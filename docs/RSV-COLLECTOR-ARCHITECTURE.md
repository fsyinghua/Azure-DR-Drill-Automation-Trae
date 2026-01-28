# Azure RSV采集模块架构设计

## 一、设计目标

### 1.1 核心目标
- **可扩展性**: 支持未来采集多种类型的数据（指标、费用、配置等）
- **模块化**: 每种数据类型独立采集，互不影响
- **可配置**: 通过配置文件控制采集哪些数据
- **版本兼容**: 数据库schema支持平滑升级
- **性能优化**: 支持增量采集、并发采集、批量插入

### 1.2 设计原则
- **单一职责**: 每个采集器只负责一种类型的数据
- **开闭原则**: 对扩展开放，对修改关闭
- **依赖倒置**: 依赖抽象接口，不依赖具体实现
- **接口隔离**: 每个采集器只暴露必要的接口

---

## 二、架构设计

### 2.1 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                    Azure-RSV-Collector.psm1              │
│                   (采集模块主控制器)                      │
└──────────────────────┬──────────────────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
        ▼              ▼              ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ 采集器接口   │ │ 数据存储接口 │ │ 导出器接口   │
│ ICollector   │ │ IStorage     │ │ IExporter    │
└──────────────┘ └──────────────┘ └──────────────┘
        │              │              │
        ▼              ▼              ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ 具体采集器   │ │ SQLite存储   │ │ CSV导出器   │
│              │ │             │ │             │
│ - BackupVM   │ │ - 数据库管理 │ │ - CSV导出   │
│ - Replicated │ │ - 表管理     │ │ - Excel导出 │
│ - Metrics    │ │ - 增量采集   │ │             │
│ - Cost       │ │             │ │             │
└──────────────┘ └──────────────┘ └──────────────┘
```

### 2.2 核心组件

#### 2.2.1 采集器接口 (ICollector)

```powershell
interface ICollector {
    [string] GetName()
    [string] GetDataType()
    [hashtable] CollectData([hashtable]$config)
    [bool] ValidateData([hashtable]$data)
}
```

**实现类**:
- `BackupVMCollector` - Backup虚拟机采集器
- `ReplicatedItemCollector` - Replicated Items采集器
- `MetricsCollector` - 指标采集器（未来）
- `CostCollector` - 费用采集器（未来）
- `CustomCollector` - 自定义采集器（未来）

#### 2.2.2 数据存储接口 (IStorage)

```powershell
interface IStorage {
    [void] Initialize([string]$connectionString)
    [void] CreateTable([string]$tableName, [hashtable]$schema)
    [void] InsertOrUpdate([string]$tableName, [hashtable]$data)
    [hashtable[]] Query([string]$tableName, [hashtable]$filters)
    [void] Close()
}
```

**实现类**:
- `SQLiteStorage` - SQLite存储实现
- `SQLServerStorage` - SQL Server存储实现（未来）
- `PostgreSQLStorage` - PostgreSQL存储实现（未来）

#### 2.2.3 导出器接口 (IExporter)

```powershell
interface IExporter {
    [string] GetFormat()
    [void] Export([hashtable[]]$data, [string]$filePath, [hashtable]$options)
    [bool] ValidateData([hashtable[]]$data)
}
```

**实现类**:
- `CSVExporter` - CSV导出器
- `ExcelExporter` - Excel导出器
- `JSONExporter` - JSON导出器（未来）

---

## 三、数据模型设计

### 3.1 统一数据模型

所有采集的数据都遵循以下统一结构：

```powershell
@{
    # 元数据
    DataType = "BackupVM"           # 数据类型
    CollectorName = "BackupVMCollector"  # 采集器名称
    CollectionTime = "2026-01-28T10:00:00Z"  # 采集时间
    CollectionVersion = "1.0.0"     # 数据版本
    
    # 数据内容
    Data = @{
        # 具体数据字段
    }
    
    # 元数据扩展
    Metadata = @{
        Source = "Azure"
        Region = "eastus"
        SubscriptionId = "xxx-xxx-xxx"
        Tags = @{}
    }
}
```

### 3.2 数据类型定义

#### 3.2.1 BackupVM（当前实现）

```powershell
DataType = "BackupVM"

Data = @{
    RSVName = "rsv-primary"
    VMName = "vm-prod-001"
    VMId = "/subscriptions/.../vm-prod-001"
    ResourceGroup = "rg-prod"
    Location = "eastus"
    BackupStatus = "Healthy"
    LastBackupTime = "2026-01-28T08:00:00Z"
    NextBackupTime = "2026-01-29T08:00:00Z"
    BackupPolicy = "DailyBackup"
    BackupSizeGB = 100.5
    RecoveryPointsCount = 30
    IsProtected = $true
}
```

#### 3.2.2 ReplicatedItem（当前实现）

```powershell
DataType = "ReplicatedItem"

Data = @{
    RSVName = "rsv-primary"
    VMName = "vm-prod-001"
    VMId = "/subscriptions/.../vm-prod-001"
    
    # 源信息
    SourceResourceGroup = "rg-prod"
    SourceLocation = "eastus"
    SourceNetwork = "vnet-prod"
    SourceSubnet = "subnet-prod"
    
    # 目标信息
    TargetResourceGroup = "rg-dr"
    TargetLocation = "westus"
    TargetNetwork = "vnet-dr"
    TargetSubnet = "subnet-dr"
    TargetVMName = "vm-prod-001-dr"
    
    # ASR状态
    ASRStatus = "Enabled"
    FailoverState = "None"
    CommitState = "None"
    ReprotectState = "Completed"
    FallbackState = "None"
    
    # 操作指标
    Status = "Replicating"
    Health = "Normal"
    LastSuccessfulReplicationTime = "2026-01-28T09:30:00Z"
    RecoveryPoint = "2026-01-28T09:30:00Z"
    RPO = "PT5M"
    TestFailoverState = "None"
    ReplicationProgress = 95
    DataTransferRateMBps = 10.5
}
```

#### 3.2.3 Metrics（未来扩展）

```powershell
DataType = "Metrics"

Data = @{
    RSVName = "rsv-primary"
    VMName = "vm-prod-001"
    MetricName = "ReplicationHealth"
    MetricValue = 100
    Unit = "Percent"
    Timestamp = "2026-01-28T10:00:00Z"
    
    # 指标维度
    Dimensions = @{
        Direction = "PrimaryToSecondary"
        NetworkType = "ExpressRoute"
    }
}
```

#### 3.2.4 Cost（未来扩展）

```powershell
DataType = "Cost"

Data = @{
    RSVName = "rsv-primary"
    VMName = "vm-prod-001"
    CostType = "Storage"
    Amount = 50.25
    Currency = "USD"
    BillingPeriod = "2026-01"
    BillingDate = "2026-01-28"
    
    # 费用明细
    Details = @{
        StorageGB = 500
        StorageCost = 25.00
        ReplicationGB = 1000
        ReplicationCost = 25.25
    }
}
```

### 3.3 数据库表设计

#### 3.3.1 通用表结构

```sql
-- 采集记录表（所有数据类型共用）
CREATE TABLE collection_records (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    data_type TEXT NOT NULL,              -- 数据类型
    collector_name TEXT NOT NULL,          -- 采集器名称
    collection_time TEXT NOT NULL,        -- 采集时间
    collection_version TEXT NOT NULL,      -- 数据版本
    data_json TEXT NOT NULL,              -- 数据内容（JSON）
    metadata_json TEXT,                   -- 元数据（JSON）
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT DEFAULT CURRENT_TIMESTAMP
);

-- 索引
CREATE INDEX idx_data_type ON collection_records(data_type);
CREATE INDEX idx_collection_time ON collection_records(collection_time);
CREATE INDEX idx_collector_name ON collection_records(collector_name);
```

#### 3.3.2 专用表结构（可选，用于复杂查询）

```sql
-- Backup虚拟机专用表
CREATE TABLE backup_vms (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    rsv_name TEXT NOT NULL,
    vm_name TEXT NOT NULL,
    vm_id TEXT NOT NULL,
    resource_group TEXT NOT NULL,
    location TEXT NOT NULL,
    backup_status TEXT,
    last_backup_time TEXT,
    next_backup_time TEXT,
    backup_policy TEXT,
    backup_size_gb REAL,
    recovery_points_count INTEGER,
    is_protected BOOLEAN,
    collection_time TEXT NOT NULL,
    UNIQUE(vm_id, collection_time)
);

-- Replicated Items专用表
CREATE TABLE replicated_items (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    rsv_name TEXT NOT NULL,
    vm_name TEXT NOT NULL,
    vm_id TEXT NOT NULL,
    source_resource_group TEXT NOT NULL,
    source_location TEXT NOT NULL,
    source_network TEXT,
    source_subnet TEXT,
    target_resource_group TEXT NOT NULL,
    target_location TEXT NOT NULL,
    target_network TEXT,
    target_subnet TEXT,
    target_vm_name TEXT,
    asr_status TEXT,
    failover_state TEXT,
    commit_state TEXT,
    reprotect_state TEXT,
    fallback_state TEXT,
    status TEXT,
    health TEXT,
    last_successful_replication_time TEXT,
    recovery_point TEXT,
    rpo TEXT,
    test_failover_state TEXT,
    replication_progress INTEGER,
    data_transfer_rate_mbps REAL,
    collection_time TEXT NOT NULL,
    UNIQUE(vm_id, collection_time)
);
```

---

## 四、配置设计

### 4.1 采集配置文件（rsv-collector-config.txt）

```ini
# ========================================
# RSV采集配置
# ========================================

# 基础配置
SubscriptionId=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
ResourceGroupName=rg-dr-test
PrimaryRegion=eastus
SecondaryRegion=westus

# 数据存储配置
StorageType=SQLite
DatabasePath=.\data\rsv-data.db
EnableIncrementalCollection=true
CollectionInterval=60

# 导出配置
ExportFormat=CSV
ExportPath=.\exports\
EnableAutoExport=true
ExportOnCollection=true

# ========================================
# 采集器配置
# ========================================

# 启用的采集器（逗号分隔）
EnabledCollectors=BackupVM,ReplicatedItem

# BackupVM采集器配置
[BackupVM]
Enabled=true
Priority=1
MaxRetries=3
RetryInterval=10
Fields=VMName,BackupStatus,LastBackupTime,NextBackupTime,BackupPolicy,BackupSizeGB

# ReplicatedItem采集器配置
[ReplicatedItem]
Enabled=true
Priority=2
MaxRetries=3
RetryInterval=10
Fields=VMName,SourceResourceGroup,SourceNetwork,TargetResourceGroup,TargetNetwork,ASRStatus,Status,Health,LastSuccessfulReplicationTime

# Metrics采集器配置（未来）
[Metrics]
Enabled=false
Priority=3
MaxRetries=3
RetryInterval=10
MetricNames=ReplicationHealth,DataTransferRate,RPO

# Cost采集器配置（未来）
[Cost]
Enabled=false
Priority=4
MaxRetries=3
RetryInterval=10
CostTypes=Storage,Replication,Network

# ========================================
# 导出配置
# ========================================

# CSV导出配置
[CSV]
Delimiter=,
Encoding=UTF8
IncludeHeader=true
DateFormat=yyyy-MM-dd HH:mm:ss

# Excel导出配置
[Excel]
AutoSizeColumns=true
FreezeHeaderRow=true
EnableFilter=true
EnablePivotTable=false

# ========================================
# 增量采集配置
# ========================================

# 增量采集策略
IncrementalStrategy=Timestamp

# 时间戳字段名（用于增量检测）
TimestampFields=LastBackupTime,LastSuccessfulReplicationTime,CollectionTime

# 数据保留策略
DataRetentionDays=90
ArchiveOldData=false
ArchivePath=.\archive\

# ========================================
# 日志配置
# ========================================

LogPath=.\logs\rsv-collector.log
VerboseLogging=true
LogToConsole=true
LogToFile=true

# ========================================
# 性能配置
# ========================================

# 并发采集
EnableConcurrentCollection=true
MaxConcurrentCollectors=3

# 批量插入
EnableBatchInsert=true
BatchSize=100

# 缓存配置
EnableDataCache=true
CacheSizeMB=100
CacheTTLMinutes=30
```

### 4.2 采集器注册机制

```powershell
# 采集器注册表
$Global:CollectorRegistry = @{
    "BackupVM" = @{
        Type = "BackupVMCollector"
        Assembly = "Azure-RSV-Collector.psm1"
        Version = "1.0.0"
        Enabled = $true
        Priority = 1
        Config = @{}
    }
    "ReplicatedItem" = @{
        Type = "ReplicatedItemCollector"
        Assembly = "Azure-RSV-Collector.psm1"
        Version = "1.0.0"
        Enabled = $true
        Priority = 2
        Config = @{}
    }
    "Metrics" = @{
        Type = "MetricsCollector"
        Assembly = "Azure-Metrics-Collector.psm1"
        Version = "1.0.0"
        Enabled = $false
        Priority = 3
        Config = @{}
    }
    "Cost" = @{
        Type = "CostCollector"
        Assembly = "Azure-Cost-Collector.psm1"
        Version = "1.0.0"
        Enabled = $false
        Priority = 4
        Config = @{}
    }
}
```

---

## 五、实现示例

### 5.1 采集器接口实现

```powershell
# BackupVM采集器
class BackupVMCollector : ICollector {
    [string] GetName() {
        return "BackupVMCollector"
    }
    
    [string] GetDataType() {
        return "BackupVM"
    }
    
    [hashtable] CollectData([hashtable]$config) {
        $results = @()
        
        try {
            $rsvs = Get-RSVList -Config $config
            
            foreach ($rsv in $rsvs) {
                $backupVMs = Get-AzRecoveryServicesBackupItem -VaultId $rsv.ID
                
                foreach ($item in $backupVMs) {
                    $data = @{
                        DataType = "BackupVM"
                        CollectorName = $this.GetName()
                        CollectionTime = (Get-Date).ToUniversalTime().ToString("o")
                        CollectionVersion = "1.0.0"
                        
                        Data = @{
                            RSVName = $rsv.Name
                            VMName = $item.Name
                            VMId = $item.ID
                            ResourceGroup = $item.ResourceGroupName
                            Location = $item.Location
                            BackupStatus = $item.BackupStatus
                            LastBackupTime = $item.LastBackupTime
                            NextBackupTime = $item.NextBackupTime
                            BackupPolicy = $item.BackupPolicyName
                            BackupSizeGB = $item.BackupSizeGB
                            RecoveryPointsCount = $item.RecoveryPointsCount
                            IsProtected = $item.IsProtected
                        }
                        
                        Metadata = @{
                            Source = "Azure"
                            Region = $item.Location
                            SubscriptionId = $config.SubscriptionId
                            Tags = $item.Tags
                        }
                    }
                    
                    $results += $data
                }
            }
        }
        catch {
            Write-Error "采集BackupVM数据失败: $_"
        }
        
        return $results
    }
    
    [bool] ValidateData([hashtable]$data) {
        # 验证数据完整性
        return $true
    }
}
```

### 5.2 主控制器实现

```powershell
function Invoke-RSVCollection {
    param(
        [hashtable]$Config
    )
    
    # 初始化存储
    $storage = [SQLiteStorage]::new()
    $storage.Initialize($Config.DatabasePath)
    
    # 获取启用的采集器
    $enabledCollectors = Get-EnabledCollectors -Config $Config
    
    # 按优先级排序
    $enabledCollectors = $enabledCollectors | Sort-Object Priority
    
    # 执行采集
    foreach ($collectorInfo in $enabledCollectors) {
        $collector = New-Object -TypeName $collectorInfo.Type
        
        Write-Host "开始采集: $($collector.GetName())" -ForegroundColor Cyan
        
        $data = $collector.CollectData($Config)
        
        if ($data) {
            # 存储数据
            foreach ($item in $data) {
                $storage.InsertOrUpdate("collection_records", $item)
            }
            
            Write-Host "采集完成: $($collector.GetName()) - $($data.Count) 条记录" -ForegroundColor Green
        }
    }
    
    # 关闭存储
    $storage.Close()
    
    # 导出数据
    if ($Config.EnableAutoExport) {
        Export-RSVData -Config $Config -Storage $storage
    }
}
```

---

## 六、扩展指南

### 6.1 添加新的采集器

#### 步骤1: 实现ICollector接口

```powershell
class MyCustomCollector : ICollector {
    [string] GetName() {
        return "MyCustomCollector"
    }
    
    [string] GetDataType() {
        return "MyCustomData"
    }
    
    [hashtable] CollectData([hashtable]$config) {
        # 实现采集逻辑
        $results = @()
        
        # ... 采集代码 ...
        
        return $results
    }
    
    [bool] ValidateData([hashtable]$data) {
        # 实现验证逻辑
        return $true
    }
}
```

#### 步骤2: 注册采集器

```powershell
# 在采集器注册表中添加
$Global:CollectorRegistry["MyCustomData"] = @{
    Type = "MyCustomCollector"
    Assembly = "MyCustomCollector.psm1"
    Version = "1.0.0"
    Enabled = $true
    Priority = 5
    Config = @{}
}
```

#### 步骤3: 更新配置文件

```ini
# 在rsv-collector-config.txt中添加
EnabledCollectors=BackupVM,ReplicatedItem,MyCustomData

[MyCustomData]
Enabled=true
Priority=5
MaxRetries=3
RetryInterval=10
```

### 6.2 添加新的存储类型

实现IStorage接口：

```powershell
class SQLServerStorage : IStorage {
    [void] Initialize([string]$connectionString) {
        # 实现初始化逻辑
    }
    
    [void] CreateTable([string]$tableName, [hashtable]$schema) {
        # 实现表创建逻辑
    }
    
    [void] InsertOrUpdate([string]$tableName, [hashtable]$data) {
        # 实现插入或更新逻辑
    }
    
    [hashtable[]] Query([string]$tableName, [hashtable]$filters) {
        # 实现查询逻辑
    }
    
    [void] Close() {
        # 实现关闭逻辑
    }
}
```

### 6.3 添加新的导出格式

实现IExporter接口：

```powershell
class JSONExporter : IExporter {
    [string] GetFormat() {
        return "JSON"
    }
    
    [void] Export([hashtable[]]$data, [string]$filePath, [hashtable]$options) {
        # 实现JSON导出逻辑
        $json = $data | ConvertTo-Json -Depth 10
        $json | Out-File -FilePath $filePath -Encoding UTF8
    }
    
    [bool] ValidateData([hashtable[]]$data) {
        # 实现验证逻辑
        return $true
    }
}
```

---

## 七、版本兼容性

### 7.1 数据版本管理

每个数据记录都包含版本信息：

```powershell
@{
    CollectionVersion = "1.0.0"
    Data = @{ ... }
}
```

### 7.2 Schema升级策略

```powershell
function Update-Schema {
    param(
        [string]$currentVersion,
        [string]$targetVersion
    )
    
    $upgraders = @{
        "1.0.0->1.1.0" = {
            param($data)
            # 升级逻辑
            $data.Data.NewField = "DefaultValue"
            return $data
        }
        "1.1.0->1.2.0" = {
            param($data)
            # 升级逻辑
            return $data
        }
    }
    
    # 应用升级
    foreach ($upgrade in $upgraders.Keys) {
        if ($upgrade -like "$currentVersion*") {
            $data = & $upgraders[$upgrade] $data
        }
    }
    
    return $data
}
```

---

## 八、性能优化

### 8.1 增量采集

```powershell
function Get-IncrementalData {
    param(
        [string]$dataType,
        [datetime]$lastCollectionTime
    )
    
    # 只采集变化的数据
    $newData = Get-AzureData -Since $lastCollectionTime
    
    return $newData
}
```

### 8.2 并发采集

```powershell
function Invoke-ConcurrentCollection {
    param(
        [array]$collectors,
        [hashtable]$config
    )
    
    $jobs = @()
    
    foreach ($collector in $collectors) {
        $job = Start-Job -ScriptBlock {
            param($collectorType, $config)
            $collector = New-Object -TypeName $collectorType
            return $collector.CollectData($config)
        } -ArgumentList $collector.Type, $config
        
        $jobs += $job
    }
    
    # 等待所有作业完成
    $results = $jobs | Wait-Job | Receive-Job
    
    # 清理作业
    $jobs | Remove-Job
    
    return $results
}
```

### 8.3 批量插入

```powershell
function Insert-Batch {
    param(
        [object]$storage,
        [string]$tableName,
        [array]$data,
        [int]$batchSize = 100
    )
    
    for ($i = 0; $i -lt $data.Count; $i += $batchSize) {
        $batch = $data[$i..($i + $batchSize - 1)]
        $storage.InsertBatch($tableName, $batch)
    }
}
```

---

## 九、总结

### 9.1 架构优势

1. **可扩展性**: 通过接口和注册机制，轻松添加新的采集器、存储类型和导出格式
2. **模块化**: 每个组件独立开发和测试，降低耦合度
3. **可配置**: 通过配置文件控制采集行为，无需修改代码
4. **版本兼容**: 支持数据版本管理和schema升级
5. **性能优化**: 支持增量采集、并发采集、批量插入

### 9.2 未来扩展方向

1. **更多数据类型**: 指标、费用、日志、审计等
2. **更多存储类型**: SQL Server、PostgreSQL、MongoDB等
3. **更多导出格式**: JSON、XML、Parquet等
4. **高级功能**: 数据分析、告警、报表等
5. **云原生**: 支持Azure Functions、容器化部署

---

**文档版本**: 1.0.0  
**创建日期**: 2026-01-28  
**作者**: Azure DR Team
