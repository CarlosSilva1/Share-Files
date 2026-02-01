// Bloco 1

//+------------------------------------------------------------------+
//|                                      MaisPivotAdvance_PRO_v3.mq4 |
//|                          Sistema No-Repaint com Stats Avançado   |
//+------------------------------------------------------------------+
#property copyright "Mais Pivot Advance PRO"
#property link      ""
#property version   "3.00"
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
   int barIndex;
   string entryLineName;
   string slLineName;
   string tpLineName;
   bool linesDrawn;
};

TradeInfo trades[];
int totalTrades = 0;

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
datetime firstBarProcessed = 0;  // Primeira barra processada
datetime lastBarProcessed = 0;   // Última barra processada
int totalDaysCovered = 0;        // Total de dias cobertos

// ═══ CONTROLE DE LIMPEZA DE LINHAS ═══
datetime lastChartScroll = 0;     // Última vez que o gráfico foi rolado
int lastVisibleBars = 0;          // Última contagem de barras visíveis
ENUM_TIMEFRAMES lastPeriod = PERIOD_CURRENT; // Último timeframe
int lastFirstVisibleBar = 0;     // Primeira barra visível na tela
bool chartMoved = false;          // Flag para detectar movimento


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
   
      Print("MAIS PIVOT PRO iniciado | Barras disponíveis: ", totalBarsAvailable, 
         " | Varredura: ", barsToScan, " barras (", ScanPercentage, "%)");
   
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
   
   Print("🔄 RESET FINANCEIRO EXECUTADO");
}


//+------------------------------------------------------------------+
//| Calcular Estatísticas (compatibilidade)                         |
//+------------------------------------------------------------------+
void CalculateStats()
{
   CalculateMetrics();
}



// Bloco 4

//+------------------------------------------------------------------+
//| Custom indicator iteration function (PROTEGIDO)                  |
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
   // ========== PROTEÇÃO 1: Verificar dados suficientes ==========
   int minBars = TrendEMAPeriod + 50;
   if(rates_total < minBars)
   {
      Comment("⏳ Aguardando dados históricos... ", rates_total, "/", minBars, " barras");
      return(0);
   }
   
   // ========== PROTEÇÃO 2: Verificar tamanho dos buffers ==========
   if(ArraySize(BuyPivotBuf) < rates_total)
   {
      Print("⚠️ Buffer menor que rates_total! Aguardando...");
      return(0);
   }
   
   // Definir como série
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   // Verificar se mudou o percentual de varredura
   if(ScanPercentage != lastScanPercentage)
   {
      if(ScanPercentage == 0)
      {
         // Reset solicitado
         ResetFinancialMetrics();
         barsToScan = 50;
      }
      else
      {
         // Recalcular varredura
         totalBarsAvailable = rates_total;
         barsToScan = (int)(totalBarsAvailable * (ScanPercentage / 100.0));
         if(barsToScan > MaxLookback) barsToScan = MaxLookback;
         if(barsToScan < 50) barsToScan = 50;
         
         // ========== PROTEÇÃO 3: Garantir que não ultrapasse rates_total ==========
         if(barsToScan > rates_total - 1)
         {
            barsToScan = rates_total - 1;
            Print("⚠️ barsToScan ajustado para: ", barsToScan);
         }
      }
      
      lastScanPercentage = ScanPercentage;
      Print("📊 Varredura ajustada: ", barsToScan, " barras (", ScanPercentage, "%)");
   }
   
   // ========== PROTEÇÃO 4: Determinar ponto de início SEGURO ==========
   int start;
   if(prev_calculated == 0)
   {
      // Primeira execução - varrer conforme percentual
      start = MathMin(barsToScan, rates_total - 1);
      
      // Garantir que não seja menor que o mínimo necessário
      if(start < TrendEMAPeriod + 10)
         start = MathMin(TrendEMAPeriod + 10, rates_total - 1);
   }
   else
   {
      // Apenas atualizar últimas barras
      start = MathMin(10, rates_total - 1);
   }
   
   // ========== PROTEÇÃO 5: Validar start antes do loop ==========
   if(start >= rates_total)
   {
      Print("❌ ERRO: start (", start, ") >= rates_total (", rates_total, ")");
      return(prev_calculated);
   }
   
   if(start < 0)
   {
      Print("❌ ERRO: start negativo (", start, ")");
      return(prev_calculated);
   }
   
   // ═══ RASTREAR PERÍODO DE VARREDURA ═══
   if(rates_total > 0)
   {
      // Primeira barra (mais antiga) = índice mais alto
      if(firstBarProcessed == 0 || Time[rates_total - 1] < firstBarProcessed)
         firstBarProcessed = Time[rates_total - 1];
      
      // Última barra (mais recente) = índice 0
      if(Time[0] > lastBarProcessed)
         lastBarProcessed = Time[0];
      
      // Calcular dias cobertos
      if(firstBarProcessed > 0 && lastBarProcessed > 0)
      {
         totalDaysCovered = (int)((lastBarProcessed - firstBarProcessed) / 86400); // 86400 = segundos em um dia
      }
   }
   
   // ========== Loop através das barras (PROTEGIDO) ==========
   for(int i = start; i >= 0 && !IsStopped(); i--)
   {
      // ========== PROTEÇÃO 6: Verificar índice dentro do loop ==========
      if(i >= rates_total || i < 0)
      {
         Print("⚠️ Índice inválido no loop: i=", i, ", rates_total=", rates_total);
         continue; // Pular esta iteração
      }
      
      // ========== PROTEÇÃO 7: Verificar acesso aos buffers ==========
      if(i >= ArraySize(BuyPivotBuf) || i >= ArraySize(close))
      {
         Print("⚠️ Buffer insuficiente: i=", i, ", tamanho=", ArraySize(BuyPivotBuf));
         continue;
      }
      
      // Limpar buffers
      BuyPivotBuf[i] = 0.0;
      SellPivotBuf[i] = 0.0;
      BuyConfirmBuf[i] = 0.0;
      SellConfirmBuf[i] = 0.0;
      BuySignalBuf[i] = 0.0;
      SellSignalBuf[i] = 0.0;
      
      // ========== Processar lógica (PROTEGIDO) ==========
      if(i + TrendEMAPeriod < rates_total) // Garantir dados suficientes
      {
         DetectPivots(i);
         ProcessConfirmation(i);
      }
   }
   
   // ═══ RELATÓRIO FINAL DA VARREDURA (APENAS NA PRIMEIRA EXECUÇÃO) ═══
   static bool firstRunComplete = false;
   
   if(prev_calculated == 0 && !firstRunComplete)
   {
      // Contar pivôs detectados
      int buyPivotsFound = 0;
      int sellPivotsFound = 0;
      int buyConfirmsFound = 0;
      int sellConfirmsFound = 0;
      int buySignalsFound = 0;
      int sellSignalsFound = 0;
      
      for(int i = 0; i < MathMin(barsToScan, rates_total); i++)
      {
         if(BuyPivotBuf[i] != 0.0 && BuyPivotBuf[i] != EMPTY_VALUE)
            buyPivotsFound++;
         
         if(SellPivotBuf[i] != 0.0 && SellPivotBuf[i] != EMPTY_VALUE)
            sellPivotsFound++;
         
         if(BuyConfirmBuf[i] != 0.0 && BuyConfirmBuf[i] != EMPTY_VALUE)
            buyConfirmsFound++;
         
         if(SellConfirmBuf[i] != 0.0 && SellConfirmBuf[i] != EMPTY_VALUE)
            sellConfirmsFound++;
         
         if(BuySignalBuf[i] != 0.0 && BuySignalBuf[i] != EMPTY_VALUE)
            buySignalsFound++;
         
         if(SellSignalBuf[i] != 0.0 && SellSignalBuf[i] != EMPTY_VALUE)
            sellSignalsFound++;
      }
      
      // Imprimir relatório completo
      Print("════════════════════════════════════════");
      Print("📊 RELATÓRIO FINAL DA VARREDURA");
      Print("════════════════════════════════════════");
      Print("🔹 Barras processadas: ", barsToScan);
      Print("");
      Print("⭐ PIVÔS DETECTADOS:");
      Print("   🔴 Fundos (Compra): ", buyPivotsFound);
      Print("   🔵 Topos (Venda): ", sellPivotsFound);
      Print("   Total: ", buyPivotsFound + sellPivotsFound);
      Print("");
      Print("➡️ CONFIRMAÇÕES DISPARADAS:");
      Print("   🔵 Compra (Setas Azuis): ", buyConfirmsFound);
      Print("   🔴 Venda (Setas Vermelhas): ", sellConfirmsFound);
      Print("   Total: ", buyConfirmsFound + sellConfirmsFound);
      Print("");
      Print("🎯 SINAIS PROCESSADOS:");
      Print("   📈 Compra (Buffer invisível): ", buySignalsFound);
      Print("   📉 Venda (Buffer invisível): ", sellSignalsFound);
      Print("   Total: ", buySignalsFound + sellSignalsFound);
      Print("");
      Print("💰 TRADES REGISTRADOS:");
      Print("   Total: ", totalTrades);
      Print("   Wins: ", totalWins);
      Print("   Losses: ", totalLosses);
      Print("   Balance: $", DoubleToString(currentBalance, 2));
      Print("");
      Print("🔍 DIAGNÓSTICO:");
      if(buyPivotsFound == 0 && sellPivotsFound == 0)
         Print("   ⚠️ PROBLEMA: Nenhum pivô detectado! Diminua 'PivotStrength' nos inputs.");
      else if(buyConfirmsFound == 0 && sellConfirmsFound == 0)
         Print("   ⚠️ PROBLEMA: Pivôs detectados mas sem confirmações! Ajuste 'ConfirmCandles'.");
      else if(buySignalsFound == 0 && sellSignalsFound == 0)
         Print("   ⚠️ PROBLEMA: Confirmações OK mas sinais bloqueados! Desabilite filtros temporariamente.");
      else if(totalTrades == 0)
         Print("   ⚠️ PROBLEMA: Sinais OK mas trades não registrados! Verifique 'EnableBacktest' e 'ShowSLTPLines'.");
      else
         Print("   ✅ Sistema funcionando corretamente!");
      
      Print("════════════════════════════════════════");
      
      firstRunComplete = true;
   }
   
   // Verificar resultados dos trades (SEMPRE em nova barra)
   if(rates_total > 0 && Time[0] != lastBarTime)
   {
      CheckTradeResults();
      CalculateMetrics(); // ⭐ FORÇAR CÁLCULO
      lastBarTime = Time[0];
      
      // Debug (reduzido para não poluir)
      static int barCount = 0;
      barCount++;
      if(barCount % 10 == 0) // A cada 10 barras
      {
         Print("🔄 NOVA BARRA | Trades: ", totalTrades, " | Wins: ", totalWins, 
               " | Losses: ", totalLosses, " | Balance: $", DoubleToString(currentBalance, 2));
      }
   }
   
   // ⭐ FORÇAR ATUALIZAÇÃO DO PAINEL (SEMPRE)
   UpdateInfoPanel();
   
   // Redesenhar gráfico
   ChartRedraw(0);
   
   return(rates_total);
}

// Bloco 5

//+------------------------------------------------------------------+
//| Detectar Pivôs de Alta e Baixa                                  |
//+------------------------------------------------------------------+
void DetectPivots(int bar)
{
   if(bar < PivotStrength + MaxConfirmCandles + 10) return;
   
   double atr = iATR(NULL, 0, ATRPeriod, bar);
   if(atr <= 0) return;
   
   double minReversal = atr * ATRMultiplier;
   
   // === PIVÔ DE COMPRA (Fundo) - ESTRELA VERMELHA ===
   bool isBuyPivot = true;
   double lowestLow = Low[bar];
   
   for(int j = 1; j <= PivotStrength; j++)
   {
      if(Low[bar + j] < lowestLow || Low[bar - j] < lowestLow)
      {
         isBuyPivot = false;
         break;
      }
   }
   
   if(isBuyPivot)
   {
      double highestAfter = High[bar];
      for(int j = 1; j <= ConfirmCandles && bar - j >= 0; j++)
      {
         if(High[bar - j] > highestAfter)
            highestAfter = High[bar - j];
      }
      
      double reversal = highestAfter - lowestLow;
      
      if(reversal >= minReversal)
      {
         int bullishCandles = 0;
         for(int j = 1; j <= ConfirmCandles && bar - j >= 0; j++)
         {
            if(Close[bar - j] > Open[bar - j])
               bullishCandles++;
         }
         
         if(bullishCandles >= ConfirmCandles)
         {
            BuyPivotBuf[bar] = lowestLow;
            lastBuyPivotBar = bar;
            lastBuyPivotPrice = lowestLow;
            
            // Desenhar estrela VERMELHA no fundo
            DrawStar(true, bar, lowestLow);
         }
      }
   }
   
   // === PIVÔ DE VENDA (Topo) - ESTRELA AZUL ===
   bool isSellPivot = true;
   double highestHigh = High[bar];
   
   for(int j = 1; j <= PivotStrength; j++)
   {
      if(High[bar + j] > highestHigh || High[bar - j] > highestHigh)
      {
         isSellPivot = false;
         break;
      }
   }
   
   if(isSellPivot)
   {
      double lowestAfter = Low[bar];
      for(int j = 1; j <= ConfirmCandles && bar - j >= 0; j++)
      {
         if(Low[bar - j] < lowestAfter)
            lowestAfter = Low[bar - j];
      }
      
      double reversal = highestHigh - lowestAfter;
      
      if(reversal >= minReversal)
      {
         int bearishCandles = 0;
         for(int j = 1; j <= ConfirmCandles && bar - j >= 0; j++)
         {
            if(Close[bar - j] < Open[bar - j])
               bearishCandles++;
         }
         
         if(bearishCandles >= ConfirmCandles)
         {
            SellPivotBuf[bar] = highestHigh;
            lastSellPivotBar = bar;
            lastSellPivotPrice = highestHigh;
            
            // Desenhar estrela AZUL no topo
            DrawStar(false, bar, highestHigh);
         }
      }
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


// Bloco 6

//+------------------------------------------------------------------+
//| Processar Confirmação No-Repaint                                 |
//+------------------------------------------------------------------+
void ProcessConfirmation(int bar)
{
   if(bar < 1) return;
   
   // === CONFIRMAÇÃO DE COMPRA (SETA AZUL) ===
   if(lastBuyPivotBar > 0 && bar <= lastBuyPivotBar - 1)
   {
      int barsSincePivot = lastBuyPivotBar - bar;
      
      if(barsSincePivot > 0 && barsSincePivot <= MaxConfirmCandles)
      {
         if(ValidateBuyConfirmation(bar, lastBuyPivotBar, lastBuyPivotPrice))
         {
            BuyConfirmBuf[bar] = Low[bar] - 15 * Point;
            
            if(PassEntryFilters(true, bar))
            {
               double sl = 0.0, tp = 0.0;
               CalculateSLTP(true, bar, lastBuyPivotPrice, sl, tp);
               
               BuySignalBuf[bar] = Close[bar];
               DrawTradeSetup(true, bar, Close[bar], sl, tp, lastBuyPivotPrice);
               
               if(bar == 1 && EnableAlerts)
               {
                  SendTradeAlert(true, Close[bar], sl, tp);
               }
            }
            
            lastBuyPivotBar = -1;
         }
      }
   }
   
   // === CONFIRMAÇÃO DE VENDA (SETA VERMELHA) ===
   if(lastSellPivotBar > 0 && bar <= lastSellPivotBar - 1)
   {
      int barsSincePivot = lastSellPivotBar - bar;
      
      if(barsSincePivot > 0 && barsSincePivot <= MaxConfirmCandles)
      {
         if(ValidateSellConfirmation(bar, lastSellPivotBar, lastSellPivotPrice))
         {
            SellConfirmBuf[bar] = High[bar] + 15 * Point;
            
            if(PassEntryFilters(false, bar))
            {
               double sl = 0.0, tp = 0.0;
               CalculateSLTP(false, bar, lastSellPivotPrice, sl, tp);
               
               SellSignalBuf[bar] = Close[bar];
               DrawTradeSetup(false, bar, Close[bar], sl, tp, lastSellPivotPrice);
               
               if(bar == 1 && EnableAlerts)
               {
                  SendTradeAlert(false, Close[bar], sl, tp);
               }
            }
            
            lastSellPivotBar = -1;
         }
      }
   }
}

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
//| Verificar Todos os Filtros de Entrada                            |
//+------------------------------------------------------------------+
bool PassEntryFilters(bool isBuy, int bar)
{
   // ⭐ DEBUG: Rastrear quais filtros estão bloqueando
   static int debugCount = 0;
   debugCount++;
   bool shouldDebug = (debugCount <= 5); // Debug apenas nos primeiros 5 sinais
   
   if(shouldDebug)
   {
      Print("════════════════════════════════════════");
      Print("🔍 VERIFICANDO FILTROS | Sinal #", debugCount);
      Print("   Tipo: ", (isBuy ? "COMPRA 📈" : "VENDA 📉"));
      Print("   Bar: ", bar, " | Time: ", TimeToString(Time[bar], TIME_DATE|TIME_MINUTES));
      Print("   Close: ", DoubleToString(Close[bar], Digits));
   }
   
   // === FILTRO 1: TENDÊNCIA ===
   if(UseTrendFilter)
   {
      double ema = iMA(NULL, TrendTimeframe, TrendEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
      
      if(shouldDebug)
      {
         Print("📊 Filtro 1: TENDÊNCIA");
         Print("   UseTrendFilter: TRUE");
         Print("   EMA ", TrendEMAPeriod, " (", EnumToString(TrendTimeframe), "): ", DoubleToString(ema, Digits));
         Print("   Close[", bar, "]: ", DoubleToString(Close[bar], Digits));
      }
      
      if(isBuy && Close[bar] < ema)
      {
         if(shouldDebug)
            Print("   ❌ BLOQUEADO: COMPRA abaixo da EMA");
         return false;
      }
      if(!isBuy && Close[bar] > ema)
      {
         if(shouldDebug)
            Print("   ❌ BLOQUEADO: VENDA acima da EMA");
         return false;
      }
      
      if(shouldDebug)
         Print("   ✅ PASSOU: Tendência OK");
   }
   else if(shouldDebug)
   {
      Print("📊 Filtro 1: TENDÊNCIA");
      Print("   UseTrendFilter: FALSE (desabilitado)");
      Print("   ✅ PASSOU: Filtro desabilitado");
   }
   
   // === FILTRO 2: ATR MÍNIMO ===
   if(UseATRFilter) // ✅ AGORA VERIFICA O INPUT!
   {
      double atr = iATR(NULL, 0, ATRPeriod, bar);
      
      if(shouldDebug)
      {
         Print("📊 Filtro 2: ATR MÍNIMO");
         Print("   UseATRFilter: TRUE");
         Print("   ATR: ", DoubleToString(atr, 5));
         Print("   MinATR: ", DoubleToString(MinATR, 5));
      }
      
      if(atr < MinATR)
      {
         if(shouldDebug)
            Print("   ❌ BLOQUEADO: ATR muito baixo");
         return false;
      }
      
      if(shouldDebug)
         Print("   ✅ PASSOU: ATR OK");
   }
   else if(shouldDebug)
   {
      Print("📊 Filtro 2: ATR MÍNIMO");
      Print("   UseATRFilter: FALSE (desabilitado)");
      Print("   ✅ PASSOU: Filtro desabilitado");
   }
   
   // === FILTRO 3: HORÁRIO ===
   if(UseTimeFilter)
   {
      int hour = TimeHour(Time[bar]);
      int dayOfWeek = TimeDayOfWeek(Time[bar]);
      
      if(shouldDebug)
      {
         Print("📊 Filtro 3: HORÁRIO");
         Print("   UseTimeFilter: TRUE");
         Print("   Hora atual: ", hour, " GMT");
         Print("   Horário permitido: ", StartHour, " - ", EndHour, " GMT");
         Print("   Dia da semana: ", dayOfWeek, " (1=Dom, 2=Seg, ... 6=Sex)");
      }
      
      if(hour < StartHour || hour > EndHour)
      {
         if(shouldDebug)
            Print("   ❌ BLOQUEADO: Fora do horário permitido");
         return false;
      }
      
      if(AvoidFridayLate && dayOfWeek == 5 && hour > 15)
      {
         if(shouldDebug)
            Print("   ❌ BLOQUEADO: Sexta-feira tarde (após 15h)");
         return false;
      }
      
      if(shouldDebug)
         Print("   ✅ PASSOU: Horário OK");
   }
   else if(shouldDebug)
   {
      Print("📊 Filtro 3: HORÁRIO");
      Print("   UseTimeFilter: FALSE (desabilitado)");
      Print("   ✅ PASSOU: Filtro desabilitado");
   }
   
   // === FILTRO 4: SPREAD ===
   if(UseSpreadFilter) // ✅ AGORA VERIFICA O INPUT!
   {
      double spread = (Ask - Bid) / Point;
      
      if(shouldDebug)
      {
         Print("📊 Filtro 4: SPREAD");
         Print("   UseSpreadFilter: TRUE");
         Print("   Spread atual: ", DoubleToString(spread, 1), " pontos");
         Print("   Máximo permitido: ", MaxSpreadPoints, " pontos");
      }
      
      if(spread > MaxSpreadPoints)
      {
         if(shouldDebug)
            Print("   ❌ BLOQUEADO: Spread muito alto");
         return false;
      }
      
      if(shouldDebug)
         Print("   ✅ PASSOU: Spread OK");
   }
   else if(shouldDebug)
   {
      Print("📊 Filtro 4: SPREAD");
      Print("   UseSpreadFilter: FALSE (desabilitado)");
      Print("   ✅ PASSOU: Filtro desabilitado");
   }
   
   // === FILTRO 5: RSI ===
   if(UseRSIFilter) // ✅ AGORA VERIFICA O INPUT!
   {
      double rsi = iRSI(NULL, 0, RSIPeriod, PRICE_CLOSE, bar);
      
      if(shouldDebug)
      {
         Print("📊 Filtro 5: RSI");
         Print("   UseRSIFilter: TRUE");
         Print("   RSI: ", DoubleToString(rsi, 2));
      }
      
      if(isBuy)
      {
         if(shouldDebug)
            Print("   RSI mínimo para COMPRA: ", RSILevelBuy);
         
         if(rsi < RSILevelBuy || rsi > 70)
         {
            if(shouldDebug)
               Print("   ❌ BLOQUEADO: RSI fora do range (", RSILevelBuy, " - 70)");
            return false;
         }
      }
      else
      {
         if(shouldDebug)
            Print("   RSI máximo para VENDA: ", RSILevelSell);
         
         if(rsi > RSILevelSell || rsi < 30)
         {
            if(shouldDebug)
               Print("   ❌ BLOQUEADO: RSI fora do range (30 - ", RSILevelSell, ")");
            return false;
         }
      }
      
      if(shouldDebug)
         Print("   ✅ PASSOU: RSI OK");
   }
   else if(shouldDebug)
   {
      Print("📊 Filtro 5: RSI");
      Print("   UseRSIFilter: FALSE (desabilitado)");
      Print("   ✅ PASSOU: Filtro desabilitado");
   }
   
   // === TODOS OS FILTROS PASSARAM ===
   if(shouldDebug)
   {
      Print("════════════════════════════════════════");
      Print("✅✅✅ TODOS OS FILTROS PASSARAM! ✅✅✅");
      Print("   Sinal APROVADO para processamento");
      Print("════════════════════════════════════════");
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Calcular Stop Loss e Take Profit                                |
//+------------------------------------------------------------------+
void CalculateSLTP(bool isBuy, int bar, double pivotPrice, double &sl, double &tp)
{
   double atr = iATR(NULL, 0, ATRPeriod, bar);
   double slDistance = atr * StopLossATRMulti;
   
   double slDistancePoints = slDistance / Point;
   if(slDistancePoints < MinStopLossPoints)
      slDistance = MinStopLossPoints * Point;
   if(slDistancePoints > MaxStopLossPoints)
      slDistance = MaxStopLossPoints * Point;
   
   double entry = Close[bar];
   
   if(isBuy)
   {
      sl = pivotPrice - slDistance;
      tp = entry + (slDistance * RiskRewardRatio);
   }
   else
   {
      sl = pivotPrice + slDistance;
      tp = entry - (slDistance * RiskRewardRatio);
   }
   
   sl = NormalizeDouble(sl, Digits);
   tp = NormalizeDouble(tp, Digits);
}

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
//| Registrar Novo Trade com Linhas                                 |
//+------------------------------------------------------------------+
void RegisterTrade(bool isBuy, int bar, double entry, double sl, double tp)
{
   Print("════════════════════════════════════════");
   Print("🔔 RegisterTrade CHAMADO!");
   Print("   Tipo: ", (isBuy ? "COMPRA 📈" : "VENDA 📉"));
   Print("   Bar: ", bar, " | Time: ", TimeToString(Time[bar], TIME_DATE|TIME_MINUTES));
   Print("   Entry: ", DoubleToString(entry, Digits));
   Print("   SL: ", DoubleToString(sl, Digits), " | Distância: ", DoubleToString(MathAbs(entry - sl) / Point, 1), " pips");
   Print("   TP: ", DoubleToString(tp, Digits), " | Distância: ", DoubleToString(MathAbs(tp - entry) / Point, 1), " pips");
   Print("════════════════════════════════════════");
   
   Print("🔍 Verificando EnableBacktest...");
   Print("   EnableBacktest = ", (EnableBacktest ? "TRUE ✅" : "FALSE ❌"));
   
   if(!EnableBacktest)
   {
      Print("════════════════════════════════════════");
      Print("❌ TRADE BLOQUEADO!");
      Print("⚠️ MOTIVO: EnableBacktest = FALSE");
      Print("💡 SOLUÇÃO: Nos inputs do indicador, ative:");
      Print("   → 'Habilitar Rastreamento' = TRUE");
      Print("════════════════════════════════════════");
      return;
   }
   
   Print("✅ Backtest habilitado - Prosseguindo com registro...");
   
   Print("📊 Estado ANTES do registro:");
   Print("   totalTrades atual: ", totalTrades);
   Print("   Array trades size: ", ArraySize(trades));
   
   ArrayResize(trades, totalTrades + 1);
   Print("✅ Array redimensionado para: ", ArraySize(trades));
   
   string timeStr = TimeToString(Time[bar], TIME_DATE|TIME_MINUTES);
   
   trades[totalTrades].openTime = Time[bar];
   trades[totalTrades].entryPrice = entry;
   trades[totalTrades].slPrice = sl;
   trades[totalTrades].tpPrice = tp;
   trades[totalTrades].isBuy = isBuy;
   trades[totalTrades].status = 0;
   trades[totalTrades].profitUSD = 0.0;
   trades[totalTrades].closeTime = 0;
   trades[totalTrades].barIndex = bar;
   trades[totalTrades].linesDrawn = false;
   
   trades[totalTrades].entryLineName = prefix + "ENTRY_" + timeStr;
   trades[totalTrades].slLineName = prefix + "SL_" + timeStr;
   trades[totalTrades].tpLineName = prefix + "TP_" + timeStr;
   
   totalTrades++;
   
   Print("════════════════════════════════════════");
   Print("✅✅✅ TRADE REGISTRADO COM SUCESSO! ✅✅✅");
   Print("   Index registrado: ", totalTrades - 1);
   Print("   Total de trades: ", totalTrades);
   Print("   Status: ABERTO (0)");
   Print("════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Verificar Resultados dos Trades                                 |
//+------------------------------------------------------------------+
void CheckTradeResults()
{
   static int checkCount = 0;
   checkCount++;
   
   if(checkCount % 10 == 0)
   {
      Print("🔍 CheckTradeResults #", checkCount, " | Total Trades: ", totalTrades, 
            " | Wins: ", totalWins, " | Losses: ", totalLosses);
   }
   
   if(!EnableBacktest)
   {
      if(checkCount % 20 == 0)
         Print("❌ CheckTradeResults BLOQUEADO - EnableBacktest = FALSE");
      return;
   }
   
   if(totalTrades == 0)
   {
      if(checkCount % 50 == 0)
         Print("⚠️ CheckTradeResults executando mas totalTrades = 0 (nenhum trade registrado)");
      return;
   }
   
   if(checkCount % 20 == 0)
      Print("🔄 Verificando ", totalTrades, " trade(s) aberto(s)...");
   
   for(int i = 0; i < totalTrades; i++)
   {
      if(trades[i].status != 0) continue;
      
      bool hitSL = false;
      bool hitTP = false;
      datetime closeTime = 0;
      int closeBar = 0;
      
      int entryBarIndex = trades[i].barIndex;
      
      for(int j = entryBarIndex - 1; j >= 0; j--)
      {
         if(trades[i].isBuy)
         {
            if(High[j] >= trades[i].tpPrice)
            {
               hitTP = true;
               closeTime = Time[j];
               closeBar = j;
               break;
            }
            if(Low[j] <= trades[i].slPrice)
            {
               hitSL = true;
               closeTime = Time[j];
               closeBar = j;
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
               break;
            }
            if(High[j] >= trades[i].slPrice)
            {
               hitSL = true;
               closeTime = Time[j];
               closeBar = j;
               break;
            }
         }
      }
      
      if(hitTP || hitSL)
      {
         trades[i].closeTime = closeTime;
         
         Print("════════════════════════════════════════");
         Print("💰 TRADE FECHADO!");
         Print("   Index: ", i, " de ", totalTrades);
         Print("   Tipo: ", (trades[i].isBuy ? "COMPRA 📈" : "VENDA 📉"));
         Print("   Resultado: ", (hitTP ? "✅ VITÓRIA (TP)" : "❌ DERROTA (SL)"));
         Print("   Entry Bar: ", trades[i].barIndex, " | Close Bar: ", closeBar);
         Print("   Entry Price: ", DoubleToString(trades[i].entryPrice, Digits));
         Print("   Exit Price: ", DoubleToString(hitTP ? trades[i].tpPrice : trades[i].slPrice, Digits));
         Print("════════════════════════════════════════");
         
         if(trades[i].linesDrawn)
         {
            ObjectDelete(0, trades[i].entryLineName);
            ObjectDelete(0, trades[i].slLineName);
            ObjectDelete(0, trades[i].tpLineName);
            trades[i].linesDrawn = false;
            Print("🗑️ Linhas SL/TP deletadas do gráfico");
         }
         
         if(hitTP)
         {
            trades[i].status = 1;
            double slPips = MathAbs(trades[i].entryPrice - trades[i].slPrice) / Point;
            trades[i].profitUSD = CalculateProfitUSD(slPips, true);
            
            totalWins++;
            totalProfitUSD += trades[i].profitUSD;
            
            Print("✅ WIN registrado | Total Wins: ", totalWins, " | Profit: $", DoubleToString(trades[i].profitUSD, 2));
            
            DrawTradeResult(trades[i], true, closeBar);
         }
         else if(hitSL)
         {
            trades[i].status = 2;
            double slPips = MathAbs(trades[i].entryPrice - trades[i].slPrice) / Point;
            trades[i].profitUSD = CalculateProfitUSD(slPips, false);
            
            totalLosses++;
            totalLossUSD += MathAbs(trades[i].profitUSD);
            
            Print("❌ LOSS registrado | Total Losses: ", totalLosses, " | Loss: $", DoubleToString(MathAbs(trades[i].profitUSD), 2));
            
            DrawTradeResult(trades[i], false, closeBar);
         }
         
         Print("📊 Totais atualizados:");
         Print("   Wins: ", totalWins, " | Losses: ", totalLosses);
         Print("   Total Profit: $", DoubleToString(totalProfitUSD, 2));
         Print("   Total Loss: $", DoubleToString(totalLossUSD, 2));
         Print("════════════════════════════════════════");
      }
   }
   
   CalculateMetrics();
}

//+------------------------------------------------------------------+
//| Calcular Lucro/Prejuízo em USD                                  |
//+------------------------------------------------------------------+
double CalculateProfitUSD(double pips, bool isWin)
{
   double riskAmount = InitialBalance * (RiskPerTrade / 100.0);
   
   if(isWin)
   {
      return riskAmount * RiskRewardRatio;
   }
   else
   {
      return -riskAmount;
   }
}

//+------------------------------------------------------------------+
//| Desenhar Resultado do Trade COM LINHA TRACEJADA AZUL            |
//+------------------------------------------------------------------+
void DrawTradeResult(TradeInfo &trade, bool isWin, int closeBar)
{
   string suffix = "_" + TimeToString(trade.openTime, TIME_DATE|TIME_MINUTES);
   
   // ═══ 1️⃣ LINHA TRACEJADA: ENTRY → TP/SL ATINGIDO ═══
   string lineName = prefix + "RESULT_LINE" + suffix;
   double exitPrice = isWin ? trade.tpPrice : trade.slPrice;
   
   // Criar linha tracejada do ponto de entrada até o fechamento
   if(ObjectCreate(0, lineName, OBJ_TREND, 0, trade.openTime, trade.entryPrice, trade.closeTime, exitPrice))
   {
      // ✅ WIN = AZUL TRACEJADO | LOSS = VERMELHO TRACEJADO
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, isWin ? clrDodgerBlue : clrRed);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DOT); // Linha tracejada (pontos)
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, lineName, OBJPROP_BACK, true); // No fundo
      ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false); // Não estender
   }
   
   // ═══ 2️⃣ MARCADOR DE RESULTADO (THUMB UP/DOWN) ═══
   string resultName = prefix + "RESULT" + suffix;
   
   ObjectCreate(0, resultName, OBJ_ARROW, 0, trade.closeTime, exitPrice);
   ObjectSetInteger(0, resultName, OBJPROP_ARROWCODE, isWin ? 252 : 251); // Thumb up/down
   ObjectSetInteger(0, resultName, OBJPROP_COLOR, isWin ? clrDodgerBlue : clrRed); // ✅ AZUL para WIN
   ObjectSetInteger(0, resultName, OBJPROP_WIDTH, 3);
   ObjectSetInteger(0, resultName, OBJPROP_BACK, false);
   
   // ═══ 3️⃣ TEXTO DO RESULTADO COM VALOR EM AZUL/VERMELHO ═══
   string resultText = prefix + "RESULT_TEXT" + suffix;
   
   // Formatar texto completo
   string text;
   if(isWin)
   {
      // ✅ WIN: texto completo em AZUL
      text = StringFormat("WIN +$%.2f", MathAbs(trade.profitUSD));
   }
   else
   {
      // ❌ LOSS: texto completo em VERMELHO
      text = StringFormat("LOSS -$%.2f", MathAbs(trade.profitUSD));
   }
   
   double textPrice = isWin ? exitPrice + 30*Point : exitPrice - 40*Point;
   ObjectCreate(0, resultText, OBJ_TEXT, 0, trade.closeTime, textPrice);
   ObjectSetString(0, resultText, OBJPROP_TEXT, text);
   ObjectSetInteger(0, resultText, OBJPROP_COLOR, isWin ? clrDodgerBlue : clrRed); // ✅ AZUL para WIN
   ObjectSetInteger(0, resultText, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, resultText, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, resultText, OBJPROP_BACK, false);
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
      startDateStr = StringFormat("%02d%02d%04d", dtStart.mon, dtStart.day, dtStart.year);
   }
   
   // Formatar data final
   if(lastBarProcessed > 0)
   {
      MqlDateTime dtEnd;
      TimeToStruct(lastBarProcessed, dtEnd);
      endDateStr = StringFormat("%02d%02d%04d", dtEnd.mon, dtEnd.day, dtEnd.year);
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
   
   // ═══ ÚLTIMO SINAL ═══
   string lastSignal = "Nenhum";
   color lastSignalColor = clrGray;
   
   for(int i = 1; i < 100; i++)
   {
      if(BuySignalBuf[i] != 0.0)
      {
         lastSignal = StringFormat("COMPRA ha %d barras", i);
         lastSignalColor = clrDodgerBlue;
         break;
      }
      if(SellSignalBuf[i] != 0.0)
      {
         lastSignal = StringFormat("VENDA ha %d barras", i);
         lastSignalColor = clrOrangeRed;
         break;
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

