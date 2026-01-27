# Token缓存机制说明

## 概述

Token缓存机制用于缓存Azure认证token，避免在频繁执行脚本时重复进行device login认证。此功能特别适用于需要多次执行DR演练的场景。

## 功能特性

- ✅ 自动缓存Azure认证token
- ✅ 检查token是否过期
- ✅ 过期前5分钟提示重新认证
- ✅ 可配置缓存过期时间
- ✅ 支持禁用缓存功能
- ✅ 安全的本地存储（JSON格式）

## 配置参数

在 [config.txt](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/config.txt) 中配置以下参数：

```ini
# 启用Token缓存（推荐）
EnableTokenCache=true

# Token缓存过期时间（分钟）
TokenCacheExpiryMinutes=60
```

### 参数说明

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| EnableTokenCache | Boolean | true | 是否启用token缓存 |
| TokenCacheExpiryMinutes | Integer | 60 | token缓存过期时间（分钟） |

## 工作原理

### 1. 首次认证

```powershell
# 用户执行device login
Connect-AzAccount -UseDeviceAuthentication

# 脚本检测到Azure连接，保存token到缓存
# 缓存文件: .\cache\azure-token-cache.json
```

### 2. 后续执行

```powershell
# 脚本启动时检查缓存
# 如果缓存存在且未过期，直接使用缓存的token
# 如果缓存过期，提示用户重新认证
```

### 3. Token过期检查

- 检查缓存的过期时间
- 如果剩余时间 < 5分钟，发出警告
- 如果已过期，删除缓存并提示重新认证

## 缓存文件结构

Token缓存保存在 `.\cache\azure-token-cache.json`，格式如下：

```json
{
  "AccountId": "user@example.com",
  "TenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "SubscriptionId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "AccessToken": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "ExpiresOn": "2026-01-27T15:30:00.0000000+08:00",
  "CachedAt": "2026-01-27T14:30:00.0000000+08:00"
}
```

## 使用场景

### 场景1：单次执行DR演练

```powershell
# 首次执行，需要认证
.\Start-DRDrill.ps1
# 提示: Connect-AzAccount -UseDeviceAuthentication

# 执行DR演练
```

### 场景2：多次执行DR演练

```powershell
# 第一次执行
.\Start-DRDrill.ps1
# 需要认证: Connect-AzAccount -UseDeviceAuthentication
# Token已缓存

# 第二次执行（1小时内）
.\Start-DRDrill.ps1
# 使用缓存的token，无需重新认证

# 第三次执行（1小时后）
.\Start-DRDrill.ps1
# Token已过期，提示重新认证
```

### 场景3：禁用Token缓存

如果需要每次都重新认证，可以禁用缓存：

```ini
# config.txt
EnableTokenCache=false
```

## 核心函数

### Get-TokenCacheFilePath

获取token缓存文件路径。

```powershell
$cachePath = Get-TokenCacheFilePath
# 返回: .\cache\azure-token-cache.json
```

### Save-TokenCache

保存Azure上下文到缓存文件。

```powershell
Save-TokenCache -Context $context -TokenExpiryMinutes 60
```

**参数**:
- `Context`: Azure上下文对象
- `TokenExpiryMinutes`: token过期时间（分钟）

### Get-TokenCache

读取并验证token缓存。

```powershell
$cacheData = Get-TokenCache
```

**返回值**:
- 如果缓存有效：返回缓存数据对象
- 如果缓存无效或不存在：返回 `$null`

### Test-TokenValid

检查token是否仍然有效。

```powershell
$isValid = Test-TokenValid -Config $script:Config
```

**返回值**:
- `$true`: token有效（剩余时间 > 5分钟）
- `$false`: token无效或即将过期

## 日志输出

### Token缓存成功

```
[2026-01-27 14:30:00] [INFO] Token cache saved. Expires at: 2026-01-27T15:30:00.0000000+08:00
```

### Token缓存有效

```
[2026-01-27 14:45:00] [INFO] Token cache found and valid. Expires in: 00:45:00
[2026-01-27 14:45:00] [INFO] Cached token is valid. Time remaining: 00:45:00
```

### Token即将过期

```
[2026-01-27 15:26:00] [INFO] Token cache found and valid. Expires in: 00:04:00
[2026-01-27 15:26:00] [WARNING] Cached token is expiring soon (4 minutes remaining). Re-authentication recommended.
```

### Token已过期

```
[2026-01-27 15:35:00] [INFO] Token cache expired. Cached at: 2026-01-27T14:30:00.0000000+08:00, Expired at: 2026-01-27T15:30:00.0000000+08:00
```

## 安全考虑

### 1. 缓存文件权限

- 缓存文件保存在本地 `.\cache` 目录
- 建议设置适当的文件权限，限制访问

### 2. 敏感信息

- 缓存文件包含访问token，请妥善保管
- 不要将缓存文件提交到版本控制系统
- 定期清理过期的缓存文件

### 3. 清除缓存

如需清除缓存：

```powershell
# 删除缓存目录
Remove-Item -Path ".\cache" -Recurse -Force

# 或删除特定缓存文件
Remove-Item -Path ".\cache\azure-token-cache.json" -Force
```

## 故障排查

### 问题1：缓存文件损坏

**症状**:
```
[ERROR] Failed to read token cache: Invalid JSON
```

**解决方案**:
```powershell
# 删除缓存文件
Remove-Item -Path ".\cache\azure-token-cache.json" -Force
# 重新认证
Connect-AzAccount -UseDeviceAuthentication
```

### 问题2：Token频繁过期

**症状**: 每次执行都提示重新认证

**解决方案**:
- 增加 `TokenCacheExpiryMinutes` 值（如120分钟）
- 检查Azure AD token策略
- 确认网络连接稳定

### 问题3：缓存未生效

**症状**: 缓存已保存但仍提示重新认证

**解决方案**:
- 检查 `EnableTokenCache=true` 是否设置
- 查看日志确认缓存是否成功保存
- 确认缓存文件路径正确

## 最佳实践

1. **启用Token缓存**
   - 推荐在大多数场景下启用
   - 可显著减少认证次数

2. **合理设置过期时间**
   - 根据执行频率调整
   - 建议60-120分钟

3. **定期清理缓存**
   - 删除过期的缓存文件
   - 保持缓存目录整洁

4. **监控日志**
   - 关注token过期警告
   - 及时重新认证

5. **安全存储**
   - 不要共享缓存文件
   - 定期更换密码

## 相关文档

- [需求参数.txt](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/需求参数.txt) - 完整参数说明
- [README.md](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/README.md) - 使用指南
- [Azure-DR-Drill.ps1](file:///d:/UserProfiles/JoeHe/Codes/Azure-DR-Drill-Automation-Trae/Azure-DR-Drill.ps1) - 主脚本

## 版本历史

| 版本 | 日期 | 变更说明 |
|------|------|---------|
| 1.0.0 | 2026-01-27 | 初始版本 |