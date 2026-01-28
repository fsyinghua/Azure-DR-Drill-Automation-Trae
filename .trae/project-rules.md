# Azure PowerShell 开发规范

## 核心原则

1.  **防御性编程**：任何脚本都必须包含 `try-catch-finally` 块进行错误处理，并使用 `-ErrorAction Stop` 确保关键错误能被捕获。
2.  **参数完整性**：调用 `Get-AzVM`、`New-AzResourceGroup` 等cmdlet时，必须显式指定所有必需参数（如 `-ResourceGroupName`, `-Name`, `-Location`），禁止依赖管道传参。
3.  **资源存在性检查**：在执行创建或修改操作前，必须先使用 `Get-*` cmdlet检查资源是否存在。
4.  **代码审查**：任何生成的代码都必须附带一个简单的审查报告，说明：检查了哪些参数、如何处理错误、以及资源的依赖关系。

## 输出格式
*   所有注释和提示信息请使用中文。
*   为关键逻辑和参数添加简明中文注释。

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
- ⚠️ **远程机器配置**: 在远程机器上运行脚本前，必须确保已安装System.Data.SQLite程序集
- 在远程机器上运行`Install-Module -Name PSSQLite -Scope CurrentUser -Force`安装SQLite模块
- 或使用`Install-Module -Name System.Data.SQLite -Scope CurrentUser -Force`安装System.Data.SQLite NuGet包
- ⚠️ **手动安装**: 如果无法通过NuGet安装，可以手动下载System.Data.SQLite.dll
- 运行`scripts/install-sqlite-dll.ps1`自动下载并安装System.Data.SQLite.dll
- 或手动从https://www.nuget.org/packages/System.Data.SQLite/下载.nupkg文件
- 解压.nupkg文件，将System.Data.SQLite.dll复制到lib目录
- Test-SQLiteModule函数会优先检查lib目录下的DLL，如果没有则尝试加载全局程序集
- ⚠️ **重要区别**: SQLite PowerShell模块（提供mount-sqlite命令）和System.Data.SQLite（.NET程序集）是不同的东西，不能互相替代

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

## 版本历史

| 版本 | 日期 | 变更说明 | 作者 |
|------|------|---------|------|
| 1.0.0 | 2026-01-28 | 初始版本，定义Azure PowerShell开发规范 | Azure DR Team |

---

**文档最后更新**: 2026-01-28
