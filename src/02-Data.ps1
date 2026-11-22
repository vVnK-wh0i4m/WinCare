# ============================================================================
#  src/02-Data.ps1 - Thu muc du lieu, settings, logging (thread-safe)
# ============================================================================

if (-not ('WinCare.CoreUtil' -as [type])) {
    Add-Type -TypeDefinition @'
using System.Collections.Concurrent;
using System.Collections;

namespace WinCare {
    public static class CoreUtil {
        public static readonly object LogLock = new object();
    }

    // Message worker -> UI (khong dung scriptblock qua runspace - ngai deadlock)
    public class TaskMessage {
        public string Type;   // Progress | Log | Data
        public string Text;
        public int Pct;
    }

    // Ng canh bao huy + hang doi ket qua, goi duoc tu bat ky runspace nao
    public class TaskContext {
        public string Id;
        public System.Threading.ManualResetEvent CancelEvent;
        public ConcurrentQueue<TaskMessage> Queue;
        public void Post(TaskMessage m) { Queue.Enqueue(m); }
        public void Progress(int pct, string text) {
            TaskMessage m = new TaskMessage(); m.Type = "Progress"; m.Pct = pct; m.Text = text; Queue.Enqueue(m);
        }
        public void Log(string text) {
            TaskMessage m = new TaskMessage(); m.Type = "Log"; m.Text = text; Queue.Enqueue(m);
        }
        public bool Cancelled() { return CancelEvent.WaitOne(0); }
    }
}
'@
}

function Initialize-WCData {
    # Tao cay thu muc: %ProgramData%\WinCare\{logs, backups, reports}
    $root = Get-WCDataRoot
    foreach ($sub in @('', 'logs', 'backups', 'reports')) {
        $p = if ($sub -eq '') { $root } else { Join-Path $root $sub }
        if (-not (Test-Path -LiteralPath $p)) {
            New-Item -Path $p -ItemType Directory -Force | Out-Null
        }
    }
    $Script:WcLogFile = Join-Path $root ('logs\wincare-' + (Get-Date -Format 'yyyy-MM-dd') + '.log')
}

function Get-WCLogPath { return $Script:WcLogFile }

function Write-WCLog {
    # Log dong thoi an toan nhieu thread (worker runspace + UI). KHONG ghi du lieu nhay cam.
    param(
        [string]$Level = 'INFO',
        [string]$Text = ''
    )
    try {
        $logFile = Get-WCState 'WcLogFile'
        if (-not $logFile) { return }
        $line = ('{0} [{1}] [{2}] {3}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $PID, $Text)
        [Threading.Monitor]::Enter([WinCare.CoreUtil]::LogLock)
        try {
            [IO.File]::AppendAllText($logFile, $line + [Environment]::NewLine, (New-Object Text.UTF8Encoding($false)))
        } finally {
            [Threading.Monitor]::Exit([WinCare.CoreUtil]::LogLock)
        }
    } catch { }
}

function Open-WCDataFolder {
    try { Start-Process explorer.exe -ArgumentList (Get-WCDataRoot) } catch { Show-WCError (T 'common.cannotopen') $_.Exception.Message }
}

function Remove-WCAllData {
    # Nut "Xoa du lieu WinCare" (spec 2.4) - xoa toan bo logs/journal/backups/settings
    $root = Get-WCDataRoot
    if (Test-Path -LiteralPath $root) {
        Get-ChildItem -LiteralPath $root -Force -ErrorAction SilentlyContinue | ForEach-Object {
            # Log file dang mo boi chinh app: bo qua file log hom nay
            if ($_.FullName -ne $Script:WcLogFile) {
                Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# ---------------------------------------------------------------------------
# Settings (settings.json trong thu muc du lieu)
# ---------------------------------------------------------------------------
function Get-WCSettingsPath { return (Join-Path (Get-WCDataRoot) 'settings.json') }

function Load-WCSettings {
    $Script:WcSettings = @{
        lang = 'vi'; theme = 'system'; dryRun = $false; expert = $false
        maskSensitive = $true; firstRunDone = $false; serviceTimeoutMin = 0
    }
    $path = Get-WCSettingsPath
    if (Test-Path -LiteralPath $path) {
        try {
            $json = [IO.File]::ReadAllText($path)
            $obj = ConvertFrom-Json $json
            foreach ($k in @('lang','theme','dryRun','expert','maskSensitive','firstRunDone','serviceTimeoutMin')) {
                $p = $obj.PSObject.Properties[$k]
                if ($p) { $Script:WcSettings[$k] = $p.Value }
            }
        } catch { Write-WCLog 'WARN' ('settings.json hong -> dung mac dinh: ' + $_.Exception.Message) }
    }
    # Bien moi truong de cao hon file cau hinh
    if ($Script:WcLang) { $Script:WcSettings['lang'] = $Script:WcLang }
    if ($Script:WcDryRun) { $Script:WcSettings['dryRun'] = $true }
}

function Save-WCSettings {
    try {
        $json = ConvertTo-Json $Script:WcSettings -Depth 4
        [IO.File]::WriteAllText((Get-WCSettingsPath), $json, (New-Object Text.UTF8Encoding($false)))
    } catch { Write-WCLog 'WARN' ('Khong luu duoc settings: ' + $_.Exception.Message) }
}

function Get-WCSetting {
    param([string]$Key)
    $s = Get-WCState 'WcSettings'
    if ($s -and $s.ContainsKey($Key)) { return $s[$Key] }
    return $null
}

function Set-WCSetting {
    param([string]$Key, $Value)
    $Script:WcSettings[$Key] = $Value
    Save-WCSettings
}
function Test-WCExpertMode  { return [bool](Get-WCSetting 'expert') }
function Test-WCDryRunMode  { return [bool](Get-WCSetting 'dryRun') }
function Test-WCMaskMode    { return [bool](Get-WCSetting 'maskSensitive') }
