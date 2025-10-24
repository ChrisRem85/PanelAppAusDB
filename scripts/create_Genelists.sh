#!/bin/bash
# PanelApp Australia Gene to Genelists Converter (Bash)
# This script converts genes.tsv to genelist format files based on confidence levels
# Creates separate files for Green (confidence_level 3) and Amber (confidence_level 2) genes

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_PATH="./data"
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
    cat << 'EOF'
USAGE:
    create_Genelists.sh [OPTIONS]

DESCRIPTION:
    Creates genelist files from consolidated genes.tsv based on confidence levels.
    
    Generates two output files:
    - genes_to_genelists.PanelAppAustralia_Green.txt (confidence_level = 3)
    - genes_to_genelists.PanelAppAustralia_Amber.txt (confidence_level = 2)
    
    Output format: ensembl_id<tab>Paus:[panel_id].[Green|Amber]
    Files are sorted by ensembl_id, then by panel_id.

OPTIONS:
    --data-path <path>  Path to data directory (default: ./data)
    --force             Force regeneration even if files are up to date
    --verbose           Enable verbose output
    --help              Show this help message

EXAMPLES:
    ./create_Genelists.sh
    ./create_Genelists.sh --data-path "/path/to/data" --verbose
    ./create_Genelists.sh --force --verbose

REQUIREMENTS:
    - Consolidated genes.tsv file in data/genes/genes.tsv
    - genes.tsv must contain: ensembl_id, confidence_level, panel_id columns
    - awk command available

OUTPUT:
    - data/genelists/genes_to_genelists.PanelAppAustralia_Green.txt
    - data/genelists/genes_to_genelists.PanelAppAustralia_Amber.txt

EOF
}

# Check if regeneration is needed
check_regeneration_needed() {
    local input_file="$1"
    local output_file1="$2"
    local output_file2="$3"
    
    if [[ $FORCE -eq 1 ]]; then
        log_verbose "Force flag specified, regenerating files"
        return 0
    fi
    
    if [[ ! -f "$input_file" ]]; then
        log_message "Input file not found: $input_file" "ERROR"
        return 1
    fi
    
    local input_time
    input_time=$(stat -c %Y "$input_file" 2>/dev/null || stat -f %m "$input_file" 2>/dev/null || echo 0)
    
    for output_file in "$output_file1" "$output_file2"; do
        if [[ ! -f "$output_file" ]]; then
            log_verbose "Output file missing: $(basename "$output_file")"
            return 0
        fi
        
        local output_time
        output_time=$(stat -c %Y "$output_file" 2>/dev/null || stat -f %m "$output_file" 2>/dev/null || echo 0)
        
        if [[ $input_time -gt $output_time ]]; then
            log_verbose "Input file is newer than output file: $(basename "$output_file")"
            return 0
        fi
    done
    
    return 1
}

# Process genes.tsv and create genelist files
create_genelist_files() {
    local genes_file="$1"
    local output_dir="$2"
    
    log_message "Reading genes data from: $genes_file"
    
    # Check if input file exists and is readable
    if [[ ! -f "$genes_file" ]]; then
        log_message "Genes file not found: $genes_file" "ERROR"
        return 1
    fi
    
    # Get column positions (assuming tab-separated with header)
    local header
    header=$(head -n1 "$genes_file")
    
    # Find column indices (1-based for awk)
    local ensembl_col panel_col confidence_col
    ensembl_col=$(echo "$header" | awk -F'\t' '{for(i=1;i<=NF;i++) if($i=="ensembl_id") print i}')
    panel_col=$(echo "$header" | awk -F'\t' '{for(i=1;i<=NF;i++) if($i=="panel_id") print i}')
    confidence_col=$(echo "$header" | awk -F'\t' '{for(i=1;i<=NF;i++) if($i=="confidence_level") print i}')
    
    if [[ -z "$ensembl_col" || -z "$panel_col" || -z "$confidence_col" ]]; then
        log_message "Required columns not found in genes.tsv. Need: ensembl_id, panel_id, confidence_level" "ERROR"
        return 1
    fi
    
    log_verbose "Column positions - ensembl_id: $ensembl_col, panel_id: $panel_col, confidence_level: $confidence_col"
    
    # Count total genes
    local total_genes
    total_genes=$(tail -n +2 "$genes_file" | wc -l)
    log_message "Loaded $total_genes gene entries"
    
    # Create output directory if it doesn't exist
    mkdir -p "$output_dir"
    log_verbose "Ensured output directory exists: $output_dir"
    
    # Define output files
    local green_file="$output_dir/genes_to_genelists.PanelAppAustralia_Green.txt"
    local amber_file="$output_dir/genes_to_genelists.PanelAppAustralia_Amber.txt"
    
    # Process Green genes (confidence_level = 3)
    log_verbose "Processing Green genes (confidence_level = 3)"
    awk -F'\t' -v ensembl_col="$ensembl_col" -v panel_col="$panel_col" -v confidence_col="$confidence_col" '
        NR > 1 && $confidence_col == "3" && $ensembl_col != "" {
            print $ensembl_col "\t" "Paus:" $panel_col ".Green"
        }
    ' "$genes_file" | sort -t$'\t' -k1,1 -k2,2 > "$green_file"
    
    local green_count
    green_count=$(wc -l < "$green_file")
    log_message "Green genes (confidence_level 3): $green_count entries" "SUCCESS"
    
    # Process Amber genes (confidence_level = 2)
    log_verbose "Processing Amber genes (confidence_level = 2)"
    awk -F'\t' -v ensembl_col="$ensembl_col" -v panel_col="$panel_col" -v confidence_col="$confidence_col" '
        NR > 1 && $confidence_col == "2" && $ensembl_col != "" {
            print $ensembl_col "\t" "Paus:" $panel_col ".Amber"
        }
    ' "$genes_file" | sort -t$'\t' -k1,1 -k2,2 > "$amber_file"
    
    local amber_count
    amber_count=$(wc -l < "$amber_file")
    log_message "Amber genes (confidence_level 2): $amber_count entries" "SUCCESS"
    
    log_message "Created Green genelist: $green_file ($green_count entries)" "SUCCESS"
    log_message "Created Amber genelist: $amber_file ($amber_count entries)" "SUCCESS"
    
    return 0
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --data-path)
                DATA_PATH="$2"
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
            --help)
                show_usage
                exit 0
                ;;
            *)
                echo "Unknown option: $1" >&2
                show_usage >&2
                exit 1
                ;;
        esac
    done
}

# Main execution
main() {
    parse_arguments "$@"
    
    log_message "PanelApp Australia Gene to Genelists Converter starting..."
    
    # Validate data path
    if [[ ! -d "$DATA_PATH" ]]; then
        log_message "Data directory not found: $DATA_PATH" "ERROR"
        return 1
    fi
    
    # Define paths
    local genes_file="$DATA_PATH/genes/genes.tsv"
    local output_dir="$DATA_PATH/genelists"
    local green_file="$output_dir/genes_to_genelists.PanelAppAustralia_Green.txt"
    local amber_file="$output_dir/genes_to_genelists.PanelAppAustralia_Amber.txt"
    
    # Check if regeneration is needed
    if ! check_regeneration_needed "$genes_file" "$green_file" "$amber_file"; then
        log_message "Genelist files are up to date, skipping regeneration"
        log_message "Use --force to regenerate anyway"
        return 0
    fi
    
    # Process genes and create genelist files
    if create_genelist_files "$genes_file" "$output_dir"; then
        log_message "Gene to genelists conversion completed successfully" "SUCCESS"
        log_message "Output directory: $output_dir"
        return 0
    else
        log_message "Gene to genelists conversion failed" "ERROR"
        return 1
    fi
}

# Run main function with all arguments
main "$@"