//+------------------------------------------------------------------+
//|                                              CCandleStrategy.mqh |
//|                                                    Danne Pereira |
//|                                             https://www.aipi.com |
//+------------------------------------------------------------------+
#property copyright "Danne Pereira"
#property link      "https://www.aipi.com"
#property version   "1.00"
#include "CandlePatterns.mqh"
#include "../../libs/CUtils.mqh"
#include "../../libs/CPrintManager.mqh"
#include "../../libs/structs/TradeSignal.mqh"

class CCandleStrategy
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   PatternConfig     m_patternConfigs[9];
   int               m_volumeAVGPeriod;
   
   CPrintManager print;
   CandlePattern     IdentifyCurrentCandle(double atrPoints);

public:
                     CCandleStrategy(string symbol, ENUM_TIMEFRAMES timeframe, int volumeAVGPeriod,  PatternConfig &patterns[]);
                    ~CCandleStrategy();
   
   TradeSignal      CheckForSignal(ENUM_TREND_DIRECTION trend, double maLongValue, double atrPoints);
};

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
CCandleStrategy::CCandleStrategy(string symbol, ENUM_TIMEFRAMES timeframe, int volumeAVGPeriod, PatternConfig &patterns[]) :
   m_symbol(symbol),
   m_timeframe(timeframe),
   m_volumeAVGPeriod(volumeAVGPeriod)
{
   for(int i = 0; i < 9; i++) {
      m_patternConfigs[i] = patterns[i];
   }
}


//+------------------------------------------------------------------+
//| Destrutor                                                        |
//+------------------------------------------------------------------+
CCandleStrategy::~CCandleStrategy()
{
}
TradeSignal CCandleStrategy::CheckForSignal(ENUM_TREND_DIRECTION trend, double maLongValue, double atrPoints)
{
    TradeSignal signal;
    
    // 1. Filtro de tendência
    double lastClose = iClose(m_symbol, m_timeframe, 1);
    if((trend == TREND_UP && lastClose <= maLongValue) || 
       (trend == TREND_DOWN && lastClose >= maLongValue))
    {
        print.DebugPrint(StringFormat("Filtro de tendência falhou: Close=%.5f, MA=%.5f, Trend=%s", 
            lastClose, 
            maLongValue, 
            (trend == TREND_UP ? "UP" : "DOWN")));
        return signal;
    }
    else 
    {
        print.DebugPrint(StringFormat("Filtro de tendência OK: Close=%.5f %s MA=%.5f", 
            lastClose, 
            (trend == TREND_UP ? ">" : "<"), 
            maLongValue));
    }
    
    // 2. Identificação do padrão
    CandlePattern pattern = IdentifyCurrentCandle(atrPoints);
    if(pattern == PATTERN_NONE)
    {
        print.DebugPrint("Nenhum padrão de candle identificado");
        return signal;
    }
    else if(!m_patternConfigs[pattern].enabled)
    {
        print.DebugPrint(StringFormat("Padrão %s desativado nas configurações", GetCandlePatternName(pattern)));
        return signal;
    }
    else
    {
        if(IsBuyPatternSignal(pattern) && trend != TREND_UP) 
            return signal;
        
        if(IsSellPatternSignal(pattern) && trend != TREND_DOWN)
            return signal;
            
        print.DebugPrint(StringFormat("Padrão válido encontrado: %s", GetCandlePatternName(pattern)));
    }
    
    // 3. Verificação de volume
    bool isVolumeOK = CUtils::IsVolumeAboveAvg(m_volumeAVGPeriod, m_symbol, m_timeframe);
    if(!isVolumeOK)
    {
        print.DebugPrint("Volume atual abaixo da média especificada");
        return signal;
    }
    else
    {
        print.DebugPrint("Volume acima da média - condição atendida");
    }
    
    // 4. Configuração do sinal
    signal.isValid = true;
    signal.direction = trend;
    signal.lotSize = m_patternConfigs[pattern].lotSize;
    signal.stopLoss = m_patternConfigs[pattern].stopLoss;
    signal.takeProfit = m_patternConfigs[pattern].takeProfit;
    signal.comment = StringFormat("%s+%s", 
        (trend == TREND_UP ? "UP" : "DOWN"),
        GetCandlePatternName(pattern));
    signal.patternType = pattern;
    
    print.DebugPrint(StringFormat("Sinal confirmado: %s | TP=%.5f | SL=%.5f | Lote=%.2f", 
        signal.comment, 
        signal.takeProfit, 
        signal.stopLoss, 
        signal.lotSize));
    
    return signal;
}

//+------------------------------------------------------------------+
//| Identifica o padrão do último candle                             |
//+------------------------------------------------------------------+
CandlePattern CCandleStrategy::IdentifyCurrentCandle(double atrPoints)
{
   double open = iOpen(m_symbol, m_timeframe, 1);
   double high = iHigh(m_symbol, m_timeframe, 1);
   double low = iLow(m_symbol, m_timeframe, 1);
   double close = iClose(m_symbol, m_timeframe, 1);
   
   // Verifica todos os padrões habilitados
   for(int i = 1; i < ArraySize(m_patternConfigs); i++) // Começa de 1 para pular PATTERN_NONE
   {
      if(m_patternConfigs[i].enabled)
      {
         CandlePattern pattern = IdentifyPattern(open, high, low, close, m_patternConfigs[i].minRange * atrPoints, m_patternConfigs[i].maxRange * atrPoints);
         if(pattern == i)
            return pattern;
      }
   }
   
   return PATTERN_NONE;
}