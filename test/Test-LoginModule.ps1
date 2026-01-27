<#
.SYNOPSIS
    Azure Login Module Test Script

.DESCRIPTION
    Test Azure login module functionality, including login and subscription retrieval

.NOTES
    Version: 1.0.0
    Author: Azure DR Team
    Date: 2026-01-27
#>

$ErrorActionPreference = "Stop"

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulePath = Join-Path $scriptPath "..\Azure-Login.psm1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Azure Login Module Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Step 0: Checking Azure PowerShell module..." -ForegroundColor Yellow
try {
    $azModule = Get-Module -ListAvailable -Name Az -ErrorAction SilentlyContinue
    if (-not $azModule) {
        Write-Host "Azure PowerShell module not found, installing..." -ForegroundColor Red
        Install-Module -Name Az -AllowClobber -Scope CurrentUser -Force
        Write-Host "Azure PowerShell module installed" -ForegroundColor Green
    }
    else {
        Write-Host "Azure PowerShell module already installed" -ForegroundColor Green
    }
}
catch {
    Write-Host "Failed to install Azure PowerShell module: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 1: Importing login module..." -ForegroundColor Yellow
Write-Host "  Module path: $modulePath" -ForegroundColor Gray
try {
    Import-Module $modulePath -Force -ErrorAction Stop
    Write-Host "Login module imported successfully" -ForegroundColor Green
}
catch {
    Write-Host "Failed to import login module: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 2: Checking login status..." -ForegroundColor Yellow
$status = Test-AzureLoginStatus

if ($status.IsLoggedIn) {
    Write-Host "Current login status: Logged in" -ForegroundColor Green
    Write-Host "  Account: $($status.Account)" -ForegroundColor White
    Write-Host "  Subscription: $($status.SubscriptionName)" -ForegroundColor White
    Write-Host "  Subscription ID: $($status.SubscriptionId)" -ForegroundColor White
    Write-Host "  Tenant: $($status.TenantId)" -ForegroundColor White
    Write-Host "  Environment: $($status.Environment)" -ForegroundColor White
}
else {
    Write-Host "Current login status: Not logged in" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Step 3: Initializing Azure session..." -ForegroundColor Yellow
$config = @{
    EnableTokenCache = $true
    TokenCacheExpiryMinutes = 60
}

$session = Initialize-AzureSession -Config $config -Interactive

if (-not $session.Success) {
    Write-Host "Azure session initialization failed: $($session.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "Azure session initialized successfully" -ForegroundColor Green
Write-Host "  Account: $($session.Context.Account.Id)" -ForegroundColor White
Write-Host "  Subscription: $($session.Context.Subscription.Name)" -ForegroundColor White
Write-Host "  Subscription ID: $($session.Context.Subscription.Id)" -ForegroundColor White
Write-Host "  Tenant: $($session.Context.Tenant.Id)" -ForegroundColor White

Write-Host ""
Write-Host "Step 4: Getting all subscriptions..." -ForegroundColor Yellow
try {
    $subscriptions = Get-AzureSubscriptions
    
    if ($subscriptions.Count -eq 0) {
        Write-Host "No subscriptions found" -ForegroundColor Red
        exit 1
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Azure Subscription List" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    for ($i = 0; $i -lt $subscriptions.Count; $i++) {
        $sub = $subscriptions[$i]
        $isCurrent = if ($sub.Id -eq $session.Context.Subscription.Id) { " [Current]" } else { "" }
        
        Write-Host "[$($i + 1)] $($sub.Name)$isCurrent" -ForegroundColor Green
        Write-Host "    ID: $($sub.Id)" -ForegroundColor Gray
        Write-Host "    Tenant ID: $($sub.TenantId)" -ForegroundColor Gray
        Write-Host "    State: $($sub.State)" -ForegroundColor Gray
        
        if ($sub.HomeTenantId) {
            Write-Host "    Home Tenant ID: $($sub.HomeTenantId)" -ForegroundColor Gray
        }
        
        Write-Host ""
    }
    
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Total: $($subscriptions.Count) subscriptions" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}
catch {
    Write-Host "Failed to get subscriptions: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Step 5: Displaying detailed login status..." -ForegroundColor Yellow
Show-AzureLoginStatus

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Test Completed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
