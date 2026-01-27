# 测试目录

本目录包含用于测试Azure登录模块的测试脚本。

## 测试脚本

### Test-LoginModule.ps1

完整的登录模块测试脚本，包含以下功能：
- 检查Azure PowerShell模块
- 导入登录模块
- 检查登录状态
- 初始化Azure会话（支持token缓存）
- 获取并显示所有订阅
- 显示详细登录状态

**使用方法**：
```powershell
.\test\Test-LoginModule.ps1
```

**注意**：此脚本会尝试自动安装Azure PowerShell模块（如果未安装）并执行完整的登录流程。

### Test-LoginModule-Simple.ps1

简化的登录模块测试脚本，专注于：
- 导入登录模块
- 检查登录状态
- 获取并显示所有订阅
- 显示详细登录状态

**使用方法**：
```powershell
.\test\Test-LoginModule-Simple.ps1
```

**注意**：此脚本不会尝试登录Azure，仅测试已登录状态和获取订阅列表。

## 测试场景

### 场景1：未登录状态

```powershell
# 运行简化测试脚本
.\test\Test-LoginModule-Simple.ps1

# 预期输出：
# - 当前登录状态: 未登录
# - 提示使用 Connect-AzAccount -UseDeviceAuthentication 登录
```

### 场景2：已登录状态

```powershell
# 先登录Azure
Connect-AzAccount -UseDeviceAuthentication

# 运行测试脚本
.\test\Test-LoginModule-Simple.ps1

# 预期输出：
# - 当前登录状态: 已登录
# - 显示所有订阅列表
# - 显示当前订阅信息
```

### 场景3：完整测试

```powershell
# 运行完整测试脚本（会尝试自动登录）
.\test\Test-LoginModule.ps1

# 预期输出：
# - 检查并安装Azure PowerShell模块
# - 导入登录模块
# - 初始化Azure会话（如果未登录会提示登录）
# - 显示所有订阅
# - 显示详细登录状态
```

## 预期输出示例

### 未登录状态

```
========================================
Azure登录模块测试
========================================

步骤 1: 导入登录模块...
  模块路径: D:\UserProfiles\JoeHe\Codes\Azure-DR-Drill-Automation-Trae\Azure-Login.psm1
  登录模块导入成功

步骤 2: 检查登录状态...
  当前登录状态: 未登录

步骤 3: 获取所有订阅...
  未找到任何订阅

提示: 请先使用以下命令登录Azure:
  Connect-AzAccount -UseDeviceAuthentication

========================================
测试完成!
========================================
```

### 已登录状态

```
========================================
Azure登录模块测试
========================================

步骤 1: 导入登录模块...
  模块路径: D:\UserProfiles\JoeHe\Codes\Azure-DR-Drill-Automation-Trae\Azure-Login.psm1
  登录模块导入成功

步骤 2: 检查登录状态...
  当前登录状态: 已登录
    账户: user@example.com
    订阅: Production Subscription
    订阅ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    租户: yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy
    环境: AzureCloud

步骤 3: 获取所有订阅...

========================================
Azure订阅列表
========================================

[1] Production Subscription [当前]
    ID: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
    租户ID: yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy
    状态: Enabled
    主租户ID: yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy

[2] Development Subscription
    ID: zzzzzzzz-zzzz-zzzz-zzzz-zzzzzzzzzzzzz
    租户ID: yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy
    状态: Enabled
    主租户ID: yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy

========================================
总计: 2 个订阅
========================================

步骤 4: 显示详细登录状态...

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

========================================
测试完成!
========================================
```

## 故障排查

### 问题1：模块导入失败

**错误信息**：
```
导入登录模块失败: The specified module 'Azure-Login.psm1' was not found
```

**解决方案**：
- 确认脚本在正确的目录下运行
- 检查Azure-Login.psm1文件是否存在

### 问题2：Azure PowerShell模块未安装

**错误信息**：
```
获取订阅失败: The term 'Get-AzSubscription' is not recognized
```

**解决方案**：
```powershell
# 安装Azure PowerShell模块
Install-Module -Name Az -AllowClobber -Scope CurrentUser -Force
```

### 问题3：未登录Azure

**错误信息**：
```
未找到任何订阅
```

**解决方案**：
```powershell
# 使用Device Login方式登录
Connect-AzAccount -UseDeviceAuthentication
```

## 相关文档

- [Azure-Login.psm1](../Azure-Login.psm1) - Azure登录模块
- [LOGIN_MODULE.md](../LOGIN_MODULE.md) - 登录模块详细文档
- [TOKEN_CACHE.md](../TOKEN_CACHE.md) - Token缓存机制说明

## 版本历史

| 版本 | 日期 | 变更说明 |
|------|------|---------|
| 1.0.0 | 2026-01-27 | 初始版本，创建测试脚本 |