# PanelApp Australia Database Extractor

A collection of scripts to automatically extract comprehensive data from the [PanelApp Australia API](https://panelapp-aus.org/api/docs/) and organize it by date.

## Features

- **Wrapper scripts** for complete data extraction (panels + genes + STRs + regions)
- **Panel list extraction** with automatic date folder creation (format: YYYYMMDD)
- **Version tracking** per panel in individual directories  
- **Incremental extraction** - only download panels with newer versions
- **API version checking** to ensure compatibility
- **Paginated data extraction** with automatic "next" page handling
- **Multiple script formats** (Bash, PowerShell)
- **Structured data output** (JSON files + TSV summary)
- **Error handling and logging** with detailed progress information

## Requirements

### For Bash Scripts (`extract_panels.sh` / `extract_panel_list.sh` / `extract_genes.sh`)
- `bash` shell
- `curl` command
- `jq` JSON processor
- Unix-like environment (Linux, macOS, WSL)

### For PowerShell Scripts (`extract_panels.ps1` / `extract_panel_list.ps1` / `extract_genes.ps1`)
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

**Using PowerShell Wrapper (Recommended for Windows):**
```powershell
cd scripts
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser  # If needed
.\extract_panels.ps1

# Skip specific data types
.\extract_panels.ps1 -SkipGenes
.\extract_panels.ps1 -SkipStrs -SkipRegions

# With verbose logging and custom path
.\extract_panels.ps1 -OutputPath "C:\MyData" -Verbose
```

**Using Bash Wrapper (Linux/macOS/WSL):**
```bash
cd scripts
chmod +x extract_panels.sh extract_panel_list.sh extract_genes.sh
./extract_panels.sh

# Skip specific data types
./extract_panels.sh --skip-genes
./extract_panels.sh --skip-strs --skip-regions

# With verbose logging and custom path
./extract_panels.sh --output-path /path/to/data --verbose
```

### Manual Step-by-Step Extraction

If you prefer to run individual components manually:

#### Step 1: Extract Panel List Only

**Using Bash Script:**
```bash
cd scripts
chmod +x extract_panel_list.sh
./extract_panel_list.sh
```

**Using PowerShell Script:**
```powershell
cd scripts
.\extract_panel_list.ps1
```

### Step 2: Extract Gene Data (Optional)

After running the panel extraction, you can extract detailed gene data:

**Using Bash Script:**
```bash
chmod +x extract_genes.sh
./extract_genes.sh

# Use specific data folder
./extract_genes.sh --folder 20251017

# With verbose logging
./extract_genes.sh --verbose
```

**Using PowerShell Script:**
```powershell
.\extract_genes.ps1

# Use specific data folder
.\extract_genes.ps1 -Folder "20251017"

# With verbose logging
.\extract_genes.ps1 -Verbose
```

### Step 3: Process Gene Data (Optional)

After extracting gene data, you can process it into TSV format with built-in validation:

**Using Bash Script:**
```bash
chmod +x process_genes.sh
./process_genes.sh

# With verbose logging
./process_genes.sh --verbose
```

**Using PowerShell Script:**
```powershell
.\process_genes.ps1

# With verbose logging
.\process_genes.ps1 -Verbose
```

The process_genes scripts:
- ✅ **Convert JSON to TSV** format with extracted gene fields
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

For efficiency, use the incremental extraction scripts that only download panels with newer versions than previously extracted:

**Using Bash Script:**
```bash
./extract_genes.sh

# Force re-download all panels
./extract_genes.sh --force

# Use specific data folder
./extract_genes.sh --folder 20251017
```

**Using PowerShell Script:**
```powershell
.\extract_genes.ps1

# Force re-download all panels
.\extract_genes.ps1 -Force

# Use specific data folder and verbose logging
.\extract_genes.ps1 -Folder "20251017" -Verbose
```

The incremental scripts:
- ✅ **Track extraction history** in `version_extracted.txt` files
- ✅ **Compare version_created dates** to determine if panels need updating
- ✅ **Skip unchanged panels** to save time and bandwidth
- ✅ **Support force mode** to re-download all panels when needed

## Output Structure

The scripts create the following folder structure:

```
data/
├── panel_list/
│   └── json/
│       ├── panels_page_1.json
│       ├── panels_page_2.json
│       └── ...
├── panels/                      # Individual panel data
│   ├── 3149/                   # Panel ID folder
│   │   ├── version_created.txt         # Panel version tracking for incremental updates
│   │   ├── version_processed.txt       # Processing timestamp (when genes converted to TSV)
│   │   ├── genes/
│   │   │   ├── json/
│   │   │   │   ├── genes_page_1.json   # Raw gene data from API
│   │   │   │   └── ...
│   │   │   ├── genes.tsv               # Processed gene data (TSV format)
│   │   │   └── version_extracted.txt   # Gene extraction timestamp
│   │   ├── strs/                       # STR data (future implementation)
│   │   └── regions/                    # Region data (future implementation)
│   └── 3150/                   # Another panel
│       ├── version_created.txt
│       ├── version_processed.txt
│       └── genes/
│           ├── json/
│           │   └── genes_page_1.json
│           ├── genes.tsv
│           └── version_extracted.txt
└── panel_list.tsv              # Extracted panel information (tab-separated)
```

### File Descriptions

| File | Purpose | Created By |
|------|---------|------------|
| `panel_list.tsv` | Summary of all panels with metadata | `extract_panel_list.*` scripts |
| `version_created.txt` | Panel version from API for incremental updates | `extract_panel_list.*` scripts |
| `version_extracted.txt` | Timestamp when genes were extracted | `extract_genes.*` scripts |
| `version_processed.txt` | Timestamp when genes were processed to TSV | `process_genes.*` scripts |
| `genes.tsv` | Processed gene data in tab-separated format | `process_genes.*` scripts |
| `genes_page_*.json` | Raw gene data from API (paginated) | `extract_genes.*` scripts |
```

## Data Extracted

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

The API uses pagination with the following structure:
```json
{
  "count": 123,
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