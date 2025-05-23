//+------------------------------------------------------------------+
//|                                              CCandleStrategy.mqh |
//|                        Copyright © 2023, Danne M. G. Pereira     |
//|                              www.aipi.com.br                     |
//+------------------------------------------------------------------+
enum CandlePattern {
    PATTERN_NONE,
    PATTERN_DOJI,
    PATTERN_MARUBOZU_GREEN,
    PATTERN_MARUBOZU_RED,
    PATTERN_SHOOTING_STAR_RED,
    PATTERN_SHOOTING_STAR_GREEN,
    PATTERN_SPINNING_TOP,
    PATTERN_HAMMER_GREEN,
    PATTERN_HAMMER_RED
};

string CandlePatternNames[] = {
    "NONE",
    "DOJI",
    "MARUBOZU_GREEN",
    "MARUBOZU_RED",
    "SHOOTING_STAR_RED",
    "SHOOTING_STAR_GREEN",
    "SPINNING_TOP",
    "HAMMER_GREEN",
    "HAMMER_RED"
};

struct PatternConfig {
    bool enabled;
    int variationHigh;
    double lotSize;
    double stopLoss;
    double takeProfit;
};

class CCandleStrategy {
private:
    string m_symbol;
    ENUM_TIMEFRAMES m_timeframe;
    int m_magicNumber;
    int m_volumePeriod;
    PatternConfig m_patterns[9];
    
    double m_stopLoss;
    double m_takeProfit;
    string m_comment;
    double m_lotSize;
    
    // Métodos auxiliares privados
    bool IsVolumeAboveAverage();
    bool IsBuyPattern(CandlePattern pattern);
    bool IsSellPattern(CandlePattern pattern);
    string GetCandlePatternName(CandlePattern pattern);
    CandlePattern IdentifyPattern(double open, double high, double low, double close, int variationHigh);
    
public:
    CCandleStrategy(string symbol, ENUM_TIMEFRAMES timeframe, int magicNumber, int volumePeriod, PatternConfig &patterns[]);
    
    // Métodos principais para serem chamados no OnTick
    bool IsBuySignal(double maLongValue);
    bool IsSellSignal(double maLongValue);
    
    // Getters para informações do sinal
    double GetLotSize() const;
    double GetStopLoss() const;
    double GetTakeProfit() const;
    string GetComment() const;
};

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
CCandleStrategy::CCandleStrategy(string symbol, ENUM_TIMEFRAMES timeframe, int magicNumber, 
                                int volumePeriod, PatternConfig &patterns[]) :
    m_symbol(symbol),
    m_timeframe(timeframe),
    m_magicNumber(magicNumber),
    m_volumePeriod(volumePeriod)
{
    for(int i = 0; i < 9; i++) {
        m_patterns[i] = patterns[i];
    }
    
    m_stopLoss = -1.0;
    m_takeProfit = -1.0;
    m_comment = "";
    m_lotSize = -1.0;
}

//+------------------------------------------------------------------+
//| Verifica se há sinal de compra                                   |
//+------------------------------------------------------------------+
bool CCandleStrategy::IsBuySignal(double maLongValue)
{
    double lastClose = iClose(m_symbol, m_timeframe, 1);
    if(lastClose <= maLongValue) return false;
    
    double lastOpen = iOpen(m_symbol, m_timeframe, 1);
    double lastHigh = iHigh(m_symbol, m_timeframe, 1);
    double lastLow = iLow(m_symbol, m_timeframe, 1);
    
    if(!IsVolumeAboveAverage()) return false;
    
    for(int i = 0; i < ArraySize(m_patterns); i++) {
        if(m_patterns[i].enabled) {
            CandlePattern pattern = IdentifyPattern(lastOpen, lastHigh, lastLow, lastClose, m_patterns[i].variationHigh);
            if(pattern == i && IsBuyPattern(pattern)) {
                m_stopLoss = m_patterns[i].stopLoss;
                m_takeProfit = m_patterns[i].takeProfit;
                m_comment = "UP+"+GetCandlePatternName(pattern);
                m_lotSize = m_patterns[i].lotSize;
                return true;
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Verifica se há sinal de venda                                    |
//+------------------------------------------------------------------+
bool CCandleStrategy::IsSellSignal(double maLongValue)
{
    double lastClose = iClose(m_symbol, m_timeframe, 1);
    if(lastClose >= maLongValue) return false;
    
    double lastOpen = iOpen(m_symbol, m_timeframe, 1);
    double lastHigh = iHigh(m_symbol, m_timeframe, 1);
    double lastLow = iLow(m_symbol, m_timeframe, 1);
    
    if(!IsVolumeAboveAverage()) return false;
    
    for(int i = 0; i < ArraySize(m_patterns); i++) {
        if(m_patterns[i].enabled) {
            CandlePattern pattern = IdentifyPattern(lastOpen, lastHigh, lastLow, lastClose, m_patterns[i].variationHigh);
            if(pattern == i && IsSellPattern(pattern)) {
                return true;
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Identifica o padrão do candle                                    |
//+------------------------------------------------------------------+
CandlePattern CCandleStrategy::IdentifyPattern(double open, double high, double low, double close, int variationHigh)
{
    double bodySize = MathAbs(close - open);
    double totalRange = high - low;

    // Doji
    if(bodySize <= 1 * _Point && totalRange >= variationHigh * _Point) 
        return PATTERN_DOJI;
    
    // Hammer Verde (Bullish Hammer)
    if((close > open) && (totalRange > (3 * bodySize)) && ((high - close) <= 15 * _Point) && (totalRange >= variationHigh * _Point)) 
        return PATTERN_HAMMER_GREEN;

    // Hammer Vermelho (Bearish Hammer)
    if((close < open) && (totalRange > (8 * bodySize)) && ((high - open) <= 15 * _Point) && (totalRange >= variationHigh * _Point)) 
        return PATTERN_HAMMER_RED;

    // Marubozu
    if((close > open) && (bodySize > (totalRange * 0.8)) && (totalRange >= variationHigh * _Point)) 
        return PATTERN_MARUBOZU_GREEN;
    if((close < open) && (bodySize > (totalRange * 0.8)) && (totalRange >= variationHigh * _Point)) 
        return PATTERN_MARUBOZU_RED;

    // Shooting Star Vermelho (Bearish Shooting Star)
    if((close < open) && (totalRange > (3 * bodySize)) && ((close - low) <= 15 * _Point) && (totalRange >= variationHigh * _Point)) 
        return PATTERN_SHOOTING_STAR_RED;

    // Shooting Star Verde (Bullish Shooting Star)
    if((close > open) && (totalRange > (8 * bodySize)) && ((open - low) <= 15 * _Point) && (totalRange >= variationHigh * _Point)) 
        return PATTERN_SHOOTING_STAR_GREEN;

    // Spinning Top
    if((close > open) && (bodySize * 2 < (open - low)) && (bodySize < (high - close)) && totalRange >= variationHigh * _Point) 
        return PATTERN_SPINNING_TOP;
    if((close < open) && (bodySize * 2 < (close - low)) && (bodySize < (high - open)) && totalRange >= variationHigh * _Point) 
        return PATTERN_SPINNING_TOP;

    return PATTERN_NONE;
}

//+------------------------------------------------------------------+
//| Verifica se o volume está acima da média                         |
//+------------------------------------------------------------------+
bool CCandleStrategy::IsVolumeAboveAverage()
{
    if(m_volumePeriod <= 0) return false;
    
    double sumVolumes = 0;
    for(int i = 1; i <= m_volumePeriod; i++) {
        sumVolumes += (double)iVolume(m_symbol, m_timeframe, i + 1);
    }
    
    double averageVolume = sumVolumes / m_volumePeriod;
    double currentVolume = (double)iVolume(m_symbol, m_timeframe, 1);
    
    return currentVolume > averageVolume;
}

//+------------------------------------------------------------------+
//| Verifica se o padrão é de compra                                 |
//+------------------------------------------------------------------+
bool CCandleStrategy::IsBuyPattern(CandlePattern pattern)
{
    return (pattern == PATTERN_MARUBOZU_GREEN || pattern == PATTERN_HAMMER_GREEN || pattern == PATTERN_HAMMER_RED);
}

//+------------------------------------------------------------------+
//| Verifica se o padrão é de venda                                  |
//+------------------------------------------------------------------+
bool CCandleStrategy::IsSellPattern(CandlePattern pattern)
{
    return (pattern == PATTERN_MARUBOZU_RED || pattern == PATTERN_SHOOTING_STAR_RED || pattern == PATTERN_SHOOTING_STAR_GREEN);
}

//+------------------------------------------------------------------+
//| Retorna o nome do padrão                                         |
//+------------------------------------------------------------------+
string CCandleStrategy::GetCandlePatternName(CandlePattern pattern)
{
    int index = (int)pattern;
    if(index >= 0 && index < ArraySize(CandlePatternNames)) {
        return CandlePatternNames[index];
    }
    return "PATTERN_UNKNOWN";
}

//+------------------------------------------------------------------+
//| Getters para informações do trade                                |
//+------------------------------------------------------------------+
double CCandleStrategy::GetLotSize() const
{
    return m_lotSize;
}

double CCandleStrategy::GetStopLoss() const
{
    return m_stopLoss;
}

double CCandleStrategy::GetTakeProfit() const
{
    return m_takeProfit;
}

string CCandleStrategy::GetComment() const
{
    return m_comment;
}