//+------------------------------------------------------------------+
//|                                                      BollingerEA |
//|                        Versão simples com Bandas de Bollinger    |
//+------------------------------------------------------------------+



#include "../DefaultInputs.mqh"
#include "../DefaultFunctions.mqh"

input int BollingerBandsPeriod = 20;       // Período das Bandas de Bollinger
input double BollingerBandsDeviation = 2.0;  // Desvio padrão das Bandas de Bollinger
input bool UseDynamicTP = true;            // Usar TP dinâmico? TP na média do Bollinger ajustável a cada candle

// Handles para o indicador Bandas de Bollinger
int bbHandle;

// Buffers para armazenar os valores das Bandas de Bollinger
double upperBandBuffer[];
double middleBandBuffer[];
double lowerBandBuffer[];

//+------------------------------------------------------------------+
//| Função de inicialização do EA                                    |
//+------------------------------------------------------------------+
int OnInit()
{

    // Inicializa o handle para o indicador Bandas de Bollinger
    bbHandle = iBands(_Symbol, PERIOD_CURRENT, BollingerBandsPeriod, 0, BollingerBandsDeviation, PRICE_CLOSE);
    if (bbHandle == INVALID_HANDLE)
    {
        Print("Erro ao criar o handle para as Bandas de Bollinger.");
        return(INIT_FAILED);
    }

    // Define os buffers para os valores das Bandas de Bollinger
    ArraySetAsSeries(upperBandBuffer, true);
    ArraySetAsSeries(middleBandBuffer, true);
    ArraySetAsSeries(lowerBandBuffer, true);

    Print("EA inicializado com sucesso.");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Função de execução do EA                                         |
//+------------------------------------------------------------------+
void OnTick()
{
    
    CheckStopsSkippedAndCloseTrade(InpMagicNumber);
    
    // Cancela ordens velhas
    CancelOldPendingOrders(InpMagicNumber, InpOrderExpiration);

    // Aplica Trailing Stop se estiver ativado
    if (InpTrailingStop) MonitorTrailingStop(InpMagicNumber, InpStopLoss);
    
    // Copia os valores das Bandas de Bollinger para os buffers
    if (CopyBuffer(bbHandle, 1, 0, 3, upperBandBuffer) <= 0 ||
        CopyBuffer(bbHandle, 0, 0, 3, middleBandBuffer) <= 0 ||
        CopyBuffer(bbHandle, 2, 0, 3, lowerBandBuffer) <= 0)
    {
        Print("Erro ao copiar os dados das Bandas de Bollinger.");
        return;
    }
    
    if (UseDynamicTP) AdjustTP(InpMagicNumber, middleBandBuffer[0]);
    
    // Verifica a última negociação e envia e-mail se necessário
    CheckLastTradeAndSendEmail(InpMagicNumber);
    
    // Verifica se é um novo candle
    if (!isNewCandle()) return;
    
    // Verifica horário de funcionamento e fecha possições
    if (!CheckTradingTime(InpMagicNumber)) 
        return;
    
    // Verifica se já existe uma posição aberta pelo bot
    if (HasOpenPosition(InpMagicNumber))
        return;

    // Obtém o preço de fechamento do candle anterior
    double previousClose = iClose(NULL, 0, 1);

    // Lógica de entrada
    if (previousClose > upperBandBuffer[1]) // Fechou acima da Banda Superior: Venda
    {
        double tp = middleBandBuffer[0]; // TP na Banda Média
        ExecuteSellOrder(InpMagicNumber, InpLotSize, InpStopLoss, tp, "Acima da BSup");
    }
    else if (previousClose < lowerBandBuffer[1]) // Fechou abaixo da Banda Inferior: Compra
    {
        double tp = middleBandBuffer[0]; // TP na Banda Média
        ExecuteBuyOrder(InpMagicNumber, InpLotSize, InpStopLoss, tp, "Abaixo da BInf");
    }
}

// Função para ajustar o TP 
void AdjustTP(int magicNumber, double newTP) {
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

            // Verifica as condições para ajustar o TP
            if ((posType == POSITION_TYPE_BUY && newTP > positionPrice) ||
                (posType == POSITION_TYPE_SELL && newTP < positionPrice))
            {
                // Obtém o Stop Loss atual da posição
                double currentSL = PositionGetDouble(POSITION_SL);

                // Modifica o TP da posição
                if (!trade.PositionModify(ticket, currentSL, newTP))
                {
                    Print("Erro ao modificar TP da posição ", ticket, ": ", GetLastError());
                }
                else
                {
                    Print("TP da posição ", ticket, " ajustado para ", newTP);
                }
            }
        }
    }
}