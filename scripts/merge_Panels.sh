#!/bin/bash

# PanelApp Australia Merge Script - Simplified
set -euo pipefail

DATA_PATH="data"
ENTITY_TYPE=""
FORCE=0
VERBOSE=0

error_exit() { echo "ERROR: $1" >&2; exit 1; }
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1"; }
log_verbose() { [[ $VERBOSE -eq 1 ]] && log "VERBOSE: $1"; }

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --data-path) DATA_PATH="$2"; shift 2 ;;
        --entity-type) ENTITY_TYPE="$2"; shift 2 ;;
        --force) FORCE=1; shift ;;
        --verbose) VERBOSE=1; shift ;;
        --help|-h) echo "Usage: merge_panels.sh [--data-path PATH] [--entity-type TYPE] [--force] [--verbose]"; exit 0 ;;
        *) error_exit "Unknown option: $1" ;;
    esac
done

# Check if merge needed
merge_needed() {
    local data_path="$1" entity_type="$2"
    [[ $FORCE -eq 1 ]] && return 0
    
    local merged_file="$data_path/$entity_type/$entity_type.tsv"
    local version_file="$data_path/$entity_type/version_merged.txt"
    
    [[ ! -f "$merged_file" || ! -f "$version_file" ]] && return 0
    
    local last_merged
    last_merged=$(head -n1 "$version_file" 2>/dev/null) || return 0
    [[ -z "$last_merged" ]] && return 0
    
    local last_merged_ts
    last_merged_ts=$(date -d "$last_merged" +%s 2>/dev/null) || return 0
    
    for panel_dir in "$data_path/panels"/*/; do
        [[ ! -d "$panel_dir" ]] && continue
        local panel_id
        panel_id=$(basename "$panel_dir")
        [[ ! "$panel_id" =~ ^[0-9]+$ ]] && continue
        
        local processed_file="$panel_dir/$entity_type/version_processed.txt"
        [[ ! -f "$processed_file" ]] && continue
        
        local processed_date
        processed_date=$(head -n1 "$processed_file" 2>/dev/null) || continue
        [[ -z "$processed_date" ]] && continue
        
        local processed_ts
        processed_ts=$(date -d "$processed_date" +%s 2>/dev/null) || continue
        
        if [[ $processed_ts -gt $last_merged_ts ]]; then
            log_verbose "$entity_type merge needed: Panel $panel_id updated"
            return 0
        fi
    done
    
    log_verbose "$entity_type is up to date"
    return 1
}

# Merge entity data
merge_entity_data() {
    local data_path="$1" entity_type="$2"
    log "Merging $entity_type data..."
    
    local panels_dir="$data_path/panels"
    local merged_dir="$data_path/$entity_type"
    local merged_file="$merged_dir/$entity_type.tsv"
    local version_file="$merged_dir/version_merged.txt"
    
    mkdir -p "$merged_dir"
    
    # Find TSV files
    local tsv_files=()
    local panel_ids=()
    for panel_dir in "$panels_dir"/*/; do
        [[ ! -d "$panel_dir" ]] && continue
        local panel_id
        panel_id=$(basename "$panel_dir")
        [[ ! "$panel_id" =~ ^[0-9]+$ ]] && continue
        
        local tsv_path="$panel_dir/$entity_type/${panel_id}.${entity_type}.tsv"
        if [[ -f "$tsv_path" && -s "$tsv_path" ]]; then
            tsv_files+=("$tsv_path")
            panel_ids+=("$panel_id")
            log_verbose "Found $entity_type file for panel $panel_id"
        fi
    done
    
    if [[ ${#tsv_files[@]} -eq 0 ]]; then
        log "WARNING: No $entity_type files found"
        return 1
    fi
    
    log "Found ${#tsv_files[@]} $entity_type files to merge"
    
    local temp_file
    temp_file=$(mktemp)
    local header_written=0
    local row_count=0
    local expected_header=""
    
    for i in "${!tsv_files[@]}"; do
        local panel_id="${panel_ids[$i]}"
        local file_path="${tsv_files[$i]}"
        log_verbose "Processing panel $panel_id"
        
        local line_number=0
        while IFS= read -r line; do
            line_number=$((line_number + 1))
            
            if [[ $line_number -eq 1 ]]; then
                if [[ $header_written -eq 0 ]]; then
                    expected_header="$line"
                    echo -e "panel_id\t$line" >> "$temp_file"
                    header_written=1
                    log_verbose "Header established from panel $panel_id"
                else
                    local header
                    header=$(head -n1 "$file_path")
                    if [[ "$header" != "$expected_header" ]]; then
                        log "WARNING: Column mismatch in panel $panel_id, skipping"
                        continue 2
                    fi
                fi
            else
                if [[ -n "${line// }" ]]; then
                    echo -e "$panel_id\t$line" >> "$temp_file"
                    row_count=$((row_count + 1))
                fi
            fi
        done < "$file_path"
    done
    
    if [[ $row_count -eq 0 ]]; then
        log "WARNING: No data rows found"
        rm -f "$temp_file"
        return 1
    fi
    
    if mv "$temp_file" "$merged_file"; then
        log "Created merged file: $merged_file with $row_count data rows"
    else
        error_exit "Failed to create merged file"
    fi
    
    date -u '+%Y-%m-%dT%H:%M:%S.%6NZ' > "$version_file"
    log "Created version file: $version_file"
}

# Main execution
main() {
    log "Starting PanelApp Australia panel data merger"
    [[ ! -d "$DATA_PATH" ]] && error_exit "Data path not found: $DATA_PATH"
    
    DATA_PATH=$(realpath "$DATA_PATH")
    log "Using data path: $DATA_PATH"
    
    local entity_types
    if [[ -n "$ENTITY_TYPE" ]]; then
        entity_types=("$ENTITY_TYPE")
    else
        entity_types=("genes")
    fi
    
    local success=1
    for entity_type in "${entity_types[@]}"; do
        if merge_needed "$DATA_PATH" "$entity_type"; then
            if ! merge_entity_data "$DATA_PATH" "$entity_type"; then
                log "WARNING: $entity_type merge failed"
                success=0
            fi
        else
            log "$entity_type data is up to date"
        fi
    done
    
    if [[ $success -eq 1 ]]; then
        log "Panel data merger completed successfully"
    else
        log "Panel data merger completed with warnings"
    fi
}

main "$@"