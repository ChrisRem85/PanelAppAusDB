# PanelApp Australia Complete Data Extraction Wrapper Script (PowerShell)
# This script orchestrates the complete data extraction process:
# 1. Extracts panel list data
# 2. Extracts detailed gene data for each panel
# 3. Will extract STR data (placeholder for future implementation)
# 4. Will extract region data (placeholder for future implementation)

param(
    [string]$OutputPath = "..\data",
    [switch]$SkipGenes,
    [switch]$SkipStrs,
    [switch]$SkipRegions,
    [switch]$Verbose
)

# Configuration
$ScriptDir = $PSScriptRoot

# Logging functions
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        default { "Blue" }
    }
    Write-Host "[$timestamp] " -NoNewline -ForegroundColor Blue
    Write-Host $Message -ForegroundColor $color
}

function Write-Error-Log {
    param([string]$Message)
    Write-Log $Message "ERROR"
}

function Write-Success-Log {
    param([string]$Message)
    Write-Log $Message "SUCCESS"
}

function Write-Warning-Log {
    param([string]$Message)
    Write-Log $Message "WARNING"
}

# Execute a script and handle errors
function Invoke-ExtractionScript {
    param(
        [string]$ScriptPath,
        [string]$ScriptName,
        [array]$Arguments = @(),
        [bool]$Optional = $false
    )
    
    if (-not (Test-Path $ScriptPath)) {
        if ($Optional) {
            Write-Warning-Log "$ScriptName not found at $ScriptPath (optional - skipping)"
            return $true
        } else {
            Write-Error-Log "$ScriptName not found at $ScriptPath"
            return $false
        }
    }
    
    Write-Log "Running $ScriptName..."
    
    try {
        $params = @()
        if ($Arguments) {
            $params += $Arguments
        }
        
        # Add verbose flag if specified
        if ($Verbose) {
            $params += "-Verbose"
        }
        
        $result = & $ScriptPath @params
        
        if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $null) {
            Write-Success-Log "$ScriptName completed successfully"
            return $true
        } else {
            Write-Error-Log "$ScriptName failed with exit code $LASTEXITCODE"
            return $false
        }
    }
    catch {
        Write-Error-Log "$ScriptName failed with error: $($_.Exception.Message)"
        return $false
    }
}

# Main execution function
function Main {
    Write-Log "Starting PanelApp Australia complete data extraction..."
    
    $success = $true
    
    # Step 1: Extract panel list data
    $panelListScript = Join-Path $ScriptDir "extract_panel_list.ps1"
    $panelListArgs = @("-OutputPath", $OutputPath)
    
    if (-not (Invoke-ExtractionScript -ScriptPath $panelListScript -ScriptName "Panel List Extraction" -Arguments $panelListArgs)) {
        Write-Error-Log "Panel list extraction failed. Cannot continue."
        exit 1
    }
    
    # Use the output path directly as data folder
    $dataFolder = $OutputPath
    
    if (-not (Test-Path $dataFolder)) {
        Write-Error-Log "Data folder not found: $dataFolder"
        exit 1
    }
    
    Write-Log "Using data folder: $dataFolder"
    
    # Step 2: Extract gene data (if not skipped)
    if (-not $SkipGenes) {
        $geneScript = Join-Path $ScriptDir "extract_genes_incremental.ps1"
        $geneArgs = @("-DataPath", $OutputPath)
        
        if (-not (Invoke-ExtractionScript -ScriptPath $geneScript -ScriptName "Gene Data Extraction" -Arguments $geneArgs)) {
            Write-Warning-Log "Gene extraction failed, but continuing with other extractions"
            $success = $false
        }
    } else {
        Write-Log "Skipping gene extraction (--SkipGenes specified)"
    }
    
    # Step 3: Extract STR data (placeholder - future implementation)
    if (-not $SkipStrs) {
        $strScript = Join-Path $ScriptDir "extract_strs.ps1"
        $strArgs = @("-DataPath", $OutputPath)
        
        if (-not (Invoke-ExtractionScript -ScriptPath $strScript -ScriptName "STR Data Extraction" -Arguments $strArgs -Optional $true)) {
            Write-Warning-Log "STR extraction failed or not implemented yet"
        }
    } else {
        Write-Log "Skipping STR extraction (--SkipStrs specified)"
    }
    
    # Step 4: Extract region data (placeholder - future implementation)
    if (-not $SkipRegions) {
        $regionScript = Join-Path $ScriptDir "extract_regions.ps1"
        $regionArgs = @("-DataPath", $OutputPath)
        
        if (-not (Invoke-ExtractionScript -ScriptPath $regionScript -ScriptName "Region Data Extraction" -Arguments $regionArgs -Optional $true)) {
            Write-Warning-Log "Region extraction failed or not implemented yet"
        }
    } else {
        Write-Log "Skipping region extraction (--SkipRegions specified)"
    }
    
    # Summary
    if ($success) {
        Write-Success-Log "Complete data extraction finished successfully!"
    } else {
        Write-Warning-Log "Complete data extraction finished with some warnings/errors"
    }
    
    Write-Log "Output directory: $dataFolder"
    Write-Log ""
    Write-Log "Data extraction summary:"
    Write-Log "  Panel list: Completed"
    Write-Log "  Gene data: $(if ($SkipGenes) { 'Skipped' } else { 'Attempted' })"
    Write-Log "  STR data: $(if ($SkipStrs) { 'Skipped' } else { 'Attempted (future implementation)' })"
    Write-Log "  Region data: $(if ($SkipRegions) { 'Skipped' } else { 'Attempted (future implementation)' })"
}

# Show usage information
function Show-Usage {
    Write-Host @"
PanelApp Australia Complete Data Extraction Wrapper

DESCRIPTION:
    This script orchestrates the complete data extraction process from PanelApp Australia API.
    It runs panel list extraction followed by detailed data extraction for genes, STRs, and regions.

USAGE:
    .\extract_panels.ps1 [OPTIONS]

OPTIONS:
    -OutputPath PATH      Path to output directory (default: ..\data)
    -SkipGenes           Skip gene data extraction
    -SkipStrs            Skip STR data extraction
    -SkipRegions         Skip region data extraction
    -Verbose             Enable verbose logging
    -Help                Show this help message

EXAMPLES:
    .\extract_panels.ps1                           # Full extraction
    .\extract_panels.ps1 -SkipGenes                # Skip gene extraction
    .\extract_panels.ps1 -OutputPath "C:\MyData"   # Custom output path
    .\extract_panels.ps1 -Verbose                  # Verbose logging

"@
}

# Handle help parameter
if ($args -contains "-Help" -or $args -contains "--help" -or $args -contains "-h") {
    Show-Usage
    exit 0
}

# Run main function
try {
    Main
}
catch {
    Write-Error-Log "Wrapper script execution failed: $($_.Exception.Message)"
    exit 1
}