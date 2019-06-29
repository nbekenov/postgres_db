#!/bin/sh

#set params in order to curl meta-data 
export NO_PROXY=169.254.169.254
export SHELL=/bin/bash
export PWD=/home/ec2-user
export AWS_CONFIG_FILE=/home/ec2-user/.aws/config
export HOME=/home/ec2-user

FOLDER_NAME=$1
LAST_MODIFIED_DATE=$(aws s3  ls cxtwh-postgresql-backup/$FOLDER_NAME/ --recursive | sort | tail -1 | awk '{print $1}')
LAST_MODIFIED_DATE_EPOCH=$(date --date="$LAST_MODIFIED_DATE" +%s)
echo "LAST_MODIFIED_DATE_EPOCH = $LAST_MODIFIED_DATE_EPOCH"


TIMESTAMP=$(date +%s -d '2 day ago')
echo "TIMESTAMP_EPOCH = $TIMESTAMP"

if [ "$LAST_MODIFIED_DATE_EPOCH" -le "$TIMESTAMP" ]; then
    echo "PG Backup was not been created 1 day ago"
    echo "PG Backup was not been created 1 day ago." | mail -s "$FOLDER_NAME Backup WARNING: POSTGRESQL BACKUP WAS NOT BEEN CREATED" <email>
else
   echo "PG Backup was successfully been created 1 day ago"
fi
