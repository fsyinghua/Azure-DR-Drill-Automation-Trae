# Azure 灾难恢复演练自动化脚本

## 概述

此脚本用于批量执行Azure虚拟机的灾难恢复演练，自动执行完整的故障转移流程。

## 功能特性

- 批量处理多台虚拟机
- 完整的DR演练流程：Failover → Commit → Re-protect → Fallback → Commit → Re-protect
- 自动关闭虚拟机（可选）
- 详细的日志记录
- 错误处理和恢复机制
- WhatIf模式（模拟执行）
- 进度跟踪和结果导出
- 统一的Azure登录管理
- Token缓存机制（避免频繁重新登录）
- 交互式订阅选择

## 文件说明

| 文件 | 说明 |
|------|------|
| [Start-DRDrill.ps1](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/Start-DRDrill.ps1) | 快速启动脚本，检查环境并启动演练 |
| [Azure-DR-Drill.ps1](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/Azure-DR-Drill.ps1) | 主脚本，执行DR演练逻辑 |
| [Azure-Login.psm1](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/Azure-Login.psm1) | Azure登录模块，提供统一的认证管理 |
| [config.txt](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/config.txt) | 配置参数文件 |
| [vmlist.txt](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/vmlist.txt) | 虚拟机列表 |
| [rsv.txt](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/rsv.txt) | RSV恢复服务保管库列表 |
| [需求参数.txt](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/需求参数.txt) | 详细的参数说明文档 |
| [TOKEN_CACHE.md](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/TOKEN_CACHE.md) | Token缓存机制详细说明 |
| [LOGIN_MODULE.md](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/LOGIN_MODULE.md) | Azure登录模块文档 |

## 前置要求

1. **Azure PowerShell模块**
   ```powershell
   Install-Module -Name Az -AllowClobber -Scope CurrentUser
   ```

2. **Azure权限**
   - Site Recovery Contributor 或更高权限
   - 虚拟机管理权限

3. **网络要求**
   - 能够访问Azure服务端点
   - 稳定的网络连接

## 快速开始

### 1. 配置参数

编辑 [config.txt](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/config.txt)，设置必要的参数：

```ini
SubscriptionId=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
ResourceGroupName=rg-dr-test
PrimaryRegion=eastus
SecondaryRegion=westus
FailoverType=TestFailover
ShutdownVM=true
ShutdownTimeout=15
FailoverTimeout=30
WaitTime=5
```

### 2. 配置虚拟机列表

编辑 [vmlist.txt](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/vmlist.txt)，每行一个虚拟机名称：

```
vm-prod-web-001
vm-prod-web-002
vm-prod-app-001
```

### 3. 配置RSV列表

编辑 [rsv.txt](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/rsv.txt)，每行一个RSV名称：

```
rsv-primary-eastus
rsv-secondary-westus
```

### 4. 执行演练

#### 方式一：使用快速启动脚本（推荐）

```powershell
.\Start-DRDrill.ps1
```

脚本会自动：
- 检查Azure PowerShell模块
- 导入登录模块
- 初始化Azure会话（支持token缓存）
- 验证配置文件
- 读取虚拟机和RSV列表
- 询问是否使用WhatIf模式
- 执行演练

**登录流程**：
- 首次执行：提示使用Device Login方式登录
- 后续执行：自动使用缓存的token（如果有效）
- 支持交互式选择订阅
- 支持强制重新登录

#### 方式二：直接运行主脚本

```powershell
# 正常执行
.\Azure-DR-Drill.ps1

# WhatIf模式（仅模拟，不实际执行）
.\Azure-DR-Drill.ps1 -WhatIf

# 详细输出
.\Azure-DR-Drill.ps1 -Verbose
```

**注意**：直接运行主脚本需要先手动登录Azure。

## 演练流程

脚本会为每台虚拟机执行以下步骤：

1. **Failover (with shutdown)**
   - 关闭虚拟机（如果配置了ShutdownVM=true）
   - 执行故障转移到次要区域

2. **Commit**
   - 提交故障转移操作

3. **Re-protect**
   - 重新保护虚拟机，准备回退

4. **Fallback (with shutdown)**
   - 关闭次要区域的虚拟机
   - 执行故障转移回主区域

5. **Commit**
   - 提交回退操作

6. **Re-protect**
   - 重新保护虚拟机，恢复正常状态

## 输出文件

执行完成后，会生成以下文件：

- **日志文件**: `.\logs\dr-drill.log`
  - 详细的执行日志
  - 包含时间戳和操作记录

- **结果文件**: `.\results\dr-drill-results_YYYYMMDD_HHMMSS.csv`
  - CSV格式的执行结果
  - 包含每台虚拟机的状态和耗时

## 配置参数详解

| 参数 | 说明 | 默认值 |
|------|------|--------|
| SubscriptionId | Azure订阅ID | 必填 |
| ResourceGroupName | 资源组名称 | 必填 |
| PrimaryRegion | 主区域 | eastus |
| SecondaryRegion | 次要区域 | westus |
| FailoverType | 故障转移类型 | TestFailover |
| ShutdownVM | 是否关闭虚拟机 | true |
| ShutdownTimeout | 关闭超时（分钟） | 15 |
| FailoverTimeout | 故障转移超时（分钟） | 30 |
| WaitTime | 步骤间等待时间（分钟） | 5 |
| LogPath | 日志文件路径 | .\logs\dr-drill.log |
| VerboseLogging | 详细日志 | false |
| ContinueOnError | 出错后是否继续 | true |
| ConcurrentTasks | 并发任务数 | 3 |
| EnableTokenCache | 启用Token缓存（推荐） | true |
| TokenCacheExpiryMinutes | Token缓存过期时间（分钟） | 60 |

## 故障排查

### 认证错误

**问题**: 未连接到Azure

**解决方案**:
```powershell
Connect-AzAccount -UseDeviceAuthentication
```

### 权限不足

**问题**: 执行操作时提示权限不足

**解决方案**:
- 确认账户有Site Recovery Contributor权限
- 检查虚拟机的RBAC权限

### 虚拟机未配置灾难恢复

**问题**: 找不到虚拟机的复制项

**解决方案**:
- 确认虚拟机已启用Azure Site Recovery
- 检查恢复服务保管库配置
- 验证虚拟机在正确的资源组中

### 超时错误

**问题**: 操作超时

**解决方案**:
- 增加 `ShutdownTimeout` 或 `FailoverTimeout` 参数
- 检查虚拟机是否响应正常
- 检查网络连接

## 最佳实践

1. **首次执行**
   - 先使用WhatIf模式测试
   - 从单台虚拟机开始
   - 验证配置正确后再批量执行

2. **执行时间**
   - 选择非业务高峰期
   - 预留足够的执行时间
   - 通知相关团队

3. **监控**
   - 实时查看日志文件
   - 监控Azure Portal中的ASR状态
   - 准备应急回滚方案

4. **验证**
   - 演练完成后验证虚拟机状态
   - 检查应用程序功能
   - 确认数据完整性

5. **Token缓存管理**
   - 推荐启用Token缓存（EnableTokenCache=true）
   - Token缓存保存在 .\cache\azure-token-cache.json
   - 默认缓存60分钟，可根据需要调整
   - Token过期后会自动提示重新认证
   - 如需清除缓存，删除 .\cache 目录即可

## 注意事项

- ⚠️ 演练期间虚拟机将不可用
- ⚠️ 确保有足够的Azure配额
- ⚠️ 执行前备份重要数据
- ⚠️ 建议在测试环境先验证
- ⚠️ 保持网络连接稳定

## 版本信息

- 版本: 1.0.0
- 创建日期: 2026-01-27
- 作者: Azure DR Team

## 支持

如有问题，请查看：
- [需求参数.txt](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/需求参数.txt) - 详细的参数说明
- 日志文件 - 执行日志和错误信息
- 结果文件 - CSV格式的执行结果