using namespace System.Data.SQLite

class DRDatabaseManager {
    [string]$DatabasePath
    [SQLiteConnection]$Connection
    
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
        
        # 创建连接
        $this.Connection = [SQLiteConnection]::new("Data Source=$($this.DatabasePath);Version=3;")
        $this.Connection.Open()
        
        # 创建表结构
        $this.CreateTables()
    }
    
    [void] CreateTables() {
        $createTablesSql = @"
-- 订阅表
CREATE TABLE IF NOT EXISTS Subscriptions (
    Id TEXT PRIMARY KEY,
    Name TEXT,
    TenantId TEXT,
    Location TEXT,
    CollectedAt DATETIME,
    Version INTEGER
);

-- Recovery Services Vault 表
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

-- Replication Protected Items 表
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

-- 执行计划表
CREATE TABLE IF NOT EXISTS ExecutionPlans (
    Id TEXT PRIMARY KEY,
    PlanName TEXT,
    VmNames TEXT,
    GeneratedAt DATETIME,
    PlanData TEXT,
    Status TEXT,
    CreatedBy TEXT
);

-- 创建索引
CREATE INDEX IF NOT EXISTS idx_rpi_vmname ON ReplicationProtectedItems(VmName);
CREATE INDEX IF NOT EXISTS idx_rpi_health ON ReplicationProtectedItems(HealthStatus, ReplicationHealth);
CREATE INDEX IF NOT EXISTS idx_rpi_vault ON ReplicationProtectedItems(VaultId);
CREATE INDEX IF NOT EXISTS idx_rpi_subscription ON ReplicationProtectedItems(SubscriptionId);
"@
        
        $command = [SQLiteCommand]::new($createTablesSql, $this.Connection)
        $command.ExecuteNonQuery()
    }
    
    [void] InsertTestData() {
        # 清空现有数据
        $clearSql = "DELETE FROM ReplicationProtectedItems; DELETE FROM RecoveryServicesVaults; DELETE FROM Subscriptions;"
        $command = [SQLiteCommand]::new($clearSql, $this.Connection)
        $command.ExecuteNonQuery()
        
        # 插入测试订阅数据
        $subscriptionSql = @"
INSERT INTO Subscriptions (Id, Name, TenantId, Location, CollectedAt, Version) 
VALUES 
    ('sub-test-001', 'Test-Subscription-HK', 'tenant-001', 'eastasia', datetime('now'), 1),
    ('sub-test-002', 'Test-Subscription-SG', 'tenant-001', 'southeastasia', datetime('now'), 1);
"@
        
        $command = [SQLiteCommand]::new($subscriptionSql, $this.Connection)
        $command.ExecuteNonQuery()
        
        # 插入测试 Vault 数据
        $vaultSql = @"
INSERT INTO RecoveryServicesVaults (Id, Name, ResourceGroup, SubscriptionId, Location, CollectedAt, Version)
VALUES 
    ('/subscriptions/sub-test-001/resourceGroups/rg-asr-hk/providers/Microsoft.RecoveryServices/vaults/asr-vault-hk', 
     'asr-vault-hk', 'rg-asr-hk', 'sub-test-001', 'eastasia', datetime('now'), 1);
"@
        
        $command = [SQLiteCommand]::new($vaultSql, $this.Connection)
        $command.ExecuteNonQuery()
        
        # 插入测试 Replication Protected Items 数据
        $protectedItemsSql = @"
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
        
        $command = [SQLiteCommand]::new($protectedItemsSql, $this.Connection)
        $command.ExecuteNonQuery()
        
        Write-Host "测试数据插入完成！" -ForegroundColor Green
        Write-Host "已插入 2 个测试 VM:" -ForegroundColor Yellow
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
AND rpi.HealthStatus = 'Healthy'
"@
        
        $command = [SQLiteCommand]::new($query, $this.Connection)
        $reader = $command.ExecuteReader()
        
        $results = @()
        while ($reader.Read()) {
            $result = [PSCustomObject]@{
                Id = $reader["Id"]
                Name = $reader["Name"]
                VmName = $reader["VmName"]
                VaultId = $reader["VaultId"]
                SubscriptionId = $reader["SubscriptionId"]
                ResourceGroup = $reader["ResourceGroup"]
                SourceLocation = $reader["SourceLocation"]
                TargetLocation = $reader["TargetLocation"]
                HealthStatus = $reader["HealthStatus"]
                ReplicationHealth = $reader["ReplicationHealth"]
                VaultName = $reader["VaultName"]
                VaultResourceGroup = $reader["VaultResourceGroup"]
                SubscriptionName = $reader["SubscriptionName"]
                TenantId = $reader["TenantId"]
            }
            $results += $result
        }
        
        return $results
    }
    
    [void] Close() {
        if ($this.Connection -ne $null) {
            $this.Connection.Close()
        }
    }
}

# 使用示例
function Initialize-DRDatabase {
    param(
        [string]$DatabasePath = "state\dr-drill.db"
    )
    
    $dbManager = [DRDatabaseManager]::new($DatabasePath)
    $dbManager.InsertTestData()
    $dbManager.Close()
    
    Write-Host "数据库初始化完成: $DatabasePath" -ForegroundColor Green
}

# 测试查询功能
function Test-DatabaseQuery {
    param(
        [string]$DatabasePath = "state\dr-drill.db"
    )
    
    $dbManager = [DRDatabaseManager]::new($DatabasePath)
    $results = $dbManager.GetASRContextByVmNames(@("INFGAL01VMP", "UNF01VMP"))
    
    Write-Host "`n=== 查询结果 ===" -ForegroundColor Green
    foreach ($result in $results) {
        Write-Host "VM: $($result.VmName)" -ForegroundColor Yellow
        Write-Host "  订阅: $($result.SubscriptionName) ($($result.SubscriptionId))" -ForegroundColor Cyan
        Write-Host "  保管库: $($result.VaultName) ($($result.VaultResourceGroup))" -ForegroundColor Cyan
        Write-Host "  源区域: $($result.SourceLocation) -> 目标区域: $($result.TargetLocation)" -ForegroundColor Cyan
        Write-Host "  健康状态: $($result.HealthStatus) / $($result.ReplicationHealth)" -ForegroundColor Cyan
        Write-Host ""
    }
    
    $dbManager.Close()
}
