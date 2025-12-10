#!/bin/bash
#SBATCH --account=def-bmartin
#SBATCH --time=2:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --output=genome-coverage-%A_%a.out

# exit when any command fails
set -e

if [[ -n "$CC_CLUSTER" ]]
then
  module purge
  module load StdEnv/2023
  module load bedtools/2.31.0
  echo
fi

index=${SLURM_ARRAY_TASK_ID:-0}
index=$((index+1))
threads=${SLURM_CPUS_PER_TASK:-1}
tmpdir=${SLURM_TMPDIR:-/tmp}

samplesheet=samplesheet.csv
genome=hg38.chrom.sizes
output=output/star_salmon
scales_column=3
suffix=.depth_scaled

# Usage function
usage() {
  echo
  echo "Usage: genome-coverage.sh [-i int] [-s samplesheet.csv] [-g hg38.chrom.sizes] " \
       "[-o output/star_salmon] [-S scale-factors.txt] [-c 3] [-f .depth_scaled]"
  echo "  -i: Index of sample in samplesheet (default: 1 or SLURM_ARRAY_TASK_ID+1 if present)"
  echo "  -s: Samplesheet file (default: samplesheet.csv)"
  echo "  -g: Genome chromosome sizes file (default: hg38.chrom.sizes)"
  echo "  -o: Output folder where BAM files are located (default: output/star_salmon)"
  echo "  -S: File containing scale factors (default: \$output/scale-factors.txt)"
  echo "  -c: File containing scale factors (default: 3)"
  echo "  -f: Output file suffix (default: .depth_scaled)"
  echo "  -h: Show this help"
}

# Parsing arguments.
while getopts 'i:s:g:o:S:c:f:h' OPTION; do
  case "$OPTION" in
    i)
       index="$OPTARG"
       ;;
    s)
       samplesheet="$OPTARG"
       ;;
    g)
       genome="$OPTARG"
       ;;
    o)
       output="$OPTARG"
       ;;
    S)
       scales="$OPTARG"
       ;;
    c)
       scales_column="$OPTARG"
       ;;
    f)
       suffix="$OPTARG"
       ;;
    h)
       usage
       exit 0
       ;;
    :)
       usage
       exit 1
       ;;
    ?)
       usage
       exit 1
       ;;
  esac
done

if [[ -z "$scales" ]]
then
  scales="$output"/scale-factors.txt
fi

# Validating arguments.
if ! [[ "$index" =~ ^[0-9]+$ ]]
then
  >&2 echo "Error: -i parameter '$index' is not an integer."
  usage
  exit 1
fi
if ! [[ -f "$samplesheet" ]]
then
  >&2 echo "Error: -s file parameter '$samplesheet' does not exists."
  usage
  exit 1
fi
if ! [[ -f "$genome" ]]
then
  >&2 echo "Error: -g file parameter '$genome' does not exists."
  usage
  exit 1
fi
if ! [[ -d "$output" ]]
then
  >&2 echo "Error: -o folder parameter '$output' does not exists."
  usage
  exit 1
fi
if ! [[ -f "$scales" ]]
then
  >&2 echo "Error: -S file parameter '$scales' does not exists."
  usage
  exit 1
fi
if ! [[ "$scales_column" =~ ^[0-9]+$ ]]
then
  >&2 echo "Error: -C parameter '$scales_column' is not an integer."
  usage
  exit 1
fi


sample=$(awk -F ',' -v sample_index="$index" \
    'NR > 1 && !seen[$1] {ln++; seen[$1]++; if (ln == sample_index) {print $1}}' "$samplesheet")
sample="${sample%%[[:cntrl:]]}"
scale=$(awk -v sample="$sample" -v print_column="$scales_column" \
    '$1 == sample {print $print_column}' "$scales")

if [ "$scale" == "" ] || [ "$scale" == "NA" ]
then
  >&2 echo "Error: scale factor for sample '$sample' is '$scale' and coverage cannot be computed, exiting..."
  exit 1
fi

bam="${output}/${sample}.markdup.sorted.bam"
if [[ ! -f "$bam" ]]
then
  >&2 echo "Error: BAM file '${sample}.markdup.sorted.bam' does not exists in output folder '$output', exiting..."
  exit 1
fi

echo "Running bedtools genomecov on positive strand for sample $sample on BAM $bam"
bedtools genomecov \
    -split \
    -du \
    -strand + \
    -bg \
    -scale "$scale" \
    -ibam "$bam" \
    | LC_ALL=C sort --parallel="$threads" -k1,1 -k2,2n \
    > "${tmpdir}/${sample}.forward.bedGraph"
bedGraphToBigWig \
    "${tmpdir}/${sample}.forward.bedGraph" \
    "$genome" \
    "${output}/bigwig/${sample}${suffix}.forward.bigWig"

echo "Running bedtools genomecov on negative strand for sample $sample on BAM $bam"
bedtools genomecov \
    -split \
    -du \
    -strand + \
    -bg \
    -scale "$scale" \
    -ibam "$bam" \
    | awk -F '\t' -v OFS='\t' '$4=0-$4 {print}' \
    | LC_ALL=C sort --parallel="$threads" -k1,1 -k2,2n \
    > "${tmpdir}/${sample}.reverse.bedGraph"
bedGraphToBigWig \
    "${tmpdir}/${sample}.reverse.bedGraph" \
    "$genome" \
    "${output}/bigwig/${sample}${suffix}.reverse.bigWig"
