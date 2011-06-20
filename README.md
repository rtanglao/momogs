# Roland's utilities for Get Satisfaction Metrics and other GS fun stuff 

* hardcoded for now for the Thunderbird product i.e. getsatisfaction.com/mozilla_message/products/thunderbird
* easily hackable for any other product
* forgive the barebones documentation for this project :-) !
* HELP WANTED: would love for a real developer to fix this code and enhance it
* email rtanglao AT mozilla.com if you are interested

# Prerequisites: 

* requires a MongoDB running on local host with a database called "gs" 
* and with collection in the gs database called "topics"

# Usage:

## Update the Mongo - ALWAYS do this first before running anything else!

    ./mongoUpdateSlurpGS.rb 2011 6 16  2011 6 19 2>mongoslurp.16-19june2011.818pm.stderr.txt &
     
## Daily email metrics (I run this twice a day, typically 9a.m. and 4p.m. Pacific)

    ./emailDailyMetrics.rb &

## Weekly Metrics to CSV files and stdout (run once a week to generate support metrics for the Thunderbird Project Call)

    ./weeklyMetrics.rb 2011 6 13 2011 6 19 2>13-19june2011.stderr.txt 1>13-19june2011.stdout.txt

## Search the Thunderbird Get Satisfaction MongoDB for regexes in the fulltext (title+content+replies) & tags

e.g. for Thunderbird 5 here's a sample search ("-r" is a comma separated list of regexes to search the fulltext for and "-s" is a comma separated list of regexes to search tags for)

    ./bruteforceSearch.rb 2011 6 1 2011 6 30 2>19june2011.tb5b1.bfs.stderr.1020pm.txt 
    1>19june2011.tb5b1.bfs.stdout.1020pm.txt 
    -r tb5, "tb 5","thunderbird5","thunderbird 5",beta 
    -s "tb 5",tb5,thunderbird5,"thunderbird 5","beta feedback",50,tb5,"tb 5",beta