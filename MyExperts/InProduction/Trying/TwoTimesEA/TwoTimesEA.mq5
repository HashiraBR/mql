//+------------------------------------------------------------------+
//|                                                      BotBollingerRSIStoch.mq5 |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

#include "../DefaultInputs.mqh"
#include "../DefaultFunctions.mqh"

// Inputs
input ENUM_TIMEFRAMES InpLongPeriod = PERIOD_M2; // Timeframe do gráfico maior

input int      InpBollingerPeriod = 20;    // Período das Bandas de Bollinger
input double   InpBollingerDeviation = 2.0; // Desvio padrão das Bandas de Bollinger
input int      InpRSIPeriod = 14;          // Período do RSI
input int      InpRSILow = 20;             // Nível inferior do RSI
input int      InpRSIHigh = 80;            // Nível superior do RSI
input int      InpStochKPeriod = 5;        // Período %K do Stochastic
input int      InpStochDPeriod = 3;        // Período %D do Stochastic
input int      InpStochSlowing = 3;        // Slowing do Stochastic
input int      InpStochLow = 20;           // Nível inferior do Stochastic
input int      InpStochHigh = 80;          // Nível superior do Stochastic
input bool     InpUseRSI = true;           // Usar RSI na estratégia
input bool     InpUseStoch = true;         // Usar Stochastic na estratégia

// Novos inputs para MACD e Bollinger no período curto
input int      InpShortBollingerPeriod = 20;    // Período das Bandas de Bollinger no curto período
input double   InpShortBollingerDeviation = 2.0; // Desvio padrão das Bandas de Bollinger no curto período
input int      InpMACDFastPeriod = 12;          // Período rápido do MACD
input int      InpMACDSlowPeriod = 26;          // Período lento do MACD
input int      InpMACDSignalPeriod = 9;         // Período do sinal do MACD
input bool     InpUseBollingerShort = true;     // Usar Bollinger no curto período
input bool     InpUseMACD = true;               // Usar MACD na estratégia

// Handles para os indicadores
int bollingerHandle;
int rsiHandle;
int stochHandle;
int shortBollingerHandle; // Handle para Bollinger no curto período
int macdHandle;           // Handle para MACD

enum ENUM_STOCH_SIGNAL
  {
   STOCH_SIGNAL_NONE,  // Nenhum sinal
   STOCH_SIGNAL_BUY,   // Sinal de compra
   STOCH_SIGNAL_SELL   // Sinal de venda
  };

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Verifica se os períodos são válidos
   if(InpLongPeriod <= InpTimeframe)
     {
      Print("O período do gráfico maior deve ser maior que o do gráfico menor.");
      return(INIT_PARAMETERS_INCORRECT);
     }

   // Inicializa os indicadores
   bollingerHandle = iBands(_Symbol, InpLongPeriod, InpBollingerPeriod, 0, InpBollingerDeviation, PRICE_CLOSE);
   if(bollingerHandle == INVALID_HANDLE)
     {
      Print("Falha ao criar o indicador Bandas de Bollinger.");
      return(INIT_FAILED);
     }

   rsiHandle = iRSI(NULL, InpTimeframe, InpRSIPeriod, PRICE_CLOSE);
   if(rsiHandle == INVALID_HANDLE)
     {
      Print("Falha ao criar o indicador RSI.");
      return(INIT_FAILED);
     }

   stochHandle = iStochastic(NULL, InpTimeframe, InpStochKPeriod, InpStochDPeriod, InpStochSlowing, MODE_SMA, STO_LOWHIGH);
   if(stochHandle == INVALID_HANDLE)
     {
      Print("Falha ao criar o indicador Stochastic.");
      return(INIT_FAILED);
     }

   // Inicializa Bollinger no curto período
   shortBollingerHandle = iBands(_Symbol, InpTimeframe, InpShortBollingerPeriod, 0, InpShortBollingerDeviation, PRICE_CLOSE);
   if(shortBollingerHandle == INVALID_HANDLE)
     {
      Print("Falha ao criar o indicador Bandas de Bollinger no curto período.");
      return(INIT_FAILED);
     }

   // Inicializa MACD
   macdHandle = iMACD(_Symbol, InpTimeframe, InpMACDFastPeriod, InpMACDSlowPeriod, InpMACDSignalPeriod, PRICE_CLOSE);
   if(macdHandle == INVALID_HANDLE)
     {
      Print("Falha ao criar o indicador MACD.");
      return(INIT_FAILED);
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // Libera os handles dos indicadores
   if(bollingerHandle != INVALID_HANDLE)
      IndicatorRelease(bollingerHandle);
   if(rsiHandle != INVALID_HANDLE)
      IndicatorRelease(rsiHandle);
   if(stochHandle != INVALID_HANDLE)
      IndicatorRelease(stochHandle);
   if(shortBollingerHandle != INVALID_HANDLE)
      IndicatorRelease(shortBollingerHandle);
   if(macdHandle != INVALID_HANDLE)
      IndicatorRelease(macdHandle);
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
   
   // Verifica horário de funcionamento e fecha posições
   if (!CheckTradingTime(InpMagicNumber)) return;
   if(HasOpenPosition(InpMagicNumber)) return;

   // Obter os dados do gráfico maior (Bandas de Bollinger)
   double upperBand[1], lowerBand[1];
   if(CopyBuffer(bollingerHandle, 1, 1, 1, upperBand) <= 0 || CopyBuffer(bollingerHandle, 2, 1, 1, lowerBand) <= 0)
     {
      Print("Falha ao copiar dados das Bandas de Bollinger.");
      return;
     }

   // Preço de fechamento do candle anterior no gráfico maior
   double closePrice = iClose(NULL, InpLongPeriod, 1);

   // Verificar se o preço está extrapolando as Bandas de Bollinger
   bool isAboveUpperBand = closePrice > upperBand[0];
   bool isBelowLowerBand = closePrice < lowerBand[0];

   // Obter os dados do gráfico menor (RSI, Stochastic, Bollinger e MACD)
   double rsi[1], stochK[2], stochD[2], shortUpperBand[1], shortLowerBand[1], macdMain[1], macdSignal[1];
   
   if(InpUseRSI && CopyBuffer(rsiHandle, 0, 1, 1, rsi) <= 0)
     {
      Print("Falha ao copiar dados do RSI.");
      return;
     }
   if(InpUseStoch && (CopyBuffer(stochHandle, 0, 1, 2, stochK) <= 0 || CopyBuffer(stochHandle, 1, 1, 2, stochD) <= 0))
     {
      Print("Falha ao copiar dados do Stochastic.");
      return;
     }
   if(InpUseBollingerShort && (CopyBuffer(shortBollingerHandle, 1, 1, 1, shortUpperBand) <= 0 || CopyBuffer(shortBollingerHandle, 2, 1, 1, shortLowerBand) <= 0))
     {
      Print("Falha ao copiar dados das Bandas de Bollinger no curto período.");
      return;
     }
   if(InpUseMACD && (CopyBuffer(macdHandle, 0, 1, 1, macdMain) <= 0 || CopyBuffer(macdHandle, 1, 1, 1, macdSignal) <= 0))
     {
      Print("Falha ao copiar dados do MACD.");
      return;
     }
   
   // Verificar o sinal do Stochastic
   ENUM_STOCH_SIGNAL stochSignal = CheckStochSignal(stochK[0], stochD[0], stochK[1], stochD[1], InpStochHigh, InpStochLow);

   // Verificar o sinal do MACD
   bool isMacdSignal = (macdMain[0] > macdSignal[0]); // MACD acima do sinal = sinal de compra

   // Lógica de entrada
   if(isAboveUpperBand)
     {
      // Verificar condições de venda no gráfico menor
      if((InpUseRSI && rsi[0] > InpRSIHigh) || (InpUseStoch && stochSignal == STOCH_SIGNAL_SELL) || 
         (InpUseBollingerShort && closePrice > shortUpperBand[0]) || (InpUseMACD && !isMacdSignal))
        {
         // Executar ordem de venda
         ExecuteSellOrder(InpMagicNumber, InpLotSize, InpStopLoss, InpTakeProfit, "P > B sup. GLong." + (InpUseRSI ? " + RSI alto" : "") + (InpUseStoch ? " + cruz. stoch p/ cima" : "") + (InpUseBollingerShort ? " + P > B sup. GShort" : "") + (InpUseMACD ? " + MACD abaixo do sinal" : ""));
        }
     }
   else if(isBelowLowerBand)
     {
      // Verificar condições de compra no gráfico menor
      if((InpUseRSI && rsi[0] < InpRSILow) || (InpUseStoch && stochSignal == STOCH_SIGNAL_BUY) || 
         (InpUseBollingerShort && closePrice < shortLowerBand[0]) || (InpUseMACD && isMacdSignal))
        {
         // Executar ordem de compra
         ExecuteBuyOrder(InpMagicNumber, InpLotSize, InpStopLoss, InpTakeProfit, "P < B sup. GLong." + (InpUseRSI ? " + RSI baixo" : "") + (InpUseStoch ? " + cruz. stoch p/ baixo" : "") + (InpUseBollingerShort ? " + P < B inf. GShort" : "") + (InpUseMACD ? " + MACD acima do sinal" : ""));
        }
     }
 }

//+------------------------------------------------------------------+
//| Função para verificar o sinal do Stochastic                       |
//| Parâmetros:                                                      |
//|   - stochK: Valor atual de %K                                    |
//|   - stochD: Valor atual de %D                                    |
//|   - prevStochK: Valor anterior de %K                             |
//|   - prevStochD: Valor anterior de %D                             |
//|   - overboughtLevel: Nível de sobrecompra (ex: 80)               |
//|   - oversoldLevel: Nível de sobrevenda (ex: 20)                  |
//| Retorno:                                                         |
//|   - true: Sinal de compra ou venda detectado                     |
//|   - false: Nenhum sinal detectado                                |
//+------------------------------------------------------------------+
ENUM_STOCH_SIGNAL CheckStochSignal(double stochK, double stochD, double prevStochK, double prevStochD, int overboughtLevel = 80, int oversoldLevel = 20)
  {
   // Verifica se %K cruzou %D para cima (sinal de compra)
   if(prevStochK < prevStochD && stochK > stochD)
     {
      // Verifica se o cruzamento ocorreu abaixo do nível de sobrevenda
      if(stochK < oversoldLevel && stochD < oversoldLevel)
        {
         return STOCH_SIGNAL_BUY; // Sinal de compra
        }
     }

   // Verifica se %K cruzou %D para baixo (sinal de venda)
   if(prevStochK > prevStochD && stochK < stochD)
     {
      // Verifica se o cruzamento ocorreu acima do nível de sobrecompra
      if(stochK > overboughtLevel && stochD > overboughtLevel)
        {
         return STOCH_SIGNAL_SELL; // Sinal de venda
        }
     }

   // Nenhum sinal detectado
   return STOCH_SIGNAL_NONE;
  }