# ============================================================================
#  src/18-M7-Aging.ps1 - Module M7: DO "LAO HOA" MAY (spec M7)
#  Muc tieu: tra loi "may nay co dang tich tu rac/cham dan khong?" bang
#  BANG CHUNG DO DUOC (so lieu + nguon), khong phan cam tinh.
#  May moi cai phai ra ket qua "binh thuong" ma KHONG doa nguoi dung.
#  Moi chi bao 1 section rieng, du lieu ve dan qua task nen tung phan.
# ============================================================================

Register-WCStrings 'vi' @{
    'm7.title' = 'Độ "lão hóa" máy'
    'm7.subtitle' = 'Máy có đang tích tụ rác / chậm dần không? — trả lời bằng bằng chứng đo được, không phán cảm tính'
    'm7.fact' = '"Windows dùng lâu là chậm" không phải quy luật. WinCare chỉ kết luận từ số liệu đo được và ghi rõ nguồn từng chỉ báo. Máy mới cài sẽ thấy kết quả "bình thường" — không dọa.'
    # -- Ket luan -------------------------------------------------------------
    'm7.verdict.title' = 'Kết luận: Độ lão hóa'
    'm7.verdict.subtitle' = 'Chỉ dựa trên số liệu đo được — bảng bằng chứng kèm theo từng chỉ báo'
    'm7.verdict.waiting' = 'Đang thu thập bằng chứng từ 7 nguồn…'
    'm7.verdict.fresh' = 'Mới / Như mới'
    'm7.verdict.good' = 'Được chăm sóc tốt'
    'm7.verdict.light' = 'Có tích tụ nhẹ'
    'm7.verdict.heavy' = 'Tích tụ nhiều'
    'm7.verdict.fresh.sum' = 'Windows được cài cách đây {0} và chưa có dấu hiệu tích tụ rõ ràng — đây là kết quả bình thường cho máy mới, không cần làm gì.'
    'm7.verdict.good.sum' = 'Máy đã dùng {0} nhưng chưa có dấu hiệu tích tụ rõ ràng — tuổi bản thân không làm Windows chậm, không cần lo.'
    'm7.verdict.light.sum' = 'Có dấu hiệu tích tụ nhẹ (xem bảng bằng chứng bên dưới). Nên bắt đầu từ hướng KHUYẾN NGHỊ ở cuối trang.'
    'm7.verdict.heavy.sum' = 'Phát hiện {0} dấu hiệu nặng và {1} dấu hiệu nhẹ cùng lúc — xem bảng bằng chứng để biết rõ từng mục đo được.'
    'm7.verdict.evidence' = 'Bảng bằng chứng'
    # -- Bang bang chung: cot + ten chi bao ----------------------------------
    'm7.col.indicator' = 'Chỉ báo'
    'm7.col.value' = 'Số liệu'
    'm7.col.source' = 'Nguồn'
    'm7.col.meaning' = 'Ý nghĩa'
    'm7.ev.age' = 'Tuổi cài đặt'
    'm7.ev.age.mean' = 'Chỉ là bối cảnh — trọng số rất nhỏ'
    'm7.ev.boot' = 'Xu hướng khởi động'
    'm7.ev.boot.up' = '+{0}% (trung vị 30 ngày so với 90 ngày)'
    'm7.ev.boot.down' = '{0}% (30 ngày nhanh hơn 90 ngày)'
    'm7.ev.boot.flat' = 'ổn định ({0}%)'
    'm7.ev.boot.mean.sign' = 'Khởi động chậm dần theo thời gian'
    'm7.ev.boot.mean.ok' = 'Thời gian khởi động không tăng'
    'm7.ev.startup' = 'Mục khởi động ngoài Microsoft'
    'm7.ev.startup.value' = '{0} mục ({1} đang bật)'
    'm7.ev.startup.mean.sign' = 'Nhiều chương trình đón lúc đăng nhập'
    'm7.ev.startup.mean.ok' = 'Mức bình thường'
    'm7.ev.bloat' = 'Ứng viên OEM/bloatware'
    'm7.ev.bloat.mean' = 'Phần mềm lắp sẵn ít dùng — gỡ qua trình gỡ chính thức'
    'm7.ev.residual' = 'Thư mục "CÓ THỂ là tàn dư"'
    'm7.ev.residual.value' = '{0} thư mục, {1}'
    'm7.ev.residual.mean' = 'Chiếm chỗ nhưng dễ báo nhầm — kiểm tra trước khi xóa'
    'm7.ev.games' = 'Game lâu không chơi (>180 ngày)'
    'm7.ev.games.value' = '{0} game, {1}'
    'm7.ev.games.mean' = 'Không phải "rác hệ thống" — chỉ là chỗ chiếm disk, gỡ qua launcher'
    'm7.ev.disk' = 'Ổ hệ thống còn trống'
    'm7.ev.disk.mean.low' = 'Không gian quá thấp ảnh hưởng trực tiếp hiệu năng'
    'm7.ev.disk.mean.ok' = 'Còn thoải mái'
    'm7.ev.pending' = 'Cờ chờ khởi động lại'
    'm7.ev.pending.mean' = 'Bản cập nhật chưa hoàn tất — nên khởi động lại'
    'm7.ev.bsod' = 'BSOD (90 ngày)'
    'm7.ev.bsod.mean' = 'Lỗi hệ thống lặp lại cần xem xét (xem M5)'
    'm7.src.registry' = 'Registry InstallDate'
    'm7.src.event100' = 'Sự kiện ID 100 (Diagnostics-Performance)'
    'm7.src.runkeys' = 'Run keys + Startup + Task Scheduler + services'
    'm7.src.uninstall' = 'Khóa Uninstall (HKLM 64/32 + HKCU)'
    'm7.src.folders' = 'Program Files / ProgramData / Local'
    'm7.src.manifest' = 'Steam/Epic manifest (thư mục cài)'
    'm7.src.logicaldisk' = 'Win32_LogicalDisk (ổ hệ thống)'
    'm7.src.rebootkeys' = 'CBS / WindowsUpdate / Session Manager'
    'm7.src.system1001' = 'Sự kiện System 1001 (BugCheck)'
    # -- Tuoi cai dat ---------------------------------------------------------
    'm7.age.title' = 'Tuổi cài đặt'
    'm7.age.hint' = 'Đọc từ registry — InstallDate là số giây Unix'
    'm7.age.value' = 'Windows được cài ngày {0} — cách đây {1}'
    'm7.age.unknown' = 'Không đọc được ngày cài đặt từ registry.'
    'm7.age.note' = 'Tuổi đơn thuần có trọng số RẤT NHỎ trong kết luận: Windows dùng lâu không tự nhiên chậm, chậm là do các yếu tố đo được bên dưới.'
    # -- Xu huong khoi dong ---------------------------------------------------
    'm7.boot.title' = 'Xu hướng thời gian khởi động'
    'm7.boot.hint' = 'Trung vị 30 ngày gần nhất so với 90/180 ngày — nguồn: sự kiện ID 100 (MainPathBootTime + BootPostBootTime)'
    'm7.boot.nodata' = 'Không đủ dữ liệu (log bị giới hạn/xóa, hoặc chưa đủ lần khởi động được đo).'
    'm7.boot.bucket.30' = '30 ngày gần nhất'
    'm7.boot.bucket.90' = '90 ngày gần nhất'
    'm7.boot.bucket.180' = '180 ngày gần nhất'
    'm7.boot.col.bucket' = 'Khoảng thời gian'
    'm7.boot.col.count' = 'Số lần khởi động'
    'm7.boot.col.median' = 'Trung vị (ms)'
    'm7.boot.col.max' = 'Chậm nhất (ms)'
    'm7.boot.count' = '{0} lần khởi động có đo được trong 180 ngày gần nhất.'
    'm7.boot.up' = '30 ngày gần nhất chậm hơn {0}% so với trung vị 90 ngày ({1} → {2} ms).'
    'm7.boot.down' = '30 ngày gần nhất NHANH hơn {0}% so với trung vị 90 ngày ({1} → {2} ms) — máy không chậm dần.'
    'm7.boot.flat' = 'Thời gian khởi động ổn định (thay đổi {0}% giữa trung vị 30 và 90 ngày).'
    'm7.boot.compare.nodata' = 'Chưa đủ lần khởi động để so sánh xu hướng (cần ≥ 3 lần trong 30 ngày và ≥ 5 lần trong 90 ngày).'
    'm7.boot.recent' = 'Lần khởi động gần đây (cũ → mới, chiều cao khối ~ thời gian khởi động):'
    'm7.boot.source' = 'Nguồn: sự kiện ID 100 — MainPathBootTime + BootPostBootTime (ms), đọc qua thuộc tính sự kiện (không parse thông điệp).'
    # -- Muc khoi dong --------------------------------------------------------
    'm7.startup.title' = 'Mục khởi động'
    'm7.startup.hint' = 'Gộp Run keys (HKLM/HKCU + WOW6432Node), thư mục Startup, tác vụ đăng nhập/khởi động, dịch vụ Auto — ngoài Microsoft'
    'm7.startup.count' = '{0} mục khởi động ngoài Microsoft ({1} đang bật).'
    'm7.startup.mscount' = '{0} mục thuộc Windows (tham khảo, thường để nguyên).'
    'm7.startup.empty' = 'Không có mục khởi động ngoài Microsoft — rất gọn.'
    'm7.startup.on' = 'BẬT'
    'm7.startup.off' = 'TẮT'
    'm7.startup.msbadge' = 'Windows'
    'm7.startup.toggle.off' = 'Tắt mục đã chọn'
    'm7.startup.toggle.on' = 'Bật lại mục đã chọn'
    'm7.startup.confirm.title' = 'Đổi trạng thái mục khởi động'
    'm7.startup.confirm.off' = 'Sẽ TẮT các mục khởi động sau (chỉ đổi trạng thái như Task Manager — KHÔNG xóa lệnh gốc, KHÔNG gỡ phần mềm):'
    'm7.startup.confirm.on' = 'Sẽ BẬT lại các mục khởi động sau:'
    'm7.startup.confirm.undo' = 'Bật lại được ngay bằng nút "Bật lại mục đã chọn" hoặc Hoàn tác trong Lịch sử.'
    'm7.startup.confirm.noundo' = 'Mục bị tắt sẽ không chạy khi đăng nhập cho đến khi bạn bật lại (phần mềm vẫn còn, không mất dữ liệu).'
    'm7.startup.journal.off' = 'Tắt mục khởi động'
    'm7.startup.journal.on' = 'Bật lại mục khởi động'
    'm7.startup.decode.note' = 'Trạng thái BẬT/TẮT giải mã từ giá trị StartupApproved (cơ chế Task Manager dùng) — cách giải mã phổ biến, chưa kiểm chứng trên mọi máy.'
    'm7.startup.tasks.title' = 'Tác vụ & dịch vụ tự chạy (ngoài Microsoft)'
    'm7.startup.tasks.summary' = '{0} tác vụ, {1} dịch vụ — chỉ liệt kê'
    'm7.startup.tasks.hint' = 'Tác vụ và dịch vụ không bật/tắt bằng cơ chế StartupApproved — quản lý bằng Task Scheduler / services.msc. WinCare chỉ báo cáo để bạn biết có gì đang đón cùng Windows.'
    'm7.startup.col.name' = 'Tên'
    'm7.startup.col.type' = 'Loại'
    'm7.startup.col.state' = 'Trạng thái'
    'm7.startup.type.task' = 'Tác vụ'
    'm7.startup.type.service' = 'Dịch vụ'
    'm7.startup.result' = 'Đã đổi {0} mục, {1} lỗi.'
    'm7.startup.more' = '… và {0} mục khác'
    # -- Phan mem -------------------------------------------------------------
    'm7.software.title' = 'Phần mềm đã cài'
    'm7.software.hint' = 'Đếm từ khóa Uninstall (HKLM 64/32-bit + HKCU) — không quét lớp WMI "sản phẩm" của Windows (vì nó kích hoạt MSI tự sửa)'
    'm7.software.count' = '{0} chương trình đang cài.'
    'm7.software.bloat.title' = 'Ứng viên OEM / bloatware (chỉ ĐỀ XUẤT — bạn tự quyết định)'
    'm7.software.bloat.hint' = 'Khớp tên với danh sách phần mềm lắp sẵn phổ biến. Nút "Gỡ" chỉ mở trình gỡ CHÍNH THỨC của phần mềm — không tự xóa.'
    'm7.software.bloat.empty' = 'Không phát hiện ứng viên bloatware phổ biến.'
    'm7.software.uninstall' = 'Gỡ'
    'm7.software.installedon' = 'Cài: {0}'
    'm7.software.uninstall.confirm.title' = 'Mở trình gỡ phần mềm?'
    'm7.software.uninstall.confirm.msg' = 'Sẽ mở trình gỡ chính thức của "{0}" và chạy lệnh:{1}{2}{3}Bạn sẽ tự xác nhận thêm trong trình gỡ của phần mềm.'
    'm7.software.uninstall.confirm.noundo' = 'Việc gỡ do trình gỡ của phần mềm thực hiện — WinCare không thể hoàn tác giúp bạn.'
    'm7.software.uninstall.running' = 'Đã mở trình gỡ của "{0}".'
    'm7.software.uninstall.fail' = 'Không mở được trình gỡ'
    'm7.software.uninstall.nostring' = 'Phần mềm này không có lệnh gỡ trong registry.'
    'm7.software.journal' = 'Mở trình gỡ chính thức'
    # -- Tan du ---------------------------------------------------------------
    'm7.residual.title' = 'Thư mục "CÓ THỂ là tàn dư"'
    'm7.residual.hint' = 'Thư mục trong Program Files / Program Files (x86) / ProgramData / Local\Programs không khớp phần mềm đang cài — nhãn "CÓ THỂ" vì rất dễ báo nhầm'
    'm7.residual.empty' = 'Không phát hiện thư mục mồ côi đáng chú ý.'
    'm7.residual.open' = 'Mở vị trí (mục đã chọn)'
    'm7.residual.delete' = 'Chuyển Thùng rác (mục đã chọn)'
    'm7.residual.delete.confirm.title' = 'Chuyển thư mục vào Thùng rác?'
    'm7.residual.delete.confirm.msg' = 'Các thư mục sau sẽ được chuyển vào THÙNG RÁC (không xóa vĩnh viễn):'
    'm7.residual.delete.confirm.noundo' = 'WinCare không tự hoàn tác việc này — khôi phục bằng cách kéo thư mục từ Thùng rác về chỗ cũ.'
    'm7.residual.journal' = 'Chuyển Thùng rác (tàn dư)'
    'm7.residual.orphan.title' = 'Mục Uninstall mồ côi trong registry (CHỈ báo cáo)'
    'm7.residual.orphan.hint' = 'Khóa Uninstall không có DisplayName — thường là dấu vết gỡ cài đặt. WinCare không tự xóa; chỉ giúp bạn biết có tồn tại.'
    'm7.residual.orphan.empty' = 'Không có mục Uninstall mồ côi.'
    'm7.residual.more' = '… và {0} thư mục khác'
    'm7.residual.result' = 'Đã chuyển {0} thư mục vào Thùng rác, {1} lỗi/bỏ qua.'
    # -- Game -----------------------------------------------------------------
    'm7.games.title' = 'Game & launcher'
    'm7.games.hint' = 'Steam (libraryfolders.vdf + appmanifest), Epic (Manifests .item), game khác qua khóa Uninstall'
    'm7.games.steam.none' = 'Không phát hiện Steam.'
    'm7.games.steam.ok' = 'Steam: {0} thư viện, {1} game.'
    'm7.games.epic.none' = 'Không phát hiện Epic Games Launcher.'
    'm7.games.epic.ok' = 'Epic Games Launcher: {0} game.'
    'm7.games.col.name' = 'Game'
    'm7.games.col.source' = 'Nguồn'
    'm7.games.col.size' = 'Dung lượng'
    'm7.games.col.last' = 'Chơi lần cuối'
    'm7.games.col.drive' = 'Ổ'
    'm7.games.source.other' = 'Khác (Uninstall)'
    'm7.games.last.unknown' = 'Chưa rõ'
    'm7.games.old.total' = '• {0} game lâu không chơi (>180 ngày) — tổng {1}. Gỡ/chuyển qua launcher để giải phóng chỗ.'
    'm7.games.hdd' = '• Game đặt trên ổ HDD (nên cân nhắc chuyển sang SSD để giảm thời gian load): {0}'
    'm7.games.launcher' = '• Launcher game tự chạy cùng Windows: {0} — xem mục Khởi động phía trên để tắt nếu không cần.'
    'm7.games.shader' = '• Bộ nhớ đệm shader: D3DSCache {0} + NVIDIA GLCache {1} — dọn ở M2 (Dọn ổ đĩa), sẽ tự dựng lại.'
    'm7.games.gpu.old' = '• Driver GPU "{0}" đã {1} ngày (> 1 năm) — xem M3 (Driver) để cập nhật.'
    'm7.games.gpu.ok' = '• Driver GPU "{0}" cập nhật cách đây {1} ngày — ổn.'
    'm7.games.open.steam' = 'Mở Steam'
    'm7.games.open.epic' = 'Mở Epic'
    'm7.games.open.fail' = 'Không mở được launcher.'
    'm7.games.uninstall.note' = 'Gỡ/chuyển game CHỈ qua Steam/Epic — không xóa tay thư mục game (dễ hỏng launcher).'
    'm7.games.empty' = 'Không phát hiện game qua Steam / Epic / khóa Uninstall.'
    'm7.games.more' = '… và {0} game khác'
    # -- Tich tu he thong -----------------------------------------------------
    'm7.sys.title' = 'Tích tụ hệ thống'
    'm7.sys.hint' = 'Cập nhật đang chờ, lần bảo trì tự động gần nhất, ổ hệ thống, BSOD gần đây'
    'm7.sys.pending.ok' = '• Không có cờ chờ khởi động lại — cập nhật đã hoàn tất.'
    'm7.sys.pending.list' = '• Cờ chờ khởi động lại: {0} — có bản cập nhật chưa hoàn tất, nên khởi động lại máy.'
    'm7.sys.maintenance.label' = '• Lần bảo trì tự động (Automatic Maintenance) gần nhất: {0} ({1}).'
    'm7.sys.maintenance.none' = '• Không đủ dữ liệu về lần bảo trì tự động gần nhất.'
    'm7.sys.disk' = '• Ổ hệ thống còn trống: {0}%'
    'm7.sys.bsod.none' = '• BSOD 90 ngày gần nhất: 0 lần.'
    'm7.sys.bsod.some' = '• BSOD 90 ngày gần nhất: {0} lần — xem chi tiết ở M5 (Ổn định & Toàn vẹn).'
    'm7.sys.bsod.nodata' = '• BSOD 90 ngày gần nhất: không đọc được nhật ký.'
    # -- Huong xu ly ----------------------------------------------------------
    'm7.actions.title' = 'Hướng xử lý (rủi ro tăng dần)'
    'm7.actions.hint' = 'Làm theo thứ tự — chỉ làm gì bạn hiểu và đã xác nhận'
    'm7.actions.waiting' = 'Sẽ hiện sau khi quét xong.'
    'm7.actions.1.title' = 'Dọn mục tiêu'
    'm7.actions.1.desc' = 'Chạy M2 (Dọn ổ đĩa) cho các mục cache/tạm an toàn, và tắt bớt mục khởi động không cần ở phần "Mục khởi động" phía trên.'
    'm7.actions.1.btn' = 'Mở M2 — Dọn ổ đĩa'
    'm7.actions.2.title' = 'Gỡ/tắt phần mềm, chuyển game'
    'm7.actions.2.desc' = 'Gỡ bloatware bằng trình gỡ chính thức (mục Phần mềm), chuyển game từ HDD sang SSD qua Steam/Epic (mục Game). Không xóa tay thư mục game.'
    'm7.actions.3.title' = 'Cài lại Windows / Reset this PC (giữ tệp)'
    'm7.actions.3.desc' = 'Chỉ cân nhắc khi các hướng trên không giải quyết được. Đây là quyết định của bạn — WinCare KHÔNG tự động hóa bước này.'
    'm7.actions.3.notneeded' = 'Chưa có cơ sở đề xuất cài lại Windows: cần ít nhất 3 dấu hiệu khách quan cùng lúc (hiện phát hiện {0}/{1}).'
    'm7.actions.3.criteria' = 'Các dấu hiệu khách quan đang thỏa:'
    'm7.actions.3.sign.boot' = '• Thời gian khởi động tăng hơn 50% (trung vị 30 ngày so với 90 ngày)'
    'm7.actions.3.sign.startup' = '• Hơn 15 mục khởi động ngoài Microsoft'
    'm7.actions.3.sign.disk' = '• Ổ hệ thống còn dưới 10% chỗ trống'
    'm7.actions.3.sign.bsod' = '• Từ 3 lần BSOD trong 90 ngày'
    'm7.actions.3.checklist.title' = 'Checklist sao lưu TRƯỚC khi cài lại:'
    'm7.actions.3.checklist.1' = '• Tài liệu, ảnh, video — kiểm tra cả Desktop, Downloads, thư mục ngoài ổ C'
    'm7.actions.3.checklist.2' = '• Dữ liệu trình duyệt: đăng nhập đồng bộ tài khoản, hoặc xuất bookmark/mật khẩu'
    'm7.actions.3.checklist.3' = '• Key/giấy phép phần mềm (Office, bản quyền…) — ghi lại để kích hoạt lại'
    'm7.actions.3.checklist.4' = '• Driver đã xuất ở M3 (dùng khi Windows thiếu driver sau cài)'
    'm7.actions.3.checklist.5' = '• Xác nhận Windows gắn với tài khoản Microsoft (để tự kích hoạt lại)'
    'm7.actions.3.checklist.6' = '• Danh sách phần mềm đang dùng — xem lại mục "Phần mềm đã cài" phía trên'
    'm7.actions.3.guide.title' = 'Hướng dẫn (bạn tự thao tác):'
    'm7.actions.3.guide.1' = '• Cách 1: Settings → System → Recovery → Reset this PC → "Keep my files" (giữ tệp cá nhân, cài lại Windows).'
    'm7.actions.3.guide.2' = '• Cách 2: tạo USB cài bằng Media Creation Tool từ microsoft.com rồi cài đè (sao lưu trước như checklist).'
    'm7.actions.3.note' = 'WinCare không thực hiện các bước này thay bạn — mọi thao tác cài lại thuộc về bạn.'
    'm7.nodata.reason' = 'Không đủ dữ liệu: {0}'
}
Register-WCStrings 'en' @{
    'm7.title' = 'PC "aging" check'
    'm7.subtitle' = 'Is this PC piling up junk / slowing down? — answered with measurable evidence, no guesswork'
    'm7.fact' = '"Old Windows is slow" is not a law. WinCare only concludes from measured data and names the source of every indicator. A fresh install will read "normal" — no scare tactics.'
    'm7.verdict.title' = 'Verdict: Aging level'
    'm7.verdict.subtitle' = 'Based only on measured data — evidence table attached per indicator'
    'm7.verdict.waiting' = 'Collecting evidence from 7 sources…'
    'm7.verdict.fresh' = 'New / Like new'
    'm7.verdict.good' = 'Well maintained'
    'm7.verdict.light' = 'Light buildup'
    'm7.verdict.heavy' = 'Heavy buildup'
    'm7.verdict.fresh.sum' = 'Windows was installed {0} ago with no clear buildup signs — a perfectly normal result for a new PC, nothing to do.'
    'm7.verdict.good.sum' = 'The PC has been used {0} but shows no clear buildup — age alone does not slow Windows down.'
    'm7.verdict.light.sum' = 'There are mild buildup signs (see evidence table below). Start with the RECOMMENDED direction at the bottom.'
    'm7.verdict.heavy.sum' = 'Found {0} severe and {1} mild signs at once — see the evidence table for each measured item.'
    'm7.verdict.evidence' = 'Evidence table'
    'm7.col.indicator' = 'Indicator'
    'm7.col.value' = 'Value'
    'm7.col.source' = 'Source'
    'm7.col.meaning' = 'Meaning'
    'm7.ev.age' = 'Install age'
    'm7.ev.age.mean' = 'Context only — very small weight'
    'm7.ev.boot' = 'Boot time trend'
    'm7.ev.boot.up' = '+{0}% (30-day median vs 90-day)'
    'm7.ev.boot.down' = '{0}% (30 days faster than 90 days)'
    'm7.ev.boot.flat' = 'stable ({0}%)'
    'm7.ev.boot.mean.sign' = 'Boot is getting slower over time'
    'm7.ev.boot.mean.ok' = 'Boot time is not increasing'
    'm7.ev.startup' = 'Non-Microsoft startup items'
    'm7.ev.startup.value' = '{0} items ({1} enabled)'
    'm7.ev.startup.mean.sign' = 'Many programs hook logon'
    'm7.ev.startup.mean.ok' = 'Normal level'
    'm7.ev.bloat' = 'OEM/bloatware candidates'
    'm7.ev.bloat.mean' = 'Preinstalled software rarely used — uninstall via its own uninstaller'
    'm7.ev.residual' = '"POSSIBLY leftover" folders'
    'm7.ev.residual.value' = '{0} folders, {1}'
    'm7.ev.residual.mean' = 'Wastes space but easy to misjudge — verify before deleting'
    'm7.ev.games' = 'Games not played >180 days'
    'm7.ev.games.value' = '{0} games, {1}'
    'm7.ev.games.mean' = 'Not "system junk" — just disk space; uninstall via launcher'
    'm7.ev.disk' = 'System drive free space'
    'm7.ev.disk.mean.low' = 'Very low space directly hurts performance'
    'm7.ev.disk.mean.ok' = 'Comfortable'
    'm7.ev.pending' = 'Pending reboot flags'
    'm7.ev.pending.mean' = 'Updates not finalized — consider restarting'
    'm7.ev.bsod' = 'BSODs (90 days)'
    'm7.ev.bsod.mean' = 'Repeated system crashes — see M5'
    'm7.src.registry' = 'Registry InstallDate'
    'm7.src.event100' = 'Event ID 100 (Diagnostics-Performance)'
    'm7.src.runkeys' = 'Run keys + Startup + Task Scheduler + services'
    'm7.src.uninstall' = 'Uninstall keys (HKLM 64/32 + HKCU)'
    'm7.src.folders' = 'Program Files / ProgramData / Local'
    'm7.src.manifest' = 'Steam/Epic manifests (install folders)'
    'm7.src.logicaldisk' = 'Win32_LogicalDisk (system drive)'
    'm7.src.rebootkeys' = 'CBS / WindowsUpdate / Session Manager'
    'm7.src.system1001' = 'System event 1001 (BugCheck)'
    'm7.age.title' = 'Install age'
    'm7.age.hint' = 'Read from registry — InstallDate is Unix seconds'
    'm7.age.value' = 'Windows was installed on {0} — {1} ago'
    'm7.age.unknown' = 'Could not read install date from registry.'
    'm7.age.note' = 'Age alone carries a VERY SMALL weight in the verdict: an old Windows is not automatically slow — slowness comes from the measurable factors below.'
    'm7.boot.title' = 'Boot time trend'
    'm7.boot.hint' = 'Median of last 30 days vs 90/180 days — source: event ID 100 (MainPathBootTime + BootPostBootTime)'
    'm7.boot.nodata' = 'Not enough data (log limited/cleared, or too few measured boots).'
    'm7.boot.bucket.30' = 'Last 30 days'
    'm7.boot.bucket.90' = 'Last 90 days'
    'm7.boot.bucket.180' = 'Last 180 days'
    'm7.boot.col.bucket' = 'Window'
    'm7.boot.col.count' = 'Boots'
    'm7.boot.col.median' = 'Median (ms)'
    'm7.boot.col.max' = 'Slowest (ms)'
    'm7.boot.count' = '{0} measured boots in the last 180 days.'
    'm7.boot.up' = 'Last 30 days are {0}% slower than the 90-day median ({1} → {2} ms).'
    'm7.boot.down' = 'Last 30 days are {0}% FASTER than the 90-day median ({1} → {2} ms) — the PC is not slowing down.'
    'm7.boot.flat' = 'Boot time is stable ({0}% change between 30-day and 90-day medians).'
    'm7.boot.compare.nodata' = 'Not enough boots to compare trend (need ≥ 3 in 30 days and ≥ 5 in 90 days).'
    'm7.boot.recent' = 'Recent boots (old → new, block height ~ boot time):'
    'm7.boot.source' = 'Source: event ID 100 — MainPathBootTime + BootPostBootTime (ms), read from event properties (no message parsing).'
    'm7.startup.title' = 'Startup items'
    'm7.startup.hint' = 'Run keys (HKLM/HKCU + WOW6432Node), Startup folders, logon/boot tasks, auto services — outside Microsoft'
    'm7.startup.count' = '{0} non-Microsoft startup items ({1} enabled).'
    'm7.startup.mscount' = '{0} Windows items (for reference, usually leave as is).'
    'm7.startup.empty' = 'No non-Microsoft startup items — very clean.'
    'm7.startup.on' = 'ON'
    'm7.startup.off' = 'OFF'
    'm7.startup.msbadge' = 'Windows'
    'm7.startup.toggle.off' = 'Disable selected'
    'm7.startup.toggle.on' = 'Re-enable selected'
    'm7.startup.confirm.title' = 'Change startup item state'
    'm7.startup.confirm.off' = 'The following startup items will be turned OFF (state change only, like Task Manager — the original command is NOT deleted, nothing is uninstalled):'
    'm7.startup.confirm.on' = 'The following startup items will be turned back ON:'
    'm7.startup.confirm.undo' = 'Reversible right away with "Re-enable selected" or Undo in History.'
    'm7.startup.confirm.noundo' = 'Disabled items will not run at logon until you re-enable them (software stays installed, no data loss).'
    'm7.startup.journal.off' = 'Disable startup item'
    'm7.startup.journal.on' = 'Re-enable startup item'
    'm7.startup.decode.note' = 'ON/OFF state is decoded from the StartupApproved value (the mechanism Task Manager uses) — a common decoding, not verified on every machine.'
    'm7.startup.tasks.title' = 'Startup tasks & services (outside Microsoft)'
    'm7.startup.tasks.summary' = '{0} tasks, {1} services — listed only'
    'm7.startup.tasks.hint' = 'Tasks and services are not toggled via StartupApproved — manage them in Task Scheduler / services.msc. WinCare only reports what hooks Windows startup.'
    'm7.startup.col.name' = 'Name'
    'm7.startup.col.type' = 'Type'
    'm7.startup.col.state' = 'State'
    'm7.startup.type.task' = 'Task'
    'm7.startup.type.service' = 'Service'
    'm7.startup.result' = 'Changed {0} items, {1} failed.'
    'm7.startup.more' = '… and {0} more'
    'm7.software.title' = 'Installed software'
    'm7.software.hint' = 'Counted from Uninstall keys (HKLM 64/32-bit + HKCU) — the WMI "product" class is never queried (it triggers MSI self-repair)'
    'm7.software.count' = '{0} programs installed.'
    'm7.software.bloat.title' = 'OEM / bloatware candidates (SUGGESTION only — your call)'
    'm7.software.bloat.hint' = 'Names matched against a list of common preinstalled software. "Uninstall" only opens the software own official uninstaller — nothing is deleted by WinCare.'
    'm7.software.bloat.empty' = 'No common bloatware candidates found.'
    'm7.software.uninstall' = 'Uninstall'
    'm7.software.installedon' = 'Installed: {0}'
    'm7.software.uninstall.confirm.title' = 'Open the uninstaller?'
    'm7.software.uninstall.confirm.msg' = 'This will open the official uninstaller of "{0}" and run:{1}{2}{3}You will confirm again inside the software uninstaller.'
    'm7.software.uninstall.confirm.noundo' = 'The uninstall is performed by the software own uninstaller — WinCare cannot undo it for you.'
    'm7.software.uninstall.running' = 'Opened the uninstaller of "{0}".'
    'm7.software.uninstall.fail' = 'Could not open the uninstaller'
    'm7.software.uninstall.nostring' = 'This program has no uninstall command in the registry.'
    'm7.software.journal' = 'Open official uninstaller'
    'm7.residual.title' = '"POSSIBLY leftover" folders'
    'm7.residual.hint' = 'Folders in Program Files / Program Files (x86) / ProgramData / Local\Programs not matching installed software — labeled "POSSIBLY" because false positives are easy'
    'm7.residual.empty' = 'No notable orphan folders found.'
    'm7.residual.open' = 'Open location (selected)'
    'm7.residual.delete' = 'Send to Recycle Bin (selected)'
    'm7.residual.delete.confirm.title' = 'Send folders to Recycle Bin?'
    'm7.residual.delete.confirm.msg' = 'The following folders will be moved to the RECYCLE BIN (not permanently deleted):'
    'm7.residual.delete.confirm.noundo' = 'WinCare will not auto-undo this — restore by dragging the folders back from the Recycle Bin.'
    'm7.residual.journal' = 'Recycle (leftover folder)'
    'm7.residual.orphan.title' = 'Orphan Uninstall keys in registry (REPORT only)'
    'm7.residual.orphan.hint' = 'Uninstall keys without DisplayName — usually traces of uninstalled apps. WinCare never deletes these; it only reports their existence.'
    'm7.residual.orphan.empty' = 'No orphan Uninstall keys.'
    'm7.residual.more' = '… and {0} more folders'
    'm7.residual.result' = 'Moved {0} folders to Recycle Bin, {1} failed/skipped.'
    'm7.games.title' = 'Games & launchers'
    'm7.games.hint' = 'Steam (libraryfolders.vdf + appmanifest), Epic (Manifests .item), other games via Uninstall keys'
    'm7.games.steam.none' = 'Steam not detected.'
    'm7.games.steam.ok' = 'Steam: {0} libraries, {1} games.'
    'm7.games.epic.none' = 'Epic Games Launcher not detected.'
    'm7.games.epic.ok' = 'Epic Games Launcher: {0} games.'
    'm7.games.col.name' = 'Game'
    'm7.games.col.source' = 'Source'
    'm7.games.col.size' = 'Size'
    'm7.games.col.last' = 'Last played'
    'm7.games.col.drive' = 'Drive'
    'm7.games.source.other' = 'Other (Uninstall)'
    'm7.games.last.unknown' = 'Unknown'
    'm7.games.old.total' = '• {0} games not played >180 days — totaling {1}. Uninstall/move via the launcher to free space.'
    'm7.games.hdd' = '• Games on an HDD (consider moving to SSD to cut load times): {0}'
    'm7.games.launcher' = '• Game launcher auto-starts with Windows: {0} — see Startup items above to disable if unneeded.'
    'm7.games.shader' = '• Shader caches: D3DSCache {0} + NVIDIA GLCache {1} — clean them in M2 (Disk cleanup); they rebuild automatically.'
    'm7.games.gpu.old' = '• GPU driver "{0}" is {1} days old (> 1 year) — see M3 (Drivers) to update.'
    'm7.games.gpu.ok' = '• GPU driver "{0}" updated {1} days ago — fine.'
    'm7.games.open.steam' = 'Open Steam'
    'm7.games.open.epic' = 'Open Epic'
    'm7.games.open.fail' = 'Could not open the launcher.'
    'm7.games.uninstall.note' = 'Uninstall/moving games ONLY via Steam/Epic — never delete game folders by hand (breaks the launcher).'
    'm7.games.empty' = 'No games detected via Steam / Epic / Uninstall keys.'
    'm7.games.more' = '… and {0} more games'
    'm7.sys.title' = 'System buildup'
    'm7.sys.hint' = 'Pending updates, last automatic maintenance, system drive, recent BSODs'
    'm7.sys.pending.ok' = '• No pending reboot flags — updates are finalized.'
    'm7.sys.pending.list' = '• Pending reboot flags: {0} — an update is not finalized; consider restarting.'
    'm7.sys.maintenance.label' = '• Last automatic maintenance: {0} ({1}).'
    'm7.sys.maintenance.none' = '• Not enough data about the last automatic maintenance.'
    'm7.sys.disk' = '• System drive free space: {0}%'
    'm7.sys.bsod.none' = '• BSODs in the last 90 days: 0.'
    'm7.sys.bsod.some' = '• BSODs in the last 90 days: {0} — see details in M5 (Stability & Integrity).'
    'm7.sys.bsod.nodata' = '• BSODs in the last 90 days: log not readable.'
    'm7.actions.title' = 'Directions (risk ascending)'
    'm7.actions.hint' = 'Go in order — only do what you understand and confirmed'
    'm7.actions.waiting' = 'Will appear once the scan finishes.'
    'm7.actions.1.title' = 'Targeted cleanup'
    'm7.actions.1.desc' = 'Run M2 (Disk cleanup) for safe cache/temp targets, and disable unneeded startup items in the "Startup items" section above.'
    'm7.actions.1.btn' = 'Open M2 — Disk cleanup'
    'm7.actions.2.title' = 'Uninstall/disable software, move games'
    'm7.actions.2.desc' = 'Remove bloatware via official uninstallers (Software section), move games from HDD to SSD via Steam/Epic (Games section). Never delete game folders by hand.'
    'm7.actions.3.title' = 'Reinstall Windows / Reset this PC (keep files)'
    'm7.actions.3.desc' = 'Consider only if the directions above do not help. This is your decision — WinCare does NOT automate this step.'
    'm7.actions.3.notneeded' = 'No basis to suggest a Windows reinstall yet: at least 3 objective signs at once are required (currently {0}/{1}).'
    'm7.actions.3.criteria' = 'Objective signs currently met:'
    'm7.actions.3.sign.boot' = '• Boot time increased by more than 50% (30-day vs 90-day median)'
    'm7.actions.3.sign.startup' = '• More than 15 non-Microsoft startup items'
    'm7.actions.3.sign.disk' = '• System drive below 10% free space'
    'm7.actions.3.sign.bsod' = '• 3 or more BSODs within 90 days'
    'm7.actions.3.checklist.title' = 'Backup checklist BEFORE reinstalling:'
    'm7.actions.3.checklist.1' = '• Documents, photos, videos — check Desktop, Downloads and folders outside C:'
    'm7.actions.3.checklist.2' = '• Browser data: sign in to sync, or export bookmarks/passwords'
    'm7.actions.3.checklist.3' = '• Software keys/licenses (Office, paid apps) — write them down to reactivate'
    'm7.actions.3.checklist.4' = '• Drivers exported in M3 (useful if Windows lacks drivers after install)'
    'm7.actions.3.checklist.5' = '• Confirm Windows is linked to your Microsoft account (to reactivate automatically)'
    'm7.actions.3.checklist.6' = '• List of software you use — review "Installed software" above'
    'm7.actions.3.guide.title' = 'Guide (you do it yourself):'
    'm7.actions.3.guide.1' = '• Way 1: Settings → System → Recovery → Reset this PC → "Keep my files" (keeps personal files, reinstalls Windows).'
    'm7.actions.3.guide.2' = '• Way 2: create an install USB with the Media Creation Tool from microsoft.com and install over the system partition (back up first per the checklist).'
    'm7.actions.3.note' = 'WinCare will not perform these steps for you — every reinstall action is yours.'
    'm7.nodata.reason' = 'Not enough data: {0}'
}

# ---------------------------------------------------------------------------
# UNDO HANDLER cho thao tac BAT LAI muc khoi dong (dao nguoc cua "tat")
# (handler "startup.enable" da co san trong 05-Journal.ps1)
# ---------------------------------------------------------------------------
Register-WCUndoHandler 'startup.disable' {
    # Tat lai muc khoi dong da bat lai qua StartupApproved (M7, ghi binary nhu Task Manager)
    param($Entry)
    $args2 = $Entry.UndoArgs
    $regPath = [string](Get-WCProp $args2 'RegPath')
    $valueName = [string](Get-WCProp $args2 'ValueName')
    if ($regPath -and $valueName) {
        $bytes = [byte[]]@(2,0,0,0,0,0,0,0,0,0,0,0)   # 4 byte dau 02 00 00 00 = dang TAT
        [Microsoft.Win32.Registry]::SetValue($regPath, $valueName, [byte[]]$bytes, [Microsoft.Win32.RegistryValueKind]::Binary)
    }
}

# ---------------------------------------------------------------------------
# DATA LAYER (Get-*/ConvertTo-* thuan, tra hashtable chuan hoa - spec 2.3)
# ---------------------------------------------------------------------------
function Get-WCWindowsInstallAge {
    # Tuoi cai dat: HKLM InstallDate la SO GIAY UNIX (khong phai FILETIME)
    # -> dung [DateTimeOffset]::FromUnixTimeSeconds de chuyen doi.
    $raw = Get-WCRegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'InstallDate'
    if ($null -eq $raw) { return $null }
    try {
        $secs = [long]$raw
        if ($secs -le 0) { return $null }
        $dto = [DateTimeOffset]::FromUnixTimeSeconds($secs)
        $ageDays = [int](([DateTimeOffset]::Now - $dto).TotalDays)
        if ($ageDays -lt 0) { $ageDays = 0 }
        return @{ InstallDate = $dto.LocalDateTime; AgeDays = $ageDays }
    } catch { return $null }
}

function Get-WCM7BootBucket {
    # Gom gio khoi dong trong N ngay gan nhat: Count + Median + Max (ms)
    param($Boots, [double]$Days, [DateTime]$Now)
    $vals = @()
    foreach ($b in $Boots) {
        $t = $b['Time']
        if (($null -ne $t) -and ($t -is [DateTime]) -and ((($Now - $t).TotalDays) -le $Days)) {
            $vals += [double]$b['TotalMs']
        }
    }
    if ($vals.Count -eq 0) { return @{ Count = 0; MedianMs = $null; MaxMs = $null } }
    $sorted = @($vals | Sort-Object)
    $med = $null
    if (($sorted.Count % 2) -eq 1) {
        $med = [double]$sorted[[int](($sorted.Count - 1) / 2)]
    } else {
        $med = ([double]$sorted[($sorted.Count / 2) - 1] + [double]$sorted[($sorted.Count / 2)]) / 2.0
    }
    return @{ Count = $vals.Count; MedianMs = [math]::Round($med, 0); MaxMs = [double]$sorted[$sorted.Count - 1] }
}

function Get-WCBootTrend {
    # Xu huong thoi gian khoi dong: su kien ID 100 (Boot) trong log
    # Microsoft-Windows-Diagnostics-Performance/Operational.
    # Doc MainPathBootTime + BootPostBootTime qua $event.Properties (index),
    # KHONG parse message (da dia phuong hoa). Tong = MainPath + PostBoot (ms).
    $out = @{ Boots = @(); Buckets = @{}; DeltaPct = $null; Enough = $false; SampleCount = 0; Error = '' }
    $events = @()
    try {
        $since = [DateTime]::Now.AddDays(-190)
        $events = @(Get-WinEvent -FilterHashtable @{
            LogName = 'Microsoft-Windows-Diagnostics-Performance/Operational'
            Id = 100; StartTime = $since } -ErrorAction Stop)
    } catch {
        # Log khong ton tai / khong co su kien -> khong du du lieu (khong phai loi)
        $out.Error = 'noevents'
        return $out
    }
    if ($events.Count -eq 0) { $out.Error = 'noevents'; return $out }
    # Xac dinh CHI SO truong MainPathBootTime / BootPostBootTime tu 1 su kien mau
    # (event XML EventData/Data theo dung thu tu voi Properties)
    $idxMain = -1; $idxPost = -1
    try {
        [xml]$xml = $events[0].ToXml()
        $i = 0
        foreach ($d in @($xml.Event.EventData.Data)) {
            $n = (Get-WCProp $d 'Name')
            if ($n -eq 'MainPathBootTime') { $idxMain = $i }
            if ($n -eq 'BootPostBootTime') { $idxPost = $i }
            $i++
        }
    } catch { }
    if (($idxMain -lt 0) -or ($idxPost -lt 0)) { $out.Error = 'nofields'; return $out }
    $now = [DateTime]::Now
    $boots = @()
    foreach ($e in $events) {
        try {
            $props = @(Get-WCProp $e 'Properties')
            $need = [Math]::Max($idxMain, $idxPost)
            if ($props.Count -le $need) { continue }
            $mainVal = (Get-WCProp $props[$idxMain] 'Value')
            $postVal = (Get-WCProp $props[$idxPost] 'Value')
            if (($null -eq $mainVal) -or ($null -eq $postVal)) { continue }
            $t = (Get-WCProp $e 'TimeCreated')
            if ($null -eq $t) { continue }
            $total = [double]$mainVal + [double]$postVal
            if ($total -le 0) { continue }
            $boots += @{ Time = $t; TotalMs = $total }
        } catch { }
    }
    $out.Boots = $boots
    $out.SampleCount = $boots.Count
    $out.Buckets['30'] = (Get-WCM7BootBucket -Boots $boots -Days 30 -Now $now)
    $out.Buckets['90'] = (Get-WCM7BootBucket -Boots $boots -Days 90 -Now $now)
    $out.Buckets['180'] = (Get-WCM7BootBucket -Boots $boots -Days 180 -Now $now)
    # So sanh trung vi 30 ngay voi trung vi 90 ngay (can du so mau de ket luan)
    $b30 = $out.Buckets['30']; $b90 = $out.Buckets['90']
    if (($b30.Count -ge 3) -and ($b90.Count -ge 5) -and $b90.MedianMs -and ($b90.MedianMs -gt 0)) {
        $delta = (([double]$b30.MedianMs - [double]$b90.MedianMs) / [double]$b90.MedianMs) * 100.0
        $out.DeltaPct = [math]::Round($delta, 0)
        $out.Enough = $true
    }
    return $out
}

function Test-WCM7IsMicrosoftPath {
    # Heuristic "thuoc Windows/Model Microsoft": duong dan nam trong %SystemRoot%
    # hoac chua \Microsoft\ (vi du OneDrive trong LOCALAPPDATA\Microsoft)
    param([string]$Path)
    if ([string]::IsNullOrEmpty($Path)) { return $false }
    try {
        $p = $Path.ToLowerInvariant()
        $win = ''
        try { $win = ([string]$env:SystemRoot).ToLowerInvariant() } catch { }
        if ($win -and ($p.StartsWith($win))) { return $true }
        if ($p -like '*\microsoft\*') { return $true }
    } catch { }
    return $false
}

function Resolve-WCM7ShortcutTarget {
    # Doc duong dan dich cua .lnk qua COM WScript.Shell (khong parse CLI)
    param([string]$Path)
    try {
        $sh = New-Object -ComObject WScript.Shell
        $sc = $sh.CreateShortcut($Path)
        # COM: truy cap thuoc tinh trong try/catch (TargetPath ton tai tren shortcut)
        $t = [string]$sc.TargetPath
        try { $null = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($sc) } catch { }
        try { $null = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($sh) } catch { }
        return $t
    } catch { return '' }
}

function Get-WCStartupApprovedState {
    # Trang thai bat/tat tu gia tri binary StartupApproved (12 byte).
    # DECODE PHO BIEN (chua kiem chung tren moi may, xem comment file):
    #   4 byte dau 00 00 00 00 = dang BAT; 02 00 00 00 = da TAT.
    # Gia tri khac / thieu -> coi nhu dang BAT (nhu cach Task Manager hien thi).
    param([string]$ApprovedKey, [string]$ValueName)
    try {
        $bytes = Get-WCRegistryValue -Path $ApprovedKey -Name $ValueName
        if ($null -eq $bytes) { return 'Enabled' }
        $arr = @($bytes)
        if ($arr.Count -lt 4) { return 'Enabled' }
        if (($arr[0] -eq 2) -and ($arr[1] -eq 0) -and ($arr[2] -eq 0) -and ($arr[3] -eq 0)) { return 'Disabled' }
        if (($arr[0] -eq 0) -and ($arr[1] -eq 0) -and ($arr[2] -eq 0) -and ($arr[3] -eq 0)) { return 'Enabled' }
        return 'Enabled'
    } catch { return 'Enabled' }
}

function Convert-WCRegPsPathToFull {
    # 'HKLM:\...' -> 'HKEY_LOCAL_MACHINE\...' (dang ma [Microsoft.Win32.Registry]::SetValue dung)
    param([string]$Path)
    if ($Path -like 'HKLM:\*') { return ('HKEY_LOCAL_MACHINE\' + $Path.Substring(6)) }
    if ($Path -like 'HKCU:\*') { return ('HKEY_CURRENT_USER\' + $Path.Substring(6)) }
    return $Path
}

function Set-WCStartupApprovedState {
    # Viet binary StartupApproved DUNG CACH Task Manager (KHONG xoa khoa goc):
    #   Bat = 12 byte 0; Tat = 02 00 00 00 + 8 byte 0.
    param([string]$ApprovedKey, [string]$ValueName, [bool]$Enable)
    $full = Convert-WCRegPsPathToFull -Path $ApprovedKey
    $bytes = [byte[]]@(0,0,0,0,0,0,0,0,0,0,0,0)
    if (-not $Enable) { $bytes = [byte[]]@(2,0,0,0,0,0,0,0,0,0,0,0) }
    [Microsoft.Win32.Registry]::SetValue($full, $ValueName, [byte[]]$bytes, [Microsoft.Win32.RegistryValueKind]::Binary)
}

function Get-WCStartupEntries {
    # Gom muc khoi dong: Run keys (HKLM/HKCU + WOW6432Node), thu muc Startup
    # (user + common), Scheduled Task trigger Logon/Boot ngoai Microsoft,
    # service Auto ngoai Microsoft. Trang thai doc tu StartupApproved.
    param([bool]$IncludeTasksAndServices = $true)
    $out = @{ Entries = @(); Tasks = @(); Services = @(); NonMsCount = 0; NonMsEnabledCount = 0; Error = '' }
    # --- Run keys ---
    $runSources = @(
        @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
           Approved = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' }
        @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
           Approved = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run' }
        @{ Path = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
           Approved = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32' }
        @{ Path = 'HKCU:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run'
           Approved = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32' }
    )
    foreach ($src in $runSources) {
        try {
            if (-not (Test-Path -LiteralPath $src['Path'])) { continue }
            $key = Get-Item -LiteralPath $src['Path'] -ErrorAction Stop
            foreach ($vn in @($key.GetValueNames())) {
                try {
                    $cmd = ''
                    try { $cmd = [string]$key.GetValue($vn) } catch { }
                    if ([string]::IsNullOrEmpty($cmd)) { continue }
                    $state = Get-WCStartupApprovedState -ApprovedKey $src['Approved'] -ValueName $vn
                    $out.Entries += @{
                        Name = $vn; Command = $cmd; Kind = 'Run'
                        IsMicrosoft = (Test-WCM7IsMicrosoftPath -Path $cmd)
                        State = $state
                        ApprovedKey = $src['Approved']; ValueName = $vn
                    }
                } catch { }
            }
        } catch { }
    }
    # --- Thu muc Startup (user + common) ---
    $folderSources = @(
        @{ Folder = ([Environment]::GetFolderPath('Startup'))
           Approved = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder' }
        @{ Folder = ([Environment]::GetFolderPath('CommonStartup'))
           Approved = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder' }
    )
    foreach ($src in $folderSources) {
        try {
            if ([string]::IsNullOrEmpty($src['Folder']) -or (-not (Test-Path -LiteralPath $src['Folder']))) { continue }
            $files = @(Get-ChildItem -LiteralPath $src['Folder'] -File -ErrorAction SilentlyContinue)
            foreach ($f in $files) {
                try {
                    if ($f.Name -ieq 'desktop.ini') { continue }
                    $target = ''
                    if ($f.Extension -ieq '.lnk') { $target = (Resolve-WCM7ShortcutTarget -Path $f.FullName) }
                    $state = Get-WCStartupApprovedState -ApprovedKey $src['Approved'] -ValueName $f.Name
                    $out.Entries += @{
                        Name = $f.Name; Command = $target; Kind = 'Folder'
                        IsMicrosoft = (Test-WCM7IsMicrosoftPath -Path $target)
                        State = $state
                        ApprovedKey = $src['Approved']; ValueName = $f.Name
                    }
                } catch { }
            }
        } catch { }
    }
    # --- Scheduled Task trigger Logon/Boot, ngoai Microsoft ---
    if ($IncludeTasksAndServices) {
        try {
            $all = @(Get-ScheduledTask -ErrorAction SilentlyContinue)
            foreach ($t in $all) {
                try {
                    $tp = [string](Get-WCProp $t 'TaskPath')
                    if ($tp -like '\Microsoft\*') { continue }
                    $triggers = @(Get-WCProp $t 'Triggers')
                    $hit = $false
                    foreach ($tr in $triggers) {
                        $cn = ''
                        try {
                            $cc = Get-WCProp $tr 'CimClass'
                            if ($cc) { $cn = [string](Get-WCProp $cc 'CimClassName') }
                        } catch { }
                        if ([string]::IsNullOrEmpty($cn)) {
                            # Phuong an B: ten kieu PSObject (CimInstance#...MSFT_TaskLogonTrigger)
                            try {
                                foreach ($tn in @($tr.PSObject.TypeNames)) {
                                    if ($tn -match 'LogonTrigger|BootTrigger') { $cn = $tn; break }
                                }
                            } catch { }
                        }
                        if ($cn -match 'LogonTrigger|BootTrigger') { $hit = $true; break }
                    }
                    if ($hit) {
                        $out.Tasks += @{
                            Name = ([string](Get-WCProp $t 'TaskName'))
                            TaskPath = $tp
                            State = ([string](Get-WCProp $t 'State'))
                        }
                    }
                } catch { }
            }
        } catch { }
        # --- Service Auto ngoai Microsoft (heuristic theo duong dan) ---
        try {
            $svcs = @(Get-CimInstance -ClassName Win32_Service -Property Name,DisplayName,State,StartMode,PathName -OperationTimeoutSec 15)
            foreach ($s in $svcs) {
                try {
                    if ((Get-WCProp $s 'StartMode') -ne 'Auto') { continue }
                    $pn = [string](Get-WCProp $s 'PathName')
                    if (Test-WCM7IsMicrosoftPath -Path $pn) { continue }
                    $out.Services += @{
                        Name = ([string](Get-WCProp $s 'Name'))
                        DisplayName = ([string](Get-WCProp $s 'DisplayName'))
                        State = ([string](Get-WCProp $s 'State')); PathName = $pn
                    }
                } catch { }
            }
        } catch { }
    }
    # --- Dem muc NGOAI Microsoft (chi so bang chung) ---
    $nonMs = 0; $nonMsEnabled = 0
    foreach ($e in @($out.Entries)) {
        if (-not $e['IsMicrosoft']) {
            $nonMs++
            if ($e['State'] -ne 'Disabled') { $nonMsEnabled++ }
        }
    }
    foreach ($tk in @($out.Tasks)) {
        $nonMs++
        if ($tk['State'] -ne 'Disabled') { $nonMsEnabled++ }
    }
    foreach ($sv in @($out.Services)) {
        $nonMs++
        if ($sv['State'] -eq 'Running') { $nonMsEnabled++ }
    }
    $out.NonMsCount = $nonMs
    $out.NonMsEnabledCount = $nonMsEnabled
    return $out
}

function ConvertTo-WCM7InstallDateText {
    # InstallDate trong khoa Uninstall dang 'YYYYMMDD' -> 'YYYY-MM-DD'
    param($Raw)
    try {
        $s = [string]$Raw
        if ($s -match '^(\d{4})(\d{2})(\d{2})$') {
            return ($Matches[1] + '-' + $Matches[2] + '-' + $Matches[3])
        }
    } catch { }
    return ''
}

function Get-WCInstalledSoftware {
    # Dem phan mem tu khoa Uninstall: HKLM 64/32-bit + HKCU.
    # KHONG bao gio truy van lop WMI "san pham" cua Windows (gay MSI self-repair - spec M7).
    # Ket qua: @{ Total; Apps = @{DisplayName;Publisher;InstallDateText;
    #            UninstallString;EstimatedBytes}; OrphanKeys = @{KeyName} }
    $roots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    $apps = @()
    $seen = @{}
    $orphans = @()
    foreach ($root in $roots) {
        try {
            if (-not (Test-Path -LiteralPath $root)) { continue }
            $keys = @(Get-ChildItem -LiteralPath $root -ErrorAction Stop)
            foreach ($k in $keys) {
                try {
                    $p = Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction Stop
                    if ((Get-WCProp $p 'SystemComponent') -eq 1) { continue }
                    $name = (Get-WCProp $p 'DisplayName')
                    if ([string]::IsNullOrEmpty([string]$name)) {
                        # Muc Uninstall mo coi (khong co DisplayName) -> CHI BAO CAO
                        $orphans += @{ KeyName = ([string]$k.PSChildName); Root = $root }
                        continue
                    }
                    $pub = [string](Get-WCProp $p 'Publisher')
                    $dedupeKey = (([string]$name).ToLowerInvariant() + '|' + $pub.ToLowerInvariant())
                    if ($seen.ContainsKey($dedupeKey)) { continue }
                    $seen[$dedupeKey] = $true
                    $estBytes = [long]0
                    $est = Get-WCProp $p 'EstimatedSize'
                    if ($null -ne $est) { $estBytes = ([long]$est) * 1KB }
                    $apps += @{
                        DisplayName = [string]$name; Publisher = $pub
                        InstallDateText = (ConvertTo-WCM7InstallDateText (Get-WCProp $p 'InstallDate'))
                        UninstallString = [string](Get-WCProp $p 'UninstallString')
                        EstimatedBytes = $estBytes
                    }
                } catch { }
            }
        } catch { }
    }
    return @{ Total = $apps.Count; Apps = $apps; OrphanKeys = $orphans }
}

function Get-WCOemBloatCandidates {
    # Loc ung vien OEM/bloatware: ten khop danh sach phan mem lap san pho bien.
    # CHI DE XUAT - nguoi dung tu quyet dinh go (spec M7).
    param($Apps)
    $patterns = @(
        'Dell SupportAssist','Dell Optimizer','Dell Mobile Connect','Dell Digital Delivery','SupportAssist',
        'McAfee','WildTangent','HP JumpStart','HP Support Assistant','HP Documentation','HP Orbit',
        'Lenovo','CyberLink','Booking.com','Ask Toolbar','Google Toolbar','Bing Bar',
        'WinZip Driver Updater','Driver Booster','Advanced SystemCare','DriverPack','PC Cleaner',
        'Registry Cleaner','MyWinLocker'
    )
    $hits = @()
    foreach ($a in @($Apps)) {
        $name = [string]$a['DisplayName']
        $pub = [string]$a['Publisher']
        if ([string]::IsNullOrEmpty($name)) { continue }
        $matched = $false
        foreach ($pat in $patterns) {
            if (($name -like ('*' + $pat + '*')) -or ($pub -like ('*' + $pat + '*'))) { $matched = $true; break }
        }
        if ($matched) { $hits += $a }
    }
    return $hits
}

function ConvertTo-WCM7NormName {
    # Chuan hoa ten de so khop mo: chu thuong, chi giu [0-9a-z]
    param([string]$Name)
    try {
        $n = ($Name.ToLowerInvariant() -replace '[^0-9a-z]', '')
        if ([string]::IsNullOrEmpty($n)) { return ($Name.ToLowerInvariant()) }
        return $n
    } catch { return ($Name.ToLowerInvariant()) }
}

function Test-WCM7NameMatch {
    # So khop MO (fuzzy) ten thu muc voi danh sach DisplayName:
    # DisplayName bo khoang trang roi so -like '*<folder>*' (hoac nguoc lai).
    # Ten thu muc ngan (<4 ky tu) chi khop KHOANH DUNG de tranh bao nham.
    param([string]$NormFolder, $Names)
    foreach ($n in $Names) {
        $normName = ConvertTo-WCM7NormName -Name ([string]$n)
        if ([string]::IsNullOrEmpty($normName)) { continue }
        if ($NormFolder.Length -ge 4) {
            if ($normName -like ('*' + $NormFolder + '*')) { return $true }
            if ($NormFolder -like ('*' + $normName + '*')) { return $true }
        } else {
            # Ten thu muc ngan: chi khop khoanh dung hoac tien to (an toan
            # huong "khong bao tan du" thay vi "bao nham")
            if ($normName -eq $NormFolder) { return $true }
            if ($normName -like ($NormFolder + '*')) { return $true }
        }
    }
    return $false
}

function Get-WCResidualCandidates {
    # Thu muc mo coi trong Program Files / PF(x86) / ProgramData / Local\Programs
    # KHONG ung voi phan mem dang cai (so khop mo voi DisplayName).
    # Nhan "CO THE la tan du" - de bao nham, chi bo cao + kich thuoc.
    $sw = Get-WCInstalledSoftware
    $names = @()
    foreach ($a in @($sw['Apps'])) { $names += [string]$a['DisplayName'] }
    # Thu muc he thong bo qua (dang CHUAN HOA khong khoang trang)
    $skipNorm = @(
        'commonfiles','microsoft','windows','windowsnt','internetexplorer','windowsapps',
        'windowsdefender','modifiablewindowsapps','installshieldinstallationinformation',
        'packagecache','packages','softwaredistribution','usoshared','regid199106commicrosoft',
        'windowspowershell','powershell','default','public','desktop','documents','startmenu',
        'programs','chocolatey','windowsholographicdevices','ssh','usoprivatecatalogupdate'
    )
    $roots = @()
    foreach ($p in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData, (Join-Path $env:LOCALAPPDATA 'Programs'))) {
        if ($p -and (Test-Path -LiteralPath $p)) { $roots += [string]$p }
    }
    $result = @()
    foreach ($root in $roots) {
        try {
            $dirs = @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue)
            foreach ($d in $dirs) {
                try {
                    $norm = ConvertTo-WCM7NormName -Name $d.Name
                    if ($norm.Length -lt 2) { continue }
                    if ($skipNorm -contains $norm) { continue }
                    if (Test-WCM7NameMatch -NormFolder $norm -Names $names) { continue }
                    if (Test-WCPathIsReparsePoint -Path $d.FullName) { continue }   # junction -> bo qua
                    $size = Get-WCDirSize -Path $d.FullName
                    $result += @{ Path = $d.FullName; Name = $d.Name; Root = $root; SizeBytes = $size }
                } catch { }
            }
        } catch { }
    }
    $sorted = @($result | Sort-Object -Property { $_['SizeBytes'] } -Descending)
    return @{ Folders = $sorted }
}

function Get-WCSteamLibraryPaths {
    # Parser VDF DON GIAN (ham thuan de unit test): moi dong '"path"  "C:\\..."'
    # trong libraryfolders.vdf -> tra mang duong dan thu vien Steam.
    param([string]$SteamRoot)
    $paths = @()
    try {
        if ([string]::IsNullOrEmpty($SteamRoot)) { return @() }
        $vdf = Join-Path $SteamRoot 'steamapps\libraryfolders.vdf'
        if (-not (Test-Path -LiteralPath $vdf)) { return @() }
        foreach ($line in [IO.File]::ReadAllLines($vdf)) {
            if ($line -match '"path"\s+"(.+)"') {
                $p = ($Matches[1] -replace '\\\\', '\')
                if (-not [string]::IsNullOrEmpty($p)) { $paths += $p }
            }
        }
    } catch { }
    return $paths
}

function Get-WCSteamGames {
    # Doc appmanifest_*.acf trong tung thu vien Steam: name / SizeOnDisk /
    # LastPlayed (giay Unix). Lay ket qua DAU TIEN cho moi truong (cap muc cao
    # nam truoc cac khoi long - ten co the trung o muc sau).
    param([string]$SteamRoot)
    $games = @()
    $libs = @(Get-WCSteamLibraryPaths -SteamRoot $SteamRoot)
    if ($libs.Count -eq 0) { $libs = @([string]$SteamRoot) }
    foreach ($lib in $libs) {
        try {
            $appsDir = Join-Path $lib 'steamapps'
            if (-not (Test-Path -LiteralPath $appsDir)) { continue }
            $files = @(Get-ChildItem -LiteralPath $appsDir -Filter 'appmanifest_*.acf' -File -ErrorAction SilentlyContinue)
            foreach ($f in $files) {
                try {
                    $name = ''; $size = [long]0; $last = [long]0
                    foreach ($line in [IO.File]::ReadAllLines($f.FullName)) {
                        if (($name -eq '') -and ($line -match '"name"\s+"(.*)"')) { $name = $Matches[1] }
                        elseif (($size -eq 0) -and ($line -match '"SizeOnDisk"\s+"(\d+)"')) { $size = [long]$Matches[1] }
                        elseif (($last -eq 0) -and ($line -match '"LastPlayed"\s+"(\d+)"')) { $last = [long]$Matches[1] }
                    }
                    if ([string]::IsNullOrEmpty($name)) { continue }
                    $lastDt = $null
                    if ($last -gt 0) {
                        try { $lastDt = [DateTimeOffset]::FromUnixTimeSeconds($last).LocalDateTime } catch { }
                    }
                    $drive = ''
                    if ($lib -match '^([A-Za-z]):') { $drive = $Matches[1] + ':' }
                    $games += @{ Name = $name; Source = 'Steam'; SizeBytes = $size; LastPlayed = $lastDt; Drive = $drive }
                } catch { }
            }
        } catch { }
    }
    return $games
}

function Get-WCEpicGames {
    # Epic: %ProgramData%\Epic\EpicGamesLauncher\Data\Manifests\*.item (JSON)
    # Thuoc tinh doc qua Get-WCProp; thieu (AppSizeBytes...) -> de N/A.
    $games = @()
    try {
        $dir = Join-Path $env:ProgramData 'Epic\EpicGamesLauncher\Data\Manifests'
        if (-not (Test-Path -LiteralPath $dir)) { return @() }
        $files = @(Get-ChildItem -LiteralPath $dir -Filter '*.item' -File -ErrorAction SilentlyContinue)
        foreach ($f in $files) {
            try {
                $json = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
                $name = [string](Get-WCProp $json 'DisplayName')
                if ([string]::IsNullOrEmpty($name)) { continue }
                $loc = [string](Get-WCProp $json 'InstallLocation')
                $size = [long]0
                $szProp = Get-WCProp $json 'AppSizeBytes'
                if ($null -ne $szProp) { $size = [long]$szProp }
                $drive = ''
                if ($loc -match '^([A-Za-z]):') { $drive = $Matches[1] + ':' }
                $games += @{ Name = $name; Source = 'Epic'; SizeBytes = $size; LastPlayed = $null; Drive = $drive }
            } catch { }
        }
    } catch { }
    return $games
}

function Get-WCDriveMediaTypeMap {
    # Map ky tu o -> 'SSD'/'HDD' de goi y "game nam tren o HDD".
    # dung CIM: Win32_LogicalDiskToPartition (lay Disk #) + MSFT_PhysicalDisk
    # (root/Microsoft/Windows/Storage, MediaType 3=HDD 4=SSD). Loi -> map rong
    # (bo goi y, khong bao loi - spec M7).
    $map = @{}
    try {
        $phys = @(Get-CimInstance -Namespace 'root/Microsoft/Windows/Storage' -ClassName 'MSFT_PhysicalDisk' -Property DeviceId,MediaType -OperationTimeoutSec 10 -ErrorAction Stop)
        $byDisk = @{}
        foreach ($p in $phys) {
            $dev = [string](Get-WCProp $p 'DeviceId')
            $mt = (Get-WCProp $p 'MediaType')
            if ($dev) {
                $kind = ''
                if ([int]$mt -eq 3) { $kind = 'HDD' }
                if ([int]$mt -eq 4) { $kind = 'SSD' }
                $byDisk[$dev] = $kind
            }
        }
        $assoc = @(Get-CimInstance -ClassName Win32_LogicalDiskToPartition -OperationTimeoutSec 10 -ErrorAction Stop)
        foreach ($a in $assoc) {
            try {
                $ant = [string](Get-WCProp $a 'Antecedent')   # ...DiskPartition.DeviceID="Disk #0, Partition #2"
                $dep = [string](Get-WCProp $a 'Dependent')    # ...LogicalDisk.DeviceID="C:"
                $diskIdx = ''
                if ($ant -match 'Disk #(\d+)') { $diskIdx = $Matches[1] }
                $letter = ''
                if ($dep -match '"([A-Za-z]):"') { $letter = $Matches[1] + ':' }
                if ($diskIdx -ne '' -and $letter -ne '' -and $byDisk.ContainsKey($diskIdx)) {
                    $map[$letter] = $byDisk[$diskIdx]
                }
            } catch { }
        }
    } catch { }
    return $map
}

function Get-WCGamesInfo {
    # Gom toan bo thong tin game: Steam + Epic + game khac qua khoa Uninstall,
    # goi y (game lau khong choi, o HDD, launcher tu chay, shader cache,
    # driver GPU cu). Steam/Epic khong cai -> khong loi, chi bao "khong phat hien".
    $out = @{
        SteamInstalled = $false; EpicInstalled = $false; SteamRoot = ''
        Games = @(); OldGamesCount = 0; OldGamesBytes = [long]0
        HddGames = @(); LauncherInStartup = @()
        ShaderD3DBytes = $null; ShaderGlBytes = $null
        GpuName = ''; GpuDriverDays = $null
        Error = ''
    }
    # --- Steam ---
    try {
        $pf86 = ${env:ProgramFiles(x86)}
        if ($pf86 -and (Test-Path -LiteralPath (Join-Path $pf86 'Steam'))) {
            $out.SteamRoot = (Join-Path $pf86 'Steam')
            $out.SteamInstalled = $true
        }
    } catch { }
    if ($out.SteamInstalled) {
        $steamGames = @(Get-WCSteamGames -SteamRoot $out.SteamRoot)
        $out.Games += $steamGames
    }
    # --- Epic ---
    try {
        $epicGames = @(Get-WCEpicGames)
        if ($epicGames.Count -gt 0) {
            $out.EpicInstalled = $true
            $out.Games += $epicGames
        }
    } catch { }
    # --- Game khac qua khoa Uninstall (Publisher khop nha phat hanh game) ---
    try {
        $sw = Get-WCInstalledSoftware
        $haveNames = @{}
        foreach ($g in @($out.Games)) { $haveNames[([string]$g['Name']).ToLowerInvariant()] = $true }
        foreach ($a in @($sw['Apps'])) {
            $name = [string]$a['DisplayName']
            $pub = [string]$a['Publisher']
            if ([string]::IsNullOrEmpty($name)) { continue }
            $nl = $name.ToLowerInvariant()
            if ($nl -eq 'steam' -or $nl -eq 'epic games launcher') { continue }   # launcher, khong phai game
            if ($haveNames.ContainsKey($nl)) { continue }
            if ($pub -match 'Valve|Steam|Epic Games|GOG|Ubisoft|Electronic Arts|Activision|Bethesda') {
                $out.Games += @{ Name = $name; Source = 'Other'; SizeBytes = [long]$a['EstimatedBytes']; LastPlayed = $null; Drive = '' }
            }
        }
    } catch { }
    # --- Goi y: game lau khong choi (>180 ngay, LastPlayed > 0) ---
    $now = [DateTime]::Now
    foreach ($g in @($out.Games)) {
        $lp = $g['LastPlayed']
        if (($null -ne $lp) -and ($lp -is [DateTime]) -and ((($now - $lp).TotalDays) -gt 180)) {
            $out.OldGamesCount++
            $out.OldGamesBytes += [long]$g['SizeBytes']
        }
    }
    # --- Goi y: game nam tren o HDD ---
    try {
        $driveMap = Get-WCDriveMediaTypeMap
        if ($driveMap.Count -gt 0) {
            foreach ($g in @($out.Games)) {
                $d = [string]$g['Drive']
                if ($d -and $driveMap.ContainsKey($d) -and ($driveMap[$d] -eq 'HDD')) {
                    $out.HddGames += [string]$g['Name']
                }
            }
        }
    } catch { }
    # --- Goi y: launcher tu chay cung Windows (chi xem Run keys + Startup folder) ---
    try {
        $su = Get-WCStartupEntries -IncludeTasksAndServices:$false
        foreach ($e in @($su['Entries'])) {
            $hay = (([string]$e['Name']) + ' ' + ([string]$e['Command'])).ToLowerInvariant()
            if ($hay -match 'steam|epicgames|epic games') { $out.LauncherInStartup += [string]$e['Name'] }
        }
    } catch { }
    # --- Shader cache (doi chieu M2 - o day chi hien dung luong) ---
    try {
        $d3d = Join-Path $env:LOCALAPPDATA 'D3DSCache'
        if (Test-Path -LiteralPath $d3d) { $out.ShaderD3DBytes = (Get-WCDirSize -Path $d3d) }
    } catch { }
    try {
        $gl = Join-Path $env:LOCALAPPDATA 'NVIDIA\GLCache'
        if (Test-Path -LiteralPath $gl) { $out.ShaderGlBytes = (Get-WCDirSize -Path $gl) }
    } catch { }
    # --- Driver GPU cu (> 1 nam -> goi y xem M3) ---
    try {
        $gpus = @(Get-CimInstance -ClassName Win32_VideoController -Property Name,DriverDate -OperationTimeoutSec 10)
        $oldest = $null
        foreach ($g in $gpus) {
            $n = [string](Get-WCProp $g 'Name')
            if ($n -and ([string]::IsNullOrEmpty($out.GpuName))) { $out.GpuName = $n }
            $dd = Get-WCProp $g 'DriverDate'
            if ($null -ne $dd) {
                $d = $null
                try {
                    if ($dd -is [DateTime]) { $d = $dd }
                    else { $d = $dd.ToDateTime([Globalization.CultureInfo]::InvariantCulture) }
                } catch { }
                if ($d -and (($null -eq $oldest) -or ($d -lt $oldest))) { $oldest = $d }
            }
        }
        if ($oldest) { $out.GpuDriverDays = [int](([DateTime]::Now - $oldest).TotalDays) }
    } catch { }
    return $out
}

function Get-WCSystemAccumulation {
    # Tich tu he thong: co cho khoi dong lai, lan bao tri tu dong gan nhat,
    # o he thong con trong bao nhieu %, so lan BSOD 90 ngay.
    $out = @{
        PendingFlags = @(); MaintenanceLastRun = $null; MaintenanceDays = $null
        DiskFreePct = $null; BsodCount90 = $null; Error = ''
    }
    # 1) Co cho khoi dong lai (RebootPending keys)
    try {
        if (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') {
            $out.PendingFlags += 'CBS'
        }
    } catch { }
    try {
        if (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootPending') {
            $out.PendingFlags += 'WindowsUpdate'
        }
    } catch { }
    try {
        $pfro = Get-WCRegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations'
        $arr = @($pfro)
        if ($arr.Count -gt 0 -and (-not [string]::IsNullOrEmpty([string]$arr[0]))) {
            $out.PendingFlags += 'PendingFileRename'
        }
    } catch { }
    # 2) Thoi gian tu lan bao tri tu dong (Idle Maintenance / Maintenance Configurator)
    foreach ($taskName in @('Idle Maintenance', 'Maintenance Configurator')) {
        try {
            $info = Get-ScheduledTaskInfo -TaskName $taskName -TaskPath '\Microsoft\Windows\TaskScheduler\' -ErrorAction Stop
            $lr = Get-WCProp $info 'LastRunTime'
            if ($lr -and ($lr -is [DateTime]) -and ($lr.Year -gt 2000)) {
                $out.MaintenanceLastRun = $lr
                $out.MaintenanceDays = [int](([DateTime]::Now - $lr).TotalDays)
                break
            }
        } catch { }
    }
    # 3) O he thong con trong bao nhieu phan tram
    try {
        $ld = Get-CimInstance -ClassName Win32_LogicalDisk -Filter ("DeviceID='" + $env:SystemDrive + "'") -Property Size,FreeSpace -OperationTimeoutSec 10
        $sz = Get-WCProp $ld 'Size'
        $fr = Get-WCProp $ld 'FreeSpace'
        if ($sz -and $fr) {
            $out.DiskFreePct = [math]::Round(([double]$fr / [double]$sz) * 100.0, 1)
        }
    } catch { }
    # 4) So lan BSOD (BugCheck) trong 90 ngay - thu 2 provider, tinh theo so su kien
    try {
        $since = [DateTime]::Now.AddDays(-90)
        $count = 0
        try {
            $ev = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-WER-SystemErrorReporter'; Id = 1001; StartTime = $since } -ErrorAction Stop)
            $count = $ev.Count
        } catch { $count = 0 }
        if ($count -eq 0) {
            try {
                $ev2 = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'BugCheck'; Id = 1001; StartTime = $since } -ErrorAction Stop)
                $count = $ev2.Count
            } catch { $count = 0 }
        }
        $out.BsodCount90 = $count
    } catch { $out.BsodCount90 = $null }
    return $out
}

function Split-WCUninstallCommand {
    # Tach UninstallString thanh exe + args:
    #   - neu bat dau bang '"' -> exe la phan trong ngoac, phan con lai la args
    #   - nguoc lai exe la token dau tien
    param([string]$Cmd)
    try {
        $c = ($Cmd).Trim()
        if ([string]::IsNullOrEmpty($c)) { return $null }
        if ($c.StartsWith('"')) {
            $end = $c.IndexOf('"', 1)
            if ($end -gt 1) {
                $exe = $c.Substring(1, $end - 1)
                $rest = $c.Substring($end + 1).Trim()
                return @{ Exe = $exe; Args = $rest }
            }
            return $null
        }
        $sp = $c.IndexOf(' ')
        if ($sp -lt 0) { return @{ Exe = $c; Args = '' } }
        return @{ Exe = $c.Substring(0, $sp); Args = $c.Substring($sp + 1).Trim() }
    } catch { return $null }
}

function Get-WCAgingVerdict {
    # Tinh chi so "Do lao hoa" tu du lieu 7 nguon. THUAN (de unit test):
    # dau vao la cac hashtable (hoac $null), dau ra nhan + chi tiet dau hieu.
    # Gia dinh nguong (ghi ro trong bao cao): boot > +25% nhe / > +50% nang;
    # startup ngoai MS > 10 nhe / > 15 nang; bloat >= 2 nhe; tan du > 1GB nhe;
    # o he thong < 20% trong nhe / < 10% nang; >= 2 co pending nhe; BSOD >= 3 nang.
    # Nhan: diem = nhe + 2*nang; >= 4 "Tich tu nhieu"; 2..3 "nhe"; <= 1 la
    # "Moi/Nhu moi" (tuoi < 90 ngay) hoac "Duoc cham soc tot".
    param($Age, $Boot, $Startup, $Software, $Residual, $Games, $Sys)
    $v = @{
        LabelKey = 'm7.verdict.good'; ChipKind = 'Ok'
        Mild = 0; Strong = 0; AgeDays = $null
        BootDeltaPct = $null; BootEnough = $false; BootStrong = $false
        StartupNonMs = 0; StartupEnabled = 0
        BloatCount = 0; ResidualCount = 0; ResidualBytes = [long]0
        OldGamesCount = 0; OldGamesBytes = [long]0
        DiskFreePct = $null; PendingCount = 0; Bsod90 = $null
        ReinstallSigns = @(); ReinstallMet = $false
    }
    if ($Age -and $null -ne $Age['AgeDays']) { $v.AgeDays = [int]$Age['AgeDays'] }
    # Boot trend
    if ($Boot -and $Boot['Enough'] -and ($null -ne $Boot['DeltaPct'])) {
        $v.BootDeltaPct = [double]$Boot['DeltaPct']
        $v.BootEnough = $true
        if ($v.BootDeltaPct -gt 50) { $v.Strong++; $v.BootStrong = $true; $v.ReinstallSigns += 'boot' }
        elseif ($v.BootDeltaPct -gt 25) { $v.Mild++ }
    }
    # Startup ngoai Microsoft
    if ($Startup -and ($null -ne $Startup['NonMsCount'])) {
        $v.StartupNonMs = [int]$Startup['NonMsCount']
        $v.StartupEnabled = [int]$Startup['NonMsEnabledCount']
        if ($v.StartupNonMs -gt 15) { $v.Strong++; $v.ReinstallSigns += 'startup' }
        elseif ($v.StartupNonMs -gt 10) { $v.Mild++ }
    }
    # Bloatware
    if ($Software -and $Software['Bloat']) {
        $v.BloatCount = @($Software['Bloat']).Count
        if ($v.BloatCount -ge 2) { $v.Mild++ }
    }
    # Tan du
    if ($Residual -and $Residual['Folders']) {
        $v.ResidualCount = @($Residual['Folders']).Count
        foreach ($f in @($Residual['Folders'])) { $v.ResidualBytes += [long]$f['SizeBytes'] }
        if ($v.ResidualBytes -gt 1GB) { $v.Mild++ }
    }
    # Game lau khong choi (chi la goi y giai phong cho, KHONG tinh dau hieu lao hoa)
    if ($Games) {
        $v.OldGamesCount = [int]$Games['OldGamesCount']
        $v.OldGamesBytes = [long]$Games['OldGamesBytes']
    }
    # O he thong + pending + BSOD
    if ($Sys) {
        if ($null -ne $Sys['DiskFreePct']) {
            $v.DiskFreePct = [double]$Sys['DiskFreePct']
            if ($v.DiskFreePct -lt 10) { $v.Strong++; $v.ReinstallSigns += 'disk' }
            elseif ($v.DiskFreePct -lt 20) { $v.Mild++ }
        }
        if ($null -ne $Sys['PendingCount']) {
            $v.PendingCount = [int]$Sys['PendingCount']
            if ($v.PendingCount -ge 2) { $v.Mild++ }
        }
        if ($null -ne $Sys['BsodCount90']) {
            $v.Bsod90 = [int]$Sys['BsodCount90']
            if ($v.Bsod90 -ge 3) { $v.Strong++; $v.ReinstallSigns += 'bsod' }
        }
    }
    # Nhan ket luan
    $score = $v.Mild + (2 * $v.Strong)
    if ($score -ge 4) {
        $v.LabelKey = 'm7.verdict.heavy'; $v.ChipKind = 'Bad'
    } elseif ($score -ge 2) {
        $v.LabelKey = 'm7.verdict.light'; $v.ChipKind = 'Warn'
    } elseif (($null -ne $v.AgeDays) -and ($v.AgeDays -lt 90)) {
        $v.LabelKey = 'm7.verdict.fresh'; $v.ChipKind = 'Ok'
    } else {
        $v.LabelKey = 'm7.verdict.good'; $v.ChipKind = 'Ok'
    }
    # Chi de xuat "cai lai Windows" khi >= 3 dau hieu khach quan CUNG LUC (spec M7)
    $v.ReinstallMet = ($v.ReinstallSigns.Count -ge 3)
    return $v
}

# ---------------------------------------------------------------------------
# UI
# ---------------------------------------------------------------------------
function New-WCM7Panel {
    param($State)
    $root = New-Object Windows.Controls.ScrollViewer
    $root.VerticalScrollBarVisibility = [Windows.Controls.ScrollBarVisibility]::Auto
    $hostPanel = New-WCVStack -Spacing 14
    $hostPanel.Margin = (New-Object Windows.Thickness(20))
    $root.Content = $hostPanel

    # --- Tieu de + nut Quet lai ---
    $top = New-Object Windows.Controls.DockPanel
    $top.LastChildFill = $true
    $rescan = New-WCButton -Text (T 'common.rescan') -OnClick { param($b) Invoke-WCM7Scan $State }.GetNewClosure()
    $rescan.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $rescan.Margin = (New-Object Windows.Thickness(0,0,0,10))
    [Windows.Controls.DockPanel]::SetDock($rescan, [Windows.Dock]::Right)
    $top.Children.Add($rescan) | Out-Null
    $leftStack = New-WCVStack -Spacing 6
    $titleRow = New-WCHStack
    $titleRow.Children.Add((New-WCHeading (T 'm7.title'))) | Out-Null
    $betaChip = New-WCChip -Text (T 'common.beta') -Kind 'Warn'
    $betaChip.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $titleRow.Children.Add($betaChip) | Out-Null
    Add-WCChild $leftStack $titleRow
    Add-WCChild $leftStack (New-WCSubtitle (T 'm7.subtitle'))
    Add-WCChild $leftStack (New-WCTextBlock -Text (T 'm7.fact') -Size 12.5 -ColorKey 'WcSubtle' -Wrap)
    $top.Children.Add($leftStack) | Out-Null
    Add-WCChild $hostPanel $top

    # --- Tao cac section (du lieu ve dan, moi chi bao 1 section rieng) ---
    $defs = @(
        @{ Key = 'verdict';  Title = (T 'm7.verdict.title');  Sub = (T 'm7.verdict.subtitle') }
        @{ Key = 'age';      Title = (T 'm7.age.title');      Sub = (T 'm7.age.hint') }
        @{ Key = 'boot';     Title = (T 'm7.boot.title');     Sub = (T 'm7.boot.hint') }
        @{ Key = 'startup';  Title = (T 'm7.startup.title');  Sub = (T 'm7.startup.hint') }
        @{ Key = 'software'; Title = (T 'm7.software.title'); Sub = (T 'm7.software.hint') }
        @{ Key = 'residual'; Title = (T 'm7.residual.title'); Sub = (T 'm7.residual.hint') }
        @{ Key = 'games';    Title = (T 'm7.games.title');    Sub = (T 'm7.games.hint') }
        @{ Key = 'sys';      Title = (T 'm7.sys.title');      Sub = (T 'm7.sys.hint') }
        @{ Key = 'actions';  Title = (T 'm7.actions.title');  Sub = (T 'm7.actions.hint') }
    )
    foreach ($def in $defs) {
        $sec = New-WCSection -Title $def['Title'] -Subtitle $def['Sub']
        $State['Sections'][$def['Key']] = $sec
        Add-WCChild $hostPanel $sec['Root']
    }
    # Trang thai ban dau: spinner cho cac section du lieu, actions cho text cho
    foreach ($k in @('verdict','age','boot','startup','software','residual','games','sys')) {
        Set-WCM7SectionLoading -State $State -Key $k
    }
    Add-WCChild $State['Sections']['actions']['Body'] (New-WCTextBlock -Text (T 'm7.actions.waiting') -ColorKey 'WcSubtle' -Wrap)
    return $root
}

function Set-WCM7SectionLoading {
    # Dat 1 section ve trang thai "dang tai" (spinner); section ket luan
    # hien chu dac biet "dang thu thap bang chung"
    param($State, [string]$Key)
    $sec = $State['Sections'][$Key]
    if (-not $sec) { return }
    $sec['Body'].Children.Clear()
    $spinner = New-WCSpinner
    if ($Key -eq 'verdict') { $spinner = New-WCSpinner -Text (T 'm7.verdict.waiting') }
    Add-WCChild $sec['Body'] $spinner
}

function Invoke-WCM7Scan {
    # Quet toan bo 7 nguon - moi phan 1 task nen rieng, ve dan tung section
    param($State)
    $ids = @('m7.age','m7.boot','m7.startup','m7.software','m7.residual','m7.games','m7.sys')
    foreach ($id in $ids) {
        if (Test-WCTaskRunning -Id $id) {
            Show-WCToast (T 'common.running' @((T 'm7.title'))) 'Info'
            return
        }
    }
    $State['Data'] = @{}
    $State['Ready'] = @{}
    foreach ($k in @('verdict','age','boot','startup','software','residual','games','sys')) {
        Set-WCM7SectionLoading -State $State -Key $k
    }
    $State['Sections']['actions']['Body'].Children.Clear()
    Add-WCChild $State['Sections']['actions']['Body'] (New-WCTextBlock -Text (T 'm7.actions.waiting') -ColorKey 'WcSubtle' -Wrap)
    Invoke-WCM7ScanAge $State
    Invoke-WCM7ScanBoot $State
    Invoke-WCM7ScanStartup $State
    Invoke-WCM7ScanSoftware $State
    Invoke-WCM7ScanResidual $State
    Invoke-WCM7ScanGames $State
    Invoke-WCM7ScanSys $State
}

function Invoke-WCM7ScanAge {
    param($State)
    Set-WCM7SectionLoading -State $State -Key 'age'
    Start-WCTask -Id 'm7.age' -Title (T 'm7.title') -Worker {
        param($ctx, $s)
        try { return (Get-WCWindowsInstallAge) } catch { return @{ Error = ([string]$_.Exception.Message) } }
    } -Done {
        param($result)
        $State['Data']['age'] = $result
        $State['Ready']['age'] = $true
        Update-WCM7Age $State $result
        Update-WCM7Verdict $State
    }.GetNewClosure() | Out-Null
}

function Invoke-WCM7ScanBoot {
    param($State)
    Set-WCM7SectionLoading -State $State -Key 'boot'
    Start-WCTask -Id 'm7.boot' -Title (T 'm7.title') -Worker {
        param($ctx, $s)
        try { return (Get-WCBootTrend) } catch { return @{ Error = ([string]$_.Exception.Message) } }
    } -Done {
        param($result)
        $State['Data']['boot'] = $result
        $State['Ready']['boot'] = $true
        Update-WCM7Boot $State $result
        Update-WCM7Verdict $State
    }.GetNewClosure() | Out-Null
}

function Invoke-WCM7ScanStartup {
    param($State)
    Set-WCM7SectionLoading -State $State -Key 'startup'
    Start-WCTask -Id 'm7.startup' -Title (T 'm7.title') -Worker {
        param($ctx, $s)
        try { return (Get-WCStartupEntries) } catch { return @{ Error = ([string]$_.Exception.Message) } }
    } -Done {
        param($result)
        $State['Data']['startup'] = $result
        $State['Ready']['startup'] = $true
        Update-WCM7Startup $State $result
        Update-WCM7Verdict $State
    }.GetNewClosure() | Out-Null
}

function Invoke-WCM7ScanSoftware {
    param($State)
    Set-WCM7SectionLoading -State $State -Key 'software'
    Start-WCTask -Id 'm7.software' -Title (T 'm7.title') -Worker {
        param($ctx, $s)
        try {
            $sw = Get-WCInstalledSoftware
            $sw['Bloat'] = @(Get-WCOemBloatCandidates -Apps $sw['Apps'])
            return $sw
        } catch { return @{ Error = ([string]$_.Exception.Message) } }
    } -Done {
        param($result)
        $State['Data']['software'] = $result
        $State['Ready']['software'] = $true
        Update-WCM7Software $State $result
        # Ve lai muc Tan du de hien "Uninstall mo coi" (du lieu tu khoa Uninstall)
        if ($State['Ready'].ContainsKey('residual') -and $State['Data'].ContainsKey('residual')) {
            Update-WCM7Residual $State $State['Data']['residual']
        }
        Update-WCM7Verdict $State
    }.GetNewClosure() | Out-Null
}

function Invoke-WCM7ScanResidual {
    param($State)
    Set-WCM7SectionLoading -State $State -Key 'residual'
    Start-WCTask -Id 'm7.residual' -Title (T 'm7.title') -Worker {
        param($ctx, $s)
        try { return (Get-WCResidualCandidates) } catch { return @{ Error = ([string]$_.Exception.Message) } }
    } -Done {
        param($result)
        $State['Data']['residual'] = $result
        $State['Ready']['residual'] = $true
        Update-WCM7Residual $State $result
        Update-WCM7Verdict $State
    }.GetNewClosure() | Out-Null
}

function Invoke-WCM7ScanGames {
    param($State)
    Set-WCM7SectionLoading -State $State -Key 'games'
    Start-WCTask -Id 'm7.games' -Title (T 'm7.title') -Worker {
        param($ctx, $s)
        try { return (Get-WCGamesInfo) } catch { return @{ Error = ([string]$_.Exception.Message) } }
    } -Done {
        param($result)
        $State['Data']['games'] = $result
        $State['Ready']['games'] = $true
        Update-WCM7Games $State $result
        Update-WCM7Verdict $State
    }.GetNewClosure() | Out-Null
}

function Invoke-WCM7ScanSys {
    param($State)
    Set-WCM7SectionLoading -State $State -Key 'sys'
    Start-WCTask -Id 'm7.sys' -Title (T 'm7.title') -Worker {
        param($ctx, $s)
        try { return (Get-WCSystemAccumulation) } catch { return @{ Error = ([string]$_.Exception.Message) } }
    } -Done {
        param($result)
        $State['Data']['sys'] = $result
        $State['Ready']['sys'] = $true
        Update-WCM7Sys $State $result
        Update-WCM7Verdict $State
    }.GetNewClosure() | Out-Null
}

function Update-WCM7Age {
    param($State, $Data)
    $body = $State['Sections']['age']['Body']
    $body.Children.Clear()
    if ($null -eq $Data) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.age.unknown') -ColorKey 'WcSubtle' -Wrap)
        return
    }
    if ($Data['Error']) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.nodata.reason' @([string]$Data['Error'])) -ColorKey 'WcSubtle' -Wrap)
        return
    }
    $d = $Data['InstallDate']
    $ageTxt = T 'fmt.days' @([string]$Data['AgeDays'])
    $dateTxt = ''
    try { $dateTxt = $d.ToString('yyyy-MM-dd') } catch { $dateTxt = '?' }
    Add-WCChild $body (New-WCTextBlock -Text (T 'm7.age.value' @($dateTxt, $ageTxt)) -Size 13.5 -Weight 'SemiBold' -Wrap)
    Add-WCChild $body (New-WCTextBlock -Text (T 'm7.age.note') -Size 12 -ColorKey 'WcSubtle' -Wrap)
}

function Update-WCM7Boot {
    param($State, $Data)
    $body = $State['Sections']['boot']['Body']
    $body.Children.Clear()
    if ($null -eq $Data) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.boot.nodata') -ColorKey 'WcSubtle' -Wrap)
        return
    }
    if ($Data['Error']) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.boot.nodata') -ColorKey 'WcSubtle' -Wrap)
        return
    }
    $buckets = $Data['Buckets']
    $b30 = $buckets['30']; $b90 = $buckets['90']; $b180 = $buckets['180']
    $hasData = (($b30.Count -gt 0) -or ($b90.Count -gt 0) -or ($b180.Count -gt 0))
    if (-not $hasData) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.boot.nodata') -ColorKey 'WcSubtle' -Wrap)
        return
    }
    # Text-bar: moi bucket 1 dong, do dai thanh ~ trung vi / max toan bo
    $scaleMax = [double]0
    foreach ($k in @('30','90','180')) {
        $b = $buckets[$k]
        if ($null -ne $b['MaxMs']) { if ([double]$b['MaxMs'] -gt $scaleMax) { $scaleMax = [double]$b['MaxMs'] } }
    }
    $lines = @()
    foreach ($k in @('30','90','180')) {
        $b = $buckets[$k]
        $barLen = 0
        if (($null -ne $b['MedianMs']) -and ($scaleMax -gt 0)) {
            $barLen = [int][math]::Ceiling(([double]$b['MedianMs'] / $scaleMax) * 36.0)
        }
        $bar = ''
        for ($i = 0; $i -lt $barLen; $i++) { $bar += [char]0x2588 }
        $medTxt = '-'
        if ($null -ne $b['MedianMs']) { $medTxt = ('{0:N0} ms' -f [double]$b['MedianMs']) }
        $lines += ('{0,-20} {1}  {2}' -f (T ('m7.boot.bucket.' + $k)), $bar, $medTxt)
    }
    $barTb = New-WCTextBlock -Text ([string]::Join("`n", $lines)) -Size 12.5
    $barTb.FontFamily = New-Object Windows.Media.FontFamily('Consolas')
    Add-WCChild $body $barTb
    # Bang so
    $table = New-WCTable -Columns @(
        @{ Header = (T 'm7.boot.col.bucket'); Prop = 'C0'; Width = 170 }
        @{ Header = (T 'm7.boot.col.count');  Prop = 'C1'; Width = 110 }
        @{ Header = (T 'm7.boot.col.median'); Prop = 'C2'; Width = 120 }
        @{ Header = (T 'm7.boot.col.max');    Prop = 'C3'; Width = 120 }
    )
    foreach ($k in @('30','90','180')) {
        $b = $buckets[$k]
        $row = [PSCustomObject]@{
            C0 = (T ('m7.boot.bucket.' + $k))
            C1 = [string]$b['Count']
            C2 = ($(if ($null -ne $b['MedianMs']) { '{0:N0}' -f [double]$b['MedianMs'] } else { '-' }))
            C3 = ($(if ($null -ne $b['MaxMs']) { '{0:N0}' -f [double]$b['MaxMs'] } else { '-' }))
        }
        $table.Items.Add($row) | Out-Null
    }
    Add-WCChild $body $table
    # So sanh trung vi 30 ngay vs 90 ngay
    if ($Data['Enough'] -and ($null -ne $Data['DeltaPct'])) {
        $pct = [double]$Data['DeltaPct']
        $m30 = [double]$b30['MedianMs']; $m90 = [double]$b90['MedianMs']
        $cmpText = ''
        if ($pct -gt 5) { $cmpText = (T 'm7.boot.up' @([string][math]::Abs($pct), ('{0:N0}' -f $m90), ('{0:N0}' -f $m30))) }
        elseif ($pct -lt -5) { $cmpText = (T 'm7.boot.down' @([string][math]::Abs($pct), ('{0:N0}' -f $m90), ('{0:N0}' -f $m30))) }
        else { $cmpText = (T 'm7.boot.flat' @([string]$pct)) }
        Add-WCChild $body (New-WCTextBlock -Text $cmpText -Size 13 -Wrap)
    } else {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.boot.compare.nodata') -Size 12.5 -ColorKey 'WcSubtle' -Wrap)
    }
    # Sparkline nhung lan khoi dong gan day (cu -> moi)
    $boots = @($Data['Boots'] | Sort-Object -Property { $_['Time'] })
    if ($boots.Count -gt 1) {
        $recent = $boots
        if ($boots.Count -gt 24) { $recent = @($boots[($boots.Count - 24)..($boots.Count - 1)]) }
        $mx = [double]0
        foreach ($b in $recent) { if ([double]$b['TotalMs'] -gt $mx) { $mx = [double]$b['TotalMs'] } }
        if ($mx -gt 0) {
            $spark = ''
            foreach ($b in $recent) {
                $n = [int][math]::Ceiling(([double]$b['TotalMs'] / $mx) * 9.0)
                if ($n -lt 1) { $n = 1 }
                $spark += ([string]([char]0x2588) * $n) + ' '
            }
            Add-WCChild $body (New-WCTextBlock -Text (T 'm7.boot.recent') -Size 11.5 -ColorKey 'WcSubtle')
            $sparkTb = New-WCTextBlock -Text $spark -Size 11.5 -Wrap
            $sparkTb.FontFamily = New-Object Windows.Media.FontFamily('Consolas')
            Add-WCChild $body $sparkTb
        }
    }
    Add-WCChild $body (New-WCTextBlock -Text ((T 'm7.boot.count' @([string]$Data['SampleCount']))) -Size 12 -ColorKey 'WcSubtle' -Wrap)
    Add-WCChild $body (New-WCTextBlock -Text (T 'm7.boot.source') -Size 11 -ColorKey 'WcSubtle' -Wrap)
}

function Update-WCM7Startup {
    param($State, $Data)
    $body = $State['Sections']['startup']['Body']
    $body.Children.Clear()
    if ($null -eq $Data -or $Data['Error']) {
        $reason = ''
        if ($Data -and $Data['Error']) { $reason = [string]$Data['Error'] }
        $txt = (T 'common.nodata')
        if ($reason) { $txt = (T 'm7.nodata.reason' @($reason)) }
        Add-WCChild $body (New-WCTextBlock -Text $txt -ColorKey 'WcSubtle' -Wrap)
        return
    }
    $entries = @($Data['Entries'])
    $msCount = @($entries | Where-Object { $_['IsMicrosoft'] }).Count
    Add-WCChild $body (New-WCTextBlock -Text (T 'm7.startup.count' @([string]$Data['NonMsCount'], [string]$Data['NonMsEnabledCount'])) -Size 13.5 -Weight 'SemiBold' -Wrap)
    if ($msCount -gt 0) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.startup.mscount' @([string]$msCount)) -Size 12 -ColorKey 'WcSubtle' -Wrap)
    }
    Add-WCChild $body (New-WCTextBlock -Text (T 'm7.startup.decode.note') -Size 11 -ColorKey 'WcSubtle' -Wrap)
    if ($entries.Count -eq 0) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.startup.empty') -Size 12.5 -ColorKey 'WcSubtle' -Wrap)
    } else {
        # Danh sach tick: muc Run/StartupFolder (tat/bat duoc qua StartupApproved)
        $list = New-WCCheckList
        $State['StartupList'] = $list
        $sorted = @($entries | Sort-Object -Property { $(if ($_['IsMicrosoft']) { 1 } else { 0 }) }, { $_['Name'] })
        foreach ($e in $sorted) {
            $name = [string]$e['Name']
            if ($e['IsMicrosoft']) { $name = $name + ' (' + (T 'm7.startup.msbadge') + ')' }
            $cmd = [string]$e['Command']
            if ($cmd.Length -gt 70) { $cmd = $cmd.Substring(0, 67) + '...' }
            $chipKind = 'Ok'; $chipTxt = (T 'm7.startup.on')
            if ($e['State'] -eq 'Disabled') { $chipKind = 'Plain'; $chipTxt = (T 'm7.startup.off') }
            Add-WCCheckRow -List $list -Item $e -Checked:$false -TextColumns @($name, $cmd) -ChipText $chipTxt -ChipKind $chipKind
        }
        Add-WCChild $body $list
        $btnRow = New-WCHStack
        $offBtn = New-WCButton -Text (T 'm7.startup.toggle.off') -OnClick { param($b) Invoke-WCM7ToggleStartup $State $false }.GetNewClosure()
        $onBtn = New-WCButton -Text (T 'm7.startup.toggle.on') -OnClick { param($b) Invoke-WCM7ToggleStartup $State $true }.GetNewClosure()
        $btnRow.Children.Add($offBtn) | Out-Null
        $btnRow.Children.Add($onBtn) | Out-Null
        Add-WCChild $body $btnRow
    }
    # Tac vu + dich vu (chi liet ke - khong bat/tat qua StartupApproved)
    $tasks = @($Data['Tasks'])
    $services = @($Data['Services'])
    if (($tasks.Count -gt 0) -or ($services.Count -gt 0)) {
        $exp = New-WCExpander -Title (T 'm7.startup.tasks.title') -Summary (T 'm7.startup.tasks.summary' @([string]$tasks.Count, [string]$services.Count))
        $t = New-WCTable -Columns @(
            @{ Header = (T 'm7.startup.col.name');  Prop = 'C0'; Width = 300 }
            @{ Header = (T 'm7.startup.col.type');  Prop = 'C1'; Width = 90 }
            @{ Header = (T 'm7.startup.col.state'); Prop = 'C2'; Width = 110 }
        )
        $maxRows = 40; $added = 0
        foreach ($tk in $tasks) {
            if ($added -ge $maxRows) { break }
            $t.Items.Add([PSCustomObject]@{ C0 = ($tk['TaskPath'] + $tk['Name']); C1 = (T 'm7.startup.type.task'); C2 = [string]$tk['State'] }) | Out-Null
            $added++
        }
        foreach ($sv in $services) {
            if ($added -ge $maxRows) { break }
            $t.Items.Add([PSCustomObject]@{ C0 = $sv['DisplayName']; C1 = (T 'm7.startup.type.service'); C2 = [string]$sv['State'] }) | Out-Null
            $added++
        }
        Add-WCChild $exp['Body'] $t
        $total = $tasks.Count + $services.Count
        if ($total -gt $maxRows) {
            Add-WCChild $exp['Body'] (New-WCTextBlock -Text (T 'm7.startup.more' @([string]($total - $maxRows))) -Size 11.5 -ColorKey 'WcSubtle')
        }
        Add-WCChild $exp['Body'] (New-WCTextBlock -Text (T 'm7.startup.tasks.hint') -Size 11 -ColorKey 'WcSubtle' -Wrap)
        Add-WCChild $body $exp['Root']
    }
}

function Update-WCM7Software {
    param($State, $Data)
    $body = $State['Sections']['software']['Body']
    $body.Children.Clear()
    if ($null -eq $Data -or $Data['Error']) {
        $reason = ''
        if ($Data -and $Data['Error']) { $reason = [string]$Data['Error'] }
        $txt = (T 'common.nodata')
        if ($reason) { $txt = (T 'm7.nodata.reason' @($reason)) }
        Add-WCChild $body (New-WCTextBlock -Text $txt -ColorKey 'WcSubtle' -Wrap)
        return
    }
    Add-WCChild $body (New-WCTextBlock -Text (T 'm7.software.count' @([string]$Data['Total'])) -Size 13.5 -Weight 'SemiBold' -Wrap)
    # Ung vien OEM/bloatware - chi DE XUAT, nut Go mo trinh go chinh thuc
    $bloat = @($Data['Bloat'])
    Add-WCChild $body (New-WCTextBlock -Text (T 'm7.software.bloat.title') -Size 13 -Weight 'SemiBold')
    if ($bloat.Count -eq 0) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.software.bloat.empty') -Size 12.5 -ColorKey 'WcSubtle' -Wrap)
    } else {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.software.bloat.hint') -Size 11 -ColorKey 'WcSubtle' -Wrap)
        foreach ($item in $bloat) {
            Add-WCChild $body (New-WCM7SoftwareRow -Item $item)
        }
    }
}

function New-WCM7SoftwareRow {
    # 1 dong ung vien bloatware: ten + nha phat hanh + ngay cai + nut "Go"
    param($Item)
    $row = New-Object Windows.Controls.Border
    $row.Style = (Get-WCControlStyles)['WcListItem']
    $dock = New-Object Windows.Controls.DockPanel
    $dock.LastChildFill = $true
    $btn = New-WCButton -Text (T 'm7.software.uninstall') -Small -OnClick { param($b) Invoke-WCM7Uninstall $Item }.GetNewClosure()
    $btn.VerticalAlignment = [Windows.VerticalAlignment]::Center
    [Windows.Controls.DockPanel]::SetDock($btn, [Windows.Dock]::Right)
    $dock.Children.Add($btn) | Out-Null
    $stack = New-WCVStack -Spacing 2
    Add-WCChild $stack (New-WCTextBlock -Text ([string]$Item['DisplayName']) -Size 13 -Weight 'SemiBold' -Wrap)
    $meta = [string]$Item['Publisher']
    if (-not [string]::IsNullOrEmpty([string]$Item['InstallDateText'])) {
        $meta = $meta + '  ·  ' + (T 'm7.software.installedon' @([string]$Item['InstallDateText']))
    }
    Add-WCChild $stack (New-WCTextBlock -Text $meta -Size 11.5 -ColorKey 'WcSubtle' -Wrap)
    $dock.Child = $stack
    $row.Child = $dock
    return $row
}

function Update-WCM7Residual {
    param($State, $Data)
    $body = $State['Sections']['residual']['Body']
    $body.Children.Clear()
    if ($null -eq $Data -or $Data['Error']) {
        $reason = ''
        if ($Data -and $Data['Error']) { $reason = [string]$Data['Error'] }
        $txt = (T 'common.nodata')
        if ($reason) { $txt = (T 'm7.nodata.reason' @($reason)) }
        Add-WCChild $body (New-WCTextBlock -Text $txt -ColorKey 'WcSubtle' -Wrap)
        return
    }
    $folders = @($Data['Folders'])
    if ($folders.Count -eq 0) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.residual.empty') -Size 12.5 -ColorKey 'WcSubtle' -Wrap)
    } else {
        # Mac dinh KHONG tick (spec M7 - de bao nham)
        $list = New-WCCheckList
        $State['ResidualList'] = $list
        $maxRows = 25
        $idx = 0
        foreach ($f in $folders) {
            if ($idx -ge $maxRows) { break }
            Add-WCCheckRow -List $list -Item $f -Checked:$false -TextColumns @(
                ([string]$f['Name']),
                ([string]$f['Root']),
                (ConvertTo-WCHumanSize ([long]$f['SizeBytes']))
            )
            $idx++
        }
        Add-WCChild $body $list
        if ($folders.Count -gt $maxRows) {
            Add-WCChild $body (New-WCTextBlock -Text (T 'm7.residual.more' @([string]($folders.Count - $maxRows))) -Size 11.5 -ColorKey 'WcSubtle')
        }
        $btnRow = New-WCHStack
        $openBtn = New-WCButton -Text (T 'm7.residual.open') -OnClick { param($b) Invoke-WCM7OpenResidualSelected $State }.GetNewClosure()
        $delBtn = New-WCButton -Text (T 'm7.residual.delete') -Kind Danger -OnClick { param($b) Invoke-WCM7DeleteResidual $State }.GetNewClosure()
        $btnRow.Children.Add($openBtn) | Out-Null
        $btnRow.Children.Add($delBtn) | Out-Null
        Add-WCChild $body $btnRow
    }
    # Muc Uninstall mo coi trong registry (key khong DisplayName) - CHI BAO CAO
    # (du lieu lay tu task phan mem; ve lai khi ca hai phan deu ve)
    $swData = $null
    if ($State['Data'].ContainsKey('software')) { $swData = $State['Data']['software'] }
    $orphans = @()
    if ($swData -and $swData['OrphanKeys']) { $orphans = @($swData['OrphanKeys']) }
    if ($orphans.Count -gt 0) {
        $exp = New-WCExpander -Title (T 'm7.residual.orphan.title') -Summary ([string]$orphans.Count)
        $maxOrphan = 20
        $i = 0
        foreach ($o in $orphans) {
            if ($i -ge $maxOrphan) { break }
            Add-WCChild $exp['Body'] (New-WCTextBlock -Text ([string]$o['KeyName']) -Size 11.5 -ColorKey 'WcSubtle')
            $i++
        }
        Add-WCChild $exp['Body'] (New-WCTextBlock -Text (T 'm7.residual.orphan.hint') -Size 11 -ColorKey 'WcSubtle' -Wrap)
        Add-WCChild $body $exp['Root']
    }
}

function Update-WCM7Games {
    param($State, $Data)
    $body = $State['Sections']['games']['Body']
    $body.Children.Clear()
    if ($null -eq $Data -or $Data['Error']) {
        $reason = ''
        if ($Data -and $Data['Error']) { $reason = [string]$Data['Error'] }
        $txt = (T 'common.nodata')
        if ($reason) { $txt = (T 'm7.nodata.reason' @($reason)) }
        Add-WCChild $body (New-WCTextBlock -Text $txt -ColorKey 'WcSubtle' -Wrap)
        return
    }
    $games = @($Data['Games'])
    $steamCount = @($games | Where-Object { $_['Source'] -eq 'Steam' }).Count
    # Trang thai phat hien launcher (khong cai -> khong loi)
    if ($Data['SteamInstalled']) {
        $libs = @(Get-WCSteamLibraryPaths -SteamRoot $Data['SteamRoot'])
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.games.steam.ok' @([string]$libs.Count, [string]$steamCount)) -Size 12.5 -Wrap)
    } else {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.games.steam.none') -Size 12.5 -ColorKey 'WcSubtle' -Wrap)
    }
    if ($Data['EpicInstalled']) {
        $epicCount = @($games | Where-Object { $_['Source'] -eq 'Epic' }).Count
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.games.epic.ok' @([string]$epicCount)) -Size 12.5 -Wrap)
    } else {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.games.epic.none') -Size 12.5 -ColorKey 'WcSubtle' -Wrap)
    }
    if ($games.Count -eq 0) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.games.empty') -Size 12.5 -ColorKey 'WcSubtle' -Wrap)
    } else {
        $t = New-WCTable -Columns @(
            @{ Header = (T 'm7.games.col.name');  Prop = 'C0'; Width = 240 }
            @{ Header = (T 'm7.games.col.source'); Prop = 'C1'; Width = 110 }
            @{ Header = (T 'm7.games.col.size');  Prop = 'C2'; Width = 100 }
            @{ Header = (T 'm7.games.col.last');  Prop = 'C3'; Width = 110 }
            @{ Header = (T 'm7.games.col.drive'); Prop = 'C4'; Width = 80 }
        )
        $maxRows = 40; $added = 0
        $sorted = @($games | Sort-Object -Property { [long]$_['SizeBytes'] } -Descending)
        foreach ($g in $sorted) {
            if ($added -ge $maxRows) { break }
            $src = [string]$g['Source']
            if ($src -eq 'Other') { $src = (T 'm7.games.source.other') }
            $lastTxt = (T 'm7.games.last.unknown')
            $lp = $g['LastPlayed']
            if (($null -ne $lp) -and ($lp -is [DateTime])) { $lastTxt = $lp.ToString('yyyy-MM-dd') }
            $sizeTxt = '-'
            if ([long]$g['SizeBytes'] -gt 0) { $sizeTxt = (ConvertTo-WCHumanSize ([long]$g['SizeBytes'])) }
            $driveTxt = [string]$g['Drive']
            if ([string]::IsNullOrEmpty($driveTxt)) { $driveTxt = '-' }
            $t.Items.Add([PSCustomObject]@{
                C0 = [string]$g['Name']; C1 = $src; C2 = $sizeTxt; C3 = $lastTxt; C4 = $driveTxt
            }) | Out-Null
            $added++
        }
        Add-WCChild $body $t
        if ($games.Count -gt $maxRows) {
            Add-WCChild $body (New-WCTextBlock -Text (T 'm7.games.more' @([string]($games.Count - $maxRows))) -Size 11.5 -ColorKey 'WcSubtle')
        }
    }
    # Cac goi y (chi hien khi co du lieu tuong ung - khong doa)
    if ($Data['OldGamesCount'] -gt 0) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.games.old.total' @([string]$Data['OldGamesCount'], (ConvertTo-WCHumanSize ([long]$Data['OldGamesBytes'])))) -Size 12.5 -Wrap)
    }
    $hdd = @($Data['HddGames'])
    if ($hdd.Count -gt 0) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.games.hdd' @([string]::Join(', ', $hdd))) -Size 12.5 -Wrap)
    }
    $launchers = @($Data['LauncherInStartup'])
    if ($launchers.Count -gt 0) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.games.launcher' @([string]::Join(', ', $launchers))) -Size 12.5 -Wrap)
    }
    if (($null -ne $Data['ShaderD3DBytes']) -or ($null -ne $Data['ShaderGlBytes'])) {
        $d3dTxt = (T 'common.na'); $glTxt = (T 'common.na')
        if ($null -ne $Data['ShaderD3DBytes']) { $d3dTxt = (ConvertTo-WCHumanSize ([long]$Data['ShaderD3DBytes'])) }
        if ($null -ne $Data['ShaderGlBytes']) { $glTxt = (ConvertTo-WCHumanSize ([long]$Data['ShaderGlBytes'])) }
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.games.shader' @($d3dTxt, $glTxt)) -Size 12.5 -Wrap)
    }
    if (($null -ne $Data['GpuDriverDays']) -and (-not [string]::IsNullOrEmpty([string]$Data['GpuName']))) {
        $gpuTxt = $null
        if ([int]$Data['GpuDriverDays'] -gt 365) {
            $gpuTxt = (T 'm7.games.gpu.old' @([string]$Data['GpuName'], [string]$Data['GpuDriverDays']))
        } else {
            $gpuTxt = (T 'm7.games.gpu.ok' @([string]$Data['GpuName'], [string]$Data['GpuDriverDays']))
        }
        Add-WCChild $body (New-WCTextBlock -Text $gpuTxt -Size 12.5 -Wrap)
    }
    # Nut mo launcher (go/chuyen game CHI qua launcher)
    if ($Data['SteamInstalled'] -or $Data['EpicInstalled']) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.games.uninstall.note') -Size 11 -ColorKey 'WcSubtle' -Wrap)
        $btnRow = New-WCHStack
        if ($Data['SteamInstalled']) {
            $steamRootRef = [string]$Data['SteamRoot']
            $btnRow.Children.Add((New-WCButton -Text (T 'm7.games.open.steam') -OnClick { param($b) Invoke-WCM7OpenLauncher -Kind 'steam' -FallbackExe (Join-Path $steamRootRef 'steam.exe') }.GetNewClosure())) | Out-Null
        }
        if ($Data['EpicInstalled']) {
            $btnRow.Children.Add((New-WCButton -Text (T 'm7.games.open.epic') -OnClick { param($b) Invoke-WCM7OpenLauncher -Kind 'epic' -FallbackExe '' }.GetNewClosure())) | Out-Null
        }
        Add-WCChild $body $btnRow
    }
}

function Update-WCM7Sys {
    param($State, $Data)
    $body = $State['Sections']['sys']['Body']
    $body.Children.Clear()
    if ($null -eq $Data -or $Data['Error']) {
        $reason = ''
        if ($Data -and $Data['Error']) { $reason = [string]$Data['Error'] }
        $txt = (T 'common.nodata')
        if ($reason) { $txt = (T 'm7.nodata.reason' @($reason)) }
        Add-WCChild $body (New-WCTextBlock -Text $txt -ColorKey 'WcSubtle' -Wrap)
        return
    }
    # Co cho khoi dong lai
    $flags = @($Data['PendingFlags'])
    if ($flags.Count -eq 0) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.sys.pending.ok') -Size 12.5 -Wrap)
    } else {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.sys.pending.list' @([string]::Join(', ', $flags))) -Size 12.5 -Wrap)
    }
    # Lan bao tri tu dong gan nhat
    if ($null -ne $Data['MaintenanceLastRun']) {
        $dTxt = ''
        try { $dTxt = ([datetime]$Data['MaintenanceLastRun']).ToString('yyyy-MM-dd HH:mm') } catch { $dTxt = '?' }
        $daysTxt = T 'fmt.days' @([string]$Data['MaintenanceDays'])
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.sys.maintenance.label' @($dTxt, $daysTxt)) -Size 12.5 -Wrap)
    } else {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.sys.maintenance.none') -Size 12.5 -Wrap)
    }
    # O he thong
    if ($null -ne $Data['DiskFreePct']) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.sys.disk' @([string]$Data['DiskFreePct'])) -Size 12.5 -Wrap)
    }
    # BSOD 90 ngay
    if ($null -eq $Data['BsodCount90']) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.sys.bsod.nodata') -Size 12.5 -Wrap)
    } elseif ([int]$Data['BsodCount90'] -eq 0) {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.sys.bsod.none') -Size 12.5 -Wrap)
    } else {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.sys.bsod.some' @([string]$Data['BsodCount90'])) -Size 12.5 -Wrap)
    }
}

function Update-WCM7Verdict {
    # Chi render ket luan khi CA 7 phan da ve (moi phan tu them goi ham nay)
    param($State)
    foreach ($k in @('age','boot','startup','software','residual','games','sys')) {
        if (-not $State['Ready'].ContainsKey($k)) { return }
    }
    $d = $State['Data']
    $v = Get-WCAgingVerdict -Age $d['age'] -Boot $d['boot'] -Startup $d['startup'] `
        -Software $d['software'] -Residual $d['residual'] -Games $d['games'] -Sys $d['sys']
    $body = $State['Sections']['verdict']['Body']
    $body.Children.Clear()
    # Nhan ket luan (chip + 1 cau)
    $chip = New-WCChip -Text (T $v['LabelKey']) -Kind ([string]$v['ChipKind'])
    Add-WCChild $body $chip
    $sum = ''
    $ageDaysTxt = (T 'common.unknown')
    if ($null -ne $v['AgeDays']) { $ageDaysTxt = (T 'fmt.days' @([string]$v['AgeDays'])) }
    switch ($v['LabelKey']) {
        'm7.verdict.fresh' { $sum = (T 'm7.verdict.fresh.sum' @($ageDaysTxt)) }
        'm7.verdict.good'  { $sum = (T 'm7.verdict.good.sum' @($ageDaysTxt)) }
        'm7.verdict.light' { $sum = (T 'm7.verdict.light.sum') }
        'm7.verdict.heavy' { $sum = (T 'm7.verdict.heavy.sum' @([string]$v['Strong'], [string]$v['Mild'])) }
    }
    Add-WCChild $body (New-WCTextBlock -Text $sum -Size 13.5 -Wrap)
    # Bang bang chung: chi bao | so lieu | nguon | y nghia
    Add-WCChild $body (New-WCTextBlock -Text (T 'm7.verdict.evidence') -Size 13 -Weight 'SemiBold')
    $table = New-WCTable -Columns @(
        @{ Header = (T 'm7.col.indicator'); Prop = 'C0'; Width = 180 }
        @{ Header = (T 'm7.col.value');     Prop = 'C1'; Width = 250 }
        @{ Header = (T 'm7.col.source');    Prop = 'C2'; Width = 220 }
        @{ Header = (T 'm7.col.meaning');   Prop = 'C3'; Width = 250 }
    )
    # --- hang: tuoi ---
    $ageVal = (T 'common.nodata')
    if ($null -ne $v['AgeDays']) { $ageVal = (T 'fmt.days' @([string]$v['AgeDays'])) }
    $table.Items.Add([PSCustomObject]@{ C0 = (T 'm7.ev.age'); C1 = $ageVal; C2 = (T 'm7.src.registry'); C3 = (T 'm7.ev.age.mean') }) | Out-Null
    # --- hang: boot ---
    $bootVal = (T 'common.nodata')
    $bootMean = (T 'm7.ev.boot.mean.ok')
    if ($v['BootEnough']) {
        $pct = [double]$v['BootDeltaPct']
        if ($pct -gt 5) { $bootVal = (T 'm7.ev.boot.up' @([string]$pct)) }
        elseif ($pct -lt -5) { $bootVal = (T 'm7.ev.boot.down' @([string][math]::Abs($pct))) }
        else { $bootVal = (T 'm7.ev.boot.flat' @([string]$pct)) }
        if ($pct -gt 25) { $bootMean = (T 'm7.ev.boot.mean.sign') }
    }
    $table.Items.Add([PSCustomObject]@{ C0 = (T 'm7.ev.boot'); C1 = $bootVal; C2 = (T 'm7.src.event100'); C3 = $bootMean }) | Out-Null
    # --- hang: startup ---
    $stMean = (T 'm7.ev.startup.mean.ok')
    if ($v['StartupNonMs'] -gt 10) { $stMean = (T 'm7.ev.startup.mean.sign') }
    $table.Items.Add([PSCustomObject]@{
        C0 = (T 'm7.ev.startup')
        C1 = (T 'm7.ev.startup.value' @([string]$v['StartupNonMs'], [string]$v['StartupEnabled']))
        C2 = (T 'm7.src.runkeys'); C3 = $stMean }) | Out-Null
    # --- hang: bloatware ---
    $table.Items.Add([PSCustomObject]@{ C0 = (T 'm7.ev.bloat'); C1 = [string]$v['BloatCount']; C2 = (T 'm7.src.uninstall'); C3 = (T 'm7.ev.bloat.mean') }) | Out-Null
    # --- hang: tan du ---
    $table.Items.Add([PSCustomObject]@{
        C0 = (T 'm7.ev.residual')
        C1 = (T 'm7.ev.residual.value' @([string]$v['ResidualCount'], (ConvertTo-WCHumanSize ([long]$v['ResidualBytes']))))
        C2 = (T 'm7.src.folders'); C3 = (T 'm7.ev.residual.mean') }) | Out-Null
    # --- hang: game lau khong choi ---
    $table.Items.Add([PSCustomObject]@{
        C0 = (T 'm7.ev.games')
        C1 = (T 'm7.ev.games.value' @([string]$v['OldGamesCount'], (ConvertTo-WCHumanSize ([long]$v['OldGamesBytes']))))
        C2 = (T 'm7.src.manifest'); C3 = (T 'm7.ev.games.mean') }) | Out-Null
    # --- hang: o he thong ---
    if ($null -ne $v['DiskFreePct']) {
        $diskMean = (T 'm7.ev.disk.mean.ok')
        if ([double]$v['DiskFreePct'] -lt 20) { $diskMean = (T 'm7.ev.disk.mean.low') }
        $table.Items.Add([PSCustomObject]@{
            C0 = (T 'm7.ev.disk'); C1 = ('{0}%' -f [string]$v['DiskFreePct'])
            C2 = (T 'm7.src.logicaldisk'); C3 = $diskMean }) | Out-Null
    }
    # --- hang: co cho khoi dong lai ---
    $table.Items.Add([PSCustomObject]@{ C0 = (T 'm7.ev.pending'); C1 = [string]$v['PendingCount']; C2 = (T 'm7.src.rebootkeys'); C3 = (T 'm7.ev.pending.mean') }) | Out-Null
    # --- hang: BSOD ---
    if ($null -ne $v['Bsod90']) {
        $table.Items.Add([PSCustomObject]@{ C0 = (T 'm7.ev.bsod'); C1 = [string]$v['Bsod90']; C2 = (T 'm7.src.system1001'); C3 = (T 'm7.ev.bsod.mean') }) | Out-Null
    }
    Add-WCChild $body $table
    # Render luon huong xu ly
    Update-WCM7Actions -State $State -Verdict $v
}

function New-WCM7ActionCard {
    # The 1 huong xu ly: tieu de + chip muc rui ro + mo ta (tra @{Root;Body})
    param([string]$Title, [string]$Desc, [string]$Risk)
    $risk = Get-WCRiskInfo -Risk $Risk
    $row = New-Object Windows.Controls.Border
    $row.CornerRadius = (New-Object Windows.CornerRadius(8))
    $row.BorderThickness = (New-Object Windows.Thickness(1))
    $row.Padding = (New-Object Windows.Thickness(12))
    $row.Margin = (New-Object Windows.Thickness(0,4,0,4))
    $row.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'WcCardBg2')
    $row.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'WcBorder')
    $inner = New-WCVStack -Spacing 4
    $top = New-WCHStack
    $t = New-WCTextBlock -Text $Title -Size 13.5 -Weight 'SemiBold'
    $t.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $top.Children.Add($t) | Out-Null
    $chip = New-WCChip -Text $risk.Text -Kind ($risk.Brush.Replace('Wc', ''))
    $chip.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $top.Children.Add($chip) | Out-Null
    Add-WCChild $inner $top
    Add-WCChild $inner (New-WCTextBlock -Text $Desc -Size 12 -ColorKey 'WcSubtle' -Wrap)
    $row.Child = $inner
    return @{ Root = $row; Body = $inner }
}

function Update-WCM7Actions {
    # 3 huong xu ly xep theo rui ro tang dan (spec M7);
    # huong 3 chi hien khi >= 3 dau hieu khach quan cung luc.
    param($State, $Verdict)
    $body = $State['Sections']['actions']['Body']
    $body.Children.Clear()
    # Huong 1: KHUYEN NGH
    $c1 = New-WCM7ActionCard -Title (T 'm7.actions.1.title') -Desc (T 'm7.actions.1.desc') -Risk 'Recommended'
    $btnM2 = New-WCButton -Text (T 'm7.actions.1.btn') -Kind Primary -Small -OnClick { param($b) Invoke-WCShowNav 'm2' }.GetNewClosure()
    Add-WCChild $c1['Body'] $btnM2
    Add-WCChild $body $c1['Root']
    # Huong 2: NANG CAO
    $c2 = New-WCM7ActionCard -Title (T 'm7.actions.2.title') -Desc (T 'm7.actions.2.desc') -Risk 'Advanced'
    Add-WCChild $body $c2['Root']
    # Huong 3: RUI RO - chi de xuat khi du dau hieu
    if ($Verdict['ReinstallMet']) {
        $c3 = New-WCM7ActionCard -Title (T 'm7.actions.3.title') -Desc (T 'm7.actions.3.desc') -Risk 'Risky'
        Add-WCChild $c3['Body'] (New-WCTextBlock -Text (T 'm7.actions.3.criteria') -Size 12.5 -Weight 'SemiBold' -Wrap)
        foreach ($sign in @($Verdict['ReinstallSigns'])) {
            $txt = ''
            switch ($sign) {
                'boot'    { $txt = (T 'm7.actions.3.sign.boot') }
                'startup' { $txt = (T 'm7.actions.3.sign.startup') }
                'disk'    { $txt = (T 'm7.actions.3.sign.disk') }
                'bsod'    { $txt = (T 'm7.actions.3.sign.bsod') }
            }
            if ($txt) { Add-WCChild $c3['Body'] (New-WCTextBlock -Text $txt -Size 12 -Wrap) }
        }
        Add-WCChild $c3['Body'] (New-WCTextBlock -Text (T 'm7.actions.3.checklist.title') -Size 12.5 -Weight 'SemiBold' -Wrap)
        for ($i = 1; $i -le 6; $i++) {
            Add-WCChild $c3['Body'] (New-WCTextBlock -Text (T ('m7.actions.3.checklist.' + $i)) -Size 12 -Wrap)
        }
        Add-WCChild $c3['Body'] (New-WCTextBlock -Text (T 'm7.actions.3.guide.title') -Size 12.5 -Weight 'SemiBold' -Wrap)
        Add-WCChild $c3['Body'] (New-WCTextBlock -Text (T 'm7.actions.3.guide.1') -Size 12 -Wrap)
        Add-WCChild $c3['Body'] (New-WCTextBlock -Text (T 'm7.actions.3.guide.2') -Size 12 -Wrap)
        Add-WCChild $c3['Body'] (New-WCTextBlock -Text (T 'm7.actions.3.note') -Size 11 -ColorKey 'WcSubtle' -Wrap)
        Add-WCChild $body $c3['Root']
    } else {
        Add-WCChild $body (New-WCTextBlock -Text (T 'm7.actions.3.notneeded' @([string]@($Verdict['ReinstallSigns']).Count, '4')) -Size 12 -ColorKey 'WcSubtle' -Wrap)
    }
}

# ---------------------------------------------------------------------------
# HANH DONG (xac nhan truoc, ghi journal truoc khi thay doi - spec 2.4)
# ---------------------------------------------------------------------------
function Invoke-WCM7ToggleStartup {
    # Tat/bat muc khoi dong da chon qua CO CHE StartupApproved
    # (viet binary nhu Task Manager, KHONG xoa khoa goc, dao nguoc duoc).
    param($State, [bool]$Enable)
    $list = $State['StartupList']
    if (-not $list) { return }
    $sel = @(Get-WCCheckRowSelection -List $list)
    if ($sel.Count -eq 0) {
        Show-WCToast (T 'common.empty') 'Info'
        return
    }
    $names = @()
    foreach ($e in $sel) { $names += [string]$e['Name'] }
    $msgKey = 'm7.startup.confirm.on'
    if (-not $Enable) { $msgKey = 'm7.startup.confirm.off' }
    $msg = (T $msgKey) + "`n  • " + ([string]::Join("`n  • ", $names))
    if (-not (Show-WCConfirm -Title (T 'm7.startup.confirm.title') -Message $msg `
            -Undoable (T 'm7.startup.confirm.undo') -NotUndoable (T 'm7.startup.confirm.noundo'))) { return }
    if (Test-WCDryRunMode) {
        Show-WCToast (T 'common.dryrun.header') 'Info'
        return
    }
    $okCount = 0; $failCount = 0
    foreach ($e in $sel) {
        $entry = $null
        try {
            $action = (T 'm7.startup.journal.on')
            $undoType = 'startup.disable'
            # OldValue = trang thai HIEN TAI cua muc (truoc khi doi)
            $oldVal = [string]$e['State']
            if ($oldVal -ne 'Disabled') { $oldVal = 'Enabled' }
            if (-not $Enable) { $action = (T 'm7.startup.journal.off'); $undoType = 'startup.enable' }
            $approvedFull = Convert-WCRegPsPathToFull -Path ([string]$e['ApprovedKey'])
            # Ghi journal TRUOC khi thay doi (undo handler 'startup.enable' co san trong 05-Journal)
            $entry = Add-WCJournalEntry -Module 'M7' -Action $action -Target ([string]$e['Name']) `
                -OldValue $oldVal -UndoType $undoType `
                -UndoArgs @{ RegPath = $approvedFull; ValueName = ([string]$e['ValueName']) } `
                -AutoRestore:$false
            Set-WCStartupApprovedState -ApprovedKey ([string]$e['ApprovedKey']) -ValueName ([string]$e['ValueName']) -Enable $Enable
            Complete-WCJournalEntry -Entry $entry -Result 'Ok'
            $okCount++
        } catch {
            if ($entry) { Complete-WCJournalEntry -Entry $entry -Result ('Failed: ' + $_.Exception.Message) }
            $failCount++
        }
    }
    Show-WCToast (T 'm7.startup.result' @([string]$okCount, [string]$failCount)) 'Ok'
    Invoke-WCM7ScanStartup $State
}

function Invoke-WCM7Uninstall {
    # Mo trinh go CHINH THUC cua phan mem (go qua co che go chinh thuc,
    # KHONG tu xoa). Parse UninstallString: dau '"' -> exe trong ngoac + phan
    # con lai la args; khong co -> exe la token dau tien.
    param($Item)
    $name = [string]$Item['DisplayName']
    $us = [string]$Item['UninstallString']
    if ([string]::IsNullOrEmpty($us)) {
        Show-WCToast (T 'm7.software.uninstall.nostring') 'Warn'
        return
    }
    $parsed = Split-WCUninstallCommand -Cmd $us
    if ($null -eq $parsed) {
        Show-WCToast (T 'm7.software.uninstall.nostring') 'Warn'
        return
    }
    $cmdShown = ([string]$parsed['Exe'] + ' ' + [string]$parsed['Args']).Trim()
    $msg = (T 'm7.software.uninstall.confirm.msg' @($name, "`n", $cmdShown, "`n`n"))
    if (-not (Show-WCConfirm -Title (T 'm7.software.uninstall.confirm.title') -Message $msg `
            -NotUndoable (T 'm7.software.uninstall.confirm.noundo'))) { return }
    if (Test-WCDryRunMode) {
        Show-WCToast (T 'common.dryrun.header') 'Info'
        return
    }
    $entry = Add-WCJournalEntry -Module 'M7' -Action (T 'm7.software.journal') -Target $name `
        -OldValue 'Installed' -UndoType '' -UndoArgs $null
    try {
        if ([string]::IsNullOrEmpty([string]$parsed['Args'])) {
            Start-Process -FilePath ([string]$parsed['Exe']) -ErrorAction Stop
        } else {
            Start-Process -FilePath ([string]$parsed['Exe']) -ArgumentList ([string]$parsed['Args']) -ErrorAction Stop
        }
        Complete-WCJournalEntry -Entry $entry -Result 'Ok'
        Show-WCToast (T 'm7.software.uninstall.running' @($name)) 'Ok'
    } catch {
        Complete-WCJournalEntry -Entry $entry -Result ('Failed: ' + $_.Exception.Message)
        Show-WCError -Friendly (T 'm7.software.uninstall.fail') -Details $_.Exception.Message
    }
}

function Invoke-WCM7OpenResidualSelected {
    # Mo Explorer tai vi tri cac thu muc tan du da chon
    param($State)
    $list = $State['ResidualList']
    if (-not $list) { return }
    $sel = @(Get-WCCheckRowSelection -List $list)
    if ($sel.Count -eq 0) {
        Show-WCToast (T 'common.empty') 'Info'
        return
    }
    foreach ($f in $sel) {
        try { Start-Process explorer.exe -ArgumentList ('"' + [string]$f['Path'] + '"') } catch { }
    }
}

function Invoke-WCM7DeleteResidual {
    # Chuyen thu muc tan du da chon vao THUNG RAC (KHONG xoa vinh vien,
    # mac dinh khong tick). Goi Send-WCFileToRecycleBin (08-Interop.ps1)
    # sau Show-WCConfirm + ghi journal tung thu muc truoc khi lam.
    param($State)
    $list = $State['ResidualList']
    if (-not $list) { return }
    $sel = @(Get-WCCheckRowSelection -List $list)
    if ($sel.Count -eq 0) {
        Show-WCToast (T 'common.empty') 'Info'
        return
    }
    $lines = @()
    foreach ($f in $sel) {
        $lines += ('  • ' + [string]$f['Path'] + ' (' + (ConvertTo-WCHumanSize ([long]$f['SizeBytes'])) + ')')
    }
    $msg = (T 'm7.residual.delete.confirm.msg') + "`n" + ([string]::Join("`n", $lines))
    if (-not (Show-WCConfirm -Title (T 'm7.residual.delete.confirm.title') -Message $msg `
            -NotUndoable (T 'm7.residual.delete.confirm.noundo'))) { return }
    if (Test-WCDryRunMode) {
        Show-WCToast (T 'common.dryrun.header') 'Info'
        return
    }
    # Chay nen co tien do + Huy (recycle thu muc lon co the lau)
    $delArgs = @{ Items = $sel }
    Start-WCTask -Id 'm7.residual.delete' -Title (T 'm7.residual.delete') -ShowStatus -Args $delArgs -Worker {
        param($ctx, $s)
        $okCount = 0; $failCount = 0
        foreach ($f in @($s['Items'])) {
            if ($ctx.Cancelled()) { break }
            $path = [string]$f['Path']
            $ctx.Log(('Recycle: ' + $path))
            # Kiem tra an toan: junction thi bo qua; phai con thu muc con cap 1+
            if (Test-WCPathIsReparsePoint -Path $path) { $failCount++; continue }
            $entry = $null
            try {
                $entry = Add-WCJournalEntry -Module 'M7' -Action (T 'm7.residual.journal') -Target $path `
                    -OldValue ([string]$f['SizeBytes'] + ' bytes') -UndoType '' -UndoArgs $null
                $done = Send-WCFileToRecycleBin -Path $path
                if ($done) {
                    Complete-WCJournalEntry -Entry $entry -Result 'Ok'
                    $okCount++
                } else {
                    Complete-WCJournalEntry -Entry $entry -Result 'Failed'
                    $failCount++
                }
            } catch {
                if ($entry) { Complete-WCJournalEntry -Entry $entry -Result ('Failed: ' + $_.Exception.Message) }
                $failCount++
            }
        }
        return @{ Ok = $okCount; Fail = $failCount }
    } -Done {
        param($r)
        if ($r -and $r.ContainsKey('Ok')) {
            Show-WCToast (T 'm7.residual.result' @([string]$r['Ok'], [string]$r['Fail'])) 'Ok'
        }
        Invoke-WCM7ScanResidual $State
    }.GetNewClosure() | Out-Null
}

function Invoke-WCM7OpenLauncher {
    # Mo Steam/Epic (go/chuyen game chi qua launcher - spec M7)
    param([string]$Kind, [string]$FallbackExe)
    try {
        if ($Kind -eq 'steam') { Start-Process 'steam://open/games' }
        else { Start-Process 'com.epicgames.launcher://store' }
    } catch {
        $opened = $false
        if (-not [string]::IsNullOrEmpty($FallbackExe)) {
            try { Start-Process -FilePath $FallbackExe; $opened = $true } catch { }
        }
        if (-not $opened) { Show-WCToast (T 'm7.games.open.fail') 'Warn' }
    }
}

# ---------------------------------------------------------------------------
# KHOI TAO MODULE + DANG KY NAV (BAT BUOC cuoi file - spec hop dong)
# ---------------------------------------------------------------------------
function Initialize-WCModuleM7 {
    $state = @{
        Sections = @{}; Data = @{}; Ready = @{}
        Scanned = $false; StartupList = $null; ResidualList = $null
    }
    Register-WCNavItem -Key 'm7' -Badge 'M7' -Title (T 'm7.title') -Order 80 -Builder {
        New-WCM7Panel $state
    }.GetNewClosure() -OnShow {
        if (-not $state['Scanned']) {
            $state['Scanned'] = $true
            Invoke-WCM7Scan $state
        }
    }.GetNewClosure() -OnHide { }
}
