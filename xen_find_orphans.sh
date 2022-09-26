#!/bin/bash

echo "This script identifies whether a VDI has an associated VBD to help identify orphaned VDIs."
echo ""
echo "Note: It only checks r/w VDIs and items with 'Name-Label: Update' are xenserver updates that have been uploaded"
echo ""

VDI_UUIDS=$(xe vdi-list read-only=false --minimal | sed 's/,/ /g')

for VDI in ${VDI_UUIDS}; do
  VBD_UUID=$(xe vbd-list vdi-uuid="${VDI}" --minimal)

  if [ "${VBD_UUID}x" == "x" ]; then
    NAME_LABEL=$(xe vdi-list uuid="${VDI}" | grep name-label | cut -d':' -f2)

    if [ "$NAME_LABEL" != " Update" ] && [ "$NAME_LABEL" != " Pool Metadata Backup:" ]; then
      echo "VDI: ${VDI}"
      echo "NULL VBD. Probably not attached to any vm"
      echo "Name-Label: ${NAME_LABEL}"
      echo "------------------------------------------"
    fi
  fi
done
