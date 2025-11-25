# Installing RNA-seq scripts on Alliance Canada

### Steps

1. [Installing of the scripts](#Installing-of-the-scripts)
   1. [Change directory to `projects` folder](#Change-directory-to-projects-folder)
   2. [Clone repository](#Clone-repository)
2. [Updating scripts](#Updating-scripts)
3. [After installing or updating the scripts](#After-installing-or-updating-the-scripts)
   1. [Creating python virtual environment for nf-core](#Creating-python-virtual-environment-for-nf-core)
   2. [Downloading containers used by nf-core](#Downloading-containers-used-by-nf-core)

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
cd ~/projects/def-bmartin/scripts/rnaseq
git pull
```

For Rorqual server, use

```shell
cd ~/links/projects/def-bmartin/scripts/rnaseq
git pull
```

## After installing or updating the scripts

After installing or updating the scripts, you may need to do the following steps.

First, save the RNA-seq scripts folder location in a variable.

```shell
rnaseq_folder=~/projects/def-bmartin/scripts/rnaseq
```

For Rorqual server, use

```shell
rnaseq_folder=~/links/projects/def-bmartin/scripts/rnaseq
```

### Creating python virtual environment for nf-core

```shell
bash $rnaseq_folder/nfcore-create-env.sh
```

### Downloading containers used by nf-core

```shell
bash $rnaseq_folder/nfcore-download-containers.sh
```

### Download bedGraphToBigWig

```shell
wget https://hgdownload.soe.ucsc.edu/admin/exe/linux.x86_64.v479/bedGraphToBigWig
chmod 755 bedGraphToBigWig
```
