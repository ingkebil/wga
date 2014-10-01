#!/bin/bash
REFSEQFILE=/mnt/hds/proj/bioinfo/REF/hs_NCBIbuild372.fa 
INDIR=${1}
OUTDIR=${2}
ONEDIRECTION=${3}
TWODIRECTION=${4}

# with $1 reads in one direction and $2 reads in reverse direction
bwa mem -t 16 $REFSEQFILE "${INDIR}/$1" "${INDIR}/$2" > ${OUTDIR}/aln.sam
