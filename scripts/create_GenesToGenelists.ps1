# PanelApp Australia Gene to Genelists Converter (PowerShell)
# This script converts genes.tsv to genelist format files based on confidence levels
# Creates separate files for Green (confidence_level 3) and Amber (confidence_level 2) genes

param(
    [string]$DataPath = ".\data",
    [switch]$Force,
    [switch]$Verbose,
    [switch]$Help
)

# Set strict mode for better error handling
Set-StrictMode -Version Latest

# Configuration
$script:VerboseMode = $Verbose.IsPresent

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
    create_GenesToGenelists.ps1 [OPTIONS]

DESCRIPTION:
    Creates genelist files from consolidated genes.tsv based on confidence levels.
    
    Generates two output files:
    - genes_to_genelists.PanelAppAustralia_Green.txt (confidence_level = 3)
    - genes_to_genelists.PanelAppAustralia_Amber.txt (confidence_level = 2)
    
    Output format: ensembl_id<tab>Paus:[panel_id].[Green|Amber]
    Files are sorted by ensembl_id, then by panel_id.

OPTIONS:
    -DataPath <path>    Path to data directory (default: .\data)
    -Force              Force regeneration even if files are up to date
    -Verbose            Enable verbose output
    -Help               Show this help message

EXAMPLES:
    create_GenesToGenelists.ps1
    create_GenesToGenelists.ps1 -DataPath "C:\data" -Verbose
    create_GenesToGenelists.ps1 -Force -Verbose

REQUIREMENTS:
    - Consolidated genes.tsv file in data/genes/genes.tsv
    - genes.tsv must contain: ensembl_id, confidence_level, panel_id columns

OUTPUT:
    - data/genelists/genes_to_genelists.PanelAppAustralia_Green.txt
    - data/genelists/genes_to_genelists.PanelAppAustralia_Amber.txt

"@ -ForegroundColor Yellow
}

# Check if regeneration is needed
function Test-RegenerationNeeded {
    param(
        [string]$InputFile,
        [string[]]$OutputFiles
    )
    
    if ($Force) {
        Write-Verbose-Log "Force flag specified, regenerating files"
        return $true
    }
    
    if (-not (Test-Path $InputFile)) {
        Write-Error-Log "Input file not found: $InputFile"
        return $false
    }
    
    $inputTime = (Get-Item $InputFile).LastWriteTime
    
    foreach ($outputFile in $OutputFiles) {
        if (-not (Test-Path $outputFile)) {
            Write-Verbose-Log "Output file missing: $(Split-Path $outputFile -Leaf)"
            return $true
        }
        
        $outputTime = (Get-Item $outputFile).LastWriteTime
        if ($inputTime -gt $outputTime) {
            Write-Verbose-Log "Input file is newer than output file: $(Split-Path $outputFile -Leaf)"
            return $true
        }
    }
    
    return $false
}

# Process genes.tsv and create genelist files
function New-GenelistFiles {
    param(
        [string]$GenesFile,
        [string]$OutputDir
    )
    
    try {
        Write-Log "Reading genes data from: $GenesFile"
        
        # Read the TSV file
        $genes = Import-Csv -Path $GenesFile -Delimiter "`t"
        
        $genesCount = @($genes).Count
        Write-Log "Loaded $genesCount gene entries"
        
        # Validate required columns
        $requiredColumns = @('ensembl_id', 'confidence_level', 'panel_id')
        $availableColumns = @($genes[0].PSObject.Properties.Name)
        $missingColumns = @($requiredColumns | Where-Object { $_ -notin $availableColumns })
        
        if ($missingColumns.Count -gt 0) {
            Write-Error-Log "Missing required columns in genes.tsv: $($missingColumns -join ', ')"
            Write-Verbose-Log "Available columns: $($availableColumns -join ', ')"
            return $false
        }
        
        Write-Verbose-Log "Required columns validated successfully"
        
        # Filter and process genes by confidence level
        Write-Verbose-Log "Filtering genes by confidence level"
        
        # Green genes (confidence_level = 3)
        $greenGenes = @($genes | Where-Object { $_.confidence_level -eq '3' -and $_.ensembl_id -ne '' } | 
                       Select-Object @{Name='ensembl_id'; Expression={$_.ensembl_id}}, 
                                     @{Name='genelist'; Expression={"Paus:$($_.panel_id).Green"}} |
                       Sort-Object ensembl_id, genelist)
        
        # Amber genes (confidence_level = 2)
        $amberGenes = @($genes | Where-Object { $_.confidence_level -eq '2' -and $_.ensembl_id -ne '' } | 
                       Select-Object @{Name='ensembl_id'; Expression={$_.ensembl_id}}, 
                                     @{Name='genelist'; Expression={"Paus:$($_.panel_id).Amber"}} |
                       Sort-Object ensembl_id, genelist)
        
        Write-Log "Green genes (confidence_level 3): $($greenGenes.Count) entries"
        Write-Log "Amber genes (confidence_level 2): $($amberGenes.Count) entries"
        
        # Create output directory if it doesn't exist
        if (-not (Test-Path $OutputDir)) {
            New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
            Write-Verbose-Log "Created output directory: $OutputDir"
        }
        
        # Write Green genelist file
        $greenFile = Join-Path $OutputDir "genes_to_genelists.PanelAppAustralia_Green.txt"
        $greenOutput = $greenGenes | ForEach-Object { "$($_.ensembl_id)`t$($_.genelist)" }
        $greenOutput | Out-File -FilePath $greenFile -Encoding UTF8
        Write-Success-Log "Created Green genelist: $greenFile ($($greenGenes.Count) entries)"
        
        # Write Amber genelist file
        $amberFile = Join-Path $OutputDir "genes_to_genelists.PanelAppAustralia_Amber.txt"
        $amberOutput = $amberGenes | ForEach-Object { "$($_.ensembl_id)`t$($_.genelist)" }
        $amberOutput | Out-File -FilePath $amberFile -Encoding UTF8
        Write-Success-Log "Created Amber genelist: $amberFile ($($amberGenes.Count) entries)"
        
        return $true
        
    } catch {
        Write-Error-Log "Error processing genes data: $($_.Exception.Message)"
        return $false
    }
}

# Main execution
function Main {
    if ($Help) {
        Show-Usage
        return 0
    }
    
    Write-Log "PanelApp Australia Gene to Genelists Converter starting..."
    
    # Validate data path
    if (-not (Test-Path $DataPath)) {
        Write-Error-Log "Data directory not found: $DataPath"
        return 1
    }
    
    # Define paths
    $genesFile = Join-Path $DataPath "genes\genes.tsv"
    $outputDir = Join-Path $DataPath "genelists"
    
    $greenFile = Join-Path $outputDir "genes_to_genelists.PanelAppAustralia_Green.txt"
    $amberFile = Join-Path $outputDir "genes_to_genelists.PanelAppAustralia_Amber.txt"
    $outputFiles = @($greenFile, $amberFile)
    
    # Check if regeneration is needed
    if (-not (Test-RegenerationNeeded -InputFile $genesFile -OutputFiles $outputFiles)) {
        Write-Log "Genelist files are up to date, skipping regeneration"
        Write-Log "Use -Force to regenerate anyway"
        return 0
    }
    
    # Process genes and create genelist files
    if (New-GenelistFiles -GenesFile $genesFile -OutputDir $outputDir) {
        Write-Success-Log "Gene to genelists conversion completed successfully"
        Write-Log "Output directory: $outputDir"
        return 0
    } else {
        Write-Error-Log "Gene to genelists conversion failed"
        return 1
    }
}

# Run main function
exit (Main)