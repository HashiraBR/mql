//+------------------------------------------------------------------+
//|                                                      StochCrossTrendBot.mq5 |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

#include "../DefaultInputs.mqh"
#include "../DefaultFunctions.mqh"

// Inputs
input ENUM_TIMEFRAMES InpLongPeriod = PERIOD_M15;      // Timeframe do gráfico maior
//input ENUM_TIMEFRAMES InpShortPeriod = PERIOD_M5;     // Timeframe do gráfico menor

// Parâmetros do Stochastic
input int InpStochKPeriod = 5;                        // Período %K do Stochastic
input int InpStochDPeriod = 3;                        // Período %D do Stochastic
input int InpStochSlowing = 3;                        // Slowing do Stochastic
input int InpStochCandleRange = 3;                    // Range de candles para validar cruzamento no gráfico menor

// Parâmetros da Média Móvel
input int InpMAPeriod = 200;                          // Período da Média Móvel
input ENUM_MA_METHOD InpMAMethod = MODE_SMA;          // Método da Média Móvel (SMA, EMA, etc.)
input bool InpUseMA = true;                           // Habilitar/Desabilitar Média Móvel
input bool InpUseStochTP = false;                     // Usar TP com cruzamento do Stochastic no gráfico menor

// Handles para os indicadores
int stochLongHandle, stochShortHandle, maHandle;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Inicializa os indicadores
   stochLongHandle = iStochastic(_Symbol, InpLongPeriod, InpStochKPeriod, InpStochDPeriod, InpStochSlowing, MODE_SMA, STO_LOWHIGH);
   if(stochLongHandle == INVALID_HANDLE)
     {
      Print("Falha ao criar o indicador Stochastic no gráfico maior.");
      return(INIT_FAILED);
     }

   stochShortHandle = iStochastic(_Symbol, InpTimeframe, InpStochKPeriod, InpStochDPeriod, InpStochSlowing, MODE_SMA, STO_LOWHIGH);
   if(stochShortHandle == INVALID_HANDLE)
     {
      Print("Falha ao criar o indicador Stochastic no gráfico menor.");
      return(INIT_FAILED);
     }

   if(InpUseMA)
     {
      maHandle = iMA(_Symbol, InpLongPeriod, InpMAPeriod, 0, InpMAMethod, PRICE_CLOSE);
      if(maHandle == INVALID_HANDLE)
        {
         Print("Falha ao criar o indicador Média Móvel.");
         return(INIT_FAILED);
        }
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // Libera os handles dos indicadores
   if(stochLongHandle != INVALID_HANDLE)
      IndicatorRelease(stochLongHandle);
   if(stochShortHandle != INVALID_HANDLE)
      IndicatorRelease(stochShortHandle);
   if(maHandle != INVALID_HANDLE)
      IndicatorRelease(maHandle);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   CheckStopsSkippedAndCloseTrade(InpMagicNumber);
   
   // Cancela ordens velhas
   CancelOldPendingOrders(InpMagicNumber, InpOrderExpiration);
   
   // Aplica Trailing Stop se estiver ativado
   if (InpTrailingStop) MonitorTrailingStop(InpMagicNumber, InpStopLoss);

   // Verifica a última negociação e envia e-mail se necessário
   CheckLastTradeAndSendEmail(InpMagicNumber);

   // Verifica se é um novo candle
   if (!isNewCandle()) return;
   
   // Verifica a tendência (se a Média Móvel estiver habilitada)
   bool isUptrend = true; // Por padrão, assume tendência de alta
   if(InpUseMA)
     {
      double maValue[1];
      if(CopyBuffer(maHandle, 0, 0, 1, maValue) <= 0)
        {
         Print("Falha ao copiar dados da Média Móvel.");
         return;
        }
      double closePrice = iClose(_Symbol, InpLongPeriod, 0);
      isUptrend = (closePrice > maValue[0]); // Preço acima da MA = tendência de alta
     }
   
   
   
   // Verifica o Stochastic no gráfico maior
   double stochKLong[2], stochDLong[2]; // Precisamos de 2 valores para verificar o cruzamento
   if(CopyBuffer(stochLongHandle, 0, 0, 2, stochKLong) <= 0 || CopyBuffer(stochLongHandle, 1, 0, 2, stochDLong) <= 0)
     {
      Print("Falha ao copiar dados do Stochastic no gráfico maior.");
      return;
     }

   // Verifica o Stochastic no gráfico menor
   double stochKShort[2], stochDShort[2]; // Precisamos de 2 valores para verificar o cruzamento
   if(CopyBuffer(stochShortHandle, 0, 0, 2, stochKShort) <= 0 || CopyBuffer(stochShortHandle, 1, 0, 2, stochDShort) <= 0)
     {
      Print("Falha ao copiar dados do Stochastic no gráfico menor.");
      return;
     }
   // Verifica se há cruzamento no gráfico maior
   bool isCrossLongUp = (stochKLong[1] < stochDLong[1] && stochKLong[0] > stochDLong[0]); // %K cruzou %D para cima
   bool isCrossLongDown = (stochKLong[1] > stochDLong[1] && stochKLong[0] < stochDLong[0]); // %K cruzou %D para baixo
   
   // Verifica se há cruzamento no gráfico menor
   bool isCrossShortUp = (stochKShort[1] < stochDShort[1] && stochKShort[0] > stochDShort[0]); // %K cruzou %D para cima
   bool isCrossShortDown = (stochKShort[1] > stochDShort[1] && stochKShort[0] < stochDShort[0]); // %K cruzou %D para baixo
   
   
   
   if(InpUseStochTP) closePositionWithDynamicTP(isUptrend, isCrossShortDown, isCrossShortUp);
   
   // Verifica horário de funcionamento e fecha posições
   if (!CheckTradingTime(InpMagicNumber)) return;
   
    if(HasOpenPosition(InpMagicNumber)) return;

   // Lógica de entrada
   if(isUptrend) // Tendência de alta
     {
      // Verifica cruzamento para cima nos dois gráficos
      if(isCrossLongUp && isCrossShortUp)
        {
         ExecuteBuyOrder(InpMagicNumber, InpLotSize, InpStopLoss, InpTakeProfit, "");
        }
     }
   else // Tendência de baixa
     {
      // Verifica cruzamento para baixo nos dois gráficos
      if(isCrossLongDown && isCrossShortDown)
        {
         ExecuteSellOrder(InpMagicNumber, InpLotSize, InpStopLoss, InpTakeProfit, "");
        }
     }
  }
  
  void closePositionWithDynamicTP(bool isUptrend, bool isCrossShortDown, bool isCrossShortUp)
  {
      if(isUptrend && isCrossShortDown) // Tendência de alta e cruzamento para baixo no gráfico menor
      {
         ClosePositionWithMagicNumber(InpMagicNumber);
      }
      else if(!isUptrend && isCrossShortUp) // Tendência de baixa e cruzamento para cima no gráfico menor
      {
         ClosePositionWithMagicNumber(InpMagicNumber);
      }
  }
  