#!/bin/bash

# PanelApp Australia Gene Processing Script (Bash)
# This script processes downloaded gene JSON files and extracts specific fields to TSV format
# Processes all panels found in the data/panels directory

set -euo pipefail

# Default values
DATA_PATH="../data"
VERBOSE=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_message() {
    local message="$1"
    local level="${2:-INFO}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        ERROR)
            echo -e "${BLUE}[$timestamp]${NC} ${RED}$message${NC}" >&2
            ;;
        SUCCESS)
            echo -e "${BLUE}[$timestamp]${NC} ${GREEN}$message${NC}"
            ;;
        WARNING)
            echo -e "${BLUE}[$timestamp]${NC} ${YELLOW}$message${NC}"
            ;;
        *)
            echo -e "${BLUE}[$timestamp]${NC} ${BLUE}$message${NC}"
            ;;
    esac
}

# Usage function
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Options:"
    echo "  --data-path PATH    Path to data directory (default: ../data)"
    echo "  --verbose           Enable verbose logging"
    echo "  --help              Show this help message"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --data-path)
            DATA_PATH="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Check if jq is available
if ! command -v jq &> /dev/null; then
    log_message "jq is required but not installed. Please install jq." "ERROR"
    exit 1
fi

# Get all panel directories
get_panel_directories() {
    local data_path="$1"
    local panels_path="$data_path/panels"
    
    if [[ ! -d "$panels_path" ]]; then
        log_message "Panels directory not found: $panels_path" "ERROR"
        return 1
    fi
    
    # Get only numeric directory names (panel IDs) and sort them numerically
    find "$panels_path" -maxdepth 1 -type d -name '[0-9]*' | \
    sed "s|$panels_path/||" | \
    sort -n | \
    while read -r panel_id; do
        echo "$panel_id:$panels_path/$panel_id"
    done
}

# Process genes for a single panel
process_panel_genes() {
    local panel_id="$1"
    local panel_path="$2"
    local genes_json_path="$panel_path/genes/json"
    local output_file="$panel_path/genes/genes.tsv"
    
    if [[ ! -d "$genes_json_path" ]]; then
        log_message "No genes JSON directory found for panel $panel_id" "WARNING"
        return 1
    fi
    
    # Get all JSON files in the genes directory
    local json_files=($(find "$genes_json_path" -name "*.json" | sort))
    
    if [[ ${#json_files[@]} -eq 0 ]]; then
        log_message "No JSON files found for panel $panel_id" "WARNING"
        return 1
    fi
    
    log_message "Processing ${#json_files[@]} JSON files for panel $panel_id"
    
    # Create output directory if it doesn't exist
    local output_dir=$(dirname "$output_file")
    mkdir -p "$output_dir"
    
    # Create temporary file for processing
    local temp_file=$(mktemp)
    
    # Write TSV header
    echo -e "hgnc_symbol\tensembl_id\tconfidence_level\tpenetrance\tmode_of_pathogenicity\tpublications\tmode_of_inheritance" > "$temp_file"
    
    # Process each JSON file
    local gene_count=0
    for json_file in "${json_files[@]}"; do
        if [[ ! -f "$json_file" ]]; then
            continue
        fi
        
        # Extract gene data using jq
        jq -r '
            .results[]? | 
            [
                (.gene_data.hgnc_symbol // ""),
                (
                    if .gene_data.ensembl_genes.GRch38 then
                        (.gene_data.ensembl_genes.GRch38 | to_entries[0].value.ensembl_id // "")
                    else
                        ""
                    end
                ),
                (.confidence_level // ""),
                (.penetrance // ""),
                (.mode_of_pathogenicity // ""),
                (
                    if .publications and (.publications | length > 0) then
                        (.publications | join(","))
                    else
                        ""
                    end
                ),
                (.mode_of_inheritance // "")
            ] | @tsv
        ' "$json_file" 2>/dev/null >> "$temp_file" || {
            log_message "Error processing file $(basename "$json_file")" "ERROR"
            continue
        }
        
        # Count genes processed (excluding header)
        local file_genes=$(jq -r '.results | length' "$json_file" 2>/dev/null || echo "0")
        gene_count=$((gene_count + file_genes))
    done
    
    # Check if any genes were found
    local total_lines=$(wc -l < "$temp_file")
    if [[ $total_lines -le 1 ]]; then
        log_message "No genes found for panel $panel_id" "WARNING"
        rm -f "$temp_file"
        return 1
    fi
    
    # Move temp file to final location
    mv "$temp_file" "$output_file"
    
    # Create version_processed.txt with current timestamp
    local version_processed_path="$panel_path/version_processed.txt"
    date -u '+%Y-%m-%dT%H:%M:%S.%6NZ' > "$version_processed_path"
    
    log_message "Processed $gene_count genes for panel $panel_id -> $output_file" "SUCCESS"
    return 0
}

# Main execution
main() {
    log_message "Starting PanelApp Australia gene processing..."
    
    if [[ ! -d "$DATA_PATH" ]]; then
        log_message "Data path does not exist: $DATA_PATH" "ERROR"
        exit 1
    fi
    
    # Get panel directories
    local panel_dirs_output
    panel_dirs_output=$(get_panel_directories "$DATA_PATH") || {
        log_message "Failed to get panel directories" "ERROR"
        exit 1
    }
    
    if [[ -z "$panel_dirs_output" ]]; then
        log_message "No panel directories found" "ERROR"
        exit 1
    fi
    
    # Count panels
    local panel_count=$(echo "$panel_dirs_output" | wc -l)
    log_message "Found $panel_count panel directories to process"
    
    local successful=0
    local skipped=0
    
    # Process each panel
    while IFS=':' read -r panel_id panel_path; do
        if [[ "$VERBOSE" == true ]]; then
            log_message "Processing panel $panel_id..."
        fi
        
        if process_panel_genes "$panel_id" "$panel_path"; then
            successful=$((successful + 1))
        else
            skipped=$((skipped + 1))
        fi
    done <<< "$panel_dirs_output"
    
    log_message "Gene processing completed: $successful successful, $skipped skipped" "SUCCESS"
    log_message "Output files saved in individual panel directories as genes/genes.tsv"
}

# Run main function
main "$@"