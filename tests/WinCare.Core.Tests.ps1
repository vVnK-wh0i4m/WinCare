# ============================================================================
#  WinCare.Core.Tests.ps1 - Pester tests cho logic thuan (chay duoc tren pwsh Linux)
#  Cac phan phu thuoc Windows that (registry/CIM/WPF) duoc SKIP tren non-Windows
#  va ghi ro trong TEST-REPORT.md (spec muc 1.6 - khong ghi PASS cho thu chua chay).
# ============================================================================
if (-not (Get-Module -ListAvailable -Name Pester)) {
    Write-Output 'Pester chua cai. Cai: Install-Module Pester -Force -Scope CurrentUser'
    exit 1
}
$pesterVer = (Get-Module -ListAvailable -Name Pester | Sort-Object Version -Descending | Select-Object -First 1).Version
if ($pesterVer.Major -lt 5) {
    Write-Output ('Can Pester 5+ (Windows co san 3.x) - phat hien ' + $pesterVer)
    exit 1
}

# ---------------------------------------------------------------------------
# BOOTSTRAP: nap khung lõi WinCare (KHONG nap 21-Main de boot khong chay)
# $PSScriptRoot = tests/; goc = ..
# ---------------------------------------------------------------------------
BeforeAll {
    $root = Split-Path -Parent $PSScriptRoot
    # Linux/macOS: stub %ProgramData% de Get-WCDataRoot thao tac thu muc test
    if ($env:ProgramData -eq $null -or $env:ProgramData -eq '') {
        $env:ProgramData = (Join-Path ([IO.Path]::GetTempPath()) 'wincare-test-programdata')
    }
    # Nap theo thu tu (00 -> 20, bo 21-Main)
    $files = @(Get-ChildItem -Path (Join-Path $root 'src') -Filter '*.ps1' | Sort-Object Name | Where-Object { $_.Name -ne '21-Main.ps1' })
    foreach ($f in $files) {
        . $f.FullName
    }
    # Pester 6: $Script: dot-sourced khong nhat quan giua BeforeAll/It
    # -> chup lai bang chuoi vao $script: scope (Pester khuyen dung)
    $script:WC_L10N_SNAPSHOT = $Script:WcL10n
    # Don dep che do strict/EAP cho moi truong test
    Set-StrictMode -Off
    $ErrorActionPreference = 'Continue'
}

Describe 'i18n: du chuoi vi/en day du (spec: ngon ngu vi mac dinh, en phu)' {
    It 'moi key vi deu co key en' {
        $vi = $script:WC_L10N_SNAPSHOT['vi'].Keys
        $en = $script:WC_L10N_SNAPSHOT['en'].Keys
        $missing = @($vi | Where-Object { $en -notcontains $_ })
        $missing.Count | Should -Be 0
    }
    It 'moi key en deu co key vi' {
        $vi = $script:WC_L10N_SNAPSHOT['vi'].Keys
        $en = $script:WC_L10N_SNAPSHOT['en'].Keys
        $missing = @($en | Where-Object { $vi -notcontains $_ })
        $missing.Count | Should -Be 0
    }
    It 'khong co chuoi rong' {
        $empty = @($script:WC_L10N_SNAPSHOT['vi'].Values | Where-Object { [string]::IsNullOrEmpty($_) })
        $empty.Count | Should -Be 0
    }
    It 'T() tra key khi thieu (khong throw)' {
        { T 'khong.ton.tai.nao' } | Should -Not -Throw
        T 'khong.ton.tai.nao' | Should -Be 'khong.ton.tai.nao'
    }
}

Describe 'Journal: ghi/doc/hoan tac/tu phuc hoi (spec 2.4)' {
    BeforeEach {
        Initialize-WCData
        Initialize-WCJournal
        Save-WCJournal @()   # xoa sach truoc moi test
    }
    It 'Add-WCJournalEntry -> Get-WCJournal doc lai du' {
        $e = Add-WCJournalEntry -Module 'TEST' -Action 'Hanh dong' -Target 'Doi tuong' -OldValue 'A' -UndoType 'test.undo' -UndoArgs @{ X = 1 }
        $all = @(Get-WCJournal)
        $all.Count | Should -Be 1
        $all[0].Module | Should -Be 'TEST'
        $all[0].Action | Should -Be 'Hanh dong'
        $all[0].UndoType | Should -Be 'test.undo'
    }
    It 'Undo-WCJournalEntry goi handler dung va danh dau Undone' {
        $script:undoCalled = 0
        Register-WCUndoHandler 'test.undo2' { param($entry) $script:undoCalled = 1 }
        $e = Add-WCJournalEntry -Module 'TEST' -Action 'A' -Target 'T' -UndoType 'test.undo2'
        $r = Undo-WCJournalEntry $e
        $r.Ok | Should -Be $true
        $script:undoCalled | Should -Be 1
        (@(Get-WCJournal)[0]).Result | Should -Be 'Undone'
    }
    It 'Restore-WCPendingSessionEntries phuc hoi entry AutoRestore chua undone' {
        $script:restored = 0
        Register-WCUndoHandler 'test.restore' { param($entry) $script:restored++ }
        $e = Add-WCJournalEntry -Module 'TEST' -Action 'A' -Target 'T1' -UndoType 'test.restore' -AutoRestore
        # Entry phai hoan thanh ('Ok') truoc khi duoc tu phuc hoi (dung vong thuc te)
        Complete-WCJournalEntry -Entry $e -Result 'Ok'
        $all = @(Get-WCJournal)
        $all[0].Result | Should -Be 'Ok'
        Restore-WCPendingSessionEntries
        $script:restored | Should -Be 1
        (@(Get-WCJournal)[0]).Result | Should -Be 'AutoRestored'
    }
    It 'Undo khong co handler -> that bai ro rang, khong throw' {
        $e = Add-WCJournalEntry -Module 'TEST' -Action 'A' -Target 'T' -UndoType 'khong.co.handler'
        { Undo-WCJournalEntry $e } | Should -Not -Throw
        (Undo-WCJournalEntry $e).Ok | Should -Be $false
    }
}

Describe 'Assert-SafePath: tu choi duong dan nguy hiem (spec 2.5)' {
    BeforeAll {
        Initialize-WCData
        Initialize-WCDefaultDeleteRoots
    }
    It 'tu choi duong dan TUONG DOI' {
        Assert-SafePath 'duong/doi/tuong.ps1' | Should -Be $false
    }
    It 'tu choi duong dan chua segment ..' {
        # 'C:\...' tren Linux la tuong doi -> tu choi; tren Windows cung phai tu choi
        Assert-SafePath 'C:\Windows\Temp\..\..\system32\evil.dll' | Should -Be $false
    }
    It 'tu choi goc o dia truc tiep' {
        if ($IsWindows) {
            Assert-SafePath 'C:\' | Should -Be $false
        } else {
            # Linux: /tmp duoc trong whitelist con '/' phai tu choi
            Assert-SafePath '/' | Should -Be $false
        }
    }
    It 'chap nhan duong dan hop le trong whitelist (temp)' {
        if ($IsWindows) {
            Assert-SafePath (Join-Path ([IO.Path]::GetTempPath()) 'wincare-test\x.txt') | Should -Be $true
        } else {
            Assert-SafePath '/tmp/wincare-test/x.txt' | Should -Be $true
        }
    }
    It 'tu choi ngoai whitelist' {
        if ($IsWindows) {
            Assert-SafePath (Join-Path $env:USERPROFILE 'Documents\quan-trong.docx') | Should -Be $false
        } else {
            Assert-SafePath '/home/nguoi-dung/du-lieu-quan-trong.docx' | Should -Be $false
        }
    }
}

Describe 'Junction/symlink: Assert-SafePath phai chan (fix 2.1 - bao cao do loi)' {
    # Bai hoc su co: vong kiem tra reparse cu dung Combine('C:',...) -> duong dan
    # TUONG DOI -> GetAttributes luon throw -> khong phat hien junction; dong thoi
    # bo qua segment cuoi. Test nay tao junction/symlink that de chang hoi lai.
    BeforeAll {
        Initialize-WCData
        Initialize-WCDefaultDeleteRoots
    }
    It 'tu choi duong dan DI QUA junction/symlink + muc junction cuoi + Remove-WCItem khong xoa thu muc moi' {
        $base = Join-Path ([IO.Path]::GetTempPath()) ('wincare-junc-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
        $real = Join-Path $base 'real'
        $link = Join-Path $base 'link'
        New-Item -ItemType Directory -Path $real -Force | Out-Null
        $bait = Join-Path $real 'tep-moi.txt'
        Set-Content -LiteralPath $bait -Value 'du lieu quy'
        $made = $true
        try {
            if ($IsWindows) {
                New-Item -ItemType Junction -Path $link -Target $real -ErrorAction Stop | Out-Null
            } else {
                New-Item -ItemType SymbolicLink -Path $link -Target $real -ErrorAction Stop | Out-Null
            }
        } catch { $made = $false }
        if (-not $made) {
            Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
            Set-ItResult -Skipped -Because 'moi truong khong tao duoc junction/symlink'
            return
        }
        try {
            # Di qua junction (segment trung gian) -> tu choi
            Assert-SafePath (Join-Path $link 'tep-moi.txt') | Should -Be $false
            # Chinh junction la muc xoa (segment cuoi) -> tu choi
            Assert-SafePath $link | Should -Be $false
            # Ham xoa duy nhat cung phai tu choi, tep moi con nguyen
            $r = Remove-WCItem -Path (Join-Path $link 'tep-moi.txt')
            $r.Deleted | Should -Be 0
            (Test-Path -LiteralPath $bait) | Should -Be $true
        } finally {
            Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Whitelist browser: CHI muc cache cua tung profile (fix 2.3)' {
    # Bai hoc su co: whitelist cu chap nhan ca thu muc "User Data" / "Profiles"
    # (chua Login Data, Cookies...) - chi can M2 sai liet ke la mat mat khau.
    It 'Login Data / Cookies bi tu choi, thu muc cache duoc chap nhan' {
        if (-not $IsWindows) {
            Set-ItResult -Skipped -Because 'cau truc thu muc browser chi dung tren Windows'
            return
        }
        $base = Join-Path $env:USERPROFILE ('wincare-browser-test-' + [Guid]::NewGuid().ToString('N').Substring(0, 8))
        $ud = Join-Path $base 'Google\Chrome\User Data\Default'
        New-Item -ItemType Directory -Path (Join-Path $ud 'Cache') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $ud 'Code Cache') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $ud 'Login Data') -Value 'mat khau'
        $old = $env:LOCALAPPDATA
        $env:LOCALAPPDATA = $base
        try {
            Initialize-WCDefaultDeleteRoots
            # Du lieu nhay cam trong profile -> KHONG BAO GIO duoc phep xoa
            Assert-SafePath (Join-Path $ud 'Login Data') | Should -Be $false
            Assert-SafePath (Join-Path $ud 'Cookies') | Should -Be $false
            # Muc cache cua profile do -> duoc chap nhan
            Assert-SafePath (Join-Path $ud 'Cache\data_0') | Should -Be $true
            Assert-SafePath (Join-Path $ud 'Code Cache\xay-dung') | Should -Be $true
        } finally {
            $env:LOCALAPPDATA = $old
            Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Remove-WCAllData: di qua Remove-WCItem + ton trong DRYRUN (fix 2.2)' {
    BeforeEach {
        Initialize-WCData
        Load-WCSettings      # app goi trong Invoke-WCBoot; khoi tao $Script:WcSettings
        Set-WCSetting 'dryRun' $false
    }
    AfterAll { Set-WCSetting 'dryRun' $false }
    It 'che do DRYRUN -> khong xoa bat ky cai gi' {
        $marker = Join-Path (Get-WCDataRoot) 'marker-giu-nguyen.json'
        Set-Content -LiteralPath $marker -Value 'x'
        Set-WCSetting 'dryRun' $true
        { Remove-WCAllData } | Should -Not -Throw
        (Test-Path -LiteralPath $marker) | Should -Be $true
        Set-WCSetting 'dryRun' $false
    }
    It 'xoa that -> marker bien mat, cay thu muc tao lai, file log hom nay con lai' {
        $root = Get-WCDataRoot
        $marker = Join-Path $root 'marker-xoa.json'
        Set-Content -LiteralPath $marker -Value 'x'
        Write-WCLog 'INFO' 'test Remove-WCAllData'   # dam bao file log hom nay ton tai
        Remove-WCAllData
        (Test-Path -LiteralPath $marker) | Should -Be $false
        # Cay thu muc chuan duoc tao lai de app van hoat dong
        (Test-Path -LiteralPath $root) | Should -Be $true
        foreach ($d in @('logs', 'backups', 'reports')) {
            (Test-Path -LiteralPath (Join-Path $root $d)) | Should -Be $true
        }
        # File log hom nay duoc giu lai (so sanh DUNG duong dan trong thu muc logs)
        (Test-Path -LiteralPath (Get-WCLogPath)) | Should -Be $true
    }
}

Describe 'M6 Get-WCHealthScore: cong thuc diem minh bach (spec M6)' {
    It 'tat ca nhom diem day -> 100' {
        $g = @{
            Storage = @{ Status = 'Ok'; Score = 100 }
            Stability = @{ Status = 'Ok'; Score = 100 }
            Integrity = @{ Status = 'Ok'; Score = 100 }
            Security = @{ Status = 'Ok'; Score = 100 }
            Memory = @{ Status = 'Ok'; Score = 100 }
            Battery = @{ Status = 'Ok'; Score = 100 }
        }
        (Get-WCHealthScore $g).Score | Should -Be 100
    }
    It 'thieu Battery (may ban) -> BO khoi mau so, khong tinh nhu diem toi da' {
        $g = @{
            Storage = @{ Status = 'Ok'; Score = 100 }
            Stability = @{ Status = 'Ok'; Score = 100 }
            Integrity = @{ Status = 'Ok'; Score = 100 }
            Security = @{ Status = 'Ok'; Score = 100 }
            Memory = @{ Status = 'Ok'; Score = 100 }
        }
        $r = Get-WCHealthScore $g
        $r.Score | Should -Be 100
        $r.TotalWeight | Should -Be 90
    }
    It 'dau hieu nghiem trong (Severe) -> tran 49 kem ly do' {
        $g = @{
            Storage = @{ Status = 'Bad'; Score = 20; Severe = $true; Reason = 'SMART bao hong' }
            Stability = @{ Status = 'Ok'; Score = 100 }
            Integrity = @{ Status = 'Ok'; Score = 100 }
            Security = @{ Status = 'Ok'; Score = 100 }
        }
        $r = Get-WCHealthScore $g
        ($r.Score -le 49) | Should -Be $true
        $r.Capped | Should -Be $true
        $r.CapReason | Should -Not -BeNullOrEmpty
    }
    It 'diem thap phan dung trong so' {
        $g = @{
            Storage = @{ Status = 'Warn'; Score = 60 }    # 25 * 0.6 = 15
            Stability = @{ Status = 'Ok'; Score = 100 }   # 25
        }
        $r = Get-WCHealthScore $g
        $r.Score | Should -Be 80   # 40 / 50 = 0.8
    }
    It 'khong nhom nao doc duoc -> Score null (khong doan)' {
        $r = Get-WCHealthScore @{}
        ($null -eq $r.Score) | Should -Be $true
    }
}

Describe 'M7 Get-WCAgingVerdict: may moi khong bi doa (spec M7)' {
    It 'may moi cai (30 ngay, khong dau hieu) -> nhan tot, khong de xuat cai lai' {
        $v = Get-WCAgingVerdict `
            -Age @{ AgeDays = 30 } `
            -Boot @{ Enough = $false } `
            -Startup @{ NonMsCount = 3; NonMsEnabledCount = 3 } `
            -Software $null -Residual $null -Games $null -Sys $null
        $v.Mild | Should -Be 0
        $v.Strong | Should -Be 0
        $v.ReinstallMet | Should -Be $false
    }
    It '4 dau hieu nghiem trong -> de xuat cai lai (ReinstallMet)' {
        $v = Get-WCAgingVerdict `
            -Age @{ AgeDays = 900 } `
            -Boot @{ Enough = $true; DeltaPct = 80 } `
            -Startup @{ NonMsCount = 20; NonMsEnabledCount = 20 } `
            -Software $null -Residual $null -Games $null `
            -Sys @{ DiskFreePct = 5; PendingCount = 3; Bsod90 = 5 }
        $v.ReinstallMet | Should -Be $true
    }
    It '1-2 dau hieu nhe -> KHONG de xuat cai lai' {
        $v = Get-WCAgingVerdict `
            -Age @{ AgeDays = 400 } `
            -Boot @{ Enough = $true; DeltaPct = 30 } `
            -Startup @{ NonMsCount = 5; NonMsEnabledCount = 5 } `
            -Software $null -Residual $null -Games $null -Sys $null
        $v.ReinstallMet | Should -Be $false
    }
}

Describe 'Danh sach tien trinh bao ve M1 (spec M1)' {
    It 'chua tien trinh he thong can thiet' {
        $list = Get-WCProtectedProcesses
        foreach ($must in @('System','csrss','winlogon','lsass','services','dwm','MsMpEng','audiodg')) {
            $list -contains $must | Should -Be $true
        }
    }
}

Describe 'ConvertTo-WCHumanSize / ConvertTo-WCSafeString' {
    It 'dung dinh dang KB/MB/GB (theo culture hien tai)' {
        ConvertTo-WCHumanSize 512 | Should -Be '512 B'
        ConvertTo-WCHumanSize 2048 | Should -Be '2 KB'
        # Ky tu thap phan theo culture cua may chay test (vi/en khac nhau) - khong gia dinh
        (ConvertTo-WCHumanSize (5MB)) | Should -Match ('^5[.,]0 MB$')
        (ConvertTo-WCHumanSize (1GB + 200MB)) | Should -Match ('^1[.,]20 GB$')
    }
    It 'ky tu do WMI -> chuoi sach' {
        $bytes = [byte[]]([int][char]'D'..([int][char]'E' - 1)) + [byte[]](0,0)
        # 'D' la 68 -> mang 68,0
        $b = [byte[]]@(68, 69, 76, 76, 0, 0)
        ConvertTo-WCSafeString $b | Should -Be 'DELL'
    }
}

AfterAll {
    # Don dep thu muc test
    if ($env:ProgramData -like '*wincare-test-programdata*') {
        Remove-Item -LiteralPath $env:ProgramData -Recurse -Force -ErrorAction SilentlyContinue
    }
}
