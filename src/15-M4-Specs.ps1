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
