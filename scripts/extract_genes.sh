#!/bin/bash
# PanelApp Australia Incremental Gene Extraction Script (Bash)
# This script extracts gene data only for panels that have been updated since last extraction
# Tracks version_created dates and compares with previously extracted data

set -euo pipefail

# Configuration
BASE_URL="https://panelapp-aus.org/api"
API_VERSION="v1"
DATA_PATH="../data"
FOLDER=""
VERBOSE=0
FORCE=0

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
Usage: $0 [OPTIONS]

Extract gene data incrementally from PanelApp Australia API.
Only downloads panels that have been updated since last extraction.

OPTIONS:
    --data-path PATH    Path to data directory (default: ../data)

    --force             Force re-download all panels
    --verbose           Enable verbose logging
    --help             Show this help message

EXAMPLES:
    $0                                    # Use latest data folder

    $0 --force                            # Force re-download all
    $0 --data-path /path/to/data --verbose # Custom path with verbose output
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

# Find the latest data folder
find_latest_data_folder() {
    local data_path="$1"
    
    if [[ ! -d "$data_path" ]]; then
        log_message "Data path does not exist: $data_path" "ERROR"
        return 1
    fi
    
    # Look for date folders (YYYYMMDD format)
    local latest_folder
    latest_folder=$(find "$data_path" -maxdepth 1 -type d -name '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]' | sort -r | head -1)
    
    if [[ -z "$latest_folder" ]]; then
        # Try today's date
        local today
        today=$(date '+%Y%m%d')
        local today_folder="$data_path/$today"
        if [[ -d "$today_folder" ]]; then
            log_message "Using today's folder: $today_folder"
            echo "$today_folder"
            return 0
        else
            log_message "No data folders found and today's folder doesn't exist: $today_folder" "ERROR"
            return 1
        fi
    fi
    
    log_message "Using latest data folder: $latest_folder"
    echo "$latest_folder"
}

# Update version tracking file for successfully downloaded panel
update_panel_version_tracking() {
    local data_folder="$1"
    local panel_id="$2"
    local version_created="$3"
    
    # Ensure panel directory exists
    local panel_dir="$data_folder/panels/$panel_id"
    mkdir -p "$panel_dir"
    
    # Update version tracking file
    local version_file="$panel_dir/version_created.txt"
    echo -n "$version_created" > "$version_file"
    
    log_message "Updated version tracking for panel $panel_id to $version_created"
}

# Check if panel needs to be updated based on version file in panel directory
panel_needs_update() {
    local panel_id="$1"
    local current_version_created="$2"
    local data_folder="$3"
    local force="$4"
    
    if [[ "$force" == "1" ]]; then
        return 0
    fi
    
    # Check for existing version file in panel directory
    local version_file="$data_folder/panels/$panel_id/version_created.txt"
    
    if [[ ! -f "$version_file" ]]; then
        log_message "Panel $panel_id has no version tracking file, will download"
        return 0
    fi
    
    local last_version_created
    last_version_created=$(cat "$version_file" 2>/dev/null || echo "")
    
    if [[ -z "$last_version_created" ]]; then
        log_message "Panel $panel_id has empty version file, will download"
        return 0
    fi
    
    # Compare dates (simplified string comparison should work for ISO dates)
    if [[ "$current_version_created" > "$last_version_created" ]]; then
        log_message "Panel $panel_id has been updated ($last_version_created -> $current_version_created)"
        return 0
    else
        log_message "Panel $panel_id is up to date ($current_version_created)"
        return 1
    fi
}

# Download genes for a specific panel
download_panel_genes() {
    local data_folder="$1"
    local panel_id="$2"
    local panel_name="$3"
    local version_created="$4"
    
    log_message "Extracting genes for panel $panel_id ($panel_name)..."
    
    # Create panel-specific directory structure
    local panel_dir="$data_folder/panels/$panel_id/genes/json"
    mkdir -p "$panel_dir"
    
    # Download genes with pagination
    local gene_url="$BASE_URL/$API_VERSION/panels/$panel_id/genes/"
    local page=1
    local next_url="$gene_url"
    
    while [[ -n "$next_url" && "$next_url" != "null" ]]; do
        log_message "  Downloading genes page $page for panel $panel_id..."
        
        local response_file="$panel_dir/genes_page_$page.json"
        
        if ! curl -s -f "$next_url" -o "$response_file"; then
            log_message "Error downloading genes for panel $panel_id" "ERROR"
            return 1
        fi
        
        # Parse response for pagination info
        if command -v jq >/dev/null 2>&1; then
            local count
            local results_count
            count=$(jq -r '.count // 0' "$response_file")
            results_count=$(jq -r '.results | length' "$response_file")
            next_url=$(jq -r '.next // empty' "$response_file")
            
            log_message "    Page $page downloaded: $results_count genes (Total: $count)"
        else
            log_message "    Page $page downloaded (jq not available for detailed info)"
            # Simple check for next page without jq
            if grep -q '"next":' "$response_file"; then
                next_url="continue"  # Will be handled in next iteration
            else
                next_url=""
            fi
        fi
        
        ((page++))
        
        # Safety check
        if [[ $page -gt 100 ]]; then
            log_message "Safety limit reached (100 pages) for panel $panel_id" "WARNING"
            break
        fi
    done
    
    log_message "Completed gene extraction for panel $panel_id ($((page-1)) pages)" "SUCCESS"
    
    # Create version_extracted.txt with current timestamp
    local genes_dir="$data_folder/panels/$panel_id/genes"
    local version_extracted_path="$genes_dir/version_extracted.txt"
    date -u '+%Y-%m-%dT%H:%M:%S.%6NZ' > "$version_extracted_path"
    
    # Return extraction metadata as JSON
    local extraction_date
    extraction_date=$(date -u '+%Y-%m-%dT%H:%M:%S.000Z')
    
    cat << EOF
{
  "success": true,
  "panel_id": "$panel_id",
  "version_created": "$version_created",
  "extraction_date": "$extraction_date",
  "pages_downloaded": $((page-1))
}
EOF
}



# Main execution function
main() {
    log_message "Starting PanelApp Australia incremental gene extraction..."
    
    # Determine data folder
    local data_folder
    # Use data path directly (no date subfolders)
    data_folder="$DATA_PATH"
    if [[ ! -d "$data_folder" ]]; then
        log_message "Data path does not exist: $data_folder" "ERROR"
        exit 1
    fi
    log_message "Using data folder: $data_folder"
    
    # Check for required files
    local tsv_file="$data_folder/panel_list/panel_list.tsv"
    if [[ ! -f "$tsv_file" ]]; then
        log_message "Panel list file not found: $tsv_file" "ERROR"
        exit 1
    fi
    
    # Read panel data and filter panels that need updating
    local panels_to_update=()
    local total_panels=0
    
    while IFS=$'\t' read -r id name version version_created; do
        # Skip header line
        if [[ "$id" == "id" ]]; then
            continue
        fi
        
        # Validate panel ID
        if [[ ! "$id" =~ ^[0-9]+$ ]]; then
            [[ -n "$id" ]] && log_message "Invalid panel ID: $id" "WARNING"
            continue
        fi
        
        ((total_panels++))
        
        # Check if panel needs updating
        if panel_needs_update "$id" "$version_created" "$data_folder" "$FORCE"; then
            panels_to_update+=("$id|$name|$version|$version_created")
        fi
        
    done < "$tsv_file"
    
    if [[ ${#panels_to_update[@]} -eq 0 ]]; then
        log_message "All panels are up to date. No downloads needed." "SUCCESS"
        exit 0
    fi
    
    log_message "Will download genes for ${#panels_to_update[@]} panels (out of $total_panels total)"
    
    # Download genes for panels that need updating
    local successful=0
    local failed=0
    
    for panel_data in "${panels_to_update[@]}"; do
        IFS='|' read -r panel_id panel_name panel_version version_created <<< "$panel_data"
        
        if download_panel_genes "$data_folder" "$panel_id" "$panel_name" "$version_created" > /dev/null; then
            ((successful++))
            # Update version tracking file
            update_panel_version_tracking "$data_folder" "$panel_id" "$version_created"
        else
            ((failed++))
        fi
    done
    
    log_message "Incremental gene extraction completed: $successful successful, $failed failed" "SUCCESS"
    if [[ $failed -gt 0 ]]; then
        log_message "Some panels failed. Check logs for details." "WARNING"
    fi
    
    log_message "Output directory: $data_folder"
    log_message "Version tracking files updated in individual panel directories"
}

# Parse arguments and run main function
parse_args "$@"
main