//+------------------------------------------------------------------+
//|                                                  MASRCandleEA.mq5|
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
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

// Inputs do EA
input string space0 = "#### Operacional ####";
input TYPE_SL InptSLMode = FIXED_SL;      // Modo de SL
input TYPE_TP InptTPMode = FIXED_TP;      // Modo de TP
input double InpRelGain = 2;              // Relação Loss/Gain (Essa opção desativa o TP fixo)
input int InpCandlesForSL = 10;           // Número de candles para analisar o topo/fundo anterior
input bool InpUseSpecificCandles = true;  // Operar apenas com candles específicos (estrela cadente/martelo)
input int InpVolumePeriod = 2;           // Período para cálculo da média de volume

input string space1 = "#### Médias Móveis ####";
input int InpMAPeriod1 = 50;              // Período da primeira Média Móvel
input int InpMAPeriod2 = 200;             // Período da segunda Média Móvel
input ENUM_MA_METHOD InpMAMethod = MODE_SMA; // Método da Média Móvel
input double InpMADistance = 0.01;        // Distância mínima da MA (em %)
input ENUM_NUMBER_LEVEL InpNumberLevel = MEDIUM; // Nível de sensibilidade

input string space2 = "#### Níveis de suporte e resistências ####";
input int InpMaxCandles = 500;            // Número máximo de candles analisados
input double InpSafeDistance = 50;        // Margem de tolerância (em pontos)
input bool InpUseMedian = false;          // Preferência: true para mediana, false para média
input int InpQtLevels = 10;               // Quantidade de níveis

// Variáveis globais
int gMaHandle1, gMaHandle2;               // Handles das Médias Móveis
double gSrLevels[];                       // Array para armazenar os níveis de suporte/resistência
int gTouchLevels[];                       // Array para contar quantas vezes o preço tocou em cada nível
double gMinDistance;                      // Distância mínima entre os níveis
double gStopLoss = 0;

//+------------------------------------------------------------------+
//| Função de inicialização da EA                                     |
//+------------------------------------------------------------------+
int OnInit()
{
    gStopLoss = InpStopLoss;
    
    // Obter os handles das Médias Móveis
    gMaHandle1 = iMA(NULL, 0, InpMAPeriod1, 0, InpMAMethod, PRICE_CLOSE);
    gMaHandle2 = iMA(NULL, 0, InpMAPeriod2, 0, InpMAMethod, PRICE_CLOSE);
    if (gMaHandle1 == INVALID_HANDLE || gMaHandle2 == INVALID_HANDLE)
    {
        Print("Erro ao criar os handles das Médias Móveis");
        return(INIT_FAILED);
    }

    // Inicializar os arrays
    ArrayResize(gSrLevels, InpQtLevels);
    ArrayResize(gTouchLevels, InpQtLevels);
    ArrayInitialize(gTouchLevels, 0);

    // Calcular a distância mínima entre os níveis
    double close = iClose(_Symbol, PERIOD_CURRENT, 0);
    if (InpNumberLevel == LOW) gMinDistance = close * 0.0008;
    else if (InpNumberLevel == MEDIUM) gMinDistance = close * 0.001;
    else if (InpNumberLevel == HIGH) gMinDistance = close * 0.0013;

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Função de desinicialização da EA                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Liberar os handles das Médias Móveis
    if (gMaHandle1 != INVALID_HANDLE)
        IndicatorRelease(gMaHandle1);
    if (gMaHandle2 != INVALID_HANDLE)
        IndicatorRelease(gMaHandle2);

    // Remover objetos gráficos
    ObjectsDeleteAll(0, "SRLevel_");
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
    
    // Identificar os níveis de suporte/resistência
    IdentifyResSupLevels();

    // Verifica o horário de funcionamento e fecha posições se necessário
    if (!CheckTradingTime(InpMagicNumber)) return;

    // Verifica se já existe uma posição aberta pelo bot
    if (HasOpenPosition(InpMagicNumber)) return;

    // Verificar se há candles suficientes
    if (Bars(_Symbol, InpTimeframe) < InpMAPeriod1 || Bars(_Symbol, InpTimeframe) < InpMAPeriod2)
        return;

    // Obter o preço atual
    double currentPrice = iClose(_Symbol, InpTimeframe, 0);

    // Obter os valores das Médias Móveis
    double maValue1[1], maValue2[1];
    if (CopyBuffer(gMaHandle1, 0, 0, 1, maValue1) != 1 || CopyBuffer(gMaHandle2, 0, 0, 1, maValue2) != 1)
    {
        Print("Erro ao copiar os buffers das Médias Móveis");
        return;
    }

    // Verificar a tendência das MAs
    bool isUptrend = maValue1[0] > maValue2[0];

    // Desenhar os níveis no gráfico
    DrawSupportResistanceLevels();

    // Verificar padrões de candlestick e níveis de suporte/resistência
    CheckForTrades(isUptrend);
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

    // Ordenar os níveis
    ArraySort(levels);

    // Preencher o array gSrLevels com os níveis mais próximos do preço atual
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
//| Verificar padrões de candlestick e níveis de suporte/resistência  |
//+------------------------------------------------------------------+
void CheckForTrades(bool isUptrend)
{
    // Obter dados do candle anterior
    double open = iOpen(_Symbol, InpTimeframe, 1);
    double high = iHigh(_Symbol, InpTimeframe, 1);
    double low = iLow(_Symbol, InpTimeframe, 1);
    double close = iClose(_Symbol, InpTimeframe, 1);

    // Verificar tendência de baixa
    if (!isUptrend && (!InpUseSpecificCandles || IsShootingStarRed(open, high, low, close)))
    {
        // Verificar se está próximo de uma resistência
        if (IsNearResistence(high, close) && IsVolumeAboveAverage()) //CheckQdtTouchAtPrice(false) &&
        {
            // Calcular Stop Loss (SL) e Take Profit (TP)
            double sl = CalculateSL(close, high, InptSLMode);
            double tp = CalculateTP(close, sl, InptTPMode);

            // Executar ordem de venda
            ExecuteSellOrderDefinedLSTP(InpMagicNumber, InpLotSize, sl, tp, "Venda");
        }
    }

    // Verificar tendência de alta
    if (isUptrend && (!InpUseSpecificCandles || IsHammerGreen(open, high, low, close)))
    {
        // Verificar se está próximo de um suporte
        if (IsNearSupport(low, close) && IsVolumeAboveAverage()) //&& CheckQdtTouchAtPrice(true)
        {
            // Calcular Stop Loss (SL) e Take Profit (TP)
            double sl = CalculateSL(close, low, InptSLMode);
            double tp = CalculateTP(close, sl, InptTPMode);

            // Executar ordem de compra
            ExecuteBuyOrderDefinedLSTP(InpMagicNumber, InpLotSize, sl, tp, "Compra");
        }
    }
}

//+------------------------------------------------------------------+
//| Calcular Stop Loss                                               |
//+------------------------------------------------------------------+
double CalculateSL(double close, double extremePrice, TYPE_SL slMode)
{
    double sl = 0;

    switch (slMode)
    {
        case FIXED_SL:
            sl = close + (InpStopLoss * _Point * (close < extremePrice ? -1 : 1));
            break;

        case MIN_MAX_SL:
            sl = extremePrice + (InpStopLoss * _Point * (close < extremePrice ? -1 : 1));
            break;

        case TOP_BOTTOM:
            sl = GetPreviousHighLow(close < extremePrice, InpCandlesForSL);
            break;
    }

    return NormalizeDouble(sl, _Digits);
}

//+------------------------------------------------------------------+
//| Calcular Take Profit                                             |
//+------------------------------------------------------------------+
double CalculateTP(double close, double sl, TYPE_TP tpMode)
{
    double tp = 0;

    switch (tpMode)
    {
        case FIXED_TP:
            tp = close + (InpTakeProfit * _Point * (close < sl ? 1 : -1));
            break;

        case REL_LOSS_GAIN:
            tp = close + (MathAbs(close - sl) * InpRelGain * (close < sl ? 1 : -1));
            break;
    }

    return NormalizeDouble(tp, _Digits);
}

//+------------------------------------------------------------------+
//| Obter o high/low anterior                                        |
//+------------------------------------------------------------------+
double GetPreviousHighLow(bool isHigh, int candlesToCheck)
{
    double extremeValue = isHigh ? 0 : DBL_MAX;

    for (int i = 1; i <= candlesToCheck; i++)
    {
        double high = iHigh(_Symbol, InpTimeframe, i);
        double low = iLow(_Symbol, InpTimeframe, i);

        if (isHigh)
        {
            if (high > extremeValue) extremeValue = high;
        }
        else
        {
            if (low < extremeValue) extremeValue = low;
        }
    }

    return extremeValue;
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
//| Verificar se está próximo de uma resistência                     |
//+------------------------------------------------------------------+
bool IsNearResistence(double high, double close)
{
    double lvl = getLevel(high, close);
    if (lvl == 0.0) return false;

    for (int i = 0; i < InpQtLevels; i++)
    {
        if (close < lvl && high > lvl)
            return true; // Preço está abaixo do nível e o high acima (resistência)
    }
    return false;
}

//+------------------------------------------------------------------+
//| Verificar se está próximo de um suporte                          |
//+------------------------------------------------------------------+
bool IsNearSupport(double low, double close)
{
    double lvl = getLevel(close, low);
    if (lvl == 0.0) return false;

    for (int i = 0; i < InpQtLevels; i++)
    {
        if (close > lvl && low < lvl)
            return true; // Preço está acima do nível e o low abaixo (suporte)
    }
    return false;
}

//+------------------------------------------------------------------+
//| Calcular a média de volume com base em X candles anteriores       |
//+------------------------------------------------------------------+
bool IsVolumeAboveAverage()
{
    double volumeSum = 0;
    for (int i = 1; i <= InpVolumePeriod; i++)
    {
        volumeSum += iVolume(_Symbol, InpTimeframe, i);
    }
    double volumeAvg = volumeSum / InpVolumePeriod;

    // Verificar se o volume do candle anterior é maior que a média
    return (iVolume(_Symbol, InpTimeframe, 1) > volumeAvg);
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