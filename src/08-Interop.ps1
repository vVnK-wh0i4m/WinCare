# ============================================================================
#  src/08-Interop.ps1 - P/Invoke Win32 (duoc su dung boi M1/M2)
#  NGUYEN TAC (spec 2.5): C# viet de doc, co chu thich, nam trong 1 here-string.
#  Khong neo AMSI/Defender; neu bi chan -> bao loi ro chu khong lach.
#  Chu y: gia tri enum NT xac minh tu tai lieu cong khai (winternl/Process
#  Hacker); CHUA kiem chung runtime tren Windows that (ghi ro trong TEST-REPORT).
# ============================================================================

function Add-WCNativeType {
    if ('WinCare.Native' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace WinCare
{
    public static class Native
    {
        // ---------------- Process / working set (M1) ----------------
        // PROCESS_SET_QUOTA (0x0100) | PROCESS_QUERY_LIMITED_INFORMATION (0x1000)
        public const uint PROCESS_SET_QUOTA = 0x0100;
        public const uint PROCESS_QUERY_LIMITED_INFORMATION = 0x1000;

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern IntPtr OpenProcess(uint dwDesiredAccess, bool bInheritHandle, int dwProcessId);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool CloseHandle(IntPtr hObject);

        // EmptyWorkingSet: thu gom working set cua 1 tien trinh (chung san kernel32)
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool EmptyWorkingSet(IntPtr hProcess);

        // ---------------- Foreground window (M1: khong trim app dang dung truoc) ---
        [DllImport("user32.dll")]
        public static extern IntPtr GetForegroundWindow();

        [DllImport("user32.dll")]
        public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);

        // ---------------- Cua so (mutex single-instance) ----------------
        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        public static extern IntPtr FindWindowW(string lpClassName, string lpWindowName);

        [DllImport("user32.dll")]
        public static extern bool SetForegroundWindow(IntPtr hWnd);

        [DllImport("user32.dll")]
        public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

        public static void ActivateExistingWindow(string title)
        {
            IntPtr h = FindWindowW(null, title);
            if (h != IntPtr.Zero)
            {
                ShowWindow(h, 9 /* SW_RESTORE */);
                SetForegroundWindow(h);
            }
        }

        // ---------------- Trạng thái toàn màn hình / đỡ làm phiền (M1) -------------
        // SHQueryUserNotificationState: 3 = QUNS_RUNNING_D3D_FULL_SCREEN (game),
        // 4 = QUNS_PRESENTATION_MODE (trình chiếu)
        [DllImport("shell32.dll")]
        public static extern int SHQueryUserNotificationState(out int pqunsState);

        public static bool IsFullScreenOrPresentation()
        {
            try
            {
                int state;
                int hr = SHQueryUserNotificationState(out state);
                if (hr == 0) { return (state == 3 || state == 4 || state == 2); } // D3D fullscreen | presentation | busy
            }
            catch { }
            return false;
        }

        // ----------------特权 + memory list (M1 chế độ 2/3) ----------------
        // SeProfileSingleProcessPrivilege = 19 (bien tai lieu cong khai)
        [DllImport("ntdll.dll")]
        public static extern int RtlAdjustPrivilege(uint Privilege, bool Enable, bool CurrentThread, out bool Enabled);

        public static bool EnableProfilePrivilege()
        {
            bool prev;
            int status = RtlAdjustPrivilege(19 /* SeProfileSingleProcessPrivilege */, true, false, out prev);
            return (status == 0);
        }

        // SYSTEM_MEMORY_LIST_INFORMATION = 0x50 (80)
        public const int SystemMemoryListInformation = 0x50;

        // SYSTEM_MEMORY_LIST_COMMANDS (xac minh tu enum cong khai cua Windows):
        //   2 = MemoryEmptyWorkingSets
        //   3 = MemoryFlushModifiedList
        //   4 = MemoryPurgeLowPriorityStandbyList
        //   5 = MemoryPurgeStandbyList
        [DllImport("ntdll.dll")]
        public static extern int NtSetSystemInformation(int SystemInformationClass, ref int SystemInformation, int SystemInformationLength);

        public static int RunMemoryListCommand(int command)
        {
            int info = command;
            int len = sizeof(int);
            return NtSetSystemInformation(SystemMemoryListInformation, ref info, len);
        }

        // ---------------- Helper gom 1 tien trinh ----------------
        public static bool TrimWorkingSet(int pid)
        {
            IntPtr h = OpenProcess(PROCESS_SET_QUOTA | PROCESS_QUERY_LIMITED_INFORMATION, false, pid);
            if (h == IntPtr.Zero) { return false; }
            try { return EmptyWorkingSet(h); }
            finally { CloseHandle(h); }
        }

        public static int GetForegroundPid()
        {
            IntPtr h = GetForegroundWindow();
            if (h == IntPtr.Zero) { return 0; }
            uint pid;
            GetWindowThreadProcessId(h, out pid);
            return (int)pid;
        }
    }
}
'@ -Language CSharp
}

function Send-WCFileToRecycleBin {
    # Chuyen tep/thu muc vao THUNG RAC (du lieu nguoi dung KHONG bao gio xoa vinh vien - spec 2.5)
    param([Parameter(Mandatory)][string]$Path)
    try {
        Add-Type -AssemblyName Microsoft.VisualBasic -ErrorAction Stop
        if (Test-Path -LiteralPath $Path -PathType Container) {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory(
                $Path, [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)
        } else {
            [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(
                $Path, [Microsoft.VisualBasic.FileIO.UIOption]::OnlyErrorDialogs,
                [Microsoft.VisualBasic.FileIO.RecycleOption]::SendToRecycleBin)
        }
        return $true
    } catch {
        Write-WCLog 'WARN' ('Recycle bin that bai cho: ' + $Path + ' -> ' + $_.Exception.Message)
        return $false
    }
}

function Get-WCNotificationStateText {
    # Giai thi nghia trang thai thong bao (dung de canh bao game/fullscreen - spec M1)
    Add-WCNativeType
    try {
        $state = 0
        $hr = [WinCare.Native]::SHQueryUserNotificationState([ref]$state)
        if ($hr -ne 0) { return $null }
        switch ($state) {
            2 { return 'busy' }        # QUNS_BUSY - ung dung full man hinh
            3 { return 'fullscreen' }  # QUNS_RUNNING_D3D_FULL_SCREEN - game
            4 { return 'presentation' }# QUNS_PRESENTATION_MODE
            default { return 'normal' }
        }
    } catch { return $null }
}
