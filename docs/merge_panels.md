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
│   ├── genes.tsv.log                 # Detailed validation and merge information
│   └── version_merged.txt            # Last merge timestamp (ISO 8601 format)
├── strs/                             # Future: Consolidated STR data
│   ├── strs.tsv                      # (Planned for future implementation)
│   ├── strs.tsv.log                  # Validation log file
│   └── version_merged.txt            # Simple timestamp tracking
└── regions/                          # Future: Consolidated region data  
    ├── regions.tsv                   # (Planned for future implementation)
    ├── regions.tsv.log               # Validation log file
    └── version_merged.txt            # Simple timestamp tracking
```

## Key Features

- ✅ **Consolidate panel data** - Combine individual panel TSV files with panel_id column
- ✅ **Cross-panel analysis** - Enable analysis across multiple panels while maintaining traceability
- ✅ **Incremental merging** - Only re-merge when panel data has been updated
- ✅ **Version tracking** - Track merge timestamps in `version_merged.txt` files
- ✅ **Multi-entity support** - Handle genes, STRs, and regions (STRs/regions planned for future)
- ✅ **Intelligent updates** - Compare panel `version_processed.txt` against merge timestamps
- ✅ **Cross-platform** - Both PowerShell and Bash implementations
- ✅ **Data validation** - Comprehensive integrity checks for merged data
- ✅ **Row count validation** - Ensures output contains sum of all input entries
- ✅ **Column structure validation** - Verifies consistent headers across all input files

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

## Data Validation

The merge process includes comprehensive validation to ensure data integrity:

### Row Count Validation
- **Purpose**: Verifies that the output file contains exactly the sum of all input file entries
- **Process**: Counts data rows (excluding headers) from all input TSV files
- **Validation**: Compares total input rows against output file row count
- **Reporting**: Success/failure status logged and recorded in version files

### Column Structure Validation
- **Purpose**: Ensures all input files have consistent column structure
- **Column Count Check**: Verifies all input TSV files have the same number of columns
- **Column Name Check**: Confirms all input files have identical column headers
- **Output Validation**: Verifies the merged output maintains the correct structure
- **Error Detection**: Catches structural inconsistencies before processing large datasets

### Validation Output
Successful validation produces detailed reports in both console logs and version files:

```
✅ Row validation: PASSED (48,257 input rows = 48,257 output rows)
✅ Column validation: PASSED (All files have matching structure)
✅ Output structure: PASSED (Correct header format maintained)
```

### Error Handling
- **Column mismatches**: Script exits with detailed error messages
- **Row count discrepancies**: Automatic failure with diagnostic information
- **Missing files**: Graceful handling with informative warnings
- **Structural issues**: Early detection prevents corrupt merged files

## Incremental Processing

The merger includes intelligent incremental processing:

### Merge Triggers
- **Missing merged directory**: Creates new merged structure
- **Missing merged TSV file**: Regenerates consolidated file
- **Missing version_merged.txt**: No timestamp tracking available
- **Newer panel data**: Any panel's `version_processed.txt` is newer than `version_merged.txt`
- **Force flag**: Bypasses all checks and re-merges

### Version Tracking
- **version_merged.txt**: Contains only an ISO 8601 timestamp of the last successful merge
- **[entity_type].tsv.log**: Contains detailed validation information and merge statistics  
- **Comparison logic**: Checks all panel `version_processed.txt` files against merge timestamp
- **Cross-validation**: Ensures data consistency across panels

### Version and Log Files

**Version File (`version_merged.txt`)**
Contains only the timestamp for simple version tracking:
```
2025-10-22T07:07:06.4593636Z
```

**Log File (`[entity_type].tsv.log`)**
Contains comprehensive validation and merge information:
```
Merged on: 2025-10-22 07:07:06
Script version: 2.1 (with row and column validation)
Entity type: genes
Panels processed: 281
Input files processed: 281
Total input rows: 48257
Output rows: 48257
Row validation: PASSED
Column validation: PASSED
Expected columns: 7
Output columns: 7
Timestamp: 2025-10-22T07:07:06.4593636Z
```

## Implementation Status

### Currently Implemented
- ✅ **Genes merging**: Fully functional with panel_id column
- ✅ **Incremental updates**: Version tracking and intelligent merge detection
- ✅ **Cross-platform**: Both PowerShell and Bash versions
- ✅ **Error handling**: Comprehensive validation and logging
- ✅ **Data integrity validation**: Row count and column structure validation
- ✅ **Validation reporting**: Detailed success/failure indicators in logs and version files

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