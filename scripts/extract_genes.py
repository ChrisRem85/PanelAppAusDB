#!/usr/bin/env python3
"""
PanelApp Australia Gene Extraction Script (Python)

This script extracts gene data for each panel listed in panel_list.tsv.
Reads panel IDs from the TSV file and downloads genes with pagination.
"""

import os
import json
import requests
import argparse
import logging
from datetime import datetime
from pathlib import Path
from typing import Optional, Dict, List, Any


class PanelGeneExtractor:
    """Class to handle PanelApp Australia gene extraction for panels."""
    
    def __init__(self, data_path: str = "../data"):
        self.base_url = "https://panelapp-aus.org/api"
        self.api_version = "v1"
        self.data_path = Path(data_path)
        self.session = requests.Session()
        
        # Setup logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        self.logger = logging.getLogger(__name__)
    
    def find_latest_data_folder(self) -> Optional[Path]:
        """Find the most recent data folder or use today's date."""
        if not self.data_path.exists():
            self.logger.error(f"Data path does not exist: {self.data_path}")
            return None
        
        # Look for date folders (YYYYMMDD format)
        date_folders = []
        for folder in self.data_path.iterdir():
            if folder.is_dir() and folder.name.isdigit() and len(folder.name) == 8:
                try:
                    # Validate it's a proper date
                    datetime.strptime(folder.name, '%Y%m%d')
                    date_folders.append(folder)
                except ValueError:
                    continue
        
        if not date_folders:
            # Use today's date if no folders found
            today = datetime.now().strftime("%Y%m%d")
            today_folder = self.data_path / today
            if today_folder.exists():
                return today_folder
            else:
                self.logger.error(f"No data folders found and today's folder doesn't exist: {today_folder}")
                return None
        
        # Return the most recent folder
        latest_folder = max(date_folders, key=lambda x: x.name)
        self.logger.info(f"Using data folder: {latest_folder}")
        return latest_folder
    
    def read_panel_list(self, data_folder: Path) -> List[str]:
        """Read panel IDs from panel_list.tsv file."""
        tsv_file = data_folder / "panel_list.tsv"
        
        if not tsv_file.exists():
            self.logger.error(f"Panel list file not found: {tsv_file}")
            return []
        
        panel_ids = []
        try:
            with open(tsv_file, 'r', encoding='utf-8') as f:
                # Skip header
                next(f)
                for line_num, line in enumerate(f, 2):
                    fields = line.strip().split('\t')
                    if fields and fields[0].isdigit():
                        panel_ids.append(fields[0])
                    elif fields and fields[0]:  # Non-empty but not digit
                        self.logger.warning(f"Invalid panel ID on line {line_num}: {fields[0]}")
        except Exception as e:
            self.logger.error(f"Error reading panel list file: {e}")
            return []
        
        self.logger.info(f"Found {len(panel_ids)} panels to process")
        return panel_ids
    
    def download_panel_genes(self, data_folder: Path, panel_id: str) -> bool:
        """Download genes for a specific panel with pagination."""
        self.logger.info(f"Extracting genes for panel {panel_id}...")
        
        # Create panel-specific directory structure
        panel_dir = data_folder / "panels" / panel_id / "genes" / "json"
        panel_dir.mkdir(parents=True, exist_ok=True)
        
        # Download genes with pagination
        gene_url = f"{self.base_url}/{self.api_version}/panels/{panel_id}/genes/"
        page = 1
        next_url = gene_url
        
        try:
            while next_url and next_url != "null":
                self.logger.info(f"  Downloading genes page {page} for panel {panel_id}...")
                
                response = self.session.get(next_url, timeout=30)
                response.raise_for_status()
                
                # Parse and validate JSON
                try:
                    data = response.json()
                except json.JSONDecodeError as e:
                    self.logger.error(f"Invalid JSON received for panel {panel_id}, page {page}: {e}")
                    return False
                
                # Save to file
                response_file = panel_dir / f"genes_page_{page}.json"
                with open(response_file, 'w', encoding='utf-8') as f:
                    json.dump(data, f, indent=2, ensure_ascii=False)
                
                # Get pagination info
                count = data.get('count', 0)
                next_url = data.get('next')
                results_count = len(data.get('results', []))
                
                self.logger.info(f"    Page {page} downloaded: {results_count} genes (Total: {count})")
                
                page += 1
                
                # Safety check
                if page > 100:
                    self.logger.warning(f"Safety limit reached (100 pages) for panel {panel_id}")
                    break
            
            self.logger.info(f"Completed gene extraction for panel {panel_id} ({page-1} pages)")
            return True
            
        except requests.exceptions.RequestException as e:
            self.logger.error(f"HTTP error downloading genes for panel {panel_id}: {e}")
            return False
        except Exception as e:
            self.logger.error(f"Unexpected error downloading genes for panel {panel_id}: {e}")
            return False
    
    def extract_genes(self, data_folder: Optional[Path] = None) -> None:
        """Main gene extraction method."""
        if data_folder is None:
            data_folder = self.find_latest_data_folder()
            if data_folder is None:
                raise ValueError("No valid data folder found")
        
        self.logger.info(f"Starting gene extraction from: {data_folder}")
        
        # Read panel list
        panel_ids = self.read_panel_list(data_folder)
        if not panel_ids:
            self.logger.error("No panels found to process")
            return
        
        # Download genes for each panel
        successful = 0
        failed = 0
        
        for panel_id in panel_ids:
            if self.download_panel_genes(data_folder, panel_id):
                successful += 1
            else:
                failed += 1
        
        self.logger.info(f"Gene extraction completed: {successful} successful, {failed} failed")
        if failed > 0:
            self.logger.warning(f"Some panels failed. Check logs for details.")


def main():
    """Main function with command line argument parsing."""
    parser = argparse.ArgumentParser(
        description="Extract gene data for panels from PanelApp Australia API"
    )
    parser.add_argument(
        '--data-path', 
        default="../data", 
        help="Data directory path (default: ../data)"
    )
    parser.add_argument(
        '--folder', 
        help="Specific data folder (YYYYMMDD format). If not specified, uses latest."
    )
    parser.add_argument(
        '--verbose', '-v', 
        action='store_true', 
        help="Enable verbose logging"
    )
    
    args = parser.parse_args()
    
    if args.verbose:
        logging.getLogger().setLevel(logging.DEBUG)
    
    try:
        extractor = PanelGeneExtractor(data_path=args.data_path)
        
        # Use specific folder if provided
        data_folder = None
        if args.folder:
            data_folder = Path(args.data_path) / args.folder
            if not data_folder.exists():
                print(f"Specified folder does not exist: {data_folder}")
                return 1
        
        extractor.extract_genes(data_folder)
        
    except KeyboardInterrupt:
        print("\nGene extraction cancelled by user.")
        return 1
    except Exception as e:
        print(f"Gene extraction failed: {e}")
        return 1
    
    return 0


if __name__ == "__main__":
    exit(main())