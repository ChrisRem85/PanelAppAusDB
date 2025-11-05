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

# Retry configuration
RETRY_ATTEMPTS=3           # Number of retry attempts for failed downloads

# Output path configuration
OUTPUT_PATH=""             # Custom output path (optional)

# Logging function
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[ERROR] $1" >&2
}

success() {
    echo "[SUCCESS] $1"
}

warning() {
    echo "[WARNING] $1"
}

# Retry mechanism for API requests
retry_with_backoff() {
    local max_attempts="$1"
    shift 1
    local command=("$@")
    
    local attempt=1
    local delay=5
    
    while [[ $attempt -le $max_attempts ]]; do
        log "Attempt $attempt/$max_attempts for API request"
        
        if "${command[@]}"; then
            return 0
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            error "All $max_attempts attempts failed"
            return 1
        fi
        
        warning "Attempt $attempt failed, retrying in ${delay}s..."
        sleep "$delay"
        
        # Exponential backoff
        delay=$((delay * 2))
        ((attempt++))
    done
}

# Retry mechanism for commands that need to capture output
retry_with_backoff_capture() {
    local max_attempts="$1"
    local output_var="$2"
    shift 2
    local command=("$@")
    
    local attempt=1
    local delay=5
    
    while [[ $attempt -le $max_attempts ]]; do
        log "Attempt $attempt/$max_attempts for API request"
        
        local result
        if result=$("${command[@]}" 2>/dev/null); then
            eval "$output_var=\"\$result\""
            return 0
        fi
        
        if [[ $attempt -eq $max_attempts ]]; then
            error "All $max_attempts attempts failed"
            return 1
        fi
        
        warning "Attempt $attempt failed, retrying in ${delay}s..."
        sleep "$delay"
        
        # Exponential backoff
        delay=$((delay * 2))
        ((attempt++))
    done
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
    # Check if custom output path is provided
    if [[ -n "$OUTPUT_PATH" ]]; then
        local base_dir="$OUTPUT_PATH"
        log "Using custom output folder: $base_dir" >&2
    else
        # Get the directory where this script is located
        local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        # Go up one level to the project root and then to data
        local base_dir="$(dirname "$script_dir")/data"
        log "Setting up output folder: $base_dir" >&2
    fi
    
    if [ ! -d "$base_dir" ]; then
        mkdir -p "$base_dir"
    fi
    
    if [ ! -d "$base_dir/panel_list/json" ]; then
        mkdir -p "$base_dir/panel_list/json"
        success "Created folder structure: $base_dir/panel_list/json" >&2
    else
        log "Using existing folder structure: $base_dir/panel_list/json" >&2
    fi
    
    # Clear any existing JSON files to prevent inconsistencies
    clear_json_directory "$base_dir/panel_list/json" >&2
    
    echo "$base_dir"
}

# Check API version
check_api_version() {
    log "Checking API version..."
    
    # Use retry mechanism for API version check
    local swagger_response
    if ! retry_with_backoff_capture "$RETRY_ATTEMPTS" swagger_response curl -s "$SWAGGER_URL"; then
        error "Failed to fetch swagger documentation after $RETRY_ATTEMPTS attempts"
        exit 1
    fi
    
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
        
        # Ensure directory exists
        mkdir -p "$(dirname "$response_file")"
        
        # Download the page with timeout and retry mechanism
        local temp_file=$(mktemp)
        
        # Use retry mechanism for the download
        if ! retry_with_backoff "$RETRY_ATTEMPTS" timeout 30 curl -s -f -o "$response_file" "$next_url" 2>"$temp_file"; then
            error "Failed to download page $page after $RETRY_ATTEMPTS attempts from: $next_url"
            cat "$temp_file" >&2
            rm -f "$response_file" "$temp_file"
            exit 1
        fi
        
        rm -f "$temp_file"
        
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
    # Temporarily disable strict error handling for this function
    set +e
    
    local output_dir="$1"
    local json_dir="$output_dir/panel_list/json"
    local tsv_file="$output_dir/panel_list/panel_list.tsv"
    
    log "Extracting panel information from JSON files..." >&2
    
    # Create TSV header
    echo -e "id\tname\tversion\tversion_created\tnumber_of_genes\tnumber_of_strs\tnumber_of_regions" > "$tsv_file"
    
    # Process all JSON files
    local file_count=0
    local panel_count=0
    
    for json_file in "$json_dir"/panels_page_*.json; do
        if [ -f "$json_file" ]; then
            ((file_count++))
            log "Processing $json_file..." >&2
            
            # Extract panel information using jq (TSV format without quotes)
            jq -r '.results[]? | [.id, .name, .version, .version_created, .stats.number_of_genes, .stats.number_of_strs, .stats.number_of_regions] | @tsv' "$json_file" >> "$tsv_file"
            
            # Create individual panel directories and save version tracking (simplified)
            mkdir -p "$output_dir/panels"
            jq -r '.results[]? | "\(.id)\t\(.version_created)"' "$json_file" > "$output_dir/panels/temp_versions_$file_count.txt"
            
            while IFS=$'\t' read -r panel_id version_created; do
                if [ -n "$panel_id" ] && [ -n "$version_created" ]; then
                    local panel_dir="$output_dir/panels/$panel_id"
                    mkdir -p "$panel_dir"
                    
                    local version_file="$panel_dir/version_created.txt"
                    echo -n "$version_created" > "$version_file"
                fi
            done < "$output_dir/panels/temp_versions_$file_count.txt"
            
            rm -f "$output_dir/panels/temp_versions_$file_count.txt"
            
            local current_panels
            current_panels=$(jq '.results | length' "$json_file")
            log "  Processed $current_panels panels from $(basename "$json_file")" >&2
            panel_count=$((panel_count + current_panels))
        fi
    done
    
    success "Extracted information from $file_count files containing $panel_count panels" >&2
    success "Summary saved to: $tsv_file" >&2
    success "Version tracking files saved in individual panel directories" >&2
    
    # Display first few lines of the summary
    if [ -f "$tsv_file" ]; then
        log "First 5 entries in summary:" >&2
        head -6 "$tsv_file" | while IFS= read -r line; do
            echo "  $line" >&2
        done
    fi
    
    # Re-enable strict error handling
    set -e
}

# Show usage information
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Extract panel list data from PanelApp Australia API.

OPTIONS:
    --output-path PATH  Custom output path for data (default: auto-detected)
    --retries N         Number of retry attempts for failed downloads (default: 3)
    --help, -h          Show this help message

EXAMPLES:
    $0                                  # Use default settings
    $0 --retries 5                      # Use 5 retry attempts
    $0 --output-path /custom/path       # Use custom output path

EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --output-path)
                OUTPUT_PATH="$2"
                shift 2
                ;;
            --retries)
                RETRY_ATTEMPTS="$2"
                shift 2
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Main execution
main() {
    # Parse command line arguments first
    parse_arguments "$@"
    
    log "Starting PanelApp Australia data extraction..." >&2
    
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
    
    success "Data extraction completed successfully!" >&2
    log "Output directory: $output_dir" >&2
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi