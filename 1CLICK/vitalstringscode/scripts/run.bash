#!/bin/bash

set -e
set -u
set -x

echo "++++++++++++++++++++ START '$0' ++++++++++++++++++++"

SCRIPT_DIR=$(dirname `readlink -f ${0}`)
BASE_DIR=$(dirname $SCRIPT_DIR)

#cd $BASE_DIR
DATE=`date +"%Y%m%d"`
#DATE=20121116
TYPE=TEST
DATADATE=20121116
OUTDIR=$BASE_DIR/out/1C2-E-$TYPE/$DATE
mkdir -p $OUTDIR/log

$SCRIPT_DIR/stanfordparser.bash $BASE_DIR/data/$TYPE/$DATADATE/query_id.$TYPE.txt $OUTDIR $BASE_DIR/data/$TYPE/1C2-E-$TYPE.tsv 1
#echo "===== STARING CMU SEMAFOR PARSER ====="
$SCRIPT_DIR/semafor.bash $OUTDIR
echo "++++++++++++++++++++ FINISHED '$0' ++++++++++++++++++++"
exit

## tsunami
DATADATE=20121116
$SCRIPT_DIR/stanfordparser.bash $BASE_DIR/data/wikipedia/$DATADATE/query.txt out/wikipedia/$DATE








########### DUMP NUGGETS (from fiji11)
DATE=`date +"%Y%m%d"`
TYPE=TEST
OUTDIR=$BASE_DIR/data/$TYPE/$DATE
mkdir -p $OUTDIR/files
echo 'SELECT distinct(query_id) FROM nugget where rel=1' | mysql -u ntcir_nug --password='IRUeTQnT+8HvRlzU' ntcir_nuggets \
    | ~/bin/exclude.pl -h1 > $OUTDIR/query_id.$TYPE.simple
cat $OUTDIR/query_id.$TYPE.simple | perl -lne 'print "1C2-E-'$TYPE'-$_ '$OUTDIR'/files/1C2-E-'$TYPE'-$_.IUnits.tsv.utf8"' > $OUTDIR/query_id.$TYPE.txt

# bash (from fiji11)
cat $OUTDIR/query_id.$TYPE.simple | while read l; do
    echo "SELECT nugget_id,nugget_text FROM nugget where query_id=$l and rel=1;" \
	| mysql -u ntcir_nug --password='IRUeTQnT+8HvRlzU' ntcir_nuggets \
	| ~/bin/exclude.pl -h1 > $OUTDIR/files/1C2-E-$TYPE-$l.IUnits.tsv
    cat $OUTDIR/files/1C2-E-$TYPE-$l.IUnits.tsv | iconv -f iso-8859-1 -t utf-8 >$OUTDIR/files/1C2-E-$TYPE-$l.IUnits.tsv.utf8
done

exit

# perl (DO NOT USE)
cat data/query_id.$TYPE.txt | while read l; do
    ../code/dump-nuggets.pl $l > $OUTDIR/1C2-E-TEST-$l.IUnits.tsv
    iconv -f iso-8859-1 -t utf-8 <data/1C2-E-TEST-$l.IUnits.tsv >data/1C2-E-TEST-$l.IUnits.tsv.utf8
done

# diff dump result
ls data_bash/1C2-E-TEST-0*.tsv | while read f; do
    b=`basename $f`
    diff -bB data_bash/$b data_dumppl/$b | more
done

# check result
date=`date +"%Y%m%d"`
for i in {1..16}; do
    id=`printf "%04d" $i`
    #echo "diff out/1C2-E-SAMPLE-$id.out out-20120920/1C2-E-SAMPLE-$id.out"
    diff out/$date/1C2-E-SAMPLE-$id.out out/20120919/1C2-E-SAMPLE-$id.out
done



# TEST corpus
cat data/query_id.txt | while read l; do
    echo 1C2-E-TEST-$l data/1C2-E-TEST-$l.IUnits.tsv.utf8 >> $tmp/input.TEST.txt
done
#echo "1C2-E-TEST-0002 data/1C2-E-TEST-0002.IUnits.tsv" | ./run.pl -s "stopword.txt" -q "1C2-E-TEST.tsv" -P "stanfordparser" -T "$tmp" -O "$out"
cat $tmp/input.TEST.txt | ./extract_vitalstring.20120927.pl -s "stopword.txt" -q "1C2-E-TEST.tsv" -P "stanfordparser" -T "$tmp" -O "$out"
#cat $tmp/input.TEST.txt | ./extract_vitalstring.20121005.pl -s "stopword.txt" -q "1C2-E-TEST.tsv" -P "stanfordparser" -T "$tmp" -O "$out"

echo "FINISHED RUNNING"
exit
