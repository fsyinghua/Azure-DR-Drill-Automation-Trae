# Az Module Fix Script
# Fix Az module version conflicts and corruption

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Az Module Fix Tool" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Check current Az module versions
Write-Host "[1] Checking current Az module versions..." -ForegroundColor Yellow
$azModules = Get-Module -ListAvailable -Name Az* | Sort-Object Name
if ($azModules) {
    Write-Host "  Found Az modules:" -ForegroundColor White
    foreach ($module in $azModules) {
        Write-Host "    - $($module.Name) (Version: $($module.Version))" -ForegroundColor White
    }
}
else {
    Write-Host "  No Az modules found" -ForegroundColor Yellow
}
Write-Host ""

# Step 2: Uninstall all Az modules
Write-Host "[2] Uninstalling all Az modules..." -ForegroundColor Yellow
$allAzModules = Get-Module -ListAvailable -Name Az* | Select-Object -ExpandProperty Name | Sort-Object -Unique
$uninstalledCount = 0

foreach ($moduleName in $allAzModules) {
    try {
        Write-Host "  Uninstalling: $moduleName" -ForegroundColor White
        Uninstall-Module -Name $moduleName -Force -ErrorAction SilentlyContinue
        $uninstalledCount++
    }
    catch {
        Write-Host "  Uninstall failed: $moduleName - $_" -ForegroundColor Red
    }
}

Write-Host "  Uninstalled $uninstalledCount modules" -ForegroundColor Green
Write-Host ""

# Step 3: Clear PowerShell module cache
Write-Host "[3] Clearing PowerShell module cache..." -ForegroundColor Yellow
$modulePaths = @(
    "$env:USERPROFILE\Documents\WindowsPowerShell\Modules",
    "$env:USERPROFILE\Documents\PowerShell\Modules",
    "$env:ProgramFiles\WindowsPowerShell\Modules",
    "$env:ProgramFiles\PowerShell\Modules"
)

$clearedCount = 0
foreach ($path in $modulePaths) {
    if (Test-Path $path) {
        $azPaths = Get-ChildItem -Path $path -Filter "Az*" -Directory -ErrorAction SilentlyContinue
        foreach ($azPath in $azPaths) {
            try {
                Write-Host "  Deleting: $($azPath.FullName)" -ForegroundColor White
                Remove-Item -Path $azPath.FullName -Recurse -Force -ErrorAction SilentlyContinue
                $clearedCount++
            }
            catch {
                Write-Host "  Delete failed: $($azPath.FullName) - $_" -ForegroundColor Red
            }
        }
    }
}

Write-Host "  Cleared $clearedCount cache directories" -ForegroundColor Green
Write-Host ""

# Step 4: Reinstall Az module
Write-Host "[4] Reinstalling Az module..." -ForegroundColor Yellow
Write-Host "  This may take a few minutes..." -ForegroundColor Gray
Write-Host ""

try {
    Install-Module -Name Az -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
    Write-Host "  Az module installed successfully" -ForegroundColor Green
}
catch {
    Write-Host "  Az module installation failed: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please try manual installation:" -ForegroundColor Yellow
    Write-Host "  Install-Module -Name Az -Scope CurrentUser -Force" -ForegroundColor White
    exit 1
}
Write-Host ""

# Step 5: Verify installation
Write-Host "[5] Verifying Az module installation..." -ForegroundColor Yellow
$azModule = Get-Module -ListAvailable -Name Az | Select-Object -First 1
if ($azModule) {
    Write-Host "  Az module installed" -ForegroundColor Green
    Write-Host "  Version: $($azModule.Version)" -ForegroundColor White

    # Test import
    try {
        Import-Module -Name Az -Force -ErrorAction Stop
        Write-Host "  Az module imported successfully" -ForegroundColor Green
    }
    catch {
        Write-Host "  Az module import failed: $_" -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "  Az module not found" -ForegroundColor Red
    exit 1
}
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Az Module Fix Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Restart PowerShell" -ForegroundColor White
Write-Host "  2. Run: Connect-AzAccount -UseDeviceAuthentication" -ForegroundColor White
Write-Host "  3. Run: .\test\Test-RSV-Collector.ps1" -ForegroundColor White
Write-Host ""
