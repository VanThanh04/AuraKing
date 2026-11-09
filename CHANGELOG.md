# Lịch sử phát triển AuraKing

## v1.01 — 09/11/2026 · Rủi ro mặc định 1%

- `InpRiskPct` mặc định 0,5 → **1,0**. Logic giao dịch không đổi.
- Preset mới: `AuraKing_v101_macdinh.set` (1%) và `AuraKing_v101_an_toan_0_5pct.set` (0,5%); bỏ hai preset v1.00.
- Kiểm tra lại real-tick: 2025 +110.769 @ DD 23,0% · 01–10/2026 +65.043 @ DD 27,2% · 22 tháng +238.538 @ DD 25,5%.

## v1.00 — 09/11/2026 · Bản đầu tiên

- EA lệnh đơn XAUUSD: mỗi tín hiệu 1 lệnh có SL thật trên server, lot theo % rủi ro số dư, không DCA/martingale.
- 5 động cơ tín hiệu (`AuraKingSignals.mqh`): E1 TIA đảo chiều, E2 Donchian breakout, E3 breakout biên độ phiên,
  E4 hồi về EMA + RSI, E5 fade Bollinger. Mỗi động cơ magic riêng (`InpMagic + số động cơ`).
- Thoát lệnh: SL k×ATR (kẹp min/max), TP theo R, hoà vốn, trailing ATR, giới hạn thời gian giữ, đóng + đảo chiều.
- Bộ lọc: spread, khung giờ server, tối thứ Sáu, lỗ ngày %, số lệnh/ngày, thua liên tiếp, chờ sau khi đóng lệnh.
- Mặc định chọn qua 4 vòng backtest real-tick: **E1 (lọc TIA H1) + E2, cả bot 1 lệnh, rủi ro 0,5%**.
  22 tháng +124.283 @ MaxDD 13,1% (vốn 100k, đã trừ hoa hồng 7 USD/lot).
- `OnTester` ghi CSV: lãi gộp, hoa hồng tester đã trừ, phần bù hoa hồng, lãi ròng, DD, PF, tỉ lệ thắng, lãi từng động cơ.
- Đã qua review mã độc lập: 0 lỗi nghiêm trọng; đã sửa các điểm trung bình (đảo chiều bị cooldown chặn, E3 mất lượt
  khi lệnh bị chặn, khung thời gian không hỗ trợ, điều kiện "vừa phá kênh" của E2 luôn đúng, mở CSV khi nhiều agent).
