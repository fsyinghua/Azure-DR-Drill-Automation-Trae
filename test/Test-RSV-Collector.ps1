<#
.SYNOPSIS
    RSV配置采集测试脚本

.DESCRIPTION
    测试RSV配置采集模块的功能，包括数据采集、存储和导出

.NOTES
    Version: 1.0.0
    Author: Azure DR Team
    Date: 2026-01-28
#>

param(
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory = $false)]
    [switch]$Verbose
)

# ========================================
# 初始化
# ========================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "RSV配置采集测试" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 设置编码
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'

# 导入登录模块
$modulePath = Join-Path $PSScriptRoot "Azure-Login.psm1"
Write-Host "步骤 1: 导入登录模块..." -ForegroundColor Yellow
Write-Host "  模块路径: $modulePath" -ForegroundColor White

try {
    Import-Module -Name $modulePath -Force -ErrorAction Stop
    Write-Host "登录模块导入成功" -ForegroundColor Green
}
catch {
    Write-Host "登录模块导入失败: $_" -ForegroundColor Red
    exit 1
}

# 导入RSV采集模块
$rsvCollectorPath = Join-Path $PSScriptRoot "Azure-RSV-Collector.psm1"
Write-Host ""
Write-Host "步骤 2: 导入RSV采集模块..." -ForegroundColor Yellow
Write-Host "  模块路径: $rsvCollectorPath" -ForegroundColor White

try {
    Import-Module -Name $rsvCollectorPath -Force -ErrorAction Stop
    Write-Host "RSV采集模块导入成功" -ForegroundColor Green
}
catch {
    Write-Host "RSV采集模块导入失败: $_" -ForegroundColor Red
    exit 1
}

# ========================================
# 配置参数
# ========================================

Write-Host ""
Write-Host "步骤 3: 配置采集参数..." -ForegroundColor Yellow

$config = @{
    SubscriptionId = $null
    ResourceGroupName = $null
    RSVList = @()
    DatabasePath = ".\data\rsv-data.db"
    LogPath = ".\logs\rsv-collector.log"
    ExportPath = ".\exports\"
    IncludeBackupVMs = $true
    IncludeReplicatedItems = $true
    EnableIncrementalCollection = $true
    EnableAutoExport = $true
}

# 读取RSV列表
$rsvListFile = Join-Path $PSScriptRoot "rsv.txt"
if (Test-Path $rsvListFile) {
    $rsvList = Get-Content -Path $rsvListFile -ErrorAction SilentlyContinue | Where-Object { $_.Trim() -ne "" }
    $config.RSVList = $rsvList
    Write-Host "  RSV列表: $($rsvList.Count) 个" -ForegroundColor White
    foreach ($rsv in $rsvList) {
        Write-Host "    - $rsv" -ForegroundColor White
    }
}
else {
    Write-Host "  警告: 未找到rsv.txt文件" -ForegroundColor Yellow
    Write-Host "  使用默认RSV列表" -ForegroundColor Yellow
    $config.RSVList = @("rsv-primary")
}

# 读取配置文件
$configFile = Join-Path $PSScriptRoot "config.txt"
if (Test-Path $configFile) {
    $configContent = Get-Content -Path $configFile -ErrorAction SilentlyContinue
    foreach ($line in $configContent) {
        if ($line -match '^([^=]+)=(.+)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            
            switch ($key) {
                "SubscriptionId" { $config.SubscriptionId = $value }
                "ResourceGroupName" { $config.ResourceGroupName = $value }
            }
        }
    }
    
    if ($config.SubscriptionId) {
        Write-Host "  订阅ID: $($config.SubscriptionId)" -ForegroundColor White
    }
    if ($config.ResourceGroupName) {
        Write-Host "  资源组: $($config.ResourceGroupName)" -ForegroundColor White
    }
}

# ========================================
# 初始化Azure会话
# ========================================

Write-Host ""
Write-Host "步骤 4: 初始化Azure会话..." -ForegroundColor Yellow

try {
    $sessionConfig = @{
        EnableTokenCache = $true
        TokenCacheExpiryMinutes = 60
        Interactive = $false
    }
    
    $sessionResult = Initialize-AzureSession -Config $sessionConfig
    
    if (-not $sessionResult.Success) {
        Write-Host "Azure会话初始化失败: $($sessionResult.Message)" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Azure会话初始化成功" -ForegroundColor Green
}
catch {
    Write-Host "Azure会话初始化失败: $_" -ForegroundColor Red
    exit 1
}

# ========================================
# 执行采集
# ========================================

Write-Host ""
Write-Host "步骤 5: 执行RSV配置采集..." -ForegroundColor Yellow

if ($WhatIf) {
    Write-Host "WhatIf模式: 将显示采集配置但不执行实际采集" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "采集配置:" -ForegroundColor Cyan
    Write-Host "  数据库路径: $($config.DatabasePath)" -ForegroundColor White
    Write-Host "  日志路径: $($config.LogPath)" -ForegroundColor White
    Write-Host "  导出路径: $($config.ExportPath)" -ForegroundColor White
    Write-Host "  包含Backup VMs: $($config.IncludeBackupVMs)" -ForegroundColor White
    Write-Host "  包含Replicated Items: $($config.IncludeReplicatedItems)" -ForegroundColor White
    Write-Host "  启用增量采集: $($config.EnableIncrementalCollection)" -ForegroundColor White
    Write-Host "  启用自动导出: $($config.EnableAutoExport)" -ForegroundColor White
    Write-Host ""
    Write-Host "WhatIf模式完成，未执行实际采集" -ForegroundColor Green
    exit 0
}

try {
    $collectionResult = Invoke-RSVCollection -Config $config
    
    if (-not $collectionResult) {
        Write-Host "RSV配置采集失败" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "RSV配置采集成功" -ForegroundColor Green
}
catch {
    Write-Host "RSV配置采集失败: $_" -ForegroundColor Red
    exit 1
}

# ========================================
# 显示结果
# ========================================

Write-Host ""
Write-Host "步骤 6: 显示采集结果..." -ForegroundColor Yellow

if (Test-Path $config.DatabasePath) {
    Write-Host "数据库文件: $($config.DatabasePath)" -ForegroundColor White
    
    # 获取数据库大小
    $dbSize = (Get-Item $config.DatabasePath).Length / 1MB
    Write-Host "数据库大小: $([math]::Round($dbSize, 2)) MB" -ForegroundColor White
}

if (Test-Path $config.ExportPath) {
    $exportFiles = Get-ChildItem -Path $config.ExportPath -Filter "*.csv" -ErrorAction SilentlyContinue
    if ($exportFiles) {
        Write-Host "导出文件:" -ForegroundColor White
        foreach ($file in $exportFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 5) {
            Write-Host "  - $($file.Name) ($([math]::Round($file.Length / 1KB, 2)) KB)" -ForegroundColor White
        }
    }
}

if (Test-Path $config.LogPath) {
    Write-Host "日志文件: $($config.LogPath)" -ForegroundColor White
}

# ========================================
# 完成
# ========================================

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "测试完成!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

Write-Host "下一步操作:" -ForegroundColor Cyan
Write-Host "  1. 查看日志文件: $($config.LogPath)" -ForegroundColor White
Write-Host "  2. 查看导出文件: $($config.ExportPath)" -ForegroundColor White
Write-Host "  3. 查询数据库数据" -ForegroundColor White
Write-Host ""
