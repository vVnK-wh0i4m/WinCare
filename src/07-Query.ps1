# ============================================================================
#  src/07-Query.ps1 - Lop du lieu tach khoi UI (spec 2.3)
#  Get-* thuan, tra object chuan hoa co Status (Ok/Warn/Bad/Unknown) + Reason.
#  Co che FIXTURE (WINCARE_FIXTURE=file.json) de test UI/logic voi du lieu gia.
#  Moi truy van co try/catch rieng; mot nguon loi khong lam sap module.
# ============================================================================

$Script:WcFixture = $null      # hashtable du lieu gia (nap tu JSON)
$Script:WcQueryCache = @{}

function Initialize-WCFixture {
    if ([string]::IsNullOrEmpty($Script:WcFixturePath)) { return }
    try {
        if (Test-Path -LiteralPath $Script:WcFixturePath) {
            $json = [IO.File]::ReadAllText($Script:WcFixturePath)
            $obj = ConvertFrom-Json $json
            $h = @{}
            foreach ($p in $obj.PSObject.Properties) { $h[$p.Name] = $p.Value }
            $Script:WcFixture = $h
            Write-WCLog 'INFO' ('FIXTURE mode: ' + $Script:WcFixturePath + ' (' + $h.Count + ' khoa)')
        } else {
            Write-WCLog 'WARN' ('WINCARE_FIXTURE chi dinh nhung khong ton tai: ' + $Script:WcFixturePath)
        }
    } catch { Write-WCLog 'WARN' ('FIXTURE hong: ' + $_.Exception.Message) }
}

function Test-WCFixtureMode { return ($null -ne $Script:WcFixture) }

function New-WCResult {
    # Object chuan hoa toan app: Status (Ok/Warn/Bad/Unknown) + Reason + Data
    param(
        [Parameter(Mandatory)][ValidateSet('Ok','Warn','Bad','Unknown')]$Status,
        [string]$Reason = '',
        $Data = $null
    )
    return [PSCustomObject]@{ Status = $Status; Reason = $Reason; Data = $Data }
}

function Get-WCProp {
    # Truy cap thuoc tinh an toan (CIM co the thieu thuoc tinh; StrictMode 2.0)
    param($Obj, [Parameter(Mandatory)][string]$Name)
    if ($null -eq $Obj) { return $null }
    try {
        $p = $Obj.PSObject.Properties[$Name]
        if ($p) { return $p.Value }
    } catch { }
    return $null
}

function Invoke-WCQuery {
    # Cong truy van trung tam: ho tro FIXTURE theo key + try/catch + cache TTL.
    # Vi du:
    #   Invoke-WCQuery -Key 'os' -Script { Get-CimInstance Win32_OperatingSystem } | Out-Null
    # Ket qua luon la New-WCResult. FIXTURE uu tien: du lieu gia thay the truy van that.
    param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][scriptblock]$Script,
        [int]$CacheTtlSec = 0,
        [switch]$NoCache
    )
    # 1) FIXTURE mode (spec 2.3)
    $fixture = Get-WCState 'WcFixture'
    if ($fixture -and $fixture.ContainsKey($Key)) {
        return (New-WCResult -Status 'Ok' -Data $fixture[$Key])
    }
    # 2) Cache
    $cache = Get-WCState 'WcQueryCache'
    if (-not $NoCache -and $CacheTtlSec -gt 0 -and $cache) {
        if ($cache.ContainsKey($Key)) {
            $hit = $cache[$Key]
            if ((([DateTime]::Now) - $hit.Time).TotalSeconds -lt $CacheTtlSec) {
                return $hit.Result
            }
        }
    }
    # 3) Truy van that
    try {
        $data = & $Script
        $result = New-WCResult -Status 'Ok' -Data $data
    } catch {
        Write-WCLog 'QUERY' ($Key + ' that bai: ' + $_.Exception.Message)
        $result = New-WCResult -Status 'Unknown' -Reason $_.Exception.Message
    }
    if ($CacheTtlSec -gt 0 -and $cache -and -not $cache.ContainsKey($Key)) {
        $cache[$Key] = @{ Time = [DateTime]::Now; Result = $result }
    }
    return $result
}

# ---------------------------------------------------------------------------
# Helpers dinh dang dung chung
# ---------------------------------------------------------------------------
function ConvertTo-WCHumanSize {
    # Bytes -> "1,2 GB" / "512 MB" (dau phan cach hang nghin theo InvariantCulture)
    param([long]$Bytes)
    if ($Bytes -lt 0) { return '0 B' }
    if ($Bytes -lt 1024) { return ('{0} B' -f $Bytes) }
    $kb = [double]$Bytes / 1KB
    if ($kb -lt 1024) { return ('{0:N0} KB' -f $kb) }
    $mb = $kb / 1024
    if ($mb -lt 1024) { return ('{0:N1} MB' -f $mb) }
    $gb = $mb / 1024
    if ($gb -lt 1024) { return ('{0:N2} GB' -f $gb) }
    return ('{0:N2} TB' -f ($gb / 1024))
}

function ConvertTo-WCHumanDuration {
    param([double]$Seconds)
    if ($Seconds -lt 60) { return (T 'fmt.seconds' @([math]::Round($Seconds))) }
    if ($Seconds -lt 3600) { return (T 'fmt.minutes' @([math]::Round($Seconds / 60))) }
    return (T 'fmt.hours' @([math]::Round(($Seconds / 3600), 1)))
}

function ConvertTo-WCSafeString {
    # Ky tu do mo tu CIM (WmiMonitorID...) -> chuoi sach
    param($RawBytes)
    if ($null -eq $RawBytes) { return '' }
    try {
        $s = ([string]::Join('', ($RawBytes | ForEach-Object { if ($_ -gt 0) { [char]$_ } })))
        return $s.Trim()
    } catch { return '' }
}

function Get-WCRegistryValue {
    # Doc registry an toan: tra $null khi loi (khong throw)
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Name)
    try {
        $v = Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop
        return (Get-WCProp $v $Name)
    } catch { return $null }
}

function Get-WCIsHDDPresent {
    # Kiem tra may co o HDD khong (canh bao purge cache gay giat - spec M1)
    $r = Invoke-WCQuery -Key 'physicaldisks' -CacheTtlSec 120 -Script {
        Get-CimInstance -ClassName Win32_DiskDrive -Property MediaType -OperationTimeoutSec 10
    }
    if ($r.Status -ne 'Ok') { return $false }
    foreach ($d in @($r.Data)) {
        $mt = (Get-WCProp $d 'MediaType')
        if ($mt -and ($mt -like '*fixed*hard*')) { return $true }
        # Win32_DiskDrive.MediaType thuong la "Fixed hard disk media" cho ca SSD;
        # phan biet SSD/HDD chinh xac qua Get-PhysicalDisk o M2/M6 - day chi la heuristic
    }
    return $false
}

function Get-WCUpTime {
    $r = Invoke-WCQuery -Key 'os' -CacheTtlSec 30 -Script {
        Get-CimInstance -ClassName Win32_OperatingSystem -Property LastBootUpTime -OperationTimeoutSec 10
    }
    if ($r.Status -ne 'Ok') { return $null }
    $lbt = (Get-WCProp $r.Data 'LastBootUpTime')
    if ($null -eq $lbt) { return $null }
    try {
        if ($lbt -is [DateTime]) { return (([DateTime]::Now) - $lbt) }
        return (([DateTime]::Now) - $lbt.ToDateTime([Globalization.CultureInfo]::InvariantCulture))
    } catch { return $null }
}

function Get-WCMemorySnapshot {
    # Anh trai RAM khong phu thuoc ngon ngu Windows (spec M1):
    # Win32_OperatingSystem + Win32_PerfFormattedData_PerfOS_Memory
    $osR = Invoke-WCQuery -Key 'os.mem' -CacheTtlSec 2 -Script {
        Get-CimInstance -ClassName Win32_OperatingSystem -Property TotalVisibleMemorySize,FreePhysicalMemory,TotalVirtualMemorySize,FreeVirtualMemory -OperationTimeoutSec 8
    }
    $perfR = Invoke-WCQuery -Key 'perf.mem' -CacheTtlSec 2 -Script {
        Get-CimInstance -ClassName Win32_PerfFormattedData_PerfOS_Memory -OperationTimeoutSec 8
    }
    $snap = [ordered]@{
        TotalKb       = $null; FreeKb = $null; UsedKb = $null
        CommitKb      = $null; CommitLimitKb = $null
        StandbyKb     = $null; ModifiedKb = $null
        HardFaultsPerSec = $null; PagesPerSec = $null
        AvailableKb   = $null
        Status = 'Unknown'; Reason = ''
    }
    if ($osR.Status -eq 'Ok' -and $osR.Data) {
        $tot = Get-WCProp $osR.Data 'TotalVisibleMemorySize'
        $free = Get-WCProp $osR.Data 'FreePhysicalMemory'
        if ($null -ne $tot) { $snap.TotalKb = [double]$tot }
        if ($null -ne $free) { $snap.FreeKb = [double]$free }
        if (($snap.TotalKb -gt 0) -and ($null -ne $snap.FreeKb)) { $snap.UsedKb = $snap.TotalKb - $snap.FreeKb }
        $lim = Get-WCProp $osR.Data 'TotalVirtualMemorySize'
        $fv = Get-WCProp $osR.Data 'FreeVirtualMemory'
        if ($null -ne $lim) { $snap.CommitLimitKb = [double]$lim }
        if (($null -ne $lim) -and ($null -ne $fv)) { $snap.CommitKb = [double]$lim - [double]$fv }
    }
    if ($perfR.Status -eq 'Ok' -and $perfR.Data) {
        $avail = Get-WCProp $perfR.Data 'AvailableKBytes'
        if ($null -ne $avail) { $snap.AvailableKb = [double]$avail }
        # Standby/Modified: co tren Win10/11, thieu tren he thong cu -> khong doan (spec 1.5)
        $sbCore = Get-WCProp $perfR.Data 'StandbyCacheCoreBytes'
        $sbNorm = Get-WCProp $perfR.Data 'StandbyCacheNormalPriorityBytes'
        $sbRes  = Get-WCProp $perfR.Data 'StandbyCacheReserveBytes'
        if ($null -ne $sbCore) {
            $standby = [double]$sbCore
            if ($null -ne $sbNorm) { $standby += [double]$sbNorm }
            if ($null -ne $sbRes)  { $standby += [double]$sbRes }
            $snap.StandbyKb = [math]::Round($standby / 1KB)
        }
        $mod = Get-WCProp $perfR.Data 'ModifiedPageListBytes'
        if ($null -ne $mod) { $snap.ModifiedKb = [math]::Round([double]$mod / 1KB) }
        $pi = Get-WCProp $perfR.Data 'PagesInputPersec'
        if ($null -ne $pi) { $snap.HardFaultsPerSec = [double]$pi }
        $pp = Get-WCProp $perfR.Data 'PagesPersec'
        if ($null -ne $pp) { $snap.PagesPerSec = [double]$pp }
    }
    if ($null -ne $snap.TotalKb) { $snap.Status = 'Ok' }
    else { $snap.Reason = 'Khong doc duoc CIM memory' }
    return [PSCustomObject]$snap
}
