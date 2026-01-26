# Azure Site Recovery DR 演练自动化脚本

## 项目概述

本项目提供了一套完整的 Azure Site Recovery (ASR) 灾难恢复演练自动化脚本，用于自动化执行从香港（EA）到新加坡（SEA）的虚拟机 DR 演练流程。

## 功能特性

- ✅ 安全的、可控制的 ASR 测试故障转移自动化
- ✅ 支持单台到多台虚拟机的 DR 演练
- ✅ 解决 CloudShell 会话超时问题
- ✅ 灵活的执行策略和详细日志记录
- ✅ 最小化生产环境影响

## 快速开始

### 环境要求

- PowerShell 7.x
- Azure PowerShell 模块
- Azure Contributor 权限

### 安装配置

```powershell
# 1. 克隆代码库
git clone <repository-url>
cd Azure-DR-Drill-Automation

# 2. 配置环境
Copy-Item Config\AzureConfig.example.json Config\AzureConfig.json

# 3. 编辑配置文件（最小配置原则）
# 在启用自动发现模式下，所有配置项都有默认值：
# - persistence.databasePath: SQLite 数据库路径（默认 state\\dr-drill.db）
# 如需通知，配置 NotificationConfig.json 中的 Teams Webhook 或 SMTP 信息
# 其他配置项均可保持默认值

# 4. 执行模拟验证
.\Scripts\Main\Test-DR-Simulation.ps1 -WhatIf
```

### 基本使用

```powershell
# 单台测试故障转移
.\Scripts\Main\Execute-TestFailover.ps1 -VMName "INFGAL01VMP" -TestDurationMinutes 120

# 完整演练（分阶段）
.\Scripts\Main\Execute-FullDrill.ps1 -Phase Failover -VMFilter "GIT"
.\Scripts\Main\Execute-FullDrill.ps1 -Phase Commit -VMFilter "GIT"

# 批量执行
.\Scripts\Main\Execute-FullDrill.ps1 -BatchSize 3 -Phase FullCycle
```

## 项目结构

```
Azure-DR-Drill-Automation/
├── Config/                    # 配置文件
├── Scripts/                   # 脚本文件
│   ├── Core/                  # 核心功能
│   ├── Modules/               # 功能模块
│   └── Main/                  # 主执行脚本
├── Templates/                 # 模板文件
└── Logs/                      # 日志目录
```

## 支持的虚拟机

当前支持 17 台虚拟机的 DR 演练，包括：
- GIT 部门：GALsync、用户管理、uniFLOW 等
- GFD 部门：Application Server、SharePoint 等
- GLD 部门：DNS、Intranet 等
- GSD 部门：SQL Server、CSA Expert 等
- JF 部门：Foundation Application/DB 等

## 安全考虑

- 使用最小权限原则（Contributor）
- 支持 WhatIf 模拟模式
- 详细的预执行检查
- 可逆的操作设计

## 文档

详细文档请参考：
- [需求说明.md](./需求说明.md) - 完整需求文档
- [配置指南](./docs/configuration.md) - 配置说明
- [故障排除](./docs/troubleshooting.md) - 常见问题

## 许可证

本项目采用内部许可证，仅供公司内部使用。

## 联系方式

- **项目负责人**: He Joe
- **技术支持**: JSC Cloud Team
