void PullbackMovingAverageStrategy()
{
    // Garantindo que temos dados suficientes para análise
    if (ArraySize(bMAShortPB) < InpTimeWindowPB+1 ||
        ArraySize(bMAMediumPB) < InpTimeWindowPB+1 ||
        ArraySize(bMALongPB) < InpTimeWindowPB+1) 
    {
        //Print("Erro: Buffers de médias móveis não possuem dados suficientes.");
        return;
    }

    // Obtendo os valores mais recentes das médias móveis
    double shortMA = bMAShortPB[0];
    double mediumMA = bMAMediumPB[0];
    double longMA = bMALongPB[0];

    // Verificação de espaçamento entre médias para garantir tendência clara
    if (MathAbs(shortMA - mediumMA) < (mediumMA * InpMinDistSM/100) ||
        MathAbs(mediumMA - longMA) < (longMA * InpMinDistML/100) ||
        MathAbs(shortMA - longMA) < (longMA * InpMinDistSL/100)) 
    {
        return;
    }

    bool isUpTrend = shortMA > mediumMA && mediumMA > longMA;
    bool isDownTrend = shortMA < mediumMA && mediumMA < longMA;

    if (isUpTrend)
    {
        bool closeBelowShortMA = false;
        bool closeBelowLongMA = false;
        bool allAboveLongMA = true;

        // Analisando a janela de candles
        for (int i = InpTimeWindowPB; i >= 1; i--) 
        {
            double closePrice = iClose(_Symbol, InpTimeframe, i);

            if (closePrice < bMAShortPB[i]) closeBelowShortMA = true;
            if (closePrice < bMALongPB[i]) 
            {
                closeBelowLongMA = true;
                allAboveLongMA = false;
            }
        }

        // Confirmação do pullback
        if (closeBelowShortMA && !closeBelowLongMA && allAboveLongMA)
        {
            //Print("Pullback identificado na tendência de alta.");

            // Verificando o rompimento acima da MA curta no último candle
            if (iClose(_Symbol, InpTimeframe, 1) > bMAShortPB[1])
            {
                double entryPrice = iHigh(_Symbol, InpTimeframe, 1);
                double stopLoss = iLow(_Symbol, InpTimeframe, 1);
                double takeProfit = (entryPrice - stopLoss) * InpTPRatioPB;
                double tpPrice = entryPrice + takeProfit;
                tpPrice = Rounder(tpPrice);

                stopLossArray[PULLBACK] = Rounder(entryPrice - stopLoss);
                
                // Enviar ordem de compra
                BuyStopPrice(magicNumberArray[PULLBACK], InpLotSize, entryPrice, stopLoss, tpPrice, InpOrderExpiration, "Pullback Up");
            }
        }
    }
    else if (isDownTrend)
    {
        bool closeAboveShortMA = false;
        bool closeAboveLongMA = false;
        bool allBelowLongMA = true;

        // Analisando a janela de candles
        for (int i = InpTimeWindowPB; i >= 1; i--) 
        {
            double closePrice = iClose(_Symbol, InpTimeframe, i);

            if (closePrice > bMAShortPB[i]) closeAboveShortMA = true;
            if (closePrice > bMALongPB[i]) 
            {
                closeAboveLongMA = true;
                allBelowLongMA = false;
            }
        }

        // Confirmação do pullback
        if (closeAboveShortMA && !closeAboveLongMA && allBelowLongMA)
        {
            //Print("Pullback identificado na tendência de baixa.");

            // Verificando o rompimento abaixo da MA curta no último candle
            if (iClose(_Symbol, InpTimeframe, 1) < bMAShortPB[1])
            {
                double entryPrice = iLow(_Symbol, InpTimeframe, 1);
                double stopLoss = iHigh(_Symbol, InpTimeframe, 1);
                double takeProfit = (stopLoss - entryPrice) * InpTPRatioPB;
                double tpPrice = entryPrice - takeProfit;
                tpPrice = Rounder(tpPrice);
                
                stopLossArray[PULLBACK] = Rounder(stopLoss - entryPrice);

                // Enviar ordem de venda
                SellStopPrice(magicNumberArray[PULLBACK], InpLotSize, entryPrice, stopLoss, tpPrice, InpOrderExpiration, "Pullback Down");
            }
        }
    }
}
