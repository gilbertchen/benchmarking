#!/bin/bash

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
BACKUP_DIR=${TEST_DIR}/linux
DUPLICACY_STORAGE=${TEST_DIR}/linux-duplicacy-storage
RESTIC_STORAGE=${TEST_DIR}/linux-restic-storage
ATTIC_STORAGE=${TEST_DIR}/linux-attic-storage
DUPLICITY_STORAGE=${TEST_DIR}/linux-duplicity-storage

# Used as the storage password throughout the tests
PASSWORD=12345678

# Clean up the storages
rm -rf ${DUPLICACY_STORAGE}
mkdir -p ${DUPLICACY_STORAGE}
rm -rf ${RESTIC_STORAGE}
mkdir -p ${RESTIC_STORAGE}
rm -rf ${ATTIC_STORAGE}
mkdir -p ${ATTIC_STORAGE}
rm -rf ${DUPLICITY_STORAGE}
mkdir -p ${DUPLICITY_STORAGE}

# Download the github repository if needed
if [ ! -d "${BACKUP_DIR}" ]; then
    git clone https://github.com/torvalds/linux.git ${BACKUP_DIR}
fi 

function duplicacy_backup()
{
    time env DUPLICACY_PASSWORD=${PASSWORD} ${DUPLICACY_PATH} backup -stats | grep -v Uploaded
}

function restic_backup()
{
    time env RESTIC_PASSWORD=${PASSWORD} ${RESTIC_PATH} -r ${RESTIC_STORAGE} --exclude-file=${BACKUP_DIR}/.duplicacy/restic-exclude backup ${BACKUP_DIR}
}

function attic_backup()
{
    time env BORG_PASSPHRASE=${PASSWORD} ${ATTIC_PATH} create --compression lz4 ${ATTIC_STORAGE}::$1 ${BACKUP_DIR} --exclude-from ${BACKUP_DIR}/.duplicacy/attic-exclude 
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
    du -sh ${TEST_DIR}/linux-*-storage
}

pushd ${BACKUP_DIR}

echo =========================================== init ========================================
rm -rf ${BACKUP_DIR}/.duplicacy
env DUPLICACY_PASSWORD=${PASSWORD} ${DUPLICACY_PATH} init test ${DUPLICACY_STORAGE} -e -c 1M
echo "-.git/" > ${BACKUP_DIR}/.duplicacy/filters

echo ".git/**" > ${BACKUP_DIR}/.duplicacy/restic-exclude
echo ".duplicacy/**" >> ${BACKUP_DIR}/.duplicacy/restic-exclude
env RESTIC_PASSWORD=${PASSWORD} ${RESTIC_PATH} -r ${RESTIC_STORAGE} init

echo "${BACKUP_DIR}/.git/*" > ${BACKUP_DIR}/.duplicacy/attic-exclude
echo "${BACKUP_DIR}/.duplicacy/*" >> ${BACKUP_DIR}/.duplicacy/attic-exclude
env BORG_PASSPHRASE=${PASSWORD} ${ATTIC_PATH} init -e repokey-blake2 ${ATTIC_STORAGE}

echo "- ${BACKUP_DIR}/.git" > ${BACKUP_DIR}/.duplicacy/duplicity-exclude
echo "- ${BACKUP_DIR}/.duplicacy" >> ${BACKUP_DIR}/.duplicacy/duplicity-exclude


du -sh ${TEST_DIR}/linux-*-storage

git checkout -f 4f302921c1458d790ae21147f7043f4e6b6a1085 # commit on 07/02/2016
all_backup 1

git checkout -f 3481b68285238054be519ad0c8cad5cc2425e26c # commit on 08/03/2016 
all_backup 2 

git checkout -f 46e36683f433528bfb7e5754ca5c5c86c204c40a # commit on 09/02/2016 
all_backup 3 

git checkout -f 566c56a493ea17fd321abb60d59bfb274489bb18 # commit on 10/05/2016 
all_backup 4 

git checkout -f 1be81ea5860744520e06d0dfb9e3490b45902dbb # commit on 11/01/2016 
all_backup 5 

git checkout -f ef3d232245ab7a1bf361c52449e612e4c8b7c5ab # commit on 12/02/2016 
all_backup 6 

git checkout -f 0e377f3b9ae936aefe5aaca4c2e2546d57b63df7 # commit on 01/05/2017
all_backup 7 

git checkout -f cb23ebdfa6a491cf2173323059d846b4c5c9264e # commit on 02/04/2017 
all_backup 8 

git checkout -f 67db256ed1e09fa03551f90ab3562df34c802a0b # commit on 03/02/2017 
all_backup 9 

git checkout -f 1aed89640a899cd695bbfc976a4356affa474646 # commit on 04/05/2017 
all_backup 10

git checkout -f a6128f47f7940d8388ca7c8623fbe24e52f8fae6 # commit on 05/05/2017 
all_backup 11

git checkout -f 57caf4ec2b8bfbcb4f738ab5a12eedf3a8786045 # commit on 06/05/2017 
all_backup 12

