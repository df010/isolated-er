#!/bin/bash
set -x
./run.sh ../cf-1.8.17-build.3.pivotal 1.0 dmz sf ptr
echo "exit code from run.sh is:"
echo $?
