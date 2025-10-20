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

### Standard Gene Extraction (Downloads all panels)

# After panel extraction, extract detailed gene data
.\extract_genes.ps1

# Use specific data folder
.\extract_genes.ps1 -Folder "20251017"

# With verbose logging
.\extract_genes.ps1 -Verbose

### Incremental Gene Extraction (Recommended - Only downloads updated panels)

# Extract only panels with newer versions than last extraction
.\extract_genes_incremental.ps1

# Force re-download all panels (bypass version checking)
.\extract_genes_incremental.ps1 -Force

# Use specific data folder with verbose logging
.\extract_genes_incremental.ps1 -Folder "20251017" -Verbose

## Python (Cross-platform)

# Install dependencies
pip install -r ..\requirements.txt

# Step 1: Extract panels
python extract_panels.py

# With verbose output
python extract_panels.py --verbose

# With custom output path
python extract_panels.py --output-path "C:\MyData"

# Step 2a: Standard gene extraction
python extract_genes.py

# Use specific data folder
python extract_genes.py --folder 20251017

# With custom data path and verbose logging
python extract_genes.py --data-path "C:\MyData" --verbose

# Step 2b: Incremental gene extraction (Recommended)
python extract_genes_incremental.py

# Force re-download all panels
python extract_genes_incremental.py --force

# Use specific data folder with verbose logging
python extract_genes_incremental.py --folder 20251017 --verbose

## Bash (Linux/macOS/WSL)

# Make scripts executable
chmod +x extract_panels.sh extract_genes.sh extract_genes_incremental.sh

# Step 1: Extract panels
./extract_panels.sh

# Step 2a: Standard gene extraction
./extract_genes.sh

# Use specific data folder
./extract_genes.sh --folder 20251017

# With verbose logging
./extract_genes.sh --verbose

# Step 2b: Incremental gene extraction (Recommended)
./extract_genes_incremental.sh

# Force re-download all panels  
./extract_genes_incremental.sh --force

# Use specific folder with verbose logging
./extract_genes_incremental.sh --folder 20251017 --verbose

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
#     │   │       └── json/
#     │   │           └── genes_page_1.json
#     │   └── 3150/              # Another panel
#     │       └── genes/
#     │           └── json/
#     │               └── genes_page_1.json
#     └── panel_list.tsv         # Extracted data (tab-separated)

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