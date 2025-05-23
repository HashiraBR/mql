void TrendAccelerationStrategy()

{   double factor = InpMinDisMATrenA;
    double maShort = bMAShortTrendA[0];       // Valor da MA curta no último candle fechado (índice 1)
    double maShortBefore = bMAShortTrendA[1]; // Valor da MA curta no candle antes do último (índice 2)
    double maLong = bMALongTrendA[0];         // Valor da MA longa no último candle fechado (índice 1)
    double trueRange = bTrueRange[0];         // Valor do True Range no último candle fechado (índice 1)
    double smoothedTrueRange = bSmoothedTrueRange[0]; // Valor do True Range suavizado no último candle fechado (índice 1)

    // Tendência ascendente
    if (maShort > maLong && maShort > maShortBefore * (1 + factor/100))
    {
        // Obtém as mínimas dos dois últimos candles fechados
        double lastLow = iLow(_Symbol, InpTimeframe, 1); // Mínima do último candle fechado (índice 1)
        double secondLastLow = iLow(_Symbol, InpTimeframe, 2); // Mínima do candle antes do último (índice 2)
        
        //Print("lastLow: ", lastLow, " - secondLastLow: ", secondLastLow,   " - maShort: ", maShort, " - maShortBefore: ", maShortBefore, " - maLong: ", maLong);

        // Verifica se a mínima do último candle fechado está acima da MA curta
        if (lastLow > maShort)
        {
            // Preço de entrada: mínima entre os dois últimos candles fechados
            double entryPrice = MathMin(lastLow, secondLastLow);

            double stopLoss = smoothedTrueRange * InpSLFactorTrendA * _Point;
            // Arredondar o valor para o múltiplo mais próximo de 5 pontos
            stopLoss = MathRound(stopLoss / (5 * _Point)) * (5 * _Point);
            
            double takeProfit = stopLoss * InpTPRatioTrendA;
            // Ajustar também para múltiplo de 5 pontos
            takeProfit = MathRound(takeProfit / (5 * _Point)) * (5 * _Point);
            
            stopLossArray[TREND] = stopLoss;

            // Envia a ordem de compra pendente
            BuyLimitPrice(magicNumberArray[TREND], entryPrice, InpLotSize, entryPrice - stopLoss, entryPrice + takeProfit, InpOrderExpiration, "StrongUp");
        }
    }
    // Tendência descendente
    else if (maShort < maLong && maShort < maShortBefore * (1 - factor/100))
    {
        // Obtém as máximas dos dois últimos candles fechados
        double lastHigh = iHigh(_Symbol, InpTimeframe, 1); // Máxima do último candle fechado (índice 1)
        double secondLastHigh = iHigh(_Symbol, InpTimeframe, 2); // Máxima do candle antes do último (índice 2)

        // Verifica se a máxima do último candle fechado está abaixo da MA curta
        if (lastHigh < maShort)
        {
            // Preço de entrada: máxima entre os dois últimos candles fechados
            double entryPrice = MathMax(lastHigh, secondLastHigh);

            // Calcula SL e TP
            double stopLoss = smoothedTrueRange * InpSLFactorTrendA * _Point;
            // Arredondar o valor para o múltiplo mais próximo de 5 pontos
            stopLoss = MathRound(stopLoss / (5 * _Point)) * (5 * _Point);
            
            double takeProfit = stopLoss * InpTPRatioTrendA;
            // Ajustar também para múltiplo de 5 pontos
            takeProfit = MathRound(takeProfit / (5 * _Point)) * (5 * _Point);
            
            stopLossArray[TREND] = stopLoss;

            // Envia a ordem de venda pendente
            SellLimitPrice(magicNumberArray[TREND], entryPrice, InpLotSize, entryPrice + stopLoss, entryPrice - takeProfit, InpOrderExpiration, "StrongDown");
        }
    }
}