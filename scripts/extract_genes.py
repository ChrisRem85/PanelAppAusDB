#!/usr/bin/env python3
"""
PanelApp Australia Incremental Gene Extraction Script (Python)
This script extracts gene data only for panels that have been updated since last extraction.
Tracks version_created dates and compares with previously extracted data.
"""

import argparse
import json
import os
import sys
from datetime import datetime
from pathlib import Path
import requests
from typing import Dict, List, Optional, Tuple
import csv

# Configuration
BASE_URL = "https://panelapp-aus.org/api"
API_VERSION = "v1"

def log_message(message: str, level: str = "INFO") -> None:
    """Log a message with timestamp and color coding."""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    colors = {
        "ERROR": "\033[91m",
        "SUCCESS": "\033[92m", 
        "WARNING": "\033[93m",
        "INFO": "\033[94m"
    }
    reset = "\033[0m"
    color = colors.get(level, colors["INFO"])
    print(f"\033[94m[{timestamp}]\033[0m {color}{message}{reset}")

def find_latest_data_folder(data_path: str) -> Optional[str]:
    """Find the latest data folder (YYYYMMDD format)."""
    data_dir = Path(data_path)
    
    if not data_dir.exists():
        log_message(f"Data path does not exist: {data_path}", "ERROR")
        return None
    
    # Look for date folders (YYYYMMDD format)
    date_folders = [
        d for d in data_dir.iterdir() 
        if d.is_dir() and d.name.isdigit() and len(d.name) == 8
    ]
    
    if not date_folders:
        # Try today's date
        today = datetime.now().strftime("%Y%m%d")
        today_folder = data_dir / today
        if today_folder.exists():
            log_message(f"Using today's folder: {today_folder}")
            return str(today_folder)
        else:
            log_message(f"No data folders found and today's folder doesn't exist: {today_folder}", "ERROR")
            return None
    
    # Sort by name (which is date) and get the latest
    latest_folder = sorted(date_folders, key=lambda x: x.name, reverse=True)[0]
    log_message(f"Using latest data folder: {latest_folder}")
    return str(latest_folder)

def update_panel_version_tracking(data_folder: str, panel: Dict) -> None:
    """Update version tracking file for successfully downloaded panel."""
    panel_id = panel['id']
    version_created = panel['version_created']
    
    # Ensure panel directory exists
    panel_dir = Path(data_folder) / "panels" / panel_id
    panel_dir.mkdir(parents=True, exist_ok=True)
    
    # Update version tracking file
    version_file = panel_dir / "version_created.txt"
    with open(version_file, 'w', encoding='utf-8') as f:
        f.write(version_created)
    
    log_message(f"Updated version tracking for panel {panel_id} to {version_created}")

def read_panel_data(data_folder: str) -> List[Dict]:
    """Read panel data with version information from TSV file."""
    tsv_file = Path(data_folder) / "panel_list.tsv"
    
    if not tsv_file.exists():
        log_message(f"Panel list file not found: {tsv_file}", "ERROR")
        return []
    
    panels = []
    try:
        with open(tsv_file, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f, delimiter='\t')
            
            for row_num, row in enumerate(reader, start=2):
                try:
                    panel_id = row.get('id', '').strip()
                    if panel_id and panel_id.isdigit():
                        panel = {
                            'id': panel_id,
                            'name': row.get('name', 'Unknown').strip(),
                            'version': row.get('version', 'Unknown').strip(),
                            'version_created': row.get('version_created', '').strip()
                        }
                        panels.append(panel)
                    elif panel_id:
                        log_message(f"Invalid panel ID on line {row_num}: {panel_id}", "WARNING")
                except Exception as e:
                    log_message(f"Error parsing line {row_num}: {e}", "WARNING")
                    
    except Exception as e:
        log_message(f"Error reading panel list file: {e}", "ERROR")
        return []
    
    log_message(f"Found {len(panels)} panels in panel list")
    return panels

def panel_needs_update(panel: Dict, data_folder: str, force: bool = False) -> bool:
    """Check if panel needs to be downloaded based on version file in panel directory."""
    if force:
        return True
    
    panel_id = panel['id']
    current_version_created = panel['version_created']
    
    # Check for existing version file in panel directory
    version_file = Path(data_folder) / "panels" / panel_id / "version_created.txt"
    
    if not version_file.exists():
        log_message(f"Panel {panel_id} has no version tracking file, will download")
        return True
    
    try:
        with open(version_file, 'r', encoding='utf-8') as f:
            last_version_created = f.read().strip()
        
        if not last_version_created:
            log_message(f"Panel {panel_id} has empty version file, will download")
            return True
        
        # Compare version dates
        current_date = datetime.fromisoformat(current_version_created.replace('Z', '+00:00'))
        last_date = datetime.fromisoformat(last_version_created.replace('Z', '+00:00'))
        
        if current_date > last_date:
            log_message(f"Panel {panel_id} has been updated ({last_version_created} -> {current_version_created})")
            return True
        else:
            log_message(f"Panel {panel_id} is up to date ({current_version_created})")
            return False
    except Exception as e:
        log_message(f"Error reading/parsing version file for panel {panel_id}, will download: {e}", "WARNING")
        return True

def download_panel_genes(data_folder: str, panel: Dict) -> Dict:
    """Download genes for a specific panel."""
    panel_id = panel['id']
    panel_name = panel['name']
    
    log_message(f"Extracting genes for panel {panel_id} ({panel_name})...")
    
    # Create panel-specific directory structure
    panel_dir = Path(data_folder) / "panels" / panel_id / "genes" / "json"
    panel_dir.mkdir(parents=True, exist_ok=True)
    
    # Download genes with pagination
    gene_url = f"{BASE_URL}/{API_VERSION}/panels/{panel_id}/genes/"
    page = 1
    next_url = gene_url
    
    try:
        while next_url and next_url != "null":
            log_message(f"  Downloading genes page {page} for panel {panel_id}...")
            
            response = requests.get(next_url, timeout=30)
            response.raise_for_status()
            data = response.json()
            
            # Save response to file
            response_file = panel_dir / f"genes_page_{page}.json"
            with open(response_file, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2)
            
            count = data.get('count', 0)
            next_url = data.get('next')
            results_count = len(data.get('results', []))
            
            log_message(f"    Page {page} downloaded: {results_count} genes (Total: {count})")
            
            page += 1
            
            # Safety check
            if page > 100:
                log_message(f"Safety limit reached (100 pages) for panel {panel_id}", "WARNING")
                break
        
        log_message(f"Completed gene extraction for panel {panel_id} ({page-1} pages)", "SUCCESS")
        
        return {
            'success': True,
            'panel_id': panel_id,
            'version_created': panel['version_created'],
            'extraction_date': datetime.now().isoformat() + 'Z',
            'pages_downloaded': page - 1
        }
        
    except Exception as e:
        log_message(f"Error downloading genes for panel {panel_id}: {e}", "ERROR")
        return {
            'success': False,
            'panel_id': panel_id,
            'error': str(e)
        }

def main():
    """Main execution function."""
    parser = argparse.ArgumentParser(
        description="Extract gene data incrementally from PanelApp Australia API"
    )
    parser.add_argument(
        "--data-path", 
        default="../data",
        help="Path to data directory (default: ../data)"
    )

    parser.add_argument(
        "--force",
        action="store_true",
        help="Force re-download all panels"
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable verbose logging"
    )
    
    args = parser.parse_args()
    
    log_message("Starting PanelApp Australia incremental gene extraction...")
    
    try:
        # Use data path directly (no date subfolders)
        data_folder = args.data_path
        if not os.path.exists(data_folder):
            log_message(f"Data path does not exist: {data_folder}", "ERROR")
            sys.exit(1)
        log_message(f"Using data folder: {data_folder}")
        
        # Read panel data with version information
        panels = read_panel_data(data_folder)
        if not panels:
            log_message("No panels found to process", "ERROR")
            sys.exit(1)
        
        # Filter panels that need updating
        panels_to_update = [
            panel for panel in panels 
            if panel_needs_update(panel, data_folder, args.force)
        ]
        
        if not panels_to_update:
            log_message("All panels are up to date. No downloads needed.", "SUCCESS")
            sys.exit(0)
        
        log_message(f"Will download genes for {len(panels_to_update)} panels (out of {len(panels)} total)")
        
        # Download genes for panels that need updating
        successful = 0
        failed = 0
        
        for panel in panels_to_update:
            result = download_panel_genes(data_folder, panel)
            
            if result['success']:
                successful += 1
                # Update version tracking file
                update_panel_version_tracking(data_folder, panel)
            else:
                failed += 1
        
        log_message(f"Incremental gene extraction completed: {successful} successful, {failed} failed", "SUCCESS")
        if failed > 0:
            log_message("Some panels failed. Check logs for details.", "WARNING")
        
        log_message(f"Output directory: {data_folder}")
        log_message("Version tracking files updated in individual panel directories")
        
    except Exception as e:
        log_message(f"Script execution failed: {e}", "ERROR")
        sys.exit(1)

if __name__ == "__main__":
    main()