# TEST-REPORT — WinCare v1.0.0

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
| Máy Windows thật | **KHÔNG CÓ** — xem mục 5 |

## 2. ĐÃ XÁC MINH (lệnh + kết quả thật)

### 2.1 Kiểm tra tĩnh (spec 2.7)

```
$ pwsh -NoProfile -File ./parse-check.ps1
OK   00-Boot.ps1 ... OK 21-Main.ps1      (22/22 file)
== TAT CA PASS ==                        (0 lỗi parse)
+ Quét chuỗi cấm: Win32_Product, -EncodedCommand, Add-MpPreference, && , || , ??
  → 0 vi phạm
+ Kiểm tra trùng tên hàm qua AST toàn bộ src: 406 hàm duy nhất, 0 trùng
```

### 2.2 Build

```
$ pwsh -NoProfile -File ./build.ps1
BUILD OK: dist/WinCare.ps1
  size: 796251 bytes | lines: 16276 | parse: OK (0 lỗi)
  build: ad25efbc
  sha256: f96f811ba86dc55e15580e76fb01ff52738ff1b668839034c8eec03d826c313a
  BOM: không (OK) — kiểm byte 0xEF 0xBB 0xBF = không có
```

### 2.3 Boot guard trên môi trường không phải Windows

```
$ pwsh -NoProfile -File ./dist/WinCare.ps1   (trên Linux)
→ thoát sạch, exit 0, không treo, không in rác console
+ gọi trực tiếp Test-WCPlatform → Status=Bad,
  Reason="WinCare chỉ chạy trên Windows 10/11. Phát hiện hệ điều hành khác." ✓
```

### 2.4 Pester — logic thuần (chạy thật trên Linux)

```
$ pwsh -NoProfile -File ./tests/run-tests.ps1
Tests Passed: 24, Failed: 0, Skipped: 0   (Pester 6.2.0)
```

Bao phủ: i18n vi/en đồng bộ 1165/1165 key mỗi thứ tiếng + T() fallback;
journal CRUD/hoàn tác/tự-phục-hồi; Assert-SafePath (từ chối đường tương đối,
segment `..`, góc ổ đĩa, ngoài whitelist; chấp nhận whitelist Temp);
công thức điểm M6 (đầy đủ 100 điểm, bỏ nhóm khỏi mẫu số, trần 49 khi Severe,
điểm có trọng số, không nhóm → Score null); M7 verdict (máy mới không bị dọa,
≥4 dấu hiệu mới đề xuất cài lại, 1-2 dấu hiệu nhẹ không đề xuất); danh sách
tiến trình bảo vệ; bộ định dạng KB/MB/GB.

Ghi chú: Pester 6.2.0 có lỗi gói tham số với `Should -BeLessThanOrEqual` —
đã thay bằng `($x -le 49) | Should -Be $true` (tương đương logic).

### 2.5 Smoke test công thức điểm M6 (module-owner viết, chạy thật)

```
$ pwsh -NoProfile -File ./tests/m6-smoke.ps1
== TAT CA SMOKE TEST PASS ==   (50/50 PASS)
```

### 2.6 Phân phối script qua raw GitHub

Dự án **không có API/Next.js** — nguồn phát hành duy nhất là file tĩnh
`dist/WinCare.ps1` trên nhánh `main`:

```
irm 'https://raw.githubusercontent.com/vVnK-wh0i4m/WinCare/main/dist/WinCare.ps1' | iex
```

- `dist/WinCare.ps1`: 796251 bytes, UTF-8 **không BOM**, sha256
  `f96f811b…313a` khớp `dist/WinCare.ps1.sha256` (đã đối chiếu cục bộ).
- `Content-Type` do `raw.githubusercontent.com` trả về và việc hiển thị tiếng
  Việt qua `irm | iex` dưới PS 5.1: **CHƯA KIỂM CHỨNG** (xem mục 5).

### 2.7 Landing page tĩnh (index.html)

- `index.html` là một file duy nhất, không dependency, không build frontend;
  workflow `.github/workflows/pages.yml` sao chép nguyên file lên GitHub Pages.
- Nút **Sao chép** dùng `navigator.clipboard.writeText` và có fallback
  `document.execCommand('copy')`; lệnh trong trang trỏ đúng raw URL ở mục 2.6.
- Kiểm thử trình duyệt thật trên URL GitHub Pages: **CHƯA KIỂM CHỨNG** trong
  phiên này.

### 2.8 Kiểm tra cú pháp HTML/JS

```
$ (không có ESLint/Next.js trong repo)
```

Landing page không có bước lint/build riêng; chỉ cần mở `index.html` là chạy.

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

## 4. GIẢ ĐỊNH đang áp dụng (chưa kiểm chứng trên Windows thật)

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

## 5. CHƯA KIỂM CHỨNG (thiếu Windows thật) — kịch bản cần chạy

1. **Khởi động**: PS 5.1 VÀ 7; không-Admin → UAC → chạy; từ chối UAC; mutex lần
   2; chạy lại cùng phiên (Add-Type trùng); `irm | iex` thật qua HTTP với chuỗi
   tiếng Việt dưới PS 5.1.
2. **WPF runtime**: mọi màn hình dựng thật (nút, bảng, expander, dialog),
   theme sáng/tối, DPI 100/150/200%, đóng cửa sổ khi đang chạy task.
3. **M1**: EmptyWorkingSet/NtSetSystemInformation chạy thật; đo trước/sau;
   Notepad có dấu `*` không bị buộc đóng khi chưa cảnh báo; dịch vụ tự khôi
   phục đủ kể cả thoát đột ngột.
4. **M2**: bẫy junction (tạo junction trong Temp trỏ thư mục mồi → tệp mồi
   còn nguyên sau dọn); dung lượng xem trước sai lệch ≤5%; Chrome đang mở.
5. **M3**: WUA search/download/install thật; WSUS; Dell dcu-cli; luồng Dell
   chỉ được ghi "đã kiểm chứng" khi chạy trên máy Dell thật.
6. **M5**: EICAR (do người dùng tự tạo) bị Defender bắt và hiển thị đúng;
   Stop-MpScan khi Hủy; StartupApproved thật.
7. **M6/M7**: Get-WinEvent thật (log tắt/bị xóa), DISM/SFC exit-code thật,
   Steam/Epic thật.
8. **Hiệu năng**: vào Dashboard ≤ ~3s; quét nhanh ≤ ~30s; RAM app < ~150MB;
   CPU nhàn rỗi ≈ 0.

## 6. Kết luận theo cổng chất lượng (spec mục 6)

| Cổng | Trạng thái |
|---|---|
| C1 Hiểu | ✅ spec từng module có tiêu chí đo được |
| C2 Thiết kế | ✅ schema WCResult, task runner, journal, Assert-SafePath, UI shell chốt trước |
| C3 Code | ✅ parse 0 lỗi, không hard-code, lỗi được bắt và hiển thị |
| C4 Test | ✅ 24 Pester + 50 smoke + 29 smoke M7 (sau phục hồi) — viết từ spec |
| C5 Gia cố | ⚠️ tĩnh OK (whitelist, hàm xóa duy nhất, chuỗi cấm); runtime chưa đo |
| C6 Soát | ✅ review tích hợp + phát hiện/sửa sự cố dữ liệu bằng cổng chất lượng |
| C7 Xác minh | ⚠️ build 1 file OK; chạy thật trên Windows: **CHƯA** |

**Kết luận trung thực**: sản phẩm đạt chuẩn kiểm chứng tĩnh + logic thuần;
**chưa được xác minh runtime trên Windows thật** — toàn bộ UI trong app gắn
chip "Beta / chưa kiểm chứng runtime" cho đến khi mục 5 được thực hiện.
