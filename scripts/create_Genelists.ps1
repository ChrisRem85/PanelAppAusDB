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
    create_Genelists.ps1 [OPTIONS]

DESCRIPTION:
    Creates genelist files from consolidated genes.tsv based on confidence levels.
    
    Generates three output files:
    - genes_to_genelists.PanelAppAustralia_Green.txt (confidence_level = 3)
    - genes_to_genelists.PanelAppAustralia_Amber.txt (confidence_level = 2)
    - genelist.PanelAppAustralia_GreenAmber.txt (all ensembl_ids, unique, no headers)
    
    Output format: 
    - Green/Amber files: ensembl_id<tab>Paus:[panel_id].[Green|Amber]
    - Simple genelist: ensembl_id only (one per line, sorted, unique)
    Files are sorted by ensembl_id, then by panel_id.
    All files use Unix newlines (LF) for cross-platform compatibility.

OPTIONS:
    -DataPath <path>    Path to data directory (default: .\data)
    -Force              Force regeneration even if files are up to date
    -Verbose            Enable verbose output
    -Help               Show this help message

EXAMPLES:
    create_Genelists.ps1
    create_Genelists.ps1 -DataPath "C:\data" -Verbose
    create_Genelists.ps1 -Force -Verbose

REQUIREMENTS:
    - Consolidated genes.tsv file in data/genes/genes.tsv
    - genes.tsv must contain: ensembl_id, confidence_level, panel_id columns

OUTPUT:
    - data/genelists/genes_to_genelists.PanelAppAustralia_Green.txt
    - data/genelists/genes_to_genelists.PanelAppAustralia_Amber.txt
    - data/genelists/genelist.PanelAppAustralia_GreenAmber.txt

"@ -ForegroundColor Yellow
}

# Check if regeneration is needed for a specific file
function Test-FileRegenerationNeeded {
    param(
        [string]$OutputFile,
        [string]$VersionFile
    )
    
    if ($Force) {
        return $true
    }
    
    if (-not (Test-Path $OutputFile)) {
        Write-Verbose-Log "Output file missing: $(Split-Path $OutputFile -Leaf)"
        return $true
    }
    
    # Check version file for timestamp comparison
    $referenceTime = $null
    if (Test-Path $VersionFile) {
        try {
            $versionContent = Get-Content $VersionFile -Raw
            if ($versionContent -and $versionContent.Trim()) {
                $referenceTime = [DateTime]::Parse($versionContent.Trim())
            }
        } catch {
            Write-Verbose-Log "Could not parse version file timestamp for $(Split-Path $OutputFile -Leaf)"
        }
    }
    
    # If no valid version timestamp, file needs regeneration
    if (-not $referenceTime) {
        Write-Verbose-Log "No valid version timestamp found, regenerating $(Split-Path $OutputFile -Leaf)"
        return $true
    }
    
    $outputTime = (Get-Item $OutputFile).LastWriteTime
    if ($referenceTime -gt $outputTime) {
        Write-Verbose-Log "Version timestamp is newer than output file: $(Split-Path $OutputFile -Leaf)"
        return $true
    }
    
    return $false
}

# Check if regeneration is needed
function Test-RegenerationNeeded {
    param(
        [string]$InputFile,
        [string[]]$OutputFiles,
        [string]$VersionFile
    )
    
    if ($Force) {
        Write-Verbose-Log "Force flag specified, regenerating files"
        return $true
    }
    
    if (-not (Test-Path $InputFile)) {
        Write-Error-Log "Input file not found: $InputFile"
        return $false
    }
    
    # Check version file for timestamp comparison
    $referenceTime = $null
    if (Test-Path $VersionFile) {
        try {
            $versionContent = Get-Content $VersionFile -Raw
            if ($versionContent -and $versionContent.Trim()) {
                $referenceTime = [DateTime]::Parse($versionContent.Trim())
                Write-Verbose-Log "Using version file timestamp: $referenceTime"
            }
        } catch {
            Write-Verbose-Log "Could not parse version file timestamp, using input file time"
        }
    }
    
    # Fall back to input file time if no valid version timestamp
    if (-not $referenceTime) {
        $referenceTime = (Get-Item $InputFile).LastWriteTime
        Write-Verbose-Log "Using input file timestamp: $referenceTime"
    }
    
    foreach ($outputFile in $OutputFiles) {
        if (-not (Test-Path $outputFile)) {
            Write-Verbose-Log "Output file missing: $(Split-Path $outputFile -Leaf)"
            return $true
        }
        
        $outputTime = (Get-Item $outputFile).LastWriteTime
        if ($referenceTime -gt $outputTime) {
            Write-Verbose-Log "Reference time is newer than output file: $(Split-Path $outputFile -Leaf)"
            return $true
        }
    }
    
    return $false
}

# Process genes.tsv and create genelist files
function New-GenelistFiles {
    param(
        [string]$GenesFile,
        [string]$OutputDir,
        [string]$VersionFile
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
        
        # Write Green genelist file (only if needed)
        $greenFile = Join-Path $OutputDir "genes_to_genelists.PanelAppAustralia_Green.txt"
        if (Test-FileRegenerationNeeded -OutputFile $greenFile -VersionFile $VersionFile) {
            $greenOutput = $greenGenes | ForEach-Object { "$($_.ensembl_id)`t$($_.genelist)" }
            if ($greenOutput.Count -eq 0) {
                Write-Error-Log "No Green genes found - output would be empty"
                return $false
            }
            # Write with Unix newlines (LF only)
            $greenContent = $greenOutput -join "`n"
            [System.IO.File]::WriteAllText($greenFile, $greenContent, [System.Text.Encoding]::UTF8)
            Write-Success-Log "Created Green genelist: $greenFile ($($greenGenes.Count) entries)"
        } else {
            Write-Log "Green genelist is up to date: $(Split-Path $greenFile -Leaf)"
        }
        
        # Write Amber genelist file (only if needed)
        $amberFile = Join-Path $OutputDir "genes_to_genelists.PanelAppAustralia_Amber.txt"
        if (Test-FileRegenerationNeeded -OutputFile $amberFile -VersionFile $VersionFile) {
            $amberOutput = $amberGenes | ForEach-Object { "$($_.ensembl_id)`t$($_.genelist)" }
            if ($amberOutput.Count -eq 0) {
                Write-Error-Log "No Amber genes found - output would be empty"
                return $false
            }
            # Write with Unix newlines (LF only)
            $amberContent = $amberOutput -join "`n"
            [System.IO.File]::WriteAllText($amberFile, $amberContent, [System.Text.Encoding]::UTF8)
            Write-Success-Log "Created Amber genelist: $amberFile ($($amberGenes.Count) entries)"
        } else {
            Write-Log "Amber genelist is up to date: $(Split-Path $amberFile -Leaf)"
        }
        
        # Write simple genelist file (all unique ensembl_ids, no headers, sorted) - only if needed
        $simpleFile = Join-Path $OutputDir "genelist.PanelAppAustralia_GreenAmber.txt"
        
        # Check if simple genelist needs regeneration (based on Green and Amber input files)
        $needsSimpleRegen = $false
        if (-not (Test-Path $simpleFile)) {
            Write-Verbose-Log "Simple genelist missing: $(Split-Path $simpleFile -Leaf)"
            $needsSimpleRegen = $true
        } elseif ($Force) {
            $needsSimpleRegen = $true
        } else {
            $simpleTime = (Get-Item $simpleFile).LastWriteTime
            $inputFiles = @($greenFile, $amberFile)
            
            foreach ($inputFile in $inputFiles) {
                if (Test-Path $inputFile) {
                    $inputTime = (Get-Item $inputFile).LastWriteTime
                    if ($inputTime -gt $simpleTime) {
                        Write-Verbose-Log "Input file is newer than simple genelist: $(Split-Path $inputFile -Leaf)"
                        $needsSimpleRegen = $true
                        break
                    }
                }
            }
        }
        
        if ($needsSimpleRegen) {
            # Read ensembl_ids from Green and Amber genelist files
            $allEnsemblIds = @()
            
            if (Test-Path $greenFile) {
                $greenIds = Get-Content $greenFile | ForEach-Object { $_.Split("`t")[0] }
                $allEnsemblIds += $greenIds
            }
            
            if (Test-Path $amberFile) {
                $amberIds = Get-Content $amberFile | ForEach-Object { $_.Split("`t")[0] }
                $allEnsemblIds += $amberIds
            }
            
            # Get unique, sorted ensembl_ids
            $uniqueEnsemblIds = @($allEnsemblIds | Where-Object { $_ -ne '' } | Sort-Object -Unique)
            
            if ($uniqueEnsemblIds.Count -eq 0) {
                Write-Error-Log "No ensembl_ids found for simple genelist - output would be empty"
                return $false
            }
            
            # Write without trailing newline
            $simpleContent = $uniqueEnsemblIds -join "`n"
            [System.IO.File]::WriteAllText($simpleFile, $simpleContent, [System.Text.Encoding]::UTF8)
            Write-Success-Log "Created simple genelist: $simpleFile ($($uniqueEnsemblIds.Count) unique ensembl_ids)"
        } else {
            Write-Log "Simple genelist is up to date: $(Split-Path $simpleFile -Leaf)"
        }
        
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
    $versionFile = Join-Path $DataPath "genes\version_merged.txt"
    $outputDir = Join-Path $DataPath "genelists"
    
    $greenFile = Join-Path $outputDir "genes_to_genelists.PanelAppAustralia_Green.txt"
    $amberFile = Join-Path $outputDir "genes_to_genelists.PanelAppAustralia_Amber.txt"
    $simpleFile = Join-Path $outputDir "genelist.PanelAppAustralia_GreenAmber.txt"
    $outputFiles = @($greenFile, $amberFile, $simpleFile)
    
    # Check if any regeneration is needed (for overall process decision)
    # Note: Simple genelist is now dependent on Green/Amber files, not version file
    $confidenceFiles = @($greenFile, $amberFile)
    $anyRegenNeeded = (Test-RegenerationNeeded -InputFile $genesFile -OutputFiles $confidenceFiles -VersionFile $versionFile)
    
    # Also check if simple genelist needs regen based on confidence files
    if (-not $anyRegenNeeded -and (Test-Path $greenFile) -and (Test-Path $amberFile)) {
        if (-not (Test-Path $simpleFile)) {
            $anyRegenNeeded = $true
        } else {
            $simpleTime = (Get-Item $simpleFile).LastWriteTime
            foreach ($confFile in $confidenceFiles) {
                if (Test-Path $confFile) {
                    $confTime = (Get-Item $confFile).LastWriteTime
                    if ($confTime -gt $simpleTime) {
                        $anyRegenNeeded = $true
                        break
                    }
                }
            }
        }
    }
    
    if (-not $anyRegenNeeded -and -not $Force) {
        Write-Log "All genelist files are up to date, skipping regeneration"
        Write-Log "Use -Force to regenerate anyway"
        return 0
    }
    
    # Process genes and create genelist files (individual files will be checked within)
    if (New-GenelistFiles -GenesFile $genesFile -OutputDir $outputDir -VersionFile $versionFile) {
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