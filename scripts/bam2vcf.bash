#!/bin/bash

REFFILE=${1}
BAMFILE=${2}
OUTDIR=${3}

# import logging functionality
source log.bash

MPILEUPFILE="${OUTDIR}/aln.mpileup"
COMMAND="samtools mpileup -Bf ${REFFILE} ${BAMFILE} > ${MPILEUPFILE}"
log 'MPILEUP' "$COMMAND"
`$COMMAND` 
log 'MPILEUP' 'done.'

REGIONSFILE="${OUTDIR}/aln.regions"
COMMAND="java -Xms8g -Xmx8g -jar /mnt/hds/proj/common/java/VarScan.v2.3.7.jar limit ${MPILEUPFILE} --regions-file /mnt/hds/proj/bioinfo/mip/mip_references/Agilent_SureSelect.V5.GRCh37.70_targets.bed --output-file $REGIONSFILE"
log 'REGIONS FILE' "$COMMAND"
`$COMMAND`
log 'REGIONS FILE' 'done.'

VCFFILE="${OUTDIR}/aln.vcf"
COMMAND="java -Xms32g -Xmx32g -jar /mnt/hds/proj/common/java/VarScan.v2.3.7.jar mpileup2cns ${REGIONSFILE} --output-vcf 1 --p-value 99e-02 > ${VCFFILE}"
log 'VCF' "$COMMAND"
`$COMMAND`
log 'VCF' 'done.'
