#!/bin/bash

# Pipeline to align fastq.gz files to target reference genome and create vcf files.
# 1/ bwa to align to target genome
# 2/ convert resulting sam to bam
# 3/ create vcf file from bam file

# exit on errr
set -e

##########
# params #
##########

REF_GENOME=/mnt/hds/proj/bioinfo/REF/hs_NCBIbuild372.fa 
NUM_NODES=2
INDIR=${1}
OUTDIR=${2}
FORWARD_PATTERN='*_1.fastq.gz' # the file pattern to select forward fastq files. Single quote this!
REVERSE_PATTERN='*_2.fastq.gz'
##################
LOGDIR=/mnt/hds/proj/bioinfo/LOG/
SCRIPTSDIR=${3-'/mnt/hds/proj/bioinfo/scripts/'}

[[ ! -d ${OUTDIR} ]] && mkdir ${OUTDIR}

#############
# functions #
#############

log() {
    NOW=$(date +"%Y%m%d%H%M%S")
    echo [${NOW}] [${1}] $2
}

function join { local IFS="$1"; shift; echo "$*"; }

# FOR TESTING ONLY
# add a bash 'finally' block to remove symlink dirs
cleanup() {
    for i in `seq 1 ${NUM_NODES}`; do
        TARGET_DIR="${INDIR}/${i}"
        if [[ -e ${TARGET_DIR} ]]; then
            rm -Rf ${TARGET_DIR}
        fi
    done
}

# In case scripting went wrong .. I don't have to cancel the submitted jobs myself :)
cancel() {
    if [[ -n $ALIGN_JOBIDS ]]; then
        for JOB_ID in ${ALIGN_JOBIDS[@]}; do
            echo "Canceling $JOB_ID"
            scancel $JOB_ID
        done
    fi
    if [[ -n $SAM2BAM_JOBID ]]; then
        echo "Canceling $SAM2BAM_JOBID"
        scancel $SAM2BAM_JOBID
    fi
}
trap cancel EXIT

#######################
# create symlink dirs #
#######################

# For each node, it will create following structure
# ${INDIR}/${number}/
# Each of these directories will be filled with symlinks to 1/${NUM_NODES} of the 
# ${FORWARD_PATTERN} and ${REVERSE_PATTERN} files. Last dir will contain remainder
# of files when number of files modulo ${NUM_NODES} is not zero.

log 'SYMLINKS' 'Creating symlink directories ...'
files=(`ls -1 ${INDIR}/${FORWARD_PATTERN} ${INDIR}/${REVERSE_PATTERN}`)
step=`echo $(( ${#files[@]} / ${NUM_NODES} ))`
for i in `seq 1 ${NUM_NODES}`; do
    if [[ ! -e ${INDIR}/${i} ]]; then
        mkdir ${INDIR}/${i}
    fi
    startpos=`echo $(( (${i} - 1) * ${step} ))`
    endpos=`echo $(( ${startpos} + ${step} - 1 ))`
    for j in `seq ${startpos} ${endpos}`; do
        filename=`basename ${files[$j]}`
        if [[ ! -e ${INDIR}/${filename} ${INDIR}/${i}/${filename} ]]; then
            ln -s ${INDIR}/${filename} ${INDIR}/${i}/${filename}
        fi
    done
done
startpos=`echo $(( $endpos + 1 ))`
endpos=`echo $(( ${#files[@]} - 1 ))`
for j in `seq ${startpos} ${endpos}`; do
    filename=`basename ${files[$j]}`
    if [[ ! -e ${INDIR}/${filename} ${INDIR}/${NUM_NODES}/${filename} ]]; then
        ln -s ${INDIR}/${filename} ${INDIR}/${NUM_NODES}/${filename}
    fi
done
log 'SYMLINKS' 'Done'

#########
# ALIGN #
#########

# Next step dependencies:
# SAM2BAM_INFILES, ALIGN_JOBIDS
ALIGN_NAME=named_align.$$
for i in `seq 1 ${NUM_NODES}`; do
    OUTFILE=${OUTDIR}/aln.${i}.sam
    if [[ ! -e ${OUTFILE} ]]; then
        ALIGN_INDIR=${INDIR}/${i}/
        COMMAND="sbatch -c 16 -N 1 -t 6:00:00 -A prod001 -J ${ALIGN_NAME} --output=${LOGDIR}/${$}.named_wgalign-${i}-%j.out --error=${LOGDIR}/${$}.named_wgalign-${i}-%j.err --mail-type=ALL --mail-user=kenny.billiau@scilifelab.se ${SCRIPTSDIR}/named_align.bash ${REF_GENOME} ${ALIGN_INDIR} ${OUTFILE} \"${FORWARD_PATTERN}\" \"${REVERSE_PATTERN}\""
        RS=`$COMMAND`
        ALIGN_JOBIDS[$(( $i - 1 ))]=${RS##* }
    fi
    SAM2BAM_INFILES[$(( $i - 1 ))]=${OUTFILE}
    log 'ALIGN' "$COMMAND"
done

###########
# sam2bam #
###########

# job is dependent on ALIGN to finish first
SAM2BAM_NAME=sam2bam.$$
if [[ -n $ALIGN_JOBIDS ]]; then
    JOINED_ALIGN_JOBIDS=`join : ${ALIGN_JOBIDS[@]}`
    DEPENDENCY="--dependency=afterok:${JOINED_ALIGN_JOBIDS}"
fi
COMMAND="sbatch -t 2:00:00 -c 16 -A prod001 -J ${SAM2BAM_NAME} $DEPENDENCY --output=/mnt/hds/proj/bioinfo/LOG/${$}.sam2bam-%j.out --error=/mnt/hds/proj/bioinfo/LOG/${$}.sam2bam-%j.err --mail-type=ALL --mail-user=kenny.billiau@scilifelab.se ${SCRIPTSDIR}/sam2bam.bash 16 ${OUTDIR}/aln.bam ${SAM2BAM_INFILES[@]}"
RS=`$COMMAND`
SAM2BAM_JOBID=${RS##* }
log 'SAM2BAM' "$COMMAND"

###########
# mpileup #
###########

# TODO

###########
# bam2vcf #
###########

BAM2VCF_NAME=bam2vcf.$$
COMMAND="sbatch -t 24:00:00 -c 1 -A prod001 -J ${BAM2VCF_NAME} --output=/mnt/hds/proj/bioinfo/LOG/${$}.bam2vcf-%j.out --error=/mnt/hds/proj/bioinfo/LOG/${$}.bam2vcf-%j.err --mail-type=ALL --mail-user=kenny.billiau@scilifelab.se"

trap - EXIT
