#!/bin/bash

REFFILE=$1
REGFILE=$2
BAMFILE=$3
OUTFILE=$4

samtools mpileup -Bf ${REFFILE} -l ${REGFILE} ${BAMFILE} > ${OUTFILE}
