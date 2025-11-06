#!/bin/bash

# PanelApp Australia Gene to Genelists Converter - Simplified
set -euo pipefail

OUTPUT_DIR="data"
FORCE=0

error_exit() { echo "ERROR: $1" >&2; exit 1; }
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $1"; }

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --output-dir) OUTPUT_DIR="$2"; shift 2 ;;
        --force) FORCE=1; shift ;;
        --help|-h) echo "Usage: create_Genelists.sh [--output-dir PATH] [--force]"; exit 0 ;;
        *) error_exit "Unknown option: $1" ;;
    esac
done

# Check if regeneration needed
needs_update() {
    local genes_file="$1" output_file="$2" version_file="$3"
    
    [[ $FORCE -eq 1 ]] && return 0
    [[ ! -f "$output_file" ]] && return 0
    
    if [[ -f "$version_file" ]]; then
        local version_date
        version_date=$(head -n1 "$version_file" 2>/dev/null) || return 0
        [[ -z "$version_date" ]] && return 0
        
        local version_ts
        version_ts=$(date -d "$version_date" +%s 2>/dev/null) || return 0
        
        local output_ts
        output_ts=$(stat -c %Y "$output_file" 2>/dev/null || stat -f %m "$output_file" 2>/dev/null || echo 0)
        
        [[ $version_ts -gt $output_ts ]] && return 0
    fi
    
    return 1
}

# Create genelist files
create_genelist_files() {
    local genes_file="$1" output_dir="$2" version_file="$3"
    
    log "Reading genes data from: $genes_file"
    
    [[ ! -f "$genes_file" ]] && error_exit "Genes file not found: $genes_file"
    
    # Count total genes
    local total_genes
    total_genes=$(tail -n +2 "$genes_file" | wc -l)
    log "Loaded $total_genes gene entries"
    
    mkdir -p "$output_dir"
    
    # Define output files
    local green_file="$output_dir/genes_to_genelists.PanelAppAustralia_Green.txt"
    local amber_file="$output_dir/genes_to_genelists.PanelAppAustralia_Amber.txt"
    local simple_file="$output_dir/genelist.PanelAppAustralia_GreenAmber.txt"
    
    # Process Green genes (confidence_level = 3)
    if needs_update "$genes_file" "$green_file" "$version_file"; then
        log "Processing Green genes (confidence_level = 3)"
        awk -F'\t' 'NR > 1 && $4 == "3" && $3 != "" {
            print $3 "\t" "Paus:" $1 ".Green"
        }' "$genes_file" | sort -t$'\t' -k1,1 -k2,2 > "$green_file"
        
        local green_count
        green_count=$(wc -l < "$green_file")
        [[ $green_count -eq 0 ]] && error_exit "No Green genes found"
        log "Created Green genelist: $green_file ($green_count entries)"
    else
        log "Green genelist is up to date: $(basename "$green_file")"
    fi
    
    # Process Amber genes (confidence_level = 2)
    if needs_update "$genes_file" "$amber_file" "$version_file"; then
        log "Processing Amber genes (confidence_level = 2)"
        awk -F'\t' 'NR > 1 && $4 == "2" && $3 != "" {
            print $3 "\t" "Paus:" $1 ".Amber"
        }' "$genes_file" | sort -t$'\t' -k1,1 -k2,2 > "$amber_file"
        
        local amber_count
        amber_count=$(wc -l < "$amber_file")
        [[ $amber_count -eq 0 ]] && error_exit "No Amber genes found"
        log "Created Amber genelist: $amber_file ($amber_count entries)"
    else
        log "Amber genelist is up to date: $(basename "$amber_file")"
    fi
    
    # Create simple combined genelist
    local simple_needs_update=0
    if [[ $FORCE -eq 1 || ! -f "$simple_file" ]]; then
        simple_needs_update=1
    elif [[ -f "$green_file" && -f "$amber_file" ]]; then
        local simple_ts
        simple_ts=$(stat -c %Y "$simple_file" 2>/dev/null || stat -f %m "$simple_file" 2>/dev/null || echo 0)
        
        for conf_file in "$green_file" "$amber_file"; do
            local conf_ts
            conf_ts=$(stat -c %Y "$conf_file" 2>/dev/null || stat -f %m "$conf_file" 2>/dev/null || echo 0)
            if [[ $conf_ts -gt $simple_ts ]]; then
                simple_needs_update=1
                break
            fi
        done
    fi
    
    if [[ $simple_needs_update -eq 1 ]]; then
        log "Creating simple combined genelist"
        {
            [[ -f "$green_file" ]] && awk -F'\t' '{print $1}' "$green_file"
            [[ -f "$amber_file" ]] && awk -F'\t' '{print $1}' "$amber_file"
        } | sort -u > "$simple_file"
        
        local simple_count
        simple_count=$(wc -l < "$simple_file")
        log "Created simple genelist: $simple_file ($simple_count unique genes)"
    else
        log "Simple genelist is up to date: $(basename "$simple_file")"
    fi
    
    return 0
}

# Main execution
main() {
    log "PanelApp Australia Gene to Genelists Converter starting"
    
    [[ ! -d "$OUTPUT_DIR" ]] && error_exit "Data directory not found: $OUTPUT_DIR"
    
    # File paths
    local genes_file="$OUTPUT_DIR/genes/genes.tsv"
    local version_file="$OUTPUT_DIR/genes/version_merged.txt"
    local output_dir="$OUTPUT_DIR/genelists"
    
    # Check if any work needed
    if [[ $FORCE -eq 0 ]]; then
        local green_file="$output_dir/genes_to_genelists.PanelAppAustralia_Green.txt"
        local amber_file="$output_dir/genes_to_genelists.PanelAppAustralia_Amber.txt"
        local simple_file="$output_dir/genelist.PanelAppAustralia_GreenAmber.txt"
        
        if ! needs_update "$genes_file" "$green_file" "$version_file" && \
           ! needs_update "$genes_file" "$amber_file" "$version_file" && \
           [[ -f "$simple_file" ]]; then
            log "All genelist files are up to date, use --force to regenerate"
            return 0
        fi
    fi
    
    # Process genes and create genelist files
    if create_genelist_files "$genes_file" "$output_dir" "$version_file"; then
        # Create version file
        local version_genelists="$output_dir/version_genelists.txt"
        date -u '+%Y-%m-%dT%H:%M:%S.%6NZ' > "$version_genelists"
        log "Created version file: $version_genelists"
        log "Genelist creation completed successfully"
    else
        error_exit "Failed to create genelist files"
    fi
}

main "$@"