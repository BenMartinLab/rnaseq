## Alternative using the wait script

While this will not be recommended by anyone working at Alliance Canada, you can cheat a compute node to act in a similar way as Rorqual/Narval's login nodes.

To get this working, you need to start the `wait.sh` script.

```shell
sbatch --job-name=nfcore-rnaseq --cpus-per-task=1 --mem=4G --time=2-00:00:00 wait.sh
```

Once the job is running (check using `squeue -u $USER`), start a tmux session.

```shell
tmux new -s rnaseq
```

Connect to the compute node that is running the `wait.sh` script.

> [!IMPORTANT]
> Replace `$slurm_job_id` with the actual job id - obtained using `squeue -u $USER`.

```shell
srun --pty --jobid $slurm_job_id /bin/bash
```

Set genome as a variable.

```shell
genome=hg38
```

Run the pipeline.

> [!IMPORTANT]
> Replace `$samplesheet.csv` with the actual samplesheet.

```shell
run-nfcore.sh -profile alliance_canada --input $samplesheet.csv --outdir output --fasta $genome.fa --gtf $genome.gtf
```
