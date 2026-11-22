# WINCARE MODULE CONTRACT (bắt buộc đọc trước khi viết module)

Bạn là một module-owner trong dự án WinCare. File bạn viết là `src/1X-M?.ps1` và sẽ
được ghép vào MỘT file `dist/WinCare.ps1` (spec mục 2.7). Vi phạm hợp đồng = code bị loại.

## 1. Quy tắc PowerShell 5.1 (CẤM tuyệt đối)
- KHÔNG dùng: `??`, ternary `? :`, `&&`, `||`, `-Parallel`, alias (vd `gci`, `?`, `%`).
- KHÔNG dùng `param()` ở top-level file (chỉ trong hàm).
- KHÔNG dùng `exit` ở bất kỳ đâu.
- KHÔNG dùng `Get-WmiObject` → dùng `Get-CimInstance`.
- KHÔNG dùng `Win32_Product`, `-EncodedCommand`, `Add-MpPreference`.
- KHÔNG parse output CLI bị địa phương hóa (netsh, sfc, dism, powercfg text).
  Ưu tiên CIM/.NET/registry/Event ID/exit code/cmdlet trả object.
- KHÔNG hard-code `C:\Users\...` → dùng `[Environment]::GetFolderPath` / biến môi trường.
- Đặt tên hàm: `Verb-WC*` (approved verbs: Get, New, Add, Invoke, Test, Show, Register...).
- Mọi truy cập thuộc tính object ngoài (CIM/registry/PSCustomObject từ JSON) phải qua
  `Get-WCProp $obj 'TênThuộcTính'` — KHÔNG truy cập trực tiếp `$obj.X` (StrictMode sẽ văng).
- Try/catch mọi truy vấn; lỗi một nguồn không được làm sập module.
- File UTF-8 không BOM. Comment tiếng Việt không dấu. Chuỗi UI tiếng Việt CÓ dấu.

## 2. API khung lõi sẵn có (đọc src/00→09 để biết chi tiết)
- `T 'key' [-Fmt array]` → chuỗi i18n. `Register-WCStrings 'vi' @{...}` + `'en' @{...}`
  đăng ký chuỗi của module bạn (key prefix `m4.`, `m5.`...).
- `Invoke-WCQuery -Key 'unique.key' -Script { ... } [-CacheTtlSec n] [-NoCache]`
  → trả `New-WCResult` (`.Status` Ok/Warn/Bad/Unknown, `.Reason`, `.Data`).
  FIXTURE mode tự động áp dụng khi key trùng file JSON fixture.
- `New-WCResult -Status Ok|Warn|Bad|Unknown [-Reason s] [-Data d]`
- `Get-WCProp $obj 'Prop'` — đọc thuộc tính an toàn (null nếu thiếu).
- `Get-WCRegistryValue -Path 'HKLM:\...' -Name 'X'` — đọc registry an toàn.
- `Start-WCTask -Id 'm?.xxx' -Title ... -Args $hashtable -Worker { param($ctx, $s) ... }`
  `-Done { param($result) ... }.GetNewClosure()` — chạy nền có Hủy/tiến độ.
  * Worker chạy trong runspace riêng: KHÔNG thấy biến local của hàm gọi — mọi dữ
    liệu truyền qua `-Args`, trong worker đọc `$s.Mode` v.v.
  * Trong worker: `$ctx.Progress(0-100,'chữ')`, `$ctx.Log('...')`, `$ctx.Cancelled()`
    (bấm Hủy → trả true → dọn dẹp và return sớm).
  * Worker gọi được MỌI hàm Get-*/helper của WinCare (đã nap qua InitialSessionState).
  * `-Done` chạy lại trên UI thread; nếu tham chiếu biến local của hàm gọi thì
    PHẢI kết thúc bằng `.GetNewClosure()`.
  * Cùng Id đang chạy → Start-WCTask trả $false (không chạy chồng).
  * Quy ước kết quả: worker trả ĐÚNG 1 object → Done nhận object đó; nhiều object
    → Done nhận mảng.
- `Add-WCJournalEntry -Module 'M4' -Action '...' -Target '...' -OldValue '...'`
  `-UndoType '' -UndoArgs $null [-AutoRestore]` + `Complete-WCJournalEntry -Entry $e`.
  Mọi thay đổi hệ thống PHẢI ghi journal trước khi làm (spec 2.4).
- `Remove-WCItem -Path $p [-Recycle]` — HÀM XÓA DUY NHẤT, đã qua `Assert-SafePath`.
  KHÔNG BAO GIỜ gọi `Remove-Item` trực tiếp trong module.
- `Test-WCDryRunMode` — nếu true: chỉ hiện "sẽ làm", không làm (spec 2.4).
- `Test-WCExpertMode`, `Test-WCMaskMode` (che dữ liệu nhạy cảm khi xuất).
- `ConvertTo-WCHumanSize [long]bytes` → "1,2 GB".
- `ConvertTo-WCSafeString $rawBytes` → chuỗi sạch từ byte WMI.
- `Get-WCIsAdmin`, `Get-WCDataRoot`, `Get-WCLogPath`, `Write-WCLog 'LEVEL' 'text'`.

## 3. API UI (src/09-UICore.ps1) — module CHỈ dựng UI qua các helper này
- `New-WCVStack -Spacing n` / `New-WCHStack -Spacing n` / `Add-WCChild $panel $control`
- `New-WCSection -Title s [-Subtitle s] [-Badge s]` → `@{ Root; Body }` (card Win11)
- `New-WCHeading`, `New-WCSubtitle`, `New-WCTextBlock -Text -Size -ColorKey -Wrap`
- `New-WCButton -Text -OnClick { param($btn) ... } [-Kind Primary|Danger] [-Small]`
- `New-WCChip -Text -Kind Ok|Warn|Bad|Unknown|Accent|Plain`, `New-WCStatusChip -Status`
- `New-WCProgressBar`, `New-WCSpinner`, `New-WCSkeleton` (4 trạng thái UI - spec muc 3)
- `New-WCTable -Columns @(@{Header='Cột';Prop='Tên';Width=200},...)` + `$table.Items.Add($obj)`
- `New-WCCheckList` + `Add-WCCheckRow -List -Item -TextColumns @('a','b') [-ChipText x -ChipKind Warn] [-Checked:$false]`
  + `Get-WCCheckRowSelection $list` + `Clear-WCCheckList $list`
- `New-WCExpander -Title -Summary` → `@{ Root; Body }` (M4 dùng nhiều)
- `New-WCFieldRow -Label -Value [-NoCopy] [-Mono]` → grid, `.Tag` = TextBlock giá trị
- `New-WCSearchBox -OnChanged { param($box) ... }`
- `New-WCExpertLine -Command 'lenh se chay'` (chỉ hiện ở chế độ chuyên gia)
- `Show-WCToast 'text' 'Ok|Warn|Bad|Info'`, `Show-WCConfirm -Title -Message`
  `[-Undoable s] [-NotUndoable s] [-Danger]` (RỦI RO tự xác nhận 2 bước),
  `Show-WCError -Friendly -Details`, `Show-WCInfo -Title -Message`
- `Set-WCStatus 'text'`
- Đăng ký nav (BẮT BUỘC cuối file, trong `Initialize-WCModuleM?`):
  ```
  Register-WCNavItem -Key 'm4' -Badge 'M4' -Title (T 'm4.title') -Order 50 -Builder {
      New-WCM4Panel $state
  }.GetNewClosure() -OnShow { ... }.GetNewClosure() -OnHide { ... }.GetNewClosure()
  ```
  Builder xây panel LAZY (gọi 1 lần, cache). OnShow/OnHide: bật/tắt timer, tải dữ liệu.
- Panel root = `ScrollViewer` chứa `New-WCVStack` margin 20 (xem M1).

## 4. Mẫu giao diện MỌI tác vụ (spec muc 3)
QUÉT (chỉ đọc) → XEM LẠI (danh sách tick + rủi ro) → XÁC NHẬN (tóm tắt đúng thứ sẽ
đổi + hoàn tác được gì/không được gì) → CHẠY (tiến độ thật + Hủy) → KẾT QUẢ (trước/sau).
- 4 trạng thái bắt buộc: đang tải (New-WCSpinner/skeleton), rỗng ("Không có gì cần
  làm" thân thiện), lỗi (Show-WCError), thành công.
- Dữ liệu về dần: hiện cái có trước, phần chậm có spinner riêng.
- Mức rủi ro luôn kèm CHỮ: `Get-WCRiskInfo 'Recommended|Advanced|Risky'` → `.Text`, `.Hint`, `.Brush`.
- Chỉ mục KHUYẾN NGHỊ được tick sẵn; NÂNG CAO/RỦI RO KHÔNG BAO GIỜ tick sẵn.
- KHÔNG hứa suông ("tăng X% tốc độ"), chỉ hiện số đo thật. Không dọa người dùng.

## 5. Yêu cầu riêng từng module (từ spec gốc — đọc file upload nếu cần)
Xem prompt giao việc của bạn. File spec gốc: `/home/z/my-project/upload/Pasted Content_1795278201019.txt`.

## 6. Kiểm chứng
- Sau khi viết xong, chạy: `/home/z/tools/pwsh/pwsh -NoProfile -File /home/z/my-project/wincare/parse-check.ps1`
  (chỉ được báo OK). KHÔNG chạy thử app (không có Windows).
- Báo cáo lại: ĐÃ LÀM / GIẢ ĐỊNH / CHƯA KIỂM CHỨNG (trung thực — spec mục 1.6).
