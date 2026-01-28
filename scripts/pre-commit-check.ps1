# Pre-commit检查脚本
# 用于在提交代码前自动检查代码质量

param(
    [switch]$Verbose
)

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Pre-commit代码检查" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$errors = 0
$warnings = 0

# 1. 检查文件编码
Write-Host "检查1: 文件编码..." -ForegroundColor Yellow
$ps1Files = Get-ChildItem -Path . -Filter "*.ps1" -Recurse | Where-Object { $_.FullName -notlike "*\node_modules\*" -and $_.FullName -notlike "*\.git\*" }
$psm1Files = Get-ChildItem -Path . -Filter "*.psm1" -Recurse | Where-Object { $_.FullName -notlike "*\node_modules\*" -and $_.FullName -notlike "*\.git\*" }

$encodingErrors = 0
foreach ($file in ($ps1Files + $psm1Files)) {
    $content = Get-Content $file.FullName -Raw -Encoding Byte -ErrorAction SilentlyContinue
    if ($content -and $content.Count -ge 3) {
        if ($content[0] -ne 0xEF -or $content[1] -ne 0xBB -or $content[2] -ne 0xBF) {
            Write-Host "  ✗ $($file.FullName) 未使用UTF-8 BOM编码" -ForegroundColor Red
            $encodingErrors++
            $errors++
        }
    }
}

if ($encodingErrors -eq 0) {
    Write-Host "  ✓ 所有PowerShell文件编码正确" -ForegroundColor Green
} else {
    Write-Host "  发现 $encodingErrors 个编码错误" -ForegroundColor Red
}

# 2. 检查语法错误
Write-Host ""
Write-Host "检查2: 语法错误..." -ForegroundColor Yellow
$syntaxErrors = 0
foreach ($file in ($ps1Files + $psm1Files)) {
    try {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)
        if ($ast.ParseErrors.Count -gt 0) {
            Write-Host "  ✗ $($file.FullName) 存在语法错误" -ForegroundColor Red
            $ast.ParseErrors | ForEach-Object {
                Write-Host "    行 $($_.Extent.StartLineNumber): $($_.Message)" -ForegroundColor Yellow
            }
            $syntaxErrors++
            $errors++
        }
    }
    catch {
        Write-Host "  ✗ $($file.FullName) 语法检查失败: $_" -ForegroundColor Red
        $syntaxErrors++
        $errors++
    }
}

if ($syntaxErrors -eq 0) {
    Write-Host "  ✓ 所有文件语法正确" -ForegroundColor Green
} else {
    Write-Host "  发现 $syntaxErrors 个语法错误" -ForegroundColor Red
}

# 3. 检查模块导出
Write-Host ""
Write-Host "检查3: 模块导出..." -ForegroundColor Yellow
$exportErrors = 0
foreach ($file in $psm1Files) {
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
    if ($content -notmatch 'Export-ModuleMember') {
        Write-Host "  ✗ $($file.FullName) 未找到Export-ModuleMember" -ForegroundColor Yellow
        $exportErrors++
        $warnings++
    }
}

if ($exportErrors -eq 0) {
    Write-Host "  ✓ 所有模块导出正确" -ForegroundColor Green
} else {
    Write-Host "  发现 $exportErrors 个导出警告" -ForegroundColor Yellow
}

# 4. 检查敏感信息
Write-Host ""
Write-Host "检查4: 敏感信息..." -ForegroundColor Yellow
$sensitivePatterns = @(
    "password\s*=\s*[`"'].*[`"']",
    "secret\s*=\s*[`"'].*[`"']",
    "token\s*=\s*[`"'].*[`"']",
    "apikey\s*=\s*[`"'].*[`"']",
    "credential\s*=\s*[`"'].*[`"']"
)

$sensitiveErrors = 0
$allFiles = Get-ChildItem -Path . -Include "*.ps1","*.psm1","*.txt","*.json","*.yml","*.yaml" -Recurse | 
    Where-Object { $_.FullName -notlike "*\node_modules\*" -and $_.FullName -notlike "*\.git\*" -and $_.FullName -notlike "*\cache\*" }

foreach ($file in $allFiles) {
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
    if ($content) {
        foreach ($pattern in $sensitivePatterns) {
            if ($content -match $pattern) {
                Write-Host "  ⚠ $($file.FullName) 可能包含敏感信息" -ForegroundColor Yellow
                $sensitiveErrors++
                $warnings++
                break
            }
        }
    }
}

if ($sensitiveErrors -eq 0) {
    Write-Host "  ✓ 未发现敏感信息" -ForegroundColor Green
} else {
    Write-Host "  发现 $sensitiveErrors 个敏感信息警告" -ForegroundColor Yellow
}

# 5. 检查参数类型
Write-Host ""
Write-Host "检查5: 参数类型..." -ForegroundColor Yellow
$paramTypeErrors = 0
foreach ($file in ($ps1Files + $psm1Files)) {
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
    if ($content) {
        # 检查是否使用了过于具体的参数类型
        if ($content -match '\[hashtable\]\s*\$Context') {
            Write-Host "  ⚠ $($file.FullName) 参数类型可能过窄，考虑使用[object]" -ForegroundColor Yellow
            $paramTypeErrors++
            $warnings++
        }
    }
}

if ($paramTypeErrors -eq 0) {
    Write-Host "  ✓ 参数类型检查通过" -ForegroundColor Green
} else {
    Write-Host "  发现 $paramTypeErrors 个参数类型警告" -ForegroundColor Yellow
}

# 6. 检查错误处理
Write-Host ""
Write-Host "检查6: 错误处理..." -ForegroundColor Yellow
$errorHandlingWarnings = 0
foreach ($file in ($ps1Files + $psm1Files)) {
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
    if ($content) {
        # 检查是否有Azure命令但没有try-catch
        $hasAzureCmd = $content -match '(Get-Az|Set-Az|New-Az|Remove-Az|Connect-Az|Select-Az)'
        $hasTryCatch = $content -match 'try\s*\{'
        
        if ($hasAzureCmd -and -not $hasTryCatch) {
            Write-Host "  ⚠ $($file.FullName) 包含Azure命令但缺少try-catch块" -ForegroundColor Yellow
            $errorHandlingWarnings++
            $warnings++
        }
    }
}

if ($errorHandlingWarnings -eq 0) {
    Write-Host "  ✓ 错误处理检查通过" -ForegroundColor Green
} else {
    Write-Host "  发现 $errorHandlingWarnings 个错误处理警告" -ForegroundColor Yellow
}

# 7. 检查函数注释
Write-Host ""
Write-Host "检查7: 函数注释..." -ForegroundColor Yellow
$commentWarnings = 0
foreach ($file in ($ps1Files + $psm1Files)) {
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
    if ($content) {
        # 检查是否有函数但没有注释
        $functionMatches = [regex]::Matches($content, 'function\s+(\w+)')
        if ($functionMatches.Count -gt 0) {
            foreach ($match in $functionMatches) {
                $functionName = $match.Groups[1].Value
                if ($functionName -notmatch '^Write-' -and $functionName -notmatch '^Test-') {
                    # 检查函数前是否有注释
                    $functionIndex = $content.IndexOf("function $functionName")
                    $beforeFunction = $content.Substring([Math]::Max(0, $functionIndex - 500))
                    if ($beforeFunction -notmatch '<#|^\s*#') {
                        Write-Host "  ⚠ $($file.FullName) 函数 $functionName 缺少注释" -ForegroundColor Yellow
                        $commentWarnings++
                        $warnings++
                    }
                }
            }
        }
    }
}

if ($commentWarnings -eq 0) {
    Write-Host "  ✓ 函数注释检查通过" -ForegroundColor Green
} else {
    Write-Host "  发现 $commentWarnings 个注释警告" -ForegroundColor Yellow
}

# 8. 检查尾随空格
Write-Host ""
Write-Host "检查8: 尾随空格..." -ForegroundColor Yellow
$trailingSpaceErrors = 0
foreach ($file in ($ps1Files + $psm1Files)) {
    $lines = Get-Content $file.FullName -ErrorAction SilentlyContinue
    $lineNumber = 0
    foreach ($line in $lines) {
        $lineNumber++
        if ($line -match '\s+$') {
            Write-Host "  ⚠ $($file.FullName):$lineNumber 存在尾随空格" -ForegroundColor Yellow
            $trailingSpaceErrors++
            $warnings++
        }
    }
}

if ($trailingSpaceErrors -eq 0) {
    Write-Host "  ✓ 未发现尾随空格" -ForegroundColor Green
} else {
    Write-Host "  发现 $trailingSpaceErrors 个尾随空格警告" -ForegroundColor Yellow
}

# 汇总结果
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "检查结果汇总" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($errors -eq 0 -and $warnings -eq 0) {
    Write-Host "✓ 所有检查通过！" -ForegroundColor Green
    Write-Host ""
    exit 0
}
else {
    if ($errors -gt 0) {
        Write-Host "✗ 发现 $errors 个错误" -ForegroundColor Red
    }
    if ($warnings -gt 0) {
        Write-Host "⚠ 发现 $warnings 个警告" -ForegroundColor Yellow
    }
    Write-Host ""
    
    if ($errors -gt 0) {
        Write-Host "请修复错误后再提交代码" -ForegroundColor Red
        exit 1
    }
    else {
        Write-Host "建议修复警告后再提交代码" -ForegroundColor Yellow
        exit 0
    }
}
