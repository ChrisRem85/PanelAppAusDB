# PanelApp Australia Panel Data Merger (PowerShell)
# This script merges all panel data into consolidated files with panel_id columns
# It processes genes.tsv, strs.tsv, and regions.tsv files from individual panels

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

# Show help information
function Show-Usage {
    @"
PanelApp Australia Panel Data Merger

DESCRIPTION:
    This script merges panel data files (genes.tsv, strs.tsv, regions.tsv) from individual panels
    into consolidated files with an additional panel_id column.

USAGE:
    .\merge_panels.ps1 [OPTIONS]

OPTIONS:
    -DataPath PATH      Path to data directory (default: .\data)
    -EntityType TYPE    Merge only specific entity type: genes, strs, or regions (default: all)
    -Force              Force re-merge even if up to date
    -Verbose            Enable verbose logging
    -Help               Show this help message

EXAMPLES:
    .\merge_panels.ps1                           # Merge all entity types
    .\merge_panels.ps1 -EntityType genes         # Merge only genes
    .\merge_panels.ps1 -Force                    # Force re-merge all
    .\merge_panels.ps1 -DataPath "data"          # Custom data path
    .\merge_panels.ps1 -Verbose                  # Verbose logging

OUTPUT:
    Creates merged files in:
    - data/genes/genes.tsv
    - data/strs/strs.tsv (future)
    - data/regions/regions.tsv (future)
    
    With version tracking files:
    - data/genes/version_merged.txt
    - data/strs/version_merged.txt
    - data/regions/version_merged.txt

"@
}

# Check if merge is needed for an entity type
function Test-MergeNeeded {
    param(
        [string]$DataPath,
        [string]$EntityType
    )
    
    Write-Verbose-Log "Checking if $EntityType merge is needed..."
    
    $mergedDir = Join-Path $DataPath $EntityType
    $mergedFile = Join-Path $mergedDir "$EntityType.tsv"
    $versionFile = Join-Path $mergedDir "version_merged.txt"
    
    # If Force is specified, always merge
    if ($Force) {
        Write-Verbose-Log "$EntityType merge needed: Force specified"
        return $true
    }
    
    # If merged directory doesn't exist
    if (-not (Test-Path $mergedDir)) {
        Write-Verbose-Log "$EntityType merge needed: Merged directory does not exist"
        return $true
    }
    
    # If merged file doesn't exist
    if (-not (Test-Path $mergedFile)) {
        Write-Verbose-Log "$EntityType merge needed: Merged file does not exist"
        return $true
    }
    
    # If version file doesn't exist
    if (-not (Test-Path $versionFile)) {
        Write-Verbose-Log "$EntityType merge needed: Version file does not exist"
        return $true
    }
    
    # Get the last merged date
    try {
        $lastMergedDate = Get-Content $versionFile -ErrorAction Stop | Select-Object -First 1
        $lastMergedDateTime = [DateTime]::Parse($lastMergedDate)
        Write-Verbose-Log "$EntityType last merged: $lastMergedDate"
    } catch {
        Write-Verbose-Log "$EntityType merge needed: Cannot read version file"
        return $true
    }
    
    # Check all panel version_processed files
    $panelsDir = Join-Path $DataPath "panels"
    if (-not (Test-Path $panelsDir)) {
        Write-Warning-Log "Panels directory not found: $panelsDir"
        return $false
    }
    
    $panelDirs = Get-ChildItem $panelsDir -Directory | Where-Object { $_.Name -match '^\d+$' }
    
    foreach ($panelDir in $panelDirs) {
        $panelId = $panelDir.Name
        $processedFile = Join-Path (Join-Path $panelDir.FullName $EntityType) "version_processed.txt"
        
        if (Test-Path $processedFile) {
            try {
                $processedDate = Get-Content $processedFile -ErrorAction Stop | Select-Object -First 1
                $processedDateTime = [DateTime]::Parse($processedDate)
                
                if ($processedDateTime -gt $lastMergedDateTime) {
                    Write-Verbose-Log "$EntityType merge needed: Panel $panelId processed date ($processedDate) is newer than merged date ($lastMergedDate)"
                    return $true
                }
            } catch {
                Write-Verbose-Log "$EntityType merge needed: Cannot read processed date for panel $panelId"
                return $true
            }
        }
    }
    
    Write-Verbose-Log "$EntityType is up to date"
    return $false
}

# Merge entity type data
function Merge-EntityData {
    param(
        [string]$DataPath,
        [string]$EntityType
    )
    
    Write-Log "Merging $EntityType data..."
    
    $panelsDir = Join-Path $DataPath "panels"
    $mergedDir = Join-Path $DataPath $EntityType
    $mergedFile = Join-Path $mergedDir "$EntityType.tsv"
    $versionFile = Join-Path $mergedDir "version_merged.txt"
    
    # Create merged directory if it doesn't exist
    if (-not (Test-Path $mergedDir)) {
        New-Item -Path $mergedDir -ItemType Directory -Force | Out-Null
        Write-Verbose-Log "Created directory: $mergedDir"
    }
    
    # Find all panel directories
    $panelDirs = Get-ChildItem $panelsDir -Directory | Where-Object { $_.Name -match '^\d+$' }
    
    if ($panelDirs.Count -eq 0) {
        Write-Warning-Log "No panel directories found in $panelsDir"
        return $false
    }
    
    Write-Verbose-Log "Found $($panelDirs.Count) panel directories"
    
    # Collect all TSV files
    $tsvFiles = @()
    foreach ($panelDir in $panelDirs) {
        $panelId = $panelDir.Name
        $tsvPath = Join-Path (Join-Path $panelDir.FullName $EntityType) "$EntityType.tsv"
        
        if (Test-Path $tsvPath) {
            $tsvFiles += @{
                PanelId = $panelId
                Path = $tsvPath
            }
            Write-Verbose-Log "Found $EntityType file for panel $panelId"
        } else {
            Write-Verbose-Log "No $EntityType file found for panel $panelId"
        }
    }
    
    if ($tsvFiles.Count -eq 0) {
        Write-Warning-Log "No $EntityType.tsv files found in any panel directory"
        return $false
    }
    
    Write-Log "Found $($tsvFiles.Count) $EntityType files to merge"
    
    # Process and merge files
    $allRows = @()
    $headerWritten = $false
    $header = $null
    
    foreach ($tsvFile in $tsvFiles) {
        $panelId = $tsvFile.PanelId
        $filePath = $tsvFile.Path
        
        Write-Verbose-Log "Processing panel $panelId file: $filePath"
        
        try {
            $content = Get-Content $filePath -Encoding UTF8
            
            if ($content.Count -eq 0) {
                Write-Warning-Log "Empty file: $filePath"
                continue
            }
            
            # Get header from first file
            if (-not $headerWritten) {
                $header = "panel_id`t" + $content[0]
                $headerWritten = $true
                Write-Verbose-Log "Header: $header"
            }
            
            # Process data rows (skip header)
            for ($i = 1; $i -lt $content.Count; $i++) {
                if ($content[$i].Trim() -ne "") {
                    $row = "$panelId`t" + $content[$i]
                    $allRows += $row
                }
            }
            
            Write-Verbose-Log "Added $($content.Count - 1) rows from panel $panelId"
        } catch {
            Write-Error-Log "Error processing file $filePath`: $($_.Exception.Message)"
            continue
        }
    }
    
    if ($allRows.Count -eq 0) {
        Write-Warning-Log "No data rows found to merge"
        return $false
    }
    
    # Write merged file
    try {
        $outputContent = @($header) + $allRows
        $outputContent | Out-File -FilePath $mergedFile -Encoding UTF8
        Write-Success-Log "Created merged file: $mergedFile with $($allRows.Count) data rows"
    } catch {
        Write-Error-Log "Error writing merged file $mergedFile`: $($_.Exception.Message)"
        return $false
    }
    
    # Create version file
    try {
        $currentDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $currentDate | Out-File -FilePath $versionFile -Encoding UTF8
        Write-Success-Log "Created version file: $versionFile"
    } catch {
        Write-Error-Log "Error writing version file $versionFile`: $($_.Exception.Message)"
        return $false
    }
    
    return $true
}

# Main execution function
function Main {
    if ($Help) {
        Show-Usage
        exit 0
    }
    
    Write-Log "Starting PanelApp Australia panel data merger..."
    
    # Validate data path
    if (-not (Test-Path $DataPath)) {
        Write-Error-Log "Data path not found: $DataPath"
        exit 1
    }
    
    $DataPath = Resolve-Path $DataPath
    Write-Log "Using data path: $DataPath"
    
    # Define entity types to process
    $entityTypes = if ($EntityType) { @($EntityType) } else { @("genes", "strs", "regions") }
    
    $success = $true
    
    foreach ($entityType in $entityTypes) {
        # For now, only process genes (strs and regions are future implementation)
        if ($entityType -ne "genes") {
            Write-Log "Skipping $entityType (future implementation)"
            continue
        }
        
        if (Test-MergeNeeded -DataPath $DataPath -EntityType $entityType) {
            if (-not (Merge-EntityData -DataPath $DataPath -EntityType $entityType)) {
                Write-Warning-Log "$entityType merge failed"
                $success = $false
            }
        } else {
            Write-Log "$entityType data is up to date"
        }
    }
    
    if ($success) {
        Write-Success-Log "Panel data merger completed successfully!"
    } else {
        Write-Warning-Log "Panel data merger completed with some warnings/errors"
    }
}

# Run main function
Main