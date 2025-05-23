//+------------------------------------------------------------------+
//|                                              CandlesTrendMaster.mq5   |
//|                        Copyright © 2023, Danne M. G. Pereira     |
//|                              Email: makleyston@gmail.com         |
//|                              Site: www.aipi.com.br               |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2023, Danne M. G. Pereira"
#property link      "www.aipi.com.br"
#property version   "1.0"
#property description "CandlesTrendMaster - Expert Advisor baseado em padrões de candles, médias móveis e tendências."
#property description " "
#property description "Funcionalidades:"
#property description "- Identifica padrões de candles como Marubozu, Doji, Estrela Cadente e Martelo."
#property description "- Opera com base em médias móveis e distâncias mínimas entre elas."
#property description "- Identifica e opera a favor de tendências."
#property description "- Gerenciamento de risco com Stop Loss e Take Profit."
#property description "- Horário de negociação configurável."
#property description "- Envio de e-mails para notificações."
#property description " "
#property description "Recomendações:"
#property description "- Use, preferencialmente, no timeframe de M2."
#property icon "\\Images\\CandlesMaster.ico" // Ícone personalizado (opcional)
#property script_show_inputs

#include "../libs/old/DefaultFunctions.mqh"
#include "../libs/old/DefaultInputs.mqh"


enum Strategy {
   TREND,
   CANDLE
};

enum CandlePattern {
    PATTERN_NONE,
    PATTERN_DOJI,
    PATTERN_MARUBOZU_GREEN,
    PATTERN_MARUBOZU_RED,
    PATTERN_SHOOTING_STAR_RED,
    PATTERN_SHOOTING_STAR_GREEN,
    PATTERN_SPINNING_TOP,
    PATTERN_HAMMER_GREEN,
    PATTERN_HAMMER_RED,
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

// Estrutura para configurar cada padrão de candle
struct PatternConfig {
    bool enabled;               // Se o padrão está habilitado
    int variationHigh;          // Variação mínima do candle (pontos)
    double lotSize;             // Tamanho do lote
    double stopLoss;            // Stop loss em pontos
    double takeProfit;          // Take profit em pontos
};


input string space0111_ = "==========================================================================="; // ############ Configurações de detecção de tendência ############

// Configurações de Médias Móveis
input ENUM_MA_METHOD InpMAMethod = MODE_SMA;   // Tipo de Média Móvel
input int      InpMAShortPeriod = 9;           // Período da Média Móvel Curta
input int      InpMAMediumPeriod = 17;         // Período da Média Móvel Média
input int      InpMALongPeriod = 100;          // Período da Média Móvel Longa

// Distâncias Mínimas entre Médias Móveis (em porcentagem)
input double   InpMinDistanceShortMedium = 0.06; // Distância mínima entre curta e média (%)
input double   InpMinDistanceMediumLong = 0.06;  // Distância mínima entre média e longa (%)
input double   InpMinDistanceShortLong = 0.06;   // Distância mínima entre curta e longa (%)

input string space0 = "==========================================================================="; // ############ Estratégia de Tendência ############
input bool     InpUseTrendStrategy = true;     // Usar estratégia de tendências
//input int      InpMagicNumberTrend = 1002;     // Número mágico para estratégia de tendências
input int      InpPeriodTrend = 2;              // Qt candles para cálculo de média de vol.
input double   InpCandleLongPercent = 5.0;      // Estratégia de Tendência: Variação dos tamanhos dos candles em %
input double   InpLotSizeTrend = 1.0;           // Tamanho do lote para as operações
input double   InpStopLossTrend = 100;          // Stop Loss
input double   InpTakeProfitTrend = 200;        // Take Profit

input string space1 = "==========================================================================="; // ############ Estratégia de Padrões de Candle ############
input bool     InpUseCandleStrategy = true;     // Usar estratégia de padrões de candles
//input int      InpMagicNumberCandle = 1001;    // Número mágico para estratégia de candles
input int      InpPeriodCandle = 2;              // Qt candles para cálculo de média de vol.

input string space10 = "==========================================================================="; // ############ Marubozu GREEN ############
// Configurações do padrão Marubozu Verde
input bool PATTERN_MARUBOZU_GREEN_Enabled = true; // Habilita/desabilita o padrão Marubozu Verde
input int PATTERN_MARUBOZU_GREEN_VariationHigh = 150; // Variação mínima do candle (em pontos) 
input double PATTERN_MARUBOZU_GREEN_LotSize = 1.0; // Tamanho do lote para operações 
input double PATTERN_MARUBOZU_GREEN_StopLoss = 50; // Stop Loss em pontos
input double PATTERN_MARUBOZU_GREEN_TakeProfit = 100; // Take Profit em pontos

input string space2 = "==========================================================================="; // ############ Marubozu RED ############
// Configurações do padrão Marubozu Vermelho
input bool PATTERN_MARUBOZU_RED_Enabled = true; // Habilita/desabilita o padrão Marubozu Vermelho
input int PATTERN_MARUBOZU_RED_VariationHigh = 150; // Variação mínima do candle (em pontos) 
input double PATTERN_MARUBOZU_RED_LotSize = 1.0; // Tamanho do lote para operações
input double PATTERN_MARUBOZU_RED_StopLoss = 50; // Stop Loss em pontos para operações
input double PATTERN_MARUBOZU_RED_TakeProfit = 100; // Take Profit em pontos

input string space3 = "==========================================================================="; // ############ Estrela Cadente RED ############
// Configurações do padrão Estrela Cadente RED (Shooting Star RED)
input bool PATTERN_SHOOTING_STAR_RED_Enabled = true; // Habilita/desabilita o padrão Estrela Cadente Red
input int PATTERN_SHOOTING_STAR_RED_VariationHigh = 150; // Variação mínima do candle (em pontos)
input double PATTERN_SHOOTING_STAR_RED_LotSize = 1.0; // Tamanho do lote para operações 
input double PATTERN_SHOOTING_STAR_RED_StopLoss = 50; // Stop Loss em pontos
input double PATTERN_SHOOTING_STAR_RED_TakeProfit = 100; // Take Profit em pontos

input string space4 = "==========================================================================="; // ############ Estrela Cadente GREEN ############
// Configurações do padrão Estrela Cadente GREEN (Shooting Star GREEN)
input bool PATTERN_SHOOTING_STAR_GREEN_Enabled = true; // Habilita/desabilita o padrão Estrela Cadente Green
input int PATTERN_SHOOTING_STAR_GREEN_VariationHigh = 150; // Variação mínima do candle (em pontos)
input double PATTERN_SHOOTING_STAR_GREEN_LotSize = 1.0; // Tamanho do lote para operações 
input double PATTERN_SHOOTING_STAR_GREEN_StopLoss = 50; // Stop Loss em pontos
input double PATTERN_SHOOTING_STAR_GREEN_TakeProfit = 100; // Take Profit em pontos

input string space5 = "==========================================================================="; // ############ Martelo GREEN ############
// Configurações do padrão Martelo (Hammer)
input bool PATTERN_HAMMER_GREEN_Enabled = true; // Habilita/desabilita o padrão Martelo Green
input int PATTERN_HAMMER_GREEN_VariationHigh = 150; // Variação mínima do candle (em pontos) 
input double PATTERN_HAMMER_GREEN_LotSize = 1.0; // Tamanho do lote para operações 
input double PATTERN_HAMMER_GREEN_StopLoss = 50; // Stop Loss em pontos 
input double PATTERN_HAMMER_GREEN_TakeProfit = 100; // Take Profit em pontos 

input string space6 = "==========================================================================="; // ############ Martelo RED ############
input bool PATTERN_HAMMER_RED_Enabled = true; // Habilita/desabilita o padrão Martelo Red
input int PATTERN_HAMMER_RED_VariationHigh = 150; // Variação mínima do candle (em pontos) 
input double PATTERN_HAMMER_RED_LotSize = 1.0; // Tamanho do lote para operações 
input double PATTERN_HAMMER_RED_StopLoss = 50; // Stop Loss em pontos 
input double PATTERN_HAMMER_RED_TakeProfit = 100; // Take Profit em pontos 

// Array para armazenar as configurações de cada padrão
PatternConfig patternConfigs[9];

//int magicNumberArray[2];
double stopLossArray[2];
double takeProfitArray[2];

bool isProximityWarningPrinted = false;
bool isDistanceInfoPrinted = false;
int shortMAHandle, mediumMAHandle, longMAHandle;
double minDistanceShortLong, minDistanceMediumLong, minDistanceShortMedium;
double shortMABuffer[], mediumMABuffer[], longMABuffer[];


int OnInit() {
    // Inicializa as configurações dos padrões
    patternConfigs[PATTERN_MARUBOZU_GREEN].enabled = PATTERN_MARUBOZU_GREEN_Enabled;
    patternConfigs[PATTERN_MARUBOZU_GREEN].variationHigh = PATTERN_MARUBOZU_GREEN_VariationHigh;
    patternConfigs[PATTERN_MARUBOZU_GREEN].lotSize = PATTERN_MARUBOZU_GREEN_LotSize;
    patternConfigs[PATTERN_MARUBOZU_GREEN].stopLoss = PATTERN_MARUBOZU_GREEN_StopLoss;
    patternConfigs[PATTERN_MARUBOZU_GREEN].takeProfit = PATTERN_MARUBOZU_GREEN_TakeProfit;

    patternConfigs[PATTERN_MARUBOZU_RED].enabled = PATTERN_MARUBOZU_RED_Enabled;
    patternConfigs[PATTERN_MARUBOZU_RED].variationHigh = PATTERN_MARUBOZU_RED_VariationHigh;
    patternConfigs[PATTERN_MARUBOZU_RED].lotSize = PATTERN_MARUBOZU_RED_LotSize;
    patternConfigs[PATTERN_MARUBOZU_RED].stopLoss = PATTERN_MARUBOZU_RED_StopLoss;
    patternConfigs[PATTERN_MARUBOZU_RED].takeProfit = PATTERN_MARUBOZU_RED_TakeProfit;

    patternConfigs[PATTERN_SHOOTING_STAR_RED].enabled = PATTERN_SHOOTING_STAR_RED_Enabled;
    patternConfigs[PATTERN_SHOOTING_STAR_RED].variationHigh = PATTERN_SHOOTING_STAR_RED_VariationHigh;
    patternConfigs[PATTERN_SHOOTING_STAR_RED].lotSize = PATTERN_SHOOTING_STAR_RED_LotSize;
    patternConfigs[PATTERN_SHOOTING_STAR_RED].stopLoss = PATTERN_SHOOTING_STAR_RED_StopLoss;
    patternConfigs[PATTERN_SHOOTING_STAR_RED].takeProfit = PATTERN_SHOOTING_STAR_RED_TakeProfit;
    
    patternConfigs[PATTERN_SHOOTING_STAR_GREEN].enabled = PATTERN_SHOOTING_STAR_GREEN_Enabled;
    patternConfigs[PATTERN_SHOOTING_STAR_GREEN].variationHigh = PATTERN_SHOOTING_STAR_GREEN_VariationHigh;
    patternConfigs[PATTERN_SHOOTING_STAR_GREEN].lotSize = PATTERN_SHOOTING_STAR_GREEN_LotSize;
    patternConfigs[PATTERN_SHOOTING_STAR_GREEN].stopLoss = PATTERN_SHOOTING_STAR_GREEN_StopLoss;
    patternConfigs[PATTERN_SHOOTING_STAR_GREEN].takeProfit = PATTERN_SHOOTING_STAR_GREEN_TakeProfit;

    patternConfigs[PATTERN_HAMMER_GREEN].enabled = PATTERN_HAMMER_GREEN_Enabled;
    patternConfigs[PATTERN_HAMMER_GREEN].variationHigh = PATTERN_HAMMER_GREEN_VariationHigh;
    patternConfigs[PATTERN_HAMMER_GREEN].lotSize = PATTERN_HAMMER_GREEN_LotSize;
    patternConfigs[PATTERN_HAMMER_GREEN].stopLoss = PATTERN_HAMMER_GREEN_StopLoss;
    patternConfigs[PATTERN_HAMMER_GREEN].takeProfit = PATTERN_HAMMER_GREEN_TakeProfit;
    
    patternConfigs[PATTERN_HAMMER_RED].enabled = PATTERN_HAMMER_RED_Enabled;
    patternConfigs[PATTERN_HAMMER_RED].variationHigh = PATTERN_HAMMER_RED_VariationHigh;
    patternConfigs[PATTERN_HAMMER_RED].lotSize = PATTERN_HAMMER_RED_LotSize;
    patternConfigs[PATTERN_HAMMER_RED].stopLoss = PATTERN_HAMMER_RED_StopLoss;
    patternConfigs[PATTERN_HAMMER_RED].takeProfit = PATTERN_HAMMER_RED_TakeProfit;

    // Verifica o número de barras disponíveis
    int availableBars = Bars(Symbol(), InpTimeframe);
    if (availableBars < InpMALongPeriod) {
        Print(expertName + "Erro: Dados insuficientes para calcular médias móveis. Bars disponíveis: ", availableBars);
        return INIT_FAILED;
    }

    // Cria os handles dos indicadores de média móvel
    shortMAHandle = iMA(_Symbol, InpTimeframe, InpMAShortPeriod, 0, InpMAMethod, PRICE_CLOSE);
    mediumMAHandle = iMA(_Symbol, InpTimeframe, InpMAMediumPeriod, 0, InpMAMethod, PRICE_CLOSE);
    longMAHandle = iMA(_Symbol, InpTimeframe, InpMALongPeriod, 0, InpMAMethod, PRICE_CLOSE);

    // Verifica se os handles são válidos
    if (shortMAHandle == INVALID_HANDLE || mediumMAHandle == INVALID_HANDLE || longMAHandle == INVALID_HANDLE) {
        Print(expertName + "Erro: Falha ao criar os indicadores de média móvel.");
        return INIT_FAILED;
    }
    
    // Pré-calcula as distâncias mínimas
    minDistanceShortLong = InpMinDistanceShortLong / 100.0;
    minDistanceMediumLong = InpMinDistanceMediumLong / 100.0;
    minDistanceShortMedium = InpMinDistanceShortMedium / 100.0;

    // Configura os buffers como séries temporais
    ArraySetAsSeries(shortMABuffer, true);
    ArraySetAsSeries(mediumMABuffer, true);
    ArraySetAsSeries(longMABuffer, true);
    
    takeProfitArray[TREND] = InpTakeProfitTrend;
    stopLossArray[TREND] = InpStopLossTrend;

    return INIT_SUCCEEDED;
}

void OnTick() {

    for(int i=0;i<ArraySize(stopLossArray);i++){    
       double sl = stopLossArray[i];

       if(InpSLType == TRAILING) MonitorTrailingStop(InpMagicNumber, sl);
       else if(InpSLType == PROGRESS) ProtectProfitProgressivo(InpMagicNumber, InpProgressSLProtectedPoints, InpProgressSLPercentToProtect);
       else if(InpSLType == OPEN_PRICE_SL) SetStopLossAtOpenPrice(InpMagicNumber, SymbolInfoDouble(_Symbol, SYMBOL_POINT));
    }
    
    if(!BasicFunctions(InpMagicNumber))
      return;
    
    double shortMA, mediumMA, longMA;
    if (!CalculateMovingAverages(shortMA, mediumMA, longMA)) return;
    
    bool isUptrend = (shortMA > mediumMA && mediumMA > longMA);
    bool isDowntrend = (shortMA < mediumMA && mediumMA < longMA);

    // Executa a estratégia de padrões de candles, se habilitada
    if (InpUseCandleStrategy && !HasOpenPosition(InpMagicNumber)) {
        ExecuteCandleStrategy(isUptrend, isDowntrend, longMA);
    }

    // Executa a estratégia de tendências, se habilitada
    if (InpUseTrendStrategy && !HasOpenPosition(InpMagicNumber)) {
        ExecuteTrendStrategy(isUptrend, isDowntrend, shortMA);
    }
}


bool BasicFunctions(int magicNumber = 0){

    ManagePositionsAndOrders(magicNumber, InpOrderExpiration);
        
    // Verifica se é um novo candle
    if (!isNewCandle()) 
        return false;
   
    // Verifica horário de funcionamento e fecha possições
    if (!CheckTradingTime(magicNumber)) 
        return false;
    
    if(!IsSignalFromCurrentDay())
      return false;
    
    // Gerenciamento de risco e perdas
    if(!ManageTradingLimits(magicNumber, InpMaxConsecutiveLosses, InpMaxTrades, InpMaxOpenPositions))
      return false;

    if(DailyLimitReached())
        return false;
        
    if(HasOpenPosition(magicNumber)) 
        return false;
        
    return true;
        
}

void ExecuteCandleStrategy(bool isUptrend, bool isDownTrend, double longMA) {
    
    double lastOpen = iOpen(_Symbol, _Period, 1);
    double lastHigh = iHigh(_Symbol, _Period, 1);
    double lastLow = iLow(_Symbol, _Period, 1);
    double lastClose = iClose(_Symbol, _Period, 1);
    
    //int magicNumber = magicNumberArray[CANDLE];
    
    // 9) Verifica o volume dos candles passados
    bool isVolumeHigh = IsVolumeAboveAverage(InpPeriodCandle);
    
    // Loop sobre todos os padrões habilitados para verificar e operar
    for (int i = 0; i < ArraySize(patternConfigs); i++) {
        if (patternConfigs[i].enabled) {
            // 5.2) Identifique o padrão com a variação específica do padrão
            CandlePattern pattern = IdentifyPattern(lastOpen, lastHigh, lastLow, lastClose, patternConfigs[i].variationHigh);
            stopLossArray[CANDLE] = patternConfigs[i].stopLoss;
            takeProfitArray[CANDLE] = patternConfigs[i].takeProfit;
                    
            // 11) Verifica se deve operar com base no padrão identificado
            if (pattern == i && isVolumeHigh) {
                if (isUptrend && lastClose > longMA && IsBuyPatternSigal(pattern)) {
                        BuyMarketPoint(
                           InpMagicNumber,  
                           patternConfigs[i].lotSize,  
                           patternConfigs[i].stopLoss,  
                           patternConfigs[i].takeProfit,  
                           "UP+" + GetCandlePatternName(pattern)
                        );
                    
                    break;
         } else if (isDownTrend && IsSellPatternSigal(pattern) && lastClose < longMA) {
                        SellMarketPoint(
                           InpMagicNumber,
                           patternConfigs[i].lotSize,  
                           patternConfigs[i].stopLoss,  
                           patternConfigs[i].takeProfit,   
                           "DOWN+" + GetCandlePatternName(pattern)
                        );
                    
                    break;
                }
            }
        }
    }
}

bool IsBuyPatternSigal(CandlePattern pattern)
{
    if(pattern == PATTERN_MARUBOZU_GREEN || pattern == PATTERN_HAMMER_GREEN || pattern == PATTERN_HAMMER_RED)
       return true;
    return false;
}

bool IsSellPatternSigal(CandlePattern pattern)
{
    if(pattern == PATTERN_MARUBOZU_RED || pattern == PATTERN_SHOOTING_STAR_RED || pattern == PATTERN_SHOOTING_STAR_GREEN)
       return true;
    return false;
}

void ExecuteTrendStrategy(bool isUpTrend, bool isDownTrend, double shortMA) {

    double lastCLose = iClose(_Symbol, InpTimeframe, 1);
    bool isCandleLong = IsCandleLong();
    bool isCandleReversalUp = IsCandleReversal(true);
    bool isCandleReversalDown = IsCandleReversal(false);
    bool isVolumeHigh = IsVolumeAboveAverage(InpPeriodTrend); 
    
    if (isUpTrend && lastCLose > shortMA && isCandleLong && isCandleReversalUp && isVolumeHigh)
    {
        BuyMarketPoint(InpMagicNumber, InpLotSizeTrend, InpStopLossTrend, InpTakeProfitTrend, "Trend Up");
    }
    else if (isDownTrend && lastCLose < shortMA && isCandleLong && isCandleReversalDown && isVolumeHigh)
    {
        SellMarketPoint(InpMagicNumber, InpLotSizeTrend, InpStopLossTrend, InpTakeProfitTrend, "Trend Down");
    }

}

//+------------------------------------------------------------------+
CandlePattern IdentifyPattern(double open, double high, double low, double close, int variationHigh) {
    double bodySize = MathAbs(close - open);
    double totalRange = high - low;

    // Doji
    if (bodySize <= 1 * _Point && totalRange >= variationHigh * _Point) return PATTERN_DOJI;
    
    // Hammer Verde (Bullish Hammer)
    if ((close > open) && (totalRange > (3 * bodySize)) && ((high - close) <= 15 * _Point) && (totalRange >= variationHigh * _Point)) 
        return PATTERN_HAMMER_GREEN;

    // Hammer Vermelho (Bearish Hammer) Pafio muiiiito grande 8x > corpo
    if ((close < open) && (totalRange > (8 * bodySize)) && ((high - open) <= 15 * _Point) && (totalRange >= variationHigh * _Point)) 
        return PATTERN_HAMMER_RED;

    // Marubozu
    if ((close > open) && (bodySize > (totalRange * 0.8)) && (totalRange >= variationHigh * _Point)) 
        return PATTERN_MARUBOZU_GREEN;
    if ((close < open) && (bodySize > (totalRange * 0.8)) && (totalRange >= variationHigh * _Point)) 
        return PATTERN_MARUBOZU_RED;

    // Shooting Star Vermelho (Bearish Shooting Star)
    if ((close < open) && (totalRange > (3 * bodySize)) && ((close - low) <= 15 * _Point) && (totalRange >= variationHigh * _Point)) 
        return PATTERN_SHOOTING_STAR_RED;

    // Shooting Star Verde (Bullish Shooting Star) Pavio muiiiiito grande 8x > corpo
    if ((close > open) && (totalRange > (8 * bodySize)) && ((open - low) <= 15 * _Point) && (totalRange >= variationHigh * _Point)) 
        return PATTERN_SHOOTING_STAR_GREEN;

    // Spinning Top
    if ((close > open) && (bodySize * 2 < (open - low)) && (bodySize < (high - close)) && totalRange >= variationHigh * _Point) 
        return PATTERN_SPINNING_TOP;
    if ((close < open) && (bodySize * 2 < (close - low)) && (bodySize < (high - open)) && totalRange >= variationHigh * _Point) 
        return PATTERN_SPINNING_TOP;

    return PATTERN_NONE;
}

string GetCandlePatternName(CandlePattern pattern) {
    int index = (int)pattern;
    if (index >= 0 && index < ArraySize(CandlePatternNames)) {
        return CandlePatternNames[index];
    }
    return "PATTERN_UNKNOWN";
}

bool IsCandleLong()
{
    double currentRange = MathAbs(iClose(Symbol(), InpTimeframe, 1) - iOpen(Symbol(), InpTimeframe, 1));
    double previousRange = MathAbs(iClose(Symbol(), InpTimeframe, 2) - iOpen(Symbol(), InpTimeframe, 2));
    return (currentRange > previousRange * (1 + InpCandleLongPercent/ 100.0));
}

bool IsCandleReversal(bool isUptrend)
{
    double previousOpen = iOpen(Symbol(), InpTimeframe, 2);
    double previousClose = iClose(Symbol(), InpTimeframe, 2);
    double lastOpen = iOpen(Symbol(), InpTimeframe, 1);
    double lastClose = iClose(Symbol(), InpTimeframe, 1);

    if (isUptrend)
    {
        return (previousClose < previousOpen && lastClose > lastOpen && lastClose > previousOpen);
    }
    else
    {
        return (previousClose > previousOpen && lastClose < lastOpen && lastClose < previousOpen);
    }
}

bool CalculateMovingAverages(double &shortMA, double &mediumMA, double &longMA)
{
    // Copia apenas o valor mais recente das médias móveis
    if (CopyBuffer(shortMAHandle, 0, 0, 1, shortMABuffer) <= 0 ||
        CopyBuffer(mediumMAHandle, 0, 0, 1, mediumMABuffer) <= 0 ||
        CopyBuffer(longMAHandle, 0, 0, 1, longMABuffer) <= 0) {
        Print(expertName + "Erro: Falha ao copiar os buffers das médias móveis.");
        return false;
    }

    // Obtém os valores das médias móveis
    shortMA = shortMABuffer[0];
    mediumMA = mediumMABuffer[0];
    longMA = longMABuffer[0];
    
    // Verifica se as médias estão suficientemente distantes
    if (MathAbs(shortMA - mediumMA) < (mediumMA * minDistanceShortMedium) ||
        MathAbs(mediumMA - longMA) < (longMA * minDistanceMediumLong) ||
        MathAbs(shortMA - longMA) < (longMA * minDistanceShortLong)) {
        if (!isProximityWarningPrinted) {
            isProximityWarningPrinted = true;
            isDistanceInfoPrinted = false;
        }
        return false;
    } else {
        if (!isDistanceInfoPrinted) {
            Print(expertName + "Médias móveis estão suficientemente distantes.");
            isDistanceInfoPrinted = true;
            isProximityWarningPrinted = false;
        }
    }

    return true;
}
