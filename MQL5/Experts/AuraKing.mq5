//+------------------------------------------------------------------+
//| AuraKing.mq5 - EA LENH DON cho XAUUSD (MT5)                       |
//| - Khong DCA, khong martingale: moi tin hieu = 1 lenh co SL that.  |
//| - Lot tinh theo % rui ro so du khi cham SL.                       |
//| - 5 dong co tin hieu bat/tat rieng (AuraKingSignals.mqh), moi     |
//|   dong co dung magic rieng (InpMagic + so dong co).               |
//+------------------------------------------------------------------+
#property copyright "AuraKing"
#property version   "1.00"
#property description "EA lenh don XAUUSD: SL that, lot theo % rui ro, 5 dong co tin hieu."

#include <Trade\Trade.mqh>
#include <AuraKingSignals.mqh>

input group "=== AuraKing: RUI RO ==="
input double InpRiskPct      = 0.5;    // % so du chiu lo moi lenh khi cham SL
input double InpMaxLot       = 5.0;    // Tran lot moi lenh
input long   InpMagic        = 20261100; // Magic goc (dong co e dung InpMagic + e)
input bool   InpOnePosGlobal = true;   // true: ca bot chi 1 lenh mo | false: moi dong co toi da 1 lenh

input group "=== THOAT LENH ==="
input double InpSL_ATR       = 1.5;    // SL = k x ATR (khung dong co)
input double InpSL_MinUSD    = 2.0;    // SL toi thieu (gia)
input double InpSL_MaxUSD    = 20.0;   // SL toi da (gia); ATR lon hon -> bo lenh
input double InpTP_R         = 2.0;    // TP = R x khoang SL (0 = khong dat TP)
input double InpBE_R         = 1.0;    // Lai >= R x SL -> keo SL ve hoa von (0 = tat)
input double InpBE_LockR     = 0.1;    // Khi hoa von: khoa them R x SL lai
input double InpTrailStartR  = 1.5;    // Lai >= R x SL -> trailing theo ATR (0 = tat)
input double InpTrailATR     = 2.0;    // Khoang trailing = k x ATR
input int    InpMaxHoldMin   = 0;      // Dong lenh sau X phut (0 = tat)
input bool   InpExitOnFlip   = true;   // Tin hieu nguoc chieu cua cung dong co -> dong lenh (va dao chieu)

input group "=== BO LOC & GIOI HAN NGAY ==="
input double InpMaxSpreadUSD = 0.8;    // Khong vao khi spread > X (gia); 0 = tat
input int    InpStartHHMM    = 115;    // Gio server bat dau cho phep vao lenh (HHMM)
input int    InpEndHHMM      = 2155;   // Gio server ngung vao lenh (HHMM)
input bool   InpNoFriLate    = true;   // Thu Sau: ngung vao lenh tu 18:00 server
input double InpDayLossPct   = 2.0;    // Lo trong ngay (da chot + dang mo) >= X% -> nghi het ngay (0 = tat)
input int    InpMaxTradesDay = 8;      // Toi da so lenh vao moi ngay (0 = tat)
input int    InpMaxConsecLoss= 3;      // Thua lien tiep K lenh trong ngay -> nghi het ngay (0 = tat)
input int    InpCooldownMin  = 0;      // Cho X phut sau khi dong lenh moi vao tiep (0 = tat)

input group "=== BAO CAO ==="
input double InpCommPerLot   = 7.0;    // Hoa hong tron vong / lot muc tieu: OnTester bu phan tester chua tru (chi de bao cao)
input string InpResultCsv    = "";     // File CSV ket qua OnTester trong Common\Files (rong = tat)
input string InpResultTag    = "";     // Nhan dong ket qua
input bool   InpQuietLog     = false;  // Tat log tung lenh
input bool   InpShowStatus   = true;   // Hien trang thai len chart (Comment)

CTrade   g_trade;
datetime g_dayStart = 0;
double   g_dayBal   = 0;
string   g_status   = "";
bool     g_dayHalt  = false;
// rui ro ban dau (khoang SL) cua tung lenh, de tinh R khi SL da bi keo
ulong    g_rTk[];
double   g_rDist[];

//=================== TIEN ICH ===================
bool IsOurMagic(const long m) { return m > InpMagic && m <= InpMagic + AK_ENGINES; }
int  EngineOf(const long m)   { return (int)(m - InpMagic); }

void Log(const string s) { if(!InpQuietLog) Print("AuraKing: ", s); }

void RiskRemember(const ulong tk, const double dist)
{
   int n = ArraySize(g_rTk);
   ArrayResize(g_rTk, n + 1); ArrayResize(g_rDist, n + 1);
   g_rTk[n] = tk; g_rDist[n] = dist;
   if(n > 200) { ArrayRemove(g_rTk, 0, 100); ArrayRemove(g_rDist, 0, 100); }
}

// Khoang SL ban dau: bo nho -> comment "AKe|dist" -> |open - SL| (du phong).
double RiskDist(const ulong tk, const string cmt, const double open, const double sl)
{
   for(int i = ArraySize(g_rTk) - 1; i >= 0; i--)
      if(g_rTk[i] == tk) return g_rDist[i];
   int p = StringFind(cmt, "|");
   if(p > 0)
   {
      double d = StringToDouble(StringSubstr(cmt, p + 1));
      if(d > 0) return d;
   }
   return (sl > 0) ? MathAbs(open - sl) : 0.0;
}

// Lot sao cho cham SL (khoang slDist gia) mat ~InpRiskPct% so du. 0 = khong vao duoc.
double LotForRisk(const double slDist, const int dir)
{
   double risk = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPct / 100.0;
   double tSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tVal <= 0) tVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tSize <= 0 || tVal <= 0 || slDist <= 0 || risk <= 0) return 0.0;
   double lossPerLot = slDist / tSize * tVal;
   double vMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vMax = MathMin(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX), InpMaxLot);
   double vStp = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(vStp <= 0) vStp = vMin;
   double lot = MathFloor(risk / lossPerLot / vStp + 1e-9) * vStp;
   if(lot < vMin)
   {
      if(vMin * lossPerLot > 1.2 * risk) return 0.0;   // lot nho nhat vuot rui ro cho phep qua 20%
      lot = vMin;
   }
   lot = MathMin(lot, vMax);
   // khong de ky quy vuot 90% ky quy tu do
   double price = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double margin = 0;
   ENUM_ORDER_TYPE ot = (dir > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(OrderCalcMargin(ot, _Symbol, lot, price, margin) && margin > 0)
   {
      double free = AccountInfoDouble(ACCOUNT_MARGIN_FREE) * 0.9;
      if(margin > free) lot = MathFloor(lot * free / margin / vStp) * vStp;
   }
   if(lot < vMin) return 0.0;
   int dg = 0;
   while(dg < 8 && MathAbs(vStp * MathPow(10, dg) - MathRound(vStp * MathPow(10, dg))) > 1e-9) dg++;
   return NormalizeDouble(lot, dg);
}

//=================== THONG KE TRONG NGAY ===================
struct DayStats { double realized; int entries; int consecLoss; datetime lastClose; };

DayStats TodayStats()
{
   DayStats s; s.realized = 0; s.entries = 0; s.consecLoss = 0; s.lastClose = 0;
   if(!HistorySelect(g_dayStart, TimeCurrent() + 60)) return s;
   int n = HistoryDealsTotal();
   for(int i = 0; i < n; i++)
   {
      ulong tk = HistoryDealGetTicket(i);
      if(tk == 0 || !IsOurMagic(HistoryDealGetInteger(tk, DEAL_MAGIC))) continue;
      if(HistoryDealGetString(tk, DEAL_SYMBOL) != _Symbol) continue;
      long ent = HistoryDealGetInteger(tk, DEAL_ENTRY);
      double cost = HistoryDealGetDouble(tk, DEAL_COMMISSION) + HistoryDealGetDouble(tk, DEAL_FEE);
      if(ent == DEAL_ENTRY_IN) { s.entries++; s.realized += cost; continue; }
      double pl = HistoryDealGetDouble(tk, DEAL_PROFIT) + HistoryDealGetDouble(tk, DEAL_SWAP) + cost;
      s.realized += pl;
      s.consecLoss = (pl < 0) ? s.consecLoss + 1 : 0;
      s.lastClose = (datetime)HistoryDealGetInteger(tk, DEAL_TIME);
   }
   return s;
}

double FloatingPL()
{
   double f = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(!IsOurMagic(PositionGetInteger(POSITION_MAGIC))) continue;
      f += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return f;
}

void DayRollover()
{
   MqlDateTime d; TimeToStruct(TimeCurrent(), d);
   datetime day = TimeCurrent() - (d.hour * 3600 + d.min * 60 + d.sec);
   if(day == g_dayStart) return;
   g_dayStart = day;
   g_dayHalt  = false;
   // moc = so du dau ngay (tru phan da chot hom nay, dung khi EA khoi dong lai giua ngay)
   g_dayBal   = AccountInfoDouble(ACCOUNT_BALANCE) - TodayStats().realized;
}

// Kiem tra moi bo loc truoc khi vao lenh moi. why = ly do chan.
bool AllowEntry(string &why, const bool flipping)
{
   if(g_dayHalt) { why = "nghi het ngay"; return false; }
   double spr = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(InpMaxSpreadUSD > 0 && spr > InpMaxSpreadUSD) { why = "spread rong"; return false; }
   MqlDateTime d; TimeToStruct(TimeCurrent(), d);
   int now = d.hour * 100 + d.min;
   bool inWin = (InpStartHHMM <= InpEndHHMM) ? (now >= InpStartHHMM && now < InpEndHHMM)
                                             : (now >= InpStartHHMM || now < InpEndHHMM);
   if(!inWin) { why = "ngoai gio"; return false; }
   if(InpNoFriLate && d.day_of_week == 5 && now >= 1800) { why = "toi thu Sau"; return false; }
   DayStats s = TodayStats();
   if(InpDayLossPct > 0 && g_dayBal > 0 && s.realized + FloatingPL() <= -g_dayBal * InpDayLossPct / 100.0)
   { g_dayHalt = true; why = "lo ngay"; return false; }
   if(InpMaxConsecLoss > 0 && s.consecLoss >= InpMaxConsecLoss) { g_dayHalt = true; why = "thua lien tiep"; return false; }
   if(InpMaxTradesDay > 0 && s.entries >= InpMaxTradesDay) { why = "du so lenh ngay"; return false; }
   if(!flipping && InpCooldownMin > 0 && s.lastClose > 0 && TimeCurrent() - s.lastClose < InpCooldownMin * 60)
   { why = "cho sau dong lenh"; return false; }
   return true;
}

//=================== VI THE ===================
// Tim lenh cua dong co e (0 neu khong co). dir = +1/-1.
ulong EnginePosition(const int e, int &dir)
{
   dir = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic + e) continue;
      dir = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      return tk;
   }
   return 0;
}

int OurPositions()
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk != 0 && PositionGetString(POSITION_SYMBOL) == _Symbol && IsOurMagic(PositionGetInteger(POSITION_MAGIC))) n++;
   }
   return n;
}

bool OpenTrade(const int e, const int dir)
{
   double atr = AkATR(e);
   if(atr == EMPTY_VALUE || atr <= 0) { g_status = "chua co ATR"; return false; }
   double slDist = MathMax(InpSL_MinUSD, InpSL_ATR * atr);
   if(InpSL_MaxUSD > 0 && slDist > InpSL_MaxUSD) { g_status = "SL vuot tran"; return false; }
   double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double stopLvl = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * pt;
   double spr = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
   slDist = MathMax(slDist, stopLvl + spr + 2 * pt);
   double lot = LotForRisk(slDist, dir);
   if(lot <= 0) { g_status = "lot qua nho so voi rui ro"; return false; }
   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double px = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = NormalizeDouble(px - dir * slDist, dg);
   double tp = (InpTP_R > 0) ? NormalizeDouble(px + dir * slDist * InpTP_R, dg) : 0.0;
   string cmt = StringFormat("AK%d|%.2f", e, slDist);
   g_trade.SetExpertMagicNumber(InpMagic + e);
   bool ok = (dir > 0) ? g_trade.Buy(lot, _Symbol, 0, sl, tp, cmt) : g_trade.Sell(lot, _Symbol, 0, sl, tp, cmt);
   uint rc = g_trade.ResultRetcode();
   if(!ok || (rc != TRADE_RETCODE_DONE && rc != TRADE_RETCODE_PLACED))
   {
      Log(StringFormat("mo lenh %s loi %u", AkEngineName(e), rc));
      return false;
   }
   ulong tk = g_trade.ResultOrder();
   // trong che do hedging, ticket vi the = ticket lenh
   RiskRemember(tk, slDist);
   AkOnOpened(e);
   Log(StringFormat("%s %s %.2f lot @%.2f SL %.2f TP %.2f (ATR %.2f)", AkEngineName(e), dir > 0 ? "BUY" : "SELL",
                    lot, px, sl, tp, atr));
   return true;
}

void HandleSignal(const int e, const int dir)
{
   int curDir = 0;
   bool flipping = false;
   ulong tk = EnginePosition(e, curDir);
   if(tk != 0)
   {
      if(curDir == dir) return;                      // da co lenh cung chieu
      if(!InpExitOnFlip) return;                     // giu lenh cu den SL/TP
      g_trade.SetExpertMagicNumber(InpMagic + e);
      if(!g_trade.PositionClose(tk)) { Log("dong lenh dao chieu loi"); return; }
      Log(StringFormat("%s dao chieu -> dong lenh", AkEngineName(e)));
      flipping = true;
   }
   if(InpOnePosGlobal && OurPositions() > 0) return;
   string why = "";
   if(!AllowEntry(why, flipping)) { g_status = why; return; }
   OpenTrade(e, dir);
}

// Hoa von / trailing / gioi han thoi gian giu lenh. Goi moi tick.
void ManagePositions()
{
   int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double stopLvl = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * pt;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID), ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      long mg = PositionGetInteger(POSITION_MAGIC);
      if(!IsOurMagic(mg)) continue;
      int e = EngineOf(mg);
      int dir = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL), tp = PositionGetDouble(POSITION_TP);
      double R = RiskDist(tk, PositionGetString(POSITION_COMMENT), open, sl);
      g_trade.SetExpertMagicNumber(mg);
      if(InpMaxHoldMin > 0 && TimeCurrent() - (datetime)PositionGetInteger(POSITION_TIME) >= InpMaxHoldMin * 60)
      {
         if(g_trade.PositionClose(tk)) Log(StringFormat("%s dong vi giu qua %d phut", AkEngineName(e), InpMaxHoldMin));
         continue;
      }
      if(R <= 0) continue;
      double px = (dir > 0) ? bid : ask;
      double gain = (px - open) * dir;
      double newSL = sl;
      if(InpBE_R > 0 && gain >= InpBE_R * R)
      {
         double be = open + dir * InpBE_LockR * R;
         if(sl == 0 || (be - sl) * dir > 0) newSL = be;
      }
      if(InpTrailStartR > 0 && gain >= InpTrailStartR * R)
      {
         double atr = AkATR(e);
         if(atr != EMPTY_VALUE && atr > 0)
         {
            double tr = px - dir * InpTrailATR * atr;
            if((tr - newSL) * dir > 0 || newSL == 0) newSL = tr;
         }
      }
      newSL = NormalizeDouble(newSL, dg);
      if(newSL == sl) continue;
      double minStep = MathMax(10 * pt, 0.05 * R);   // khong sua lenh lien tuc tung diem
      if(sl != 0 && (newSL - sl) * dir < minStep) continue;
      if((px - newSL) * dir <= stopLvl) continue;    // qua sat gia hien tai
      if(!g_trade.PositionModify(tk, newSL, tp))
         Log(StringFormat("sua SL loi %u", g_trade.ResultRetcode()));
   }
}

//=================== SU KIEN ===================
int OnInit()
{
   if(InpRiskPct <= 0 || InpRiskPct > 10) { Print("AuraKing: InpRiskPct phai trong (0, 10]"); return INIT_PARAMETERS_INCORRECT; }
   if(!AkSignalsInit()) return INIT_FAILED;
   if(!InpOnePosGlobal && AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
      Print("AuraKing: tai khoan netting -> cac dong co dung chung 1 vi the (nen dat InpOnePosGlobal = true)");
   g_trade.SetDeviationInPoints(30);
   g_trade.SetTypeFillingBySymbol(_Symbol);
   DayRollover();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   AkSignalsDeinit();
   if(InpShowStatus) Comment("");
}

void OnTick()
{
   DayRollover();
   ManagePositions();
   for(int e = 1; e <= AK_ENGINES; e++)
   {
      int sig = AkSignal(e);
      if(sig != 0) HandleSignal(e, sig);
   }
   if(InpShowStatus && !MQLInfoInteger(MQL_TESTER))
      Comment(StringFormat("AuraKing v1.00 | dong co: %s | rui ro %.2f%% | lenh mo: %d | %s",
                           InpEngines, InpRiskPct, OurPositions(), g_status));
}

//=================== KET QUA BACKTEST ===================
double OnTester()
{
   // STAT_PROFIT da gom hoa hong ma tester tu tru (DEAL_COMMISSION). Bao cao tach rieng:
   //   tcomm = hoa hong tester da tru; extra = phan bu them cho du InpCommPerLot moi lot (neu tester tru it hon).
   double gross = TesterStatistics(STAT_PROFIT);
   double lots = 0, tcomm = 0, eNet[AK_ENGINES + 1], eLots[AK_ENGINES + 1];
   int eTr[AK_ENGINES + 1];
   ArrayInitialize(eNet, 0); ArrayInitialize(eLots, 0); ArrayInitialize(eTr, 0);
   if(HistorySelect(0, TimeCurrent() + 60))
      for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
      {
         ulong tk = HistoryDealGetTicket(i);
         long mg = HistoryDealGetInteger(tk, DEAL_MAGIC);
         if(!IsOurMagic(mg)) continue;
         int e = EngineOf(mg);
         double c = HistoryDealGetDouble(tk, DEAL_COMMISSION) + HistoryDealGetDouble(tk, DEAL_FEE);
         tcomm += c;
         eNet[e] += HistoryDealGetDouble(tk, DEAL_PROFIT) + HistoryDealGetDouble(tk, DEAL_SWAP) + c;
         if(HistoryDealGetInteger(tk, DEAL_ENTRY) == DEAL_ENTRY_IN)
         {
            double vol = HistoryDealGetDouble(tk, DEAL_VOLUME);
            lots += vol; eLots[e] += vol; eTr[e]++;
         }
      }
   double extraPerLot = (lots > 0) ? MathMax(0.0, InpCommPerLot - (-tcomm) / lots) : 0.0;
   double comm = lots * extraPerLot;
   for(int e = 1; e <= AK_ENGINES; e++) eNet[e] -= eLots[e] * extraPerLot;
   double net = gross - comm;
   double trades = TesterStatistics(STAT_TRADES);
   double win = (trades > 0) ? 100.0 * TesterStatistics(STAT_PROFIT_TRADES) / trades : 0;
   if(StringLen(InpResultCsv) > 0)
   {
      int h = INVALID_HANDLE;
      for(int k = 0; k < 20 && h == INVALID_HANDLE; k++)
      {
         h = FileOpen(InpResultCsv, FILE_READ | FILE_WRITE | FILE_CSV | FILE_COMMON | FILE_ANSI |
                      FILE_SHARE_READ | FILE_SHARE_WRITE, ',');
         if(h == INVALID_HANDLE) Sleep(50);
      }
      if(h == INVALID_HANDLE) Print("AuraKing: khong mo duoc ", InpResultCsv, " loi ", GetLastError());
      else
      {
         if(FileSize(h) == 0)
            FileWrite(h, "tag", "gross", "tcomm", "comm", "net", "dd_equity_pct", "trades", "win_pct", "pf", "lots",
                      "e1_n", "e1_net", "e2_n", "e2_net", "e3_n", "e3_net", "e4_n", "e4_net", "e5_n", "e5_net");
         FileSeek(h, 0, SEEK_END);
         FileWrite(h, InpResultTag, DoubleToString(gross, 2), DoubleToString(-tcomm, 2), DoubleToString(comm, 2), DoubleToString(net, 2),
                   DoubleToString(TesterStatistics(STAT_EQUITY_DDREL_PERCENT), 2), (int)trades,
                   DoubleToString(win, 1), DoubleToString(TesterStatistics(STAT_PROFIT_FACTOR), 3),
                   DoubleToString(lots, 2),
                   eTr[1], DoubleToString(eNet[1], 0), eTr[2], DoubleToString(eNet[2], 0), eTr[3], DoubleToString(eNet[3], 0),
                   eTr[4], DoubleToString(eNet[4], 0), eTr[5], DoubleToString(eNet[5], 0));
         FileClose(h);
      }
   }
   return net;
}
