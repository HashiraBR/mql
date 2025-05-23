//+------------------------------------------------------------------+
//|                                  CCongestionStrategy.mqh         |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "2.00" // Versão atualizada

#include "../../libs/CPrintManager.mqh"
#include "../../libs/structs/TradeSignal.mqh"
#include "CandlePatterns.mqh"

class CCongestionStrategy
{
private:
    // Configurações
    string            m_symbol;
    ENUM_TIMEFRAMES   m_timeframe;
    int               m_lookback;
    double            m_extreme_weight;
    int               m_shortPeriod;
    int               m_mediumPeriod;
    int               m_longPeriod;
    double            m_distMaxSM;
    double            m_distMaxML;
    color             m_support_color;
    color             m_resistance_color;
    string            m_prefix;
    CPrintManager     print;
    double            m_lotSize;
    double            m_takeProfit;
    int               m_volumePeriod;
    
    // Níveis e estado
    double            m_current_support;
    double            m_current_resistance;
    int               m_congestionHandle;
    
    double            m_distMinLvls;
    
    // Métodos privados
    bool              UpdateIndicatorData();
    bool              IsValidLevel(double level) const;
    void              DrawLevel(double price, string name, color clr);
    double            GetStopLossPrice(bool isBuy) const;
        
    bool              IsBuySignalCondition();
    bool              IsSellSignalCondition();
    void              SetupSignal(TradeSignal &signal, bool isBuy, double atrValue);

public:
                     CCongestionStrategy(string symbol, ENUM_TIMEFRAMES timeframe, 
                                       int lookback, double extreme_weight,
                                       int shortPeriod, int mediumPeriod,
                                       int longPeriod, double distMaxSM, double distMaxML, 
                                       double lotSize, double takeProfit, double distMinLvls, int volumePeriod,
                                       string prefix = "CCS_", color support_clr = clrRed, color resistance_clr = clrGreen);
                                       
                      ~CCongestionStrategy();
                    
    bool              Init();
    void              DeInit();
    TradeSignal       CheckForSignal(double atrValue);
    
    // Getters
    double            GetSupport() const { return m_current_support; }
    double            GetResistance() const { return m_current_resistance; }
    
    // Métodos visuais
    void              UpdateVisuals();
    void              RemoveVisuals();
    
    double CCongestionStrategy::GetStopLossPoints(bool isBuy) const;
};

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
CCongestionStrategy::CCongestionStrategy(string symbol, ENUM_TIMEFRAMES timeframe, 
                                       int lookback, double extreme_weight,
                                       int shortPeriod, int mediumPeriod,
                                       int longPeriod, double distMaxSM, double distMaxML, 
                                       double lotSize, double takeProfit, double distMinLvls, int volumePeriod,
                                       string prefix = "CCS_", color support_clr = clrRed, color resistance_clr = clrGreen) :
    m_symbol(symbol),
    m_timeframe(timeframe),
    m_lookback(lookback),
    m_extreme_weight(extreme_weight),
    m_shortPeriod(shortPeriod),
    m_mediumPeriod(mediumPeriod),
    m_longPeriod(longPeriod),
    m_distMaxSM(distMaxSM),
    m_distMaxML(distMaxML),
    m_support_color(support_clr),
    m_resistance_color(resistance_clr),
    m_prefix(prefix),
    m_current_support(0.0),
    m_current_resistance(0.0),
    m_volumePeriod(volumePeriod),
    m_congestionHandle(INVALID_HANDLE),
    m_lotSize(lotSize),
    m_takeProfit(takeProfit),
    m_distMinLvls(distMinLvls)
{
    Init();
    Print("CongestionStrategy inicializado para ", m_symbol);
}

//+------------------------------------------------------------------+
//| Verifica sinal de trading                                        |
//+------------------------------------------------------------------+
TradeSignal CCongestionStrategy::CheckForSignal(double atrValue)
{
    TradeSignal signal;
    
    if(!UpdateIndicatorData())
    {
        print.DebugPrint("Falha ao atualizar dados do indicador");
        return signal;
    }
    
    print.DebugPrint(" === >> INÍCIO - CongestionStrategy: Verificando sinal");
    print.DebugPrint(StringFormat("Suporte: %.5f | Resistência: %.5f", 
                  m_current_support, m_current_resistance));

    // Verifica sinal de compra (rompimento de suporte)
    if(IsBuySignalCondition())
    {
        SetupSignal(signal, true, atrValue);
        print.DebugPrint("SINAL DE COMPRA DETECTADO");
    }
    // Verifica sinal de venda (rompimento de resistência)
    else if(IsSellSignalCondition())
    {
        SetupSignal(signal, false, atrValue);
        print.DebugPrint("SINAL DE VENDA DETECTADO");
    }
    else
    {
        print.DebugPrint("NENHUM SINAL DETECTADO");
    }

    print.DebugPrint(" === >> FIM - CongestionStrategy");
    return signal;
}

void CCongestionStrategy::SetupSignal(TradeSignal &signal, bool isBuy, double atrValue)
{
    signal.isValid = true;
    signal.direction = isBuy ? TREND_UP : TREND_DOWN;
    signal.lotSize = m_lotSize;
    signal.stopLoss = MathMax(GetStopLossPoints(isBuy), atrValue) / atrValue;
    signal.takeProfit = m_takeProfit;
    signal.comment = isBuy ? "Congestion + Supp." : "Congestion + Resist.";
}

//+------------------------------------------------------------------+
//| Atualiza dados do indicador                                      |
//+------------------------------------------------------------------+
bool CCongestionStrategy::UpdateIndicatorData()
{
    if(m_congestionHandle == INVALID_HANDLE) return false;
    
    double support[1], resistance[1];
    
    if(CopyBuffer(m_congestionHandle, 3, 1, 1, support) != 1 ||
       CopyBuffer(m_congestionHandle, 4, 1, 1, resistance) != 1)
    {
        print.ErrorPrint("Falha ao copiar dados do indicador. Erro: " + IntegerToString(GetLastError()));
        return false;
    }
    
    m_current_support = support[0];
    m_current_resistance = resistance[0];
    
    return true;
}

//+------------------------------------------------------------------+
//| Verifica se um nível é válido                                    |
//+------------------------------------------------------------------+
bool CCongestionStrategy::IsValidLevel(double level) const
{
    return (level > 0 && level != EMPTY_VALUE);
}

//+------------------------------------------------------------------+
//| Atualiza objetos visuais                                         |
//+------------------------------------------------------------------+
void CCongestionStrategy::UpdateVisuals()
{
    RemoveVisuals();
    
    if(IsValidLevel(m_current_support))
        DrawLevel(m_current_support, "Support", m_support_color);
    
    if(IsValidLevel(m_current_resistance))
        DrawLevel(m_current_resistance, "Resistance", m_resistance_color);
}

//+------------------------------------------------------------------+
//| Desenha um nível no gráfico                                      |
//+------------------------------------------------------------------+
void CCongestionStrategy::DrawLevel(double price, string name, color clr)
{
    string obj_name = m_prefix + name;
    ObjectCreate(0, obj_name, OBJ_HLINE, 0, 0, price);
    ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, obj_name, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);
    ObjectSetString(0, obj_name, OBJPROP_TEXT, DoubleToString(price, _Digits));
}


bool CCongestionStrategy::Init()
{
    m_congestionHandle = iCustom(
        m_symbol,
        m_timeframe,
        "Congestion\\Congestion.ex5",
        m_shortPeriod,      // Seu primeiro parâmetro input (7)
        m_mediumPeriod,     // Segundo parâmetro (21)
        m_longPeriod,       // Terceiro parâmetro (50)
        m_distMaxSM,        // Quarto parâmetro (0.05)
        m_distMaxML,        // Quinto parâmetro (0.05)
        m_lookback,         // Sexto parâmetro (100)
        m_support_color,    // Sétimo parâmetro (cor)
        m_resistance_color, // Oitavo parâmetro (cor)
        m_extreme_weight    // Nono parâmetro (3.0)
    );
    
    if(m_congestionHandle == INVALID_HANDLE)
    {
        Print("Falha ao carregar o indicador Congestion. Erro: ", GetLastError());
        return false;
    }
    return true;
}

CCongestionStrategy::~CCongestionStrategy()
{
    DeInit();
}

void CCongestionStrategy::DeInit()
{
    if(m_congestionHandle != INVALID_HANDLE)
    {
        IndicatorRelease(m_congestionHandle);
        m_congestionHandle = INVALID_HANDLE;
    }
    RemoveVisuals();
}

double CCongestionStrategy::GetStopLossPoints(bool isBuy) const
{
    double lastClose = iClose(m_symbol, m_timeframe, 1);
    
    if(isBuy)
    {
        // Para compra: SL = Fechamento - Mínimo do candle
        double low = MathMin(iLow(m_symbol, m_timeframe, 1), iLow(m_symbol, m_timeframe, 2));
        return lastClose - low;
    }
    else
    {
        // Para venda: SL = Máximo do candle - Fechamento
        double high = MathMax(iHigh(m_symbol, m_timeframe, 1), iHigh(m_symbol, m_timeframe, 2));
        return high - lastClose;
    }
}

double CCongestionStrategy::GetStopLossPrice(bool isBuy) const
{
    if(isBuy)
    {
        // Para compra, stop loss é o mínimo do último candle
        return MathMin(iLow(m_symbol, m_timeframe, 1), iLow(m_symbol, m_timeframe, 2));
    }
    else
    {
        // Para venda, stop loss é o máximo do último candle
        return MathMax(iHigh(m_symbol, m_timeframe, 1), iHigh(m_symbol, m_timeframe, 2));
    }
}

void CCongestionStrategy::RemoveVisuals()
{
    ObjectDelete(0, m_prefix + "Support");
    ObjectDelete(0, m_prefix + "Resistance");
}

//+------------------------------------------------------------------+
//| Verifica condições para sinal de compra (rompimento de suporte)  |
//+------------------------------------------------------------------+
bool CCongestionStrategy::IsBuySignalCondition()
{
    if(!IsValidLevel(m_current_support)) 
    {
       // print.DebugPrint("Condição COMPRA - FALHA: Nível de suporte inválido");
        return false;
    }
    
    double lastClose = iClose(m_symbol, m_timeframe, 1);
    double lastLow = iLow(m_symbol, m_timeframe, 1);
    double lastHigh = iHigh(m_symbol, m_timeframe, 1);
    double lastOpen = iOpen(m_symbol, m_timeframe, 1);
    double prevOpen = iOpen(m_symbol, m_timeframe, 2);
    double prevLow = iLow(m_symbol, m_timeframe, 2);
    double prevClose = iClose(m_symbol, m_timeframe, 2);

    // Condições individuais
    bool fakeoutA = false;//(lastLow < m_current_support && lastClose > m_current_support);
    bool fakeoutB = (prevLow < m_current_support && prevClose > m_current_support && lastClose > m_current_support);
    //bool isBullishReversal = (lastClose > lastOpen) && (lastClose > (lastHigh + lastLow)/2); // Candle forte
    bool isPriceComingFromCongestion  = (prevOpen > m_current_support);
    bool hasVolumeConfirmation = CUtils::IsVolumeAboveAvg(m_volumePeriod, m_symbol, m_timeframe); // Volume acima da média
    
    CandlePattern pattern = IdentifyPattern(lastOpen, lastHigh, lastLow, lastClose, 0);
    //bool isBuyPattern = IsBuyPatternSignal(pattern);
    bool isBuyPattern = (pattern == PATTERN_HAMMER_GREEN || pattern == PATTERN_HAMMER_RED);
    
    bool isValid = (fakeoutA || fakeoutB) && isBuyPattern && isPriceComingFromCongestion && hasVolumeConfirmation;
   
    // Debug simplificado - versão clean
   print.DebugPrint("=== FAKEOUT COMPRA DEBUG ===");
   print.DebugPrint(StringFormat("Suporte: %f", DoubleToString(m_current_support, _Digits)));
   print.DebugPrint(StringFormat("fakeoutA: %b | fakeoutB: %b", fakeoutA, fakeoutB));
   print.DebugPrint(StringFormat("Bullish: %b", isBuyPattern));
   print.DebugPrint(StringFormat("Origem Congestão: %b", isPriceComingFromCongestion));
   print.DebugPrint(StringFormat("Volume OK: %b", hasVolumeConfirmation));
   print.DebugPrint(StringFormat("SINAL VÁLIDO: %b", isValid));
    
    return isValid;
}

bool CCongestionStrategy::IsSellSignalCondition()
{
    if(!IsValidLevel(m_current_resistance)) 
    {
       // print.DebugPrint("Condição VENDA - FALHA: Nível de resistência inválido");
        return false;
    }
    
    double lastClose = iClose(m_symbol, m_timeframe, 1);
    double lastHigh = iHigh(m_symbol, m_timeframe, 1);
    double lastLow = iLow(m_symbol, m_timeframe, 1);
    double lastOpen = iOpen(m_symbol, m_timeframe, 1);
    double prevHigh = iHigh(m_symbol, m_timeframe, 2);
    double prevOpen = iOpen(m_symbol, m_timeframe, 2);
    double prevClose = iClose(m_symbol, m_timeframe, 2);
    
    // Condições para VENDA (falha de rompimento da resistência)
    bool fakeoutA = false;//(lastHigh > m_current_resistance && lastClose < m_current_resistance);
    bool fakeoutB = (prevHigh > m_current_resistance && prevClose < m_current_resistance && lastClose < m_current_resistance);
    //bool isBearishReversal = (lastClose < lastOpen) && (lastClose < (lastHigh + lastLow)/2); // Candle forte de baixa
    bool isPriceComingFromCongestion = (prevOpen < m_current_resistance);
    bool hasVolumeConfirmation = CUtils::IsVolumeAboveAvg(m_volumePeriod, m_symbol, m_timeframe);
    
    CandlePattern pattern = IdentifyPattern(lastOpen, lastHigh, lastLow, lastClose, 0);
    bool isSellPattern = (pattern == PATTERN_SHOOTING_STAR_RED || pattern == PATTERN_SHOOTING_STAR_GREEN);
    
    bool isValid = (fakeoutA || fakeoutB) && isSellPattern && isPriceComingFromCongestion && hasVolumeConfirmation;
    
    // Debug simplificado (1 parâmetro por chamada)
    print.DebugPrint("=== FAKEOUT VENDA DEBUG ===");
    print.DebugPrint(StringFormat("Resistência: %f", DoubleToString(m_current_resistance, _Digits)));
    print.DebugPrint(StringFormat("fakeoutA: %b | fakeoutB: %b", fakeoutA, fakeoutB));
    print.DebugPrint(StringFormat("Bearish: %b", isSellPattern));
    print.DebugPrint(StringFormat("Origem Congestão: %b", isPriceComingFromCongestion));
    print.DebugPrint(StringFormat("Volume OK: %b", hasVolumeConfirmation));
    print.DebugPrint(StringFormat("SINAL VÁLIDO: %b", isValid));
    
    return isValid;
}