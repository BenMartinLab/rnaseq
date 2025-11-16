#!/bin/bash
#SBATCH --account=def-bmartin
#SBATCH --time=12:00:00
#SBATCH --cpus-per-task=4
#SBATCH --mem=4G
#SBATCH --mail-type=NONE
#SBATCH --output=split-bam-%A_%a.out

# Exit on errors.
set -e

if [[ -n "$CC_CLUSTER" ]]
then
  module purge
  module load StdEnv/2023
  module load samtools/1.20
  echo
fi

index=${SLURM_ARRAY_TASK_ID:-0}
index=$((index+1))
threads=${SLURM_CPUS_PER_TASK:-1}
tmpdir=${SLURM_TMPDIR:-/tmp}

samplesheet=samplesheet.csv
spike=dm6.fa
output=output/star_salmon
suffix=.main
spike_suffix=.spike

# Usage function
usage() {
  echo
  echo "Usage: split-bam.sh [--index int] [--samplesheet samplesheet.csv] [--spike dm6.fa] " \
       "[--output output/star_salmon] [--suffix .main] [--spike_suffix .spike]"
  echo "  --index (-i): Index of sample in samplesheet (default: 1 or SLURM_ARRAY_TASK_ID+1 if present)"
  echo "  --samplesheet (-s): Samplesheet file (default: samplesheet.csv)"
  echo "  --spike (-k): Genome file of spike-in organism (default: dm6.fa)"
  echo "  --output (-o): Output folder where BAM files are located (default: output/star_salmon)"
  echo "  --suffix (-f): Output file suffix appended to sample name (default: .main)"
  echo "  --spike_suffix (-F): Output file suffix for spike-in BAM appended to sample name (default: .spike)"
  echo "  --threads (-t): Number of threads (default: 1 or SLURM_CPUS_PER_TASK if present)"
  echo "  --help (-h): Show this help"
}

# Parsing arguments.
if ! valid_args=$(getopt -o i:s:k:o:f:F:t:h --long index:,samplesheet:,spike:,output:,suffix:,spike_suffix:,threads:,help -- "$@")
then
  usage
  exit 1
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
    -k | --spike)
        spike=$2
        shift 2
        ;;
    -o | --output)
        output=$2
        shift 2
        ;;
    -f | --suffix)
        suffix=$2
        shift 2
        ;;
    -F | --spike_suffix)
        spike_suffix=$2
        shift 2
        ;;
    -t | --threads)
        threads=$2
        shift 2
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    --) shift;
        break
        ;;
  esac
done

# Validating arguments.
if ! [[ "$index" =~ ^[0-9]+$ ]]
then
  >&2 echo "Error: --index parameter '$index' is not an integer."
  usage
  exit 1
fi
if ! [[ -f "$samplesheet" ]]
then
  >&2 echo "Error: --samplesheet file parameter '$samplesheet' does not exists."
  usage
  exit 1
fi
if ! [[ -f "$spike" ]]
then
  >&2 echo "Error: --spike file parameter '$spike' does not exists."
  usage
  exit 1
fi
if ! [[ -d "$output" ]]
then
  >&2 echo "Error: --output folder parameter '$output' does not exists."
  usage
  exit 1
fi

sample=$(awk -F ',' -v sample_index="$index" \
    'NR > 1 && !seen[$1] {ln++; seen[$1]++; if (ln == sample_index) {print $1}}' "$samplesheet")
sample="${sample%%[[:cntrl:]]}"

bam="${output}/${sample}.markdup.sorted.bam"
if [[ ! -f "$bam" ]]
then
  >&2 echo "Error: BAM file '${sample}.markdup.sorted.bam' does not exists in output folder '$output', exiting..."
  exit 1
fi


echo "Finding reads from spike-in in BAM '${bam}' using fasta '${spike}'"
spike_chromosomes="${tmpdir}/spike_chromosomes.txt"
awk '$0 ~ /^>/ {print substr($1, 2)}' "$spike" \
    > "$spike_chromosomes"
spike_reads="${tmpdir}/${sample}_spike_reads.txt"
samtools view "$bam" \
    --threads "$threads" | \
    awk -F '\t' 'FNR==NR {seen[$1]++; next} seen[$3] {print $1}' "$spike_chromosomes" - \
    > "$spike_reads"
rm "$spike_chromosomes"

output_bam="${output}/${sample}${suffix}.markdup.sorted.bam"
echo "Split reads from main genome to ${output_bam} from BAM ${bam}"
samtools view -b -h "$bam" \
    --threads "$threads" \
    --qname-file "^${spike_reads}" \
    > "$output_bam"

output_bam="${output}/${sample}${spike_suffix}.markdup.sorted.bam"
echo "Split reads from spike-in genome to ${output_bam} from BAM ${bam}"
samtools view -b -h "$bam" \
    --threads "$threads" \
    --qname-file "$spike_reads" \
    > "$output_bam"
rm "$spike_reads"
