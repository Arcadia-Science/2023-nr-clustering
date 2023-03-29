# The goal of these commands was to build a clustered nr database (90% identity, 90% length)
# nr the NCBI non-redundant protein database for BLAST and other applications.

#############################################################################
## set up
#############################################################################

curl -JLO https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh # download the miniconda installation script
bash Miniconda3-latest-Linux-x86_64.sh # run the miniconda installation script. Accept the license and follow the defaults.
source ~/.bashrc # source the .bashrc for miniconda to be available in the environment
# configure miniconda channel order
conda config --add channels defaults
conda config --add channels bioconda
conda config --add channels conda-forge
conda install mamba # install mamba for faster software installation.
conda create -n mmseqs mmseqs2=14.7e284 csvtk=0.25.0 taxonkit=0.14.2 # only works with taxonkit 0.14.2, which should be released on conda soon
# in the meantime, the executable can be downloaded from this url: https://github.com/shenwei356/taxonkit/files/11073880/taxonkit_linux_amd64.tar.gz
conda activate mmseqs

#############################################################################
## cluster NR with mmseqs2
#############################################################################

# download NCBI nr protein BLAST database
wget https://ftp.ncbi.nlm.nih.gov/blast/db/v5/FASTA/nr.gz # run on 03/13/2023 with db last updated 2023-03-11 21:09
# cluster with mmseqs linclust 90% length and 90% identity
time mmseqs easy-linclust nr.gz nr tmp_mmseqs2 --min-seq-id 0.9 -c 0.9 --similarity-type 2 --cov-mode 1 --threads 63
# gzip the output
gzip *fasta

# mmseqs outputs 3 files:
# nr_cluster.tsv: a TSV file documenting cluster membership. There's one line per input protein sequence.
# nr_all_seqs.fasta.gz: I'm not actually sure what's in this file
# nr_rep_seq.fasta.gz: Representative protein sequences.

################################################################################
## Build the taxonomy file with rep prot ID: LCA (taxid, name) for each cluster
###############################################################################

# get the protein:taxid file from ncbi
wget https://ftp.ncbi.nih.gov/pub/taxonomy/accession2taxid/prot.accession2taxid.gz
gunzip prot.accession2taxid.gz
# add a header to the mmseqs output file
csvtk add-header -t -n rep,accession.version -o nr_cluster_header.tsv nr_cluster.tsv
# add taxid information for each protein sequence by joining to the prot.accession2taxid file
# this step succeeded with 512gb of ram in ~1.5 hours (r5a.16xlarge)
csvtk join --left-join -f "accession.version" -t -o nr_cluster_join.tsv nr_cluster_header.tsv prot.accession2taxid
# download taxid -> lineage file. required for taxonkit
wget https://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump.tar.gz
tar xf taxdump.tar.gz
# get the size of each cluster by counting the frequency of each rep sequence
# this is used to filter into two separate files, one with > 1 members per cluster (g1) and one with == 1 (eq1) members per cluster
csvtk freq -f rep nr_cluster_join.tsv -t -o nr_cluster_join_freq.tsv
# join the frequency information back to the original set of results
csvtk join --left-join -f "rep" -t -o nr_cluster_join_freq_join.tsv nr_cluster_join.tsv nr_cluster_join_freq.tsv
# filter to those that have more than 1 member in their cluster
csvtk filter -f "frequency>1" -t -o nr_cluster_join_freq_join_g1.tsv nr_cluster_join_freq_join.tsv 
# filter to those that only have 1
csvtk filter -f "frequency=1" -t -o nr_cluster_join_freq_join_eq1.tsv nr_cluster_join_freq_join.tsv
# reformat so that it can be joined up wtih the g1 set when g1 is done being processed
csvtk cut -f 1,4 -t nr_cluster_join_freq_join_eq1.tsv | csvtk mutate -f taxid -n lca_taxid -t -o nr_cluster_join_freq_join_eq1_formatted.tsv
# collapse the taxids for each cluster into a single row in the g1 file
csvtk fold -f "rep" -v taxid -s ";" -t -o nr_cluster_join_freq_join_g1_fold.tsv  nr_cluster_join_freq_join_g1.tsv
# for clusters with multiple members, get the LCA taxonid
./taxonkit lca --data-dir . -i 2 -s ";" -o nr_cluster_join_freq_join_g1_fold_lca.tsv nr_cluster_join_freq_join_g1_fold.tsv --buffer-size 1G
# combined with taxid info for clusters with only one member
cat nr_cluster_join_freq_join_eq1_formatted.tsv nr_cluster_join_freq_join_g1_fold_lca.tsv > nr_cluster_lca.tsv
# reformat the LCA taxonid into a named lineage
taxonkit reformat -I 3 -f "{{k}};{{p}};{{c}};{{o}};{{f}};{{g}};{{s}};{{t}}" -F --data-dir . -t -o nr_cluster_lca_formatted.tsv nr_cluster_lca.tsv 
# compress the output file
gzip nr_cluster_lca_formatted.tsv
