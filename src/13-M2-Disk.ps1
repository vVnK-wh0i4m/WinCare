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
