# ============================================================================
#  src/06-TaskRunner.ps1 - Task runner nen (runspace + queue + DispatcherTimer)
#  UI thread chi ve; viec > 100ms chay o runspace nen; ket qua ve qua
#  ConcurrentQueue, UI rut hang bang DispatcherTimer (spec 2.2).
#  Runspace nen KHONG thay scope cha -> nap ham bang InitialSessionState.
#  KHONG truyen scriptblock qua ranh gioi runspace (ngai deadlock): worker duoc
#  truyen duoi dang TEXT va bien dich lai trong runspace moi.
# ============================================================================

$Script:WcRunspacePool = $null
$Script:WcTasks = @{}
$Script:WcTaskTimer = $null

function Initialize-WCTaskRunner {
    # Nap toan bo ham cua script vao InitialSessionState de worker goi duoc
    # (SessionStateFunctionEntry - spec 2.2)
    $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    $fnCount = 0
    foreach ($f in (Get-ChildItem Function: -ErrorAction SilentlyContinue)) {
        if ([string]::IsNullOrEmpty($f.ModuleName) -and $f.Definition) {
            try {
                $entry = [System.Management.Automation.Runspaces.SessionStateFunctionEntry]::new($f.Name, $f.Definition)
                $iss.Commands.Add($entry) | Out-Null
                $fnCount++
            } catch { }
        }
    }
    # Bien chia se: hashtable la reference type -> thay doi song voi UI session.
    # Worker lay gia tri thong qua Get-WCState (scope Global cua runspace).
    $shared = @{
        'WcSettings'           = $Script:WcSettings
        'WcL10n'               = $Script:WcL10n
        'WcQueryCache'         = $Script:WcQueryCache
        'WcFixture'            = $Script:WcFixture
        'WcDeleteRoots'        = $Script:WcDeleteRoots
        'WcProtectedProcesses' = $Script:WcProtectedProcesses
        'WcLogFile'            = $Script:WcLogFile
        'WcDebug'              = $Script:WcDebug
        'WcDryRun'             = (Test-WCDryRunMode)
        'WcInv'                = $Script:WcInv
        'WcName'               = $Script:WcName
        'WcVersion'            = $Script:WcVersion
        'WcSelfUrl'            = (Get-WCSelfUrl)
    }
    foreach ($name in @($shared.Keys)) {
        $v = [System.Management.Automation.Runspaces.SessionStateVariableEntry]::new($name, $shared[$name], $null)
        $iss.Variables.Add($v) | Out-Null
    }
    $Script:WcRunspacePool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1, 4, $iss, $Host)
    $Script:WcRunspacePool.ThreadOptions = [System.Management.Automation.Runspaces.PSThreadOptions]::ReuseThread
    $Script:WcRunspacePool.Open()
    Write-WCDebugMsg ('TaskRunner: da nap ' + $fnCount + ' ham vao runspace pool')
}

function Start-WCTaskPump {
    # DispatcherTimer rut hang doi ket qua cua tat ca task (chi tren UI thread)
    $Script:WcTaskTimer = New-Object Windows.Threading.DispatcherTimer
    $Script:WcTaskTimer.Interval = [TimeSpan]::FromMilliseconds(120)
    $Script:WcTaskTimer.Add_Tick({ try { Invoke-WCTaskPumpTick } catch { Write-WCLog 'ERROR' ('Pump tick: ' + $_.Exception.Message) } }.GetNewClosure())
    $Script:WcTaskTimer.Start()
}

function Stop-WCTaskRunner {
    # Don dep khi thoat: huy task, dong pool (spec 2.2 - khong de tien trinh mo coi)
    if ($Script:WcTaskTimer) { $Script:WcTaskTimer.Stop(); $Script:WcTaskTimer = $null }
    foreach ($id in @($Script:WcTasks.Keys)) {
        try {
            $t = $Script:WcTasks[$id]
            if ($t.Ps -and $t.Ps.InvocationStateInfo.State -eq 'Running') { $t.Ps.Stop() }
        } catch { }
    }
    Start-Sleep -Milliseconds 400
    foreach ($id in @($Script:WcTasks.Keys)) {
        try {
            $t = $Script:WcTasks[$id]
            if ($t.Ps) { $t.Ps.Dispose() }
        } catch { }
    }
    $Script:WcTasks = @{}
    if ($Script:WcRunspacePool) {
        try { $Script:WcRunspacePool.Close() } catch { }
        try { $Script:WcRunspacePool.Dispose() } catch { }
        $Script:WcRunspacePool = $null
    }
}

function Start-WCTask {
    # Chay 1 viec o nen. Vi du:
    #   Start-WCTask -Id 'm2.scan' -Title (T 'm2.title') -Worker { param($ctx, $s) ...; return $ketqua } `
    #                -Args @{ DuLieu = 1 } -Done { param($ketqua) ... } -ShowStatus
    # QUAN TRONG (han che ky thuat):
    #   - Worker chay trong runspace rieng: KHONG thay bien local cua ham goi.
    #     Truyen du lieu qua -Args; trong worker khai bao param($ctx, $s).
    #   - Worker khong goi duoc ham o day? CO - moi ham duoc nap qua InitialSessionState.
    #   - Done/OnMessage chay lai tren UI thread: neu tham chieu bien local
    #     cua ham goi thi PHAI .GetNewClosure() khi truyen vao.
    # Worker ($ctx la WinCare.TaskContext):
    #   $ctx.Progress(50,'Dang quet...') ; $ctx.Log('...') ; $ctx.Cancelled() -> nen dung lai va return
    # Ngoai le trong worker bi bat va chuyen ve UI (khong nuot - spec 2.2).
    # Cung 1 Id dang chay -> tra ve $false (chan 2 tac vu chong len nhau - spec muc 6).
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][scriptblock]$Worker,
        $Args = $null,
        [scriptblock]$Done = $null,
        [scriptblock]$OnMessage = $null,
        [switch]$ShowStatus
    )
    if ($Script:WcTasks.ContainsKey($Id)) {
        $existing = $Script:WcTasks[$Id]
        if ($existing.State -eq 'Running') { return $false }
    }
    if (-not $Script:WcRunspacePool) { Initialize-WCTaskRunner }

    $cancelEvent = New-Object System.Threading.ManualResetEvent($false)
    $ctx = New-Object WinCare.TaskContext
    $ctx.Id = $Id
    $ctx.CancelEvent = $cancelEvent
    $ctx.Queue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[WinCare.TaskMessage]'

    # Worker duoc truyen dang TEXT va bien dich lai trong runspace nen (an toan,
    # khong keo session state cu sang runspace moi). $Args truyen du lieu vao.
    $wrapper = @'
param([string]$WorkerText, $TaskCtx, $WorkerArgs)
try { [Threading.Thread]::CurrentThread.Priority = 'BelowNormal' } catch { }
$workerSb = [scriptblock]::Create($WorkerText)
& $workerSb $TaskCtx $WorkerArgs
'@
    $ps = [PowerShell]::Create()
    $ps.RunspacePool = $Script:WcRunspacePool
    $null = $ps.AddScript($wrapper).AddArgument($Worker.ToString()).AddArgument($ctx).AddArgument($Args)
    $handle = $ps.BeginInvoke()

    $Script:WcTasks[$Id] = @{
        Id = $Id; Title = $Title; Ps = $ps; Handle = $handle; Ctx = $ctx
        State = 'Running'; Done = $Done; OnMessage = $OnMessage
        ShowStatus = [bool]$ShowStatus; StartedAt = [DateTime]::Now
        CancelRequested = $false; CancelTicks = 0; Result = $null; Error = $null
    }
    if ($ShowStatus) { Set-WCStatusTask $Title $false }
    Write-WCDebugMsg ('Task bat dau: ' + $Id)
    return $true
}

function Test-WCTaskRunning {
    param([Parameter(Mandatory)][string]$Id)
    if ($Script:WcTasks.ContainsKey($Id)) {
        return ($Script:WcTasks[$Id].State -eq 'Running')
    }
    return $false
}

function Test-WCAnyTaskRunning {
    foreach ($id in @($Script:WcTasks.Keys)) {
        if ($Script:WcTasks[$id].State -eq 'Running') { return $true }
    }
    return $false
}

function Cancel-WCTask {
    param([Parameter(Mandatory)][string]$Id)
    if (-not $Script:WcTasks.ContainsKey($Id)) { return }
    $t = $Script:WcTasks[$Id]
    if ($t.State -ne 'Running') { return }
    $t.CancelRequested = $true
    $t.Ctx.CancelEvent.Set() | Out-Null
    Set-WCStatusTask $t.Title $true
    Write-WCLog 'INFO' ('Da yeu cau huy task: ' + $Id)
}

function Invoke-WCTaskPumpTick {
    $ids = @($Script:WcTasks.Keys)
    foreach ($id in $ids) {
        $t = $Script:WcTasks[$id]
        if ($null -eq $t) { continue }

        # 1) Rut toan bo message worker -> UI (kieu .NET TaskMessage, truy cap thuoc tinh an toan)
        $msg = $null
        while ($t.Ctx.Queue.TryDequeue([ref]$msg)) {
            try {
                if ($msg.Type -eq 'Progress' -and $t.ShowStatus) {
                    $elapsed = [int](([DateTime]::Now - $t.StartedAt).TotalSeconds)
                    Set-WCStatusTask ($t.Title + ' — ' + $msg.Text + ' (' + $msg.Pct + '%, ' + $elapsed + 's)') $t.CancelRequested
                } elseif ($msg.Type -eq 'Log') {
                    Write-WCLog 'WORKER' $msg.Text
                }
                if ($t.OnMessage) { & $t.OnMessage $msg }
            } catch { Write-WCLog 'WARN' ('Xu ly message task that bai: ' + $_.Exception.Message) }
            $msg = $null
        }

        # 2) Chuyen trang thai khi worker ket thuc
        if ($t.State -eq 'Running') {
            $st = $t.Ps.InvocationStateInfo.State
            if (($st -eq 'Completed') -or ($st -eq 'Failed') -or ($st -eq 'Stopped')) {
                $errorText = $null
                try { $t.Result = $t.Ps.EndInvoke($t.Handle) } catch { $errorText = $_.Exception.Message }
                # Thu thom loi tu stream neu co
                if ($t.Ps.Streams.Error.Count -gt 0) {
                    $errorText = [string]$t.Ps.Streams.Error[0]
                }
                if ($t.CancelRequested) { $t.State = 'Cancelled' }
                elseif ($errorText) { $t.State = 'Failed'; $t.Error = $errorText }
                else { $t.State = 'Completed' }
                try { $t.Ps.Dispose() } catch { }
                $t.Ps = $null
                Write-WCDebugMsg ('Task ket thuc: ' + $id + ' -> ' + $t.State)

                if ($t.ShowStatus) { Set-WCStatusTask $null $false }
                if ($t.State -eq 'Completed' -and $t.Done) {
                    # Quy uoc: 1 object duy nhat -> truyen thang; nhieu object -> mang
                    $resultData = $null
                    if ($t.Result) {
                        if ($t.Result.Count -eq 1) { $resultData = $t.Result[0] }
                        elseif ($t.Result.Count -gt 1) { $resultData = @($t.Result) }
                    }
                    try { & $t.Done $resultData } catch { Show-WCError (T 'common.error') $_.Exception.Message }
                } elseif ($t.State -eq 'Failed') {
                    Write-WCLog 'ERROR' ('Task ' + $id + ' that bai: ' + $t.Error)
                    Show-WCError (T 'common.task.failed') $t.Error
                } elseif ($t.State -eq 'Cancelled') {
                    Show-WCToast (T 'common.task.cancelled') 'Info'
                }
            } elseif ($t.CancelRequested) {
                # Sau ~3 giay ma van chay -> ep dung pipeline (worker co the dang cho lenh ngoai)
                $t.CancelTicks++
                if ($t.CancelTicks -ge 25) { try { $t.Ps.Stop() } catch { } }
            }
        }
    }
}
