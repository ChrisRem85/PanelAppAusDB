#!/bin/bash
# PanelApp Australia Panel Data Merger (Bash)
# This script merges all panel data into consolidated files with panel_id columns
# It processes genes.tsv, strs.tsv, and regions.tsv files from individual panels

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_PATH="./data"
ENTITY_TYPE=""
FORCE=0
VERBOSE=0

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
    
    case "$level" in
        "ERROR")
            echo -e "${BLUE}[$timestamp]${NC} ${RED}$message${NC}" >&2
            ;;
        "SUCCESS")
            echo -e "${BLUE}[$timestamp]${NC} ${GREEN}$message${NC}"
            ;;
        "WARNING")
            echo -e "${BLUE}[$timestamp]${NC} ${YELLOW}$message${NC}"
            ;;
        *)
            echo -e "${BLUE}[$timestamp]${NC} ${BLUE}$message${NC}"
            ;;
    esac
}

log_verbose() {
    if [[ $VERBOSE -eq 1 ]]; then
        log_message "$1" "INFO"
    fi
}

# Show usage information
show_usage() {
    cat << EOF
PanelApp Australia Panel Data Merger

DESCRIPTION:
    This script merges panel data files (genes.tsv, strs.tsv, regions.tsv) from individual panels
    into consolidated files with an additional panel_id column.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --data-path PATH      Path to data directory (default: ./data)
    --entity-type TYPE    Merge only specific entity type: genes, strs, or regions (default: all)
    --force               Force re-merge even if up to date
    --verbose             Enable verbose logging
    --help                Show this help message

EXAMPLES:
    $0                                      # Merge all entity types
    $0 --entity-type genes                  # Merge only genes
    $0 --force                              # Force re-merge all
    $0 --data-path "/path/to/data"          # Custom data path
    $0 --verbose                            # Verbose logging

OUTPUT:
    Creates merged files in:
    - data/genes/genes.tsv
    - data/strs/strs.tsv (future)
    - data/regions/regions.tsv (future)
    
    With version tracking files:
    - data/genes/version_merged.txt
    - data/strs/version_merged.txt
    - data/regions/version_merged.txt

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --data-path)
                DATA_PATH="$2"
                shift 2
                ;;
            --entity-type)
                ENTITY_TYPE="$2"
                shift 2
                ;;
            --force)
                FORCE=1
                shift
                ;;
            --verbose)
                VERBOSE=1
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                log_message "Unknown option: $1" "ERROR"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Check if merge is needed for an entity type
merge_needed() {
    local data_path="$1"
    local entity_type="$2"
    
    log_verbose "Checking if $entity_type merge is needed..."
    
    local merged_dir="$data_path/$entity_type"
    local merged_file="$merged_dir/$entity_type.tsv"
    local version_file="$merged_dir/version_merged.txt"
    
    # If force is specified, always merge
    if [[ $FORCE -eq 1 ]]; then
        log_verbose "$entity_type merge needed: Force specified"
        return 0
    fi
    
    # If merged directory doesn't exist
    if [[ ! -d "$merged_dir" ]]; then
        log_verbose "$entity_type merge needed: Merged directory does not exist"
        return 0
    fi
    
    # If merged file doesn't exist
    if [[ ! -f "$merged_file" ]]; then
        log_verbose "$entity_type merge needed: Merged file does not exist"
        return 0
    fi
    
    # If version file doesn't exist
    if [[ ! -f "$version_file" ]]; then
        log_verbose "$entity_type merge needed: Version file does not exist"
        return 0
    fi
    
    # Get the last merged date
    if [[ ! -s "$version_file" ]]; then
        log_verbose "$entity_type merge needed: Version file is empty"
        return 0
    fi
    
    local last_merged_date
    last_merged_date=$(head -n1 "$version_file")
    
    if [[ -z "$last_merged_date" ]]; then
        log_verbose "$entity_type merge needed: Cannot read version file"
        return 0
    fi
    
    log_verbose "$entity_type last merged: $last_merged_date"
    
    # Convert to Unix timestamp for comparison
    local last_merged_timestamp
    if ! last_merged_timestamp=$(date -d "$last_merged_date" +%s 2>/dev/null); then
        log_verbose "$entity_type merge needed: Cannot parse merged date"
        return 0
    fi
    
    # Check all panel version_processed files
    local panels_dir="$data_path/panels"
    if [[ ! -d "$panels_dir" ]]; then
        log_message "Panels directory not found: $panels_dir" "WARNING"
        return 1
    fi
    
    # Find panel directories (numeric names only)
    local panel_dir
    for panel_dir in "$panels_dir"/*/; do
        if [[ ! -d "$panel_dir" ]]; then
            continue
        fi
        
        local panel_id
        panel_id=$(basename "$panel_dir")
        
        # Check if panel_id is numeric
        if ! [[ "$panel_id" =~ ^[0-9]+$ ]]; then
            continue
        fi
        
        local processed_file="$panel_dir/$entity_type/version_processed.txt"
        
        if [[ -f "$processed_file" && -s "$processed_file" ]]; then
            local processed_date
            processed_date=$(head -n1 "$processed_file")
            
            if [[ -n "$processed_date" ]]; then
                local processed_timestamp
                if processed_timestamp=$(date -d "$processed_date" +%s 2>/dev/null); then
                    if [[ $processed_timestamp -gt $last_merged_timestamp ]]; then
                        log_verbose "$entity_type merge needed: Panel $panel_id processed date ($processed_date) is newer than merged date ($last_merged_date)"
                        return 0
                    fi
                else
                    log_verbose "$entity_type merge needed: Cannot parse processed date for panel $panel_id"
                    return 0
                fi
            fi
        fi
    done
    
    log_verbose "$entity_type is up to date"
    return 1
}

# Merge entity type data
merge_entity_data() {
    local data_path="$1"
    local entity_type="$2"
    
    log_message "Merging $entity_type data..."
    
    local panels_dir="$data_path/panels"
    local merged_dir="$data_path/$entity_type"
    local merged_file="$merged_dir/$entity_type.tsv"
    local version_file="$merged_dir/version_merged.txt"
    
    # Create merged directory if it doesn't exist
    if [[ ! -d "$merged_dir" ]]; then
        mkdir -p "$merged_dir"
        log_verbose "Created directory: $merged_dir"
    fi
    
    # Find all panel directories
    local panel_dirs=()
    local panel_dir
    for panel_dir in "$panels_dir"/*/; do
        if [[ ! -d "$panel_dir" ]]; then
            continue
        fi
        
        local panel_id
        panel_id=$(basename "$panel_dir")
        
        # Check if panel_id is numeric
        if [[ "$panel_id" =~ ^[0-9]+$ ]]; then
            panel_dirs+=("$panel_dir")
        fi
    done
    
    if [[ ${#panel_dirs[@]} -eq 0 ]]; then
        log_message "No panel directories found in $panels_dir" "WARNING"
        return 1
    fi
    
    log_verbose "Found ${#panel_dirs[@]} panel directories"
    
    # Collect all TSV files
    local tsv_files=()
    local panel_ids=()
    
    for panel_dir in "${panel_dirs[@]}"; do
        local panel_id
        panel_id=$(basename "$panel_dir")
        local tsv_path="$panel_dir/$entity_type/$entity_type.tsv"
        
        if [[ -f "$tsv_path" ]]; then
            tsv_files+=("$tsv_path")
            panel_ids+=("$panel_id")
            log_verbose "Found $entity_type file for panel $panel_id"
        else
            log_verbose "No $entity_type file found for panel $panel_id"
        fi
    done
    
    if [[ ${#tsv_files[@]} -eq 0 ]]; then
        log_message "No $entity_type.tsv files found in any panel directory" "WARNING"
        return 1
    fi
    
    log_message "Found ${#tsv_files[@]} $entity_type files to merge"
    
    # Create temporary file
    local temp_file
    temp_file=$(mktemp)
    
    # Process and merge files
    local header_written=0
    local row_count=0
    local total_input_rows=0
    
    for i in "${!tsv_files[@]}"; do
        local panel_id="${panel_ids[$i]}"
        local file_path="${tsv_files[$i]}"
        
        log_verbose "Processing panel $panel_id file: $file_path"
        
        if [[ ! -s "$file_path" ]]; then
            log_message "Empty file: $file_path" "WARNING"
            continue
        fi
        
        # Process file line by line
        local line_number=0
        local panel_row_count=0
        while IFS= read -r line; do
            line_number=$((line_number + 1))
            
            # Handle header
            if [[ $line_number -eq 1 ]]; then
                if [[ $header_written -eq 0 ]]; then
                    echo -e "panel_id\t$line" >> "$temp_file"
                    header_written=1
                    log_verbose "Header: panel_id	$line"
                fi
            else
                # Handle data rows
                if [[ -n "${line// }" ]]; then  # Check if line is not empty or just whitespace
                    echo -e "$panel_id\t$line" >> "$temp_file"
                    row_count=$((row_count + 1))
                    panel_row_count=$((panel_row_count + 1))
                fi
            fi
        done < "$file_path"
        
        total_input_rows=$((total_input_rows + panel_row_count))
        log_verbose "Added $panel_row_count rows from panel $panel_id"
    done
    
    if [[ $row_count -eq 0 ]]; then
        log_message "No data rows found to merge" "WARNING"
        rm -f "$temp_file"
        return 1
    fi
    
    # Move temporary file to final location
    if mv "$temp_file" "$merged_file"; then
        log_message "Created merged file: $merged_file with $row_count data rows" "SUCCESS"
    else
        log_message "Error writing merged file $merged_file" "ERROR"
        rm -f "$temp_file"
        return 1
    fi
    
    # Validate merged output
    log_verbose "Validating merged output: expected $total_input_rows rows, actual $row_count rows"
    if [[ "$row_count" -eq "$total_input_rows" ]]; then
        log_message "✓ Validation passed: Merged file contains expected $row_count rows" "SUCCESS"
    else
        log_message "✗ Validation failed: Expected $total_input_rows rows, but merged file contains $row_count rows" "ERROR"
        log_message "Row count mismatch indicates data loss or corruption during merge" "ERROR"
        return 1
    fi
    
    # Create version file
    local current_date
    current_date=$(date '+%Y-%m-%d %H:%M:%S')
    
    if echo "$current_date" > "$version_file"; then
        log_message "Created version file: $version_file" "SUCCESS"
    else
        log_message "Error writing version file $version_file" "ERROR"
        return 1
    fi
    
    return 0
}

# Main execution function
main() {
    log_message "Starting PanelApp Australia panel data merger..."
    
    # Validate data path
    if [[ ! -d "$DATA_PATH" ]]; then
        log_message "Data path not found: $DATA_PATH" "ERROR"
        exit 1
    fi
    
    DATA_PATH=$(realpath "$DATA_PATH")
    log_message "Using data path: $DATA_PATH"
    
    # Define entity types to process
    local entity_types
    if [[ -n "$ENTITY_TYPE" ]]; then
        entity_types=("$ENTITY_TYPE")
    else
        entity_types=("genes" "strs" "regions")
    fi
    
    local success=1
    
    for entity_type in "${entity_types[@]}"; do
        # For now, only process genes (strs and regions are future implementation)
        if [[ "$entity_type" != "genes" ]]; then
            log_message "Skipping $entity_type (future implementation)"
            continue
        fi
        
        if merge_needed "$DATA_PATH" "$entity_type"; then
            if ! merge_entity_data "$DATA_PATH" "$entity_type"; then
                log_message "$entity_type merge failed" "WARNING"
                success=0
            fi
        else
            log_message "$entity_type data is up to date"
        fi
    done
    
    if [[ $success -eq 1 ]]; then
        log_message "Panel data merger completed successfully!" "SUCCESS"
    else
        log_message "Panel data merger completed with some warnings/errors" "WARNING"
    fi
}

# Parse arguments and run main function
parse_args "$@"

# Run main function
main