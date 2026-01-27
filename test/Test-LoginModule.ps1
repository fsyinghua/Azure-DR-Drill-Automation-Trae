<#
.SYNOPSIS
    Azure登录模块测试脚本

.DESCRIPTION
    测试Azure登录模块功能，包括登录、获取订阅等

.NOTES
    Version: 1.0.0
    Author: Azure DR Team
    Date: 2026-01-27
#>

$ErrorActionPreference = "Stop"

$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulePath = Join-Path $scriptPath "..\Azure-Login.psm1"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Azure登录模块测试" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "步骤 0: 检查Azure PowerShell模块..." -ForegroundColor Yellow
try {
    $azModule = Get-Module -ListAvailable -Name Az -ErrorAction SilentlyContinue
    if (-not $azModule) {
        Write-Host "未找到Azure PowerShell模块，正在安装..." -ForegroundColor Red
        Install-Module -Name Az -AllowClobber -Scope CurrentUser -Force
        Write-Host "Azure PowerShell模块安装完成" -ForegroundColor Green
    }
    else {
        Write-Host "Azure PowerShell模块已安装" -ForegroundColor Green
    }
}
catch {
    Write-Host "安装Azure PowerShell模块失败: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "步骤 1: 导入登录模块..." -ForegroundColor Yellow
Write-Host "  模块路径: $modulePath" -ForegroundColor Gray
try {
    Import-Module $modulePath -Force -ErrorAction Stop
    Write-Host "登录模块导入成功" -ForegroundColor Green
}
catch {
    Write-Host "导入登录模块失败: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "步骤 2: 检查登录状态..." -ForegroundColor Yellow
$status = Test-AzureLoginStatus

if ($status.IsLoggedIn) {
    Write-Host "当前登录状态: 已登录" -ForegroundColor Green
    Write-Host "  账户: $($status.Account)" -ForegroundColor White
    Write-Host "  订阅: $($status.SubscriptionName)" -ForegroundColor White
    Write-Host "  订阅ID: $($status.SubscriptionId)" -ForegroundColor White
    Write-Host "  租户: $($status.TenantId)" -ForegroundColor White
    Write-Host "  环境: $($status.Environment)" -ForegroundColor White
}
else {
    Write-Host "当前登录状态: 未登录" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "步骤 3: 初始化Azure会话..." -ForegroundColor Yellow
$config = @{
    EnableTokenCache = $true
    TokenCacheExpiryMinutes = 60
}

$session = Initialize-AzureSession -Config $config -Interactive

if (-not $session.Success) {
    Write-Host "Azure会话初始化失败: $($session.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "Azure会话初始化成功" -ForegroundColor Green
Write-Host "  账户: $($session.Context.Account.Id)" -ForegroundColor White
Write-Host "  订阅: $($session.Context.Subscription.Name)" -ForegroundColor White
Write-Host "  订阅ID: $($session.Context.Subscription.Id)" -ForegroundColor White
Write-Host "  租户: $($session.Context.Tenant.Id)" -ForegroundColor White

Write-Host ""
Write-Host "步骤 4: 获取所有订阅..." -ForegroundColor Yellow
try {
    $subscriptions = Get-AzureSubscriptions
    
    if ($subscriptions.Count -eq 0) {
        Write-Host "未找到任何订阅" -ForegroundColor Red
        exit 1
    }
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Azure订阅列表" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    
    for ($i = 0; $i -lt $subscriptions.Count; $i++) {
        $sub = $subscriptions[$i]
        $isCurrent = if ($sub.Id -eq $session.Context.Subscription.Id) { " [当前]" } else { "" }
        
        Write-Host "[$($i + 1)] $($sub.Name)$isCurrent" -ForegroundColor Green
        Write-Host "    ID: $($sub.Id)" -ForegroundColor Gray
        Write-Host "    租户ID: $($sub.TenantId)" -ForegroundColor Gray
        Write-Host "    状态: $($sub.State)" -ForegroundColor Gray
        
        if ($sub.HomeTenantId) {
            Write-Host "    主租户ID: $($sub.HomeTenantId)" -ForegroundColor Gray
        }
        
        Write-Host ""
    }
    
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "总计: $($subscriptions.Count) 个订阅" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}
catch {
    Write-Host "获取订阅失败: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "步骤 5: 显示详细登录状态..." -ForegroundColor Yellow
Show-AzureLoginStatus

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "测试完成!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
