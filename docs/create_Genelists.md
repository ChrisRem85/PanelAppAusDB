# Gene to Genelists Converter

## Overview

The GenesToGenelists converter scripts transform the consolidated genes.tsv file into specialized genelist files based on confidence levels and create a simple genelist with all unique ensembl_ids. These files are formatted for integration with external gene analysis tools and databases.

## Available Scripts

- **PowerShell**: `scripts/create_Genelists.ps1`
- **Bash**: `scripts/create_Genelists.sh`

## Usage

### PowerShell
```powershell
# Create genelist files from consolidated genes data
.\scripts\create_Genelists.ps1

# Force regeneration even if files are up to date
.\scripts\create_Genelists.ps1 -Force

# With verbose logging and custom data path
.\scripts\create_Genelists.ps1 -DataPath "data" -Verbose
```

### Bash
```bash
# Create genelist files from consolidated genes data
./scripts/create_Genelists.sh

# Force regeneration even if files are up to date
./scripts/create_Genelists.sh --force

# With verbose logging and custom data path
./scripts/create_Genelists.sh --data-path "data" --verbose
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
    ├── genes_to_genelists.PanelAppAustralia_Amber.txt    # Confidence level 2 genes
    ├── genelist.PanelAppAustralia_GreenAmber.txt         # All unique ensembl_ids
    └── version_genelists.txt                             # Creation timestamp
```

## Key Features

- ✅ **Confidence-based filtering** - Separate files for Green (3) and Amber (2) confidence levels
- ✅ **Simple genelist** - All unique ensembl_ids in a single column format
- ✅ **Version tracking** - Automatic creation of version_genelists.txt with ISO 8601 UTC timestamp
- ✅ **Standardized format** - Two-column output for confidence files, one-column for simple genelist
- ✅ **Proper sorting** - Sorted by ensembl_id, then by panel_id for consistency
- ✅ **Panel identification** - Panel IDs formatted as "Paus:[panel_id].[Green|Amber]"
- ✅ **Version-aware processing** - Uses version_merged.txt timestamp for regeneration decisions
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

**Simple genelist (all confidence levels):**
```
ENSG00000000419
ENSG00000001626
ENSG00000001631
ENSG00000003989
ENSG00000005007
```

**Version tracking file:**
```
2025-11-05T11:28:57.8192891Z
```

### Column Descriptions

**Green/Amber files:**
- **Column 1**: Ensembl gene ID (ENSG identifiers)
- **Column 2**: Formatted panel identifier with confidence level suffix

**Simple genelist file:**
- **Column 1**: Ensembl gene ID (ENSG identifiers) - unique, sorted, no headers

**Version file:**
- Contains ISO 8601 UTC timestamp with nanosecond precision indicating when genelists were created

## Processing Logic

1. **Input Validation**: Checks for required columns (ensembl_id, confidence_level, panel_id)
2. **Version Check**: Uses version_merged.txt timestamp to determine if regeneration is needed
3. **Confidence Filtering**: Separates genes by confidence_level (2 = Amber, 3 = Green)
4. **Empty Value Filtering**: Excludes records with empty ensembl_id values
5. **Format Transformation**: Creates "Paus:[panel_id].[Green|Amber]" identifiers
6. **Simple Genelist Creation**: Extracts all unique ensembl_ids sorted alphanumerically
7. **Sorting**: Orders output by ensembl_id first, then by panel identifier
8. **File Output**: Writes tab-separated confidence files and single-column simple genelist without headers
9. **Version Tracking**: Creates version_genelists.txt with ISO 8601 UTC timestamp upon successful completion

## Use Cases

- **Gene Analysis Tools**: Import curated gene lists for pathway analysis
- **Database Integration**: Load panel-specific gene sets into research databases  
- **Quality Control**: Separate high-confidence (Green) from moderate-confidence (Amber) genes
- **Cross-Panel Studies**: Compare gene membership across different panels by confidence level
- **Simple Gene Lists**: Use the basic genelist.PanelAppAustralia_GreenAmber.txt for tools requiring simple ensembl_id lists
- **External Tool Integration**: Format compatible with various bioinformatics pipelines
- **Version Tracking**: Monitor when genelists were last updated for audit trails and reproducibility

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