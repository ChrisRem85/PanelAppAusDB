# Panel List Extraction

## Overview

The panel list extraction scripts download comprehensive panel metadata from the PanelApp Australia API and organize it by date.

## Available Scripts

- **PowerShell**: `scripts/extract_PanelList.ps1`
- **Bash**: `scripts/extract_PanelList.sh`

## Usage

### PowerShell
```powershell
# Run just the panel list extraction script
.\scripts\extract_PanelList.ps1

# Or with custom output path
.\scripts\extract_PanelList.ps1 -OutputPath "data"
```

### Bash
```bash
# Extract panel list only
./scripts/extract_PanelList.sh
```

## Parameters

| Parameter | PowerShell | Bash | Description |
|-----------|------------|------|-------------|
| Output Path | `-OutputPath` | N/A | Custom output directory path |

## Output

Creates the following structure:
```
data/
└── panel_list/
    ├── json/
    │   └── panels_page_*.json        # Raw panel data from API (paginated)
    └── panel_list.tsv                # Panel list summary (tab-separated)
```

## Features

- **Automatic date folder creation** (format: YYYYMMDD)
- **API version checking** to ensure compatibility
- **Paginated data extraction** with automatic "next" page handling
- **Error handling and logging** with detailed progress information
- **TSV output format** for easy data analysis

## Panel Information Extracted

| Field | Description | Source API Field |
|-------|-------------|------------------|
| `id` | Unique panel identifier | `id` |
| `name` | Panel name | `name` |
| `version` | Panel version | `version` |
| `version_created` | Version creation timestamp | `version_created` |
| `number_of_genes` | Number of genes in panel | `stats.number_of_genes` |
| `number_of_strs` | Number of STRs in panel | `stats.number_of_strs` |
| `number_of_regions` | Number of regions in panel | `stats.number_of_regions` |

## TSV Output Format

```
id	name	version	version_created	number_of_genes	number_of_strs	number_of_regions
3149	Achromatopsia	1.5	2022-09-21T07:10:55.626185Z	8	0	0
1234	Another Panel	2.1	2023-02-15T10:30:00Z	15	2	1
```

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