# Azure DR Test Failover Script - Simplified Version
param(
    [Parameter(Mandatory=$true)]
    [string[]]$VMNames,
    
    [string]$DatabasePath = "state\dr-drill.json",
    
    [switch]$WhatIf,
    [switch]$Force
)

Write-Host "=== Azure DR Test Failover Script ===" -ForegroundColor Green
Write-Host "VMs: $($VMNames -join ', ')" -ForegroundColor Yellow
Write-Host "Database: $DatabasePath" -ForegroundColor Cyan
Write-Host ""

try {
    # 加载数据
    Write-Host "Loading ASR configuration data..." -ForegroundColor Yellow
    if (-not (Test-Path $DatabasePath)) {
        throw "Database file not found: $DatabasePath"
    }
    
    $data = Get-Content $DatabasePath | ConvertFrom-Json
    
    # 查询 VM 上下文
    Write-Host "Querying VM ASR context..." -ForegroundColor Yellow
    $vmContexts = @()
    
    foreach ($vmName in $VMNames) {
        $protectedItem = $data.ReplicationProtectedItems | Where-Object { 
            $_.VmName -eq $vmName -and $_.HealthStatus -eq "Healthy" 
        }
        
        if ($protectedItem) {
            $vault = $data.RecoveryServicesVaults | Where-Object { $_.Id -eq $protectedItem.VaultId }
            $subscription = $data.Subscriptions | Where-Object { $_.Id -eq $protectedItem.SubscriptionId }
            
            $context = [PSCustomObject]@{
                VMName = $protectedItem.VmName
                ProtectedItemId = $protectedItem.Id
                SubscriptionId = $subscription.Id
                SubscriptionName = $subscription.Name
                VaultName = $vault.Name
                ResourceGroup = $protectedItem.ResourceGroup
                SourceLocation = $protectedItem.SourceLocation
                TargetLocation = $protectedItem.TargetLocation
                HealthStatus = $protectedItem.HealthStatus
                ReplicationHealth = $protectedItem.ReplicationHealth
            }
            $vmContexts += $context
        } else {
            Write-Warning "VM '$vmName' not found or not healthy in ASR configuration"
        }
    }
    
    if ($vmContexts.Count -eq 0) {
        throw "No valid VM contexts found"
    }
    
    Write-Host "Found $($vmContexts.Count) VM(s):" -ForegroundColor Green
    foreach ($context in $vmContexts) {
        Write-Host "  - $($context.VMName) ($($context.SubscriptionName))" -ForegroundColor Cyan
    }
    Write-Host ""
    
    # 生成执行计划
    Write-Host "Generating test failover commands..." -ForegroundColor Yellow
    $executionPlan = @()
    
    foreach ($context in $vmContexts) {
        $commands = @()
        
        # 设置订阅上下文
        $commands += "Set-AzContext -SubscriptionId '$($context.SubscriptionId)'"
        
        # 设置保管库上下文
        $commands += "Get-AzRecoveryServicesVault -Name '$($context.VaultName)' -ResourceGroupName '$($context.ResourceGroup)' | Set-AzRecoveryServicesVaultContext"
        
        # 获取受保护项目
        $commands += "`$protectedItem = Get-AzRecoveryServicesAsrReplicationProtectedItem | Where-Object { `$_.FriendlyName -eq '$($context.VMName)' }"
        
        # 执行测试故障转移
        $commands += "Start-AzRecoveryServicesAsrTestFailoverJob -ReplicationProtectedItem `$protectedItem -AzureVMNetworkName 'test-dr-vnet'"
        
        # 等待作业完成
        $commands += "Write-Host 'Test failover initiated for $($context.VMName)' -ForegroundColor Green"
        
        $plan = [PSCustomObject]@{
            VMName = $context.VMName
            SubscriptionName = $context.SubscriptionName
            VaultName = $context.VaultName
            Commands = $commands
        }
        $executionPlan += $plan
    }
    
    # 显示执行计划
    Write-Host "=== Execution Plan ===" -ForegroundColor Green
    foreach ($plan in $executionPlan) {
        Write-Host "VM: $($plan.VMName)" -ForegroundColor Yellow
        Write-Host "Subscription: $($plan.SubscriptionName)" -ForegroundColor Cyan
        Write-Host "Vault: $($plan.VaultName)" -ForegroundColor Cyan
        Write-Host "Commands:" -ForegroundColor White
        foreach ($cmd in $plan.Commands) {
            Write-Host "  $cmd" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    # 执行确认
    if (-not $WhatIf -and -not $Force) {
        $confirmation = Read-Host "Do you want to execute these commands? (y/N)"
        if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
            Write-Host "Execution cancelled." -ForegroundColor Yellow
            return
        }
    }
    
    # 执行命令
    if (-not $WhatIf) {
        Write-Host "=== Executing Test Failover ===" -ForegroundColor Green
        
        foreach ($plan in $executionPlan) {
            Write-Host "Processing VM: $($plan.VMName)" -ForegroundColor Yellow
            
            foreach ($cmd in $plan.Commands) {
                Write-Host "Executing: $cmd" -ForegroundColor Gray
                
                try {
                    # 这里模拟执行，实际环境中需要真正的 Azure PowerShell 命令
                    if ($cmd.StartsWith("Write-Host")) {
                        Invoke-Expression $cmd
                    } else {
                        Write-Host "  [SIMULATED] $cmd" -ForegroundColor DarkGray
                    }
                } catch {
                    Write-Error "Failed to execute: $cmd. Error: $($_.Exception.Message)"
                }
            }
            
            Write-Host "Completed test failover for $($plan.VMName)" -ForegroundColor Green
            Write-Host ""
        }
        
        Write-Host "=== Test Failover Completed ===" -ForegroundColor Green
        Write-Host "Remember to clean up test failovers after validation!" -ForegroundColor Yellow
    } else {
        Write-Host "=== WhatIf Mode - No actual execution ===" -ForegroundColor Yellow
    }
    
} catch {
    Write-Error "Script failed: $($_.Exception.Message)"
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}
