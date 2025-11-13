#!/bin/bash
#SBATCH --account=def-bmartin
#SBATCH --time=2-00:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --output=run-nfcore-%A.out

script_path=${RNASEQ_SCRIPTS:-.}

echo "Launching nf-core pipeline ${script_path}/nf-core-rnaseq_3.19.0/3_19_0"
nextflow run "${script_path}/nf-core-rnaseq_3.19.0/3_19_0/" \
    "$@"
