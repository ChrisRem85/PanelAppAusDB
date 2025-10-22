# Panel Data Merging

## Overview

The merge panels scripts consolidate individual panel TSV files into unified datasets with panel_id columns for cross-panel analysis and research.

## Available Scripts

- **PowerShell**: `scripts/merge_panels.ps1`
- **Bash**: `scripts/merge_panels.sh`

## Usage

### PowerShell
```powershell
# Merge all entity types (genes, strs, regions)
.\scripts\merge_panels.ps1

# Merge only genes data
.\scripts\merge_panels.ps1 -EntityType genes

# Force re-merge even if up to date
.\scripts\merge_panels.ps1 -Force

# Custom data path with verbose logging
.\scripts\merge_panels.ps1 -DataPath "data" -Verbose
```

### Bash
```bash
# Merge all entity types
./scripts/merge_panels.sh

# Merge only genes data  
./scripts/merge_panels.sh --entity-type genes

# Force re-merge even if up to date
./scripts/merge_panels.sh --force

# Custom data path with verbose logging
./scripts/merge_panels.sh --data-path "data" --verbose
```

## Parameters

| Parameter | PowerShell | Bash | Description |
|-----------|------------|------|-------------|
| Data Path | `-DataPath` | `--data-path` | Path to data directory (default: ../data) |
| Entity Type | `-EntityType` | `--entity-type` | Merge specific type: genes, strs, regions (default: all) |
| Force | `-Force` | `--force` | Force re-merge even if up to date |
| Verbose | `-Verbose` | `--verbose` | Enable detailed logging |

## Output Structure

Creates consolidated datasets in the root data directory:
```
data/
├── genes/                            # Consolidated cross-panel gene data
│   ├── genes.tsv                     # Merged gene data with panel_id column
│   └── version_merged.txt            # Last merge timestamp
├── strs/                             # Future: Consolidated STR data
│   ├── strs.tsv                      # (Planned for future implementation)
│   └── version_merged.txt
└── regions/                          # Future: Consolidated region data  
    ├── regions.tsv                   # (Planned for future implementation)
    └── version_merged.txt
```

## Key Features

- ✅ **Consolidate panel data** - Combine individual panel TSV files with panel_id column
- ✅ **Cross-panel analysis** - Enable analysis across multiple panels while maintaining traceability
- ✅ **Incremental merging** - Only re-merge when panel data has been updated
- ✅ **Version tracking** - Track merge timestamps in `version_merged.txt` files
- ✅ **Multi-entity support** - Handle genes, STRs, and regions (STRs/regions planned for future)
- ✅ **Intelligent updates** - Compare panel `version_processed.txt` against merge timestamps
- ✅ **Cross-platform** - Both PowerShell and Bash implementations

## Merged Output Example

After merging, consolidated datasets include panel_id as the first column:

**`data/genes/genes.tsv`:**
```
panel_id    hgnc_symbol    ensembl_id         confidence_level    penetrance    mode_of_pathogenicity
6           COL3A1         ENSG00000168542    3                                                        
6           DAG1           ENSG00000173402    1                   unknown                             
6           FKRP           ENSG00000181027    3                                                        
7           BRCA1          ENSG00000012048    3                                 LOF_mechanism           
7           BRCA2          ENSG00000139618    3                                 LOF_mechanism           
```

## Benefits of Merged Data

- **Multi-panel analysis**: Compare genes across different panels
- **Panel coverage studies**: Identify overlapping genes between panels
- **Database integration**: Single file for loading into analysis pipelines
- **Traceability**: Panel_id maintains source panel information

## Incremental Processing

The merger includes intelligent incremental processing:

### Merge Triggers
- **Missing merged directory**: Creates new merged structure
- **Missing merged TSV file**: Regenerates consolidated file
- **Missing version_merged.txt**: No timestamp tracking available
- **Newer panel data**: Any panel's `version_processed.txt` is newer than `version_merged.txt`
- **Force flag**: Bypasses all checks and re-merges

### Version Tracking
- **version_merged.txt**: Contains timestamp of last successful merge
- **Comparison logic**: Checks all panel `version_processed.txt` files against merge timestamp
- **Cross-validation**: Ensures data consistency across panels

## Implementation Status

### Currently Implemented
- ✅ **Genes merging**: Fully functional with panel_id column
- ✅ **Incremental updates**: Version tracking and intelligent merge detection
- ✅ **Cross-platform**: Both PowerShell and Bash versions
- ✅ **Error handling**: Comprehensive validation and logging

### Future Implementation
- ⏳ **STRs merging**: Placeholder logic in place
- ⏳ **Regions merging**: Placeholder logic in place
- ⏳ **Additional entity types**: Extensible framework ready

## Requirements

### PowerShell Version
- PowerShell 5.1 or later
- Windows environment
- Valid processed panel TSV files

### Bash Version
- `bash` shell
- Unix-like environment (Linux, macOS, WSL)
- Valid processed panel TSV files

---

← [Back to Main README](../README.md)