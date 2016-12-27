#!/bin/bash
set -x
./run.sh ../cf-1.8.17-build.3.pivotal 1.0.1 dmz sf ptr  #the last argment 1 is for haproxy release
echo "exit code from run.sh is:"
echo $?
