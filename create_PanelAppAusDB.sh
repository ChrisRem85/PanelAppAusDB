#!/bin/bash
# PanelApp Australia Complete Data Extraction - Simplified Wrapper
# Orchestrates: panel list → gene extraction → processing → merging → genelists

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_PATH="./data"
PANEL_ID=""
SKIP_GENES=0
SKIP_STRS=0
SKIP_REGIONS=0
FORCE=0
VERBOSE=0
CREATE_SOMATIC_GENELISTS=0
RETRY_ATTEMPTS=""

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

Orchestrates complete PanelApp Australia data extraction process.

OPTIONS:
  --data-path PATH      Data directory (default: ./data)
  --panel-id ID         Extract specific panel only
  --skip-genes          Skip gene data extraction
  --skip-strs           Skip STR data extraction  
  --skip-regions        Skip region data extraction
  --force               Force re-download all data
  --verbose             Verbose output
  --create-somatic-genelists  Create somatic genelists too
  --retries N           API retry attempts (default: 3)
  --help                This help

EXAMPLES:
  $0                                    # Full extraction
  $0 --create-somatic-genelists         # Full + somatic genelists
  $0 --panel-id 6                       # Single panel
  $0 --force --verbose                  # Force with verbose output
EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --data-path) DATA_PATH="$2"; shift 2 ;;
        --panel-id) PANEL_ID="$2"; shift 2 ;;
        --skip-genes) SKIP_GENES=1; shift ;;
        --skip-strs) SKIP_STRS=1; shift ;;
        --skip-regions) SKIP_REGIONS=1; shift ;;
        --force) FORCE=1; shift ;;
        --verbose) VERBOSE=1; shift ;;
        --create-somatic-genelists) CREATE_SOMATIC_GENELISTS=1; shift ;;
        --retries) RETRY_ATTEMPTS="$2"; shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) error "Unknown option: $1" ;;
    esac
done

# Run script with error handling
run_script() {
    local script="$1"
    local name="$2"
    local optional="${3:-false}"
    shift 3
    local args=("$@")
    
    if [[ ! -f "$script" ]]; then
        if [[ "$optional" == "true" ]]; then
            log "$name not found (optional - skipping)"
            return 0
        else
            error "$name not found: $script"
        fi
    fi
    
    log "Running $name..."
    if bash "$script" "${args[@]}"; then
        log "✓ $name completed"
        return 0
    else
        log "✗ $name failed"
        return 1
    fi
}

# Build common arguments
build_args() {
    local args=("--data-path" "$DATA_PATH")
    [[ $FORCE -eq 1 ]] && args+=("--force")
    [[ $VERBOSE -eq 1 ]] && args+=("--verbose")
    [[ -n "$PANEL_ID" ]] && args+=("--panel-id" "$PANEL_ID")
    [[ -n "$RETRY_ATTEMPTS" ]] && args+=("--retries" "$RETRY_ATTEMPTS")
    echo "${args[@]}"
}

# Main execution
main() {
    log "Starting PanelApp Australia data extraction..."
    
    local success=true
    local common_args=($(build_args))
    
    # Step 1: Extract panel list
    if ! run_script "$SCRIPT_DIR/scripts/extract_PanelList.sh" "Panel List Extraction" false "${common_args[@]}"; then
        error "Panel list extraction failed - cannot continue"
    fi
    
    # Step 2: Gene extraction pipeline
    if [[ $SKIP_GENES -eq 0 ]]; then
        # 2a: Extract genes
        if ! run_script "$SCRIPT_DIR/scripts/extract_Genes.sh" "Gene Extraction" false "${common_args[@]}"; then
            log "Gene extraction failed, continuing..."
            success=false
        fi
        
        # 2b: Process genes (JSON → TSV)
        if ! run_script "$SCRIPT_DIR/scripts/process_Genes.sh" "Gene Processing" false "${common_args[@]}"; then
            log "Gene processing failed, continuing..."
            success=false
        fi
        
        # 2c: Merge panels
        if ! run_script "$SCRIPT_DIR/scripts/merge_Panels.sh" "Panel Merging" false "${common_args[@]}"; then
            log "Panel merging failed, continuing..."
            success=false
        fi
        
        # 2d: Create genelists (if genes.tsv exists)
        if [[ -f "$DATA_PATH/genes/genes.tsv" ]]; then
            if ! run_script "$SCRIPT_DIR/scripts/create_Genelists.sh" "Genelist Creation" false "${common_args[@]}"; then
                log "Genelist creation failed, continuing..."
                success=false
            fi
            
            # 2e: Create somatic genelists (optional)
            if [[ $CREATE_SOMATIC_GENELISTS -eq 1 ]]; then
                if ! run_script "$SCRIPT_DIR/scripts/create_Somatic_genelists.sh" "Somatic Genelist Creation" false "${common_args[@]}"; then
                    log "Somatic genelist creation failed, continuing..."
                    success=false
                fi
            fi
        else
            log "No genes.tsv found, skipping genelist creation"
            success=false
        fi
    else
        log "Skipping gene extraction pipeline"
    fi
    
    # Step 3: STR extraction (future)
    if [[ $SKIP_STRS -eq 0 ]]; then
        run_script "$SCRIPT_DIR/scripts/extract_strs.sh" "STR Extraction" true "${common_args[@]}" || true
    fi
    
    # Step 4: Region extraction (future)  
    if [[ $SKIP_REGIONS -eq 0 ]]; then
        run_script "$SCRIPT_DIR/scripts/extract_regions.sh" "Region Extraction" true "${common_args[@]}" || true
    fi
    
    # Summary
    log "Data extraction completed $(if [[ "$success" == "true" ]]; then echo "successfully"; else echo "with warnings"; fi)"
    log "Output directory: $DATA_PATH"
    
    # Status summary
    echo ""
    log "Extraction Summary:"
    log "  Panel list: ✓ Completed"
    log "  Genes: $(if [[ $SKIP_GENES -eq 1 ]]; then echo "Skipped"; else echo "Attempted"; fi)"
    log "  STRs: $(if [[ $SKIP_STRS -eq 1 ]]; then echo "Skipped"; else echo "Future"; fi)"
    log "  Regions: $(if [[ $SKIP_REGIONS -eq 1 ]]; then echo "Skipped"; else echo "Future"; fi)"
    log "  Somatic lists: $(if [[ $CREATE_SOMATIC_GENELISTS -eq 1 ]]; then echo "Attempted"; else echo "Skipped"; fi)"
}

# Validate required script exists
[[ -f "$SCRIPT_DIR/scripts/extract_PanelList.sh" ]] || error "Required script extract_PanelList.sh not found"

# Run main
main "$@"