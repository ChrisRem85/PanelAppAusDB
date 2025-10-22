# Gene Data Extraction

## Overview

The gene extraction scripts download detailed gene data for each panel with intelligent incremental updating based on panel version tracking.

## Available Scripts

- **PowerShell**: `scripts/extract_genes.ps1`
- **Bash**: `scripts/extract_genes.sh`

## Usage

### PowerShell
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

### Bash
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

## Parameters

| Parameter | PowerShell | Bash | Description |
|-----------|------------|------|-------------|
| Data Path | `-DataPath` | `--folder` | Path to data directory or specific date folder |
| Panel ID | `-PanelId` | `--panel-id` | Extract genes for specific panel ID only |
| Force | `-Force` | `--force` | Force re-download all panels (bypass version checking) |
| Verbose | `-Verbose` | `--verbose` | Enable detailed logging |

## Output Structure

Creates gene data within the panel structure:
```
data/
└── panels/
    └── [panel_id]/
        ├── version_created.txt           # Panel version tracking
        └── genes/
            ├── json/
            │   └── genes_page_*.json     # Raw gene data from API (paginated)
            └── version_extracted.txt     # Gene extraction timestamp
```

## Key Features

- ✅ **Incremental extraction** - Only download panels with newer versions than previously extracted
- ✅ **Track extraction history** in `version_extracted.txt` files
- ✅ **Compare version_created dates** to determine if panels need updating
- ✅ **Skip unchanged panels** to save time and bandwidth
- ✅ **Support force mode** to re-download all panels when needed
- ✅ **Clear JSON directories** before downloads to prevent inconsistencies from old files
- ✅ **Panel-specific filtering** with `-PanelId` / `--panel-id` parameter for targeted extraction

## Gene Data Structure

Each panel's genes are stored in `panels/[panel_id]/genes/json/genes_page_*.json`.

Gene data includes:
- **entity_name**: Gene symbol (e.g., "CNGA3")
- **confidence_level**: Evidence level (1-3)
- **mode_of_inheritance**: Inheritance pattern
- **phenotypes**: Associated conditions
- **gene_data**: Detailed gene information (HGNC, OMIM, etc.)

## Version Tracking

The extraction process uses intelligent version tracking:

1. **version_created.txt**: Contains the panel's creation timestamp from the API
2. **version_extracted.txt**: Records when genes were last extracted
3. **Comparison Logic**: Only extracts genes if panel version is newer than last extraction
4. **Force Mode**: Bypasses all version checks and re-downloads everything

## Requirements

### PowerShell Version
- PowerShell 5.1 or later
- Windows environment
- Internet access

### Bash Version
- `bash` shell
- `curl` command
- `jq` JSON processor
- Unix-like environment (Linux, macOS, WSL)

---

← [Back to Main README](../README.md)