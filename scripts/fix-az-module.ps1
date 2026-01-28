# Az模块修复脚本
# 解决Az模块版本冲突和损坏问题

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Az模块修复工具" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 步骤1: 检查当前Az模块版本
Write-Host "[1] 检查当前Az模块版本..." -ForegroundColor Yellow
$azModules = Get-Module -ListAvailable -Name Az* | Sort-Object Name
if ($azModules) {
    Write-Host "  找到以下Az模块:" -ForegroundColor White
    foreach ($module in $azModules) {
        Write-Host "    - $($module.Name) (版本: $($module.Version))" -ForegroundColor White
    }
}
else {
    Write-Host "  未找到任何Az模块" -ForegroundColor Yellow
}
Write-Host ""

# 步骤2: 卸载所有Az模块
Write-Host "[2] 卸载所有Az模块..." -ForegroundColor Yellow
$allAzModules = Get-Module -ListAvailable -Name Az* | Select-Object -ExpandProperty Name | Sort-Object -Unique
$uninstalledCount = 0

foreach ($moduleName in $allAzModules) {
    try {
        Write-Host "  卸载: $moduleName" -ForegroundColor White
        Uninstall-Module -Name $moduleName -Force -ErrorAction SilentlyContinue
        $uninstalledCount++
    }
    catch {
        Write-Host "  卸载失败: $moduleName - $_" -ForegroundColor Red
    }
}

Write-Host "  已卸载 $uninstalledCount 个模块" -ForegroundColor Green
Write-Host ""

# 步骤3: 清除PowerShell模块缓存
Write-Host "[3] 清除PowerShell模块缓存..." -ForegroundColor Yellow
$modulePaths = @(
    "$env:USERPROFILE\Documents\WindowsPowerShell\Modules",
    "$env:USERPROFILE\Documents\PowerShell\Modules",
    "$env:ProgramFiles\WindowsPowerShell\Modules",
    "$env:ProgramFiles\PowerShell\Modules"
)

$clearedCount = 0
foreach ($path in $modulePaths) {
    if (Test-Path $path) {
        $azPaths = Get-ChildItem -Path $path -Filter "Az*" -Directory -ErrorAction SilentlyContinue
        foreach ($azPath in $azPaths) {
            try {
                Write-Host "  删除: $($azPath.FullName)" -ForegroundColor White
                Remove-Item -Path $azPath.FullName -Recurse -Force -ErrorAction SilentlyContinue
                $clearedCount++
            }
            catch {
                Write-Host "  删除失败: $($azPath.FullName) - $_" -ForegroundColor Red
            }
        }
    }
}

Write-Host "  已清除 $clearedCount 个缓存目录" -ForegroundColor Green
Write-Host ""

# 步骤4: 重新安装Az模块
Write-Host "[4] 重新安装Az模块..." -ForegroundColor Yellow
Write-Host "  这可能需要几分钟时间..." -ForegroundColor Gray
Write-Host ""

try {
    Install-Module -Name Az -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
    Write-Host "  Az模块安装成功" -ForegroundColor Green
}
catch {
    Write-Host "  Az模块安装失败: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "请尝试手动安装:" -ForegroundColor Yellow
    Write-Host "  Install-Module -Name Az -Scope CurrentUser -Force" -ForegroundColor White
    exit 1
}
Write-Host ""

# 步骤5: 验证安装
Write-Host "[5] 验证Az模块安装..." -ForegroundColor Yellow
$azModule = Get-Module -ListAvailable -Name Az | Select-Object -First 1
if ($azModule) {
    Write-Host "  Az模块已安装" -ForegroundColor Green
    Write-Host "  版本: $($azModule.Version)" -ForegroundColor White

    # 测试导入
    try {
        Import-Module -Name Az -Force -ErrorAction Stop
        Write-Host "  Az模块导入成功" -ForegroundColor Green
    }
    catch {
        Write-Host "  Az模块导入失败: $_" -ForegroundColor Red
        exit 1
    }
}
else {
    Write-Host "  Az模块未找到" -ForegroundColor Red
    exit 1
}
Write-Host ""

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Az模块修复完成！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "下一步操作:" -ForegroundColor Cyan
Write-Host "  1. 重新启动PowerShell" -ForegroundColor White
Write-Host "  2. 运行: Connect-AzAccount -UseDeviceAuthentication" -ForegroundColor White
Write-Host "  3. 运行: .\test\Test-RSV-Collector.ps1" -ForegroundColor White
Write-Host ""
