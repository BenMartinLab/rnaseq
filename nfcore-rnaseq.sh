#!/bin/bash
#SBATCH --account=def-bmartin
#SBATCH --time=2-00:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --output=nfcore-rnaseq-%A.out

script_path=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
if ! [[ -f "${script_path}/nfcore-rnaseq.sh" ]] && [[ -n "$SLURM_JOB_ID" ]]
then
  script_path=$(dirname "$(scontrol show job "$SLURM_JOB_ID" | awk -F '=' '$0 ~ /Command=/ {print $2; exit}')")
fi
source "${script_path}/nfcore-modules.sh"

echo "Launching nf-core pipeline ${script_path}/nf-core-rnaseq_3.22.2/3_22_2"
nextflow run "${script_path}/nf-core-rnaseq_3.22.2/3_22_2/" -c "${script_path}/nextflow.config" \
    "$@"
