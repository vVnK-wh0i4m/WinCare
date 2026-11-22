# ============================================================================
#  src/21-Main.ps1 - Chuoi khoi dong + chay app + don dep
#  Thu tu (spec 2.1): kiem tra moi truong -> Admin -> STA -> mutex -> data ->
#  module -> shell -> ShowDialog -> cleanup. Khong dung exit top-level.
# ============================================================================

function Initialize-WCModules {
    # Khoi tao tung module, moi module mot try/catch (loi 1 module khong sap app)
    $initializers = @(
        'Initialize-WCModuleDashboard'
        'Initialize-WCModuleM1'
        'Initialize-WCModuleM2'
        'Initialize-WCModuleM3'
        'Initialize-WCModuleM4'
        'Initialize-WCModuleM5'
        'Initialize-WCModuleM6'
        'Initialize-WCModuleM7'
        'Initialize-WCModuleHistory'
        'Initialize-WCModuleSettings'
    )
    foreach ($name in $initializers) {
        try {
            $fn = Get-Command -Name $name -ErrorAction SilentlyContinue
            if ($fn) { & $fn }
            else { Write-WCLog 'WARN' ('Khong tim ham khoi tao: ' + $name) }
        } catch {
            Write-WCLog 'ERROR' ('Khoi tao module that bai [' + $name + ']: ' + $_.Exception.Message)
        }
    }
}

function Invoke-WCBoot {
    # Diem vao duy nhat (irm | iex dan vao day). Tra ve $true neu app da chay xong.
    # 1) Kiem tra moi truong
    $platform = Test-WCPlatform
    if ($platform.Status -ne 'Ok') {
        try {
            [Windows.MessageBox]::Show($platform.Reason, (Get-WCName), [Windows.MessageBoxButton]::OK, [Windows.MessageBoxImage]::Warning) | Out-Null
        } catch { Write-Output $platform.Reason }
        return $false
    }

    # 2) Nang quyen Admin (spec 2.1: relaunch -Verb RunAs; tu choi -> thong bao than thien)
    if (-not (Get-WCIsAdmin)) {
        $elevated = Invoke-WCElevation
        if (-not $elevated) { return $false }   # da thong bao cho nguoi dung
        # Da relaunch tien trinh moi o che do Admin; tien trinh nay thoat an tinh
        return $true
    }

    # 3) STA cho WPF (relaunch -STA neu can)
    if (-not (Test-WCSTA)) {
        if (-not (Test-WCSelfUrlPlaceholder)) {
            $url = Get-WCSelfUrl
            try {
                Start-Process -FilePath 'powershell.exe' `
                    -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-STA','-WindowStyle','Hidden','-Command', ("irm '" + $url + "' | iex")) `
                    -Verb RunAs -ErrorAction Stop
                return $true
            } catch { }
        }
        # Khong relaunch duoc -> bao ro (WPF can STA)
        try {
            [Windows.MessageBox]::Show((T 'boot.err.wpf'), (Get-WCName), [Windows.MessageBoxButton]::OK, [Windows.MessageBoxImage]::Warning) | Out-Null
        } catch { }
        return $false
    }

    # 4) Mot instance duy nhat (mutex)
    if (-not (Initialize-WCSingleInstance)) {
        return $true    # instance cu da duoc dua len truoc
    }

    # 5) Du lieu + settings + journal + fixture + interop
    Initialize-WCData
    Write-WCLog 'INFO' ('===== ' + (Get-WCName) + ' ' + (Get-WCVersion) + ' khoi dong =====')
    Load-WCSettings
    Initialize-WCDefaultDeleteRoots
    Initialize-WCJournal
    Initialize-WCFixture
    try { Add-WCNativeType } catch { Write-WCLog 'WARN' ('Add-WCNativeType: ' + $_.Exception.Message) }

    # 6) Dang ky module + shell + chay
    Initialize-WCModules
    Show-WCShell

    # 7) Don dep (shell Closed da don task/mutex; day la phong thu)
    try { Stop-WCTaskRunner } catch { }
    try {
        if ($Script:WcMutex) {
            $Script:WcMutex.ReleaseMutex()
            $Script:WcMutex.Dispose()
            $Script:WcMutex = $null
        }
    } catch { }
    Write-WCLog 'INFO' '===== Thoat ====='
    return $true
}

# CHAY (khong exit top-level - spec muc 1.4)
$null = Invoke-WCBoot
