#!/bin/bash

# Standalone multi-processed mpile script

# exit on errr
set -e

REFFILE=${1}
BAMFILE=${2}
OUTFILE=${3}

# import logging functionality
source log.bash

# clean up all region files
cleanup() {
    if [[ -n ${REGION_FILES[@]} ]]; then
        for REGION_FILE in ${REGION_FILES[@]}; do
            rm "$REGION_FILE"
        done
    fi
}
trap cleanup EXIT

# first, calculate the lengths of all reference regions in the ref file
REGIONS=`mktemp`
COMMAND="`pwd`/seqlength.awk"
log 'SEQLEN' "$COMMAND < $REFFILE > $REGIONS"
$COMMAND < $REFFILE > $REGIONS
log 'SEQLEN' 'Done.'

# start op a process of samtools for each region
REGION_FILES=() # holds a list of region files so we can clean them up on exit
i=0
while read REGION; do
    # create a regions file for this process
    R=`mktemp`
    echo $REGION > $R
    REGION_FILES+=($R)

    # launch!
    if [[ ! -e ${OUTFILE}.$i ]]; then
        COMMAND="samtools mpileup -Bf ${REFFILE} -l $R ${BAMFILE}"
        log 'MPILEUP' "$COMMAND > ${OUTFILE}.$i"
        $COMMAND > ${OUTFILE}.$i &
    else
        log 'MPILEUP' "{$OUTFILE}.$i already present!"
    fi
done < $REGIONS

# create the named pipe for forward
log 'MPILEUP' 'Creating named pipe for cat ... '
mkfifo ${OUTFILE}
cat `ls ${OUTFILE}.*` > ${OUTFILE} &
log 'MPILEUP' 'Done.'

# clean exit
cleanup
trap - EXIT
