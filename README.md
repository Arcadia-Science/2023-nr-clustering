# Clustering NCBI's nr database

NCBI now provides [a clustered nr database](https://ncbiinsights.ncbi.nlm.nih.gov/2022/05/02/clusterednr_1/) when users perform BLASTP queries using [NCBI's online interface](https://blast.ncbi.nlm.nih.gov/Blast.cgi?PROGRAM=blastp&PAGE_TYPE=BlastSearch&LINK_LOC=blasthome).
We were interested in using this database to reduce search times and to increase the taxonomic diversity of returned sequences when doing BLAST searches.
However, as of March 2023, the database is not available for download.
Therefore, re-made this database ourselves.
The [README.sh](./README.sh) file in this repository documents how we performed the clustering and created a taxonomy sheet that annotates the lowest common ancestor for each protein cluster.
