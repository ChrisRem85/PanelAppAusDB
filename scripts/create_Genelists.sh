#!/bin/bash
# PanelApp Australia Gene to Genelists Converter (Bash)
# This script converts genes.tsv to genelist format files based on confidence levels
# Creates separate files for Green (confidence_level 3) and Amber (confidence_level 2) genes
# All output files use Unix newlines (LF) for cross-platform compatibility

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
    
    Generates three output files:
    - genes_to_genelists.PanelAppAustralia_Green.txt (confidence_level = 3)
    - genes_to_genelists.PanelAppAustralia_Amber.txt (confidence_level = 2)
    - genelist.PanelAppAustralia_GreenAmber.txt (all ensembl_ids, unique, no headers)
    
    Output format: 
    - Green/Amber files: ensembl_id<tab>Paus:[panel_id].[Green|Amber]
    - Simple genelist: ensembl_id only (one per line, sorted, unique)
    Files are sorted by ensembl_id, then by panel_id.
    All files use Unix newlines (LF) for cross-platform compatibility.

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
    - data/genelists/genelist.PanelAppAustralia_GreenAmber.txt

EOF
}

# Check if regeneration is needed for a specific file
check_file_regeneration_needed() {
    local output_file="$1"
    local version_file="$2"
    
    if [[ $FORCE -eq 1 ]]; then
        return 0
    fi
    
    if [[ ! -f "$output_file" ]]; then
        log_verbose "Output file missing: $(basename "$output_file")"
        return 0
    fi
    
    # Check version file for timestamp comparison
    local reference_time=0
    if [[ -f "$version_file" ]] && [[ -s "$version_file" ]]; then
        local version_content
        version_content=$(cat "$version_file" | xargs)
        if [[ -n "$version_content" ]]; then
            # Try to parse timestamp (assuming ISO format or similar)
            reference_time=$(date -d "$version_content" +%s 2>/dev/null || echo 0)
        fi
    fi
    
    # If no valid version timestamp, file needs regeneration
    if [[ $reference_time -eq 0 ]]; then
        log_verbose "No valid version timestamp found, regenerating $(basename "$output_file")"
        return 0
    fi
    
    local output_time
    output_time=$(stat -c %Y "$output_file" 2>/dev/null || stat -f %m "$output_file" 2>/dev/null || echo 0)
    
    if [[ $reference_time -gt $output_time ]]; then
        log_verbose "Version timestamp is newer than output file: $(basename "$output_file")"
        return 0
    fi
    
    return 1
}

# Check if regeneration is needed
check_regeneration_needed() {
    local input_file="$1"
    local output_file1="$2"
    local output_file2="$3"
    local output_file3="$4"
    local version_file="$5"
    
    if [[ $FORCE -eq 1 ]]; then
        log_verbose "Force flag specified, regenerating files"
        return 0
    fi
    
    if [[ ! -f "$input_file" ]]; then
        log_message "Input file not found: $input_file" "ERROR"
        return 1
    fi
    
    # Check version file for timestamp comparison
    local reference_time
    if [[ -f "$version_file" ]] && [[ -s "$version_file" ]]; then
        local version_content
        version_content=$(cat "$version_file" | xargs)
        if [[ -n "$version_content" ]]; then
            # Try to parse timestamp (assuming ISO format or similar)
            reference_time=$(date -d "$version_content" +%s 2>/dev/null || echo 0)
            if [[ $reference_time -gt 0 ]]; then
                log_verbose "Using version file timestamp: $version_content"
            else
                reference_time=0
            fi
        else
            reference_time=0
        fi
    else
        reference_time=0
    fi
    
    # Fall back to input file time if no valid version timestamp
    if [[ $reference_time -eq 0 ]]; then
        reference_time=$(stat -c %Y "$input_file" 2>/dev/null || stat -f %m "$input_file" 2>/dev/null || echo 0)
        log_verbose "Using input file timestamp"
    fi
    
    for output_file in "$output_file1" "$output_file2" "$output_file3"; do
        if [[ ! -f "$output_file" ]]; then
            log_verbose "Output file missing: $(basename "$output_file")"
            return 0
        fi
        
        local output_time
        output_time=$(stat -c %Y "$output_file" 2>/dev/null || stat -f %m "$output_file" 2>/dev/null || echo 0)
        
        if [[ $reference_time -gt $output_time ]]; then
            log_verbose "Reference time is newer than output file: $(basename "$output_file")"
            return 0
        fi
    done
    
    return 1
}

# Process genes.tsv and create genelist files
create_genelist_files() {
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
    # From earlier debug: 1=panel_id, 2=hgnc_symbol, 3=ensembl_id, 4=confidence_level
    local ensembl_col=3
    local panel_col=1
    local confidence_col=4
    
    log_verbose "Using column positions - ensembl_id: $ensembl_col, panel_id: $panel_col, confidence_level: $confidence_col"
    
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
    
    # Process Green genes (confidence_level = 3) - only if needed
    if check_file_regeneration_needed "$green_file" "$version_file"; then
        log_verbose "Processing Green genes (confidence_level = 3)"
        awk -F'\t' -v ensembl_col="$ensembl_col" -v panel_col="$panel_col" -v confidence_col="$confidence_col" '
            NR > 1 && $confidence_col == "3" && $ensembl_col != "" {
                print $ensembl_col "\t" "Paus:" $panel_col ".Green"
            }
        ' "$genes_file" | sort -t$'\t' -k1,1 -k2,2 > "$green_file"
        
        local green_count
        green_count=$(wc -l < "$green_file")
        if [[ $green_count -eq 0 ]]; then
            log_message "No Green genes found - output would be empty" "ERROR"
            return 1
        fi
        log_message "Created Green genelist: $green_file ($green_count entries)" "SUCCESS"
    else
        log_message "Green genelist is up to date: $(basename "$green_file")"
    fi
    
    # Process Amber genes (confidence_level = 2) - only if needed
    if check_file_regeneration_needed "$amber_file" "$version_file"; then
        log_verbose "Processing Amber genes (confidence_level = 2)"
        awk -F'\t' -v ensembl_col="$ensembl_col" -v panel_col="$panel_col" -v confidence_col="$confidence_col" '
            NR > 1 && $confidence_col == "2" && $ensembl_col != "" {
                print $ensembl_col "\t" "Paus:" $panel_col ".Amber"
            }
        ' "$genes_file" | sort -t$'\t' -k1,1 -k2,2 > "$amber_file"
        
        local amber_count
        amber_count=$(wc -l < "$amber_file")
        if [[ $amber_count -eq 0 ]]; then
            log_message "No Amber genes found - output would be empty" "ERROR"
            return 1
        fi
        log_message "Created Amber genelist: $amber_file ($amber_count entries)" "SUCCESS"
    else
        log_message "Amber genelist is up to date: $(basename "$amber_file")"
    fi
    
    # Create simple genelist file (all unique ensembl_ids, no headers, sorted) - only if needed
    local simple_file="$output_dir/genelist.PanelAppAustralia_GreenAmber.txt"
    
    # Check if simple genelist needs regeneration (based on Green and Amber input files)
    local needs_simple_regen=0
    if [[ ! -f "$simple_file" ]]; then
        log_verbose "Simple genelist missing: $(basename "$simple_file")"
        needs_simple_regen=1
    elif [[ $FORCE -eq 1 ]]; then
        needs_simple_regen=1
    else
        local simple_time
        simple_time=$(stat -c %Y "$simple_file" 2>/dev/null || stat -f %m "$simple_file" 2>/dev/null || echo 0)
        
        # Check if either Green or Amber file is newer than simple file
        for input_file in "$green_file" "$amber_file"; do
            if [[ -f "$input_file" ]]; then
                local input_time
                input_time=$(stat -c %Y "$input_file" 2>/dev/null || stat -f %m "$input_file" 2>/dev/null || echo 0)
                if [[ $input_time -gt $simple_time ]]; then
                    log_verbose "Input file is newer than simple genelist: $(basename "$input_file")"
                    needs_simple_regen=1
                    break
                fi
            fi
        done
    fi
    
    if [[ $needs_simple_regen -eq 1 ]]; then
        log_verbose "Creating simple genelist (all unique ensembl_ids)"
        
        # Create temporary file with all ensembl_ids from Green and Amber files
        local temp_file="${simple_file}.tmp"
        > "$temp_file"  # Create empty file
        
        # Extract ensembl_ids from Green file if it exists
        if [[ -f "$green_file" ]]; then
            cut -f1 "$green_file" >> "$temp_file"
        fi
        
        # Extract ensembl_ids from Amber file if it exists
        if [[ -f "$amber_file" ]]; then
            cut -f1 "$amber_file" >> "$temp_file"
        fi
        
        # Sort unique and remove empty lines, then remove trailing newline
        if [[ -s "$temp_file" ]]; then
            sort -u "$temp_file" | grep -v '^$' > "${temp_file}.sorted"
            local simple_count_check
            simple_count_check=$(wc -l < "${temp_file}.sorted" 2>/dev/null || echo 0)
            if [[ $simple_count_check -eq 0 ]]; then
                log_message "No ensembl_ids found for simple genelist - output would be empty" "ERROR"
                rm "$temp_file" "${temp_file}.sorted" 2>/dev/null || true
                return 1
            fi
            cp "${temp_file}.sorted" "$simple_file"
            rm "$temp_file" "${temp_file}.sorted"
        else
            log_message "No ensembl_ids found for simple genelist - output would be empty" "ERROR"
            rm "$temp_file" 2>/dev/null || true
            return 1
        fi
        
        local simple_count
        simple_count=$(wc -l < "$simple_file" 2>/dev/null || echo 0)
        log_message "Created simple genelist: $simple_file ($simple_count unique ensembl_ids)" "SUCCESS"
    else
        log_message "Simple genelist is up to date: $(basename "$simple_file")"
    fi
    
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
    local version_file="$DATA_PATH/genes/version_merged.txt"
    local output_dir="$DATA_PATH/genelists"
    local green_file="$output_dir/genes_to_genelists.PanelAppAustralia_Green.txt"
    local amber_file="$output_dir/genes_to_genelists.PanelAppAustralia_Amber.txt"
    local simple_file="$output_dir/genelist.PanelAppAustralia_GreenAmber.txt"
    
    # Check if any regeneration is needed (for overall process decision)
    # Note: Simple genelist is now dependent on Green/Amber files, not version file
    local any_regen_needed=1
    if ! check_regeneration_needed "$genes_file" "$green_file" "$amber_file" "$version_file" "$version_file"; then
        any_regen_needed=0
    fi
    
    # Also check if simple genelist needs regen based on confidence files
    if [[ $any_regen_needed -eq 0 && -f "$green_file" && -f "$amber_file" ]]; then
        if [[ ! -f "$simple_file" ]]; then
            any_regen_needed=1
        else
            local simple_time
            simple_time=$(stat -c %Y "$simple_file" 2>/dev/null || stat -f %m "$simple_file" 2>/dev/null || echo 0)
            
            for conf_file in "$green_file" "$amber_file"; do
                if [[ -f "$conf_file" ]]; then
                    local conf_time
                    conf_time=$(stat -c %Y "$conf_file" 2>/dev/null || stat -f %m "$conf_file" 2>/dev/null || echo 0)
                    if [[ $conf_time -gt $simple_time ]]; then
                        any_regen_needed=1
                        break
                    fi
                fi
            done
        fi
    fi
    
    if [[ $any_regen_needed -eq 0 && $FORCE -eq 0 ]]; then
        log_message "All genelist files are up to date, skipping regeneration"
        log_message "Use --force to regenerate anyway"
        return 0
    fi
    
    # Process genes and create genelist files (individual files will be checked within)
    if create_genelist_files "$genes_file" "$output_dir" "$version_file"; then
        # Create version file for genelists with current timestamp
        local genelists_version_file="$output_dir/version_genelists.txt"
        local current_timestamp
        current_timestamp=$(date -u '+%Y-%m-%dT%H:%M:%S.%7NZ' 2>/dev/null || date -u '+%Y-%m-%dT%H:%M:%SZ')
        echo "$current_timestamp" > "$genelists_version_file"
        log_verbose "Created version file: $genelists_version_file with timestamp: $current_timestamp"
        
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