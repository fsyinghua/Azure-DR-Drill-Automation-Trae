# 项目规则

## 文档说明

本文档定义Azure DR Drill Automation项目的开发规则和审查标准，确保代码质量和一致性。

**文档版本**: 1.0.0  
**创建日期**: 2026-01-28  
**最后更新**: 2026-01-28  
**维护者**: Azure DR Team

---

## 一、编码规范

### 1.1 文件编码
- ⚠️ **强制要求**: 所有PowerShell脚本（.ps1、.psm1）必须使用UTF-8 BOM编码
- 使用Write工具创建文件后，必须立即转换为UTF-8 BOM编码
- Git配置：`core.autocrlf false`、`core.eol lf`
- VSCode配置：使用.editorconfig指定UTF-8 BOM编码

### 1.2 编码转换脚本
```powershell
# 创建文件后立即转换为UTF-8 BOM编码
$content = Get-Content -Path "script.ps1" -Raw -Encoding UTF8
$utf8BOM = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText("$(Get-Location)\script.ps1", $content, $utf8BOM)
```

### 1.3 编码检查
- 在提交前运行`scripts/pre-commit-check.ps1`检查文件编码
- 检查文件前3个字节是否为0xEF 0xBB 0xBF（UTF-8 BOM标记）

---

## 二、模块管理

### 2.1 模块检测
- ⚠️ **禁止使用SQLite模块命令**: 不要使用`Invoke-SqliteQuery`、`New-SQLiteConnection`等
- 使用System.Data.SQLite程序集直接操作SQLite数据库
- ⚠️ **重要**: 不要使用`[System.Reflection.Assembly]::LoadWithPartialName`加载程序集
- 直接引用程序集中的类型，让PowerShell自动加载程序集
- 在测试函数中直接使用类型（如`[System.Data.SQLite.SQLiteConnection]`）来验证程序集是否可用
- 模块检测使用多方法：已加载模块、读取manifest文件、Get-Module -ListAvailable

### 2.2 模块导出
- 所有公共函数必须在`Export-ModuleMember`中声明
- 新增公共函数后，必须更新Export-ModuleMember列表
- 在代码审查时检查函数可见性

### 2.3 函数命名
- 使用动词-名词格式（如`Get-RSVData`、`Save-RSVListToDatabase`）
- 避免使用PowerShell内置参数名称（Verbose、Debug等）

---

## 三、参数类型

### 3.1 参数类型定义
- 使用`[object]`或`[psobject]`作为参数类型，提高兼容性
- 避免使用过于具体的类型（如`[hashtable]`、`[PSAzureContext]`）

### 3.2 参数验证
- 在函数内部进行类型检查和转换
- 添加参数验证逻辑
- 提供合理的默认值

### 3.3 禁止的参数名称
- ⚠️ **禁止**: 不要定义PowerShell内置参数（Verbose、Debug、ErrorAction、WarningAction等）
- 使用`Get-Command -Syntax`查看命令的参数列表

---

## 四、Azure命令

### 4.1 命令参数
- 在使用Azure命令前查看命令文档
- 确保所有必需参数都已提供
- 使用正确的参数类型

### 4.2 ASR命令
- ⚠️ **重要**: 使用ASR命令前必须先导入Vault上下文
- 使用`Set-AzRecoveryServicesAsrVaultContext -Vault $rsv`导入Vault设置
- ⚠️ **禁止**: 不要使用`-DefaultProfile`参数，这是错误的参数
- ASR命令名称：`Get-AzRecoveryServicesAsrFabric`、`Get-AzRecoveryServicesAsrProtectableItem`等

### 4.3 Backup命令
- Backup容器命令：`Get-AzRecoveryServicesBackupContainer`必须指定`-ContainerType "AzureVM"`
- Backup项命令：`Get-AzRecoveryServicesBackupItem`必须指定`-WorkloadType "AzureVM"`

---

## 五、数据库操作

### 5.1 数据库连接
- ⚠️ **重要**: 明确数据库连接的生命周期
- 在所有数据库操作前检查连接状态
- 使用`Initialize-RSVDatabase`和`Close-RSVDatabase`管理连接

### 5.2 数据库查询
- 使用`ExecuteReader`执行查询
- 读取数据后立即保存到变量，然后关闭reader
- 检查值是否为DBNull再进行类型转换

### 5.3 DBNull处理
- 在读取数据库值后立即保存到变量
- 使用`if ($value -and $value -ne [System.DBNull]::Value)`检查null值
- 对null值调用DateTime解析前进行检查

### 5.4 缓存机制
- 使用数据库缓存避免重复操作
- 支持增量更新，避免重复数据
- 在读取缓存前先初始化数据库连接

---

## 六、CSV导出

### 6.1 导出命令
- ⚠️ **禁止**: 不要使用`Export-Excel`命令（需要ImportExcel模块）
- 使用PowerShell内置的`Export-Csv`命令
- 避免外部依赖

### 6.2 编码参数
- ⚠️ **强制要求**: `Export-Csv`必须使用`-Encoding UTF8BOM`参数
- 确保中文正确显示
- 在代码审查时检查所有Export-Csv调用

---

## 七、错误处理

### 7.1 Try-Catch块
- 所有关键操作必须使用try-catch块
- 提供详细的错误日志
- 在catch块中返回合理的默认值

### 7.2 错误日志
- 使用`Write-RSVLog`记录错误
- 指定日志级别（INFO、WARNING、ERROR）
- 提供友好的错误信息

### 7.3 错误恢复
- 提供错误恢复机制
- 使用重试逻辑
- 避免脚本意外终止

---

## 八、性能优化

### 8.1 缓存策略
- 使用数据库缓存避免重复操作
- 使用Token缓存避免重复登录
- 缓存RSV列表避免重复发现

### 8.2 批量操作
- 使用批量插入和更新
- 减少数据库往返次数
- 优化查询性能

### 8.3 并发执行
- 考虑使用并发执行
- 优化长时间运行的操作
- 提供进度提示

---

## 九、代码审查检查清单

### 9.1 环境配置
- [ ] 检查是否需要安装依赖工具（如gh CLI）
- [ ] 检查环境变量配置是否正确
- [ ] 检查远程仓库是否存在

### 9.2 编码规范
- [ ] 所有PowerShell脚本使用UTF-8 BOM编码
- [ ] 检查文件编码一致性
- [ ] 检查Git配置（core.autocrlf, core.eol）
- [ ] 检查.editorconfig配置

### 9.3 模块管理
- [ ] 检查模块检测机制是否健壮
- [ ] 检查模块导入路径是否正确
- [ ] 检查模块版本兼容性
- [ ] 检查所有公共函数是否已导出

### 9.4 参数类型
- [ ] 检查参数类型定义是否合理
- [ ] 检查参数验证是否充分
- [ ] 检查参数默认值是否合理
- [ ] 检查是否使用了PowerShell内置参数名称

### 9.5 Azure命令
- [ ] 检查Azure命令参数是否完整
- [ ] 检查ASR命令是否先导入Vault上下文
- [ ] 检查Backup命令是否指定ContainerType和WorkloadType
- [ ] 检查命令文档是否正确

### 9.6 数据库操作
- [ ] 检查数据库连接生命周期是否明确
- [ ] 检查数据库查询是否正确处理DBNull
- [ ] 检查数据库操作前是否检查连接状态
- [ ] 检查是否使用缓存机制

### 9.7 CSV导出
- [ ] 检查是否使用Export-Csv而不是Export-Excel
- [ ] 检查Export-Csv是否使用UTF8BOM编码
- [ ] 检查是否避免了外部依赖

### 9.8 错误处理
- [ ] 检查try-catch块是否完整
- [ ] 检查错误日志是否详细
- [ ] 检查错误恢复机制是否健全
- [ ] 检查重试机制是否合理

### 9.9 性能优化
- [ ] 检查是否有不必要的重复操作
- [ ] 检查是否有长时间运行的阻塞操作
- [ ] 检查是否使用了缓存机制
- [ ] 检查是否支持并发执行

### 9.10 安全性
- [ ] 检查敏感信息是否泄露
- [ ] 检查认证信息是否安全存储
- [ ] 检查权限控制是否合理

### 9.11 文档完整性
- [ ] 检查README是否更新
- [ ] 检查注释是否清晰
- [ ] 检查参数说明是否完整
- [ ] 检查使用示例是否正确
- [ ] 检查错误文档是否更新

---

## 十、常见错误模式

### 10.1 参数类型过窄
**症状**: 类型转换错误  
**原因**: 参数类型定义过于具体  
**解决**: 使用更宽泛的类型（如`[object]`、`[psobject]`）

### 10.2 未导出公共函数
**症状**: 函数调用失败  
**原因**: 未在Export-ModuleMember中声明  
**解决**: 检查并添加所有公共函数到导出列表

### 10.3 编码不一致
**症状**: 中文显示乱码或语法错误  
**原因**: 文件编码不统一  
**解决**: 统一使用UTF-8 BOM编码

### 10.4 缺少错误处理
**症状**: 脚本意外终止  
**原因**: 未使用try-catch块  
**解决**: 在关键操作周围添加错误处理

### 10.5 不必要的用户交互
**症状**: 自动化场景需要手动确认  
**原因**: 未考虑自动化需求  
**解决**: 提供配置选项控制交互行为

### 10.6 数据库连接未打开
**症状**: "数据库连接未打开"错误  
**原因**: 未在操作前初始化数据库连接  
**解决**: 在所有数据库操作前检查连接状态

### 10.7 Azure命令参数缺失
**症状**: 命令提示缺少参数  
**原因**: 未提供必需的参数  
**解决**: 查看命令文档，添加所有必需参数

### 10.8 DateTime解析错误
**症状**: "String was not recognized as a valid DateTime"错误  
**原因**: 直接对DBNull值调用DateTime.Parse  
**解决**: 先保存到变量，检查是否为DBNull再解析

---

## 十一、提交前检查

### 11.1 运行检查脚本
```powershell
# 在提交前运行检查
.\scripts\pre-commit-check.ps1
```

### 11.2 检查内容
- 文件编码检查（UTF-8 BOM）
- 语法错误检查
- 模块导出检查
- 敏感信息检查

---

## 十二、文档更新

### 12.1 错误文档
- 每次遇到新错误时，更新`docs/DEVELOPMENT-ERRORS.md`
- 记录错误信息、发生场景、根本原因、修正方案、预防措施
- 更新版本历史

### 12.2 项目规则
- 本文档定义项目的开发规则和审查标准
- 在代码审查时参考本文档
- 规则变更时更新版本历史

### 12.3 README文档
- 每次添加新功能时，更新README
- 说明功能使用方法
- 提供配置示例

---

## 版本历史

| 版本 | 日期 | 变更说明 | 作者 |
|------|------|---------|------|
| 1.0.0 | 2026-01-28 | 初始版本，定义项目规则和审查标准 | Azure DR Team |

---

## 联系信息

如有问题或建议，请联系：
- **项目团队**: Azure DR Team
- **文档位置**: `d:\UserProfiles\JoeHe\Codes\Azure-DR-Drill-Automation-Trae\.trae\`

---

**文档最后更新**: 2026-01-28
