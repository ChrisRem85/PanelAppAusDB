#!/bin/bash
# PanelApp Australia Gene Extraction Script - Simplified Version
# Downloads gene data from panels that need updating

set -euo pipefail

# Configuration
BASE_URL="https://panelapp-aus.org/api/v1"
OUTPUT_DIR="./data"
PANEL_ID=""
FORCE=0

# Load API configuration from config file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.sh"

if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
    echo "[INFO] Loaded configuration from: $CONFIG_FILE" >&2
else
    echo "[WARNING] Config file not found: $CONFIG_FILE" >&2
    echo "[WARNING] Please copy config.sh.template to config.sh and add your API token" >&2
    
    # Fallback to default values
    API_TOKEN=""  # No token
    REQUEST_DELAY=1.0
fi

# Simple logging
log() {
    echo "[$(date '+%H:%M:%S')] $1" >&2
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
  --panel-id ID       Specific panel ID only
  --force             Force re-download
  --help              This help
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        --panel-id) PANEL_ID="$2"; shift 2 ;;
        --force) FORCE=1; shift ;;
        --help|-h) usage; exit 0 ;;
        *) error "Unknown option: $1" ;;
    esac
done

# Check if panel needs update
needs_update() {
    local panel_id="$1"
    local current_version="$2"
    local panel_dir="$OUTPUT_DIR/panels/$panel_id"
    
    [[ $FORCE -eq 1 ]] && return 0
    [[ ! -d "$panel_dir/genes/json" ]] && return 0
    [[ ! -f "$panel_dir/genes/version_extracted.txt" ]] && return 0
    [[ ! -f "$panel_dir/version_created.txt" ]] && return 0
    
    local last_version=$(cat "$panel_dir/version_created.txt" 2>/dev/null || echo "")
    [[ "$current_version" > "$last_version" ]] && return 0

    log "Genes of panel $panel_id already extracted"
    return 1
}

# Download panel genes
download_genes() {
    local panel_id="$1"
    local panel_name="$2"
    local version="$3"
    local panel_dir="$OUTPUT_DIR/panels/$panel_id"
    local json_dir="$panel_dir/genes/json"
    
    log "Downloading genes for panel $panel_id"
    
    # Create directories
    mkdir -p "$json_dir"
    rm -f "$json_dir"/*.json 2>/dev/null || true
    
    # Download pages
    local page=1
    while true; do
        local url="$BASE_URL/panels/$panel_id/genes/?page=$page"
        local output="$json_dir/genes_page_$page.json"
        
        # Add delay to reduce API load (skip for first page)
        if [[ $page -gt 1 ]]; then
            sleep "$REQUEST_DELAY"
        fi
        
        if [[ -n "$API_TOKEN" ]]; then
            if ! curl -s -f -H "Authorization: $API_TOKEN" "$url" -o "$output"; then
                error "Failed to download page $page for panel $panel_id"
            fi
        else
            if ! curl -s -f "$url" -o "$output"; then
                error "Failed to download page $page for panel $panel_id"
            fi
        fi
        
        # Check if more pages exist
        local next_page=$(jq -r '.next // empty' "$output" 2>/dev/null || true)
        [[ -z "$next_page" ]] && break
        ((page++))
    done
    
    # Update version tracking
    echo "$version" > "$panel_dir/version_created.txt"
    date -Iseconds > "$panel_dir/genes/version_extracted.txt"
    
    log "Downloaded $page pages for panel $panel_id"
}

# Main execution
main() {
    local tsv_file="$OUTPUT_DIR/panel_list/panel_list.tsv"
    [[ ! -f "$tsv_file" ]] && error "Panel list not found: $tsv_file"
    
    local panels_to_update=()
    local total=0

    # Extract specific panel or all panels
    if [[ -n "$PANEL_ID" ]]; then
        # Single panel mode
        local panel_data=$(grep "^$PANEL_ID"$'\t' "$tsv_file" || true)
        [[ -z "$panel_data" ]] && error "Panel $PANEL_ID not found"
        
        IFS=$'\t' read -r id name version created <<< "$panel_data"
        if needs_update "$id" "$created"; then
            download_genes "$id" "$name" "$created"
            echo "✓ Panel $id processed"
        else
            echo "Panel $id up to date"
        fi
        return
    fi
    
    # All panels mode - collect panels needing updates
    while read -r line; do
        [[ "$line" == id* ]] && continue  # Skip header
        
        # Parse TSV line manually
        id=$(echo "$line" | cut -f1)
        name=$(echo "$line" | cut -f2)
        version=$(echo "$line" | cut -f3)
        created=$(echo "$line" | cut -f4)
        
        [[ ! "$id" =~ ^[0-9]+$ ]] && continue  # Numeric IDs only
        
        total=$((total + 1))
        needs_update "$id" "$created" && panels_to_update+=("$id|$name|$created") || true
    done < "$tsv_file"
    
    echo "Found ${#panels_to_update[@]} panels to update (of $total total)"
    
    # Download updates
    local count=0
    for panel_data in "${panels_to_update[@]}"; do
        IFS='|' read -r id name created <<< "$panel_data"
        count=$((count + 1))
        echo "[$count/${#panels_to_update[@]}] Extracting genes for panel $id"
        
        if download_genes "$id" "$name" "$created"; then
            echo "  ✓ Success"
        else
            echo "  ✗ Failed"
        fi
    done
    
    echo "Completed: Genes for $count panels extracted"
}

# Check dependencies
command -v curl >/dev/null || error "curl not found"
command -v jq >/dev/null || error "jq not found"

# Run main
main "$@"