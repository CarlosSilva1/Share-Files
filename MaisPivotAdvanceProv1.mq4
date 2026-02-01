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
input int PivotStrength = 5;                // Força do Pivô (barras)
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
input bool UsePivotBasedSL = false;          // 🎯 SL baseado no Pivô (false = baseado na Entry)

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
string lastAlertMessage = "";

// Controle de Varredura
int barsToScan = 0;
int lastScanPercentage = -1;
bool needsReset = false;
int totalBarsAvailable = 0;

// ═══ CONTROLE DE TRIGGER DE VELA ═══
datetime lastProcessedBarTime = 0;  // Última barra processada
bool isNewBar = false;               // Flag de nova barra
bool isScanningHistory = true;       // Flag de varredura inicial
int initialBars = 0;                 // Total de barras no início

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
   double exitPrice;     // ✅ ADICIONAR ESTA LINHA
   int barIndex;
   string entryLineName;
   string slLineName;
   string tpLineName;
   bool linesDrawn;
   bool resultDrawn;     // ✅ ADICIONAR ESTA LINHA
};

TradeInfo trades[];
int totalTrades = 0;

// ═══ CONTROLE DE LINHAS POR TRADE ═══
struct LineControl
{
   int tradeIndex;        // Índice do trade associado
   string entryLine;      // Nome da linha Entry
   string slLine;         // Nome da linha SL
   string tpLine;         // Nome da linha TP
   bool active;           // Linha está ativa?
   datetime created;      // Quando foi criada
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

// Controle de atualização
datetime lastTradeCheck = 0;
datetime lastPanelUpdate = 0;
datetime lastBarTime = 0;

// ═══ RASTREAMENTO DO PERÍODO DE VARREDURA ═══
datetime firstBarProcessed = 0;
datetime lastBarProcessed = 0;
int totalDaysCovered = 0;

// ═══ CONTROLE DE LIMPEZA DE LINHAS ═══
datetime lastChartScroll = 0;
int lastVisibleBars = 0;
ENUM_TIMEFRAMES lastPeriod = PERIOD_CURRENT;
int lastFirstVisibleBar = 0;
bool chartMoved = false;

// ═══════════════════════════════════════════════════════════════
// ═══ CONTROLE DE REVERSE CLOSE (NOVO) ═══
// ═══════════════════════════════════════════════════════════════
struct ActiveTradeControl
{
   bool hasPosition;          // Tem posição aberta?
   bool isBuy;                // É compra ou venda?
   datetime openTime;         // Quando abriu
   double entryPrice;         // Preço de entrada
   double slPrice;            // Stop Loss
   double tpPrice;            // Take Profit
   int tradeIndex;            // Índice no array trades[]
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
   SetIndexStyle(2, DRAW_ARROW, EMPTY, 2, BuyConfirmColor);
   SetIndexArrow(2, 233);
   SetIndexLabel(2, "Confirmação de Compra");
   
   // ➡️ Buffer 3: Confirmação de Venda (SETA VERMELHA)
   SetIndexBuffer(3, SellConfirmBuf);
   SetIndexStyle(3, DRAW_ARROW, EMPTY, 2, SellConfirmColor);
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
      barsToScan = 50; // Apenas últimas 50 barras
   }
   else
   {
      // Calcular quantas barras varrer
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
   
   // ═══════════════════════════════════════════════════���═══════════
   // ═══ INICIALIZAR CONTROLE DE REVERSE CLOSE (NOVO) ═══
   // ═══════════════════════════════════════════════════════════════
   activeTrade.hasPosition = false;
   activeTrade.isBuy = false;
   activeTrade.openTime = 0;
   activeTrade.entryPrice = 0;
   activeTrade.slPrice = 0;
   activeTrade.tpPrice = 0;
   activeTrade.tradeIndex = -1;
   
   Print("MAIS PIVOT PRO iniciado | Barras disponíveis: ", totalBarsAvailable, 
         " | Varredura: ", barsToScan, " barras (", ScanPercentage, "%)");
   Print("🔄 Reverse Close: ", (UseReverseClose ? "ATIVADO" : "DESATIVADO"));
   
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
      case REASON_REMOVE: reasonText = "Removido do gráfico"; break;
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
//| Calcular Estatísticas (compatibilidade)                         |
//+------------------------------------------------------------------+
void CalculateStats()
{
   CalculateMetrics();
}

//+------------------------------------------------------------------+
//| Limpar Linhas de Trades Encerrados                               |
//+------------------------------------------------------------------+
void CleanupClosedTradeLines()
{
   for(int i = totalActiveLines - 1; i >= 0; i--)
   {
      if(!activeLines[i].active)
         continue;
         
      int tradeIdx = activeLines[i].tradeIndex;
      
      // Verificar se o trade foi encerrado
      if(tradeIdx >= 0 && tradeIdx < totalTrades)
      {
         if(trades[tradeIdx].status != 0) // Trade fechado (Win ou Loss)
         {
            // Deletar as linhas
            ObjectDelete(0, activeLines[i].entryLine);
            ObjectDelete(0, activeLines[i].slLine);
            ObjectDelete(0, activeLines[i].tpLine);
            
            // Marcar como inativa
            activeLines[i].active = false;
            
            Print("🗑️ Linhas removidas para trade #", tradeIdx, 
                  " (", trades[tradeIdx].status == 1 ? "WIN" : "LOSS", ")");
         }
      }
   }
   
   // Compactar array removendo linhas inativas
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
}

//+------------------------------------------------------------------+
//| Registrar Linhas de um Trade                                     |
//+------------------------------------------------------------------+
void RegisterTradeLines(int tradeIndex, string entry, string sl, string tp)
{
   // Aumentar array se necessário
   if(totalActiveLines >= ArraySize(activeLines))
      ArrayResize(activeLines, totalActiveLines + 10);
   
   // Registrar linhas
   activeLines[totalActiveLines].tradeIndex = tradeIndex;
   activeLines[totalActiveLines].entryLine = entry;
   activeLines[totalActiveLines].slLine = sl;
   activeLines[totalActiveLines].tpLine = tp;
   activeLines[totalActiveLines].active = true;
   activeLines[totalActiveLines].created = TimeCurrent();
   
   totalActiveLines++;
   
   Print("📌 Linhas registradas para trade #", tradeIndex);
}

//+------------------------------------------------------------------+
//| Verificar se é Pivô High (CORRIGIDO - Array Safe)               |
//+------------------------------------------------------------------+
bool IsPivotHigh(int shift)
{
   // ✅ PROTEÇÃO 1: Verificar limites básicos
   if(shift < PivotStrength || shift < 0)
      return false;
   
   // ✅ PROTEÇÃO 2: Verificar se há barras suficientes
   int totalBars = Bars;
   if(totalBars <= 0)
      return false;
      
   if(shift >= totalBars - PivotStrength - 1)
      return false;
   
   // ✅ PROTEÇÃO 3: Verificar tamanho do array
   if(shift >= ArraySize(High))
      return false;
      
   double centerHigh = High[shift];
   
   // Verificar barras À ESQUERDA
   for(int i = 1; i <= PivotStrength; i++)
   {
      int leftBar = shift + i;
      
      // ✅ PROTEÇÃO: Verificar limites antes de acessar
      if(leftBar < 0 || leftBar >= totalBars || leftBar >= ArraySize(High))
         return false;
         
      if(High[leftBar] >= centerHigh)
         return false;
   }
   
   // Verificar barras À DIREITA
   for(int i = 1; i <= PivotStrength; i++)
   {
      int rightBar = shift - i;
      
      // ✅ PROTEÇÃO: Verificar limites antes de acessar
      if(rightBar < 0 || rightBar >= totalBars || rightBar >= ArraySize(High))
         return false;
         
      if(High[rightBar] >= centerHigh)
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Verificar se é Pivô Low (CORRIGIDO - Array Safe)                |
//+------------------------------------------------------------------+
bool IsPivotLow(int shift)
{
   // ✅ PROTEÇÃO 1: Verificar limites básicos
   if(shift < PivotStrength || shift < 0)
      return false;
   
   // ✅ PROTEÇÃO 2: Verificar se há barras suficientes
   int totalBars = Bars;
   if(totalBars <= 0)
      return false;
      
   if(shift >= totalBars - PivotStrength - 1)
      return false;
   
   // ✅ PROTEÇÃO 3: Verificar tamanho do array
   if(shift >= ArraySize(Low))
      return false;
      
   double centerLow = Low[shift];
   
   // Verificar barras À ESQUERDA
   for(int i = 1; i <= PivotStrength; i++)
   {
      int leftBar = shift + i;
      
      // ✅ PROTEÇÃO: Verificar limites antes de acessar
      if(leftBar < 0 || leftBar >= totalBars || leftBar >= ArraySize(Low))
         return false;
         
      if(Low[leftBar] <= centerLow)
         return false;
   }
   
   // Verificar barras À DIREITA
   for(int i = 1; i <= PivotStrength; i++)
   {
      int rightBar = shift - i;
      
      // ✅ PROTEÇÃO: Verificar limites antes de acessar
      if(rightBar < 0 || rightBar >= totalBars || rightBar >= ArraySize(Low))
         return false;
         
      if(Low[rightBar] <= centerLow)
         return false;
   }
   
   return true;
}

void CloseCurrentTrade(int currentBar, string reason)
{
   if(!activeTrade.hasPosition)
   {
      Print("⚠️ CloseCurrentTrade: Nenhum trade ativo para fechar");
      return;
   }
   
   if(activeTrade.tradeIndex < 0 || activeTrade.tradeIndex >= totalTrades)
   {
      Print("❌ Erro: Índice de trade inválido");
      activeTrade.hasPosition = false;
      return;
   }
   
   if(trades[activeTrade.tradeIndex].status != 0)
   {
      Print("⚠️ Trade já foi fechado anteriormente");
      activeTrade.hasPosition = false;
      return;
   }
   
   // ═══════════════════════════════════════════════════════════════
   // ✅ BUSCAR A VELA QUE REALMENTE ATINGIU TP/SL
   // ═══════════════════════════════════════════════════════════════
   
   int closeBar = currentBar;
   bool hitTP = false;
   bool hitSL = false;
   double closePrice = Close[currentBar];
   datetime closeTime = Time[currentBar];
   
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
   
   if(!hitTP && !hitSL)
   {
      closePrice = Close[currentBar];
      closeTime = Time[currentBar];
      closeBar = currentBar;
   }
   
   // ✅ VALIDAÇÃO: Verificar se exitPrice está dentro da vela
   int closeBarIndex = iBarShift(NULL, 0, closeTime);
   if(closeBarIndex >= 0 && closeBarIndex < Bars)
   {
      bool priceInsideBar = (closePrice >= Low[closeBarIndex] && closePrice <= High[closeBarIndex]);
      
      if(!priceInsideBar)
      {
         Print("⚠️ CORREÇÃO: Exit price ", DoubleToString(closePrice, Digits), 
               " fora da vela [", DoubleToString(Low[closeBarIndex], Digits), 
               " - ", DoubleToString(High[closeBarIndex], Digits), "]");
         closePrice = Close[closeBarIndex];
         hitTP = false;
         hitSL = false;
      }
   }
   
   Print("🔍 DEBUG CloseCurrentTrade:");
   Print("   Barra do novo sinal: ", currentBar);
   Print("   Barra que atingiu TP/SL: ", closeBar);
   Print("   Hit TP: ", hitTP, " | Hit SL: ", hitSL);
   Print("   Close Price: ", DoubleToString(closePrice, Digits));
   Print("   Close Time: ", TimeToString(closeTime));
   
   // ═══ CALCULAR LUCRO/PERDA ═══
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
   
   string type = activeTrade.isBuy ? "COMPRA" : "VENDA";
   string result = (profit > 0) ? "WIN" : "LOSS";
   string exitType = hitTP ? "TP" : (hitSL ? "SL" : "PARCIAL");
   
   Print("🔄 REVERSE CLOSE: ", type, " fechada | Razão: ", reason, 
         " | Exit: ", exitType,
         " | Preço: ", DoubleToString(closePrice, Digits),
         " | Resultado: ", result, " $", DoubleToString(profit, 2));
   
   activeTrade.hasPosition = false;
   activeTrade.tradeIndex = -1;
}

//+------------------------------------------------------------------+
//| Gerar Sinal de Compra (COM REVERSE CLOSE)                        |
//+------------------------------------------------------------------+
void GenerateBuySignal(int i)
{
   // ✅ PROTEÇÃO: Verificar índice válido
   if(i < 0 || i >= ArraySize(Close))
   {
      Print("⚠️ GenerateBuySignal: Índice inválido i=", i);
      return;
   }
   
   if(!PassEntryFilters(true, i))
      return;
   
   double entry = Close[i];
   double sl = 0.0, tp = 0.0;
   CalculateSLTP(true, i, lastBuyPivotPrice, sl, tp);
   
   // ✅ PROTEÇÃO: Verificar antes de escrever no buffer
   if(i >= 0 && i < ArraySize(BuySignalBuf))
      BuySignalBuf[i] = entry;
   
   // ═══════════════════════════════════════════════════════════
   // 🔄 REVERSE CLOSE LOGIC
   // ═══════════════════════════════════════════════════════════
   
   if(UseReverseClose && activeTrade.hasPosition)
   {
      if(activeTrade.isBuy)
      {
         // Já é COMPRA, ignora novo sinal de COMPRA
         Print("⚠️ Sinal de COMPRA ignorado: já existe COMPRA aberta");
         lastBuyPivotBar = -1;
         return;
      }
      else
      {
         // É VENDA, REVERTER para COMPRA
         Print("🔄 REVERSE: Detectado sinal de COMPRA, fechando VENDA atual...");
         CloseCurrentTrade(i, "Reverse to BUY");
         // Continua para abrir a COMPRA
      }
   }
   else if(!UseReverseClose && activeTrade.hasPosition)
   {
      // Modo normal: ignora se já tem posição
      Print("⚠️ Sinal ignorado: já existe posição aberta (Reverse Close desativado)");
      lastBuyPivotBar = -1;
      return;
   }
   
   // ═══ SEMPRE REGISTRAR TRADE (durante varredura E ao vivo) ═══
   if(EnableBacktest)
   {
      int tradeIdx = totalTrades;
      ArrayResize(trades, totalTrades + 1);
      
      // ✅ PROTEÇÃO: Verificar acesso ao array Time
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
      
      // Atualizar controle de trade ativo
      activeTrade.hasPosition = true;
      activeTrade.isBuy = true;
      activeTrade.openTime = tradeTime;
      activeTrade.entryPrice = entry;
      activeTrade.slPrice = sl;
      activeTrade.tpPrice = tp;
      activeTrade.tradeIndex = tradeIdx;
      
      // ═══ DESENHAR LINHAS HLINE APENAS AO VIVO (não durante varredura) ═══
      if(ShowSLTPLines && !isScanningHistory)
      {
         string entryName = "MPP_ENTRY_BUY_" + TimeToString(tradeTime, TIME_DATE|TIME_SECONDS);
         string slName = "MPP_SL_BUY_" + TimeToString(tradeTime, TIME_DATE|TIME_SECONDS);
         string tpName = "MPP_TP_BUY_" + TimeToString(tradeTime, TIME_DATE|TIME_SECONDS);
         
         // Criar linhas horizontais
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
         
         // Registrar linhas para limpeza futura
         RegisterTradeLines(tradeIdx, entryName, slName, tpName);
      }
      
      Print("✅ TRADE COMPRA REGISTRADO: Entry=", entry, " SL=", sl, " TP=", tp, 
            " | Scanning=", (isScanningHistory ? "SIM" : "NÃO"));
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
//| Gerar Sinal de Venda (COM REVERSE CLOSE)                         |
//+------------------------------------------------------------------+
void GenerateSellSignal(int i)
{
   // ✅ PROTEÇÃO: Verificar índice válido
   if(i < 0 || i >= ArraySize(Close))
   {
      Print("⚠️ GenerateSellSignal: Índice inválido i=", i);
      return;
   }
   
   if(!PassEntryFilters(false, i))
      return;
   
   double entry = Close[i];
   double sl = 0.0, tp = 0.0;
   CalculateSLTP(false, i, lastSellPivotPrice, sl, tp);
   
   // ✅ PROTEÇÃO: Verificar antes de escrever no buffer
   if(i >= 0 && i < ArraySize(SellSignalBuf))
      SellSignalBuf[i] = entry;
   
   // ═══════════════════════════════════════════════════════════
   // 🔄 REVERSE CLOSE LOGIC
   // ═══════════════════════════════════════════════════════════
   
   if(UseReverseClose && activeTrade.hasPosition)
   {
      if(!activeTrade.isBuy)
      {
         // Já é VENDA, ignora novo sinal de VENDA
         Print("⚠️ Sinal de VENDA ignorado: já existe VENDA aberta");
         lastSellPivotBar = -1;
         return;
      }
      else
      {
         // É COMPRA, REVERTER para VENDA
         Print("🔄 REVERSE: Detectado sinal de VENDA, fechando COMPRA atual...");
         CloseCurrentTrade(i, "Reverse to SELL");
         // Continua para abrir a VENDA
      }
   }
   else if(!UseReverseClose && activeTrade.hasPosition)
   {
      // Modo normal: ignora se já tem posição
      Print("⚠️ Sinal ignorado: já existe posição aberta (Reverse Close desativado)");
      lastSellPivotBar = -1;
      return;
   }
   
   // ═══ SEMPRE REGISTRAR TRADE (durante varredura E ao vivo) ═══
   if(EnableBacktest)
   {
      int tradeIdx = totalTrades;
      ArrayResize(trades, totalTrades + 1);
      
      // ✅ PROTEÇÃO: Verificar acesso ao array Time
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
      
      // Atualizar controle de trade ativo
      activeTrade.hasPosition = true;
      activeTrade.isBuy = false;
      activeTrade.openTime = tradeTime;
      activeTrade.entryPrice = entry;
      activeTrade.slPrice = sl;
      activeTrade.tpPrice = tp;
      activeTrade.tradeIndex = tradeIdx;
      
      // ═══ DESENHAR LINHAS HLINE APENAS AO VIVO (não durante varredura) ═══
      if(ShowSLTPLines && !isScanningHistory)
      {
         string entryName = "MPP_ENTRY_SELL_" + TimeToString(tradeTime, TIME_DATE|TIME_SECONDS);
         string slName = "MPP_SL_SELL_" + TimeToString(tradeTime, TIME_DATE|TIME_SECONDS);
         string tpName = "MPP_TP_SELL_" + TimeToString(tradeTime, TIME_DATE|TIME_SECONDS);
         
         // Criar linhas horizontais
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
         
         // Registrar linhas para limpeza futura
         RegisterTradeLines(tradeIdx, entryName, slName, tpName);
      }
      
      Print("✅ TRADE VENDA REGISTRADO: Entry=", entry, " SL=", sl, " TP=", tp,
            " | Scanning=", (isScanningHistory ? "SIM" : "NÃO"));
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

// Bloco 4

//+------------------------------------------------------------------+
//| Custom indicator iteration function (COM REVERSE CLOSE)          |
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
   // ═══ PROTEÇÃO: Verificar dados suficientes ═══
   int minBars = TrendEMAPeriod + 50;
   if(rates_total < minBars)
   {
      Comment("⏳ Aguardando dados históricos... ", rates_total, "/", minBars, " barras");
      return(0);
   }
   
   if(ArraySize(BuyPivotBuf) < rates_total)
   {
      Print("⚠️ Buffer menor que rates_total! Aguardando...");
      return(0);
   }
   
   // ═══ DETECÇÃO DE NOVA BARRA ═══
   datetime currentBarTime = Time[0];
   isNewBar = false;
   
   if(currentBarTime != lastProcessedBarTime)
   {
      isNewBar = true;
      lastProcessedBarTime = currentBarTime;
   }
   
   // ═══ DETECTAR FIM DA VARREDURA INICIAL ═══
   if(isScanningHistory)
   {
      if(initialBars == 0)
         initialBars = rates_total;
         
      // Varredura terminou quando prev_calculated == rates_total
      if(prev_calculated > 0 && prev_calculated == rates_total)
      {
         isScanningHistory = false;
         Print("✅ Varredura histórica concluída. Sistema ativo para trading ao vivo.");
          DrawAllClosedTradeResults();  // ✅ ADICIONAR ESTA LINHA
      }
   }
   
   // ═══ LIMPAR LINHAS DE TRADES ENCERRADOS ═══
   CleanupClosedTradeLines();
   
   // ═══ VERIFICAR SE PRECISA RESETAR ═══
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
   
   // ═══ CALCULAR BARRAS A VARRER ═══
   totalBarsAvailable = iBars(Symbol(), Period());
   
   if(ScanPercentage == 0)
      barsToScan = MathMin(150, totalBarsAvailable);
   else
      barsToScan = MathMin((int)(totalBarsAvailable * ScanPercentage / 100.0), totalBarsAvailable);
   
   int limit = barsToScan;
   if(prev_calculated > 0)
      limit = MathMin(3, barsToScan);
   
   // ✅✅ PROTEÇÃO CRÍTICA: Evitar array out of range ✅✅
   if(limit >= rates_total)
      limit = rates_total - 1;
   
   // ✅ Garantir que não acesse índices negativos
   if(limit < 0)
      limit = 0;
   
   // ═══ RASTREAMENTO DO PERÍODO DE VARREDURA ═══
   if(rates_total > 0)
   {
      // ✅ PROTEÇÃO: Verificar antes de acessar Time[rates_total - 1]
      int lastIndex = rates_total - 1;
      if(lastIndex >= 0 && lastIndex < ArraySize(Time))
      {
         if(firstBarProcessed == 0 || Time[lastIndex] < firstBarProcessed)
            firstBarProcessed = Time[lastIndex];
      }
      
      // ✅ PROTEÇÃO: Verificar antes de acessar Time[0]
      if(ArraySize(Time) > 0 && Time[0] > lastBarProcessed)
         lastBarProcessed = Time[0];
      
      if(firstBarProcessed > 0 && lastBarProcessed > 0)
         totalDaysCovered = (int)((lastBarProcessed - firstBarProcessed) / 86400);
   }
   
   // ═══ LOOP PRINCIPAL COM PROTEÇÃO TOTAL ═══
   for(int i = limit; i >= 0; i--)
   {
      // ✅✅ PROTEÇÃO ADICIONAL: Verificar se i está dentro dos limites ✅✅
      if(i < 0 || i >= rates_total)
         continue;
      
      // ✅ PROTEÇÃO: Verificar tamanho dos buffers antes de escrever
      if(i >= ArraySize(BuyPivotBuf))
         continue;
      
      // Resetar buffers
      BuyPivotBuf[i] = EMPTY_VALUE;
      SellPivotBuf[i] = EMPTY_VALUE;
      BuyConfirmBuf[i] = EMPTY_VALUE;
      SellConfirmBuf[i] = EMPTY_VALUE;
      BuySignalBuf[i] = EMPTY_VALUE;
      SellSignalBuf[i] = EMPTY_VALUE;
      
      // ═══ DETECTAR PIVÔS ═══
      if(IsPivotHigh(i))
      {
         // ✅ PROTEÇÃO: Verificar antes de acessar High[i]
         if(i >= 0 && i < ArraySize(High))
         {
            SellPivotBuf[i] = High[i];
            lastSellPivotBar = i;
            lastSellPivotPrice = High[i];
         }
      }
      
      if(IsPivotLow(i))
      {
         // ✅ PROTEÇÃO: Verificar antes de acessar Low[i]
         if(i >= 0 && i < ArraySize(Low))
         {
            BuyPivotBuf[i] = Low[i];
            lastBuyPivotBar = i;
            lastBuyPivotPrice = Low[i];
         }
      }
      
      // ═══ VERIFICAR CONFIRMAÇÃO DE COMPRA ═══
      if(lastBuyPivotBar >= 0 && i < lastBuyPivotBar - ConfirmCandles && lastBuyPivotBar < rates_total)
      {
         bool confirmed = true;
         
         for(int j = 1; j <= ConfirmCandles; j++)
         {
            int checkBar = lastBuyPivotBar - j;
            
            // ✅ PROTEÇÃO: Verificar limites do array antes de acessar
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
            // ✅ PROTEÇÃO: Verificar antes de escrever no buffer
            if(i >= 0 && i < ArraySize(BuyConfirmBuf) && i < ArraySize(Low))
               BuyConfirmBuf[i] = Low[i] - 15 * Point;
            
            // ✅✅ GERAR SINAL: VARREDURA OU NOVA BARRA AO VIVO ✅✅
            if(isScanningHistory || (i == 0 && isNewBar))
            {
               GenerateBuySignal(i);
               lastBuyPivotBar = -1; // ✅ Resetar após gerar sinal
            }
         }
      }
      
      // ═══ VERIFICAR CONFIRMAÇÃO DE VENDA ═══
      if(lastSellPivotBar >= 0 && i < lastSellPivotBar - ConfirmCandles && lastSellPivotBar < rates_total)
      {
         bool confirmed = true;
         
         for(int j = 1; j <= ConfirmCandles; j++)
         {
            int checkBar = lastSellPivotBar - j;
            
            // ✅ PROTEÇÃO: Verificar limites do array antes de acessar
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
            // ✅ PROTEÇÃO: Verificar antes de escrever no buffer
            if(i >= 0 && i < ArraySize(SellConfirmBuf) && i < ArraySize(High))
               SellConfirmBuf[i] = High[i] + 15 * Point;
            
            // ✅✅ GERAR SINAL: VARREDURA OU NOVA BARRA AO VIVO ✅✅
            if(isScanningHistory || (i == 0 && isNewBar))
            {
               GenerateSellSignal(i);
               lastSellPivotBar = -1; // ✅ Resetar após gerar sinal
            }
         }
      }
   }
   
   // ═══ PROCESSAR TRADES ABERTOS ═══
   CheckTradeResults();
   
   
   // ═══════════════════════════════════════════════════════════════
   // ✅ DESENHAR RESULTADOS DE TRADES FECHADOS (UMA VEZ APENAS)
   // ═══════════════════════════════════════════════════════════════
   if(ShowSLTPLines)
   {
      for(int i = 0; i < totalTrades; i++)
      {
         // Apenas trades fechados que ainda não foram desenhados
         if(trades[i].status != 0 && !trades[i].resultDrawn)
         {
            DrawTradeResult(i);
            trades[i].resultDrawn = true;  // Marcar como desenhado
            Print("🎨 Resultado desenhado para trade #", i, " | Status: ", 
                  trades[i].status == 1 ? "WIN" : "LOSS");
         }
      }
   }
   
   
   // ═══ ATUALIZAR PAINEL ═══
   if(TimeCurrent() - lastPanelUpdate >= 1)
   {
      UpdateInfoPanel();
      lastPanelUpdate = TimeCurrent();
   }
   
   return rates_total;
}

//+------------------------------------------------------------------+
//| Verificar Resultados dos Trades (COM REVERSE CLOSE + DESENHO)    |
//+------------------------------------------------------------------+
void CheckTradeResults()
{
   if(!EnableBacktest)
      return;
   
   // ═══════════════════════════════════════════════════════════
   // 🔄 MODO REVERSE CLOSE: Verifica apenas o trade ativo
   // ═══════════════════════════════════════════════════════════
   
   if(UseReverseClose && activeTrade.hasPosition)
   {
      int idx = activeTrade.tradeIndex;
      
      // Verificar se índice válido
      if(idx < 0 || idx >= totalTrades)
      {
         Print("⚠️ CheckTradeResults: Índice de trade inválido");
         activeTrade.hasPosition = false;
         return;
      }
      
      // Verificar se trade ainda está aberto
      if(trades[idx].status != 0)
      {
         activeTrade.hasPosition = false;
         return;
      }
      
      // Verificar SL/TP apenas na barra atual (mais eficiente)
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
      
      return; // Não precisa verificar outros trades
   }
   
   // ═══════════════════════════════════════════════════════════
   // MODO NORMAL: Verifica todos os trades abertos
   // ═══════════════════════════════════════════════════════════
   
   if(totalTrades == 0)
      return;
   
   for(int i = 0; i < totalTrades; i++)
   {
      if(trades[i].status != 0)
         continue;
      
      int entryBar = iBarShift(NULL, 0, trades[i].openTime);
      if(entryBar < 0)
         continue;
      
      for(int j = entryBar - 1; j >= 0; j--)
      {
         bool hitTP = false, hitSL = false;
         
         if(trades[i].isBuy)
         {
            if(High[j] >= trades[i].tpPrice)
               hitTP = true;
            if(Low[j] <= trades[i].slPrice)
               hitSL = true;
         }
         else
         {
            if(Low[j] <= trades[i].tpPrice)
               hitTP = true;
            if(High[j] >= trades[i].slPrice)
               hitSL = true;
         }
         
          // ✅ DEBUG ADICIONAL: Mostrar CADA vela testada
   if(i < 3)  // Apenas para os 3 primeiros trades
   {
      Print("   🔎 Testando Bar[", j, "] ", TimeToString(Time[j], TIME_DATE|TIME_MINUTES), 
            " | High:", DoubleToString(High[j], Digits), 
            " Low:", DoubleToString(Low[j], Digits),
            " | hitTP:", hitTP, " hitSL:", hitSL);
   }
         
         
         
         
         
         
         if(hitTP || hitSL)
         {
         
            // ✅ DEBUG: Mostrar detecção de TP/SL
      Print("════════════════════════════════════════");
      Print("🎯 TRADE FECHADO - Trade #", i);
      Print("   Type: ", trades[i].isBuy ? "BUY" : "SELL");
      Print("   Entry Bar: ", entryBar, " | Time: ", TimeToString(trades[i].openTime, TIME_DATE|TIME_MINUTES));
      Print("   Entry Price: ", DoubleToString(trades[i].entryPrice, Digits));
      Print("   Close Bar: ", j, " | Time: ", TimeToString(Time[j], TIME_DATE|TIME_MINUTES));
      Print("   Close Type: ", hitTP ? "TP" : "SL");
      Print("   Target Price: ", hitTP ? DoubleToString(trades[i].tpPrice, Digits) : DoubleToString(trades[i].slPrice, Digits));
      Print("   Bar High: ", DoubleToString(High[j], Digits));
      Print("   Bar Low: ", DoubleToString(Low[j], Digits));
      Print("   Bar Close: ", DoubleToString(Close[j], Digits));
      Print("════════════════════════════════════════");
         
         
         
            trades[i].closeTime = Time[j];
            
            // ✅ ARMAZENAR PREÇO DE SAÍDA REAL
            if(hitTP)
               trades[i].exitPrice = trades[i].tpPrice;
            else
               trades[i].exitPrice = trades[i].slPrice;
            
            double riskPoints = MathAbs(trades[i].entryPrice - trades[i].slPrice) / Point;
            double profit = 0;
            
            if(hitTP)
            {
               trades[i].status = 1; // Win
               profit = (InitialBalance * RiskPerTrade / 100) * RiskRewardRatio;
               totalWins++;
               totalProfitUSD += profit;
            }
            else
            {
               trades[i].status = 2; // Loss
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
            
            // ✅ ADICIONAR: Desenhar resultado visual
            if(ShowSLTPLines )
               DrawTradeResult(i);
            
            string result = hitTP ? "WIN ✅" : "LOSS ❌";
            Print("📊 Trade fechado: ", result, " | Profit: $", DoubleToString(profit, 2));
            
            break;
         }
      }
   }
}

// Bloco 5

//+------------------------------------------------------------------+
//| Detectar Pivôs de Alta e Baixa (SIMPLIFICADO)                   |
//+------------------------------------------------------------------+
void DetectPivots(int bar)
{
   // Esta função agora é apenas um wrapper
   // A lógica real está em IsPivotHigh e IsPivotLow
   // que são chamadas diretamente no OnCalculate
   
   // Manter DrawStar se necessário
   if(BuyPivotBuf[bar] != EMPTY_VALUE && BuyPivotBuf[bar] != 0.0)
   {
      DrawStar(true, bar, BuyPivotBuf[bar]);
   }
   
   if(SellPivotBuf[bar] != EMPTY_VALUE && SellPivotBuf[bar] != 0.0)
   {
      DrawStar(false, bar, SellPivotBuf[bar]);
   }
}

//+------------------------------------------------------------------+
//| Desenhar Estrela no Pivô (AZUL para topo / VERMELHA para fundo) |
//+------------------------------------------------------------------+
void DrawStar(bool isBuyPivot, int bar, double price)
{
   // Nome único do objeto
   string objName = "MPP_STAR_" + (isBuyPivot ? "BUY_" : "SELL_") + TimeToString(Time[bar]);
   
   // Deletar objeto se já existir
   if(ObjectFind(0, objName) >= 0)
      ObjectDelete(0, objName);
   
   // Criar ESTRELA (código 119 = wingdings estrela ★)
   if(!ObjectCreate(0, objName, OBJ_ARROW, 0, Time[bar], price))
   {
      Print("❌ Erro ao criar estrela: ", objName, " - ", GetLastError());
      return;
   }
   
   // Configurar ESTRELA
   ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, 119);  // ★ Estrela preenchida
   
   // COR: VERMELHA para COMPRA (fundo) / AZUL para VENDA (topo)
   if(isBuyPivot)
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrRed);      // 🔴 Fundo = VERMELHO
   else
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrDodgerBlue); // 🔵 Topo = AZUL
   
   // Tamanho MAIOR (3 = grande)
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 3);
   
   // Posicionar corretamente
   if(isBuyPivot)
      ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_TOP);    // Abaixo do preço
   else
      ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_BOTTOM); // Acima do preço
   
   // Não selecionar automaticamente
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, objName, OBJPROP_SELECTED, false);
   
   // Aplicar ao fundo (não sobrepor velas)
   ObjectSetInteger(0, objName, OBJPROP_BACK, false);
}


//Bloco 6

//+------------------------------------------------------------------+
//| Validar Confirmação de Compra                                    |
//+------------------------------------------------------------------+
bool ValidateBuyConfirmation(int confirmBar, int pivotBar, double pivotPrice)
{
   double atr = iATR(NULL, 0, ATRPeriod, pivotBar);
   double minMove = atr * 0.8;
   
   double moveAway = Close[confirmBar] - pivotPrice;
   if(moveAway < minMove) return false;
   
   if(RequireCloseBreak && Close[confirmBar] <= High[pivotBar])
      return false;
   
   if(Close[confirmBar] <= Open[confirmBar])
      return false;
   
   if(Low[confirmBar] < pivotPrice)
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Validar Confirmação de Venda                                     |
//+------------------------------------------------------------------+
bool ValidateSellConfirmation(int confirmBar, int pivotBar, double pivotPrice)
{
   double atr = iATR(NULL, 0, ATRPeriod, pivotBar);
   double minMove = atr * 0.8;
   
   double moveAway = pivotPrice - Close[confirmBar];
   if(moveAway < minMove) return false;
   
   if(RequireCloseBreak && Close[confirmBar] >= Low[pivotBar])
      return false;
   
   if(Close[confirmBar] >= Open[confirmBar])
      return false;
   
   if(High[confirmBar] > pivotPrice)
      return false;
   
   return true;
}


//Bloco 7




//+------------------------------------------------------------------+
//| Enviar Alerta de Trade                                           |
//+------------------------------------------------------------------+
void SendTradeAlert(bool isBuy, double entry, double sl, double tp)
{
   string message = StringFormat("%s SINAL: %s | Entry: %s | SL: %s | TP: %s",
                                 Symbol(),
                                 isBuy ? "COMPRA" : "VENDA",
                                 DoubleToString(entry, Digits),
                                 DoubleToString(sl, Digits),
                                 DoubleToString(tp, Digits));
   
   if(lastAlertMessage != message || TimeCurrent() - lastAlertTime > 60)
   {
      Alert(message);
      
      if(EnablePushNotifications)
         SendNotification(message);
      
      lastAlertMessage = message;
      lastAlertTime = TimeCurrent();
   }
}


// Bloco 8

//+------------------------------------------------------------------+
//| Calcular SL e TP (COM REVERSE CLOSE)                             |
//+------------------------------------------------------------------+
void CalculateSLTP(bool isBuy, int bar, double pivotPrice, double &sl, double &tp)
{
   // 1️⃣ Calcular ATR
   double atr = iATR(NULL, 0, ATRPeriod, bar);
   double slDistance = atr * StopLossATRMulti;
   
   // 2️⃣ Aplicar limites mínimos e máximos
   double slDistancePoints = slDistance / Point;
   if(slDistancePoints < MinStopLossPoints)
      slDistance = MinStopLossPoints * Point;
   if(slDistancePoints > MaxStopLossPoints)
      slDistance = MaxStopLossPoints * Point;
   
   // 3️⃣ Preço de entrada
   double entry = Close[bar];
   
   // 4️⃣ SWITCH: Escolher lógica baseada no input
   if(UsePivotBasedSL)
   {
      // ════════════════════════════════════════════════════════════
      // 🎯 OPÇÃO 2: SL baseado no PIVÔ, TP ajustado pela distância REAL
      // ════════════════════════════════════════════════════════════
      
      if(isBuy)
      {
         // SL abaixo do pivô (protege o fundo)
         sl = pivotPrice - slDistance;
         
         // ✅ Calcular distância REAL entre Entry e SL
         double realSLDistance = entry - sl;
         
         // TP ajustado pela distância REAL (mantém R:R correto)
         tp = entry + (realSLDistance * RiskRewardRatio);
      }
      else
      {
         // SL acima do pivô (protege o topo)
         sl = pivotPrice + slDistance;
         
         // ✅ Calcular distância REAL entre Entry e SL
         double realSLDistance = sl - entry;
         
         // TP ajustado pela distância REAL (mantém R:R correto)
         tp = entry - (realSLDistance * RiskRewardRatio);
      }
   }
   else
   {
      // ════════════════════════════════════════════════════════════
      // 📍 OPÇÃO 1: SL e TP baseados na ENTRADA (R:R fixo)
      // ════════════════════════════════════════════════════════════
      
      if(isBuy)
      {
         // SL e TP baseados na entrada
         sl = entry - slDistance;
         tp = entry + (slDistance * RiskRewardRatio);
      }
      else
      {
         sl = entry + slDistance;
         tp = entry - (slDistance * RiskRewardRatio);
      }
   }
   
   // 5️⃣ Normalizar preços
   sl = NormalizeDouble(sl, Digits);
   tp = NormalizeDouble(tp, Digits);
   
   // ✅ DEBUG: Mostrar cálculo TP/SL
   Print("════════════════════════════════════════");
   Print("🔍 DEBUG CalculateSLTP");
   Print("   Bar: ", bar, " | Time: ", TimeToString(Time[bar], TIME_DATE|TIME_MINUTES));
   Print("   Type: ", isBuy ? "BUY" : "SELL");
   Print("   Entry: ", DoubleToString(Close[bar], Digits));
   Print("   Pivot: ", DoubleToString(pivotPrice, Digits));
   Print("   SL: ", DoubleToString(sl, Digits), " | Distance: ", DoubleToString(MathAbs(Close[bar] - sl) / Point, 0), " points");
   Print("   TP: ", DoubleToString(tp, Digits), " | Distance: ", DoubleToString(MathAbs(tp - Close[bar]) / Point, 0), " points");
   Print("   Risk:Reward = 1:", DoubleToString(MathAbs(tp - Close[bar]) / MathAbs(Close[bar] - sl), 2));
   Print("════════════════════════════════════════");
   
   
   
   
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
   
    // ✅ DEBUG COMPLETO
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
   
   // Verificar se exitPrice está dentro da vela
   bool priceInsideBar = (exitPrice >= Low[closeBar] && exitPrice <= High[closeBar]);
   Print("      Exit Price dentro da vela? ", priceInsideBar ? "✅ SIM" : "❌ NÃO!");
   Print("════════════════════════════════════════");
   
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
   
   // ═══════════════════════════════════════════════════════════════
   // 1️⃣ LINHA PONTILHADA (Entry → Exit) - CONECTA NO PREÇO DA VELA
   // ═══════════════════════════════════════════════════════════════
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
   
   // ═══════════════════════════════════════════════════════════════
   // 2️⃣ CÍRCULO PEQUENO NO PONTO DE SAÍDA (ao invés de seta)
   // ═══════════════════════════════════════════════════════════════
   string circleName = baseName + "_CIRCLE";
   
   if(ObjectFind(0, circleName) < 0)
   {
      if(ObjectCreate(0, circleName, OBJ_ARROW, 0, closeTime, exitPrice))
      {
         ObjectSetInteger(0, circleName, OBJPROP_ARROWCODE, 159); // Círculo pequeno ●
         ObjectSetInteger(0, circleName, OBJPROP_COLOR, isWin ? clrDodgerBlue : clrRed);
         ObjectSetInteger(0, circleName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, circleName, OBJPROP_BACK, false);
         ObjectSetInteger(0, circleName, OBJPROP_SELECTABLE, false);
      }
   }
   
   // ═══════════════════════════════════════════════════════════════
   // 3️⃣ TEXTO COM RESULTADO (posicionado próximo ao ponto de saída)
   // ═══════════════════════════════════════════════════════════════
   string textName = baseName + "_TEXT";
   
   if(ObjectFind(0, textName) < 0)
   {
      // Calcular posição do texto
      double textPrice;
      if(trades[tradeIdx].isBuy)
         textPrice = exitPrice + (50 * Point); // Acima do círculo
      else
         textPrice = exitPrice - (50 * Point); // Abaixo do círculo
      
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
   
   Print("🎨 ", isWin ? "WIN" : "LOSS", " | Trade #", tradeIdx, 
         " | Entry: ", DoubleToString(entryPrice, Digits), 
         " → Exit: ", DoubleToString(exitPrice, Digits));
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
      // Apenas trades fechados (status 1=Win ou 2=Loss)
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

