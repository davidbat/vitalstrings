#!/bin/bash

set -e
set -u
set -x

echo "++++++++++++++++++++ START '$0' ++++++++++++++++++++"

#type=$1
data=`readlink -f $1`
OUTDIR=`readlink -f $2`
#queries=$3
#iunitInData=$4
if (( "$#" >= 4 )); then
    iunitInData=1
    opt="-u"
    properties="parser.properties.spliteol"
else
    iunitInData=0
    opt=""
    properties="parser.properties"
fi

SCRIPTS_DIR=$(dirname `readlink -f ${0}`)
BASE_DIR=$(dirname $SCRIPTS_DIR)

out=$OUTDIR/output/STANFORD
tmp=$OUTDIR/tmp
stopwords=$BASE_DIR/stopword.txt
mkdir -p $tmp/STANFORD/{input,etc,output} $out

#if [ ]; then
## PREPROC
rm -f $tmp/STANFORD/input.files
cat $data | while read l; do
    fileid=`echo $l | awk '{print $1}'`
    f_tmp=`echo $l | awk '{print $2}'`
    f=`readlink -f $f_tmp`
    if [ $iunitInData == 1 ]; then
	#cat $f | awk -F'\t' '{print $1}' > $tmp/STANFORD/etc/$fileid.sid
	cat $f | awk -F'\t' '{print $2}' | sed -r 's/(\.)?\s*$/.\n/'> $tmp/STANFORD/input/$fileid
    else
	ln -sf $f $tmp/STANFORD/input/$fileid
    fi
    echo $tmp/STANFORD/input/$fileid >> $tmp/STANFORD/input.files
    #echo "$f	$tmp/STANFORD/input/$fileid" >> $tmp/STANFORD/filelist
done

## STANFORD PARSER
cd stanfordparser
jarpath=stanford-corenlp-2012-07-06-models.jar:xom.jar:joda-time.jar:stanford-corenlp-2012-07-09.jar
java -cp $jarpath edu.stanford.nlp.pipeline.StanfordCoreNLP -props $properties -filelist $tmp/STANFORD/input.files -outputDirectory $tmp/STANFORD/output
cd ..

#fi

find $tmp/STANFORD/output/ -name "*.xml" | while read path; do
    f=`basename $path`
    fileid=`echo $f | sed 's/.xml//'`

    #echo grep $fileid $data | awk '{print $2}'
    ori_file=`grep $fileid $data | awk '{print $2}'`

    querywords=$tmp/STANFORD/etc/$fileid.querywords
    cp $stopwords $querywords
    #echo "HERE???" 
    #echo grep $fileid $queries
    if (( "$#" >= 3 )); then grep $fileid $3 | awk -F '\t' '{print $3}' |sed 's/\s\s*/\n/g' >> $querywords; fi
    #exit

    if [ $iunitInData == 1 ]; then u_opt="-u"; else u_opt=""; fi
    #echo $path 
    #echo $SCRIPTS_DIR/extract_vitalstring.20121115.pl $u_opt -q $querywords -o $ori_file
    cat $path | $SCRIPTS_DIR/extract_vitalstring.20121115.pl $u_opt -q $querywords -o $ori_file > $out/$fileid.out
done

echo "++++++++++++++++++++ FINISHED '$0' ++++++++++++++++++++"
exit


