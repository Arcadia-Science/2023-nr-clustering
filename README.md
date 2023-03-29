# Clustering NCBI's nr database

NCBI now provides [a clustered nr database](https://ncbiinsights.ncbi.nlm.nih.gov/2022/05/02/clusterednr_1/) when users perform BLASTP queries using [NCBI's online interface](https://blast.ncbi.nlm.nih.gov/Blast.cgi?PROGRAM=blastp&PAGE_TYPE=BlastSearch&LINK_LOC=blasthome).
We were interested in using this database to reduce search times and to increase the taxonomic diversity of returned sequences when doing BLAST searches.
However, as of March 2023, the database is not available for download.
Therefore, we re-made this database ourselves.
The [Snakefile](./Snakefile) in this repository documents how we performed the clustering and created a taxonomy sheet that annotates the lowest common ancestor for each protein cluster.

## Getting started with this repository

This repository uses snakemake to run the pipeline and conda to manage software environments and installations.
You can find operating system-specific instructions for installing miniconda [here](https://docs.conda.io/en/latest/miniconda.html).
We executed the pipeline on AWS EC2 with an Ubuntu image (ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-20230208).

```
curl -JLO https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh # download the miniconda installation script
bash Miniconda3-latest-Linux-x86_64.sh # run the miniconda installation script. Accept the license and follow the defaults.
source ~/.bashrc # source the .bashrc for miniconda to be available in the environment
# configure miniconda channel order
conda config --add channels defaults
conda config --add channels bioconda
conda config --add channels conda-forge
conda config --set channel_priority strict # make channel priority strict so snakemake doesn't yell at you
conda install mamba # install mamba for faster software installation.

conda env create -n nr -f environment.yml
conda activate nr
```

After cloning the repository, you can then run the snakefile with:

```
snakemake -j 1 --use-conda --rerun-incomplete -k -n
```

where `-j` specifies the number of threads to run with, `--use-conda` uses conda to manage software environments, `--rerun-incomplete` re-runs incomplete files, `-k` tells the pipeline to continue with independent steps when one step fails, and `-n` signifies to run a dry run first.
