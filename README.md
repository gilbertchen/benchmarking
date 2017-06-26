## Summary

The following table shows the running times (in seconds) of 4 backup tools when backing up the entire Linux code base:

| Backup             | [Duplicacy](https://github.com/gilbertchen/duplicacy) |   [restic](https://github.com/restic/restic)   |   [Attic](https://github.com/borgbackup/borg)    |  [duplicity](http://duplicity.nongnu.org/)  | 
|:------------------:|:-------------:|:----------:|:----------:|:-----------:|
| Initial Backup     |   **11.7**      |    21.9    |    28.7    |     46.3    |
| 2nd Backup         |    **3.8**      |     7.8    |    16.3    |     21.9    |
| 3rd Backup         |    **5.6**      |    11.9    |    21.4    |     29.6    |
| 4th Backup         |    **3.3**      |     8.2    |    16.7    |     24.7    |
| 5th Backup         |    **7.9**      |    11.3    |    21.2    |     32.1    |
| 6th Backup         |    **4.4**      |     8.9    |    20.1    |     26.1    |

Duplicacy is not only the fastest, but also almost twice as faster as the second fastest!

## Disclaimer
As the developer of Duplicacy, I have little firsh-hand experience with other tools, other than setting them up and running for these experiements for the first time for this performance study.  It is highly possible that configurations for other tools may not be optimal.  Therefore, results presented here should be taken with a grain of salt until they are independently confirmed by other people.


## Setup

All tests were performed on a Mac mini 2012 model running macOS Sierra (10.12.3), with a 2.3 GHZ Intel i7 4-core processor and 16 GB memory.

The following table lists serveral important configuration parameters or algorithms that may have significant impact on the overall performance.

| Configuration      |   Duplicacy   |   restic              |   Attic    |  duplicity  | 
|:------------------:|:-------------:|:---------------------:|:----------:|:-----------:|
| Version            |   2.0.3      |    0.6.1               |    BorgBackup 1.1.0b6    |    0.7.12    |
| Average chunk size |     4MB     |    1MB               |     2MB    |     25MB     |
| Hash               |     blake2    |    SHA256             |  blake2 <sup>[1]</sup>|  SHA1    |
| Compression        |    lz4        |    not impelmented    |    lz4     | zlib level 1|
| Encryption         |    AES-GCM    |   AES-CTR             |  AES-CTR   |  GnuPG      |

[1] Enabled by `-e repokey-blake2` which is only available in 1.1.0+

## Backing up the Linux code base

We chose the Linux code base (https://github.com/torvalds/linux) mostly because it is the largest github repository we could find and it has frequent commits (good for testing incremental backups).  Its size is 1.76G with about 58K files, so it is relatively small, but it represents a popular use case where a backup tool runs alongside a version control program such as git to frequently save changes made between checkins.

To test incremental backup, we selected a commit on July 2016 and rolled back the entire code base to that commit. After the initial backup was finished, we selected other commits that were about one month apart, applied them one by one to emulate incremental changes and then performed subsequent backups accordingly.  Details can be found in linux-backup-test.sh.

Backups were all saved to a storage directory on the same hard disk as the code base, to eliminate the performance variations caused by different implementation of networked or cloud storage backends.

Here are the elapsed real times in seconds as reported by the `time` command, with the user CPU time and sytem CPU time in the parentheses:

| Backup             |   Duplicacy  |   restic   |   Attic    |  duplicity  | 
|:------------------:|:----------------:|:----------:|:----------:|:-----------:|
| Initial Backup     | 11.7 (13.1, 1.7) | 21.9 (70.9, 9.9) | 28.7 (24.0, 3.6) | 46.3 (58.6, 4.7) |
| 2nd Backup         | 3.8 (3.4, 0.5)   | 7.8 (15.8, 2.8)  | 16.3 (14.0, 1.6) | 21.9 (19.1, 1.4) |
| 3rd Backup         | 5.6 (6.3, 0.8)   | 11.9 (31.7, 4.0) | 21.4 (17.8, 2.4) | 29.6 (28.4, 2.0) |
| 4th Backup         | 3.3 (3.0, 0.5)   | 8.2 (14.4, 2.8)  | 16.7 (14.8, 1.6) | 24.7 (22.3, 1.3) |
| 5th Backup         | 7.9 (8.7, 0.9)   | 11.3 (35.9, 4.5) | 21.2 (17.2, 2.2) | 32.1 (30.3, 2.1) |
| 6th Backup         | 4.4 (4.3, 0.7)   | 8.9 (19.0, 3.3)  | 20.1 (16.2, 2.0) | 26.1 (24.0, 1.5) |

Clearly Duplicacy is the winner by a confortable margin.  It is interesting to note that restic, while being the second fastest, consumed excessive CPU such that the user CPU times were a lot higher than the eleapsed real times, which is bad for the user case where users want to keep the backup tool running in the background to minimize the interference with other tasks.  This could be caused by using too many threads (or more precisely, goroutines) in its local storage backend implementation.  However, even if this issue is fixable, as restic currently does not support compression, the addition of compression will only further slow down the backup speeds.

Now let us look at the sizes of the backup storage after each backup:

| Backup             |   Duplicacy  |   restic   |   Attic    |  duplicity  | 
|:------------------:|:----------------:|:----------:|:----------:|:-----------:|
| Initial Backup     | 223MB | 631MB | 259MB | 183MB |
| 2nd Backup         | 244MB | 692MB | 280MB | 185MB |
| 3rd Backup         | 331MB | 912MB | 367MB | 203MB |
| 4th Backup         | 339MB | 934MB | 374MB | 204MB |
| 5th Backup         | 427MB | 1.1GB | 466MB | 222MB |
| 6th Backup         | 455MB | 1.2GB | 492MB | 224MB |

Although duplicity is the most storage efficient, it should be noted that it uses zlib, which is known to compress better than lz4 used by Duplicacy and Attic.  Moreoever, unlike other 3, duplicity is the only one that has a serious flaw in its incremental model -- the user has to decide whether to perform a full backup or an incremental backup on each run.  That is because while an incremental backup in duplicity saves a lot of storage space, it also becomes dependent on previous backups, making it impossible to delete any single backup on the long chain of dependent backups. A long chain of dependent backups also significantly slow down the restore operation, which has to start at a full backup and then follow the incremental backups on the chain to reach the desired one.  So there is always a dilemma of how often to perform a full backup for duplicity users.  In contrast, in other 3 tools, a backup is always incremental in nature but appears to be a full backup.  Any backup can be individually deleted without affecting others, or indepdently restored.
