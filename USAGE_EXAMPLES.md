# PanelApp Australia Data Extraction - Example Usage

## Complete Data Extraction (Recommended)

### Windows PowerShell (Recommended for Windows users)

# Set execution policy for current session (if needed)
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Complete extraction (panel list + genes + STRs + regions)
.\extract_panels.ps1

# Skip specific data types
.\extract_panels.ps1 -SkipGenes
.\extract_panels.ps1 -SkipStrs -SkipRegions

# With custom output path
.\extract_panels.ps1 -OutputPath "C:\MyData" -Verbose

## Manual Step-by-Step Extraction

### Step 1: Panel List Extraction Only

# Run just the panel list extraction script
.\extract_panel_list.ps1

# Or with custom output path
.\extract_panel_list.ps1 -OutputPath "C:\MyData"

## Step 2: Gene Data Extraction (Optional)

### Gene Data Extraction (Incremental by default)

# After panel extraction, extract detailed gene data
.\extract_genes.ps1

# Use specific data path
.\extract_genes.ps1 -DataPath "C:\MyData"

# Extract genes for specific panel ID only
.\extract_genes.ps1 -PanelId 6

# Force re-download all panels (bypass version checking)
.\extract_genes.ps1 -Force

# Combine parameters: specific panel with verbose logging
.\extract_genes.ps1 -PanelId 6 -Force -Verbose

### Step 3: Process Gene Data (Convert JSON to TSV)

# Process all panels (detects missing TSV files automatically)
.\process_genes.ps1

# Process specific panel ID only
.\process_genes.ps1 -PanelId 6

# Force reprocessing even if files are up-to-date
.\process_genes.ps1 -Force

# With verbose logging for detailed progress
.\process_genes.ps1 -Verbose

# Custom data path with specific panel
.\process_genes.ps1 -DataPath "C:\MyData" -PanelId 6 -Verbose

## Python (Alternative - if available)

# Note: Python scripts are not included in this repository
# This project uses PowerShell and Bash scripts only
# If you have Python scripts, they would follow similar patterns:

# python scripts/extract_panels.py
# python scripts/extract_genes.py --panel-id 6  
# python scripts/process_genes.py

## Bash (Linux/macOS/WSL)

# Make scripts executable
chmod +x scripts/extract_panels.sh scripts/extract_genes.sh scripts/process_genes.sh

# Complete extraction workflow
./scripts/extract_panels.sh

# With custom output path
./scripts/extract_panels.sh --output-path "/home/user/mydata"

# Individual scripts:

# Extract panel list only
./scripts/extract_panel_list.sh

# Extract genes for all panels
./scripts/extract_genes.sh

# Extract genes for specific panel
./scripts/extract_genes.sh --panel-id 6

# Use specific data folder
./scripts/extract_genes.sh --folder 20251017

# With verbose logging
./scripts/extract_genes.sh --verbose

# Process genes (JSON to TSV)
./scripts/process_genes.sh

# Process specific panel
./scripts/process_genes.sh --panel-id 6

# Force reprocessing
./scripts/process_genes.sh --force

## Output Structure Example

# After running, you'll get:
# data/
# └── 20251017/                     # Today's date
#     ├── panel_list/
#     │   └── json/
#     │       ├── panels_page_1.json
#     │       ├── panels_page_2.json
#     │       └── panels_page_3.json
#     ├── panels/                 # Individual panel gene data
#     │   ├── 3149/              # Panel ID folder  
#     │   │   └── genes/
#     │   │       ├── json/
#     │   │       │   └── genes_page_1.json
#     │   │       └── genes.tsv   # Processed gene data (tab-separated)
#     │   └── 3150/              # Another panel
#     │       └── genes/
#     │           ├── json/
#     │           │   └── genes_page_1.json
#     │           └── genes.tsv   # Processed gene data (tab-separated)
#     └── panel_list.tsv         # Panel list (tab-separated)

## API Information Retrieved

# Each panel entry contains:
# - id: Unique identifier
# - name: Panel name 
# - version: Version string
# - version_created: Creation timestamp
# - number_of_genes: Count of genes in panel
# - number_of_strs: Count of STRs in panel  
# - number_of_regions: Count of regions in panel

## Gene Data Structure

# Each panel's genes are stored in:
# panels/[panel_id]/genes/json/genes_page_*.json

# Gene data includes:
# - entity_name: Gene symbol (e.g., "CNGA3")
# - confidence_level: Evidence level (1-3)
# - mode_of_inheritance: Inheritance pattern
# - phenotypes: Associated conditions
# - gene_data: Detailed gene information (HGNC, OMIM, etc.)

## Current API Status (as of last test)
# - Total panels: 283
# - API version: v1
# - Pagination: ~100 panels per page
# - Expected pages: 3 (283 panels / 100 per page)