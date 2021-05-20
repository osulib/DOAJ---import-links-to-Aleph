#!/bin/csh -f

# Using OAI, this harvests DOAJ journal records, match them against Aleph BIB database by ISSN and creates/updates links to doaj.org to 856 Marc fields.
#
# Argument:  1. date from which the harvest is performed YYYY-MM-DD
#                 (optional) - if not set, file "doaj_import_links.last_harvest" is looked up in the same directory as this script. 
#                                  If the file is not found, harvest is performed since 1900-01-01
#            2. "force"|"FORCE" - deletes all current links to fulltexts at doaj.org and imports all newlz harvested (optional)
# Requirements: a] python
#               b] pyoaiharvest.py - OAI harvester in python : https://github.com/vphill/pyoaiharvester
#               c] xmllint - http://xmlsoft.org/xmllint.html
#               d] ISSN matching routine set in $data_tab/tab_match file. Example of this setting (Marc field 022, acc heading ISN) is:
#                         ISSN  match_doc_gen                  TYPE=IND,TAG=022,SUBFIELD=a,CODE=ISN
#
#by Matyas F. Bajger, University os Ostrava Librart, library.osu.eu. 20210402, GNU GPL ver 3.0 (free distribution and modification)


#initial constats - SET THIS FIRST
set bibBase="XXX01"; #Aleph BIB base where records should be updated
set librarianMail="best.librarian@library.moon"; #for sending reports and alerts to
set issnIndexName='ISN'; #Aleph index code set for ISSN (Marc field 022) as it is set in $data_tab/tab11_acc or tab11_word
set doajLinkToJournal='https://doaj.org/toc/@@@@-@@@@'; #Links ro DOAJ journals that will be added to 856 fields, '@@@@-@@@@' is replaced to real ISSN value
set doajLinkText='$$yPlné texty online (doaj.org)'; #Text that will be added to 856 fields. Including prefix with subfield code that will be used (might subfiel;d 3 or y)
set doajImportCataloger='doaj_import'; #Cataloger name that will be used to import 856 fields, up to 10 chars long
set doajImportCatalogerLevel='00'; #Cataloger level that will be used to import 856 fields. Set upo according to your library catal. level policy


#other constants
set doajOaiUrl='https://doaj.org/oai'
set logfile="$alephe_scratch/doaj_import_links.log"
set scriptDir=`dirname $0 && pwd | awk '{print $2;}'`
set today=`date "+%Y%m%d"`
set bibBaseLowerCase=`echo $bibBase | aleph_tr -l`
set dataScratch="$alephe_dev/$bibBaseLowerCase/scratch"
set doajLinkToJournalDomain=`echo "$doajLinkToJournal" | grep -o '://[^/]\+/'`
set thisScriptPath=`dirname "$0"`


printf "\n\n START `date`" | tee -a $logfile

#check argument or look for timestamp file
echo "HARVESTING $doajOaiUrl ..." | tee -a $logfile
set harvestFrom='';
set force='';
if ( $?1 ) then #read argument
   if ( "$1" == 'force' || "$1" == 'FORCE' ) then
     set force='Y'
   else if ( "$1" != "" ) then
     if ( `echo $1 | grep -c '[12][0-9]\{3\}\-[0-9]\{2\}\-[0-9]\{2\}' | bc` != 1 ) then #bad argument
        echo "ERROR - argument $1 has bad syntax. It must be timestamp of date-from harvest, like YYYY-MM-DD" | tee -a $logfile
	tail $logfile -n10 | mail -s "doaj_import_links.csh error" "$librarianMail"
        exit
     else
        set harvestFrom="$1";
        echo "Harvesting from $harvestFrom (set as script argument)"
     endif
   endif
endif
if ( $?2 ) then 
   if ( "$2" == 'force' || "$2" == 'FORCE' ) then
     set force='Y'
   endif
endif
if ( $harvestFrom == '' && -e $thisScriptPath/doaj_import_links.last_harvest ) then
   if ( `cat $thisScriptPath/doaj_import_links.last_harvest | grep -c '[12][0-9]\{3\}\-[0-9]\{2\}\-[0-9]\{2\}' | bc` == 1 ) then
      set harvestFrom=`grep -o '[12][0-9]\{3\}\-[0-9]\{2\}\-[0-9]\{2\}' | head -n1`
      echo "Harvesting from $harvestFrom (got from file doaj_import_links.last_harvest)"
   else
      echo "ERROR - file with date of last harvest found - $thisScriptPath/doaj_import_links.last_harvest. Still it has bad syntax (no YYYY-MM-DD included):"
      cat $thisScriptPath/doaj_import_links.last_harvest
      exit 1
   endif
endif

if ( $harvestFrom == '' ) then #lookup last harvest file
   if (! -e "$scriptDir/doaj_import_links.last_harvest") then
      echo "NOTICE - no argument given and file doaj_import_links.last_harvest not found. I will harvest since 1900-01-01" |  tee -a $logfile
      tail $logfile -n10 | mail -s "doaj_import_links.csh notice" "$librarianMail"
      set harvestFrom="1900-01-01";
   else
      if ( -z "$scriptDir/doaj_import_links.last_harvest") then
         echo "WARNING - file file doaj_import_links.last_harvest found, but it is empty. I will harvest since 1900-01-01" | tee -a $logfile
         tail $logfile -n10 | mail -s "doaj_import_links.csh warning" "$librarianMail"
         set harvestFrom="1900-01-01";
      else
         set harvestFrom=`head "$scriptDir/doaj_import_links.last_harvest" -n1 | sed 's/\s//g'`
         if ( `echo "$harvestFrom" | grep -c '[12][0-9]\{3\}\-[0-9]\{2\}\-[0-9]\{2\}' | bc` != 1 ) then #bad syntax
            printf "WARNING - file file doaj_import_links.last_harvest found, but has bad contents:\n`cat "$scriptDir/doaj_import_links.last_harvest" `\n\n I will harvest since 1900-01-01\n" | tee -a $logfile
            tail $logfile -n10 | mail -s "doaj_import_links.csh warning" "$librarianMail"
            set harvestFrom="1900-01-01";
         else
            echo "Last harvest date found in file doaj_import_links.last_harvest. Now harvesting from $harvestFrom" | tee -a $logfile
         endif   
      endif 
   endif
endif
if ( "$harvestFrom" == '' || `echo "$harvestFrom" | grep -c '[12][0-9]\{3\}\-[0-9]\{2\}\-[0-9]\{2\}' | bc` != 1 ) then #final check of the date
   echo "ERROR - date-from for harvest is empty or has bad syntax: $harvestFrom   Exiting..." | tee -a $logfile
   tail $logfile -n10 | mail -s "doaj_import_links.csh error" "$librarianMail"
   exit
endif

#harvest
if (! -e "$scriptDir/pyoaiharvest.py") then
   echo "ERROR - harvesting script $scriptDir/pyoaiharvest.py not found! It must be located in the same dir as this doaj_import_links.csh script. Exiting" | tee -a $logfile
   tail $logfile -n10 | mail -s "doaj_import_links.csh error" "$librarianMail"
   exit
endif
if ( `whereis xmllint | wc -w | bc` == 1 ) then
   echo "ERROR - tool xmllint not found. It is required for xml parsing and should be a part of your linux system. Exiting" | tee -a $logfile
   tail $logfile -n10 | mail -s "doaj_import_links.csh error" "$librarianMail"
   exit
endif

echo "performing HARVEST from $harvestFrom" | tee -a $logfile
set doajDataFile="$alephe_scratch/doaj_oai$today.xml"
python "$scriptDir/pyoaiharvest.py" -l "$doajOaiUrl" -f "$harvestFrom" -m 'oai_dc' -o "$doajDataFile" | tee -a $logfile
if (! -e $doajDataFile ) then
   echo "ERROR - harvesting failed. Output file $doajDataFile not found! Exiting" | tee -a $logfile
   tail $logfile -n10 | mail -s "doaj_import_links.csh error" "$librarianMail"
   exit
endif

#check harvested file
set harvestError=`xmllint --xpath "count(//*[local-name()='error'])" "$doajDataFile"`
if ( `echo $harvestError | bc` > 0 ) then
   printf "ERROR - harvesting failed. OAI claims an error: `xmllint --xpath "//*[local-name()='error']" "$doajDataFile"`  \nExiting\n" | tee -a $logfile
   tail $logfile -n10 | mail -s "doaj_import_links.csh error" "$librarianMail"
   exit
endif
set harvestRecords=`xmllint --xpath "count(//*[local-name()='record'])" "$doajDataFile"`
if ( `echo $harvestRecords | bc` == 0 ) then
   printf "NOTICE - no records found in harvested file $doajDataFile. Might no new records found, but this could be also some error.\n END `date`\n " | tee -a $logfile
   tail $logfile -n10 | mail -s "doaj_import_links.csh error" "$librarianMail"
   exit
endif
                                  

#force mode - delete all links to doaj from Aleph catalogue before import
if ( $force == 'Y') then
   echo 'WARNING - script run in FORCE mode!!' | tee -a $logfile
   echo "I will now delete all links do DOAJ from the catalogue (856 fields with url containg $doajLinkToJournalDomain" | tee -a $logfile
   #find all 856 fields
   csh -f $aleph_proc/p_ret_01 "$bibBase,,current_urls.sys,000000000,999999999,,00,00000000,99999999,00000000,99999999,,AND,NOT,8564#,,,,,,,,,,,,,,,,,,,,,00000000,99999999,OSU,03," | tee $dataScratch/doaj.ret01
   if ( `grep -c -i  -e 'error[^_]'  -e 'ORA-' $dataScratch/doaj.ret01 | bc` > 1 ) then
      echo "ERROR in ret-01 (see log above). Exiting!"  | tee -a $logfile
      cat $dataScratch/doaj.manage36 | mail -s "doaj_import_links.csh error in ret-01 (find 856 fields to be deleted - in force mode)" "$librarianMail"
      exit 1;
   endif
   csh -f $aleph_proc/p_print_03 "$bibBase,current_urls.sys,8564#,,,,,,,,current_urls.856.seq,A,,,,N," | tee $dataScratch/doaj.print03_force
   if ( `grep -c -i  -e 'error[^_]'  -e 'ORA-' $dataScratch/doaj.print03_force | bc` > 1 ) then
      echo "ERROR in print-03 (see log above). Exiting!"  | tee -a $logfile
      cat $dataScratch/doaj.print03_force | mail -s "doaj_import_links.csh error in print-03 (export 856 fields to be deleted - in force mode)" "$librarianMail"
      exit 1;
   endif
   grep "$doajLinkToJournalDomain" $dataScratch/current_urls.856.seq >$dataScratch/current_urls.856_doaj.seq
   mv $dataScratch/current_urls.856_doaj.seq $dataScratch/doaj2del
   echo "Found `wc -l <$dataScratch/doaj2del` fields linking to $doajLinkToJournalDomain in `awk '{print $1;}' $dataScratch/doaj2del | sort -u | wc -l` $bibBase records" | tee -a $logfile
   if ( `wc -l <$dataScratch/doaj2del | bc` == 0 ) then
      echo "Nothing to delete" | tee -a $logfile
   else
      echo "Going to delete them" | tee -a $logfile
      csh -f $aleph_proc/p_manage_18 "$bibBase,doaj2del,doaj2del.reject,doaj2del.doc_log,OLD,,,FULL,DEL,M,,,$doajImportCataloger,$doajImportCatalogerLevel," | tee $dataScratch/doaj.manage18_del
      if ( `grep -c -i  -e 'error[^_]'  -e 'ORA-' $dataScratch/doaj.manage18_del | bc` > 1 ) then
         echo "ERROR in manage18 - delete (see log above). Exiting!"  | tee -a $logfile
         cat $dataScratch/doaj.print03_force | mail -s "doaj_import_links.csh error in manage-18 (delete current 856 fields - in force mode)" "$librarianMail"
         exit 1;
      endif
      printf "\n\nDeleted `wc -l <$alephe_scratch/doaj2del.doc_log` records linking to $doajLinkToJournalDomain\n\n" | tee -a $logfile
   endif
endif

#extract dc identifiers, that matcg issn by syntax and converto to Aleph sequential format for matching
echo 'EXTRACT ISSNs FROM HARVESTED DATA ...' | tee -a $logfile
echo '<root xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/">' >"$doajDataFile.identifiers.tmp"
xmllint --xpath "//*[local-name()='identifier']" "$doajDataFile" | grep -o '[0-9X]\{4\}\-[0-9X]\{4\}' | sort -u | awk '{printf("%09d", NR); print " 022   L $$a"$0;}' >$dataScratch/doaj_issn

#match issn against database
echo "MATCH ISSNs AGAINST CURRENT DATA IN THE CATALOGUE (MANAGE-36) ..."  | tee -a $logfile
csh -f $aleph_proc/p_manage_36 "$bibBase,doaj_issn,doaj_issn.no,doaj_issn.match,doaj_issn.multi,ISSN,MUL,,N," | tee $dataScratch/doaj.manage36
echo "`wc -l $dataScratch/doaj_issn.no` ISSNs harvested from DOAJ not found in the Aleph catalogue"  | tee -a $logfile
echo "`wc -l $dataScratch/doaj_issn.match` match to 1 record in the catalogue. Going to import them."  | tee -a $logfile
echo  | tee -a $logfile
if ( `grep -c -i  -e 'error[^_]'  -e 'ORA-' $dataScratch/doaj.manage36 | bc` > 1 ) then
   echo "ERROR in manage-36 (see log above). Exiting!"  | tee -a $logfile
   cat $dataScratch/doaj.manage36 | mail -s "doaj_import_links.csh error in manage-36 (match harvest agaionst current data)" "$librarianMail"
   exit 1;
endif

if ( ! -z $dataScratch/doaj_issn.multi ) then
   echo "NOTICE - `wc -l $dataScratch/doaj_issn.multi` ISSNs harvested from DOAJ found in more than one record in the Aleph Catalogue (not imported). Their list:"  | tee -a $logfile
   cat $dataScratch/doaj_issn.multi  | tee -a $logfile
   cat $dataScratch/doaj_issn.multi | mail -s "doaj_import_links.csh notice - some issns for match to more than one records (not imported)" "$librarianMail"
endif

grep -v '^[0]\+\s' $dataScratch/doaj_issn.match >$dataScratch/doaj_issn.match.tmp
mv  $dataScratch/doaj_issn.match.tmp $dataScratch/doaj_issn.match
sed -i 's/ 022   L \$\$a/ /' $dataScratch/doaj_issn.match
awk -v dl="$doajLinkToJournal" -v dt="$doajLinkText" '{ print $2 " " $1 " 85641 L $$u" dl dt "$$4N";}' $dataScratch/doaj_issn.match | awk '{ sub ("@@@@-@@@@",$1); print substr($0,10);}' | sed 's/^\s\+//' >$dataScratch/doaj_856match

awk -v bb=$bibBase '{ print $1 bb;}' $dataScratch/doaj_856match | sort -u >$alephe_scratch/doaj_856match.sys
#export current records and replace doaj links to new ones if different
echo "EXPORTING CURRENT DATA (by harvested ISSNs) FOR CHECK AND REPLACE ..."  | tee -a $logfile

csh -f $aleph_proc/p_print_03 "$bibBase,doaj_856match.sys,8564#,,,,,,,,doaj_current.856,A,,,,N," | tee $dataScratch/doaj.print03
if ( `grep -c -i  -e 'error[^_]'  -e 'ORA-' $dataScratch/doaj.print03 | bc` > 1 ) then
   echo "ERROR in print-03 (see log above). Exiting!"  | tee -a $logfile
   cat $dataScratch/doaj.manage36 | mail -s "doaj_import_links.csh error in print-03 (export current records with doaj issns)" "$librarianMail"
   exit 1;
endif
#loop over new data. find them in the current DB export and replace changed + add new
rm -f $dataScratch/doaj_856toimport*
foreach newLinkSeq ( "`cat $dataScratch/doaj_856match`" )
   set newLinkSys = `echo "$newLinkSeq" | awk '{print $1;}'`
   set newLinkURL = `echo "$newLinkSeq" | grep -o '\$\$u[^\$]\+'`
   #Check if doaj fulltext url exists in the database already.
   #   If not, remove current links to doaj, add the new one, take other 856 fields and prepare for later import
   if ( `grep -c "^$newLinkSys.*$newLinkURL" $dataScratch/doaj.print03 | bc` >0 ) then
     echo "Journal URL $newLinkURL is already linek in sysno $newLinkSys"  | tee -a $logfile
   else
     echo "Adding URL $newLinkURL to sysno $newLinkSys for later import"  | tee -a $logfile
     grep "^$newLinkSys" $dataScratch/doaj.print03 | grep -v $doajLinkToJournalDomain >>$dataScratch/doaj_856toimport
     echo "$newLinkSeq" >>$dataScratch/doaj_856toimport
   endif
end

echo "IMPORTING NEW LINKS TO DOAJ (MANAGE-18) ..."  | tee -a $logfile
if ( -e $dataScratch/doaj_856toimport ) then
   if ( `wc -l <$dataScratch/doaj_856toimport | bc ` < 0 ) then
      echo "Nothing to import" | tee -a $logfile
      printf "\n\n END `date`" | tee -a $logfile
      exit 0
   endif
else
   echo "Nothing to import (harvested-data file $dataScratch/doaj_856toimport not found or has zero size)" | tee -a $logfile
   printf "\n\n END `date`" | tee -a $logfile
   exit 0
endif
csh -f $aleph_proc/p_manage_18 "$bibBase,doaj_856toimport,doaj_856toimport.reject,doaj_856toimport.doc_log,OLD,,,FULL,COR,M,,,$doajImportCataloger,$doajImportCatalogerLevel," | tee $dataScratch/doaj.manage18
if ( `grep -c -i  -e 'error[^_]'  -e 'ORA-' $dataScratch/doaj.manage18 | bc` > 1 ) then
   echo "ERROR in print-18 (see log above)." | tee -a $logfile
   cat $dataScratch/doaj.manage18 | mail -s "doaj_import_links.csh error in manage-18 (import new/changed links to DOAJ)" "$librarianMail"
endif
if ( -e $dataScratch/doaj_856toimport.reject ) then
   if ( `wc -l <$dataScratch/doaj_856toimport.reject | bc` > 0 ) then
   echo "WARNING - some records has been rejected on manage-18 import. Their list:" | tee -a $logfile
   cat $dataScratch/doaj_856toimport.reject  | tee -a $logfile
   cat $dataScratch/doaj_856toimport.reject | mail -s "doaj_import_links.csh warning - some records has been rejected on manage-18 import" "$librarianMail"
   endif
endif
printf "\n\n" | tee -a $logfile
set result="`wc -l <$alephe_scratch/doaj_856toimport.doc_log` records has been successfully updated with new or changed urls to DOAJ.org." 
echo "$result" | tee -a $logfile
cat $alephe_scratch/doaj_856toimport.doc_log | mail -s "doaj_import_links.csh $result" "$librarianMail"


#write timestamp of this harvest
date +"%Y-%m-%d" > $thisScriptPath/doaj_import_links.last_harvest


printf "\n\n END `date`" | tee -a $logfile  | tee -a $logfile

