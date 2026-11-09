//+------------------------------------------------------------------+
//| AuraKingSignals.mqh - 5 dong co tin hieu cho AuraKing (lenh don)  |
//| Moi dong co tra ve +1 (BUY), -1 (SELL), 0 (khong) tren nen DA DONG |
//| cua khung rieng. Chi danh gia 1 lan moi nen moi cua khung do.      |
//+------------------------------------------------------------------+
#property strict

input group "=== AuraKing: DONG CO TIN HIEU ==="
input string InpEngines     = "1,2";  // Dong co bat (vd "1" hoac "1,2,3"): 1 TIA dao chieu | 2 Donchian breakout | 3 Breakout phien A | 4 Hoi ve EMA | 5 Fade Bollinger
input int    InpATRPeriod   = 14;     // Chu ky ATR dung tinh SL / trailing (theo khung cua dong co)

input group "=== E1: TIA (Heikin-Ashi EMA) DAO CHIEU ==="
input int    InpE1_TF       = 5;      // Khung (phut)
input int    InpE1_Period   = 9;      // Chu ky EMA tren nen Heikin-Ashi
input int    InpE1_HTF      = 60;     // Loc xu huong: TIA khung lon (phut) phai cung chieu (0 = tat)

input group "=== E2: DONCHIAN BREAKOUT ==="
input int    InpE2_TF       = 15;     // Khung (phut)
input int    InpE2_N        = 20;     // So nen kenh
input int    InpE2_EMA      = 200;    // Loc: chi BUY khi gia > EMA, SELL khi < EMA (0 = tat)

input group "=== E3: BREAKOUT BIEN DO PHIEN A ==="
input int    InpE3_RangeFrom = 0;     // Bat dau do bien do (HHMM gio server)
input int    InpE3_RangeTo   = 700;   // Ket thuc do bien do (HHMM)
input int    InpE3_LastEntry = 1600;  // Khong vao sau gio nay (HHMM)
input double InpE3_BufferUSD = 0.5;   // Gia dong M1 phai vuot dinh/day bien do them X (gia)
input double InpE3_MinRange  = 3.0;   // Bien do toi thieu (gia); nho hon thi bo ngay
input double InpE3_MaxRange  = 40.0;  // Bien do toi da (gia)

input group "=== E4: HOI VE TRONG XU HUONG (EMA + RSI) ==="
input int    InpE4_TF       = 5;      // Khung vao lenh (phut)
input int    InpE4_HTF      = 60;     // Khung xu huong (phut)
input int    InpE4_Fast     = 20;     // EMA nhanh (khung xu huong)
input int    InpE4_Slow     = 50;     // EMA cham (khung xu huong)
input int    InpE4_RSI      = 14;     // RSI (khung vao lenh)
input double InpE4_RSILo    = 40;     // Xu huong tang: RSI cat len tren muc nay -> BUY
input double InpE4_RSIHi    = 60;     // Xu huong giam: RSI cat xuong duoi muc nay -> SELL

input group "=== E5: FADE BOLLINGER (nguoc chieu, doi chung) ==="
input int    InpE5_TF       = 15;     // Khung (phut)
input int    InpE5_Period   = 20;     // Chu ky Bollinger
input double InpE5_Dev      = 2.0;    // Do lech chuan

#define AK_ENGINES 5

//=================== TIEN ICH ===================
ENUM_TIMEFRAMES AkTF(const int m)
{
   switch(m)
   {
      case 1:    return PERIOD_M1;   case 2:  return PERIOD_M2;   case 3:  return PERIOD_M3;
      case 5:    return PERIOD_M5;   case 10: return PERIOD_M10;  case 15: return PERIOD_M15;
      case 30:   return PERIOD_M30;  case 60: return PERIOD_H1;   case 120: return PERIOD_H2;
      case 240:  return PERIOD_H4;   case 1440: return PERIOD_D1;
   }
   return PERIOD_CURRENT;                             // khung khong ho tro -> AkSignalsInit bao loi
}

bool AkTFValid(const int m) { return m > 0 && AkTF(m) != PERIOD_CURRENT; }

int AkHHMM(const datetime t)
{
   MqlDateTime d; TimeToStruct(t, d);
   return d.hour * 100 + d.min;
}

double AkBuf(const int handle, const int buf, const int shift)
{
   double v[1];
   if(handle == INVALID_HANDLE || CopyBuffer(handle, buf, shift, 1, v) != 1) return EMPTY_VALUE;
   return v[0];
}

//=================== TRANG THAI ===================
bool     g_akOn[AK_ENGINES + 1];
int      g_akTFmin[AK_ENGINES + 1];
datetime g_akLastBar[AK_ENGINES + 1];
int      g_akATR[AK_ENGINES + 1];
int      g_akE2ema = INVALID_HANDLE;
int      g_akE4fast = INVALID_HANDLE, g_akE4slow = INVALID_HANDLE, g_akE4rsi = INVALID_HANDLE;
int      g_akE5bb = INVALID_HANDLE;
// E3: bien do phien theo ngay
datetime g_akE3Day = 0;
double   g_akE3Hi = 0, g_akE3Lo = 0;
bool     g_akE3Done = false;

// Bat dong co tu chuoi "1,2,3". Tra ve false neu khong co dong co hop le.
bool AkParseEngines()
{
   ArrayInitialize(g_akOn, false);
   string parts[];
   int n = StringSplit(InpEngines, ',', parts);
   bool any = false;
   for(int i = 0; i < n; i++)
   {
      StringTrimLeft(parts[i]); StringTrimRight(parts[i]);
      int e = (int)StringToInteger(parts[i]);
      if(e >= 1 && e <= AK_ENGINES) { g_akOn[e] = true; any = true; }
   }
   return any;
}

bool AkSignalsInit()
{
   if(!AkParseEngines()) { Print("AuraKing: InpEngines khong hop le: ", InpEngines); return false; }
   g_akTFmin[1] = InpE1_TF; g_akTFmin[2] = InpE2_TF; g_akTFmin[3] = 1;
   g_akTFmin[4] = InpE4_TF; g_akTFmin[5] = InpE5_TF;
   int tfs[] = {InpE1_TF, InpE2_TF, InpE4_TF, InpE4_HTF, InpE5_TF};
   for(int i = 0; i < ArraySize(tfs); i++)
      if(!AkTFValid(tfs[i])) { Print("AuraKing: khung khong ho tro (phut): ", tfs[i]); return false; }
   if(InpE1_HTF > 0 && !AkTFValid(InpE1_HTF)) { Print("AuraKing: InpE1_HTF khong ho tro: ", InpE1_HTF); return false; }
   for(int e = 1; e <= AK_ENGINES; e++)
   {
      g_akLastBar[e] = 0;
      g_akATR[e] = INVALID_HANDLE;
      if(!g_akOn[e]) continue;
      // E3 dung ATR M15 cho SL (M1 qua nhieu nhieu)
      int atrTF = (e == 3) ? 15 : g_akTFmin[e];
      g_akATR[e] = iATR(_Symbol, AkTF(atrTF), InpATRPeriod);
      if(g_akATR[e] == INVALID_HANDLE) return false;
   }
   if(g_akOn[2] && InpE2_EMA > 0)
   {
      g_akE2ema = iMA(_Symbol, AkTF(InpE2_TF), InpE2_EMA, 0, MODE_EMA, PRICE_CLOSE);
      if(g_akE2ema == INVALID_HANDLE) return false;
   }
   if(g_akOn[4])
   {
      g_akE4fast = iMA(_Symbol, AkTF(InpE4_HTF), InpE4_Fast, 0, MODE_EMA, PRICE_CLOSE);
      g_akE4slow = iMA(_Symbol, AkTF(InpE4_HTF), InpE4_Slow, 0, MODE_EMA, PRICE_CLOSE);
      g_akE4rsi  = iRSI(_Symbol, AkTF(InpE4_TF), InpE4_RSI, PRICE_CLOSE);
      if(g_akE4fast == INVALID_HANDLE || g_akE4slow == INVALID_HANDLE || g_akE4rsi == INVALID_HANDLE) return false;
   }
   if(g_akOn[5])
   {
      g_akE5bb = iBands(_Symbol, AkTF(InpE5_TF), InpE5_Period, 0, InpE5_Dev, PRICE_CLOSE);
      if(g_akE5bb == INVALID_HANDLE) return false;
   }
   return true;
}

void AkSignalsDeinit()
{
   for(int e = 1; e <= AK_ENGINES; e++)
      if(g_akATR[e] != INVALID_HANDLE) IndicatorRelease(g_akATR[e]);
   int h[] = {g_akE2ema, g_akE4fast, g_akE4slow, g_akE4rsi, g_akE5bb};
   for(int i = 0; i < ArraySize(h); i++)
      if(h[i] != INVALID_HANDLE) IndicatorRelease(h[i]);
}

// ATR (nen da dong) cua dong co e, dung cho SL / trailing.
double AkATR(const int e) { return AkBuf(g_akATR[e], 0, 1); }

//=================== E1: TIA ===================
// Huong TIA tai nen dong shift=1 (out1) va shift=2 (out2). Cong thuc giong AuraFusion ComputeTIA.
bool AkTIA(const int tfMin, const int period, int &out1, int &out2)
{
   ENUM_TIMEFRAMES tf = AkTF(tfMin);
   int P = MathMax(1, period);
   int need = P * 6 + 30;
   double o[], h[], l[], c[];
   if(CopyOpen(_Symbol, tf, 1, need, o) != need || CopyHigh(_Symbol, tf, 1, need, h) != need ||
      CopyLow(_Symbol, tf, 1, need, l) != need || CopyClose(_Symbol, tf, 1, need, c) != need)
      return false;
   double haO = (o[0] + c[0]) / 2.0, haC = (o[0] + h[0] + l[0] + c[0]) / 4.0;
   double eO = haO, eC = haC;
   double eH = MathMax(h[0], MathMax(haO, haC)), eL = MathMin(l[0], MathMin(haO, haC));
   double a = 2.0 / (P + 1.0);
   double trPrev = 0, trLast = 0;
   for(int i = 1; i < need; i++)
   {
      double hC = (o[i] + h[i] + l[i] + c[i]) / 4.0;
      double hO = (haO + haC) / 2.0;
      double hH = MathMax(h[i], MathMax(hO, hC));
      double hL = MathMin(l[i], MathMin(hO, hC));
      haO = hO; haC = hC;
      eO = a * hO + (1.0 - a) * eO;  eC = a * hC + (1.0 - a) * eC;
      eH = a * hH + (1.0 - a) * eH;  eL = a * hL + (1.0 - a) * eL;
      double den = eH - eL;
      trPrev = trLast;
      trLast = (den > 0.0) ? (eC - eO) / den : 0.0;
   }
   out1 = (trLast > 0) ? 1 : ((trLast < 0) ? -1 : 0);
   out2 = (trPrev > 0) ? 1 : ((trPrev < 0) ? -1 : 0);
   return true;
}

int AkE1()
{
   int d1, d2;
   if(!AkTIA(InpE1_TF, InpE1_Period, d1, d2)) return 0;
   if(d1 == 0 || d1 == d2) return 0;                  // chi vao khi vua dao chieu
   if(InpE1_HTF > 0)
   {
      int h1, h2;
      if(!AkTIA(InpE1_HTF, InpE1_Period, h1, h2) || h1 != d1) return 0;
   }
   return d1;
}

//=================== E2: DONCHIAN ===================
int AkE2()
{
   ENUM_TIMEFRAMES tf = AkTF(InpE2_TF);
   int n = MathMax(2, InpE2_N);
   double hi[], lo[];
   // kenh tu nen 3..N+2 -> nen 2 nam ngoai kenh, kiem tra "nen 1 vua pha, nen 2 chua pha" co y nghia
   if(CopyHigh(_Symbol, tf, 3, n, hi) != n || CopyLow(_Symbol, tf, 3, n, lo) != n) return 0;
   double top = hi[ArrayMaximum(hi)], bot = lo[ArrayMinimum(lo)];
   double c1 = iClose(_Symbol, tf, 1), c2 = iClose(_Symbol, tf, 2);
   int dir = 0;
   if(c1 > top && c2 <= top) dir = 1;                 // vua pha len (khong vao lai lien tuc)
   else if(c1 < bot && c2 >= bot) dir = -1;
   if(dir == 0) return 0;
   if(InpE2_EMA > 0)
   {
      double ema = AkBuf(g_akE2ema, 0, 1);
      if(ema == EMPTY_VALUE) return 0;
      if(dir > 0 && c1 <= ema) return 0;
      if(dir < 0 && c1 >= ema) return 0;
   }
   return dir;
}

//=================== E3: BREAKOUT PHIEN ===================
// Chay moi nen M1. Do bien do [RangeFrom, RangeTo) tren M1; sau RangeTo, vao 1 lan/ngay khi pha.
int AkE3()
{
   datetime t1 = iTime(_Symbol, PERIOD_M1, 1);
   MqlDateTime d; TimeToStruct(t1, d);
   datetime day = t1 - (d.hour * 3600 + d.min * 60 + d.sec);
   if(day != g_akE3Day)
   {
      // ngay moi: bien do se duoc do sau khi qua RangeTo (g_akE3Hi < 0 = chua do)
      g_akE3Day  = day;
      g_akE3Hi   = -1;
      g_akE3Lo   = 0;
      g_akE3Done = (InpE3_RangeTo <= InpE3_RangeFrom);
   }
   if(g_akE3Done) return 0;
   int now = AkHHMM(t1);
   if(now < InpE3_RangeTo) return 0;
   if(now >= InpE3_LastEntry) { g_akE3Done = true; return 0; }
   if(g_akE3Hi < 0)
   {
      datetime from = g_akE3Day + (InpE3_RangeFrom / 100) * 3600 + (InpE3_RangeFrom % 100) * 60;
      datetime to   = g_akE3Day + (InpE3_RangeTo / 100) * 3600 + (InpE3_RangeTo % 100) * 60 - 1;
      double hi[], lo[];
      int nh = CopyHigh(_Symbol, PERIOD_M1, from, to, hi);
      int nl = CopyLow(_Symbol, PERIOD_M1, from, to, lo);
      if(nh <= 10 || nl <= 10) { g_akE3Done = true; return 0; }
      g_akE3Hi = hi[ArrayMaximum(hi)];
      g_akE3Lo = lo[ArrayMinimum(lo)];
      double rng = g_akE3Hi - g_akE3Lo;
      if(rng < InpE3_MinRange || rng > InpE3_MaxRange) { g_akE3Done = true; return 0; }
   }
   double c1 = iClose(_Symbol, PERIOD_M1, 1);
   // chua danh dau Done: OpenTrade goi AkOnOpened(3) khi lenh mo thanh cong (bi chan thi thu lai nen sau)
   if(c1 > g_akE3Hi + InpE3_BufferUSD) return 1;
   if(c1 < g_akE3Lo - InpE3_BufferUSD) return -1;
   return 0;
}

// Goi khi dong co e vua mo lenh thanh cong.
void AkOnOpened(const int e) { if(e == 3) g_akE3Done = true; }

//=================== E4: HOI VE TRONG XU HUONG ===================
int AkE4()
{
   double f = AkBuf(g_akE4fast, 0, 1), s = AkBuf(g_akE4slow, 0, 1);
   double r1 = AkBuf(g_akE4rsi, 0, 1), r2 = AkBuf(g_akE4rsi, 0, 2);
   if(f == EMPTY_VALUE || s == EMPTY_VALUE || r1 == EMPTY_VALUE || r2 == EMPTY_VALUE) return 0;
   if(f > s && r2 < InpE4_RSILo && r1 >= InpE4_RSILo) return 1;
   if(f < s && r2 > InpE4_RSIHi && r1 <= InpE4_RSIHi) return -1;
   return 0;
}

//=================== E5: FADE BOLLINGER ===================
int AkE5()
{
   ENUM_TIMEFRAMES tf = AkTF(InpE5_TF);
   double up2 = AkBuf(g_akE5bb, 1, 2), lo2 = AkBuf(g_akE5bb, 2, 2);
   double up1 = AkBuf(g_akE5bb, 1, 1), lo1 = AkBuf(g_akE5bb, 2, 1);
   if(up2 == EMPTY_VALUE || lo2 == EMPTY_VALUE || up1 == EMPTY_VALUE || lo1 == EMPTY_VALUE) return 0;
   double c1 = iClose(_Symbol, tf, 1), c2 = iClose(_Symbol, tf, 2);
   if(c2 < lo2 && c1 >= lo1) return 1;                // dong lai vao trong tu duoi -> BUY
   if(c2 > up2 && c1 <= up1) return -1;
   return 0;
}

// Danh gia dong co e neu khung cua no vua co nen moi. Tra ve huong (0 = khong co tin hieu).
int AkSignal(const int e)
{
   if(!g_akOn[e]) return 0;
   datetime bt = iTime(_Symbol, AkTF(g_akTFmin[e]), 0);
   if(bt == 0 || bt == g_akLastBar[e]) return 0;
   g_akLastBar[e] = bt;
   switch(e)
   {
      case 1: return AkE1();
      case 2: return AkE2();
      case 3: return AkE3();
      case 4: return AkE4();
      case 5: return AkE5();
   }
   return 0;
}

string AkEngineName(const int e)
{
   switch(e)
   {
      case 1: return "TIA";   case 2: return "DON";  case 3: return "ORB";
      case 4: return "PULL";  case 5: return "FADE";
   }
   return "?";
}
