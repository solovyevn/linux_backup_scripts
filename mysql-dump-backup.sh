#!/bin/bash
#
#===================================
# MySQL Database Dump Backup Script
#===================================
#
# Dumps MySQL DBs to specified directory
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
#Set admin email, to get notifications
EMAIL="admin@example.com"
#Set database credentials, root user to get access to all DBs
DB_USER=root
DB_PASS="password"
#Set folder to put backup files
BASE_BACK_FLDR=/var/dbs/backup
#Set log file to use
BACKUP_LOG=/var/log/mysql-dump-backup-script.log
#END SETTINGS
#Create log file if it doesn't exist
if [ ! -f $BACKUP_LOG ]; then
    touch $BACKUP_LOG
	chmod 600 $BACKUP_LOG
fi
#Get current time to use for logging
NOW=$(date +"%T-%m-%d-%Y")
#Test MySQL connection, and if connection  fails send email to admin and exit with error code
CON_TEST=$(mysqladmin ping -u $DB_USER -p$DB_PASS 2>/dev/null)
if [ "$CON_TEST" != "mysqld is alive" ]; then
    echo "Error: Unable to connected to MySQL Server, exiting!"
	echo "Error: Unable to connected to MySQL Server, exiting! DateTime: $NOW" > $BACKUP_LOG
	echo "Error: Unable to connected to MySQL Server, exiting! DateTime: $NOW" | mail -s "MySQL Dump Failed!" $BACKUP_EMAIL
    exit 1;
fi
#Flush DB logs and remove old ones
mysqladmin flush-logs -u $DB_USER -p$DB_PASS
master_binlog=$(mysql -u $DB_USER -p$DB_PASS -e "show master status" 2>/dev/null | grep -o mysql-bin.[0-9]*)
mysql -u $DB_USER -p$DB_PASS -e "PURGE BINARY LOGS TO \"$master_binlog\""
#Get existing DB list
DBS="$(mysql -u $DB_USER -p$DB_PASS -Bse 'show databases')"
#Get current time to calculate the time spent on dumping
START=$(date +%s)
#Dump each DB
for db in $DBS
do
	#Use DB name as backup filename
	FILE=$BASE_BACK_FLDR/$db.gz
	#Compress each file with gzip to save storage space
	mysqldump -u $DB_USER -p$DB_PASS $db --single-transaction --quick --events | gzip -9 > $FILE
done
#Calculate time spent on dumping
echo "Total time : $(($(date +%s) - $START))/n" > $BACKUP_LOG
exit 0;
