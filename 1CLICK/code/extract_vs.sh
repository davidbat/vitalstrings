#!/bin/bash

if [ $# -lt 1 ]; then
  echo "$0 QueryID"
  exit 1
fi

QID=$1

./dump-nuggets.pl $QID >../vitalstringscode/Iunits/$QID.tsv
./dump-query.pl $QID >../vitalstringscode/queries/$QID.tsv
cd ../vitalstringscode
#python 1click.py $QID.tsv $QID.tsv
perl 1click.pl $QID.tsv $QID.tsv
#./dump-nuggets.pl $QID >../vitalstringscode/Iunits/$QID.tsv
#./dump-query.pl $QID >../vitalstringscode/queries/$QID.tsv
#cd ../vitalstringscode
## For with output file
#python 1click.py queries/$QID.tsv iunits/$QID.tsv Results/$QID.tsv
## For without output file
#python 1click.py queries/$QID.tsv iunits/$QID.tsv
echo "Results are in ../vitalstringscode/Results/$QID.txt"
