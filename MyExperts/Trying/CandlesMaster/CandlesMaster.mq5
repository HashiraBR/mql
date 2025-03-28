//+------------------------------------------------------------------+
//|                                              CandlesMaster.mq5   |
//|                        Copyright © 2023, Danne M. G. Pereira     |
//|                              Email: makleyston@gmail.com         |
//|                              Site: www.aipi.com.br               |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2023, Danne M. G. Pereira"
#property link      "www.aipi.com.br"
#property version   "1.0"
#property description "CandlesMaster - Expert Advisor baseado em padrões de candles e médias móveis."
#property description " "
#property description "Funcionalidades:"
#property description "- Identifica padrões de candles como Marubozu, Doji, Estrela Cadente e Martelo."
#property description "- Opera com base em médias móveis e distâncias mínimas entre elas."
#property description "- Gerenciamento de risco com Stop Loss e Take Profit."
#property description "- Horário de negociação configurável."
#property description "- Envio de e-mails para notificações."
#property description " "
#property description "Recomendações:"
#property description "- Use, preferencialmente, no timeframe de M2."
#property description "- Ajuste os parâmetros de distância entre médias móveis conforme o ativo."
#property icon "\\Images\\CandlesMaster.ico" // Ícone personalizado (opcional)
#property script_show_inputs

#include "../DefaultFunctions.mqh"

// Horário de Negociação
input int      InpStartHour = 9;               // Hora de início das negociações (formato 24h)
input int      InpStartMinute = 0;             // Minuto de início das negociações
input int      InpEndHour = 17;                // Hora de término das negociações (formato 24h)
input int      InpEndMinute = 0;               // Minuto de término das negociações
input int      InpCloseAfterMinutes = 20;      // Encerrar posições após parar de operar (minutos)

// Identificação e Controle
input int      InpMagicNumber = 123456;         // Número mágico para identificar as ordens do bot
input bool     InpSendEmail = true;             // Habilitar envio de e-mails
input bool     InpSendPushNotification = true;  // Habilitar envio de Push Notification
input int      InpOrderExpiration = 60;         // Tempo de expiração da ordem (em segundos)
input bool     InpTrailingStop = true;          // Tipo de Stop Loss (true = móvel, false = fixo)

// Configurações Técnicas
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M2; // Timeframe do gráfico

// Configurações de Saída com Padrão de Indecisão
input bool     InpExitOnIndecision = false;     // Sair com padrão de indecisão (doji e spinning)

// Configurações de Médias Móveis
input int      InpMAShortPeriod = 9;           // Período da Média Móvel Curta
input int      InpMAMediumPeriod = 17;         // Período da Média Móvel Média
input int      InpMALongPeriod = 100;          // Período da Média Móvel Longa

// Distâncias Mínimas entre Médias Móveis (em porcentagem)
input double   InpMinDistanceShortMedium = 0.06; // Distância mínima entre curta e média (%)
input double   InpMinDistanceMediumLong = 0.06;  // Distância mínima entre média e longa (%)
input double   InpMinDistanceShortLong = 0.06;   // Distância mínima entre curta e longa (%)

input int InpXCandles = 2;                      // Qt candles para cálculo de média de vol.

enum CandlePattern {
    PATTERN_NONE,
    PATTERN_DOJI,
    PATTERN_MARUBOZU_GREEN,
    PATTERN_MARUBOZU_RED,
    PATTERN_SHOOTING_STAR,
    PATTERN_SPINNING_TOP,
    PATTERN_HAMMER,
};

string CandlePatternNames[] = {
    "NONE",
    "DOJI",
    "MARUBOZU_GREEN",
    "MARUBOZU_RED",
    "SHOOTING_STAR",
    "SPINNING_TOP",
    "HAMMER"
};

// Estrutura para configurar cada padrão de candle
struct PatternConfig {
    bool enabled;               // Se o padrão está habilitado
    int magicNumber;            // MagicNumber específico para o padrão
    int variationHigh;          // Variação mínima do candle (pontos)
    double lotSize;             // Tamanho do lote
    double stopLoss;            // Stop loss em pontos
    double takeProfit;          // Take profit em pontos
};

input string space1 = "#################### Marubozu Verde ####################"; // #################### Marubozu Verde ####################

// Inputs para cada padrão de candle
// Configurações do padrão Marubozu Verde
input bool PATTERN_MARUBOZU_GREEN_Enabled = true; // Habilita/desabilita o padrão Marubozu Verde
input int PATTERN_MARUBOZU_GREEN_MagicNumber = 1001; // Número mágico
input int PATTERN_MARUBOZU_GREEN_VariationHigh = 150; // Variação mínima do candle (em pontos) 
input double PATTERN_MARUBOZU_GREEN_LotSize = 1.0; // Tamanho do lote para operações 
input double PATTERN_MARUBOZU_GREEN_StopLoss = 50; // Stop Loss em pontos
input double PATTERN_MARUBOZU_GREEN_TakeProfit = 100; // Take Profit em pontos

input string space2 = "#################### Marubozu Vermelho ####################"; // #################### Marubozu Vermelho ####################

// Configurações do padrão Marubozu Vermelho
input bool PATTERN_MARUBOZU_RED_Enabled = true; // Habilita/desabilita o padrão Marubozu Vermelho
input int PATTERN_MARUBOZU_RED_MagicNumber = 1002; // Número mágico
input int PATTERN_MARUBOZU_RED_VariationHigh = 150; // Variação mínima do candle (em pontos) 
input double PATTERN_MARUBOZU_RED_LotSize = 1.0; // Tamanho do lote para operações
input double PATTERN_MARUBOZU_RED_StopLoss = 50; // Stop Loss em pontos para operações
input double PATTERN_MARUBOZU_RED_TakeProfit = 100; // Take Profit em pontos

input string space3 = "#################### Estrela Cadente ####################"; // #################### Estrela Cadente ####################

// Configurações do padrão Estrela Cadente (Shooting Star)
input bool PATTERN_SHOOTING_STAR_Enabled = true; // Habilita/desabilita o padrão Estrela Cadente
input int PATTERN_SHOOTING_STAR_MagicNumber = 1003; // Número mágico 
input int PATTERN_SHOOTING_STAR_VariationHigh = 150; // Variação mínima do candle (em pontos)
input double PATTERN_SHOOTING_STAR_LotSize = 1.0; // Tamanho do lote para operações 
input double PATTERN_SHOOTING_STAR_StopLoss = 50; // Stop Loss em pontos
input double PATTERN_SHOOTING_STAR_TakeProfit = 100; // Take Profit em pontos

input string space4 = "#################### Martelo ####################"; // #################### Martelo ####################

// Configurações do padrão Martelo (Hammer)
input bool PATTERN_HAMMER_Enabled = true; // Habilita/desabilita o padrão Martelo
input int PATTERN_HAMMER_MagicNumber = 1004; // Número mágico 
input int PATTERN_HAMMER_VariationHigh = 150; // Variação mínima do candle (em pontos) 
input double PATTERN_HAMMER_LotSize = 1.0; // Tamanho do lote para operações 
input double PATTERN_HAMMER_StopLoss = 50; // Stop Loss em pontos 
input double PATTERN_HAMMER_TakeProfit = 100; // Take Profit em pontos 


// Array para armazenar as configurações de cada padrão
PatternConfig patternConfigs[7];

bool isProximityWarningPrinted = false;
bool isDistanceInfoPrinted = false;
int shortMAHandle, mediumMAHandle, longMAHandle;
double minDistanceShortLong, minDistanceMediumLong, minDistanceShortMedium;
double shortMABuffer[], mediumMABuffer[], longMABuffer[];


int OnInit() {
    // Inicializa as configurações dos padrões
    patternConfigs[PATTERN_MARUBOZU_GREEN].enabled = PATTERN_MARUBOZU_GREEN_Enabled;
    patternConfigs[PATTERN_MARUBOZU_GREEN].magicNumber = PATTERN_MARUBOZU_GREEN_MagicNumber;
    patternConfigs[PATTERN_MARUBOZU_GREEN].variationHigh = PATTERN_MARUBOZU_GREEN_VariationHigh;
    patternConfigs[PATTERN_MARUBOZU_GREEN].lotSize = PATTERN_MARUBOZU_GREEN_LotSize;
    patternConfigs[PATTERN_MARUBOZU_GREEN].stopLoss = PATTERN_MARUBOZU_GREEN_StopLoss;
    patternConfigs[PATTERN_MARUBOZU_GREEN].takeProfit = PATTERN_MARUBOZU_GREEN_TakeProfit;

    patternConfigs[PATTERN_MARUBOZU_RED].enabled = PATTERN_MARUBOZU_RED_Enabled;
    patternConfigs[PATTERN_MARUBOZU_RED].magicNumber = PATTERN_MARUBOZU_RED_MagicNumber;
    patternConfigs[PATTERN_MARUBOZU_RED].variationHigh = PATTERN_MARUBOZU_RED_VariationHigh;
    patternConfigs[PATTERN_MARUBOZU_RED].lotSize = PATTERN_MARUBOZU_RED_LotSize;
    patternConfigs[PATTERN_MARUBOZU_RED].stopLoss = PATTERN_MARUBOZU_RED_StopLoss;
    patternConfigs[PATTERN_MARUBOZU_RED].takeProfit = PATTERN_MARUBOZU_RED_TakeProfit;

    patternConfigs[PATTERN_SHOOTING_STAR].enabled = PATTERN_SHOOTING_STAR_Enabled;
    patternConfigs[PATTERN_SHOOTING_STAR].magicNumber = PATTERN_SHOOTING_STAR_MagicNumber;
    patternConfigs[PATTERN_SHOOTING_STAR].variationHigh = PATTERN_SHOOTING_STAR_VariationHigh;
    patternConfigs[PATTERN_SHOOTING_STAR].lotSize = PATTERN_SHOOTING_STAR_LotSize;
    patternConfigs[PATTERN_SHOOTING_STAR].stopLoss = PATTERN_SHOOTING_STAR_StopLoss;
    patternConfigs[PATTERN_SHOOTING_STAR].takeProfit = PATTERN_SHOOTING_STAR_TakeProfit;

    patternConfigs[PATTERN_HAMMER].enabled = PATTERN_HAMMER_Enabled;
    patternConfigs[PATTERN_HAMMER].magicNumber = PATTERN_HAMMER_MagicNumber;
    patternConfigs[PATTERN_HAMMER].variationHigh = PATTERN_HAMMER_VariationHigh;
    patternConfigs[PATTERN_HAMMER].lotSize = PATTERN_HAMMER_LotSize;
    patternConfigs[PATTERN_HAMMER].stopLoss = PATTERN_HAMMER_StopLoss;
    patternConfigs[PATTERN_HAMMER].takeProfit = PATTERN_HAMMER_TakeProfit;

    // Verifica o número de barras disponíveis
    int availableBars = Bars(Symbol(), InpTimeframe);
    if (availableBars < InpMALongPeriod) {
        Print(expertName + "Erro: Dados insuficientes para calcular médias móveis. Bars disponíveis: ", availableBars);
        return INIT_FAILED;
    }

    // Cria os handles dos indicadores de média móvel
    shortMAHandle = iMA(Symbol(), InpTimeframe, InpMAShortPeriod, 0, MODE_SMA, PRICE_CLOSE);
    mediumMAHandle = iMA(Symbol(), InpTimeframe, InpMAMediumPeriod, 0, MODE_SMA, PRICE_CLOSE);
    longMAHandle = iMA(Symbol(), InpTimeframe, InpMALongPeriod, 0, MODE_SMA, PRICE_CLOSE);

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
    
    return(INIT_SUCCEEDED);
}

void OnTick() {
    // Loop sobre todos os padrões habilitados
    for (int i = 0; i < ArraySize(patternConfigs); i++) {
        if (patternConfigs[i].enabled) {
            
            CheckStopsSkippedAndCloseTrade(patternConfigs[i].magicNumber);
        
            // 1) Cancela ordens velhas para o MagicNumber específico
            CancelOldPendingOrders(patternConfigs[i].magicNumber, InpOrderExpiration);

            // 2) Aplica Trailing Stop se estiver ativado
            if (InpTrailingStop) {
                MonitorTrailingStop(patternConfigs[i].magicNumber, patternConfigs[i].stopLoss);
            }

            // 3) Verifica a última negociação e envia e-mail se necessário
            CheckLastTradeAndSendEmail(patternConfigs[i].magicNumber);
        }
    }

    // 4) Verifica se é um novo candle
    if (!isNewCandle()) return;

    // 5.1) Obtenha os dados do último candle
    double open = iOpen(_Symbol, _Period, 1);
    double high = iHigh(_Symbol, _Period, 1);
    double low = iLow(_Symbol, _Period, 1);
    double close = iClose(_Symbol, _Period, 1);
    
    // 10) Coleta dos dados das médias móveis
    double shortMA, mediumMA, longMA;
    if (!CalculateMovingAverages(shortMA, mediumMA, longMA)) return;

    // Loop sobre todos os padrões habilitados para verificar e operar
    for (int i = 0; i < ArraySize(patternConfigs); i++) {
        if (patternConfigs[i].enabled) {
            // 5.2) Identifique o padrão com a variação específica do padrão
            CandlePattern pattern = IdentifyPattern(open, high, low, close, patternConfigs[i].variationHigh);

            // 6) Verifica se deve sair da operação com padrões de indecisão
            if (InpExitOnIndecision && ShouldExitTrade(pattern)) {
                ClosePositionWithMagicNumber(patternConfigs[i].magicNumber);
            }

            // 7) Verifica horário de funcionamento
            if (!CheckTradingTime(patternConfigs[i].magicNumber)) continue;

            // 8) Verifica se já existe uma posição aberta para o MagicNumber específico
            if (HasOpenPosition(patternConfigs[i].magicNumber)) {
                continue; // Pula para o próximo padrão se já houver uma posição aberta
            }

            // 9) Verifica o volume dos candles passados
            bool isVolumeHigh = IsVolumeAboveAverage();

            // 11) Verifica se deve operar com base no padrão identificado
            if (pattern == i && isVolumeHigh) {
                if (isBuySinal(pattern, shortMA, mediumMA, longMA) && close > longMA) {
                    ExecuteBuyOrder(
                     patternConfigs[i].magicNumber,  
                     patternConfigs[i].lotSize,  
                     patternConfigs[i].stopLoss,  
                     patternConfigs[i].takeProfit,  
                     "UP+" + GetCandlePatternName(pattern)
                    );
                } else if (isSellSinal(pattern, shortMA, mediumMA, longMA) && close < longMA) {
                    ExecuteSellOrder(
                     patternConfigs[i].magicNumber,
                     patternConfigs[i].lotSize,  
                     patternConfigs[i].stopLoss,  
                     patternConfigs[i].takeProfit,   
                     "DOWN+" + GetCandlePatternName(pattern)
                    );
                }
            }
        }
    }
}

bool isBuySinal(CandlePattern pattern, double shortMA, double mediumMA, double longMA)
{
    if(shortMA > mediumMA && mediumMA > longMA)
         if(pattern == PATTERN_MARUBOZU_GREEN || pattern == PATTERN_HAMMER)
             return true;
    return false;
}

bool isSellSinal(CandlePattern pattern, double shortMA, double mediumMA, double longMA)
{
   if(shortMA < mediumMA && mediumMA < longMA)
         if(pattern == PATTERN_MARUBOZU_RED || pattern == PATTERN_SHOOTING_STAR)
             return true;
    return false;
}

//+------------------------------------------------------------------+
CandlePattern IdentifyPattern(double open, double high, double low, double close, int variationHigh) {
    double bodySize = MathAbs(close - open);
    double totalRange = high - low;

    // Doji
    if (bodySize <= 1 * _Point && totalRange >= variationHigh * _Point) return PATTERN_DOJI;
    
    // Hammer (Só estou considerando o martelo verde, pois só vou operar na alta e esse padrão é mais confiável)
    if ((close > open) && (totalRange > (2 * bodySize)) && ((high - close) <= 10 * _Point)  && (totalRange >= variationHigh * _Point)) 
        return PATTERN_HAMMER;

    // Marubozu
    if ((close > open) && (bodySize > (totalRange * 0.8)) && (totalRange >= variationHigh * _Point)) 
        return PATTERN_MARUBOZU_GREEN;
    if ((close < open) && (bodySize > (totalRange * 0.8)) && (totalRange >= variationHigh * _Point)) 
        return PATTERN_MARUBOZU_RED;

    // Shooting Star (Só estou considerando a estrela vermelha, pois só vou operar na queda e esse padrão é mais confiável)
    if ((close < open) && (totalRange > (2 * bodySize)) && ((close - low) <= 10 * _Point)  && (totalRange >= variationHigh * _Point)) 
        return PATTERN_SHOOTING_STAR;

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

bool CalculateMovingAverages(double &shortMA, double &mediumMA, double &longMA) {
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

//+------------------------------------------------------------------+
//| Funções de Execução de Ordens                                    |
//+------------------------------------------------------------------+

bool ShouldExitTrade(CandlePattern pattern) {
    if (pattern == PATTERN_DOJI || pattern == PATTERN_SHOOTING_STAR) 
        return true;
    return false;
}

bool IsVolumeAboveAverage() {
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