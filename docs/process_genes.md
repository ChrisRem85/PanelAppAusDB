# Gene Data Processing

## Overview

The gene processing scripts convert raw JSON gene data into structured TSV format with built-in validation and automatic missing file detection.

## Available Scripts

- **PowerShell**: `scripts/process_genes.ps1`
- **Bash**: `scripts/process_genes.sh`

## Usage

### PowerShell
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

### Bash
```bash
# Process genes (JSON to TSV)
./scripts/process_genes.sh

# Process specific panel
./scripts/process_genes.sh --panel-id 6

# Force reprocessing
./scripts/process_genes.sh --force

# With verbose logging
./scripts/process_genes.sh --verbose
```

## Parameters

| Parameter | PowerShell | Bash | Description |
|-----------|------------|------|-------------|
| Data Path | `-DataPath` | N/A | Path to data directory (default: ../data) |
| Panel ID | `-PanelId` | `--panel-id` | Process specific panel ID only |
| Force | `-Force` | `--force` | Force reprocessing even if files are up-to-date |
| Verbose | `-Verbose` | `--verbose` | Enable detailed logging |

## Output Structure

Adds processed TSV files to the gene data structure:
```
data/
└── panels/
    └── [panel_id]/
        └── genes/
            ├── json/
            │   └── genes_page_*.json     # Raw gene data from API (paginated)
            ├── genes.tsv                 # Processed gene data (tab-separated)
            ├── version_extracted.txt     # Gene extraction timestamp
            └── version_processed.txt     # Processing timestamp
```

## Key Features

- ✅ **Convert JSON to TSV** format with extracted gene fields
- ✅ **Detect missing TSV files** and automatically regenerate them
- ✅ **Validate gene counts** against panel_list.tsv automatically
- ✅ **Log validation results** with detailed success/failure reporting
- ✅ **Generate validation statistics** showing success rates and summaries
- ✅ **Create version tracking** in `version_processed.txt` files
- ✅ **Generate structured output** in `genes/genes.tsv` for each panel
- ✅ **Color-coded logging** for easy identification of issues
- ✅ **Comprehensive error handling** with detailed failure explanations

## Validation Process

The script automatically validates that the number of genes extracted matches the expected count from `panel_list.tsv`. For each panel, it:

- Compares actual gene count in `genes.tsv` with expected count from panel list
- Reports validation results with panel ID, expected vs actual counts
- Logs detailed statistics including success rate and summary counts
- Uses color-coded output (green for success, red for failures, yellow for warnings)

## TSV Output Format

The generated `genes.tsv` files contain extracted gene fields in tab-separated format:

```
hgnc_symbol    ensembl_id         confidence_level    penetrance    mode_of_pathogenicity    publications               mode_of_inheritance
COL3A1         ENSG00000168542    3                                                          28742248,19455184,25205403 BIALLELIC, autosomal or pseudoautosomal
DAG1           ENSG00000173402    1                   unknown                              29337005                   BIALLELIC, autosomal or pseudoautosomal
```

## Processing Logic

1. **Missing File Detection**: Automatically identifies panels missing TSV files
2. **Version Comparison**: Checks if JSON data is newer than processed TSV
3. **JSON Parsing**: Extracts relevant fields from paginated gene data
4. **Data Transformation**: Converts nested JSON structures to flat TSV format
5. **Validation**: Compares gene counts against expected values
6. **Timestamp Tracking**: Records processing time in `version_processed.txt`

## Requirements

### PowerShell Version
- PowerShell 5.1 or later
- Windows environment
- Valid JSON gene data (from extract_genes scripts)

### Bash Version
- `bash` shell
- `jq` JSON processor
- Unix-like environment (Linux, macOS, WSL)
- Valid JSON gene data (from extract_genes scripts)

---

← [Back to Main README](../README.md)