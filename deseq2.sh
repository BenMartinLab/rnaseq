#!/bin/bash
#SBATCH --account=def-bmartin
#SBATCH --time=2:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=16G
#SBATCH --output=deseq2-%A.out

set -e

if [[ -n "$CC_CLUSTER" ]]
then
  module purge
  module load StdEnv/2023
  module load gcc/12.3
  module load r-bundle-bioconductor/3.21
fi

script_path=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
if ! [[ -f "${script_path}/nfcore-rnaseq.sh" ]] && [[ -n "$SLURM_JOB_ID" ]]
then
  script_path=$(dirname "$(scontrol show job "$SLURM_JOB_ID" | awk -F '=' '$0 ~ /Command=/ {print $2; exit}')")
fi

Rscript "${script_path}/deseq2.R" "$@"
