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
