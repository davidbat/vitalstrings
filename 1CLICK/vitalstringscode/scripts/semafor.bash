#!/bin/bash -f

set -e
set -u

echo "++++++++++++++++++++ START '$0' ++++++++++++++++++++"
OUTDIR=$1

SCRIPTS_DIR=$(dirname `readlink -f ${0}`)
BASE_DIR=$(dirname $SCRIPTS_DIR)
cd $BASE_DIR


#find $OUTDIR/tmp/STANFORD/input/ -name "1C2-E-$TYPE-*.sentences" | xargs -i basename {} | parallel -u /home/yerihyo/Downloads/semafor-semantic-parser/release/fnParserDriver.sh $OUTDIR/tmp/STANFORD/input/"{}" $OUTDIR/output/SEMAFOR/"{}".out
#exit

mkdir -p $OUTDIR/output/SEMAFOR
find $OUTDIR/tmp/STANFORD/input -type f -name "*" | xargs -i basename {} | while read f; do
    echo "RUNNING CMU SEMAFOR on file '$f'"
    /home/yerihyo/Downloads/semafor-semantic-parser/release/fnParserDriver.sh $OUTDIR/tmp/STANFORD/input/$f $OUTDIR/output/SEMAFOR/$f.out
done

echo "++++++++++++++++++++ FINISHED '$0' ++++++++++++++++++++"
