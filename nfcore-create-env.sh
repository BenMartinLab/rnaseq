#!/bin/bash

if [[ -n "$CC_CLUSTER" ]]
then
  module purge
  module load StdEnv/2023
  module load python/3.13
fi

script_path=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
cd "$script_path" || { echo "Folder $script_path does not exists"; exit 1; }

rm -rf nfcore-env
python -m venv nfcore-env
source nfcore-env/bin/activate
python -m pip install --upgrade pip
python -m pip install nf_core==3.2.1 pysam==0.23.3
