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
