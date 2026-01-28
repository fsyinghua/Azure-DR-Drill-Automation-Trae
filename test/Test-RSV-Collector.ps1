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
    [switch]$WhatIf
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

# 获取项目根目录
$projectRoot = Split-Path -Parent $PSScriptRoot

# 导入登录模块
$modulePath = Join-Path $projectRoot "Azure-Login.psm1"
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
$rsvCollectorPath = Join-Path $projectRoot "Azure-RSV-Collector.psm1"
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
    DatabasePath = Join-Path $projectRoot "data\rsv-data.db"
    LogPath = Join-Path $projectRoot "logs\rsv-collector.log"
    ExportPath = Join-Path $projectRoot "exports\"
    IncludeBackupVMs = $true
    IncludeReplicatedItems = $true
    EnableIncrementalCollection = $false
    EnableAutoExport = $true
    TestRSVName = $null
}

# 获取所有订阅
Write-Host "  获取所有订阅..." -ForegroundColor White
$subscriptions = Get-AzSubscription -ErrorAction SilentlyContinue

if (-not $subscriptions -or $subscriptions.Count -eq 0) {
    Write-Host "  警告: 未找到任何订阅" -ForegroundColor Yellow
    exit 1
}

Write-Host "  找到 $($subscriptions.Count) 个订阅" -ForegroundColor White
foreach ($sub in $subscriptions) {
    Write-Host "    - $($sub.Name) ($($sub.Id))" -ForegroundColor White
}

# 读取RSV列表（如果存在）
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
    Write-Host "  未找到rsv.txt文件，将自动发现所有RSV" -ForegroundColor Yellow
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

# 如果没有RSV列表，自动发现所有RSV
if ($config.RSVList.Count -eq 0) {
    Write-Host "  自动发现所有RSV..." -ForegroundColor Yellow
    $allRSVs = @()
    
    foreach ($sub in $subscriptions) {
        # 切换到该订阅
        $null = Select-AzSubscription -SubscriptionId $sub.Id -ErrorAction SilentlyContinue
        
        # 获取该订阅下的所有RSV
        $rsvs = Get-AzRecoveryServicesVault -ErrorAction SilentlyContinue
        
        foreach ($rsv in $rsvs) {
            $allRSVs += @{
                SubscriptionId = $sub.Id
                SubscriptionName = $sub.Name
                RSVName = $rsv.Name
                ResourceGroupName = $rsv.ResourceGroupName
                Location = $rsv.Location
            }
        }
    }
    
    Write-Host "  发现 $($allRSVs.Count) 个RSV" -ForegroundColor Green
    
    # 找到第一个以"rsv"或"RSV"开头的RSV用于测试
    $testRSV = $allRSVs | Where-Object { $_.RSVName -like "rsv*" -or $_.RSVName -like "RSV*" } | Select-Object -First 1
    
    if ($testRSV) {
        $config.TestRSVName = $testRSV.RSVName
        $config.ResourceGroupName = $testRSV.ResourceGroupName
        $config.RSVList = @($testRSV.RSVName)
        Write-Host "  选择测试RSV: $($testRSV.RSVName) (订阅: $($testRSV.SubscriptionName))" -ForegroundColor Cyan
    }
    else {
        Write-Host "  警告: 未找到以'RSV'开头的RSV，使用第一个RSV" -ForegroundColor Yellow
        $firstRSV = $allRSVs | Select-Object -First 1
        if ($firstRSV) {
            $config.TestRSVName = $firstRSV.RSVName
            $config.ResourceGroupName = $firstRSV.ResourceGroupName
            $config.RSVList = @($firstRSV.RSVName)
            Write-Host "  选择测试RSV: $($firstRSV.RSVName) (订阅: $($firstRSV.SubscriptionName))" -ForegroundColor Cyan
        }
    }
    
    # 保存所有RSV到数据库
    $config.AllRSVs = $allRSVs
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
    
    if ($config.AllRSVs) {
        Write-Host ""
        Write-Host "  发现的RSV:" -ForegroundColor Cyan
        foreach ($rsv in $config.AllRSVs) {
            Write-Host "    - $($rsv.RSVName) (订阅: $($rsv.SubscriptionName), 资源组: $($rsv.ResourceGroupName))" -ForegroundColor White
        }
    }
    
    Write-Host ""
    Write-Host "WhatIf模式完成，未执行实际采集" -ForegroundColor Green
    exit 0
}

try {
    # 如果有自动发现的RSV列表，采集所有RSV
    if ($config.AllRSVs -and $config.AllRSVs.Count -gt 0) {
        Write-Host ""
        Write-Host "  采集所有订阅下的RSV配置..." -ForegroundColor Yellow
        
        foreach ($rsvInfo in $config.AllRSVs) {
            Write-Host "    正在采集: $($rsvInfo.RSVName) (订阅: $($rsvInfo.SubscriptionName))" -ForegroundColor White
            
            # 切换到该订阅
            $null = Select-AzSubscription -SubscriptionId $rsvInfo.SubscriptionId -ErrorAction SilentlyContinue
            
            # 采集该RSV的配置
            $rsvConfig = @{
                DatabasePath = $config.DatabasePath
                LogPath = $config.LogPath
                RSVList = @($rsvInfo.RSVName)
                ResourceGroupName = $rsvInfo.ResourceGroupName
                IncludeBackupVMs = $true
                IncludeReplicatedItems = $true
                EnableIncrementalCollection = $false
                EnableAutoExport = $false
            }
            
            $result = Invoke-RSVCollection -Config $rsvConfig
        }
        
        Write-Host "  所有RSV采集完成" -ForegroundColor Green
    }
    else {
        # 使用配置的RSV列表采集
        $collectionResult = Invoke-RSVCollection -Config $config
        
        if (-not $collectionResult) {
            Write-Host "RSV配置采集失败" -ForegroundColor Red
            exit 1
        }
    }
    
    Write-Host "RSV配置采集成功" -ForegroundColor Green
}
catch {
    Write-Host "RSV配置采集失败: $_" -ForegroundColor Red
    exit 1
}

# ========================================
# 导出测试RSV配置到Excel
# ========================================

Write-Host ""
Write-Host "步骤 6: 导出测试RSV配置到Excel..." -ForegroundColor Yellow

if ($config.TestRSVName) {
    Write-Host "  导出RSV: $($config.TestRSVName)" -ForegroundColor White
    
    # 创建导出目录
    if (-not (Test-Path $config.ExportPath)) {
        New-Item -ItemType Directory -Path $config.ExportPath -Force | Out-Null
    }
    
    # 生成CSV文件名
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $backupVMsPath = Join-Path $config.ExportPath "BackupVMs-$($config.TestRSVName)-$timestamp.csv"
    $replicatedItemsPath = Join-Path $config.ExportPath "ReplicatedItems-$($config.TestRSVName)-$timestamp.csv"
    
    Write-Host "  导出路径: $backupVMsPath" -ForegroundColor White
    
    try {
        # 重新打开数据库连接
        $dbInitialized = Initialize-RSVDatabase -DatabasePath $config.DatabasePath
        if (-not $dbInitialized) {
            Write-Host "  数据库初始化失败" -ForegroundColor Red
            return
        }
        
        # 导出Backup VMs
        Write-Host "    导出Backup VMs..." -ForegroundColor White
        $backupVMs = Get-RSVData -DataType "BackupVM" -Filter "RSVName = '$($config.TestRSVName)'" -OrderBy "CollectionTime DESC"
        
        if ($backupVMs -and $backupVMs.Count -gt 0) {
            $backupVMs | Export-Csv -Path $backupVMsPath -NoTypeInformation -Encoding UTF8BOM
            Write-Host "      导出 $($backupVMs.Count) 条Backup VM记录到 $backupVMsPath" -ForegroundColor Green
        }
        else {
            Write-Host "      没有Backup VM记录" -ForegroundColor Yellow
        }
        
        # 导出Replicated Items
        Write-Host "    导出Replicated Items..." -ForegroundColor White
        $replicatedItems = Get-RSVData -DataType "ReplicatedItem" -Filter "RSVName = '$($config.TestRSVName)'" -OrderBy "CollectionTime DESC"
        
        if ($replicatedItems -and $replicatedItems.Count -gt 0) {
            $replicatedItems | Export-Csv -Path $replicatedItemsPath -NoTypeInformation -Encoding UTF8BOM
            Write-Host "      导出 $($replicatedItems.Count) 条Replicated Item记录到 $replicatedItemsPath" -ForegroundColor Green
        }
        else {
            Write-Host "      没有Replicated Item记录" -ForegroundColor Yellow
        }
        
        # 关闭数据库连接
        Close-RSVDatabase
        
        Write-Host "  CSV导出成功" -ForegroundColor Green
    }
    catch {
        Write-Host "  CSV导出失败: $_" -ForegroundColor Red
    }
}
else {
    Write-Host "  未选择测试RSV，跳过Excel导出" -ForegroundColor Yellow
}

# ========================================
# 显示结果
# ========================================

Write-Host ""
Write-Host "步骤 7: 显示采集结果..." -ForegroundColor Yellow

if (Test-Path $config.DatabasePath) {
    Write-Host "数据库文件: $($config.DatabasePath)" -ForegroundColor White
    
    # 获取数据库大小
    $dbSize = (Get-Item $config.DatabasePath).Length / 1MB
    Write-Host "数据库大小: $([math]::Round($dbSize, 2)) MB" -ForegroundColor White
    
    # 显示数据摘要
    Write-Host ""
    Write-Host "数据摘要:" -ForegroundColor Cyan
    Get-RSVDataSummary
}

if (Test-Path $config.ExportPath) {
    $exportFiles = Get-ChildItem -Path $config.ExportPath -Filter "*.xlsx" -ErrorAction SilentlyContinue
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
