# Azure登录模块文档

## 概述

Azure登录模块（Azure-Login.psm1）提供统一的Azure认证管理功能，包括登录、状态检查、订阅选择和token缓存等核心功能。

## 功能特性

- ✅ Device Login认证方式（适配防火墙SSLO限制）
- ✅ 登录状态检查和显示
- ✅ 交互式订阅选择
- ✅ Token缓存机制
- ✅ 自动会话初始化
- ✅ 缓存清理功能

## 模块文件

- **文件名**: [Azure-Login.psm1](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/Azure-Login.psm1)
- **类型**: PowerShell模块
- **版本**: 1.0.0

## 核心函数

### 1. Test-AzureLoginStatus

检查当前Azure登录状态。

#### 语法
```powershell
Test-AzureLoginStatus
```

#### 返回值
返回一个包含登录状态信息的哈希表：

| 属性 | 类型 | 说明 |
|------|------|------|
| IsLoggedIn | Boolean | 是否已登录 |
| Account | String | 账户ID |
| SubscriptionId | String | 订阅ID |
| SubscriptionName | String | 订阅名称 |
| TenantId | String | 租户ID |
| Environment | String | 环境名称 |

#### 示例
```powershell
$status = Test-AzureLoginStatus
if ($status.IsLoggedIn) {
    Write-Host "已登录: $($status.Account)"
}
```

### 2. Invoke-AzureDeviceLogin

使用Device Login方式进行Azure认证。

#### 语法
```powershell
Invoke-AzureDeviceLogin
```

#### 返回值
- `$true`: 登录成功
- `$false`: 登录失败

#### 示例
```powershell
$result = Invoke-AzureDeviceLogin
if ($result) {
    Write-Host "登录成功!"
}
```

### 3. Select-AzureSubscription

选择或切换Azure订阅。

#### 语法
```powershell
Select-AzureSubscription [-SubscriptionId <string>] [-Interactive]
```

#### 参数
| 参数 | 类型 | 必需 | 说明 |
|------|------|--------|------|
| SubscriptionId | String | 否 | 目标订阅ID |
| Interactive | Switch | 否 | 启用交互式选择 |

#### 返回值
- `$true`: 选择成功
- `$false`: 选择失败

#### 示例
```powershell
# 直接指定订阅ID
Select-AzureSubscription -SubscriptionId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# 交互式选择
Select-AzureSubscription -Interactive
```

### 4. Initialize-AzureSession

初始化Azure会话，包括登录检查、订阅选择和token缓存。

#### 语法
```powershell
Initialize-AzureSession [-Config <hashtable>] [-TargetSubscriptionId <string>] [-ForceLogin] [-Interactive]
```

#### 参数
| 参数 | 类型 | 必需 | 说明 |
|------|------|--------|------|
| Config | Hashtable | 是 | 配置参数哈希表 |
| TargetSubscriptionId | String | 否 | 目标订阅ID |
| ForceLogin | Switch | 否 | 强制重新登录 |
| Interactive | Switch | 否 | 启用交互式模式 |

#### 返回值
返回一个包含会话信息的哈希表：

| 属性 | 类型 | 说明 |
|------|------|------|
| Success | Boolean | 是否成功 |
| Context | Object | Azure上下文对象 |
| Message | String | 状态消息 |

#### 示例
```powershell
$config = @{
    EnableTokenCache = $true
    TokenCacheExpiryMinutes = 60
}

$session = Initialize-AzureSession -Config $config -Interactive
if ($session.Success) {
    Write-Host "会话初始化成功"
}
```

### 5. Clear-AzureLoginCache

清除Azure登录缓存。

#### 语法
```powershell
Clear-AzureLoginCache
```

#### 返回值
- `$true`: 清除成功
- `$false`: 清除失败或缓存不存在

#### 示例
```powershell
Clear-AzureLoginCache
```

### 6. Show-AzureLoginStatus

显示当前Azure登录状态的详细信息。

#### 语法
```powershell
Show-AzureLoginStatus
```

#### 示例
```powershell
Show-AzureLoginStatus
```

#### 输出示例
```
========================================
Azure登录状态
========================================

状态: 已登录
账户: user@example.com
订阅: Production Subscription
订阅ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
租户ID: yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy
环境: AzureCloud
缓存过期时间: 2026-01-27 15:30:00
剩余时间: 00:45:00

========================================
```

## 使用场景

### 场景1：首次登录

```powershell
Import-Module ".\Azure-Login.psm1"

# 检查登录状态
$status = Test-AzureLoginStatus
if (-not $status.IsLoggedIn) {
    # 执行登录
    Invoke-AzureDeviceLogin
}

# 显示登录状态
Show-AzureLoginStatus
```

### 场景2：使用token缓存

```powershell
$config = @{
    EnableTokenCache = $true
    TokenCacheExpiryMinutes = 60
}

# 初始化会话（自动使用缓存）
$session = Initialize-AzureSession -Config $config
```

### 场景3：切换订阅

```powershell
# 方式1：直接指定订阅ID
Select-AzureSubscription -SubscriptionId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# 方式2：交互式选择
Select-AzureSubscription -Interactive
```

### 场景4：强制重新登录

```powershell
$config = @{
    EnableTokenCache = $true
    TokenCacheExpiryMinutes = 60
}

# 强制重新登录（忽略缓存）
$session = Initialize-AzureSession -Config $config -ForceLogin -Interactive
```

### 场景5：清除缓存

```powershell
# 清除登录缓存
Clear-AzureLoginCache

# 重新登录
Invoke-AzureDeviceLogin
```

## Token缓存机制

### 缓存文件

- **路径**: `.\cache\azure-login-cache.json`
- **格式**: JSON

### 缓存内容

```json
{
  "AccountId": "user@example.com",
  "TenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "SubscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "SubscriptionName": "Production Subscription",
  "Environment": "AzureCloud",
  "ExpiresOn": "2026-01-27T15:30:00.0000000+08:00",
  "CachedAt": "2026-01-27T14:30:00.0000000+08:00"
}
```

### 缓存策略

1. **首次登录**: 保存登录信息到缓存
2. **后续执行**: 检查缓存是否有效
3. **过期检查**: 剩余时间 < 5分钟时发出警告
4. **自动清理**: 过期后自动删除缓存

### 配置参数

在config.txt中配置：

```ini
# 启用Token缓存
EnableTokenCache=true

# Token缓存过期时间（分钟）
TokenCacheExpiryMinutes=60
```

## 集成到脚本

### 在Start-DRDrill.ps1中使用

```powershell
# 导入登录模块
Import-Module ".\Azure-Login.psm1" -Force

# 读取配置
$config = Get-Content "config.txt" | ...

# 初始化会话
$session = Initialize-AzureSession -Config $configHashTable -Interactive

if ($session.Success) {
    # 继续执行DR演练
}
```

### 在Azure-DR-Drill.ps1中使用

```powershell
# 导入登录模块
Import-Module ".\Azure-Login.psm1" -Force

# 初始化会话
$session = Initialize-AzureSession -Config $script:Config

if ($session.Success) {
    # 执行DR演练
}
```

## 错误处理

### 常见错误

#### 1. 模块导入失败

**错误信息**:
```
导入登录模块失败: The term 'Import-Module' is not recognized
```

**解决方案**:
```powershell
# 确保使用PowerShell 5.1或更高版本
$PSVersionTable.PSVersion

# 检查模块文件是否存在
Test-Path ".\Azure-Login.psm1"
```

#### 2. 登录失败

**错误信息**:
```
登录失败: Connect-AzAccount: The user has not been authenticated
```

**解决方案**:
```powershell
# 检查网络连接
Test-NetConnection -ComputerName login.microsoftonline.com -Port 443

# 清除缓存后重试
Clear-AzureLoginCache
Invoke-AzureDeviceLogin
```

#### 3. 订阅切换失败

**错误信息**:
```
选择订阅失败: Subscription 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' not found
```

**解决方案**:
```powershell
# 列出所有订阅
Get-AzSubscription

# 检查订阅ID是否正确
Select-AzureSubscription -Interactive
```

## 最佳实践

1. **使用Token缓存**
   - 推荐启用以减少认证次数
   - 根据执行频率调整过期时间

2. **交互式模式**
   - 首次使用时启用交互式模式
   - 便于选择正确的订阅

3. **错误处理**
   - 始终检查函数返回值
   - 提供清晰的错误消息

4. **日志记录**
   - 记录登录状态变化
   - 记录订阅切换操作

5. **缓存管理**
   - 定期清理过期缓存
   - 不要共享缓存文件

## 安全考虑

1. **缓存文件安全**
   - 缓存包含敏感信息
   - 设置适当的文件权限
   - 不要提交到版本控制

2. **认证安全**
   - 使用Device Login方式
   - 避免在脚本中硬编码凭据
   - 定期更换密码

3. **网络安全**
   - 确保网络连接安全
   - 使用HTTPS端点
   - 避免在公共网络执行

## 相关文档

- [TOKEN_CACHE.md](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/TOKEN_CACHE.md) - Token缓存机制详细说明
- [需求参数.txt](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/需求参数.txt) - 配置参数说明
- [README.md](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/README.md) - 项目使用指南

## 版本历史

| 版本 | 日期 | 变更说明 |
|------|------|---------|
| 1.0.0 | 2026-01-27 | 初始版本，实现核心登录功能 |