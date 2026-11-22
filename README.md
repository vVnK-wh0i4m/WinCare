# WinCare — Trình tối ưu & kiểm tra Windows trung thực

> **Một file PowerShell duy nhất** (`dist/WinCare.ps1`). Người dùng mở PowerShell
> (Admin) và dán `irm <URL> | iex`. Script tự kiểm tra môi trường rồi mở app
> giao diện đồ họa WPF tiếng Việt: Dashboard + 7 module.

![PowerShell](https://img.shields.io/badge/PowerShell-5.1%20%7C%207%2B-5391FE?style=flat-square&logo=powershell&logoColor=white)
![Platform](https://img.shields.io/badge/Windows-10%20%2F%2011-0078D4?style=flat-square&logo=windows)
![License](https://img.shields.io/badge/License-MIT-059669?style=flat-square)
![Tests](https://img.shields.io/badge/Tests-24%20Pester%20%2B%2050%20smoke-brightgreen?style=flat-square)
![No telemetry](https://img.shields.io/badge/Telemetry-KHÔNG-059669?style=flat-square)

**Triết lý**: trung thực, không hứa suông. Quét là chỉ đọc; mọi thay đổi phải
qua xác nhận + ghi nhật ký + hoàn tác được khi khả thi. Không telemetry.

---

## 1. Cài đặt & chạy (one-liner `irm | iex`)

Repo công khai: **https://github.com/vVnK-wh0i4m/WinCare** — mở
**PowerShell (Admin)** và dán:

```powershell
irm 'https://raw.githubusercontent.com/vVnK-wh0i4m/WinCare/main/dist/WinCare.ps1' | iex
```

> Repo đang ở chế độ **Public** nên `raw.githubusercontent.com` phục vụ không cần token.

**Ổn định hơn — trỏ vào commit SHA bất biến** (khuyến nghị khi phát hành, không
bị ảnh hưởng khi main thay đổi):

```powershell
irm 'https://raw.githubusercontent.com/vVnK-wh0i4m/WinCare/<COMMIT_SHA>/dist/WinCare.ps1' | iex
```

**Tự nâng quyền qua URL khác** (đặt biến trước khi chạy — app sẽ relaunch đúng
URL khi cần Admin):

```powershell
$env:WINCARE_SELFURL = 'https://raw.githubusercontent.com/vVnK-wh0i4m/WinCare/main/dist/WinCare.ps1'
irm $env:WINCARE_SELFURL | iex
```

**Lệnh dự phòng UTF-8** (nếu môi trường khác thiếu charset và tiếng Việt vỡ dấu
trên PS 5.1):

```powershell
& ([scriptblock]::Create([Text.Encoding]::UTF8.GetString((iwr -UseBasicParsing 'https://raw.githubusercontent.com/vVnK-wh0i4m/WinCare/main/dist/WinCare.ps1').RawContentStream.ToArray())))
```

**Chạy từ file đã tải** (khuyến nghị PowerShell 7 — PS 5.1 đọc file UTF-8
không BOM có thể vỡ dấu tiếng Việt trong chuỗi):

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
| `WINCARE_SELFURL` | URL script — bắt buộc nếu muốn tự nâng quyền qua URL hiện tại |

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

## 6. Landing page (GitHub Pages)

Repo kèm sẵn `index.html` — trang giới thiệu một file (không dependency) có
nút sao chép lệnh cài đặt. Workflow `.github/workflows/pages.yml` tự động
triển khai nó lên GitHub Pages:

1. Vào **Settings → Pages**
2. Mục **Build and deployment** → **Source: GitHub Actions**
3. Website sẽ chạy tại `https://vVnK-wh0i4m.github.io/WinCare/`

## 7. Cấu trúc repo

```
wincare/
├── index.html              # Landing page (GitHub Pages) — one file, không dependency
├── src/                    # 22 file nguồn (00-Boot → 21-Main), mỗi file một chủ sở hữu
├── build.ps1               # Ghép 1 file dist/WinCare.ps1 (UTF-8 KHÔNG BOM, build hash)
├── parse-check.ps1         # Parse toàn bộ + quét chuỗi cấm (Win32_Product, -EncodedCommand, Add-MpPreference, &&/||/??)
├── fixtures/               # Dữ liệu giả (3 GPU, không pin, HDD+SSD) cho WINCARE_FIXTURE
├── tests/                  # Pester (24 test logic thuần) + smoke M6 (50 test) + run-tests.ps1
├── dist/                   # WinCare.ps1 + .sha256 + build-info.json — file phát hành cho irm | iex
├── .github/workflows/
│   ├── ci.yml              # CI: kiểm tra sha256 dist + parse + build + Pester + smoke
│   └── pages.yml           # Deploy landing page lên GitHub Pages
├── CONTRACT.md             # Hợp đồng API cho module-owner
├── TEST-REPORT.md          # Báo cáo kiểm chứng trung thực
├── LICENSE                 # MIT
└── README.md
```

## 8. Phát triển

```powershell
# Kiểm tra tĩnh (parse + chuỗi cấm):
./parse-check.ps1

# Build lại dist:
./build.ps1

# Toàn bộ kiểm chứng (parse + build + Pester + smoke M6):
./tests/run-tests.ps1
```

CI (`.github/workflows/ci.yml`) chạy trên `windows-latest`:
1. Đối chiếu `sha256` của `dist/WinCare.ps1` với `dist/WinCare.ps1.sha256` đã commit
2. Parse-check toàn bộ `src/` + `dist/`
3. Build lại dist
4. Pester logic (24 test) + smoke M6 (50 test)

Kiến trúc chính (spec mục 2): TaskRunner runspace-nền (worker nhận dữ liệu qua
`-Args`, KHÔNG truyền scriptblock qua ranh giới runspace — biến dịch lại từ
text), journal + undo handlers, `Assert-SafePath` + `Remove-WCItem` là hàm xóa
duy nhất, i18n vi/en, FIXTURE mode, theme sáng/tối. Xem `CONTRACT.md` để viết
module mới.

## 9. Giới hạn đã biết (trung thực)

- Toàn bộ runtime trên Windows thật **chưa kiểm chứng** (phần lớn phát triển và
  kiểm thử tĩnh trên Linux sandbox; bản phát hành hiện tại được build lại trên
  Windows nhưng chưa chạy UI) — xem `TEST-REPORT.md`. Mọi module hiển thị chip
  "Beta / chưa kiểm chứng runtime".
- Per-monitor DPI: WPF mặc định System-DPI-aware (không manifest được trong
  script) — có thể mờ khi kéo qua màn hình DPI khác nhau.
- Windows.old chỉ liệt kê + hướng dẫn Storage Sense (chưa hỗ trợ xóa tự động).
- Nhiệt độ CPU: Windows không có API chung đáng tin — hiển thị thông điệp trung
  thực thay vì đoán.

## 10. Giấy phép

[MIT](LICENSE) — © 2026 WinCare contributors.
