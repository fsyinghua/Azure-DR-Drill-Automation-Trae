# Azure DR Automation - Required Modules

## Overview
This document outlines all PowerShell modules required for the Azure DR Automation project.

## Required Modules (Must Install)

### Core Azure Modules
| Module Name | Description | Purpose | Version |
|-------------|-------------|---------|---------|
| `Az.Accounts` | Azure Account management | Authentication and subscription management | latest |
| `Az.RecoveryServices` | Azure Site Recovery management | ASR vault and replication operations | latest |
| `Az.Compute` | Azure Compute management | Virtual machine operations | latest |
| `Az.Network` | Azure Network management | Network configuration for test failover | latest |
| `Az.Resources` | Azure Resource management | Resource group and deployment operations | latest |

## Optional Modules (Recommended)

### Data Processing
| Module Name | Description | Purpose | Version |
|-------------|-------------|---------|---------|
| `ImportExcel` | Excel file reading | Reading VM lists from Excel files | latest |
| `SqlServer` | SQL Server module | Alternative SQLite access method | latest |

## Installation Commands

### Install All Required Modules
```powershell
# Install required modules
Install-Module -Name "Az.Accounts" -Force -Scope CurrentUser
Install-Module -Name "Az.RecoveryServices" -Force -Scope CurrentUser
Install-Module -Name "Az.Compute" -Force -Scope CurrentUser
Install-Module -Name "Az.Network" -Force -Scope CurrentUser
Install-Module -Name "Az.Resources" -Force -Scope CurrentUser

# Install optional modules
Install-Module -Name "ImportExcel" -Force -Scope CurrentUser
Install-Module -Name "SqlServer" -Force -Scope CurrentUser
```

### Install All Modules at Once
```powershell
# Run the installation script
.\Scripts\Setup\Install-Modules.ps1
```

## Prerequisites

### PowerShell Version
- **Minimum**: PowerShell 5.1
- **Recommended**: PowerShell 7.x

### Permissions
- Local administrator rights (for module installation)
- Internet access (to download modules from PowerShell Gallery)

### Azure Permissions
- Azure Account with appropriate permissions
- Subscription access for DR operations
- Contributor role on target resource groups

## Module Usage in Project

### Az.Accounts
- Used for: Authentication and context management
- Functions: `Connect-AzAccount`, `Set-AzContext`
- Scripts: All main execution scripts

### Az.RecoveryServices
- Used for: ASR operations and vault management
- Functions: `Get-AzRecoveryServicesVault`, `Start-AzRecoveryServicesAsrTestFailoverJob`
- Scripts: `Test-Failover.ps1`, `Execute-FullDrill.ps1`

### Az.Compute
- Used for: Virtual machine information and operations
- Functions: `Get-AzVM`, `Start-AzVM`
- Scripts: VM validation and status checking

### Az.Network
- Used for: Network configuration during test failover
- Functions: `Get-AzVirtualNetwork`, `Get-AzSubnet`
- Scripts: Test failover network setup

### Az.Resources
- Used for: Resource group operations and deployment
- Functions: `Get-AzResourceGroup`, `New-AzResourceGroupDeployment`
- Scripts: Resource validation and cleanup

### ImportExcel (Optional)
- Used for: Reading VM lists from Excel files
- Functions: `Import-Excel`
- Scripts: VM list import and processing

## Troubleshooting

### Common Issues

1. **Module Not Found**
   ```powershell
   # Check if module is installed
   Get-Module -ListAvailable -Name "Az.RecoveryServices"
   
   # Install if missing
   Install-Module -Name "Az.RecoveryServices" -Force
   ```

2. **Permission Denied**
   - Run PowerShell as Administrator
   - Use `-Scope CurrentUser` if admin rights not available

3. **Network Issues**
   - Check internet connectivity
   - Verify PowerShell Gallery access:
     ```powershell
     Find-Module -Name "Az.RecoveryServices"
     ```

4. **Version Conflicts**
   ```powershell
   # Uninstall old versions
   Uninstall-Module -Name "Az.RecoveryServices" -AllVersions
   # Install latest version
   Install-Module -Name "Az.RecoveryServices" -Force
   ```

### Verification Commands
```powershell
# Verify all required modules are installed
$requiredModules = @("Az.Accounts", "Az.RecoveryServices", "Az.Compute", "Az.Network", "Az.Resources")
foreach ($module in $requiredModules) {
    try {
        Import-Module $module -ErrorAction Stop
        Write-Host "[✓] $module - Available" -ForegroundColor Green
    } catch {
        Write-Host "[✗] $module - Missing" -ForegroundColor Red
    }
}
```

## Update Process

### Regular Updates
```powershell
# Update all Azure modules
Update-Module -Name "Az.*" -Force

# Update specific module
Update-Module -Name "Az.RecoveryServices" -Force
```

### Monthly Maintenance
1. Check for module updates
2. Test compatibility with existing scripts
3. Update documentation if needed
4. Verify functionality in test environment

## Security Considerations

- Only install modules from official PowerShell Gallery
- Verify module signatures before installation
- Keep modules updated to latest stable versions
- Use least privilege principle for Azure permissions
- Regular security updates for PowerShell and modules
