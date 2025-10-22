# PanelApp Australia Database Extractor

A collection of scripts to automatically extract comprehensive data from the [PanelApp Australia API](https://panelapp-aus.org/api/docs/) and organize it by date.

## Features

- **Wrapper scripts** for complete data extraction (panels + genes + STRs + regions)
- **Panel list extraction** with automatic date folder creation (format: YYYYMMDD)
- **Version tracking** per panel in individual directories  
- **Incremental extraction** - only download panels with newer versions
- **JSON directory clearing** - prevents inconsistencies from old files before downloads
- **Missing file detection** - automatically processes panels when TSV files are missing
- **Panel-specific filtering** - extract genes for specific panel IDs only
- **API version checking** to ensure compatibility
- **Paginated data extraction** with automatic "next" page handling
- **Multiple script formats** (Bash, PowerShell)
- **Structured data output** (JSON files + TSV summary)
- **Error handling and logging** with detailed progress information

## Requirements

### For Bash Scripts (`create_PanelAppAusDB.sh` / `extract_panel_list.sh` / `extract_genes.sh`)
- `bash` shell
- `curl` command
- `jq` JSON processor
- Unix-like environment (Linux, macOS, WSL)

### For PowerShell Scripts (`create_PanelAppAusDB.ps1` / `extract_panel_list.ps1` / `extract_genes.ps1`)
- PowerShell 5.1 or later
- Windows environment
- Internet access

## Installation

1. Clone this repository:
```bash
git clone https://github.com/ChrisRem85/PanelAppAusDB.git
cd PanelAppAusDB
```

2. Install dependencies based on your preferred script:

**For Bash (Linux/macOS):**
```bash
# Install jq if not available
# Ubuntu/Debian: sudo apt-get install jq curl
# macOS: brew install jq curl
```

## Usage

### Complete Data Extraction (Recommended)

Use the wrapper scripts to extract all data types (panel list + genes + STRs + regions):

#### Windows PowerShell (Recommended for Windows users)

```powershell
# Set execution policy for current session (if needed)
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Complete extraction (panel list + genes + processing + merging)
.\create_PanelAppAusDB.ps1

# Skip gene extraction (panel list only)
.\create_PanelAppAusDB.ps1 -SkipGenes

# Force re-download all data (ignore version tracking)
.\create_PanelAppAusDB.ps1 -Force

# With custom output path and verbose logging
.\create_PanelAppAusDB.ps1 -OutputPath "data" -Verbose
```

#### Bash (Linux/macOS/WSL)

```bash
# Make scripts executable
chmod +x create_PanelAppAusDB.sh scripts/extract_genes.sh scripts/process_genes.sh

# Complete extraction workflow (panel list + genes + processing + merging)
./create_PanelAppAusDB.sh

# With custom output path
./create_PanelAppAusDB.sh --output-path "data"
```

### Manual Step-by-Step Extraction

If you prefer to run individual components manually:

#### Step 1: Panel List Extraction Only

**PowerShell:**
```powershell
# Run just the panel list extraction script
.\scripts\extract_panel_list.ps1

# Or with custom output path
.\scripts\extract_panel_list.ps1 -OutputPath "data"
```

**Bash:**
```bash
# Extract panel list only
./scripts/extract_panel_list.sh
```

#### Step 2: Gene Data Extraction (Optional)

After running the panel extraction, you can extract detailed gene data:

**PowerShell:**
```powershell
# After panel extraction, extract detailed gene data
.\scripts\extract_genes.ps1

# Use specific data path
.\scripts\extract_genes.ps1 -DataPath "data"

# Extract genes for specific panel ID only
.\scripts\extract_genes.ps1 -PanelId 6

# Force re-download all panels (bypass version checking)
.\scripts\extract_genes.ps1 -Force

# Combine parameters: specific panel with verbose logging
.\scripts\extract_genes.ps1 -PanelId 6 -Force -Verbose
```

**Bash:**
```bash
# Extract genes for all panels
./scripts/extract_genes.sh

# Extract genes for specific panel
./scripts/extract_genes.sh --panel-id 6

# Use specific data folder
./scripts/extract_genes.sh --folder 20251017

# With verbose logging
./scripts/extract_genes.sh --verbose
```

#### Step 3: Process Gene Data (Convert JSON to TSV)

After extracting gene data, you can process it into TSV format with built-in validation:

**PowerShell:**
```powershell
# Process all panels (detects missing TSV files automatically)
.\scripts\process_genes.ps1

# Process specific panel ID only
.\scripts\process_genes.ps1 -PanelId 6

# Force reprocessing even if files are up-to-date
.\scripts\process_genes.ps1 -Force

# With verbose logging for detailed progress
.\scripts\process_genes.ps1 -Verbose

# Custom data path with specific panel
.\scripts\process_genes.ps1 -DataPath "data" -PanelId 6 -Verbose
```

**Bash:**
```bash
# Process genes (JSON to TSV)
./scripts/process_genes.sh

# Process specific panel
./scripts/process_genes.sh --panel-id 6

# Force reprocessing
./scripts/process_genes.sh --force
```

The process_genes scripts:
- ✅ **Convert JSON to TSV** format with extracted gene fields
- ✅ **Detect missing TSV files** and automatically regenerate them
- ✅ **Validate gene counts** against panel_list.tsv automatically
- ✅ **Log validation results** with detailed success/failure reporting
- ✅ **Generate validation statistics** showing success rates and summaries
- ✅ **Create version tracking** in `version_processed.txt` files
- ✅ **Generate structured output** in `genes/genes.tsv` for each panel
- ✅ **Color-coded logging** for easy identification of issues
- ✅ **Comprehensive error handling** with detailed failure explanations

**Validation Process:**
The script automatically validates that the number of genes extracted matches the expected count from `panel_list.tsv`. For each panel, it:
- Compares actual gene count in `genes.tsv` with expected count from panel list
- Reports validation results with panel ID, expected vs actual counts
- Logs detailed statistics including success rate and summary counts
- Uses color-coded output (green for success, red for failures, yellow for warnings)

## Key Features of Gene Extraction

The gene extraction scripts provide:
- ✅ **Incremental extraction** - Only download panels with newer versions than previously extracted
- ✅ **Track extraction history** in `version_extracted.txt` files
- ✅ **Compare version_created dates** to determine if panels need updating
- ✅ **Skip unchanged panels** to save time and bandwidth
- ✅ **Support force mode** to re-download all panels when needed
- ✅ **Clear JSON directories** before downloads to prevent inconsistencies from old files
- ✅ **Panel-specific filtering** with `-PanelId` / `--panel-id` parameter for targeted extraction

## Output Structure

The scripts create the following folder structure:

```
data/
├── panel_list/
│   ├── json/
│   │   └── panels_page_*.json        # Raw panel data from API (paginated)
│   └── panel_list.tsv                # Panel list summary (tab-separated)
└── panels/                           # Individual panel gene data
    └── [panel_id]/                   # Panel ID folders (e.g., 6, 7, 123, etc.)
        ├── version_created.txt           # Panel version tracking for incremental updates
        └── genes/
            ├── json/
            │   └── genes_page_*.json     # Raw gene data from API (paginated)
            ├── genes.tsv                 # Processed gene data (tab-separated)
            ├── version_extracted.txt     # Gene extraction timestamp
            └── version_processed.txt     # Processing timestamp (when genes converted to TSV)
```

**Note:** STR and regions data extraction is planned for future implementation. Currently, only panel metadata and gene data are extracted.

### File Descriptions

| File | Purpose | Created By |
|------|---------|------------|
| `panel_list.tsv` | Summary of all panels with metadata | `extract_panel_list.*` scripts |
| `version_created.txt` | Timestamp when panel was created (from API) | `extract_panel_list.*` scripts |
| `version_extracted.txt` | Timestamp when genes were extracted | `extract_genes.*` scripts |
| `version_processed.txt` | Timestamp when genes were processed to TSV | `process_genes.*` scripts |
| `genes.tsv` | Processed gene data in tab-separated format | `process_genes.*` scripts |
| `genes_page_*.json` | Raw gene data from API (paginated) | `extract_genes.*` scripts |
```

## Data Extracted

### Panel Information

From each panel, the following information is extracted:

| Field | Description | Source API Field |
|-------|-------------|------------------|
| `id` | Unique panel identifier | `id` |
| `name` | Panel name | `name` |
| `version` | Panel version | `version` |
| `version_created` | Version creation timestamp | `version_created` |
| `number_of_genes` | Number of genes in panel | `stats.number_of_genes` |
| `number_of_strs` | Number of STRs in panel | `stats.number_of_strs` |
| `number_of_regions` | Number of regions in panel | `stats.number_of_regions` |

### Gene Data Structure

Each panel's genes are stored in `panels/[panel_id]/genes/json/genes_page_*.json` and processed into `genes.tsv`.

Gene data includes:
- **entity_name**: Gene symbol (e.g., "CNGA3")
- **confidence_level**: Evidence level (1-3)
- **mode_of_inheritance**: Inheritance pattern
- **phenotypes**: Associated conditions
- **gene_data**: Detailed gene information (HGNC, OMIM, etc.)

## Configuration

You can modify the configuration in `config/config.env`:

```bash
# API Configuration
BASE_URL=https://panelapp-aus.org/api
API_VERSION=v1
EXPECTED_API_VERSION=v1

# Output Configuration
DEFAULT_OUTPUT_PATH=../data

# Safety Configuration
MAX_PAGES=1000  # Prevent infinite loops
```

## API Information

This project uses the [PanelApp Australia API v1](https://panelapp-aus.org/api/docs/):
- **Base URL:** `https://panelapp-aus.org/api/v1`
- **Panels endpoint:** `/panels/`
- **Documentation:** [OpenAPI/Swagger](https://panelapp-aus.org/api/docs/?format=openapi)

### API Status (as of October 2025)
- **Total panels**: ~283
- **API version**: v1
- **Pagination**: ~100 panels per page
- **Expected pages**: 3 (283 panels / 100 per page)

The API uses pagination with the following structure:
```json
{
  "count": 283,
  "next": "https://panelapp-aus.org/api/v1/panels/?page=2",
  "previous": null,
  "results": [...]
}
```

## Error Handling

All scripts include comprehensive error handling:

- **HTTP errors** are caught and logged with appropriate messages
- **JSON parsing errors** are handled gracefully
- **File system errors** (permissions, disk space) are reported
- **API version mismatches** generate warnings but allow continued execution
- **Safety limits** prevent infinite loops in pagination

## Logging

- **Bash script:** Colored console output with timestamps
- **PowerShell script:** Colored console output with timestamps

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is open source. Please check the LICENSE file for details.

## Support

For issues or questions:
1. Check the [PanelApp Australia API documentation](https://panelapp-aus.org/api/docs/)
2. Review the error logs for specific error messages
3. Open an issue in this repository

## TSV Output Format

The generated `panel_list.tsv` file contains the following tab-separated columns:

```
id	name	version	version_created	number_of_genes	number_of_strs	number_of_regions
3149	Achromatopsia	1.5	2022-09-21T07:10:55.626185Z	8	0	0
1234	Another Panel	2.1	2023-02-15T10:30:00Z	15	2	1
```

## Changelog

### Version 1.2.0
- **BREAKING:** Separated gene extraction into dedicated scripts (`extract_genes.*`)
- Panel extraction scripts now focus only on panel metadata
- Gene scripts: `extract_genes.py`, `extract_genes.ps1`, `extract_genes.sh`
- Auto-detection of latest data folder for gene extraction
- Enhanced command-line options for both script types

### Version 1.1.0
- Added `number_of_genes`, `number_of_strs`, and `number_of_regions` columns to TSV output
- Enhanced data extraction to include panel statistics

### Version 1.0.0
- Initial release with Bash, PowerShell, and Python scripts
- Automatic date folder creation
- API version checking
- Paginated data extraction
- TSV summary generation (tab-separated, no quotes)