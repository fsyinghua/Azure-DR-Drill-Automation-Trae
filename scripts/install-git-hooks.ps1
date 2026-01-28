# Git Hooks 安装脚本
# 用于在克隆项目后自动设置 Git pre-commit hook

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "安装Git Hooks" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 获取脚本目录
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent $scriptDir
$hooksDir = Join-Path $rootDir ".git\hooks"
$sourceHook = Join-Path $scriptDir "pre-commit-hook.ps1"

# 检查.git目录是否存在
if (-not (Test-Path (Join-Path $rootDir ".git"))) {
    Write-Host "错误: 未找到.git目录，请确保在Git仓库根目录运行此脚本" -ForegroundColor Red
    exit 1
}

# 创建hooks目录（如果不存在）
if (-not (Test-Path $hooksDir)) {
    New-Item -ItemType Directory -Path $hooksDir -Force | Out-Null
    Write-Host "创建hooks目录: $hooksDir" -ForegroundColor Green
}

# 创建pre-commit hook
$preCommitHook = Join-Path $hooksDir "pre-commit"
$hookContent = @'
# Git pre-commit hook
# 在每次提交前自动运行代码检查

$ErrorActionPreference = "Stop"

# 获取脚本目录
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent $scriptDir

# 切换到项目根目录
Set-Location $rootDir

# 运行预提交检查脚本
$checkScript = Join-Path $rootDir "scripts\pre-commit-check.ps1"

if (Test-Path $checkScript) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "运行Pre-commit检查..." -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""

    $result = & $checkScript

    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Red
        Write-Host "Pre-commit检查失败！" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        Write-Host ""
        Write-Host "请修复上述错误后再提交代码。" -ForegroundColor Yellow
        Write-Host "如果确实要跳过检查，使用: git commit --no-verify" -ForegroundColor Gray
        Write-Host ""
        exit 1
    }
    else {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "Pre-commit检查通过！" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        exit 0
    }
}
else {
    Write-Host "警告: 未找到pre-commit-check.ps1脚本" -ForegroundColor Yellow
    exit 0
}
'@

# 写入hook文件
$hookContent | Out-File -FilePath $preCommitHook -Encoding UTF8 -Force

# 在Windows上，PowerShell脚本需要正确的扩展名和shebang
# Git会自动识别.ps1文件
$preCommitHookPs1 = $preCommitHook + ".ps1"
$hookContent | Out-File -FilePath $preCommitHookPs1 -Encoding UTF8 -Force

# 创建无扩展名的wrapper脚本（用于Git调用）
$wrapperContent = @'
#!/usr/bin/env pwsh
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "$PSScriptRoot\pre-commit.ps1"
'@
$wrapperContent | Out-File -FilePath $preCommitHook -Encoding UTF8 -Force

Write-Host "安装pre-commit hook: $preCommitHook" -ForegroundColor Green
Write-Host ""

# 验证hook是否安装成功
if (Test-Path $preCommitHook) {
    Write-Host "✓ Git pre-commit hook安装成功！" -ForegroundColor Green
    Write-Host ""
    Write-Host "现在每次提交代码前都会自动运行代码检查。" -ForegroundColor Cyan
    Write-Host "如果需要跳过检查，使用: git commit --no-verify" -ForegroundColor Yellow
    Write-Host ""
}
else {
    Write-Host "✗ Git pre-commit hook安装失败" -ForegroundColor Red
    exit 1
}

# 测试hook
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "测试Git Hook" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "运行一次代码检查测试..." -ForegroundColor Yellow
Write-Host ""

$checkScript = Join-Path $rootDir "scripts\pre-commit-check.ps1"
& $checkScript

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "安装完成" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
