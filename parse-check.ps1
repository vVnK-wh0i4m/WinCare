# Parse-check tat ca file src + dist (chay duoc ca tren pwsh Linux - spec 2.7)
param([string]$Path = (Join-Path $PSScriptRoot 'src'))
$files = @(Get-ChildItem -Path $Path -Filter '*.ps1' | Sort-Object Name)
if ($files.Count -eq 0) { Write-Output 'KHONG TIM THAY FILE NAO'; exit 1 }
$fail = 0
foreach ($f in $files) {
    $tokens = $null; $errors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) {
        $fail++
        Write-Output ('FAIL ' + $f.Name)
        foreach ($e in $errors) {
            Write-Output ('   dong ' + $e.Extent.StartLineNumber + ': ' + $e.Message)
        }
    } else {
        Write-Output ('OK   ' + $f.Name + ' (' + (Get-Item $f.FullName).Length + ' bytes)')
    }
}
# Quet chuoi cam (spec 2.7)
$forbidden = @('Win32_Product', '-EncodedCommand', 'Add-MpPreference')
foreach ($f in $files) {
    $content = Get-Content -Raw $f.FullName
    foreach ($pat in $forbidden) {
        if ($content -like ('*' + $pat + '*')) {
            $fail++
            Write-Output ('CAM ' + $f.Name + ': chua "' + $pat + '"')
        }
    }
    # Kiem tra mau than PS5.1: &&, ||, ??, ternary (dang token rieng)
    $tokens = $null; $errs = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errs)
    foreach ($tk in $tokens) {
        $txt = $tk.Text
        if ($txt -eq '&&' -or $txt -eq '||' -or $txt -eq '??') {
            $fail++
            Write-Output ('CAM ' + $f.Name + ': dong ' + $tk.Extent.StartLineNumber + ' toan tu khong ho tro PS5.1: ' + $txt)
        }
    }
}
if ($fail -eq 0) { Write-Output '== TAT CA PASS ==' ; exit 0 } else { Write-Output ('== ' + $fail + ' FILE CO LOI ==') ; exit 1 }
