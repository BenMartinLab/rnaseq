#!/bin/bash
#SBATCH --account=def-bmartin
#SBATCH --time=2:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G
#SBATCH --output=scale-factors-%A.out

script_path=${RNASEQ_SCRIPTS:-.}

echo "Running python script ${script_path}/scale-factors.py"
python "${script_path}/scale-factors.py" "$@"
