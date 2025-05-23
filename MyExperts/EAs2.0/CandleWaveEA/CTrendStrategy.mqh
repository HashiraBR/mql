//+------------------------------------------------------------------+
//|                                               CTrendStrategy.mqh |
//|                                                    Danne Pereira |
//|                                             https://www.aipi.com |
//+------------------------------------------------------------------+
#property copyright "Danne Pereira"
#property link      "https://www.aipi.com"
#property version   "1.00"
#include "../../libs/CUtils.mqh"
#include "../../libs/CPrintManager.mqh"
#include "../../libs/structs/TradeSignal.mqh"

class CTrendStrategy
  {
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_volumeAVGPeriod;
   double            m_candleLongPercent;
   
   double            m_stopLoss;
   double            m_takeProfit;
   double            m_lotSize;
   CPrintManager     print;
   
   // Métodos privados
   bool              IsCandleLong(double lastClose, double lastOpen, double prevClose, double prevOpen);
   bool              IsCandleReversal(bool isUptrend, double lastClose, double lastOpen, double prevClose, double prevOpen);
   bool              IsCandleSizeValid(double candleSize, double maxCandleSize);
   bool              IsVolumeAboveAverage();
   void              SetupSignal(TradeSignal &signal, ENUM_TREND_DIRECTION direction);

public:
                     CTrendStrategy(string symbol, ENUM_TIMEFRAMES timeframe, int volumeAVGPeriod, double candleLongPercent, 
                     double stopLoss, double takeProfit, double lotSize) :
                        m_symbol(symbol),
                        m_timeframe(timeframe),
                        m_volumeAVGPeriod(volumeAVGPeriod),
                        m_candleLongPercent(candleLongPercent),
                        m_stopLoss(stopLoss),
                        m_takeProfit(takeProfit),
                        m_lotSize(lotSize)
                     {
                        Print("TrendStrategy inicializado para ", m_symbol, " no timeframe ", EnumToString(m_timeframe));
                     }
                    ~CTrendStrategy(){};
                    
                    TradeSignal CheckForSignal(double maShortValue, ENUM_TREND_DIRECTION currentTrend, double maxCandleSize);
};

//+------------------------------------------------------------------+
//| Verifica sinal de trading                                        |
//+------------------------------------------------------------------+
TradeSignal CTrendStrategy::CheckForSignal(double maShortValue, ENUM_TREND_DIRECTION currentTrend, double maxCandleSize)
{
   TradeSignal signal;
   double lastClose = iClose(m_symbol, m_timeframe, 1);
   double lastOpen = iOpen(m_symbol, m_timeframe, 1);
   double prevClose = iClose(m_symbol, m_timeframe, 2);
   double prevOpen = iOpen(m_symbol, m_timeframe, 2);
   double candleSize = MathAbs(iHigh(m_symbol, m_timeframe, 1) - iLow(m_symbol, m_timeframe, 1));

   // Debug information
   print.DebugPrint(" === >> INÍCIO - TrendStrategy: Verificando sinal para tendência " + EnumToString(currentTrend));
   print.DebugPrint(StringFormat(" - Preço: %.5f vs MA: %.5f | Tamanho do candle: %.5f", 
                 lastClose, maShortValue, candleSize));

   // Condições básicas
   bool isDirectionOK = (currentTrend == TREND_UP && lastClose > maShortValue) ||
                       (currentTrend == TREND_DOWN && lastClose < maShortValue);
   
   bool isValid = isDirectionOK &&
                 IsCandleLong(lastClose, lastOpen, prevClose, prevOpen) &&
                 IsCandleReversal(currentTrend == TREND_UP, lastClose, lastOpen, prevClose, prevOpen) &&
                 IsVolumeAboveAverage() &&
                 IsCandleSizeValid(candleSize, maxCandleSize);

   if(isValid)
   {
      SetupSignal(signal, currentTrend);
      print.DebugPrint("SINAL CONFIRMADO - " + signal.comment);
   }
   else
   {
      print.DebugPrint("SINAL REJEITADO");
   }

   print.DebugPrint(" === >> FIM - TrendStrategy");
   return signal;
}

//+------------------------------------------------------------------+
//| Configura o sinal de trade                                       |
//+------------------------------------------------------------------+
void CTrendStrategy::SetupSignal(TradeSignal &signal, ENUM_TREND_DIRECTION direction)
{
   signal.isValid = true;
   signal.direction = direction;
   signal.lotSize = m_lotSize; // Definido nos inputs do EA
   signal.stopLoss = m_stopLoss;
   signal.takeProfit = m_takeProfit;
   signal.comment = "Trend " + (direction == TREND_UP ? "Up" : "Down");
}

//+------------------------------------------------------------------+
//| Verifica se o candle é longo o suficiente                        |
//+------------------------------------------------------------------+
bool CTrendStrategy::IsCandleLong(double lastClose, double lastOpen, double prevClose, double prevOpen)
{
   double lastRange = MathAbs(lastClose - lastOpen);
   double previousRange = MathAbs(prevClose - prevOpen);
   bool isLong = (lastRange > previousRange * (1 + m_candleLongPercent/100.0));
   
   print.DebugPrint(StringFormat(" - Candle longo: %s (Atual: %.5f vs Anterior: %.5f)", 
                 isLong ? "SIM" : "NÃO", lastRange, previousRange));
   return isLong;
}

//+------------------------------------------------------------------+
//| Verifica padrão de reversão                                      |
//+------------------------------------------------------------------+
bool CTrendStrategy::IsCandleReversal(bool isUptrend, double lastClose, double lastOpen, 
                                    double prevClose, double prevOpen)
{
   bool isReversal = false;
   
   if(isUptrend)
   {
      isReversal = (prevClose < prevOpen && lastClose > lastOpen && lastClose > prevOpen);
      print.DebugPrint(StringFormat(" - Reversão de alta: %s (Fechamento atual %.5f > Abertura anterior %.5f)", 
                    isReversal ? "SIM" : "NÃO", lastClose, prevOpen));
   }
   else
   {
      isReversal = (prevClose > prevOpen && lastClose < lastOpen && lastClose < prevOpen);
      print.DebugPrint(StringFormat(" - Reversão de baixa: %s (Fechamento atual %.5f < Abertura anterior %.5f)", 
                    isReversal ? "SIM" : "NÃO", lastClose, prevOpen));
   }
   
   return isReversal;
}

//+------------------------------------------------------------------+
//| Verifica volume acima da média                                   |
//+------------------------------------------------------------------+
bool CTrendStrategy::IsVolumeAboveAverage()
{
   bool isVolumeOK = CUtils::IsVolumeAboveAvg(m_volumeAVGPeriod, m_symbol, m_timeframe);
   print.DebugPrint(" - Volume acima da média: " + (isVolumeOK ? "SIM" : "NÃO"));
   return isVolumeOK;
}

//+------------------------------------------------------------------+
//| Verifica tamanho do candle                                       |
//+------------------------------------------------------------------+
bool CTrendStrategy::IsCandleSizeValid(double candleSize, double maxCandleSize)
{
   bool isValid = (candleSize <= maxCandleSize);
   print.DebugPrint(StringFormat(" - Tamanho válido: %s (%.5f <= %.5f)", 
                 isValid ? "SIM" : "NÃO", candleSize, maxCandleSize));
   return isValid;
}