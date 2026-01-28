# Azure PowerShell 开发规范

## 核心原则
1.  **防御性编程**：任何脚本都必须包含 `try-catch-finally` 块进行错误处理，并使用 `-ErrorAction Stop` 确保关键错误能被捕获。
2.  **参数完整性**：调用 `Get-AzVM`、`New-AzResourceGroup` 等cmdlet时，必须显式指定所有必需参数（如 `-ResourceGroupName`, `-Name`, `-Location`），禁止依赖管道传参。
3.  **资源存在性检查**：在执行创建或修改操作前，必须先使用 `Get-*` cmdlet检查资源是否存在。
4.  **代码审查**：任何生成的代码都必须附带一个简单的审查报告，说明：检查了哪些参数、如何处理错误、以及资源的依赖关系。

## 输出格式
*   所有注释和提示信息请使用中文。
*   为关键逻辑和参数添加简明中文注释。

## 工作流程规范

### 提交和推送流程
**每次代码提交后必须执行以下步骤：**

1. **更新相关文档**：
   - 如果修复了错误，更新 `docs/DEVELOPMENT-ERRORS.md`
   - 如果添加了新的开发规则，更新 `.trae/project-rules.md`
   - 如果有架构或功能变更，更新 `docs/PROJECT-CONTEXT.md`

2. **提交所有更改**：
   ```bash
   git add .
   git commit -m "提交信息"
   ```

3. **自动推送到远程仓库**：
   ```bash
   git push
   ```

**重要**：不要遗漏任何文档更新，确保代码和文档同步。