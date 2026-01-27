<#
.SYNOPSIS
    Azure Disaster Recovery Drill Automation Script

.DESCRIPTION
    批量执行Azure虚拟机灾难恢复演练，包括Failover、Commit、Re-protect、Fallback等操作

.NOTES
    Version: 1.1.0
    Author: Azure DR Team
    Date: 2026-01-27
    Changes: Integrated Azure login module with token caching and subscription management
#>

param(
    [string]$ConfigFile = ".\config.txt",
    [string]$VMListFile = ".\vmlist.txt",
    [string]$RSVListFile = ".\rsv.txt",
    [switch]$WhatIf,
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "Continue"

$script:LogFile = $null
$script:Config = @{}
$script:VMList = @()
$script:RSVList = @()
$script:Results = @()

try {
    Import-Module ".\Azure-Login.psm1" -Force -ErrorAction Stop
}
catch {
    Write-Error "Failed to import login module: $_"
    exit 1
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] [$Level] $Message"
    
    Write-Host $logMessage
    
    if ($script:LogFile) {
        try {
            Add-Content -Path $script:LogFile -Value $logMessage -ErrorAction SilentlyContinue
        }
        catch {
            Write-Warning "Failed to write to log file: $_"
        }
    }
}

function Initialize-Logging {
    param([string]$LogPath)
    
    try {
        $logDir = Split-Path -Parent $LogPath
        if (-not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }
        
        $script:LogFile = $LogPath
        Write-Log "Logging initialized. Log file: $LogPath"
    }
    catch {
        Write-Error "Failed to initialize logging: $_"
        exit 1
    }
}

function Read-ConfigFile {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        Write-Log "Config file not found: $FilePath. Using default values." -Level "WARNING"
        return @{
            SubscriptionId = ""
            ResourceGroupName = ""
            PrimaryRegion = "eastus"
            SecondaryRegion = "westus"
            FailoverType = "TestFailover"
            ShutdownVM = $true
            ShutdownTimeout = 15
            FailoverTimeout = 30
            WaitTime = 5
            LogPath = ".\logs\dr-drill.log"
            VerboseLogging = $false
            ContinueOnError = $true
            ConcurrentTasks = 3
            EnableTokenCache = $true
            TokenCacheExpiryMinutes = 60
        }
    }
    
    $config = @{}
    $lines = Get-Content $FilePath | Where-Object { $_ -match '^\s*[^#]' }
    
    foreach ($line in $lines) {
        if ($line -match '^\s*([^=]+)\s*=\s*(.+)\s*$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            
            switch ($key) {
                { $_ -in @("ShutdownVM", "VerboseLogging", "ContinueOnError", "EnableEmailNotification", "EnableWebhookNotification", "EnableTokenCache") } {
                    $config[$key] = $value -eq "true"
                }
                { $_ -in @("ShutdownTimeout", "FailoverTimeout", "WaitTime", "ConcurrentTasks", "SmtpPort", "TokenCacheExpiryMinutes") } {
                    $config[$key] = [int]$value
                }
                default {
                    $config[$key] = $value
                }
            }
        }
    }
    
    Write-Log "Configuration loaded from: $FilePath"
    return $config
}

function Read-VMList {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        Write-Log "VM list file not found: $FilePath" -Level "ERROR"
        throw "VM list file not found"
    }
    
    $vms = Get-Content $FilePath | Where-Object { $_ -match '^\s*[^#\s]' } | ForEach-Object { $_.Trim() }
    Write-Log "Loaded $($vms.Count) virtual machines from: $FilePath"
    return $vms
}

function Read-RSVList {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) {
        Write-Log "RSV list file not found: $FilePath" -Level "ERROR"
        throw "RSV list file not found"
    }
    
    $rsvs = Get-Content $FilePath | Where-Object { $_ -match '^\s*[^#\s]' } | ForEach-Object { $_.Trim() }
    Write-Log "Loaded $($rsvs.Count) Recovery Service Vaults from: $FilePath"
    return $rsvs
}

function Get-TokenCacheFilePath {
    $cacheDir = ".\cache"
    if (-not (Test-Path $cacheDir)) {
        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
    }
    return Join-Path $cacheDir "azure-token-cache.json"
}

function Save-TokenCache {
    param(
        [hashtable]$Context,
        [int]$TokenExpiryMinutes = 60
    )
    
    try {
        $cacheData = @{
            AccountId = $context.Account.Id
            TenantId = $context.Tenant.Id
            SubscriptionId = $context.Subscription.Id
            AccessToken = $context.TokenCache.ReadItems() | Select-Object -First 1 -ExpandProperty AccessToken
            ExpiresOn = (Get-Date).AddMinutes($TokenExpiryMinutes).ToString("o")
            CachedAt = (Get-Date).ToString("o")
        }
        
        $cacheFilePath = Get-TokenCacheFilePath
        $cacheData | ConvertTo-Json -Depth 10 | Set-Content -Path $cacheFilePath -Encoding UTF8
        
        Write-Log "Token cache saved. Expires at: $($cacheData.ExpiresOn)"
        return $true
    }
    catch {
        Write-Log "Failed to save token cache: $_" -Level "WARNING"
        return $false
    }
}

function Get-TokenCache {
    try {
        $cacheFilePath = Get-TokenCacheFilePath
        if (-not (Test-Path $cacheFilePath)) {
            return $null
        }
        
        $cacheContent = Get-Content -Path $cacheFilePath -Raw -Encoding UTF8
        $cacheData = $cacheContent | ConvertFrom-Json
        
        $expiresOn = [DateTime]::Parse($cacheData.ExpiresOn)
        if ($expiresOn -lt (Get-Date)) {
            Write-Log "Token cache expired. Cached at: $($cacheData.CachedAt), Expired at: $($cacheData.ExpiresOn)"
            Remove-Item -Path $cacheFilePath -Force -ErrorAction SilentlyContinue
            return $null
        }
        
        Write-Log "Token cache found and valid. Expires in: $($expiresOn - (Get-Date))"
        return $cacheData
    }
    catch {
        Write-Log "Failed to read token cache: $_" -Level "WARNING"
        return $null
    }
}

function Test-TokenValid {
    param([hashtable]$Config)
    
    if (-not $Config.EnableTokenCache -or $Config.EnableTokenCache -eq $false) {
        return $false
    }
    
    try {
        $context = Get-AzContext -ErrorAction Stop
        if ($context) {
            $tokenCache = Get-TokenCache
            if ($tokenCache) {
                $expiresOn = [DateTime]::Parse($tokenCache.ExpiresOn)
                $timeRemaining = $expiresOn - (Get-Date)
                
                if ($timeRemaining.TotalMinutes -gt 5) {
                    Write-Log "Cached token is valid. Time remaining: $($timeRemaining.ToString('hh\:mm\:ss'))"
                    return $true
                }
                else {
                    Write-Log "Cached token is expiring soon ($($timeRemaining.TotalMinutes) minutes remaining). Re-authentication recommended." -Level "WARNING"
                    return $false
                }
            }
        }
        return $false
    }
    catch {
        Write-Log "Error checking token validity: $_" -Level "DEBUG"
        return $false
    }
}

function Test-AzureConnection {
    try {
        $context = Get-AzContext -ErrorAction Stop
        if ($context) {
            Write-Log "Connected to Azure. Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))"
            
            if ($script:Config.EnableTokenCache) {
                Save-TokenCache -Context $context -TokenExpiryMinutes $script:Config.TokenCacheExpiryMinutes
            }
            
            return $true
        }
        return $false
    }
    catch {
        Write-Log "Not connected to Azure. Please run: Connect-AzAccount -UseDeviceAuthentication" -Level "ERROR"
        return $false
    }
}

function Get-ProtectedItem {
    param(
        [string]$VMName,
        [string]$ResourceGroupName,
        [string]$RSVName
    )
    
    try {
        $vault = Get-AzRecoveryServicesVault -Name $RSVName -ResourceGroupName $ResourceGroupName -ErrorAction Stop
        $container = Get-AzRecoveryServicesBackupContainer -ContainerType AzureVM -VaultId $vault.ID -ErrorAction SilentlyContinue | 
                     Where-Object { $_.FriendlyName -eq $VMName }
        
        if ($container) {
            $item = Get-AzRecoveryServicesBackupItem -Container $container -WorkloadType AzureVM -VaultId $vault.ID -ErrorAction SilentlyContinue
            return $item
        }
        
        return $null
    }
    catch {
        Write-Log "Error getting protected item for $VMName : $_" -Level "ERROR"
        return $null
    }
}

function Start-VMShutdown {
    param(
        [string]$VMName,
        [string]$ResourceGroupName,
        [int]$TimeoutMinutes
    )
    
    try {
        Write-Log "Attempting to shutdown VM: $VMName"
        
        $vm = Get-AzVM -Name $VMName -ResourceGroupName $ResourceGroupName -ErrorAction Stop
        
        if ($vm.PowerState -eq "VM deallocated" -or $vm.PowerState -eq "VM stopped") {
            Write-Log "VM $VMName is already stopped"
            return $true
        }
        
        Stop-AzVM -Name $VMName -ResourceGroupName $ResourceGroupName -Force -AsJob | Out-Null
        
        $startTime = Get-Date
        $timeout = [TimeSpan]::FromMinutes($TimeoutMinutes)
        
        while ((Get-Date) - $startTime -lt $timeout) {
            $status = Get-AzVM -Name $VMName -ResourceGroupName $ResourceGroupName -Status
            if ($status.PowerState -eq "VM deallocated" -or $status.PowerState -eq "VM stopped") {
                Write-Log "VM $VMName shutdown completed successfully"
                return $true
            }
            Start-Sleep -Seconds 10
        }
        
        Write-Log "VM $VMName shutdown timed out after $TimeoutMinutes minutes" -Level "WARNING"
        return $false
    }
    catch {
        Write-Log "Error shutting down VM $VMName : $_" -Level "ERROR"
        return $false
    }
}

function Start-Failover {
    param(
        [string]$VMName,
        [string]$RSVName,
        [string]$FailoverType,
        [int]$TimeoutMinutes
    )
    
    try {
        Write-Log "Starting failover for VM: $VMName (Type: $FailoverType)"
        
        $vault = Get-AzRecoveryServicesVault -Name $RSVName -ErrorAction Stop
        $fabric = Get-AzRecoveryServicesAsrFabric -VaultId $vault.ID | Select-Object -First 1
        $container = Get-AzRecoveryServicesAsrProtectionContainer -Fabric $fabric -VaultId $vault.ID | Select-Object -First 1
        $replicatedItem = Get-AzRecoveryServicesAsrReplicationProtectedItem -ProtectionContainer $container -VaultId $vault.ID | 
                          Where-Object { $_.FriendlyName -eq $VMName }
        
        if (-not $replicatedItem) {
            Write-Log "Replicated item not found for VM: $VMName" -Level "ERROR"
            return $false
        }
        
        $job = Start-AzRecoveryServicesAsrTestFailoverJob -ReplicationProtectedItem $replicatedItem -Direction PrimaryToRecovery -VaultId $vault.ID
        
        $startTime = Get-Date
        $timeout = [TimeSpan]::FromMinutes($TimeoutMinutes)
        
        while ((Get-Date) - $startTime -lt $timeout) {
            $jobStatus = Get-AzRecoveryServicesAsrJob -Job $job -VaultId $vault.ID
            
            if ($jobStatus.State -eq "Succeeded") {
                Write-Log "Failover completed successfully for VM: $VMName"
                return $true
            }
            elseif ($jobStatus.State -eq "Failed") {
                Write-Log "Failover failed for VM: $VMName - $($jobStatus.Errors)" -Level "ERROR"
                return $false
            }
            
            Start-Sleep -Seconds 15
        }
        
        Write-Log "Failover timed out for VM: $VMName" -Level "WARNING"
        return $false
    }
    catch {
        Write-Log "Error during failover for VM $VMName : $_" -Level "ERROR"
        return $false
    }
}

function Start-Commit {
    param(
        [string]$VMName,
        [string]$RSVName,
        [int]$TimeoutMinutes
    )
    
    try {
        Write-Log "Starting commit for VM: $VMName"
        
        $vault = Get-AzRecoveryServicesVault -Name $RSVName -ErrorAction Stop
        $fabric = Get-AzRecoveryServicesAsrFabric -VaultId $vault.ID | Select-Object -First 1
        $container = Get-AzRecoveryServicesAsrProtectionContainer -Fabric $fabric -VaultId $vault.ID | Select-Object -First 1
        $replicatedItem = Get-AzRecoveryServicesAsrReplicationProtectedItem -ProtectionContainer $container -VaultId $vault.ID | 
                          Where-Object { $_.FriendlyName -eq $VMName }
        
        if (-not $replicatedItem) {
            Write-Log "Replicated item not found for VM: $VMName" -Level "ERROR"
            return $false
        }
        
        $job = Start-AzRecoveryServicesAsrCommitFailoverJob -ReplicationProtectedItem $replicatedItem -VaultId $vault.ID
        
        $startTime = Get-Date
        $timeout = [TimeSpan]::FromMinutes($TimeoutMinutes)
        
        while ((Get-Date) - $startTime -lt $timeout) {
            $jobStatus = Get-AzRecoveryServicesAsrJob -Job $job -VaultId $vault.ID
            
            if ($jobStatus.State -eq "Succeeded") {
                Write-Log "Commit completed successfully for VM: $VMName"
                return $true
            }
            elseif ($jobStatus.State -eq "Failed") {
                Write-Log "Commit failed for VM: $VMName - $($jobStatus.Errors)" -Level "ERROR"
                return $false
            }
            
            Start-Sleep -Seconds 10
        }
        
        Write-Log "Commit timed out for VM: $VMName" -Level "WARNING"
        return $false
    }
    catch {
        Write-Log "Error during commit for VM $VMName : $_" -Level "ERROR"
        return $false
    }
}

function Start-Reprotect {
    param(
        [string]$VMName,
        [string]$RSVName,
        [int]$TimeoutMinutes
    )
    
    try {
        Write-Log "Starting re-protect for VM: $VMName"
        
        $vault = Get-AzRecoveryServicesVault -Name $RSVName -ErrorAction Stop
        $fabric = Get-AzRecoveryServicesAsrFabric -VaultId $vault.ID | Select-Object -First 1
        $container = Get-AzRecoveryServicesAsrProtectionContainer -Fabric $fabric -VaultId $vault.ID | Select-Object -First 1
        $replicatedItem = Get-AzRecoveryServicesAsrReplicationProtectedItem -ProtectionContainer $container -VaultId $vault.ID | 
                          Where-Object { $_.FriendlyName -eq $VMName }
        
        if (-not $replicatedItem) {
            Write-Log "Replicated item not found for VM: $VMName" -Level "ERROR"
            return $false
        }
        
        $job = Update-AzRecoveryServicesAsrProtectionDirection -ReplicationProtectedItem $replicatedItem -Direction RecoveryToPrimary -VaultId $vault.ID
        
        $startTime = Get-Date
        $timeout = [TimeSpan]::FromMinutes($TimeoutMinutes)
        
        while ((Get-Date) - $startTime -lt $timeout) {
            $jobStatus = Get-AzRecoveryServicesAsrJob -Job $job -VaultId $vault.ID
            
            if ($jobStatus.State -eq "Succeeded") {
                Write-Log "Re-protect completed successfully for VM: $VMName"
                return $true
            }
            elseif ($jobStatus.State -eq "Failed") {
                Write-Log "Re-protect failed for VM: $VMName - $($jobStatus.Errors)" -Level "ERROR"
                return $false
            }
            
            Start-Sleep -Seconds 15
        }
        
        Write-Log "Re-protect timed out for VM: $VMName" -Level "WARNING"
        return $false
    }
    catch {
        Write-Log "Error during re-protect for VM $VMName : $_" -Level "ERROR"
        return $false
    }
}

function Start-Fallback {
    param(
        [string]$VMName,
        [string]$RSVName,
        [int]$TimeoutMinutes
    )
    
    try {
        Write-Log "Starting fallback for VM: $VMName"
        
        $vault = Get-AzRecoveryServicesVault -Name $RSVName -ErrorAction Stop
        $fabric = Get-AzRecoveryServicesAsrFabric -VaultId $vault.ID | Select-Object -First 1
        $container = Get-AzRecoveryServicesAsrProtectionContainer -Fabric $fabric -VaultId $vault.ID | Select-Object -First 1
        $replicatedItem = Get-AzRecoveryServicesAsrReplicationProtectedItem -ProtectionContainer $container -VaultId $vault.ID | 
                          Where-Object { $_.FriendlyName -eq $VMName }
        
        if (-not $replicatedItem) {
            Write-Log "Replicated item not found for VM: $VMName" -Level "ERROR"
            return $false
        }
        
        $job = Start-AzRecoveryServicesAsrUnplannedFailoverJob -ReplicationProtectedItem $replicatedItem -Direction RecoveryToPrimary -VaultId $vault.ID
        
        $startTime = Get-Date
        $timeout = [TimeSpan]::FromMinutes($TimeoutMinutes)
        
        while ((Get-Date) - $startTime -lt $timeout) {
            $jobStatus = Get-AzRecoveryServicesAsrJob -Job $job -VaultId $vault.ID
            
            if ($jobStatus.State -eq "Succeeded") {
                Write-Log "Fallback completed successfully for VM: $VMName"
                return $true
            }
            elseif ($jobStatus.State -eq "Failed") {
                Write-Log "Fallback failed for VM: $VMName - $($jobStatus.Errors)" -Level "ERROR"
                return $false
            }
            
            Start-Sleep -Seconds 15
        }
        
        Write-Log "Fallback timed out for VM: $VMName" -Level "WARNING"
        return $false
    }
    catch {
        Write-Log "Error during fallback for VM $VMName : $_" -Level "ERROR"
        return $false
    }
}

function Invoke-DRDrill {
    param(
        [string]$VMName,
        [hashtable]$Config
    )
    
    $result = @{
        VMName = $VMName
        StartTime = Get-Date
        Status = "InProgress"
        Steps = @()
    }
    
    Write-Log "========================================"
    Write-Log "Starting DR drill for VM: $VMName"
    Write-Log "========================================"
    
    try {
        $rsvName = $script:RSVList[0]
        
        if ($Config.ShutdownVM) {
            $stepResult = Start-VMShutdown -VMName $VMName -ResourceGroupName $Config.ResourceGroupName -TimeoutMinutes $Config.ShutdownTimeout
            $result.Steps += @{ Step = "Shutdown"; Status = if ($stepResult) { "Success" } else { "Failed" } }
            
            if (-not $stepResult) {
                $result.Status = "Failed"
                return $result
            }
            
            Start-Sleep -Seconds ($Config.WaitTime * 60)
        }
        
        if ($WhatIf) {
            Write-Log "[WHATIF] Would execute failover for $VMName"
            $result.Steps += @{ Step = "Failover"; Status = "Skipped (WhatIf)" }
        }
        else {
            $stepResult = Start-Failover -VMName $VMName -RSVName $rsvName -FailoverType $Config.FailoverType -TimeoutMinutes $Config.FailoverTimeout
            $result.Steps += @{ Step = "Failover"; Status = if ($stepResult) { "Success" } else { "Failed" } }
            
            if (-not $stepResult) {
                $result.Status = "Failed"
                return $result
            }
            
            Start-Sleep -Seconds ($Config.WaitTime * 60)
        }
        
        if ($WhatIf) {
            Write-Log "[WHATIF] Would execute commit for $VMName"
            $result.Steps += @{ Step = "Commit"; Status = "Skipped (WhatIf)" }
        }
        else {
            $stepResult = Start-Commit -VMName $VMName -RSVName $rsvName -TimeoutMinutes $Config.FailoverTimeout
            $result.Steps += @{ Step = "Commit"; Status = if ($stepResult) { "Success" } else { "Failed" } }
            
            if (-not $stepResult) {
                $result.Status = "Failed"
                return $result
            }
            
            Start-Sleep -Seconds ($Config.WaitTime * 60)
        }
        
        if ($WhatIf) {
            Write-Log "[WHATIF] Would execute re-protect for $VMName"
            $result.Steps += @{ Step = "Reprotect"; Status = "Skipped (WhatIf)" }
        }
        else {
            $stepResult = Start-Reprotect -VMName $VMName -RSVName $rsvName -TimeoutMinutes $Config.FailoverTimeout
            $result.Steps += @{ Step = "Reprotect"; Status = if ($stepResult) { "Success" } else { "Failed" } }
            
            if (-not $stepResult) {
                $result.Status = "Failed"
                return $result
            }
            
            Start-Sleep -Seconds ($Config.WaitTime * 60)
        }
        
        if ($Config.ShutdownVM) {
            $stepResult = Start-VMShutdown -VMName $VMName -ResourceGroupName $Config.ResourceGroupName -TimeoutMinutes $Config.ShutdownTimeout
            $result.Steps += @{ Step = "FallbackShutdown"; Status = if ($stepResult) { "Success" } else { "Failed" } }
            
            if (-not $stepResult) {
                $result.Status = "Failed"
                return $result
            }
            
            Start-Sleep -Seconds ($Config.WaitTime * 60)
        }
        
        if ($WhatIf) {
            Write-Log "[WHATIF] Would execute fallback for $VMName"
            $result.Steps += @{ Step = "Fallback"; Status = "Skipped (WhatIf)" }
        }
        else {
            $stepResult = Start-Fallback -VMName $VMName -RSVName $rsvName -TimeoutMinutes $Config.FailoverTimeout
            $result.Steps += @{ Step = "Fallback"; Status = if ($stepResult) { "Success" } else { "Failed" } }
            
            if (-not $stepResult) {
                $result.Status = "Failed"
                return $result
            }
            
            Start-Sleep -Seconds ($Config.WaitTime * 60)
        }
        
        if ($WhatIf) {
            Write-Log "[WHATIF] Would execute commit for $VMName"
            $result.Steps += @{ Step = "FallbackCommit"; Status = "Skipped (WhatIf)" }
        }
        else {
            $stepResult = Start-Commit -VMName $VMName -RSVName $rsvName -TimeoutMinutes $Config.FailoverTimeout
            $result.Steps += @{ Step = "FallbackCommit"; Status = if ($stepResult) { "Success" } else { "Failed" } }
            
            if (-not $stepResult) {
                $result.Status = "Failed"
                return $result
            }
            
            Start-Sleep -Seconds ($Config.WaitTime * 60)
        }
        
        if ($WhatIf) {
            Write-Log "[WHATIF] Would execute re-protect for $VMName"
            $result.Steps += @{ Step = "FallbackReprotect"; Status = "Skipped (WhatIf)" }
        }
        else {
            $stepResult = Start-Reprotect -VMName $VMName -RSVName $rsvName -TimeoutMinutes $Config.FailoverTimeout
            $result.Steps += @{ Step = "FallbackReprotect"; Status = if ($stepResult) { "Success" } else { "Failed" } }
            
            if (-not $stepResult) {
                $result.Status = "Failed"
                return $result
            }
        }
        
        $result.Status = "Completed"
        $result.EndTime = Get-Date
        $result.Duration = $result.EndTime - $result.StartTime
        
        Write-Log "========================================"
        Write-Log "DR drill completed successfully for VM: $VMName"
        Write-Log "Duration: $($result.Duration)"
        Write-Log "========================================"
        
        return $result
    }
    catch {
        $result.Status = "Error"
        $result.ErrorMessage = $_.Exception.Message
        $result.EndTime = Get-Date
        $result.Duration = $result.EndTime - $result.StartTime
        
        Write-Log "Error during DR drill for VM $VMName : $_" -Level "ERROR"
        return $result
    }
}

function Invoke-BatchDRDrill {
    param(
        [string[]]$VMList,
        [hashtable]$Config
    )
    
    Write-Log "========================================"
    Write-Log "Starting batch DR drill for $($VMList.Count) virtual machines"
    Write-Log "========================================"
    
    $script:Results = @()
    $completedCount = 0
    $failedCount = 0
    
    foreach ($vmName in $VMList) {
        Write-Log "Processing VM: $vmName ($($completedCount + 1)/$($VMList.Count))"
        
        $result = Invoke-DRDrill -VMName $vmName -Config $Config
        $script:Results += $result
        
        if ($result.Status -eq "Completed") {
            $completedCount++
        }
        else {
            $failedCount++
            if (-not $Config.ContinueOnError) {
                Write-Log "Stopping execution due to error and ContinueOnError is false" -Level "ERROR"
                break
            }
        }
        
        Write-Log "Progress: $completedCount completed, $failedCount failed"
    }
    
    Write-Log "========================================"
    Write-Log "Batch DR drill completed"
    Write-Log "Total: $($VMList.Count), Completed: $completedCount, Failed: $failedCount"
    Write-Log "========================================"
    
    return $script:Results
}

function Export-Results {
    param(
        [array]$Results,
        [string]$OutputPath
    )
    
    try {
        $resultsDir = Split-Path -Parent $OutputPath
        if (-not (Test-Path $resultsDir)) {
            New-Item -ItemType Directory -Path $resultsDir -Force | Out-Null
        }
        
        $Results | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
        Write-Log "Results exported to: $OutputPath"
    }
    catch {
        Write-Log "Failed to export results: $_" -Level "ERROR"
    }
}

function Show-Summary {
    param([array]$Results)
    
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "DR DRILL SUMMARY" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    $total = $Results.Count
    $completed = ($Results | Where-Object { $_.Status -eq "Completed" }).Count
    $failed = ($Results | Where-Object { $_.Status -eq "Failed" }).Count
    $errorCount = ($Results | Where-Object { $_.Status -eq "Error" }).Count
    
    Write-Host "Total VMs: $total" -ForegroundColor White
    Write-Host "Completed: $completed" -ForegroundColor Green
    Write-Host "Failed: $failed" -ForegroundColor Red
    Write-Host "Errors: $errorCount" -ForegroundColor Red
    
    Write-Host ""
    Write-Host "Detailed Results:" -ForegroundColor Yellow
    
    foreach ($result in $Results) {
        $color = switch ($result.Status) {
            "Completed" { "Green" }
            "Failed" { "Red" }
            "Error" { "Red" }
            default { "Yellow" }
        }
        
        Write-Host "  - $($result.VMName): $($result.Status)" -ForegroundColor $color
        
        if ($result.Duration) {
            Write-Host "    Duration: $($result.Duration.ToString('hh\:mm\:ss'))" -ForegroundColor Gray
        }
        
        if ($result.ErrorMessage) {
            Write-Host "    Error: $($result.ErrorMessage)" -ForegroundColor Red
        }
    }
    
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

try {
    $script:Config = Read-ConfigFile -FilePath $ConfigFile
    Initialize-Logging -LogPath $script:Config.LogPath
    
    Write-Log "========================================"
    Write-Log "Azure DR Drill Automation Script"
    Write-Log "Version: 1.1.0"
    Write-Log "========================================"
    
    if ($Verbose -or $script:Config.VerboseLogging) {
        $VerbosePreference = "Continue"
    }
    
    $sessionResult = Initialize-AzureSession -Config $script:Config
    
    if (-not $sessionResult.Success) {
        Write-Log "Azure session initialization failed: $($sessionResult.Message)" -Level "ERROR"
        exit 1
    }
    
    Write-Log "Azure session initialized successfully"
    Write-Log "Account: $($sessionResult.Context.Account.Id)"
    Write-Log "Subscription: $($sessionResult.Context.Subscription.Name)"
    
    $script:VMList = Read-VMList -FilePath $VMListFile
    $script:RSVList = Read-RSVList -FilePath $RSVListFile
    
    if ($script:VMList.Count -eq 0) {
        Write-Log "No virtual machines found in VM list file" -Level "ERROR"
        exit 1
    }
    
    if ($WhatIf) {
        Write-Log "Running in WhatIf mode - no changes will be made" -Level "WARNING"
    }
    
    $results = Invoke-BatchDRDrill -VMList $script:VMList -Config $script:Config
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $resultsFile = ".\results\dr-drill-results_$timestamp.csv"
    Export-Results -Results $results -OutputPath $resultsFile
    
    Show-Summary -Results $results
    
    Write-Log "Script execution completed"
}
catch {
    Write-Log "Fatal error: $_" -Level "ERROR"
    Write-Log "Stack Trace: $($_.ScriptStackTrace)" -Level "ERROR"
    exit 1
}