#!/bin/bash
#SBATCH --account=def-bmartin
#SBATCH --time=2:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --output=genomecov-%A_%a.out

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
  echo "Usage: genome-coverage.sh [--index int] [--samplesheet samplesheet.csv] [--genome hg38.chrom.sizes] " \
       "[--output output/star_salmon] [--scales scale-factors.txt] [--scales_column 3] [--suffix .depth_scaled]"
  echo "  --index: Index of sample in samplesheet (default: 1 or SLURM_ARRAY_TASK_ID+1 if present)"
  echo "  --samplesheet: Samplesheet file (default: samplesheet.csv)"
  echo "  --genome: Genome chromosome sizes file (default: hg38.chrom.sizes)"
  echo "  --output: Output folder where BAM files are located (default: output/star_salmon)"
  echo "  --scales: File containing scale factors (default: \$output/scale-factors.txt)"
  echo "  --scales_column: File containing scale factors (default: 3)"
  echo "  --suffix: Output file suffix (default: .depth_scaled)"
  exit 1
}

# Parsing arguments.
if ! valid_args=$(getopt -o i:s:g:o:S:c:f:h --long index:,samplesheet:,genome:,output:,scales:,scales_column:,suffix:,help -- "$@")
then
  usage
fi

eval set -- "$valid_args"
while true
do
  case "$1" in
    -i | --index)
        index=$2
        shift 2
        ;;
    -s | --samplesheet)
        samplesheet=$2
        shift 2
        ;;
    -g | --genome)
        genome=$2
        shift 2
        ;;
    -o | --output)
        output=$2
        shift 2
        ;;
    -S | --scales)
        scales=$2
        shift 2
        ;;
    -c | --scales_column)
        scales_column=$2
        shift 2
        ;;
    -f | --suffix)
        suffix=$2
        shift 2
        ;;
    -h | --help)
        usage
        ;;
    --) shift;
        break
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
  >&2 echo "Error: --index parameter '$index' is not an integer."
  usage
fi
if ! [[ -f "$samplesheet" ]]
then
  >&2 echo "Error: --samplesheet file parameter '$samplesheet' does not exists."
  usage
fi
if ! [[ -f "$genome" ]]
then
  >&2 echo "Error: --genome file parameter '$genome' does not exists."
  usage
fi
if ! [[ -d "$output" ]]
then
  >&2 echo "Error: --output folder parameter '$output' does not exists."
  usage
fi
if ! [[ -f "$scales" ]]
then
  >&2 echo "Error: --scales file parameter '$scales' does not exists."
  usage
fi
if ! [[ "$scales_column" =~ ^[0-9]+$ ]]
then
  >&2 echo "Error: --scales_column parameter '$scales_column' is not an integer."
  usage
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
