//+------------------------------------------------------------------+
//|                                                  CDTStrategy.mqh |
//|                                                    Danne Pereira |
//|                                             https://www.aipi.com |
//+------------------------------------------------------------------+
#property copyright "Danne Pereira"
#property link      "https://www.aipi.com"
#property version   "1.00"

#include "../../libs/CandlePatterns.mqh"

//+------------------------------------------------------------------+
//| CDTStrategy - Estratégia baseada no DT Oscillator                |
//+------------------------------------------------------------------+
class CDTStrategy
{
private:
    // Configurações da estratégia
    ENUM_TIMEFRAMES   m_timeframe;
    int               m_rsiPeriod;
    int               m_stochPeriod;
    int               m_slowingPeriod;
    int               m_signalPeriod;
    double            m_disDT;
    string            m_symbol;
    
    int               m_maShortPeriod;
    int               m_maLongPeriod;
    int               m_maShortHandler;
    int               m_maLongHandler;
    
    // Dados do indicador
    struct DT_DATA {
        double dtosc;
        double dtoss;
    };
    
    struct RSI_DATA {
        double chgAvg;
        double totChg;
        double lastPrice;
    };
    
    DT_DATA           m_currentDT, m_previousDT;
    RSI_DATA          m_rsiData;
    double            m_stochBuffer[];
    double            m_dtoscBuffer[];
    double            m_dtossBuffer[];
    double            m_lastClose;
    
    double            m_emaShort;
    double            m_emaLong;
    double            m_maDist;
    
    double CalculateRSI(double price);
    double CalculateStochasticRSI(double rsiValue);
    void CalculateDTOscillator(double &dtosc, double &dtoss, double stochValue);
    
public:
    //--- Construtor ---//
    CDTStrategy(string symbol, ENUM_TIMEFRAMES timeframe, int rsiPeriod, int stochPeriod, int slowingPeriod, int signalPeriod, double disDT, int maShortPeriod, int maLongPeriod, double maDist);
    ~CDTStrategy();
    
    //--- Métodos públicos ---//
    bool UpdateData();
    bool IsBuySignal() const;
    bool IsSellSignal() const;
    
    //--- Getters ---//
    double GetDTOSC() const { return m_currentDT.dtosc; }
    double GetDTOSS() const { return m_currentDT.dtoss; }
    double GetLastClose() { return m_lastClose; }
    double GetRSIValue() { return CalculateRSI(m_lastClose); }
    double GetStochRSI() { return CalculateStochasticRSI(GetRSIValue()); }
    
    bool Init();
    void Deinit();
};

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
CDTStrategy::CDTStrategy(string symbol, ENUM_TIMEFRAMES timeframe, int rsiPeriod, int stochPeriod, 
                        int slowingPeriod, int signalPeriod, double disDT, int maShortPeriod, int maLongPeriod, double maDist) :
    m_symbol(symbol),
    m_timeframe(timeframe),
    m_rsiPeriod(rsiPeriod),
    m_stochPeriod(stochPeriod),
    m_slowingPeriod(slowingPeriod),
    m_signalPeriod(signalPeriod),
    m_disDT(disDT),
    m_maShortPeriod(maShortPeriod),
    m_maLongPeriod(maLongPeriod),
    m_lastClose(0),
    m_maDist(maDist)
{
    ArrayResize(m_stochBuffer, m_stochPeriod);
    ArrayResize(m_dtoscBuffer, m_slowingPeriod);
    ArrayResize(m_dtossBuffer, m_signalPeriod);
    
    ArrayInitialize(m_stochBuffer, 0);
    ArrayInitialize(m_dtoscBuffer, 0);
    ArrayInitialize(m_dtossBuffer, 0);
    
    ZeroMemory(m_rsiData);
    ZeroMemory(m_currentDT);
    ZeroMemory(m_previousDT);
    
    Init();
}

CDTStrategy::~CDTStrategy()
{
    Deinit();
}

bool CDTStrategy::Init(void)
{
    m_maShortHandler = iMA(m_symbol, m_timeframe, m_maShortPeriod, 0, MODE_EMA, PRICE_CLOSE);
    m_maLongHandler = iMA(m_symbol, m_timeframe, m_maLongPeriod, 0, MODE_EMA, PRICE_CLOSE);
    if(m_maShortHandler == INVALID_HANDLE || m_maLongHandler == INVALID_HANDLE)
    {
        Print("Failed to create EMA handle");
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Liberação de recursos                                            |
//+------------------------------------------------------------------+
void CDTStrategy::Deinit()
{
    if(m_maShortHandler != INVALID_HANDLE)
    {
        IndicatorRelease(m_maShortHandler);
        m_maShortHandler = INVALID_HANDLE;
    }
    if(m_maLongHandler != INVALID_HANDLE)
    {
        IndicatorRelease(m_maLongHandler);
        m_maLongHandler = INVALID_HANDLE;
    }
}

//+------------------------------------------------------------------+
//| Atualiza os dados da estratégia                                  |
//+------------------------------------------------------------------+
bool CDTStrategy::UpdateData()
{
    double _valueMAShort[], _valueMALong[];
    // Copiar os últimos 3 valores para análise
    if(CopyBuffer(m_maShortHandler, 0, 0, 2, _valueMAShort) != 2 ||
       CopyBuffer(m_maLongHandler, 0, 0, 2, _valueMALong) != 2 )
    {
        Print("Failed to copy EMA indicator buffers");
        return false;
    }
    
    // Armazena o valor anterior
    m_previousDT = m_currentDT;
    
    // Obtém o preço atual
    m_lastClose = iClose(_Symbol, m_timeframe, 1);
    m_emaShort = _valueMAShort[1];
    m_emaLong = _valueMALong[1];
    
    //Print(m_previousDT.dtosc, " - ", m_previousDT.dtoss, " - ",  m_lastClose, " - ",  m_emaShort," - ",  m_emaLong);
    
    // Calcula os novos valores do DT Oscillator
    double rsiValue = CalculateRSI(m_lastClose);
    double stochRsi = CalculateStochasticRSI(rsiValue);
    
    //Print(rsiValue," - ", stochRsi);
    
    CalculateDTOscillator(m_currentDT.dtosc, m_currentDT.dtoss, stochRsi);
    
    return true;
}

//+------------------------------------------------------------------+
//| Verifica sinal de compra                                         |
//+------------------------------------------------------------------+
bool CDTStrategy::IsBuySignal() const
{
    bool upTrend   = m_emaShort > m_emaLong * (1 + m_maDist / 100);
    bool crossUp = m_previousDT.dtosc < m_previousDT.dtoss && 
                  m_currentDT.dtosc > m_currentDT.dtoss && 
                  MathAbs(m_currentDT.dtosc - m_currentDT.dtoss) >= m_disDT;
    
    bool below30 = m_currentDT.dtosc < 30 && m_currentDT.dtoss < 30;
    bool priceAboveEMA = m_lastClose > m_emaShort;
    
    return crossUp && below30 && priceAboveEMA && upTrend && IsBullishSignal(m_timeframe);
}

//+------------------------------------------------------------------+
//| Verifica sinal de venda                                         |
//+------------------------------------------------------------------+
bool CDTStrategy::IsSellSignal() const
{
    bool downTrend = m_emaShort < m_emaLong * (1 - m_maDist / 100);
    bool crossDown = m_previousDT.dtosc > m_previousDT.dtoss && 
                    m_currentDT.dtosc < m_currentDT.dtoss && 
                    MathAbs(m_currentDT.dtosc - m_currentDT.dtoss) >= m_disDT;
    
    bool above70 = m_currentDT.dtosc > 70 && m_currentDT.dtoss > 70;
    bool priceBelowEMA = m_lastClose < m_emaShort;
    
    return crossDown && above70 && priceBelowEMA && downTrend && IsBearishSignal(m_timeframe);
}

double CDTStrategy::CalculateRSI(double price)
{
    if(m_rsiData.lastPrice == 0)
    {
        m_rsiData.lastPrice = price;
        return 50;
    }
    
    double sf = 1.0 / m_rsiPeriod;
    double change = price - m_rsiData.lastPrice;
    
    m_rsiData.chgAvg = m_rsiData.chgAvg + sf * (change - m_rsiData.chgAvg);
    m_rsiData.totChg = m_rsiData.totChg + sf * (MathAbs(change) - m_rsiData.totChg);
    m_rsiData.lastPrice = price;  // Atualiza o último preço
    
    double changeRatio = (m_rsiData.totChg != 0) ? m_rsiData.chgAvg / m_rsiData.totChg : 0;
    return 50.0 * (changeRatio + 1.0);
}

double CDTStrategy::CalculateStochasticRSI(double rsiValue)
{
    // Atualiza o buffer circular
    for(int i = m_stochPeriod-1; i > 0; i--)
        m_stochBuffer[i] = m_stochBuffer[i-1];
    m_stochBuffer[0] = rsiValue;
    
    double min = rsiValue;
    double max = rsiValue;
    for(int i = 0; i < m_stochPeriod; i++)
    {
        min = MathMin(m_stochBuffer[i], min);
        max = MathMax(m_stochBuffer[i], max);
    }
    
    return (max != min) ? 100 * (rsiValue - min) / (max - min) : 0;
}

void CDTStrategy::CalculateDTOscillator(double &dtosc, double &dtoss, double stochValue)
{
    // Atualiza o buffer DTOSC
    for(int i = m_slowingPeriod-1; i > 0; i--)
        m_dtoscBuffer[i] = m_dtoscBuffer[i-1];
    m_dtoscBuffer[0] = stochValue;
    
    double sum = 0;
    for(int i = 0; i < m_slowingPeriod; i++)
        sum += m_dtoscBuffer[i];
    dtosc = sum / m_slowingPeriod;
    
    // Atualiza o buffer DTOSS
    for(int i = m_signalPeriod-1; i > 0; i--)
        m_dtossBuffer[i] = m_dtossBuffer[i-1];
    m_dtossBuffer[0] = dtosc;
    
    sum = 0;
    for(int i = 0; i < m_signalPeriod; i++)
        sum += m_dtossBuffer[i];
    dtoss = sum / m_signalPeriod;
}