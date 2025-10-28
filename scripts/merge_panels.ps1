# PanelApp Australia Panel Data Merger (PowerShell) with Validation
# This script merges all panel data into consolidated files with panel_id columns
# It processes genes.tsv, strs.tsv, and regions.tsv files from individual panels
# Includes validation to ensure output row count matches sum of input row counts
# All output files use Unix newlines (LF) for cross-platform compatibility

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
USAGE: merge_Panels.ps1 [OPTIONS] [ENTITY_TYPE]

DESCRIPTION:
    Merges individual panel TSV files into consolidated files with panel_id columns.
    Validates that output row counts match the sum of input row counts.

PARAMETERS:
    EntityType          Type of data to merge (genes, strs, regions, or 'all')
                       If not specified, defaults to 'all'

OPTIONS:
    -DataPath <path>    Path to data directory (default: .\data)
    -Force             Force overwrite existing files
    -Verbose           Enable verbose output
    -Help              Show this help message

EXAMPLES:
    merge_Panels.ps1 genes
    merge_Panels.ps1 -DataPath "C:\data" -Verbose all
    merge_Panels.ps1 -Force strs

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

# Function to validate TSV column structure
function Test-TSVColumnStructure {
    param(
        [string]$FilePath,
        [string]$ExpectedHeader,
        [string]$PanelId
    )
    
    try {
        $content = Get-Content $FilePath -ErrorAction Stop
        if ($content.Count -eq 0) {
            Write-Warning-Log "Empty file cannot be validated: $FilePath"
            return $false
        }
        
        $currentHeader = $content[0]
        $expectedColumns = $ExpectedHeader -split "`t"
        $actualColumns = $currentHeader -split "`t"
        
        # Check column count
        if ($expectedColumns.Count -ne $actualColumns.Count) {
            Write-Error-Log "Column count mismatch in panel $PanelId. Expected: $($expectedColumns.Count), Found: $($actualColumns.Count)"
            Write-Error-Log "Expected: $ExpectedHeader"
            Write-Error-Log "Found: $currentHeader"
            return $false
        }
        
        # Check column names
        for ($i = 0; $i -lt $expectedColumns.Count; $i++) {
            if ($expectedColumns[$i] -ne $actualColumns[$i]) {
                Write-Error-Log "Column name mismatch in panel $PanelId at position $($i+1). Expected: '$($expectedColumns[$i])', Found: '$($actualColumns[$i])'"
                Write-Error-Log "Expected: $ExpectedHeader"
                Write-Error-Log "Found: $currentHeader"
                return $false
            }
        }
        
        Write-Verbose-Log "Column structure validated for panel $PanelId"
        return $true
        
    } catch {
        Write-Error-Log "Error validating column structure for $FilePath : $($_.Exception.Message)"
        return $false
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
    $logFile = Join-Path $outputDir "$EntityType.tsv.log"
    
    # Initialize merged data
    $mergedData = @()
    $header = $null
    $expectedHeader = $null
    
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
            
            # Process header and validate column structure
            $currentHeader = $content[0]
            if (-not $header) {
                # First file establishes the expected column structure
                $expectedHeader = $currentHeader
                $header = "panel_id`t$currentHeader"
                Write-Verbose-Log "Header: $header"
                Write-Verbose-Log "Established column structure from panel $panelId"
            } else {
                # Validate that subsequent files have the same column structure
                if (-not (Test-TSVColumnStructure -FilePath $filePath -ExpectedHeader $expectedHeader -PanelId $panelId)) {
                    Write-Error-Log "Column structure validation failed for panel $panelId. Skipping file."
                    continue
                }
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
        # Write with Unix newlines
        $fileContent = $allContent -join "`n"
        [System.IO.File]::WriteAllText($outputFile, $fileContent, [System.Text.Encoding]::UTF8)
        
        # Validation: Count rows in output file
        $outputRowCount = Get-TSVRowCount $outputFile
        
        # Validate output file column structure
        $outputContent = Get-Content $outputFile -ErrorAction Stop
        $outputHeader = $outputContent[0]
        $expectedOutputHeader = "panel_id`t$expectedHeader"
        $columnValidationPassed = ($outputHeader -eq $expectedOutputHeader)
        
        if ($columnValidationPassed) {
            Write-Success-Log "Column structure validation PASSED: Output header matches expected format"
        } else {
            Write-Error-Log "Column structure validation FAILED: Output header mismatch"
            Write-Error-Log "Expected: $expectedOutputHeader"
            Write-Error-Log "Found: $outputHeader"
        }
        
        # Create version file with just timestamp (Unix format)
        $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffffffZ"
        [System.IO.File]::WriteAllText($versionFile, $timestamp, [System.Text.Encoding]::UTF8)
        
        # Create detailed log file with validation information
        $logInfo = @"
Merged on: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Script version: 2.1 (with row and column validation)
Entity type: $EntityType
Panels processed: $processedPanels
Input files processed: $($filesToMerge.Count)
Total input rows: $totalInputRows
Output rows: $outputRowCount
Row validation: $(if ($outputRowCount -eq $totalInputRows) { "PASSED" } else { "FAILED" })
Column validation: $(if ($columnValidationPassed) { "PASSED" } else { "FAILED" })
Expected columns: $(($expectedHeader -split "`t").Count)
Output columns: $(($outputHeader -split "`t").Count)
Timestamp: $timestamp
"@
        # Write log with Unix newlines
        [System.IO.File]::WriteAllText($logFile, $logInfo, [System.Text.Encoding]::UTF8)
        
        # Perform comprehensive validation check
        $rowValidationPassed = ($outputRowCount -eq $totalInputRows)
        $allValidationPassed = $rowValidationPassed -and $columnValidationPassed
        
        if ($allValidationPassed) {
            Write-Success-Log "All validations PASSED: Output file structure and row count are correct"
            Write-Success-Log "Created merged file: $outputFile with $outputRowCount data rows"
        } else {
            if (-not $rowValidationPassed) {
                Write-Error-Log "Row validation FAILED: Expected $totalInputRows rows, but output file has $outputRowCount rows"
            }
            if (-not $columnValidationPassed) {
                Write-Error-Log "Column validation FAILED: Output header structure does not match expected format"
            }
            Write-Error-Log "Data integrity issues detected in merged file: $outputFile"
            return $false
        }
        
        Write-Success-Log "Created version file: $versionFile"
        Write-Success-Log "Created validation log: $logFile"
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