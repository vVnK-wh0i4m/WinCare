# Smoke test logic thuan cua M6 (chay tren Linux pwsh voi stub cac ham khung)
# Chi kiem chung: Get-WCHealthScore + 6 verdict + Merge-WCHealthStorage + Get-WCM6Field
$ErrorActionPreference = 'Stop'
$fail = 0
function Assert($Name, $Cond) {
    if ($Cond) { Write-Output ('PASS  ' + $Name) }
    else { $script:fail++; Write-Output ('FAIL  ' + $Name) }
}

# --- Stub khung WinCare ---
function Register-WCStrings { param($Lang, $Strings) }
function T { param([Parameter(Mandatory)][string]$Key, [object[]]$Fmt)
    if ($Fmt -and $Fmt.Count -gt 0) { try { return ($Key + '|' + ($Fmt -join ',')) } catch { return $Key } }
    return $Key
}
function Get-WCProp {
    param($Obj, [Parameter(Mandatory)][string]$Name)
    if ($null -eq $Obj) { return $null }
    try { $p = $Obj.PSObject.Properties[$Name]; if ($p) { return $p.Value } } catch { }
    return $null
}
function Write-WCLog { param($Level, $Text) }

. (Join-Path (Split-Path -Parent $PSScriptRoot) 'src/17-M6-Health.ps1')

# --- Get-WCM6Field: hashtable + PSCustomObject ---
Assert 'Field hashtable' ((Get-WCM6Field @{ A = 5 } 'A') -eq 5)
Assert 'Field hashtable missing' ($null -eq (Get-WCM6Field @{ A = 5 } 'B'))
Assert 'Field psobject' ((Get-WCM6Field ([PSCustomObject]@{ A = 7 }) 'A') -eq 7)

# --- Get-WCHealthScore: truong hop chinh ---
$g = @{
    Storage   = @{ Status = 'Ok'; Score = 100; Severe = $false; Reason = 'ok' }
    Stability = @{ Status = 'Ok'; Score = 100; Severe = $false; Reason = 'ok' }
    Integrity = @{ Status = 'Ok'; Score = 100; Severe = $false; Reason = 'ok' }
    Security  = @{ Status = 'Ok'; Score = 100; Severe = $false; Reason = 'ok' }
    Memory    = @{ Status = 'Ok'; Score = 100; Severe = $false; Reason = 'ok' }
    Battery   = @{ Status = 'Ok'; Score = 100; Severe = $false; Reason = 'ok' }
}
$r = Get-WCHealthScore $g
Assert 'Score all-100 = 100' ($r.Score -eq 100)
Assert 'No cap' ($r.Capped -eq $false)
Assert 'TotalWeight 100' ($r.TotalWeight -eq 100)

# May khong pin: Battery Unknown -> bo khoi mau so, con 90 trong so
$g2 = @{
    Storage   = @{ Status = 'Ok'; Score = 100; Severe = $false; Reason = 'ok' }
    Stability = @{ Status = 'Ok'; Score = 100; Severe = $false; Reason = 'ok' }
    Integrity = @{ Status = 'Ok'; Score = 100; Severe = $false; Reason = 'ok' }
    Security  = @{ Status = 'Ok'; Score = 100; Severe = $false; Reason = 'ok' }
    Memory    = @{ Status = 'Ok'; Score = 100; Severe = $false; Reason = 'ok' }
    Battery   = @{ Status = 'Unknown'; Score = $null; Severe = $false; Reason = 'khong pin' }
}
$r2 = Get-WCHealthScore $g2
Assert 'Skip Battery -> renorm 100' ($r2.Score -eq 100)
Assert 'TotalWeight 90' ($r2.TotalWeight -eq 90)
Assert 'SkippedNames contains Battery' (@($r2.SkippedNames) -contains 'Battery')
Assert 'Breakdown Battery Score null' ($null -eq ($r2.Breakdown | Where-Object { $_.Group -eq 'Battery' }).Score)

# Trong so: Storage 100, Stability 50, cac nhom khac 100, bo Battery
# (25*100 + 25*50 + 15*100 + 15*100 + 10*100) / 90 = 7750/90 = 86.1 -> 86
$g3 = @{
    Storage   = @{ Status = 'Ok'; Score = 100; Severe = $false; Reason = 'ok' }
    Stability = @{ Status = 'Warn'; Score = 50; Severe = $false; Reason = 'bsod' }
    Integrity = @{ Status = 'Ok'; Score = 100; Severe = $false; Reason = 'ok' }
    Security  = @{ Status = 'Ok'; Score = 100; Severe = $false; Reason = 'ok' }
    Memory    = @{ Status = 'Ok'; Score = 100; Severe = $false; Reason = 'ok' }
    Battery   = @{ Status = 'Unknown'; Score = $null; Severe = $false; Reason = 'na' }
}
$r3 = Get-WCHealthScore $g3
Assert 'Weighted renorm = 86' ($r3.Score -eq 86)

# Tran: Storage Severe -> toi da 49
$g4 = @{
    Storage   = @{ Status = 'Bad'; Score = 40; Severe = $true; Reason = 'SMART hong' }
    Stability = @{ Status = 'Ok'; Score = 100; Severe = $false; Reason = 'ok' }
    Integrity = @{ Status = 'Ok'; Score = 100; Severe = $false; Reason = 'ok' }
    Security  = @{ Status = 'Ok'; Score = 100; Severe = $false; Reason = 'ok' }
    Memory    = @{ Status = 'Ok'; Score = 100; Severe = $false; Reason = 'ok' }
    Battery   = @{ Status = 'Ok'; Score = 100; Severe = $false; Reason = 'ok' }
}
$r4 = Get-WCHealthScore $g4
Assert 'Capped = true' ($r4.Capped -eq $true)
Assert 'Cap max 49' ($r4.Score -le 49)
Assert 'CapReason contains SMART' ($r4.CapReason -like '*SMART*')

# Khong nhom nao -> Score null
$r5 = Get-WCHealthScore @{}
Assert 'Empty -> null score' ($null -eq $r5.Score)

# Group PSCustomObject (unit test truyen PSObject cung chay)
$g6 = [PSCustomObject]@{
    Storage   = [PSCustomObject]@{ Status = 'Ok'; Score = 80; Severe = $false; Reason = 'ok' }
}
$r6 = Get-WCHealthScore $g6
Assert 'PSObject input works' ($r6.Score -eq 80 -and $r6.TotalWeight -eq 25)

# --- Verdict: Storage ---
$v = Get-WCHealthStorageVerdict (Merge-WCHealthStorage `
    ([PSCustomObject]@{ Ok = $true; Disks = @([PSCustomObject]@{ DeviceId = '0'; Name = 'SSD A'; Media = 'SSD'; Health = 'Healthy'; OpStatus = 'OK' }) }) `
    ([PSCustomObject]@{ Ok = $true; Counters = @([PSCustomObject]@{ DeviceId = '0'; Temp = 41; Wear = 3; Hours = 5000; ReadErrors = 5; ReadUncorr = 0; WriteErrors = 0 }) }) `
    ([PSCustomObject]@{ Ok = $true; Volumes = @([PSCustomObject]@{ Letter = 'C:'; Size = [double]500GB; Free = [double]250GB; PctFree = 50.0 }) }))
Assert 'Storage healthy = 100 Ok' ($v.Score -eq 100 -and $v.Status -eq 'Ok')
Assert 'Storage fact ok' ((Get-WCM6Field $v.Facts[0] 'Key') -eq 'storage.ok')

$v = Get-WCHealthStorageVerdict (Merge-WCHealthStorage `
    ([PSCustomObject]@{ Ok = $true; Disks = @([PSCustomObject]@{ DeviceId = '0'; Name = 'SSD A'; Media = 'SSD'; Health = 'Unhealthy'; OpStatus = 'Predictive Failure' }) }) `
    $null `
    ([PSCustomObject]@{ Ok = $true; Volumes = @() }))
Assert 'Storage unhealthy -> Bad + Severe' ($v.Status -eq 'Bad' -and $v.Severe -eq $true -and $v.Score -lt 60)

$v = Get-WCHealthStorageVerdict (Merge-WCHealthStorage $null $null ([PSCustomObject]@{ Ok = $true; Volumes = @([PSCustomObject]@{ Letter = 'C:'; Size = 100.0; Free = 2.0; PctFree = 2.0 }) }))
Assert 'Volumes-only low free (<5%) -> 75 Warn' ($v.Score -eq 75 -and $v.Status -eq 'Warn')

$v = Get-WCHealthStorageVerdict (Merge-WCHealthStorage $null $null $null)
Assert 'Storage no data -> Unknown' ($v.Status -eq 'Unknown' -and $null -eq $v.Score)

# SMART kho doc (chi physicaldisks, khong reliability) -> khong tru diem
$v = Get-WCHealthStorageVerdict (Merge-WCHealthStorage `
    ([PSCustomObject]@{ Ok = $true; Disks = @([PSCustomObject]@{ DeviceId = '1'; Name = 'USB'; Media = 'Unspecified'; Health = 'Healthy'; OpStatus = 'OK' }) }) `
    ([PSCustomObject]@{ Ok = $true; Counters = @() }) `
    ([PSCustomObject]@{ Ok = $true; Volumes = @([PSCustomObject]@{ Letter = 'C:'; Size = 1000.0; Free = 500.0; PctFree = 50.0 }) }))
Assert 'USB no SMART -> 100 + nosmart fact' ($v.Score -eq 100 -and ((@($v.Facts) | Where-Object { (Get-WCM6Field $_ 'Key') -eq 'storage.nosmart' }).Count -gt 0))

# --- Verdict: Stability ---
$mk = { param($sysOk, $appOk, $cats)
    [PSCustomObject]@{ Ok = $sysOk; SystemOk = $sysOk; AppOk = $appOk; Cats = $cats; BugCodes = @('0x9f') }
}
$cats0 = @{ kpower41 = 0; whea = 0; bugcheck = 0; diskerr = 0; tdr = 0; svc = 0; appcrash = 0; wheamem = 0; memdiagerr = 0; memdiagok = 0 }
$v = Get-WCHealthStabilityVerdict (& $mk $true $true $cats0)
Assert 'Stability clean = 100' ($v.Score -eq 100 -and $v.Status -eq 'Ok')

$catsBad = @{ kpower41 = 1; whea = 1; bugcheck = 2; diskerr = 1; tdr = 1; svc = 1; appcrash = 1; wheamem = 0; memdiagerr = 0; memdiagok = 0 }
$v = Get-WCHealthStabilityVerdict (& $mk $true $true $catsBad)
Assert 'Stability mixed = 21 Bad' ($v.Score -eq 21 -and $v.Status -eq 'Bad')

$catsDisk = @{ kpower41 = 0; whea = 0; bugcheck = 0; diskerr = 12; tdr = 0; svc = 0; appcrash = 0; wheamem = 0; memdiagerr = 0; memdiagok = 0 }
$v = Get-WCHealthStabilityVerdict (& $mk $true $true $catsDisk)
Assert 'Stability diskerr>=10 -> Severe' ($v.Severe -eq $true)

$v = Get-WCHealthStabilityVerdict (& $mk $true $false $cats0)
Assert 'App log off -> khong tru, co fact applog' ($v.Score -eq 100 -and ((@($v.Facts) | Where-Object { (Get-WCM6Field $_ 'Key') -eq 'stab.applog' }).Count -gt 0))

$v = Get-WCHealthStabilityVerdict (& $mk $false $true $cats0)
Assert 'Stability System log off -> Unknown' ($v.Status -eq 'Unknown')

# --- Verdict: Integrity ---
$v = Get-WCHealthIntegrityVerdict ([PSCustomObject]@{ Ok = $true; ExitCode = 0 }) ([PSCustomObject]@{ Ok = $true; ExitCode = 0 })
Assert 'Integrity clean = 100' ($v.Score -eq 100 -and $v.Status -eq 'Ok')
$v = Get-WCHealthIntegrityVerdict ([PSCustomObject]@{ Ok = $true; ExitCode = 0 }) ([PSCustomObject]@{ Ok = $true; ExitCode = 1 })
Assert 'Integrity sfc!=0 = 60 Warn' ($v.Score -eq 60 -and $v.Status -eq 'Warn')
$v = Get-WCHealthIntegrityVerdict ([PSCustomObject]@{ Ok = $false; ExitCode = $null }) ([PSCustomObject]@{ Ok = $false; ExitCode = $null })
Assert 'Integrity both norun -> Unknown' ($v.Status -eq 'Unknown')
$v = Get-WCHealthIntegrityVerdict ([PSCustomObject]@{ Ok = $true; ExitCode = 0 }) $null
Assert 'Integrity dism clean + sfc null = 70' ($v.Score -eq 70)
$v = Get-WCHealthIntegrityVerdict ([PSCustomObject]@{ Ok = $true; ExitCode = 87 }) ([PSCustomObject]@{ Ok = $true; ExitCode = 0 })
Assert 'Integrity dism inconclusive + sfc clean = 60' ($v.Score -eq 60)

# --- Verdict: Security ---
$v = Get-WCHealthSecurityVerdict ([PSCustomObject]@{ Mode = 'defender'; RealTime = $true; SigAgeDays = 2 })
Assert 'Security rtp+fresh = 100' ($v.Score -eq 100 -and $v.Status -eq 'Ok')
$v = Get-WCHealthSecurityVerdict ([PSCustomObject]@{ Mode = 'defender'; RealTime = $true; SigAgeDays = 20 })
Assert 'Security old sig = 40' ($v.Score -eq 40)
$v = Get-WCHealthSecurityVerdict ([PSCustomObject]@{ Mode = 'defender'; RealTime = $false; SigAgeDays = 1 })
Assert 'Security rtp off = 30 Bad' ($v.Score -eq 30 -and $v.Status -eq 'Bad')
$v = Get-WCHealthSecurityVerdict ([PSCustomObject]@{ Mode = 'defender'; RealTime = $true; SigAgeDays = $null })
Assert 'Security sig null = 80 Warn' ($v.Score -eq 80 -and $v.Status -eq 'Warn')
$v = Get-WCHealthSecurityVerdict ([PSCustomObject]@{ Mode = 'thirdparty'; AvName = 'AV X' })
Assert 'Security thirdparty -> Unknown skip' ($v.Status -eq 'Unknown' -and $null -eq $v.Score)
$v = Get-WCHealthSecurityVerdict ([PSCustomObject]@{ Mode = 'unknown' })
Assert 'Security unknown mode -> skip' ($v.Status -eq 'Unknown')

# --- Verdict: Memory ---
$v = Get-WCHealthMemoryVerdict (& $mk $true $true $cats0)
Assert 'Memory clean = 100' ($v.Score -eq 100 -and $v.Status -eq 'Ok')
$catsMem = @{ kpower41 = 0; whea = 3; bugcheck = 0; diskerr = 0; tdr = 0; svc = 0; appcrash = 0; wheamem = 4; memdiagerr = 0; memdiagok = 0 }
$v = Get-WCHealthMemoryVerdict (& $mk $true $true $catsMem)
Assert 'Memory whea>=3 -> Severe 25' ($v.Score -eq 25 -and $v.Severe -eq $true)
$catsMem2 = @{ kpower41 = 0; whea = 2; bugcheck = 0; diskerr = 0; tdr = 0; svc = 0; appcrash = 0; wheamem = 2; memdiagerr = 0; memdiagok = 0 }
$v = Get-WCHealthMemoryVerdict (& $mk $true $true $catsMem2)
Assert 'Memory whea 1-2 -> 60 Warn' ($v.Score -eq 60 -and $v.Status -eq 'Warn')
$catsDiag = @{ kpower41 = 0; whea = 0; bugcheck = 0; diskerr = 0; tdr = 0; svc = 0; appcrash = 0; wheamem = 0; memdiagerr = 1; memdiagok = 0 }
$v = Get-WCHealthMemoryVerdict (& $mk $true $true $catsDiag)
Assert 'Memory diag err -> Severe 20' ($v.Score -eq 20 -and $v.Severe -eq $true)
$v = Get-WCHealthMemoryVerdict $null
Assert 'Memory nodata -> Unknown' ($v.Status -eq 'Unknown')

# --- Verdict: Battery ---
$v = Get-WCHealthBatteryVerdict ([PSCustomObject]@{ Ok = $true; HasBattery = $true; Batteries = @([PSCustomObject]@{ Design = 60000.0; Full = 58000.0; Wear = 3.3 }) })
Assert 'Battery wear 3.3% = 100' ($v.Score -eq 100)
$v = Get-WCHealthBatteryVerdict ([PSCustomObject]@{ Ok = $true; HasBattery = $true; Batteries = @([PSCustomObject]@{ Design = 60000.0; Full = 45000.0; Wear = 25.0 }) })
Assert 'Battery wear 25% = 65 Warn' ($v.Score -eq 65 -and $v.Status -eq 'Warn')
$v = Get-WCHealthBatteryVerdict ([PSCustomObject]@{ Ok = $true; HasBattery = $true; Batteries = @([PSCustomObject]@{ Design = 60000.0; Full = 30000.0; Wear = 50.0 }) })
Assert 'Battery wear 50% = 40 Bad' ($v.Score -eq 40 -and $v.Status -eq 'Bad')
$v = Get-WCHealthBatteryVerdict ([PSCustomObject]@{ Ok = $true; HasBattery = $false; Batteries = @() })
Assert 'Battery absent -> Unknown' ($v.Status -eq 'Unknown')
$v = Get-WCHealthBatteryVerdict ([PSCustomObject]@{ Ok = $false; HasBattery = $false; Batteries = @() })
Assert 'Battery unreadable -> Unknown' ($v.Status -eq 'Unknown')

# --- Kich ban may de khong pin + event log tat (spec M6 tieu chi hoan thanh) ---
$gEdge = @{
    Storage   = @{ Status = 'Ok'; Score = 95; Severe = $false; Reason = 'ok' }
    Stability = @{ Status = 'Unknown'; Score = $null; Severe = $false; Reason = 'log tat' }
    Integrity = @{ Status = 'Ok'; Score = 100; Severe = $false; Reason = 'ok' }
    Security  = @{ Status = 'Ok'; Score = 100; Severe = $false; Reason = 'ok' }
    Memory    = @{ Status = 'Unknown'; Score = $null; Severe = $false; Reason = 'log tat' }
    Battery   = @{ Status = 'Unknown'; Score = $null; Severe = $false; Reason = 'khong pin' }
}
$rEdge = Get-WCHealthScore $gEdge
# (25*95 + 15*100 + 15*100) / 55 = 5375/55 = 97.7 -> 98
Assert 'Edge machine score = 98' ($rEdge.Score -eq 98)
Assert 'Edge 3 skipped' (@($rEdge.SkippedNames).Count -eq 3)

Write-Output ''
if ($fail -eq 0) { Write-Output '== TAT CA SMOKE TEST PASS ==' } else { Write-Output ('== ' + $fail + ' FAIL ==') }
exit $(if ($fail -eq 0) { 0 } else { 1 })
