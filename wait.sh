#!/bin/bash
#SBATCH --account=def-bmartin
#SBATCH --time=01:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=1G

# Ideally, this job should be started with parameters setting
# the job name, number of cpus, memory and time:
# sbatch --job-name=nfcore-chipseq --cpus-per-task=2 --mem=4G --time=1-00:00:00 \
#     --output=nfcore-chipseq-%A.out

# Exit on errors.
set -e

echo "Wait indefinitely... Requires manual kill to terminate."
echo "Job id is: ${SLURM_JOB_ID}"
echo ""

echo "Using 'tmux' is advised to connect to this compute node."
echo "Start a new 'tmux' session using:"
echo "tmux new -s session_name"
echo ""

echo "From the tmux session, connect to the login node using the command:"
echo "srun --pty --jobid ${SLURM_JOB_ID} /bin/bash"

while true; do sleep 86400; done
