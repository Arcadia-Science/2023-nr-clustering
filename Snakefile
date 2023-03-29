NUMS = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13]

rule all:
    input:
        "nr_cluster_taxid_formatted_final_line_count.txt",
        "nr_cluster_taxid_formatted_final.tsv.gz",
        "nr_cluster_uniq_reps_line_count.txt"
    
# rules to add:
# 3. add header sequences to nr_cluster.tsv    

#############################################################################
## cluster NR with mmseqs2
#############################################################################

rule download_nr:
    output: "inputs/nr.gz"
    shell:'''
    wget -O {output} https://ftp.ncbi.nlm.nih.gov/blast/db/v5/FASTA/nr.gz # run on 03/13/2023 with db last updated 2023-03-11 21:09
    '''

rule cluster_nr_with_mmseqs:
    input: "inputs/nr.gz"
    output:
        "nr_cluster.tsv",
        "nr_rep_seq.fasta"
    conda: "envs/mmseqs2.yml"
    threads: 63
    shell:'''
    mmseqs easy-linclust {input} nr tmp_mmseqs2 --min-seq-id 0.9 -c 0.9 --similarity-type 2 --cov-mode 1 --threads {threads}
    '''

rule get_cluster_reps:
    input: "nr_cluster.tsv"
    output: "nr_cluster_uniq_reps.txt"
    conda: "envs/csvtk.yml"
    shell:'''
    csvtk cut -t -H -f 1 {input} | csvtk uniq -o {output}
    '''

rule count_cluster_reps:
    input: "nr_cluster_uniq_reps.txt"
    output: "nr_cluster_uniq_reps_line_count.txt"
    shell:'''
    wc -l {input} > {output}
    '''

rule add_header_to_cluster_reps:
    input: "nr_cluster.tsv"
    output: "nr_cluster_header.tsv"
    conda: "envs/csvtk.yml"
    shell:'''
    csvtk add-header -t -n rep,accession.version -o {output} {input}
    '''

################################################################################
## Build the taxonomy file with rep prot ID: LCA (taxid, name) for each cluster
###############################################################################

rule download_taxdump:
    output: "inputs/taxdump.tar.gz"
    shell:'''
    wget -O {output} https://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump.tar.gz
    '''

rule decompress_taxdump:
    input: "inputs/taxdump.tar.gz"
    output: "inputs/taxdump/nodes.dmp"
    shell:'''
    tar xf {input} -C inputs/taxdump/
    '''
        
rule download_protaccession2taxid:
    output: "inputs/prot.accession2taxid.FULL_subsets/prot.accession2taxid.FULL.{num}.gz"
    shell:'''
    wget https://ftp.ncbi.nih.gov/pub/taxonomy/accession2taxid/prot.accession2taxid.FULL.{wildcards.num}.gz
    '''
    
rule decompress_protaccession2taxid:
    input: "inputs/prot.accession2taxid.FULL_subsets/prot.accession2taxid.FULL.{num}.gz"
    output: "outputs/prot.accession2taxid.FULL_subsets/prot.accession2taxid.FULL.{num}"
    shell:'''
    gunzip -c {input} > {output}
    '''

rule join_protaccession2taxid_to_clusters:
    input: 
        taxid="outputs/prot.accession2taxid.FULL_subsets/prot.accession2taxid.FULL.{num}",
        clusters= "nr_cluster_header.tsv"
    output: "outputs/nr_cluster_taxid/nr_cluster_taxid{num}.tsv"
    conda: "envs/csvtk.yml"
    shell:'''
    csvtk join --left-join -f "accession.version" -t -o {output} {input.taxid} {input.clusters}
    '''
    
rule reformat_taxid_sheet:
    input: "outputs/nr_cluster_taxid/nr_cluster_taxid{num}.tsv"
    output: "outputs/nr_cluster_taxid_filtered/nr_cluster_taxid{num}_filtered.tsv"
    conda: "envs/csvtk.yml"
    shell:'''
    # replace blanks with NAs | filter out NAs | change order of sheet
    csvtk replace -I -t -f 3 -p "^$" -r NA {input} | csvtk grep -t -f 3 -p NA -v | csvtk cut -t -f 3,1,2 -o {output}
    '''

rule recombine_clusters:
    input: expand("outputs/nr_cluster_taxid_filtered/nr_cluster_taxid{num}_filtered.tsv", num = NUMS)
    output: "nr_cluster_taxid_filtered.tsv"
    shell:'''
    cat {input} > {output}
    '''

rule fold_cluster_accessions:
    input: "nr_cluster_taxid_filtered.tsv"
    output: "nr_cluster_taxid_folded.tsv"
    conda: "envs/csvtk.yml"
    shell:'''
    # collapse the taxids for each cluster into a single row
    csvtk fold -f "rep" -v taxid -s ";" -t -o {output} {input}
    '''

rule get_lca_taxid_for_each_cluster:
    input: 
        tsv="nr_cluster_taxid_folded.tsv",
        dmp="inputs/taxdump/nodes.dmp"
    output: "nr_cluster_taxid_lca.tsv"
    params: datadir="inputs/taxdump/"
    #conda: "envs/taxonkit.yml" # needs to be 0.14.2, which isn't on conda yet
    shell:'''
    ./taxonkit lca --data-dir {params.datadir} -i 2 -s ";" -o {output} {input.tsv} --buffer-size 1G
    '''

rule reformat_lca_taxid_to_lineage:
    input: 
        tsv="nr_cluster_taxid_lca.tsv",
        dmp="inputs/taxdump/nodes.dmp"
    output: "nr_cluster_taxid_formatted.tsv"
    params: datadir="inputs/taxdump/"
    conda: "envs/taxonkit.yml"
    shell:'''
    taxonkit reformat -I 3 -f "{{k}};{{K}};{{p}};{{c}};{{o}};{{f}};{{g}};{{s}};{{t}}" -F --data-dir {params.datadir} -t -o {output} {input.tsv}
    '''

rule add_header:
    input: "nr_cluster_taxid_formatted.tsv"
    output: "nr_cluster_taxid_formatted_final.tsv"
    conda: "envs/csvtk.yml"
    shell:'''
    csvtk add-header -t -I -H -n rep,taxid,lca_taxid,lca_lineage_named,lca_lineage_taxid -o {output} {input}
    '''

rule compress_output:
    input: "nr_cluster_taxid_formatted_final.tsv"
    output: "nr_cluster_taxid_formatted_final.tsv.gz"
    shell: '''
    gzip {input}
    '''
    
rule get_line_count:
    input: "nr_cluster_taxid_formatted_final.tsv.gz"
    output: "nr_cluster_taxid_formatted_final_line_count.txt"
    shell:'''
    gunzip -c {input} | wc -l > {output}
    '''

