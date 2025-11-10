# RNA-seq data analysis

This repository contains scripts to analyse RNA-seq data using [nf-core pipeline](#https://nf-co.re/rnaseq) on Alliance Canada servers.

To install the scripts on Alliance Canada servers and download genomes, see [INSTALL.md](#INSTALL.md)

## Choose server to use

While you can run nf-core pipelines on any general servers, you will find it easier to run nf-core on Rorqual or Narval.

## Transfer data to scratch

You will need to transfer the following files on the server in the `scratch` folder.

* FASTQ files.
* Genome files (FASTA and GTF). See [Genomes](#https://github.com/BenMartinLab/genomes).
* Samplesheet file. See [Samplesheet for RNA-seq pipeline](#https://nf-co.re/rnaseq/3.19.0/docs/usage/#samplesheet-input)
* Any additional files that are needed for your analysis.

There are many ways to transfer data to the server. Here are some suggestions.

* Use an FTP software like [WinSCP](https://winscp.net) (Windows), [Cyberduck](https://cyberduck.io) (Mac), [FileZilla](https://filezilla-project.org).
* Use command line tools like `rsync` or `scp`.

## Add RNA-seq scripts folder to your PATH

```shell
export PATH=~/projects/def-bmartin/scripts/rnaseq:$PATH
```

For Rorqual server, use

```shell
export PATH=~/links/projects/def-bmartin/scripts/rnaseq:$PATH
```

## Run the pipeline on Rorqual or Narval

### Create tmux session

You need to remember on which login node you started the tmux session in case you get disconnected from the server. If you have trouble remembering the login node, connect to the first login node.

To connect to the first login node on Narval, use this command.

```shell
ssh narval1
```

To connect to the first login node on Rorqual, use this command.

```shell
ssh rorqual1
```

### Start a new tmux session

```shell
tmux new -s rnaseq
```

Once inside the tmux session, you may find it difficult to return to your regular shell. Use Ctrl+b than d to detach from the tmux session.

To reattach to the tmux session, use this command (must be executed from the same login node on which you started the session).

```shell
tmux a -t rnaseq
```

You can see active tmux sessions using this command.

```shell
tmux ls
```

For more information on tmux, see [tmux documentation](https://github.com/tmux/tmux/wiki).

Cheatsheet for tmux [https://tmuxcheatsheet.com](https://tmuxcheatsheet.com).

### Run the pipeline

Set genome as a variable.

```shell
genome=hg38-ensembl-115
```

From the tmux session, start the pipeline using the following command.

> [!IMPORTANT]
> Replace `$samplesheet.csv` with the actual samplesheet.

```shell
run-nfcore.sh -profile alliance_canada --input $samplesheet.csv --outdir output --fasta $genome.fa --gtf $genome.gtf
```

## Run the pipeline on Fir

Please use Rorqual or Narval when possible because running nf-core pipelines on Cedar is much less trivial because the login node virtual memory limit cannot be changed.

You can still run the pipeline by creating a bash script (named rnaseq.sh for example) file containing the following.

> [!IMPORTANT]
> Replace `samplesheet.csv` and `genome` value with the actual samplesheet and genome names. 

```shell
#SBATCH --account=def-bmartin
#SBATCH --time=2-00:00:00
#SBATCH --cpus-per-task=1
#SBATCH --mem=4G

# Stop if an error is encountered.
set -e

export PATH=~/projects/def-bmartin/scripts/rnaseq:$PATH

genome=hg38-ensembl-115

run-nfcore.sh \
    -profile alliance_canada \
    --input samplesheet.csv \
    --outdir output \
    --fasta $genome.fa \
    --gtf $genome.gtf
```

Then submit the script for execution:

```shell
sbatch rnaseq.sh
```

The main issue of running the script this way is that the log file will be difficult to read.

### Alternative using the wait script

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
genome=hg38-ensembl-115
```

Run the pipeline.

> [!IMPORTANT]
> Replace `$samplesheet.csv` with the actual samplesheet.

```shell
run-nfcore.sh -profile alliance_canada --input $samplesheet.csv --outdir output --fasta $genome.fa --gtf $genome.gtf
```
