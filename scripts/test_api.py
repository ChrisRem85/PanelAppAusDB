#!/usr/bin/env python3
"""
Test script to verify the API connection and basic functionality.
This will only test the API version check without downloading all data.
"""

import requests
import json
import logging

def test_api_connection():
    """Test basic API connectivity and version check."""
    logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
    logger = logging.getLogger(__name__)
    
    # Test swagger endpoint
    swagger_url = "https://panelapp-aus.org/api/docs/?format=openapi"
    logger.info("Testing swagger endpoint...")
    
    try:
        response = requests.get(swagger_url, timeout=10)
        response.raise_for_status()
        
        swagger_data = response.json()
        api_version = swagger_data.get("info", {}).get("version")
        
        logger.info(f"✓ Swagger endpoint accessible")
        logger.info(f"✓ API version: {api_version}")
        
    except Exception as e:
        logger.error(f"✗ Swagger test failed: {e}")
        return False
    
    # Test panels endpoint (first page only)
    panels_url = "https://panelapp-aus.org/api/v1/panels/"
    logger.info("Testing panels endpoint...")
    
    try:
        response = requests.get(panels_url, timeout=10)
        response.raise_for_status()
        
        data = response.json()
        count = data.get('count', 0)
        results_count = len(data.get('results', []))
        has_next = bool(data.get('next'))
        
        logger.info(f"✓ Panels endpoint accessible")
        logger.info(f"✓ Total panels in API: {count}")
        logger.info(f"✓ First page contains: {results_count} panels")
        logger.info(f"✓ Has next page: {has_next}")
        
        # Show first panel info if available
        if results_count > 0:
            first_panel = data['results'][0]
            logger.info(f"✓ First panel example - ID: {first_panel.get('id')}, Name: {first_panel.get('name')}")
        
    except Exception as e:
        logger.error(f"✗ Panels endpoint test failed: {e}")
        return False
    
    logger.info("✓ All tests passed! The scripts should work correctly.")
    return True

if __name__ == "__main__":
    test_api_connection()