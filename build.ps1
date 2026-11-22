# ============================================================================
#  build.ps1 - Ghep src/*.ps1 thanh MOT file dist/WinCare.ps1 (spec 2.7)
#  - UTF-8 KHONG BOM, khong dot-source, XAML/style nhung
#  - Thay __BUILD_HASH__ bang 8 ky tu dau SHA-256 cua noi dung nguon
#  - Parse check + quet chuoi cam sau khi ghep
#  Chay duoc ca tren Windows PowerShell 5.1 va pwsh 7 (Linux/Mac).
#  Cach dung:  .\build.ps1 [-SkipParse]
# ============================================================================
param([switch]$SkipParse)

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$srcDir = Join-Path $root 'src'
$distDir = Join-Path $root 'dist'
if (-not (Test-Path -LiteralPath $distDir)) { New-Item -Path $distDir -ItemType Directory -Force | Out-Null }

# 1) Doc cac file nguon theo thu tu ten (00-Boot -> 21-Main)
$files = @(Get-ChildItem -Path $srcDir -Filter '*.ps1' | Sort-Object Name)
if ($files.Count -eq 0) { throw 'Khong tim thay src/*.ps1' }

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$parts = New-Object System.Text.StringBuilder
foreach ($f in $files) {
    # Doc that carefully: bo BOM neu co
    $text = [IO.File]::ReadAllText($f.FullName)
    if ($text.Length -gt 0 -and [int][char]$text[0] -eq 0xFEFF) { $text = $text.Substring(1) }
    $null = $parts.AppendLine('')
    $null = $parts.AppendLine('# ' + ('=' * 76))
    $null = $parts.AppendLine('# REGION: ' + $f.Name)
    $null = $parts.AppendLine('# ' + ('=' * 76))
    $null = $parts.AppendLine('')
    $null = $parts.Append($text)
    $null = $parts.AppendLine('')
}
$body = $parts.ToString()

# 2) Build hash = 8 ky tu dau SHA-256 cua noi dung (voi placeholder)
$sha = [System.Security.Cryptography.SHA256]::Create()
$bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
$hashBytes = $sha.ComputeHash($bytes)
$sha.Dispose()
$fullHash = ([BitConverter]::ToString($hashBytes)).Replace('-', '').ToLowerInvariant()
$buildHash = $fullHash.Substring(0, 8)

# 3) Banner + thay the placeholder
$banner = @'
# ==============================================================================
#   WinCare - Trinh toi uu & kiem tra Windows (tieng Viet)
#   Mot file PowerShell duy nhat. Chay:  irm <URL> | iex   (can Admin, WPF)
#   Ma nguon: src/*.ps1 -> build.ps1 -> dist/WinCare.ps1
#   Khong telemetry. Quet chi doc. Moi thay doi can xac nhan + nhat ky hoan tac.
# ==============================================================================
'@
$out = $banner + "`r`n" + $body.Replace('__BUILD_HASH__', $buildHash)

# 4) Ghi file UTF-8 KHONG BOM (spec 2.1)
$outPath = Join-Path $distDir 'WinCare.ps1'
[IO.File]::WriteAllText($outPath, $out, $utf8NoBom)

# Kiem tra lai khong con BOM, khong con placeholder
$raw = [IO.File]::ReadAllBytes($outPath)
if ($raw.Length -ge 3 -and $raw[0] -eq 0xEF -and $raw[1] -eq 0xBB -and $raw[2] -eq 0xBF) {
    throw 'LOI: dist/WinCare.ps1 co BOM!'
}
$checkText = [IO.File]::ReadAllText($outPath)
if ($checkText -like '*__BUILD_HASH__*') { throw 'LOI: con placeholder __BUILD_HASH__' }

# 5) Parse check file ghep (spec 2.7 - bat buoc)
if (-not $SkipParse) {
    $tokens = $null; $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($outPath, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) {
        foreach ($e in $errors) { Write-Output ('  dong ' + $e.Extent.StartLineNumber + ': ' + $e.Message) }
        throw ('LOI PARSE dist/WinCare.ps1: ' + $errors.Count + ' loi')
    }
    # Quet chuoi cam (spec 2.7)
    foreach ($pat in @('Win32_Product', '-EncodedCommand', 'Add-MpPreference')) {
        if ($checkText -like ('*' + $pat + '*')) { throw ('LOI: dist chua chuoi cam: ' + $pat) }
    }
}

# 6) SHA-256 cuoi + thong tin build cho landing page/API
$sha2 = [System.Security.Cryptography.SHA256]::Create()
$finalHashBytes = $sha2.ComputeHash([IO.File]::ReadAllBytes($outPath))
$sha2.Dispose()
$finalHash = ([BitConverter]::ToString($finalHashBytes)).Replace('-', '').ToLowerInvariant()
[IO.File]::WriteAllText((Join-Path $distDir 'WinCare.ps1.sha256'), ($finalHash + '  WinCare.ps1' + [Environment]::NewLine), $utf8NoBom)

$lineCount = (@($checkText -split "`n")).Count
$buildInfo = @{
    name = 'WinCare'
    version = '1.0.1'
    build = $buildHash
    sha256 = $finalHash
    sizeBytes = $raw.Length
    lineCount = $lineCount
    builtAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    sourceFiles = @($files | ForEach-Object { $_.Name })
}
[IO.File]::WriteAllText((Join-Path $distDir 'build-info.json'), (ConvertTo-Json $buildInfo -Depth 4), $utf8NoBom)

Write-Output ('BUILD OK: ' + $outPath)
Write-Output ('  size      : ' + $raw.Length + ' bytes')
Write-Output ('  lines     : ' + $lineCount)
Write-Output ('  build     : ' + $buildHash)
Write-Output ('  sha256    : ' + $finalHash)
Write-Output ('  BOM       : khong (OK)')
Write-Output ('  parse     : OK (0 loi)')
