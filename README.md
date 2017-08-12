## Objective

To benchmark the performance and storage efficiency of 4 backup tools, [Duplicacy](https://github.com/gilbertchen/duplicacy), [restic](https://github.com/restic/restic), [Attic](https://github.com/borgbackup/borg), and [duplicity](http://duplicity.nongnu.org/), using datasets that are publicly available.

## Disclaimer
As the developer of Duplicacy, I have little first-hand experience with other tools, other than setting them up and running for these experiments for the first time for this performance study.  It is highly possible that configurations for other tools may not be optimal.  Therefore, results presented here should not be viewed as conclusive until they are independently confirmed by other people.

## Setup

All tests were performed on a Mac mini 2012 model running macOS Sierra (10.12.3), with a 2.3 GHZ Intel i7 4-core processor and 16 GB memory.

The following table lists several important configuration parameters or algorithms that may have significant impact on the overall performance.

|                    |   Duplicacy   |   restic              |   Attic    |  duplicity  | 
|:------------------:|:-------------:|:---------------------:|:----------:|:-----------:|
| Version            |   2.0.3      |    0.6.1               |    BorgBackup 1.1.0b6    |    0.7.12    |
| Average chunk size |     1MB<sup>[1]</sup>     |    1MB               |     2MB    |     25MB     |
| Hash               |     blake2    |    SHA256             |  blake2 <sup>[2]</sup>|  SHA1    |
| Compression        |    lz4        |    not implemented    |    lz4     | zlib level 1|
| Encryption         |    AES-GCM    |   AES-CTR             |  AES-CTR   |  GnuPG      |

[1] The chunk size in Duplicacy is configurable with the default being 4MB.  It was set it to 1MB to match that of restic

[2] Enabled by `-e repokey-blake2` which is only available in 1.1.0+

## Backing up the Linux code base

The first dataset is the [Linux code base](https://github.com/torvalds/linux) mostly because it is the largest github repository that we could find and it has frequent commits (good for testing incremental backups).  Its size is 1.76 GB with about 58K files, so it is a relatively small repository consisting of small files, but it represents a popular use case where a backup tool runs alongside a version control program such as git to frequently save changes made between checkins.

To test incremental backup, a random commit on July 2016 was selected, and the entire code base is rolled back to that commit. After the initial backup was finished, other commits were chosen such that they were about one month apart.  The code base is then moved forward to these commits one by one to emulate incremental changes.  Details can be found in linux-backup-test.sh.

Backups were all saved to a storage directory on the same hard disk as the code base, to eliminate the performance variations introduced by different implementation of networked or cloud storage backends.

Here are the elapsed real times (in seconds) as reported by the `time` command, with the user CPU times and system CPU times in the parentheses:

|                    |   Duplicacy  |   restic   |   Attic    |  duplicity  | 
|:------------------:|:----------------:|:----------:|:----------:|:-----------:|
| Initial backup | 13.7 (16.9, 1.6) | 20.7 (69.9, 9.9) | 26.9 (23.1, 3.1) | 44.2 (56.3, 4.6) | 
| 2nd backup | 4.8 (4.8, 0.5) | 8.0 (15.3, 2.5) | 15.4 (13.4, 1.5) | 19.5 (17.9, 1.1) | 
| 3rd backup | 6.9 (8.0, 1.0) | 11.9 (32.2, 4.0) | 19.6 (16.4, 2.0) | 29.8 (29.3, 1.9) | 
| 4th backup | 3.3 (3.1, 0.4) | 7.0 (12.7, 2.2) | 13.7 (12.1, 1.2) | 18.6 (17.3, 0.9) | 
| 5th backup | 9.9 (11.0, 1.0) | 11.4 (33.5, 3.8) | 19.9 (17.1, 2.1) | 28.0 (27.6, 1.5) | 
| 6th backup | 3.8 (3.9, 0.5) | 8.0 (17.7, 2.7) | 16.8 (14.1, 1.6) | 22.0 (20.7, 1.0) | 
| 7th backup | 5.1 (5.1, 0.5) | 7.8 (16.0, 2.4) | 14.3 (12.6, 1.3) | 21.6 (20.3, 1.0) | 
| 8th backup | 9.5 (10.8, 1.1) | 13.5 (49.3, 4.8) | 18.3 (15.9, 1.8) | 35.0 (33.6, 1.9) | 
| 9th backup | 4.3 (4.5, 0.6) | 9.0 (20.6, 2.8) | 15.7 (13.7, 1.5) | 24.9 (23.6, 1.1) | 
| 10th backup | 7.9 (9.1, 0.9) | 20.2 (38.4, 4.7) | 32.2 (18.1, 2.3) | 35.0 (33.8, 1.8) | 
| 11th backup | 4.6 (4.5, 0.6) | 9.1 (19.6, 2.8) | 16.8 (14.5, 1.7) | 28.1 (26.4, 1.3) | 
| 12th backup | 7.4 (8.8, 1.0) | 12.0 (38.4, 4.0) | 21.7 (18.4, 2.2) | 37.4 (37.0, 2.0) | 


Clearly Duplicacy was the winner by a comfortable margin.  It is interesting that restic, while being the second fastest, consumed far more CPU times than the elapsed real times, which is bad for the user case where users want to keep the backup tool running in the background to minimize the interference with other tasks.  This could be caused by using too many threads (or more precisely goroutines, since restic is written in GO) in its local storage backend implementation.  However, even if this issue is fixable, as restic currently does not support compression, the addition of compression will only further slow down its backup speeds.

Now let us look at the sizes of the backup storage after each backup:

|                    |   Duplicacy  |   restic   |   Attic    |  duplicity  | 
|:------------------:|:----------------:|:----------:|:----------:|:-----------:|
| Initial backup     | 224MB | 631MB | 259MB | 183MB |
| 2nd backup         | 246MB | 692MB | 280MB | 185MB |
| 3rd backup         | 333MB | 912MB | 367MB | 203MB |
| 4th backup         | 340MB | 934MB | 373MB | 204MB |
| 5th backup         | 429MB | 1.1GB | 466MB | 222MB |
| 6th backup         | 457MB | 1.2GB | 492MB | 224MB |
| 7th backup         | 475MB | 1.2GB | 504MB | 227MB |
| 8th backup         | 576MB | 1.5GB | 607MB | 247MB |
| 9th backup         | 609MB | 1.6GB | 636MB | 251MB |
| 10th backup        | 706MB | 1.8GB | 739MB | 268MB |
| 11th backup        | 734MB | 1.9GB | 766MB | 270MB |
| 12th backup        | 834MB | 2.2GB | 869MB | 294MB |


Although duplicity was the most storage efficient, it should be noted that it uses zlib, which is known to compress better than lz4 used by Duplicacy and Attic.  In addition, duplicity has a serious flaw in its incremental model -- the user has to decide whether to perform a full backup or an incremental backup on each run.  That is because while an incremental backup saves a lot of storage space, it is also dependent on previous backups due to the design of duplicity, making it impossible to delete any single backup on a long chain of dependent backups. So there is always a dilemma of how often to perform a full backup for duplicity users.

We also ran linux-restore-test.sh to test restore speeds.  The destination directory was emptied before each restore, so we only test full restore, not incremental restore.  Again, Duplicacy is not only the fastest but also the most stable.  The restore times of restic and Attic increased considerably for backups created later, with restic's performance deteriorating far more quickly.  This is perhaps due to to fact that both restic and Attic group a number of chunks into a pack, so to restore a later backup one may need to unpack many packs belonging to earlier backups.  In contrast, chunks in Duplicacy are independent entities and are never packed, so any backup can be quickly restored from chunks that compose that backup, without the need to retrieve data from other backups.

|                    |   Duplicacy  |   restic   |   Attic    |  duplicity  | 
|:------------------:|:----------------:|:----------:|:----------:|:-----------:|
| 1st restore | 38.8 (18.4, 11.5) | 38.4 (17.3, 8.6) | 81.5 (18.8, 12.5) | 251.6 (133.4, 51.9) | 
| 2nd restore | 35.2 (11.5, 12.9) | 92.7 (25.1, 12.6) | 41.1 (17.0, 11.4) | 256.6 (133.7, 48.4) | 
| 3rd restore | 33.9 (9.7, 10.9) | 136.7 (27.7, 15.0) | 35.3 (17.3, 11.5) | 231.4 (134.5, 46.9) | 
| 4th restore | 34.5 (14.0, 10.8) | 149.7 (26.9, 15.1) | 46.4 (17.9, 12.5) | 213.8 (134.5, 43.5) | 
| 5th restore | 30.2 (9.4, 9.4) | 198.3 (28.6, 17.3) | 58.2 (18.9, 13.3) | 236.4 (134.3, 49.2) | 
| 6th restore | 34.7 (11.2, 9.3) | 348.6 (30.2, 20.8) | 65.5 (19.5, 13.4) | 250.7 (135.3, 40.9) | 
| 7th restore | 36.8 (9.2, 9.6) | 238.8 (29.3, 18.6) | 64.8 (19.4, 13.6) | 225.7 (125.1, 42.7) | 
| 8th restore | 26.0 (9.7, 8.1) | 251.5 (32.5, 21.7) | 83.1 (20.9, 14.3) | 261.0 (126.0, 45.3) | 
| 9th restore | 31.5 (8.8, 8.7) | 269.5 (31.0, 21.0) | 80.3 (20.5, 14.1) | 230.6 (126.8, 43.0) | 
| 10th restore | 40.5 (8.7, 8.1) | 290.6 (32.0, 22.1) | 91.9 (21.5, 15.0) | 242.4 (128.9, 46.3) | 
| 11th restore | 34.6 (8.3, 7.6) | 472.7 (33.0, 26.3) | 125.3 (22.3, 15.1) | 278.5 (127.9, 49.1) | 
| 12th restore | 76.4 (20.4, 13.1) | 387.7 (33.4, 24.7) | 103.2 (23.1, 16.1) | 240.3 (134.9, 44.8) | 


## Backing up a VirtualBox virtual machine

The second test was targeted at the other end of the spectrum - a dataset with fewer but much larger files.  Virtual machine files typically fall into this category.  The particular dataset for this test is a VirtualBox virtual machine file.  The base disk image is 64 bit CentOS 7, downloaded from http://www.osboxes.org/centos/.  Its size is about 4 GB, still small compared to virtual machines that are actually being used everyday, but it is enough to quantify performance differences between these 4 backup tools.

The first backup was performed right after the virtual machine had been set up without installing any software.  The second backup was performed after installing common developer tools using the command `yum groupinstall 'Development Tools'`.  The third backup was performed after a power on immediately followed by a power off.

The following table lists the restore times by these 4 tools.  With default settings, Duplicacy was generally slower than Attic.  However, this is mainly because Attic does not [compute file hashes](https://www.bountysource.com/issues/31735500-show-which-distinct-versions-of-a-file-exist), while Duplicacy does.  For a fair comparison, an option was added to Duplicacy to disable file hash computation and that made Duplicacy slightly faster than Attic.  This is not to say that Duplicacy should make this option the default.  Although chunk hashes along can guarantee the integrity of backups, file hashes can be useful in many ways. For instance, file hashes enable users to quickly identify which files in existing backups are changed.  They also allow third-party tools to compare files on disks to those in the backups.  It is unlikely that Duplicacy will stop computing file hashes by default in favor of slight performance gains.

Surprisingly, for the third backup restic was the fastest.  This can be explained partly by the lack of compression, partly by the high CPU usage.

|                    |   Duplicacy (default settings)  | Duplicacy (no file hash) |   restic   |   Attic    |  duplicity  | 
|:------------------:|:----------------:|:----------------:|:----------:|:----------:|:-----------:|
| Initial backup | 80.6 (100.7, 3.3) | 41.4 (57.7, 3.2) | 136.5 (116.4, 13.7) | 47.6 (46.9, 4.9) | 255.6 (226.9, 18.5) | 
| 2nd backup | 49.4 (52.9, 2.0) | 36.5 (40.8, 2.1) | 32.2 (70.4, 4.8) | 39.2 (34.2, 2.4) | 334.3 (343.4, 4.6) | 
| 3rd backup | 45.7 (44.6, 1.4) | 34.5 (33.1, 1.4) | 17.3 (55.1, 2.2) | 36.1 (31.8, 1.7) | 42.0 (35.3, 2.2) | 
 
Not surprisingly, duplicity is still the most storage efficient with restic being the worst:

|                    |   Duplicacy  |   restic   |   Attic    |  duplicity  | 
|:------------------:|:----------------:|:----------:|:----------:|:-----------:|
| Initial backup     | 2.0G | 4.1G | 2.0G | 1.7G |
| 2nd backup         | 2.6G | 5.0G | 2.6G | 1.9G |
| 3rd backup         | 2.6G | 5.1G | 2.7G | 1.9G |

A full restore was also performed for each backup.  Again, by not computing the file hash helped improve the performance, but at the risk of possible undetected data corruption. 

|                    |   Duplicacy (default settings)  | Duplicacy (no file hash)  |   restic   |   Attic    |  duplicity  | 
|:------------------:|:----------------:|:----------------:|:----------:|:----------:|:-----------:|
| 1st restore | 130.5 (72.4, 5.7) | 76.8 (23.7, 4.2) | 202.6 (52.1, 7.1) | 99.6 (30.9, 6.6) | 728.3 (195.6, 87.0) | 
| 2nd restore | 138.9 (79.4, 5.4) | 121.5 (27.8, 6.6) | 230.8 (59.5, 8.3) | 115.7 (35.6, 7.8) | 720.5 (191.2, 87.7) | 
| 3rd restore | 145.4 (73.2, 5.4) | 123.9 (27.7, 6.6) | 244.8 (59.8, 8.1) | 122.2 (35.7, 7.9) | 749.7 (196.1, 87.9) | 

## Conclusion

The performances of 4 different backup tools on two publicly available datasets were compared.  Duplicacy is clearly the top performer for the first dataset and as fast as Attic for the second if the file hash computation is disabled.  However, it should be noted as both datasets are small and may be very different in nature from your data to be backed up.  Therefore, I strongly encourage you to run your own experiments using scripts available in this github repository in order to determine which one is the best for you.
