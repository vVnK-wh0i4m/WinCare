# ============================================================================
#  src/05-Journal.ps1 - Nhat ky thay doi + hoan tac (spec 2.4)
#  Ghi MOI thay doi: thoi gian, module, hanh dong, doi tuong, gia tri cu,
#  cach hoan tac, ket qua. Man "Lich su & Hoan tac" doc tu day.
# ============================================================================

$Script:WcJournalPath = $null
$Script:WcUndoHandlers = @{}   # undoType -> scriptblock(param($entry))
$Script:WcJournalSessionRestored = $false

function Initialize-WCJournal {
    $Script:WcJournalPath = Join-Path (Get-WCDataRoot) 'journal.json'
    if (-not (Test-Path -LiteralPath $Script:WcJournalPath)) {
        Save-WCJournal @()
    }
    # Phat hien entry "tu phuc hoi" con sot lai tu phien truoc (spec M1: dich vu dung tam
    # phai duoc khoi phuc ke ca khi thoat app dot ngot)
    Restore-WCSessionScopedEntries
}

function Get-WCJournal {
    try {
        $json = [IO.File]::ReadAllText($Script:WcJournalPath)
        $entries = ConvertFrom-Json $json
        if ($null -eq $entries) { return @() }
        if ($entries -is [array]) { return $entries }
        return @($entries)
    } catch {
        Write-WCLog 'WARN' ('journal.json hong -> khoi tao lai: ' + $_.Exception.Message)
        return @()
    }
}

function Save-WCJournal {
    param([Parameter(Mandatory)]$Entries)
    try {
        # Giu toi da 500 entry moi nhat de file khong phinh to
        $list = @($Entries)
        if ($list.Count -gt 500) { $list = $list[($list.Count - 500)..($list.Count - 1)] }
        $json = ConvertTo-Json $list -Depth 6
        [IO.File]::WriteAllText($Script:WcJournalPath, $json, (New-Object Text.UTF8Encoding($false)))
    } catch { Write-WCLog 'WARN' ('Khong luu duoc journal: ' + $_.Exception.Message) }
}

function Add-WCJournalEntry {
    # Vi du:
    #   Add-WCJournalEntry -Module 'M1' -Action 'Stop service' -Target 'SysMain' `
    #     -UndoType 'service.start' -UndoArgs @{ Name='SysMain'; StartType='Automatic' } -AutoRestore $true
    param(
        [Parameter(Mandatory)][string]$Module,
        [Parameter(Mandatory)][string]$Action,
        [Parameter(Mandatory)][string]$Target,
        [string]$OldValue = '',
        [string]$UndoType = '',          # '' = khong the hoan tac tu dong
        $UndoArgs = $null,
        [switch]$AutoRestore             # tu phuc hoi khi thoat app / mo lai
    )
    $entry = [PSCustomObject]@{
        Id = [Guid]::NewGuid().ToString('N')
        Time = (Get-Date).ToString('o')
        Module = $Module
        Action = $Action
        Target = $Target
        OldValue = $OldValue
        UndoType = $UndoType
        UndoArgs = $UndoArgs
        AutoRestore = [bool]$AutoRestore
        Result = 'Pending'
    }
    $all = @(Get-WCJournal)
    $all += $entry
    Save-WCJournal $all
    Write-WCLog 'JOURNAL' ('{0} | {1} | {2} | undo={3}' -f $Module, $Action, $Target, $UndoType)
    return $entry
}

function Complete-WCJournalEntry {
    param([Parameter(Mandatory)]$Entry, [string]$Result = 'Ok')
    $all = @(Get-WCJournal)
    foreach ($e in $all) {
        if ((Get-WCProp $e 'Id') -eq $Entry.Id) {
            $e.Result = $Result
            break
        }
    }
    Save-WCJournal $all
}

function Register-WCUndoHandler {
    param([Parameter(Mandatory)][string]$UndoType, [Parameter(Mandatory)][scriptblock]$Handler)
    $Script:WcUndoHandlers[$UndoType] = $Handler
}

function Undo-WCJournalEntry {
    # Hoan tac 1 entry neu co handler. Tra ve @{ Ok; Message }
    param([Parameter(Mandatory)]$Entry)
    $type = [string](Get-WCProp $Entry 'UndoType')
    if ([string]::IsNullOrEmpty($type)) { return @{ Ok = $false; Message = (T 'journal.noundo') } }
    $handler = $null
    if ($Script:WcUndoHandlers.ContainsKey($type)) { $handler = $Script:WcUndoHandlers[$type] }
    if (-not $handler) { return @{ Ok = $false; Message = (T 'journal.noundo') } }
    try {
        $r = & $handler $Entry
        $all = @(Get-WCJournal)
        foreach ($e in $all) {
            if ((Get-WCProp $e 'Id') -eq (Get-WCProp $Entry 'Id')) { $e.Result = 'Undone'; break }
        }
        Save-WCJournal $all
        return @{ Ok = $true; Message = (T 'common.success') }
    } catch {
        Write-WCLog 'WARN' ('Hoan tac that bai: ' + $_.Exception.Message)
        return @{ Ok = $false; Message = $_.Exception.Message }
    }
}

function Restore-WCSessionScopedEntries {
    # Khoi phuc cac entry AutoRestore=True chua undone (dich vu dung tam...) - chay 1 lan khi khoi dong
    if ($Script:WcJournalSessionRestored) { return }
    $Script:WcJournalSessionRestored = $true
    $all = @(Get-WCJournal)
    $pending = @($all | Where-Object { ($_.AutoRestore -eq $true) -and ($_.Result -eq 'Ok') })
    if ($pending.Count -eq 0) { return }
    Write-WCLog 'JOURNAL' ('Phat hien ' + $pending.Count + ' entry can tu phuc hoi tu phien truoc')
    $changed = $false
    foreach ($e in $pending) {
        $type = [string](Get-WCProp $e 'UndoType')
        if ($Script:WcUndoHandlers.ContainsKey($type)) {
            try {
                & $Script:WcUndoHandlers[$type] $e | Out-Null
                $e.Result = 'AutoRestored'
                $changed = $true
                Write-WCLog 'JOURNAL' ('Da tu phuc hoi: ' + $e.Target)
            } catch { Write-WCLog 'WARN' ('Tu phuc hoi that bai: ' + $e.Target + ' -> ' + $_.Exception.Message) }
        }
    }
    if ($changed) { Save-WCJournal $all }
}

function Restore-WCPendingSessionEntries {
    # Goi khi THOAT app: phuc hoi moi entry AutoRestore con 'Ok'
    $all = @(Get-WCJournal)
    $pending = @($all | Where-Object { ($_.AutoRestore -eq $true) -and ($_.Result -eq 'Ok') })
    foreach ($e in $pending) {
        $type = [string](Get-WCProp $e 'UndoType')
        if ($Script:WcUndoHandlers.ContainsKey($type)) {
            try {
                & $Script:WcUndoHandlers[$type] $e | Out-Null
                $e.Result = 'AutoRestored'
                Write-WCLog 'JOURNAL' ('Thoat app -> da phuc hoi: ' + $e.Target)
            } catch { Write-WCLog 'WARN' ('Phuc hoi khi thoat that bai: ' + $e.Target) }
        }
    }
    if ($pending.Count -gt 0) { Save-WCJournal $all }
}

# ---------------------------------------------------------------------------
# Cac undo handler co ban dang ky san
# ---------------------------------------------------------------------------
Register-WCUndoHandler 'service.start' {
    # Khoi phuc dich vu bi dung tam (M1 che do 3)
    param($Entry)
    $args2 = $Entry.UndoArgs
    $name = [string](Get-WCProp $args2 'Name')
    $startType = [string](Get-WCProp $args2 'StartType')
    if ($name) {
        $svc = Get-Service -Name $name -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -ne 'Running') {
            Start-Service -Name $name -ErrorAction Stop
        }
        if ($startType -and $svc) {
            # Khoi phuc dung kieu khoi dong goc
            Set-Service -Name $name -StartupType $startType -ErrorAction SilentlyContinue
        }
    }
}

Register-WCUndoHandler 'hibernate.on' {
    # Khoi phuc ngu dong sau khi "tat ngu dong" (M2 muc RUI RO, dao nguoc duoc)
    param($Entry)
    Start-Process -FilePath 'powercfg.exe' -ArgumentList @('/h','on') -WindowStyle Hidden -Wait
}

Register-WCUndoHandler 'startup.enable' {
    # Bat lai muc khoi dong da tat qua StartupApproved (M5/M7, nhu Task Manager)
    param($Entry)
    $args2 = $Entry.UndoArgs
    $regPath = [string](Get-WCProp $args2 'RegPath')
    $valueName = [string](Get-WCProp $args2 'ValueName')
    if ($regPath -and $valueName) {
        $bytes = [byte[]]@(0,0,0,0,0,0,0,0,0,0,0,0)   # 12 byte 0 = dang BAT (nhu Task Manager)
        [Microsoft.Win32.Registry]::SetValue($regPath, $valueName, [byte[]]$bytes, [Microsoft.Win32.RegistryValueKind]::Binary)
    }
}
