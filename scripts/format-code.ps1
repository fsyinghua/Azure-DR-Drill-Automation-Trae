# 代码格式化脚本
# 自动修复常见的代码质量问题

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "代码格式化" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$fixedFiles = 0
$fixedTrailingSpaces = 0

# 获取所有PowerShell文件
$ps1Files = Get-ChildItem -Path . -Filter "*.ps1" -Recurse | Where-Object { $_.FullName -notlike "*\node_modules\*" -and $_.FullName -notlike "*\.git\*" -and $_.FullName -notlike "*\cache\*" }
$psm1Files = Get-ChildItem -Path . -Filter "*.psm1" -Recurse | Where-Object { $_.FullName -notlike "*\node_modules\*" -and $_.FullName -notlike "*\.git\*" -and $_.FullName -notlike "*\cache\*" }

Write-Host "处理 $($ps1Files.Count + $psm1Files.Count) 个文件..." -ForegroundColor Yellow
Write-Host ""

foreach ($file in ($ps1Files + $psm1Files)) {
    $content = Get-Content $file.FullName -Raw -Encoding UTF8

    if (-not $content) {
        continue
    }

    $originalContent = $content

    # 修复尾随空格
    $lines = $content -split "`r?`n"
    $fixedLines = @()
    $fileFixed = $false

    foreach ($line in $lines) {
        $trimmedLine = $line -replace '\s+$', ''
        if ($trimmedLine -ne $line) {
            $fileFixed = $true
            $fixedTrailingSpaces++
        }
        $fixedLines += $trimmedLine
    }

    if ($fileFixed) {
        $newContent = $fixedLines -join "`r`n"

        # 确保文件以UTF-8 BOM编码保存
        $utf8BOM = New-Object System.Text.UTF8Encoding $true
        [System.IO.File]::WriteAllText($file.FullName, $newContent, $utf8BOM)

        Write-Host "  ✓ $($file.Name) - 修复尾随空格" -ForegroundColor Green
        $fixedFiles++
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "格式化完成" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "修复文件数: $fixedFiles" -ForegroundColor White
Write-Host "修复尾随空格: $fixedTrailingSpaces 行" -ForegroundColor White
Write-Host ""

if ($fixedFiles -gt 0) {
    Write-Host "✓ 代码格式化完成！" -ForegroundColor Green
}
else {
    Write-Host "✓ 没有需要修复的问题" -ForegroundColor Green
}

Write-Host ""
