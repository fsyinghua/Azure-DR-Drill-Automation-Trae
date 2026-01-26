# 创建测试数据
$testData = @{
    Subscriptions = @(
        @{
            Id = "sub-test-001"
            Name = "Test-Subscription-HK"
            TenantId = "tenant-001"
            Location = "eastasia"
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
            HealthStatus = "Healthy"
            ReplicationHealth = "Normal"
            CollectedAt = Get-Date
            Version = 1
        }
    )
}

# 确保目录存在
if (-not (Test-Path "state")) {
    New-Item -ItemType Directory -Path "state" -Force | Out-Null
}

# 保存数据
$testData | ConvertTo-Json -Depth 10 | Out-File -FilePath "state\dr-drill.json" -Encoding UTF8

Write-Host "=== Test Data Created ===" -ForegroundColor Green
Write-Host "Database: state\dr-drill.json" -ForegroundColor Yellow
Write-Host "VMs: INFGAL01VMP, UNF01VMP" -ForegroundColor Cyan

# 测试查询功能
$data = Get-Content "state\dr-drill.json" | ConvertFrom-Json

Write-Host "`n=== Query Test ===" -ForegroundColor Green
foreach ($item in $data.ReplicationProtectedItems) {
    Write-Host "VM: $($item.VmName)" -ForegroundColor Yellow
    Write-Host "  Source: $($item.SourceLocation) -> Target: $($item.TargetLocation)" -ForegroundColor Cyan
    Write-Host "  Health: $($item.HealthStatus)" -ForegroundColor Cyan
    Write-Host ""
}

Write-Host "Ready to develop failover script!" -ForegroundColor Green
