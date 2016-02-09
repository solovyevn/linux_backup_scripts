Linux Backup Scripts
====================

A set of backup scripts, that allow to perform full backup of essential data on a common Linux web server.


Duplicity Backup Scripts
========================

These scripts perform backup of the data from local server (the one running the scripts) to remote machine, using Duplicity tool with GPG encryption and SFTP for data protection. The scripts use 3 Duplicity filelist files to determine what to backup: 'main-data.exclude', 'other-data.exclude', 'binaries.exclude'. See each script file for variables containing various settings for script execution.


Requirements
------------

 - Duplicity
 - GPG


Duplicity Backup Script
-----------------------
Backups files to remote server via SFTP using Duplicity tool with GPG encryption. Calls "MySQL Dump Backup Script" and "MySQL Binlog Backup Script" to get local backup of MySQL data to further backup it to remote server. Creates installed packages list and copies several configs to root home for further backup. MySQL dumps, "main-data.exclude" and "other-data.exclude" files are backuped once a day at specified hour and "Duplicity Extra Backup Script" is run if enabled, "binaries.exclude" are backuped once a week at specified day on the same hour, MySQL binlogs are backuped several times a day as specified in settings. Log file is emptied and emailed to admin once a month on specified day, and also emailed anytime the error occurs. This script is intended to be the main "entry point": run every hour via cron, and it will run other backup scripts as needed.

See script file for possible settings.

Requires: mysql-binlog-backup.sh, mysql-dump-backup.sh


Duplicity Extra Backup Script
-----------------------------
Backups files prepared by main Duplicity Backup Script to Google Drive. Intended to be run by main "Duplicity Backup Script" as supplement to remote server backup. "main-data" and "other-data" are backuped everytime the script is ran, and "binaries" are backuped once a week on specified day. Log file is emptied and emailed to admin once a month on specified day, and also emailed anytime the error occurs.

See script file for possible settings.

Requires: Google Drive Fuse, in order for Google Drive to be mountable as local directory via fuse.


Duplicity Restore Script
------------------------
Restores data from remote machine, either remote server or Google Drive, to specified local directory. The files are basicly copied, decrypted and unpacked to local directory without overwriting the actual files corresponding to backeuped files. Selective restoration might be required, therefore distribution of backup files to various local directories has to be made manually after running this script.

See script file for possible settings.

Usage: 
       ./duplicity-restore-script.sh (srv|gd) [directory]
Required argument:
       srv - restore from remote server via SFTP;

       gd - for mounting and restoring from Google Drive. Requires Google Drive Fuse.

Optional argument:
       directory - local directory to put backup files from remote backup. If directory is not provided, then $MAIN_RESTORE_DIR from script settings section will be used.


MySQL Backup Scripts
====================

These scripts perform local backup of the MySQL databases. See each script file for variables containing settings.
In general dump backups have some limitations, see MySQL documentation for more information. The idea behind these scripts is to use binlog backups frequently (i.e. several times a day), and dump backups less frequently (i.e. once a day, once a week, depending on your DB usage).

These scripts create backup files on local filesystem, so other tools had to be used to transfer them somewhere. "Duplicity Backup Scripts" from this package use these scipts to backup these files to remote location.


MySQL Binlog Backup Script
--------------------------
Creates compressed backup files of binlogs. Flushes binlogs before proceesing them, so that only the new active one - "master" will be untouched and others all backed up. After backup is complete removes old binlogs.


MySQL Dump Backup Script
------------------------
Creates full compressed dumps of all databases.


MySQL Dump Restore Script
-------------------------
Restores all databases from dumps created by "MySQL Dump Backup Script".


LICENSE
=======

Copyright (c) 2013 Nikita Solovyev
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.