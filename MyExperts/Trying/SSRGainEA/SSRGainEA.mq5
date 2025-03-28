#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property version   "1.00"

#include "../DefaultInputs.mqh"
#include "../DefaultFunctions.mqh"

enum TYPE_SL {
   FIXED_SL,
   MIN_MAX_SL,
   TOP_BOTTOM
};

enum TYPE_TP{
   FIXED_TP,
   REL_LOSS_GAIN
};

enum ENUM_NUMBER_LEVEL {
   LOW,
   MEDIUM,
   HIGH
};

input string space1 = "#### Operacional ####"; //#### Operacional ####
input TYPE_SL InptSLMode = FIXED_SL;      // Modo de SL
input TYPE_TP InptTPMode = FIXED_TP;      // Modo de TP
input double InpRelGain = 2;              // Relação Loss/Gain (selecione essa opção no modo de TP)
input bool InpUseSpecificCandles = true;  // Operar apenas com candles específicos (estrela cadente/martelo)
input int InpVolumePeriod = 2;            // Período para cálculo da média de volume
input int InpSlidingWindow = 5;           // Janela de tempo deslizante (em candles) para ocorrer as condições de trade

input string space2 = "#### Suporte e Resistência  ####"; //#### Suporte e Resistência  ####
input bool InpUseSupportResistance = true; // Usar suporte e resistência
input int InpMaxCandles = 500;            // Número máximo de candles analisados
input double InpSafeDistance = 50;        // Margem de tolerância (em pontos)
input bool InpUseMedian = false;          // Preferência: true para mediana, false para média
input int InpQtLevels = 16;               // Quantidade de níveis
input ENUM_NUMBER_LEVEL InpNumberLevel = MEDIUM; // Nível de sensibilidade

input string space3 = "#### Estocástico ####"; //#### Estocástico ####
input bool InpUseStochastic = true;       // Usar indicador Stochastic
input int InpStochKPeriod = 5;            // Período %K do Stochastic
input int InpStochDPeriod = 3;            // Período %D do Stochastic
input int InpStochSlowing = 3;            // Slowing do Stochastic
input double InpStochOverbought = 80;     // Nível de sobrecompra
input double InpStochOversold = 20;       // Nível de sobrevenda

input string space4 = "#### Médias Móveis ####"; //#### Médias Móveis ####
input bool InpUseTrendDetection = true;   // Usar detecção de tendência com MAs
input int InpShortMAPeriod = 10;          // Período da MA curta
input int InpMediumMAPeriod = 20;         // Período da MA média
input int InpLongMAPeriod = 50;           // Período da MA longa
input double InpMinDistanceShortLong = 1; // Distância mínima entre MA curta e longa (%)
input double InpMinDistanceMediumLong = 0.5; // Distância mínima entre MA média e longa (%)
input double InpMinDistanceShortMedium = 0.5; // Distância mínima entre MA curta e média (%)

// Variáveis globais
bool conditionsMetSell[]; // Condições para venda ao longo da janela
bool conditionsMetBuy[];  // Condições para compra ao longo da janela

// Variáveis globais
double gSrLevels[];                     // Array para armazenar os níveis de suporte/resistência
int gTouchLevels[];                     // Array para contar quantas vezes o preço tocou em cada nível
double gMinDistance;                    // Distância mínima entre os níveis
double gStopLoss = 0;
int gStochHandle;                       // Handle do indicador Stochastic
int gShortMAHandle, gMediumMAHandle, gLongMAHandle; // Handles das MAs
double minDistanceShortLong, minDistanceMediumLong, minDistanceShortMedium; // Distâncias mínimas entre as MAs

// Flags globais para rastrear condições dentro da janela
bool flagOverbought = false;
bool flagOversold = false;
bool flagCrossDown = false;
bool flagCrossUp = false;
bool flagResistance = false;
bool flagSupport = false;

//+------------------------------------------------------------------+
//| Função de inicialização da EA                                     |
//+------------------------------------------------------------------+
int OnInit()
{
    gStopLoss = InpStopLoss;

    // Inicializar os arrays
    ArrayResize(gSrLevels, InpQtLevels);
    ArrayResize(gTouchLevels, InpQtLevels);
    ArrayInitialize(gTouchLevels, 0);
    
    InitializeConditionArrays();

    // Calcular a distância mínima entre os níveis
    double close = iClose(_Symbol, InpTimeframe, 0);
    if (InpNumberLevel == LOW) gMinDistance = close * 0.0008;
    else if (InpNumberLevel == MEDIUM) gMinDistance = close * 0.001;
    else if (InpNumberLevel == HIGH) gMinDistance = close * 0.0013;

    // Inicializar o indicador Stochastic
    if (InpUseStochastic)
    {
        gStochHandle = iStochastic(_Symbol, _Period, InpStochKPeriod, InpStochDPeriod, InpStochSlowing, MODE_SMA, STO_LOWHIGH);
        if (gStochHandle == INVALID_HANDLE)
        {
            Print("Erro ao criar o handle do Stochastic");
            return(INIT_FAILED);
        }
    }

    // Inicializar as MAs
    if (InpUseTrendDetection)
    {
        gShortMAHandle = iMA(_Symbol, _Period, InpShortMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
        gMediumMAHandle = iMA(_Symbol, _Period, InpMediumMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
        gLongMAHandle = iMA(_Symbol, _Period, InpLongMAPeriod, 0, MODE_SMA, PRICE_CLOSE);

        if (gShortMAHandle == INVALID_HANDLE || gMediumMAHandle == INVALID_HANDLE || gLongMAHandle == INVALID_HANDLE)
        {
            Print("Erro ao criar os handles das MAs");
            return(INIT_FAILED);
        }

        // Pré-calcula as distâncias mínimas
        minDistanceShortLong = InpMinDistanceShortLong / 100.0;
        minDistanceMediumLong = InpMinDistanceMediumLong / 100.0;
        minDistanceShortMedium = InpMinDistanceShortMedium / 100.0;
    }

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Função de desinicialização da EA                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Remover objetos gráficos
    ObjectsDeleteAll(0, "SRLevel_");

    // Liberar os handles dos indicadores
    if (gStochHandle != INVALID_HANDLE)
        IndicatorRelease(gStochHandle);
    if (gShortMAHandle != INVALID_HANDLE)
        IndicatorRelease(gShortMAHandle);
    if (gMediumMAHandle != INVALID_HANDLE)
        IndicatorRelease(gMediumMAHandle);
    if (gLongMAHandle != INVALID_HANDLE)
        IndicatorRelease(gLongMAHandle);
}

//+------------------------------------------------------------------+
//| Função de iteração da EA                                         |
//+------------------------------------------------------------------+
void OnTick()
{
    // Verifica e fecha trades com stops ignorados
    CheckStopsSkippedAndCloseTrade(InpMagicNumber);

    // Cancela ordens pendentes antigas
    CancelOldPendingOrders(InpMagicNumber, InpOrderExpiration);

    // Aplica trailing stop se estiver ativado
    if (InpTrailingStop) MonitorTrailingStop(InpMagicNumber, gStopLoss);

    // Verifica a última negociação e envia e-mail se necessário
    CheckLastTradeAndSendEmail(InpMagicNumber);

    // Verifica se é um novo candle
    if (!isNewCandle()) return;

    // Verificar se há candles suficientes
    if (Bars(NULL, 0) < InpMaxCandles)
        return;

    // Identificar os níveis de suporte/resistência
    if (InpUseSupportResistance)
    {
        IdentifyResSupLevels();
        DrawSupportResistanceLevels();
    }

    // Verifica o horário de funcionamento e fecha posições se necessário
    if (!CheckTradingTime(InpMagicNumber)) return;

    // Verifica se já existe uma posição aberta pelo bot
    if (HasOpenPosition(InpMagicNumber)) return;

    // Verificar padrões de candlestick e níveis de suporte/resistência
    CheckForTrades();
}

//+------------------------------------------------------------------+
//| Inicializa as condições ao início                                |
//+------------------------------------------------------------------+
void InitializeConditionArrays()
{
    ArrayResize(conditionsMetSell, InpSlidingWindow);
    ArrayResize(conditionsMetBuy, InpSlidingWindow);
    ArrayInitialize(conditionsMetSell, false);
    ArrayInitialize(conditionsMetBuy, false);
}

//+------------------------------------------------------------------+
//| Função principal de verificação de sinais de trade               |
//+------------------------------------------------------------------+
void CheckForTrades()
{
    // Reinicializar as flags a cada chamada
    ResetFlags();

    // Obter dados do candle atual e anteriores na janela deslizante
    double high[], low[], close[];
    if (CopyHigh(_Symbol, InpTimeframe, 1, InpSlidingWindow, high) <= 0 ||
        CopyLow(_Symbol, InpTimeframe, 1, InpSlidingWindow, low) <= 0 ||
        CopyClose(_Symbol, InpTimeframe, 1, InpSlidingWindow, close) <= 0)
    {
        Print("Erro ao copiar dados de candles.");
        return;
    }

    // Obter valores do Stochastic
    double stochK[], stochD[];
    if (InpUseStochastic)
    {
        if (CopyBuffer(gStochHandle, 0, 1, InpSlidingWindow, stochK) <= 0 || 
            CopyBuffer(gStochHandle, 1, 1, InpSlidingWindow, stochD) <= 0)
        {
            Print("Erro ao copiar dados do Stochastic.");
            return;
        }
    }

    // Verificar condições em todos os candles da janela
    for (int i = InpSlidingWindow - 1; i >= 0; i--)
    {
        // Condição de sobrecompra/sobrevenda
        if (InpUseStochastic)
        {
            if (stochK[i] >= InpStochOverbought)
                flagOverbought = true;
            if (stochK[i] <= InpStochOversold)
                flagOversold = true;

            // Cruzamento do Stochastic
            if (i > 0 && stochK[i - 1] > stochD[i - 1] && stochK[i] < stochD[i])
                flagCrossDown = true;
            if (i > 0 && stochK[i - 1] < stochD[i - 1] && stochK[i] > stochD[i])
                flagCrossUp = true;
        }

        // Proximidade de resistência/suporte
        if (InpUseSupportResistance)
        {
            if (IsNearResistence(high[i], close[i], InpSafeDistance))
                flagResistance = true;
            if (IsNearSupport(low[i], close[i], InpSafeDistance))
                flagSupport = true;
        }
    }
    
    bool volHigh = IsVolumeAboveAverage();
    double lastClose = iClose(_Symbol, InpTimeframe, 1);
    double lastHigh = iHigh(_Symbol, InpTimeframe, 1);
    double lastLow = iLow(_Symbol, InpTimeframe, 1);

    // Verificar tendência com as MAs
    bool isUptrend = false, isDowntrend = false;
    if (InpUseTrendDetection)
    {
        double shortMA, mediumMA, longMA;
        if (CalculateMovingAverages(shortMA, mediumMA, longMA))
        {
            isUptrend = (shortMA > mediumMA && mediumMA > longMA);
            isDowntrend = (shortMA < mediumMA && mediumMA < longMA);
        }
    }

    // Verificar se todas as condições para venda foram atendidas
    if ((!InpUseTrendDetection || isDowntrend) && flagOverbought && flagCrossDown && flagResistance && volHigh)
    {
        double sl = CalculateSL(lastClose, lastHigh, InptSLMode);
        double tp = Normalize(CalculateTP(lastClose, sl, InptTPMode, InpRelGain));
        gStopLoss = MathAbs(lastClose - sl);

        ExecuteSellOrderDefinedLSTP(InpMagicNumber, InpLotSize, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), "Venda");
        ResetFlags();
    }

    // Verificar se todas as condições para compra foram atendidas
    if ((!InpUseTrendDetection || isUptrend) && flagOversold && flagCrossUp && flagSupport && volHigh)
    {
        double sl = CalculateSL(lastClose, lastLow, InptSLMode);
        double tp = Normalize(CalculateTP(lastClose, sl, InptTPMode, InpRelGain));
        gStopLoss = MathAbs(lastClose - sl);

        ExecuteBuyOrderDefinedLSTP(InpMagicNumber, InpLotSize, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), "Compra");
        ResetFlags();
    }
}

//+------------------------------------------------------------------+
//| Calcular as Médias Móveis                                        |
//+------------------------------------------------------------------+
bool CalculateMovingAverages(double &shortMA, double &mediumMA, double &longMA)
{
    double shortMABuffer[], mediumMABuffer[], longMABuffer[];
    ArraySetAsSeries(shortMABuffer, true);
    ArraySetAsSeries(mediumMABuffer, true);
    ArraySetAsSeries(longMABuffer, true);

    if (CopyBuffer(gShortMAHandle, 0, 0, 1, shortMABuffer) <= 0 ||
        CopyBuffer(gMediumMAHandle, 0, 0, 1, mediumMABuffer) <= 0 ||
        CopyBuffer(gLongMAHandle, 0, 0, 1, longMABuffer) <= 0)
    {
        Print("Erro ao copiar os buffers das MAs.");
        return false;
    }

    shortMA = shortMABuffer[0];
    mediumMA = mediumMABuffer[0];
    longMA = longMABuffer[0];

    // Verificar distâncias mínimas
    if (MathAbs(shortMA - mediumMA) < (mediumMA * minDistanceShortMedium) ||
        MathAbs(mediumMA - longMA) < (longMA * minDistanceMediumLong) ||
        MathAbs(shortMA - longMA) < (longMA * minDistanceShortLong))
    {
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Reinicializar as flags                                           |
//+------------------------------------------------------------------+
void ResetFlags()
{
    flagOverbought = false;
    flagOversold = false;
    flagCrossDown = false;
    flagCrossUp = false;
    flagResistance = false;
    flagSupport = false;
}

//+------------------------------------------------------------------+
//| Verificar se está próximo de uma resistência                     |
//+------------------------------------------------------------------+
bool IsNearResistence(double high, double close, double margin)
{
    double lvl = getLevel(high, close);
    if (lvl == 0.0) return false;

    // Verificar se o preço está dentro da margem X do nível de resistência
    return (close <= lvl + margin * _Point && close >= lvl - margin * _Point);
}

//+------------------------------------------------------------------+
//| Verificar se está próximo de um suporte                          |
//+------------------------------------------------------------------+
bool IsNearSupport(double low, double close, double margin)
{
    double lvl = getLevel(close, low);
    if (lvl == 0.0) return false;

    // Verificar se o preço está dentro da margem X do nível de suporte
    return (close <= lvl + margin * _Point && close >= lvl - margin * _Point);
}

//+------------------------------------------------------------------+
//| Obter o nível de suporte/resistência mais próximo                |
//+------------------------------------------------------------------+
double getLevel(double high, double low)
{
    for (int i = 0; i < InpQtLevels; i++)
    {
        if (gSrLevels[i] != 0 && low < gSrLevels[i] && high > gSrLevels[i])
        {
            return gSrLevels[i];
        }
    }
    return 0.0; // Retorna 0.0 se nenhum nível for encontrado
}

//+------------------------------------------------------------------+
//| Verificar Shooting Star Red                                       |
//+------------------------------------------------------------------+
bool IsShootingStarRed(double open, double high, double low, double close)
{
    double bodySize = MathAbs(close - open);
    double upperShadow = high - MathMax(open, close);
    double lowerShadow = MathMin(open, close) - low;

    // Shooting Star: corpo pequeno, sombra superior longa, sombra inferior pequena
    return (bodySize < (high - low) * 0.3 && upperShadow > bodySize * 2 && lowerShadow < bodySize * 0.5 && close < open);
}

//+------------------------------------------------------------------+
//| Verificar Hammer Green                                            |
//+------------------------------------------------------------------+
bool IsHammerGreen(double open, double high, double low, double close)
{
    double bodySize = MathAbs(close - open);
    double upperShadow = high - MathMax(open, close);
    double lowerShadow = MathMin(open, close) - low;

    // Hammer: corpo pequeno, sombra inferior longa, sombra superior pequena
    return (bodySize < (high - low) * 0.3 && lowerShadow > bodySize * 2 && upperShadow < bodySize * 0.5 && close > open);
}

//+------------------------------------------------------------------+
//| Calcular a média de volume com base em X candles anteriores       |
//+------------------------------------------------------------------+
bool IsVolumeAboveAverage()
{
    double volumeSum = 0;
    for (int i = 2; i <= 1+InpVolumePeriod; i++)
    {
        volumeSum += iVolume(_Symbol, InpTimeframe, i);
    }
    double volumeAvg = volumeSum / InpVolumePeriod;

    // Verificar se o volume do candle anterior é maior que a média
    return (iVolume(_Symbol, InpTimeframe, 1) > volumeAvg);
}

//+------------------------------------------------------------------+
//| Identificar níveis de suporte/resistência                        |
//+------------------------------------------------------------------+
void IdentifyResSupLevels()
{
    double levels[];

    // Obter dados dos candles
    double high[], low[], close[];
    if (CopyHigh(_Symbol, InpTimeframe, 1, InpMaxCandles, high) <= 0 ||
        CopyLow(_Symbol, InpTimeframe, 1, InpMaxCandles, low) <= 0 ||
        CopyClose(_Symbol, InpTimeframe, 1, InpMaxCandles, close) <= 0)
    {
        Print("Erro ao copiar dados dos candles");
        return;
    }

    // Identificar topos e fundos
    for (int i = 1; i < InpMaxCandles - 1; i++)
    {
        if (high[i] > high[i - 1] && high[i] > high[i + 1])
        {
            if (!IsCloseLevel(high[i], levels, gMinDistance))
            {
                ArrayResize(levels, ArraySize(levels) + 1);
                levels[ArraySize(levels) - 1] = high[i];
            }
        }

        if (low[i] < low[i - 1] && low[i] < low[i + 1])
        {
            if (!IsCloseLevel(low[i], levels, gMinDistance))
            {
                ArrayResize(levels, ArraySize(levels) + 1);
                levels[ArraySize(levels) - 1] = low[i];
            }
        }
    }

    ArraySort(levels);

    double currentPrice = iClose(_Symbol, _Period, 0);
    int levelsAbove = 0, levelsBelow = 0;
    for (int i = 0; i < ArraySize(levels); i++)
    {
        if (levels[i] < currentPrice && levelsBelow < InpQtLevels / 2)
        {
            gSrLevels[levelsBelow++] = levels[i];
        }
        else if (levels[i] > currentPrice && levelsAbove < InpQtLevels / 2)
        {
            gSrLevels[InpQtLevels / 2 + levelsAbove++] = levels[i];
        }
    }
}

//+------------------------------------------------------------------+
//| Verificar se um nível está próximo de outro                      |
//+------------------------------------------------------------------+
bool IsCloseLevel(double level, const double &levels[], double min_distance)
{
    for (int i = 0; i < ArraySize(levels); i++)
    {
        if (MathAbs(level - levels[i]) <= min_distance)
            return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Desenhar os níveis de suporte/resistência no gráfico             |
//+------------------------------------------------------------------+
void DrawSupportResistanceLevels()
{
    // Remover todas as linhas antigas
    ObjectsDeleteAll(0, "SRLevel_");

    // Desenhar os novos níveis
    for (int i = 0; i < InpQtLevels; i++)
    {
        if (gSrLevels[i] != 0)
        {
            string lineName = "SRLevel_" + IntegerToString(i);
            color lineColor = (gSrLevels[i] < iClose(_Symbol, InpTimeframe, 0)) ? clrRed : clrGreen;

            // Criar a linha horizontal
            ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, gSrLevels[i]);
            ObjectSetInteger(0, lineName, OBJPROP_COLOR, lineColor);
            ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_SOLID);
        }
    }
}

//+------------------------------------------------------------------+
//| Calcular Stop Loss                                               |
//+------------------------------------------------------------------+
double CalculateSL(double close, double extreme, TYPE_SL slMode)
{
    double sl = 0;

    if (slMode == FIXED_SL)
    {
        sl = close + (InpStopLoss * _Point * (close < extreme ? 1 : -1));
    }
    else if (slMode == MIN_MAX_SL)
    {
        sl = extreme + (InpStopLoss * _Point * (close < extreme ? 1 : -1));
    }
    else if (slMode == TOP_BOTTOM)
    {
        // Aqui você pode adicionar a lógica para calcular o SL com base no topo/fundo anterior
        sl = close + (InpStopLoss * _Point * (close < extreme ? 1 : -1));
    }

    return NormalizeDouble(sl, _Digits);
}

//+------------------------------------------------------------------+
//| Calcular Take Profit                                             |
//+------------------------------------------------------------------+
double CalculateTP(double close, double sl, TYPE_TP tpMode, double relGain)
{
    double tp = 0;

    if (tpMode == FIXED_TP)
    {
        tp = close + (InpTakeProfit * _Point * (close < sl ? -1 : 1));
    }
    else if (tpMode == REL_LOSS_GAIN)
    {
        double risk = MathAbs(close - sl);
        tp = close + (risk * relGain * (close < sl ? -1 : 1));
    }

    return NormalizeDouble(tp, _Digits);
}