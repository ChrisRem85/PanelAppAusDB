# PanelApp Australia Gene Extraction Script (PowerShell)
# This script extracts gene data for each panel listed in panel_list.tsv
# Reads panel IDs from the TSV file and downloads genes with pagination

param(
    [string]$DataPath = "..\data",
    [string]$Folder = "",
    [switch]$Verbose
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

# Read panel IDs from panel_list.tsv
function Read-PanelList {
    param([string]$DataFolder)
    
    $tsvFile = Join-Path $DataFolder "panel_list.tsv"
    
    if (-not (Test-Path $tsvFile)) {
        Write-Error-Log "Panel list file not found: $tsvFile"
        return @()
    }
    
    $panelIds = @()
    try {
        $lines = Get-Content $tsvFile -Encoding UTF8
        # Skip header (first line)
        for ($i = 1; $i -lt $lines.Count; $i++) {
            $fields = $lines[$i] -split "`t"
            if ($fields.Length -gt 0 -and $fields[0] -match '^\d+$') {
                $panelIds += $fields[0]
            } elseif ($fields.Length -gt 0 -and $fields[0]) {
                Write-Warning-Log "Invalid panel ID on line $($i + 1): $($fields[0])"
            }
        }
    }
    catch {
        Write-Error-Log "Error reading panel list file: $($_.Exception.Message)"
        return @()
    }
    
    Write-Log "Found $($panelIds.Count) panels to process"
    return $panelIds
}

# Download genes for a specific panel
function Get-PanelGenes {
    param([string]$DataFolder, [string]$PanelId)
    
    Write-Log "Extracting genes for panel $PanelId..."
    
    # Create panel-specific directory structure
    $panelDir = Join-Path $DataFolder "panels\$PanelId\genes\json"
    New-Item -ItemType Directory -Path $panelDir -Force | Out-Null
    
    # Download genes with pagination
    $geneUrl = "$BaseURL/$APIVersion/panels/$PanelId/genes/"
    $page = 1
    $nextUrl = $geneUrl
    
    try {
        while ($nextUrl -and $nextUrl -ne "null") {
            Write-Log "  Downloading genes page $page for panel $PanelId..."
            
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
                Write-Warning-Log "Safety limit reached (100 pages) for panel $PanelId"
                break
            }
        }
        
        Write-Success-Log "Completed gene extraction for panel $PanelId ($($page-1) pages)"
        return $true
    }
    catch {
        Write-Error-Log "Error downloading genes for panel $PanelId`: $($_.Exception.Message)"
        return $false
    }
}

# Main execution
function Main {
    Write-Log "Starting PanelApp Australia gene extraction..."
    
    try {
        # Determine data folder
        if ($Folder) {
            $dataFolder = Join-Path $DataPath $Folder
            if (-not (Test-Path $dataFolder)) {
                Write-Error-Log "Specified folder does not exist: $dataFolder"
                exit 1
            }
            Write-Log "Using specified folder: $dataFolder"
        } else {
            $dataFolder = Find-LatestDataFolder -DataPath $DataPath
            if (-not $dataFolder) {
                exit 1
            }
        }
        
        # Read panel list
        $panelIds = Read-PanelList -DataFolder $dataFolder
        if ($panelIds.Count -eq 0) {
            Write-Error-Log "No panels found to process"
            exit 1
        }
        
        # Download genes for each panel
        $successful = 0
        $failed = 0
        
        foreach ($panelId in $panelIds) {
            if (Get-PanelGenes -DataFolder $dataFolder -PanelId $panelId) {
                $successful++
            } else {
                $failed++
            }
        }
        
        Write-Success-Log "Gene extraction completed: $successful successful, $failed failed"
        if ($failed -gt 0) {
            Write-Warning-Log "Some panels failed. Check logs for details."
        }
        
        Write-Log "Output directory: $dataFolder"
    }
    catch {
        Write-Error-Log "Script execution failed: $($_.Exception.Message)"
        exit 1
    }
}

# Run main function
Main