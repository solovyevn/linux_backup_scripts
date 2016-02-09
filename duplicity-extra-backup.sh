#!/bin/bash
#
#===============================
# Duplicity Extra Backup Script
#===============================
#
# Backups data prepared by main Duplicity Backup Script to Google Drive
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
#Set admin email to get notifications
ADMIN_EMAIL=admin@example.com;
#Set month day to send existing backup log to admin and empty it. If an error will occur the log will be sent instantly.
LOG_SEND_DAY=1
#Set day of the week for "binaries" backup, "main-data" and "other-data" are backed up everytime the script is ran
BINARIES_DAY=6
#Set duplicity full backup period
FULL_BACKUP_TIME="1M"
#Set number of full backups for duplicity to keep
FULL_BACKUP_COUNT=1
#Set folder containing duplicity backup filelist files: 'main-data.exclude', 'other-data.exclude', 'binaries.exclude'
FILELISTS_FLDR=/etc/backup-file-lists
#Set directory to mount Google Drive
GD_DIR=/mnt/google_drive
#Set connection string for Google Drive directory
REMOTE_BACKUP_STR=file://$GD_DIR/backup
#Set GPG key ID to use for backup
GPG_KEY_ID=A111B222
#Set file with passphrase for GPG key, will be sourced later
PASSPHRASE_FILE=/root/.passphrase
#Set log file to use
BACKUP_LOG=/var/log/duplicity-extra-backup-script.log
#END SETTINGS
#Create log file if it doesn't exist
if [ ! -f $BACKUP_LOG ]; then
	touch $BACKUP_LOG
	chmod 600 $BACKUP_LOG
fi
#Get current time for logging
START_TIME=`date +%a-%d.%m.%Y-%T-%Z`
#Get current hour, month day and week day to determine what to backup
HOUR=$(date +%H)
DAY_OF_THE_MONTH=$(date +%d)
DAY_OF_THE_WEEK=$(date +%u)
#Variable to identify if errors occured during script execution
ERROR_HAPPENED=0;
echo "" >> $BACKUP_LOG
echo "Backup to Google Drive started at $START_TIME!" >> $BACKUP_LOG
echo "" >> $BACKUP_LOG
#Load GPG passphrase
source $PASSPHRASE_FILE
export PASSPHRASE
#Try to unmount Google Drive (helps to avoid errors)
fusermount -u $GD_DIR  > /dev/null 2>&1
#Now mount Google Drive again
mount $GD_DIR
if [ $? != 0 ]; then
	echo "Error: Couldn't mount Google Drive!" >> $BACKUP_LOG
	echo "" >> $BACKUP_LOG
	ERROR_HAPPENED=1
fi
#Check that Google Drive is mounted successfully where expected
mount | awk '{ print $3}' |grep -w $GD_DIR >/dev/null
if [ $? == 0 ]; then
	#Mounted successfully, proceed with backup
	#"main-data" backup
	ionice -c2 -n7 nice -n10 /usr/bin/duplicity --full-if-older-than $FULL_BACKUP_TIME --encrypt-key $GPG_KEY_ID --exclude-globbing-filelist $FILELISTS_FLDR/main-data.exclude / $REMOTE_BACKUP_STR/main-data >> $BACKUP_LOG 2>&1
	if [ $? != 0 ]; then
		echo "Error during main-data backup!" >> $BACKUP_LOG
		echo "" >> $BACKUP_LOG
		ERROR_HAPPENED=1
	fi
	#Remove old backups if needed
	ionice -c2 -n7 nice -n10 /usr/bin/duplicity remove-all-but-n-full $FULL_BACKUP_COUNT --force $REMOTE_BACKUP_STR/main-data >> $BACKUP_LOG 2>&1
	if [ $? != 0 ]; then
		echo "Error during removal of outdated main-data backups!" >> $BACKUP_LOG
		echo "" >> $BACKUP_LOG
		ERROR_HAPPENED=1
	fi
	#"other-data" backup
	ionice -c2 -n7 nice -n10 /usr/bin/duplicity --full-if-older-than $FULL_BACKUP_TIME --encrypt-key $GPG_KEY_ID --exclude-globbing-filelist $FILELISTS_FLDR/other-data.exclude / $REMOTE_BACKUP_STR/other-data >> $BACKUP_LOG 2>&1
	if [ $? != 0 ]; then
		echo "Error during other-data backup!" >> $BACKUP_LOG
		echo "" >> $BACKUP_LOG
		ERROR_HAPPENED=1
	fi
	#Remove old backups if needed
	ionice -c2 -n7 nice -n10 /usr/bin/duplicity remove-all-but-n-full $FULL_BACKUP_COUNT --force $REMOTE_BACKUP_STR/other-data >> $BACKUP_LOG 2>&1
	if [ $? != 0 ]; then
		echo "Error during removal of outdated other-data backups!" >> $BACKUP_LOG
		echo "" >> $BACKUP_LOG
		ERROR_HAPPENED=1
	fi
	if [ $DAY_OF_THE_WEEK == $BINARIES_DAY ]; then
		#"binaries" backup
		ionice -c2 -n7 nice -n10 /usr/bin/duplicity --full-if-older-than $FULL_BACKUP_TIME --encrypt-key $GPG_KEY_ID --exclude-globbing-filelist $FILELISTS_FLDR/binaries.exclude / $REMOTE_BACKUP_STR/binaries >> $BACKUP_LOG 2>&1
		if [ $? != 0 ]; then
			echo "Error during binaries backup!" >> $BACKUP_LOG
			echo "" >> $BACKUP_LOG
			ERROR_HAPPENED=1
		fi
		#Remove old backups if needed
		ionice -c2 -n7 nice -n10 /usr/bin/duplicity remove-all-but-n-full $FULL_BACKUP_COUNT --force $REMOTE_BACKUP_STR/binaries >> $BACKUP_LOG 2>&1
		if [ $? != 0 ]; then
			echo "Error during removal of outdated binaries backups!" >> $BACKUP_LOG
			echo "" >> $BACKUP_LOG
			ERROR_HAPPENED=1
		fi
	fi
	#Unmount Google Drive
	fusermount -u $GD_DIR
	if [ $? != 0 ]; then
		echo "Error during Google Drive unmounting after backup!" >> $BACKUP_LOG
		echo "" >> $BACKUP_LOG
		ERROR_HAPPENED=1
	fi
else
	#Error remounting Google Drive, unable to perform backup
	echo "Error: Google Drive in not mounted! Exiting..." >> $BACKUP_LOG
	echo "" >> $BACKUP_LOG
	ERROR_HAPPENED=1
fi
#Get current time for logging
END_TIME=`date +%a-%d.%m.%Y-%T-%Z`
echo "Backup to Google Drive finished at $END_TIME!" >> $BACKUP_LOG
echo "" >> $BACKUP_LOG
echo "Backup Start Time: $START_TIME" >> $BACKUP_LOG
echo "Backup End Time: $END_TIME" >> $BACKUP_LOG
echo "" >> $BACKUP_LOG
#On specified day of the month send backup log to admin and empty it
if [[ ( $HOUR == 0 ) || ( "$HOUR" == "00" ) ]] && [[ $DAY_OF_THE_MONTH == $LOG_SEND_DAY ]]; then
	cat $BACKUP_LOG | mail -s "Backup to Google Drive Log ($START_TIME)" $ADMIN_EMAIL
	cat /dev/null > $BACKUP_LOG
fi
# If errors occured, then send backup log to admin and exit with error code
if [ $ERROR_HAPPENED == 1 ]; then
	cat $BACKUP_LOG | mail -s "Errors during backup to Google Drive at $START_TIME" $ADMIN_EMAIL
	exit 1;
fi
exit 0;