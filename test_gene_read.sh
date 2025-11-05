#!/usr/bin/bash

# Simple test to isolate the issue
cd /mnt/c/Users/cr528/Documents/VSCode/GitHub/PanelAppAusDB/PanelAppAusDB

echo "Testing gene extraction logic..."

data_folder="./data"
tsv_file="$data_folder/panel_list/panel_list.tsv"

echo "Data folder: $data_folder"
echo "TSV file: $tsv_file"

if [[ ! -d "$data_folder" ]]; then
    echo "ERROR: Data path does not exist: $data_folder"
    exit 1
fi

if [[ ! -f "$tsv_file" ]]; then
    echo "ERROR: Panel list file not found: $tsv_file"
    exit 1
fi

echo "Files exist, testing read..."

total_panels=0
while IFS=$'\t' read -r id name version version_created; do
    # Skip header line
    if [[ "$id" == "id" ]]; then
        echo "Skipping header: $id"
        continue
    fi
    
    echo "Panel: $id, Name: $name"
    ((total_panels++))
    
    if [[ $total_panels -ge 3 ]]; then
        break
    fi
done < "$tsv_file"

echo "Read $total_panels panels successfully"