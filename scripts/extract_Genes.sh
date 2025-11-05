#!/bin/bash
# PanelApp Australia Incremental Gene Extraction Script (Bash)
# This script extracts gene data only for panels that have been updated since last extraction
# Tracks version_created dates and compares with previously extracted data
# All output files use Unix newlines (LF) for cross-platform compatibility

set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# Configuration
BASE_URL="https://panelapp-aus.org/api"
API_VERSION="v1"
DATA_PATH="../data"
FOLDER=""
PANEL_ID=""
VERBOSE=0
FORCE=0

# Logging functions
log_message() {
    local message="$1"
    local level="${2:-INFO}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "ERROR")
            echo "[$timestamp] $message" >&2
            ;;
        "SUCCESS")
            echo "[$timestamp] $message"
            ;;
        "WARNING")
            echo "[$timestamp] $message"
            ;;
        *)
            echo "[$timestamp] $message"
            ;;
    esac
}

# Clear JSON directory to prevent inconsistencies from old files
clear_json_directory() {
    local json_path="$1"
    
    if [ -d "$json_path" ]; then
        log_message "Clearing existing JSON files from: $json_path" "INFO"
        local json_files=($(find "$json_path" -name "*.json" 2>/dev/null))
        if [ ${#json_files[@]} -gt 0 ]; then
            rm -f "$json_path"/*.json 2>/dev/null || true
            log_message "Removed ${#json_files[@]} existing JSON files" "SUCCESS"
        else
            log_message "No existing JSON files found to clear" "INFO"
        fi
    else
        log_message "JSON directory does not exist yet: $json_path" "INFO"
    fi
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Extract gene data incrementally from PanelApp Australia API.
Only downloads panels that have been updated since last extraction.

OPTIONS:
    --data-path PATH    Path to data directory (default: ../data)
    --panel-id ID       Extract genes for specific panel ID only
    --force             Force re-download all panels
    --verbose           Enable verbose logging
    --help             Show this help message

EXAMPLES:
    $0                                    # Use data path directly
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

            --panel-id)
                PANEL_ID="$2"
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
    
    log_message "Checking panel $panel_id for updates (force=$force)"
    
    if [[ "$force" == "1" ]]; then
        return 0
    fi
    
    # Check for JSON folder existence
    local json_folder="$data_folder/panels/$panel_id/genes/json"
    if [[ ! -d "$json_folder" ]]; then
        log_message "Panel $panel_id has no JSON folder, will download"
        return 0
    fi
    
    # Check for JSON files in the folder
    local json_file_count
    json_file_count=$(find "$json_folder" -name "*.json" -type f 2>/dev/null | wc -l || echo "0")
    if [[ "$json_file_count" -eq 0 ]]; then
        log_message "Panel $panel_id has no JSON files in folder, will download"
        return 0
    fi
    
    # Check for version_extracted.txt file
    local version_extracted_file="$data_folder/panels/$panel_id/genes/version_extracted.txt"
    if [[ ! -f "$version_extracted_file" ]]; then
        log_message "Panel $panel_id has no extraction tracking file, will download"
        return 0
    fi
    
    # Check for version_created.txt file
    local version_created_file="$data_folder/panels/$panel_id/version_created.txt"
    if [[ ! -f "$version_created_file" ]]; then
        log_message "Panel $panel_id has no version tracking file, will download"
        return 0
    fi
    
    # Read extraction date
    local extracted_date
    extracted_date=$(cat "$version_extracted_file" 2>/dev/null | tr -d '[:space:]' 2>/dev/null || echo "")
    
    if [[ -z "$extracted_date" ]]; then
        log_message "Panel $panel_id has empty extraction tracking file, will download"
        return 0
    fi
    
    # Read version created date
    local last_version_created
    last_version_created=$(cat "$version_created_file" 2>/dev/null | tr -d '[:space:]' 2>/dev/null || echo "")
    
    if [[ -z "$last_version_created" ]]; then
        log_message "Panel $panel_id has empty version file, will download"
        return 0
    fi
    
    # Check if panel version has been updated since last extraction
    if [[ "$current_version_created" > "$last_version_created" ]]; then
        log_message "Panel $panel_id has been updated ($last_version_created -> $current_version_created)"
        return 0
    fi
    
    # Check if extraction is older than the version created date
    if [[ "$extracted_date" < "$last_version_created" ]]; then
        log_message "Panel $panel_id extraction is older than version created date, will download"
        return 0
    fi
    
    log_message "Panel $panel_id is up to date ($current_version_created)"
    return 1
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
    
    # Clear any existing JSON files to prevent inconsistencies
    clear_json_directory "$panel_dir"
    
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
    
    log_message "Found TSV file: $tsv_file"
    
    # Display filtering information if panel ID is specified
    if [[ -n "$PANEL_ID" ]]; then
        log_message "Filtering for specific panel ID: $PANEL_ID" "INFO"
    fi
    
    # Read panel data and filter panels that need updating
    local panels_to_update=()
    local total_panels=0
    
    log_message "Starting to read TSV file..."
    
    while IFS=$'\t' read -r id name version version_created number_of_genes number_of_strs number_of_regions; do
        log_message "Read line: id='$id', name='$name'"
        
        # Skip header line
        if [[ "$id" == "id" ]]; then
            log_message "Skipping header line"
            continue
        fi
        
        log_message "Processing non-header line: $id"
        
        # Filter for specific panel ID if provided
        if [[ -n "$PANEL_ID" && "$id" != "$PANEL_ID" ]]; then
            log_message "Filtered out panel $id"
            continue
        fi
        
        log_message "Panel $id passed filter"
        
        # Validate panel ID
        if [[ -z "$id" || ! "$id" =~ ^[0-9]+$ ]]; then
            log_message "Invalid panel ID: '$id'"
            [[ -n "$id" ]] && log_message "Invalid panel ID: $id" "WARNING"
            continue
        fi
        
        log_message "Panel $id is valid"
        
        total_panels=$((total_panels + 1))
        log_message "Incremented total_panels to $total_panels"
        
        # Add debug for first panel
        if [[ $total_panels -eq 1 ]]; then
            log_message "Processing first panel: $id"
        fi
        
        # Check if panel needs updating
        if panel_needs_update "$id" "$version_created" "$data_folder" "$FORCE"; then
            panels_to_update+=("$id|$name|$version|$version_created")
        fi
        
    done < "$tsv_file"
    
    log_message "Finished reading TSV, total_panels: $total_panels, panels_to_update: ${#panels_to_update[@]}"
    
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