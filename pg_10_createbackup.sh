#!/bin/bash

set -e

unset http_proxy
unset https_proxy

export PWD=/home/ec2-user
export AWS_CONFIG_FILE=/home/ec2-user/.aws/config
export HOME=/home/ec2-user
SUBJECT="Postgresql DB weekly backup"

# Database credentials
PG_HOST=
PORT=
PG_USER=
PG_HOME=/usr/pgsql-10/bin
PG_DB_NAME=
PG_DB_SCHEMA_NAME=$1

# Vars
timestamp=$(date +%m-%d-%Y)
S3_PATH=
BKP_DIR=
EMAIL=

echo "PostgreSQL Database Logical Backup is started.."
# Dump database
$PG_HOME/pg_dump -h $PG_HOST -p $PORT -U $PG_USER -Fc $PG_DB_NAME -n $PG_DB_SCHEMA_NAME | gzip > $BKP_DIR/$BKP_FOLDER/${timestamp}_${PG_DB_NAME}_${PG_DB_SCHEMA_NAME}_PG10.gz
rc=$?
  if [ $rc -gt 0 ]
  then
    echo -e "### Failed to create Backup!"
    echo -e "Postgresql-10 Database: $PG_DB_NAME Failed to create Backup!\n Please check the log file " | mail -s "$SUBJECT" $EMAIL
    exit 1
  fi
echo "* Database:" $PG_DB_NAME "is archived at timestamp:" $timestamp

# copy to S3
aws s3 cp $BKP_DIR/${timestamp}_${PG_DB_NAME}_${PG_DB_SCHEMA_NAME}_PG10.gz  s3://$S3_PATH/${timestamp}_${PG_DB_NAME}_${PG_DB_SCHEMA_NAME}_PG10.gz --storage-class STANDARD_IA
rc=$?
  if [ $rc -gt 0 ]
  then
    echo -e "### Failed to copy backup file into S3!"
    echo -e "Postgresql-9 Database: $PG_DB_NAME Failed to copy backup file into S3!\n Please check the log file " | mail -s "$SUBJECT" $EMAIL
    exit 1
  fi
echo "* Database:" $PG_DB_NAME "backup file was copied into s3 $S3_PATH:" $timestamp  
# Delete local file
rm $BKP_DIR/${timestamp}_${PG_DB_NAME}_${PG_DB_SCHEMA_NAME}_PG10.gz
echo -e "Postgresql-10 Database: $PG_DB_NAME schema: $PG_DB_SCHEMA_NAME  backup completed" | mail -s "$SUBJECT" $EMAIL
