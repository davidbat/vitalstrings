#!/bin/bash -f



cat data_dumppl/query_id.SAMPLE.txt  | xargs -i echo "1C2-E-SAMPLE-{} data/SAMPLE/1C2-E-SAMPLE-{}.IUnits.tsv.utf8" > data/query_id.SAMPLE.txt

cat data_dumppl/query_id.TEST.txt  | xargs -i echo "1C2-E-TEST-{} data/TEST/1C2-E-TEST-{}.IUnits.tsv.utf8" > data/query_id.TEST.txt
