<#
.SYNOPSIS
    快速启动Azure灾难演练脚本

.DESCRIPTION
    此脚本用于快速启动Azure灾难恢复演练，包含Azure连接检查和参数验证

.NOTES
    Version: 1.1.0
    Author: Azure DR Team
    Date: 2026-01-27
    Changes: Integrated Azure login module with token caching and subscription management
#>

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Azure DR Drill - Quick Start" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "步骤 1: 检查Azure PowerShell模块..." -ForegroundColor Yellow
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
Write-Host "步骤 2: 导入登录模块..." -ForegroundColor Yellow
try {
    Import-Module ".\Azure-Login.psm1" -Force -ErrorAction Stop
    Write-Host "登录模块导入成功" -ForegroundColor Green
}
catch {
    Write-Host "导入登录模块失败: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "步骤 3: 读取配置..." -ForegroundColor Yellow
$config = Get-Content "config.txt" | Where-Object { $_ -match '^\s*[^#]' } | ForEach-Object {
    if ($_ -match '^\s*([^=]+)\s*=\s*(.+)\s*$') {
        @{ Key = $matches[1].Trim(); Value = $matches[2].Trim() }
    }
}

$configHashTable = @{}
foreach ($item in $config) {
    $configHashTable[$item.Key] = $item.Value
}

Write-Host "配置参数:" -ForegroundColor White
$config | Where-Object { $_.Key -notmatch "Password|Token" } | ForEach-Object {
    Write-Host "  $($_.Key) = $($_.Value)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "步骤 4: 初始化Azure会话..." -ForegroundColor Yellow
try {
    $sessionResult = Initialize-AzureSession -Config $configHashTable -Interactive

    if (-not $sessionResult.Success) {
        Write-Host "Azure会话初始化失败: $($sessionResult.Message)" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "Azure会话初始化失败: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "步骤 5: 检查配置文件..." -ForegroundColor Yellow
$configFiles = @("vmlist.txt", "rsv.txt")
$allFilesExist = $true

foreach ($file in $configFiles) {
    if (Test-Path $file) {
        Write-Host "  ✓ $file" -ForegroundColor Green
    }
    else {
        Write-Host "  ✗ $file (未找到)" -ForegroundColor Red
        $allFilesExist = $false
    }
}

if (-not $allFilesExist) {
    Write-Host ""
    Write-Host "请确保所有配置文件都存在" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "步骤 6: 读取虚拟机列表..." -ForegroundColor Yellow
$vms = Get-Content "vmlist.txt" | Where-Object { $_ -match '^\s*[^#\s]' } | ForEach-Object { $_.Trim() }
Write-Host "找到 $($vms.Count) 台虚拟机:" -ForegroundColor White
$vms | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }

Write-Host ""
Write-Host "步骤 7: 读取RSV列表..." -ForegroundColor Yellow
$rsvs = Get-Content "rsv.txt" | Where-Object { $_ -match '^\s*[^#\s]' } | ForEach-Object { $_.Trim() }
Write-Host "找到 $($rsvs.Count) 个恢复服务保管库:" -ForegroundColor White
$rsvs | ForEach-Object { Write-Host "  - $_" -ForegroundColor Gray }

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "准备就绪!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$whatIf = $false
$whatIfInput = Read-Host "是否运行WhatIf模式（仅模拟，不实际执行）? (Y/N)"
if ($whatIfInput -eq "Y" -or $whatIfInput -eq "y") {
    $whatIf = $true
    Write-Host "将运行WhatIf模式" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "开始执行灾难演练..." -ForegroundColor Cyan
Write-Host ""

try {
    $params = @{}
    if ($whatIf) {
        $params["WhatIf"] = $true
    }

    & ".\Azure-DR-Drill.ps1" @params
}
catch {
    Write-Host "执行失败: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "灾难演练完成!" -ForegroundColor Green
Write-Host "日志文件: .\logs\dr-drill.log" -ForegroundColor White
Write-Host "结果文件: .\results\dr-drill-results_*.csv" -ForegroundColor White