#!/bin/sh
# Creates PostgresSQL DB volumes consitent backup
# The script performs the follwoing actions:
### 1. stops PostgresSQL DB
### 2. unmounts the RAID 
### 3. creates EBS volumes snapshots
### 4. mount RAID
### 5. starts PostgresSQL DB
 
DB_VERSION=PG_10
RAID_NAME=PG10RAID
PG_MOUNT_POINT=/sasdata/postgresql
BKP_DIR=/depot/postgresql_bkp
LOG_IDR=$BKP_DIR/logs
EMAIL=
SUBJECT="PostgresSQL DB backup ERROR"
timestamp=$(date +%m-%d-%Y)

#set proxy
export NO_PROXY=169.254.169.254
export http_proxy=
export https_proxy=
export SHELL=/bin/bash
export PWD=/home/ec2-user
export AWS_CONFIG_FILE=/home/ec2-user/.aws/config
export HOME=/home/ec2-user

# func for sending notifications
send_notify(){
	local message=$1
	echo -e $message | mail -s "$SUBJECT" $EMAIL 
}


# Get instance id and region
get_aws_params(){
	export NO_PROXY=169.254.169.254
	INSTANCE_ID=$(curl -s --connect-timeout 12 http://169.254.169.254/latest/meta-data/instance-id)
	if [ -z "$INSTANCE_ID" ]
	then
		echo "## ERROR: INSTANCE_ID is empty" >> $LOG_IDR/${DB_VERSION}_consistent_backup_${timestamp}.log
		send_notify "## ERROR: INSTANCE_ID is empty"
		exit 1
	else
		echo INSTANCE_ID=$INSTANCE_ID
	fi
	
	EC2_REGION=$(curl -s --connect-timeout 12 http://169.254.169.254/latest/meta-data/placement/availability-zone | sed -e 's/\([1-9]\).$/\1/g')
	if [ -z "$EC2_REGION" ]
	then
		echo "## ERROR: AWS_DEFAULT_REGION is empty" >> $LOG_IDR/${DB_VERSION}_consistent_backup_${timestamp}.log
		send_notify "## ERROR: AWS_DEFAULT_REGION is empty"
		exit 1
	else
		echo AWS_DEFAULT_REGION=$EC2_REGION
	fi
}

# Start or Stop postgresql
cmd_postgresql() {
  local var1=$1
  echo "## ${var1}ing postgresql"
  sudo systemctl $var1 postgresql-10 2>> $LOG_IDR/${DB_VERSION}_consistent_backup_${timestamp}.log
  rc=$?
  if [ $rc -gt 0 ]
  then
    send_notify "### Failed to {$var1} Postgresql!\n Please check the log file $LOG_IDR/${DB_VERSION}_consistent_backup_${timestamp}.log"
    exit 1
  fi
  echo "return code = $rc"
  echo "## Postgresql ${var1}ed" >> $LOG_IDR/${DB_VERSION}_consistent_backup_${timestamp}.log
}

# check that postgres is runing
check_pg_is_runing(){
 pg_status=$(sudo systemctl status postgresql-10  | awk 'FNR == 5 {print}'| tr -s " " | cut -d " " -f 4)
 if [ "$pg_status" = "(running)"  ]
 then
	echo "## Postgres is runing" 
 else
	send_notify "## Postgres is NOT runing. Trying to start ..."
	cmd_postgresql start
	exit 1
 fi
}

unmount_raid() {
	pg_run_flg=$(sudo systemctl status postgresql-10  | awk 'FNR == 5 {print}'| tr -s " " | cut -d " " -f 4)
	if [ "$pg_run_flg" = "(running)" ]
	then
		send_notify "### Failed to unmount RAID!\n Please check the log file $LOG_IDR/${DB_VERSION}_consistent_backup_${timestamp}.log"
		echo -e "### Failed to unmount RAID! PG is still runing" >> $LOG_IDR/${DB_VERSION}_consistent_backup_${timestamp}.log
		exit 1
	else 
		echo "## Unmount the RAID0"
		sudo umount $PG_MOUNT_POINT 2>> $LOG_IDR/${DB_VERSION}_consistent_backup_${timestamp}.log
		rc=$?
		if [ $rc -gt 0 ]
		then
			send_notify "### Failed to unmount RAID!\n Please check the log file $LOG_IDR/${DB_VERSION}_consistent_backup_${timestamp}.log"
			echo -e "### Failed to unmount RAID!" >> $LOG_IDR/${DB_VERSION}_consistent_backup_${timestamp}.log
			sudo lsof | grep $PG_MOUNT_POINT >> $LOG_IDR/${DB_VERSION}_consistent_backup_${timestamp}.log
			#failed to unmont then start postgres
			cmd_postgresql start
			exit 1
		fi
	fi
	echo "## RAID was unmouted from $PG_MOUNT_POINT" >> $LOG_IDR/${DB_VERSION}_consistent_backup_${timestamp}.log
}

#create EBS volume snapshot
create_snapshot() {
	volume_list=$(aws ec2 describe-volumes --region $EC2_REGION --filters Name=attachment.instance-id,Values=$INSTANCE_ID Name=tag:array,Values=PG10RAID --query Volumes[].VolumeId --output text)
	echo $volume_list >> $LOG_IDR/${DB_VERSION}_consistent_backup_${timestamp}.log
	for volume_id in $volume_list; do 
        snapshot_name="snap-$volume_id-$(date +%Y-%m-%d)"
        snapshot_id=$(aws ec2 create-snapshot --volume-id $volume_id --output=text --query SnapshotId --tag-specifications 'ResourceType=snapshot,Tags=[{Key=CreatedBy,Value=PGBackup},{Key=Name,Value='$snapshot_name'}]' )
        if [ -z "$snapshot_id" ]
		then
      		echo "## New snapshotID is empty" >> $LOG_IDR/${DB_VERSION}_consistent_backup_${timestamp}.log
			send_notify "## Snapshot was not created"
		else
      		echo "## New snapshotID is $snapshot_id" >> $LOG_IDR/${DB_VERSION}_consistent_backup_${timestamp}.log
		fi
    done
}

mount_raid() {
  echo "## Mount the RAID0"
  sudo mount LABEL=$RAID_NAME $PG_MOUNT_POINT 2>> $LOG_IDR/${DB_VERSION}_consistent_backup_${timestamp}.log
  rc=$?
  if [ $rc -gt 0 ]
  then
    send_notify "### Failed to mount RAID!\n Please check the log file $LOG_IDR/${DB_VERSION}_consistent_backup_${timestamp}.log"
    exit 1
  fi
  echo "RAID was mouted to $PG_MOUNT_POINT" >> $LOG_IDR/${DB_VERSION}_consistent_backup_${timestamp}.log
}

# _main_
check_pg_is_runing
get_aws_params
cmd_postgresql stop
unmount_raid
create_snapshot
mount_raid
cmd_postgresql start
check_pg_is_runing