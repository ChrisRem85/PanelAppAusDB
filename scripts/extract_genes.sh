#!/bin/bash

# PanelApp Australia Gene Extraction Script
# This script extracts gene data for each panel listed in panel_list.tsv
# Reads panel IDs from the TSV file and downloads genes with pagination

set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# Configuration
BASE_URL="https://panelapp-aus.org/api"
API_VERSION="v1"
DATA_PATH="../data"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse command line arguments
FOLDER=""
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --data-path)
            DATA_PATH="$2"
            shift 2
            ;;
        --folder)
            FOLDER="$2"
            shift 2
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --data-path PATH    Data directory path (default: ../data)"
            echo "  --folder FOLDER     Specific data folder (YYYYMMDD format)"
            echo "  --verbose, -v       Enable verbose logging"
            echo "  --help, -h          Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v curl &> /dev/null; then
        missing_deps+=("curl")
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        error "Missing required dependencies: ${missing_deps[*]}"
        error "Please install the missing dependencies and try again."
        exit 1
    fi
}

# Find the latest data folder
find_latest_data_folder() {
    if [ ! -d "$DATA_PATH" ]; then
        error "Data path does not exist: $DATA_PATH"
        return 1
    fi
    
    # Look for date folders (YYYYMMDD format)
    local latest_folder=""
    for folder in "$DATA_PATH"/*/; do
        if [ -d "$folder" ]; then
            local folder_name=$(basename "$folder")
            if [[ "$folder_name" =~ ^[0-9]{8}$ ]]; then
                if [ -z "$latest_folder" ] || [ "$folder_name" > "$(basename "$latest_folder")" ]; then
                    latest_folder="$folder"
                fi
            fi
        fi
    done
    
    if [ -z "$latest_folder" ]; then
        # Try today's date
        local today=$(date +%Y%m%d)
        local today_folder="$DATA_PATH/$today"
        if [ -d "$today_folder" ]; then
            log "Using today's folder: $today_folder"
            echo "$today_folder"
            return 0
        else
            error "No data folders found and today's folder doesn't exist: $today_folder"
            return 1
        fi
    fi
    
    log "Using latest data folder: $latest_folder"
    echo "$latest_folder"
    return 0
}

# Read panel IDs from panel_list.tsv
read_panel_list() {
    local data_folder="$1"
    local tsv_file="$data_folder/panel_list.tsv"
    
    if [ ! -f "$tsv_file" ]; then
        error "Panel list file not found: $tsv_file"
        return 1
    fi
    
    local panel_ids=()
    local line_num=1
    
    # Read file and skip header
    while IFS=$'\t' read -r panel_id rest; do
        if [ $line_num -eq 1 ]; then
            # Skip header
            ((line_num++))
            continue
        fi
        
        if [[ "$panel_id" =~ ^[0-9]+$ ]]; then
            panel_ids+=("$panel_id")
        elif [ -n "$panel_id" ]; then
            warning "Invalid panel ID on line $line_num: $panel_id"
        fi
        ((line_num++))
    done < "$tsv_file"
    
    log "Found ${#panel_ids[@]} panels to process"
    
    # Export array for use in other functions
    printf '%s\n' "${panel_ids[@]}"
}

# Download genes for a specific panel
download_panel_genes() {
    local data_folder="$1"
    local panel_id="$2"
    
    log "Extracting genes for panel $panel_id..."
    
    # Create panel-specific directory structure
    local panel_dir="$data_folder/panels/$panel_id/genes/json"
    mkdir -p "$panel_dir"
    
    # Download genes with pagination
    local gene_url="$BASE_URL/$API_VERSION/panels/$panel_id/genes/"
    local page=1
    local next_url="$gene_url"
    
    while [ -n "$next_url" ] && [ "$next_url" != "null" ]; do
        log "  Downloading genes page $page for panel $panel_id..."
        
        local response_file="$panel_dir/genes_page_${page}.json"
        
        # Download the page
        local http_code
        http_code=$(curl -s -w "%{http_code}" -o "$response_file" "$next_url")
        
        if [ "$http_code" != "200" ]; then
            error "HTTP $http_code error downloading genes for panel $panel_id, page $page"
            rm -f "$response_file"
            return 1
        fi
        
        # Validate JSON
        if ! jq empty "$response_file" 2>/dev/null; then
            error "Invalid JSON received for panel $panel_id, page $page"
            rm -f "$response_file"
            return 1
        fi
        
        # Get pagination info
        local count
        local next_url_raw
        count=$(jq -r '.count // 0' "$response_file")
        next_url_raw=$(jq -r '.next // null' "$response_file")
        
        # Handle null or empty next URL
        if [ "$next_url_raw" = "null" ] || [ -z "$next_url_raw" ]; then
            next_url=""
        else
            next_url="$next_url_raw"
        fi
        
        local results_count
        results_count=$(jq -r '.results | length' "$response_file")
        
        log "    Page $page downloaded: $results_count genes (Total: $count)"
        
        ((page++))
        
        # Safety check
        if [ $page -gt 100 ]; then
            warning "Safety limit reached (100 pages) for panel $panel_id"
            break
        fi
    done
    
    success "Completed gene extraction for panel $panel_id ($((page-1)) pages)"
    return 0
}

# Main execution
main() {
    log "Starting PanelApp Australia gene extraction..."
    
    # Check dependencies
    check_dependencies
    
    # Determine data folder
    local data_folder
    if [ -n "$FOLDER" ]; then
        data_folder="$DATA_PATH/$FOLDER"
        if [ ! -d "$data_folder" ]; then
            error "Specified folder does not exist: $data_folder"
            exit 1
        fi
        log "Using specified folder: $data_folder"
    else
        data_folder=$(find_latest_data_folder)
        if [ $? -ne 0 ]; then
            exit 1
        fi
    fi
    
    # Read panel list
    local panel_ids
    mapfile -t panel_ids < <(read_panel_list "$data_folder")
    
    if [ ${#panel_ids[@]} -eq 0 ]; then
        error "No panels found to process"
        exit 1
    fi
    
    # Download genes for each panel
    local successful=0
    local failed=0
    
    for panel_id in "${panel_ids[@]}"; do
        if download_panel_genes "$data_folder" "$panel_id"; then
            ((successful++))
        else
            ((failed++))
        fi
    done
    
    success "Gene extraction completed: $successful successful, $failed failed"
    if [ $failed -gt 0 ]; then
        warning "Some panels failed. Check logs for details."
    fi
    
    log "Output directory: $data_folder"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi