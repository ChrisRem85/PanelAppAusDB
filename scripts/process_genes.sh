#!/bin/bash

# PanelApp Australia Gene Processing Script (Bash)
# This script processes downloaded gene JSON files and extracts specific fields to TSV format
# Processes all panels found in the data/panels directory

set -euo pipefail

# Default values
DATA_PATH="../data"
PANEL_ID=""
VERBOSE=false
FORCE=false

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
    echo "PanelApp Australia Gene Processing Script"
    echo ""
    echo "DESCRIPTION:"
    echo "    This script processes downloaded gene JSON files and extracts specific fields to TSV format."
    echo "    Only processes panels that need processing based on version timestamps."
    echo ""
    echo "USAGE:"
    echo "    $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "    --data-path PATH    Path to data directory (default: ../data)"
    echo "    --panel-id ID       Process only the specified panel ID (default: process all panels)"
    echo "    --verbose           Enable verbose logging"
    echo "    --force             Force processing even if files are up to date"
    echo "    --help              Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "    $0                          # Process all panels with incremental logic"
    echo "    $0 --panel-id 6             # Process only panel 6"
    echo "    $0 --force                  # Force process all panels"
    echo "    $0 --data-path \"/path/data\" # Custom data path"
    echo "    $0 --verbose                # Verbose logging"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --data-path)
            DATA_PATH="$2"
            shift 2
            ;;
        --panel-id)
            PANEL_ID="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --force)
            FORCE=true
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
    local panel_id="$1"
    local directories=()
    
    if [[ -n "$panel_id" ]]; then
        # Return specific panel directory if it exists
        local panel_dir="$DATA_PATH/Panel$panel_id"
        if [[ -d "$panel_dir" ]]; then
            directories=("$panel_dir")
        fi
    else
        # Return all panel directories
        for dir in "$DATA_PATH"/Panel*/; do
            if [[ -d "$dir" ]]; then
                directories+=("${dir%/}")  # Remove trailing slash
            fi
        done
    fi
    
    printf '%s\n' "${directories[@]}"
}

# Check if a panel needs processing
test_panel_needs_processing() {
    local panel_id="$1"
    local panel_path="$2"
    local genes_path="$panel_path/genes"
    local version_processed_path="$genes_path/version_processed.txt"
    local version_created_path="$panel_path/version_created.txt"
    local version_extracted_path="$panel_path/version_extracted.txt"
    local genes_tsv_path="$genes_path/genes.tsv"
    
    log_message "Checking if panel $panel_id needs processing..." "INFO"
    
    # If force is specified, always process
    if [[ "$FORCE" == "true" ]]; then
        log_message "Force parameter specified - panel will be processed" "WARNING"
        return 0
    fi
    
    # If genes.tsv doesn't exist, processing is needed
    if [[ ! -f "$genes_tsv_path" ]]; then
        log_message "Panel $panel_id needs processing: genes.tsv not found" "INFO"
        return 0
    fi
    
    # If version_processed.txt doesn't exist, processing is needed
    if [[ ! -f "$version_processed_path" ]]; then
        log_message "Panel $panel_id needs processing: version_processed.txt not found" "INFO"
        return 0
    fi
    
    # Get processed date
    local processed_date_str
    if ! processed_date_str=$(cat "$version_processed_path" 2>/dev/null | tr -d '\n\r'); then
        log_message "Panel $panel_id needs processing: Cannot read processed date" "WARNING"
        return 0
    fi
    
    # Check against version_created.txt
    if [[ -f "$version_created_path" ]]; then
        local created_date_str
        if created_date_str=$(cat "$version_created_path" 2>/dev/null | tr -d '\n\r'); then
            if [[ "$processed_date_str" < "$created_date_str" ]]; then
                log_message "Panel $panel_id needs processing: processed date ($processed_date_str) is older than created date ($created_date_str)" "INFO"
                return 0
            fi
        else
            log_message "Panel $panel_id needs processing: Cannot read created date" "WARNING"
            return 0
        fi
    fi
    
    # Check against version_extracted.txt
    if [[ -f "$version_extracted_path" ]]; then
        local extracted_date_str
        if extracted_date_str=$(cat "$version_extracted_path" 2>/dev/null | tr -d '\n\r'); then
            if [[ "$processed_date_str" < "$extracted_date_str" ]]; then
                log_message "Panel $panel_id needs processing: processed date ($processed_date_str) is older than extracted date ($extracted_date_str)" "INFO"
                return 0
            fi
        else
            log_message "Panel $panel_id needs processing: Cannot read extracted date" "WARNING"
            return 0
        fi
    fi
    
    log_message "Panel $panel_id is up to date" "SUCCESS"
    return 1
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
    echo -e "hgnc_symbol\tensembl_id\tconfidence_level\tpenetrance\tmode_of_pathogenicity\tpublications\tmode_of_inheritance\ttags" > "$temp_file"
    
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
                (.mode_of_inheritance // ""),
                (
                    if .tags and (.tags | length > 0) then
                        (.tags | join(","))
                    else
                        ""
                    end
                )
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
    local version_processed_path="$panel_path/genes/version_processed.txt"
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
    panel_dirs_output=$(get_panel_directories "$PANEL_ID") || {
        log_message "Failed to get panel directories" "ERROR"
        exit 1
    }
    
    if [[ -z "$panel_dirs_output" ]]; then
        if [[ -n "$PANEL_ID" ]]; then
            log_message "Panel $PANEL_ID not found" "ERROR"
        else
            log_message "No panel directories found" "ERROR"
        fi
        exit 1
    fi
    
    # Count panels
    local panel_count=$(echo "$panel_dirs_output" | wc -l)
    if [[ -n "$PANEL_ID" ]]; then
        log_message "Processing panel $PANEL_ID"
    else
        log_message "Found $panel_count panel directories to process"
    fi
    
    local successful=0
    local failed=0
    local skipped=0
    
    # Process each panel
    while IFS=':' read -r panel_id panel_path; do
        # Check if panel needs processing
        if ! test_panel_needs_processing "$panel_id" "$panel_path"; then
            skipped=$((skipped + 1))
            continue
        fi
        
        if [[ "$VERBOSE" == true ]]; then
            log_message "Processing panel $panel_id..."
        fi
        
        if process_panel_genes "$panel_id" "$panel_path"; then
            successful=$((successful + 1))
        else
            failed=$((failed + 1))
        fi
    done <<< "$panel_dirs_output"
    
    log_message "Gene processing completed: $successful successful, $skipped skipped, $failed failed" "SUCCESS"
    log_message "Output files saved in individual panel directories as genes/genes.tsv"
}

# Run main function
main "$@"