//+------------------------------------------------------------------+
//|                                            MyLerryWilliams.mq5   |
//|                        Copyright © 2023, Danne M. G. Pereira     |
//|                              Email: makleyston@gmail.com         |
//|                              Site: www.aipi.com.br               |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2023, Danne M. G. Pereira"
#property link      "www.aipi.com.br"
#property version   "1.0"
#property description "MyLerryWilliams - EA baseado em 3 médias móveis para identificar tendências e gerar sinais de compra/venda."
#property description " "
#property description "Funcionalidades:"
#property description "- Usa 3 médias móveis (curta, média e longa) para definir tendência."
#property description "- Entrada na direção da tendência com base no alinhamento das médias."
#property description "- Saída quando as médias curta e média se cruzam no sentido de reversão."
#property description "- Gerenciamento de risco com Stop Loss."
#property description " "
#property description "Recomendações:"
#property description "- Use, preferencialmente, no timeframe de M2."
#property icon "\\Images\\TrendWaveMaster.ico" // Ícone personalizado (opcional)
#property script_show_inputs

#include "../DefaultInputs.mqh"
#include "../DefaultFunctions.mqh"

//+------------------------------------------------------------------+
//| Inputs do Expert Advisor                                         |
//+------------------------------------------------------------------+

// Configurações das Médias Móveis
input int      InpShortMAPeriod = 7;           // Período da Média Curta
input int      InpMediumMAPeriod = 20;         // Período da Média Média
input int      InpLongMAPeriod = 200;          // Período da Média Longa
input ENUM_MA_METHOD InpMAType = MODE_EMA;     // Tipo de Média Móvel (SMA, EMA, etc.)

// Distâncias Mínimas entre as Médias
input double   InpMinDistanceShortMedium = 1.0; // Distância mínima entre Short e Medium MA (%)
input double   InpMinDistanceMediumLong = 2.0;  // Distância mínima entre Medium e Long MA (%)
input double   InpMinDistanceShortLong = 3.0;   // Distância mínima entre Short e Long MA (%)

input int InpEMAHighPeriod = 6; // Períodos para a EMA das máximas
input int InpEMALowPeriod = 6;  // Períodos para a EMA das mínimas

input bool exitOnMACross = true; // Encerrar posição no cruz. das MAs
input int InpMAExitPeriod = 4;  // Períodos para a EMA do exit
input bool InpSLOnMAMedium = false; // SL dinâmico na MA médio

// Handles para as Médias Móveis
int shortMAHandle;    // Handle para a Média Curta
int mediumMAHandle;   // Handle para a Média Média
int longMAHandle;     // Handle para a Média Longa
int emaHighHandle;    // Handle para a EMA das Máximas
int emaLowHandle;     // Handle para a EMA das Mínimas
int maExitHandle;     // Handle para a MA do exit

//+------------------------------------------------------------------+
//| Função de Inicialização dos Indicadores                          |
//+------------------------------------------------------------------+
int InitializeIndicators() {
    // Inicializa as Médias Móveis
    shortMAHandle = iMA(_Symbol, _Period, InpShortMAPeriod, 0, InpMAType, PRICE_CLOSE);
    mediumMAHandle = iMA(_Symbol, _Period, InpMediumMAPeriod, 0, InpMAType, PRICE_CLOSE);
    longMAHandle = iMA(_Symbol, _Period, InpLongMAPeriod, 0, InpMAType, PRICE_CLOSE);

    // Inicializa as EMAs das Máximas e Mínimas
    emaHighHandle = iMA(_Symbol, _Period, InpEMAHighPeriod, 0, MODE_EMA, PRICE_HIGH);
    emaLowHandle = iMA(_Symbol, _Period, InpEMALowPeriod, 0, MODE_EMA, PRICE_LOW);
    
    maExitHandle = iMA(_Symbol, _Period, InpMAExitPeriod, 0, InpMAType, PRICE_CLOSE);

    // Verifica se os handles foram criados corretamente
    if (shortMAHandle == INVALID_HANDLE || mediumMAHandle == INVALID_HANDLE || longMAHandle == INVALID_HANDLE ||
        emaHighHandle == INVALID_HANDLE || emaLowHandle == INVALID_HANDLE || maExitHandle == INVALID_HANDLE) {
        Print("Erro ao criar os handles dos indicadores");
        return INIT_FAILED;
    }
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Função de Inicialização do EA                                    |
//+------------------------------------------------------------------+
int OnInit() {
    return InitializeIndicators();
}

//+------------------------------------------------------------------+
//| Função de Desinicialização do EA                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    IndicatorRelease(shortMAHandle);
    IndicatorRelease(mediumMAHandle);
    IndicatorRelease(longMAHandle);
    IndicatorRelease(emaHighHandle);
    IndicatorRelease(emaLowHandle);
    IndicatorRelease(maExitHandle);
}

//+------------------------------------------------------------------+
//| Função Principal (OnTick)                                        |
//+------------------------------------------------------------------+
void OnTick() {

    CheckStopsSkippedAndCloseTrade(InpMagicNumber);
   
    // Cancela ordens velhas
    CancelOldPendingOrders(InpMagicNumber, InpOrderExpiration);
    
    // Aplica Trailing Stop se estiver ativado
    if (InpTrailingStop) MonitorTrailingStop(InpMagicNumber, InpStopLoss);

    // Verifica a última negociação e envia e-mail se necessário
    CheckLastTradeAndSendEmail(InpMagicNumber);
    
    // Verifica se é um novo candle
    if (!isNewCandle()) return;
       
    if(InpSLOnMAMedium) AdjustSL(InpMagicNumber, GetMAValue(mediumMAHandle));
       
    // Verifica se há posições abertas
    if (HasOpenPosition(InpMagicNumber)) {
        if(exitOnMACross)
            CheckForExitSignal(); // Verifica se é hora de sair
            return;
    }
   
    // Verifica horário de funcionamento e fecha possições
    if (!CheckTradingTime(InpMagicNumber)) 
        return;

    // Verifica se as médias estão suficientemente distantes
    if (!CheckMADistances()) return;

    // Define a tendência e gera sinal de entrada
    CheckForEntrySignal();
}


void AdjustSL(int magicNumber, double mediumMA) {
    // Itera sobre todas as posições abertas
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        // Obtém o ticket da posição
        ulong ticket = PositionGetTicket(i);
        if (ticket <= 0) {
            Print("Erro ao obter o ticket da posição ", i);
            continue; // Pula para a próxima posição
        }

        // Verifica se a posição pertence a este EA (pelo Magic Number)
        if (PositionGetInteger(POSITION_MAGIC) == magicNumber) {
            // Obtém o tipo da posição (comprada ou vendida)
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

            // Obtém o preço de abertura da posição
            double positionPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentSL = PositionGetDouble(POSITION_SL);
            double currentTP = PositionGetDouble(POSITION_TP);

            // Ajusta o SL para compras
            if (posType == POSITION_TYPE_BUY) {
                double newSL = mediumMA; // SL dinâmico para compras
                if (newSL > currentSL && newSL < positionPrice) { // Apenas ajusta se for mais favorável
                    trade.PositionModify(ticket, newSL, currentTP);
                }
            }
            // Ajusta o SL para vendas
            else if (posType == POSITION_TYPE_SELL) {
                double newSL = mediumMA; // SL dinâmico para vendas
                if (newSL < currentSL && newSL > positionPrice) { // Apenas ajusta se for mais favorável
                    trade.PositionModify(ticket, newSL, currentTP);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Verifica as Distâncias entre as Médias                           |
//+------------------------------------------------------------------+
bool CheckMADistances() {
    double shortMA = GetMAValue(shortMAHandle);
    double mediumMA = GetMAValue(mediumMAHandle);
    double longMA = GetMAValue(longMAHandle);

    double minDistanceShortMedium = InpMinDistanceShortMedium / 100.0;
    double minDistanceMediumLong = InpMinDistanceMediumLong / 100.0;
    double minDistanceShortLong = InpMinDistanceShortLong / 100.0;

    if (MathAbs(shortMA - mediumMA) < (mediumMA * minDistanceShortMedium) ||
        MathAbs(mediumMA - longMA) < (longMA * minDistanceMediumLong) ||
        MathAbs(shortMA - longMA) < (longMA * minDistanceShortLong)) {
        //Print("Médias móveis estão muito próximas. Aguardando distância mínima.");
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Verifica o Sinal de Entrada                                      |
//+------------------------------------------------------------------+
void CheckForEntrySignal() {
    double shortMA = GetMAValue(shortMAHandle);
    double mediumMA = GetMAValue(mediumMAHandle);
    double longMA = GetMAValue(longMAHandle);

    double lastClose = iClose(NULL, _Period, 1);  // Último preço de fechamento
    double emaHigh = GetMAValue(emaHighHandle);   // EMA das máximas
    double emaLow = GetMAValue(emaLowHandle);     // EMA das mínimas

    // Tendência de Alta: Short MA > Medium MA > Long MA
    if (shortMA > mediumMA && mediumMA > longMA) {
        // Compra quando o preço toca ou ultrapassa a EMA das mínimas (suporte dinâmico)
        if (lastClose <= emaLow) {
            ExecuteBuyOrder(InpMagicNumber, InpLotSize, InpStopLoss, InpTakeProfit, "Tendência de Alta: Preço <= EMA Low");
        }
    }
    // Tendência de Baixa: Short MA < Medium MA < Long MA
    else if (shortMA < mediumMA && mediumMA < longMA) {
        // Venda quando o preço toca ou ultrapassa a EMA das máximas (resistência dinâmica)
        if (lastClose >= emaHigh) {
            ExecuteSellOrder(InpMagicNumber, InpLotSize, InpStopLoss, InpTakeProfit, "Tendência de Baixa: Preço >= EMA High");
        }
    }
}

//+------------------------------------------------------------------+
//| Verifica o Sinal de Saída                                        |
//+------------------------------------------------------------------+
void CheckForExitSignal() {
    //double shortMA = GetMAValue(shortMAHandle);
    double exitMA = GetMAValue(maExitHandle);
    double mediumMA = GetMAValue(mediumMAHandle);

    // Fechar Compra: Short MA cruza abaixo da Medium MA
    if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && exitMA < mediumMA) {
        ClosePositionWithMagicNumber(InpMagicNumber);
    }
    // Fechar Venda: Short MA cruza acima da Medium MA
    else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && exitMA > mediumMA) {
        ClosePositionWithMagicNumber(InpMagicNumber);
    }
}

//+------------------------------------------------------------------+
//| Função para Obter o Valor de uma Média Móvel                     |
//+------------------------------------------------------------------+
double GetMAValue(int handle, int shift = 0) {
    double maValue[1];
    if (CopyBuffer(handle, 0, shift, 1, maValue) == 1) {
        return maValue[0];
    }
    return -1; // Retorna -1 em caso de erro
}