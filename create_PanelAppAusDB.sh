#!/bin/bash
# PanelApp Australia Complete Data Extraction Wrapper Script (Bash)
# This script orchestrates the complete data extraction process:
# 1. Extracts panel list data
# 2. Extracts detailed gene data for each panel
# 3. Processes gene data (converts JSON to TSV format)
# 4. Merges panel data (consolidates TSVs with panel_id column)
# 5. Will extract STR data (placeholder for future implementation)
# 6. Will extract region data (placeholder for future implementation)

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_PATH="./data"
PANEL_ID=""
SKIP_GENES=0
SKIP_STRS=0
SKIP_REGIONS=0
FORCE=0
VERBOSE=0
CREATE_SOMATIC_GENELISTS=0

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

# Show usage information
show_usage() {
    cat << EOF
PanelApp Australia Complete Data Extraction Wrapper

DESCRIPTION:
    This script orchestrates the complete data extraction process from PanelApp Australia API.
    It runs panel list extraction, detailed data extraction for genes, data processing, and merging.

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --output-path PATH    Path to output directory (default: ./data)
    --panel-id ID         Extract data for specific panel ID only
    --skip-genes         Skip gene data extraction
    --skip-strs          Skip STR data extraction
    --skip-regions       Skip region data extraction
    --force              Force re-download all data (ignore version tracking)
    --verbose            Enable verbose logging
    --create-somatic-genelists  Generate somatic genelists in addition to standard genelists (optional)
    --help              Show this help message

EXAMPLES:
    $0                                    # Full extraction with general genelists
    $0 --create-somatic-genelists         # Full extraction with both general and somatic genelists
    $0 --panel-id 6                      # Extract only panel 6
    $0 --skip-genes                       # Skip gene extraction
    $0 --force                            # Force re-download all
    $0 --output-path /path/to/data        # Custom output path
    $0 --verbose                          # Verbose logging

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --output-path)
                OUTPUT_PATH="$2"
                shift 2
                ;;
            --panel-id)
                PANEL_ID="$2"
                shift 2
                ;;
            --skip-genes)
                SKIP_GENES=1
                shift
                ;;
            --skip-strs)
                SKIP_STRS=1
                shift
                ;;
            --skip-regions)
                SKIP_REGIONS=1
                shift
                ;;
            --force)
                FORCE=1
                shift
                ;;
            --verbose)
                VERBOSE=1
                shift
                ;;
            --create-somatic-genelists)
                CREATE_SOMATIC_GENELISTS=1
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

# Execute a script and handle errors
run_script() {
    local script_path="$1"
    local script_name="$2"
    local optional="${3:-false}"
    shift 3
    local args=("$@")
    
    if [[ ! -f "$script_path" ]]; then
        if [[ "$optional" == "true" ]]; then
            log_message "$script_name not found at $script_path (optional - skipping)" "WARNING"
            return 0
        else
            log_message "$script_name not found at $script_path" "ERROR"
            return 1
        fi
    fi
    
    log_message "Running $script_name..."
    
    # Add verbose flag if specified
    if [[ $VERBOSE -eq 1 ]]; then
        args+=(--verbose)
    fi
    
    if bash "$script_path" "${args[@]}"; then
        log_message "$script_name completed successfully" "SUCCESS"
        return 0
    else
        local exit_code=$?
        log_message "$script_name failed with exit code $exit_code" "ERROR"
        return $exit_code
    fi
}

# Main execution function
main() {
    log_message "Starting PanelApp Australia complete data extraction..."
    
    local success=true
    
    # Step 1: Extract panel list data
    local panel_list_script="$SCRIPT_DIR/scripts/extract_PanelList.sh"
    local panel_list_args=("--output-path" "$OUTPUT_PATH")
    
    if ! run_script "$panel_list_script" "Panel List Extraction" false "${panel_list_args[@]}"; then
        log_message "Panel list extraction failed. Cannot continue." "ERROR"
        exit 1
    fi
    
    # Set data folder path directly
    local data_folder="$OUTPUT_PATH"
    
    if [[ ! -d "$data_folder" ]]; then
        log_message "Data folder not found: $data_folder" "ERROR"
        exit 1
    fi
    
    log_message "Using data folder: $data_folder"
    
    # Step 2: Extract gene data (if not skipped)
    if [[ $SKIP_GENES -eq 0 ]]; then
        local gene_script="$SCRIPT_DIR/scripts/extract_Genes.sh"
        local gene_args=("--data-path" "$OUTPUT_PATH")
        if [[ $FORCE -eq 1 ]]; then
            gene_args+=("--force")
        fi
        if [[ -n "$PANEL_ID" ]]; then
            gene_args+=("--panel-id" "$PANEL_ID")
        fi
        
        if run_script "$gene_script" "Gene Data Extraction" false "${gene_args[@]}"; then
            # Step 2b: Process gene data (convert JSON to TSV)
            local process_script="$SCRIPT_DIR/scripts/process_Genes.sh"
            local process_args=("--data-path" "$OUTPUT_PATH")
            if [[ $FORCE -eq 1 ]]; then
                process_args+=("--force")
            fi
            if [[ -n "$PANEL_ID" ]]; then
                process_args+=("--panel-id" "$PANEL_ID")
            fi
            
            if ! run_script "$process_script" "Gene Data Processing" false "${process_args[@]}"; then
                log_message "Gene processing failed, but continuing with other extractions" "WARNING"
                success=false
            else
                # Step 2c: Merge panel data (consolidate TSVs with panel_id column)
                local merge_script="$SCRIPT_DIR/scripts/merge_Panels.sh"
                local merge_args=("--data-path" "$OUTPUT_PATH")
                if [[ $FORCE -eq 1 ]]; then
                    merge_args+=("--force")
                fi
                if [[ $VERBOSE -eq 1 ]]; then
                    merge_args+=("--verbose")
                fi
                
                if ! run_script "$merge_script" "Panel Data Merging" false "${merge_args[@]}"; then
                    log_message "Panel data merging failed, but continuing with other extractions" "WARNING"
                    success=false
                fi
                
                # Step 2d: Create general genelists (mandatory) - attempt if genes.tsv exists
                local genes_file="$OUTPUT_PATH/genes/genes.tsv"
                if [[ -f "$genes_file" ]]; then
                    local genelist_script="$SCRIPT_DIR/scripts/create_Genelists.sh"
                    local genelist_args=("--data-path" "$OUTPUT_PATH")
                    if [[ $VERBOSE -eq 1 ]]; then
                        genelist_args+=("--verbose")
                    fi
                    
                    if ! run_script "$genelist_script" "General Genelist Creation" false "${genelist_args[@]}"; then
                        log_message "General genelist creation failed, but continuing with other extractions" "WARNING"
                        success=false
                    fi
                    
                    # Step 2e: Create somatic genelists (optional)
                    if [[ $CREATE_SOMATIC_GENELISTS -eq 1 ]]; then
                        local somatic_script="$SCRIPT_DIR/scripts/create_Somatic_genelists.sh"
                        local somatic_args=("--data-path" "$OUTPUT_PATH")
                        if [[ $VERBOSE -eq 1 ]]; then
                            somatic_args+=("--verbose")
                        fi
                        
                        if ! run_script "$somatic_script" "Somatic Genelist Creation" false "${somatic_args[@]}"; then
                            log_message "Somatic genelist creation failed, but continuing with other extractions" "WARNING"
                            success=false
                        fi
                    else
                        log_message "Skipping somatic genelist creation (--create-somatic-genelists not specified)"
                    fi
                else
                    log_message "Genes file not found at $genes_file, skipping genelist creation" "WARNING"
                    success=false
                fi
            fi
        else
            log_message "Gene extraction failed, but continuing with other extractions" "WARNING"
            success=false
        fi
    else
        log_message "Skipping gene extraction, processing, and merging (--skip-genes specified)"
    fi
    
    # Step 3: Extract STR data (placeholder - future implementation)
    if [[ $SKIP_STRS -eq 0 ]]; then
        local str_script="$SCRIPT_DIR/scripts/extract_strs.sh"
        local str_args=("--data-path" "$OUTPUT_PATH")
        
        if ! run_script "$str_script" "STR Data Extraction" true "${str_args[@]}"; then
            log_message "STR extraction failed or not implemented yet" "WARNING"
        fi
    else
        log_message "Skipping STR extraction (--skip-strs specified)"
    fi
    
    # Step 4: Extract region data (placeholder - future implementation)
    if [[ $SKIP_REGIONS -eq 0 ]]; then
        local region_script="$SCRIPT_DIR/scripts/extract_regions.sh"
        local region_args=("--data-path" "$OUTPUT_PATH")
        
        if ! run_script "$region_script" "Region Data Extraction" true "${region_args[@]}"; then
            log_message "Region extraction failed or not implemented yet" "WARNING"
        fi
    else
        log_message "Skipping region extraction (--skip-regions specified)"
    fi
    
    # Summary
    if [[ "$success" == "true" ]]; then
        log_message "Complete data extraction finished successfully!" "SUCCESS"
    else
        log_message "Complete data extraction finished with some warnings/errors" "WARNING"
    fi
    
    log_message "Output directory: $data_folder"
    echo ""
    log_message "Data extraction summary:"
    log_message "  Panel list: Completed"
    log_message "  Gene data: $(if [[ $SKIP_GENES -eq 1 ]]; then echo 'Skipped'; else echo 'Attempted'; fi)"
    log_message "  Gene processing: $(if [[ $SKIP_GENES -eq 1 ]]; then echo 'Skipped'; else echo 'Attempted'; fi)"
    log_message "  Panel data merging: $(if [[ $SKIP_GENES -eq 1 ]]; then echo 'Skipped'; else echo 'Attempted'; fi)"
    log_message "  General genelists: $(if [[ $SKIP_GENES -eq 1 ]]; then echo 'Skipped'; else echo 'Attempted'; fi)"
    log_message "  Somatic genelists: $(if [[ $SKIP_GENES -eq 1 ]]; then echo 'Skipped'; elif [[ $CREATE_SOMATIC_GENELISTS -eq 1 ]]; then echo 'Attempted'; else echo 'Skipped'; fi)"
    log_message "  STR data: $(if [[ $SKIP_STRS -eq 1 ]]; then echo 'Skipped'; else echo 'Attempted (future implementation)'; fi)"
    log_message "  Region data: $(if [[ $SKIP_REGIONS -eq 1 ]]; then echo 'Skipped'; else echo 'Attempted (future implementation)'; fi)"
}

# Parse arguments and run main function
parse_args "$@"

# Check if we can find the panel list script
if [[ ! -f "$SCRIPT_DIR/scripts/extract_PanelList.sh" ]]; then
    log_message "Required script extract_PanelList.sh not found in $SCRIPT_DIR/scripts" "ERROR"
    exit 1
fi

# Run main function
main