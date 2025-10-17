# PanelApp Australia Database Extractor

A collection of scripts to automatically extract panel data from the [PanelApp Australia API](https://panelapp-aus.org/api/docs/) and organize it by date.

## Features

- **Automatic date folder creation** (format: YYYYMMDD)
- **API version checking** to ensure compatibility
- **Paginated data extraction** with automatic "next" page handling
- **Multiple script formats** (Bash, PowerShell, Python)
- **Structured data output** (JSON files + TSV summary)
- **Error handling and logging** with detailed progress information

## Requirements

### For Bash Script (`extract_panels.sh`)
- `bash` shell
- `curl` command
- `jq` JSON processor
- Unix-like environment (Linux, macOS, WSL)

### For PowerShell Script (`extract_panels.ps1`)
- PowerShell 5.1 or later
- Windows environment
- Internet access

### For Python Script (`extract_panels.py`)
- Python 3.6 or later
- `requests` library (`pip install requests`)
- Cross-platform (Windows, Linux, macOS)

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

**For Python:**
```bash
pip install requests
```

## Usage

### Using Bash Script (Recommended for Linux/macOS)
```bash
cd scripts
chmod +x extract_panels.sh
./extract_panels.sh
```

### Using PowerShell Script (Recommended for Windows)
```powershell
cd scripts
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser  # If needed
.\extract_panels.ps1
```

### Using Python Script (Cross-platform)
```bash
cd scripts
python extract_panels.py

# With custom output path
python extract_panels.py --output-path /path/to/custom/output

# With verbose logging
python extract_panels.py --verbose
```

## Output Structure

The scripts create the following folder structure:

```
data/
└── YYYYMMDD/                    # Date of execution (e.g., 20251017)
    ├── panel_list/
    │   └── json/
    │       ├── panels_page_1.json
    │       ├── panels_page_2.json
    │       └── ...
    └── panel_list.tsv            # Extracted panel information (tab-separated)
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
- **Python script:** Standard Python logging with configurable levels

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

### Version 1.1.0
- Added `number_of_genes`, `number_of_strs`, and `number_of_regions` columns to TSV output
- Enhanced data extraction to include panel statistics

### Version 1.0.0
- Initial release with Bash, PowerShell, and Python scripts
- Automatic date folder creation
- API version checking
- Paginated data extraction
- TSV summary generation (tab-separated, no quotes)