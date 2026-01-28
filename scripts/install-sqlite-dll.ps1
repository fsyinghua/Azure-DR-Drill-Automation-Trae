# 安装System.Data.SQLite DLL

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "System.Data.SQLite 安装脚本" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# 创建lib目录
$libDir = ".\lib"
if (-not (Test-Path $libDir)) {
    New-Item -ItemType Directory -Path $libDir -Force | Out-Null
    Write-Host "创建lib目录: $libDir" -ForegroundColor Green
}

$dllPath = "$libDir\System.Data.SQLite.dll"

Write-Host "`n[1] 下载System.Data.SQLite..." -ForegroundColor Yellow

# NuGet包URL
$nugetUrl = "https://www.nuget.org/api/v2/package/System.Data.SQLite/1.0.118.0"
$tempFile = "System.Data.SQLite.1.0.118.0.nupkg"

try {
    Write-Host "  从NuGet下载: $nugetUrl" -ForegroundColor Gray
    Invoke-WebRequest -Uri $nugetUrl -OutFile $tempFile -ErrorAction Stop
    Write-Host "  ✓ 下载完成" -ForegroundColor Green

    Write-Host "`n[2] 解压.nupkg文件..." -ForegroundColor Yellow

    # 加载压缩程序集
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    # 解压.nupkg文件
    $extractPath = "temp_extract"
    if (Test-Path $extractPath) {
        Remove-Item $extractPath -Recurse -Force
    }
    [System.IO.Compression.ZipFile]::ExtractToDirectory($tempFile, $extractPath)
    Write-Host "  ✓ 解压完成" -ForegroundColor Green

    # 查找DLL文件
    Write-Host "`n[3] 查找DLL文件..." -ForegroundColor Yellow

    # 显示解压后的目录结构
    Write-Host "  解压后的目录结构:" -ForegroundColor Gray
    Get-ChildItem $extractPath -Recurse -Directory | Select-Object -First 10 | ForEach-Object {
        $relativePath = $_.FullName.Replace($extractPath + "\", "")
        Write-Host "    $relativePath" -ForegroundColor DarkGray
    }

    # 尝试多个可能的DLL路径
    $possiblePaths = @(
        "$extractPath\lib\net46\System.Data.SQLite.dll",
        "$extractPath\lib\netstandard2.0\System.Data.SQLite.dll",
        "$extractPath\lib\net6.0\System.Data.SQLite.dll",
        "$extractPath\lib\net20\System.Data.SQLite.dll",
        "$extractPath\lib\net40\System.Data.SQLite.dll"
    )

    $dllFile = $null
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            $dllFile = Get-Item $path
            Write-Host "  ✓ 找到DLL: $path" -ForegroundColor Green
            break
        }
    }

    # 如果没找到，尝试递归搜索
    if (-not $dllFile) {
        Write-Host "  递归搜索DLL文件..." -ForegroundColor Gray
        $dllFile = Get-ChildItem $extractPath -Recurse -Filter "System.Data.SQLite.dll" | Select-Object -First 1
    }

    if ($dllFile) {
        Write-Host "  ✓ 找到DLL: $($dllFile.FullName)" -ForegroundColor Green

        Write-Host "`n[4] 复制DLL到lib目录..." -ForegroundColor Yellow
        Copy-Item $dllFile.FullName -Destination $dllPath -Force
        Write-Host "  ✓ DLL已复制到: $dllPath" -ForegroundColor Green

        # 清理临时文件
        Write-Host "`n[5] 清理临时文件..." -ForegroundColor Yellow
        Remove-Item $tempFile -Force
        Remove-Item $extractPath -Recurse -Force
        Write-Host "  ✓ 清理完成" -ForegroundColor Green

        # 验证DLL
        Write-Host "`n[6] 验证DLL..." -ForegroundColor Yellow
        try {
            Add-Type -Path $dllPath -ErrorAction Stop
            $null = [System.Data.SQLite.SQLiteConnection]
            Write-Host "  ✓ System.Data.SQLite已成功加载" -ForegroundColor Green

            # 获取版本信息
            $assembly = [System.Data.SQLite.SQLiteConnection].Assembly
            Write-Host "`n========================================" -ForegroundColor Cyan
            Write-Host "安装成功！" -ForegroundColor Green
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host "版本: $($assembly.GetName().Version)" -ForegroundColor White
            Write-Host "位置: $dllPath" -ForegroundColor White
        }
        catch {
            Write-Host "  ✗ DLL加载失败: $_" -ForegroundColor Red
            Write-Host "`n请手动下载System.Data.SQLite.dll并放到lib目录" -ForegroundColor Yellow
            Write-Host "下载地址: https://www.nuget.org/packages/System.Data.SQLite/" -ForegroundColor Cyan
        }
    }
    else {
        Write-Host "  ✗ 未找到System.Data.SQLite.dll" -ForegroundColor Red
        Write-Host "`n请手动安装:" -ForegroundColor Yellow
        Write-Host "1. 访问: https://www.nuget.org/packages/System.Data.SQLite/" -ForegroundColor Cyan
        Write-Host "2. 下载最新版本的.nupkg文件" -ForegroundColor Cyan
        Write-Host "3. 解压.nupkg文件（改为.zip后解压）" -ForegroundColor Cyan
        Write-Host "4. 将System.Data.SQLite.dll复制到lib目录" -ForegroundColor Cyan
    }
}
catch {
    Write-Host "  ✗ 下载失败: $_" -ForegroundColor Red

    # 清理临时文件
    if (Test-Path $tempFile) {
        Remove-Item $tempFile -Force
    }
    if (Test-Path "temp_extract") {
        Remove-Item "temp_extract" -Recurse -Force
    }

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "自动下载失败" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "`n请手动安装:" -ForegroundColor Yellow
    Write-Host "1. 访问: https://www.nuget.org/packages/System.Data.SQLite/" -ForegroundColor Cyan
    Write-Host "2. 下载最新版本的.nupkg文件" -ForegroundColor Cyan
    Write-Host "3. 解压.nupkg文件（改为.zip后解压）" -ForegroundColor Cyan
    Write-Host "4. 将System.Data.SQLite.dll复制到lib目录" -ForegroundColor Cyan
    Write-Host "5. 重新运行此脚本验证" -ForegroundColor Cyan
}

Write-Host ""
