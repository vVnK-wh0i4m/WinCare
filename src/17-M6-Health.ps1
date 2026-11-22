# ============================================================================
#  src/17-M6-Health.ps1 - Module M6: KIEM TRA SUC KHOE MAY
#  Diem 0-100 KEM bang phan ra MINH BACH (nguoi dung thay diem den tu dau).
#  Trong so tham khao: Luu tru 25, On dinh 25, Toan ven 15, Bao mat 15,
#  Bo nho 10, Pin 10. Nhom khong doc duoc BI BO khoi mau so (chia lai trong so).
#  Tran: SMART hong / loi RAM / dia loi lap -> diem toi da 49.
#
#  FIXTURE (WINCARE_FIXTURE=file.json) - cac key module M6 dung de thay the:
#    health.physicaldisks : { Ok, Disks: [ { DeviceId, Name, Media, Health, OpStatus } ] }
#    health.reliability   : { Ok, Counters: [ { DeviceId, Temp, Wear, Hours, ReadErrors, ReadUncorr, WriteErrors } ] }
#    health.volumes       : { Ok, Volumes: [ { Letter, Size, Free, PctFree } ] }
#    health.events        : { Ok, SystemOk, AppOk,
#                             Cats: { kpower41, whea, bugcheck, diskerr, tdr, svc,
#                                     appcrash, wheamem, memdiagerr, memdiagok },
#                             BugCodes: [] }
#    health.dism          : { Ok, ExitCode }          (DISM /CheckHealth - CheckHealth)
#    health.sfc           : { Ok, ExitCode }          (SFC /verifyonly)
#    health.battery       : { Ok, HasBattery, Batteries: [ { Design, Full, Wear } ] }
#    health.mp            : { Mode: defender|thirdparty|unknown, AvName, RealTime,
#                             SigAgeDays, Engine, Tamper, LastQuick, LastFull }
#    (khi khong co fixture, health.mp goi lai nguon 'sec.mpstatus' cua M5 qua cache)
#
#  KHONG parse output text cua sfc/dism (chi ExitCode). Event log loc theo
#  ProviderName + Id (khong phu thuoc ngon ngu). Comment tieng Viet khong dau.
# ============================================================================

Register-WCStrings 'vi' @{
    'm6.title' = 'Kiểm tra sức khỏe máy'
    'm6.subtitle' = 'Điểm 0-100 kèm bảng phân rã minh bạch — bạn thấy rõ điểm đến từ đâu, không phóng đại, không đoán.'
    'm6.score' = 'Điểm sức khỏe'
    'm6.score.howto' = 'Cách tính: Lưu trữ 25% · Ổn định 25% · Toàn vẹn hệ thống 15% · Bảo mật 15% · Bộ nhớ 10% · Pin 10%. Nhóm không đo được bị BỎ khỏi mẫu số (trọng số chia lại cho các nhóm còn lại, không bị coi là điểm tối đa). Dấu hiệu nghiêm trọng (SMART hỏng, lỗi RAM, đĩa lỗi lặp lặp) → điểm bị trần 49.'
    'm6.score.nodata' = 'Chưa đủ dữ liệu để chấm điểm.'
    'm6.score.band.good' = 'Tốt — 75-100 điểm'
    'm6.score.band.mid' = 'Trung bình — 50-74 điểm'
    'm6.score.band.bad' = 'Kém — 0-49 điểm'
    'm6.score.cap' = 'Điểm bị giới hạn tối đa 49 vì dấu hiệu nghiêm trọng: {0}'
    'm6.score.renorm' = 'Bỏ qua (không có dữ liệu): {0} — trọng số còn lại được chia lại cho các nhóm đã đo.'
    'm6.scan.at' = 'Quét lúc {0}'
    'm6.scan.pending' = 'Đang quét ({0}/{1} nhóm có kết quả)…'
    'm6.scan.done' = 'Đã quét đủ 6 nhóm.'
    'm6.breakdown.title' = 'Bảng phân rã — điểm đến từ đâu'
    'm6.breakdown.sub' = 'Mỗi nhóm chấm 0-100 rồi nhân trọng số. Mỗi điểm trừ đều kèm lý do cụ thể bên cạnh.'
    'm6.col.group' = 'Nhóm'
    'm6.col.weight' = 'Trọng số'
    'm6.col.score' = 'Điểm'
    'm6.col.why' = 'Tại sao'
    'm6.col.what' = 'Nên làm gì'
    'm6.detail' = 'Chi tiết'
    'm6.action.detail' = 'Xem chi tiết'
    'm6.skipped' = 'Bỏ qua (không có dữ liệu)'
    'm6.why.nodata' = 'Không đủ dữ liệu — nhóm này bị bỏ khỏi công thức điểm, không bị tính là điểm xấu.'
    'm6.status.scanning' = 'Đang quét…'
    'm6.busy' = 'Đang có tác vụ của mục này chạy — chờ hoàn tất rồi thử lại.'
    'm6.rescan.busy' = 'Đang quét — chờ hoàn tất rồi bấm Quét lại.'
    'm6.on' = 'Bật'
    'm6.off' = 'Tắt'
    'm6.fmt.hours' = '{0} giờ'
    'm6.fmt.errs' = '{0} (chưa sửa được: {1})'
    'm6.fmt.mwh' = '{0} mWh'
    'm6.fact.cancelled' = 'Đã hủy quét nhóm này — chưa có số liệu.'
    # --- Nhom ---
    'm6.group.storage' = 'Lưu trữ'
    'm6.group.storage.tip' = 'Sức khỏe từng ổ (Get-PhysicalDisk), SMART (Get-StorageReliabilityCounter: nhiệt độ, hao mòn SSD, giờ bật, lỗi đọc/ghi) và dung lượng trống của từng volume.'
    'm6.group.stability' = 'Ổn định (30 ngày)'
    'm6.group.stability.tip' = 'Đọc nhật ký sự kiện 30 ngày theo nhà cung cấp + mã sự kiện (không phụ thuộc ngôn ngữ): BSOD, tắt đột ngột, lỗi phần cứng, lỗi đĩa, dịch vụ chết, ứng dụng treo.'
    'm6.group.integrity' = 'Toàn vẹn hệ thống'
    'm6.group.integrity.tip' = 'DISM /CheckHealth (nhanh) + SFC /verifyonly (chỉ kiểm tra, không sửa). Kết luận chỉ dựa trên mã thoát — không chắc thì ghi "Không kết luận được".'
    'm6.group.security' = 'Bảo mật'
    'm6.group.security.tip' = 'Trạng thái Microsoft Defender (bảo vệ thời gian thực, tuổi chữ ký) — dùng lại nguồn dữ liệu của mục M5, không quét trùng.'
    'm6.group.memory' = 'Bộ nhớ (RAM)'
    'm6.group.memory.tip' = 'Sự kiện lỗi bộ nhớ WHEA trong 30 ngày và kết quả Windows Memory Diagnostic (nếu chạy trong 30 ngày).'
    'm6.group.battery' = 'Pin'
    'm6.group.battery.tip' = 'Độ chai pin: so sánh dung lượng sạc đầy hiện tại với dung lượng thiết kế (root\wmi).'
    # --- Luu tru ---
    'm6.fact.storage.ok' = 'Cả {0} ổ đều Healthy, không có lỗi đọc/ghi đáng kể, dung lượng còn thoải mái.'
    'm6.fact.storage.diskwarn' = 'Ổ "{0}" đang ở trạng thái Warning (SMART cảnh báo).'
    'm6.fact.storage.diskbad' = 'Ổ "{0}" bị báo HỎNG/sắp hỏng — cần sao lưu dữ liệu ngay.'
    'm6.fact.storage.opstat' = 'Ổ "{0}" trạng thái vận hành: {1}.'
    'm6.fact.storage.temp.warn' = 'Ổ "{0}" nhiệt độ {1}°C — hơi cao.'
    'm6.fact.storage.temp.hot' = 'Ổ "{0}" đang nóng: {1}°C.'
    'm6.fact.storage.wear' = 'SSD "{0}" đã hao mòn {1}%.'
    'm6.fact.storage.readerr' = 'Ổ "{0}" ghi nhận {1} lỗi đọc tổng cộng ({2} lỗi không sửa được).'
    'm6.fact.storage.lowfree' = 'Ổ {0} chỉ còn {1}% dung lượng trống.'
    'm6.fact.storage.nosmart' = 'Không đọc được chỉ số SMART (ổ USB/bridge thường không có) — các cột SMART hiển thị N/A, không trừ điểm.'
    'm6.fact.storage.diskna' = 'Không đọc được trạng thái ổ đĩa (Get-PhysicalDisk) — chỉ đánh giá dung lượng trống.'
    'm6.fact.storage.nodata' = 'Không đọc được thông tin lưu trữ.'
    'm6.storage.what.ok' = 'Không cần làm gì — tiếp tục sao lưu định kỳ.'
    'm6.storage.what.warn' = 'Xem SMART chi tiết, sao lưu dữ liệu; nếu ổ đầy thì dọn đĩa (M2).'
    'm6.storage.what.bad' = 'SAO LƯU DỮ LIỆU NGAY và cân nhắc thay ổ (xem M2).'
    'm6.storage.col.disk' = 'Ổ'
    'm6.storage.col.media' = 'Loại'
    'm6.storage.col.health' = 'Sức khỏe'
    'm6.storage.col.temp' = 'Nhiệt độ'
    'm6.storage.col.wear' = 'Hao mòn'
    'm6.storage.col.hours' = 'Giờ bật'
    'm6.storage.col.readerr' = 'Lỗi đọc'
    'm6.storage.col.vol' = 'Ổ đĩa'
    'm6.storage.col.size' = 'Dung lượng'
    'm6.storage.col.free' = 'Còn trống'
    'm6.storage.col.pct' = '% trống'
    # --- On dinh ---
    'm6.fact.stab.ok' = 'Không có sự cố nghiêm trọng nào trong 30 ngày.'
    'm6.fact.stab.kpower41' = 'Tắt đột ngột / mất nguồn: {0} lần.'
    'm6.fact.stab.whea' = 'Lỗi phần cứng (WHEA): {0} lần.'
    'm6.fact.stab.bugcheck' = 'Màn hình xanh (BSOD): {0} lần (mã: {1}).'
    'm6.fact.stab.diskerr' = 'Lỗi đĩa (disk/Ntfs): {0} lần.'
    'm6.fact.stab.tdr' = 'Card đồ họa bị reset (TDR): {0} lần.'
    'm6.fact.stab.svc' = 'Dịch vụ Windows dừng đột ngột: {0} lần.'
    'm6.fact.stab.appcrash' = 'Ứng dụng bị lỗi/treo: {0} lần.'
    'm6.fact.stab.applog' = 'Nhật ký Application không đọc được — số liệu ứng dụng có thể thiếu, không trừ điểm vì thiếu dữ liệu.'
    'm6.fact.stab.nodata' = 'Không đủ dữ liệu (không đọc được nhật ký System) — không đoán.'
    'm6.stability.what.ok' = 'Không cần làm gì.'
    'm6.stability.what.warn' = 'Xem chi tiết từng loại sự cố bên dưới; lỗi lặp lại nên kiểm tra driver (M3) và phần cứng.'
    'm6.stab.none' = 'Không có sự cố nào được ghi nhận trong 30 ngày.'
    'm6.stab.kpower41.desc' = 'Máy tắt mà không qua quy trình tắt máy (mất điện, treo cứng, giữ nút nguồn).'
    'm6.stab.kpower41.fix' = 'Nếu lặp lại: kiểm tra nguồn/pin và nhiệt độ; lưu công việc thường xuyên.'
    'm6.stab.whea.desc' = 'Windows ghi nhận lỗi phần cứng đã sửa hoặc chưa sửa (CPU, RAM, bus…).'
    'm6.stab.whea.fix' = 'Lặp lại nhiều lần: chạy kiểm tra RAM (nhóm Bộ nhớ) và cập nhật BIOS/driver.'
    'm6.stab.bugcheck.desc' = 'Hệ thống dừng vì lỗi nghiêm trọng và tự khởi động lại.'
    'm6.stab.bugcheck.fix' = 'Ghi lại mã BugCheck, tìm driver/phần cứng liên quan; cập nhật driver ở M3.'
    'm6.stab.diskerr.desc' = 'Ổ lưu trữ hoặc hệ thống file báo lỗi đọc/ghi/lỗi cấu trúc.'
    'm6.stab.diskerr.fix' = 'Kiểm tra SMART ở nhóm Lưu trữ; sao lưu dữ liệu; chạy chkdsk nếu Windows gợi ý.'
    'm6.stab.tdr.desc' = 'Driver GPU bị treo và Windows đã reset nó (màn hình nháy đen/lag).'
    'm6.stab.tdr.fix' = 'Cập nhật driver GPU (M3); bỏ xung nếu đang overclock.'
    'm6.stab.svc.desc' = 'Dịch vụ hệ thống bị chết đột ngột (crash).'
    'm6.stab.svc.fix' = 'Nếu lặp lại: mở Trình xem sự kiện xem tên dịch vụ và tìm bản cập nhật.'
    'm6.stab.appcrash.desc' = 'Ứng dụng gặp lỗi nghiêm trọng hoặc bị treo.'
    'm6.stab.appcrash.fix' = 'Cập nhật/gỡ cài đặt ứng dụng liên quan — ảnh hưởng rất nhỏ đến điểm tổng thể.'
    # --- Toan ven ---
    'm6.fact.int.dism.ok' = 'DISM /CheckHealth: không phát hiện cờ hỏng (mã thoát 0).'
    'm6.fact.int.dism.unknown' = 'DISM /CheckHealth: không kết luận được (mã thoát {0}).'
    'm6.fact.int.dism.norun' = 'DISM /CheckHealth: không chạy được.'
    'm6.fact.int.sfc.ok' = 'SFC /verifyonly: không phát hiện lỗi file hệ thống (mã thoát 0).'
    'm6.fact.int.sfc.unknown' = 'SFC /verifyonly: không kết luận được (mã thoát {0}) — có thể có lỗi hệ thống.'
    'm6.fact.int.sfc.norun' = 'SFC /verifyonly: không chạy được.'
    'm6.integrity.what.ok' = 'Không cần làm gì.'
    'm6.integrity.what.warn' = 'Chạy "Kiểm tra sâu (DISM ScanHealth)" để chắc hơn — ước tính 5-15 phút.'
    'm6.integrity.p.dism' = 'Đang chạy DISM /CheckHealth (nhanh)…'
    'm6.integrity.p.sfc' = 'Đang chạy SFC /verifyonly (chỉ kiểm tra — có thể mất vài phút)…'
    'm6.integrity.dism.exit' = 'DISM /CheckHealth — mã thoát'
    'm6.integrity.sfc.exit' = 'SFC /verifyonly — mã thoát'
    'm6.integrity.deep.result' = 'Kiểm tra sâu gần nhất'
    'm6.integrity.deep' = 'Kiểm tra sâu (DISM ScanHealth)'
    'm6.integrity.deep.confirm.title' = 'Chạy kiểm tra sâu?'
    'm6.integrity.deep.confirm.msg' = 'DISM /Online /Cleanup-Image /ScanHealth — quét kỹ kho thành phần, ước tính 5-15 phút, chạy nền và HỦY ĐƯỢC. Chỉ quét, không sửa gì.'
    'm6.integrity.deep.running' = 'Đang quét sâu DISM ScanHealth (ước tính 5-15 phút)…'
    'm6.integrity.deep.done.ok' = 'Quét sâu hoàn tất: DISM không báo cờ hỏng (mã thoát 0).'
    'm6.integrity.deep.done.unknown' = 'Quét sâu xong nhưng không kết luận được (mã thoát {0}).'
    # --- Bao mat ---
    'm6.fact.sec.rtp.on' = 'Bảo vệ thời gian thực đang bật.'
    'm6.fact.sec.ok.sig' = 'Chữ ký Defender mới ({0} ngày).'
    'm6.fact.sec.sigold' = 'Chữ ký Defender đã {0} ngày tuổi — nên cập nhật.'
    'm6.fact.sec.sig.na' = 'Không đọc được tuổi chữ ký.'
    'm6.fact.sec.rtp.off' = 'Bảo vệ thời gian thực đang TẮT.'
    'm6.fact.sec.rtp.na' = 'Không đọc được trạng thái bảo vệ thời gian thực.'
    'm6.fact.sec.third' = 'Đang dùng antivirus bên thứ ba ({0}) — WinCare không chấm điểm thay họ.'
    'm6.fact.sec.nodata' = 'Không đọc được trạng thái bảo vệ.'
    'm6.security.what.ok' = 'Không cần làm gì.'
    'm6.security.what.rtp' = 'Bật lại bảo vệ thời gian thực trong Windows Security (xem mục Bảo mật M5).'
    'm6.security.what.sig' = 'Cập nhật chữ ký Defender (mục M5).'
    'm6.security.what.warn' = 'Kiểm tra lại trạng thái bảo vệ ở mục Bảo mật (M5).'
    'm6.security.rtp' = 'Bảo vệ thời gian thực'
    'm6.security.sigage' = 'Tuổi chữ ký'
    'm6.security.engine' = 'Phiên bản engine'
    'm6.security.tamper' = 'Chống giả mạo (Tamper Protection)'
    'm6.security.lastquick' = 'Quét nhanh gần nhất'
    'm6.security.lastfull' = 'Quét toàn bộ gần nhất'
    'm6.security.av' = 'Antivirus'
    # --- Bo nho ---
    'm6.fact.mem.ok' = 'Không thấy lỗi RAM nào trong nhật ký 30 ngày.'
    'm6.fact.mem.whea' = 'Có {0} sự kiện lỗi bộ nhớ (WHEA) trong 30 ngày.'
    'm6.fact.mem.diag' = 'Windows Memory Diagnostic phát hiện lỗi phần cứng bộ nhớ (trong 30 ngày).'
    'm6.fact.mem.diagok' = 'Lần chạy Windows Memory Diagnostic gần nhất (30 ngày): không phát hiện lỗi.'
    'm6.fact.mem.nodata' = 'Không đủ dữ liệu (không đọc được nhật ký System).'
    'm6.memory.what.ok' = 'Không cần làm gì.'
    'm6.memory.what.test' = 'Chạy Windows Memory Diagnostic để kiểm tra kỹ hơn (cần khởi động lại).'
    'm6.memory.run' = 'Chạy Windows Memory Diagnostic'
    'm6.memory.confirm.title' = 'Chạy Windows Memory Diagnostic?'
    'm6.memory.confirm.msg' = 'WinCare sẽ chỉ MỞ công cụ của Windows — công cụ này sẽ hỏi bạn khởi động lại NGAY hay vào lần tắt máy sau. WinCare không tự khởi động lại máy. Hãy lưu công việc trước.'
    'm6.memory.opened' = 'Đã mở Windows Memory Diagnostic.'
    'm6.memory.wheacount' = 'Sự kiện lỗi bộ nhớ (WHEA, 30 ngày)'
    'm6.memory.diagresult' = 'Windows Memory Diagnostic (30 ngày)'
    'm6.memory.diag.err' = 'Phát hiện lỗi phần cứng bộ nhớ'
    'm6.memory.diag.ok' = 'Không phát hiện lỗi'
    'm6.memory.diag.none' = 'Chưa chạy trong 30 ngày'
    # --- Pin ---
    'm6.fact.bat.ok' = 'Pin chai {0}% — trong ngưỡng bình thường.'
    'm6.fact.bat.wear' = 'Pin đã chai {0}% (sạc đầy {1}/{2} mWh so với thiết kế).'
    'm6.fact.bat.absent' = 'Máy không có pin — nhóm bị bỏ khỏi công thức điểm.'
    'm6.fact.bat.nodata' = 'Không đọc được dữ liệu pin (máy không có pin hoặc không đọc được) — nhóm bị bỏ.'
    'm6.fact.bat.nowear' = 'Không tính được độ chai (thiếu dung lượng thiết kế) — nhóm bị bỏ.'
    'm6.battery.what.ok' = 'Không cần làm gì.'
    'm6.battery.what.wear' = 'Giảm thói quen sạc kiệt 0% nếu cần dùng lâu; chai nặng thì thay pin.'
    'm6.battery.design' = 'Dung lượng thiết kế'
    'm6.battery.full' = 'Sạc đầy hiện tại'
    'm6.battery.wear' = 'Độ chai'
    # --- Sua loi (nang cao) ---
    'm6.repair.title' = 'Nâng cao — Sửa lỗi hệ thống'
    'm6.repair.subtitle' = 'Chỉ dùng khi kiểm tra phát hiện vấn đề. Có xác nhận, thử tạo điểm khôi phục trước, báo thời gian ước tính. Không hoàn tác tự động.'
    'm6.repair.dism' = 'Sửa kho thành phần (DISM RestoreHealth)'
    'm6.repair.dism.eta' = 'Ước tính 10-30 phút, có thể cần mạng.'
    'm6.repair.sfc' = 'Sửa file hệ thống (SFC /scannow)'
    'm6.repair.sfc.eta' = 'Ước tính 5-15 phút.'
    'm6.repair.confirm.title' = 'Xác nhận sửa lỗi hệ thống'
    'm6.repair.confirm.msg.dism' = "Sẽ chạy: DISM /Online /Cleanup-Image /RestoreHealth (ước tính 10-30 phút).`nNên để chạy hết — hủy giữa chừng có thể phải chạy lại từ đầu."
    'm6.repair.confirm.msg.sfc' = "Sẽ chạy: sfc.exe /scannow (ước tính 5-15 phút).`nNên để chạy hết — hủy giữa chừng có thể phải chạy lại từ đầu."
    'm6.repair.noundo' = 'File hệ thống/kho thành phần bị thay thế KHÔNG hoàn tác tự động được. WinCare sẽ thử tạo điểm khôi phục System Restore trước khi chạy.'
    'm6.repair.cp.running' = 'Đang thử tạo điểm khôi phục…'
    'm6.repair.cp.fail' = 'Không tạo được điểm khôi phục: {0}'
    'm6.repair.cp.ask.title' = 'Tiếp tục mà không có điểm khôi phục?'
    'm6.repair.cp.ask.msg' = 'System Restore có thể đang tắt trên máy này. Nếu tiếp tục, việc sửa lỗi sẽ KHÔNG có điểm khôi phục để quay lại.'
    'm6.repair.running' = 'Đang sửa lỗi hệ thống'
    'm6.repair.done.ok' = 'Sửa hoàn tất (mã thoát 0). Nên bấm "Quét lại" để xem điểm mới.'
    'm6.repair.done.unknown' = 'Chạy xong nhưng không kết luận được (mã thoát {0}) — xem chi tiết trong nhật ký.'
    'm6.repair.cancelled' = 'Đã hủy — có thể phải chạy lại từ đầu lần sau.'
    'm6.repair.journal.dism' = 'Sửa kho thành phần (DISM RestoreHealth)'
    'm6.repair.journal.sfc' = 'Sửa file hệ thống (SFC /scannow)'
}
Register-WCStrings 'en' @{
    'm6.title' = 'PC health check'
    'm6.subtitle' = 'A 0-100 score with a fully transparent breakdown — you see exactly where the score comes from. No hype, no guessing.'
    'm6.score' = 'Health score'
    'm6.score.howto' = 'How it is computed: Storage 25% · Stability 25% · System integrity 15% · Security 15% · Memory 10% · Battery 10%. Groups that cannot be read are REMOVED from the denominator (weights are re-split; never counted as full marks). Serious signs (failing SMART, RAM errors, repeated disk errors) cap the score at 49.'
    'm6.score.nodata' = 'Not enough data to compute a score yet.'
    'm6.score.band.good' = 'Good — 75-100'
    'm6.score.band.mid' = 'Fair — 50-74'
    'm6.score.band.bad' = 'Poor — 0-49'
    'm6.score.cap' = 'Score capped at 49 due to serious signs: {0}'
    'm6.score.renorm' = 'Skipped (no data): {0} — remaining weights are re-split across the measured groups.'
    'm6.scan.at' = 'Scanned at {0}'
    'm6.scan.pending' = 'Scanning ({0}/{1} groups reported)…'
    'm6.scan.done' = 'All 6 groups scanned.'
    'm6.breakdown.title' = 'Breakdown — where the score comes from'
    'm6.breakdown.sub' = 'Each group is scored 0-100 then weighted. Every deduction comes with its specific reason.'
    'm6.col.group' = 'Group'
    'm6.col.weight' = 'Weight'
    'm6.col.score' = 'Score'
    'm6.col.why' = 'Why'
    'm6.col.what' = 'What to do'
    'm6.detail' = 'Details'
    'm6.action.detail' = 'View details'
    'm6.skipped' = 'Skipped (no data)'
    'm6.why.nodata' = 'Not enough data — this group is removed from the score formula, not counted as bad.'
    'm6.status.scanning' = 'Scanning…'
    'm6.busy' = 'A task from this page is already running — wait for it to finish.'
    'm6.rescan.busy' = 'Still scanning — wait for it to finish, then rescan.'
    'm6.on' = 'On'
    'm6.off' = 'Off'
    'm6.fmt.hours' = '{0} hours'
    'm6.fmt.errs' = '{0} (uncorrected: {1})'
    'm6.fmt.mwh' = '{0} mWh'
    'm6.fact.cancelled' = 'Scan of this group was cancelled — no data yet.'
    'm6.group.storage' = 'Storage'
    'm6.group.storage.tip' = 'Per-disk health (Get-PhysicalDisk), SMART (Get-StorageReliabilityCounter: temperature, SSD wear, power-on hours, read/write errors) and free space per volume.'
    'm6.group.stability' = 'Stability (30 days)'
    'm6.group.stability.tip' = 'Reads the last 30 days of event logs by provider + event ID (language-independent): BSOD, unexpected shutdowns, hardware errors, disk errors, service crashes, app hangs.'
    'm6.group.integrity' = 'System integrity'
    'm6.group.integrity.tip' = 'DISM /CheckHealth (fast) + SFC /verifyonly (verify only, fixes nothing). Conclusions are based on exit codes only — "Inconclusive" when not sure.'
    'm6.group.security' = 'Security'
    'm6.group.security.tip' = 'Microsoft Defender status (real-time protection, signature age) — reuses the M5 data source, no duplicate scanning.'
    'm6.group.memory' = 'Memory (RAM)'
    'm6.group.memory.tip' = 'WHEA memory-error events in the last 30 days plus Windows Memory Diagnostic results if it ran within 30 days.'
    'm6.group.battery' = 'Battery'
    'm6.group.battery.tip' = 'Battery wear: current full-charge capacity vs design capacity (root\wmi).'
    'm6.fact.storage.ok' = 'All {0} disks are Healthy, no significant read/write errors, free space is comfortable.'
    'm6.fact.storage.diskwarn' = 'Disk "{0}" is in Warning state (SMART warning).'
    'm6.fact.storage.diskbad' = 'Disk "{0}" is reported FAILING/about to fail — back up your data now.'
    'm6.fact.storage.opstat' = 'Disk "{0}" operational status: {1}.'
    'm6.fact.storage.temp.warn' = 'Disk "{0}" temperature {1}°C — a bit high.'
    'm6.fact.storage.temp.hot' = 'Disk "{0}" is hot: {1}°C.'
    'm6.fact.storage.wear' = 'SSD "{0}" wear level: {1}%.'
    'm6.fact.storage.readerr' = 'Disk "{0}" recorded {1} total read errors ({2} uncorrected).'
    'm6.fact.storage.lowfree' = 'Volume {0} has only {1}% free space.'
    'm6.fact.storage.nosmart' = 'SMART counters unavailable (USB/bridge disks usually lack them) — SMART columns show N/A, no deduction.'
    'm6.fact.storage.diskna' = 'Disk health status unavailable (Get-PhysicalDisk failed) — only free space was evaluated.'
    'm6.fact.storage.nodata' = 'Storage information could not be read.'
    'm6.storage.what.ok' = 'Nothing to do — keep regular backups.'
    'm6.storage.what.warn' = 'Check SMART details, back up data; clean the disk if it is full (M2).'
    'm6.storage.what.bad' = 'BACK UP YOUR DATA NOW and consider replacing the disk (see M2).'
    'm6.storage.col.disk' = 'Disk'
    'm6.storage.col.media' = 'Type'
    'm6.storage.col.health' = 'Health'
    'm6.storage.col.temp' = 'Temp'
    'm6.storage.col.wear' = 'Wear'
    'm6.storage.col.hours' = 'Power-on'
    'm6.storage.col.readerr' = 'Read errors'
    'm6.storage.col.vol' = 'Volume'
    'm6.storage.col.size' = 'Size'
    'm6.storage.col.free' = 'Free'
    'm6.storage.col.pct' = '% free'
    'm6.fact.stab.ok' = 'No serious incidents in the last 30 days.'
    'm6.fact.stab.kpower41' = 'Unexpected shutdown / power loss: {0} times.'
    'm6.fact.stab.whea' = 'Hardware errors (WHEA): {0} times.'
    'm6.fact.stab.bugcheck' = 'Blue screen (BSOD): {0} times (codes: {1}).'
    'm6.fact.stab.diskerr' = 'Disk errors (disk/Ntfs): {0} times.'
    'm6.fact.stab.tdr' = 'GPU driver reset (TDR): {0} times.'
    'm6.fact.stab.svc' = 'Windows services terminated unexpectedly: {0} times.'
    'm6.fact.stab.appcrash' = 'Applications crashed/hung: {0} times.'
    'm6.fact.stab.applog' = 'Application log unreadable — app statistics may be incomplete; no deduction for missing data.'
    'm6.fact.stab.nodata' = 'Not enough data (System log unreadable) — no guessing.'
    'm6.stability.what.ok' = 'Nothing to do.'
    'm6.stability.what.warn' = 'Review each incident type below; repeated errors deserve a driver (M3) and hardware check.'
    'm6.stab.none' = 'No incidents recorded in the last 30 days.'
    'm6.stab.kpower41.desc' = 'The PC turned off without going through the shutdown flow (power loss, hard freeze, holding the power button).'
    'm6.stab.kpower41.fix' = 'If repeated: check PSU/battery and temperatures; save your work often.'
    'm6.stab.whea.desc' = 'Windows logged corrected or uncorrected hardware errors (CPU, RAM, bus…).'
    'm6.stab.whea.fix' = 'If repeated: run the memory test (Memory group) and update BIOS/drivers.'
    'm6.stab.bugcheck.desc' = 'The system halted due to a serious error and restarted itself.'
    'm6.stab.bugcheck.fix' = 'Note the BugCheck code, look up the related driver/hardware; update drivers in M3.'
    'm6.stab.diskerr.desc' = 'A storage device or the file system reported read/write/structure errors.'
    'm6.stab.diskerr.fix' = 'Check SMART in the Storage group; back up data; run chkdsk if Windows suggests it.'
    'm6.stab.tdr.desc' = 'The GPU driver hung and Windows reset it (screen flickers black/stutters).'
    'm6.stab.tdr.fix' = 'Update the GPU driver (M3); remove overclocks if any.'
    'm6.stab.svc.desc' = 'A Windows service crashed unexpectedly.'
    'm6.stab.svc.fix' = 'If repeated: open Event Viewer for the service name and look for updates.'
    'm6.stab.appcrash.desc' = 'An application hit a critical error or hung.'
    'm6.stab.appcrash.fix' = 'Update/uninstall the affected app — very small impact on the overall score.'
    'm6.fact.int.dism.ok' = 'DISM /CheckHealth: no corruption flag (exit code 0).'
    'm6.fact.int.dism.unknown' = 'DISM /CheckHealth: inconclusive (exit code {0}).'
    'm6.fact.int.dism.norun' = 'DISM /CheckHealth: could not run.'
    'm6.fact.int.sfc.ok' = 'SFC /verifyonly: no system file problems found (exit code 0).'
    'm6.fact.int.sfc.unknown' = 'SFC /verifyonly: inconclusive (exit code {0}) — system errors are possible.'
    'm6.fact.int.sfc.norun' = 'SFC /verifyonly: could not run.'
    'm6.integrity.what.ok' = 'Nothing to do.'
    'm6.integrity.what.warn' = 'Run "Deep check (DISM ScanHealth)" to be surer — takes 5-15 minutes.'
    'm6.integrity.p.dism' = 'Running DISM /CheckHealth (fast)…'
    'm6.integrity.p.sfc' = 'Running SFC /verifyonly (verify only — may take several minutes)…'
    'm6.integrity.dism.exit' = 'DISM /CheckHealth — exit code'
    'm6.integrity.sfc.exit' = 'SFC /verifyonly — exit code'
    'm6.integrity.deep.result' = 'Last deep check'
    'm6.integrity.deep' = 'Deep check (DISM ScanHealth)'
    'm6.integrity.deep.confirm.title' = 'Run deep check?'
    'm6.integrity.deep.confirm.msg' = 'DISM /Online /Cleanup-Image /ScanHealth — thorough component-store scan, estimated 5-15 minutes, runs in background and is CANCELLABLE. Scan only, changes nothing.'
    'm6.integrity.deep.running' = 'Running DISM ScanHealth deep check (estimated 5-15 minutes)…'
    'm6.integrity.deep.done.ok' = 'Deep check finished: DISM reported no corruption flag (exit code 0).'
    'm6.integrity.deep.done.unknown' = 'Deep check finished but inconclusive (exit code {0}).'
    'm6.fact.sec.rtp.on' = 'Real-time protection is on.'
    'm6.fact.sec.ok.sig' = 'Defender signatures are fresh ({0} days).'
    'm6.fact.sec.sigold' = 'Defender signatures are {0} days old — should update.'
    'm6.fact.sec.sig.na' = 'Signature age could not be read.'
    'm6.fact.sec.rtp.off' = 'Real-time protection is OFF.'
    'm6.fact.sec.rtp.na' = 'Real-time protection status could not be read.'
    'm6.fact.sec.third' = 'A third-party antivirus ({0}) is in use — WinCare does not grade it on their behalf.'
    'm6.fact.sec.nodata' = 'Protection status could not be read.'
    'm6.security.what.ok' = 'Nothing to do.'
    'm6.security.what.rtp' = 'Turn real-time protection back on in Windows Security (see M5).'
    'm6.security.what.sig' = 'Update Defender signatures (M5).'
    'm6.security.what.warn' = 'Re-check protection status in the Security page (M5).'
    'm6.security.rtp' = 'Real-time protection'
    'm6.security.sigage' = 'Signature age'
    'm6.security.engine' = 'Engine version'
    'm6.security.tamper' = 'Tamper Protection'
    'm6.security.lastquick' = 'Last quick scan'
    'm6.security.lastfull' = 'Last full scan'
    'm6.security.av' = 'Antivirus'
    'm6.fact.mem.ok' = 'No RAM errors seen in the last 30 days of logs.'
    'm6.fact.mem.whea' = '{0} memory-error (WHEA) events in the last 30 days.'
    'm6.fact.mem.diag' = 'Windows Memory Diagnostic detected a memory hardware problem (within 30 days).'
    'm6.fact.mem.diagok' = 'Latest Windows Memory Diagnostic run (30 days): no errors detected.'
    'm6.fact.mem.nodata' = 'Not enough data (System log unreadable).'
    'm6.memory.what.ok' = 'Nothing to do.'
    'm6.memory.what.test' = 'Run Windows Memory Diagnostic for a deeper check (requires a restart).'
    'm6.memory.run' = 'Run Windows Memory Diagnostic'
    'm6.memory.confirm.title' = 'Run Windows Memory Diagnostic?'
    'm6.memory.confirm.msg' = 'WinCare will only OPEN the Windows tool — that tool asks you whether to restart NOW or on the next shutdown. WinCare never restarts the PC itself. Save your work first.'
    'm6.memory.opened' = 'Windows Memory Diagnostic opened.'
    'm6.memory.wheacount' = 'Memory-error events (WHEA, 30 days)'
    'm6.memory.diagresult' = 'Windows Memory Diagnostic (30 days)'
    'm6.memory.diag.err' = 'Memory hardware problem detected'
    'm6.memory.diag.ok' = 'No errors detected'
    'm6.memory.diag.none' = 'Not run within 30 days'
    'm6.fact.bat.ok' = 'Battery wear {0}% — within the normal range.'
    'm6.fact.bat.wear' = 'Battery wear is {0}% (full charge {1}/{2} mWh vs design).'
    'm6.fact.bat.absent' = 'This PC has no battery — the group is removed from the score formula.'
    'm6.fact.bat.nodata' = 'Battery data unreadable (no battery or read failed) — group removed.'
    'm6.fact.bat.nowear' = 'Wear could not be computed (missing design capacity) — group removed.'
    'm6.battery.what.ok' = 'Nothing to do.'
    'm6.battery.what.wear' = 'Avoid full 0% discharges if you need long runtime; replace the battery if wear is heavy.'
    'm6.battery.design' = 'Design capacity'
    'm6.battery.full' = 'Current full charge'
    'm6.battery.wear' = 'Wear'
    'm6.repair.title' = 'Advanced — Repair system files'
    'm6.repair.subtitle' = 'Only use when a check found problems. Requires confirmation, tries a restore point first, shows time estimates. Not auto-undoable.'
    'm6.repair.dism' = 'Repair component store (DISM RestoreHealth)'
    'm6.repair.dism.eta' = 'Estimated 10-30 minutes, may need network.'
    'm6.repair.sfc' = 'Repair system files (SFC /scannow)'
    'm6.repair.sfc.eta' = 'Estimated 5-15 minutes.'
    'm6.repair.confirm.title' = 'Confirm system repair'
    'm6.repair.confirm.msg.dism' = "Will run: DISM /Online /Cleanup-Image /RestoreHealth (estimated 10-30 minutes).`nBest to let it finish — cancelling mid-way may require starting over."
    'm6.repair.confirm.msg.sfc' = "Will run: sfc.exe /scannow (estimated 5-15 minutes).`nBest to let it finish — cancelling mid-way may require starting over."
    'm6.repair.noundo' = 'Replaced system files/component store CANNOT be auto-undone. WinCare will try to create a System Restore point before running.'
    'm6.repair.cp.running' = 'Trying to create a restore point…'
    'm6.repair.cp.fail' = 'Could not create a restore point: {0}'
    'm6.repair.cp.ask.title' = 'Continue without a restore point?'
    'm6.repair.cp.ask.msg' = 'System Restore may be disabled on this PC. If you continue, the repair will have NO restore point to roll back to.'
    'm6.repair.running' = 'Repairing system files'
    'm6.repair.done.ok' = 'Repair finished (exit code 0). Press "Rescan" to refresh the score.'
    'm6.repair.done.unknown' = 'Finished but inconclusive (exit code {0}) — see the log for details.'
    'm6.repair.cancelled' = 'Cancelled — you may need to start over next time.'
    'm6.repair.journal.dism' = 'Repair component store (DISM RestoreHealth)'
    'm6.repair.journal.sfc' = 'Repair system files (SFC /scannow)'
}

# ---------------------------------------------------------------------------
# LOP DU LIEU (query qua Invoke-WCQuery - key 'health.*' de FIXTURE thay the)
# ---------------------------------------------------------------------------
function Get-WCM6Field {
    # Doc truong an toan tu hashtable hoac PSCustomObject (unit test truyen duoc ca 2)
    param($Obj, [Parameter(Mandatory)][string]$Name)
    if ($null -eq $Obj) { return $null }
    try {
        if ($Obj -is [System.Collections.IDictionary]) {
            if ($Obj.Contains($Name)) { return $Obj[$Name] }
            return $null
        }
    } catch { }
    return (Get-WCProp $Obj $Name)
}

function Get-WCM6GroupKeys {
    # Thu tu hien thi cac nhom (cung la thu tu trong bang phan ra)
    return @('Storage', 'Stability', 'Integrity', 'Security', 'Memory', 'Battery')
}

function Get-WCM6GroupLabel {
    param([Parameter(Mandatory)][string]$Key)
    $map = @{ Storage = 'storage'; Stability = 'stability'; Integrity = 'integrity'; Security = 'security'; Memory = 'memory'; Battery = 'battery' }
    $k = $map[$Key]
    if (-not $k) { return $Key }
    return (T ('m6.group.' + $k))
}

function Get-WCM6PhysicalDisksData {
    # Get-PhysicalDisk: HealthStatus/OperationalStatus (SMART tinh o query rieng)
    param([bool]$NoCache = $false)
    $r = Invoke-WCQuery -Key 'health.physicaldisks' -CacheTtlSec 300 -NoCache:$NoCache -Script {
        $o = @{ Ok = $false; Disks = @() }
        try {
            $disks = @(Get-PhysicalDisk -ErrorAction Stop)
            $o['Ok'] = $true
            foreach ($d in $disks) {
                $o['Disks'] += [PSCustomObject]@{
                    DeviceId = [string](Get-WCProp $d 'DeviceId')
                    Name     = [string](Get-WCProp $d 'FriendlyName')
                    Media    = [string](Get-WCProp $d 'MediaType')
                    Health   = [string](Get-WCProp $d 'HealthStatus')
                    OpStatus = [string](Get-WCProp $d 'OperationalStatus')
                }
            }
        } catch { }
        return [PSCustomObject]$o
    }
    if ($r.Status -eq 'Ok') { return $r.Data }
    return $null
}

function Get-WCM6ReliabilityData {
    # Get-StorageReliabilityCounter cho tung dia: nhiet do, hao mon, gio bat, loi doc/ghi
    param([bool]$NoCache = $false)
    $r = Invoke-WCQuery -Key 'health.reliability' -CacheTtlSec 300 -NoCache:$NoCache -Script {
        $o = @{ Ok = $false; Counters = @() }
        try {
            $disks = @(Get-PhysicalDisk -ErrorAction Stop)
            $o['Ok'] = $true
            foreach ($d in $disks) {
                $rec = @{
                    DeviceId = [string](Get-WCProp $d 'DeviceId')
                    Temp = $null; Wear = $null; Hours = $null
                    ReadErrors = $null; ReadUncorr = $null; WriteErrors = $null
                }
                try {
                    $c = $d | Get-StorageReliabilityCounter -ErrorAction Stop
                    if ($c) {
                        $rec['Temp']        = (Get-WCProp $c 'Temperature')
                        $rec['Wear']        = (Get-WCProp $c 'Wear')
                        $rec['Hours']       = (Get-WCProp $c 'PowerOnHours')
                        $rec['ReadErrors']  = (Get-WCProp $c 'ReadErrorsTotal')
                        $rec['ReadUncorr']  = (Get-WCProp $c 'ReadErrorsUncorrected')
                        $rec['WriteErrors'] = (Get-WCProp $c 'WriteErrorsTotal')
                    }
                } catch { }
                $o['Counters'] += [PSCustomObject]$rec
            }
        } catch { }
        return [PSCustomObject]$o
    }
    if ($r.Status -eq 'Ok') { return $r.Data }
    return $null
}

function Get-WCM6VolumesData {
    # Win32_LogicalDisk (DriveType=3): dung luong tung volume
    param([bool]$NoCache = $false)
    $r = Invoke-WCQuery -Key 'health.volumes' -CacheTtlSec 300 -NoCache:$NoCache -Script {
        $o = @{ Ok = $false; Volumes = @() }
        try {
            $vols = @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3' -Property DeviceID,Size,FreeSpace -OperationTimeoutSec 10 -ErrorAction Stop)
            $o['Ok'] = $true
            foreach ($v in $vols) {
                $size = Get-WCProp $v 'Size'
                $free = Get-WCProp $v 'FreeSpace'
                if (($null -eq $size) -or ([double]$size -le 0)) { continue }
                $pct = [math]::Round(([double]$free / [double]$size) * 100, 1)
                $o['Volumes'] += [PSCustomObject]@{
                    Letter  = [string](Get-WCProp $v 'DeviceID')
                    Size    = [double]$size
                    Free    = [double]$free
                    PctFree = $pct
                }
            }
        } catch { }
        return [PSCustomObject]$o
    }
    if ($r.Status -eq 'Ok') { return $r.Data }
    return $null
}

function Get-WCM6EventsData {
    # Nhat ky System + Application 30 ngay, LOC THEO ProviderName + Id (khong phu
    # thuoc ngon ngu). Log bi tat/loi -> coi nhu khong du du lieu, khong doan.
    param([bool]$NoCache = $false)
    $r = Invoke-WCQuery -Key 'health.events' -CacheTtlSec 300 -NoCache:$NoCache -Script {
        $start = (Get-Date).AddDays(-30)
        $cats = @{
            kpower41 = 0; whea = 0; bugcheck = 0; diskerr = 0; tdr = 0; svc = 0
            appcrash = 0; wheamem = 0; memdiagerr = 0; memdiagok = 0
        }
        $bugcodes = @{}
        $specs = @(
            @{ Log = 'System'; Providers = @(
                'Microsoft-Windows-Kernel-Power', 'Microsoft-Windows-WHEA-Logger',
                'Microsoft-Windows-WER-SystemErrorReporting', 'disk', 'Ntfs',
                'Microsoft-Windows-Ntfs', 'Display', 'Microsoft-Windows-Display',
                'Service Control Manager') },
            @{ Log = 'Application'; Providers = @(
                'Application Error', 'Application Hang', 'Microsoft-Windows-MemoryDiagnostics-Results') }
        )
        $sysOk = $false
        $appOk = $false
        foreach ($spec in $specs) {
            $events = @()
            $readable = $false
            try {
                $events = @(Get-WinEvent -FilterHashtable @{ LogName = $spec['Log']; ProviderName = $spec['Providers']; StartTime = $start } -ErrorAction Stop)
                $readable = $true
            } catch {
                # FullyQualifiedErrorId khong bi dia phuong hoa: phan biet "khong co
                # su kiện nao" (may on dinh - tot) voi "log loi/bi tat" (thieu du lieu)
                if ($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound*') {
                    $readable = $true
                } else {
                    # Mot so provider co the khong ton tai tren may nay -> thu lai
                    # khong loc provider (van loc theo thoi gian), sau do loc bang tay
                    try {
                        $events = @(Get-WinEvent -FilterHashtable @{ LogName = $spec['Log']; StartTime = $start } -ErrorAction Stop)
                        $readable = $true
                    } catch {
                        if ($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound*') { $readable = $true }
                    }
                }
            }
            if ($spec['Log'] -eq 'System') { $sysOk = $readable } else { $appOk = $readable }
            if (-not $readable) { continue }
            foreach ($e in @($events)) {
                $prov = [string](Get-WCProp $e 'ProviderName')
                $idObj = Get-WCProp $e 'Id'
                if ($null -eq $idObj) { continue }
                $id = [int]$idObj
                if (($prov -eq 'Microsoft-Windows-Kernel-Power') -and ($id -eq 41)) { $cats['kpower41']++ }
                elseif ($prov -like '*WHEA-Logger*') {
                    $cats['whea']++
                    if (($id -eq 18) -or ($id -eq 19) -or ($id -eq 20) -or ($id -eq 46) -or ($id -eq 47)) { $cats['wheamem']++ }
                }
                elseif (($prov -like '*WER-SystemErrorReporting*') -and ($id -eq 1001)) {
                    $cats['bugcheck']++
                    try {
                        $props = $e.Properties
                        if ($props -and ($props.Count -gt 0)) {
                            $code = [string]$props[0].Value
                            if ($code) { $bugcodes[$code.Trim()] = $true }
                        }
                    } catch { }
                }
                elseif ((($prov -eq 'disk') -and (($id -eq 7) -or ($id -eq 11) -or ($id -eq 51) -or ($id -eq 153))) -or
                        (($prov -like '*Ntfs*') -and ($id -eq 55))) { $cats['diskerr']++ }
                elseif ((($prov -eq 'Display') -or ($prov -like '*-Display')) -and ($id -eq 4101)) { $cats['tdr']++ }
                elseif (($prov -eq 'Service Control Manager') -and (($id -eq 7031) -or ($id -eq 7034))) { $cats['svc']++ }
                elseif (($prov -eq 'Application Error') -and ($id -eq 1000)) { $cats['appcrash']++ }
                elseif (($prov -eq 'Application Hang') -and ($id -eq 1002)) { $cats['appcrash']++ }
                elseif (($prov -like '*MemoryDiagnostics-Results*') -and ($id -eq 1101)) { $cats['memdiagerr']++ }
                elseif (($prov -like '*MemoryDiagnostics-Results*') -and ($id -eq 1102)) { $cats['memdiagok']++ }
            }
        }
        $codeList = @($bugcodes.Keys | Sort-Object)
        if ($codeList.Count -gt 3) { $codeList = @($codeList[0], $codeList[1], $codeList[2]) }
        return [PSCustomObject]@{
            Ok = ($sysOk -or $appOk)
            SystemOk = $sysOk
            AppOk = $appOk
            Cats = $cats
            BugCodes = $codeList
        }
    }
    if ($r.Status -eq 'Ok') { return $r.Data }
    return $null
}

function Get-WCM6DismCheckData {
    # DISM /CheckHealth (nhanh) - chi lay ExitCode, KHONG parse stdout
    param([bool]$NoCache = $false)
    $r = Invoke-WCQuery -Key 'health.dism' -CacheTtlSec 600 -NoCache:$NoCache -Script {
        try {
            $p = Start-Process -FilePath 'dism.exe' -ArgumentList '/Online', '/Cleanup-Image', '/CheckHealth' -WindowStyle Hidden -Wait -PassThru -ErrorAction Stop
            return [PSCustomObject]@{ Ok = $true; ExitCode = $p.ExitCode }
        } catch {
            return [PSCustomObject]@{ Ok = $false; ExitCode = $null }
        }
    }
    if ($r.Status -eq 'Ok') { return $r.Data }
    return $null
}

function Get-WCM6SfcVerifyData {
    # SFC /verifyonly (CHI KIEM TRA, khong sua) - chi lay ExitCode.
    # ExitCode 0 = khong phat hien loi; khac 0 = co loi HOAC khong ket luan duoc.
    param([bool]$NoCache = $false)
    $r = Invoke-WCQuery -Key 'health.sfc' -CacheTtlSec 600 -NoCache:$NoCache -Script {
        try {
            $p = Start-Process -FilePath 'sfc.exe' -ArgumentList '/verifyonly' -WindowStyle Hidden -Wait -PassThru -ErrorAction Stop
            return [PSCustomObject]@{ Ok = $true; ExitCode = $p.ExitCode }
        } catch {
            return [PSCustomObject]@{ Ok = $false; ExitCode = $null }
        }
    }
    if ($r.Status -eq 'Ok') { return $r.Data }
    return $null
}

function Get-WCM6BatteryData {
    # root\wmi BatteryStaticData / BatteryFullChargedCapacity -> do chai
    param([bool]$NoCache = $false)
    $r = Invoke-WCQuery -Key 'health.battery' -CacheTtlSec 300 -NoCache:$NoCache -Script {
        $o = @{ Ok = $false; HasBattery = $false; Batteries = @() }
        try {
            $statics = @(Get-CimInstance -Namespace 'root\wmi' -ClassName 'BatteryStaticData' -OperationTimeoutSec 10 -ErrorAction Stop)
            $fulls = @(Get-CimInstance -Namespace 'root\wmi' -ClassName 'BatteryFullChargedCapacity' -OperationTimeoutSec 10 -ErrorAction Stop)
            $o['Ok'] = $true
            if ($statics.Count -gt 0) {
                $o['HasBattery'] = $true
                foreach ($s in $statics) {
                    $design = Get-WCProp $s 'DesignedCapacity'
                    $inst = [string](Get-WCProp $s 'InstanceName')
                    $full = $null
                    foreach ($f in $fulls) {
                        if ([string](Get-WCProp $f 'InstanceName') -eq $inst) { $full = Get-WCProp $f 'FullChargedCapacity'; break }
                    }
                    if (($null -eq $full) -and ($fulls.Count -gt 0)) { $full = Get-WCProp $fulls[0] 'FullChargedCapacity' }
                    $wear = $null
                    if (($null -ne $design) -and ($null -ne $full) -and ([double]$design -gt 0)) {
                        $wear = [math]::Round(100 - (([double]$full / [double]$design) * 100), 1)
                    }
                    $o['Batteries'] += [PSCustomObject]@{
                        Design = [double]$design
                        Full   = [double]$full
                        Wear   = $wear
                    }
                }
            }
        } catch { }
        return [PSCustomObject]$o
    }
    if ($r.Status -eq 'Ok') { return $r.Data }
    return $null
}

function Get-WCM6MpData {
    # Dung lai nguon cua M5 (key 'sec.mpstatus' - Invoke-WCQuery co cache, khong
    # tao truy van trung). Chuan hoa thanh trang thai bao mat cho M6.
    param([bool]$NoCache = $false)
    $r = Invoke-WCQuery -Key 'health.mp' -CacheTtlSec 120 -NoCache:$NoCache -Script {
        # Goi dung key 'sec.mpstatus' nhu M5 (Invoke-WCM5SourceQuery) de DUNG CHUNG
        # cache: script + TTL giong het M5, khong tao ban cache lech mau du lieu.
        $st = $null
        try {
            $r2 = Invoke-WCQuery -Key 'sec.mpstatus' -CacheTtlSec 60 -NoCache:$NoCache -Script { Get-MpComputerStatus -ErrorAction Stop }
            if (($r2.Status -eq 'Ok') -and $r2.Data) { $st = $r2.Data }
        } catch { }
        $rt = $null; $sigAge = $null; $eng = ''; $tamper = $null
        $lastQuick = $null; $lastFull = $null; $avEnabled = $null; $running = ''
        if ($st) {
            $rt = Get-WCProp $st 'RealTimeProtectionEnabled'
            $sigAge = Get-WCProp $st 'AntivirusSignatureAge'
            $eng = [string](Get-WCProp $st 'AMEngineVersion')
            $tamper = Get-WCProp $st 'IsTamperProtected'
            $lastQuick = Get-WCProp $st 'QuickScanEndTime'
            $lastFull = Get-WCProp $st 'FullScanEndTime'
            $avEnabled = Get-WCProp $st 'AntivirusEnabled'
            $running = [string](Get-WCProp $st 'AMRunningMode')
        }
        # AV ben thu ba: chi xem ten trong SecurityCenter2, khong giai ma productState
        $thirdNames = @()
        $avsReadable = $false
        try {
            $avs = @(Get-CimInstance -Namespace 'root/SecurityCenter2' -ClassName 'AntiVirusProduct' -OperationTimeoutSec 8 -ErrorAction Stop)
            $avsReadable = $true
            foreach ($av in $avs) {
                $pn = [string](Get-WCProp $av 'displayName')
                if ($pn -and ($pn -notlike '*Defender*')) { $thirdNames += $pn }
            }
        } catch { }
        $mode = 'unknown'
        $avName = ''
        if ($st -and (($null -ne $rt) -or ($null -ne $avEnabled))) {
            $mode = 'defender'
            # Defender o che do passive + co AV thu ba -> khong cham diem thay ho
            $passive = (($running -eq 'Passive Mode') -or ($avEnabled -eq $false))
            if ($passive -and ($thirdNames.Count -gt 0)) {
                $mode = 'thirdparty'
                $avName = [string]::Join(', ', $thirdNames)
            }
        } elseif ($thirdNames.Count -gt 0) {
            $mode = 'thirdparty'
            $avName = [string]::Join(', ', $thirdNames)
        }
        return [PSCustomObject]@{
            Mode = $mode
            AvName = $avName
            RealTime = $rt
            SigAgeDays = $sigAge
            Engine = $eng
            Tamper = $tamper
            LastQuick = $lastQuick
            LastFull = $lastFull
            ThirdParty = ($thirdNames.Count -gt 0)
        }
    }
    if ($r.Status -eq 'Ok') { return $r.Data }
    return $null
}

# ---------------------------------------------------------------------------
# HAM THUAN (unit test duoc): gop du lieu + cham diem tung nhom + cong thuc tong
# KHONG goi T, KHONG dung UI, KHONG truy van he thong.
# ---------------------------------------------------------------------------
function Merge-WCHealthStorage {
    # Gop 3 nguon (physicaldisks / reliability / volumes) thanh 1 du lieu chuan
    param($DisksResult, $ReliabilityResult, $VolumesResult)
    $out = @{ DisksOk = $false; VolumesOk = $false; Disks = @(); Volumes = @() }
    $rawDisks = @()
    if ($DisksResult) {
        $out['DisksOk'] = [bool](Get-WCM6Field $DisksResult 'Ok')
        $dd = Get-WCM6Field $DisksResult 'Disks'
        if ($null -ne $dd) { $rawDisks = @($dd) }
    }
    $counters = @()
    if ($ReliabilityResult) {
        $cc = Get-WCM6Field $ReliabilityResult 'Counters'
        if ($null -ne $cc) { $counters = @($cc) }
    }
    $i = 0
    foreach ($d in $rawDisks) {
        $devId = [string](Get-WCM6Field $d 'DeviceId')
        $ctr = $null
        foreach ($c in $counters) {
            if ([string](Get-WCM6Field $c 'DeviceId') -eq $devId) { $ctr = $c; break }
        }
        if ($null -eq $ctr) {
            # DeviceId khong khop (mot so o USB/RAID) -> gan theo thu tu, phong thu
            if ($counters.Count -eq 1) { $ctr = $counters[0] }
            elseif ($i -lt $counters.Count) { $ctr = $counters[$i] }
        }
        $rec = @{
            DeviceId = $devId
            Name = [string](Get-WCM6Field $d 'Name')
            Media = [string](Get-WCM6Field $d 'Media')
            Health = [string](Get-WCM6Field $d 'Health')
            OpStatus = [string](Get-WCM6Field $d 'OpStatus')
            Temp = $null; Wear = $null; Hours = $null
            ReadErrors = $null; ReadUncorr = $null; WriteErrors = $null
        }
        if ($ctr) {
            $rec['Temp'] = Get-WCM6Field $ctr 'Temp'
            $rec['Wear'] = Get-WCM6Field $ctr 'Wear'
            $rec['Hours'] = Get-WCM6Field $ctr 'Hours'
            $rec['ReadErrors'] = Get-WCM6Field $ctr 'ReadErrors'
            $rec['ReadUncorr'] = Get-WCM6Field $ctr 'ReadUncorr'
            $rec['WriteErrors'] = Get-WCM6Field $ctr 'WriteErrors'
        }
        $out['Disks'] += $rec
        $i++
    }
    if ($VolumesResult) {
        $out['VolumesOk'] = [bool](Get-WCM6Field $VolumesResult 'Ok')
        $vv = Get-WCM6Field $VolumesResult 'Volumes'
        if ($null -ne $vv) { $out['Volumes'] = @($vv) }
    }
    return $out
}

function Get-WCHealthStorageVerdict {
    # Diem Luu tru (trong so 25). Gia dinh nguong (ghi ro trong bao cao):
    #   Warning -20, Unhealthy -55 + SEVERE; OpStatus khac OK -8; nhiet do 60-69 -7,
    #   >=70 -15 (chi ap dung khi 0<T<100 de tranh nham don vi); Wear 21-50 -10,
    #   >50 -20; loi doc uncorrected>0 hoac total>=10000 -25, 1000-9999 -15;
    #   volume <5% -25, o he thong <10% -12 (tong volume toi da -30).
    param($Data)
    $facts = @()
    $disksOk = $false; $volumesOk = $false
    $disks = @(); $volumes = @()
    if ($Data) {
        $disksOk = [bool](Get-WCM6Field $Data 'DisksOk')
        $volumesOk = [bool](Get-WCM6Field $Data 'VolumesOk')
        $d = Get-WCM6Field $Data 'Disks'
        if ($null -ne $d) { $disks = @($d) }
        $v = Get-WCM6Field $Data 'Volumes'
        if ($null -ne $v) { $volumes = @($v) }
    }
    if (-not ($disksOk -or $volumesOk)) {
        return @{ Status = 'Unknown'; Score = $null; Severe = $false; Facts = @(@{ Key = 'storage.nodata' }); WhatKey = '' }
    }
    $score = 100.0
    $severe = $false
    if ($disksOk -and ($disks.Count -eq 0)) { $facts += @{ Key = 'storage.diskna' } }
    if (-not $disksOk) { $facts += @{ Key = 'storage.diskna' } }
    $anyCounter = $false
    foreach ($disk in $disks) {
        $name = [string](Get-WCM6Field $disk 'Name')
        if (-not $name) { $name = [string](Get-WCM6Field $disk 'DeviceId') }
        if (-not $name) { $name = '?' }
        $health = [string](Get-WCM6Field $disk 'Health')
        if ($health -eq 'Warning') {
            $score -= 20
            $facts += @{ Key = 'storage.diskwarn'; Args = @($name) }
        } elseif (($health -eq 'Unhealthy') -or ($health -eq 'Bad')) {
            $score -= 55
            $severe = $true
            $facts += @{ Key = 'storage.diskbad'; Args = @($name) }
        }
        $op = [string](Get-WCM6Field $disk 'OpStatus')
        if (($op -ne '') -and ($op -notlike '*OK*')) {
            $score -= 8
            $facts += @{ Key = 'storage.opstat'; Args = @($name, $op) }
        }
        $temp = Get-WCM6Field $disk 'Temp'
        if (($null -ne $temp) -and ([double]$temp -gt 0) -and ([double]$temp -lt 100)) {
            $anyCounter = $true
            if ([double]$temp -ge 70) {
                $score -= 15
                $facts += @{ Key = 'storage.temp.hot'; Args = @($name, [string]$temp) }
            } elseif ([double]$temp -ge 60) {
                $score -= 7
                $facts += @{ Key = 'storage.temp.warn'; Args = @($name, [string]$temp) }
            }
        }
        $wear = Get-WCM6Field $disk 'Wear'
        if ($null -ne $wear) { $anyCounter = $true }
        if (($null -ne $wear) -and ([double]$wear -gt 20)) {
            if ([double]$wear -gt 50) { $score -= 20 } else { $score -= 10 }
            $facts += @{ Key = 'storage.wear'; Args = @($name, [string]$wear) }
        }
        $rt = Get-WCM6Field $disk 'ReadErrors'
        $ru = Get-WCM6Field $disk 'ReadUncorr'
        if (($null -ne $rt) -or ($null -ne $ru)) { $anyCounter = $true }
        $rtN = 0.0; if ($null -ne $rt) { $rtN = [double]$rt }
        $ruN = 0.0; if ($null -ne $ru) { $ruN = [double]$ru }
        $ded = 0.0
        if ($ruN -gt 0) { $ded = 25 }
        elseif ($rtN -ge 10000) { $ded = 25 }
        elseif ($rtN -ge 1000) { $ded = 15 }
        if ($ded -gt 0) {
            $score -= $ded
            $facts += @{ Key = 'storage.readerr'; Args = @($name, [string]$rtN, [string]$ruN) }
        }
    }
    if ($disksOk -and ($disks.Count -gt 0) -and (-not $anyCounter)) {
        $facts += @{ Key = 'storage.nosmart' }
    }
    $volDed = 0.0
    foreach ($vol in $volumes) {
        $letter = [string](Get-WCM6Field $vol 'Letter')
        $pct = Get-WCM6Field $vol 'PctFree'
        if ($null -eq $pct) { continue }
        $p = [double]$pct
        $ded = 0.0
        if ($p -lt 5) { $ded = 25 }
        elseif (($p -lt 10) -and ($letter -eq $env:SystemDrive)) { $ded = 12 }
        if ($ded -gt 0) {
            $volDed += $ded
            $facts += @{ Key = 'storage.lowfree'; Args = @($letter, [string]$p) }
        }
    }
    if ($volDed -gt 30) { $volDed = 30 }
    $score -= $volDed
    if ($score -lt 0) { $score = 0 }
    $score = [int][math]::Round($score)
    $status = 'Warn'
    if ($score -ge 85) { $status = 'Ok' }
    if ($score -lt 60) { $status = 'Bad' }
    if ($facts.Count -eq 0) { $facts += @{ Key = 'storage.ok'; Args = @([string]$disks.Count) } }
    $whatKey = 'm6.storage.what.warn'
    if ($status -eq 'Ok') { $whatKey = 'm6.storage.what.ok' }
    if ($status -eq 'Bad') { $whatKey = 'm6.storage.what.bad' }
    return @{ Status = $status; Score = $score; Severe = $severe; Facts = $facts; WhatKey = $whatKey }
}

function Get-WCHealthStabilityVerdict {
    # Diem On dinh 30 ngay (trong so 25). Gia dinh nguong theo tan suat:
    #   kpower41: 1 lan -8 / 2 lan -16 / >=3 -24; whea: -10/-20/-30;
    #   bugcheck: -20/-35/-50; diskerr: 1-3 -12 / 4-9 -25 / >=10 -45 + SEVERE;
    #   tdr: -6/-12/-20; svc: -5/-12/-20; appcrash: -3/-8/-12.
    param($Data)
    $facts = @()
    $sysOk = $false; $appOk = $false
    $cats = $null
    $bugcodes = @()
    if ($Data) {
        $sysOk = [bool](Get-WCM6Field $Data 'SystemOk')
        $appOk = [bool](Get-WCM6Field $Data 'AppOk')
        $cats = Get-WCM6Field $Data 'Cats'
        $bc = Get-WCM6Field $Data 'BugCodes'
        if ($null -ne $bc) { $bugcodes = @($bc) }
    }
    if (-not $sysOk) {
        return @{ Status = 'Unknown'; Score = $null; Severe = $false; Facts = @(@{ Key = 'stab.nodata' }); WhatKey = '' }
    }
    $c = @{ kpower41 = 0; whea = 0; bugcheck = 0; diskerr = 0; tdr = 0; svc = 0; appcrash = 0 }
    if ($cats) {
        foreach ($k in @($c.Keys)) {
            $v = Get-WCM6Field $cats $k
            if ($null -ne $v) { $c[$k] = [int]$v }
        }
    }
    $score = 100.0
    $severe = $false
    if ($c['kpower41'] -ge 3) { $score -= 24 }
    elseif ($c['kpower41'] -eq 2) { $score -= 16 }
    elseif ($c['kpower41'] -eq 1) { $score -= 8 }
    if ($c['kpower41'] -gt 0) { $facts += @{ Key = 'stab.kpower41'; Args = @([string]$c['kpower41']) } }
    if ($c['whea'] -ge 3) { $score -= 30 }
    elseif ($c['whea'] -eq 2) { $score -= 20 }
    elseif ($c['whea'] -eq 1) { $score -= 10 }
    if ($c['whea'] -gt 0) { $facts += @{ Key = 'stab.whea'; Args = @([string]$c['whea']) } }
    if ($c['bugcheck'] -gt 0) {
        if ($c['bugcheck'] -ge 3) { $score -= 50 }
        elseif ($c['bugcheck'] -eq 2) { $score -= 35 }
        else { $score -= 20 }
        $facts += @{ Key = 'stab.bugcheck'; Args = @([string]$c['bugcheck'], [string]::Join(', ', $bugcodes)) }
    }
    if ($c['diskerr'] -ge 10) {
        $score -= 45
        $severe = $true
    } elseif ($c['diskerr'] -ge 4) {
        $score -= 25
    } elseif ($c['diskerr'] -ge 1) {
        $score -= 12
    }
    if ($c['diskerr'] -gt 0) { $facts += @{ Key = 'stab.diskerr'; Args = @([string]$c['diskerr']) } }
    if ($c['tdr'] -ge 10) { $score -= 20 }
    elseif ($c['tdr'] -ge 4) { $score -= 12 }
    elseif ($c['tdr'] -ge 1) { $score -= 6 }
    if ($c['tdr'] -gt 0) { $facts += @{ Key = 'stab.tdr'; Args = @([string]$c['tdr']) } }
    if ($c['svc'] -ge 20) { $score -= 20 }
    elseif ($c['svc'] -ge 6) { $score -= 12 }
    elseif ($c['svc'] -ge 1) { $score -= 5 }
    if ($c['svc'] -gt 0) { $facts += @{ Key = 'stab.svc'; Args = @([string]$c['svc']) } }
    if ($c['appcrash'] -ge 30) { $score -= 12 }
    elseif ($c['appcrash'] -ge 10) { $score -= 8 }
    elseif ($c['appcrash'] -ge 1) { $score -= 3 }
    if ($c['appcrash'] -gt 0) { $facts += @{ Key = 'stab.appcrash'; Args = @([string]$c['appcrash']) } }
    if (-not $appOk) { $facts += @{ Key = 'stab.applog' } }
    if ($score -lt 0) { $score = 0 }
    $score = [int][math]::Round($score)
    $status = 'Warn'
    if ($score -ge 85) { $status = 'Ok' }
    if ($score -lt 60) { $status = 'Bad' }
    if ($facts.Count -eq 0) { $facts += @{ Key = 'stab.ok' } }
    $whatKey = 'm6.stability.what.warn'
    if ($status -eq 'Ok') { $whatKey = 'm6.stability.what.ok' }
    return @{ Status = $status; Score = $score; Severe = $severe; Facts = $facts; WhatKey = $whatKey }
}

function Get-WCHealthIntegrityVerdict {
    # Diem Toan ven (trong so 15). Chi dua tren ExitCode, khong parse output:
    #   ca hai sach (exit 0) = 100; mot sach + mot khong chay duoc = 70;
    #   mot sach + mot khong ket luan (exit != 0) = 60; con lai = 50;
    #   ca hai khong chay duoc -> Unknown (bo khoi mau so).
    param($Dism, $Sfc)
    $dOk = $false; $dCode = $null
    if ($Dism) {
        $dOk = [bool](Get-WCM6Field $Dism 'Ok')
        $dCode = Get-WCM6Field $Dism 'ExitCode'
    }
    $sOk = $false; $sCode = $null
    if ($Sfc) {
        $sOk = [bool](Get-WCM6Field $Sfc 'Ok')
        $sCode = Get-WCM6Field $Sfc 'ExitCode'
    }
    $dClean = ($dOk -and ($dCode -eq 0))
    $dIncon = ($dOk -and ($dCode -ne 0))
    $dNa = (-not $dOk)
    $sClean = ($sOk -and ($sCode -eq 0))
    $sIncon = ($sOk -and ($sCode -ne 0))
    $sNa = (-not $sOk)
    $facts = @()
    if ($dClean) { $facts += @{ Key = 'int.dism.ok' } }
    elseif ($dIncon) { $facts += @{ Key = 'int.dism.unknown'; Args = @([string]$dCode) } }
    else { $facts += @{ Key = 'int.dism.norun' } }
    if ($sClean) { $facts += @{ Key = 'int.sfc.ok' } }
    elseif ($sIncon) { $facts += @{ Key = 'int.sfc.unknown'; Args = @([string]$sCode) } }
    else { $facts += @{ Key = 'int.sfc.norun' } }
    if ($dNa -and $sNa) {
        return @{ Status = 'Unknown'; Score = $null; Severe = $false; Facts = $facts; WhatKey = '' }
    }
    $score = 50
    if ($dClean -and $sClean) { $score = 100 }
    elseif (($dClean -and $sIncon) -or ($dIncon -and $sClean)) { $score = 60 }
    elseif (($dClean -and $sNa) -or ($dNa -and $sClean)) { $score = 70 }
    $status = 'Warn'
    if ($score -ge 85) { $status = 'Ok' }
    $whatKey = 'm6.integrity.what.warn'
    if ($status -eq 'Ok') { $whatKey = 'm6.integrity.what.ok' }
    return @{ Status = $status; Score = $score; Severe = $false; Facts = $facts; WhatKey = $whatKey }
}

function Get-WCHealthSecurityVerdict {
    # Diem Bao mat (trong so 15): RTP bat + chu ky <=3 ngay = 100; 4-7 = 85;
    # 8-14 = 60; >14 = 40; RTP tat = 30; AV thu ba / khong doc duoc -> Unknown.
    param($Data)
    if (-not $Data) {
        return @{ Status = 'Unknown'; Score = $null; Severe = $false; Facts = @(@{ Key = 'sec.nodata' }); WhatKey = '' }
    }
    $mode = [string](Get-WCM6Field $Data 'Mode')
    if ($mode -eq 'thirdparty') {
        $av = [string](Get-WCM6Field $Data 'AvName')
        return @{ Status = 'Unknown'; Score = $null; Severe = $false; Facts = @(@{ Key = 'sec.third'; Args = @($av) }); WhatKey = '' }
    }
    if ($mode -ne 'defender') {
        return @{ Status = 'Unknown'; Score = $null; Severe = $false; Facts = @(@{ Key = 'sec.nodata' }); WhatKey = '' }
    }
    $rt = Get-WCM6Field $Data 'RealTime'
    $sig = Get-WCM6Field $Data 'SigAgeDays'
    $facts = @()
    $score = 70
    $status = 'Warn'
    $whatKey = 'm6.security.what.warn'
    if ($rt -eq $false) {
        $facts += @{ Key = 'sec.rtp.off' }
        $score = 30
        $status = 'Bad'
        $whatKey = 'm6.security.what.rtp'
    } elseif ($null -eq $rt) {
        $facts += @{ Key = 'sec.rtp.na' }
        $score = 70
        $status = 'Warn'
    } else {
        $facts += @{ Key = 'sec.rtp.on' }
        if ($null -eq $sig) {
            $facts += @{ Key = 'sec.sig.na' }
            $score = 80
            $status = 'Warn'
            $whatKey = 'm6.security.what.warn'
        } else {
            $s = [double]$sig
            if ($s -le 3) {
                $facts += @{ Key = 'sec.ok.sig'; Args = @([string]$s) }
                $score = 100
                $status = 'Ok'
                $whatKey = 'm6.security.what.ok'
            } elseif ($s -le 7) {
                $facts += @{ Key = 'sec.sigold'; Args = @([string]$s) }
                $score = 85
                $status = 'Ok'
                $whatKey = 'm6.security.what.sig'
            } elseif ($s -le 14) {
                $facts += @{ Key = 'sec.sigold'; Args = @([string]$s) }
                $score = 60
                $status = 'Warn'
                $whatKey = 'm6.security.what.sig'
            } else {
                $facts += @{ Key = 'sec.sigold'; Args = @([string]$s) }
                $score = 40
                $status = 'Warn'
                $whatKey = 'm6.security.what.sig'
            }
        }
    }
    return @{ Status = $status; Score = $score; Severe = $false; Facts = $facts; WhatKey = $whatKey }
}

function Get-WCHealthMemoryVerdict {
    # Diem Bo nho (trong so 10): khong loi = 100; 1-2 WHEA bo nho = 60;
    # >=3 WHEA bo nho = 25 + SEVERE; Memory Diagnostic phat hien loi = 20 + SEVERE.
    param($Data)
    if (-not $Data) {
        return @{ Status = 'Unknown'; Score = $null; Severe = $false; Facts = @(@{ Key = 'mem.nodata' }); WhatKey = '' }
    }
    $sysOk = [bool](Get-WCM6Field $Data 'SystemOk')
    if (-not $sysOk) {
        return @{ Status = 'Unknown'; Score = $null; Severe = $false; Facts = @(@{ Key = 'mem.nodata' }); WhatKey = '' }
    }
    $cats = Get-WCM6Field $Data 'Cats'
    $wheamem = 0; $diagErr = 0; $diagOk = 0
    if ($cats) {
        $v = Get-WCM6Field $cats 'wheamem'
        if ($null -ne $v) { $wheamem = [int]$v }
        $v = Get-WCM6Field $cats 'memdiagerr'
        if ($null -ne $v) { $diagErr = [int]$v }
        $v = Get-WCM6Field $cats 'memdiagok'
        if ($null -ne $v) { $diagOk = [int]$v }
    }
    $facts = @()
    $score = 100
    $status = 'Ok'
    $severe = $false
    if ($diagErr -gt 0) {
        $facts += @{ Key = 'mem.diag' }
        $score = 20
        $status = 'Bad'
        $severe = $true
    } elseif ($wheamem -ge 3) {
        $facts += @{ Key = 'mem.whea'; Args = @([string]$wheamem) }
        $score = 25
        $status = 'Bad'
        $severe = $true
    } elseif ($wheamem -ge 1) {
        $facts += @{ Key = 'mem.whea'; Args = @([string]$wheamem) }
        $score = 60
        $status = 'Warn'
    } else {
        $facts += @{ Key = 'mem.ok' }
        if ($diagOk -gt 0) { $facts += @{ Key = 'mem.diagok' } }
    }
    $whatKey = 'm6.memory.what.test'
    if ($status -eq 'Ok') { $whatKey = 'm6.memory.what.ok' }
    return @{ Status = $status; Score = $score; Severe = $severe; Facts = $facts; WhatKey = $whatKey }
}

function Get-WCHealthBatteryVerdict {
    # Diem Pin (trong so 10): chai <=10% = 100; 11-20% = 85; 21-35% = 65; >35% = 40.
    # Khong co pin / khong doc duoc / thieu dung luong thiet ke -> Unknown (bo).
    param($Data)
    if (-not $Data) {
        return @{ Status = 'Unknown'; Score = $null; Severe = $false; Facts = @(@{ Key = 'bat.nodata' }); WhatKey = '' }
    }
    $ok = [bool](Get-WCM6Field $Data 'Ok')
    if (-not $ok) {
        return @{ Status = 'Unknown'; Score = $null; Severe = $false; Facts = @(@{ Key = 'bat.nodata' }); WhatKey = '' }
    }
    $has = [bool](Get-WCM6Field $Data 'HasBattery')
    if (-not $has) {
        return @{ Status = 'Unknown'; Score = $null; Severe = $false; Facts = @(@{ Key = 'bat.absent' }); WhatKey = '' }
    }
    $batteries = @()
    $bb = Get-WCM6Field $Data 'Batteries'
    if ($null -ne $bb) { $batteries = @($bb) }
    $worst = $null; $worstFull = 0; $worstDesign = 0
    foreach ($b in $batteries) {
        $w = Get-WCM6Field $b 'Wear'
        if ($null -eq $w) { continue }
        if (($null -eq $worst) -or ([double]$w -gt [double]$worst)) {
            $worst = $w
            $worstFull = Get-WCM6Field $b 'Full'
            $worstDesign = Get-WCM6Field $b 'Design'
        }
    }
    if ($null -eq $worst) {
        return @{ Status = 'Unknown'; Score = $null; Severe = $false; Facts = @(@{ Key = 'bat.nowear' }); WhatKey = '' }
    }
    $score = 100
    if ([double]$worst -gt 35) { $score = 40 }
    elseif ([double]$worst -gt 20) { $score = 65 }
    elseif ([double]$worst -gt 10) { $score = 85 }
    $status = 'Warn'
    if ($score -ge 85) { $status = 'Ok' }
    if ($score -lt 60) { $status = 'Bad' }
    $factKey = 'bat.ok'
    $fargs = @([string]$worst)
    if ([double]$worst -gt 10) {
        $factKey = 'bat.wear'
        $fargs = @([string]$worst, [string]$worstFull, [string]$worstDesign)
    }
    $whatKey = 'm6.battery.what.ok'
    if ($status -ne 'Ok') { $whatKey = 'm6.battery.what.wear' }
    return @{ Status = $status; Score = $score; Severe = $false; Facts = @(@{ Key = $factKey; Args = $fargs }); WhatKey = $whatKey }
}

function Get-WCHealthScore {
    # HAM THUAN de unit test (spec M6): cong thuc diem tong.
    #   $Groups = @{ Storage = @{Status;Score;Severe;Reason}; ... }
    #   - Nhom thieu/null hoac Status 'Unknown' -> BO khoi mau so (chia lai trong so)
    #   - Tran: nhom nao do Severe=$true -> diem toi da 49 + CapReason
    #   - Khong nhom nao doc duoc -> Score = $null
    # Tra ve: @{ Score; Breakdown = @(@{Group;Weight;Score;Reason;Included;Severe});
    #           Capped; CapReason; TotalWeight; SkippedNames }
    param($Groups)
    $weights = @{ Storage = 25; Stability = 25; Integrity = 15; Security = 15; Memory = 10; Battery = 10 }
    $breakdown = @()
    $sum = 0.0
    $totalWeight = 0
    $severeReasons = @()
    $skipped = @()
    foreach ($name in @(Get-WCM6GroupKeys)) {
        $w = $weights[$name]
        $g = $null
        if ($Groups -is [System.Collections.IDictionary]) {
            if ($Groups.Contains($name)) { $g = $Groups[$name] }
        } elseif ($Groups) {
            $g = Get-WCProp $Groups $name
        }
        $score = $null
        $reason = ''
        $included = $false
        $isSevere = $false
        if ($null -ne $g) {
            $status = [string](Get-WCM6Field $g 'Status')
            $score = Get-WCM6Field $g 'Score'
            $reason = [string](Get-WCM6Field $g 'Reason')
            $isSevere = [bool](Get-WCM6Field $g 'Severe')
            if (($status -ne 'Unknown') -and ($null -ne $score)) {
                $included = $true
                $sum += ([double]$score * $w)
                $totalWeight += $w
                if ($isSevere) { $severeReasons += $reason }
            }
        }
        if (-not $included) {
            $skipped += $name
            $score = $null
        }
        $breakdown += @{
            Group = $name; Weight = $w; Score = $score; Reason = $reason
            Included = $included; Severe = $isSevere
        }
    }
    $final = $null
    $capped = $false
    $capReason = ''
    if ($totalWeight -gt 0) {
        $final = [int][math]::Round(($sum / $totalWeight), 0)
        if ($severeReasons.Count -gt 0) {
            $capped = $true
            $capReason = [string]::Join(' ', $severeReasons)
            if ($final -gt 49) { $final = 49 }
        }
    }
    return @{
        Score = $final
        Breakdown = $breakdown
        Capped = $capped
        CapReason = $capReason
        TotalWeight = $totalWeight
        SkippedNames = $skipped
    }
}

# ---------------------------------------------------------------------------
# TASK NEN - moi nhom 1 task rieng, ket qua ve dan (spec M6)
# ---------------------------------------------------------------------------
function Test-WCM6Busy {
    # Co tac vu nao cua M6 dang chay khong (chan chong len: DISM/SFC dung cung
    # kho servicing cua Windows, khong duoc chay song song)
    foreach ($id in @('m6.storage', 'm6.stability', 'm6.integrity', 'm6.security', 'm6.memory', 'm6.battery', 'm6.deepscan', 'm6.repair.dism', 'm6.repair.sfc')) {
        if (Test-WCTaskRunning $id) { return $true }
    }
    return $false
}

function Invoke-WCM6RunScan {
    # Khoi dong 6 task nen (moi nhom 1 task, ve dan). $NoCache = quen cache de quet moi.
    param($State, [bool]$NoCache)
    $State.Groups = @{}
    $State.GroupData = @{}
    if ($State.ScanLabel) {
        $State.ScanLabel.Text = (T 'm6.scan.at' @((Get-Date).ToString('g')))
    }
    foreach ($k in (Get-WCM6GroupKeys)) {
        Update-WCM6RowLoading $State $k
    }
    Update-WCM6Score $State
    Write-WCLog 'INFO' ('M6: bat dau quet (NoCache=' + $NoCache + ')')
    foreach ($k in (Get-WCM6GroupKeys)) {
        Invoke-WCM6StartGroup $State $k $NoCache
    }
}

function Invoke-WCM6Rescan {
    param($State)
    if (Test-WCM6Busy) {
        Show-WCToast (T 'm6.rescan.busy') 'Info'
        return
    }
    Invoke-WCM6RunScan $State $true
}

function Invoke-WCM6StartGroup {
    # Khoi dong task nen cho 1 nhom. Worker thuan (param $ctx/$s); Done chay lai
    # tren UI thread bang closure cua $State.
    param($State, [string]$Key, [bool]$NoCache)
    $lower = $Key.ToLower()
    $taskId = 'm6.' + $lower
    $title = (T ('m6.group.' + $lower))
    $worker = $null
    switch ($Key) {
        'Storage' {
            $worker = {
                param($ctx, $s)
                $nc = $false
                if ($s -and $s.ContainsKey('NoCache')) { $nc = [bool]$s['NoCache'] }
                $merged = Merge-WCHealthStorage (Get-WCM6PhysicalDisksData $nc) (Get-WCM6ReliabilityData $nc) (Get-WCM6VolumesData $nc)
                $verdict = Get-WCHealthStorageVerdict $merged
                return @{
                    Key = 'Storage'; Status = $verdict['Status']; Score = $verdict['Score']
                    Severe = $verdict['Severe']; Facts = $verdict['Facts']; WhatKey = $verdict['WhatKey']
                    Data = $merged
                }
            }
        }
        'Stability' {
            $worker = {
                param($ctx, $s)
                $nc = $false
                if ($s -and $s.ContainsKey('NoCache')) { $nc = [bool]$s['NoCache'] }
                $data = Get-WCM6EventsData $nc
                $verdict = Get-WCHealthStabilityVerdict $data
                return @{
                    Key = 'Stability'; Status = $verdict['Status']; Score = $verdict['Score']
                    Severe = $verdict['Severe']; Facts = $verdict['Facts']; WhatKey = $verdict['WhatKey']
                    Data = $data
                }
            }
        }
        'Integrity' {
            # Nhom cham nhat: DISM CheckHealth (giay) + SFC /verifyonly (co the may phut)
            $worker = {
                param($ctx, $s)
                $nc = $false
                if ($s -and $s.ContainsKey('NoCache')) { $nc = [bool]$s['NoCache'] }
                $cancelled = @{ Key = 'Integrity'; Status = 'Unknown'; Score = $null; Severe = $false; Facts = @(@{ Key = 'cancelled' }); WhatKey = ''; Data = $null }
                $ctx.Progress(10, (T 'm6.integrity.p.dism'))
                $dism = Get-WCM6DismCheckData $nc
                if ($ctx.Cancelled()) { return $cancelled }
                $ctx.Progress(35, (T 'm6.integrity.p.sfc'))
                $sfc = Get-WCM6SfcVerifyData $nc
                if ($ctx.Cancelled()) { return $cancelled }
                $verdict = Get-WCHealthIntegrityVerdict $dism $sfc
                return @{
                    Key = 'Integrity'; Status = $verdict['Status']; Score = $verdict['Score']
                    Severe = $verdict['Severe']; Facts = $verdict['Facts']; WhatKey = $verdict['WhatKey']
                    Data = @{ Dism = $dism; Sfc = $sfc }
                }
            }
        }
        'Security' {
            # Chi doc lai nguon 'sec.mpstatus' cua M5 qua cache - khong tao quet trung
            $worker = {
                param($ctx, $s)
                $nc = $false
                if ($s -and $s.ContainsKey('NoCache')) { $nc = [bool]$s['NoCache'] }
                $data = Get-WCM6MpData $nc
                $verdict = Get-WCHealthSecurityVerdict $data
                return @{
                    Key = 'Security'; Status = $verdict['Status']; Score = $verdict['Score']
                    Severe = $verdict['Severe']; Facts = $verdict['Facts']; WhatKey = $verdict['WhatKey']
                    Data = $data
                }
            }
        }
        'Memory' {
            $worker = {
                param($ctx, $s)
                $nc = $false
                if ($s -and $s.ContainsKey('NoCache')) { $nc = [bool]$s['NoCache'] }
                $data = Get-WCM6EventsData $nc
                $verdict = Get-WCHealthMemoryVerdict $data
                return @{
                    Key = 'Memory'; Status = $verdict['Status']; Score = $verdict['Score']
                    Severe = $verdict['Severe']; Facts = $verdict['Facts']; WhatKey = $verdict['WhatKey']
                    Data = $data
                }
            }
        }
        'Battery' {
            $worker = {
                param($ctx, $s)
                $nc = $false
                if ($s -and $s.ContainsKey('NoCache')) { $nc = [bool]$s['NoCache'] }
                $data = Get-WCM6BatteryData $nc
                $verdict = Get-WCHealthBatteryVerdict $data
                return @{
                    Key = 'Battery'; Status = $verdict['Status']; Score = $verdict['Score']
                    Severe = $verdict['Severe']; Facts = $verdict['Facts']; WhatKey = $verdict['WhatKey']
                    Data = $data
                }
            }
        }
    }
    if (-not $worker) { return $false }
    $done = {
        param($r)
        Invoke-WCM6ApplyGroupResult $State $r
    }.GetNewClosure()
    if ($Key -eq 'Integrity') {
        # Hien tien do that + nut Huy o thanh trang thai; dong "Tại sao" cap nhat
        # truc tieo theo tien do (SFC /verifyonly lau)
        $onMsg = {
            param($msg)
            try {
                if ($msg.Type -eq 'Progress') {
                    if ($State.Rows.ContainsKey('Integrity')) {
                        $State.Rows['Integrity'].WhyText.Text = $msg.Text
                    }
                }
            } catch { }
        }.GetNewClosure()
        return (Start-WCTask -Id $taskId -Title $title -Args @{ NoCache = $NoCache } -Worker $worker -Done $done -ShowStatus -OnMessage $onMsg)
    }
    return (Start-WCTask -Id $taskId -Title $title -Args @{ NoCache = $NoCache } -Worker $worker -Done $done)
}

function Invoke-WCM6ApplyGroupResult {
    # Nhan ket qua 1 nhom tu worker: ghp ly do (i18n tren UI thread), cap nhat
    # dong bang + diem tong.
    param($State, $Result)
    if ($null -eq $Result) { return }
    $key = [string](Get-WCM6Field $Result 'Key')
    if (-not $key) { return }
    $status = [string](Get-WCM6Field $Result 'Status')
    $score = Get-WCM6Field $Result 'Score'
    $severe = [bool](Get-WCM6Field $Result 'Severe')
    $whatKey = [string](Get-WCM6Field $Result 'WhatKey')
    $data = Get-WCM6Field $Result 'Data'
    $reason = ''
    $facts = Get-WCM6Field $Result 'Facts'
    if ($null -ne $facts) {
        $parts = @()
        foreach ($f in @($facts)) {
            $fk = [string](Get-WCM6Field $f 'Key')
            if (-not $fk) { continue }
            $fargs = Get-WCM6Field $f 'Args'
            if ($null -ne $fargs) {
                $parts += (T ('m6.fact.' + $fk) @($fargs))
            } else {
                $parts += (T ('m6.fact.' + $fk))
            }
        }
        $reason = [string]::Join(' ', $parts)
    }
    if ([string]::IsNullOrEmpty($reason)) { $reason = (T 'm6.why.nodata') }
    $State.Groups[$key] = @{ Status = $status; Score = $score; Severe = $severe; Reason = $reason }
    $State.GroupData[$key] = $data
    Update-WCM6GroupRow $State $key $status $score $reason $whatKey $data
    Update-WCM6Score $State
    Write-WCLog 'INFO' ('M6: nhom ' + $key + ' -> ' + $status + ' diem=' + $score)
}

# ---------------------------------------------------------------------------
# UI HELPERS
# ---------------------------------------------------------------------------
function Set-WCM6ChipStatus {
    # Doi mau + chu cua chip trang thai (chip mau luon kem chu - spec muc 1)
    param($Chip, [string]$Status, [string]$Text)
    $bgKey = 'WcUnknownBg'
    $fgKey = 'WcUnknown'
    if ($Status -eq 'Ok') { $bgKey = 'WcOkBg'; $fgKey = 'WcOk' }
    elseif ($Status -eq 'Warn') { $bgKey = 'WcWarnBg'; $fgKey = 'WcWarn' }
    elseif ($Status -eq 'Bad') { $bgKey = 'WcBadBg'; $fgKey = 'WcBad' }
    $Chip.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, $bgKey)
    if ($Chip.Tag -is [Windows.Controls.TextBlock]) {
        $Chip.Tag.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, $fgKey)
    }
    Set-WCChipText $Chip $Text
}

function Test-WCM6NavExists {
    # Chi hien nut "Xem chi tiet" khi module dich da dang ky nav
    param([Parameter(Mandatory)][string]$NavKey)
    foreach ($item in (Get-WCNavItemsSorted)) {
        if ($item.Key -eq $NavKey) { return $true }
    }
    return $false
}

function New-WCM6FiveColGrid {
    # Luoi 5 cot dung chung cho header + moi dong nhom:
    # Nhom | Trong so | Diem | Tai sao | Nen lam gi
    $g = New-Object Windows.Controls.Grid
    foreach ($w in @(200, 62, 56)) {
        $cd = New-Object Windows.Controls.ColumnDefinition
        $cd.Width = (New-Object Windows.GridLength([double]$w))
        $g.ColumnDefinitions.Add($cd) | Out-Null
    }
    $cdStar = New-Object Windows.Controls.ColumnDefinition
    $cdStar.Width = (New-Object Windows.GridLength(1, [Windows.GridUnitType]::Star))
    $g.ColumnDefinitions.Add($cdStar) | Out-Null
    $cdWhat = New-Object Windows.Controls.ColumnDefinition
    $cdWhat.Width = (New-Object Windows.GridLength(340))
    $g.ColumnDefinitions.Add($cdWhat) | Out-Null
    return $g
}

function New-WCM6GroupRow {
    # 1 dong nhom trong bang phan ra: card chua luoi 5 cot + expander chi tiet
    param($State, [string]$Key, [int]$Weight)
    $lower = $Key.ToLower()
    $card = New-Object Windows.Controls.Border
    $card.CornerRadius = (New-Object Windows.CornerRadius(8))
    $card.BorderThickness = (New-Object Windows.Thickness(1))
    $card.Padding = (New-Object Windows.Thickness(12))
    $card.Margin = (New-Object Windows.Thickness(0, 4, 0, 4))
    $card.SetResourceReference([Windows.Controls.Border]::BackgroundProperty, 'WcCardBg2')
    $card.SetResourceReference([Windows.Controls.Border]::BorderBrushProperty, 'WcBorder')
    $v = New-WCVStack -Spacing 6

    $grid = New-WCM6FiveColGrid
    # Cot 0: ten nhom + chip trang thai (chip co ToolTip giai thich)
    $left = New-WCVStack -Spacing 4
    $nameTb = New-WCTextBlock -Text (T ('m6.group.' + $lower)) -Size 13.5 -Weight 'SemiBold' -Wrap
    Add-WCChild $left $nameTb
    $chip = New-WCChip -Text (T 'm6.status.scanning') -Kind 'Unknown'
    $chip.ToolTip = (T ('m6.group.' + $lower + '.tip'))
    $chip.HorizontalAlignment = [Windows.HorizontalAlignment]::Left
    Add-WCChild $left $chip
    [Windows.Controls.Grid]::SetColumn($left, 0)
    $grid.Children.Add($left) | Out-Null
    # Cot 1: trong so
    $weightTb = New-WCTextBlock -Text ('{0}%' -f $Weight) -Size 12.5 -ColorKey 'WcSubtle'
    $weightTb.VerticalAlignment = [Windows.VerticalAlignment]::Center
    [Windows.Controls.Grid]::SetColumn($weightTb, 1)
    $grid.Children.Add($weightTb) | Out-Null
    # Cot 2: diem
    $scoreTb = New-WCTextBlock -Text '…' -Size 16 -Weight 'SemiBold'
    $scoreTb.VerticalAlignment = [Windows.VerticalAlignment]::Center
    [Windows.Controls.Grid]::SetColumn($scoreTb, 2)
    $grid.Children.Add($scoreTb) | Out-Null
    # Cot 3: tai sao
    $whyTb = New-WCTextBlock -Text (T 'common.loading') -Size 12.5 -Wrap
    $whyTb.VerticalAlignment = [Windows.VerticalAlignment]::Center
    [Windows.Controls.Grid]::SetColumn($whyTb, 3)
    $grid.Children.Add($whyTb) | Out-Null
    # Cot 4: nen lam gi + nut hanh dong
    $whatCol = New-WCVStack -Spacing 4
    $whatTb = New-WCTextBlock -Text '' -Size 12 -ColorKey 'WcSubtle' -Wrap
    Add-WCChild $whatCol $whatTb
    $btnHost = New-WCHStack -Spacing 6
    Add-WCChild $whatCol $btnHost
    [Windows.Controls.Grid]::SetColumn($whatCol, 4)
    $grid.Children.Add($whatCol) | Out-Null

    Add-WCChild $v $grid
    # Expander chi tiet (bang dia/su kien/ma thoat...) - nap khi co ket qua
    $exp = New-WCExpander -Title (T 'm6.detail')
    Add-WCChild $v $exp.Root

    $card.Child = $v
    $row = @{
        Key = $Key; Card = $card; Chip = $chip
        ScoreText = $scoreTb; WhyText = $whyTb; WhatText = $whatTb
        BtnHost = $btnHost; DetailHost = $exp.Body
    }
    $State.Rows[$Key] = $row
    return $row
}

function Update-WCM6RowLoading {
    # Dat lai 1 dong ve trang thai "dang quet"
    param($State, [string]$Key)
    $row = $State.Rows[$Key]
    if (-not $row) { return }
    Set-WCM6ChipStatus $row.Chip 'Unknown' (T 'm6.status.scanning')
    $row.ScoreText.Text = '…'
    $row.WhyText.Text = (T 'common.loading')
    $row.WhatText.Text = ''
    $row.BtnHost.Children.Clear()
    $row.DetailHost.Children.Clear()
}

function Update-WCM6GroupRow {
    # Cap nhat 1 dong nhom sau khi co ket qua + nap lai nut hanh dong/chi tiet
    param($State, [string]$Key, [string]$Status, $Score, [string]$Reason, [string]$WhatKey, $Data)
    $row = $State.Rows[$Key]
    if (-not $row) { return }
    if ($Status -eq 'Unknown') {
        Set-WCM6ChipStatus $row.Chip 'Unknown' (T 'm6.skipped')
        $row.ScoreText.Text = '—'
    } else {
        $chipText = (T ('common.status.' + $Status.ToLower()))
        Set-WCM6ChipStatus $row.Chip $Status $chipText
        $row.ScoreText.Text = [string]$Score
    }
    $row.WhyText.Text = $Reason
    if ($WhatKey) {
        $row.WhatText.Text = (T $WhatKey)
    } else {
        $row.WhatText.Text = ''
    }
    # Nut hanh dong: "Xem chi tiet" chuyen nav sang module lien quan
    $row.BtnHost.Children.Clear()
    $navMap = @{ Storage = 'm2'; Stability = 'm3'; Integrity = ''; Security = 'm5'; Memory = 'm1'; Battery = 'm4' }
    $navKey = $navMap[$Key]
    if ($navKey -and (Test-WCM6NavExists $navKey)) {
        $navBtn = New-WCButton -Text (T 'm6.action.detail') -Small -OnClick {
            param($b)
            Invoke-WCShowNav $navKey
        }.GetNewClosure()
        $row.BtnHost.Children.Add($navBtn) | Out-Null
    }
    if ($Key -eq 'Memory') {
        $memBtn = New-WCButton -Text (T 'm6.memory.run') -Small -OnClick {
            param($b)
            Invoke-WCM6RunMemoryDiagnostic
        }.GetNewClosure()
        $row.BtnHost.Children.Add($memBtn) | Out-Null
    }
    if ($Key -eq 'Integrity') {
        $deepBtn = New-WCButton -Text (T 'm6.integrity.deep') -Small -OnClick {
            param($b)
            Invoke-WCM6DeepScan $State
        }.GetNewClosure()
        $row.BtnHost.Children.Add($deepBtn) | Out-Null
    }
    # Chi tiet tung nhom
    $row.DetailHost.Children.Clear()
    try {
        switch ($Key) {
            'Storage' { Update-WCM6StorageDetail $row.DetailHost $Data }
            'Stability' { Update-WCM6StabilityDetail $row.DetailHost $Data }
            'Integrity' { Update-WCM6IntegrityDetail $row.DetailHost $Data $State.DeepResult }
            'Security' { Update-WCM6SecurityDetail $row.DetailHost $Data }
            'Memory' { Update-WCM6MemoryDetail $row.DetailHost $Data }
            'Battery' { Update-WCM6BatteryDetail $row.DetailHost $Data }
        }
    } catch {
        Write-WCLog 'WARN' ('M6 chi tiet ' + $Key + ' loi: ' + $_.Exception.Message)
    }
}

function Update-WCM6Score {
    # Tinh lai diem tong tu cac nhom da ve (ve dan) + cap nhat vung diem lon
    param($State)
    $res = Get-WCHealthScore $State.Groups
    $done = $State.Groups.Count
    $total = (Get-WCM6GroupKeys).Count
    if ($null -ne $res.Score) {
        $State.ScoreText.Text = [string]$res.Score
        $band = 'bad'
        $color = 'WcBad'
        if ($res.Score -ge 75) { $band = 'good'; $color = 'WcOk' }
        elseif ($res.Score -ge 50) { $band = 'mid'; $color = 'WcWarn' }
        $State.ScoreText.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, $color)
        $State.BandText.Text = (T ('m6.score.band.' + $band))
    } else {
        $State.ScoreText.Text = '—'
        $State.ScoreText.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'WcUnknown')
        if ($done -lt $total) { $State.BandText.Text = (T 'm6.status.scanning') }
        else { $State.BandText.Text = (T 'm6.score.nodata') }
    }
    if ($done -lt $total) {
        $State.PendingText.Text = (T 'm6.scan.pending' @([string]$done, [string]$total))
    } else {
        $State.PendingText.Text = (T 'm6.scan.done')
    }
    # Ghi chu "bo qua" - chi dem cac nhom DA VE va bi Unknown (khong dem nhom dang quet)
    $skippedReal = @()
    foreach ($k in @($State.Groups.Keys)) {
        if ([string]$State.Groups[$k]['Status'] -eq 'Unknown') { $skippedReal += $k }
    }
    if ($skippedReal.Count -gt 0) {
        $names = @()
        foreach ($n in $skippedReal) { $names += (Get-WCM6GroupLabel $n) }
        $State.RenormNote.Text = (T 'm6.score.renorm' @([string]::Join(', ', $names)))
        $State.RenormNote.Visibility = [Windows.Visibility]::Visible
    } else {
        $State.RenormNote.Visibility = [Windows.Visibility]::Collapsed
    }
    if ($res.Capped) {
        $State.CapNote.Text = (T 'm6.score.cap' @($res.CapReason))
        $State.CapNote.Visibility = [Windows.Visibility]::Visible
    } else {
        $State.CapNote.Visibility = [Windows.Visibility]::Collapsed
    }
}

# ---------------------------------------------------------------------------
# CHI TIET tung nhom (nap vao expander cua dong)
# ---------------------------------------------------------------------------
function Update-WCM6StorageDetail {
    param($DetailHost, $Data)
    if ($null -eq $Data) { return }
    $disks = Get-WCM6Field $Data 'Disks'
    $volumes = Get-WCM6Field $Data 'Volumes'
    if ($null -ne $disks) {
        $tbl = New-WCTable -Columns @(
            @{ Header = (T 'm6.storage.col.disk');     Prop = 'D0'; Width = 160 }
            @{ Header = (T 'm6.storage.col.media');    Prop = 'D1'; Width = 90 }
            @{ Header = (T 'm6.storage.col.health');   Prop = 'D2'; Width = 100 }
            @{ Header = (T 'm6.storage.col.temp');     Prop = 'D3'; Width = 90 }
            @{ Header = (T 'm6.storage.col.wear');     Prop = 'D4'; Width = 80 }
            @{ Header = (T 'm6.storage.col.hours');    Prop = 'D5'; Width = 90 }
            @{ Header = (T 'm6.storage.col.readerr');  Prop = 'D6'; Width = 150 }
        )
        foreach ($d in @($disks)) {
            $name = [string](Get-WCM6Field $d 'Name')
            if (-not $name) { $name = [string](Get-WCM6Field $d 'DeviceId') }
            if (-not $name) { $name = (T 'common.unknown') }
            $temp = Get-WCM6Field $d 'Temp'
            $wear = Get-WCM6Field $d 'Wear'
            $hours = Get-WCM6Field $d 'Hours'
            $rt = Get-WCM6Field $d 'ReadErrors'
            $ru = Get-WCM6Field $d 'ReadUncorr'
            $errTxt = (T 'common.na')
            if (($null -ne $rt) -or ($null -ne $ru)) {
                $errTxt = (T 'm6.fmt.errs' @([string]$rt, [string]$ru))
            }
            $tbl.Items.Add([PSCustomObject]@{
                D0 = $name
                D1 = [string](Get-WCM6Field $d 'Media')
                D2 = [string](Get-WCM6Field $d 'Health')
                D3 = ($(if ($null -ne $temp) { ('{0}°C' -f $temp) } else { (T 'common.na') }))
                D4 = ($(if ($null -ne $wear) { ('{0}%' -f $wear) } else { (T 'common.na') }))
                D5 = ($(if ($null -ne $hours) { (T 'm6.fmt.hours' @([string]$hours)) } else { (T 'common.na') }))
                D6 = $errTxt
            }) | Out-Null
        }
        Add-WCChild $DetailHost $tbl
    }
    if ($null -ne $volumes) {
        $vt = New-WCTable -Columns @(
            @{ Header = (T 'm6.storage.col.vol');   Prop = 'V0'; Width = 100 }
            @{ Header = (T 'm6.storage.col.size');  Prop = 'V1'; Width = 120 }
            @{ Header = (T 'm6.storage.col.free');  Prop = 'V2'; Width = 120 }
            @{ Header = (T 'm6.storage.col.pct');   Prop = 'V3'; Width = 90 }
        )
        foreach ($v in @($volumes)) {
            $size = Get-WCM6Field $v 'Size'
            $free = Get-WCM6Field $v 'Free'
            $pct = Get-WCM6Field $v 'PctFree'
            $vt.Items.Add([PSCustomObject]@{
                V0 = [string](Get-WCM6Field $v 'Letter')
                V1 = ($(if ($null -ne $size) { ConvertTo-WCHumanSize ([long]$size) } else { '—' }))
                V2 = ($(if ($null -ne $free) { ConvertTo-WCHumanSize ([long]$free) } else { '—' }))
                V3 = ($(if ($null -ne $pct) { ('{0}%' -f $pct) } else { '—' }))
            }) | Out-Null
        }
        Add-WCChild $DetailHost $vt
    }
}

function Update-WCM6StabilityDetail {
    param($DetailHost, $Data)
    if ($null -eq $Data) { return }
    $cats = Get-WCM6Field $Data 'Cats'
    $appOk = [bool](Get-WCM6Field $Data 'AppOk')
    if ($null -eq $cats) { return }
    $any = $false
    foreach ($catKey in @('kpower41', 'whea', 'bugcheck', 'diskerr', 'tdr', 'svc', 'appcrash')) {
        $n = 0
        $v = Get-WCM6Field $cats $catKey
        if ($null -ne $v) { $n = [int]$v }
        if ($n -le 0) { continue }
        $any = $true
        $line = New-WCTextBlock -Text ('• ' + (T ('m6.fact.stab.' + $catKey))) -Size 12.5 -Weight 'SemiBold' -Wrap
        Add-WCChild $DetailHost $line
        Add-WCChild $DetailHost (New-WCTextBlock -Text (T ('m6.stab.' + $catKey + '.desc')) -Size 11.5 -ColorKey 'WcSubtle' -Wrap)
        Add-WCChild $DetailHost (New-WCTextBlock -Text ('→ ' + (T ('m6.stab.' + $catKey + '.fix'))) -Size 11.5 -Wrap)
        Add-WCChild $DetailHost (New-WCSpacer -Height 4)
    }
    if (-not $any) {
        Add-WCChild $DetailHost (New-WCTextBlock -Text (T 'm6.stab.none') -Size 12.5 -ColorKey 'WcSubtle' -Wrap)
    }
    if (-not $appOk) {
        Add-WCChild $DetailHost (New-WCTextBlock -Text (T 'm6.fact.stab.applog') -Size 11.5 -ColorKey 'WcSubtle' -Wrap)
    }
}

function Update-WCM6IntegrityDetail {
    param($DetailHost, $Data, $DeepResult)
    if ($null -ne $Data) {
        $dism = Get-WCM6Field $Data 'Dism'
        if ($dism) {
            $dOk = Get-WCM6Field $dism 'Ok'
            $dCode = Get-WCM6Field $dism 'ExitCode'
            $txt = (T 'common.notread')
            if ($dOk) { $txt = [string]$dCode }
            Add-WCChild $DetailHost (New-WCFieldRow -Label (T 'm6.integrity.dism.exit') -Value $txt -NoCopy)
        }
        $sfc = Get-WCM6Field $Data 'Sfc'
        if ($sfc) {
            $sOk = Get-WCM6Field $sfc 'Ok'
            $sCode = Get-WCM6Field $sfc 'ExitCode'
            $txt = (T 'common.notread')
            if ($sOk) { $txt = [string]$sCode }
            Add-WCChild $DetailHost (New-WCFieldRow -Label (T 'm6.integrity.sfc.exit') -Value $txt -NoCopy)
        }
    }
    if ($null -ne $DeepResult) {
        $code = Get-WCM6Field $DeepResult 'ExitCode'
        $when = Get-WCM6Field $DeepResult 'Time'
        $txt = ''
        if ($code -eq 0) { $txt = (T 'm6.integrity.deep.done.ok') }
        else { $txt = (T 'm6.integrity.deep.done.unknown' @([string]$code)) }
        $whenTxt = ''
        try {
            if ($when -is [datetime]) { $whenTxt = $when.ToString('g') } else { $whenTxt = [string]$when }
        } catch { $whenTxt = [string]$when }
        if ($whenTxt) { $txt = $txt + ' (' + (T 'm6.scan.at' @($whenTxt)) + ')' }
        Add-WCChild $DetailHost (New-WCFieldRow -Label (T 'm6.integrity.deep.result') -Value $txt -NoCopy)
    }
}

function Update-WCM6IntegrityDeepNote {
    # Sau khi quet sâu xong: nap lai chi tiet nhom Toan ven (neu da co ket qua)
    param($State)
    $row = $State.Rows['Integrity']
    if (-not $row) { return }
    $row.DetailHost.Children.Clear()
    $data = $null
    if ($State.GroupData.ContainsKey('Integrity')) { $data = $State.GroupData['Integrity'] }
    try {
        Update-WCM6IntegrityDetail $row.DetailHost $data $State.DeepResult
    } catch {
        Write-WCLog 'WARN' ('M6 chi tiet Integrity (deep) loi: ' + $_.Exception.Message)
    }
}

function Update-WCM6SecurityDetail {
    param($DetailHost, $Data)
    if ($null -eq $Data) { return }
    $mode = [string](Get-WCM6Field $Data 'Mode')
    if ($mode -eq 'thirdparty') {
        $av = [string](Get-WCM6Field $Data 'AvName')
        Add-WCChild $DetailHost (New-WCFieldRow -Label (T 'm6.security.av') -Value ($(if ($av) { $av } else { (T 'common.unknown') })) -NoCopy)
        return
    }
    $rt = Get-WCM6Field $Data 'RealTime'
    $rtTxt = '—'
    if ($rt -eq $true) { $rtTxt = (T 'm6.on') }
    elseif ($rt -eq $false) { $rtTxt = (T 'm6.off') }
    Add-WCChild $DetailHost (New-WCFieldRow -Label (T 'm6.security.rtp') -Value $rtTxt -NoCopy)
    $sig = Get-WCM6Field $Data 'SigAgeDays'
    $sigTxt = '—'
    if ($null -ne $sig) { $sigTxt = (T 'fmt.days' @([string]$sig)) }
    Add-WCChild $DetailHost (New-WCFieldRow -Label (T 'm6.security.sigage') -Value $sigTxt -NoCopy)
    $eng = [string](Get-WCM6Field $Data 'Engine')
    if ($eng) {
        Add-WCChild $DetailHost (New-WCFieldRow -Label (T 'm6.security.engine') -Value $eng -NoCopy)
    }
    $tamper = Get-WCM6Field $Data 'Tamper'
    $tamperTxt = '—'
    if ($tamper -eq $true) { $tamperTxt = (T 'm6.on') }
    elseif ($tamper -eq $false) { $tamperTxt = (T 'm6.off') }
    Add-WCChild $DetailHost (New-WCFieldRow -Label (T 'm6.security.tamper') -Value $tamperTxt -NoCopy)
    foreach ($pair in @(@{ L = 'm6.security.lastquick'; V = (Get-WCM6Field $Data 'LastQuick') }, @{ L = 'm6.security.lastfull'; V = (Get-WCM6Field $Data 'LastFull') })) {
        $lq = $pair['V']
        if ($null -eq $lq) { continue }
        $lqTxt = '—'
        try {
            if ($lq -is [datetime]) { $lqTxt = $lq.ToString('g') } else { $lqTxt = [string]$lq }
        } catch { $lqTxt = [string]$lq }
        Add-WCChild $DetailHost (New-WCFieldRow -Label (T $pair['L']) -Value $lqTxt -NoCopy)
    }
}

function Update-WCM6MemoryDetail {
    param($DetailHost, $Data)
    if ($null -eq $Data) { return }
    $cats = Get-WCM6Field $Data 'Cats'
    $wheamem = 0; $diagErr = 0; $diagOk = 0
    if ($cats) {
        $v = Get-WCM6Field $cats 'wheamem'
        if ($null -ne $v) { $wheamem = [int]$v }
        $v = Get-WCM6Field $cats 'memdiagerr'
        if ($null -ne $v) { $diagErr = [int]$v }
        $v = Get-WCM6Field $cats 'memdiagok'
        if ($null -ne $v) { $diagOk = [int]$v }
    }
    Add-WCChild $DetailHost (New-WCFieldRow -Label (T 'm6.memory.wheacount') -Value ([string]$wheamem) -NoCopy)
    $diagTxt = (T 'm6.memory.diag.none')
    if ($diagErr -gt 0) { $diagTxt = (T 'm6.memory.diag.err') }
    elseif ($diagOk -gt 0) { $diagTxt = (T 'm6.memory.diag.ok') }
    Add-WCChild $DetailHost (New-WCFieldRow -Label (T 'm6.memory.diagresult') -Value $diagTxt -NoCopy)
}

function Update-WCM6BatteryDetail {
    param($DetailHost, $Data)
    if ($null -eq $Data) { return }
    $batteries = Get-WCM6Field $Data 'Batteries'
    if ($null -eq $batteries) { return }
    foreach ($b in @($batteries)) {
        $design = Get-WCM6Field $b 'Design'
        $full = Get-WCM6Field $b 'Full'
        $wear = Get-WCM6Field $b 'Wear'
        Add-WCChild $DetailHost (New-WCFieldRow -Label (T 'm6.battery.design') -Value ($(if ($design) { (T 'm6.fmt.mwh' @([string]$design)) } else { '—' })) -NoCopy)
        Add-WCChild $DetailHost (New-WCFieldRow -Label (T 'm6.battery.full') -Value ($(if ($full) { (T 'm6.fmt.mwh' @([string]$full)) } else { '—' })) -NoCopy)
        Add-WCChild $DetailHost (New-WCFieldRow -Label (T 'm6.battery.wear') -Value ($(if ($null -ne $wear) { ('{0}%' -f $wear) } else { '—' })) -NoCopy)
    }
}

# ---------------------------------------------------------------------------
# HANH DONG: quet sau (ScanHealth), sua loi (RestoreHealth/scannow), Memory Diagnostic
# ---------------------------------------------------------------------------
function Invoke-WCM6DeepScan {
    # Nut "Kiem tra sau (DISM ScanHealth)": lau (5-15 phut), chay nen, CO HUY.
    # Quet sau KHONG doi diem (chi la thong tin bo sung, trung thuc).
    param($State)
    if (Test-WCM6Busy) {
        Show-WCToast (T 'm6.busy') 'Info'
        return
    }
    if (-not (Show-WCConfirm -Title (T 'm6.integrity.deep.confirm.title') -Message (T 'm6.integrity.deep.confirm.msg'))) { return }
    $ok = Start-WCTask -Id 'm6.deepscan' -Title (T 'm6.integrity.deep') -ShowStatus -Worker {
        param($ctx, $s)
        $ctx.Progress(3, (T 'm6.integrity.deep.running'))
        $p = $null
        try {
            $p = Start-Process -FilePath 'dism.exe' -ArgumentList '/Online', '/Cleanup-Image', '/ScanHealth' -WindowStyle Hidden -PassThru -ErrorAction Stop
        } catch {
            return @{ Ok = $false; Cancelled = $false; Error = $_.Exception.Message; ExitCode = $null }
        }
        # Vong poll de HUY duoc that (kill dism an toan vi ScanHealth chi quet)
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $expected = 900.0
        while (-not $p.HasExited) {
            if ($ctx.Cancelled()) {
                try { $p.Kill() } catch { }
                return @{ Ok = $true; Cancelled = $true; Error = ''; ExitCode = $null }
            }
            $pct = [int][math]::Min(92, (3 + (($sw.Elapsed.TotalSeconds / $expected) * 89)))
            $ctx.Progress($pct, (T 'm6.integrity.deep.running'))
            Start-Sleep -Seconds 3
        }
        try { $p.WaitForExit() } catch { }
        return @{ Ok = $true; Cancelled = $false; Error = ''; ExitCode = $p.ExitCode }
    } -Done {
        param($r)
        if ($r.Cancelled) {
            Show-WCToast (T 'common.task.cancelled') 'Info'
            return
        }
        if (-not $r.Ok) {
            Show-WCError -Friendly (T 'common.task.failed') -Details $r.Error
            return
        }
        $State.DeepResult = @{ ExitCode = $r.ExitCode; Time = (Get-Date) }
        Update-WCM6IntegrityDeepNote $State
        if ($r.ExitCode -eq 0) {
            Show-WCToast (T 'm6.integrity.deep.done.ok') 'Ok'
        } else {
            Show-WCToast (T 'm6.integrity.deep.done.unknown' @([string]$r.ExitCode)) 'Warn'
        }
    }.GetNewClosure()
    if (-not $ok) { Show-WCToast (T 'm6.busy') 'Info' }
}

function Invoke-WCM6RunMemoryDiagnostic {
    # Chi MO cong cu cua Windows (mdsched.exe), KHONG tu khoi dong lai may
    if (-not (Show-WCConfirm -Title (T 'm6.memory.confirm.title') -Message (T 'm6.memory.confirm.msg'))) { return }
    try {
        Start-Process -FilePath 'mdsched.exe' -ErrorAction Stop
        Show-WCToast (T 'm6.memory.opened') 'Ok'
        Write-WCLog 'INFO' 'M6: da mo Windows Memory Diagnostic (nguoi dung tu quyet dinh khoi dong lai)'
    } catch {
        Show-WCError -Friendly (T 'common.cannotopen') -Details $_.Exception.Message
    }
}

function Invoke-WCM6Repair {
    # Hanh dong NANG CAO: DISM RestoreHealth / SFC scannow (spec M6).
    # Xac nhan -> thu tao diem khoi phuc (that bai se hoi lai, khong lach) ->
    # journal -> chay nen co Huy + uoc tinh thoi gian.
    param($State, [string]$Kind)
    if ($Kind -ne 'dism' -and $Kind -ne 'sfc') { return }
    if (Test-WCM6Busy) {
        Show-WCToast (T 'm6.busy') 'Info'
        return
    }
    $msgKey = 'm6.repair.confirm.msg.' + $Kind
    if (-not (Show-WCConfirm -Title (T 'm6.repair.confirm.title') -Message (T $msgKey) -NotUndoable (T 'm6.repair.noundo'))) { return }
    Invoke-WCM6RepairPhase $State $Kind $false
}

function Invoke-WCM6RepairPhase {
    param($State, [string]$Kind, [bool]$SkipCp)
    $ok = Start-WCTask -Id ('m6.repair.' + $Kind) -Title (T 'm6.repair.running') -ShowStatus -Args @{ Kind = $Kind; SkipCp = $SkipCp } -Worker {
        param($ctx, $s)
        $isDism = ($s.Kind -eq 'dism')
        # Buoc 1: thu tao diem khoi phuc (System Restore co the tat -> bao ro, khong lach)
        if (-not $s.SkipCp) {
            $ctx.Progress(3, (T 'm6.repair.cp.running'))
            $cpErr = ''
            try {
                Checkpoint-Computer -Description 'WinCare M6 - truoc khi sua loi he thong' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
            } catch { $cpErr = $_.Exception.Message }
            if ($cpErr -ne '') { return @{ Phase = 'askcp'; CpError = $cpErr } }
        }
        # Buoc 2: ghi journal truoc khi thay doi he thong (spec 2.4)
        $cmd = 'sfc.exe /scannow'
        $journalAction = (T 'm6.repair.journal.sfc')
        if ($isDism) {
            $cmd = 'DISM /Online /Cleanup-Image /RestoreHealth'
            $journalAction = (T 'm6.repair.journal.dism')
        }
        $entry = Add-WCJournalEntry -Module 'M6' -Action $journalAction -Target 'Windows' -OldValue '' -UndoType ''
        if (Test-WCDryRunMode) {
            Complete-WCJournalEntry -Entry $entry -Result 'DryRun'
            $ctx.Log('[DRY-RUN] se chay: ' + $cmd)
            return @{ Phase = 'done'; DryRun = $true; Ok = $true; Cancelled = $false; ExitCode = 0; Cmd = $cmd }
        }
        # Buoc 3: chay lenh that, poll de Huy duoc
        $ctx.Progress(6, ((T 'm6.repair.running') + ' (' + $cmd + ')'))
        $p = $null
        try {
            if ($isDism) {
                $p = Start-Process -FilePath 'dism.exe' -ArgumentList '/Online', '/Cleanup-Image', '/RestoreHealth' -WindowStyle Hidden -PassThru -ErrorAction Stop
            } else {
                $p = Start-Process -FilePath 'sfc.exe' -ArgumentList '/scannow' -WindowStyle Hidden -PassThru -ErrorAction Stop
            }
        } catch {
            Complete-WCJournalEntry -Entry $entry -Result ('Failed: ' + $_.Exception.Message)
            return @{ Phase = 'done'; DryRun = $false; Ok = $false; Cancelled = $false; Error = $_.Exception.Message; ExitCode = $null; Cmd = $cmd }
        }
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $expected = 1200.0
        if (-not $isDism) { $expected = 600.0 }
        while (-not $p.HasExited) {
            if ($ctx.Cancelled()) {
                try { $p.Kill() } catch { }
                Complete-WCJournalEntry -Entry $entry -Result 'Cancelled'
                return @{ Phase = 'done'; DryRun = $false; Ok = $true; Cancelled = $true; ExitCode = $null; Cmd = $cmd }
            }
            $pct = [int][math]::Min(92, (6 + (($sw.Elapsed.TotalSeconds / $expected) * 86)))
            $ctx.Progress($pct, ((T 'm6.repair.running') + ' — ' + $cmd))
            Start-Sleep -Seconds 3
        }
        try { $p.WaitForExit() } catch { }
        Complete-WCJournalEntry -Entry $entry -Result ('ExitCode ' + $p.ExitCode)
        return @{ Phase = 'done'; DryRun = $false; Ok = $true; Cancelled = $false; ExitCode = $p.ExitCode; Cmd = $cmd }
    } -Done {
        param($r)
        if ($r.Phase -eq 'askcp') {
            # Khong tao duoc restore point -> hoi ro rang, khong tu dong tiep tuc
            $msg = (T 'm6.repair.cp.fail' @($r.CpError))
            if (Show-WCConfirm -Title (T 'm6.repair.cp.ask.title') -Message ($msg + "`n`n" + (T 'm6.repair.cp.ask.msg'))) {
                Invoke-WCM6RepairPhase $State $Kind $true
            } else {
                Show-WCToast (T 'common.cancel') 'Info'
                Write-WCLog 'INFO' 'M6: nguoi dung tu choi sua loi khi khong co diem khoi phuc'
            }
            return
        }
        if ($r.DryRun) {
            Show-WCToast (T 'common.dryrun.header') 'Info'
            return
        }
        if ($r.Cancelled) {
            Show-WCToast (T 'm6.repair.cancelled') 'Info'
            return
        }
        if (-not $r.Ok) {
            Show-WCError -Friendly (T 'common.task.failed') -Details $r.Error
            return
        }
        if ($r.ExitCode -eq 0) {
            Show-WCToast (T 'm6.repair.done.ok') 'Ok'
        } else {
            Show-WCToast (T 'm6.repair.done.unknown' @([string]$r.ExitCode)) 'Warn'
        }
    }.GetNewClosure()
    if (-not $ok) { Show-WCToast (T 'm6.busy') 'Info' }
}

# ---------------------------------------------------------------------------
# UI CHINH
# ---------------------------------------------------------------------------
function New-WCM6AdvancedSection {
    # Muc NANG CAO: sua loi he thong (DISM RestoreHealth / SFC scannow)
    param($State)
    $sec = New-WCSection -Title (T 'm6.repair.title') -Subtitle (T 'm6.repair.subtitle')
    $risk = Get-WCRiskInfo 'Advanced'
    $chip = New-WCChip -Text $risk.Text -Kind 'Warn'
    $chip.HorizontalAlignment = [Windows.HorizontalAlignment]::Left
    Add-WCChild $sec.Body $chip
    Add-WCChild $sec.Body (New-WCTextBlock -Text $risk.Hint -Size 11.5 -ColorKey 'WcSubtle' -Wrap)
    # DISM RestoreHealth
    $row1 = New-WCHStack -Spacing 10
    $b1 = New-WCButton -Text (T 'm6.repair.dism') -OnClick { param($b) Invoke-WCM6Repair $State 'dism' }.GetNewClosure()
    $b1.VerticalAlignment = [Windows.VerticalAlignment]::Center
    Add-WCChild $row1 $b1
    $t1 = New-WCTextBlock -Text (T 'm6.repair.dism.eta') -Size 12 -ColorKey 'WcSubtle' -Wrap
    $t1.VerticalAlignment = [Windows.VerticalAlignment]::Center
    Add-WCChild $row1 $t1
    Add-WCChild $sec.Body $row1
    # SFC /scannow
    $row2 = New-WCHStack -Spacing 10
    $b2 = New-WCButton -Text (T 'm6.repair.sfc') -OnClick { param($b) Invoke-WCM6Repair $State 'sfc' }.GetNewClosure()
    $b2.VerticalAlignment = [Windows.VerticalAlignment]::Center
    Add-WCChild $row2 $b2
    $t2 = New-WCTextBlock -Text (T 'm6.repair.sfc.eta') -Size 12 -ColorKey 'WcSubtle' -Wrap
    $t2.VerticalAlignment = [Windows.VerticalAlignment]::Center
    Add-WCChild $row2 $t2
    Add-WCChild $sec.Body $row2
    # Che do chuyen gia: hien dung lenh se chay
    Add-WCChild $sec.Body (New-WCExpertLine -Command 'DISM /Online /Cleanup-Image /RestoreHealth')
    Add-WCChild $sec.Body (New-WCExpertLine -Command 'sfc.exe /scannow')
    return $sec
}

function New-WCM6Panel {
    param($State)
    $root = New-Object Windows.Controls.ScrollViewer
    $root.VerticalScrollBarVisibility = [Windows.Controls.ScrollBarVisibility]::Auto
    $hostPanel = New-WCVStack -Spacing 14
    $hostPanel.Margin = (New-Object Windows.Thickness(20))
    $root.Content = $hostPanel

    # Tieu de + chip Beta (trung thuc: chua kiem chung runtime tren Windows that)
    $titleRow = New-WCHStack
    $titleRow.Children.Add((New-WCHeading (T 'm6.title'))) | Out-Null
    $betaChip = New-WCChip -Text (T 'common.beta') -Kind 'Warn'
    $betaChip.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $titleRow.Children.Add($betaChip) | Out-Null
    Add-WCChild $hostPanel $titleRow
    Add-WCChild $hostPanel (New-WCSubtitle (T 'm6.subtitle'))

    # Muc diem: diem to + dai cham chu + cong thuc minh bach + thoi diem quet
    $scoreSec = New-WCSection -Title (T 'm6.score')
    $scoreRow = New-WCHStack -Spacing 16
    $scoreText = New-WCTextBlock -Text '—' -Size 42 -Weight 'SemiBold'
    $scoreRow.Children.Add($scoreText) | Out-Null
    $bandBox = New-WCVStack -Spacing 2
    $bandText = New-WCTextBlock -Text (T 'm6.status.scanning') -Size 14 -Weight 'SemiBold'
    Add-WCChild $bandBox $bandText
    $pendingText = New-WCTextBlock -Text '' -Size 12 -ColorKey 'WcSubtle'
    Add-WCChild $bandBox $pendingText
    $bandBox.VerticalAlignment = [Windows.VerticalAlignment]::Center
    $scoreRow.Children.Add($bandBox) | Out-Null
    Add-WCChild $scoreSec.Body $scoreRow
    Add-WCChild $scoreSec.Body (New-WCTextBlock -Text (T 'm6.score.howto') -Size 11.5 -ColorKey 'WcSubtle' -Wrap)
    $renormNote = New-WCTextBlock -Text '' -Size 12 -Wrap
    $renormNote.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'WcWarn')
    $renormNote.TextWrapping = [Windows.TextWrapping]::Wrap
    $renormNote.Visibility = [Windows.Visibility]::Collapsed
    Add-WCChild $scoreSec.Body $renormNote
    $capNote = New-WCTextBlock -Text '' -Size 12 -Wrap
    $capNote.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, 'WcBad')
    $capNote.TextWrapping = [Windows.TextWrapping]::Wrap
    $capNote.Visibility = [Windows.Visibility]::Collapsed
    Add-WCChild $scoreSec.Body $capNote
    $scanRow = New-WCHStack -Spacing 12
    $scanLabel = New-WCTextBlock -Text '' -Size 12.5 -ColorKey 'WcSubtle'
    $scanLabel.VerticalAlignment = [Windows.VerticalAlignment]::Center
    Add-WCChild $scanRow $scanLabel
    $rescanBtn = New-WCButton -Text (T 'common.rescan') -Kind Primary -OnClick {
        param($b)
        Invoke-WCM6Rescan $State
    }.GetNewClosure()
    $rescanBtn.VerticalAlignment = [Windows.VerticalAlignment]::Center
    Add-WCChild $scanRow $rescanBtn
    Add-WCChild $scoreSec.Body $scanRow
    Add-WCChild $hostPanel $scoreSec.Root

    # Bang phan ra: Nhom | Trong so | Diem | Tai sao | Nen lam gi
    $brkSec = New-WCSection -Title (T 'm6.breakdown.title') -Subtitle (T 'm6.breakdown.sub')
    $hdr = New-WCM6FiveColGrid
    $labels = @((T 'm6.col.group'), (T 'm6.col.weight'), (T 'm6.col.score'), (T 'm6.col.why'), (T 'm6.col.what'))
    $i = 0
    foreach ($lbl in $labels) {
        $t = New-WCTextBlock -Text $lbl -Size 11.5 -ColorKey 'WcSubtle'
        [Windows.Controls.Grid]::SetColumn($t, $i)
        $hdr.Children.Add($t) | Out-Null
        $i++
    }
    Add-WCChild $brkSec.Body $hdr
    $weights = @{ Storage = 25; Stability = 25; Integrity = 15; Security = 15; Memory = 10; Battery = 10 }
    foreach ($k in (Get-WCM6GroupKeys)) {
        $row = New-WCM6GroupRow $State $k $weights[$k]
        Add-WCChild $brkSec.Body $row.Card
    }
    Add-WCChild $hostPanel $brkSec.Root

    # Muc nang cao: sua loi he thong
    $advSec = New-WCM6AdvancedSection $State
    Add-WCChild $hostPanel $advSec.Root

    # Luu tham chieu dieu khien vao State
    $State.ScoreText = $scoreText
    $State.BandText = $bandText
    $State.PendingText = $pendingText
    $State.RenormNote = $renormNote
    $State.CapNote = $capNote
    $State.ScanLabel = $scanLabel
    return $root
}

# ---------------------------------------------------------------------------
# KHOI TAO MODULE (goi 1 lan khi nap app)
# ---------------------------------------------------------------------------
function Initialize-WCModuleM6 {
    $state = @{
        Groups = @{}          # Key -> @{ Status; Score; Severe; Reason }
        GroupData = @{}       # Key -> du lieu tho de ve chi tiet
        Rows = @{}            # Key -> cac phan tu UI cua dong nhom
        ScanTime = $null
        DeepResult = $null    # Ket qua quet sau gan nhat (nguoi dung tu bam)
        Scanned = $false
        ScoreText = $null; BandText = $null; PendingText = $null
        RenormNote = $null; CapNote = $null; ScanLabel = $null
    }
    Register-WCNavItem -Key 'm6' -Badge 'M6' -Title (T 'm6.title') -Order 70 -Builder {
        New-WCM6Panel $state
    }.GetNewClosure() -OnShow {
        # Lan dau mo muc: tu quet (chi doc). cac lan sau giu ket qua cu + nut Quet lai
        if (-not $state.Scanned) {
            $state.Scanned = $true
            Invoke-WCM6RunScan $state $false
        }
    }.GetNewClosure()
}
