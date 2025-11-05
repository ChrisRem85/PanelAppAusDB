#!/usr/bin/bash

# Simple test to check regex validation
cd /mnt/c/Users/cr528/Documents/VSCode/GitHub/PanelAppAusDB/PanelAppAusDB

echo "Testing regex validation..."

# Test the regex pattern
test_ids=("123" "abc" "456def" "" "789")

for id in "${test_ids[@]}"; do
    echo "Testing ID: '$id'"
    if [[ -z "$id" || ! "$id" =~ ^[0-9]+$ ]]; then
        echo "  Invalid or empty ID"
    else
        echo "  Valid ID"
    fi
done

echo "Testing file reading with validation..."
data_folder="./data"
tsv_file="$data_folder/panel_list/panel_list.tsv"

# Test first few lines
head -5 "$tsv_file" | while IFS=$'\t' read -r id name version version_created; do
    echo "Read: id='$id', name='$name'"
    
    if [[ "$id" == "id" ]]; then
        echo "  Skipping header"
        continue
    fi
    
    if [[ -z "$id" || ! "$id" =~ ^[0-9]+$ ]]; then
        echo "  Invalid panel ID: '$id'"
    else
        echo "  Valid panel ID: '$id'"
    fi
done