# PanelApp Australia Complete Data Extraction Wrapper Script (PowerShell)
# This script orchestrates the complete data extraction process:
# 1. Extracts panel list data
# 2. Extracts detailed gene data for each panel
# 3. Processes gene data (converts JSON to TSV format)
# 4. Merges panel data (consolidates TSVs with panel_id column)
# 5. Creates general genelists (confidence-based, mandatory)
# 6. Creates somatic genelists (specialized, optional)
# 7. Will extract STR data (placeholder for future implementation)
# 8. Will extract region data (placeholder for future implementation)

param(
    [string]$OutputPath = ".\data",
    [string]$PanelId = "",
    [switch]$SkipGenes,
    [switch]$SkipStrs,
    [switch]$SkipRegions,
    [switch]$CreateSomaticGenelists,
    [switch]$Force,
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
        $params = @{}
        
        # Process arguments
        if ($Arguments) {
            $i = 0
            while ($i -lt $Arguments.Length) {
                $arg = $Arguments[$i]
                if ($arg.StartsWith('-')) {
                    $paramName = $arg -replace '^-', ''  # Remove leading dash
                    
                    # Check if this is a switch parameter (no value follows, or next item is another parameter)
                    if (($i + 1 -ge $Arguments.Length) -or ($Arguments[$i + 1].StartsWith('-'))) {
                        # This is a switch parameter
                        $params[$paramName] = $true
                        $i++
                    } else {
                        # This is a parameter with a value
                        $paramValue = $Arguments[$i + 1]
                        $params[$paramName] = $paramValue
                        $i += 2
                    }
                } else {
                    $i++
                }
            }
        }
        
        # Add verbose flag if specified
        if ($Verbose) {
            $params['Verbose'] = $true
        }
        
        & $ScriptPath @params
        
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
    $panelListScript = Join-Path $ScriptDir "scripts\extract_PanelList.ps1"
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
        $geneScript = Join-Path $ScriptDir "scripts\extract_Genes.ps1"
        $geneArgs = @("-DataPath", $OutputPath)
        if ($Force) { $geneArgs += "-Force" }
        if ($PanelId) { $geneArgs += @("-PanelId", $PanelId) }
        
        if (-not (Invoke-ExtractionScript -ScriptPath $geneScript -ScriptName "Gene Data Extraction" -Arguments $geneArgs)) {
            Write-Warning-Log "Gene extraction failed, but continuing with other extractions"
            $success = $false
        } else {
            # Step 2b: Process gene data (convert JSON to TSV)
            $processScript = Join-Path $ScriptDir "scripts\process_Genes.ps1"
            $processArgs = @("-DataPath", $OutputPath)
            if ($Force) { $processArgs += "-Force" }
            if ($PanelId) { $processArgs += @("-PanelId", $PanelId) }
            
            if (-not (Invoke-ExtractionScript -ScriptPath $processScript -ScriptName "Gene Data Processing" -Arguments $processArgs)) {
                Write-Warning-Log "Gene processing failed, but continuing with other extractions"
                $success = $false
            } else {
                # Step 2c: Merge panel data (consolidate TSVs with panel_id column)
                $mergeScript = Join-Path $ScriptDir "scripts\merge_Panels.ps1"
                $mergeArgs = @("-DataPath", $OutputPath)
                if ($Force) { $mergeArgs += "-Force" }
                if ($Verbose) { $mergeArgs += "-Verbose" }
                
                if (-not (Invoke-ExtractionScript -ScriptPath $mergeScript -ScriptName "Panel Data Merging" -Arguments $mergeArgs)) {
                    Write-Warning-Log "Panel data merging failed, but continuing with other extractions"
                    $success = $false
                } else {
                    # Step 2d: Create general genelists (mandatory)
                    $genelistScript = Join-Path $ScriptDir "scripts\create_Genelists.ps1"
                    $genelistArgs = @("-DataPath", $OutputPath)
                    if ($Force) { $genelistArgs += "-Force" }
                    
                    if (-not (Invoke-ExtractionScript -ScriptPath $genelistScript -ScriptName "General Genelist Creation" -Arguments $genelistArgs)) {
                        Write-Warning-Log "General genelist creation failed, but continuing with other extractions"
                        $success = $false
                    }
                    
                    # Step 2e: Create somatic genelists (optional)
                    if ($CreateSomaticGenelists) {
                        $somaticScript = Join-Path $ScriptDir "scripts\create_Somatic_genelists.ps1"
                        $somaticArgs = @("-DataPath", $OutputPath)
                        if ($Force) { $somaticArgs += "-Force" }
                        
                        if (-not (Invoke-ExtractionScript -ScriptPath $somaticScript -ScriptName "Somatic Genelist Creation" -Arguments $somaticArgs)) {
                            Write-Warning-Log "Somatic genelist creation failed, but continuing with other extractions"
                            $success = $false
                        }
                    } else {
                        Write-Log "Skipping somatic genelist creation (use -CreateSomaticGenelists to enable)"
                    }
                }
            }
        }
    } else {
        Write-Log "Skipping gene extraction, processing, and merging (--SkipGenes specified)"
    }
    
    # Step 3: Extract STR data (placeholder - future implementation)
    if (-not $SkipStrs) {
        $strScript = Join-Path $ScriptDir "scripts\extract_strs.ps1"
        $strArgs = @("-DataPath", $OutputPath)
        
        if (-not (Invoke-ExtractionScript -ScriptPath $strScript -ScriptName "STR Data Extraction" -Arguments $strArgs -Optional $true)) {
            Write-Warning-Log "STR extraction failed or not implemented yet"
        }
    } else {
        Write-Log "Skipping STR extraction (--SkipStrs specified)"
    }
    
    # Step 4: Extract region data (placeholder - future implementation)
    if (-not $SkipRegions) {
        $regionScript = Join-Path $ScriptDir "scripts\extract_regions.ps1"
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
    Write-Log "  Gene extraction: $(if ($SkipGenes) { 'Skipped' } else { 'Attempted' })"
    Write-Log "  Gene processing: $(if ($SkipGenes) { 'Skipped' } else { 'Attempted' })"
    Write-Log "  Panel data merging: $(if ($SkipGenes) { 'Skipped' } else { 'Attempted' })"
    Write-Log "  General genelists: $(if ($SkipGenes) { 'Skipped' } else { 'Attempted' })"
    Write-Log "  Somatic genelists: $(if ($SkipGenes -or -not $CreateSomaticGenelists) { 'Skipped' } else { 'Attempted' })"
    Write-Log "  STR data: $(if ($SkipStrs) { 'Skipped' } else { 'Attempted (future implementation)' })"
    Write-Log "  Region data: $(if ($SkipRegions) { 'Skipped' } else { 'Attempted (future implementation)' })"
}

# Show usage information
function Show-Usage {
    Write-Host @"
PanelApp Australia Complete Data Extraction Wrapper

DESCRIPTION:
    This script orchestrates the complete data extraction process from PanelApp Australia API.
    It runs panel list extraction, detailed data extraction for genes, data processing, merging,
    and genelist creation.

USAGE:
    .\create_PanelAppAusDB.ps1 [OPTIONS]

OPTIONS:
    -OutputPath PATH             Path to output directory (default: .\data)
    -SkipGenes                   Skip gene data extraction
    -SkipStrs                    Skip STR data extraction
    -SkipRegions                 Skip region data extraction
    -CreateSomaticGenelists      Create specialized somatic genelists (optional)
    -Force                       Force re-download all data (ignore version tracking)
    -Verbose                     Enable verbose logging
    -Help                        Show this help message

EXAMPLES:
    .\create_PanelAppAusDB.ps1                                    # Full extraction with general genelists
    .\create_PanelAppAusDB.ps1 -CreateSomaticGenelists            # Include somatic genelists
    .\create_PanelAppAusDB.ps1 -SkipGenes                         # Skip gene extraction
    .\create_PanelAppAusDB.ps1 -Force                             # Force re-download all
    .\create_PanelAppAusDB.ps1 -OutputPath "C:\MyData"            # Custom output path
    .\create_PanelAppAusDB.ps1 -Verbose -CreateSomaticGenelists   # Verbose with somatic genelists

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