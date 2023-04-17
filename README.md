# Harverst and import links to DOAJ (doaj.org) to Aleph catalogue

## What's this?
The script intended for scheduled execution harvests (OAI) records from doaj.org. The harvest can be performed from date set as script argument or from date set in special file with data-stamp. ISSN are extracted from harvested Dublin Core file. Theese issn are compared to ALEPH BIB base using manage-36 procedure. If just one corresponding record is found, the script exports (print-03) the record, compare the current value of 856 4# MARC field with link to doaj.org, and if it has changed or not exists yet, the new 856 field is imported to BIB base (manage-18).  For more matching BIB recs to one ISSN, it sends alert to librarian. All alerts,erros and results are sent to librarian mail set in the script.

## Implementation
1. Put the script `doaj_import_links.csh` anywhere on aleph server and make it executable (`chmod +x doaj_import_links.csh`)
Edit this file and at the beginning see the section "#initial constats - SET THIS FIRST". Here are some variables according to library local settings that must be set before execution.
2. Download pyoaiharvest.py - OAI harvester in python from https://github.com/vphill/pyoaiharvester and place it in the same directory as the main CSH script.
3. Check if you have xmllint installed (tool for xml,xpath...  http://xmlsoft.org/xmllint.html). If not, install this package: `sudo yum -y install libxml2`


## Execution
The script can have an argument YYYY-MM-DD, which determines dateFrom the data is harvested from doaj.org OAI. Without argument, the script looks up a file `doaj_import_links.last_harvest`, where date-stamp of the last harvest is stored. This execution without any argument is common for scheduled running, when harvest is performed from the date of the last harvest. If no date argument nor file, harvest is performed from year 1900.

Another possible script argument is "force" or "FORCE" intended for exceptional ("tidying") executions. Before import, all links to doaj.org are deleted from the ALEPH BIB base.

Argument:  1. date from which the harvest is performed YYYY-MM-DD
                (optional) - if not set, file "doaj_import_links.last_harvest" is looked up in the same directory as this script. 
                                 If the file is not found, harvest is performed since 1900-01-01
           2. "force"|"FORCE" - deletes all current links to fulltexts at doaj.org and imports all newlz harvested (optional)

### Example of scheduling execution every Sunday in ALEPH $alephe_tab/joblist :
WW 06:00:00 N doaj_import          /{some_path_to_script}/doaj_import_links.csh


#Requirements: 
               a] python
               b] pyoaiharvest.py - OAI harvester in python : https://github.com/vphill/pyoaiharvester
               c] xmllint - http://xmlsoft.org/xmllint.html
               d] ISSN matching routine set in $data_tab/tab_match file. Example of this setting (Marc field 022, acc heading ISN) is:
                         `ISSN  match_doc_gen                  TYPE=IND,TAG=022,SUBFIELD=a,CODE=ISN`


_by Matyas F. Bajger, University of Ostrava Library, library.osu.eu. 20210402, GNU GPL ver 3.0 (free distribution and modification)_
