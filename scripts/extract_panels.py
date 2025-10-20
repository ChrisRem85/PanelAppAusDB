#!/usr/bin/env python3
"""
PanelApp Australia Complete Data Extraction Wrapper Script (Python)

This script orchestrates the complete data extraction process:
1. Extracts panel list data
2. Extracts detailed gene data for each panel
3. Will extract STR data (placeholder for future implementation)
4. Will extract region data (placeholder for future implementation)
"""

import argparse
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path


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


def run_script(script_path: str, script_name: str, args: list = None, optional: bool = False) -> bool:
    """Execute a script and handle errors."""
    if not os.path.exists(script_path):
        if optional:
            log_message(f"{script_name} not found at {script_path} (optional - skipping)", "WARNING")
            return True
        else:
            log_message(f"{script_name} not found at {script_path}", "ERROR")
            return False
    
    log_message(f"Running {script_name}...")
    
    try:
        cmd = [sys.executable, script_path]
        if args:
            cmd.extend(args)
        
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=3600)  # 1 hour timeout
        
        if result.returncode == 0:
            log_message(f"{script_name} completed successfully", "SUCCESS")
            if result.stdout:
                print(result.stdout)
            return True
        else:
            log_message(f"{script_name} failed with exit code {result.returncode}", "ERROR")
            if result.stderr:
                print(result.stderr)
            return False
            
    except subprocess.TimeoutExpired:
        log_message(f"{script_name} timed out after 1 hour", "ERROR")
        return False
    except Exception as e:
        log_message(f"{script_name} failed with error: {e}", "ERROR")
        return False


def main():
    """Main execution function."""
    parser = argparse.ArgumentParser(
        description="Complete data extraction wrapper for PanelApp Australia API",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
EXAMPLES:
    python extract_panels.py                           # Full extraction
    python extract_panels.py --skip-genes              # Skip gene extraction
    python extract_panels.py --output-path /path/data  # Custom output path
    python extract_panels.py --verbose                 # Verbose logging
        """
    )
    
    parser.add_argument(
        "--output-path", 
        default="../data",
        help="Path to output directory (default: ../data)"
    )
    parser.add_argument(
        "--skip-genes",
        action="store_true",
        help="Skip gene data extraction"
    )
    parser.add_argument(
        "--skip-strs",
        action="store_true",
        help="Skip STR data extraction"
    )
    parser.add_argument(
        "--skip-regions",
        action="store_true",
        help="Skip region data extraction"
    )
    parser.add_argument(
        "--verbose",
        action="store_true",
        help="Enable verbose logging"
    )
    
    args = parser.parse_args()
    
    log_message("Starting PanelApp Australia complete data extraction...")
    
    script_dir = Path(__file__).parent
    success = True
    
    # Step 1: Extract panel list data
    panel_list_script = script_dir / "extract_panel_list.py"
    panel_list_args = ["--output-path", args.output_path]
    if args.verbose:
        panel_list_args.append("--verbose")
    
    if not run_script(str(panel_list_script), "Panel List Extraction", panel_list_args):
        log_message("Panel list extraction failed. Cannot continue.", "ERROR")
        sys.exit(1)
    
    # Use the output path directly as data folder
    data_folder = Path(args.output_path)
    
    if not data_folder.exists():
        log_message(f"Data folder not found: {data_folder}", "ERROR")
        sys.exit(1)
    
    log_message(f"Using data folder: {data_folder}")
    
    # Step 2: Extract gene data (if not skipped)
    if not args.skip_genes:
        gene_script = script_dir / "extract_genes_incremental.py"
        gene_args = ["--data-path", args.output_path]
        if args.verbose:
            gene_args.append("--verbose")
        
        if not run_script(str(gene_script), "Gene Data Extraction", gene_args):
            log_message("Gene extraction failed, but continuing with other extractions", "WARNING")
            success = False
    else:
        log_message("Skipping gene extraction (--skip-genes specified)")
    
    # Step 3: Extract STR data (placeholder - future implementation)
    if not args.skip_strs:
        str_script = script_dir / "extract_strs.py"
        str_args = ["--data-path", args.output_path]
        if args.verbose:
            str_args.append("--verbose")
        
        if not run_script(str(str_script), "STR Data Extraction", str_args, optional=True):
            log_message("STR extraction failed or not implemented yet", "WARNING")
    else:
        log_message("Skipping STR extraction (--skip-strs specified)")
    
    # Step 4: Extract region data (placeholder - future implementation)
    if not args.skip_regions:
        region_script = script_dir / "extract_regions.py"
        region_args = ["--data-path", args.output_path]
        if args.verbose:
            region_args.append("--verbose")
        
        if not run_script(str(region_script), "Region Data Extraction", region_args, optional=True):
            log_message("Region extraction failed or not implemented yet", "WARNING")
    else:
        log_message("Skipping region extraction (--skip-regions specified)")
    
    # Summary
    if success:
        log_message("Complete data extraction finished successfully!", "SUCCESS")
    else:
        log_message("Complete data extraction finished with some warnings/errors", "WARNING")
    
    log_message(f"Output directory: {data_folder}")
    print()
    log_message("Data extraction summary:")
    log_message("  Panel list: Completed")
    log_message(f"  Gene data: {'Skipped' if args.skip_genes else 'Attempted'}")
    log_message(f"  STR data: {'Skipped' if args.skip_strs else 'Attempted (future implementation)'}")
    log_message(f"  Region data: {'Skipped' if args.skip_regions else 'Attempted (future implementation)'}")


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        log_message("Extraction interrupted by user", "WARNING")
        sys.exit(1)
    except Exception as e:
        log_message(f"Wrapper script execution failed: {e}", "ERROR")
        sys.exit(1)