# Installing RNA-seq scripts on Alliance Canada

### Steps

1. [Prepare working environment](#Prepare working environment)
2. [Installing of the scripts](#Installing-of-the-scripts)
   1. [Change directory to `projects` folder](#Change-directory-to-projects-folder)
   2. [Clone repository](#Clone-repository)
3. [Updating scripts](#Updating-scripts)
4. [After installing or updating the scripts](#After-installing-or-updating-the-scripts)
   1. [Creating python virtual environment for nf-core](#Creating-python-virtual-environment-for-nf-core)
   2. [Downloading containers used by nf-core](#Downloading-containers-used-by-nf-core)

## Prepare working environment

Set rnaseq script folder.

```shell
rnaseq=~/projects/def-bmartin/scripts/rnaseq
```

For Rorqual server, use

```shell
rnaseq=~/links/projects/def-bmartin/scripts/rnaseq
```

## Installing of the scripts

### Change directory to projects folder

```shell
cd ~/projects/def-bmartin/scripts
```

For Rorqual server, use

```shell
cd ~/links/projects/def-bmartin/scripts
```

### Clone repository

```shell
git clone https://github.com/BenMartinLab/rnaseq.git
```

## Updating scripts

Go to the rnaseq scripts folder and run `git pull`.

```shell
cd $rnaseq
git pull
```

## After installing or updating the scripts

After installing or updating the scripts, you may need to do the following steps.

Move to rnaseq scripts directory. See [Prepare working environment](#Prepare-working-environment).

```shell
cd $rnaseq
```

### Creating python virtual environment for nf-core

```shell
bash nfcore-create-env.sh
```

### Downloading containers used by nf-core

```shell
bash nfcore-download-containers.sh
```

### Download bedGraphToBigWig

```shell
wget https://hgdownload.soe.ucsc.edu/admin/exe/linux.x86_64.v479/bedGraphToBigWig
chmod 755 bedGraphToBigWig
```
