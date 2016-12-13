#!/bin/bash
set -x
set -e
ER_TILE=$1
BUILD=build
rm -rf $BUILD/* || true
mkdir $BUILD/templates
unzip $ER_TILE metadata/* -d $BUILD
COUNT=$(ls -1 $BUILD/metadata/cf*.yml|wc -l)
if (( COUNT != 1 )); then
    echo "fail to find metadata/cf*.yml in $ER_TILE, unsupported service tile";
    exit;
fi
METAFILE=$(ls $BUILD/metadata/*.yml)

BACKUP_METADATA=backup/$(basename $ER_TILE).yml
if [[ -f  $BACKUP_METADATA ]];then
  rm $METAFILE
  cp $BACKUP_METADATA ${METAFILE}
else
  cp ${METAFILE} $BACKUP_METADATA
fi


STACKS=""
 
for i in `seq 3 $#` ;do
    STACKS=$STACKS" "${!i}
done

./template.rb  templates/property_blueprints.yml.erb $BUILD/templates/property_blueprints.yml $STACKS
sed -i '/^ *$/d' $BUILD/templates/property_blueprints.yml
./template.rb  templates/form_types.yml.erb $BUILD/templates/form_types.yml $STACKS
sed -i '/^ *$/d' $BUILD/templates/form_types.yml
./template.rb  templates/lifecyle_bundles_inputs.erb $BUILD/templates/lifecyle_bundles_inputs.yml $STACKS
sed -i '/^ *$/d' $BUILD/templates/lifecyle_bundles_inputs.yml

sed -i -e "/^property_blueprints:\$/r $BUILD/templates/property_blueprints.yml" $METAFILE 
sed -i -e "/^form_types:$/r $BUILD/templates/form_types.yml" $METAFILE 
sed -i -e "/^      stacks:$/{n;N;N;N;d}" $METAFILE #delete next 4 rows
sed -i -e "s/^      stacks:/& (( .properties.stacks.value ))/" $METAFILE
sed -i -e "/^      stager:$/r $BUILD/templates/lifecyle_bundles_inputs.yml" $METAFILE 
sed -i -e "/^      nsync:$/r $BUILD/templates/lifecyle_bundles_inputs.yml"  $METAFILE 

cd $BUILD

if [[ "$ER_TILE" = /* ]]
then
  zip $ER_TILE metadata/*
else
  zip ../$ER_TILE metadata/* 
fi

cd -


./extract.rb $METAFILE $BUILD/base.yml $2 |xargs -i unzip $ER_TILE releases/{} -d $BUILD

echo $?
shift
shift 

for i in $@; do
    mkdir -p $BUILD/$i/metadata
    mkdir -p $BUILD/$i/releases
    cp $BUILD/releases/* $BUILD/$i/releases/
    sed "s/__name__/$i/g" $BUILD/base.yml >  $BUILD/$i/metadata/${i}.yml
    cd $BUILD/$i 
    zip -r ../${i}.pivotal *
    cd -
done;
rm $BUILD/base.yml
