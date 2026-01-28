<#
.SYNOPSIS
    一键安装所有必需的PowerShell模块

.DESCRIPTION
    快速安装Azure PowerShell模块和SQLite相关模块

.NOTES
    Version: 1.0.0
    Author: Azure DR Team
    Date: 2026-01-27
#>

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Azure DR Drill - 模块安装" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "步骤 1: 检查PowerShell版本..." -ForegroundColor Yellow
$psVersion = $PSVersionTable.PSVersion
Write-Host "  当前版本: $($psVersion)" -ForegroundColor White

if ($psVersion.Major -lt 5) {
    Write-Host "  错误: 需要PowerShell 5.1或更高版本" -ForegroundColor Red
    exit 1
}
Write-Host "  版本检查通过" -ForegroundColor Green

Write-Host ""
Write-Host "步骤 2: 检查执行策略..." -ForegroundColor Yellow
$executionPolicy = Get-ExecutionPolicy -Scope CurrentUser
Write-Host "  当前策略: $executionPolicy" -ForegroundColor White

Write-Host ""
Write-Host "步骤 3: 安装Azure PowerShell模块..." -ForegroundColor Yellow
try {
    $azModule = Get-Module -ListAvailable -Name Az -ErrorAction SilentlyContinue

    if ($azModule) {
        Write-Host "  Az模块已安装: $($azModule.Version)" -ForegroundColor Green
        $update = Read-Host "  是否更新到最新版本? (Y/N)"
        if ($update -eq "Y" -or $update -eq "y") {
            Write-Host "  正在更新Az模块..." -ForegroundColor Cyan
            Update-Module -Name Az -Scope CurrentUser -Force
            Write-Host "  Az模块已更新" -ForegroundColor Green
        }
    }
    else {
        Write-Host "  正在安装Az模块..." -ForegroundColor Cyan
        Write-Host "  这可能需要几分钟时间，请耐心等待..." -ForegroundColor Gray
        Install-Module -Name Az -AllowClobber -Scope CurrentUser -Force
        Write-Host "  Az模块安装完成" -ForegroundColor Green
    }
}
catch {
    Write-Host "  安装Az模块失败: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "  请检查:" -ForegroundColor Yellow
    Write-Host "  1. 网络连接是否正常" -ForegroundColor White
    Write-Host "  2. 是否可以访问PowerShell Gallery" -ForegroundColor White
    Write-Host "  3. 是否有足够的磁盘空间" -ForegroundColor White
    exit 1
}

Write-Host ""
Write-Host "步骤 4: 安装SQLite模块..." -ForegroundColor Yellow
Write-Host "  注意: SQLite模块是可选的，用于本地存储DR演练结果" -ForegroundColor Gray
try {
    $sqliteModule = Get-Module -ListAvailable -Name System.Data.SQLite -ErrorAction SilentlyContinue

    if ($sqliteModule) {
        Write-Host "  System.Data.SQLite模块已安装: $($sqliteModule.Version)" -ForegroundColor Green
    }
    else {
        Write-Host "  正在查找SQLite模块..." -ForegroundColor Cyan
        $sqliteModules = Find-Module -Name "*SQLite*" -Repository PSGallery

        if ($sqliteModules.Count -gt 0) {
            Write-Host "  找到以下SQLite相关模块:" -ForegroundColor White
            for ($i = 0; $i -lt [Math]::Min(5, $sqliteModules.Count); $i++) {
                Write-Host "    $($i + 1). $($sqliteModules[$i].Name) - $($sqliteModules[$i].Version)" -ForegroundColor Gray
            }

            if ($sqliteModules.Count -gt 5) {
                Write-Host "    ... 还有 $($sqliteModules.Count - 5) 个模块" -ForegroundColor Gray
            }

            Write-Host ""
            $installSqlite = Read-Host "  是否安装SQLite模块? (Y/N)"
            if ($installSqlite -eq "Y" -or $installSqlite -eq "y") {
                $selectedModule = $sqliteModules[0].Name
                if ($sqliteModules.Count -gt 1) {
                    Write-Host ""
                    Write-Host "  选择要安装的SQLite模块:" -ForegroundColor Yellow
                    for ($i = 0; $i -lt [Math]::Min(5, $sqliteModules.Count); $i++) {
                        Write-Host "    [$($i + 1)] $($sqliteModules[$i].Name)" -ForegroundColor White
                    }
                    $selection = Read-Host "  请输入选项 (1-$($sqliteModules.Count))"
                    $selectedIndex = [int]$selection - 1
                    if ($selectedIndex -ge 0 -and $selectedIndex -lt $sqliteModules.Count) {
                        $selectedModule = $sqliteModules[$selectedIndex].Name
                    }
                }

                Write-Host "  正在安装$selectedModule..." -ForegroundColor Cyan
                Install-Module -Name $selectedModule -Scope CurrentUser -Force
                Write-Host "  $selectedModule安装完成" -ForegroundColor Green
            }
        }
        else {
            Write-Host "  未找到SQLite模块" -ForegroundColor Yellow
            Write-Host "  提示: SQLite模块是可选的，可以跳过" -ForegroundColor Gray
            Write-Host "  提示: 如需使用SQLite，可以手动下载System.Data.SQLite.dll" -ForegroundColor Gray
        }
    }
}
catch {
    Write-Host "  安装SQLite模块失败: $_" -ForegroundColor Yellow
    Write-Host "  注意: SQLite模块是可选的，可以跳过" -ForegroundColor Gray
}

Write-Host ""
Write-Host "步骤 5: 验证安装..." -ForegroundColor Yellow

$azInstalled = Get-Module -ListAvailable -Name Az -ErrorAction SilentlyContinue
$sqliteInstalled = Get-Module -ListAvailable -Name System.Data.SQLite -ErrorAction SilentlyContinue

Write-Host "  Az模块: $(if ($azInstalled) { '已安装' } else { '未安装' })" -ForegroundColor $(if ($azInstalled) { 'Green' } else { 'Red' })
if ($azInstalled) {
    Write-Host "    版本: $($azInstalled.Version)" -ForegroundColor Gray
}

$sqliteStatus = if ($sqliteInstalled) { '已安装' } else { '未安装' }
Write-Host "  SQLite模块: $sqliteStatus" -ForegroundColor $(if ($sqliteInstalled) { 'Green' } else { 'Yellow' })
if ($sqliteInstalled) {
    Write-Host "    版本: $($sqliteInstalled.Version)" -ForegroundColor Gray
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "安装完成!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

Write-Host "下一步:" -ForegroundColor Cyan
Write-Host "  1. 连接到Azure: Connect-AzAccount -UseDeviceAuthentication" -ForegroundColor White
Write-Host "  2. 运行测试脚本: .\test\Test-LoginModule-Simple.ps1" -ForegroundColor White
Write-Host "  3. 运行DR演练: .\Start-DRDrill.ps1" -ForegroundColor White
Write-Host ""

Write-Host "查看详细安装指南: .\INSTALLATION.md" -ForegroundColor Cyan
Write-Host ""