#!/bin/bash
set -x
set -e
ER_TILE=$1
#unzip $ER_TILE metadata/*
mkdir -p build/metadata
cp backup/$(basename $ER_TILE).yml  build/metadata/cf.yml
cd build

if [[ "$ER_TILE" = /* ]]
then
  zip $ER_TILE metadata/*
else
  zip ../$ER_TILE metadata/*
fi

cd -
