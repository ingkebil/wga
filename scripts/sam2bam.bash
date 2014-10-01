#!/bin/bash

NOW=$(date +"%Y%m%d%H%M%S")

echo 'Creating bash script ...'
TMP=$(mktemp -d)

# set trap
cleanup() {
    rm -Rf ${TMP}
    exit
}
trap cleanup EXIT

MAX_THREADS=${1}
OUTPUTFILE=${1}
shift
shift

# Use 16 threads for sorting/merging,
# by then the 'samtools view' commands are finished

# amount of memory for each thread in GB
MAX_THREAD_MEM=$(( 110 / ${MAX_THREADS} ))

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
echo "} | samtools view -ubS - | samtools sort -@ ${MAX_THREADS} -m ${MAX_THREAD_MEM}G - ${sam2bambash}" >> $sam2bambash

# run run run!
echo 'Starting sam2bam ...'
bash $sam2bambash "${OUTPUTFILE}"

# reset trap
trap - EXIT
cleanup

NOW=$(date +"%Y%m%d%H%M%S")
echo [${NOW}] done
