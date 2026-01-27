<#
.SYNOPSIS
    Azure登录模块 - 提供统一的Azure认证管理功能

.DESCRIPTION
    此模块提供Azure登录、状态检查、订阅选择等功能，集成token缓存机制

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
        [object]$Context,
        [int]$TokenExpiryMinutes = 60
    )
    
    try {
        $cacheData = @{
            AccountId = $Context.Account.Id
            TenantId = $Context.Tenant.Id
            SubscriptionId = $Context.Subscription.Id
            SubscriptionName = $Context.Subscription.Name
            Environment = $Context.Environment.Name
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
        Write-Host "Azure设备登录" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        
        Connect-AzAccount -UseDeviceAuthentication -ErrorAction Stop
        
        $context = Get-AzContext -ErrorAction Stop
        if ($context) {
            Write-Host ""
            Write-Host "登录成功!" -ForegroundColor Green
            Write-Host "账户: $($context.Account.Id)" -ForegroundColor White
            Write-Host "订阅: $($context.Subscription.Name)" -ForegroundColor White
            Write-Host ""
            
            return $true
        }
        
        return $false
    }
    catch {
        Write-Host ""
        Write-Host "登录失败: $_" -ForegroundColor Red
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
                Write-Host "已切换到订阅: $($result.Subscription.Name)" -ForegroundColor Green
                return $true
            }
            return $false
        }
        
        if ($Interactive) {
            $subscriptions = Get-AzSubscription -ErrorAction Stop
            
            if ($subscriptions.Count -eq 0) {
                Write-Host "未找到任何订阅" -ForegroundColor Red
                return $false
            }
            
            if ($subscriptions.Count -eq 1) {
                Write-Host "只有一个订阅，自动选择: $($subscriptions[0].Name)" -ForegroundColor Yellow
                $result = Select-AzSubscription -SubscriptionId $subscriptions[0].Id -ErrorAction Stop
                return $result -ne $null
            }
            
            Write-Host ""
            Write-Host "找到 $($subscriptions.Count) 个订阅:" -ForegroundColor Cyan
            Write-Host ""
            
            for ($i = 0; $i -lt $subscriptions.Count; $i++) {
                $isSelected = if ($subscriptions[$i].Id -eq (Get-AzContext).Subscription.Id) { " [当前]" } else { "" }
                Write-Host "  [$($i + 1)] $($subscriptions[$i].Name) ($($subscriptions[$i].Id))$isSelected" -ForegroundColor White
            }
            
            Write-Host ""
            $selection = Read-Host "请选择订阅 (1-$($subscriptions.Count))"
            
            $selectedIndex = [int]$selection - 1
            if ($selectedIndex -ge 0 -and $selectedIndex -lt $subscriptions.Count) {
                $result = Select-AzSubscription -SubscriptionId $subscriptions[$selectedIndex].Id -ErrorAction Stop
                if ($result) {
                    Write-Host "已切换到订阅: $($result.Subscription.Name)" -ForegroundColor Green
                    return $true
                }
            }
            
            Write-Host "无效的选择" -ForegroundColor Red
            return $false
        }
        
        return $false
    }
    catch {
        Write-Host "选择订阅失败: $_" -ForegroundColor Red
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
    Write-Host "初始化Azure会话" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    $loginStatus = Test-AzureLoginStatus
    
    if ($loginStatus.IsLoggedIn -and -not $ForceLogin) {
        Write-Host "当前登录状态:" -ForegroundColor Yellow
        Write-Host "  账户: $($loginStatus.Account)" -ForegroundColor White
        Write-Host "  订阅: $($loginStatus.SubscriptionName)" -ForegroundColor White
        Write-Host "  租户: $($loginStatus.TenantId)" -ForegroundColor White
        Write-Host ""
        
        if ($Config.EnableTokenCache) {
            $cache = Get-LoginCache
            if ($cache) {
                $expiresOn = [DateTime]::Parse($cache.ExpiresOn)
                $timeRemaining = $expiresOn - (Get-Date)
                
                if ($timeRemaining.TotalMinutes -gt 5) {
                    Write-Host "Token缓存有效，剩余时间: $($timeRemaining.ToString('hh\:mm\:ss'))" -ForegroundColor Green
                    Write-Host ""
                    
                    if ($TargetSubscriptionId -and $TargetSubscriptionId -ne $loginStatus.SubscriptionId) {
                        Write-Host "需要切换到目标订阅..." -ForegroundColor Yellow
                        $switchResult = Select-AzureSubscription -SubscriptionId $TargetSubscriptionId
                        if ($switchResult) {
                            $context = Get-AzContext -ErrorAction Stop
                            Save-LoginCache -Context $context -TokenExpiryMinutes $Config.TokenCacheExpiryMinutes
                        }
                    }
                    
                    return @{
                        Success = $true
                        Context = Get-AzContext -ErrorAction Stop
                        Message = "使用缓存的token"
                    }
                }
                else {
                    Write-Host "Token即将过期 ($($timeRemaining.TotalMinutes) 分钟剩余)" -ForegroundColor Yellow
                    Write-Host "建议重新登录" -ForegroundColor Yellow
                    Write-Host ""
                }
            }
        }
        
        if ($Interactive) {
            $relogin = Read-Host "是否重新登录? (Y/N)"
            if ($relogin -eq "Y" -or $relogin -eq "y") {
                $loginResult = Invoke-AzureDeviceLogin
                if (-not $loginResult) {
                    return @{
                        Success = $false
                        Context = $null
                        Message = "登录失败"
                    }
                }
            }
        }
    }
    else {
        Write-Host "未登录到Azure" -ForegroundColor Yellow
        Write-Host ""
        
        $loginResult = Invoke-AzureDeviceLogin
        if (-not $loginResult) {
            return @{
                Success = $false
                Context = $null
                Message = "登录失败"
            }
        }
    }
    
    $context = Get-AzContext -ErrorAction Stop
    
    if ($Config.EnableTokenCache) {
        Save-LoginCache -Context $context -TokenExpiryMinutes $Config.TokenCacheExpiryMinutes
        Write-Host "登录信息已缓存" -ForegroundColor Green
    }
    
    if ($TargetSubscriptionId -and $TargetSubscriptionId -ne $context.Subscription.Id) {
        Write-Host ""
        Write-Host "切换到目标订阅..." -ForegroundColor Yellow
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
                Message = "切换订阅失败"
            }
        }
    }
    
    if ($Interactive -and -not $TargetSubscriptionId) {
        $subscriptions = Get-AzSubscription
        if ($subscriptions.Count -gt 1) {
            Write-Host ""
            $changeSub = Read-Host "是否切换订阅? (Y/N)"
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
    Write-Host "Azure会话初始化完成" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "账户: $($finalContext.Account.Id)" -ForegroundColor White
    Write-Host "订阅: $($finalContext.Subscription.Name)" -ForegroundColor White
    Write-Host "订阅ID: $($finalContext.Subscription.Id)" -ForegroundColor White
    Write-Host "租户: $($finalContext.Tenant.Id)" -ForegroundColor White
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    
    return @{
        Success = $true
        Context = $finalContext
        Message = "会话初始化成功"
    }
}

function Clear-AzureLoginCache {
    try {
        $cacheFilePath = Get-LoginCacheFilePath
        if (Test-Path $cacheFilePath) {
            Remove-Item -Path $cacheFilePath -Force
            Write-Host "登录缓存已清除" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "未找到登录缓存" -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        Write-Host "清除登录缓存失败: $_" -ForegroundColor Red
        return $false
    }
}

function Show-AzureLoginStatus {
    $status = Test-AzureLoginStatus
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Azure登录状态" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    if ($status.IsLoggedIn) {
        Write-Host "状态: 已登录" -ForegroundColor Green
        Write-Host "账户: $($status.Account)" -ForegroundColor White
        Write-Host "订阅: $($status.SubscriptionName)" -ForegroundColor White
        Write-Host "订阅ID: $($status.SubscriptionId)" -ForegroundColor White
        Write-Host "租户ID: $($status.TenantId)" -ForegroundColor White
        Write-Host "环境: $($status.Environment)" -ForegroundColor White
        
        if ($status.IsLoggedIn) {
            $cache = Get-LoginCache
            if ($cache) {
                $expiresOn = [DateTime]::Parse($cache.ExpiresOn)
                $timeRemaining = $expiresOn - (Get-Date)
                Write-Host "缓存过期时间: $($expiresOn.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
                Write-Host "剩余时间: $($timeRemaining.ToString('hh\:mm\:ss'))" -ForegroundColor Gray
            }
        }
    }
    else {
        Write-Host "状态: 未登录" -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

Export-ModuleMember -Function @(
    'Test-AzureLoginStatus',
    'Invoke-AzureDeviceLogin',
    'Get-AzureSubscriptions',
    'Select-AzureSubscription',
    'Initialize-AzureSession',
    'Clear-AzureLoginCache',
    'Show-AzureLoginStatus'
)
