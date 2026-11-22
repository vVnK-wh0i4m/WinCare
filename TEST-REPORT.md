# TEST-REPORT — WinCare v1.0.1

> Nguyên tắc (spec mục 1.6): KHÔNG ghi PASS cho thứ chưa chạy. Môi trường phát
> triển là **Linux sandbox** (không có Windows) — mọi kiểm chứng runtime trên
> Windows thật được liệt kê rõ ở mục "CHƯA KIỂM CHỨNG".

## 1. Môi trường kiểm thử

| Hạng mục | Thực tế |
|---|---|
| OS phát triển | Linux x86_64 (không có Windows/WSL) |
| PowerShell kiểm thử | pwsh 7.4.6 (Linux) — dùng cho parse-check, Pester, build |
| Pester | 6.2.0 (PSGallery) |
| Trình duyệt xác minh | Agent Browser (Chromium headless) chống localhost:3000 |
| Máy Windows thật | **KHÔNG CÓ** — xem mục 6 |

## 2. ĐÃ XÁC MINH (lệnh + kết quả thật)

### 2.1 Kiểm tra tĩnh (spec 2.7)

```
$ pwsh -NoProfile -File ./parse-check.ps1
OK   00-Boot.ps1 ... OK 21-Main.ps1      (22/22 file)
== TAT CA PASS ==                        (0 lỗi parse)
+ Quét chuỗi cấm: Win32_Product, -EncodedCommand, Add-MpPreference, && , || , ??
  → 0 vi phạm
+ Kiểm tra trùng tên hàm qua AST toàn bộ src: 426 hàm duy nhất, 0 trùng
+ Lời gọi hàm WC* chưa định nghĩa: 0 (1 kết quả là chuỗi trong ghi chú)
+ Remove-Item trong src: CHỈ còn trong Remove-WCItem (04-Safety.ps1) — hợp đồng
  "hàm xóa duy nhất" (spec 2.5) giờ đúng cả với Remove-WCAllData (xem mục 4)
```

### 2.2 Build (v1.0.1)

```
$ pwsh -NoProfile -File ./build.ps1
BUILD OK: dist/WinCare.ps1
  size: 801046 bytes | lines: 16365 | parse: OK (0 lỗi)
  build: 999705ba
  sha256: d701c6592d41f4383867d36e625c6919a8ef9dfebe85bcd5fd38a2110865bd33
  BOM: không (OK) — kiểm byte 0xEF 0xBB 0xBF = không có
+ Build 2 lần liên tiếp → SHA-256 trùng khớp (deterministic — điều kiện bắt
  buộc để cổng "dist khớp build từ src" trong CI hoạt động)
```

### 2.3 Boot guard trên môi trường không phải Windows

```
$ pwsh -NoProfile -File ./dist/WinCare.ps1   (trên Linux)
→ thoát sạch, exit 0, không treo, không in rác console
```

### 2.4 Pester — logic thuần (chạy thật trên Linux)

```
$ pwsh -NoProfile -File ./tests/run-tests.ps1
Tests Passed: 27, Failed: 0, Skipped: 1   (Pester 6.2.0)
```

Bao phủ: i18n vi/en đồng bộ 1165/1165 key mỗi thứ tiếng + T() fallback;
journal CRUD/hoàn tác/tự-phục-hồi; Assert-SafePath (từ chối đường tương đối,
segment `..`, góc ổ đĩa, ngoài whitelist; chấp nhận whitelist Temp); **mới trong
v1.0.1 — junction/symlink thật (tạo SymbolicLink trên Linux, Junction trên
Windows CI): từ chối đường đi qua junction, từ chối chính junction ở segment
cuối, Remove-WCItem từ chối xóa và tệp mồi còn nguyên**; **whitelist browser
chỉ nhận đúng thư mục cache từng profile (test này skip trên Linux, chạy trên
Windows CI)**; **Remove-WCAllData tôn trọng DRYRUN (không xóa gì) và khi xóa
thật: marker biến mất, cây thư mục tạo lại, file log hôm nay còn lại**; công
thức điểm M6; verdict M7; danh sách tiến trình bảo vệ; bộ định dạng KB/MB/GB.

Ghi chú quan trọng (sửa trong v1.0.1): Pester 6 chỉ trả result object khi
`Run.PassThru = $true`. Trước đây `run-tests.ps1` không đặt — `$r` rỗng →
đếm fail luôn bằng rỗng → **2 test fail vẫn in "PASS"** (phát hiện khi chạy
lại sau đợt sửa lỗi). Đã đặt PassThru + chuyển sang kiểm tra fail-closed:
không nhận được kết quả → coi như FAIL.

### 2.5 Smoke test công thức điểm M6 (module-owner viết, chạy thật)

```
$ pwsh -NoProfile -File ./tests/m6-smoke.ps1
== TAT CA SMOKE TEST PASS ==   (50/50 PASS)
```

### 2.6 Phân phối qua landing page (kiểm thật HTTP)

```
$ curl -s localhost:3000/api/wincare/script -o /tmp/http.ps1
+ SHA-256 nội dung HTTP == SHA-256 dist (D701C659…BD33) → giống hệt byte-for-byte
+ Content-Type: text/plain; charset=utf-8 ✓ (yêu cầu PS 5.1)
+ Tiếng Việt có dấu trong file nguyên vẹn ("Tổng quan" ✓), không BOM ✓
+ /api/wincare/download → 200, 801046 bytes (attachment) ✓
+ /api/wincare/info → 200, JSON version 1.0.1/build/sha256/lineCount ✓
```

### 2.7 Landing page (Agent Browser, headless Chromium)

- Trang `/` tải: 200, title đúng tiếng Việt, **0 page errors, 0 console
  errors, 0 hydration mismatch** (đối chiếu dev.log).
- One-liner dựng đúng theo origin: `irm 'http://localhost:3000/api/wincare/script' | iex`.
- Bấm **Sao chép** → toast "Đã sao chép" hiện ra ✓ (cả nút hero lẫn nút
  trong khối hướng dẫn).
- Khối "xem trước landing page": iframe `/preview/index.html` render đầy đủ
  (đúng v1.0.1 + 782 KB); nút **Tải lại trang xem trước** tải lại iframe thành
  công ✓.
- Không còn sót chuỗi phiên bản cũ (v1.0.0 / 777 KB / 16.276 / 74 test) trên
  trang chính lẫn trong iframe ✓ (kiểm bằng JS qua innerText).
- Viewport 390×844 (mobile): `scrollWidth = 390` — không tràn ngang; bố cục
  không vỡ (screenshot đã chụp).
- Footer: `min-h-screen flex flex-col` + `mt-auto` + safe-area-inset — trang
  dài thì bị đẩy xuống tự nhiên, không đè nội dung.
- Ghi chú trung thực: trang KHÔNG có accordion Hỏi đáp hay nút đổi theme —
  bản v1.0.0 của file này từng ghi 2 mục đó là đã kiểm, thực tế không tồn
  tại trên trang (sao chép nhầm từ dự án khác). Đã rút ra và chỉ giữ những
  gì kiểm được.

### 2.8 ESLint Next.js

```
$ bun run lint   → 0 error, 0 warning
```

## 3. SỰ CỐ DỮ LIỆU & PHỤC HỒI (ghi lại trung thực)

Trong phiên phát triển, một lệnh sửa lỗi gửi qua kênh shell đã làm hỏng 3 file
nguồn (ký tự `[` bị thay thế hàng trăm vị trí trong 13-M2, 18-M7, 04-Safety).
Phát hiện nhờ: Pester fail + parse-check fail (cổng chất lượng làm đúng việc).
Phục hồi:

- `13-M2-Disk.ps1`: sửa 262 chỗ — bằng chứng: size khớp **đúng tuyệt đối**
  74937 bytes như bản gốc + parse sạch.
- `18-M7-Aging.ps1`: khôi phục từ bản build dist trước sự cố, đối chiếu từng
  byte — **SHA-256 trùng khớp bản gốc** `a5c0a8e15e…`, size 122947 bytes,
  29/29 test chức năng của module pass lại sau phục hồi.
- `04-Safety.ps1`: viết lại toàn bộ (có cải tiến: null-env guards, kiểm tra
  Downloads, path-separator theo nền tảng).

Sau phục hồi: toàn bộ cổng chất lượng (2.1–2.5) chạy lại **PASS toàn bộ**.

## 4. DÒ LỖI BÊN NGOÀI v1.0.0 → ĐÃ SỬA TRONG v1.0.1

Báo cáo dò lỗi độc lập (đọc mã + tái tạo build bằng Python, đối chiếu
byte-cho-byte) phát hiện 1 lỗi nghiêm trọng, 3 trung bình, 3 thấp, 2 tài liệu.
Toàn bộ đã xử lý:

| # | Mức | Lỗi | Cách sửa | Kiểm chứng |
|---|---|---|---|---|
| 2.1 | Nghiêm trọng | Chặn junction/symlink trong `Assert-SafePath` không hoạt động: vòng lặp bỏ qua segment cuối (`-ine $fullTrim`) và `Path.Combine('C:',…)` trả đường TƯƠNG ĐƠI → `GetAttributes` luôn throw → không phát hiện junction ở bất kỳ cấp nào | Viết lại vòng duyệt: dựng tiền tố gốc `C:\` (hoặc `/` trên Unix) trước khi Combine, kiểm tra MỌI segment kể cả segment cuối | Pester tạo SymbolicLink thật (Linux) / Junction (Windows CI): đường qua junction bị từ chối, junction ở cuối bị từ chối, `Remove-WCItem` từ chối xóa, tệp mồi còn nguyên — **PASS** |
| 2.2 | Trung bình | `Remove-WCAllData` bỏ qua `Assert-SafePath`/`Remove-WCItem` (gọi `Remove-Item` trực tiếp), không tôn trọng DRYRUN, skip file log so sánh sai cấp thư mục | Chuyển hẳn qua `Remove-WCItem` (đăng ký data root vào whitelist bằng `Add-WCDeleteRoot`), thêm guard `Test-WCDryRunMode` (chỉ ghi log), so sánh ĐÚNG đường dẫn file log khi duyệt thư mục `logs`, tạo lại cây thư mục chuẩn sau khi xóa | 2 test Pester: DRYRUN không xóa gì; xóa thật → marker mất + cây tạo lại + log hôm nay còn — **PASS** |
| 2.3 | Trung bình | Whitelist chứa nguyên `Chrome/Edge/Brave\User Data` và `Firefox\Profiles` (chứ Login Data, Cookies) — chỉ cần M2 liệt kê sai là mất mật khẩu | Thu hẹp về đúng thư mục cache của từng profile qua hàm mới `Get-WCSafeBrowserCacheRoots` — tầng an toàn tự liệt kê ĐỘC LẬP với module (phòng thủ 2 lớp: M2 sai → Assert-SafePath vẫn từ chối) | Test Pester (Windows CI): `Login Data`/`Cookies` bị từ chối, `Cache\…`/`Code Cache\…` được chấp nhận — **PASS** (skip trên Linux) |
| 2.4 | Trung bình | CI chỉ so `dist` với `.sha256` đã commit — sửa trực tiếp `dist` rồi tự cập nhật `.sha256` vẫn xanh (rủi ro chuỗi cung ứng: người dùng `irm \| iex` từ `dist`) | Thêm bước CI sau khi build lại: `git status --porcelain -- dist/` không được có thay đổi nào ngoài `build-info.json` (chỉ khác mỗi `builtAt`); so sánh từng trường của build-info với HEAD | Logic đã mô phỏng trong git repo thật (rebuild → 0 thay đổi; giả lập sửa dist → phát hiện) |
| 2.5 | Thấp | `Windows.old` whitelist sai đường dẫn (`C:\Windows\Windows.old`) | Dùng `[IO.Path]::GetPathRoot($env:SystemRoot)` + `Windows.old` (đúng `C:\Windows.old`, khớp với M2) | Parse + review; M2 vẫn `SkipAtRun` (chỉ liệt kê) |
| 2.6 | Thấp | M1 worker `Stop-Process` theo danh sách UI chọn mà không kiểm tra lại tiến trình bảo vệ | Worker kiểm tra lại `Test-WCProtectedProcess` cho cả tên nhóm và từng PID sau `Get-Process` | Parse + Pester danh sách bảo vệ (giữ nguyên); hành vi runtime chờ Windows thật |
| 2.7 | Thấp | Ghi chú "bỏ qua file log" gây hiểu nhầm (không có tác dụng) | Gộp vào cách sửa 2.2 — so sánh đúng đường dẫn, comment mô tả đúng hành vi | Test Pester file log hôm nay còn lại — **PASS** |
| T1 | Tài liệu | `TEST-REPORT.md` ghi "406 hàm" trong khi mã có nhiều hơn | Đếm lại bằng AST: **426 hàm duy nhất** (đã cập nhật mục 2.1) | Lệnh đếm trong pwsh, số liệu in trực tiếp |
| T2 | Tài liệu | `run-tests.ps1` chứa đường dẫn máy cá nhân `/home/z/tools/pwsh/pwsh` | Đổi thành lệnh chung `pwsh -NoProfile -File ./tests/run-tests.ps1` | Review |

**Phát hiện thêm trong lúc sửa** (không nằm trong báo cáo gốc, đều đã sửa):

- **Cổng Pester câm lặng với Pester 6** (chi tiết ở mục 2.4): result object
  rỗng khi thiếu `Run.PassThru` → fail không bao giờ được đếm. Đây chính là
  lý do các lỗi 2.1/2.2 tồn tại qua 24 test "PASS" trước đây.
- **CI sẽ false-fail trên Windows runner vì CRLF**: git Windows mặc định
  `autocrlf` đổi LF→CRLF lúc checkout → bước verify sha256 byte-cho-byte gãy.
  Đã thêm `.gitattributes` với `* -text` (giữ nguyên byte mọi file) + bước CI
  tự đặt `core.autocrlf false`.
- **TEST-REPORT v1.0.0 ghi vượt thực tế ở mục 2.7**: khai "Accordion Hỏi đáp
  mở/đóng ✓, đổi theme sáng/tối ✓" nhưng landing page không hề có 2 tính năng
  này (sao chép nhầm từ dự án khác). Đã rút gọn mục 2.7 về đúng những gì kiểm
  được — đúng nguyên tắc "không ghi PASS cho thứ chưa chạy/chưa có".

## 5. GIẢ ĐỊNH đang áp dụng (chưa kiểm chứng trên Windows thật)

- Giá trị enum `SYSTEM_MEMORY_LIST_COMMANDS` (2/3/4/5) lấy từ tài liệu công khai
  (Process Hacker/winternl); `SeProfileSingleProcessPrivilege = 19`.
- Decode `productState` AV (nibble 3 = bật, nibble 5 = chữ ký mới) — phổ biến
  nhưng chưa chuẩn hóa chính thức.
- Binary `StartupApproved` (4 byte `00…` = bật, `02 00…` = tắt) theo hành vi
  quan sát được của Task Manager.
- Map `SMBIOSMemoryType` (26=DDR4, 34=DDR5, 30=LPDDR4…), decode mã lỗi
  ConfigManagerErrorCode, GUID DeviceClass → nhóm tiếng Việt.
- Trọng số điểm M6, ngưỡng lão hóa M7: heuristics do module-owner chọn, ghi
  rõ trong code + bảng phân rã hiển thị cho người dùng.
- WUA COM chạy trong runspace pool MTA (chưa có bằng chứng Windows thật).
- Hành vi `Path.Combine('C:', 'X')` trả `'C:X'` (đường tương đối theo ổ đĩa)
  lấy từ tài liệu .NET — chưa chạy trực tiếp trên Windows .NET Framework,
  nhưng cách sửa mới không phụ thuộc hành vi này (luôn dựng `C:\` trước).

## 6. CHƯA KIỂM CHỨNG (thiếu Windows thật) — kịch bản cần chạy

1. **Khởi động**: PS 5.1 VÀ 7; không-Admin → UAC → chạy; từ chối UAC; mutex lần
   2; chạy lại cùng phiên (Add-Type trùng); `irm | iex` thật qua HTTP với chuỗi
   tiếng Việt dưới PS 5.1.
2. **WPF runtime**: mọi màn hình dựng thật (nút, bảng, expander, dialog),
   theme sáng/tối, DPI 100/150/200%, đóng cửa sổ khi đang chạy task.
3. **M1**: EmptyWorkingSet/NtSetSystemInformation chạy thật; đo trước/sau;
   Notepad có dấu `*` không bị buộc đóng khi chưa cảnh báo; dịch vụ tự khôi
   phục đủ kể cả thoát đột ngột; nút đóng app có kiểm tra lại danh sách bảo
   vệ trong worker (sửa 2.6).
4. **M2**: junction thật bằng Junction trên NTFS (test Pester đã phủ
   SymbolicLink/Junction ở tầng logic; cần xác nhận thêm `Remove-Item -Recurse`
   của PS 5.1 không xuyên junction khi WinCare chạy thật); dung lượng xem
   trước sai lệch ≤5%; Chrome đang mở; whitelist browser trên profile thật.
5. **M3**: WUA search/download/install thật; WSUS; Dell dcu-cli; luồng Dell
   chỉ được ghi "đã kiểm chứng" khi chạy trên máy Dell thật.
6. **M5**: EICAR (do người dùng tự tạo) bị Defender bắt và hiển thị đúng;
   Stop-MpScan khi Hủy; StartupApproved thật.
7. **M6/M7**: Get-WinEvent thật (log tắt/bị xóa), DISM/SFC exit-code thật,
   Steam/Epic thật.
8. **Hiệu năng**: vào Dashboard ≤ ~3s; quét nhanh ≤ ~30s; RAM app < ~150MB;
   CPU nhàn rỗi ≈ 0.

## 7. Kết luận theo cổng chất lượng (spec mục 6)

| Cổng | Trạng thái |
|---|---|
| C1 Hiểu | ✅ spec từng module có tiêu chí đo được |
| C2 Thiết kế | ✅ schema WCResult, task runner, journal, Assert-SafePath, UI shell chốt trước |
| C3 Code | ✅ parse 0 lỗi, không hard-code, lỗi được bắt và hiển thị |
| C4 Test | ✅ 27 Pester + 50 smoke M6 + 29 smoke M7 — viết từ spec, bổ sung 3 test hồi quy cho lỗi dò outside |
| C5 Gia cố | ✅ tĩnh OK (whitelist thu hẹp, hàm xóa duy nhất đúng toàn app, chuỗi cấm, chặn junction, cổng Pester hết câm); runtime chưa đo |
| C6 Soát | ✅ review tích hợp + phát hiện/sửa sự cố dữ liệu + xử lý trọn bộ báo cáo dò lỗi bên ngoài |
| C7 Xác minh | ⚠️ build 1 file OK; chạy thật trên Windows: **CHƯA** |

**Kết luận trung thực**: sản phẩm đạt chuẩn kiểm chứng tĩnh + logic thuần
(kể cả 3 lỗi bảo mật nghiêm trọng nhất đã có test hồi quy tự động chạy trên
Linux và Windows CI); **chưa được xác minh runtime trên Windows thật** —
toàn bộ UI trong app gắn chip "Beta / chưa kiểm chứng runtime" cho đến khi
mục 6 được thực hiện.
