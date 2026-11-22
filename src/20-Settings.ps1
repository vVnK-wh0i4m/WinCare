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
