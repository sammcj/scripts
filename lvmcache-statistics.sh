#!/usr/bin/env bash
#
# lvmcache-statistics.sh displays the LVM cache statistics
# in a user friendly manner
#
# Copyright (C) 2014 Armin Hammer
# Modified by Sam McLeod 2023
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at
# your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program. If not, see http://www.gnu.org/licenses/.
#
# Usage:
# # lvmcache-statistics.sh [lvm-device]
#
#   lvm-device: device file of the to be inspected LVM device
#               if not set - the first LVM cache device will be used
#
# Sample:
#   # lvmcache-statistics.sh
#   # lvmcache-statistics.sh /dev/vg00/lvol0
#
# References
# - https://www.kernel.org/doc/Documentation/device-mapper/cache.txt
# - https://www.kernel.org/doc/Documentation/device-mapper/cache-policies.txt
# - https://en.wikipedia.org/wiki/Dm-cache
# - ftp://sources.redhat.com/pub/lvm2/WHATS_NEW
# - $ man lvmcache
#
# History:
# 20141220 hammerar, initial version v1.0
# 20151219 hammerar, complete overhaul and much more verbose v2.0
# 20151220 hammerar, no policy args in smq policy fixed
# 20160326 hammerar, bugfix lvm detection and better policy undestanding
# 20170915 hammerar, bugfix mg instaead of mq typo
#                    missed cleaner policy
#
# Todo:
# - division by zero if you call statitics if not even 1 block is used
# - fully add cleaner policy
##################################################################
set -o nounset

DEBUG=false
#DEBUG=true

# use first parameter if given as device to be inspected
if [ $# -ne 0 ]; then
  LVCACHED=$1
else
  # LVCACHED=/dev/vg00/lvol0
  LVCACHED="/dev/$(lvs --noheadings -o lv_fullname,cache_policy | grep -E -w "mq|smq|cleaner" | head -n 1 | awk '{ print $1 }')"
fi

RESULT=$(dmsetup status ${LVCACHED})
if [ $? -ne 0 ]; then
  echo "[ERROR] Unsuccessfull readout of <${LVCACHED}>! Abort...!"
  exit 1
fi

# http://stackoverflow.com/questions/10586153/bash-split-string-into-array
IFS=' ' read -a RESULTS <<<"${RESULT}"

PRINTDEBUG() {

  ${DEBUG} && echo "[DEBUG] $1"
  return
}

# mq
# 0 3892379648 cache 8 5204/393216 128 1228751/1740800 16000290 96139299 7608331 58288757 0 367718 0 \
# 1 writeback 2 migration_threshold 2048 mq 10 random_threshold 4 sequential_threshold 512 \
# discard_promote_adjustment 1 read_promote_adjustment 4 write_promote_adjustment 8 rw -
# smq
# 0 3892379648 cache 8 5204/393216 128 1694509/1740800 16064464 96291237 8382251 58523837 0 0 5
# 1 writeback 2 migration_threshold 2048 smq 0 rw -

MetadataBlockSize="${RESULTS[3]}"
NrUsedMetadataBlocks="${RESULTS[4]%%/*}"
NrTotalMetadataBlocks="${RESULTS[4]##*/}"

CacheBlockSize="${RESULTS[5]}"
NrUsedCacheBlocks="${RESULTS[6]%%/*}"
NrTotalCacheBlocks="${RESULTS[6]##*/}"

NrReadHits="${RESULTS[7]}"
NrReadMisses="${RESULTS[8]}"
NrWriteHits="${RESULTS[9]}"
NrWriteMisses="${RESULTS[10]}"

NrDemotions="${RESULTS[11]}"
NrPromotions="${RESULTS[12]}"
NrDirty="${RESULTS[13]}"

INDEX=14
NrFeatureArgs="${RESULTS[${INDEX}]}"
FeatureArgs=""

if [ ${NrFeatureArgs} -ne 0 ]; then

  for ITEM in $(seq $((INDEX + 1)) $((INDEX + NrFeatureArgs))); do
    FeatureArgs="${FeatureArgs}${RESULTS[${ITEM}]} "
    PRINTDEBUG "${FeatureArgs}"
  done

  INDEX=$((INDEX + NrFeatureArgs))
fi

INDEX=$((INDEX + 1))
NrCoreArgs="${RESULTS[${INDEX}]}"
CoreArgs=""

if [ ${NrCoreArgs} -ne 0 ]; then

  for ITEM in $(seq $((INDEX + 1)) $((INDEX + 2 * NrCoreArgs))); do
    CoreArgs="${CoreArgs}${RESULTS[${ITEM}]} "
    PRINTDEBUG "${CoreArgs}"
  done

  INDEX=$((INDEX + 2 * NrCoreArgs))
fi

CachePolicyMQ=$(echo ${CoreArgs} | grep -w mq >/dev/null && echo mq)
CachePolicySMQ=$(echo ${CoreArgs} | grep -w smq >/dev/null && echo smq)
CachePolicy=${CachePolicyMQ}${CachePolicySMQ}
# the cleaner policy is yet ignored

if [ -n "${CachePolicyMQ}" ]; then

  INDEX=$((INDEX + 1))
  PolicyName="${RESULTS[${INDEX}]}"
  INDEX=$((INDEX + 1))
  NrPolicyArgs="${RESULTS[${INDEX}]}"
  PolicyArgs=""

  if [ ${NrPolicyArgs} -ne 0 ]; then

    for ITEM in $(seq $((INDEX + 1)) $((2 * NrPolicyArgs + INDEX))); do
      PolicyArgs="${PolicyArgs}${RESULTS[${ITEM}]} "
      PRINTDEBUG "${PolicyArgs}"
    done

    INDEX=$((INDEX + 2 * NrPolicyArgs))
  fi
fi

INDEX=$((INDEX + 1))
CacheMetadataMode="${RESULTS[${INDEX}]}"
INDEX=$((INDEX + 1))
NeedsCheck="${RESULTS[${INDEX}]}"

##################################################################
# human friendly output
##################################################################
echo "-------------------------------------------------------------------------"
echo -n "LVM [$(lvm version | grep 'LVM' | awk '{ print $3 }')] cache report of "
if [ $# -ne 0 ]; then
  echo -n "given "
else
  echo -n "found "
fi
echo "device ${LVCACHED}"
echo "-------------------------------------------------------------------------"

MetaUsage=$(echo "scale=1;($NrUsedMetadataBlocks * 100) / $NrTotalMetadataBlocks" | bc)
CacheUsage=$(echo "scale=1;($NrUsedCacheBlocks * 100) / $NrTotalCacheBlocks" | bc)
echo "- Cache Usage: ${CacheUsage}% - Metadata Usage: ${MetaUsage}%"

ReadRate=$(echo "scale=1;($NrReadHits * 100) / ($NrReadMisses + $NrReadHits)" | bc)
WriteRate=$(echo "scale=1;($NrWriteHits * 100) / ($NrWriteMisses + $NrWriteHits)" | bc)
echo "- Read Hit Rate: ${ReadRate}% - Write Hit Rate: ${WriteRate}%"
echo "- Demotions/Promotions/Dirty: ${NrDemotions}/${NrPromotions}/${NrDirty}"
echo "- Feature arguments in use: ${FeatureArgs}"
echo "- Core arguments in use : ${CoreArgs}"

echo -n "  - Cache Policy: "
case $CachePolicy in
mq)
  echo "multiqueue (mq)"
  echo "  - Policy arguments in use: ${PolicyArgs}"
  ;;
smq)
  echo "stochastic multiqueue (smq)"
  ;;
cleaner)
  echo "cleaner"
  ;;
*)
  echo " *** ooops *** - unknown policy <${CachePolicy}>"
  ;;
esac

echo "- Cache Metadata Mode: ${CacheMetadataMode}"
echo -n "- MetaData Operation Health: "

if [ "${NeedsCheck}" == "-" ]; then
  echo "ok"
else
  echo "needs-check"
fi

#### EOF #########################################################
