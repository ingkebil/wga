#!/bin/bash

# exit on errr
set -e

source log.bash

# params
REFFILE=$1
REGION=$2
BAMFILE=$3
OUTFILE=$4

cleanup() {
    if [[ -e $REGFILE ]]; then
        rm $REGFILE
    fi
}
trap cleanup EXIT

# first create a region file
REGFILE=`mktemp`
echo ${REGION//./ } > $REGFILE

COMMAND="samtools mpileup -Bf ${REFFILE} -l ${REGFILE} ${BAMFILE}"
log 'MPILEUP' "$COMMAND > ${OUTFILE}"
$COMMAND > ${OUTFILE}
log 'MPILEUP' 'Done.'

trap - EXIT
cleanup
