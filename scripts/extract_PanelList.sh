#!/bin/bash

# PanelApp Australia Data Extraction Script
# This script extracts panel data from the PanelApp Australia API
# Creates a folder for the current date and downloads all panels with pagination
# All output files use Unix newlines (LF) for cross-platform compatibility

set -euo pipefail  # Exit on error, undefined variables, and pipe failures

# Configuration
BASE_URL="https://panelapp-aus.org/api"
API_VERSION="v1"
SWAGGER_URL="https://panelapp-aus.org/api/docs/?format=openapi"
EXPECTED_API_VERSION="v1"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
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

# Clear JSON directory to prevent inconsistencies from old files
clear_json_directory() {
    local json_path="$1"
    
    if [ -d "$json_path" ]; then
        log "Clearing existing JSON files from: $json_path"
        local json_files=($(find "$json_path" -name "*.json" 2>/dev/null))
        if [ ${#json_files[@]} -gt 0 ]; then
            rm -f "$json_path"/*.json 2>/dev/null || true
            success "Removed ${#json_files[@]} existing JSON files"
        else
            log "No existing JSON files found to clear"
        fi
    else
        log "JSON directory does not exist yet: $json_path"
    fi
}

# Check if required commands are available
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

# Create output folder structure
create_output_folder() {
    local base_dir="../data"
    
    log "Setting up output folder: $base_dir"
    
    if [ ! -d "$base_dir" ]; then
        mkdir -p "$base_dir"
    fi
    
    if [ ! -d "$base_dir/panel_list/json" ]; then
        mkdir -p "$base_dir/panel_list/json"
        success "Created folder structure: $base_dir/panel_list/json"
    else
        log "Using existing folder structure: $base_dir/panel_list/json"
    fi
    
    # Clear any existing JSON files to prevent inconsistencies
    clear_json_directory "$base_dir/panel_list/json"
    
    echo "$base_dir"
}

# Check API version
check_api_version() {
    log "Checking API version..."
    
    local swagger_response
    swagger_response=$(curl -s "$SWAGGER_URL" || {
        error "Failed to fetch swagger documentation"
        exit 1
    })
    
    # Extract version from swagger JSON
    local api_version
    api_version=$(echo "$swagger_response" | jq -r '.info.version // empty' 2>/dev/null || echo "")
    
    if [ -z "$api_version" ]; then
        error "Could not determine API version from swagger documentation"
        exit 1
    fi
    
    log "Current API version: $api_version"
    
    if [ "$api_version" != "$EXPECTED_API_VERSION" ]; then
        warning "API version mismatch! Expected: $EXPECTED_API_VERSION, Found: $api_version"
        warning "Continuing with execution, but results may vary..."
    else
        success "API version matches expected version: $EXPECTED_API_VERSION"
    fi
}

# Download panels with pagination
download_panels() {
    local output_dir="$1"
    local panel_url="$BASE_URL/$API_VERSION/panels/"
    local page=1
    local next_url="$panel_url"
    
    log "Starting panel data extraction..."
    
    while [ -n "$next_url" ] && [ "$next_url" != "null" ]; do
        log "Downloading page $page..."
        
        local response_file="$output_dir/panel_list/json/panels_page_${page}.json"
        
        # Download the page
        local http_code
        http_code=$(curl -s -w "%{http_code}" -o "$response_file" "$next_url")
        
        if [ "$http_code" != "200" ]; then
            error "HTTP $http_code error downloading page $page from: $next_url"
            rm -f "$response_file"
            exit 1
        fi
        
        # Validate JSON
        if ! jq empty "$response_file" 2>/dev/null; then
            error "Invalid JSON received for page $page"
            rm -f "$response_file"
            exit 1
        fi
        
        # Get the count and next URL
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
        
        success "Page $page downloaded: $results_count panels (Total in API: $count)"
        
        ((page++))
        
        # Safety check to prevent infinite loops
        if [ $page -gt 1000 ]; then
            error "Safety limit reached (1000 pages). Stopping to prevent infinite loop."
            break
        fi
    done
    
    success "Panel data extraction completed. Downloaded $((page-1)) pages."
}

# Extract panel information from JSON files and save version tracking
extract_panel_info() {
    local output_dir="$1"
    local json_dir="$output_dir/panel_list/json"
    local tsv_file="$output_dir/panel_list/panel_list.tsv"
    
    log "Extracting panel information from JSON files..."
    
    # Create TSV header
    echo -e "id\tname\tversion\tversion_created\tnumber_of_genes\tnumber_of_strs\tnumber_of_regions" > "$tsv_file"
    
    # Process all JSON files
    local file_count=0
    local panel_count=0
    
    for json_file in "$json_dir"/panels_page_*.json; do
        if [ -f "$json_file" ]; then
            ((file_count++))
            
            # Extract panel information using jq (TSV format without quotes)
            jq -r '.results[]? | [.id, .name, .version, .version_created, .stats.number_of_genes, .stats.number_of_strs, .stats.number_of_regions] | @tsv' "$json_file" >> "$tsv_file"
            
            # Create individual panel directories and save version tracking
            jq -r '.results[]? | "\(.id)\t\(.version_created)"' "$json_file" | while IFS=$'\t' read -r panel_id version_created; do
                if [ -n "$panel_id" ] && [ -n "$version_created" ]; then
                    local panel_dir="$output_dir/panels/$panel_id"
                    mkdir -p "$panel_dir"
                    
                    local version_file="$panel_dir/version_created.txt"
                    echo -n "$version_created" > "$version_file"
                    
                    log "  Created version tracking for panel $panel_id: $version_created"
                fi
            done
            
            local current_panels
            current_panels=$(jq '.results | length' "$json_file")
            panel_count=$((panel_count + current_panels))
        fi
    done
    
    success "Extracted information from $file_count files containing $panel_count panels"
    success "Summary saved to: $tsv_file"
    success "Version tracking files saved in individual panel directories"
    
    # Display first few lines of the summary
    if [ -f "$tsv_file" ]; then
        log "First 5 entries in summary:"
        head -6 "$tsv_file" | while IFS= read -r line; do
            echo "  $line"
        done
    fi
}

# Main execution
main() {
    log "Starting PanelApp Australia data extraction..."
    
    # Check dependencies
    check_dependencies
    
    # Create output folder structure
    local output_dir
    output_dir=$(create_output_folder)
    
    # Check API version
    check_api_version
    
    # Download panels
    download_panels "$output_dir"
    
    # Extract panel information
    extract_panel_info "$output_dir"
    
    success "Data extraction completed successfully!"
    log "Output directory: $output_dir"
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi