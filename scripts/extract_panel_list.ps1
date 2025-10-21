# PanelApp Australia Data Extraction Script (PowerShell)
# This script extracts panel data from the PanelApp Australia API
# Creates a folder for the current date and downloads all panels with pagination

param(
    [string]$OutputPath = "..\data"
)

# Configuration
$BaseURL = "https://panelapp-aus.org/api"
$APIVersion = "v1"
$SwaggerURL = "https://panelapp-aus.org/api/docs/?format=openapi"
$ExpectedAPIVersion = "v1"

# Enable TLS 1.2 for web requests
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

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

# Create output folder structure
function New-OutputFolder {
    param([string]$OutputPath)
    
    Write-Log "Setting up output folder: $OutputPath"
    
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }
    
    $jsonPath = Join-Path $OutputPath "panel_list\json"
    if (-not (Test-Path $jsonPath)) {
        New-Item -ItemType Directory -Path $jsonPath -Force | Out-Null
        Write-Success-Log "Created folder structure: $jsonPath"
    } else {
        Write-Log "Using existing folder structure: $jsonPath"
    }
    
    return $OutputPath
}

# Check API version
function Test-APIVersion {
    Write-Log "Checking API version..."
    
    try {
        $response = Invoke-RestMethod -Uri $SwaggerURL -Method Get -ErrorAction Stop
        
        $apiVersion = $response.info.version
        
        if (-not $apiVersion) {
            Write-Error-Log "Could not determine API version from swagger documentation"
            exit 1
        }
        
        Write-Log "Current API version: $apiVersion"
        
        if ($apiVersion -ne $ExpectedAPIVersion) {
            Write-Warning-Log "API version mismatch! Expected: $ExpectedAPIVersion, Found: $apiVersion"
            Write-Warning-Log "Continuing with execution, but results may vary..."
        } else {
            Write-Success-Log "API version matches expected version: $ExpectedAPIVersion"
        }
    }
    catch {
        Write-Error-Log "Failed to fetch swagger documentation: $($_.Exception.Message)"
        exit 1
    }
}

# Download panels with pagination
function Get-PanelData {
    param([string]$OutputDir)
    
    $panelURL = "$BaseURL/$APIVersion/panels/"
    $page = 1
    $nextURL = $panelURL
    
    Write-Log "Starting panel data extraction..."
    
    while ($nextURL -and $nextURL -ne "null") {
        Write-Log "Downloading page $page..."
        
        $responseFile = Join-Path $OutputDir "panel_list\json\panels_page_$page.json"
        
        try {
            $response = Invoke-RestMethod -Uri $nextURL -Method Get -ErrorAction Stop
            
            # Save response to file
            $response | ConvertTo-Json -Depth 10 | Out-File -FilePath $responseFile -Encoding UTF8
            
            $count = $response.count
            $nextURL = $response.next
            $resultsCount = $response.results.Count
            
            Write-Success-Log "Page $page downloaded: $resultsCount panels (Total in API: $count)"
            
            $page++
            
            # Safety check to prevent infinite loops
            if ($page -gt 1000) {
                Write-Error-Log "Safety limit reached (1000 pages). Stopping to prevent infinite loop."
                break
            }
        }
        catch {
            Write-Error-Log "Error downloading page $page`: $($_.Exception.Message)"
            if (Test-Path $responseFile) {
                Remove-Item $responseFile -Force
            }
            exit 1
        }
    }
    
    Write-Success-Log "Panel data extraction completed. Downloaded $($page-1) pages."
}

# Extract panel information from JSON files and save version tracking
function Export-PanelInfo {
    param([string]$OutputDir)
    
    $jsonDir = Join-Path $OutputDir "panel_list\json"
    $tsvFile = Join-Path $OutputDir "panel_list.tsv"
    
    Write-Log "Extracting panel information from JSON files..."
    
    # Create TSV header
    "id`tname`tversion`tversion_created`tnumber_of_genes`tnumber_of_strs`tnumber_of_regions" | Out-File -FilePath $tsvFile -Encoding UTF8
    
    $fileCount = 0
    $panelCount = 0
    $panels = @()
    
    Get-ChildItem -Path $jsonDir -Filter "panels_page_*.json" | ForEach-Object {
        $fileCount++
        
        try {
            $jsonContent = Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            
            foreach ($panel in $jsonContent.results) {
                $panelInfo = [PSCustomObject]@{
                    id = $panel.id
                    name = $panel.name
                    version = $panel.version
                    version_created = $panel.version_created
                    number_of_genes = $panel.stats.number_of_genes
                    number_of_strs = $panel.stats.number_of_strs
                    number_of_regions = $panel.stats.number_of_regions
                }
                $panels += $panelInfo
                $panelCount++
                
                # Create individual panel directory and save version tracking
                $panelDir = Join-Path $OutputDir "panels\$($panel.id)"
                New-Item -ItemType Directory -Path $panelDir -Force | Out-Null
                
                $versionFile = Join-Path $panelDir "version_created.txt"
                $panel.version_created | Out-File -FilePath $versionFile -Encoding UTF8 -NoNewline
                
                Write-Log "  Created version tracking for panel $($panel.id): $($panel.version_created)" -Level "INFO"
            }
        }
        catch {
            Write-Error-Log "Error processing file $($_.Name): $($_.Exception.Message)"
        }
    }
    
    # Export to TSV
    $panels | ForEach-Object {
        "$($_.id)`t$($_.name)`t$($_.version)`t$($_.version_created)`t$($_.number_of_genes)`t$($_.number_of_strs)`t$($_.number_of_regions)"
    } | Add-Content -Path $tsvFile -Encoding UTF8
    
    Write-Success-Log "Extracted information from $fileCount files containing $panelCount panels"
    Write-Success-Log "Summary saved to: $tsvFile"
    Write-Success-Log "Version tracking files saved in individual panel directories"
    
    # Display first few lines of the summary
    if (Test-Path $tsvFile) {
        Write-Log "First 5 entries in summary:"
        Get-Content $tsvFile | Select-Object -First 6 | ForEach-Object {
            Write-Host "  $_" -ForegroundColor Gray
        }
    }
}

# Main execution
function Main {
    Write-Log "Starting PanelApp Australia data extraction..."
    
    try {
        # Create output folder structure
        $outputDir = New-OutputFolder -OutputPath $OutputPath
        
        # Check API version
        Test-APIVersion
        
        # Download panels
        Get-PanelData -OutputDir $outputDir
        
        # Extract panel information
        Export-PanelInfo -OutputDir $outputDir
        
        Write-Success-Log "Data extraction completed successfully!"
        Write-Log "Output directory: $outputDir"
    }
    catch {
        Write-Error-Log "Script execution failed: $($_.Exception.Message)"
        exit 1
    }
}

# Run main function
Main