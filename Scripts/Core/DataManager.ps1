# 简化的数据管理器 - 使用 JSON 文件存储
class DRDataManager {
    [string]$DataPath
    
    DRDataManager([string]$dataPath) {
        $this.DataPath = $dataPath
        $this.InitializeData()
    }
    
    [void] InitializeData() {
        # 确保目录存在
        $dataDir = Split-Path $this.DataPath -Parent
        if (-not (Test-Path $dataDir)) {
            New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
        }
        
        # 初始化数据结构
        $this.CreateTestData()
    }
    
    [void] CreateTestData() {
        $testData = @{
            Subscriptions = @(
                @{
                    Id = "sub-test-001"
                    Name = "Test-Subscription-HK"
                    TenantId = "tenant-001"
                    Location = "eastasia"
                    CollectedAt = Get-Date
                    Version = 1
                },
                @{
                    Id = "sub-test-002"
                    Name = "Test-Subscription-SG"
                    TenantId = "tenant-001"
                    Location = "southeastasia"
                    CollectedAt = Get-Date
                    Version = 1
                }
            )
            RecoveryServicesVaults = @(
                @{
                    Id = "/subscriptions/sub-test-001/resourceGroups/rg-asr-hk/providers/Microsoft.RecoveryServices/vaults/asr-vault-hk"
                    Name = "asr-vault-hk"
                    ResourceGroup = "rg-asr-hk"
                    SubscriptionId = "sub-test-001"
                    Location = "eastasia"
                    CollectedAt = Get-Date
                    Version = 1
                }
            )
            ReplicationProtectedItems = @(
                @{
                    Id = "/subscriptions/sub-test-001/resourceGroups/rg-asr-hk/providers/Microsoft.RecoveryServices/vaults/asr-vault-hk/replicationProtectedItems/infgal01vmp"
                    Name = "infgal01vmp"
                    VmName = "INFGAL01VMP"
                    VaultId = "/subscriptions/sub-test-001/resourceGroups/rg-asr-hk/providers/Microsoft.RecoveryServices/vaults/asr-vault-hk"
                    SubscriptionId = "sub-test-001"
                    ResourceGroup = "rg-asr-hk"
                    SourceLocation = "eastasia"
                    TargetLocation = "southeastasia"
                    PolicyId = "/subscriptions/sub-test-001/resourceGroups/rg-asr-hk/providers/Microsoft.RecoveryServices/vaults/asr-vault-hk/replicationPolicies/daily-policy"
                    HealthStatus = "Healthy"
                    ReplicationHealth = "Normal"
                    CollectedAt = Get-Date
                    Version = 1
                },
                @{
                    Id = "/subscriptions/sub-test-001/resourceGroups/rg-asr-hk/providers/Microsoft.RecoveryServices/vaults/asr-vault-hk/replicationProtectedItems/unf01vmp"
                    Name = "unf01vmp"
                    VmName = "UNF01VMP"
                    VaultId = "/subscriptions/sub-test-001/resourceGroups/rg-asr-hk/providers/Microsoft.RecoveryServices/vaults/asr-vault-hk"
                    SubscriptionId = "sub-test-001"
                    ResourceGroup = "rg-asr-hk"
                    SourceLocation = "eastasia"
                    TargetLocation = "southeastasia"
                    PolicyId = "/subscriptions/sub-test-001/resourceGroups/rg-asr-hk/providers/Microsoft.RecoveryServices/vaults/asr-vault-hk/replicationPolicies/daily-policy"
                    HealthStatus = "Healthy"
                    ReplicationHealth = "Normal"
                    CollectedAt = Get-Date
                    Version = 1
                }
            )
        }
        
        # 保存到 JSON 文件
        $testData | ConvertTo-Json -Depth 10 | Out-File -FilePath $this.DataPath -Encoding UTF8
        
        Write-Host "Test data created successfully!" -ForegroundColor Green
        Write-Host "Created 2 test VMs:" -ForegroundColor Yellow
        Write-Host "  - INFGAL01VMP (GIT - NETsec GALsync)" -ForegroundColor Cyan
        Write-Host "  - UNF01VMP (GIT - uniFLOW Management Console)" -ForegroundColor Cyan
    }
    
    [object] LoadData() {
        if (Test-Path $this.DataPath) {
            return Get-Content $this.DataPath | ConvertFrom-Json
        }
        return $null
    }
    
    [object[]] GetASRContextByVmNames([string[]]$vmNames) {
        $data = $this.LoadData()
        if (-not $data) { return @() }
        
        $results = @()
        
        foreach ($vmName in $vmNames) {
            $protectedItem = $data.ReplicationProtectedItems | Where-Object { $_.VmName -eq $vmName -and $_.HealthStatus -eq "Healthy" }
            
            if ($protectedItem) {
                $vault = $data.RecoveryServicesVaults | Where-Object { $_.Id -eq $protectedItem.VaultId }
                $subscription = $data.Subscriptions | Where-Object { $_.Id -eq $protectedItem.SubscriptionId }
                
                $result = [PSCustomObject]@{
                    Id = $protectedItem.Id
                    Name = $protectedItem.Name
                    VmName = $protectedItem.VmName
                    VaultId = $protectedItem.VaultId
                    SubscriptionId = $protectedItem.SubscriptionId
                    ResourceGroup = $protectedItem.ResourceGroup
                    SourceLocation = $protectedItem.SourceLocation
                    TargetLocation = $protectedItem.TargetLocation
                    HealthStatus = $protectedItem.HealthStatus
                    ReplicationHealth = $protectedItem.ReplicationHealth
                    VaultName = $vault.Name
                    VaultResourceGroup = $vault.ResourceGroup
                    SubscriptionName = $subscription.Name
                    TenantId = $subscription.TenantId
                }
                $results += $result
            }
        }
        
        return $results
    }
}

# 使用示例
function Initialize-DRDatabase {
    param(
        [string]$DatabasePath = "state\dr-drill.json"
    )
    
    $dataManager = [DRDataManager]::new($DatabasePath)
    
    Write-Host "Database initialized: $DatabasePath" -ForegroundColor Green
}

# 测试查询功能
function Test-DatabaseQuery {
    param(
        [string]$DatabasePath = "state\dr-drill.json"
    )
    
    $dataManager = [DRDataManager]::new($DatabasePath)
    $results = $dataManager.GetASRContextByVmNames(@("INFGAL01VMP", "UNF01VMP"))
    
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
