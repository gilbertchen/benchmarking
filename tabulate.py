#!/usr/bin/python

import os
import sys
import re

#
# This script is written to extract elapsed times from linux-backup-test.sh or linux-restore-test.sh
#
# Usage:
#
#     ./linux-backup-test.sh &> linux-backup-test.results
#     python tabulate.py linux-backup-test.results 

def getBackup(i):
    l = ["Initial", "2nd", "3rd"]
    if i < len(l):
        return l[i] + " backup"
    else:
        return str(i + 1) + "th backup"

def getTime(minute, second):
    t = int(minute) * 60 + float(second)
    return "%.1f" % t

if len(sys.argv) <= 1:
    print "usage:", sys.argv[0], "<test result file>"
    sys.exit(1)

i = 0
for line in open(sys.argv[1]).readlines():
    if line.startswith("====") and "init" not in line:
        print "\n|", getBackup(i), "|",
        i += 1 
        continue
    m = re.match(r"real\s+(\d+)m([\d.]+)s", line)
    if m:
        print getTime(m.group(1), m.group(2)),
        continue

    m = re.match(r"user\s+(\d+)m([\d.]+)s", line)
    if m:
        print "(", getTime(m.group(1), m.group(2)), ",", 
        continue
    m = re.match(r"sys\s+(\d+)m([\d.]+)s", line)
    if m:
        print getTime(m.group(1), m.group(2)), ") |", 
        continue
  
print "" 
     
