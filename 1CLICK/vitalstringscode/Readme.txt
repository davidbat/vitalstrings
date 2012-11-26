Contents and Locations:

Below is the description of the various contents present in this folder:


1. Results : This folder has the results text files having vital strings and dependencies among them for each query.

2. stanfordparser : This folder has the jars and the files necessary to extract the nlp output for an iunit.

3. 1click.py : The python utility which reads iunits and queries from files and extracts vital
               strings from each iunit using the dependency output from stanford-core-nlp-parser.

4. stopword.txt : stopword list to be used.

Runnning the 1click.py file:

Use the following sort of command-line:

1clcik.py QUERNUMBER PATH-TO-NUGGET-FILE.....

Arguments:

1click.py- This is the python file name.

QUERYNUMBER- NUMBER OF THE QUERY IN THE QUERIES FILE HAVING QUERIES.

PATH-TO-NUGGET-FILE - RELATIVE/ABSOLUTEPATH TO THE IUNIT FILE.

you can give multiple QUERYNUMBER PATH-TO-NUGGET-FILE pairs on the command-line to process multiple 
queries.

Output:

View the result text files in the Results folder created
in the same directory from which you ae running the utility.

