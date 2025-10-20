#!/usr/bin/env python3
"""
PanelApp Australia Data Extraction Script (Python)

This script extracts panel data from the PanelApp Australia API.
Creates a folder for the current date and downloads all panels with pagination.
"""

import os
import json
import requests
import argparse
import logging
from datetime import datetime
from pathlib import Path
from typing import Optional, Dict, List, Any
from urllib.parse import urljoin


class PanelAppExtractor:
    """Class to handle PanelApp Australia data extraction."""
    
    def __init__(self, output_path: str = "../data"):
        self.base_url = "https://panelapp-aus.org/api"
        self.api_version = "v1"
        self.swagger_url = "https://panelapp-aus.org/api/docs/?format=openapi"
        self.expected_api_version = "v1"
        self.output_path = Path(output_path)
        self.session = requests.Session()
        
        # Setup logging
        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s - %(levelname)s - %(message)s',
            datefmt='%Y-%m-%d %H:%M:%S'
        )
        self.logger = logging.getLogger(__name__)
    
    def create_output_folder(self) -> Path:
        """Create output folder structure."""
        full_path = self.output_path / "panel_list" / "json"
        
        self.logger.info(f"Setting up output folder: {self.output_path}")
        
        try:
            full_path.mkdir(parents=True, exist_ok=True)
            self.logger.info(f"Created folder structure: {full_path}")
            return self.output_path
        except Exception as e:
            self.logger.error(f"Failed to create folder structure: {e}")
            raise
    
    def check_api_version(self) -> None:
        """Check if API is still on the required version."""
        self.logger.info("Checking API version...")
        
        try:
            response = self.session.get(self.swagger_url, timeout=30)
            response.raise_for_status()
            
            swagger_data = response.json()
            api_version = swagger_data.get("info", {}).get("version")
            
            if not api_version:
                raise ValueError("Could not determine API version from swagger documentation")
            
            self.logger.info(f"Current API version: {api_version}")
            
            if api_version != self.expected_api_version:
                self.logger.warning(
                    f"API version mismatch! Expected: {self.expected_api_version}, "
                    f"Found: {api_version}"
                )
                self.logger.warning("Continuing with execution, but results may vary...")
            else:
                self.logger.info(f"API version matches expected version: {self.expected_api_version}")
                
        except requests.exceptions.RequestException as e:
            self.logger.error(f"Failed to fetch swagger documentation: {e}")
            raise
        except json.JSONDecodeError as e:
            self.logger.error(f"Invalid JSON in swagger response: {e}")
            raise
    
    def download_panels(self, output_dir: Path) -> None:
        """Download panels with pagination."""
        panel_url = f"{self.base_url}/{self.api_version}/panels/"
        page = 1
        next_url = panel_url
        
        self.logger.info("Starting panel data extraction...")
        
        try:
            while next_url and next_url != "null":
                self.logger.info(f"Downloading page {page}...")
                
                response_file = output_dir / "panel_list" / "json" / f"panels_page_{page}.json"
                
                # Download the page
                response = self.session.get(next_url, timeout=30)
                response.raise_for_status()
                
                # Parse and validate JSON
                try:
                    data = response.json()
                except json.JSONDecodeError as e:
                    self.logger.error(f"Invalid JSON received for page {page}: {e}")
                    raise
                
                # Save to file
                with open(response_file, 'w', encoding='utf-8') as f:
                    json.dump(data, f, indent=2, ensure_ascii=False)
                
                # Get pagination info
                count = data.get('count', 0)
                next_url = data.get('next')
                results_count = len(data.get('results', []))
                
                self.logger.info(f"Page {page} downloaded: {results_count} panels (Total in API: {count})")
                
                page += 1
                
                # Safety check to prevent infinite loops
                if page > 1000:
                    self.logger.error("Safety limit reached (1000 pages). Stopping to prevent infinite loop.")
                    break
            
            self.logger.info(f"Panel data extraction completed. Downloaded {page-1} pages.")
            
        except requests.exceptions.RequestException as e:
            self.logger.error(f"HTTP error during panel download: {e}")
            raise
        except Exception as e:
            self.logger.error(f"Unexpected error during panel download: {e}")
            raise
    
    def extract_panel_info(self, output_dir: Path) -> None:
        """Extract panel information from JSON files and save version tracking."""
        json_dir = output_dir / "panel_list" / "json"
        tsv_file = output_dir / "panel_list.tsv"
        
        self.logger.info("Extracting panel information from JSON files...")
        
        try:
            # Prepare data collection
            panels_data = []
            file_count = 0
            panel_count = 0
            
            # Process all JSON files
            for json_file in json_dir.glob("panels_page_*.json"):
                file_count += 1
                
                try:
                    with open(json_file, 'r', encoding='utf-8') as f:
                        data = json.load(f)
                    
                    for panel in data.get('results', []):
                        stats = panel.get('stats', {})
                        panel_info = {
                            'id': panel.get('id'),
                            'name': panel.get('name', ''),
                            'version': panel.get('version'),
                            'version_created': panel.get('version_created'),
                            'number_of_genes': stats.get('number_of_genes', 0),
                            'number_of_strs': stats.get('number_of_strs', 0),
                            'number_of_regions': stats.get('number_of_regions', 0)
                        }
                        panels_data.append(panel_info)
                        panel_count += 1
                        
                        # Create individual panel directory and save version tracking
                        panel_dir = output_dir / "panels" / str(panel.get('id'))
                        panel_dir.mkdir(parents=True, exist_ok=True)
                        
                        version_file = panel_dir / "version_created.txt"
                        with open(version_file, 'w', encoding='utf-8') as vf:
                            vf.write(panel.get('version_created', ''))
                        
                        self.logger.info(f"  Created version tracking for panel {panel.get('id')}: {panel.get('version_created')}")
                        
                except json.JSONDecodeError as e:
                    self.logger.error(f"Error reading JSON file {json_file}: {e}")
                    continue
                except Exception as e:
                    self.logger.error(f"Unexpected error processing file {json_file}: {e}")
                    continue
            
            # Write to TSV
            with open(tsv_file, 'w', encoding='utf-8') as f:
                # Write header
                f.write("id\tname\tversion\tversion_created\tnumber_of_genes\tnumber_of_strs\tnumber_of_regions\n")
                # Write data
                for panel in panels_data:
                    f.write(f"{panel['id']}\t{panel['name']}\t{panel['version']}\t{panel['version_created']}\t{panel['number_of_genes']}\t{panel['number_of_strs']}\t{panel['number_of_regions']}\n")
            
            self.logger.info(f"Extracted information from {file_count} files containing {panel_count} panels")
            self.logger.info(f"Summary saved to: {tsv_file}")
            self.logger.info("Version tracking files saved in individual panel directories")
            
            # Display first few lines of the summary
            if tsv_file.exists() and panels_data:
                self.logger.info("First 5 entries in summary:")
                for i, panel in enumerate(panels_data[:5]):
                    self.logger.info(f"  {panel['id']}: {panel['name']}")
            
        except Exception as e:
            self.logger.error(f"Error during panel information extraction: {e}")
            raise
    
    def extract_data(self) -> None:
        """Main extraction method."""
        self.logger.info("Starting PanelApp Australia data extraction...")
        
        try:
            # Create output folder structure
            output_dir = self.create_output_folder()
            
            # Check API version
            self.check_api_version()
            
            # Download panels
            self.download_panels(output_dir)
            
            # Extract panel information
            self.extract_panel_info(output_dir)
            
            self.logger.info("Data extraction completed successfully!")
            self.logger.info(f"Output directory: {output_dir}")
            
        except Exception as e:
            self.logger.error(f"Data extraction failed: {e}")
            raise


def main():
    """Main function with command line argument parsing."""
    parser = argparse.ArgumentParser(
        description="Extract panel data from PanelApp Australia API"
    )
    parser.add_argument(
        '--output-path', 
        default="../data", 
        help="Output directory path (default: ../data)"
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
        extractor = PanelAppExtractor(output_path=args.output_path)
        extractor.extract_data()
    except KeyboardInterrupt:
        print("\nExtraction cancelled by user.")
        return 1
    except Exception as e:
        print(f"Extraction failed: {e}")
        return 1
    
    return 0


if __name__ == "__main__":
    exit(main())