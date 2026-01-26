# 测试数据库管理器
param(
    [string]$DatabasePath = "state\dr-drill.json"
)

# 导入数据管理器
. "$PSScriptRoot\..\Core\DataManager.ps1"

Write-Host "=== Azure DR Automation Script - Database Initialization Test ===" -ForegroundColor Green
Write-Host ""

try {
    # 初始化数据库并插入测试数据
    Write-Host "1. Initializing database..." -ForegroundColor Yellow
    Initialize-DRDatabase -DatabasePath $DatabasePath
    
    # 测试查询功能
    Write-Host "2. Testing query functionality..." -ForegroundColor Yellow
    Test-DatabaseQuery -DatabasePath $DatabasePath
    
    Write-Host "3. Database test completed!" -ForegroundColor Green
    Write-Host "Now ready to develop failover script based on this test data." -ForegroundColor Cyan
    
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack: $($_.ScriptStackTrace)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Next step: Develop failover script based on database queries" -ForegroundColor Yellow
