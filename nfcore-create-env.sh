#!/bin/bash

if [[ -n "$CC_CLUSTER" ]]
then
  module purge
  module load StdEnv/2023
  module load python/3.13
fi

script_path=$(dirname "$(readlink -f "$0")")
cd "$script_path" || { echo "Folder $script_path does not exists"; exit 1; }

python -m venv nfcore-env
source nfcore-env/bin/activate
python -m pip install nf_core==3.2.1

echo
echo

echo "Example to run the chipseq pipeline:"
echo "nextflow run nf-core-rnaseq_3.19.0/3_19_0/ \\"
echo "    -profile test,alliance_canada \\"
echo "    --outdir output"
