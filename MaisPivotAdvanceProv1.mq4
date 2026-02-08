// Bloco 1

//+------------------------------------------------------------------+
//|                                      MaisPivotAdvance_PRO_v3.mq4 |
//|                          Sistema No-Repaint com Stats Avançado   |
//+------------------------------------------------------------------+
#property copyright "Mais Pivot Advance PRO"
#property link      ""
#property version   "3.01"
#property strict
#property indicator_chart_window
#property indicator_buffers 6

//+------------------------------------------------------------------+
//| INPUTS - CONFIGURAÇÕES                                           |
//+------------------------------------------------------------------+
// === Pivôs ===
input int PivotStrength = 20;                // Força do Pivô (barras)
input double ATRMultiplier = 1.5;           // Multiplicador ATR
input int ConfirmCandles = 2;               // Candles de confirmação
input int MaxConfirmCandles = 3;            // Máximo de barras p/ confirmar
input bool RequireCloseBreak = true;        // Exigir quebra de fechamento

// ════════════════════════════════════════════════════════════════
// === FILTROS DE ENTRADA (CONTROLE INDIVIDUAL) ===
// ════════════════════════════════════════════════════════════════
input bool UseTrendFilter = false;          // ⚙️ Ativar Filtro de Tendência EMA
input bool UseATRFilter = false;            // ⚙️ Ativar Filtro de ATR Mínimo
input bool UseTimeFilter = false;           // ⚙️ Ativar Filtro de Horário
input bool UseSpreadFilter = false;         // ⚙️ Ativar Filtro de Spread
input bool UseRSIFilter = false;            // ⚙️ Ativar Filtro de RSI

// === Configurações de Tendência (usado se UseTrendFilter = true) ===
input ENUM_TIMEFRAMES TrendTimeframe = PERIOD_H4;  // Timeframe Tendência
input int TrendEMAPeriod = 200;             // Período EMA Tendência

// === Configurações de ATR (usado se UseATRFilter = true) ===
input int ATRPeriod = 14;                   // Período ATR
input double MinATR = 0.0010;               // ATR Mínimo

// === Configurações de Horário (usado se UseTimeFilter = true) ===
input int StartHour = 8;                    // Hora Início (GMT)
input int EndHour = 18;                     // Hora Fim (GMT)
input bool AvoidFridayLate = true;          // Evitar Sexta-feira Tarde

// === Configurações de Spread (usado se UseSpreadFilter = true) ===
input int MaxSpreadPoints = 20;             // Spread Máximo (pontos)

// === Configurações de RSI (usado se UseRSIFilter = true) ===
input int RSIPeriod = 14;                   // Período RSI
input int RSILevelBuy = 40;                 // RSI Mínimo Compra
input int RSILevelSell = 60;                // RSI Máximo Venda

// === Stop Loss / Take Profit ===
input double StopLossATRMulti = 1.5;        // SL = ATR × Multiplicador
input double RiskRewardRatio = 2.0;         // Risk:Reward (TP/SL)
input int MinStopLossPoints = 200;          // SL Mínimo (pontos)
input int MaxStopLossPoints = 1000;         // SL Máximo (pontos)
input bool UsePivotBasedSL = true;          // 🎯 SL baseado no Pivô (false = baseado na Entry)

// === Gestão de Trades ===
input bool UseReverseClose = true;          // 🔄 Reverse Close (fecha trade oposto automaticamente)

// === Visual ===
input bool ShowInfoPanel = true;            // Mostrar Painel
input bool ShowEntryArrows = true;          // Mostrar Setas Entrada
input bool ShowSLTPLines = true;            // Mostrar Linhas SL/TP
input color BuyPivotColor = clrRed;         // Cor Pivô Compra (Fundo)
input color SellPivotColor = clrDodgerBlue; // Cor Pivô Venda (Topo)
input color BuyConfirmColor = clrDodgerBlue;// Cor Confirmação Compra
input color SellConfirmColor = clrRed;      // Cor Confirmação Venda

// === Alertas ===
input bool EnableAlerts = true;             // Habilitar Alertas
input bool EnablePushNotifications = false; // Notificações Push

// === Backtesting e Varredura ===
input double InitialBalance = 10000.0;      // Capital Inicial (USD)
input double RiskPerTrade = 0.5;            // Risco por Trade (%)
input bool EnableBacktest = true;           // Habilitar Rastreamento
input int ScanPercentage = 100;             // Varredura Histórico (0-100%)

// === Avançado ===
input int MaxLookback = 5000;               // Barras Máximas Análise
input string prefix = "MPP_";               // Prefixo dos Objetos

// ✅ NOVO: Controle de Debug
bool EnableDebugLogs = true;  // ← ADICIONAR ESTA LINHA SE NÃO EXISTIR

//Bloco 2
//+------------------------------------------------------------------+
//| VARIÁVEIS GLOBAIS                                                |
//+------------------------------------------------------------------+
// Buffers do Indicador
double BuyPivotBuf[];
double SellPivotBuf[];
double BuyConfirmBuf[];
double SellConfirmBuf[];
double BuySignalBuf[];
double SellSignalBuf[];

// Estado dos Pivôs
int lastBuyPivotBar = -1;
int lastSellPivotBar = -1;
double lastBuyPivotPrice = 0.0;
double lastSellPivotPrice = 0.0;

// Controle de Alertas
datetime lastAlertTime = 0;
string lastAlertMessage = "";        // ✅ NECESSÁRIA para SendTradeAlert()

// Controle de Varredura
int barsToScan = 0;
int lastScanPercentage = -1;
bool needsReset = false;
int totalBarsAvailable = 0;

// Controle de trigger de vela
datetime lastProcessedBarTime = 0;
bool isNewBar = false;
bool isScanningHistory = true;
int initialBars = 0;

// Rastreamento do período de varredura
datetime firstBarProcessed = 0;     // ✅ NECESSÁRIA no Bloco 4
datetime lastBarProcessed = 0;      // ✅ NECESSÁRIA no Bloco 4
int totalDaysCovered = 0;           // ✅ NECESSÁRIA no Bloco 4

// Controle de atualização
datetime lastPanelUpdate = 0;       // ✅ NECESSÁRIA no Bloco 4

//+------------------------------------------------------------------+
//| ESTRUTURA PARA RASTREAMENTO DE TRADES                            |
//+------------------------------------------------------------------+
struct TradeInfo
{
   datetime openTime;
   double entryPrice;
   double slPrice;
   double tpPrice;
   bool isBuy;
   int status;           // 0=Aberto, 1=Win, 2=Loss
   double profitUSD;
   datetime closeTime;
   double exitPrice;
   int barIndex;
   string entryLineName;
   string slLineName;
   string tpLineName;
   bool linesDrawn;
   bool resultDrawn;
};

TradeInfo trades[];
int totalTrades = 0;

// Controle de linhas por trade
struct LineControl
{
   int tradeIndex;
   string entryLine;
   string slLine;
   string tpLine;
   bool active;
   datetime created;
};

LineControl activeLines[];
int totalActiveLines = 0;

// Métricas de Performance
int totalWins = 0;
int totalLosses = 0;
double totalProfitUSD = 0.0;
double totalLossUSD = 0.0;
double currentBalance = 0.0;
double maxBalance = 0.0;
double maxDrawdown = 0.0;
double profitFactor = 0.0;

// Controle de Reverse Close
struct ActiveTradeControl
{
   bool hasPosition;
   bool isBuy;
   datetime openTime;
   double entryPrice;
   double slPrice;
   double tpPrice;
   int tradeIndex;
};

ActiveTradeControl activeTrade;



// Bloco 3

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   IndicatorBuffers(6);
   IndicatorDigits(Digits);
   
   // ⭐ Buffer 0: Pivôs de Compra (ESTRELA VERMELHA - Fundo)
   SetIndexBuffer(0, BuyPivotBuf);
   SetIndexStyle(0, DRAW_ARROW, EMPTY, 3, BuyPivotColor);
   SetIndexArrow(0, 159);
   SetIndexLabel(0, "Pivô de Compra (Fundo)");
   
   // ⭐ Buffer 1: Pivôs de Venda (ESTRELA AZUL - Topo)
   SetIndexBuffer(1, SellPivotBuf);
   SetIndexStyle(1, DRAW_ARROW, EMPTY, 3, SellPivotColor);
   SetIndexArrow(1, 159);
   SetIndexLabel(1, "Pivô de Venda (Topo)");
   
   // ➡️ Buffer 2: Confirmação de Compra (SETA AZUL)
   SetIndexBuffer(2, BuyConfirmBuf);
   SetIndexStyle(2, DRAW_NONE);  // ✅ AGORA INVISÍVEL
   SetIndexArrow(2, 233);
   SetIndexLabel(2, "Confirmação de Compra");
   
   // ➡️ Buffer 3: Confirmação de Venda (SETA VERMELHA)
   SetIndexBuffer(3, SellConfirmBuf);
   SetIndexStyle(3, DRAW_NONE);  // ✅ AGORA INVISÍVEL
   SetIndexArrow(3, 234);
   SetIndexLabel(3, "Confirmação de Venda");
   
   // Buffer 4: Sinal de Compra (invisível)
   SetIndexBuffer(4, BuySignalBuf);
   SetIndexStyle(4, DRAW_NONE);
   SetIndexLabel(4, "Sinal de Compra");
   
   // Buffer 5: Sinal de Venda (invisível)
   SetIndexBuffer(5, SellSignalBuf);
   SetIndexStyle(5, DRAW_NONE);
   SetIndexLabel(5, "Sinal de Venda");
   
   // Calcular total de barras disponíveis
   totalBarsAvailable = iBars(NULL, 0);
   
   // Verificar se precisa resetar
   if(ScanPercentage == 0)
   {
      ResetFinancialMetrics();
      barsToScan = 50;
   }
   else
   {
      barsToScan = (int)(totalBarsAvailable * (ScanPercentage / 100.0));
      if(barsToScan > MaxLookback) barsToScan = MaxLookback;
      if(barsToScan < 50) barsToScan = 50;
   }
   
   lastScanPercentage = ScanPercentage;
   
   // Criar Painel
   CreateInfoPanel();
   
   // Inicializar Balance
   currentBalance = InitialBalance;
   maxBalance = InitialBalance;
   
   // Inicializar controle de Reverse Close
   activeTrade.hasPosition = false;
   activeTrade.isBuy = false;
   activeTrade.openTime = 0;
   activeTrade.entryPrice = 0;
   activeTrade.slPrice = 0;
   activeTrade.tpPrice = 0;
   activeTrade.tradeIndex = -1;
   
   Print("MAIS PIVOT PRO iniciado | Barras: ", totalBarsAvailable, 
         " | Varredura: ", barsToScan, " (", ScanPercentage, "%)");
   Print("🔄 Reverse Close: ", (UseReverseClose ? "ATIVADO" : "DESATIVADO"));
   Print("🐛 Debug Logs: ", (EnableDebugLogs ? "ATIVADO" : "DESATIVADO"));
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteAllIndicatorObjects();
   Comment("");
   
   string reasonText = "";
   switch(reason)
   {
      case REASON_REMOVE: reasonText = "Removido"; break;
      case REASON_RECOMPILE: reasonText = "Recompilado"; break;
      case REASON_CHARTCHANGE: reasonText = "Mudança de período"; break;
      case REASON_CHARTCLOSE: reasonText = "Gráfico fechado"; break;
      case REASON_PARAMETERS: reasonText = "Parâmetros alterados"; break;
      case REASON_ACCOUNT: reasonText = "Mudança de conta"; break;
      default: reasonText = "Motivo desconhecido"; break;
   }
   
   Print("❌ MAIS PIVOT PRO REMOVIDO | Motivo: ", reasonText);
}

//+------------------------------------------------------------------+
//| Desenhar Seta com Tooltip do Trade (NOVO)                        |
//+------------------------------------------------------------------+
void DrawEntryArrowWithTooltip(int tradeIdx, datetime time, double price, bool isBuy, double entryPrice, double sl, double tp)
{
   string arrowName = prefix + "ENTRY_ARROW_" + IntegerToString(tradeIdx) + "_" + TimeToString(time, TIME_SECONDS);
   
   // Deletar se já existir
   if(ObjectFind(0, arrowName) >= 0)
      ObjectDelete(0, arrowName);
   
   // Criar seta
   if(ObjectCreate(0, arrowName, OBJ_ARROW, 0, time, price))
   {
      // Configurar seta
      if(isBuy)
      {
         ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, 233);  // Seta para cima
         ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clrDodgerBlue);
      }
      else
      {
         ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, 234);  // Seta para baixo
         ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clrRed);
      }
      
      ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, arrowName, OBJPROP_BACK, false);
      ObjectSetInteger(0, arrowName, OBJPROP_SELECTABLE, true);  // ✅ Importante para tooltip funcionar
      
      // Calcular distâncias em pontos
      double slDistance = MathAbs(entryPrice - sl);
      double tpDistance = MathAbs(tp - entryPrice);
      double slPoints = slDistance / Point;
      double tpPoints = tpDistance / Point;
      
      // Criar tooltip
      string tooltip = StringFormat(
         "Trade #%d | %s\nEntry: %.2f\nSL: %.2fpts | TP: %.2fpts\nR:R = 1:%.1f",
         tradeIdx,
         isBuy ? "BUY" : "SELL",
         entryPrice,
         slPoints,
         tpPoints,
         tpPoints / slPoints
      );
      
      ObjectSetString(0, arrowName, OBJPROP_TOOLTIP, tooltip);
   }
}

//+------------------------------------------------------------------+
//| Deletar todos os objetos do indicador                           |
//+------------------------------------------------------------------+
void DeleteAllIndicatorObjects()
{
   int totalDeleted = 0;
   
   string keywords[] = {
      "MPP_", "MAIS", "Panel", "Label", "Value", "Section",
      "STAR", "CONFIRM", "ENTRY", "SL_", "TP_", "RESULT",
      "Title", "Version", "ScanInfo", "Footer"
   };
   
   for(int i = ObjectsTotal() - 1; i >= 0; i--)
   {
      string name = ObjectName(i);
      
      for(int k = 0; k < ArraySize(keywords); k++)
      {
         if(StringFind(name, keywords[k]) >= 0)
         {
            if(ObjectDelete(name))
               totalDeleted++;
            break;
         }
      }
   }
   
   WindowRedraw();
   
   if(totalDeleted > 0)
      Print("✅ ", totalDeleted, " objetos removidos");
}

//+------------------------------------------------------------------+
//| Resetar Métricas Financeiras                                    |
//+------------------------------------------------------------------+
void ResetFinancialMetrics()
{
   // Remover linhas de trades ativos
   for(int i = 0; i < totalTrades; i++)
   {
      if(trades[i].linesDrawn)
      {
         ObjectDelete(0, trades[i].entryLineName);
         ObjectDelete(0, trades[i].slLineName);
         ObjectDelete(0, trades[i].tpLineName);
      }
   }
   
   // Resetar arrays e contadores
   ArrayResize(trades, 0);
   totalTrades = 0;
   totalWins = 0;
   totalLosses = 0;
   totalProfitUSD = 0.0;
   totalLossUSD = 0.0;
   currentBalance = InitialBalance;
   maxBalance = InitialBalance;
   maxDrawdown = 0.0;
   profitFactor = 0.0;
   
   // Resetar controle de Reverse Close
   activeTrade.hasPosition = false;
   activeTrade.tradeIndex = -1;
   
   Print("🔄 RESET FINANCEIRO EXECUTADO");
}

//+------------------------------------------------------------------+
//| Limpar Linhas de Trades Encerrados (OTIMIZADO)                   |
//+------------------------------------------------------------------+
void CleanupClosedTradeLines()
{
   int removed = 0;
   
   for(int i = totalActiveLines - 1; i >= 0; i--)
   {
      if(!activeLines[i].active)
         continue;
         
      int tradeIdx = activeLines[i].tradeIndex;
      
      if(tradeIdx >= 0 && tradeIdx < totalTrades)
      {
         if(trades[tradeIdx].status != 0)
         {
            ObjectDelete(0, activeLines[i].entryLine);
            ObjectDelete(0, activeLines[i].slLine);
            ObjectDelete(0, activeLines[i].tpLine);
            activeLines[i].active = false;
            removed++;
         }
      }
   }
   
   // Compactar array
   int newSize = 0;
   for(int i = 0; i < totalActiveLines; i++)
   {
      if(activeLines[i].active)
      {
         if(i != newSize)
            activeLines[newSize] = activeLines[i];
         newSize++;
      }
   }
   totalActiveLines = newSize;
   
   // ✅ Log único
   if(removed > 0 && EnableDebugLogs)
      Print("🗑️ ", removed, " linhas removidas");
}

//+------------------------------------------------------------------+
//| Registrar Linhas de um Trade (OTIMIZADO - SEM LOG)               |
//+------------------------------------------------------------------+
void RegisterTradeLines(int tradeIndex, string entry, string sl, string tp)
{
   if(totalActiveLines >= ArraySize(activeLines))
      ArrayResize(activeLines, totalActiveLines + 10);
   
   activeLines[totalActiveLines].tradeIndex = tradeIndex;
   activeLines[totalActiveLines].entryLine = entry;
   activeLines[totalActiveLines].slLine = sl;
   activeLines[totalActiveLines].tpLine = tp;
   activeLines[totalActiveLines].active = true;
   activeLines[totalActiveLines].created = TimeCurrent();
   
   totalActiveLines++;
}

//+------------------------------------------------------------------+
//| Verificar se é Pivô High (Array Safe)                            |
//+------------------------------------------------------------------+
bool IsPivotHigh(int shift)
{
   if(shift < PivotStrength || shift < 0)
      return false;
   
   int totalBars = Bars;
   if(totalBars <= 0)
      return false;
      
   if(shift >= totalBars - PivotStrength - 1)
      return false;
   
   if(shift >= ArraySize(High))
      return false;
      
   double centerHigh = High[shift];
   
   for(int i = 1; i <= PivotStrength; i++)
   {
      int leftBar = shift + i;
      
      if(leftBar < 0 || leftBar >= totalBars || leftBar >= ArraySize(High))
         return false;
         
      if(High[leftBar] >= centerHigh)
         return false;
   }
   
   for(int i = 1; i <= PivotStrength; i++)
   {
      int rightBar = shift - i;
      
      if(rightBar < 0 || rightBar >= totalBars || rightBar >= ArraySize(High))
         return false;
         
      if(High[rightBar] >= centerHigh)
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Verificar se é Pivô Low (Array Safe)                             |
//+------------------------------------------------------------------+
bool IsPivotLow(int shift)
{
   if(shift < PivotStrength || shift < 0)
      return false;
   
   int totalBars = Bars;
   if(totalBars <= 0)
      return false;
      
   if(shift >= totalBars - PivotStrength - 1)
      return false;
   
   if(shift >= ArraySize(Low))
      return false;
      
   double centerLow = Low[shift];
   
   for(int i = 1; i <= PivotStrength; i++)
   {
      int leftBar = shift + i;
      
      if(leftBar < 0 || leftBar >= totalBars || leftBar >= ArraySize(Low))
         return false;
         
      if(Low[leftBar] <= centerLow)
         return false;
   }
   
   for(int i = 1; i <= PivotStrength; i++)
   {
      int rightBar = shift - i;
      
      if(rightBar < 0 || rightBar >= totalBars || rightBar >= ArraySize(Low))
         return false;
         
      if(Low[rightBar] <= centerLow)
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Fechar Trade Atual (OTIMIZADO)                                   |
//+------------------------------------------------------------------+
void CloseCurrentTrade(int currentBar, string reason)
{
   // Validações silenciosas durante scan
   if(!activeTrade.hasPosition)
   {
      if(EnableDebugLogs && !isScanningHistory)
         Print("⚠️ Nenhum trade ativo para fechar");
      return;
   }
   
   if(activeTrade.tradeIndex < 0 || activeTrade.tradeIndex >= totalTrades)
   {
      if(EnableDebugLogs && !isScanningHistory)
         Print("❌ Índice de trade inválido");
      activeTrade.hasPosition = false;
      return;
   }
   
   if(trades[activeTrade.tradeIndex].status != 0)
   {
      if(EnableDebugLogs && !isScanningHistory)
         Print("⚠️ Trade já foi fechado");
      activeTrade.hasPosition = false;
      return;
   }
   
   bool isReverseClose = (StringFind(reason, "Reverse") >= 0);
   
   int closeBar = currentBar;
   bool hitTP = false;
   bool hitSL = false;
   double closePrice = Close[currentBar];
   datetime closeTime = Time[currentBar];
   
   if(isReverseClose)
   {
      closePrice = Close[currentBar];
      closeTime = Time[currentBar];
      closeBar = currentBar;
      hitTP = false;
      hitSL = false;
   }
   else
   {
      int entryBar = iBarShift(NULL, 0, activeTrade.openTime);
      
      for(int j = currentBar; j <= entryBar; j++)
      {
         if(activeTrade.isBuy)
         {
            if(High[j] >= activeTrade.tpPrice)
            {
               hitTP = true;
               closePrice = activeTrade.tpPrice;
               closeTime = Time[j];
               closeBar = j;
               break;
            }
            if(Low[j] <= activeTrade.slPrice)
            {
               hitSL = true;
               closePrice = activeTrade.slPrice;
               closeTime = Time[j];
               closeBar = j;
               break;
            }
         }
         else
         {
            if(Low[j] <= activeTrade.tpPrice)
            {
               hitTP = true;
               closePrice = activeTrade.tpPrice;
               closeTime = Time[j];
               closeBar = j;
               break;
            }
            if(High[j] >= activeTrade.slPrice)
            {
               hitSL = true;
               closePrice = activeTrade.slPrice;
               closeTime = Time[j];
               closeBar = j;
               break;
            }
         }
      }
   }
   
   // Validação
   int closeBarIndex = iBarShift(NULL, 0, closeTime);
   if(closeBarIndex >= 0 && closeBarIndex < Bars)
   {
      bool priceInsideBar = (closePrice >= Low[closeBarIndex] && closePrice <= High[closeBarIndex]);
      
      if(!priceInsideBar)
      {
         if(EnableDebugLogs)
            Print("⚠️ Exit price fora da vela, usando Close");
         closePrice = Close[closeBarIndex];
         hitTP = false;
         hitSL = false;
      }
   }
   
   // ✅ DEBUG condicional
   if(EnableDebugLogs)
   {
      Print("🔍 DEBUG CloseCurrentTrade:");
      Print("   Reason: ", reason);
      Print("   Reverse: ", isReverseClose ? "SIM" : "NÃO");
      Print("   Bar: ", currentBar, " → ", closeBar);
      Print("   TP/SL: ", hitTP, "/", hitSL);
      Print("   Price: ", DoubleToString(closePrice, Digits));
   }
   
   // Calcular lucro
   double profit = 0;
   
   if(hitTP)
   {
      profit = (InitialBalance * RiskPerTrade / 100) * RiskRewardRatio;
   }
   else if(hitSL)
   {
      profit = -(InitialBalance * RiskPerTrade / 100);
   }
   else
   {
      double riskPoints = MathAbs(activeTrade.entryPrice - activeTrade.slPrice) / Point;
      
      if(activeTrade.isBuy)
      {
         double gainPoints = (closePrice - activeTrade.entryPrice) / Point;
         profit = (gainPoints / riskPoints) * (InitialBalance * RiskPerTrade / 100);
      }
      else
      {
         double gainPoints = (activeTrade.entryPrice - closePrice) / Point;
         profit = (gainPoints / riskPoints) * (InitialBalance * RiskPerTrade / 100);
      }
      
      double maxProfit = (InitialBalance * RiskPerTrade / 100) * RiskRewardRatio;
      double maxLoss = -(InitialBalance * RiskPerTrade / 100);
      
      if(profit > maxProfit)
         profit = maxProfit;
      else if(profit < maxLoss)
         profit = maxLoss;
   }
   
   // ✅ Log simplificado
   if(EnableDebugLogs)
      Print("   💰 ", (hitTP ? "TP" : (hitSL ? "SL" : "Parcial")), " = $", DoubleToString(profit, 2));
   
   // Atualizar trade
   int idx = activeTrade.tradeIndex;
   trades[idx].closeTime = closeTime;
   trades[idx].exitPrice = closePrice;
   trades[idx].profitUSD = profit;
   
   if(profit > 0)
   {
      trades[idx].status = 1;
      totalWins++;
      totalProfitUSD += profit;
   }
   else
   {
      trades[idx].status = 2;
      totalLosses++;
      totalLossUSD += MathAbs(profit);
   }
   
   currentBalance += profit;
   
   if(currentBalance > maxBalance)
      maxBalance = currentBalance;
   
   double dd = ((maxBalance - currentBalance) / maxBalance) * 100;
   if(dd > maxDrawdown)
      maxDrawdown = dd;
   
   // ✅ Log limpo apenas ao vivo
   if(!isScanningHistory)
   {
      string type = activeTrade.isBuy ? "COMPRA" : "VENDA";
      string result = (profit > 0) ? "WIN" : "LOSS";
      string exitType = hitTP ? "TP" : (hitSL ? "SL" : "REVERSE");
      
      Print("💼 ", type, " fechada | ", exitType, " | ", result, " $", DoubleToString(profit, 2));
   }
   
   activeTrade.hasPosition = false;
   activeTrade.tradeIndex = -1;
}

//+------------------------------------------------------------------+
//| Gerar Sinal de Compra (COM TOOLTIP)                              |
//+------------------------------------------------------------------+
void GenerateBuySignal(int i)
{
   if(i < 0 || i >= ArraySize(Close))
   {
      if(EnableDebugLogs)
         Print("⚠️ GenerateBuySignal: Índice inválido i=", i);
      return;
   }
   
   if(!PassEntryFilters(true, i))
      return;
   
   double entry = Close[i];
   double sl = 0.0, tp = 0.0;
   CalculateSLTP(true, i, lastBuyPivotPrice, sl, tp);
   
   if(i >= 0 && i < ArraySize(BuySignalBuf))
      BuySignalBuf[i] = entry;
   
   // Reverse Close Logic
   if(UseReverseClose && activeTrade.hasPosition)
   {
      if(activeTrade.isBuy)
      {
         if(!isScanningHistory)
            Print("⚠️ Sinal COMPRA ignorado: já existe COMPRA aberta");
         lastBuyPivotBar = -1;
         return;
      }
      else
      {
         if(!isScanningHistory)
            Print("🔄 REVERSE: Fechando VENDA para abrir COMPRA");
         CloseCurrentTrade(i, "Reverse to BUY");
      }
   }
   else if(!UseReverseClose && activeTrade.hasPosition)
   {
      if(!isScanningHistory)
         Print("⚠️ Sinal ignorado: posição já aberta");
      lastBuyPivotBar = -1;
      return;
   }
   
   // Registrar trade
   if(EnableBacktest)
   {
      int tradeIdx = totalTrades;
      ArrayResize(trades, totalTrades + 1);
      
      datetime tradeTime = (i >= 0 && i < ArraySize(Time)) ? Time[i] : TimeCurrent();
      
      trades[tradeIdx].openTime = tradeTime;
      trades[tradeIdx].entryPrice = entry;
      trades[tradeIdx].slPrice = sl;
      trades[tradeIdx].tpPrice = tp;
      trades[tradeIdx].isBuy = true;
      trades[tradeIdx].status = 0;
      trades[tradeIdx].barIndex = i;
      trades[tradeIdx].linesDrawn = false;
      trades[tradeIdx].resultDrawn = false;
      
      totalTrades++;
      
      // ✅✅✅ NOVO: Desenhar seta com tooltip ✅✅✅
      if(ShowEntryArrows)
      {
         double arrowPrice = Low[i] - (15 * Point);
         DrawEntryArrowWithTooltip(tradeIdx, tradeTime, arrowPrice, true, entry, sl, tp);
      }
      
      // Atualizar controle
      activeTrade.hasPosition = true;
      activeTrade.isBuy = true;
      activeTrade.openTime = tradeTime;
      activeTrade.entryPrice = entry;
      activeTrade.slPrice = sl;
      activeTrade.tpPrice = tp;
      activeTrade.tradeIndex = tradeIdx;
      
      // Desenhar linhas apenas ao vivo
      if(ShowSLTPLines && !isScanningHistory)
      {
         string entryName = "MPP_ENTRY_BUY_" + TimeToString(tradeTime, TIME_DATE|TIME_SECONDS);
         string slName = "MPP_SL_BUY_" + TimeToString(tradeTime, TIME_DATE|TIME_SECONDS);
         string tpName = "MPP_TP_BUY_" + TimeToString(tradeTime, TIME_DATE|TIME_SECONDS);
         
         if(ObjectCreate(0, entryName, OBJ_HLINE, 0, 0, entry))
         {
            ObjectSetInteger(0, entryName, OBJPROP_COLOR, clrGold);
            ObjectSetInteger(0, entryName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, entryName, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, entryName, OBJPROP_BACK, true);
            ObjectSetInteger(0, entryName, OBJPROP_SELECTABLE, false);
         }
         
         if(ObjectCreate(0, slName, OBJ_HLINE, 0, 0, sl))
         {
            ObjectSetInteger(0, slName, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, slName, OBJPROP_STYLE, STYLE_DOT);
            ObjectSetInteger(0, slName, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, slName, OBJPROP_BACK, true);
            ObjectSetInteger(0, slName, OBJPROP_SELECTABLE, false);
         }
         
         if(ObjectCreate(0, tpName, OBJ_HLINE, 0, 0, tp))
         {
            ObjectSetInteger(0, tpName, OBJPROP_COLOR, clrDodgerBlue);
            ObjectSetInteger(0, tpName, OBJPROP_STYLE, STYLE_DOT);
            ObjectSetInteger(0, tpName, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, tpName, OBJPROP_BACK, true);
            ObjectSetInteger(0, tpName, OBJPROP_SELECTABLE, false);
         }
         
         trades[tradeIdx].entryLineName = entryName;
         trades[tradeIdx].slLineName = slName;
         trades[tradeIdx].tpLineName = tpName;
         trades[tradeIdx].linesDrawn = true;
         
         RegisterTradeLines(tradeIdx, entryName, slName, tpName);
      }
      
      // ✅ Log apenas em modo debug ou ao vivo
      if((EnableDebugLogs || !isScanningHistory) && !isScanningHistory)
         Print("✅ COMPRA registrada: ", DoubleToString(entry, Digits), 
               " | SL: ", DoubleToString(sl, Digits), " | TP: ", DoubleToString(tp, Digits));
   }
   
   // Alerta apenas ao vivo
   if(EnableAlerts && !isScanningHistory && TimeCurrent() - lastAlertTime > 5)
   {
      string msg = "🟢 SINAL DE COMPRA em " + Symbol();
      Alert(msg);
      lastAlertTime = TimeCurrent();
   }
   
   lastBuyPivotBar = -1;
}

//+------------------------------------------------------------------+
//| Gerar Sinal de Venda (COM TOOLTIP)                               |
//+------------------------------------------------------------------+
void GenerateSellSignal(int i)
{
   if(i < 0 || i >= ArraySize(Close))
   {
      if(EnableDebugLogs)
         Print("⚠️ GenerateSellSignal: Índice inválido i=", i);
      return;
   }
   
   if(!PassEntryFilters(false, i))
      return;
   
   double entry = Close[i];
   double sl = 0.0, tp = 0.0;
   CalculateSLTP(false, i, lastSellPivotPrice, sl, tp);
   
   if(i >= 0 && i < ArraySize(SellSignalBuf))
      SellSignalBuf[i] = entry;
   
   // Reverse Close Logic
   if(UseReverseClose && activeTrade.hasPosition)
   {
      if(!activeTrade.isBuy)
      {
         if(!isScanningHistory)
            Print("⚠️ Sinal VENDA ignorado: já existe VENDA aberta");
         lastSellPivotBar = -1;
         return;
      }
      else
      {
         if(!isScanningHistory)
            Print("🔄 REVERSE: Fechando COMPRA para abrir VENDA");
         CloseCurrentTrade(i, "Reverse to SELL");
      }
   }
   else if(!UseReverseClose && activeTrade.hasPosition)
   {
      if(!isScanningHistory)
         Print("⚠️ Sinal ignorado: posição já aberta");
      lastSellPivotBar = -1;
      return;
   }
   
   // Registrar trade
   if(EnableBacktest)
   {
      int tradeIdx = totalTrades;
      ArrayResize(trades, totalTrades + 1);
      
      datetime tradeTime = (i >= 0 && i < ArraySize(Time)) ? Time[i] : TimeCurrent();
      
      trades[tradeIdx].openTime = tradeTime;
      trades[tradeIdx].entryPrice = entry;
      trades[tradeIdx].slPrice = sl;
      trades[tradeIdx].tpPrice = tp;
      trades[tradeIdx].isBuy = false;
      trades[tradeIdx].status = 0;
      trades[tradeIdx].barIndex = i;
      trades[tradeIdx].linesDrawn = false;
      trades[tradeIdx].resultDrawn = false;
      
      totalTrades++;
      
      // ✅✅✅ NOVO: Desenhar seta com tooltip ✅✅✅
      if(ShowEntryArrows)
      {
         double arrowPrice = High[i] + (15 * Point);
         DrawEntryArrowWithTooltip(tradeIdx, tradeTime, arrowPrice, false, entry, sl, tp);
      }
      
      // Atualizar controle
      activeTrade.hasPosition = true;
      activeTrade.isBuy = false;
      activeTrade.openTime = tradeTime;
      activeTrade.entryPrice = entry;
      activeTrade.slPrice = sl;
      activeTrade.tpPrice = tp;
      activeTrade.tradeIndex = tradeIdx;
      
      // Desenhar linhas apenas ao vivo
      if(ShowSLTPLines && !isScanningHistory)
      {
         string entryName = "MPP_ENTRY_SELL_" + TimeToString(tradeTime, TIME_DATE|TIME_SECONDS);
         string slName = "MPP_SL_SELL_" + TimeToString(tradeTime, TIME_DATE|TIME_SECONDS);
         string tpName = "MPP_TP_SELL_" + TimeToString(tradeTime, TIME_DATE|TIME_SECONDS);
         
         if(ObjectCreate(0, entryName, OBJ_HLINE, 0, 0, entry))
         {
            ObjectSetInteger(0, entryName, OBJPROP_COLOR, clrGold);
            ObjectSetInteger(0, entryName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, entryName, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, entryName, OBJPROP_BACK, true);
            ObjectSetInteger(0, entryName, OBJPROP_SELECTABLE, false);
         }
         
         if(ObjectCreate(0, slName, OBJ_HLINE, 0, 0, sl))
         {
            ObjectSetInteger(0, slName, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, slName, OBJPROP_STYLE, STYLE_DOT);
            ObjectSetInteger(0, slName, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, slName, OBJPROP_BACK, true);
            ObjectSetInteger(0, slName, OBJPROP_SELECTABLE, false);
         }
         
         if(ObjectCreate(0, tpName, OBJ_HLINE, 0, 0, tp))
         {
            ObjectSetInteger(0, tpName, OBJPROP_COLOR, clrDodgerBlue);
            ObjectSetInteger(0, tpName, OBJPROP_STYLE, STYLE_DOT);
            ObjectSetInteger(0, tpName, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, tpName, OBJPROP_BACK, true);
            ObjectSetInteger(0, tpName, OBJPROP_SELECTABLE, false);
         }
         
         trades[tradeIdx].entryLineName = entryName;
         trades[tradeIdx].slLineName = slName;
         trades[tradeIdx].tpLineName = tpName;
         trades[tradeIdx].linesDrawn = true;
         
         RegisterTradeLines(tradeIdx, entryName, slName, tpName);
      }
      
      // ✅ Log apenas em modo debug ou ao vivo
      if((EnableDebugLogs || !isScanningHistory) && !isScanningHistory)
         Print("✅ VENDA registrada: ", DoubleToString(entry, Digits),
               " | SL: ", DoubleToString(sl, Digits), " | TP: ", DoubleToString(tp, Digits));
   }
   
   // Alerta apenas ao vivo
   if(EnableAlerts && !isScanningHistory && TimeCurrent() - lastAlertTime > 5)
   {
      string msg = "🔴 SINAL DE VENDA em " + Symbol();
      Alert(msg);
      lastAlertTime = TimeCurrent();
   }
   
   lastSellPivotBar = -1;
}


//+------------------------------------------------------------------+
//| Redesenhar Setas de Entrada com Tooltip                          |
//+------------------------------------------------------------------+
void RedrawAllEntryArrows()
{
   if(!ShowEntryArrows)
      return;
   
   int drawn = 0;
   
   for(int i = 0; i < totalTrades; i++)
   {
      // Verificar se já existe a seta
      string arrowName = prefix + "ENTRY_ARROW_" + IntegerToString(i) + "_" + TimeToString(trades[i].openTime, TIME_SECONDS);
      
      if(ObjectFind(0, arrowName) >= 0)
         continue;  // Já existe, pular
      
      // Desenhar seta com tooltip
      double arrowPrice;
      if(trades[i].isBuy)
         arrowPrice = trades[i].entryPrice - (15 * Point);  // Aproximação
      else
         arrowPrice = trades[i].entryPrice + (15 * Point);
      
      DrawEntryArrowWithTooltip(
         i, 
         trades[i].openTime, 
         arrowPrice, 
         trades[i].isBuy, 
         trades[i].entryPrice, 
         trades[i].slPrice, 
         trades[i].tpPrice
      );
      
      drawn++;
   }
   
   if(drawn > 0)
      Print("✅ ", drawn, " setas de entrada redesenhadas com tooltip");
}




// Bloco 4

//+------------------------------------------------------------------+
//| Custom indicator iteration function (OTIMIZADO)                  |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   // Proteção: Verificar dados suficientes
   int minBars = TrendEMAPeriod + 50;
   if(rates_total < minBars)
   {
      Comment("⏳ Aguardando dados... ", rates_total, "/", minBars);
      return(0);
   }
   
   if(ArraySize(BuyPivotBuf) < rates_total)
      return(0);
   
   // Detecção de nova barra
   datetime currentBarTime = Time[0];
   isNewBar = false;
   
   if(currentBarTime != lastProcessedBarTime)
   {
      isNewBar = true;
      lastProcessedBarTime = currentBarTime;
   }
   
   // Detectar fim da varredura inicial
   if(isScanningHistory)
   {
      if(initialBars == 0)
         initialBars = rates_total;
         
      if(prev_calculated > 0 && prev_calculated == rates_total)
      {
         isScanningHistory = false;
         Print("✅ Varredura concluída. Sistema ativo para trading ao vivo.");
         Print("📊 Total de trades: ", totalTrades, " | Wins: ", totalWins, " | Losses: ", totalLosses);
         DrawAllClosedTradeResults();
      }
   }
   
   // Limpar linhas de trades encerrados
   CleanupClosedTradeLines();
   
   // Verificar reset
   if(needsReset)
   {
      ResetFinancialMetrics();
      needsReset = false;
      lastScanPercentage = -1;
   }
   
   // Definir como série
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   // Calcular barras a varrer
   totalBarsAvailable = iBars(Symbol(), Period());
   
   if(ScanPercentage == 0)
      barsToScan = MathMin(150, totalBarsAvailable);
   else
      barsToScan = MathMin((int)(totalBarsAvailable * ScanPercentage / 100.0), totalBarsAvailable);
   
   int limit = barsToScan;
   if(prev_calculated > 0)
      limit = MathMin(3, barsToScan);
   
   // Proteção: Evitar array out of range
   if(limit >= rates_total)
      limit = rates_total - 1;
   
   if(limit < 0)
      limit = 0;
   
   // Rastreamento do período de varredura
   if(rates_total > 0)
   {
      int lastIndex = rates_total - 1;
      if(lastIndex >= 0 && lastIndex < ArraySize(Time))
      {
         if(firstBarProcessed == 0 || Time[lastIndex] < firstBarProcessed)
            firstBarProcessed = Time[lastIndex];
      }
      
      if(ArraySize(Time) > 0 && Time[0] > lastBarProcessed)
         lastBarProcessed = Time[0];
      
      if(firstBarProcessed > 0 && lastBarProcessed > 0)
         totalDaysCovered = (int)((lastBarProcessed - firstBarProcessed) / 86400);
   }
   
   // Loop principal com proteção total
   for(int i = limit; i >= 0; i--)
   {
      // Proteção: Verificar limites
      if(i < 0 || i >= rates_total)
         continue;
      
      if(i >= ArraySize(BuyPivotBuf))
         continue;
      
      // Resetar buffers
      BuyPivotBuf[i] = EMPTY_VALUE;
      SellPivotBuf[i] = EMPTY_VALUE;
      BuyConfirmBuf[i] = EMPTY_VALUE;
      SellConfirmBuf[i] = EMPTY_VALUE;
      BuySignalBuf[i] = EMPTY_VALUE;
      SellSignalBuf[i] = EMPTY_VALUE;
      
      // Detectar pivôs
      if(IsPivotHigh(i))
      {
         if(i >= 0 && i < ArraySize(High))
         {
            SellPivotBuf[i] = High[i];
            lastSellPivotBar = i;
            lastSellPivotPrice = High[i];
         }
      }
      
      if(IsPivotLow(i))
      {
         if(i >= 0 && i < ArraySize(Low))
         {
            BuyPivotBuf[i] = Low[i];
            lastBuyPivotBar = i;
            lastBuyPivotPrice = Low[i];
         }
      }
      
      // Verificar confirmação de compra
      if(lastBuyPivotBar >= 0 && i < lastBuyPivotBar - ConfirmCandles && lastBuyPivotBar < rates_total)
      {
         bool confirmed = true;
         
         for(int j = 1; j <= ConfirmCandles; j++)
         {
            int checkBar = lastBuyPivotBar - j;
            
            if(checkBar < 0 || checkBar >= rates_total || checkBar >= ArraySize(Close))
            {
               confirmed = false;
               break;
            }
            
            if(Close[checkBar] <= lastBuyPivotPrice || Low[checkBar] < lastBuyPivotPrice)
            {
               confirmed = false;
               break;
            }
         }
         
         if(confirmed)
         {
            
            
            if(isScanningHistory || (i == 0 && isNewBar))
            {
               GenerateBuySignal(i);
               lastBuyPivotBar = -1;
            }
         }
      }
      
      // Verificar confirmação de venda
      if(lastSellPivotBar >= 0 && i < lastSellPivotBar - ConfirmCandles && lastSellPivotBar < rates_total)
      {
         bool confirmed = true;
         
         for(int j = 1; j <= ConfirmCandles; j++)
         {
            int checkBar = lastSellPivotBar - j;
            
            if(checkBar < 0 || checkBar >= rates_total || checkBar >= ArraySize(Close))
            {
               confirmed = false;
               break;
            }
            
            if(Close[checkBar] >= lastSellPivotPrice || High[checkBar] > lastSellPivotPrice)
            {
               confirmed = false;
               break;
            }
         }
         
         if(confirmed)
         {
            
            
            if(isScanningHistory || (i == 0 && isNewBar))
            {
               GenerateSellSignal(i);
               lastSellPivotBar = -1;
            }
         }
      }
      
      // Verificar trades durante varredura
      if(isScanningHistory && EnableBacktest)
      {
         CheckTradeResultsDuringHistory(i);
      }
   }
   
   // Processar trades abertos (apenas ao vivo)
   if(!isScanningHistory)
   {
      CheckTradeResults();
   }
   
   // ✅ Desenhar resultados APENAS uma vez por trade
   if(ShowSLTPLines)
   {
      int drawn = 0;
      
      for(int i = 0; i < totalTrades; i++)
      {
         if(trades[i].status != 0 && !trades[i].resultDrawn)
         {
            DrawTradeResult(i);
            trades[i].resultDrawn = true;
            drawn++;
         }
      }
      
      // ✅ Log único ao final
      if(drawn > 0 && EnableDebugLogs && !isScanningHistory)
         Print("🎨 ", drawn, " resultados desenhados");
   }
   
   // Atualizar painel
   if(ShowInfoPanel && TimeCurrent() - lastPanelUpdate >= 1)
   {
      UpdateInfoPanel();
      lastPanelUpdate = TimeCurrent();
   }
   
   return rates_total;
}

//+------------------------------------------------------------------+
//| Verificar Trades Durante Varredura Histórica (OTIMIZADO)         |
//+------------------------------------------------------------------+
void CheckTradeResultsDuringHistory(int currentBar)
{
   if(!EnableBacktest || totalTrades == 0)
      return;
   
   // ✅ Contador para resumo
   static int closedCount = 0;
   static int lastReportedCount = 0;
   
   for(int i = 0; i < totalTrades; i++)
   {
      if(trades[i].status != 0)
         continue;
      
      int entryBar = iBarShift(NULL, 0, trades[i].openTime);
      if(entryBar < 0 || currentBar >= entryBar)
         continue;
      
      bool hitTP = false;
      bool hitSL = false;
      
      if(trades[i].isBuy)
      {
         if(High[currentBar] >= trades[i].tpPrice)
            hitTP = true;
         if(Low[currentBar] <= trades[i].slPrice)
            hitSL = true;
      }
      else
      {
         if(Low[currentBar] <= trades[i].tpPrice)
            hitTP = true;
         if(High[currentBar] >= trades[i].slPrice)
            hitSL = true;
      }
      
      if(hitTP || hitSL)
      {
         trades[i].closeTime = Time[currentBar];
         trades[i].exitPrice = hitTP ? trades[i].tpPrice : trades[i].slPrice;
         
         double profit = 0;
         
         if(hitTP)
         {
            trades[i].status = 1;
            profit = (InitialBalance * RiskPerTrade / 100) * RiskRewardRatio;
            totalWins++;
            totalProfitUSD += profit;
         }
         else
         {
            trades[i].status = 2;
            profit = -(InitialBalance * RiskPerTrade / 100);
            totalLosses++;
            totalLossUSD += MathAbs(profit);
         }
         
         trades[i].profitUSD = profit;
         currentBalance += profit;
         
         if(currentBalance > maxBalance)
            maxBalance = currentBalance;
         
         double dd = ((maxBalance - currentBalance) / maxBalance) * 100;
         if(dd > maxDrawdown)
            maxDrawdown = dd;
         
         // Se este é o trade ativo, limpar controle
         if(UseReverseClose && activeTrade.hasPosition && activeTrade.tradeIndex == i)
         {
            activeTrade.hasPosition = false;
            activeTrade.tradeIndex = -1;
         }
         
         closedCount++;
         
         // ✅ Log resumido apenas a cada 10 trades ou em modo debug
         if(EnableDebugLogs || (closedCount % 10 == 0 && closedCount > lastReportedCount))
         {
            Print("📊 Histórico: ", closedCount, " trades processados | Wins: ", totalWins, " | Losses: ", totalLosses);
            lastReportedCount = closedCount;
         }
         
         // ✅ Log detalhado APENAS em modo debug E para primeiros/últimos 3 trades
         if(EnableDebugLogs && (i < 3 || i >= totalTrades - 3))
         {
            Print("   Trade #", i, " | ", (trades[i].isBuy ? "BUY" : "SELL"), 
                  " | ", (hitTP ? "TP" : "SL"), 
                  " | Entry: ", TimeToString(trades[i].openTime, TIME_DATE|TIME_MINUTES),
                  " | Exit: ", TimeToString(Time[currentBar], TIME_DATE|TIME_MINUTES),
                  " | $", DoubleToString(profit, 2));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Verificar Resultados dos Trades (MODO AO VIVO - OTIMIZADO)       |
//+------------------------------------------------------------------+
void CheckTradeResults()
{
   if(!EnableBacktest)
      return;
   
   // Modo Reverse Close: verifica apenas o trade ativo
   if(UseReverseClose && activeTrade.hasPosition)
   {
      int idx = activeTrade.tradeIndex;
      
      if(idx < 0 || idx >= totalTrades)
      {
         if(EnableDebugLogs)
            Print("⚠️ CheckTradeResults: Índice inválido");
         activeTrade.hasPosition = false;
         return;
      }
      
      if(trades[idx].status != 0)
      {
         activeTrade.hasPosition = false;
         return;
      }
      
      bool hitTP = false, hitSL = false;
      
      if(activeTrade.isBuy)
      {
         if(High[0] >= activeTrade.tpPrice)
            hitTP = true;
         if(Low[0] <= activeTrade.slPrice)
            hitSL = true;
      }
      else
      {
         if(Low[0] <= activeTrade.tpPrice)
            hitTP = true;
         if(High[0] >= activeTrade.slPrice)
            hitSL = true;
      }
      
      if(hitTP || hitSL)
      {
         string reason = hitTP ? "Take Profit atingido" : "Stop Loss atingido";
         CloseCurrentTrade(0, reason);
      }
      
      return;
   }
   
   // Modo Normal: verifica todos os trades abertos
   if(totalTrades == 0)
      return;
   
   for(int i = 0; i < totalTrades; i++)
   {
      if(trades[i].status != 0)
         continue;
      
      int entryBar = iBarShift(NULL, 0, trades[i].openTime);
      if(entryBar < 0)
         continue;
      
      bool hitTP = false, hitSL = false;
      datetime closeTime = 0;
      int closeBar = 0;
      
      for(int j = entryBar - 1; j >= 0; j--)
      {
         if(trades[i].isBuy)
         {
            if(High[j] >= trades[i].tpPrice)
            {
               hitTP = true;
               closeTime = Time[j];
               closeBar = j;
               trades[i].exitPrice = trades[i].tpPrice;
               break;
            }
            if(Low[j] <= trades[i].slPrice)
            {
               hitSL = true;
               closeTime = Time[j];
               closeBar = j;
               trades[i].exitPrice = trades[i].slPrice;
               break;
            }
         }
         else
         {
            if(Low[j] <= trades[i].tpPrice)
            {
               hitTP = true;
               closeTime = Time[j];
               closeBar = j;
               trades[i].exitPrice = trades[i].tpPrice;
               break;
            }
            if(High[j] >= trades[i].slPrice)
            {
               hitSL = true;
               closeTime = Time[j];
               closeBar = j;
               trades[i].exitPrice = trades[i].slPrice;
               break;
            }
         }
      }
      
      if(hitTP || hitSL)
      {
         trades[i].closeTime = closeTime;
         
         double profit = 0;
         
         if(hitTP)
         {
            trades[i].status = 1;
            profit = (InitialBalance * RiskPerTrade / 100) * RiskRewardRatio;
            totalWins++;
            totalProfitUSD += profit;
         }
         else
         {
            trades[i].status = 2;
            profit = -(InitialBalance * RiskPerTrade / 100);
            totalLosses++;
            totalLossUSD += MathAbs(profit);
         }
         
         trades[i].profitUSD = profit;
         currentBalance += profit;
         
         if(currentBalance > maxBalance)
            maxBalance = currentBalance;
         
         double dd = ((maxBalance - currentBalance) / maxBalance) * 100;
         if(dd > maxDrawdown)
            maxDrawdown = dd;
         
         if(ShowSLTPLines)
            DrawTradeResult(i);
         
         // ✅ Log limpo
         Print("💼 Trade #", i, " fechado | ", (hitTP ? "TP WIN" : "SL LOSS"), " | $", DoubleToString(profit, 2));
      }
   }
}
// Bloco 5

//+------------------------------------------------------------------+
//| Desenhar Estrela no Pivô (OTIMIZADO)                             |
//+------------------------------------------------------------------+
void DrawStar(bool isBuyPivot, int bar, double price)
{
   // Validações silenciosas
   if(bar < 0 || bar >= Bars)
      return;
   
   if(price <= 0)
      return;
   
   // Nome único do objeto
   string objName = prefix + "STAR_" + (isBuyPivot ? "BUY_" : "SELL_") + TimeToString(Time[bar], TIME_SECONDS);
   
   // Deletar objeto se já existir
   if(ObjectFind(0, objName) >= 0)
      ObjectDelete(0, objName);
   
   // Criar ESTRELA (código 119 = wingdings estrela ★)
   if(!ObjectCreate(0, objName, OBJ_ARROW, 0, Time[bar], price))
   {
      // ✅ Log apenas em modo debug
      if(EnableDebugLogs)
         Print("⚠️ Erro ao criar estrela: ", GetLastError());
      return;
   }
   
   // Configurar ESTRELA
   ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, 119);
   
   // COR: VERMELHA para COMPRA (fundo) / AZUL para VENDA (topo)
   if(isBuyPivot)
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrRed);
   else
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrDodgerBlue);
   
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 3);
   
   // Posicionar corretamente
   if(isBuyPivot)
      ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_TOP);
   else
      ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
   
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, objName, OBJPROP_BACK, false);
}

// Bloco 6

// Empty

//Bloco 7 (OTIMIZADO)

//+------------------------------------------------------------------+
//| Enviar Alerta de Trade (OTIMIZADO)                               |
//+------------------------------------------------------------------+
void SendTradeAlert(bool isBuy, double entry, double sl, double tp)
{
   // Validações
   if(!EnableAlerts)
      return;
   
   if(isScanningHistory)
      return;
   
   // Criar mensagem
   string message = StringFormat("%s %s | Entry: %s | SL: %s | TP: %s",
                                 Symbol(),
                                 isBuy ? "🟢 COMPRA" : "🔴 VENDA",
                                 DoubleToString(entry, Digits),
                                 DoubleToString(sl, Digits),
                                 DoubleToString(tp, Digits));
   
   // Prevenir alertas duplicados
   if(lastAlertMessage == message && TimeCurrent() - lastAlertTime <= 60)
   {
      if(EnableDebugLogs)
         Print("⚠️ Alerta duplicado bloqueado");
      return;
   }
   
   // Enviar alerta
   Alert(message);
   
   // Enviar notificação push
   if(EnablePushNotifications)
   {
      if(!SendNotification(message))
      {
         if(EnableDebugLogs)
            Print("⚠️ Falha ao enviar notificação push: ", GetLastError());
      }
   }
   
   // Atualizar controle
   lastAlertMessage = message;
   lastAlertTime = TimeCurrent();
   
   if(EnableDebugLogs)
      Print("✅ Alerta enviado: ", message);
}

// Bloco 8

//+------------------------------------------------------------------+
//| Obter unidade de ponto UNIVERSAL (funciona para QUALQUER ativo)  |
//+------------------------------------------------------------------+
double GetDisplayPoint()
{
   string symbol = Symbol();
   int digits = Digits;
   
   // ══════════════════════════════════════════════════════════════
   // 1️⃣ METAIS PRECIOSOS (Gold, Silver, etc)
   // ══════════════════════════════════════════════════════════════
   if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0)
      return 1.0;  // GOLD: 1 ponto = $1.00
   
   if(StringFind(symbol, "XAG") >= 0 || StringFind(symbol, "SILVER") >= 0)
      return 1.0;  // SILVER: 1 ponto = $1.00
   
   // ══════════════════════════════════════════════════════════════
   // 2️⃣ ÍNDICES (US500, NAS100, DAX, etc)
   // ══════════════════════════════════════════════════════════════
   if(StringFind(symbol, "US500") >= 0 || 
      StringFind(symbol, "SPX") >= 0 || 
      StringFind(symbol, "S&P") >= 0)
      return 1.0;  // S&P500: 1 ponto = 1.00
   
   if(StringFind(symbol, "NAS100") >= 0 || 
      StringFind(symbol, "NDX") >= 0)
      return 1.0;  // NASDAQ: 1 ponto = 1.00
   
   if(StringFind(symbol, "DAX") >= 0 || 
      StringFind(symbol, "GER") >= 0)
      return 1.0;  // DAX: 1 ponto = 1.00
   
   if(StringFind(symbol, "UK100") >= 0 || 
      StringFind(symbol, "FTSE") >= 0)
      return 1.0;  // FTSE: 1 ponto = 1.00
   
   if(StringFind(symbol, "JP225") >= 0 || 
      StringFind(symbol, "NIKKEI") >= 0)
      return 1.0;  // NIKKEI: 1 ponto = 1.00
   
   // ══════════════════════════════════════════════════════════════
   // 3️⃣ CRIPTOMOEDAS (Bitcoin, Ethereum, etc)
   // ══════════════════════════════════════════════════════════════
   if(StringFind(symbol, "BTC") >= 0 || 
      StringFind(symbol, "BITCOIN") >= 0)
      return 1.0;  // BITCOIN: 1 ponto = $1.00
   
   if(StringFind(symbol, "ETH") >= 0 || 
      StringFind(symbol, "ETHEREUM") >= 0)
      return 1.0;  // ETHEREUM: 1 ponto = $1.00
   
   // ══════════════════════════════════════════════════════════════
   // 4️⃣ PETRÓLEO E COMMODITIES
   // ══════════════════════════════════════════════════════════════
   if(StringFind(symbol, "OIL") >= 0 || 
      StringFind(symbol, "WTI") >= 0 || 
      StringFind(symbol, "BRENT") >= 0)
      return 1.0;  // PETRÓLEO: 1 ponto = $1.00
   
   // ══════════════════════════════════════════════════════════════
   // 5️⃣ FOREX (detecção automática por dígitos)
   // ══════════════════════════════════════════════════════════════
   if(digits == 3)
      return 0.01;   // USDJPY (3 dígitos): 1 pip = 0.01
   else if(digits == 4)
      return 0.01;   // Forex 4 dígitos: 1 pip = 0.01
   else if(digits >= 5)
      return 0.0001; // Forex 5 dígitos: 1 pip = 0.0001
   
   // ══════════════════════════════════════════════════════════════
   // 6️⃣ FALLBACK (caso genérico)
   // ══════════════════════════════════════════════════════════════
   if(digits <= 2)
      return 1.0;   // Ativos com 0-2 casas: 1 ponto = 1.00
   else
      return 0.0001; // Outros: assume Forex
}

//+------------------------------------------------------------------+
//| Converter distância em preço para pontos/pips reais              |
//+------------------------------------------------------------------+
double PriceToPoints(double priceDistance)
{
   return priceDistance / GetDisplayPoint();
}

//+------------------------------------------------------------------+
//| Calcular SL e TP COM AUDITORIA AUTOMÁTICA                        |
//+------------------------------------------------------------------+
void CalculateSLTP(bool isBuy, int bar, double pivotPrice, double &sl, double &tp)
{
   
   // ═══════════════════════════════════════════════════════════════
   // 🧪 TESTE DE CONVERSÃO DE PONTOS (TEMPORÁRIO)
   // ═══════════════════════════════════════════════════════════════
   static bool tested = false;
   if(!tested && EnableDebugLogs)
   {
      Print("");
      Print("╔═══════════════════════════════════════════════════════════╗");
      Print("║  🧪 TESTE DE CONFIGURAÇÃO DE PONTOS - US500              ║");
      Print("╚═══════════════════════════════════════════════════════════╝");
      Print("");
      Print("📊 DADOS DO SÍMBOLO:");
      Print("   Symbol(): ", Symbol());
      Print("   Digits: ", Digits);
      Print("   Point: ", DoubleToString(Point, 8));
      Print("   GetDisplayPoint(): ", DoubleToString(GetDisplayPoint(), 8));
      Print("");
      Print("🧮 TESTE DE CONVERSÃO:");
      Print("   Distância em preço: 55.52");
      Print("   Usando Point: ", DoubleToString(55.52 / Point, 2), " pontos");
      Print("   Usando GetDisplayPoint(): ", DoubleToString(55.52 / GetDisplayPoint(), 2), " pontos");
      Print("   ✅ Esperado para US500: 55.52 pontos");
      Print("");
      Print("╔═══════════════════════════════════════════════════════════╗");
      Print("║  🔍 ANÁLISE:                                             ║");
      if(MathAbs((55.52 / Point) - 55.52) < 0.1)
         Print("║  ✅ Point está CORRETO (1.0)                            ║");
      else
         Print("║  ❌ Point está ERRADO! Deveria ser 1.0                 ║");
      
      if(MathAbs((55.52 / GetDisplayPoint()) - 55.52) < 0.1)
         Print("║  ✅ GetDisplayPoint() está CORRETO (1.0)               ║");
      else
         Print("║  ❌ GetDisplayPoint() está ERRADO! Deveria ser 1.0     ║");
      Print("╚═══════════════════════════════════════════════════════════╝");
      Print("");
      
      tested = true;
   }
   
   
   
   
   
   
   
   
   
   
   // 1️⃣ Calcular ATR
   double atr = iATR(NULL, 0, ATRPeriod, bar);
   double slDistance = atr * StopLossATRMulti;
   
   // 2️⃣ Aplicar limites
   double slDistancePoints = slDistance / Point;
   if(slDistancePoints < MinStopLossPoints)
      slDistance = MinStopLossPoints * Point;
   if(slDistancePoints > MaxStopLossPoints)
      slDistance = MaxStopLossPoints * Point;
   
   // 3️⃣ Entry
   double entry = Close[bar];
   
   // ✅ CONTROLE DE LOG INTELIGENTE
   static int callCount = 0;
   callCount++;
   
   bool isTargetTrade = (StringFind(TimeToString(Time[bar], TIME_DATE|TIME_MINUTES), "2026.01.26 04:00") >= 0);
   bool shouldLogFull = (callCount <= 3 || isTargetTrade);
   bool shouldLogSimple = (callCount > (totalTrades - 3));
   
   // 4️⃣ Calcular SL/TP
   if(UsePivotBasedSL)
   {
      if(isBuy)
      {
         sl = pivotPrice - slDistance;
         double realSLDistance = entry - sl;
         tp = entry + (realSLDistance * RiskRewardRatio);
         
         if(shouldLogFull)
         {
            Print("════════════════════════════════════════");
            Print("🔍 AUDITORIA CalculateSLTP #", callCount);
            if(isTargetTrade) Print("   🎯 TRADE TARGET DETECTADO!");
            Print("   Type: BUY (Compra)");
            Print("   Bar: ", bar, " | Time: ", TimeToString(Time[bar], TIME_DATE|TIME_MINUTES));
            Print("   Entry: ", DoubleToString(entry, Digits));
            Print("   Pivot: ", DoubleToString(pivotPrice, Digits), " (fundo)");
            Print("   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
            Print("   📏 ATR: ", DoubleToString(atr, Digits));
            Print("   📏 SL Distance: ", DoubleToString(slDistance, Digits), " (", DoubleToString(PriceToPoints(slDistance), 2), " pontos)");
            Print("   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
            Print("   ✅ PIVOT-BASED (COMPRA):");
            Print("      SL = Pivot - Distance");
            Print("      SL = ", DoubleToString(pivotPrice, Digits), " - ", DoubleToString(slDistance, Digits));
            Print("      SL = ", DoubleToString(sl, Digits));
            Print("      Real SL Distance = ", DoubleToString(realSLDistance, Digits), " (", DoubleToString(PriceToPoints(realSLDistance), 2), " pontos)");
            Print("      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
            Print("      TP = Entry + (RealDist × R:R)");
            Print("      TP = ", DoubleToString(entry, Digits), " + (", DoubleToString(realSLDistance, Digits), " × ", RiskRewardRatio, ")");
            Print("      TP = ", DoubleToString(tp, Digits));
            Print("      TP Distance = ", DoubleToString((tp-entry), Digits), " (", DoubleToString(PriceToPoints(tp-entry), 2), " pontos)");
         }
      }
      else
      {
         sl = pivotPrice + slDistance;
         double realSLDistance = sl - entry;
         tp = entry - (realSLDistance * RiskRewardRatio);
         
         if(shouldLogFull)
         {
            Print("════════════════════════════════════════");
            Print("🔍 AUDITORIA CalculateSLTP #", callCount);
            if(isTargetTrade) Print("   🎯 TRADE TARGET DETECTADO!");
            Print("   Type: SELL (Venda)");
            Print("   Bar: ", bar, " | Time: ", TimeToString(Time[bar], TIME_DATE|TIME_MINUTES));
            Print("   Entry: ", DoubleToString(entry, Digits));
            Print("   Pivot: ", DoubleToString(pivotPrice, Digits), " (topo)");
            Print("   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
            Print("   📏 ATR: ", DoubleToString(atr, Digits));
            Print("   📏 SL Distance: ", DoubleToString(slDistance, Digits), " (", DoubleToString(PriceToPoints(slDistance), 2), " pontos)");
            Print("   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
            Print("   ✅ PIVOT-BASED (VENDA):");
            Print("      SL = Pivot + Distance");
            Print("      SL = ", DoubleToString(pivotPrice, Digits), " + ", DoubleToString(slDistance, Digits));
            Print("      SL = ", DoubleToString(sl, Digits));
            Print("      Real SL Distance = ", DoubleToString(realSLDistance, Digits), " (", DoubleToString(PriceToPoints(realSLDistance), 2), " pontos)");
            Print("      ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
            Print("      TP = Entry - (RealDist × R:R)");
            Print("      TP = ", DoubleToString(entry, Digits), " - (", DoubleToString(realSLDistance, Digits), " × ", RiskRewardRatio, ")");
            Print("      TP = ", DoubleToString(tp, Digits));
            Print("      TP Distance = ", DoubleToString((entry-tp), Digits), " (", DoubleToString(PriceToPoints(entry-tp), 2), " pontos)");
         }
      }
   }
   else
   {
      // ENTRY-BASED
      if(isBuy)
      {
         sl = entry - slDistance;
         tp = entry + (slDistance * RiskRewardRatio);
         
         if(shouldLogFull)
         {
            Print("════════════════════════════════════════");
            Print("🔍 AUDITORIA CalculateSLTP #", callCount);
            Print("   Type: BUY (Compra)");
            Print("   Entry: ", DoubleToString(entry, Digits));
            Print("   SL = ", DoubleToString(sl, Digits), " (", DoubleToString(PriceToPoints(slDistance), 2), " pontos abaixo)");
            Print("   TP = ", DoubleToString(tp, Digits), " (", DoubleToString(PriceToPoints(slDistance * RiskRewardRatio), 2), " pontos acima)");
         }
      }
      else
      {
         sl = entry + slDistance;
         tp = entry - (slDistance * RiskRewardRatio);
         
         if(shouldLogFull)
         {
            Print("════════════════════════════════════════");
            Print("🔍 AUDITORIA CalculateSLTP #", callCount);
            Print("   Type: SELL (Venda)");
            Print("   Entry: ", DoubleToString(entry, Digits));
            Print("   SL = ", DoubleToString(sl, Digits), " (", DoubleToString(PriceToPoints(slDistance), 2), " pontos acima)");
            Print("   TP = ", DoubleToString(tp, Digits), " (", DoubleToString(PriceToPoints(slDistance * RiskRewardRatio), 2), " pontos abaixo)");
         }
      }
   }
   
   // 5️⃣ Normalizar
   sl = NormalizeDouble(sl, Digits);
   tp = NormalizeDouble(tp, Digits);
   
   // 6️⃣ RESUMO FINAL
   if(shouldLogFull)
   {
      double finalSLDist = MathAbs(entry - sl);
      double finalTPDist = MathAbs(tp - entry);
      double finalRR = finalTPDist / finalSLDist;
      
      Print("   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━");
      Print("   📊 RESULTADO:");
      Print("      Entry: ", DoubleToString(entry, Digits));
      Print("      SL:    ", DoubleToString(sl, Digits), " (", DoubleToString(PriceToPoints(finalSLDist), 2), " pontos)");
      Print("      TP:    ", DoubleToString(tp, Digits), " (", DoubleToString(PriceToPoints(finalTPDist), 2), " pontos)");
      Print("      R:R = 1:", DoubleToString(finalRR, 2));
      Print("   💰 Lucro esperado: +$", DoubleToString(InitialBalance * RiskPerTrade / 100 * RiskRewardRatio, 2));
      Print("════════════════════════════════════════");
   }
   else if(shouldLogSimple)
   {
      // ✅ CONVERSÃO AUTOMÁTICA
      double finalSLDist = MathAbs(entry - sl);
      double finalTPDist = MathAbs(tp - entry);
      
      Print("📊 Trade #", callCount, " | ", (isBuy ? "BUY" : "SELL"), 
            " | Entry:", DoubleToString(entry, Digits),
            " | SL:", DoubleToString(PriceToPoints(finalSLDist), 2), "pts",
            " | TP:", DoubleToString(PriceToPoints(finalTPDist), 2), "pts");
   }
}

//+------------------------------------------------------------------+
//| Verificar Filtros de Entrada                                     |
//+------------------------------------------------------------------+
bool PassEntryFilters(bool isBuy, int bar)
{
   // Filtro de Tendência
   if(UseTrendFilter)
   {
      double ema = iMA(NULL, TrendTimeframe, TrendEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 
                       iBarShift(NULL, TrendTimeframe, Time[bar]));
      
      if(isBuy && Close[bar] < ema)
         return false;
      if(!isBuy && Close[bar] > ema)
         return false;
   }
   
   // Filtro de ATR
   if(UseATRFilter)
   {
      double atr = iATR(NULL, 0, ATRPeriod, bar);
      
      if(atr < MinATR)
         return false;
   }
   
   // Filtro de Horário
   if(UseTimeFilter)
   {
      int hour = TimeHour(Time[bar]);
      int dayOfWeek = TimeDayOfWeek(Time[bar]);
      
      if(hour < StartHour || hour > EndHour)
         return false;
      
      if(AvoidFridayLate && dayOfWeek == 5 && hour > 15)
         return false;
   }
   
   // Filtro de Spread
   if(UseSpreadFilter)
   {
      double spread = (Ask - Bid) / Point;
      
      if(spread > MaxSpreadPoints)
         return false;
   }
   
   // Filtro de RSI
   if(UseRSIFilter)
   {
      double rsi = iRSI(NULL, 0, RSIPeriod, PRICE_CLOSE, bar);
      
      if(isBuy && rsi < RSILevelBuy)
         return false;
      if(!isBuy && rsi > RSILevelSell)
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Calcular Métricas de Performance                                |
//+------------------------------------------------------------------+
void CalculateMetrics()
{
   currentBalance = InitialBalance + totalProfitUSD - totalLossUSD;
   
   if(currentBalance > maxBalance)
      maxBalance = currentBalance;
   
   double currentDD = maxBalance - currentBalance;
   if(currentDD > maxDrawdown)
      maxDrawdown = currentDD;
   
   if(totalLossUSD > 0)
      profitFactor = totalProfitUSD / totalLossUSD;
   else
      profitFactor = totalProfitUSD > 0 ? 999.99 : 0.0;
}

//+------------------------------------------------------------------+
//| Registrar Trade (compatibilidade)                                |
//+------------------------------------------------------------------+
void RegisterTrade(bool isBuy, int bar, double entry, double sl, double tp)
{
   // Esta função é obsoleta no código novo
   // O registro é feito diretamente em GenerateBuySignal/GenerateSellSignal
   // Mantida apenas para evitar erros de compilação
   Print("⚠️ RegisterTrade obsoleta - registro feito diretamente nos Generate...Signal()");
}

//+------------------------------------------------------------------+
//| Desenhar Resultado - SEM SETA NA SAÍDA                           |
//+------------------------------------------------------------------+
void DrawTradeResult(int tradeIdx)
{
   // Proteções
   if(tradeIdx < 0 || tradeIdx >= totalTrades) return;
   if(trades[tradeIdx].status == 0) return;
   
   bool isWin = (trades[tradeIdx].status == 1);
   datetime openTime = trades[tradeIdx].openTime;
   datetime closeTime = trades[tradeIdx].closeTime;
   double entryPrice = trades[tradeIdx].entryPrice;
   double exitPrice = trades[tradeIdx].exitPrice;
   
   // ✅ DEBUG APENAS PARA PRIMEIROS 3 E ÚLTIMOS 3 TRADES
   static int drawCount = 0;
   drawCount++;
   bool shouldDebug = (drawCount <= 3 || drawCount > (totalTrades - 3));
   
   if(shouldDebug)
   {
      Print("════════════════════════════════════════");
      Print("🎨 DESENHANDO LINHA - Trade #", tradeIdx);
      Print("   Status: ", isWin ? "WIN" : "LOSS");
      Print("   Type: ", trades[tradeIdx].isBuy ? "BUY" : "SELL");
      Print("   ");
      Print("   📍 PONTO INICIAL (Entry):");
      Print("      Time: ", TimeToString(openTime, TIME_DATE|TIME_MINUTES));
      Print("      Price: ", DoubleToString(entryPrice, Digits));
      int openBar = iBarShift(NULL, 0, openTime);
      Print("      Bar Index: ", openBar);
      Print("   ");
      Print("   📍 PONTO FINAL (Exit):");
      Print("      Time: ", TimeToString(closeTime, TIME_DATE|TIME_MINUTES));
      Print("      Price: ", DoubleToString(exitPrice, Digits));
      int closeBar = iBarShift(NULL, 0, closeTime);
      Print("      Bar Index: ", closeBar);
      Print("   ");
      Print("   📊 VALIDAÇÃO DA VELA DE SAÍDA:");
      Print("      High[", closeBar, "]: ", DoubleToString(High[closeBar], Digits));
      Print("      Low[", closeBar, "]: ", DoubleToString(Low[closeBar], Digits));
      Print("      Open[", closeBar, "]: ", DoubleToString(Open[closeBar], Digits));
      Print("      Close[", closeBar, "]: ", DoubleToString(Close[closeBar], Digits));
      
      bool priceInsideBar = (exitPrice >= Low[closeBar] && exitPrice <= High[closeBar]);
      Print("      Exit Price dentro da vela? ", priceInsideBar ? "✅ SIM" : "❌ NÃO!");
      Print("════════════════════════════════════════");
   }
   
   if(openTime == 0 || closeTime == 0 || exitPrice == 0) return;
   
   // Deletar linhas HLINE antigas
   if(trades[tradeIdx].linesDrawn)
   {
      ObjectDelete(0, trades[tradeIdx].entryLineName);
      ObjectDelete(0, trades[tradeIdx].slLineName);
      ObjectDelete(0, trades[tradeIdx].tpLineName);
      trades[tradeIdx].linesDrawn = false;
   }
   
   string baseName = prefix + "RESULT_" + IntegerToString(tradeIdx) + "_" + TimeToString(openTime, TIME_SECONDS);
   
   // 1️⃣ LINHA PONTILHADA
   string lineName = baseName + "_LINE";
   
   if(ObjectFind(0, lineName) < 0)
   {
      if(ObjectCreate(0, lineName, OBJ_TREND, 0, openTime, entryPrice, closeTime, exitPrice))
      {
         ObjectSetInteger(0, lineName, OBJPROP_COLOR, isWin ? clrDodgerBlue : clrRed);
         ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
         ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, lineName, OBJPROP_RAY_LEFT, false);
      }
   }
   
   // 2️⃣ CÍRCULO NO PONTO DE SAÍDA
   string circleName = baseName + "_CIRCLE";
   
   if(ObjectFind(0, circleName) < 0)
   {
      if(ObjectCreate(0, circleName, OBJ_ARROW, 0, closeTime, exitPrice))
      {
         ObjectSetInteger(0, circleName, OBJPROP_ARROWCODE, 159);
         ObjectSetInteger(0, circleName, OBJPROP_COLOR, isWin ? clrDodgerBlue : clrRed);
         ObjectSetInteger(0, circleName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, circleName, OBJPROP_BACK, false);
         ObjectSetInteger(0, circleName, OBJPROP_SELECTABLE, false);
      }
   }
   
   // 3️⃣ TEXTO COM RESULTADO
   string textName = baseName + "_TEXT";
   
   if(ObjectFind(0, textName) < 0)
   {
      double textPrice;
      if(trades[tradeIdx].isBuy)
         textPrice = exitPrice + (50 * Point);
      else
         textPrice = exitPrice - (50 * Point);
      
      string text;
      if(isWin)
         text = StringFormat("WIN +$%.2f", trades[tradeIdx].profitUSD);
      else
         text = StringFormat("LOSS -$%.2f", MathAbs(trades[tradeIdx].profitUSD));
      
      if(ObjectCreate(0, textName, OBJ_TEXT, 0, closeTime, textPrice))
      {
         ObjectSetString(0, textName, OBJPROP_TEXT, text);
         ObjectSetInteger(0, textName, OBJPROP_COLOR, isWin ? clrDodgerBlue : clrRed);
         ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 8);
         ObjectSetString(0, textName, OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(0, textName, OBJPROP_ANCHOR, ANCHOR_LEFT);
         ObjectSetInteger(0, textName, OBJPROP_BACK, false);
         ObjectSetInteger(0, textName, OBJPROP_SELECTABLE, false);
      }
   }
   
   if(shouldDebug)
   {
      Print("🎨 ", isWin ? "WIN" : "LOSS", " | Trade #", tradeIdx, 
            " | Entry: ", DoubleToString(entryPrice, Digits), 
            " → Exit: ", DoubleToString(exitPrice, Digits));
   }
}

//+------------------------------------------------------------------+
//| Desenhar Resultados de TODOS os Trades Fechados                  |
//+------------------------------------------------------------------+
void DrawAllClosedTradeResults()
{
   if(!ShowSLTPLines)
      return;
   
   int drawn = 0;
   
   for(int i = 0; i < totalTrades; i++)
   {
      if(trades[i].status != 0)
      {
         DrawTradeResult(i);
         drawn++;
      }
   }
   
   if(drawn > 0)
      Print("🎨 Desenhados resultados de ", drawn, " trades fechados");
}
// Bloco 9

//+------------------------------------------------------------------+
//| Desenhar Setup Completo - APENAS LINHAS SL/TP/ENTRY             |
//+------------------------------------------------------------------+
void DrawTradeSetup(bool isBuy, int bar, double entry, double sl, double tp, double pivot)
{
   string suffix = "_" + TimeToString(Time[bar], TIME_DATE|TIME_MINUTES);
   
   // ═══ NÃO DESENHAR SETAS AQUI - OS BUFFERS JÁ FAZEM ISSO! ═══
   // As setas de confirmação são desenhadas pelos buffers:
   // - BuyConfirmBuf[bar] → Seta AZUL (código 233)
   // - SellConfirmBuf[bar] → Seta VERMELHA (código 234)
   
   // ═══ DESENHAR APENAS LINHAS SL/TP/ENTRY - NO BACKTESTING ═══
   if(ShowSLTPLines && EnableBacktest)
   {
      // Registrar trade PRIMEIRO
      RegisterTrade(isBuy, bar, entry, sl, tp);
      
      // Obter o trade recém-criado
      int tradeIndex = totalTrades - 1;
      
      if(tradeIndex >= 0)
      {
         // 🟡 LINHA DE ENTRADA (AMARELA - SÓLIDA) - OBJ_HLINE
         if(!ObjectCreate(0, trades[tradeIndex].entryLineName, OBJ_HLINE, 0, 0, entry))
         {
            Print("❌ Erro ao criar linha de entrada: ", GetLastError());
         }
         else
         {
            ObjectSetInteger(0, trades[tradeIndex].entryLineName, OBJPROP_COLOR, clrGold);
            ObjectSetInteger(0, trades[tradeIndex].entryLineName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, trades[tradeIndex].entryLineName, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, trades[tradeIndex].entryLineName, OBJPROP_BACK, true); // No fundo
            ObjectSetInteger(0, trades[tradeIndex].entryLineName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, trades[tradeIndex].entryLineName, OBJPROP_SELECTED, false);
         }
         
         // 🔴 LINHA DE STOP LOSS (VERMELHA - TRACEJADA) - OBJ_HLINE
         if(!ObjectCreate(0, trades[tradeIndex].slLineName, OBJ_HLINE, 0, 0, sl))
         {
            Print("❌ Erro ao criar linha SL: ", GetLastError());
         }
         else
         {
            ObjectSetInteger(0, trades[tradeIndex].slLineName, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, trades[tradeIndex].slLineName, OBJPROP_STYLE, STYLE_DASH);
            ObjectSetInteger(0, trades[tradeIndex].slLineName, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, trades[tradeIndex].slLineName, OBJPROP_BACK, true);
            ObjectSetInteger(0, trades[tradeIndex].slLineName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, trades[tradeIndex].slLineName, OBJPROP_SELECTED, false);
         }
         
         // 🔵 LINHA DE TAKE PROFIT (AZUL - TRACEJADA) - OBJ_HLINE
         if(!ObjectCreate(0, trades[tradeIndex].tpLineName, OBJ_HLINE, 0, 0, tp))
         {
            Print("❌ Erro ao criar linha TP: ", GetLastError());
         }
         else
         {
            ObjectSetInteger(0, trades[tradeIndex].tpLineName, OBJPROP_COLOR, clrDodgerBlue);
            ObjectSetInteger(0, trades[tradeIndex].tpLineName, OBJPROP_STYLE, STYLE_DASH);
            ObjectSetInteger(0, trades[tradeIndex].tpLineName, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, trades[tradeIndex].tpLineName, OBJPROP_BACK, true);
            ObjectSetInteger(0, trades[tradeIndex].tpLineName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, trades[tradeIndex].tpLineName, OBJPROP_SELECTED, false);
         }
         
         trades[tradeIndex].linesDrawn = true;
         
         Print("✅ LINHAS CRIADAS | Entry: ", DoubleToString(entry, Digits), 
               " | SL: ", DoubleToString(sl, Digits), 
               " | TP: ", DoubleToString(tp, Digits));
      }
      else
      {
         Print("❌ ERRO: tradeIndex inválido (", tradeIndex, ")");
      }
   }
   else
   {
      if(!ShowSLTPLines)
         Print("⚠️ Linhas não desenhadas - ShowSLTPLines = FALSE");
      if(!EnableBacktest)
         Print("⚠️ Trade não registrado - EnableBacktest = FALSE");
   }
}

//+------------------------------------------------------------------+
//| Criar Label de Texto                                            |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, int fontSize, color clr, string font)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}


// Bloco 10

//+------------------------------------------------------------------+
//| Criar Painel Informativo com Todas as Seções                    |
//+------------------------------------------------------------------+
void CreateInfoPanel()
{
   if(!ShowInfoPanel) return;
   
   string panelName = prefix + "Panel";
   int x = 10;
   int y = 20;
   int width = 340;
   int height = 360;
   
   // ═══ FUNDO DO PAINEL ═══
   ObjectCreate(0, panelName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, panelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, panelName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, panelName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, panelName, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, panelName, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, panelName, OBJPROP_BGCOLOR, C'15,15,20');
   ObjectSetInteger(0, panelName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, panelName, OBJPROP_COLOR, clrGold);
   ObjectSetInteger(0, panelName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, panelName, OBJPROP_BACK, false);
   ObjectSetInteger(0, panelName, OBJPROP_SELECTABLE, false);
   
   // ═══ CABEÇALHO ═══
   CreateLabel(prefix + "Title", "⭐ MAIS PIVOT PRO ⭐", x + 15, y + 10, 13, clrGold, "Arial Black");
   CreateLabel(prefix + "Version", "v3.0 | Backtest Avançado", x + 15, y + 32, 8, C'120,120,120', "Arial");
   
   // ═══ INFO DE VARREDURA ═══
   CreateLabel(prefix + "ScanInfo", "Varredura: ...", x + 15, y + 48, 7, C'150,150,150', "Arial");
   
   // ═══ SEÇÃO: STATUS ═══
   CreateLabel(prefix + "SectionStatus", "━━━ STATUS ━━━", x + 15, y + 68, 9, clrGold, "Arial Bold");
   CreateLabel(prefix + "Label1", "Sistema:", x + 15, y + 88, 9, C'200,200,200', "Arial");
   CreateLabel(prefix + "Label2", "Ultimo Sinal:", x + 15, y + 105, 9, C'200,200,200', "Arial");
   CreateLabel(prefix + "Label3", "Proxima Barra:", x + 15, y + 122, 9, C'200,200,200', "Arial");
   
   CreateLabel(prefix + "Value1", "...", x + 160, y + 88, 9, clrLime, "Arial Bold");
   CreateLabel(prefix + "Value2", "...", x + 160, y + 105, 9, clrGray, "Arial");
   CreateLabel(prefix + "Value3", "...", x + 160, y + 122, 9, clrAqua, "Courier New");
   
   // ═══ SEÇÃO: PERFORMANCE ═══
   CreateLabel(prefix + "SectionPerf", "━━━ PERFORMANCE ━━━", x + 15, y + 150, 9, clrDodgerBlue, "Arial Bold");
   CreateLabel(prefix + "Label4", "Vitorias:", x + 15, y + 170, 9, C'200,200,200', "Arial");
   CreateLabel(prefix + "Label5", "Derrotas:", x + 15, y + 187, 9, C'200,200,200', "Arial");
   CreateLabel(prefix + "Label6", "Win Rate:", x + 15, y + 204, 9, C'200,200,200', "Arial");
   CreateLabel(prefix + "Label7", "Profit Factor:", x + 15, y + 221, 9, C'200,200,200', "Arial");
   
   CreateLabel(prefix + "Value4", "0", x + 160, y + 170, 9, clrLime, "Arial Bold");
   CreateLabel(prefix + "Value5", "0", x + 160, y + 187, 9, clrRed, "Arial Bold");
   CreateLabel(prefix + "Value6", "0.0%", x + 160, y + 204, 9, clrGray, "Arial Bold");
   CreateLabel(prefix + "Value7", "0.00", x + 160, y + 221, 9, clrGray, "Arial Bold");
   
   // ═══ SEÇÃO: FINANCEIRO ═══
   CreateLabel(prefix + "SectionFin", "━━━ FINANCEIRO ━━━", x + 15, y + 250, 9, clrLime, "Arial Bold");
   CreateLabel(prefix + "Label8", "Balance:", x + 15, y + 270, 9, C'200,200,200', "Arial");
   CreateLabel(prefix + "Label9", "Lucro Total:", x + 15, y + 287, 9, C'200,200,200', "Arial");
   CreateLabel(prefix + "Label10", "Perda Total:", x + 15, y + 304, 9, C'200,200,200', "Arial");
   CreateLabel(prefix + "Label11", "Max DD:", x + 15, y + 321, 9, C'200,200,200', "Arial");
   
   CreateLabel(prefix + "Value8", "$10,000.00", x + 160, y + 270, 9, clrWhite, "Arial Bold");
   CreateLabel(prefix + "Value9", "$0.00", x + 160, y + 287, 9, clrLime, "Arial Bold");
   CreateLabel(prefix + "Value10", "$0.00", x + 160, y + 304, 9, clrRed, "Arial Bold");
   CreateLabel(prefix + "Value11", "$0.00", x + 160, y + 321, 9, clrOrange, "Arial Bold");
   
   // ═══ RODAPÉ ═══
   CreateLabel(prefix + "Footer", "Risk: 0.5% | RR: 2.0", x + 15, y + 343, 7, C'100,100,100', "Arial");
}

// Bloco 11

//+------------------------------------------------------------------+
//| Atualizar Painel com Todas as Informações                       |
//+------------------------------------------------------------------+
void UpdateInfoPanel()
{
   if(!ShowInfoPanel) return;
   
   // ✅ PROTEÇÃO: Verificar se buffers estão inicializados
   if(ArraySize(BuySignalBuf) == 0 || ArraySize(SellSignalBuf) == 0)
   {
      Print("⚠️ UpdateInfoPanel: Buffers não inicializados ainda");
      return;
   }
   
   // Atualizar apenas uma vez por segundo
   static datetime lastUpdate = 0;
   if(TimeCurrent() == lastUpdate) return;
   lastUpdate = TimeCurrent();
   
   // ═══ INFO DE VARREDURA COM PERÍODO COMPLETO ═══
   string startDateStr = "N/A";
   string endDateStr = "N/A";
   string daysStr = "0";
   
   // Formatar data inicial
   if(firstBarProcessed > 0)
   {
      MqlDateTime dtStart;
      TimeToStruct(firstBarProcessed, dtStart);
      startDateStr = StringFormat("%02d/%02d/%04d", dtStart.day, dtStart.mon, dtStart.year);
   }
   
   // Formatar data final
   if(lastBarProcessed > 0)
   {
      MqlDateTime dtEnd;
      TimeToStruct(lastBarProcessed, dtEnd);
      endDateStr = StringFormat("%02d/%02d/%04d", dtEnd.day, dtEnd.mon, dtEnd.year);
   }
   
   // Calcular dias
   if(totalDaysCovered > 0)
   {
      daysStr = IntegerToString(totalDaysCovered);
   }
   
   // Montar texto da varredura COM DATAS
   string scanInfo = StringFormat("Inicio: %s | Fim: %s | %s dias", startDateStr, endDateStr, daysStr);
   ObjectSetString(0, prefix + "ScanInfo", OBJPROP_TEXT, scanInfo);
   
   // ═══ STATUS DO SISTEMA ═══
   string status = "Monitorando";
   color statusColor = clrLime;
   
   if(!PassEntryFilters(true, 1) && !PassEntryFilters(false, 1))
   {
      status = "Filtros Bloqueados";
      statusColor = clrOrange;
   }
   
   ObjectSetString(0, prefix + "Value1", OBJPROP_TEXT, status);
   ObjectSetInteger(0, prefix + "Value1", OBJPROP_COLOR, statusColor);
   
   // ═══ ÚLTIMO SINAL (✅ CORREÇÃO DEFINITIVA) ═══
   string lastSignal = "Nenhum";
   color lastSignalColor = clrGray;
   
   // ✅ PROTEÇÃO TRIPLA: Verificar tamanho dos buffers
   int buyBufSize = ArraySize(BuySignalBuf);
   int sellBufSize = ArraySize(SellSignalBuf);
   
   // ✅ Só processar se houver dados suficientes
   if(buyBufSize > 1 && sellBufSize > 1)
   {
      // ✅ Limitar busca ao menor dos dois tamanhos
      int maxSearch = MathMin(100, MathMin(buyBufSize, sellBufSize));
      
      for(int i = 1; i < maxSearch; i++)
      {
         // ✅ VERIFICAÇÃO QUÁDRUPLA: índice válido + tamanho + não-zero + não-vazio
         if(i < buyBufSize && 
            i < ArraySize(BuySignalBuf) && 
            BuySignalBuf[i] != 0.0 && 
            BuySignalBuf[i] != EMPTY_VALUE)
         {
            lastSignal = StringFormat("COMPRA ha %d barras", i);
            lastSignalColor = clrDodgerBlue;
            break;
         }
         
         if(i < sellBufSize && 
            i < ArraySize(SellSignalBuf) && 
            SellSignalBuf[i] != 0.0 && 
            SellSignalBuf[i] != EMPTY_VALUE)
         {
            lastSignal = StringFormat("VENDA ha %d barras", i);
            lastSignalColor = clrOrangeRed;
            break;
         }
      }
   }
   
   ObjectSetString(0, prefix + "Value2", OBJPROP_TEXT, lastSignal);
   ObjectSetInteger(0, prefix + "Value2", OBJPROP_COLOR, lastSignalColor);
   
   // ═══ PRÓXIMA BARRA ═══
   datetime currentTime = TimeCurrent();
   datetime barTime = Time[0];
   int periodSeconds = PeriodSeconds();
   int elapsedSeconds = (int)(currentTime - barTime);
   int secondsLeft = periodSeconds - elapsedSeconds;
   
   if(secondsLeft < 0) secondsLeft = 0;
   
   int minutes = secondsLeft / 60;
   int seconds = secondsLeft % 60;
   
   string nextCheck = StringFormat("%02d:%02d", minutes, seconds);
   ObjectSetString(0, prefix + "Value3", OBJPROP_TEXT, nextCheck);
   ObjectSetInteger(0, prefix + "Value3", OBJPROP_COLOR, clrAqua);
   
   // ═══ PERFORMANCE - VITÓRIAS ═══
   ObjectSetString(0, prefix + "Value4", OBJPROP_TEXT, IntegerToString(totalWins));
   ObjectSetInteger(0, prefix + "Value4", OBJPROP_COLOR, totalWins > 0 ? clrLime : clrGray);
   
   // ═══ PERFORMANCE - DERROTAS ═══
   ObjectSetString(0, prefix + "Value5", OBJPROP_TEXT, IntegerToString(totalLosses));
   ObjectSetInteger(0, prefix + "Value5", OBJPROP_COLOR, totalLosses > 0 ? clrRed : clrGray);
   
   // ═══ WIN RATE ═══
   double winRate = 0.0;
   if(totalWins + totalLosses > 0)
      winRate = (totalWins * 100.0) / (totalWins + totalLosses);
   
   string winRateText = StringFormat("%.1f%%", winRate);
   color winRateColor = clrGray;
   if(winRate >= 60) winRateColor = clrLime;
   else if(winRate >= 50) winRateColor = clrYellow;
   else if(totalWins + totalLosses > 0) winRateColor = clrOrange;
   
   ObjectSetString(0, prefix + "Value6", OBJPROP_TEXT, winRateText);
   ObjectSetInteger(0, prefix + "Value6", OBJPROP_COLOR, winRateColor);
   
   // ═══ PROFIT FACTOR ═══
   string pfText = "0.00";
   if(profitFactor > 0)
      pfText = StringFormat("%.2f", profitFactor);
   
   color pfColor = clrGray;
   if(profitFactor >= 2.0) pfColor = clrLime;
   else if(profitFactor >= 1.5) pfColor = clrYellow;
   else if(profitFactor >= 1.0) pfColor = clrOrange;
   else if(profitFactor > 0) pfColor = clrRed;
   
   ObjectSetString(0, prefix + "Value7", OBJPROP_TEXT, pfText);
   ObjectSetInteger(0, prefix + "Value7", OBJPROP_COLOR, pfColor);
   
   // ═══ BALANCE ATUAL ═══
   string balanceText = StringFormat("$%s", FormatMoney(currentBalance));
   color balanceColor = currentBalance >= InitialBalance ? clrLime : clrRed;
   
   ObjectSetString(0, prefix + "Value8", OBJPROP_TEXT, balanceText);
   ObjectSetInteger(0, prefix + "Value8", OBJPROP_COLOR, balanceColor);
   
   // ═══ LUCRO TOTAL ═══
   string profitText = totalProfitUSD > 0 ? StringFormat("+$%s", FormatMoney(totalProfitUSD)) : "$0.00";
   ObjectSetString(0, prefix + "Value9", OBJPROP_TEXT, profitText);
   ObjectSetInteger(0, prefix + "Value9", OBJPROP_COLOR, totalProfitUSD > 0 ? clrLime : clrGray);
   
   // ═══ PERDA TOTAL ═══
   string lossText = totalLossUSD > 0 ? StringFormat("-$%s", FormatMoney(totalLossUSD)) : "$0.00";
   ObjectSetString(0, prefix + "Value10", OBJPROP_TEXT, lossText);
   ObjectSetInteger(0, prefix + "Value10", OBJPROP_COLOR, totalLossUSD > 0 ? clrRed : clrGray);
   
   // ═══ MAX DRAWDOWN ═══
   string ddText = maxDrawdown > 0 ? StringFormat("-$%s", FormatMoney(maxDrawdown)) : "$0.00";
   color ddColor = clrGray;
   
   if(maxDrawdown > InitialBalance * 0.20) 
      ddColor = clrRed;
   else if(maxDrawdown > InitialBalance * 0.10) 
      ddColor = clrOrange;
   else if(maxDrawdown > 0) 
      ddColor = clrYellow;
   
   ObjectSetString(0, prefix + "Value11", OBJPROP_TEXT, ddText);
   ObjectSetInteger(0, prefix + "Value11", OBJPROP_COLOR, ddColor);
   
   // ═══ ATUALIZAR RODAPÉ ═══
   string footerText = StringFormat("Risk: %.1f%% | RR: %.1f", RiskPerTrade, RiskRewardRatio);
   ObjectSetString(0, prefix + "Footer", OBJPROP_TEXT, footerText);
}

//+------------------------------------------------------------------+
//| Formatar Valores Monetários com Separador de Milhares           |
//+------------------------------------------------------------------+
string FormatMoney(double value)
{
   string result = DoubleToString(MathAbs(value), 2);
   
   // Adicionar separador de milhares
   int len = StringLen(result);
   int dotPos = StringFind(result, ".");
   
   if(dotPos < 0) dotPos = len;
   
   string formatted = "";
   int counter = 0;
   
   for(int i = dotPos - 1; i >= 0; i--)
   {
      if(counter == 3)
      {
         formatted = "," + formatted;
         counter = 0;
      }
      formatted = StringSubstr(result, i, 1) + formatted;
      counter++;
   }
   
   // Adicionar parte decimal
   if(dotPos < len)
      formatted += StringSubstr(result, dotPos);
   
   return formatted;
}
//+------------------------------------------------------------------+

