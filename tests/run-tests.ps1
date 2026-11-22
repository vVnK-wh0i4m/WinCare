# ============================================================================
#  run-tests.ps1 - Chay toan bo kiem chung cua du an WinCare
#  1) parse-check (tat ca src + dist)     2) Pester logic thuan
#  3) smoke test M6 cua module owner
#  Chay:  pwsh -NoProfile -File ./tests/run-tests.ps1
#  (pwsh 7 tren bat ky nen tang nao; Windows PowerShell khong duoc ho tro)
# ============================================================================
param([switch]$SkipPester)

$root = Split-Path -Parent $PSScriptRoot
$fail = 0

Write-Output '======================================================'
Write-Output ' 1) PARSE CHECK + QUET CHUOI CAM (src + dist)'
Write-Output '======================================================'
& (Join-Path $root 'parse-check.ps1')
if ($LASTEXITCODE -ne 0) { $fail++ }

Write-Output ''
Write-Output '======================================================'
Write-Output ' 2) BUILD LAI DIST (dam ban moi nhat)'
Write-Output '======================================================'
& (Join-Path $root 'build.ps1')
if ($LASTEXITCODE -ne 0) { $fail++ }

if (-not $SkipPester) {
    Write-Output ''
    Write-Output '======================================================'
    Write-Output ' 3) PESTER - LOGIC THUAN (chay duoc tren Linux)'
    Write-Output '======================================================'
    $pester = Get-Module -ListAvailable -Name Pester | Sort-Object Version -Descending | Select-Object -First 1
    if ($pester -and $pester.Version.Major -ge 5) {
        $cfg = New-PesterConfiguration
        $cfg.Run.Path = Join-Path $PSScriptRoot 'WinCare.Core.Tests.ps1'
        $cfg.Run.Exit = $false
        # Pester 6 chi tra result object khi PassThru = true (Pester 5 luon tra).
        # Truoc day khong dat -> $r rong -> fail khong bao gio dem (cang tham).
        $cfg.Run.PassThru = $true
        $cfg.Output.Verbosity = 'Detailed'
        $r = Invoke-Pester -Configuration $cfg
        if ($r) {
            $passed = [int]$r.PassedCount; $failedCount = [int]$r.FailedCount; $skipped = [int]$r.SkippedCount
            if ($failedCount -gt 0) { $fail++ }
            Write-Output ('  Pester: {0} passed, {1} failed, {2} skipped' -f $passed, $failedCount, $skipped)
        } else {
            # Fail-closed: khong nhan duoc ket qua -> coi nhu FAIL (spec muc 6)
            Write-Output '  CANH BAO: Invoke-Pester khong tra ket qua (kiem tra PassThru) -> coi nhu FAIL'
            $fail++
        }
    } else {
        Write-Output '  (Pester 5+ khong kha dung - bo qua, ghi ro trong TEST-REPORT)'
    }

    Write-Output ''
    Write-Output '======================================================'
    Write-Output ' 4) SMOKE TEST M6 (module owner viet, 50 case)'
    Write-Output '======================================================'
    $smoke = Join-Path $PSScriptRoot 'm6-smoke.ps1'
    if (Test-Path -LiteralPath $smoke) {
        & $smoke
        if ($LASTEXITCODE -ne 0) { $fail++ }
    } else {
        Write-Output '  (khong tim thay m6-smoke.ps1)'
    }
}

Write-Output ''
if ($fail -eq 0) {
    Write-Output '>>>>>>>>>> TAT CA KIEM CHUNG TINH TOAN PASS <<<<<<<<<<'
    exit 0
} else {
    Write-Output ('>>>>>>>>>> CO ' + $fail + ' NHOM KIEM CHUNG FAIL <<<<<<<<<<')
    exit 1
}
