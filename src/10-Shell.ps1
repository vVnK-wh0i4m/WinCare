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
