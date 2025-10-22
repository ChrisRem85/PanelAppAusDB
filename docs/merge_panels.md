# PanelApp Australia Panel Data Merger

## Overview

The `merge_panels` scripts consolidate individual panel data files into unified TSV files with an additional `panel_id` column. This enables analysis across multiple panels while maintaining traceability to the source panel.

## Available Scripts

### PowerShell Version: `merge_panels.ps1`
- **Location**: `scripts/merge_panels.ps1`
- **Platform**: Windows PowerShell 5.1+
- **Purpose**: Merge panel data with incremental update support

### Bash Version: `merge_panels.sh`
- **Location**: `scripts/merge_panels.sh`
- **Platform**: Linux/macOS/WSL
- **Purpose**: Cross-platform equivalent of PowerShell version

## Usage

### PowerShell
```powershell
# Merge all entity types
.\scripts\merge_panels.ps1

# Merge only genes data
.\scripts\merge_panels.ps1 -EntityType genes

# Force re-merge even if up to date
.\scripts\merge_panels.ps1 -Force

# Custom data path with verbose logging
.\scripts\merge_panels.ps1 -DataPath "C:\data" -Verbose
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
./scripts/merge_panels.sh --data-path "/path/to/data" --verbose
```

## Parameters

| Parameter | PowerShell | Bash | Description |
|-----------|------------|------|-------------|
| Data Path | `-DataPath` | `--data-path` | Path to data directory (default: ../data) |
| Entity Type | `-EntityType` | `--entity-type` | Merge specific type: genes, strs, regions (default: all) |
| Force | `-Force` | `--force` | Force re-merge even if up to date |
| Verbose | `-Verbose` | `--verbose` | Enable detailed logging |
| Help | `-Help` | `--help` | Show usage information |

## Output Structure

The merger creates consolidated files in the following structure:

```
data/
├── genes/
│   ├── genes.tsv                    # Consolidated genes data
│   └── version_merged.txt           # Last merge timestamp
├── strs/                            # Future implementation
│   ├── strs.tsv
│   └── version_merged.txt
├── regions/                         # Future implementation
│   ├── regions.tsv
│   └── version_merged.txt
└── panels/
    └── [individual panel directories]
```

## Output Format

### Genes TSV Structure
```
panel_id    hgnc_symbol    ensembl_id         confidence_level    penetrance    mode_of_pathogenicity    publications               mode_of_inheritance
6           COL3A1         ENSG00000168542    3                                                          28742248,19455184,25205403 BIALLELIC, autosomal or pseudoautosomal
6           DAG1           ENSG00000173402    1                   unknown                              29337005                   BIALLELIC, autosomal or pseudoautosomal
```

- **panel_id**: First column containing the source panel identifier
- **Remaining columns**: Original data from individual panel TSV files

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

## Integration with Existing Workflow

The merge_panels scripts integrate seamlessly with the existing extraction pipeline:

1. **create_PanelAppAusDB** → Orchestrates panel list and gene extraction
2. **extract_genes** → Downloads raw JSON data for panels
3. **process_genes** → Converts JSON to TSV format
4. **merge_panels** → Consolidates panel TSVs with panel_id column

### Recommended Workflow
```powershell
# Complete data extraction, processing, and merging in one command
.\create_PanelAppAusDB.ps1

# Result: Consolidated cross-panel datasets ready for analysis
```

### Manual Workflow (if needed)
```powershell
# Step-by-step approach (if you need more control)
.\create_PanelAppAusDB.ps1 -SkipGenes  # Panel list only
.\scripts\extract_genes.ps1            # Gene extraction
.\scripts\process_genes.ps1            # Gene processing
.\scripts\merge_panels.ps1             # Data merging

# Result: Same consolidated datasets
```

## Example Output

After running the merger on panel 6 (Cobblestone Malformations):

```
panel_id    hgnc_symbol    ensembl_id         confidence_level
6           COL3A1         ENSG00000168542    3
6           DAG1           ENSG00000173402    1
6           FKRP           ENSG00000181027    3
6           FKTN           ENSG00000106692    3
6           LAMA2          ENSG00000196569    3
6           LAMB1          ENSG00000091136    3
6           LARGE1         ENSG00000133424    3
6           POMGNT1        ENSG00000085998    3
6           POMGNT2        ENSG00000144647    3
6           POMT1          ENSG00000168615    3
6           POMT2          ENSG00000093100    3
6           ISPD           ENSG00000103257    3
6           TMEM5          ENSG00000147526    3
```

This consolidated format enables:
- **Multi-panel analysis**: Compare genes across different panels
- **Panel coverage studies**: Identify overlapping genes between panels  
- **Database integration**: Single file for loading into analysis pipelines
- **Traceability**: Panel_id maintains source panel information

## Error Handling

The scripts include comprehensive error handling:

- **Path validation**: Verifies data directories exist
- **File validation**: Checks for required TSV files and content
- **Permission checks**: Ensures write access to output directories
- **Graceful degradation**: Continues processing if individual panels fail
- **Detailed logging**: Comprehensive status and error messages

## Performance Considerations

- **Incremental processing**: Only processes panels with updated data
- **Memory efficient**: Processes files sequentially rather than loading all in memory
- **Large dataset support**: Handles hundreds of panels efficiently
- **Progress tracking**: Verbose mode shows detailed processing status