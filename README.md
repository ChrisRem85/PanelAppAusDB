# PanelApp Australia Database Extractor

A comprehensive toolkit for automatically extracting and processing data from the [PanelApp Australia API](https://panelapp-aus.org/api/docs/). This project provides both wrapper scripts for complete automation and individual scripts for fine-grained control.

## 🔑 API Token Required

**PanelApp Australia requires an API token for automated access.**

To get your API token:
1. Contact PanelApp Australia at their [contact page](https://panelapp-aus.org/about/contact/)
2. Explain your use case (research, clinical, etc.)
3. They will provide you with an authorization token

Once you have your token, see the **Configuration** section below for setup instructions.

This project includes built-in rate limiting and secure token storage to be respectful of their infrastructure.

## 🚀 Quick Start

### Complete Data Extraction (Recommended)

Use the main wrapper scripts for full automation:

**Windows PowerShell:**
```powershell
# Complete extraction workflow (no prompts)
.\create_PanelAppAusDB.ps1

# Skip gene extraction (panel list only)
.\create_PanelAppAusDB.ps1 -SkipGenes

# Force re-download all data with detailed logging
.\create_PanelAppAusDB.ps1 -Force -Verbose
```

**Linux/macOS/WSL:**
```bash
# Complete extraction workflow
./create_PanelAppAusDB.sh

# With custom output path
./create_PanelAppAusDB.sh --output-path "data"
```

## 🎯 Key Features

- **🔄 Complete Automation**: Single-command workflow from API to analysis-ready data
- **📊 Cross-Panel Analysis**: Consolidated datasets with panel_id columns for multi-panel research
- **🔍 Incremental Processing**: Smart version tracking to avoid unnecessary re-downloads
- **✅ Built-in Validation**: Comprehensive data integrity checks including row count and column structure validation
- **🏷️ Tag Extraction**: Automatic extraction of gene tags as comma-separated values in output
- **� Clean File Structure**: Separated version tracking (timestamps) from detailed validation logs
- **�🖥️ Cross-Platform**: Both PowerShell (Windows) and Bash (Linux/macOS/WSL) versions
- **📈 Comprehensive Logging**: Detailed progress tracking and colored output
- **🚫 No Prompts**: Streamlined execution without user confirmation prompts

## 🛠️ What Gets Extracted

| Data Type | Status | Description |
|-----------|---------|-------------|
| **Panel Metadata** | ✅ Ready | Panel information, versions, gene counts |
| **Gene Data** | ✅ Ready | Detailed gene information with confidence levels |
| **Panel Merging** | ✅ Ready | Consolidated cross-panel datasets |
| **STR Data** | ⏳ Planned | Short Tandem Repeat information |
| **Region Data** | ⏳ Planned | Genomic region definitions |

## 💻 System Requirements

### Windows (PowerShell)
- PowerShell 5.1 or later
- Internet access

### Linux/macOS/WSL (Bash)
- `bash` shell
- `curl` command  
- `jq` JSON processor
- Internet access

## 📦 Installation

```bash
git clone https://github.com/ChrisRem85/PanelAppAusDB.git
cd PanelAppAusDB
```

**Dependencies:**
- **Windows**: No additional setup required
- **Linux/macOS**: Install `jq` if not available (`sudo apt-get install jq` or `brew install jq`)

### ⚙️ Configuration (Required Before First Use)

**API Token Setup:**

1. **Copy the configuration template:**
   ```powershell
   # Windows PowerShell
   Copy-Item scripts\config.ps1.template scripts\config.ps1
   ```
   ```bash
   # Linux/macOS/WSL
   cp scripts/config.sh.template scripts/config.sh
   ```

2. **Edit the config file** with your API token:
   - Windows: Edit `scripts/config.ps1`
   - Linux/macOS: Edit `scripts/config.sh`

3. **Add your API token** (obtained from PanelApp Australia):
   ```powershell
   # PowerShell
   $APIToken = "your-api-token-here"
   ```
   ```bash
   # Bash
   API_TOKEN="your-api-token-here"
   ```

4. **(Optional)** Update your contact information:
   ```powershell
   $UserAgent = "PanelAppAusDB-Extractor/1.0 (GitHub:ChrisRem85/PanelAppAusDB; your.email@institution.edu)"
   ```

✅ **Your token is safe:** Config files are already in `.gitignore` and won't be committed to Git.

📖 **See [scripts/README.md](scripts/README.md) for detailed configuration options.**

## 📖 Usage Guide

### Main Wrapper Scripts

The `create_PanelAppAusDB` scripts provide complete automation for the entire data extraction workflow:

**Windows PowerShell:**
```powershell
# Set execution policy if needed
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process

# Complete workflow (recommended)
.\create_PanelAppAusDB.ps1

# Panel list extraction only
.\create_PanelAppAusDB.ps1 -SkipGenes

# Force complete re-download
.\create_PanelAppAusDB.ps1 -Force -Verbose

# Specific panel with custom output path
.\create_PanelAppAusDB.ps1 -PanelId 6 -OutputPath "data" -Verbose
```

**Linux/macOS/WSL:**
```bash
# Make executable (first time only)
chmod +x create_PanelAppAusDB.sh

# Complete workflow (recommended)  
./create_PanelAppAusDB.sh

# Custom output directory
./create_PanelAppAusDB.sh --output-path "custom_data"
```

### Wrapper Script Parameters

| Parameter | PowerShell | Bash | Description |
|-----------|------------|------|-------------|
| Output Path | `-OutputPath` | `--output-path` | Custom data directory |
| Skip Genes | `-SkipGenes` | N/A | Extract panel list only |
| Panel ID | `-PanelId` | N/A | Process specific panel only |
| Force | `-Force` | N/A | Force complete re-download |
| Verbose | `-Verbose` | N/A | Detailed logging |

### Individual Script Documentation

For advanced usage or specific requirements, detailed documentation is available for each component:

#### 📋 Core Processing Steps

1. **[Panel List Extraction](docs/extract_PanelList.md)**
   - Extract comprehensive panel metadata from PanelApp Australia API
   - Creates `panel_list.tsv` with panel information and statistics

2. **[Gene Data Extraction](docs/extract_Genes.md)**  
   - Download detailed gene data for each panel with incremental updates
   - Version tracking and intelligent change detection

3. **[Gene Data Processing](docs/process_Genes.md)**
   - Convert raw JSON data to structured TSV format
   - Built-in validation and automatic missing file detection

4. **[Panel Data Merging](docs/merge_Panels.md)**
   - Consolidate individual panel data into cross-panel datasets with comprehensive validation
   - Enables multi-panel analysis with panel_id traceability and data integrity verification

5. **[Gene to Genelists Conversion](docs/create_Genelists.md)**
   - Convert consolidated genes data to specialized genelist format files
   - Separate files for different confidence levels (Green/Amber) with standardized formatting

#### 📚 Complete Documentation Index

### Detailed Script Documentation

This section provides comprehensive information about all individual scripts for advanced users and specific use cases.

#### Core Extraction Scripts

1. **[Panel List Extraction](docs/extract_PanelList.md)**
   - Extract panel metadata from PanelApp Australia API
   - Creates `panel_list.tsv` with comprehensive panel information
   - Available in PowerShell and Bash versions

2. **[Gene Data Extraction](docs/extract_Genes.md)**
   - Download detailed gene data for each panel
   - Incremental extraction with version tracking
   - Available in PowerShell and Bash versions

3. **[Gene Data Processing](docs/process_Genes.md)**
   - Convert JSON gene data to structured TSV format
   - Built-in validation and missing file detection
   - Available in PowerShell and Bash versions

4. **[Panel Data Merging](docs/merge_Panels.md)**
   - Consolidate individual panel data into cross-panel datasets with validation
   - Adds panel_id columns for traceability with data integrity checks
   - Available in PowerShell and Bash versions with comprehensive validation

5. **[Gene to Genelists Conversion](docs/create_Genelists.md)**
   - Convert consolidated genes data to specialized genelist format files
   - Separate files for different confidence levels (Green/Amber) with standardized formatting
   - Available in PowerShell and Bash versions

6. **[Somatic Gene to Genelists Conversion](docs/create_Somatic_genelists.md)**
   - Create cancer/somatic-specific genelist files from consolidated data
   - Filters for cancer predisposition, tumor, and somatic variant panels only
   - Available in PowerShell and Bash versions

#### Script Comparison Matrix

| Feature | Panel List | Gene Extraction | Gene Processing | Panel Merging | Genelists | Somatic Genelists |
|---------|------------|----------------|----------------|---------------|-----------|-------------------|
| **Input** | PanelApp API | Panel List + API | JSON files | Individual TSV files | Consolidated genes.tsv | Consolidated genes.tsv |
| **Output** | panel_list.tsv | genes/*.json | genes.tsv + tags | genes/genes.tsv + logs | Confidence-based genelists | Cancer-specific genelists |
| **Version Tracking** | ❌ | ✅ | ✅ | ✅ (separated files) | ✅ | ✅ |
| **Incremental Updates** | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Cross-platform** | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Validation** | ❌ | ❌ | ✅ | ✅ (comprehensive) | ✅ | ✅ |
| **Tag Extraction** | ❌ | ❌ | ✅ | ✅ (preserved) | ❌ | ❌ |
| **User Prompts** | ❌ | ❌ | ❌ | ❌ | ❌ | ❌ |

#### Platform Support

All scripts are available in two versions:

- **PowerShell (.ps1)**: Windows PowerShell 5.1+
- **Bash (.sh)**: Linux/macOS/WSL with standard Unix tools

#### Getting Started Guide

- **Most users**: Use the main wrapper scripts (`create_PanelAppAusDB.*`) for complete automation
- **Advanced users**: Use individual scripts for specific requirements and fine-grained control
- **Developers**: Refer to individual script documentation for detailed parameters and usage

### Workflow Overview

The complete extraction process follows this sequence:

```mermaid
graph LR
    A[Panel List] --> B[Gene Extraction]
    B --> C[Gene Processing with Tags] 
    C --> D[Data Merging with Validation]
    D --> I[Genelist Creation]
    A --> E[panel_list.tsv]
    B --> F[genes/*.json]
    C --> G[genes.tsv + tags]
    D --> H[genes/genes.tsv + validation logs]
    I --> J[Green/Amber genelists]
```

**Automated by `create_PanelAppAusDB` scripts** with streamlined execution (no prompts) or run individually using the scripts in the `scripts/` directory.

## 📁 Output Structure

The extraction process creates a well-organized directory structure:

```
data/
├── panel_list/
│   └── panel_list.tsv                # ← Summary of all panels
├── genes/  
│   ├── genes.tsv                     # ← Consolidated cross-panel gene data with tags
│   ├── version_merged.txt            # ← Clean timestamp (no validation details)
│   └── genes.tsv.log                 # ← Detailed validation log
├── genelists/
│   ├── genes_to_genelists.PanelAppAustralia_Green.txt  # ← High confidence genes (level 3)
│   ├── genes_to_genelists.PanelAppAustralia_Amber.txt  # ← Moderate confidence genes (level 2)
│   ├── genelist.PanelAppAustralia_GreenAmber.txt       # ← All unique ensembl_ids (simple format)
│   ├── version_genelists.txt                          # ← Genelist creation timestamp
│   ├── genes_to_genelists.PanelAppAustralia_Somatic_Green.txt  # ← Cancer/somatic high confidence
│   ├── genes_to_genelists.PanelAppAustralia_Somatic_Amber.txt  # ← Cancer/somatic moderate confidence
│   └── genelist.PanelAppAustralia_Somatic_GreenAmber.txt       # ← Unique cancer/somatic ensembl_ids
└── panels/[panel_id]/
    └── genes/
        ├── json/                     # Raw API data
        ├── genes.tsv                 # Individual panel gene data with tags
        └── version_processed.txt     # Processing timestamp
```

### Key Output Files

| File | Description |
|------|-------------|
| **`panel_list.tsv`** | Complete panel metadata and statistics |
| **`genes/genes.tsv`** | **Cross-panel consolidated gene dataset with tags** |
| **`genes/version_merged.txt`** | Clean merge timestamp (no trailing newlines) |
| **`genes/genes.tsv.log`** | Detailed validation results and metrics |
| **`genelists/*.txt`** | **Confidence-based genelist files and simple ensembl_id list for external tools** |
| **`genelists/version_genelists.txt`** | **Genelist creation timestamp (ISO 8601 UTC format)** |
| **`panels/*/genes.tsv`** | Individual panel gene data with extracted tags |

> **💡 Pro Tip**: The consolidated `genes/genes.tsv` file includes a `panel_id` column and extracted tags, making it perfect for cross-panel analysis and research. All version files now use clean timestamps without trailing newlines for better automation compatibility.

## 🔍 Data Overview

### Panel Information
Each panel includes comprehensive metadata: ID, name, version, creation date, and entity counts (genes, STRs, regions).

### Gene Data Structure  
Detailed gene information with confidence levels, inheritance patterns, phenotypes, external database references (HGNC, OMIM, etc.), and extracted tags as comma-separated values.

**📖 [View detailed data specifications →](docs/README.md)**

## ⚙️ Configuration

All configuration is embedded within the scripts for simplicity. Default settings work for most users:

- **API Endpoint**: `https://panelapp-aus.org/api/v1`
- **Output Directory**: `data/` (relative to script location)
- **Safety Limits**: 10,000 pages maximum to prevent infinite loops

To modify settings, edit the configuration variables at the top of each script file.

## 📚 Documentation Navigation

### Quick Links
- **[📖 Complete Documentation](docs/README.md)** - Comprehensive guide to all scripts
- **[📋 Panel List Scripts](docs/extract_PanelList.md)** - Extract panel metadata  
- **[🧬 Gene Extraction Scripts](docs/extract_Genes.md)** - Download gene data
- **[⚡ Gene Processing Scripts](docs/process_Genes.md)** - Convert JSON to TSV
- **[🔀 Panel Merging Scripts](docs/merge_Panels.md)** - Create consolidated datasets
- **[📝 Genelist Converter Scripts](docs/create_Genelists.md)** - Generate confidence-based genelists
- **[🧬 Somatic Genelist Scripts](docs/create_Somatic_genelists.md)** - Generate cancer/somatic-specific genelists

### External Resources
- **[PanelApp Australia API](https://panelapp-aus.org/api/docs/)** - Official API documentation
- **[OpenAPI/Swagger Docs](https://panelapp-aus.org/api/docs/?format=openapi)** - Interactive API explorer

## 🔧 Technical Details

### API Information
- **Endpoint**: `https://panelapp-aus.org/api/v1`
- **Current Status**: ~283 panels available (October 2025)
- **Pagination**: ~100 panels per page, 3 total pages

### Error Handling
All scripts include comprehensive error handling for HTTP requests, JSON parsing, file system operations, and API version compatibility.

### Data Validation
The merge_panels scripts include comprehensive validation features:
- **Row Count Validation**: Ensures output contains the exact sum of all input file entries
- **Column Structure Validation**: Verifies consistent column names and counts across all input files
- **Integrity Reporting**: Detailed validation results in both logs and version files
- **File Structure**: Clean separation of version tracking (timestamp-only files) from detailed validation logs

### Output Format
All TSV files use tab-separated values with headers, compatible with Excel, R, Python pandas, and other analysis tools.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Add tests if applicable  
5. Submit a pull request

## 📄 License

This project is open source. Please check the LICENSE file for details.

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/ChrisRem85/PanelAppAusDB/issues)
- **API Problems**: [PanelApp Australia API Docs](https://panelapp-aus.org/api/docs/)
- **Documentation**: Check error logs and [detailed documentation](docs/README.md)

---

## 📋 Changelog

### Version 2.3.0 (Current)
- **NEW**: Version tracking for genelist creation - automatic `version_genelists.txt` file generation
- **NEW**: ISO 8601 UTC timestamp format with nanosecond precision for genelist version tracking
- **ENHANCED**: Both PowerShell and Bash genelist scripts now create version files automatically
- **ENHANCED**: Consistent version file formatting across all script components

### Version 2.2.0
- **NEW**: Tag extraction feature - genes now include tags as comma-separated values in final column
- **NEW**: Clean file structure - separated version files (timestamp only) from detailed validation logs
- **ENHANCED**: Removed confirmation prompts for streamlined automation
- **ENHANCED**: Cross-platform consistency - all features implemented in both PowerShell and Bash versions
- **ENHANCED**: Improved validation logging with structured output files

### Version 2.1.0
- **NEW**: Comprehensive data validation in `merge_panels` scripts
- **NEW**: Row count validation ensures output contains sum of all input entries
- **NEW**: Column structure validation verifies consistent headers across all input files
- **ENHANCED**: Detailed validation reporting with success/failure indicators
- **ENHANCED**: Version tracking includes validation results and metrics

### Version 2.0.0
- **NEW**: Complete workflow automation with `create_PanelAppAusDB` wrapper scripts
- **NEW**: Panel data merging for cross-panel analysis with `merge_panels` scripts
- **NEW**: Comprehensive documentation restructure with dedicated `docs/` folder
- **ENHANCED**: Incremental processing with intelligent version tracking
- **ENHANCED**: Built-in validation and error handling across all scripts

### Version 1.2.0  
- **BREAKING**: Separated gene extraction into dedicated scripts
- **NEW**: Individual processing scripts for genes (`extract_genes.*`, `process_genes.*`)
- **ENHANCED**: Command-line options and auto-detection features

### Version 1.1.0
- **NEW**: Panel statistics (gene, STR, region counts) in TSV output
- **ENHANCED**: Data extraction to include comprehensive panel metadata

### Version 1.0.0
- **INITIAL**: Core extraction scripts for Bash and PowerShell
- **FEATURES**: API version checking, pagination, TSV output generation