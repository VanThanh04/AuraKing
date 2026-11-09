# AuraKing — EA lệnh đơn cho XAUUSD (MT5)

**Phiên bản: v1.00** (09/11/2026) · Kết quả nghiên cứu: [docs/BACKTEST.md](docs/BACKTEST.md) · Lịch sử: [CHANGELOG.md](CHANGELOG.md)

> ⚠️ Mọi con số dưới đây là backtest. Hãy chạy demo vài tháng trước khi dùng tiền thật.

## Khác gì AuraFusion

| | AuraFusion | AuraKing |
|---|---|---|
| Kiểu vào lệnh | Rổ nhiều lệnh, nhồi theo trend (DCA dương) | **Mỗi tín hiệu = 1 lệnh**, không nhồi, không martingale |
| Cắt lỗ | SL theo tiền của cả rổ | **SL thật trên server cho từng lệnh** (k × ATR) |
| Khối lượng | Lot cố định | **Lot theo % rủi ro**: chạm SL mất đúng X% số dư |
| Rủi ro đuôi | Rổ 10 bậc có thể lỗ lớn trong 1 cú quét | Lỗ tối đa mỗi lệnh ≈ X% số dư (trừ trượt giá / gap) |

## Cách bot giao dịch (mặc định v1.00)

1. **Động cơ E1 — TIA M5 đảo chiều.** Đường TIA (EMA 9 trên nến Heikin-Ashi) khung M5 vừa đổi chiều, và TIA khung H1
   cùng chiều đó → vào 1 lệnh theo chiều mới.
2. **Động cơ E2 — Donchian M15.** Nến M15 vừa đóng cửa phá kênh 20 nến, cùng phía với EMA 200 M15 → vào 1 lệnh theo hướng phá.
3. **Cả bot chỉ giữ 1 lệnh tại một thời điểm.** Động cơ nào có tín hiệu trước thì vào.
4. **SL = 1,5 × ATR(14)** của khung động cơ (tối thiểu 2 giá, tối đa 20 giá; ATR quá lớn thì bỏ lệnh). **TP = 2R.**
5. Lãi đạt **1R** → kéo SL về hoà vốn + 0,1R. Lãi đạt **1,5R** → trailing cách giá 2 × ATR.
   Động cơ đã mở lệnh báo tín hiệu **ngược chiều** → đóng lệnh và đảo chiều.
6. **Lot** = 0,5% số dư ÷ (khoảng SL × giá trị 1 lot). Trần 5 lot/lệnh.
7. **Bộ lọc:** spread ≤ 0,8 giá · chỉ vào lệnh 01:15–21:55 giờ server · tối thứ Sáu (từ 18:00) không vào ·
   tối đa 8 lệnh/ngày · lỗ trong ngày ≥ 2% hoặc thua 3 lệnh liên tiếp → nghỉ hết ngày.

## Kết quả backtest (real-tick, XAUUSD, vốn 100.000 USD, 1:200, đã trừ hoa hồng 7 USD/lot)

| Preset | 2025 | 01–10/2026 (ngoài mẫu) | 22 tháng liền |
|---|---|---|---|
| `AuraKing_v100_macdinh.set` (rủi ro 0,5%) | +58.711 @ MaxDD 13,1% | +39.985 @ MaxDD 13,0% | **+124.283 @ MaxDD 13,1%** |
| `AuraKing_v100_rui_ro_1pct.set` (rủi ro 1%) | — | — | +238.538 @ MaxDD 25,5% |

- PF 1,11 ở cả hai năm, tỉ lệ thắng ~53%, khoảng 140 lệnh/tháng.
- Lãi mỗi lệnh nhỏ so với chi phí: **hoa hồng ăn khoảng 19% lãi trước phí** (29,6k trên 153,9k trong 22 tháng).
  Tài khoản phí cao hơn 7 USD/lot sẽ cho kết quả kém hơn rõ.
- Tham số được chọn trên 2025; 2026 là kiểm tra ngoài mẫu. Riêng việc ghép E1 + E2 được quyết định sau khi đã xem 2026
  (chi tiết trong docs/BACKTEST.md), nên hãy coi 2026 là ước lượng lạc quan.

## Cài đặt

| File | Copy vào |
|---|---|
| `MQL5/Experts/AuraKing.ex5` | `<Data Folder>\MQL5\Experts\` (chạy được ngay) |
| `MQL5/Experts/AuraKing.mq5` + `MQL5/Include/AuraKingSignals.mqh` | `Experts\` và `Include\` (nếu tự compile) |
| `Presets/*.set` | `<Data Folder>\MQL5\Presets\` |

Gắn vào chart **XAUUSD M1**, bật Algo Trading. Tài khoản **Hedging** (netting cũng chạy được với `InpOnePosGlobal = true`).
Không chạy chung magic `20261101`–`20261105` với EA khác.

## Input chính

| Input | Mặc định | Ý nghĩa |
|---|---|---|
| `InpRiskPct` | 0.5 | % số dư mất nếu chạm SL |
| `InpEngines` | "1,2" | Động cơ bật: 1 TIA · 2 Donchian · 3 Breakout phiên · 4 Hồi về EMA · 5 Fade Bollinger |
| `InpOnePosGlobal` | true | Cả bot 1 lệnh (false = mỗi động cơ 1 lệnh) |
| `InpSL_ATR` / `InpSL_MinUSD` / `InpSL_MaxUSD` | 1.5 / 2 / 20 | SL = k × ATR, kẹp trong [min, max] giá |
| `InpTP_R` | 2.0 | TP = R × SL (0 = không TP, chỉ trailing) |
| `InpBE_R`, `InpTrailStartR`, `InpTrailATR` | 1.0, 1.5, 2.0 | Hoà vốn và trailing |
| `InpE1_HTF` | 60 | Lọc TIA khung lớn cho E1 (0 = tắt) |
| `InpDayLossPct`, `InpMaxTradesDay`, `InpMaxConsecLoss` | 2, 8, 3 | Giới hạn ngày |

E3, E4, E5 vẫn có trong mã để thử nghiệm nhưng **đã test real-tick là lỗ ngoài mẫu** — không bật khi chạy thật.

## Về AUREUSPRIME QUANTUM AI

QUANTUM là bot thương mại đã mã hoá, **tự chặn Strategy Tester** và cần license. AuraKing không dịch ngược nó; chỉ học
kiến trúc lộ ra từ danh sách tham số: nhiều động cơ độc lập có magic riêng, lot theo % rủi ro, SL có trần, lọc spread,
khung giờ 01:15–21:55 và lọc tin. Mức rủi ro 5%/lệnh mặc định của QUANTUM là quá cao; AuraKing dùng 0,5%.

## Cấu trúc

```
MQL5/Experts/AuraKing.mq5           lõi: rủi ro, vào/thoát lệnh, giới hạn ngày, OnTester
MQL5/Include/AuraKingSignals.mqh    5 động cơ tín hiệu
Presets/                            preset mặc định (0,5%) và rủi ro 1%
docs/BACKTEST.md                    4 vòng backtest, bảng số liệu, kết luận
```
