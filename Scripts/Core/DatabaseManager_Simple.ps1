# 简化的数据库管理器 - 使用 PowerShell 原生方式
class DRDatabaseManager {
    [string]$DatabasePath
    
    DRDatabaseManager([string]$dbPath) {
        $this.DatabasePath = $dbPath
        $this.InitializeDatabase()
    }
    
    [void] InitializeDatabase() {
        # 确保目录存在
        $dbDir = Split-Path $this.DatabasePath -Parent
        if (-not (Test-Path $dbDir)) {
            New-Item -ItemType Directory -Path $dbDir -Force | Out-Null
        }
        
        # 创建表结构
        $this.CreateTables()
    }
    
    [void] CreateTables() {
        $createTablesSql = @"
CREATE TABLE IF NOT EXISTS Subscriptions (
    Id TEXT PRIMARY KEY,
    Name TEXT,
    TenantId TEXT,
    Location TEXT,
    CollectedAt DATETIME,
    Version INTEGER
);

CREATE TABLE IF NOT EXISTS RecoveryServicesVaults (
    Id TEXT PRIMARY KEY,
    Name TEXT,
    ResourceGroup TEXT,
    SubscriptionId TEXT,
    Location TEXT,
    CollectedAt DATETIME,
    Version INTEGER,
    FOREIGN KEY (SubscriptionId) REFERENCES Subscriptions(Id)
);

CREATE TABLE IF NOT EXISTS ReplicationProtectedItems (
    Id TEXT PRIMARY KEY,
    Name TEXT,
    VmName TEXT,
    VaultId TEXT,
    SubscriptionId TEXT,
    ResourceGroup TEXT,
    SourceLocation TEXT,
    TargetLocation TEXT,
    PolicyId TEXT,
    HealthStatus TEXT,
    ReplicationHealth TEXT,
    CollectedAt DATETIME,
    Version INTEGER,
    FOREIGN KEY (VaultId) REFERENCES RecoveryServicesVaults(Id),
    FOREIGN KEY (SubscriptionId) REFERENCES Subscriptions(Id)
);

CREATE TABLE IF NOT EXISTS ExecutionPlans (
    Id TEXT PRIMARY KEY,
    PlanName TEXT,
    VmNames TEXT,
    GeneratedAt DATETIME,
    PlanData TEXT,
    Status TEXT,
    CreatedBy TEXT
);

CREATE INDEX IF NOT EXISTS idx_rpi_vmname ON ReplicationProtectedItems(VmName);
CREATE INDEX IF NOT EXISTS idx_rpi_health ON ReplicationProtectedItems(HealthStatus, ReplicationHealth);
"@
        
        # 使用 sqlite3 命令行工具创建表
        $createTablesSql | Out-File -FilePath "temp_create_tables.sql" -Encoding UTF8
        & sqlite3 $this.DatabasePath < temp_create_tables.sql
        Remove-Item "temp_create_tables.sql" -Force -ErrorAction SilentlyContinue
    }
    
    [void] InsertTestData() {
        # 清空现有数据
        & sqlite3 $this.DatabasePath "DELETE FROM ReplicationProtectedItems; DELETE FROM RecoveryServicesVaults; DELETE FROM Subscriptions;"
        
        # 插入测试订阅数据
        & sqlite3 $this.DatabasePath @"
INSERT INTO Subscriptions (Id, Name, TenantId, Location, CollectedAt, Version) 
VALUES 
    ('sub-test-001', 'Test-Subscription-HK', 'tenant-001', 'eastasia', datetime('now'), 1),
    ('sub-test-002', 'Test-Subscription-SG', 'tenant-001', 'southeastasia', datetime('now'), 1);
"@
        
        # 插入测试 Vault 数据
        & sqlite3 $this.DatabasePath @"
INSERT INTO RecoveryServicesVaults (Id, Name, ResourceGroup, SubscriptionId, Location, CollectedAt, Version)
VALUES 
    ('/subscriptions/sub-test-001/resourceGroups/rg-asr-hk/providers/Microsoft.RecoveryServices/vaults/asr-vault-hk', 
     'asr-vault-hk', 'rg-asr-hk', 'sub-test-001', 'eastasia', datetime('now'), 1);
"@
        
        # 插入测试 Replication Protected Items 数据
        & sqlite3 $this.DatabasePath @"
INSERT INTO ReplicationProtectedItems (
    Id, Name, VmName, VaultId, SubscriptionId, ResourceGroup, 
    SourceLocation, TargetLocation, PolicyId, HealthStatus, ReplicationHealth, 
    CollectedAt, Version
) VALUES 
    ('/subscriptions/sub-test-001/resourceGroups/rg-asr-hk/providers/Microsoft.RecoveryServices/vaults/asr-vault-hk/replicationProtectedItems/infgal01vmp',
     'infgal01vmp', 'INFGAL01VMP', 
     '/subscriptions/sub-test-001/resourceGroups/rg-asr-hk/providers/Microsoft.RecoveryServices/vaults/asr-vault-hk',
     'sub-test-001', 'rg-asr-hk',
     'eastasia', 'southeastasia', 
     '/subscriptions/sub-test-001/resourceGroups/rg-asr-hk/providers/Microsoft.RecoveryServices/vaults/asr-vault-hk/replicationPolicies/daily-policy',
     'Healthy', 'Normal', datetime('now'), 1),
     
    ('/subscriptions/sub-test-001/resourceGroups/rg-asr-hk/providers/Microsoft.RecoveryServices/vaults/asr-vault-hk/replicationProtectedItems/unf01vmp',
     'unf01vmp', 'UNF01VMP', 
     '/subscriptions/sub-test-001/resourceGroups/rg-asr-hk/providers/Microsoft.RecoveryServices/vaults/asr-vault-hk',
     'sub-test-001', 'rg-asr-hk',
     'eastasia', 'southeastasia', 
     '/subscriptions/sub-test-001/resourceGroups/rg-asr-hk/providers/Microsoft.RecoveryServices/vaults/asr-vault-hk/replicationPolicies/daily-policy',
     'Healthy', 'Normal', datetime('now'), 1);
"@
        
        Write-Host "Test data inserted successfully!" -ForegroundColor Green
        Write-Host "Inserted 2 test VMs:" -ForegroundColor Yellow
        Write-Host "  - INFGAL01VMP (GIT - NETsec GALsync)" -ForegroundColor Cyan
        Write-Host "  - UNF01VMP (GIT - uniFLOW Management Console)" -ForegroundColor Cyan
    }
    
    [object[]] GetASRContextByVmNames([string[]]$vmNames) {
        $vmList = "'" + ($vmNames -join "','") + "'"
        $query = @"
SELECT 
    rpi.Id, rpi.Name, rpi.VmName, rpi.VaultId, rpi.SubscriptionId, rpi.ResourceGroup,
    rpi.SourceLocation, rpi.TargetLocation, rpi.HealthStatus, rpi.ReplicationHealth,
    rv.Name as VaultName, rv.ResourceGroup as VaultResourceGroup,
    s.Name as SubscriptionName, s.TenantId
FROM ReplicationProtectedItems rpi
JOIN RecoveryServicesVaults rv ON rpi.VaultId = rv.Id
JOIN Subscriptions s ON rpi.SubscriptionId = s.Id
WHERE rpi.VmName IN ($vmList)
AND rpi.HealthStatus = 'Healthy';
"@
        
        # 执行查询并解析结果
        $result = & sqlite3 $this.DatabasePath $query
        $lines = $result -split "`n"
        $results = @()
        
        # 跳过表头
        if ($lines.Count -gt 0) {
            $headers = $lines[0] -split '\|'
            for ($i = 1; $i -lt $lines.Count; $i++) {
                if ([string]::IsNullOrWhiteSpace($lines[$i])) { continue }
                
                $values = $lines[$i] -split '\|'
                if ($values.Count -eq $headers.Count) {
                    $resultObj = [PSCustomObject]@{}
                    for ($j = 0; $j -lt $headers.Count; $j++) {
                        $resultObj | Add-Member -NotePropertyName $headers[$j].Trim() -NotePropertyValue $values[$j].Trim()
                    }
                    $results += $resultObj
                }
            }
        }
        
        return $results
    }
}

# 使用示例
function Initialize-DRDatabase {
    param(
        [string]$DatabasePath = "state\dr-drill.db"
    )
    
    $dbManager = [DRDatabaseManager]::new($DatabasePath)
    $dbManager.InsertTestData()
    
    Write-Host "Database initialized: $DatabasePath" -ForegroundColor Green
}

# 测试查询功能
function Test-DatabaseQuery {
    param(
        [string]$DatabasePath = "state\dr-drill.db"
    )
    
    $dbManager = [DRDatabaseManager]::new($DatabasePath)
    $results = $dbManager.GetASRContextByVmNames(@("INFGAL01VMP", "UNF01VMP"))
    
    Write-Host "`n=== Query Results ===" -ForegroundColor Green
    foreach ($result in $results) {
        Write-Host "VM: $($result.VmName)" -ForegroundColor Yellow
        Write-Host "  Subscription: $($result.SubscriptionName) ($($result.SubscriptionId))" -ForegroundColor Cyan
        Write-Host "  Vault: $($result.VaultName) ($($result.VaultResourceGroup))" -ForegroundColor Cyan
        Write-Host "  Source: $($result.SourceLocation) -> Target: $($result.TargetLocation)" -ForegroundColor Cyan
        Write-Host "  Health: $($result.HealthStatus) / $($result.ReplicationHealth)" -ForegroundColor Cyan
        Write-Host ""
    }
}
