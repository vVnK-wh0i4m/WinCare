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
