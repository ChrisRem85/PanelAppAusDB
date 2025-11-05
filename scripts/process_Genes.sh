#!/bin/bash
# PanelApp Australia Gene Processing - Simplified Version
# Converts downloaded gene JSON files to TSV format

set -euo pipefail

# Configuration
DATA_PATH="./data"
PANEL_ID=""
VERBOSE=0
FORCE=0

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
  --panel-id ID       Process specific panel only
  --force             Force reprocessing
  --verbose           Verbose output
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
        --help|-h) usage; exit 0 ;;
        *) error "Unknown option: $1" ;;
    esac
done

# Check if panel needs processing
needs_processing() {
    local panel_id="$1"
    local panel_dir="$DATA_PATH/panels/$panel_id"
    local genes_dir="$panel_dir/genes"
    local tsv_file="$genes_dir/${panel_id}.genes.tsv"
    
    [[ $FORCE -eq 1 ]] && return 0
    [[ ! -f "$tsv_file" ]] && return 0
    [[ ! -f "$genes_dir/version_processed.txt" ]] && return 0
    
    # Check if JSON is newer than TSV
    local json_dir="$genes_dir/json"
    [[ -d "$json_dir" ]] || return 1
    
    local newest_json=$(find "$json_dir" -name "*.json" -type f -printf '%T@\n' | sort -n | tail -1)
    local tsv_time=$(stat -c '%Y' "$tsv_file" 2>/dev/null || echo "0")
    
    [[ "${newest_json%.*}" > "$tsv_time" ]] && return 0
    
    log "Panel $panel_id already processed"
    return 1
}

# Process panel genes
process_panel() {
    local panel_id="$1"
    local panel_dir="$DATA_PATH/panels/$panel_id"
    local genes_dir="$panel_dir/genes"
    local json_dir="$genes_dir/json"
    local output_file="$genes_dir/${panel_id}.genes.tsv"
    
    log "Processing panel $panel_id"
    
    # Check for JSON files
    local json_files=($(find "$json_dir" -name "*.json" 2>/dev/null | sort))
    [[ ${#json_files[@]} -eq 0 ]] && { log "No JSON files for panel $panel_id"; return 1; }
    
    log "Processing ${#json_files[@]} JSON files"
    
    # Create temporary file
    local temp_file=$(mktemp)
    
    # Write header
    echo -e "hgnc_symbol\tensembl_id\tconfidence_level\tpenetrance\tmode_of_pathogenicity\tpublications\tmode_of_inheritance\ttags" > "$temp_file"
    
    # Process each JSON file
    local gene_count=0
    for json_file in "${json_files[@]}"; do
        jq -r '
            .results[]? | 
            [
                (.gene_data.hgnc_symbol // ""),
                (
                    if .gene_data.ensembl_genes.GRch38 then
                        (.gene_data.ensembl_genes.GRch38 | to_entries[0].value.ensembl_id // "")
                    else
                        ""
                    end
                ),
                (.confidence_level // ""),
                (.penetrance // ""),
                (.mode_of_pathogenicity // ""),
                (
                    if .publications and (.publications | length > 0) then
                        (.publications | join(","))
                    else
                        ""
                    end
                ),
                (.mode_of_inheritance // ""),
                (
                    if .tags and (.tags | length > 0) then
                        (.tags | join(","))
                    else
                        ""
                    end
                )
            ] | @tsv
        ' "$json_file" 2>/dev/null >> "$temp_file" || {
            log "Error processing $json_file"
            continue
        }
        
        local file_genes=$(jq -r '.results | length' "$json_file" 2>/dev/null || echo "0")
        gene_count=$((gene_count + file_genes))
    done
    
    # Move to final location
    mkdir -p "$genes_dir"
    mv "$temp_file" "$output_file"
    
    # Create version file
    date -Iseconds > "$genes_dir/version_processed.txt"
    
    log "Processed $gene_count genes for panel $panel_id -> $output_file"
}

# Main execution
main() {
    # Check dependencies
    command -v jq >/dev/null || error "jq not found"
    
    local panels_to_process=()
    local successful=0
    local skipped=0
    local failed=0
    
    # Determine panels to process
    if [[ -n "$PANEL_ID" ]]; then
        # Single panel mode
        local panel_dir="$DATA_PATH/panels/$PANEL_ID"
        [[ ! -d "$panel_dir" ]] && error "Panel $PANEL_ID not found"
        
        if needs_processing "$PANEL_ID"; then
            if process_panel "$PANEL_ID"; then
                echo "✓ Panel $PANEL_ID processed"
                ((successful++))
            else
                echo "✗ Panel $PANEL_ID failed"
                ((failed++))
            fi
        else
            echo "Panel $PANEL_ID up to date"
            ((skipped++))
        fi
    else
        # All panels mode
        local panels_dir="$DATA_PATH/panels"
        [[ ! -d "$panels_dir" ]] && error "Panels directory not found: $panels_dir"
        
        # Find panel directories
        for panel_dir in "$panels_dir"/*/; do
            [[ ! -d "$panel_dir" ]] && continue
            local panel_id=$(basename "$panel_dir")
            [[ ! "$panel_id" =~ ^[0-9]+$ ]] && continue
            
            if needs_processing "$panel_id"; then
                panels_to_process+=("$panel_id")
            else
                ((skipped++))
            fi
        done
        
        echo "Found ${#panels_to_process[@]} panels to process"
        
        # Process panels
        for panel_id in "${panels_to_process[@]}"; do
            if process_panel "$panel_id"; then
                ((successful++))
                echo "  ✓ Panel $panel_id"
            else
                ((failed++))
                echo "  ✗ Panel $panel_id"
            fi
        done
    fi
    
    echo "Gene processing completed: $successful successful, $skipped skipped, $failed failed"
}

# Run main
main "$@"