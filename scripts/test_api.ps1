# Simple test of PowerShell API connectivity
# This tests the same endpoints as the Python test script

function Test-PanelAppAPI {
    Write-Host "Testing PanelApp Australia API connectivity..." -ForegroundColor Blue
    
    # Test swagger endpoint
    Write-Host "Testing swagger endpoint..." -ForegroundColor Yellow
    try {
        $swaggerResponse = Invoke-RestMethod -Uri "https://panelapp-aus.org/api/docs/?format=openapi" -Method Get -TimeoutSec 10
        $apiVersion = $swaggerResponse.info.version
        Write-Host "✓ Swagger endpoint accessible" -ForegroundColor Green
        Write-Host "✓ API version: $apiVersion" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ Swagger test failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    
    # Test panels endpoint
    Write-Host "Testing panels endpoint..." -ForegroundColor Yellow
    try {
        $panelsResponse = Invoke-RestMethod -Uri "https://panelapp-aus.org/api/v1/panels/" -Method Get -TimeoutSec 10
        $count = $panelsResponse.count
        $resultsCount = $panelsResponse.results.Count
        $hasNext = $null -ne $panelsResponse.next
        
        Write-Host "✓ Panels endpoint accessible" -ForegroundColor Green
        Write-Host "✓ Total panels in API: $count" -ForegroundColor Green
        Write-Host "✓ First page contains: $resultsCount panels" -ForegroundColor Green
        Write-Host "✓ Has next page: $hasNext" -ForegroundColor Green
        
        if ($resultsCount -gt 0) {
            $firstPanel = $panelsResponse.results[0]
            Write-Host "✓ First panel example - ID: $($firstPanel.id), Name: $($firstPanel.name)" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "✗ Panels endpoint test failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    
    Write-Host "✓ All tests passed! The PowerShell script should work correctly." -ForegroundColor Green
    return $true
}

# Run the test
Test-PanelAppAPI