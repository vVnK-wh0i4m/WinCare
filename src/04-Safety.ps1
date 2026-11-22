# ============================================================================
#  src/04-Safety.ps1 - Assert-SafePath, ham xoa duy nhat, danh sach bao ve
#  RANG BUOC: moi thao tac xoa/ghi phai qua Assert-SafePath truoc (spec 2.5)
#  (File viet lai toan bo sau su co hong du lieu)
# ============================================================================

# Ngon ngu rui ro dung chung toan app (luon kem CHU, khong chi mau - spec muc 1)
function Get-WCRiskInfo {
    param([Parameter(Mandatory)][ValidateSet('Recommended','Advanced','Risky')]$Risk)
    $map = @{
        Recommended = @{ Text = (T 'common.risk.recommended'); Hint = (T 'common.risk.recommended.hint'); Brush = 'WcOk' }
        Advanced    = @{ Text = (T 'common.risk.advanced');    Hint = (T 'common.risk.advanced.hint');    Brush = 'WcWarn' }
        Risky       = @{ Text = (T 'common.risk.risky');       Hint = (T 'common.risk.risky.hint');       Brush = 'WcBad' }
    }
    return $map[$Risk]
}

# ---------------------------------------------------------------------------
# Whitelist goc duoc phep xoa/don (mo rong boi tung module bang Add-WCDeleteRoot).
# Du lieu nguoi dung (Documents, Downloads, Desktop...) KHONG BAO GIO nam trong
# whitelist nay (spec 2.5).
# ---------------------------------------------------------------------------
$Script:WcDeleteRoots = New-Object System.Collections.Generic.List[string]

function Add-WCDeleteRoot {
    # Them 1 goc duoc phep don. Vd: Add-WCDeleteRoot (Join-Path $env:TEMP '')
    # Dung separator cua nen tang ([IO.Path]) de dung cho ca Windows va Linux (test)
    param([Parameter(Mandatory)][string]$Path)
    if (-not [IO.Path]::IsPathRooted($Path)) { throw ('Add-WCDeleteRoot: duong dan tuong doi khong chap nhan: ' + $Path) }
    $sep = [IO.Path]::DirectorySeparatorChar
    $norm = ([IO.Path]::GetFullPath($Path)).TrimEnd($sep) + $sep
    if (-not $Script:WcDeleteRoots.Contains($norm)) { $Script:WcDeleteRoots.Add($norm) }
}

function Initialize-WCDefaultDeleteRoots {
    # Cac goc he thong an toan, xay dung tu bien moi truong (khong hard-code C:\...).
    # Moi bien moi truong duoc kiem tra null (phong thu may truong hop dac biet).
    $c = New-Object System.Collections.Generic.List[string]
    if ($env:SystemRoot) {
        $c.Add((Join-Path $env:SystemRoot 'Temp'))
        $c.Add((Join-Path $env:SystemRoot 'Minidump'))
        $c.Add((Join-Path $env:SystemRoot 'LiveKernelReports'))
        $c.Add((Join-Path $env:SystemRoot ('SoftwareDistribution' + '\' + 'Download')))
        $c.Add((Join-Path $env:SystemRoot ('SoftwareDistribution' + '\' + 'DeliveryOptimization')))
        # Windows.old nam o GOC o dia he thong (C:\Windows.old), khong phai C:\Windows\Windows.old
        $winRoot = [IO.Path]::GetPathRoot($env:SystemRoot)
        if ($winRoot) { $c.Add((Join-Path $winRoot 'Windows.old')) }
    }
    if ($env:ProgramData) {
        $c.Add((Join-Path $env:ProgramData ('Microsoft' + '\' + 'Windows' + '\' + 'WER')))
        $c.Add((Join-Path $env:ProgramData ('Microsoft' + '\' + 'Windows Defender' + '\' + 'Scans')))
    }
    if ($env:LOCALAPPDATA) {
        $c.Add((Join-Path $env:LOCALAPPDATA 'CrashDumps'))
        $c.Add((Join-Path $env:LOCALAPPDATA 'D3DSCache'))                     # shader cache DirectX
        $c.Add((Join-Path $env:LOCALAPPDATA ('NVIDIA' + '\' + 'GLCache')))    # shader cache NVIDIA
        $c.Add((Join-Path $env:LOCALAPPDATA ('Spotify' + '\' + 'Storage')))
        # Browser cache: CHI dung muc cache cua tung profile (tang an toan tu liet ke
        # doc lap - KHONG tin danh sach tu module). Tuyet doi khong chap nhan ca thu
        # muc "User Data" hay "Profiles" vi do chua cookie/mat khau/lich su (spec 2.5)
        foreach ($p in (Get-WCSafeBrowserCacheRoots)) { $c.Add($p) }
    }
    if ($env:APPDATA) {
        $c.Add((Join-Path $env:APPDATA ('discord' + '\' + 'Cache')))
        $c.Add((Join-Path $env:APPDATA ('discord' + '\' + 'Code Cache')))
        $c.Add((Join-Path $env:APPDATA ('discord' + '\' + 'GPUCache')))
        $c.Add((Join-Path $env:APPDATA ('Microsoft' + '\' + 'Teams' + '\' + 'Cache')))
    }
    $c.Add([IO.Path]::GetTempPath())   # %TEMP% nguoi dung
    foreach ($p in $c) {
        try { Add-WCDeleteRoot $p } catch { Write-WCLog 'WARN' ('Bo qua delete root: ' + $p) }
    }
}

function Test-WCPathIsReparsePoint {
    param([Parameter(Mandatory)][string]$Path)
    try {
        $attr = [IO.File]::GetAttributes($Path)
        return (([int]$attr -band [int][IO.FileAttributes]::ReparsePoint) -ne 0)
    } catch { return $false }
}

function Get-WCSafeBrowserCacheRoots {
    # Liet ke CHINH XAC cac thu muc cache trinh duyet theo tung profile (fix 2.3):
    # Chromium (Chrome/Edge/Brave): <User Data>\<Profile>\{Cache, Code Cache, GPUCache}
    # Firefox: <Profiles>\<profile>\cache2
    # Tang an toan tu liet ke doc lap voi module M2 (phong thu 2 lop): neu module
    # sai liet ke thi Assert-SafePath van tu choi duong dan ngoai danh sach nay.
    # KHONG bao gio tra ve ca thu muc "User Data" / "Profiles" (chua cookie,
    # mat khau, lich su - doc lai se mat du lieu nguoi dung).
    $roots = New-Object System.Collections.Generic.List[string]
    if (-not $env:LOCALAPPDATA) { return $roots }
    $chromium = @('Google\Chrome', 'Microsoft\Edge', 'BraveSoftware\Brave-Browser')
    foreach ($b in $chromium) {
        $ud = Join-Path $env:LOCALAPPDATA ($b + '\' + 'User Data')
        if (-not (Test-Path -LiteralPath $ud -PathType Container)) { continue }
        try {
            foreach ($profile in [IO.Directory]::EnumerateDirectories($ud)) {
                $name = [IO.Path]::GetFileName($profile)
                if ($name -eq 'System Profile') { continue }
                if ($name -eq 'Guest Profile') { continue }
                # Chi tinh la profile neu co thu muc Cache (loai ShaderCache, Crashpad...)
                if (-not (Test-Path -LiteralPath (Join-Path $profile 'Cache') -PathType Container)) { continue }
                foreach ($cache in @('Cache', 'Code Cache', 'GPUCache')) {
                    $p = Join-Path $profile $cache
                    if (Test-Path -LiteralPath $p -PathType Container) { $roots.Add($p) }
                }
            }
        } catch { }
    }
    $ffProfiles = Join-Path $env:LOCALAPPDATA ('Mozilla' + '\' + 'Firefox' + '\' + 'Profiles')
    if (Test-Path -LiteralPath $ffProfiles -PathType Container) {
        try {
            foreach ($pf in [IO.Directory]::EnumerateDirectories($ffProfiles)) {
                $c2 = Join-Path $pf 'cache2'
                if (Test-Path -LiteralPath $c2 -PathType Container) { $roots.Add($c2) }
            }
        } catch { }
    }
    return $roots
}

function Assert-SafePath {
    # KIEM TRA BAT BUOC truoc moi thao tac xoa/ghi (spec 2.5).
    # Tra ve $true neu an toan; neu khong -> ghi log + tra ve $false.
    # Quy tac:
    #   1. Duong dan tuyet doi, da chuan hoa, khong chua segment '..' / '.'
    #   2. KHONG phai goc o dia / thu muc he thong truc tiep
    #   3. Khong di qua junction/symlink (ReparsePoint) o bat ky segment nao
    #   4. Nam duoc IT NHAT 1 goc trong whitelist
    param([Parameter(Mandatory)][string]$Path)
    try {
        if (-not [IO.Path]::IsPathRooted($Path)) { Write-WCLog 'SAFETY' ('Tu choi (tuong doi): ' + $Path); return $false }
        $full = [IO.Path]::GetFullPath($Path)
        foreach ($seg in ($full -split '[\\/]')) {
            if ($seg -eq '..' -or $seg -eq '.') { Write-WCLog 'SAFETY' ('Tu choi (segment dac biet): ' + $Path); return $false }
        }
        $fullTrim = $full.Trim("\/".ToCharArray())
        if ($fullTrim.Length -le 3) { Write-WCLog 'SAFETY' ('Tu choi (goc o dia): ' + $Path); return $false }
        # Khong dinh danh truc tiep cac thu muc he thong cap 1
        $sysDirs = @($env:SystemRoot, $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData, $env:LOCALAPPDATA, $env:APPDATA)
        foreach ($s in $sysDirs) {
            if ($s -and ($fullTrim -ieq $s.TrimEnd('\'))) { Write-WCLog 'SAFETY' ('Tu choi (thu muc he thong): ' + $Path); return $false }
        }
        # Khong du lieu nguoi dung (Documents/Downloads/Desktop/...)
        foreach ($u in @('Personal','Desktop','My Pictures','My Music','My Videos')) {
            try {
                $ud = [Environment]::GetFolderPath($u)
                if ($ud) {
                    $udn = $ud.TrimEnd('\') + '\'
                    if ($full.StartsWith($udn, [StringComparison]::OrdinalIgnoreCase)) {
                        Write-WCLog 'SAFETY' ('Tu choi (du lieu nguoi dung): ' + $Path); return $false
                    }
                }
            } catch { }
        }
        # Downloads khong co GetFolderPath rieng - kiem qua registry shell folders
        try {
            $dl = Get-WCRegistryValue -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders' -Name '{374DE290-123F-4565-9164-39C4925E467B}'
            if ($dl) {
                $dlFull = [Environment]::ExpandEnvironmentVariables($dl)
                $dln = $dlFull.TrimEnd('\') + '\'
                if ($full.StartsWith($dln, [StringComparison]::OrdinalIgnoreCase)) {
                    Write-WCLog 'SAFETY' ('Tu choi (Downloads): ' + $Path); return $false
                }
            }
        } catch { }
        # Khong di qua reparse point (junction/symlink) o bat ky cap nao,
        # TINH CA segment cuoi (fix 2.1 - bao cao do loi ben ngoai):
        #   + Vong cu bo qua segment cuoi (-ine $fullTrim) -> junction o cuoi duoc chap nhan.
        #   + Vong cu dung [IO.Path]::Combine('C:', 'Users') -> 'C:Users' (duong dan
        #     TUONG DOI theo o dia) -> GetAttributes luon throw -> khong bao gio phat
        #     hien junction o cac segment trung gian.
        # Cach dung: dung tien to goc 'C:\' (hoac '/' tren Unix) truoc khi Combine.
        $segs = @($full -split '[\\/]')
        $cur = ''
        $idx = 0
        if (($segs.Count -gt 0) -and ($segs[0] -match '^[A-Za-z]:$')) {
            $cur = $segs[0] + [IO.Path]::DirectorySeparatorChar
            $idx = 1
        } elseif ($full.StartsWith('\') -or $full.StartsWith('/')) {
            # UNC (\\server\share) hoac goc Unix (/tmp): segment dau tien rong
            $cur = [string][IO.Path]::DirectorySeparatorChar
            $idx = 1
        }
        for (; $idx -lt $segs.Count; $idx++) {
            $seg = $segs[$idx]
            if ([string]::IsNullOrEmpty($seg)) { continue }
            $cur = [IO.Path]::Combine($cur, $seg)
            if (Test-WCPathIsReparsePoint $cur) {
                Write-WCLog 'SAFETY' ('Tu choi (junction/symlink): ' + $cur)
                return $false
            }
        }
        # Phai nam trong it nhat 1 goc whitelist (khong phan biet hoa/thuong)
        $ok = $false
        $roots = Get-WCState 'WcDeleteRoots'
        if ($roots) {
            foreach ($root in $roots) {
                if ($full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase)) { $ok = $true; break }
            }
        }
        if (-not $ok) { Write-WCLog 'SAFETY' ('Tu choi (ngoai whitelist): ' + $Path); return $false }
        return $true
    } catch {
        Write-WCLog 'SAFETY' ('Tu choi (ngoai le): ' + $Path + ' -> ' + $_.Exception.Message)
        return $false
    }
}

function Remove-WCItem {
    # HAM XOA DUY NHAT cua toan app (spec 2.5). Moi lenh xoa phai di qua day.
    # -Recycle: chuyen vao Thung rac; mac dinh: xoa thang (cache he thong).
    # Dung -LiteralPath; bo qua an tinh tep dang khoa; tra ve so luong da xoa/skip.
    param(
        [Parameter(Mandatory)][string]$Path,
        [switch]$Recycle
    )
    if (-not (Assert-SafePath $Path)) { return @{ Deleted = 0; Skipped = 1; Bytes = [long]0 } }
    $bytes = [long]0
    try {
        if (Test-Path -LiteralPath $Path -PathType Container) {
            $bytes = (Get-WCDirSize $Path)
        } else {
            $fi = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
            if ($fi) { $bytes = $fi.Length }
        }
    } catch { $bytes = [long]0 }

    if (Test-WCDryRunMode) {
        Write-WCLog 'DRYRUN' ('[DRY-RUN] se ' + $(if ($Recycle) { 'chuyen Thung rac' } else { 'xoa' }) + ': ' + $Path)
        return @{ Deleted = 1; Skipped = 0; Bytes = $bytes; DryRun = $true }
    }
    try {
        if ($Recycle) {
            Send-WCFileToRecycleBin -Path $Path
        } else {
            if (Test-Path -LiteralPath $Path -PathType Container) {
                Remove-Item -LiteralPath $Path -Recurse -Force -ErrorAction Stop
            } else {
                Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
            }
        }
        return @{ Deleted = 1; Skipped = 0; Bytes = $bytes }
    } catch {
        # Tep dang khoa / truy cap bi tu choi -> bo qua e va dem (spec M2)
        Write-WCLog 'INFO' ('Bo qua (dang dung/khoa): ' + $Path)
        return @{ Deleted = 0; Skipped = 1; Bytes = [long]0 }
    }
}

function Get-WCDirSize {
    # Tinh kich thuoc thu muc, bo qua reparse point, khong throw
    param([Parameter(Mandatory)][string]$Path)
    $total = [long]0
    try {
        $stack = New-Object System.Collections.Stack
        $stack.Push($Path)
        while ($stack.Count -gt 0) {
            $dir = $stack.Pop()
            try {
                foreach ($f in [IO.Directory]::EnumerateFiles($dir)) {
                    try { $total += ([IO.FileInfo]$f).Length } catch { }
                }
                foreach ($d in [IO.Directory]::EnumerateDirectories($dir)) {
                    if (-not (Test-WCPathIsReparsePoint $d)) { $stack.Push($d) }
                }
            } catch { }
        }
    } catch { }
    return $total
}

# ---------------------------------------------------------------------------
# Danh sach tien trinh bao ve - KHONG BAO GIO trim/dong/dung (spec M1)
# ---------------------------------------------------------------------------
$Script:WcProtectedProcesses = @(
    'System','Registry','smss','csrss','wininit','winlogon','services','lsass','lsm',
    'svchost','dwm','fontdrvhost','MsMpEng','NisSrv','audiodg'
)

function Get-WCProtectedProcesses { return @(Get-WCState 'WcProtectedProcesses') }

function Test-WCProtectedProcess {
    param([Parameter(Mandatory)][string]$ProcessName)
    $n = $ProcessName -replace '\.exe$',''
    $protected = Get-WCState 'WcProtectedProcesses'
    if ($protected -and ($protected -contains $n)) { return $true }
    # Tien trinh anti-cheat / game-platform
    if ($n -match 'anticheat|vgtray|vgc|easyanticheat|battleeye|faceit|ricochet') { return $true }
    # Moi AV dang ky o SecurityCenter2 (ten process thuong giong ten san pham)
    try {
        $avs = Get-CimInstance -Namespace 'root/SecurityCenter2' -ClassName 'AntiVirusProduct' -ErrorAction Stop
        foreach ($av in $avs) {
            $pn = (Get-WCProp $av 'displayName')
            if ($pn) {
                $first = ($pn -split ' ')[0]
                if ($first -and ($n -like ($first + '*'))) { return $true }
            }
        }
    } catch { }
    $wcName = Get-WCState 'WcName'
    if ($wcName -and ($n -like ($wcName + '*'))) { return $true }  # chinh WinCare
    return $false
}

function Get-WCProcessDisplayName {
    # Chuan hoa ten hien thi cua process (Chrome nhieu tien trinh = 1 nhom)
    param([Parameter(Mandatory)][string]$ProcessName, [string]$Path = '')
    $n = ($ProcessName -replace '\.exe$','')
    $known = @{
        'chrome' = 'Google Chrome'; 'msedge' = 'Microsoft Edge'; 'brave' = 'Brave'
        'firefox' = 'Firefox'; 'discord' = 'Discord'; 'spotify' = 'Spotify'
        'teams' = 'Microsoft Teams'; 'Code' = 'VS Code'; 'onenote' = 'OneNote'
        'steam' = 'Steam'; 'steamwebhelper' = 'Steam'; 'EpicGamesLauncher' = 'Epic Games'
    }
    if ($known.ContainsKey($n)) { return $known[$n] }
    if ($Path -and (Test-WCPathIsReparsePoint $Path) -eq $false) {
        try {
            $company = ((Get-Item -LiteralPath $Path -ErrorAction Stop).VersionInfo.CompanyName)
            if ($company) { return ($company.Trim() + ' (' + $n + ')') }
        } catch { }
    }
    return $n
}
