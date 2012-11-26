## 1click.py
##
## This script accepts a series of (query number and nugget file path ) pairs producing
## vital strings and dependencies between them for each information unit in the nugget file.
##
##

##Import Statements##
import re
from collections import defaultdict
import string
import os
import sys
import pdb

##Global Variables##
dict_vital=defaultdict(dict)   ## dictionary for vitalstrings per iunit
dict_iunits=defaultdict(list)   ## dictionary for iunits per query

##Constants##
QUERIESPATH="1C2-E-TEST.tsv"
QUERYPREFIX='1C2-E-TEST-'
OSNAME=os.name
JARLIST=['stanford-corenlp-2012-07-06-models.jar','xom.jar','joda-time.jar','stanford-corenlp-2012-07-09.jar']
PARSERDIRECTORY='stanfordparser'
SLASH='\\' if OSNAME == 'nt' else '/'
IUNITRESULTS="Results" + SLASH
JARFILEPATH=";".join(JARLIST) if OSNAME == 'nt' else ":".join(JARLIST)
IUNITFILE='iunits.txt'
STOPWORD_FILE='stopword.txt'

## This function writes the vital strings and dependency output into
## a file.
def writeoutput(filename,dict_dependency,temp_iunits):
    fv=open(IUNITRESULTS+filename+".txt","w")       ## write the vital-strings and dependency output
    dict_dep,wtstr=defaultdict(list),''             
    for i in range(1,len(dict_vital)+1):
        dict_v=dict_vital[i]
        deplist=dict_dependency[i]
        for d in deplist:   ##process dependencies
            p=q=-1
            for key,value in dict_v.items():
                if d[0] in value:
                    p=key
                if d[1] in value:
                    q=key
            if p!=q and p not in dict_dep.get(q,[]) and q not in dict_dep.get(p,[]) and p>0 and q>0:
               dict_dep[q].append(p)
        idnum=temp_iunits[i-1][0]
        vitalnum="V" + idnum[1:]
        wtstr+=temp_iunits[i-1][0] +'\t' + temp_iunits[i-1][1]+'\n'
        for key,value in dict_v.items():    ## prepare output in required format.
            vital_num=vitalnum + '0' * (3- len(str(key))) + str(key) 
            wtstr+=vital_num + '\t' + ''.join([p +' ' for p in value]) + ' '
            if len(dict_dep[key])>0:
               for k in dict_dep[key]:
                   wtstr+='DEP=' + vitalnum + '0' * (3- len(str(k))) + str(k) + ' '
            wtstr+='\n'
        dict_dep.clear()
    fv.write(wtstr)
    fv.close()

## This function extracts the vital strings from the core-nlp-output using regex.
def extractvitalstrings(temp_iunits,data,stopword):
    joinvital,dict_vitals,numval=[],[],1
    t=re.compile(r'\([A-Z]+\s+([^)(]*)\)*')
    for c,d in zip(temp_iunits,data):     ## repeat this for each iunit.
        d=re.sub(r'\(DT\s+.*?\)|\(IN\s+.*?\)|\(TO\s+.*?\)|\(VBP\s+.*?\)|\(MD\s+.*?\)',"",d)  ## remove the unimportant words.
        vitalstring=re.compile(r'\([A-Z]+\s+([^\(\)]+?)\)').findall(d)
        vitals=re.compile(r'\(NP\s+((\([^\(]+?\){1}\s*)+)').findall(d)  ##extract related words.
        for i in vitals:
            if i!='':
                st=t.findall(i[0])
                st=[i.lower() for i in st if i.lower() not in stopword]  ## remove stopwords + query words.
                if len(st)>0 and st not in dict_vitals:
                   if type(st) is list:
                       dict_vitals.append(st)
                   else:
                       dict_vitals.append([st])
        [joinvital.extend(el) for el in dict_vitals]
        for j in vitalstring:
            lower_word=j.lower()
            if lower_word not in stopword and lower_word not in joinvital and j not in dict_vitals:
                if type(j) is list:
                       dict_vitals.append(j)
                else:
                       dict_vitals.append([lower_word])
        dict_vital[numval]=dict(zip(range(1,len(dict_vitals)+1),dict_vitals))
        numval=numval+1
        dict_vitals=[]

##This function parses the output from the xml file produced
## by the stanford-core-nlp parser.
def parsetext(stopword,temp_iunits,filename):
    deplist,dict_dependency,count=[],defaultdict(list),1
    nlp_output=open(PARSERDIRECTORY+SLASH+filename + '.txt.xml',"r").read(); ## read the xml file output
    data=re.compile(r'<parse>.*?\(ROOT(.*?)\(\.\s+?\.\)\)\)',re.DOTALL).findall(nlp_output) ## get the parser output
    datadependency=re.compile(r'.*?\<basic-dependencies>(.*?)</basic-dependencies>',re.DOTALL).findall(nlp_output)  ##get the dependencies
    for i in datadependency:
        dependency=re.sub(r'\n|\t','',i)
        dataone=re.compile(r'.*?<dep.*?>\s+<governor.*?>(.*?)</governor>\s+<dependent.*?>(.*?)</dependent>\s+?</dep>',re.DOTALL).findall(i)
        dataone=[(j[0].lower(),j[1].lower()) for j in dataone] ##convert words to lowercase
        for k in dataone:
            if k[0] not in stopword and k[1] not in stopword:  ##eliminate stopwords in dependency
                deplist.append(k)
        dict_dependency[count]=deplist   
        deplist=[]
        count=count+1
    extractvitalstrings(temp_iunits,data,stopword)  ##extract vital strings by using regex
    writeoutput(filename,dict_dependency,temp_iunits)  ##write the output

##This function calls the stanford-core-nlp tool 
##and retrieves the output in the xml file.
def processiunits(iunitft):
    os.chdir(os.path.abspath(PARSERDIRECTORY)) ## change directory to stanford-core-nlp directory to run the utility.
    writeiunit=open(IUNITFILE,'w') ## file for writing list of nugget files.
    writeiunit.write(''.join([i+'.txt\n' for i in iunitft]))   ## write list of nugget files into a file.
    writeiunit.close()
    ## command-line arguments to be given to the core-nlp tool.
    args = [
             'java',
            '-cp '+ JARFILEPATH,
             'edu.stanford.nlp.pipeline.StanfordCoreNLP',
            '-annotators tokenize,ssplit,pos,lemma,ner,parse,dcoref',
            '-filelist '+IUNITFILE,
        ]
    cmd =' '.join(args)
    os.system(cmd)

## This is the function which calls several other functions
## to extract the vital strings and dependencies from iunits. 
def clickproject():
    global dict_vital
    try:             ##check for correct arguments
        if (len(sys.argv) < 3):
            raise Exception("Command-line arguments wrong!")
    except Exception:
        print "Command-line arguments are:" +'\n' \
              "1click.py query-number path-to-nuggetfile ...."
        os._exit(1)
    wholeiunits=re.compile(r'(.*?)\t(.*?)\t')    ## regex for extracting only iunit number and text.
    for i in range(1,len(sys.argv),2):
        querynum=QUERYPREFIX+'0'*(4-len(sys.argv[i])) + sys.argv[i]   ## construct the query number according to the query file processed(TEST OR SAMPLE).
        nugget_file=open(sys.argv[i+1],'r').read()             ##read the nugget-file
        temp_iunits=wholeiunits.findall(nugget_file)           ## find iunit-number,iunit tuples
        iunitft=''.join([i[1] + '.' if i[1][-1]!='.' else i[1] for i in temp_iunits])  ## separate each of the iunits by a period.
        file_nugget=open(PARSERDIRECTORY+SLASH+querynum + '.txt','w').write(iunitft)  ##write iunits for each query into a separate file.
        dict_iunits[querynum]=temp_iunits
    processiunits(dict_iunits.keys())                      ## call the stanford-core-nlp tool
    os.chdir('..')       ##return back from the stanfordparser directory
    for k,v in dict_iunits.items():
        fp=open(QUERIESPATH,"r").read()                     ## read the sample file having queries.
        stopword=open(STOPWORD_FILE,"r").read().split()      ## read the stopword file
        data=re.compile(r'(.*?)\t.*?\t(.*?)\n').findall(fp)  ## regex to extract querynumber and query pair in a list.
        iunitdata=re.compile(r'.*?\t(.*?)\t')  
        data=dict(data);
        query=data[k];
        query=[i.lower() for i in query.split()]
        stopwordquery=query+stopword                    ## combine query words with stopwords.
        parsetext(stopwordquery,v,k) ##process the text.
        dict_vital.clear()

#Program starts here.#    
clickproject()   
