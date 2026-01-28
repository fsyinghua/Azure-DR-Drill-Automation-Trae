# Azure 灾难恢复演练自动化项目计划

## 项目信息

**项目名称**: Azure 灾难恢复演练批量自动化脚本  
**创建日期**: 2026-01-27  
**当前版本**: 1.2.0  
**负责人**: Azure DR Team  
**状态**: 开发中（RSV配置采集模块）

---

## 一、项目背景

### 1.1 业务需求
需要在Windows堡垒机上批量执行多台Azure虚拟机的灾难恢复演练，验证灾难恢复（DR）流程的有效性。

### 1.2 环境约束
- **操作系统**: Windows堡垒机
- **权限**: 无管理员权限
- **网络限制**: 防火墙SSLO限制，无法使用 `az login`
- **认证方式**: 可使用 Azure PowerShell device login (`Connect-AzAccount -UseDeviceAuthentication`)


---

## 二、功能需求

### 2.1 核心功能

#### 2.1.1 DR演练流程
为每台虚拟机实现完整的DR演练流程：

```
1. Failover (with shutdown)
   ↓
2. Commit
   ↓
3. Re-protect
   ↓
4. Fallback (with shutdown)
   ↓
5. Commit
   ↓
6. Re-protect
```

#### 2.1.2 RSV配置采集与存储
采集Recovery Services Vault (RSV) 的配置和状态信息：

**Backup虚拟机采集**：
- 获取RSV中所有受保护的虚拟机
- 采集备份状态（Healthy、Warning、Critical等）
- 采集备份时间（最新备份时间、下次备份时间）
- 采集备份策略信息
- 采集备份大小和存储使用情况

**Replicated Items采集**：
- 获取RSV中所有复制的虚拟机
- 采集复制映射关系：
  - 源资源组
  - 源服务器（虚拟机）
  - 源网络
  - 目标资源组
  - 目标网络
  - 目标服务器（虚拟机）
- 采集ASR当前状态：
  - Failover状态
  - Commit状态
  - Re-protect状态
  - Fallback状态
- 采集重要操作指标：
  - Status（复制状态）
  - Health（健康状态）
  - LastSuccessfulReplicationTime（最后成功复制时间）
  - RecoveryPoint（恢复点信息）
  - RPO（恢复点目标）
  - TestFailoverState（测试故障转移状态）
  - ReplicationProgress（复制进度）
  - DataTransferRate（数据传输速率）

**数据存储**：
- 使用SQLite数据库本地存储采集的数据
- 支持增量采集插入机制
- 记录采集时间戳，便于增量更新
- 提供数据查询和导出功能

**数据导出**：
- 支持导出到Excel格式
- 支持导出到CSV格式
- 提供多种筛选和排序选项
- 支持自定义导出字段

### 2.2 输入文件
- **vmlist.txt**: 虚拟机列表（每行一个虚拟机名称）
- **rsv.txt**: RSV恢复服务保管库列表（每行一个RSV名称）
- **config.txt**: 配置参数文件（自动生成）

### 2.3 输出文件
- **日志文件**: 详细的执行日志
- **结果文件**: CSV格式的执行结果报告
- **SQLite数据库**: RSV配置和状态数据（.db文件）
- **导出文件**: Excel或CSV格式的RSV配置报告

---

## 三、开发任务清单

### 3.1 已完成任务 ✅

| 任务ID | 任务描述 | 负责人 | 完成日期 | 状态 |
|--------|---------|--------|----------|------|
| T-001 | 创建需求参数.txt文件，列出所有必要的配置参数 | Azure DR Team | 2026-01-27 | ✅ 完成 |
| T-002 | 创建vmlist.txt示例文件（虚拟机列表） | Azure DR Team | 2026-01-27 | ✅ 完成 |
| T-003 | 创建rsv.txt示例文件（RSV保险库列表） | Azure DR Team | 2026-01-27 | ✅ 完成 |
| T-004 | 创建主PowerShell脚本实现批量灾难演练功能 | Azure DR Team | 2026-01-27 | ✅ 完成 |
| T-005 | 添加日志记录和错误处理机制 | Azure DR Team | 2026-01-27 | ✅ 完成 |
| T-006 | 创建config.txt配置文件示例 | Azure DR Team | 2026-01-27 | ✅ 完成 |
| T-007 | 创建快速启动脚本 | Azure DR Team | 2026-01-27 | ✅ 完成 |
| T-008 | 创建README.md使用文档 | Azure DR Team | 2026-01-27 | ✅ 完成 |

### 3.2 待完成任务 📋

| 任务ID | 任务描述 | 优先级 | 预计工时 | 状态 |
|--------|---------|--------|----------|------|
| T-009 | 在测试环境验证脚本功能 | 高 | 4小时 | ⏳ 待开始 |
| T-010 | 根据用户反馈调整参数配置 | 中 | 2小时 | ⏳ 待开始 |
| T-011 | 添加邮件通知功能（可选） | 低 | 3小时 | ⏳ 待开始 |
| T-012 | 添加Webhook通知功能（可选） | 低 | 2小时 | ⏳ 待开始 |
| T-013 | 优化并发执行逻辑 | 中 | 4小时 | ⏳ 待开始 |
| T-014 | 添加单元测试 | 中 | 6小时 | ⏳ 待开始 |
| T-015 | 编写用户操作手册 | 低 | 3小时 | ⏳ 待开始 |
| T-016 | 设计SQLite数据库表结构（Backup VMs、Replicated Items） | 高 | 4小时 | ⏳ 待开始 |
| T-017 | 实现SQLite数据库初始化和连接管理模块 | 高 | 3小时 | ⏳ 待开始 |
| T-018 | 实现RSV Backup虚拟机信息采集功能 | 高 | 6小时 | ⏳ 待开始 |
| T-019 | 实现RSV Replicated Items信息采集功能 | 高 | 8小时 | ⏳ 待开始 |
| T-020 | 实现增量采集插入机制 | 高 | 4小时 | ⏳ 待开始 |
| T-021 | 实现数据导出到Excel功能 | 中 | 4小时 | ⏳ 待开始 |
| T-022 | 实现数据导出到CSV功能 | 中 | 3小时 | ⏳ 待开始 |
| T-023 | 创建RSV配置采集测试脚本 | 高 | 4小时 | ⏳ 待开始 |
| T-024 | 编写RSV配置采集模块文档 | 中 | 3小时 | ⏳ 待开始 |

---

## 四、技术实现

### 4.1 核心脚本文件

| 文件名 | 功能 | 行数 | 状态 |
|--------|------|------|------|
| Azure-DR-Drill.ps1 | 主脚本，执行DR演练逻辑 | ~600行 | ✅ 完成 |
| Start-DRDrill.ps1 | 快速启动脚本，环境检查 | ~140行 | ✅ 完成 |
| Azure-Login.psm1 | Azure登录模块，提供统一的认证管理 | ~350行 | ✅ 完成 |
| Azure-RSV-Collector.psm1 | RSV配置采集模块，采集Backup和Replicated Items信息 | ~800行 | ⏳ 待开发 |
| Test-RSV-Collector.ps1 | RSV配置采集测试脚本 | ~200行 | ⏳ 待开发 |

### 4.2 配置文件

| 文件名 | 用途 | 状态 |
|--------|------|------|
| config.txt | 配置参数（订阅、区域、超时等） | ✅ 完成 |
| vmlist.txt | 虚拟机列表示例 | ✅ 完成 |
| rsv.txt | RSV保险库列表示例 | ✅ 完成 |

### 4.3 文档文件

| 文件名 | 用途 | 状态 |
|--------|------|------|
| 需求参数.txt | 详细的参数说明文档 | ✅ 完成 |
| TOKEN_CACHE.md | Token缓存机制详细说明 | ✅ 完成 |
| LOGIN_MODULE.md | Azure登录模块文档 | ✅ 完成 |
| README.md | 使用文档和快速开始指南 | ✅ 完成 |
| PROJECT_PLAN.md | 本项目计划文件 | ✅ 完成 |

### 4.4 核心功能模块

#### Azure-DR-Drill.ps1 模块

| 模块名称 | 功能描述 | 状态 |
|---------|---------|------|
| Write-Log | 日志记录函数 | ✅ 完成 |
| Initialize-Logging | 日志初始化 | ✅ 完成 |
| Read-ConfigFile | 配置文件读取 | ✅ 完成 |
| Read-VMList | 虚拟机列表读取 | ✅ 完成 |
| Read-RSVList | RSV列表读取 | ✅ 完成 |
| Start-VMShutdown | 虚拟机关闭 | ✅ 完成 |
| Start-Failover | 故障转移 | ✅ 完成 |
| Start-Commit | 提交操作 | ✅ 完成 |
| Start-Reprotect | 重新保护 | ✅ 完成 |
| Start-Fallback | 回退操作 | ✅ 完成 |
| Invoke-DRDrill | 单台VM DR演练 | ✅ 完成 |
| Invoke-BatchDRDrill | 批量DR演练 | ✅ 完成 |
| Export-Results | 结果导出 | ✅ 完成 |
| Show-Summary | 结果汇总显示 | ✅ 完成 |

#### Azure-Login.psm1 模块

| 模块名称 | 功能描述 | 状态 |
|---------|---------|------|
| Get-LoginCacheFilePath | 获取登录缓存文件路径 | ✅ 完成 |
| Save-LoginCache | 保存登录信息到缓存 | ✅ 完成 |
| Get-LoginCache | 读取并验证登录缓存 | ✅ 完成 |
| Test-AzureLoginStatus | 检查Azure登录状态 | ✅ 完成 |
| Invoke-AzureDeviceLogin | 使用Device Login方式登录 | ✅ 完成 |
| Get-AzureSubscriptions | 获取所有Azure订阅 | ✅ 完成 |
| Select-AzureSubscription | 选择或切换Azure订阅 | ✅ 完成 |
| Initialize-AzureSession | 初始化Azure会话（集成缓存） | ✅ 完成 |
| Clear-AzureLoginCache | 清除登录缓存 | ✅ 完成 |
| Show-AzureLoginStatus | 显示登录状态详情 | ✅ 完成 |

#### Azure-RSV-Collector.psm1 模块（待开发）

| 模块名称 | 功能描述 | 状态 |
|---------|---------|------|
| Initialize-RSVDatabase | 初始化SQLite数据库和表结构 | ⏳ 待开发 |
| Get-RSVBackupVMs | 获取RSV中所有Backup虚拟机信息 | ⏳ 待开发 |
| Get-RSVReplicatedItems | 获取RSV中所有Replicated Items信息 | ⏳ 待开发 |
| Insert-BackupVMData | 插入或更新Backup虚拟机数据到数据库 | ⏳ 待开发 |
| Insert-ReplicatedItemData | 插入或更新Replicated Item数据到数据库 | ⏳ 待开发 |
| Export-BackupVMsToCSV | 导出Backup虚拟机数据到CSV | ⏳ 待开发 |
| Export-ReplicatedItemsToCSV | 导出Replicated Items数据到CSV | ⏳ 待开发 |
| Export-BackupVMsToExcel | 导出Backup虚拟机数据到Excel | ⏳ 待开发 |
| Export-ReplicatedItemsToExcel | 导出Replicated Items数据到Excel | ⏳ 待开发 |
| Query-RSVData | 查询RSV数据（支持筛选和排序） | ⏳ 待开发 |
| Get-RSVCollectionSummary | 获取RSV数据采集摘要 | ⏳ 待开发 |

---

## 五、配置参数说明

### 5.1 必需参数

| 参数名 | 说明 | 示例值 |
|--------|------|--------|
| SubscriptionId | Azure订阅ID | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx |
| ResourceGroupName | 资源组名称 | rg-dr-test |

### 5.2 可选参数

| 参数名 | 说明 | 默认值 |
|--------|------|--------|
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

### 5.3 RSV采集参数

| 参数名 | 说明 | 默认值 |
|--------|------|--------|
| RSVDatabasePath | SQLite数据库文件路径 | .\data\rsv-data.db |
| EnableIncrementalCollection | 启用增量采集 | true |
| CollectionInterval | 采集间隔（分钟） | 60 |
| ExportFormat | 导出格式（CSV/Excel） | CSV |
| ExportPath | 导出文件路径 | .\exports\ |
| IncludeBackupVMs | 是否采集Backup虚拟机 | true |
| IncludeReplicatedItems | 是否采集Replicated Items | true |
| MaxRetries | 采集失败重试次数 | 3 |
| RetryInterval | 重试间隔（秒） | 10 |

---

## 六、使用流程

### 6.1 DR演练流程

#### 6.1.1 准备阶段
1. 安装Azure PowerShell模块
2. 使用device login连接Azure
3. 配置vmlist.txt（虚拟机列表）
4. 配置rsv.txt（RSV列表）
5. 配置config.txt（参数配置）

#### 6.1.2 执行阶段
1. 运行Start-DRDrill.ps1
2. 选择是否使用WhatIf模式
3. 脚本自动执行DR演练
4. 监控日志输出

#### 6.1.3 验证阶段
1. 查看日志文件（./logs/dr-drill.log）
2. 查看结果文件（./results/dr-drill-results_*.csv）
3. 验证虚拟机状态
4. 确认应用程序功能正常

### 6.2 RSV配置采集流程

#### 6.2.1 准备阶段
1. 安装Azure PowerShell模块
2. 安装SQLite（如需要）
3. 使用device login连接Azure
4. 配置rsv.txt（RSV列表）
5. 配置RSV采集参数（可选）

#### 6.2.2 采集阶段
1. 运行Test-RSV-Collector.ps1
2. 脚本自动初始化SQLite数据库
3. 采集RSV Backup虚拟机信息
4. 采集RSV Replicated Items信息
5. 数据自动存储到SQLite数据库
6. 监控采集进度和日志

#### 6.2.3 导出阶段
1. 选择导出格式（CSV或Excel）
2. 选择导出字段（可选）
3. 应用筛选条件（可选）
4. 生成导出文件
5. 验证导出数据完整性

#### 6.2.4 增量采集
1. 定期运行采集脚本
2. 脚本自动检测数据变化
3. 只插入或更新变化的数据
4. 保留历史数据记录
5. 支持数据对比和分析

---

## 七、测试计划

### 7.1 单元测试
- [ ] 配置文件读取测试
- [ ] 日志记录功能测试
- [ ] Azure连接检查测试
- [ ] 各功能模块独立测试
- [ ] SQLite数据库初始化测试
- [ ] 数据插入和更新测试
- [ ] 数据查询和筛选测试
- [ ] 数据导出功能测试（CSV/Excel）

### 7.2 集成测试
- [ ] 单台虚拟机完整流程测试
- [ ] 多台虚拟机批量测试
- [ ] 错误场景测试
- [ ] 超时场景测试
- [ ] RSV Backup虚拟机采集测试
- [ ] RSV Replicated Items采集测试
- [ ] 增量采集机制测试
- [ ] 数据导出完整性测试

### 7.3 用户验收测试
- [ ] 在实际环境执行演练
- [ ] 验证业务连续性
- [ ] 性能和稳定性测试
- [ ] RSV配置采集验证
- [ ] 导出数据准确性验证
- [ ] 增量采集效果验证

---

## 八、风险管理

| 风险项 | 风险等级 | 应对措施 | 状态 |
|--------|---------|---------|------|
| 虚拟机关闭失败 | 中 | 增加重试机制和超时控制 | ✅ 已实现 |
| 故障转移超时 | 中 | 可配置超时参数 | ✅ 已实现 |
| 网络连接不稳定 | 高 | 错误处理和继续执行选项 | ✅ 已实现 |
| 权限不足 | 高 | 前置检查和明确提示 | ✅ 已实现 |
| 数据丢失 | 低 | 使用TestFailover模式 | ✅ 已实现 |
| SQLite数据库访问失败 | 中 | 增加重试机制和错误处理 | ⏳ 待实现 |
| RSV数据采集失败 | 高 | 增加重试机制和日志记录 | ⏳ 待实现 |
| 数据导出格式错误 | 中 | 格式验证和错误提示 | ⏳ 待实现 |
| 增量采集数据不一致 | 中 | 数据校验和冲突处理 | ⏳ 待实现 |
| 大量数据采集性能问题 | 中 | 分批采集和进度显示 | ⏳ 待实现 |

---

## 九、后续优化方向

### 9.1 短期优化（1-2周）
- [ ] 根据用户反馈调整参数默认值
- [ ] 优化日志输出格式
- [ ] 增加进度条显示
- [ ] 添加更多错误提示信息

### 9.2 中期优化（1-2月）
- [ ] 实现真正的并发执行
- [ ] 添加邮件通知功能
- [ ] 添加Webhook通知功能
- [ ] 支持更多故障转移类型

### 9.3 长期优化（3-6月）
- [ ] 开发Web界面
- [ ] 集成到CI/CD流程
- [ ] 支持定时任务调度
- [ ] 添加性能监控和告警

---

## 十、用户反馈记录

### 10.1 待处理反馈
| 日期 | 反馈内容 | 优先级 | 处理状态 |
|------|---------|--------|----------|
| 2026-01-28 | 开发RSV配置采集模块，采集Backup虚拟机和Replicated Items信息 | 高 | ⏳ 待处理 |
| 2026-01-28 | 使用SQLite数据库存储RSV配置数据，支持增量采集 | 高 | ⏳ 待处理 |
| 2026-01-28 | 实现数据导出到Excel和CSV格式 | 中 | ⏳ 待处理 |

### 10.2 已处理反馈
| 日期 | 反馈内容 | 处理方案 | 处理日期 |
|------|---------|---------|----------|
| 2026-01-27 | 增加token缓存机制，每次检查token没过期则继续使用缓存的token | 实现token缓存检查、保存和验证功能；添加EnableTokenCache和TokenCacheExpiryMinutes配置参数；更新相关文档 | 2026-01-27 |
| 2026-01-27 | 开发登录模块，提供统一的Azure认证管理 | 创建Azure-Login.psm1模块；实现Test-AzureLoginStatus、Invoke-AzureDeviceLogin、Select-AzureSubscription、Initialize-AzureSession等函数；集成token缓存机制；更新Start-DRDrill.ps1和Azure-DR-Drill.ps1使用新登录模块；创建LOGIN_MODULE.md文档 | 2026-01-27 |

---

## 十一、版本历史

| 版本 | 日期 | 变更说明 | 作者 |
|------|------|---------|------|
| 1.2.0 | 2026-01-28 | 新增RSV配置采集需求：采集Backup虚拟机信息（状态、时间、策略、大小）；采集Replicated Items信息（映射关系、ASR状态、操作指标）；使用SQLite数据库存储数据；支持增量采集插入机制；支持导出到Excel和CSV格式；更新项目计划文档 | Azure DR Team |
| 1.1.0 | 2026-01-27 | 新增Azure登录模块（Azure-Login.psm1），提供统一的认证管理；实现Test-AzureLoginStatus、Invoke-AzureDeviceLogin、Select-AzureSubscription、Initialize-AzureSession等函数；集成token缓存机制；更新Start-DRDrill.ps1和Azure-DR-Drill.ps1使用新登录模块；创建LOGIN_MODULE.md文档 | Azure DR Team |
| 1.0.1 | 2026-01-27 | 新增token缓存机制，避免频繁重新登录；添加Get-TokenCache、Save-TokenCache、Test-TokenValid函数；更新配置参数和文档 | Azure DR Team |
| 1.0.0 | 2026-01-27 | 初始版本，完成核心功能开发 | Azure DR Team |

---

## 十二、联系信息

如有问题或建议，请联系：
- **项目团队**: Azure DR Team
- **文档位置**: `d:\UserProfiles\JoeHe\Codes\Azure-DR-Drill-Automation-Trae`

---

## 十三、附录

### 13.1 相关文档
- [需求参数.txt](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/需求参数.txt) - 详细的参数说明
- [README.md](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/README.md) - 使用文档
- [Azure-DR-Drill.ps1](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/Azure-DR-Drill.ps1) - 主脚本
- [Start-DRDrill.ps1](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/Start-DRDrill.ps1) - 快速启动脚本

### 13.2 参考资料
- [Azure Site Recovery 文档](https://docs.microsoft.com/azure/site-recovery/)
- [Azure PowerShell 文档](https://docs.microsoft.com/powershell/azure/)

---

**文档最后更新**: 2026-01-27  
**下次评审日期**: 待定