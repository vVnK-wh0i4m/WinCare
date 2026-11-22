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
