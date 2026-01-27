# 安装指南

## 概述

本文档提供了Azure DR Drill Automation项目所需的所有模块和工具的安装命令和前提条件。

## 前提条件

### 1. PowerShell版本要求

- **最低版本**: PowerShell 5.1
- **推荐版本**: PowerShell 7.x (PowerShell Core)

**检查PowerShell版本**:
```powershell
$PSVersionTable.PSVersion
```

**安装PowerShell 7.x**:
```powershell
# 使用winget安装
winget install Microsoft.PowerShell

# 或从官网下载安装
# https://github.com/PowerShell/PowerShell/releases
```

### 2. 网络要求

- 能够访问以下域名：
  - `login.microsoftonline.com` - Azure认证
  - `www.powershellgallery.com` - PowerShell Gallery
  - `management.azure.com` - Azure管理
  - `*.azure.net` - Azure服务端点

- 稳定的网络连接
- 如有防火墙，确保允许HTTPS流量

### 3. 权限要求

- Windows用户账户（无需管理员权限）
- PowerShell执行策略允许脚本运行

**检查执行策略**:
```powershell
Get-ExecutionPolicy
```

**设置执行策略**（如需要）:
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## 安装Azure PowerShell模块

### 方法1：使用PowerShell Gallery（推荐）

```powershell
# 安装Az模块（包含所有Azure服务模块）
Install-Module -Name Az -AllowClobber -Scope CurrentUser -Force

# 更新已安装的模块
Update-Module -Name Az

# 查看已安装的模块
Get-Module -ListAvailable -Name Az*
```

### 方法2：使用PowerShell Get命令

```powershell
# 查找Az模块
Find-Module -Name Az

# 安装特定版本
Install-Module -Name Az -RequiredVersion <version> -Scope CurrentUser
```

### 方法3：离线安装

如果无法访问PowerShell Gallery，可以离线安装：

```powershell
# 1. 在有网络的机器上下载模块
Save-Module -Name Az -Path C:\Temp\Modules

# 2. 将模块复制到目标机器
# 3. 安装模块
Install-Module -Name Az -Repository C:\Temp\Modules -Scope CurrentUser
```

### 验证安装

```powershell
# 检查Az模块是否已安装
Get-Module -ListAvailable -Name Az

# 查看Az模块版本
(Get-Module -ListAvailable -Name Az).Version

# 导入Az模块测试
Import-Module Az -Verbose
```

## 安装SQLLite相关模块

### SQLite模块

SQLite是一个轻量级的嵌入式数据库，用于存储DR演练结果。

#### 安装SQLite PowerShell模块

```powershell
# 方法1：从PowerShell Gallery安装
Install-Module -Name PSSQLite -Scope CurrentUser -Force

# 方法2：使用NuGet安装
Install-Package -Name System.Data.SQLite -Scope CurrentUser

# 方法3：手动安装SQLite DLL
# 下载SQLite DLL并放置在脚本目录下
```

#### 验证SQLite模块

```powershell
# 检查PSSQLite模块
Get-Module -ListAvailable -Name PSSQLite

# 测试SQLite功能
Import-Module PSSQLite
Test-SQLiteConnection
```

### 其他SQL相关模块

根据项目需求，可能需要以下模块：

```powershell
# SQL Server模块（如果使用SQL Server）
Install-Module -Name SqlServer -Scope CurrentUser -Force

# 注意：MySQL和PostgreSQL模块在PowerShell Gallery中不存在
# 如需使用这些数据库，请使用相应的.NET驱动或ODBC连接
```

### SQLite模块说明

SQLite是一个轻量级的嵌入式数据库，用于本地存储DR演练结果。

#### 方法1：使用System.Data.SQLite（推荐）

```powershell
# 安装System.Data.SQLite NuGet包
Install-Package -Name System.Data.SQLite -Scope CurrentUser

# 或使用NuGet CLI
nuget install System.Data.SQLite
```

#### 方法2：手动下载SQLite DLL

```powershell
# 1. 下载SQLite DLL
# 访问: https://system.data.sqlite.org/
# 下载: System.Data.SQLite.dll

# 2. 将DLL放置在项目目录
# 创建目录: .\lib\
# 复制DLL到: .\lib\System.Data.SQLite.dll

# 3. 在脚本中加载DLL
Add-Type -Path ".\lib\System.Data.SQLite.dll"
```

#### 方法3：使用PSSQLite（如果可用）

```powershell
# 搜索SQLite相关模块
Find-Module -Name "*SQLite*"

# 安装找到的模块
Install-Module -Name <ModuleName> -Scope CurrentUser -Force
```

## 完整安装脚本

### 自动安装所有必需模块

创建一个完整的安装脚本：

```powershell
<#
.SYNOPSIS
    自动安装所有必需的PowerShell模块

.DESCRIPTION
    安装Azure PowerShell模块和SQLLite相关模块
#>

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Azure DR Drill - 模块安装" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 步骤1: 检查PowerShell版本
Write-Host "步骤 1: 检查PowerShell版本..." -ForegroundColor Yellow
$psVersion = $PSVersionTable.PSVersion
Write-Host "  当前版本: $($psVersion)" -ForegroundColor White

if ($psVersion.Major -lt 5) {
    Write-Host "  错误: 需要PowerShell 5.1或更高版本" -ForegroundColor Red
    exit 1
}
Write-Host "  版本检查通过" -ForegroundColor Green

# 步骤2: 检查执行策略
Write-Host ""
Write-Host "步骤 2: 检查执行策略..." -ForegroundColor Yellow
$executionPolicy = Get-ExecutionPolicy -Scope CurrentUser
Write-Host "  当前策略: $executionPolicy" -ForegroundColor White

if ($executionPolicy -eq "Restricted") {
    Write-Host "  警告: 执行策略为Restricted，可能无法运行脚本" -ForegroundColor Yellow
    $changePolicy = Read-Host "是否修改执行策略为RemoteSigned? (Y/N)"
    if ($changePolicy -eq "Y" -or $changePolicy -eq "y") {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
        Write-Host "  执行策略已更新" -ForegroundColor Green
    }
}

# 步骤3: 安装Azure PowerShell模块
Write-Host ""
Write-Host "步骤 3: 安装Azure PowerShell模块..." -ForegroundColor Yellow
try {
    $azModule = Get-Module -ListAvailable -Name Az -ErrorAction SilentlyContinue
    
    if ($azModule) {
        Write-Host "  Az模块已安装: $($azModule.Version)" -ForegroundColor Green
        $update = Read-Host "是否更新到最新版本? (Y/N)"
        if ($update -eq "Y" -or $update -eq "y") {
            Update-Module -Name Az -Scope CurrentUser -Force
            Write-Host "  Az模块已更新" -ForegroundColor Green
        }
    }
    else {
        Write-Host "  正在安装Az模块..." -ForegroundColor Cyan
        Install-Module -Name Az -AllowClobber -Scope CurrentUser -Force
        Write-Host "  Az模块安装完成" -ForegroundColor Green
    }
}
catch {
    Write-Host "  安装Az模块失败: $_" -ForegroundColor Red
    exit 1
}

# 步骤4: 安装SQLite模块
Write-Host ""
Write-Host "步骤 4: 安装SQLite模块..." -ForegroundColor Yellow
try {
    $sqliteModule = Get-Module -ListAvailable -Name PSSQLite -ErrorAction SilentlyContinue
    
    if ($sqliteModule) {
        Write-Host "  PSSQLite模块已安装: $($sqliteModule.Version)" -ForegroundColor Green
    }
    else {
        Write-Host "  正在安装PSSQLite模块..." -ForegroundColor Cyan
        Install-Module -Name PSSQLite -Scope CurrentUser -Force
        Write-Host "  PSSQLite模块安装完成" -ForegroundColor Green
    }
}
catch {
    Write-Host "  安装PSSQLite模块失败: $_" -ForegroundColor Yellow
    Write-Host "  注意: SQLite模块是可选的，如果不需要可以跳过" -ForegroundColor Yellow
}

# 步骤5: 验证安装
Write-Host ""
Write-Host "步骤 5: 验证安装..." -ForegroundColor Yellow

$azInstalled = Get-Module -ListAvailable -Name Az -ErrorAction SilentlyContinue
$sqliteInstalled = Get-Module -ListAvailable -Name PSSQLite -ErrorAction SilentlyContinue

Write-Host "  Az模块: $(if ($azInstalled) { '已安装' } else { '未安装' })" -ForegroundColor $(if ($azInstalled) { 'Green' } else { 'Red' })
Write-Host "  PSSQLite模块: $(if ($sqliteInstalled) { '已安装' } else { '未安装' })" -ForegroundColor $(if ($sqliteInstalled) { 'Green' } else { 'Yellow' })

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "安装完成!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "下一步:" -ForegroundColor Cyan
Write-Host "  1. 运行测试脚本: .\test\Test-LoginModule-Simple.ps1" -ForegroundColor White
Write-Host "  2. 运行DR演练: .\Start-DRDrill.ps1" -ForegroundColor White
Write-Host ""
```

### 快速安装命令

如果只需要快速安装，可以使用以下命令：

```powershell
# 一键安装所有必需模块
Install-Module -Name Az, PSSQLite -Scope CurrentUser -Force

# 或分别安装
Install-Module -Name Az -Scope CurrentUser -Force
Install-Module -Name PSSQLite -Scope CurrentUser -Force
```

## 配置Azure连接

### 使用Device Login（推荐）

由于防火墙SSLO限制，使用Device Login方式：

```powershell
# 连接到Azure
Connect-AzAccount -UseDeviceAuthentication

# 按照提示操作：
# 1. 访问 https://microsoft.com/devicelogin
# 2. 输入显示的代码
# 3. 完成认证
```

### 使用服务主体（自动化场景）

如果需要自动化，可以使用服务主体：

```powershell
# 创建服务主体（需要Azure AD管理员权限）
$sp = New-AzADServicePrincipal -DisplayName "DRDrillService"

# 使用服务主体登录
$credential = Get-Credential
Connect-AzAccount -ServicePrincipal -Credential $credential -TenantId <tenant-id>
```

## 验证安装

### 测试Azure模块

```powershell
# 导入Az模块
Import-Module Az

# 测试连接
Get-AzContext

# 列出订阅
Get-AzSubscription
```

### 测试SQLite模块

```powershell
# 导入SQLite模块
Import-Module PSSQLite

# 创建测试数据库
$db = New-SQLiteDatabase -Path "test.db"

# 创建测试表
Invoke-SQLiteQuery -Database $db -Query "CREATE TABLE test (id INTEGER PRIMARY KEY, name TEXT)"

# 插入测试数据
Invoke-SQLiteQuery -Database $db -Query "INSERT INTO test (name) VALUES ('test')"

# 查询数据
Invoke-SQLiteQuery -Database $db -Query "SELECT * FROM test"
```

## 故障排查

### 问题1：无法访问PowerShell Gallery

**错误信息**：
```
Unable to resolve package source 'https://www.powershellgallery.com/api/v2/'
```

**解决方案**：
```powershell
# 检查网络连接
Test-NetConnection -ComputerName www.powershellgallery.com -Port 443

# 使用代理（如果需要）
[Net.WebRequest]::DefaultWebProxy = "http://proxy.example.com:8080"

# 或使用离线安装
```

### 问题2：执行策略限制

**错误信息**：
```
running scripts is disabled on this system
```

**解决方案**：
```powershell
# 修改执行策略
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# 或临时绕过（不推荐）
powershell.exe -ExecutionPolicy Bypass -File script.ps1
```

### 问题3：模块版本冲突

**错误信息**：
```
The module 'Az' is already loaded
```

**解决方案**：
```powershell
# 卸载旧版本
Remove-Module Az -Force

# 重新安装
Install-Module -Name Az -Force -Scope CurrentUser

# 重启PowerShell
```

### 问题4：SQLite模块安装失败

**错误信息**：
```
No match was found for the specified search term 'PSSQLite'
```

**解决方案**：
```powershell
# 搜索可用的SQLite模块
Find-Module -Name *SQLite*

# 使用不同的模块名
Install-Module -Name System.Data.SQLite -Scope CurrentUser

# 或手动下载SQLite DLL
# https://system.data.sqlite.org/
```

## 清理和卸载

### 卸载模块

```powershell
# 卸载Az模块
Uninstall-Module -Name Az -Force

# 卸载SQLite模块
Uninstall-Module -Name PSSQLite -Force

# 清理缓存
Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\PowerShell\Modules" -Recurse -Force
```

### 清理临时文件

```powershell
# 清理PowerShell临时文件
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue

# 清理NuGet缓存
Remove-Item -Path "$env:LOCALAPPDATA\NuGet\Cache" -Recurse -Force -ErrorAction SilentlyContinue
```

## 最佳实践

1. **使用Scope CurrentUser**
   - 无需管理员权限
   - 不影响其他用户
   - 适合个人开发环境

2. **定期更新模块**
   ```powershell
   # 每月更新一次
   Update-Module -Name Az, PSSQLite
   ```

3. **使用版本控制**
   - 记录使用的模块版本
   - 测试新版本后再更新

4. **离线环境准备**
   - 提前下载所需模块
   - 保存到本地目录
   - 离线安装时使用

5. **网络优化**
   - 使用国内镜像（如可用）
   - 配置代理（如需要）
   - 确保DNS解析正常

## 相关文档

- [README.md](README.md) - 项目使用指南
- [LOGIN_MODULE.md](LOGIN_MODULE.md) - 登录模块文档
- [TOKEN_CACHE.md](TOKEN_CACHE.md) - Token缓存机制说明
- [test/README.md](test/README.md) - 测试脚本说明

## 版本历史

| 版本 | 日期 | 变更说明 |
|------|------|---------|
| 1.0.0 | 2026-01-27 | 初始版本，创建安装指南 |