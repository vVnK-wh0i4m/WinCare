# ============================================================================
#  src/01-Environment.ps1 - Kiem tra moi truong, tu nang quyen Admin, mutex
# ============================================================================

function Test-WCPlatform {
    # Tra ve $true neu moi truong dat yeu cau; neu khong dat -> hien loi ro rang
    # Windows 10 1809 (build 17763) tro len, 64-bit, PS 5.1+, co WPF (spec 2.1)
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
        return (New-WCResult -Status 'Bad' -Reason (T 'boot.err.notwindows'))
    }
    $ver = [Environment]::OSVersion.Version
    if (($ver.Major -lt 10) -or (($ver.Major -eq 10) -and ($ver.Build -lt 17763))) {
        return (New-WCResult -Status 'Bad' -Reason ("Windows 10 1809+ / Windows 11 can thiet. Phat hien: build $($ver.Build)" ))
    }
    if (-not [Environment]::Is64BitOperatingSystem) {
        return (New-WCResult -Status 'Bad' -Reason (T 'boot.err.64bit'))
    }
    if ($PSVersionTable.PSVersion.Major -lt 5) {
        return (New-WCResult -Status 'Bad' -Reason (T 'boot.err.ps5'))
    }
    # WPF: PresentationFramework phai nap duoc (khong co tren PowerShell 6 hoac Linux)
    try {
        Add-Type -AssemblyName PresentationFramework -ErrorAction Stop
        Add-Type -AssemblyName PresentationCore -ErrorAction Stop
        Add-Type -AssemblyName WindowsBase -ErrorAction Stop
        Add-Type -AssemblyName System.Xaml -ErrorAction Stop
    } catch {
        return (New-WCResult -Status 'Bad' -Reason ((T 'boot.err.wpf') + ' [' + $_.Exception.Message + ']'))
    }
    return (New-WCResult -Status 'Ok' -Data $true)
}

function Get-WCIsAdmin {
    # Kiem tra theo WindowsBuiltInRole::Administrator, KHONG theo ten nhom (spec 2.1)
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Invoke-WCElevation {
    # Tu xin quyen Admin (spec 2.1). Neu SelfUrl la placeholder -> huong dan bang tay.
    # Tra ve $true neu da la Admin hoac da relaunch (goi nay ket thuc tien trinh hien tai).
    if (Get-WCIsAdmin) { return $true }

    $url = Get-WCSelfUrl
    if (Test-WCSelfUrlPlaceholder) {
        # Khong co URL that -> khong the tu relaunch; huong dan than thien
        $msg = (T 'boot.elev.manual') -f $url
        try { [Windows.MessageBox]::Show($msg, $Script:WcName, [Windows.MessageBoxButton]::OK, [Windows.MessageBoxImage]::Information) | Out-Null } catch { Write-Output $msg }
        return $false
    }
    $cmd = "irm '$url' | iex"
    try {
        Start-Process -FilePath 'powershell.exe' `
            -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-STA','-WindowStyle','Hidden','-Command', $cmd) `
            -Verb RunAs -ErrorAction Stop
        return $true
    } catch {
        # UAC bi tu choi -> thong bao than thien, khong treo, khong do lo (spec 2.1)
        try { [Windows.MessageBox]::Show((T 'boot.elev.declined'), $Script:WcName, [Windows.MessageBoxButton]::OK, [Windows.MessageBoxImage]::Information) | Out-Null } catch { }
        return $false
    }
}

function Initialize-WCSingleInstance {
    # Mot instance duy nhat (Mutex ten co dinh). Lan 2 -> dua cua so cu len truoc (spec 2.1)
    $created = $false
    $mutex = New-Object System.Threading.Mutex($true, 'Global\WinCare_SingleInstance', [ref]$created)
    if ($created) {
        $Script:WcMutex = $mutex
        return $true
    }
    # Da co instance: tim cua so WinCare va dua len truoc
    try {
        Add-WCNativeType
        [WinCare.Native]::ActivateExistingWindow($Script:WcName)
    } catch { }
    try { $mutex.ReleaseMutex() } catch { }
    $mutex.Dispose()
    return $false
}

function Test-WCSTA {
    # WPF can STA tren UI thread
    $state = [Threading.Thread]::CurrentThread.ApartmentState
    return ($state -eq [Threading.ApartmentState]::STA)
}
