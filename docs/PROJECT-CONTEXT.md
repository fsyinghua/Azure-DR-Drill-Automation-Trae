# Azure RSV Collector 项目上下文文档

## 项目概述

**项目名称**: Azure RSV (Recovery Services Vault) Collector
**项目类型**: PowerShell 模块 + 数据库 + 自动化脚本
**开发语言**: PowerShell 7+
**数据库**: SQLite
**主要用途**: 自动化采集Azure Recovery Services Vault的配置信息，用于DR（灾难恢复）演练

## 项目结构

```
Azure-DR-Drill-Automation-Trae/
├── Azure-RSV-Collector.psm1          # 主模块文件（核心功能）
├── Test-RSV-Collector.ps1            # 测试脚本（工作流程）
├── docs/                             # 文档目录
│   ├── DEVELOPMENT-ERRORS.md         # 开发错误记录
│   └── PROJECT-CONTEXT.md            # 本文档
├── .trae/                            # 项目配置目录
│   └── project-rules.md              # 项目开发规则
├── config/                           # 配置文件目录（如果存在）
├── output/                           # 输出文件目录（CSV导出）
└── data/                             # 数据库文件目录
```

## 核心文件说明

### 1. Azure-RSV-Collector.psm1
**重要性**: ⭐⭐⭐⭐⭐ (核心模块)
**功能**: 
- 数据库初始化和管理
- RSV配置采集
- Backup配置采集
- ASR配置采集
- 数据导出（CSV格式）
- RSV列表缓存

**关键函数**:
- `Initialize-RSVDatabase` - 初始化数据库和表结构
- `Close-RSVDatabase` - 关闭数据库连接
- `Collect-RSVConfig` - 采集RSV配置
- `Collect-BackupConfig` - 采集Backup配置
- `Collect-ASRConfig` - 采集ASR配置
- `Export-RSVDataToCSV` - 导出数据到CSV
- `Save-RSVListToDatabase` - 保存RSV列表到数据库
- `Get-RSVListFromDatabase` - 从数据库读取RSV列表

**重要规则**:
- 不要使用SQLite模块命令（Invoke-SqliteQuery等）
- 直接使用System.Data.SQLite程序集
- 所有数据库操作前检查连接状态
- Export-Csv必须使用UTF8BOM编码
- 正确处理DBNull值

### 2. Test-RSV-Collector.ps1
**重要性**: ⭐⭐⭐⭐⭐ (测试和执行脚本)
**功能**:
- 执行完整的数据采集工作流程
- 测试各个模块功能
- 导出CSV报告

**工作流程**:
1. 导入主模块
2. 初始化配置
3. 初始化数据库连接
4. 从数据库读取或自动发现RSV列表
5. 遍历每个RSV采集配置
6. 导出数据到CSV
7. 关闭数据库连接

**重要规则**:
- 在读取RSV列表前必须先初始化数据库
- 使用缓存机制避免重复发现RSV
- 正确管理数据库连接生命周期

## 数据库结构

### 主要表

1. **rsv_list** - RSV列表缓存表
   - id (主键)
   - subscription_id
   - subscription_name
   - rsv_name
   - resource_group_name
   - location
   - discovered_time

2. **rsv_config** - RSV配置表
   - id (主键)
   - subscription_id
   - rsv_name
   - resource_group_name
   - location
   - sku
   - storage_type
   - soft_delete_enabled
   - immutability_enabled
   - collected_time

3. **backup_config** - Backup配置表
   - id (主键)
   - subscription_id
   - rsv_name
   - container_name
   - container_type
   - item_name
   - item_type
   - workload_type
   - protection_status
   - last_backup_time
   - collected_time

4. **asr_config** - ASR配置表
   - id (主键)
   - subscription_id
   - rsv_name
   - fabric_name
   - protection_container_name
   - policy_name
   - replication_provider
   - policy_type
   - collected_time

## 开发规则和规范

### 编码规范
- 文件编码: UTF-8 with BOM
- PowerShell版本: 7+
- 不要添加代码注释（除非明确要求）

### 模块管理
- 不要使用SQLite模块命令
- 直接使用System.Data.SQLite程序集
- 使用`Export-ModuleMember`导出公共函数
- 函数命名使用动词-名词格式（如：Initialize-RSVDatabase）

### 参数类型
- 使用宽泛类型（如：`[string]`而不是`[ValidateNotNullOrEmpty()][string()]`）
- 避免使用PowerShell内置参数名称（如：Path, Force, Verbose等）

### Azure命令
- Get-AzRecoveryServicesBackupContainer: 必须添加`-ContainerType`参数
- Get-AzRecoveryServicesBackupItem: 必须添加`-WorkloadType`参数
- ASR命令: 使用`Get-AzRecoveryServicesAsrFabric`而不是`Get-AzRecoveryServicesFabric`
- ASR命令: 使用前必须执行`Set-AzRecoveryServicesAsrVaultContext -Vault $vault`

### 数据库操作
- 所有数据库操作前检查`$Script:DatabaseConnection`是否为null
- 正确处理DBNull值：`if ($value -ne [System.DBNull]::Value) { ... }`
- 使用缓存机制避免重复查询
- 正确关闭数据库连接

### CSV导出
- 使用`Export-Csv`而不是`Export-Excel`
- 必须使用`-Encoding UTF8BOM`参数
- 示例：`$data | Export-Csv -Path $csvPath -Encoding UTF8BOM -NoTypeInformation`

### 错误处理
- 使用Try-Catch块捕获异常
- 记录错误日志：`Write-RSVLog "错误信息" -Level "ERROR"`
- 提供错误恢复机制

### 性能优化
- 使用缓存机制（RSV列表）
- 批量操作数据库
- 避免重复查询

## 当前进度

### 已完成功能
- ✅ 数据库初始化和表结构创建
- ✅ RSV配置采集
- ✅ Backup配置采集
- ✅ ASR配置采集
- ✅ CSV数据导出（UTF8BOM编码）
- ✅ RSV列表缓存机制
- ✅ 数据库连接管理
- ✅ 错误处理和日志记录
- ✅ 测试脚本和工作流程

### 已修复错误
- ✅ SQLite模块命令错误（改用System.Data.SQLite）
- ✅ Azure cmdlet参数缺失（添加ContainerType、WorkloadType）
- ✅ DateTime解析错误（DBNull处理）
- ✅ Excel导出错误（改用CSV + UTF8BOM）
- ✅ ASR命令错误（使用正确命令和上下文）
- ✅ 数据库连接管理（正确打开/关闭）
- ✅ RSV自动发现慢（使用缓存）
- ✅ 数据库初始化顺序（先初始化再读取）

### 待办事项
- 无明确待办事项

## 常见错误和解决方案

### 1. SQLite模块检测失败
**错误**: 使用Invoke-SqliteQuery等SQLite模块命令
**解决**: 直接使用System.Data.SQLite程序集

### 2. SQLite程序集加载失败
**错误**: 使用LoadWithPartialName加载程序集失败
**解决**: 直接引用程序集中的类型，让PowerShell自动加载程序集

### 3. 远程机器SQLite环境配置
**错误**: 远程机器上System.Data.SQLite程序集未安装
**解决**: 在远程机器上运行`Install-Module -Name PSSQLite -Scope CurrentUser -Force`或`Install-Module -Name System.Data.SQLite -Scope CurrentUser -Force`安装SQLite模块
**注意**: 开发机器和远程机器的环境配置可能不同，需要在远程机器上单独安装依赖

### 4. 数据库连接为null
**错误**: 数据库操作时连接未打开
**解决**: 在所有数据库操作前检查`$Script:DatabaseConnection`

### 4. Export-Excel命令不存在
**错误**: 使用Export-Excel命令
**解决**: 使用Export-Csv代替，并添加`-Encoding UTF8BOM`

### 5. CSV编码问题
**错误**: CSV文件编码不正确
**解决**: Export-Csv必须使用UTF8BOM编码

### 6. Azure cmdlet参数错误
**错误**: Get-AzRecoveryServicesBackupContainer/Item参数缺失
**解决**: 添加ContainerType和WorkloadType参数

### 7. ASR命令错误
**错误**: Get-AzRecoveryServicesFabric命令不存在
**解决**: 使用Get-AzRecoveryServicesAsrFabric，并导入Vault上下文

### 8. Set-AzRecoveryServicesAsrVaultContext参数错误
**错误**: Set-AzRecoveryServicesAsrVaultContext缺少Vault参数
**解决**: 使用`Set-AzRecoveryServicesAsrVaultContext -Vault $rsv`，不要使用`-DefaultProfile`参数

### 9. DateTime解析错误
**错误**: DBNull值导致DateTime解析失败
**解决**: 检查DBNull值：`if ($value -ne [System.DBNull]::Value) { [DateTime]::Parse($value) }`

### 10. RSV自动发现慢
**错误**: 每次都重新发现RSV
**解决**: 使用数据库缓存RSV列表

### 11. 数据库初始化顺序错误
**错误**: 读取RSV列表前数据库未初始化
**解决**: 先调用Initialize-RSVDatabase，再调用Get-RSVListFromDatabase

## 技术栈

- **PowerShell**: 7+
- **Azure PowerShell**: Az.RecoveryServices, Az.Compute等模块
- **数据库**: SQLite (System.Data.SQLite)
- **数据导出**: CSV (UTF8BOM编码)
- **版本控制**: Git

## 快速开始指南

### 1. 环境准备
```powershell
# 安装Azure PowerShell模块
Install-Module -Name Az -Force -AllowClobber

# 连接到Azure
Connect-AzAccount
```

### 2. 运行测试脚本
```powershell
# 导入主模块
Import-Module .\Azure-RSV-Collector.psm1

# 运行测试脚本
.\Test-RSV-Collector.ps1
```

### 3. 查看输出
- CSV文件: output/ 目录
- 数据库文件: data/ 目录

## 开发工作流程

### 修改代码
1. 编辑 `Azure-RSV-Collector.psm1` 或 `Test-RSV-Collector.ps1`
2. 运行测试脚本验证修改
3. 检查输出文件和数据库
4. 提交更改到Git

### 添加新功能
1. 在 `Azure-RSV-Collector.psm1` 中添加新函数
2. 使用 `Export-ModuleMember` 导出新函数
3. 在 `Test-RSV-Collector.ps1` 中测试新功能
4. 更新文档（如果需要）
5. 提交更改到Git

### 修复错误
1. 查看 `docs/DEVELOPMENT-ERRORS.md` 了解常见错误
2. 参考 `.trae/project-rules.md` 了解开发规则
3. 修复代码
4. 运行测试脚本验证
5. 更新错误文档（如果是新错误）
6. 提交更改到Git

## 代码审查检查清单

### 编码规范
- [ ] 文件使用UTF-8 with BOM编码
- [ ] 没有不必要的代码注释

### 模块管理
- [ ] 不使用SQLite模块命令
- [ ] 使用System.Data.SQLite程序集
- [ ] 公共函数已使用Export-ModuleMember导出
- [ ] 函数命名使用动词-名词格式

### 参数类型
- [ ] 使用宽泛类型
- [ ] 避免使用PowerShell内置参数名称

### Azure命令
- [ ] Get-AzRecoveryServicesBackupContainer包含ContainerType参数
- [ ] Get-AzRecoveryServicesBackupItem包含WorkloadType参数
- [ ] ASR命令使用Get-AzRecoveryServicesAsrFabric
- [ ] ASR命令前已导入Vault上下文

### 数据库操作
- [ ] 所有数据库操作前检查连接状态
- [ ] 正确处理DBNull值
- [ ] 使用缓存机制
- [ ] 正确关闭数据库连接

### CSV导出
- [ ] 使用Export-Csv
- [ ] 包含-Encoding UTF8BOM参数

### 错误处理
- [ ] 使用Try-Catch块
- [ ] 记录错误日志
- [ ] 提供错误恢复机制

## 重要提醒

⚠️ **关键规则**:
1. 不要使用SQLite模块命令
2. Export-Csv必须使用UTF8BOM编码
3. Azure cmdlet需要特定参数
4. 所有数据库操作前检查连接状态
5. 正确处理DBNull值
6. 使用缓存机制优化性能

⚠️ **常见陷阱**:
1. 忘记初始化数据库连接
2. 使用错误的Azure命令
3. DateTime解析时忽略DBNull值
4. CSV导出时忘记UTF8BOM编码
5. ASR命令前未导入Vault上下文

## 相关文档

- `docs/DEVELOPMENT-ERRORS.md` - 详细的开发错误记录
- `.trae/project-rules.md` - 项目开发规则和审查标准

## Git提交历史

最近的提交记录（查看最新状态）:
```bash
git log --oneline -10
```

---

**最后更新**: 2026-01-28
**文档版本**: 1.0
**维护者**: 开发团队
