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
SCRIPTSDIR=${3-'/mnt/hds/proj/bioinfo/git/kenny/wga/scripts/'}
MAILUSER='kenny.billiau@scilifelab.se'
MAILTYPE='ALL'

#########
# usage #
#########

if [[ ${#@} < 2 ]]; then
    echo "USAGE: $0 inputdir outputdir [scriptsdir]"
    exit 2 # exit code 2 is for missing arguments, right?
fi

[[ ! -d ${OUTDIR} ]] && mkdir ${OUTDIR}

#############
# functions #
#############

source log.bash

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
        if [[ ! -e ${INDIR}/${i}/${filename} ]]; then
            ln -s ${INDIR}/${filename} ${INDIR}/${i}/${filename}
        fi
    done
done
startpos=`echo $(( $endpos + 1 ))`
endpos=`echo $(( ${#files[@]} - 1 ))`
for j in `seq ${startpos} ${endpos}`; do
    filename=`basename ${files[$j]}`
    if [[ ! -e ${INDIR}/${NUM_NODES}/${filename} ]]; then
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
    ALIGN_OUTFILE=${OUTDIR}/aln.${i}.sam
    if [[ ! -e ${ALIGN_OUTFILE} ]]; then
        ALIGN_INDIR=${INDIR}/${i}/
        COMMAND="sbatch -c 16 -N 1 -t 6:00:00 -A prod001 -J ${ALIGN_NAME} --output=${LOGDIR}/${$}.named_wgalign-${i}-%j.out --error=${LOGDIR}/${$}.named_wgalign-${i}-%j.err --mail-type=${MAILTYPE} --mail-user=${MAILUSER} ${SCRIPTSDIR}/named_align.bash ${REF_GENOME} ${ALIGN_INDIR} ${ALIGN_OUTFILE} \"${FORWARD_PATTERN}\" \"${REVERSE_PATTERN}\""
        RS=`$COMMAND`
        ALIGN_JOBIDS[$(( $i - 1 ))]=${RS##* }
        log 'ALIGN' "$COMMAND"
    else
        log 'ALIGN' "$ALIGN_OUTFILE already present!"
    fi
    SAM2BAM_INFILES[$(( $i - 1 ))]=${ALIGN_OUTFILE}
done

###########
# sam2bam #
###########

SAM2BAM_OUTFILE=${OUTDIR}/aln.bam
if [[ ! -e ${SAM2BAM_OUTFILE} ]]; then
    # job is dependent on ALIGN to finish first
    SAM2BAM_NAME=sam2bam.$$
    DEPENDENCY=""
    if [[ -n $ALIGN_JOBIDS ]]; then
        JOINED_ALIGN_JOBIDS=`join : ${ALIGN_JOBIDS[@]}`
        DEPENDENCY="--dependency=afterok:${JOINED_ALIGN_JOBIDS}"
    fi
    COMMAND="sbatch -t 2:00:00 -c 16 -A prod001 -J ${SAM2BAM_NAME} $DEPENDENCY --output=/mnt/hds/proj/bioinfo/LOG/${$}.sam2bam-%j.out --error=/mnt/hds/proj/bioinfo/LOG/${$}.sam2bam-%j.err --mail-type=${MAILTYPE} --mail-user=${MAILUSER} ${SCRIPTSDIR}/sam2bam.bash 16 ${SAM2BAM_OUTFILE} ${SAM2BAM_INFILES[@]}"
    RS=`$COMMAND`
    SAM2BAM_JOBID=${RS##* }
    log 'SAM2BAM' "$COMMAND"
else
    log 'SAM2BAM' "$SAM2BAM_OUTFILE Already present!"
fi

###########
# mpileup #
###########

MPILEUP_OUTFILE=${OUTDIR}/aln.mpileup
if [[ ! -e ${MPILEUP_OUTFILE} ]]; then
    MPILEUP_NAME=mpileup.$$
    MPILEUPDEPENDENCY=""
    if [[ -n $SAM2BAM_JOBID ]]; then
        MPILEUPDEPENDENCY="--dependency=afterok:${SAM2BAM_JOBID}"
    fi

    # first, calculate the lengths of all reference regions in the ref file
    REGIONS_FILE=`mktemp`
    COMMAND="${SCRIPTSDIR}/seqlength.awk"
    log 'SEQLEN' "$COMMAND < $REF_GENOME > $REGIONS_FILE"
    $COMMAND < $REF_GENOME > $REGIONS_FILE
    log 'SEQLEN' 'Done.'

    # start op a process of samtools for each region
    i=0
    while read REGION; do
        LOCAL_MPILEUP_OUTFILE=${MPILEUP_OUTFILE}.${i}
        if [[ ! -e ${LOCAL_MPILEUP_OUTFILE} ]]; then
            COMMAND="sbatch -t 4:00:00 -c 1 -A prod001 -J ${MPILEUP_NAME} ${MPILEUPDEPENDENCY} --output=/mnt/hds/proj/bioinfo/LOG/${$}.mpileup-${i}-%j.out --error=/mnt/hds/proj/bioinfo/LOG/${$}.mpileup-${i}-%j.err --mail-type=${MAILTYPE} --mail-user=${MAILUSER} ${SCRIPTSDIR}/samtools_mpileup.bash $REF_GENOME ${REGION// /.} ${SAM2BAM_OUTFILE} ${LOCAL_MPILEUP_OUTFILE}"
            RS=`$COMMAND`
            MPILEUP_JOBIDS[${i}]=${RS##* }
            log 'MPILEUP' "$COMMAND"
        else
            log 'MPILEUP' "${LOCAL_MPILEUP_OUTFILE} Already present!"
        fi
        i=$(( $i + 1 ))
    done < $REGIONS_FILE

    # cp all mpileup files into one
    log 'MPILEUP' 'Cat-ing to one file ... '
    cat `ls ${MPILEUP_OUTFILE}.*` > ${MPILEUP_OUTFILE}
    rm ${MPILEUP_OUTFILE}.*
    log 'MPILEUP' 'Done.'
else
    log 'MPILEUP' "$MPILEUP_OUTFILE Already present!"
fi

###########
# bam2vcf #
###########

BAM2VCF_NAME=bam2vcf.$$
BAM2VCFDEPENDENCY=""
if [[ -n $MPILEUP_JOBIDS ]]; then
    JOINED_MPILEUP_JOBIDS=`join : ${MPILEUP_JOBIDS[@]}`
    BAM2VCFDEPENDENCY="--dependency=afterok:${JOINED_MPILEUP_JOBIDS}"
fi
COMMAND="sbatch -t 12:00:00 -c 1 -A prod001 -J ${BAM2VCF_NAME} ${BAM2VCFDEPENDENCY} --output=/mnt/hds/proj/bioinfo/LOG/${$}.bam2vcf-%j.out --error=/mnt/hds/proj/bioinfo/LOG/${$}.bam2vcf-%j.err --mail-type=${MAILTYPE} --mail-user=${MAILUSER} ${SCRIPTSDIR}/bam2vcf.bash ${MPILEUP_OUTFILE} ${OUTDIR}"
RS=`$COMMAND`
log 'BAM2VCF' "$COMMAND"

trap - EXIT
