#!/bin/bash
# PanelApp Australia Panel List Extraction - Simplified Version
# Downloads panel list data from API with pagination

set -euo pipefail

# Configuration
BASE_URL="https://panelapp-aus.org/api/v1"
OUTPUT_DIR="./data"

# Load API configuration from config file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.sh"

if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    echo "[INFO] Loaded configuration from: $CONFIG_FILE"
else
    echo "[WARNING] Config file not found: $CONFIG_FILE"
    echo "[WARNING] Please copy config.sh.template to config.sh and add your API token"
    
    # Fallback to default values
    API_TOKEN=""  # No token
    REQUEST_DELAY=1.0
    USER_AGENT="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
fi

# Simple logging
log() {
    echo "[$(date '+%H:%M:%S')] $1"
}

error() {
    echo "[ERROR] $1" >&2
    exit 1
}

# Usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]
  --output-dir PATH   Data directory (default: ./data)
  --help              This help
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) error "Unknown option: $1" ;;
    esac
done

# Download panels with pagination
download_panels() {
    local panels_dir="$OUTPUT_DIR/panels"
    local json_dir="$panels_dir/json"
    
    log "Creating directory: $json_dir"
    mkdir -p "$json_dir"
    rm -f "$json_dir"/*.json 2>/dev/null || true
    
    # Download pages
    local page=1
    local total_panels=0
    local next_url="$BASE_URL/panels/"
    
    while [[ -n "$next_url" ]]; do
        local output="$json_dir/panels_page_$page.json"
        
        # Add delay to reduce API load (skip for first page)
        if [[ $page -gt 1 ]]; then
            sleep "$REQUEST_DELAY"
        fi
        
        log "Downloading page $page..."
        if [[ -n "$API_TOKEN" ]]; then
            http_code=$(curl -s -w "%{http_code}" -A "$USER_AGENT" -H "Authorization: $API_TOKEN" "$next_url" -o "$output")
            if [[ "$http_code" != "200" ]]; then
                error "Failed to download page $page (HTTP $http_code)"
            fi
        else
            http_code=$(curl -s -w "%{http_code}" -A "$USER_AGENT" "$next_url" -o "$output")
            if [[ "$http_code" != "200" ]]; then
                error "Failed to download page $page (HTTP $http_code)"
            fi
        fi
        
        # Count panels in this page
        local page_count=$(jq -r '.results | length' "$output" 2>/dev/null || echo "0")
        [[ "$page_count" == "0" ]] && break
        
        total_panels=$((total_panels + page_count))
        log "Page $page: $page_count panels (total: $total_panels)"
        
        # Get next page URL from API response
        next_url=$(jq -r '.next // empty' "$output" 2>/dev/null || true)
        [[ -z "$next_url" ]] && break
        ((page++))
    done
    
    log "Downloaded $total_panels panels across $page pages"
}

# Convert JSON to TSV
convert_to_tsv() {
    local panels_dir="$OUTPUT_DIR/panels"
    local json_dir="$panels_dir/json"
    local panel_list_dir="$OUTPUT_DIR/panel_list"
    local output_file="$panel_list_dir/panel_list.tsv"
    
    log "Creating panel list directory"
    mkdir -p "$panel_list_dir"
    
    log "Converting JSON to TSV..."
    
    # Create TSV header
    echo -e "id\tname\tversion\tversion_created" > "$output_file"
    
    # Process all JSON files
    local json_files=($(find "$json_dir" -name "*.json" | sort))
    local total_rows=0
    
    for json_file in "${json_files[@]}"; do
        # Extract panel data using jq
        jq -r '.results[] | [.id, .name, .version, .version_created] | @tsv' "$json_file" >> "$output_file"
        local file_rows=$(jq -r '.results | length' "$json_file")
        total_rows=$((total_rows + file_rows))
    done
    
    log "Created TSV with $total_rows panels: $output_file"
    
    # Create version file
    date -Iseconds > "$panel_list_dir/version_extracted.txt"
    log "Created version tracking file"
}

# Main execution
main() {
    log "Starting PanelApp Australia panel list extraction..."
    
    # Check dependencies
    command -v curl >/dev/null || error "curl not found"
    command -v jq >/dev/null || error "jq not found"
    
    # Download panels
    download_panels
    
    # Convert to TSV
    convert_to_tsv
    
    log "Panel list extraction completed successfully!"
    log "Output directory: $OUTPUT_DIR"
}

# Run main
main "$@"