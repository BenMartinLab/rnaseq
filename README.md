# RNA-seq data analysis

This repository contains scripts to analyse RNA-seq data using [nf-core pipeline](https://nf-co.re/rnaseq) on Alliance Canada servers.

To install the scripts on Alliance Canada servers and download genomes, see [INSTALL.md](INSTALL.md)

### Steps

1. [Transfer data to scratch](#Transfer-data-to-scratch)
2. [Prepare working environment](#Prepare-working-environment)
   1. [Set additional variables](#Set-additional-variables)
   2. [UMI deduplication](#UMI-deduplication)
3. [Run the nf-core pipeline](#Run-the-nf-core-pipeline)
4. [Computing scale factors](#Computing-scale-factors)
5. [Genome coverage](#Genome-coverage)
6. [Split BAM (Optional)](#Split-BAM-Optional)

## Transfer data to scratch

You will need to transfer the following files on the server in the `scratch` folder.

* FASTQ files.
* Genome files (FASTA and GTF). See [Genomes](https://github.com/BenMartinLab/genomes).
  * Copy `star` folder for your genome.
* Samplesheet file. See [Samplesheet for RNA-seq pipeline](https://nf-co.re/rnaseq/3.22.2/docs/usage/#samplesheet-input)
  * [Here is an example of a samplesheet file](samplesheet.csv)
* Any additional files that are needed for your analysis.

There are many ways to transfer data to the server. Here are some suggestions.

* Use an FTP software like [WinSCP](https://winscp.net) (Windows), [Cyberduck](https://cyberduck.io) (Mac), [FileZilla](https://filezilla-project.org).
* Use command line tools like `rsync` or `scp`.

## Prepare working environment

Add RNA-seq scripts folder to your PATH.

```shell
export PATH=/project/def-bmartin/scripts/rnaseq:$PATH
```

### Set additional variables

> [!IMPORTANT]
> Change `samplesheet.csv` by your actual samplesheet filename.

```shell
samplesheet=samplesheet.csv
```

```shell
samples_array=$(awk -F ',' \
    'NR > 1 && !seen[$1] {ln++; seen[$1]++} END {print "0-"ln-1}' \
    "$samplesheet")
```

> [!IMPORTANT]
> Change `hg38-spike-dm6` by your actual genome name.

```shell
genome=hg38-spike-dm6
```

> [!IMPORTANT]
> Change `dm6` by your actual spike-in genome name.

```shell
spike=dm6
```

### UMI deduplication

To skip UMI deduplication, use an empty string for `umi_deduplication` variable.

```shell
umi_deduplication=
```

To activate UMI deduplication, use the right parameters from the [usage page](https://nf-co.re/rnaseq/3.22.2/docs/usage/#unique-molecular-identifiers-umi).

> [!IMPORTANT]
> `sbatch` does not process `--umitools_umi_separator` parameter with one character properly. Please use the example for UMI in read name (using `--umitools_umi_separator=:` instead of `--umitools_umi_separator ":"`).

```shell
umi_deduplication='--with_umi --skip_umi_extract --umitools_umi_separator=:'
```

#### UMI at Plasmidsaurus

Plasmidsaurus uses `_` as a separator in the read name.

```shell
umi_deduplication='--with_umi --skip_umi_extract --umitools_umi_separator=_'
```

## Run the nf-core pipeline

```shell
sbatch nfcore-rnaseq.sh -profile alliance_canada \
    --input $samplesheet \
    --outdir output \
    --fasta $genome.fa \
    --gtf $genome.gtf \
    --star_index star \
    $umi_deduplication
```

## Computing scale factors

```shell
sbatch scale-factors.sh \
    --bam output/star_salmon/*.bam \
    --output output/star_salmon/scale-factors.txt \
    --samplesheet $samplesheet \
    --spike_fasta $spike.fa \
    --mean
```

## Genome coverage

Genome coverage using scale factors based on sequencing depth. 

```shell
sbatch --array=$samples_array genome-coverage.sh \
    -s $samplesheet \
    -g $genome.chrom.sizes
```

Genome coverage using spike-in scale factors.

```shell
sbatch --array=$samples_array genome-coverage.sh \
    -s $samplesheet \
    -g $genome.chrom.sizes \
    -c 5 \
    -f .spike_scaled
```

## Split BAM (Optional)

To split BAM files between main genome and spike-in genome, use the following command.

```shell
sbatch --array=$samples_array split-bam.sh \
    -s $samplesheet \
    -k $spike.fa
```
