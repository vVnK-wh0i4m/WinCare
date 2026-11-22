# ============================================================================
#  WinCare - Trinh toi uu & kiem tra Windows (mot file PowerShell duy nhat)
#  File nguon: src/00-Boot.ps1  |  Duoc ghep boi build.ps1 vao dist/WinCare.ps1
#  Yeu cau: Windows 10 1809+ / Windows 11 x64, Windows PowerShell 5.1+ hoac 7+
# ============================================================================

$Script:WcName     = 'WinCare'
$Script:WcVersion  = '1.0.0'
$Script:WcBuild    = '__BUILD_HASH__'   # duoc build.ps1 thay the bang 8 ky tu dau SHA-256
$Script:WcSelfUrlDefault = 'https://raw.githubusercontent.com/WINCARE-PLACEHOLDER/WinCare.ps1'

# iex khong nhan tham so -> moi cau hinh di qua bien moi truong (spec 2.1)
$Script:WcLang     = $env:WINCARE_LANG        # 'vi' | 'en'
$Script:WcDebug    = ($env:WINCARE_DEBUG -eq '1')
$Script:WcDryRun   = ($env:WINCARE_DRYRUN -eq '1')
$Script:WcFixturePath = $env:WINCARE_FIXTURE  # duong dan file JSON du lieu gia (spec 2.3)
$Script:WcSelfUrl  = $env:WINCARE_SELFURL     # URL de tu relaunch khi can Admin

Set-StrictMode -Version 2.0
$Script:WcErrorPreferenceBackup = $ErrorActionPreference
$ErrorActionPreference = 'Stop'

# TLS 1.2 (va 1.3 neu enum co) - can cho irm/Update session tren PS 5.1
try {
    $tls = [Net.SecurityProtocolType]::Tls12
    if (@([Enum]::GetNames([Net.SecurityProtocolType])) -contains 'Tls13') {
        $tls = $tls -bor [Net.SecurityProtocolType]::Tls13
    }
    [Net.ServicePointManager]::SecurityProtocol = $tls
} catch { }

# Parse so lieu luon dung InvariantCulture (spec 2.3 - may dat dau phay thap phan)
$Script:WcInv = [Globalization.CultureInfo]::InvariantCulture
$Script:WcMutex = $null          # mutex single-instance (01-Environment set)

function Get-WCName { return $Script:WcName }
function Get-WCVersion { return $Script:WcVersion }
function Get-WCBuildHash { return $Script:WcBuild }
function Get-WCSelfUrl { if ($Script:WcSelfUrl) { return $Script:WcSelfUrl } else { return $Script:WcSelfUrlDefault } }
function Test-WCSelfUrlPlaceholder { return ((Get-WCSelfUrl) -like '*WINCARE-PLACEHOLDER*') }

function Get-WCDataRoot {
    # Mot thu muc du lieu duy nhat (spec 2.4): %ProgramData%\WinCare
    $root = Join-Path $env:ProgramData $Script:WcName
    return $root
}

function Get-WCState {
    # Truy cap bien script an toan o CA hai moi truong: UI session ($Script:) va
    # worker runspace (InitialSessionState dat bien vao scope Global - spec 2.2)
    param([Parameter(Mandatory)][string]$Name)
    $v = Get-Variable -Name $Name -Scope Script -ErrorAction SilentlyContinue
    if ($v) { return $v.Value }
    $v = Get-Variable -Name $Name -Scope Global -ErrorAction SilentlyContinue
    if ($v) { return $v.Value }
    return $null
}

function Write-WCDebugMsg {
    param([string]$Message)
    if ($Script:WcDebug) { Write-WCLog -Level 'DEBUG' -Text $Message }
}
