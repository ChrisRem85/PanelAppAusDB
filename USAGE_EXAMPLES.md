# PanelApp Australia Data Extraction - Example Usage

## Windows PowerShell (Recommended for Windows users)

# Set execution policy for current session (if needed)
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Run the extraction script
.\extract_panels.ps1

# Or with custom output path
.\extract_panels.ps1 -OutputPath "C:\MyData"

## Python (Cross-platform)

# Install dependencies
pip install -r ..\requirements.txt

# Run the extraction
python extract_panels.py

# With verbose output
python extract_panels.py --verbose

# With custom output path
python extract_panels.py --output-path "C:\MyData"

## Bash (Linux/macOS/WSL)

# Make script executable
chmod +x extract_panels.sh

# Run the extraction
./extract_panels.sh

## Output Structure Example

# After running, you'll get:
# data/
# └── 20251017/                     # Today's date
#     ├── panel_list/
#     │   └── json/
#     │       ├── panels_page_1.json
#     │       ├── panels_page_2.json
#     │       └── panels_page_3.json
#     └── panel_list.tsv             # Extracted data (tab-separated)

## API Information Retrieved

# Each panel entry contains:
# - id: Unique identifier
# - name: Panel name 
# - version: Version string
# - version_created: Creation timestamp
# - number_of_genes: Count of genes in panel
# - number_of_strs: Count of STRs in panel  
# - number_of_regions: Count of regions in panel

## Current API Status (as of last test)
# - Total panels: 283
# - API version: v1
# - Pagination: ~100 panels per page
# - Expected pages: 3 (283 panels / 100 per page)