# ==============================================================================
#   WinCare - Trinh toi uu & kiem tra Windows (tieng Viet)
#   Mot file PowerShell duy nhat. Chay:  irm 'https://raw.githubusercontent.com/vVnK-wh0i4m/WinCare/main/dist/WinCare.ps1' | iex   (can Admin, WPF)
#   Ma nguon: src/*.ps1 -> build.ps1 -> dist/WinCare.ps1
#   Khong telemetry. Quet chi doc. Moi thay doi can xac nhan + nhat ky hoan tac.
# ==============================================================================

# ============================================================================
# REGION: 00-Boot.ps1
# ============================================================================

# ============================================================================
#  WinCare - Trinh toi uu & kiem tra Windows (mot file PowerShell duy nhat)
#  File nguon: src/00-Boot.ps1  |  Duoc ghep boi build.ps1 vao dist/WinCare.ps1
#  Yeu cau: Windows 10 1809+ / Windows 11 x64, Windows PowerShell 5.1+ hoac 7+
# ============================================================================

$Script:WcName     = 'WinCare'
$Script:WcVersion  = '1.0.0'
$Script:WcBuild    = 'ad25efbc'   # duoc build.ps1 thay the bang 8 ky tu dau SHA-256
$Script:WcSelfUrlDefault = 'https://raw.githubusercontent.com/WINCARE-PLACEHOLDER/WinCare.ps1'

# iex khong nhan tham so -> moi cau hinh di qua bien moi truong (spec 2.1)
$Script:WcLang     = $env:WINCARE_LANG        # 'vi' | 'en'
$Script:WcDebug    = ($env:WINCARE_DEBUG -eq '1')
$Script:WcDryRun   = ($env:WINCARE_DRYRUN -eq '1')
$Script:WcFixturePath = $env:WINCARE_FIXTURE  # duong dan file JSON du lieu gia (spec 2.3)
$Script:WcSelfUrl  = $env:WINCARE_SELFURL     # URL de tu relaunch khi can Admin

Set-StrictMode -Version 2.0
$Script:WcErrorPreferenceBackup = $ErrorActionPreference
$ErrorActionPreference = 'Stop'

# TLS 1.2 (va 1.3 neu enum co) - can cho irm/Update session tren PS 5.1
try {
    $tls = [Net.SecurityProtocolType]::Tls12
    if (@([Enum]::GetNames([Net.SecurityProtocolType])) -contains 'Tls13') {
        $tls = $tls -bor [Net.SecurityProtocolType]::Tls13
    }
    [Net.ServicePointManager]::SecurityProtocol = $tls
} catch { }

# Parse so lieu luon dung InvariantCulture (spec 2.3 - may dat dau phay thap phan)
$Script:WcInv = [Globalization.CultureInfo]::InvariantCulture
$Script:WcMutex = $null          # mutex single-instance (01-Environment set)

function Get-WCName { return $Script:WcName }
function Get-WCVersion { return $Script:WcVersion }
function Get-WCBuildHash { return $Script:WcBuild }
function Get-WCSelfUrl { if ($Script:WcSelfUrl) { return $Script:WcSelfUrl } else { return $Script:WcSelfUrlDefault } }
function Test-WCSelfUrlPlaceholder { return ((Get-WCSelfUrl) -like '*WINCARE-PLACEHOLDER*') }

function Get-WCDataRoot {
    # Mot thu muc du lieu duy nhat (spec 2.4): %ProgramData%\WinCare
    $root = Join-Path $env:ProgramData $Script:WcName
    return $root
}

function Get-WCState {
    # Truy cap bien script an toan o CA hai moi truong: UI session ($Script:) va
    # worker runspace (InitialSessionState dat bien vao scope Global - spec 2.2)
    param([Parameter(Mandatory)][string]$Name)
    $v = Get-Variable -Name $Name -Scope Script -ErrorAction SilentlyContinue
    if ($v) { return $v.Value }
    $v = Get-Variable -Name $Name -Scope Global -ErrorAction SilentlyContinue
    if ($v) { return $v.Value }
    return $null
}

function Write-WCDebugMsg {
    param([string]$Message)
    if ($Script:WcDebug) { Write-WCLog -Level 'DEBUG' -Text $Message }
}


# ============================================================================
# REGION: 01-Environment.ps1
# ============================================================================

# ============================================================================
#  src/01-Environment.ps1 - Kiem tra moi truong, tu nang quyen Admin, mutex
# ============================================================================

function Test-WCPlatform {
    # Tra ve $true neu moi truong dat yeu cau; neu khong dat -> hien loi ro rang
    # Windows 10 1809 (build 17763) tro len, 64-bit, PS 5.1+, co WPF (spec 2.1)
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
        return (New-WCResult -Status 'Bad' -Reason (T 'boot.err.notwindows'))
    }
    $ver = [Environment]::OSVersion.Version
    if (($ver.Major -lt 10) -or (($ver.Major -eq 10) -and ($ver.Build -lt 17763))) {
        return (New-WCResult -Status 'Bad' -Reason ("Windows 10 1809+ / Windows 11 can thiet. Phat hien: build $($ver.Build)" ))
    }
    if (-not [Environment]::Is64BitOperatingSystem) {
        return (New-WCResult -Status 'Bad' -Reason (T 'boot.err.64bit'))
    }
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        return (New-WCResult -Status 'Bad' -Reason (T 'boot.err.ps5'))
    }
    # WPF: PresentationFramework phai nap duoc (khong co tren PowerShell 6 hoac Linux)
    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
        Add-Type -AssemblyName PresentationCore -ErrorAction Stop
        Add-Type -AssemblyName WindowsBase -ErrorAction Stop
        Add-Type -AssemblyName System.Xaml -ErrorAction Stop
    } catch {
        return (New-WCResult -Status 'Bad' -Reason ((T 'boot.err.wpf') + ' [' + $_.Exception.Message + ']'))
    }
    return (New-WCResult -Status 'Ok' -Data $true)
}

function Get-WCIsAdmin {
    # Kiem tra theo WindowsBuiltInRole::Administrator, KHONG theo ten nhom (spec 2.1)
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-WCElevation {
    # Tu xin quyen Admin (spec 2.1). Neu SelfUrl la placeholder -> huong dan bang tay.
    # Tra ve $true neu da la Admin hoac da relaunch (goi nay ket thuc tien trinh hien tai).
    if (Get-WCIsAdmin) { return $true }

    $url = Get-WCSelfUrl
    if (Test-WCSelfUrlPlaceholder) {
        # Khong co URL that -> khong the tu relaunch; huong dan than thien
        $msg = (T 'boot.elev.manual') -f $url
        try { [Windows.MessageBox]::Show($msg, $Script:WcName, [Windows.MessageBoxButton]::OK, [Windows.MessageBoxImage]::Information) | Out-Null } catch { Write-Output $msg }
        return $false
    }
    $cmd = "irm '$url' | iex"
    try {
        Start-Process -FilePath 'powershell.exe' `
            -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-STA','-WindowStyle','Hidden','-Command', $cmd) `
            -Verb RunAs -ErrorAction Stop
        return $true
    } catch {
        # UAC bi tu choi -> thong bao than thien, khong treo, khong do lo (spec 2.1)
        try { [Windows.MessageBox]::Show((T 'boot.elev.declined'), $Script:WcName, [Windows.MessageBoxButton]::OK, [Windows.MessageBoxImage]::Information) | Out-Null } catch { }
        return $false
    }
}

function Initialize-WCSingleInstance {
    # Mot instance duy nhat (Mutex ten co dinh). Lan 2 -> dua cua so cu len truoc (spec 2.1)
    $created = $false
    $mutex = New-Object System.Threading.Mutex($true, 'Global\WinCare_SingleInstance', [ref]$created)
    if ($created) {
        $Script:WcMutex = $mutex
        return $true
    }
    # Da co instance: tim cua so WinCare va dua len truoc
    try {
        Add-WCNativeType
        [WinCare.Native]::ActivateExistingWindow($Script:WcName)
    } catch { }
    try { $mutex.ReleaseMutex() } catch { }
    $mutex.Dispose()
    return $false
}

function Test-WCSTA {
    # WPF can STA tren UI thread
    $state = [Threading.Thread]::CurrentThread.ApartmentState
    return ($state -eq [Threading.ApartmentState]::STA)
}


# ============================================================================
# REGION: 02-Data.ps1
# ============================================================================

# ============================================================================
#  src/02-Data.ps1 - Thu muc du lieu, settings, logging (thread-safe)
# ============================================================================

if (-not ('WinCare.CoreUtil' -as [type])) {
    Add-Type -TypeDefinition @'
using System.Collections.Concurrent;
using System.Collections;

namespace WinCare {
    public static class CoreUtil {
        public static readonly object LogLock = new object();
    }

    // Message worker -> UI (khong dung scriptblock qua runspace - ngai deadlock)
    public class TaskMessage {
        public string Type;   // Progress | Log | Data
        public string Text;
        public int Pct;
    }

    // Ng canh bao huy + hang doi ket qua, goi duoc tu bat ky runspace nao
    public class TaskContext {
        public string Id;
        public System.Threading.ManualResetEvent CancelEvent;
        public ConcurrentQueue<TaskMessage> Queue;
        public void Post(TaskMessage m) { Queue.Enqueue(m); }
        public void Progress(int pct, string text) {
            TaskMessage m = new TaskMessage(); m.Type = "Progress"; m.Pct = pct; m.Text = text; Queue.Enqueue(m);
        }
        public void Log(string text) {
            TaskMessage m = new TaskMessage(); m.Type = "Log"; m.Text = text; Queue.Enqueue(m);
        }
        public bool Cancelled() { return CancelEvent.WaitOne(0); }
    }
}
'@
}

function Initialize-WCData {
    # Tao cay thu muc: %ProgramData%\WinCare\{logs, backups, reports}
    $root = Get-WCDataRoot
    foreach ($sub in @('', 'logs', 'backups', 'reports')) {
        $p = if ($sub -eq '') { $root } else { Join-Path $root $sub }
        if (-not (Test-Path -LiteralPath $p)) {
            New-Item -Path $p -ItemType Directory -Force | Out-Null
        }
    }
    $Script:WcLogFile = Join-Path $root ('logs\wincare-' + (Get-Date -Format 'yyyy-MM-dd') + '.log')
}

function Get-WCLogPath { return $Script:WcLogFile }

function Write-WCLog {
    # Log dong thoi an toan nhieu thread (worker runspace + UI). KHONG ghi du lieu nhay cam.
    param(
        [string]$Level = 'INFO',
        [string]$Text = ''
    )
    try {
        $logFile = Get-WCState 'WcLogFile'
        if (-not $logFile) { return }
        $line = ('{0} [{1}] [{2}] {3}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $PID, $Text)
        [Threading.Monitor]::Enter([WinCare.CoreUtil]::LogLock)
        try {
            [IO.File]::AppendAllText($logFile, $line + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false)))
        } finally {
            [Threading.Monitor]::Exit([WinCare.CoreUtil]::LogLock)
        }
    } catch { }
}

function Open-WCDataFolder {
    try { Start-Process explorer.exe -ArgumentList (Get-WCDataRoot) } catch { Show-WCError (T 'common.cannotopen') $_.Exception.Message }
}

function Remove-WCAllData {
    # Nut "Xoa du lieu WinCare" (spec 2.4) - xoa toan bo logs/journal/backups/settings
    $root = Get-WCDataRoot
    if (Test-Path -LiteralPath $root) {
        Get-ChildItem -LiteralPath $root -Force -ErrorAction SilentlyContinue | ForEach-Object {
            # Log file dang mo boi chinh app: bo qua file log hom nay
            if ($_.FullName -ne $Script:WcLogFile) {
                Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# ---------------------------------------------------------------------------
# Settings (settings.json trong thu muc du lieu)
# ---------------------------------------------------------------------------
function Get-WCSettingsPath { return (Join-Path (Get-WCDataRoot) 'settings.json') }

function Load-WCSettings {
    $Script:WcSettings = @{
        lang = 'vi'; theme = 'system'; dryRun = $false; expert = $false
        maskSensitive = $true; firstRunDone = $false; serviceTimeoutMin = 0
    }
    $path = Get-WCSettingsPath
    if (Test-Path -LiteralPath $path) {
        try {
            $json = [IO.File]::ReadAllText($path)
            $obj = ConvertFrom-Json $json
            foreach ($k in @('lang','theme','dryRun','expert','maskSensitive','firstRunDone','serviceTimeoutMin')) {
                $p = $obj.PSObject.Properties[$k]
                if ($p) { $Script:WcSettings[$k] = $p.Value }
            }
        } catch { Write-WCLog 'WARN' ('settings.json hong -> dung mac dinh: ' + $_.Exception.Message) }
    }
    # Bien moi truong de cao hon file cau hinh
    if ($Script:WcLang) { $Script:WcSettings['lang'] = $Script:WcLang }
    if ($Script:WcDryRun) { $Script:WcSettings['dryRun'] = $true }
}

function Save-WCSettings {
    try {
        $json = ConvertTo-Json $Script:WcSettings -Depth 4
        [IO.File]::WriteAllText((Get-WCSettingsPath), $json, (New-Object Text.UTF8Encoding($false)))
    } catch { Write-WCLog 'WARN' ('Khong luu duoc settings: ' + $_.Exception.Message) }
}

function Get-WCSetting {
    param([string]$Key)
    $s = Get-WCState 'WcSettings'
    if ($s -and $s.ContainsKey($Key)) { return $s[$Key] }
    return $null
}

function Set-WCSetting {
    param([string]$Key, $Value)
    $Script:WcSettings[$Key] = $Value
    Save-WCSettings
}
function Test-WCExpertMode  { return [bool](Get-WCSetting 'expert') }
function Test-WCDryRunMode  { return [bool](Get-WCSetting 'dryRun') }
function Test-WCMaskMode    { return [bool](Get-WCSetting 'maskSensitive') }


# ============================================================================
# REGION: 03-L10n.ps1
# ============================================================================

# ============================================================================
#  src/03-L10n.ps1 - Ngon ngu tieng Viet (mac dinh) / English
#  Moi module tu dang ky chuoi cua minh bang Register-WCStrings (spec 0)
# ============================================================================

$Script:WcL10n = @{ vi = @{}; en = @{} }

function Register-WCStrings {
    # Dang ky bang chuoi cho 1 ngon ngu. Vi du:
    #   Register-WCStrings 'vi' @{ 'm1.title' = 'Toi uu RAM' }
    param([Parameter(Mandatory)][string]$Lang, [Parameter(Mandatory)]$Strings)
    if (-not $Script:WcL10n.ContainsKey($Lang)) { $Script:WcL10n[$Lang] = @{} }
    foreach ($k in @($Strings.Keys)) { $Script:WcL10n[$Lang][$k] = $Strings[$k] }
}

function T {
    # Lay chuoi theo ngon ngu hien hanh; thieu -> fallback vi -> tra ve key
    param([Parameter(Mandatory)][string]$Key, [object[]]$Fmt)
    $lang = 'vi'
    $s = Get-WCState 'WcSettings'
    if ($s -and $s.ContainsKey('lang')) { $lang = [string]$s['lang'] }
    $l10n = Get-WCState 'WcL10n'
    if (-not ($l10n -and $l10n.ContainsKey($lang))) { $lang = 'vi' }
    $str = $null
    if ($l10n -and $l10n[$lang].ContainsKey($Key)) { $str = $l10n[$lang][$Key] }
    elseif ($l10n -and $l10n['vi'].ContainsKey($Key)) { $str = $l10n['vi'][$Key] }
    if ($null -eq $str) {
        Write-WCLog 'WARN' ('Thieu key i18n: ' + $Key)
        return $Key
    }
    if ($Fmt -and $Fmt.Count -gt 0) {
        try { return ($str -f $Fmt) } catch { return $str }
    }
    return $str
}

function Set-WCLanguage {
    param([string]$Lang = 'vi')
    if ($Lang -ne 'vi' -and $Lang -ne 'en') { $Lang = 'vi' }
    Set-WCSetting 'lang' $Lang
}

# ---------------------------------------------------------------------------
# Chuoi dung chung toan app
# ---------------------------------------------------------------------------
Register-WCStrings 'vi' @{
    'common.scan' = 'Quét'
    'common.rescan' = 'Quét lại'
    'common.review' = 'Xem lại'
    'common.confirm' = 'Xác nhận'
    'common.run' = 'Chạy'
    'common.cancel' = 'Hủy'
    'common.close' = 'Đóng'
    'common.copy' = 'Sao chép'
    'common.copied' = 'Đã sao chép'
    'common.open' = 'Mở'
    'common.openlocation' = 'Mở vị trí'
    'common.refresh' = 'Làm mới'
    'common.loading' = 'Đang tải…'
    'common.empty' = 'Không có gì cần làm'
    'common.empty.hint' = 'Máy đang ổn, chưa cần tối ưu gì cả.'
    'common.error' = 'Có lỗi'
    'common.success' = 'Hoàn tất'
    'common.yes' = 'Có'
    'common.no' = 'Không'
    'common.details' = 'Chi tiết kỹ thuật'
    'common.undo' = 'Hoàn tác'
    'common.export' = 'Xuất'
    'common.search' = 'Tìm kiếm…'
    'common.all' = 'Tất cả'
    'common.unknown' = 'Không xác định'
    'common.na' = 'N/A'
    'common.notread' = 'Không đọc được'
    'common.notread.fmt' = 'Không đọc được: {0}'
    'common.nodata' = 'Không đủ dữ liệu'
    'common.selected' = 'Đã chọn: {0}'
    'common.total' = 'Tổng cộng'
    'common.risk.recommended' = 'KHUYẾN NGHỊ'
    'common.risk.advanced' = 'NÂNG CAO'
    'common.risk.risky' = 'RỦI RO'
    'common.risk.recommended.hint' = 'Hoàn tác được hoặc tự tái tạo, không ảnh hưởng ổn định'
    'common.risk.advanced.hint' = 'Có hiệu ứng phụ tạm thời (giật nhẹ, tải lại cache), không mất dữ liệu'
    'common.risk.risky.hint' = 'Có thể không hoàn tác được hoặc đổi chức năng; cần xác nhận 2 bước'
    'common.status.ok' = 'Tốt'
    'common.status.warn' = 'Cần xem'
    'common.status.bad' = 'Có vấn đề'
    'common.status.unknown' = 'Không rõ'
    'common.confirm.title' = 'Xác nhận thao tác'
    'common.confirm.run' = 'Chạy'
    'common.confirm.undone' = 'Hoàn tác được:'
    'common.confirm.notundone' = 'KHÔNG hoàn tác được:'
    'common.confirm.twostep' = 'Đây là thao tác RỦI RO. Bấm lần nữa để xác nhận.'
    'common.cannotopen' = 'Không mở được'
    'common.clipboard.fail' = 'Không sao chép được vào clipboard'
    'common.running' = 'Đang chạy: {0}'
    'common.task.cancelling' = 'Đang hủy…'
    'common.task.cancelled' = 'Đã hủy'
    'common.task.done' = 'Xong'
    'common.task.failed' = 'Thất bại'
    'common.dryrun.header' = 'DRY-RUN: sẽ làm (không thực hiện)'
    'common.expert.cmd' = 'Lệnh sẽ chạy'
    'common.beta' = 'Beta / chưa kiểm chứng runtime'
    'common.before' = 'Trước'
    'common.after' = 'Sau'
    'common.progress' = 'Tiến độ'
    'common.elapsed' = 'Đã chạy'
    'common.retry' = 'Thử lại'
    'boot.err.notwindows' = 'WinCare chỉ chạy trên Windows 10/11. Phát hiện hệ điều hành khác.'
    'boot.err.64bit' = 'WinCare hỗ trợ Windows 64-bit.'
    'boot.err.ps5' = 'Cần Windows PowerShell 5.1 trở lên.'
    'boot.err.wpf' = 'Không tải được WPF (PresentationFramework). Có thể bạn đang dùng PowerShell 6 (không có WPF) — hãy dùng Windows PowerShell 5.1 hoặc PowerShell 7.'
    'boot.elev.manual' = "WinCare cần quyền Admin.`nCách 1: mở PowerShell bằng cách chuột phải → 'Run as Administrator', rồi dán:`n    irm '{0}' | iex`nCách 2: đặt biến môi trường WINCARE_SELFURL trỏ tới URL script rồi chạy lại từ cửa sổ thường."
    'boot.elev.declined' = 'Bạn đã từ chối UAC. WinCare cần quyền Admin để đọc thông số phần cứng và tối ưu. Chạy lại khi sẵn sàng.'
    'boot.alreadyrunning' = 'WinCare đang chạy. Cửa sổ cũ đã được đưa lên trước.'
    'boot.firstrun.title' = 'Chào mừng đến WinCare'
    'boot.firstrun.line1' = 'WinCare giúp tối ưu RAM, dọn ổ cứng, kiểm tra driver, bảo mật, sức khỏe máy — trung thực, không phóng đại.'
    'boot.firstrun.line2' = 'Không gửi bất kỳ dữ liệu nào ra ngoài (không telemetry).'
    'boot.firstrun.line3' = 'Mọi thao tác quét đều chỉ-đọc; mọi thay đổi đều phải qua bạn xác nhận và được ghi nhật ký.'
    'boot.firstrun.start' = 'Bắt đầu'
    'fmt.seconds' = '{0} giây'
    'fmt.minutes' = '{0} phút'
    'fmt.hours' = '{0} giờ'
    'fmt.days' = '{0} ngày'
    'journal.noundo' = 'Mục này không thể hoàn tác tự động (xem hướng dẫn trong chi tiết).'
    'journal.title' = 'Lịch sử & Hoàn tác'
    'journal.empty' = 'Chưa có thay đổi nào được ghi lại.'
    'journal.module' = 'Module'
    'journal.action' = 'Hành động'
    'journal.target' = 'Đối tượng'
    'journal.time' = 'Thời gian'
    'journal.result' = 'Kết quả'
    'journal.result.pending' = 'Đang chờ'
    'journal.result.ok' = 'Đã làm'
    'journal.result.undone' = 'Đã hoàn tác'
    'journal.result.autorestored' = 'Đã tự khôi phục'
    'journal.export' = 'Xuất nhật ký'
    'journal.clear' = 'Xóa dữ liệu WinCare'
    'journal.clear.confirm' = "Xóa TOÀN BỘ dữ liệu WinCare (nhật ký, sao lưu driver, cài đặt) trong %ProgramData%\WinCare?`nHành động này KHÔNG hoàn tác được."
}
Register-WCStrings 'en' @{
    'common.scan' = 'Scan'
    'common.rescan' = 'Rescan'
    'common.review' = 'Review'
    'common.confirm' = 'Confirm'
    'common.run' = 'Run'
    'common.cancel' = 'Cancel'
    'common.close' = 'Close'
    'common.copy' = 'Copy'
    'common.copied' = 'Copied'
    'common.open' = 'Open'
    'common.openlocation' = 'Open location'
    'common.refresh' = 'Refresh'
    'common.loading' = 'Loading…'
    'common.empty' = 'Nothing to do'
    'common.empty.hint' = 'Your PC is fine — no action needed.'
    'common.error' = 'Error'
    'common.success' = 'Done'
    'common.yes' = 'Yes'
    'common.no' = 'No'
    'common.details' = 'Technical details'
    'common.undo' = 'Undo'
    'common.export' = 'Export'
    'common.search' = 'Search…'
    'common.all' = 'All'
    'common.unknown' = 'Unknown'
    'common.na' = 'N/A'
    'common.notread' = 'Cannot read'
    'common.notread.fmt' = 'Cannot read: {0}'
    'common.nodata' = 'Not enough data'
    'common.selected' = 'Selected: {0}'
    'common.total' = 'Total'
    'common.risk.recommended' = 'RECOMMENDED'
    'common.risk.advanced' = 'ADVANCED'
    'common.risk.risky' = 'RISKY'
    'common.risk.recommended.hint' = 'Reversible or self-rebuilding, no stability impact'
    'common.risk.advanced.hint' = 'Temporary side effects (minor stutter, cache rebuild), no data loss'
    'common.risk.risky.hint' = 'May be irreversible or change behavior; requires double confirmation'
    'common.status.ok' = 'Good'
    'common.status.warn' = 'Review'
    'common.status.bad' = 'Problem'
    'common.status.unknown' = 'Unclear'
    'common.confirm.title' = 'Confirm action'
    'common.confirm.run' = 'Run'
    'common.confirm.undone' = 'Undoable:'
    'common.confirm.notundone' = 'NOT undoable:'
    'common.confirm.twostep' = 'This is a RISKY action. Click again to confirm.'
    'common.cannotopen' = 'Cannot open'
    'common.clipboard.fail' = 'Could not copy to clipboard'
    'common.running' = 'Running: {0}'
    'common.task.cancelling' = 'Cancelling…'
    'common.task.cancelled' = 'Cancelled'
    'common.task.done' = 'Done'
    'common.task.failed' = 'Failed'
    'common.dryrun.header' = 'DRY-RUN: would do (not executing)'
    'common.expert.cmd' = 'Command to run'
    'common.beta' = 'Beta / not runtime-verified'
    'common.before' = 'Before'
    'common.after' = 'After'
    'common.progress' = 'Progress'
    'common.elapsed' = 'Elapsed'
    'common.retry' = 'Retry'
    'boot.err.notwindows' = 'WinCare runs on Windows 10/11 only.'
    'boot.err.64bit' = 'WinCare supports 64-bit Windows.'
    'boot.err.ps5' = 'Windows PowerShell 5.1+ required.'
    'boot.err.wpf' = 'Cannot load WPF (PresentationFramework). You may be on PowerShell 6 (no WPF) — use Windows PowerShell 5.1 or PowerShell 7.'
    'boot.elev.manual' = "WinCare needs Admin rights.`nOption 1: right-click PowerShell → 'Run as Administrator', then paste:`n    irm '{0}' | iex`nOption 2: set WINCARE_SELFURL to the script URL and run again."
    'boot.elev.declined' = 'UAC declined. WinCare needs Admin rights to read hardware info and optimize. Run again when ready.'
    'boot.alreadyrunning' = 'WinCare is already running. The existing window was brought to front.'
    'boot.firstrun.title' = 'Welcome to WinCare'
    'boot.firstrun.line1' = 'WinCare optimizes RAM, cleans disks, checks drivers, security and health — honestly, no hype.'
    'boot.firstrun.line2' = 'Nothing is ever sent out (no telemetry).'
    'boot.firstrun.line3' = 'All scans are read-only; every change requires your confirmation and is journaled.'
    'boot.firstrun.start' = 'Start'
    'fmt.seconds' = '{0}s'
    'fmt.minutes' = '{0} min'
    'fmt.hours' = '{0}h'
    'fmt.days' = '{0} days'
    'journal.noundo' = 'This entry cannot be auto-undone (see details).'
    'journal.title' = 'History & Undo'
    'journal.empty' = 'No changes recorded yet.'
    'journal.module' = 'Module'
    'journal.action' = 'Action'
    'journal.target' = 'Target'
    'journal.time' = 'Time'
    'journal.result' = 'Result'
    'journal.result.pending' = 'Pending'
    'journal.result.ok' = 'Done'
    'journal.result.undone' = 'Undone'
    'journal.result.autorestored' = 'Auto-restored'
    'journal.export' = 'Export journal'
    'journal.clear' = 'Delete WinCare data'
    'journal.clear.confirm' = "Delete ALL WinCare data (journal, driver backups, settings) in %ProgramData%\WinCare?`nThis action is NOT undoable."
}


# ============================================================================
# REGION: 04-Safety.ps1
# ============================================================================

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
        $c.Add((Join-Path $env:SystemRoot 'Windows.old'))
    }
    if ($env:ProgramData) {
        $c.Add((Join-Path $env:ProgramData ('Microsoft' + '\' + 'Windows' + '\' + 'WER')))
        $c.Add((Join-Path $env:ProgramData ('Microsoft' + '\' + 'Windows Defender' + '\' + 'Scans')))
    }
    if ($env:LOCALAPPDATA) {
        $c.Add((Join-Path $env:LOCALAPPDATA 'CrashDumps'))
        $c.Add((Join-Path $env:LOCALAPPDATA 'D3DSCache'))                     # shader cache DirectX
        $c.Add((Join-Path $env:LOCALAPPDATA ('NVIDIA' + '\' + 'GLCache')))    # shader cache NVIDIA
        $c.Add((Join-Path $env:LOCALAPPDATA ('Mozilla' + '\' + 'Firefox' + '\' + 'Profiles')))
        $c.Add((Join-Path $env:LOCALAPPDATA ('Spotify' + '\' + 'Storage')))
        # Browser cache (CHI muc cache, tuyet doi khong cookie/mat khau/lich su)
        foreach ($b in @('Google\Chrome','Microsoft\Edge','BraveSoftware\Brave-Browser')) {
            $c.Add((Join-Path $env:LOCALAPPDATA ($b + '\' + 'User Data')))
        }
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
        # Khong di qua reparse point (junction/symlink) o bat ky cap nao
        $cur = ''
        foreach ($seg in ($fullTrim -split '[\\/]')) {
            if ([string]::IsNullOrEmpty($seg)) { continue }
            if ($cur -eq '') { $cur = $seg } else { $cur = [IO.Path]::Combine($cur, $seg) }
            if ((Test-WCPathIsReparsePoint $cur) -and ($cur -ine $fullTrim)) {
                Write-WCLog 'SAFETY' ('Tu choi (junction/symlink): ' + $cur); return $false
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


# ============================================================================
# REGION: 05-Journal.ps1
# ============================================================================

# ============================================================================
#  src/05-Journal.ps1 - Nhat ky thay doi + hoan tac (spec 2.4)
#  Ghi MOI thay doi: thoi gian, module, hanh dong, doi tuong, gia tri cu,
#  cach hoan tac, ket qua. Man "Lich su & Hoan tac" doc tu day.
# ============================================================================

$Script:WcJournalPath = $null
$Script:WcUndoHandlers = @{}   # undoType -> scriptblock(param($entry))
$Script:WcJournalSessionRestored = $false

function Initialize-WCJournal {
    $Script:WcJournalPath = Join-Path (Get-WCDataRoot) 'journal.json'
    if (-not (Test-Path -LiteralPath $Script:WcJournalPath)) {
        Save-WCJournal @()
    }
    # Phat hien entry "tu phuc hoi" con sot lai tu phien truoc (spec M1: dich vu dung tam
    # phai duoc khoi phuc ke ca khi thoat app dot ngot)
    Restore-WCSessionScopedEntries
}

function Get-WCJournal {
    try {
        $json = [IO.File]::ReadAllText($Script:WcJournalPath)
        $entries = ConvertFrom-Json $json
        if ($null -eq $entries) { return @() }
        if ($entries -is [array]) { return $entries }
        return @($entries)
    } catch {
        Write-WCLog 'WARN' ('journal.json hong -> khoi tao lai: ' + $_.Exception.Message)
        return @()
    }
}

function Save-WCJournal {
    param([Parameter(Mandatory)]$Entries)
    try {
        # Giu toi da 500 entry moi nhat de file khong phinh to
        $list = @($Entries)
        if ($list.Count -gt 500) { $list = $list[($list.Count - 500)..($list.Count - 1)] }
        $json = ConvertTo-Json $list -Depth 6
        [IO.File]::WriteAllText($Script:WcJournalPath, $json, (New-Object Text.UTF8Encoding($false)))
    } catch { Write-WCLog 'WARN' ('Khong luu duoc journal: ' + $_.Exception.Message) }
}

function Add-WCJournalEntry {
    # Vi du:
    #   Add-WCJournalEntry -Module 'M1' -Action 'Stop service' -Target 'SysMain' `
    #     -UndoType 'service.start' -UndoArgs @{ Name='SysMain'; StartType='Automatic' } -AutoRestore $true
    param(
        [Parameter(Mandatory)][string]$Module,
        [Parameter(Mandatory)][string]$Action,
        [Parameter(Mandatory)][string]$Target,
        [string]$OldValue = '',
        [string]$UndoType = '',          # '' = khong the hoan tac tu dong
        $UndoArgs = $null,
        [switch]$AutoRestore             # tu phuc hoi khi thoat app / mo lai
    )
    $entry = [PSCustomObject]@{
        Id = [Guid]::NewGuid().ToString('N')
        Time = (Get-Date).ToString('o')
        Module = $Module
        Action = $Action
        Target = $Target
        OldValue = $OldValue
        UndoType = $UndoType
        UndoArgs = $UndoArgs
        AutoRestore = [bool]$AutoRestore
        Result = 'Pending'
    }
    $all = @(Get-WCJournal)
    $all += $entry
    Save-WCJournal $all
    Write-WCLog 'JOURNAL' ('{0} | {1} | {2} | undo={3}' -f $Module, $Action, $Target, $UndoType)
    return $entry
}

function Complete-WCJournalEntry {
    param([Parameter(Mandatory)]$Entry, [string]$Result = 'Ok')
    $all = @(Get-WCJournal)
    foreach ($e in $all) {
        if ((Get-WCProp $e 'Id') -eq $Entry.Id) {
            $e.Result = $Result
            break
        }
    }
    Save-WCJournal $all
}

function Register-WCUndoHandler {
    param([Parameter(Mandatory)][string]$UndoType, [Parameter(Mandatory)][scriptblock]$Handler)
    $Script:WcUndoHandlers[$UndoType] = $Handler
}

function Undo-WCJournalEntry {
    # Hoan tac 1 entry neu co handler. Tra ve @{ Ok; Message }
    param([Parameter(Mandatory)]$Entry)
    $type = [string](Get-WCProp $Entry 'UndoType')
    if ([string]::IsNullOrEmpty($type)) { return @{ Ok = $false; Message = (T 'journal.noundo') } }
    $handler = $null
    if ($Script:WcUndoHandlers.ContainsKey($type)) { $handler = $Script:WcUndoHandlers[$type] }
    if (-not $handler) { return @{ Ok = $false; Message = (T 'journal.noundo') } }
    try {
        $r = & $handler $Entry
        $all = @(Get-WCJournal)
        foreach ($e in $all) {
            if ((Get-WCProp $e 'Id') -eq (Get-WCProp $Entry 'Id')) { $e.Result = 'Undone'; break }
        }
        Save-WCJournal $all
        return @{ Ok = $true; Message = (T 'common.success') }
    } catch {
        Write-WCLog 'WARN' ('Hoan tac that bai: ' + $_.Exception.Message)
        return @{ Ok = $false; Message = $_.Exception.Message }
    }
}

function Restore-WCSessionScopedEntries {
    # Khoi phuc cac entry AutoRestore=True chua undone (dich vu dung tam...) - chay 1 lan khi khoi dong
    if ($Script:WcJournalSessionRestored) { return }
    $Script:WcJournalSessionRestored = $true
    $all = @(Get-WCJournal)
    $pending = @($all | Where-Object { ($_.AutoRestore -eq $true) -and ($_.Result -eq 'Ok') })
    if ($pending.Count -eq 0) { return }
    Write-WCLog 'JOURNAL' ('Phat hien ' + $pending.Count + ' entry can tu phuc hoi tu phien truoc')
    $changed = $false
    foreach ($e in $pending) {
        $type = [string](Get-WCProp $e 'UndoType')
        if ($Script:WcUndoHandlers.ContainsKey($type)) {
            try {
                & $Script:WcUndoHandlers[$type] $e | Out-Null
                $e.Result = 'AutoRestored'
                $changed = $true
                Write-WCLog 'JOURNAL' ('Da tu phuc hoi: ' + $e.Target)
            } catch { Write-WCLog 'WARN' ('Tu phuc hoi that bai: ' + $e.Target + ' -> ' + $_.Exception.Message) }
        }
    }
    if ($changed) { Save-WCJournal $all }
}

function Restore-WCPendingSessionEntries {
    # Goi khi THOAT app: phuc hoi moi entry AutoRestore con 'Ok'
    $all = @(Get-WCJournal)
    $pending = @($all | Where-Object { ($_.AutoRestore -eq $true) -and ($_.Result -eq 'Ok') })
    foreach ($e in $pending) {
        $type = [string](Get-WCProp $e 'UndoType')
        if ($Script:WcUndoHandlers.ContainsKey($type)) {
            try {
                & $Script:WcUndoHandlers[$type] $e | Out-Null
                $e.Result = 'AutoRestored'
                Write-WCLog 'JOURNAL' ('Thoat app -> da phuc hoi: ' + $e.Target)
            } catch { Write-WCLog 'WARN' ('Phuc hoi khi thoat that bai: ' + $e.Target) }
        }
    }
    if ($pending.Count -gt 0) { Save-WCJournal $all }
}

# ---------------------------------------------------------------------------
# Cac undo handler co ban dang ky san
# ---------------------------------------------------------------------------
Register-WCUndoHandler 'service.start' {
    # Khoi phuc dich vu bi dung tam (M1 che do 3)
    param($Entry)
    $args2 = $Entry.UndoArgs
    $name = [string](Get-WCProp $args2 'Name')
    $startType = [string](Get-WCProp $args2 'StartType')
    if ($name) {
        $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -ne 'Running') {
            Start-Service -Name $name -ErrorAction Stop
        }
        if ($startType -and $svc) {
            # Khoi phuc dung kieu khoi dong goc
            Set-Service -Name $name -StartupType $startType -ErrorAction SilentlyContinue
        }
    }
}

Register-WCUndoHandler 'hibernate.on' {
    # Khoi phuc ngu dong sau khi "tat ngu dong" (M2 muc RUI RO, dao nguoc duoc)
    param($Entry)
    Start-Process -FilePath 'powercfg.exe' -ArgumentList @('/h','on') -WindowStyle Hidden -Wait
}

Register-WCUndoHandler 'startup.enable' {
    # Bat lai muc khoi dong da tat qua StartupApproved (M5/M7, nhu Task Manager)
    param($Entry)
    $args2 = $Entry.UndoArgs
    $regPath = [string](Get-WCProp $args2 'RegPath')
    $valueName = [string](Get-WCProp $args2 'ValueName')
    if ($regPath -and $valueName) {
        $bytes = [byte[]]@(0,0,0,0,0,0,0,0,0,0,0,0)   # 12 byte 0 = dang BAT (nhu Task Manager)
        [Microsoft.Win32.Registry]::SetValue($regPath, $valueName, [byte[]]$bytes, [Microsoft.Win32.RegistryValueKind]::Binary)
    }
}


# ============================================================================
# REGION: 06-TaskRunner.ps1
# ============================================================================

# ============================================================================
#  src/06-TaskRunner.ps1 - Task runner nen (runspace + queue + DispatcherTimer)
#  UI thread chi ve; viec > 100ms chay o runspace nen; ket qua ve qua
#  ConcurrentQueue, UI rut hang bang DispatcherTimer (spec 2.2).
#  Runspace nen KHONG thay scope cha -> nap ham bang InitialSessionState.
#  KHONG truyen scriptblock qua ranh gioi runspace (ngai deadlock): worker duoc
#  truyen duoi dang TEXT va bien dich lai trong runspace moi.
# ============================================================================

$Script:WcRunspacePool = $null
$Script:WcTasks = @{}
$Script:WcTaskTimer = $null

function Initialize-WCTaskRunner {
    # Nap toan bo ham cua script vao InitialSessionState de worker goi duoc
    # (SessionStateFunctionEntry - spec 2.2)
    $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    $fnCount = 0
    foreach ($f in (Get-ChildItem Function: -ErrorAction SilentlyContinue)) {
        if ([string]::IsNullOrEmpty($f.ModuleName) -and $f.Definition) {
            try {
                $entry = [System.Management.Automation.Runspaces.SessionStateFunctionEntry]::new($f.Name, $f.Definition)
                $iss.Commands.Add($entry) | Out-Null
                $fnCount++
            } catch { }
        }
    }
    # Bien chia se: hashtable la reference type -> thay doi song voi UI session.
    # Worker lay gia tri thong qua Get-WCState (scope Global cua runspace).
    $shared = @{
        'WcSettings'           = $Script:WcSettings
        'WcL10n'               = $Script:WcL10n
        'WcQueryCache'         = $Script:WcQueryCache
        'WcFixture'            = $Script:WcFixture
        'WcDeleteRoots'        = $Script:WcDeleteRoots
        'WcProtectedProcesses' = $Script:WcProtectedProcesses
        'WcLogFile'            = $Script:WcLogFile
        'WcDebug'              = $Script:WcDebug
        'WcDryRun'             = (Test-WCDryRunMode)
        'WcInv'                = $Script:WcInv
        'WcName'               = $Script:WcName
        'WcVersion'            = $Script:WcVersion
        'WcSelfUrl'            = (Get-WCSelfUrl)
    }
    foreach ($name in @($shared.Keys)) {
        $v = [System.Management.Automation.Runspaces.SessionStateVariableEntry]::new($name, $shared[$name], $null)
        $iss.Variables.Add($v) | Out-Null
    }
    $Script:WcRunspacePool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1, 4, $iss, $Host)
    $Script:WcRunspacePool.ThreadOptions = [System.Management.Automation.Runspaces.PSThreadOptions]::ReuseThread
    $Script:WcRunspacePool.Open()
    Write-WCDebugMsg ('TaskRunner: da nap ' + $fnCount + ' ham vao runspace pool')
}

function Start-WCTaskPump {
    # DispatcherTimer rut hang doi ket qua cua tat ca task (chi tren UI thread)
    $Script:WcTaskTimer = New-Object Windows.Threading.DispatcherTimer
    $Script:WcTaskTimer.Interval = [TimeSpan]::FromMilliseconds(120)
    $Script:WcTaskTimer.Add_Tick({ try { Invoke-WCTaskPumpTick } catch { Write-WCLog 'ERROR' ('Pump tick: ' + $_.Exception.Message) } }.GetNewClosure())
    $Script:WcTaskTimer.Start()
}

function Stop-WCTaskRunner {
    # Don dep khi thoat: huy task, dong pool (spec 2.2 - khong de tien trinh mo coi)
    if ($Script:WcTaskTimer) { $Script:WcTaskTimer.Stop(); $Script:WcTaskTimer = $null }
    foreach ($id in @($Script:WcTasks.Keys)) {
        try {
            $t = $Script:WcTasks[$id]
            if ($t.Ps -and $t.Ps.InvocationStateInfo.State -eq 'Running') { $t.Ps.Stop() }
        } catch { }
    }
    Start-Sleep -Milliseconds 400
    foreach ($id in @($Script:WcTasks.Keys)) {
        try {
            $t = $Script:WcTasks[$id]
            if ($t.Ps) { $t.Ps.Dispose() }
        } catch { }
    }
    $Script:WcTasks = @{}
    if ($Script:WcRunspacePool) {
        try { $Script:WcRunspacePool.Close() } catch { }
        try { $Script:WcRunspacePool.Dispose() } catch { }
        $Script:WcRunspacePool = $null
    }
}

function Start-WCTask {
    # Chay 1 viec o nen. Vi du:
    #   Start-WCTask -Id 'm2.scan' -Title (T 'm2.title') -Worker { param($ctx, $s) ...; return $ketqua } `
    #                -Args @{ DuLieu = 1 } -Done { param($ketqua) ... } -ShowStatus
    # QUAN TRONG (han che ky thuat):
    #   - Worker chay trong runspace rieng: KHONG thay bien local cua ham goi.
    #     Truyen du lieu qua -Args; trong worker khai bao param($ctx, $s).
    #   - Worker khong goi duoc ham o day? CO - moi ham duoc nap qua InitialSessionState.
    #   - Done/OnMessage chay lai tren UI thread: neu tham chieu bien local
    #     cua ham goi thi PHAI .GetNewClosure() khi truyen vao.
    # Worker ($ctx la WinCare.TaskContext):
    #   $ctx.Progress(50,'Dang quet...') ; $ctx.Log('...') ; $ctx.Cancelled() -> nen dung lai va return
    # Ngoai le trong worker bi bat va chuyen ve UI (khong nuot - spec 2.2).
    # Cung 1 Id dang chay -> tra ve $false (chan 2 tac vu chong len nhau - spec muc 6).
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][scriptblock]$Worker,
        $Args = $null,
        [scriptblock]$Done = $null,
        [scriptblock]$OnMessage = $null,
        [switch]$ShowStatus
    )
    if ($Script:WcTasks.ContainsKey($Id)) {
        $existing = $Script:WcTasks[$Id]
        if ($existing.State -eq 'Running') { return $false }
    }
    if (-not $Script:WcRunspacePool) { Initialize-WCTaskRunner }

    $cancelEvent = New-Object System.Threading.ManualResetEvent($false)
    $ctx = New-Object WinCare.TaskContext
    $ctx.Id = $Id
    $ctx.CancelEvent = $cancelEvent
    $ctx.Queue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[WinCare.TaskMessage]'

    # Worker duoc truyen dang TEXT va bien dich lai trong runspace nen (an toan,
    # khong keo session state cu sang runspace moi). $Args truyen du lieu vao.
    $wrapper = @'
param([string]$WorkerText, $TaskCtx, $WorkerArgs)
try { [Threading.Thread]::CurrentThread.Priority = 'BelowNormal' } catch { }
$workerSb = [scriptblock]::Create($WorkerText)
& $workerSb $TaskCtx $WorkerArgs
'@
    $ps = [PowerShell]::Create()
    $ps.RunspacePool = $Script:WcRunspacePool
    $null = $ps.AddScript($wrapper).AddArgument($Worker.ToString()).AddArgument($ctx).AddArgument($Args)
    $handle = $ps.BeginInvoke()

    $Script:WcTasks[$Id] = @{
        Id = $Id; Title = $Title; Ps = $ps; Handle = $handle; Ctx = $ctx
        State = 'Running'; Done = $Done; OnMessage = $OnMessage
        ShowStatus = [bool]$ShowStatus; StartedAt = [DateTime]::Now
        CancelRequested = $false; CancelTicks = 0; Result = $null; Error = $null
    }
    if ($ShowStatus) { Set-WCStatusTask $Title $false }
    Write-WCDebugMsg ('Task bat dau: ' + $Id)
    return $true
}

function Test-WCTaskRunning {
    param([Parameter(Mandatory)][string]$Id)
    if ($Script:WcTasks.ContainsKey($Id)) {
        return ($Script:WcTasks[$Id].State -eq 'Running')
    }
    return $false
}

function Test-WCAnyTaskRunning {
    foreach ($id in @($Script:WcTasks.Keys)) {
        if ($Script:WcTasks[$id].State -eq 'Running') { return $true }
    }
    return $false
}

function Cancel-WCTask {
    param([Parameter(Mandatory)][string]$Id)
    if (-not $Script:WcTasks.ContainsKey($Id)) { return }
    $t = $Script:WcTasks[$Id]
    if ($t.State -ne 'Running') { return }
    $t.CancelRequested = $true
    $t.Ctx.CancelEvent.Set() | Out-Null
    Set-WCStatusTask $t.Title $true
    Write-WCLog 'INFO' ('Da yeu cau huy task: ' + $Id)
}

function Invoke-WCTaskPumpTick {
    $ids = @($Script:WcTasks.Keys)
    foreach ($id in $ids) {
        $t = $Script:WcTasks[$id]
        if ($null -eq $t) { continue }

        # 1) Rut toan bo message worker -> UI (kieu .NET TaskMessage, truy cap thuoc tinh an toan)
        $msg = $null
        while ($t.Ctx.Queue.TryDequeue([ref]$msg)) {
            try {
                if ($msg.Type -eq 'Progress' -and $t.ShowStatus) {
                    $elapsed = [int](([DateTime]::Now - $t.StartedAt).TotalSeconds)
                    Set-WCStatusTask ($t.Title + ' — ' + $msg.Text + ' (' + $msg.Pct + '%, ' + $elapsed + 's)') $t.CancelRequested
                } elseif ($msg.Type -eq 'Log') {
                    Write-WCLog 'WORKER' $msg.Text
                }
                if ($t.OnMessage) { & $t.OnMessage $msg }
            } catch { Write-WCLog 'WARN' ('Xu ly message task that bai: ' + $_.Exception.Message) }
            $msg = $null
        }

        # 2) Chuyen trang thai khi worker ket thuc
        if ($t.State -eq 'Running') {
            $st = $t.Ps.InvocationStateInfo.State
            if (($st -eq 'Completed') -or ($st -eq 'Failed') -or ($st -eq 'Stopped')) {
                $errorText = $null
                try { $t.Result = $t.Ps.EndInvoke($t.Handle) } catch { $errorText = $_.Exception.Message }
                # Thu thom loi tu stream neu co
                if ($t.Ps.Streams.Error.Count -gt 0) {
                    $errorText = [string]$t.Ps.Streams.Error[0]
                }
                if ($t.CancelRequested) { $t.State = 'Cancelled' }
                elseif ($errorText) { $t.State = 'Failed'; $t.Error = $errorText }
                else { $t.State = 'Completed' }
                try { $t.Ps.Dispose() } catch { }
                $t.Ps = $null
                Write-WCDebugMsg ('Task ket thuc: ' + $id + ' -> ' + $t.State)

                if ($t.ShowStatus) { Set-WCStatusTask $null $false }
                if ($t.State -eq 'Completed' -and $t.Done) {
                    # Quy uoc: 1 object duy nhat -> truyen thang; nhieu object -> mang
                    $resultData = $null
                    if ($t.Result) {
                        if ($t.Result.Count -eq 1) { $resultData = $t.Result[0] }
                        elseif ($t.Result.Count -gt 1) { $resultData = @($t.Result) }
                    }
                    try { & $t.Done $resultData } catch { Show-WCError (T 'common.error') $_.Exception.Message }
                } elseif ($t.State -eq 'Failed') {
                    Write-WCLog 'ERROR' ('Task ' + $id + ' that bai: ' + $t.Error)
                    Show-WCError (T 'common.task.failed') $t.Error
                } elseif ($t.State -eq 'Cancelled') {
                    Show-WCToast (T 'common.task.cancelled') 'Info'
                }
            } elseif ($t.CancelRequested) {
                # Sau ~3 giay ma van chay -> ep dung pipeline (worker co the dang cho lenh ngoai)
                $t.CancelTicks++
                if ($t.CancelTicks -ge 25) { try { $t.Ps.Stop() } catch { } }
            }
        }
    }
}


# ============================================================================
# REGION: 07-Query.ps1
# ============================================================================

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


# ============================================================================
# REGION: 08-Interop.ps1
# ============================================================================

# ============================================================================
#  src/08-Interop.ps1 - P/Invoke Win32 (duoc su dung boi M1/M2)
#  NGUYEN TAC (spec 2.5): C# viet de doc, co chu thich, nam trong 1 here-string.
#  Khong neo AMSI/Defender; neu bi chan -> bao loi ro chu khong lach.
#  Chu y: gia tri enum NT xac minh tu tai lieu cong khai (winternl/Process
#  Hacker); CHUA kiem chung runtime tren Windows that (ghi ro trong TEST-REPORT).
# ============================================================================

function Add-WCNativeType {
    if ('WinCare.Native' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace WinCare
{
    public static class Native
    {
        // ---------------- Process / working set (M1) ----------------
        // PROCESS_SET_QUOTA (0x0100) | PROCESS_QUERY_LIMITED_INFORMATION (0x1000)
        public const uint PROCESS_SET_QUOTA = 0x0100;
        public const uint PROCESS_QUERY_LIMITED_INFORMATION = 0x1000;

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern IntPtr OpenProcess(uint dwDesiredAccess, bool bInheritHandle, int dwProcessId);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool CloseHandle(IntPtr hObject);

        // EmptyWorkingSet: thu gom working set cua 1 tien trinh (chung san kernel32)
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool EmptyWorkingSet(IntPtr hProcess);

        // ---------------- Foreground window (M1: khong trim app dang dung truoc) ---
        [DllImport("user32.dll")]
        public static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll")]
        public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

        // ---------------- Cua so (mutex single-instance) ----------------
        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        public static extern IntPtr FindWindowW(string lpClassName, string lpWindowName);

        [DllImport("user32.dll")]
        public static extern bool SetForegroundWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

        public static void ActivateExistingWindow(string title)
        {
            IntPtr h = FindWindowW(null, title);
            if (h != IntPtr.Zero)
            {
                ShowWindow(h, 9 /* SW_RESTORE */);
                SetForegroundWindow(h);
            }
        }

        // ---------------- Trạng thái toàn màn hình / đỡ làm phiền (M1) -------------
        // SHQueryUserNotificationState: 3 = QUNS_RUNNING_D3D_FULL_SCREEN (game),
        // 4 = QUNS_PRESENTATION_MODE (trình chiếu)
        [DllImport("shell32.dll")]
        public static extern int SHQueryUserNotificationState(out int pqunsState);

        public static bool IsFullScreenOrPresentation()
        {
            try
            {
                int state;
                int hr = SHQueryUserNotificationState(out state);
                if (hr == 0) { return (state == 3 || state == 4 || state == 2); } // D3D fullscreen | presentation | busy
            }
            catch { }
            return false;
        }

        // ----------------特权 + memory list (M1 chế độ 2/3) ----------------
        // SeProfileSingleProcessPrivilege = 19 (bien tai lieu cong khai)
        [DllImport("ntdll.dll")]
        public static extern int RtlAdjustPrivilege(uint Privilege, bool Enable, bool CurrentThread, out bool Enabled);

        public static bool EnableProfilePrivilege()
        {
            bool prev;
            int status = RtlAdjustPrivilege(19 /* SeProfileSingleProcessPrivilege */, true, false, out prev);
            return (status == 0);
        }

        // SYSTEM_MEMORY_LIST_INFORMATION = 0x50 (80)
        public const int SystemMemoryListInformation = 0x50;

        // SYSTEM_MEMORY_LIST_COMMANDS (xac minh tu enum cong khai cua Windows):
        //   2 = MemoryEmptyWorkingSets
        //   3 = MemoryFlushModifiedList
        //   4 = MemoryPurgeLowPriorityStandbyList
        //   5 = MemoryPurgeStandbyList
        [DllImport("ntdll.dll")]
        public static extern int NtSetSystemInformation(int SystemInformationClass, ref int SystemInformation, int SystemInformationLength);

        public static int RunMemoryListCommand(int command)
        {
            int info = command;
            int len = sizeof(int);
            return NtSetSystemInformation(SystemMemoryListInformation, ref info, len);
        }

        // ---------------- Helper gom 1 tien trinh ----------------
        public static bool TrimWorkingSet(int pid)
        {
            IntPtr h = OpenProcess(PROCESS_SET_QUOTA | PROCESS_QUERY_LIMITED_INFORMATION, false, pid);
            if (h == IntPtr.Zero) { return false; }
            try { return EmptyWorkingSet(h); }
            finally { CloseHandle(h); }
        }

        public static int GetForegroundPid()
        {
            IntPtr h = GetForegroundWindow();
            if (h == IntPtr.Zero) { return 0; }
            uint pid;
            GetWindowThreadProcessId(h, out pid);
            return (int)pid;
        }
    }
}
'@ -Language CSharp
}

function Send-WCFileToRecycleBin {
    # Chuyen tep/thu muc vao THUNG RAC (du lieu nguoi dung KHONG bao gio xoa vinh vien - spec 2.5)
    param([Parameter(Mandatory)][string]$Path)
    try {
        Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction Stop
        if (Test-Path -LiteralPath $Path -PathType Container) {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(
                $Path, [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)
        } else {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
                $Path, [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)
        }
        return $true
    } catch {
        Write-WCLog 'WARN' ('Recycle bin that bai cho: ' + $Path + ' -> ' + $_.Exception.Message)
        return $false
    }
}

function Get-WCNotificationStateText {
    # Giai thi nghia trang thai thong bao (dung de canh bao game/fullscreen - spec M1)
    Add-WCNativeType
    try {
        $state = 0
        $hr = [WinCare.Native]::SHQueryUserNotificationState([ref]$state)
        if ($hr -ne 0) { return $null }
        switch ($state) {
            2 { return 'busy' }        # QUNS_BUSY - ung dung full man hinh
            3 { return 'fullscreen' }  # QUNS_RUNNING_D3D_FULL_SCREEN - game
            4 { return 'presentation' }# QUNS_PRESENTATION_MODE
            default { return 'normal' }
        }
    } catch { return $null }
}


# ============================================================================
# REGION: 09-UICore.ps1
# ============================================================================

# ============================================================================
#  src/09-UICore.ps1 - Theme, control factory, dialogs, nav registry
#  Moi module XAY DUNG UI bang cac helper o day (khong viet WPF tho).
#  Theme sang/tim theo he thong (AppsUseLightTheme) + doi tay duoc (spec muc 3)
# ============================================================================

$Script:WcShell = $null          # tham chieu cua so chinh
$Script:WcNavItems = [ordered]@{}
$Script:WcNavCurrent = $null
$Script:WcToastTimer = $null
$Script:WcStyles = $null          # style dictionary (parse lan dau)
$Script:WcNavHighlightAction = $null   # shell dang ky de highlight nut nav

# ---------------------------------------------------------------------------
# THEME
# ---------------------------------------------------------------------------
function Get-WCSystemPrefersDark {
    # Doc AppsUseLightTheme (0 = dark); loi -> mac dinh sang (spec muc 3)
    $v = Get-WCRegistryValue -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' -Name 'AppsUseLightTheme'
    if ($null -eq $v) { return $false }
    return ($v -eq 0)
}

function Get-WCThemeIsDark {
    $t = Get-WCSetting 'theme'
    if ($t -eq 'dark') { return $true }
    if ($t -eq 'light') { return $false }
    return (Get-WCSystemPrefersDark)
}

function Get-WCThemePalette {
    param([switch]$Dark)
    if ($Dark) {
        return @{
            WcBg = '#0F1419'; WcCardBg = '#1A2129'; WcCardBg2 = '#151C23'
            WcText = '#E8EDF2'; WcSubtle = '#9AA6B2'; WcBorder = '#2A343E'
            WcAccent = '#35C48D'; WcAccentText = '#06281A'
            WcOk = '#4BD48C'; WcWarn = '#F5B94A'; WcBad = '#F08A8A'; WcUnknown = '#93A0AD'
            WcOkBg = '#12271C'; WcWarnBg = '#2B2110'; WcBadBg = '#2B1515'; WcUnknownBg = '#1D242C'; WcAccentBg = '#10291F'
            WcHover = '#242E39'; WcActive = '#2B3A46'
        }
    }
    return @{
        WcBg = '#F4F5F7'; WcCardBg = '#FFFFFF'; WcCardBg2 = '#FAFBFC'
        WcText = '#1A202C'; WcSubtle = '#5F6B7A'; WcBorder = '#E3E7EC'
        WcAccent = '#0E9F6E'; WcAccentText = '#FFFFFF'
        WcOk = '#16794C'; WcWarn = '#9A5B00'; WcBad = '#C02626'; WcUnknown = '#5A6572'
        WcOkBg = '#E7F6EE'; WcWarnBg = '#FBF1DE'; WcBadBg = '#FBE7E7'; WcUnknownBg = '#EEF1F4'; WcAccentBg = '#E3F6EE'
        WcHover = '#E9EDF1'; WcActive = '#DDE3E9'
    }
}

function New-WCBrush {
    param([Parameter(Mandatory)][string]$Hex)
    $c = [Windows.Media.ColorConverter]::ConvertFromString($Hex)
    $b = New-Object Windows.Media.SolidColorBrush($c)
    $b.Freeze()
    return $b
}

function Apply-WCTheme {
    # Dat toan bo brush theme vao Resources cua so -> moi control dung
    # SetResourceReference tu dong cap nhat khi doi theme
    param([Parameter(Mandatory)]$Window)
    $palette = Get-WCThemePalette -Dark:(Get-WCThemeIsDark)
    foreach ($k in @($palette.Keys)) {
        $Window.Resources[$k] = (New-WCBrush -Hex $palette[$k])
    }
}

function Get-WCHeadingFont {
    # Segoe UI Variable (Win11) neu co, nguoc lai Segoe UI
    try {
        $fams = [Windows.Media.Fonts]::SystemFontFamilies
        foreach ($f in $fams) { if ($f.Source -eq 'Segoe UI Variable Text') { return 'Segoe UI Variable Text' } }
    } catch { }
    return 'Segoe UI'
}

function Get-WCControlStyles {
    # 1 ResourceDictionary chua style dung chung (nut, o nhap), parse 1 lan
    if ($Script:WcStyles) { return $Script:WcStyles }
    $xaml = @"
<ResourceDictionary xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
                    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
    <Style x:Key="WcBtn" TargetType="Button">
        <Setter Property="Background" Value="{DynamicResource WcCardBg}"/>
        <Setter Property="Foreground" Value="{DynamicResource WcText}"/>
        <Setter Property="BorderBrush" Value="{DynamicResource WcBorder}"/>
        <Setter Property="BorderThickness" Value="1"/>
        <Setter Property="Padding" Value="14,7"/>
        <Setter Property="FontSize" Value="13"/>
        <Setter Property="Cursor" Value="Hand"/>
        <Setter Property="HorizontalContentAlignment" Value="Center"/>
        <Setter Property="Template">
            <Setter.Value>
                <ControlTemplate TargetType="Button">
                    <Border x:Name="bd" Background="{TemplateBinding Background}"
                            BorderBrush="{TemplateBinding BorderBrush}"
                            BorderThickness="{TemplateBinding BorderThickness}"
                            CornerRadius="6" Padding="{TemplateBinding Padding}">
                        <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" RecognizesAccessKey="False"/>
                    </Border>
                    <ControlTemplate.Triggers>
                        <Trigger Property="IsMouseOver" Value="True">
                            <Setter TargetName="bd" Property="Background" Value="{DynamicResource WcHover}"/>
                            <Setter TargetName="bd" Property="BorderBrush" Value="{DynamicResource WcAccent}"/>
                        </Trigger>
                        <Trigger Property="IsPressed" Value="True">
                            <Setter TargetName="bd" Property="Background" Value="{DynamicResource WcActive}"/>
                        </Trigger>
                        <Trigger Property="IsEnabled" Value="False">
                            <Setter TargetName="bd" Property="Opacity" Value="0.45"/>
                        </Trigger>
                    </ControlTemplate.Triggers>
                </ControlTemplate>
            </Setter.Value>
        </Setter>
    </Style>
    <Style x:Key="WcBtnPrimary" TargetType="Button" BasedOn="{StaticResource WcBtn}">
        <Setter Property="Background" Value="{DynamicResource WcAccent}"/>
        <Setter Property="Foreground" Value="{DynamicResource WcAccentText}"/>
        <Setter Property="BorderBrush" Value="{DynamicResource WcAccent}"/>
        <Setter Property="FontWeight" Value="SemiBold"/>
    </Style>
    <Style x:Key="WcBtnDanger" TargetType="Button" BasedOn="{StaticResource WcBtn}">
        <Setter Property="Foreground" Value="{DynamicResource WcBad}"/>
        <Setter Property="BorderBrush" Value="{DynamicResource WcBad}"/>
        <Setter Property="FontWeight" Value="SemiBold"/>
    </Style>
    <Style x:Key="WcInput" TargetType="TextBox">
        <Setter Property="Background" Value="{DynamicResource WcCardBg}"/>
        <Setter Property="Foreground" Value="{DynamicResource WcText}"/>
        <Setter Property="BorderBrush" Value="{DynamicResource WcBorder}"/>
        <Setter Property="Padding" Value="8,6"/>
        <Setter Property="FontSize" Value="13"/>
        <Setter Property="VerticalContentAlignment" Value="Center"/>
        <Setter Property="Template">
            <Setter.Value>
                <ControlTemplate TargetType="TextBox">
                    <Border x:Name="bd" Background="{TemplateBinding Background}"
                            BorderBrush="{TemplateBinding BorderBrush}"
                            BorderThickness="1" CornerRadius="6" Padding="{TemplateBinding Padding}">
                        <ScrollViewer x:Name="PART_ContentHost" Margin="0" VerticalAlignment="Center"/>
                    </Border>
                    <ControlTemplate.Triggers>
                        <Trigger Property="IsKeyboardFocused" Value="True">
                            <Setter TargetName="bd" Property="BorderBrush" Value="{DynamicResource WcAccent}"/>
                        </Trigger>
                    </ControlTemplate.Triggers>
                </ControlTemplate>
            </Setter.Value>
        </Setter>
    </Style>
    <Style x:Key="WcListItem" TargetType="Border">
        <Setter Property="Background" Value="Transparent"/>
        <Setter Property="BorderBrush" Value="{DynamicResource WcBorder}"/>
        <Setter Property="BorderThickness" Value="0,0,0,1"/>
        <Setter Property="CornerRadius" Value="6"/>
        <Setter Property="Padding" Value="8,7"/>
        <Style.Triggers>
            <Trigger Property="IsMouseOver" Value="True">
                <Setter Property="Background" Value="{DynamicResource WcHover}"/>
            </Trigger>
        </Style.Triggers>
    </Style>
</ResourceDictionary>
"@
    $Script:WcStyles = [Windows.Markup.XamlReader]::Parse($xaml)
    return $Script:WcStyles
}

# ---------------------------------------------------------------------------
# CONTROL FACTORY
# ---------------------------------------------------------------------------
function New-WCTextBlock {
    param([string]$Text = '', [double]$Size = 13, [string]$Weight = 'Normal',
          [string]$ColorKey = 'WcText', [switch]$Wrap)
    $t = New-Object Windows.Controls.TextBlock
    $t.Text = $Text
    $t.FontSize = $Size
    $t.FontFamily = New-Object Windows.Media.FontFamily('Segoe UI')
    try { $t.FontWeight = [Windows.FontWeights]::$Weight } catch { }
    $t.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, $ColorKey)
    if ($Wrap) { $t.TextWrapping = [Windows.TextWrapping]::Wrap }
    return $t
}

function New-WCHeading {
    param([string]$Text = '', [double]$Size = 20)
    $t = New-WCTextBlock -Text $Text -Size $Size -Weight 'SemiBold'
    $t.FontFamily = New-Object Windows.Media.FontFamily((Get-WCHeadingFont))
    return $t
}

function New-WCSubtitle {
    param([string]$Text = '')
    return (New-WCTextBlock -Text $Text -Size 12.5 -ColorKey 'WcSubtle' -Wrap)
}

function New-WCButton {
    # Button chuan; OnClick nhan $btn lam tham so, ngoai le tu dong bat + bao loi
    param([Parameter(Mandatory)][string]$Text, [scriptblock]$OnClick,
          [ValidateSet('Normal','Primary','Danger')][string]$Kind = 'Normal',
          [switch]$Small, [switch]$Disabled)
    $b = New-Object Windows.Controls.Button
    $b.Content = $Text
    $styleKey = 'WcBtn'
    if ($Kind -eq 'Primary') { $styleKey = 'WcBtnPrimary' }
    if ($Kind -eq 'Danger')  { $styleKey = 'WcBtnDanger' }
    $b.Style = (Get-WCControlStyles)[$styleKey]
    if ($Small) { $b.Padding = New-Object Windows.Thickness(10,4,10,4); $b.FontSize = 12 }
    if ($Disabled) { $b.IsEnabled = $false }
    if ($OnClick) {
        $handler = $OnClick
        $btnRef = $b
        $b.Add_Click({ try { & $handler $btnRef } catch { Write-WCLog 'ERROR' ('UI handler: ' + $_.Exception.Message); Show-WCError (T 'common.error') $_.Exception.Message } }.GetNewClosure())
    }
    return $b
}

function New-WCHStack {
    param([double]$Spacing = 8)
    $sp = New-Object Windows.Controls.StackPanel
    $sp.Orientation = [Windows.Controls.Orientation]::Horizontal
    $sp.Tag = $Spacing
    return $sp
}

function New-WCVStack {
    param([double]$Spacing = 8)
    $sp = New-Object Windows.Controls.StackPanel
    $sp.Orientation = [Windows.Controls.Orientation]::Vertical
    if ($Spacing -gt 0) {
        # Set spacing qua attached behavior: dung Margin cho con khi Add
        $sp.Tag = $Spacing
    }
    return $sp
}

function Add-WCChild {
    # Them con vao StackPanel, TU DONG tao spacing theo huong cua panel
    param([Parameter(Mandatory)]$Parent, [Parameter(Mandatory)]$Child)
    $spacing = 0.0
    if ($Parent.Tag -is [double]) { $spacing = $Parent.Tag }
    if (($Parent.Children.Count -gt 0) -and ($spacing -gt 0)) {
        $m = $Child.Margin
        if ($Parent.Orientation -eq [Windows.Controls.Orientation]::Vertical) {
            $Child.Margin = (New-Object Windows.Thickness($m.Left, $spacing, $m.Right, $m.Bottom))
        } else {
            $Child.Margin = (New-Object Windows.Thickness($spacing, $m.Top, $m.Right, $m.Bottom))
        }
    }
    $Parent.Children.Add($Child) | Out-Null
    return $Child
}

function New-WCSection {
    # The nhom kieu card Win11. Tra ve @{ Root; Body } - Body la StackPanel de nap noi dung
    param([string]$Title = '', [string]$Subtitle = '', [string]$Badge = '')
    $border = New-Object Windows.Controls.Border
    $border.CornerRadius = (New-Object Windows.CornerRadius(10))
    $border.BorderThickness = (New-Object Windows.Thickness(1))
    $border.Padding = (New-Object Windows.Thickness(16))
    $border.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'WcCardBg')
    $border.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'WcBorder')

    $body = New-Object Windows.Controls.StackPanel
    $body.Orientation = [Windows.Controls.Orientation]::Vertical
    $body.Tag = 10.0

    if ($Title -or $Subtitle) {
        $header = New-WCHStack -Spacing 10
        if ($Badge) {
            $badge = New-WCChip -Text $Badge -Kind 'Accent'
            $badge.VerticalAlignment = [Windows.VerticalAlignment]::Center
            $header.Children.Add($badge) | Out-Null
        }
        $titleBlock = New-WCHeading -Text $Title -Size 15
        $titleBlock.VerticalAlignment = [Windows.VerticalAlignment]::Center
        $header.Children.Add($titleBlock) | Out-Null
        Add-WCChild $body $header
        if ($Subtitle) { Add-WCChild $body (New-WCSubtitle $Subtitle) }
        Add-WCChild $body (New-WCSpacer -Height 4)
    }
    $border.Child = $body
    return @{ Root = $border; Body = $body }
}

function New-WCSpacer {
    param([double]$Height = 8, [double]$Width = 0)
    $e = New-Object Windows.Controls.Border
    $e.Height = $Height
    if ($Width -gt 0) { $e.Width = $Width }
    return $e
}

function New-WCChip {
    # Nhan trang thai: LUON kem chu (khong chi mau - spec muc 1)
    param([Parameter(Mandatory)][string]$Text,
          [ValidateSet('Ok','Warn','Bad','Unknown','Accent','Plain')][string]$Kind = 'Plain')
    $b = New-Object Windows.Controls.Border
    $b.CornerRadius = (New-Object Windows.CornerRadius(999))
    $b.Padding = (New-Object Windows.Thickness(9,2,9,3))
    $b.BorderThickness = (New-Object Windows.Thickness(0))
    $bgKey = 'WcUnknownBg'; $fgKey = 'WcUnknown'
    switch ($Kind) {
        'Ok'      { $bgKey = 'WcOkBg';      $fgKey = 'WcOk' }
        'Warn'    { $bgKey = 'WcWarnBg';    $fgKey = 'WcWarn' }
        'Bad'     { $bgKey = 'WcBadBg';     $fgKey = 'WcBad' }
        'Accent'  { $bgKey = 'WcAccentBg';  $fgKey = 'WcAccent' }
    }
    $b.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, $bgKey)
    $t = New-WCTextBlock -Text $Text -Size 11 -Weight 'SemiBold' -ColorKey $fgKey
    $b.Child = $t
    $b.Tag = $t          # cho phep cap nhat chu sau nay
    return $b
}

function Set-WCChipText {
    param([Parameter(Mandatory)]$Chip, [Parameter(Mandatory)][string]$Text)
    if ($Chip.Tag -is [Windows.Controls.TextBlock]) { $Chip.Tag.Text = $Text }
}

function New-WCStatusChip {
    # Chip tu Status chuan hoa: Ok/Warn/Bad/Unknown
    param([Parameter(Mandatory)][string]$Status, [string]$Text = '')
    $kind = 'Unknown'; $label = (T 'common.status.unknown')
    switch ($Status) {
        'Ok'   { $kind = 'Ok';   $label = (T 'common.status.ok') }
        'Warn' { $kind = 'Warn'; $label = (T 'common.status.warn') }
        'Bad'  { $kind = 'Bad';  $label = (T 'common.status.bad') }
    }
    if ($Text) { $label = $Text }
    return (New-WCChip -Text $label -Kind $kind)
}

function New-WCProgressBar {
    param([double]$Value = 0, [switch]$Indeterminate)
    $p = New-Object Windows.Controls.ProgressBar
    $p.Height = 6
    $p.CornerRadius = (New-Object Windows.CornerRadius(3))
    if ($Indeterminate) { $p.IsIndeterminate = $true } else { $p.Value = $Value; $p.Minimum = 0; $p.Maximum = 100 }
    $p.SetResourceReference([Windows.Controls.ProgressBar]::ForegroundProperty, 'WcAccent')
    $p.SetResourceReference([Windows.Controls.ProgressBar]::BackgroundProperty, 'WcHover')
    return $p
}

function New-WCSpinner {
    # Dai "dang tai" nhe (progress indeterminate + chu)
    param([string]$Text = '')
    $sp = New-Object Windows.Controls.StackPanel
    $sp.Orientation = [Windows.Controls.Orientation]::Horizontal
    $bar = New-WCProgressBar -Indeterminate
    $bar.Width = 90; $bar.Height = 4
    $bar.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $sp.Children.Add($bar) | Out-Null
    if (-not $Text) { $Text = (T 'common.loading') }
    $t = New-WCTextBlock -Text $Text -Size 12 -ColorKey 'WcSubtle'
    $t.Margin = (New-Object Windows.Thickness(10,0,0,0))
    $t.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $sp.Children.Add($t) | Out-Null
    return $sp
}

function New-WCSkeleton {
    $b = New-Object Windows.Controls.Border
    $b.Height = 13
    $b.CornerRadius = (New-Object Windows.CornerRadius(4))
    $b.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'WcCardBg2')
    return $b
}

function New-WCFieldRow {
    # Dong "Nhan: gia tri" co nut copy. Tra ve TextBlock gia tri (cap nhat duoc).
    param([Parameter(Mandatory)][string]$Label, [string]$Value = '', [switch]$NoCopy, [switch]$Mono)
    $grid = New-Object Windows.Controls.Grid
    $cd0 = New-Object Windows.Controls.ColumnDefinition
    $cd0.Width = (New-Object Windows.GridLength(210))
    $cd1 = New-Object Windows.Controls.ColumnDefinition
    $cd1.Width = (New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star))
    $cd2 = New-Object Windows.Controls.ColumnDefinition
    $cd2.Width = [Windows.GridLength]::Auto
    $grid.ColumnDefinitions.Add($cd0) | Out-Null
    $grid.ColumnDefinitions.Add($cd1) | Out-Null
    $grid.ColumnDefinitions.Add($cd2) | Out-Null

    $lbl = New-WCTextBlock -Text $Label -Size 12.5 -ColorKey 'WcSubtle'
    $val = New-WCTextBlock -Text $Value -Size 13
    if ($Mono) { $val.FontFamily = New-Object Windows.Media.FontFamily('Consolas') }
    $val.TextWrapping = [Windows.TextWrapping]::Wrap
    $val.Margin = (New-Object Windows.Thickness(12,0,12,0))
    if (-not $NoCopy) {
        $btn = New-WCButton -Text (T 'common.copy') -Small -OnClick { param($b) Set-WCClipboard $val.Text; Show-WCToast (T 'common.copied') 'Ok' }.GetNewClosure()
        [Windows.Controls.Grid]::SetColumn($btn, 2)
        $grid.Children.Add($btn) | Out-Null
    }
    [Windows.Controls.Grid]::SetColumn($lbl, 0)
    [Windows.Controls.Grid]::SetColumn($val, 1)
    $grid.Children.Add($lbl) | Out-Null
    $grid.Children.Add($val) | Out-Null
    $grid.Tag = $val
    return $grid
}

function New-WCTable {
    # Bang chi hien thi (ListView + GridView). Columns: @{Header='Cot'; Prop='Name'; Width=200}
    param([Parameter(Mandatory)]$Columns)
    $lv = New-Object Windows.Controls.ListView
    $lv.BorderThickness = (New-Object Windows.Thickness(0))
    $lv.Background = [Windows.Media.Brushes]::Transparent
    $lv.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'WcText')
    $lv.SetValue([Windows.Controls.VirtualizingStackPanel]::IsVirtualizingProperty, $true)
    $gv = New-Object Windows.Controls.GridView
    foreach ($c in $Columns) {
        $col = New-Object Windows.Controls.GridViewColumn
        $col.Header = [string]$c['Header']
        if ($c.ContainsKey('Width') -and $c['Width']) { $col.Width = [double]$c['Width'] }
        $binding = New-Object Windows.Data.Binding([string]$c['Prop'])
        $col.DisplayMemberBinding = $binding
        $gv.Columns.Add($col) | Out-Null
    }
    $lv.View = $gv
    return $lv
}

function New-WCCheckList {
    # Danh sach tick (manh "XEM LAI" cua moi tac vu). Row = Border chua CheckBox.
    param([string]$EmptyText = '')
    $sp = New-Object Windows.Controls.StackPanel
    $sp.Orientation = [Windows.Controls.Orientation]::Vertical
    return $sp
}

function Add-WCCheckRow {
    # Them 1 dong co checkbox. $Item gan vao .Tag cua row. TextColumns: mang [string] hien thi.
    param([Parameter(Mandatory)]$List, [Parameter(Mandatory)]$Item, [Parameter(Mandatory)]$TextColumns,
          [bool]$Checked = $false, [string]$ChipText = '', [string]$ChipKind = 'Plain')
    $row = New-Object Windows.Controls.Border
    $row.Style = (Get-WCControlStyles)['WcListItem']
    $row.Tag = $Item
    $dock = New-Object Windows.Controls.DockPanel
    $dock.LastChildFill = $true

    $cb = New-Object Windows.Controls.CheckBox
    $cb.IsChecked = $Checked
    $cb.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $cb.Margin = (New-Object Windows.Thickness(0,0,10,0))
    $cb.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'WcText')
    $dock.Children.Add($cb) | Out-Null
    [Windows.Controls.DockPanel]::SetDock($cb, [Windows.Dock]::Left)

    $textHost = New-Object Windows.Controls.StackPanel
    $textHost.Orientation = [Windows.Controls.Orientation]::Horizontal
    $textHost.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $first = $true
    foreach ($col in $TextColumns) {
        $t = New-WCTextBlock -Text ([string]$col) -Size 13
        if (-not $first) { $t.Margin = (New-Object Windows.Thickness(14,0,0,0)); $t.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'WcSubtle') }
        $textHost.Children.Add($t) | Out-Null
        $first = $false
    }
    $dock.Child = $textHost
    if ($ChipText) {
        $chip = New-WCChip -Text $ChipText -Kind $ChipKind
        $chip.VerticalAlignment = [Windows.VerticalAlignment]::Center
        $chip.Margin = (New-Object Windows.Thickness(10,0,0,0))
        $textHost.Children.Add($chip) | Out-Null
    }
    $row.Child = $dock
    $List.Children.Add($row) | Out-Null
    return $row
}

function Get-WCCheckRowSelection {
    # Lay cac item duoc tick trong New-WCCheckList
    param([Parameter(Mandatory)]$List)
    $sel = @()
    foreach ($child in $List.Children) {
        if ($child -is [Windows.Controls.Border] -and $child.Child -is [Windows.Controls.DockPanel]) {
            $dock = $child.Child
            $cb = $null
            foreach ($el in $dock.Children) { if ($el -is [Windows.Controls.CheckBox]) { $cb = $el; break } }
            if ($cb -and $cb.IsChecked -eq $true) { $sel += $child.Tag }
        }
    }
    return $sel
}

function Clear-WCCheckList {
    param([Parameter(Mandatory)]$List)
    $List.Children.Clear()
}

function New-WCExpander {
    # Expander kieu M4: dong tom tat khi thu gon. Tra ve @{ Root; Body; Header }
    param([Parameter(Mandatory)][string]$Title, [string]$Summary = '')
    $exp = New-Object Windows.Controls.Expander
    $exp.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'WcText')
    $exp.BorderThickness = (New-Object Windows.Thickness(0))
    $header = New-Object Windows.Controls.StackPanel
    $header.Orientation = [Windows.Controls.Orientation]::Horizontal
    $t = New-WCTextBlock -Text $Title -Size 13.5 -Weight 'SemiBold'
    $header.Children.Add($t) | Out-Null
    if ($Summary) {
        $s = New-WCTextBlock -Text (' — ' + $Summary) -Size 12.5 -ColorKey 'WcSubtle'
        $header.Children.Add($s) | Out-Null
    }
    $exp.Header = $header
    $body = New-Object Windows.Controls.StackPanel
    $body.Orientation = [Windows.Controls.Orientation]::Vertical
    $body.Tag = 6.0
    $body.Margin = (New-Object Windows.Thickness(0,8,0,0))
    $exp.Content = $body
    return @{ Root = $exp; Body = $body; Header = $header }
}

function New-WCSearchBox {
    param([Parameter(Mandatory)][scriptblock]$OnChanged)
    $tb = New-Object Windows.Controls.TextBox
    $tb.Style = (Get-WCControlStyles)['WcInput']
    $tb.Width = 260
    $handler = $OnChanged; $tbRef = $tb
    $tb.Add_TextChanged({ try { & $handler $tbRef } catch { } }.GetNewClosure())
    return $tb
}

function New-WCExpertLine {
    # "Che do chuyen gia": hien lenh se chay (spec 2.4) - chi hien khi bat che do
    param([Parameter(Mandatory)][string]$Command)
    $b = New-Object Windows.Controls.Border
    $b.CornerRadius = (New-Object Windows.CornerRadius(6))
    $b.Padding = (New-Object Windows.Thickness(10,6,10,6))
    $b.Margin = (New-Object Windows.Thickness(0,6,0,0))
    $b.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'WcCardBg2')
    $sp = New-Object Windows.Controls.StackPanel
    $sp.Orientation = [Windows.Controls.Orientation]::Horizontal
    $lbl = New-WCTextBlock -Text ((T 'common.expert.cmd') + ':') -Size 11.5 -ColorKey 'WcSubtle'
    $lbl.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $cmd = New-WCTextBlock -Text $Command -Size 12
    $cmd.FontFamily = New-Object Windows.Media.FontFamily('Consolas')
    $cmd.TextWrapping = [Windows.TextWrapping]::Wrap
    $cmd.Margin = (New-Object Windows.Thickness(8,0,0,0))
    $copyBtn = New-WCButton -Text (T 'common.copy') -Small -OnClick { param($x) Set-WCClipboard $cmd.Text }.GetNewClosure()
    $copyBtn.Margin = (New-Object Windows.Thickness(8,0,0,0))
    $sp.Children.Add($lbl) | Out-Null
    $sp.Children.Add($cmd) | Out-Null
    $sp.Children.Add($copyBtn) | Out-Null
    $b.Child = $sp
    $b.Visibility = [Windows.Visibility]::Collapsed
    if (Test-WCExpertMode) { $b.Visibility = [Windows.Visibility]::Visible }
    return $b
}

# ---------------------------------------------------------------------------
# SHELL / STATUS / TOAST
# ---------------------------------------------------------------------------
function Set-WCShellWindow {
    param([Parameter(Mandatory)]$Window, $StatusText, $TaskText, $TaskCancelBtn, $ToastHost, $NavHost, $VersionText, $AdminText)
    $Script:WcShell = @{
        Window = $Window; StatusText = $StatusText; TaskText = $TaskText
        TaskCancel = $TaskCancelBtn; ToastHost = $ToastHost; NavHost = $NavHost
        VersionText = $VersionText; AdminText = $AdminText
    }
    if ($VersionText) { $VersionText.Text = ('{0} v{1} ({2})' -f (Get-WCName), (Get-WCVersion), (Get-WCBuildHash)) }
    if ($AdminText) {
        if (Get-WCIsAdmin) { $AdminText.Text = 'Administrator' } else { $AdminText.Text = '' }
    }
}

function Get-WCShellWindow { if ($Script:WcShell) { return $Script:WcShell.Window } else { return $null } }

function Set-WCStatus {
    param([string]$Text = '')
    if ($Script:WcShell -and $Script:WcShell.StatusText) { $Script:WcShell.StatusText.Text = $Text }
}

function Set-WCStatusTask {
    # Hien task dang chay o thanh trang thai; $Cancelling = true -> hien "dang huy"
    param([string]$Title, [bool]$Cancelling = $false)
    if (-not $Script:WcShell) { return }
    $s = $Script:WcShell
    if ([string]::IsNullOrEmpty($Title)) {
        $s.TaskText.Text = ''
        $s.TaskText.Visibility = [Windows.Visibility]::Collapsed
        $s.TaskCancel.Visibility = [Windows.Visibility]::Collapsed
    } else {
        if ($Cancelling) {
            $s.TaskText.Text = (T 'common.task.cancelling')
        } else {
            $s.TaskText.Text = (T 'common.running' @($Title))
        }
        $s.TaskText.Visibility = [Windows.Visibility]::Visible
        $s.TaskCancel.Visibility = [Windows.Visibility]::Visible
    }
}

function Show-WCToast {
    param([Parameter(Mandatory)][string]$Text, [ValidateSet('Info','Ok','Warn','Bad')][string]$Kind = 'Info')
    if (-not $Script:WcShell) { return }
    $host_ = $Script:WcShell.ToastHost
    if (-not $host_) { return }
    $host_.Children.Clear()
    $border = New-Object Windows.Controls.Border
    $border.CornerRadius = (New-Object Windows.CornerRadius(8))
    $border.Padding = (New-Object Windows.Thickness(14,8,14,8))
    $border.HorizontalAlignment = [Windows.HorizontalAlignment]::Center
    $fgKey = 'WcText'; $bgKey = 'WcCardBg'
    switch ($Kind) {
        'Ok'   { $fgKey = 'WcOk' }
        'Warn' { $fgKey = 'WcWarn' }
        'Bad'  { $fgKey = 'WcBad' }
    }
    $border.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, $bgKey)
    $border.BorderThickness = (New-Object Windows.Thickness(1))
    $border.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'WcBorder')
    $t = New-WCTextBlock -Text $Text -Size 12.5 -ColorKey $fgKey
    $border.Child = $t
    $host_.Children.Add($border) | Out-Null
    $host_.Visibility = [Windows.Visibility]::Visible
    if ($Script:WcToastTimer) { $Script:WcToastTimer.Stop() }
    $Script:WcToastTimer = New-Object Windows.Threading.DispatcherTimer
    $Script:WcToastTimer.Interval = [TimeSpan]::FromMilliseconds(2600)
    $hostRef = $host_
    $Script:WcToastTimer.Add_Tick({ $hostRef.Visibility = [Windows.Visibility]::Collapsed }.GetNewClosure())
    $Script:WcToastTimer.Start()
}

function Set-WCClipboard {
    param([Parameter(Mandatory)][string]$Text)
    try {
        [Windows.Clipboard]::SetText($Text)
    } catch {
        Show-WCToast (T 'common.clipboard.fail') 'Warn'
    }
}

# ---------------------------------------------------------------------------
# DIALOGS (cua so rieng, phong cach Win11, khong dung MessageBox do)
# ---------------------------------------------------------------------------
function New-WCDialog {
    # Dialog chung. $Content = UIElement. $Buttons = @(@{Text; Kind; Result}, ...)
    # Tra ve Result cua nut duoc bam (hoac $null khi dong cua so)
    param([Parameter(Mandatory)][string]$Title, [Parameter(Mandatory)]$Content, [Parameter(Mandatory)]$Buttons)
    $win = New-Object Windows.Window
    $win.Title = $Title
    $win.WindowStyle = [Windows.WindowStyle]::SingleBorderWindow
    $win.WindowStartupLocation = [Windows.WindowStartupLocation]::CenterOwner
    $win.SizeToContent = [Windows.SizeToContent]::WidthAndHeight
    $win.MinWidth = 420
    $win.MaxWidth = 640
    $win.ResizeMode = [Windows.ResizeMode]::NoResize
    $win.ShowInTaskbar = $false
    if ($Script:WcShell -and $Script:WcShell.Window) { $win.Owner = $Script:WcShell.Window }

    $root = New-Object Windows.Controls.Border
    $root.Padding = (New-Object Windows.Thickness(20))
    $root.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'WcBg')
    $grid = New-Object Windows.Controls.Grid
    $rd0 = New-Object Windows.Controls.RowDefinition
    $rd0.Height = (New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star))
    $rd1 = New-Object Windows.Controls.RowDefinition
    $rd1.Height = [Windows.GridLength]::Auto
    $grid.RowDefinitions.Add($rd0) | Out-Null
    $grid.RowDefinitions.Add($rd1) | Out-Null
    $contentScroll = New-Object Windows.Controls.ScrollViewer
    $contentScroll.VerticalScrollBarVisibility = [Windows.Controls.ScrollBarVisibility]::Auto
    $contentScroll.MaxHeight = 380
    $contentScroll.Content = $Content
    [Windows.Controls.Grid]::SetRow($contentScroll, 0)
    $btnHost = New-Object Windows.Controls.StackPanel
    $btnHost.Orientation = [Windows.Controls.Orientation]::Horizontal
    $btnHost.HorizontalAlignment = [Windows.HorizontalAlignment]::Right
    $btnHost.Margin = (New-Object Windows.Thickness(0,16,0,0))
    foreach ($b in $Buttons) {
        $kind = 'Normal'
        if ($b.ContainsKey('Kind')) { $kind = $b['Kind'] }
        $winRef = $win; $result = $b['Result']
        $btn = New-WCButton -Text ([string]$b['Text']) -Kind $kind -OnClick { param($x) $winRef.Tag = $result; $winRef.Close() }.GetNewClosure()
        $btn.Margin = (New-Object Windows.Thickness(8,0,0,0))
        $btn.MinWidth = 96
        $btnHost.Children.Add($btn) | Out-Null
    }
    [Windows.Controls.Grid]::SetRow($btnHost, 1)
    $grid.Children.Add($contentScroll) | Out-Null
    $grid.Children.Add($btnHost) | Out-Null
    $root.Child = $grid
    $win.Content = $root
    Apply-WCTheme $win
    $win.Tag = $null
    $win.ShowDialog() | Out-Null
    return $win.Tag
}

function Show-WCConfirm {
    # Xac nhan chuan: { Undoable / NotUndoable } + RUI RO -> xac nhan 2 buoc (spec muc 1, 3)
    param([Parameter(Mandatory)][string]$Title, [Parameter(Mandatory)][string]$Message,
          [string]$Undoable = '', [string]$NotUndoable = '', [switch]$Danger)
    $body = New-Object Windows.Controls.StackPanel
    $body.Orientation = [Windows.Controls.Orientation]::Vertical
    $body.Tag = 8.0
    $msg = New-WCTextBlock -Text $Message -Size 13 -Wrap
    Add-WCChild $body $msg
    if ($Undoable) {
        $okLine = New-WCHStack
        $okChip = New-WCChip -Text (T 'common.confirm.undone') -Kind 'Ok'
        $okLine.Children.Add($okChip) | Out-Null
        $okTxt = New-WCTextBlock -Text $Undoable -Size 12.5 -Wrap
        $okTxt.Margin = (New-Object Windows.Thickness(8,0,0,0))
        $okLine.Children.Add($okTxt) | Out-Null
        Add-WCChild $body $okLine
    }
    if ($NotUndoable) {
        $badLine = New-WCHStack
        $badChip = New-WCChip -Text (T 'common.confirm.notundone') -Kind 'Bad'
        $badLine.Children.Add($badChip) | Out-Null
        $badTxt = New-WCTextBlock -Text $NotUndoable -Size 12.5 -Wrap
        $badTxt.Margin = (New-Object Windows.Thickness(8,0,0,0))
        $badLine.Children.Add($badTxt) | Out-Null
        Add-WCChild $body $badLine
    }
    $btns = @(
        @{ Text = (T 'common.confirm.run'); Kind = $(if ($Danger) { 'Danger' } else { 'Primary' }); Result = $true },
        @{ Text = (T 'common.cancel'); Kind = 'Normal'; Result = $false }
    )
    $r = New-WCDialog -Title $Title -Content $body -Buttons $btns
    if ($r -eq $true -and $Danger) {
        # Buoc 2 cua xac nhan RUI RO (spec: nhan do + xac nhan 2 buoc)
        $body2 = New-Object Windows.Controls.StackPanel
        $body2.Orientation = [Windows.Controls.Orientation]::Vertical
        Add-WCChild $body2 (New-WCTextBlock -Text (T 'common.confirm.twostep') -Size 13.5 -Weight 'SemiBold' -ColorKey 'WcBad' -Wrap)
        Add-WCChild $body2 (New-WCTextBlock -Text $Title -Size 12.5 -ColorKey 'WcSubtle' -Wrap)
        $btns2 = @(
            @{ Text = (T 'common.confirm.run'); Kind = 'Danger'; Result = $true },
            @{ Text = (T 'common.cancel'); Kind = 'Normal'; Result = $false }
        )
        $r = New-WCDialog -Title $Title -Content $body2 -Buttons $btns2
    }
    return ($r -eq $true)
}

function Show-WCError {
    # Loi de hieu + chi tiet ky thuat thu gon + duong dan log (spec muc 3)
    param([Parameter(Mandatory)][string]$Friendly, [string]$Details = '')
    $body = New-Object Windows.Controls.StackPanel
    $body.Orientation = [Windows.Controls.Orientation]::Vertical
    $body.Tag = 8.0
    Add-WCChild $body (New-WCTextBlock -Text $Friendly -Size 13.5 -Wrap)
    if ($Details) {
        $exp = New-WCExpander -Title (T 'common.details')
        $det = New-WCTextBlock -Text $Details -Size 12
        $det.FontFamily = New-Object Windows.Media.FontFamily('Consolas')
        $det.TextWrapping = [Windows.TextWrapping]::Wrap
        Add-WCChild $exp.Body $det
        Add-WCChild $body $exp.Root
    }
    $logPath = Get-WCLogPath
    if ($logPath) {
        $h = New-WCHStack
        $lbl = New-WCTextBlock -Text ('Log: ' + $logPath) -Size 11.5 -ColorKey 'WcSubtle'
        $lbl.VerticalAlignment = [Windows.VerticalAlignment]::Center
        $h.Children.Add($lbl) | Out-Null
        $openBtn = New-WCButton -Text (T 'common.open') -Small -OnClick { param($x) Open-WCLogFile }.GetNewClosure()
        $openBtn.Margin = (New-Object Windows.Thickness(8,0,0,0))
        $h.Children.Add($openBtn) | Out-Null
        Add-WCChild $body $h
    }
    $btns = @(@{ Text = (T 'common.close'); Kind = 'Normal'; Result = $true })
    $null = New-WCDialog -Title (T 'common.error') -Content $body -Buttons $btns
}

function Open-WCLogFile {
    $p = Get-WCLogPath
    if ($p -and (Test-Path -LiteralPath $p)) {
        try { Start-Process notepad.exe -ArgumentList ('"' + $p + '"') } catch { }
    }
}

function Show-WCInfo {
    param([Parameter(Mandatory)][string]$Title, [Parameter(Mandatory)][string]$Message)
    $body = New-Object Windows.Controls.StackPanel
    $body.Orientation = [Windows.Controls.Orientation]::Vertical
    Add-WCChild $body (New-WCTextBlock -Text $Message -Size 13 -Wrap)
    $btns = @(@{ Text = (T 'common.close'); Kind = 'Primary'; Result = $true })
    $null = New-WCDialog -Title $Title -Content $body -Buttons $btns
}

# ---------------------------------------------------------------------------
# NAV REGISTRY - moi module dang ky 1 muc (panel xay lazy + cache)
# ---------------------------------------------------------------------------
function Register-WCNavItem {
    # Vi du:
    #   Register-WCNavItem -Key 'm1' -Badge 'M1' -Title (T 'm1.title') -Order 20 -Builder {
    #       # xay panel (goi 1 lan, cache lai); tra ve UIElement
    #   } -OnShow { } -OnHide { }
    param(
        [Parameter(Mandatory)][string]$Key,
        [Parameter(Mandatory)][string]$Badge,
        [Parameter(Mandatory)][string]$Title,
        [double]$Order = 100,
        [Parameter(Mandatory)][scriptblock]$Builder,
        [scriptblock]$OnShow = $null,
        [scriptblock]$OnHide = $null
    )
    $Script:WcNavItems[$Key] = @{
        Key = $Key; Badge = $Badge; Title = $Title; Order = $Order
        Builder = $Builder; Panel = $null
        OnShow = $OnShow; OnHide = $OnHide
    }
}

function Invoke-WCShowNav {
    # Hien thi panel cua 1 muc nav (shell goi khi bam menu)
    param([Parameter(Mandatory)][string]$Key)
    if (-not $Script:WcNavItems.Contains($Key)) { return }
    if ($Script:WcNavCurrent -and $Script:WcNavItems.Contains($Script:WcNavCurrent)) {
        $prev = $Script:WcNavItems[$Script:WcNavCurrent]
        if ($prev.OnHide) { try { & $prev.OnHide } catch { } }
        if ($prev.Panel) { $prev.Panel.Visibility = [Windows.Visibility]::Collapsed }
    }
    $item = $Script:WcNavItems[$Key]
    if (-not $item.Panel) {
        try {
            $item.Panel = & $item.Builder
        } catch {
            Write-WCLog 'ERROR' ('Xay panel that bai [' + $Key + ']: ' + $_.Exception.Message)
            $fallback = New-WCVStack -Spacing 10
            Add-WCChild $fallback (New-WCHeading (T 'common.error'))
            Add-WCChild $fallback (New-WCTextBlock -Text $_.Exception.Message -Wrap)
            $item.Panel = $fallback
        }
        if ($Script:WcShell -and $Script:WcShell.NavHost) {
            $Script:WcShell.NavHost.Children.Add($item.Panel) | Out-Null
        }
    }
    $item.Panel.Visibility = [Windows.Visibility]::Visible
    $Script:WcNavCurrent = $Key
    if ($item.OnShow) { try { & $item.OnShow } catch { Write-WCLog 'ERROR' ('OnShow: ' + $_.Exception.Message) } }
    Set-WCStatus $item.Title
    # Cap nhat highlight nut nav (shell dang ky action nay)
    if ($Script:WcNavHighlightAction) {
        try { & $Script:WcNavHighlightAction } catch { }
    }
}

function Reset-WCNavPanels {
    # Doi ngon ngu/theme -> huy cache panel, xay lai man hien tai
    $current = $Script:WcNavCurrent
    if ($Script:WcShell -and $Script:WcShell.NavHost) { $Script:WcShell.NavHost.Children.Clear() }
    foreach ($k in @($Script:WcNavItems.Keys)) {
        $Script:WcNavItems[$k].Panel = $null
    }
    $Script:WcNavCurrent = $null
    if ($current) { Invoke-WCShowNav $current }
}

function Get-WCNavItemsSorted {
    return @($Script:WcNavItems.Values | Sort-Object Order)
}


# ============================================================================
# REGION: 10-Shell.ps1
# ============================================================================

# ============================================================================
#  src/10-Shell.ps1 - Cua so chinh: nav trai + noi dung + thanh trang thai
#  Bo cuc theo spec muc 3: Dashboard + 7 module + Lich su + Cai dat.
# ============================================================================

Register-WCStrings 'vi' @{
    'shell.taskcancel' = 'Hủy'
    'shell.exitconfirm.title' = 'Đang chạy tác vụ'
    'shell.exitconfirm.text' = 'WinCare đang chạy tác vụ nền. Dừng và thoát?'
    'shell.exitconfirm.stop' = 'Dừng và thoát'
    'shell.exitconfirm.wait' = 'Chờ, không thoát'
    'shell.about.network' = 'Hoạt động mạng'
    'shell.about.network.desc' = 'WinCare chỉ kết nối: (1) Windows Update qua dịch vụ WUA của chính Windows; (2) trang chính thức của hãng phần cứng (chỉ mở trình duyệt); (3) URL script khi tự nâng quyền. Không telemetry, không analytics.'
    'nav.dashboard' = 'Tổng quan'
    'nav.history' = 'Lịch sử & Hoàn tác'
    'nav.settings' = 'Cài đặt'
}
Register-WCStrings 'en' @{
    'shell.taskcancel' = 'Cancel'
    'shell.exitconfirm.title' = 'Task is running'
    'shell.exitconfirm.text' = 'WinCare is running a background task. Stop and exit?'
    'shell.exitconfirm.stop' = 'Stop and exit'
    'shell.exitconfirm.wait' = 'Wait, do not exit'
    'shell.about.network' = 'Network activity'
    'shell.about.network.desc' = 'WinCare only connects to: (1) Windows Update via Windows own WUA service; (2) official hardware vendor pages (opens browser only); (3) the script URL when self-elevating. No telemetry, no analytics.'
    'nav.dashboard' = 'Overview'
    'nav.history' = 'History & Undo'
    'nav.settings' = 'Settings'
}

function New-WCNavItemButton {
    # 1 nut nav: badge + ten; highlight khi dang chon
    param([Parameter(Mandatory)]$Item)
    $btn = New-Object Windows.Controls.Button
    $btn.Style = (Get-WCControlStyles)['WcBtn']
    $btn.Padding = (New-Object Windows.Thickness(12,9,12,9))
    $btn.Margin = (New-Object Windows.Thickness(10,2,10,2))
    $btn.HorizontalAlignment = [Windows.HorizontalAlignment]::Stretch
    $btn.HorizontalContentAlignment = [Windows.HorizontalAlignment]::Stretch
    $btn.BorderThickness = (New-Object Windows.Thickness(0))
    $btn.Background = [Windows.Media.Brushes]::Transparent

    $dock = New-Object Windows.Controls.DockPanel
    $dock.LastChildFill = $true
    $badge = New-WCChip -Text $Item.Badge -Kind 'Accent'
    $badge.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $badge.MinWidth = 34
    [Windows.Controls.DockPanel]::SetDock($badge, [Windows.Dock]::Left)
    $dock.Children.Add($badge) | Out-Null
    $title = New-WCTextBlock -Text $Item.Title -Size 13
    $title.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $title.Margin = (New-Object Windows.Thickness(10,0,0,0))
    $dock.Child = $title
    $btn.Content = $dock
    $btn.Tag = @{ Item = $Item; TitleBlock = $title }
    $key = $Item.Key
    $btn.Add_Click({ try { Invoke-WCShowNav $key } catch { Write-WCLog 'ERROR' ('Nav click: ' + $_.Exception.Message) } }.GetNewClosure())
    return $btn
}

function Update-WCNavSelection {
    # To mau nut nav dang chon (kieu Win11)
    param([Parameter(Mandatory)]$NavList, [string]$CurrentKey)
    foreach ($child in $NavList.Children) {
        if ($child -is [Windows.Controls.Button] -and $child.Tag) {
            if ($child.Tag.Item.Key -eq $CurrentKey) {
                $child.SetResourceReference([Windows.Controls.Control]::BackgroundProperty, 'WcAccentBg')
                $child.Tag.TitleBlock.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'WcAccent')
            } else {
                $child.Background = [Windows.Media.Brushes]::Transparent
                $child.Tag.TitleBlock.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'WcText')
            }
        }
    }
}

function Show-WCShell {
    # Cua so chinh (spec muc 3): toi thieu 1000x650, co giãn duoc
    $window = New-Object Windows.Window
    $window.Title = (Get-WCName)
    $window.Width = 1180
    $window.Height = 720
    $window.MinWidth = 1000
    $window.MinHeight = 650
    $window.WindowStartupLocation = [Windows.WindowStartupLocation]::CenterScreen

    $root = New-Object Windows.Controls.Grid
    $rdMain = New-Object Windows.Controls.RowDefinition
    $rdMain.Height = (New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star))
    $rdStatus = New-Object Windows.Controls.RowDefinition
    $rdStatus.Height = [Windows.GridLength]::Auto
    $root.RowDefinitions.Add($rdMain) | Out-Null
    $root.RowDefinitions.Add($rdStatus) | Out-Null

    # Cot: [nav 240 | noi dung *]
    $mainGrid = New-Object Windows.Controls.Grid
    $cdNav = New-Object Windows.Controls.ColumnDefinition
    $cdNav.Width = (New-Object Windows.GridLength(240))
    $cdBody = New-Object Windows.Controls.ColumnDefinition
    $cdBody.Width = (New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star))
    $mainGrid.ColumnDefinitions.Add($cdNav) | Out-Null
    $mainGrid.ColumnDefinitions.Add($cdBody) | Out-Null
    [Windows.Controls.Grid]::SetRow($mainGrid, 0)

    # --- Nav trai ---
    $navBorder = New-Object Windows.Controls.Border
    $navBorder.BorderThickness = (New-Object Windows.Thickness(0,0,1,0))
    $navBorder.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'WcCardBg')
    $navBorder.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'WcBorder')
    [Windows.Controls.Grid]::SetColumn($navBorder, 0)

    $navScroll = New-Object Windows.Controls.ScrollViewer
    $navScroll.VerticalScrollBarVisibility = [Windows.Controls.ScrollBarVisibility]::Auto
    $navStack = New-Object Windows.Controls.StackPanel
    $navStack.Orientation = [Windows.Controls.Orientation]::Vertical

    # Logo/danh xung
    $brandHost = New-Object Windows.Controls.StackPanel
    $brandHost.Orientation = [Windows.Controls.Orientation]::Vertical
    $brandHost.Margin = (New-Object Windows.Thickness(14,14,14,8))
    $brand = New-WCHeading -Text (Get-WCName) -Size 19
    $brandHost.Children.Add($brand) | Out-Null
    $tagline = New-WCTextBlock -Text ('v' + (Get-WCVersion) + ' — trung thực, không hứa suông') -Size 11 -ColorKey 'WcSubtle'
    $brandHost.Children.Add($tagline) | Out-Null
    $navStack.Children.Add($brandHost) | Out-Null

    $navList = New-Object Windows.Controls.StackPanel
    $navList.Orientation = [Windows.Controls.Orientation]::Vertical
    $navStack.Children.Add($navList) | Out-Null
    $navScroll.Content = $navStack
    $navBorder.Child = $navScroll
    $mainGrid.Children.Add($navBorder) | Out-Null

    # --- Noi dung phai ---
    $bodyBorder = New-Object Windows.Controls.Border
    $bodyBorder.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'WcBg')
    [Windows.Controls.Grid]::SetColumn($bodyBorder, 1)
    $navHost = New-Object Windows.Controls.Grid
    $bodyBorder.Child = $navHost
    $mainGrid.Children.Add($bodyBorder) | Out-Null
    $root.Children.Add($mainGrid) | Out-Null

    # --- Toast host (nổi trên nội dung) ---
    $toastHost = New-Object Windows.Controls.StackPanel
    $toastHost.HorizontalAlignment = [Windows.HorizontalAlignment]::Center
    $toastHost.VerticalAlignment = [Windows.VerticalAlignment]::Bottom
    $toastHost.Margin = (New-Object Windows.Thickness(0,0,0,10))
    $toastHost.Visibility = [Windows.Visibility]::Collapsed
    [Windows.Controls.Grid]::SetRow($toastHost, 0)
    $root.Children.Add($toastHost) | Out-Null

    # --- Thanh trang thai duoi ---
    $statusBar = New-Object Windows.Controls.Border
    $statusBar.BorderThickness = (New-Object Windows.Thickness(0,1,0,0))
    $statusBar.Padding = (New-Object Windows.Thickness(14,6,14,6))
    $statusBar.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'WcCardBg')
    $statusBar.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'WcBorder')
    [Windows.Controls.Grid]::SetRow($statusBar, 1)

    $statusDock = New-Object Windows.Controls.DockPanel
    $statusDock.LastChildFill = $true

    $versionTxt = New-WCTextBlock -Text '' -Size 11.5 -ColorKey 'WcSubtle'
    [Windows.Controls.DockPanel]::SetDock($versionTxt, [Windows.Dock]::Left)
    $statusDock.Children.Add($versionTxt) | Out-Null

    $adminTxt = New-WCTextBlock -Text 'Administrator' -Size 11.5 -ColorKey 'WcOk'
    $adminTxt.Margin = (New-Object Windows.Thickness(12,0,0,0))
    [Windows.Controls.DockPanel]::SetDock($adminTxt, [Windows.Dock]::Left)
    $statusDock.Children.Add($adminTxt) | Out-Null

    $cancelBtn = New-WCButton -Text (T 'shell.taskcancel') -Small -OnClick {
        param($b)
        foreach ($id in @($Script:WcTasks.Keys)) {
            if ($Script:WcTasks[$id].State -eq 'Running') { Cancel-WCTask $id }
        }
    }.GetNewClosure()
    $cancelBtn.Visibility = [Windows.Visibility]::Collapsed
    [Windows.Controls.DockPanel]::SetDock($cancelBtn, [Windows.Dock]::Right)
    $statusDock.Children.Add($cancelBtn) | Out-Null

    $taskTxt = New-WCTextBlock -Text '' -Size 11.5 -ColorKey 'WcText'
    $taskTxt.Margin = (New-Object Windows.Thickness(12,0,12,0))
    $taskTxt.VerticalAlignment = [Windows.VerticalAlignment]::Center
    [Windows.Controls.DockPanel]::SetDock($taskTxt, [Windows.Dock]::Right)
    $statusDock.Children.Add($taskTxt) | Out-Null

    $statusTxt = New-WCTextBlock -Text '' -Size 11.5 -ColorKey 'WcSubtle'
    $statusTxt.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $statusDock.Child = $statusTxt

    $statusBar.Child = $statusDock
    $root.Children.Add($statusBar) | Out-Null

    $window.Content = $root

    # Dang ky shell cho toan app (status/toast/nav host/nav list)
    Set-WCShellWindow -Window $window -StatusText $statusTxt -TaskText $taskTxt `
        -TaskCancelBtn $cancelBtn -ToastHost $toastHost -NavHost $navHost `
        -VersionText $versionTxt -AdminText $adminTxt
    $Script:WcShell.NavList = $navList

    # Theme + nap nut nav tu registry (da duoc Initialize-WCModule* dang ky truoc)
    Apply-WCTheme $window
    foreach ($item in (Get-WCNavItemsSorted)) {
        $btn = New-WCNavItemButton -Item $item
        $navList.Children.Add($btn) | Out-Null
    }
    $window.Add_Loaded({
        try {
            # Hien panel dau tien (Dashboard)
            Invoke-WCShowNav 'dashboard'
        } catch { Write-WCLog 'ERROR' ('Show dashboard: ' + $_.Exception.Message) }
        # Dong ho pump task bat dau sau khi cua so san sang
        Start-WCTaskPump
    }.GetNewClosure())

    # Bat su kien chon nav de highlight (09-UICore Invoke-WCShowNav se goi action nay)
    $Script:WcNavHighlightAction = {
        try { Update-WCNavSelection $navList $Script:WcNavCurrent } catch { }
    }.GetNewClosure()

    # Dong cua so khi dang chay -> hoi (spec muc 3)
    $window.Add_Closing({
        param($sender, $e)
        if (Test-WCAnyTaskRunning) {
            $body = New-Object Windows.Controls.StackPanel
            $body.Orientation = [Windows.Controls.Orientation]::Vertical
            Add-WCChild $body (New-WCTextBlock -Text (T 'shell.exitconfirm.text') -Size 13 -Wrap)
            $btns = @(
                @{ Text = (T 'shell.exitconfirm.stop'); Kind = 'Danger'; Result = $true },
                @{ Text = (T 'shell.exitconfirm.wait'); Kind = 'Normal'; Result = $false }
            )
            $r = New-WCDialog -Title (T 'shell.exitconfirm.title') -Content $body -Buttons $btns
            if ($r -ne $true) { $e.Cancel = $true }
        }
    }.GetNewClosure())

    # Da dong: don dep + tu phuc hoi dich vu dung tam (spec 2.2/2.4)
    $window.Add_Closed({
        try {
            Restore-WCPendingSessionEntries
            Stop-WCTaskRunner
        } catch { Write-WCLog 'WARN' ('Cleanup: ' + $_.Exception.Message) }
        try {
            if ($Script:WcMutex) {
                $Script:WcMutex.ReleaseMutex()
                $Script:WcMutex.Dispose()
                $Script:WcMutex = $null
            }
        } catch { }
    }.GetNewClosure())

    # Lan chay dau: hop thoai ngan 3 dong + nut Bat dau (spec muc 3)
    if (-not (Get-WCSetting 'firstRunDone')) {
        $body = New-Object Windows.Controls.StackPanel
        $body.Tag = 10.0
        Add-WCChild $body (New-WCHeading -Text (T 'boot.firstrun.title') -Size 17)
        Add-WCChild $body (New-WCTextBlock -Text (T 'boot.firstrun.line1') -Size 13 -Wrap)
        Add-WCChild $body (New-WCTextBlock -Text (T 'boot.firstrun.line2') -Size 13 -Wrap)
        Add-WCChild $body (New-WCTextBlock -Text (T 'boot.firstrun.line3') -Size 13 -Wrap)
        $btns = @(@{ Text = (T 'boot.firstrun.start'); Kind = 'Primary'; Result = $true })
        $null = New-WCDialog -Title (Get-WCName) -Content $body -Buttons $btns
        Set-WCSetting 'firstRunDone' $true
    }

    $window.ShowDialog() | Out-Null
}

function Refresh-WCNavTitles {
    # Doi ngon ngu -> dang ky lai nav (ten moi) + xay lai nut nav + panel
    if (-not $Script:WcShell) { return }
    $current = $Script:WcNavCurrent
    $Script:WcNavItems.Clear()
    Initialize-WCModules
    # Xay lai danh sach nut nav
    $navList = $Script:WcShell.NavList
    if ($navList) {
        $navList.Children.Clear()
        foreach ($item in (Get-WCNavItemsSorted)) {
            $btn = New-WCNavItemButton -Item $item
            $navList.Children.Add($btn) | Out-Null
        }
    }
    # Huy panel cu + xay lai man hien tai
    if ($Script:WcShell.NavHost) { $Script:WcShell.NavHost.Children.Clear() }
    foreach ($k in @($Script:WcNavItems.Keys)) { $Script:WcNavItems[$k].Panel = $null }
    $Script:WcNavCurrent = $null
    if ($current -and $Script:WcNavItems.Contains($current)) {
        Invoke-WCShowNav $current
    } else {
        Invoke-WCShowNav 'dashboard'
    }
}


# ============================================================================
# REGION: 11-Dashboard.ps1
# ============================================================================

# ============================================================================
#  src/11-Dashboard.ps1 - Tong quan: quet nhanh chi doc + "Viec nen lam"
#  Mo the: mau + chu, 1 cau ket luan, nut "Xem chi tiet" + 1 hanh phu hop (spec muc 5)
# ============================================================================

Register-WCStrings 'vi' @{
    'dash.title' = 'Tổng quan'
    'dash.subtitle' = 'Quét nhanh chỉ đọc — không thay đổi gì trên máy của bạn'
    'dash.rescan' = 'Quét lại'
    'dash.lastscan' = 'Quét lúc: {0}'
    'dash.card.ram' = 'RAM'
    'dash.card.disk' = 'Ổ đĩa'
    'dash.card.driver' = 'Driver'
    'dash.card.security' = 'Bảo mật'
    'dash.card.health' = 'Sức khỏe'
    'dash.card.aging' = 'Độ lão hóa'
    'dash.ram.ok' = 'RAM đang thoải mái'
    'dash.ram.warn' = 'RAM đang căng ({0} khả dụng)'
    'dash.disk.ok' = 'Ổ hệ thống còn {0} trống ({1}%)'
    'dash.disk.warn' = 'Ổ hệ thống sắp đầy: còn {0} ({1}%)'
    'dash.driver.ok' = 'Không có thiết bị lỗi'
    'dash.driver.warn' = '{0} thiết bị đang lỗi'
    'dash.driver.scan' = 'Đang kiểm kê driver…'
    'dash.security.ok' = 'Bảo vệ thời gian thực đang bật'
    'dash.security.warn' = 'Defender: bảo vệ thời gian thực TẮT'
    'dash.security.sig' = 'Chữ ký Defender cũ ({0} ngày)'
    'dash.security.unknown' = 'Không đọc được trạng thái Defender'
    'dash.health.ok' = 'Các ổ đĩa đều khỏe'
    'dash.health.warn' = 'Có ổ {0}'
    'dash.health.unknown' = 'Không đọc được tình trạng ổ'
    'dash.aging.ok' = 'Máy được chăm sóc tốt'
    'dash.aging.warn' = 'Có {0} mục khởi động ngoài Microsoft'
    'dash.aging.unknown' = 'Chưa đủ dữ liệu'
    'dash.todo.title' = 'Việc nên làm'
    'dash.todo.empty' = 'Không có gì cần làm. Máy đang ổn.'
    'dash.todo.disk' = 'Giải phóng ổ hệ thống (Dọn ổ cứng)'
    'dash.todo.ram' = 'Tối ưu RAM (Chế độ 1 — an toàn)'
    'dash.todo.sig' = 'Cập nhật chữ ký Defender'
    'dash.todo.device' = 'Xem thiết bị lỗi trong Trình điều khiển'
    'dash.todo.startup' = 'Rà soát mục khởi động (Độ lão hóa)'
    'dash.viewdetail' = 'Xem chi tiết'
}
Register-WCStrings 'en' @{
    'dash.title' = 'Overview'
    'dash.subtitle' = 'Quick read-only scan — nothing on your PC is changed'
    'dash.rescan' = 'Rescan'
    'dash.lastscan' = 'Scanned at: {0}'
    'dash.card.ram' = 'RAM'
    'dash.card.disk' = 'Disk'
    'dash.card.driver' = 'Drivers'
    'dash.card.security' = 'Security'
    'dash.card.health' = 'Health'
    'dash.card.aging' = 'Aging'
    'dash.ram.ok' = 'RAM is comfortable'
    'dash.ram.warn' = 'RAM under pressure ({0} available)'
    'dash.disk.ok' = 'System drive has {0} free ({1}%)'
    'dash.disk.warn' = 'System drive nearly full: {0} free ({1}%)'
    'dash.driver.ok' = 'No problem devices'
    'dash.driver.warn' = '{0} devices with errors'
    'dash.driver.scan' = 'Inventorying drivers…'
    'dash.security.ok' = 'Real-time protection is on'
    'dash.security.warn' = 'Defender: real-time protection OFF'
    'dash.security.sig' = 'Defender signatures stale ({0} days)'
    'dash.security.unknown' = 'Cannot read Defender status'
    'dash.health.ok' = 'All disks healthy'
    'dash.health.warn' = 'A disk is {0}'
    'dash.health.unknown' = 'Cannot read disk health'
    'dash.aging.ok' = 'PC is well maintained'
    'dash.aging.warn' = '{0} non-Microsoft startup entries'
    'dash.aging.unknown' = 'Not enough data'
    'dash.todo.title' = 'Suggested actions'
    'dash.todo.empty' = 'Nothing to do. Your PC is fine.'
    'dash.todo.disk' = 'Free up system drive (Disk cleanup)'
    'dash.todo.ram' = 'Optimize RAM (Mode 1 — safe)'
    'dash.todo.sig' = 'Update Defender signatures'
    'dash.todo.device' = 'Check problem devices in Drivers'
    'dash.todo.startup' = 'Review startup entries (Aging)'
    'dash.viewdetail' = 'Details'
}

function Initialize-WCModuleDashboard {
    $state = @{ Cards = @{}; TodoHost = $null; LastScan = $null }
    Register-WCNavItem -Key 'dashboard' -Badge (T 'nav.dashboard') -Title (T 'dash.title') -Order 10 -Builder {
        New-WCDashboardPanel $state
    }.GetNewClosure() -OnShow {
        Invoke-WCDashboardScan $state $true
    }.GetNewClosure()
}

function New-WCDashboardPanel {
    param($State)
    $root = New-Object Windows.Controls.ScrollViewer
    $root.VerticalScrollBarVisibility = [Windows.Controls.ScrollBarVisibility]::Auto
    $hostPanel = New-WCVStack -Spacing 14
    $hostPanel.Margin = (New-Object Windows.Thickness(20))
    $root.Content = $hostPanel

    $titleRow = New-WCHStack
    Add-WCChild $titleRow (New-WCHeading (T 'dash.title'))
    $betaChip = New-WCChip -Text (T 'common.beta') -Kind 'Warn'
    $betaChip.VerticalAlignment = [Windows.VerticalAlignment]::Center
    Add-WCChild $titleRow $betaChip
    $spacer = New-WCSpacer -Width 10
    Add-WCChild $titleRow $spacer
    $rescanBtn = New-WCButton -Text (T 'dash.rescan') -OnClick { param($b) Invoke-WCDashboardScan $state $false }.GetNewClosure()
    Add-WCChild $titleRow $rescanBtn
    Add-WCChild $hostPanel $titleRow
    Add-WCChild $hostPanel (New-WCSubtitle (T 'dash.subtitle'))

    # Luoi the 6 module (3 cot x 2 hang), moi the co spinner ban dau
    $grid = New-Object Windows.Controls.Grid
    for ($i = 0; $i -lt 3; $i++) {
        $cd = New-Object Windows.Controls.ColumnDefinition
        $cd.Width = (New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star))
        $grid.ColumnDefinitions.Add($cd) | Out-Null
    }
    $cardDefs = @(
        @{ Key = 'ram';      Label = (T 'dash.card.ram');      Nav = 'm1' }
        @{ Key = 'disk';     Label = (T 'dash.card.disk');     Nav = 'm2' }
        @{ Key = 'driver';   Label = (T 'dash.card.driver');   Nav = 'm3' }
        @{ Key = 'security'; Label = (T 'dash.card.security'); Nav = 'm5' }
        @{ Key = 'health';   Label = (T 'dash.card.health');   Nav = 'm6' }
        @{ Key = 'aging';    Label = (T 'dash.card.aging');    Nav = 'm7' }
    )
    $idx = 0
    foreach ($def in $cardDefs) {
        $row = [math]::Floor($idx / 3)
        while ($grid.RowDefinitions.Count -le $row) {
            $grid.RowDefinitions.Add((New-Object Windows.Controls.RowDefinition)) | Out-Null
        }
        $card = New-Object Windows.Controls.Border
        $card.CornerRadius = (New-Object Windows.CornerRadius(10))
        $card.BorderThickness = (New-Object Windows.Thickness(1))
        $card.Padding = (New-Object Windows.Thickness(16))
        $card.Margin = (New-Object Windows.Thickness(0,0,10,10))
        $card.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'WcCardBg')
        $card.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'WcBorder')
        $inner = New-WCVStack -Spacing 6
        $headRow = New-WCHStack
        $lbl = New-WCTextBlock -Text $def.Label -Size 13 -Weight 'SemiBold' -ColorKey 'WcSubtle'
        Add-WCChild $headRow $lbl
        $chip = New-WCStatusChip -Status 'Unknown'
        Add-WCChild $headRow $chip
        Add-WCChild $inner $headRow
        $conclusion = New-WCTextBlock -Text '…' -Size 13 -Wrap
        Add-WCChild $inner $conclusion
        $btnRow = New-WCHStack
        $nav = $def.Nav
        $detailBtn = New-WCButton -Text (T 'dash.viewdetail') -Small -OnClick { param($b) Invoke-WCShowNav $nav }.GetNewClosure()
        Add-WCChild $btnRow $detailBtn
        Add-WCChild $inner $btnRow
        $card.Child = $inner
        [Windows.Controls.Grid]::SetColumn($card, ($idx % 3))
        [Windows.Controls.Grid]::SetRow($card, $row)
        $grid.Children.Add($card) | Out-Null
        $State.Cards[$def.Key] = @{ Chip = $chip; Conclusion = $conclusion; Label = $lbl }
        $idx++
    }
    Add-WCChild $hostPanel $grid

    # "Viec nen lam" (toi da 3, muc rui ro thap len truoc - spec muc 5)
    $todoSec = New-WCSection -Title (T 'dash.todo.title')
    $State.TodoHost = $todoSec.Body
    Add-WCChild $todoSec.Body (New-WCSpinner)
    Add-WCChild $hostPanel $todoSec.Root

    $State.LastScan = New-WCTextBlock -Text '' -Size 11.5 -ColorKey 'WcSubtle'
    Add-WCChild $hostPanel $State.LastScan

    return $root
}

function Set-WCDashboardCard {
    param($State, [string]$Key, [string]$Status, [string]$Conclusion)
    if (-not $State.Cards.ContainsKey($Key)) { return }
    $card = $State.Cards[$Key]
    $chip = New-WCStatusChip -Status $Status
    $hostChip = $card.Chip
    # Thay chip cu bang chip moi (giu vi tri trong StackPanel cha)
    $parent = $hostChip.Parent
    if ($parent -is [Windows.Controls.StackPanel]) {
        $pos = $parent.Children.IndexOf($hostChip)
        $parent.Children.Remove($hostChip) | Out-Null
        $parent.Children.Insert($pos, $chip) | Out-Null
    }
    $card.Chip = $chip
    $card.Conclusion.Text = $Conclusion
}

function Invoke-WCDashboardScan {
    # Quet nhanh chi doc (spec muc 5): cac the cap nhat dan, driver co spinner rieng
    param($State, [bool]$OnlyIfStale)
    if (Test-WCTaskRunning 'dash.scan') { return }

    $ok = Start-WCTask -Id 'dash.scan' -Title (T 'dash.title') -Worker {
        param($ctx, $s)
        $r = @{}

        # RAM
        $snap = Get-WCMemorySnapshot
        $r.Ram = @{ Status = 'Ok'; Text = (T 'dash.ram.ok'); Snap = $snap }
        $avail = $snap.AvailableKb; if ($null -eq $avail) { $avail = $snap.FreeKb }
        if ($snap.TotalKb -and ($null -ne $avail)) {
            $pctUsed = (($snap.TotalKb - $avail) / $snap.TotalKb) * 100
            if ($pctUsed -ge 88) {
                $r.Ram.Status = 'Warn'
                $r.Ram.Text = (T 'dash.ram.warn' @((ConvertTo-WCHumanSize ([long]($avail * 1KB)))))
            }
        }

        # O dia he thong
        try {
            $os = Get-CimInstance -ClassName Win32_OperatingSystem -Property SystemDrive -OperationTimeoutSec 8
            $drive = [string](Get-WCProp $os 'SystemDrive')
            if ($drive) {
                $ld = Get-CimInstance -ClassName Win32_LogicalDisk -Filter ("DeviceID='" + $drive + "'") -Property Size,FreeSpace -OperationTimeoutSec 8
                $size = [double](Get-WCProp $ld 'Size')
                $free = [double](Get-WCProp $ld 'FreeSpace')
                if ($size -gt 0) {
                    $pct = [math]::Round(($free / $size) * 100)
                    if (($pct -lt 15) -or ($free -lt 10GB)) {
                        $r.Disk = @{ Status = 'Warn'; Text = (T 'dash.disk.warn' @((ConvertTo-WCHumanSize ([long]$free)), $pct)); Pct = $pct; Free = $free }
                    } else {
                        $r.Disk = @{ Status = 'Ok'; Text = (T 'dash.disk.ok' @((ConvertTo-WCHumanSize ([long]$free)), $pct)); Pct = $pct; Free = $free }
                    }
                }
            }
        } catch { }
        if (-not $r.ContainsKey('Disk')) { $r.Disk = @{ Status = 'Unknown'; Text = (T 'common.notread') } }

        # Thiet bi loi (nhe) - driver day du xem o M3
        try {
            $bad = @(Get-CimInstance -ClassName Win32_PnPEntity -Filter 'ConfigManagerErrorCode<>0' -Property Name -OperationTimeoutSec 10)
            if ($bad.Count -eq 0) { $r.Driver = @{ Status = 'Ok'; Text = (T 'dash.driver.ok'); Count = 0 } }
            else { $r.Driver = @{ Status = 'Warn'; Text = (T 'dash.driver.warn' @($bad.Count)); Count = $bad.Count } }
        } catch { $r.Driver = @{ Status = 'Unknown'; Text = (T 'common.notread') } }

        # Bao mat (nhe)
        try {
            $mp = Get-MpComputerStatus -ErrorAction Stop
            $rtp = (Get-WCProp $mp 'RealTimeProtectionEnabled')
            $sigAge = (Get-WCProp $mp 'AntivirusSignatureAge')
            if ($rtp -eq $true) {
                if (($null -ne $sigAge) -and ($sigAge -gt 7)) {
                    $r.Security = @{ Status = 'Warn'; Text = (T 'dash.security.sig' @([int]$sigAge)); SigAge = $sigAge }
                } else {
                    $r.Security = @{ Status = 'Ok'; Text = (T 'dash.security.ok') }
                }
            } else {
                $r.Security = @{ Status = 'Warn'; Text = (T 'dash.security.warn') }
            }
        } catch { $r.Security = @{ Status = 'Unknown'; Text = (T 'dash.security.unknown') } }

        # Suc khoe nhanh (tinh trang o dia vat ly)
        try {
            $disks = @(Get-PhysicalDisk -ErrorAction Stop)
            $worst = 'Ok'
            foreach ($d in $disks) {
                $hs = [string](Get-WCProp $d 'HealthStatus')
                if ($hs -ne 'Healthy') { $worst = 'Warn' }
            }
            if ($worst -eq 'Ok') { $r.Health = @{ Status = 'Ok'; Text = (T 'dash.health.ok') } }
            else { $r.Health = @{ Status = 'Warn'; Text = (T 'dash.health.warn' @('không Healthy')) } }
        } catch { $r.Health = @{ Status = 'Unknown'; Text = (T 'dash.health.unknown') } }

        # Lau hoa nhanh (so muc khoi dong ngoai Microsoft)
        try {
            $count = 0
            $runPaths = @(
                'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
                'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
            )
            foreach ($p in $runPaths) {
                if (Test-Path -LiteralPath $p) {
                    $props = Get-Item -LiteralPath $p -ErrorAction SilentlyContinue
                    if ($props) { $count += @($props.Property).Count }
                }
            }
            if ($count -gt 15) { $r.Aging = @{ Status = 'Warn'; Text = (T 'dash.aging.warn' @($count)); StartupCount = $count } }
            else { $r.Aging = @{ Status = 'Ok'; Text = (T 'dash.aging.ok'); StartupCount = $count } }
        } catch { $r.Aging = @{ Status = 'Unknown'; Text = (T 'dash.aging.unknown') } }

        return $r
    } -Done {
        param($r)
        if ($null -eq $r) { return }
        Set-WCDashboardCard $State 'ram' $r.Ram.Status $r.Ram.Text
        Set-WCDashboardCard $State 'disk' $r.Disk.Status $r.Disk.Text
        Set-WCDashboardCard $State 'driver' $r.Driver.Status $r.Driver.Text
        Set-WCDashboardCard $State 'security' $r.Security.Status $r.Security.Text
        Set-WCDashboardCard $State 'health' $r.Health.Status $r.Health.Text
        Set-WCDashboardCard $State 'aging' $r.Aging.Status $r.Aging.Text
        Invoke-WCDashboardBuildTodo $State $r
        if ($State.LastScan) {
            $State.LastScan.Text = (T 'dash.lastscan' @((Get-Date -Format 'HH:mm:ss')))
        }
    }.GetNewClosure()
    if (-not $ok) { return }
}

function Invoke-WCDashboardBuildTodo {
    # "Viec nen lam" toi da 3 muc, xep theo (loi ich / rui ro), muc thap len truoc (spec muc 5)
    param($State, $Result)
    $hostPanel = $State.TodoHost
    if (-not $hostPanel) { return }
    $hostPanel.Children.Clear()

    $todos = @()
    if ($Result.ContainsKey('Disk') -and ($Result.Disk.Status -eq 'Warn')) {
        $todos += @{ Text = (T 'dash.todo.disk'); Nav = 'm2'; Kind = 'Recommended' }
    }
    if ($Result.ContainsKey('Ram') -and ($Result.Ram.Status -eq 'Warn')) {
        $todos += @{ Text = (T 'dash.todo.ram'); Nav = 'm1'; Kind = 'Recommended' }
    }
    if ($Result.ContainsKey('Security')) {
        if ($Result.Security.Status -eq 'Warn') {
            $todos += @{ Text = (T 'dash.todo.sig'); Nav = 'm5'; Kind = 'Recommended' }
        }
    }
    if ($Result.ContainsKey('Driver') -and ($Result.Driver.Status -eq 'Warn')) {
        $todos += @{ Text = (T 'dash.todo.device'); Nav = 'm3'; Kind = 'Advanced' }
    }
    if ($Result.ContainsKey('Aging') -and ($Result.Aging.Status -eq 'Warn')) {
        $todos += @{ Text = (T 'dash.todo.startup'); Nav = 'm7'; Kind = 'Advanced' }
    }

    if ($todos.Count -eq 0) {
        # May on -> "Khong co gi can lam" (cam tao cam giac khan cap gia - spec muc 5)
        $row = New-WCHStack
        $chip = New-WCChip -Text (T 'common.status.ok') -Kind 'Ok'
        Add-WCChild $row $chip
        Add-WCChild $row (New-WCTextBlock -Text (T 'dash.todo.empty') -Size 13 -ColorKey 'WcSubtle')
        Add-WCChild $hostPanel $row
        return
    }
    # Muc rui ro thap len truoc, gioi han 3
    $todos = @($todos | Sort-Object { if ($_.Kind -eq 'Recommended') { 0 } else { 1 } } | Select-Object -First 3)
    foreach ($t in $todos) {
        $row = New-WCHStack
        $risk = Get-WCRiskInfo $t.Kind
        $chip = New-WCChip -Text $risk.Text -Kind $risk.Brush.Replace('Wc','')
        Add-WCChild $row $chip
        $nav = $t.Nav
        $btn = New-WCButton -Text $t.Text -Kind Primary -Small -OnClick { param($b) Invoke-WCShowNav $nav }.GetNewClosure()
        $btn.Margin = (New-Object Windows.Thickness(10,0,0,0))
        Add-WCChild $row $btn
        Add-WCChild $hostPanel $row
    }
}


# ============================================================================
# REGION: 12-M1-Ram.ps1
# ============================================================================

# ============================================================================
#  src/12-M1-Ram.ps1 - Module M1: TOI UU RAM (3 che do, rui ro tang dan)
#  Su that the hien trong UI: Windows chu dong dung RAM trong lam cache;
#  "RAM trong" tang chua chac lam may nhanh hon (spec M1).
# ============================================================================

Register-WCStrings 'vi' @{
    'm1.title' = 'Tối ưu RAM'
    'm1.subtitle' = 'Giải phóng bộ nhớ khi máy thật sự cần — trung thực, không hứa suông'
    'm1.fact' = 'Windows chủ động dùng RAM trống làm cache (standby). "RAM trống" cao chưa chắc máy nhanh hơn — xả cache có thể gây giật vì phải đọc đĩa lại. Chỉ nên tối ưu khi RAM thật sự căng (commit gần giới hạn, RAM khả dụng thấp, nhiều hard fault).'
    'm1.diag.ok' = 'RAM đang thoải mái, chưa cần tối ưu.'
    'm1.diag.warn' = 'RAM đang căng: khả dụng thấp ({0}), hard fault {1}/s. Có thể cân nhắc Chế độ 1.'
    'm1.diag.commit' = 'Commit ({0} / {1}) đã gần giới hạn — các app đang yêu cầu nhiều bộ nhớ ảo.'
    'm1.diag.culprit' = 'RAM đang căng, phần lớn do: {0}.'
    'm1.now' = 'Bộ nhớ hiện tại'
    'm1.used' = 'Đang dùng'
    'm1.available' = 'Khả dụng'
    'm1.standby' = 'Standby (cache)'
    'm1.modified' = 'Modified'
    'm1.free' = 'Free/Zero'
    'm1.commit' = 'Commit / Giới hạn'
    'm1.hardfaults' = 'Hard faults/giây'
    'm1.hardfaults.hint' = 'Số lần/giây hệ thống phải đọc RAM từ đĩa (pagefile). Về 0 là tốt; cao liên tục nghĩa là thiếu RAM thật.'
    'm1.topapps' = 'Ứng dụng ngốn RAM'
    'm1.topapps.hint' = 'Gom theo ứng dụng (Chrome nhiều tiến trình = 1 dòng). Tick để đóng ở Chế độ 3. KHÔNG tick sẵn.'
    'm1.col.app' = 'Ứng dụng'
    'm1.col.ram' = 'RAM (working set)'
    'm1.col.private' = 'Riêng tư (xấp xỉ)'
    'm1.col.procs' = 'Tiến trình'
    'm1.mode1' = 'Chế độ 1 — AN TOÀN'
    'm1.mode1.desc' = 'Thu nhỏ working set của tiến trình nền đang nhàn rỗi (CPU ~0 trong ~3 giây). Không đóng app nào, không đụng standby list.'
    'm1.mode2' = 'Chế độ 2 — CÂN BẰNG'
    'm1.mode2.desc' = 'Gồm Chế độ 1, thêm: xả modified page list + purge standby ưu tiên thấp. Một số app có thể chậm hơn trong giây lát vì cache bị xả.'
    'm1.mode3' = 'Chế độ 3 — MẠNH'
    'm1.mode3.desc' = 'Gồm Chế độ 2, thêm: purge TOÀN BỘ standby, trim mọi tiến trình không được bảo vệ, tạm dừng dịch vụ không thiết yếu (tự khôi phục), đóng hàng loạt app bạn tự tick.'
    'm1.mode3.services' = 'Dịch vụ tạm dừng (tự khôi phục khi thoát)'
    'm1.mode3.timeout' = 'Tự khôi phục dịch vụ sau (phút, 0 = khi thoát app)'
    'm1.run' = 'Chạy tối ưu'
    'm1.run.confirm.title' = 'Xác nhận tối ưu RAM'
    'm1.run.confirm.undo' = 'Dịch vụ tạm dừng sẽ tự khôi phục khi thoát app / hết thời hạn / bấm Hoàn tác.'
    'm1.run.confirm.noundo' = 'Working set/standby bị xả sẽ tự đầy lại theo nhu cầu (không mất dữ liệu nhưng có thể giật nhẹ lúc đầu).'
    'm1.warn.game' = 'Đang phát hiện game/ứng dụng toàn màn hình hoặc trình chiếu — purge cache lúc này dễ gây giật. Nên thoát fullscreen trước.'
    'm1.warn.hdd' = 'Máy có ổ HDD — purge standby có thể làm các app cũ chậm hơn khi đọc lại từ đĩa.'
    'm1.warn.unsaved' = 'CẢNH BÁO: các cửa sổ sau có dấu chưa lưu (*) hoặc là trình soạn thảo/trình duyệt — buộc đóng sẽ MẤT dữ liệu chưa lưu:'
    'm1.close.graceful' = 'Đóng nhẹ'
    'm1.close.force' = 'Buộc đóng'
    'm1.close.confirm' = 'Buộc đóng các app đã chọn? Tiến trình sẽ bị kill — mọi dữ liệu chưa lưu MẤT.'
    'm1.running' = 'Đang tối ưu RAM'
    'm1.running.sampling' = 'Lấy mẫu tiến trình nhàn rỗi (~3 giây)…'
    'm1.running.trim' = 'Đang thu nhỏ working set: {0} tiến trình'
    'm1.running.purge' = 'Đang xả danh sách trang hệ thống…'
    'm1.running.services' = 'Đang tạm dừng dịch vụ: {0}'
    'm1.running.closing' = 'Đang đóng ứng dụng: {0}'
    'm1.result.title' = 'Kết quả đo thật (trước / sau)'
    'm1.result.freed' = 'Khả dụng tăng thêm: {0} (tạm thời — Windows sẽ dùng lại làm cache)'
    'm1.result.none' = 'Không có cải thiện đáng kể (điều này bình thường nếu máy đang ổn).'
    'm1.result.after30' = 'Đo lại sau 30 giây'
    'm1.result.measure' = 'Đo sau 30 giây: khả dụng {0} (standby đã tự đầy lại: {1})'
    'm1.noapps' = 'Không có ứng dụng người dùng đáng kể nào đang chạy.'
    'm1.service.restored' = 'Đã khôi phục dịch vụ: {0}'
    'm1.journal.action' = 'Tạm dừng dịch vụ'
    'm1.journal.close' = 'Đóng ứng dụng'
    'm1.journal.trim' = 'Trim working set'
    'm1.journal.purge' = 'Xả standby/modified'
}
Register-WCStrings 'en' @{
    'm1.title' = 'RAM optimizer'
    'm1.subtitle' = 'Free memory when the PC truly needs it — honest, no hype'
    'm1.fact' = 'Windows actively uses free RAM as cache (standby). Higher "free RAM" does not mean a faster PC — purging cache may cause stutter as data must be re-read from disk. Only optimize when memory pressure is real (commit near limit, low available RAM, many hard faults).'
    'm1.diag.ok' = 'RAM is comfortable — no optimization needed.'
    'm1.diag.warn' = 'RAM is under pressure: low available ({0}), {1} hard faults/s. Mode 1 may help.'
    'm1.diag.commit' = 'Commit ({0} / {1}) is near the limit — apps are requesting lots of virtual memory.'
    'm1.diag.culprit' = 'RAM pressure mostly caused by: {0}.'
    'm1.now' = 'Current memory'
    'm1.used' = 'In use'
    'm1.available' = 'Available'
    'm1.standby' = 'Standby (cache)'
    'm1.modified' = 'Modified'
    'm1.free' = 'Free/Zero'
    'm1.commit' = 'Commit / Limit'
    'm1.hardfaults' = 'Hard faults/sec'
    'm1.hardfaults.hint' = 'How many times per second the system must fetch memory from disk. Near 0 is good; sustained high values mean real RAM shortage.'
    'm1.topapps' = 'RAM-hungry apps'
    'm1.topapps.hint' = 'Grouped by app (Chrome with many processes = 1 row). Tick to close in Mode 3. NOT pre-ticked.'
    'm1.col.app' = 'App'
    'm1.col.ram' = 'RAM (working set)'
    'm1.col.private' = 'Private (approx)'
    'm1.col.procs' = 'Processes'
    'm1.mode1' = 'Mode 1 — SAFE'
    'm1.mode1.desc' = 'Shrink working set of idle background processes (~0% CPU for ~3s). Closes nothing, does not touch standby list.'
    'm1.mode2' = 'Mode 2 — BALANCED'
    'm1.mode2.desc' = 'Mode 1 plus: flush modified page list + purge low-priority standby. Some apps may briefly slow as cache is dropped.'
    'm1.mode3' = 'Mode 3 — AGGRESSIVE'
    'm1.mode3.desc' = 'Mode 2 plus: purge ALL standby, trim every non-protected process, temporarily pause non-essential services (auto-restored), close apps you ticked.'
    'm1.mode3.services' = 'Services to pause (auto-restore on exit)'
    'm1.mode3.timeout' = 'Auto-restore services after (minutes, 0 = on app exit)'
    'm1.run' = 'Run optimization'
    'm1.run.confirm.title' = 'Confirm RAM optimization'
    'm1.run.confirm.undo' = 'Paused services auto-restore on app exit / timeout / Undo.'
    'm1.run.confirm.noundo' = 'Dropped working set/standby will refill on demand (no data loss, may stutter briefly).'
    'm1.warn.game' = 'A fullscreen game/app or presentation is detected — purging cache now may stutter. Consider leaving fullscreen first.'
    'm1.warn.hdd' = 'This PC has an HDD — purging standby may make older apps slower when re-reading from disk.'
    'm1.warn.unsaved' = 'WARNING: these windows look unsaved (*) or are editors/browsers — force close will LOSE unsaved data:'
    'm1.close.graceful' = 'Close gracefully'
    'm1.close.force' = 'Force close'
    'm1.close.confirm' = 'Force close selected apps? Processes will be killed — unsaved data is LOST.'
    'm1.running' = 'Optimizing RAM'
    'm1.running.sampling' = 'Sampling idle processes (~3 seconds)…'
    'm1.running.trim' = 'Trimming working set: {0} processes'
    'm1.running.purge' = 'Flushing system page lists…'
    'm1.running.services' = 'Pausing service: {0}'
    'm1.running.closing' = 'Closing app: {0}'
    'm1.result.title' = 'Measured result (before / after)'
    'm1.result.freed' = 'Available memory gained: {0} (temporary — Windows will reuse it as cache)'
    'm1.result.none' = 'No significant improvement (normal if the PC is already fine).'
    'm1.result.after30' = 'Re-measure after 30 seconds'
    'm1.result.measure' = 'After 30s: available {0} (standby refilled: {1})'
    'm1.noapps' = 'No significant user apps are running.'
    'm1.service.restored' = 'Service restored: {0}'
    'm1.journal.action' = 'Pause service'
    'm1.journal.close' = 'Close app'
    'm1.journal.trim' = 'Trim working set'
    'm1.journal.purge' = 'Purge standby/modified'
}

# ---------------------------------------------------------------------------
# DATA LAYER (Get-* thuan, tra object chuan hoa - spec 2.3)
# ---------------------------------------------------------------------------
function Get-WCRamVerdict {
    # Chan doan tu dong bang chu thuong, KHONG ep bam (spec M1)
    $snap = Get-WCMemorySnapshot
    $v = @{ Snap = $snap; Status = 'Ok'; Lines = @() }
    $totalKb = $snap.TotalKb
    $availKb = $snap.AvailableKb
    if ($null -eq $availKb) { $availKb = $snap.FreeKb }
    if ($totalKb -and ($null -ne $availKb)) {
        $pct = [math]::Round((($totalKb - $availKb) / $totalKb) * 100)
        $hf = $snap.HardFaultsPerSec
        if (($pct -ge 88) -or (($null -ne $hf) -and ($hf -ge 50))) {
            $v.Status = 'Warn'
            $v.Lines += (T 'm1.diag.warn' @((ConvertTo-WCHumanSize ([long]($availKb * 1KB))), ($(if ($null -ne $hf) { [string][int]$hf } else { '?' }))))
        } else {
            $v.Lines += (T 'm1.diag.ok')
        }
    }
    if ($snap.CommitLimitKb -and $snap.CommitKb) {
        $commitPct = [math]::Round(($snap.CommitKb / $snap.CommitLimitKb) * 100)
        if ($commitPct -ge 90) {
            $v.Status = 'Warn'
            $v.Lines += (T 'm1.diag.commit' @((ConvertTo-WCHumanSize ([long]($snap.CommitKb * 1KB))), (ConvertTo-WCHumanSize ([long]($snap.CommitLimitKb * 1KB)))))
        }
    }
    return [PSCustomObject]$v
}

function Get-WCMemoryProcessGroups {
    # Gom process theo ten hien thi; tra mang: Name, ProcessCount, WorkingSet, Private, Ids, Paths, MainWindows
    $groups = @{}
    $fgPid = 0
    try { Add-WCNativeType; $fgPid = [WinCare.Native]::GetForegroundPid() } catch { }
    foreach ($p in (Get-Process -ErrorAction SilentlyContinue)) {
        if (Test-WCProtectedProcess $p.Name) { continue }
        $path = ''
        try { $path = $p.Path } catch { }
        $display = (Get-WCProcessDisplayName -ProcessName $p.Name -Path $path)
        $key = $display
        if (-not $groups.ContainsKey($key)) {
            $groups[$key] = @{
                Name = $display; ProcessCount = 0; WorkingSet = [long]0
                Private = [long]0; Ids = @(); Paths = @(); MainWindows = @()
                Names = @{}; IsForeground = $false
            }
        }
        $g = $groups[$key]
        $g.ProcessCount++
        $g.WorkingSet += [long]$p.WorkingSet64
        $g.Private += [long]$p.PrivateMemorySize64
        $g.Ids += [int]$p.Id
        if ($path) { $g.Paths += $path }
        if (-not $g.Names.ContainsKey($p.Name)) { $g.Names[$p.Name] = $true }
        if ($p.MainWindowTitle) { $g.MainWindows += $p.MainWindowTitle }
        if ([int]$p.Id -eq $fgPid) { $g.IsForeground = $true }
    }
    $list = @()
    foreach ($k in $groups.Keys) { $list += $groups[$k] }
    $list = @($list | Sort-Object WorkingSet -Descending)
    return $list
}

function Get-WCIdleBackgroundProcessIds {
    # Lay mau CPU ~3 giay, tra Id cua tien trinh nen nhan roi, khong phai foreground,
    # khong thuoc danh sach bao ve (spec M1 che do 1)
    param($Ctx)
    $first = @{}
    foreach ($p in (Get-Process -ErrorAction SilentlyContinue)) {
        try { $first[[int]$p.Id] = @{ Cpu = $p.TotalProcessorTime; Name = $p.Name; HasWindow = [bool]$p.MainWindowTitle } } catch { }
    }
    $fgPid = 0
    try { Add-WCNativeType; $fgPid = [WinCare.Native]::GetForegroundPid() } catch { }
    if ($Ctx) { $Ctx.Log('Sampling CPU (~3s)…') }
    Start-Sleep -Seconds 3
    if ($Ctx -and $Ctx.Cancelled()) { return @() }
    $idle = @()
    foreach ($p in (Get-Process -ErrorAction SilentlyContinue)) {
        try {
            $pid2 = [int]$p.Id
            if (-not $first.ContainsKey($pid2)) { continue }
            $info = $first[$pid2]
            if (Test-WCProtectedProcess $info.Name) { continue }
            if ($info.HasWindow -and ($pid2 -eq $fgPid)) { continue }   # app dang dung truoc
            $delta = ($p.TotalProcessorTime - $info.Cpu).TotalSeconds
            if ($delta -lt 0.15) { $idle += $pid2 }                     # CPU ~0 trong cua so 3s
        } catch { }
    }
    return $idle
}

function Invoke-WCTrimProcesses {
    # Trim working set cho danh sach Id (P/Invoke EmptyWorkingSet - spec M1)
    param([int[]]$Ids, $Ctx)
    Add-WCNativeType
    $done = 0
    foreach ($id in $Ids) {
        if ($Ctx -and $Ctx.Cancelled()) { break }
        try {
            if ([WinCare.Native]::TrimWorkingSet($id)) { $done++ }
        } catch { }
    }
    return $done
}

function Invoke-WCMemoryPurge {
    # Xa modified + standby qua NtSetSystemInformation (can SeProfileSingleProcessPrivilege)
    # Lenh: 2=EmptyWorkingSets, 3=FlushModifiedList, 4=PurgeLowPriorityStandby, 5=PurgeStandbyList
    param([int[]]$Commands, $Ctx)
    Add-WCNativeType
    $priv = [WinCare.Native]::EnableProfilePrivilege()
    if (-not $priv) { Write-WCLog 'WARN' 'Khong bat duoc SeProfileSingleProcessPrivilege'; return $false }
    $allOk = $true
    foreach ($cmd in $Commands) {
        if ($Ctx -and $Ctx.Cancelled()) { break }
        $status = [WinCare.Native]::RunMemoryListCommand($cmd)
        if ($status -ne 0) {
            $allOk = $false
            Write-WCLog 'WARN' ('MemoryListCommand ' + $cmd + ' -> NTSTATUS 0x' + $status.ToString('X8'))
        }
    }
    return $allOk
}

function Get-WCPausableServices {
    # Chi dich vu DANG CHAY, khong phai Microsoft-core, khong co dependent dang chay.
    # Whitelist ung vien kiem chung (spec M1: "whitelist da kiem chung tren chinh may do")
    $candidates = @('DiagTrack','Fax','MapsBroker','PhoneSvc','RetailDemo','WbioSrvc','wisvc','Spooler','WSearch')
    $result = @()
    foreach ($name in $candidates) {
        try {
            $svc = Get-Service -Name $name -ErrorAction Stop
            if ($svc.Status -ne 'Running') { continue }
            $hasRunningDependent = $false
            foreach ($dep in @($svc.DependentServices)) {
                if ($dep.Status -eq 'Running') { $hasRunningDependent = $true; break }
            }
            if ($hasRunningDependent) { continue }
            $result += @{ Name = $svc.Name; Display = $svc.DisplayName; StartType = [string]$svc.StartType }
        } catch { }
    }
    return $result
}

function Invoke-WCPauseService {
    # Dung tam 1 dich vu + ghi journal AutoRestore (tu khoi phuc khi thoat/timeout/undo)
    param([Parameter(Mandatory)]$Service, [bool]$DryRun = $false)
    $name = $Service['Name']
    if ($DryRun) { return $true }
    $entry = Add-WCJournalEntry -Module 'M1' -Action (T 'm1.journal.action') -Target $name `
        -OldValue 'Running' -UndoType 'service.start' -UndoArgs @{
            Name = $name; StartType = $Service['StartType'] } -AutoRestore
    try {
        Stop-Service -Name $name -Force -ErrorAction Stop
        Complete-WCJournalEntry -Entry $entry -Result 'Ok'
        return $true
    } catch {
        Complete-WCJournalEntry -Entry $entry -Result ('Failed: ' + $_.Exception.Message)
        return $false
    }
}

function Get-WCUnsavedWindowTitles {
    # Phat hien cua so co dau '*' (chua luu) hoac trinh soan thao/trinh duyet (spec M1)
    param([Parameter(Mandatory)]$Titles)
    $unsaved = @()
    foreach ($t in $Titles) {
        if ([string]::IsNullOrEmpty($t)) { continue }
        if ($t -like '*\**' -or ($t -like '*(*)*' -and $t -match '\*\)$')) { $unsaved += $t }
    }
    return $unsaved
}

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
function Initialize-WCModuleM1 {
    $state = @{
        Timer = $null; Gauge = @{}; Mode = 1
        Apps = @(); SelectedApps = @(); ResultHost = $null
        After30Check = $null
    }

    Register-WCNavItem -Key 'm1' -Badge 'M1' -Title (T 'm1.title') -Order 20 -Builder {
        New-WCM1Panel $state
    }.GetNewClosure() -OnShow {
        Start-WCM1LiveGauge $state
    }.GetNewClosure() -OnHide {
        Stop-WCM1LiveGauge $state
    }.GetNewClosure()
}

function New-WCM1Panel {
    param($State)
    $root = New-Object Windows.Controls.ScrollViewer
    $root.VerticalScrollBarVisibility = [Windows.Controls.ScrollBarVisibility]::Auto
    $hostPanel = New-WCVStack -Spacing 14
    $hostPanel.Margin = (New-Object Windows.Thickness(20))
    $root.Content = $hostPanel

    # Tieu de
    $titleRow = New-WCHStack
    $titleRow.Children.Add((New-WCHeading (T 'm1.title'))) | Out-Null
    $betaChip = New-WCChip -Text (T 'common.beta') -Kind 'Warn'
    $betaChip.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $titleRow.Children.Add($betaChip) | Out-Null
    Add-WCChild $hostPanel $titleRow
    Add-WCChild $hostPanel (New-WCSubtitle (T 'm1.subtitle'))

    # Su that ve RAM (spec: su that phai the hien trong UI)
    $fact = New-WCSection -Title (T 'm1.now')
    Add-WCChild $fact.Body (New-WCTextBlock -Text (T 'm1.fact') -Size 12.5 -ColorKey 'WcSubtle' -Wrap)
    Add-WCChild $fact.Body (New-WCSpacer -Height 8)

    # Luoi dong ho truc tiep (cap nhat 1.5s, chi khi man hinh dang hien - spec M1)
    $gaugeGrid = New-Object Windows.Controls.Grid
    for ($i = 0; $i -lt 3; $i++) {
        $cd = New-Object Windows.Controls.ColumnDefinition
        $cd.Width = (New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star))
        $gaugeGrid.ColumnDefinitions.Add($cd) | Out-Null
    }
    $gaugeDefs = @(
        @{ Key = 'used';        Label = (T 'm1.used');        Fmt = 'size' }
        @{ Key = 'available';   Label = (T 'm1.available');   Fmt = 'size' }
        @{ Key = 'standby';     Label = (T 'm1.standby');     Fmt = 'size' }
        @{ Key = 'modified';    Label = (T 'm1.modified');    Fmt = 'size' }
        @{ Key = 'commit';      Label = (T 'm1.commit');      Fmt = 'commit' }
        @{ Key = 'hardfaults';  Label = (T 'm1.hardfaults');  Fmt = 'num' }
    )
    $idx = 0
    foreach ($def in $gaugeDefs) {
        $card = New-Object Windows.Controls.Border
        $card.CornerRadius = (New-Object Windows.CornerRadius(8))
        $card.Padding = (New-Object Windows.Thickness(12))
        $card.Margin = (New-Object Windows.Thickness(0,0,0,0))
        $card.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'WcCardBg2')
        $card.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'WcBorder')
        $card.BorderThickness = (New-Object Windows.Thickness(1))
        $inner = New-WCVStack -Spacing 3
        $lbl = New-WCTextBlock -Text $def.Label -Size 11.5 -ColorKey 'WcSubtle'
        $val = New-WCTextBlock -Text '—' -Size 17 -Weight 'SemiBold'
        $hint = $null
        if ($def.Key -eq 'hardfaults') {
            $hint = New-WCTextBlock -Text (T 'm1.hardfaults.hint') -Size 10.5 -ColorKey 'WcSubtle' -Wrap
            $hint.ToolTip = (T 'm1.hardfaults.hint')
        }
        Add-WCChild $inner $lbl
        Add-WCChild $inner $val
        if ($hint) { Add-WCChild $inner $hint }
        $card.Child = $inner
        [Windows.Controls.Grid]::SetColumn($card, ($idx % 3))
        [Windows.Controls.Grid]::SetRow($card, [math]::Floor($idx / 3))
        if ($gaugeGrid.RowDefinitions.Count -lt ([math]::Floor($idx / 3) + 1)) {
            $gaugeGrid.RowDefinitions.Add((New-Object Windows.Controls.RowDefinition)) | Out-Null
        }
        $gaugeGrid.Children.Add($card) | Out-Null
        $State.Gauge[$def.Key] = @{ Value = $val; Def = $def }
        $idx++
    }
    Add-WCChild $fact.Body $gaugeGrid
    $usedBar = New-WCProgressBar
    $State.Gauge['bar'] = @{ Value = $usedBar }
    Add-WCChild $fact.Body $usedBar
    # Dong chan doan tu dong (chu thuong, khong ep bam - spec M1)
    $diagText = New-WCTextBlock -Text (T 'common.loading') -Size 13 -ColorKey 'WcSubtle' -Wrap
    $State.DiagText = $diagText
    Add-WCChild $fact.Body $diagText
    Add-WCChild $hostPanel $fact.Root

    # Ung dung ngon RAM
    $appsSec = New-WCSection -Title (T 'm1.topapps') -Subtitle (T 'm1.topapps.hint')
    $appsList = New-WCCheckList
    $State.AppsList = $appsList
    Add-WCChild $appsSec.Body $appsList
    $appsSpinner = New-WCSpinner
    $State.AppsSpinner = $appsSpinner
    Add-WCChild $appsSec.Body $appsSpinner
    $appsBtnRow = New-WCHStack
    $State.CloseGracefulBtn = New-WCButton -Text (T 'm1.close.graceful') -OnClick { param($b) Invoke-WCM1CloseSelected $State $false }.GetNewClosure()
    $State.CloseForceBtn = New-WCButton -Text (T 'm1.close.force') -Kind Danger -OnClick { param($b) Invoke-WCM1CloseSelected $State $true }.GetNewClosure()
    $appsBtnRow.Children.Add($State.CloseGracefulBtn) | Out-Null
    $appsBtnRow.Children.Add($State.CloseForceBtn) | Out-Null
    Add-WCChild $appsSec.Body $appsBtnRow
    Add-WCChild $hostPanel $appsSec.Root

    # 3 che do (radio qua danh sach card)
    $modeSec = New-WCSection -Title (T 'm1.title')
    $modes = @(
        @{ Id = 1; Title = (T 'm1.mode1'); Desc = (T 'm1.mode1.desc'); Risk = 'Recommended' }
        @{ Id = 2; Title = (T 'm1.mode2'); Desc = (T 'm1.mode2.desc'); Risk = 'Advanced' }
        @{ Id = 3; Title = (T 'm1.mode3'); Desc = (T 'm1.mode3.desc'); Risk = 'Risky' }
    )
    foreach ($m in $modes) {
        $risk = Get-WCRiskInfo $m.Risk
        $row = New-Object Windows.Controls.Border
        $row.CornerRadius = (New-Object Windows.CornerRadius(8))
        $row.BorderThickness = (New-Object Windows.Thickness(1))
        $row.Padding = (New-Object Windows.Thickness(12))
        $row.Margin = (New-Object Windows.Thickness(0,4,0,4))
        $row.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'WcCardBg2')
        $row.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'WcBorder')
        $row.Tag = $m
        $inner = New-WCVStack -Spacing 4
        $topRow = New-WCHStack
        $rb = New-Object Windows.Controls.RadioButton
        $rb.GroupName = 'wcm1mode'
        $rb.VerticalAlignment = [Windows.VerticalAlignment]::Center
        if ($m.Id -eq 1) { $rb.IsChecked = $true }
        $rb.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'WcText')
        $modeId = $m.Id
        $rb.Add_Checked({ $State.Mode = $modeId }.GetNewClosure())
        $topRow.Children.Add($rb) | Out-Null
        $t = New-WCTextBlock -Text $m.Title -Size 13.5 -Weight 'SemiBold'
        $t.VerticalAlignment = [Windows.VerticalAlignment]::Center
        $topRow.Children.Add($t) | Out-Null
        $chip = New-WCChip -Text $risk.Text -Kind $risk.Brush.Replace('Wc','')
        $chip.VerticalAlignment = [Windows.VerticalAlignment]::Center
        $topRow.Children.Add($chip) | Out-Null
        Add-WCChild $inner $topRow
        Add-WCChild $inner (New-WCTextBlock -Text $m.Desc -Size 12 -ColorKey 'WcSubtle' -Wrap)
        if ($m.Id -eq 3) {
            $svcRow = New-WCHStack
            $svcLbl = New-WCTextBlock -Text (T 'm1.mode3.timeout') -Size 12 -ColorKey 'WcSubtle'
            $svcLbl.VerticalAlignment = [Windows.VerticalAlignment]::Center
            $svcRow.Children.Add($svcLbl) | Out-Null
            $num = New-Object Windows.Controls.TextBox
            $num.Style = (Get-WCControlStyles)['WcInput']
            $num.Width = 70
            $num.Text = '0'
            $num.Margin = (New-Object Windows.Thickness(8,0,0,0))
            $State.TimeoutBox = $num
            $svcRow.Children.Add($num) | Out-Null
            Add-WCChild $inner $svcRow
        }
        $row.Child = $inner
        # Bam vao card = chon che do
        $row.Add_MouseLeftButtonDown({ $rb.IsChecked = $true }.GetNewClosure())
        Add-WCChild $modeSec.Body $row
    }
    $runBtn = New-WCButton -Text (T 'm1.run') -Kind Primary -OnClick { param($b) Invoke-WCM1Run $State }.GetNewClosure()
    $runBtn.Margin = (New-Object Windows.Thickness(0,10,0,0))
    Add-WCChild $modeSec.Body $runBtn
    Add-WCChild $hostPanel $modeSec.Root

    # Vung ket qua
    $resultSec = New-WCSection -Title (T 'm1.result.title')
    $State.ResultHost = $resultSec.Body
    Add-WCChild $hostPanel $resultSec.Root
    $resultSec.Root.Visibility = [Windows.Visibility]::Collapsed
    $State.ResultSection = $resultSec

    return $root
}

function Update-WCM1Gauge {
    param($State)
    try {
        $snap = Get-WCMemorySnapshot
        $g = $State.Gauge
        if ($snap.TotalKb -and $snap.UsedKb) {
            $g['used'].Value.Text = (ConvertTo-WCHumanSize ([long]($snap.UsedKb * 1KB)))
            $g['bar'].Value.Value = [math]::Round((($snap.UsedKb / $snap.TotalKb) * 100))
        }
        $avail = $snap.AvailableKb; if ($null -eq $avail) { $avail = $snap.FreeKb }
        $g['available'].Value.Text = ($(if ($null -ne $avail) { ConvertTo-WCHumanSize ([long]($avail * 1KB)) } else { '—' }))
        $g['standby'].Value.Text = ($(if ($null -ne $snap.StandbyKb) { ConvertTo-WCHumanSize ([long]($snap.StandbyKb * 1KB)) } else { '—' }))
        $g['modified'].Value.Text = ($(if ($null -ne $snap.ModifiedKb) { ConvertTo-WCHumanSize ([long]($snap.ModifiedKb * 1KB)) } else { '—' }))
        if ($snap.CommitKb -and $snap.CommitLimitKb) {
            $g['commit'].Value.Text = ('{0} / {1}' -f (ConvertTo-WCHumanSize ([long]($snap.CommitKb * 1KB))), (ConvertTo-WCHumanSize ([long]($snap.CommitLimitKb * 1KB))))
        }
        $g['hardfaults'].Value.Text = ($(if ($null -ne $snap.HardFaultsPerSec) { [string][int]$snap.HardFaultsPerSec } else { '—' }))
        # Chan doan
        $verdict = Get-WCRamVerdict
        $State.DiagText.Text = ([string]::Join(' ', $verdict.Lines))
    } catch { }
}

function Start-WCM1LiveGauge {
    # Chi chay timer khi man hinh dang hien (spec: dung polling khi an)
    param($State)
    if ($State.Timer) { return }
    Update-WCM1Gauge $State
    $State.Timer = New-Object Windows.Threading.DispatcherTimer
    $State.Timer.Interval = [TimeSpan]::FromMilliseconds(1500)
    $State.Timer.Add_Tick({ Update-WCM1Gauge $State }.GetNewClosure())
    $State.Timer.Start()
    # Tai danh sach app lan dau
    Invoke-WCM1LoadApps $State
}

function Stop-WCM1LiveGauge {
    param($State)
    if ($State.Timer) {
        $State.Timer.Stop()
        $State.Timer = $null
    }
}

function Invoke-WCM1LoadApps {
    param($State)
    $ok = Start-WCTask -Id 'm1.apps' -Title (T 'm1.topapps') -Worker {
        param($ctx, $s)
        return @(Get-WCMemoryProcessGroups)
    } -Done {
        param($result)
        $State.AppsSpinner.Visibility = [Windows.Visibility]::Collapsed
        Clear-WCCheckList $State.AppsList
        $items = @($result)
        if (($items.Count -eq 0) -or ($null -eq $items[0])) {
            Add-WCChild $State.AppsList (New-WCTextBlock -Text (T 'm1.noapps') -ColorKey 'WcSubtle' -Wrap)
            return
        }
        foreach ($g in $items) {
            if ($g.WorkingSet -lt 20MB) { continue }   # chi hien app dang ke
            $main = ''
            if ($g.MainWindows.Count -gt 0) { $main = ' | ' + $g.MainWindows[0] }
            Add-WCCheckRow -List $State.AppsList -Item $g -Checked:$false -TextColumns @(
                $g.Name,
                (ConvertTo-WCHumanSize $g.WorkingSet),
                (ConvertTo-WCHumanSize $g.Private),
                ('x' + $g.ProcessCount + $main)
            )
        }
    }.GetNewClosure()
    if (-not $ok) { return }   # dang chay roi
}

function Invoke-WCM1CloseSelected {
    param($State, [bool]$Force)
    $selected = @(Get-WCCheckRowSelection $State.AppsList)
    if ($selected.Count -eq 0) {
        Show-WCToast (T 'common.empty') 'Info'
        return
    }
    if ($Force) {
        # Canh bao mat du lieu chua luu (spec M1: phat hien dau '*')
        $unsavedTitles = @()
        foreach ($g in $selected) { $unsavedTitles += @(Get-WCUnsavedWindowTitles -Titles $g.MainWindows) }
        $msg = (T 'm1.close.confirm')
        if ($unsavedTitles.Count -gt 0) {
            $msg = (T 'm1.warn.unsaved') + "`n  • " + ([string]::Join("`n  • ", $unsavedTitles)) + "`n`n" + $msg
        }
        if (-not (Show-WCConfirm -Title (T 'm1.close.force') -Message $msg -NotUndoable (T 'm1.close.confirm') -Danger)) { return }
    }
    $names = @()
    foreach ($g in $selected) { $names += $g.Name }
    $closeArgs = @{ Selected = $selected; Force = $Force }
    Start-WCTask -Id 'm1.close' -Title (T 'm1.close.force') -ShowStatus -Args $closeArgs -Worker {
        param($ctx, $s)
        $closed = 0
        foreach ($g in $s.Selected) {
            if ($ctx.Cancelled()) { break }
            $ctx.Log(('Closing: ' + $g.Name))
            foreach ($procId in $g.Ids) {
                try {
                    $p = Get-Process -Id $procId -ErrorAction Stop
                    if (-not $s.Force) {
                        $null = $p.CloseMainWindow()
                        Start-Sleep -Milliseconds 600
                        if (-not $p.HasExited) { continue }   # khong chet -> bo qua (dong nhe)
                    } else {
                        Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
                    }
                    $closed++
                } catch { }
            }
        }
        return @{ Closed = $closed }
    } -Done {
        param($r)
        Show-WCToast (T 'common.success') 'Ok'
        Invoke-WCM1LoadApps $State
    }.GetNewClosure()
}

function Invoke-WCM1Run {
    param($State)
    $mode = $State.Mode
    # Canh bao truoc khi chay (game/fullscreen, HDD - spec M1)
    $warns = @()
    $state2 = Get-WCNotificationStateText
    if ($state2 -eq 'fullscreen' -or $state2 -eq 'presentation' -or $state2 -eq 'busy') {
        $warns += (T 'm1.warn.game')
    }
    if ($mode -ge 2 -and (Get-WCIsHDDPresent)) { $warns += (T 'm1.warn.hdd') }

    $undoable = (T 'm1.run.confirm.undo')
    $noundo = (T 'm1.run.confirm.noundo')
    $selectedApps = @(Get-WCCheckRowSelection $State.AppsList)
    $svcNames = @()
    if ($mode -eq 3) {
        $pausable = @(Get-WCPausableServices)
        foreach ($s in $pausable) { $svcNames += $s.Display }
    }
    $summaryLines = @()
    $summaryLines += (T ('m1.mode' + $mode))
    if ($mode -eq 3 -and $svcNames.Count -gt 0) {
        $summaryLines += ((T 'm1.mode3.services') + ': ' + ([string]::Join(', ', $svcNames)))
    }
    if ($mode -eq 3 -and $selectedApps.Count -gt 0) {
        $appNames = @(); foreach ($a in $selectedApps) { $appNames += $a.Name }
        $summaryLines += ((T 'm1.close.force') + ': ' + ([string]::Join(', ', $appNames)))
    }
    $msg = ([string]::Join("`n", $summaryLines))
    if ($warns.Count -gt 0) { $msg = ([string]::Join("`n", $warns)) + "`n`n" + $msg }
    $isDanger = ($mode -eq 3)
    if (-not (Show-WCConfirm -Title (T 'm1.run.confirm.title') -Message $msg -Undoable $undoable -NotUndoable $noundo -Danger:$isDanger)) { return }

    $timeoutMin = 0
    if ($mode -eq 3 -and $State.TimeoutBox) {
        $t = 0
        if ([int]::TryParse($State.TimeoutBox.Text, [ref]$t)) { $timeoutMin = $t }
    }
    $before = Get-WCMemorySnapshot
    $dry = Test-WCDryRunMode
    $runArgs = @{ Mode = $mode; DryRun = $dry; SelectedApps = $selectedApps }

    $ok = Start-WCTask -Id 'm1.run' -Title (T 'm1.running') -ShowStatus -Args $runArgs -Worker {
        param($ctx, $s)
        $ctx.Progress(5, (T 'm1.running.sampling'))
        $report = @{ Trimmed = 0; Purged = $false; Services = @(); Closed = 0; Warnings = @() }

        # Che do 1: thu gom working set tien trinh nen nhan roi
        $idleIds = @(Get-WCIdleBackgroundProcessIds -Ctx $ctx)
        if ($ctx.Cancelled()) { return @{ Cancelled = $true } }
        $ctx.Progress(30, ((T 'm1.running.trim') -f $idleIds.Count))
        if (-not $s.DryRun) {
            $report.Trimmed = (Invoke-WCTrimProcesses -Ids ([int[]]$idleIds) -Ctx $ctx)
            Add-WCJournalEntry -Module 'M1' -Action (T 'm1.journal.trim') -Target ($idleIds.Count.ToString() + ' processes') -OldValue '' -UndoType ''
        }

        if ($s.Mode -ge 2) {
            if ($ctx.Cancelled()) { return @{ Cancelled = $true } }
            $ctx.Progress(55, (T 'm1.running.purge'))
            $cmds = @(3, 4)   # FlushModifiedList + PurgeLowPriorityStandby
            if ($s.Mode -eq 3) { $cmds = @(2, 3, 4, 5) }   # + EmptyWorkingSets + PurgeStandbyList
            if (-not $s.DryRun) {
                $report.Purged = (Invoke-WCMemoryPurge -Commands ([int[]]$cmds) -Ctx $ctx)
                Add-WCJournalEntry -Module 'M1' -Action (T 'm1.journal.purge') -Target ('commands=' + ($cmds -join ',')) -OldValue '' -UndoType ''
            }
        }

        if ($s.Mode -eq 3) {
            # Tam dung dich vu (tu khoi phuc - spec M1)
            if ($ctx.Cancelled()) { return @{ Cancelled = $true } }
            $i = 0
            foreach ($svc in @(Get-WCPausableServices)) {
                if ($ctx.Cancelled()) { break }
                $ctx.Progress((60 + $i), ((T 'm1.running.services') -f $svc.Display))
                $ok2 = (Invoke-WCPauseService -Service $svc -DryRun:$s.DryRun)
                if ($ok2) { $report.Services += $svc.Name }
                $i++
            }
            # Dong app da tick (dong nhe truoc - spec M1)
            foreach ($g in $s.SelectedApps) {
                if ($ctx.Cancelled()) { break }
                $ctx.Log(('Closing: ' + $g.Name))
                foreach ($procId in $g.Ids) {
                    try {
                        $p = Get-Process -Id $procId -ErrorAction Stop
                        $null = $p.CloseMainWindow()
                        Start-Sleep -Milliseconds 500
                        if (-not $p.HasExited) { Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue }
                        $report.Closed++
                    } catch { }
                }
                Add-WCJournalEntry -Module 'M1' -Action (T 'm1.journal.close') -Target $g.Name -OldValue '' -UndoType ''
            }
        }
        $ctx.Progress(95, (T 'common.loading'))
        return $report
    } -Done {
        param($report)
        $after = Get-WCMemorySnapshot
        Show-WCM1Result $State $before $after $report
        if ($timeoutMin -gt 0) {
            # Tu khoi phuc dich vu sau thoi han nguoi dung chon
            $timer = New-Object Windows.Threading.DispatcherTimer
            $timer.Interval = [TimeSpan]::FromMinutes($timeoutMin)
            $timer.Add_Tick({
                Restore-WCPendingSessionEntries
                $timer.Stop()
                Show-WCToast (T 'm1.service.restored' @('')) 'Ok'
            }.GetNewClosure())
            $timer.Start()
        }
        Invoke-WCM1LoadApps $State
    }.GetNewClosure()
    if (-not $ok) { Show-WCToast (T 'common.running' @((T 'm1.running'))) 'Info' }
}

function Show-WCM1Result {
    # Ket qua trung thuc: do that truoc/sau, noi ro la tam thoi (spec 1, M1)
    param($State, $Before, $After, $Report)
    $body = $State.ResultHost
    $body.Children.Clear()
    $State.ResultSection.Root.Visibility = [Windows.Visibility]::Visible

    $beforeAvail = $Before.AvailableKb; if ($null -eq $beforeAvail) { $beforeAvail = $Before.FreeKb }
    $afterAvail = $After.AvailableKb; if ($null -eq $afterAvail) { $afterAvail = $After.FreeKb }
    $deltaTxt = (T 'm1.result.none')
    if (($null -ne $beforeAvail) -and ($null -ne $afterAvail)) {
        $deltaKb = $afterAvail - $beforeAvail
        if ($deltaKb -gt 50MB / 1KB) {
            $deltaTxt = (T 'm1.result.freed' @((ConvertTo-WCHumanSize ([long]($deltaKb * 1KB)))))
        }
    }
    Add-WCChild $body (New-WCTextBlock -Text $deltaTxt -Size 14 -Weight 'SemiBold' -Wrap)

    $rows = @(
        @{ L = (T 'common.before'); B = $beforeAvail; A = $afterAvail }
        @{ L = (T 'm1.standby'); B = $Before.StandbyKb; A = $After.StandbyKb }
        @{ L = (T 'm1.commit'); B = $Before.CommitKb; A = $After.CommitKb }
    )
    $table = New-WCTable -Columns @(
        @{ Header = ''; Prop = 'C0'; Width = 220 }
        @{ Header = (T 'common.before'); Prop = 'C1'; Width = 160 }
        @{ Header = (T 'common.after'); Prop = 'C2'; Width = 160 }
    )
    foreach ($r in $rows) {
        $row = [PSCustomObject]@{
            C0 = $r.L
            C1 = ($(if ($null -ne $r.B) { ConvertTo-WCHumanSize ([long]($r.B * 1KB)) } else { '—' }))
            C2 = ($(if ($null -ne $r.A) { ConvertTo-WCHumanSize ([long]($r.A * 1KB)) } else { '—' }))
        }
        $table.Items.Add($row) | Out-Null
    }
    Add-WCChild $body $table

    if ($Report -and ($Report.ContainsKey('Services')) -and (@($Report.Services).Count -gt 0)) {
        Add-WCChild $body (New-WCTextBlock -Text ((T 'm1.mode3.services') + ': ' + ([string]::Join(', ', @($Report.Services)))) -Size 12 -ColorKey 'WcSubtle' -Wrap)
    }

    # Do lai sau 30 giay (tuy chon - standby se day lai - spec M1)
    $cb = New-Object Windows.Controls.CheckBox
    $cb.Content = (T 'm1.result.after30')
    $cb.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'WcText')
    $cb.Margin = (New-Object Windows.Thickness(0,8,0,0))
    $cbHandler = {
        param($c)
        if ($c.IsChecked -ne $true) { return }
        $after30 = Get-WCMemorySnapshot
        $av = $after30.AvailableKb; if ($null -eq $av) { $av = $after30.FreeKb }
        $sb = $after30.StandbyKb
        $line = (T 'm1.result.measure' @(
            ($(if ($null -ne $av) { ConvertTo-WCHumanSize ([long]($av * 1KB)) } else { '—' })),
            ($(if ($null -ne $sb) { ConvertTo-WCHumanSize ([long]($sb * 1KB)) } else { '—' }))
        ))
        Add-WCChild $State.ResultHost (New-WCTextBlock -Text $line -Size 12.5 -ColorKey 'WcSubtle' -Wrap)
    }
    $cb.Add_Checked({ try { & $cbHandler $cb } catch { } }.GetNewClosure())
    Add-WCChild $body $cb
}


# ============================================================================
# REGION: 13-M2-Disk.ps1
# ============================================================================

# ============================================================================
#  src/13-M2-Disk.ps1 - Module M2: DON O CUNG
#  Mau tac vu chuan: QUET (chi doc) -> XEM LAI -> XAC NHAN -> CHAY -> KET QUA.
#  Ket qua do bang chenh lech free space THAT cua o he thong (khong cong tep).
#  Moi phep xoa di qua Remove-WCItem (Assert-SafePath + whitelist - spec 2.5).
#  Man "Phan tich dung luong" chi chuyen Thuong rac qua Send-WCFileToRecycleBin.
#  Toi uu o: SSD -> TRIM; HDD -> phan tich roi moi Defrag; khong bao gio defrag SSD.
# ============================================================================

Register-WCStrings 'vi' @{
    'm2.title' = 'Dọn ổ cứng'
    'm2.subtitle' = 'Chỉ dọn thứ Windows tự tạo lại được. Kết quả đo bằng dung lượng trống thật — trung thực, không hứa suông.'
    'm2.lowspace' = 'Ổ hệ thống sắp đầy: còn trống {0} ({1}%)'
    'm2.clean.title' = 'Dọn dẹp'
    'm2.clean.subtitle' = 'Quét (chỉ đọc) → xem lại → xác nhận → chạy. Chỉ mục KHUYẾN NGHỊ được tick sẵn; NÂNG CAO / RỦI RO tự bạn quyết định.'
    'm2.scan' = 'Quét'
    'm2.scanning' = 'Đang quét (chỉ đọc)'
    'm2.scan.item' = 'Đang quét: {0}'
    'm2.scan.rb' = 'Đang đếm Thùng rác…'
    'm2.scan.done' = 'Quét xong: {0} danh mục, ước dọn được {1}. Di chuột vào từng mục để xem "có thể mất gì".'
    'm2.empty' = 'Không có gì cần dọn — máy đang gọn.'
    'm2.files' = '{0} tệp'
    'm2.items' = '{0} mục'
    'm2.roots' = 'Vị trí: {0}'
    'm2.run' = 'Dọn mục đã chọn'
    'm2.select.none' = 'Chưa chọn mục nào.'
    'm2.confirm.title' = 'Xác nhận dọn ổ'
    'm2.confirm.undo' = 'Tắt ngủ đông có thể bật lại bằng powercfg /h on (xem Lịch sử & Hoàn tác).'
    'm2.confirm.noundo' = 'Các tệp được dọn sẽ xóa vĩnh viễn (không vào Thùng rác); cache sẽ tự tạo lại. Dọn Thùng rác nghĩa là không phục hồi được nội dung trong đó.'
    'm2.running' = 'Đang dọn ổ'
    'm2.running.item' = 'Đang dọn: {0}'
    'm2.result.title' = 'Kết quả (đo bằng dung lượng trống thật)'
    'm2.result.freed' = 'Đã giải phóng: {0}'
    'm2.result.free' = 'Dung lượng trống ổ {0}'
    'm2.result.none' = 'Dung lượng trống không tăng — có thể tệp đang bị khóa hoặc Windows đã tự dọn bớt.'
    'm2.result.skipped' = '{0} mục bị bỏ qua êm (đang bị khóa / đang dùng) — không hiện hộp thoại lỗi từng tệp.'
    'm2.result.rescan' = 'Bấm "Quét lại" để cập nhật danh sách.'
    'm2.viewlog' = 'Xem nhật ký'
    'm2.journal.clean' = 'Dọn'
    'm2.journal.hibernate' = 'Tắt ngủ đông'
    'm2.journal.bigfile' = 'Chuyển tệp vào Thùng rác'
    'm2.journal.retrim' = 'Tối ưu ổ (TRIM)'
    'm2.journal.defrag' = 'Chạy Defrag'
    'm2.skipped.cat' = 'Bỏ qua: {0}'
    'm2.wu.skip' = 'Đang chờ khởi động lại sau cập nhật — đã bỏ qua cache Windows Update.'
    'm2.cat.temp.user' = 'Tệp tạm người dùng (cũ > 24 giờ)'
    'm2.cat.temp.user.loss' = 'Chỉ xóa tệp cũ hơn 24 giờ; không mất dữ liệu cá nhân. Ứng dụng đang chạy có thể phải tạo lại tệp tạm của nó.'
    'm2.cat.temp.windows' = 'Tệp tạm Windows (cũ > 24 giờ)'
    'm2.cat.temp.windows.loss' = 'Chỉ xóa tệp cũ hơn 24 giờ — Windows tự tạo lại khi cần.'
    'm2.cat.recycle' = 'Thùng rác'
    'm2.cat.recycle.loss' = 'Toàn bộ tệp trong Thùng rác sẽ bị xóa vĩnh viễn — không thể phục hồi. Hãy chắc chắn bạn không cần lấy lại gì trong đó.'
    'm2.cat.wer' = 'Báo cáo lỗi Windows (WER)'
    'm2.cat.wer.loss' = 'Mất báo cáo lỗi cũ — chỉ dùng cho chẩn đoán, không ảnh hưởng hoạt động.'
    'm2.cat.crashdumps' = 'Bản ghi lỗi ứng dụng (CrashDumps)'
    'm2.cat.crashdumps.loss' = 'Mất bản ghi lỗi dùng để chẩn đoán; ứng dụng vẫn chạy bình thường.'
    'm2.cat.minidump' = 'Bản ghi lỗi xanh (Minidump)'
    'm2.cat.minidump.loss' = 'Mất bản ghi các lần lỗi xanh gần nhất — nếu còn đang điều tra BSOD thì đừng dọn mục này.'
    'm2.cat.lkr' = 'LiveKernelReports'
    'm2.cat.lkr.loss' = 'Mất báo cáo chẩn đoán kernel — không ảnh hưởng hoạt động.'
    'm2.cat.do' = 'Cache Delivery Optimization'
    'm2.cat.do.loss' = 'Phần cập nhật đã tải về để chia sẻ sẽ tải lại khi cần — không mất dữ liệu.'
    'm2.cat.browser' = 'Cache trình duyệt (Chrome / Edge / Brave / Firefox)'
    'm2.cat.browser.loss' = 'Chỉ xóa cache (ảnh, mã nguồn đã tải). KHÔNG đụng cookie, mật khẩu, lịch sử, Local Storage. Trang web mở lần đầu sau khi dọn sẽ chậm hơn một chút.'
    'm2.cat.browser.open' = 'Trình duyệt đang mở — một số tệp sẽ bị bỏ qua (không bắt buộc đóng).'
    'm2.cat.wu' = 'Cache tải Windows Update'
    'm2.cat.wu.loss' = 'Bản cập nhật đã tải sẽ phải tải lại khi cài (tốn mạng). Không đụng lịch sử cập nhật (DataStore). Khi chạy sẽ tạm dừng dịch vụ wuauserv / bits rồi khôi phục đúng trạng thái cũ.'
    'm2.cat.wu.pending' = 'Đang chờ khởi động lại — mục này sẽ bị bỏ qua.'
    'm2.cat.shader' = 'Cache shader (DirectX / NVIDIA OpenGL)'
    'm2.cat.shader.loss' = 'Lần mở game đầu tiên sau khi dọn có thể giật hoặc vào chậm hơn vì phải dựng lại shader.'
    'm2.cat.appcache' = 'Cache ứng dụng (Discord, Teams, Spotify)'
    'm2.cat.appcache.loss' = 'Ứng dụng tự tạo lại cache (lần mở đầu hơi chậm); Spotify có thể phải tải lại nhạc đã lưu vào bộ nhớ đệm. Không mất tin nhắn hay cài đặt.'
    'm2.cat.hibernate' = 'Tắt ngủ đông (xóa hiberfil.sys)'
    'm2.cat.hibernate.loss' = 'Mất chế độ Ngủ đông và Khởi động nhanh cho đến khi bật lại bằng powercfg /h on.'
    'm2.cat.windowsold' = 'Windows.old (bản Windows cũ)'
    'm2.cat.windowsold.loss' = 'Chưa hỗ trợ xóa tự động trong phiên bản này. Nếu chắc chắn không cần quay lại bản Windows cũ, hãy dùng Storage Sense (Cài đặt → Bộ nhớ) hoặc cleanmgr. Lưu ý: xóa Windows.old là không quay về bản Windows cũ được.'
    'm2.cat.windowsold.skip' = 'Windows.old: chỉ liệt kê, chưa hỗ trợ xóa tự động (dùng Storage Sense hoặc cleanmgr).'
    'm2.analyze.title' = 'Phân tích dung lượng'
    'm2.analyze.subtitle' = 'Liệt kê 100 tệp lớn nhất trên ổ bạn chọn (chỉ đọc). Không xóa vĩnh viễn ở màn này — tệp chỉ được chuyển vào Thùng rác sau khi bạn xác nhận.'
    'm2.analyze.pick' = 'Ổ:'
    'm2.analyze.picknone' = 'Hãy chọn một ổ trước.'
    'm2.analyze.btn' = 'Phân tích'
    'm2.analyze.counting' = 'Đã quét {0} tệp…'
    'm2.analyze.done' = 'Top {0} tệp lớn nhất — tổng {1}.'
    'm2.analyze.empty' = 'Không đọc được tệp nào trên ổ này.'
    'm2.analyze.none' = 'Chưa chọn tệp nào trong bảng.'
    'm2.analyze.col.file' = 'Tệp'
    'm2.analyze.col.size' = 'Dung lượng'
    'm2.analyze.col.modified' = 'Ngày sửa'
    'm2.analyze.drivefmt' = '{0} — trống {1} / {2}'
    'm2.analyze.recycle' = 'Chuyển vào Thùng rác'
    'm2.analyze.recycle.title' = 'Chuyển tệp vào Thùng rác?'
    'm2.analyze.recycle.msg' = 'Tệp sẽ được CHUYỂN vào Thùng rác (không xóa vĩnh viễn):'
    'm2.analyze.recycle.undo' = 'Lấy lại được thủ công từ Thùng rác.'
    'm2.analyze.recycle.ok' = 'Đã chuyển vào Thùng rác.'
    'm2.analyze.recycle.fail' = 'Không chuyển được — tệp có thể đang bị khóa.'
    'm2.opt.title' = 'Tối ưu ổ'
    'm2.opt.subtitle' = 'SSD chạy TRIM; HDD phân tích rồi mới đề nghị defrag; KHÔNG bao giờ defrag SSD. Ổ không xác định loại sẽ bị bỏ qua (không đoán).'
    'm2.opt.loading' = 'Đang đọc danh sách ổ…'
    'm2.opt.none' = 'Không đọc được thông tin ổ vật lý (Get-PhysicalDisk).'
    'm2.opt.ssd' = 'SSD'
    'm2.opt.hdd' = 'HDD'
    'm2.opt.unknown' = 'Không xác định loại ổ — bỏ qua (không đoán)'
    'm2.opt.noletter' = 'Không có ký tự ổ — bỏ qua.'
    'm2.opt.trim' = 'Tối ưu (TRIM)'
    'm2.opt.analyze' = 'Phân tích'
    'm2.opt.defrag' = 'Chạy Defrag'
    'm2.opt.done' = 'Tối ưu xong: {0}'
    'm2.opt.analyze.done' = 'Đã phân tích xong {0}. Nếu phân mảnh cao, bấm "Chạy Defrag".'
    'm2.opt.fail' = 'Không tối ưu được {0} — xem chi tiết trong log.'
    'm2.expert.clean' = 'Remove-WCItem -Path <cache>  (qua Assert-SafePath + whitelist)'
    'm2.expert.recycle' = 'Send-WCFileToRecycleBin -Path <tệp> (sau xác nhận)'
}
Register-WCStrings 'en' @{
    'm2.title' = 'Disk cleaner'
    'm2.subtitle' = 'Only cleans what Windows can rebuild. Results are measured by real free space — honest, no hype.'
    'm2.lowspace' = 'System drive is nearly full: {0} free ({1}%)'
    'm2.clean.title' = 'Cleanup'
    'm2.clean.subtitle' = 'Scan (read-only) → review → confirm → run. Only RECOMMENDED items are pre-ticked; ADVANCED / RISKY are up to you.'
    'm2.scan' = 'Scan'
    'm2.scanning' = 'Scanning (read-only)'
    'm2.scan.item' = 'Scanning: {0}'
    'm2.scan.rb' = 'Counting Recycle Bin…'
    'm2.scan.done' = 'Scan finished: {0} categories, about {1} reclaimable. Hover an item to see what may be lost.'
    'm2.empty' = 'Nothing to clean — the PC is already tidy.'
    'm2.files' = '{0} files'
    'm2.items' = '{0} items'
    'm2.roots' = 'Location: {0}'
    'm2.run' = 'Clean selected items'
    'm2.select.none' = 'No item selected.'
    'm2.confirm.title' = 'Confirm disk cleanup'
    'm2.confirm.undo' = 'Hibernation can be re-enabled with powercfg /h on (see History & Undo).'
    'm2.confirm.noundo' = 'Cleaned files are deleted permanently (not moved to the Recycle Bin); caches rebuild themselves. Emptying the Recycle Bin cannot be undone.'
    'm2.running' = 'Cleaning disk'
    'm2.running.item' = 'Cleaning: {0}'
    'm2.result.title' = 'Result (measured by real free space)'
    'm2.result.freed' = 'Freed: {0}'
    'm2.result.free' = 'Free space on {0}'
    'm2.result.none' = 'Free space did not increase — files may be locked, or Windows already cleaned the caches.'
    'm2.result.skipped' = '{0} items skipped quietly (in use / locked) — no per-file error dialogs.'
    'm2.result.rescan' = 'Press "Scan" again to refresh the list.'
    'm2.viewlog' = 'View log'
    'm2.journal.clean' = 'Clean'
    'm2.journal.hibernate' = 'Disable hibernation'
    'm2.journal.bigfile' = 'Send file to Recycle Bin'
    'm2.journal.retrim' = 'Optimize drive (TRIM)'
    'm2.journal.defrag' = 'Run Defrag'
    'm2.skipped.cat' = 'Skipped: {0}'
    'm2.wu.skip' = 'Reboot pending after updates — Windows Update cache skipped.'
    'm2.cat.temp.user' = 'User temp files (older than 24h)'
    'm2.cat.temp.user.loss' = 'Only deletes files older than 24 hours; no personal data is touched. Running apps may recreate their temp files.'
    'm2.cat.temp.windows' = 'Windows temp files (older than 24h)'
    'm2.cat.temp.windows.loss' = 'Only deletes files older than 24 hours — Windows recreates them as needed.'
    'm2.cat.recycle' = 'Recycle Bin'
    'm2.cat.recycle.loss' = 'Everything in the Recycle Bin will be deleted permanently — it cannot be restored. Make sure you do not need anything from it.'
    'm2.cat.wer' = 'Windows error reports (WER)'
    'm2.cat.wer.loss' = 'Old error reports are removed — diagnostic data only, no impact on operation.'
    'm2.cat.crashdumps' = 'App crash dumps'
    'm2.cat.crashdumps.loss' = 'Crash dumps used for diagnostics are removed; apps keep running normally.'
    'm2.cat.minidump' = 'BSOD minidumps'
    'm2.cat.minidump.loss' = 'Recent BSOD records are removed — skip this item if you are still investigating a blue screen.'
    'm2.cat.lkr' = 'LiveKernelReports'
    'm2.cat.lkr.loss' = 'Kernel diagnostic reports are removed — no impact on operation.'
    'm2.cat.do' = 'Delivery Optimization cache'
    'm2.cat.do.loss' = 'Already-downloaded update parts will be re-downloaded when needed — no data loss.'
    'm2.cat.browser' = 'Browser cache (Chrome / Edge / Brave / Firefox)'
    'm2.cat.browser.loss' = 'Only cache (images, downloaded code) is deleted. Cookies, passwords, history and Local Storage are NEVER touched. First page loads may be a bit slower.'
    'm2.cat.browser.open' = 'A browser is running — some files will be skipped (no need to close it).'
    'm2.cat.wu' = 'Windows Update download cache'
    'm2.cat.wu.loss' = 'Downloaded updates will be re-downloaded when installed (uses bandwidth). Update history (DataStore) is never touched. The wuauserv / bits services are paused and restored to their previous state.'
    'm2.cat.wu.pending' = 'Reboot pending — this item will be skipped.'
    'm2.cat.shader' = 'Shader caches (DirectX / NVIDIA OpenGL)'
    'm2.cat.shader.loss' = 'The first game launch after cleaning may stutter or load slower while shaders are rebuilt.'
    'm2.cat.appcache' = 'App caches (Discord, Teams, Spotify)'
    'm2.cat.appcache.loss' = 'Apps rebuild their caches (first launch slightly slower); Spotify may re-download cached music. No messages or settings are lost.'
    'm2.cat.hibernate' = 'Disable hibernation (deletes hiberfil.sys)'
    'm2.cat.hibernate.loss' = 'Hibernation and Fast Startup are disabled until re-enabled with powercfg /h on.'
    'm2.cat.windowsold' = 'Windows.old (previous Windows)'
    'm2.cat.windowsold.loss' = 'Automatic deletion is NOT supported in this version. If you are sure you will not roll back, use Storage Sense (Settings → Storage) or cleanmgr. Note: deleting Windows.old means you cannot return to the previous Windows.'
    'm2.cat.windowsold.skip' = 'Windows.old: listed only, automatic deletion not supported (use Storage Sense or cleanmgr).'
    'm2.analyze.title' = 'Disk space analysis'
    'm2.analyze.subtitle' = 'Lists the 100 largest files on the selected drive (read-only). No permanent deletion here — files are only moved to the Recycle Bin after you confirm.'
    'm2.analyze.pick' = 'Drive:'
    'm2.analyze.picknone' = 'Please pick a drive first.'
    'm2.analyze.btn' = 'Analyze'
    'm2.analyze.counting' = 'Scanned {0} files…'
    'm2.analyze.done' = 'Top {0} largest files — total {1}.'
    'm2.analyze.empty' = 'Could not read any file on this drive.'
    'm2.analyze.none' = 'No file selected in the table.'
    'm2.analyze.col.file' = 'File'
    'm2.analyze.col.size' = 'Size'
    'm2.analyze.col.modified' = 'Modified'
    'm2.analyze.drivefmt' = '{0} — free {1} / {2}'
    'm2.analyze.recycle' = 'Send to Recycle Bin'
    'm2.analyze.recycle.title' = 'Send file to Recycle Bin?'
    'm2.analyze.recycle.msg' = 'The file will be MOVED to the Recycle Bin (not permanently deleted):'
    'm2.analyze.recycle.undo' = 'Recoverable manually from the Recycle Bin.'
    'm2.analyze.recycle.ok' = 'Moved to Recycle Bin.'
    'm2.analyze.recycle.fail' = 'Could not move it — the file may be locked.'
    'm2.opt.title' = 'Optimize drives'
    'm2.opt.subtitle' = 'SSD gets TRIM; HDD is analyzed first, then defrag is suggested; SSDs are NEVER defragmented. Unknown media type is skipped (no guessing).'
    'm2.opt.loading' = 'Reading drive list…'
    'm2.opt.none' = 'Could not read physical disk info (Get-PhysicalDisk).'
    'm2.opt.ssd' = 'SSD'
    'm2.opt.hdd' = 'HDD'
    'm2.opt.unknown' = 'Unknown media type — skipped (no guessing)'
    'm2.opt.noletter' = 'No drive letter — skipped.'
    'm2.opt.trim' = 'Optimize (TRIM)'
    'm2.opt.analyze' = 'Analyze'
    'm2.opt.defrag' = 'Run Defrag'
    'm2.opt.done' = 'Optimized: {0}'
    'm2.opt.analyze.done' = 'Analysis done for {0}. If fragmentation is high, press "Run Defrag".'
    'm2.opt.fail' = 'Could not optimize {0} — see log for details.'
    'm2.expert.clean' = 'Remove-WCItem -Path <cache>  (via Assert-SafePath + whitelist)'
    'm2.expert.recycle' = 'Send-WCFileToRecycleBin -Path <file> (after confirmation)'
}

# ---------------------------------------------------------------------------
# LOP DU LIEU (Get-* thuan - spec 2.3). Tat ca deu goi duoc tu worker runspace.
# ---------------------------------------------------------------------------

function Get-WCM2SystemDisk {
    # Thong tin o he thong (free/total bytes). -Fresh: bo cache de do chinh xac.
    param([switch]$Fresh)
    $sb = {
        $root = [IO.Path]::GetPathRoot($env:SystemRoot)
        $letter = $root.TrimEnd('\')
        Get-CimInstance -ClassName Win32_LogicalDisk -Filter ("DeviceID = '" + $letter + "'") -Property DeviceID,FreeSpace,Size -OperationTimeoutSec 8
    }
    if ($Fresh) {
        $r = Invoke-WCQuery -Key 'm2.sysdisk' -NoCache -Script $sb
    } else {
        $r = Invoke-WCQuery -Key 'm2.sysdisk' -CacheTtlSec 20 -Script $sb
    }
    if ($r.Status -ne 'Ok') { return $null }
    if (-not $r.Data) { return $null }
    $free = Get-WCProp $r.Data 'FreeSpace'
    $size = Get-WCProp $r.Data 'Size'
    $out = @{ Free = $null; Total = $null }
    if ($null -ne $free) { $out.Free = [long]$free }
    if ($null -ne $size) { $out.Total = [long]$size }
    return $out
}

function Get-WCM2LogicalDisks {
    # Cac o dia cuc bo (DriveType = 3) cho combobox "Phan tich dung luong"
    $r = Invoke-WCQuery -Key 'm2.disks' -CacheTtlSec 60 -Script {
        Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType = 3' -Property DeviceID,VolumeName,Size,FreeSpace -OperationTimeoutSec 8
    }
    if ($r.Status -ne 'Ok') { return @() }
    $list = @()
    foreach ($d in @($r.Data)) {
        $dev = Get-WCProp $d 'DeviceID'
        if (-not $dev) { continue }
        $szL = [long]0; $frL = [long]0
        $sz = Get-WCProp $d 'Size'
        $fr = Get-WCProp $d 'FreeSpace'
        if ($null -ne $sz) { $szL = [long]$sz }
        if ($null -ne $fr) { $frL = [long]$fr }
        $list += @{
            DeviceId = [string]$dev; VolumeName = [string](Get-WCProp $d 'VolumeName')
            Size = $szL; Free = $frL
        }
    }
    return $list
}

function Get-WCM2TreeSize {
    # Tong dung luong + so tep cua 1 thu muc (bo reparse point, khong throw)
    param([string]$Path, $Ctx)
    $bytes = [long]0
    $files = 0
    try {
        $stack = New-Object System.Collections.Stack
        $stack.Push($Path)
        while ($stack.Count -gt 0) {
            if ($Ctx -and $Ctx.Cancelled()) { break }
            $dir = [string]$stack.Pop()
            try {
                foreach ($f in [IO.Directory]::EnumerateFiles($dir)) {
                    try {
                        $fi = New-Object IO.FileInfo($f)
                        $bytes += [long]$fi.Length
                        $files++
                    } catch { }
                }
                foreach ($d in [IO.Directory]::EnumerateDirectories($dir)) {
                    if (-not (Test-WCPathIsReparsePoint $d)) { $stack.Push($d) }
                }
            } catch { }
        }
    } catch { }
    return @{ Bytes = $bytes; Files = $files }
}

function Get-WCM2RootsDisplay {
    # Chuoi hien thi cac thu muc goc (toi da 2 + dau ba cham)
    param([string[]]$Roots)
    $list = @()
    foreach ($r in $Roots) { if ($r) { $list += [string]$r } }
    if ($list.Count -le 2) { return ([string]::Join('; ', $list)) }
    return ($list[0] + '; ' + $list[1] + ' …')
}

function Get-WCM2AgeTargets {
    # Muc tieu xoa cho danh muc co loc tuoi (>24h):
    # - tep cu cap truc tiep cua moi thu muc
    # - thu muc ma TOAN BO noi dung (va chinh no) deu cu -> xoa ca thu muc
    # Duyet iterative (Stack) + tong hop post-order; bo reparse point.
    param([string]$Root, [DateTime]$Cutoff, $Ctx)
    $rootRec = @{
        Path = $Root; OldBytes = [long]0; OldFiles = 0; AllOld = $true
        OldFilesList = ([System.Collections.Generic.List[string]]::new())
        Dirs = ([System.Collections.Generic.List[hashtable]]::new())
        Parent = $null; Done = $false
    }
    $stack = New-Object System.Collections.Stack
    $stack.Push($rootRec)
    while ($stack.Count -gt 0) {
        if ($Ctx -and $Ctx.Cancelled()) { break }
        $rec = $stack.Pop()
        if ($rec.Done) {
            if ($rec.Parent) {
                $rec.Parent.OldBytes += [long]$rec.OldBytes
                $rec.Parent.OldFiles += [int]$rec.OldFiles
                if (-not $rec.AllOld) { $rec.Parent.AllOld = $false }
            }
            continue
        }
        $rec.Done = $true
        $stack.Push($rec)
        try {
            foreach ($f in [IO.Directory]::EnumerateFiles($rec.Path)) {
                try {
                    $fi = New-Object IO.FileInfo($f)
                    if ($fi.LastWriteTime -lt $Cutoff) {
                        $rec.OldBytes += [long]$fi.Length
                        $rec.OldFiles++
                        $rec.OldFilesList.Add($f)
                    } else {
                        $rec.AllOld = $false
                    }
                } catch { $rec.AllOld = $false }
            }
            foreach ($d in [IO.Directory]::EnumerateDirectories($rec.Path)) {
                if (Test-WCPathIsReparsePoint $d) { continue }
                $childAllOld = $false
                try {
                    $di = New-Object IO.DirectoryInfo($d)
                    $childAllOld = ($di.LastWriteTime -lt $Cutoff)
                } catch { }
                $child = @{
                    Path = $d; OldBytes = [long]0; OldFiles = 0; AllOld = $childAllOld
                    OldFilesList = ([System.Collections.Generic.List[string]]::new())
                    Dirs = ([System.Collections.Generic.List[hashtable]]::new())
                    Parent = $rec; Done = $false
                }
                $rec.Dirs.Add($child)
                $stack.Push($child)
            }
        } catch { }
    }
    $targets = Get-WCM2OldTargetsFromTree -Rec $rootRec
    return @{ Targets = @($targets); Bytes = [long]$rootRec.OldBytes; Files = [int]$rootRec.OldFiles }
}

function Get-WCM2OldTargetsFromTree {
    # De quy gom muc tieu tu cay ban ghi cua Get-WCM2AgeTargets
    param($Rec)
    $list = [System.Collections.Generic.List[string]]::new()
    foreach ($f in $Rec.OldFilesList) { $list.Add([string]$f) }
    foreach ($d in $Rec.Dirs) {
        if ($d.AllOld) {
            $list.Add([string]$d.Path)
        } else {
            $inner = Get-WCM2OldTargetsFromTree -Rec $d
            foreach ($x in $inner) { $list.Add([string]$x) }
        }
    }
    return $list
}

function Get-WCM2AgeCategory {
    # Danh muc co loc tuoi (Temp nguoi dung / Temp Windows)
    param([string]$Key, [string]$Risk, [string[]]$Roots, [DateTime]$Cutoff, $Ctx)
    $targets = @()
    $bytes = [long]0
    $files = 0
    $existing = @()
    foreach ($root in $Roots) {
        if (-not $root) { continue }
        if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }
        $existing += [string]$root
        $r = Get-WCM2AgeTargets -Root $root -Cutoff $Cutoff -Ctx $Ctx
        $targets += @($r.Targets)
        $bytes += [long]$r.Bytes
        $files += [int]$r.Files
    }
    if ($targets.Count -eq 0) { return $null }
    return @{
        Key = $Key; Name = (T ('m2.cat.' + $Key)); Risk = $Risk; Kind = 'Files'
        Size = $bytes; Files = $files; Targets = $targets
        Loss = (T ('m2.cat.' + $Key + '.loss')); Note = ''
        Roots = (Get-WCM2RootsDisplay -Roots $existing); SkipAtRun = $false
    }
}

function Get-WCM2PathsCategory {
    # Danh muc don con cap 1 cua cac thu muc goc (khong loc tuoi)
    param([string]$Key, [string]$Risk, [string[]]$Roots, [string]$Kind = 'Files', $Ctx)
    $targets = @()
    $bytes = [long]0
    $files = 0
    $existing = @()
    foreach ($root in $Roots) {
        if (-not $root) { continue }
        if (-not (Test-Path -LiteralPath $root -PathType Container)) { continue }
        $existing += [string]$root
        try {
            foreach ($e in [IO.Directory]::EnumerateFileSystemEntries($root)) {
                if (Test-WCPathIsReparsePoint $e) { continue }
                $targets += $e
            }
        } catch { }
        $st = Get-WCM2TreeSize -Path $root -Ctx $Ctx
        $bytes += [long]$st.Bytes
        $files += [int]$st.Files
    }
    if ($targets.Count -eq 0) { return $null }
    return @{
        Key = $Key; Name = (T ('m2.cat.' + $Key)); Risk = $Risk; Kind = $Kind
        Size = $bytes; Files = $files; Targets = $targets
        Loss = (T ('m2.cat.' + $Key + '.loss')); Note = ''
        Roots = (Get-WCM2RootsDisplay -Roots $existing); SkipAtRun = $false
    }
}

function Get-WCM2BrowserCacheRoots {
    # Chi cac thu muc CACHE cua trinh duyet (moi profile): Cache / Code Cache /
    # GPUCache (Chromium) va cache2 (Firefox). Tuyet doi khong cookie/mat khau/
    # lich su / Local Storage (spec M2).
    $roots = @()
    $userDataRoots = @(
        (Join-Path $env:LOCALAPPDATA 'Google\Chrome\User Data'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Edge\User Data'),
        (Join-Path $env:LOCALAPPDATA 'BraveSoftware\Brave-Browser\User Data')
    )
    foreach ($ud in $userDataRoots) {
        if (-not (Test-Path -LiteralPath $ud -PathType Container)) { continue }
        try {
            foreach ($profile in [IO.Directory]::EnumerateDirectories($ud)) {
                $name = [IO.Path]::GetFileName($profile)
                if ($name -eq 'System Profile') { continue }
                if ($name -eq 'Guest Profile') { continue }
                # Chi tinh la profile neu co thu muc Cache (loai ShaderCache, Crashpad...)
                if (-not (Test-Path -LiteralPath (Join-Path $profile 'Cache') -PathType Container)) { continue }
                foreach ($c in @('Cache', 'Code Cache', 'GPUCache')) {
                    $p = Join-Path $profile $c
                    if (Test-Path -LiteralPath $p -PathType Container) { $roots += $p }
                }
            }
        } catch { }
    }
    $ffProfiles = Join-Path $env:LOCALAPPDATA 'Mozilla\Firefox\Profiles'
    if (Test-Path -LiteralPath $ffProfiles -PathType Container) {
        try {
            foreach ($pf in [IO.Directory]::EnumerateDirectories($ffProfiles)) {
                $c2 = Join-Path $pf 'cache2'
                if (Test-Path -LiteralPath $c2 -PathType Container) { $roots += $c2 }
            }
        } catch { }
    }
    return $roots
}

function Get-WCM2RunningBrowsers {
    # Kiem tra trinh duyet dang mo (de gan canh bao "se bo qua tep khoa")
    $names = @()
    foreach ($p in @('chrome', 'msedge', 'brave', 'firefox')) {
        try {
            $procs = @(Get-Process -Name $p -ErrorAction Stop)
            if ($procs.Count -gt 0) { $names += $p }
        } catch { }
    }
    return $names
}

function Get-WCM2BrowserCategory {
    param($Ctx)
    $roots = @(Get-WCM2BrowserCacheRoots)
    if ($roots.Count -eq 0) { return $null }
    $targets = @()
    $bytes = [long]0
    $files = 0
    foreach ($root in $roots) {
        try {
            foreach ($e in [IO.Directory]::EnumerateFileSystemEntries($root)) {
                if (Test-WCPathIsReparsePoint $e) { continue }
                $targets += $e
            }
        } catch { }
        $st = Get-WCM2TreeSize -Path $root -Ctx $Ctx
        $bytes += [long]$st.Bytes
        $files += [int]$st.Files
    }
    if ($targets.Count -eq 0) { return $null }
    $note = ''
    $running = @(Get-WCM2RunningBrowsers)
    if ($running.Count -gt 0) { $note = (T 'm2.cat.browser.open') }
    return @{
        Key = 'browser'; Name = (T 'm2.cat.browser'); Risk = 'Recommended'; Kind = 'Files'
        Size = $bytes; Files = $files; Targets = $targets
        Loss = (T 'm2.cat.browser.loss'); Note = $note
        Roots = (Get-WCM2RootsDisplay -Roots $roots); SkipAtRun = $false
    }
}

function Get-WCM2HibernateCategory {
    # Chi liet ke khi hiberfil.sys ton tai (= ngu dong dang BAT). Kich thuoc that.
    $hib = Join-Path $env:SystemRoot 'hiberfil.sys'
    try {
        if (Test-Path -LiteralPath $hib -PathType Leaf) {
            $fi = Get-Item -LiteralPath $hib -Force -ErrorAction Stop
            $len = [long]$fi.Length
            return @{
                Key = 'hibernate'; Name = (T 'm2.cat.hibernate'); Risk = 'Risky'; Kind = 'Hibernate'
                Size = $len; Files = 1; Targets = @()
                Loss = (T 'm2.cat.hibernate.loss'); Note = ''
                Roots = $hib; SkipAtRun = $false
            }
        }
    } catch { }
    return $null
}

function Get-WCM2WindowsOldCategory {
    # CHI LIET KE + huong dan; khong tu xoa trong ban nay (spec M2)
    param($Ctx)
    try {
        $root = [IO.Path]::GetPathRoot($env:SystemRoot)
        $p = Join-Path $root 'Windows.old'
        if (Test-Path -LiteralPath $p -PathType Container) {
            $st = Get-WCM2TreeSize -Path $p -Ctx $Ctx
            return @{
                Key = 'windowsold'; Name = (T 'm2.cat.windowsold'); Risk = 'Risky'; Kind = 'InfoOnly'
                Size = [long]$st.Bytes; Files = [int]$st.Files; Targets = @()
                Loss = (T 'm2.cat.windowsold.loss'); Note = ''
                Roots = $p; SkipAtRun = $true
            }
        }
    } catch { }
    return $null
}

function Get-WCM2IsRebootPending {
    # Kiem tra cho khoi dong lai (dung khoa ton tai, khong parse output CLI)
    try {
        if (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') { return $true }
    } catch { }
    try {
        if (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') { return $true }
    } catch { }
    return $false
}

function Get-WCM2RecycleBinStats {
    # Dem so item + dung luong Thuong rac qua Shell.Application NameSpace(0xA).
    # COM co the cham/loi -> task rieng co spinner rieng, try/catch tra $null.
    try {
        if (-not (Get-Command -Name Clear-RecycleBin -ErrorAction SilentlyContinue)) { return $null }
        $shell = New-Object -ComObject Shell.Application
        $rb = $shell.NameSpace(0xA)
        if (-not $rb) { return $null }
        $count = 0
        $bytes = [long]0
        foreach ($item in @($rb.Items())) {
            $count++
            try {
                $sz = Get-WCProp $item 'Size'
                if ($null -ne $sz) { $bytes += [long]$sz }
            } catch { }
        }
        return @{ Items = $count; Bytes = $bytes }
    } catch {
        Write-WCLog 'WARN' ('Quet Thuong rac that bai: ' + $_.Exception.Message)
        return $null
    }
}

function Get-WCM2ScanCategories {
    # Quet chi-doc tat ca danh muc (rieng Thuong rac co task rieng). Chay trong worker.
    param($Ctx)
    $cats = @()
    $cutoff = [DateTime]::Now.AddHours(-24)
    $pct = 4

    if ($Ctx) { $Ctx.Progress($pct, (T 'm2.scan.item' @((T 'm2.cat.temp.user')))) }
    $c = Get-WCM2AgeCategory -Key 'temp.user' -Risk 'Recommended' -Roots @(([IO.Path]::GetTempPath()).TrimEnd('\')) -Cutoff $cutoff -Ctx $Ctx
    if ($c) { $cats += $c }

    $pct += 7
    if ($Ctx) { $Ctx.Progress($pct, (T 'm2.scan.item' @((T 'm2.cat.temp.windows')))) }
    $c = Get-WCM2AgeCategory -Key 'temp.windows' -Risk 'Recommended' -Roots @((Join-Path $env:SystemRoot 'Temp')) -Cutoff $cutoff -Ctx $Ctx
    if ($c) { $cats += $c }

    $pct += 7
    if ($Ctx) { $Ctx.Progress($pct, (T 'm2.scan.item' @((T 'm2.cat.wer')))) }
    $c = Get-WCM2PathsCategory -Key 'wer' -Risk 'Recommended' -Roots @(
        (Join-Path $env:ProgramData 'Microsoft\Windows\WER\ReportQueue'),
        (Join-Path $env:ProgramData 'Microsoft\Windows\WER\ReportArchive')
    ) -Ctx $Ctx
    if ($c) { $cats += $c }

    $pct += 7
    if ($Ctx) { $Ctx.Progress($pct, (T 'm2.scan.item' @((T 'm2.cat.crashdumps')))) }
    $c = Get-WCM2PathsCategory -Key 'crashdumps' -Risk 'Recommended' -Roots @(
        (Join-Path $env:LOCALAPPDATA 'CrashDumps')
    ) -Ctx $Ctx
    if ($c) { $cats += $c }

    $pct += 7
    if ($Ctx) { $Ctx.Progress($pct, (T 'm2.scan.item' @((T 'm2.cat.minidump')))) }
    $c = Get-WCM2PathsCategory -Key 'minidump' -Risk 'Recommended' -Roots @(
        (Join-Path $env:SystemRoot 'Minidump')
    ) -Ctx $Ctx
    if ($c) { $cats += $c }

    $pct += 7
    if ($Ctx) { $Ctx.Progress($pct, (T 'm2.scan.item' @((T 'm2.cat.lkr')))) }
    $c = Get-WCM2PathsCategory -Key 'lkr' -Risk 'Recommended' -Roots @(
        (Join-Path $env:SystemRoot 'LiveKernelReports')
    ) -Ctx $Ctx
    if ($c) { $cats += $c }

    $pct += 7
    if ($Ctx) { $Ctx.Progress($pct, (T 'm2.scan.item' @((T 'm2.cat.do')))) }
    $c = Get-WCM2PathsCategory -Key 'do' -Risk 'Recommended' -Roots @(
        (Join-Path $env:SystemRoot 'SoftwareDistribution\DeliveryOptimization')
    ) -Ctx $Ctx
    if ($c) { $cats += $c }

    $pct += 7
    if ($Ctx) { $Ctx.Progress($pct, (T 'm2.scan.item' @((T 'm2.cat.browser')))) }
    $c = Get-WCM2BrowserCategory -Ctx $Ctx
    if ($c) { $cats += $c }

    # ---- NANG CAO ----
    $pct += 7
    if ($Ctx) { $Ctx.Progress($pct, (T 'm2.scan.item' @((T 'm2.cat.wu')))) }
    $c = Get-WCM2PathsCategory -Key 'wu' -Risk 'Advanced' -Kind 'WuDownload' -Roots @(
        (Join-Path $env:SystemRoot 'SoftwareDistribution\Download')
    ) -Ctx $Ctx
    if ($c) {
        if (Get-WCM2IsRebootPending) {
            $c.SkipAtRun = $true
            $c.Note = (T 'm2.cat.wu.pending')
        }
        $cats += $c
    }

    $pct += 7
    if ($Ctx) { $Ctx.Progress($pct, (T 'm2.scan.item' @((T 'm2.cat.shader')))) }
    $c = Get-WCM2PathsCategory -Key 'shader' -Risk 'Advanced' -Roots @(
        (Join-Path $env:LOCALAPPDATA 'D3DSCache'),
        (Join-Path $env:LOCALAPPDATA 'NVIDIA\GLCache')
    ) -Ctx $Ctx
    if ($c) { $cats += $c }

    $pct += 7
    if ($Ctx) { $Ctx.Progress($pct, (T 'm2.scan.item' @((T 'm2.cat.appcache')))) }
    $c = Get-WCM2PathsCategory -Key 'appcache' -Risk 'Advanced' -Roots @(
        (Join-Path $env:APPDATA 'discord\Cache'),
        (Join-Path $env:APPDATA 'discord\Code Cache'),
        (Join-Path $env:APPDATA 'discord\GPUCache'),
        (Join-Path $env:APPDATA 'Microsoft\Teams\Cache'),
        (Join-Path $env:LOCALAPPDATA 'Spotify\Storage')
    ) -Ctx $Ctx
    if ($c) { $cats += $c }

    # ---- RUI RO ----
    $pct += 7
    if ($Ctx) { $Ctx.Progress($pct, (T 'm2.scan.item' @((T 'm2.cat.hibernate')))) }
    $c = Get-WCM2HibernateCategory
    if ($c) { $cats += $c }

    $pct += 7
    if ($Ctx) { $Ctx.Progress($pct, (T 'm2.scan.item' @((T 'm2.cat.windowsold')))) }
    $c = Get-WCM2WindowsOldCategory -Ctx $Ctx
    if ($c) { $cats += $c }

    if ($Ctx) { $Ctx.Progress(99, (T 'common.loading')) }
    return $cats
}

function Get-WCM2TopFiles {
    # Top N tep lon nhat tren 1 o (EnumerateFiles de quy bang Stack, bo reparse).
    # Giu nho co gioi han: cat ve Top moi khi vuot 5000 phan tu.
    param([string]$Root, [int]$Top = 100, $Ctx)
    $list = [System.Collections.Generic.List[object]]::new()
    $stack = New-Object System.Collections.Stack
    $stack.Push($Root)
    $scanned = 0
    while ($stack.Count -gt 0) {
        if ($Ctx -and $Ctx.Cancelled()) { break }
        $dir = [string]$stack.Pop()
        try {
            foreach ($f in [IO.Directory]::EnumerateFiles($dir)) {
                $scanned++
                try {
                    $fi = New-Object IO.FileInfo($f)
                    if ($fi.Length -gt 0) {
                        $list.Add([PSCustomObject]@{
                            Path = $f; Size = [long]$fi.Length; Modified = $fi.LastWriteTime
                        })
                    }
                } catch { }
                if (($scanned % 4096) -eq 0) {
                    if ($Ctx) {
                        $Ctx.Progress(50, (T 'm2.analyze.counting' @([string]$scanned)))
                        if ($Ctx.Cancelled()) { break }
                    }
                }
            }
        } catch { }
        if ($Ctx -and $Ctx.Cancelled()) { break }
        try {
            foreach ($d in [IO.Directory]::EnumerateDirectories($dir)) {
                if (-not (Test-WCPathIsReparsePoint $d)) { $stack.Push($d) }
            }
        } catch { }
        if ($list.Count -gt 5000) {
            $sorted = @($list | Sort-Object -Property Size -Descending | Select-Object -First $Top)
            $list = [System.Collections.Generic.List[object]]::new()
            foreach ($x in $sorted) { $list.Add($x) }
        }
    }
    $top = @($list | Sort-Object -Property Size -Descending | Select-Object -First $Top)
    return $top
}

function Get-WCM2PhysicalDiskRows {
    # Danh sach o vat ly + ky tu o tuong ung (Get-PhysicalDisk + Get-Partition)
    $rows = @()
    try {
        $disks = @(Get-PhysicalDisk -ErrorAction Stop)
        foreach ($d in $disks) {
            $num = Get-WCProp $d 'DeviceId'
            $letters = @()
            if ($num) {
                try {
                    $parts = @(Get-Partition -DiskNumber ([int]$num) -ErrorAction Stop)
                    foreach ($p in $parts) {
                        $dl = Get-WCProp $p 'DriveLetter'
                        if ($dl -and ([string]$dl).Trim() -ne '') { $letters += [string]$dl }
                    }
                } catch { }
            }
            $rows += @{
                Number = [string]$num
                FriendlyName = [string](Get-WCProp $d 'FriendlyName')
                MediaType = [string](Get-WCProp $d 'MediaType')
                BusType = [string](Get-WCProp $d 'BusType')
                Letters = @($letters)
            }
        }
    } catch {
        Write-WCLog 'WARN' ('Get-PhysicalDisk that bai: ' + $_.Exception.Message)
        return $null
    }
    return $rows
}

function Get-WCM2ServiceRunning {
    param([Parameter(Mandatory)][string]$Name)
    try {
        $svc = Get-Service -Name $Name -ErrorAction Stop
        return ($svc.Status -eq 'Running')
    } catch { return $false }
}

function Invoke-WCM2StopService {
    # Dung dich vu (dung cho cache Windows Update); loi chi ghi log
    param([Parameter(Mandatory)][string]$Name)
    try {
        $svc = Get-Service -Name $Name -ErrorAction Stop
        if ($svc.Status -eq 'Running') {
            Stop-Service -Name $Name -Force -ErrorAction Stop
        }
    } catch {
        Write-WCLog 'WARN' ('Khong dung duoc dich vu ' + $Name + ': ' + $_.Exception.Message)
    }
}

function Invoke-WCM2StartService {
    param([Parameter(Mandatory)][string]$Name)
    try {
        Start-Service -Name $Name -ErrorAction Stop
    } catch {
        Write-WCLog 'WARN' ('Khong khoi phuc duoc dich vu ' + $Name + ': ' + $_.Exception.Message)
    }
}

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------

function Initialize-WCModuleM2 {
    # Phong thu: chac chan whitelist xoa da duoc nap (ham idempotent, goi 2 lan an toan)
    try { Initialize-WCDefaultDeleteRoots } catch { }

    $state = @{
        Scanned = $false; DrivesLoaded = $false
        CatList = $null; ScanBtn = $null; RunBtn = $null
        ScanSpinner = $null; RbSpinner = $null; SummaryText = $null; EmptyText = $null
        ResultHost = $null; ResultSection = $null
        DriveCombo = $null; TopTable = $null; AnalyzeBtn = $null; AnalyzeSpinner = $null
        AnaSummary = $null
        OptSpinner = $null; OptHost = $null; DefragBtns = @{}
        LowChip = $null
    }

    Register-WCNavItem -Key 'm2' -Badge 'M2' -Title (T 'm2.title') -Order 30 -Builder {
        New-WCM2Panel $state
    }.GetNewClosure() -OnShow {
        Update-WCM2LowSpaceChip $state
        if (-not $state.Scanned) {
            $state.Scanned = $true
            Invoke-WCM2Scan $state
        }
        if (-not $state.DrivesLoaded) {
            $state.DrivesLoaded = $true
            Invoke-WCM2PopulateDrives $state
            Invoke-WCM2LoadDisks $state
        }
    }.GetNewClosure() -OnHide { }.GetNewClosure()
}

function New-WCM2Panel {
    param($State)
    $root = New-Object Windows.Controls.ScrollViewer
    $root.VerticalScrollBarVisibility = [Windows.Controls.ScrollBarVisibility]::Auto
    $hostPanel = New-WCVStack -Spacing 14
    $hostPanel.Margin = (New-Object Windows.Thickness(20))
    $root.Content = $hostPanel

    # Tieu de + chip canh bao o he thong sap day
    $titleRow = New-WCHStack -Spacing 10
    $titleRow.Children.Add((New-WCHeading (T 'm2.title'))) | Out-Null
    $lowChip = New-WCChip -Text '' -Kind 'Bad'
    $lowChip.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $lowChip.Visibility = [Windows.Visibility]::Collapsed
    $State.LowChip = $lowChip
    $titleRow.Children.Add($lowChip) | Out-Null
    Add-WCChild $hostPanel $titleRow
    Add-WCChild $hostPanel (New-WCSubtitle (T 'm2.subtitle'))

    # =========== MUC 1: DON DEP (QUET -> XEM LAI -> XAC NHAN -> CHAY) ===========
    $cleanSec = New-WCSection -Title (T 'm2.clean.title') -Subtitle (T 'm2.clean.subtitle')
    $btnRow = New-WCHStack -Spacing 8
    $State.ScanBtn = New-WCButton -Text (T 'm2.scan') -Kind Primary -OnClick { param($b) Invoke-WCM2Scan $State }.GetNewClosure()
    $State.RunBtn = New-WCButton -Text (T 'm2.run') -Disabled -OnClick { param($b) Invoke-WCM2RunSelected $State }.GetNewClosure()
    $btnRow.Children.Add($State.ScanBtn) | Out-Null
    $btnRow.Children.Add($State.RunBtn) | Out-Null
    Add-WCChild $cleanSec.Body $btnRow

    $State.ScanSpinner = New-WCSpinner -Text (T 'm2.scanning')
    $State.ScanSpinner.Visibility = [Windows.Visibility]::Collapsed
    Add-WCChild $cleanSec.Body $State.ScanSpinner
    $State.RbSpinner = New-WCSpinner -Text (T 'm2.scan.rb')
    $State.RbSpinner.Visibility = [Windows.Visibility]::Collapsed
    Add-WCChild $cleanSec.Body $State.RbSpinner

    $State.SummaryText = New-WCTextBlock -Text '' -Size 12.5 -ColorKey 'WcSubtle' -Wrap
    Add-WCChild $cleanSec.Body $State.SummaryText

    $State.CatList = New-WCCheckList
    Add-WCChild $cleanSec.Body $State.CatList

    Add-WCChild $cleanSec.Body (New-WCExpertLine -Command (T 'm2.expert.clean'))
    Add-WCChild $hostPanel $cleanSec.Root

    # =========== MUC 2: KET QUA ===========
    $resSec = New-WCSection -Title (T 'm2.result.title')
    $State.ResultHost = $resSec.Body
    $State.ResultSection = $resSec
    $resSec.Root.Visibility = [Windows.Visibility]::Collapsed
    Add-WCChild $hostPanel $resSec.Root

    # =========== MUC 3: PHAN TICH DUNG LUONG ===========
    $anaSec = New-WCSection -Title (T 'm2.analyze.title') -Subtitle (T 'm2.analyze.subtitle')
    $anaRow = New-WCHStack -Spacing 8
    $lbl = New-WCTextBlock -Text (T 'm2.analyze.pick') -Size 13
    $lbl.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $anaRow.Children.Add($lbl) | Out-Null
    $combo = New-Object Windows.Controls.ComboBox
    $combo.Width = 320
    $combo.DisplayMemberPath = 'Label'
    $State.DriveCombo = $combo
    $anaRow.Children.Add($combo) | Out-Null
    $State.AnalyzeBtn = New-WCButton -Text (T 'm2.analyze.btn') -Kind Primary -OnClick { param($b) Invoke-WCM2Analyze $State }.GetNewClosure()
    $anaRow.Children.Add($State.AnalyzeBtn) | Out-Null
    $State.AnalyzeSpinner = New-WCSpinner
    $State.AnalyzeSpinner.Visibility = [Windows.Visibility]::Collapsed
    $anaRow.Children.Add($State.AnalyzeSpinner) | Out-Null
    Add-WCChild $anaSec.Body $anaRow

    $State.AnaSummary = New-WCTextBlock -Text '' -Size 12.5 -ColorKey 'WcSubtle' -Wrap
    Add-WCChild $anaSec.Body $State.AnaSummary

    $State.TopTable = New-WCTable -Columns @(
        @{ Header = (T 'm2.analyze.col.file'); Prop = 'File'; Width = 620 }
        @{ Header = (T 'm2.analyze.col.size'); Prop = 'Size'; Width = 110 }
        @{ Header = (T 'm2.analyze.col.modified'); Prop = 'Modified'; Width = 150 }
    )
    $State.TopTable.MaxHeight = 320
    Add-WCChild $anaSec.Body $State.TopTable

    $anaBtnRow = New-WCHStack -Spacing 8
    $openBtn = New-WCButton -Text (T 'common.openlocation') -OnClick { param($b) Invoke-WCM2OpenLocation $State }.GetNewClosure()
    $recBtn = New-WCButton -Text (T 'm2.analyze.recycle') -OnClick { param($b) Invoke-WCM2RecycleSelected $State }.GetNewClosure()
    $anaBtnRow.Children.Add($openBtn) | Out-Null
    $anaBtnRow.Children.Add($recBtn) | Out-Null
    Add-WCChild $anaSec.Body $anaBtnRow
    Add-WCChild $anaSec.Body (New-WCExpertLine -Command (T 'm2.expert.recycle'))
    Add-WCChild $hostPanel $anaSec.Root

    # =========== MUC 4: TOI UU O ===========
    $optSec = New-WCSection -Title (T 'm2.opt.title') -Subtitle (T 'm2.opt.subtitle')
    $State.OptSpinner = New-WCSpinner -Text (T 'm2.opt.loading')
    Add-WCChild $optSec.Body $State.OptSpinner
    $State.OptHost = New-WCVStack -Spacing 4
    Add-WCChild $optSec.Body $State.OptHost
    Add-WCChild $hostPanel $optSec.Root

    return $root
}

function Update-WCM2LowSpaceChip {
    # Chip do canh bao o he thong sap day (<15% hoac <10GB) - spec M2
    param($State)
    if (-not $State.LowChip) { return }
    try {
        $d = Get-WCM2SystemDisk -Fresh
        if (($null -eq $d) -or ($null -eq $d.Free) -or ($null -eq $d.Total) -or ($d.Total -le 0)) {
            $State.LowChip.Visibility = [Windows.Visibility]::Collapsed
            return
        }
        $pct = [math]::Round((100.0 * [double]$d.Free / [double]$d.Total))
        if (($pct -lt 15) -or ($d.Free -lt 10GB)) {
            Set-WCChipText -Chip $State.LowChip -Text (T 'm2.lowspace' @((ConvertTo-WCHumanSize ([long]$d.Free)), ([string]$pct)))
            $State.LowChip.Visibility = [Windows.Visibility]::Visible
        } else {
            $State.LowChip.Visibility = [Windows.Visibility]::Collapsed
        }
    } catch {
        $State.LowChip.Visibility = [Windows.Visibility]::Collapsed
    }
}

function Invoke-WCM2Scan {
    # QUET (chi doc): 2 task song song - danh muc tep (co Huy) + Thung rac (spinner rieng)
    param($State)
    if (Test-WCTaskRunning -Id 'm2.scan') { return }
    if (Test-WCTaskRunning -Id 'm2.clean') {
        Show-WCToast (T 'common.running' @((T 'm2.running'))) 'Info'
        return
    }
    Clear-WCCheckList $State.CatList
    $State.EmptyText = $null
    $State.RunBtn.IsEnabled = $false
    $State.SummaryText.Text = ''
    if ($State.ResultSection) { $State.ResultSection.Root.Visibility = [Windows.Visibility]::Collapsed }
    $State.ScanSpinner.Visibility = [Windows.Visibility]::Visible
    $State.RbSpinner.Visibility = [Windows.Visibility]::Visible

    # Task rieng: dem Thuong rac (COM co the cham)
    $null = Start-WCTask -Id 'm2.scan.rb' -Title (T 'm2.cat.recycle') -Worker {
        param($ctx, $s)
        Get-WCM2RecycleBinStats
    } -Done {
        param($rb)
        $State.RbSpinner.Visibility = [Windows.Visibility]::Collapsed
        if ($rb -and (([int]$rb.Items) -gt 0)) {
            if ($State.EmptyText) {
                try { $State.CatList.Children.Remove($State.EmptyText) } catch { }
                $State.EmptyText = $null
                $State.RunBtn.IsEnabled = $true
            }
            $cat = @{
                Key = 'recycle'; Name = (T 'm2.cat.recycle'); Risk = 'Recommended'; Kind = 'RecycleBin'
                Size = [long]$rb.Bytes; Files = [int]$rb.Items; Targets = @()
                Loss = (T 'm2.cat.recycle.loss'); Note = ''
                Roots = 'Shell NameSpace(0xA)'; SkipAtRun = $false
            }
            $risk = Get-WCRiskInfo 'Recommended'
            $row = Add-WCCheckRow -List $State.CatList -Item $cat -TextColumns @(
                [string]$cat.Name,
                (ConvertTo-WCHumanSize ([long]$cat.Size)),
                (T 'm2.items' @([string][int]$cat.Files))
            ) -ChipText ([string]$risk.Text) -ChipKind 'Ok' -Checked:$true
            $row.ToolTip = ([string]$cat.Loss + "`n" + (T 'm2.roots' @([string]$cat.Roots)))
        }
    }.GetNewClosure()

    # Task chinh: quet danh muc tep
    $ok = Start-WCTask -Id 'm2.scan' -Title (T 'm2.scanning') -ShowStatus -Worker {
        param($ctx, $s)
        @(Get-WCM2ScanCategories -Ctx $ctx)
    } -Done {
        param($result)
        $State.ScanSpinner.Visibility = [Windows.Visibility]::Collapsed
        $State.ScanBtn.Content = (T 'common.rescan')
        # KHONG Clear o day: task Thuong rac co the da them dong truoc (progressive)
        $cats = @($result)
        $hasAny = $false
        $total = [long]0
        $count = 0
        if (($cats.Count -gt 0) -and ($null -ne $cats[0])) {
            foreach ($cat in $cats) {
                if ($null -eq $cat) { continue }
                $hasAny = $true
                $count++
                $total += [long]$cat.Size
                $risk = Get-WCRiskInfo ([string]$cat.Risk)
                $chipKind = $risk.Brush.Replace('Wc', '')
                $cols = @(
                    [string]$cat.Name,
                    (ConvertTo-WCHumanSize ([long]$cat.Size)),
                    (T 'm2.files' @([string][int]$cat.Files))
                )
                if ([string]$cat.Note) { $cols += @([string]$cat.Note) }
                $row = Add-WCCheckRow -List $State.CatList -Item $cat -TextColumns $cols `
                    -ChipText ([string]$risk.Text) -ChipKind $chipKind `
                    -Checked:(([string]$cat.Risk) -eq 'Recommended')
                $tip = [string]$cat.Loss
                $tip = $tip + "`n" + (T 'm2.roots' @([string]$cat.Roots))
                if ([string]$cat.Note) { $tip = $tip + "`n" + [string]$cat.Note }
                $row.ToolTip = $tip
                if ([string]$cat.Kind -eq 'InfoOnly') {
                    # Windows.old: khong tu xoa -> khoa checkbox lai (chi tham khao)
                    try {
                        $dock = $row.Child
                        if ($dock -is [Windows.Controls.DockPanel]) {
                            $cbx = $dock.Children[0]
                            if ($cbx -is [Windows.Controls.CheckBox]) { $cbx.IsEnabled = $false }
                        }
                    } catch { }
                }
            }
        }
        if ($hasAny) {
            $State.SummaryText.Text = (T 'm2.scan.done' @([string]$count, (ConvertTo-WCHumanSize $total)))
            $State.RunBtn.IsEnabled = $true
        } else {
            # Co the task Thuong rac da them dong rieng -> chi bao "khong co gi them"
            $hasRows = $false
            foreach ($ch in $State.CatList.Children) {
                if ($ch -is [Windows.Controls.Border]) { $hasRows = $true; break }
            }
            if ($hasRows) {
                $State.SummaryText.Text = (T 'm2.empty')
            } else {
                $empty = New-WCTextBlock -Text (T 'm2.empty') -Size 12.5 -ColorKey 'WcSubtle' -Wrap
                $State.EmptyText = $empty
                Add-WCChild $State.CatList $empty
                $State.RunBtn.IsEnabled = $false
            }
        }
    }.GetNewClosure()
    if (-not $ok) { return }
}

function Invoke-WCM2RunSelected {
    # XEM LAI -> XAC NHAN -> CHAY (moi phep xoa qua Remove-WCItem / cmdlet chinh thuc)
    param($State)
    if (Test-WCTaskRunning -Id 'm2.clean') {
        Show-WCToast (T 'common.running' @((T 'm2.running'))) 'Info'
        return
    }
    if (Test-WCTaskRunning -Id 'm2.scan') {
        Show-WCToast (T 'common.running' @((T 'm2.scanning'))) 'Info'
        return
    }
    $selected = @()
    foreach ($x in @(Get-WCCheckRowSelection $State.CatList)) {
        if ($null -ne $x) { $selected += $x }
    }
    if ($selected.Count -eq 0) {
        Show-WCToast (T 'm2.select.none') 'Info'
        return
    }

    # XAC NHAN: tom tat dung thu se lam + hoan tac duoc / khong duoc gi
    $lines = @()
    $hasDanger = $false
    $hasUndoable = $false
    foreach ($cat in $selected) {
        $line = '- ' + [string]$cat.Name + ' — ' + (ConvertTo-WCHumanSize ([long]$cat.Size)) + ' (' + (T 'm2.files' @([string][int]$cat.Files)) + ')'
        if ([string]$cat.Note) { $line = $line + ' [' + [string]$cat.Note + ']' }
        $lines += $line
        if ([string]$cat.Risk -eq 'Risky') { $hasDanger = $true }
        if ([string]$cat.Kind -eq 'Hibernate') { $hasUndoable = $true }
        if ([string]$cat.Kind -eq 'InfoOnly') { $lines += ('    ' + (T 'm2.cat.windowsold.skip')) }
    }
    $undoTxt = ''
    if ($hasUndoable) { $undoTxt = (T 'm2.confirm.undo') }
    $msg = ([string]::Join("`n", $lines))
    if (-not (Show-WCConfirm -Title (T 'm2.confirm.title') -Message $msg -Undoable $undoTxt -NotUndoable (T 'm2.confirm.noundo') -Danger:$hasDanger)) {
        return
    }

    $runArgs = @{ Categories = $selected }
    $ok = Start-WCTask -Id 'm2.clean' -Title (T 'm2.running') -ShowStatus -Args $runArgs -Worker {
        param($ctx, $s)
        $report = @{
            FreeBefore = $null; FreeAfter = $null; Freed = [long]0
            Deleted = 0; Skipped = 0; Notes = @(); DryRun = (Test-WCDryRunMode)
        }
        # Do free space THAT truoc khi chay (spec M2: ket qua = chenh lech that)
        $dBefore = Get-WCM2SystemDisk -Fresh
        if ($dBefore) { $report.FreeBefore = $dBefore.Free }

        $cats = @($s.Categories)
        $n = $cats.Count
        if ($n -lt 1) { $n = 1 }
        for ($i = 0; $i -lt $cats.Count; $i++) {
            $cat = $cats[$i]
            if ($null -eq $cat) { continue }
            if ($ctx.Cancelled()) { break }
            $ctx.Progress(([int](5 + ((85 * $i) / $n))), (T 'm2.running.item' @([string]$cat.Name)))
            $ctx.Log(('Danh muc: ' + [string]$cat.Key + ' (' + [string]$cat.Kind + ')'))

            # Chi liet ke / dang cho khoi dong lai -> ghi chu, khong lam
            if ([string]$cat.Kind -eq 'InfoOnly') {
                $report.Notes += (T 'm2.cat.windowsold.skip')
                continue
            }
            if ($cat.SkipAtRun) {
                if ([string]$cat.Note) { $report.Notes += [string]$cat.Note }
                else { $report.Notes += (T 'm2.skipped.cat' @([string]$cat.Name)) }
                continue
            }

            if ([string]$cat.Kind -eq 'Files') {
                $entry = $null
                if (-not $report.DryRun) {
                    $entry = Add-WCJournalEntry -Module 'M2' -Action (T 'm2.journal.clean') -Target ([string]$cat.Name) -OldValue (ConvertTo-WCHumanSize ([long]$cat.Size)) -UndoType ''
                }
                foreach ($t in @($cat.Targets)) {
                    if ($ctx.Cancelled()) { break }
                    $r = Remove-WCItem -Path ([string]$t)
                    if ($r) {
                        $report.Deleted += [int]$r.Deleted
                        $report.Skipped += [int]$r.Skipped
                    }
                }
                if ($entry) { Complete-WCJournalEntry -Entry $entry -Result 'Ok' }
            }
            elseif ([string]$cat.Kind -eq 'WuDownload') {
                # Kiem tra lai luc chay: dang cho khoi dong lai thi bo qua (spec M2)
                if (Get-WCM2IsRebootPending) {
                    $report.Notes += (T 'm2.wu.skip')
                    continue
                }
                $wuWas = Get-WCM2ServiceRunning -Name 'wuauserv'
                $bitsWas = Get-WCM2ServiceRunning -Name 'bits'
                $entry = $null
                if (-not $report.DryRun) {
                    $ctx.Log('Tam dung wuauserv/bits de don cache Windows Update')
                    Invoke-WCM2StopService -Name 'wuauserv'
                    Invoke-WCM2StopService -Name 'bits'
                    $entry = Add-WCJournalEntry -Module 'M2' -Action (T 'm2.journal.clean') -Target ([string]$cat.Name) -OldValue (ConvertTo-WCHumanSize ([long]$cat.Size)) -UndoType ''
                }
                foreach ($t in @($cat.Targets)) {
                    if ($ctx.Cancelled()) { break }
                    $r = Remove-WCItem -Path ([string]$t)
                    if ($r) {
                        $report.Deleted += [int]$r.Deleted
                        $report.Skipped += [int]$r.Skipped
                    }
                }
                # Khoi phuc DUNG trang thai ban dau (chi start lai nhung cai dang chay)
                if (-not $report.DryRun) {
                    $ctx.Log('Khoi phuc dich vu wuauserv/bits ve trang thai cu')
                    if ($wuWas) { Invoke-WCM2StartService -Name 'wuauserv' }
                    if ($bitsWas) { Invoke-WCM2StartService -Name 'bits' }
                    if ($entry) { Complete-WCJournalEntry -Entry $entry -Result 'Ok' }
                }
            }
            elseif ([string]$cat.Kind -eq 'RecycleBin') {
                # Clear-RecycleBin la cmdlet chinh thuc (duong dan $Recycle.Bin nam
                # ngoai whitelist nen Remove-WCItem khong ap dung duoc cho muc nay)
                $entry = $null
                if (-not $report.DryRun) {
                    $entry = Add-WCJournalEntry -Module 'M2' -Action (T 'm2.journal.clean') -Target ([string]$cat.Name) -OldValue (ConvertTo-WCHumanSize ([long]$cat.Size)) -UndoType ''
                }
                try {
                    if ($report.DryRun) {
                        $ctx.Log('[DRY-RUN] Clear-RecycleBin -Force')
                    } else {
                        Clear-RecycleBin -Force -ErrorAction Stop
                        $report.Deleted += [int]$cat.Files
                    }
                    if ($entry) { Complete-WCJournalEntry -Entry $entry -Result 'Ok' }
                } catch {
                    $report.Skipped++
                    if ($entry) { Complete-WCJournalEntry -Entry $entry -Result ('Failed: ' + $_.Exception.Message) }
                }
            }
            elseif ([string]$cat.Kind -eq 'Hibernate') {
                # RUI RO nhung hoan tac duoc: powercfg /h on (handler 'hibernate.on' co san)
                $entry = $null
                if (-not $report.DryRun) {
                    $entry = Add-WCJournalEntry -Module 'M2' -Action (T 'm2.journal.hibernate') -Target 'powercfg /h off' -OldValue (ConvertTo-WCHumanSize ([long]$cat.Size)) -UndoType 'hibernate.on'
                }
                try {
                    if ($report.DryRun) {
                        $ctx.Log('[DRY-RUN] powercfg /h off')
                    } else {
                        # Kiem tra exit code (khong parse output - spec 2.3)
                        $pc = Start-Process -FilePath 'powercfg.exe' -ArgumentList @('/h', 'off') -WindowStyle Hidden -Wait -PassThru
                        if ($pc.ExitCode -ne 0) { throw ('powercfg /h off that bai (exit ' + [string]$pc.ExitCode + ')') }
                        $report.Deleted++
                    }
                    if ($entry) { Complete-WCJournalEntry -Entry $entry -Result 'Ok' }
                } catch {
                    $report.Skipped++
                    if ($entry) { Complete-WCJournalEntry -Entry $entry -Result ('Failed: ' + $_.Exception.Message) }
                }
            }
        }

        # Do free space THAT sau khi chay
        $dAfter = Get-WCM2SystemDisk -Fresh
        if ($dAfter) { $report.FreeAfter = $dAfter.Free }
        if (($null -ne $report.FreeBefore) -and ($null -ne $report.FreeAfter)) {
            $delta = ([long]$report.FreeAfter - [long]$report.FreeBefore)
            if ($delta -gt 0) { $report.Freed = $delta }
        }
        return $report
    } -Done {
        param($report)
        Show-WCM2Result $State $report
    }.GetNewClosure()
    if (-not $ok) {
        Show-WCToast (T 'common.running' @((T 'm2.running'))) 'Info'
    }
}

function Show-WCM2Result {
    # KET QUA: do bang chenh lech free space that + so muc bo qua + nut xem log
    param($State, $Report)
    if ($null -eq $Report) { return }
    $body = $State.ResultHost
    $body.Children.Clear()
    $State.ResultSection.Root.Visibility = [Windows.Visibility]::Visible

    $freed = [long]0
    try { $freed = [long]$Report.Freed } catch { $freed = [long]0 }
    if ($freed -gt 1MB) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm2.result.freed' @((ConvertTo-WCHumanSize $freed))) -Size 15 -Weight 'SemiBold' -Wrap)
    } else {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm2.result.none') -Size 13.5 -Wrap)
    }

    $table = New-WCTable -Columns @(
        @{ Header = ''; Prop = 'C0'; Width = 260 }
        @{ Header = (T 'common.before'); Prop = 'C1'; Width = 170 }
        @{ Header = (T 'common.after'); Prop = 'C2'; Width = 170 }
    )
    $sysLetter = ''
    try { $sysLetter = ([IO.Path]::GetPathRoot($env:SystemRoot)).TrimEnd('\') } catch { }
    $beforeTxt = '—'
    $afterTxt = '—'
    if ($null -ne $Report.FreeBefore) { $beforeTxt = (ConvertTo-WCHumanSize ([long]$Report.FreeBefore)) }
    if ($null -ne $Report.FreeAfter) { $afterTxt = (ConvertTo-WCHumanSize ([long]$Report.FreeAfter)) }
    $row = [PSCustomObject]@{
        C0 = (T 'm2.result.free' @($sysLetter))
        C1 = $beforeTxt
        C2 = $afterTxt
    }
    $table.Items.Add($row) | Out-Null
    Add-WCChild $body $table

    $skipped = 0
    try { $skipped = [int]$Report.Skipped } catch { $skipped = 0 }
    if ($skipped -gt 0) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm2.result.skipped' @([string]$skipped)) -Size 12.5 -ColorKey 'WcWarn' -Wrap)
    }
    foreach ($note in @($Report.Notes)) {
        if ($note) { Add-WCChild $body (New-WCTextBlock -Text ([string]$note) -Size 12 -ColorKey 'WcSubtle' -Wrap) }
    }
    if ($Report.DryRun) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'common.dryrun.header') -Size 12.5 -ColorKey 'WcWarn' -Wrap)
    }
    $btnRow = New-WCHStack
    $logBtn = New-WCButton -Text (T 'm2.viewlog') -Small -OnClick { param($b) Open-WCLogFile }.GetNewClosure()
    $btnRow.Children.Add($logBtn) | Out-Null
    Add-WCChild $body $btnRow
    Add-WCChild $body (New-WCTextBlock -Text (T 'm2.result.rescan') -Size 12 -ColorKey 'WcSubtle' -Wrap)

    Update-WCM2LowSpaceChip $State
}

function Invoke-WCM2PopulateDrives {
    # Nap combobox chon o (CIM nhanh, chay tren UI thread voi cache)
    param($State)
    try {
        $State.DriveCombo.Items.Clear()
        $disks = @(Get-WCM2LogicalDisks)
        foreach ($d in $disks) {
            $label = [string]$d.DeviceId
            if ([string]$d.VolumeName) { $label = $label + ' ' + [string]$d.VolumeName }
            $label = (T 'm2.analyze.drivefmt' @($label, (ConvertTo-WCHumanSize ([long]$d.Free)), (ConvertTo-WCHumanSize ([long]$d.Size))))
            $item = [PSCustomObject]@{ Label = $label; Letter = ([string]$d.DeviceId).TrimEnd(':') }
            $State.DriveCombo.Items.Add($item) | Out-Null
        }
        if ($State.DriveCombo.Items.Count -gt 0) { $State.DriveCombo.SelectedIndex = 0 }
    } catch {
        Write-WCLog 'WARN' ('Nap danh sach o that bai: ' + $_.Exception.Message)
    }
}

function Invoke-WCM2Analyze {
    # Phan tich: TOP 100 tep lon nhat (chi doc, Huy duoc)
    param($State)
    if (Test-WCTaskRunning -Id 'm2.analyze') {
        Show-WCToast (T 'common.running' @((T 'm2.analyze.title'))) 'Info'
        return
    }
    $sel = $State.DriveCombo.SelectedItem
    if (-not $sel) {
        Show-WCToast (T 'm2.analyze.picknone') 'Info'
        return
    }
    $letter = [string]$sel.Letter
    if ([string]::IsNullOrEmpty($letter)) {
        Show-WCToast (T 'm2.analyze.picknone') 'Info'
        return
    }
    $State.TopTable.Items.Clear()
    $State.AnaSummary.Text = ''
    $State.AnalyzeSpinner.Visibility = [Windows.Visibility]::Visible
    $ok = Start-WCTask -Id 'm2.analyze' -Title (T 'm2.analyze.title') -ShowStatus -Args @{ Root = ($letter + ':\') } -Worker {
        param($ctx, $s)
        Get-WCM2TopFiles -Root ([string]$s.Root) -Top 100 -Ctx $ctx
    } -Done {
        param($result)
        $State.AnalyzeSpinner.Visibility = [Windows.Visibility]::Collapsed
        $files = @($result)
        if (($files.Count -eq 0) -or ($null -eq $files[0])) {
            $State.AnaSummary.Text = (T 'm2.analyze.empty')
            return
        }
        $total = [long]0
        foreach ($f in $files) {
            if ($null -eq $f) { continue }
            $total += [long]$f.Size
            $row = [PSCustomObject]@{
                File = [string]$f.Path
                Size = (ConvertTo-WCHumanSize ([long]$f.Size))
                Modified = ''
                RawSize = [long]$f.Size
            }
            try { $row.Modified = ([DateTime]$f.Modified).ToString('yyyy-MM-dd HH:mm') } catch { }
            $State.TopTable.Items.Add($row) | Out-Null
        }
        $State.AnaSummary.Text = (T 'm2.analyze.done' @([string]$files.Count, (ConvertTo-WCHumanSize $total)))
    }.GetNewClosure()
    if (-not $ok) {
        $State.AnalyzeSpinner.Visibility = [Windows.Visibility]::Collapsed
        Show-WCToast (T 'common.running' @((T 'm2.analyze.title'))) 'Info'
    }
}

function Invoke-WCM2OpenLocation {
    # explorer.exe /select,<tep> - khong can quyen, khong thay doi he thong
    param($State)
    $sel = $State.TopTable.SelectedItem
    if (-not $sel) {
        Show-WCToast (T 'm2.analyze.none') 'Info'
        return
    }
    try {
        Start-Process -FilePath 'explorer.exe' -ArgumentList ('/select,"' + [string]$sel.File + '"')
    } catch {
        Show-WCToast (T 'common.cannotopen') 'Warn'
    }
}

function Invoke-WCM2RecycleSelected {
    # Chi CHUYEN vao Thuong rac (Send-WCFileToRecycleBin co san trong 08-Interop),
    # sau khi xac nhan; KHONG co xoa vinh vien o man nay (spec M2).
    param($State)
    if (Test-WCTaskRunning -Id 'm2.recycle1') { return }
    $selItem = $State.TopTable.SelectedItem
    if (-not $selItem) {
        Show-WCToast (T 'm2.analyze.none') 'Info'
        return
    }
    $selFile = [string]$selItem.File
    $selSize = [string]$selItem.Size
    $msg = (T 'm2.analyze.recycle.msg') + "`n" + $selFile + ' — ' + $selSize
    if (-not (Show-WCConfirm -Title (T 'm2.analyze.recycle.title') -Message $msg -Undoable (T 'm2.analyze.recycle.undo'))) {
        return
    }
    $rargs = @{ Path = $selFile; SizeText = $selSize }
    $ok = Start-WCTask -Id 'm2.recycle1' -Title (T 'm2.analyze.recycle') -Args $rargs -Worker {
        param($ctx, $s)
        $entry = $null
        if (-not (Test-WCDryRunMode)) {
            # Hoan tac thu cong tu Thuong rac -> UndoType '' (spec M2)
            $entry = Add-WCJournalEntry -Module 'M2' -Action (T 'm2.journal.bigfile') -Target ([string]$s.Path) -OldValue ([string]$s.SizeText) -UndoType ''
        }
        $moved = Send-WCFileToRecycleBin -Path ([string]$s.Path)
        if ($entry) {
            if ($moved) { Complete-WCJournalEntry -Entry $entry -Result 'Ok' }
            else { Complete-WCJournalEntry -Entry $entry -Result 'Failed' }
        }
        return @{ Path = [string]$s.Path; Ok = [bool]$moved }
    } -Done {
        param($r)
        if ($r -and $r.Ok) {
            try { $State.TopTable.Items.Remove($selItem) } catch { }
            Show-WCToast (T 'm2.analyze.recycle.ok') 'Ok'
            Update-WCM2LowSpaceChip $State
        } else {
            Show-WCToast (T 'm2.analyze.recycle.fail') 'Bad'
        }
    }.GetNewClosure()
    if (-not $ok) { return }
}

function Invoke-WCM2LoadDisks {
    # Tai danh sach o vat ly o nen (Get-PhysicalDisk co the cham)
    param($State)
    $ok = Start-WCTask -Id 'm2.disks' -Title (T 'm2.opt.title') -Worker {
        param($ctx, $s)
        Get-WCM2PhysicalDiskRows
    } -Done {
        param($result)
        $State.OptSpinner.Visibility = [Windows.Visibility]::Collapsed
        $rows = @($result)
        if (($rows.Count -eq 0) -or ($null -eq $rows[0])) {
            Add-WCChild $State.OptHost (New-WCTextBlock -Text (T 'm2.opt.none') -Size 12.5 -ColorKey 'WcSubtle' -Wrap)
            return
        }
        foreach ($row in $rows) {
            if ($null -eq $row) { continue }
            Add-WCM2DiskRow $State $row
        }
    }.GetNewClosure()
    if (-not $ok) {
        $State.OptSpinner.Visibility = [Windows.Visibility]::Collapsed
    }
}

function Add-WCM2DiskRow {
    # 1 the o vat ly: ten + chip SSD/HDD/Khong xac dinh + nut hanh dong tung ky tu o.
    # SSD -> TRIM; HDD -> Phan tich roi moi mo khoa Defrag; khac -> khong doan.
    param($State, $Row)
    $card = New-Object Windows.Controls.Border
    $card.CornerRadius = (New-Object Windows.CornerRadius(8))
    $card.BorderThickness = (New-Object Windows.Thickness(1))
    $card.Padding = (New-Object Windows.Thickness(12))
    $card.Margin = (New-Object Windows.Thickness(0, 4, 0, 4))
    $card.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'WcCardBg2')
    $card.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'WcBorder')

    $inner = New-WCVStack -Spacing 6
    $topRow = New-WCHStack -Spacing 10
    $nameTxt = New-WCTextBlock -Text ([string]$Row.FriendlyName) -Size 13.5 -Weight 'SemiBold'
    $nameTxt.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $topRow.Children.Add($nameTxt) | Out-Null
    if ([string]$Row.BusType) {
        $bus = New-WCChip -Text ([string]$Row.BusType) -Kind 'Plain'
        $bus.VerticalAlignment = [Windows.VerticalAlignment]::Center
        $topRow.Children.Add($bus) | Out-Null
    }
    $media = [string]$Row.MediaType
    $mediaChip = $null
    if ($media -eq 'SSD') {
        $mediaChip = New-WCChip -Text (T 'm2.opt.ssd') -Kind 'Ok'
    } elseif ($media -eq 'HDD') {
        $mediaChip = New-WCChip -Text (T 'm2.opt.hdd') -Kind 'Plain'
    } else {
        $mediaChip = New-WCChip -Text (T 'common.unknown') -Kind 'Unknown'
    }
    $mediaChip.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $topRow.Children.Add($mediaChip) | Out-Null
    Add-WCChild $inner $topRow

    $letters = @($Row.Letters)
    if ($letters.Count -eq 0) {
        Add-WCChild $inner (New-WCTextBlock -Text (T 'm2.opt.noletter') -Size 12 -ColorKey 'WcSubtle' -Wrap)
    }
    foreach ($lt in $letters) {
        $letter = ([string]$lt).Trim()
        if ([string]::IsNullOrEmpty($letter)) { continue }
        $rowLine = New-WCHStack -Spacing 8
        $ltTxt = New-WCTextBlock -Text ($letter + ':') -Size 13 -Weight 'SemiBold'
        $ltTxt.VerticalAlignment = [Windows.VerticalAlignment]::Center
        $rowLine.Children.Add($ltTxt) | Out-Null
        if ($media -eq 'SSD') {
            $btn = New-WCButton -Text (T 'm2.opt.trim') -Kind Primary -Small -OnClick { param($b) Invoke-WCM2Optimize $State $letter 'ReTrim' }.GetNewClosure()
            $rowLine.Children.Add($btn) | Out-Null
            Add-WCChild $inner $rowLine
            Add-WCChild $inner (New-WCExpertLine -Command ('Optimize-Volume -DriveLetter ' + $letter + ' -ReTrim'))
        }
        elseif ($media -eq 'HDD') {
            $aBtn = New-WCButton -Text (T 'm2.opt.analyze') -Small -OnClick { param($b) Invoke-WCM2Optimize $State $letter 'Analyze' }.GetNewClosure()
            $dBtn = New-WCButton -Text (T 'm2.opt.defrag') -Small -Disabled -OnClick { param($b) Invoke-WCM2Optimize $State $letter 'Defrag' }.GetNewClosure()
            $State.DefragBtns[$letter] = $dBtn
            $rowLine.Children.Add($aBtn) | Out-Null
            $rowLine.Children.Add($dBtn) | Out-Null
            Add-WCChild $inner $rowLine
            Add-WCChild $inner (New-WCExpertLine -Command ('Optimize-Volume -DriveLetter ' + $letter + ' -Analyze; Optimize-Volume -DriveLetter ' + $letter + ' -Defrag'))
        }
        else {
            # MediaType 'Unspecified' hoac khac: KHONG doan (spec: khong bao gio defrag SSD)
            $txt = New-WCTextBlock -Text (T 'm2.opt.unknown') -Size 12 -ColorKey 'WcSubtle' -Wrap
            $txt.VerticalAlignment = [Windows.VerticalAlignment]::Center
            $rowLine.Children.Add($txt) | Out-Null
            Add-WCChild $inner $rowLine
        }
    }
    $card.Child = $inner
    Add-WCChild $State.OptHost $card
}

function Invoke-WCM2Optimize {
    # TRIM / Phan tich / Defrag qua Optimize-Volume (chay truc tiep trong worker, admin co san)
    param($State, [string]$Letter, [string]$Mode)
    if (Test-WCTaskRunning -Id 'm2.opt') {
        Show-WCToast (T 'common.running' @((T 'm2.opt.title'))) 'Info'
        return
    }
    $ok = Start-WCTask -Id 'm2.opt' -Title (T 'm2.opt.title') -ShowStatus -Args @{ Letter = $Letter; Mode = $Mode } -Worker {
        param($ctx, $s)
        $letter = ([string]$s.Letter).Trim().TrimEnd(':')
        $mode = [string]$s.Mode
        $dry = Test-WCDryRunMode
        # Phan tich la doc thong tin -> khong ghi journal; TRIM/Defrag co thay doi
        $entry = $null
        if ((-not $dry) -and ($mode -ne 'Analyze')) {
            $actionKey = 'm2.journal.retrim'
            if ($mode -eq 'Defrag') { $actionKey = 'm2.journal.defrag' }
            $entry = Add-WCJournalEntry -Module 'M2' -Action (T $actionKey) -Target ($letter + ':') -OldValue '' -UndoType ''
        }
        try {
            if ($letter.Length -lt 1) { throw 'Khong co ky tu o' }
            $c = [char]$letter[0]
            if ($dry) {
                Write-WCLog 'DRYRUN' ('[DRY-RUN] Optimize-Volume -DriveLetter ' + $letter + ' -' + $mode)
            }
            elseif ($mode -eq 'ReTrim') {
                Optimize-Volume -DriveLetter $c -ReTrim -ErrorAction Stop
            }
            elseif ($mode -eq 'Analyze') {
                Optimize-Volume -DriveLetter $c -Analyze -ErrorAction Stop
            }
            else {
                Optimize-Volume -DriveLetter $c -Defrag -ErrorAction Stop
            }
            if ($entry) { Complete-WCJournalEntry -Entry $entry -Result 'Ok' }
            return @{ Ok = $true; Letter = $letter; Mode = $mode }
        } catch {
            if ($entry) { Complete-WCJournalEntry -Entry $entry -Result ('Failed: ' + $_.Exception.Message) }
            Write-WCLog 'WARN' ('Optimize-Volume ' + $letter + ' ' + $mode + ' that bai: ' + $_.Exception.Message)
            return @{ Ok = $false; Letter = $letter; Mode = $mode }
        }
    } -Done {
        param($r)
        $lt = ''
        $mode = ''
        $okr = $false
        if ($r) {
            $lt = [string]$r.Letter
            $mode = [string]$r.Mode
            $okr = [bool]$r.Ok
        }
        if ($okr) {
            if ($mode -eq 'Analyze') {
                if ($State.DefragBtns.ContainsKey($lt)) {
                    $State.DefragBtns[$lt].IsEnabled = $true
                }
                Show-WCToast (T 'm2.opt.analyze.done' @($lt)) 'Ok'
            } else {
                Show-WCToast (T 'm2.opt.done' @($lt)) 'Ok'
            }
            Update-WCM2LowSpaceChip $State
        } else {
            Show-WCToast (T 'm2.opt.fail' @($lt)) 'Bad'
        }
    }.GetNewClosure()
    if (-not $ok) { return }
}


# ============================================================================
# REGION: 14-M3-Driver.ps1
# ============================================================================

# ============================================================================
#  src/14-M3-Driver.ps1 - Module M3: QUET VA TAI DRIVER CHO DUNG MAY
#  Su that the hien trong UI: KHONG co API chung nao cho "driver moi nhat cua
#  moi phan cung". Kien truc 3 lop nguon: kiem ke (chi doc), Windows Update
#  (chinh thuc, da ky), GPU/OEM (mo trang chinh thuc, KHONG scrape trang hang).
#  KHONG bao gio noi "moi nhat" khi khong co nguon so sanh (spec M3).
# ============================================================================

Register-WCStrings 'vi' @{
    'm3.title' = 'Driver'
    'm3.subtitle' = 'Quét và tải driver phù hợp cho đúng máy — trung thực về "mới nhất"'
    'm3.fact' = 'Không có API chung nào cho "driver mới nhất của mọi phần cứng". WinCare kiểm kê máy (chỉ đọc), tra nguồn chính thức (Windows Update, trang hãng) và KHÔNG scrape trang hãng — nên không tự nhận "mới nhất" khi không có nguồn so. Driver cũ không có nghĩa là xấu.'
    'm3.rescan' = 'Quét lại'
    'm3.devmgr' = 'Mở Device Manager'
    'm3.scan.inventory' = 'Đang kiểm kê driver (có thể chậm trên một số máy)…'
    'm3.scan.problems' = 'Đang kiểm tra thiết bị lỗi…'
    'm3.scan.system' = 'Đang đọc thông tin GPU / OEM / BIOS…'
    'm3.scan.backup' = 'Đang đọc danh sách bản sao lưu…'
    # --- Cap nhat Windows Update ---
    'm3.updates.title' = 'Cập nhật có sẵn (Windows Update)'
    'm3.updates.hint' = 'Nguồn chính thức của Microsoft, driver đã ký số. KHÔNG mục nào được tick sẵn — hãy tự chọn rồi bấm cài.'
    'm3.updates.searching' = 'Đang tìm cập nhật driver qua Windows Update (có thể mất vài phút, bấm Hủy để bỏ qua chờ)…'
    'm3.updates.wsus' = 'Máy đang được quản lý bằng WSUS/GPO — danh sách cập nhật có thể không đầy đủ. WinCare không lách chính sách của tổ chức.'
    'm3.updates.empty' = 'Không có cập nhật driver nào từ Windows Update cho máy này.'
    'm3.updates.fail' = 'Không tìm được cập nhật: {0}'
    'm3.updates.install' = 'Tải và cài các mục đã chọn'
    'm3.updates.install.confirm.title' = 'Cài driver qua Windows Update?'
    'm3.updates.install.confirm.msg' = "Sẽ tải và cài {0} mục driver qua Windows Update:`n`n{1}`n`nTrước khi cài, WinCare sẽ tự động:`n• Sao lưu toàn bộ driver hiện tại (nếu chưa có bản sao lưu hôm nay)`n• Thử tạo điểm khôi phục hệ thống"
    'm3.updates.install.confirm.noundo' = 'Driver cũ có thể khôi phục từ bản sao lưu (pnputil) hoặc Rollback qua Device Manager — Windows không tự hoàn tác.'
    # --- Luong cai driver ---
    'm3.install.backup' = 'Đang sao lưu driver hiện tại…'
    'm3.install.restorepoint' = 'Đang tạo điểm khôi phục hệ thống…'
    'm3.install.searching' = 'Đang tìm lại các mục đã chọn trong Windows Update…'
    'm3.install.download' = 'Đang tải {0}/{1}: {2}'
    'm3.install.installing' = 'Đang cài {0} mục driver…'
    'm3.restorepoint.fail.title' = 'Không tạo được điểm khôi phục'
    'm3.restorepoint.fail.msg' = 'Không tạo được điểm khôi phục (System Protection có thể đang tắt).{0}WinCare KHÔNG tự bật System Protection.{0}Tiếp tục cài driver mà không có điểm khôi phục?'
    'm3.result.dryrun' = 'DRY-RUN: sẽ tải và cài {0} mục driver (không thực hiện).'
    'm3.result.ok' = 'Đã cài xong {0} mục driver.'
    'm3.result.failed' = 'Không cài được: {0}'
    'm3.result.skipped' = 'Bỏ qua (không tìm lại được): {0}'
    'm3.result.download.fail' = 'Không tải được các mục: {0}'
    'm3.result.cancelled' = 'Đã dừng theo yêu cầu — kết quả giữa chừng được bỏ qua.'
    'm3.result.reboot' = 'Cần khởi động lại máy để hoàn tất.'
    'm3.result.backup.new' = 'Driver cũ đã được sao lưu tại: {0}'
    'm3.result.backup.today' = 'Đã có bản sao lưu hôm nay: {0}'
    'm3.result.restorepoint.ok' = 'Đã tạo điểm khôi phục "WinCare trước khi cài driver".'
    'm3.result.restorepoint.skip' = 'Đã cài theo lựa chọn của bạn: bỏ qua điểm khôi phục.'
    'm3.result.search.fail' = 'Không tìm lại được danh sách cập nhật: {0}'
    'm3.result.fixture' = 'Đang ở chế độ FIXTURE (dữ liệu giả) — không cài thật.'
    'm3.result.nomatch' = 'Không khớp lại được mục nào với Windows Update (danh sách có thể đã thay đổi) — hãy quét lại.'
    # --- Thiet bi loi ---
    'm3.problems.title' = 'Thiết bị lỗi'
    'm3.problems.hint' = 'Các thiết bị đang báo lỗi trong Device Manager — ưu tiên xử lý nhóm này trước.'
    'm3.problems.empty' = 'Không có thiết bị nào đang lỗi — tốt.'
    'm3.problems.count' = '{0} thiết bị đang lỗi'
    'm3.problems.fail' = 'Không đọc được danh sách thiết bị lỗi: {0}'
    'm3.problems.col.device' = 'Thiết bị'
    'm3.problems.col.code' = 'Mã lỗi'
    'm3.problems.col.meaning' = 'Ý nghĩa'
    # --- GPU / OEM / BIOS ---
    'm3.oem.title' = 'GPU / Máy OEM / BIOS'
    'm3.oem.hint' = 'Windows Update thường KHÔNG có driver mới nhất cho GPU/chipset. WinCare không scrape trang hãng nên không nói "mới nhất" — mở trang chính thức để đối chiếu.'
    'm3.gpu.none' = 'Không đọc được thông tin GPU (hoặc máy không có GPU nào được liệt kê).'
    'm3.gpu.current' = 'Driver hiện tại'
    'm3.gpu.smi' = 'nvidia-smi báo phiên bản: {0}'
    'm3.gpu.status' = 'Không xác định (mở trang hãng để kiểm tra)'
    'm3.gpu.open' = 'Mở trang tải driver chính thức'
    'm3.oem.vendor' = 'Hãng máy'
    'm3.oem.model' = 'Model'
    'm3.oem.serial' = 'Service tag / Số serial'
    'm3.oem.advice' = 'Máy {0}: nên ưu tiên driver OEM đã kiểm định — driver Intel/AMD "generic" có thể không cài được trên máy OEM.'
    'm3.oem.open' = 'Mở trang hỗ trợ {0}'
    'm3.oem.dell.scan' = 'Quét bằng Dell Command Update'
    'm3.oem.dell.note' = 'WinCare chỉ chạy /scan (đọc danh sách). KHÔNG tự chạy /applyUpdates — lệnh đó chỉ hiện ở chế độ chuyên gia để bạn tự sao chép nếu muốn.'
    'm3.bios.version' = 'BIOS / Firmware'
    'm3.bios.date' = 'Ngày phát hành'
    'm3.bios.warn' = 'WinCare KHÔNG tự cài BIOS. Nếu bạn tự cập nhật: cắm sạc, pin ≥ 50%, và tuyệt đối không tắt máy giữa chừng.'
    # --- Tat ca driver ---
    'm3.all.title' = 'Tất cả driver'
    'm3.all.hint' = 'Kiểm kê chỉ-đọc toàn bộ driver đang cài trên máy. Lọc theo nhóm hoặc tìm theo tên thiết bị/hãng.'
    'm3.all.col.device' = 'Thiết bị'
    'm3.all.col.maker' = 'Hãng'
    'm3.all.col.version' = 'Phiên bản'
    'm3.all.col.date' = 'Ngày'
    'm3.all.col.group' = 'Nhóm'
    'm3.all.count' = '{0} / {1} driver'
    'm3.all.fail' = 'Không đọc được kiểm kê driver: {0}'
    'm3.group.all' = 'Tất cả'
    'm3.group.display' = 'Màn hình'
    'm3.group.net' = 'Mạng'
    'm3.group.media' = 'Âm thanh'
    'm3.group.processor' = 'CPU'
    'm3.group.system' = 'Chipset'
    'm3.group.bluetooth' = 'Bluetooth'
    'm3.group.storage' = 'Lưu trữ'
    'm3.group.image' = 'Máy quét / Camera'
    'm3.group.other' = 'Khác'
    # --- Sao luu & khoi phuc ---
    'm3.backup.title' = 'Sao lưu & Khôi phục'
    'm3.backup.hint' = 'Xuất toàn bộ driver hiện tại (Export-WindowsDriver) — đường lui trước khi cài driver mới.'
    'm3.backup.run' = 'Sao lưu toàn bộ driver hiện tại'
    'm3.backup.running' = 'Đang xuất driver (thao tác DISM, có thể mất vài phút)…'
    'm3.backup.done' = 'Đã sao lưu {0} gói driver vào: {1}'
    'm3.backup.fail' = 'Sao lưu driver thất bại'
    'm3.backup.exists' = 'Hôm nay đã có bản sao lưu: {0}'
    'm3.backup.empty' = 'Chưa có bản sao lưu nào. Nên sao lưu trước khi cài driver mới.'
    'm3.backup.restore' = 'Hướng dẫn khôi phục'
    'm3.backup.restore.title' = 'Khôi phục driver từ bản sao lưu'
    'm3.backup.restore.msg' = "Cách khôi phục driver từ bản sao lưu:`n`n1. Mở PowerShell với quyền Administrator.`n`n2. Cài lại toàn bộ file .inf trong thư mục:`n    pnputil /add-driver `"{0}\*.inf`" /subdirs /install`n`n3. Hoặc cài từng file:`n    pnputil /add-driver `"<đường-dẫn-đến-file.inf>`" /install`n`n4. Cách khác: Device Manager → chuột phải thiết bị → Properties → Driver → Roll Back Driver (về driver ngay trước đó), hoặc Update driver → Browse → trỏ tới thư mục sao lưu."
    # --- Ma loi thiet bi (diem dan) ---
    'm3.err.unknown' = 'Mã lỗi {0} — xem chi tiết trong Device Manager.'
    'm3.err.1' = 'Thiết bị chưa được cấu hình đúng — thường là thiếu hoặc sai driver.'
    'm3.err.10' = 'Thiết bị không khởi động được — driver có thể bị lỗi.'
    'm3.err.12' = 'Thiếu tài nguyên cho thiết bị (xung đột phần cứng).'
    'm3.err.14' = 'Cần khởi động lại máy để thiết bị hoạt động.'
    'm3.err.18' = 'Cần cài lại driver: gỡ thiết bị trong Device Manager rồi quét thay đổi phần cứng.'
    'm3.err.19' = 'Windows báo registry của thiết bị có thể bị hỏng (Code 19).'
    'm3.err.21' = 'Windows đang tháo gỡ thiết bị — chờ một lúc rồi quét lại.'
    'm3.err.22' = 'Thiết bị đang bị TẮT — bật lại trong Device Manager.'
    'm3.err.24' = 'Thiết bị không hiện diện, bị lỗi hoặc thiếu driver — cài lại driver hoặc kiểm tra phần cứng.'
    'm3.err.28' = 'Chưa cài driver cho thiết bị — đây là thiết bị cần driver nhất.'
    'm3.err.31' = 'Thiết bị không hoạt động đúng vì Windows không nạp được driver cần thiết.'
    'm3.err.37' = 'Khởi động lại máy để hoàn tất cấu hình thiết bị.'
    'm3.err.39' = 'Driver của thiết bị bị hỏng hoặc thiếu thành phần đi kèm.'
    'm3.err.43' = 'Thiết bị báo lỗi phần cứng — tắt máy, rút thiết bị (nếu tháo được) rồi cắm lại; vẫn lỗi thì phần cứng có vấn đề.'
    'm3.err.45' = 'Thiết bị hiện KHÔNG được kết nối (đã rút ra hoặc tắt trong BIOS).'
    'm3.err.52' = 'Windows không xác minh được chữ ký số của driver (Code 52).'
    # --- Journal ---
    'm3.journal.backup' = 'Sao lưu driver'
    'm3.journal.install' = 'Cài driver (Windows Update)'
}
Register-WCStrings 'en' @{
    'm3.title' = 'Drivers'
    'm3.subtitle' = 'Scan and get the right drivers for this PC — honest about "latest"'
    'm3.fact' = 'There is no common API for "the latest driver for every hardware". WinCare inventories your PC (read-only), checks official sources (Windows Update, vendor pages) and does NOT scrape vendor sites — so it never claims "latest" without a source to compare. An old driver is not a bad driver.'
    'm3.rescan' = 'Rescan'
    'm3.devmgr' = 'Open Device Manager'
    'm3.scan.inventory' = 'Inventorying drivers (can be slow on some PCs)…'
    'm3.scan.problems' = 'Checking problem devices…'
    'm3.scan.system' = 'Reading GPU / OEM / BIOS info…'
    'm3.scan.backup' = 'Reading backup list…'
    'm3.updates.title' = 'Available updates (Windows Update)'
    'm3.updates.hint' = 'Official Microsoft source, signed drivers. Nothing is pre-ticked — pick yourself, then install.'
    'm3.updates.searching' = 'Searching Windows Update for driver updates (may take minutes; press Cancel to skip waiting)…'
    'm3.updates.wsus' = 'This PC is managed by WSUS/GPO — the update list may be incomplete. WinCare does not bypass your organization policy.'
    'm3.updates.empty' = 'No driver updates from Windows Update for this PC.'
    'm3.updates.fail' = 'Could not search for updates: {0}'
    'm3.updates.install' = 'Download and install selected'
    'm3.updates.install.confirm.title' = 'Install drivers via Windows Update?'
    'm3.updates.install.confirm.msg' = "Will download and install {0} driver item(s) via Windows Update:`n`n{1}`n`nBefore installing, WinCare will automatically:`n• Back up all current drivers (if no backup today)`n• Try to create a system restore point"
    'm3.updates.install.confirm.noundo' = 'Old drivers can be restored from the backup (pnputil) or rolled back via Device Manager — Windows will not auto-undo.'
    'm3.install.backup' = 'Backing up current drivers…'
    'm3.install.restorepoint' = 'Creating a system restore point…'
    'm3.install.searching' = 'Re-finding selected items in Windows Update…'
    'm3.install.download' = 'Downloading {0}/{1}: {2}'
    'm3.install.installing' = 'Installing {0} driver item(s)…'
    'm3.restorepoint.fail.title' = 'Could not create a restore point'
    'm3.restorepoint.fail.msg' = 'Could not create a restore point (System Protection may be off).{0}WinCare does NOT turn on System Protection by itself.{0}Continue installing drivers without a restore point?'
    'm3.result.dryrun' = 'DRY-RUN: would download and install {0} driver item(s).'
    'm3.result.ok' = 'Installed {0} driver item(s).'
    'm3.result.failed' = 'Could not install: {0}'
    'm3.result.skipped' = 'Skipped (not found again): {0}'
    'm3.result.download.fail' = 'Could not download: {0}'
    'm3.result.cancelled' = 'Stopped on request — intermediate results were discarded.'
    'm3.result.reboot' = 'A restart is required to finish.'
    'm3.result.backup.new' = 'Old drivers backed up to: {0}'
    'm3.result.backup.today' = 'A backup from today already exists: {0}'
    'm3.result.restorepoint.ok' = 'Restore point "WinCare before driver install" created.'
    'm3.result.restorepoint.skip' = 'Installed at your choice: restore point skipped.'
    'm3.result.search.fail' = 'Could not re-search updates: {0}'
    'm3.result.fixture' = 'FIXTURE mode (fake data) — real install disabled.'
    'm3.result.nomatch' = 'No selected item matched Windows Update again (the list may have changed) — rescan.'
    'm3.problems.title' = 'Problem devices'
    'm3.problems.hint' = 'Devices reporting errors in Device Manager — handle these first.'
    'm3.problems.empty' = 'No problem devices — good.'
    'm3.problems.count' = '{0} problem device(s)'
    'm3.problems.fail' = 'Could not read problem devices: {0}'
    'm3.problems.col.device' = 'Device'
    'm3.problems.col.code' = 'Code'
    'm3.problems.col.meaning' = 'Meaning'
    'm3.oem.title' = 'GPU / OEM PC / BIOS'
    'm3.oem.hint' = 'Windows Update often does NOT have the latest GPU/chipset drivers. WinCare does not scrape vendor sites, so it never claims "latest" — open the official page to compare.'
    'm3.gpu.none' = 'No GPU info could be read (or no GPU listed).'
    'm3.gpu.current' = 'Current driver'
    'm3.gpu.smi' = 'nvidia-smi reports version: {0}'
    'm3.gpu.status' = 'Unknown (open vendor page to check)'
    'm3.gpu.open' = 'Open official driver download page'
    'm3.oem.vendor' = 'Manufacturer'
    'm3.oem.model' = 'Model'
    'm3.oem.serial' = 'Service tag / Serial number'
    'm3.oem.advice' = 'This is a {0} PC: prefer the OEM-validated drivers — generic Intel/AMD drivers may not install on OEM machines.'
    'm3.oem.open' = 'Open {0} support page'
    'm3.oem.dell.scan' = 'Scan with Dell Command Update'
    'm3.oem.dell.note' = 'WinCare only runs /scan (read-only list). It does NOT run /applyUpdates — that command is shown in expert mode for you to copy if you want.'
    'm3.bios.version' = 'BIOS / Firmware'
    'm3.bios.date' = 'Release date'
    'm3.bios.warn' = 'WinCare does NOT flash BIOS itself. If you update it manually: plug in the charger, keep battery ≥ 50%, and never power off midway.'
    'm3.all.title' = 'All drivers'
    'm3.all.hint' = 'Read-only inventory of every driver installed on this PC. Filter by group or search by device/vendor.'
    'm3.all.col.device' = 'Device'
    'm3.all.col.maker' = 'Vendor'
    'm3.all.col.version' = 'Version'
    'm3.all.col.date' = 'Date'
    'm3.all.col.group' = 'Group'
    'm3.all.count' = '{0} / {1} drivers'
    'm3.all.fail' = 'Could not read driver inventory: {0}'
    'm3.group.all' = 'All'
    'm3.group.display' = 'Display'
    'm3.group.net' = 'Network'
    'm3.group.media' = 'Audio'
    'm3.group.processor' = 'CPU'
    'm3.group.system' = 'Chipset'
    'm3.group.bluetooth' = 'Bluetooth'
    'm3.group.storage' = 'Storage'
    'm3.group.image' = 'Scanner / Camera'
    'm3.group.other' = 'Other'
    'm3.backup.title' = 'Backup & Restore'
    'm3.backup.hint' = 'Export all current drivers (Export-WindowsDriver) — your way back before installing new ones.'
    'm3.backup.run' = 'Back up all current drivers'
    'm3.backup.running' = 'Exporting drivers (DISM operation, may take minutes)…'
    'm3.backup.done' = 'Backed up {0} driver package(s) to: {1}'
    'm3.backup.fail' = 'Driver backup failed'
    'm3.backup.exists' = 'Today backup already exists: {0}'
    'm3.backup.empty' = 'No backups yet. Back up before installing new drivers.'
    'm3.backup.restore' = 'Restore guide'
    'm3.backup.restore.title' = 'Restore drivers from a backup'
    'm3.backup.restore.msg' = "How to restore drivers from a backup:`n`n1. Open PowerShell as Administrator.`n`n2. Reinstall every .inf in the folder:`n    pnputil /add-driver `"{0}\*.inf`" /subdirs /install`n`n3. Or one file at a time:`n    pnputil /add-driver `"<path-to-file.inf>`" /install`n`n4. Alternative: Device Manager → right-click device → Properties → Driver → Roll Back Driver (to the previous driver), or Update driver → Browse → point to the backup folder."
    'm3.err.unknown' = 'Error code {0} — see Device Manager for details.'
    'm3.err.1' = 'The device is not configured correctly — usually a missing or bad driver.'
    'm3.err.10' = 'The device cannot start — its driver may be faulty.'
    'm3.err.12' = 'Not enough free resources for the device (hardware conflict).'
    'm3.err.14' = 'A restart is required for the device to work.'
    'm3.err.18' = 'Reinstall the driver: uninstall the device in Device Manager, then scan for hardware changes.'
    'm3.err.19' = 'Windows reports the device registry may be corrupted (Code 19).'
    'm3.err.21' = 'Windows is removing the device — wait a moment and rescan.'
    'm3.err.22' = 'The device is DISABLED — re-enable it in Device Manager.'
    'm3.err.24' = 'The device is missing, faulty, or lacks drivers — reinstall the driver or check the hardware.'
    'm3.err.28' = 'No driver is installed for this device — the top candidate needing a driver.'
    'm3.err.31' = 'The device does not work because Windows cannot load the required drivers.'
    'm3.err.37' = 'Restart the computer to finish configuring the device.'
    'm3.err.39' = 'The device driver is corrupt or missing components.'
    'm3.err.43' = 'The device reported a hardware problem — power off, unplug it (if removable), plug back in; if the error persists the hardware may be faulty.'
    'm3.err.45' = 'The device is currently NOT connected (unplugged or disabled in BIOS).'
    'm3.err.52' = 'Windows cannot verify the digital signature of the driver (Code 52).'
    'm3.journal.backup' = 'Back up drivers'
    'm3.journal.install' = 'Install drivers (Windows Update)'
}

# ---------------------------------------------------------------------------
# DATA LAYER (Get-*/Invoke-* thuan, moi nguon co try/cach rieng - spec 2.3)
# ---------------------------------------------------------------------------
function Get-WCDriverBackupRoot {
    # Thu muc chua backup driver. Dung Get-WCState de hoat dong ca trong
    # worker runspace (bien $Script:WcName khong nap vao worker).
    $name = (Get-WCState 'WcName')
    if (-not $name) { $name = 'WinCare' }
    $pd = $env:ProgramData
    if (-not $pd) { $pd = [Environment]::GetFolderPath('CommonApplicationData') }
    if (-not $pd) { return '' }   # moi truong la (khong Windows) -> de caller xu ly
    return (Join-Path $pd (Join-Path $name 'backups'))
}

function Get-WCDriverGroup {
    # Doi chieu DeviceClass (ten hoac GUID) sang nhom tieng Viet.
    # Tra hashtable @{ Key = 'display'...; Text = 'Man hinh' }
    param([string]$Class)
    $c = ''
    if ($Class) { $c = $Class.Trim().ToUpperInvariant() }
    $key = 'other'
    switch ($c) {
        'DISPLAY'     { $key = 'display' }
        'MONITOR'     { $key = 'display' }
        'NET'         { $key = 'net' }
        'MEDIA'       { $key = 'media' }
        'PROCESSOR'   { $key = 'processor' }
        'SYSTEM'      { $key = 'system' }
        'BLUETOOTH'   { $key = 'bluetooth' }
        'HDC'         { $key = 'storage' }
        'SCSIADAPTER' { $key = 'storage' }
        'USB'         { $key = 'storage' }
        'DISKDRIVE'   { $key = 'storage' }
        'IMAGE'       { $key = 'image' }
    }
    # Mot so may tra ve GUID thay vi ten class -> doi chieu bang GUID
    if (($key -eq 'other') -and ($c -like '{*')) {
        $guidMap = @{
            '{4D36E968-E325-11CE-BFC1-08002BE10318}' = 'display'
            '{4D36E96E-E325-11CE-BFC1-08002BE10318}' = 'display'
            '{4D36E972-E325-11CE-BFC1-08002BE10318}' = 'net'
            '{4D36E96C-E325-11CE-BFC1-08002BE10318}' = 'media'
            '{50127DC3-0F36-415C-A0CC-4CB4EA2B236E}' = 'processor'
            '{4D36E97D-E325-11CE-BFC1-08002BE10318}' = 'system'
            '{E0CBF06C-CD8B-4647-BB8A-263B43F0F974}' = 'bluetooth'
            '{4D36E96A-E325-11CE-BFC1-08002BE10318}' = 'storage'
            '{4D36E97B-E325-11CE-BFC1-08002BE10318}' = 'storage'
            '{36FC9E60-C465-11CF-8056-444553540000}' = 'storage'
            '{4D36E967-E325-11CE-BFC1-08002BE10318}' = 'storage'
            '{6BDD1FC6-810F-11D0-BEC7-08002BE2092F}' = 'image'
        }
        if ($guidMap.ContainsKey($c)) { $key = $guidMap[$c] }
    }
    $text = ''
    switch ($key) {
        'display'   { $text = (T 'm3.group.display') }
        'net'       { $text = (T 'm3.group.net') }
        'media'     { $text = (T 'm3.group.media') }
        'processor' { $text = (T 'm3.group.processor') }
        'system'    { $text = (T 'm3.group.system') }
        'bluetooth' { $text = (T 'm3.group.bluetooth') }
        'storage'   { $text = (T 'm3.group.storage') }
        'image'     { $text = (T 'm3.group.image') }
        default     { $text = (T 'm3.group.other') }
    }
    return @{ Key = $key; Text = $text }
}

function Get-WCDriverErrorCode {
    # Dien giai ma loi ConfigManagerErrorCode bang tieng Viet de hieu.
    # Ma khong co trong bang -> "Ma loi X - xem Device Manager" (spec M3).
    param([Parameter(Mandatory)][int]$Code)
    $map = @{
        1  = (T 'm3.err.1');  10 = (T 'm3.err.10'); 12 = (T 'm3.err.12')
        14 = (T 'm3.err.14'); 18 = (T 'm3.err.18'); 19 = (T 'm3.err.19')
        21 = (T 'm3.err.21'); 22 = (T 'm3.err.22'); 24 = (T 'm3.err.24')
        28 = (T 'm3.err.28'); 31 = (T 'm3.err.31'); 37 = (T 'm3.err.37')
        39 = (T 'm3.err.39'); 43 = (T 'm3.err.43'); 45 = (T 'm3.err.45')
        52 = (T 'm3.err.52')
    }
    if ($map.ContainsKey($Code)) { return $map[$Code] }
    return (T 'm3.err.unknown' @($Code))
}

function Get-WCDriverInventory {
    # Lop 1: kiem ke toan bo driver (Win32_PnPSignedDriver - CHAM tren vai may,
    # bat buoc goi trong worker nen + cache dai 600s). Tra New-WCResult,
    # Data = mang dong chuan hoa (Get-WCProp cho moi thuoc tinh).
    $r = Invoke-WCQuery -Key 'drivers.inventory' -CacheTtlSec 600 -Script {
        Get-CimInstance -ClassName Win32_PnPSignedDriver -Property DeviceName,DriverVersion,DriverDate,Manufacturer,HardWareID,InfName,DeviceClass -OperationTimeoutSec 120 -ErrorAction Stop
    }
    if ($r.Status -ne 'Ok') { return $r }
    $rows = @()
    foreach ($d in @($r.Data)) {
        if ($null -eq $d) { continue }
        $name = [string](Get-WCProp $d 'DeviceName')
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        # Ngay phat hanh (CIM datetime hoac chuoi tu FIXTURE)
        $dateText = '—'
        $dd = Get-WCProp $d 'DriverDate'
        if ($null -ne $dd) {
            try {
                if ($dd -is [DateTime]) { $dateText = $dd.ToString('yyyy-MM-dd') }
                else { $dateText = ([DateTime]::Parse([string]$dd)).ToString('yyyy-MM-dd') }
            } catch {
                $s3 = ([string]$dd).Trim()
                if ($s3) { $dateText = $s3 }
            }
        }
        # HardWareID co the la mang tren mot so may
        $hw = Get-WCProp $d 'HardWareID'
        $hwText = ''
        if ($hw -is [array]) { $hwText = [string]::Join(';', @($hw)) }
        else { $hwText = [string]$hw }
        $cls = [string](Get-WCProp $d 'DeviceClass')
        $grp = Get-WCDriverGroup $cls
        $rows += [PSCustomObject]@{
            DeviceName     = $name
            DriverVersion  = ([string](Get-WCProp $d 'DriverVersion'))
            DriverDateText = $dateText
            Manufacturer   = ([string](Get-WCProp $d 'Manufacturer'))
            HardWareID     = $hwText
            InfName        = ([string](Get-WCProp $d 'InfName'))
            DeviceClass    = $cls
            Group          = $grp.Text
            GroupKey       = $grp.Key
        }
    }
    $rows = @($rows | Sort-Object -Property DeviceName)
    return (New-WCResult -Status 'Ok' -Data $rows)
}

function Get-WCDriverProblemDevices {
    # Lop 1: thiet bi dang bao loi (ConfigManagerErrorCode != 0) + dien giai.
    $r = Invoke-WCQuery -Key 'drivers.problems' -CacheTtlSec 600 -Script {
        Get-CimInstance -ClassName Win32_PnPEntity -Property Name,DeviceID,ConfigManagerErrorCode,PNPClass -OperationTimeoutSec 30 -ErrorAction Stop
    }
    if ($r.Status -ne 'Ok') { return $r }
    $rows = @()
    foreach ($e in @($r.Data)) {
        if ($null -eq $e) { continue }
        $code = Get-WCProp $e 'ConfigManagerErrorCode'
        if ($null -eq $code) { continue }
        $codeInt = 0
        try { $codeInt = [int]$code } catch { continue }
        if ($codeInt -eq 0) { continue }
        $name = [string](Get-WCProp $e 'Name')
        if ([string]::IsNullOrWhiteSpace($name)) { $name = (T 'common.unknown') }
        $rows += [PSCustomObject]@{
            Name      = $name
            DeviceID  = ([string](Get-WCProp $e 'DeviceID'))
            Code      = $codeInt
            Meaning   = (Get-WCDriverErrorCode $codeInt)
            ClassName = ([string](Get-WCProp $e 'PNPClass'))
        }
    }
    return (New-WCResult -Status 'Ok' -Data $rows)
}

function Get-WCDriverComProp {
    # Doc thuoc tinh COM (WUA) an toan: thu qua PSObject roi thu truy cap truc tiep
    param($Obj, [Parameter(Mandatory)][string]$Name)
    if ($null -eq $Obj) { return $null }
    $v = Get-WCProp $Obj $Name
    if ($null -ne $v) { return $v }
    try { return $Obj.$Name } catch { return $null }
}

function Get-WCNvidiaFriendlyVersion {
    # Dinh dang phien ban kieu NVIDIA: '31.0.15.3758' -> '537.58'
    # (lay 5 chu so cuoi cua phan 3+4, cham truoc 2 so cuoi - quy uoc cua hang).
    param([string]$RawVersion)
    if ([string]::IsNullOrWhiteSpace($RawVersion)) { return '' }
    try {
        $parts = $RawVersion.Split('.')
        $combined = ''
        if ($parts.Count -ge 3) {
            $combined = ([string]$parts[$parts.Count - 2]) + ([string]$parts[$parts.Count - 1])
        } else {
            $combined = [string]$parts[0]
        }
        $digits = $combined
        if ($combined.Length -gt 5) { $digits = $combined.Substring($combined.Length - 5) }
        if ($digits.Length -gt 2) {
            return ($digits.Substring(0, $digits.Length - 2) + '.' + $digits.Substring($digits.Length - 2))
        }
        return $digits
    } catch { return $RawVersion }
}

function Get-WCNvidiaSmiVersion {
    # Doi chieu phien bang nvidia-smi (dang --query-gpu co dinh, khong phai
    # output bi dia phuong hoa). Khong co thi tra '' (khong doan).
    $exe = ''
    try {
        $c = Get-Command 'nvidia-smi.exe' -ErrorAction Stop
        $exe = [string](Get-WCProp $c 'Source')
        if (-not $exe) { $exe = [string]$c.Source }
    } catch { }
    if (-not $exe) {
        $sysRoot = $env:SystemRoot
        if (-not $sysRoot) { $sysRoot = $env:windir }
        if ($sysRoot) {
            $p = Join-Path $sysRoot 'System32\nvidia-smi.exe'
            if (Test-Path -LiteralPath $p) { $exe = $p }
        }
    }
    if (-not $exe) { return '' }
    try {
        $out = @(& $exe '--query-gpu=driver_version' '--format=csv,noheader' 2>$null)
        foreach ($line in $out) {
            $t = ([string]$line).Trim()
            if ($t) { return $t }
        }
    } catch { }
    return ''
}

function Get-WCGpuVendorUrl {
    # URL trang tai driver CHINH THUC theo hang (khong scrape - chi mo trang).
    param([string]$VendorName)
    switch ($VendorName) {
        'NVIDIA' { return 'https://www.nvidia.com/Download/index.aspx' }
        'AMD'    { return 'https://www.amd.com/en/support' }
        'Intel'  { return 'https://www.intel.com/content/www/us/en/download-center/home.html' }
    }
    return ''
}

function Get-WCDriverGpus {
    # Nhan hang GPU qua PCI VEN trong HardWareID (uu tien PnPSignedDriver,
    # fallback Win32_VideoController). KHONG noi "moi nhat" - chi hien
    # phien ban hien tai va trang thai "Khong xac dinh" (spec M3 lop 3).
    param($Inventory)
    $venMap = @{ '10DE' = 'NVIDIA'; '8086' = 'Intel'; '1002' = 'AMD' }
    $smiVersion = (Get-WCNvidiaSmiVersion)
    $gpus = @()
    foreach ($d in @($Inventory)) {
        if ($null -eq $d) { continue }
        $cls = ([string](Get-WCProp $d 'DeviceClass')).Trim().ToUpperInvariant()
        if ($cls -ne 'DISPLAY') { continue }
        $hwid = [string](Get-WCProp $d 'HardWareID')
        $ven = ''
        if ($hwid -match 'VEN_([0-9A-Fa-f]{4})') { $ven = $Matches[1].ToUpperInvariant() }
        $vendorName = ''
        if ($venMap.ContainsKey($ven)) { $vendorName = $venMap[$ven] }
        $raw = [string](Get-WCProp $d 'DriverVersion')
        $friendly = ''
        if ($vendorName -eq 'NVIDIA') { $friendly = Get-WCNvidiaFriendlyVersion $raw }
        $gpus += [PSCustomObject]@{
            Name            = [string](Get-WCProp $d 'DeviceName')
            Vendor          = $vendorName
            RawVersion      = $raw
            FriendlyVersion = $friendly
            DateText        = [string](Get-WCProp $d 'DriverDateText')
            SmiVersion      = $smiVersion
        }
    }
    # Fallback: khong co dong DISPLAY nao (thieu du lieu PnPSignedDriver)
    if ($gpus.Count -eq 0) {
        try {
            $r = Invoke-WCQuery -Key 'drivers.videoctrl' -CacheTtlSec 600 -Script {
                Get-CimInstance -ClassName Win32_VideoController -Property Name,DriverVersion,DriverDate,PNPDeviceID -OperationTimeoutSec 15 -ErrorAction Stop
            }
            foreach ($v in @($r.Data)) {
                if ($null -eq $v) { continue }
                $ven = ''
                $pnid = [string](Get-WCProp $v 'PNPDeviceID')
                if ($pnid -match 'VEN_([0-9A-Fa-f]{4})') { $ven = $Matches[1].ToUpperInvariant() }
                $vendorName = ''
                if ($venMap.ContainsKey($ven)) { $vendorName = $venMap[$ven] }
                $raw = [string](Get-WCProp $v 'DriverVersion')
                $friendly = ''
                if ($vendorName -eq 'NVIDIA') { $friendly = Get-WCNvidiaFriendlyVersion $raw }
                $dateText = '—'
                $dd = Get-WCProp $v 'DriverDate'
                try { if ($null -ne $dd) { $dateText = ([DateTime]$dd).ToString('yyyy-MM-dd') } } catch { }
                $gpus += [PSCustomObject]@{
                    Name            = [string](Get-WCProp $v 'Name')
                    Vendor          = $vendorName
                    RawVersion      = $raw
                    FriendlyVersion = $friendly
                    DateText        = $dateText
                    SmiVersion      = $smiVersion
                }
            }
        } catch { }
    }
    return $gpus
}

function Resolve-WCOemVendor {
    # Nhan diem hang OEM tu Manufacturer -> ten + URL trang ho tro chinh thuc
    param([string]$Manufacturer)
    if ([string]::IsNullOrWhiteSpace($Manufacturer)) { return $null }
    $m = $Manufacturer.ToLowerInvariant()
    if ($m -like '*dell*') {
        return [PSCustomObject]@{ Id = 'dell'; Name = 'Dell'; Url = 'https://www.dell.com/support' }
    }
    if (($m -like '*hewlett*') -or ($m -like '*hp*')) {
        return [PSCustomObject]@{ Id = 'hp'; Name = 'HP'; Url = 'https://support.hp.com' }
    }
    if ($m -like '*lenovo*') {
        return [PSCustomObject]@{ Id = 'lenovo'; Name = 'Lenovo'; Url = 'https://support.lenovo.com' }
    }
    if ($m -like '*asus*') {
        return [PSCustomObject]@{ Id = 'asus'; Name = 'ASUS'; Url = 'https://www.asus.com/support' }
    }
    return $null
}

function Get-WCDellUpdateCli {
    # Tim dcu-cli.exe (Dell Command Update) neu da cai - Get-Command hoac duong dan chuan
    foreach ($n in @('dcu-cli.exe', 'dcu-cli')) {
        try {
            $c = Get-Command $n -ErrorAction Stop
            $src = [string](Get-WCProp $c 'Source')
            if (-not $src) { $src = [string]$c.Source }
            if ($src) { return $src }
        } catch { }
    }
    $pf = $env:ProgramFiles
    if ($pf) {
        $p = Join-Path $pf 'Dell\CommandUpdate\dcu-cli.exe'
        if (Test-Path -LiteralPath $p) { return $p }
    }
    return ''
}

function Get-WCDriverWuPolicy {
    # Kiem tra may co dang quan ly bang WSUS/GPO khong (chi DOC, khong lanh).
    # Co WUServer / DisableWindowsUpdateAccess / UseWUServer=1 -> canh bao.
    $wuPath = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
    $server = Get-WCRegistryValue -Path $wuPath -Name 'WUServer'
    $disable = Get-WCRegistryValue -Path $wuPath -Name 'DisableWindowsUpdateAccess'
    $useWu = Get-WCRegistryValue -Path ($wuPath + '\AU') -Name 'UseWUServer'
    $managed = $false
    if ($server -or ($null -ne $disable) -or ($useWu -eq 1)) { $managed = $true }
    return [PSCustomObject]@{ Managed = $managed; Server = ([string]$server) }
}

function Invoke-WCDriverWuaSearch {
    # Lop 2: tim driver qua COM Windows Update (nguon chinh thuc, da ky).
    # Ep ServerSelection = 2 (Windows Update). Search cham -> chi goi trong worker.
    # Tra PSCustomObject: Status/Reason/Managed/ManagedServer/Updates.
    $policy = Get-WCDriverWuPolicy
    $out = [PSCustomObject]@{
        Status = 'Ok'; Reason = ''
        Managed = [bool]$policy.Managed; ManagedServer = [string]$policy.Server
        Updates = @()
    }
    $r = Invoke-WCQuery -Key 'drivers.wua' -NoCache -Script {
        # Toan bo COM nam trong 1 try duy nhat: loi mang/service -> Bad ro ly do
        $session = New-Object -ComObject Microsoft.Update.Session
        $searcher = $session.CreateUpdateSearcher()
        try { $searcher.ServerSelection = 2 } catch { }   # 2 = Windows Update
        $result = $searcher.Search("IsInstalled=0 and Type='Driver'")
        $list = @()
        foreach ($u in @($result.Updates)) {
            if ($null -eq $u) { continue }
            $mfr = [string](Get-WCDriverComProp $u 'DriverManufacturer')
            if ([string]::IsNullOrWhiteSpace($mfr)) { $mfr = '—' }
            $ver = [string](Get-WCDriverComProp $u 'DriverVerVersion')
            if ([string]::IsNullOrWhiteSpace($ver)) { $ver = '—' }
            $dateText = '—'
            $dv = (Get-WCDriverComProp $u 'DriverVerDate')
            if ($null -ne $dv) {
                $s2 = ([string]$dv).Trim()
                if ($s2) {
                    try { $dateText = ([DateTime]::Parse($s2)).ToString('yyyy-MM-dd') } catch { $dateText = $s2 }
                }
            }
            $sizeText = '—'
            $max = Get-WCDriverComProp $u 'MaxDownloadSize'
            try { if ($null -ne $max) { $sizeText = ConvertTo-WCHumanSize ([long]$max) } } catch { }
            $list += [PSCustomObject]@{
                Title        = [string](Get-WCDriverComProp $u 'Title')
                Manufacturer = $mfr
                Version      = $ver
                DateText     = $dateText
                SizeText     = $sizeText
                Class        = [string](Get-WCDriverComProp $u 'DriverClass')
            }
        }
        return $list
    }
    if ($r.Status -ne 'Ok') {
        $out.Status = 'Bad'
        $out.Reason = [string]$r.Reason
        return $out
    }
    $out.Updates = @($r.Data)
    return $out
}

function Get-WCDriverSystemInfo {
    # Thong tin he thong cho lop 3: hang/model/serial (OEM), BIOS, GPU.
    # Goi trong worker; moi nguon co try/catch rieng.
    param($Inventory)
    $info = [PSCustomObject]@{
        Manufacturer = ''; Model = ''; Serial = ''
        BiosVersion = ''; BiosDateText = ''
        Vendor = $null      # PSCustomObject @{ Id; Name; Url } hoac $null
        DellCli = ''
        Gpus = @()
    }
    try {
        $r = Invoke-WCQuery -Key 'drivers.computersystem' -CacheTtlSec 600 -Script {
            Get-CimInstance -ClassName Win32_ComputerSystem -Property Manufacturer,Model -OperationTimeoutSec 15 -ErrorAction Stop
        }
        if (($r.Status -eq 'Ok') -and $r.Data) {
            $info.Manufacturer = [string](Get-WCProp $r.Data 'Manufacturer')
            $info.Model = [string](Get-WCProp $r.Data 'Model')
        }
    } catch { }
    try {
        $r2 = Invoke-WCQuery -Key 'drivers.bios' -CacheTtlSec 600 -Script {
            Get-CimInstance -ClassName Win32_BIOS -Property SMBIOSBIOSVersion,ReleaseDate,SerialNumber -OperationTimeoutSec 15 -ErrorAction Stop
        }
        if (($r2.Status -eq 'Ok') -and $r2.Data) {
            $info.BiosVersion = [string](Get-WCProp $r2.Data 'SMBIOSBIOSVersion')
            $info.Serial = [string](Get-WCProp $r2.Data 'SerialNumber')
            $rd = Get-WCProp $r2.Data 'ReleaseDate'
            try {
                if ($null -ne $rd) {
                    if ($rd -is [DateTime]) { $info.BiosDateText = $rd.ToString('yyyy-MM-dd') }
                    else { $info.BiosDateText = ([DateTime]::Parse([string]$rd)).ToString('yyyy-MM-dd') }
                }
            } catch { }
        }
    } catch { }
    $info.Vendor = Resolve-WCOemVendor $info.Manufacturer
    if ($info.Vendor -and ((Get-WCProp $info.Vendor 'Id') -eq 'dell')) {
        $info.DellCli = (Get-WCDellUpdateCli)
    }
    $info.Gpus = @(Get-WCDriverGpus -Inventory $Inventory)
    return $info
}

function Get-WCDriverBackups {
    # Liem ke cac thu muc backup drivers-<ngay> co san
    $rows = @()
    try {
        $root = Get-WCDriverBackupRoot
        if (-not $root) { return $rows }
        if (-not (Test-Path -LiteralPath $root)) { return $rows }
        $dirs = @(Get-ChildItem -LiteralPath $root -Directory -Filter 'drivers-*' -ErrorAction Stop | Sort-Object -Property Name -Descending)
        foreach ($d in $dirs) {
            $infs = @(Get-ChildItem -LiteralPath $d.FullName -Filter '*.inf' -Recurse -ErrorAction SilentlyContinue)
            $bytes = (Get-WCDirSize $d.FullName)
            $rows += [PSCustomObject]@{
                Path     = $d.FullName
                Name     = $d.Name
                InfCount = $infs.Count
                SizeText = (ConvertTo-WCHumanSize $bytes)
            }
        }
    } catch { Write-WCLog 'WARN' ('Doc danh sach backup driver that bai: ' + $_.Exception.Message) }
    return $rows
}

function Invoke-WCDriverExportCore {
    # Chay Export-WindowsDriver cho 1 thu muc dich (dung cho nut "Sao luu"
    # va cho luong cai driver - muc B(a) cua spec M3).
    # Tra hashtable: Ok / Path / Count / Reason / DryRun.
    param([Parameter(Mandatory)][string]$Destination, $Ctx, [bool]$DryRun = $false)
    if ($DryRun) {
        if ($Ctx) { $Ctx.Log('[DRY-RUN] Export-WindowsDriver -Online -Destination ' + $Destination) }
        return @{ Ok = $true; Path = $Destination; Count = 0; Reason = ''; DryRun = $true }
    }
    try {
        # Nap module Dism (PS7 phai qua compat; PS5.1 nap thang)
        try {
            if ($PSVersionTable.PSEdition -eq 'Core') { Import-Module Dism -UseWindowsPowerShell -ErrorAction Stop }
            else { Import-Module Dism -ErrorAction Stop }
        } catch { }
        if (-not (Get-Command Export-WindowsDriver -ErrorAction SilentlyContinue)) {
            return @{ Ok = $false; Path = $Destination; Count = 0; Reason = 'Export-WindowsDriver khong kha dung (module Dism?)'; DryRun = $false }
        }
        if (-not (Test-Path -LiteralPath $Destination)) {
            New-Item -Path $Destination -ItemType Directory -Force | Out-Null
        }
        if ($Ctx) {
            if ($Ctx.Cancelled()) { return @{ Ok = $false; Path = $Destination; Count = 0; Reason = 'Cancelled'; DryRun = $false } }
            $Ctx.Log('Export-WindowsDriver -Online -Destination ' + $Destination)
        }
        $null = Export-WindowsDriver -Online -Destination $Destination -ErrorAction Stop
        $infs = @(Get-ChildItem -LiteralPath $Destination -Filter '*.inf' -Recurse -ErrorAction SilentlyContinue)
        return @{ Ok = $true; Path = $Destination; Count = $infs.Count; Reason = ''; DryRun = $false }
    } catch {
        return @{ Ok = $false; Path = $Destination; Count = 0; Reason = $_.Exception.Message; DryRun = $false }
    }
}

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
function Start-WCM3TaskWatch {
    # Don dep spinner khi task ket thuc, KE CA khi bi Huy (framework khong goi
    # Done khi task bi huy -> spinner se treo mai neu khong co watcher nay).
    param($State, [string]$TaskId, [string[]]$SpinnerKeys)
    $keys = @($SpinnerKeys)
    $timer = New-Object Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(500)
    $timer.Add_Tick({
        param($sender, $e)
        if (Test-WCTaskRunning $TaskId) { return }
        $sender.Stop()
        foreach ($k in $keys) {
            $sp = $State[$k]
            if ($sp -and ($sp.Visibility -eq [Windows.Visibility]::Visible)) {
                $sp.Visibility = [Windows.Visibility]::Collapsed
            }
        }
        # Task WUA bi huy khi chua co du lieu -> hien chu "da huy" cho ro
        if ($TaskId -eq 'm3.wua') {
            if ($State.UpdatesList -and ($State.UpdatesList.Children.Count -eq 0) -and
                $State.UpdatesStatus -and ($State.UpdatesStatus.Visibility -eq [Windows.Visibility]::Collapsed)) {
                $State.UpdatesStatus.Text = (T 'm3.result.cancelled')
                $State.UpdatesStatus.Visibility = [Windows.Visibility]::Visible
            }
        }
    }.GetNewClosure())
    $timer.Start()
    return $timer
}

function New-WCM3Panel {
    param($State)
    $root = New-Object Windows.Controls.ScrollViewer
    $root.VerticalScrollBarVisibility = [Windows.Controls.ScrollBarVisibility]::Auto
    $hostPanel = New-WCVStack -Spacing 14
    $hostPanel.Margin = (New-Object Windows.Thickness(20))
    $root.Content = $hostPanel

    # --- Tieu de + su that ---
    $titleRow = New-WCHStack
    $titleRow.Children.Add((New-WCHeading (T 'm3.title'))) | Out-Null
    $betaChip = New-WCChip -Text (T 'common.beta') -Kind 'Warn'
    $betaChip.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $titleRow.Children.Add($betaChip) | Out-Null
    Add-WCChild $hostPanel $titleRow
    Add-WCChild $hostPanel (New-WCSubtitle (T 'm3.subtitle'))
    Add-WCChild $hostPanel (New-WCTextBlock -Text (T 'm3.fact') -Size 12.5 -ColorKey 'WcSubtle' -Wrap)

    # --- Hang nut: Quet lai + Mo Device Manager ---
    $btnRow = New-WCHStack -Spacing 8
    $rescanBtn = New-WCButton -Text (T 'm3.rescan') -Kind Primary -OnClick { param($b) Invoke-WCM3Scan $State }.GetNewClosure()
    $devBtn = New-WCButton -Text (T 'm3.devmgr') -OnClick { param($b) try { Start-Process 'devmgmt.msc' } catch { Show-WCToast (T 'common.cannotopen') 'Warn' } }.GetNewClosure()
    Add-WCChild $btnRow $rescanBtn
    Add-WCChild $btnRow $devBtn
    Add-WCChild $hostPanel $btnRow

    # --- Section 1: Cap nhat co san (Windows Update) ---
    $updSec = New-WCSection -Title (T 'm3.updates.title') -Subtitle (T 'm3.updates.hint')
    $wsus = New-WCTextBlock -Text '' -Size 12.5 -ColorKey 'WcWarn' -Wrap
    $wsus.Visibility = [Windows.Visibility]::Collapsed
    $State.WsusBanner = $wsus
    Add-WCChild $updSec.Body $wsus
    $State.UpdatesSpinner = New-WCSpinner -Text (T 'm3.updates.searching')
    Add-WCChild $updSec.Body $State.UpdatesSpinner
    $State.UpdatesList = New-WCCheckList
    Add-WCChild $updSec.Body $State.UpdatesList
    $stText = New-WCTextBlock -Text '' -Size 12.5 -ColorKey 'WcSubtle' -Wrap
    $stText.Visibility = [Windows.Visibility]::Collapsed
    $State.UpdatesStatus = $stText
    Add-WCChild $updSec.Body $stText
    $instBtn = New-WCButton -Text (T 'm3.updates.install') -Kind Primary -Disabled -OnClick { param($b) Invoke-WCM3InstallSelected $State }.GetNewClosure()
    $instBtn.Margin = (New-Object Windows.Thickness(0,6,0,0))
    $State.InstallBtn = $instBtn
    Add-WCChild $updSec.Body $instBtn
    Add-WCChild $hostPanel $updSec.Root

    # --- Section 2: Thiet bi loi ---
    $probSec = New-WCSection -Title (T 'm3.problems.title') -Subtitle (T 'm3.problems.hint')
    $State.ProblemsSpinner = New-WCSpinner
    Add-WCChild $probSec.Body $State.ProblemsSpinner
    $State.ProblemsHost = New-WCVStack -Spacing 8
    Add-WCChild $probSec.Body $State.ProblemsHost
    Add-WCChild $hostPanel $probSec.Root

    # --- Section 3: GPU / OEM / BIOS ---
    $sysSec = New-WCSection -Title (T 'm3.oem.title') -Subtitle (T 'm3.oem.hint')
    $State.SysSpinner = New-WCSpinner
    Add-WCChild $sysSec.Body $State.SysSpinner
    $State.GpuHost = New-WCVStack -Spacing 8
    $State.OemHost = New-WCVStack -Spacing 8
    $State.BiosHost = New-WCVStack -Spacing 8
    Add-WCChild $sysSec.Body $State.GpuHost
    Add-WCChild $sysSec.Body $State.OemHost
    Add-WCChild $sysSec.Body $State.BiosHost
    Add-WCChild $hostPanel $sysSec.Root

    # --- Section 4: Tat ca driver (tim kiem + loc nhom + bang) ---
    $allSec = New-WCSection -Title (T 'm3.all.title') -Subtitle (T 'm3.all.hint')
    $filterRow = New-WCHStack -Spacing 8
    $search = New-WCSearchBox -OnChanged {
        param($box)
        $State.SearchText = [string]$box.Text
        Update-WCM3DriverTable $State
    }.GetNewClosure()
    Add-WCChild $filterRow $search
    $State.DriverCount = New-WCTextBlock -Text '' -Size 12 -ColorKey 'WcSubtle'
    $State.DriverCount.VerticalAlignment = [Windows.VerticalAlignment]::Center
    Add-WCChild $filterRow $State.DriverCount
    Add-WCChild $allSec.Body $filterRow
    $State.ChipHost = New-Object Windows.Controls.WrapPanel
    Add-WCChild $allSec.Body $State.ChipHost
    $State.DriverTable = New-WCTable -Columns @(
        @{ Header = (T 'm3.all.col.device');  Prop = 'Device';  Width = 250 }
        @{ Header = (T 'm3.all.col.maker');   Prop = 'Maker';   Width = 160 }
        @{ Header = (T 'm3.all.col.version'); Prop = 'Version'; Width = 110 }
        @{ Header = (T 'm3.all.col.date');    Prop = 'Date';    Width = 90 }
        @{ Header = (T 'm3.all.col.group');   Prop = 'Group';   Width = 110 }
    )
    $State.DriverTable.MaxHeight = 440
    Add-WCChild $allSec.Body $State.DriverTable
    $allStatus = New-WCTextBlock -Text '' -Size 12.5 -ColorKey 'WcSubtle' -Wrap
    $allStatus.Visibility = [Windows.Visibility]::Collapsed
    $State.AllStatus = $allStatus
    Add-WCChild $allSec.Body $allStatus
    Add-WCChild $hostPanel $allSec.Root

    # --- Section 5: Sao luu & Khoi phuc ---
    $bakSec = New-WCSection -Title (T 'm3.backup.title') -Subtitle (T 'm3.backup.hint')
    $bakBtn = New-WCButton -Text (T 'm3.backup.run') -Kind Primary -OnClick { param($b) Invoke-WCM3BackupNow $State }.GetNewClosure()
    Add-WCChild $bakSec.Body $bakBtn
    $State.BackupSpinner = New-WCSpinner -Text (T 'm3.backup.running')
    $State.BackupSpinner.Visibility = [Windows.Visibility]::Collapsed
    Add-WCChild $bakSec.Body $State.BackupSpinner
    $State.BackupHost = New-WCVStack -Spacing 6
    Add-WCChild $bakSec.Body $State.BackupHost
    Add-WCChild $hostPanel $bakSec.Root

    # Khoi tao hang chip loc nhom
    Update-WCM3GroupChips $State
    return $root
}

function Update-WCM3GroupChips {
    # Hang nut loc theo nhom (tu dung thay cho combobox - spec M3 muc E)
    param($State)
    if (-not $State.ChipHost) { return }
    $chipHostPanel = $State.ChipHost
    $chipHostPanel.Children.Clear()
    $defs = @(
        @{ Key = 'all';       Label = (T 'm3.group.all') }
        @{ Key = 'display';   Label = (T 'm3.group.display') }
        @{ Key = 'net';       Label = (T 'm3.group.net') }
        @{ Key = 'media';     Label = (T 'm3.group.media') }
        @{ Key = 'processor'; Label = (T 'm3.group.processor') }
        @{ Key = 'system';    Label = (T 'm3.group.system') }
        @{ Key = 'bluetooth'; Label = (T 'm3.group.bluetooth') }
        @{ Key = 'storage';   Label = (T 'm3.group.storage') }
        @{ Key = 'other';     Label = (T 'm3.group.other') }
    )
    foreach ($d in $defs) {
        $kind = 'Normal'
        if ($State.GroupFilter -eq $d.Key) { $kind = 'Primary' }
        $gkey = $d.Key
        $btn = New-WCButton -Text ([string]$d.Label) -Kind $kind -Small -OnClick {
            param($b)
            $State.GroupFilter = $gkey
            Update-WCM3GroupChips $State
            Update-WCM3DriverTable $State
        }.GetNewClosure()
        $btn.Margin = (New-Object Windows.Thickness(0,0,6,6))
        $chipHostPanel.Children.Add($btn) | Out-Null
    }
}

function Update-WCM3DriverTable {
    # Do lai bang "Tat ca driver" theo loc nhom + chuoi tim kiem
    param($State)
    if (-not $State.DriverTable) { return }
    $table = $State.DriverTable
    $table.Items.Clear()
    $q = ''
    if ($State.SearchText) { $q = ([string]$State.SearchText).Trim().ToLowerInvariant() }
    $shown = 0
    $total = @($State.Inventory).Count
    foreach ($d in @($State.Inventory)) {
        if ($null -eq $d) { continue }
        $gk = [string](Get-WCProp $d 'GroupKey')
        if (($State.GroupFilter -ne 'all') -and ($gk -ne $State.GroupFilter)) { continue }
        if ($q) {
            $hay = (([string](Get-WCProp $d 'DeviceName')) + ' ' + ([string](Get-WCProp $d 'Manufacturer')) + ' ' + ([string](Get-WCProp $d 'InfName'))).ToLowerInvariant()
            if (-not ($hay -like ('*' + $q + '*'))) { continue }
        }
        $row = [PSCustomObject]@{
            Device  = [string](Get-WCProp $d 'DeviceName')
            Maker   = [string](Get-WCProp $d 'Manufacturer')
            Version = [string](Get-WCProp $d 'DriverVersion')
            Date    = [string](Get-WCProp $d 'DriverDateText')
            Group   = [string](Get-WCProp $d 'Group')
        }
        $table.Items.Add($row) | Out-Null
        $shown++
    }
    $State.DriverCount.Text = (T 'm3.all.count' @($shown, $total))
}

function Update-WCM3UpdatesUi {
    # Do du lieu vao section "Cap nhat co san" (danh sach tick, KHONG tick san)
    param($State, $Result)
    $State.UpdatesSpinner.Visibility = [Windows.Visibility]::Collapsed
    Clear-WCCheckList $State.UpdatesList
    $State.InstallBtn.IsEnabled = $false
    if ($null -eq $Result) {
        $State.UpdatesStatus.Text = (T 'm3.result.cancelled')
        $State.UpdatesStatus.Visibility = [Windows.Visibility]::Visible
        return
    }
    if ([bool](Get-WCProp $Result 'Managed')) {
        $State.WsusBanner.Text = (T 'm3.updates.wsus')
        $State.WsusBanner.Visibility = [Windows.Visibility]::Visible
    }
    if ([string](Get-WCProp $Result 'Status') -eq 'Bad') {
        # Khong mang / service WU tat / loi COM -> kiem ke van hien day du (spec M3)
        $State.UpdatesStatus.Text = (T 'm3.updates.fail' @([string](Get-WCProp $Result 'Reason')))
        $State.UpdatesStatus.Visibility = [Windows.Visibility]::Visible
        return
    }
    $updates = @(Get-WCProp $Result 'Updates')
    if ($updates.Count -eq 0) {
        $State.UpdatesStatus.Text = (T 'm3.updates.empty')
        $State.UpdatesStatus.Visibility = [Windows.Visibility]::Visible
        return
    }
    foreach ($u in $updates) {
        if ($null -eq $u) { continue }
        $grp = Get-WCDriverGroup ([string](Get-WCProp $u 'Class'))
        # Nhom quan trong (GPU/chipset) danh dau Warn de nguoi dung chu y - van KHONG tick san
        $chipKind = 'Plain'
        if (($grp.Key -eq 'display') -or ($grp.Key -eq 'system')) { $chipKind = 'Warn' }
        Add-WCCheckRow -List $State.UpdatesList -Item $u -Checked:$false -TextColumns @(
            ([string](Get-WCProp $u 'Title')),
            ([string](Get-WCProp $u 'Manufacturer')),
            ([string](Get-WCProp $u 'Version')),
            ([string](Get-WCProp $u 'DateText')),
            ([string](Get-WCProp $u 'SizeText'))
        ) -ChipText ([string]$grp.Text) -ChipKind $chipKind
    }
    $State.InstallBtn.IsEnabled = $true
}

function Update-WCM3ProblemsUi {
    # Do du lieu vao section "Thiet bi loi" (bang: thiet bi | ma loi | y nghia)
    param($State, [string]$Status, [string]$Reason, $Rows)
    $State.ProblemsSpinner.Visibility = [Windows.Visibility]::Collapsed
    $State.ProblemsHost.Children.Clear()
    if ($Status -ne 'Ok') {
        Add-WCChild $State.ProblemsHost (New-WCTextBlock -Text (T 'm3.problems.fail' @($Reason)) -ColorKey 'WcBad' -Wrap)
        return
    }
    $rows = @($Rows)
    if ($rows.Count -eq 0) {
        Add-WCChild $State.ProblemsHost (New-WCTextBlock -Text (T 'm3.problems.empty') -ColorKey 'WcSubtle' -Wrap)
        return
    }
    Add-WCChild $State.ProblemsHost (New-WCChip -Text (T 'm3.problems.count' @($rows.Count)) -Kind 'Bad')
    $table = New-WCTable -Columns @(
        @{ Header = (T 'm3.problems.col.device');  Prop = 'Device';  Width = 250 }
        @{ Header = (T 'm3.problems.col.code');    Prop = 'Code';    Width = 80 }
        @{ Header = (T 'm3.problems.col.meaning'); Prop = 'Meaning'; Width = 430 }
    )
    $table.MaxHeight = 260
    foreach ($p in $rows) {
        if ($null -eq $p) { continue }
        $row = [PSCustomObject]@{
            Device  = [string](Get-WCProp $p 'Name')
            Code    = ('Code ' + (Get-WCProp $p 'Code'))
            Meaning = [string](Get-WCProp $p 'Meaning')
        }
        $table.Items.Add($row) | Out-Null
    }
    Add-WCChild $State.ProblemsHost $table
}

function Update-WCM3SystemUi {
    # Do du lieu GPU / OEM / BIOS (lop 3 - trung thuc, khong noi "moi nhat")
    param($State, $Info)
    $State.SysSpinner.Visibility = [Windows.Visibility]::Collapsed
    $State.GpuHost.Children.Clear()
    $State.OemHost.Children.Clear()
    $State.BiosHost.Children.Clear()

    # --- GPU ---
    $gpus = @()
    if ($null -ne $Info) { $gpus = @(Get-WCProp $Info 'Gpus') }
    if ($gpus.Count -eq 0) {
        Add-WCChild $State.GpuHost (New-WCTextBlock -Text (T 'm3.gpu.none') -Size 12.5 -ColorKey 'WcSubtle' -Wrap)
    }
    foreach ($g in $gpus) {
        if ($null -eq $g) { continue }
        $vendor = [string](Get-WCProp $g 'Vendor')
        $raw = [string](Get-WCProp $g 'RawVersion')
        $friendly = [string](Get-WCProp $g 'FriendlyVersion')
        $dateText = [string](Get-WCProp $g 'DateText')
        $smi = [string](Get-WCProp $g 'SmiVersion')

        $card = New-Object Windows.Controls.Border
        $card.CornerRadius = (New-Object Windows.CornerRadius(8))
        $card.BorderThickness = (New-Object Windows.Thickness(1))
        $card.Padding = (New-Object Windows.Thickness(12))
        $card.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'WcCardBg2')
        $card.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'WcBorder')
        $inner = New-WCVStack -Spacing 4

        $topRow = New-WCHStack
        $t = New-WCTextBlock -Text ([string](Get-WCProp $g 'Name')) -Size 13.5 -Weight 'SemiBold'
        $t.VerticalAlignment = [Windows.VerticalAlignment]::Center
        Add-WCChild $topRow $t
        if ($vendor) {
            $chip = New-WCChip -Text $vendor -Kind 'Accent'
            $chip.VerticalAlignment = [Windows.VerticalAlignment]::Center
            Add-WCChild $topRow $chip
        }
        # Trang thai trung thuc: khong scrape trang hang -> "Khong xac dinh"
        $statusChip = New-WCChip -Text (T 'm3.gpu.status') -Kind 'Unknown'
        $statusChip.VerticalAlignment = [Windows.VerticalAlignment]::Center
        Add-WCChild $topRow $statusChip
        Add-WCChild $inner $topRow

        $verText = $raw
        if ($friendly) { $verText = $friendly }
        $fr = New-WCFieldRow -Label (T 'm3.gpu.current') -Value $verText -NoCopy
        if ($friendly -and $raw -and ($friendly -ne $raw)) { $fr.Tag.ToolTip = $raw }
        Add-WCChild $inner $fr
        if ($dateText -and ($dateText -ne '—')) {
            Add-WCChild $inner (New-WCFieldRow -Label (T 'm3.all.col.date') -Value $dateText -NoCopy)
        }
        if (($vendor -eq 'NVIDIA') -and $smi) {
            Add-WCChild $inner (New-WCTextBlock -Text (T 'm3.gpu.smi' @($smi)) -Size 12 -ColorKey 'WcSubtle' -Wrap)
        }
        $url = Get-WCGpuVendorUrl $vendor
        if ($url) {
            $u = $url
            $openBtn = New-WCButton -Text (T 'm3.gpu.open') -Small -OnClick { param($b) try { Start-Process $u } catch { Show-WCToast (T 'common.cannotopen') 'Warn' } }.GetNewClosure()
            Add-WCChild $inner $openBtn
        }
        $card.Child = $inner
        Add-WCChild $State.GpuHost $card
    }

    # --- OEM (hang may / model / service tag) ---
    if ($null -ne $Info) {
        Add-WCChild $State.OemHost (New-WCFieldRow -Label (T 'm3.oem.vendor') -Value ([string](Get-WCProp $Info 'Manufacturer')))
        Add-WCChild $State.OemHost (New-WCFieldRow -Label (T 'm3.oem.model') -Value ([string](Get-WCProp $Info 'Model')))
        # Service tag hien DAY DU trong app (day khong phai export - spec M3)
        Add-WCChild $State.OemHost (New-WCFieldRow -Label (T 'm3.oem.serial') -Value ([string](Get-WCProp $Info 'Serial')))
        $vendor2 = Get-WCProp $Info 'Vendor'
        if ($null -ne $vendor2) {
            $vName = [string](Get-WCProp $vendor2 'Name')
            $vUrl = [string](Get-WCProp $vendor2 'Url')
            Add-WCChild $State.OemHost (New-WCTextBlock -Text (T 'm3.oem.advice' @($vName)) -Size 12.5 -ColorKey 'WcWarn' -Wrap)
            $oemBtnRow = New-WCHStack -Spacing 8
            $oemBtn = New-WCButton -Text (T 'm3.oem.open' @($vName)) -OnClick { param($b) try { Start-Process $vUrl } catch { Show-WCToast (T 'common.cannotopen') 'Warn' } }.GetNewClosure()
            Add-WCChild $oemBtnRow $oemBtn
            # Dell: co dcu-cli -> nut quet /scan; KHONG tu /applyUpdates (spec M3)
            $cli = [string](Get-WCProp $Info 'DellCli')
            if ($cli) {
                $cliPath = $cli
                $dcuBtn = New-WCButton -Text (T 'm3.oem.dell.scan') -OnClick { param($b) try { Start-Process -FilePath $cliPath -ArgumentList '/scan' } catch { Show-WCToast (T 'common.cannotopen') 'Warn' } }.GetNewClosure()
                Add-WCChild $oemBtnRow $dcuBtn
                Add-WCChild $State.OemHost $oemBtnRow
                Add-WCChild $State.OemHost (New-WCTextBlock -Text (T 'm3.oem.dell.note') -Size 11.5 -ColorKey 'WcSubtle' -Wrap)
                # Che do chuyen gia: hien lenh KHONG tu chay (/applyUpdates) kem nut copy
                Add-WCChild $State.OemHost (New-WCExpertLine -Command ('"' + $cli + '" /applyUpdates'))
            } else {
                Add-WCChild $State.OemHost $oemBtnRow
            }
        }
        # --- BIOS: chi liet ke + huong dan, KHONG tu cai ---
        Add-WCChild $State.BiosHost (New-WCFieldRow -Label (T 'm3.bios.version') -Value ([string](Get-WCProp $Info 'BiosVersion')) -NoCopy)
        Add-WCChild $State.BiosHost (New-WCFieldRow -Label (T 'm3.bios.date') -Value ([string](Get-WCProp $Info 'BiosDateText')) -NoCopy)
        Add-WCChild $State.BiosHost (New-WCTextBlock -Text (T 'm3.bios.warn') -Size 12.5 -ColorKey 'WcWarn' -Wrap)
    }
}

function Update-WCM3BackupsUi {
    # Do danh sach cac ban sao luong driver + nut huong dan khoi phuc
    param($State, $Rows)
    $State.BackupHost.Children.Clear()
    $rows = @($Rows)
    if ($rows.Count -eq 0) {
        Add-WCChild $State.BackupHost (New-WCTextBlock -Text (T 'm3.backup.empty') -ColorKey 'WcSubtle' -Wrap)
        return
    }
    foreach ($b in $rows) {
        if ($null -eq $b) { continue }
        $path = [string](Get-WCProp $b 'Path')
        $label = New-WCTextBlock -Text (([string](Get-WCProp $b 'Name')) + ' — ' + ([string](Get-WCProp $b 'InfCount')) + ' .inf, ' + ([string](Get-WCProp $b 'SizeText'))) -Size 12.5
        $label.VerticalAlignment = [Windows.VerticalAlignment]::Center
        $row = New-WCHStack -Spacing 8
        Add-WCChild $row $label
        $p = $path
        $btn = New-WCButton -Text (T 'm3.backup.restore') -Small -OnClick { param($x) Show-WCM3RestoreGuide -BackupPath $p }.GetNewClosure()
        Add-WCChild $row $btn
        Add-WCChild $State.BackupHost $row
    }
}

function Show-WCM3RestoreGuide {
    # Huong dan khoi phuc: pnputil /add-driver + Rollback Device Manager
    param([Parameter(Mandatory)][string]$BackupPath)
    $msg = (T 'm3.backup.restore.msg' @($BackupPath))
    Show-WCInfo -Title (T 'm3.backup.restore.title') -Message $msg
}

function Show-WCM3InstallResult {
    # Hien ket qua cai driver (trung thuc: cai duoc cai gi, rot cai gi)
    param($State, $Rep)
    $lines = @()
    if ([bool](Get-WCProp $Rep 'DryRun')) {
        $lines += (T 'common.dryrun.header')
        $lines += (T 'm3.result.dryrun' @((@(Get-WCProp $Rep 'Installed')).Count))
    } else {
        $inst = @(Get-WCProp $Rep 'Installed')
        if ($inst.Count -gt 0) { $lines += (T 'm3.result.ok' @($inst.Count)) }
        $fail = @(Get-WCProp $Rep 'Failed')
        if ($fail.Count -gt 0) { $lines += (T 'm3.result.failed' @([string]::Join('; ', $fail))) }
        $dlf = @(Get-WCProp $Rep 'DownloadFailed')
        if ($dlf.Count -gt 0) { $lines += (T 'm3.result.download.fail' @([string]::Join('; ', $dlf))) }
        $skip = @(Get-WCProp $Rep 'Skipped')
        if ($skip.Count -gt 0) { $lines += (T 'm3.result.skipped' @([string]::Join('; ', $skip))) }
        if ([bool](Get-WCProp $Rep 'RebootRequired')) { $lines += (T 'm3.result.reboot') }
        $bk = [string](Get-WCProp $Rep 'Backup')
        $bp = [string](Get-WCProp $Rep 'BackupPath')
        if ($bk -eq 'new') { $lines += (T 'm3.result.backup.new' @($bp)) }
        elseif ($bk -eq 'today') { $lines += (T 'm3.result.backup.today' @($bp)) }
        $rp = [string](Get-WCProp $Rep 'RestorePoint')
        if ($rp -eq 'ok') { $lines += (T 'm3.result.restorepoint.ok') }
        elseif ($rp -eq 'skip') { $lines += (T 'm3.result.restorepoint.skip') }
    }
    $State.UpdatesStatus.Text = [string]::Join("`n", $lines)
    $State.UpdatesStatus.Visibility = [Windows.Visibility]::Visible
}

function Invoke-WCM3Scan {
    # Quet toan bo: 1 task nen cho du lieu CIM (kiem ke + thiet bi loi + GPU/OEM/
    # BIOS + backup), 1 task rieng cho Windows Update (mang, cham) -> du lieu ve dan.
    param($State)
    if ($State.ProblemsSpinner) { $State.ProblemsSpinner.Visibility = [Windows.Visibility]::Visible }
    if ($State.SysSpinner) { $State.SysSpinner.Visibility = [Windows.Visibility]::Visible }
    $ok = Start-WCTask -Id 'm3.scan' -Title (T 'm3.title') -ShowStatus -Worker {
        param($ctx, $s)
        $ctx.Progress(10, (T 'm3.scan.inventory'))
        $inv = Get-WCDriverInventory
        $ctx.Progress(55, (T 'm3.scan.problems'))
        $prob = Get-WCDriverProblemDevices
        $ctx.Progress(70, (T 'm3.scan.system'))
        $info = Get-WCDriverSystemInfo -Inventory @($inv.Data)
        $ctx.Progress(90, (T 'm3.scan.backup'))
        $backups = Get-WCDriverBackups
        return [PSCustomObject]@{
            InventoryStatus = [string]$inv.Status
            InventoryReason = [string]$inv.Reason
            Inventory       = @($inv.Data)
            ProblemsStatus  = [string]$prob.Status
            ProblemsReason  = [string]$prob.Reason
            Problems        = @($prob.Data)
            SystemInfo      = $info
            Backups         = @($backups)
        }
    } -Done {
        param($r)
        if ($null -eq $r) { return }
        $invStatus = [string](Get-WCProp $r 'InventoryStatus')
        if ($invStatus -ne 'Ok') {
            $State.AllStatus.Text = (T 'm3.all.fail' @([string](Get-WCProp $r 'InventoryReason')))
            $State.AllStatus.Visibility = [Windows.Visibility]::Visible
        } else {
            $State.AllStatus.Visibility = [Windows.Visibility]::Collapsed
        }
        $State.Inventory = @(Get-WCProp $r 'Inventory')
        Update-WCM3DriverTable $State
        Update-WCM3ProblemsUi $State ([string](Get-WCProp $r 'ProblemsStatus')) ([string](Get-WCProp $r 'ProblemsReason')) @(Get-WCProp $r 'Problems')
        Update-WCM3SystemUi $State (Get-WCProp $r 'SystemInfo')
        Update-WCM3BackupsUi $State @(Get-WCProp $r 'Backups')
    }.GetNewClosure()
    if (-not $ok) {
        Show-WCToast (T 'common.running' @((T 'm3.title'))) 'Info'
        return
    }
    Start-WCM3TaskWatch $State 'm3.scan' @('ProblemsSpinner', 'SysSpinner')
    Invoke-WCM3WuaSearch $State
}

function Invoke-WCM3WuaSearch {
    # Tim cap nhat driver qua Windows Update (task rieng, co Huy = bo qua ket qua)
    param($State)
    $State.UpdatesSpinner.Visibility = [Windows.Visibility]::Visible
    $State.UpdatesStatus.Visibility = [Windows.Visibility]::Collapsed
    $ok = Start-WCTask -Id 'm3.wua' -Title (T 'm3.updates.title') -ShowStatus -Worker {
        param($ctx, $s)
        $ctx.Progress(5, (T 'm3.updates.searching'))
        $res = Invoke-WCDriverWuaSearch
        # COM khong huy duoc giua chang -> Huy = ghi log + bo qua ket qua
        if ($ctx.Cancelled()) {
            $ctx.Log('WUA search: nguoi dung bam Huy -> bo qua ket qua')
            return $null
        }
        return $res
    } -Done {
        param($r)
        Update-WCM3UpdatesUi $State $r
    }.GetNewClosure()
    if (-not $ok) {
        Show-WCToast (T 'common.running' @((T 'm3.updates.title'))) 'Info'
        return
    }
    Start-WCM3TaskWatch $State 'm3.wua' @('UpdatesSpinner')
}

function Invoke-WCM3InstallSelected {
    # Luong chinh: chon muc -> xac nhan (NotUndoable) -> task nen:
    # (a) backup neu chua co hom nay, (b) thu tao restore point, (c) tai + cai.
    param($State, [switch]$SkipRestorePoint)
    $selected = @(Get-WCCheckRowSelection $State.UpdatesList)
    if ($selected.Count -eq 0) {
        Show-WCToast (T 'common.empty') 'Info'
        return
    }
    $titles = @()
    foreach ($u in $selected) {
        $t = [string](Get-WCProp $u 'Title')
        if ($t) { $titles += $t }
    }
    if ($titles.Count -eq 0) {
        Show-WCToast (T 'common.nodata') 'Warn'
        return
    }
    $bullets = @()
    foreach ($t2 in $titles) { $bullets += ('  • ' + $t2) }
    $msg = (T 'm3.updates.install.confirm.msg' @($titles.Count, ([string]::Join("`n", $bullets))))
    if (-not (Show-WCConfirm -Title (T 'm3.updates.install.confirm.title') -Message $msg -NotUndoable (T 'm3.updates.install.confirm.noundo'))) { return }
    # Ghi journal TREN UI THREAD truoc khi lam (worker runspace khong nap
    # $Script:WcJournalPath -> ghi tu worker se mat - han che ky thuat da biet)
    $entry = Add-WCJournalEntry -Module 'M3' -Action (T 'm3.journal.install') -Target ([string]::Join('; ', $titles)) -OldValue '' -UndoType ''
    $backupRoot2 = Get-WCDriverBackupRoot
    if (-not $backupRoot2) { Show-WCToast (T 'common.cannotopen') 'Warn'; return }
    $backupPath = Join-Path $backupRoot2 ('drivers-' + (Get-Date -Format 'yyyy-MM-dd'))
    Start-WCM3InstallTask -State $State -Titles $titles -SkipRestorePoint ([bool]$SkipRestorePoint) -Entry $entry -BackupPath $backupPath
}

function Start-WCM3InstallTask {
    # Task cai driver: toan bo COM (search lai + download tung goi + install)
    # nam trong 1 worker duy nhat - khong truyen doi tuong COM qua ranh gioi.
    param($State, [string[]]$Titles, [bool]$SkipRestorePoint, $Entry, [string]$BackupPath)
    $taskArgs = @{
        Titles = @($Titles); SkipRestorePoint = $SkipRestorePoint
        DryRun = (Test-WCDryRunMode); BackupPath = $BackupPath
    }
    $ok = Start-WCTask -Id 'm3.install' -Title (T 'm3.updates.install') -ShowStatus -Args $taskArgs -Worker {
        param($ctx, $s)
        $rep = [PSCustomObject]@{
            Cancelled = $false; DryRun = [bool]$s.DryRun
            Backup = 'skip'; BackupPath = [string]$s.BackupPath
            RestorePoint = 'ok'; RestorePointReason = ''
            Downloaded = 0; Installed = @(); Failed = @(); DownloadFailed = @(); Skipped = @()
            RebootRequired = $false; Aborted = ''; Reason = ''
        }
        # FIXTURE (du lieu gia) -> khong cho cai that
        $fx = Get-WCState 'WcFixture'
        if ($fx) { $rep.Aborted = 'fixture'; return $rep }
        if ($ctx.Cancelled()) { $rep.Cancelled = $true; return $rep }

        # (a) Sao luu driver neu hom nay chua co (spec M3: duong lui truoc khi cai)
        $ctx.Progress(3, (T 'm3.install.backup'))
        $dest = [string]$s.BackupPath
        $hasToday = $false
        try {
            if (Test-Path -LiteralPath $dest) {
                $infs = @(Get-ChildItem -LiteralPath $dest -Filter '*.inf' -Recurse -ErrorAction SilentlyContinue)
                if ($infs.Count -gt 0) { $hasToday = $true }
            }
        } catch { }
        if (-not $hasToday) {
            if ($s.DryRun) { $rep.Backup = 'dryrun' }
            else {
                $b = Invoke-WCDriverExportCore -Destination $dest -Ctx $ctx
                if (-not $b['Ok']) {
                    $rep.Backup = 'failed'; $rep.Reason = [string]$b['Reason']; $rep.Aborted = 'backup'
                    return $rep
                }
                $rep.Backup = 'new'
            }
        } else { $rep.Backup = 'today' }
        if ($ctx.Cancelled()) { $rep.Cancelled = $true; return $rep }

        # (b) Thu tao diem khoi phuc; that bai -> DUNG lai de nguoi dung quyet
        #     (KHONG tu bat System Protection - spec 2.4 / M3)
        if (-not [bool]$s.SkipRestorePoint) {
            $ctx.Progress(8, (T 'm3.install.restorepoint'))
            if ($s.DryRun) { $rep.RestorePoint = 'dryrun' }
            else {
                try {
                    Checkpoint-Computer -Description 'WinCare trước khi cài driver' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
                    $rep.RestorePoint = 'ok'
                } catch {
                    $rep.RestorePoint = 'failed'
                    $rep.RestorePointReason = $_.Exception.Message
                    $rep.Aborted = 'restorepoint'
                    return $rep
                }
            }
        } else { $rep.RestorePoint = 'skip' }
        if ($ctx.Cancelled()) { $rep.Cancelled = $true; return $rep }

        # (c) Tim lai cac muc da chon (COM moi trong worker nay)
        $ctx.Progress(12, (T 'm3.install.searching'))
        $session = $null
        try {
            $session = New-Object -ComObject Microsoft.Update.Session
            $searcher = $session.CreateUpdateSearcher()
            try { $searcher.ServerSelection = 2 } catch { }   # 2 = Windows Update
            $result = $searcher.Search("IsInstalled=0 and Type='Driver'")
        } catch {
            $rep.Aborted = 'search'; $rep.Reason = $_.Exception.Message
            return $rep
        }
        $all = New-Object -ComObject Microsoft.Update.UpdateColl
        foreach ($u in @($result.Updates)) {
            if ($null -eq $u) { continue }
            $t = [string](Get-WCDriverComProp $u 'Title')
            if (@($s.Titles) -contains $t) { $null = $all.Add($u) }
        }
        foreach ($want in @($s.Titles)) {
            $found = $false
            for ($k = 0; $k -lt $all.Count; $k++) {
                if ([string](Get-WCDriverComProp $all.Item($k) 'Title') -eq $want) { $found = $true; break }
            }
            if (-not $found) { $rep.Skipped += $want }
        }
        if ($all.Count -eq 0) { $rep.Aborted = 'nomatch'; return $rep }
        if ($s.DryRun) {
            $rep.Downloaded = $all.Count
            for ($k = 0; $k -lt $all.Count; $k++) { $rep.Installed += [string](Get-WCDriverComProp $all.Item($k) 'Title') }
            $ctx.Progress(100, (T 'common.dryrun.header'))
            return $rep
        }

        # (d) Tai TUNG goi mot (tien do that theo so goi x/n; WUA khong cho huy
        #     giua 1 goi - Huy = dung o goi ke tiep, ghi log)
        $ready = New-Object -ComObject Microsoft.Update.UpdateColl
        for ($i = 0; $i -lt $all.Count; $i++) {
            if ($ctx.Cancelled()) { $rep.Cancelled = $true; break }
            $u = $all.Item($i)
            $title = [string](Get-WCDriverComProp $u 'Title')
            $pct = 15 + [int][math]::Floor((55 * $i) / $all.Count)
            $ctx.Progress($pct, (T 'm3.install.download' @(($i + 1), $all.Count, $title)))
            $one = New-Object -ComObject Microsoft.Update.UpdateColl
            $null = $one.Add($u)
            try {
                $dl = $session.CreateUpdateDownloader()
                $dl.Updates = $one
                $dres = $dl.Download()
                $dcode = -1
                try { $dcode = [int](Get-WCDriverComProp $dres 'ResultCode') } catch { }
                if (($dcode -eq 2) -or ($dcode -eq 3)) { $null = $ready.Add($u); $rep.Downloaded++ }
                else { $rep.DownloadFailed += $title }
            } catch { $rep.DownloadFailed += $title }
        }
        if ($rep.Cancelled) { return $rep }
        if ($ready.Count -eq 0) { $rep.Aborted = 'download'; return $rep }

        # (e) Cai qua UpdateInstaller, doc ket qua tung muc + co can khoi dong lai
        $ctx.Progress(75, (T 'm3.install.installing' @($ready.Count)))
        try {
            $installer = $session.CreateUpdateInstaller()
            $installer.Updates = $ready
            $ires = $installer.Install()
            $rep.RebootRequired = [bool](Get-WCDriverComProp $ires 'RebootRequired')
            for ($j = 0; $j -lt $ready.Count; $j++) {
                $title2 = [string](Get-WCDriverComProp $ready.Item($j) 'Title')
                $code = -1
                try { $ur = $ires.GetUpdateResult($j); $code = [int](Get-WCDriverComProp $ur 'ResultCode') } catch { }
                if (($code -eq 2) -or ($code -eq 3)) { $rep.Installed += $title2 }
                else { $rep.Failed += $title2 }
            }
            $ctx.Progress(100, (T 'common.task.done'))
        } catch {
            $rep.Aborted = 'install'; $rep.Reason = $_.Exception.Message
            return $rep
        }
        return $rep
    } -Done {
        param($rep)
        if ($null -eq $rep) { return }
        $aborted = [string](Get-WCProp $rep 'Aborted')
        $cancelled = [bool](Get-WCProp $rep 'Cancelled')
        $jr = 'Ok'
        if ($cancelled) { $jr = 'Cancelled' }
        elseif ($aborted) { $jr = ('Failed: ' + $aborted) }
        Complete-WCJournalEntry -Entry $Entry -Result $jr
        if ($cancelled) {
            $State.UpdatesStatus.Text = (T 'm3.result.cancelled')
            $State.UpdatesStatus.Visibility = [Windows.Visibility]::Visible
            return
        }
        if ($aborted -eq 'restorepoint') {
            # System Protection tat / loi -> bao ro, khong tu bat, de nguoi dung quyet
            $reason = [string](Get-WCProp $rep 'RestorePointReason')
            $detail = ''
            if ($reason) { $detail = ("`n" + (T 'common.details') + ': ' + $reason + "`n`n") }
            $msg = (T 'm3.restorepoint.fail.msg' @($detail))
            if (Show-WCConfirm -Title (T 'm3.restorepoint.fail.title') -Message $msg -NotUndoable (T 'm3.updates.install.confirm.noundo') -Danger) {
                $entry2 = Add-WCJournalEntry -Module 'M3' -Action (T 'm3.journal.install') -Target ([string]::Join('; ', $Titles)) -OldValue '' -UndoType ''
                Start-WCM3InstallTask -State $State -Titles $Titles -SkipRestorePoint $true -Entry $entry2 -BackupPath $BackupPath
            }
            return
        }
        if ($aborted -eq 'backup') {
            Show-WCError -Friendly (T 'm3.backup.fail') -Details ([string](Get-WCProp $rep 'Reason'))
            return
        }
        if ($aborted -eq 'search') {
            Show-WCError -Friendly (T 'm3.result.search.fail' @([string](Get-WCProp $rep 'Reason'))) -Details ([string](Get-WCProp $rep 'Reason'))
            return
        }
        if ($aborted -eq 'fixture') {
            $State.UpdatesStatus.Text = (T 'm3.result.fixture')
            $State.UpdatesStatus.Visibility = [Windows.Visibility]::Visible
            return
        }
        if ($aborted -eq 'nomatch') {
            $State.UpdatesStatus.Text = (T 'm3.result.nomatch')
            $State.UpdatesStatus.Visibility = [Windows.Visibility]::Visible
            return
        }
        if ($aborted -eq 'download') {
            $dlf = @(Get-WCProp $rep 'DownloadFailed')
            $State.UpdatesStatus.Text = (T 'm3.result.download.fail' @([string]::Join('; ', $dlf)))
            $State.UpdatesStatus.Visibility = [Windows.Visibility]::Visible
            return
        }
        if ($aborted -eq 'install') {
            Show-WCError -Friendly (T 'common.task.failed') -Details ([string](Get-WCProp $rep 'Reason'))
            return
        }
        Show-WCM3InstallResult $State $rep
        Update-WCM3BackupsUi $State (Get-WCDriverBackups)
        $inst = @(Get-WCProp $rep 'Installed')
        if ($inst.Count -gt 0) {
            Show-WCToast (T 'common.success') 'Ok'
            Invoke-WCM3WuaSearch $State
        }
    }.GetNewClosure()
    if (-not $ok) {
        Show-WCToast (T 'common.running' @((T 'm3.updates.install'))) 'Info'
    }
}

function Invoke-WCM3BackupNow {
    # Nut "Sao luu toan bo driver hien tai" (Export-WindowsDriver -Online)
    param($State)
    $backupRoot = Get-WCDriverBackupRoot
    if (-not $backupRoot) { Show-WCToast (T 'common.cannotopen') 'Warn'; return }
    $dest = Join-Path $backupRoot ('drivers-' + (Get-Date -Format 'yyyy-MM-dd'))
    # Hom nay da co roi -> khong xuat lai (thao tac DISM nang)
    $hasToday = $false
    try {
        if (Test-Path -LiteralPath $dest) {
            $infs = @(Get-ChildItem -LiteralPath $dest -Filter '*.inf' -Recurse -ErrorAction SilentlyContinue)
            if ($infs.Count -gt 0) { $hasToday = $true }
        }
    } catch { }
    if ($hasToday) {
        Show-WCToast (T 'm3.backup.exists' @($dest)) 'Info'
        return
    }
    $dry = Test-WCDryRunMode
    $entry = Add-WCJournalEntry -Module 'M3' -Action (T 'm3.journal.backup') -Target $dest -OldValue '' -UndoType ''
    $State.BackupSpinner.Visibility = [Windows.Visibility]::Visible
    $ok = Start-WCTask -Id 'm3.backup' -Title (T 'm3.backup.run') -ShowStatus -Args @{ Destination = $dest; DryRun = $dry } -Worker {
        param($ctx, $s)
        if ($ctx.Cancelled()) { return $null }
        $h = Invoke-WCDriverExportCore -Destination ([string]$s.Destination) -Ctx $ctx -DryRun ([bool]$s.DryRun)
        if ($ctx.Cancelled()) { return $null }
        return [PSCustomObject]$h
    } -Done {
        param($r)
        $State.BackupSpinner.Visibility = [Windows.Visibility]::Collapsed
        if ($null -eq $r) {
            Complete-WCJournalEntry -Entry $Entry -Result 'Cancelled'
            return
        }
        if ([bool](Get-WCProp $r 'Ok')) {
            Complete-WCJournalEntry -Entry $Entry -Result 'Ok'
            if ([bool](Get-WCProp $r 'DryRun')) {
                Show-WCToast (T 'common.dryrun.header') 'Info'
            } else {
                Show-WCToast (T 'm3.backup.done' @(([int](Get-WCProp $r 'Count')), ([string](Get-WCProp $r 'Path')))) 'Ok'
            }
            Update-WCM3BackupsUi $State (Get-WCDriverBackups)
        } else {
            Complete-WCJournalEntry -Entry $Entry -Result ('Failed: ' + [string](Get-WCProp $r 'Reason'))
            Show-WCError -Friendly (T 'm3.backup.fail') -Details ([string](Get-WCProp $r 'Reason'))
        }
    }.GetNewClosure()
    if (-not $ok) {
        $State.BackupSpinner.Visibility = [Windows.Visibility]::Collapsed
        Show-WCToast (T 'common.running' @((T 'm3.backup.run'))) 'Info'
        return
    }
    Start-WCM3TaskWatch $State 'm3.backup' @('BackupSpinner')
}

# ---------------------------------------------------------------------------
# KHOI TAO MODULE (BAT BUOC cuoi file)
# ---------------------------------------------------------------------------
function Initialize-WCModuleM3 {
    $state = @{
        Scanned = $false
        Inventory = @()
        GroupFilter = 'all'
        SearchText = ''
        UpdatesList = $null; UpdatesSpinner = $null; UpdatesStatus = $null
        WsusBanner = $null; InstallBtn = $null
        ProblemsSpinner = $null; ProblemsHost = $null
        SysSpinner = $null; GpuHost = $null; OemHost = $null; BiosHost = $null
        DriverCount = $null; ChipHost = $null; DriverTable = $null; AllStatus = $null
        BackupSpinner = $null; BackupHost = $null
    }
    Register-WCNavItem -Key 'm3' -Badge 'M3' -Title (T 'm3.title') -Order 40 -Builder {
        New-WCM3Panel $state
    }.GetNewClosure() -OnShow {
        if (-not $state.Scanned) {
            $state.Scanned = $true
            Invoke-WCM3Scan $state
        }
    }.GetNewClosure() -OnHide { }
}


# ============================================================================
# REGION: 15-M4-Specs.ps1
# ============================================================================

# ============================================================================
#  src/15-M4-Specs.ps1 - Module M4: THONG SO MAY CHI TIET (cay mo rộng)
#  Nhom = Expander, dong tom tat hien san khi thu gon; thu thap SONG SONG o
#  nen (3 Start-WCTask), nhom nao xong som hien truoc, nhom cham co spinner rieng.
#  Moi nguon qua Invoke-WCQuery (key rieng, TTL 60s), moi thuoc tinh qua
#  Get-WCProp, moi loi thanh "Khong doc duoc (ly do)" - khong de trong (spec M4).
# ============================================================================

Register-WCStrings 'vi' @{
    'm4.title' = 'Thông số máy chi tiết'
    'm4.subtitle' = 'Kiểm kê phần cứng đầy đủ — thu thập song song ở nền, nhóm nào xong sớm hiện trước'
    'm4.notread' = 'Không đọc được ({0})'
    'm4.reason.missing' = 'thiếu dữ liệu'
    'm4.reason.unknown' = 'không rõ lý do'
    'm4.on' = 'Bật'
    'm4.off' = 'Tắt'
    'm4.uptime.fmt' = '{0} ngày {1} giờ {2} phút'
    'm4.mhz' = '{0} MHz'
    'm4.hz' = '{0} Hz'
    'm4.pct' = '{0}%'
    'm4.copy.summary' = 'Sao chép tóm tắt'
    'm4.export' = 'Xuất báo cáo'
    'm4.open.reports' = 'Mở thư mục báo cáo'
    'm4.show.virtual' = 'Hiện adapter ảo'
    'm4.gpu.hidden' = 'Đang ẩn {0} adapter ảo — bật "Hiện adapter ảo" để xem'
    'm4.grp.system' = 'Hệ thống'
    'm4.grp.cpu' = 'CPU'
    'm4.grp.gpu' = 'GPU'
    'm4.grp.ram' = 'RAM'
    'm4.grp.disks' = 'Ổ đĩa'
    'm4.grp.monitors' = 'Màn hình'
    'm4.grp.net' = 'Mạng'
    'm4.grp.battery' = 'Pin'
    'm4.grp.cputemp' = 'Nhiệt độ CPU'
    'm4.cpu.n' = 'CPU {0}'
    'm4.gpu.n' = 'GPU {0}'
    'm4.disk.n' = 'Ổ đĩa {0}'
    'm4.mon.n' = 'Màn hình {0}'
    'm4.ram.slot.n' = 'Slot {0}'
    'm4.bat.n' = 'Pin {0}'
    'm4.src.cs' = 'Máy tính (Win32_ComputerSystem)'
    'm4.src.os' = 'Hệ điều hành (Win32_OperatingSystem)'
    'm4.src.bios' = 'BIOS (Win32_BIOS)'
    'm4.src.board' = 'Mainboard (Win32_BaseBoard)'
    'm4.src.product' = 'Danh tính máy (Win32_ComputerSystemProduct)'
    'm4.sys.manufacturer' = 'Hãng sản xuất'
    'm4.sys.model' = 'Model'
    'm4.sys.ramtotal' = 'RAM lắp vào máy (phần cứng)'
    'm4.sys.user' = 'Người dùng hiện tại'
    'm4.sys.os' = 'Hệ điều hành'
    'm4.sys.osversion' = 'Phiên bản'
    'm4.sys.build' = 'Build'
    'm4.sys.arch' = 'Kiến trúc hệ điều hành'
    'm4.sys.installdate' = 'Ngày cài đặt'
    'm4.sys.uptime' = 'Thời gian hoạt động liên tục'
    'm4.sys.sysdrive' = 'Ổ hệ thống'
    'm4.sys.firmware' = 'Chế độ firmware'
    'm4.sys.firmware.uefi' = 'UEFI'
    'm4.sys.firmware.legacy' = 'Legacy (BIOS cũ)'
    'm4.sys.secureboot' = 'Secure Boot'
    'm4.sys.tpm' = 'TPM'
    'm4.sys.tpm.ready' = 'Sẵn sàng ({0})'
    'm4.sys.tpm.notready' = 'Không sẵn sàng ({0})'
    'm4.sys.biosver' = 'Phiên bản BIOS'
    'm4.sys.biosdate' = 'Ngày phát hành BIOS'
    'm4.sys.biosserial' = 'Serial BIOS / Service tag'
    'm4.sys.board' = 'Mainboard'
    'm4.sys.boardserial' = 'Serial mainboard'
    'm4.sys.uuid' = 'UUID máy'
    'm4.cpu.name' = 'Tên'
    'm4.cpu.cores' = 'Nhân vật lý'
    'm4.cpu.threads' = 'Luồng logic'
    'm4.cpu.maxclock' = 'Xung tối đa'
    'm4.cpu.curclock' = 'Xung hiện tại'
    'm4.cpu.l2' = 'Cache L2'
    'm4.cpu.l3' = 'Cache L3'
    'm4.cpu.socket' = 'Socket'
    'm4.cpu.arch' = 'Kiến trúc'
    'm4.cpu.virt' = 'Ảo hóa (VT-x/AMD-V)'
    'm4.cpu.load' = 'Tải hiện tại'
    'm4.gpu.name' = 'Tên'
    'm4.gpu.type' = 'Loại'
    'm4.gpu.type.integrated' = 'Tích hợp'
    'm4.gpu.type.discrete' = 'Rời'
    'm4.gpu.vendor' = 'Hãng'
    'm4.gpu.vendor.unknownven' = 'Không xác định (VEN_{0})'
    'm4.gpu.driver' = 'Phiên bản driver'
    'm4.gpu.driverdate' = 'Ngày driver'
    'm4.gpu.resolution' = 'Độ phân giải đang dùng'
    'm4.gpu.refresh' = 'Tần số quét'
    'm4.gpu.vram' = 'VRAM'
    'm4.gpu.vram.shared' = 'Dùng chung RAM hệ thống'
    'm4.gpu.temp' = 'Nhiệt độ (nvidia-smi)'
    'm4.gpu.clock' = 'Xung SM (nvidia-smi)'
    'm4.gpu.util' = 'Tải GPU (nvidia-smi)'
    'm4.gpu.smi.temp' = '{0} °C'
    'm4.gpu.ordernote' = 'Thứ tự liệt kê GPU có thể khác Task Manager. VRAM đọc từ registry (không dùng AdapterRAM — kiểu uint32 bị tràn trên 4 GB).'
    'm4.gpu.virtualnote' = 'Adapter ảo — bị ẩn mặc định.'
    'm4.ram.totalhw' = 'Tổng dung lượng (phần cứng)'
    'm4.ram.used' = 'Đang dùng (hệ điều hành)'
    'm4.ram.usedpct' = '{0} ({1}%)'
    'm4.ram.slots' = 'Slot đang dùng / tối đa'
    'm4.ram.location' = 'Vị trí khay RAM'
    'm4.ram.capacity' = 'Dung lượng'
    'm4.ram.type' = 'Loại'
    'm4.ram.speed' = 'Tốc độ danh nghĩa'
    'm4.ram.cspeed' = 'Tốc độ đang chạy'
    'm4.ram.manufacturer' = 'Hãng'
    'm4.ram.partnumber' = 'Part number'
    'm4.ram.formfactor' = 'Hình dạng'
    'm4.ram.soldered' = 'Số module ít hơn số slot và trùng một hãng: có thể có RAM hàn trên main (SMBIOS không tách bạch).'
    'm4.disk.model' = 'Tên / model'
    'm4.disk.type' = 'Loại'
    'm4.disk.bus' = 'Giao tiếp'
    'm4.disk.size' = 'Dung lượng'
    'm4.disk.health' = 'Tình trạng'
    'm4.disk.temp' = 'Nhiệt độ'
    'm4.disk.wear' = 'Hao mòn'
    'm4.disk.poweron' = 'Tổng giờ bật'
    'm4.disk.readerrors' = 'Lỗi đọc'
    'm4.disk.partition.letter' = 'Phân vùng {0}:'
    'm4.disk.partition.n' = 'Phân vùng {0}'
    'm4.disk.free.fmt' = '{0} (còn trống {1})'
    'm4.disk.temp.fmt' = '{0} °C'
    'm4.disk.wear.fmt' = '{0} %'
    'm4.disk.hours.fmt' = '{0} giờ'
    'm4.mon.name' = 'Tên'
    'm4.mon.year' = 'Năm sản xuất'
    'm4.mon.serial' = 'Serial'
    'm4.mon.resolution' = 'Độ phân giải đang dùng'
    'm4.mon.refresh' = 'Tần số quét'
    'm4.mon.hdr' = 'HDR'
    'm4.mon.hdr.on' = 'Bật ({0}/{1} màn hình)'
    'm4.mon.summary' = '{0} màn hình'
    'm4.net.desc' = 'Thiết bị'
    'm4.net.speed' = 'Tốc độ liên kết'
    'm4.net.type' = 'Loại adapter'
    'm4.net.mac' = 'Địa chỉ MAC'
    'm4.net.wifistd' = 'Chuẩn Wi-Fi'
    'm4.net.wifistd.na' = 'N/A (cần API Wi-Fi)'
    'm4.net.speed.gbps' = '{0} Gbps'
    'm4.net.speed.mbps' = '{0} Mbps'
    'm4.net.summary' = '{0} adapter đang bật'
    'm4.net.none.lbl' = 'Trạng thái'
    'm4.net.none' = 'Không có adapter mạng nào đang bật'
    'm4.bat.designed' = 'Dung lượng thiết kế'
    'm4.bat.full' = 'Dung lượng sạc đầy hiện tại'
    'm4.bat.wear' = 'Mức chai'
    'm4.bat.cycles' = 'Số chu kỳ sạc'
    'm4.bat.mwh' = '{0} mWh'
    'm4.bat.summary' = 'Chai {0}%'
    'm4.cputemp.summary' = 'Không có cảm biến chung'
    'm4.cputemp.msg' = 'Không có cảm biến đọc được (Windows không cung cấp API chung; dùng công cụ của hãng CPU nếu cần). WinCare không đóng gói driver kernel bên thứ ba để đọc nhiệt độ.'
    'm4.export.done' = 'Đã xuất báo cáo: {0}'
    'm4.export.fail' = 'Không xuất được báo cáo'
    'm4.export.time' = 'Thời điểm xuất'
    'm4.export.version' = 'Xuất bởi'
    'm4.export.masked' = 'Dữ liệu nhạy cảm (serial, MAC, UUID, tên người dùng) đã được che — tắt "Che dữ liệu nhạy cảm" trong cài đặt nếu cần bản đầy đủ'
    'm4.report.header' = 'WinCare — THÔNG SỐ MÁY CHI TIẾT'
}
Register-WCStrings 'en' @{
    'm4.title' = 'Detailed PC specs'
    'm4.subtitle' = 'Full hardware inventory — collected in parallel in the background, groups appear as they finish'
    'm4.notread' = 'Cannot read ({0})'
    'm4.reason.missing' = 'missing data'
    'm4.reason.unknown' = 'unknown reason'
    'm4.on' = 'On'
    'm4.off' = 'Off'
    'm4.uptime.fmt' = '{0} days {1} hours {2} minutes'
    'm4.mhz' = '{0} MHz'
    'm4.hz' = '{0} Hz'
    'm4.pct' = '{0}%'
    'm4.copy.summary' = 'Copy summary'
    'm4.export' = 'Export report'
    'm4.open.reports' = 'Open reports folder'
    'm4.show.virtual' = 'Show virtual adapters'
    'm4.gpu.hidden' = 'Hiding {0} virtual adapters — enable "Show virtual adapters" to see them'
    'm4.grp.system' = 'System'
    'm4.grp.cpu' = 'CPU'
    'm4.grp.gpu' = 'GPU'
    'm4.grp.ram' = 'RAM'
    'm4.grp.disks' = 'Disks'
    'm4.grp.monitors' = 'Monitors'
    'm4.grp.net' = 'Network'
    'm4.grp.battery' = 'Battery'
    'm4.grp.cputemp' = 'CPU temperature'
    'm4.cpu.n' = 'CPU {0}'
    'm4.gpu.n' = 'GPU {0}'
    'm4.disk.n' = 'Disk {0}'
    'm4.mon.n' = 'Monitor {0}'
    'm4.ram.slot.n' = 'Slot {0}'
    'm4.bat.n' = 'Battery {0}'
    'm4.src.cs' = 'Computer (Win32_ComputerSystem)'
    'm4.src.os' = 'Operating system (Win32_OperatingSystem)'
    'm4.src.bios' = 'BIOS (Win32_BIOS)'
    'm4.src.board' = 'Mainboard (Win32_BaseBoard)'
    'm4.src.product' = 'Machine identity (Win32_ComputerSystemProduct)'
    'm4.sys.manufacturer' = 'Manufacturer'
    'm4.sys.model' = 'Model'
    'm4.sys.ramtotal' = 'Installed RAM (hardware)'
    'm4.sys.user' = 'Current user'
    'm4.sys.os' = 'Operating system'
    'm4.sys.osversion' = 'Version'
    'm4.sys.build' = 'Build'
    'm4.sys.arch' = 'OS architecture'
    'm4.sys.installdate' = 'Install date'
    'm4.sys.uptime' = 'Uptime'
    'm4.sys.sysdrive' = 'System drive'
    'm4.sys.firmware' = 'Firmware mode'
    'm4.sys.firmware.uefi' = 'UEFI'
    'm4.sys.firmware.legacy' = 'Legacy (old BIOS)'
    'm4.sys.secureboot' = 'Secure Boot'
    'm4.sys.tpm' = 'TPM'
    'm4.sys.tpm.ready' = 'Ready ({0})'
    'm4.sys.tpm.notready' = 'Not ready ({0})'
    'm4.sys.biosver' = 'BIOS version'
    'm4.sys.biosdate' = 'BIOS release date'
    'm4.sys.biosserial' = 'BIOS serial / service tag'
    'm4.sys.board' = 'Mainboard'
    'm4.sys.boardserial' = 'Mainboard serial'
    'm4.sys.uuid' = 'Machine UUID'
    'm4.cpu.name' = 'Name'
    'm4.cpu.cores' = 'Physical cores'
    'm4.cpu.threads' = 'Logical processors'
    'm4.cpu.maxclock' = 'Max clock'
    'm4.cpu.curclock' = 'Current clock'
    'm4.cpu.l2' = 'L2 cache'
    'm4.cpu.l3' = 'L3 cache'
    'm4.cpu.socket' = 'Socket'
    'm4.cpu.arch' = 'Architecture'
    'm4.cpu.virt' = 'Virtualization (VT-x/AMD-V)'
    'm4.cpu.load' = 'Current load'
    'm4.gpu.name' = 'Name'
    'm4.gpu.type' = 'Type'
    'm4.gpu.type.integrated' = 'Integrated'
    'm4.gpu.type.discrete' = 'Discrete'
    'm4.gpu.vendor' = 'Vendor'
    'm4.gpu.vendor.unknownven' = 'Unknown (VEN_{0})'
    'm4.gpu.driver' = 'Driver version'
    'm4.gpu.driverdate' = 'Driver date'
    'm4.gpu.resolution' = 'Active resolution'
    'm4.gpu.refresh' = 'Refresh rate'
    'm4.gpu.vram' = 'VRAM'
    'm4.gpu.vram.shared' = 'Shared with system RAM'
    'm4.gpu.temp' = 'Temperature (nvidia-smi)'
    'm4.gpu.clock' = 'SM clock (nvidia-smi)'
    'm4.gpu.util' = 'GPU utilization (nvidia-smi)'
    'm4.gpu.smi.temp' = '{0} °C'
    'm4.gpu.ordernote' = 'GPU ordering may differ from Task Manager. VRAM is read from the registry (AdapterRAM is uint32 and overflows above 4 GB).'
    'm4.gpu.virtualnote' = 'Virtual adapter — hidden by default.'
    'm4.ram.totalhw' = 'Total (hardware)'
    'm4.ram.used' = 'In use (OS)'
    'm4.ram.usedpct' = '{0} ({1}%)'
    'm4.ram.slots' = 'Slots used / max'
    'm4.ram.location' = 'Memory array location'
    'm4.ram.capacity' = 'Capacity'
    'm4.ram.type' = 'Type'
    'm4.ram.speed' = 'Rated speed'
    'm4.ram.cspeed' = 'Configured speed'
    'm4.ram.manufacturer' = 'Manufacturer'
    'm4.ram.partnumber' = 'Part number'
    'm4.ram.formfactor' = 'Form factor'
    'm4.ram.soldered' = 'Fewer modules than slots, all from one brand: RAM may be soldered to the board (SMBIOS cannot tell).'
    'm4.disk.model' = 'Name / model'
    'm4.disk.type' = 'Media type'
    'm4.disk.bus' = 'Bus'
    'm4.disk.size' = 'Capacity'
    'm4.disk.health' = 'Health'
    'm4.disk.temp' = 'Temperature'
    'm4.disk.wear' = 'Wear'
    'm4.disk.poweron' = 'Power-on hours'
    'm4.disk.readerrors' = 'Read errors'
    'm4.disk.partition.letter' = 'Partition {0}:'
    'm4.disk.partition.n' = 'Partition {0}'
    'm4.disk.free.fmt' = '{0} ({1} free)'
    'm4.disk.temp.fmt' = '{0} °C'
    'm4.disk.wear.fmt' = '{0} %'
    'm4.disk.hours.fmt' = '{0} hours'
    'm4.mon.name' = 'Name'
    'm4.mon.year' = 'Year of manufacture'
    'm4.mon.serial' = 'Serial'
    'm4.mon.resolution' = 'Active resolution'
    'm4.mon.refresh' = 'Refresh rate'
    'm4.mon.hdr' = 'HDR'
    'm4.mon.hdr.on' = 'On ({0}/{1} monitors)'
    'm4.mon.summary' = '{0} monitor(s)'
    'm4.net.desc' = 'Device'
    'm4.net.speed' = 'Link speed'
    'm4.net.type' = 'Adapter type'
    'm4.net.mac' = 'MAC address'
    'm4.net.wifistd' = 'Wi-Fi standard'
    'm4.net.wifistd.na' = 'N/A (needs Wi-Fi API)'
    'm4.net.speed.gbps' = '{0} Gbps'
    'm4.net.speed.mbps' = '{0} Mbps'
    'm4.net.summary' = '{0} active adapter(s)'
    'm4.net.none.lbl' = 'Status'
    'm4.net.none' = 'No enabled network adapter'
    'm4.bat.designed' = 'Designed capacity'
    'm4.bat.full' = 'Current full-charge capacity'
    'm4.bat.wear' = 'Wear level'
    'm4.bat.cycles' = 'Charge cycles'
    'm4.bat.mwh' = '{0} mWh'
    'm4.bat.summary' = 'Wear {0}%'
    'm4.cputemp.summary' = 'No common sensor'
    'm4.cputemp.msg' = 'No readable sensor (Windows provides no common API; use your CPU vendor''s tool if needed). WinCare does not bundle third-party kernel drivers to read temperatures.'
    'm4.export.done' = 'Report exported: {0}'
    'm4.export.fail' = 'Could not export the report'
    'm4.export.time' = 'Exported at'
    'm4.export.version' = 'Exported by'
    'm4.export.masked' = 'Sensitive data (serials, MAC, UUID, user name) is masked — turn off "Mask sensitive data" in settings for the full version'
    'm4.report.header' = 'WinCare — DETAILED PC SPECS'
}

# ---------------------------------------------------------------------------
# HELPERS (dinh dang, che du lieu, map enum)
# ---------------------------------------------------------------------------
function Mask-WCSensitive {
    # Che du lieu nhay cam: giu 2 ky tu dau/cuoi, thay phan giua bang '••••'
    param([string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return $Text }
    if ($Text.Length -le 5) { return '••••' }
    return ($Text.Substring(0, 2) + '••••' + $Text.Substring($Text.Length - 2))
}

function ConvertTo-WCM4ShortReason {
    # Rut ngan ly do loi cho vao chuoi "Khong doc duoc (...)"
    param($Reason)
    $s = [string]$Reason
    if ([string]::IsNullOrWhiteSpace($s)) { return (T 'm4.reason.unknown') }
    $s = $s -replace "`r|`n", ' '
    if ($s.Length -gt 70) { $s = $s.Substring(0, 70) + '…' }
    return $s.Trim()
}

function ConvertTo-WCM4ShortText {
    # Cat chuoi dai de lam dong tom tat Expander
    param([string]$Text, [int]$Max = 80)
    if ([string]::IsNullOrEmpty($Text)) { return '' }
    if ($Text.Length -le $Max) { return $Text }
    return ($Text.Substring(0, ($Max - 1)) + '…')
}

function Get-WCM4Inv {
    # Culture Invariant an toan ca tren UI lan worker runspace
    $inv = Get-WCState 'WcInv'
    if ($null -eq $inv) { $inv = [Globalization.CultureInfo]::InvariantCulture }
    return $inv
}

function Get-WCM4Val {
    # Gia tri null/thieu -> "Khong doc duoc (thieu du lieu)" - khong de trong
    param($Value)
    if ($null -eq $Value) { return (T 'm4.notread' @((T 'm4.reason.missing'))) }
    $s = [string]$Value
    if ([string]::IsNullOrWhiteSpace($s)) { return (T 'm4.notread' @((T 'm4.reason.missing'))) }
    return $s.Trim()
}

function Get-WCM4List {
    # Chuan hoa mot gia tri (co the null/mang) thanh MANG that su (khong bi unwrap)
    param($Value)
    $list = @($Value)
    if ($list.Count -eq 0) { return ,@() }
    if (($list.Count -eq 1) -and ($null -eq $list[0])) { return ,@() }
    return ,$list
}

function Get-WCM4Member {
    # Doc thanh vien an toan cho ca hashtable (chay that) va PSCustomObject (fixture)
    param($Obj, [string]$Name)
    if ($null -eq $Obj) { return $null }
    if ($Obj -is [hashtable]) { return $Obj[$Name] }
    return (Get-WCProp $Obj $Name)
}

function ConvertTo-WCM4DateText {
    # DMTF/DateTime/string -> 'dd/MM/yyyy HH:mm' (InvariantCulture)
    param($Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [DateTime]) { return $Value.ToString('dd/MM/yyyy HH:mm', (Get-WCM4Inv)) }
    $s = [string]$Value
    if ([string]::IsNullOrWhiteSpace($s)) { return $null }
    try {
        return ([DateTime]::Parse($s, (Get-WCM4Inv))).ToString('dd/MM/yyyy HH:mm', (Get-WCM4Inv))
    } catch { }
    return $s
}

function Get-WCM4UptimeText {
    param($LastBoot)
    if ($null -eq $LastBoot) { return $null }
    try {
        $boot = $null
        if ($LastBoot -is [DateTime]) { $boot = $LastBoot }
        else { $boot = [DateTime]::Parse([string]$LastBoot, (Get-WCM4Inv)) }
        $span = [DateTime]::Now - $boot
        if ($span.TotalSeconds -lt 0) { return $null }
        return (T 'm4.uptime.fmt' @([int]$span.TotalDays, [int]$span.Hours, [int]$span.Minutes))
    } catch { return $null }
}

function Get-WCM4RamTypeText {
    # Map SMBIOSMemoryType theo tai lieu WMI (spec M4)
    param($Code)
    if ($null -eq $Code) { return (T 'common.unknown') }
    switch ([int]$Code) {
        20 { return 'DDR' }
        21 { return 'DDR2' }
        24 { return 'DDR3' }
        26 { return 'DDR4' }
        30 { return 'LPDDR4' }
        34 { return 'DDR5' }
        35 { return 'LPDDR5' }
    }
    return (T 'common.unknown')
}

function Get-WCM4FormFactorText {
    param($Code)
    if ($null -eq $Code) { return (T 'common.unknown') }
    switch ([int]$Code) {
        8  { return 'DIMM' }
        12 { return 'SODIMM' }
    }
    return (T 'common.unknown')
}

function Get-WCM4CpuArchText {
    param($Code)
    if ($null -eq $Code) { return (T 'common.unknown') }
    switch ([int]$Code) {
        0  { return 'x86' }
        5  { return 'ARM' }
        9  { return 'x64' }
        12 { return 'ARM64' }
    }
    return (T 'common.unknown')
}

function Get-WCM4FirmwareText {
    # UEFI/Legacy: registry PEFirmwareType (2=UEFI, 1=Legacy) -> env firmware_type
    param($RegValue)
    if ($null -ne $RegValue) {
        $s = [string]$RegValue
        $code = 0
        if ([int]::TryParse($s, [ref]$code)) {
            if ($code -eq 2) { return (T 'm4.sys.firmware.uefi') }
            if ($code -eq 1) { return (T 'm4.sys.firmware.legacy') }
        } else {
            if ($s -like '*UEFI*') { return (T 'm4.sys.firmware.uefi') }
            if ($s -like '*Legacy*') { return (T 'm4.sys.firmware.legacy') }
        }
    }
    $envFw = [string]$env:firmware_type
    if ($envFw -like '*UEFI*') { return (T 'm4.sys.firmware.uefi') }
    if ($envFw -like '*Legacy*') { return (T 'm4.sys.firmware.legacy') }
    return (T 'common.unknown')
}

function Get-WCM4GpuVendorText {
    # Parse VEN_xxxx tu PNPDeviceID; fallback AdapterCompatibility
    param([string]$PnpId, [string]$AdapterCompat)
    $code = ''
    if (-not [string]::IsNullOrEmpty($PnpId)) {
        if ($PnpId -match 'VEN_([0-9A-Fa-f]{4})') { $code = $Matches[1].ToUpperInvariant() }
    }
    if ($code -eq '10DE') { return 'NVIDIA' }
    if ($code -eq '8086') { return 'Intel' }
    if ($code -eq '1002') { return 'AMD' }
    if (-not [string]::IsNullOrWhiteSpace($AdapterCompat)) { return $AdapterCompat.Trim() }
    if ($code -ne '') { return (T 'm4.gpu.vendor.unknownven' @($code)) }
    return (T 'common.unknown')
}

function Test-WCM4IntegratedGpu {
    # GPU tich hop theo ten (Intel Iris/UHD/HD, AMD "Radeon Graphics")
    # Ten WMI thuong chua (R)/(TM) -> bo marker truoc khi so khop
    param([string]$Name)
    if ([string]::IsNullOrEmpty($Name)) { return $false }
    $n = ($Name -replace '\((R|TM|C)\)', '')
    foreach ($pat in @('*Iris Xe*', '*Iris Plus*', '*Iris Pro*', '*UHD Graphics*', '*HD Graphics*', '*Radeon Graphics*')) {
        if ($n -like $pat) { return $true }
    }
    return $false
}

function Test-WCM4VirtualGpu {
    # Adapter ao bi an mac dinh (spec M4); bo marker (R)/(TM) khi so khop
    param([string]$Name)
    if ([string]::IsNullOrEmpty($Name)) { return $false }
    $n = ($Name -replace '\((R|TM|C)\)', '')
    foreach ($pat in @('*Basic Display*', '*Hyper-V*', '*Virtual*', '*Remote Display*', '*Parallels*', '*VMware*', '*VirtualBox*')) {
        if ($n -like $pat) { return $true }
    }
    return $false
}

function Get-WCM4NvidiaSmiInfo {
    # nvidia-smi neu co: CSV so InvariantCulture, khong phai output bi dia phuong hoa
    $path = $null
    try {
        $cmd = Get-Command -Name nvidia-smi -ErrorAction SilentlyContinue
        if ($cmd) { $path = $cmd.Source }
    } catch { }
    if (-not $path) {
        if ($env:SystemRoot) {
            $p = Join-Path $env:SystemRoot 'System32\nvidia-smi.exe'
            if (Test-Path -LiteralPath $p) { $path = $p }
        }
    }
    if (-not $path) { return $null }
    try {
        $raw = (& $path '--query-gpu=temperature.gpu,clocks.sm,utilization.gpu' '--format=csv,noheader' | Out-String)
    } catch { return $null }
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    $inv = Get-WCM4Inv
    $list = @()
    foreach ($ln in @($raw -split "`r?`n")) {
        $ln = $ln.Trim()
        if ($ln -eq '') { continue }
        $parts = $ln -split ','
        if ($parts.Count -lt 3) { continue }
        $temp = $null; $clock = $null; $util = $null
        $v = 0
        if ([int]::TryParse($parts[0].Trim(), [System.Globalization.NumberStyles]::Integer, $inv, [ref]$v)) { $temp = $v }
        $v = 0
        if ([int]::TryParse($parts[1].Trim(), [System.Globalization.NumberStyles]::Integer, $inv, [ref]$v)) { $clock = $v }
        $v = 0
        if ([int]::TryParse($parts[2].Trim(), [System.Globalization.NumberStyles]::Integer, $inv, [ref]$v)) { $util = $v }
        $list += @{ Temp = $temp; Clock = $clock; Util = $util }
    }
    if ($list.Count -eq 0) { return $null }
    return ,$list
}

function Get-WCM4MediaTypeText {
    # Get-PhysicalDisk.MediaType: thuong la chuoi; so = map theo tai lieu Storage
    param($Value)
    if ($null -eq $Value) { return (T 'common.unknown') }
    if ($Value -is [string]) {
        if ($Value -ne '') { return $Value }
        return (T 'common.unknown')
    }
    switch ([int]$Value) {
        3 { return 'HDD' }
        4 { return 'SSD' }
        5 { return 'SCM' }
    }
    return (T 'common.unknown')
}

function Get-WCM4BusTypeText {
    param($Value)
    if ($null -eq $Value) { return (T 'common.unknown') }
    if ($Value -is [string]) {
        if ($Value -ne '') { return $Value }
        return (T 'common.unknown')
    }
    switch ([int]$Value) {
        7  { return 'NVMe' }
        8  { return 'SATA' }
        9  { return 'SAS' }
        10 { return 'RAID' }
        11 { return 'USB' }
    }
    # ma khong ro -> hien ma goc, khong doan
    return ('BusType ' + [string][int]$Value)
}

# ---------------------------------------------------------------------------
# MODEL (du lieu thuan cho UI + bao cao; chi chua string/bool/mang)
# ---------------------------------------------------------------------------
function New-WCM4Field {
    param([string]$Label, $Value, [string]$Raw = '', [switch]$Sensitive, [switch]$Mono)
    return @{
        Kind = 'field'; Label = $Label; Value = [string]$Value
        Raw = $Raw; Sensitive = [bool]$Sensitive; Mono = [bool]$Mono
    }
}

function New-WCM4HeaderRow {
    param([string]$Text)
    return @{ Kind = 'header'; Label = $Text; Value = $Text; Raw = $Text; Sensitive = $false; Mono = $false }
}

function New-WCM4GroupModel {
    param([string]$Key, [string]$BaseKey, [string]$Title, [string]$Summary, $Rows,
          [string]$Note = '', [bool]$Virtual = $false, [bool]$Absent = $false)
    return @{
        Key = $Key; BaseKey = $BaseKey; Title = $Title; Summary = $Summary
        Rows = @($Rows); Note = $Note; Virtual = $Virtual; Absent = $Absent
    }
}

function New-WCM4ErrorGroupModel {
    param([string]$Key, [string]$BaseKey, [string]$Title, [string]$Reason)
    return (New-WCM4GroupModel -Key $Key -BaseKey $BaseKey -Title $Title -Summary '' `
        -Rows @((New-WCM4Field -Label $Title -Value (T 'm4.notread' @((ConvertTo-WCM4ShortReason $Reason))))))
}

# ---------------------------------------------------------------------------
# BO THU THAP DU LIEU (chay trong worker; moi nhom 1 key Invoke-WCQuery)
# ---------------------------------------------------------------------------
function Get-WCM4SystemModel {
    # Nhom He thong: CIM + registry + SecureBoot/TPM, moi nguon con boc loi rieng
    $r = Invoke-WCQuery -Key 'specs.os' -CacheTtlSec 60 -Script {
        $b = [PSCustomObject]@{
            CS = $null; OS = $null; BIOS = $null; Board = $null; Product = $null
            Firmware = $null; SecureBoot = $null; Tpm = $null; Errors = @{}
        }
        try { $b.OS = Get-CimInstance -ClassName Win32_OperatingSystem -OperationTimeoutSec 10 } catch { $b.Errors['OS'] = $_.Exception.Message }
        try { $b.CS = Get-CimInstance -ClassName Win32_ComputerSystem -OperationTimeoutSec 10 } catch { $b.Errors['CS'] = $_.Exception.Message }
        try { $b.BIOS = Get-CimInstance -ClassName Win32_BIOS -OperationTimeoutSec 10 } catch { $b.Errors['BIOS'] = $_.Exception.Message }
        try { $b.Board = Get-CimInstance -ClassName Win32_BaseBoard -OperationTimeoutSec 10 } catch { $b.Errors['Board'] = $_.Exception.Message }
        try { $b.Product = Get-CimInstance -ClassName Win32_ComputerSystemProduct -OperationTimeoutSec 10 } catch { $b.Errors['Product'] = $_.Exception.Message }
        try { $b.Firmware = Get-WCRegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control' -Name 'PEFirmwareType' } catch { $b.Firmware = $null }
        try { $b.SecureBoot = (Confirm-SecureBootUEFI -ErrorAction Stop) } catch { $b.SecureBoot = $null }
        try { $b.Tpm = (Get-Tpm -ErrorAction Stop) } catch { $b.Tpm = $null }
        $b
    }
    $d = $r.Data
    $err = @{}
    $errObj = Get-WCProp $d 'Errors'
    if ($errObj -is [hashtable]) { $err = $errObj }
    elseif ($errObj) {
        foreach ($k in @('OS', 'CS', 'BIOS', 'Board', 'Product')) {
            $v = Get-WCProp $errObj $k
            if ($null -ne $v) { $err[$k] = [string]$v }
        }
    }
    $cs = Get-WCProp $d 'CS'; $os = Get-WCProp $d 'OS'; $bios = Get-WCProp $d 'BIOS'
    $board = Get-WCProp $d 'Board'; $product = Get-WCProp $d 'Product'

    $rows = @()
    if ($cs) {
        $rows += (New-WCM4Field -Label (T 'm4.sys.manufacturer') -Value (Get-WCM4Val (Get-WCProp $cs 'Manufacturer')))
        $rows += (New-WCM4Field -Label (T 'm4.sys.model') -Value (Get-WCM4Val (Get-WCProp $cs 'Model')))
        $tp = Get-WCProp $cs 'TotalPhysicalMemory'
        $tpTxt = (T 'm4.notread' @('CIM'))
        if ($null -ne $tp) { $tpTxt = (ConvertTo-WCHumanSize ([long]$tp)) }
        $rows += (New-WCM4Field -Label (T 'm4.sys.ramtotal') -Value $tpTxt)
        $user = [string](Get-WCProp $cs 'UserName')
        $userShown = (T 'm4.notread' @('CIM'))
        if (-not [string]::IsNullOrWhiteSpace($user)) {
            $userShown = $user
            if (Test-WCMaskMode) { $userShown = (Mask-WCSensitive $user) }
        }
        $rows += (New-WCM4Field -Label (T 'm4.sys.user') -Value $userShown -Raw $user -Sensitive)
    } else {
        $rows += (New-WCM4Field -Label (T 'm4.src.cs') -Value (T 'm4.notread' @((ConvertTo-WCM4ShortReason $err['CS']))))
    }

    if ($os) {
        $rows += (New-WCM4Field -Label (T 'm4.sys.os') -Value (Get-WCM4Val (Get-WCProp $os 'Caption')))
        $rows += (New-WCM4Field -Label (T 'm4.sys.osversion') -Value (Get-WCM4Val (Get-WCProp $os 'Version')))
        $rows += (New-WCM4Field -Label (T 'm4.sys.build') -Value (Get-WCM4Val (Get-WCProp $os 'BuildNumber')))
        $rows += (New-WCM4Field -Label (T 'm4.sys.arch') -Value (Get-WCM4Val (Get-WCProp $os 'OSArchitecture')))
        $rows += (New-WCM4Field -Label (T 'm4.sys.installdate') -Value (Get-WCM4Val (ConvertTo-WCM4DateText (Get-WCProp $os 'InstallDate'))))
        $upTxt = (Get-WCM4UptimeText (Get-WCProp $os 'LastBootUpTime'))
        if (-not $upTxt) { $upTxt = (T 'm4.notread' @('CIM')) }
        $rows += (New-WCM4Field -Label (T 'm4.sys.uptime') -Value $upTxt)
        $rows += (New-WCM4Field -Label (T 'm4.sys.sysdrive') -Value (Get-WCM4Val (Get-WCProp $os 'SystemDrive')))
    } else {
        $rows += (New-WCM4Field -Label (T 'm4.src.os') -Value (T 'm4.notread' @((ConvertTo-WCM4ShortReason $err['OS']))))
    }

    $rows += (New-WCM4Field -Label (T 'm4.sys.firmware') -Value (Get-WCM4FirmwareText (Get-WCProp $d 'Firmware')))

    $sbVal = Get-WCProp $d 'SecureBoot'
    $sbTxt = (T 'common.unknown')
    if ($sbVal -is [bool]) {
        if ($sbVal) { $sbTxt = (T 'm4.on') } else { $sbTxt = (T 'm4.off') }
    }
    $rows += (New-WCM4Field -Label (T 'm4.sys.secureboot') -Value $sbTxt)

    $tpm = Get-WCProp $d 'Tpm'
    $tpmTxt = $null
    if ($tpm) {
        $ready = Get-WCProp $tpm 'TpmReady'
        $manu = ([string](Get-WCProp $tpm 'ManufacturerIdTxt')).Trim()
        if ($ready -is [bool]) {
            if ($ready) {
                if ($manu) { $tpmTxt = (T 'm4.sys.tpm.ready' @($manu)) } else { $tpmTxt = (T 'm4.on') }
            } else {
                if ($manu) { $tpmTxt = (T 'm4.sys.tpm.notready' @($manu)) } else { $tpmTxt = (T 'm4.off') }
            }
        }
    }
    if (-not $tpmTxt) { $tpmTxt = (T 'm4.notread' @('Get-Tpm')) }
    $rows += (New-WCM4Field -Label (T 'm4.sys.tpm') -Value $tpmTxt)

    if ($bios) {
        $rows += (New-WCM4Field -Label (T 'm4.sys.biosver') -Value (Get-WCM4Val (Get-WCProp $bios 'SMBIOSBIOSVersion')))
        $rows += (New-WCM4Field -Label (T 'm4.sys.biosdate') -Value (Get-WCM4Val (ConvertTo-WCM4DateText (Get-WCProp $bios 'ReleaseDate'))))
        $bserial = ([string](Get-WCProp $bios 'SerialNumber')).Trim()
        $rows += (New-WCM4Field -Label (T 'm4.sys.biosserial') -Value (Get-WCM4Val $bserial) -Raw $bserial -Sensitive)
    } else {
        $rows += (New-WCM4Field -Label (T 'm4.src.bios') -Value (T 'm4.notread' @((ConvertTo-WCM4ShortReason $err['BIOS']))))
    }

    if ($board) {
        $bm = ([string](Get-WCProp $board 'Manufacturer')).Trim()
        $bp = ([string](Get-WCProp $board 'Product')).Trim()
        $boardTxt = ''
        if ($bm) { $boardTxt = $bm }
        if ($bp) {
            if ($boardTxt) { $boardTxt = $boardTxt + ' ' + $bp } else { $boardTxt = $bp }
        }
        if (-not $boardTxt) { $boardTxt = (T 'm4.notread' @((T 'm4.reason.missing'))) }
        $rows += (New-WCM4Field -Label (T 'm4.sys.board') -Value $boardTxt)
        $bser = ([string](Get-WCProp $board 'SerialNumber')).Trim()
        $rows += (New-WCM4Field -Label (T 'm4.sys.boardserial') -Value (Get-WCM4Val $bser) -Raw $bser -Sensitive)
    } else {
        $rows += (New-WCM4Field -Label (T 'm4.src.board') -Value (T 'm4.notread' @((ConvertTo-WCM4ShortReason $err['Board']))))
    }

    if ($product) {
        $uuid = ([string](Get-WCProp $product 'UUID')).Trim()
        $rows += (New-WCM4Field -Label (T 'm4.sys.uuid') -Value (Get-WCM4Val $uuid) -Raw $uuid -Sensitive -Mono)
    } else {
        $rows += (New-WCM4Field -Label (T 'm4.src.product') -Value (T 'm4.notread' @((ConvertTo-WCM4ShortReason $err['Product']))))
    }

    $sumParts = @()
    $mm = (([string](Get-WCProp $cs 'Manufacturer')).Trim() + ' ' + ([string](Get-WCProp $cs 'Model')).Trim()).Trim()
    if ($mm) { $sumParts += $mm }
    $caption = ([string](Get-WCProp $os 'Caption')).Trim()
    if ($caption) { $sumParts += $caption }
    return (New-WCM4GroupModel -Key 'system' -BaseKey 'system' -Title (T 'm4.grp.system') `
        -Summary ([string]::Join(' — ', $sumParts)) -Rows $rows)
}

function Get-WCM4CpuModels {
    # Nhieu socket -> moi socket mot model (spec M4)
    $r = Invoke-WCQuery -Key 'specs.cpu' -CacheTtlSec 60 -Script {
        Get-CimInstance -ClassName Win32_Processor -OperationTimeoutSec 10
    }
    if ($r.Status -ne 'Ok') {
        return @(New-WCM4ErrorGroupModel -Key 'cpu:0' -BaseKey 'cpu' -Title (T 'm4.grp.cpu') -Reason $r.Reason)
    }
    $list = Get-WCM4List $r.Data
    if ($list.Count -eq 0) {
        return @(New-WCM4ErrorGroupModel -Key 'cpu:0' -BaseKey 'cpu' -Title (T 'm4.grp.cpu') -Reason (T 'm4.reason.missing'))
    }
    $models = @()
    $i = 0
    foreach ($cpu in $list) {
        $rows = @()
        $name = ([string](Get-WCProp $cpu 'Name')).Trim()
        try { $name = ([regex]::Replace($name, '\s+', ' ')).Trim() } catch { }
        $rows += (New-WCM4Field -Label (T 'm4.cpu.name') -Value (Get-WCM4Val $name))
        $cores = Get-WCProp $cpu 'NumberOfCores'
        $coresTxt = (T 'common.na')
        if ($null -ne $cores) { $coresTxt = [string][int]$cores }
        $rows += (New-WCM4Field -Label (T 'm4.cpu.cores') -Value $coresTxt)
        $threads = Get-WCProp $cpu 'NumberOfLogicalProcessors'
        $threadsTxt = (T 'common.na')
        if ($null -ne $threads) { $threadsTxt = [string][int]$threads }
        $rows += (New-WCM4Field -Label (T 'm4.cpu.threads') -Value $threadsTxt)
        $maxClk = Get-WCProp $cpu 'MaxClockSpeed'
        $maxTxt = (T 'common.na')
        if ($null -ne $maxClk) { $maxTxt = (T 'm4.mhz' @([int]$maxClk)) }
        $rows += (New-WCM4Field -Label (T 'm4.cpu.maxclock') -Value $maxTxt)
        $curClk = Get-WCProp $cpu 'CurrentClockSpeed'
        $curTxt = (T 'common.na')
        if ($null -ne $curClk) { $curTxt = (T 'm4.mhz' @([int]$curClk)) }
        $rows += (New-WCM4Field -Label (T 'm4.cpu.curclock') -Value $curTxt)
        foreach ($cacheDef in @(@{ Key = 'L2CacheSize'; Lbl = 'm4.cpu.l2' }, @{ Key = 'L3CacheSize'; Lbl = 'm4.cpu.l3' })) {
            $kb = Get-WCProp $cpu $cacheDef.Key
            $cTxt = (T 'common.na')
            if ($null -ne $kb) {
                if ([long]$kb -ge 1024) { $cTxt = ('{0:N1} MB' -f ([long]$kb / 1024.0)) }
                else { $cTxt = ('{0} KB' -f [long]$kb) }
            }
            $rows += (New-WCM4Field -Label (T $cacheDef.Lbl) -Value $cTxt)
        }
        $sock = ([string](Get-WCProp $cpu 'SocketDesignation')).Trim()
        $sockTxt = (T 'common.na')
        if ($sock) { $sockTxt = $sock }
        $rows += (New-WCM4Field -Label (T 'm4.cpu.socket') -Value $sockTxt)
        $rows += (New-WCM4Field -Label (T 'm4.cpu.arch') -Value (Get-WCM4CpuArchText (Get-WCProp $cpu 'Architecture')))
        $virt = Get-WCProp $cpu 'VirtualizationFirmwareEnabled'
        $virtTxt = (T 'common.na')
        if ($virt -is [bool]) {
            if ($virt) { $virtTxt = (T 'm4.on') } else { $virtTxt = (T 'm4.off') }
        }
        $rows += (New-WCM4Field -Label (T 'm4.cpu.virt') -Value $virtTxt)
        $load = Get-WCProp $cpu 'LoadPercentage'
        $loadTxt = (T 'common.na')
        if ($null -ne $load) { $loadTxt = (T 'm4.pct' @([int]$load)) }
        $rows += (New-WCM4Field -Label (T 'm4.cpu.load') -Value $loadTxt)

        $title = (T 'm4.grp.cpu')
        if ($list.Count -gt 1) { $title = (T 'm4.cpu.n' @($i + 1)) }
        $models += (New-WCM4GroupModel -Key ('cpu:' + $i) -BaseKey 'cpu' -Title $title -Summary $name -Rows $rows)
        $i++
    }
    return $models
}

function Get-WCM4GpuModels {
    # VRAM: KHONG dung AdapterRAM (uint32 tran 4GB) - doc registry lop Display
    $r = Invoke-WCQuery -Key 'specs.gpu' -CacheTtlSec 60 -Script {
        $b = [PSCustomObject]@{ Vcs = @(); Vram = @(); Smi = $null; Errors = @{} }
        try { $b.Vcs = @(Get-CimInstance -ClassName Win32_VideoController -OperationTimeoutSec 10) } catch { $b.Errors['Vcs'] = $_.Exception.Message }
        # Doc truoc VRAM cua cac subkey 0000..0015 (REG_QWORD qwMemorySize)
        $vramList = @()
        for ($i = 0; $i -lt 16; $i++) {
            $bytes = $null
            try {
                $p = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\' + ('{0:D4}' -f $i)
                if (Test-Path -LiteralPath $p) {
                    $bytes = Get-WCRegistryValue -Path $p -Name 'HardwareInformation.qwMemorySize'
                }
            } catch { $bytes = $null }
            if ($null -ne $bytes) { $vramList += [long]$bytes } else { $vramList += [long](-1) }
        }
        $b.Vram = $vramList
        try { $b.Smi = Get-WCM4NvidiaSmiInfo } catch { $b.Smi = $null }
        $b
    }
    $d = $r.Data
    $vcs = Get-WCM4List (Get-WCProp $d 'Vcs')
    if ($vcs.Count -eq 0) {
        $reason = $r.Reason
        $errObj = Get-WCProp $d 'Errors'
        if ($errObj -is [hashtable]) { $reason = [string]$errObj['Vcs'] }
        return @(New-WCM4ErrorGroupModel -Key 'gpu:0' -BaseKey 'gpu' -Title (T 'm4.grp.gpu') -Reason $reason)
    }
    $vramList = Get-WCM4List (Get-WCProp $d 'Vram')
    $smi = Get-WCM4List (Get-WCProp $d 'Smi')

    $models = @()
    $nvidiaIdx = 0
    $i = 0
    foreach ($vc in $vcs) {
        $name = ([string](Get-WCProp $vc 'Name')).Trim()
        $integrated = (Test-WCM4IntegratedGpu $name)
        $virtual = (Test-WCM4VirtualGpu $name)
        $vendor = (Get-WCM4GpuVendorText ([string](Get-WCProp $vc 'PNPDeviceID')) ([string](Get-WCProp $vc 'AdapterCompatibility')))

        $rows = @()
        $rows += (New-WCM4Field -Label (T 'm4.gpu.name') -Value (Get-WCM4Val $name))
        $typeTxt = (T 'm4.gpu.type.discrete')
        if ($integrated) { $typeTxt = (T 'm4.gpu.type.integrated') }
        $rows += (New-WCM4Field -Label (T 'm4.gpu.type') -Value $typeTxt)
        $rows += (New-WCM4Field -Label (T 'm4.gpu.vendor') -Value $vendor)
        $rows += (New-WCM4Field -Label (T 'm4.gpu.driver') -Value (Get-WCM4Val (Get-WCProp $vc 'DriverVersion')))
        $rows += (New-WCM4Field -Label (T 'm4.gpu.driverdate') -Value (Get-WCM4Val (ConvertTo-WCM4DateText (Get-WCProp $vc 'DriverDate'))))

        $h = Get-WCProp $vc 'CurrentHorizontalResolution'
        $v2 = Get-WCProp $vc 'CurrentVerticalResolution'
        $resTxt = (T 'common.na')
        if (($null -ne $h) -and ($null -ne $v2) -and ([long]$h -gt 0) -and ([long]$v2 -gt 0)) {
            $resTxt = ('{0} × {1}' -f [long]$h, [long]$v2)
        }
        $rows += (New-WCM4Field -Label (T 'm4.gpu.resolution') -Value $resTxt)
        $rr = Get-WCProp $vc 'CurrentRefreshRate'
        $rrTxt = (T 'common.na')
        if (($null -ne $rr) -and ([long]$rr -gt 0)) { $rrTxt = (T 'm4.hz' @([long]$rr)) }
        $rows += (New-WCM4Field -Label (T 'm4.gpu.refresh') -Value $rrTxt)

        $vramText = ''
        $vramShort = ''
        if ($integrated) {
            $vramText = (T 'm4.gpu.vram.shared')
            $vramShort = $vramText
        } else {
            $bytes = [long](-1)
            if ($i -lt $vramList.Count) { $bytes = [long]$vramList[$i] }
            if ($bytes -gt 0) {
                $vramText = (ConvertTo-WCHumanSize $bytes)
                $vramShort = $vramText
            } else {
                $vramText = (T 'm4.notread' @('registry qwMemorySize'))
                $vramShort = (T 'common.na')
            }
        }
        $rows += (New-WCM4Field -Label (T 'm4.gpu.vram') -Value $vramText)

        if ($vendor -eq 'NVIDIA') {
            $info = $null
            if ($nvidiaIdx -lt $smi.Count) { $info = $smi[$nvidiaIdx] }
            $tempVal = (Get-WCM4Member $info 'Temp')
            $clockVal = (Get-WCM4Member $info 'Clock')
            $utilVal = (Get-WCM4Member $info 'Util')
            $tempTxt = (T 'common.na'); $clockTxt = (T 'common.na'); $utilTxt = (T 'common.na')
            if ($null -ne $tempVal) { $tempTxt = (T 'm4.gpu.smi.temp' @([int]$tempVal)) }
            if ($null -ne $clockVal) { $clockTxt = (T 'm4.mhz' @([int]$clockVal)) }
            if ($null -ne $utilVal) { $utilTxt = (T 'm4.pct' @([int]$utilVal)) }
            $rows += (New-WCM4Field -Label (T 'm4.gpu.temp') -Value $tempTxt)
            $rows += (New-WCM4Field -Label (T 'm4.gpu.clock') -Value $clockTxt)
            $rows += (New-WCM4Field -Label (T 'm4.gpu.util') -Value $utilTxt)
            $nvidiaIdx++
        }

        $note = (T 'm4.gpu.ordernote')
        if ($virtual) { $note = $note + ' ' + (T 'm4.gpu.virtualnote') }
        $title = (T 'm4.grp.gpu')
        if ($vcs.Count -gt 1) { $title = (T 'm4.gpu.n' @($i + 1)) }
        $models += (New-WCM4GroupModel -Key ('gpu:' + $i) -BaseKey 'gpu' -Title $title `
            -Summary ($name + ' · ' + $vramShort) -Rows $rows -Note $note -Virtual $virtual)
        $i++
    }
    return $models
}

function Get-WCM4RamModel {
    $r = Invoke-WCQuery -Key 'specs.ram' -CacheTtlSec 60 -Script {
        $b = [PSCustomObject]@{ PM = @(); PMA = @(); CSTotal = $null; OsMem = $null; Errors = @{} }
        try { $b.PM = @(Get-CimInstance -ClassName Win32_PhysicalMemory -OperationTimeoutSec 10) } catch { $b.Errors['PM'] = $_.Exception.Message }
        try { $b.PMA = @(Get-CimInstance -ClassName Win32_PhysicalMemoryArray -OperationTimeoutSec 10) } catch { $b.Errors['PMA'] = $_.Exception.Message }
        try { $b.CSTotal = Get-CimInstance -ClassName Win32_ComputerSystem -Property TotalPhysicalMemory -OperationTimeoutSec 10 } catch { $b.Errors['CS'] = $_.Exception.Message }
        try { $b.OsMem = Get-CimInstance -ClassName Win32_OperatingSystem -Property TotalVisibleMemorySize,FreePhysicalMemory -OperationTimeoutSec 10 } catch { $b.Errors['OS'] = $_.Exception.Message }
        $b
    }
    $d = $r.Data
    $pm = Get-WCM4List (Get-WCProp $d 'PM')
    $pma = Get-WCM4List (Get-WCProp $d 'PMA')
    $csT = Get-WCProp $d 'CSTotal'
    $osMem = Get-WCProp $d 'OsMem'

    $rows = @()
    $tp = Get-WCProp $csT 'TotalPhysicalMemory'
    $totalTxt = (T 'm4.notread' @('CIM'))
    if ($null -ne $tp) { $totalTxt = (ConvertTo-WCHumanSize ([long]$tp)) }
    $rows += (New-WCM4Field -Label (T 'm4.ram.totalhw') -Value $totalTxt)

    $usedTxt = (T 'm4.notread' @('CIM'))
    $totKb = Get-WCProp $osMem 'TotalVisibleMemorySize'
    $freeKb = Get-WCProp $osMem 'FreePhysicalMemory'
    if (($null -ne $totKb) -and ($null -ne $freeKb) -and ([double]$totKb -gt 0)) {
        $usedKb = [double]$totKb - [double]$freeKb
        $pct = [math]::Round(($usedKb / [double]$totKb) * 100)
        $usedTxt = (T 'm4.ram.usedpct' @((ConvertTo-WCHumanSize ([long]($usedKb * 1KB))), $pct))
    }
    $rows += (New-WCM4Field -Label (T 'm4.ram.used') -Value $usedTxt)

    $maxSlots = $null
    if ($pma.Count -gt 0) { $maxSlots = Get-WCProp $pma[0] 'MemoryDevices' }
    $slotsTxt = (T 'm4.notread' @('Win32_PhysicalMemoryArray'))
    if ($null -ne $maxSlots) { $slotsTxt = ('{0} / {1}' -f $pm.Count, [int]$maxSlots) }
    $rows += (New-WCM4Field -Label (T 'm4.ram.slots') -Value $slotsTxt)

    $locTxt = (T 'common.na')
    if ($pma.Count -gt 0) {
        $loc = ([string](Get-WCProp $pma[0] 'Location')).Trim()
        if ($loc) { $locTxt = $loc }
    }
    $rows += (New-WCM4Field -Label (T 'm4.ram.location') -Value $locTxt)

    $manufacturers = @()
    $slotNo = 0
    foreach ($m in $pm) {
        $rows += (New-WCM4HeaderRow -Text (T 'm4.ram.slot.n' @($slotNo + 1)))
        $cap = Get-WCProp $m 'Capacity'
        $capTxt = (T 'common.na')
        if ($null -ne $cap) { $capTxt = (ConvertTo-WCHumanSize ([long]$cap)) }
        $rows += (New-WCM4Field -Label (T 'm4.ram.capacity') -Value $capTxt)
        $rows += (New-WCM4Field -Label (T 'm4.ram.type') -Value (Get-WCM4RamTypeText (Get-WCProp $m 'SMBIOSMemoryType')))
        $spd = Get-WCProp $m 'Speed'
        $spdTxt = (T 'common.na')
        if ($null -ne $spd) { $spdTxt = (T 'm4.mhz' @([int]$spd)) }
        $rows += (New-WCM4Field -Label (T 'm4.ram.speed') -Value $spdTxt)
        $cspd = Get-WCProp $m 'ConfiguredClockSpeed'
        $cspdTxt = (T 'common.na')
        if ($null -ne $cspd) { $cspdTxt = (T 'm4.mhz' @([int]$cspd)) }
        $rows += (New-WCM4Field -Label (T 'm4.ram.cspeed') -Value $cspdTxt)
        $manu = ([string](Get-WCProp $m 'Manufacturer')).Trim()
        $rows += (New-WCM4Field -Label (T 'm4.ram.manufacturer') -Value (Get-WCM4Val $manu))
        if ($manu) {
            if ($manufacturers -notcontains $manu) { $manufacturers += $manu }
        }
        $part = ([string](Get-WCProp $m 'PartNumber')).Trim()
        $rows += (New-WCM4Field -Label (T 'm4.ram.partnumber') -Value (Get-WCM4Val $part))
        $rows += (New-WCM4Field -Label (T 'm4.ram.formfactor') -Value (Get-WCM4FormFactorText (Get-WCProp $m 'FormFactor')))
        $slotNo++
    }

    $note = ''
    if (($null -ne $maxSlots) -and ($pm.Count -gt 0) -and ($pm.Count -lt [int]$maxSlots) -and ($manufacturers.Count -eq 1)) {
        $note = (T 'm4.ram.soldered')
    }

    $sumParts = @()
    if ($null -ne $tp) { $sumParts += $totalTxt }
    if ($null -ne $maxSlots) { $sumParts += ('{0}/{1} slot' -f $pm.Count, [int]$maxSlots) }
    return (New-WCM4GroupModel -Key 'ram' -BaseKey 'ram' -Title (T 'm4.grp.ram') `
        -Summary ([string]::Join(' · ', $sumParts)) -Rows $rows -Note $note)
}

function Get-WCM4DiskModels {
    # Get-PhysicalDisk + Get-StorageReliabilityCounter (null -> N/A) + phan vung
    $r = Invoke-WCQuery -Key 'specs.disks' -CacheTtlSec 60 -Script {
        $b = [PSCustomObject]@{ Disks = @(); Parts = @(); Logical = @(); Rel = @{}; Errors = @{} }
        try { $b.Disks = @(Get-PhysicalDisk -ErrorAction Stop) } catch { $b.Errors['Disks'] = $_.Exception.Message }
        try { $b.Parts = @(Get-Partition -ErrorAction Stop) } catch { $b.Errors['Parts'] = $_.Exception.Message }
        try { $b.Logical = @(Get-CimInstance -ClassName Win32_LogicalDisk -OperationTimeoutSec 10) } catch { $b.Errors['Logical'] = $_.Exception.Message }
        foreach ($disk in @($b.Disks)) {
            $num = 0
            $devId = [string](Get-WCProp $disk 'DeviceId')
            if (-not [int]::TryParse($devId, [ref]$num)) { continue }
            try { $b.Rel[$num] = (Get-StorageReliabilityCounter -DeviceNumber $num -ErrorAction Stop) } catch { }
        }
        $b
    }
    $d = $r.Data
    $disks = Get-WCM4List (Get-WCProp $d 'Disks')
    if ($disks.Count -eq 0) {
        $reason = $r.Reason
        $errObj = Get-WCProp $d 'Errors'
        if ($errObj -is [hashtable]) { $reason = [string]$errObj['Disks'] }
        return @(New-WCM4ErrorGroupModel -Key 'disk:0' -BaseKey 'disks' -Title (T 'm4.grp.disks') -Reason $reason)
    }
    $parts = Get-WCM4List (Get-WCProp $d 'Parts')
    $logical = Get-WCM4List (Get-WCProp $d 'Logical')
    $rel = Get-WCProp $d 'Rel'

    $models = @()
    $i = 0
    foreach ($disk in $disks) {
        $num = 0
        $devId = [string](Get-WCProp $disk 'DeviceId')
        $hasNum = [int]::TryParse($devId, [ref]$num)
        $rows = @()
        $friendly = ([string](Get-WCProp $disk 'FriendlyName')).Trim()
        $rows += (New-WCM4Field -Label (T 'm4.disk.model') -Value (Get-WCM4Val $friendly))
        $rows += (New-WCM4Field -Label (T 'm4.disk.type') -Value (Get-WCM4MediaTypeText (Get-WCProp $disk 'MediaType')))
        $rows += (New-WCM4Field -Label (T 'm4.disk.bus') -Value (Get-WCM4BusTypeText (Get-WCProp $disk 'BusType')))
        $sz = Get-WCProp $disk 'Size'
        $szTxt = (T 'm4.notread' @('CIM'))
        if ($null -ne $sz) { $szTxt = (ConvertTo-WCHumanSize ([long]$sz)) }
        $rows += (New-WCM4Field -Label (T 'm4.disk.size') -Value $szTxt)
        $rows += (New-WCM4Field -Label (T 'm4.disk.health') -Value (Get-WCM4Val (Get-WCProp $disk 'HealthStatus')))

        $counter = $null
        if ($hasNum) {
            if ($rel -is [hashtable]) {
                if ($rel.ContainsKey($num)) { $counter = $rel[$num] }
            } elseif ($rel) {
                # FIXTURE: JSON key la chuoi
                $counter = Get-WCProp $rel ([string]$num)
            }
        }
        $tempV = Get-WCProp $counter 'Temperature'
        $tempTxt = (T 'common.na')
        if ($null -ne $tempV) { $tempTxt = (T 'm4.disk.temp.fmt' @([int]$tempV)) }
        $rows += (New-WCM4Field -Label (T 'm4.disk.temp') -Value $tempTxt)
        $wearV = Get-WCProp $counter 'Wear'
        $wearTxt = (T 'common.na')
        if ($null -ne $wearV) { $wearTxt = (T 'm4.disk.wear.fmt' @([int]$wearV)) }
        $rows += (New-WCM4Field -Label (T 'm4.disk.wear') -Value $wearTxt)
        $pohV = Get-WCProp $counter 'PowerOnHours'
        $pohTxt = (T 'common.na')
        if ($null -ne $pohV) { $pohTxt = (T 'm4.disk.hours.fmt' @([long]$pohV)) }
        $rows += (New-WCM4Field -Label (T 'm4.disk.poweron') -Value $pohTxt)
        $reV = Get-WCProp $counter 'ReadErrorsTotal'
        $reTxt = (T 'common.na')
        if ($null -ne $reV) { $reTxt = [string][long]$reV }
        $rows += (New-WCM4Field -Label (T 'm4.disk.readerrors') -Value $reTxt)

        if ($hasNum) {
            foreach ($p in $parts) {
                $dn = Get-WCProp $p 'DiskNumber'
                if ($null -eq $dn) { continue }
                if ([int]$dn -ne $num) { continue }
                $letter = ([string](Get-WCProp $p 'DriveLetter')).Trim()
                $pSize = Get-WCProp $p 'Size'
                $pSizeTxt = (T 'common.na')
                if ($null -ne $pSize) { $pSizeTxt = (ConvertTo-WCHumanSize ([long]$pSize)) }
                if ($letter -ne '') {
                    foreach ($ld in $logical) {
                        if ((([string](Get-WCProp $ld 'DeviceID')).Trim()) -eq ($letter + ':')) {
                            $lsz = Get-WCProp $ld 'Size'
                            $lfr = Get-WCProp $ld 'FreeSpace'
                            if (($null -ne $lsz) -and ($null -ne $lfr)) {
                                $pSizeTxt = (T 'm4.disk.free.fmt' @((ConvertTo-WCHumanSize ([long]$lsz)), (ConvertTo-WCHumanSize ([long]$lfr))))
                            }
                            break
                        }
                    }
                    $rows += (New-WCM4Field -Label (T 'm4.disk.partition.letter' @($letter)) -Value $pSizeTxt)
                } else {
                    $pNum = Get-WCProp $p 'PartitionNumber'
                    $pNumTxt = '?'
                    if ($null -ne $pNum) { $pNumTxt = [string][int]$pNum }
                    $rows += (New-WCM4Field -Label (T 'm4.disk.partition.n' @($pNumTxt)) -Value $pSizeTxt)
                }
            }
        }

        $title = (T 'm4.grp.disks')
        if ($disks.Count -gt 1) { $title = (T 'm4.disk.n' @($i + 1)) }
        $sumParts = @()
        if ($friendly) { $sumParts += $friendly }
        if ($null -ne $sz) { $sumParts += $szTxt }
        $models += (New-WCM4GroupModel -Key ('disk:' + $i) -BaseKey 'disks' -Title $title `
            -Summary ([string]::Join(' · ', $sumParts)) -Rows $rows)
        $i++
    }
    return $models
}

function Get-WCM4MonitorModel {
    # WmiMonitorID (EDID) + do phan giai tu VideoController; HDR chi hien neu doc duoc
    $r = Invoke-WCQuery -Key 'specs.monitors' -CacheTtlSec 60 -Script {
        $b = [PSCustomObject]@{ Monitors = @(); Vcs = @(); Hdr = @(); Errors = @{} }
        try { $b.Monitors = @(Get-CimInstance -Namespace 'root\wmi' -ClassName 'WmiMonitorID' -OperationTimeoutSec 10 -ErrorAction Stop) } catch { $b.Errors['Monitors'] = $_.Exception.Message }
        try { $b.Vcs = @(Get-CimInstance -ClassName Win32_VideoController -Property Name,CurrentHorizontalResolution,CurrentVerticalResolution,CurrentRefreshRate -OperationTimeoutSec 10) } catch { $b.Errors['Vcs'] = $_.Exception.Message }
        # HDR: doc registry Graphics\Drivers, khong doc duoc thi khong hien (khong doan)
        $hdr = @()
        try {
            $gbase = 'HKLM:\SYSTEM\CurrentControlSet\Control\Graphics\Drivers'
            if (Test-Path -LiteralPath $gbase) {
                foreach ($ad in (Get-ChildItem -LiteralPath $gbase -ErrorAction SilentlyContinue)) {
                    $adPath = [string](Get-WCProp $ad 'PSPath')
                    if (-not $adPath) { continue }
                    foreach ($mon in (Get-ChildItem -LiteralPath $adPath -ErrorAction SilentlyContinue)) {
                        $monPath = [string](Get-WCProp $mon 'PSPath')
                        if (-not $monPath) { continue }
                        $hv = Get-WCRegistryValue -Path $monPath -Name 'AdvancedColorEnabled'
                        if ($null -ne $hv) { $hdr += [int]$hv }
                    }
                }
            }
        } catch { }
        $b.Hdr = $hdr
        $b
    }
    $d = $r.Data
    $mons = Get-WCM4List (Get-WCProp $d 'Monitors')
    if ($mons.Count -eq 0) {
        $reason = $r.Reason
        $errObj = Get-WCProp $d 'Errors'
        if ($errObj -is [hashtable]) { $reason = [string]$errObj['Monitors'] }
        return @(New-WCM4ErrorGroupModel -Key 'monitors' -BaseKey 'monitors' -Title (T 'm4.grp.monitors') -Reason $reason)
    }
    $vcs = Get-WCM4List (Get-WCProp $d 'Vcs')
    $hdrVals = Get-WCM4List (Get-WCProp $d 'Hdr')

    $rows = @()
    $i = 0
    foreach ($mon in $mons) {
        $name = (ConvertTo-WCSafeString (Get-WCProp $mon 'UserFriendlyName'))
        $headTxt = (T 'm4.mon.n' @($i + 1))
        if ($name) { $headTxt = $headTxt + ': ' + $name }
        $rows += (New-WCM4HeaderRow -Text $headTxt)
        $rows += (New-WCM4Field -Label (T 'm4.mon.name') -Value (Get-WCM4Val $name))
        $year = Get-WCProp $mon 'YearOfManufacture'
        $yearTxt = (T 'common.na')
        if (($null -ne $year) -and ([int]$year -gt 1980) -and ([int]$year -lt 2100)) { $yearTxt = [string][int]$year }
        $rows += (New-WCM4Field -Label (T 'm4.mon.year') -Value $yearTxt)
        $serial = (ConvertTo-WCSafeString (Get-WCProp $mon 'SerialNumber'))
        $rows += (New-WCM4Field -Label (T 'm4.mon.serial') -Value (Get-WCM4Val $serial) -Raw $serial -Sensitive)
        $i++
    }

    $modes = @()
    $rates = @()
    foreach ($vc in $vcs) {
        $h = Get-WCProp $vc 'CurrentHorizontalResolution'
        $v2 = Get-WCProp $vc 'CurrentVerticalResolution'
        if (($null -ne $h) -and ($null -ne $v2) -and ([long]$h -gt 0) -and ([long]$v2 -gt 0)) {
            $mode = ('{0} × {1}' -f [long]$h, [long]$v2)
            if ($modes -notcontains $mode) { $modes += $mode }
        }
        $rr = Get-WCProp $vc 'CurrentRefreshRate'
        if (($null -ne $rr) -and ([long]$rr -gt 0)) {
            $rate = (T 'm4.hz' @([long]$rr))
            if ($rates -notcontains $rate) { $rates += $rate }
        }
    }
    $resTxt = (T 'm4.notread' @('Win32_VideoController'))
    if ($vcs.Count -gt 0) {
        $resTxt = (T 'common.na')
        if ($modes.Count -gt 0) { $resTxt = [string]::Join('; ', $modes) }
    }
    $rows += (New-WCM4Field -Label (T 'm4.mon.resolution') -Value $resTxt)
    $rrTxt = (T 'm4.notread' @('Win32_VideoController'))
    if ($vcs.Count -gt 0) {
        $rrTxt = (T 'common.na')
        if ($rates.Count -gt 0) { $rrTxt = [string]::Join('; ', $rates) }
    }
    $rows += (New-WCM4Field -Label (T 'm4.mon.refresh') -Value $rrTxt)

    if ($hdrVals.Count -gt 0) {
        $onCount = 0
        foreach ($hv in $hdrVals) {
            if ([int]$hv -eq 1) { $onCount++ }
        }
        if ($onCount -gt 0) {
            $rows += (New-WCM4Field -Label (T 'm4.mon.hdr') -Value (T 'm4.mon.hdr.on' @($onCount, $hdrVals.Count)))
        } else {
            $rows += (New-WCM4Field -Label (T 'm4.mon.hdr') -Value (T 'm4.off'))
        }
    }

    return (New-WCM4GroupModel -Key 'monitors' -BaseKey 'monitors' -Title (T 'm4.grp.monitors') `
        -Summary (T 'm4.mon.summary' @($mons.Count)) -Rows $rows)
}

function Get-WCM4NetModel {
    # Chi adapter NetEnabled=true; Wi-Fi khong parse CLI bi dia phuong hoa
    $r = Invoke-WCQuery -Key 'specs.net' -CacheTtlSec 60 -Script {
        $b = [PSCustomObject]@{ Adapters = @(); Errors = @{} }
        try { $b.Adapters = @(Get-CimInstance -ClassName Win32_NetworkAdapter -OperationTimeoutSec 10) } catch { $b.Errors['Adapters'] = $_.Exception.Message }
        $b
    }
    $d = $r.Data
    $all = Get-WCM4List (Get-WCProp $d 'Adapters')
    $enabled = @()
    foreach ($a in $all) {
        if ((Get-WCProp $a 'NetEnabled') -eq $true) { $enabled += $a }
    }
    if ($all.Count -eq 0) {
        $reason = $r.Reason
        $errObj = Get-WCProp $d 'Errors'
        if ($errObj -is [hashtable]) { $reason = [string]$errObj['Adapters'] }
        return (New-WCM4ErrorGroupModel -Key 'net' -BaseKey 'net' -Title (T 'm4.grp.net') -Reason $reason)
    }
    $rows = @()
    if ($enabled.Count -eq 0) {
        $rows += (New-WCM4Field -Label (T 'm4.net.none.lbl') -Value (T 'm4.net.none'))
    }
    $i = 0
    foreach ($a in $enabled) {
        $connId = ([string](Get-WCProp $a 'NetConnectionID')).Trim()
        $headTxt = $connId
        if (-not $headTxt) { $headTxt = ('Adapter ' + ($i + 1)) }
        $rows += (New-WCM4HeaderRow -Text $headTxt)
        $rows += (New-WCM4Field -Label (T 'm4.net.desc') -Value (Get-WCM4Val (Get-WCProp $a 'Description')))
        $sp = Get-WCProp $a 'Speed'
        $spTxt = (T 'common.na')
        if ($null -ne $sp) {
            $spd = [double]$sp
            if ($spd -ge 1000000000) { $spTxt = (T 'm4.net.speed.gbps' @([math]::Round(($spd / 1000000000), 2))) }
            elseif ($spd -gt 0) { $spTxt = (T 'm4.net.speed.mbps' @([math]::Round(($spd / 1000000), 0))) }
        }
        $rows += (New-WCM4Field -Label (T 'm4.net.speed') -Value $spTxt)
        $rows += (New-WCM4Field -Label (T 'm4.net.type') -Value (Get-WCM4Val (Get-WCProp $a 'AdapterType')))
        $mac = ([string](Get-WCProp $a 'MACAddress')).Trim()
        $rows += (New-WCM4Field -Label (T 'm4.net.mac') -Value (Get-WCM4Val $mac) -Raw $mac -Sensitive -Mono)
        $at = [string](Get-WCProp $a 'AdapterType')
        $desc2 = [string](Get-WCProp $a 'Description')
        $isWifi = $false
        if ($at -like '*Wireless*') { $isWifi = $true }
        if ($desc2 -like '*Wi-Fi*' -or $desc2 -like '*Wireless*' -or $desc2 -like '*802.11*') { $isWifi = $true }
        if ($connId -like '*Wi-Fi*') { $isWifi = $true }
        if ($isWifi) {
            $rows += (New-WCM4Field -Label (T 'm4.net.wifistd') -Value (T 'm4.net.wifistd.na'))
        }
        $i++
    }
    return (New-WCM4GroupModel -Key 'net' -BaseKey 'net' -Title (T 'm4.grp.net') `
        -Summary (T 'm4.net.summary' @($enabled.Count)) -Rows $rows)
}

function Get-WCM4BatteryModel {
    # root\wmi BatteryStaticData / FullChargedCapacity / CycleCount; may khong pin -> Absent
    $r = Invoke-WCQuery -Key 'specs.battery' -CacheTtlSec 60 -Script {
        $b = [PSCustomObject]@{ Static = @(); Full = @(); Cycles = @(); Errors = @{} }
        try { $b.Static = @(Get-CimInstance -Namespace 'root\wmi' -ClassName 'BatteryStaticData' -OperationTimeoutSec 10 -ErrorAction Stop) } catch { $b.Errors['Static'] = $_.Exception.Message }
        try { $b.Full = @(Get-CimInstance -Namespace 'root\wmi' -ClassName 'BatteryFullChargedCapacity' -OperationTimeoutSec 10 -ErrorAction Stop) } catch { $b.Errors['Full'] = $_.Exception.Message }
        try { $b.Cycles = @(Get-CimInstance -Namespace 'root\wmi' -ClassName 'BatteryCycleCount' -OperationTimeoutSec 10 -ErrorAction Stop) } catch { $b.Errors['Cycles'] = $_.Exception.Message }
        $b
    }
    $d = $r.Data
    $static = Get-WCM4List (Get-WCProp $d 'Static')
    $full = Get-WCM4List (Get-WCProp $d 'Full')
    $cycles = Get-WCM4List (Get-WCProp $d 'Cycles')
    $err = @{}
    $errObj = Get-WCProp $d 'Errors'
    if ($errObj -is [hashtable]) { $err = $errObj }

    if (($static.Count -eq 0) -and ($full.Count -eq 0)) {
        if ($err.Count -gt 0) {
            $firstReason = ''
            foreach ($k in @('Static', 'Full', 'Cycles')) {
                if ($err.ContainsKey($k)) { $firstReason = [string]$err[$k]; break }
            }
            return (New-WCM4ErrorGroupModel -Key 'battery' -BaseKey 'battery' -Title (T 'm4.grp.battery') -Reason $firstReason)
        }
        # Khong co pin (may ban) -> AN muc nay (spec M4)
        return (New-WCM4GroupModel -Key 'battery' -BaseKey 'battery' -Title (T 'm4.grp.battery') -Summary '' -Rows @() -Absent $true)
    }

    $count = $static.Count
    if ($full.Count -gt $count) { $count = $full.Count }
    if ($count -eq 0) { $count = 1 }
    $rows = @()
    $wearPct = $null
    for ($i = 0; $i -lt $count; $i++) {
        $designed = $null; $fullCap = $null; $cyc = $null
        if ($i -lt $static.Count) { $designed = Get-WCProp $static[$i] 'DesignedCapacity' }
        if ($i -lt $full.Count) { $fullCap = Get-WCProp $full[$i] 'FullChargedCapacity' }
        if ($i -lt $cycles.Count) { $cyc = Get-WCProp $cycles[$i] 'CycleCount' }
        if ($count -gt 1) {
            $rows += (New-WCM4HeaderRow -Text (T 'm4.bat.n' @($i + 1)))
        }
        $desTxt = (T 'common.na'); $fullTxt = (T 'common.na'); $cycTxt = (T 'common.na')
        if ($null -ne $designed) { $desTxt = (T 'm4.bat.mwh' @([long]$designed)) }
        if ($null -ne $fullCap) { $fullTxt = (T 'm4.bat.mwh' @([long]$fullCap)) }
        if ($null -ne $cyc) { $cycTxt = [string][int]$cyc }
        $rows += (New-WCM4Field -Label (T 'm4.bat.designed') -Value $desTxt)
        $rows += (New-WCM4Field -Label (T 'm4.bat.full') -Value $fullTxt)
        if (($null -ne $designed) -and ($null -ne $fullCap) -and ([long]$designed -gt 0) -and ([long]$fullCap -gt 0)) {
            $wearPct = [math]::Round(100 - (([double]$fullCap / [double]$designed) * 100), 1)
            if ($wearPct -lt 0) { $wearPct = 0 }
            $rows += (New-WCM4Field -Label (T 'm4.bat.wear') -Value (T 'm4.pct' @($wearPct)))
        } else {
            $rows += (New-WCM4Field -Label (T 'm4.bat.wear') -Value (T 'common.na'))
        }
        $rows += (New-WCM4Field -Label (T 'm4.bat.cycles') -Value $cycTxt)
    }
    $sumTxt = (T 'm4.grp.battery')
    if ($null -ne $wearPct) { $sumTxt = (T 'm4.bat.summary' @($wearPct)) }
    return (New-WCM4GroupModel -Key 'battery' -BaseKey 'battery' -Title (T 'm4.grp.battery') -Summary $sumTxt -Rows $rows)
}

function Get-WCM4CpuTempModel {
    # Trung thuc: Windows khong co API nhiet do CPU chung dang tin (spec M4)
    return (New-WCM4GroupModel -Key 'cputemp' -BaseKey 'cputemp' -Title (T 'm4.grp.cputemp') `
        -Summary (T 'm4.cputemp.summary') -Rows @() -Note (T 'm4.cputemp.msg'))
}

# ---------------------------------------------------------------------------
# XUAT BAO CAO (HTML tu chua + TXT can cot; che du lieu nhay cam mac dinh)
# ---------------------------------------------------------------------------
function ConvertTo-WCM4HtmlEscape {
    param([string]$Text)
    if ($null -eq $Text) { return '' }
    $s = $Text.Replace('&', '&amp;').Replace('<', '&lt;').Replace('>', '&gt;').Replace('"', '&quot;')
    return $s
}

function Get-WCM4RowDisplayValue {
    # Gia tri hien thi trong bao cao (che neu Mask + Sensitive)
    param($Row, [bool]$Mask)
    $val = [string]$Row['Value']
    if ($Mask -and [bool]$Row['Sensitive']) {
        $raw = [string]$Row['Raw']
        if ([string]::IsNullOrEmpty($raw)) { $raw = $val }
        $val = (Mask-WCSensitive $raw)
    }
    return $val
}

function New-WCM4ReportHtml {
    param($Models, [bool]$Mask, [string]$Version, [string]$TimeText)
    $css = 'body{font-family:"Segoe UI",Arial,sans-serif;background:#f4f5f7;color:#1b1f24;margin:24px;} h1{font-size:20px;margin:0 0 4px;} .meta{color:#5a6472;font-size:12px;margin-bottom:18px;} .card{background:#fff;border:1px solid #e1e4e9;border-radius:10px;padding:12px 16px;margin:12px 0;} h2{font-size:15px;margin:2px 0 10px;} .sum{color:#5a6472;font-weight:400;font-size:12.5px;} table{border-collapse:collapse;width:100%;} td{padding:4px 10px 4px 0;border-bottom:1px solid #eef0f3;vertical-align:top;font-size:13px;} td.l{width:300px;color:#5a6472;} tr.hdr td{font-weight:600;background:#f7f8fa;} .note{color:#6a7482;font-size:11.5px;margin-top:8px;}'
    $sb = New-Object System.Text.StringBuilder
    $null = $sb.Append('<!DOCTYPE html><html><head><meta charset="utf-8"/><title>')
    $null = $sb.Append((ConvertTo-WCM4HtmlEscape (T 'm4.title')))
    $null = $sb.Append('</title><style>')
    $null = $sb.Append($css)
    $null = $sb.Append('</style></head><body><h1>')
    $null = $sb.Append((ConvertTo-WCM4HtmlEscape (T 'm4.title')))
    $null = $sb.Append('</h1><div class="meta">')
    $null = $sb.Append((ConvertTo-WCM4HtmlEscape ((T 'm4.export.time') + ': ' + $TimeText + ' | ' + (T 'm4.export.version') + ': WinCare ' + $Version)))
    if ($Mask) {
        $null = $sb.Append('<br/>')
        $null = $sb.Append((ConvertTo-WCM4HtmlEscape (T 'm4.export.masked')))
    }
    $null = $sb.Append('</div>')
    foreach ($m in @($Models)) {
        $null = $sb.Append('<div class="card"><h2>')
        $null = $sb.Append((ConvertTo-WCM4HtmlEscape ([string]$m['Title'])))
        $sum = [string]$m['Summary']
        if ($sum) {
            $null = $sb.Append(' <span class="sum">— ')
            $null = $sb.Append((ConvertTo-WCM4HtmlEscape $sum))
            $null = $sb.Append('</span>')
        }
        $null = $sb.Append('</h2>')
        if ((Get-WCM4List $m['Rows']).Count -gt 0) {
            $null = $sb.Append('<table>')
            foreach ($row in @($m['Rows'])) {
                if ([string]$row['Kind'] -eq 'header') {
                    $null = $sb.Append('<tr class="hdr"><td colspan="2">')
                    $null = $sb.Append((ConvertTo-WCM4HtmlEscape ([string]$row['Label'])))
                    $null = $sb.Append('</td></tr>')
                } else {
                    $null = $sb.Append('<tr><td class="l">')
                    $null = $sb.Append((ConvertTo-WCM4HtmlEscape ([string]$row['Label'])))
                    $null = $sb.Append('</td><td>')
                    $null = $sb.Append((ConvertTo-WCM4HtmlEscape (Get-WCM4RowDisplayValue $row $Mask)))
                    $null = $sb.Append('</td></tr>')
                }
            }
            $null = $sb.Append('</table>')
        }
        $note = [string]$m['Note']
        if ($note) {
            $null = $sb.Append('<div class="note">')
            $null = $sb.Append((ConvertTo-WCM4HtmlEscape $note))
            $null = $sb.Append('</div>')
        }
        $null = $sb.Append('</div>')
    }
    $null = $sb.Append('</body></html>')
    return $sb.ToString()
}

function New-WCM4ReportText {
    param($Models, [bool]$Mask, [string]$Version, [string]$TimeText)
    $sb = New-Object System.Text.StringBuilder
    $null = $sb.AppendLine((T 'm4.report.header'))
    $null = $sb.AppendLine((T 'm4.export.time') + ': ' + $TimeText + ' | ' + (T 'm4.export.version') + ': WinCare ' + $Version)
    if ($Mask) { $null = $sb.AppendLine((T 'm4.export.masked')) }
    foreach ($m in @($Models)) {
        $title = [string]$m['Title']
        $sum = [string]$m['Summary']
        $head = $title
        if ($sum) { $head = $title + ' — ' + $sum }
        $null = $sb.AppendLine('')
        $null = $sb.AppendLine(('=== ' + $head + ' ==='))
        foreach ($row in @($m['Rows'])) {
            if ([string]$row['Kind'] -eq 'header') {
                $null = $sb.AppendLine(('[' + [string]$row['Label'] + ']'))
            } else {
                $null = $sb.AppendLine(('  ' + ([string]$row['Label']).PadRight(36) + ' : ' + (Get-WCM4RowDisplayValue $row $Mask)))
            }
        }
        $note = [string]$m['Note']
        if ($note) { $null = $sb.AppendLine(('  ' + $note)) }
    }
    return $sb.ToString()
}

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
function New-WCM4Record {
    # Tao 1 Expander + ghi vao Records/GroupOrder (hoac chen sau record khac)
    param($State, [string]$Key, [string]$BaseKey, [string]$Title, $After = $null)
    $exp = New-WCExpander -Title $Title
    $summary = New-WCTextBlock -Text '' -Size 12.5 -ColorKey 'WcSubtle'
    $summary.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $exp.Header.Children.Add($summary) | Out-Null
    $rec = @{
        Key = $Key; BaseKey = $BaseKey; Root = $exp.Root; Body = $exp.Body
        TitleBlock = $exp.Header.Children[0]; SummaryBlock = $summary
        Rows = @(); Model = $null; Loaded = $false; Claimed = $false
        Virtual = $false; Hidden = $false
    }
    $State['Records'][$Key] = $rec
    if ($After) {
        $idx = $State['GroupsHost'].Children.IndexOf($After['Root'])
        if ($idx -ge 0) {
            $State['GroupsHost'].Children.Insert(($idx + 1), $rec['Root'])
        } else {
            Add-WCChild $State['GroupsHost'] $rec['Root']
        }
        $order = @()
        $inserted = $false
        foreach ($r in @($State['GroupOrder'])) {
            $order += $r
            if ($r -eq $After) { $order += $rec; $inserted = $true }
        }
        if (-not $inserted) { $order += $rec }
        $State['GroupOrder'] = $order
    } else {
        Add-WCChild $State['GroupsHost'] $rec['Root']
        $State['GroupOrder'] = @($State['GroupOrder']) + $rec
    }
    return $rec
}

function Update-WCM4GroupFromModel {
    # Do du lieu 1 model vao Expander tuong ung (base hoac tao moi cho thiet bi phu)
    param($State, $Model)
    if ($null -eq $Model) { return }
    $key = [string]$Model['Key']
    $baseKey = [string]$Model['BaseKey']
    if ([bool]$Model['Absent']) {
        if ($State['Records'].ContainsKey($key)) {
            $rec = $State['Records'][$key]
            $rec['Body'].Children.Clear()
            $rec['Rows'] = @()
            $rec['Hidden'] = $true
            $rec['Loaded'] = $true
        }
        return
    }
    $rec = $null
    if ($State['Records'].ContainsKey($key)) { $rec = $State['Records'][$key] }
    if (-not $rec) {
        $base = $null
        if ($State['Records'].ContainsKey($baseKey)) { $base = $State['Records'][$baseKey] }
        if ($base -and (-not $base['Claimed']) -and ($key -like ($baseKey + ':0'))) {
            # Thiet bi DAU TIEN cua nhom "nhieu thiet bi" chiem Expander goc
            $rec = $base
            $rec['Claimed'] = $true
            $rec['Key'] = $key
            $State['Records'][$key] = $rec
        } else {
            $after = $null
            if ($State['LastRec'].ContainsKey($baseKey)) { $after = $State['LastRec'][$baseKey] }
            elseif ($base) { $after = $base }
            $rec = New-WCM4Record -State $State -Key $key -BaseKey $baseKey -Title ([string]$Model['Title']) -After $after
            $rec['Claimed'] = $true
        }
    }
    if (-not $rec) { return }
    $State['LastRec'][$baseKey] = $rec

    $title = [string]$Model['Title']
    if ($title) { $rec['TitleBlock'].Text = $title }
    $summary = [string]$Model['Summary']
    if ($summary) {
        $rec['SummaryBlock'].Text = (' — ' + (ConvertTo-WCM4ShortText $summary 80))
    } else {
        $rec['SummaryBlock'].Text = ''
    }

    $body = $rec['Body']
    $body.Children.Clear()
    $rows = @()
    foreach ($row in (Get-WCM4List $Model['Rows'])) {
        if ([string]$row['Kind'] -eq 'header') {
            $tb = New-WCTextBlock -Text ([string]$row['Label']) -Size 12.5 -Weight 'SemiBold'
            Add-WCChild $body $tb
            $rows += @{ Ctrl = $tb; Label = [string]$row['Label']; Val = $tb }
        } else {
            $fr = New-WCFieldRow -Label ([string]$row['Label']) -Value ([string]$row['Value']) -Mono:([bool]$row['Mono'])
            Add-WCChild $body $fr
            $rows += @{ Ctrl = $fr; Label = [string]$row['Label']; Val = $fr.Tag }
        }
    }
    $note = [string]$Model['Note']
    if ($note) {
        $ntb = New-WCTextBlock -Text $note -Size 11.5 -ColorKey 'WcSubtle' -Wrap
        Add-WCChild $body $ntb
        $rows += @{ Ctrl = $ntb; Label = ''; Val = $ntb }
    }
    $rec['Rows'] = $rows
    $rec['Model'] = $Model
    $rec['Loaded'] = $true
    $rec['Virtual'] = [bool]$Model['Virtual']
    $rec['Hidden'] = $false
}

function Invoke-WCM4ApplyVisibility {
    # Ap dung cung luc: bo loc tim kiem + cong tac adapter ao + an nhom khong co du lieu
    param($State)
    $q = ''
    if ($State.ContainsKey('FilterText')) { $q = ([string]$State['FilterText']).Trim() }
    $showVirtual = $false
    if ($State['VirtualCheck']) { $showVirtual = ($State['VirtualCheck'].IsChecked -eq $true) }
    $hiddenVirtual = 0
    foreach ($rec in @($State['GroupOrder'])) {
        if (-not $rec['Loaded']) { continue }
        if ($rec['Hidden']) {
            $rec['Root'].Visibility = [Windows.Visibility]::Collapsed
            continue
        }
        $groupVisible = $true
        if ($q -ne '') {
            $groupVisible = $false
            $titleText = [string]$rec['TitleBlock'].Text
            if ($titleText -like ('*' + $q + '*')) { $groupVisible = $true }
            foreach ($row in @($rec['Rows'])) {
                $match = $false
                $lbl = [string]$row['Label']
                $val = ''
                if ($row['Val']) { $val = [string]$row['Val'].Text }
                if (($lbl -like ('*' + $q + '*')) -or ($val -like ('*' + $q + '*'))) { $match = $true }
                if ($match) {
                    $row['Ctrl'].Visibility = [Windows.Visibility]::Visible
                    $groupVisible = $true
                } else {
                    $row['Ctrl'].Visibility = [Windows.Visibility]::Collapsed
                }
            }
        } else {
            foreach ($row in @($rec['Rows'])) {
                $row['Ctrl'].Visibility = [Windows.Visibility]::Visible
            }
        }
        if ($rec['Virtual'] -and (-not $showVirtual)) { $groupVisible = $false }
        if ($groupVisible) {
            $rec['Root'].Visibility = [Windows.Visibility]::Visible
        } else {
            $rec['Root'].Visibility = [Windows.Visibility]::Collapsed
        }
        if ($rec['Virtual'] -and (-not $showVirtual)) { $hiddenVirtual++ }
    }
    if ($State['VirtualNote']) {
        if (($hiddenVirtual -gt 0) -and (-not $showVirtual)) {
            $State['VirtualNote'].Text = (T 'm4.gpu.hidden' @($hiddenVirtual))
            $State['VirtualNote'].Visibility = [Windows.Visibility]::Visible
        } else {
            $State['VirtualNote'].Visibility = [Windows.Visibility]::Collapsed
        }
    }
}

function Invoke-WCM4RenderModels {
    # Chay tren UI thread khi task nen tra ket qua; render tung nhom
    param($State, $Result)
    $models = $null
    if ($Result -is [hashtable]) { $models = $Result['Groups'] }
    elseif ($Result) { $models = (Get-WCProp $Result 'Groups') }
    if ($null -eq $models) { return }
    foreach ($m in (Get-WCM4List $models)) {
        Update-WCM4GroupFromModel -State $State -Model $m
    }
    Invoke-WCM4ApplyVisibility -State $State
}

function Invoke-WCM4CopySummary {
    param($State)
    $lines = @()
    foreach ($rec in @($State['GroupOrder'])) {
        $m = $rec['Model']
        if ($null -eq $m) { continue }
        if ($rec['Hidden']) { continue }
        $title = [string]$m['Title']
        $sum = [string]$m['Summary']
        if ($sum) { $lines += ($title + ' — ' + $sum) } else { $lines += $title }
    }
    if ($lines.Count -eq 0) {
        Show-WCToast (T 'common.empty') 'Info'
        return
    }
    Set-WCClipboard ([string]::Join([Environment]::NewLine, $lines))
    Show-WCToast (T 'common.copied') 'Ok'
}

function Invoke-WCM4OpenReports {
    try {
        $dir = Join-Path (Get-WCDataRoot) 'reports'
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
        }
        Start-Process explorer.exe -ArgumentList $dir
    } catch {
        Show-WCToast (T 'common.cannotopen') 'Warn'
    }
}

function Invoke-WCM4ExportReport {
    # Xuat 2 file (HTML tu chua + TXT can cot) vao reports\; che du lieu neu Mask
    param($State)
    $models = @()
    foreach ($rec in @($State['GroupOrder'])) {
        if ($null -ne $rec['Model']) { $models += $rec['Model'] }
    }
    if ($models.Count -eq 0) {
        Show-WCToast (T 'common.empty') 'Info'
        return
    }
    try {
        $dir = Join-Path (Get-WCDataRoot) 'reports'
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
        }
        $stamp = (Get-Date -Format 'yyyy-MM-dd-HHmm')
        $taskArgs = @{
            Models = $models
            HtmlPath = (Join-Path $dir ('thong-so-' + $stamp + '.html'))
            TxtPath = (Join-Path $dir ('thong-so-' + $stamp + '.txt'))
            Mask = (Test-WCMaskMode)
            Version = (Get-WCVersion)
            TimeText = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
        }
        $ok = Start-WCTask -Id 'm4.export' -Title (T 'm4.export') -Args $taskArgs -Worker {
            param($ctx, $s)
            $html = New-WCM4ReportHtml -Models $s.Models -Mask ([bool]$s.Mask) -Version ([string]$s.Version) -TimeText ([string]$s.TimeText)
            $txt = New-WCM4ReportText -Models $s.Models -Mask ([bool]$s.Mask) -Version ([string]$s.Version) -TimeText ([string]$s.TimeText)
            [IO.File]::WriteAllText($s.HtmlPath, $html, (New-Object Text.UTF8Encoding($false)))
            [IO.File]::WriteAllText($s.TxtPath, $txt, (New-Object Text.UTF8Encoding($false)))
            return @{ TxtPath = $s.TxtPath; HtmlPath = $s.HtmlPath }
        } -Done {
            param($r)
            $p = ''
            if ($r -is [hashtable]) { $p = [string]$r['TxtPath'] }
            elseif ($r) { $p = [string](Get-WCProp $r 'TxtPath') }
            Show-WCToast (T 'm4.export.done' @($p)) 'Ok'
        }.GetNewClosure()
        if (-not $ok) { Show-WCToast (T 'common.running' @((T 'm4.export'))) 'Info' }
    } catch {
        Show-WCError -Friendly (T 'm4.export.fail') -Details $_.Exception.Message
    }
}

function Invoke-WCM4Load {
    # 3 task SONG SONG (spec M4): nhom nao xong som hien truoc, spinner rieng tung nhom
    param($State)
    Start-WCTask -Id 'm4.collect.a' -Title (T 'm4.title') -Worker {
        param($ctx, $s)
        $groups = @()
        try { $groups += (Get-WCM4SystemModel) } catch { $groups += (New-WCM4ErrorGroupModel -Key 'system' -BaseKey 'system' -Title (T 'm4.grp.system') -Reason $_.Exception.Message) }
        try { $groups += @(Get-WCM4CpuModels) } catch { $groups += (New-WCM4ErrorGroupModel -Key 'cpu:0' -BaseKey 'cpu' -Title (T 'm4.grp.cpu') -Reason $_.Exception.Message) }
        try { $groups += (Get-WCM4RamModel) } catch { $groups += (New-WCM4ErrorGroupModel -Key 'ram' -BaseKey 'ram' -Title (T 'm4.grp.ram') -Reason $_.Exception.Message) }
        return @{ Groups = $groups }
    } -Done { param($result) Invoke-WCM4RenderModels -State $State -Result $result }.GetNewClosure() | Out-Null

    Start-WCTask -Id 'm4.collect.b' -Title (T 'm4.title') -Worker {
        param($ctx, $s)
        $groups = @()
        try { $groups += @(Get-WCM4GpuModels) } catch { $groups += (New-WCM4ErrorGroupModel -Key 'gpu:0' -BaseKey 'gpu' -Title (T 'm4.grp.gpu') -Reason $_.Exception.Message) }
        try { $groups += (Get-WCM4MonitorModel) } catch { $groups += (New-WCM4ErrorGroupModel -Key 'monitors' -BaseKey 'monitors' -Title (T 'm4.grp.monitors') -Reason $_.Exception.Message) }
        try { $groups += (Get-WCM4BatteryModel) } catch { $groups += (New-WCM4ErrorGroupModel -Key 'battery' -BaseKey 'battery' -Title (T 'm4.grp.battery') -Reason $_.Exception.Message) }
        return @{ Groups = $groups }
    } -Done { param($result) Invoke-WCM4RenderModels -State $State -Result $result }.GetNewClosure() | Out-Null

    Start-WCTask -Id 'm4.collect.c' -Title (T 'm4.title') -Worker {
        param($ctx, $s)
        $groups = @()
        try { $groups += @(Get-WCM4DiskModels) } catch { $groups += (New-WCM4ErrorGroupModel -Key 'disk:0' -BaseKey 'disks' -Title (T 'm4.grp.disks') -Reason $_.Exception.Message) }
        try { $groups += (Get-WCM4NetModel) } catch { $groups += (New-WCM4ErrorGroupModel -Key 'net' -BaseKey 'net' -Title (T 'm4.grp.net') -Reason $_.Exception.Message) }
        return @{ Groups = $groups }
    } -Done { param($result) Invoke-WCM4RenderModels -State $State -Result $result }.GetNewClosure() | Out-Null
}

function New-WCM4Panel {
    param($State)
    # Panel co the duoc xay lai (doi ngon ngu/theme) -> reset danh sach record cu
    $State['Records'] = @{}
    $State['GroupOrder'] = @()
    $State['LastRec'] = @{}
    $root = New-Object Windows.Controls.ScrollViewer
    $root.VerticalScrollBarVisibility = [Windows.Controls.ScrollBarVisibility]::Auto
    $hostPanel = New-WCVStack -Spacing 14
    $hostPanel.Margin = (New-Object Windows.Thickness(20))
    $root.Content = $hostPanel

    Add-WCChild $hostPanel (New-WCHeading (T 'm4.title'))
    Add-WCChild $hostPanel (New-WCSubtitle (T 'm4.subtitle'))

    # Hang 1: tim kiem + cong tac adapter ao
    $row1 = New-WCHStack -Spacing 10
    $searchLbl = New-WCTextBlock -Text (T 'common.search') -Size 12.5 -ColorKey 'WcSubtle'
    $searchLbl.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $row1.Children.Add($searchLbl) | Out-Null
    $searchBox = New-WCSearchBox -OnChanged {
        param($b)
        $State['FilterText'] = $b.Text
        Invoke-WCM4ApplyVisibility -State $State
    }.GetNewClosure()
    $row1.Children.Add($searchBox) | Out-Null
    $virtualCb = New-Object Windows.Controls.CheckBox
    $virtualCb.Content = (T 'm4.show.virtual')
    $virtualCb.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'WcText')
    $virtualCb.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $virtualCb.Add_Checked({ Invoke-WCM4ApplyVisibility -State $State }.GetNewClosure())
    $virtualCb.Add_Unchecked({ Invoke-WCM4ApplyVisibility -State $State }.GetNewClosure())
    $State['VirtualCheck'] = $virtualCb
    $row1.Children.Add($virtualCb) | Out-Null
    Add-WCChild $hostPanel $row1

    # Hang 2: cac nut
    $row2 = New-WCHStack -Spacing 8
    $copyBtn = New-WCButton -Text (T 'm4.copy.summary') -Small -OnClick { param($b) Invoke-WCM4CopySummary -State $State }.GetNewClosure()
    $row2.Children.Add($copyBtn) | Out-Null
    $exportBtn = New-WCButton -Text (T 'm4.export') -Small -OnClick { param($b) Invoke-WCM4ExportReport -State $State }.GetNewClosure()
    $row2.Children.Add($exportBtn) | Out-Null
    $openBtn = New-WCButton -Text (T 'm4.open.reports') -Small -OnClick { param($b) Invoke-WCM4OpenReports }.GetNewClosure()
    $row2.Children.Add($openBtn) | Out-Null
    Add-WCChild $hostPanel $row2

    # Ghi chu so adapter ao dang an
    $vnote = New-WCTextBlock -Text '' -Size 11.5 -ColorKey 'WcSubtle' -Wrap
    $vnote.Visibility = [Windows.Visibility]::Collapsed
    $State['VirtualNote'] = $vnote
    Add-WCChild $hostPanel $vnote

    # Vung cac nhom (Expander theo dung thu tu spec)
    $groupsHost = New-WCVStack -Spacing 8
    $State['GroupsHost'] = $groupsHost
    Add-WCChild $hostPanel $groupsHost

    $defs = @(
        @{ Key = 'system';   Title = (T 'm4.grp.system') },
        @{ Key = 'cpu';      Title = (T 'm4.grp.cpu') },
        @{ Key = 'gpu';      Title = (T 'm4.grp.gpu') },
        @{ Key = 'ram';      Title = (T 'm4.grp.ram') },
        @{ Key = 'disks';    Title = (T 'm4.grp.disks') },
        @{ Key = 'monitors'; Title = (T 'm4.grp.monitors') },
        @{ Key = 'net';      Title = (T 'm4.grp.net') },
        @{ Key = 'battery';  Title = (T 'm4.grp.battery') }
    )
    foreach ($d in $defs) {
        $rec = New-WCM4Record -State $State -Key $d['Key'] -BaseKey $d['Key'] -Title ([string]$d['Title'])
        Add-WCChild $rec['Body'] (New-WCSpinner)
    }

    # Nhom nhiet do CPU: thong diep trung thuc, khong cho nen tai
    New-WCM4Record -State $State -Key 'cputemp' -BaseKey 'cputemp' -Title (T 'm4.grp.cputemp') | Out-Null
    Update-WCM4GroupFromModel -State $State -Model (Get-WCM4CpuTempModel)

    return $root
}

# ---------------------------------------------------------------------------
# KHOI TAO MODULE (dang ky nav - buoc cuoi file theo contract)
# ---------------------------------------------------------------------------
function Initialize-WCModuleM4 {
    $state = @{
        Records = @{}; GroupOrder = @(); LastRec = @{}
        GroupsHost = $null; VirtualCheck = $null; VirtualNote = $null
        FilterText = ''
    }
    Register-WCNavItem -Key 'm4' -Badge 'M4' -Title (T 'm4.title') -Order 50 -Builder {
        New-WCM4Panel $state
    }.GetNewClosure() -OnShow {
        Invoke-WCM4Load $state
    }.GetNewClosure()
}


# ============================================================================
# REGION: 16-M5-Security.ps1
# ============================================================================

# ============================================================================
#  src/16-M5-Security.ps1 - Module M5: KIEM TRA BAO MAT & MA DOC
#  Su that the hien trong UI (spec M5): WinCare KHONG phai antivirus - dung
#  chinh engine Microsoft Defender lam dong co quet; "Khong phat hien moi de
#  doa" KHONG dong nghia "may sach 100%".
#  3 lop: (1) trang thai bao ve - chi doc + huong dan cach bat, khong tu bat;
#         (2) quet Defender (nhanh/toan bo/thu muc/ngoai tuyen) + xu ly de doa
#             qua Defender, xac nhan tung muc, khong tu xoa;
#         (3) heuristic dau hieu bat thuong - "goi y, khong phai ket luan",
#             moi muc kem LY DO cu the, vo hieu hoa dao nguoc duoc qua
#             StartupApproved ( nhu Task Manager ) + journal 'startup.enable'.
# ============================================================================

Register-WCStrings 'vi' @{
    'm5.title' = 'Kiểm tra bảo mật & mã độc'
    'm5.subtitle' = 'Dùng chính Microsoft Defender để quét — trung thực về giới hạn của công cụ'
    'm5.fact.title' = 'Sự thật cần biết trước'
    'm5.fact' = 'WinCare KHÔNG phải antivirus và không có engine quét riêng — mọi thao tác quét bên dưới đều dùng chính engine Microsoft Defender của Windows. "Không phát hiện mối đe dọa" KHÔNG đồng nghĩa "máy sạch 100%": kết quả chỉ phản ánh những gì Defender phát hiện được ở thời điểm quét.'
    # ---- Lop 1: trang thai bao ve ----
    'm5.l1.title' = 'Lớp 1 — Trạng thái bảo vệ'
    'm5.l1.subtitle' = 'Đọc trạng thái các lớp bảo vệ Windows. WinCare chỉ HƯỚNG DẪN cách bật — không tự thay đổi cấu hình bảo mật khi bạn chưa đồng ý.'
    'm5.l1.s.mpstatus' = 'Dịch vụ Microsoft Defender'
    'm5.l1.s.av' = 'Phần mềm diệt virus đã đăng ký'
    'm5.l1.s.firewall' = 'Tường lửa (Firewall)'
    'm5.l1.s.smartscreen' = 'SmartScreen'
    'm5.l1.s.uac' = 'Kiểm soát tài khoản (UAC)'
    'm5.l1.s.bitlocker' = 'BitLocker'
    'm5.l1.s.wupending' = 'Windows Update'
    'm5.def.mode' = 'Chế độ hoạt động: {0}'
    'm5.def.mode.normal' = 'đang hoạt động bình thường'
    'm5.def.mode.passive' = 'chế độ ngầm (passive) — thường do phần mềm diệt virus khác đang giữ vai trò chính. Đây là hành vi đúng của Windows, WinCare không "giành quyền"'
    'm5.def.mode.off' = 'không chạy / không đọc được — các nút quét bằng Defender ở Lớp 2 có thể không khả dụng'
    'm5.def.rtp' = 'Bảo vệ thời gian thực'
    'm5.def.rtp.how' = 'Cách bật: Bảo mật Windows → Virus & threat protection → Real-time protection. Nếu nút này bị mờ, có thể phần mềm diệt virus khác đang giữ vai trò (tham khảo mục "Phần mềm diệt virus đã đăng ký" phía trên).'
    'm5.def.sig.age' = 'Chữ ký virus: {0} ngày tuổi (cập nhật lần cuối: {1})'
    'm5.def.sig.stale' = 'Chữ ký đã cũ — nên bấm "Cập nhật chữ ký" ở Lớp 2.'
    'm5.def.sig.unknown' = 'Không đọc được thông tin chữ ký virus.'
    'm5.def.engine' = 'Phiên bản engine'
    'm5.def.quick' = 'Quét nhanh gần nhất'
    'm5.def.full' = 'Quét toàn bộ gần nhất'
    'm5.def.never' = 'chưa từng quét'
    'm5.def.tamper' = 'Chống can thiệp (Tamper Protection)'
    'm5.def.tamper.source' = 'Nguồn cấu hình chống can thiệp: {0}'
    'm5.def.tamper.how' = 'Cách bật: Bảo mật Windows → Virus & threat protection → Manage settings → Tamper Protection.'
    'm5.av.line' = '{0} — {1}, chữ ký {2}'
    'm5.av.on' = 'đang bật'
    'm5.av.off' = 'đang tắt'
    'm5.av.up' = 'mới'
    'm5.av.outdated' = 'cũ'
    'm5.av.unknown' = 'không rõ'
    'm5.av.note' = 'Giải mã productState theo cách phổ biến (chưa kiểm chứng trên mọi máy).'
    'm5.av.thirdparty' = 'Phát hiện phần mềm diệt virus bên thứ ba đang bật — khi đó Defender thường chuyển sang chế độ passive. Đây là thực trạng đúng của máy, không phải lỗi.'
    'm5.av.none' = 'Không đọc được danh sách AV (không gian root\SecurityCenter2 — máy ảo/Server có thể không có).'
    'm5.fw.line' = '{0}: {1}'
    'm5.fw.domain' = 'Miền (Domain)'
    'm5.fw.private' = 'Riêng tư (Private)'
    'm5.fw.public' = 'Công khai (Public)'
    'm5.fw.on' = 'đang bật'
    'm5.fw.off' = 'ĐANG TẮT — máy dễ bị truy cập từ mạng'
    'm5.fw.how' = 'Cách bật: Bảo mật Windows → Firewall & network protection → chọn profile → Bật.'
    'm5.ss.machine' = 'SmartScreen (toàn máy)'
    'm5.ss.user' = 'SmartScreen (người dùng)'
    'm5.ss.off' = 'Đang tắt — nên bật lại.'
    'm5.ss.warn' = 'Chỉ cảnh báo (Warn).'
    'm5.ss.missing' = 'Chưa đặt giá trị — dùng mặc định hệ thống.'
    'm5.ss.how' = 'Cách bật: Bảo mật Windows → App & browser control → Reputation-based protection settings → Check apps and files.'
    'm5.uac.on' = 'UAC đang bật (EnableLUA = 1).'
    'm5.uac.off' = 'UAC ĐANG TẮT (EnableLUA = 0) — chương trình có thể nâng quyền mà không hỏi.'
    'm5.uac.prompt' = 'Hành vi nhắc với Admin (ConsentPromptBehaviorAdmin)'
    'm5.uac.how' = 'Cách bật: tìm "Thay đổi cài đặt Kiểm soát tài khoản người dùng" trong Cài đặt Windows và kéo về mức mặc định.'
    'm5.bl.line' = '{0} — {1} (bảo vệ: {2})'
    'm5.bl.enc' = 'đã mã hóa'
    'm5.bl.dec' = 'CHƯA mã hóa'
    'm5.bl.protected' = 'bật'
    'm5.bl.notprotected' = 'tắt'
    'm5.bl.how' = 'Cách bật: Cài đặt → Quyền riêng tư & bảo mật → Mã hóa thiết bị / BitLocker (một số máy không hỗ trợ).'
    'm5.bl.unread' = 'Không đọc được BitLocker (cần quyền Admin hoặc module BitLocker không có trên máy).'
    'm5.wu.pending' = 'Có cập nhật chờ khởi động lại: {0}.'
    'm5.wu.none' = 'Không có cập nhật nào chờ khởi động lại.'
    'm5.wu.cbs' = 'thành phần hệ thống (CBS)'
    'm5.wu.wu' = 'Windows Update'
    'm5.wu.pfro' = 'tệp chờ đổi tên'
    'm5.wu.how' = 'Nên lưu công việc và khởi động lại máy để hoàn tất cập nhật.'
    # ---- Lop 2: quet Defender ----
    'm5.l2.title' = 'Lớp 2 — Quét bằng Microsoft Defender'
    'm5.l2.subtitle' = 'Các nút bên dưới gọi trực tiếp engine Microsoft Defender. Defender không báo tiến độ chi tiết — WinCare chỉ hiện thời gian đã chạy, không bịa số %.'
    'm5.l2.sig' = 'Cập nhật chữ ký'
    'm5.l2.quick' = 'Quét nhanh'
    'm5.l2.full' = 'Quét toàn bộ'
    'm5.l2.custom' = 'Quét thư mục'
    'm5.l2.wdo' = 'Quét ngoại tuyến'
    'm5.l2.folder.hint' = 'Thư mục / ổ đĩa cần quét (ví dụ: D:\Downloads):'
    'm5.l2.status.idle' = 'Chưa chạy quét nào.'
    'm5.scan.title' = 'Quét Defender'
    'm5.elapsed' = 'Đã chạy {0} giây'
    'm5.scan.noprogress' = 'Defender không báo tiến độ chi tiết — không có số % thật nên không hiển thị'
    'm5.scan.folder.invalid' = 'Đường dẫn thư mục không hợp lệ hoặc không tồn tại.'
    'm5.scan.done' = 'Quét xong sau {0} giây.'
    'm5.scan.error' = 'Quét không thành công — dịch vụ Defender có thể đang tắt hoặc bị phần mềm diệt virus khác thay thế.'
    'm5.sig.title' = 'Cập nhật chữ ký Defender'
    'm5.sig.done' = 'Đã cập nhật chữ ký virus.'
    'm5.sig.error' = 'Cập nhật chữ ký không thành công (kiểm tra kết nối mạng hoặc trạng thái dịch vụ Defender).'
    'm5.sig.cancelnote' = 'Việc cập nhật chữ ký không dừng ngay được — bấm Hủy chỉ ngừng chờ, dịch vụ Defender có thể vẫn cập nhật nốt'
    'm5.wdo.confirm.title' = 'Quét ngoại tuyến — máy sẽ KHỞI ĐỘNG LẠI'
    'm5.wdo.confirm.msg' = "Ngay sau khi xác nhận, máy sẽ KHỞI ĐỘNG LẠI để quét trước khi Windows chạy (khoảng 15–30 phút, trong lúc đó không dùng được máy).`nHãy LƯU hết công việc đang mở trước khi bấm."
    'm5.wdo.confirm.noundo' = 'Máy khởi động lại ngay — không thể hoàn tác.'
    'm5.wdo.scheduled' = 'Đã hẹn quét ngoại tuyến — máy sẽ khởi động lại ngay để quét.'
    'm5.wdo.error' = 'Không hẹn được quét ngoại tuyến.'
    'm5.threat.title' = 'Kết quả — mối đe dọa'
    'm5.threat.subtitle' = 'Danh sách Defender ghi nhận (Get-MpThreatDetection / Get-MpThreat).'
    'm5.threat.col.name' = 'Mối đe dọa'
    'm5.threat.col.type' = 'Loại'
    'm5.threat.col.res' = 'Tài nguyên'
    'm5.threat.col.status' = 'Trạng thái'
    'm5.threat.none' = 'Không phát hiện mối đe dọa. Lưu ý: KHÔNG đồng nghĩa máy sạch 100% — chỉ có nghĩa là Defender không thấy gì trong phạm vi nó quét được.'
    'm5.threat.remove' = 'Cách ly'
    'm5.threat.active' = 'đang hoạt động'
    'm5.threat.at' = 'Phát hiện lúc: {0}'
    'm5.threat.confirm.title' = 'Xử lý mối đe dọa bằng Defender'
    'm5.threat.confirm.msg' = ('Yêu cầu Microsoft Defender xử lý mối đe dọa "{0}"?' + "`n" + 'Lưu ý: cmdlet Remove-MpThreat của Microsoft xử lý theo chính sách của Defender (thường là cách ly/xóa các mối đe dọa đang hoạt động), không chọn đúng một mục.')
    'm5.threat.confirm.noundo' = 'Không hoàn tác tự động qua WinCare; mục bị cách ly có thể xem/khôi phục trong "Protection history" của Bảo mật Windows.'
    'm5.threat.refresh' = 'Làm mới danh sách'
    'm5.threat.journal' = 'Yêu cầu Defender xử lý mối đe dọa'
    'm5.threat.sev.1' = 'Thấp'
    'm5.threat.sev.2' = 'Trung bình'
    'm5.threat.sev.3' = 'Cao'
    'm5.threat.sev.4' = 'Cao'
    'm5.threat.sev.5' = 'Nghiêm trọng'
    'm5.threat.sev.fmt' = 'Mức {0}'
    'm5.threat.sev.unknown' = 'Không rõ'
    'm5.threat.cat.1' = 'Adware'
    'm5.threat.cat.2' = 'Spyware'
    'm5.threat.cat.5' = 'Sâu máy (Worm)'
    'm5.threat.cat.6' = 'Backdoor'
    'm5.threat.cat.8' = 'Trojan'
    'm5.threat.cat.10' = 'Keylogger'
    'm5.threat.cat.30' = 'Exploit'
    'm5.threat.cat.fmt' = 'Loại {0}'
    'm5.threat.status.1' = 'Không rõ'
    'm5.threat.status.2' = 'Đã phát hiện'
    'm5.threat.status.3' = 'Đã dọn'
    'm5.threat.status.4' = 'Đã cách ly'
    'm5.threat.status.5' = 'Đã xóa'
    'm5.threat.status.6' = 'Đã cho phép'
    'm5.threat.status.fmt' = 'Mã {0}'
    # ---- Lop 3: heuristic ----
    'm5.l3.title' = 'Lớp 3 — Dấu hiệu bất thường'
    'm5.l3.subtitle' = 'Heuristic mang tính GỢI Ý, KHÔNG phải kết luận. Mỗi mục kèm lý do cụ thể để bạn tự đánh giá; WinCare không tự xóa gì.'
    'm5.l3.scan' = 'Quét dấu hiệu bất thường'
    'm5.l3.scanning' = 'Đang quét dấu hiệu bất thường (có thể mất chục giây)…'
    'm5.l3.idle' = 'Chưa quét'
    'm5.l3.notfound' = 'Không có mục nào.'
    'm5.l3.errsource' = 'Không đọc được nguồn này: {0}'
    'm5.l3.cancelled' = 'Đã dừng giữa chừng — danh sách có thể thiếu. Bấm quét lại để quét đầy đủ.'
    'm5.level.ok' = 'Bình thường'
    'm5.level.warn' = 'Cần xem'
    'm5.level.bad' = 'Đáng ngờ'
    'm5.level.unknown' = 'Không rõ'
    'm5.g.run' = 'Run / RunOnce (khởi động cùng Windows)'
    'm5.g.startup' = 'Thư mục Startup'
    'm5.g.task' = 'Scheduled Tasks ngoài Microsoft'
    'm5.g.svc' = 'Dịch vụ tự khởi động ngoài Windows'
    'm5.g.winlogon' = 'Winlogon (Shell / Userinit)'
    'm5.g.ifeo' = 'IFEO Debugger'
    'm5.g.wmi' = 'Đăng ký sự kiện WMI (bền vững)'
    'm5.g.excl' = 'Danh sách loại trừ của Defender'
    'm5.g.hosts' = 'Tệp hosts'
    'm5.g.proxy' = 'Proxy / PAC'
    'm5.g.count' = '{0} mục'
    'm5.h.location' = 'Tệp chạy từ vị trí tạm/công cộng (Temp/Public) — vị trí thường bị mã độc lợi dụng.'
    'm5.h.unquoted' = 'Đường dẫn có khoảng trắng nhưng không đặt trong ngoặc kép — có thể bị chiếm quyền bằng tệp ngụy trang (unquoted path).'
    'm5.h.unsigned' = 'Không có chữ ký số hợp lệ.'
    'm5.h.signed' = 'Đã ký số: {0}'
    'm5.h.nofile' = 'Không tìm thấy tệp để kiểm tra chữ ký (có thể đã bị xóa).'
    'm5.h.noexe' = 'Không xác định được tệp thực thi từ lệnh.'
    'm5.h.run' = 'Chạy tự động khi đăng nhập (khóa Run trong registry).'
    'm5.h.startup' = 'Nằm trong thư mục Startup — chạy tự động khi đăng nhập.'
    'm5.h.task' = 'Tác vụ lập lịch ngoài Microsoft.'
    'm5.h.svc' = 'Dịch vụ bên thứ ba tự khởi động cùng Windows.'
    'm5.h.shell.bad' = 'Shell không còn là "explorer.exe" chuẩn — dấu hiệu chiếm quyền hiếm gặp, cần xem ngay.'
    'm5.h.shell.ok' = 'Giá trị chuẩn "explorer.exe".'
    'm5.h.userinit.bad' = 'Userinit không chứa "userinit.exe," chuẩn — dấu hiệu chiếm quyền hiếm gặp, cần xem ngay.'
    'm5.h.userinit.ok' = 'Giá trị chuẩn (chứa "userinit.exe,").'
    'm5.h.ifeo' = 'Có giá trị Debugger trong IFEO — một số công cụ phát triển hợp lệ cũng dùng, nhưng mã độc cũng hay dùng để chặn/chiếm tiến trình.'
    'm5.h.wmi' = 'Đăng ký sự kiện WMI bền vững — rất ít phần mềm hợp lệ dùng, nên kiểm tra kỹ.'
    'm5.h.excl.path' = 'Nằm trong danh sách loại trừ của Defender — mã độc hay tự thêm để né quét.'
    'm5.h.excl.ext' = 'Phần mở rộng được bỏ qua khi quét: {0}'
    'm5.h.excl.proc' = 'Tiến trình được bỏ qua khi quét: {0}'
    'm5.h.excl.none' = 'Không có loại trừ nào.'
    'm5.h.hosts' = 'hosts có dòng chỉnh sửa (chặn hoặc trỏ domain) — có thể do bạn tự đặt hoặc do phần mềm.'
    'm5.h.hosts.ok' = 'Chỉ có dòng chuẩn (localhost / ghi chú).'
    'm5.h.proxy' = 'Đang đặt proxy/PAC thủ công — nếu không phải bạn đặt, nên kiểm tra lại.'
    'm5.h.proxy.none' = 'Không đặt proxy/PAC thủ công.'
    'm5.a.hash' = 'SHA-256'
    'm5.a.vt' = 'Tra VirusTotal'
    'm5.a.disable' = 'Vô hiệu hóa'
    'm5.hash.title' = 'Băm SHA-256'
    'm5.hash.msg' = "SHA-256:`n{0}`n`nTệp: {1}`n`nĐã sao chép vào clipboard."
    'm5.vt.opening' = 'Mở VirusTotal với mã băm (chỉ tra cứu hash — KHÔNG tải tệp của bạn lên).'
    'm5.reg.copied' = 'Đã sao chép đường dẫn khóa — mở Registry Editor rồi dán (Ctrl+V) vào thanh địa chỉ.'
    'm5.dis.confirm.title' = 'Vô hiệu hóa mục khởi động'
    'm5.dis.confirm.msg' = ('Tắt khởi động của "{0}"?' + "`n" + 'WinCare KHÔNG xóa gì — chỉ ghi cờ "đã tắt" đúng cách Task Manager (StartupApproved). Phần mềm vẫn chạy bình thường khi bạn tự mở.')
    'm5.dis.confirm.undo' = 'Khôi phục được: bấm "Hoàn tác" trong Lịch sử, hoặc bật lại trong Task Manager.'
    'm5.journal.disable' = 'Vô hiệu hóa mục khởi động'
    'm5.dis.enabled' = 'Đang bật'
    'm5.open.parent' = 'Không tìm thấy tệp — mở thư mục cha.'
    'm5.filenotfound' = 'Không tìm thấy tệp để kiểm tra.'
    'm5.expert.l2' = 'Update-MpSignature; Start-MpScan -ScanType QuickScan|FullScan|CustomScan; Start-MpWDOScan; Get-MpThreat; Get-MpThreatDetection; Remove-MpThreat; Stop-MpScan'
    'm5.expert.l3' = 'Get-Item HKLM/HKCU:...\CurrentVersion\Run; Get-ScheduledTask; Get-CimInstance Win32_Service; Get-AuthenticodeSignature; Get-MpPreference; __EventFilter/__EventConsumer'
}
Register-WCStrings 'en' @{
    'm5.title' = 'Security & malware check'
    'm5.subtitle' = 'Scans use the built-in Microsoft Defender engine — honest about the tool limits'
    'm5.fact.title' = 'Facts to know first'
    'm5.fact' = 'WinCare is NOT an antivirus and has no scan engine of its own — every scan below uses the Microsoft Defender engine built into Windows. "No threats found" does NOT mean the PC is 100% clean: it only reflects what Defender can detect at scan time.'
    'm5.l1.title' = 'Layer 1 — Protection status'
    'm5.l1.subtitle' = 'Read-only view of Windows protection layers. WinCare only GUIDES you how to turn things on — it never changes security settings without your consent.'
    'm5.l1.s.mpstatus' = 'Microsoft Defender service'
    'm5.l1.s.av' = 'Registered antivirus products'
    'm5.l1.s.firewall' = 'Firewall'
    'm5.l1.s.smartscreen' = 'SmartScreen'
    'm5.l1.s.uac' = 'User Account Control (UAC)'
    'm5.l1.s.bitlocker' = 'BitLocker'
    'm5.l1.s.wupending' = 'Windows Update'
    'm5.def.mode' = 'Running mode: {0}'
    'm5.def.mode.normal' = 'running normally'
    'm5.def.mode.passive' = 'passive mode — usually because another antivirus is the primary AV. This is correct Windows behavior; WinCare does not "take over"'
    'm5.def.mode.off' = 'not running / cannot read — Defender-based scans in Layer 2 may not work'
    'm5.def.rtp' = 'Real-time protection'
    'm5.def.rtp.how' = 'How to enable: Windows Security → Virus & threat protection → Real-time protection. If the toggle is greyed out, another antivirus may own this role (see "Registered antivirus products" above).'
    'm5.def.sig.age' = 'Virus signatures: {0} days old (last updated: {1})'
    'm5.def.sig.stale' = 'Signatures are stale — consider "Update signatures" in Layer 2.'
    'm5.def.sig.unknown' = 'Cannot read signature information.'
    'm5.def.engine' = 'Engine version'
    'm5.def.quick' = 'Last quick scan'
    'm5.def.full' = 'Last full scan'
    'm5.def.never' = 'never'
    'm5.def.tamper' = 'Tamper Protection'
    'm5.def.tamper.source' = 'Tamper protection config source: {0}'
    'm5.def.tamper.how' = 'How to enable: Windows Security → Virus & threat protection → Manage settings → Tamper Protection.'
    'm5.av.line' = '{0} — {1}, signatures {2}'
    'm5.av.on' = 'on'
    'm5.av.off' = 'off'
    'm5.av.up' = 'current'
    'm5.av.outdated' = 'outdated'
    'm5.av.unknown' = 'unknown'
    'm5.av.note' = 'productState decoded with the common method (not verified on every machine).'
    'm5.av.thirdparty' = 'A third-party antivirus is enabled — Defender usually runs in passive mode then. This is the true state of the machine, not an error.'
    'm5.av.none' = 'Cannot read the AV list (root\SecurityCenter2 namespace — missing on Server/some VMs).'
    'm5.fw.line' = '{0}: {1}'
    'm5.fw.domain' = 'Domain'
    'm5.fw.private' = 'Private'
    'm5.fw.public' = 'Public'
    'm5.fw.on' = 'on'
    'm5.fw.off' = 'OFF — the PC is exposed to the network'
    'm5.fw.how' = 'How to enable: Windows Security → Firewall & network protection → pick a profile → turn it on.'
    'm5.ss.machine' = 'SmartScreen (machine)'
    'm5.ss.user' = 'SmartScreen (user)'
    'm5.ss.off' = 'Off — should be turned back on.'
    'm5.ss.warn' = 'Warn only.'
    'm5.ss.missing' = 'Value not set — system default applies.'
    'm5.ss.how' = 'How to enable: Windows Security → App & browser control → Reputation-based protection settings → Check apps and files.'
    'm5.uac.on' = 'UAC is on (EnableLUA = 1).'
    'm5.uac.off' = 'UAC is OFF (EnableLUA = 0) — programs can elevate without asking.'
    'm5.uac.prompt' = 'Admin prompt behavior (ConsentPromptBehaviorAdmin)'
    'm5.uac.how' = 'How to enable: search "Change User Account Control settings" in Windows Settings and slide back to default.'
    'm5.bl.line' = '{0} — {1} (protection: {2})'
    'm5.bl.enc' = 'encrypted'
    'm5.bl.dec' = 'NOT encrypted'
    'm5.bl.protected' = 'on'
    'm5.bl.notprotected' = 'off'
    'm5.bl.how' = 'How to enable: Settings → Privacy & security → Device encryption / BitLocker (not available on all machines).'
    'm5.bl.unread' = 'Cannot read BitLocker (needs Admin or the BitLocker module is missing).'
    'm5.wu.pending' = 'Updates are waiting for a reboot: {0}.'
    'm5.wu.none' = 'No updates are waiting for a reboot.'
    'm5.wu.cbs' = 'Component Based Servicing'
    'm5.wu.wu' = 'Windows Update'
    'm5.wu.pfro' = 'pending file rename'
    'm5.wu.how' = 'Save your work and restart the PC to finish installing updates.'
    'm5.l2.title' = 'Layer 2 — Scan with Microsoft Defender'
    'm5.l2.subtitle' = 'Buttons below call the Microsoft Defender engine directly. Defender reports no detailed progress — WinCare only shows elapsed time, no made-up percentages.'
    'm5.l2.sig' = 'Update signatures'
    'm5.l2.quick' = 'Quick scan'
    'm5.l2.full' = 'Full scan'
    'm5.l2.custom' = 'Scan folder'
    'm5.l2.wdo' = 'Offline scan'
    'm5.l2.folder.hint' = 'Folder / drive to scan (e.g. D:\Downloads):'
    'm5.l2.status.idle' = 'No scan has been run yet.'
    'm5.scan.title' = 'Defender scan'
    'm5.elapsed' = 'Running for {0} seconds'
    'm5.scan.noprogress' = 'Defender reports no detailed progress — no real % exists, so none is shown'
    'm5.scan.folder.invalid' = 'Folder path is invalid or does not exist.'
    'm5.scan.done' = 'Scan finished in {0} seconds.'
    'm5.scan.error' = 'Scan failed — the Defender service may be off or replaced by another antivirus.'
    'm5.sig.title' = 'Update Defender signatures'
    'm5.sig.done' = 'Virus signatures updated.'
    'm5.sig.error' = 'Signature update failed (check the network connection or the Defender service).'
    'm5.sig.cancelnote' = 'Signature updates cannot be stopped midway — pressing Cancel only stops waiting; the Defender service may finish the update'
    'm5.wdo.confirm.title' = 'Offline scan — the PC WILL RESTART'
    'm5.wdo.confirm.msg' = "Right after you confirm, the PC will RESTART to scan before Windows loads (about 15–30 minutes, unusable meanwhile).`nSAVE all open work before pressing the button."
    'm5.wdo.confirm.noundo' = 'The PC restarts immediately — cannot be undone.'
    'm5.wdo.scheduled' = 'Offline scan scheduled — the PC will restart now to scan.'
    'm5.wdo.error' = 'Could not schedule the offline scan.'
    'm5.threat.title' = 'Results — threats'
    'm5.threat.subtitle' = 'Listed by Defender (Get-MpThreatDetection / Get-MpThreat).'
    'm5.threat.col.name' = 'Threat'
    'm5.threat.col.type' = 'Type'
    'm5.threat.col.res' = 'Resource'
    'm5.threat.col.status' = 'Status'
    'm5.threat.none' = 'No threats found. Note: this does NOT mean the PC is 100% clean — it only means Defender saw nothing within what it can scan.'
    'm5.threat.remove' = 'Quarantine'
    'm5.threat.active' = 'active'
    'm5.threat.at' = 'Detected at: {0}'
    'm5.threat.confirm.title' = 'Handle threat with Defender'
    'm5.threat.confirm.msg' = ('Ask Microsoft Defender to handle "{0}"?' + "`n" + 'Note: the Microsoft cmdlet Remove-MpThreat acts according to Defender policy (usually quarantining/removing active threats), it cannot target exactly one item.')
    'm5.threat.confirm.noundo' = 'Not auto-undoable via WinCare; quarantined items can be viewed/restored in Windows Security "Protection history".'
    'm5.threat.refresh' = 'Refresh list'
    'm5.threat.journal' = 'Ask Defender to handle threat'
    'm5.threat.sev.1' = 'Low'
    'm5.threat.sev.2' = 'Medium'
    'm5.threat.sev.3' = 'High'
    'm5.threat.sev.4' = 'High'
    'm5.threat.sev.5' = 'Severe'
    'm5.threat.sev.fmt' = 'Level {0}'
    'm5.threat.sev.unknown' = 'Unknown'
    'm5.threat.cat.1' = 'Adware'
    'm5.threat.cat.2' = 'Spyware'
    'm5.threat.cat.5' = 'Worm'
    'm5.threat.cat.6' = 'Backdoor'
    'm5.threat.cat.8' = 'Trojan'
    'm5.threat.cat.10' = 'Keylogger'
    'm5.threat.cat.30' = 'Exploit'
    'm5.threat.cat.fmt' = 'Type {0}'
    'm5.threat.status.1' = 'Unknown'
    'm5.threat.status.2' = 'Detected'
    'm5.threat.status.3' = 'Cleaned'
    'm5.threat.status.4' = 'Quarantined'
    'm5.threat.status.5' = 'Removed'
    'm5.threat.status.6' = 'Allowed'
    'm5.threat.status.fmt' = 'Code {0}'
    'm5.l3.title' = 'Layer 3 — Suspicious signs'
    'm5.l3.subtitle' = 'Heuristics are HINTS, NOT conclusions. Each item shows its specific reason so you can judge; WinCare deletes nothing on its own.'
    'm5.l3.scan' = 'Scan for suspicious signs'
    'm5.l3.scanning' = 'Scanning for suspicious signs (may take tens of seconds)…'
    'm5.l3.idle' = 'Not scanned yet'
    'm5.l3.notfound' = 'No items.'
    'm5.l3.errsource' = 'Cannot read this source: {0}'
    'm5.l3.cancelled' = 'Stopped midway — the list may be incomplete. Scan again for full results.'
    'm5.level.ok' = 'Normal'
    'm5.level.warn' = 'Review'
    'm5.level.bad' = 'Suspicious'
    'm5.level.unknown' = 'Unclear'
    'm5.g.run' = 'Run / RunOnce (starts with Windows)'
    'm5.g.startup' = 'Startup folder'
    'm5.g.task' = 'Non-Microsoft scheduled tasks'
    'm5.g.svc' = 'Auto-start services outside Windows'
    'm5.g.winlogon' = 'Winlogon (Shell / Userinit)'
    'm5.g.ifeo' = 'IFEO Debugger'
    'm5.g.wmi' = 'Persistent WMI event subscriptions'
    'm5.g.excl' = 'Defender exclusion list'
    'm5.g.hosts' = 'hosts file'
    'm5.g.proxy' = 'Proxy / PAC'
    'm5.g.count' = '{0} items'
    'm5.h.location' = 'Executable runs from a temp/public location (Temp/Public) — commonly abused by malware.'
    'm5.h.unquoted' = 'Path contains spaces but is not quoted — can be hijacked with a decoy file (unquoted path).'
    'm5.h.unsigned' = 'No valid digital signature.'
    'm5.h.signed' = 'Signed by: {0}'
    'm5.h.nofile' = 'File not found for signature check (may have been deleted).'
    'm5.h.noexe' = 'Could not determine the executable from the command.'
    'm5.h.run' = 'Runs automatically at sign-in (registry Run key).'
    'm5.h.startup' = 'Lives in the Startup folder — runs automatically at sign-in.'
    'm5.h.task' = 'Non-Microsoft scheduled task.'
    'm5.h.svc' = 'Third-party service starting with Windows.'
    'm5.h.shell.bad' = 'Shell is no longer the standard "explorer.exe" — rare hijack sign, review now.'
    'm5.h.shell.ok' = 'Standard value "explorer.exe".'
    'm5.h.userinit.bad' = 'Userinit lacks the standard "userinit.exe," — rare hijack sign, review now.'
    'm5.h.userinit.ok' = 'Standard value (contains "userinit.exe,").'
    'm5.h.ifeo' = 'Debugger value present in IFEO — some legit dev tools use it, but malware likes it to block/hijack processes.'
    'm5.h.wmi' = 'Persistent WMI event subscription — very few legit products use it, review carefully.'
    'm5.h.excl.path' = 'Listed as a Defender exclusion — malware often adds itself here to dodge scans.'
    'm5.h.excl.ext' = 'Extension excluded from scanning: {0}'
    'm5.h.excl.proc' = 'Process excluded from scanning: {0}'
    'm5.h.excl.none' = 'No exclusions.'
    'm5.h.hosts' = 'hosts file has custom lines (blocking/redirecting domains) — could be yours or added by software.'
    'm5.h.hosts.ok' = 'Only standard lines (localhost / comments).'
    'm5.h.proxy' = 'A manual proxy/PAC is configured — if you did not set it, investigate.'
    'm5.h.proxy.none' = 'No manual proxy/PAC configured.'
    'm5.a.hash' = 'SHA-256'
    'm5.a.vt' = 'Check VirusTotal'
    'm5.a.disable' = 'Disable'
    'm5.hash.title' = 'SHA-256 hash'
    'm5.hash.msg' = "SHA-256:`n{0}`n`nFile: {1}`n`nCopied to clipboard."
    'm5.vt.opening' = 'Opening VirusTotal with the hash (hash lookup only — your file is NOT uploaded).'
    'm5.reg.copied' = 'Registry path copied — open Registry Editor and paste (Ctrl+V) into the address bar.'
    'm5.dis.confirm.title' = 'Disable startup item'
    'm5.dis.confirm.msg' = ('Disable startup of "{0}"?' + "`n" + 'WinCare deletes NOTHING — it only sets the "disabled" flag the same way Task Manager does (StartupApproved). The app still runs fine when you open it yourself.')
    'm5.dis.confirm.undo' = 'Undoable: press "Undo" in History, or re-enable in Task Manager.'
    'm5.journal.disable' = 'Disable startup item'
    'm5.dis.enabled' = 'Enabled'
    'm5.open.parent' = 'File not found — opening its parent folder.'
    'm5.filenotfound' = 'File not found for inspection.'
    'm5.expert.l2' = 'Update-MpSignature; Start-MpScan -ScanType QuickScan|FullScan|CustomScan; Start-MpWDOScan; Get-MpThreat; Get-MpThreatDetection; Remove-MpThreat; Stop-MpScan'
    'm5.expert.l3' = 'Get-Item HKLM/HKCU:...\CurrentVersion\Run; Get-ScheduledTask; Get-CimInstance Win32_Service; Get-AuthenticodeSignature; Get-MpPreference; __EventFilter/__EventConsumer'
}

# Hashtable tinh cua module: cache ket qua kiem chu ky so (path + LastWriteTime).
# Truyen vao worker qua -Args (hashtable la reference type -> chia se that).
$Script:WcM5SigCache = @{}

# ---------------------------------------------------------------------------
# Helpers dung chung cua module
# ---------------------------------------------------------------------------
function ConvertTo-WCM5TimeText {
    # DateTime (co the string) -> "yyyy-MM-dd HH:mm"; loi -> "Khong ro"
    param($Value)
    if ($null -eq $Value) { return (T 'common.unknown') }
    try { return ('{0:yyyy-MM-dd HH:mm}' -f [datetime]$Value) } catch { return (T 'common.unknown') }
}

function Get-WCM5Worst {
    # Tra muc xau nhat trong danh sach Ok/Warn/Bad/Unknown
    param([string[]]$Statuses)
    foreach ($s in @('Bad', 'Warn', 'Unknown')) {
        foreach ($x in $Statuses) { if ($x -eq $s) { return $s } }
    }
    return 'Ok'
}

function ConvertTo-WCM5NetRegPath {
    # 'HKLM:\A\B' -> 'HKEY_LOCAL_MACHINE\A\B' (dung cho Registry.SetValue + clipboard)
    param([string]$PsPath)
    if ([string]::IsNullOrEmpty($PsPath)) { return '' }
    if ($PsPath.StartsWith('HKLM:\')) { return ('HKEY_LOCAL_MACHINE\' + $PsPath.Substring(6)) }
    if ($PsPath.StartsWith('HKCU:\')) { return ('HKEY_CURRENT_USER\' + $PsPath.Substring(6)) }
    return $PsPath
}

function Get-WCM5L1Sources { return @('mpstatus', 'av', 'firewall', 'smartscreen', 'uac', 'bitlocker', 'wupending') }

# ---------------------------------------------------------------------------
# LOP 1 — DU LIEU TRANG THAI BAO VE (moi nguon mot key rieng, try/catch rieng)
# ---------------------------------------------------------------------------
function Get-WCM5FirewallRaw {
    # COM HNetCfg.FwPolicy2, doc FirewallEnabled tung profile.
    # Luu y: theo tai lieu Microsoft, NET_FW_PROFILE2 la Domain=1, Private=2,
    # Public=4 (yeu cau goc ghi 1/2/3 nhung gia tri 3 khong ton tai trong enum).
    $out = @()
    $fw = New-Object -ComObject HNetCfg.FwPolicy2
    $map = @(
        @{ Id = 1; Name = 'Domain' }
        @{ Id = 2; Name = 'Private' }
        @{ Id = 4; Name = 'Public' }
    )
    foreach ($m in $map) {
        $en = $null
        try { $en = [bool]$fw.FirewallEnabled($m['Id']) } catch { }
        $out += [PSCustomObject]@{ Profile = $m['Name']; Enabled = $en }
    }
    try { $null = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($fw) } catch { }
    return ,@($out)
}

function Get-WCM5SmartscreenRaw {
    $lm = Get-WCRegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' -Name 'SmartScreenEnabled'
    $cu = Get-WCRegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' -Name 'SmartScreenEnabled'
    return [PSCustomObject]@{ Machine = $lm; User = $cu }
}

function Get-WCM5UacRaw {
    $lua = Get-WCRegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'EnableLUA'
    $consent = Get-WCRegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'ConsentPromptBehaviorAdmin'
    return [PSCustomObject]@{ EnableLUA = $lua; Consent = $consent }
}

function Get-WCM5WuPendingRaw {
    # 3 dau hieu cap nhat cho khoi dong lai: CBS RebootPending, WU RebootRequired,
    # PendingFileRenameOperations
    $cbs = $false
    $wu = $false
    $ren = $false
    try { $cbs = Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending' } catch { }
    try { $wu = Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired' } catch { }
    $pfro = Get-WCRegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations'
    if ($null -ne $pfro) { $ren = $true }
    return [PSCustomObject]@{ Cbs = $cbs; Wu = $wu; Rename = $ren }
}

function Get-WCM5AvProducts {
    # AV ben thu ba qua root/SecurityCenter2 + giai ma productState.
    # GIAI DINH (best-effort, decode pho bien chua kiem chung tren moi may):
    #   hex = '{0:X6}' -f state; enabled  = nibble thu 3 (index 2) khac '0';
    #   updated = nibble thu 5 (index 4) bang '0'.
    param([switch]$Fresh)
    $r = $null
    if ($Fresh) {
        $r = Invoke-WCQuery -Key 'sec.av' -NoCache -Script {
            Get-CimInstance -Namespace 'root/SecurityCenter2' -ClassName 'AntiVirusProduct' -OperationTimeoutSec 10 -ErrorAction Stop
        }
    } else {
        $r = Invoke-WCQuery -Key 'sec.av' -CacheTtlSec 60 -Script {
            Get-CimInstance -Namespace 'root/SecurityCenter2' -ClassName 'AntiVirusProduct' -OperationTimeoutSec 10 -ErrorAction Stop
        }
    }
    if ($r.Status -ne 'Ok') { return $r }
    $items = @()
    $hasThird = $false
    foreach ($p in @($r.Data)) {
        if ($null -eq $p) { continue }
        $name = [string](Get-WCProp $p 'displayName')
        $state = Get-WCProp $p 'productState'
        $enabled = $null
        $updated = $null
        if ($null -ne $state) {
            try {
                $hex = '{0:X6}' -f ([int]$state)
                $enabled = ($hex[2] -ne '0')
                $updated = ($hex[4] -eq '0')
            } catch { }
        }
        if (($enabled -eq $true) -and ($name -notlike '*Defender*')) { $hasThird = $true }
        $items += [PSCustomObject]@{
            Name = $name; Enabled = $enabled; UpToDate = $updated
            Timestamp = (Get-WCProp $p 'timestamp'); State = $state
        }
    }
    return (New-WCResult -Status 'Ok' -Data ([PSCustomObject]@{ Items = $items; HasThirdParty = $hasThird }))
}

function Invoke-WCM5SourceQuery {
    param([Parameter(Mandatory)][string]$Key, [Parameter(Mandatory)][scriptblock]$Query, [switch]$Fresh)
    if ($Fresh) { return (Invoke-WCQuery -Key $Key -NoCache -Script $Query) }
    return (Invoke-WCQuery -Key $Key -CacheTtlSec 60 -Script $Query)
}

function Get-WCM5StatusData {
    # Dispatch tung nguon Lop 1; moi nguon goi Invoke-WCQuery voi key rieng
    # ('sec.mpstatus', 'sec.av', ...) -> ho tro FIXTURE va cache
    param([Parameter(Mandatory)][string]$Source, [switch]$Fresh)
    switch ($Source) {
        'mpstatus'   { return (Invoke-WCM5SourceQuery -Key 'sec.mpstatus' -Fresh:$Fresh -Query { Get-MpComputerStatus -ErrorAction Stop }) }
        'av'         { return (Get-WCM5AvProducts -Fresh:$Fresh) }
        'firewall'   { return (Invoke-WCM5SourceQuery -Key 'sec.firewall' -Fresh:$Fresh -Query { Get-WCM5FirewallRaw }) }
        'smartscreen' { return (Invoke-WCM5SourceQuery -Key 'sec.smartscreen' -Fresh:$Fresh -Query { Get-WCM5SmartscreenRaw }) }
        'uac'        { return (Invoke-WCM5SourceQuery -Key 'sec.uac' -Fresh:$Fresh -Query { Get-WCM5UacRaw }) }
        'bitlocker'  { return (Invoke-WCM5SourceQuery -Key 'sec.bitlocker' -Fresh:$Fresh -Query { Get-BitLockerVolume -ErrorAction Stop }) }
        'wupending'  { return (Invoke-WCM5SourceQuery -Key 'sec.wupending' -Fresh:$Fresh -Query { Get-WCM5WuPendingRaw }) }
    }
    return (New-WCResult -Status 'Unknown' -Reason 'Unknown source')
}

# ---------------------------------------------------------------------------
# LOP 2 — DU LIEU DE DOA (Get-MpThreat + Get-MpThreatDetection)
# ---------------------------------------------------------------------------
function Get-WCM5SeverityText {
    param($Sev, $SevId)
    if ($Sev) { return [string]$Sev }
    if ($null -ne $SevId) {
        switch ([int]$SevId) {
            1 { return (T 'm5.threat.sev.1') }
            2 { return (T 'm5.threat.sev.2') }
            3 { return (T 'm5.threat.sev.3') }
            4 { return (T 'm5.threat.sev.4') }
            5 { return (T 'm5.threat.sev.5') }
            default { return (T 'm5.threat.sev.fmt' @([string]$SevId)) }
        }
    }
    return (T 'm5.threat.sev.unknown')
}

function Get-WCM5CategoryText {
    # CategoryID map pho bien (best-effort; gia tri khac hien so goc)
    param($CatId)
    if ($null -eq $CatId) { return (T 'm5.threat.sev.unknown') }
    switch ([int]$CatId) {
        1 { return (T 'm5.threat.cat.1') }
        2 { return (T 'm5.threat.cat.2') }
        5 { return (T 'm5.threat.cat.5') }
        6 { return (T 'm5.threat.cat.6') }
        8 { return (T 'm5.threat.cat.8') }
        10 { return (T 'm5.threat.cat.10') }
        30 { return (T 'm5.threat.cat.30') }
        default { return (T 'm5.threat.cat.fmt' @([string]$CatId)) }
    }
}

function Get-WCM5ThreatStatusText {
    # ThreatStatusID map pho bien (best-effort; gia tri khac hien ma goc)
    param($StatusId)
    if ($null -eq $StatusId) { return (T 'm5.threat.sev.unknown') }
    switch ([int]$StatusId) {
        1 { return (T 'm5.threat.status.1') }
        2 { return (T 'm5.threat.status.2') }
        3 { return (T 'm5.threat.status.3') }
        4 { return (T 'm5.threat.status.4') }
        5 { return (T 'm5.threat.status.5') }
        6 { return (T 'm5.threat.status.6') }
        default { return (T 'm5.threat.status.fmt' @([string]$StatusId)) }
    }
}

function Get-WCM5ThreatsRaw {
    # Gop Get-MpThreat (ten, muc do) + Get-MpThreatDetection (tai nguyen, trang thai)
    $threats = @()
    $dets = @()
    try { $threats = @(Get-MpThreat -ErrorAction Stop) } catch { }
    try { $dets = @(Get-MpThreatDetection -ErrorAction Stop) } catch { }
    $detById = @{}
    foreach ($d in $dets) {
        if ($null -eq $d) { continue }
        $id = Get-WCProp $d 'ThreatID'
        if ($null -eq $id) { continue }
        $key = [string]$id
        if (-not $detById.ContainsKey($key)) { $detById[$key] = $d }
    }
    $rows = @()
    foreach ($t in $threats) {
        if ($null -eq $t) { continue }
        $id = Get-WCProp $t 'ThreatID'
        $key = ''
        if ($null -ne $id) { $key = [string]$id }
        $name = [string](Get-WCProp $t 'ThreatName')
        if ([string]::IsNullOrEmpty($name)) { $name = ('Threat #' + $key) }
        $d = $null
        if ($key -and $detById.ContainsKey($key)) { $d = $detById[$key] }
        $resTxt = ''
        $srcRes = $null
        if ($d) { $srcRes = Get-WCProp $d 'Resources' }
        if ($null -eq $srcRes) { $srcRes = Get-WCProp $t 'Resources' }
        if ($null -ne $srcRes) { $resTxt = [string]::Join(' | ', @($srcRes)) }
        $time = $null
        if ($d) { $time = Get-WCProp $d 'InitialDetectionTime' }
        $statusId = $null
        if ($d) { $statusId = Get-WCProp $d 'ThreatStatusID' }
        if ($null -eq $statusId) { $statusId = Get-WCProp $t 'ThreatStatusID' }
        $rows += [PSCustomObject]@{
            ThreatID = $id
            Name = $name
            Type = (Get-WCM5CategoryText (Get-WCProp $t 'CategoryID'))
            Severity = (Get-WCM5SeverityText (Get-WCProp $t 'Severity') (Get-WCProp $t 'SeverityID'))
            Resources = $resTxt
            Status = (Get-WCM5ThreatStatusText $statusId)
            DetectedAt = $time
            Active = (Get-WCProp $t 'IsActive')
        }
    }
    return $rows
}

# ---------------------------------------------------------------------------
# LOP 3 — HEURISTIC DAU HIEU BAT THUONG
# ---------------------------------------------------------------------------
function Test-WCM5SuspiciousLocation {
    # Temp / Public / AppData\Local\Temp -> vi tri "dang ngo"
    param([Parameter(Mandatory)][string]$Path)
    try {
        $p = $Path.ToLowerInvariant()
        if ($p.Contains('\temp\')) { return $true }
        if ($p.Contains('\appdata\local\temp\')) { return $true }
        if ($p.Contains('\users\public\')) { return $true }
    } catch { }
    return $false
}

function Get-WCM5CommandExePath {
    # Trich duong dan exe tu dong lenh (co the co tham so, co/khong ngoac kep)
    param([string]$Command)
    if ([string]::IsNullOrWhiteSpace($Command)) { return '' }
    $c = $Command.Trim()
    if ($c.StartsWith('"')) {
        $idx = $c.IndexOf('"', 1)
        if ($idx -gt 1) { return $c.Substring(1, ($idx - 1)) }
        return $c.Trim('"')
    }
    if (-not $c.Contains(' ')) { return $c }
    $m = [regex]::Match($c, '(?i)^(.{2,}?\.(exe|bat|cmd|com|scr|pif|ps1|vbs|js|jar|msi))(\s|$)')
    if ($m.Success) { return $m.Groups[1].Value }
    return ($c.Split(' ')[0])
}

function Get-WCM5AuthenticodeInfo {
    # Kiem chu ky so, cache theo path + LastWriteTime trong hashtable truyen vao
    param([string]$FilePath, $Cache)
    if ([string]::IsNullOrEmpty($FilePath)) { return $null }
    try {
        if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
            return @{ Status = 'Missing'; Signer = '' }
        }
    } catch { return @{ Status = 'Missing'; Signer = '' } }
    $stamp = ''
    try {
        $fi = Get-Item -LiteralPath $FilePath -ErrorAction Stop
        $stamp = [string]$fi.LastWriteTimeUtc.Ticks
    } catch { $stamp = '' }
    $ck = ($FilePath + '|' + $stamp)
    if ($Cache -and $Cache.ContainsKey($ck)) { return $Cache[$ck] }
    $info = $null
    try {
        $sig = Get-AuthenticodeSignature -LiteralPath $FilePath -ErrorAction Stop
        $st = [string](Get-WCProp $sig 'Status')
        $signer = ''
        try {
            $sc = Get-WCProp $sig 'SignerCertificate'
            if ($sc) { $signer = [string]$sc.Subject }
        } catch { }
        $status = 'Unknown'
        if ($st -eq 'Valid') { $status = 'Valid' }
        elseif ($st -eq 'NotSigned') { $status = 'NotSigned' }
        elseif (-not [string]::IsNullOrEmpty($st)) { $status = 'Invalid' }
        $info = @{ Status = $status; Signer = $signer }
    } catch {
        $info = @{ Status = 'Unknown'; Signer = '' }
    }
    if ($Cache) { $Cache[$ck] = $info }
    return $info
}

function Get-WCM5AssessTarget {
    # Danh gia 1 muc tieu (exe + lenh): 3 muc Ok/Warn/Bad + mang ly do cu the
    param([string]$ExePath, [string]$Command, $Cache, [switch]$SkipUnquoted)
    if ([string]::IsNullOrEmpty($ExePath)) {
        return @{ Level = 'Warn'; Reasons = @((T 'm5.h.noexe')) }
    }
    $level = 'Ok'
    $reasons = @()
    if (Test-WCM5SuspiciousLocation $ExePath) {
        $level = 'Bad'
        $reasons += (T 'm5.h.location')
    }
    if (-not $SkipUnquoted) {
        $cmdTxt = [string]$Command
        $quoted = $false
        if ($cmdTxt.Length -gt 0) { $quoted = $cmdTxt.StartsWith('"') }
        if ($ExePath.Contains(' ') -and (-not $quoted)) {
            if ($level -ne 'Bad') { $level = 'Warn' }
            $reasons += (T 'm5.h.unquoted')
        }
    }
    $sig = Get-WCM5AuthenticodeInfo -FilePath $ExePath -Cache $Cache
    if ($null -eq $sig) {
        if ($level -ne 'Bad') { $level = 'Warn' }
        $reasons += (T 'm5.h.nofile')
    } elseif ($sig.Status -eq 'Valid') {
        $reasons += (T 'm5.h.signed' @($sig.Signer))
    } elseif ($sig.Status -eq 'Missing') {
        # Tep khong ton tai (da go cai dat / entry bo vo nghia) -> dang "can xem"
        if ($level -ne 'Bad') { $level = 'Warn' }
        $reasons += (T 'm5.h.nofile')
    } else {
        if ($level -ne 'Bad') { $level = 'Warn' }
        $reasons += (T 'm5.h.unsigned')
    }
    return @{ Level = $level; Reasons = $reasons }
}

function New-WCM5Finding {
    # Object chuan cua 1 ket qua heuristic
    param([string]$Group, [string]$Title, [string]$Command, [string]$Path, [string]$Level,
          [string[]]$Reasons, [string]$OpenKind, [string]$OpenPath, [string]$RegPath,
          [bool]$CanDisable = $false, [string]$DisApproved = '', [string]$DisNetPath = '', [string]$DisValueName = '')
    if ([string]::IsNullOrEmpty($Level)) { $Level = 'Unknown' }
    return [PSCustomObject]@{
        Group = $Group; Title = $Title; Command = $Command; Path = $Path; Level = $Level
        Reasons = @($Reasons); OpenKind = $OpenKind; OpenPath = $OpenPath; RegPath = $RegPath
        CanDisable = $CanDisable; DisApproved = $DisApproved; DisNetPath = $DisNetPath; DisValueName = $DisValueName
    }
}

function Get-WCM5RunFindings {
    # Run/RunOnce: HKLM + HKCU + WOW6432Node. Moi gia tri 3 muc kem ly do.
    # Vo hieu hoa (chi voi Run): ghi StartupApproved nhu Task Manager.
    param($Cache)
    $findings = @()
    $sources = @(
        @{ PsPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run';     Wow = $false; Kind = 'Run' }
        @{ PsPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'; Wow = $false; Kind = 'RunOnce' }
        @{ PsPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run';     Wow = $false; Kind = 'Run' }
        @{ PsPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'; Wow = $false; Kind = 'RunOnce' }
        @{ PsPath = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run';     Wow = $true; Kind = 'Run' }
        @{ PsPath = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce'; Wow = $true; Kind = 'RunOnce' }
    )
    foreach ($src in $sources) {
        $key = $null
        try { $key = Get-Item -LiteralPath $src['PsPath'] -ErrorAction Stop } catch { continue }
        foreach ($vn in @($key.GetValueNames())) {
            $cmd = ''
            try { $cmd = [string]$key.GetValue($vn) } catch { }
            if ([string]::IsNullOrWhiteSpace($cmd)) { continue }
            $exe = Get-WCM5CommandExePath -Command $cmd
            $a = Get-WCM5AssessTarget -ExePath $exe -Command $cmd -Cache $Cache
            $canDis = ($src['Kind'] -eq 'Run')
            $approved = ''
            $netPath = ''
            if ($canDis) {
                if ($src['PsPath'].StartsWith('HKCU:')) {
                    $approved = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
                    $netPath = 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
                } elseif ($src['Wow']) {
                    $approved = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32'
                    $netPath = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32'
                } else {
                    $approved = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
                    $netPath = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
                }
            }
            $reasons = @((T 'm5.h.run')) + @($a.Reasons)
            $findings += (New-WCM5Finding -Group 'run' -Title ([string]$vn) -Command $cmd -Path $exe -Level $a.Level `
                -Reasons $reasons -OpenKind 'reg' -OpenPath '' -RegPath $src['PsPath'] `
                -CanDisable $canDis -DisApproved $approved -DisNetPath $netPath -DisValueName ([string]$vn))
        }
        try { $key.Close() } catch { }
    }
    return [PSCustomObject]@{ Findings = $findings; Error = '' }
}

function Get-WCM5StartupFindings {
    # Thu muc Startup (user + common); .lnk doc muc tieu qua COM WScript.Shell
    param($Cache)
    $findings = @()
    $folders = @(
        @{ Path = [Environment]::GetFolderPath('Startup');       Machine = $false }
        @{ Path = [Environment]::GetFolderPath('CommonStartup'); Machine = $true }
    )
    $sh = $null
    foreach ($f in $folders) {
        $dir = [string]$f['Path']
        if ([string]::IsNullOrEmpty($dir)) { continue }
        try { if (-not (Test-Path -LiteralPath $dir)) { continue } } catch { continue }
        $files = @()
        try { $files = @(Get-ChildItem -LiteralPath $dir -File -Force -ErrorAction Stop) } catch { continue }
        foreach ($file in $files) {
            $target = ''
            if ($file.Extension -ieq '.lnk') {
                if (-not $sh) {
                    try { $sh = New-Object -ComObject WScript.Shell } catch { $sh = $null }
                }
                if ($sh) {
                    try {
                        $lnk = $sh.CreateShortcut($file.FullName)
                        $target = [string]$lnk.TargetPath
                        try { $null = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($lnk) } catch { }
                    } catch { $target = '' }
                }
            } else {
                $target = $file.FullName
            }
            $a = $null
            if (-not [string]::IsNullOrEmpty($target)) {
                # TargetPath la duong dan thu (khong phai dong lenh) -> bo qua check ngoac
                $a = Get-WCM5AssessTarget -ExePath $target -Command ('"' + $target + '"') -Cache $Cache
            } else {
                $a = @{ Level = 'Warn'; Reasons = @((T 'm5.h.noexe')) }
            }
            if ($f['Machine']) {
                $approved = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'
                $netPath = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'
            } else {
                $approved = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'
                $netPath = 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'
            }
            $reasons = @((T 'm5.h.startup')) + @($a.Reasons)
            $cmdTxt = $file.FullName
            if (-not [string]::IsNullOrEmpty($target)) { $cmdTxt = $target }
            $findings += (New-WCM5Finding -Group 'startup' -Title $file.Name -Command $cmdTxt `
                -Path $target -Level $a.Level -Reasons $reasons -OpenKind 'file' -OpenPath $file.FullName `
                -RegPath '' -CanDisable $true -DisApproved $approved -DisNetPath $netPath -DisValueName $file.Name)
        }
    }
    if ($sh) { try { $null = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($sh) } catch { } }
    return [PSCustomObject]@{ Findings = $findings; Error = '' }
}

function Get-WCM5TaskFindings {
    # Scheduled Task ngoai Microsoft (TaskPath / Author khong gom Microsoft)
    param($Cache)
    $findings = @()
    $tasks = @()
    try { $tasks = @(Get-ScheduledTask -ErrorAction Stop) } catch {
        return [PSCustomObject]@{ Findings = $findings; Error = $_.Exception.Message }
    }
    foreach ($t in $tasks) {
        if ($null -eq $t) { continue }
        $taskPath = [string](Get-WCProp $t 'TaskPath')
        $author = [string](Get-WCProp $t 'Author')
        if ($taskPath -like '\Microsoft\*') { continue }
        if ($author -like '*Microsoft*') { continue }
        $taskName = [string](Get-WCProp $t 'TaskName')
        $state = [string](Get-WCProp $t 'State')
        $execs = @()
        $actions = Get-WCProp $t 'Actions'
        foreach ($act in @($actions)) {
            if ($null -eq $act) { continue }
            $e = [string](Get-WCProp $act 'Execute')
            if (-not [string]::IsNullOrEmpty($e)) { $execs += $e }
        }
        $execTxt = [string]::Join(' ; ', @($execs))
        if ([string]::IsNullOrEmpty($execTxt)) { $execTxt = '(?)' }
        $exe = ''
        if (@($execs).Count -gt 0) { $exe = Get-WCM5CommandExePath -Command ([string]$execs[0]) }
        # Execute cua task la truong rieng (khong tach argv) -> bo qua check ngoac kep
        $a = Get-WCM5AssessTarget -ExePath $exe -Command ('"' + $exe + '"') -Cache $Cache
        $reasons = @((T 'm5.h.task')) + @($a.Reasons)
        $level = $a.Level
        if ($level -eq 'Ok') { $level = 'Warn' }
        $cmdTxt = $execTxt
        if (-not [string]::IsNullOrEmpty($state)) { $cmdTxt = $cmdTxt + '  [' + $state + ']' }
        $findings += (New-WCM5Finding -Group 'task' -Title ($taskPath + $taskName) -Command $cmdTxt -Path $exe `
            -Level $level -Reasons $reasons -OpenKind 'taskschd' -OpenPath '' -RegPath '' -CanDisable $false)
    }
    return [PSCustomObject]@{ Findings = $findings; Error = '' }
}

function Get-WCM5ServiceFindings {
    # Dich vu auto-start ngoai thu muc Windows; duong dan khong ngoac + khoang trang -> canh bao
    param($Cache)
    $findings = @()
    $svcs = @()
    try {
        $svcs = @(Get-CimInstance -ClassName Win32_Service -Filter "StartMode='Auto'" `
            -Property Name,DisplayName,State,StartMode,PathName -OperationTimeoutSec 15 -ErrorAction Stop)
    } catch {
        return [PSCustomObject]@{ Findings = $findings; Error = $_.Exception.Message }
    }
    foreach ($s in $svcs) {
        if ($null -eq $s) { continue }
        $pn = [string](Get-WCProp $s 'PathName')
        if ([string]::IsNullOrWhiteSpace($pn)) { continue }
        if ($pn -like '*\Windows\*') { continue }
        $name = [string](Get-WCProp $s 'Name')
        $disp = [string](Get-WCProp $s 'DisplayName')
        $state = [string](Get-WCProp $s 'State')
        $exe = Get-WCM5CommandExePath -Command $pn
        $a = Get-WCM5AssessTarget -ExePath $exe -Command $pn -Cache $Cache
        $reasons = @((T 'm5.h.svc')) + @($a.Reasons)
        $level = $a.Level
        if ($level -eq 'Ok') { $level = 'Warn' }
        $findings += (New-WCM5Finding -Group 'svc' -Title ($disp + ' (' + $name + ')') `
            -Command ($pn + '  [' + $state + ']') -Path $exe -Level $level -Reasons $reasons `
            -OpenKind 'svc' -OpenPath $exe -RegPath '' -CanDisable $false)
    }
    return [PSCustomObject]@{ Findings = $findings; Error = '' }
}

function Get-WCM5WinlogonFindings {
    # Shell chuan = "explorer.exe"; Userinit chuan chua "userinit.exe,"
    $findings = @()
    $regPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    $shell = Get-WCRegistryValue -Path $regPath -Name 'Shell'
    $shellTxt = ''
    if ($null -ne $shell) { $shellTxt = ([string]$shell).Trim() }
    if ($null -eq $shell) {
        $findings += (New-WCM5Finding -Group 'winlogon' -Title 'Shell' -Command '' -Path '' -Level 'Unknown' `
            -Reasons @((T 'common.notread')) -OpenKind 'reg' -OpenPath '' -RegPath $regPath -CanDisable $false)
    } elseif ($shellTxt -eq 'explorer.exe') {
        $findings += (New-WCM5Finding -Group 'winlogon' -Title 'Shell' -Command $shellTxt -Path '' -Level 'Ok' `
            -Reasons @((T 'm5.h.shell.ok')) -OpenKind 'reg' -OpenPath '' -RegPath $regPath -CanDisable $false)
    } else {
        $findings += (New-WCM5Finding -Group 'winlogon' -Title 'Shell' -Command $shellTxt -Path '' -Level 'Bad' `
            -Reasons @((T 'm5.h.shell.bad')) -OpenKind 'reg' -OpenPath '' -RegPath $regPath -CanDisable $false)
    }
    $userinit = Get-WCRegistryValue -Path $regPath -Name 'Userinit'
    $uiTxt = ''
    if ($null -ne $userinit) { $uiTxt = [string]$userinit }
    if ($null -eq $userinit) {
        $findings += (New-WCM5Finding -Group 'winlogon' -Title 'Userinit' -Command '' -Path '' -Level 'Unknown' `
            -Reasons @((T 'common.notread')) -OpenKind 'reg' -OpenPath '' -RegPath $regPath -CanDisable $false)
    } elseif ($uiTxt -like '*userinit.exe*') {
        $findings += (New-WCM5Finding -Group 'winlogon' -Title 'Userinit' -Command $uiTxt -Path '' -Level 'Ok' `
            -Reasons @((T 'm5.h.userinit.ok')) -OpenKind 'reg' -OpenPath '' -RegPath $regPath -CanDisable $false)
    } else {
        $findings += (New-WCM5Finding -Group 'winlogon' -Title 'Userinit' -Command $uiTxt -Path '' -Level 'Bad' `
            -Reasons @((T 'm5.h.userinit.bad')) -OpenKind 'reg' -OpenPath '' -RegPath $regPath -CanDisable $false)
    }
    return [PSCustomObject]@{ Findings = $findings; Error = '' }
}

function Get-WCM5IfeoFindings {
    # IFEO Debugger: gia tri nao co -> liet ke (best-effort, co the la cong cu hop le)
    param($Cache)
    $findings = @()
    $rootPs = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options'
    $subs = @()
    try { $subs = @(Get-ChildItem -LiteralPath $rootPs -ErrorAction Stop) } catch {
        return [PSCustomObject]@{ Findings = $findings; Error = '' }
    }
    foreach ($sub in $subs) {
        if ($null -eq $sub) { continue }
        $childName = ''
        try { $childName = [string]$sub.PSChildName } catch { }
        if ([string]::IsNullOrEmpty($childName)) { continue }
        $dbg = ''
        try { $dbg = [string]$sub.GetValue('Debugger') } catch { }
        if ([string]::IsNullOrWhiteSpace($dbg)) { continue }
        $exe = Get-WCM5CommandExePath -Command $dbg
        $a = Get-WCM5AssessTarget -ExePath $exe -Command $dbg -Cache $Cache
        $reasons = @((T 'm5.h.ifeo')) + @($a.Reasons)
        $level = $a.Level
        if ($level -eq 'Ok') { $level = 'Warn' }
        $findings += (New-WCM5Finding -Group 'ifeo' -Title ($childName + ' - Debugger') -Command $dbg -Path $exe `
            -Level $level -Reasons $reasons -OpenKind 'reg' -OpenPath '' `
            -RegPath ($rootPs + '\' + $childName) -CanDisable $false)
    }
    return [PSCustomObject]@{ Findings = $findings; Error = '' }
}

function Get-WCM5WmiFindings {
    # __EventFilter / __EventConsumer / (binding ngam: consumer la phan nguy hiem)
    $findings = @()
    $consumers = @()
    try { $consumers = @(Get-CimInstance -Namespace 'root\subscription' -ClassName '__EventConsumer' -ErrorAction Stop) } catch {
        return [PSCustomObject]@{ Findings = $findings; Error = '' }
    }
    foreach ($c in $consumers) {
        if ($null -eq $c) { continue }
        $name = [string](Get-WCProp $c 'Name')
        $cmdl = [string](Get-WCProp $c 'CommandLineTemplate')
        $scriptTxt = [string](Get-WCProp $c 'ScriptText')
        $detail = ''
        if (-not [string]::IsNullOrEmpty($cmdl)) { $detail = $cmdl }
        elseif (-not [string]::IsNullOrEmpty($scriptTxt)) { $detail = ('script: ' + $scriptTxt) }
        else { $detail = $name }
        $exe = Get-WCM5CommandExePath -Command $detail
        $level = 'Warn'
        if (-not [string]::IsNullOrEmpty($exe)) {
            if (Test-WCM5SuspiciousLocation $exe) { $level = 'Bad' }
        }
        $findings += (New-WCM5Finding -Group 'wmi' -Title ('__EventConsumer: ' + $name) -Command $detail -Path $exe `
            -Level $level -Reasons @((T 'm5.h.wmi')) -OpenKind 'none' -OpenPath '' -RegPath '' -CanDisable $false)
    }
    $filters = @()
    try { $filters = @(Get-CimInstance -Namespace 'root\subscription' -ClassName '__EventFilter' -ErrorAction Stop) } catch { }
    foreach ($f in $filters) {
        if ($null -eq $f) { continue }
        $name = [string](Get-WCProp $f 'Name')
        $query = [string](Get-WCProp $f 'Query')
        $findings += (New-WCM5Finding -Group 'wmi' -Title ('__EventFilter: ' + $name) -Command $query -Path '' `
            -Level 'Warn' -Reasons @((T 'm5.h.wmi')) -OpenKind 'none' -OpenPath '' -RegPath '' -CanDisable $false)
    }
    return [PSCustomObject]@{ Findings = $findings; Error = '' }
}

function Get-WCM5ExclusionFindings {
    # ExclusionPath/Extension/Process cua Defender — ma doc hay tu them
    $findings = @()
    $pref = $null
    try { $pref = Get-MpPreference -ErrorAction Stop } catch {
        return [PSCustomObject]@{ Findings = $findings; Error = $_.Exception.Message }
    }
    $paths = @(Get-WCProp $pref 'ExclusionPath')
    $exts = @(Get-WCProp $pref 'ExclusionExtension')
    $procs = @(Get-WCProp $pref 'ExclusionProcess')
    foreach ($p in $paths) {
        if ([string]::IsNullOrEmpty([string]$p)) { continue }
        $findings += (New-WCM5Finding -Group 'excl' -Title ([string]$p) -Command ([string]$p) -Path ([string]$p) `
            -Level 'Warn' -Reasons @((T 'm5.h.excl.path')) -OpenKind 'file' -OpenPath ([string]$p) -RegPath '' -CanDisable $false)
    }
    foreach ($e in $exts) {
        if ([string]::IsNullOrEmpty([string]$e)) { continue }
        $findings += (New-WCM5Finding -Group 'excl' -Title ('*.' + [string]$e) -Command ([string]$e) -Path '' `
            -Level 'Warn' -Reasons @((T 'm5.h.excl.ext' @([string]$e))) -OpenKind 'none' -OpenPath '' -RegPath '' -CanDisable $false)
    }
    foreach ($pr in $procs) {
        if ([string]::IsNullOrEmpty([string]$pr)) { continue }
        $findings += (New-WCM5Finding -Group 'excl' -Title ([string]$pr) -Command ([string]$pr) -Path '' `
            -Level 'Warn' -Reasons @((T 'm5.h.excl.proc' @([string]$pr))) -OpenKind 'none' -OpenPath '' -RegPath '' -CanDisable $false)
    }
    if ($findings.Count -eq 0) {
        $findings += (New-WCM5Finding -Group 'excl' -Title 'Exclusions' -Command '' -Path '' -Level 'Ok' `
            -Reasons @((T 'm5.h.excl.none')) -OpenKind 'none' -OpenPath '' -RegPath '' -CanDisable $false)
    }
    return [PSCustomObject]@{ Findings = $findings; Error = '' }
}

function Get-WCM5HostsFindings {
    # Doc hosts; dong khong phai comment/localhost -> liet ke
    $findings = @()
    $hostsPath = ''
    try { $hostsPath = Join-Path ([Environment]::GetFolderPath('System')) 'drivers\etc\hosts' } catch {
        return [PSCustomObject]@{ Findings = $findings; Error = $_.Exception.Message }
    }
    $lines = @()
    try { $lines = [IO.File]::ReadAllLines($hostsPath) } catch {
        return [PSCustomObject]@{ Findings = $findings; Error = $_.Exception.Message }
    }
    foreach ($ln in $lines) {
        $t = ''
        try { $t = ([string]$ln).Trim() } catch { continue }
        if ([string]::IsNullOrEmpty($t)) { continue }
        if ($t.StartsWith('#')) { continue }
        if ($t -match '(?i)localhost') { continue }
        $findings += (New-WCM5Finding -Group 'hosts' -Title $t -Command $t -Path '' -Level 'Warn' `
            -Reasons @((T 'm5.h.hosts')) -OpenKind 'hosts' -OpenPath $hostsPath -RegPath '' -CanDisable $false)
    }
    if ($findings.Count -eq 0) {
        $findings += (New-WCM5Finding -Group 'hosts' -Title 'hosts' -Command $hostsPath -Path '' -Level 'Ok' `
            -Reasons @((T 'm5.h.hosts.ok')) -OpenKind 'hosts' -OpenPath $hostsPath -RegPath '' -CanDisable $false)
    }
    return [PSCustomObject]@{ Findings = $findings; Error = '' }
}

function Get-WCM5ProxyFindings {
    # WinINET: ProxyServer/ProxyOverride/AutoConfigURL (HKCU)
    $findings = @()
    $is = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
    $enable = Get-WCRegistryValue -Path $is -Name 'ProxyEnable'
    $server = Get-WCRegistryValue -Path $is -Name 'ProxyServer'
    $override = Get-WCRegistryValue -Path $is -Name 'ProxyOverride'
    $pac = Get-WCRegistryValue -Path $is -Name 'AutoConfigURL'
    if (($enable -eq 1) -and ($null -ne $server)) {
        $detail = [string]$server
        if ($null -ne $override) { $detail = $detail + '  (bỏ qua: ' + [string]$override + ')' }
        $findings += (New-WCM5Finding -Group 'proxy' -Title 'Proxy' -Command $detail -Path '' -Level 'Warn' `
            -Reasons @((T 'm5.h.proxy')) -OpenKind 'reg' -OpenPath '' -RegPath $is -CanDisable $false)
    }
    if ($null -ne $pac) {
        $findings += (New-WCM5Finding -Group 'proxy' -Title 'AutoConfigURL (PAC)' -Command ([string]$pac) -Path '' `
            -Level 'Warn' -Reasons @((T 'm5.h.proxy')) -OpenKind 'reg' -OpenPath '' -RegPath $is -CanDisable $false)
    }
    if ($findings.Count -eq 0) {
        $findings += (New-WCM5Finding -Group 'proxy' -Title 'Proxy / PAC' -Command '' -Path '' -Level 'Ok' `
            -Reasons @((T 'm5.h.proxy.none')) -OpenKind 'reg' -OpenPath '' -RegPath $is -CanDisable $false)
    }
    return [PSCustomObject]@{ Findings = $findings; Error = '' }
}

function Get-WCM5HeuristicsGroup {
    # Chay 1 nhom heuristic (goi tu worker; loi bat trong nay khong lam sap task)
    param([Parameter(Mandatory)][string]$Group, $Cache)
    try {
        switch ($Group) {
            'run'      { return (Get-WCM5RunFindings -Cache $Cache) }
            'startup'  { return (Get-WCM5StartupFindings -Cache $Cache) }
            'task'     { return (Get-WCM5TaskFindings -Cache $Cache) }
            'svc'      { return (Get-WCM5ServiceFindings -Cache $Cache) }
            'winlogon' { return (Get-WCM5WinlogonFindings) }
            'ifeo'     { return (Get-WCM5IfeoFindings -Cache $Cache) }
            'wmi'      { return (Get-WCM5WmiFindings) }
            'excl'     { return (Get-WCM5ExclusionFindings) }
            'hosts'    { return (Get-WCM5HostsFindings) }
            'proxy'    { return (Get-WCM5ProxyFindings) }
        }
        return [PSCustomObject]@{ Findings = @(); Error = ('Unknown group: ' + $Group) }
    } catch {
        return [PSCustomObject]@{ Findings = @(); Error = $_.Exception.Message }
    }
}

# ---------------------------------------------------------------------------
# HANH DONG (vo hieu hoa muc khoi dong — dao nguoc duoc qua journal)
# ---------------------------------------------------------------------------
function Invoke-WCM5DisableStartup {
    # Vo hieu hoa muc Run key / Startup folder bang StartupApproved (12 byte
    # 02 00 ... nhu Task Manager). KHONG xoa gia tri goc. Ghi journal voi
    # UndoType 'startup.enable' (handler co san trong 05-Journal.ps1) de bat lai.
    param($State, $Finding)
    $f = $Finding
    $approved = [string](Get-WCProp $f 'DisApproved')
    $netPath = [string](Get-WCProp $f 'DisNetPath')
    $vn = [string](Get-WCProp $f 'DisValueName')
    $title = [string](Get-WCProp $f 'Title')
    if ([string]::IsNullOrEmpty($approved) -or [string]::IsNullOrEmpty($vn)) {
        Show-WCToast (T 'common.nodata') 'Warn'
        return
    }
    $msg = (T 'm5.dis.confirm.msg' @($title))
    if (-not (Show-WCConfirm -Title (T 'm5.dis.confirm.title') -Message $msg -Undoable (T 'm5.dis.confirm.undo'))) { return }
    if (Test-WCDryRunMode) {
        Show-WCInfo -Title (T 'common.dryrun.header') -Message ('[DRY-RUN] ' + $approved + ' -> ' + $vn + ' = 02 00 00 00 00 00 00 00 00 00 00 00')
        return
    }
    # Ghi journal TRUOC khi lam (spec 2.4); UndoArgs dung cho handler 'startup.enable'
    $entry = Add-WCJournalEntry -Module 'M5' -Action (T 'm5.journal.disable') -Target $title `
        -OldValue (T 'm5.dis.enabled') -UndoType 'startup.enable' -UndoArgs @{
            RegPath = $netPath; ValueName = $vn }
    try {
        if (-not (Test-Path -LiteralPath $approved)) {
            New-Item -Path $approved -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
        # 12 byte: 02 00 00 00 00 00 00 00 00 00 00 00 = "da tat" (12 byte 0 = bat lai)
        New-ItemProperty -Path $approved -Name $vn -Value ([byte[]](2,0,0,0,0,0,0,0,0,0,0,0)) `
            -PropertyType Binary -Force -ErrorAction Stop | Out-Null
        Complete-WCJournalEntry -Entry $entry -Result 'Ok'
        Show-WCToast (T 'common.success') 'Ok'
        Invoke-WCM5HeurScan $State
    } catch {
        Complete-WCJournalEntry -Entry $entry -Result ('Failed: ' + $_.Exception.Message)
        Show-WCError (T 'common.error') $_.Exception.Message
    }
}

# ---------------------------------------------------------------------------
# UI — LOP 1
# ---------------------------------------------------------------------------
function New-WCM5L1Block {
    # 1 khoi trang thai: header (tieu de + chip) + body (skeleton khi dang tai)
    param($Parent, [string]$Title)
    $outer = New-WCVStack -Spacing 4
    $header = New-WCHStack -Spacing 10
    $t = New-WCTextBlock -Text $Title -Size 13.5 -Weight 'SemiBold'
    $t.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $null = Add-WCChild $header $t
    $chip = New-WCStatusChip -Status 'Unknown'
    $chip.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $null = Add-WCChild $header $chip
    $null = Add-WCChild $outer $header
    $body = New-WCVStack -Spacing 5
    $skel = New-WCSkeleton
    $null = Add-WCChild $body $skel
    $null = Add-WCChild $outer $body
    $null = Add-WCChild $outer (New-WCSpacer -Height 6)
    $null = Add-WCChild $Parent $outer
    return @{ Root = $outer; Body = $body; Chip = $chip; Skeleton = $skel }
}

function Reset-WCM5BlockBody {
    param($Block)
    $Block['Skeleton'].Visibility = [Windows.Visibility]::Collapsed
    $Block['Body'].Children.Clear()
}

function Set-WCM5BlockChip {
    param($Block, [string]$Status)
    $bgKey = 'WcUnknownBg'
    $fgKey = 'WcUnknown'
    switch ($Status) {
        'Ok'   { $bgKey = 'WcOkBg';   $fgKey = 'WcOk' }
        'Warn' { $bgKey = 'WcWarnBg'; $fgKey = 'WcWarn' }
        'Bad'  { $bgKey = 'WcBadBg';  $fgKey = 'WcBad' }
    }
    $chip = $Block['Chip']
    try {
        $chip.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, $bgKey)
        if ($chip.Tag -is [Windows.Controls.TextBlock]) {
            $chip.Tag.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, $fgKey)
            $chip.Tag.Text = (T ('common.status.' + $Status.ToLower()))
        }
    } catch { }
}

function Add-WCM5BlockLine {
    # 1 dong: chip trang thai + chu
    param($Body, [string]$Status, [string]$Text)
    $h = New-WCHStack -Spacing 8
    $chip = New-WCStatusChip -Status $Status
    $chip.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $null = Add-WCChild $h $chip
    $t = New-WCTextBlock -Text $Text -Size 12.5 -Wrap
    $t.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $null = Add-WCChild $h $t
    $null = Add-WCChild $Body $h
}

function Add-WCM5BlockGuide {
    # Dong huong dan "cach bat" (khong tu bat)
    param($Body, [string]$Text)
    $t = New-WCTextBlock -Text ('→ ' + $Text) -Size 11.5 -ColorKey 'WcSubtle' -Wrap
    $null = Add-WCChild $Body $t
}

function Add-WCM5BlockField {
    param($Body, [string]$Label, [string]$Value)
    $null = Add-WCChild $Body (New-WCFieldRow -Label $Label -Value $Value)
}

function Update-WCM5DefenderBlock {
    param($Block, $Result)
    Reset-WCM5BlockBody $Block
    if (($Result.Status -ne 'Ok') -or ($null -eq $Result.Data)) {
        Set-WCM5BlockChip $Block 'Unknown'
        Add-WCM5BlockLine $Block['Body'] 'Unknown' (T 'common.notread.fmt' @($Result.Reason))
        Add-WCM5BlockLine $Block['Body'] 'Bad' (T 'm5.def.mode.off')
        return
    }
    $d = $Result.Data
    $statuses = @()
    # Che do hoat dong (kem passive do AV ben thu ba)
    $mode = [string](Get-WCProp $d 'AMRunningMode')
    $modeStatus = 'Unknown'
    $modeTxt = ''
    if ($mode -eq 'Normal') { $modeStatus = 'Ok'; $modeTxt = (T 'm5.def.mode.normal') }
    elseif ($mode -like '*Passive*') { $modeStatus = 'Warn'; $modeTxt = (T 'm5.def.mode.passive') }
    else { $modeStatus = 'Bad'; $modeTxt = (T 'm5.def.mode.off') }
    $statuses += $modeStatus
    Add-WCM5BlockLine $Block['Body'] $modeStatus (T 'm5.def.mode' @($modeTxt))
    # Bao ve thoi gian thuc
    $rtp = Get-WCProp $d 'RealTimeProtectionEnabled'
    $rtpStatus = 'Unknown'
    if ($rtp -eq $true) { $rtpStatus = 'Ok' }
    elseif ($rtp -eq $false) { $rtpStatus = 'Bad' }
    $statuses += $rtpStatus
    Add-WCM5BlockLine $Block['Body'] $rtpStatus (T 'm5.def.rtp')
    if ($rtpStatus -eq 'Bad') { Add-WCM5BlockGuide $Block['Body'] (T 'm5.def.rtp.how') }
    # Chu ky virus
    $age = Get-WCProp $d 'AntivirusSignatureAge'
    $lastUpd = Get-WCProp $d 'AntivirusSignatureLastUpdated'
    $sigStatus = 'Unknown'
    if ($null -ne $age) {
        $sigStatus = 'Ok'
        if ([double]$age -gt 7) { $sigStatus = 'Warn' }
        Add-WCM5BlockLine $Block['Body'] $sigStatus (T 'm5.def.sig.age' @([string][int]$age, (ConvertTo-WCM5TimeText $lastUpd)))
        if ($sigStatus -eq 'Warn') { Add-WCM5BlockGuide $Block['Body'] (T 'm5.def.sig.stale') }
    } else {
        Add-WCM5BlockLine $Block['Body'] 'Unknown' (T 'm5.def.sig.unknown')
    }
    $statuses += $sigStatus
    # Engine
    $eng = Get-WCProp $d 'AntivirusEngineVersion'
    if ($null -ne $eng) { Add-WCM5BlockField $Block['Body'] (T 'm5.def.engine') ([string]$eng) }
    # Lan quet gan nhat
    $qs = Get-WCProp $d 'QuickScanEndTime'
    $fs = Get-WCProp $d 'FullScanEndTime'
    $qsTxt = (T 'm5.def.never')
    if ($null -ne $qs) { $qsTxt = (ConvertTo-WCM5TimeText $qs) }
    $fsTxt = (T 'm5.def.never')
    if ($null -ne $fs) { $fsTxt = (ConvertTo-WCM5TimeText $fs) }
    Add-WCM5BlockField $Block['Body'] (T 'm5.def.quick') $qsTxt
    Add-WCM5BlockField $Block['Body'] (T 'm5.def.full') $fsTxt
    # Tamper Protection
    $tp = Get-WCProp $d 'IsTamperProtectionEnabled'
    $tps = Get-WCProp $d 'TamperProtectionSource'
    $tpStatus = 'Unknown'
    if ($tp -eq $true) { $tpStatus = 'Ok' }
    elseif ($tp -eq $false) { $tpStatus = 'Bad' }
    $statuses += $tpStatus
    if ($tp -eq $true) {
        Add-WCM5BlockLine $Block['Body'] 'Ok' (T 'm5.def.tamper')
    } elseif ($tp -eq $false) {
        Add-WCM5BlockLine $Block['Body'] 'Bad' (T 'm5.def.tamper')
        Add-WCM5BlockGuide $Block['Body'] (T 'm5.def.tamper.how')
    } elseif ($null -ne $tps) {
        Add-WCM5BlockLine $Block['Body'] 'Unknown' (T 'm5.def.tamper.source' @([string]$tps))
    } else {
        Add-WCM5BlockLine $Block['Body'] 'Unknown' (T 'm5.def.tamper')
    }
    Set-WCM5BlockChip $Block (Get-WCM5Worst $statuses)
}

function Update-WCM5AvBlock {
    param($Block, $Result)
    Reset-WCM5BlockBody $Block
    if ($Result.Status -ne 'Ok') {
        Set-WCM5BlockChip $Block 'Unknown'
        Add-WCM5BlockLine $Block['Body'] 'Unknown' (T 'common.notread.fmt' @($Result.Reason))
        return
    }
    $data = $Result.Data
    if ($null -eq $data) {
        Set-WCM5BlockChip $Block 'Unknown'
        Add-WCM5BlockLine $Block['Body'] 'Unknown' (T 'm5.av.none')
        return
    }
    $items = @(Get-WCProp $data 'Items')
    if (($items.Count -eq 0) -or (($items.Count -eq 1) -and ($null -eq $items[0]))) {
        Set-WCM5BlockChip $Block 'Unknown'
        Add-WCM5BlockLine $Block['Body'] 'Unknown' (T 'm5.av.none')
        return
    }
    $hasThird = ((Get-WCProp $data 'HasThirdParty') -eq $true)
    $statuses = @()
    foreach ($it in $items) {
        $on = Get-WCProp $it 'Enabled'
        $up = Get-WCProp $it 'UpToDate'
        $onStatus = 'Unknown'
        $onTxt = (T 'm5.av.unknown')
        if ($on -eq $true) { $onStatus = 'Ok'; $onTxt = (T 'm5.av.on') }
        elseif ($on -eq $false) { $onStatus = 'Warn'; $onTxt = (T 'm5.av.off') }
        $upStatus = 'Unknown'
        $upTxt = (T 'm5.av.unknown')
        if ($up -eq $true) { $upStatus = 'Ok'; $upTxt = (T 'm5.av.up') }
        elseif ($up -eq $false) { $upStatus = 'Warn'; $upTxt = (T 'm5.av.outdated') }
        $lineStatus = (Get-WCM5Worst @($onStatus, $upStatus))
        $statuses += $lineStatus
        Add-WCM5BlockLine $Block['Body'] $lineStatus (T 'm5.av.line' @([string](Get-WCProp $it 'Name'), $onTxt, $upTxt))
    }
    if ($hasThird) {
        $statuses += 'Warn'
        Add-WCM5BlockLine $Block['Body'] 'Warn' (T 'm5.av.thirdparty')
    }
    Add-WCM5BlockGuide $Block['Body'] (T 'm5.av.note')
    Set-WCM5BlockChip $Block (Get-WCM5Worst $statuses)
}

function Update-WCM5FirewallBlock {
    param($Block, $Result)
    Reset-WCM5BlockBody $Block
    if (($Result.Status -ne 'Ok') -or ($null -eq $Result.Data)) {
        Set-WCM5BlockChip $Block 'Unknown'
        Add-WCM5BlockLine $Block['Body'] 'Unknown' (T 'common.notread.fmt' @($Result.Reason))
        return
    }
    $statuses = @()
    $anyOff = $false
    foreach ($p in @($Result.Data)) {
        if ($null -eq $p) { continue }
        $prof = [string](Get-WCProp $p 'Profile')
        $en = Get-WCProp $p 'Enabled'
        $label = $prof
        if ($prof -eq 'Domain') { $label = (T 'm5.fw.domain') }
        elseif ($prof -eq 'Private') { $label = (T 'm5.fw.private') }
        elseif ($prof -eq 'Public') { $label = (T 'm5.fw.public') }
        $st = 'Unknown'
        $txt = (T 'm5.av.unknown')
        if ($en -eq $true) { $st = 'Ok'; $txt = (T 'm5.fw.on') }
        elseif ($en -eq $false) { $st = 'Bad'; $txt = (T 'm5.fw.off'); $anyOff = $true }
        $statuses += $st
        Add-WCM5BlockLine $Block['Body'] $st (T 'm5.fw.line' @($label, $txt))
    }
    if ($anyOff) { Add-WCM5BlockGuide $Block['Body'] (T 'm5.fw.how') }
    Set-WCM5BlockChip $Block (Get-WCM5Worst $statuses)
}

function Get-WCM5SmartScreenLine {
    # 1 dong SmartScreen tu gia tri registry (On/Warn/Off/khong dat)
    param($Body, [string]$Label, $Value)
    if ($null -eq $Value) {
        Add-WCM5BlockLine $Body 'Unknown' ($Label + ': ' + (T 'm5.ss.missing'))
        return 'Unknown'
    }
    $v = ([string]$Value).Trim()
    if ($v -ieq 'On') {
        Add-WCM5BlockLine $Body 'Ok' ($Label + ': ' + $v)
        return 'Ok'
    }
    if ($v -ieq 'Off') {
        Add-WCM5BlockLine $Body 'Bad' ($Label + ': ' + $v + ' — ' + (T 'm5.ss.off'))
        return 'Bad'
    }
    if ($v -ieq 'Warn') {
        Add-WCM5BlockLine $Body 'Warn' ($Label + ': ' + $v + ' — ' + (T 'm5.ss.warn'))
        return 'Warn'
    }
    Add-WCM5BlockLine $Body 'Unknown' ($Label + ': ' + $v)
    return 'Unknown'
}

function Update-WCM5SmartScreenBlock {
    param($Block, $Result)
    Reset-WCM5BlockBody $Block
    if (($Result.Status -ne 'Ok') -or ($null -eq $Result.Data)) {
        Set-WCM5BlockChip $Block 'Unknown'
        Add-WCM5BlockLine $Block['Body'] 'Unknown' (T 'common.notread.fmt' @($Result.Reason))
        return
    }
    $statuses = @()
    $statuses += (Get-WCM5SmartScreenLine $Block['Body'] (T 'm5.ss.machine') (Get-WCProp $Result.Data 'Machine'))
    $statuses += (Get-WCM5SmartScreenLine $Block['Body'] (T 'm5.ss.user') (Get-WCProp $Result.Data 'User'))
    Add-WCM5BlockGuide $Block['Body'] (T 'm5.ss.how')
    Set-WCM5BlockChip $Block (Get-WCM5Worst $statuses)
}

function Update-WCM5UacBlock {
    param($Block, $Result)
    Reset-WCM5BlockBody $Block
    if (($Result.Status -ne 'Ok') -or ($null -eq $Result.Data)) {
        Set-WCM5BlockChip $Block 'Unknown'
        Add-WCM5BlockLine $Block['Body'] 'Unknown' (T 'common.notread.fmt' @($Result.Reason))
        return
    }
    $lua = Get-WCProp $Result.Data 'EnableLUA'
    $consent = Get-WCProp $Result.Data 'Consent'
    $statuses = @()
    if ($lua -eq 1) {
        $statuses += 'Ok'
        Add-WCM5BlockLine $Block['Body'] 'Ok' (T 'm5.uac.on')
    } elseif ($lua -eq 0) {
        $statuses += 'Bad'
        Add-WCM5BlockLine $Block['Body'] 'Bad' (T 'm5.uac.off')
        Add-WCM5BlockGuide $Block['Body'] (T 'm5.uac.how')
    } else {
        $statuses += 'Unknown'
        Add-WCM5BlockLine $Block['Body'] 'Unknown' (T 'm5.uac.on')
    }
    if ($null -ne $consent) {
        Add-WCM5BlockField $Block['Body'] (T 'm5.uac.prompt') ([string]$consent)
    }
    Set-WCM5BlockChip $Block (Get-WCM5Worst $statuses)
}

function Update-WCM5BitlockerBlock {
    param($Block, $Result)
    Reset-WCM5BlockBody $Block
    if (($Result.Status -ne 'Ok') -or ($null -eq $Result.Data)) {
        Set-WCM5BlockChip $Block 'Unknown'
        Add-WCM5BlockLine $Block['Body'] 'Unknown' (T 'm5.bl.unread')
        return
    }
    $vols = @($Result.Data)
    if (($vols.Count -eq 0) -or (($vols.Count -eq 1) -and ($null -eq $vols[0]))) {
        Set-WCM5BlockChip $Block 'Unknown'
        Add-WCM5BlockLine $Block['Body'] 'Unknown' (T 'm5.bl.unread')
        return
    }
    $statuses = @()
    $anyDec = $false
    foreach ($v in $vols) {
        if ($null -eq $v) { continue }
        $mount = [string](Get-WCProp $v 'MountPoint')
        $vs = [string](Get-WCProp $v 'VolumeStatus')
        $ps = Get-WCProp $v 'ProtectionStatus'
        $st = 'Unknown'
        $txt = $vs
        if ($vs -eq 'FullyEncrypted') { $st = 'Ok'; $txt = (T 'm5.bl.enc') }
        elseif ($vs -eq 'FullyDecrypted') { $st = 'Warn'; $txt = (T 'm5.bl.dec'); $anyDec = $true }
        elseif (-not [string]::IsNullOrEmpty($vs)) { $st = 'Warn' }
        $protTxt = (T 'common.unknown')
        if ($ps -eq 1) { $protTxt = (T 'm5.bl.protected') }
        elseif ($ps -eq 0) { $protTxt = (T 'm5.bl.notprotected') }
        $statuses += $st
        Add-WCM5BlockLine $Block['Body'] $st (T 'm5.bl.line' @($mount, $txt, $protTxt))
    }
    if ($anyDec) { Add-WCM5BlockGuide $Block['Body'] (T 'm5.bl.how') }
    Set-WCM5BlockChip $Block (Get-WCM5Worst $statuses)
}

function Update-WCM5WuBlock {
    param($Block, $Result)
    Reset-WCM5BlockBody $Block
    if (($Result.Status -ne 'Ok') -or ($null -eq $Result.Data)) {
        Set-WCM5BlockChip $Block 'Unknown'
        Add-WCM5BlockLine $Block['Body'] 'Unknown' (T 'common.notread.fmt' @($Result.Reason))
        return
    }
    $cbs = (Get-WCProp $Result.Data 'Cbs') -eq $true
    $wu = (Get-WCProp $Result.Data 'Wu') -eq $true
    $ren = (Get-WCProp $Result.Data 'Rename') -eq $true
    $parts = @()
    if ($cbs) { $parts += (T 'm5.wu.cbs') }
    if ($wu) { $parts += (T 'm5.wu.wu') }
    if ($ren) { $parts += (T 'm5.wu.pfro') }
    if ($parts.Count -gt 0) {
        Set-WCM5BlockChip $Block 'Warn'
        Add-WCM5BlockLine $Block['Body'] 'Warn' (T 'm5.wu.pending' @([string]::Join(', ', $parts)))
        Add-WCM5BlockGuide $Block['Body'] (T 'm5.wu.how')
    } else {
        Set-WCM5BlockChip $Block 'Ok'
        Add-WCM5BlockLine $Block['Body'] 'Ok' (T 'm5.wu.none')
    }
}

function Update-WCM5L1Source {
    param($State, [string]$Source, $Result)
    $block = $State['L1'][$Source]
    if (-not $block) { return }
    try {
        switch ($Source) {
            'mpstatus'    { Update-WCM5DefenderBlock $block $Result }
            'av'          { Update-WCM5AvBlock $block $Result }
            'firewall'    { Update-WCM5FirewallBlock $block $Result }
            'smartscreen' { Update-WCM5SmartScreenBlock $block $Result }
            'uac'         { Update-WCM5UacBlock $block $Result }
            'bitlocker'   { Update-WCM5BitlockerBlock $block $Result }
            'wupending'   { Update-WCM5WuBlock $block $Result }
        }
    } catch {
        Write-WCLog 'ERROR' ('M5 update L1 [' + $Source + ']: ' + $_.Exception.Message)
        Set-WCM5BlockChip $block 'Unknown'
        Add-WCM5BlockLine $block['Body'] 'Unknown' (T 'common.notread.fmt' @($_.Exception.Message))
    }
}

function Start-WCM5StatusTask {
    # 1 task nen cho 1 nguon Lop 1 (Invoke-WCQuery key rieng trong worker)
    param($State, [string]$Source, [bool]$Fresh = $false)
    $srcName = $Source
    $null = Start-WCTask -Id ('m5.' + $Source) -Title (T ('m5.l1.s.' + $Source)) `
        -Args @{ Source = $Source; Fresh = $Fresh } -Worker {
            param($ctx, $s)
            return (Get-WCM5StatusData -Source ([string]$s['Source']) -Fresh:([bool]$s['Fresh']))
        } -Done {
            param($result)
            Update-WCM5L1Source $State $srcName $result
        }.GetNewClosure()
}

function Invoke-WCM5RefreshStatus {
    param($State)
    foreach ($src in (Get-WCM5L1Sources)) {
        Start-WCM5StatusTask $State $src $true
    }
}

# ---------------------------------------------------------------------------
# UI — LOP 2 (quet Defender + xu ly de doa)
# ---------------------------------------------------------------------------
function Invoke-WCM5SignatureUpdate {
    param($State)
    if (Test-WCTaskRunning 'm5.sig') {
        Show-WCToast (T 'common.running' @((T 'm5.sig.title'))) 'Info'
        return
    }
    $State['L2Status'].Text = (T 'common.loading')
    $ok = Start-WCTask -Id 'm5.sig' -Title (T 'm5.sig.title') -ShowStatus -Worker {
        param($ctx, $s)
        # Update-MpSignature la cmdlet chan: chay trong PowerShell con de vong
        # polling van cap nhat elapsed + xu ly Huy (ngung cho, dich vu co the
        # van cap nhat not — trung thuc, khong hua la huy duoc).
        $start = [DateTime]::Now
        $ctx.Progress(0, (T 'm5.sig.cancelnote'))
        $child = [PowerShell]::Create()
        $null = $child.AddScript('Update-MpSignature')
        $handle = $child.BeginInvoke()
        while (-not $handle.IsCompleted) {
            if ($ctx.Cancelled()) {
                try { $child.Stop() } catch { }
                Start-Sleep -Milliseconds 500
                try { $child.Dispose() } catch { }
                return [PSCustomObject]@{ Cancelled = $true }
            }
            $el = [int](([DateTime]::Now - $start).TotalSeconds)
            $ctx.Progress(0, ((T 'm5.elapsed' @([string]$el)) + ' — ' + (T 'm5.sig.cancelnote')))
            Start-Sleep -Milliseconds 1500
        }
        $errText = ''
        try { $null = $child.EndInvoke($handle) } catch { $errText = $_.Exception.Message }
        if (@($child.Streams.Error).Count -gt 0) { $errText = [string]$child.Streams.Error[0] }
        try { $child.Dispose() } catch { }
        if ($errText) { return [PSCustomObject]@{ Error = $errText } }
        return [PSCustomObject]@{ Ok = $true; Elapsed = [int](([DateTime]::Now - $start).TotalSeconds) }
    } -Done {
        param($r)
        if ($null -eq $r) { return }
        if (Get-WCProp $r 'Error') {
            $State['L2Status'].Text = (T 'm5.sig.error')
            Show-WCError (T 'm5.sig.error') ([string](Get-WCProp $r 'Error'))
            return
        }
        if (Get-WCProp $r 'Cancelled') {
            $State['L2Status'].Text = (T 'common.task.cancelled')
            return
        }
        $State['L2Status'].Text = (T 'm5.sig.done')
        Show-WCToast (T 'm5.sig.done') 'Ok'
        Start-WCM5StatusTask $State 'mpstatus' $true
    }.GetNewClosure()
    if (-not $ok) {
        Show-WCToast (T 'common.running' @((T 'm5.sig.title'))) 'Info'
    }
}

function Invoke-WCM5Scan {
    # Quick | Full | Custom — quet bang Defender trong PowerShell con; Huy =
    # Stop-MpScan; progress chi la elapsed + ghi ro "khong co tien do chi tiet"
    param($State, [string]$Mode)
    if (Test-WCTaskRunning 'm5.scan') {
        Show-WCToast (T 'common.running' @((T 'm5.scan.title'))) 'Info'
        return
    }
    $path = ''
    if ($Mode -eq 'Custom') {
        if ($State['FolderBox']) { $path = ([string]$State['FolderBox'].Text).Trim() }
        if ([string]::IsNullOrEmpty($path) -or (-not (Test-Path -LiteralPath $path -PathType Container))) {
            Show-WCToast (T 'm5.scan.folder.invalid') 'Warn'
            return
        }
    }
    $cmd = ''
    switch ($Mode) {
        'Quick'  { $cmd = 'Start-MpScan -ScanType QuickScan' }
        'Full'   { $cmd = 'Start-MpScan -ScanType FullScan' }
        'Custom' {
            $esc = $path.Replace('''', '''''')
            $cmd = 'Start-MpScan -ScanType CustomScan -ScanPath ''' + $esc + ''''
        }
    }
    $State['L2Status'].Text = (T 'common.loading')
    $scanArgs = @{ Cmd = $cmd; Mode = $Mode }
    $ok = Start-WCTask -Id 'm5.scan' -Title (T 'm5.scan.title') -ShowStatus -Args $scanArgs -Worker {
        param($ctx, $s)
        $start = [DateTime]::Now
        $ctx.Progress(0, (T 'm5.scan.noprogress'))
        $child = [PowerShell]::Create()
        $null = $child.AddScript([string]$s['Cmd'])
        $handle = $child.BeginInvoke()
        $cancelled = $false
        while (-not $handle.IsCompleted) {
            if ($ctx.Cancelled()) {
                # Huy = Stop-MpScan (yeu cau Defender dung quet), roi cho lenh tra ve
                $cancelled = $true
                try { Stop-MpScan -ErrorAction Stop } catch { $ctx.Log('Stop-MpScan loi: ' + $_.Exception.Message) }
                $null = $handle.AsyncWaitHandle.WaitOne(30000)
                break
            }
            $el = [int](([DateTime]::Now - $start).TotalSeconds)
            $ctx.Progress(0, ((T 'm5.elapsed' @([string]$el)) + ' — ' + (T 'm5.scan.noprogress')))
            Start-Sleep -Milliseconds 1500
        }
        $errText = ''
        if ($handle.IsCompleted) {
            try { $null = $child.EndInvoke($handle) } catch { $errText = $_.Exception.Message }
        } else {
            try { $child.Stop() } catch { }
        }
        if (@($child.Streams.Error).Count -gt 0) { $errText = [string]$child.Streams.Error[0] }
        try { $child.Dispose() } catch { }
        if ($cancelled) { return [PSCustomObject]@{ Cancelled = $true } }
        if ($errText) { return [PSCustomObject]@{ Error = $errText } }
        $threats = @(Get-WCM5ThreatsRaw)
        return [PSCustomObject]@{
            Ok = $true
            ElapsedSec = [int](([DateTime]::Now - $start).TotalSeconds)
            Threats = $threats
        }
    } -OnMessage {
        param($msg)
        if ($msg.Type -eq 'Progress') { $State['L2Status'].Text = [string]$msg.Text }
    }.GetNewClosure() -Done {
        param($r)
        if ($null -eq $r) { return }
        if (Get-WCProp $r 'Error') {
            $State['L2Status'].Text = (T 'm5.scan.error')
            Show-WCError (T 'm5.scan.error') ([string](Get-WCProp $r 'Error'))
            return
        }
        if (Get-WCProp $r 'Cancelled') {
            $State['L2Status'].Text = (T 'common.task.cancelled')
            return
        }
        $el = [string](Get-WCProp $r 'ElapsedSec')
        $State['L2Status'].Text = (T 'm5.scan.done' @($el))
        Show-WCToast (T 'm5.scan.done' @($el)) 'Ok'
        Show-WCM5Threats $State @(Get-WCProp $r 'Threats')
        Start-WCM5StatusTask $State 'mpstatus' $true
    }.GetNewClosure()
    if (-not $ok) {
        Show-WCToast (T 'common.running' @((T 'm5.scan.title'))) 'Info'
    }
}

function Invoke-WCM5OfflineScan {
    # Quet ngoai tuyen: canh bao RO RANG se khoi dong lai + xac nhan 2 buoc (Danger)
    param($State)
    if (Test-WCTaskRunning 'm5.wdo') {
        Show-WCToast (T 'common.running' @((T 'm5.l2.wdo'))) 'Info'
        return
    }
    if (-not (Show-WCConfirm -Title (T 'm5.wdo.confirm.title') -Message (T 'm5.wdo.confirm.msg') `
            -NotUndoable (T 'm5.wdo.confirm.noundo') -Danger)) { return }
    $null = Start-WCTask -Id 'm5.wdo' -Title (T 'm5.l2.wdo') -ShowStatus -Worker {
        param($ctx, $s)
        try {
            Start-MpWDOScan -ErrorAction Stop
            return [PSCustomObject]@{ Ok = $true }
        } catch {
            return [PSCustomObject]@{ Error = $_.Exception.Message }
        }
    } -Done {
        param($r)
        if (Get-WCProp $r 'Error') {
            Show-WCError (T 'm5.wdo.error') ([string](Get-WCProp $r 'Error'))
            return
        }
        $State['L2Status'].Text = (T 'm5.wdo.scheduled')
        Show-WCToast (T 'm5.wdo.scheduled') 'Warn'
    }.GetNewClosure()
}

function Show-WCM5Threats {
    # Bang: Moi de doa | Loai | Tai nguyen | Trang thai (+ nut Cach ly tung muc)
    param($State, $Rows)
    $body = $State['ThreatHost']
    if (-not $body) { return }
    $body.Children.Clear()
    $State['ThreatSection'].Root.Visibility = [Windows.Visibility]::Visible
    $rows = @($Rows)
    if (($rows.Count -eq 0) -or (($rows.Count -eq 1) -and ($null -eq $rows[0]))) {
        $null = Add-WCChild $body (New-WCTextBlock -Text (T 'm5.threat.none') -Size 12.5 -ColorKey 'WcSubtle' -Wrap)
        return
    }
    $grid = New-Object Windows.Controls.Grid
    $colDefs = @(
        @{ W = 220.0; Star = $false }
        @{ W = 130.0; Star = $false }
        @{ W = 0.0;   Star = $true }
        @{ W = 120.0; Star = $false }
        @{ W = 90.0;  Star = $false }
    )
    foreach ($colDef in $colDefs) {
        $d = New-Object Windows.Controls.ColumnDefinition
        if ($colDef['Star']) { $d.Width = (New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)) }
        else { $d.Width = (New-Object Windows.GridLength($colDef['W'])) }
        $grid.ColumnDefinitions.Add($d) | Out-Null
    }
    $rd = New-Object Windows.Controls.RowDefinition
    $rd.Height = [Windows.GridLength]::Auto
    $grid.RowDefinitions.Add($rd) | Out-Null
    $headers = @((T 'm5.threat.col.name'), (T 'm5.threat.col.type'), (T 'm5.threat.col.res'), (T 'm5.threat.col.status'), '')
    for ($c = 0; $c -lt 5; $c++) {
        $ht = New-WCTextBlock -Text ([string]$headers[$c]) -Size 11.5 -Weight 'SemiBold' -ColorKey 'WcSubtle'
        $ht.Margin = (New-Object Windows.Thickness(0, 0, 10, 4))
        [Windows.Controls.Grid]::SetColumn($ht, $c)
        [Windows.Controls.Grid]::SetRow($ht, 0)
        $grid.Children.Add($ht) | Out-Null
    }
    $rowIdx = 1
    foreach ($t in $rows) {
        if ($null -eq $t) { continue }
        $th = $t
        $rd2 = New-Object Windows.Controls.RowDefinition
        $rd2.Height = [Windows.GridLength]::Auto
        $grid.RowDefinitions.Add($rd2) | Out-Null
        $name = [string](Get-WCProp $th 'Name')
        $typeTxt = ([string](Get-WCProp $th 'Type') + ' · ' + [string](Get-WCProp $th 'Severity'))
        $resTxt = [string](Get-WCProp $th 'Resources')
        $statusTxt = [string](Get-WCProp $th 'Status')
        if ((Get-WCProp $th 'Active') -eq $true) { $statusTxt = $statusTxt + ' (' + (T 'm5.threat.active') + ')' }
        $cells = @($name, $typeTxt, $resTxt, $statusTxt)
        for ($c = 0; $c -lt 4; $c++) {
            $ct = New-WCTextBlock -Text ([string]$cells[$c]) -Size 12.5 -Wrap
            $ct.Margin = (New-Object Windows.Thickness(0, 0, 10, 6))
            $ct.TextTrimming = [Windows.TextTrimming]::CharacterEllipsis
            $ct.ToolTip = ([string]$cells[$c] + "`n" + (T 'm5.threat.at' @((ConvertTo-WCM5TimeText (Get-WCProp $th 'DetectedAt')))))
            [Windows.Controls.Grid]::SetColumn($ct, $c)
            [Windows.Controls.Grid]::SetRow($ct, $rowIdx)
            $grid.Children.Add($ct) | Out-Null
        }
        # Cach ly tung muc — CHI chay sau Show-WCConfirm tung muc (trong handler)
        $btn = New-WCButton -Text (T 'm5.threat.remove') -Small -OnClick {
            param($b)
            Invoke-WCM5RemoveThreat $State $th
        }.GetNewClosure()
        $btn.VerticalAlignment = [Windows.VerticalAlignment]::Center
        $btn.Margin = (New-Object Windows.Thickness(0, 0, 0, 6))
        [Windows.Controls.Grid]::SetColumn($btn, 4)
        [Windows.Controls.Grid]::SetRow($btn, $rowIdx)
        $grid.Children.Add($btn) | Out-Null
        $rowIdx++
    }
    $null = Add-WCChild $body $grid
}

function Invoke-WCM5LoadThreats {
    param($State)
    if (Test-WCTaskRunning 'm5.threats') { return }
    $null = Start-WCTask -Id 'm5.threats' -Title (T 'm5.threat.title') -Worker {
        param($ctx, $s)
        return [PSCustomObject]@{ Rows = @(Get-WCM5ThreatsRaw) }
    } -Done {
        param($r)
        if ($null -eq $r) { return }
        $State['ThreatsLoaded'] = $true
        Show-WCM5Threats $State @(Get-WCProp $r 'Rows')
    }.GetNewClosure()
}

function Invoke-WCM5RemoveThreat {
    # Cach ly qua Defender: xac nhan TUNG MUC; khong tu xoa; ghi journal
    # (UndoType '' = khong hoan tac tu dong — ghi ro trong confirm)
    param($State, $Threat)
    $th = $Threat
    $name = [string](Get-WCProp $th 'Name')
    $msg = (T 'm5.threat.confirm.msg' @($name))
    if (-not (Show-WCConfirm -Title (T 'm5.threat.confirm.title') -Message $msg `
            -NotUndoable (T 'm5.threat.confirm.noundo'))) { return }
    if (Test-WCDryRunMode) {
        Show-WCInfo -Title (T 'common.dryrun.header') -Message ('[DRY-RUN] Remove-MpThreat — ' + $name)
        return
    }
    $tid = Get-WCProp $th 'ThreatID'
    $entry = Add-WCJournalEntry -Module 'M5' -Action (T 'm5.threat.journal') -Target $name `
        -OldValue '' -UndoType '' -UndoArgs $null
    $ok = Start-WCTask -Id 'm5.remove' -Title (T 'm5.threat.confirm.title') -ShowStatus `
        -Args @{ ThreatID = $tid } -Worker {
            param($ctx, $s)
            if ($ctx.Cancelled()) { return [PSCustomObject]@{ Cancelled = $true } }
            try {
                $done = $false
                # Thu theo ThreatID; neu module khong ho tro tham so thi dung dang tong quat
                try {
                    if ($null -ne $s['ThreatID']) {
                        Remove-MpThreat -ThreatID ([long]$s['ThreatID']) -ErrorAction Stop
                        $done = $true
                    }
                } catch { }
                if (-not $done) { Remove-MpThreat -ErrorAction Stop }
                return [PSCustomObject]@{ Ok = $true }
            } catch {
                return [PSCustomObject]@{ Error = $_.Exception.Message }
            }
        } -Done {
            param($r)
            if (Get-WCProp $r 'Error') {
                Complete-WCJournalEntry -Entry $entry -Result ('Failed: ' + (Get-WCProp $r 'Error'))
                Show-WCError (T 'common.error') ([string](Get-WCProp $r 'Error'))
                return
            }
            if (Get-WCProp $r 'Cancelled') {
                Complete-WCJournalEntry -Entry $entry -Result 'Cancelled'
                return
            }
            Complete-WCJournalEntry -Entry $entry -Result 'Ok'
            Show-WCToast (T 'common.success') 'Ok'
            Invoke-WCM5LoadThreats $State
        }.GetNewClosure()
    if (-not $ok) {
        Complete-WCJournalEntry -Entry $entry -Result 'Skipped: task busy'
        Show-WCToast (T 'common.running' @((T 'm5.threat.confirm.title'))) 'Info'
    }
}

# ---------------------------------------------------------------------------
# UI — LOP 3 (heuristic)
# ---------------------------------------------------------------------------
function Invoke-WCM5HeurScan {
    param($State)
    if (Test-WCTaskRunning 'm5.heur') {
        Show-WCToast (T 'common.running' @((T 'm5.l3.title'))) 'Info'
        return
    }
    $State['L3Host'].Children.Clear()
    $State['L3Spinner'].Visibility = [Windows.Visibility]::Visible
    Set-WCM5SummaryChips $State -1 -1 -1
    $ok = Start-WCTask -Id 'm5.heur' -Title (T 'm5.l3.title') -ShowStatus `
        -Args @{ Cache = $Script:WcM5SigCache } -Worker {
            param($ctx, $s)
            # 1 task lon, tung nguon try/catch rieng (Get-WCM5HeuristicsGroup)
            # Progress theo SO NGUON da quet (that), khong phai % bia
            $groupKeys = @('run', 'startup', 'task', 'svc', 'winlogon', 'ifeo', 'wmi', 'excl', 'hosts', 'proxy')
            $out = @()
            $i = 0
            foreach ($g in $groupKeys) {
                if ($ctx.Cancelled()) { return [PSCustomObject]@{ Cancelled = $true } }
                $ctx.Progress(([int](($i * 100) / $groupKeys.Count)), (T ('m5.g.' + $g)))
                $out += (Get-WCM5HeuristicsGroup -Group $g -Cache $s['Cache'])
                $i++
            }
            $ctx.Progress(100, (T 'common.task.done'))
            return [PSCustomObject]@{ Groups = $out }
        } -Done {
            param($r)
            $State['L3Spinner'].Visibility = [Windows.Visibility]::Collapsed
            Show-WCM5Findings $State $r
        }.GetNewClosure()
    if (-not $ok) {
        $State['L3Spinner'].Visibility = [Windows.Visibility]::Collapsed
    }
}

function Set-WCM5SummaryChips {
    # -1 = dang tai (chip "Chua quet"/spinner)
    param($State, [int]$OkCount, [int]$WarnCount, [int]$BadCount)
    # LUU Y: khong dung ten bien $host (bien tu dong read-only cua PowerShell)
    $sumHost = $State['L3SummaryHost']
    if (-not $sumHost) { return }
    $sumHost.Children.Clear()
    if ($OkCount -lt 0) {
        $c = New-WCChip -Text (T 'm5.l3.idle') -Kind 'Plain'
        $sumHost.Children.Add($c) | Out-Null
        return
    }
    $chipOk = New-WCChip -Text ((T 'm5.level.ok') + ': ' + [string]$OkCount) -Kind 'Ok'
    $chipWarn = New-WCChip -Text ((T 'm5.level.warn') + ': ' + [string]$WarnCount) -Kind 'Warn'
    $chipBad = New-WCChip -Text ((T 'm5.level.bad') + ': ' + [string]$BadCount) -Kind 'Bad'
    $chipOk.Margin = (New-Object Windows.Thickness(0, 0, 8, 0))
    $chipWarn.Margin = (New-Object Windows.Thickness(0, 0, 8, 0))
    $sumHost.Children.Add($chipOk) | Out-Null
    $sumHost.Children.Add($chipWarn) | Out-Null
    $sumHost.Children.Add($chipBad) | Out-Null
}

function Add-WCM5FindingRow {
    param($Body, $Finding, $State)
    $f = $Finding
    $card = New-Object Windows.Controls.Border
    $card.Style = (Get-WCControlStyles)['WcListItem']
    $card.Padding = (New-Object Windows.Thickness(6, 6, 6, 6))
    $inner = New-WCVStack -Spacing 3
    # Hang 1: chip muc + tieu de
    $row1 = New-WCHStack -Spacing 8
    $level = [string](Get-WCProp $f 'Level')
    $chip = New-WCChip -Text (T ('m5.level.' + $level.ToLower())) -Kind $level
    $chip.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $null = Add-WCChild $row1 $chip
    $title = New-WCTextBlock -Text ([string](Get-WCProp $f 'Title')) -Size 13 -Weight 'SemiBold' -Wrap
    $title.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $null = Add-WCChild $row1 $title
    $null = Add-WCChild $inner $row1
    # Hang 2: lenh / duong dan
    $cmd = [string](Get-WCProp $f 'Command')
    if (-not [string]::IsNullOrEmpty($cmd)) {
        $t2 = New-WCTextBlock -Text $cmd -Size 11.5 -ColorKey 'WcSubtle' -Wrap
        $t2.FontFamily = New-Object Windows.Media.FontFamily('Consolas')
        $null = Add-WCChild $inner $t2
    }
    # Hang 3: ly do cu the
    $reasons = @(Get-WCProp $f 'Reasons')
    if ($reasons.Count -gt 0) {
        $null = Add-WCChild $inner (New-WCTextBlock -Text ([string]::Join(' · ', $reasons)) -Size 11.5 -ColorKey 'WcSubtle' -Wrap)
    }
    # Hang 4: dia chi registry (neu co)
    $regP = [string](Get-WCProp $f 'RegPath')
    if (-not [string]::IsNullOrEmpty($regP)) {
        $t4 = New-WCTextBlock -Text $regP -Size 11 -ColorKey 'WcSubtle' -Wrap
        $t4.FontFamily = New-Object Windows.Media.FontFamily('Consolas')
        $null = Add-WCChild $inner $t4
    }
    # Hang 5: cac nut
    $btnRow = New-WCHStack -Spacing 6
    $openKind = [string](Get-WCProp $f 'OpenKind')
    if ($openKind -ne 'none') {
        $null = Add-WCChild $btnRow (New-WCButton -Text (T 'common.openlocation') -Small -OnClick {
            param($b)
            Open-WCM5Location $f
        }.GetNewClosure())
    }
    $fp = [string](Get-WCProp $f 'Path')
    if (-not [string]::IsNullOrEmpty($fp)) {
        $null = Add-WCChild $btnRow (New-WCButton -Text (T 'm5.a.hash') -Small -OnClick {
            param($b)
            Invoke-WCM5Hash $State $f $false
        }.GetNewClosure())
        $null = Add-WCChild $btnRow (New-WCButton -Text (T 'm5.a.vt') -Small -OnClick {
            param($b)
            Invoke-WCM5Hash $State $f $true
        }.GetNewClosure())
    }
    if ((Get-WCProp $f 'CanDisable') -eq $true) {
        $null = Add-WCChild $btnRow (New-WCButton -Text (T 'm5.a.disable') -Small -Kind Danger -OnClick {
            param($b)
            Invoke-WCM5DisableStartup $State $f
        }.GetNewClosure())
    }
    if ($btnRow.Children.Count -gt 0) { $null = Add-WCChild $inner $btnRow }
    $card.Child = $inner
    $null = Add-WCChild $Body $card
}

function Show-WCM5Findings {
    param($State, $Result)
    $listHost = $State['L3Host']
    if (-not $listHost) { return }
    $listHost.Children.Clear()
    if ($null -eq $Result) {
        Set-WCM5SummaryChips $State -1 -1 -1
        return
    }
    if (Get-WCProp $Result 'Cancelled') {
        $null = Add-WCChild $listHost (New-WCTextBlock -Text (T 'm5.l3.cancelled') -Size 12.5 -ColorKey 'WcSubtle' -Wrap)
        Set-WCM5SummaryChips $State -1 -1 -1
        return
    }
    $groups = @(Get-WCProp $Result 'Groups')
    $ok = 0
    $warn = 0
    $bad = 0
    foreach ($g in $groups) {
        if ($null -eq $g) { continue }
        foreach ($fd in @(Get-WCProp $g 'Findings')) {
            if ($null -eq $fd) { continue }
            $lvl = [string](Get-WCProp $fd 'Level')
            if ($lvl -eq 'Bad') { $bad++ }
            elseif ($lvl -eq 'Warn') { $warn++ }
            elseif ($lvl -eq 'Ok') { $ok++ }
        }
    }
    Set-WCM5SummaryChips $State $ok $warn $bad
    foreach ($g in $groups) {
        if ($null -eq $g) { continue }
        $key = [string](Get-WCProp $g 'Key')
        $findings = @(Get-WCProp $g 'Findings')
        $err = [string](Get-WCProp $g 'Error')
        $gBad = 0
        $gWarn = 0
        foreach ($fd in $findings) {
            if ($null -eq $fd) { continue }
            $lvl = [string](Get-WCProp $fd 'Level')
            if ($lvl -eq 'Bad') { $gBad++ }
            elseif ($lvl -eq 'Warn') { $gWarn++ }
        }
        $summary = (T 'm5.g.count' @([string]$findings.Count))
        if ($gBad -gt 0) { $summary = $summary + (' · ' + (T 'm5.level.bad') + ': ' + [string]$gBad) }
        if ($gWarn -gt 0) { $summary = $summary + (' · ' + (T 'm5.level.warn') + ': ' + [string]$gWarn) }
        $exp = New-WCExpander -Title (T ('m5.g.' + $key)) -Summary $summary
        if (($gBad -gt 0) -or ($gWarn -gt 0)) { $exp.Root.IsExpanded = $true }
        if (-not [string]::IsNullOrEmpty($err)) {
            $null = Add-WCChild $exp.Body (New-WCTextBlock -Text (T 'm5.l3.errsource' @($err)) -Size 12 -ColorKey 'WcSubtle' -Wrap)
        }
        if (($findings.Count -eq 0) -and [string]::IsNullOrEmpty($err)) {
            $null = Add-WCChild $exp.Body (New-WCTextBlock -Text (T 'm5.l3.notfound') -Size 12 -ColorKey 'WcSubtle' -Wrap)
        }
        foreach ($fd in $findings) {
            if ($null -eq $fd) { continue }
            Add-WCM5FindingRow -Body $exp.Body -Finding $fd -State $State
        }
        $null = Add-WCChild $listHost $exp.Root
    }
}

# ---------------------------------------------------------------------------
# HANH DONG PHU: mo vi tri / SHA-256 / VirusTotal
# ---------------------------------------------------------------------------
function Open-WCM5Location {
    param($Finding)
    $f = $Finding
    $kind = [string](Get-WCProp $f 'OpenKind')
    try {
        switch ($kind) {
            'file' {
                $p = [string](Get-WCProp $f 'OpenPath')
                if ([string]::IsNullOrEmpty($p)) { $p = [string](Get-WCProp $f 'Path') }
                if ((-not [string]::IsNullOrEmpty($p)) -and (Test-Path -LiteralPath $p)) {
                    Start-Process explorer.exe -ArgumentList ('/select,"' + $p + '"')
                } else {
                    $parent = ''
                    try { $parent = Split-Path -Path $p -Parent } catch { }
                    if ((-not [string]::IsNullOrEmpty($parent)) -and (Test-Path -LiteralPath $parent)) {
                        Start-Process explorer.exe -ArgumentList $parent
                        Show-WCToast (T 'm5.open.parent') 'Info'
                    } else {
                        Show-WCToast (T 'm5.filenotfound') 'Warn'
                    }
                }
            }
            'svc' {
                $p = [string](Get-WCProp $f 'Path')
                if ((-not [string]::IsNullOrEmpty($p)) -and (Test-Path -LiteralPath $p)) {
                    Start-Process explorer.exe -ArgumentList ('/select,"' + $p + '"')
                } else {
                    Start-Process services.msc
                }
            }
            'reg' {
                $rp = [string](Get-WCProp $f 'RegPath')
                if (-not [string]::IsNullOrEmpty($rp)) {
                    # Regedit khong nhan tham so nhay den khoa -> copy duong dan
                    # dang .NET de nguoi dung dan vao thanh dia chi cua Registry Editor
                    Set-WCClipboard (ConvertTo-WCM5NetRegPath $rp)
                    Start-Process regedit
                    Show-WCToast (T 'm5.reg.copied') 'Info'
                }
            }
            'taskschd' { Start-Process taskschd.msc }
            'hosts' {
                $hp = [string](Get-WCProp $f 'OpenPath')
                Start-Process notepad.exe -ArgumentList ('"' + $hp + '"')
            }
            default { }
        }
    } catch {
        Show-WCToast (T 'common.cannotopen') 'Warn'
    }
}

function Invoke-WCM5Hash {
    # Tinh SHA-256 o nen roi: hien Show-WCInfo + copy clipboard; OpenVt = chi mo
    # link tra CUU hash tren VirusTotal, KHONG tai tep len
    param($State, $Finding, [bool]$OpenVt)
    $f = $Finding
    $p = [string](Get-WCProp $f 'Path')
    if ([string]::IsNullOrEmpty($p)) {
        Show-WCToast (T 'm5.filenotfound') 'Warn'
        return
    }
    $ok = Start-WCTask -Id 'm5.hash' -Title (T 'm5.hash.title') -Args @{ Path = $p; OpenVt = $OpenVt } -Worker {
        param($ctx, $s)
        if ($ctx.Cancelled()) { return $null }
        try {
            $h = Get-FileHash -LiteralPath ([string]$s['Path']) -Algorithm SHA256 -ErrorAction Stop
            return [PSCustomObject]@{
                Hash = [string](Get-WCProp $h 'Hash')
                Path = [string]$s['Path']
                OpenVt = ([bool]$s['OpenVt'])
            }
        } catch {
            return [PSCustomObject]@{ Error = $_.Exception.Message }
        }
    } -Done {
        param($r)
        if ($null -eq $r) { return }
        if (Get-WCProp $r 'Error') {
            Show-WCError (T 'm5.filenotfound') ([string](Get-WCProp $r 'Error'))
            return
        }
        $hash = [string](Get-WCProp $r 'Hash')
        Set-WCClipboard $hash
        if ((Get-WCProp $r 'OpenVt') -eq $true) {
            Show-WCToast (T 'm5.vt.opening') 'Info'
            try {
                Start-Process ('https://www.virustotal.com/gui/search/' + $hash)
            } catch {
                Show-WCToast (T 'common.cannotopen') 'Warn'
            }
        } else {
            Show-WCInfo -Title (T 'm5.hash.title') -Message (T 'm5.hash.msg' @($hash, [string](Get-WCProp $r 'Path')))
        }
    }.GetNewClosure()
    if (-not $ok) {
        Show-WCToast (T 'common.running' @((T 'm5.hash.title'))) 'Info'
    }
}

# ---------------------------------------------------------------------------
# PANEL CHINH
# ---------------------------------------------------------------------------
function New-WCM5Panel {
    param($State)
    $root = New-Object Windows.Controls.ScrollViewer
    $root.VerticalScrollBarVisibility = [Windows.Controls.ScrollBarVisibility]::Auto
    $hostPanel = New-WCVStack -Spacing 14
    $hostPanel.Margin = (New-Object Windows.Thickness(20))
    $root.Content = $hostPanel

    # Tieu de + chip "chua kiem chung runtime" (trung thuc — spec 1.6)
    $titleRow = New-WCHStack -Spacing 10
    $titleRow.Children.Add((New-WCHeading (T 'm5.title'))) | Out-Null
    $betaChip = New-WCChip -Text (T 'common.beta') -Kind 'Warn'
    $betaChip.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $titleRow.Children.Add($betaChip) | Out-Null
    $null = Add-WCChild $hostPanel $titleRow
    $null = Add-WCChild $hostPanel (New-WCSubtitle (T 'm5.subtitle'))

    # Su that ve tool (spec M5: su that phai the hien trong UI)
    $factSec = New-WCSection -Title (T 'm5.fact.title')
    $null = Add-WCChild $factSec.Body (New-WCTextBlock -Text (T 'm5.fact') -Size 12.5 -ColorKey 'WcSubtle' -Wrap)
    $null = Add-WCChild $hostPanel $factSec.Root

    # ---- Lop 1: trang thai bao ve ----
    $l1 = New-WCSection -Title (T 'm5.l1.title') -Subtitle (T 'm5.l1.subtitle')
    foreach ($src in (Get-WCM5L1Sources)) {
        $State['L1'][$src] = (New-WCM5L1Block -Parent $l1.Body -Title (T ('m5.l1.s.' + $src)))
    }
    $refreshBtn = New-WCButton -Text (T 'common.refresh') -OnClick {
        param($b)
        Invoke-WCM5RefreshStatus $State
    }.GetNewClosure()
    $null = Add-WCChild $l1.Body $refreshBtn
    $null = Add-WCChild $hostPanel $l1.Root

    # ---- Lop 2: quet Defender ----
    $l2 = New-WCSection -Title (T 'm5.l2.title') -Subtitle (T 'm5.l2.subtitle')
    $btnRow = New-WCHStack -Spacing 8
    $btnRow.Children.Add((New-WCButton -Text (T 'm5.l2.sig') -OnClick {
        param($b)
        Invoke-WCM5SignatureUpdate $State
    }.GetNewClosure())) | Out-Null
    $btnRow.Children.Add((New-WCButton -Text (T 'm5.l2.quick') -OnClick {
        param($b)
        Invoke-WCM5Scan $State 'Quick'
    }.GetNewClosure())) | Out-Null
    $btnRow.Children.Add((New-WCButton -Text (T 'm5.l2.full') -OnClick {
        param($b)
        Invoke-WCM5Scan $State 'Full'
    }.GetNewClosure())) | Out-Null
    $btnRow.Children.Add((New-WCButton -Text (T 'm5.l2.wdo') -Kind Danger -OnClick {
        param($b)
        Invoke-WCM5OfflineScan $State
    }.GetNewClosure())) | Out-Null
    $null = Add-WCChild $l2.Body $btnRow
    # Quet thu muc tuy chon: TextBox trong panel + nut quet (khong dung dialog)
    $folderRow = New-WCHStack -Spacing 8
    $folderLbl = New-WCTextBlock -Text (T 'm5.l2.folder.hint') -Size 12.5 -ColorKey 'WcSubtle'
    $folderLbl.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $null = Add-WCChild $folderRow $folderLbl
    $box = New-Object Windows.Controls.TextBox
    $box.Style = (Get-WCControlStyles)['WcInput']
    $box.Width = 300
    $null = Add-WCChild $folderRow $box
    $State['FolderBox'] = $box
    $null = Add-WCChild $folderRow (New-WCButton -Text (T 'm5.l2.custom') -OnClick {
        param($b)
        Invoke-WCM5Scan $State 'Custom'
    }.GetNewClosure())
    $null = Add-WCChild $l2.Body $folderRow
    # Trang thai quet (elapsed + ghi ro khong co % that)
    $l2Status = New-WCTextBlock -Text (T 'm5.l2.status.idle') -Size 12 -ColorKey 'WcSubtle' -Wrap
    $State['L2Status'] = $l2Status
    $null = Add-WCChild $l2.Body $l2Status
    $null = Add-WCChild $l2.Body (New-WCExpertLine -Command (T 'm5.expert.l2'))
    $null = Add-WCChild $hostPanel $l2.Root

    # Ket qua de doa
    $thr = New-WCSection -Title (T 'm5.threat.title') -Subtitle (T 'm5.threat.subtitle')
    $null = Add-WCChild $thr.Body (New-WCButton -Text (T 'm5.threat.refresh') -Small -OnClick {
        param($b)
        Invoke-WCM5LoadThreats $State
    }.GetNewClosure())
    $thrHost = New-WCVStack -Spacing 6
    $State['ThreatHost'] = $thrHost
    $null = Add-WCChild $thr.Body $thrHost
    $thr.Root.Visibility = [Windows.Visibility]::Collapsed
    $State['ThreatSection'] = $thr
    $null = Add-WCChild $hostPanel $thr.Root

    # ---- Lop 3: heuristic ----
    $l3 = New-WCSection -Title (T 'm5.l3.title') -Subtitle (T 'm5.l3.subtitle')
    $null = Add-WCChild $l3.Body (New-WCButton -Text (T 'm5.l3.scan') -Kind Primary -OnClick {
        param($b)
        Invoke-WCM5HeurScan $State
    }.GetNewClosure())
    $l3SummaryHost = New-WCHStack -Spacing 0
    $State['L3SummaryHost'] = $l3SummaryHost
    $null = Add-WCChild $l3.Body $l3SummaryHost
    $l3Spinner = New-WCSpinner -Text (T 'm5.l3.scanning')
    $l3Spinner.Visibility = [Windows.Visibility]::Collapsed
    $State['L3Spinner'] = $l3Spinner
    $null = Add-WCChild $l3.Body $l3Spinner
    $l3Host = New-WCVStack -Spacing 8
    $State['L3Host'] = $l3Host
    $null = Add-WCChild $l3.Body $l3Host
    $null = Add-WCChild $l3.Body (New-WCExpertLine -Command (T 'm5.expert.l3'))
    $null = Add-WCChild $hostPanel $l3.Root

    Set-WCM5SummaryChips $State -1 -1 -1
    return $root
}

function Invoke-WCM5OnShow {
    # Tai du lieu ve dan: 7 nguon Lop 1 chay nen rieng biet; de doa + heuristic
    # tai 1 lan dau
    param($State)
    foreach ($src in (Get-WCM5L1Sources)) {
        Start-WCM5StatusTask $State $src $false
    }
    if (-not $State['ThreatsLoaded']) { Invoke-WCM5LoadThreats $State }
    if (-not $State['HeurStarted']) {
        $State['HeurStarted'] = $true
        Invoke-WCM5HeurScan $State
    }
}

# ---------------------------------------------------------------------------
# KHOI TAO MODULE (buoc cuoi file — dang ky nav theo CONTRACT)
# ---------------------------------------------------------------------------
function Initialize-WCModuleM5 {
    $state = @{
        L1 = @{}
        L2Status = $null
        FolderBox = $null
        ThreatHost = $null
        ThreatSection = $null
        ThreatsLoaded = $false
        L3Host = $null
        L3Spinner = $null
        L3SummaryHost = $null
        HeurStarted = $false
    }
    Register-WCNavItem -Key 'm5' -Badge 'M5' -Title (T 'm5.title') -Order 60 -Builder {
        New-WCM5Panel $state
    }.GetNewClosure() -OnShow {
        Invoke-WCM5OnShow $state
    }.GetNewClosure()
}


# ============================================================================
# REGION: 17-M6-Health.ps1
# ============================================================================

# ============================================================================
#  src/17-M6-Health.ps1 - Module M6: KIEM TRA SUC KHOE MAY
#  Diem 0-100 KEM bang phan ra MINH BACH (nguoi dung thay diem den tu dau).
#  Trong so tham khao: Luu tru 25, On dinh 25, Toan ven 15, Bao mat 15,
#  Bo nho 10, Pin 10. Nhom khong doc duoc BI BO khoi mau so (chia lai trong so).
#  Tran: SMART hong / loi RAM / dia loi lap -> diem toi da 49.
#
#  FIXTURE (WINCARE_FIXTURE=file.json) - cac key module M6 dung de thay the:
#    health.physicaldisks : { Ok, Disks: [ { DeviceId, Name, Media, Health, OpStatus } ] }
#    health.reliability   : { Ok, Counters: [ { DeviceId, Temp, Wear, Hours, ReadErrors, ReadUncorr, WriteErrors } ] }
#    health.volumes       : { Ok, Volumes: [ { Letter, Size, Free, PctFree } ] }
#    health.events        : { Ok, SystemOk, AppOk,
#                             Cats: { kpower41, whea, bugcheck, diskerr, tdr, svc,
#                                     appcrash, wheamem, memdiagerr, memdiagok },
#                             BugCodes: [] }
#    health.dism          : { Ok, ExitCode }          (DISM /CheckHealth - CheckHealth)
#    health.sfc           : { Ok, ExitCode }          (SFC /verifyonly)
#    health.battery       : { Ok, HasBattery, Batteries: [ { Design, Full, Wear } ] }
#    health.mp            : { Mode: defender|thirdparty|unknown, AvName, RealTime,
#                             SigAgeDays, Engine, Tamper, LastQuick, LastFull }
#    (khi khong co fixture, health.mp goi lai nguon 'sec.mpstatus' cua M5 qua cache)
#
#  KHONG parse output text cua sfc/dism (chi ExitCode). Event log loc theo
#  ProviderName + Id (khong phu thuoc ngon ngu). Comment tieng Viet khong dau.
# ============================================================================

Register-WCStrings 'vi' @{
    'm6.title' = 'Kiểm tra sức khỏe máy'
    'm6.subtitle' = 'Điểm 0-100 kèm bảng phân rã minh bạch — bạn thấy rõ điểm đến từ đâu, không phóng đại, không đoán.'
    'm6.score' = 'Điểm sức khỏe'
    'm6.score.howto' = 'Cách tính: Lưu trữ 25% · Ổn định 25% · Toàn vẹn hệ thống 15% · Bảo mật 15% · Bộ nhớ 10% · Pin 10%. Nhóm không đo được bị BỎ khỏi mẫu số (trọng số chia lại cho các nhóm còn lại, không bị coi là điểm tối đa). Dấu hiệu nghiêm trọng (SMART hỏng, lỗi RAM, đĩa lỗi lặp lặp) → điểm bị trần 49.'
    'm6.score.nodata' = 'Chưa đủ dữ liệu để chấm điểm.'
    'm6.score.band.good' = 'Tốt — 75-100 điểm'
    'm6.score.band.mid' = 'Trung bình — 50-74 điểm'
    'm6.score.band.bad' = 'Kém — 0-49 điểm'
    'm6.score.cap' = 'Điểm bị giới hạn tối đa 49 vì dấu hiệu nghiêm trọng: {0}'
    'm6.score.renorm' = 'Bỏ qua (không có dữ liệu): {0} — trọng số còn lại được chia lại cho các nhóm đã đo.'
    'm6.scan.at' = 'Quét lúc {0}'
    'm6.scan.pending' = 'Đang quét ({0}/{1} nhóm có kết quả)…'
    'm6.scan.done' = 'Đã quét đủ 6 nhóm.'
    'm6.breakdown.title' = 'Bảng phân rã — điểm đến từ đâu'
    'm6.breakdown.sub' = 'Mỗi nhóm chấm 0-100 rồi nhân trọng số. Mỗi điểm trừ đều kèm lý do cụ thể bên cạnh.'
    'm6.col.group' = 'Nhóm'
    'm6.col.weight' = 'Trọng số'
    'm6.col.score' = 'Điểm'
    'm6.col.why' = 'Tại sao'
    'm6.col.what' = 'Nên làm gì'
    'm6.detail' = 'Chi tiết'
    'm6.action.detail' = 'Xem chi tiết'
    'm6.skipped' = 'Bỏ qua (không có dữ liệu)'
    'm6.why.nodata' = 'Không đủ dữ liệu — nhóm này bị bỏ khỏi công thức điểm, không bị tính là điểm xấu.'
    'm6.status.scanning' = 'Đang quét…'
    'm6.busy' = 'Đang có tác vụ của mục này chạy — chờ hoàn tất rồi thử lại.'
    'm6.rescan.busy' = 'Đang quét — chờ hoàn tất rồi bấm Quét lại.'
    'm6.on' = 'Bật'
    'm6.off' = 'Tắt'
    'm6.fmt.hours' = '{0} giờ'
    'm6.fmt.errs' = '{0} (chưa sửa được: {1})'
    'm6.fmt.mwh' = '{0} mWh'
    'm6.fact.cancelled' = 'Đã hủy quét nhóm này — chưa có số liệu.'
    # --- Nhom ---
    'm6.group.storage' = 'Lưu trữ'
    'm6.group.storage.tip' = 'Sức khỏe từng ổ (Get-PhysicalDisk), SMART (Get-StorageReliabilityCounter: nhiệt độ, hao mòn SSD, giờ bật, lỗi đọc/ghi) và dung lượng trống của từng volume.'
    'm6.group.stability' = 'Ổn định (30 ngày)'
    'm6.group.stability.tip' = 'Đọc nhật ký sự kiện 30 ngày theo nhà cung cấp + mã sự kiện (không phụ thuộc ngôn ngữ): BSOD, tắt đột ngột, lỗi phần cứng, lỗi đĩa, dịch vụ chết, ứng dụng treo.'
    'm6.group.integrity' = 'Toàn vẹn hệ thống'
    'm6.group.integrity.tip' = 'DISM /CheckHealth (nhanh) + SFC /verifyonly (chỉ kiểm tra, không sửa). Kết luận chỉ dựa trên mã thoát — không chắc thì ghi "Không kết luận được".'
    'm6.group.security' = 'Bảo mật'
    'm6.group.security.tip' = 'Trạng thái Microsoft Defender (bảo vệ thời gian thực, tuổi chữ ký) — dùng lại nguồn dữ liệu của mục M5, không quét trùng.'
    'm6.group.memory' = 'Bộ nhớ (RAM)'
    'm6.group.memory.tip' = 'Sự kiện lỗi bộ nhớ WHEA trong 30 ngày và kết quả Windows Memory Diagnostic (nếu chạy trong 30 ngày).'
    'm6.group.battery' = 'Pin'
    'm6.group.battery.tip' = 'Độ chai pin: so sánh dung lượng sạc đầy hiện tại với dung lượng thiết kế (root\wmi).'
    # --- Luu tru ---
    'm6.fact.storage.ok' = 'Cả {0} ổ đều Healthy, không có lỗi đọc/ghi đáng kể, dung lượng còn thoải mái.'
    'm6.fact.storage.diskwarn' = 'Ổ "{0}" đang ở trạng thái Warning (SMART cảnh báo).'
    'm6.fact.storage.diskbad' = 'Ổ "{0}" bị báo HỎNG/sắp hỏng — cần sao lưu dữ liệu ngay.'
    'm6.fact.storage.opstat' = 'Ổ "{0}" trạng thái vận hành: {1}.'
    'm6.fact.storage.temp.warn' = 'Ổ "{0}" nhiệt độ {1}°C — hơi cao.'
    'm6.fact.storage.temp.hot' = 'Ổ "{0}" đang nóng: {1}°C.'
    'm6.fact.storage.wear' = 'SSD "{0}" đã hao mòn {1}%.'
    'm6.fact.storage.readerr' = 'Ổ "{0}" ghi nhận {1} lỗi đọc tổng cộng ({2} lỗi không sửa được).'
    'm6.fact.storage.lowfree' = 'Ổ {0} chỉ còn {1}% dung lượng trống.'
    'm6.fact.storage.nosmart' = 'Không đọc được chỉ số SMART (ổ USB/bridge thường không có) — các cột SMART hiển thị N/A, không trừ điểm.'
    'm6.fact.storage.diskna' = 'Không đọc được trạng thái ổ đĩa (Get-PhysicalDisk) — chỉ đánh giá dung lượng trống.'
    'm6.fact.storage.nodata' = 'Không đọc được thông tin lưu trữ.'
    'm6.storage.what.ok' = 'Không cần làm gì — tiếp tục sao lưu định kỳ.'
    'm6.storage.what.warn' = 'Xem SMART chi tiết, sao lưu dữ liệu; nếu ổ đầy thì dọn đĩa (M2).'
    'm6.storage.what.bad' = 'SAO LƯU DỮ LIỆU NGAY và cân nhắc thay ổ (xem M2).'
    'm6.storage.col.disk' = 'Ổ'
    'm6.storage.col.media' = 'Loại'
    'm6.storage.col.health' = 'Sức khỏe'
    'm6.storage.col.temp' = 'Nhiệt độ'
    'm6.storage.col.wear' = 'Hao mòn'
    'm6.storage.col.hours' = 'Giờ bật'
    'm6.storage.col.readerr' = 'Lỗi đọc'
    'm6.storage.col.vol' = 'Ổ đĩa'
    'm6.storage.col.size' = 'Dung lượng'
    'm6.storage.col.free' = 'Còn trống'
    'm6.storage.col.pct' = '% trống'
    # --- On dinh ---
    'm6.fact.stab.ok' = 'Không có sự cố nghiêm trọng nào trong 30 ngày.'
    'm6.fact.stab.kpower41' = 'Tắt đột ngột / mất nguồn: {0} lần.'
    'm6.fact.stab.whea' = 'Lỗi phần cứng (WHEA): {0} lần.'
    'm6.fact.stab.bugcheck' = 'Màn hình xanh (BSOD): {0} lần (mã: {1}).'
    'm6.fact.stab.diskerr' = 'Lỗi đĩa (disk/Ntfs): {0} lần.'
    'm6.fact.stab.tdr' = 'Card đồ họa bị reset (TDR): {0} lần.'
    'm6.fact.stab.svc' = 'Dịch vụ Windows dừng đột ngột: {0} lần.'
    'm6.fact.stab.appcrash' = 'Ứng dụng bị lỗi/treo: {0} lần.'
    'm6.fact.stab.applog' = 'Nhật ký Application không đọc được — số liệu ứng dụng có thể thiếu, không trừ điểm vì thiếu dữ liệu.'
    'm6.fact.stab.nodata' = 'Không đủ dữ liệu (không đọc được nhật ký System) — không đoán.'
    'm6.stability.what.ok' = 'Không cần làm gì.'
    'm6.stability.what.warn' = 'Xem chi tiết từng loại sự cố bên dưới; lỗi lặp lại nên kiểm tra driver (M3) và phần cứng.'
    'm6.stab.none' = 'Không có sự cố nào được ghi nhận trong 30 ngày.'
    'm6.stab.kpower41.desc' = 'Máy tắt mà không qua quy trình tắt máy (mất điện, treo cứng, giữ nút nguồn).'
    'm6.stab.kpower41.fix' = 'Nếu lặp lại: kiểm tra nguồn/pin và nhiệt độ; lưu công việc thường xuyên.'
    'm6.stab.whea.desc' = 'Windows ghi nhận lỗi phần cứng đã sửa hoặc chưa sửa (CPU, RAM, bus…).'
    'm6.stab.whea.fix' = 'Lặp lại nhiều lần: chạy kiểm tra RAM (nhóm Bộ nhớ) và cập nhật BIOS/driver.'
    'm6.stab.bugcheck.desc' = 'Hệ thống dừng vì lỗi nghiêm trọng và tự khởi động lại.'
    'm6.stab.bugcheck.fix' = 'Ghi lại mã BugCheck, tìm driver/phần cứng liên quan; cập nhật driver ở M3.'
    'm6.stab.diskerr.desc' = 'Ổ lưu trữ hoặc hệ thống file báo lỗi đọc/ghi/lỗi cấu trúc.'
    'm6.stab.diskerr.fix' = 'Kiểm tra SMART ở nhóm Lưu trữ; sao lưu dữ liệu; chạy chkdsk nếu Windows gợi ý.'
    'm6.stab.tdr.desc' = 'Driver GPU bị treo và Windows đã reset nó (màn hình nháy đen/lag).'
    'm6.stab.tdr.fix' = 'Cập nhật driver GPU (M3); bỏ xung nếu đang overclock.'
    'm6.stab.svc.desc' = 'Dịch vụ hệ thống bị chết đột ngột (crash).'
    'm6.stab.svc.fix' = 'Nếu lặp lại: mở Trình xem sự kiện xem tên dịch vụ và tìm bản cập nhật.'
    'm6.stab.appcrash.desc' = 'Ứng dụng gặp lỗi nghiêm trọng hoặc bị treo.'
    'm6.stab.appcrash.fix' = 'Cập nhật/gỡ cài đặt ứng dụng liên quan — ảnh hưởng rất nhỏ đến điểm tổng thể.'
    # --- Toan ven ---
    'm6.fact.int.dism.ok' = 'DISM /CheckHealth: không phát hiện cờ hỏng (mã thoát 0).'
    'm6.fact.int.dism.unknown' = 'DISM /CheckHealth: không kết luận được (mã thoát {0}).'
    'm6.fact.int.dism.norun' = 'DISM /CheckHealth: không chạy được.'
    'm6.fact.int.sfc.ok' = 'SFC /verifyonly: không phát hiện lỗi file hệ thống (mã thoát 0).'
    'm6.fact.int.sfc.unknown' = 'SFC /verifyonly: không kết luận được (mã thoát {0}) — có thể có lỗi hệ thống.'
    'm6.fact.int.sfc.norun' = 'SFC /verifyonly: không chạy được.'
    'm6.integrity.what.ok' = 'Không cần làm gì.'
    'm6.integrity.what.warn' = 'Chạy "Kiểm tra sâu (DISM ScanHealth)" để chắc hơn — ước tính 5-15 phút.'
    'm6.integrity.p.dism' = 'Đang chạy DISM /CheckHealth (nhanh)…'
    'm6.integrity.p.sfc' = 'Đang chạy SFC /verifyonly (chỉ kiểm tra — có thể mất vài phút)…'
    'm6.integrity.dism.exit' = 'DISM /CheckHealth — mã thoát'
    'm6.integrity.sfc.exit' = 'SFC /verifyonly — mã thoát'
    'm6.integrity.deep.result' = 'Kiểm tra sâu gần nhất'
    'm6.integrity.deep' = 'Kiểm tra sâu (DISM ScanHealth)'
    'm6.integrity.deep.confirm.title' = 'Chạy kiểm tra sâu?'
    'm6.integrity.deep.confirm.msg' = 'DISM /Online /Cleanup-Image /ScanHealth — quét kỹ kho thành phần, ước tính 5-15 phút, chạy nền và HỦY ĐƯỢC. Chỉ quét, không sửa gì.'
    'm6.integrity.deep.running' = 'Đang quét sâu DISM ScanHealth (ước tính 5-15 phút)…'
    'm6.integrity.deep.done.ok' = 'Quét sâu hoàn tất: DISM không báo cờ hỏng (mã thoát 0).'
    'm6.integrity.deep.done.unknown' = 'Quét sâu xong nhưng không kết luận được (mã thoát {0}).'
    # --- Bao mat ---
    'm6.fact.sec.rtp.on' = 'Bảo vệ thời gian thực đang bật.'
    'm6.fact.sec.ok.sig' = 'Chữ ký Defender mới ({0} ngày).'
    'm6.fact.sec.sigold' = 'Chữ ký Defender đã {0} ngày tuổi — nên cập nhật.'
    'm6.fact.sec.sig.na' = 'Không đọc được tuổi chữ ký.'
    'm6.fact.sec.rtp.off' = 'Bảo vệ thời gian thực đang TẮT.'
    'm6.fact.sec.rtp.na' = 'Không đọc được trạng thái bảo vệ thời gian thực.'
    'm6.fact.sec.third' = 'Đang dùng antivirus bên thứ ba ({0}) — WinCare không chấm điểm thay họ.'
    'm6.fact.sec.nodata' = 'Không đọc được trạng thái bảo vệ.'
    'm6.security.what.ok' = 'Không cần làm gì.'
    'm6.security.what.rtp' = 'Bật lại bảo vệ thời gian thực trong Windows Security (xem mục Bảo mật M5).'
    'm6.security.what.sig' = 'Cập nhật chữ ký Defender (mục M5).'
    'm6.security.what.warn' = 'Kiểm tra lại trạng thái bảo vệ ở mục Bảo mật (M5).'
    'm6.security.rtp' = 'Bảo vệ thời gian thực'
    'm6.security.sigage' = 'Tuổi chữ ký'
    'm6.security.engine' = 'Phiên bản engine'
    'm6.security.tamper' = 'Chống giả mạo (Tamper Protection)'
    'm6.security.lastquick' = 'Quét nhanh gần nhất'
    'm6.security.lastfull' = 'Quét toàn bộ gần nhất'
    'm6.security.av' = 'Antivirus'
    # --- Bo nho ---
    'm6.fact.mem.ok' = 'Không thấy lỗi RAM nào trong nhật ký 30 ngày.'
    'm6.fact.mem.whea' = 'Có {0} sự kiện lỗi bộ nhớ (WHEA) trong 30 ngày.'
    'm6.fact.mem.diag' = 'Windows Memory Diagnostic phát hiện lỗi phần cứng bộ nhớ (trong 30 ngày).'
    'm6.fact.mem.diagok' = 'Lần chạy Windows Memory Diagnostic gần nhất (30 ngày): không phát hiện lỗi.'
    'm6.fact.mem.nodata' = 'Không đủ dữ liệu (không đọc được nhật ký System).'
    'm6.memory.what.ok' = 'Không cần làm gì.'
    'm6.memory.what.test' = 'Chạy Windows Memory Diagnostic để kiểm tra kỹ hơn (cần khởi động lại).'
    'm6.memory.run' = 'Chạy Windows Memory Diagnostic'
    'm6.memory.confirm.title' = 'Chạy Windows Memory Diagnostic?'
    'm6.memory.confirm.msg' = 'WinCare sẽ chỉ MỞ công cụ của Windows — công cụ này sẽ hỏi bạn khởi động lại NGAY hay vào lần tắt máy sau. WinCare không tự khởi động lại máy. Hãy lưu công việc trước.'
    'm6.memory.opened' = 'Đã mở Windows Memory Diagnostic.'
    'm6.memory.wheacount' = 'Sự kiện lỗi bộ nhớ (WHEA, 30 ngày)'
    'm6.memory.diagresult' = 'Windows Memory Diagnostic (30 ngày)'
    'm6.memory.diag.err' = 'Phát hiện lỗi phần cứng bộ nhớ'
    'm6.memory.diag.ok' = 'Không phát hiện lỗi'
    'm6.memory.diag.none' = 'Chưa chạy trong 30 ngày'
    # --- Pin ---
    'm6.fact.bat.ok' = 'Pin chai {0}% — trong ngưỡng bình thường.'
    'm6.fact.bat.wear' = 'Pin đã chai {0}% (sạc đầy {1}/{2} mWh so với thiết kế).'
    'm6.fact.bat.absent' = 'Máy không có pin — nhóm bị bỏ khỏi công thức điểm.'
    'm6.fact.bat.nodata' = 'Không đọc được dữ liệu pin (máy không có pin hoặc không đọc được) — nhóm bị bỏ.'
    'm6.fact.bat.nowear' = 'Không tính được độ chai (thiếu dung lượng thiết kế) — nhóm bị bỏ.'
    'm6.battery.what.ok' = 'Không cần làm gì.'
    'm6.battery.what.wear' = 'Giảm thói quen sạc kiệt 0% nếu cần dùng lâu; chai nặng thì thay pin.'
    'm6.battery.design' = 'Dung lượng thiết kế'
    'm6.battery.full' = 'Sạc đầy hiện tại'
    'm6.battery.wear' = 'Độ chai'
    # --- Sua loi (nang cao) ---
    'm6.repair.title' = 'Nâng cao — Sửa lỗi hệ thống'
    'm6.repair.subtitle' = 'Chỉ dùng khi kiểm tra phát hiện vấn đề. Có xác nhận, thử tạo điểm khôi phục trước, báo thời gian ước tính. Không hoàn tác tự động.'
    'm6.repair.dism' = 'Sửa kho thành phần (DISM RestoreHealth)'
    'm6.repair.dism.eta' = 'Ước tính 10-30 phút, có thể cần mạng.'
    'm6.repair.sfc' = 'Sửa file hệ thống (SFC /scannow)'
    'm6.repair.sfc.eta' = 'Ước tính 5-15 phút.'
    'm6.repair.confirm.title' = 'Xác nhận sửa lỗi hệ thống'
    'm6.repair.confirm.msg.dism' = "Sẽ chạy: DISM /Online /Cleanup-Image /RestoreHealth (ước tính 10-30 phút).`nNên để chạy hết — hủy giữa chừng có thể phải chạy lại từ đầu."
    'm6.repair.confirm.msg.sfc' = "Sẽ chạy: sfc.exe /scannow (ước tính 5-15 phút).`nNên để chạy hết — hủy giữa chừng có thể phải chạy lại từ đầu."
    'm6.repair.noundo' = 'File hệ thống/kho thành phần bị thay thế KHÔNG hoàn tác tự động được. WinCare sẽ thử tạo điểm khôi phục System Restore trước khi chạy.'
    'm6.repair.cp.running' = 'Đang thử tạo điểm khôi phục…'
    'm6.repair.cp.fail' = 'Không tạo được điểm khôi phục: {0}'
    'm6.repair.cp.ask.title' = 'Tiếp tục mà không có điểm khôi phục?'
    'm6.repair.cp.ask.msg' = 'System Restore có thể đang tắt trên máy này. Nếu tiếp tục, việc sửa lỗi sẽ KHÔNG có điểm khôi phục để quay lại.'
    'm6.repair.running' = 'Đang sửa lỗi hệ thống'
    'm6.repair.done.ok' = 'Sửa hoàn tất (mã thoát 0). Nên bấm "Quét lại" để xem điểm mới.'
    'm6.repair.done.unknown' = 'Chạy xong nhưng không kết luận được (mã thoát {0}) — xem chi tiết trong nhật ký.'
    'm6.repair.cancelled' = 'Đã hủy — có thể phải chạy lại từ đầu lần sau.'
    'm6.repair.journal.dism' = 'Sửa kho thành phần (DISM RestoreHealth)'
    'm6.repair.journal.sfc' = 'Sửa file hệ thống (SFC /scannow)'
}
Register-WCStrings 'en' @{
    'm6.title' = 'PC health check'
    'm6.subtitle' = 'A 0-100 score with a fully transparent breakdown — you see exactly where the score comes from. No hype, no guessing.'
    'm6.score' = 'Health score'
    'm6.score.howto' = 'How it is computed: Storage 25% · Stability 25% · System integrity 15% · Security 15% · Memory 10% · Battery 10%. Groups that cannot be read are REMOVED from the denominator (weights are re-split; never counted as full marks). Serious signs (failing SMART, RAM errors, repeated disk errors) cap the score at 49.'
    'm6.score.nodata' = 'Not enough data to compute a score yet.'
    'm6.score.band.good' = 'Good — 75-100'
    'm6.score.band.mid' = 'Fair — 50-74'
    'm6.score.band.bad' = 'Poor — 0-49'
    'm6.score.cap' = 'Score capped at 49 due to serious signs: {0}'
    'm6.score.renorm' = 'Skipped (no data): {0} — remaining weights are re-split across the measured groups.'
    'm6.scan.at' = 'Scanned at {0}'
    'm6.scan.pending' = 'Scanning ({0}/{1} groups reported)…'
    'm6.scan.done' = 'All 6 groups scanned.'
    'm6.breakdown.title' = 'Breakdown — where the score comes from'
    'm6.breakdown.sub' = 'Each group is scored 0-100 then weighted. Every deduction comes with its specific reason.'
    'm6.col.group' = 'Group'
    'm6.col.weight' = 'Weight'
    'm6.col.score' = 'Score'
    'm6.col.why' = 'Why'
    'm6.col.what' = 'What to do'
    'm6.detail' = 'Details'
    'm6.action.detail' = 'View details'
    'm6.skipped' = 'Skipped (no data)'
    'm6.why.nodata' = 'Not enough data — this group is removed from the score formula, not counted as bad.'
    'm6.status.scanning' = 'Scanning…'
    'm6.busy' = 'A task from this page is already running — wait for it to finish.'
    'm6.rescan.busy' = 'Still scanning — wait for it to finish, then rescan.'
    'm6.on' = 'On'
    'm6.off' = 'Off'
    'm6.fmt.hours' = '{0} hours'
    'm6.fmt.errs' = '{0} (uncorrected: {1})'
    'm6.fmt.mwh' = '{0} mWh'
    'm6.fact.cancelled' = 'Scan of this group was cancelled — no data yet.'
    'm6.group.storage' = 'Storage'
    'm6.group.storage.tip' = 'Per-disk health (Get-PhysicalDisk), SMART (Get-StorageReliabilityCounter: temperature, SSD wear, power-on hours, read/write errors) and free space per volume.'
    'm6.group.stability' = 'Stability (30 days)'
    'm6.group.stability.tip' = 'Reads the last 30 days of event logs by provider + event ID (language-independent): BSOD, unexpected shutdowns, hardware errors, disk errors, service crashes, app hangs.'
    'm6.group.integrity' = 'System integrity'
    'm6.group.integrity.tip' = 'DISM /CheckHealth (fast) + SFC /verifyonly (verify only, fixes nothing). Conclusions are based on exit codes only — "Inconclusive" when not sure.'
    'm6.group.security' = 'Security'
    'm6.group.security.tip' = 'Microsoft Defender status (real-time protection, signature age) — reuses the M5 data source, no duplicate scanning.'
    'm6.group.memory' = 'Memory (RAM)'
    'm6.group.memory.tip' = 'WHEA memory-error events in the last 30 days plus Windows Memory Diagnostic results if it ran within 30 days.'
    'm6.group.battery' = 'Battery'
    'm6.group.battery.tip' = 'Battery wear: current full-charge capacity vs design capacity (root\wmi).'
    'm6.fact.storage.ok' = 'All {0} disks are Healthy, no significant read/write errors, free space is comfortable.'
    'm6.fact.storage.diskwarn' = 'Disk "{0}" is in Warning state (SMART warning).'
    'm6.fact.storage.diskbad' = 'Disk "{0}" is reported FAILING/about to fail — back up your data now.'
    'm6.fact.storage.opstat' = 'Disk "{0}" operational status: {1}.'
    'm6.fact.storage.temp.warn' = 'Disk "{0}" temperature {1}°C — a bit high.'
    'm6.fact.storage.temp.hot' = 'Disk "{0}" is hot: {1}°C.'
    'm6.fact.storage.wear' = 'SSD "{0}" wear level: {1}%.'
    'm6.fact.storage.readerr' = 'Disk "{0}" recorded {1} total read errors ({2} uncorrected).'
    'm6.fact.storage.lowfree' = 'Volume {0} has only {1}% free space.'
    'm6.fact.storage.nosmart' = 'SMART counters unavailable (USB/bridge disks usually lack them) — SMART columns show N/A, no deduction.'
    'm6.fact.storage.diskna' = 'Disk health status unavailable (Get-PhysicalDisk failed) — only free space was evaluated.'
    'm6.fact.storage.nodata' = 'Storage information could not be read.'
    'm6.storage.what.ok' = 'Nothing to do — keep regular backups.'
    'm6.storage.what.warn' = 'Check SMART details, back up data; clean the disk if it is full (M2).'
    'm6.storage.what.bad' = 'BACK UP YOUR DATA NOW and consider replacing the disk (see M2).'
    'm6.storage.col.disk' = 'Disk'
    'm6.storage.col.media' = 'Type'
    'm6.storage.col.health' = 'Health'
    'm6.storage.col.temp' = 'Temp'
    'm6.storage.col.wear' = 'Wear'
    'm6.storage.col.hours' = 'Power-on'
    'm6.storage.col.readerr' = 'Read errors'
    'm6.storage.col.vol' = 'Volume'
    'm6.storage.col.size' = 'Size'
    'm6.storage.col.free' = 'Free'
    'm6.storage.col.pct' = '% free'
    'm6.fact.stab.ok' = 'No serious incidents in the last 30 days.'
    'm6.fact.stab.kpower41' = 'Unexpected shutdown / power loss: {0} times.'
    'm6.fact.stab.whea' = 'Hardware errors (WHEA): {0} times.'
    'm6.fact.stab.bugcheck' = 'Blue screen (BSOD): {0} times (codes: {1}).'
    'm6.fact.stab.diskerr' = 'Disk errors (disk/Ntfs): {0} times.'
    'm6.fact.stab.tdr' = 'GPU driver reset (TDR): {0} times.'
    'm6.fact.stab.svc' = 'Windows services terminated unexpectedly: {0} times.'
    'm6.fact.stab.appcrash' = 'Applications crashed/hung: {0} times.'
    'm6.fact.stab.applog' = 'Application log unreadable — app statistics may be incomplete; no deduction for missing data.'
    'm6.fact.stab.nodata' = 'Not enough data (System log unreadable) — no guessing.'
    'm6.stability.what.ok' = 'Nothing to do.'
    'm6.stability.what.warn' = 'Review each incident type below; repeated errors deserve a driver (M3) and hardware check.'
    'm6.stab.none' = 'No incidents recorded in the last 30 days.'
    'm6.stab.kpower41.desc' = 'The PC turned off without going through the shutdown flow (power loss, hard freeze, holding the power button).'
    'm6.stab.kpower41.fix' = 'If repeated: check PSU/battery and temperatures; save your work often.'
    'm6.stab.whea.desc' = 'Windows logged corrected or uncorrected hardware errors (CPU, RAM, bus…).'
    'm6.stab.whea.fix' = 'If repeated: run the memory test (Memory group) and update BIOS/drivers.'
    'm6.stab.bugcheck.desc' = 'The system halted due to a serious error and restarted itself.'
    'm6.stab.bugcheck.fix' = 'Note the BugCheck code, look up the related driver/hardware; update drivers in M3.'
    'm6.stab.diskerr.desc' = 'A storage device or the file system reported read/write/structure errors.'
    'm6.stab.diskerr.fix' = 'Check SMART in the Storage group; back up data; run chkdsk if Windows suggests it.'
    'm6.stab.tdr.desc' = 'The GPU driver hung and Windows reset it (screen flickers black/stutters).'
    'm6.stab.tdr.fix' = 'Update the GPU driver (M3); remove overclocks if any.'
    'm6.stab.svc.desc' = 'A Windows service crashed unexpectedly.'
    'm6.stab.svc.fix' = 'If repeated: open Event Viewer for the service name and look for updates.'
    'm6.stab.appcrash.desc' = 'An application hit a critical error or hung.'
    'm6.stab.appcrash.fix' = 'Update/uninstall the affected app — very small impact on the overall score.'
    'm6.fact.int.dism.ok' = 'DISM /CheckHealth: no corruption flag (exit code 0).'
    'm6.fact.int.dism.unknown' = 'DISM /CheckHealth: inconclusive (exit code {0}).'
    'm6.fact.int.dism.norun' = 'DISM /CheckHealth: could not run.'
    'm6.fact.int.sfc.ok' = 'SFC /verifyonly: no system file problems found (exit code 0).'
    'm6.fact.int.sfc.unknown' = 'SFC /verifyonly: inconclusive (exit code {0}) — system errors are possible.'
    'm6.fact.int.sfc.norun' = 'SFC /verifyonly: could not run.'
    'm6.integrity.what.ok' = 'Nothing to do.'
    'm6.integrity.what.warn' = 'Run "Deep check (DISM ScanHealth)" to be surer — takes 5-15 minutes.'
    'm6.integrity.p.dism' = 'Running DISM /CheckHealth (fast)…'
    'm6.integrity.p.sfc' = 'Running SFC /verifyonly (verify only — may take several minutes)…'
    'm6.integrity.dism.exit' = 'DISM /CheckHealth — exit code'
    'm6.integrity.sfc.exit' = 'SFC /verifyonly — exit code'
    'm6.integrity.deep.result' = 'Last deep check'
    'm6.integrity.deep' = 'Deep check (DISM ScanHealth)'
    'm6.integrity.deep.confirm.title' = 'Run deep check?'
    'm6.integrity.deep.confirm.msg' = 'DISM /Online /Cleanup-Image /ScanHealth — thorough component-store scan, estimated 5-15 minutes, runs in background and is CANCELLABLE. Scan only, changes nothing.'
    'm6.integrity.deep.running' = 'Running DISM ScanHealth deep check (estimated 5-15 minutes)…'
    'm6.integrity.deep.done.ok' = 'Deep check finished: DISM reported no corruption flag (exit code 0).'
    'm6.integrity.deep.done.unknown' = 'Deep check finished but inconclusive (exit code {0}).'
    'm6.fact.sec.rtp.on' = 'Real-time protection is on.'
    'm6.fact.sec.ok.sig' = 'Defender signatures are fresh ({0} days).'
    'm6.fact.sec.sigold' = 'Defender signatures are {0} days old — should update.'
    'm6.fact.sec.sig.na' = 'Signature age could not be read.'
    'm6.fact.sec.rtp.off' = 'Real-time protection is OFF.'
    'm6.fact.sec.rtp.na' = 'Real-time protection status could not be read.'
    'm6.fact.sec.third' = 'A third-party antivirus ({0}) is in use — WinCare does not grade it on their behalf.'
    'm6.fact.sec.nodata' = 'Protection status could not be read.'
    'm6.security.what.ok' = 'Nothing to do.'
    'm6.security.what.rtp' = 'Turn real-time protection back on in Windows Security (see M5).'
    'm6.security.what.sig' = 'Update Defender signatures (M5).'
    'm6.security.what.warn' = 'Re-check protection status in the Security page (M5).'
    'm6.security.rtp' = 'Real-time protection'
    'm6.security.sigage' = 'Signature age'
    'm6.security.engine' = 'Engine version'
    'm6.security.tamper' = 'Tamper Protection'
    'm6.security.lastquick' = 'Last quick scan'
    'm6.security.lastfull' = 'Last full scan'
    'm6.security.av' = 'Antivirus'
    'm6.fact.mem.ok' = 'No RAM errors seen in the last 30 days of logs.'
    'm6.fact.mem.whea' = '{0} memory-error (WHEA) events in the last 30 days.'
    'm6.fact.mem.diag' = 'Windows Memory Diagnostic detected a memory hardware problem (within 30 days).'
    'm6.fact.mem.diagok' = 'Latest Windows Memory Diagnostic run (30 days): no errors detected.'
    'm6.fact.mem.nodata' = 'Not enough data (System log unreadable).'
    'm6.memory.what.ok' = 'Nothing to do.'
    'm6.memory.what.test' = 'Run Windows Memory Diagnostic for a deeper check (requires a restart).'
    'm6.memory.run' = 'Run Windows Memory Diagnostic'
    'm6.memory.confirm.title' = 'Run Windows Memory Diagnostic?'
    'm6.memory.confirm.msg' = 'WinCare will only OPEN the Windows tool — that tool asks you whether to restart NOW or on the next shutdown. WinCare never restarts the PC itself. Save your work first.'
    'm6.memory.opened' = 'Windows Memory Diagnostic opened.'
    'm6.memory.wheacount' = 'Memory-error events (WHEA, 30 days)'
    'm6.memory.diagresult' = 'Windows Memory Diagnostic (30 days)'
    'm6.memory.diag.err' = 'Memory hardware problem detected'
    'm6.memory.diag.ok' = 'No errors detected'
    'm6.memory.diag.none' = 'Not run within 30 days'
    'm6.fact.bat.ok' = 'Battery wear {0}% — within the normal range.'
    'm6.fact.bat.wear' = 'Battery wear is {0}% (full charge {1}/{2} mWh vs design).'
    'm6.fact.bat.absent' = 'This PC has no battery — the group is removed from the score formula.'
    'm6.fact.bat.nodata' = 'Battery data unreadable (no battery or read failed) — group removed.'
    'm6.fact.bat.nowear' = 'Wear could not be computed (missing design capacity) — group removed.'
    'm6.battery.what.ok' = 'Nothing to do.'
    'm6.battery.what.wear' = 'Avoid full 0% discharges if you need long runtime; replace the battery if wear is heavy.'
    'm6.battery.design' = 'Design capacity'
    'm6.battery.full' = 'Current full charge'
    'm6.battery.wear' = 'Wear'
    'm6.repair.title' = 'Advanced — Repair system files'
    'm6.repair.subtitle' = 'Only use when a check found problems. Requires confirmation, tries a restore point first, shows time estimates. Not auto-undoable.'
    'm6.repair.dism' = 'Repair component store (DISM RestoreHealth)'
    'm6.repair.dism.eta' = 'Estimated 10-30 minutes, may need network.'
    'm6.repair.sfc' = 'Repair system files (SFC /scannow)'
    'm6.repair.sfc.eta' = 'Estimated 5-15 minutes.'
    'm6.repair.confirm.title' = 'Confirm system repair'
    'm6.repair.confirm.msg.dism' = "Will run: DISM /Online /Cleanup-Image /RestoreHealth (estimated 10-30 minutes).`nBest to let it finish — cancelling mid-way may require starting over."
    'm6.repair.confirm.msg.sfc' = "Will run: sfc.exe /scannow (estimated 5-15 minutes).`nBest to let it finish — cancelling mid-way may require starting over."
    'm6.repair.noundo' = 'Replaced system files/component store CANNOT be auto-undone. WinCare will try to create a System Restore point before running.'
    'm6.repair.cp.running' = 'Trying to create a restore point…'
    'm6.repair.cp.fail' = 'Could not create a restore point: {0}'
    'm6.repair.cp.ask.title' = 'Continue without a restore point?'
    'm6.repair.cp.ask.msg' = 'System Restore may be disabled on this PC. If you continue, the repair will have NO restore point to roll back to.'
    'm6.repair.running' = 'Repairing system files'
    'm6.repair.done.ok' = 'Repair finished (exit code 0). Press "Rescan" to refresh the score.'
    'm6.repair.done.unknown' = 'Finished but inconclusive (exit code {0}) — see the log for details.'
    'm6.repair.cancelled' = 'Cancelled — you may need to start over next time.'
    'm6.repair.journal.dism' = 'Repair component store (DISM RestoreHealth)'
    'm6.repair.journal.sfc' = 'Repair system files (SFC /scannow)'
}

# ---------------------------------------------------------------------------
# LOP DU LIEU (query qua Invoke-WCQuery - key 'health.*' de FIXTURE thay the)
# ---------------------------------------------------------------------------
function Get-WCM6Field {
    # Doc truong an toan tu hashtable hoac PSCustomObject (unit test truyen duoc ca 2)
    param($Obj, [Parameter(Mandatory)][string]$Name)
    if ($null -eq $Obj) { return $null }
    try {
        if ($Obj -is [System.Collections.IDictionary]) {
            if ($Obj.Contains($Name)) { return $Obj[$Name] }
            return $null
        }
    } catch { }
    return (Get-WCProp $Obj $Name)
}

function Get-WCM6GroupKeys {
    # Thu tu hien thi cac nhom (cung la thu tu trong bang phan ra)
    return @('Storage', 'Stability', 'Integrity', 'Security', 'Memory', 'Battery')
}

function Get-WCM6GroupLabel {
    param([Parameter(Mandatory)][string]$Key)
    $map = @{ Storage = 'storage'; Stability = 'stability'; Integrity = 'integrity'; Security = 'security'; Memory = 'memory'; Battery = 'battery' }
    $k = $map[$Key]
    if (-not $k) { return $Key }
    return (T ('m6.group.' + $k))
}

function Get-WCM6PhysicalDisksData {
    # Get-PhysicalDisk: HealthStatus/OperationalStatus (SMART tinh o query rieng)
    param([bool]$NoCache = $false)
    $r = Invoke-WCQuery -Key 'health.physicaldisks' -CacheTtlSec 300 -NoCache:$NoCache -Script {
        $o = @{ Ok = $false; Disks = @() }
        try {
            $disks = @(Get-PhysicalDisk -ErrorAction Stop)
            $o['Ok'] = $true
            foreach ($d in $disks) {
                $o['Disks'] += [PSCustomObject]@{
                    DeviceId = [string](Get-WCProp $d 'DeviceId')
                    Name     = [string](Get-WCProp $d 'FriendlyName')
                    Media    = [string](Get-WCProp $d 'MediaType')
                    Health   = [string](Get-WCProp $d 'HealthStatus')
                    OpStatus = [string](Get-WCProp $d 'OperationalStatus')
                }
            }
        } catch { }
        return [PSCustomObject]$o
    }
    if ($r.Status -eq 'Ok') { return $r.Data }
    return $null
}

function Get-WCM6ReliabilityData {
    # Get-StorageReliabilityCounter cho tung dia: nhiet do, hao mon, gio bat, loi doc/ghi
    param([bool]$NoCache = $false)
    $r = Invoke-WCQuery -Key 'health.reliability' -CacheTtlSec 300 -NoCache:$NoCache -Script {
        $o = @{ Ok = $false; Counters = @() }
        try {
            $disks = @(Get-PhysicalDisk -ErrorAction Stop)
            $o['Ok'] = $true
            foreach ($d in $disks) {
                $rec = @{
                    DeviceId = [string](Get-WCProp $d 'DeviceId')
                    Temp = $null; Wear = $null; Hours = $null
                    ReadErrors = $null; ReadUncorr = $null; WriteErrors = $null
                }
                try {
                    $c = $d | Get-StorageReliabilityCounter -ErrorAction Stop
                    if ($c) {
                        $rec['Temp']        = (Get-WCProp $c 'Temperature')
                        $rec['Wear']        = (Get-WCProp $c 'Wear')
                        $rec['Hours']       = (Get-WCProp $c 'PowerOnHours')
                        $rec['ReadErrors']  = (Get-WCProp $c 'ReadErrorsTotal')
                        $rec['ReadUncorr']  = (Get-WCProp $c 'ReadErrorsUncorrected')
                        $rec['WriteErrors'] = (Get-WCProp $c 'WriteErrorsTotal')
                    }
                } catch { }
                $o['Counters'] += [PSCustomObject]$rec
            }
        } catch { }
        return [PSCustomObject]$o
    }
    if ($r.Status -eq 'Ok') { return $r.Data }
    return $null
}

function Get-WCM6VolumesData {
    # Win32_LogicalDisk (DriveType=3): dung luong tung volume
    param([bool]$NoCache = $false)
    $r = Invoke-WCQuery -Key 'health.volumes' -CacheTtlSec 300 -NoCache:$NoCache -Script {
        $o = @{ Ok = $false; Volumes = @() }
        try {
            $vols = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3' -Property DeviceID,Size,FreeSpace -OperationTimeoutSec 10 -ErrorAction Stop)
            $o['Ok'] = $true
            foreach ($v in $vols) {
                $size = Get-WCProp $v 'Size'
                $free = Get-WCProp $v 'FreeSpace'
                if (($null -eq $size) -or ([double]$size -le 0)) { continue }
                $pct = [math]::Round(([double]$free / [double]$size) * 100, 1)
                $o['Volumes'] += [PSCustomObject]@{
                    Letter  = [string](Get-WCProp $v 'DeviceID')
                    Size    = [double]$size
                    Free    = [double]$free
                    PctFree = $pct
                }
            }
        } catch { }
        return [PSCustomObject]$o
    }
    if ($r.Status -eq 'Ok') { return $r.Data }
    return $null
}

function Get-WCM6EventsData {
    # Nhat ky System + Application 30 ngay, LOC THEO ProviderName + Id (khong phu
    # thuoc ngon ngu). Log bi tat/loi -> coi nhu khong du du lieu, khong doan.
    param([bool]$NoCache = $false)
    $r = Invoke-WCQuery -Key 'health.events' -CacheTtlSec 300 -NoCache:$NoCache -Script {
        $start = (Get-Date).AddDays(-30)
        $cats = @{
            kpower41 = 0; whea = 0; bugcheck = 0; diskerr = 0; tdr = 0; svc = 0
            appcrash = 0; wheamem = 0; memdiagerr = 0; memdiagok = 0
        }
        $bugcodes = @{}
        $specs = @(
            @{ Log = 'System'; Providers = @(
                'Microsoft-Windows-Kernel-Power', 'Microsoft-Windows-WHEA-Logger',
                'Microsoft-Windows-WER-SystemErrorReporting', 'disk', 'Ntfs',
                'Microsoft-Windows-Ntfs', 'Display', 'Microsoft-Windows-Display',
                'Service Control Manager') },
            @{ Log = 'Application'; Providers = @(
                'Application Error', 'Application Hang', 'Microsoft-Windows-MemoryDiagnostics-Results') }
        )
        $sysOk = $false
        $appOk = $false
        foreach ($spec in $specs) {
            $events = @()
            $readable = $false
            try {
                $events = @(Get-WinEvent -FilterHashtable @{ LogName = $spec['Log']; ProviderName = $spec['Providers']; StartTime = $start } -ErrorAction Stop)
                $readable = $true
            } catch {
                # FullyQualifiedErrorId khong bi dia phuong hoa: phan biet "khong co
                # su kiện nao" (may on dinh - tot) voi "log loi/bi tat" (thieu du lieu)
                if ($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound*') {
                    $readable = $true
                } else {
                    # Mot so provider co the khong ton tai tren may nay -> thu lai
                    # khong loc provider (van loc theo thoi gian), sau do loc bang tay
                    try {
                        $events = @(Get-WinEvent -FilterHashtable @{ LogName = $spec['Log']; StartTime = $start } -ErrorAction Stop)
                        $readable = $true
                    } catch {
                        if ($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound*') { $readable = $true }
                    }
                }
            }
            if ($spec['Log'] -eq 'System') { $sysOk = $readable } else { $appOk = $readable }
            if (-not $readable) { continue }
            foreach ($e in @($events)) {
                $prov = [string](Get-WCProp $e 'ProviderName')
                $idObj = Get-WCProp $e 'Id'
                if ($null -eq $idObj) { continue }
                $id = [int]$idObj
                if (($prov -eq 'Microsoft-Windows-Kernel-Power') -and ($id -eq 41)) { $cats['kpower41']++ }
                elseif ($prov -like '*WHEA-Logger*') {
                    $cats['whea']++
                    if (($id -eq 18) -or ($id -eq 19) -or ($id -eq 20) -or ($id -eq 46) -or ($id -eq 47)) { $cats['wheamem']++ }
                }
                elseif (($prov -like '*WER-SystemErrorReporting*') -and ($id -eq 1001)) {
                    $cats['bugcheck']++
                    try {
                        $props = $e.Properties
                        if ($props -and ($props.Count -gt 0)) {
                            $code = [string]$props[0].Value
                            if ($code) { $bugcodes[$code.Trim()] = $true }
                        }
                    } catch { }
                }
                elseif ((($prov -eq 'disk') -and (($id -eq 7) -or ($id -eq 11) -or ($id -eq 51) -or ($id -eq 153))) -or
                        (($prov -like '*Ntfs*') -and ($id -eq 55))) { $cats['diskerr']++ }
                elseif ((($prov -eq 'Display') -or ($prov -like '*-Display')) -and ($id -eq 4101)) { $cats['tdr']++ }
                elseif (($prov -eq 'Service Control Manager') -and (($id -eq 7031) -or ($id -eq 7034))) { $cats['svc']++ }
                elseif (($prov -eq 'Application Error') -and ($id -eq 1000)) { $cats['appcrash']++ }
                elseif (($prov -eq 'Application Hang') -and ($id -eq 1002)) { $cats['appcrash']++ }
                elseif (($prov -like '*MemoryDiagnostics-Results*') -and ($id -eq 1101)) { $cats['memdiagerr']++ }
                elseif (($prov -like '*MemoryDiagnostics-Results*') -and ($id -eq 1102)) { $cats['memdiagok']++ }
            }
        }
        $codeList = @($bugcodes.Keys | Sort-Object)
        if ($codeList.Count -gt 3) { $codeList = @($codeList[0], $codeList[1], $codeList[2]) }
        return [PSCustomObject]@{
            Ok = ($sysOk -or $appOk)
            SystemOk = $sysOk
            AppOk = $appOk
            Cats = $cats
            BugCodes = $codeList
        }
    }
    if ($r.Status -eq 'Ok') { return $r.Data }
    return $null
}

function Get-WCM6DismCheckData {
    # DISM /CheckHealth (nhanh) - chi lay ExitCode, KHONG parse stdout
    param([bool]$NoCache = $false)
    $r = Invoke-WCQuery -Key 'health.dism' -CacheTtlSec 600 -NoCache:$NoCache -Script {
        try {
            $p = Start-Process -FilePath 'dism.exe' -ArgumentList '/Online', '/Cleanup-Image', '/CheckHealth' -WindowStyle Hidden -Wait -PassThru -ErrorAction Stop
            return [PSCustomObject]@{ Ok = $true; ExitCode = $p.ExitCode }
        } catch {
            return [PSCustomObject]@{ Ok = $false; ExitCode = $null }
        }
    }
    if ($r.Status -eq 'Ok') { return $r.Data }
    return $null
}

function Get-WCM6SfcVerifyData {
    # SFC /verifyonly (CHI KIEM TRA, khong sua) - chi lay ExitCode.
    # ExitCode 0 = khong phat hien loi; khac 0 = co loi HOAC khong ket luan duoc.
    param([bool]$NoCache = $false)
    $r = Invoke-WCQuery -Key 'health.sfc' -CacheTtlSec 600 -NoCache:$NoCache -Script {
        try {
            $p = Start-Process -FilePath 'sfc.exe' -ArgumentList '/verifyonly' -WindowStyle Hidden -Wait -PassThru -ErrorAction Stop
            return [PSCustomObject]@{ Ok = $true; ExitCode = $p.ExitCode }
        } catch {
            return [PSCustomObject]@{ Ok = $false; ExitCode = $null }
        }
    }
    if ($r.Status -eq 'Ok') { return $r.Data }
    return $null
}

function Get-WCM6BatteryData {
    # root\wmi BatteryStaticData / BatteryFullChargedCapacity -> do chai
    param([bool]$NoCache = $false)
    $r = Invoke-WCQuery -Key 'health.battery' -CacheTtlSec 300 -NoCache:$NoCache -Script {
        $o = @{ Ok = $false; HasBattery = $false; Batteries = @() }
        try {
            $statics = @(Get-CimInstance -Namespace 'root\wmi' -ClassName 'BatteryStaticData' -OperationTimeoutSec 10 -ErrorAction Stop)
            $fulls = @(Get-CimInstance -Namespace 'root\wmi' -ClassName 'BatteryFullChargedCapacity' -OperationTimeoutSec 10 -ErrorAction Stop)
            $o['Ok'] = $true
            if ($statics.Count -gt 0) {
                $o['HasBattery'] = $true
                foreach ($s in $statics) {
                    $design = Get-WCProp $s 'DesignedCapacity'
                    $inst = [string](Get-WCProp $s 'InstanceName')
                    $full = $null
                    foreach ($f in $fulls) {
                        if ([string](Get-WCProp $f 'InstanceName') -eq $inst) { $full = Get-WCProp $f 'FullChargedCapacity'; break }
                    }
                    if (($null -eq $full) -and ($fulls.Count -gt 0)) { $full = Get-WCProp $fulls[0] 'FullChargedCapacity' }
                    $wear = $null
                    if (($null -ne $design) -and ($null -ne $full) -and ([double]$design -gt 0)) {
                        $wear = [math]::Round(100 - (([double]$full / [double]$design) * 100), 1)
                    }
                    $o['Batteries'] += [PSCustomObject]@{
                        Design = [double]$design
                        Full   = [double]$full
                        Wear   = $wear
                    }
                }
            }
        } catch { }
        return [PSCustomObject]$o
    }
    if ($r.Status -eq 'Ok') { return $r.Data }
    return $null
}

function Get-WCM6MpData {
    # Dung lai nguon cua M5 (key 'sec.mpstatus' - Invoke-WCQuery co cache, khong
    # tao truy van trung). Chuan hoa thanh trang thai bao mat cho M6.
    param([bool]$NoCache = $false)
    $r = Invoke-WCQuery -Key 'health.mp' -CacheTtlSec 120 -NoCache:$NoCache -Script {
        # Goi dung key 'sec.mpstatus' nhu M5 (Invoke-WCM5SourceQuery) de DUNG CHUNG
        # cache: script + TTL giong het M5, khong tao ban cache lech mau du lieu.
        $st = $null
        try {
            $r2 = Invoke-WCQuery -Key 'sec.mpstatus' -CacheTtlSec 60 -NoCache:$NoCache -Script { Get-MpComputerStatus -ErrorAction Stop }
            if (($r2.Status -eq 'Ok') -and $r2.Data) { $st = $r2.Data }
        } catch { }
        $rt = $null; $sigAge = $null; $eng = ''; $tamper = $null
        $lastQuick = $null; $lastFull = $null; $avEnabled = $null; $running = ''
        if ($st) {
            $rt = Get-WCProp $st 'RealTimeProtectionEnabled'
            $sigAge = Get-WCProp $st 'AntivirusSignatureAge'
            $eng = [string](Get-WCProp $st 'AMEngineVersion')
            $tamper = Get-WCProp $st 'IsTamperProtected'
            $lastQuick = Get-WCProp $st 'QuickScanEndTime'
            $lastFull = Get-WCProp $st 'FullScanEndTime'
            $avEnabled = Get-WCProp $st 'AntivirusEnabled'
            $running = [string](Get-WCProp $st 'AMRunningMode')
        }
        # AV ben thu ba: chi xem ten trong SecurityCenter2, khong giai ma productState
        $thirdNames = @()
        $avsReadable = $false
        try {
            $avs = @(Get-CimInstance -Namespace 'root/SecurityCenter2' -ClassName 'AntiVirusProduct' -OperationTimeoutSec 8 -ErrorAction Stop)
            $avsReadable = $true
            foreach ($av in $avs) {
                $pn = [string](Get-WCProp $av 'displayName')
                if ($pn -and ($pn -notlike '*Defender*')) { $thirdNames += $pn }
            }
        } catch { }
        $mode = 'unknown'
        $avName = ''
        if ($st -and (($null -ne $rt) -or ($null -ne $avEnabled))) {
            $mode = 'defender'
            # Defender o che do passive + co AV thu ba -> khong cham diem thay ho
            $passive = (($running -eq 'Passive Mode') -or ($avEnabled -eq $false))
            if ($passive -and ($thirdNames.Count -gt 0)) {
                $mode = 'thirdparty'
                $avName = [string]::Join(', ', $thirdNames)
            }
        } elseif ($thirdNames.Count -gt 0) {
            $mode = 'thirdparty'
            $avName = [string]::Join(', ', $thirdNames)
        }
        return [PSCustomObject]@{
            Mode = $mode
            AvName = $avName
            RealTime = $rt
            SigAgeDays = $sigAge
            Engine = $eng
            Tamper = $tamper
            LastQuick = $lastQuick
            LastFull = $lastFull
            ThirdParty = ($thirdNames.Count -gt 0)
        }
    }
    if ($r.Status -eq 'Ok') { return $r.Data }
    return $null
}

# ---------------------------------------------------------------------------
# HAM THUAN (unit test duoc): gop du lieu + cham diem tung nhom + cong thuc tong
# KHONG goi T, KHONG dung UI, KHONG truy van he thong.
# ---------------------------------------------------------------------------
function Merge-WCHealthStorage {
    # Gop 3 nguon (physicaldisks / reliability / volumes) thanh 1 du lieu chuan
    param($DisksResult, $ReliabilityResult, $VolumesResult)
    $out = @{ DisksOk = $false; VolumesOk = $false; Disks = @(); Volumes = @() }
    $rawDisks = @()
    if ($DisksResult) {
        $out['DisksOk'] = [bool](Get-WCM6Field $DisksResult 'Ok')
        $dd = Get-WCM6Field $DisksResult 'Disks'
        if ($null -ne $dd) { $rawDisks = @($dd) }
    }
    $counters = @()
    if ($ReliabilityResult) {
        $cc = Get-WCM6Field $ReliabilityResult 'Counters'
        if ($null -ne $cc) { $counters = @($cc) }
    }
    $i = 0
    foreach ($d in $rawDisks) {
        $devId = [string](Get-WCM6Field $d 'DeviceId')
        $ctr = $null
        foreach ($c in $counters) {
            if ([string](Get-WCM6Field $c 'DeviceId') -eq $devId) { $ctr = $c; break }
        }
        if ($null -eq $ctr) {
            # DeviceId khong khop (mot so o USB/RAID) -> gan theo thu tu, phong thu
            if ($counters.Count -eq 1) { $ctr = $counters[0] }
            elseif ($i -lt $counters.Count) { $ctr = $counters[$i] }
        }
        $rec = @{
            DeviceId = $devId
            Name = [string](Get-WCM6Field $d 'Name')
            Media = [string](Get-WCM6Field $d 'Media')
            Health = [string](Get-WCM6Field $d 'Health')
            OpStatus = [string](Get-WCM6Field $d 'OpStatus')
            Temp = $null; Wear = $null; Hours = $null
            ReadErrors = $null; ReadUncorr = $null; WriteErrors = $null
        }
        if ($ctr) {
            $rec['Temp'] = Get-WCM6Field $ctr 'Temp'
            $rec['Wear'] = Get-WCM6Field $ctr 'Wear'
            $rec['Hours'] = Get-WCM6Field $ctr 'Hours'
            $rec['ReadErrors'] = Get-WCM6Field $ctr 'ReadErrors'
            $rec['ReadUncorr'] = Get-WCM6Field $ctr 'ReadUncorr'
            $rec['WriteErrors'] = Get-WCM6Field $ctr 'WriteErrors'
        }
        $out['Disks'] += $rec
        $i++
    }
    if ($VolumesResult) {
        $out['VolumesOk'] = [bool](Get-WCM6Field $VolumesResult 'Ok')
        $vv = Get-WCM6Field $VolumesResult 'Volumes'
        if ($null -ne $vv) { $out['Volumes'] = @($vv) }
    }
    return $out
}

function Get-WCHealthStorageVerdict {
    # Diem Luu tru (trong so 25). Gia dinh nguong (ghi ro trong bao cao):
    #   Warning -20, Unhealthy -55 + SEVERE; OpStatus khac OK -8; nhiet do 60-69 -7,
    #   >=70 -15 (chi ap dung khi 0<T<100 de tranh nham don vi); Wear 21-50 -10,
    #   >50 -20; loi doc uncorrected>0 hoac total>=10000 -25, 1000-9999 -15;
    #   volume <5% -25, o he thong <10% -12 (tong volume toi da -30).
    param($Data)
    $facts = @()
    $disksOk = $false; $volumesOk = $false
    $disks = @(); $volumes = @()
    if ($Data) {
        $disksOk = [bool](Get-WCM6Field $Data 'DisksOk')
        $volumesOk = [bool](Get-WCM6Field $Data 'VolumesOk')
        $d = Get-WCM6Field $Data 'Disks'
        if ($null -ne $d) { $disks = @($d) }
        $v = Get-WCM6Field $Data 'Volumes'
        if ($null -ne $v) { $volumes = @($v) }
    }
    if (-not ($disksOk -or $volumesOk)) {
        return @{ Status = 'Unknown'; Score = $null; Severe = $false; Facts = @(@{ Key = 'storage.nodata' }); WhatKey = '' }
    }
    $score = 100.0
    $severe = $false
    if ($disksOk -and ($disks.Count -eq 0)) { $facts += @{ Key = 'storage.diskna' } }
    if (-not $disksOk) { $facts += @{ Key = 'storage.diskna' } }
    $anyCounter = $false
    foreach ($disk in $disks) {
        $name = [string](Get-WCM6Field $disk 'Name')
        if (-not $name) { $name = [string](Get-WCM6Field $disk 'DeviceId') }
        if (-not $name) { $name = '?' }
        $health = [string](Get-WCM6Field $disk 'Health')
        if ($health -eq 'Warning') {
            $score -= 20
            $facts += @{ Key = 'storage.diskwarn'; Args = @($name) }
        } elseif (($health -eq 'Unhealthy') -or ($health -eq 'Bad')) {
            $score -= 55
            $severe = $true
            $facts += @{ Key = 'storage.diskbad'; Args = @($name) }
        }
        $op = [string](Get-WCM6Field $disk 'OpStatus')
        if (($op -ne '') -and ($op -notlike '*OK*')) {
            $score -= 8
            $facts += @{ Key = 'storage.opstat'; Args = @($name, $op) }
        }
        $temp = Get-WCM6Field $disk 'Temp'
        if (($null -ne $temp) -and ([double]$temp -gt 0) -and ([double]$temp -lt 100)) {
            $anyCounter = $true
            if ([double]$temp -ge 70) {
                $score -= 15
                $facts += @{ Key = 'storage.temp.hot'; Args = @($name, [string]$temp) }
            } elseif ([double]$temp -ge 60) {
                $score -= 7
                $facts += @{ Key = 'storage.temp.warn'; Args = @($name, [string]$temp) }
            }
        }
        $wear = Get-WCM6Field $disk 'Wear'
        if ($null -ne $wear) { $anyCounter = $true }
        if (($null -ne $wear) -and ([double]$wear -gt 20)) {
            if ([double]$wear -gt 50) { $score -= 20 } else { $score -= 10 }
            $facts += @{ Key = 'storage.wear'; Args = @($name, [string]$wear) }
        }
        $rt = Get-WCM6Field $disk 'ReadErrors'
        $ru = Get-WCM6Field $disk 'ReadUncorr'
        if (($null -ne $rt) -or ($null -ne $ru)) { $anyCounter = $true }
        $rtN = 0.0; if ($null -ne $rt) { $rtN = [double]$rt }
        $ruN = 0.0; if ($null -ne $ru) { $ruN = [double]$ru }
        $ded = 0.0
        if ($ruN -gt 0) { $ded = 25 }
        elseif ($rtN -ge 10000) { $ded = 25 }
        elseif ($rtN -ge 1000) { $ded = 15 }
        if ($ded -gt 0) {
            $score -= $ded
            $facts += @{ Key = 'storage.readerr'; Args = @($name, [string]$rtN, [string]$ruN) }
        }
    }
    if ($disksOk -and ($disks.Count -gt 0) -and (-not $anyCounter)) {
        $facts += @{ Key = 'storage.nosmart' }
    }
    $volDed = 0.0
    foreach ($vol in $volumes) {
        $letter = [string](Get-WCM6Field $vol 'Letter')
        $pct = Get-WCM6Field $vol 'PctFree'
        if ($null -eq $pct) { continue }
        $p = [double]$pct
        $ded = 0.0
        if ($p -lt 5) { $ded = 25 }
        elseif (($p -lt 10) -and ($letter -eq $env:SystemDrive)) { $ded = 12 }
        if ($ded -gt 0) {
            $volDed += $ded
            $facts += @{ Key = 'storage.lowfree'; Args = @($letter, [string]$p) }
        }
    }
    if ($volDed -gt 30) { $volDed = 30 }
    $score -= $volDed
    if ($score -lt 0) { $score = 0 }
    $score = [int][math]::Round($score)
    $status = 'Warn'
    if ($score -ge 85) { $status = 'Ok' }
    if ($score -lt 60) { $status = 'Bad' }
    if ($facts.Count -eq 0) { $facts += @{ Key = 'storage.ok'; Args = @([string]$disks.Count) } }
    $whatKey = 'm6.storage.what.warn'
    if ($status -eq 'Ok') { $whatKey = 'm6.storage.what.ok' }
    if ($status -eq 'Bad') { $whatKey = 'm6.storage.what.bad' }
    return @{ Status = $status; Score = $score; Severe = $severe; Facts = $facts; WhatKey = $whatKey }
}

function Get-WCHealthStabilityVerdict {
    # Diem On dinh 30 ngay (trong so 25). Gia dinh nguong theo tan suat:
    #   kpower41: 1 lan -8 / 2 lan -16 / >=3 -24; whea: -10/-20/-30;
    #   bugcheck: -20/-35/-50; diskerr: 1-3 -12 / 4-9 -25 / >=10 -45 + SEVERE;
    #   tdr: -6/-12/-20; svc: -5/-12/-20; appcrash: -3/-8/-12.
    param($Data)
    $facts = @()
    $sysOk = $false; $appOk = $false
    $cats = $null
    $bugcodes = @()
    if ($Data) {
        $sysOk = [bool](Get-WCM6Field $Data 'SystemOk')
        $appOk = [bool](Get-WCM6Field $Data 'AppOk')
        $cats = Get-WCM6Field $Data 'Cats'
        $bc = Get-WCM6Field $Data 'BugCodes'
        if ($null -ne $bc) { $bugcodes = @($bc) }
    }
    if (-not $sysOk) {
        return @{ Status = 'Unknown'; Score = $null; Severe = $false; Facts = @(@{ Key = 'stab.nodata' }); WhatKey = '' }
    }
    $c = @{ kpower41 = 0; whea = 0; bugcheck = 0; diskerr = 0; tdr = 0; svc = 0; appcrash = 0 }
    if ($cats) {
        foreach ($k in @($c.Keys)) {
            $v = Get-WCM6Field $cats $k
            if ($null -ne $v) { $c[$k] = [int]$v }
        }
    }
    $score = 100.0
    $severe = $false
    if ($c['kpower41'] -ge 3) { $score -= 24 }
    elseif ($c['kpower41'] -eq 2) { $score -= 16 }
    elseif ($c['kpower41'] -eq 1) { $score -= 8 }
    if ($c['kpower41'] -gt 0) { $facts += @{ Key = 'stab.kpower41'; Args = @([string]$c['kpower41']) } }
    if ($c['whea'] -ge 3) { $score -= 30 }
    elseif ($c['whea'] -eq 2) { $score -= 20 }
    elseif ($c['whea'] -eq 1) { $score -= 10 }
    if ($c['whea'] -gt 0) { $facts += @{ Key = 'stab.whea'; Args = @([string]$c['whea']) } }
    if ($c['bugcheck'] -gt 0) {
        if ($c['bugcheck'] -ge 3) { $score -= 50 }
        elseif ($c['bugcheck'] -eq 2) { $score -= 35 }
        else { $score -= 20 }
        $facts += @{ Key = 'stab.bugcheck'; Args = @([string]$c['bugcheck'], [string]::Join(', ', $bugcodes)) }
    }
    if ($c['diskerr'] -ge 10) {
        $score -= 45
        $severe = $true
    } elseif ($c['diskerr'] -ge 4) {
        $score -= 25
    } elseif ($c['diskerr'] -ge 1) {
        $score -= 12
    }
    if ($c['diskerr'] -gt 0) { $facts += @{ Key = 'stab.diskerr'; Args = @([string]$c['diskerr']) } }
    if ($c['tdr'] -ge 10) { $score -= 20 }
    elseif ($c['tdr'] -ge 4) { $score -= 12 }
    elseif ($c['tdr'] -ge 1) { $score -= 6 }
    if ($c['tdr'] -gt 0) { $facts += @{ Key = 'stab.tdr'; Args = @([string]$c['tdr']) } }
    if ($c['svc'] -ge 20) { $score -= 20 }
    elseif ($c['svc'] -ge 6) { $score -= 12 }
    elseif ($c['svc'] -ge 1) { $score -= 5 }
    if ($c['svc'] -gt 0) { $facts += @{ Key = 'stab.svc'; Args = @([string]$c['svc']) } }
    if ($c['appcrash'] -ge 30) { $score -= 12 }
    elseif ($c['appcrash'] -ge 10) { $score -= 8 }
    elseif ($c['appcrash'] -ge 1) { $score -= 3 }
    if ($c['appcrash'] -gt 0) { $facts += @{ Key = 'stab.appcrash'; Args = @([string]$c['appcrash']) } }
    if (-not $appOk) { $facts += @{ Key = 'stab.applog' } }
    if ($score -lt 0) { $score = 0 }
    $score = [int][math]::Round($score)
    $status = 'Warn'
    if ($score -ge 85) { $status = 'Ok' }
    if ($score -lt 60) { $status = 'Bad' }
    if ($facts.Count -eq 0) { $facts += @{ Key = 'stab.ok' } }
    $whatKey = 'm6.stability.what.warn'
    if ($status -eq 'Ok') { $whatKey = 'm6.stability.what.ok' }
    return @{ Status = $status; Score = $score; Severe = $severe; Facts = $facts; WhatKey = $whatKey }
}

function Get-WCHealthIntegrityVerdict {
    # Diem Toan ven (trong so 15). Chi dua tren ExitCode, khong parse output:
    #   ca hai sach (exit 0) = 100; mot sach + mot khong chay duoc = 70;
    #   mot sach + mot khong ket luan (exit != 0) = 60; con lai = 50;
    #   ca hai khong chay duoc -> Unknown (bo khoi mau so).
    param($Dism, $Sfc)
    $dOk = $false; $dCode = $null
    if ($Dism) {
        $dOk = [bool](Get-WCM6Field $Dism 'Ok')
        $dCode = Get-WCM6Field $Dism 'ExitCode'
    }
    $sOk = $false; $sCode = $null
    if ($Sfc) {
        $sOk = [bool](Get-WCM6Field $Sfc 'Ok')
        $sCode = Get-WCM6Field $Sfc 'ExitCode'
    }
    $dClean = ($dOk -and ($dCode -eq 0))
    $dIncon = ($dOk -and ($dCode -ne 0))
    $dNa = (-not $dOk)
    $sClean = ($sOk -and ($sCode -eq 0))
    $sIncon = ($sOk -and ($sCode -ne 0))
    $sNa = (-not $sOk)
    $facts = @()
    if ($dClean) { $facts += @{ Key = 'int.dism.ok' } }
    elseif ($dIncon) { $facts += @{ Key = 'int.dism.unknown'; Args = @([string]$dCode) } }
    else { $facts += @{ Key = 'int.dism.norun' } }
    if ($sClean) { $facts += @{ Key = 'int.sfc.ok' } }
    elseif ($sIncon) { $facts += @{ Key = 'int.sfc.unknown'; Args = @([string]$sCode) } }
    else { $facts += @{ Key = 'int.sfc.norun' } }
    if ($dNa -and $sNa) {
        return @{ Status = 'Unknown'; Score = $null; Severe = $false; Facts = $facts; WhatKey = '' }
    }
    $score = 50
    if ($dClean -and $sClean) { $score = 100 }
    elseif (($dClean -and $sIncon) -or ($dIncon -and $sClean)) { $score = 60 }
    elseif (($dClean -and $sNa) -or ($dNa -and $sClean)) { $score = 70 }
    $status = 'Warn'
    if ($score -ge 85) { $status = 'Ok' }
    $whatKey = 'm6.integrity.what.warn'
    if ($status -eq 'Ok') { $whatKey = 'm6.integrity.what.ok' }
    return @{ Status = $status; Score = $score; Severe = $false; Facts = $facts; WhatKey = $whatKey }
}

function Get-WCHealthSecurityVerdict {
    # Diem Bao mat (trong so 15): RTP bat + chu ky <=3 ngay = 100; 4-7 = 85;
    # 8-14 = 60; >14 = 40; RTP tat = 30; AV thu ba / khong doc duoc -> Unknown.
    param($Data)
    if (-not $Data) {
        return @{ Status = 'Unknown'; Score = $null; Severe = $false; Facts = @(@{ Key = 'sec.nodata' }); WhatKey = '' }
    }
    $mode = [string](Get-WCM6Field $Data 'Mode')
    if ($mode -eq 'thirdparty') {
        $av = [string](Get-WCM6Field $Data 'AvName')
        return @{ Status = 'Unknown'; Score = $null; Severe = $false; Facts = @(@{ Key = 'sec.third'; Args = @($av) }); WhatKey = '' }
    }
    if ($mode -ne 'defender') {
        return @{ Status = 'Unknown'; Score = $null; Severe = $false; Facts = @(@{ Key = 'sec.nodata' }); WhatKey = '' }
    }
    $rt = Get-WCM6Field $Data 'RealTime'
    $sig = Get-WCM6Field $Data 'SigAgeDays'
    $facts = @()
    $score = 70
    $status = 'Warn'
    $whatKey = 'm6.security.what.warn'
    if ($rt -eq $false) {
        $facts += @{ Key = 'sec.rtp.off' }
        $score = 30
        $status = 'Bad'
        $whatKey = 'm6.security.what.rtp'
    } elseif ($null -eq $rt) {
        $facts += @{ Key = 'sec.rtp.na' }
        $score = 70
        $status = 'Warn'
    } else {
        $facts += @{ Key = 'sec.rtp.on' }
        if ($null -eq $sig) {
            $facts += @{ Key = 'sec.sig.na' }
            $score = 80
            $status = 'Warn'
            $whatKey = 'm6.security.what.warn'
        } else {
            $s = [double]$sig
            if ($s -le 3) {
                $facts += @{ Key = 'sec.ok.sig'; Args = @([string]$s) }
                $score = 100
                $status = 'Ok'
                $whatKey = 'm6.security.what.ok'
            } elseif ($s -le 7) {
                $facts += @{ Key = 'sec.sigold'; Args = @([string]$s) }
                $score = 85
                $status = 'Ok'
                $whatKey = 'm6.security.what.sig'
            } elseif ($s -le 14) {
                $facts += @{ Key = 'sec.sigold'; Args = @([string]$s) }
                $score = 60
                $status = 'Warn'
                $whatKey = 'm6.security.what.sig'
            } else {
                $facts += @{ Key = 'sec.sigold'; Args = @([string]$s) }
                $score = 40
                $status = 'Warn'
                $whatKey = 'm6.security.what.sig'
            }
        }
    }
    return @{ Status = $status; Score = $score; Severe = $false; Facts = $facts; WhatKey = $whatKey }
}

function Get-WCHealthMemoryVerdict {
    # Diem Bo nho (trong so 10): khong loi = 100; 1-2 WHEA bo nho = 60;
    # >=3 WHEA bo nho = 25 + SEVERE; Memory Diagnostic phat hien loi = 20 + SEVERE.
    param($Data)
    if (-not $Data) {
        return @{ Status = 'Unknown'; Score = $null; Severe = $false; Facts = @(@{ Key = 'mem.nodata' }); WhatKey = '' }
    }
    $sysOk = [bool](Get-WCM6Field $Data 'SystemOk')
    if (-not $sysOk) {
        return @{ Status = 'Unknown'; Score = $null; Severe = $false; Facts = @(@{ Key = 'mem.nodata' }); WhatKey = '' }
    }
    $cats = Get-WCM6Field $Data 'Cats'
    $wheamem = 0; $diagErr = 0; $diagOk = 0
    if ($cats) {
        $v = Get-WCM6Field $cats 'wheamem'
        if ($null -ne $v) { $wheamem = [int]$v }
        $v = Get-WCM6Field $cats 'memdiagerr'
        if ($null -ne $v) { $diagErr = [int]$v }
        $v = Get-WCM6Field $cats 'memdiagok'
        if ($null -ne $v) { $diagOk = [int]$v }
    }
    $facts = @()
    $score = 100
    $status = 'Ok'
    $severe = $false
    if ($diagErr -gt 0) {
        $facts += @{ Key = 'mem.diag' }
        $score = 20
        $status = 'Bad'
        $severe = $true
    } elseif ($wheamem -ge 3) {
        $facts += @{ Key = 'mem.whea'; Args = @([string]$wheamem) }
        $score = 25
        $status = 'Bad'
        $severe = $true
    } elseif ($wheamem -ge 1) {
        $facts += @{ Key = 'mem.whea'; Args = @([string]$wheamem) }
        $score = 60
        $status = 'Warn'
    } else {
        $facts += @{ Key = 'mem.ok' }
        if ($diagOk -gt 0) { $facts += @{ Key = 'mem.diagok' } }
    }
    $whatKey = 'm6.memory.what.test'
    if ($status -eq 'Ok') { $whatKey = 'm6.memory.what.ok' }
    return @{ Status = $status; Score = $score; Severe = $severe; Facts = $facts; WhatKey = $whatKey }
}

function Get-WCHealthBatteryVerdict {
    # Diem Pin (trong so 10): chai <=10% = 100; 11-20% = 85; 21-35% = 65; >35% = 40.
    # Khong co pin / khong doc duoc / thieu dung luong thiet ke -> Unknown (bo).
    param($Data)
    if (-not $Data) {
        return @{ Status = 'Unknown'; Score = $null; Severe = $false; Facts = @(@{ Key = 'bat.nodata' }); WhatKey = '' }
    }
    $ok = [bool](Get-WCM6Field $Data 'Ok')
    if (-not $ok) {
        return @{ Status = 'Unknown'; Score = $null; Severe = $false; Facts = @(@{ Key = 'bat.nodata' }); WhatKey = '' }
    }
    $has = [bool](Get-WCM6Field $Data 'HasBattery')
    if (-not $has) {
        return @{ Status = 'Unknown'; Score = $null; Severe = $false; Facts = @(@{ Key = 'bat.absent' }); WhatKey = '' }
    }
    $batteries = @()
    $bb = Get-WCM6Field $Data 'Batteries'
    if ($null -ne $bb) { $batteries = @($bb) }
    $worst = $null; $worstFull = 0; $worstDesign = 0
    foreach ($b in $batteries) {
        $w = Get-WCM6Field $b 'Wear'
        if ($null -eq $w) { continue }
        if (($null -eq $worst) -or ([double]$w -gt [double]$worst)) {
            $worst = $w
            $worstFull = Get-WCM6Field $b 'Full'
            $worstDesign = Get-WCM6Field $b 'Design'
        }
    }
    if ($null -eq $worst) {
        return @{ Status = 'Unknown'; Score = $null; Severe = $false; Facts = @(@{ Key = 'bat.nowear' }); WhatKey = '' }
    }
    $score = 100
    if ([double]$worst -gt 35) { $score = 40 }
    elseif ([double]$worst -gt 20) { $score = 65 }
    elseif ([double]$worst -gt 10) { $score = 85 }
    $status = 'Warn'
    if ($score -ge 85) { $status = 'Ok' }
    if ($score -lt 60) { $status = 'Bad' }
    $factKey = 'bat.ok'
    $fargs = @([string]$worst)
    if ([double]$worst -gt 10) {
        $factKey = 'bat.wear'
        $fargs = @([string]$worst, [string]$worstFull, [string]$worstDesign)
    }
    $whatKey = 'm6.battery.what.ok'
    if ($status -ne 'Ok') { $whatKey = 'm6.battery.what.wear' }
    return @{ Status = $status; Score = $score; Severe = $false; Facts = @(@{ Key = $factKey; Args = $fargs }); WhatKey = $whatKey }
}

function Get-WCHealthScore {
    # HAM THUAN de unit test (spec M6): cong thuc diem tong.
    #   $Groups = @{ Storage = @{Status;Score;Severe;Reason}; ... }
    #   - Nhom thieu/null hoac Status 'Unknown' -> BO khoi mau so (chia lai trong so)
    #   - Tran: nhom nao do Severe=$true -> diem toi da 49 + CapReason
    #   - Khong nhom nao doc duoc -> Score = $null
    # Tra ve: @{ Score; Breakdown = @(@{Group;Weight;Score;Reason;Included;Severe});
    #           Capped; CapReason; TotalWeight; SkippedNames }
    param($Groups)
    $weights = @{ Storage = 25; Stability = 25; Integrity = 15; Security = 15; Memory = 10; Battery = 10 }
    $breakdown = @()
    $sum = 0.0
    $totalWeight = 0
    $severeReasons = @()
    $skipped = @()
    foreach ($name in @(Get-WCM6GroupKeys)) {
        $w = $weights[$name]
        $g = $null
        if ($Groups -is [System.Collections.IDictionary]) {
            if ($Groups.Contains($name)) { $g = $Groups[$name] }
        } elseif ($Groups) {
            $g = Get-WCProp $Groups $name
        }
        $score = $null
        $reason = ''
        $included = $false
        $isSevere = $false
        if ($null -ne $g) {
            $status = [string](Get-WCM6Field $g 'Status')
            $score = Get-WCM6Field $g 'Score'
            $reason = [string](Get-WCM6Field $g 'Reason')
            $isSevere = [bool](Get-WCM6Field $g 'Severe')
            if (($status -ne 'Unknown') -and ($null -ne $score)) {
                $included = $true
                $sum += ([double]$score * $w)
                $totalWeight += $w
                if ($isSevere) { $severeReasons += $reason }
            }
        }
        if (-not $included) {
            $skipped += $name
            $score = $null
        }
        $breakdown += @{
            Group = $name; Weight = $w; Score = $score; Reason = $reason
            Included = $included; Severe = $isSevere
        }
    }
    $final = $null
    $capped = $false
    $capReason = ''
    if ($totalWeight -gt 0) {
        $final = [int][math]::Round(($sum / $totalWeight), 0)
        if ($severeReasons.Count -gt 0) {
            $capped = $true
            $capReason = [string]::Join(' ', $severeReasons)
            if ($final -gt 49) { $final = 49 }
        }
    }
    return @{
        Score = $final
        Breakdown = $breakdown
        Capped = $capped
        CapReason = $capReason
        TotalWeight = $totalWeight
        SkippedNames = $skipped
    }
}

# ---------------------------------------------------------------------------
# TASK NEN - moi nhom 1 task rieng, ket qua ve dan (spec M6)
# ---------------------------------------------------------------------------
function Test-WCM6Busy {
    # Co tac vu nao cua M6 dang chay khong (chan chong len: DISM/SFC dung cung
    # kho servicing cua Windows, khong duoc chay song song)
    foreach ($id in @('m6.storage', 'm6.stability', 'm6.integrity', 'm6.security', 'm6.memory', 'm6.battery', 'm6.deepscan', 'm6.repair.dism', 'm6.repair.sfc')) {
        if (Test-WCTaskRunning $id) { return $true }
    }
    return $false
}

function Invoke-WCM6RunScan {
    # Khoi dong 6 task nen (moi nhom 1 task, ve dan). $NoCache = quen cache de quet moi.
    param($State, [bool]$NoCache)
    $State.Groups = @{}
    $State.GroupData = @{}
    if ($State.ScanLabel) {
        $State.ScanLabel.Text = (T 'm6.scan.at' @((Get-Date).ToString('g')))
    }
    foreach ($k in (Get-WCM6GroupKeys)) {
        Update-WCM6RowLoading $State $k
    }
    Update-WCM6Score $State
    Write-WCLog 'INFO' ('M6: bat dau quet (NoCache=' + $NoCache + ')')
    foreach ($k in (Get-WCM6GroupKeys)) {
        Invoke-WCM6StartGroup $State $k $NoCache
    }
}

function Invoke-WCM6Rescan {
    param($State)
    if (Test-WCM6Busy) {
        Show-WCToast (T 'm6.rescan.busy') 'Info'
        return
    }
    Invoke-WCM6RunScan $State $true
}

function Invoke-WCM6StartGroup {
    # Khoi dong task nen cho 1 nhom. Worker thuan (param $ctx/$s); Done chay lai
    # tren UI thread bang closure cua $State.
    param($State, [string]$Key, [bool]$NoCache)
    $lower = $Key.ToLower()
    $taskId = 'm6.' + $lower
    $title = (T ('m6.group.' + $lower))
    $worker = $null
    switch ($Key) {
        'Storage' {
            $worker = {
                param($ctx, $s)
                $nc = $false
                if ($s -and $s.ContainsKey('NoCache')) { $nc = [bool]$s['NoCache'] }
                $merged = Merge-WCHealthStorage (Get-WCM6PhysicalDisksData $nc) (Get-WCM6ReliabilityData $nc) (Get-WCM6VolumesData $nc)
                $verdict = Get-WCHealthStorageVerdict $merged
                return @{
                    Key = 'Storage'; Status = $verdict['Status']; Score = $verdict['Score']
                    Severe = $verdict['Severe']; Facts = $verdict['Facts']; WhatKey = $verdict['WhatKey']
                    Data = $merged
                }
            }
        }
        'Stability' {
            $worker = {
                param($ctx, $s)
                $nc = $false
                if ($s -and $s.ContainsKey('NoCache')) { $nc = [bool]$s['NoCache'] }
                $data = Get-WCM6EventsData $nc
                $verdict = Get-WCHealthStabilityVerdict $data
                return @{
                    Key = 'Stability'; Status = $verdict['Status']; Score = $verdict['Score']
                    Severe = $verdict['Severe']; Facts = $verdict['Facts']; WhatKey = $verdict['WhatKey']
                    Data = $data
                }
            }
        }
        'Integrity' {
            # Nhom cham nhat: DISM CheckHealth (giay) + SFC /verifyonly (co the may phut)
            $worker = {
                param($ctx, $s)
                $nc = $false
                if ($s -and $s.ContainsKey('NoCache')) { $nc = [bool]$s['NoCache'] }
                $cancelled = @{ Key = 'Integrity'; Status = 'Unknown'; Score = $null; Severe = $false; Facts = @(@{ Key = 'cancelled' }); WhatKey = ''; Data = $null }
                $ctx.Progress(10, (T 'm6.integrity.p.dism'))
                $dism = Get-WCM6DismCheckData $nc
                if ($ctx.Cancelled()) { return $cancelled }
                $ctx.Progress(35, (T 'm6.integrity.p.sfc'))
                $sfc = Get-WCM6SfcVerifyData $nc
                if ($ctx.Cancelled()) { return $cancelled }
                $verdict = Get-WCHealthIntegrityVerdict $dism $sfc
                return @{
                    Key = 'Integrity'; Status = $verdict['Status']; Score = $verdict['Score']
                    Severe = $verdict['Severe']; Facts = $verdict['Facts']; WhatKey = $verdict['WhatKey']
                    Data = @{ Dism = $dism; Sfc = $sfc }
                }
            }
        }
        'Security' {
            # Chi doc lai nguon 'sec.mpstatus' cua M5 qua cache - khong tao quet trung
            $worker = {
                param($ctx, $s)
                $nc = $false
                if ($s -and $s.ContainsKey('NoCache')) { $nc = [bool]$s['NoCache'] }
                $data = Get-WCM6MpData $nc
                $verdict = Get-WCHealthSecurityVerdict $data
                return @{
                    Key = 'Security'; Status = $verdict['Status']; Score = $verdict['Score']
                    Severe = $verdict['Severe']; Facts = $verdict['Facts']; WhatKey = $verdict['WhatKey']
                    Data = $data
                }
            }
        }
        'Memory' {
            $worker = {
                param($ctx, $s)
                $nc = $false
                if ($s -and $s.ContainsKey('NoCache')) { $nc = [bool]$s['NoCache'] }
                $data = Get-WCM6EventsData $nc
                $verdict = Get-WCHealthMemoryVerdict $data
                return @{
                    Key = 'Memory'; Status = $verdict['Status']; Score = $verdict['Score']
                    Severe = $verdict['Severe']; Facts = $verdict['Facts']; WhatKey = $verdict['WhatKey']
                    Data = $data
                }
            }
        }
        'Battery' {
            $worker = {
                param($ctx, $s)
                $nc = $false
                if ($s -and $s.ContainsKey('NoCache')) { $nc = [bool]$s['NoCache'] }
                $data = Get-WCM6BatteryData $nc
                $verdict = Get-WCHealthBatteryVerdict $data
                return @{
                    Key = 'Battery'; Status = $verdict['Status']; Score = $verdict['Score']
                    Severe = $verdict['Severe']; Facts = $verdict['Facts']; WhatKey = $verdict['WhatKey']
                    Data = $data
                }
            }
        }
    }
    if (-not $worker) { return $false }
    $done = {
        param($r)
        Invoke-WCM6ApplyGroupResult $State $r
    }.GetNewClosure()
    if ($Key -eq 'Integrity') {
        # Hien tien do that + nut Huy o thanh trang thai; dong "Tại sao" cap nhat
        # truc tieo theo tien do (SFC /verifyonly lau)
        $onMsg = {
            param($msg)
            try {
                if ($msg.Type -eq 'Progress') {
                    if ($State.Rows.ContainsKey('Integrity')) {
                        $State.Rows['Integrity'].WhyText.Text = $msg.Text
                    }
                }
            } catch { }
        }.GetNewClosure()
        return (Start-WCTask -Id $taskId -Title $title -Args @{ NoCache = $NoCache } -Worker $worker -Done $done -ShowStatus -OnMessage $onMsg)
    }
    return (Start-WCTask -Id $taskId -Title $title -Args @{ NoCache = $NoCache } -Worker $worker -Done $done)
}

function Invoke-WCM6ApplyGroupResult {
    # Nhan ket qua 1 nhom tu worker: ghp ly do (i18n tren UI thread), cap nhat
    # dong bang + diem tong.
    param($State, $Result)
    if ($null -eq $Result) { return }
    $key = [string](Get-WCM6Field $Result 'Key')
    if (-not $key) { return }
    $status = [string](Get-WCM6Field $Result 'Status')
    $score = Get-WCM6Field $Result 'Score'
    $severe = [bool](Get-WCM6Field $Result 'Severe')
    $whatKey = [string](Get-WCM6Field $Result 'WhatKey')
    $data = Get-WCM6Field $Result 'Data'
    $reason = ''
    $facts = Get-WCM6Field $Result 'Facts'
    if ($null -ne $facts) {
        $parts = @()
        foreach ($f in @($facts)) {
            $fk = [string](Get-WCM6Field $f 'Key')
            if (-not $fk) { continue }
            $fargs = Get-WCM6Field $f 'Args'
            if ($null -ne $fargs) {
                $parts += (T ('m6.fact.' + $fk) @($fargs))
            } else {
                $parts += (T ('m6.fact.' + $fk))
            }
        }
        $reason = [string]::Join(' ', $parts)
    }
    if ([string]::IsNullOrEmpty($reason)) { $reason = (T 'm6.why.nodata') }
    $State.Groups[$key] = @{ Status = $status; Score = $score; Severe = $severe; Reason = $reason }
    $State.GroupData[$key] = $data
    Update-WCM6GroupRow $State $key $status $score $reason $whatKey $data
    Update-WCM6Score $State
    Write-WCLog 'INFO' ('M6: nhom ' + $key + ' -> ' + $status + ' diem=' + $score)
}

# ---------------------------------------------------------------------------
# UI HELPERS
# ---------------------------------------------------------------------------
function Set-WCM6ChipStatus {
    # Doi mau + chu cua chip trang thai (chip mau luon kem chu - spec muc 1)
    param($Chip, [string]$Status, [string]$Text)
    $bgKey = 'WcUnknownBg'
    $fgKey = 'WcUnknown'
    if ($Status -eq 'Ok') { $bgKey = 'WcOkBg'; $fgKey = 'WcOk' }
    elseif ($Status -eq 'Warn') { $bgKey = 'WcWarnBg'; $fgKey = 'WcWarn' }
    elseif ($Status -eq 'Bad') { $bgKey = 'WcBadBg'; $fgKey = 'WcBad' }
    $Chip.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, $bgKey)
    if ($Chip.Tag -is [Windows.Controls.TextBlock]) {
        $Chip.Tag.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, $fgKey)
    }
    Set-WCChipText $Chip $Text
}

function Test-WCM6NavExists {
    # Chi hien nut "Xem chi tiet" khi module dich da dang ky nav
    param([Parameter(Mandatory)][string]$NavKey)
    foreach ($item in (Get-WCNavItemsSorted)) {
        if ($item.Key -eq $NavKey) { return $true }
    }
    return $false
}

function New-WCM6FiveColGrid {
    # Luoi 5 cot dung chung cho header + moi dong nhom:
    # Nhom | Trong so | Diem | Tai sao | Nen lam gi
    $g = New-Object Windows.Controls.Grid
    foreach ($w in @(200, 62, 56)) {
        $cd = New-Object Windows.Controls.ColumnDefinition
        $cd.Width = (New-Object Windows.GridLength([double]$w))
        $g.ColumnDefinitions.Add($cd) | Out-Null
    }
    $cdStar = New-Object Windows.Controls.ColumnDefinition
    $cdStar.Width = (New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star))
    $g.ColumnDefinitions.Add($cdStar) | Out-Null
    $cdWhat = New-Object Windows.Controls.ColumnDefinition
    $cdWhat.Width = (New-Object Windows.GridLength(340))
    $g.ColumnDefinitions.Add($cdWhat) | Out-Null
    return $g
}

function New-WCM6GroupRow {
    # 1 dong nhom trong bang phan ra: card chua luoi 5 cot + expander chi tiet
    param($State, [string]$Key, [int]$Weight)
    $lower = $Key.ToLower()
    $card = New-Object Windows.Controls.Border
    $card.CornerRadius = (New-Object Windows.CornerRadius(8))
    $card.BorderThickness = (New-Object Windows.Thickness(1))
    $card.Padding = (New-Object Windows.Thickness(12))
    $card.Margin = (New-Object Windows.Thickness(0, 4, 0, 4))
    $card.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'WcCardBg2')
    $card.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'WcBorder')
    $v = New-WCVStack -Spacing 6

    $grid = New-WCM6FiveColGrid
    # Cot 0: ten nhom + chip trang thai (chip co ToolTip giai thich)
    $left = New-WCVStack -Spacing 4
    $nameTb = New-WCTextBlock -Text (T ('m6.group.' + $lower)) -Size 13.5 -Weight 'SemiBold' -Wrap
    Add-WCChild $left $nameTb
    $chip = New-WCChip -Text (T 'm6.status.scanning') -Kind 'Unknown'
    $chip.ToolTip = (T ('m6.group.' + $lower + '.tip'))
    $chip.HorizontalAlignment = [Windows.HorizontalAlignment]::Left
    Add-WCChild $left $chip
    [Windows.Controls.Grid]::SetColumn($left, 0)
    $grid.Children.Add($left) | Out-Null
    # Cot 1: trong so
    $weightTb = New-WCTextBlock -Text ('{0}%' -f $Weight) -Size 12.5 -ColorKey 'WcSubtle'
    $weightTb.VerticalAlignment = [Windows.VerticalAlignment]::Center
    [Windows.Controls.Grid]::SetColumn($weightTb, 1)
    $grid.Children.Add($weightTb) | Out-Null
    # Cot 2: diem
    $scoreTb = New-WCTextBlock -Text '…' -Size 16 -Weight 'SemiBold'
    $scoreTb.VerticalAlignment = [Windows.VerticalAlignment]::Center
    [Windows.Controls.Grid]::SetColumn($scoreTb, 2)
    $grid.Children.Add($scoreTb) | Out-Null
    # Cot 3: tai sao
    $whyTb = New-WCTextBlock -Text (T 'common.loading') -Size 12.5 -Wrap
    $whyTb.VerticalAlignment = [Windows.VerticalAlignment]::Center
    [Windows.Controls.Grid]::SetColumn($whyTb, 3)
    $grid.Children.Add($whyTb) | Out-Null
    # Cot 4: nen lam gi + nut hanh dong
    $whatCol = New-WCVStack -Spacing 4
    $whatTb = New-WCTextBlock -Text '' -Size 12 -ColorKey 'WcSubtle' -Wrap
    Add-WCChild $whatCol $whatTb
    $btnHost = New-WCHStack -Spacing 6
    Add-WCChild $whatCol $btnHost
    [Windows.Controls.Grid]::SetColumn($whatCol, 4)
    $grid.Children.Add($whatCol) | Out-Null

    Add-WCChild $v $grid
    # Expander chi tiet (bang dia/su kien/ma thoat...) - nap khi co ket qua
    $exp = New-WCExpander -Title (T 'm6.detail')
    Add-WCChild $v $exp.Root

    $card.Child = $v
    $row = @{
        Key = $Key; Card = $card; Chip = $chip
        ScoreText = $scoreTb; WhyText = $whyTb; WhatText = $whatTb
        BtnHost = $btnHost; DetailHost = $exp.Body
    }
    $State.Rows[$Key] = $row
    return $row
}

function Update-WCM6RowLoading {
    # Dat lai 1 dong ve trang thai "dang quet"
    param($State, [string]$Key)
    $row = $State.Rows[$Key]
    if (-not $row) { return }
    Set-WCM6ChipStatus $row.Chip 'Unknown' (T 'm6.status.scanning')
    $row.ScoreText.Text = '…'
    $row.WhyText.Text = (T 'common.loading')
    $row.WhatText.Text = ''
    $row.BtnHost.Children.Clear()
    $row.DetailHost.Children.Clear()
}

function Update-WCM6GroupRow {
    # Cap nhat 1 dong nhom sau khi co ket qua + nap lai nut hanh dong/chi tiet
    param($State, [string]$Key, [string]$Status, $Score, [string]$Reason, [string]$WhatKey, $Data)
    $row = $State.Rows[$Key]
    if (-not $row) { return }
    if ($Status -eq 'Unknown') {
        Set-WCM6ChipStatus $row.Chip 'Unknown' (T 'm6.skipped')
        $row.ScoreText.Text = '—'
    } else {
        $chipText = (T ('common.status.' + $Status.ToLower()))
        Set-WCM6ChipStatus $row.Chip $Status $chipText
        $row.ScoreText.Text = [string]$Score
    }
    $row.WhyText.Text = $Reason
    if ($WhatKey) {
        $row.WhatText.Text = (T $WhatKey)
    } else {
        $row.WhatText.Text = ''
    }
    # Nut hanh dong: "Xem chi tiet" chuyen nav sang module lien quan
    $row.BtnHost.Children.Clear()
    $navMap = @{ Storage = 'm2'; Stability = 'm3'; Integrity = ''; Security = 'm5'; Memory = 'm1'; Battery = 'm4' }
    $navKey = $navMap[$Key]
    if ($navKey -and (Test-WCM6NavExists $navKey)) {
        $navBtn = New-WCButton -Text (T 'm6.action.detail') -Small -OnClick {
            param($b)
            Invoke-WCShowNav $navKey
        }.GetNewClosure()
        $row.BtnHost.Children.Add($navBtn) | Out-Null
    }
    if ($Key -eq 'Memory') {
        $memBtn = New-WCButton -Text (T 'm6.memory.run') -Small -OnClick {
            param($b)
            Invoke-WCM6RunMemoryDiagnostic
        }.GetNewClosure()
        $row.BtnHost.Children.Add($memBtn) | Out-Null
    }
    if ($Key -eq 'Integrity') {
        $deepBtn = New-WCButton -Text (T 'm6.integrity.deep') -Small -OnClick {
            param($b)
            Invoke-WCM6DeepScan $State
        }.GetNewClosure()
        $row.BtnHost.Children.Add($deepBtn) | Out-Null
    }
    # Chi tiet tung nhom
    $row.DetailHost.Children.Clear()
    try {
        switch ($Key) {
            'Storage' { Update-WCM6StorageDetail $row.DetailHost $Data }
            'Stability' { Update-WCM6StabilityDetail $row.DetailHost $Data }
            'Integrity' { Update-WCM6IntegrityDetail $row.DetailHost $Data $State.DeepResult }
            'Security' { Update-WCM6SecurityDetail $row.DetailHost $Data }
            'Memory' { Update-WCM6MemoryDetail $row.DetailHost $Data }
            'Battery' { Update-WCM6BatteryDetail $row.DetailHost $Data }
        }
    } catch {
        Write-WCLog 'WARN' ('M6 chi tiet ' + $Key + ' loi: ' + $_.Exception.Message)
    }
}

function Update-WCM6Score {
    # Tinh lai diem tong tu cac nhom da ve (ve dan) + cap nhat vung diem lon
    param($State)
    $res = Get-WCHealthScore $State.Groups
    $done = $State.Groups.Count
    $total = (Get-WCM6GroupKeys).Count
    if ($null -ne $res.Score) {
        $State.ScoreText.Text = [string]$res.Score
        $band = 'bad'
        $color = 'WcBad'
        if ($res.Score -ge 75) { $band = 'good'; $color = 'WcOk' }
        elseif ($res.Score -ge 50) { $band = 'mid'; $color = 'WcWarn' }
        $State.ScoreText.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, $color)
        $State.BandText.Text = (T ('m6.score.band.' + $band))
    } else {
        $State.ScoreText.Text = '—'
        $State.ScoreText.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'WcUnknown')
        if ($done -lt $total) { $State.BandText.Text = (T 'm6.status.scanning') }
        else { $State.BandText.Text = (T 'm6.score.nodata') }
    }
    if ($done -lt $total) {
        $State.PendingText.Text = (T 'm6.scan.pending' @([string]$done, [string]$total))
    } else {
        $State.PendingText.Text = (T 'm6.scan.done')
    }
    # Ghi chu "bo qua" - chi dem cac nhom DA VE va bi Unknown (khong dem nhom dang quet)
    $skippedReal = @()
    foreach ($k in @($State.Groups.Keys)) {
        if ([string]$State.Groups[$k]['Status'] -eq 'Unknown') { $skippedReal += $k }
    }
    if ($skippedReal.Count -gt 0) {
        $names = @()
        foreach ($n in $skippedReal) { $names += (Get-WCM6GroupLabel $n) }
        $State.RenormNote.Text = (T 'm6.score.renorm' @([string]::Join(', ', $names)))
        $State.RenormNote.Visibility = [Windows.Visibility]::Visible
    } else {
        $State.RenormNote.Visibility = [Windows.Visibility]::Collapsed
    }
    if ($res.Capped) {
        $State.CapNote.Text = (T 'm6.score.cap' @($res.CapReason))
        $State.CapNote.Visibility = [Windows.Visibility]::Visible
    } else {
        $State.CapNote.Visibility = [Windows.Visibility]::Collapsed
    }
}

# ---------------------------------------------------------------------------
# CHI TIET tung nhom (nap vao expander cua dong)
# ---------------------------------------------------------------------------
function Update-WCM6StorageDetail {
    param($DetailHost, $Data)
    if ($null -eq $Data) { return }
    $disks = Get-WCM6Field $Data 'Disks'
    $volumes = Get-WCM6Field $Data 'Volumes'
    if ($null -ne $disks) {
        $tbl = New-WCTable -Columns @(
            @{ Header = (T 'm6.storage.col.disk');     Prop = 'D0'; Width = 160 }
            @{ Header = (T 'm6.storage.col.media');    Prop = 'D1'; Width = 90 }
            @{ Header = (T 'm6.storage.col.health');   Prop = 'D2'; Width = 100 }
            @{ Header = (T 'm6.storage.col.temp');     Prop = 'D3'; Width = 90 }
            @{ Header = (T 'm6.storage.col.wear');     Prop = 'D4'; Width = 80 }
            @{ Header = (T 'm6.storage.col.hours');    Prop = 'D5'; Width = 90 }
            @{ Header = (T 'm6.storage.col.readerr');  Prop = 'D6'; Width = 150 }
        )
        foreach ($d in @($disks)) {
            $name = [string](Get-WCM6Field $d 'Name')
            if (-not $name) { $name = [string](Get-WCM6Field $d 'DeviceId') }
            if (-not $name) { $name = (T 'common.unknown') }
            $temp = Get-WCM6Field $d 'Temp'
            $wear = Get-WCM6Field $d 'Wear'
            $hours = Get-WCM6Field $d 'Hours'
            $rt = Get-WCM6Field $d 'ReadErrors'
            $ru = Get-WCM6Field $d 'ReadUncorr'
            $errTxt = (T 'common.na')
            if (($null -ne $rt) -or ($null -ne $ru)) {
                $errTxt = (T 'm6.fmt.errs' @([string]$rt, [string]$ru))
            }
            $tbl.Items.Add([PSCustomObject]@{
                D0 = $name
                D1 = [string](Get-WCM6Field $d 'Media')
                D2 = [string](Get-WCM6Field $d 'Health')
                D3 = ($(if ($null -ne $temp) { ('{0}°C' -f $temp) } else { (T 'common.na') }))
                D4 = ($(if ($null -ne $wear) { ('{0}%' -f $wear) } else { (T 'common.na') }))
                D5 = ($(if ($null -ne $hours) { (T 'm6.fmt.hours' @([string]$hours)) } else { (T 'common.na') }))
                D6 = $errTxt
            }) | Out-Null
        }
        Add-WCChild $DetailHost $tbl
    }
    if ($null -ne $volumes) {
        $vt = New-WCTable -Columns @(
            @{ Header = (T 'm6.storage.col.vol');   Prop = 'V0'; Width = 100 }
            @{ Header = (T 'm6.storage.col.size');  Prop = 'V1'; Width = 120 }
            @{ Header = (T 'm6.storage.col.free');  Prop = 'V2'; Width = 120 }
            @{ Header = (T 'm6.storage.col.pct');   Prop = 'V3'; Width = 90 }
        )
        foreach ($v in @($volumes)) {
            $size = Get-WCM6Field $v 'Size'
            $free = Get-WCM6Field $v 'Free'
            $pct = Get-WCM6Field $v 'PctFree'
            $vt.Items.Add([PSCustomObject]@{
                V0 = [string](Get-WCM6Field $v 'Letter')
                V1 = ($(if ($null -ne $size) { ConvertTo-WCHumanSize ([long]$size) } else { '—' }))
                V2 = ($(if ($null -ne $free) { ConvertTo-WCHumanSize ([long]$free) } else { '—' }))
                V3 = ($(if ($null -ne $pct) { ('{0}%' -f $pct) } else { '—' }))
            }) | Out-Null
        }
        Add-WCChild $DetailHost $vt
    }
}

function Update-WCM6StabilityDetail {
    param($DetailHost, $Data)
    if ($null -eq $Data) { return }
    $cats = Get-WCM6Field $Data 'Cats'
    $appOk = [bool](Get-WCM6Field $Data 'AppOk')
    if ($null -eq $cats) { return }
    $any = $false
    foreach ($catKey in @('kpower41', 'whea', 'bugcheck', 'diskerr', 'tdr', 'svc', 'appcrash')) {
        $n = 0
        $v = Get-WCM6Field $cats $catKey
        if ($null -ne $v) { $n = [int]$v }
        if ($n -le 0) { continue }
        $any = $true
        $line = New-WCTextBlock -Text ('• ' + (T ('m6.fact.stab.' + $catKey))) -Size 12.5 -Weight 'SemiBold' -Wrap
        Add-WCChild $DetailHost $line
        Add-WCChild $DetailHost (New-WCTextBlock -Text (T ('m6.stab.' + $catKey + '.desc')) -Size 11.5 -ColorKey 'WcSubtle' -Wrap)
        Add-WCChild $DetailHost (New-WCTextBlock -Text ('→ ' + (T ('m6.stab.' + $catKey + '.fix'))) -Size 11.5 -Wrap)
        Add-WCChild $DetailHost (New-WCSpacer -Height 4)
    }
    if (-not $any) {
        Add-WCChild $DetailHost (New-WCTextBlock -Text (T 'm6.stab.none') -Size 12.5 -ColorKey 'WcSubtle' -Wrap)
    }
    if (-not $appOk) {
        Add-WCChild $DetailHost (New-WCTextBlock -Text (T 'm6.fact.stab.applog') -Size 11.5 -ColorKey 'WcSubtle' -Wrap)
    }
}

function Update-WCM6IntegrityDetail {
    param($DetailHost, $Data, $DeepResult)
    if ($null -ne $Data) {
        $dism = Get-WCM6Field $Data 'Dism'
        if ($dism) {
            $dOk = Get-WCM6Field $dism 'Ok'
            $dCode = Get-WCM6Field $dism 'ExitCode'
            $txt = (T 'common.notread')
            if ($dOk) { $txt = [string]$dCode }
            Add-WCChild $DetailHost (New-WCFieldRow -Label (T 'm6.integrity.dism.exit') -Value $txt -NoCopy)
        }
        $sfc = Get-WCM6Field $Data 'Sfc'
        if ($sfc) {
            $sOk = Get-WCM6Field $sfc 'Ok'
            $sCode = Get-WCM6Field $sfc 'ExitCode'
            $txt = (T 'common.notread')
            if ($sOk) { $txt = [string]$sCode }
            Add-WCChild $DetailHost (New-WCFieldRow -Label (T 'm6.integrity.sfc.exit') -Value $txt -NoCopy)
        }
    }
    if ($null -ne $DeepResult) {
        $code = Get-WCM6Field $DeepResult 'ExitCode'
        $when = Get-WCM6Field $DeepResult 'Time'
        $txt = ''
        if ($code -eq 0) { $txt = (T 'm6.integrity.deep.done.ok') }
        else { $txt = (T 'm6.integrity.deep.done.unknown' @([string]$code)) }
        $whenTxt = ''
        try {
            if ($when -is [datetime]) { $whenTxt = $when.ToString('g') } else { $whenTxt = [string]$when }
        } catch { $whenTxt = [string]$when }
        if ($whenTxt) { $txt = $txt + ' (' + (T 'm6.scan.at' @($whenTxt)) + ')' }
        Add-WCChild $DetailHost (New-WCFieldRow -Label (T 'm6.integrity.deep.result') -Value $txt -NoCopy)
    }
}

function Update-WCM6IntegrityDeepNote {
    # Sau khi quet sâu xong: nap lai chi tiet nhom Toan ven (neu da co ket qua)
    param($State)
    $row = $State.Rows['Integrity']
    if (-not $row) { return }
    $row.DetailHost.Children.Clear()
    $data = $null
    if ($State.GroupData.ContainsKey('Integrity')) { $data = $State.GroupData['Integrity'] }
    try {
        Update-WCM6IntegrityDetail $row.DetailHost $data $State.DeepResult
    } catch {
        Write-WCLog 'WARN' ('M6 chi tiet Integrity (deep) loi: ' + $_.Exception.Message)
    }
}

function Update-WCM6SecurityDetail {
    param($DetailHost, $Data)
    if ($null -eq $Data) { return }
    $mode = [string](Get-WCM6Field $Data 'Mode')
    if ($mode -eq 'thirdparty') {
        $av = [string](Get-WCM6Field $Data 'AvName')
        Add-WCChild $DetailHost (New-WCFieldRow -Label (T 'm6.security.av') -Value ($(if ($av) { $av } else { (T 'common.unknown') })) -NoCopy)
        return
    }
    $rt = Get-WCM6Field $Data 'RealTime'
    $rtTxt = '—'
    if ($rt -eq $true) { $rtTxt = (T 'm6.on') }
    elseif ($rt -eq $false) { $rtTxt = (T 'm6.off') }
    Add-WCChild $DetailHost (New-WCFieldRow -Label (T 'm6.security.rtp') -Value $rtTxt -NoCopy)
    $sig = Get-WCM6Field $Data 'SigAgeDays'
    $sigTxt = '—'
    if ($null -ne $sig) { $sigTxt = (T 'fmt.days' @([string]$sig)) }
    Add-WCChild $DetailHost (New-WCFieldRow -Label (T 'm6.security.sigage') -Value $sigTxt -NoCopy)
    $eng = [string](Get-WCM6Field $Data 'Engine')
    if ($eng) {
        Add-WCChild $DetailHost (New-WCFieldRow -Label (T 'm6.security.engine') -Value $eng -NoCopy)
    }
    $tamper = Get-WCM6Field $Data 'Tamper'
    $tamperTxt = '—'
    if ($tamper -eq $true) { $tamperTxt = (T 'm6.on') }
    elseif ($tamper -eq $false) { $tamperTxt = (T 'm6.off') }
    Add-WCChild $DetailHost (New-WCFieldRow -Label (T 'm6.security.tamper') -Value $tamperTxt -NoCopy)
    foreach ($pair in @(@{ L = 'm6.security.lastquick'; V = (Get-WCM6Field $Data 'LastQuick') }, @{ L = 'm6.security.lastfull'; V = (Get-WCM6Field $Data 'LastFull') })) {
        $lq = $pair['V']
        if ($null -eq $lq) { continue }
        $lqTxt = '—'
        try {
            if ($lq -is [datetime]) { $lqTxt = $lq.ToString('g') } else { $lqTxt = [string]$lq }
        } catch { $lqTxt = [string]$lq }
        Add-WCChild $DetailHost (New-WCFieldRow -Label (T $pair['L']) -Value $lqTxt -NoCopy)
    }
}

function Update-WCM6MemoryDetail {
    param($DetailHost, $Data)
    if ($null -eq $Data) { return }
    $cats = Get-WCM6Field $Data 'Cats'
    $wheamem = 0; $diagErr = 0; $diagOk = 0
    if ($cats) {
        $v = Get-WCM6Field $cats 'wheamem'
        if ($null -ne $v) { $wheamem = [int]$v }
        $v = Get-WCM6Field $cats 'memdiagerr'
        if ($null -ne $v) { $diagErr = [int]$v }
        $v = Get-WCM6Field $cats 'memdiagok'
        if ($null -ne $v) { $diagOk = [int]$v }
    }
    Add-WCChild $DetailHost (New-WCFieldRow -Label (T 'm6.memory.wheacount') -Value ([string]$wheamem) -NoCopy)
    $diagTxt = (T 'm6.memory.diag.none')
    if ($diagErr -gt 0) { $diagTxt = (T 'm6.memory.diag.err') }
    elseif ($diagOk -gt 0) { $diagTxt = (T 'm6.memory.diag.ok') }
    Add-WCChild $DetailHost (New-WCFieldRow -Label (T 'm6.memory.diagresult') -Value $diagTxt -NoCopy)
}

function Update-WCM6BatteryDetail {
    param($DetailHost, $Data)
    if ($null -eq $Data) { return }
    $batteries = Get-WCM6Field $Data 'Batteries'
    if ($null -eq $batteries) { return }
    foreach ($b in @($batteries)) {
        $design = Get-WCM6Field $b 'Design'
        $full = Get-WCM6Field $b 'Full'
        $wear = Get-WCM6Field $b 'Wear'
        Add-WCChild $DetailHost (New-WCFieldRow -Label (T 'm6.battery.design') -Value ($(if ($design) { (T 'm6.fmt.mwh' @([string]$design)) } else { '—' })) -NoCopy)
        Add-WCChild $DetailHost (New-WCFieldRow -Label (T 'm6.battery.full') -Value ($(if ($full) { (T 'm6.fmt.mwh' @([string]$full)) } else { '—' })) -NoCopy)
        Add-WCChild $DetailHost (New-WCFieldRow -Label (T 'm6.battery.wear') -Value ($(if ($null -ne $wear) { ('{0}%' -f $wear) } else { '—' })) -NoCopy)
    }
}

# ---------------------------------------------------------------------------
# HANH DONG: quet sau (ScanHealth), sua loi (RestoreHealth/scannow), Memory Diagnostic
# ---------------------------------------------------------------------------
function Invoke-WCM6DeepScan {
    # Nut "Kiem tra sau (DISM ScanHealth)": lau (5-15 phut), chay nen, CO HUY.
    # Quet sau KHONG doi diem (chi la thong tin bo sung, trung thuc).
    param($State)
    if (Test-WCM6Busy) {
        Show-WCToast (T 'm6.busy') 'Info'
        return
    }
    if (-not (Show-WCConfirm -Title (T 'm6.integrity.deep.confirm.title') -Message (T 'm6.integrity.deep.confirm.msg'))) { return }
    $ok = Start-WCTask -Id 'm6.deepscan' -Title (T 'm6.integrity.deep') -ShowStatus -Worker {
        param($ctx, $s)
        $ctx.Progress(3, (T 'm6.integrity.deep.running'))
        $p = $null
        try {
            $p = Start-Process -FilePath 'dism.exe' -ArgumentList '/Online', '/Cleanup-Image', '/ScanHealth' -WindowStyle Hidden -PassThru -ErrorAction Stop
        } catch {
            return @{ Ok = $false; Cancelled = $false; Error = $_.Exception.Message; ExitCode = $null }
        }
        # Vong poll de HUY duoc that (kill dism an toan vi ScanHealth chi quet)
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $expected = 900.0
        while (-not $p.HasExited) {
            if ($ctx.Cancelled()) {
                try { $p.Kill() } catch { }
                return @{ Ok = $true; Cancelled = $true; Error = ''; ExitCode = $null }
            }
            $pct = [int][math]::Min(92, (3 + (($sw.Elapsed.TotalSeconds / $expected) * 89)))
            $ctx.Progress($pct, (T 'm6.integrity.deep.running'))
            Start-Sleep -Seconds 3
        }
        try { $p.WaitForExit() } catch { }
        return @{ Ok = $true; Cancelled = $false; Error = ''; ExitCode = $p.ExitCode }
    } -Done {
        param($r)
        if ($r.Cancelled) {
            Show-WCToast (T 'common.task.cancelled') 'Info'
            return
        }
        if (-not $r.Ok) {
            Show-WCError -Friendly (T 'common.task.failed') -Details $r.Error
            return
        }
        $State.DeepResult = @{ ExitCode = $r.ExitCode; Time = (Get-Date) }
        Update-WCM6IntegrityDeepNote $State
        if ($r.ExitCode -eq 0) {
            Show-WCToast (T 'm6.integrity.deep.done.ok') 'Ok'
        } else {
            Show-WCToast (T 'm6.integrity.deep.done.unknown' @([string]$r.ExitCode)) 'Warn'
        }
    }.GetNewClosure()
    if (-not $ok) { Show-WCToast (T 'm6.busy') 'Info' }
}

function Invoke-WCM6RunMemoryDiagnostic {
    # Chi MO cong cu cua Windows (mdsched.exe), KHONG tu khoi dong lai may
    if (-not (Show-WCConfirm -Title (T 'm6.memory.confirm.title') -Message (T 'm6.memory.confirm.msg'))) { return }
    try {
        Start-Process -FilePath 'mdsched.exe' -ErrorAction Stop
        Show-WCToast (T 'm6.memory.opened') 'Ok'
        Write-WCLog 'INFO' 'M6: da mo Windows Memory Diagnostic (nguoi dung tu quyet dinh khoi dong lai)'
    } catch {
        Show-WCError -Friendly (T 'common.cannotopen') -Details $_.Exception.Message
    }
}

function Invoke-WCM6Repair {
    # Hanh dong NANG CAO: DISM RestoreHealth / SFC scannow (spec M6).
    # Xac nhan -> thu tao diem khoi phuc (that bai se hoi lai, khong lach) ->
    # journal -> chay nen co Huy + uoc tinh thoi gian.
    param($State, [string]$Kind)
    if ($Kind -ne 'dism' -and $Kind -ne 'sfc') { return }
    if (Test-WCM6Busy) {
        Show-WCToast (T 'm6.busy') 'Info'
        return
    }
    $msgKey = 'm6.repair.confirm.msg.' + $Kind
    if (-not (Show-WCConfirm -Title (T 'm6.repair.confirm.title') -Message (T $msgKey) -NotUndoable (T 'm6.repair.noundo'))) { return }
    Invoke-WCM6RepairPhase $State $Kind $false
}

function Invoke-WCM6RepairPhase {
    param($State, [string]$Kind, [bool]$SkipCp)
    $ok = Start-WCTask -Id ('m6.repair.' + $Kind) -Title (T 'm6.repair.running') -ShowStatus -Args @{ Kind = $Kind; SkipCp = $SkipCp } -Worker {
        param($ctx, $s)
        $isDism = ($s.Kind -eq 'dism')
        # Buoc 1: thu tao diem khoi phuc (System Restore co the tat -> bao ro, khong lach)
        if (-not $s.SkipCp) {
            $ctx.Progress(3, (T 'm6.repair.cp.running'))
            $cpErr = ''
            try {
                Checkpoint-Computer -Description 'WinCare M6 - truoc khi sua loi he thong' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
            } catch { $cpErr = $_.Exception.Message }
            if ($cpErr -ne '') { return @{ Phase = 'askcp'; CpError = $cpErr } }
        }
        # Buoc 2: ghi journal truoc khi thay doi he thong (spec 2.4)
        $cmd = 'sfc.exe /scannow'
        $journalAction = (T 'm6.repair.journal.sfc')
        if ($isDism) {
            $cmd = 'DISM /Online /Cleanup-Image /RestoreHealth'
            $journalAction = (T 'm6.repair.journal.dism')
        }
        $entry = Add-WCJournalEntry -Module 'M6' -Action $journalAction -Target 'Windows' -OldValue '' -UndoType ''
        if (Test-WCDryRunMode) {
            Complete-WCJournalEntry -Entry $entry -Result 'DryRun'
            $ctx.Log('[DRY-RUN] se chay: ' + $cmd)
            return @{ Phase = 'done'; DryRun = $true; Ok = $true; Cancelled = $false; ExitCode = 0; Cmd = $cmd }
        }
        # Buoc 3: chay lenh that, poll de Huy duoc
        $ctx.Progress(6, ((T 'm6.repair.running') + ' (' + $cmd + ')'))
        $p = $null
        try {
            if ($isDism) {
                $p = Start-Process -FilePath 'dism.exe' -ArgumentList '/Online', '/Cleanup-Image', '/RestoreHealth' -WindowStyle Hidden -PassThru -ErrorAction Stop
            } else {
                $p = Start-Process -FilePath 'sfc.exe' -ArgumentList '/scannow' -WindowStyle Hidden -PassThru -ErrorAction Stop
            }
        } catch {
            Complete-WCJournalEntry -Entry $entry -Result ('Failed: ' + $_.Exception.Message)
            return @{ Phase = 'done'; DryRun = $false; Ok = $false; Cancelled = $false; Error = $_.Exception.Message; ExitCode = $null; Cmd = $cmd }
        }
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $expected = 1200.0
        if (-not $isDism) { $expected = 600.0 }
        while (-not $p.HasExited) {
            if ($ctx.Cancelled()) {
                try { $p.Kill() } catch { }
                Complete-WCJournalEntry -Entry $entry -Result 'Cancelled'
                return @{ Phase = 'done'; DryRun = $false; Ok = $true; Cancelled = $true; ExitCode = $null; Cmd = $cmd }
            }
            $pct = [int][math]::Min(92, (6 + (($sw.Elapsed.TotalSeconds / $expected) * 86)))
            $ctx.Progress($pct, ((T 'm6.repair.running') + ' — ' + $cmd))
            Start-Sleep -Seconds 3
        }
        try { $p.WaitForExit() } catch { }
        Complete-WCJournalEntry -Entry $entry -Result ('ExitCode ' + $p.ExitCode)
        return @{ Phase = 'done'; DryRun = $false; Ok = $true; Cancelled = $false; ExitCode = $p.ExitCode; Cmd = $cmd }
    } -Done {
        param($r)
        if ($r.Phase -eq 'askcp') {
            # Khong tao duoc restore point -> hoi ro rang, khong tu dong tiep tuc
            $msg = (T 'm6.repair.cp.fail' @($r.CpError))
            if (Show-WCConfirm -Title (T 'm6.repair.cp.ask.title') -Message ($msg + "`n`n" + (T 'm6.repair.cp.ask.msg'))) {
                Invoke-WCM6RepairPhase $State $Kind $true
            } else {
                Show-WCToast (T 'common.cancel') 'Info'
                Write-WCLog 'INFO' 'M6: nguoi dung tu choi sua loi khi khong co diem khoi phuc'
            }
            return
        }
        if ($r.DryRun) {
            Show-WCToast (T 'common.dryrun.header') 'Info'
            return
        }
        if ($r.Cancelled) {
            Show-WCToast (T 'm6.repair.cancelled') 'Info'
            return
        }
        if (-not $r.Ok) {
            Show-WCError -Friendly (T 'common.task.failed') -Details $r.Error
            return
        }
        if ($r.ExitCode -eq 0) {
            Show-WCToast (T 'm6.repair.done.ok') 'Ok'
        } else {
            Show-WCToast (T 'm6.repair.done.unknown' @([string]$r.ExitCode)) 'Warn'
        }
    }.GetNewClosure()
    if (-not $ok) { Show-WCToast (T 'm6.busy') 'Info' }
}

# ---------------------------------------------------------------------------
# UI CHINH
# ---------------------------------------------------------------------------
function New-WCM6AdvancedSection {
    # Muc NANG CAO: sua loi he thong (DISM RestoreHealth / SFC scannow)
    param($State)
    $sec = New-WCSection -Title (T 'm6.repair.title') -Subtitle (T 'm6.repair.subtitle')
    $risk = Get-WCRiskInfo 'Advanced'
    $chip = New-WCChip -Text $risk.Text -Kind 'Warn'
    $chip.HorizontalAlignment = [Windows.HorizontalAlignment]::Left
    Add-WCChild $sec.Body $chip
    Add-WCChild $sec.Body (New-WCTextBlock -Text $risk.Hint -Size 11.5 -ColorKey 'WcSubtle' -Wrap)
    # DISM RestoreHealth
    $row1 = New-WCHStack -Spacing 10
    $b1 = New-WCButton -Text (T 'm6.repair.dism') -OnClick { param($b) Invoke-WCM6Repair $State 'dism' }.GetNewClosure()
    $b1.VerticalAlignment = [Windows.VerticalAlignment]::Center
    Add-WCChild $row1 $b1
    $t1 = New-WCTextBlock -Text (T 'm6.repair.dism.eta') -Size 12 -ColorKey 'WcSubtle' -Wrap
    $t1.VerticalAlignment = [Windows.VerticalAlignment]::Center
    Add-WCChild $row1 $t1
    Add-WCChild $sec.Body $row1
    # SFC /scannow
    $row2 = New-WCHStack -Spacing 10
    $b2 = New-WCButton -Text (T 'm6.repair.sfc') -OnClick { param($b) Invoke-WCM6Repair $State 'sfc' }.GetNewClosure()
    $b2.VerticalAlignment = [Windows.VerticalAlignment]::Center
    Add-WCChild $row2 $b2
    $t2 = New-WCTextBlock -Text (T 'm6.repair.sfc.eta') -Size 12 -ColorKey 'WcSubtle' -Wrap
    $t2.VerticalAlignment = [Windows.VerticalAlignment]::Center
    Add-WCChild $row2 $t2
    Add-WCChild $sec.Body $row2
    # Che do chuyen gia: hien dung lenh se chay
    Add-WCChild $sec.Body (New-WCExpertLine -Command 'DISM /Online /Cleanup-Image /RestoreHealth')
    Add-WCChild $sec.Body (New-WCExpertLine -Command 'sfc.exe /scannow')
    return $sec
}

function New-WCM6Panel {
    param($State)
    $root = New-Object Windows.Controls.ScrollViewer
    $root.VerticalScrollBarVisibility = [Windows.Controls.ScrollBarVisibility]::Auto
    $hostPanel = New-WCVStack -Spacing 14
    $hostPanel.Margin = (New-Object Windows.Thickness(20))
    $root.Content = $hostPanel

    # Tieu de + chip Beta (trung thuc: chua kiem chung runtime tren Windows that)
    $titleRow = New-WCHStack
    $titleRow.Children.Add((New-WCHeading (T 'm6.title'))) | Out-Null
    $betaChip = New-WCChip -Text (T 'common.beta') -Kind 'Warn'
    $betaChip.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $titleRow.Children.Add($betaChip) | Out-Null
    Add-WCChild $hostPanel $titleRow
    Add-WCChild $hostPanel (New-WCSubtitle (T 'm6.subtitle'))

    # Muc diem: diem to + dai cham chu + cong thuc minh bach + thoi diem quet
    $scoreSec = New-WCSection -Title (T 'm6.score')
    $scoreRow = New-WCHStack -Spacing 16
    $scoreText = New-WCTextBlock -Text '—' -Size 42 -Weight 'SemiBold'
    $scoreRow.Children.Add($scoreText) | Out-Null
    $bandBox = New-WCVStack -Spacing 2
    $bandText = New-WCTextBlock -Text (T 'm6.status.scanning') -Size 14 -Weight 'SemiBold'
    Add-WCChild $bandBox $bandText
    $pendingText = New-WCTextBlock -Text '' -Size 12 -ColorKey 'WcSubtle'
    Add-WCChild $bandBox $pendingText
    $bandBox.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $scoreRow.Children.Add($bandBox) | Out-Null
    Add-WCChild $scoreSec.Body $scoreRow
    Add-WCChild $scoreSec.Body (New-WCTextBlock -Text (T 'm6.score.howto') -Size 11.5 -ColorKey 'WcSubtle' -Wrap)
    $renormNote = New-WCTextBlock -Text '' -Size 12 -Wrap
    $renormNote.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'WcWarn')
    $renormNote.TextWrapping = [Windows.TextWrapping]::Wrap
    $renormNote.Visibility = [Windows.Visibility]::Collapsed
    Add-WCChild $scoreSec.Body $renormNote
    $capNote = New-WCTextBlock -Text '' -Size 12 -Wrap
    $capNote.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'WcBad')
    $capNote.TextWrapping = [Windows.TextWrapping]::Wrap
    $capNote.Visibility = [Windows.Visibility]::Collapsed
    Add-WCChild $scoreSec.Body $capNote
    $scanRow = New-WCHStack -Spacing 12
    $scanLabel = New-WCTextBlock -Text '' -Size 12.5 -ColorKey 'WcSubtle'
    $scanLabel.VerticalAlignment = [Windows.VerticalAlignment]::Center
    Add-WCChild $scanRow $scanLabel
    $rescanBtn = New-WCButton -Text (T 'common.rescan') -Kind Primary -OnClick {
        param($b)
        Invoke-WCM6Rescan $State
    }.GetNewClosure()
    $rescanBtn.VerticalAlignment = [Windows.VerticalAlignment]::Center
    Add-WCChild $scanRow $rescanBtn
    Add-WCChild $scoreSec.Body $scanRow
    Add-WCChild $hostPanel $scoreSec.Root

    # Bang phan ra: Nhom | Trong so | Diem | Tai sao | Nen lam gi
    $brkSec = New-WCSection -Title (T 'm6.breakdown.title') -Subtitle (T 'm6.breakdown.sub')
    $hdr = New-WCM6FiveColGrid
    $labels = @((T 'm6.col.group'), (T 'm6.col.weight'), (T 'm6.col.score'), (T 'm6.col.why'), (T 'm6.col.what'))
    $i = 0
    foreach ($lbl in $labels) {
        $t = New-WCTextBlock -Text $lbl -Size 11.5 -ColorKey 'WcSubtle'
        [Windows.Controls.Grid]::SetColumn($t, $i)
        $hdr.Children.Add($t) | Out-Null
        $i++
    }
    Add-WCChild $brkSec.Body $hdr
    $weights = @{ Storage = 25; Stability = 25; Integrity = 15; Security = 15; Memory = 10; Battery = 10 }
    foreach ($k in (Get-WCM6GroupKeys)) {
        $row = New-WCM6GroupRow $State $k $weights[$k]
        Add-WCChild $brkSec.Body $row.Card
    }
    Add-WCChild $hostPanel $brkSec.Root

    # Muc nang cao: sua loi he thong
    $advSec = New-WCM6AdvancedSection $State
    Add-WCChild $hostPanel $advSec.Root

    # Luu tham chieu dieu khien vao State
    $State.ScoreText = $scoreText
    $State.BandText = $bandText
    $State.PendingText = $pendingText
    $State.RenormNote = $renormNote
    $State.CapNote = $capNote
    $State.ScanLabel = $scanLabel
    return $root
}

# ---------------------------------------------------------------------------
# KHOI TAO MODULE (goi 1 lan khi nap app)
# ---------------------------------------------------------------------------
function Initialize-WCModuleM6 {
    $state = @{
        Groups = @{}          # Key -> @{ Status; Score; Severe; Reason }
        GroupData = @{}       # Key -> du lieu tho de ve chi tiet
        Rows = @{}            # Key -> cac phan tu UI cua dong nhom
        ScanTime = $null
        DeepResult = $null    # Ket qua quet sau gan nhat (nguoi dung tu bam)
        Scanned = $false
        ScoreText = $null; BandText = $null; PendingText = $null
        RenormNote = $null; CapNote = $null; ScanLabel = $null
    }
    Register-WCNavItem -Key 'm6' -Badge 'M6' -Title (T 'm6.title') -Order 70 -Builder {
        New-WCM6Panel $state
    }.GetNewClosure() -OnShow {
        # Lan dau mo muc: tu quet (chi doc). cac lan sau giu ket qua cu + nut Quet lai
        if (-not $state.Scanned) {
            $state.Scanned = $true
            Invoke-WCM6RunScan $state $false
        }
    }.GetNewClosure()
}


# ============================================================================
# REGION: 18-M7-Aging.ps1
# ============================================================================

# ============================================================================
#  src/18-M7-Aging.ps1 - Module M7: DO "LAO HOA" MAY (spec M7)
#  Muc tieu: tra loi "may nay co dang tich tu rac/cham dan khong?" bang
#  BANG CHUNG DO DUOC (so lieu + nguon), khong phan cam tinh.
#  May moi cai phai ra ket qua "binh thuong" ma KHONG doa nguoi dung.
#  Moi chi bao 1 section rieng, du lieu ve dan qua task nen tung phan.
# ============================================================================

Register-WCStrings 'vi' @{
    'm7.title' = 'Độ "lão hóa" máy'
    'm7.subtitle' = 'Máy có đang tích tụ rác / chậm dần không? — trả lời bằng bằng chứng đo được, không phán cảm tính'
    'm7.fact' = '"Windows dùng lâu là chậm" không phải quy luật. WinCare chỉ kết luận từ số liệu đo được và ghi rõ nguồn từng chỉ báo. Máy mới cài sẽ thấy kết quả "bình thường" — không dọa.'
    # -- Ket luan -------------------------------------------------------------
    'm7.verdict.title' = 'Kết luận: Độ lão hóa'
    'm7.verdict.subtitle' = 'Chỉ dựa trên số liệu đo được — bảng bằng chứng kèm theo từng chỉ báo'
    'm7.verdict.waiting' = 'Đang thu thập bằng chứng từ 7 nguồn…'
    'm7.verdict.fresh' = 'Mới / Như mới'
    'm7.verdict.good' = 'Được chăm sóc tốt'
    'm7.verdict.light' = 'Có tích tụ nhẹ'
    'm7.verdict.heavy' = 'Tích tụ nhiều'
    'm7.verdict.fresh.sum' = 'Windows được cài cách đây {0} và chưa có dấu hiệu tích tụ rõ ràng — đây là kết quả bình thường cho máy mới, không cần làm gì.'
    'm7.verdict.good.sum' = 'Máy đã dùng {0} nhưng chưa có dấu hiệu tích tụ rõ ràng — tuổi bản thân không làm Windows chậm, không cần lo.'
    'm7.verdict.light.sum' = 'Có dấu hiệu tích tụ nhẹ (xem bảng bằng chứng bên dưới). Nên bắt đầu từ hướng KHUYẾN NGHỊ ở cuối trang.'
    'm7.verdict.heavy.sum' = 'Phát hiện {0} dấu hiệu nặng và {1} dấu hiệu nhẹ cùng lúc — xem bảng bằng chứng để biết rõ từng mục đo được.'
    'm7.verdict.evidence' = 'Bảng bằng chứng'
    # -- Bang bang chung: cot + ten chi bao ----------------------------------
    'm7.col.indicator' = 'Chỉ báo'
    'm7.col.value' = 'Số liệu'
    'm7.col.source' = 'Nguồn'
    'm7.col.meaning' = 'Ý nghĩa'
    'm7.ev.age' = 'Tuổi cài đặt'
    'm7.ev.age.mean' = 'Chỉ là bối cảnh — trọng số rất nhỏ'
    'm7.ev.boot' = 'Xu hướng khởi động'
    'm7.ev.boot.up' = '+{0}% (trung vị 30 ngày so với 90 ngày)'
    'm7.ev.boot.down' = '{0}% (30 ngày nhanh hơn 90 ngày)'
    'm7.ev.boot.flat' = 'ổn định ({0}%)'
    'm7.ev.boot.mean.sign' = 'Khởi động chậm dần theo thời gian'
    'm7.ev.boot.mean.ok' = 'Thời gian khởi động không tăng'
    'm7.ev.startup' = 'Mục khởi động ngoài Microsoft'
    'm7.ev.startup.value' = '{0} mục ({1} đang bật)'
    'm7.ev.startup.mean.sign' = 'Nhiều chương trình đón lúc đăng nhập'
    'm7.ev.startup.mean.ok' = 'Mức bình thường'
    'm7.ev.bloat' = 'Ứng viên OEM/bloatware'
    'm7.ev.bloat.mean' = 'Phần mềm lắp sẵn ít dùng — gỡ qua trình gỡ chính thức'
    'm7.ev.residual' = 'Thư mục "CÓ THỂ là tàn dư"'
    'm7.ev.residual.value' = '{0} thư mục, {1}'
    'm7.ev.residual.mean' = 'Chiếm chỗ nhưng dễ báo nhầm — kiểm tra trước khi xóa'
    'm7.ev.games' = 'Game lâu không chơi (>180 ngày)'
    'm7.ev.games.value' = '{0} game, {1}'
    'm7.ev.games.mean' = 'Không phải "rác hệ thống" — chỉ là chỗ chiếm disk, gỡ qua launcher'
    'm7.ev.disk' = 'Ổ hệ thống còn trống'
    'm7.ev.disk.mean.low' = 'Không gian quá thấp ảnh hưởng trực tiếp hiệu năng'
    'm7.ev.disk.mean.ok' = 'Còn thoải mái'
    'm7.ev.pending' = 'Cờ chờ khởi động lại'
    'm7.ev.pending.mean' = 'Bản cập nhật chưa hoàn tất — nên khởi động lại'
    'm7.ev.bsod' = 'BSOD (90 ngày)'
    'm7.ev.bsod.mean' = 'Lỗi hệ thống lặp lại cần xem xét (xem M5)'
    'm7.src.registry' = 'Registry InstallDate'
    'm7.src.event100' = 'Sự kiện ID 100 (Diagnostics-Performance)'
    'm7.src.runkeys' = 'Run keys + Startup + Task Scheduler + services'
    'm7.src.uninstall' = 'Khóa Uninstall (HKLM 64/32 + HKCU)'
    'm7.src.folders' = 'Program Files / ProgramData / Local'
    'm7.src.manifest' = 'Steam/Epic manifest (thư mục cài)'
    'm7.src.logicaldisk' = 'Win32_LogicalDisk (ổ hệ thống)'
    'm7.src.rebootkeys' = 'CBS / WindowsUpdate / Session Manager'
    'm7.src.system1001' = 'Sự kiện System 1001 (BugCheck)'
    # -- Tuoi cai dat ---------------------------------------------------------
    'm7.age.title' = 'Tuổi cài đặt'
    'm7.age.hint' = 'Đọc từ registry — InstallDate là số giây Unix'
    'm7.age.value' = 'Windows được cài ngày {0} — cách đây {1}'
    'm7.age.unknown' = 'Không đọc được ngày cài đặt từ registry.'
    'm7.age.note' = 'Tuổi đơn thuần có trọng số RẤT NHỎ trong kết luận: Windows dùng lâu không tự nhiên chậm, chậm là do các yếu tố đo được bên dưới.'
    # -- Xu huong khoi dong ---------------------------------------------------
    'm7.boot.title' = 'Xu hướng thời gian khởi động'
    'm7.boot.hint' = 'Trung vị 30 ngày gần nhất so với 90/180 ngày — nguồn: sự kiện ID 100 (MainPathBootTime + BootPostBootTime)'
    'm7.boot.nodata' = 'Không đủ dữ liệu (log bị giới hạn/xóa, hoặc chưa đủ lần khởi động được đo).'
    'm7.boot.bucket.30' = '30 ngày gần nhất'
    'm7.boot.bucket.90' = '90 ngày gần nhất'
    'm7.boot.bucket.180' = '180 ngày gần nhất'
    'm7.boot.col.bucket' = 'Khoảng thời gian'
    'm7.boot.col.count' = 'Số lần khởi động'
    'm7.boot.col.median' = 'Trung vị (ms)'
    'm7.boot.col.max' = 'Chậm nhất (ms)'
    'm7.boot.count' = '{0} lần khởi động có đo được trong 180 ngày gần nhất.'
    'm7.boot.up' = '30 ngày gần nhất chậm hơn {0}% so với trung vị 90 ngày ({1} → {2} ms).'
    'm7.boot.down' = '30 ngày gần nhất NHANH hơn {0}% so với trung vị 90 ngày ({1} → {2} ms) — máy không chậm dần.'
    'm7.boot.flat' = 'Thời gian khởi động ổn định (thay đổi {0}% giữa trung vị 30 và 90 ngày).'
    'm7.boot.compare.nodata' = 'Chưa đủ lần khởi động để so sánh xu hướng (cần ≥ 3 lần trong 30 ngày và ≥ 5 lần trong 90 ngày).'
    'm7.boot.recent' = 'Lần khởi động gần đây (cũ → mới, chiều cao khối ~ thời gian khởi động):'
    'm7.boot.source' = 'Nguồn: sự kiện ID 100 — MainPathBootTime + BootPostBootTime (ms), đọc qua thuộc tính sự kiện (không parse thông điệp).'
    # -- Muc khoi dong --------------------------------------------------------
    'm7.startup.title' = 'Mục khởi động'
    'm7.startup.hint' = 'Gộp Run keys (HKLM/HKCU + WOW6432Node), thư mục Startup, tác vụ đăng nhập/khởi động, dịch vụ Auto — ngoài Microsoft'
    'm7.startup.count' = '{0} mục khởi động ngoài Microsoft ({1} đang bật).'
    'm7.startup.mscount' = '{0} mục thuộc Windows (tham khảo, thường để nguyên).'
    'm7.startup.empty' = 'Không có mục khởi động ngoài Microsoft — rất gọn.'
    'm7.startup.on' = 'BẬT'
    'm7.startup.off' = 'TẮT'
    'm7.startup.msbadge' = 'Windows'
    'm7.startup.toggle.off' = 'Tắt mục đã chọn'
    'm7.startup.toggle.on' = 'Bật lại mục đã chọn'
    'm7.startup.confirm.title' = 'Đổi trạng thái mục khởi động'
    'm7.startup.confirm.off' = 'Sẽ TẮT các mục khởi động sau (chỉ đổi trạng thái như Task Manager — KHÔNG xóa lệnh gốc, KHÔNG gỡ phần mềm):'
    'm7.startup.confirm.on' = 'Sẽ BẬT lại các mục khởi động sau:'
    'm7.startup.confirm.undo' = 'Bật lại được ngay bằng nút "Bật lại mục đã chọn" hoặc Hoàn tác trong Lịch sử.'
    'm7.startup.confirm.noundo' = 'Mục bị tắt sẽ không chạy khi đăng nhập cho đến khi bạn bật lại (phần mềm vẫn còn, không mất dữ liệu).'
    'm7.startup.journal.off' = 'Tắt mục khởi động'
    'm7.startup.journal.on' = 'Bật lại mục khởi động'
    'm7.startup.decode.note' = 'Trạng thái BẬT/TẮT giải mã từ giá trị StartupApproved (cơ chế Task Manager dùng) — cách giải mã phổ biến, chưa kiểm chứng trên mọi máy.'
    'm7.startup.tasks.title' = 'Tác vụ & dịch vụ tự chạy (ngoài Microsoft)'
    'm7.startup.tasks.summary' = '{0} tác vụ, {1} dịch vụ — chỉ liệt kê'
    'm7.startup.tasks.hint' = 'Tác vụ và dịch vụ không bật/tắt bằng cơ chế StartupApproved — quản lý bằng Task Scheduler / services.msc. WinCare chỉ báo cáo để bạn biết có gì đang đón cùng Windows.'
    'm7.startup.col.name' = 'Tên'
    'm7.startup.col.type' = 'Loại'
    'm7.startup.col.state' = 'Trạng thái'
    'm7.startup.type.task' = 'Tác vụ'
    'm7.startup.type.service' = 'Dịch vụ'
    'm7.startup.result' = 'Đã đổi {0} mục, {1} lỗi.'
    'm7.startup.more' = '… và {0} mục khác'
    # -- Phan mem -------------------------------------------------------------
    'm7.software.title' = 'Phần mềm đã cài'
    'm7.software.hint' = 'Đếm từ khóa Uninstall (HKLM 64/32-bit + HKCU) — không quét lớp WMI "sản phẩm" của Windows (vì nó kích hoạt MSI tự sửa)'
    'm7.software.count' = '{0} chương trình đang cài.'
    'm7.software.bloat.title' = 'Ứng viên OEM / bloatware (chỉ ĐỀ XUẤT — bạn tự quyết định)'
    'm7.software.bloat.hint' = 'Khớp tên với danh sách phần mềm lắp sẵn phổ biến. Nút "Gỡ" chỉ mở trình gỡ CHÍNH THỨC của phần mềm — không tự xóa.'
    'm7.software.bloat.empty' = 'Không phát hiện ứng viên bloatware phổ biến.'
    'm7.software.uninstall' = 'Gỡ'
    'm7.software.installedon' = 'Cài: {0}'
    'm7.software.uninstall.confirm.title' = 'Mở trình gỡ phần mềm?'
    'm7.software.uninstall.confirm.msg' = 'Sẽ mở trình gỡ chính thức của "{0}" và chạy lệnh:{1}{2}{3}Bạn sẽ tự xác nhận thêm trong trình gỡ của phần mềm.'
    'm7.software.uninstall.confirm.noundo' = 'Việc gỡ do trình gỡ của phần mềm thực hiện — WinCare không thể hoàn tác giúp bạn.'
    'm7.software.uninstall.running' = 'Đã mở trình gỡ của "{0}".'
    'm7.software.uninstall.fail' = 'Không mở được trình gỡ'
    'm7.software.uninstall.nostring' = 'Phần mềm này không có lệnh gỡ trong registry.'
    'm7.software.journal' = 'Mở trình gỡ chính thức'
    # -- Tan du ---------------------------------------------------------------
    'm7.residual.title' = 'Thư mục "CÓ THỂ là tàn dư"'
    'm7.residual.hint' = 'Thư mục trong Program Files / Program Files (x86) / ProgramData / Local\Programs không khớp phần mềm đang cài — nhãn "CÓ THỂ" vì rất dễ báo nhầm'
    'm7.residual.empty' = 'Không phát hiện thư mục mồ côi đáng chú ý.'
    'm7.residual.open' = 'Mở vị trí (mục đã chọn)'
    'm7.residual.delete' = 'Chuyển Thùng rác (mục đã chọn)'
    'm7.residual.delete.confirm.title' = 'Chuyển thư mục vào Thùng rác?'
    'm7.residual.delete.confirm.msg' = 'Các thư mục sau sẽ được chuyển vào THÙNG RÁC (không xóa vĩnh viễn):'
    'm7.residual.delete.confirm.noundo' = 'WinCare không tự hoàn tác việc này — khôi phục bằng cách kéo thư mục từ Thùng rác về chỗ cũ.'
    'm7.residual.journal' = 'Chuyển Thùng rác (tàn dư)'
    'm7.residual.orphan.title' = 'Mục Uninstall mồ côi trong registry (CHỈ báo cáo)'
    'm7.residual.orphan.hint' = 'Khóa Uninstall không có DisplayName — thường là dấu vết gỡ cài đặt. WinCare không tự xóa; chỉ giúp bạn biết có tồn tại.'
    'm7.residual.orphan.empty' = 'Không có mục Uninstall mồ côi.'
    'm7.residual.more' = '… và {0} thư mục khác'
    'm7.residual.result' = 'Đã chuyển {0} thư mục vào Thùng rác, {1} lỗi/bỏ qua.'
    # -- Game -----------------------------------------------------------------
    'm7.games.title' = 'Game & launcher'
    'm7.games.hint' = 'Steam (libraryfolders.vdf + appmanifest), Epic (Manifests .item), game khác qua khóa Uninstall'
    'm7.games.steam.none' = 'Không phát hiện Steam.'
    'm7.games.steam.ok' = 'Steam: {0} thư viện, {1} game.'
    'm7.games.epic.none' = 'Không phát hiện Epic Games Launcher.'
    'm7.games.epic.ok' = 'Epic Games Launcher: {0} game.'
    'm7.games.col.name' = 'Game'
    'm7.games.col.source' = 'Nguồn'
    'm7.games.col.size' = 'Dung lượng'
    'm7.games.col.last' = 'Chơi lần cuối'
    'm7.games.col.drive' = 'Ổ'
    'm7.games.source.other' = 'Khác (Uninstall)'
    'm7.games.last.unknown' = 'Chưa rõ'
    'm7.games.old.total' = '• {0} game lâu không chơi (>180 ngày) — tổng {1}. Gỡ/chuyển qua launcher để giải phóng chỗ.'
    'm7.games.hdd' = '• Game đặt trên ổ HDD (nên cân nhắc chuyển sang SSD để giảm thời gian load): {0}'
    'm7.games.launcher' = '• Launcher game tự chạy cùng Windows: {0} — xem mục Khởi động phía trên để tắt nếu không cần.'
    'm7.games.shader' = '• Bộ nhớ đệm shader: D3DSCache {0} + NVIDIA GLCache {1} — dọn ở M2 (Dọn ổ đĩa), sẽ tự dựng lại.'
    'm7.games.gpu.old' = '• Driver GPU "{0}" đã {1} ngày (> 1 năm) — xem M3 (Driver) để cập nhật.'
    'm7.games.gpu.ok' = '• Driver GPU "{0}" cập nhật cách đây {1} ngày — ổn.'
    'm7.games.open.steam' = 'Mở Steam'
    'm7.games.open.epic' = 'Mở Epic'
    'm7.games.open.fail' = 'Không mở được launcher.'
    'm7.games.uninstall.note' = 'Gỡ/chuyển game CHỈ qua Steam/Epic — không xóa tay thư mục game (dễ hỏng launcher).'
    'm7.games.empty' = 'Không phát hiện game qua Steam / Epic / khóa Uninstall.'
    'm7.games.more' = '… và {0} game khác'
    # -- Tich tu he thong -----------------------------------------------------
    'm7.sys.title' = 'Tích tụ hệ thống'
    'm7.sys.hint' = 'Cập nhật đang chờ, lần bảo trì tự động gần nhất, ổ hệ thống, BSOD gần đây'
    'm7.sys.pending.ok' = '• Không có cờ chờ khởi động lại — cập nhật đã hoàn tất.'
    'm7.sys.pending.list' = '• Cờ chờ khởi động lại: {0} — có bản cập nhật chưa hoàn tất, nên khởi động lại máy.'
    'm7.sys.maintenance.label' = '• Lần bảo trì tự động (Automatic Maintenance) gần nhất: {0} ({1}).'
    'm7.sys.maintenance.none' = '• Không đủ dữ liệu về lần bảo trì tự động gần nhất.'
    'm7.sys.disk' = '• Ổ hệ thống còn trống: {0}%'
    'm7.sys.bsod.none' = '• BSOD 90 ngày gần nhất: 0 lần.'
    'm7.sys.bsod.some' = '• BSOD 90 ngày gần nhất: {0} lần — xem chi tiết ở M5 (Ổn định & Toàn vẹn).'
    'm7.sys.bsod.nodata' = '• BSOD 90 ngày gần nhất: không đọc được nhật ký.'
    # -- Huong xu ly ----------------------------------------------------------
    'm7.actions.title' = 'Hướng xử lý (rủi ro tăng dần)'
    'm7.actions.hint' = 'Làm theo thứ tự — chỉ làm gì bạn hiểu và đã xác nhận'
    'm7.actions.waiting' = 'Sẽ hiện sau khi quét xong.'
    'm7.actions.1.title' = 'Dọn mục tiêu'
    'm7.actions.1.desc' = 'Chạy M2 (Dọn ổ đĩa) cho các mục cache/tạm an toàn, và tắt bớt mục khởi động không cần ở phần "Mục khởi động" phía trên.'
    'm7.actions.1.btn' = 'Mở M2 — Dọn ổ đĩa'
    'm7.actions.2.title' = 'Gỡ/tắt phần mềm, chuyển game'
    'm7.actions.2.desc' = 'Gỡ bloatware bằng trình gỡ chính thức (mục Phần mềm), chuyển game từ HDD sang SSD qua Steam/Epic (mục Game). Không xóa tay thư mục game.'
    'm7.actions.3.title' = 'Cài lại Windows / Reset this PC (giữ tệp)'
    'm7.actions.3.desc' = 'Chỉ cân nhắc khi các hướng trên không giải quyết được. Đây là quyết định của bạn — WinCare KHÔNG tự động hóa bước này.'
    'm7.actions.3.notneeded' = 'Chưa có cơ sở đề xuất cài lại Windows: cần ít nhất 3 dấu hiệu khách quan cùng lúc (hiện phát hiện {0}/{1}).'
    'm7.actions.3.criteria' = 'Các dấu hiệu khách quan đang thỏa:'
    'm7.actions.3.sign.boot' = '• Thời gian khởi động tăng hơn 50% (trung vị 30 ngày so với 90 ngày)'
    'm7.actions.3.sign.startup' = '• Hơn 15 mục khởi động ngoài Microsoft'
    'm7.actions.3.sign.disk' = '• Ổ hệ thống còn dưới 10% chỗ trống'
    'm7.actions.3.sign.bsod' = '• Từ 3 lần BSOD trong 90 ngày'
    'm7.actions.3.checklist.title' = 'Checklist sao lưu TRƯỚC khi cài lại:'
    'm7.actions.3.checklist.1' = '• Tài liệu, ảnh, video — kiểm tra cả Desktop, Downloads, thư mục ngoài ổ C'
    'm7.actions.3.checklist.2' = '• Dữ liệu trình duyệt: đăng nhập đồng bộ tài khoản, hoặc xuất bookmark/mật khẩu'
    'm7.actions.3.checklist.3' = '• Key/giấy phép phần mềm (Office, bản quyền…) — ghi lại để kích hoạt lại'
    'm7.actions.3.checklist.4' = '• Driver đã xuất ở M3 (dùng khi Windows thiếu driver sau cài)'
    'm7.actions.3.checklist.5' = '• Xác nhận Windows gắn với tài khoản Microsoft (để tự kích hoạt lại)'
    'm7.actions.3.checklist.6' = '• Danh sách phần mềm đang dùng — xem lại mục "Phần mềm đã cài" phía trên'
    'm7.actions.3.guide.title' = 'Hướng dẫn (bạn tự thao tác):'
    'm7.actions.3.guide.1' = '• Cách 1: Settings → System → Recovery → Reset this PC → "Keep my files" (giữ tệp cá nhân, cài lại Windows).'
    'm7.actions.3.guide.2' = '• Cách 2: tạo USB cài bằng Media Creation Tool từ microsoft.com rồi cài đè (sao lưu trước như checklist).'
    'm7.actions.3.note' = 'WinCare không thực hiện các bước này thay bạn — mọi thao tác cài lại thuộc về bạn.'
    'm7.nodata.reason' = 'Không đủ dữ liệu: {0}'
}
Register-WCStrings 'en' @{
    'm7.title' = 'PC "aging" check'
    'm7.subtitle' = 'Is this PC piling up junk / slowing down? — answered with measurable evidence, no guesswork'
    'm7.fact' = '"Old Windows is slow" is not a law. WinCare only concludes from measured data and names the source of every indicator. A fresh install will read "normal" — no scare tactics.'
    'm7.verdict.title' = 'Verdict: Aging level'
    'm7.verdict.subtitle' = 'Based only on measured data — evidence table attached per indicator'
    'm7.verdict.waiting' = 'Collecting evidence from 7 sources…'
    'm7.verdict.fresh' = 'New / Like new'
    'm7.verdict.good' = 'Well maintained'
    'm7.verdict.light' = 'Light buildup'
    'm7.verdict.heavy' = 'Heavy buildup'
    'm7.verdict.fresh.sum' = 'Windows was installed {0} ago with no clear buildup signs — a perfectly normal result for a new PC, nothing to do.'
    'm7.verdict.good.sum' = 'The PC has been used {0} but shows no clear buildup — age alone does not slow Windows down.'
    'm7.verdict.light.sum' = 'There are mild buildup signs (see evidence table below). Start with the RECOMMENDED direction at the bottom.'
    'm7.verdict.heavy.sum' = 'Found {0} severe and {1} mild signs at once — see the evidence table for each measured item.'
    'm7.verdict.evidence' = 'Evidence table'
    'm7.col.indicator' = 'Indicator'
    'm7.col.value' = 'Value'
    'm7.col.source' = 'Source'
    'm7.col.meaning' = 'Meaning'
    'm7.ev.age' = 'Install age'
    'm7.ev.age.mean' = 'Context only — very small weight'
    'm7.ev.boot' = 'Boot time trend'
    'm7.ev.boot.up' = '+{0}% (30-day median vs 90-day)'
    'm7.ev.boot.down' = '{0}% (30 days faster than 90 days)'
    'm7.ev.boot.flat' = 'stable ({0}%)'
    'm7.ev.boot.mean.sign' = 'Boot is getting slower over time'
    'm7.ev.boot.mean.ok' = 'Boot time is not increasing'
    'm7.ev.startup' = 'Non-Microsoft startup items'
    'm7.ev.startup.value' = '{0} items ({1} enabled)'
    'm7.ev.startup.mean.sign' = 'Many programs hook logon'
    'm7.ev.startup.mean.ok' = 'Normal level'
    'm7.ev.bloat' = 'OEM/bloatware candidates'
    'm7.ev.bloat.mean' = 'Preinstalled software rarely used — uninstall via its own uninstaller'
    'm7.ev.residual' = '"POSSIBLY leftover" folders'
    'm7.ev.residual.value' = '{0} folders, {1}'
    'm7.ev.residual.mean' = 'Wastes space but easy to misjudge — verify before deleting'
    'm7.ev.games' = 'Games not played >180 days'
    'm7.ev.games.value' = '{0} games, {1}'
    'm7.ev.games.mean' = 'Not "system junk" — just disk space; uninstall via launcher'
    'm7.ev.disk' = 'System drive free space'
    'm7.ev.disk.mean.low' = 'Very low space directly hurts performance'
    'm7.ev.disk.mean.ok' = 'Comfortable'
    'm7.ev.pending' = 'Pending reboot flags'
    'm7.ev.pending.mean' = 'Updates not finalized — consider restarting'
    'm7.ev.bsod' = 'BSODs (90 days)'
    'm7.ev.bsod.mean' = 'Repeated system crashes — see M5'
    'm7.src.registry' = 'Registry InstallDate'
    'm7.src.event100' = 'Event ID 100 (Diagnostics-Performance)'
    'm7.src.runkeys' = 'Run keys + Startup + Task Scheduler + services'
    'm7.src.uninstall' = 'Uninstall keys (HKLM 64/32 + HKCU)'
    'm7.src.folders' = 'Program Files / ProgramData / Local'
    'm7.src.manifest' = 'Steam/Epic manifests (install folders)'
    'm7.src.logicaldisk' = 'Win32_LogicalDisk (system drive)'
    'm7.src.rebootkeys' = 'CBS / WindowsUpdate / Session Manager'
    'm7.src.system1001' = 'System event 1001 (BugCheck)'
    'm7.age.title' = 'Install age'
    'm7.age.hint' = 'Read from registry — InstallDate is Unix seconds'
    'm7.age.value' = 'Windows was installed on {0} — {1} ago'
    'm7.age.unknown' = 'Could not read install date from registry.'
    'm7.age.note' = 'Age alone carries a VERY SMALL weight in the verdict: an old Windows is not automatically slow — slowness comes from the measurable factors below.'
    'm7.boot.title' = 'Boot time trend'
    'm7.boot.hint' = 'Median of last 30 days vs 90/180 days — source: event ID 100 (MainPathBootTime + BootPostBootTime)'
    'm7.boot.nodata' = 'Not enough data (log limited/cleared, or too few measured boots).'
    'm7.boot.bucket.30' = 'Last 30 days'
    'm7.boot.bucket.90' = 'Last 90 days'
    'm7.boot.bucket.180' = 'Last 180 days'
    'm7.boot.col.bucket' = 'Window'
    'm7.boot.col.count' = 'Boots'
    'm7.boot.col.median' = 'Median (ms)'
    'm7.boot.col.max' = 'Slowest (ms)'
    'm7.boot.count' = '{0} measured boots in the last 180 days.'
    'm7.boot.up' = 'Last 30 days are {0}% slower than the 90-day median ({1} → {2} ms).'
    'm7.boot.down' = 'Last 30 days are {0}% FASTER than the 90-day median ({1} → {2} ms) — the PC is not slowing down.'
    'm7.boot.flat' = 'Boot time is stable ({0}% change between 30-day and 90-day medians).'
    'm7.boot.compare.nodata' = 'Not enough boots to compare trend (need ≥ 3 in 30 days and ≥ 5 in 90 days).'
    'm7.boot.recent' = 'Recent boots (old → new, block height ~ boot time):'
    'm7.boot.source' = 'Source: event ID 100 — MainPathBootTime + BootPostBootTime (ms), read from event properties (no message parsing).'
    'm7.startup.title' = 'Startup items'
    'm7.startup.hint' = 'Run keys (HKLM/HKCU + WOW6432Node), Startup folders, logon/boot tasks, auto services — outside Microsoft'
    'm7.startup.count' = '{0} non-Microsoft startup items ({1} enabled).'
    'm7.startup.mscount' = '{0} Windows items (for reference, usually leave as is).'
    'm7.startup.empty' = 'No non-Microsoft startup items — very clean.'
    'm7.startup.on' = 'ON'
    'm7.startup.off' = 'OFF'
    'm7.startup.msbadge' = 'Windows'
    'm7.startup.toggle.off' = 'Disable selected'
    'm7.startup.toggle.on' = 'Re-enable selected'
    'm7.startup.confirm.title' = 'Change startup item state'
    'm7.startup.confirm.off' = 'The following startup items will be turned OFF (state change only, like Task Manager — the original command is NOT deleted, nothing is uninstalled):'
    'm7.startup.confirm.on' = 'The following startup items will be turned back ON:'
    'm7.startup.confirm.undo' = 'Reversible right away with "Re-enable selected" or Undo in History.'
    'm7.startup.confirm.noundo' = 'Disabled items will not run at logon until you re-enable them (software stays installed, no data loss).'
    'm7.startup.journal.off' = 'Disable startup item'
    'm7.startup.journal.on' = 'Re-enable startup item'
    'm7.startup.decode.note' = 'ON/OFF state is decoded from the StartupApproved value (the mechanism Task Manager uses) — a common decoding, not verified on every machine.'
    'm7.startup.tasks.title' = 'Startup tasks & services (outside Microsoft)'
    'm7.startup.tasks.summary' = '{0} tasks, {1} services — listed only'
    'm7.startup.tasks.hint' = 'Tasks and services are not toggled via StartupApproved — manage them in Task Scheduler / services.msc. WinCare only reports what hooks Windows startup.'
    'm7.startup.col.name' = 'Name'
    'm7.startup.col.type' = 'Type'
    'm7.startup.col.state' = 'State'
    'm7.startup.type.task' = 'Task'
    'm7.startup.type.service' = 'Service'
    'm7.startup.result' = 'Changed {0} items, {1} failed.'
    'm7.startup.more' = '… and {0} more'
    'm7.software.title' = 'Installed software'
    'm7.software.hint' = 'Counted from Uninstall keys (HKLM 64/32-bit + HKCU) — the WMI "product" class is never queried (it triggers MSI self-repair)'
    'm7.software.count' = '{0} programs installed.'
    'm7.software.bloat.title' = 'OEM / bloatware candidates (SUGGESTION only — your call)'
    'm7.software.bloat.hint' = 'Names matched against a list of common preinstalled software. "Uninstall" only opens the software own official uninstaller — nothing is deleted by WinCare.'
    'm7.software.bloat.empty' = 'No common bloatware candidates found.'
    'm7.software.uninstall' = 'Uninstall'
    'm7.software.installedon' = 'Installed: {0}'
    'm7.software.uninstall.confirm.title' = 'Open the uninstaller?'
    'm7.software.uninstall.confirm.msg' = 'This will open the official uninstaller of "{0}" and run:{1}{2}{3}You will confirm again inside the software uninstaller.'
    'm7.software.uninstall.confirm.noundo' = 'The uninstall is performed by the software own uninstaller — WinCare cannot undo it for you.'
    'm7.software.uninstall.running' = 'Opened the uninstaller of "{0}".'
    'm7.software.uninstall.fail' = 'Could not open the uninstaller'
    'm7.software.uninstall.nostring' = 'This program has no uninstall command in the registry.'
    'm7.software.journal' = 'Open official uninstaller'
    'm7.residual.title' = '"POSSIBLY leftover" folders'
    'm7.residual.hint' = 'Folders in Program Files / Program Files (x86) / ProgramData / Local\Programs not matching installed software — labeled "POSSIBLY" because false positives are easy'
    'm7.residual.empty' = 'No notable orphan folders found.'
    'm7.residual.open' = 'Open location (selected)'
    'm7.residual.delete' = 'Send to Recycle Bin (selected)'
    'm7.residual.delete.confirm.title' = 'Send folders to Recycle Bin?'
    'm7.residual.delete.confirm.msg' = 'The following folders will be moved to the RECYCLE BIN (not permanently deleted):'
    'm7.residual.delete.confirm.noundo' = 'WinCare will not auto-undo this — restore by dragging the folders back from the Recycle Bin.'
    'm7.residual.journal' = 'Recycle (leftover folder)'
    'm7.residual.orphan.title' = 'Orphan Uninstall keys in registry (REPORT only)'
    'm7.residual.orphan.hint' = 'Uninstall keys without DisplayName — usually traces of uninstalled apps. WinCare never deletes these; it only reports their existence.'
    'm7.residual.orphan.empty' = 'No orphan Uninstall keys.'
    'm7.residual.more' = '… and {0} more folders'
    'm7.residual.result' = 'Moved {0} folders to Recycle Bin, {1} failed/skipped.'
    'm7.games.title' = 'Games & launchers'
    'm7.games.hint' = 'Steam (libraryfolders.vdf + appmanifest), Epic (Manifests .item), other games via Uninstall keys'
    'm7.games.steam.none' = 'Steam not detected.'
    'm7.games.steam.ok' = 'Steam: {0} libraries, {1} games.'
    'm7.games.epic.none' = 'Epic Games Launcher not detected.'
    'm7.games.epic.ok' = 'Epic Games Launcher: {0} games.'
    'm7.games.col.name' = 'Game'
    'm7.games.col.source' = 'Source'
    'm7.games.col.size' = 'Size'
    'm7.games.col.last' = 'Last played'
    'm7.games.col.drive' = 'Drive'
    'm7.games.source.other' = 'Other (Uninstall)'
    'm7.games.last.unknown' = 'Unknown'
    'm7.games.old.total' = '• {0} games not played >180 days — totaling {1}. Uninstall/move via the launcher to free space.'
    'm7.games.hdd' = '• Games on an HDD (consider moving to SSD to cut load times): {0}'
    'm7.games.launcher' = '• Game launcher auto-starts with Windows: {0} — see Startup items above to disable if unneeded.'
    'm7.games.shader' = '• Shader caches: D3DSCache {0} + NVIDIA GLCache {1} — clean them in M2 (Disk cleanup); they rebuild automatically.'
    'm7.games.gpu.old' = '• GPU driver "{0}" is {1} days old (> 1 year) — see M3 (Drivers) to update.'
    'm7.games.gpu.ok' = '• GPU driver "{0}" updated {1} days ago — fine.'
    'm7.games.open.steam' = 'Open Steam'
    'm7.games.open.epic' = 'Open Epic'
    'm7.games.open.fail' = 'Could not open the launcher.'
    'm7.games.uninstall.note' = 'Uninstall/moving games ONLY via Steam/Epic — never delete game folders by hand (breaks the launcher).'
    'm7.games.empty' = 'No games detected via Steam / Epic / Uninstall keys.'
    'm7.games.more' = '… and {0} more games'
    'm7.sys.title' = 'System buildup'
    'm7.sys.hint' = 'Pending updates, last automatic maintenance, system drive, recent BSODs'
    'm7.sys.pending.ok' = '• No pending reboot flags — updates are finalized.'
    'm7.sys.pending.list' = '• Pending reboot flags: {0} — an update is not finalized; consider restarting.'
    'm7.sys.maintenance.label' = '• Last automatic maintenance: {0} ({1}).'
    'm7.sys.maintenance.none' = '• Not enough data about the last automatic maintenance.'
    'm7.sys.disk' = '• System drive free space: {0}%'
    'm7.sys.bsod.none' = '• BSODs in the last 90 days: 0.'
    'm7.sys.bsod.some' = '• BSODs in the last 90 days: {0} — see details in M5 (Stability & Integrity).'
    'm7.sys.bsod.nodata' = '• BSODs in the last 90 days: log not readable.'
    'm7.actions.title' = 'Directions (risk ascending)'
    'm7.actions.hint' = 'Go in order — only do what you understand and confirmed'
    'm7.actions.waiting' = 'Will appear once the scan finishes.'
    'm7.actions.1.title' = 'Targeted cleanup'
    'm7.actions.1.desc' = 'Run M2 (Disk cleanup) for safe cache/temp targets, and disable unneeded startup items in the "Startup items" section above.'
    'm7.actions.1.btn' = 'Open M2 — Disk cleanup'
    'm7.actions.2.title' = 'Uninstall/disable software, move games'
    'm7.actions.2.desc' = 'Remove bloatware via official uninstallers (Software section), move games from HDD to SSD via Steam/Epic (Games section). Never delete game folders by hand.'
    'm7.actions.3.title' = 'Reinstall Windows / Reset this PC (keep files)'
    'm7.actions.3.desc' = 'Consider only if the directions above do not help. This is your decision — WinCare does NOT automate this step.'
    'm7.actions.3.notneeded' = 'No basis to suggest a Windows reinstall yet: at least 3 objective signs at once are required (currently {0}/{1}).'
    'm7.actions.3.criteria' = 'Objective signs currently met:'
    'm7.actions.3.sign.boot' = '• Boot time increased by more than 50% (30-day vs 90-day median)'
    'm7.actions.3.sign.startup' = '• More than 15 non-Microsoft startup items'
    'm7.actions.3.sign.disk' = '• System drive below 10% free space'
    'm7.actions.3.sign.bsod' = '• 3 or more BSODs within 90 days'
    'm7.actions.3.checklist.title' = 'Backup checklist BEFORE reinstalling:'
    'm7.actions.3.checklist.1' = '• Documents, photos, videos — check Desktop, Downloads and folders outside C:'
    'm7.actions.3.checklist.2' = '• Browser data: sign in to sync, or export bookmarks/passwords'
    'm7.actions.3.checklist.3' = '• Software keys/licenses (Office, paid apps) — write them down to reactivate'
    'm7.actions.3.checklist.4' = '• Drivers exported in M3 (useful if Windows lacks drivers after install)'
    'm7.actions.3.checklist.5' = '• Confirm Windows is linked to your Microsoft account (to reactivate automatically)'
    'm7.actions.3.checklist.6' = '• List of software you use — review "Installed software" above'
    'm7.actions.3.guide.title' = 'Guide (you do it yourself):'
    'm7.actions.3.guide.1' = '• Way 1: Settings → System → Recovery → Reset this PC → "Keep my files" (keeps personal files, reinstalls Windows).'
    'm7.actions.3.guide.2' = '• Way 2: create an install USB with the Media Creation Tool from microsoft.com and install over the system partition (back up first per the checklist).'
    'm7.actions.3.note' = 'WinCare will not perform these steps for you — every reinstall action is yours.'
    'm7.nodata.reason' = 'Not enough data: {0}'
}

# ---------------------------------------------------------------------------
# UNDO HANDLER cho thao tac BAT LAI muc khoi dong (dao nguoc cua "tat")
# (handler "startup.enable" da co san trong 05-Journal.ps1)
# ---------------------------------------------------------------------------
Register-WCUndoHandler 'startup.disable' {
    # Tat lai muc khoi dong da bat lai qua StartupApproved (M7, ghi binary nhu Task Manager)
    param($Entry)
    $args2 = $Entry.UndoArgs
    $regPath = [string](Get-WCProp $args2 'RegPath')
    $valueName = [string](Get-WCProp $args2 'ValueName')
    if ($regPath -and $valueName) {
        $bytes = [byte[]]@(2,0,0,0,0,0,0,0,0,0,0,0)   # 4 byte dau 02 00 00 00 = dang TAT
        [Microsoft.Win32.Registry]::SetValue($regPath, $valueName, [byte[]]$bytes, [Microsoft.Win32.RegistryValueKind]::Binary)
    }
}

# ---------------------------------------------------------------------------
# DATA LAYER (Get-*/ConvertTo-* thuan, tra hashtable chuan hoa - spec 2.3)
# ---------------------------------------------------------------------------
function Get-WCWindowsInstallAge {
    # Tuoi cai dat: HKLM InstallDate la SO GIAY UNIX (khong phai FILETIME)
    # -> dung [DateTimeOffset]::FromUnixTimeSeconds de chuyen doi.
    $raw = Get-WCRegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'InstallDate'
    if ($null -eq $raw) { return $null }
    try {
        $secs = [long]$raw
        if ($secs -le 0) { return $null }
        $dto = [DateTimeOffset]::FromUnixTimeSeconds($secs)
        $ageDays = [int](([DateTimeOffset]::Now - $dto).TotalDays)
        if ($ageDays -lt 0) { $ageDays = 0 }
        return @{ InstallDate = $dto.LocalDateTime; AgeDays = $ageDays }
    } catch { return $null }
}

function Get-WCM7BootBucket {
    # Gom gio khoi dong trong N ngay gan nhat: Count + Median + Max (ms)
    param($Boots, [double]$Days, [DateTime]$Now)
    $vals = @()
    foreach ($b in $Boots) {
        $t = $b['Time']
        if (($null -ne $t) -and ($t -is [DateTime]) -and ((($Now - $t).TotalDays) -le $Days)) {
            $vals += [double]$b['TotalMs']
        }
    }
    if ($vals.Count -eq 0) { return @{ Count = 0; MedianMs = $null; MaxMs = $null } }
    $sorted = @($vals | Sort-Object)
    $med = $null
    if (($sorted.Count % 2) -eq 1) {
        $med = [double]$sorted[[int](($sorted.Count - 1) / 2)]
    } else {
        $med = ([double]$sorted[($sorted.Count / 2) - 1] + [double]$sorted[($sorted.Count / 2)]) / 2.0
    }
    return @{ Count = $vals.Count; MedianMs = [math]::Round($med, 0); MaxMs = [double]$sorted[$sorted.Count - 1] }
}

function Get-WCBootTrend {
    # Xu huong thoi gian khoi dong: su kien ID 100 (Boot) trong log
    # Microsoft-Windows-Diagnostics-Performance/Operational.
    # Doc MainPathBootTime + BootPostBootTime qua $event.Properties (index),
    # KHONG parse message (da dia phuong hoa). Tong = MainPath + PostBoot (ms).
    $out = @{ Boots = @(); Buckets = @{}; DeltaPct = $null; Enough = $false; SampleCount = 0; Error = '' }
    $events = @()
    try {
        $since = [DateTime]::Now.AddDays(-190)
        $events = @(Get-WinEvent -FilterHashtable @{
            LogName = 'Microsoft-Windows-Diagnostics-Performance/Operational'
            Id = 100; StartTime = $since } -ErrorAction Stop)
    } catch {
        # Log khong ton tai / khong co su kien -> khong du du lieu (khong phai loi)
        $out.Error = 'noevents'
        return $out
    }
    if ($events.Count -eq 0) { $out.Error = 'noevents'; return $out }
    # Xac dinh CHI SO truong MainPathBootTime / BootPostBootTime tu 1 su kien mau
    # (event XML EventData/Data theo dung thu tu voi Properties)
    $idxMain = -1; $idxPost = -1
    try {
        [xml]$xml = $events[0].ToXml()
        $i = 0
        foreach ($d in @($xml.Event.EventData.Data)) {
            $n = (Get-WCProp $d 'Name')
            if ($n -eq 'MainPathBootTime') { $idxMain = $i }
            if ($n -eq 'BootPostBootTime') { $idxPost = $i }
            $i++
        }
    } catch { }
    if (($idxMain -lt 0) -or ($idxPost -lt 0)) { $out.Error = 'nofields'; return $out }
    $now = [DateTime]::Now
    $boots = @()
    foreach ($e in $events) {
        try {
            $props = @(Get-WCProp $e 'Properties')
            $need = [Math]::Max($idxMain, $idxPost)
            if ($props.Count -le $need) { continue }
            $mainVal = (Get-WCProp $props[$idxMain] 'Value')
            $postVal = (Get-WCProp $props[$idxPost] 'Value')
            if (($null -eq $mainVal) -or ($null -eq $postVal)) { continue }
            $t = (Get-WCProp $e 'TimeCreated')
            if ($null -eq $t) { continue }
            $total = [double]$mainVal + [double]$postVal
            if ($total -le 0) { continue }
            $boots += @{ Time = $t; TotalMs = $total }
        } catch { }
    }
    $out.Boots = $boots
    $out.SampleCount = $boots.Count
    $out.Buckets['30'] = (Get-WCM7BootBucket -Boots $boots -Days 30 -Now $now)
    $out.Buckets['90'] = (Get-WCM7BootBucket -Boots $boots -Days 90 -Now $now)
    $out.Buckets['180'] = (Get-WCM7BootBucket -Boots $boots -Days 180 -Now $now)
    # So sanh trung vi 30 ngay voi trung vi 90 ngay (can du so mau de ket luan)
    $b30 = $out.Buckets['30']; $b90 = $out.Buckets['90']
    if (($b30.Count -ge 3) -and ($b90.Count -ge 5) -and $b90.MedianMs -and ($b90.MedianMs -gt 0)) {
        $delta = (([double]$b30.MedianMs - [double]$b90.MedianMs) / [double]$b90.MedianMs) * 100.0
        $out.DeltaPct = [math]::Round($delta, 0)
        $out.Enough = $true
    }
    return $out
}

function Test-WCM7IsMicrosoftPath {
    # Heuristic "thuoc Windows/Model Microsoft": duong dan nam trong %SystemRoot%
    # hoac chua \Microsoft\ (vi du OneDrive trong LOCALAPPDATA\Microsoft)
    param([string]$Path)
    if ([string]::IsNullOrEmpty($Path)) { return $false }
    try {
        $p = $Path.ToLowerInvariant()
        $win = ''
        try { $win = ([string]$env:SystemRoot).ToLowerInvariant() } catch { }
        if ($win -and ($p.StartsWith($win))) { return $true }
        if ($p -like '*\microsoft\*') { return $true }
    } catch { }
    return $false
}

function Resolve-WCM7ShortcutTarget {
    # Doc duong dan dich cua .lnk qua COM WScript.Shell (khong parse CLI)
    param([string]$Path)
    try {
        $sh = New-Object -ComObject WScript.Shell
        $sc = $sh.CreateShortcut($Path)
        # COM: truy cap thuoc tinh trong try/catch (TargetPath ton tai tren shortcut)
        $t = [string]$sc.TargetPath
        try { $null = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($sc) } catch { }
        try { $null = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($sh) } catch { }
        return $t
    } catch { return '' }
}

function Get-WCStartupApprovedState {
    # Trang thai bat/tat tu gia tri binary StartupApproved (12 byte).
    # DECODE PHO BIEN (chua kiem chung tren moi may, xem comment file):
    #   4 byte dau 00 00 00 00 = dang BAT; 02 00 00 00 = da TAT.
    # Gia tri khac / thieu -> coi nhu dang BAT (nhu cach Task Manager hien thi).
    param([string]$ApprovedKey, [string]$ValueName)
    try {
        $bytes = Get-WCRegistryValue -Path $ApprovedKey -Name $ValueName
        if ($null -eq $bytes) { return 'Enabled' }
        $arr = @($bytes)
        if ($arr.Count -lt 4) { return 'Enabled' }
        if (($arr[0] -eq 2) -and ($arr[1] -eq 0) -and ($arr[2] -eq 0) -and ($arr[3] -eq 0)) { return 'Disabled' }
        if (($arr[0] -eq 0) -and ($arr[1] -eq 0) -and ($arr[2] -eq 0) -and ($arr[3] -eq 0)) { return 'Enabled' }
        return 'Enabled'
    } catch { return 'Enabled' }
}

function Convert-WCRegPsPathToFull {
    # 'HKLM:\...' -> 'HKEY_LOCAL_MACHINE\...' (dang ma [Microsoft.Win32.Registry]::SetValue dung)
    param([string]$Path)
    if ($Path -like 'HKLM:\*') { return ('HKEY_LOCAL_MACHINE\' + $Path.Substring(6)) }
    if ($Path -like 'HKCU:\*') { return ('HKEY_CURRENT_USER\' + $Path.Substring(6)) }
    return $Path
}

function Set-WCStartupApprovedState {
    # Viet binary StartupApproved DUNG CACH Task Manager (KHONG xoa khoa goc):
    #   Bat = 12 byte 0; Tat = 02 00 00 00 + 8 byte 0.
    param([string]$ApprovedKey, [string]$ValueName, [bool]$Enable)
    $full = Convert-WCRegPsPathToFull -Path $ApprovedKey
    $bytes = [byte[]]@(0,0,0,0,0,0,0,0,0,0,0,0)
    if (-not $Enable) { $bytes = [byte[]]@(2,0,0,0,0,0,0,0,0,0,0,0) }
    [Microsoft.Win32.Registry]::SetValue($full, $ValueName, [byte[]]$bytes, [Microsoft.Win32.RegistryValueKind]::Binary)
}

function Get-WCStartupEntries {
    # Gom muc khoi dong: Run keys (HKLM/HKCU + WOW6432Node), thu muc Startup
    # (user + common), Scheduled Task trigger Logon/Boot ngoai Microsoft,
    # service Auto ngoai Microsoft. Trang thai doc tu StartupApproved.
    param([bool]$IncludeTasksAndServices = $true)
    $out = @{ Entries = @(); Tasks = @(); Services = @(); NonMsCount = 0; NonMsEnabledCount = 0; Error = '' }
    # --- Run keys ---
    $runSources = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
           Approved = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
           Approved = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' }
        @{ Path = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
           Approved = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32' }
        @{ Path = 'HKCU:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run'
           Approved = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32' }
    )
    foreach ($src in $runSources) {
        try {
            if (-not (Test-Path -LiteralPath $src['Path'])) { continue }
            $key = Get-Item -LiteralPath $src['Path'] -ErrorAction Stop
            foreach ($vn in @($key.GetValueNames())) {
                try {
                    $cmd = ''
                    try { $cmd = [string]$key.GetValue($vn) } catch { }
                    if ([string]::IsNullOrEmpty($cmd)) { continue }
                    $state = Get-WCStartupApprovedState -ApprovedKey $src['Approved'] -ValueName $vn
                    $out.Entries += @{
                        Name = $vn; Command = $cmd; Kind = 'Run'
                        IsMicrosoft = (Test-WCM7IsMicrosoftPath -Path $cmd)
                        State = $state
                        ApprovedKey = $src['Approved']; ValueName = $vn
                    }
                } catch { }
            }
        } catch { }
    }
    # --- Thu muc Startup (user + common) ---
    $folderSources = @(
        @{ Folder = ([Environment]::GetFolderPath('Startup'))
           Approved = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder' }
        @{ Folder = ([Environment]::GetFolderPath('CommonStartup'))
           Approved = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder' }
    )
    foreach ($src in $folderSources) {
        try {
            if ([string]::IsNullOrEmpty($src['Folder']) -or (-not (Test-Path -LiteralPath $src['Folder']))) { continue }
            $files = @(Get-ChildItem -LiteralPath $src['Folder'] -File -ErrorAction SilentlyContinue)
            foreach ($f in $files) {
                try {
                    if ($f.Name -ieq 'desktop.ini') { continue }
                    $target = ''
                    if ($f.Extension -ieq '.lnk') { $target = (Resolve-WCM7ShortcutTarget -Path $f.FullName) }
                    $state = Get-WCStartupApprovedState -ApprovedKey $src['Approved'] -ValueName $f.Name
                    $out.Entries += @{
                        Name = $f.Name; Command = $target; Kind = 'Folder'
                        IsMicrosoft = (Test-WCM7IsMicrosoftPath -Path $target)
                        State = $state
                        ApprovedKey = $src['Approved']; ValueName = $f.Name
                    }
                } catch { }
            }
        } catch { }
    }
    # --- Scheduled Task trigger Logon/Boot, ngoai Microsoft ---
    if ($IncludeTasksAndServices) {
        try {
            $all = @(Get-ScheduledTask -ErrorAction SilentlyContinue)
            foreach ($t in $all) {
                try {
                    $tp = [string](Get-WCProp $t 'TaskPath')
                    if ($tp -like '\Microsoft\*') { continue }
                    $triggers = @(Get-WCProp $t 'Triggers')
                    $hit = $false
                    foreach ($tr in $triggers) {
                        $cn = ''
                        try {
                            $cc = Get-WCProp $tr 'CimClass'
                            if ($cc) { $cn = [string](Get-WCProp $cc 'CimClassName') }
                        } catch { }
                        if ([string]::IsNullOrEmpty($cn)) {
                            # Phuong an B: ten kieu PSObject (CimInstance#...MSFT_TaskLogonTrigger)
                            try {
                                foreach ($tn in @($tr.PSObject.TypeNames)) {
                                    if ($tn -match 'LogonTrigger|BootTrigger') { $cn = $tn; break }
                                }
                            } catch { }
                        }
                        if ($cn -match 'LogonTrigger|BootTrigger') { $hit = $true; break }
                    }
                    if ($hit) {
                        $out.Tasks += @{
                            Name = ([string](Get-WCProp $t 'TaskName'))
                            TaskPath = $tp
                            State = ([string](Get-WCProp $t 'State'))
                        }
                    }
                } catch { }
            }
        } catch { }
        # --- Service Auto ngoai Microsoft (heuristic theo duong dan) ---
        try {
            $svcs = @(Get-CimInstance -ClassName Win32_Service -Property Name,DisplayName,State,StartMode,PathName -OperationTimeoutSec 15)
            foreach ($s in $svcs) {
                try {
                    if ((Get-WCProp $s 'StartMode') -ne 'Auto') { continue }
                    $pn = [string](Get-WCProp $s 'PathName')
                    if (Test-WCM7IsMicrosoftPath -Path $pn) { continue }
                    $out.Services += @{
                        Name = ([string](Get-WCProp $s 'Name'))
                        DisplayName = ([string](Get-WCProp $s 'DisplayName'))
                        State = ([string](Get-WCProp $s 'State')); PathName = $pn
                    }
                } catch { }
            }
        } catch { }
    }
    # --- Dem muc NGOAI Microsoft (chi so bang chung) ---
    $nonMs = 0; $nonMsEnabled = 0
    foreach ($e in @($out.Entries)) {
        if (-not $e['IsMicrosoft']) {
            $nonMs++
            if ($e['State'] -ne 'Disabled') { $nonMsEnabled++ }
        }
    }
    foreach ($tk in @($out.Tasks)) {
        $nonMs++
        if ($tk['State'] -ne 'Disabled') { $nonMsEnabled++ }
    }
    foreach ($sv in @($out.Services)) {
        $nonMs++
        if ($sv['State'] -eq 'Running') { $nonMsEnabled++ }
    }
    $out.NonMsCount = $nonMs
    $out.NonMsEnabledCount = $nonMsEnabled
    return $out
}

function ConvertTo-WCM7InstallDateText {
    # InstallDate trong khoa Uninstall dang 'YYYYMMDD' -> 'YYYY-MM-DD'
    param($Raw)
    try {
        $s = [string]$Raw
        if ($s -match '^(\d{4})(\d{2})(\d{2})$') {
            return ($Matches[1] + '-' + $Matches[2] + '-' + $Matches[3])
        }
    } catch { }
    return ''
}

function Get-WCInstalledSoftware {
    # Dem phan mem tu khoa Uninstall: HKLM 64/32-bit + HKCU.
    # KHONG bao gio truy van lop WMI "san pham" cua Windows (gay MSI self-repair - spec M7).
    # Ket qua: @{ Total; Apps = @{DisplayName;Publisher;InstallDateText;
    #            UninstallString;EstimatedBytes}; OrphanKeys = @{KeyName} }
    $roots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    $apps = @()
    $seen = @{}
    $orphans = @()
    foreach ($root in $roots) {
        try {
            if (-not (Test-Path -LiteralPath $root)) { continue }
            $keys = @(Get-ChildItem -LiteralPath $root -ErrorAction Stop)
            foreach ($k in $keys) {
                try {
                    $p = Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction Stop
                    if ((Get-WCProp $p 'SystemComponent') -eq 1) { continue }
                    $name = (Get-WCProp $p 'DisplayName')
                    if ([string]::IsNullOrEmpty([string]$name)) {
                        # Muc Uninstall mo coi (khong co DisplayName) -> CHI BAO CAO
                        $orphans += @{ KeyName = ([string]$k.PSChildName); Root = $root }
                        continue
                    }
                    $pub = [string](Get-WCProp $p 'Publisher')
                    $dedupeKey = (([string]$name).ToLowerInvariant() + '|' + $pub.ToLowerInvariant())
                    if ($seen.ContainsKey($dedupeKey)) { continue }
                    $seen[$dedupeKey] = $true
                    $estBytes = [long]0
                    $est = Get-WCProp $p 'EstimatedSize'
                    if ($null -ne $est) { $estBytes = ([long]$est) * 1KB }
                    $apps += @{
                        DisplayName = [string]$name; Publisher = $pub
                        InstallDateText = (ConvertTo-WCM7InstallDateText (Get-WCProp $p 'InstallDate'))
                        UninstallString = [string](Get-WCProp $p 'UninstallString')
                        EstimatedBytes = $estBytes
                    }
                } catch { }
            }
        } catch { }
    }
    return @{ Total = $apps.Count; Apps = $apps; OrphanKeys = $orphans }
}

function Get-WCOemBloatCandidates {
    # Loc ung vien OEM/bloatware: ten khop danh sach phan mem lap san pho bien.
    # CHI DE XUAT - nguoi dung tu quyet dinh go (spec M7).
    param($Apps)
    $patterns = @(
        'Dell SupportAssist','Dell Optimizer','Dell Mobile Connect','Dell Digital Delivery','SupportAssist',
        'McAfee','WildTangent','HP JumpStart','HP Support Assistant','HP Documentation','HP Orbit',
        'Lenovo','CyberLink','Booking.com','Ask Toolbar','Google Toolbar','Bing Bar',
        'WinZip Driver Updater','Driver Booster','Advanced SystemCare','DriverPack','PC Cleaner',
        'Registry Cleaner','MyWinLocker'
    )
    $hits = @()
    foreach ($a in @($Apps)) {
        $name = [string]$a['DisplayName']
        $pub = [string]$a['Publisher']
        if ([string]::IsNullOrEmpty($name)) { continue }
        $matched = $false
        foreach ($pat in $patterns) {
            if (($name -like ('*' + $pat + '*')) -or ($pub -like ('*' + $pat + '*'))) { $matched = $true; break }
        }
        if ($matched) { $hits += $a }
    }
    return $hits
}

function ConvertTo-WCM7NormName {
    # Chuan hoa ten de so khop mo: chu thuong, chi giu [0-9a-z]
    param([string]$Name)
    try {
        $n = ($Name.ToLowerInvariant() -replace '[^0-9a-z]', '')
        if ([string]::IsNullOrEmpty($n)) { return ($Name.ToLowerInvariant()) }
        return $n
    } catch { return ($Name.ToLowerInvariant()) }
}

function Test-WCM7NameMatch {
    # So khop MO (fuzzy) ten thu muc voi danh sach DisplayName:
    # DisplayName bo khoang trang roi so -like '*<folder>*' (hoac nguoc lai).
    # Ten thu muc ngan (<4 ky tu) chi khop KHOANH DUNG de tranh bao nham.
    param([string]$NormFolder, $Names)
    foreach ($n in $Names) {
        $normName = ConvertTo-WCM7NormName -Name ([string]$n)
        if ([string]::IsNullOrEmpty($normName)) { continue }
        if ($NormFolder.Length -ge 4) {
            if ($normName -like ('*' + $NormFolder + '*')) { return $true }
            if ($NormFolder -like ('*' + $normName + '*')) { return $true }
        } else {
            # Ten thu muc ngan: chi khop khoanh dung hoac tien to (an toan
            # huong "khong bao tan du" thay vi "bao nham")
            if ($normName -eq $NormFolder) { return $true }
            if ($normName -like ($NormFolder + '*')) { return $true }
        }
    }
    return $false
}

function Get-WCResidualCandidates {
    # Thu muc mo coi trong Program Files / PF(x86) / ProgramData / Local\Programs
    # KHONG ung voi phan mem dang cai (so khop mo voi DisplayName).
    # Nhan "CO THE la tan du" - de bao nham, chi bo cao + kich thuoc.
    $sw = Get-WCInstalledSoftware
    $names = @()
    foreach ($a in @($sw['Apps'])) { $names += [string]$a['DisplayName'] }
    # Thu muc he thong bo qua (dang CHUAN HOA khong khoang trang)
    $skipNorm = @(
        'commonfiles','microsoft','windows','windowsnt','internetexplorer','windowsapps',
        'windowsdefender','modifiablewindowsapps','installshieldinstallationinformation',
        'packagecache','packages','softwaredistribution','usoshared','regid199106commicrosoft',
        'windowspowershell','powershell','default','public','desktop','documents','startmenu',
        'programs','chocolatey','windowsholographicdevices','ssh','usoprivatecatalogupdate'
    )
    $roots = @()
    foreach ($p in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData, (Join-Path $env:LOCALAPPDATA 'Programs'))) {
        if ($p -and (Test-Path -LiteralPath $p)) { $roots += [string]$p }
    }
    $result = @()
    foreach ($root in $roots) {
        try {
            $dirs = @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue)
            foreach ($d in $dirs) {
                try {
                    $norm = ConvertTo-WCM7NormName -Name $d.Name
                    if ($norm.Length -lt 2) { continue }
                    if ($skipNorm -contains $norm) { continue }
                    if (Test-WCM7NameMatch -NormFolder $norm -Names $names) { continue }
                    if (Test-WCPathIsReparsePoint -Path $d.FullName) { continue }   # junction -> bo qua
                    $size = Get-WCDirSize -Path $d.FullName
                    $result += @{ Path = $d.FullName; Name = $d.Name; Root = $root; SizeBytes = $size }
                } catch { }
            }
        } catch { }
    }
    $sorted = @($result | Sort-Object -Property { $_['SizeBytes'] } -Descending)
    return @{ Folders = $sorted }
}

function Get-WCSteamLibraryPaths {
    # Parser VDF DON GIAN (ham thuan de unit test): moi dong '"path"  "C:\\..."'
    # trong libraryfolders.vdf -> tra mang duong dan thu vien Steam.
    param([string]$SteamRoot)
    $paths = @()
    try {
        if ([string]::IsNullOrEmpty($SteamRoot)) { return @() }
        $vdf = Join-Path $SteamRoot 'steamapps\libraryfolders.vdf'
        if (-not (Test-Path -LiteralPath $vdf)) { return @() }
        foreach ($line in [IO.File]::ReadAllLines($vdf)) {
            if ($line -match '"path"\s+"(.+)"') {
                $p = ($Matches[1] -replace '\\\\', '\')
                if (-not [string]::IsNullOrEmpty($p)) { $paths += $p }
            }
        }
    } catch { }
    return $paths
}

function Get-WCSteamGames {
    # Doc appmanifest_*.acf trong tung thu vien Steam: name / SizeOnDisk /
    # LastPlayed (giay Unix). Lay ket qua DAU TIEN cho moi truong (cap muc cao
    # nam truoc cac khoi long - ten co the trung o muc sau).
    param([string]$SteamRoot)
    $games = @()
    $libs = @(Get-WCSteamLibraryPaths -SteamRoot $SteamRoot)
    if ($libs.Count -eq 0) { $libs = @([string]$SteamRoot) }
    foreach ($lib in $libs) {
        try {
            $appsDir = Join-Path $lib 'steamapps'
            if (-not (Test-Path -LiteralPath $appsDir)) { continue }
            $files = @(Get-ChildItem -LiteralPath $appsDir -Filter 'appmanifest_*.acf' -File -ErrorAction SilentlyContinue)
            foreach ($f in $files) {
                try {
                    $name = ''; $size = [long]0; $last = [long]0
                    foreach ($line in [IO.File]::ReadAllLines($f.FullName)) {
                        if (($name -eq '') -and ($line -match '"name"\s+"(.*)"')) { $name = $Matches[1] }
                        elseif (($size -eq 0) -and ($line -match '"SizeOnDisk"\s+"(\d+)"')) { $size = [long]$Matches[1] }
                        elseif (($last -eq 0) -and ($line -match '"LastPlayed"\s+"(\d+)"')) { $last = [long]$Matches[1] }
                    }
                    if ([string]::IsNullOrEmpty($name)) { continue }
                    $lastDt = $null
                    if ($last -gt 0) {
                        try { $lastDt = [DateTimeOffset]::FromUnixTimeSeconds($last).LocalDateTime } catch { }
                    }
                    $drive = ''
                    if ($lib -match '^([A-Za-z]):') { $drive = $Matches[1] + ':' }
                    $games += @{ Name = $name; Source = 'Steam'; SizeBytes = $size; LastPlayed = $lastDt; Drive = $drive }
                } catch { }
            }
        } catch { }
    }
    return $games
}

function Get-WCEpicGames {
    # Epic: %ProgramData%\Epic\EpicGamesLauncher\Data\Manifests\*.item (JSON)
    # Thuoc tinh doc qua Get-WCProp; thieu (AppSizeBytes...) -> de N/A.
    $games = @()
    try {
        $dir = Join-Path $env:ProgramData 'Epic\EpicGamesLauncher\Data\Manifests'
        if (-not (Test-Path -LiteralPath $dir)) { return @() }
        $files = @(Get-ChildItem -LiteralPath $dir -Filter '*.item' -File -ErrorAction SilentlyContinue)
        foreach ($f in $files) {
            try {
                $json = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
                $name = [string](Get-WCProp $json 'DisplayName')
                if ([string]::IsNullOrEmpty($name)) { continue }
                $loc = [string](Get-WCProp $json 'InstallLocation')
                $size = [long]0
                $szProp = Get-WCProp $json 'AppSizeBytes'
                if ($null -ne $szProp) { $size = [long]$szProp }
                $drive = ''
                if ($loc -match '^([A-Za-z]):') { $drive = $Matches[1] + ':' }
                $games += @{ Name = $name; Source = 'Epic'; SizeBytes = $size; LastPlayed = $null; Drive = $drive }
            } catch { }
        }
    } catch { }
    return $games
}

function Get-WCDriveMediaTypeMap {
    # Map ky tu o -> 'SSD'/'HDD' de goi y "game nam tren o HDD".
    # dung CIM: Win32_LogicalDiskToPartition (lay Disk #) + MSFT_PhysicalDisk
    # (root/Microsoft/Windows/Storage, MediaType 3=HDD 4=SSD). Loi -> map rong
    # (bo goi y, khong bao loi - spec M7).
    $map = @{}
    try {
        $phys = @(Get-CimInstance -Namespace 'root/Microsoft/Windows/Storage' -ClassName 'MSFT_PhysicalDisk' -Property DeviceId,MediaType -OperationTimeoutSec 10 -ErrorAction Stop)
        $byDisk = @{}
        foreach ($p in $phys) {
            $dev = [string](Get-WCProp $p 'DeviceId')
            $mt = (Get-WCProp $p 'MediaType')
            if ($dev) {
                $kind = ''
                if ([int]$mt -eq 3) { $kind = 'HDD' }
                if ([int]$mt -eq 4) { $kind = 'SSD' }
                $byDisk[$dev] = $kind
            }
        }
        $assoc = @(Get-CimInstance -ClassName Win32_LogicalDiskToPartition -OperationTimeoutSec 10 -ErrorAction Stop)
        foreach ($a in $assoc) {
            try {
                $ant = [string](Get-WCProp $a 'Antecedent')   # ...DiskPartition.DeviceID="Disk #0, Partition #2"
                $dep = [string](Get-WCProp $a 'Dependent')    # ...LogicalDisk.DeviceID="C:"
                $diskIdx = ''
                if ($ant -match 'Disk #(\d+)') { $diskIdx = $Matches[1] }
                $letter = ''
                if ($dep -match '"([A-Za-z]):"') { $letter = $Matches[1] + ':' }
                if ($diskIdx -ne '' -and $letter -ne '' -and $byDisk.ContainsKey($diskIdx)) {
                    $map[$letter] = $byDisk[$diskIdx]
                }
            } catch { }
        }
    } catch { }
    return $map
}

function Get-WCGamesInfo {
    # Gom toan bo thong tin game: Steam + Epic + game khac qua khoa Uninstall,
    # goi y (game lau khong choi, o HDD, launcher tu chay, shader cache,
    # driver GPU cu). Steam/Epic khong cai -> khong loi, chi bao "khong phat hien".
    $out = @{
        SteamInstalled = $false; EpicInstalled = $false; SteamRoot = ''
        Games = @(); OldGamesCount = 0; OldGamesBytes = [long]0
        HddGames = @(); LauncherInStartup = @()
        ShaderD3DBytes = $null; ShaderGlBytes = $null
        GpuName = ''; GpuDriverDays = $null
        Error = ''
    }
    # --- Steam ---
    try {
        $pf86 = ${env:ProgramFiles(x86)}
        if ($pf86 -and (Test-Path -LiteralPath (Join-Path $pf86 'Steam'))) {
            $out.SteamRoot = (Join-Path $pf86 'Steam')
            $out.SteamInstalled = $true
        }
    } catch { }
    if ($out.SteamInstalled) {
        $steamGames = @(Get-WCSteamGames -SteamRoot $out.SteamRoot)
        $out.Games += $steamGames
    }
    # --- Epic ---
    try {
        $epicGames = @(Get-WCEpicGames)
        if ($epicGames.Count -gt 0) {
            $out.EpicInstalled = $true
            $out.Games += $epicGames
        }
    } catch { }
    # --- Game khac qua khoa Uninstall (Publisher khop nha phat hanh game) ---
    try {
        $sw = Get-WCInstalledSoftware
        $haveNames = @{}
        foreach ($g in @($out.Games)) { $haveNames[([string]$g['Name']).ToLowerInvariant()] = $true }
        foreach ($a in @($sw['Apps'])) {
            $name = [string]$a['DisplayName']
            $pub = [string]$a['Publisher']
            if ([string]::IsNullOrEmpty($name)) { continue }
            $nl = $name.ToLowerInvariant()
            if ($nl -eq 'steam' -or $nl -eq 'epic games launcher') { continue }   # launcher, khong phai game
            if ($haveNames.ContainsKey($nl)) { continue }
            if ($pub -match 'Valve|Steam|Epic Games|GOG|Ubisoft|Electronic Arts|Activision|Bethesda') {
                $out.Games += @{ Name = $name; Source = 'Other'; SizeBytes = [long]$a['EstimatedBytes']; LastPlayed = $null; Drive = '' }
            }
        }
    } catch { }
    # --- Goi y: game lau khong choi (>180 ngay, LastPlayed > 0) ---
    $now = [DateTime]::Now
    foreach ($g in @($out.Games)) {
        $lp = $g['LastPlayed']
        if (($null -ne $lp) -and ($lp -is [DateTime]) -and ((($now - $lp).TotalDays) -gt 180)) {
            $out.OldGamesCount++
            $out.OldGamesBytes += [long]$g['SizeBytes']
        }
    }
    # --- Goi y: game nam tren o HDD ---
    try {
        $driveMap = Get-WCDriveMediaTypeMap
        if ($driveMap.Count -gt 0) {
            foreach ($g in @($out.Games)) {
                $d = [string]$g['Drive']
                if ($d -and $driveMap.ContainsKey($d) -and ($driveMap[$d] -eq 'HDD')) {
                    $out.HddGames += [string]$g['Name']
                }
            }
        }
    } catch { }
    # --- Goi y: launcher tu chay cung Windows (chi xem Run keys + Startup folder) ---
    try {
        $su = Get-WCStartupEntries -IncludeTasksAndServices:$false
        foreach ($e in @($su['Entries'])) {
            $hay = (([string]$e['Name']) + ' ' + ([string]$e['Command'])).ToLowerInvariant()
            if ($hay -match 'steam|epicgames|epic games') { $out.LauncherInStartup += [string]$e['Name'] }
        }
    } catch { }
    # --- Shader cache (doi chieu M2 - o day chi hien dung luong) ---
    try {
        $d3d = Join-Path $env:LOCALAPPDATA 'D3DSCache'
        if (Test-Path -LiteralPath $d3d) { $out.ShaderD3DBytes = (Get-WCDirSize -Path $d3d) }
    } catch { }
    try {
        $gl = Join-Path $env:LOCALAPPDATA 'NVIDIA\GLCache'
        if (Test-Path -LiteralPath $gl) { $out.ShaderGlBytes = (Get-WCDirSize -Path $gl) }
    } catch { }
    # --- Driver GPU cu (> 1 nam -> goi y xem M3) ---
    try {
        $gpus = @(Get-CimInstance -ClassName Win32_VideoController -Property Name,DriverDate -OperationTimeoutSec 10)
        $oldest = $null
        foreach ($g in $gpus) {
            $n = [string](Get-WCProp $g 'Name')
            if ($n -and ([string]::IsNullOrEmpty($out.GpuName))) { $out.GpuName = $n }
            $dd = Get-WCProp $g 'DriverDate'
            if ($null -ne $dd) {
                $d = $null
                try {
                    if ($dd -is [DateTime]) { $d = $dd }
                    else { $d = $dd.ToDateTime([Globalization.CultureInfo]::InvariantCulture) }
                } catch { }
                if ($d -and (($null -eq $oldest) -or ($d -lt $oldest))) { $oldest = $d }
            }
        }
        if ($oldest) { $out.GpuDriverDays = [int](([DateTime]::Now - $oldest).TotalDays) }
    } catch { }
    return $out
}

function Get-WCSystemAccumulation {
    # Tich tu he thong: co cho khoi dong lai, lan bao tri tu dong gan nhat,
    # o he thong con trong bao nhieu %, so lan BSOD 90 ngay.
    $out = @{
        PendingFlags = @(); MaintenanceLastRun = $null; MaintenanceDays = $null
        DiskFreePct = $null; BsodCount90 = $null; Error = ''
    }
    # 1) Co cho khoi dong lai (RebootPending keys)
    try {
        if (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
            $out.PendingFlags += 'CBS'
        }
    } catch { }
    try {
        if (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootPending') {
            $out.PendingFlags += 'WindowsUpdate'
        }
    } catch { }
    try {
        $pfro = Get-WCRegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations'
        $arr = @($pfro)
        if ($arr.Count -gt 0 -and (-not [string]::IsNullOrEmpty([string]$arr[0]))) {
            $out.PendingFlags += 'PendingFileRename'
        }
    } catch { }
    # 2) Thoi gian tu lan bao tri tu dong (Idle Maintenance / Maintenance Configurator)
    foreach ($taskName in @('Idle Maintenance', 'Maintenance Configurator')) {
        try {
            $info = Get-ScheduledTaskInfo -TaskName $taskName -TaskPath '\Microsoft\Windows\TaskScheduler\' -ErrorAction Stop
            $lr = Get-WCProp $info 'LastRunTime'
            if ($lr -and ($lr -is [DateTime]) -and ($lr.Year -gt 2000)) {
                $out.MaintenanceLastRun = $lr
                $out.MaintenanceDays = [int](([DateTime]::Now - $lr).TotalDays)
                break
            }
        } catch { }
    }
    # 3) O he thong con trong bao nhieu phan tram
    try {
        $ld = Get-CimInstance -ClassName Win32_LogicalDisk -Filter ("DeviceID='" + $env:SystemDrive + "'") -Property Size,FreeSpace -OperationTimeoutSec 10
        $sz = Get-WCProp $ld 'Size'
        $fr = Get-WCProp $ld 'FreeSpace'
        if ($sz -and $fr) {
            $out.DiskFreePct = [math]::Round(([double]$fr / [double]$sz) * 100.0, 1)
        }
    } catch { }
    # 4) So lan BSOD (BugCheck) trong 90 ngay - thu 2 provider, tinh theo so su kien
    try {
        $since = [DateTime]::Now.AddDays(-90)
        $count = 0
        try {
            $ev = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-WER-SystemErrorReporter'; Id = 1001; StartTime = $since } -ErrorAction Stop)
            $count = $ev.Count
        } catch { $count = 0 }
        if ($count -eq 0) {
            try {
                $ev2 = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'BugCheck'; Id = 1001; StartTime = $since } -ErrorAction Stop)
                $count = $ev2.Count
            } catch { $count = 0 }
        }
        $out.BsodCount90 = $count
    } catch { $out.BsodCount90 = $null }
    return $out
}

function Split-WCUninstallCommand {
    # Tach UninstallString thanh exe + args:
    #   - neu bat dau bang '"' -> exe la phan trong ngoac, phan con lai la args
    #   - nguoc lai exe la token dau tien
    param([string]$Cmd)
    try {
        $c = ($Cmd).Trim()
        if ([string]::IsNullOrEmpty($c)) { return $null }
        if ($c.StartsWith('"')) {
            $end = $c.IndexOf('"', 1)
            if ($end -gt 1) {
                $exe = $c.Substring(1, $end - 1)
                $rest = $c.Substring($end + 1).Trim()
                return @{ Exe = $exe; Args = $rest }
            }
            return $null
        }
        $sp = $c.IndexOf(' ')
        if ($sp -lt 0) { return @{ Exe = $c; Args = '' } }
        return @{ Exe = $c.Substring(0, $sp); Args = $c.Substring($sp + 1).Trim() }
    } catch { return $null }
}

function Get-WCAgingVerdict {
    # Tinh chi so "Do lao hoa" tu du lieu 7 nguon. THUAN (de unit test):
    # dau vao la cac hashtable (hoac $null), dau ra nhan + chi tiet dau hieu.
    # Gia dinh nguong (ghi ro trong bao cao): boot > +25% nhe / > +50% nang;
    # startup ngoai MS > 10 nhe / > 15 nang; bloat >= 2 nhe; tan du > 1GB nhe;
    # o he thong < 20% trong nhe / < 10% nang; >= 2 co pending nhe; BSOD >= 3 nang.
    # Nhan: diem = nhe + 2*nang; >= 4 "Tich tu nhieu"; 2..3 "nhe"; <= 1 la
    # "Moi/Nhu moi" (tuoi < 90 ngay) hoac "Duoc cham soc tot".
    param($Age, $Boot, $Startup, $Software, $Residual, $Games, $Sys)
    $v = @{
        LabelKey = 'm7.verdict.good'; ChipKind = 'Ok'
        Mild = 0; Strong = 0; AgeDays = $null
        BootDeltaPct = $null; BootEnough = $false; BootStrong = $false
        StartupNonMs = 0; StartupEnabled = 0
        BloatCount = 0; ResidualCount = 0; ResidualBytes = [long]0
        OldGamesCount = 0; OldGamesBytes = [long]0
        DiskFreePct = $null; PendingCount = 0; Bsod90 = $null
        ReinstallSigns = @(); ReinstallMet = $false
    }
    if ($Age -and $null -ne $Age['AgeDays']) { $v.AgeDays = [int]$Age['AgeDays'] }
    # Boot trend
    if ($Boot -and $Boot['Enough'] -and ($null -ne $Boot['DeltaPct'])) {
        $v.BootDeltaPct = [double]$Boot['DeltaPct']
        $v.BootEnough = $true
        if ($v.BootDeltaPct -gt 50) { $v.Strong++; $v.BootStrong = $true; $v.ReinstallSigns += 'boot' }
        elseif ($v.BootDeltaPct -gt 25) { $v.Mild++ }
    }
    # Startup ngoai Microsoft
    if ($Startup -and ($null -ne $Startup['NonMsCount'])) {
        $v.StartupNonMs = [int]$Startup['NonMsCount']
        $v.StartupEnabled = [int]$Startup['NonMsEnabledCount']
        if ($v.StartupNonMs -gt 15) { $v.Strong++; $v.ReinstallSigns += 'startup' }
        elseif ($v.StartupNonMs -gt 10) { $v.Mild++ }
    }
    # Bloatware
    if ($Software -and $Software['Bloat']) {
        $v.BloatCount = @($Software['Bloat']).Count
        if ($v.BloatCount -ge 2) { $v.Mild++ }
    }
    # Tan du
    if ($Residual -and $Residual['Folders']) {
        $v.ResidualCount = @($Residual['Folders']).Count
        foreach ($f in @($Residual['Folders'])) { $v.ResidualBytes += [long]$f['SizeBytes'] }
        if ($v.ResidualBytes -gt 1GB) { $v.Mild++ }
    }
    # Game lau khong choi (chi la goi y giai phong cho, KHONG tinh dau hieu lao hoa)
    if ($Games) {
        $v.OldGamesCount = [int]$Games['OldGamesCount']
        $v.OldGamesBytes = [long]$Games['OldGamesBytes']
    }
    # O he thong + pending + BSOD
    if ($Sys) {
        if ($null -ne $Sys['DiskFreePct']) {
            $v.DiskFreePct = [double]$Sys['DiskFreePct']
            if ($v.DiskFreePct -lt 10) { $v.Strong++; $v.ReinstallSigns += 'disk' }
            elseif ($v.DiskFreePct -lt 20) { $v.Mild++ }
        }
        if ($null -ne $Sys['PendingCount']) {
            $v.PendingCount = [int]$Sys['PendingCount']
            if ($v.PendingCount -ge 2) { $v.Mild++ }
        }
        if ($null -ne $Sys['BsodCount90']) {
            $v.Bsod90 = [int]$Sys['BsodCount90']
            if ($v.Bsod90 -ge 3) { $v.Strong++; $v.ReinstallSigns += 'bsod' }
        }
    }
    # Nhan ket luan
    $score = $v.Mild + (2 * $v.Strong)
    if ($score -ge 4) {
        $v.LabelKey = 'm7.verdict.heavy'; $v.ChipKind = 'Bad'
    } elseif ($score -ge 2) {
        $v.LabelKey = 'm7.verdict.light'; $v.ChipKind = 'Warn'
    } elseif (($null -ne $v.AgeDays) -and ($v.AgeDays -lt 90)) {
        $v.LabelKey = 'm7.verdict.fresh'; $v.ChipKind = 'Ok'
    } else {
        $v.LabelKey = 'm7.verdict.good'; $v.ChipKind = 'Ok'
    }
    # Chi de xuat "cai lai Windows" khi >= 3 dau hieu khach quan CUNG LUC (spec M7)
    $v.ReinstallMet = ($v.ReinstallSigns.Count -ge 3)
    return $v
}

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
function New-WCM7Panel {
    param($State)
    $root = New-Object Windows.Controls.ScrollViewer
    $root.VerticalScrollBarVisibility = [Windows.Controls.ScrollBarVisibility]::Auto
    $hostPanel = New-WCVStack -Spacing 14
    $hostPanel.Margin = (New-Object Windows.Thickness(20))
    $root.Content = $hostPanel

    # --- Tieu de + nut Quet lai ---
    $top = New-Object Windows.Controls.DockPanel
    $top.LastChildFill = $true
    $rescan = New-WCButton -Text (T 'common.rescan') -OnClick { param($b) Invoke-WCM7Scan $State }.GetNewClosure()
    $rescan.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $rescan.Margin = (New-Object Windows.Thickness(0,0,0,10))
    [Windows.Controls.DockPanel]::SetDock($rescan, [Windows.Dock]::Right)
    $top.Children.Add($rescan) | Out-Null
    $leftStack = New-WCVStack -Spacing 6
    $titleRow = New-WCHStack
    $titleRow.Children.Add((New-WCHeading (T 'm7.title'))) | Out-Null
    $betaChip = New-WCChip -Text (T 'common.beta') -Kind 'Warn'
    $betaChip.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $titleRow.Children.Add($betaChip) | Out-Null
    Add-WCChild $leftStack $titleRow
    Add-WCChild $leftStack (New-WCSubtitle (T 'm7.subtitle'))
    Add-WCChild $leftStack (New-WCTextBlock -Text (T 'm7.fact') -Size 12.5 -ColorKey 'WcSubtle' -Wrap)
    $top.Children.Add($leftStack) | Out-Null
    Add-WCChild $hostPanel $top

    # --- Tao cac section (du lieu ve dan, moi chi bao 1 section rieng) ---
    $defs = @(
        @{ Key = 'verdict';  Title = (T 'm7.verdict.title');  Sub = (T 'm7.verdict.subtitle') }
        @{ Key = 'age';      Title = (T 'm7.age.title');      Sub = (T 'm7.age.hint') }
        @{ Key = 'boot';     Title = (T 'm7.boot.title');     Sub = (T 'm7.boot.hint') }
        @{ Key = 'startup';  Title = (T 'm7.startup.title');  Sub = (T 'm7.startup.hint') }
        @{ Key = 'software'; Title = (T 'm7.software.title'); Sub = (T 'm7.software.hint') }
        @{ Key = 'residual'; Title = (T 'm7.residual.title'); Sub = (T 'm7.residual.hint') }
        @{ Key = 'games';    Title = (T 'm7.games.title');    Sub = (T 'm7.games.hint') }
        @{ Key = 'sys';      Title = (T 'm7.sys.title');      Sub = (T 'm7.sys.hint') }
        @{ Key = 'actions';  Title = (T 'm7.actions.title');  Sub = (T 'm7.actions.hint') }
    )
    foreach ($def in $defs) {
        $sec = New-WCSection -Title $def['Title'] -Subtitle $def['Sub']
        $State['Sections'][$def['Key']] = $sec
        Add-WCChild $hostPanel $sec['Root']
    }
    # Trang thai ban dau: spinner cho cac section du lieu, actions cho text cho
    foreach ($k in @('verdict','age','boot','startup','software','residual','games','sys')) {
        Set-WCM7SectionLoading -State $State -Key $k
    }
    Add-WCChild $State['Sections']['actions']['Body'] (New-WCTextBlock -Text (T 'm7.actions.waiting') -ColorKey 'WcSubtle' -Wrap)
    return $root
}

function Set-WCM7SectionLoading {
    # Dat 1 section ve trang thai "dang tai" (spinner); section ket luan
    # hien chu dac biet "dang thu thap bang chung"
    param($State, [string]$Key)
    $sec = $State['Sections'][$Key]
    if (-not $sec) { return }
    $sec['Body'].Children.Clear()
    $spinner = New-WCSpinner
    if ($Key -eq 'verdict') { $spinner = New-WCSpinner -Text (T 'm7.verdict.waiting') }
    Add-WCChild $sec['Body'] $spinner
}

function Invoke-WCM7Scan {
    # Quet toan bo 7 nguon - moi phan 1 task nen rieng, ve dan tung section
    param($State)
    $ids = @('m7.age','m7.boot','m7.startup','m7.software','m7.residual','m7.games','m7.sys')
    foreach ($id in $ids) {
        if (Test-WCTaskRunning -Id $id) {
            Show-WCToast (T 'common.running' @((T 'm7.title'))) 'Info'
            return
        }
    }
    $State['Data'] = @{}
    $State['Ready'] = @{}
    foreach ($k in @('verdict','age','boot','startup','software','residual','games','sys')) {
        Set-WCM7SectionLoading -State $State -Key $k
    }
    $State['Sections']['actions']['Body'].Children.Clear()
    Add-WCChild $State['Sections']['actions']['Body'] (New-WCTextBlock -Text (T 'm7.actions.waiting') -ColorKey 'WcSubtle' -Wrap)
    Invoke-WCM7ScanAge $State
    Invoke-WCM7ScanBoot $State
    Invoke-WCM7ScanStartup $State
    Invoke-WCM7ScanSoftware $State
    Invoke-WCM7ScanResidual $State
    Invoke-WCM7ScanGames $State
    Invoke-WCM7ScanSys $State
}

function Invoke-WCM7ScanAge {
    param($State)
    Set-WCM7SectionLoading -State $State -Key 'age'
    Start-WCTask -Id 'm7.age' -Title (T 'm7.title') -Worker {
        param($ctx, $s)
        try { return (Get-WCWindowsInstallAge) } catch { return @{ Error = ([string]$_.Exception.Message) } }
    } -Done {
        param($result)
        $State['Data']['age'] = $result
        $State['Ready']['age'] = $true
        Update-WCM7Age $State $result
        Update-WCM7Verdict $State
    }.GetNewClosure() | Out-Null
}

function Invoke-WCM7ScanBoot {
    param($State)
    Set-WCM7SectionLoading -State $State -Key 'boot'
    Start-WCTask -Id 'm7.boot' -Title (T 'm7.title') -Worker {
        param($ctx, $s)
        try { return (Get-WCBootTrend) } catch { return @{ Error = ([string]$_.Exception.Message) } }
    } -Done {
        param($result)
        $State['Data']['boot'] = $result
        $State['Ready']['boot'] = $true
        Update-WCM7Boot $State $result
        Update-WCM7Verdict $State
    }.GetNewClosure() | Out-Null
}

function Invoke-WCM7ScanStartup {
    param($State)
    Set-WCM7SectionLoading -State $State -Key 'startup'
    Start-WCTask -Id 'm7.startup' -Title (T 'm7.title') -Worker {
        param($ctx, $s)
        try { return (Get-WCStartupEntries) } catch { return @{ Error = ([string]$_.Exception.Message) } }
    } -Done {
        param($result)
        $State['Data']['startup'] = $result
        $State['Ready']['startup'] = $true
        Update-WCM7Startup $State $result
        Update-WCM7Verdict $State
    }.GetNewClosure() | Out-Null
}

function Invoke-WCM7ScanSoftware {
    param($State)
    Set-WCM7SectionLoading -State $State -Key 'software'
    Start-WCTask -Id 'm7.software' -Title (T 'm7.title') -Worker {
        param($ctx, $s)
        try {
            $sw = Get-WCInstalledSoftware
            $sw['Bloat'] = @(Get-WCOemBloatCandidates -Apps $sw['Apps'])
            return $sw
        } catch { return @{ Error = ([string]$_.Exception.Message) } }
    } -Done {
        param($result)
        $State['Data']['software'] = $result
        $State['Ready']['software'] = $true
        Update-WCM7Software $State $result
        # Ve lai muc Tan du de hien "Uninstall mo coi" (du lieu tu khoa Uninstall)
        if ($State['Ready'].ContainsKey('residual') -and $State['Data'].ContainsKey('residual')) {
            Update-WCM7Residual $State $State['Data']['residual']
        }
        Update-WCM7Verdict $State
    }.GetNewClosure() | Out-Null
}

function Invoke-WCM7ScanResidual {
    param($State)
    Set-WCM7SectionLoading -State $State -Key 'residual'
    Start-WCTask -Id 'm7.residual' -Title (T 'm7.title') -Worker {
        param($ctx, $s)
        try { return (Get-WCResidualCandidates) } catch { return @{ Error = ([string]$_.Exception.Message) } }
    } -Done {
        param($result)
        $State['Data']['residual'] = $result
        $State['Ready']['residual'] = $true
        Update-WCM7Residual $State $result
        Update-WCM7Verdict $State
    }.GetNewClosure() | Out-Null
}

function Invoke-WCM7ScanGames {
    param($State)
    Set-WCM7SectionLoading -State $State -Key 'games'
    Start-WCTask -Id 'm7.games' -Title (T 'm7.title') -Worker {
        param($ctx, $s)
        try { return (Get-WCGamesInfo) } catch { return @{ Error = ([string]$_.Exception.Message) } }
    } -Done {
        param($result)
        $State['Data']['games'] = $result
        $State['Ready']['games'] = $true
        Update-WCM7Games $State $result
        Update-WCM7Verdict $State
    }.GetNewClosure() | Out-Null
}

function Invoke-WCM7ScanSys {
    param($State)
    Set-WCM7SectionLoading -State $State -Key 'sys'
    Start-WCTask -Id 'm7.sys' -Title (T 'm7.title') -Worker {
        param($ctx, $s)
        try { return (Get-WCSystemAccumulation) } catch { return @{ Error = ([string]$_.Exception.Message) } }
    } -Done {
        param($result)
        $State['Data']['sys'] = $result
        $State['Ready']['sys'] = $true
        Update-WCM7Sys $State $result
        Update-WCM7Verdict $State
    }.GetNewClosure() | Out-Null
}

function Update-WCM7Age {
    param($State, $Data)
    $body = $State['Sections']['age']['Body']
    $body.Children.Clear()
    if ($null -eq $Data) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.age.unknown') -ColorKey 'WcSubtle' -Wrap)
        return
    }
    if ($Data['Error']) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.nodata.reason' @([string]$Data['Error'])) -ColorKey 'WcSubtle' -Wrap)
        return
    }
    $d = $Data['InstallDate']
    $ageTxt = T 'fmt.days' @([string]$Data['AgeDays'])
    $dateTxt = ''
    try { $dateTxt = $d.ToString('yyyy-MM-dd') } catch { $dateTxt = '?' }
    Add-WCChild $body (New-WCTextBlock -Text (T 'm7.age.value' @($dateTxt, $ageTxt)) -Size 13.5 -Weight 'SemiBold' -Wrap)
    Add-WCChild $body (New-WCTextBlock -Text (T 'm7.age.note') -Size 12 -ColorKey 'WcSubtle' -Wrap)
}

function Update-WCM7Boot {
    param($State, $Data)
    $body = $State['Sections']['boot']['Body']
    $body.Children.Clear()
    if ($null -eq $Data) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.boot.nodata') -ColorKey 'WcSubtle' -Wrap)
        return
    }
    if ($Data['Error']) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.boot.nodata') -ColorKey 'WcSubtle' -Wrap)
        return
    }
    $buckets = $Data['Buckets']
    $b30 = $buckets['30']; $b90 = $buckets['90']; $b180 = $buckets['180']
    $hasData = (($b30.Count -gt 0) -or ($b90.Count -gt 0) -or ($b180.Count -gt 0))
    if (-not $hasData) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.boot.nodata') -ColorKey 'WcSubtle' -Wrap)
        return
    }
    # Text-bar: moi bucket 1 dong, do dai thanh ~ trung vi / max toan bo
    $scaleMax = [double]0
    foreach ($k in @('30','90','180')) {
        $b = $buckets[$k]
        if ($null -ne $b['MaxMs']) { if ([double]$b['MaxMs'] -gt $scaleMax) { $scaleMax = [double]$b['MaxMs'] } }
    }
    $lines = @()
    foreach ($k in @('30','90','180')) {
        $b = $buckets[$k]
        $barLen = 0
        if (($null -ne $b['MedianMs']) -and ($scaleMax -gt 0)) {
            $barLen = [int][math]::Ceiling(([double]$b['MedianMs'] / $scaleMax) * 36.0)
        }
        $bar = ''
        for ($i = 0; $i -lt $barLen; $i++) { $bar += [char]0x2588 }
        $medTxt = '-'
        if ($null -ne $b['MedianMs']) { $medTxt = ('{0:N0} ms' -f [double]$b['MedianMs']) }
        $lines += ('{0,-20} {1}  {2}' -f (T ('m7.boot.bucket.' + $k)), $bar, $medTxt)
    }
    $barTb = New-WCTextBlock -Text ([string]::Join("`n", $lines)) -Size 12.5
    $barTb.FontFamily = New-Object Windows.Media.FontFamily('Consolas')
    Add-WCChild $body $barTb
    # Bang so
    $table = New-WCTable -Columns @(
        @{ Header = (T 'm7.boot.col.bucket'); Prop = 'C0'; Width = 170 }
        @{ Header = (T 'm7.boot.col.count');  Prop = 'C1'; Width = 110 }
        @{ Header = (T 'm7.boot.col.median'); Prop = 'C2'; Width = 120 }
        @{ Header = (T 'm7.boot.col.max');    Prop = 'C3'; Width = 120 }
    )
    foreach ($k in @('30','90','180')) {
        $b = $buckets[$k]
        $row = [PSCustomObject]@{
            C0 = (T ('m7.boot.bucket.' + $k))
            C1 = [string]$b['Count']
            C2 = ($(if ($null -ne $b['MedianMs']) { '{0:N0}' -f [double]$b['MedianMs'] } else { '-' }))
            C3 = ($(if ($null -ne $b['MaxMs']) { '{0:N0}' -f [double]$b['MaxMs'] } else { '-' }))
        }
        $table.Items.Add($row) | Out-Null
    }
    Add-WCChild $body $table
    # So sanh trung vi 30 ngay vs 90 ngay
    if ($Data['Enough'] -and ($null -ne $Data['DeltaPct'])) {
        $pct = [double]$Data['DeltaPct']
        $m30 = [double]$b30['MedianMs']; $m90 = [double]$b90['MedianMs']
        $cmpText = ''
        if ($pct -gt 5) { $cmpText = (T 'm7.boot.up' @([string][math]::Abs($pct), ('{0:N0}' -f $m90), ('{0:N0}' -f $m30))) }
        elseif ($pct -lt -5) { $cmpText = (T 'm7.boot.down' @([string][math]::Abs($pct), ('{0:N0}' -f $m90), ('{0:N0}' -f $m30))) }
        else { $cmpText = (T 'm7.boot.flat' @([string]$pct)) }
        Add-WCChild $body (New-WCTextBlock -Text $cmpText -Size 13 -Wrap)
    } else {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.boot.compare.nodata') -Size 12.5 -ColorKey 'WcSubtle' -Wrap)
    }
    # Sparkline nhung lan khoi dong gan day (cu -> moi)
    $boots = @($Data['Boots'] | Sort-Object -Property { $_['Time'] })
    if ($boots.Count -gt 1) {
        $recent = $boots
        if ($boots.Count -gt 24) { $recent = @($boots[($boots.Count - 24)..($boots.Count - 1)]) }
        $mx = [double]0
        foreach ($b in $recent) { if ([double]$b['TotalMs'] -gt $mx) { $mx = [double]$b['TotalMs'] } }
        if ($mx -gt 0) {
            $spark = ''
            foreach ($b in $recent) {
                $n = [int][math]::Ceiling(([double]$b['TotalMs'] / $mx) * 9.0)
                if ($n -lt 1) { $n = 1 }
                $spark += ([string]([char]0x2588) * $n) + ' '
            }
            Add-WCChild $body (New-WCTextBlock -Text (T 'm7.boot.recent') -Size 11.5 -ColorKey 'WcSubtle')
            $sparkTb = New-WCTextBlock -Text $spark -Size 11.5 -Wrap
            $sparkTb.FontFamily = New-Object Windows.Media.FontFamily('Consolas')
            Add-WCChild $body $sparkTb
        }
    }
    Add-WCChild $body (New-WCTextBlock -Text ((T 'm7.boot.count' @([string]$Data['SampleCount']))) -Size 12 -ColorKey 'WcSubtle' -Wrap)
    Add-WCChild $body (New-WCTextBlock -Text (T 'm7.boot.source') -Size 11 -ColorKey 'WcSubtle' -Wrap)
}

function Update-WCM7Startup {
    param($State, $Data)
    $body = $State['Sections']['startup']['Body']
    $body.Children.Clear()
    if ($null -eq $Data -or $Data['Error']) {
        $reason = ''
        if ($Data -and $Data['Error']) { $reason = [string]$Data['Error'] }
        $txt = (T 'common.nodata')
        if ($reason) { $txt = (T 'm7.nodata.reason' @($reason)) }
        Add-WCChild $body (New-WCTextBlock -Text $txt -ColorKey 'WcSubtle' -Wrap)
        return
    }
    $entries = @($Data['Entries'])
    $msCount = @($entries | Where-Object { $_['IsMicrosoft'] }).Count
    Add-WCChild $body (New-WCTextBlock -Text (T 'm7.startup.count' @([string]$Data['NonMsCount'], [string]$Data['NonMsEnabledCount'])) -Size 13.5 -Weight 'SemiBold' -Wrap)
    if ($msCount -gt 0) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.startup.mscount' @([string]$msCount)) -Size 12 -ColorKey 'WcSubtle' -Wrap)
    }
    Add-WCChild $body (New-WCTextBlock -Text (T 'm7.startup.decode.note') -Size 11 -ColorKey 'WcSubtle' -Wrap)
    if ($entries.Count -eq 0) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.startup.empty') -Size 12.5 -ColorKey 'WcSubtle' -Wrap)
    } else {
        # Danh sach tick: muc Run/StartupFolder (tat/bat duoc qua StartupApproved)
        $list = New-WCCheckList
        $State['StartupList'] = $list
        $sorted = @($entries | Sort-Object -Property { $(if ($_['IsMicrosoft']) { 1 } else { 0 }) }, { $_['Name'] })
        foreach ($e in $sorted) {
            $name = [string]$e['Name']
            if ($e['IsMicrosoft']) { $name = $name + ' (' + (T 'm7.startup.msbadge') + ')' }
            $cmd = [string]$e['Command']
            if ($cmd.Length -gt 70) { $cmd = $cmd.Substring(0, 67) + '...' }
            $chipKind = 'Ok'; $chipTxt = (T 'm7.startup.on')
            if ($e['State'] -eq 'Disabled') { $chipKind = 'Plain'; $chipTxt = (T 'm7.startup.off') }
            Add-WCCheckRow -List $list -Item $e -Checked:$false -TextColumns @($name, $cmd) -ChipText $chipTxt -ChipKind $chipKind
        }
        Add-WCChild $body $list
        $btnRow = New-WCHStack
        $offBtn = New-WCButton -Text (T 'm7.startup.toggle.off') -OnClick { param($b) Invoke-WCM7ToggleStartup $State $false }.GetNewClosure()
        $onBtn = New-WCButton -Text (T 'm7.startup.toggle.on') -OnClick { param($b) Invoke-WCM7ToggleStartup $State $true }.GetNewClosure()
        $btnRow.Children.Add($offBtn) | Out-Null
        $btnRow.Children.Add($onBtn) | Out-Null
        Add-WCChild $body $btnRow
    }
    # Tac vu + dich vu (chi liet ke - khong bat/tat qua StartupApproved)
    $tasks = @($Data['Tasks'])
    $services = @($Data['Services'])
    if (($tasks.Count -gt 0) -or ($services.Count -gt 0)) {
        $exp = New-WCExpander -Title (T 'm7.startup.tasks.title') -Summary (T 'm7.startup.tasks.summary' @([string]$tasks.Count, [string]$services.Count))
        $t = New-WCTable -Columns @(
            @{ Header = (T 'm7.startup.col.name');  Prop = 'C0'; Width = 300 }
            @{ Header = (T 'm7.startup.col.type');  Prop = 'C1'; Width = 90 }
            @{ Header = (T 'm7.startup.col.state'); Prop = 'C2'; Width = 110 }
        )
        $maxRows = 40; $added = 0
        foreach ($tk in $tasks) {
            if ($added -ge $maxRows) { break }
            $t.Items.Add([PSCustomObject]@{ C0 = ($tk['TaskPath'] + $tk['Name']); C1 = (T 'm7.startup.type.task'); C2 = [string]$tk['State'] }) | Out-Null
            $added++
        }
        foreach ($sv in $services) {
            if ($added -ge $maxRows) { break }
            $t.Items.Add([PSCustomObject]@{ C0 = $sv['DisplayName']; C1 = (T 'm7.startup.type.service'); C2 = [string]$sv['State'] }) | Out-Null
            $added++
        }
        Add-WCChild $exp['Body'] $t
        $total = $tasks.Count + $services.Count
        if ($total -gt $maxRows) {
            Add-WCChild $exp['Body'] (New-WCTextBlock -Text (T 'm7.startup.more' @([string]($total - $maxRows))) -Size 11.5 -ColorKey 'WcSubtle')
        }
        Add-WCChild $exp['Body'] (New-WCTextBlock -Text (T 'm7.startup.tasks.hint') -Size 11 -ColorKey 'WcSubtle' -Wrap)
        Add-WCChild $body $exp['Root']
    }
}

function Update-WCM7Software {
    param($State, $Data)
    $body = $State['Sections']['software']['Body']
    $body.Children.Clear()
    if ($null -eq $Data -or $Data['Error']) {
        $reason = ''
        if ($Data -and $Data['Error']) { $reason = [string]$Data['Error'] }
        $txt = (T 'common.nodata')
        if ($reason) { $txt = (T 'm7.nodata.reason' @($reason)) }
        Add-WCChild $body (New-WCTextBlock -Text $txt -ColorKey 'WcSubtle' -Wrap)
        return
    }
    Add-WCChild $body (New-WCTextBlock -Text (T 'm7.software.count' @([string]$Data['Total'])) -Size 13.5 -Weight 'SemiBold' -Wrap)
    # Ung vien OEM/bloatware - chi DE XUAT, nut Go mo trinh go chinh thuc
    $bloat = @($Data['Bloat'])
    Add-WCChild $body (New-WCTextBlock -Text (T 'm7.software.bloat.title') -Size 13 -Weight 'SemiBold')
    if ($bloat.Count -eq 0) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.software.bloat.empty') -Size 12.5 -ColorKey 'WcSubtle' -Wrap)
    } else {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.software.bloat.hint') -Size 11 -ColorKey 'WcSubtle' -Wrap)
        foreach ($item in $bloat) {
            Add-WCChild $body (New-WCM7SoftwareRow -Item $item)
        }
    }
}

function New-WCM7SoftwareRow {
    # 1 dong ung vien bloatware: ten + nha phat hanh + ngay cai + nut "Go"
    param($Item)
    $row = New-Object Windows.Controls.Border
    $row.Style = (Get-WCControlStyles)['WcListItem']
    $dock = New-Object Windows.Controls.DockPanel
    $dock.LastChildFill = $true
    $btn = New-WCButton -Text (T 'm7.software.uninstall') -Small -OnClick { param($b) Invoke-WCM7Uninstall $Item }.GetNewClosure()
    $btn.VerticalAlignment = [Windows.VerticalAlignment]::Center
    [Windows.Controls.DockPanel]::SetDock($btn, [Windows.Dock]::Right)
    $dock.Children.Add($btn) | Out-Null
    $stack = New-WCVStack -Spacing 2
    Add-WCChild $stack (New-WCTextBlock -Text ([string]$Item['DisplayName']) -Size 13 -Weight 'SemiBold' -Wrap)
    $meta = [string]$Item['Publisher']
    if (-not [string]::IsNullOrEmpty([string]$Item['InstallDateText'])) {
        $meta = $meta + '  ·  ' + (T 'm7.software.installedon' @([string]$Item['InstallDateText']))
    }
    Add-WCChild $stack (New-WCTextBlock -Text $meta -Size 11.5 -ColorKey 'WcSubtle' -Wrap)
    $dock.Child = $stack
    $row.Child = $dock
    return $row
}

function Update-WCM7Residual {
    param($State, $Data)
    $body = $State['Sections']['residual']['Body']
    $body.Children.Clear()
    if ($null -eq $Data -or $Data['Error']) {
        $reason = ''
        if ($Data -and $Data['Error']) { $reason = [string]$Data['Error'] }
        $txt = (T 'common.nodata')
        if ($reason) { $txt = (T 'm7.nodata.reason' @($reason)) }
        Add-WCChild $body (New-WCTextBlock -Text $txt -ColorKey 'WcSubtle' -Wrap)
        return
    }
    $folders = @($Data['Folders'])
    if ($folders.Count -eq 0) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.residual.empty') -Size 12.5 -ColorKey 'WcSubtle' -Wrap)
    } else {
        # Mac dinh KHONG tick (spec M7 - de bao nham)
        $list = New-WCCheckList
        $State['ResidualList'] = $list
        $maxRows = 25
        $idx = 0
        foreach ($f in $folders) {
            if ($idx -ge $maxRows) { break }
            Add-WCCheckRow -List $list -Item $f -Checked:$false -TextColumns @(
                ([string]$f['Name']),
                ([string]$f['Root']),
                (ConvertTo-WCHumanSize ([long]$f['SizeBytes']))
            )
            $idx++
        }
        Add-WCChild $body $list
        if ($folders.Count -gt $maxRows) {
            Add-WCChild $body (New-WCTextBlock -Text (T 'm7.residual.more' @([string]($folders.Count - $maxRows))) -Size 11.5 -ColorKey 'WcSubtle')
        }
        $btnRow = New-WCHStack
        $openBtn = New-WCButton -Text (T 'm7.residual.open') -OnClick { param($b) Invoke-WCM7OpenResidualSelected $State }.GetNewClosure()
        $delBtn = New-WCButton -Text (T 'm7.residual.delete') -Kind Danger -OnClick { param($b) Invoke-WCM7DeleteResidual $State }.GetNewClosure()
        $btnRow.Children.Add($openBtn) | Out-Null
        $btnRow.Children.Add($delBtn) | Out-Null
        Add-WCChild $body $btnRow
    }
    # Muc Uninstall mo coi trong registry (key khong DisplayName) - CHI BAO CAO
    # (du lieu lay tu task phan mem; ve lai khi ca hai phan deu ve)
    $swData = $null
    if ($State['Data'].ContainsKey('software')) { $swData = $State['Data']['software'] }
    $orphans = @()
    if ($swData -and $swData['OrphanKeys']) { $orphans = @($swData['OrphanKeys']) }
    if ($orphans.Count -gt 0) {
        $exp = New-WCExpander -Title (T 'm7.residual.orphan.title') -Summary ([string]$orphans.Count)
        $maxOrphan = 20
        $i = 0
        foreach ($o in $orphans) {
            if ($i -ge $maxOrphan) { break }
            Add-WCChild $exp['Body'] (New-WCTextBlock -Text ([string]$o['KeyName']) -Size 11.5 -ColorKey 'WcSubtle')
            $i++
        }
        Add-WCChild $exp['Body'] (New-WCTextBlock -Text (T 'm7.residual.orphan.hint') -Size 11 -ColorKey 'WcSubtle' -Wrap)
        Add-WCChild $body $exp['Root']
    }
}

function Update-WCM7Games {
    param($State, $Data)
    $body = $State['Sections']['games']['Body']
    $body.Children.Clear()
    if ($null -eq $Data -or $Data['Error']) {
        $reason = ''
        if ($Data -and $Data['Error']) { $reason = [string]$Data['Error'] }
        $txt = (T 'common.nodata')
        if ($reason) { $txt = (T 'm7.nodata.reason' @($reason)) }
        Add-WCChild $body (New-WCTextBlock -Text $txt -ColorKey 'WcSubtle' -Wrap)
        return
    }
    $games = @($Data['Games'])
    $steamCount = @($games | Where-Object { $_['Source'] -eq 'Steam' }).Count
    # Trang thai phat hien launcher (khong cai -> khong loi)
    if ($Data['SteamInstalled']) {
        $libs = @(Get-WCSteamLibraryPaths -SteamRoot $Data['SteamRoot'])
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.games.steam.ok' @([string]$libs.Count, [string]$steamCount)) -Size 12.5 -Wrap)
    } else {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.games.steam.none') -Size 12.5 -ColorKey 'WcSubtle' -Wrap)
    }
    if ($Data['EpicInstalled']) {
        $epicCount = @($games | Where-Object { $_['Source'] -eq 'Epic' }).Count
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.games.epic.ok' @([string]$epicCount)) -Size 12.5 -Wrap)
    } else {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.games.epic.none') -Size 12.5 -ColorKey 'WcSubtle' -Wrap)
    }
    if ($games.Count -eq 0) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.games.empty') -Size 12.5 -ColorKey 'WcSubtle' -Wrap)
    } else {
        $t = New-WCTable -Columns @(
            @{ Header = (T 'm7.games.col.name');  Prop = 'C0'; Width = 240 }
            @{ Header = (T 'm7.games.col.source'); Prop = 'C1'; Width = 110 }
            @{ Header = (T 'm7.games.col.size');  Prop = 'C2'; Width = 100 }
            @{ Header = (T 'm7.games.col.last');  Prop = 'C3'; Width = 110 }
            @{ Header = (T 'm7.games.col.drive'); Prop = 'C4'; Width = 80 }
        )
        $maxRows = 40; $added = 0
        $sorted = @($games | Sort-Object -Property { [long]$_['SizeBytes'] } -Descending)
        foreach ($g in $sorted) {
            if ($added -ge $maxRows) { break }
            $src = [string]$g['Source']
            if ($src -eq 'Other') { $src = (T 'm7.games.source.other') }
            $lastTxt = (T 'm7.games.last.unknown')
            $lp = $g['LastPlayed']
            if (($null -ne $lp) -and ($lp -is [DateTime])) { $lastTxt = $lp.ToString('yyyy-MM-dd') }
            $sizeTxt = '-'
            if ([long]$g['SizeBytes'] -gt 0) { $sizeTxt = (ConvertTo-WCHumanSize ([long]$g['SizeBytes'])) }
            $driveTxt = [string]$g['Drive']
            if ([string]::IsNullOrEmpty($driveTxt)) { $driveTxt = '-' }
            $t.Items.Add([PSCustomObject]@{
                C0 = [string]$g['Name']; C1 = $src; C2 = $sizeTxt; C3 = $lastTxt; C4 = $driveTxt
            }) | Out-Null
            $added++
        }
        Add-WCChild $body $t
        if ($games.Count -gt $maxRows) {
            Add-WCChild $body (New-WCTextBlock -Text (T 'm7.games.more' @([string]($games.Count - $maxRows))) -Size 11.5 -ColorKey 'WcSubtle')
        }
    }
    # Cac goi y (chi hien khi co du lieu tuong ung - khong doa)
    if ($Data['OldGamesCount'] -gt 0) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.games.old.total' @([string]$Data['OldGamesCount'], (ConvertTo-WCHumanSize ([long]$Data['OldGamesBytes'])))) -Size 12.5 -Wrap)
    }
    $hdd = @($Data['HddGames'])
    if ($hdd.Count -gt 0) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.games.hdd' @([string]::Join(', ', $hdd))) -Size 12.5 -Wrap)
    }
    $launchers = @($Data['LauncherInStartup'])
    if ($launchers.Count -gt 0) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.games.launcher' @([string]::Join(', ', $launchers))) -Size 12.5 -Wrap)
    }
    if (($null -ne $Data['ShaderD3DBytes']) -or ($null -ne $Data['ShaderGlBytes'])) {
        $d3dTxt = (T 'common.na'); $glTxt = (T 'common.na')
        if ($null -ne $Data['ShaderD3DBytes']) { $d3dTxt = (ConvertTo-WCHumanSize ([long]$Data['ShaderD3DBytes'])) }
        if ($null -ne $Data['ShaderGlBytes']) { $glTxt = (ConvertTo-WCHumanSize ([long]$Data['ShaderGlBytes'])) }
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.games.shader' @($d3dTxt, $glTxt)) -Size 12.5 -Wrap)
    }
    if (($null -ne $Data['GpuDriverDays']) -and (-not [string]::IsNullOrEmpty([string]$Data['GpuName']))) {
        $gpuTxt = $null
        if ([int]$Data['GpuDriverDays'] -gt 365) {
            $gpuTxt = (T 'm7.games.gpu.old' @([string]$Data['GpuName'], [string]$Data['GpuDriverDays']))
        } else {
            $gpuTxt = (T 'm7.games.gpu.ok' @([string]$Data['GpuName'], [string]$Data['GpuDriverDays']))
        }
        Add-WCChild $body (New-WCTextBlock -Text $gpuTxt -Size 12.5 -Wrap)
    }
    # Nut mo launcher (go/chuyen game CHI qua launcher)
    if ($Data['SteamInstalled'] -or $Data['EpicInstalled']) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.games.uninstall.note') -Size 11 -ColorKey 'WcSubtle' -Wrap)
        $btnRow = New-WCHStack
        if ($Data['SteamInstalled']) {
            $steamRootRef = [string]$Data['SteamRoot']
            $btnRow.Children.Add((New-WCButton -Text (T 'm7.games.open.steam') -OnClick { param($b) Invoke-WCM7OpenLauncher -Kind 'steam' -FallbackExe (Join-Path $steamRootRef 'steam.exe') }.GetNewClosure())) | Out-Null
        }
        if ($Data['EpicInstalled']) {
            $btnRow.Children.Add((New-WCButton -Text (T 'm7.games.open.epic') -OnClick { param($b) Invoke-WCM7OpenLauncher -Kind 'epic' -FallbackExe '' }.GetNewClosure())) | Out-Null
        }
        Add-WCChild $body $btnRow
    }
}

function Update-WCM7Sys {
    param($State, $Data)
    $body = $State['Sections']['sys']['Body']
    $body.Children.Clear()
    if ($null -eq $Data -or $Data['Error']) {
        $reason = ''
        if ($Data -and $Data['Error']) { $reason = [string]$Data['Error'] }
        $txt = (T 'common.nodata')
        if ($reason) { $txt = (T 'm7.nodata.reason' @($reason)) }
        Add-WCChild $body (New-WCTextBlock -Text $txt -ColorKey 'WcSubtle' -Wrap)
        return
    }
    # Co cho khoi dong lai
    $flags = @($Data['PendingFlags'])
    if ($flags.Count -eq 0) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.sys.pending.ok') -Size 12.5 -Wrap)
    } else {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.sys.pending.list' @([string]::Join(', ', $flags))) -Size 12.5 -Wrap)
    }
    # Lan bao tri tu dong gan nhat
    if ($null -ne $Data['MaintenanceLastRun']) {
        $dTxt = ''
        try { $dTxt = ([datetime]$Data['MaintenanceLastRun']).ToString('yyyy-MM-dd HH:mm') } catch { $dTxt = '?' }
        $daysTxt = T 'fmt.days' @([string]$Data['MaintenanceDays'])
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.sys.maintenance.label' @($dTxt, $daysTxt)) -Size 12.5 -Wrap)
    } else {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.sys.maintenance.none') -Size 12.5 -Wrap)
    }
    # O he thong
    if ($null -ne $Data['DiskFreePct']) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.sys.disk' @([string]$Data['DiskFreePct'])) -Size 12.5 -Wrap)
    }
    # BSOD 90 ngay
    if ($null -eq $Data['BsodCount90']) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.sys.bsod.nodata') -Size 12.5 -Wrap)
    } elseif ([int]$Data['BsodCount90'] -eq 0) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.sys.bsod.none') -Size 12.5 -Wrap)
    } else {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.sys.bsod.some' @([string]$Data['BsodCount90'])) -Size 12.5 -Wrap)
    }
}

function Update-WCM7Verdict {
    # Chi render ket luan khi CA 7 phan da ve (moi phan tu them goi ham nay)
    param($State)
    foreach ($k in @('age','boot','startup','software','residual','games','sys')) {
        if (-not $State['Ready'].ContainsKey($k)) { return }
    }
    $d = $State['Data']
    $v = Get-WCAgingVerdict -Age $d['age'] -Boot $d['boot'] -Startup $d['startup'] `
        -Software $d['software'] -Residual $d['residual'] -Games $d['games'] -Sys $d['sys']
    $body = $State['Sections']['verdict']['Body']
    $body.Children.Clear()
    # Nhan ket luan (chip + 1 cau)
    $chip = New-WCChip -Text (T $v['LabelKey']) -Kind ([string]$v['ChipKind'])
    Add-WCChild $body $chip
    $sum = ''
    $ageDaysTxt = (T 'common.unknown')
    if ($null -ne $v['AgeDays']) { $ageDaysTxt = (T 'fmt.days' @([string]$v['AgeDays'])) }
    switch ($v['LabelKey']) {
        'm7.verdict.fresh' { $sum = (T 'm7.verdict.fresh.sum' @($ageDaysTxt)) }
        'm7.verdict.good'  { $sum = (T 'm7.verdict.good.sum' @($ageDaysTxt)) }
        'm7.verdict.light' { $sum = (T 'm7.verdict.light.sum') }
        'm7.verdict.heavy' { $sum = (T 'm7.verdict.heavy.sum' @([string]$v['Strong'], [string]$v['Mild'])) }
    }
    Add-WCChild $body (New-WCTextBlock -Text $sum -Size 13.5 -Wrap)
    # Bang bang chung: chi bao | so lieu | nguon | y nghia
    Add-WCChild $body (New-WCTextBlock -Text (T 'm7.verdict.evidence') -Size 13 -Weight 'SemiBold')
    $table = New-WCTable -Columns @(
        @{ Header = (T 'm7.col.indicator'); Prop = 'C0'; Width = 180 }
        @{ Header = (T 'm7.col.value');     Prop = 'C1'; Width = 250 }
        @{ Header = (T 'm7.col.source');    Prop = 'C2'; Width = 220 }
        @{ Header = (T 'm7.col.meaning');   Prop = 'C3'; Width = 250 }
    )
    # --- hang: tuoi ---
    $ageVal = (T 'common.nodata')
    if ($null -ne $v['AgeDays']) { $ageVal = (T 'fmt.days' @([string]$v['AgeDays'])) }
    $table.Items.Add([PSCustomObject]@{ C0 = (T 'm7.ev.age'); C1 = $ageVal; C2 = (T 'm7.src.registry'); C3 = (T 'm7.ev.age.mean') }) | Out-Null
    # --- hang: boot ---
    $bootVal = (T 'common.nodata')
    $bootMean = (T 'm7.ev.boot.mean.ok')
    if ($v['BootEnough']) {
        $pct = [double]$v['BootDeltaPct']
        if ($pct -gt 5) { $bootVal = (T 'm7.ev.boot.up' @([string]$pct)) }
        elseif ($pct -lt -5) { $bootVal = (T 'm7.ev.boot.down' @([string][math]::Abs($pct))) }
        else { $bootVal = (T 'm7.ev.boot.flat' @([string]$pct)) }
        if ($pct -gt 25) { $bootMean = (T 'm7.ev.boot.mean.sign') }
    }
    $table.Items.Add([PSCustomObject]@{ C0 = (T 'm7.ev.boot'); C1 = $bootVal; C2 = (T 'm7.src.event100'); C3 = $bootMean }) | Out-Null
    # --- hang: startup ---
    $stMean = (T 'm7.ev.startup.mean.ok')
    if ($v['StartupNonMs'] -gt 10) { $stMean = (T 'm7.ev.startup.mean.sign') }
    $table.Items.Add([PSCustomObject]@{
        C0 = (T 'm7.ev.startup')
        C1 = (T 'm7.ev.startup.value' @([string]$v['StartupNonMs'], [string]$v['StartupEnabled']))
        C2 = (T 'm7.src.runkeys'); C3 = $stMean }) | Out-Null
    # --- hang: bloatware ---
    $table.Items.Add([PSCustomObject]@{ C0 = (T 'm7.ev.bloat'); C1 = [string]$v['BloatCount']; C2 = (T 'm7.src.uninstall'); C3 = (T 'm7.ev.bloat.mean') }) | Out-Null
    # --- hang: tan du ---
    $table.Items.Add([PSCustomObject]@{
        C0 = (T 'm7.ev.residual')
        C1 = (T 'm7.ev.residual.value' @([string]$v['ResidualCount'], (ConvertTo-WCHumanSize ([long]$v['ResidualBytes']))))
        C2 = (T 'm7.src.folders'); C3 = (T 'm7.ev.residual.mean') }) | Out-Null
    # --- hang: game lau khong choi ---
    $table.Items.Add([PSCustomObject]@{
        C0 = (T 'm7.ev.games')
        C1 = (T 'm7.ev.games.value' @([string]$v['OldGamesCount'], (ConvertTo-WCHumanSize ([long]$v['OldGamesBytes']))))
        C2 = (T 'm7.src.manifest'); C3 = (T 'm7.ev.games.mean') }) | Out-Null
    # --- hang: o he thong ---
    if ($null -ne $v['DiskFreePct']) {
        $diskMean = (T 'm7.ev.disk.mean.ok')
        if ([double]$v['DiskFreePct'] -lt 20) { $diskMean = (T 'm7.ev.disk.mean.low') }
        $table.Items.Add([PSCustomObject]@{
            C0 = (T 'm7.ev.disk'); C1 = ('{0}%' -f [string]$v['DiskFreePct'])
            C2 = (T 'm7.src.logicaldisk'); C3 = $diskMean }) | Out-Null
    }
    # --- hang: co cho khoi dong lai ---
    $table.Items.Add([PSCustomObject]@{ C0 = (T 'm7.ev.pending'); C1 = [string]$v['PendingCount']; C2 = (T 'm7.src.rebootkeys'); C3 = (T 'm7.ev.pending.mean') }) | Out-Null
    # --- hang: BSOD ---
    if ($null -ne $v['Bsod90']) {
        $table.Items.Add([PSCustomObject]@{ C0 = (T 'm7.ev.bsod'); C1 = [string]$v['Bsod90']; C2 = (T 'm7.src.system1001'); C3 = (T 'm7.ev.bsod.mean') }) | Out-Null
    }
    Add-WCChild $body $table
    # Render luon huong xu ly
    Update-WCM7Actions -State $State -Verdict $v
}

function New-WCM7ActionCard {
    # The 1 huong xu ly: tieu de + chip muc rui ro + mo ta (tra @{Root;Body})
    param([string]$Title, [string]$Desc, [string]$Risk)
    $risk = Get-WCRiskInfo -Risk $Risk
    $row = New-Object Windows.Controls.Border
    $row.CornerRadius = (New-Object Windows.CornerRadius(8))
    $row.BorderThickness = (New-Object Windows.Thickness(1))
    $row.Padding = (New-Object Windows.Thickness(12))
    $row.Margin = (New-Object Windows.Thickness(0,4,0,4))
    $row.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'WcCardBg2')
    $row.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'WcBorder')
    $inner = New-WCVStack -Spacing 4
    $top = New-WCHStack
    $t = New-WCTextBlock -Text $Title -Size 13.5 -Weight 'SemiBold'
    $t.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $top.Children.Add($t) | Out-Null
    $chip = New-WCChip -Text $risk.Text -Kind ($risk.Brush.Replace('Wc', ''))
    $chip.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $top.Children.Add($chip) | Out-Null
    Add-WCChild $inner $top
    Add-WCChild $inner (New-WCTextBlock -Text $Desc -Size 12 -ColorKey 'WcSubtle' -Wrap)
    $row.Child = $inner
    return @{ Root = $row; Body = $inner }
}

function Update-WCM7Actions {
    # 3 huong xu ly xep theo rui ro tang dan (spec M7);
    # huong 3 chi hien khi >= 3 dau hieu khach quan cung luc.
    param($State, $Verdict)
    $body = $State['Sections']['actions']['Body']
    $body.Children.Clear()
    # Huong 1: KHUYEN NGH
    $c1 = New-WCM7ActionCard -Title (T 'm7.actions.1.title') -Desc (T 'm7.actions.1.desc') -Risk 'Recommended'
    $btnM2 = New-WCButton -Text (T 'm7.actions.1.btn') -Kind Primary -Small -OnClick { param($b) Invoke-WCShowNav 'm2' }.GetNewClosure()
    Add-WCChild $c1['Body'] $btnM2
    Add-WCChild $body $c1['Root']
    # Huong 2: NANG CAO
    $c2 = New-WCM7ActionCard -Title (T 'm7.actions.2.title') -Desc (T 'm7.actions.2.desc') -Risk 'Advanced'
    Add-WCChild $body $c2['Root']
    # Huong 3: RUI RO - chi de xuat khi du dau hieu
    if ($Verdict['ReinstallMet']) {
        $c3 = New-WCM7ActionCard -Title (T 'm7.actions.3.title') -Desc (T 'm7.actions.3.desc') -Risk 'Risky'
        Add-WCChild $c3['Body'] (New-WCTextBlock -Text (T 'm7.actions.3.criteria') -Size 12.5 -Weight 'SemiBold' -Wrap)
        foreach ($sign in @($Verdict['ReinstallSigns'])) {
            $txt = ''
            switch ($sign) {
                'boot'    { $txt = (T 'm7.actions.3.sign.boot') }
                'startup' { $txt = (T 'm7.actions.3.sign.startup') }
                'disk'    { $txt = (T 'm7.actions.3.sign.disk') }
                'bsod'    { $txt = (T 'm7.actions.3.sign.bsod') }
            }
            if ($txt) { Add-WCChild $c3['Body'] (New-WCTextBlock -Text $txt -Size 12 -Wrap) }
        }
        Add-WCChild $c3['Body'] (New-WCTextBlock -Text (T 'm7.actions.3.checklist.title') -Size 12.5 -Weight 'SemiBold' -Wrap)
        for ($i = 1; $i -le 6; $i++) {
            Add-WCChild $c3['Body'] (New-WCTextBlock -Text (T ('m7.actions.3.checklist.' + $i)) -Size 12 -Wrap)
        }
        Add-WCChild $c3['Body'] (New-WCTextBlock -Text (T 'm7.actions.3.guide.title') -Size 12.5 -Weight 'SemiBold' -Wrap)
        Add-WCChild $c3['Body'] (New-WCTextBlock -Text (T 'm7.actions.3.guide.1') -Size 12 -Wrap)
        Add-WCChild $c3['Body'] (New-WCTextBlock -Text (T 'm7.actions.3.guide.2') -Size 12 -Wrap)
        Add-WCChild $c3['Body'] (New-WCTextBlock -Text (T 'm7.actions.3.note') -Size 11 -ColorKey 'WcSubtle' -Wrap)
        Add-WCChild $body $c3['Root']
    } else {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.actions.3.notneeded' @([string]@($Verdict['ReinstallSigns']).Count, '4')) -Size 12 -ColorKey 'WcSubtle' -Wrap)
    }
}

# ---------------------------------------------------------------------------
# HANH DONG (xac nhan truoc, ghi journal truoc khi thay doi - spec 2.4)
# ---------------------------------------------------------------------------
function Invoke-WCM7ToggleStartup {
    # Tat/bat muc khoi dong da chon qua CO CHE StartupApproved
    # (viet binary nhu Task Manager, KHONG xoa khoa goc, dao nguoc duoc).
    param($State, [bool]$Enable)
    $list = $State['StartupList']
    if (-not $list) { return }
    $sel = @(Get-WCCheckRowSelection -List $list)
    if ($sel.Count -eq 0) {
        Show-WCToast (T 'common.empty') 'Info'
        return
    }
    $names = @()
    foreach ($e in $sel) { $names += [string]$e['Name'] }
    $msgKey = 'm7.startup.confirm.on'
    if (-not $Enable) { $msgKey = 'm7.startup.confirm.off' }
    $msg = (T $msgKey) + "`n  • " + ([string]::Join("`n  • ", $names))
    if (-not (Show-WCConfirm -Title (T 'm7.startup.confirm.title') -Message $msg `
            -Undoable (T 'm7.startup.confirm.undo') -NotUndoable (T 'm7.startup.confirm.noundo'))) { return }
    if (Test-WCDryRunMode) {
        Show-WCToast (T 'common.dryrun.header') 'Info'
        return
    }
    $okCount = 0; $failCount = 0
    foreach ($e in $sel) {
        $entry = $null
        try {
            $action = (T 'm7.startup.journal.on')
            $undoType = 'startup.disable'
            # OldValue = trang thai HIEN TAI cua muc (truoc khi doi)
            $oldVal = [string]$e['State']
            if ($oldVal -ne 'Disabled') { $oldVal = 'Enabled' }
            if (-not $Enable) { $action = (T 'm7.startup.journal.off'); $undoType = 'startup.enable' }
            $approvedFull = Convert-WCRegPsPathToFull -Path ([string]$e['ApprovedKey'])
            # Ghi journal TRUOC khi thay doi (undo handler 'startup.enable' co san trong 05-Journal)
            $entry = Add-WCJournalEntry -Module 'M7' -Action $action -Target ([string]$e['Name']) `
                -OldValue $oldVal -UndoType $undoType `
                -UndoArgs @{ RegPath = $approvedFull; ValueName = ([string]$e['ValueName']) } `
                -AutoRestore:$false
            Set-WCStartupApprovedState -ApprovedKey ([string]$e['ApprovedKey']) -ValueName ([string]$e['ValueName']) -Enable $Enable
            Complete-WCJournalEntry -Entry $entry -Result 'Ok'
            $okCount++
        } catch {
            if ($entry) { Complete-WCJournalEntry -Entry $entry -Result ('Failed: ' + $_.Exception.Message) }
            $failCount++
        }
    }
    Show-WCToast (T 'm7.startup.result' @([string]$okCount, [string]$failCount)) 'Ok'
    Invoke-WCM7ScanStartup $State
}

function Invoke-WCM7Uninstall {
    # Mo trinh go CHINH THUC cua phan mem (go qua co che go chinh thuc,
    # KHONG tu xoa). Parse UninstallString: dau '"' -> exe trong ngoac + phan
    # con lai la args; khong co -> exe la token dau tien.
    param($Item)
    $name = [string]$Item['DisplayName']
    $us = [string]$Item['UninstallString']
    if ([string]::IsNullOrEmpty($us)) {
        Show-WCToast (T 'm7.software.uninstall.nostring') 'Warn'
        return
    }
    $parsed = Split-WCUninstallCommand -Cmd $us
    if ($null -eq $parsed) {
        Show-WCToast (T 'm7.software.uninstall.nostring') 'Warn'
        return
    }
    $cmdShown = ([string]$parsed['Exe'] + ' ' + [string]$parsed['Args']).Trim()
    $msg = (T 'm7.software.uninstall.confirm.msg' @($name, "`n", $cmdShown, "`n`n"))
    if (-not (Show-WCConfirm -Title (T 'm7.software.uninstall.confirm.title') -Message $msg `
            -NotUndoable (T 'm7.software.uninstall.confirm.noundo'))) { return }
    if (Test-WCDryRunMode) {
        Show-WCToast (T 'common.dryrun.header') 'Info'
        return
    }
    $entry = Add-WCJournalEntry -Module 'M7' -Action (T 'm7.software.journal') -Target $name `
        -OldValue 'Installed' -UndoType '' -UndoArgs $null
    try {
        if ([string]::IsNullOrEmpty([string]$parsed['Args'])) {
            Start-Process -FilePath ([string]$parsed['Exe']) -ErrorAction Stop
        } else {
            Start-Process -FilePath ([string]$parsed['Exe']) -ArgumentList ([string]$parsed['Args']) -ErrorAction Stop
        }
        Complete-WCJournalEntry -Entry $entry -Result 'Ok'
        Show-WCToast (T 'm7.software.uninstall.running' @($name)) 'Ok'
    } catch {
        Complete-WCJournalEntry -Entry $entry -Result ('Failed: ' + $_.Exception.Message)
        Show-WCError -Friendly (T 'm7.software.uninstall.fail') -Details $_.Exception.Message
    }
}

function Invoke-WCM7OpenResidualSelected {
    # Mo Explorer tai vi tri cac thu muc tan du da chon
    param($State)
    $list = $State['ResidualList']
    if (-not $list) { return }
    $sel = @(Get-WCCheckRowSelection -List $list)
    if ($sel.Count -eq 0) {
        Show-WCToast (T 'common.empty') 'Info'
        return
    }
    foreach ($f in $sel) {
        try { Start-Process explorer.exe -ArgumentList ('"' + [string]$f['Path'] + '"') } catch { }
    }
}

function Invoke-WCM7DeleteResidual {
    # Chuyen thu muc tan du da chon vao THUNG RAC (KHONG xoa vinh vien,
    # mac dinh khong tick). Goi Send-WCFileToRecycleBin (08-Interop.ps1)
    # sau Show-WCConfirm + ghi journal tung thu muc truoc khi lam.
    param($State)
    $list = $State['ResidualList']
    if (-not $list) { return }
    $sel = @(Get-WCCheckRowSelection -List $list)
    if ($sel.Count -eq 0) {
        Show-WCToast (T 'common.empty') 'Info'
        return
    }
    $lines = @()
    foreach ($f in $sel) {
        $lines += ('  • ' + [string]$f['Path'] + ' (' + (ConvertTo-WCHumanSize ([long]$f['SizeBytes'])) + ')')
    }
    $msg = (T 'm7.residual.delete.confirm.msg') + "`n" + ([string]::Join("`n", $lines))
    if (-not (Show-WCConfirm -Title (T 'm7.residual.delete.confirm.title') -Message $msg `
            -NotUndoable (T 'm7.residual.delete.confirm.noundo'))) { return }
    if (Test-WCDryRunMode) {
        Show-WCToast (T 'common.dryrun.header') 'Info'
        return
    }
    # Chay nen co tien do + Huy (recycle thu muc lon co the lau)
    $delArgs = @{ Items = $sel }
    Start-WCTask -Id 'm7.residual.delete' -Title (T 'm7.residual.delete') -ShowStatus -Args $delArgs -Worker {
        param($ctx, $s)
        $okCount = 0; $failCount = 0
        foreach ($f in @($s['Items'])) {
            if ($ctx.Cancelled()) { break }
            $path = [string]$f['Path']
            $ctx.Log(('Recycle: ' + $path))
            # Kiem tra an toan: junction thi bo qua; phai con thu muc con cap 1+
            if (Test-WCPathIsReparsePoint -Path $path) { $failCount++; continue }
            $entry = $null
            try {
                $entry = Add-WCJournalEntry -Module 'M7' -Action (T 'm7.residual.journal') -Target $path `
                    -OldValue ([string]$f['SizeBytes'] + ' bytes') -UndoType '' -UndoArgs $null
                $done = Send-WCFileToRecycleBin -Path $path
                if ($done) {
                    Complete-WCJournalEntry -Entry $entry -Result 'Ok'
                    $okCount++
                } else {
                    Complete-WCJournalEntry -Entry $entry -Result 'Failed'
                    $failCount++
                }
            } catch {
                if ($entry) { Complete-WCJournalEntry -Entry $entry -Result ('Failed: ' + $_.Exception.Message) }
                $failCount++
            }
        }
        return @{ Ok = $okCount; Fail = $failCount }
    } -Done {
        param($r)
        if ($r -and $r.ContainsKey('Ok')) {
            Show-WCToast (T 'm7.residual.result' @([string]$r['Ok'], [string]$r['Fail'])) 'Ok'
        }
        Invoke-WCM7ScanResidual $State
    }.GetNewClosure() | Out-Null
}

function Invoke-WCM7OpenLauncher {
    # Mo Steam/Epic (go/chuyen game chi qua launcher - spec M7)
    param([string]$Kind, [string]$FallbackExe)
    try {
        if ($Kind -eq 'steam') { Start-Process 'steam://open/games' }
        else { Start-Process 'com.epicgames.launcher://store' }
    } catch {
        $opened = $false
        if (-not [string]::IsNullOrEmpty($FallbackExe)) {
            try { Start-Process -FilePath $FallbackExe; $opened = $true } catch { }
        }
        if (-not $opened) { Show-WCToast (T 'm7.games.open.fail') 'Warn' }
    }
}

# ---------------------------------------------------------------------------
# KHOI TAO MODULE + DANG KY NAV (BAT BUOC cuoi file - spec hop dong)
# ---------------------------------------------------------------------------
function Initialize-WCModuleM7 {
    $state = @{
        Sections = @{}; Data = @{}; Ready = @{}
        Scanned = $false; StartupList = $null; ResidualList = $null
    }
    Register-WCNavItem -Key 'm7' -Badge 'M7' -Title (T 'm7.title') -Order 80 -Builder {
        New-WCM7Panel $state
    }.GetNewClosure() -OnShow {
        if (-not $state['Scanned']) {
            $state['Scanned'] = $true
            Invoke-WCM7Scan $state
        }
    }.GetNewClosure() -OnHide { }
}


# ============================================================================
# REGION: 19-History.ps1
# ============================================================================

# ============================================================================
#  src/19-History.ps1 - Lich su & Hoan tac (doc tu journal - spec 2.4)
# ============================================================================

Register-WCStrings 'vi' @{
    'hist.refresh' = 'Làm mới'
    'hist.undo.ok' = 'Đã hoàn tác: {0}'
    'hist.undo.fail' = 'Không hoàn tác được: {0}'
    'hist.exported' = 'Đã xuất nhật ký: {0}'
    'hist.col.time' = 'Thời gian'
    'hist.col.module' = 'Module'
    'hist.col.action' = 'Hành động'
    'hist.col.target' = 'Đối tượng'
    'hist.col.result' = 'Kết quả'
    'hist.undo.btn' = 'Hoàn tác'
    'hist.view.log' = 'Mở log'
    'hist.deleted' = 'Đã xóa toàn bộ dữ liệu WinCare'
    'hist.confirm.delete' = 'Xóa toàn bộ dữ liệu?'
}
Register-WCStrings 'en' @{
    'hist.refresh' = 'Refresh'
    'hist.undo.ok' = 'Undone: {0}'
    'hist.undo.fail' = 'Cannot undo: {0}'
    'hist.exported' = 'Journal exported: {0}'
    'hist.col.time' = 'Time'
    'hist.col.module' = 'Module'
    'hist.col.action' = 'Action'
    'hist.col.target' = 'Target'
    'hist.col.result' = 'Result'
    'hist.undo.btn' = 'Undo'
    'hist.view.log' = 'Open log'
    'hist.deleted' = 'All WinCare data deleted'
    'hist.confirm.delete' = 'Delete all data?'
}

function Initialize-WCModuleHistory {
    $state = @{ ListHost = $null }
    Register-WCNavItem -Key 'history' -Badge (T 'nav.history') -Title (T 'journal.title') -Order 90 -Builder {
        New-WCHistoryPanel $state
    }.GetNewClosure() -OnShow {
        Invoke-WCHistoryLoad $state
    }.GetNewClosure()
}

function New-WCHistoryPanel {
    param($State)
    $root = New-Object Windows.Controls.ScrollViewer
    $root.VerticalScrollBarVisibility = [Windows.Controls.ScrollBarVisibility]::Auto
    $hostPanel = New-WCVStack -Spacing 14
    $hostPanel.Margin = (New-Object Windows.Thickness(20))
    $root.Content = $hostPanel

    $titleRow = New-WCHStack
    Add-WCChild $titleRow (New-WCHeading (T 'journal.title'))
    $refreshBtn = New-WCButton -Text (T 'hist.refresh') -OnClick { param($b) Invoke-WCHistoryLoad $state }.GetNewClosure()
    $refreshBtn.Margin = (New-Object Windows.Thickness(12,0,0,0))
    Add-WCChild $titleRow $refreshBtn
    Add-WCChild $hostPanel $titleRow
    Add-WCChild $hostPanel (New-WCSubtitle (T 'm1.run.confirm.undo'))

    $listHost = New-WCVStack -Spacing 4
    $State.ListHost = $listHost
    Add-WCChild $hostPanel $listHost

    # Xuat + mo log + xoa du lieu
    $actionsSec = New-WCSection
    $btnRow = New-WCHStack
    $exportBtn = New-WCButton -Text (T 'journal.export') -OnClick { param($b) Invoke-WCHistoryExport $state }.GetNewClosure()
    Add-WCChild $btnRow $exportBtn
    $logBtn = New-WCButton -Text (T 'hist.view.log') -OnClick { param($b) Open-WCLogFile }.GetNewClosure()
    Add-WCChild $btnRow $logBtn
    $deleteBtn = New-WCButton -Text (T 'journal.clear') -Kind Danger -OnClick { param($b) Invoke-WCHistoryDeleteAll $state }.GetNewClosure()
    Add-WCChild $btnRow $deleteBtn
    Add-WCChild $actionsSec.Body $btnRow
    Add-WCChild $hostPanel $actionsSec.Root

    return $root
}

function Invoke-WCHistoryLoad {
    param($State)
    $hostPanel = $State.ListHost
    $hostPanel.Children.Clear()
    $entries = @(Get-WCJournal)
    if ($entries.Count -eq 0) {
        Add-WCChild $hostPanel (New-WCTextBlock -Text (T 'journal.empty') -ColorKey 'WcSubtle' -Wrap)
        return
    }
    # Moi nhat len truoc
    [array]::Reverse($entries)
    foreach ($e in $entries) {
        $row = New-Object Windows.Controls.Border
        $row.Style = (Get-WCControlStyles)['WcListItem']
        $dock = New-Object Windows.Controls.DockPanel
        $dock.LastChildFill = $true

        $right = New-Object Windows.Controls.StackPanel
        $right.Orientation = [Windows.Controls.Orientation]::Horizontal
        [Windows.Controls.DockPanel]::SetDock($right, [Windows.Dock]::Right)
        $result = [string](Get-WCProp $e 'Result')
        $canUndo = ((Get-WCProp $e 'UndoType') -and $result -eq 'Ok')
        if ($canUndo) {
            $entryRef = $e
            $undoBtn = New-WCButton -Text (T 'hist.undo.btn') -Small -OnClick {
                param($b)
                $b.IsEnabled = $false
                $r = Undo-WCJournalEntry $entryRef
                if ($r.Ok) { Show-WCToast (T 'hist.undo.ok' @($entryRef.Target)) 'Ok' }
                else { Show-WCToast (T 'hist.undo.fail' @($r.Message)) 'Warn' }
                Invoke-WCHistoryLoad $state
            }.GetNewClosure()
            $undoBtn.Margin = (New-Object Windows.Thickness(8,0,0,0))
            $right.Children.Add($undoBtn) | Out-Null
        }
        $resultChip = New-WCChip -Text $result -Kind ($(if ($result -eq 'Ok') { 'Accent' } elseif ($result -like 'Failed*') { 'Bad' } elseif ($result -eq 'Undone' -or $result -eq 'AutoRestored') { 'Ok' } else { 'Unknown' }))
        $resultChip.VerticalAlignment = [Windows.VerticalAlignment]::Center
        $right.Children.Add($resultChip) | Out-Null
        $dock.Children.Add($right) | Out-Null

        $textHost = New-Object Windows.Controls.StackPanel
        $textHost.Orientation = [Windows.Controls.Orientation]::Vertical
        $line1 = New-WCTextBlock -Text (('[{0}] {1} — {2}' -f (Get-WCProp $e 'Module'), (Get-WCProp $e 'Action'), (Get-WCProp $e 'Target'))) -Size 13 -Weight 'SemiBold' -Wrap
        Add-WCChild $textHost $line1
        try {
            $t = [DateTime]::Parse([string](Get-WCProp $e 'Time'), [Globalization.CultureInfo]::InvariantCulture)
            $line2 = New-WCTextBlock -Text $t.ToLocalTime().ToString('yyyy-MM-dd HH:mm:ss') -Size 11.5 -ColorKey 'WcSubtle'
            Add-WCChild $textHost $line2
        } catch { }
        $dock.Child = $textHost
        $row.Child = $dock
        $hostPanel.Children.Add($row) | Out-Null
    }
}

function Invoke-WCHistoryExport {
    param($State)
    try {
        $entries = @(Get-WCJournal)
        $lines = @()
        foreach ($e in $entries) {
            $lines += ('{0} | {1} | {2} | {3} | {4} | {5}' -f `
                (Get-WCProp $e 'Time'), (Get-WCProp $e 'Module'), (Get-WCProp $e 'Action'), `
                (Get-WCProp $e 'Target'), (Get-WCProp $e 'OldValue'), (Get-WCProp $e 'Result'))
        }
        $path = Join-Path (Get-WCDataRoot) ('reports\journal-' + (Get-Date -Format 'yyyy-MM-dd-HHmm') + '.txt')
        $dir = Split-Path $path -Parent
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
        [IO.File]::WriteAllLines($path, $lines, (New-Object Text.UTF8Encoding($false)))
        Show-WCToast (T 'hist.exported' @($path)) 'Ok'
    } catch {
        Show-WCError (T 'common.error') $_.Exception.Message
    }
}

function Invoke-WCHistoryDeleteAll {
    param($State)
    if (-not (Show-WCConfirm -Title (T 'hist.confirm.delete') -Message (T 'journal.clear.confirm') -NotUndoable (T 'journal.clear') -Danger)) { return }
    Remove-WCAllData
    Show-WCToast (T 'hist.deleted') 'Ok'
    Invoke-WCHistoryLoad $State
}


# ============================================================================
# REGION: 20-Settings.ps1
# ============================================================================

# ============================================================================
#  src/20-Settings.ps1 - Cai dat: ngon ngu, theme, dry-run, chuyen gia, che du lieu
#  + Gioi thieu (version, build hash, mang duoc dung - spec 2.5)
# ============================================================================

Register-WCStrings 'vi' @{
    'set.title' = 'Cài đặt'
    'set.lang' = 'Ngôn ngữ'
    'set.lang.vi' = 'Tiếng Việt'
    'set.lang.en' = 'English'
    'set.theme' = 'Giao diện'
    'set.theme.system' = 'Theo hệ thống'
    'set.theme.light' = 'Sáng'
    'set.theme.dark' = 'Tối'
    'set.behavior' = 'Hành vi'
    'set.dryrun' = 'Dry-run (chỉ hiện điều SẼ làm, không thực hiện)'
    'set.dryrun.hint' = 'Bật để xem trước mọi thay đổi mà không đụng vào máy'
    'set.expert' = 'Chế độ chuyên gia (hiện lệnh/API sẽ chạy)'
    'set.expert.hint' = 'Hiện lệnh PowerShell tương ứng ở mỗi hành động'
    'set.mask' = 'Che dữ liệu nhạy cảm khi xuất báo cáo'
    'set.mask.hint' = 'Che serial, MAC, UUID, tên người dùng trong file báo cáo'
    'set.about' = 'Giới thiệu'
    'set.about.ver' = 'Phiên bản'
    'set.about.build' = 'Build'
    'set.about.selfurl' = 'Nguồn script'
    'set.about.data' = 'Thư mục dữ liệu'
    'set.about.open' = 'Mở thư mục dữ liệu'
    'set.restart.note' = 'Một số thay đổi áp dụng cho panel mới (chuyển màn khác rồi quay lại).'
}
Register-WCStrings 'en' @{
    'set.title' = 'Settings'
    'set.lang' = 'Language'
    'set.lang.vi' = 'Tiếng Việt'
    'set.lang.en' = 'English'
    'set.theme' = 'Appearance'
    'set.theme.system' = 'Follow system'
    'set.theme.light' = 'Light'
    'set.theme.dark' = 'Dark'
    'set.behavior' = 'Behavior'
    'set.dryrun' = 'Dry-run (show what WOULD happen, do nothing)'
    'set.dryrun.hint' = 'Preview every change without touching the PC'
    'set.expert' = 'Expert mode (show commands/API calls)'
    'set.expert.hint' = 'Show the PowerShell command behind each action'
    'set.mask' = 'Mask sensitive data in exported reports'
    'set.mask.hint' = 'Hide serials, MAC, UUID, username in report files'
    'set.about' = 'About'
    'set.about.ver' = 'Version'
    'set.about.build' = 'Build'
    'set.about.selfurl' = 'Script source'
    'set.about.data' = 'Data folder'
    'set.about.open' = 'Open data folder'
    'set.restart.note' = 'Some changes apply to newly opened screens.'
}

function New-WCOptionToggle {
    # Dong tuy chinh: chu giai + checkbox WPF (doi mau theo theme)
    param([string]$Label, [string]$Hint, [bool]$Checked, [scriptblock]$OnToggle)
    $row = New-Object Windows.Controls.Border
    $row.Style = (Get-WCControlStyles)['WcListItem']
    $dock = New-Object Windows.Controls.DockPanel
    $dock.LastChildFill = $true
    $cb = New-Object Windows.Controls.CheckBox
    $cb.IsChecked = $Checked
    $cb.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $cb.SetResourceReference([Windows.Controls.Control]::ForegroundProperty, 'WcText')
    [Windows.Controls.DockPanel]::SetDock($cb, [Windows.Dock]::Right)
    $handler = $OnToggle; $cbRef = $cb
    $cb.Add_Checked({ try { & $handler $cbRef } catch { } }.GetNewClosure())
    $cb.Add_Unchecked({ try { & $handler $cbRef } catch { } }.GetNewClosure())
    $dock.Children.Add($cb) | Out-Null
    $textHost = New-Object Windows.Controls.StackPanel
    $textHost.Orientation = [Windows.Controls.Orientation]::Vertical
    $lbl = New-WCTextBlock -Text $Label -Size 13 -Wrap
    Add-WCChild $textHost $lbl
    if ($Hint) { Add-WCChild $textHost (New-WCTextBlock -Text $Hint -Size 11.5 -ColorKey 'WcSubtle' -Wrap) }
    $dock.Child = $textHost
    $row.Child = $dock
    return $row
}

function Initialize-WCModuleSettings {
    Register-WCNavItem -Key 'settings' -Badge (T 'nav.settings') -Title (T 'set.title') -Order 95 -Builder {
        New-WCSettingsPanel
    }.GetNewClosure()
}

function New-WCSettingsPanel {
    $root = New-Object Windows.Controls.ScrollViewer
    $root.VerticalScrollBarVisibility = [Windows.Controls.ScrollBarVisibility]::Auto
    $hostPanel = New-WCVStack -Spacing 14
    $hostPanel.Margin = (New-Object Windows.Thickness(20))
    $root.Content = $hostPanel

    Add-WCChild $hostPanel (New-WCHeading (T 'set.title'))

    # Ngon ngu
    $langSec = New-WCSection -Title (T 'set.lang')
    $langRow = New-WCHStack
    $curLang = [string](Get-WCSetting 'lang')
    $mkLangBtn = {
        param($code, $label)
        $kind = 'Normal'; if ($curLang -eq $code) { $kind = 'Primary' }
        return (New-WCButton -Text $label -Kind $kind -OnClick {
            param($b)
            Set-WCLanguage $code
            Refresh-WCNavTitles
            Show-WCToast (T 'common.success') 'Ok'
        }.GetNewClosure())
    }
    Add-WCChild $langRow (& $mkLangBtn 'vi' (T 'set.lang.vi'))
    Add-WCChild $langRow (& $mkLangBtn 'en' (T 'set.lang.en'))
    Add-WCChild $langSec.Body $langRow
    Add-WCChild $hostPanel $langSec.Root

    # Theme
    $themeSec = New-WCSection -Title (T 'set.theme')
    $themeRow = New-WCHStack
    $curTheme = [string](Get-WCSetting 'theme')
    foreach ($t in @(@{Code='system';Label=(T 'set.theme.system')}, @{Code='light';Label=(T 'set.theme.light')}, @{Code='dark';Label=(T 'set.theme.dark')})) {
        $kind = 'Normal'; if ($curTheme -eq $t.Code) { $kind = 'Primary' }
        $code = $t.Code
        $btn = New-WCButton -Text $t.Label -Kind $kind -OnClick {
            param($b)
            Set-WCSetting 'theme' $code
            $win = Get-WCShellWindow
            if ($win) { Apply-WCTheme $win }
        }.GetNewClosure()
        Add-WCChild $themeRow $btn
    }
    Add-WCChild $themeSec.Body $themeRow
    Add-WCChild $hostPanel $themeSec.Root

    # Hanh vi
    $behSec = New-WCSection -Title (T 'set.behavior')
    Add-WCChild $behSec.Body (New-WCOptionToggle -Label (T 'set.dryrun') -Hint (T 'set.dryrun.hint') -Checked (Test-WCDryRunMode) -OnToggle {
        param($cb) Set-WCSetting 'dryRun' ([bool]$cb.IsChecked)
    }.GetNewClosure())
    Add-WCChild $behSec.Body (New-WCOptionToggle -Label (T 'set.expert') -Hint (T 'set.expert.hint') -Checked (Test-WCExpertMode) -OnToggle {
        param($cb) Set-WCSetting 'expert' ([bool]$cb.IsChecked)
    }.GetNewClosure())
    Add-WCChild $behSec.Body (New-WCOptionToggle -Label (T 'set.mask') -Hint (T 'set.mask.hint') -Checked (Test-WCMaskMode) -OnToggle {
        param($cb) Set-WCSetting 'maskSensitive' ([bool]$cb.IsChecked)
    }.GetNewClosure())
    Add-WCChild $hostPanel $behSec.Root

    # Gioi thieu
    $aboutSec = New-WCSection -Title (T 'set.about')
    Add-WCChild $aboutSec.Body (New-WCFieldRow -Label (T 'set.about.ver') -Value ((Get-WCName) + ' ' + (Get-WCVersion)) -NoCopy)
    Add-WCChild $aboutSec.Body (New-WCFieldRow -Label (T 'set.about.build') -Value (Get-WCBuildHash) -Mono)
    $selfUrl = Get-WCSelfUrl
    $urlTxt = $selfUrl
    if (Test-WCSelfUrlPlaceholder) { $urlTxt = $selfUrl + ' (placeholder — đặt WINCARE_SELFURL để bật tự nâng quyền)' }
    Add-WCChild $aboutSec.Body (New-WCFieldRow -Label (T 'set.about.selfurl') -Value $urlTxt -Mono)
    Add-WCChild $aboutSec.Body (New-WCFieldRow -Label (T 'set.about.data') -Value (Get-WCDataRoot) -Mono)
    $openRow = New-WCHStack
    $openBtn = New-WCButton -Text (T 'set.about.open') -OnClick { param($b) Open-WCDataFolder }.GetNewClosure()
    Add-WCChild $openRow $openBtn
    Add-WCChild $aboutSec.Body $openRow
    # Mang duoc dung (spec 2.5: hien thi o "Gioi thieu > Hoat dong mang")
    Add-WCChild $aboutSec.Body (New-WCSubtitle (T 'shell.about.network'))
    Add-WCChild $aboutSec.Body (New-WCTextBlock -Text (T 'shell.about.network.desc') -Size 12 -ColorKey 'WcSubtle' -Wrap)
    Add-WCChild $hostPanel $aboutSec.Root

    Add-WCChild $hostPanel (New-WCTextBlock -Text (T 'set.restart.note') -Size 11.5 -ColorKey 'WcSubtle' -Wrap)

    return $root
}


# ============================================================================
# REGION: 21-Main.ps1
# ============================================================================

# ============================================================================
#  src/21-Main.ps1 - Chuoi khoi dong + chay app + don dep
#  Thu tu (spec 2.1): kiem tra moi truong -> Admin -> STA -> mutex -> data ->
#  module -> shell -> ShowDialog -> cleanup. Khong dung exit top-level.
# ============================================================================

function Initialize-WCModules {
    # Khoi tao tung module, moi module mot try/catch (loi 1 module khong sap app)
    $initializers = @(
        'Initialize-WCModuleDashboard'
        'Initialize-WCModuleM1'
        'Initialize-WCModuleM2'
        'Initialize-WCModuleM3'
        'Initialize-WCModuleM4'
        'Initialize-WCModuleM5'
        'Initialize-WCModuleM6'
        'Initialize-WCModuleM7'
        'Initialize-WCModuleHistory'
        'Initialize-WCModuleSettings'
    )
    foreach ($name in $initializers) {
        try {
            $fn = Get-Command -Name $name -ErrorAction SilentlyContinue
            if ($fn) { & $fn }
            else { Write-WCLog 'WARN' ('Khong tim ham khoi tao: ' + $name) }
        } catch {
            Write-WCLog 'ERROR' ('Khoi tao module that bai [' + $name + ']: ' + $_.Exception.Message)
        }
    }
}

function Invoke-WCBoot {
    # Diem vao duy nhat (irm | iex dan vao day). Tra ve $true neu app da chay xong.
    # 1) Kiem tra moi truong
    $platform = Test-WCPlatform
    if ($platform.Status -ne 'Ok') {
        try {
            [Windows.MessageBox]::Show($platform.Reason, (Get-WCName), [Windows.MessageBoxButton]::OK, [Windows.MessageBoxImage]::Warning) | Out-Null
        } catch { Write-Output $platform.Reason }
        return $false
    }

    # 2) Nang quyen Admin (spec 2.1: relaunch -Verb RunAs; tu choi -> thong bao than thien)
    if (-not (Get-WCIsAdmin)) {
        $elevated = Invoke-WCElevation
        if (-not $elevated) { return $false }   # da thong bao cho nguoi dung
        # Da relaunch tien trinh moi o che do Admin; tien trinh nay thoat an tinh
        return $true
    }

    # 3) STA cho WPF (relaunch -STA neu can)
    if (-not (Test-WCSTA)) {
        if (-not (Test-WCSelfUrlPlaceholder)) {
            $url = Get-WCSelfUrl
            try {
                Start-Process -FilePath 'powershell.exe' `
                    -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-STA','-WindowStyle','Hidden','-Command', ("irm '" + $url + "' | iex")) `
                    -Verb RunAs -ErrorAction Stop
                return $true
            } catch { }
        }
        # Khong relaunch duoc -> bao ro (WPF can STA)
        try {
            [Windows.MessageBox]::Show((T 'boot.err.wpf'), (Get-WCName), [Windows.MessageBoxButton]::OK, [Windows.MessageBoxImage]::Warning) | Out-Null
        } catch { }
        return $false
    }

    # 4) Mot instance duy nhat (mutex)
    if (-not (Initialize-WCSingleInstance)) {
        return $true    # instance cu da duoc dua len truoc
    }

    # 5) Du lieu + settings + journal + fixture + interop
    Initialize-WCData
    Write-WCLog 'INFO' ('===== ' + (Get-WCName) + ' ' + (Get-WCVersion) + ' khoi dong =====')
    Load-WCSettings
    Initialize-WCDefaultDeleteRoots
    Initialize-WCJournal
    Initialize-WCFixture
    try { Add-WCNativeType } catch { Write-WCLog 'WARN' ('Add-WCNativeType: ' + $_.Exception.Message) }

    # 6) Dang ky module + shell + chay
    Initialize-WCModules
    Show-WCShell

    # 7) Don dep (shell Closed da don task/mutex; day la phong thu)
    try { Stop-WCTaskRunner } catch { }
    try {
        if ($Script:WcMutex) {
            $Script:WcMutex.ReleaseMutex()
            $Script:WcMutex.Dispose()
            $Script:WcMutex = $null
        }
    } catch { }
    Write-WCLog 'INFO' '===== Thoat ====='
    return $true
}

# CHAY (khong exit top-level - spec muc 1.4)
$null = Invoke-WCBoot

