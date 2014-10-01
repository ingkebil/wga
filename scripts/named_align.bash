#!/bin/bash

# exit on errr
set -e

# params
REFSEQFILE=${1}
INDIR=${2}
OUTFILE=${3}
FORWARD_PATTERN=${4//\"} # this param will be quoted, remove quotes
REVERSE_PATTERN=${5//\"}
FORWARD=${INDIR}/forward.strands
REVERSE=${INDIR}/reverse.strands

# add a bash 'finally' block
cleanup() {
    if [[ -e ${FORWARD} ]]; then
        rm ${FORWARD}
    fi
    if [[ -e ${REVERSE} ]]; then
        rm ${REVERSE}
    fi
}

trap cleanup EXIT

# create the named pipe for forward
echo -n 'Creating forward named pipe ... '
mkfifo ${FORWARD}
cat ${INDIR}/${FORWARD_PATTERN} > ${FORWARD} &
echo 'done.'

# create the named pipe for reverse
echo -n 'Creating reverse named pipe ... '
mkfifo ${REVERSE}
cat ${INDIR}/${REVERSE_PATTERN} > ${REVERSE} &
echo 'done.'

# Run, bwa, run!
COMMAND="bwa mem -t 16 $REFSEQFILE ${FORWARD} ${REVERSE}"
echo "RUNNING: $COMMAND"
$COMMAND  > ${OUTFILE}

# clean up the clean up
trap - EXIT
cleanup
exit 0
