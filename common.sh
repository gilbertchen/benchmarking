
if [ -z "$DUPLICACY_PATH" ]; then
    DUPLICACY_PATH="`which duplicacy 2>/dev/null || echo ""`"
fi

if [ -z "$RESTIC_PATH" ]; then
    RESTIC_PATH="`which restic  2>/dev/null || echo ""`"
fi

if [ -z "$ATTIC_PATH" ]; then
    ATTIC_PATH="`which attic 2>/dev/null || echo ""`"
fi

if [ -z "$DUPLICITY_PATH" ]; then
    DUPLICITY_PATH="`which duplicity 2>/dev/null || echo ""`"
fi

if [ -z "$RDEDUP_PATH" ]; then
    RDEDUP_PATH="`which rdedup 2>/dev/null || echo ""`"
fi

if [ -z "$RDUP_PATH" ]; then
    RDUP_PATH="`which rdup 2>/dev/null || echo ""`"
fi

if [ -z "$RDEDUP_PATH" -o -z "$RDUP_PATH" ]; then
    RDEDUP_PATH=""
    RDUP_PATH=""
fi

if [ ! -z "$DUPLICITY_PATH" ]; then
    if [ -z "$GPG_KEY" ]; then
        echo "GPG_KEY must be set for duplicity to work properly"
        DUPLICITY_PATH=""
    fi
fi

BACKUP_DIR="`realpath ${TEST_DIR}/linux`"

DUPLICACY_STORAGE=${TEST_DIR}/linux-duplicacy-storage
RESTIC_STORAGE=${TEST_DIR}/linux-restic-storage
ATTIC_STORAGE=${TEST_DIR}/linux-attic-storage
DUPLICITY_STORAGE=${TEST_DIR}/linux-duplicity-storage
RDEDUP_STORAGE=${TEST_DIR}/linux-rdedup-storage

DUPLICACY_RESTORE=${TEST_DIR}/linux-duplicacy-restore
RESTIC_RESTORE=${TEST_DIR}/linux-restic-restore
ATTIC_RESTORE=${TEST_DIR}/linux-attic-restore
DUPLICITY_RESTORE=${TEST_DIR}/linux-duplicity-restore
RDEDUP_RESTORE=${TEST_DIR}/linux-rdedup-restore

# Used as the storage password throughout the tests
PASSWORD=12345678


