# PanelApp Australia Panel Data Merger (PowerShell) with Validation
# This script merges all panel data into consolidated files with panel_id columns
# It processes genes.tsv, strs.tsv, and regions.tsv files from individual panels
# Includes validation to ensure output row count matches sum of input row counts

param(
    [string]$DataPath = ".\data",
    [string]$EntityType = "",
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

function Show-Help {
    @"
USAGE: merge_panels.ps1 [OPTIONS] [ENTITY_TYPE]

DESCRIPTION:
    Merges individual panel TSV files into consolidated files with panel_id columns.
    Validates that output row counts match the sum of input row counts.

PARAMETERS:
    EntityType          Type of data to merge (genes, strs, regions, or 'all')
                       If not specified, defaults to 'all'

OPTIONS:
    -DataPath <path>    Path to data directory (default: .\data)
    -Force             Skip confirmation prompts
    -Verbose           Enable verbose output
    -Help              Show this help message

EXAMPLES:
    merge_panels.ps1 genes
    merge_panels.ps1 -DataPath "C:\data" -Verbose all
    merge_panels.ps1 -Force strs

OUTPUT:
    Creates merged files in data/[entity_type]/ directories:
    - [entity_type].tsv (merged data)
    - version_merged.txt (processing info)

VALIDATION:
    The script validates that the total number of rows in the output file
    equals the sum of rows from all input files, ensuring data integrity.
"@
}

# Helper function to validate file paths
function Test-DataPath {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        Write-Error-Log "Data path does not exist: $Path"
        return $false
    }
    
    $panelsPath = Join-Path $Path "panels"
    if (-not (Test-Path $panelsPath)) {
        Write-Error-Log "Panels directory not found: $panelsPath"
        return $false
    }
    
    return $true
}

# Function to get panel directories
function Get-PanelDirectories {
    param([string]$DataPath)
    
    $panelsPath = Join-Path $DataPath "panels"
    $panelDirs = Get-ChildItem -Path $panelsPath -Directory -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name -match '^\d+$' } |
                 Sort-Object { [int]$_.Name }
    
    if (-not $panelDirs) {
        Write-Error-Log "No panel directories found in $panelsPath"
        return @()
    }
    
    Write-Verbose-Log "Found $($panelDirs.Count) panel directories"
    return $panelDirs
}

# Function to count TSV data rows (excluding header)
function Get-TSVRowCount {
    param([string]$FilePath)
    
    try {
        $lines = Get-Content $FilePath -ErrorAction Stop
        # Subtract 1 for header row, return 0 if file is empty or has only header
        return [Math]::Max(0, $lines.Count - 1)
    } catch {
        Write-Verbose-Log "Could not read file $FilePath : $($_.Exception.Message)"
        return 0
    }
}

# Function to merge panel files for a specific entity type
function Merge-PanelFiles {
    param(
        [string]$DataPath,
        [string]$EntityType,
        [array]$PanelDirectories
    )
    
    Write-Log "Starting merge for $EntityType files..."
    
    # Track input row counts for validation
    $totalInputRows = 0
    $processedPanels = 0
    
    # Find files to merge
    $filesToMerge = @()
    foreach ($panelDir in $PanelDirectories) {
        $entityDir = Join-Path $panelDir.FullName $EntityType
        $entityFile = Join-Path $entityDir "$EntityType.tsv"
        
        if (Test-Path $entityFile) {
            Write-Verbose-Log "Found $EntityType file for panel $($panelDir.Name)"
            $filesToMerge += @{
                PanelId = $panelDir.Name
                FilePath = $entityFile
            }
        } else {
            Write-Verbose-Log "No $EntityType file found for panel $($panelDir.Name)"
        }
    }
    
    if ($filesToMerge.Count -eq 0) {
        Write-Warning-Log "No $EntityType files found to merge"
        return $false
    }
    
    Write-Log "Found $($filesToMerge.Count) $EntityType files to merge"
    
    # Create output directory
    $outputDir = Join-Path $DataPath $EntityType
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        Write-Verbose-Log "Created output directory: $outputDir"
    }
    
    # Prepare output files
    $outputFile = Join-Path $outputDir "$EntityType.tsv"
    $versionFile = Join-Path $outputDir "version_merged.txt"
    
    # Initialize merged data
    $mergedData = @()
    $header = $null
    
    # Process each file
    foreach ($fileInfo in $filesToMerge) {
        $panelId = $fileInfo.PanelId
        $filePath = $fileInfo.FilePath
        
        Write-Verbose-Log "Processing panel $panelId file: $filePath"
        
        try {
            $content = Get-Content $filePath -ErrorAction Stop
            
            if ($content.Count -eq 0) {
                Write-Verbose-Log "Skipping empty file: $filePath"
                continue
            }
            
            # Process header
            $currentHeader = $content[0]
            if (-not $header) {
                $header = "panel_id`t$currentHeader"
                Write-Verbose-Log "Header: $header"
            }
            
            # Process data rows
            $dataRows = $content[1..($content.Count-1)]
            $rowCount = $dataRows.Count
            
            # Count input rows for validation
            $totalInputRows += $rowCount
            
            foreach ($row in $dataRows) {
                if ($row.Trim()) {  # Skip empty rows
                    $mergedData += "$panelId`t$row"
                }
            }
            
            Write-Verbose-Log "Added $rowCount rows from panel $panelId"
            $processedPanels++
            
        } catch {
            Write-Error-Log "Error processing $filePath : $($_.Exception.Message)"
            continue
        }
    }
    
    # Write merged data to output file
    try {
        $allContent = @($header) + $mergedData
        $allContent | Out-File -FilePath $outputFile -Encoding UTF8
        
        # Validation: Count rows in output file
        $outputRowCount = Get-TSVRowCount $outputFile
        
        # Create version info
        $versionInfo = @"
Merged on: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Script version: 2.0 (with validation)
Entity type: $EntityType
Panels processed: $processedPanels
Input files processed: $($filesToMerge.Count)
Total input rows: $totalInputRows
Output rows: $outputRowCount
Validation: $(if ($outputRowCount -eq $totalInputRows) { "PASSED" } else { "FAILED" })
"@
        $versionInfo | Out-File -FilePath $versionFile -Encoding UTF8
        
        # Perform validation check
        if ($outputRowCount -eq $totalInputRows) {
            Write-Success-Log "Validation PASSED: Output file contains $outputRowCount rows (matches input total)"
            Write-Success-Log "Created merged file: $outputFile with $outputRowCount data rows"
        } else {
            Write-Error-Log "Validation FAILED: Expected $totalInputRows rows, but output file has $outputRowCount rows"
            Write-Error-Log "Data integrity issue detected in merged file: $outputFile"
            return $false
        }
        
        Write-Success-Log "Created version file: $versionFile"
        return $true
        
    } catch {
        Write-Error-Log "Error writing output files: $($_.Exception.Message)"
        return $false
    }
}

# Main execution function
function Start-PanelMerge {
    param(
        [string]$DataPath,
        [string]$EntityType,
        [switch]$Force
    )
    
    Write-Log "Panel data merger starting..."
    Write-Verbose-Log "Data path: $DataPath"
    Write-Verbose-Log "Entity type: $EntityType"
    
    # Validate data path
    if (-not (Test-DataPath $DataPath)) {
        return $false
    }
    
    # Get panel directories
    $panelDirs = Get-PanelDirectories $DataPath
    if ($panelDirs.Count -eq 0) {
        return $false
    }
    
    # Determine entity types to process
    $entityTypes = @()
    if ($EntityType -eq "all" -or $EntityType -eq "") {
        $entityTypes = @("genes", "strs", "regions")
    } else {
        $entityTypes = @($EntityType)
    }
    
    # Validate entity types
    $validTypes = @("genes", "strs", "regions")
    foreach ($type in $entityTypes) {
        if ($type -notin $validTypes) {
            Write-Error-Log "Invalid entity type: $type. Valid types are: $($validTypes -join ', ')"
            return $false
        }
    }
    
    # Confirmation prompt
    if (-not $Force) {
        $message = "This will merge $($entityTypes -join ', ') files from $($panelDirs.Count) panels. Continue? [Y/N]"
        $response = Read-Host $message
        if ($response -notmatch '^[Yy]') {
            Write-Log "Operation cancelled by user"
            return $false
        }
    }
    
    # Process each entity type
    $success = $true
    foreach ($type in $entityTypes) {
        Write-Log "Processing $type files..."
        if (-not (Merge-PanelFiles -DataPath $DataPath -EntityType $type -PanelDirectories $panelDirs)) {
            $success = $false
            Write-Error-Log "Failed to merge $type files"
        }
    }
    
    if ($success) {
        Write-Success-Log "Panel data merger completed successfully with validation!"
    } else {
        Write-Error-Log "Panel data merger completed with errors"
    }
    
    return $success
}

# Main script execution
if ($Help) {
    Show-Help
    exit 0
}

# Set default entity type
if (-not $EntityType) {
    $EntityType = "all"
}

# Convert relative path to absolute
$DataPath = Resolve-Path $DataPath -ErrorAction SilentlyContinue
if (-not $DataPath) {
    Write-Error-Log "Invalid data path specified"
    exit 1
}

# Run the merger
$result = Start-PanelMerge -DataPath $DataPath -EntityType $EntityType -Force:$Force

# Exit with appropriate code
exit $(if ($result) { 0 } else { 1 })