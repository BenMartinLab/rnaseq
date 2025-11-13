# RNA-seq data analysis

This repository contains scripts to analyse RNA-seq data using [nf-core pipeline](#https://nf-co.re/rnaseq) on Alliance Canada servers.

To install the scripts on Alliance Canada servers and download genomes, see [INSTALL.md](#INSTALL.md)

### Steps

1. [Choose server to use](#Choose-server-to-use)
2. [Transfer data to scratch](#Transfer-data-to-scratch)
3. [Prepare working environment](#Prepare-working-environment)
4. [Run the nf-core pipeline on Rorqual or Narval](#Run-the-nf-core-pipeline-on-Rorqual-or-Narval)
5. [Run the nf-core pipeline on Fir](#Run-the-nf-core-pipeline-on-Fir)
6. [Computing scale factors](#Computing-scale-factors)

## Choose server to use

While you can run nf-core pipelines on any general servers, you will find it easier to run nf-core on Rorqual or Narval.

## Transfer data to scratch

You will need to transfer the following files on the server in the `scratch` folder.

* FASTQ files.
* Genome files (FASTA and GTF). See [Genomes](https://github.com/BenMartinLab/genomes).
* Samplesheet file. See [Samplesheet for RNA-seq pipeline](#https://nf-co.re/rnaseq/3.19.0/docs/usage/#samplesheet-input)
* Any additional files that are needed for your analysis.

There are many ways to transfer data to the server. Here are some suggestions.

* Use an FTP software like [WinSCP](https://winscp.net) (Windows), [Cyberduck](https://cyberduck.io) (Mac), [FileZilla](https://filezilla-project.org).
* Use command line tools like `rsync` or `scp`.

## Prepare working environment

Add RNA-seq scripts folder to your PATH.

```shell
export PATH=~/projects/def-bmartin/scripts/rnaseq:$PATH
```

For Rorqual server, use

```shell
export PATH=~/links/projects/def-bmartin/scripts/rnaseq:$PATH
```

Load modules and virtual environment.

```shell
source nfcore-init.sh
```

Set additional variables.

```shell
samplesheet=samplesheet.csv
```

```shell
genome=hg38-spike-dm6
```

Set spike variable, if spike-in was used.

```shell
spike=dm6
```

## Run the nf-core pipeline on Rorqual or Narval

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

From the tmux session, start the pipeline using the following command.

```shell
nfcore-rnaseq.sh -profile alliance_canada --input $samplesheet --outdir output --fasta $genome.fa --gtf $genome.gtf
```

## Run the nf-core pipeline on Fir

Please use Rorqual or Narval when possible because running nf-core pipelines on Fir is much less trivial because the login node virtual memory limit cannot be changed.

You can still run the pipeline by using `sbatch` to run the nf-core pipeline on a compute node. The main issue of running the nf-core pipeline this way is that the output file will be difficult to read.

```shell
sbatch nfcore-rnaseq.sh -profile alliance_canada --input $samplesheet --outdir output --fasta $genome.fa --gtf $genome.gtf
```

## Computing scale factors

```shell
sbatch scale-factors.sh --bam output/star_salmon/*.bam --output output/star_salmon/scale-factors.txt --samplesheet $samplesheet --spike_fasta $spike.fa --mean
```
