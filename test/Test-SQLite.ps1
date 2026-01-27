<#
.SYNOPSIS
    SQLite使用示例脚本

.DESCRIPTION
    演示如何在PowerShell中使用SQLite数据库

.NOTES
    Version: 1.0.0
    Author: Azure DR Team
    Date: 2026-01-27
#>

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "SQLite使用示例" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 步骤1: 检查SQLite模块
Write-Host "步骤 1: 检查SQLite模块..." -ForegroundColor Yellow

$useDll = $false
$useModule = $false

# 检查System.Data.SQLite模块
$sqliteModule = Get-Module -ListAvailable -Name System.Data.SQLite -ErrorAction SilentlyContinue
if ($sqliteModule) {
    Write-Host "  System.Data.SQLite模块已安装: $($sqliteModule.Version)" -ForegroundColor Green
    $useModule = $true
}

# 检查DLL文件
$dllPath = ".\lib\System.Data.SQLite.dll"
if (Test-Path $dllPath) {
    Write-Host "  找到SQLite DLL: $dllPath" -ForegroundColor Green
    $useDll = $true
}

if (-not $useModule -and -not $useDll) {
    Write-Host "  未找到SQLite模块或DLL" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  请选择安装方式:" -ForegroundColor Cyan
    Write-Host "  1. 下载System.Data.SQLite.dll" -ForegroundColor White
    Write-Host "  2. 安装System.Data.SQLite NuGet包" -ForegroundColor White
    Write-Host "  3. 跳过SQLite功能" -ForegroundColor White
    Write-Host ""
    $choice = Read-Host "  请选择 (1/2/3)"
    
    switch ($choice) {
        "1" {
            Write-Host ""
            Write-Host "  请按以下步骤操作:" -ForegroundColor Yellow
            Write-Host "  1. 访问: https://system.data.sqlite.org/" -ForegroundColor White
            Write-Host "  2. 下载System.Data.SQLite.dll" -ForegroundColor White
            Write-Host "  3. 创建目录: .\lib\" -ForegroundColor White
            Write-Host "  4. 复制DLL到: .\lib\System.Data.SQLite.dll" -ForegroundColor White
            exit 0
        }
        "2" {
            Write-Host ""
            Write-Host "  正在安装System.Data.SQLite NuGet包..." -ForegroundColor Cyan
            try {
                Install-Package -Name System.Data.SQLite -Scope CurrentUser -Force
                Write-Host "  安装完成" -ForegroundColor Green
                $useModule = $true
            }
            catch {
                Write-Host "  安装失败: $_" -ForegroundColor Red
                Write-Host "  请确保已安装NuGet" -ForegroundColor Yellow
                exit 1
            }
        }
        "3" {
            Write-Host ""
            Write-Host "  将跳过SQLite功能" -ForegroundColor Yellow
            $skipSqlite = $true
        }
        default {
            Write-Host "  无效的选择" -ForegroundColor Red
            exit 1
        }
    }
}

# 步骤2: 初始化SQLite
if (-not $skipSqlite) {
    Write-Host ""
    Write-Host "步骤 2: 初始化SQLite..." -ForegroundColor Yellow
    
    try {
        if ($useDll) {
            # 加载DLL
            Add-Type -Path $dllPath
            Write-Host "  已加载SQLite DLL" -ForegroundColor Green
        }
        elseif ($useModule) {
            # 导入模块
            Import-Module System.Data.SQLite
            Write-Host "  已导入SQLite模块" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  初始化SQLite失败: $_" -ForegroundColor Red
        exit 1
    }
    
    # 步骤3: 创建数据库
    Write-Host ""
    Write-Host "步骤 3: 创建数据库..." -ForegroundColor Yellow
    
    $dbPath = ".\test-dr-results.db"
    $dbExists = Test-Path $dbPath
    
    if ($dbExists) {
        Write-Host "  数据库已存在: $dbPath" -ForegroundColor Yellow
        $overwrite = Read-Host "  是否覆盖? (Y/N)"
        if ($overwrite -ne "Y" -and $overwrite -ne "y") {
            Write-Host "  使用现有数据库" -ForegroundColor Green
        }
        else {
            Remove-Item -Path $dbPath -Force
            Write-Host "  已删除旧数据库" -ForegroundColor Green
        }
    }
    
    # 步骤4: 创建表
    Write-Host ""
    Write-Host "步骤 4: 创建表..." -ForegroundColor Yellow
    
    try {
        $connectionString = "Data Source=$dbPath;Version=3;"
        
        if ($useDll) {
            # 使用DLL方式
            $connection = New-Object System.Data.SQLite.SQLiteConnection($connectionString)
            $connection.Open()
            
            $command = $connection.CreateCommand()
            $command.CommandText = @"
                CREATE TABLE IF NOT EXISTS dr_results (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    vm_name TEXT NOT NULL,
                    operation TEXT NOT NULL,
                    status TEXT NOT NULL,
                    start_time TEXT,
                    end_time TEXT,
                    duration_seconds INTEGER,
                    error_message TEXT,
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP
                );
            "@
            $command.ExecuteNonQuery()
            
            $command.CommandText = @"
                CREATE TABLE IF NOT EXISTS subscriptions (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    subscription_id TEXT NOT NULL,
                    subscription_name TEXT NOT NULL,
                    tenant_id TEXT NOT NULL,
                    is_current INTEGER DEFAULT 0,
                    created_at TEXT DEFAULT CURRENT_TIMESTAMP
                );
            "@
            $command.ExecuteNonQuery()
            
            $connection.Close()
            Write-Host "  表创建成功" -ForegroundColor Green
        }
        elseif ($useModule) {
            # 使用模块方式
            Write-Host "  注意: 模块方式需要根据实际模块API调整" -ForegroundColor Yellow
            Write-Host "  示例代码仅作参考" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "  创建表失败: $_" -ForegroundColor Red
        exit 1
    }
    
    # 步骤5: 插入测试数据
    Write-Host ""
    Write-Host "步骤 5: 插入测试数据..." -ForegroundColor Yellow
    
    try {
        if ($useDll) {
            $connection = New-Object System.Data.SQLite.SQLiteConnection($connectionString)
            $connection.Open()
            
            # 插入DR结果
            $command = $connection.CreateCommand()
            $command.CommandText = @"
                INSERT INTO dr_results (vm_name, operation, status, start_time, end_time, duration_seconds)
                VALUES (@vm_name, @operation, @status, @start_time, @end_time, @duration_seconds);
            "@
            
            $command.Parameters.AddWithValue("@vm_name", "test-vm-001") | Out-Null
            $command.Parameters.AddWithValue("@operation", "Failover") | Out-Null
            $command.Parameters.AddWithValue("@status", "Success") | Out-Null
            $command.Parameters.AddWithValue("@start_time", "2026-01-27 10:00:00") | Out-Null
            $command.Parameters.AddWithValue("@end_time", "2026-01-27 10:05:00") | Out-Null
            $command.Parameters.AddWithValue("@duration_seconds", 300) | Out-Null
            
            $command.ExecuteNonQuery()
            
            # 插入订阅信息
            $command.CommandText = @"
                INSERT INTO subscriptions (subscription_id, subscription_name, tenant_id, is_current)
                VALUES (@subscription_id, @subscription_name, @tenant_id, @is_current);
            "@
            
            $command.Parameters.Clear()
            $command.Parameters.AddWithValue("@subscription_id", "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx") | Out-Null
            $command.Parameters.AddWithValue("@subscription_name", "Test Subscription") | Out-Null
            $command.Parameters.AddWithValue("@tenant_id", "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy") | Out-Null
            $command.Parameters.AddWithValue("@is_current", 1) | Out-Null
            
            $command.ExecuteNonQuery()
            
            $connection.Close()
            Write-Host "  测试数据插入成功" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  插入数据失败: $_" -ForegroundColor Red
        exit 1
    }
    
    # 步骤6: 查询数据
    Write-Host ""
    Write-Host "步骤 6: 查询数据..." -ForegroundColor Yellow
    
    try {
        if ($useDll) {
            $connection = New-Object System.Data.SQLite.SQLiteConnection($connectionString)
            $connection.Open()
            
            # 查询DR结果
            $command = $connection.CreateCommand()
            $command.CommandText = "SELECT * FROM dr_results;"
            
            $reader = $command.ExecuteReader()
            
            Write-Host ""
            Write-Host "DR结果:" -ForegroundColor Cyan
            Write-Host "----------------------------------------" -ForegroundColor Cyan
            
            while ($reader.Read()) {
                Write-Host "  ID: $($reader['id'])" -ForegroundColor White
                Write-Host "  VM: $($reader['vm_name'])" -ForegroundColor White
                Write-Host "  操作: $($reader['operation'])" -ForegroundColor White
                Write-Host "  状态: $($reader['status'])" -ForegroundColor White
                Write-Host "  开始时间: $($reader['start_time'])" -ForegroundColor Gray
                Write-Host "  结束时间: $($reader['end_time'])" -ForegroundColor Gray
                Write-Host "  耗时: $($reader['duration_seconds'])秒" -ForegroundColor Gray
                Write-Host "----------------------------------------" -ForegroundColor Cyan
            }
            
            $reader.Close()
            
            # 查询订阅信息
            $command.CommandText = "SELECT * FROM subscriptions;"
            $reader = $command.ExecuteReader()
            
            Write-Host ""
            Write-Host "订阅信息:" -ForegroundColor Cyan
            Write-Host "----------------------------------------" -ForegroundColor Cyan
            
            while ($reader.Read()) {
                $isCurrent = if ($reader['is_current'] -eq 1) { " [当前]" } else { "" }
                Write-Host "  ID: $($reader['id'])" -ForegroundColor White
                Write-Host "  订阅ID: $($reader['subscription_id'])" -ForegroundColor White
                Write-Host "  订阅名称: $($reader['subscription_name'])$isCurrent" -ForegroundColor White
                Write-Host "  租户ID: $($reader['tenant_id'])" -ForegroundColor White
                Write-Host "----------------------------------------" -ForegroundColor Cyan
            }
            
            $reader.Close()
            $connection.Close()
        }
    }
    catch {
        Write-Host "  查询数据失败: $_" -ForegroundColor Red
        exit 1
    }
    
    # 步骤7: 统计信息
    Write-Host ""
    Write-Host "步骤 7: 统计信息..." -ForegroundColor Yellow
    
    try {
        if ($useDll) {
            $connection = New-Object System.Data.SQLite.SQLiteConnection($connectionString)
            $connection.Open()
            
            # 统计DR结果数量
            $command = $connection.CreateCommand()
            $command.CommandText = "SELECT COUNT(*) FROM dr_results;"
            $count = $command.ExecuteScalar()
            
            Write-Host "  DR结果总数: $count" -ForegroundColor Green
            
            # 统计订阅数量
            $command.CommandText = "SELECT COUNT(*) FROM subscriptions;"
            $subCount = $command.ExecuteScalar()
            
            Write-Host "  订阅总数: $subCount" -ForegroundColor Green
            
            # 统计操作类型
            $command.CommandText = "SELECT operation, COUNT(*) as count FROM dr_results GROUP BY operation;"
            $reader = $command.ExecuteReader()
            
            Write-Host ""
            Write-Host "操作统计:" -ForegroundColor Cyan
            Write-Host "----------------------------------------" -ForegroundColor Cyan
            
            while ($reader.Read()) {
                Write-Host "  $($reader['operation']): $($reader['count'])" -ForegroundColor White
            }
            
            $reader.Close()
            $connection.Close()
        }
    }
    catch {
        Write-Host "  统计失败: $_" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "SQLite测试完成!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

if (Test-Path $dbPath) {
    Write-Host "数据库文件: $dbPath" -ForegroundColor Cyan
    Write-Host "文件大小: $((Get-Item $dbPath).Length / 1KB) KB" -ForegroundColor Gray
}

Write-Host ""
Write-Host "下一步:" -ForegroundColor Cyan
Write-Host "  1. 查看数据库: SQLite Studio或DB Browser for SQLite" -ForegroundColor White
Write-Host "  2. 集成到DR演练脚本" -ForegroundColor White
Write-Host ""