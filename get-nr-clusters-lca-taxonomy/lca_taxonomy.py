import csv
import modal

CHUNK_SIZE = 100
INPUT_FILE_NAME = "test.tsv"

stub = modal.Stub("downloading-dbs-all-the-way-down")
taxonkit_image = (
    modal.Image.conda()
    .conda_install("taxonkit", "wget", channels=["conda-forge", "bioconda"])
    .run_commands(
        "wget -c ftp://ftp.ncbi.nih.gov/pub/taxonomy/taxdump.tar.gz",
        "tar -zxvf taxdump.tar.gz",
        "mkdir -p $HOME/.taxonkit",
        "mv names.dmp nodes.dmp delnodes.dmp merged.dmp $HOME/.taxonkit",
    )
)


def run_subcommand(command):
    import subprocess

    result = subprocess.run(
        " ".join(command), shell=True, capture_output=True, text=True
    )
    return result.stdout.replace("\n", "").split("\t")[-1]


@stub.function(image=taxonkit_image)
def get_lca(taxids):
    command = ["echo"] + [str(taxid) for taxid in taxids] + ["|", "taxonkit", "lca"]
    return run_subcommand(command)


@stub.function(image=taxonkit_image)
def get_lca_formatted(lca):
    command = (
        ["echo"]
        + [lca]
        + ["|", "taxonkit", 'reformat -f "{k};{p};{c};{o};{f};{g};{s};{t}" -F -I 1']
    )
    return run_subcommand(command)


@stub.function(image=taxonkit_image)
def process_row(rows):
    results = []
    for row in rows:
        taxids = list(set([x for x in row[1].split(";") if x != ""]))
        if len(taxids) == 0:
            lca = "N/A"
            lca_formatted = "N/A"
        elif len(taxids) == 1:
            lca = taxids[0]
            lca_formatted = get_lca_formatted(lca)
        else:
            lca = get_lca(taxids)
            lca_formatted = get_lca_formatted(lca)

        results.append([row[0], row[1], lca, lca_formatted])
    return results


@stub.local_entrypoint
def main():
    # Open a CSV file for writing
    with open("csv_to_rule_them_all.csv", "w", newline="") as csvfile:
        writer = csv.writer(csvfile)
        writer.writerow(
            ["representative", "cluster_taxids", "lca_taxid", "lca_taxid_formatted"]
        )

        # Open the CSV file and read the data
        with open(INPUT_FILE_NAME, "r") as tsvfile:
            reader = csv.reader(tsvfile, delimiter="\t")
            data = [row for row in reader]

        # Split the data into smaller chunks and process them in parallel
        split_data = [data[i : i + CHUNK_SIZE] for i in range(0, len(data), CHUNK_SIZE)]
        for x in process_row.map(split_data):
            for row in x:
                writer.writerow(row)
