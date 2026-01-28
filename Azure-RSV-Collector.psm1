<#
.SYNOPSIS
    Azure RSV配置采集模块 - 提供Recovery Services Vault配置和状态采集功能

.DESCRIPTION
    此模块提供RSV Backup虚拟机和Replicated Items的采集、存储和导出功能，
    支持增量采集、SQLite数据库存储、CSV/Excel导出

.NOTES
    Version: 1.0.0
    Author: Azure DR Team
    Date: 2026-01-28
#>

# ========================================
# 全局变量
# ========================================

$Script:RSVCollectorVersion = "1.0.0"
$Script:DatabaseConnection = $null
$Script:DatabasePath = $null

# ========================================
# 辅助函数
# ========================================

function Write-RSVLog {
    <#
    .SYNOPSIS
        写入RSV采集日志
    
    .DESCRIPTION
        写入带时间戳的日志信息到文件和控制台
    
    .PARAMETER Message
        日志消息内容
    
    .PARAMETER Level
        日志级别（INFO, WARNING, ERROR）
    
    .EXAMPLE
        Write-RSVLog -Message "开始采集数据" -Level "INFO"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("INFO", "WARNING", "ERROR")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    $color = switch ($Level) {
        "INFO" { "White" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        default { "White" }
    }
    
    Write-Host $logMessage -ForegroundColor $color
    
    if ($Script:LogPath) {
        $logMessage | Out-File -FilePath $Script:LogPath -Append -Encoding UTF8
    }
}

function Test-SQLiteModule {
    <#
    .SYNOPSIS
        检查SQLite模块是否可用
    
    .DESCRIPTION
        检查系统是否安装了System.Data.SQLite
    
    .EXAMPLE
        $result = Test-SQLiteModule
    #>
    try {
        $null = [System.Reflection.Assembly]::LoadWithPartialName("System.Data.SQLite")
        return $true
    }
    catch {
        Write-RSVLog "System.Data.SQLite不可用: $_" -Level "WARNING"
        return $false
    }
}

# ========================================
# 数据库管理函数
# ========================================

function Initialize-RSVDatabase {
    <#
    .SYNOPSIS
        初始化RSV采集数据库
    
    .DESCRIPTION
        创建SQLite数据库和必要的表结构
    
    .PARAMETER DatabasePath
        数据库文件路径
    
    .PARAMETER Force
        强制重新创建数据库
    
    .EXAMPLE
        Initialize-RSVDatabase -DatabasePath ".\data\rsv-data.db"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$DatabasePath,
        
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )
    
    try {
        Write-RSVLog "初始化数据库: $DatabasePath" -Level "INFO"
        
        # 确保目录存在
        $dbDir = Split-Path -Path $DatabasePath -Parent
        if (-not (Test-Path $dbDir)) {
            New-Item -ItemType Directory -Path $dbDir -Force | Out-Null
            Write-RSVLog "创建数据库目录: $dbDir" -Level "INFO"
        }
        
        # 检查SQLite模块
        if (-not (Test-SQLiteModule)) {
            throw "System.Data.SQLite不可用"
        }
        
        # 如果强制重新创建，删除现有数据库
        if ($Force -and (Test-Path $DatabasePath)) {
            Remove-Item -Path $DatabasePath -Force
            Write-RSVLog "删除现有数据库" -Level "INFO"
        }
        
        # 创建数据库连接
        $connectionString = "Data Source=$DatabasePath;Version=3;"
        $Script:DatabaseConnection = New-Object System.Data.SQLite.SQLiteConnection($connectionString)
        $Script:DatabaseConnection.Open()
        $Script:DatabasePath = $DatabasePath
        
        # 创建通用采集记录表
        $createCollectionRecordsTable = @"
        CREATE TABLE IF NOT EXISTS collection_records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            data_type TEXT NOT NULL,
            collector_name TEXT NOT NULL,
            collection_time TEXT NOT NULL,
            collection_version TEXT NOT NULL,
            data_json TEXT NOT NULL,
            metadata_json TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP,
            updated_at TEXT DEFAULT CURRENT_TIMESTAMP
        )
"@
        
        $command = $Script:DatabaseConnection.CreateCommand()
        $command.CommandText = $createCollectionRecordsTable
        $command.ExecuteNonQuery()
        Write-RSVLog "创建collection_records表" -Level "INFO"
        
        # 创建索引
        $createIndexes = @(
            "CREATE INDEX IF NOT EXISTS idx_data_type ON collection_records(data_type);",
            "CREATE INDEX IF NOT EXISTS idx_collection_time ON collection_records(collection_time);",
            "CREATE INDEX IF NOT EXISTS idx_collector_name ON collection_records(collector_name);"
        )
        
        foreach ($indexQuery in $createIndexes) {
            $command.CommandText = $indexQuery
            $command.ExecuteNonQuery()
        }
        
        Write-RSVLog "创建索引" -Level "INFO"
        
        # 创建Backup虚拟机专用表
        $createBackupVMsTable = @"
        CREATE TABLE IF NOT EXISTS backup_vms (
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
        )
"@
        
        $command.CommandText = $createBackupVMsTable
        $command.ExecuteNonQuery()
        Write-RSVLog "创建backup_vms表" -Level "INFO"
        
        # 创建Replicated Items专用表
        $createReplicatedItemsTable = @"
        CREATE TABLE IF NOT EXISTS replicated_items (
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
        )
"@
        
        $command.CommandText = $createReplicatedItemsTable
        $command.ExecuteNonQuery()
        Write-RSVLog "创建replicated_items表" -Level "INFO"
        
        Write-RSVLog "数据库初始化完成" -Level "INFO"
        
        return $true
    }
    catch {
        Write-RSVLog "数据库初始化失败: $_" -Level "ERROR"
        return $false
    }
}

function Close-RSVDatabase {
    <#
    .SYNOPSIS
        关闭数据库连接
    
    .DESCRIPTION
        关闭SQLite数据库连接
    
    .EXAMPLE
        Close-RSVDatabase
    #>
    try {
        if ($Script:DatabaseConnection) {
            $Script:DatabaseConnection.Close()
            $Script:DatabaseConnection = $null
            Write-RSVLog "数据库连接已关闭" -Level "INFO"
        }
    }
    catch {
        Write-RSVLog "关闭数据库连接失败: $_" -Level "ERROR"
    }
}

function Get-LastCollectionTime {
    <#
    .SYNOPSIS
        获取最后一次采集时间
    
    .DESCRIPTION
        从数据库中获取指定数据类型的最后一次采集时间
    
    .PARAMETER DataType
        数据类型（BackupVM, ReplicatedItem）
    
    .EXAMPLE
        $lastTime = Get-LastCollectionTime -DataType "BackupVM"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("BackupVM", "ReplicatedItem")]
        [string]$DataType
    )
    
    try {
        $query = "SELECT MAX(collection_time) as last_time FROM collection_records WHERE data_type = '$DataType'"
        $command = $Script:DatabaseConnection.CreateCommand()
        $command.CommandText = $query
        $reader = $command.ExecuteReader()
        
        if ($reader.Read()) {
            $lastTime = $reader["last_time"]
            $reader.Close()
            
            if ($lastTime) {
                return [DateTime]::Parse($lastTime)
            }
        }
        
        return $null
    }
    catch {
        Write-RSVLog "获取最后采集时间失败: $_" -Level "ERROR"
        return $null
    }
}

# ========================================
# 数据采集函数
# ========================================

function Get-RSVBackupVMs {
    <#
    .SYNOPSIS
        采集RSV中的Backup虚拟机信息
    
    .DESCRIPTION
        从指定的Recovery Services Vault中获取所有Backup虚拟机的配置和状态信息
    
    .PARAMETER RSVName
        RSV名称
    
    .PARAMETER ResourceGroupName
        资源组名称
    
    .EXAMPLE
        $backupVMs = Get-RSVBackupVMs -RSVName "rsv-primary" -ResourceGroupName "rg-dr-test"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$RSVName,
        
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName
    )
    
    try {
        Write-RSVLog "开始采集Backup虚拟机: $RSVName" -Level "INFO"
        
        # 获取RSV
        $rsv = Get-AzRecoveryServicesVault -Name $RSVName -ResourceGroupName $ResourceGroupName -ErrorAction Stop
        
        if (-not $rsv) {
            Write-RSVLog "未找到RSV: $RSVName" -Level "ERROR"
            return @()
        }
        
        # 获取Backup容器
        $containers = Get-AzRecoveryServicesBackupContainer -VaultId $rsv.ID -ContainerType "AzureVM" -ErrorAction SilentlyContinue
        
        if (-not $containers) {
            Write-RSVLog "未找到Backup容器" -Level "WARNING"
            return @()
        }
        
        $backupVMs = @()
        
        foreach ($container in $containers) {
            # 获取Backup项
            $items = Get-AzRecoveryServicesBackupItem -Container $container -VaultId $rsv.ID -ErrorAction SilentlyContinue
            
            foreach ($item in $items) {
                # 只处理虚拟机
                if ($item.WorkloadType -eq "AzureVM") {
                    $backupVM = @{
                        DataType = "BackupVM"
                        CollectorName = "BackupVMCollector"
                        CollectionTime = (Get-Date).ToUniversalTime().ToString("o")
                        CollectionVersion = $Script:RSVCollectorVersion
                        
                        Data = @{
                            RSVName = $RSVName
                            VMName = $item.Name
                            VMId = $item.ID
                            ResourceGroup = $item.ResourceGroupName
                            Location = $item.Location
                            BackupStatus = $item.BackupStatus
                            LastBackupTime = if ($item.LastBackupTime) { $item.LastBackupTime.ToString("o") } else { $null }
                            NextBackupTime = if ($item.NextBackupTime) { $item.NextBackupTime.ToString("o") } else { $null }
                            BackupPolicy = $item.BackupPolicyName
                            BackupSizeGB = $item.BackupSizeGB
                            RecoveryPointsCount = $item.RecoveryPointsCount
                            IsProtected = $item.IsProtected
                        }
                        
                        Metadata = @{
                            Source = "Azure"
                            Region = $item.Location
                            SubscriptionId = (Get-AzContext).Subscription.Id
                            Tags = $item.Tags
                        }
                    }
                    
                    $backupVMs += $backupVM
                    Write-RSVLog "  采集Backup VM: $($item.Name)" -Level "INFO"
                }
            }
        }
        
        Write-RSVLog "完成采集Backup虚拟机: $($backupVMs.Count) 台" -Level "INFO"
        
        return $backupVMs
    }
    catch {
        Write-RSVLog "采集Backup虚拟机失败: $_" -Level "ERROR"
        return @()
    }
}

function Get-RSVReplicatedItems {
    <#
    .SYNOPSIS
        采集RSV中的Replicated Items信息
    
    .DESCRIPTION
        从指定的Recovery Services Vault中获取所有Replicated Items的配置和状态信息
    
    .PARAMETER RSVName
        RSV名称
    
    .PARAMETER ResourceGroupName
        资源组名称
    
    .EXAMPLE
        $replicatedItems = Get-RSVReplicatedItems -RSVName "rsv-primary" -ResourceGroupName "rg-dr-test"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$RSVName,
        
        [Parameter(Mandatory = $true)]
        [string]$ResourceGroupName
    )
    
    try {
        Write-RSVLog "开始采集Replicated Items: $RSVName" -Level "INFO"
        
        # 获取RSV
        $rsv = Get-AzRecoveryServicesVault -Name $RSVName -ResourceGroupName $ResourceGroupName -ErrorAction Stop
        
        if (-not $rsv) {
            Write-RSVLog "未找到RSV: $RSVName" -Level "ERROR"
            return @()
        }
        
        # 获取Fabric
        $fabrics = Get-AzRecoveryServicesFabric -VaultId $rsv.ID -ErrorAction SilentlyContinue
        
        if (-not $fabrics) {
            Write-RSVLog "未找到Fabric" -Level "WARNING"
            return @()
        }
        
        $replicatedItems = @()
        
        foreach ($fabric in $fabrics) {
            # 获取保护容器
            $containers = Get-AzRecoveryServicesProtectionContainer -Fabric $fabric -VaultId $rsv.ID -ErrorAction SilentlyContinue
            
            foreach ($container in $containers) {
                # 获取Replicated Items
                $items = Get-AzRecoveryServicesReplicationProtectedItem -ProtectionContainer $container -ErrorAction SilentlyContinue
                
                foreach ($item in $items) {
                    $replicatedItem = @{
                        DataType = "ReplicatedItem"
                        CollectorName = "ReplicatedItemCollector"
                        CollectionTime = (Get-Date).ToUniversalTime().ToString("o")
                        CollectionVersion = $Script:RSVCollectorVersion
                        
                        Data = @{
                            RSVName = $RSVName
                            VMName = $item.Name
                            VMId = $item.ID
                            SourceResourceGroup = $item.SourceResourceGroupName
                            SourceLocation = $item.SourceLocation
                            SourceNetwork = $item.SourceNetwork
                            SourceSubnet = $item.SourceSubnet
                            TargetResourceGroup = $item.TargetResourceGroupName
                            TargetLocation = $item.TargetLocation
                            TargetNetwork = $item.TargetNetwork
                            TargetSubnet = $item.TargetSubnet
                            TargetVMName = $item.TargetVMName
                            ASRStatus = $item.ASRStatus
                            FailoverState = $item.FailoverState
                            CommitState = $item.CommitState
                            ReprotectState = $item.ReprotectState
                            FallbackState = $item.FallbackState
                            Status = $item.Status
                            Health = $item.Health
                            LastSuccessfulReplicationTime = if ($item.LastSuccessfulReplicationTime) { $item.LastSuccessfulReplicationTime.ToString("o") } else { $null }
                            RecoveryPoint = if ($item.RecoveryPoint) { $item.RecoveryPoint.ToString("o") } else { $null }
                            RPO = $item.RPO
                            TestFailoverState = $item.TestFailoverState
                            ReplicationProgress = $item.ReplicationProgress
                            DataTransferRateMBps = $item.DataTransferRateMBps
                        }
                        
                        Metadata = @{
                            Source = "Azure"
                            Region = $item.SourceLocation
                            SubscriptionId = (Get-AzContext).Subscription.Id
                            Tags = $item.Tags
                        }
                    }
                    
                    $replicatedItems += $replicatedItem
                    Write-RSVLog "  采集Replicated Item: $($item.Name)" -Level "INFO"
                }
            }
        }
        
        Write-RSVLog "完成采集Replicated Items: $($replicatedItems.Count) 个" -Level "INFO"
        
        return $replicatedItems
    }
    catch {
        Write-RSVLog "采集Replicated Items失败: $_" -Level "ERROR"
        return @()
    }
}

# ========================================
# 数据存储函数
# ========================================

function Insert-RSVData {
    <#
    .SYNOPSIS
        插入或更新RSV数据到数据库
    
    .DESCRIPTION
        将采集的数据插入到SQLite数据库，支持增量更新
    
    .PARAMETER Data
        要插入的数据数组
    
    .PARAMETER EnableIncremental
        是否启用增量采集
    
    .EXAMPLE
        Insert-RSVData -Data $backupVMs -EnableIncremental $true
    #>
    param(
        [Parameter(Mandatory = $true)]
        [array]$Data,
        
        [Parameter(Mandatory = $false)]
        [bool]$EnableIncremental = $true
    )
    
    try {
        if (-not $Data -or $Data.Count -eq 0) {
            Write-RSVLog "没有数据需要插入" -Level "WARNING"
            return 0
        }
        
        Write-RSVLog "开始插入数据: $($Data.Count) 条记录" -Level "INFO"
        
        $insertedCount = 0
        $updatedCount = 0
        
        foreach ($item in $Data) {
            $dataType = $item.DataType
            $dataJson = $item.Data | ConvertTo-Json -Depth 10 -Compress
            $metadataJson = if ($item.Metadata) { $item.Metadata | ConvertTo-Json -Depth 10 -Compress } else { $null }
            
            # 检查是否已存在
            $checkQuery = "SELECT id FROM collection_records WHERE data_type = '$dataType' AND collection_time = '$($item.CollectionTime)'"
            $command = $Script:DatabaseConnection.CreateCommand()
            $command.CommandText = $checkQuery
            $reader = $command.ExecuteReader()
            $existing = $reader.Read()
            $reader.Close()
            
            if ($existing) {
                # 更新现有记录
                $updateQuery = @"
                UPDATE collection_records 
                SET collector_name = '$($item.CollectorName)',
                    collection_version = '$($item.CollectionVersion)',
                    data_json = '$dataJson',
                    metadata_json = '$metadataJson',
                    updated_at = CURRENT_TIMESTAMP
                WHERE data_type = '$dataType' AND collection_time = '$($item.CollectionTime)'
"@
                
                $command.CommandText = $updateQuery
                $command.ExecuteNonQuery()
                $updatedCount++
            }
            else {
                # 插入新记录
                $insertQuery = @"
                INSERT INTO collection_records 
                (data_type, collector_name, collection_time, collection_version, data_json, metadata_json)
                VALUES 
                ('$dataType', '$($item.CollectorName)', '$($item.CollectionTime)', '$($item.CollectionVersion)', '$dataJson', '$metadataJson')
"@
                
                $command.CommandText = $insertQuery
                $command.ExecuteNonQuery()
                $insertedCount++
            }
        }
        
        Write-RSVLog "数据插入完成: 新增 $insertedCount 条，更新 $updatedCount 条" -Level "INFO"
        
        return $insertedCount + $updatedCount
    }
    catch {
        Write-RSVLog "插入数据失败: $_" -Level "ERROR"
        return 0
    }
}

# ========================================
# 导出函数
# ========================================

function Export-RSVDataToCSV {
    <#
    .SYNOPSIS
        导出RSV数据到CSV文件
    
    .DESCRIPTION
        从数据库中查询数据并导出到CSV文件
    
    .PARAMETER DataType
        数据类型（BackupVM, ReplicatedItem, All）
    
    .PARAMETER FilePath
        输出文件路径
    
    .PARAMETER Filters
        筛选条件（hashtable）
    
    .EXAMPLE
        Export-RSVDataToCSV -DataType "BackupVM" -FilePath ".\exports\backup-vms.csv"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("BackupVM", "ReplicatedItem", "All")]
        [string]$DataType,
        
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Filters = @{}
    )
    
    try {
        Write-RSVLog "开始导出数据到CSV: $FilePath" -Level "INFO"
        
        # 确保目录存在
        $exportDir = Split-Path -Path $FilePath -Parent
        if (-not (Test-Path $exportDir)) {
            New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
        }
        
        # 构建查询
        $whereClause = ""
        if ($DataType -ne "All") {
            $whereClause = "WHERE data_type = '$DataType'"
        }
        
        # 添加筛选条件
        foreach ($key in $Filters.Keys) {
            $value = $Filters[$key]
            if ($whereClause) {
                $whereClause += " AND "
            }
            else {
                $whereClause = "WHERE "
            }
            $whereClause += "data_json LIKE '%$key%$value%'"
        }
        
        $query = "SELECT data_json FROM collection_records $whereClause ORDER BY collection_time DESC"
        $command = $Script:DatabaseConnection.CreateCommand()
        $command.CommandText = $query
        $reader = $command.ExecuteReader()
        
        $results = @()
        while ($reader.Read()) {
            $results += [PSCustomObject]@{
                data_json = $reader["data_json"]
            }
        }
        $reader.Close()
        
        if (-not $results -or $results.Count -eq 0) {
            Write-RSVLog "没有数据可导出" -Level "WARNING"
            return $false
        }
        
        # 解析JSON数据
        $exportData = @()
        foreach ($result in $results) {
            $data = $result.data_json | ConvertFrom-Json
            $exportData += $data.Data
        }
        
        # 导出到CSV
        $exportData | Export-Csv -Path $FilePath -NoTypeInformation -Encoding UTF8
        
        Write-RSVLog "导出完成: $($exportData.Count) 条记录到 $FilePath" -Level "INFO"
        
        return $true
    }
    catch {
        Write-RSVLog "导出到CSV失败: $_" -Level "ERROR"
        return $false
    }
}

function Export-RSVDataToExcel {
    <#
    .SYNOPSIS
        导出RSV数据到Excel文件
    
    .DESCRIPTION
        从数据库中查询数据并导出到Excel文件（需要ImportExcel模块）
    
    .PARAMETER DataType
        数据类型（BackupVM, ReplicatedItem, All）
    
    .PARAMETER FilePath
        输出文件路径
    
    .PARAMETER Filters
        筛选条件（hashtable）
    
    .EXAMPLE
        Export-RSVDataToExcel -DataType "BackupVM" -FilePath ".\exports\backup-vms.xlsx"
    #>
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("BackupVM", "ReplicatedItem", "All")]
        [string]$DataType,
        
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$Filters = @{}
    )
    
    try {
        Write-RSVLog "开始导出数据到Excel: $FilePath" -Level "INFO"
        
        # 检查ImportExcel模块
        $importExcelModule = Get-Module -Name ImportExcel -ListAvailable -ErrorAction SilentlyContinue
        if (-not $importExcelModule) {
            Write-RSVLog "ImportExcel模块未安装，尝试安装..." -Level "WARNING"
            Install-Module -Name ImportExcel -Scope CurrentUser -Force -ErrorAction Stop
        }
        
        # 确保目录存在
        $exportDir = Split-Path -Path $FilePath -Parent
        if (-not (Test-Path $exportDir)) {
            New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
        }
        
        # 构建查询
        $whereClause = ""
        if ($DataType -ne "All") {
            $whereClause = "WHERE data_type = '$DataType'"
        }
        
        # 添加筛选条件
        foreach ($key in $Filters.Keys) {
            $value = $Filters[$key]
            if ($whereClause) {
                $whereClause += " AND "
            }
            else {
                $whereClause = "WHERE "
            }
            $whereClause += "data_json LIKE '%$key%$value%'"
        }
        
        $query = "SELECT data_json FROM collection_records $whereClause ORDER BY collection_time DESC"
        $results = Invoke-SqliteQuery -SQLiteConnection $Script:DatabaseConnection -Query $query
        
        if (-not $results -or $results.Count -eq 0) {
            Write-RSVLog "没有数据可导出" -Level "WARNING"
            return $false
        }
        
        # 解析JSON数据
        $exportData = @()
        foreach ($result in $results) {
            $data = $result.data_json | ConvertFrom-Json
            $exportData += $data.Data
        }
        
        # 导出到Excel
        $exportData | Export-Excel -Path $FilePath -AutoSize -AutoFilter -FreezeTopRow
        
        Write-RSVLog "导出完成: $($exportData.Count) 条记录到 $FilePath" -Level "INFO"
        
        return $true
    }
    catch {
        Write-RSVLog "导出到Excel失败: $_" -Level "ERROR"
        return $false
    }
}

# ========================================
# 查询和摘要函数
# ========================================

function Get-RSVData {
    <#
    .SYNOPSIS
        从数据库查询RSV数据
    
    .DESCRIPTION
        从SQLite数据库中查询RSV配置数据
    
    .PARAMETER DataType
        数据类型（BackupVM, ReplicatedItem, All）
    
    .PARAMETER Filter
        筛选条件（SQL WHERE子句）
    
    .PARAMETER OrderBy
        排序字段
    
    .EXAMPLE
        $data = Get-RSVData -DataType "BackupVM" -OrderBy "collection_time DESC"
    #>
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet("BackupVM", "ReplicatedItem", "All")]
        [string]$DataType = "All",
        
        [Parameter(Mandatory = $false)]
        [string]$Filter = "",
        
        [Parameter(Mandatory = $false)]
        [string]$OrderBy = "collection_time DESC"
    )
    
    try {
        $whereClause = ""
        if ($DataType -ne "All") {
            $whereClause = "WHERE data_type = '$DataType'"
        }
        
        if ($Filter) {
            if ($whereClause) {
                $whereClause += " AND "
            }
            else {
                $whereClause = "WHERE "
            }
            $whereClause += $Filter
        }
        
        $query = "SELECT data_json FROM collection_records $whereClause ORDER BY $OrderBy"
        $command = $Script:DatabaseConnection.CreateCommand()
        $command.CommandText = $query
        $reader = $command.ExecuteReader()
        
        $results = @()
        while ($reader.Read()) {
            $data = $reader["data_json"] | ConvertFrom-Json
            $results += $data.Data
        }
        $reader.Close()
        
        return $results
    }
    catch {
        Write-RSVLog "查询数据失败: $_" -Level "ERROR"
        return @()
    }
}

function Get-RSVDataSummary {
    <#
    .SYNOPSIS
        获取RSV数据采集摘要
    
    .DESCRIPTION
        统计数据库中的数据采集情况
    
    .EXAMPLE
        $summary = Get-RSVDataSummary
    #>
    try {
        Write-RSVLog "获取数据摘要" -Level "INFO"
        
        # 统计各类型数据数量
        $summary = @{}
        
        $dataTypes = @("BackupVM", "ReplicatedItem")
        foreach ($type in $dataTypes) {
            $query = "SELECT COUNT(*) as count, MIN(collection_time) as first_time, MAX(collection_time) as last_time FROM collection_records WHERE data_type = '$type'"
            $command = $Script:DatabaseConnection.CreateCommand()
            $command.CommandText = $query
            $reader = $command.ExecuteReader()
            
            if ($reader.Read()) {
                $summary[$type] = @{
                    Count = $reader["count"]
                    FirstCollectionTime = if ($reader["first_time"]) { [DateTime]::Parse($reader["first_time"]) } else { $null }
                    LastCollectionTime = if ($reader["last_time"]) { [DateTime]::Parse($reader["last_time"]) } else { $null }
                }
                $reader.Close()
            }
        }
        
        # 输出摘要
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "RSV数据采集摘要" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        
        foreach ($type in $dataTypes) {
            $data = $summary[$type]
            Write-Host "数据类型: $type" -ForegroundColor White
            Write-Host "  记录数量: $($data.Count)" -ForegroundColor White
            if ($data.FirstCollectionTime) {
                Write-Host "  首次采集: $($data.FirstCollectionTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
            }
            if ($data.LastCollectionTime) {
                Write-Host "  最后采集: $($data.LastCollectionTime.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor White
            }
            Write-Host ""
        }
        
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        
        return $summary
    }
    catch {
        Write-RSVLog "获取数据摘要失败: $_" -Level "ERROR"
        return @{}
    }
}

# ========================================
# 主采集函数
# ========================================

function Invoke-RSVCollection {
    <#
    .SYNOPSIS
        执行RSV配置采集
    
    .DESCRIPTION
        主函数，执行完整的RSV配置采集流程
    
    .PARAMETER Config
        配置参数（hashtable）
    
    .EXAMPLE
        $config = @{
            DatabasePath = ".\data\rsv-data.db"
            RSVList = @("rsv-primary", "rsv-secondary")
            ResourceGroupName = "rg-dr-test"
            IncludeBackupVMs = $true
            IncludeReplicatedItems = $true
        }
        Invoke-RSVCollection -Config $config
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )
    
    try {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "RSV配置采集" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host ""
        
        # 初始化日志
        $Script:LogPath = if ($Config.LogPath) { $Config.LogPath } else { ".\logs\rsv-collector.log" }
        $logDir = Split-Path -Path $Script:LogPath -Parent
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        
        # 初始化数据库
        $dbInitialized = Initialize-RSVDatabase -DatabasePath $Config.DatabasePath
        if (-not $dbInitialized) {
            Write-RSVLog "数据库初始化失败" -Level "ERROR"
            return $false
        }
        
        # 采集数据
        $allData = @()
        
        if ($Config.IncludeBackupVMs) {
            foreach ($rsvName in $Config.RSVList) {
                $backupVMs = Get-RSVBackupVMs -RSVName $rsvName -ResourceGroupName $Config.ResourceGroupName
                $allData += $backupVMs
            }
        }
        
        if ($Config.IncludeReplicatedItems) {
            foreach ($rsvName in $Config.RSVList) {
                $replicatedItems = Get-RSVReplicatedItems -RSVName $rsvName -ResourceGroupName $Config.ResourceGroupName
                $allData += $replicatedItems
            }
        }
        
        # 插入数据
        if ($allData.Count -gt 0) {
            $inserted = Insert-RSVData -Data $allData -EnableIncremental $Config.EnableIncrementalCollection
            
            if ($inserted -gt 0) {
                Write-RSVLog "成功插入 $inserted 条记录" -Level "INFO"
            }
        }
        else {
            Write-RSVLog "没有采集到数据" -Level "WARNING"
        }
        
        # 显示摘要
        Get-RSVDataSummary
        
        # 导出数据
        if ($Config.EnableAutoExport -and $Config.ExportPath) {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            
            if ($Config.IncludeBackupVMs) {
                $csvPath = Join-Path $Config.ExportPath "backup-vms_$timestamp.csv"
                Export-RSVDataToCSV -DataType "BackupVM" -FilePath $csvPath
            }
            
            if ($Config.IncludeReplicatedItems) {
                $csvPath = Join-Path $Config.ExportPath "replicated-items_$timestamp.csv"
                Export-RSVDataToCSV -DataType "ReplicatedItem" -FilePath $csvPath
            }
        }
        
        # 关闭数据库
        Close-RSVDatabase
        
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "RSV配置采集完成" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        
        return $true
    }
    catch {
        Write-RSVLog "RSV配置采集失败: $_" -Level "ERROR"
        Close-RSVDatabase
        return $false
    }
}

# ========================================
# 导出模块成员
# ========================================

Export-ModuleMember -Function @(
    'Write-RSVLog',
    'Test-SQLiteModule',
    'Initialize-RSVDatabase',
    'Close-RSVDatabase',
    'Get-LastCollectionTime',
    'Get-RSVBackupVMs',
    'Get-RSVReplicatedItems',
    'Insert-RSVData',
    'Export-RSVDataToCSV',
    'Export-RSVDataToExcel',
    'Get-RSVData',
    'Get-RSVDataSummary',
    'Invoke-RSVCollection'
)
