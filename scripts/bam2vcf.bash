#!/bin/bash

# exit on errr
set -e

MPILEUPFILE=${1}
OUTDIR=${2}

# import logging functionality
source log.bash

# remove the named pipe on exit
cleanup() {
    if [[ -e ${MPILEUPFILE} ]]; then
        rm ${MPILEUPFILE}
    fi
}
trap cleanup EXIT

REGIONSOUTFILE="${OUTDIR}/aln.regions"
if [[ ! -e ${REGIONSOUTFILE} ]]; then
    COMMAND="java -Xms8g -Xmx8g -jar /mnt/hds/proj/common/java/VarScan.v2.3.7.jar limit ${MPILEUPFILE} --regions-file /mnt/hds/proj/bioinfo/mip/mip_references/Agilent_SureSelect.V5.GRCh37.70_targets.bed --output-file $REGIONSOUTFILE"
    log 'REGIONS FILE' "$COMMAND"
    $COMMAND
    log 'REGIONS FILE' 'done.'
else
    log 'REGIONS FILE' "$REGIONSOUTFILE already present!"
fi

# remove trap and cleanup the named pipe
trap - EXIT
cleanup

VCFOUTFILE="${OUTDIR}/aln.vcf"
if [[ ! -e $VCFOUTFILE ]]; then
    COMMAND="java -Xms32g -Xmx32g -jar /mnt/hds/proj/common/java/VarScan.v2.3.7.jar mpileup2cns ${REGIONSOUTFILE} --output-vcf 1 --p-value 99e-02"
    log 'VCF' "$COMMAND > ${VCFOUTFILE}"
    $COMMAND > ${VCFOUTFILE}
    log 'VCF' 'done.'
else
    log 'VCF' "$VCFOUTFILE already present!"
fi
