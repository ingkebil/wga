#!/bin/bash

# exit on errr
set -e

REFFILE=${1}
BAMFILE=${2}
OUTDIR=${3}

# import logging functionality
source log.bash

# first, calculte the lengths of all reference regions in the ref file
REGIONS=`mktemp`
awk seqlength.awk < $REFFILE > $REGIONS

# start op a process of samtools for each region
i=0
while read REGION; do
    R=`mktemp`
    echo $REGION > $R
    # create mpileup file
    MPILEUPOUTFILE="${OUTDIR}/aln.mpileup"
    if [[ ! -e ${MPILEUPOUTFILE} ]]; then
        COMMAND="samtools mpileup -Bf ${REFFILE} -l $R ${BAMFILE}"
        log 'MPILEUP' "$COMMAND > ${MPILEUPOUTFILE}.$i"
        $COMMAND > ${MPILEUPOUTFILE}
        log 'MPILEUP' 'done.'
    else
        log 'MPILEUP' "$MPILEUPOUTFILE already present!"
    fi
done < $REGIONS

# cat all the mpileup files together
# TODO make a named pipe for this
cat `ls $OUTDIR/${MPILEUPOUTFILE}.*` > ${MPILEUPOUTFILE}

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
