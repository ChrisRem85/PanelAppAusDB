# PanelApp Australia Somatic Gene to Genelists Converter (PowerShell)
# This script converts genes.tsv to somatic-specific genelist format files based on confidence levels
# Creates separate files for Green (confidence_level 3) and Amber (confidence_level 2) genes
# Only includes genes from cancer and somatic-related panels

param(
    [string]$DataPath = ".\data",
    [ValidateSet("panels", "tags", "combined")]
    [string]$FilterMethod = "combined",
    [switch]$Force,
    [switch]$Verbose,
    [switch]$Help
)

# Set strict mode for better error handling
Set-StrictMode -Version Latest

# Configuration
$script:VerboseMode = $Verbose.IsPresent

# Define somatic/cancer-related panel IDs based on panel names
$script:SomaticPanelIds = @(
    152,   # Cancer Predisposition_Paediatric
    3181,  # Vascular Malformations_Somatic
    3279,  # Melanoma
    3472,  # Mosaic skin disorders
    4358,  # Sarcoma soft tissue
    4359,  # Sarcoma non-soft tissue
    4360,  # Basal Cell Cancer
    4362,  # Thyroid Cancer
    4363,  # Parathyroid Tumour
    4364,  # Pituitary Tumour
    4366,  # Wilms Tumour
    4367,  # Kidney Cancer
    4368,  # Diffuse Gastric Cancer
    4369,  # Gastrointestinal Stromal Tumour
    4370,  # Pancreatic Cancer
    4371,  # Colorectal Cancer and Polyposis
    4372,  # Prostate Cancer
    4373,  # Endometrial Cancer
    4374,  # Ovarian Cancer
    4375   # Breast Cancer
)

# Logging functions
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "Cyan" }
    }
    Write-Host "[$timestamp] $Message" -ForegroundColor $color
}

function Write-Error-Log {
    param([string]$Message)
    Write-Log $Message "ERROR"
}

function Write-Warning-Log {
    param([string]$Message)
    Write-Log $Message "WARNING"
}

function Write-Success-Log {
    param([string]$Message)
    Write-Log $Message "SUCCESS"
}

function Write-Verbose-Log {
    param([string]$Message)
    if ($script:VerboseMode) {
        Write-Log $Message "INFO"
    }
}

# Show usage information
function Show-Usage {
    Write-Host @"
USAGE:
    create_Somatic_genelists.ps1 [OPTIONS]

DESCRIPTION:
    Creates somatic-specific genelist files from consolidated genes.tsv based on confidence levels.
    Supports multiple filtering methods to identify cancer and somatic-related genes.
    
    Generates three output files:
    - genes_to_genelists.PanelAppAustralia_Somatic_Green.txt (confidence_level = 3)
    - genes_to_genelists.PanelAppAustralia_Somatic_Amber.txt (confidence_level = 2)
    - genelist.PanelAppAustralia_Somatic_GreenAmber.txt (all ensembl_ids, unique, no headers)
    
    Output format: 
    - Green/Amber files: ensembl_id [TAB] panel_id_confidence
    - Simple genelist: ensembl_id only (one per line, sorted, unique)

OPTIONS:
    -DataPath <path>      Path to data directory (default: .\data)
    -FilterMethod <method> Filtering method: "panels", "tags", or "combined" (default: combined)
                          - panels: Use cancer/somatic/mosaic panel IDs 
                          - tags: Use genes with somatic/cancer/mosaic tags  
                          - combined: Use both approaches for maximum coverage
    -Force                Force overwrite existing files
    -Verbose              Enable verbose output
    -Help                 Show this help message

EXAMPLES:
    create_Somatic_genelists.ps1
    create_Somatic_genelists.ps1 -FilterMethod "tags" -Verbose
    create_Somatic_genelists.ps1 -DataPath "C:\data" -FilterMethod "panels"
    create_Somatic_genelists.ps1 -Force

SOMATIC PANELS INCLUDED:
    Cancer Predisposition_Paediatric (152), Vascular Malformations_Somatic (3181),
    Melanoma (3279), Mosaic skin disorders (3472), Sarcoma soft tissue (4358), 
    Sarcoma non-soft tissue (4359), Basal Cell Cancer (4360), Thyroid Cancer (4362), 
    Parathyroid Tumour (4363), Pituitary Tumour (4364), Wilms Tumour (4366), 
    Kidney Cancer (4367), Diffuse Gastric Cancer (4368), 
    Gastrointestinal Stromal Tumour (4369), Pancreatic Cancer (4370), 
    Colorectal Cancer and Polyposis (4371), Prostate Cancer (4372), 
    Endometrial Cancer (4373), Ovarian Cancer (4374), Breast Cancer (4375)

OUTPUT:
    Creates genelist files in data/genelists/ directory with version tracking.

"@
}

# Handle help parameter
if ($Help) {
    Show-Usage
    exit 0
}

# Helper function to validate file paths
function Test-DataPath {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        Write-Error-Log "Data path does not exist: $Path"
        return $false
    }
    
    $genesPath = Join-Path $Path "genes"
    if (-not (Test-Path $genesPath)) {
        Write-Error-Log "Genes directory not found: $genesPath"
        Write-Error-Log "Please run the merge_panels script first to create consolidated gene data"
        return $false
    }
    
    return $true
}

# Check if processing is needed
function Test-ProcessingNeeded {
    param([string]$DataPath, [switch]$Force)
    
    $outputDir = Join-Path $DataPath "genelists"
    $versionFile = Join-Path $outputDir "version_somatic_genelists.txt"
    $genesFile = Join-Path $DataPath "genes\genes.tsv"
    $genesVersionFile = Join-Path $DataPath "genes\version_merged.txt"
    
    # If force is specified, always process
    if ($Force) {
        Write-Verbose-Log "Force parameter specified - processing will run"
        return $true
    }
    
    # If output directory doesn't exist, processing is needed
    if (-not (Test-Path $outputDir)) {
        Write-Verbose-Log "Output directory doesn't exist - processing needed"
        return $true
    }
    
    # If version file doesn't exist, processing is needed
    if (-not (Test-Path $versionFile)) {
        Write-Verbose-Log "Version file doesn't exist - processing needed"
        return $true
    }
    
    # If genes file doesn't exist, cannot process
    if (-not (Test-Path $genesFile)) {
        Write-Error-Log "Source genes.tsv file not found: $genesFile"
        Write-Error-Log "Please run the merge_panels script first"
        return $false
    }
    
    # Compare timestamps if both version files exist
    if ((Test-Path $genesVersionFile) -and (Test-Path $versionFile)) {
        $genesTime = (Get-Item $genesVersionFile).LastWriteTime
        $genelisTime = (Get-Item $versionFile).LastWriteTime
        
        if ($genesTime -gt $genelisTime) {
            Write-Verbose-Log "Genes data is newer than genelists - processing needed"
            return $true
        } else {
            Write-Log "Somatic genelist files are up to date"
            return $false
        }
    }
    
    return $true
}

# Validate output files have content
function Test-OutputFiles {
    param([string]$OutputDir)
    
    $greenFile = Join-Path $OutputDir "genes_to_genelists.PanelAppAustralia_Somatic_Green.txt"
    $amberFile = Join-Path $OutputDir "genes_to_genelists.PanelAppAustralia_Somatic_Amber.txt"
    $simpleFile = Join-Path $OutputDir "genelist.PanelAppAustralia_Somatic_GreenAmber.txt"
    
    $filesValid = $true
    
    # Check each file exists and has content
    foreach ($file in @($greenFile, $amberFile, $simpleFile)) {
        if (-not (Test-Path $file)) {
            Write-Error-Log "Output file not created: $file"
            $filesValid = $false
        } else {
            $content = Get-Content $file -ErrorAction SilentlyContinue
            if (-not $content -or $content.Count -eq 0) {
                Write-Error-Log "Output file is empty: $file"
                $filesValid = $false
            } else {
                Write-Verbose-Log "Output file validated: $file ($($content.Count) lines)"
            }
        }
    }
    
    return $filesValid
}

# Process genes.tsv and create somatic genelist files
function New-SomaticGenelistFiles {
    param([string]$GenesFile, [string]$OutputDir, [string]$VersionFile, [string]$FilterMethod)
    
    Write-Log "Reading genes data from: $GenesFile"
    Write-Log "Using filter method: $FilterMethod"
    
    # Check if input file exists
    if (-not (Test-Path $GenesFile)) {
        Write-Error-Log "Genes file not found: $GenesFile"
        return $false
    }
    
    # Import genes data
    try {
        $genesData = Import-Csv $GenesFile -Delimiter "`t"
        Write-Log "Loaded $($genesData.Count) total genes from merged data"
    }
    catch {
        Write-Error-Log "Failed to read genes file: $($_.Exception.Message)"
        return $false
    }
    
    # Filter genes based on selected method
    $somaticGenes = @()
    switch ($FilterMethod) {
        "panels" {
            $somaticGenes = $genesData | Where-Object { 
                $panelId = [int]$_.panel_id
                $script:SomaticPanelIds -contains $panelId 
            }
            Write-Log "Panel-based filtering: Found $($somaticGenes.Count) genes in somatic panels"
        }
        "tags" {
            $somaticGenes = $genesData | Where-Object { 
                $_.tags -match "somatic|cancer|mosaic"
            }
            Write-Log "Tag-based filtering: Found $($somaticGenes.Count) genes with somatic/cancer/mosaic tags"
        }
        "combined" {
            $panelGenes = $genesData | Where-Object { 
                $panelId = [int]$_.panel_id
                $script:SomaticPanelIds -contains $panelId 
            }
            $tagGenes = $genesData | Where-Object { 
                $_.tags -match "somatic|cancer|mosaic"
            }
            # Combine and deduplicate by ensembl_id
            $allIds = ($panelGenes + $tagGenes) | Select-Object -ExpandProperty ensembl_id | Sort-Object | Get-Unique
            $somaticGenes = $genesData | Where-Object { $allIds -contains $_.ensembl_id }
            Write-Log "Combined filtering: Found $($panelGenes.Count) panel genes + $($tagGenes.Count) tag genes = $($somaticGenes.Count) total genes"
        }
    }
    
    if ($somaticGenes.Count -eq 0) {
        Write-Warning-Log "No genes found in somatic panels"
        return $false
    }
    
    Write-Log "Found $($somaticGenes.Count) genes in somatic panels"
    
    # Filter by confidence levels
    $greenGenes = $somaticGenes | Where-Object { $_.confidence_level -eq "3" }
    $amberGenes = $somaticGenes | Where-Object { $_.confidence_level -eq "2" }
    
    Write-Log "Green genes (confidence 3): $($greenGenes.Count)"
    Write-Log "Amber genes (confidence 2): $($amberGenes.Count)"
    
    # Create output directory
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        Write-Verbose-Log "Created output directory: $OutputDir"
    }
    
    # Generate Green genelist
    $greenFile = Join-Path $OutputDir "genes_to_genelists.PanelAppAustralia_Somatic_Green.txt"
    if ($greenGenes.Count -gt 0) {
        $greenContent = $greenGenes | ForEach-Object {
            "$($_.ensembl_id)`t$($_.panel_id)_3"
        }
        $greenFileContent = $greenContent -join "`n"
        [System.IO.File]::WriteAllText($greenFile, $greenFileContent, [System.Text.Encoding]::UTF8)
        Write-Success-Log "Created Green genelist: $greenFile ($($greenGenes.Count) genes)"
    } else {
        # Create empty file to maintain consistency
        [System.IO.File]::WriteAllText($greenFile, "", [System.Text.Encoding]::UTF8)
        Write-Warning-Log "Created empty Green genelist: $greenFile (no confidence level 3 genes)"
    }
    
    # Generate Amber genelist  
    $amberFile = Join-Path $OutputDir "genes_to_genelists.PanelAppAustralia_Somatic_Amber.txt"
    if ($amberGenes.Count -gt 0) {
        $amberContent = $amberGenes | ForEach-Object {
            "$($_.ensembl_id)`t$($_.panel_id)_2"
        }
        $amberFileContent = $amberContent -join "`n"
        [System.IO.File]::WriteAllText($amberFile, $amberFileContent, [System.Text.Encoding]::UTF8)
        Write-Success-Log "Created Amber genelist: $amberFile ($($amberGenes.Count) genes)"
    } else {
        # Create empty file to maintain consistency
        [System.IO.File]::WriteAllText($amberFile, "", [System.Text.Encoding]::UTF8)
        Write-Warning-Log "Created empty Amber genelist: $amberFile (no confidence level 2 genes)"
    }
    
    # Generate simple genelist (unique Ensembl IDs only, sorted)
    $simpleFile = Join-Path $OutputDir "genelist.PanelAppAustralia_Somatic_GreenAmber.txt"
    $allEnsemblIds = ($greenGenes + $amberGenes) | Select-Object -ExpandProperty ensembl_id | Sort-Object | Get-Unique
    
    if ($allEnsemblIds.Count -gt 0) {
        $simpleFileContent = $allEnsemblIds -join "`n"
        [System.IO.File]::WriteAllText($simpleFile, $simpleFileContent, [System.Text.Encoding]::UTF8)
        Write-Success-Log "Created simple genelist: $simpleFile ($($allEnsemblIds.Count) unique genes)"
    } else {
        # Create empty file to maintain consistency
        [System.IO.File]::WriteAllText($simpleFile, "", [System.Text.Encoding]::UTF8)
        Write-Warning-Log "Created empty simple genelist: $simpleFile (no genes found)"
    }
    
    # Update version tracking
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $versionContent = @"
Somatic genelist creation completed: $timestamp
Filter method: $FilterMethod
Source file: $GenesFile
Green genes (confidence 3): $($greenGenes.Count)
Amber genes (confidence 2): $($amberGenes.Count)
Total unique genes: $($allEnsemblIds.Count)
Somatic panels available: $($script:SomaticPanelIds.Count)
"@
    [System.IO.File]::WriteAllText($VersionFile, $versionContent, [System.Text.Encoding]::UTF8)
    Write-Verbose-Log "Updated version tracking: $VersionFile"
    
    return $true
}

# Main execution function
function Start-SomaticGenelistCreation {
    param([string]$DataPath, [string]$FilterMethod, [switch]$Force)
    
    Write-Log "Somatic genelist creation starting..."
    Write-Verbose-Log "Data path: $DataPath"
    Write-Verbose-Log "Filter method: $FilterMethod"
    
    # Validate data path
    if (-not (Test-DataPath $DataPath)) {
        return $false
    }
    
    # Check if processing is needed
    if (-not (Test-ProcessingNeeded $DataPath -Force:$Force)) {
        return $true
    }
    
    # Set up paths
    $genesFile = Join-Path $DataPath "genes\genes.tsv"
    $outputDir = Join-Path $DataPath "genelists"
    $versionFile = Join-Path $outputDir "version_somatic_genelists.txt"
    
    # Create somatic genelist files
    if (-not (New-SomaticGenelistFiles $genesFile $outputDir $versionFile $FilterMethod)) {
        Write-Error-Log "Failed to create somatic genelist files"
        return $false
    }
    
    # Validate output files
    if (-not (Test-OutputFiles $outputDir)) {
        Write-Error-Log "Output file validation failed"
        return $false
    }
    
    Write-Success-Log "Somatic genelist creation completed successfully!"
    Write-Log "Output directory: $outputDir"
    
    return $true
}

# Run main function
if (-not (Start-SomaticGenelistCreation $DataPath $FilterMethod -Force:$Force)) {
    exit 1
}