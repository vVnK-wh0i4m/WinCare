# ============================================================================
#  src/16-M5-Security.ps1 - Module M5: KIEM TRA BAO MAT & MA DOC
#  Su that the hien trong UI (spec M5): WinCare KHONG phai antivirus - dung
#  chinh engine Microsoft Defender lam dong co quet; "Khong phat hien moi de
#  doa" KHONG dong nghia "may sach 100%".
#  3 lop: (1) trang thai bao ve - chi doc + huong dan cach bat, khong tu bat;
#         (2) quet Defender (nhanh/toan bo/thu muc/ngoai tuyen) + xu ly de doa
#             qua Defender, xac nhan tung muc, khong tu xoa;
#         (3) heuristic dau hieu bat thuong - "goi y, khong phai ket luan",
#             moi muc kem LY DO cu the, vo hieu hoa dao nguoc duoc qua
#             StartupApproved ( nhu Task Manager ) + journal 'startup.enable'.
# ============================================================================

Register-WCStrings 'vi' @{
    'm5.title' = 'Kiểm tra bảo mật & mã độc'
    'm5.subtitle' = 'Dùng chính Microsoft Defender để quét — trung thực về giới hạn của công cụ'
    'm5.fact.title' = 'Sự thật cần biết trước'
    'm5.fact' = 'WinCare KHÔNG phải antivirus và không có engine quét riêng — mọi thao tác quét bên dưới đều dùng chính engine Microsoft Defender của Windows. "Không phát hiện mối đe dọa" KHÔNG đồng nghĩa "máy sạch 100%": kết quả chỉ phản ánh những gì Defender phát hiện được ở thời điểm quét.'
    # ---- Lop 1: trang thai bao ve ----
    'm5.l1.title' = 'Lớp 1 — Trạng thái bảo vệ'
    'm5.l1.subtitle' = 'Đọc trạng thái các lớp bảo vệ Windows. WinCare chỉ HƯỚNG DẪN cách bật — không tự thay đổi cấu hình bảo mật khi bạn chưa đồng ý.'
    'm5.l1.s.mpstatus' = 'Dịch vụ Microsoft Defender'
    'm5.l1.s.av' = 'Phần mềm diệt virus đã đăng ký'
    'm5.l1.s.firewall' = 'Tường lửa (Firewall)'
    'm5.l1.s.smartscreen' = 'SmartScreen'
    'm5.l1.s.uac' = 'Kiểm soát tài khoản (UAC)'
    'm5.l1.s.bitlocker' = 'BitLocker'
    'm5.l1.s.wupending' = 'Windows Update'
    'm5.def.mode' = 'Chế độ hoạt động: {0}'
    'm5.def.mode.normal' = 'đang hoạt động bình thường'
    'm5.def.mode.passive' = 'chế độ ngầm (passive) — thường do phần mềm diệt virus khác đang giữ vai trò chính. Đây là hành vi đúng của Windows, WinCare không "giành quyền"'
    'm5.def.mode.off' = 'không chạy / không đọc được — các nút quét bằng Defender ở Lớp 2 có thể không khả dụng'
    'm5.def.rtp' = 'Bảo vệ thời gian thực'
    'm5.def.rtp.how' = 'Cách bật: Bảo mật Windows → Virus & threat protection → Real-time protection. Nếu nút này bị mờ, có thể phần mềm diệt virus khác đang giữ vai trò (tham khảo mục "Phần mềm diệt virus đã đăng ký" phía trên).'
    'm5.def.sig.age' = 'Chữ ký virus: {0} ngày tuổi (cập nhật lần cuối: {1})'
    'm5.def.sig.stale' = 'Chữ ký đã cũ — nên bấm "Cập nhật chữ ký" ở Lớp 2.'
    'm5.def.sig.unknown' = 'Không đọc được thông tin chữ ký virus.'
    'm5.def.engine' = 'Phiên bản engine'
    'm5.def.quick' = 'Quét nhanh gần nhất'
    'm5.def.full' = 'Quét toàn bộ gần nhất'
    'm5.def.never' = 'chưa từng quét'
    'm5.def.tamper' = 'Chống can thiệp (Tamper Protection)'
    'm5.def.tamper.source' = 'Nguồn cấu hình chống can thiệp: {0}'
    'm5.def.tamper.how' = 'Cách bật: Bảo mật Windows → Virus & threat protection → Manage settings → Tamper Protection.'
    'm5.av.line' = '{0} — {1}, chữ ký {2}'
    'm5.av.on' = 'đang bật'
    'm5.av.off' = 'đang tắt'
    'm5.av.up' = 'mới'
    'm5.av.outdated' = 'cũ'
    'm5.av.unknown' = 'không rõ'
    'm5.av.note' = 'Giải mã productState theo cách phổ biến (chưa kiểm chứng trên mọi máy).'
    'm5.av.thirdparty' = 'Phát hiện phần mềm diệt virus bên thứ ba đang bật — khi đó Defender thường chuyển sang chế độ passive. Đây là thực trạng đúng của máy, không phải lỗi.'
    'm5.av.none' = 'Không đọc được danh sách AV (không gian root\SecurityCenter2 — máy ảo/Server có thể không có).'
    'm5.fw.line' = '{0}: {1}'
    'm5.fw.domain' = 'Miền (Domain)'
    'm5.fw.private' = 'Riêng tư (Private)'
    'm5.fw.public' = 'Công khai (Public)'
    'm5.fw.on' = 'đang bật'
    'm5.fw.off' = 'ĐANG TẮT — máy dễ bị truy cập từ mạng'
    'm5.fw.how' = 'Cách bật: Bảo mật Windows → Firewall & network protection → chọn profile → Bật.'
    'm5.ss.machine' = 'SmartScreen (toàn máy)'
    'm5.ss.user' = 'SmartScreen (người dùng)'
    'm5.ss.off' = 'Đang tắt — nên bật lại.'
    'm5.ss.warn' = 'Chỉ cảnh báo (Warn).'
    'm5.ss.missing' = 'Chưa đặt giá trị — dùng mặc định hệ thống.'
    'm5.ss.how' = 'Cách bật: Bảo mật Windows → App & browser control → Reputation-based protection settings → Check apps and files.'
    'm5.uac.on' = 'UAC đang bật (EnableLUA = 1).'
    'm5.uac.off' = 'UAC ĐANG TẮT (EnableLUA = 0) — chương trình có thể nâng quyền mà không hỏi.'
    'm5.uac.prompt' = 'Hành vi nhắc với Admin (ConsentPromptBehaviorAdmin)'
    'm5.uac.how' = 'Cách bật: tìm "Thay đổi cài đặt Kiểm soát tài khoản người dùng" trong Cài đặt Windows và kéo về mức mặc định.'
    'm5.bl.line' = '{0} — {1} (bảo vệ: {2})'
    'm5.bl.enc' = 'đã mã hóa'
    'm5.bl.dec' = 'CHƯA mã hóa'
    'm5.bl.protected' = 'bật'
    'm5.bl.notprotected' = 'tắt'
    'm5.bl.how' = 'Cách bật: Cài đặt → Quyền riêng tư & bảo mật → Mã hóa thiết bị / BitLocker (một số máy không hỗ trợ).'
    'm5.bl.unread' = 'Không đọc được BitLocker (cần quyền Admin hoặc module BitLocker không có trên máy).'
    'm5.wu.pending' = 'Có cập nhật chờ khởi động lại: {0}.'
    'm5.wu.none' = 'Không có cập nhật nào chờ khởi động lại.'
    'm5.wu.cbs' = 'thành phần hệ thống (CBS)'
    'm5.wu.wu' = 'Windows Update'
    'm5.wu.pfro' = 'tệp chờ đổi tên'
    'm5.wu.how' = 'Nên lưu công việc và khởi động lại máy để hoàn tất cập nhật.'
    # ---- Lop 2: quet Defender ----
    'm5.l2.title' = 'Lớp 2 — Quét bằng Microsoft Defender'
    'm5.l2.subtitle' = 'Các nút bên dưới gọi trực tiếp engine Microsoft Defender. Defender không báo tiến độ chi tiết — WinCare chỉ hiện thời gian đã chạy, không bịa số %.'
    'm5.l2.sig' = 'Cập nhật chữ ký'
    'm5.l2.quick' = 'Quét nhanh'
    'm5.l2.full' = 'Quét toàn bộ'
    'm5.l2.custom' = 'Quét thư mục'
    'm5.l2.wdo' = 'Quét ngoại tuyến'
    'm5.l2.folder.hint' = 'Thư mục / ổ đĩa cần quét (ví dụ: D:\Downloads):'
    'm5.l2.status.idle' = 'Chưa chạy quét nào.'
    'm5.scan.title' = 'Quét Defender'
    'm5.elapsed' = 'Đã chạy {0} giây'
    'm5.scan.noprogress' = 'Defender không báo tiến độ chi tiết — không có số % thật nên không hiển thị'
    'm5.scan.folder.invalid' = 'Đường dẫn thư mục không hợp lệ hoặc không tồn tại.'
    'm5.scan.done' = 'Quét xong sau {0} giây.'
    'm5.scan.error' = 'Quét không thành công — dịch vụ Defender có thể đang tắt hoặc bị phần mềm diệt virus khác thay thế.'
    'm5.sig.title' = 'Cập nhật chữ ký Defender'
    'm5.sig.done' = 'Đã cập nhật chữ ký virus.'
    'm5.sig.error' = 'Cập nhật chữ ký không thành công (kiểm tra kết nối mạng hoặc trạng thái dịch vụ Defender).'
    'm5.sig.cancelnote' = 'Việc cập nhật chữ ký không dừng ngay được — bấm Hủy chỉ ngừng chờ, dịch vụ Defender có thể vẫn cập nhật nốt'
    'm5.wdo.confirm.title' = 'Quét ngoại tuyến — máy sẽ KHỞI ĐỘNG LẠI'
    'm5.wdo.confirm.msg' = "Ngay sau khi xác nhận, máy sẽ KHỞI ĐỘNG LẠI để quét trước khi Windows chạy (khoảng 15–30 phút, trong lúc đó không dùng được máy).`nHãy LƯU hết công việc đang mở trước khi bấm."
    'm5.wdo.confirm.noundo' = 'Máy khởi động lại ngay — không thể hoàn tác.'
    'm5.wdo.scheduled' = 'Đã hẹn quét ngoại tuyến — máy sẽ khởi động lại ngay để quét.'
    'm5.wdo.error' = 'Không hẹn được quét ngoại tuyến.'
    'm5.threat.title' = 'Kết quả — mối đe dọa'
    'm5.threat.subtitle' = 'Danh sách Defender ghi nhận (Get-MpThreatDetection / Get-MpThreat).'
    'm5.threat.col.name' = 'Mối đe dọa'
    'm5.threat.col.type' = 'Loại'
    'm5.threat.col.res' = 'Tài nguyên'
    'm5.threat.col.status' = 'Trạng thái'
    'm5.threat.none' = 'Không phát hiện mối đe dọa. Lưu ý: KHÔNG đồng nghĩa máy sạch 100% — chỉ có nghĩa là Defender không thấy gì trong phạm vi nó quét được.'
    'm5.threat.remove' = 'Cách ly'
    'm5.threat.active' = 'đang hoạt động'
    'm5.threat.at' = 'Phát hiện lúc: {0}'
    'm5.threat.confirm.title' = 'Xử lý mối đe dọa bằng Defender'
    'm5.threat.confirm.msg' = ('Yêu cầu Microsoft Defender xử lý mối đe dọa "{0}"?' + "`n" + 'Lưu ý: cmdlet Remove-MpThreat của Microsoft xử lý theo chính sách của Defender (thường là cách ly/xóa các mối đe dọa đang hoạt động), không chọn đúng một mục.')
    'm5.threat.confirm.noundo' = 'Không hoàn tác tự động qua WinCare; mục bị cách ly có thể xem/khôi phục trong "Protection history" của Bảo mật Windows.'
    'm5.threat.refresh' = 'Làm mới danh sách'
    'm5.threat.journal' = 'Yêu cầu Defender xử lý mối đe dọa'
    'm5.threat.sev.1' = 'Thấp'
    'm5.threat.sev.2' = 'Trung bình'
    'm5.threat.sev.3' = 'Cao'
    'm5.threat.sev.4' = 'Cao'
    'm5.threat.sev.5' = 'Nghiêm trọng'
    'm5.threat.sev.fmt' = 'Mức {0}'
    'm5.threat.sev.unknown' = 'Không rõ'
    'm5.threat.cat.1' = 'Adware'
    'm5.threat.cat.2' = 'Spyware'
    'm5.threat.cat.5' = 'Sâu máy (Worm)'
    'm5.threat.cat.6' = 'Backdoor'
    'm5.threat.cat.8' = 'Trojan'
    'm5.threat.cat.10' = 'Keylogger'
    'm5.threat.cat.30' = 'Exploit'
    'm5.threat.cat.fmt' = 'Loại {0}'
    'm5.threat.status.1' = 'Không rõ'
    'm5.threat.status.2' = 'Đã phát hiện'
    'm5.threat.status.3' = 'Đã dọn'
    'm5.threat.status.4' = 'Đã cách ly'
    'm5.threat.status.5' = 'Đã xóa'
    'm5.threat.status.6' = 'Đã cho phép'
    'm5.threat.status.fmt' = 'Mã {0}'
    # ---- Lop 3: heuristic ----
    'm5.l3.title' = 'Lớp 3 — Dấu hiệu bất thường'
    'm5.l3.subtitle' = 'Heuristic mang tính GỢI Ý, KHÔNG phải kết luận. Mỗi mục kèm lý do cụ thể để bạn tự đánh giá; WinCare không tự xóa gì.'
    'm5.l3.scan' = 'Quét dấu hiệu bất thường'
    'm5.l3.scanning' = 'Đang quét dấu hiệu bất thường (có thể mất chục giây)…'
    'm5.l3.idle' = 'Chưa quét'
    'm5.l3.notfound' = 'Không có mục nào.'
    'm5.l3.errsource' = 'Không đọc được nguồn này: {0}'
    'm5.l3.cancelled' = 'Đã dừng giữa chừng — danh sách có thể thiếu. Bấm quét lại để quét đầy đủ.'
    'm5.level.ok' = 'Bình thường'
    'm5.level.warn' = 'Cần xem'
    'm5.level.bad' = 'Đáng ngờ'
    'm5.level.unknown' = 'Không rõ'
    'm5.g.run' = 'Run / RunOnce (khởi động cùng Windows)'
    'm5.g.startup' = 'Thư mục Startup'
    'm5.g.task' = 'Scheduled Tasks ngoài Microsoft'
    'm5.g.svc' = 'Dịch vụ tự khởi động ngoài Windows'
    'm5.g.winlogon' = 'Winlogon (Shell / Userinit)'
    'm5.g.ifeo' = 'IFEO Debugger'
    'm5.g.wmi' = 'Đăng ký sự kiện WMI (bền vững)'
    'm5.g.excl' = 'Danh sách loại trừ của Defender'
    'm5.g.hosts' = 'Tệp hosts'
    'm5.g.proxy' = 'Proxy / PAC'
    'm5.g.count' = '{0} mục'
    'm5.h.location' = 'Tệp chạy từ vị trí tạm/công cộng (Temp/Public) — vị trí thường bị mã độc lợi dụng.'
    'm5.h.unquoted' = 'Đường dẫn có khoảng trắng nhưng không đặt trong ngoặc kép — có thể bị chiếm quyền bằng tệp ngụy trang (unquoted path).'
    'm5.h.unsigned' = 'Không có chữ ký số hợp lệ.'
    'm5.h.signed' = 'Đã ký số: {0}'
    'm5.h.nofile' = 'Không tìm thấy tệp để kiểm tra chữ ký (có thể đã bị xóa).'
    'm5.h.noexe' = 'Không xác định được tệp thực thi từ lệnh.'
    'm5.h.run' = 'Chạy tự động khi đăng nhập (khóa Run trong registry).'
    'm5.h.startup' = 'Nằm trong thư mục Startup — chạy tự động khi đăng nhập.'
    'm5.h.task' = 'Tác vụ lập lịch ngoài Microsoft.'
    'm5.h.svc' = 'Dịch vụ bên thứ ba tự khởi động cùng Windows.'
    'm5.h.shell.bad' = 'Shell không còn là "explorer.exe" chuẩn — dấu hiệu chiếm quyền hiếm gặp, cần xem ngay.'
    'm5.h.shell.ok' = 'Giá trị chuẩn "explorer.exe".'
    'm5.h.userinit.bad' = 'Userinit không chứa "userinit.exe," chuẩn — dấu hiệu chiếm quyền hiếm gặp, cần xem ngay.'
    'm5.h.userinit.ok' = 'Giá trị chuẩn (chứa "userinit.exe,").'
    'm5.h.ifeo' = 'Có giá trị Debugger trong IFEO — một số công cụ phát triển hợp lệ cũng dùng, nhưng mã độc cũng hay dùng để chặn/chiếm tiến trình.'
    'm5.h.wmi' = 'Đăng ký sự kiện WMI bền vững — rất ít phần mềm hợp lệ dùng, nên kiểm tra kỹ.'
    'm5.h.excl.path' = 'Nằm trong danh sách loại trừ của Defender — mã độc hay tự thêm để né quét.'
    'm5.h.excl.ext' = 'Phần mở rộng được bỏ qua khi quét: {0}'
    'm5.h.excl.proc' = 'Tiến trình được bỏ qua khi quét: {0}'
    'm5.h.excl.none' = 'Không có loại trừ nào.'
    'm5.h.hosts' = 'hosts có dòng chỉnh sửa (chặn hoặc trỏ domain) — có thể do bạn tự đặt hoặc do phần mềm.'
    'm5.h.hosts.ok' = 'Chỉ có dòng chuẩn (localhost / ghi chú).'
    'm5.h.proxy' = 'Đang đặt proxy/PAC thủ công — nếu không phải bạn đặt, nên kiểm tra lại.'
    'm5.h.proxy.none' = 'Không đặt proxy/PAC thủ công.'
    'm5.a.hash' = 'SHA-256'
    'm5.a.vt' = 'Tra VirusTotal'
    'm5.a.disable' = 'Vô hiệu hóa'
    'm5.hash.title' = 'Băm SHA-256'
    'm5.hash.msg' = "SHA-256:`n{0}`n`nTệp: {1}`n`nĐã sao chép vào clipboard."
    'm5.vt.opening' = 'Mở VirusTotal với mã băm (chỉ tra cứu hash — KHÔNG tải tệp của bạn lên).'
    'm5.reg.copied' = 'Đã sao chép đường dẫn khóa — mở Registry Editor rồi dán (Ctrl+V) vào thanh địa chỉ.'
    'm5.dis.confirm.title' = 'Vô hiệu hóa mục khởi động'
    'm5.dis.confirm.msg' = ('Tắt khởi động của "{0}"?' + "`n" + 'WinCare KHÔNG xóa gì — chỉ ghi cờ "đã tắt" đúng cách Task Manager (StartupApproved). Phần mềm vẫn chạy bình thường khi bạn tự mở.')
    'm5.dis.confirm.undo' = 'Khôi phục được: bấm "Hoàn tác" trong Lịch sử, hoặc bật lại trong Task Manager.'
    'm5.journal.disable' = 'Vô hiệu hóa mục khởi động'
    'm5.dis.enabled' = 'Đang bật'
    'm5.open.parent' = 'Không tìm thấy tệp — mở thư mục cha.'
    'm5.filenotfound' = 'Không tìm thấy tệp để kiểm tra.'
    'm5.expert.l2' = 'Update-MpSignature; Start-MpScan -ScanType QuickScan|FullScan|CustomScan; Start-MpWDOScan; Get-MpThreat; Get-MpThreatDetection; Remove-MpThreat; Stop-MpScan'
    'm5.expert.l3' = 'Get-Item HKLM/HKCU:...\CurrentVersion\Run; Get-ScheduledTask; Get-CimInstance Win32_Service; Get-AuthenticodeSignature; Get-MpPreference; __EventFilter/__EventConsumer'
}
Register-WCStrings 'en' @{
    'm5.title' = 'Security & malware check'
    'm5.subtitle' = 'Scans use the built-in Microsoft Defender engine — honest about the tool limits'
    'm5.fact.title' = 'Facts to know first'
    'm5.fact' = 'WinCare is NOT an antivirus and has no scan engine of its own — every scan below uses the Microsoft Defender engine built into Windows. "No threats found" does NOT mean the PC is 100% clean: it only reflects what Defender can detect at scan time.'
    'm5.l1.title' = 'Layer 1 — Protection status'
    'm5.l1.subtitle' = 'Read-only view of Windows protection layers. WinCare only GUIDES you how to turn things on — it never changes security settings without your consent.'
    'm5.l1.s.mpstatus' = 'Microsoft Defender service'
    'm5.l1.s.av' = 'Registered antivirus products'
    'm5.l1.s.firewall' = 'Firewall'
    'm5.l1.s.smartscreen' = 'SmartScreen'
    'm5.l1.s.uac' = 'User Account Control (UAC)'
    'm5.l1.s.bitlocker' = 'BitLocker'
    'm5.l1.s.wupending' = 'Windows Update'
    'm5.def.mode' = 'Running mode: {0}'
    'm5.def.mode.normal' = 'running normally'
    'm5.def.mode.passive' = 'passive mode — usually because another antivirus is the primary AV. This is correct Windows behavior; WinCare does not "take over"'
    'm5.def.mode.off' = 'not running / cannot read — Defender-based scans in Layer 2 may not work'
    'm5.def.rtp' = 'Real-time protection'
    'm5.def.rtp.how' = 'How to enable: Windows Security → Virus & threat protection → Real-time protection. If the toggle is greyed out, another antivirus may own this role (see "Registered antivirus products" above).'
    'm5.def.sig.age' = 'Virus signatures: {0} days old (last updated: {1})'
    'm5.def.sig.stale' = 'Signatures are stale — consider "Update signatures" in Layer 2.'
    'm5.def.sig.unknown' = 'Cannot read signature information.'
    'm5.def.engine' = 'Engine version'
    'm5.def.quick' = 'Last quick scan'
    'm5.def.full' = 'Last full scan'
    'm5.def.never' = 'never'
    'm5.def.tamper' = 'Tamper Protection'
    'm5.def.tamper.source' = 'Tamper protection config source: {0}'
    'm5.def.tamper.how' = 'How to enable: Windows Security → Virus & threat protection → Manage settings → Tamper Protection.'
    'm5.av.line' = '{0} — {1}, signatures {2}'
    'm5.av.on' = 'on'
    'm5.av.off' = 'off'
    'm5.av.up' = 'current'
    'm5.av.outdated' = 'outdated'
    'm5.av.unknown' = 'unknown'
    'm5.av.note' = 'productState decoded with the common method (not verified on every machine).'
    'm5.av.thirdparty' = 'A third-party antivirus is enabled — Defender usually runs in passive mode then. This is the true state of the machine, not an error.'
    'm5.av.none' = 'Cannot read the AV list (root\SecurityCenter2 namespace — missing on Server/some VMs).'
    'm5.fw.line' = '{0}: {1}'
    'm5.fw.domain' = 'Domain'
    'm5.fw.private' = 'Private'
    'm5.fw.public' = 'Public'
    'm5.fw.on' = 'on'
    'm5.fw.off' = 'OFF — the PC is exposed to the network'
    'm5.fw.how' = 'How to enable: Windows Security → Firewall & network protection → pick a profile → turn it on.'
    'm5.ss.machine' = 'SmartScreen (machine)'
    'm5.ss.user' = 'SmartScreen (user)'
    'm5.ss.off' = 'Off — should be turned back on.'
    'm5.ss.warn' = 'Warn only.'
    'm5.ss.missing' = 'Value not set — system default applies.'
    'm5.ss.how' = 'How to enable: Windows Security → App & browser control → Reputation-based protection settings → Check apps and files.'
    'm5.uac.on' = 'UAC is on (EnableLUA = 1).'
    'm5.uac.off' = 'UAC is OFF (EnableLUA = 0) — programs can elevate without asking.'
    'm5.uac.prompt' = 'Admin prompt behavior (ConsentPromptBehaviorAdmin)'
    'm5.uac.how' = 'How to enable: search "Change User Account Control settings" in Windows Settings and slide back to default.'
    'm5.bl.line' = '{0} — {1} (protection: {2})'
    'm5.bl.enc' = 'encrypted'
    'm5.bl.dec' = 'NOT encrypted'
    'm5.bl.protected' = 'on'
    'm5.bl.notprotected' = 'off'
    'm5.bl.how' = 'How to enable: Settings → Privacy & security → Device encryption / BitLocker (not available on all machines).'
    'm5.bl.unread' = 'Cannot read BitLocker (needs Admin or the BitLocker module is missing).'
    'm5.wu.pending' = 'Updates are waiting for a reboot: {0}.'
    'm5.wu.none' = 'No updates are waiting for a reboot.'
    'm5.wu.cbs' = 'Component Based Servicing'
    'm5.wu.wu' = 'Windows Update'
    'm5.wu.pfro' = 'pending file rename'
    'm5.wu.how' = 'Save your work and restart the PC to finish installing updates.'
    'm5.l2.title' = 'Layer 2 — Scan with Microsoft Defender'
    'm5.l2.subtitle' = 'Buttons below call the Microsoft Defender engine directly. Defender reports no detailed progress — WinCare only shows elapsed time, no made-up percentages.'
    'm5.l2.sig' = 'Update signatures'
    'm5.l2.quick' = 'Quick scan'
    'm5.l2.full' = 'Full scan'
    'm5.l2.custom' = 'Scan folder'
    'm5.l2.wdo' = 'Offline scan'
    'm5.l2.folder.hint' = 'Folder / drive to scan (e.g. D:\Downloads):'
    'm5.l2.status.idle' = 'No scan has been run yet.'
    'm5.scan.title' = 'Defender scan'
    'm5.elapsed' = 'Running for {0} seconds'
    'm5.scan.noprogress' = 'Defender reports no detailed progress — no real % exists, so none is shown'
    'm5.scan.folder.invalid' = 'Folder path is invalid or does not exist.'
    'm5.scan.done' = 'Scan finished in {0} seconds.'
    'm5.scan.error' = 'Scan failed — the Defender service may be off or replaced by another antivirus.'
    'm5.sig.title' = 'Update Defender signatures'
    'm5.sig.done' = 'Virus signatures updated.'
    'm5.sig.error' = 'Signature update failed (check the network connection or the Defender service).'
    'm5.sig.cancelnote' = 'Signature updates cannot be stopped midway — pressing Cancel only stops waiting; the Defender service may finish the update'
    'm5.wdo.confirm.title' = 'Offline scan — the PC WILL RESTART'
    'm5.wdo.confirm.msg' = "Right after you confirm, the PC will RESTART to scan before Windows loads (about 15–30 minutes, unusable meanwhile).`nSAVE all open work before pressing the button."
    'm5.wdo.confirm.noundo' = 'The PC restarts immediately — cannot be undone.'
    'm5.wdo.scheduled' = 'Offline scan scheduled — the PC will restart now to scan.'
    'm5.wdo.error' = 'Could not schedule the offline scan.'
    'm5.threat.title' = 'Results — threats'
    'm5.threat.subtitle' = 'Listed by Defender (Get-MpThreatDetection / Get-MpThreat).'
    'm5.threat.col.name' = 'Threat'
    'm5.threat.col.type' = 'Type'
    'm5.threat.col.res' = 'Resource'
    'm5.threat.col.status' = 'Status'
    'm5.threat.none' = 'No threats found. Note: this does NOT mean the PC is 100% clean — it only means Defender saw nothing within what it can scan.'
    'm5.threat.remove' = 'Quarantine'
    'm5.threat.active' = 'active'
    'm5.threat.at' = 'Detected at: {0}'
    'm5.threat.confirm.title' = 'Handle threat with Defender'
    'm5.threat.confirm.msg' = ('Ask Microsoft Defender to handle "{0}"?' + "`n" + 'Note: the Microsoft cmdlet Remove-MpThreat acts according to Defender policy (usually quarantining/removing active threats), it cannot target exactly one item.')
    'm5.threat.confirm.noundo' = 'Not auto-undoable via WinCare; quarantined items can be viewed/restored in Windows Security "Protection history".'
    'm5.threat.refresh' = 'Refresh list'
    'm5.threat.journal' = 'Ask Defender to handle threat'
    'm5.threat.sev.1' = 'Low'
    'm5.threat.sev.2' = 'Medium'
    'm5.threat.sev.3' = 'High'
    'm5.threat.sev.4' = 'High'
    'm5.threat.sev.5' = 'Severe'
    'm5.threat.sev.fmt' = 'Level {0}'
    'm5.threat.sev.unknown' = 'Unknown'
    'm5.threat.cat.1' = 'Adware'
    'm5.threat.cat.2' = 'Spyware'
    'm5.threat.cat.5' = 'Worm'
    'm5.threat.cat.6' = 'Backdoor'
    'm5.threat.cat.8' = 'Trojan'
    'm5.threat.cat.10' = 'Keylogger'
    'm5.threat.cat.30' = 'Exploit'
    'm5.threat.cat.fmt' = 'Type {0}'
    'm5.threat.status.1' = 'Unknown'
    'm5.threat.status.2' = 'Detected'
    'm5.threat.status.3' = 'Cleaned'
    'm5.threat.status.4' = 'Quarantined'
    'm5.threat.status.5' = 'Removed'
    'm5.threat.status.6' = 'Allowed'
    'm5.threat.status.fmt' = 'Code {0}'
    'm5.l3.title' = 'Layer 3 — Suspicious signs'
    'm5.l3.subtitle' = 'Heuristics are HINTS, NOT conclusions. Each item shows its specific reason so you can judge; WinCare deletes nothing on its own.'
    'm5.l3.scan' = 'Scan for suspicious signs'
    'm5.l3.scanning' = 'Scanning for suspicious signs (may take tens of seconds)…'
    'm5.l3.idle' = 'Not scanned yet'
    'm5.l3.notfound' = 'No items.'
    'm5.l3.errsource' = 'Cannot read this source: {0}'
    'm5.l3.cancelled' = 'Stopped midway — the list may be incomplete. Scan again for full results.'
    'm5.level.ok' = 'Normal'
    'm5.level.warn' = 'Review'
    'm5.level.bad' = 'Suspicious'
    'm5.level.unknown' = 'Unclear'
    'm5.g.run' = 'Run / RunOnce (starts with Windows)'
    'm5.g.startup' = 'Startup folder'
    'm5.g.task' = 'Non-Microsoft scheduled tasks'
    'm5.g.svc' = 'Auto-start services outside Windows'
    'm5.g.winlogon' = 'Winlogon (Shell / Userinit)'
    'm5.g.ifeo' = 'IFEO Debugger'
    'm5.g.wmi' = 'Persistent WMI event subscriptions'
    'm5.g.excl' = 'Defender exclusion list'
    'm5.g.hosts' = 'hosts file'
    'm5.g.proxy' = 'Proxy / PAC'
    'm5.g.count' = '{0} items'
    'm5.h.location' = 'Executable runs from a temp/public location (Temp/Public) — commonly abused by malware.'
    'm5.h.unquoted' = 'Path contains spaces but is not quoted — can be hijacked with a decoy file (unquoted path).'
    'm5.h.unsigned' = 'No valid digital signature.'
    'm5.h.signed' = 'Signed by: {0}'
    'm5.h.nofile' = 'File not found for signature check (may have been deleted).'
    'm5.h.noexe' = 'Could not determine the executable from the command.'
    'm5.h.run' = 'Runs automatically at sign-in (registry Run key).'
    'm5.h.startup' = 'Lives in the Startup folder — runs automatically at sign-in.'
    'm5.h.task' = 'Non-Microsoft scheduled task.'
    'm5.h.svc' = 'Third-party service starting with Windows.'
    'm5.h.shell.bad' = 'Shell is no longer the standard "explorer.exe" — rare hijack sign, review now.'
    'm5.h.shell.ok' = 'Standard value "explorer.exe".'
    'm5.h.userinit.bad' = 'Userinit lacks the standard "userinit.exe," — rare hijack sign, review now.'
    'm5.h.userinit.ok' = 'Standard value (contains "userinit.exe,").'
    'm5.h.ifeo' = 'Debugger value present in IFEO — some legit dev tools use it, but malware likes it to block/hijack processes.'
    'm5.h.wmi' = 'Persistent WMI event subscription — very few legit products use it, review carefully.'
    'm5.h.excl.path' = 'Listed as a Defender exclusion — malware often adds itself here to dodge scans.'
    'm5.h.excl.ext' = 'Extension excluded from scanning: {0}'
    'm5.h.excl.proc' = 'Process excluded from scanning: {0}'
    'm5.h.excl.none' = 'No exclusions.'
    'm5.h.hosts' = 'hosts file has custom lines (blocking/redirecting domains) — could be yours or added by software.'
    'm5.h.hosts.ok' = 'Only standard lines (localhost / comments).'
    'm5.h.proxy' = 'A manual proxy/PAC is configured — if you did not set it, investigate.'
    'm5.h.proxy.none' = 'No manual proxy/PAC configured.'
    'm5.a.hash' = 'SHA-256'
    'm5.a.vt' = 'Check VirusTotal'
    'm5.a.disable' = 'Disable'
    'm5.hash.title' = 'SHA-256 hash'
    'm5.hash.msg' = "SHA-256:`n{0}`n`nFile: {1}`n`nCopied to clipboard."
    'm5.vt.opening' = 'Opening VirusTotal with the hash (hash lookup only — your file is NOT uploaded).'
    'm5.reg.copied' = 'Registry path copied — open Registry Editor and paste (Ctrl+V) into the address bar.'
    'm5.dis.confirm.title' = 'Disable startup item'
    'm5.dis.confirm.msg' = ('Disable startup of "{0}"?' + "`n" + 'WinCare deletes NOTHING — it only sets the "disabled" flag the same way Task Manager does (StartupApproved). The app still runs fine when you open it yourself.')
    'm5.dis.confirm.undo' = 'Undoable: press "Undo" in History, or re-enable in Task Manager.'
    'm5.journal.disable' = 'Disable startup item'
    'm5.dis.enabled' = 'Enabled'
    'm5.open.parent' = 'File not found — opening its parent folder.'
    'm5.filenotfound' = 'File not found for inspection.'
    'm5.expert.l2' = 'Update-MpSignature; Start-MpScan -ScanType QuickScan|FullScan|CustomScan; Start-MpWDOScan; Get-MpThreat; Get-MpThreatDetection; Remove-MpThreat; Stop-MpScan'
    'm5.expert.l3' = 'Get-Item HKLM/HKCU:...\CurrentVersion\Run; Get-ScheduledTask; Get-CimInstance Win32_Service; Get-AuthenticodeSignature; Get-MpPreference; __EventFilter/__EventConsumer'
}

# Hashtable tinh cua module: cache ket qua kiem chu ky so (path + LastWriteTime).
# Truyen vao worker qua -Args (hashtable la reference type -> chia se that).
$Script:WcM5SigCache = @{}

# ---------------------------------------------------------------------------
# Helpers dung chung cua module
# ---------------------------------------------------------------------------
function ConvertTo-WCM5TimeText {
    # DateTime (co the string) -> "yyyy-MM-dd HH:mm"; loi -> "Khong ro"
    param($Value)
    if ($null -eq $Value) { return (T 'common.unknown') }
    try { return ('{0:yyyy-MM-dd HH:mm}' -f [datetime]$Value) } catch { return (T 'common.unknown') }
}

function Get-WCM5Worst {
    # Tra muc xau nhat trong danh sach Ok/Warn/Bad/Unknown
    param([string[]]$Statuses)
    foreach ($s in @('Bad', 'Warn', 'Unknown')) {
        foreach ($x in $Statuses) { if ($x -eq $s) { return $s } }
    }
    return 'Ok'
}

function ConvertTo-WCM5NetRegPath {
    # 'HKLM:\A\B' -> 'HKEY_LOCAL_MACHINE\A\B' (dung cho Registry.SetValue + clipboard)
    param([string]$PsPath)
    if ([string]::IsNullOrEmpty($PsPath)) { return '' }
    if ($PsPath.StartsWith('HKLM:\')) { return ('HKEY_LOCAL_MACHINE\' + $PsPath.Substring(6)) }
    if ($PsPath.StartsWith('HKCU:\')) { return ('HKEY_CURRENT_USER\' + $PsPath.Substring(6)) }
    return $PsPath
}

function Get-WCM5L1Sources { return @('mpstatus', 'av', 'firewall', 'smartscreen', 'uac', 'bitlocker', 'wupending') }

# ---------------------------------------------------------------------------
# LOP 1 — DU LIEU TRANG THAI BAO VE (moi nguon mot key rieng, try/catch rieng)
# ---------------------------------------------------------------------------
function Get-WCM5FirewallRaw {
    # COM HNetCfg.FwPolicy2, doc FirewallEnabled tung profile.
    # Luu y: theo tai lieu Microsoft, NET_FW_PROFILE2 la Domain=1, Private=2,
    # Public=4 (yeu cau goc ghi 1/2/3 nhung gia tri 3 khong ton tai trong enum).
    $out = @()
    $fw = New-Object -ComObject HNetCfg.FwPolicy2
    $map = @(
        @{ Id = 1; Name = 'Domain' }
        @{ Id = 2; Name = 'Private' }
        @{ Id = 4; Name = 'Public' }
    )
    foreach ($m in $map) {
        $en = $null
        try { $en = [bool]$fw.FirewallEnabled($m['Id']) } catch { }
        $out += [PSCustomObject]@{ Profile = $m['Name']; Enabled = $en }
    }
    try { $null = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($fw) } catch { }
    return ,@($out)
}

function Get-WCM5SmartscreenRaw {
    $lm = Get-WCRegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' -Name 'SmartScreenEnabled'
    $cu = Get-WCRegistryValue -Path 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' -Name 'SmartScreenEnabled'
    return [PSCustomObject]@{ Machine = $lm; User = $cu }
}

function Get-WCM5UacRaw {
    $lua = Get-WCRegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'EnableLUA'
    $consent = Get-WCRegistryValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'ConsentPromptBehaviorAdmin'
    return [PSCustomObject]@{ EnableLUA = $lua; Consent = $consent }
}

function Get-WCM5WuPendingRaw {
    # 3 dau hieu cap nhat cho khoi dong lai: CBS RebootPending, WU RebootRequired,
    # PendingFileRenameOperations
    $cbs = $false
    $wu = $false
    $ren = $false
    try { $cbs = Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending' } catch { }
    try { $wu = Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired' } catch { }
    $pfro = Get-WCRegistryValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations'
    if ($null -ne $pfro) { $ren = $true }
    return [PSCustomObject]@{ Cbs = $cbs; Wu = $wu; Rename = $ren }
}

function Get-WCM5AvProducts {
    # AV ben thu ba qua root/SecurityCenter2 + giai ma productState.
    # GIAI DINH (best-effort, decode pho bien chua kiem chung tren moi may):
    #   hex = '{0:X6}' -f state; enabled  = nibble thu 3 (index 2) khac '0';
    #   updated = nibble thu 5 (index 4) bang '0'.
    param([switch]$Fresh)
    $r = $null
    if ($Fresh) {
        $r = Invoke-WCQuery -Key 'sec.av' -NoCache -Script {
            Get-CimInstance -Namespace 'root/SecurityCenter2' -ClassName 'AntiVirusProduct' -OperationTimeoutSec 10 -ErrorAction Stop
        }
    } else {
        $r = Invoke-WCQuery -Key 'sec.av' -CacheTtlSec 60 -Script {
            Get-CimInstance -Namespace 'root/SecurityCenter2' -ClassName 'AntiVirusProduct' -OperationTimeoutSec 10 -ErrorAction Stop
        }
    }
    if ($r.Status -ne 'Ok') { return $r }
    $items = @()
    $hasThird = $false
    foreach ($p in @($r.Data)) {
        if ($null -eq $p) { continue }
        $name = [string](Get-WCProp $p 'displayName')
        $state = Get-WCProp $p 'productState'
        $enabled = $null
        $updated = $null
        if ($null -ne $state) {
            try {
                $hex = '{0:X6}' -f ([int]$state)
                $enabled = ($hex[2] -ne '0')
                $updated = ($hex[4] -eq '0')
            } catch { }
        }
        if (($enabled -eq $true) -and ($name -notlike '*Defender*')) { $hasThird = $true }
        $items += [PSCustomObject]@{
            Name = $name; Enabled = $enabled; UpToDate = $updated
            Timestamp = (Get-WCProp $p 'timestamp'); State = $state
        }
    }
    return (New-WCResult -Status 'Ok' -Data ([PSCustomObject]@{ Items = $items; HasThirdParty = $hasThird }))
}

function Invoke-WCM5SourceQuery {
    param([Parameter(Mandatory)][string]$Key, [Parameter(Mandatory)][scriptblock]$Query, [switch]$Fresh)
    if ($Fresh) { return (Invoke-WCQuery -Key $Key -NoCache -Script $Query) }
    return (Invoke-WCQuery -Key $Key -CacheTtlSec 60 -Script $Query)
}

function Get-WCM5StatusData {
    # Dispatch tung nguon Lop 1; moi nguon goi Invoke-WCQuery voi key rieng
    # ('sec.mpstatus', 'sec.av', ...) -> ho tro FIXTURE va cache
    param([Parameter(Mandatory)][string]$Source, [switch]$Fresh)
    switch ($Source) {
        'mpstatus'   { return (Invoke-WCM5SourceQuery -Key 'sec.mpstatus' -Fresh:$Fresh -Query { Get-MpComputerStatus -ErrorAction Stop }) }
        'av'         { return (Get-WCM5AvProducts -Fresh:$Fresh) }
        'firewall'   { return (Invoke-WCM5SourceQuery -Key 'sec.firewall' -Fresh:$Fresh -Query { Get-WCM5FirewallRaw }) }
        'smartscreen' { return (Invoke-WCM5SourceQuery -Key 'sec.smartscreen' -Fresh:$Fresh -Query { Get-WCM5SmartscreenRaw }) }
        'uac'        { return (Invoke-WCM5SourceQuery -Key 'sec.uac' -Fresh:$Fresh -Query { Get-WCM5UacRaw }) }
        'bitlocker'  { return (Invoke-WCM5SourceQuery -Key 'sec.bitlocker' -Fresh:$Fresh -Query { Get-BitLockerVolume -ErrorAction Stop }) }
        'wupending'  { return (Invoke-WCM5SourceQuery -Key 'sec.wupending' -Fresh:$Fresh -Query { Get-WCM5WuPendingRaw }) }
    }
    return (New-WCResult -Status 'Unknown' -Reason 'Unknown source')
}

# ---------------------------------------------------------------------------
# LOP 2 — DU LIEU DE DOA (Get-MpThreat + Get-MpThreatDetection)
# ---------------------------------------------------------------------------
function Get-WCM5SeverityText {
    param($Sev, $SevId)
    if ($Sev) { return [string]$Sev }
    if ($null -ne $SevId) {
        switch ([int]$SevId) {
            1 { return (T 'm5.threat.sev.1') }
            2 { return (T 'm5.threat.sev.2') }
            3 { return (T 'm5.threat.sev.3') }
            4 { return (T 'm5.threat.sev.4') }
            5 { return (T 'm5.threat.sev.5') }
            default { return (T 'm5.threat.sev.fmt' @([string]$SevId)) }
        }
    }
    return (T 'm5.threat.sev.unknown')
}

function Get-WCM5CategoryText {
    # CategoryID map pho bien (best-effort; gia tri khac hien so goc)
    param($CatId)
    if ($null -eq $CatId) { return (T 'm5.threat.sev.unknown') }
    switch ([int]$CatId) {
        1 { return (T 'm5.threat.cat.1') }
        2 { return (T 'm5.threat.cat.2') }
        5 { return (T 'm5.threat.cat.5') }
        6 { return (T 'm5.threat.cat.6') }
        8 { return (T 'm5.threat.cat.8') }
        10 { return (T 'm5.threat.cat.10') }
        30 { return (T 'm5.threat.cat.30') }
        default { return (T 'm5.threat.cat.fmt' @([string]$CatId)) }
    }
}

function Get-WCM5ThreatStatusText {
    # ThreatStatusID map pho bien (best-effort; gia tri khac hien ma goc)
    param($StatusId)
    if ($null -eq $StatusId) { return (T 'm5.threat.sev.unknown') }
    switch ([int]$StatusId) {
        1 { return (T 'm5.threat.status.1') }
        2 { return (T 'm5.threat.status.2') }
        3 { return (T 'm5.threat.status.3') }
        4 { return (T 'm5.threat.status.4') }
        5 { return (T 'm5.threat.status.5') }
        6 { return (T 'm5.threat.status.6') }
        default { return (T 'm5.threat.status.fmt' @([string]$StatusId)) }
    }
}

function Get-WCM5ThreatsRaw {
    # Gop Get-MpThreat (ten, muc do) + Get-MpThreatDetection (tai nguyen, trang thai)
    $threats = @()
    $dets = @()
    try { $threats = @(Get-MpThreat -ErrorAction Stop) } catch { }
    try { $dets = @(Get-MpThreatDetection -ErrorAction Stop) } catch { }
    $detById = @{}
    foreach ($d in $dets) {
        if ($null -eq $d) { continue }
        $id = Get-WCProp $d 'ThreatID'
        if ($null -eq $id) { continue }
        $key = [string]$id
        if (-not $detById.ContainsKey($key)) { $detById[$key] = $d }
    }
    $rows = @()
    foreach ($t in $threats) {
        if ($null -eq $t) { continue }
        $id = Get-WCProp $t 'ThreatID'
        $key = ''
        if ($null -ne $id) { $key = [string]$id }
        $name = [string](Get-WCProp $t 'ThreatName')
        if ([string]::IsNullOrEmpty($name)) { $name = ('Threat #' + $key) }
        $d = $null
        if ($key -and $detById.ContainsKey($key)) { $d = $detById[$key] }
        $resTxt = ''
        $srcRes = $null
        if ($d) { $srcRes = Get-WCProp $d 'Resources' }
        if ($null -eq $srcRes) { $srcRes = Get-WCProp $t 'Resources' }
        if ($null -ne $srcRes) { $resTxt = [string]::Join(' | ', @($srcRes)) }
        $time = $null
        if ($d) { $time = Get-WCProp $d 'InitialDetectionTime' }
        $statusId = $null
        if ($d) { $statusId = Get-WCProp $d 'ThreatStatusID' }
        if ($null -eq $statusId) { $statusId = Get-WCProp $t 'ThreatStatusID' }
        $rows += [PSCustomObject]@{
            ThreatID = $id
            Name = $name
            Type = (Get-WCM5CategoryText (Get-WCProp $t 'CategoryID'))
            Severity = (Get-WCM5SeverityText (Get-WCProp $t 'Severity') (Get-WCProp $t 'SeverityID'))
            Resources = $resTxt
            Status = (Get-WCM5ThreatStatusText $statusId)
            DetectedAt = $time
            Active = (Get-WCProp $t 'IsActive')
        }
    }
    return $rows
}

# ---------------------------------------------------------------------------
# LOP 3 — HEURISTIC DAU HIEU BAT THUONG
# ---------------------------------------------------------------------------
function Test-WCM5SuspiciousLocation {
    # Temp / Public / AppData\Local\Temp -> vi tri "dang ngo"
    param([Parameter(Mandatory)][string]$Path)
    try {
        $p = $Path.ToLowerInvariant()
        if ($p.Contains('\temp\')) { return $true }
        if ($p.Contains('\appdata\local\temp\')) { return $true }
        if ($p.Contains('\users\public\')) { return $true }
    } catch { }
    return $false
}

function Get-WCM5CommandExePath {
    # Trich duong dan exe tu dong lenh (co the co tham so, co/khong ngoac kep)
    param([string]$Command)
    if ([string]::IsNullOrWhiteSpace($Command)) { return '' }
    $c = $Command.Trim()
    if ($c.StartsWith('"')) {
        $idx = $c.IndexOf('"', 1)
        if ($idx -gt 1) { return $c.Substring(1, ($idx - 1)) }
        return $c.Trim('"')
    }
    if (-not $c.Contains(' ')) { return $c }
    $m = [regex]::Match($c, '(?i)^(.{2,}?\.(exe|bat|cmd|com|scr|pif|ps1|vbs|js|jar|msi))(\s|$)')
    if ($m.Success) { return $m.Groups[1].Value }
    return ($c.Split(' ')[0])
}

function Get-WCM5AuthenticodeInfo {
    # Kiem chu ky so, cache theo path + LastWriteTime trong hashtable truyen vao
    param([string]$FilePath, $Cache)
    if ([string]::IsNullOrEmpty($FilePath)) { return $null }
    try {
        if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
            return @{ Status = 'Missing'; Signer = '' }
        }
    } catch { return @{ Status = 'Missing'; Signer = '' } }
    $stamp = ''
    try {
        $fi = Get-Item -LiteralPath $FilePath -ErrorAction Stop
        $stamp = [string]$fi.LastWriteTimeUtc.Ticks
    } catch { $stamp = '' }
    $ck = ($FilePath + '|' + $stamp)
    if ($Cache -and $Cache.ContainsKey($ck)) { return $Cache[$ck] }
    $info = $null
    try {
        $sig = Get-AuthenticodeSignature -LiteralPath $FilePath -ErrorAction Stop
        $st = [string](Get-WCProp $sig 'Status')
        $signer = ''
        try {
            $sc = Get-WCProp $sig 'SignerCertificate'
            if ($sc) { $signer = [string]$sc.Subject }
        } catch { }
        $status = 'Unknown'
        if ($st -eq 'Valid') { $status = 'Valid' }
        elseif ($st -eq 'NotSigned') { $status = 'NotSigned' }
        elseif (-not [string]::IsNullOrEmpty($st)) { $status = 'Invalid' }
        $info = @{ Status = $status; Signer = $signer }
    } catch {
        $info = @{ Status = 'Unknown'; Signer = '' }
    }
    if ($Cache) { $Cache[$ck] = $info }
    return $info
}

function Get-WCM5AssessTarget {
    # Danh gia 1 muc tieu (exe + lenh): 3 muc Ok/Warn/Bad + mang ly do cu the
    param([string]$ExePath, [string]$Command, $Cache, [switch]$SkipUnquoted)
    if ([string]::IsNullOrEmpty($ExePath)) {
        return @{ Level = 'Warn'; Reasons = @((T 'm5.h.noexe')) }
    }
    $level = 'Ok'
    $reasons = @()
    if (Test-WCM5SuspiciousLocation $ExePath) {
        $level = 'Bad'
        $reasons += (T 'm5.h.location')
    }
    if (-not $SkipUnquoted) {
        $cmdTxt = [string]$Command
        $quoted = $false
        if ($cmdTxt.Length -gt 0) { $quoted = $cmdTxt.StartsWith('"') }
        if ($ExePath.Contains(' ') -and (-not $quoted)) {
            if ($level -ne 'Bad') { $level = 'Warn' }
            $reasons += (T 'm5.h.unquoted')
        }
    }
    $sig = Get-WCM5AuthenticodeInfo -FilePath $ExePath -Cache $Cache
    if ($null -eq $sig) {
        if ($level -ne 'Bad') { $level = 'Warn' }
        $reasons += (T 'm5.h.nofile')
    } elseif ($sig.Status -eq 'Valid') {
        $reasons += (T 'm5.h.signed' @($sig.Signer))
    } elseif ($sig.Status -eq 'Missing') {
        # Tep khong ton tai (da go cai dat / entry bo vo nghia) -> dang "can xem"
        if ($level -ne 'Bad') { $level = 'Warn' }
        $reasons += (T 'm5.h.nofile')
    } else {
        if ($level -ne 'Bad') { $level = 'Warn' }
        $reasons += (T 'm5.h.unsigned')
    }
    return @{ Level = $level; Reasons = $reasons }
}

function New-WCM5Finding {
    # Object chuan cua 1 ket qua heuristic
    param([string]$Group, [string]$Title, [string]$Command, [string]$Path, [string]$Level,
          [string[]]$Reasons, [string]$OpenKind, [string]$OpenPath, [string]$RegPath,
          [bool]$CanDisable = $false, [string]$DisApproved = '', [string]$DisNetPath = '', [string]$DisValueName = '')
    if ([string]::IsNullOrEmpty($Level)) { $Level = 'Unknown' }
    return [PSCustomObject]@{
        Group = $Group; Title = $Title; Command = $Command; Path = $Path; Level = $Level
        Reasons = @($Reasons); OpenKind = $OpenKind; OpenPath = $OpenPath; RegPath = $RegPath
        CanDisable = $CanDisable; DisApproved = $DisApproved; DisNetPath = $DisNetPath; DisValueName = $DisValueName
    }
}

function Get-WCM5RunFindings {
    # Run/RunOnce: HKLM + HKCU + WOW6432Node. Moi gia tri 3 muc kem ly do.
    # Vo hieu hoa (chi voi Run): ghi StartupApproved nhu Task Manager.
    param($Cache)
    $findings = @()
    $sources = @(
        @{ PsPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run';     Wow = $false; Kind = 'Run' }
        @{ PsPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce'; Wow = $false; Kind = 'RunOnce' }
        @{ PsPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run';     Wow = $false; Kind = 'Run' }
        @{ PsPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'; Wow = $false; Kind = 'RunOnce' }
        @{ PsPath = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run';     Wow = $true; Kind = 'Run' }
        @{ PsPath = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce'; Wow = $true; Kind = 'RunOnce' }
    )
    foreach ($src in $sources) {
        $key = $null
        try { $key = Get-Item -LiteralPath $src['PsPath'] -ErrorAction Stop } catch { continue }
        foreach ($vn in @($key.GetValueNames())) {
            $cmd = ''
            try { $cmd = [string]$key.GetValue($vn) } catch { }
            if ([string]::IsNullOrWhiteSpace($cmd)) { continue }
            $exe = Get-WCM5CommandExePath -Command $cmd
            $a = Get-WCM5AssessTarget -ExePath $exe -Command $cmd -Cache $Cache
            $canDis = ($src['Kind'] -eq 'Run')
            $approved = ''
            $netPath = ''
            if ($canDis) {
                if ($src['PsPath'].StartsWith('HKCU:')) {
                    $approved = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
                    $netPath = 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
                } elseif ($src['Wow']) {
                    $approved = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32'
                    $netPath = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32'
                } else {
                    $approved = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
                    $netPath = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
                }
            }
            $reasons = @((T 'm5.h.run')) + @($a.Reasons)
            $findings += (New-WCM5Finding -Group 'run' -Title ([string]$vn) -Command $cmd -Path $exe -Level $a.Level `
                -Reasons $reasons -OpenKind 'reg' -OpenPath '' -RegPath $src['PsPath'] `
                -CanDisable $canDis -DisApproved $approved -DisNetPath $netPath -DisValueName ([string]$vn))
        }
        try { $key.Close() } catch { }
    }
    return [PSCustomObject]@{ Findings = $findings; Error = '' }
}

function Get-WCM5StartupFindings {
    # Thu muc Startup (user + common); .lnk doc muc tieu qua COM WScript.Shell
    param($Cache)
    $findings = @()
    $folders = @(
        @{ Path = [Environment]::GetFolderPath('Startup');       Machine = $false }
        @{ Path = [Environment]::GetFolderPath('CommonStartup'); Machine = $true }
    )
    $sh = $null
    foreach ($f in $folders) {
        $dir = [string]$f['Path']
        if ([string]::IsNullOrEmpty($dir)) { continue }
        try { if (-not (Test-Path -LiteralPath $dir)) { continue } } catch { continue }
        $files = @()
        try { $files = @(Get-ChildItem -LiteralPath $dir -File -Force -ErrorAction Stop) } catch { continue }
        foreach ($file in $files) {
            $target = ''
            if ($file.Extension -ieq '.lnk') {
                if (-not $sh) {
                    try { $sh = New-Object -ComObject WScript.Shell } catch { $sh = $null }
                }
                if ($sh) {
                    try {
                        $lnk = $sh.CreateShortcut($file.FullName)
                        $target = [string]$lnk.TargetPath
                        try { $null = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($lnk) } catch { }
                    } catch { $target = '' }
                }
            } else {
                $target = $file.FullName
            }
            $a = $null
            if (-not [string]::IsNullOrEmpty($target)) {
                # TargetPath la duong dan thu (khong phai dong lenh) -> bo qua check ngoac
                $a = Get-WCM5AssessTarget -ExePath $target -Command ('"' + $target + '"') -Cache $Cache
            } else {
                $a = @{ Level = 'Warn'; Reasons = @((T 'm5.h.noexe')) }
            }
            if ($f['Machine']) {
                $approved = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'
                $netPath = 'HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'
            } else {
                $approved = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'
                $netPath = 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'
            }
            $reasons = @((T 'm5.h.startup')) + @($a.Reasons)
            $cmdTxt = $file.FullName
            if (-not [string]::IsNullOrEmpty($target)) { $cmdTxt = $target }
            $findings += (New-WCM5Finding -Group 'startup' -Title $file.Name -Command $cmdTxt `
                -Path $target -Level $a.Level -Reasons $reasons -OpenKind 'file' -OpenPath $file.FullName `
                -RegPath '' -CanDisable $true -DisApproved $approved -DisNetPath $netPath -DisValueName $file.Name)
        }
    }
    if ($sh) { try { $null = [System.Runtime.InteropServices.Marshal]::ReleaseComObject($sh) } catch { } }
    return [PSCustomObject]@{ Findings = $findings; Error = '' }
}

function Get-WCM5TaskFindings {
    # Scheduled Task ngoai Microsoft (TaskPath / Author khong gom Microsoft)
    param($Cache)
    $findings = @()
    $tasks = @()
    try { $tasks = @(Get-ScheduledTask -ErrorAction Stop) } catch {
        return [PSCustomObject]@{ Findings = $findings; Error = $_.Exception.Message }
    }
    foreach ($t in $tasks) {
        if ($null -eq $t) { continue }
        $taskPath = [string](Get-WCProp $t 'TaskPath')
        $author = [string](Get-WCProp $t 'Author')
        if ($taskPath -like '\Microsoft\*') { continue }
        if ($author -like '*Microsoft*') { continue }
        $taskName = [string](Get-WCProp $t 'TaskName')
        $state = [string](Get-WCProp $t 'State')
        $execs = @()
        $actions = Get-WCProp $t 'Actions'
        foreach ($act in @($actions)) {
            if ($null -eq $act) { continue }
            $e = [string](Get-WCProp $act 'Execute')
            if (-not [string]::IsNullOrEmpty($e)) { $execs += $e }
        }
        $execTxt = [string]::Join(' ; ', @($execs))
        if ([string]::IsNullOrEmpty($execTxt)) { $execTxt = '(?)' }
        $exe = ''
        if (@($execs).Count -gt 0) { $exe = Get-WCM5CommandExePath -Command ([string]$execs[0]) }
        # Execute cua task la truong rieng (khong tach argv) -> bo qua check ngoac kep
        $a = Get-WCM5AssessTarget -ExePath $exe -Command ('"' + $exe + '"') -Cache $Cache
        $reasons = @((T 'm5.h.task')) + @($a.Reasons)
        $level = $a.Level
        if ($level -eq 'Ok') { $level = 'Warn' }
        $cmdTxt = $execTxt
        if (-not [string]::IsNullOrEmpty($state)) { $cmdTxt = $cmdTxt + '  [' + $state + ']' }
        $findings += (New-WCM5Finding -Group 'task' -Title ($taskPath + $taskName) -Command $cmdTxt -Path $exe `
            -Level $level -Reasons $reasons -OpenKind 'taskschd' -OpenPath '' -RegPath '' -CanDisable $false)
    }
    return [PSCustomObject]@{ Findings = $findings; Error = '' }
}

function Get-WCM5ServiceFindings {
    # Dich vu auto-start ngoai thu muc Windows; duong dan khong ngoac + khoang trang -> canh bao
    param($Cache)
    $findings = @()
    $svcs = @()
    try {
        $svcs = @(Get-CimInstance -ClassName Win32_Service -Filter "StartMode='Auto'" `
            -Property Name,DisplayName,State,StartMode,PathName -OperationTimeoutSec 15 -ErrorAction Stop)
    } catch {
        return [PSCustomObject]@{ Findings = $findings; Error = $_.Exception.Message }
    }
    foreach ($s in $svcs) {
        if ($null -eq $s) { continue }
        $pn = [string](Get-WCProp $s 'PathName')
        if ([string]::IsNullOrWhiteSpace($pn)) { continue }
        if ($pn -like '*\Windows\*') { continue }
        $name = [string](Get-WCProp $s 'Name')
        $disp = [string](Get-WCProp $s 'DisplayName')
        $state = [string](Get-WCProp $s 'State')
        $exe = Get-WCM5CommandExePath -Command $pn
        $a = Get-WCM5AssessTarget -ExePath $exe -Command $pn -Cache $Cache
        $reasons = @((T 'm5.h.svc')) + @($a.Reasons)
        $level = $a.Level
        if ($level -eq 'Ok') { $level = 'Warn' }
        $findings += (New-WCM5Finding -Group 'svc' -Title ($disp + ' (' + $name + ')') `
            -Command ($pn + '  [' + $state + ']') -Path $exe -Level $level -Reasons $reasons `
            -OpenKind 'svc' -OpenPath $exe -RegPath '' -CanDisable $false)
    }
    return [PSCustomObject]@{ Findings = $findings; Error = '' }
}

function Get-WCM5WinlogonFindings {
    # Shell chuan = "explorer.exe"; Userinit chuan chua "userinit.exe,"
    $findings = @()
    $regPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    $shell = Get-WCRegistryValue -Path $regPath -Name 'Shell'
    $shellTxt = ''
    if ($null -ne $shell) { $shellTxt = ([string]$shell).Trim() }
    if ($null -eq $shell) {
        $findings += (New-WCM5Finding -Group 'winlogon' -Title 'Shell' -Command '' -Path '' -Level 'Unknown' `
            -Reasons @((T 'common.notread')) -OpenKind 'reg' -OpenPath '' -RegPath $regPath -CanDisable $false)
    } elseif ($shellTxt -eq 'explorer.exe') {
        $findings += (New-WCM5Finding -Group 'winlogon' -Title 'Shell' -Command $shellTxt -Path '' -Level 'Ok' `
            -Reasons @((T 'm5.h.shell.ok')) -OpenKind 'reg' -OpenPath '' -RegPath $regPath -CanDisable $false)
    } else {
        $findings += (New-WCM5Finding -Group 'winlogon' -Title 'Shell' -Command $shellTxt -Path '' -Level 'Bad' `
            -Reasons @((T 'm5.h.shell.bad')) -OpenKind 'reg' -OpenPath '' -RegPath $regPath -CanDisable $false)
    }
    $userinit = Get-WCRegistryValue -Path $regPath -Name 'Userinit'
    $uiTxt = ''
    if ($null -ne $userinit) { $uiTxt = [string]$userinit }
    if ($null -eq $userinit) {
        $findings += (New-WCM5Finding -Group 'winlogon' -Title 'Userinit' -Command '' -Path '' -Level 'Unknown' `
            -Reasons @((T 'common.notread')) -OpenKind 'reg' -OpenPath '' -RegPath $regPath -CanDisable $false)
    } elseif ($uiTxt -like '*userinit.exe*') {
        $findings += (New-WCM5Finding -Group 'winlogon' -Title 'Userinit' -Command $uiTxt -Path '' -Level 'Ok' `
            -Reasons @((T 'm5.h.userinit.ok')) -OpenKind 'reg' -OpenPath '' -RegPath $regPath -CanDisable $false)
    } else {
        $findings += (New-WCM5Finding -Group 'winlogon' -Title 'Userinit' -Command $uiTxt -Path '' -Level 'Bad' `
            -Reasons @((T 'm5.h.userinit.bad')) -OpenKind 'reg' -OpenPath '' -RegPath $regPath -CanDisable $false)
    }
    return [PSCustomObject]@{ Findings = $findings; Error = '' }
}

function Get-WCM5IfeoFindings {
    # IFEO Debugger: gia tri nao co -> liet ke (best-effort, co the la cong cu hop le)
    param($Cache)
    $findings = @()
    $rootPs = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options'
    $subs = @()
    try { $subs = @(Get-ChildItem -LiteralPath $rootPs -ErrorAction Stop) } catch {
        return [PSCustomObject]@{ Findings = $findings; Error = '' }
    }
    foreach ($sub in $subs) {
        if ($null -eq $sub) { continue }
        $childName = ''
        try { $childName = [string]$sub.PSChildName } catch { }
        if ([string]::IsNullOrEmpty($childName)) { continue }
        $dbg = ''
        try { $dbg = [string]$sub.GetValue('Debugger') } catch { }
        if ([string]::IsNullOrWhiteSpace($dbg)) { continue }
        $exe = Get-WCM5CommandExePath -Command $dbg
        $a = Get-WCM5AssessTarget -ExePath $exe -Command $dbg -Cache $Cache
        $reasons = @((T 'm5.h.ifeo')) + @($a.Reasons)
        $level = $a.Level
        if ($level -eq 'Ok') { $level = 'Warn' }
        $findings += (New-WCM5Finding -Group 'ifeo' -Title ($childName + ' - Debugger') -Command $dbg -Path $exe `
            -Level $level -Reasons $reasons -OpenKind 'reg' -OpenPath '' `
            -RegPath ($rootPs + '\' + $childName) -CanDisable $false)
    }
    return [PSCustomObject]@{ Findings = $findings; Error = '' }
}

function Get-WCM5WmiFindings {
    # __EventFilter / __EventConsumer / (binding ngam: consumer la phan nguy hiem)
    $findings = @()
    $consumers = @()
    try { $consumers = @(Get-CimInstance -Namespace 'root\subscription' -ClassName '__EventConsumer' -ErrorAction Stop) } catch {
        return [PSCustomObject]@{ Findings = $findings; Error = '' }
    }
    foreach ($c in $consumers) {
        if ($null -eq $c) { continue }
        $name = [string](Get-WCProp $c 'Name')
        $cmdl = [string](Get-WCProp $c 'CommandLineTemplate')
        $scriptTxt = [string](Get-WCProp $c 'ScriptText')
        $detail = ''
        if (-not [string]::IsNullOrEmpty($cmdl)) { $detail = $cmdl }
        elseif (-not [string]::IsNullOrEmpty($scriptTxt)) { $detail = ('script: ' + $scriptTxt) }
        else { $detail = $name }
        $exe = Get-WCM5CommandExePath -Command $detail
        $level = 'Warn'
        if (-not [string]::IsNullOrEmpty($exe)) {
            if (Test-WCM5SuspiciousLocation $exe) { $level = 'Bad' }
        }
        $findings += (New-WCM5Finding -Group 'wmi' -Title ('__EventConsumer: ' + $name) -Command $detail -Path $exe `
            -Level $level -Reasons @((T 'm5.h.wmi')) -OpenKind 'none' -OpenPath '' -RegPath '' -CanDisable $false)
    }
    $filters = @()
    try { $filters = @(Get-CimInstance -Namespace 'root\subscription' -ClassName '__EventFilter' -ErrorAction Stop) } catch { }
    foreach ($f in $filters) {
        if ($null -eq $f) { continue }
        $name = [string](Get-WCProp $f 'Name')
        $query = [string](Get-WCProp $f 'Query')
        $findings += (New-WCM5Finding -Group 'wmi' -Title ('__EventFilter: ' + $name) -Command $query -Path '' `
            -Level 'Warn' -Reasons @((T 'm5.h.wmi')) -OpenKind 'none' -OpenPath '' -RegPath '' -CanDisable $false)
    }
    return [PSCustomObject]@{ Findings = $findings; Error = '' }
}

function Get-WCM5ExclusionFindings {
    # ExclusionPath/Extension/Process cua Defender — ma doc hay tu them
    $findings = @()
    $pref = $null
    try { $pref = Get-MpPreference -ErrorAction Stop } catch {
        return [PSCustomObject]@{ Findings = $findings; Error = $_.Exception.Message }
    }
    $paths = @(Get-WCProp $pref 'ExclusionPath')
    $exts = @(Get-WCProp $pref 'ExclusionExtension')
    $procs = @(Get-WCProp $pref 'ExclusionProcess')
    foreach ($p in $paths) {
        if ([string]::IsNullOrEmpty([string]$p)) { continue }
        $findings += (New-WCM5Finding -Group 'excl' -Title ([string]$p) -Command ([string]$p) -Path ([string]$p) `
            -Level 'Warn' -Reasons @((T 'm5.h.excl.path')) -OpenKind 'file' -OpenPath ([string]$p) -RegPath '' -CanDisable $false)
    }
    foreach ($e in $exts) {
        if ([string]::IsNullOrEmpty([string]$e)) { continue }
        $findings += (New-WCM5Finding -Group 'excl' -Title ('*.' + [string]$e) -Command ([string]$e) -Path '' `
            -Level 'Warn' -Reasons @((T 'm5.h.excl.ext' @([string]$e))) -OpenKind 'none' -OpenPath '' -RegPath '' -CanDisable $false)
    }
    foreach ($pr in $procs) {
        if ([string]::IsNullOrEmpty([string]$pr)) { continue }
        $findings += (New-WCM5Finding -Group 'excl' -Title ([string]$pr) -Command ([string]$pr) -Path '' `
            -Level 'Warn' -Reasons @((T 'm5.h.excl.proc' @([string]$pr))) -OpenKind 'none' -OpenPath '' -RegPath '' -CanDisable $false)
    }
    if ($findings.Count -eq 0) {
        $findings += (New-WCM5Finding -Group 'excl' -Title 'Exclusions' -Command '' -Path '' -Level 'Ok' `
            -Reasons @((T 'm5.h.excl.none')) -OpenKind 'none' -OpenPath '' -RegPath '' -CanDisable $false)
    }
    return [PSCustomObject]@{ Findings = $findings; Error = '' }
}

function Get-WCM5HostsFindings {
    # Doc hosts; dong khong phai comment/localhost -> liet ke
    $findings = @()
    $hostsPath = ''
    try { $hostsPath = Join-Path ([Environment]::GetFolderPath('System')) 'drivers\etc\hosts' } catch {
        return [PSCustomObject]@{ Findings = $findings; Error = $_.Exception.Message }
    }
    $lines = @()
    try { $lines = [IO.File]::ReadAllLines($hostsPath) } catch {
        return [PSCustomObject]@{ Findings = $findings; Error = $_.Exception.Message }
    }
    foreach ($ln in $lines) {
        $t = ''
        try { $t = ([string]$ln).Trim() } catch { continue }
        if ([string]::IsNullOrEmpty($t)) { continue }
        if ($t.StartsWith('#')) { continue }
        if ($t -match '(?i)localhost') { continue }
        $findings += (New-WCM5Finding -Group 'hosts' -Title $t -Command $t -Path '' -Level 'Warn' `
            -Reasons @((T 'm5.h.hosts')) -OpenKind 'hosts' -OpenPath $hostsPath -RegPath '' -CanDisable $false)
    }
    if ($findings.Count -eq 0) {
        $findings += (New-WCM5Finding -Group 'hosts' -Title 'hosts' -Command $hostsPath -Path '' -Level 'Ok' `
            -Reasons @((T 'm5.h.hosts.ok')) -OpenKind 'hosts' -OpenPath $hostsPath -RegPath '' -CanDisable $false)
    }
    return [PSCustomObject]@{ Findings = $findings; Error = '' }
}

function Get-WCM5ProxyFindings {
    # WinINET: ProxyServer/ProxyOverride/AutoConfigURL (HKCU)
    $findings = @()
    $is = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
    $enable = Get-WCRegistryValue -Path $is -Name 'ProxyEnable'
    $server = Get-WCRegistryValue -Path $is -Name 'ProxyServer'
    $override = Get-WCRegistryValue -Path $is -Name 'ProxyOverride'
    $pac = Get-WCRegistryValue -Path $is -Name 'AutoConfigURL'
    if (($enable -eq 1) -and ($null -ne $server)) {
        $detail = [string]$server
        if ($null -ne $override) { $detail = $detail + '  (bỏ qua: ' + [string]$override + ')' }
        $findings += (New-WCM5Finding -Group 'proxy' -Title 'Proxy' -Command $detail -Path '' -Level 'Warn' `
            -Reasons @((T 'm5.h.proxy')) -OpenKind 'reg' -OpenPath '' -RegPath $is -CanDisable $false)
    }
    if ($null -ne $pac) {
        $findings += (New-WCM5Finding -Group 'proxy' -Title 'AutoConfigURL (PAC)' -Command ([string]$pac) -Path '' `
            -Level 'Warn' -Reasons @((T 'm5.h.proxy')) -OpenKind 'reg' -OpenPath '' -RegPath $is -CanDisable $false)
    }
    if ($findings.Count -eq 0) {
        $findings += (New-WCM5Finding -Group 'proxy' -Title 'Proxy / PAC' -Command '' -Path '' -Level 'Ok' `
            -Reasons @((T 'm5.h.proxy.none')) -OpenKind 'reg' -OpenPath '' -RegPath $is -CanDisable $false)
    }
    return [PSCustomObject]@{ Findings = $findings; Error = '' }
}

function Get-WCM5HeuristicsGroup {
    # Chay 1 nhom heuristic (goi tu worker; loi bat trong nay khong lam sap task)
    param([Parameter(Mandatory)][string]$Group, $Cache)
    try {
        switch ($Group) {
            'run'      { return (Get-WCM5RunFindings -Cache $Cache) }
            'startup'  { return (Get-WCM5StartupFindings -Cache $Cache) }
            'task'     { return (Get-WCM5TaskFindings -Cache $Cache) }
            'svc'      { return (Get-WCM5ServiceFindings -Cache $Cache) }
            'winlogon' { return (Get-WCM5WinlogonFindings) }
            'ifeo'     { return (Get-WCM5IfeoFindings -Cache $Cache) }
            'wmi'      { return (Get-WCM5WmiFindings) }
            'excl'     { return (Get-WCM5ExclusionFindings) }
            'hosts'    { return (Get-WCM5HostsFindings) }
            'proxy'    { return (Get-WCM5ProxyFindings) }
        }
        return [PSCustomObject]@{ Findings = @(); Error = ('Unknown group: ' + $Group) }
    } catch {
        return [PSCustomObject]@{ Findings = @(); Error = $_.Exception.Message }
    }
}

# ---------------------------------------------------------------------------
# HANH DONG (vo hieu hoa muc khoi dong — dao nguoc duoc qua journal)
# ---------------------------------------------------------------------------
function Invoke-WCM5DisableStartup {
    # Vo hieu hoa muc Run key / Startup folder bang StartupApproved (12 byte
    # 02 00 ... nhu Task Manager). KHONG xoa gia tri goc. Ghi journal voi
    # UndoType 'startup.enable' (handler co san trong 05-Journal.ps1) de bat lai.
    param($State, $Finding)
    $f = $Finding
    $approved = [string](Get-WCProp $f 'DisApproved')
    $netPath = [string](Get-WCProp $f 'DisNetPath')
    $vn = [string](Get-WCProp $f 'DisValueName')
    $title = [string](Get-WCProp $f 'Title')
    if ([string]::IsNullOrEmpty($approved) -or [string]::IsNullOrEmpty($vn)) {
        Show-WCToast (T 'common.nodata') 'Warn'
        return
    }
    $msg = (T 'm5.dis.confirm.msg' @($title))
    if (-not (Show-WCConfirm -Title (T 'm5.dis.confirm.title') -Message $msg -Undoable (T 'm5.dis.confirm.undo'))) { return }
    if (Test-WCDryRunMode) {
        Show-WCInfo -Title (T 'common.dryrun.header') -Message ('[DRY-RUN] ' + $approved + ' -> ' + $vn + ' = 02 00 00 00 00 00 00 00 00 00 00 00')
        return
    }
    # Ghi journal TRUOC khi lam (spec 2.4); UndoArgs dung cho handler 'startup.enable'
    $entry = Add-WCJournalEntry -Module 'M5' -Action (T 'm5.journal.disable') -Target $title `
        -OldValue (T 'm5.dis.enabled') -UndoType 'startup.enable' -UndoArgs @{
            RegPath = $netPath; ValueName = $vn }
    try {
        if (-not (Test-Path -LiteralPath $approved)) {
            New-Item -Path $approved -ItemType Directory -Force -ErrorAction Stop | Out-Null
        }
        # 12 byte: 02 00 00 00 00 00 00 00 00 00 00 00 = "da tat" (12 byte 0 = bat lai)
        New-ItemProperty -Path $approved -Name $vn -Value ([byte[]](2,0,0,0,0,0,0,0,0,0,0,0)) `
            -PropertyType Binary -Force -ErrorAction Stop | Out-Null
        Complete-WCJournalEntry -Entry $entry -Result 'Ok'
        Show-WCToast (T 'common.success') 'Ok'
        Invoke-WCM5HeurScan $State
    } catch {
        Complete-WCJournalEntry -Entry $entry -Result ('Failed: ' + $_.Exception.Message)
        Show-WCError (T 'common.error') $_.Exception.Message
    }
}

# ---------------------------------------------------------------------------
# UI — LOP 1
# ---------------------------------------------------------------------------
function New-WCM5L1Block {
    # 1 khoi trang thai: header (tieu de + chip) + body (skeleton khi dang tai)
    param($Parent, [string]$Title)
    $outer = New-WCVStack -Spacing 4
    $header = New-WCHStack -Spacing 10
    $t = New-WCTextBlock -Text $Title -Size 13.5 -Weight 'SemiBold'
    $t.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $null = Add-WCChild $header $t
    $chip = New-WCStatusChip -Status 'Unknown'
    $chip.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $null = Add-WCChild $header $chip
    $null = Add-WCChild $outer $header
    $body = New-WCVStack -Spacing 5
    $skel = New-WCSkeleton
    $null = Add-WCChild $body $skel
    $null = Add-WCChild $outer $body
    $null = Add-WCChild $outer (New-WCSpacer -Height 6)
    $null = Add-WCChild $Parent $outer
    return @{ Root = $outer; Body = $body; Chip = $chip; Skeleton = $skel }
}

function Reset-WCM5BlockBody {
    param($Block)
    $Block['Skeleton'].Visibility = [Windows.Visibility]::Collapsed
    $Block['Body'].Children.Clear()
}

function Set-WCM5BlockChip {
    param($Block, [string]$Status)
    $bgKey = 'WcUnknownBg'
    $fgKey = 'WcUnknown'
    switch ($Status) {
        'Ok'   { $bgKey = 'WcOkBg';   $fgKey = 'WcOk' }
        'Warn' { $bgKey = 'WcWarnBg'; $fgKey = 'WcWarn' }
        'Bad'  { $bgKey = 'WcBadBg';  $fgKey = 'WcBad' }
    }
    $chip = $Block['Chip']
    try {
        $chip.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, $bgKey)
        if ($chip.Tag -is [Windows.Controls.TextBlock]) {
            $chip.Tag.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, $fgKey)
            $chip.Tag.Text = (T ('common.status.' + $Status.ToLower()))
        }
    } catch { }
}

function Add-WCM5BlockLine {
    # 1 dong: chip trang thai + chu
    param($Body, [string]$Status, [string]$Text)
    $h = New-WCHStack -Spacing 8
    $chip = New-WCStatusChip -Status $Status
    $chip.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $null = Add-WCChild $h $chip
    $t = New-WCTextBlock -Text $Text -Size 12.5 -Wrap
    $t.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $null = Add-WCChild $h $t
    $null = Add-WCChild $Body $h
}

function Add-WCM5BlockGuide {
    # Dong huong dan "cach bat" (khong tu bat)
    param($Body, [string]$Text)
    $t = New-WCTextBlock -Text ('→ ' + $Text) -Size 11.5 -ColorKey 'WcSubtle' -Wrap
    $null = Add-WCChild $Body $t
}

function Add-WCM5BlockField {
    param($Body, [string]$Label, [string]$Value)
    $null = Add-WCChild $Body (New-WCFieldRow -Label $Label -Value $Value)
}

function Update-WCM5DefenderBlock {
    param($Block, $Result)
    Reset-WCM5BlockBody $Block
    if (($Result.Status -ne 'Ok') -or ($null -eq $Result.Data)) {
        Set-WCM5BlockChip $Block 'Unknown'
        Add-WCM5BlockLine $Block['Body'] 'Unknown' (T 'common.notread.fmt' @($Result.Reason))
        Add-WCM5BlockLine $Block['Body'] 'Bad' (T 'm5.def.mode.off')
        return
    }
    $d = $Result.Data
    $statuses = @()
    # Che do hoat dong (kem passive do AV ben thu ba)
    $mode = [string](Get-WCProp $d 'AMRunningMode')
    $modeStatus = 'Unknown'
    $modeTxt = ''
    if ($mode -eq 'Normal') { $modeStatus = 'Ok'; $modeTxt = (T 'm5.def.mode.normal') }
    elseif ($mode -like '*Passive*') { $modeStatus = 'Warn'; $modeTxt = (T 'm5.def.mode.passive') }
    else { $modeStatus = 'Bad'; $modeTxt = (T 'm5.def.mode.off') }
    $statuses += $modeStatus
    Add-WCM5BlockLine $Block['Body'] $modeStatus (T 'm5.def.mode' @($modeTxt))
    # Bao ve thoi gian thuc
    $rtp = Get-WCProp $d 'RealTimeProtectionEnabled'
    $rtpStatus = 'Unknown'
    if ($rtp -eq $true) { $rtpStatus = 'Ok' }
    elseif ($rtp -eq $false) { $rtpStatus = 'Bad' }
    $statuses += $rtpStatus
    Add-WCM5BlockLine $Block['Body'] $rtpStatus (T 'm5.def.rtp')
    if ($rtpStatus -eq 'Bad') { Add-WCM5BlockGuide $Block['Body'] (T 'm5.def.rtp.how') }
    # Chu ky virus
    $age = Get-WCProp $d 'AntivirusSignatureAge'
    $lastUpd = Get-WCProp $d 'AntivirusSignatureLastUpdated'
    $sigStatus = 'Unknown'
    if ($null -ne $age) {
        $sigStatus = 'Ok'
        if ([double]$age -gt 7) { $sigStatus = 'Warn' }
        Add-WCM5BlockLine $Block['Body'] $sigStatus (T 'm5.def.sig.age' @([string][int]$age, (ConvertTo-WCM5TimeText $lastUpd)))
        if ($sigStatus -eq 'Warn') { Add-WCM5BlockGuide $Block['Body'] (T 'm5.def.sig.stale') }
    } else {
        Add-WCM5BlockLine $Block['Body'] 'Unknown' (T 'm5.def.sig.unknown')
    }
    $statuses += $sigStatus
    # Engine
    $eng = Get-WCProp $d 'AntivirusEngineVersion'
    if ($null -ne $eng) { Add-WCM5BlockField $Block['Body'] (T 'm5.def.engine') ([string]$eng) }
    # Lan quet gan nhat
    $qs = Get-WCProp $d 'QuickScanEndTime'
    $fs = Get-WCProp $d 'FullScanEndTime'
    $qsTxt = (T 'm5.def.never')
    if ($null -ne $qs) { $qsTxt = (ConvertTo-WCM5TimeText $qs) }
    $fsTxt = (T 'm5.def.never')
    if ($null -ne $fs) { $fsTxt = (ConvertTo-WCM5TimeText $fs) }
    Add-WCM5BlockField $Block['Body'] (T 'm5.def.quick') $qsTxt
    Add-WCM5BlockField $Block['Body'] (T 'm5.def.full') $fsTxt
    # Tamper Protection
    $tp = Get-WCProp $d 'IsTamperProtectionEnabled'
    $tps = Get-WCProp $d 'TamperProtectionSource'
    $tpStatus = 'Unknown'
    if ($tp -eq $true) { $tpStatus = 'Ok' }
    elseif ($tp -eq $false) { $tpStatus = 'Bad' }
    $statuses += $tpStatus
    if ($tp -eq $true) {
        Add-WCM5BlockLine $Block['Body'] 'Ok' (T 'm5.def.tamper')
    } elseif ($tp -eq $false) {
        Add-WCM5BlockLine $Block['Body'] 'Bad' (T 'm5.def.tamper')
        Add-WCM5BlockGuide $Block['Body'] (T 'm5.def.tamper.how')
    } elseif ($null -ne $tps) {
        Add-WCM5BlockLine $Block['Body'] 'Unknown' (T 'm5.def.tamper.source' @([string]$tps))
    } else {
        Add-WCM5BlockLine $Block['Body'] 'Unknown' (T 'm5.def.tamper')
    }
    Set-WCM5BlockChip $Block (Get-WCM5Worst $statuses)
}

function Update-WCM5AvBlock {
    param($Block, $Result)
    Reset-WCM5BlockBody $Block
    if ($Result.Status -ne 'Ok') {
        Set-WCM5BlockChip $Block 'Unknown'
        Add-WCM5BlockLine $Block['Body'] 'Unknown' (T 'common.notread.fmt' @($Result.Reason))
        return
    }
    $data = $Result.Data
    if ($null -eq $data) {
        Set-WCM5BlockChip $Block 'Unknown'
        Add-WCM5BlockLine $Block['Body'] 'Unknown' (T 'm5.av.none')
        return
    }
    $items = @(Get-WCProp $data 'Items')
    if (($items.Count -eq 0) -or (($items.Count -eq 1) -and ($null -eq $items[0]))) {
        Set-WCM5BlockChip $Block 'Unknown'
        Add-WCM5BlockLine $Block['Body'] 'Unknown' (T 'm5.av.none')
        return
    }
    $hasThird = ((Get-WCProp $data 'HasThirdParty') -eq $true)
    $statuses = @()
    foreach ($it in $items) {
        $on = Get-WCProp $it 'Enabled'
        $up = Get-WCProp $it 'UpToDate'
        $onStatus = 'Unknown'
        $onTxt = (T 'm5.av.unknown')
        if ($on -eq $true) { $onStatus = 'Ok'; $onTxt = (T 'm5.av.on') }
        elseif ($on -eq $false) { $onStatus = 'Warn'; $onTxt = (T 'm5.av.off') }
        $upStatus = 'Unknown'
        $upTxt = (T 'm5.av.unknown')
        if ($up -eq $true) { $upStatus = 'Ok'; $upTxt = (T 'm5.av.up') }
        elseif ($up -eq $false) { $upStatus = 'Warn'; $upTxt = (T 'm5.av.outdated') }
        $lineStatus = (Get-WCM5Worst @($onStatus, $upStatus))
        $statuses += $lineStatus
        Add-WCM5BlockLine $Block['Body'] $lineStatus (T 'm5.av.line' @([string](Get-WCProp $it 'Name'), $onTxt, $upTxt))
    }
    if ($hasThird) {
        $statuses += 'Warn'
        Add-WCM5BlockLine $Block['Body'] 'Warn' (T 'm5.av.thirdparty')
    }
    Add-WCM5BlockGuide $Block['Body'] (T 'm5.av.note')
    Set-WCM5BlockChip $Block (Get-WCM5Worst $statuses)
}

function Update-WCM5FirewallBlock {
    param($Block, $Result)
    Reset-WCM5BlockBody $Block
    if (($Result.Status -ne 'Ok') -or ($null -eq $Result.Data)) {
        Set-WCM5BlockChip $Block 'Unknown'
        Add-WCM5BlockLine $Block['Body'] 'Unknown' (T 'common.notread.fmt' @($Result.Reason))
        return
    }
    $statuses = @()
    $anyOff = $false
    foreach ($p in @($Result.Data)) {
        if ($null -eq $p) { continue }
        $prof = [string](Get-WCProp $p 'Profile')
        $en = Get-WCProp $p 'Enabled'
        $label = $prof
        if ($prof -eq 'Domain') { $label = (T 'm5.fw.domain') }
        elseif ($prof -eq 'Private') { $label = (T 'm5.fw.private') }
        elseif ($prof -eq 'Public') { $label = (T 'm5.fw.public') }
        $st = 'Unknown'
        $txt = (T 'm5.av.unknown')
        if ($en -eq $true) { $st = 'Ok'; $txt = (T 'm5.fw.on') }
        elseif ($en -eq $false) { $st = 'Bad'; $txt = (T 'm5.fw.off'); $anyOff = $true }
        $statuses += $st
        Add-WCM5BlockLine $Block['Body'] $st (T 'm5.fw.line' @($label, $txt))
    }
    if ($anyOff) { Add-WCM5BlockGuide $Block['Body'] (T 'm5.fw.how') }
    Set-WCM5BlockChip $Block (Get-WCM5Worst $statuses)
}

function Get-WCM5SmartScreenLine {
    # 1 dong SmartScreen tu gia tri registry (On/Warn/Off/khong dat)
    param($Body, [string]$Label, $Value)
    if ($null -eq $Value) {
        Add-WCM5BlockLine $Body 'Unknown' ($Label + ': ' + (T 'm5.ss.missing'))
        return 'Unknown'
    }
    $v = ([string]$Value).Trim()
    if ($v -ieq 'On') {
        Add-WCM5BlockLine $Body 'Ok' ($Label + ': ' + $v)
        return 'Ok'
    }
    if ($v -ieq 'Off') {
        Add-WCM5BlockLine $Body 'Bad' ($Label + ': ' + $v + ' — ' + (T 'm5.ss.off'))
        return 'Bad'
    }
    if ($v -ieq 'Warn') {
        Add-WCM5BlockLine $Body 'Warn' ($Label + ': ' + $v + ' — ' + (T 'm5.ss.warn'))
        return 'Warn'
    }
    Add-WCM5BlockLine $Body 'Unknown' ($Label + ': ' + $v)
    return 'Unknown'
}

function Update-WCM5SmartScreenBlock {
    param($Block, $Result)
    Reset-WCM5BlockBody $Block
    if (($Result.Status -ne 'Ok') -or ($null -eq $Result.Data)) {
        Set-WCM5BlockChip $Block 'Unknown'
        Add-WCM5BlockLine $Block['Body'] 'Unknown' (T 'common.notread.fmt' @($Result.Reason))
        return
    }
    $statuses = @()
    $statuses += (Get-WCM5SmartScreenLine $Block['Body'] (T 'm5.ss.machine') (Get-WCProp $Result.Data 'Machine'))
    $statuses += (Get-WCM5SmartScreenLine $Block['Body'] (T 'm5.ss.user') (Get-WCProp $Result.Data 'User'))
    Add-WCM5BlockGuide $Block['Body'] (T 'm5.ss.how')
    Set-WCM5BlockChip $Block (Get-WCM5Worst $statuses)
}

function Update-WCM5UacBlock {
    param($Block, $Result)
    Reset-WCM5BlockBody $Block
    if (($Result.Status -ne 'Ok') -or ($null -eq $Result.Data)) {
        Set-WCM5BlockChip $Block 'Unknown'
        Add-WCM5BlockLine $Block['Body'] 'Unknown' (T 'common.notread.fmt' @($Result.Reason))
        return
    }
    $lua = Get-WCProp $Result.Data 'EnableLUA'
    $consent = Get-WCProp $Result.Data 'Consent'
    $statuses = @()
    if ($lua -eq 1) {
        $statuses += 'Ok'
        Add-WCM5BlockLine $Block['Body'] 'Ok' (T 'm5.uac.on')
    } elseif ($lua -eq 0) {
        $statuses += 'Bad'
        Add-WCM5BlockLine $Block['Body'] 'Bad' (T 'm5.uac.off')
        Add-WCM5BlockGuide $Block['Body'] (T 'm5.uac.how')
    } else {
        $statuses += 'Unknown'
        Add-WCM5BlockLine $Block['Body'] 'Unknown' (T 'm5.uac.on')
    }
    if ($null -ne $consent) {
        Add-WCM5BlockField $Block['Body'] (T 'm5.uac.prompt') ([string]$consent)
    }
    Set-WCM5BlockChip $Block (Get-WCM5Worst $statuses)
}

function Update-WCM5BitlockerBlock {
    param($Block, $Result)
    Reset-WCM5BlockBody $Block
    if (($Result.Status -ne 'Ok') -or ($null -eq $Result.Data)) {
        Set-WCM5BlockChip $Block 'Unknown'
        Add-WCM5BlockLine $Block['Body'] 'Unknown' (T 'm5.bl.unread')
        return
    }
    $vols = @($Result.Data)
    if (($vols.Count -eq 0) -or (($vols.Count -eq 1) -and ($null -eq $vols[0]))) {
        Set-WCM5BlockChip $Block 'Unknown'
        Add-WCM5BlockLine $Block['Body'] 'Unknown' (T 'm5.bl.unread')
        return
    }
    $statuses = @()
    $anyDec = $false
    foreach ($v in $vols) {
        if ($null -eq $v) { continue }
        $mount = [string](Get-WCProp $v 'MountPoint')
        $vs = [string](Get-WCProp $v 'VolumeStatus')
        $ps = Get-WCProp $v 'ProtectionStatus'
        $st = 'Unknown'
        $txt = $vs
        if ($vs -eq 'FullyEncrypted') { $st = 'Ok'; $txt = (T 'm5.bl.enc') }
        elseif ($vs -eq 'FullyDecrypted') { $st = 'Warn'; $txt = (T 'm5.bl.dec'); $anyDec = $true }
        elseif (-not [string]::IsNullOrEmpty($vs)) { $st = 'Warn' }
        $protTxt = (T 'common.unknown')
        if ($ps -eq 1) { $protTxt = (T 'm5.bl.protected') }
        elseif ($ps -eq 0) { $protTxt = (T 'm5.bl.notprotected') }
        $statuses += $st
        Add-WCM5BlockLine $Block['Body'] $st (T 'm5.bl.line' @($mount, $txt, $protTxt))
    }
    if ($anyDec) { Add-WCM5BlockGuide $Block['Body'] (T 'm5.bl.how') }
    Set-WCM5BlockChip $Block (Get-WCM5Worst $statuses)
}

function Update-WCM5WuBlock {
    param($Block, $Result)
    Reset-WCM5BlockBody $Block
    if (($Result.Status -ne 'Ok') -or ($null -eq $Result.Data)) {
        Set-WCM5BlockChip $Block 'Unknown'
        Add-WCM5BlockLine $Block['Body'] 'Unknown' (T 'common.notread.fmt' @($Result.Reason))
        return
    }
    $cbs = (Get-WCProp $Result.Data 'Cbs') -eq $true
    $wu = (Get-WCProp $Result.Data 'Wu') -eq $true
    $ren = (Get-WCProp $Result.Data 'Rename') -eq $true
    $parts = @()
    if ($cbs) { $parts += (T 'm5.wu.cbs') }
    if ($wu) { $parts += (T 'm5.wu.wu') }
    if ($ren) { $parts += (T 'm5.wu.pfro') }
    if ($parts.Count -gt 0) {
        Set-WCM5BlockChip $Block 'Warn'
        Add-WCM5BlockLine $Block['Body'] 'Warn' (T 'm5.wu.pending' @([string]::Join(', ', $parts)))
        Add-WCM5BlockGuide $Block['Body'] (T 'm5.wu.how')
    } else {
        Set-WCM5BlockChip $Block 'Ok'
        Add-WCM5BlockLine $Block['Body'] 'Ok' (T 'm5.wu.none')
    }
}

function Update-WCM5L1Source {
    param($State, [string]$Source, $Result)
    $block = $State['L1'][$Source]
    if (-not $block) { return }
    try {
        switch ($Source) {
            'mpstatus'    { Update-WCM5DefenderBlock $block $Result }
            'av'          { Update-WCM5AvBlock $block $Result }
            'firewall'    { Update-WCM5FirewallBlock $block $Result }
            'smartscreen' { Update-WCM5SmartScreenBlock $block $Result }
            'uac'         { Update-WCM5UacBlock $block $Result }
            'bitlocker'   { Update-WCM5BitlockerBlock $block $Result }
            'wupending'   { Update-WCM5WuBlock $block $Result }
        }
    } catch {
        Write-WCLog 'ERROR' ('M5 update L1 [' + $Source + ']: ' + $_.Exception.Message)
        Set-WCM5BlockChip $block 'Unknown'
        Add-WCM5BlockLine $block['Body'] 'Unknown' (T 'common.notread.fmt' @($_.Exception.Message))
    }
}

function Start-WCM5StatusTask {
    # 1 task nen cho 1 nguon Lop 1 (Invoke-WCQuery key rieng trong worker)
    param($State, [string]$Source, [bool]$Fresh = $false)
    $srcName = $Source
    $null = Start-WCTask -Id ('m5.' + $Source) -Title (T ('m5.l1.s.' + $Source)) `
        -Args @{ Source = $Source; Fresh = $Fresh } -Worker {
            param($ctx, $s)
            return (Get-WCM5StatusData -Source ([string]$s['Source']) -Fresh:([bool]$s['Fresh']))
        } -Done {
            param($result)
            Update-WCM5L1Source $State $srcName $result
        }.GetNewClosure()
}

function Invoke-WCM5RefreshStatus {
    param($State)
    foreach ($src in (Get-WCM5L1Sources)) {
        Start-WCM5StatusTask $State $src $true
    }
}

# ---------------------------------------------------------------------------
# UI — LOP 2 (quet Defender + xu ly de doa)
# ---------------------------------------------------------------------------
function Invoke-WCM5SignatureUpdate {
    param($State)
    if (Test-WCTaskRunning 'm5.sig') {
        Show-WCToast (T 'common.running' @((T 'm5.sig.title'))) 'Info'
        return
    }
    $State['L2Status'].Text = (T 'common.loading')
    $ok = Start-WCTask -Id 'm5.sig' -Title (T 'm5.sig.title') -ShowStatus -Worker {
        param($ctx, $s)
        # Update-MpSignature la cmdlet chan: chay trong PowerShell con de vong
        # polling van cap nhat elapsed + xu ly Huy (ngung cho, dich vu co the
        # van cap nhat not — trung thuc, khong hua la huy duoc).
        $start = [DateTime]::Now
        $ctx.Progress(0, (T 'm5.sig.cancelnote'))
        $child = [PowerShell]::Create()
        $null = $child.AddScript('Update-MpSignature')
        $handle = $child.BeginInvoke()
        while (-not $handle.IsCompleted) {
            if ($ctx.Cancelled()) {
                try { $child.Stop() } catch { }
                Start-Sleep -Milliseconds 500
                try { $child.Dispose() } catch { }
                return [PSCustomObject]@{ Cancelled = $true }
            }
            $el = [int](([DateTime]::Now - $start).TotalSeconds)
            $ctx.Progress(0, ((T 'm5.elapsed' @([string]$el)) + ' — ' + (T 'm5.sig.cancelnote')))
            Start-Sleep -Milliseconds 1500
        }
        $errText = ''
        try { $null = $child.EndInvoke($handle) } catch { $errText = $_.Exception.Message }
        if (@($child.Streams.Error).Count -gt 0) { $errText = [string]$child.Streams.Error[0] }
        try { $child.Dispose() } catch { }
        if ($errText) { return [PSCustomObject]@{ Error = $errText } }
        return [PSCustomObject]@{ Ok = $true; Elapsed = [int](([DateTime]::Now - $start).TotalSeconds) }
    } -Done {
        param($r)
        if ($null -eq $r) { return }
        if (Get-WCProp $r 'Error') {
            $State['L2Status'].Text = (T 'm5.sig.error')
            Show-WCError (T 'm5.sig.error') ([string](Get-WCProp $r 'Error'))
            return
        }
        if (Get-WCProp $r 'Cancelled') {
            $State['L2Status'].Text = (T 'common.task.cancelled')
            return
        }
        $State['L2Status'].Text = (T 'm5.sig.done')
        Show-WCToast (T 'm5.sig.done') 'Ok'
        Start-WCM5StatusTask $State 'mpstatus' $true
    }.GetNewClosure()
    if (-not $ok) {
        Show-WCToast (T 'common.running' @((T 'm5.sig.title'))) 'Info'
    }
}

function Invoke-WCM5Scan {
    # Quick | Full | Custom — quet bang Defender trong PowerShell con; Huy =
    # Stop-MpScan; progress chi la elapsed + ghi ro "khong co tien do chi tiet"
    param($State, [string]$Mode)
    if (Test-WCTaskRunning 'm5.scan') {
        Show-WCToast (T 'common.running' @((T 'm5.scan.title'))) 'Info'
        return
    }
    $path = ''
    if ($Mode -eq 'Custom') {
        if ($State['FolderBox']) { $path = ([string]$State['FolderBox'].Text).Trim() }
        if ([string]::IsNullOrEmpty($path) -or (-not (Test-Path -LiteralPath $path -PathType Container))) {
            Show-WCToast (T 'm5.scan.folder.invalid') 'Warn'
            return
        }
    }
    $cmd = ''
    switch ($Mode) {
        'Quick'  { $cmd = 'Start-MpScan -ScanType QuickScan' }
        'Full'   { $cmd = 'Start-MpScan -ScanType FullScan' }
        'Custom' {
            $esc = $path.Replace('''', '''''')
            $cmd = 'Start-MpScan -ScanType CustomScan -ScanPath ''' + $esc + ''''
        }
    }
    $State['L2Status'].Text = (T 'common.loading')
    $scanArgs = @{ Cmd = $cmd; Mode = $Mode }
    $ok = Start-WCTask -Id 'm5.scan' -Title (T 'm5.scan.title') -ShowStatus -Args $scanArgs -Worker {
        param($ctx, $s)
        $start = [DateTime]::Now
        $ctx.Progress(0, (T 'm5.scan.noprogress'))
        $child = [PowerShell]::Create()
        $null = $child.AddScript([string]$s['Cmd'])
        $handle = $child.BeginInvoke()
        $cancelled = $false
        while (-not $handle.IsCompleted) {
            if ($ctx.Cancelled()) {
                # Huy = Stop-MpScan (yeu cau Defender dung quet), roi cho lenh tra ve
                $cancelled = $true
                try { Stop-MpScan -ErrorAction Stop } catch { $ctx.Log('Stop-MpScan loi: ' + $_.Exception.Message) }
                $null = $handle.AsyncWaitHandle.WaitOne(30000)
                break
            }
            $el = [int](([DateTime]::Now - $start).TotalSeconds)
            $ctx.Progress(0, ((T 'm5.elapsed' @([string]$el)) + ' — ' + (T 'm5.scan.noprogress')))
            Start-Sleep -Milliseconds 1500
        }
        $errText = ''
        if ($handle.IsCompleted) {
            try { $null = $child.EndInvoke($handle) } catch { $errText = $_.Exception.Message }
        } else {
            try { $child.Stop() } catch { }
        }
        if (@($child.Streams.Error).Count -gt 0) { $errText = [string]$child.Streams.Error[0] }
        try { $child.Dispose() } catch { }
        if ($cancelled) { return [PSCustomObject]@{ Cancelled = $true } }
        if ($errText) { return [PSCustomObject]@{ Error = $errText } }
        $threats = @(Get-WCM5ThreatsRaw)
        return [PSCustomObject]@{
            Ok = $true
            ElapsedSec = [int](([DateTime]::Now - $start).TotalSeconds)
            Threats = $threats
        }
    } -OnMessage {
        param($msg)
        if ($msg.Type -eq 'Progress') { $State['L2Status'].Text = [string]$msg.Text }
    }.GetNewClosure() -Done {
        param($r)
        if ($null -eq $r) { return }
        if (Get-WCProp $r 'Error') {
            $State['L2Status'].Text = (T 'm5.scan.error')
            Show-WCError (T 'm5.scan.error') ([string](Get-WCProp $r 'Error'))
            return
        }
        if (Get-WCProp $r 'Cancelled') {
            $State['L2Status'].Text = (T 'common.task.cancelled')
            return
        }
        $el = [string](Get-WCProp $r 'ElapsedSec')
        $State['L2Status'].Text = (T 'm5.scan.done' @($el))
        Show-WCToast (T 'm5.scan.done' @($el)) 'Ok'
        Show-WCM5Threats $State @(Get-WCProp $r 'Threats')
        Start-WCM5StatusTask $State 'mpstatus' $true
    }.GetNewClosure()
    if (-not $ok) {
        Show-WCToast (T 'common.running' @((T 'm5.scan.title'))) 'Info'
    }
}

function Invoke-WCM5OfflineScan {
    # Quet ngoai tuyen: canh bao RO RANG se khoi dong lai + xac nhan 2 buoc (Danger)
    param($State)
    if (Test-WCTaskRunning 'm5.wdo') {
        Show-WCToast (T 'common.running' @((T 'm5.l2.wdo'))) 'Info'
        return
    }
    if (-not (Show-WCConfirm -Title (T 'm5.wdo.confirm.title') -Message (T 'm5.wdo.confirm.msg') `
            -NotUndoable (T 'm5.wdo.confirm.noundo') -Danger)) { return }
    $null = Start-WCTask -Id 'm5.wdo' -Title (T 'm5.l2.wdo') -ShowStatus -Worker {
        param($ctx, $s)
        try {
            Start-MpWDOScan -ErrorAction Stop
            return [PSCustomObject]@{ Ok = $true }
        } catch {
            return [PSCustomObject]@{ Error = $_.Exception.Message }
        }
    } -Done {
        param($r)
        if (Get-WCProp $r 'Error') {
            Show-WCError (T 'm5.wdo.error') ([string](Get-WCProp $r 'Error'))
            return
        }
        $State['L2Status'].Text = (T 'm5.wdo.scheduled')
        Show-WCToast (T 'm5.wdo.scheduled') 'Warn'
    }.GetNewClosure()
}

function Show-WCM5Threats {
    # Bang: Moi de doa | Loai | Tai nguyen | Trang thai (+ nut Cach ly tung muc)
    param($State, $Rows)
    $body = $State['ThreatHost']
    if (-not $body) { return }
    $body.Children.Clear()
    $State['ThreatSection'].Root.Visibility = [Windows.Visibility]::Visible
    $rows = @($Rows)
    if (($rows.Count -eq 0) -or (($rows.Count -eq 1) -and ($null -eq $rows[0]))) {
        $null = Add-WCChild $body (New-WCTextBlock -Text (T 'm5.threat.none') -Size 12.5 -ColorKey 'WcSubtle' -Wrap)
        return
    }
    $grid = New-Object Windows.Controls.Grid
    $colDefs = @(
        @{ W = 220.0; Star = $false }
        @{ W = 130.0; Star = $false }
        @{ W = 0.0;   Star = $true }
        @{ W = 120.0; Star = $false }
        @{ W = 90.0;  Star = $false }
    )
    foreach ($colDef in $colDefs) {
        $d = New-Object Windows.Controls.ColumnDefinition
        if ($colDef['Star']) { $d.Width = (New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star)) }
        else { $d.Width = (New-Object Windows.GridLength($colDef['W'])) }
        $grid.ColumnDefinitions.Add($d) | Out-Null
    }
    $rd = New-Object Windows.Controls.RowDefinition
    $rd.Height = [Windows.GridLength]::Auto
    $grid.RowDefinitions.Add($rd) | Out-Null
    $headers = @((T 'm5.threat.col.name'), (T 'm5.threat.col.type'), (T 'm5.threat.col.res'), (T 'm5.threat.col.status'), '')
    for ($c = 0; $c -lt 5; $c++) {
        $ht = New-WCTextBlock -Text ([string]$headers[$c]) -Size 11.5 -Weight 'SemiBold' -ColorKey 'WcSubtle'
        $ht.Margin = (New-Object Windows.Thickness(0, 0, 10, 4))
        [Windows.Controls.Grid]::SetColumn($ht, $c)
        [Windows.Controls.Grid]::SetRow($ht, 0)
        $grid.Children.Add($ht) | Out-Null
    }
    $rowIdx = 1
    foreach ($t in $rows) {
        if ($null -eq $t) { continue }
        $th = $t
        $rd2 = New-Object Windows.Controls.RowDefinition
        $rd2.Height = [Windows.GridLength]::Auto
        $grid.RowDefinitions.Add($rd2) | Out-Null
        $name = [string](Get-WCProp $th 'Name')
        $typeTxt = ([string](Get-WCProp $th 'Type') + ' · ' + [string](Get-WCProp $th 'Severity'))
        $resTxt = [string](Get-WCProp $th 'Resources')
        $statusTxt = [string](Get-WCProp $th 'Status')
        if ((Get-WCProp $th 'Active') -eq $true) { $statusTxt = $statusTxt + ' (' + (T 'm5.threat.active') + ')' }
        $cells = @($name, $typeTxt, $resTxt, $statusTxt)
        for ($c = 0; $c -lt 4; $c++) {
            $ct = New-WCTextBlock -Text ([string]$cells[$c]) -Size 12.5 -Wrap
            $ct.Margin = (New-Object Windows.Thickness(0, 0, 10, 6))
            $ct.TextTrimming = [Windows.TextTrimming]::CharacterEllipsis
            $ct.ToolTip = ([string]$cells[$c] + "`n" + (T 'm5.threat.at' @((ConvertTo-WCM5TimeText (Get-WCProp $th 'DetectedAt')))))
            [Windows.Controls.Grid]::SetColumn($ct, $c)
            [Windows.Controls.Grid]::SetRow($ct, $rowIdx)
            $grid.Children.Add($ct) | Out-Null
        }
        # Cach ly tung muc — CHI chay sau Show-WCConfirm tung muc (trong handler)
        $btn = New-WCButton -Text (T 'm5.threat.remove') -Small -OnClick {
            param($b)
            Invoke-WCM5RemoveThreat $State $th
        }.GetNewClosure()
        $btn.VerticalAlignment = [Windows.VerticalAlignment]::Center
        $btn.Margin = (New-Object Windows.Thickness(0, 0, 0, 6))
        [Windows.Controls.Grid]::SetColumn($btn, 4)
        [Windows.Controls.Grid]::SetRow($btn, $rowIdx)
        $grid.Children.Add($btn) | Out-Null
        $rowIdx++
    }
    $null = Add-WCChild $body $grid
}

function Invoke-WCM5LoadThreats {
    param($State)
    if (Test-WCTaskRunning 'm5.threats') { return }
    $null = Start-WCTask -Id 'm5.threats' -Title (T 'm5.threat.title') -Worker {
        param($ctx, $s)
        return [PSCustomObject]@{ Rows = @(Get-WCM5ThreatsRaw) }
    } -Done {
        param($r)
        if ($null -eq $r) { return }
        $State['ThreatsLoaded'] = $true
        Show-WCM5Threats $State @(Get-WCProp $r 'Rows')
    }.GetNewClosure()
}

function Invoke-WCM5RemoveThreat {
    # Cach ly qua Defender: xac nhan TUNG MUC; khong tu xoa; ghi journal
    # (UndoType '' = khong hoan tac tu dong — ghi ro trong confirm)
    param($State, $Threat)
    $th = $Threat
    $name = [string](Get-WCProp $th 'Name')
    $msg = (T 'm5.threat.confirm.msg' @($name))
    if (-not (Show-WCConfirm -Title (T 'm5.threat.confirm.title') -Message $msg `
            -NotUndoable (T 'm5.threat.confirm.noundo'))) { return }
    if (Test-WCDryRunMode) {
        Show-WCInfo -Title (T 'common.dryrun.header') -Message ('[DRY-RUN] Remove-MpThreat — ' + $name)
        return
    }
    $tid = Get-WCProp $th 'ThreatID'
    $entry = Add-WCJournalEntry -Module 'M5' -Action (T 'm5.threat.journal') -Target $name `
        -OldValue '' -UndoType '' -UndoArgs $null
    $ok = Start-WCTask -Id 'm5.remove' -Title (T 'm5.threat.confirm.title') -ShowStatus `
        -Args @{ ThreatID = $tid } -Worker {
            param($ctx, $s)
            if ($ctx.Cancelled()) { return [PSCustomObject]@{ Cancelled = $true } }
            try {
                $done = $false
                # Thu theo ThreatID; neu module khong ho tro tham so thi dung dang tong quat
                try {
                    if ($null -ne $s['ThreatID']) {
                        Remove-MpThreat -ThreatID ([long]$s['ThreatID']) -ErrorAction Stop
                        $done = $true
                    }
                } catch { }
                if (-not $done) { Remove-MpThreat -ErrorAction Stop }
                return [PSCustomObject]@{ Ok = $true }
            } catch {
                return [PSCustomObject]@{ Error = $_.Exception.Message }
            }
        } -Done {
            param($r)
            if (Get-WCProp $r 'Error') {
                Complete-WCJournalEntry -Entry $entry -Result ('Failed: ' + (Get-WCProp $r 'Error'))
                Show-WCError (T 'common.error') ([string](Get-WCProp $r 'Error'))
                return
            }
            if (Get-WCProp $r 'Cancelled') {
                Complete-WCJournalEntry -Entry $entry -Result 'Cancelled'
                return
            }
            Complete-WCJournalEntry -Entry $entry -Result 'Ok'
            Show-WCToast (T 'common.success') 'Ok'
            Invoke-WCM5LoadThreats $State
        }.GetNewClosure()
    if (-not $ok) {
        Complete-WCJournalEntry -Entry $entry -Result 'Skipped: task busy'
        Show-WCToast (T 'common.running' @((T 'm5.threat.confirm.title'))) 'Info'
    }
}

# ---------------------------------------------------------------------------
# UI — LOP 3 (heuristic)
# ---------------------------------------------------------------------------
function Invoke-WCM5HeurScan {
    param($State)
    if (Test-WCTaskRunning 'm5.heur') {
        Show-WCToast (T 'common.running' @((T 'm5.l3.title'))) 'Info'
        return
    }
    $State['L3Host'].Children.Clear()
    $State['L3Spinner'].Visibility = [Windows.Visibility]::Visible
    Set-WCM5SummaryChips $State -1 -1 -1
    $ok = Start-WCTask -Id 'm5.heur' -Title (T 'm5.l3.title') -ShowStatus `
        -Args @{ Cache = $Script:WcM5SigCache } -Worker {
            param($ctx, $s)
            # 1 task lon, tung nguon try/catch rieng (Get-WCM5HeuristicsGroup)
            # Progress theo SO NGUON da quet (that), khong phai % bia
            $groupKeys = @('run', 'startup', 'task', 'svc', 'winlogon', 'ifeo', 'wmi', 'excl', 'hosts', 'proxy')
            $out = @()
            $i = 0
            foreach ($g in $groupKeys) {
                if ($ctx.Cancelled()) { return [PSCustomObject]@{ Cancelled = $true } }
                $ctx.Progress(([int](($i * 100) / $groupKeys.Count)), (T ('m5.g.' + $g)))
                $out += (Get-WCM5HeuristicsGroup -Group $g -Cache $s['Cache'])
                $i++
            }
            $ctx.Progress(100, (T 'common.task.done'))
            return [PSCustomObject]@{ Groups = $out }
        } -Done {
            param($r)
            $State['L3Spinner'].Visibility = [Windows.Visibility]::Collapsed
            Show-WCM5Findings $State $r
        }.GetNewClosure()
    if (-not $ok) {
        $State['L3Spinner'].Visibility = [Windows.Visibility]::Collapsed
    }
}

function Set-WCM5SummaryChips {
    # -1 = dang tai (chip "Chua quet"/spinner)
    param($State, [int]$OkCount, [int]$WarnCount, [int]$BadCount)
    # LUU Y: khong dung ten bien $host (bien tu dong read-only cua PowerShell)
    $sumHost = $State['L3SummaryHost']
    if (-not $sumHost) { return }
    $sumHost.Children.Clear()
    if ($OkCount -lt 0) {
        $c = New-WCChip -Text (T 'm5.l3.idle') -Kind 'Plain'
        $sumHost.Children.Add($c) | Out-Null
        return
    }
    $chipOk = New-WCChip -Text ((T 'm5.level.ok') + ': ' + [string]$OkCount) -Kind 'Ok'
    $chipWarn = New-WCChip -Text ((T 'm5.level.warn') + ': ' + [string]$WarnCount) -Kind 'Warn'
    $chipBad = New-WCChip -Text ((T 'm5.level.bad') + ': ' + [string]$BadCount) -Kind 'Bad'
    $chipOk.Margin = (New-Object Windows.Thickness(0, 0, 8, 0))
    $chipWarn.Margin = (New-Object Windows.Thickness(0, 0, 8, 0))
    $sumHost.Children.Add($chipOk) | Out-Null
    $sumHost.Children.Add($chipWarn) | Out-Null
    $sumHost.Children.Add($chipBad) | Out-Null
}

function Add-WCM5FindingRow {
    param($Body, $Finding, $State)
    $f = $Finding
    $card = New-Object Windows.Controls.Border
    $card.Style = (Get-WCControlStyles)['WcListItem']
    $card.Padding = (New-Object Windows.Thickness(6, 6, 6, 6))
    $inner = New-WCVStack -Spacing 3
    # Hang 1: chip muc + tieu de
    $row1 = New-WCHStack -Spacing 8
    $level = [string](Get-WCProp $f 'Level')
    $chip = New-WCChip -Text (T ('m5.level.' + $level.ToLower())) -Kind $level
    $chip.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $null = Add-WCChild $row1 $chip
    $title = New-WCTextBlock -Text ([string](Get-WCProp $f 'Title')) -Size 13 -Weight 'SemiBold' -Wrap
    $title.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $null = Add-WCChild $row1 $title
    $null = Add-WCChild $inner $row1
    # Hang 2: lenh / duong dan
    $cmd = [string](Get-WCProp $f 'Command')
    if (-not [string]::IsNullOrEmpty($cmd)) {
        $t2 = New-WCTextBlock -Text $cmd -Size 11.5 -ColorKey 'WcSubtle' -Wrap
        $t2.FontFamily = New-Object Windows.Media.FontFamily('Consolas')
        $null = Add-WCChild $inner $t2
    }
    # Hang 3: ly do cu the
    $reasons = @(Get-WCProp $f 'Reasons')
    if ($reasons.Count -gt 0) {
        $null = Add-WCChild $inner (New-WCTextBlock -Text ([string]::Join(' · ', $reasons)) -Size 11.5 -ColorKey 'WcSubtle' -Wrap)
    }
    # Hang 4: dia chi registry (neu co)
    $regP = [string](Get-WCProp $f 'RegPath')
    if (-not [string]::IsNullOrEmpty($regP)) {
        $t4 = New-WCTextBlock -Text $regP -Size 11 -ColorKey 'WcSubtle' -Wrap
        $t4.FontFamily = New-Object Windows.Media.FontFamily('Consolas')
        $null = Add-WCChild $inner $t4
    }
    # Hang 5: cac nut
    $btnRow = New-WCHStack -Spacing 6
    $openKind = [string](Get-WCProp $f 'OpenKind')
    if ($openKind -ne 'none') {
        $null = Add-WCChild $btnRow (New-WCButton -Text (T 'common.openlocation') -Small -OnClick {
            param($b)
            Open-WCM5Location $f
        }.GetNewClosure())
    }
    $fp = [string](Get-WCProp $f 'Path')
    if (-not [string]::IsNullOrEmpty($fp)) {
        $null = Add-WCChild $btnRow (New-WCButton -Text (T 'm5.a.hash') -Small -OnClick {
            param($b)
            Invoke-WCM5Hash $State $f $false
        }.GetNewClosure())
        $null = Add-WCChild $btnRow (New-WCButton -Text (T 'm5.a.vt') -Small -OnClick {
            param($b)
            Invoke-WCM5Hash $State $f $true
        }.GetNewClosure())
    }
    if ((Get-WCProp $f 'CanDisable') -eq $true) {
        $null = Add-WCChild $btnRow (New-WCButton -Text (T 'm5.a.disable') -Small -Kind Danger -OnClick {
            param($b)
            Invoke-WCM5DisableStartup $State $f
        }.GetNewClosure())
    }
    if ($btnRow.Children.Count -gt 0) { $null = Add-WCChild $inner $btnRow }
    $card.Child = $inner
    $null = Add-WCChild $Body $card
}

function Show-WCM5Findings {
    param($State, $Result)
    $listHost = $State['L3Host']
    if (-not $listHost) { return }
    $listHost.Children.Clear()
    if ($null -eq $Result) {
        Set-WCM5SummaryChips $State -1 -1 -1
        return
    }
    if (Get-WCProp $Result 'Cancelled') {
        $null = Add-WCChild $listHost (New-WCTextBlock -Text (T 'm5.l3.cancelled') -Size 12.5 -ColorKey 'WcSubtle' -Wrap)
        Set-WCM5SummaryChips $State -1 -1 -1
        return
    }
    $groups = @(Get-WCProp $Result 'Groups')
    $ok = 0
    $warn = 0
    $bad = 0
    foreach ($g in $groups) {
        if ($null -eq $g) { continue }
        foreach ($fd in @(Get-WCProp $g 'Findings')) {
            if ($null -eq $fd) { continue }
            $lvl = [string](Get-WCProp $fd 'Level')
            if ($lvl -eq 'Bad') { $bad++ }
            elseif ($lvl -eq 'Warn') { $warn++ }
            elseif ($lvl -eq 'Ok') { $ok++ }
        }
    }
    Set-WCM5SummaryChips $State $ok $warn $bad
    foreach ($g in $groups) {
        if ($null -eq $g) { continue }
        $key = [string](Get-WCProp $g 'Key')
        $findings = @(Get-WCProp $g 'Findings')
        $err = [string](Get-WCProp $g 'Error')
        $gBad = 0
        $gWarn = 0
        foreach ($fd in $findings) {
            if ($null -eq $fd) { continue }
            $lvl = [string](Get-WCProp $fd 'Level')
            if ($lvl -eq 'Bad') { $gBad++ }
            elseif ($lvl -eq 'Warn') { $gWarn++ }
        }
        $summary = (T 'm5.g.count' @([string]$findings.Count))
        if ($gBad -gt 0) { $summary = $summary + (' · ' + (T 'm5.level.bad') + ': ' + [string]$gBad) }
        if ($gWarn -gt 0) { $summary = $summary + (' · ' + (T 'm5.level.warn') + ': ' + [string]$gWarn) }
        $exp = New-WCExpander -Title (T ('m5.g.' + $key)) -Summary $summary
        if (($gBad -gt 0) -or ($gWarn -gt 0)) { $exp.Root.IsExpanded = $true }
        if (-not [string]::IsNullOrEmpty($err)) {
            $null = Add-WCChild $exp.Body (New-WCTextBlock -Text (T 'm5.l3.errsource' @($err)) -Size 12 -ColorKey 'WcSubtle' -Wrap)
        }
        if (($findings.Count -eq 0) -and [string]::IsNullOrEmpty($err)) {
            $null = Add-WCChild $exp.Body (New-WCTextBlock -Text (T 'm5.l3.notfound') -Size 12 -ColorKey 'WcSubtle' -Wrap)
        }
        foreach ($fd in $findings) {
            if ($null -eq $fd) { continue }
            Add-WCM5FindingRow -Body $exp.Body -Finding $fd -State $State
        }
        $null = Add-WCChild $listHost $exp.Root
    }
}

# ---------------------------------------------------------------------------
# HANH DONG PHU: mo vi tri / SHA-256 / VirusTotal
# ---------------------------------------------------------------------------
function Open-WCM5Location {
    param($Finding)
    $f = $Finding
    $kind = [string](Get-WCProp $f 'OpenKind')
    try {
        switch ($kind) {
            'file' {
                $p = [string](Get-WCProp $f 'OpenPath')
                if ([string]::IsNullOrEmpty($p)) { $p = [string](Get-WCProp $f 'Path') }
                if ((-not [string]::IsNullOrEmpty($p)) -and (Test-Path -LiteralPath $p)) {
                    Start-Process explorer.exe -ArgumentList ('/select,"' + $p + '"')
                } else {
                    $parent = ''
                    try { $parent = Split-Path -Path $p -Parent } catch { }
                    if ((-not [string]::IsNullOrEmpty($parent)) -and (Test-Path -LiteralPath $parent)) {
                        Start-Process explorer.exe -ArgumentList $parent
                        Show-WCToast (T 'm5.open.parent') 'Info'
                    } else {
                        Show-WCToast (T 'm5.filenotfound') 'Warn'
                    }
                }
            }
            'svc' {
                $p = [string](Get-WCProp $f 'Path')
                if ((-not [string]::IsNullOrEmpty($p)) -and (Test-Path -LiteralPath $p)) {
                    Start-Process explorer.exe -ArgumentList ('/select,"' + $p + '"')
                } else {
                    Start-Process services.msc
                }
            }
            'reg' {
                $rp = [string](Get-WCProp $f 'RegPath')
                if (-not [string]::IsNullOrEmpty($rp)) {
                    # Regedit khong nhan tham so nhay den khoa -> copy duong dan
                    # dang .NET de nguoi dung dan vao thanh dia chi cua Registry Editor
                    Set-WCClipboard (ConvertTo-WCM5NetRegPath $rp)
                    Start-Process regedit
                    Show-WCToast (T 'm5.reg.copied') 'Info'
                }
            }
            'taskschd' { Start-Process taskschd.msc }
            'hosts' {
                $hp = [string](Get-WCProp $f 'OpenPath')
                Start-Process notepad.exe -ArgumentList ('"' + $hp + '"')
            }
            default { }
        }
    } catch {
        Show-WCToast (T 'common.cannotopen') 'Warn'
    }
}

function Invoke-WCM5Hash {
    # Tinh SHA-256 o nen roi: hien Show-WCInfo + copy clipboard; OpenVt = chi mo
    # link tra CUU hash tren VirusTotal, KHONG tai tep len
    param($State, $Finding, [bool]$OpenVt)
    $f = $Finding
    $p = [string](Get-WCProp $f 'Path')
    if ([string]::IsNullOrEmpty($p)) {
        Show-WCToast (T 'm5.filenotfound') 'Warn'
        return
    }
    $ok = Start-WCTask -Id 'm5.hash' -Title (T 'm5.hash.title') -Args @{ Path = $p; OpenVt = $OpenVt } -Worker {
        param($ctx, $s)
        if ($ctx.Cancelled()) { return $null }
        try {
            $h = Get-FileHash -LiteralPath ([string]$s['Path']) -Algorithm SHA256 -ErrorAction Stop
            return [PSCustomObject]@{
                Hash = [string](Get-WCProp $h 'Hash')
                Path = [string]$s['Path']
                OpenVt = ([bool]$s['OpenVt'])
            }
        } catch {
            return [PSCustomObject]@{ Error = $_.Exception.Message }
        }
    } -Done {
        param($r)
        if ($null -eq $r) { return }
        if (Get-WCProp $r 'Error') {
            Show-WCError (T 'm5.filenotfound') ([string](Get-WCProp $r 'Error'))
            return
        }
        $hash = [string](Get-WCProp $r 'Hash')
        Set-WCClipboard $hash
        if ((Get-WCProp $r 'OpenVt') -eq $true) {
            Show-WCToast (T 'm5.vt.opening') 'Info'
            try {
                Start-Process ('https://www.virustotal.com/gui/search/' + $hash)
            } catch {
                Show-WCToast (T 'common.cannotopen') 'Warn'
            }
        } else {
            Show-WCInfo -Title (T 'm5.hash.title') -Message (T 'm5.hash.msg' @($hash, [string](Get-WCProp $r 'Path')))
        }
    }.GetNewClosure()
    if (-not $ok) {
        Show-WCToast (T 'common.running' @((T 'm5.hash.title'))) 'Info'
    }
}

# ---------------------------------------------------------------------------
# PANEL CHINH
# ---------------------------------------------------------------------------
function New-WCM5Panel {
    param($State)
    $root = New-Object Windows.Controls.ScrollViewer
    $root.VerticalScrollBarVisibility = [Windows.Controls.ScrollBarVisibility]::Auto
    $hostPanel = New-WCVStack -Spacing 14
    $hostPanel.Margin = (New-Object Windows.Thickness(20))
    $root.Content = $hostPanel

    # Tieu de + chip "chua kiem chung runtime" (trung thuc — spec 1.6)
    $titleRow = New-WCHStack -Spacing 10
    $titleRow.Children.Add((New-WCHeading (T 'm5.title'))) | Out-Null
    $betaChip = New-WCChip -Text (T 'common.beta') -Kind 'Warn'
    $betaChip.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $titleRow.Children.Add($betaChip) | Out-Null
    $null = Add-WCChild $hostPanel $titleRow
    $null = Add-WCChild $hostPanel (New-WCSubtitle (T 'm5.subtitle'))

    # Su that ve tool (spec M5: su that phai the hien trong UI)
    $factSec = New-WCSection -Title (T 'm5.fact.title')
    $null = Add-WCChild $factSec.Body (New-WCTextBlock -Text (T 'm5.fact') -Size 12.5 -ColorKey 'WcSubtle' -Wrap)
    $null = Add-WCChild $hostPanel $factSec.Root

    # ---- Lop 1: trang thai bao ve ----
    $l1 = New-WCSection -Title (T 'm5.l1.title') -Subtitle (T 'm5.l1.subtitle')
    foreach ($src in (Get-WCM5L1Sources)) {
        $State['L1'][$src] = (New-WCM5L1Block -Parent $l1.Body -Title (T ('m5.l1.s.' + $src)))
    }
    $refreshBtn = New-WCButton -Text (T 'common.refresh') -OnClick {
        param($b)
        Invoke-WCM5RefreshStatus $State
    }.GetNewClosure()
    $null = Add-WCChild $l1.Body $refreshBtn
    $null = Add-WCChild $hostPanel $l1.Root

    # ---- Lop 2: quet Defender ----
    $l2 = New-WCSection -Title (T 'm5.l2.title') -Subtitle (T 'm5.l2.subtitle')
    $btnRow = New-WCHStack -Spacing 8
    $btnRow.Children.Add((New-WCButton -Text (T 'm5.l2.sig') -OnClick {
        param($b)
        Invoke-WCM5SignatureUpdate $State
    }.GetNewClosure())) | Out-Null
    $btnRow.Children.Add((New-WCButton -Text (T 'm5.l2.quick') -OnClick {
        param($b)
        Invoke-WCM5Scan $State 'Quick'
    }.GetNewClosure())) | Out-Null
    $btnRow.Children.Add((New-WCButton -Text (T 'm5.l2.full') -OnClick {
        param($b)
        Invoke-WCM5Scan $State 'Full'
    }.GetNewClosure())) | Out-Null
    $btnRow.Children.Add((New-WCButton -Text (T 'm5.l2.wdo') -Kind Danger -OnClick {
        param($b)
        Invoke-WCM5OfflineScan $State
    }.GetNewClosure())) | Out-Null
    $null = Add-WCChild $l2.Body $btnRow
    # Quet thu muc tuy chon: TextBox trong panel + nut quet (khong dung dialog)
    $folderRow = New-WCHStack -Spacing 8
    $folderLbl = New-WCTextBlock -Text (T 'm5.l2.folder.hint') -Size 12.5 -ColorKey 'WcSubtle'
    $folderLbl.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $null = Add-WCChild $folderRow $folderLbl
    $box = New-Object Windows.Controls.TextBox
    $box.Style = (Get-WCControlStyles)['WcInput']
    $box.Width = 300
    $null = Add-WCChild $folderRow $box
    $State['FolderBox'] = $box
    $null = Add-WCChild $folderRow (New-WCButton -Text (T 'm5.l2.custom') -OnClick {
        param($b)
        Invoke-WCM5Scan $State 'Custom'
    }.GetNewClosure())
    $null = Add-WCChild $l2.Body $folderRow
    # Trang thai quet (elapsed + ghi ro khong co % that)
    $l2Status = New-WCTextBlock -Text (T 'm5.l2.status.idle') -Size 12 -ColorKey 'WcSubtle' -Wrap
    $State['L2Status'] = $l2Status
    $null = Add-WCChild $l2.Body $l2Status
    $null = Add-WCChild $l2.Body (New-WCExpertLine -Command (T 'm5.expert.l2'))
    $null = Add-WCChild $hostPanel $l2.Root

    # Ket qua de doa
    $thr = New-WCSection -Title (T 'm5.threat.title') -Subtitle (T 'm5.threat.subtitle')
    $null = Add-WCChild $thr.Body (New-WCButton -Text (T 'm5.threat.refresh') -Small -OnClick {
        param($b)
        Invoke-WCM5LoadThreats $State
    }.GetNewClosure())
    $thrHost = New-WCVStack -Spacing 6
    $State['ThreatHost'] = $thrHost
    $null = Add-WCChild $thr.Body $thrHost
    $thr.Root.Visibility = [Windows.Visibility]::Collapsed
    $State['ThreatSection'] = $thr
    $null = Add-WCChild $hostPanel $thr.Root

    # ---- Lop 3: heuristic ----
    $l3 = New-WCSection -Title (T 'm5.l3.title') -Subtitle (T 'm5.l3.subtitle')
    $null = Add-WCChild $l3.Body (New-WCButton -Text (T 'm5.l3.scan') -Kind Primary -OnClick {
        param($b)
        Invoke-WCM5HeurScan $State
    }.GetNewClosure())
    $l3SummaryHost = New-WCHStack -Spacing 0
    $State['L3SummaryHost'] = $l3SummaryHost
    $null = Add-WCChild $l3.Body $l3SummaryHost
    $l3Spinner = New-WCSpinner -Text (T 'm5.l3.scanning')
    $l3Spinner.Visibility = [Windows.Visibility]::Collapsed
    $State['L3Spinner'] = $l3Spinner
    $null = Add-WCChild $l3.Body $l3Spinner
    $l3Host = New-WCVStack -Spacing 8
    $State['L3Host'] = $l3Host
    $null = Add-WCChild $l3.Body $l3Host
    $null = Add-WCChild $l3.Body (New-WCExpertLine -Command (T 'm5.expert.l3'))
    $null = Add-WCChild $hostPanel $l3.Root

    Set-WCM5SummaryChips $State -1 -1 -1
    return $root
}

function Invoke-WCM5OnShow {
    # Tai du lieu ve dan: 7 nguon Lop 1 chay nen rieng biet; de doa + heuristic
    # tai 1 lan dau
    param($State)
    foreach ($src in (Get-WCM5L1Sources)) {
        Start-WCM5StatusTask $State $src $false
    }
    if (-not $State['ThreatsLoaded']) { Invoke-WCM5LoadThreats $State }
    if (-not $State['HeurStarted']) {
        $State['HeurStarted'] = $true
        Invoke-WCM5HeurScan $State
    }
}

# ---------------------------------------------------------------------------
# KHOI TAO MODULE (buoc cuoi file — dang ky nav theo CONTRACT)
# ---------------------------------------------------------------------------
function Initialize-WCModuleM5 {
    $state = @{
        L1 = @{}
        L2Status = $null
        FolderBox = $null
        ThreatHost = $null
        ThreatSection = $null
        ThreatsLoaded = $false
        L3Host = $null
        L3Spinner = $null
        L3SummaryHost = $null
        HeurStarted = $false
    }
    Register-WCNavItem -Key 'm5' -Badge 'M5' -Title (T 'm5.title') -Order 60 -Builder {
        New-WCM5Panel $state
    }.GetNewClosure() -OnShow {
        Invoke-WCM5OnShow $state
    }.GetNewClosure()
}
