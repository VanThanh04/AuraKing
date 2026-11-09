# Nghiên cứu và backtest AuraKing v1.00 (11/2026)

## Phương pháp

- MT5 Strategy Tester, **Model = 4 (real ticks)**, XAUUSD, Exness-MT5Real8, vốn 100.000 USD, đòn bẩy 1:200, chart M1.
- **Chọn tham số trên 2025**, kiểm tra **ngoài mẫu 01/01–01/11/2026**. Kết quả đọc từ CSV do `OnTester()` ghi.
- **Hoa hồng:** tester **đã tự trừ khoảng 5,5 USD/lot** (cột `tcomm`). `OnTester` bù thêm cho đủ `InpCommPerLot` = 7 USD/lot.
  Mọi cột "lãi" bên dưới là lãi **sau** 7 USD/lot.
- Mặc định khi test: rủi ro 0,5%/lệnh, SL 1,5×ATR, TP 2R, hoà vốn 1R, trailing từ 1,5R, giới hạn ngày 8 lệnh / lỗ 2% / thua 3.

## QUANTUM AI (tham khảo)

`AUREUSPRIME_QUANTUM_AI_v1_0_5.ex5` tự dừng trong tester với thông báo chỉ chạy trên tài khoản thật có license, nên
không đo được hành vi. Không dịch ngược. Danh sách tham số tester lưu lại cho thấy:
luồng **QUANT** (4 động cơ A–D, magic riêng, lot 0,1 / 1.000 USD) và luồng **SIGMA** (2 chiến lược, rủi ro 5%/lệnh,
SL tối đa 2.000 điểm, TP 5.000 điểm, spread ≤ 100 điểm, giờ 01:15–21:55, tránh tin USD ±2 phút).

## Vòng 1 — từng động cơ riêng lẻ, tham số mặc định

| Động cơ | 2025 | DD | 2026 | DD | PF 25 / 26 |
|---|---|---|---|---|---|
| E1 TIA M5 đảo chiều | +40.904 | 13,2% | +13.141 | 12,9% | 1,12 / 1,06 |
| E2 Donchian M15 (20 nến, EMA 200) | +23.650 | 9,4% | +11.040 | 9,6% | 1,11 / 1,09 |
| E3 Breakout biên độ 00:00–07:00 | +8.667 | 5,4% | −3.127 | 4,4% | 1,20 / 0,80 |
| E4 Hồi về EMA H1 + RSI M5 | +29.326 | 21,7% | −9.740 | 28,5% | 1,09 / 0,97 |
| E5 Fade Bollinger M15 | −9.933 | 28,3% | −12.978 | 18,2% | 0,97 / 0,92 |

Chỉ hai động cơ **đi theo xu hướng** (E1, E2) có lãi cả hai năm. Fade thua ở cả hai năm — giống kết luận cũ của AuraFusion.

## Vòng 2 — quét từng tham số (chọn trên 2025)

| Cấu hình | 2025 | DD | 2026 | DD |
|---|---|---|---|---|
| E1 khung M15 | −5.537 | 24,6% | −18.793 | 21,1% |
| **E1 + lọc TIA H1** | **+52.512** | 11,1% | **+17.950** | 15,9% |
| E1 TF M15 + lọc H4 | +2.886 | 19,9% | −11.583 | 17,2% |
| E1 không TP | +50.952 | 17,5% | +13.894 | 13,5% |
| E1 TP 3R | +52.702 | 16,8% | +13.368 | 13,9% |
| E1 SL 1×ATR | +80.636 | 15,0% | −10.927 | 15,1% |
| E1 SL 2,5×ATR | +37.180 | 9,7% | +2.911 | 14,0% |
| E1 không hoà vốn | +38.158 | 11,9% | +9.076 | 16,2% |
| E1 không trailing | +39.888 | 13,2% | +15.696 | 12,5% |
| E1 không đảo chiều | +122.175 | 9,1% | +7.410 | 20,6% |
| E2 khung H1 / M5 | −3.178 / +34.939 | | +774 / −29.011 | |
| E2 kênh 55 / bỏ EMA | +8.292 / +22.384 | | +3.886 / +7.606 | |
| E2 không TP / TP 3R | +26.306 / +22.851 | | +2.245 / +4.656 | |
| E2 SL 1 / 2,5×ATR | +17.923 / +9.724 | | +1.667 / +5.145 | |
| E2 không hoà vốn / không trailing / không đảo chiều | +24.741 / +21.164 / +28.258 | | +6.018 / +11.865 / +10.961 | |
| E3 biên độ tối đa 80 / phiên New York | +11.829 / +4.483 | | −11.843 / −4.541 | |

Cấu hình "đẹp nhất 2025" (E1 không đảo chiều +122k, SL 1×ATR +80k) **sụp ngoài mẫu**. Chỉ lọc TIA H1 tốt hơn gốc ở cả hai năm.

## Vòng 3 — khung lọc, giới hạn ngày, ghép động cơ

| Cấu hình | 2025 | DD | 2026 | DD |
|---|---|---|---|---|
| E1 lọc M30 / H2 / H4 | +1.003 / +104.016 / +104.276 | 27,7 / 12,7 / 13,1% | +2.320 / +6.886 / +17.456 | 25,6 / 21,4 / 14,1% |
| E1 lọc H1, không trailing | +56.763 | 11,3% | +25.946 | 13,5% |
| E1 lọc H1, không TP | +125.475 | 13,2% | +18.274 | 14,9% |
| E1 lọc H1, **bỏ giới hạn ngày** | +41.250 | 15,5% | +8.146 | 23,2% |
| E1 + E2, mỗi động cơ 1 lệnh, không trần lệnh/ngày | +72.060 | 13,7% | +37.456 | 14,9% |
| E1 + E2, mỗi động cơ 1 lệnh, trần 16 lệnh, thua 5 | +82.805 | 16,2% | +17.773 | 22,2% |
| **E1 + E2, cả bot 1 lệnh** (→ mặc định) | **+58.711** | **13,1%** | **+39.985** | **13,0%** |

- Giới hạn ngày có ích ở cả hai năm.
- Ghép hai động cơ đi theo xu hướng khác nhau (đảo chiều TIA và phá kênh Donchian) cho PF 1,11 ở **cả** hai năm.

## Vòng 4 — kiểm tra vùng lân cận của cấu hình mặc định

| Biến thể của "E1 + E2, 1 lệnh" | 2025 | DD | 2026 | DD |
|---|---|---|---|---|
| Lọc H4 thay H1 | +137.186 | 10,8% | +23.541 | 17,7% |
| E2 khung M30 | +60.592 | 11,5% | +22.477 | 11,6% |
| Không đảo chiều | +53.337 | 12,6% | +32.089 | 14,0% |
| TP 3R | +105.993 | 12,4% | +24.042 | 10,7% |

Mọi biến thể đều lãi ở cả hai năm (PF 1,07–1,22) → đây là một **vùng ổn định**, không phải một điểm may mắn.

### Chạy liền 22 tháng (01/2025 – 01/11/2026)

| Cấu hình | Lãi | MaxDD | PF | Lệnh | Lot | Hoa hồng |
|---|---|---|---|---|---|---|
| **Mặc định, rủi ro 0,5%** | **+124.283** | **13,1%** | 1,109 | 3.129 | 4.234 | 29.636 |
| Rủi ro 1% | +238.538 | 25,5% | 1,088 | 2.858 | 9.397 | 65.778 |
| Chỉ E1 gốc (không lọc H1) | +59.876 | 15,4% | 1,089 | 2.990 | 4.045 | 28.312 |

Đóng góp trong 22 tháng (mặc định): E1 +78.672 (2.380 lệnh), E2 +45.611 (749 lệnh).

## Kết luận

1. **Lợi thế nhỏ nhưng có thật ở các chiến lược đi theo xu hướng** (PF ~1,1). Đánh ngược xu hướng và hồi giá đều lỗ ngoài mẫu.
2. **Chọn "tốt nhất 2025" gần như luôn chọn nhầm nhiễu.** Cấu hình được chọn là một vùng mà mọi điểm lân cận đều lãi.
3. **Chi phí giao dịch là yếu tố sống còn**: hoa hồng ~19% lãi trước phí. Đừng chạy trên tài khoản phí cao hoặc spread rộng.
4. So với AuraFusion v4.10 (22 tháng +157k @ DD 20,9% với lot 0,10): AuraKing rủi ro 0,5% cho +124k @ DD 13,1% —
   tỉ lệ lãi/DD tốt hơn và **không có đuôi rủi ro của rổ nhồi lệnh**.
5. **Phát hiện phụ:** tester Exness đã trừ ~5,5 USD/lot. Các bảng của AuraFusion ghi "chưa trừ hoa hồng" nhiều khả năng sai.

## Giới hạn

- Việc ghép E1 + E2 được quyết định sau khi đã thấy kết quả 2026 của vòng 2 → 2026 không còn là ngoài mẫu hoàn toàn.
- Chưa có lọc tin tức (lịch MT5 không có dữ liệu trong tester; nghiên cứu cũ cho thấy tránh tin không thêm lãi).
- Trượt giá thật khi tin mạnh có thể làm lỗ vượt 0,5%.
