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

# System.Data.SQLite下载URL（预编译的DLL）
$dllUrl = "https://system.data.sqlite.org/blobs/1.0.118.0/sqlite-netFx46-setup-bundle-x64-1.0.118.0.exe"
$dllPath = "$libDir\System.Data.SQLite.dll"

Write-Host "`n[1] 下载System.Data.SQLite..." -ForegroundColor Yellow

# 尝试从多个源下载
$sources = @(
    "https://system.data.sqlite.org/blobs/1.0.118.0/sqlite-netFx46-setup-bundle-x64-1.0.118.0.exe",
    "https://www.nuget.org/api/v2/package/System.Data.SQLite/1.0.118.0"
)

$downloaded = $false
foreach ($source in $sources) {
    try {
        Write-Host "  尝试从: $source" -ForegroundColor Gray
        Invoke-WebRequest -Uri $source -OutFile "temp.zip" -ErrorAction Stop
        
        # 如果是.nupkg文件，解压
        if ($source -like "*.nupkg") {
            Write-Host "  解压.nupkg文件..." -ForegroundColor Gray
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory("temp.zip", "temp_extract")
            
            # 找到DLL文件
            $dllFile = Get-ChildItem "temp_extract\lib\net46\System.Data.SQLite.dll" -ErrorAction SilentlyContinue
            if ($dllFile) {
                Copy-Item $dllFile.FullName -Destination $dllPath -Force
                $downloaded = $true
                Write-Host "  ✓ DLL文件已复制到: $dllPath" -ForegroundColor Green
                break
            }
        }
        else {
            # 如果是.exe文件，需要提取DLL
            Write-Host "  从.exe文件中提取DLL..." -ForegroundColor Gray
            Write-Host "  注意: 需要手动安装.exe文件" -ForegroundColor Yellow
            Write-Host "  请访问: $source" -ForegroundColor Yellow
            Write-Host "  下载并安装，然后将System.Data.SQLite.dll复制到lib目录" -ForegroundColor Yellow
            break
        }
    }
    catch {
        Write-Host "  ✗ 下载失败: $_" -ForegroundColor Red
        continue
    }
}

# 清理临时文件
if (Test-Path "temp.zip") {
    Remove-Item "temp.zip" -Force
}
if (Test-Path "temp_extract") {
    Remove-Item "temp_extract" -Recurse -Force
}

if ($downloaded) {
    Write-Host "`n[2] 验证DLL..." -ForegroundColor Yellow
    try {
        Add-Type -Path $dllPath
        $null = [System.Data.SQLite.SQLiteConnection]
        Write-Host "  ✓ System.Data.SQLite已成功加载" -ForegroundColor Green
        
        # 获取版本信息
        $assembly = [System.Data.SQLite.SQLiteConnection].Assembly
        Write-Host "  版本: $($assembly.GetName().Version)" -ForegroundColor Cyan
        Write-Host "  位置: $dllPath" -ForegroundColor Cyan
        
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "安装成功！" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Cyan
    }
    catch {
        Write-Host "  ✗ DLL加载失败: $_" -ForegroundColor Red
        Write-Host "`n请手动下载System.Data.SQLite.dll并放到lib目录" -ForegroundColor Yellow
        Write-Host "下载地址: https://www.nuget.org/packages/System.Data.SQLite/" -ForegroundColor Cyan
    }
}
else {
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "自动下载失败" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "`n请手动安装:" -ForegroundColor Yellow
    Write-Host "1. 访问: https://www.nuget.org/packages/System.Data.SQLite/" -ForegroundColor Cyan
    Write-Host "2. 下载最新版本的.nupkg文件" -ForegroundColor Cyan
    Write-Host "3. 解压.nupkg文件（改为.zip后解压）" -ForegroundColor Cyan
    Write-Host "4. 将lib\net46\System.Data.SQLite.dll复制到lib目录" -ForegroundColor Cyan
    Write-Host "5. 重新运行此脚本验证" -ForegroundColor Cyan
}

Write-Host ""
