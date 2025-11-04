#!/bin/bash
# PanelApp Australia Somatic Gene to Genelists Converter (Bash)
# This script converts genes.tsv to somatic-specific genelist format files based on confidence levels
# Creates separate files for Green (confidence_level 3) and Amber (confidence_level 2) genes
# Only includes genes from cancer and somatic-related panels

set -euo pipefail

# Configuration
DATA_PATH="./data"
FORCE=0
VERBOSE=0

# Define somatic/cancer-related panel IDs based on panel names
SOMATIC_PANEL_IDS=(
    152   # Cancer Predisposition_Paediatric
    3181  # Vascular Malformations_Somatic
    3279  # Melanoma
    3472  # Mosaic skin disorders
    4358  # Sarcoma soft tissue
    4359  # Sarcoma non-soft tissue
    4360  # Basal Cell Cancer
    4362  # Thyroid Cancer
    4363  # Parathyroid Tumour
    4364  # Pituitary Tumour
    4366  # Wilms Tumour
    4367  # Kidney Cancer
    4368  # Diffuse Gastric Cancer
    4369  # Gastrointestinal Stromal Tumour
    4370  # Pancreatic Cancer
    4371  # Colorectal Cancer and Polyposis
    4372  # Prostate Cancer
    4373  # Endometrial Cancer
    4374  # Ovarian Cancer
    4375  # Breast Cancer
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_message() {
    local message="$1"
    local level="${2:-INFO}"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case $level in
        "ERROR")
            echo -e "[$timestamp] ${RED}$message${NC}" >&2
            ;;
        "WARNING")
            echo -e "[$timestamp] ${YELLOW}$message${NC}"
            ;;
        "SUCCESS")
            echo -e "[$timestamp] ${GREEN}$message${NC}"
            ;;
        *)
            echo -e "[$timestamp] ${CYAN}$message${NC}"
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
    create_Somatic_genelists.sh [OPTIONS]

DESCRIPTION:
    Creates somatic-specific genelist files from consolidated genes.tsv based on confidence levels.
    Only includes genes from cancer and somatic-related panels.
    
    Generates three output files:
    - genes_to_genelists.PanelAppAustralia_Somatic_Green.txt (confidence_level = 3)
    - genes_to_genelists.PanelAppAustralia_Somatic_Amber.txt (confidence_level = 2)
    - genelist.PanelAppAustralia_Somatic_GreenAmber.txt (all ensembl_ids, unique, no headers)
    
    Output format: 
    - Green/Amber files: ensembl_id [TAB] panel_id_confidence
    - Simple genelist: ensembl_id only (one per line, sorted, unique)

OPTIONS:
    --data-path <path>  Path to data directory (default: ./data)
    --force             Force overwrite existing files
    --verbose           Enable verbose output
    --help              Show this help message

EXAMPLES:
    ./create_Somatic_genelists.sh
    ./create_Somatic_genelists.sh --data-path "/path/to/data" --verbose
    ./create_Somatic_genelists.sh --force

SOMATIC PANELS INCLUDED:
    Cancer Predisposition_Paediatric (152), Vascular Malformations_Somatic (3181),
    Melanoma (3279), Sarcoma soft tissue (4358), Sarcoma non-soft tissue (4359),
    Basal Cell Cancer (4360), Thyroid Cancer (4362), Parathyroid Tumour (4363),
    Pituitary Tumour (4364), Wilms Tumour (4366), Kidney Cancer (4367),
    Diffuse Gastric Cancer (4368), Gastrointestinal Stromal Tumour (4369),
    Pancreatic Cancer (4370), Colorectal Cancer and Polyposis (4371),
    Prostate Cancer (4372), Endometrial Cancer (4373), Ovarian Cancer (4374),
    Breast Cancer (4375)

OUTPUT:
    Creates genelist files in data/genelists/ directory with version tracking.

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

# Helper function to validate file paths
test_data_path() {
    local data_path="$1"
    
    if [[ ! -d "$data_path" ]]; then
        log_message "Data path does not exist: $data_path" "ERROR"
        return 1
    fi
    
    local genes_path="$data_path/genes"
    if [[ ! -d "$genes_path" ]]; then
        log_message "Genes directory not found: $genes_path" "ERROR"
        log_message "Please run the merge_panels script first to create consolidated gene data" "ERROR"
        return 1
    fi
    
    return 0
}

# Check if a panel ID is in the somatic panels list
is_somatic_panel() {
    local panel_id="$1"
    local id
    
    for id in "${SOMATIC_PANEL_IDS[@]}"; do
        if [[ "$id" == "$panel_id" ]]; then
            return 0
        fi
    done
    return 1
}

# Check if processing is needed
test_processing_needed() {
    local data_path="$1"
    local force="$2"
    
    local output_dir="$data_path/genelists"
    local version_file="$output_dir/version_somatic_genelists.txt"
    local genes_file="$data_path/genes/genes.tsv"
    local genes_version_file="$data_path/genes/version_merged.txt"
    
    # If force is specified, always process
    if [[ $force -eq 1 ]]; then
        log_verbose "Force parameter specified - processing will run"
        return 0
    fi
    
    # If output directory doesn't exist, processing is needed
    if [[ ! -d "$output_dir" ]]; then
        log_verbose "Output directory doesn't exist - processing needed"
        return 0
    fi
    
    # If version file doesn't exist, processing is needed
    if [[ ! -f "$version_file" ]]; then
        log_verbose "Version file doesn't exist - processing needed"
        return 0
    fi
    
    # If genes file doesn't exist, cannot process
    if [[ ! -f "$genes_file" ]]; then
        log_message "Source genes.tsv file not found: $genes_file" "ERROR"
        log_message "Please run the merge_panels script first" "ERROR"
        return 1
    fi
    
    # Compare timestamps if both version files exist
    if [[ -f "$genes_version_file" && -f "$version_file" ]]; then
        if [[ "$genes_version_file" -nt "$version_file" ]]; then
            log_verbose "Genes data is newer than genelists - processing needed"
            return 0
        else
            log_message "Somatic genelist files are up to date"
            return 1
        fi
    fi
    
    return 0
}

# Validate output files have content
test_output_files() {
    local output_dir="$1"
    
    local green_file="$output_dir/genes_to_genelists.PanelAppAustralia_Somatic_Green.txt"
    local amber_file="$output_dir/genes_to_genelists.PanelAppAustralia_Somatic_Amber.txt"
    local simple_file="$output_dir/genelist.PanelAppAustralia_Somatic_GreenAmber.txt"
    
    local files_valid=1
    
    # Check each file exists and has content
    for file in "$green_file" "$amber_file" "$simple_file"; do
        if [[ ! -f "$file" ]]; then
            log_message "Output file not created: $file" "ERROR"
            files_valid=0
        else
            local line_count
            line_count=$(wc -l < "$file" 2>/dev/null || echo "0")
            if [[ $line_count -eq 0 ]]; then
                log_message "Output file is empty: $file" "ERROR"
                files_valid=0
            else
                log_verbose "Output file validated: $file ($line_count lines)"
            fi
        fi
    done
    
    return $files_valid
}

# Process genes.tsv and create somatic genelist files
create_somatic_genelist_files() {
    local genes_file="$1"
    local output_dir="$2"
    local version_file="$3"
    
    log_message "Reading genes data from: $genes_file"
    
    # Check if input file exists and is readable
    if [[ ! -f "$genes_file" ]]; then
        log_message "Genes file not found: $genes_file" "ERROR"
        return 1
    fi
    
    # Get column positions (assuming tab-separated with header)
    local header
    header=$(head -n1 "$genes_file")
    
    # Define column positions based on known structure
    # From merge_panels output: panel_id, hgnc_symbol, ensembl_id, confidence_level, ...
    local panel_col=1
    local ensembl_col=3
    local confidence_col=4
    
    log_verbose "Using columns: panel_id=$panel_col, ensembl_id=$ensembl_col, confidence_level=$confidence_col"
    
    # Check if we have data
    local total_lines
    total_lines=$(wc -l < "$genes_file")
    total_lines=$((total_lines - 1))  # Subtract header
    
    if [[ $total_lines -eq 0 ]]; then
        log_message "No gene data found in $genes_file" "WARNING"
        return 1
    fi
    
    log_message "Loaded $total_lines total genes from merged data"
    
    # Create output directory
    mkdir -p "$output_dir"
    log_verbose "Created output directory: $output_dir"
    
    # Process data and filter for somatic panels
    local temp_somatic="/tmp/somatic_genes.$$"
    local temp_green="/tmp/green_genes.$$"
    local temp_amber="/tmp/amber_genes.$$"
    
    # Filter for somatic panels only (skip header, then filter)
    {
        local somatic_count=0
        while IFS=$'\t' read -r panel_id hgnc_symbol ensembl_id confidence_level rest; do
            if is_somatic_panel "$panel_id"; then
                echo -e "$panel_id\t$hgnc_symbol\t$ensembl_id\t$confidence_level\t$rest"
                ((somatic_count++))
            fi
        done < <(tail -n +2 "$genes_file")
        
        log_message "Found $somatic_count genes in somatic panels"
        echo "$somatic_count" > "${temp_somatic}.count"
    } > "$temp_somatic"
    
    local somatic_count
    somatic_count=$(cat "${temp_somatic}.count")
    
    if [[ $somatic_count -eq 0 ]]; then
        log_message "No genes found in somatic panels" "WARNING"
        rm -f "$temp_somatic" "${temp_somatic}.count"
        return 1
    fi
    
    # Filter by confidence levels
    awk -F'\t' '$4 == "3" {print $3 "\t" $1 "_3"}' "$temp_somatic" > "$temp_green"
    awk -F'\t' '$4 == "2" {print $3 "\t" $1 "_2"}' "$temp_somatic" > "$temp_amber"
    
    local green_count amber_count
    green_count=$(wc -l < "$temp_green")
    amber_count=$(wc -l < "$temp_amber")
    
    log_message "Green genes (confidence 3): $green_count"
    log_message "Amber genes (confidence 2): $amber_count"
    
    # Generate Green genelist
    local green_file="$output_dir/genes_to_genelists.PanelAppAustralia_Somatic_Green.txt"
    if [[ $green_count -gt 0 ]]; then
        cp "$temp_green" "$green_file"
        log_message "Created Green genelist: $green_file ($green_count genes)" "SUCCESS"
    else
        touch "$green_file"
        log_message "Created empty Green genelist: $green_file (no confidence level 3 genes)" "WARNING"
    fi
    
    # Generate Amber genelist
    local amber_file="$output_dir/genes_to_genelists.PanelAppAustralia_Somatic_Amber.txt"
    if [[ $amber_count -gt 0 ]]; then
        cp "$temp_amber" "$amber_file"
        log_message "Created Amber genelist: $amber_file ($amber_count genes)" "SUCCESS"
    else
        touch "$amber_file"
        log_message "Created empty Amber genelist: $amber_file (no confidence level 2 genes)" "WARNING"
    fi
    
    # Generate simple genelist (unique Ensembl IDs only, sorted)
    local simple_file="$output_dir/genelist.PanelAppAustralia_Somatic_GreenAmber.txt"
    local unique_count=0
    
    if [[ $green_count -gt 0 || $amber_count -gt 0 ]]; then
        # Combine both files, extract first column (ensembl_id), sort and make unique
        {
            cut -f1 "$temp_green" 2>/dev/null || true
            cut -f1 "$temp_amber" 2>/dev/null || true
        } | sort | uniq > "$simple_file"
        
        unique_count=$(wc -l < "$simple_file")
        log_message "Created simple genelist: $simple_file ($unique_count unique genes)" "SUCCESS"
    else
        touch "$simple_file"
        log_message "Created empty simple genelist: $simple_file (no genes found)" "WARNING"
    fi
    
    # Update version tracking
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    cat > "$version_file" << EOF
Somatic genelist creation completed: $timestamp
Source file: $genes_file
Green genes (confidence 3): $green_count
Amber genes (confidence 2): $amber_count
Total unique genes: $unique_count
Somatic panels processed: ${#SOMATIC_PANEL_IDS[@]}
EOF
    
    log_verbose "Updated version tracking: $version_file"
    
    # Clean up temporary files
    rm -f "$temp_somatic" "${temp_somatic}.count" "$temp_green" "$temp_amber"
    
    return 0
}

# Main execution function
main() {
    log_message "Somatic genelist creation starting..."
    log_verbose "Data path: $DATA_PATH"
    log_verbose "Somatic panels: ${SOMATIC_PANEL_IDS[*]}"
    
    # Validate data path
    if ! test_data_path "$DATA_PATH"; then
        return 1
    fi
    
    # Check if processing is needed
    if ! test_processing_needed "$DATA_PATH" "$FORCE"; then
        return 0
    fi
    
    # Set up paths
    local genes_file="$DATA_PATH/genes/genes.tsv"
    local output_dir="$DATA_PATH/genelists"
    local version_file="$output_dir/version_somatic_genelists.txt"
    
    # Create somatic genelist files
    if ! create_somatic_genelist_files "$genes_file" "$output_dir" "$version_file"; then
        log_message "Failed to create somatic genelist files" "ERROR"
        return 1
    fi
    
    # Validate output files
    if ! test_output_files "$output_dir"; then
        log_message "Output file validation failed" "ERROR"
        return 1
    fi
    
    log_message "Somatic genelist creation completed successfully!" "SUCCESS"
    log_message "Output directory: $output_dir"
    
    return 0
}

# Parse arguments and run main function
parse_args "$@"

# Check if jq is available (not strictly needed for this script, but good practice)
if ! command -v awk &> /dev/null; then
    log_message "awk command not found. Please install awk." "ERROR"
    exit 1
fi

# Run main function
if ! main; then
    exit 1
fi