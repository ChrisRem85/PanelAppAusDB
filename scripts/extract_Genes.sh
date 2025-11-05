#!/bin/bash
# PanelApp Australia Gene Extraction Script - Simplified Version
# Downloads gene data from panels that need updating

set -euo pipefail

# Configuration
BASE_URL="https://panelapp-aus.org/api/v1"
DATA_PATH="./data"
PANEL_ID=""
VERBOSE=0
FORCE=0
RETRY_ATTEMPTS=3

# Simple logging
log() {
    [[ $VERBOSE -eq 1 ]] && echo "[$(date '+%H:%M:%S')] $1" >&2
}

error() {
    echo "[ERROR] $1" >&2
    exit 1
}

# Usage
usage() {
    cat << EOF
Usage: $0 [OPTIONS]
  --data-path PATH    Data directory (default: ./data)
  --panel-id ID       Specific panel ID only
  --force             Force re-download
  --verbose           Verbose output
  --retries N         Retry attempts (default: 3)
  --help              This help
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --data-path) DATA_PATH="$2"; shift 2 ;;
        --panel-id) PANEL_ID="$2"; shift 2 ;;
        --force) FORCE=1; shift ;;
        --verbose) VERBOSE=1; shift ;;
        --retries) RETRY_ATTEMPTS="$2"; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) error "Unknown option: $1" ;;
    esac
done

# Retry with backoff
retry() {
    local cmd=("$@")
    for i in $(seq 1 $RETRY_ATTEMPTS); do
        if "${cmd[@]}"; then return 0; fi
        [[ $i -eq $RETRY_ATTEMPTS ]] && return 1
        log "Retry $i failed, waiting..."
        sleep $((i * 2))
    done
}

# Check if panel needs update
needs_update() {
    local panel_id="$1"
    local current_version="$2"
    local panel_dir="$DATA_PATH/panels/$panel_id"
    
    [[ $FORCE -eq 1 ]] && return 0
    [[ ! -d "$panel_dir/genes/json" ]] && return 0
    [[ ! -f "$panel_dir/genes/version_extracted.txt" ]] && return 0
    [[ ! -f "$panel_dir/version_created.txt" ]] && return 0
    
    local last_version=$(cat "$panel_dir/version_created.txt" 2>/dev/null || echo "")
    [[ "$current_version" > "$last_version" ]] && return 0
    
    log "Panel $panel_id up to date"
    return 1
}

# Download panel genes
download_genes() {
    local panel_id="$1"
    local panel_name="$2"
    local version="$3"
    local panel_dir="$DATA_PATH/panels/$panel_id"
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
        
        if ! retry curl -s -f "$url" -o "$output"; then
            error "Failed to download page $page for panel $panel_id"
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
    local tsv_file="$DATA_PATH/panel_list/panel_list.tsv"
    [[ ! -f "$tsv_file" ]] && error "Panel list not found: $tsv_file"
    
    local panels_to_update=()
    local total=0
    
    # Process specific panel or all panels
    if [[ -n "$PANEL_ID" ]]; then
        # Single panel mode
        local panel_data=$(grep "^$PANEL_ID[[:space:]]" "$tsv_file" || true)
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
    while IFS=$'\t' read -r id name version created || [[ -n "$id" ]]; do
        [[ "$id" == "id" ]] && continue  # Skip header
        [[ ! "$id" =~ ^[0-9]+$ ]] && continue  # Numeric IDs only
        
        ((total++))
        if needs_update "$id" "$created"; then
            panels_to_update+=("$id|$name|$created")
        fi
    done < "$tsv_file"
    
    echo "Found ${#panels_to_update[@]} panels to update (of $total total)"
    
    # Download updates
    local count=0
    for panel_data in "${panels_to_update[@]}"; do
        IFS='|' read -r id name created <<< "$panel_data"
        ((count++))
        echo "[$count/${#panels_to_update[@]}] Processing panel $id"
        
        if download_genes "$id" "$name" "$created"; then
            echo "  ✓ Success"
        else
            echo "  ✗ Failed"
        fi
    done
    
    echo "Completed: $count panels processed"
}

# Check dependencies
command -v curl >/dev/null || error "curl not found"
command -v jq >/dev/null || error "jq not found"

# Run main
main "$@"