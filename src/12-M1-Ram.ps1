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
