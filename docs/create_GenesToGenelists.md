# Gene to Genelists Converter

## Overview

The GenesToGenelists converter scripts transform the consolidated genes.tsv file into specialized genelist files based on confidence levels. These files are formatted for integration with external gene analysis tools and databases.

## Available Scripts

- **PowerShell**: `scripts/create_GenesToGenelists.ps1`
- **Bash**: `scripts/create_GenesToGenelists.sh`

## Usage

### PowerShell
```powershell
# Create genelist files from consolidated genes data
.\scripts\create_GenesToGenelists.ps1

# Force regeneration even if files are up to date
.\scripts\create_GenesToGenelists.ps1 -Force

# With verbose logging and custom data path
.\scripts\create_GenesToGenelists.ps1 -DataPath "data" -Verbose
```

### Bash
```bash
# Create genelist files from consolidated genes data
./scripts/create_GenesToGenelists.sh

# Force regeneration even if files are up to date
./scripts/create_GenesToGenelists.sh --force

# With verbose logging and custom data path
./scripts/create_GenesToGenelists.sh --data-path "data" --verbose
```

## Parameters

| Parameter | PowerShell | Bash | Description |
|-----------|------------|------|-------------|
| Data Path | `-DataPath` | `--data-path` | Path to data directory (default: ./data) |
| Force | `-Force` | `--force` | Force regeneration even if files are up to date |
| Verbose | `-Verbose` | `--verbose` | Enable detailed logging |

## Output Structure

Creates genelist files in the data directory:
```
data/
└── genelists/
    ├── genes_to_genelists.PanelAppAustralia_Green.txt    # Confidence level 3 genes
    └── genes_to_genelists.PanelAppAustralia_Amber.txt    # Confidence level 2 genes
```

## Key Features

- ✅ **Confidence-based filtering** - Separate files for Green (3) and Amber (2) confidence levels
- ✅ **Standardized format** - Two-column output: ensembl_id and formatted panel identifier
- ✅ **Proper sorting** - Sorted by ensembl_id, then by panel_id for consistency
- ✅ **Panel identification** - Panel IDs formatted as "Paus:[panel_id].[Green|Amber]"
- ✅ **Incremental processing** - Only regenerates when input files are newer
- ✅ **Input validation** - Verifies required columns exist in genes.tsv
- ✅ **Cross-platform** - Both PowerShell and Bash implementations
- ✅ **Empty value filtering** - Excludes genes with empty ensembl_id values

## Output Format

Both genelist files use a consistent two-column format with no headers:

**Green genelist (confidence_level = 3):**
```
ENSG00000000419	Paus:137.Green
ENSG00000000419	Paus:138.Green
ENSG00000000419	Paus:141.Green
ENSG00000001626	Paus:4191.Green
ENSG00000001631	Paus:3302.Green
```

**Amber genelist (confidence_level = 2):**
```
ENSG00000001626	Paus:4191.Amber
ENSG00000001626	Paus:78.Amber
ENSG00000001631	Paus:3302.Amber
ENSG00000001631	Paus:3763.Amber
ENSG00000003989	Paus:137.Amber
```

### Column Descriptions
- **Column 1**: Ensembl gene ID (ENSG identifiers)
- **Column 2**: Formatted panel identifier with confidence level suffix

## Processing Logic

1. **Input Validation**: Checks for required columns (ensembl_id, confidence_level, panel_id)
2. **Confidence Filtering**: Separates genes by confidence_level (2 = Amber, 3 = Green)
3. **Empty Value Filtering**: Excludes records with empty ensembl_id values
4. **Format Transformation**: Creates "Paus:[panel_id].[Green|Amber]" identifiers
5. **Sorting**: Orders output by ensembl_id first, then by panel identifier
6. **File Output**: Writes tab-separated files without headers

## Use Cases

- **Gene Analysis Tools**: Import curated gene lists for pathway analysis
- **Database Integration**: Load panel-specific gene sets into research databases  
- **Quality Control**: Separate high-confidence (Green) from moderate-confidence (Amber) genes
- **Cross-Panel Studies**: Compare gene membership across different panels by confidence level
- **External Tool Integration**: Format compatible with various bioinformatics pipelines

## Statistics Example

From a typical run processing ~48,000 genes:
- **Green genes (confidence_level 3)**: ~35,968 entries
- **Amber genes (confidence_level 2)**: ~4,924 entries
- **Total coverage**: Across 281+ panels from PanelApp Australia

## Requirements

### PowerShell Version
- PowerShell 5.1 or later
- Windows environment
- Consolidated genes.tsv file in data/genes/genes.tsv

### Bash Version
- `bash` shell
- `awk` command (standard on Unix systems)
- Unix-like environment (Linux, macOS, WSL)
- Consolidated genes.tsv file in data/genes/genes.tsv

## Integration

This script is designed to be called from the main `create_PanelAppAusDB` wrapper scripts as part of the complete data extraction workflow. It can also be run independently when you need to regenerate genelist files from existing consolidated data.

---

← [Back to Main README](../README.md)