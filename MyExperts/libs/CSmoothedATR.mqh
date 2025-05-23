//+------------------------------------------------------------------+
//|                                                 CSmoothedATR.mqh |
//|                                                    Danne Pereira |
//|                                             https://www.aipi.com |
//+------------------------------------------------------------------+
#property copyright "Danne Pereira"
#property link      "https://www.aipi.com"
#property version   "1.00"
class CSmoothedATR
{
private:
    string m_symbol;
    ENUM_TIMEFRAMES m_timeframe;
    int m_atr_period;
   // int m_smoothing_period;
    int m_atr_handle;
   // int m_smoothed_atr_handle;
    string m_expertName;
    
public:
    // Construtor
    CSmoothedATR(string symbol, ENUM_TIMEFRAMES timeframe, int atr_period, int smoothing_period)
    {
        m_symbol = symbol;
        m_timeframe = timeframe;
        m_atr_period = atr_period;
     //   m_smoothing_period = smoothing_period;
        m_expertName = ChartGetString(0, CHART_EXPERT_NAME);
        m_atr_handle = INVALID_HANDLE;
      //  m_smoothed_atr_handle = INVALID_HANDLE;
        
        //Initialize();
    }
    
    // Destrutor
    ~CSmoothedATR()
    {
        if (m_atr_handle != INVALID_HANDLE)
            IndicatorRelease(m_atr_handle);
     //   if (m_smoothed_atr_handle != INVALID_HANDLE)
         //   IndicatorRelease(m_smoothed_atr_handle);
    }
    
    // Inicialização dos indicadores
    bool Initialize()
    {
        // Criar handle do ATR
        m_atr_handle = iATR(m_symbol, m_timeframe, m_atr_period);
        if (m_atr_handle == INVALID_HANDLE)
        {
            Print(m_expertName + " Falha ao criar handle do ATR");
            return false;
        }
        
        // Criar handle do ATR suavizado (SMMA)
       // m_smoothed_atr_handle = iMA(m_symbol, m_timeframe, m_smoothing_period, 0, MODE_SMMA, m_atr_handle);
       // if (m_smoothed_atr_handle == INVALID_HANDLE)
       // {
         //   Print(m_expertName + " Falha ao criar handle do ATR suavizado");
      //      return false;
      //  }
        
        return true;
    }
    
    // Obter o valor atual do ATR suavizado
    double GetValue()
    {
        //if(m_smoothed_atr_handle == INVALID_HANDLE)
      //  {
      //      Print(m_expertName + " Handle do ATR suavizado inválido");
      //      return -1.0;
     //   }
        
        double atrValue[1];
        int copied = CopyBuffer(m_atr_handle, 0, 0, 1, atrValue);
        
        if(copied <= 0)
        {
            PrintFormat("%s: Falha ao copiar dados do ATR suavizado (Copiados: %d)",
                      m_expertName, copied);
            return -1.0;
        }
        
        if(atrValue[0] <= 0 || atrValue[0] == EMPTY_VALUE)
            return -1.0;
            
        return NormalizeDouble(atrValue[0], _Digits);
    }
    
    // Métodos para obter informações
    string GetSymbol() const { return m_symbol; }
    ENUM_TIMEFRAMES GetTimeframe() const { return m_timeframe; }
    int GetAtrPeriod() const { return m_atr_period; }
    //int GetSmoothingPeriod() const { return m_smoothing_period; }
};