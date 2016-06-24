#!/bin/bash
#
# Builds pacemaker with legacy fence plugin support from the latest standard Redhat source RPM
# Sam McLeod <https://smcleod.net>
#
# Requires :
# - CentOS / RHEL 7
#
# Optional :
# - ~/.packagecloud containing your packagecloud.io token
# e.g. {"url":"https://packagecloud.io","token":"redacted"}
#
# Provides :
# ~/rpmbuild/SRPMS/pacemaker-<version>.rpm
# ~/rpmbuild/RPMS/x86_64/pacemaker-<version>.rpm
# ~/rpmbuild/RPMS/x86_64/pacemaker-cli-<version>.rpm
# ~/rpmbuild/RPMS/x86_64/pacemaker-libs-<version>.rpm
# ~/rpmbuild/RPMS/x86_64/pacemaker-cluster-libs-<version>.rpm
# ~/rpmbuild/RPMS/x86_64/pacemaker-remote-<version>.rpm
# ~/rpmbuild/RPMS/x86_64/pacemaker-libs-devel-<version>.rpm
# ~/rpmbuild/RPMS/x86_64/pacemaker-cts-<version>.rpm
# ~/rpmbuild/RPMS/x86_64/pacemaker-doc-<version>.rpm
# ~/rpmbuild/RPMS/x86_64/pacemaker-nagios-plugins-metadata-<version>.rpm
# ~/rpmbuild/RPMS/x86_64/pacemaker-debuginfo-<version>.rpm

# Build requirements
yum install -y rpm-devel rpm-build pacemaker-libs pacemaker-cluster-libs pacemaker-cli resource-agents make yum-utils

# Get the latest pacemaker source package
yumdownloader --source pacemaker

# Build from source enabling stonithd legacy plugins
cd ~/rpmbuild/SPECS || exit
rpmbuild -bb --with stonithd pacemaker.spec

# Passing push when calling the script will push packages to packagecloud.io
# Requires ~/.packagecloud containing your authentication token
if [ "$1" == 'push' ]
  then
  package_cloud push mrmondo/pacemaker/el/7 ~/rpmbuild/RPMS/x86_64/pacemaker-*.rpm --skip-errors
fi
