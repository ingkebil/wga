#!/bin/bash

REFFILE=${1}
BAMFILE=${2}
OUTDIR=${3}

# import logging functionality
source log.bash


# TODO maybe split up the mpileup creation to speed up the whole process
# awk '/^>/ {if (seqlen){print seqlen}; print ;seqlen=0;next; } { seqlen = seqlen +length($0)}END{print seqlen}' file.fa

# create mpileup file
MPILEUPOUTFILE="${OUTDIR}/aln.mpileup"
if [[ ! -e ${MPILEUPOUTFILE} ]]; then
    COMMAND="samtools mpileup -Bf ${REFFILE} ${BAMFILE}"
    log 'MPILEUP' "$COMMAND > ${MPILEUPOUTFILE}"
    $COMMAND > ${MPILEUPOUTFILE}
    log 'MPILEUP' 'done.'
else
    log 'MPILEUP' "$MPILEUPOUTFILE already present!"
fi

REGIONSOUTFILE="${OUTDIR}/aln.regions"
if [[ ! -e ${REGIONSOUTFILE} ]]; then
    COMMAND="java -Xms8g -Xmx8g -jar /mnt/hds/proj/common/java/VarScan.v2.3.7.jar limit ${MPILEUPOUTFILE} --regions-file /mnt/hds/proj/bioinfo/mip/mip_references/Agilent_SureSelect.V5.GRCh37.70_targets.bed --output-file $REGIONSOUTFILE"
    log 'REGIONS FILE' "$COMMAND"
    $COMMAND
    log 'REGIONS FILE' 'done.'
else
    log 'REGIONS FILE' "$REGIONSOUTFILE already present!"
fi

VCFOUTFILE="${OUTDIR}/aln.vcf"
if [[ ! -e $VCFOUTFILE ]]; then
    COMMAND="java -Xms32g -Xmx32g -jar /mnt/hds/proj/common/java/VarScan.v2.3.7.jar mpileup2cns ${REGIONSOUTFILE} --output-vcf 1 --p-value 99e-02"
    log 'VCF' "$COMMAND > ${VCFOUTFILE}"
    $COMMAND > ${VCFOUTFILE}
    log 'VCF' 'done.'
else
    log 'VCF' "$VCFOUTFILE already present!"
fi
