# Clustering NCBI's nr database

NCBI now provides [a clustered nr database](https://ncbiinsights.ncbi.nlm.nih.gov/2022/05/02/clusterednr_1/) when users perform BLASTP queries using [NCBI's online interface](https://blast.ncbi.nlm.nih.gov/Blast.cgi?PROGRAM=blastp&PAGE_TYPE=BlastSearch&LINK_LOC=blasthome).
We were interested in using this database to reduce search times and to increase the taxonomic diversity of returned sequences when doing BLAST searches.
However, as of March 2023, the database is not available for download.
Therefore, we re-made this database ourselves.
The [Snakefile](./Snakefile) in this repository documents how we performed the clustering and created a taxonomy sheet that annotates the lowest common ancestor for each protein cluster.
It starts by downloading the [NCBI nr database in FASTA format](https://ftp.ncbi.nlm.nih.gov/blast/db/v5/FASTA) (143Gb in March 2023).
After clustering this file at 90% length and 90% identity, it then determines the lowest common ancestor for each cluster using the [prot.accession2taxid.FULL files](https://ftp.ncbi.nih.gov/pub/taxonomy/accession2taxid/) (12Gb in March 2023) and the [taxdump files](https://ftp.ncbi.nlm.nih.gov/pub/taxonomy/).
The final output includes the representative sequences in FASTA format, a TSV file that reports cluster representatives and members, and an SQLite DB with representative sequence names and their taxonomic lineages (as taxid and as names).

## Outputs & Downloads

**The database and associated taxonomy files are available for download on [OSF](https://osf.io/tejwd/).**

Description of output files:
* `nr_rep_seq.fasta.gz`: FASTA file of representative sequences output by mmseqs2 `easy-linclust`.
* `nr_cluster.tsv`: TSV file documenting cluster membership. The first column records the representative sequence identifier, while the second column records the sequence identifiers for member sequences of the cluster.
* `nr_cluster_taxid_formatted_final.tsv.gz`: TSV file recording the representative sequence for a cluster, the lowest common ancestor taxomony ID, the named lineage of the lowest common ancestor, and taxonomy ID lineage of the lowest common ancestor. A snippet of the file is presented below. 
```
rep	taxid	lca_taxid	lca_lineage_named	lca_lineage_taxid
0310191A	2517390	2517390	Eukaryota;Metazoa;Chordata;Amphibia;Anura;Hyperoliidae;Kassina;Kassina cochranae;unclassified Kassina cochranae subspecies/strain	2759;33208;7711;8292;8342;8412;8413;2517390;
0311203A	9031	9031	Eukaryota;Metazoa;Chordata;Aves;Galliformes;Phasianidae;Gallus;Gallus gallus;unclassified Gallus gallus subspecies/strain	2759;33208;7711;8782;8976;9005;9030;9031;
0311203B	9940	9940	Eukaryota;Metazoa;Chordata;Mammalia;Artiodactyla;Bovidae;Ovis;Ovis aries;unclassified Ovis aries subspecies/strain	2759;33208;7711;40674;91561;9895;9935;9940;
```
* `nr_cluster_taxid_formatted_final.sqlite`: An SQLite database of the `nr_cluster_taxid_formatted_final.tsv.gz` TSV file. The name of the database was recorded as `nr_cluster_taxid_table` (see [this script](./scripts/make_sqlite_db.R)). For an example of how to use the database to assign lineages to BLAST results, see [this script](https://github.com/Arcadia-Science/2023-rehgt/blob/main/bin/blastp_add_taxonomy_info.R).

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

## Citation

This repository is associated with [this pub]().
You can read more about the project therein.
