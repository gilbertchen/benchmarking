#!/bin/bash

#
# Usage:
#     vbox-backup-test.sh <vm dir> <test dir> <action>
#
#     <vm dir>: the directory that contains the virtual machine; can't have spaces in the path
#     <test dir>: where the storage directories will be created
#     <action>: init or backup; init will also run the initial backup
#

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <vm dir> <test dir> <action>"
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
BACKUP_DIR=$1
TEST_DIR=$2
ACTION=$3
DUPLICACY_STORAGE=${TEST_DIR}/vbox-duplicacy-storage
RESTIC_STORAGE=${TEST_DIR}/vbox-restic-storage
ATTIC_STORAGE=${TEST_DIR}/vbox-attic-storage
DUPLICITY_STORAGE=${TEST_DIR}/vbox-duplicity-storage

# Used as the storage password throughout the tests
PASSWORD=12345678

function duplicacy_backup()
{
    time env DUPLICACY_PASSWORD=${PASSWORD} ${DUPLICACY_PATH} backup -stats | grep -v Uploaded | grep -v Skipped
}

function restic_backup()
{
    time env RESTIC_PASSWORD=${PASSWORD} ${RESTIC_PATH} -r ${RESTIC_STORAGE} --exclude-file=${BACKUP_DIR}/.duplicacy/restic-exclude backup ${BACKUP_DIR}
}

function attic_backup()
{
    time env BORG_PASSPHRASE=${PASSWORD} ${ATTIC_PATH} create --stats --debug --compression lz4 ${ATTIC_STORAGE}::$1 ${BACKUP_DIR} --exclude-from ${BACKUP_DIR}/.duplicacy/attic-exclude 
}

function duplicity_backup()
{
    time ${DUPLICITY_PATH} -v0 --encrypt-key ${GPG_KEY} --sign-key ${GPG_KEY} --gpg-options "--compress-level=1" --exclude-filelist ${BACKUP_DIR}/.duplicacy/duplicity-exclude ${BACKUP_DIR} file://${DUPLICITY_STORAGE}
}

function all_backup()
{
    echo ======================================== backup $1 ========================================
    duplicacy_backup
    restic_backup
    attic_backup $1
    duplicity_backup
    du -sh ${TEST_DIR}/vbox-*-storage
}

pushd ${BACKUP_DIR}

INDEX_FILE=${TEST_DIR}/vbox.index

if [ -e ${INDEX_FILE} ]; then
    INDEX=$((`cat ${INDEX_FILE}` + 1))
fi

if [ "$ACTION" == "init" ]; then

   echo =========================================== init ========================================
   # Clean up the storages
   rm -rf ${DUPLICACY_STORAGE}
   mkdir -p ${DUPLICACY_STORAGE}
   rm -rf ${RESTIC_STORAGE}
   mkdir -p ${RESTIC_STORAGE}
   rm -rf ${ATTIC_STORAGE}
   mkdir -p ${ATTIC_STORAGE}
   rm -rf ${DUPLICITY_STORAGE}
   mkdir -p ${DUPLICITY_STORAGE}

   rm -rf ${BACKUP_DIR}/.duplicacy
   env DUPLICACY_PASSWORD=${PASSWORD} ${DUPLICACY_PATH} init test ${DUPLICACY_STORAGE} -e -c 2M
   echo "-.git/" > ${BACKUP_DIR}/.duplicacy/filters

   echo ".git/**" > ${BACKUP_DIR}/.duplicacy/restic-exclude
   echo ".duplicacy/**" >> ${BACKUP_DIR}/.duplicacy/restic-exclude
   env RESTIC_PASSWORD=${PASSWORD} ${RESTIC_PATH} -r ${RESTIC_STORAGE} init

   echo "${BACKUP_DIR}/.git/*" > ${BACKUP_DIR}/.duplicacy/attic-exclude
   echo "${BACKUP_DIR}/.duplicacy/*" >> ${BACKUP_DIR}/.duplicacy/attic-exclude
   env BORG_PASSPHRASE=${PASSWORD} ${ATTIC_PATH} init -e repokey ${ATTIC_STORAGE}

   echo "- ${BACKUP_DIR}/.git" > ${BACKUP_DIR}/.duplicacy/duplicity-exclude
   echo "- ${BACKUP_DIR}/.duplicacy" >> ${BACKUP_DIR}/.duplicacy/duplicity-exclude

   du -sh ${TEST_DIR}/vbox-*-storage

   INDEX=1
   echo ${INDEX} > ${INDEX_FILE}
fi

echo Backup ${INDEX}
all_backup ${INDEX}
echo ${INDEX} > ${INDEX_FILE}


