#!/bin/bash
#
#==========================
# Duplicity Restore Script
#==========================
#
# Restores backup files to specified local folder from remote server or Google Drive
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
#Set directory to put backup files from remote machine
MAIN_RESTORE_DIR=/var/www/.backup
#Set SFTP connection and remote backup directory string
REMOTE_BACKUP_STR="sftp://backup_usr@example.com:22//var/backup"
#Set directory to mount Google Drive
GD_DIR=/mnt/google_drive
#Set connection string for Google Drive directory
GD_BACKUP_STR=file://$GD_DIR/backup
#Set SSH connection options, i.e. key file to use
SSH_OPTIONS="-oIdentityFile=/.ssh/backup_srv_key"
#Set GPG key ID, that was used for backup
GPG_KEY_ID=A111B222
#Set file with passphrase for GPG key, will be sourced later
PASSPHRASE_FILE=/root/.passphrase
#Set log file to use
RESTORE_LOG=/var/log/duplicity-restore-script.log
#END SETTINGS
#Create log file if it doesn't exist
if [ ! -f $RESTORE_LOG ]; then
	touch $RESTORE_LOG
	chmod 600 $RESTORE_LOG
fi
#Get current time for logging
START_TIME=`date +%a-%d.%m.%Y-%T-%Z`
#Variable to identify if errors occured during script execution
ERROR_HAPPENED=0;
#Check first argument
if [ "$1" == "srv" ]; then
	#If "srv", then will restore from remote server
	echo "Restoring from Remote Server..."
	echo "" >> $RESTORE_LOG
	echo "Restoring from Remote Server..." >> $RESTORE_LOG
	echo "Backup restore started at $START_TIME!"
	echo "Backup restore started at $START_TIME!" >> $RESTORE_LOG
	echo "" >> $RESTORE_LOG
elif [ "$1" == "gd" ]; then
	#If "gd", then will restore from Google Drive
	echo "Restoring from Google Drive..."
	echo "" >> $RESTORE_LOG
	echo "Restoring from Google Drive..." >> $RESTORE_LOG
	echo "Backup restore started at $START_TIME!"
	echo "Backup restore started at $START_TIME!" >> $RESTORE_LOG
	echo "" >> $RESTORE_LOG
else
	echo "Provide at least one argument when starting the script:"
	echo "./duplicity-restore-script.sh (srv|gd) [directory]"
	echo "srv - to restore from remote server via SFTP;"
	echo "gd - for mounting and restoring from Google Drive."
	echo "[directory] is local directory where to put backup files from remote backup."
	echo "If [directory] is not specified, then $MAIN_RESTORE_DIR from script settings section is used."
	exit 1;
fi
#Check if second argument is provided
if [ -n "$2" ] && [ -d "$2"]; then
	#Redefine defualt setting
	MAIN_RESTORE_DIR=$2
fi
#Create local directory for backup files if it doesn't exist
if [ ! -d $MAIN_RESTORE_DIR ]; then
	mkdir -p $MAIN_RESTORE_DIR
	if [ $? != 0 ]; then
		echo "Error: Couldn't find or create specified restore directory: $MAIN_RESTORE_DIR! Exiting now!"
		echo "Error: Couldn't find or create specified restore directory: $MAIN_RESTORE_DIR! Exiting now!" >> $RESTORE_LOG
		exit 1;
	fi
fi
#Load GPG passphrase
source $PASSPHRASE_FILE
export PASSPHRASE
#Depending on specified backup source, start restoration procedure
if [ $1 == "srv" ]; then
	#If "srv", then will restore from remote server
	#"other-data" restoration
	echo "Restoring \"other-data\"..." >> $RESTORE_LOG
	echo "" >> $RESTORE_LOG
	/usr/bin/duplicity restore --force --ssh-options=$SSH_OPTIONS --encrypt-key $GPG_KEY_ID $REMOTE_BACKUP_STR/other-data $MAIN_RESTORE_DIR/ >> $RESTORE_LOG 2>&1
	if [ $? != 0 ]; then
		echo "Error during other-data restoration!" >> $RESTORE_LOG
		echo "" >> $RESTORE_LOG
		ERROR_HAPPENED=1
	fi
	#"binaries" restoration
	echo "Restoring \"binaries\"..." >> $RESTORE_LOG
	echo "" >> $RESTORE_LOG
	/usr/bin/duplicity restore --force --ssh-options=$SSH_OPTIONS --encrypt-key $GPG_KEY_ID $REMOTE_BACKUP_STR/binaries $MAIN_RESTORE_DIR/ >> $RESTORE_LOG 2>&1
	if [ $? != 0 ]; then
		echo "Error during binaries restoration!" >> $RESTORE_LOG
		echo "" >> $RESTORE_LOG
		ERROR_HAPPENED=1
	fi
	#"main-data" restoration
	echo "Restoring \"main-data\"..." >> $RESTORE_LOG
	echo "" >> $RESTORE_LOG
	/usr/bin/duplicity restore --force --ssh-options=$SSH_OPTIONS --encrypt-key $GPG_KEY_ID $REMOTE_BACKUP_STR/main-data $MAIN_RESTORE_DIR/ >> $RESTORE_LOG 2>&1
	if [ $? != 0 ]; then
		echo "Error during main-data restoration!" >> $RESTORE_LOG
		echo "" >> $RESTORE_LOG
		ERROR_HAPPENED=1
	fi
elif [ $1 == "gd" ]; then
	#If "gd", then will restore from Google Drive
	#Try to unmount Google Drive (helps to avoid errors)
	fusermount -u $GD_DIR  > /dev/null 2>&1
	#Now mount Google Drive again
	mount $GD_DIR
	if [ $? != 0 ]; then
		echo "Error: Couldn't mount Google Drive!"
		echo "Error: Couldn't mount Google Drive!" >> $RESTORE_LOG
		echo "" >> $RESTORE_LOG
		ERROR_HAPPENED=1
	fi
	#Check that Google Drive is mounted successfully where expected
	mount | awk '{ print $3}' |grep -w $GD_DIR >/dev/null 
	if [ $? != 0 ]; then
		echo "Error: Google Drive is not mounted!."
		echo "Error: Google Drive is not mounted!." >> $RESTORE_LOG
		echo "Finished." >> $RESTORE_LOG
		exit 1;
	fi
	#"other-data" restoration
	echo "Restoring \"other-data\"..." >> $RESTORE_LOG
	echo "" >> $RESTORE_LOG
	/usr/bin/duplicity restore --force --encrypt-key $GPG_KEY_ID $GD_BACKUP_STR/other-data $MAIN_RESTORE_DIR/ >> $RESTORE_LOG 2>&1
	if [ $? != 0 ]; then
		echo "Error during other-data restoration!" >> $RESTORE_LOG
		echo "" >> $RESTORE_LOG
		ERROR_HAPPENED=1
	fi
	#"binaries" restoration
	echo "Restoring \"binaries\"..." >> $RESTORE_LOG
	echo "" >> $RESTORE_LOG
	/usr/bin/duplicity restore --force --encrypt-key $GPG_KEY_ID $GD_BACKUP_STR/binaries $MAIN_RESTORE_DIR/ >> $RESTORE_LOG 2>&1
	if [ $? != 0 ]; then
		echo "Error during binaries restoration!" >> $RESTORE_LOG
		echo "" >> $RESTORE_LOG
		ERROR_HAPPENED=1
	fi
	#"main-data" restoration
	echo "Restoring \"main-data\"..." >> $RESTORE_LOG
	echo "" >> $RESTORE_LOG
	/usr/bin/duplicity restore --force --encrypt-key $GPG_KEY_ID $GD_BACKUP_STR/main-data $MAIN_RESTORE_DIR/ >> $RESTORE_LOG 2>&1
	if [ $? != 0 ]; then
		echo "Error during main-data restoration!" >> $RESTORE_LOG
		echo "" >> $RESTORE_LOG
		ERROR_HAPPENED=1
	fi
	#Unmount Google Drive
	fusermount -u $GD_DIR
	if [ $? != 0 ]; then
		echo "Error during Google Drive unmounting after restoration!" >> $RESTORE_LOG
		echo "" >> $RESTORE_LOG
		ERROR_HAPPENED=1
	fi
fi
#Get current time for logging
END_TIME=`date +%a-%d.%m.%Y-%T-%Z`
echo "Backup restore finished at $END_TIME!"
echo "Backup restore finished at $END_TIME!" >> $RESTORE_LOG
echo "" >> $RESTORE_LOG
echo "Backup restore Start Time: $START_TIME" >> $RESTORE_LOG
echo "Backup restore End Time: $END_TIME" >> $RESTORE_LOG
echo "" >> $RESTORE_LOG
#Check if any errors occured and exit with appropriate code
if [ $ERROR_HAPPENED == 1 ]; then
	echo "***Errors during backup restoration!***"
	echo "***Errors during backup restoration!***" >> $RESTORE_LOG
	exit 1;
else
	echo "***Backup restoration succesfull! No errors!***"
	echo "***Backup restoration succesfull! No errors!***" >> $RESTORE_LOG
	exit 0;
fi