library(RSQLite)

db <- dbConnect(SQLite(), dbname = snakemake@output[['sqlite']]) 
dbWriteTable(conn = db, name = "nr_cluster_taxid_table", value = snakemake@input[['tsv']], sep="\t")
dbDisconnect(db)
