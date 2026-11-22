# WinCare — Trình tối ưu & kiểm tra Windows

> Một file PowerShell duy nhất (`dist/WinCare.ps1`). Người dùng mở PowerShell
> (Admin) và dán `irm <URL> | iex`. Script tự kiểm tra môi trường rồi mở app
> giao diện đồ họa WPF tiếng Việt: Dashboard + 7 module.

**Triết lý**: trung thực, không hứa suông. Quét là chỉ đọc; mọi thay đổi phải
qua xác nhận + ghi nhật ký + hoàn tác được khi khả thi. Không telemetry.

---

## 1. Chạy (one-liner)

Trang chủ (landing page Next.js đi kèm) phục vụ script tại
`/api/wincare/script` **kèm `Content-Type: text/plain; charset=utf-8`** — điều
bắt buộc để PowerShell 5.1 không vỡ dấu tiếng Việt khi `irm | iex`.

```powershell
# Chuẩn (host qua landing page):
irm 'https://<host-cua-ban>/api/wincare/script' | iex

# Nâng cao — đặt WINCARE_SELFURL để app tự relaunch đúng URL khi cần Admin:
$env:WINCARE_SELFURL='https://<host>/api/wincare/script'; irm 'https://<host>/api/wincare/script' | iex
```

**Tự host trên GitHub (khuyến nghị khi phát hành)**: trỏ vào **commit SHA bất
biến**, không trỏ nhánh main đang đổi:

```powershell
irm 'https://raw.githubusercontent.com/<USER>/<REPO>/<COMMIT_SHA>/WinCare.ps1' | iex
```

**Lệnh dự phòng UTF-8** (nếu server khác thiếu charset và tiếng Việt vỡ dấu
trên PS 5.1):

```powershell
& ([scriptblock]::Create([Text.Encoding]::UTF8.GetString((iwr -UseBasicParsing '<URL>').RawContentStream.ToArray())))
```

**Chạy từ file đã tải** (khuyến nghị PowerShell 7 — PS 5.1 đọc file UTF-8
không BOM sẽ vỡ dấu tiếng Việt trong chuỗi):

```powershell
pwsh -ExecutionPolicy Bypass -File .\WinCare.ps1
```

## 2. Biến môi trường (iex không nhận tham số)

| Biến | Ý nghĩa |
|---|---|
| `WINCARE_LANG` | `vi` (mặc định) / `en` — ngôn ngữ giao diện |
| `WINCARE_DEBUG` | `1` — ghi log chi tiết |
| `WINCARE_DRYRUN` | `1` — chỉ hiện điều SẼ làm, không thực hiện |
| `WINCARE_FIXTURE` | đường dẫn JSON dữ liệu giả để test UI/logic (xem `fixtures/`) |
| `WINCARE_SELFURL` | URL script — bắt buộc nếu muốn tự nâng quyền qua URL khác placeholder |

## 3. Yêu cầu hệ thống

- Windows 10 1809 (build 17763) trở lên hoặc Windows 11, **64-bit**
- Windows PowerShell 5.1 (chuẩn) hoặc PowerShell 7+ — cần WPF (PowerShell 6 không có WPF)
- Quyền Administrator (script tự xin UAC; từ chối → hướng dẫn thân thiện)
- Không có yêu cầu cài thêm bất cứ thứ gì

## 4. Mạng được phép truy cập

| Đích | Mục đích |
|---|---|
| Windows Update (qua dịch vụ WUA của Windows) | tìm + cài driver (M3) |
| Trang chính thức hãng phần cứng | **chỉ mở trình duyệt**, không scrape |
| URL script (`WINCARE_SELFURL`) | tự nâng quyền |
| **Không còn gì khác** | không telemetry, không analytics |

## 5. Cách hoàn tác / xóa dấu vết

- Mọi thay đổi ghi tại `%ProgramData%\WinCare\journal.json` — màn **Lịch sử &
  Hoàn tác** có nút hoàn tác từng mục (dịch vụ tạm dừng, mục khởi động đã tắt,
  ngủ đông…). Dịch vụ tạm dừng **tự khôi phục** khi thoát app, kể cả thoát
  đột ngột (lần mở sau phát hiện từ journal).
- Log: `%ProgramData%\WinCare\logs\`; sao lưu driver: `backups\`; báo cáo: `reports\`.
- Nút **"Xóa dữ liệu WinCare"** (Lịch sử) xóa toàn bộ thư mục trên.

## 6. Phát triển & đóng gói

```
wincare/
  src/*.ps1          22 file nguồn (00-Boot → 21-Main), mỗi file một chủ sở hữu
  build.ps1          ghép 1 file dist/WinCare.ps1 (UTF-8 KHÔNG BOM, build hash)
  parse-check.ps1    parse toàn bộ + quét chuỗi cấm (Win32_Product, -EncodedCommand, Add-MpPreference, &&/||/??)
  fixtures/          dữ liệu giả (3 GPU, không pin, HDD+SSD) cho WINCARE_FIXTURE
  tests/             Pester (24 test logic thuần) + smoke M6 (50 test) + run-tests.ps1
  dist/              WinCare.ps1 + .sha256 + build-info.json
  CONTRACT.md        hợp đồng API cho module-owner
```

```powershell
# Kiểm tra tĩnh (parse + chuỗi cấm):
./parse-check.ps1
# Build:
./build.ps1
# Toàn bộ test:
./tests/run-tests.ps1
```

Kiến trúc chính (spec mục 2): TaskRunner runspace-nền (worker nhận dữ liệu qua
`-Args`, KHÔNG truyền scriptblock qua ranh giới runspace — biến dịch lại từ
text), journal + undo handlers, `Assert-SafePath` + `Remove-WCItem` là hàm xóa
duy nhất, i18n vi/en, FIXTURE mode, theme sáng/tối.

## 7. Giới hạn đã biết (trung thực)

- Toàn bộ runtime trên Windows thật **chưa kiểm chứng** (môi trường phát triển
  là Linux) — xem `TEST-REPORT.md`. Mọi module hiển thị chip
  "Beta / chưa kiểm chứng runtime".
- Per-monitor DPI: WPF mặc định System-DPI-aware (không manifest được trong
  script) — có thể mờ khi kéo qua màn hình DPI khác nhau.
- Windows.old chỉ liệt kê + hướng dẫn Storage Sense (chưa hỗ trợ xóa tự động).
- Nhiệt độ CPU: Windows không có API chung đáng tin — hiển thị thông điệp trung
  thực thay vì đoán.
