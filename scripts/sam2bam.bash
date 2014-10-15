#!/bin/bash

source log.bash

log 'BASH' 'Creating bash script ...'
TMP=$(mktemp -d)

# set trap
cleanup() {
    rm -Rf ${TMP}
    exit
}
trap cleanup EXIT

MAX_THREADS=${1}
OUTPUTFILE=${2%.bam}
shift
shift

# We would need 1thread/program, but by the time samtools sort kicks in
# the samtools view programs are finished, use 16 threads for sorting/merging,

# get the amount of mem of the machine in kB
MAX_MEM=`cat /proc/meminfo | grep MemTotal | sed "s/MemTotal: *\(.*\) kB/\1/"`
# amount of memory for each thread in GB (use about 90% of the machine's memory)
MAX_THREAD_MEM=$(( MAX_MEM / 1000000 * 9/10 / ${MAX_THREADS} ))

sam2bambash="${TMP}/sam2bam.bash"
echo '#!/bin/bash' > $sam2bambash
echo '' >> $sam2bambash
echo '{' >> $sam2bambash
first=$1 # get the headers of the first file
echo "	samtools view -Sh ${first}" >> $sam2bambash
shift
# for each input file start a 'samtools view' instance
for f in "$@"; do
    echo "	samtools view -S ${f}" >> $sam2bambash
done
echo "} | samtools view -ubS - | samtools sort -@ ${MAX_THREADS} -m ${MAX_THREAD_MEM}G - ${OUTPUTFILE}" >> $sam2bambash

cat $sam2bambash

# run run run!
log 'SAM2BAM' 'Starting sam2bam ...'
COMMAND="bash $sam2bambash"
log 'SAM2BAM' "$COMMAND"
$COMMAND
log 'SAM2BAM' 'Done.'

# reset trap
trap - EXIT
cleanup
