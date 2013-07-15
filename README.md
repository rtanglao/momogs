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

Metrics reported:
    
1. "Topics that Roland needs to reply to:" aka Thunderbird Get Satisfaction topics that aren't closed that have replies from other people after Roland's last reply
1. Get Satisfaction Top 5 active - topics with most activity in terms of replies
1. Get Satisfaction Contributors - any contributor who has a starred or company promoted reply (unforunately since it takes 3 people to star a reply before it gets star promoted, this is usually just known contributors and doesn't spot new contributors)
1. Top 10 Get Satisfaction Repliers - those who replied the most 
1. 5 Random Get Satisfaction Topics: so we see some variation in case we don't have time to look through all the new topics
1. New Topics - all topics created today

Sample email output by emailDailyMetrics.rb:
[June 19, 2011 Example Email Report](https://github.com/rtanglao/momogs/blob/master/sampleEmailDailyReport.md)

## Weekly Metrics to CSV files and stdout (run once a week to generate support metrics for the Thunderbird Project Call)

    ./weeklyMetrics.rb 2011 6 13 2011 6 19 2>13-19june2011.stderr.txt 1>13-19june2011.stdout.txt

## Search the Thunderbird Get Satisfaction MongoDB for regexes in the fulltext (title+content+replies) & tags

e.g. for Thunderbird 5 here's a sample search ("-r" is a comma separated list of regexes to search the fulltext for and "-s" is a comma separated list of regexes to search tags for)

    ./bruteforceSearch.rb 2011 6 1 2011 6 30 2>19june2011.tb5b1.bfs.stderr.1020pm.txt 
    1>19june2011.tb5b1.bfs.stdout.1020pm.txt 
    -r tb5, "tb 5","thunderbird5","thunderbird 5",beta 
    -s "tb 5",tb5,thunderbird5,"thunderbird 5","beta feedback",50,tb5,"tb 5",beta
    
## Change status of a topic

from https://getsatisfaction.com/getsatisfaction/topics/is_it_possible_to_change_the_author_of_a_topic

    
    There is a special endpoint just for PUTing status updates: 
    https://api.getsatisfaction.com/topics/5438709/status.json

    And the parameters look like: {"status": "complete"} 
