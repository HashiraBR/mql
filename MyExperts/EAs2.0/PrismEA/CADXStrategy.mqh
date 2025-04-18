//+------------------------------------------------------------------+
//| CADXStrategy.mqh                                                 |
//| Estratégia ADX pura - apenas geração de sinais                   |
//+------------------------------------------------------------------+

class CADXStrategy
{
private:
    int m_adxHandle;            // Handle do indicador ADX
    double m_adxValues[];       // Valores da linha ADX
    double m_plusDI[];          // Valores da linha +DI
    double m_minusDI[];         // Valores da linha -DI
    
    // Flags para saber se as linhas cruzaram
    bool m_tradeSellFlag;
    bool m_tradeBuyFlag;
    
    ENUM_TIMEFRAMES m_timeframe;
    int m_ma_period;
    string m_symbol;
    
    // Configurações da estratégia
    int m_adxPeriod;           // Período do ADX
    double m_adxStep;          // Passo necessário para entrada
   
    void ResetSignals();
    
public:
    // Construtor/destrutor
    CADXStrategy(int adxPeriod, double adxStep, ENUM_TIMEFRAMES timeframe, string symbol);
    ~CADXStrategy();
    
    // Métodos principais
    bool Init();
    void Deinit();
    bool UpdateData();
    
    // Geração de sinais
    bool IsBuySignal();
    bool IsSellSignal();
};

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
CADXStrategy::CADXStrategy(int adxPeriod, double adxStep, ENUM_TIMEFRAMES timeframe, string symbol) : 
    m_adxHandle(INVALID_HANDLE),
    m_adxPeriod(adxPeriod),
    m_adxStep(adxStep),
    m_tradeSellFlag(false),
    m_tradeBuyFlag(false),
    m_timeframe(timeframe),
    m_symbol(symbol)
{
    ArraySetAsSeries(m_adxValues, true);
    ArraySetAsSeries(m_plusDI, true);
    ArraySetAsSeries(m_minusDI, true);
    
    Init();
}

//+------------------------------------------------------------------+
//| Destrutor                                                        |
//+------------------------------------------------------------------+
CADXStrategy::~CADXStrategy()
{
    Deinit();
}

//+------------------------------------------------------------------+
//| Inicialização do indicador                                       |
//+------------------------------------------------------------------+
bool CADXStrategy::Init()
{
    m_adxHandle = iADX(m_symbol, m_timeframe, m_adxPeriod);
    if(m_adxHandle == INVALID_HANDLE)
    {
        Print("Failed to create ADX handle");
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Liberação de recursos                                            |
//+------------------------------------------------------------------+
void CADXStrategy::Deinit()
{
    if(m_adxHandle != INVALID_HANDLE)
    {
        IndicatorRelease(m_adxHandle);
        m_adxHandle = INVALID_HANDLE;
    }
}

//+------------------------------------------------------------------+
//| Atualização dos dados do indicador                               |
//+------------------------------------------------------------------+
bool CADXStrategy::UpdateData()
{
    // Copiar os últimos 3 valores para análise
    if(CopyBuffer(m_adxHandle, 0, 0, 3, m_adxValues) != 3 ||
       CopyBuffer(m_adxHandle, 1, 0, 3, m_plusDI) != 3 ||
       CopyBuffer(m_adxHandle, 2, 0, 3, m_minusDI) != 3)
    {
        Print("Failed to copy ADX indicator buffers");
        return false;
    }
    
    if(!m_tradeBuyFlag && m_plusDI[2] < m_minusDI[2] && m_plusDI[1] > m_minusDI[1]) m_tradeBuyFlag = true;
    if(!m_tradeSellFlag && m_plusDI[2] > m_minusDI[2] && m_plusDI[1] < m_minusDI[1]) m_tradeSellFlag = true;
    
    return true;
}

//+------------------------------------------------------------------+
//| Verificar sinal de compra                                        |
//+------------------------------------------------------------------+
bool CADXStrategy::IsBuySignal()
{
    bool buySignal = ((m_plusDI[1] > m_adxValues[1]) && 
           (m_adxValues[2] < MathAbs(m_adxValues[1] - m_adxStep)) && 
           (m_plusDI[1] > m_minusDI[1])) && m_tradeBuyFlag;
    
    if(buySignal) ResetSignals();
    
    return buySignal;
}

//+------------------------------------------------------------------+
//| Verificar sinal de venda                                         |
//+------------------------------------------------------------------+
bool CADXStrategy::IsSellSignal()
{
    bool sellSignal = ((m_minusDI[1] > m_adxValues[1]) && 
           (m_adxValues[2] < MathAbs(m_adxValues[1] - m_adxStep)) && 
           (m_minusDI[1] > m_plusDI[1])) && m_tradeSellFlag;
           
    if(sellSignal) ResetSignals();
    
    return sellSignal;
}

//+------------------------------------------------------------------+
//| Resetar os sinais                                                |
//+------------------------------------------------------------------+
void CADXStrategy::ResetSignals()
{
    m_tradeBuyFlag = false;
    m_tradeSellFlag = false;
}