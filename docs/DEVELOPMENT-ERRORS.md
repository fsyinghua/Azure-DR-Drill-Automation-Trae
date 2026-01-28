# 开发错误记录与修正方案

## 文档说明

本文档记录项目开发过程中遇到的所有错误、问题及其修正方案，用于代码审查和开发参考。

**文档版本**: 1.0.0  
**创建日期**: 2026-01-28  
**最后更新**: 2026-01-28  
**维护者**: Azure DR Team

---

## 错误分类

- [环境配置错误](#一环境配置错误)
- [编码问题](#二编码问题)
- [模块检测问题](#三模块检测问题)
- [参数类型错误](#四参数类型错误)
- [模块导出问题](#五模块导出问题)
- [用户体验问题](#六用户体验问题)
- [RSV采集错误](#七rsv采集错误)

---

## 一、环境配置错误

### 1.1 gh CLI未安装

**错误信息**:
```
gh : The term 'gh' is not recognized as the name of a cmdlet, function, script file, or operable program.
```

**发生场景**: 尝试使用gh CLI创建GitHub仓库时

**根本原因**: Windows系统未安装GitHub CLI工具

**修正方案**:
```powershell
# 使用winget安装GitHub CLI
winget install --id GitHub.cli

# 刷新环境变量
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
```

**预防措施**:
- 在项目文档中明确列出依赖工具
- 在README中添加环境检查脚本

**相关文档**: [README.md](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/README.md)

---

### 1.2 gh CLI登录失败

**错误信息**:
```
Error: You are not logged into any GitHub hosts. Run `gh auth login` to authenticate.
```

**发生场景**: 尝试使用gh CLI推送代码时

**根本原因**: 未进行GitHub认证

**修正方案**:
```powershell
# 使用设备登录方式认证
gh auth login --web

# 或者使用token登录
gh auth login --with-token < token.txt
```

**预防措施**:
- 在项目文档中说明认证步骤
- 提供多种认证方式选择

---

### 1.3 远程仓库未找到

**错误信息**:
```
fatal: repository 'https://github.com/fsyinghua/Azure-DR-Drill-Automation-Trae.git/' not found
```

**发生场景**: 尝试推送到不存在的远程仓库时

**根本原因**: 远程仓库尚未创建

**修正方案**:
```powershell
# 步骤1: 创建GitHub仓库
gh repo create Azure-DR-Drill-Automation-Trae --public --source=. --remote=origin --push

# 步骤2: 更新远程URL（如果需要）
git remote set-url origin https://github.com/fsyinghua/Azure-DR-Drill-Automation-Trae.git

# 步骤3: 推送代码
git push -u origin master
```

**预防措施**:
- 在README中说明仓库创建流程
- 提供自动化脚本处理仓库创建

---

## 二、编码问题

### 2.1 中文字符导致语法错误

**错误信息**:
```
At E:\JoeHe\codes\Azure-DR-Drill-Automation-Trae\test\Test-LoginModule.ps1:64 char:1
+ }
+ ~
Unexpected token '}' in expression or statement.
```

**发生场景**: 在远程堡垒机上运行包含中文的PowerShell脚本时

**根本原因**: 
- 文件保存时未使用UTF-8 BOM编码
- 远程系统默认编码与文件编码不匹配

**修正方案**:
```powershell
# 方案1: 使用UTF-8 BOM编码保存文件
$content = Get-Content "Azure-Login.psm1" -Raw
[IO.File]::WriteAllLines("Azure-Login.psm1", $content, [System.Text.UTF8Encoding]::new($true))

# 方案2: 在脚本开头设置编码
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$PSDefaultParameterValues['*:Encoding'] = 'utf8'
chcp 65001
```

**预防措施**:
- 在项目规范中明确要求所有PowerShell脚本使用UTF-8 BOM编码
- 在提交前检查文件编码
- 在README中说明编码要求

**相关文档**: [README.md](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/README.md)

---

### 2.2 文件编码不一致

**错误信息**: 无明显错误信息，但中文显示乱码

**发生场景**: 不同编辑器打开同一文件时

**根本原因**: 
- 不同编辑器使用不同编码保存文件
- Git配置未统一编码设置

**修正方案**:
```powershell
# Git配置统一编码
git config --global core.autocrlf false
git config --global core.eol lf

# VSCode配置（.editorconfig）
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true

[*.ps1]
charset = utf-8-bom
```

**预防措施**:
- 在项目根目录添加.editorconfig文件
- 在代码审查时检查文件编码

---

### 2.3 新建PowerShell脚本未使用UTF-8 BOM编码

**错误信息**:
```
At E:\JoeHe\codes\Azure-DR-Drill-Automation-Trae\test\Test-RSV-Collector.ps1:399 char:24
+     Write-Host "æ•°æ®æ'˜è¦:" -ForegroundColor Cyan
+                        ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
The string is missing the terminator: '.
```

**发生场景**: 创建新的PowerShell脚本文件后，在远程系统运行时

**根本原因**: 
- 使用Write工具创建文件时，默认未指定UTF-8 BOM编码
- 新创建的文件没有BOM标记，导致PowerShell解析器无法正确识别中文字符

**修正方案**:
```powershell
# 创建文件后立即转换为UTF-8 BOM编码
$content = Get-Content -Path "test\Test-RSV-Collector.ps1" -Raw -Encoding UTF8
$utf8BOM = New-Object System.Text.UTF8Encoding $true
[System.IO.File]::WriteAllText("$(Get-Location)\test\Test-RSV-Collector.ps1", $content, $utf8BOM)
```

**预防措施**:
- ⚠️ **重要**: 使用Write工具创建PowerShell脚本后，必须立即转换为UTF-8 BOM编码
- 在提交代码前运行pre-commit-check.ps1检查文件编码
- 在创建新脚本时，确保使用UTF-8 BOM编码
- 在代码审查清单中添加"检查文件编码"项

**相关文档**: [pre-commit-check.ps1](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/scripts/pre-commit-check.ps1)

---

### 2.4 PowerShell参数重复定义

**错误信息**:
```
.\test\Test-RSV-Collector.ps1 : A parameter with the name 'Verbose' was defined multiple times for the command.
At line:1 char:1
+ .\test\Test-RSV-Collector.ps1 -WhatIf
+ ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : MetadataError: (:) [], MetadataException
    + FullyQualifiedErrorId : ParameterNameAlreadyExistsForCommand
```

**发生场景**: 运行测试脚本时

**根本原因**: 
- 自定义了`Verbose`参数，但PowerShell内置了该参数
- PowerShell内置参数包括：Verbose, Debug, ErrorAction, WarningAction, InformationAction等

**修正方案**:
```powershell
# 错误示例
param(
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf,
    
    [Parameter(Mandatory = $false)]
    [switch]$Verbose  # ❌ 重复定义
)

# 正确示例
param(
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf  # ✅ 只定义自定义参数
)
```

**预防措施**:
- ⚠️ **重要**: 不要定义PowerShell内置参数（Verbose, Debug, ErrorAction等）
- 在定义参数前检查是否为PowerShell内置参数
- 使用`Get-Command -Syntax`查看命令的参数列表

**相关文档**: [about_CommonParameters](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_commonparameters)

---

## 三、模块检测问题

### 3.1 模块检测失败（已安装但未检测到）

**错误信息**:
```
未找到Azure PowerShell模块，正在安装...
```

**发生场景**: 模块已安装但检测脚本报告未找到

**根本原因**: 
- `Get-Module -ListAvailable` 扫描时间过长
- 模块路径未包含在PSModulePath中
- 模块版本不匹配

**修正方案**:
```powershell
# 实现三重检测机制

# 方法1: 检查已加载模块
$azModule = Get-Module -Name Az -ErrorAction SilentlyContinue

# 方法2: 检查可用模块
if (-not $azModule) {
    $azModule = Get-Module -ListAvailable -Name Az -ErrorAction SilentlyContinue
}

# 方法3: 检查模块路径（不导入模块）
if (-not $azModule) {
    $modulePaths = $env:PSModulePath -split ';'
    foreach ($path in $modulePaths) {
        $azPath = Join-Path $path "Az"
        if (Test-Path $azPath) {
            $manifestFile = Get-ChildItem -Path $azPath -Filter "Az.psd1" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($manifestFile) {
                # 读取模块版本而不导入
                $manifestContent = Get-Content $manifestFile.FullName -Raw -ErrorAction SilentlyContinue
                if ($manifestContent -match 'ModuleVersion\s*=\s*[''']([^'''']+)') {
                    $version = [version]$matches[1]
                    $azModule = [PSCustomObject]@{
                        Name = "Az"
                        Version = $version
                        Path = $azPath
                    }
                    break
                }
            }
        }
    }
}
```

**预防措施**:
- 使用多方法检测，提高检测成功率
- 避免实际导入模块，减少执行时间
- 添加详细的错误日志

**相关代码**: [Test-LoginModule.ps1](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/test/Test-LoginModule.ps1)

---

### 3.2 模块检测耗时过长

**错误信息**: 无错误，但检测过程耗时40秒

**发生场景**: 使用`Get-Module -ListAvailable`扫描模块时

**根本原因**: 
- PSModulePath包含大量路径
- 需要扫描所有模块目录
- 模块数量较多

**修正方案**:
```powershell
# 优化检测顺序，优先使用快速方法

# 优先使用方法1（最快）
$azModule = Get-Module -Name Az -ErrorAction SilentlyContinue

# 如果未找到，使用方法3（中等速度）
if (-not $azModule) {
    $modulePaths = $env:PSModulePath -split ';'
    foreach ($path in $modulePaths) {
        $azPath = Join-Path $path "Az"
        if (Test-Path $azPath) {
            # 直接读取manifest文件，不导入模块
            $manifestFile = Get-ChildItem -Path $azPath -Filter "Az.psd1" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($manifestFile) {
                $manifestContent = Get-Content $manifestFile.FullName -Raw -ErrorAction SilentlyContinue
                if ($manifestContent -match 'ModuleVersion\s*=\s*[''']([^'''']+)') {
                    $version = [version]$matches[1]
                    $azModule = [PSCustomObject]@{
                        Name = "Az"
                        Version = $version
                        Path = $azPath
                    }
                    break
                }
            }
        }
    }
}

# 最后使用方法2（最慢，作为后备）
if (-not $azModule) {
    $azModule = Get-Module -ListAvailable -Name Az -ErrorAction SilentlyContinue
}
```

**预防措施**:
- 优化检测顺序，优先使用快速方法
- 添加进度提示
- 考虑缓存检测结果

---

## 四、参数类型错误

### 4.1 Save-LoginCache参数类型不匹配

**错误信息**:
```
Save-LoginCache : Cannot process argument transformation on parameter 'Context'. 
Cannot convert the "Microsoft.Azure.Commands.Profile.Models.Core.PSAzureContext" 
value of type "Microsoft.Azure.Commands.Profile.Models.Core.PSAzureContext" to 
type "System.Collections.Hashtable".
```

**发生场景**: 调用Save-LoginCache函数时传入PSAzureContext对象

**根本原因**: 
- 参数类型定义为`[hashtable]`
- 实际传入的是`PSAzureContext`对象

**修正方案**:
```powershell
# 修改前
function Save-LoginCache {
    param(
        [hashtable]$Context,  # 错误：类型定义过窄
        [int]$TokenExpiryMinutes = 60
    )

# 修改后
function Save-LoginCache {
    param(
        [object]$Context,  # 正确：使用更宽泛的类型
        [int]$TokenExpiryMinutes = 60
    )
    
    try {
        $cacheData = @{
            AccountId = $Context.Account.Id
            TenantId = $Context.Tenant.Id
            SubscriptionId = $Context.Subscription.Id
            SubscriptionName = $Context.Subscription.Name
            Environment = $Context.Environment.Name
            ExpiresOn = (Get-Date).AddMinutes($TokenExpiryMinutes).ToString("o")
            CachedAt = (Get-Date).ToString("o")
        }
        
        $cacheFilePath = Get-LoginCacheFilePath
        $cacheData | ConvertTo-Json -Depth 10 | Set-Content -Path $cacheFilePath -Encoding UTF8
        
        return $true
    }
    catch {
        return $false
    }
}
```

**预防措施**:
- 使用`[object]`或`[psobject]`作为参数类型，提高兼容性
- 在函数内部进行类型检查和转换
- 添加参数验证

**相关代码**: [Azure-Login.psm1](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/Azure-Login.psm1#L23-L50)

---

## 五、模块导出问题

### 5.1 函数未导出导致调用失败

**错误信息**:
```
获取订阅失败: The term 'Get-AzureSubscriptions' is not recognized as the name 
of a cmdlet, function, script file, or operable program.
```

**发生场景**: 尝试调用模块中的函数时

**根本原因**: 
- 函数未在`Export-ModuleMember`中声明
- 模块导入后函数不可见

**修正方案**:
```powershell
# 修改前
Export-ModuleMember -Function @(
    'Test-AzureLoginStatus',
    'Invoke-AzureDeviceLogin',
    'Select-AzureSubscription',
    'Initialize-AzureSession',
    'Clear-AzureLoginCache',
    'Show-AzureLoginStatus'
)

# 修改后
Export-ModuleMember -Function @(
    'Test-AzureLoginStatus',
    'Invoke-AzureDeviceLogin',
    'Get-AzureSubscriptions',  # 添加缺失的函数
    'Select-AzureSubscription',
    'Initialize-AzureSession',
    'Clear-AzureLoginCache',
    'Show-AzureLoginStatus'
)
```

**预防措施**:
- 在代码审查时检查所有公共函数是否已导出
- 使用自动化工具检查未导出的函数
- 在模块文档中明确列出导出的函数

**相关代码**: [Azure-Login.psm1](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/Azure-Login.psm1#L400-L410)

---

## 六、用户体验问题

### 6.1 有效缓存时仍询问重新登录

**问题描述**: 
当检测到有效的token缓存时，系统仍会询问"是否重新登录? (Y/N)"，增加了不必要的交互步骤。

**发生场景**: 每次运行初始化脚本时

**根本原因**: 
- 逻辑设计未考虑自动使用有效缓存
- 用户交互流程不够优化

**修正方案**:
```powershell
# 修改前
if ($timeRemaining.TotalMinutes -gt 5) {
    Write-Host "Token缓存有效，剩余时间: $($timeRemaining.ToString('hh\:mm\:ss'))" -ForegroundColor Green
    Write-Host ""
    
    # ... 处理订阅切换 ...
    
    return @{
        Success = $true
        Context = Get-AzContext -ErrorAction Stop
        Message = "使用缓存的token"
    }
}

# 修改后
if ($timeRemaining.TotalMinutes -gt 5) {
    Write-Host "Token缓存有效，剩余时间: $($timeRemaining.ToString('hh\:mm\:ss'))" -ForegroundColor Green
    Write-Host "直接使用缓存的token" -ForegroundColor Green  # 添加提示
    Write-Host ""
    
    # ... 处理订阅切换 ...
    
    # 显示完整的会话初始化信息
    $finalContext = Get-AzContext -ErrorAction Stop
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "Azure会话初始化完成（使用缓存）" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "账户: $($finalContext.Account.Id)" -ForegroundColor White
    Write-Host "订阅: $($finalContext.Subscription.Name)" -ForegroundColor White
    Write-Host "订阅ID: $($finalContext.Subscription.Id)" -ForegroundColor White
    Write-Host "租户: $($finalContext.Tenant.Id)" -ForegroundColor White
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    
    return @{
        Success = $true
        Context = $finalContext
        Message = "使用缓存的token"
    }
}
```

**预防措施**:
- 在设计用户交互流程时考虑自动化场景
- 减少不必要的用户确认步骤
- 提供清晰的提示信息

**相关代码**: [Azure-Login.psm1](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/Azure-Login.psm1#L239-L272)

---

## 代码审查检查清单

### 环境配置
- [ ] 检查是否需要安装依赖工具（如gh CLI）
- [ ] 检查环境变量配置是否正确
- [ ] 检查远程仓库是否存在

### 编码规范
- [ ] 所有PowerShell脚本使用UTF-8 BOM编码
- [ ] 检查文件编码一致性
- [ ] 检查Git配置（core.autocrlf, core.eol）
- [ ] 检查.editorconfig配置

### 模块管理
- [ ] 检查模块检测机制是否健壮
- [ ] 检查模块导入路径是否正确
- [ ] 检查模块版本兼容性

### 参数类型
- [ ] 检查参数类型定义是否合理
- [ ] 检查参数验证是否充分
- [ ] 检查参数默认值是否合理

### 模块导出
- [ ] 检查所有公共函数是否已导出
- [ ] 检查Export-ModuleMember声明是否完整
- [ ] 检查函数可见性是否正确

### 用户体验
- [ ] 检查是否有不必要的用户交互
- [ ] 检查提示信息是否清晰
- [ ] 检查错误信息是否友好
- [ ] 检查自动化场景是否支持

### 错误处理
- [ ] 检查try-catch块是否完整
- [ ] 检查错误日志是否详细
- [ ] 检查错误恢复机制是否健全
- [ ] 检查重试机制是否合理

### 性能优化
- [ ] 检查是否有不必要的重复操作
- [ ] 检查是否有长时间运行的阻塞操作
- [ ] 检查是否使用了缓存机制
- [ ] 检查是否支持并发执行

### 安全性
- [ ] 检查敏感信息是否泄露
- [ ] 检查认证信息是否安全存储
- [ ] 检查权限控制是否合理

### 文档完整性
- [ ] 检查README是否更新
- [ ] 检查注释是否清晰
- [ ] 检查参数说明是否完整
- [ ] 检查使用示例是否正确

---

## 提交前检查脚本

```powershell
# Pre-commit检查脚本

# 1. 检查文件编码
$ps1Files = Get-ChildItem -Path . -Filter "*.ps1" -Recurse
foreach ($file in $ps1Files) {
    $content = Get-Content $file.FullName -Raw -Encoding Byte
    if ($content[0] -ne 0xEF -or $content[1] -ne 0xBB -or $content[2] -ne 0xBF) {
        Write-Host "警告: $($file.FullName) 未使用UTF-8 BOM编码" -ForegroundColor Yellow
    }
}

# 2. 检查语法错误
foreach ($file in $ps1Files) {
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
    if ($ast.ParseErrors.Count -gt 0) {
        Write-Host "错误: $($file.FullName) 存在语法错误" -ForegroundColor Red
        $ast.ParseErrors | ForEach-Object {
            Write-Host "  行 $($_.Extent.StartLineNumber): $($_.Message)" -ForegroundColor Yellow
        }
    }
}

# 3. 检查模块导出
$moduleFiles = Get-ChildItem -Path . -Filter "*.psm1" -Recurse
foreach ($file in $moduleFiles) {
    $content = Get-Content $file.FullName -Raw
    if ($content -match 'Export-ModuleMember') {
        Write-Host "检查: $($file.FullName) 模块导出" -ForegroundColor Green
    } else {
        Write-Host "警告: $($file.FullName) 未找到Export-ModuleMember" -ForegroundColor Yellow
    }
}

# 4. 检查敏感信息
$allFiles = Get-ChildItem -Path . -Include "*.ps1","*.psm1","*.txt","*.json" -Recurse
$patterns = @('password', 'secret', 'token', 'key', 'credential')
foreach ($file in $allFiles) {
    $content = Get-Content $file.FullName -Raw
    foreach ($pattern in $patterns) {
        if ($content -match $pattern) {
            Write-Host "警告: $($file.FullName) 可能包含敏感信息: $pattern" -ForegroundColor Yellow
        }
    }
}
```

---

## 常见错误模式

### 模式1: 参数类型过窄
**症状**: 类型转换错误
**原因**: 参数类型定义过于具体
**解决**: 使用更宽泛的类型（如`[object]`、`[psobject]`）

### 模式2: 未导出公共函数
**症状**: 函数调用失败
**原因**: 未在Export-ModuleMember中声明
**解决**: 检查并添加所有公共函数到导出列表

### 模式3: 编码不一致
**症状**: 中文显示乱码或语法错误
**原因**: 文件编码不统一
**解决**: 统一使用UTF-8 BOM编码

### 模式4: 缺少错误处理
**症状**: 脚本意外终止
**原因**: 未使用try-catch块
**解决**: 在关键操作周围添加错误处理

### 模式5: 不必要的用户交互
**症状**: 自动化场景需要手动确认
**原因**: 未考虑自动化需求
**解决**: 提供配置选项控制交互行为

---

## 七、RSV采集错误

### 7.1 SQLite模块检测失败

**错误信息**:
```
未找到SQLite模块，正在安装...
```

**发生场景**: 测试SQLite模块是否可用时

**根本原因**: 
- `Get-Module -ListAvailable` 扫描时间过长
- SQLite模块命令与System.Data.SQLite不同
- SQLite模块的命令是`mount-sqlite`，不是`Invoke-SqliteQuery`

**修正方案**:
```powershell
# 修改前
function Test-SQLiteModule {
    $sqliteModule = Get-Module -ListAvailable -Name SQLite -ErrorAction SilentlyContinue
    
    if (-not $sqliteModule) {
        Write-Host "未找到SQLite模块，正在安装..." -ForegroundColor Yellow
        Install-Module -Name SQLite -Force -Scope CurrentUser
    }
}

# 修改后
function Test-SQLiteModule {
    # 直接检查System.Data.SQLite程序集是否可用
    try {
        Add-Type -Path "System.Data.SQLite.dll" -ErrorAction Stop
        Write-Host "System.Data.SQLite可用" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "System.Data.SQLite不可用: $_" -ForegroundColor Red
        return $false
    }
}
```

**预防措施**:
- ⚠️ **重要**: 不要使用SQLite模块的命令（如`Invoke-SqliteQuery`、`New-SQLiteConnection`）
- 直接使用System.Data.SQLite程序集操作SQLite数据库
- 在项目规范中明确使用System.Data.SQLite

**相关代码**: [Azure-RSV-Collector.psm1](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/Azure-RSV-Collector.psm1#L40-L60)

---

### 7.2 数据库连接为null

**错误信息**:
```
[ERROR] 数据库连接未打开
```

**发生场景**: 调用Get-RSVData或Get-RSVDataSummary函数时

**根本原因**: 
- 数据库连接已关闭
- 未在调用前初始化数据库连接
- 脚本执行流程中数据库连接管理不当

**修正方案**:
```powershell
# 在Get-RSVData函数中添加检查
function Get-RSVData {
    try {
        if (-not $Script:DatabaseConnection) {
            Write-RSVLog "数据库连接未打开" -Level "ERROR"
            return @()
        }
        
        # ... 查询逻辑 ...
    }
    catch {
        Write-RSVLog "查询数据失败: $_" -Level "ERROR"
        return @()
    }
}

# 在Get-RSVDataSummary函数中添加检查
function Get-RSVDataSummary {
    try {
        Write-RSVLog "获取数据摘要" -Level "INFO"
        
        if (-not $Script:DatabaseConnection) {
            Write-RSVLog "数据库连接未打开" -Level "ERROR"
            return @{}
        }
        
        # ... 查询逻辑 ...
    }
    catch {
        Write-RSVLog "获取数据摘要失败: $_" -Level "ERROR"
        return @{}
    }
}

# 在导出前重新打开数据库连接
$dbInitialized = Initialize-RSVDatabase -DatabasePath $config.DatabasePath
if (-not $dbInitialized) {
    Write-Host "  数据库初始化失败" -ForegroundColor Red
    return
}

# ... 执行导出 ...

Close-RSVDatabase
```

**预防措施**:
- 在所有数据库操作前检查连接状态
- 在脚本执行流程中明确数据库连接的生命周期
- 在导出前重新打开数据库连接
- 添加详细的错误日志

**相关代码**: [Azure-RSV-Collector.psm1](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/Azure-RSV-Collector.psm1#L860-L870), [Test-RSV-Collector.ps1](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/test/Test-RSV-Collector.ps1#L317-L323)

---

### 7.3 Export-Excel命令不存在

**错误信息**:
```
The term 'Export-Excel' is not recognized as the name of a cmdlet, function, script file, or operable program.
```

**发生场景**: 尝试导出数据到Excel文件时

**根本原因**: 
- 未安装ImportExcel模块
- 用户环境可能没有安装该模块
- Excel导出需要额外依赖

**修正方案**:
```powershell
# 修改前
$backupVMs | Export-Excel -Path $excelPath -WorksheetName "BackupVMs" -AutoSize -AutoFilter -FreezeTopRow

# 修改后
$backupVMs | Export-Csv -Path $backupVMsPath -NoTypeInformation -Encoding UTF8BOM
Write-Host "      导出 $($backupVMs.Count) 条Backup VM记录到 $backupVMsPath" -ForegroundColor Green
```

**预防措施**:
- ⚠️ **重要**: 使用PowerShell内置的Export-Csv命令，避免外部依赖
- 使用UTF8BOM编码确保中文正确显示
- 在项目规范中明确使用CSV导出

**相关代码**: [Test-RSV-Collector.ps1](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/test/Test-RSV-Collector.ps1#L322-L335)

---

### 7.4 CSV编码问题

**错误信息**: 无明显错误，但CSV文件中文显示乱码

**发生场景**: 使用Excel或其他工具打开CSV文件时

**根本原因**: 
- 使用UTF8编码而不是UTF8BOM
- 缺少BOM标记导致Excel无法正确识别编码

**修正方案**:
```powershell
# 修改前
$backupVMs | Export-Csv -Path $backupVMsPath -NoTypeInformation -Encoding UTF8

# 修改后
$backupVMs | Export-Csv -Path $backupVMsPath -NoTypeInformation -Encoding UTF8BOM
```

**预防措施**:
- ⚠️ **重要**: Export-Csv必须使用UTF8BOM编码
- 在项目规范中明确编码要求
- 在代码审查时检查所有Export-Csv调用

**相关代码**: [Test-RSV-Collector.ps1](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/test/Test-RSV-Collector.ps1#L322-L335)

---

### 7.5 Get-AzRecoveryServicesBackupContainer参数错误

**错误信息**:
```
cmdlet Get-AzRecoveryServicesBackupContainer at command pipeline position 1
Supply values for the following parameters: 
(Type !? for Help.) 
ContainerType:
```

**发生场景**: 采集Backup虚拟机时

**根本原因**: 
- 命令缺少必需的ContainerType参数
- Azure PowerShell模块要求指定容器类型

**修正方案**:
```powershell
# 修改前
$containers = Get-AzRecoveryServicesBackupContainer -VaultId $rsv.ID -ErrorAction SilentlyContinue

# 修改后
$containers = Get-AzRecoveryServicesBackupContainer -VaultId $rsv.ID -ContainerType "AzureVM" -ErrorAction SilentlyContinue
```

**预防措施**:
- 在使用Azure命令前查看命令文档
- 确保所有必需参数都已提供
- 在代码审查时检查Azure命令调用

**相关代码**: [Azure-RSV-Collector.psm1](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/Azure-RSV-Collector.psm1#L362)

---

### 7.6 Get-AzRecoveryServicesBackupItem参数错误

**错误信息**:
```
cmdlet Get-AzRecoveryServicesBackupItem at command pipeline position 1
Supply values for the following parameters: 
(Type !? for Help.) 
WorkloadType:
```

**发生场景**: 采集Backup虚拟机时

**根本原因**: 
- 命令缺少必需的WorkloadType参数
- Azure PowerShell模块要求指定工作负载类型

**修正方案**:
```powershell
# 修改前
$items = Get-AzRecoveryServicesBackupItem -Container $container -VaultId $rsv.ID -ErrorAction SilentlyContinue

# 修改后
$items = Get-AzRecoveryServicesBackupItem -Container $container -VaultId $rsv.ID -WorkloadType "AzureVM" -ErrorAction SilentlyContinue
```

**预防措施**:
- 在使用Azure命令前查看命令文档
- 确保所有必需参数都已提供
- 在代码审查时检查Azure命令调用

**相关代码**: [Azure-RSV-Collector.psm1](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/Azure-RSV-Collector.psm1#L373)

---

### 7.7 Get-AzRecoveryServicesFabric命令不存在

**错误信息**:
```
The term 'Get-AzRecoveryServicesFabric' is not recognized as the name of a cmdlet, function, script file, or operable program.
```

**发生场景**: 采集Replicated Items时

**根本原因**: 
- ASR命令名称不正确
- 可能需要额外的ASR模块
- 命令可能已更名

**修正方案**:
```powershell
# 修改前
$fabrics = Get-AzRecoveryServicesFabric -VaultId $rsv.ID -ErrorAction SilentlyContinue

# 修改后
# 导入Vault设置
try {
    $context = Get-AzContext
    $null = Set-AzRecoveryServicesAsrVaultContext -DefaultProfile $context -ErrorAction SilentlyContinue
}
catch {
    Write-RSVLog "导入Vault设置失败: $_" -Level "WARNING"
}

$fabrics = Get-AzRecoveryServicesAsrFabric -ErrorAction SilentlyContinue
```

**预防措施**:
- 在使用ASR命令前先导入Vault上下文
- 检查ASR命令的正确名称
- 添加详细的错误日志

**相关代码**: [Azure-RSV-Collector.psm1](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/Azure-RSV-Collector.psm1#L460-L475)

---

### 7.8 DateTime解析错误

**错误信息**:
```
[ERROR] 获取数据摘要失败: Exception calling "Parse" with "1" argument(s): "String was not recognized as a valid DateTime."
```

**发生场景**: 获取数据摘要时

**根本原因**: 
- COUNT(*)返回整数，但MIN/MAX返回DBNull
- 直接对DBNull值调用[DateTime]::Parse会失败
- 未正确处理null值

**修正方案**:
```powershell
# 修改前
if ($reader.Read()) {
    $summary[$type] = @{
        Count = $reader["count"]
        FirstCollectionTime = if ($reader["first_time"]) { [DateTime]::Parse($reader["first_time"]) } else { $null }
        LastCollectionTime = if ($reader["last_time"]) { [DateTime]::Parse($reader["last_time"]) } else { $null }
    }
    $reader.Close()
}

# 修改后
if ($reader.Read()) {
    $count = [int]$reader["count"]
    $firstTime = $reader["first_time"]
    $lastTime = $reader["last_time"]
    $reader.Close()
    
    $summary[$type] = @{
        Count = $count
        FirstCollectionTime = if ($firstTime -and $firstTime -ne [System.DBNull]::Value) { [DateTime]::Parse($firstTime) } else { $null }
        LastCollectionTime = if ($lastTime -and $lastTime -ne [System.DBNull]::Value) { [DateTime]::Parse($lastTime) } else { $null }
    }
}
```

**预防措施**:
- ⚠️ **重要**: 在读取数据库值后立即保存到变量，然后关闭reader
- 检查值是否为DBNull再进行类型转换
- 使用try-catch处理DateTime解析错误

**相关代码**: [Azure-RSV-Collector.psm1](file:///d:/UserProfiles/JoeHe/Codes/Azure-DRill-Automation-Trae/Azure-RSV-Collector.psm1#L864-L876)

---

### 7.9 Set-AzRecoveryServicesAsrVaultContext参数错误

**错误信息**:
```
[WARNING] 导入Vault设置失败: Cannot bind parameter 'DefaultProfile'. Cannot convert the "RSV-GIT-S-ASR-R-SEA-001" value of type "System.String" to type "Microsoft.Azure.Commands.Common.Authentication.Abstractions.Core.IAzureContextContainer".
```

**发生场景**: 导入ASR Vault上下文时

**根本原因**: 
- 参数类型不匹配
- 传递的是字符串而不是Azure上下文对象
- 参数名称使用错误

**修正方案**:
```powershell
# 修改前
$null = Set-AzRecoveryServicesAsrVaultContext -DefaultProfile $rsv.Name -ErrorAction SilentlyContinue

# 修改后
try {
    $context = Get-AzContext
    $null = Set-AzRecoveryServicesAsrVaultContext -DefaultProfile $context -ErrorAction SilentlyContinue
}
catch {
    Write-RSVLog "导入Vault设置失败: $_" -Level "WARNING"
}
```

**预防措施**:
- 使用Get-AzContext获取正确的上下文对象
- 检查参数类型是否匹配
- 添加错误处理

**相关代码**: [Azure-RSV-Collector.psm1](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/Azure-RSV-Collector.psm1#L461-L467)

---

### 7.10 RSV自动发现过程慢

**问题描述**: 
自动发现所有订阅下的RSV配置过程耗时较长（约40秒），影响用户体验。

**发生场景**: 每次运行测试脚本时

**根本原因**: 
- 需要遍历所有订阅
- 每个订阅都要调用Get-AzRecoveryServicesVault
- 没有缓存机制

**修正方案**:
```powershell
# 创建RSV列表表
$createRSVListTable = @"
    CREATE TABLE IF NOT EXISTS rsv_list (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        subscription_id TEXT NOT NULL,
        subscription_name TEXT NOT NULL,
        rsv_name TEXT NOT NULL,
        resource_group_name TEXT NOT NULL,
        location TEXT NOT NULL,
        discovered_time TEXT NOT NULL,
        UNIQUE(subscription_id, rsv_name)
    )
"@

# 保存RSV列表到数据库
function Save-RSVListToDatabase {
    param(
        [Parameter(Mandatory = $true)]
        [array]$RSVList
    )
    
    try {
        if (-not $Script:DatabaseConnection) {
            Write-RSVLog "数据库连接未打开" -Level "ERROR"
            return $false
        }
        
        $savedCount = 0
        $updatedCount = 0
        
        foreach ($rsv in $RSVList) {
            $subscriptionId = $rsv.SubscriptionId
            $rsvName = $rsv.RSVName
            $discoveredTime = (Get-Date).ToUniversalTime().ToString("o")
            
            $checkQuery = "SELECT id FROM rsv_list WHERE subscription_id = '$subscriptionId' AND rsv_name = '$rsvName'"
            $command = $Script:DatabaseConnection.CreateCommand()
            $command.CommandText = $checkQuery
            $reader = $command.ExecuteReader()
            
            $exists = $reader.Read()
            $reader.Close()
            
            if ($exists) {
                # 更新
                $updatedCount++
            }
            else {
                # 新增
                $savedCount++
            }
        }
        
        Write-RSVLog "保存RSV列表完成: 新增 $savedCount 条，更新 $updatedCount 条" -Level "INFO"
        return $true
    }
    catch {
        Write-RSVLog "保存RSV列表失败: $_" -Level "ERROR"
        return $false
    }
}

# 从数据库读取RSV列表
function Get-RSVListFromDatabase {
    try {
        if (-not $Script:DatabaseConnection) {
            Write-RSVLog "数据库连接未打开" -Level "ERROR"
            return @()
        }
        
        $query = "SELECT subscription_id, subscription_name, rsv_name, resource_group_name, location, discovered_time FROM rsv_list ORDER BY discovered_time DESC"
        $command = $Script:DatabaseConnection.CreateCommand()
        $command.CommandText = $query
        $reader = $command.ExecuteReader()
        
        $rsvList = @()
        while ($reader.Read()) {
            $rsvList += [PSCustomObject]@{
                SubscriptionId = $reader["subscription_id"]
                SubscriptionName = $reader["subscription_name"]
                RSVName = $reader["rsv_name"]
                ResourceGroupName = $reader["resource_group_name"]
                Location = $reader["location"]
                DiscoveredTime = [DateTime]::Parse($reader["discovered_time"])
            }
        }
        $reader.Close()
        
        Write-RSVLog "从数据库读取RSV列表: $($rsvList.Count) 个" -Level "INFO"
        return $rsvList
    }
    catch {
        Write-RSVLog "读取RSV列表失败: $_" -Level "ERROR"
        return @()
    }
}

# 在测试脚本中使用缓存
if ($config.RSVList.Count -eq 0) {
    # 先初始化数据库连接
    $dbInitialized = Initialize-RSVDatabase -DatabasePath $config.DatabasePath
    if (-not $dbInitialized) {
        Write-Host "  数据库初始化失败" -ForegroundColor Red
        exit 1
    }
    
    # 先尝试从数据库读取RSV列表
    $dbRSVs = Get-RSVListFromDatabase
    
    if ($dbRSVs -and $dbRSVs.Count -gt 0) {
        $allRSVs = $dbRSVs
        Write-Host "  从数据库读取RSV列表: $($dbRSVs.Count) 个" -ForegroundColor Green
    }
    else {
        # 数据库中没有RSV列表，执行自动发现
        $allRSVs = @()
        
        foreach ($sub in $subscriptions) {
            # 切换到该订阅
            $null = Select-AzSubscription -SubscriptionId $sub.Id -ErrorAction SilentlyContinue
            
            # 获取该订阅下的所有RSV
            $rsvs = Get-AzRecoveryServicesVault -ErrorAction SilentlyContinue
            
            foreach ($rsv in $rsvs) {
                $allRSVs += @{
                    SubscriptionId = $sub.Id
                    SubscriptionName = $sub.Name
                    RSVName = $rsv.Name
                    ResourceGroupName = $rsv.ResourceGroupName
                    Location = $rsv.Location
                }
            }
        }
        
        Write-Host "  发现 $($allRSVs.Count) 个RSV" -ForegroundColor Green
        
        # 保存RSV列表到数据库
        $saved = Save-RSVListToDatabase -RSVList $allRSVs
        if ($saved) {
            Write-Host "  RSV列表已保存到数据库" -ForegroundColor Green
        }
    }
    
    # 关闭数据库连接
    Close-RSVDatabase
}
```

**预防措施**:
- ⚠️ **重要**: 使用数据库缓存RSV列表，避免重复发现
- 在读取RSV列表前先初始化数据库连接
- 支持增量更新，避免重复数据
- 在项目规范中明确使用缓存机制

**相关代码**: [Azure-RSV-Collector.psm1](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/Azure-RSV-Collector.psm1#L248-L418), [Test-RSV-Collector.ps1](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/test/Test-RSV-Collector.ps1#L141-L193)

---

### 7.11 读取RSV列表前数据库未初始化

**错误信息**:
```
[ERROR] 数据库连接未打开
```

**发生场景**: 尝试从数据库读取RSV列表时

**根本原因**: 
- 在读取RSV列表前未初始化数据库连接
- 数据库连接生命周期管理不当

**修正方案**:
```powershell
# 修改前
if ($config.RSVList.Count -eq 0) {
    Write-Host "  自动发现所有RSV..." -ForegroundColor Yellow
    
    # 先尝试从数据库读取RSV列表
    $dbRSVs = Get-RSVListFromDatabase  # ❌ 数据库未初始化
    
    if ($dbRSVs -and $dbRSVs.Count -gt 0) {
        $allRSVs = $dbRSVs
        Write-Host "  从数据库读取RSV列表: $($dbRSVs.Count) 个" -ForegroundColor Green
    }
}

# 修改后
if ($config.RSVList.Count -eq 0) {
    Write-Host "  自动发现所有RSV..." -ForegroundColor Yellow
    
    # 先初始化数据库连接
    $dbInitialized = Initialize-RSVDatabase -DatabasePath $config.DatabasePath
    if (-not $dbInitialized) {
        Write-Host "  数据库初始化失败" -ForegroundColor Red
        exit 1
    }
    
    # 先尝试从数据库读取RSV列表
    $dbRSVs = Get-RSVListFromDatabase  # ✅ 数据库已初始化
    
    if ($dbRSVs -and $dbRSVs.Count -gt 0) {
        $allRSVs = $dbRSVs
        Write-Host "  从数据库读取RSV列表: $($dbRSVs.Count) 个" -ForegroundColor Green
    }
    
    # ... 处理RSV列表 ...
    
    # 关闭数据库连接
    Close-RSVDatabase
}
```

**预防措施**:
- ⚠️ **重要**: 在读取数据库前必须先初始化数据库连接
- 明确数据库连接的生命周期
- 添加详细的错误日志
- 在代码审查时检查数据库操作顺序

**相关代码**: [Test-RSV-Collector.ps1](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/test/Test-RSV-Collector.ps1#L141-L147)

---

### 7.12 Set-AzRecoveryServicesAsrVaultContext缺少Vault参数

**错误信息**:
```
cmdlet Set-AzRecoveryServicesAsrVaultContext at command pipeline position 1
Supply values for the following parameters:
Vault:
```

**发生场景**: 采集Replicated Items时，设置ASR Vault上下文

**根本原因**: 
- Set-AzRecoveryServicesAsrVaultContext命令缺少必需的-Vault参数
- 使用了错误的参数组合（-DefaultProfile而不是-Vault）
- 参数类型不匹配（传递了Azure上下文对象而不是RSV对象）

**修正方案**:
```powershell
# 修改前
try {
    $context = Get-AzContext
    $null = Set-AzRecoveryServicesAsrVaultContext -DefaultProfile $context -ErrorAction SilentlyContinue
}
catch {
    Write-RSVLog "导入Vault设置失败: $_" -Level "WARNING"
}

# 修改后
try {
    $null = Set-AzRecoveryServicesAsrVaultContext -Vault $rsv -ErrorAction SilentlyContinue
}
catch {
    Write-RSVLog "导入Vault设置失败: $_" -Level "WARNING"
}
```

**预防措施**:
- ⚠️ **重要**: Set-AzRecoveryServicesAsrVaultContext必须使用-Vault参数，传递RSV对象
- 不要使用-DefaultProfile参数，这是错误的参数
- 在调用前确保已经获取了RSV对象
- 添加错误处理，避免因Vault上下文设置失败导致整个采集流程中断

**相关代码**: [Azure-RSV-Collector.psm1](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/Azure-RSV-Collector.psm1#L599-L606)

---

## 学习要点

1. **类型设计**: 使用`[object]`而不是具体类型，提高兼容性
2. **模块导出**: 确保所有公共函数都在Export-ModuleMember中声明
3. **编码规范**: 统一使用UTF-8 BOM编码，避免跨平台问题
4. **错误处理**: 使用try-catch块捕获异常，提供友好的错误信息
5. **用户体验**: 减少不必要的交互，提供清晰的提示信息
6. **性能优化**: 使用缓存、并发、批量操作提高性能
7. **代码审查**: 建立检查清单，确保代码质量
8. **SQLite操作**: 使用System.Data.SQLite程序集，避免使用SQLite模块命令
9. **Azure命令**: 确保所有必需参数都已提供，查看命令文档
10. **数据库连接**: 明确数据库连接的生命周期，在操作前检查连接状态
11. **CSV导出**: 使用UTF8BOM编码，确保中文正确显示
12. **缓存机制**: 使用数据库缓存避免重复操作，提高性能

---

## 版本历史

| 版本 | 日期 | 变更说明 | 作者 |
|------|------|---------|------|
| 1.0.0 | 2026-01-28 | 初始版本，记录开发过程中的错误和修正方案 | Azure DR Team |
| 1.1.0 | 2026-01-28 | 添加RSV采集错误记录（7.1-7.11） | Azure DR Team |
| 1.2.0 | 2026-01-28 | 添加Set-AzRecoveryServicesAsrVaultContext缺少Vault参数错误（7.12） | Azure DR Team |

---

## 联系信息

如有问题或建议，请联系：
- **项目团队**: Azure DR Team
- **文档位置**: `d:\UserProfiles\JoeHe\Codes\Azure-DR-Drill-Automation-Trae\docs\`

---

**文档最后更新**: 2026-01-28
