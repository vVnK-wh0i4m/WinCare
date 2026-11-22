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
