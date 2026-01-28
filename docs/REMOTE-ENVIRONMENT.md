# 远端运行环境准备指南

## 概述

本文档说明在远端机器上运行Azure DR Drill Automation脚本所需的环境准备步骤。

**文档版本**: 1.0.0  
**创建日期**: 2026-01-28  
**最后更新**: 2026-01-28

---

## 环境要求

### 1. PowerShell版本
- **最低要求**: PowerShell 5.1
- **推荐版本**: PowerShell 7.x
- **检查命令**:
  ```powershell
  $PSVersionTable.PSVersion
  ```

### 2. 操作系统
- Windows 10/11
- Windows Server 2016/2019/2022
- Linux（通过PowerShell Core）

---

## 必需的PowerShell模块

### 2.1 Az PowerShell模块
**用途**: Azure资源管理

**安装命令**:
```powershell
# 方法1: 从PowerShell Gallery安装
Install-Module -Name Az -Scope CurrentUser -Force

# 方法2: 如果NuGet源不可用，使用预编译模块
# 下载后解压到: $env:USERPROFILE\Documents\WindowsPowerShell\Modules\Az
```

**验证安装**:
```powershell
Get-Module -ListAvailable -Name Az
```

**重要**: 安装后需要登录Azure：
```powershell
Connect-AzAccount -UseDeviceAuthentication
```

### 2.2 System.Data.SQLite
**用途**: SQLite数据库操作

**安装方法**:

**方法1: 使用自动安装脚本（推荐）**
```powershell
.\scripts\install-sqlite-dll.ps1
```

**方法2: 手动安装**
1. 访问 https://www.nuget.org/packages/System.Data.SQLite/
2. 下载最新版本的.nupkg文件
3. 将.nupkg文件重命名为.zip并解压
4. 将`lib\net46\System.Data.SQLite.dll`复制到项目的`lib`目录

**验证安装**:
```powershell
# 检查lib目录下的DLL
Test-Path .\lib\System.Data.SQLite.dll

# 尝试加载程序集
Add-Type -Path .\lib\System.Data.SQLite.dll
$null = [System.Data.SQLite.SQLiteConnection]
```

### 2.3 可选模块
**PSSQLite模块**: 提供mount-sqlite命令（可选）

```powershell
Install-Module -Name PSSQLite -Scope CurrentUser -Force
```

**注意**: PSSQLite模块不是必需的，System.Data.SQLite才是核心依赖。

---

## 文件系统要求

### 3.1 目录权限
脚本需要以下目录的写入权限：

| 目录 | 用途 | 自动创建 |
|------|------|---------|
| `./cache` | 存储Azure登录缓存 | ✓ |
| `./data` | 存储SQLite数据库 | ✓ |
| `./logs` | 存储日志文件 | ✓ |
| `./lib` | 存放System.Data.SQLite.dll | ✗ |

### 3.2 检查权限
```powershell
# 测试写入权限
$testDirs = @("cache", "data", "logs")
foreach ($dir in $testDirs) {
    $testFile = ".\$dir\test.txt"
    try {
        "test" | Out-File -FilePath $testFile -Force
        Remove-Item -Path $testFile -Force
        Write-Host "✓ $dir 目录有写入权限" -ForegroundColor Green
    }
    catch {
        Write-Host "✗ $dir 目录无写入权限" -ForegroundColor Red
    }
}
```

---

## 网络要求

### 4.1 Azure API访问
需要访问以下Azure端点：
- `login.microsoftonline.com` - Azure认证
- `management.azure.com` - Azure资源管理
- `*.vault.azure.net` - Recovery Services Vault访问

### 4.2 NuGet访问（可选）
如果使用自动安装脚本，需要访问：
- `www.nuget.org` - NuGet包源

### 4.3 测试网络连接
```powershell
# 测试Azure连接
Test-NetConnection -ComputerName login.microsoftonline.com -Port 443
Test-NetConnection -ComputerName management.azure.com -Port 443

# 测试NuGet连接（可选）
Test-NetConnection -ComputerName www.nuget.org -Port 443
```

---

## 认证要求

### 5.1 Azure账户
- 需要有效的Azure账户
- 账户需要有访问目标订阅的权限
- 支持多因素认证（MFA）

### 5.2 设备登录
脚本使用设备登录模式，不需要在远端机器上存储凭据：

```powershell
Connect-AzAccount -UseDeviceAuthentication
```

**登录流程**:
1. 运行登录命令
2. 复制显示的代码和URL
3. 在浏览器中打开URL并输入代码
4. 完成认证

### 5.3 Token缓存
登录信息会缓存到`./cache/azure-login-cache.json`，默认缓存60分钟。

---

## 环境变量

**当前版本不需要设置任何环境变量**。

所有配置都通过：
- 脚本参数传递
- 配置文件（如果添加）
- 默认值

---

## 快速检查脚本

创建一个环境检查脚本：

```powershell
# check-environment.ps1
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "环境检查" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 检查PowerShell版本
Write-Host "[1] PowerShell版本" -ForegroundColor Yellow
$psVersion = $PSVersionTable.PSVersion
Write-Host "  版本: $psVersion" -ForegroundColor White
if ($psVersion.Major -ge 5) {
    Write-Host "  ✓ 版本符合要求" -ForegroundColor Green
}
else {
    Write-Host "  ✗ 版本过低，需要5.1或更高" -ForegroundColor Red
}
Write-Host ""

# 检查Az模块
Write-Host "[2] Az PowerShell模块" -ForegroundColor Yellow
$azModule = Get-Module -ListAvailable -Name Az
if ($azModule) {
    Write-Host "  ✓ Az模块已安装" -ForegroundColor Green
    Write-Host "  版本: $($azModule.Version)" -ForegroundColor White
}
else {
    Write-Host "  ✗ Az模块未安装" -ForegroundColor Red
    Write-Host "  请运行: Install-Module -Name Az -Scope CurrentUser -Force" -ForegroundColor Yellow
}
Write-Host ""

# 检查System.Data.SQLite
Write-Host "[3] System.Data.SQLite" -ForegroundColor Yellow
$dllPath = ".\lib\System.Data.SQLite.dll"
if (Test-Path $dllPath) {
    Write-Host "  ✓ System.Data.SQLite.dll已找到" -ForegroundColor Green
    try {
        Add-Type -Path $dllPath -ErrorAction Stop
        $null = [System.Data.SQLite.SQLiteConnection]
        Write-Host "  ✓ DLL加载成功" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ DLL加载失败: $_" -ForegroundColor Red
    }
}
else {
    Write-Host "  ✗ System.Data.SQLite.dll未找到" -ForegroundColor Red
    Write-Host "  请运行: .\scripts\install-sqlite-dll.ps1" -ForegroundColor Yellow
}
Write-Host ""

# 检查目录权限
Write-Host "[4] 目录权限" -ForegroundColor Yellow
$testDirs = @("cache", "data", "logs")
$allOk = $true
foreach ($dir in $testDirs) {
    $testFile = ".\$dir\test.txt"
    try {
        "test" | Out-File -FilePath $testFile -Force
        Remove-Item -Path $testFile -Force
        Write-Host "  ✓ $dir 目录有写入权限" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ $dir 目录无写入权限" -ForegroundColor Red
        $allOk = $false
    }
}
Write-Host ""

# 检查网络连接
Write-Host "[5] 网络连接" -ForegroundColor Yellow
$endpoints = @(
    "login.microsoftonline.com",
    "management.azure.com"
)
foreach ($endpoint in $endpoints) {
    $result = Test-NetConnection -ComputerName $endpoint -Port 443 -InformationLevel Quiet
    if ($result) {
        Write-Host "  ✓ $endpoint:443 可访问" -ForegroundColor Green
    }
    else {
        Write-Host "  ✗ $endpoint:443 不可访问" -ForegroundColor Red
    }
}
Write-Host ""

# 检查Azure登录状态
Write-Host "[6] Azure登录状态" -ForegroundColor Yellow
try {
    $context = Get-AzContext -ErrorAction Stop
    if ($context) {
        Write-Host "  ✓ 已登录" -ForegroundColor Green
        Write-Host "  账户: $($context.Account.Id)" -ForegroundColor White
        Write-Host "  订阅: $($context.Subscription.Name)" -ForegroundColor White
    }
    else {
        Write-Host "  ✗ 未登录" -ForegroundColor Red
        Write-Host "  请运行: Connect-AzAccount -UseDeviceAuthentication" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "  ✗ 未登录" -ForegroundColor Red
    Write-Host "  请运行: Connect-AzAccount -UseDeviceAuthentication" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "环境检查完成" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
```

---

## 常见问题

### Q1: 无法安装Az模块
**原因**: PowerShell Gallery不可访问或网络受限

**解决方案**:
1. 检查网络连接
2. 配置代理（如果需要）
3. 手动下载模块并安装

### Q2: System.Data.SQLite安装失败
**原因**: NuGet源不可访问

**解决方案**:
1. 使用手动安装方法
2. 从其他机器复制DLL到lib目录

### Q3: 目录无写入权限
**原因**: 当前用户没有目录写入权限

**解决方案**:
1. 以管理员身份运行
2. 更改目录权限
3. 使用有权限的目录

### Q4: Azure登录失败
**原因**: 网络问题或认证问题

**解决方案**:
1. 检查网络连接
2. 确认账户凭据正确
3. 检查MFA设置

---

## 版本历史

| 版本 | 日期 | 变更说明 | 作者 |
|------|------|---------|------|
| 1.0.0 | 2026-01-28 | 初始版本 | Azure DR Team |

---

## 联系信息

如有问题或建议，请联系：
- **项目团队**: Azure DR Team
- **文档位置**: `d:\UserProfiles\JoeHe\Codes\Azure-DR-Drill-Automation-Trae\docs\`

---

**文档最后更新**: 2026-01-28
