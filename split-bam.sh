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
  echo "Usage: split-bam.sh [-i int] [-s samplesheet.csv] [-k dm6.fa] " \
       "[-o output/star_salmon] [-f .main] [-F .spike] [-t int]"
  echo "  -i: Index of sample in samplesheet (default: 1 or SLURM_ARRAY_TASK_ID+1 if present)"
  echo "  -s: Samplesheet file (default: samplesheet.csv)"
  echo "  -k: Genome file of spike-in organism (default: dm6.fa)"
  echo "  -o: Output folder where BAM files are located (default: output/star_salmon)"
  echo "  -f: Output file suffix appended to sample name (default: .main)"
  echo "  -F: Output file suffix for spike-in BAM appended to sample name (default: .spike)"
  echo "  -t: Number of threads (default: 1 or SLURM_CPUS_PER_TASK if present)"
  echo "  -h: Show this help"
}

# Parsing arguments.
while getopts 'i:s:k:o:f:F:t:h' OPTION; do
  case "$OPTION" in
    i)
       index="$OPTARG"
       ;;
    s)
       samplesheet="$OPTARG"
       ;;
    k)
       spike="$OPTARG"
       ;;
    o)
       output="$OPTARG"
       ;;
    f)
       suffix="$OPTARG"
       ;;
    F)
       spike_suffix="$OPTARG"
       ;;
    t)
       threads="$OPTARG"
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
if ! [[ -f "$spike" ]]
then
  >&2 echo "Error: -k file parameter '$spike' does not exists."
  usage
  exit 1
fi
if ! [[ -d "$output" ]]
then
  >&2 echo "Error: -o folder parameter '$output' does not exists."
  usage
  exit 1
fi

sample=$(awk -F ',' -v sample_index="$index" \
    'NR > 1 && !seen[$1] {ln++; seen[$1]++; if (ln == sample_index) {print $1}}' "$samplesheet")
sample="${sample%%[[:cntrl:]]}"

bam="${output}/${sample}.umi_dedup.sorted.bam"
if [[ ! -f "$bam" ]]
then
  bam="${output}/${sample}.markdup.sorted.bam"
fi
if [[ ! -f "$bam" ]]
then
  >&2 echo "Error: BAM file '${sample}.umi_dedup.sorted.bam' or '${sample}.markdup.sorted.bam' do not exists in output folder '$output', exiting..."
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
