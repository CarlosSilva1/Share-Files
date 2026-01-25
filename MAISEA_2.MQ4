//═══════════════════════════════════════════════════════════════════
#property copyright "Mais - Universidade Trader"
#property link      "contato. escolamais@gmail.com"
#property strict
//═══════════════════════════════════════════════════════════════════

enum RISK_LEVEL {
   LOW_AGGRESSIVE = 0,
   MID_AGGRESSIVE = 1,
   HIGH_AGGRESSIVE = 2
};

//═══════════════════════════════════════════════════════════════════
// EXTERNAL PARAMETERS
//═══════════════════════════════════════════════════════════════════
extern bool LotModeAuto = true;
extern double LotSize = 1.0;
extern double LotPerDollar = 333.0;
extern RISK_LEVEL RiskLevel = LOW_AGGRESSIVE;
int TimerCloseTrade = 32;
bool UseTimerTrailing = false;        // ✅ Ativa/Desativa timer do trailing
bool ReverseTrade = true;
extern int TakeProfit = 5000;
extern int StopLoss = 3000;

//═══════════════════════════════════════════════════════════════════
// TRAILING STOP PARAMETERS - 5 LEVELS SYSTEM
//═══════════════════════════════════════════════════════════════════
bool UseThreeLevelTrailing = true;     // ✅ Usa sistema de 5 níveis
int TrailingStop1 = 300;               // Nível 1: Ativa Breakeven (pts)
int TrailingStop2 = 500;               // Nível 2: Inicia Congelamento (pts)
int TrailingStop3 = 700;               // Nível 3: Retoma Trailing P2P (pts)
int TrailingStop4 = 1000;              // Nível 4: Segundo Congelamento (pts)
int TrailingStop5 = 1300;              // Nível 5: Ativa Sistema de Gaps (pts)
int TrailStep = 200;                   // Tamanho do Gap no Nível 5 (pts)

//═══════════════════════════════════════════════════════════════════
// OLD TRAILING PARAMETERS (para sistema de 1 nível)
//═══════════════════════  ═══════════════════════════════════════════
int TrailStop = 400;
int TrailingStart = 200;
bool TrailActive = true;
bool UseBreakeven = false;              // ✅ Ativa/Desativa breakeven automático

//═══════════════════════════════════════════════════════════════════
// DISPLAY & CONTROL PARAMETERS
//═══════════════════════════════════════════════════════════════════
bool Display = true;
int CounterSkipCandle = 3;
int NrOrders = 1;
int MagicNumber = 1001;
bool EnableTime = false;
int OpenHourTrade = 9;
int OpenMinTrade = 0;
int CloseHourTrade = 17;
int CloseMinTrade = 0;
string EAName = "";
int size = 10;
color colorcode = Blue;

//═══════════════════════════════════════════════════════════════════
// LOGO HD PARAMETERS
//═══════════════════════════════════════════════════════════════════
input bool    Logo_Enable = true;              // Enable MAIS HD Logo
input bool    Logo_Transparent_BG = true;      // Transparent Background
input int     Logo_X_Distance = 10;            // X Distance (pixels)
input int     Logo_Y_Distance = 10;            // Y Distance (pixels)
input int     Logo_Corner = CORNER_LEFT_UPPER; // Chart Corner Position

//═══════════════════════════════════════════════════════════════════
// BOLLINGER BANDS PARAMETERS
//═══════════════════════════════════════════════════════════════════
int period = 25;
double deviation = 2.0;
int appliedPrice = PRICE_CLOSE;
int shift = 0;

//═══════════════════════════════════════════════════════════════════
// 🔐 SECURITY & LICENSE - CONFIGURAÇÃO SIMPLIFICADA
//═══════════════════════════════════════════════════════════════════
//string broker_name = "XM Global Limited";
string broker_name = "Tickmill Ltd";
int acc = 2090905212;
datetime DataExpiracao = D'15.10.2027 23:59';

bool sys_active = false;
int check_counter = 0;
datetime last_check = 0;
int random_seed = 0;
int NumOfTrades;

//═══════════════════════════════════════════════════════════════════
// GLOBAL VARIABLES
//═══════════════════════════════════════════════════════════════════
double Spread, PriceBandHigh, PriceBandMid, PriceBandLow;
bool Buy, Sell, TradeTimeOk;
int ticket, ticketb, tickets;
double ilot, lots, LotMult;
double TakeBuy, TakeSell, StopBuy, StopSell;
double vcHigh, vcLow;
double slip = 3.0;
string License;
int CounterCandle;
double CurrentDD;

bool g_IsNewCandle = false;
bool IsNewCandleH1 = false;
datetime CandleH1 = 0;

bool trigger1, trigger2, step1, step2, step3, step4;
bool c1, c2;
bool LatchBuy, LatchSell;

datetime LastOrderTime = 0;
int LastOrderTicket = 0;
bool OrderBeingPlaced = false;
int MinSecondsBetweenOrders = 5;

//════  ══════════════════════════════════════════════════════════════
// ESTRUTURA DE DADOS PARA TRAILING VIRTUAL
//═══════════════════════════════════════════════════════════════════
struct TrailingData
{
   int ticket;
   double maxVirtualSL;
   datetime orderOpenTime;
   bool initialized;
};

TrailingData g_TrailingData[];

//═══════════════════════════════════════════════════════════════════
// 🔐 FUNÇÕES DE SEGURANÇA
//═══════════════════════════════════════════════════════════════════

int GenerateHash(int num)
{
   int hash = num;
   hash = ((hash >> 16) ^ hash) * 0x45d9f3b;
   hash = ((hash >> 16) ^ hash) * 0x45d9f3b;
   hash = (hash >> 16) ^ hash;
   return(hash);
}

int DecryptAccount()
{
   return(acc);
}

string DecryptBroker()
{
   if(IsTesting())
   {
      return(AccountCompany());
   }
   return(broker_name);
}

bool SecurityCheck(int level = 0)
{
   int expected_account = DecryptAccount();
   if(AccountNumber() != expected_account)
   {
      if(level > 0) 
      {
         Print("❌ [SEC-001] Conta inválida");
         Print("   Esperado: ", expected_account);
         Print("   Atual:  ", AccountNumber());
      }
      return(false);
   }
   
   if(TimeCurrent() > DataExpiracao)
   {
      if(level > 0) 
      {
         Print("❌ [SEC-002] Licença expirada");
         Print("   Expira em: ", TimeToString(DataExpiracao, TIME_DATE));
         Print("   Data atual: ", TimeToString(TimeCurrent(), TIME_DATE));
      }
      return(false);
   }
   
   if(!  IsTesting())
   {
      string expected_broker = DecryptBroker();
      string current_broker = AccountCompany();
      
      if(current_broker != expected_broker)
      {
         if(level > 0)
         {
            Print("❌ [SEC-003] Broker não confere");
            Print("   Esperado: \"", expected_broker, "\"");
            Print("   Atual:  \"", current_broker, "\"");
         }
         return(false);
      }
   }
   
   check_counter++;
   if(check_counter % 100 == 0)
   {
      int hash_check = GenerateHash(expected_account);
      if(hash_check == 0)
      {
         if(level > 0) Print("❌ [SEC-004] Hash inválido");
         return(false);
      }
   }
   
   int time_diff = (int)(TimeCurrent() - last_check);
   if(last_check > 0 && time_diff > 300)
   {
      if(MathRand() % 10 == 0)
      {
         if(level > 0) Print("❌ [SEC-005] Timeout detectado");
         return(false);
      }
   }
   
   last_check = TimeCurrent();
   return(true);
}

bool QuietCheck()
{
   return(SecurityCheck(0));
}

bool VerboseCheck()
{
   return(SecurityCheck(1));
}

bool IsDebuggerPresent()
{
   static datetime last_time = 0;
   datetime current_time = TimeCurrent();
   
   if(last_time == 0)
   {
      last_time = current_time;
      return(false);
   }
   
   if(current_time - last_time > 10)
   {
      int rand_check = MathRand() % 20;
      if(rand_check == 0)
      {
         Print("❌ [SEC-DEBUG] Anomalia temporal detectada");
         return(true);
      }
   }
   
   last_time = current_time;
   return(false);
}

void InitSecurity()
{
   random_seed = (int)TimeLocal();
   MathSrand(random_seed);
   check_counter = 0;
   last_check = TimeCurrent();
   sys_active = VerboseCheck();
}

bool ValidateRuntime()
{
   return(sys_active);
}

//═══════════════════════════════════════════════════════════════════
// FUNÇÕES DE GERENCIAMENTO DE DADOS DE TRAILING
//═══════════════════════════════════════════════════════════════════
void InitTrailingData()
{
   ArrayResize(g_TrailingData, 0);
   ArrayResize(g_TrailingData, 10);
   
   for(int j = 0; j < 10; j++)
   {
      g_TrailingData[j].ticket = 0;
      g_TrailingData[j].maxVirtualSL = 0;
      g_TrailingData[j].orderOpenTime = 0;
      g_TrailingData[j].initialized = false;
   }
}

int GetTrailingDataIndex(int tk)
{
   if(!  sys_active) return(-1);
   
   for(int i = 0; i < ArraySize(g_TrailingData); i++)
   {
      if(g_TrailingData[i].initialized && g_TrailingData[i].ticket == tk)
      {
         return(i);
      }
   }
   
   for(int i1 = 0; i1 < ArraySize(g_TrailingData); i1++)
   {
      if(!  g_TrailingData[i1].initialized)
      {
         if(OrderSelect(tk, SELECT_BY_TICKET))
         {
            g_TrailingData[i1].ticket = tk;
            g_TrailingData[i1].maxVirtualSL = 0;
            g_TrailingData[i1].orderOpenTime = OrderOpenTime();
            g_TrailingData[i1]. initialized = true;
            return(i1);
         }
      }
   }
   
   int oldSize = ArraySize(g_TrailingData);
   int newSize = oldSize + 5;
   ArrayResize(g_TrailingData, newSize);
   
   for(int i2 = oldSize; i2 < newSize; i2++)
   {
      g_TrailingData[i2]. ticket = 0;
      g_TrailingData[i2].maxVirtualSL = 0;
      g_TrailingData[i2].orderOpenTime = 0;
      g_TrailingData[i2].initialized = false;
   }
   
   if(OrderSelect(tk, SELECT_BY_TICKET))
   {
      g_TrailingData[oldSize].ticket = tk;
      g_TrailingData[oldSize].maxVirtualSL = 0;
      g_TrailingData[oldSize].orderOpenTime = OrderOpenTime();
      g_TrailingData[oldSize].initialized = true;
      return(oldSize);
   }
   
   return(-1);
}

void CleanupTrailingData()
{
   if(! sys_active) return;
   
   for(int i = 0; i < ArraySize(g_TrailingData); i++)
   {
      if(g_TrailingData[i]. initialized)
      {
         bool orderExists = false;
         
         for(int j = 0; j < OrdersTotal(); j++)
         {
            if(OrderSelect(j, SELECT_BY_POS, MODE_TRADES))
            {
               if(OrderTicket() == g_TrailingData[i].ticket)
               {
                  orderExists = true;
                  break;
               }
            }
         }
         
         if(!orderExists)
         {
            g_TrailingData[i]. ticket = 0;
            g_TrailingData[i].maxVirtualSL = 0;
            g_TrailingData[i].orderOpenTime = 0;
            g_TrailingData[i].initialized = false;
         }
      }
   }
}

void ResetAllTrailingData()
{
   for(int i = 0; i < ArraySize(g_TrailingData); i++)
   {
      g_TrailingData[i].ticket = 0;
      g_TrailingData[i].maxVirtualSL = 0;
      g_TrailingData[i].orderOpenTime = 0;
      g_TrailingData[i].initialized = false;
   }
}

//═══════════════════════════════════════════════════════════════════
// TRAILING LINE MANAGEMENT
//═══════════════════════════════════════════════════════════════════
string TrailingLineName(int tk)
{
   return("TSL_" + IntegerToString(tk));
}

void CreateOrUpdateTrailingLine(int tk, double price, color clr)
{
   string name = TrailingLineName(tk);
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(name, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   }
   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

void DeleteTrailingLine(int tk)
{
   string name = TrailingLineName(tk);
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(name);
}

bool IsTicketOpen(int tk)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!  OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderTicket() == tk)
         return(true);
   }
   return(false);
}

void SyncTrailingLinesWithOpenOrders()
{
   int total = ObjectsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      string oname = ObjectName(i);
      if(StringFind(oname, "TSL_", 0) == 0)
      {
         string sTicket = StringSubstr(oname, 4);
         int tkNum = (int)StrToInteger(sTicket);

         if(tkNum <= 0 || !  IsTicketOpen(tkNum))
         {
            ObjectDelete(oname);
         }
      }
   }
}

void CleanupAllTrailingLines()
{
   int total = ObjectsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      string oname = ObjectName(i);
      if(StringFind(oname, "TSL_", 0) == 0)
      {
         ObjectDelete(oname);
      }
   }
}

//═══════════════════════════════════════════════════════════════════
// PROTEÇÃO CONTRA MÚLTIPLAS ORDENS
//═══════════════════════════════════════════════════════════════════

bool CanOpenNewOrder()
{
   if(!ValidateRuntime()) return(false);
   
   if(OrderBeingPlaced)
   {
      Print("❌ Ordem já está sendo processada. Aguarde.");
      return(false);
   }
   
   int timeSinceLastOrder = (int)(TimeCurrent() - LastOrderTime);
   if(timeSinceLastOrder < MinSecondsBetweenOrders && LastOrderTime > 0)
   {
      Print("❌ Aguarde ", MinSecondsBetweenOrders - timeSinceLastOrder, "s para abrir nova ordem.");
      return(false);
   }
   
   RefreshRates();
   
   return(true);
}


//═══════════════════════════════════════════════════════════════════
// COUNT FUNCTIONS
//═══════════════════════════════════════════════════════════════════
int CountTrades()
{
   if(!sys_active) return(0);
   
   int count = 0;
   for(int trade = OrdersTotal() - 1; trade >= 0; trade--)
   {
      if(!OrderSelect(trade, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderType() == OP_SELL || OrderType() == OP_BUY)
         count++;
   }
   return(count);
}

int CountBuyTrades()
{
   if(!sys_active) return(0);
   
   int count = 0;
   for(int trade = OrdersTotal() - 1; trade >= 0; trade--)
   {
      if(!OrderSelect(trade, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderType() == OP_BUY)
         count++;
   }
   return(count);
}

int CountSellTrades()
{
   if(!sys_active) return(0);
   
   int count = 0;
   for(int trade = OrdersTotal() - 1; trade >= 0; trade--)
   {
      if(!OrderSelect(trade, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderType() == OP_SELL)
         count++;
   }
   return(count);
}

//═══════════════════════════════════════════════════════════════════
// PROFIT CALCULATIONS
//═══════════════════════════════════════════════════════════════════
double CalculateProfitAll()
{
   if(!sys_active) return(0.0);
   
   double Profit = 0;
   for(int cnt = OrdersTotal() - 1; cnt >= 0; cnt--)
   {
      if(!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderType() == OP_BUY || OrderType() == OP_SELL)
         Profit += OrderProfit() + OrderSwap() + OrderCommission();
   }
   return(Profit);
}

double CalculateBuyProfit()
{
   if(!sys_active) return(0.0);
   
   double Profit = 0;
   for(int cnt = OrdersTotal() - 1; cnt >= 0; cnt--)
   {
      if(!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderType() == OP_BUY)
         Profit += OrderProfit() + OrderSwap() + OrderCommission();
   }
   return(Profit);
}

double CalculateSellProfit()
{
   if(!sys_active) return(0.0);
   
   double Profit = 0;
   for(int cnt = OrdersTotal() - 1; cnt >= 0; cnt--)
   {
      if(!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderType() == OP_SELL)
         Profit += OrderProfit() + OrderSwap() + OrderCommission();
   }
   return(Profit);
}

//═══════════════════════════════════════════════════════════════════
// FIND LAST PRICES
//═══════════════════════════════════════════════════════════════════
double FindLastBuyPrice()
{
   if(!sys_active) return(0.0);
   
   double oldorderopenprice = 0;
   int ticketnumber = 0;
   
   for(int cnt = OrdersTotal() - 1; cnt >= 0; cnt--)
   {
      if(!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderType() == OP_BUY)
      {
         int oldticketnumber = OrderTicket();
         if(oldticketnumber > ticketnumber)
         {
            oldorderopenprice = OrderOpenPrice();
            ticketnumber = oldticketnumber;
         }
      }
   }
   return(oldorderopenprice);
}

double FindLastSellPrice()
{
   if(!sys_active) return(0.0);
   
   double oldorderopenprice = 0;
   int ticketnumber = 0;
   
   for(int cnt = OrdersTotal() - 1; cnt >= 0; cnt--)
   {
      if(!OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderType() == OP_SELL)
      {
         int oldticketnumber = OrderTicket();
         if(oldticketnumber > ticketnumber)
         {
            oldorderopenprice = OrderOpenPrice();
            ticketnumber = oldticketnumber;
         }
      }
   }
   return(oldorderopenprice);
}

//═══════════════════════════════════════════════════════════════════
// OPEN PENDING ORDER
//═══════════════════════════════════════════════════════════════════
int OpenPendingOrder(int pType, double pLots, double pLevel, int sp, double pr, int sl, int tp, string pComment, int pMagic, int pDatetime, color pColor)
{
   if(!sys_active) return(0);
   
   int localTicket = 0;
   int err = 0;
   int NumberOfTries = 100;
   
   for(int c = 0; c < NumberOfTries; c++)
   {
      RefreshRates();
      
      if(pType == 0)
      {
         localTicket = OrderSend(Symbol(), OP_BUY, pLots, Ask, sp, StopLong(Bid, sl), TakeLong(Ask, tp), pComment, pMagic, pDatetime, pColor);
      }
      else if(pType == 1)
      {
         localTicket = OrderSend(Symbol(), OP_SELL, pLots, Bid, sp, StopShort(Ask, sl), TakeShort(Bid, tp), pComment, pMagic, pDatetime, pColor);
      }
      
      err = GetLastError();
      
      if(err == 0)
         break;
         
      if(!(err == 4 || err == 137 || err == 146 || err == 136))
         break;
         
      Sleep(1000);
   }
   
   return(localTicket);
}

double StopLong(double price, int stop)
{
   if(!sys_active) return(0.0);
   
   if(stop == 0)
      return(0);
   else
      return(price - stop * Point);
}

double StopShort(double price, int stop)
{
   if(!sys_active) return(0.0);
   
   if(stop == 0)
      return(0);
   else
      return(price + stop * Point);
}

double TakeLong(double price, int stop)
{
   if(!sys_active) return(0.0);
   
   if(stop == 0)
      return(0);
   else
      return(price + stop * Point);
}

double TakeShort(double price, int stop)
{
   if(!sys_active) return(0.0);
   
   if(stop == 0)
      return(0);
   else
      return(price - stop * Point);
}

//═══════════════════════════════════════════════════════════════════
// CLOSE ALL ORDERS
//═══════════════════════════════════════════════════════════════════
void CloseAllSymb()
{
   if(!sys_active) return;
   
   int total = OrdersTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS))
         continue;
         
      if(OrderSymbol() != Symbol())
         continue;
         
      if(OrderMagicNumber() != MagicNumber)
         continue;

      bool result = false;
      int type = OrderType();

      switch(type)
      {
         case OP_BUY:  
            result = OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(), MODE_BID), 5, CLR_NONE);
            if(result)
               DeleteTrailingLine(OrderTicket());
            break;

         case OP_SELL:  
            result = OrderClose(OrderTicket(), OrderLots(), MarketInfo(OrderSymbol(), MODE_ASK), 5, CLR_NONE);
            if(result)
               DeleteTrailingLine(OrderTicket());
            break;

         case OP_BUYLIMIT: 
         case OP_BUYSTOP:
         case OP_SELLLIMIT:
         case OP_SELLSTOP:  
            result = OrderDelete(OrderTicket());
            break;
      }
      
      Sleep(100);
   }
   
   CleanupAllTrailingLines();
}

//═══════════════════════════════════════════════════════════════════
// DRAW HORIZONTAL LINE
//═══════════════════════════════════════════════════════════════════
void DrawHline(string name, double P, color clr, int WIDTH)
{
   if(ObjectFind(name) != -1)
      ObjectDelete(name);
      
   ObjectCreate(name, OBJ_HLINE, 0, 0, P, 0, 0, 0, 0);
   ObjectSet(name, OBJPROP_COLOR, clr);
   ObjectSet(name, OBJPROP_STYLE, 2);
   ObjectSet(name, OBJPROP_WIDTH, WIDTH);
}

//═══════════════════════════════════════════════════════════════════
// VALUE CHART FUNCTIONS
//═══════════════════════════════════════════════════════════════════
double MVA(int NumBars1, int CBar)
{
   if(!sys_active) return(0.0);
   
   double sum = 0;
   for(int k = CBar; k < NumBars1 + CBar; k++)
   {
      sum += ((High[k] + Low[k]) / 2.0);
   }
   double floatingAxis = (sum / NumBars1);
   return(floatingAxis);
}

double ATR(int NumBars1, int CBar)
{
   if(!sys_active) return(0.0);
   
   double sum = 0;
   for(int k = CBar; k < NumBars1 + CBar; k++)
   {
      sum += (High[k] - Low[k]);
   }
   double volatilityUnit = (0.2 * (sum / NumBars1));
   if(volatilityUnit == 0 || volatilityUnit == 0.0)
   {
      volatilityUnit = 0.00000001;
   }
   return(volatilityUnit);
}

//═══════════════════════════════════════════════════════════════════
// CANDLE DETECTION
//═══════════════════════════════════════════════════════════════════
void VerificaNewCandles()
{
   if(CandleH1 != iTime(_Symbol, PERIOD_H1, 0))
   {
      CandleH1 = iTime(_Symbol, PERIOD_H1, 0);
      IsNewCandleH1 = true;
      g_IsNewCandle = true;
   }
   else
   {
      IsNewCandleH1 = false;
      g_IsNewCandle = false;
   }
}

//═══════════════════════════════════════════════════════════════════
// AUTO LOT CALCULATION
//═══════════════════════════════════════════════════════════════════
double CalculateLotSize(double lotPerDollar, double kMultiplier)
{
   if(!sys_active) return(0.0);
   
   if(lotPerDollar <= 0.0 || kMultiplier <= 0.0)
   {
      Print("Error: lotPerDollar and kMultiplier must be > 0");
      return(0.0);
   }

   double funds = AccountBalance();
   double credit = AccountCredit();
   if(credit > 0.0)
      funds += credit;

   double rawLots = (funds / lotPerDollar) * 0.01 * kMultiplier;

   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);

   if(minLot <= 0.0)
      minLot = 0.01;
   if(maxLot <= 0.0)
      maxLot = 100.0;
   if(lotStep <= 0.0)
      lotStep = 0.01;

   double calculatedLots = MathFloor(rawLots / lotStep) * lotStep;
   int stepDigits = (int)MathMax(0, MathRound(-MathLog10(lotStep)));
   calculatedLots = NormalizeDouble(calculatedLots, stepDigits);

   if(calculatedLots < minLot)
      calculatedLots = minLot;
   if(calculatedLots > maxLot)
      calculatedLots = maxLot;
   if(calculatedLots <= 0.0 || !   MathIsValidNumber(calculatedLots))
      return(0.0);

   return(calculatedLots);
}
// ADICIONE ESTAS FUNÇÕES NO FINAL DO ARQUIVO (após linha 1000+)


//═══════════════════════════════════════════════════════════════════
// HD LOGO FUNCTIONS - Include library
//═══════════════════════════════════════════════════════════════════
#include "DrawLogoMAIS_HD.mqh"
   

//═══════════════════════════════════════════════════════════════════
// 🔐 INITIALIZATION
//═══════════════════════════════════════════════════════════════════
int init()
{
   InitSecurity();
   
   if(!   VerboseCheck())
   {
      Alert("*********************  Acesso Negado - Contate o Suporte  *********************");
      ExpertRemove();
      return(INIT_FAILED);
   }

   HideTestIndicators(true);
   InitTrailingData();
   
   if(Period() != PERIOD_H1)
   {
      Alert("EA Foi Anexado TimeFrame Errado Por Favor mude para o Time Frame H1.");
   }

   
   Print("✅ EA Inicializado com Sucesso - Proteção Ativa");
   Print("📅 Licença válida até: ", TimeToString(DataExpiracao, TIME_DATE));
  
   // Initialize HD Logo
   DrawLogoMAIS_HD();




   return(INIT_SUCCEEDED);
}

//═══════════════════════════════════════════════════════════════════
// DEINITIALIZATION
//═══════════════════════════════════════════════════════════════════
int deinit()
{
   CleanupAllTrailingLines();
   ResetAllTrailingData();
   
   DeleteLogoMAIS_HD();
  
   
   Print("🔴 EA Desanexado - Sistema Desligado");
   
   return(0);
}

//═══════════════════════════════════════════════════════════════════
// 🔐 MAIN START FUNCTION
//════════════════  ══════════════════════════════════════════════════
int start()
{
   if(!ValidateRuntime())
   {
      Alert("*********************  Erro de Segurança - EA Desativado  *********************");
      ExpertRemove();
      return(0);
   }

   if(Bars < 200)
   {
      return(0);
   }

   if(TimeCurrent() > DataExpiracao)
   {
      Alert("*********************  Licença Expirada - Contate o Suporte  *********************");
      ExpertRemove();
      return(0);
   }

   if(Period() != PERIOD_H1)
   {
      Alert("EA Foi Anexado ao TimeFrame Errado Por Favor mude para o TimeFrame H1.");
   }

   License = "Active";

   VerificaNewCandles();

   

   int ActualHour = Hour() * 100 + Minute();
   int SetOpenHour = OpenHourTrade * 100 + OpenMinTrade;
   int SetCloseHour = CloseHourTrade * 100 + CloseMinTrade;

   if(ActualHour >= SetOpenHour && ActualHour <= SetCloseHour && EnableTime)
   {
      TradeTimeOk = true;
   }
   else
   {
      TradeTimeOk = false;
   }

   if(!    EnableTime)
   {
      TradeTimeOk = true;
   }

   Spread = MarketInfo(Symbol(), MODE_SPREAD);

   PriceBandHigh = iBands(NULL, 0, period, deviation, 0, appliedPrice, MODE_UPPER, shift);
   PriceBandMid = iBands(NULL, 0, period, deviation, 0, appliedPrice, MODE_MAIN, shift);
   PriceBandLow = iBands(NULL, 0, period, deviation, 0, appliedPrice, MODE_LOWER, shift);

   if(IsNewCandleH1 || true)
   {
      uint VC_NumBars = 5;
      uint Compute_Candle = 1;
      double floatingAxis = MVA(VC_NumBars, Compute_Candle);
      double volatilityUnit = ATR(VC_NumBars, Compute_Candle);

      vcHigh = (High[Compute_Candle] - floatingAxis) / volatilityUnit;
      vcLow = (Low[Compute_Candle] - floatingAxis) / volatilityUnit;
   }

   //═══════════════════════════════════════════════════════════════
   // ENTRY SIGNALS
   //═══════════════════════════════════════════════════════════════
   if(ReverseTrade == false)
   {
      if(CountBuyTrades() == 0 && Close[0] < PriceBandLow && !    trigger1)
      {
         Buy = true;
         trigger1 = true;
      }
      else
      {
         Buy = false;
      }

      if(trigger1 && CountBuyTrades() == 1)
         step1 = true;

      if(step1 && CountBuyTrades() == 0)
      {
         CounterCandle = 0;
         step1 = false;
         step3 = true;
      }

      if(step3 && Close[0] >= PriceBandMid)
      {
         trigger1 = false;
         Buy = false;
         step3 = false;
      }

      if(CountSellTrades() == 0 && Close[0] > PriceBandHigh && !  trigger2)
      {
         Sell = true;
         trigger2 = true;
      }
      else
      {
         Sell = false;
      }

      if(trigger2 && CountSellTrades() == 1)
         step2 = true;

      if(step2 && CountSellTrades() == 0)
      {
         CounterCandle = 0;
         step2 = false;
         step4 = true;
      }

      if(step4 && Close[0] <= PriceBandMid)
      {
         trigger2 = false;
         Sell = false;
         step4 = false;
      }
   }

   if(ReverseTrade == true)
   {
      if(CountSellTrades() == 0 && Close[0] < PriceBandLow && !    trigger1)
      {
         Sell = true;
         trigger1 = true;
      }
      else
      {
         Sell = false;
      }

      if(trigger1 && CountSellTrades() == 1)
         step2 = true;

      if(step2 && CountSellTrades() == 0)
      {
         CounterCandle = 0;
         step2 = false;
         step4 = true;
      }

      if(step4 && Close[0] >= PriceBandMid)
      {
         trigger1 = false;
         Sell = false;
         step4 = false;
      }

      if(CountBuyTrades() == 0 && Close[0] > PriceBandHigh && !trigger2)
      {
         Buy = true;
         trigger2 = true;
      }
      else
      {
         Buy = false;
      }

      if(trigger2 && CountBuyTrades() == 1)
         step1 = true;

      if(step1 && CountBuyTrades() == 0)
      {
         CounterCandle = 0;
         step1 = false;
         step3 = true;
      }

      if(step3 && Close[0] <= PriceBandMid)
      {
         trigger2 = false;
         Buy = false;
         step3 = false;
      }
   }

   //═══════════════════════════════════════════════════════════════
   // ENTRY LOGIC WITH LATCH
   //═══════════════════════════════════════════════════════════════
   if(CountBuyTrades() == 0 && Buy == true && !    LatchBuy)
   {
      Buy = true;
      LatchBuy = true;
      CounterCandle = 0;

      ObjectCreate(0, IntegerToString(Bars), OBJ_ARROW, 0, Time[0], Close[0], 0, Blue);
      ObjectSetInteger(0, IntegerToString(Bars), OBJPROP_ARROWCODE, 225);
      ObjectSetInteger(0, IntegerToString(Bars), OBJPROP_COLOR, Blue);
   }

   if(CountBuyTrades() == 1)
      LatchBuy = false;

   if(CountSellTrades() == 0 && Sell == true && !  LatchSell)
   {
      Sell = true;
      LatchSell = true;
      CounterCandle = 0;

      ObjectCreate(0, IntegerToString(Bars), OBJ_ARROW, 0, Time[0], Close[0], 0, Red);
      ObjectSetInteger(0, IntegerToString(Bars), OBJPROP_ARROWCODE, 226);
      ObjectSetInteger(0, IntegerToString(Bars), OBJPROP_COLOR, Red);
   }

   if(CountSellTrades() == 1)
      LatchSell = false;

   if(CountTrades() > 0 && CounterCandle == 0)
      CounterCandle = CounterCandle + 1;

   if(!    g_IsNewCandle && !    c1)
   {
      c1 = true;
      c2 = false;
   }

   if(c1 && g_IsNewCandle)
   {
      c1 = false;
      c2 = true;
      CounterCandle = CounterCandle + 1;
   }

   int MaxCounterCandle = 10 - CounterSkipCandle;

   if(CounterCandle >= (CounterSkipCandle + MaxCounterCandle))
      CounterCandle = CounterSkipCandle + MaxCounterCandle;

   //═══════════════════════════════════════════════════════════════
   // OPEN FIRST BUY ORDER
   //═══════════════════════════════════════════════════════════════
   if(CountBuyTrades() == 0 && Buy && TradeTimeOk)
   {
      if(!    CanOpenNewOrder())
      {
         Buy = false;
         return(0);
      }
      
      OrderBeingPlaced = true;
      
      if(LotModeAuto)
      {
         if(RiskLevel == LOW_AGGRESSIVE)
            LotMult = 1;
         if(RiskLevel == MID_AGGRESSIVE)
            LotMult = 1.1;
         if(RiskLevel == HIGH_AGGRESSIVE)
            LotMult = 1.5;

         lots = CalculateLotSize(LotPerDollar, LotMult);
      }
      else
      {
         lots = LotSize;
      }

      string NumOfTrades = IntegerToString(CountTrades());
      ticketb = OpenPendingOrder(0, lots, Ask, (int)slip, Bid, StopLoss, TakeProfit, EAName + "-" + NumOfTrades, MagicNumber, 0, Lime);
      
      if(ticketb > 0)
      {
         LastOrderTime = TimeCurrent();
         LastOrderTicket = ticketb;
         Buy = false;
         Print("✅ Ordem BUY #", ticketb, " aberta com sucesso às ", TimeToString(TimeCurrent()));
      }
      else
      {
         Print("❌ ERRO ao abrir ordem BUY:  ", GetLastError());
      }
      
      OrderBeingPlaced = false;
      Sleep(1000);
      return(0);
   }

   if(CountBuyTrades() > 0 && Buy)
   {
      Buy = false;
   }

   //═══════════════════════════════════════════════════════════════
   // OPEN FIRST SELL ORDER
   //═══════════════════════════════════════════════════════════════
   if(CountSellTrades() == 0 && Sell && TradeTimeOk)
   {
      if(!  CanOpenNewOrder())
      {
         Sell = false;
         return(0);
      }
      
      OrderBeingPlaced = true;
      
      if(LotModeAuto)
      {
         if(RiskLevel == LOW_AGGRESSIVE)
            LotMult = 1;
         if(RiskLevel == MID_AGGRESSIVE)
            LotMult = 1.1;
         if(RiskLevel == HIGH_AGGRESSIVE)
            LotMult = 1.5;

         lots = CalculateLotSize(LotPerDollar, LotMult);
      }
      else
      {
         lots = LotSize;
      }

      NumOfTrades = IntegerToString(CountTrades());
      tickets = OpenPendingOrder(1, lots, Bid, (int)slip, Ask, StopLoss, TakeProfit, EAName + "-" + NumOfTrades, MagicNumber, 0, HotPink);
      
      if(tickets > 0)
      {
         LastOrderTime = TimeCurrent();
         LastOrderTicket = tickets;
         Sell = false;
         Print("✅ Ordem SELL #", tickets, " aberta com sucesso às ", TimeToString(TimeCurrent()));
      }
      else
      {
         Print("❌ ERRO ao abrir ordem SELL: ", GetLastError());
      }
      
      OrderBeingPlaced = false;
      Sleep(1000);
      return(0);
   }

   if(CountSellTrades() > 0 && Sell)
   {
      Sell = false;
   }
   
   //═══════════════════════════════════════════════════════════════
   // TRAILING STOP MANAGEMENT
   //═══════════════════════════════════════════════════════════════
   if(CountTrades() > 0 && TrailActive)
   {
      if(UseThreeLevelTrailing)
         ManageTrailingThreeLevels();
      else
         ManageTrailing();
   }

   if(CountTrades() == 0)
   {
      ObjectDelete("SL Sell");
      ObjectDelete("SL Buy");
      ObjectDelete("TP Buy");
      ObjectDelete("TP Sell");
      CleanupAllTrailingLines();
      ResetAllTrailingData();
   }
   else
   {
      CleanupTrailingData();
   }

   //═══════════════════════════════════════════════════════════════
   // TP/SL FOR SINGLE ORDERS
   //═══════════════════════════════════════════════════════════════
   bool Buy_Reach = false, Sell_Reach = false;

   if(CountBuyTrades() == 1)
   {
      TakeBuy = FindLastBuyPrice() + (TakeProfit * Point);
      StopBuy = FindLastBuyPrice() - (StopLoss * Point);
      DrawHline("TP Buy", TakeBuy, clrBlue, 1);
      DrawHline("SL Buy", StopBuy, clrRed, 1);
   }

   if((CountBuyTrades() == 1 && Ask > TakeBuy && CalculateBuyProfit() > 0) || Buy_Reach)
   {
      Buy_Reach = true;
      CloseAllSymb();
   }

   if((CountBuyTrades() == 1 && Ask < StopBuy && CalculateBuyProfit() < 0) || Buy_Reach)
   {
      Buy_Reach = true;
      CloseAllSymb();
   }

   if(Buy_Reach && CountBuyTrades() == 0)
   {
      Buy_Reach = false;
      ObjectDelete("TP Buy");
      ObjectDelete("SL Buy");
   }

   if(CountSellTrades() == 1)
   {
      TakeSell = FindLastSellPrice() - (TakeProfit * Point);
      StopSell = FindLastSellPrice() + (StopLoss * Point);
      DrawHline("TP Sell", TakeSell, clrBlue, 1);
      DrawHline("SL Sell", StopSell, clrRed, 1);
   }

   if((CountSellTrades() == 1 && Bid < TakeSell && CalculateSellProfit() > 0) || Sell_Reach)
   {
      Sell_Reach = true;
      CloseAllSymb();
   }

   if((CountSellTrades() == 1 && Bid > StopSell && CalculateSellProfit() < 0) || Sell_Reach)
   {
      Sell_Reach = true;
      CloseAllSymb();
   }

   if(Sell_Reach && CountSellTrades() == 0)
   {
      Sell_Reach = false;
      ObjectDelete("TP Sell");
      ObjectDelete("SL Sell");
   }

   DisplayPanel();

   return(0);
}

//═══════════════════════════════════════════════════════════════════
// DISPLAY PANEL
//═══════════════════════════════════════════════════════════════════
void DisplayPanel()
{
   if(!     sys_active) return;
   
   if(Display)
      Comment("Mais - Universidade Trader"
              + "\n"
              + "MaisEbullBlackV20 PRO - 5 NÍVEIS"
              + "\n"
              + "________________________________"
              + "\n"
              + "Broker:                  " + AccountCompany()
              + "\n"
              + "Brokers Time:       " + TimeToStr(TimeCurrent(), TIME_DATE | TIME_SECONDS)
              + "\n"
              + "________________________________"
              + "\n"
              + "Name:               " + AccountName()
              + "\n"
              + "Account Balance:    " + DoubleToStr(AccountBalance(), 2)
              + "\n"
              + "Account Equity:     " + DoubleToStr(AccountEquity(), 2)
              + "\n"
              + "_______________________________"
              + "\n"
              + "ilot :                   " + DoubleToStr(ilot, 2)
              + "\n"
              + "_______________________________"
              + "\n"
              + "CountTrades:             " + CountTrades()
              + "\n"
              + "CountBuyTrades:     " + CountBuyTrades()
              + "\n"
              + "CountSellTrades:        " + CountSellTrades()
              + "\n"
              + "🔐 License:         " + License
              + "\n"
              + "_______________________________"
             
              + "\n");
}

//═══════════════════════════════════════════════════════════════════
// ✅ TRAILING STOP - SINGLE LEVEL
//═══════════════════════════════════════════════════════════════════
void ManageTrailing()
{
   if(!   sys_active) return;
   
   bool anyOpen = false;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!   OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL)
         continue;
         
      anyOpen = true;

      int ordTicket = OrderTicket();
      double priceOpen = OrderOpenPrice();
      double slCurrent = OrderStopLoss();
      double tpCurrent = OrderTakeProfit();
      datetime timeOpen = OrderOpenTime();

      double priceBid = Bid;
      double priceAsk = Ask;
      double px = (type == OP_BUY) ?   priceBid : priceAsk;

      double profitPts = (type == OP_BUY) ?  (px - priceOpen) / Point : (priceOpen - px) / Point;

      if(profitPts >= TrailingStart && UseBreakeven)
      {
         double beStart = NormalizeDouble(priceOpen, Digits);

         if(type == OP_BUY)
         {
            if(slCurrent < beStart || slCurrent == 0.0)
            {
               if(OrderModify(ordTicket, priceOpen, beStart, tpCurrent, 0, clrGreen))
                  slCurrent = beStart;
            }
         }
         else
         {
            if(slCurrent > beStart || slCurrent == 0.0)
            {
               if(OrderModify(ordTicket, priceOpen, beStart, tpCurrent, 0, clrGreen))
                  slCurrent = beStart;
            }
         }
      }

      double be;
      if(profitPts >= TrailStop)
      {
         be = NormalizeDouble(priceOpen, Digits);
         if(type == OP_BUY)
         {
            if(slCurrent < be)
            {
               if(OrderModify(ordTicket, priceOpen, be, tpCurrent, 0, clrBlue))
                  slCurrent = be;
            }
         }
         else
         {
            if(slCurrent > be || slCurrent == 0.0)
            {
               if(OrderModify(ordTicket, priceOpen, be, tpCurrent, 0, clrRed))
                  slCurrent = be;
            }
         }
      }

      bool trailArmed = (profitPts >= TrailStop);
      be = NormalizeDouble(priceOpen, Digits);

      double vTargetSL = (slCurrent > 0 ?   slCurrent : be);
      double rawTarget;

      if(trailArmed)
      {
         if(type == OP_BUY)
         {
            rawTarget = NormalizeDouble(priceBid - TrailStop * Point, Digits);
            vTargetSL = MathMax(rawTarget, be);
         }
         else
         {
            rawTarget = NormalizeDouble(priceAsk + TrailStop * Point, Digits);
            vTargetSL = MathMin(rawTarget, be);
         }
      }
      else
      {
         vTargetSL = be;
      }

      bool allowCloseByTrailing = true;
      if(UseTimerTrailing)
      {
         allowCloseByTrailing = (TimeCurrent() - timeOpen >= TimerCloseTrade);
      }
      
      double displaySL = vTargetSL;
      
      if(!     allowCloseByTrailing)
      {
         int dataIndex = GetTrailingDataIndex(ordTicket);
         
         if(dataIndex >= 0)
         {
            if(type == OP_BUY)
            {
               if(vTargetSL > g_TrailingData[dataIndex].maxVirtualSL)
               {
                  g_TrailingData[dataIndex].maxVirtualSL = vTargetSL;
               }
               
               displaySL = g_TrailingData[dataIndex].maxVirtualSL;
               if(displaySL < be) displaySL = be;
            }
            else
            {
               if(g_TrailingData[dataIndex].maxVirtualSL == 0 || 
                  vTargetSL < g_TrailingData[dataIndex].maxVirtualSL)
               {
                  g_TrailingData[dataIndex].    maxVirtualSL = vTargetSL;
               }
               
               displaySL = g_TrailingData[dataIndex].maxVirtualSL;
               if(displaySL > be && be > 0) displaySL = be;
            }
         }
      }
      else
      {
         displaySL = vTargetSL;
      }

      color lineColor = !     trailArmed ?   clrBlue : (allowCloseByTrailing ?   clrYellow : clrOrange);
      CreateOrUpdateTrailingLine(ordTicket, displaySL, lineColor);

      if(!   allowCloseByTrailing)
         continue;

      if(trailArmed)
      {
         bool shouldModify = false;
         double newSL = vTargetSL;
         bool breached = false;
         double lotsToClose = 0;
         
         if(type == OP_BUY)
         {
            if(newSL > slCurrent + Point)
            {
               shouldModify = true;
            }
            else
            {
               newSL = slCurrent;
            }
            
            breached = (priceBid <= slCurrent - Point * 0.5);
            
            if(breached)
            {
               lotsToClose = OrderLots();
               if(OrderClose(ordTicket, lotsToClose, Bid, 0, clrYellow))
               {
                  DeleteTrailingLine(ordTicket);
                  continue;
               }
            }

            if(shouldModify)
            {
               if(OrderModify(ordTicket, priceOpen, newSL, tpCurrent, 0, clrYellow))
               {
                  slCurrent = newSL;
               }
            }
         }
         else
         {
            if(slCurrent == 0.0 || newSL < slCurrent - Point)
            {
               shouldModify = true;
            }
            else
            {
               newSL = slCurrent;
            }
            
            breached = (priceAsk >= slCurrent + Point * 0.5);
            
            if(breached)
            {
               lotsToClose = OrderLots();
               if(OrderClose(ordTicket, lotsToClose, Ask, 0, clrYellow))
               {
                  DeleteTrailingLine(ordTicket);
                  continue;
               }
            }
            
            if(shouldModify)
            {
               if(OrderModify(ordTicket, priceOpen, newSL, tpCurrent, 0, clrYellow))
               {
                  slCurrent = newSL;
               }
            }
         }

         if(!     IsTicketOpen(ordTicket))
            DeleteTrailingLine(ordTicket);
      }
   }

   if(!   anyOpen)
   {
      CleanupAllTrailingLines();
      CleanupTrailingData();
   }

   SyncTrailingLinesWithOpenOrders();
}

//═══════════════════════════════════════════════════════════════════
// ✅ TRAILING STOP - FIVE LEVELS (USANDO INPUT PARAMETERS)
//═══════════════════════════════════════════════════════════════════
// 📊 LÓGICA COM OS PARÂMETROS: 
// TrailingStop1 = 300   → Inicia trailing P2P
// TrailingStop2 = 500   → Congela em +199
// TrailingStop3 = 700   → Retoma trailing P2P
// TrailingStop4 = 1000  → Congela em +498
// TrailingStop5 = 1300  → Sistema de GAPS
// TrailStep = 200       → Distância do gap
//═══════════════════════════════════════════════════════════════════

void ManageTrailingThreeLevels()
{
   if(! sys_active) return;
   
   // Validação dos parâmetros
   if(TrailingStop1 <= 0 || TrailingStop2 <= TrailingStop1 || TrailingStop3 <= TrailingStop2 ||
      TrailingStop4 <= TrailingStop3 || TrailingStop5 <= TrailingStop4 || TrailStep <= 0)
   {
      Print("❌ ERRO: Parâmetros de trailing inválidos!");
      Print("   TrailingStop1: ", TrailingStop1);
      Print("   TrailingStop2: ", TrailingStop2);
      Print("   TrailingStop3: ", TrailingStop3);
      Print("   TrailingStop4: ", TrailingStop4);
      Print("   TrailingStop5: ", TrailingStop5);
      Print("   TrailStep:  ", TrailStep);
      return;
   }

   bool anyOpen = false;

   for(int pos = OrdersTotal() - 1; pos >= 0; pos--)
   {
      if(! OrderSelect(pos, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int ordType = OrderType();
      if(ordType != OP_BUY && ordType != OP_SELL)
         continue;
         
      anyOpen = true;

      int ordTicket = OrderTicket();
      double priceOpen = OrderOpenPrice();
      double slCurrent = OrderStopLoss();
      double slOriginal = OrderStopLoss();  // SL original da ordem
      double tpCurrent = OrderTakeProfit();
      datetime timeOpen = OrderOpenTime();

      double priceBid = Bid;
      double priceAsk = Ask;
      
      // Calcula lucro em pontos
      double profitPoints = (ordType == OP_BUY) ? (priceBid - priceOpen) / Point
                                                :  (priceOpen - priceAsk) / Point;

      // Verifica se o timer permite trailing
      bool allowTrail = true;
      if(UseTimerTrailing)
      {
         allowTrail = (TimeCurrent() - timeOpen >= TimerCloseTrade);
      }

      //═══════════════════════════════════════════════════════════
      // 🎨 SISTEMA DE CORES POR NÍVEL
      //═══════════════════════════════════════════════════════════
      color lineColor;
      
      if(UseTimerTrailing && ! allowTrail)
      {
         // Se aguardando timer
         if(profitPoints >= TrailingStop5)
            lineColor = clrMagenta;
         else if(profitPoints >= TrailingStop3)
            lineColor = clrOrange;
         else
            lineColor = clrBlue;
      }
      else
      {
         // Cores por nível de trailing
         if(profitPoints < TrailingStop1)
            lineColor = clrGray;           // 0-299: Cinza (SL Original)
         else if(profitPoints < TrailingStop2)
            lineColor = clrLime;            // 300-499: Verde (Trailing P2P)
         else if(profitPoints < TrailingStop3)
            lineColor = clrGold;            // 500-699: Dourado (CONGELADO +199)
         else if(profitPoints < TrailingStop4)
            lineColor = clrYellow;          // 700-999: Amarelo (Trailing P2P)
         else if(profitPoints < TrailingStop5)
            lineColor = clrOrange;          // 1000-1299: Laranja (CONGELADO +498)
         else
            lineColor = clrOrangeRed;       // 1300+: Vermelho (GAPS -200)
      }

      //═══════════════════════════════════════════════════════════
      // 📊 CÁLCULO DO TRAILING TARGET - USANDO INPUT PARAMETERS
      //═══════════════════════════════════════════════════════════
      double visualTarget = slCurrent;
      
      // 🔴 NÍVEL 0: 0-299 pts → SL ORIGINAL (não modifica)
      if(profitPoints < TrailingStop1)  // profitPoints < 300
      {
         // Mantém SL original - não modifica nada
         visualTarget = slOriginal;
      }
      
      // 🟢 NÍVEL 1: 300-499 pts → TRAILING PONTO A PONTO
      // 300 pts = +0 protegido (breakeven)
      // 499 pts = +199 protegidos
      else if(profitPoints >= TrailingStop1 && profitPoints < TrailingStop2)  // 300 <= profit < 500
      {
         double offset = profitPoints - TrailingStop1;  // 300→0, 301→1, 499→199
         
         if(ordType == OP_BUY)
            visualTarget = priceOpen + offset * Point;
         else
            visualTarget = priceOpen - offset * Point;
            
         visualTarget = NormalizeDouble(visualTarget, Digits);
      }
      
      // 🟡 NÍVEL 2: 500-699 pts → CONGELADO EM +199 PTS
      else if(profitPoints >= TrailingStop2 && profitPoints < TrailingStop3)  // 500 <= profit < 700
      {
         // Congela no valor máximo do nível anterior
         // TrailingStop2 - 1 = 499 pts de lucro
         // 499 - TrailingStop1 = 499 - 300 = 199 pts protegidos
         double frozenOffset = (TrailingStop2 - 1) - TrailingStop1;  // 499 - 300 = 199
         
         if(ordType == OP_BUY)
            visualTarget = priceOpen + frozenOffset * Point;
         else
            visualTarget = priceOpen - frozenOffset * Point;
            
         visualTarget = NormalizeDouble(visualTarget, Digits);
      }
      
      // 🟠 NÍVEL 3: 700-999 pts → RETOMA TRAILING PONTO A PONTO
      // 700 pts → SL em +199 (base do congelamento)
      // 701 pts → SL em +200
      // 999 pts → SL em +498
      else if(profitPoints >= TrailingStop3 && profitPoints < TrailingStop4)  // 700 <= profit < 1000
      {
         double frozenBase = (TrailingStop2 - 1) - TrailingStop1;  // 199 pts (base do congelamento)
         double additionalOffset = profitPoints - TrailingStop3;   // 700→0, 701→1, 999→299
         double totalOffset = frozenBase + additionalOffset;        // 700→199, 999→498
         
         if(ordType == OP_BUY)
            visualTarget = priceOpen + totalOffset * Point;
         else
            visualTarget = priceOpen - totalOffset * Point;
            
         visualTarget = NormalizeDouble(visualTarget, Digits);
      }
      
      // 🔵 NÍVEL 4: 1000-1299 pts → CONGELADO EM +498 PTS
      else if(profitPoints >= TrailingStop4 && profitPoints < TrailingStop5)  // 1000 <= profit < 1300
      {
         // Congela no valor máximo do nível anterior
         // TrailingStop4 - 1 = 999 pts de lucro
         // 199 (base) + (999 - 700) = 199 + 299 = 498 pts protegidos
         double frozenBase = (TrailingStop2 - 1) - TrailingStop1;  // 199
         double maxOffsetLevel3 = (TrailingStop4 - 1) - TrailingStop3;  // 999 - 700 = 299
         double frozenOffset = frozenBase + maxOffsetLevel3;  // 199 + 299 = 498
         
         if(ordType == OP_BUY)
            visualTarget = priceOpen + frozenOffset * Point;
         else
            visualTarget = priceOpen - frozenOffset * Point;
            
         visualTarget = NormalizeDouble(visualTarget, Digits);
      }
      
      // 🔴 NÍVEL 5: 1300+ pts → SISTEMA DE GAPS (mantém TrailStep pts de distância)
      // 1300 pts → SL em 1100 (1300 - 200)
      // 1500 pts → SL em 1300 (1500 - 200)
      // Mantém sempre TrailStep (200) pts de distância do preço atual
      else  // profitPoints >= TrailingStop5 (1300+)
      {
         double gapDistance = TrailStep;  // 200 pts de distância
         double targetOffset = profitPoints - gapDistance;  // Mantém 200 pts de distância
         
         if(ordType == OP_BUY)
            visualTarget = priceOpen + targetOffset * Point;
         else
            visualTarget = priceOpen - targetOffset * Point;
            
         visualTarget = NormalizeDouble(visualTarget, Digits);
      }
      
      //═══════════════════════════════════════════════════════════
      // 🖼️ SISTEMA DE TRAILING VIRTUAL (quando timer ativo)
      //═══════════════════════════════════════════════════════════
      double displayTarget = visualTarget;
      
      if(! allowTrail)
      {
         int dataIndex = GetTrailingDataIndex(ordTicket);
         
         if(dataIndex >= 0)
         {
            if(ordType == OP_BUY)
            {
               if(visualTarget > g_TrailingData[dataIndex].maxVirtualSL)
               {
                  g_TrailingData[dataIndex].maxVirtualSL = visualTarget;
               }
               
               displayTarget = g_TrailingData[dataIndex].maxVirtualSL;
            }
            else  // OP_SELL
            {
               if(g_TrailingData[dataIndex].maxVirtualSL == 0 || 
                  visualTarget < g_TrailingData[dataIndex]. maxVirtualSL)
               {
                  g_TrailingData[dataIndex].maxVirtualSL = visualTarget;
               }
               
               displayTarget = g_TrailingData[dataIndex].maxVirtualSL;
            }
         }
      }
      else
      {
         displayTarget = visualTarget;
      }
      
      // Atualiza linha visual
      CreateOrUpdateTrailingLine(ordTicket, displayTarget, lineColor);

      // Se timer não permitir, não modifica SL real
      if(!allowTrail)
         continue;

      //═══════════════════════════════════════════════════════════
      // ⚙️ MODIFICAÇÃO DO STOP LOSS REAL
      //═══════════════════════════════════════════════════════════
      
      // IMPORTANTE: Nível 0 (0-299) NÃO modifica SL
      if(profitPoints < TrailingStop1)  // profitPoints < 300
      {
         // Não faz nada, mantém SL original
         continue;
      }
      
      double proposedSL = visualTarget;
      bool needModify = false;
      
      // Garante que nunca move SL contra a posição
      if(ordType == OP_BUY)
      {
         // Para BUY: só move SL para cima
         if(proposedSL > slCurrent + Point || slCurrent == 0.0)
         {
            needModify = true;
         }
      }
      else  // OP_SELL
      {
         // Para SELL:  só move SL para baixo
         if(slCurrent == 0.0 || proposedSL < slCurrent - Point)
         {
            needModify = true;
         }
      }

      if(needModify)
      {
         bool modifyResult = OrderModify(ordTicket, priceOpen, proposedSL, tpCurrent, 0, lineColor);
         
         if(modifyResult)
         {
            slCurrent = proposedSL;
            
            // Log detalhado por nível
            string levelName = "";
            double protectedPts = 0;
            
            if(profitPoints < TrailingStop1)  // < 300
            {
               levelName = "NÍVEL 0 (SL Original)";
               protectedPts = 0;
            }
            else if(profitPoints < TrailingStop2)  // 300-499
            {
               levelName = "NÍVEL 1 (Trailing P2P)";
               protectedPts = profitPoints - TrailingStop1;
            }
            else if(profitPoints < TrailingStop3)  // 500-699
            {
               levelName = "NÍVEL 2 (Congelado +199)";
               protectedPts = (TrailingStop2 - 1) - TrailingStop1;  // 199
            }
            else if(profitPoints < TrailingStop4)  // 700-999
            {
               levelName = "NÍVEL 3 (Trailing P2P)";
               double base = (TrailingStop2 - 1) - TrailingStop1;  // 199
               protectedPts = base + (profitPoints - TrailingStop3);
            }
            else if(profitPoints < TrailingStop5)  // 1000-1299
            {
               levelName = "NÍVEL 4 (Congelado +498)";
               double base = (TrailingStop2 - 1) - TrailingStop1;  // 199
               double max3 = (TrailingStop4 - 1) - TrailingStop3;  // 299
               protectedPts = base + max3;  // 498
            }
            else  // 1300+
            {
               levelName = "NÍVEL 5 (Gap -" + IntegerToString(TrailStep) + ")";
               protectedPts = profitPoints - TrailStep;
            }
            
            Print("✅ SL modificado #", ordTicket, " | ", levelName, 
                  " | Lucro: ", DoubleToStr(profitPoints, 0), " pts",
                  " | Protegido: +", DoubleToStr(protectedPts, 0), " pts",
                  " | Novo SL: ", DoubleToStr(proposedSL, Digits));
         }
         else
         {
            Print("❌ Erro ao modificar SL #", ordTicket, " | Error: ", GetLastError());
         }
      }
      
      //═══════════════════════════════════════════════════════════
      // 🎯 VERIFICAÇÃO DE BREACH (violação de SL)
      //═══════════════════════════════════════════════════════════
      bool breached = false;
      
      if(ordType == OP_BUY)
      {
         breached = (priceBid <= slCurrent - Point * 0.5);
      }
      else  // OP_SELL
      {
         breached = (priceAsk >= slCurrent + Point * 0.5);
      }
      
      if(breached && slCurrent > 0)
      {
         double lotsToClose = OrderLots();
         bool closeResult = OrderClose(ordTicket, lotsToClose, 
                                       (ordType == OP_BUY ?  Bid : Ask), 
                                       3, clrRed);
         
         if(closeResult)
         {
            Print("🔴 Ordem #", ordTicket, " fechada por trailing stop | Lucro: ", 
                  DoubleToStr(profitPoints, 0), " pts");
            DeleteTrailingLine(ordTicket);
            continue;
         }
      }

      // Verifica se ordem ainda existe
      if(! IsTicketOpen(ordTicket))
         DeleteTrailingLine(ordTicket);
   }

   // Limpeza se não houver ordens abertas
   if(! anyOpen)
   {
      CleanupAllTrailingLines();
      CleanupTrailingData();
   }

   SyncTrailingLinesWithOpenOrders();
}

//═══════════════════════════════════════════════════════════════════
// 🎉 FIM DO CÓDIGO - EA COMPLETO
//═══════════════════════════════════════════════════════════════════   
   


