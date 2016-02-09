#!/bin/bash
#
#=========================
# Duplicity Backup Script
#=========================
#
# Backups data to remote server
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
#Set hour for backup, it's assumed that this script is run every hour via cron job
BACKUP_HOUR=0
#Set day of the week for "binaries" backup, "main-data" and "other-data" are backed up everytime the script is ran
BINARIES_DAY=6
#Set binlog backup multiple, i.e. every this value hours binlogs will be backuped
BINLOGS_BACKUP_MULTIPLE=3 
#Set duplicity full backup period
FULL_BACKUP_TIME="1M"
#Set number of full backups for duplicity to keep
FULL_BACKUP_COUNT=6
#Set folder containing duplicity backup filelist files: 'main-data.exclude', 'other-data.exclude', 'binaries.exclude'
FILELISTS_FLDR=/etc/backup-file-lists
#Set duplicity full backup time for binlogs only
FULL_BACKUP_TIME_BINLOGS="1D"
#Set number of full binlogs backups for duplicity to keep
FULL_BACKUP_COUNT_BINLOGS=7
#Set folder containing DB dumps
DB_DUMPS_FLDR=/var/dbs/backup
#Set folder containing binlogs backup files
BINLOGS_BACKUP_FLDR=$DB_DUMPS_FLDR/binlogs
#Set absolute path to folder containing other backup scripts (for MySQL backup and duplicity extra backup script)
BACKUP_SCRIPTS_FLDR=/etc/my-scripts
#Set to true to use duplicity-extra-backup.sh script
USE_EXTRA_SCRIPT=true
#Set SFTP connection and remote backup directory string
REMOTE_BACKUP_STR="sftp://backup_usr@example.com:22//var/backup"
#Set SSH connection options, i.e. key file to use
SSH_OPTIONS="-oIdentityFile=/.ssh/backup_srv_key"
#Set GPG key ID, that was used for backup
GPG_KEY_ID=A111B222
#Set file with passphrase for GPG key, will be sourced later
PASSPHRASE_FILE=/root/.passphrase
#Set log file to use
BACKUP_LOG=/var/log/duplicity-backup-script.log
#Set special backup directory, will be used to create installed packages list
SPECIAL_BACKUP_DIR=/root/.special_backup
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
echo "Backup to Remote Server started at $START_TIME!" >> $BACKUP_LOG
echo "" >> $BACKUP_LOG
#Load GPG passphrase
source $PASSPHRASE_FILE
export PASSPHRASE
#Start backup procedures
if [[ $HOUR == $BACKUP_HOUR ]] ; then
	#Perform main backup procedures once a day at specified hour
	#Use mysql-dump-backup.sh script to get local DB dumps
	$BACKUP_SCRIPTS_FLDR/mysql-dump-backup.sh
	if [ $? != 0 ]; then
		echo "Error during DB dump!" >> $BACKUP_LOG
		echo "" >> $BACKUP_LOG
		ERROR_HAPPENED=1
	fi
	#Delete local binlogs backup files to save storage space, as we don't need them, because full dump backup is performed
	find $BINLOGS_BACKUP_FLDR/ -type f -delete
	if [ $? != 0 ]; then
		echo "Error during DB binlog files removal!" >> $BACKUP_LOG
		echo "" >> $BACKUP_LOG
		ERROR_HAPPENED=1
	fi
	#"main-data" backup
	ionice -c2 -n7 nice -n10 /usr/bin/duplicity --ssh-options=$SSH_OPTIONS --full-if-older-than $FULL_BACKUP_TIME --encrypt-key $GPG_KEY_ID --exclude-globbing-filelist $FILELISTS_FLDR/main-data.exclude / $REMOTE_BACKUP_STR/main-data >> $BACKUP_LOG 2>&1
	if [ $? != 0 ]; then
		echo "Error during main-data backup!" >> $BACKUP_LOG
		echo "" >> $BACKUP_LOG
		ERROR_HAPPENED=1
	fi
	#Remove old backups if needed
	ionice -c2 -n7 nice -n10 /usr/bin/duplicity --ssh-options=$SSH_OPTIONS remove-all-but-n-full $FULL_BACKUP_COUNT --force $REMOTE_BACKUP_STR/main-data >> $BACKUP_LOG 2>&1
	if [ $? != 0 ]; then
		echo "Error during removal of outdated main-data backups!" >> $BACKUP_LOG
		echo "" >> $BACKUP_LOG
		ERROR_HAPPENED=1
	fi
	#Prepare "special" backup files in /root/
	#Create "special" backup folder if it doesn't exist
	if [ ! -d $SPECIAL_BACKUP_DIR ]; then
		mkdir $SPECIAL_BACKUP_DIR
		chmod 770 $SPECIAL_BACKUP_DIR 
	fi
	#Create file for installed packages list if it doesn't exist
	if [ ! -f $SPECIAL_BACKUP_DIR/package_list.txt ]; then
		touch $SPECIAL_BACKUP_DIR/package_list.txt
		chmod 660 $SPECIAL_BACKUP_DIR/package_list.txt
	fi
	#Make sure installed packages file is empty
	cat /dev/null > $SPECIAL_BACKUP_DIR/package_list.txt
	#Create actual installed packages list
	rpm -qa --qf '%{NAME}\n' > $SPECIAL_BACKUP_DIR/package_list.txt
	#Copy several configs to "special" backup directory
	/bin/cp -afr --parents /etc/fstab $SPECIAL_BACKUP_DIR/
	/bin/cp -afr --parents /etc/resolv.conf $SPECIAL_BACKUP_DIR/
	/bin/cp -afr --parents /etc/networks $SPECIAL_BACKUP_DIR/
	/bin/cp -afr --parents /etc/sysconfig/network* $SPECIAL_BACKUP_DIR/
	/bin/cp -afr --parents /etc/hosts $SPECIAL_BACKUP_DIR/
	/bin/cp -afr --parents /etc/modprobe* $SPECIAL_BACKUP_DIR/
	/bin/cp -afr --parents /etc/NetworkManager $SPECIAL_BACKUP_DIR/
	/bin/cp -afr --parents /etc/grub.conf $SPECIAL_BACKUP_DIR/
	#/bin/cp -afr --parents /etc/mdadm.conf $SPECIAL_BACKUP_DIR/
	#"other-data" backup
	ionice -c2 -n7 nice -n10 /usr/bin/duplicity --ssh-options=$SSH_OPTIONS --full-if-older-than $FULL_BACKUP_TIME --encrypt-key $GPG_KEY_ID --exclude-globbing-filelist $FILELISTS_FLDR/other-data.exclude / $REMOTE_BACKUP_STR/other-data >> $BACKUP_LOG 2>&1
	if [ $? != 0 ]; then
		echo "Error during other-data backup!" >> $BACKUP_LOG
		echo "" >> $BACKUP_LOG
		ERROR_HAPPENED=1
	fi
	#Remove old backups if needed
	ionice -c2 -n7 nice -n10 /usr/bin/duplicity --ssh-options=$SSH_OPTIONS remove-all-but-n-full $FULL_BACKUP_COUNT --force $REMOTE_BACKUP_STR/other-data >> $BACKUP_LOG 2>&1
	if [ $? != 0 ]; then
		echo "Error during removal of outdated other-data backups!" >> $BACKUP_LOG
		echo "" >> $BACKUP_LOG
		ERROR_HAPPENED=1
	fi
	#Perform binaries backup at specified day
	if [[ $DAY_OF_THE_WEEK == $BINARIES_DAY ]]; then
		#"binaries" backup
		ionice -c2 -n7 nice -n10 /usr/bin/duplicity --ssh-options=$SSH_OPTIONS --full-if-older-than $FULL_BACKUP_TIME --encrypt-key $GPG_KEY_ID --exclude-globbing-filelist $FILELISTS_FLDR/binaries.exclude / $REMOTE_BACKUP_STR/binaries >> $BACKUP_LOG 2>&1
		if [ $? != 0 ]; then
			echo "Error during binaries backup!" >> $BACKUP_LOG
			echo "" >> $BACKUP_LOG
			ERROR_HAPPENED=1
		fi
		#Remove old backups if needed
		ionice -c2 -n7 nice -n10 /usr/bin/duplicity --ssh-options=$SSH_OPTIONS remove-all-but-n-full $FULL_BACKUP_COUNT --force $REMOTE_BACKUP_STR/binaries >> $BACKUP_LOG 2>&1
		if [ $? != 0 ]; then
			echo "Error during removal of outdated binaries backups!" >> $BACKUP_LOG
			echo "" >> $BACKUP_LOG
			ERROR_HAPPENED=1
		fi
	fi
	#Get current time for logging
	END_TIME=`date +%a-%d.%m.%Y-%T-%Z`
	#Call extra backup script if required
	if [ "$USE_EXTRA_SCRIPT" == true ]; then
		EXTRA_START_TIME=`date +%a-%d.%m.%Y-%T-%Z`
		echo "Calling extra-backup-script at $EXTRA_START_TIME ..." >> $BACKUP_LOG
		echo "" >> $BACKUP_LOG
		$BACKUP_SCRIPTS_FLDR/duplicity-extra-backup.sh
		EXTRA_END_TIME=`date +%a-%d.%m.%Y-%T-%Z`
		echo "Returned control from extra-backup-script at $EXTRA_END_TIME." >> $BACKUP_LOG
		echo "" >> $BACKUP_LOG
	fi
	#Remove DB dump backup files to save storage space
	find $DB_DUMPS_FLDR/ -type f -delete
	if [ $? != 0 ]; then
		echo "Error during DB backup files removal!" >> $BACKUP_LOG
		echo "" >> $BACKUP_LOG
		ERROR_HAPPENED=1
	fi
else
	#Perform binlogs only backup several times a day as specified in settings
	if [ $HOUR%$$BINLOGS_BACKUP_MULTIPLE == 0 ] ; then
		#Use mysql-binlog-backup.sh script to get local binlogs backup
		$BACKUP_SCRIPTS_FLDR/mysql-binlog-backup.sh
		if [ $? != 0 ]; then
			echo "Error during mysql-binlog creation!" >> $BACKUP_LOG
			echo "" >> $BACKUP_LOG
			ERROR_HAPPENED=1
		fi
		#"binlogs" backup
		ionice -c2 -n7 nice -n10 /usr/bin/duplicity --ssh-options=$SSH_OPTIONS --full-if-older-than $FULL_BACKUP_TIME_BINLOGS --encrypt-key $GPG_KEY_ID $BINLOGS_BACKUP_FLDR/ $REMOTE_BACKUP_STR/mysql-binlogs >> $BACKUP_LOG 2>&1 
		if [ $? != 0 ]; then
			echo "Error during mysql-binlog backup!" >> $BACKUP_LOG
			echo "" >> $BACKUP_LOG
			ERROR_HAPPENED=1
		fi
		#Remove old backups if needed
		ionice -c2 -n7 nice -n10 /usr/bin/duplicity --ssh-options=$SSH_OPTIONS remove-all-but-n-full $FULL_BACKUP_COUNT_BINLOGS --force $REMOTE_BACKUP_STR/mysql-binlogs >> $BACKUP_LOG 2>&1
		if [ $? != 0 ]; then
			echo "Error during removal of outdated mysql-binlog backups!" >> $BACKUP_LOG
			echo "" >> $BACKUP_LOG
			ERROR_HAPPENED=1
		fi
	fi
	#Get current time for logging
	END_TIME=`date +%a-%d.%m.%Y-%T-%Z`
fi
echo "Backup to Remote Server finished at $END_TIME!" >> $BACKUP_LOG
echo "" >> $BACKUP_LOG
echo "Backup Start Time: $START_TIME" >> $BACKUP_LOG
echo "Backup End Time: $END_TIME" >> $BACKUP_LOG
echo "" >> $BACKUP_LOG
#On specified day of the month send backup log to admin and empty it
if [[ ( $HOUR == 0 ) || ( "$HOUR" == "00" ) ]] && [[ $DAY_OF_THE_MONTH == $LOG_SEND_DAY ]]; then
	cat $BACKUP_LOG | mail -s "Backup to Remote Server Log ($START_TIME)" $ADMIN_EMAIL
	cat /dev/null > $BACKUP_LOG
fi
# If errors occured, then send backup log to admin and exit with error code
if [ $ERROR_HAPPENED == 1 ]; then
	cat $BACKUP_LOG | mail -s "Errors during backup to Remote Server at $START_TIME" $ADMIN_EMAIL
	exit 1;
fi
exit 0;