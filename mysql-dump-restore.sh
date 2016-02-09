#!/bin/bash
#
#================================================
# MySQL Database Restore From Dump Backup Script
#================================================
#
# Restores MySQL DBs from existing dump files
#
#Copyright (c) 2013 Nikita Solovyev
#All rights reserved.
#
#Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
#
#1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
#
#2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer 
#in the documentation and/or other materials provided with the distribution.
#
#3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived 
#from this software without specific prior written permission.
#
#THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, 
#BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL 
#THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES 
#(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
#HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
#ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#START SETTINGS
#Set database credentials, root user to get access to all DBs
DB_USER=root
DB_PASS="password"
#Set folder containing DB dump backup files
BASE_BACK_FLDR=/var/dbs/backup
#Set log file to use
RESTORE_LOG=/var/dbs/backup/mysql-dump-restore-script.log
#END SETTINGS
#Create log file if it doesn't exist
if [ ! -f $RESTORE_LOG ]; then
    touch $RESTORE_LOG
	chmod 600 $RESTORE_LOG
fi
#Get current time for logging
START_TIME=`date +%a-%d.%m.%Y-%T-%Z`
#Variable to check if everything went as expected
ERROR_HAPPENED=0
#Try to restart MySQL server
echo "MySQL dump restore started at $START_TIME."
echo "MySQL dump restore started at $START_TIME." >> $RESTORE_LOG
echo "" >> $RESTORE_LOG
echo "Trying to restart mysqld service..."
echo "Trying to restart mysqld service..." >> $RESTORE_LOG
echo "" >> $RESTORE_LOG
service mysqld stop
service mysqld start >> $RESTORE_LOG 2>&1
if [ $? == 0 ]; then
	#MySQL server restart succeeded
    echo "Service mysqld restarted."
	echo "Service mysqld restarted." >> $RESTORE_LOG
	echo "" >> $RESTORE_LOG
	#Wait, to be sure the server is fully started
	sleep 10
	#Test MySQL connection
	CON_TEST=$(mysqladmin ping -u $DB_USER -p$DB_PASS 2>/dev/null)
	if [ "$CON_TEST" == "mysqld is alive" ]; then
		#Test connection to MySQL succeeded
		#Start to process the dumps
		for f in $BASE_BACK_FLDR/*.gz
		do
			#Gunzip and restore the dump
			gunzip < $f | mysql -u $DB_USER -p$DB_PASS
			#Log the result
			if [ $? != 0 ]; then
				echo "Error during $f restore!"
				echo "Error during $f restore!" >> $RESTORE_LOG
				echo "" >> $RESTORE_LOG
				ERROR_HAPPENED=1
			else
				echo "$f OK! Restored successfully."
				echo "$f OK! Restored successfully." >> $RESTORE_LOG
				echo "" >> $RESTORE_LOG
			fi
		done
		#Try  to restart MySQL server
		echo "Restart mysqld service to test..."
		echo "Restart mysqld service to test..." >> $RESTORE_LOG
		echo "" >> $RESTORE_LOG
		service mysqld restart >> $RESTORE_LOG 2>&1
		#If restarted succesfully, then probably everything went well
		if [ $? == 0 ]; then
			echo "Service mysqld restarted successfully..."
			echo "Service mysqld restarted successfully..." >> $RESTORE_LOG
			echo "" >> $RESTORE_LOG
			echo "You may now apply any binlog updates manually if needed."
			echo "You may now apply any binlog updates manually if needed." >> $RESTORE_LOG
			echo "" >> $RESTORE_LOG
			echo "MySQL dump files may be deleted now manually from $BASE_BACK_FLDR."
			echo "MySQL dump files may be deleted now manually from $BASE_BACK_FLDR." >> $RESTORE_LOG
			echo "" >> $RESTORE_LOG
		else
			echo "Failed to restart mysqld! See log $RESTORE_LOG for details!"
			echo "Failed to restart mysqld! See log $RESTORE_LOG for details!" >> $RESTORE_LOG
			echo "" >> $RESTORE_LOG
			ERROR_HAPPENED=1
		fi
	else
		#Test connection to MySQL failed
		echo "Failed to ping mysqld! Exiting..."
		echo "Failed to ping mysqld! Exiting..." >> $RESTORE_LOG
		echo "" >> $RESTORE_LOG
		ERROR_HAPPENED=1
	fi
else
	#MySQL server restart failed
	echo "Failed to restart mysqld! Exiting..."
	echo "Failed to restart mysqld! Exiting..." >> $RESTORE_LOG
	echo "" >> $RESTORE_LOG
	ERROR_HAPPENED=1
fi
#Get current time for logging
END_TIME=`date +%a-%d.%m.%Y-%T-%Z`
echo "MySQL dump restore finished at $END_TIME."
echo "MySQL dump restore finished at $END_TIME." >> $RESTORE_LOG
echo "" >> $RESTORE_LOG
echo "MySQL dump restore Start Time: $START_TIME" >> $RESTORE_LOG
echo "MySQL dump restore End Time: $END_TIME" >> $RESTORE_LOG
echo "" >> $RESTORE_LOG
#Check if any errors occured
if [ $ERROR_HAPPENED == 0 ]; then
	#Everything went well, exit with success code
	echo "Done!"
	exit 0;
else
	#Something went wrong, exit with error code
	echo "Errors during MySQL dump restoration! See log file $RESTORE_LOG for details!"
	exit 1;
fi