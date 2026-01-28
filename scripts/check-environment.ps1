# 远端环境检查脚本
# 用于验证远端机器是否满足运行Azure DR Drill Automation脚本的要求

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
Write-Host ""

# 检查Az模块
Write-Host "[2] Az PowerShell模块" -ForegroundColor Yellow
$azModule = Get-Module -ListAvailable -Name Az | Select-Object -First 1
if ($azModule) {
    Write-Host "  ✓ Az模块已安装" -ForegroundColor Green
    Write-Host "  版本: $($azModule.Version)" -ForegroundColor White
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
        $allPassed = $false
    }
}
catch {
    Write-Host "  ✗ 未登录" -ForegroundColor Red
    Write-Host "  请运行: Connect-AzAccount -UseDeviceAuthentication" -ForegroundColor Yellow
    $allPassed = $false
}
Write-Host ""

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
