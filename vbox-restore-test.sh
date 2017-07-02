#!/bin/bash

#
# This script is to be run after vbox-backup-test.sh.  It will restore backups
# in TEST_DIR/vbox-*-storage to TEST_DIR/vbox-*-restore
#
# NOTE:
#    Please make sure that this script doesn't run pass midnight, otherwise it
# would not be able to restore duplicity backups because it assumed backups were
# created on the same day.
#

if [ "$#" -eq 0 ]; then
    echo "Usage: $0 <test dir>"
    exit 1
fi

if [ -z "$DUPLICACY_PATH" ]; then
    echo "DUPLICACY_PATH must be set to the path of the Duplicacy executable"
    exit 1
fi

if [ -z "$RESTIC_PATH" ]; then
    echo "RESTIC_PATH must be set to the path of the restic executable"
    exit 1
fi

if [ -z "$ATTIC_PATH" ]; then
    echo "ATTIC_PATH must be set to the path of the attic executable"
    exit 1
fi

if [ -z "$DUPLICITY_PATH" ]; then
    echo "DUPLICITY_PATH must be set to the path of the duplicity executable"
    exit 1
fi

if [ -z "$GPG_KEY" ]; then
    echo "GPG_KEY must be set for duplicity to work properly"
    exit 1
fi

if [ -z "$PASSPHRASE" ]; then
    echo "PASSPHRASE must be set for duplicity to work properly"
    exit 1
fi

# Set up directories
TEST_DIR=$1
DUPLICACY_STORAGE=${TEST_DIR}/vbox-duplicacy-storage
RESTIC_STORAGE=${TEST_DIR}/vbox-restic-storage
ATTIC_STORAGE=${TEST_DIR}/vbox-attic-storage
DUPLICITY_STORAGE=${TEST_DIR}/vbox-duplicity-storage

DUPLICACY_RESTORE=${TEST_DIR}/vbox-duplicacy-restore
RESTIC_RESTORE=${TEST_DIR}/vbox-restic-restore
ATTIC_RESTORE=${TEST_DIR}/vbox-attic-restore
DUPLICITY_RESTORE=${TEST_DIR}/vbox-duplicity-restore

# Used as the storage password throughout the tests
PASSWORD=12345678

rm -rf ${DUPLICACY_RESTORE}
mkdir -p ${DUPLICACY_RESTORE}
rm -rf ${RESTIC_RESTORE}
mkdir -p ${RESTIC_RESTORE}
rm -rf ${ATTIC_RESTORE}
mkdir -p ${ATTIC_RESTORE}
rm -rf ${DUPLICITY_RESTORE}
mkdir -p ${DUPLICITY_RESTORE}

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

function all_restore()
{

    echo ======================================== restore $1 ========================================
    duplicacy_restore $1
    #restic_restore $1
    attic_restore $1
    #duplicity_restore $1
}


# Initialize the duplicacy directory to be restored
pushd ${DUPLICACY_RESTORE}
env DUPLICACY_PASSWORD=${PASSWORD} ${DUPLICACY_PATH} init test ${DUPLICACY_STORAGE} -e
popd

echo restic snapshots:
env RESTIC_PASSWORD=${PASSWORD} ${RESTIC_PATH} -r ${RESTIC_STORAGE} snapshots

echo duplicity archives: 
${DUPLICITY_PATH} -v0 --encrypt-key ${GPG_KEY} --sign-key ${GPG_KEY} collection-status file://${DUPLICITY_STORAGE} | grep "Full\|Incremental"

all_restore 1
all_restore 2 
all_restore 3 

