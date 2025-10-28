# PanelApp Australia Gene Processing Script (PowerShell)
# This script processes downloaded gene JSON files and extracts specific fields to TSV format
# Processes all panels found in the data/panels directory
# All output files use Unix newlines (LF) for cross-platform compatibility

param(
    [string]$DataPath = "..\data",
    [string]$PanelId = "",
    [switch]$Force,
    [switch]$Verbose,
    [switch]$Help
)

# Configuration
$ErrorActionPreference = "Stop"

# Show usage information
function Show-Usage {
    Write-Host @"
PanelApp Australia Gene Processing Script

DESCRIPTION:
    This script processes downloaded gene JSON files and extracts specific fields to TSV format.
    Only processes panels that need processing based on version timestamps.

USAGE:
    .\process_Genes.ps1 [OPTIONS]

OPTIONS:
    -DataPath PATH      Path to data directory (default: ..\data)
    -PanelId ID         Process only the specified panel ID (default: process all panels)
    -Force              Force processing even if files are up to date
    -Verbose            Enable verbose logging
    -Help               Show this help message

EXAMPLES:
    .\process_Genes.ps1                          # Process all panels with incremental logic
    .\process_Genes.ps1 -PanelId 6               # Process only panel 6
    .\process_Genes.ps1 -Force                   # Force process all panels
    .\process_Genes.ps1 -DataPath "C:\MyData"    # Custom data path
    .\process_Genes.ps1 -Verbose                 # Verbose logging

"@
}

# Handle help parameter
if ($Help) {
    Show-Usage
    exit 0
}

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

# Get all panel directories
function Get-PanelDirectories {
    param([string]$DataPath, [string]$PanelId = "")
    
    $panelsPath = Join-Path $DataPath "panels"
    if (-not (Test-Path $panelsPath)) {
        Write-Error-Log "Panels directory not found: $panelsPath"
        return @()
    }
    
    if ($PanelId) {
        # Process only the specified panel
        $specificPanelPath = Join-Path $panelsPath $PanelId
        if (Test-Path $specificPanelPath) {
            return @(Get-Item $specificPanelPath)
        } else {
            Write-Error-Log "Panel directory not found: $specificPanelPath"
            return @()
        }
    } else {
        # Process all panels
        $panelDirs = Get-ChildItem -Path $panelsPath -Directory | Where-Object {
            $_.Name -match '^\d+$'  # Only numeric directory names (panel IDs)
        }
        return $panelDirs
    }
}

# Process genes for a single panel
function Process-PanelGenes {
    param([string]$PanelPath, [string]$PanelId, [hashtable]$ExpectedCounts = @{})
    
    $genesJsonPath = Join-Path $PanelPath "genes\json"
    $outputFile = Join-Path $PanelPath "genes\genes.tsv"
    
    if (-not (Test-Path $genesJsonPath)) {
        Write-Warning-Log "No genes JSON directory found for panel $PanelId"
        return $false
    }
    
    # Get all JSON files in the genes directory
    $jsonFiles = Get-ChildItem -Path $genesJsonPath -Filter "*.json" | Sort-Object Name
    
    if ($jsonFiles.Count -eq 0) {
        Write-Warning-Log "No JSON files found for panel $PanelId"
        return $false
    }
    
    Write-Log "Processing $($jsonFiles.Count) JSON files for panel $PanelId"
    
    # Create output directory if it doesn't exist
    $outputDir = Split-Path $outputFile -Parent
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    # Initialize results array
    $allGenes = @()
    
    # Process each JSON file
    foreach ($jsonFile in $jsonFiles) {
        try {
            $jsonContent = Get-Content $jsonFile.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            
            if ($jsonContent.results) {
                foreach ($gene in $jsonContent.results) {
                    # Extract required fields
                    $hgnc_symbol = if ($gene.gene_data.hgnc_symbol) { $gene.gene_data.hgnc_symbol } else { "" }
                    
                    # Extract Ensembl ID from GRch38
                    $ensembl_id = ""
                    if ($gene.gene_data.ensembl_genes.GRch38) {
                        # Get the first available version (typically "90" or similar)
                        $grch38Versions = $gene.gene_data.ensembl_genes.GRch38 | Get-Member -MemberType NoteProperty
                        if ($grch38Versions.Count -gt 0) {
                            $firstVersion = $grch38Versions[0].Name
                            $ensembl_id = $gene.gene_data.ensembl_genes.GRch38.$firstVersion.ensembl_id
                        }
                    }
                    
                    $confidence_level = if ($gene.confidence_level) { $gene.confidence_level } else { "" }
                    $penetrance = if ($gene.penetrance) { $gene.penetrance } else { "" }
                    $mode_of_pathogenicity = if ($gene.mode_of_pathogenicity) { $gene.mode_of_pathogenicity } else { "" }
                    
                    # Convert publications array to comma-separated string
                    $publications = ""
                    if ($gene.publications -and $gene.publications.Count -gt 0) {
                        $publications = $gene.publications -join ","
                    }
                    
                    $mode_of_inheritance = if ($gene.mode_of_inheritance) { $gene.mode_of_inheritance } else { "" }
                    
                    # Convert tags array to comma-separated string
                    $tags = ""
                    if ($gene.tags -and $gene.tags.Count -gt 0) {
                        $tags = $gene.tags -join ","
                    }
                    
                    # Create gene object
                    $geneObj = [PSCustomObject]@{
                        hgnc_symbol = $hgnc_symbol
                        ensembl_id = $ensembl_id
                        confidence_level = $confidence_level
                        penetrance = $penetrance
                        mode_of_pathogenicity = $mode_of_pathogenicity
                        publications = $publications
                        mode_of_inheritance = $mode_of_inheritance
                        tags = $tags
                    }
                    
                    $allGenes += $geneObj
                }
            }
        }
        catch {
            Write-Error-Log "Error processing file $($jsonFile.Name): $($_.Exception.Message)"
            continue
        }
    }
    
    if ($allGenes.Count -eq 0) {
        Write-Warning-Log "No genes found for panel $PanelId"
        return $false
    }
    
    # Convert to TSV and save
    try {
        $tsvContent = $allGenes | ConvertTo-Csv -Delimiter "`t" -NoTypeInformation
        # Remove quotation marks from CSV output
        $tsvContent = $tsvContent | ForEach-Object { $_ -replace '"', '' }
        # Write with Unix newlines
        $fileContent = $tsvContent -join "`n"
        [System.IO.File]::WriteAllText($outputFile, $fileContent, [System.Text.Encoding]::UTF8)
        
        # Validate gene count if expected count is available
        if ($ExpectedCounts.ContainsKey($PanelId)) {
            $expectedCount = $ExpectedCounts[$PanelId]
            $actualCount = $allGenes.Count
            
            if ($actualCount -eq $expectedCount) {
                Write-Success-Log "Gene count validation PASSED for panel $PanelId`: $actualCount genes (matches expected)"
            } else {
                $difference = $actualCount - $expectedCount
                $diffText = if ($difference -gt 0) { "+$difference" } else { "$difference" }
                Write-Warning-Log "Gene count validation FAILED for panel $PanelId`: $actualCount genes (expected $expectedCount, difference: $diffText)"
            }
        } else {
            Write-Log "Gene count validation skipped for panel $PanelId (no expected count available)"
        }
        
        # Create version_processed.txt with current timestamp (Unix format)
        $versionProcessedPath = Join-Path $outputDir "version_processed.txt"
        $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffffffZ"
        [System.IO.File]::WriteAllText($versionProcessedPath, $timestamp, [System.Text.Encoding]::UTF8)
        
        Write-Success-Log "Processed $($allGenes.Count) genes for panel $PanelId -> $outputFile"
        return $true
    }
    catch {
        Write-Error-Log "Error saving TSV file for panel $PanelId`: $($_.Exception.Message)"
        return $false
    }
}

# Function to check if a panel needs processing
function Test-PanelNeedsProcessing {
    param(
        [string]$PanelPath,
        [string]$PanelId
    )
    
    $genesPath = Join-Path $PanelPath "genes"
    $versionProcessedPath = Join-Path $genesPath "version_processed.txt"
    $versionCreatedPath = Join-Path $PanelPath "version_created.txt"
    $versionExtractedPath = Join-Path $PanelPath "version_extracted.txt"
    $genesTsvPath = Join-Path $genesPath "genes.tsv"
    
    Write-Log "Checking if panel $PanelId needs processing..." -Level "Info"
    
    # If Force is specified, always process
    if ($Force) {
        Write-Log "Force parameter specified - panel will be processed" -Level "Warning"
        return $true
    }
    
    # If genes.tsv doesn't exist, processing is needed
    if (-not (Test-Path $genesTsvPath)) {
        Write-Log "Panel $PanelId needs processing: genes.tsv not found" -Level "Info"
        return $true
    }
    
    # If version_processed.txt doesn't exist, processing is needed
    if (-not (Test-Path $versionProcessedPath)) {
        Write-Log "Panel $PanelId needs processing: version_processed.txt not found" -Level "Info"
        return $true
    }
    
    # Get processed date
    try {
        $processedContent = Get-Content $versionProcessedPath -Raw -Encoding UTF8
        $processedDateStr = $processedContent.Trim()
        $processedDate = [DateTime]::Parse($processedDateStr)
        Write-Log "Panel $PanelId processed date: $processedDateStr" -Level "Debug"
    }
    catch {
        Write-Log "Panel $PanelId needs processing: Invalid processed date format" -Level "Warning"
        return $true
    }
    
    # Check against version_created.txt
    if (Test-Path $versionCreatedPath) {
        try {
            $createdContent = Get-Content $versionCreatedPath -Raw -Encoding UTF8
            $createdDateStr = $createdContent.Trim()
            $createdDate = [DateTime]::Parse($createdDateStr)
            
            if ($processedDate -lt $createdDate) {
                Write-Log "Panel $PanelId needs processing: processed date ($processedDateStr) is older than created date ($createdDateStr)" -Level "Info"
                return $true
            }
        }
        catch {
            Write-Log "Panel $PanelId needs processing: Invalid created date format" -Level "Warning"
            return $true
        }
    }
    
    # Check against version_extracted.txt
    if (Test-Path $versionExtractedPath) {
        try {
            $extractedContent = Get-Content $versionExtractedPath -Raw -Encoding UTF8
            $extractedDateStr = $extractedContent.Trim()
            $extractedDate = [DateTime]::Parse($extractedDateStr)
            
            if ($processedDate -lt $extractedDate) {
                Write-Log "Panel $PanelId needs processing: processed date ($processedDateStr) is older than extracted date ($extractedDateStr)" -Level "Info"
                return $true
            }
        }
        catch {
            Write-Log "Panel $PanelId needs processing: Invalid extracted date format" -Level "Warning"
            return $true
        }
    }
    
    Write-Log "Panel $PanelId is up to date" -Level "Success"
    return $false
}

# Main execution
function Main {
    Write-Log "Starting PanelApp Australia gene processing..."
    
    try {
        if (-not (Test-Path $DataPath)) {
            Write-Error-Log "Data path does not exist: $DataPath"
            exit 1
        }
        
        # Load panel list for gene count validation
        $panelListPath = Join-Path $DataPath "panel_list\panel_list.tsv"
        $expectedCounts = @{}
        
        if (Test-Path $panelListPath) {
            Write-Log "Loading expected gene counts from panel_list.tsv"
            try {
                $panelList = Import-Csv $panelListPath -Delimiter "`t"
                foreach ($panel in $panelList) {
                    $expectedCounts[$panel.id] = [int]$panel.number_of_genes
                }
                Write-Log "Loaded expected gene counts for $($expectedCounts.Count) panels"
            }
            catch {
                Write-Warning-Log "Could not load panel_list.tsv for validation: $($_.Exception.Message)"
            }
        } else {
            Write-Warning-Log "panel_list.tsv not found - gene count validation will be skipped"
        }
        
        $panelDirs = Get-PanelDirectories -DataPath $DataPath -PanelId $PanelId
        
        if ($panelDirs.Count -eq 0) {
            if ($PanelId) {
                Write-Error-Log "Panel directory not found for panel ID: $PanelId"
            } else {
                Write-Error-Log "No panel directories found"
            }
            exit 1
        }
        
        if ($PanelId) {
            Write-Log "Processing panel $PanelId"
        } else {
            Write-Log "Found $($panelDirs.Count) panel directories to process"
        }
        
        $successful = 0
        $failed = 0
        $skipped = 0
        $validationPassed = 0
        $validationFailed = 0
        $validationSkipped = 0
        
        foreach ($panelDir in $panelDirs) {
            $panelId = $panelDir.Name
            
            # Check if panel needs processing
            if (-not (Test-PanelNeedsProcessing -PanelPath $panelDir.FullName -PanelId $panelId)) {
                $skipped++
                continue
            }
            
            if ($Verbose) {
                Write-Log "Processing panel $panelId..."
            }
            
            $result = Process-PanelGenes -PanelPath $panelDir.FullName -PanelId $panelId -ExpectedCounts $expectedCounts
            
            if ($result) {
                $successful++
                
                # Track validation results
                if ($expectedCounts.ContainsKey($panelId)) {
                    # Check if validation passed by reading the gene count from the saved file
                    $genesFile = Join-Path $panelDir.FullName "genes\genes.tsv"
                    if (Test-Path $genesFile) {
                        $actualCount = (Get-Content $genesFile | Measure-Object -Line).Lines - 1
                        if ($actualCount -lt 0) { $actualCount = 0 }
                        
                        if ($actualCount -eq $expectedCounts[$panelId]) {
                            $validationPassed++
                        } else {
                            $validationFailed++
                        }
                    }
                } else {
                    $validationSkipped++
                }
            } else {
                $skipped++
                if ($expectedCounts.ContainsKey($panelId)) {
                    $validationSkipped++
                } else {
                    $validationSkipped++
                }
            }
        }
        
        Write-Success-Log "Gene processing completed: $successful successful, $skipped skipped, $failed failed"
        
        # Validation summary
        if ($expectedCounts.Count -gt 0) {
            Write-Log ""
            Write-Log "=== GENE COUNT VALIDATION SUMMARY ==="
            Write-Success-Log "Validation passed: $validationPassed panels"
            if ($validationFailed -gt 0) {
                Write-Warning-Log "Validation failed: $validationFailed panels"
            } else {
                Write-Log "Validation failed: $validationFailed panels"
            }
            Write-Log "Validation skipped: $validationSkipped panels"
            
            $validationRate = if (($validationPassed + $validationFailed) -gt 0) {
                [math]::Round(($validationPassed / ($validationPassed + $validationFailed)) * 100, 2)
            } else { 0 }
            Write-Log "Validation success rate: $validationRate%"
        }
        
        Write-Log "Output files saved in individual panel directories as genes/genes.tsv"
    }
    catch {
        Write-Error-Log "Script execution failed: $($_.Exception.Message)"
        exit 1
    }
}

# Run main function
Main