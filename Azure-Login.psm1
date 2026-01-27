<#
.SYNOPSIS
    Azure Login Module - Provides unified Azure authentication management

.DESCRIPTION
    This module provides Azure login, status check, subscription selection, and token caching functionality

.NOTES
    Version: 1.0.0
    Author: Azure DR Team
    Date: 2026-01-27
#>

function Get-LoginCacheFilePath {
    $cacheDir = ".\cache"
    if (-not (Test-Path $cacheDir)) {
        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
    }
    return Join-Path $cacheDir "azure-login-cache.json"
}

function Save-LoginCache {
    param(
        [hashtable]$Context,
        [int]$TokenExpiryMinutes = 60
    )
    
    try {
        $cacheData = @{
            AccountId = $context.Account.Id
            TenantId = $context.Tenant.Id
            SubscriptionId = $context.Subscription.Id
            SubscriptionName = $context.Subscription.Name
            Environment = $context.Environment.Name
            ExpiresOn = (Get-Date).AddMinutes($TokenExpiryMinutes).ToString("o")
            CachedAt = (Get-Date).ToString("o")
        }
        
        $cacheFilePath = Get-LoginCacheFilePath
        $cacheData | ConvertTo-Json -Depth 10 | Set-Content -Path $cacheFilePath -Encoding UTF8
        
        return $true
    }
    catch {
        return $false
    }
}

function Get-LoginCache {
    try {
        $cacheFilePath = Get-LoginCacheFilePath
        if (-not (Test-Path $cacheFilePath)) {
            return $null
        }
        
        $cacheContent = Get-Content -Path $cacheFilePath -Raw -Encoding UTF8
        $cacheData = $cacheContent | ConvertFrom-Json
        
        $expiresOn = [DateTime]::Parse($cacheData.ExpiresOn)
        if ($expiresOn -lt (Get-Date)) {
            Remove-Item -Path $cacheFilePath -Force -ErrorAction SilentlyContinue
            return $null
        }
        
        return $cacheData
    }
    catch {
        return $null
    }
}

function Test-AzureLoginStatus {
    try {
        $context = Get-AzContext -ErrorAction Stop
        if ($context) {
            return @{
                IsLoggedIn = $true
                Account = $context.Account.Id
                SubscriptionId = $context.Subscription.Id
                SubscriptionName = $context.Subscription.Name
                TenantId = $context.Tenant.Id
                Environment = $context.Environment.Name
            }
        }
        return @{
            IsLoggedIn = $false
            Account = $null
            SubscriptionId = $null
            SubscriptionName = $null
            TenantId = $null
            Environment = $null
        }
    }
    catch {
        return @{
            IsLoggedIn = $false
            Account = $null
            SubscriptionId = $null
            SubscriptionName = $null
            TenantId = $null
            Environment = $null
        }
    }
}

function Invoke-AzureDeviceLogin {
    try {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "Azure Device Login" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        
        Connect-AzAccount -UseDeviceAuthentication -ErrorAction Stop
        
        $context = Get-AzContext -ErrorAction Stop
        if ($context) {
            Write-Host ""
            Write-Host "Login successful!" -ForegroundColor Green
            Write-Host "Account: $($context.Account.Id)" -ForegroundColor White
            Write-Host "Subscription: $($context.Subscription.Name)" -ForegroundColor White
            Write-Host ""
            
            return $true
        }
        
        return $false
    }
    catch {
        Write-Host ""
        Write-Host "Login failed: $_" -ForegroundColor Red
        Write-Host ""
        return $false
    }
}

function Get-AzureSubscriptions {
    try {
        $subscriptions = Get-AzSubscription -ErrorAction Stop
        return $subscriptions
    }
    catch {
        return @()
    }
}

function Select-AzureSubscription {
    param(
        [string]$SubscriptionId,
        [switch]$Interactive
    )
    
    try {
        if ($SubscriptionId) {
            $result = Select-AzSubscription -SubscriptionId $SubscriptionId -ErrorAction Stop
            if ($result) {
                Write-Host "Switched to subscription: $($result.Subscription.Name)" -ForegroundColor Green
                return $true
            }
            return $false
        }
        
        if ($Interactive) {
            $subscriptions = Get-AzSubscription -ErrorAction Stop
            
            if ($subscriptions.Count -eq 0) {
                Write-Host "No subscriptions found" -ForegroundColor Red
                return $false
            }
            
            if ($subscriptions.Count -eq 1) {
                Write-Host "Only one subscription, auto-select: $($subscriptions[0].Name)" -ForegroundColor Yellow
                $result = Select-AzSubscription -SubscriptionId $subscriptions[0].Id -ErrorAction Stop
                return $result -ne $null
            }
            
            Write-Host ""
            Write-Host "Found $($subscriptions.Count) subscriptions:" -ForegroundColor Cyan
            Write-Host ""
            
            for ($i = 0; $i -lt $subscriptions.Count; $i++) {
                $isSelected = if ($subscriptions[$i].Id -eq (Get-AzContext).Subscription.Id) { " [Current]" } else { "" }
                Write-Host "  [$($i + 1)] $($subscriptions[$i].Name) ($($subscriptions[$i].Id))$isSelected" -ForegroundColor White
            }
            
            Write-Host ""
            $selection = Read-Host "Please select subscription (1-$($subscriptions.Count))"
            
            $selectedIndex = [int]$selection - 1
            if ($selectedIndex -ge 0 -and $selectedIndex -lt $subscriptions.Count) {
                $result = Select-AzSubscription -SubscriptionId $subscriptions[$selectedIndex].Id -ErrorAction Stop
                if ($result) {
                    Write-Host "Switched to subscription: $($result.Subscription.Name)" -ForegroundColor Green
                    return $true
                }
            }
            
            Write-Host "Invalid selection" -ForegroundColor Red
            return $false
        }
        
        return $false
    }
    catch {
        Write-Host "Failed to select subscription: $_" -ForegroundColor Red
        return $false
    }
}

function Initialize-AzureSession {
    param(
        [hashtable]$Config,
        [string]$TargetSubscriptionId,
        [switch]$ForceLogin,
        [switch]$Interactive
    )
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Initializing Azure Session" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    $loginStatus = Test-AzureLoginStatus
    
    if ($loginStatus.IsLoggedIn -and -not $ForceLogin) {
        Write-Host "Current login status:" -ForegroundColor Yellow
        Write-Host "  Account: $($loginStatus.Account)" -ForegroundColor White
        Write-Host "  Subscription: $($loginStatus.SubscriptionName)" -ForegroundColor White
        Write-Host "  Tenant: $($loginStatus.TenantId)" -ForegroundColor White
        Write-Host ""
        
        if ($Config.EnableTokenCache) {
            $cache = Get-LoginCache
            if ($cache) {
                $expiresOn = [DateTime]::Parse($cache.ExpiresOn)
                $timeRemaining = $expiresOn - (Get-Date)
                
                if ($timeRemaining.TotalMinutes -gt 5) {
                    Write-Host "Token cache is valid, remaining time: $($timeRemaining.ToString('hh\:mm\:ss'))" -ForegroundColor Green
                    Write-Host ""
                    
                    if ($TargetSubscriptionId -and $TargetSubscriptionId -ne $loginStatus.SubscriptionId) {
                        Write-Host "Need to switch to target subscription..." -ForegroundColor Yellow
                        $switchResult = Select-AzureSubscription -SubscriptionId $TargetSubscriptionId
                        if ($switchResult) {
                            $context = Get-AzContext -ErrorAction Stop
                            Save-LoginCache -Context $context -TokenExpiryMinutes $Config.TokenCacheExpiryMinutes
                        }
                    }
                    
                    return @{
                        Success = $true
                        Context = Get-AzContext -ErrorAction Stop
                        Message = "Using cached token"
                    }
                }
                else {
                    Write-Host "Token will expire soon ($($timeRemaining.TotalMinutes) minutes remaining)" -ForegroundColor Yellow
                    Write-Host "Suggest to re-login" -ForegroundColor Yellow
                    Write-Host ""
                }
            }
        }
        
        if ($Interactive) {
            $relogin = Read-Host "Do you want to re-login? (Y/N)"
            if ($relogin -eq "Y" -or $relogin -eq "y") {
                $loginResult = Invoke-AzureDeviceLogin
                if (-not $loginResult) {
                    return @{
                        Success = $false
                        Context = $null
                        Message = "Login failed"
                    }
                }
            }
        }
    }
    else {
        Write-Host "Not logged in to Azure" -ForegroundColor Yellow
        Write-Host ""
        
        $loginResult = Invoke-AzureDeviceLogin
        if (-not $loginResult) {
            return @{
                Success = $false
                Context = $null
                Message = "Login failed"
            }
        }
    }
    
    $context = Get-AzContext -ErrorAction Stop
    
    if ($Config.EnableTokenCache) {
        Save-LoginCache -Context $context -TokenExpiryMinutes $Config.TokenCacheExpiryMinutes
        Write-Host "Login information cached" -ForegroundColor Green
    }
    
    if ($TargetSubscriptionId -and $TargetSubscriptionId -ne $context.Subscription.Id) {
        Write-Host ""
        Write-Host "Switching to target subscription..." -ForegroundColor Yellow
        $switchResult = Select-AzureSubscription -SubscriptionId $TargetSubscriptionId
        if ($switchResult) {
            $context = Get-AzContext -ErrorAction Stop
            if ($Config.EnableTokenCache) {
                Save-LoginCache -Context $context -TokenExpiryMinutes $Config.TokenCacheExpiryMinutes
            }
        }
        else {
            return @{
                Success = $false
                Context = $null
                Message = "Failed to switch subscription"
            }
        }
    }
    
    if ($Interactive -and -not $TargetSubscriptionId) {
        $subscriptions = Get-AzSubscription
        if ($subscriptions.Count -gt 1) {
            Write-Host ""
            $changeSub = Read-Host "Do you want to switch subscription? (Y/N)"
            if ($changeSub -eq "Y" -or $changeSub -eq "y") {
                Select-AzureSubscription -Interactive
                $context = Get-AzContext -ErrorAction Stop
                if ($Config.EnableTokenCache) {
                    Save-LoginCache -Context $context -TokenExpiryMinutes $Config.TokenCacheExpiryMinutes
                }
            }
        }
    }
    
    $finalContext = Get-AzContext -ErrorAction Stop
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Azure Session Initialized Successfully" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Account: $($finalContext.Account.Id)" -ForegroundColor White
    Write-Host "Subscription: $($finalContext.Subscription.Name)" -ForegroundColor White
    Write-Host "Subscription ID: $($finalContext.Subscription.Id)" -ForegroundColor White
    Write-Host "Tenant: $($finalContext.Tenant.Id)" -ForegroundColor White
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    
    return @{
        Success = $true
        Context = $finalContext
        Message = "Session initialized successfully"
    }
}

function Clear-AzureLoginCache {
    try {
        $cacheFilePath = Get-LoginCacheFilePath
        if (Test-Path $cacheFilePath) {
            Remove-Item -Path $cacheFilePath -Force
            Write-Host "Login cache cleared" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "Login cache not found" -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        Write-Host "Failed to clear login cache: $_" -ForegroundColor Red
        return $false
    }
}

function Show-AzureLoginStatus {
    $status = Test-AzureLoginStatus
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Azure Login Status" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    if ($status.IsLoggedIn) {
        Write-Host "Status: Logged in" -ForegroundColor Green
        Write-Host "Account: $($status.Account)" -ForegroundColor White
        Write-Host "Subscription: $($status.SubscriptionName)" -ForegroundColor White
        Write-Host "Subscription ID: $($status.SubscriptionId)" -ForegroundColor White
        Write-Host "Tenant ID: $($status.TenantId)" -ForegroundColor White
        Write-Host "Environment: $($status.Environment)" -ForegroundColor White
        
        if ($status.IsLoggedIn) {
            $cache = Get-LoginCache
            if ($cache) {
                $expiresOn = [DateTime]::Parse($cache.ExpiresOn)
                $timeRemaining = $expiresOn - (Get-Date)
                Write-Host "Cache expiry time: $($expiresOn.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
                Write-Host "Remaining time: $($timeRemaining.ToString('hh\:mm\:ss'))" -ForegroundColor Gray
            }
        }
    }
    else {
        Write-Host "Status: Not logged in" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

Export-ModuleMember -Function @(
    'Test-AzureLoginStatus',
    'Invoke-AzureDeviceLogin',
    'Select-AzureSubscription',
    'Initialize-AzureSession',
    'Clear-AzureLoginCache',
    'Show-AzureLoginStatus'
)
