# PanelApp Australia Incremental Gene Extraction Script (PowerShell)
# This script extracts gene data only for panels that have been updated since last extraction
# Tracks version_created dates and compares with previously extracted data

param(
    [string]$DataPath = "..\data",
    [switch]$Verbose,
    [switch]$Force  # Force re-download all panels
)

# Configuration
$BaseURL = "https://panelapp-aus.org/api"
$APIVersion = "v1"

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

# Find the latest data folder
function Find-LatestDataFolder {
    param([string]$DataPath)
    
    if (-not (Test-Path $DataPath)) {
        Write-Error-Log "Data path does not exist: $DataPath"
        return $null
    }
    
    # Look for date folders (YYYYMMDD format)
    $dateFolders = Get-ChildItem -Path $DataPath -Directory | Where-Object {
        $_.Name -match '^\d{8}$' -and $_.Name.Length -eq 8
    } | Sort-Object Name -Descending
    
    if ($dateFolders.Count -eq 0) {
        # Try today's date
        $today = Get-Date -Format "yyyyMMdd"
        $todayFolder = Join-Path $DataPath $today
        if (Test-Path $todayFolder) {
            Write-Log "Using today's folder: $todayFolder"
            return $todayFolder
        } else {
            Write-Error-Log "No data folders found and today's folder doesn't exist: $todayFolder"
            return $null
        }
    }
    
    $latestFolder = $dateFolders[0].FullName
    Write-Log "Using latest data folder: $latestFolder"
    return $latestFolder
}

# Update version tracking file for successfully downloaded panel
function Update-PanelVersionTracking {
    param([string]$DataFolder, [hashtable]$Panel)
    
    $panelId = $Panel.Id
    $versionCreated = $Panel.VersionCreated
    
    # Ensure panel directory exists
    $panelDir = Join-Path $DataFolder "panels\$panelId"
    New-Item -ItemType Directory -Path $panelDir -Force | Out-Null
    
    # Update version tracking file
    $versionFile = Join-Path $panelDir "version_created.txt"
    $versionCreated | Out-File -FilePath $versionFile -Encoding UTF8 -NoNewline
    
    Write-Log "Updated version tracking for panel $panelId to $versionCreated"
}

# Read panel data with version information
function Read-PanelData {
    param([string]$DataFolder)
    
    $tsvFile = Join-Path $DataFolder "panel_list.tsv"
    
    if (-not (Test-Path $tsvFile)) {
        Write-Error-Log "Panel list file not found: $tsvFile"
        return @()
    }
    
    $panels = @()
    try {
        $lines = Get-Content $tsvFile -Encoding UTF8
        
        # Parse header to find column indices
        $header = $lines[0] -split "`t"
        $idIndex = [array]::IndexOf($header, "id")
        $nameIndex = [array]::IndexOf($header, "name")
        $versionIndex = [array]::IndexOf($header, "version")
        $versionCreatedIndex = [array]::IndexOf($header, "version_created")
        
        if ($idIndex -eq -1 -or $versionCreatedIndex -eq -1) {
            Write-Error-Log "Required columns 'id' or 'version_created' not found in TSV file"
            return @()
        }
        
        # Parse data rows
        for ($i = 1; $i -lt $lines.Count; $i++) {
            $fields = $lines[$i] -split "`t"
            if ($fields.Length -gt [Math]::Max($idIndex, $versionCreatedIndex) -and $fields[$idIndex] -match '^\d+$') {
                $panel = @{
                    Id = $fields[$idIndex]
                    Name = if ($nameIndex -ne -1 -and $fields.Length -gt $nameIndex) { $fields[$nameIndex] } else { "Unknown" }
                    Version = if ($versionIndex -ne -1 -and $fields.Length -gt $versionIndex) { $fields[$versionIndex] } else { "Unknown" }
                    VersionCreated = $fields[$versionCreatedIndex]
                }
                $panels += $panel
            } elseif ($fields.Length -gt 0 -and $fields[0]) {
                Write-Warning-Log "Invalid panel data on line $($i + 1): $($fields[0])"
            }
        }
    }
    catch {
        Write-Error-Log "Error reading panel list file: $($_.Exception.Message)"
        return @()
    }
    
    Write-Log "Found $($panels.Count) panels in panel list"
    return $panels
}

# Check if panel needs to be downloaded based on version file in panel directory
function Test-PanelNeedsUpdate {
    param([hashtable]$Panel, [string]$DataFolder, [bool]$Force)
    
    if ($Force) {
        return $true
    }
    
    $panelId = $Panel.Id
    $currentVersionCreated = $Panel.VersionCreated
    
    # Check for existing version file in panel directory
    $versionFile = Join-Path $DataFolder "panels\$panelId\version_created.txt"
    
    if (-not (Test-Path $versionFile)) {
        Write-Log "Panel $panelId has no version tracking file, will download" -Level "INFO"
        return $true
    }
    
    try {
        $lastVersionCreated = Get-Content $versionFile -Raw -Encoding UTF8
        $lastVersionCreated = $lastVersionCreated.Trim()
        
        if (-not $lastVersionCreated) {
            Write-Log "Panel $panelId has empty version file, will download" -Level "INFO"
            return $true
        }
        
        # Compare version dates
        $currentDate = [DateTime]::Parse($currentVersionCreated)
        $lastDate = [DateTime]::Parse($lastVersionCreated)
        
        if ($currentDate -gt $lastDate) {
            Write-Log "Panel $panelId has been updated ($lastVersionCreated -> $currentVersionCreated)" -Level "INFO"
            return $true
        } else {
            Write-Log "Panel $panelId is up to date ($currentVersionCreated)" -Level "INFO"
            return $false
        }
    }
    catch {
        Write-Warning-Log "Error reading/parsing version file for panel $panelId, will download: $($_.Exception.Message)"
        return $true
    }
}

# Download genes for a specific panel
function Get-PanelGenes {
    param([string]$DataFolder, [hashtable]$Panel)
    
    $panelId = $Panel.Id
    $panelName = $Panel.Name
    
    Write-Log "Extracting genes for panel $panelId ($panelName)..."
    
    # Create panel-specific directory structure
    $panelDir = Join-Path $DataFolder "panels\$panelId\genes\json"
    New-Item -ItemType Directory -Path $panelDir -Force | Out-Null
    
    # Download genes with pagination
    $geneUrl = "$BaseURL/$APIVersion/panels/$panelId/genes/"
    $page = 1
    $nextUrl = $geneUrl
    
    try {
        while ($nextUrl -and $nextUrl -ne "null") {
            Write-Log "  Downloading genes page $page for panel $panelId..."
            
            $response = Invoke-RestMethod -Uri $nextUrl -Method Get -ErrorAction Stop
            
            # Save response to file
            $responseFile = Join-Path $panelDir "genes_page_$page.json"
            $response | ConvertTo-Json -Depth 10 | Out-File -FilePath $responseFile -Encoding UTF8
            
            $count = $response.count
            $nextUrl = $response.next
            $resultsCount = $response.results.Count
            
            Write-Log "    Page $page downloaded: $resultsCount genes (Total: $count)"
            
            $page++
            
            # Safety check
            if ($page -gt 100) {
                Write-Warning-Log "Safety limit reached (100 pages) for panel $panelId"
                break
            }
        }
        
        Write-Success-Log "Completed gene extraction for panel $panelId ($($page-1) pages)"
        
        # Create version_extracted.txt with current timestamp
        $genesDir = Join-Path $DataFolder "panels\$panelId\genes"
        $versionExtractedPath = Join-Path $genesDir "version_extracted.txt"
        $timestamp = Get-Date -Format "yyyy-MM-ddTHH:mm:ss.fffffffZ"
        $timestamp | Out-File -FilePath $versionExtractedPath -Encoding UTF8
        
        # Return extraction metadata
        return @{
            success = $true
            panel_id = $panelId
            version_created = $Panel.VersionCreated
            extraction_date = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
            pages_downloaded = $page - 1
        }
    }
    catch {
        Write-Error-Log "Error downloading genes for panel $panelId`: $($_.Exception.Message)"
        return @{
            success = $false
            panel_id = $panelId
            error = $_.Exception.Message
        }
    }
}

# Main execution
function Main {
    Write-Log "Starting PanelApp Australia incremental gene extraction..."
    
    try {
        # Use data path directly (no date subfolders)
        $dataFolder = $DataPath
        if (-not (Test-Path $dataFolder)) {
            Write-Error-Log "Data path does not exist: $dataFolder"
            exit 1
        }
        Write-Log "Using data folder: $dataFolder"
        
        # Read panel data with version information
        $panels = Read-PanelData -DataFolder $dataFolder
        if ($panels.Count -eq 0) {
            Write-Error-Log "No panels found to process"
            exit 1
        }
        
        # Filter panels that need updating
        $panelsToUpdate = @()
        foreach ($panel in $panels) {
            if (Test-PanelNeedsUpdate -Panel $panel -DataFolder $dataFolder -Force $Force) {
                $panelsToUpdate += $panel
            }
        }
        
        if ($panelsToUpdate.Count -eq 0) {
            Write-Success-Log "All panels are up to date. No downloads needed."
            exit 0
        }
        
        Write-Log "Will download genes for $($panelsToUpdate.Count) panels (out of $($panels.Count) total)"
        
        # Download genes for panels that need updating
        $successful = 0
        $failed = 0
        
        foreach ($panel in $panelsToUpdate) {
            $result = Get-PanelGenes -DataFolder $dataFolder -Panel $panel
            
            if ($result.success) {
                $successful++
                # Update version tracking file
                Update-PanelVersionTracking -DataFolder $dataFolder -Panel $panel
            } else {
                $failed++
            }
        }
        
        Write-Success-Log "Incremental gene extraction completed: $successful successful, $failed failed"
        if ($failed -gt 0) {
            Write-Warning-Log "Some panels failed. Check logs for details."
        }
        
        Write-Log "Output directory: $dataFolder"
        Write-Log "Version tracking files updated in individual panel directories"
    }
    catch {
        Write-Error-Log "Script execution failed: $($_.Exception.Message)"
        exit 1
    }
}

# Run main function
Main