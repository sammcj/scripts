#!/bin/bash

yum groupinstall "Development Tools"
yum install -y rpm-build make yum-utils

rpm -ivh http://vault.centos.org/7.2.1511/updates/Source/SPackages/pacemaker-1.1.13-10.el7_2.2.src.rpm

cd ~/rpmbuild/SPackages ||

#vi pacemaker.spec and append the date/time to the version

pacemaker-1.1.13-10.el7_2.2.src.rpm
# Go make a coffee...
# .
# ..
# ...
# You should now pacemaker RPMs that support legacy stonith plugins under the ~/rpmbuild/RPMS/
# You can upload these to the proxy server as required