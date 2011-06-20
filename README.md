# Roland's utilities for Get Satisfaction Metrics and other GS fun stuff 

* hardcoded for now for the Thunderbird product i.e. getsatisfaction.com/mozilla_message/products/thunderbird
* easily hackable for any other product
* forgive the barebones documentation for this project :-) !
* HELP WANTED: would love for a real developer to fix this code and enhance it
* email rtanglao AT mozilla.com if you are interested

# Usage:
 
## Daily email metrics (I run this twice a day, typically 9a.m. and 4p.m. Pacfic)

    ./emailDailyMetrics.rb &

## Weekly Metrics to CSV files and stdout (run once a week to generate support metrics for the Thunderbird Project Call)

    ./weeklyMetrics.rb 2011 6 13 2011 6 19 2>13-19june2011.stderr.txt 1>13-19june2011.stdout.txt