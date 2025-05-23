//+------------------------------------------------------------------+
//|                                                 COutsiderBarStrategy.mqh |
//|                                                    Danne Pereira |
//|                                             https://www.aipi.com |
//+------------------------------------------------------------------+
#property copyright "Danne Pereira"
#property link      "https://www.aipi.com"
#property version   "1.00"
class COutsiderBarStrategy
  {
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   double m_bodySizeOutsideBar;
   
   int m_maLongHandle;
   int m_maPeriod;
   double m_maLongValue;
   ENUM_MA_METHOD m_maMethod;
   
   int m_rsiHandle;
   int m_rsiPeriod;
   double m_rsiValue;
   
   double m_lastClose;
   double m_lastOpen;
   double m_lastHigh;
   double m_lastLow;
   double m_secondLastClose;
   double m_secondLastOpen;
   double m_secondLastHigh;
   double m_secondLastLow;
   
   bool m_isOutsideBar;
   double m_body;
   double m_candleVariation;
   bool m_isFullBody;
   
   double m_entryPrice;
   double m_stopLossPrice;
   double m_stopLossPoints;
   ENUM_ORDER_TYPE m_orderType;
   
public:
                     COutsiderBarStrategy(string symbol, ENUM_TIMEFRAMES timeframe, int maPeriod, int rsiPeriod, ENUM_MA_METHOD maMethod);
                    ~COutsiderBarStrategy();
   bool UpdateData();
   bool Init();
   void DeInit();   
   bool IsBuySignal();
   bool IsSellSignal();
   double GetStopLossPoints() {return m_stopLossPoints;}
   double GetStopLossPrice() {return m_stopLossPrice;}
   double GetEntryPrice() {return m_entryPrice;}
   ENUM_ORDER_TYPE GetOrderType() {return m_orderType;}
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
COutsiderBarStrategy::COutsiderBarStrategy(string symbol, ENUM_TIMEFRAMES timeframe, int maPeriod, int rsiPeriod, ENUM_MA_METHOD maMethod):
   m_symbol(symbol),
   m_timeframe(timeframe),
   m_maPeriod(maPeriod),
   m_maMethod(maMethod),
   m_rsiPeriod(rsiPeriod)
  {
      m_entryPrice = -1.0;
      m_stopLossPrice = -1.0;
      m_stopLossPoints = -1.0;
      m_orderType = NULL;
      Init();
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
COutsiderBarStrategy::~COutsiderBarStrategy()
  {
      DeInit();
  }
//+------------------------------------------------------------------+

bool COutsiderBarStrategy::Init(){
   m_maLongHandle = iMA(m_symbol, m_timeframe, m_maPeriod, 0, m_maMethod, PRICE_CLOSE);
   if(m_maLongHandle == INVALID_HANDLE)
   {
        Print("Failed to create MA handle");
        return false;
   }
    
   m_rsiHandle = iRSI(m_symbol, m_timeframe, m_rsiPeriod, PRICE_CLOSE);
   if(m_rsiHandle== INVALID_HANDLE)
   {
        Print("Failed to create RSI handle");
        return false;
   } 
    
    return true;
}

void COutsiderBarStrategy::DeInit()
{
    if(m_maLongHandle != INVALID_HANDLE)
    {
      IndicatorRelease(m_maLongHandle);
      m_maLongHandle = INVALID_HANDLE;  
    }
    if(m_rsiHandle!= INVALID_HANDLE)
    {
      IndicatorRelease(m_rsiHandle);
      m_rsiHandle = INVALID_HANDLE;  
    }
      
}

bool COutsiderBarStrategy::UpdateData()
{
   double maValue[], rsiValue[];
   
   if((CopyBuffer(m_maLongHandle, 0, 1, 1, maValue) != 1) ||
      (CopyBuffer(m_rsiHandle, 0, 1, 1, rsiValue) != 1))
      {
         Print("Falha ao copiar dados dos indicadores da estratégia OutSideBar");
         return false;
      }
      
   m_maLongValue = maValue[0];
   m_rsiValue = rsiValue[0];
   
   m_lastClose = iClose(m_symbol, m_timeframe, 1);
   m_lastOpen = iOpen(m_symbol, m_timeframe, 1);
   m_lastHigh = iHigh(m_symbol, m_timeframe, 1);
   m_lastLow = iLow(m_symbol, m_timeframe, 1);
   
   m_secondLastClose = iClose(m_symbol, m_timeframe, 2);
   m_secondLastOpen = iOpen(m_symbol, m_timeframe, 2);
   m_secondLastHigh = iHigh(m_symbol, m_timeframe, 2);
   m_secondLastLow = iLow(m_symbol, m_timeframe, 2);
   
   m_isOutsideBar = (m_lastHigh > m_secondLastHigh && m_lastLow < m_secondLastLow);
   m_body = MathAbs(m_lastOpen - m_lastClose);
   m_candleVariation = MathAbs(m_lastLow - m_lastHigh);
   m_isFullBody = (m_body >= m_candleVariation * m_bodySizeOutsideBar);
   
   m_entryPrice = -1.0;
   m_stopLossPrice = -1.0;
   m_stopLossPoints = -1.0;
   m_orderType = NULL;
   
   return true;
}

bool COutsiderBarStrategy::IsBuySignal()
{
   if (m_lastClose > m_maLongValue && m_rsiValue > 50 && m_isOutsideBar && m_isFullBody && m_lastClose > m_lastOpen)
   {
      m_entryPrice = m_lastHigh; 
      m_stopLossPrice = m_lastLow;  
      m_stopLossPoints = MathAbs(m_entryPrice - m_stopLossPrice);
      m_orderType = ORDER_TYPE_BUY_STOP;
      return true;
   }
   return false;
}

bool COutsiderBarStrategy::IsSellSignal()
{
   if (m_lastClose < m_maLongValue && m_rsiValue < 50 && m_isOutsideBar && m_isFullBody && m_lastClose < m_lastOpen)
   {
      m_entryPrice = m_lastLow;
      m_stopLossPrice = m_lastHigh;
      m_stopLossPoints = MathAbs(m_entryPrice - m_stopLossPrice);
      m_orderType = ORDER_TYPE_SELL_STOP;
      return true;
   }
   return false;
}