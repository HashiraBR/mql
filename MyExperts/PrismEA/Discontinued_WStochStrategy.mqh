
//+------------------------------------------------------------------+
//| Função para verificar condições de negociação                    |
//+------------------------------------------------------------------+
void CheckForTradeWStoch()
{
    //int maginNumber = (InpMagicNumber == 0? InpMagicNumberWStoch : InpMagicNumber);

    // Obter os valores do Stochástico
    double stochMain = stochMainArray[0];  // %K
    double stochSignal = stochSignalArray[0]; // %D
    
    double lastClose = iClose(_Symbol, InpTimeframe, 1);
    
    /*
    Geralmente é:
    emaValueDT_Period < emaLongValueDT_Period < maValue_Period
    */
    
    double margin = 20;
    // Verifica a tendência
    //bool isUptrend = emaValueDT[0] > emaLongValueDT[0] > maValue[0] && lastClose > maValue[0] + margin * _Point;
    //bool isDowntrend = emaValueDT[0] < emaLongValueDT[0] < maValue[0] && lastClose < maValue[0] + margin * _Point;
    bool isUptrend = lastClose > maValue[0] + margin * _Point;
    bool isDowntrend = lastClose < maValue[0] + margin * _Point;

   
    double tp = InpTakeProfit;
    if(InpTPType == RISK_REWARD)
       tp = Rounder(InpStopLoss * InpTPRiskReward);

    // Lógica de entrada (compra/venda)
    if (isUptrend && CheckBuyCondition(stochMain, stochSignal))
    {
        BuyMarketPoint(InpMagicNumber, InpLotSize, InpStopLoss, tp, "Setup W");
    }
    if (isDowntrend && CheckSellCondition(stochMain, stochSignal))
    {
        SellMarketPoint(InpMagicNumber, InpLotSize, InpStopLoss, tp, "Setup M");
    }
    
}


//+------------------------------------------------------------------+
//| Funções de Verificação de Condições                              |
//+------------------------------------------------------------------+

bool CheckBuyCondition(double stochMain, double stochSignal)
{
    // Verifica se o Stochástico ultrapassou 50%
    if (stochMain >= 50.0)
    {
        flagZonaBaixa_Stoch = false; // Limpa o buffer
        stochZonaBaixa_Stoch = false; // Reseta para próxima verificação
        candleCountAfterFirstEntry = 0; // Reseta o contador de candles
    }

    // Verifica se o Stochástico está abaixo da zona baixa
    if (stochMain < InpStochasticLowLevel)
    {
        if (!stochZonaBaixa_Stoch)
        {
            stochZonaBaixa_Stoch = true; // Marca que entrou na zona baixa
        }
    }
    // Verifica se o Stochástico saiu da zona baixa
    else if (stochZonaBaixa_Stoch && stochMain > InpStochasticLowLevel && !flagZonaBaixa_Stoch)
    {
        flagZonaBaixa_Stoch = true; // Ativa a flag
        stochZonaBaixa_Stoch = false; // Reseta para próxima verificação
        candleCountAfterFirstEntry += 1; // Inicia o contador de candles
    }

    // Verifica se entrou novamente na zona baixa após a flag estar ativa
    if (stochZonaBaixa_Stoch && flagZonaBaixa_Stoch)
    {
        // Verifica o cruzamento para sinal de compra
        if (candleCountAfterFirstEntry <= InpCandlesBetweenEntriesStoch && stochMain > stochSignal)
        {
            //Print(expertName+"Segunda entrada na zona de baixa; limite de candles <= " + IntegerToString(InpCandlesBetweenEntries) + "; stoch > média;");
            flagZonaBaixa_Stoch = false; // Reseta a flag após o sinal
            stochZonaBaixa_Stoch = false; // Reseta para próxima verificação
            candleCountAfterFirstEntry = 0;
            return true; // Sinal de compra
        }
    }
    return false; // Sem sinal de compra
}

bool CheckSellCondition(double stochMain, double stochSignal)
{
    // Verifica se o Stochástico caiu abaixo de 50%
    if (stochMain <= 50.0)
    {
        flagZonaAlta_Stoch = false; // Limpa o buffer
        stochZonaAlta_Stoch = false; // Reseta para próxima verificação
        candleCountAfterFirstEntry = 0;
    }

    // Verifica se o Stochástico está acima da zona alta
    if (stochMain > InpStochasticHighLevel)
    {
        if (!stochZonaAlta_Stoch)
        {
            stochZonaAlta_Stoch = true; // Marca que entrou na zona alta
        }
    }
    // Verifica se o Stochástico saiu da zona alta
    else if (stochZonaAlta_Stoch && stochMain < InpStochasticHighLevel && !flagZonaAlta_Stoch)
    {
        flagZonaAlta_Stoch = true; // Ativa a flag
        stochZonaAlta_Stoch = false; // Reseta para próxima verificação
        candleCountAfterFirstEntry += 1;
    }

    // Verifica se entrou novamente na zona alta após a flag estar ativa
    if (stochZonaAlta_Stoch && flagZonaAlta_Stoch)
    {
        // Verifica o cruzamento para sinal de venda
        if (candleCountAfterFirstEntry <= InpCandlesBetweenEntriesStoch && stochMain < stochSignal)
        {
            //Print(expertName+"Segunda entrada na zona de alta; limite de candles <= " + IntegerToString(InpCandlesBetweenEntries) + "; stoch < média;");
            flagZonaAlta_Stoch = false; // Reseta a flag após o sinal
            stochZonaAlta_Stoch = false; // Reseta para próxima verificação
            candleCountAfterFirstEntry = 0;
            return true; // Sinal de venda
        }
    }
    return false; // Sem sinal de compra
}
