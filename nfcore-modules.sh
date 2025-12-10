#!/bin/bash

if [[ -n "$CC_CLUSTER" ]]
then
  module purge
  module load StdEnv/2023
  module load python/3.13
  module load rust
  module load postgresql
  module load nextflow/25
  module load apptainer/1
fi

export SLURM_ACCOUNT=def-bmartin
export NXF_SINGULARITY_CACHEDIR=/project/def-bmartin/NXF_SINGULARITY_CACHEDIR
export NXF_OPTS="-Xms500M -Xmx8000M"
