#!/bin/bash

# exit on errr
set -e

source log.bash

OUTFILE=${1}

COMMAND="cat ${OUTFILE}.*"
log 'CAT' "$COMMAND > ${OUTFILE}"
$COMMAND > ${OUTFILE}
COMMAND="rm ${OUTFILE}.*"
log 'CAT' "$COMMAND"
$COMMAND
log 'CAT' 'Done.'
