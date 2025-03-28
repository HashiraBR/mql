//+------------------------------------------------------------------+
//|                                          TrendCandleMaster.mq5   |
//|                        Copyright © 2023, Danne M. G. Pereira     |
//|                              Email: makleyston@gmail.com         |
//|                              Site: www.aipi.com.br               |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2023, Danne M. G. Pereira"
#property link      "www.aipi.com.br"
#property version   "1.0"
#property description "TrendCandleMaster - Expert Advisor baseado médias móveis e sinal de pullback."
#property description " "
#property description "Funcionalidades:"
#property description "- Identifica e opera a favor de tendências."
#property description "- Identifica sinais de pullback como entrada da operação."
#property description "- Opera com base em médias móveis e distâncias mínimas entre elas."
#property description "- Gerenciamento de risco com Stop Loss e Take Profit."
#property description "- Horário de negociação configurável."
#property description "- Envio de e-mails para notificações."
#property description " "
#property description "Recomendações:"
#property description "- Use, preferencialmente, no timeframe de M2."
//#property description "- Ajuste os parâmetros de distância entre médias móveis conforme o ativo."
#property icon "\\Images\\CandlesMaster.ico" // Ícone personalizado (opcional)
#property script_show_inputs


#include "../DefaultInputs.mqh"
#include "../DefaultFunctions.mqh"

//+------------------------------------------------------------------+
//| Inputs do Expert Advisor                                         |
//+------------------------------------------------------------------+

// Configurações de Stop Loss Móvel
input bool     InpSLMobilePerCandle = false;     // SL no Fundo/Topo anterior

// Configurações de Slippage
input double   InpSlippage = 5.0;               // Margem de slippage (em pontos)

// Configurações de Médias Móveis
input int      InpShortMAPeriod = 9;            // Período da Média Móvel Curta
input int      InpMediumMAPeriod = 17;          // Período da Média Móvel Média
input int      InpLongMAPeriod = 50;            // Período da Média Móvel Longa
input ENUM_APPLIED_PRICE InpEntryPriceType = PRICE_CLOSE; // Tipo de preço para cálculo das médias

// Distâncias Mínimas entre Médias Móveis (em porcentagem)
input double   InpMinDistanceShortMedium = 0.06; // Distância mínima entre curta e média (%)
input double   InpMinDistanceMediumLong = 0.06;  // Distância mínima entre média e longa (%)
input double   InpMinDistanceShortLong = 0.06;   // Distância mínima entre curta e longa (%)

// Configurações de Candles
input double   InpCandleLongPercent = 5.0;      // Variação dos tamanhos dos candles em %
input int InpXCandles = 2;                      // Qt candles para cálculo de média de vol.

// Variáveis globais
double initialBalance;
bool isProximityWarningPrinted = false;
bool isDistanceInfoPrinted = false;
enum CandlePattern {
    PATTERN_NONE,
    PATTERN_DOJI,
    PATTERN_HAMMER,
    PATTERN_MARUBOZU,
    PATTERN_MARUBOZU_GREEN,
    PATTERN_MARUBOZU_RED,
    PATTERN_SHOOTING_STAR,
    PATTERN_SPINNING_TOP,
};

//+------------------------------------------------------------------+
//| Função principal do Expert Advisor                               |
//+------------------------------------------------------------------+

int shortMAHandle, mediumMAHandle, longMAHandle;
double minDistanceShortLong, minDistanceMediumLong, minDistanceShortMedium;
double shortMABuffer[], mediumMABuffer[], longMABuffer[];

int OnInit() {

    // Verifica o número de barras disponíveis
    int availableBars = Bars(Symbol(), InpTimeframe);
    if (availableBars < InpLongMAPeriod) {
        Print(expertName + "Erro: Dados insuficientes para calcular médias móveis. Bars disponíveis: ", availableBars);
        return INIT_FAILED;
    }

    // Cria os handles dos indicadores de média móvel
    shortMAHandle = iMA(Symbol(), InpTimeframe, InpShortMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
    mediumMAHandle = iMA(Symbol(), InpTimeframe, InpMediumMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
    longMAHandle = iMA(Symbol(), InpTimeframe, InpLongMAPeriod, 0, MODE_SMA, PRICE_CLOSE);

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

    return INIT_SUCCEEDED;
}


void OnTick()
{

    CheckStopsSkippedAndCloseTrade(InpMagicNumber);
   
    // Cancela ordens velhas
    CancelOldPendingOrders(InpMagicNumber, InpOrderExpiration);
    
    // Aplica Trailing Stop se estiver ativado
    if (InpTrailingStop) MonitorTrailingStop(InpMagicNumber, InpStopLoss);

    // Verifica a última negociação e envia e-mail se necessário
    CheckLastTradeAndSendEmail(InpMagicNumber);
    
    // Verifica se é um novo candle
    if (!isNewCandle()) return;
       
    // Aplica Trailing Stop POR CANDLE se estiver ativado
    if (InpSLMobilePerCandle) MonitorTrailingStop(InpMagicNumber, InpStopLoss);
   
    // Verifica horário de funcionamento e fecha possições
    if (!CheckTradingTime(InpMagicNumber)) 
        return;
        
    if(HasOpenPosition(InpMagicNumber))
        return;

    double shortMA, mediumMA, longMA;
    if (!CalculateMovingAverages(shortMA, mediumMA, longMA)) return;

    double closePrice = iClose(Symbol(), InpTimeframe, 1);

    bool isUptrend = (shortMA > mediumMA && mediumMA > longMA);
    bool isDowntrend = (shortMA < mediumMA && mediumMA < longMA);
    bool isCandleLong = IsCandleLong();
    bool isCandleReversalUp = IsCandleReversal(true);
    bool isCandleReversalDown = IsCandleReversal(false);
    bool isVolumeHigh = isVolumeAboveAverage(); 
    
    if (isUptrend && closePrice > shortMA && isCandleLong && isCandleReversalUp && isVolumeHigh)
    {
        ExecuteBuy(closePrice);
    }
    else if (isDowntrend && closePrice < shortMA && isCandleLong && isCandleReversalDown && isVolumeHigh)
    {
        ExecuteSell(closePrice);
    }
}

//+------------------------------------------------------------------+
//| Função para calcular as médias móveis                            |
//+------------------------------------------------------------------+
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

bool isVolumeAboveAverage() {
    // Verifica se x é válido
    if (InpXCandles <= 0) {
        Print("Erro: O valor de x deve ser maior que 0.");
        return false;
    }

    // Calcula a soma dos volumes dos últimos x candles antes do candle de análise (Candle[1])
    double sumVolumes = 0;
    for (int i = 1; i <= InpXCandles; i++) {
        sumVolumes += (double)iVolume(_Symbol, _Period, i + 1); // i + 1 porque Candle[1] é o candle de análise
    }

    // Calcula a média dos volumes
    double averageVolume = sumVolumes / InpXCandles;

    // Obtém o volume do candle de análise (Candle[1])
    double analysisVolume = (double)iVolume(_Symbol, _Period, 1);

    // Retorna true se o volume do candle de análise for maior que a média
    return analysisVolume > averageVolume;
}


//+------------------------------------------------------------------+
//| Verifica se há um candle longo                                   |
//+------------------------------------------------------------------+
bool IsCandleLong()
{
    double currentRange = MathAbs(iClose(Symbol(), InpTimeframe, 1) - iOpen(Symbol(), InpTimeframe, 1));
    double previousRange = MathAbs(iClose(Symbol(), InpTimeframe, 2) - iOpen(Symbol(), InpTimeframe, 2));
    return (currentRange > previousRange * (1 + InpCandleLongPercent/ 100.0));
}

//+------------------------------------------------------------------+
//| Verifica se os candles estão em sentidos opostos                 |
//+------------------------------------------------------------------+
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

CandlePattern IdentifyPattern(double open, double high, double low, double close) {
    double bodySize = MathAbs(close - open);
    double totalRange = high - low;

    // Doji
    if (bodySize <= 1 * _Point) return PATTERN_DOJI;

    // Hammer
    if ((close > open) && ((bodySize * 2) < (open - low)) && ((bodySize * 0.5) > (high - close))) 
        return PATTERN_HAMMER;
    if ((close < open) && ((bodySize * 2) < (close - low)) && ((bodySize * 0.5) > (high - open))) 
        return PATTERN_HAMMER;

    // Marubozu
    if ((close > open) && (bodySize > (totalRange * 0.7))) 
        return PATTERN_MARUBOZU_GREEN;
    if ((close < open) && (bodySize > (totalRange * 0.7))) 
        return PATTERN_MARUBOZU_RED;

    // Shooting Star
    if ((close < open) && (totalRange > (2 * bodySize)) && (close == low)) 
        return PATTERN_SHOOTING_STAR;
    if ((close > open) && (totalRange > (2 * bodySize)) && (close == low)) 
        return PATTERN_SHOOTING_STAR;

    // Spinning Top
    if ((close > open) && (bodySize < (open - low)) && (bodySize < (high - close))) 
        return PATTERN_SPINNING_TOP;
    if ((close < open) && (bodySize < (close - low)) && (bodySize < (high - open))) 
        return PATTERN_SPINNING_TOP;

    return PATTERN_NONE;
}


//+------------------------------------------------------------------+
//| Lógica de evitar comprar depois de determinados candles          |
//+------------------------------------------------------------------+
bool CheckPreviousCandle(bool isUptrend, bool isDownTrend) {
    // Obtém os valores do último candle
    double lastOpen = iOpen(_Symbol, _Period, 1);
    double lastClose = iClose(_Symbol, _Period, 1);
    double lastHigh = iHigh(_Symbol, _Period, 1);
    double lastLow = iLow(_Symbol, _Period, 1);

    // Identifica o padrão do último candle
    CandlePattern pattern = IdentifyPattern(lastOpen, lastHigh, lastLow, lastClose);

    // Verifica se o padrão é contra a tendência
    if (isUptrend) {
        // Em tendência de alta, evita padrões de reversão ou indecisão
        if (pattern == PATTERN_SHOOTING_STAR || 
            pattern == PATTERN_DOJI || 
            pattern == PATTERN_SPINNING_TOP || 
            pattern == PATTERN_MARUBOZU_RED) {
            Print(expertName + "Padrão contra tendência de alta: "+IntegerToString(pattern));
            return false; // Padrão contra a tendência de alta
        }
    } else if (isDownTrend) {
        // Em tendência de baixa, evita padrões de reversão ou indecisão
        if (pattern == PATTERN_HAMMER || 
            pattern == PATTERN_MARUBOZU_GREEN || 
            pattern == PATTERN_DOJI || 
            pattern == PATTERN_SPINNING_TOP) {
            Print(expertName + "Padrão contra tendência de baixa: "+IntegerToString(pattern));
            return false; // Padrão contra a tendência de baixa
        }
    }

    return true; // Padrão alinhado com a tendência
}


//+------------------------------------------------------------------+
//| Lógica para sair da operação depois de determinados candles      |
//+------------------------------------------------------------------+
bool HasReversalOrIndecisionPattern() {
    // Obtém os dados do candle atual ou do último candle fechado
    double open = iOpen(_Symbol, _Period, 0);
    double close = iClose(_Symbol, _Period, 0);
    double high = iHigh(_Symbol, _Period, 0);
    double low = iLow(_Symbol, _Period, 0);

    // Identifica o padrão do candle
    CandlePattern pattern = IdentifyPattern(open, high, low, close);

    // Lista de padrões de reversão ou indecisão
    if (pattern == PATTERN_SHOOTING_STAR || 
        pattern == PATTERN_DOJI || 
        pattern == PATTERN_SPINNING_TOP || 
        pattern == PATTERN_HAMMER || 
        pattern == PATTERN_MARUBOZU_RED || 
        pattern == PATTERN_MARUBOZU_GREEN) {
        return true; // Padrão de reversão ou indecisão identificado
    }

    return false; // Nenhum padrão de reversão ou indecisão
}



//+------------------------------------------------------------------+
//| Executa uma ordem de compra                                      |
//+------------------------------------------------------------------+
void ExecuteBuy(double price)
{
    price = Normalize(price + InpSlippage * _Point);
    double sl = Normalize(price - InpStopLoss * _Point);
    double tp = Normalize(price + InpTakeProfit * _Point);
    trade.SetExpertMagicNumber(InpMagicNumber); // Define o magic number

    if (!trade.Buy(InpLotSize, Symbol(), price, sl, tp, expertName+"Tend. alta"))
        Print(expertName+"Erro ao abrir posição de compra: ", trade.ResultRetcodeDescription());
}

//+------------------------------------------------------------------+
//| Executa uma ordem de venda                                       |
//+------------------------------------------------------------------+
void ExecuteSell(double price)
{
    price = Normalize(price - InpSlippage * _Point);
    double sl = Normalize(price + InpStopLoss * _Point);
    double tp = Normalize(price - InpTakeProfit * _Point);
    trade.SetExpertMagicNumber(InpMagicNumber); // Define o magic number

    if (!trade.Sell(InpLotSize, Symbol(), price, sl, tp, expertName+"Tend. baixa"))
        Print(expertName+"Erro ao abrir posição de venda: ", trade.ResultRetcodeDescription());
}