//+------------------------------------------------------------------+
//|                                            CTrendAcceleratorStrategy.mqh |
//|                                                    Danne Pereira |
//|                                             https://www.aipi.com |
//+------------------------------------------------------------------+
#property copyright "Danne Pereira"
#property link      "https://www.aipi.com"
#property version   "1.00"
class CTrendAcceleratorStrategy
  {
private:
   string m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   
   int m_atrHandle;
   int m_atrPeriod;
   int m_maVariationHandle;
   int m_maVariationPeriod;
   ENUM_MA_METHOD m_maVarationMethod;
   
   int m_maShortHandle;
   int m_maShortPeriod;
   ENUM_MA_METHOD m_maShortMethod;
   
   int m_maLongHandle;
   int m_maLongPeriod;
   ENUM_MA_METHOD m_maLongMethod;
   
   double m_minDist;
 
   
   double m_stopLossPoints;
   double m_stopLossPrice;
   double m_entryPrice;
   ENUM_ORDER_TYPE m_orderType;
   
   double m_maShortValue;
   double m_maShortBeforeValue;
   double m_maLongValue;
   double m_maVariationValue;
   
   void ResetVariables();
      
public:
                     CTrendAcceleratorStrategy(string symbol,
      ENUM_TIMEFRAMES timeframe,
      int atrPeriod,
      int maVariationPeriod,
      ENUM_MA_METHOD maVarationMethod,
      int maShortPeriod,
      ENUM_MA_METHOD maMediumMethod,
      int maLongPeriod,
      ENUM_MA_METHOD maLongMethod, 
      double minDist);
                    ~CTrendAcceleratorStrategy();
   bool UpdateData();
   double GetStopLossPoints() {return m_stopLossPoints;}
   double GetStopLossPrice() {return m_stopLossPrice;}
   bool IsBuySignal();
   bool IsSellSignal();
   double GetEntryPrice() {return m_entryPrice;}
   ENUM_ORDER_TYPE GetOrderType() {return m_orderType;}
   
   bool Init();
   bool DeInit();
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CTrendAcceleratorStrategy::CTrendAcceleratorStrategy(
      string symbol,
      ENUM_TIMEFRAMES timeframe,
      int atrPeriod,
      int maVariationPeriod,
      ENUM_MA_METHOD maVarationMethod,
      int maShortPeriod,
      ENUM_MA_METHOD maShortMethod,
      int maLongPeriod,
      ENUM_MA_METHOD maLongMethod,
      double minDist
   ) : m_symbol(symbol),
       m_timeframe(timeframe),
       m_atrPeriod(atrPeriod),
       m_maVariationPeriod(maVariationPeriod),
       m_maVarationMethod(maVarationMethod),
       m_maShortPeriod(maShortPeriod),
       m_maShortMethod(maShortMethod),
       m_maLongPeriod(maLongPeriod),
       m_maLongMethod(maLongMethod),
       m_minDist(minDist)
   {
      ResetVariables();
      Init();
   }
      
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
CTrendAcceleratorStrategy::~CTrendAcceleratorStrategy()
  {
   DeInit();
  }
//+------------------------------------------------------------------+


bool CTrendAcceleratorStrategy::Init(void){
   // Inicializar os handles dos indicadores
   m_atrHandle = iATR(m_symbol, m_timeframe, m_atrPeriod);
   m_maVariationHandle = iMA(m_symbol, m_timeframe, m_maVariationPeriod, 0, m_maVarationMethod, m_atrHandle);
   m_maShortHandle = iMA(m_symbol, m_timeframe, m_maShortPeriod, 0, m_maShortMethod, PRICE_CLOSE);
   m_maLongHandle = iMA(m_symbol, m_timeframe, m_maLongPeriod, 0, m_maLongMethod, PRICE_CLOSE);
   
   if((m_atrHandle == INVALID_HANDLE) || (m_maVariationHandle == INVALID_HANDLE) || 
   (m_maShortHandle == INVALID_HANDLE) || (m_maLongHandle == INVALID_HANDLE))
   {
      Print("Falha ao criar os handles dos indicadores");
      return false;
   } 
   
   ResetVariables();
      
   return true;
}

void CTrendAcceleratorStrategy::ResetVariables(){
   m_stopLossPoints = -1.0;
   m_entryPrice = -1.0;
   m_orderType = NULL;
}

bool CTrendAcceleratorStrategy::DeInit(void){
   if(m_atrHandle!= INVALID_HANDLE)
    {
      IndicatorRelease(m_atrHandle);
      m_atrHandle = INVALID_HANDLE;  
    }
    if(m_maVariationHandle!= INVALID_HANDLE)
    {
      IndicatorRelease(m_maVariationHandle);
      m_maVariationHandle = INVALID_HANDLE;  
    }if(m_maShortHandle!= INVALID_HANDLE)
    {
      IndicatorRelease(m_maShortHandle);
      m_maShortHandle = INVALID_HANDLE;  
    }
    if(m_maLongHandle!= INVALID_HANDLE)
    {
      IndicatorRelease(m_maLongHandle);
      m_maLongHandle = INVALID_HANDLE;  
    }
    return true;
}

bool CTrendAcceleratorStrategy::UpdateData(void){
   ResetVariables();
   
   double maShortBuffer[], maLongBuffer[], maVariationBuffer[];
   ArraySetAsSeries(maShortBuffer, true);
   
   if (CopyBuffer(m_maShortHandle, 0, 1, 2, maShortBuffer) <= 0 || // Copia 2 valores (índices 1 e 2)
            CopyBuffer(m_maLongHandle, 0, 1, 1, maLongBuffer) <= 0 ||   // Copia 1 valor (índice 1)
            CopyBuffer(m_maVariationHandle, 0, 1, 1, maVariationBuffer) <= 0) // Copia 1 valor (índice 1)
        {
            Print("Erro ao copiar os buffers dos indicadores da Estratégia Forte Aceleração.");
            return false;
        }
   
    m_maShortValue       = maShortBuffer[0];
    m_maShortBeforeValue = maShortBuffer[1]; 
    m_maLongValue        = maLongBuffer[0];     
    m_maVariationValue   = maVariationBuffer[0];
        
   return true;
}

bool CTrendAcceleratorStrategy::IsBuySignal(void){
   if (m_maShortValue > m_maLongValue && m_maShortValue > m_maShortBeforeValue * (1 + m_minDist / 100))
   {
      double lastLow = iLow(m_symbol, m_timeframe, 1); 
      double secondLastLow = iLow(m_symbol, m_timeframe, 2); 
      if (lastLow > m_maShortValue)
      {
         m_entryPrice = MathMin(lastLow, secondLastLow);
         m_stopLossPoints = m_maVariationValue;
         m_stopLossPrice = m_entryPrice - m_maVariationValue;
         m_orderType = ORDER_TYPE_BUY_LIMIT;
         return true;
      }
   }
   return false;
}

bool CTrendAcceleratorStrategy::IsSellSignal(void){
   if (m_maShortValue < m_maLongValue && m_maShortValue < m_maShortBeforeValue * (1 - m_minDist / 100))
   {
      double lastHigh = iHigh(m_symbol, m_timeframe, 1);
      double secondLastHigh = iHigh(m_symbol, m_timeframe, 2); 
      
      if (lastHigh < m_maShortValue)
      {
         m_entryPrice = MathMax(lastHigh, secondLastHigh);
         m_stopLossPoints = m_maVariationValue;
         m_stopLossPrice = m_entryPrice + m_maVariationValue;
         m_orderType = ORDER_TYPE_SELL_LIMIT;
         return true;
      }
   }
   return false;
}