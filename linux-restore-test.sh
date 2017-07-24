#!/bin/bash

#
# This script is to be run after linux-backup-test.sh.  It will restore backups
# in TEST_DIR/linux-*-storage to TEST_DIR/linux-*-restore
#
# NOTE:
#    Please make sure that this script doesn't run pass midnight, otherwise it
# would not be able to restore duplicity backups because it assumed backups were
# created on the same day. 

if [ "$#" -eq 0 ]; then
    echo "Usage: $0 <test dir>"
    exit 1
fi


# Set up directories
TEST_DIR="`realpath $1`"
source "common.sh"

rm -rf ${DUPLICACY_RESTORE}
mkdir -p ${DUPLICACY_RESTORE}
rm -rf ${RESTIC_RESTORE}
mkdir -p ${RESTIC_RESTORE}
rm -rf ${ATTIC_RESTORE}
mkdir -p ${ATTIC_RESTORE}
rm -rf ${DUPLICITY_RESTORE}
mkdir -p ${DUPLICITY_RESTORE}
rm -rf ${RDEDUP_RESTORE}
mkdir -p ${RDEDUP_RESTORE}

function duplicacy_restore()
{  
    rm -rf ${DUPLICACY_RESTORE}/* 
    pushd ${DUPLICACY_RESTORE}
    time env DUPLICACY_PASSWORD=${PASSWORD} ${DUPLICACY_PATH} restore -r $1 -stats | grep -v Downloaded
    popd
}


function restic_restore()
{
    rm -rf ${RESTIC_RESTORE}/* 
    # We need to find the snapshot id to restore
    TODAY=`date +"%Y-%m-%d"`
    SNAPSHOT=`env RESTIC_PASSWORD=${PASSWORD} ${RESTIC_PATH} -r ${RESTIC_STORAGE} snapshots | grep $TODAY | head -n $1 | tail -n 1 | awk '{print $1;}'`
    echo Restoring from $SNAPSHOT
    time env RESTIC_PASSWORD=${PASSWORD} ${RESTIC_PATH} -r ${RESTIC_STORAGE} restore $SNAPSHOT --target ${RESTIC_RESTORE}
}

function attic_restore()
{
    rm -rf ${ATTIC_RESTORE}/* 
    pushd ${ATTIC_RESTORE}
    time env BORG_PASSPHRASE=${PASSWORD} ${ATTIC_PATH} extract ${ATTIC_STORAGE}::$1    
    popd
}

function duplicity_restore()
{
    rm -rf ${DUPLICITY_RESTORE}/* 
    # duplicity is crazy -- the --restore-time option doesn't take the time format printed by its own colleciton-status command!
    TODAY=`date +"%Y-%m-%d"`
    RESTORE_TIME=`${DUPLICITY_PATH} -v0 --encrypt-key ${GPG_KEY} --sign-key ${GPG_KEY} collection-status file://${DUPLICITY_STORAGE} | grep 'Full\|Incremental' | head -n $1 | tail -n 1 | awk '{print $5;}'`
    RESTORE_TIME=${TODAY}T${RESTORE_TIME}
    echo Restoring from $RESTORE_TIME
    time ${DUPLICITY_PATH} --force -v0 --encrypt-key ${GPG_KEY} restore -t $RESTORE_TIME file://${DUPLICITY_STORAGE} ${DUPLICITY_RESTORE}
}

function rdedup_restore()
{
    rm -rf ${RDEDUP_RESTORE}/* 
    RESTORE_NAME="`${RDEDUP_PATH} --dir ${RDEDUP_STORAGE} list | sort | head -n $1 | tail -n 1`"
    echo Restoring from $RESTORE_NAME
    time bash -c "env RDEDUP_PASSPHRASE=${PASSWORD} ${RDEDUP_PATH} --dir ${RDEDUP_STORAGE} load $RESTORE_NAME | ${RDUP_PATH}-up -r ${BACKUP_DIR} ${RDEDUP_RESTORE}"
}


function all_restore()
{

    echo ======================================== restore $1 ========================================
    if [ ! -z "$DUPLICACY_PATH" ]; then
        duplicacy_restore $1
    fi
    if [ ! -z "$RESTIC_PATH" ]; then
        restic_restore $1
    fi
    if [ ! -z "$ATTIC_PATH" ]; then
        attic_restore $1
    fi
    if [ ! -z "$DUPLICITY_PATH" ]; then
        duplicity_restore $1
    fi
    if [ ! -z "$RDEDUP_PATH" ]; then
        rdedup_restore $1
    fi
}

# Initialize the duplicacy directory to be restored
if [ ! -z "$DUPLICACY_PATH" ]; then
    pushd ${DUPLICACY_RESTORE}
    env DUPLICACY_PASSWORD=${PASSWORD} ${DUPLICACY_PATH} init test ${DUPLICACY_STORAGE} -e
    popd
fi

if [ ! -z "$RESTIC_PATH" ]; then
    echo restic snapshots:
    env RESTIC_PASSWORD=${PASSWORD} ${RESTIC_PATH} -r ${RESTIC_STORAGE} snapshots
fi

if [ ! -z "$DUPLICITY_PATH" ]; then
    echo duplicity archives: 
    ${DUPLICITY_PATH} -v0 --encrypt-key ${GPG_KEY} --sign-key ${GPG_KEY} collection-status file://${DUPLICITY_STORAGE} | grep "Full\|Incremental"
fi

for i in `seq 1 12`; do
    all_restore $i
done

