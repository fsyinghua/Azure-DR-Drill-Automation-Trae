# 远端环境检查脚本
# 用于验证远端机器是否满足运行Azure DR Drill Automation脚本的要求

param(
    [switch]$SkipAzureLogin
)

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "远端环境检查" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$allPassed = $true

# 检查PowerShell版本
Write-Host "[1] PowerShell版本" -ForegroundColor Yellow
$psVersion = $PSVersionTable.PSVersion
Write-Host "  版本: $psVersion" -ForegroundColor White
if ($psVersion.Major -ge 5) {
    Write-Host "  ✓ 版本符合要求" -ForegroundColor Green
}
else {
    Write-Host "  ✗ 版本过低，需要5.1或更高" -ForegroundColor Red
    $allPassed = $false
}

# 检查.NET版本
Write-Host "  .NET版本: $($PSVersionTable.CLRVersion)" -ForegroundColor White
Write-Host ""

# 检查Az模块
Write-Host "[2] Az PowerShell模块" -ForegroundColor Yellow
$azModule = Get-Module -ListAvailable -Name Az | Select-Object -First 1

# 如果ListAvailable找不到，尝试检查已加载的模块
if (-not $azModule) {
    $azModule = Get-Module -Name Az -ErrorAction SilentlyContinue | Select-Object -First 1
}

# 如果还是找不到，尝试检查是否有Az命令
if (-not $azModule) {
    $azCommands = Get-Command -Module Az* -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($azCommands) {
        $azModule = [PSCustomObject]@{
            Name = "Az"
            Version = "已加载"
        }
    }
}

if ($azModule) {
    Write-Host "  ✓ Az模块已安装" -ForegroundColor Green
    Write-Host "  版本: $($azModule.Version)" -ForegroundColor White
    
    # 检查是否有多个Az模块版本
    Write-Host "  检查Az模块冲突..." -ForegroundColor Yellow
    $allAzModules = Get-Module -ListAvailable -Name Az* | Group-Object Name | Where-Object { $_.Count -gt 1 }
    if ($allAzModules.Count -gt 0) {
        Write-Host "  ⚠ 警告: 发现多个版本的Az模块" -ForegroundColor Yellow
        foreach ($moduleGroup in $allAzModules) {
            Write-Host "    - $($moduleGroup.Name) ($($moduleGroup.Count) 个版本)" -ForegroundColor White
        }
    }
    else {
        Write-Host "  ✓ 未发现模块冲突" -ForegroundColor Green
    }
    
    # 检查当前加载的模块
    Write-Host "  检查已加载的模块..." -ForegroundColor Yellow
    $loadedModules = Get-Module -Name Az* | Select-Object Name, Version
    if ($loadedModules) {
        Write-Host "  已加载 $($loadedModules.Count) 个Az相关模块:" -ForegroundColor White
        foreach ($module in $loadedModules) {
            Write-Host "    - $($module.Name) (版本: $($module.Version))" -ForegroundColor White
        }
    }
    
    # 测试Get-AzSubscription命令
    Write-Host "  测试Get-AzSubscription命令..." -ForegroundColor Yellow
    try {
        $testResult = Get-AzSubscription -ErrorAction Stop | Select-Object -First 1
        if ($testResult) {
            Write-Host "  ✓ Get-AzSubscription命令正常" -ForegroundColor Green
        }
        else {
            Write-Host "  ⚠ 警告: Get-AzSubscription返回空结果" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "  ✗ Get-AzSubscription命令失败: $_" -ForegroundColor Red
        Write-Host "  错误类型: $($_.Exception.GetType().FullName)" -ForegroundColor Red
        $allPassed = $false
    }
}
else {
    Write-Host "  ✗ Az模块未安装" -ForegroundColor Red
    Write-Host "  请运行: Install-Module -Name Az -Scope CurrentUser -Force" -ForegroundColor Yellow
    $allPassed = $false
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
        $allPassed = $false
    }
}
else {
    Write-Host "  ✗ System.Data.SQLite.dll未找到" -ForegroundColor Red
    Write-Host "  请运行: .\scripts\install-sqlite-dll.ps1" -ForegroundColor Yellow
    $allPassed = $false
}
Write-Host ""

# 检查目录权限
Write-Host "[4] 目录权限" -ForegroundColor Yellow
$testDirs = @("cache", "data", "logs")
$dirsOk = $true
foreach ($dir in $testDirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $testFile = ".\$dir\test.txt"
    try {
        "test" | Out-File -FilePath $testFile -Force
        Remove-Item -Path $testFile -Force
        Write-Host "  ✓ $dir 目录有写入权限" -ForegroundColor Green
    }
    catch {
        Write-Host "  ✗ $dir 目录无写入权限" -ForegroundColor Red
        $dirsOk = $false
        $allPassed = $false
    }
}
Write-Host ""

# 检查网络连接
Write-Host "[5] 网络连接" -ForegroundColor Yellow
$endpoints = @(
    "login.microsoftonline.com",
    "management.azure.com"
)
$networkOk = $true
foreach ($endpoint in $endpoints) {
    $result = Test-NetConnection -ComputerName $endpoint -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
    if ($result) {
        Write-Host "  ✓ $endpoint:443 可访问" -ForegroundColor Green
    }
    else {
        Write-Host "  ✗ $endpoint:443 不可访问" -ForegroundColor Red
        $networkOk = $false
        $allPassed = $false
    }
}
Write-Host ""

# 检查Azure登录状态（可选）
if (-not $SkipAzureLogin) {
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
            $allPassed = $false
        }
    }
    catch {
        Write-Host "  ✗ 未登录" -ForegroundColor Red
        Write-Host "  请运行: Connect-AzAccount -UseDeviceAuthentication" -ForegroundColor Yellow
        $allPassed = $false
    }
    Write-Host ""
}
else {
    Write-Host "[6] Azure登录状态" -ForegroundColor Yellow
    Write-Host "  ⊘ 已跳过（使用 -SkipAzureLogin 参数）" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Cyan
if ($allPassed) {
    Write-Host "✓ 所有检查通过，环境准备就绪！" -ForegroundColor Green
}
else {
    Write-Host "✗ 部分检查未通过，请根据上述提示修复问题" -ForegroundColor Red
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 返回退出码
exit $([int](-not $allPassed))
