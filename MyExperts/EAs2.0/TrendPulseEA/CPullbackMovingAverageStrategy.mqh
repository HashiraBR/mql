//+------------------------------------------------------------------+
//|                                           CPullbackMovingAverageStrategy.mqh |
//|                                                    Danne Pereira |
//|                                             https://www.aipi.com |
//+------------------------------------------------------------------+
#property copyright "Danne Pereira"
#property link      "https://www.aipi.com"
#property version   "1.00"
#property strict

class CPullbackMovingAverageStrategy
{
private:
   string m_symbol;
   int m_magicNumber;
   ENUM_TIMEFRAMES m_timeframe;

   int m_maShortHandle;
   int m_maShortPeriod;
   ENUM_MA_METHOD m_maShortMode;
   
   int m_maMediumHandle;
   int m_maMediumPeriod;
   ENUM_MA_METHOD m_maMediumMode;
   
   int m_maLongHandle;
   int m_maLongPeriod;
   ENUM_MA_METHOD m_maLongMode;
   
   double m_maShortValue;
   double m_maMediumValue;
   double m_maLongValue;
   
   double m_stopLossPoints;
   double m_stopLossPrice;
   double m_entryPrice;
   int m_window;
   double m_minDistSM;
   double m_minDistML;
   double m_minDistSL;
   
   bool m_isUpTrend;
   bool m_isDownTrend;
   ENUM_ORDER_TYPE m_orderType;
   
   double m_maShortBuffer[];
   double m_maMediumBuffer[];
   double m_maLongBuffer[];
   
   bool CheckTrendConditions();
   bool CheckPullbackConditions(bool isUpTrend);
   double Rounder(double price);
   

public:
                     CPullbackMovingAverageStrategy(
                        string symbol,
                        int magicNumber,
                        ENUM_TIMEFRAMES timeframe,
                        
                        int maShortPeriod,
                        ENUM_MA_METHOD maShortMode,
                        
                        int maMediumPeriod,
                        ENUM_MA_METHOD maMediumMode,
                        
                        int maLongPeriod,
                        ENUM_MA_METHOD maLongMode,
                        
                        int window,
                        double minDistSM,
                        double minDistML,
                        double minDistSL
                     ) : 
                     m_symbol(symbol),
                     m_magicNumber(magicNumber),
                     m_timeframe(timeframe),
                     m_maShortPeriod(maShortPeriod),
                     m_maShortMode(maShortMode),
                     m_maMediumPeriod(maMediumPeriod),
                     m_maMediumMode(maMediumMode),
                     m_maLongPeriod(maLongPeriod),
                     m_maLongMode(maLongMode),
                     m_window(window),
                     m_minDistSM(minDistSM),
                     m_minDistML(minDistML),
                     m_minDistSL(minDistSL)
                     {
                        Init();
                     }
                    ~CPullbackMovingAverageStrategy()
                    {
                        DeInit();
                    }
                    
   double GetStopLossPoints() {return m_stopLossPoints;}
   double GetStopLossPrice() {return m_stopLossPrice;}
   double GetEntryPrice() {return m_entryPrice;}
   bool UpdateData();
   bool IsBuySignal();
   bool IsSellSignal();
   bool Init();
   void DeInit();
   ENUM_ORDER_TYPE GetOrderType() {return m_orderType;}
   
};

//+------------------------------------------------------------------+
//| Initialization method                                            |
//+------------------------------------------------------------------+
bool CPullbackMovingAverageStrategy::Init()
{
   // Create MA handles
   m_maShortHandle = iMA(m_symbol, m_timeframe, m_maShortPeriod, 0, m_maShortMode, PRICE_CLOSE);
   m_maMediumHandle = iMA(m_symbol, m_timeframe, m_maMediumPeriod, 0, m_maMediumMode, PRICE_CLOSE);
   m_maLongHandle = iMA(m_symbol, m_timeframe, m_maLongPeriod, 0, m_maLongMode, PRICE_CLOSE);
   
   if(m_maShortHandle == INVALID_HANDLE || m_maMediumHandle == INVALID_HANDLE || m_maLongHandle == INVALID_HANDLE)
   {
      Print("Failed to create MA handles");
      return false;
   }
   
   ArraySetAsSeries(m_maShortBuffer, true);
   ArraySetAsSeries(m_maMediumBuffer, true);
   ArraySetAsSeries(m_maLongBuffer, true);
  
   return true;
}

//+------------------------------------------------------------------+
//| Deinitialization method                                          |
//+------------------------------------------------------------------+
void CPullbackMovingAverageStrategy::DeInit()
{
   if(m_maShortHandle != INVALID_HANDLE)
      IndicatorRelease(m_maShortHandle);
   if(m_maMediumHandle != INVALID_HANDLE)
      IndicatorRelease(m_maMediumHandle);
   if(m_maLongHandle != INVALID_HANDLE)
      IndicatorRelease(m_maLongHandle);
}

//+------------------------------------------------------------------+
//| Update data method                                               |
//+------------------------------------------------------------------+
bool CPullbackMovingAverageStrategy::UpdateData()
{
   // Copy MA values
   if((CopyBuffer(m_maShortHandle, 0, 1, m_window + 1, m_maShortBuffer) <= 0) ||
      (CopyBuffer(m_maMediumHandle, 0, 1, m_window + 1, m_maMediumBuffer) <= 0) ||
      (CopyBuffer(m_maLongHandle, 0, 1, m_window + 1, m_maLongBuffer) <= 0)){
      Print("Erro ao carregar as MM da estratégia Pullback");
      return false;
   }
   
   m_maShortValue = m_maShortBuffer[0];
   m_maMediumValue = m_maMediumBuffer[0];
   m_maLongValue = m_maLongBuffer[0];
   
   return CheckTrendConditions();
}

//+------------------------------------------------------------------+
//| Check trend conditions                                           |
//+------------------------------------------------------------------+
bool CPullbackMovingAverageStrategy::CheckTrendConditions()
{
   // Verify spacing between MAs to ensure clear trend
   if(MathAbs(m_maShortValue - m_maMediumValue) < (m_maMediumValue * m_minDistSM/100) ||
      MathAbs(m_maMediumValue - m_maLongValue) < (m_maLongValue * m_minDistML/100) ||
      MathAbs(m_maShortValue - m_maLongValue) < (m_maLongValue * m_minDistSL/100))
   {
      return false;
   }
   
   m_isUpTrend = m_maShortValue > m_maMediumValue && m_maMediumValue > m_maLongValue;
   m_isDownTrend = m_maShortValue < m_maMediumValue && m_maMediumValue < m_maLongValue;
   Print(m_isUpTrend, " - ", m_isDownTrend);
   return (m_isUpTrend || m_isDownTrend);
}

//+------------------------------------------------------------------+
//| Check pullback conditions                                        |
//+------------------------------------------------------------------+
bool CPullbackMovingAverageStrategy::CheckPullbackConditions(bool isUpTrend)
{
   const double tolerance = 0.001; // 0.1% de margem de tolerância (ajustável conforme necessário)

   if(isUpTrend)
   {
      bool closeBelowShortMA = false;
      bool closeBelowLongMA = false;
      bool allAboveLongMA = true;

      // Verifica cada candle na janela de análise
      for(int i = m_window; i >= 1; i--) 
      {
         double closePrice = iClose(m_symbol, m_timeframe, i);

         if(closePrice < m_maShortBuffer[i]) 
            closeBelowShortMA = true;
         
         // Verificação simplificada com tolerância (sugestão aprimorada)
         if(closePrice <= m_maLongBuffer[i] * (1 + tolerance)) 
         {
            closeBelowLongMA = true;
            allAboveLongMA = false;
         }
      }

      // Condição de entrada (pullback válido + rompimento)
      if(closeBelowShortMA && !closeBelowLongMA && allAboveLongMA)
      {
         if(iClose(m_symbol, m_timeframe, 1) > m_maShortBuffer[1])
         {
            m_entryPrice = iHigh(m_symbol, m_timeframe, 1);
            m_stopLossPrice = iLow(m_symbol, m_timeframe, 1);
            m_stopLossPoints = MathAbs(m_entryPrice - m_stopLossPrice);
            m_orderType = ORDER_TYPE_BUY_STOP;
            return true;
         }
      }
   }
   else // Downtrend
   {
      bool closeAboveShortMA = false;
      bool closeAboveLongMA = false;
      bool allBelowLongMA = true;

      for(int i = m_window; i >= 1; i--) 
      {
         double closePrice = iClose(m_symbol, m_timeframe, i);

         if(closePrice > m_maShortBuffer[i]) 
            closeAboveShortMA = true;
         
         // Verificação simplificada com tolerância (sugestão do usuário)
         if(closePrice >= m_maLongBuffer[i] * (1 - tolerance)) 
         {
            closeAboveLongMA = true;
            allBelowLongMA = false;
         }
      }

      // Condição de entrada (pullback válido + rompimento)
      if(closeAboveShortMA && !closeAboveLongMA && allBelowLongMA)
      {
         if(iClose(m_symbol, m_timeframe, 1) < m_maShortBuffer[1])
         {
            m_entryPrice = iLow(m_symbol, m_timeframe, 1);
            m_stopLossPrice = iHigh(m_symbol, m_timeframe, 1);
            m_stopLossPoints = MathAbs(m_stopLossPrice - m_entryPrice);
            m_orderType = ORDER_TYPE_SELL_STOP;
            return true;
         }
      }
   }
   
   return false; // Sem sinal válido
}


//+------------------------------------------------------------------+
//| Check for buy signal                                             |
//+------------------------------------------------------------------+
bool CPullbackMovingAverageStrategy::IsBuySignal()
{
   //Print(m_isUpTrend, " - ", CheckPullbackConditions(true));
   return (m_isUpTrend && CheckPullbackConditions(true));
}

//+------------------------------------------------------------------+
//| Check for sell signal                                            |
//+------------------------------------------------------------------+
bool CPullbackMovingAverageStrategy::IsSellSignal()
{
//Print(m_isDownTrend, " - ", CheckPullbackConditions(false));
   return (m_isDownTrend && CheckPullbackConditions(false));
}
