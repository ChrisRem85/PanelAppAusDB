# Somatic Gene to Genelists Converter

## Overview

The somatic genelist scripts create confidence-based genelist files specifically for cancer and somatic-related panels. These scripts filter the consolidated gene data to include only genes from cancer predisposition, tumor, and somatic variant panels.

## Available Scripts

- **PowerShell**: `scripts/create_Somatic_genelists.ps1`
- **Bash**: `scripts/create_Somatic_genelists.sh`

## Usage

### PowerShell
```powershell
# Create somatic genelists with default settings
.\scripts\create_Somatic_genelists.ps1

# Force regeneration with verbose output
.\scripts\create_Somatic_genelists.ps1 -Force -Verbose

# Custom data path
.\scripts\create_Somatic_genelists.ps1 -DataPath "C:\data"
```

### Bash
```bash
# Create somatic genelists with default settings
./scripts/create_Somatic_genelists.sh

# Force regeneration with verbose output
./scripts/create_Somatic_genelists.sh --force --verbose

# Custom data path
./scripts/create_Somatic_genelists.sh --data-path "/path/to/data"
```

## Parameters

| Parameter | PowerShell | Bash | Description |
|-----------|------------|------|-------------|
| Data Path | `-DataPath` | `--data-path` | Path to data directory (default: `.\data` or `./data`) |
| Force | `-Force` | `--force` | Force overwrite existing files (bypass timestamp checks) |
| Verbose | `-Verbose` | `--verbose` | Enable detailed logging |
| Help | `-Help` | `--help` | Show usage information |

## Output Structure

Creates genelist files in the data directory:
```
data/
└── genelists/
    ├── genes_to_genelists.PanelAppAustralia_Somatic_Green.txt     # Confidence level 3 genes
    ├── genes_to_genelists.PanelAppAustralia_Somatic_Amber.txt     # Confidence level 2 genes
    ├── genelist.PanelAppAustralia_Somatic_GreenAmber.txt          # Simple genelist (unique IDs)
    └── version_somatic_genelists.txt                              # Processing information
```

## Somatic Panels Included

The scripts include genes from the following cancer and somatic-related panels:

| Panel ID | Panel Name |
|----------|------------|
| 152 | Cancer Predisposition_Paediatric |
| 3181 | Vascular Malformations_Somatic |
| 3279 | Melanoma |
| 3472 | Mosaic skin disorders |
| 4358 | Sarcoma soft tissue |
| 4359 | Sarcoma non-soft tissue |
| 4360 | Basal Cell Cancer |
| 4362 | Thyroid Cancer |
| 4363 | Parathyroid Tumour |
| 4364 | Pituitary Tumour |
| 4366 | Wilms Tumour |
| 4367 | Kidney Cancer |
| 4368 | Diffuse Gastric Cancer |
| 4369 | Gastrointestinal Stromal Tumour |
| 4370 | Pancreatic Cancer |
| 4371 | Colorectal Cancer and Polyposis |
| 4372 | Prostate Cancer |
| 4373 | Endometrial Cancer |
| 4374 | Ovarian Cancer |
| 4375 | Breast Cancer |

## Key Features

- ✅ **Somatic-specific filtering** - Only includes genes from cancer and somatic-related panels
- ✅ **Confidence-based separation** - Creates separate files for Green (level 3) and Amber (level 2) genes
- ✅ **Simple genelist generation** - Combined unique Ensembl IDs for easy analysis
- ✅ **Incremental processing** - Only processes when source data is newer than output files
- ✅ **Cross-platform compatibility** - Both PowerShell and Bash implementations
- ✅ **Comprehensive validation** - Ensures output files contain expected data
- ✅ **Unix newlines** - Consistent line endings across all platforms
- ✅ **Version tracking** - Records processing details and statistics
- ✅ **Empty file handling** - Creates empty files when no genes match criteria

## Output Format

### Green/Amber Files (genes_to_genelists.PanelAppAustralia_Somatic_*.txt)
```
ENSG00000012048	4375_3
ENSG00000139618	4375_3
ENSG00000141510	4374_3
```

**Format**: `ensembl_id [TAB] panel_id_confidence_level`

### Simple Genelist (genelist.PanelAppAustralia_Somatic_GreenAmber.txt)
```
ENSG00000012048
ENSG00000139618
ENSG00000141510
```

**Format**: One Ensembl gene ID per line, sorted and unique, no headers

## Column Descriptions

**Green/Amber files:**
- **Column 1**: Ensembl gene ID (ENSG identifiers)
- **Column 2**: Formatted panel identifier with confidence level suffix (e.g., `4375_3` for Breast Cancer panel, confidence level 3)

**Simple genelist file:**
- **Column 1**: Ensembl gene ID (ENSG identifiers) - unique, sorted, no headers

## Incremental Processing

The scripts use intelligent processing logic:

1. **Check timestamps**: Compare `genes/version_merged.txt` with `genelists/version_somatic_genelists.txt`
2. **Skip if current**: If genelist files are newer than merged gene data, skip processing
3. **Force mode**: Use `-Force` / `--force` to bypass timestamp checks
4. **Missing files**: Always process if output files don't exist

## Data Validation

The scripts include comprehensive validation:

- **Input validation**: Ensures merged gene data exists and is readable
- **Somatic filtering**: Validates panel IDs against the predefined somatic panel list
- **Output validation**: Confirms all output files are created and contain data
- **Count reporting**: Logs the number of genes in each confidence category
- **Error handling**: Provides detailed error messages for troubleshooting

## Dependencies

### PowerShell Version
- PowerShell 5.1 or later
- Windows environment
- Consolidated gene data (from merge_panels scripts)

### Bash Version
- `bash` shell
- `awk` command
- Unix-like environment (Linux, macOS, WSL)
- Consolidated gene data (from merge_panels scripts)

## Integration with Workflow

The somatic genelist scripts are designed to work with the complete PanelApp Australia extraction workflow:

1. **Extract panel list** → `extract_PanelList.*`
2. **Extract gene data** → `extract_Genes.*`
3. **Process gene data** → `process_Genes.*`
4. **Merge panel data** → `merge_Panels.*`
5. **Create somatic genelists** → `create_Somatic_genelists.*` ← **New Step**

The scripts require the consolidated gene data from step 4 and create somatic-specific genelist files for downstream analysis.

## Use Cases

- **Cancer research**: Focus on genes specifically associated with cancer predisposition and tumors
- **Somatic variant analysis**: Generate genelists for somatic mutation screening
- **Clinical genomics**: Create targeted gene panels for cancer-related genetic testing
- **Pipeline integration**: Provide standardized genelist files for bioinformatics workflows
- **Cross-platform analysis**: Use consistent gene lists across different analysis environments

## Requirements

- **Source data**: Requires `data/genes/genes.tsv` from merge_panels scripts
- **Panel list**: Uses panel IDs to identify cancer/somatic-related panels
- **File system**: Write access to create output directory and files
- **Cross-platform**: Works identically on Windows (PowerShell) and Unix-like systems (Bash)

---

← [Back to Main README](../README.md)