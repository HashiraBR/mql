void OutsideBarTrendStrategy()
{
    // Obtém os valores da MA longa e do RSI
    double longMA = bMALongOut[0];
    double rsi = bRSIOut[0];
    double lastClose = iClose(_Symbol, InpTimeframe, 1);
    double lastOpen = iOpen(_Symbol, InpTimeframe, 1);
    double lastHigh = iHigh(_Symbol, InpTimeframe, 1);
    double lastLow = iLow(_Symbol, InpTimeframe, 1);
    
    double secondLastClose = iClose(_Symbol, InpTimeframe, 2);
    double secondLastOpen = iOpen(_Symbol, InpTimeframe, 2);
    double secondLastHigh = iHigh(_Symbol, InpTimeframe, 2);
    double secondLastLow = iLow(_Symbol, InpTimeframe, 2);
    
    // Verifica se o último candle é um outside bar
    bool isOutsideBar = (lastHigh > secondLastHigh && lastLow < secondLastLow);
    
    // Verifica o corpo do candle
    double body = MathAbs(lastOpen - lastClose);
    double variation = MathAbs(lastLow - lastHigh);
    bool isFullBody = (body >= variation * InpBodySizeBarOut); //50% da barra deve ser corpo
    
    // Verifica a tendência (preço acima da MA longa e RSI > 50)
    if (lastClose > longMA && rsi > 50)
    {
        // Verifica se o último candle é um outside bar em tendência de alta
        if (isOutsideBar && isFullBody && lastClose > lastOpen)
        {
            //Print("lastClose: ", lastClose, " LongMA: ", longMA, " RSI: ", rsi, " body: ", body, " var: ", variation);
            double entryPrice = lastHigh; // Já está múltiplo de 5
            double stopLoss = lastLow;   // Já está múltiplo de 5
            
            // Calcula o Take Profit com base na fração
            double takeProfit = NormalizeDouble((entryPrice - stopLoss) * InpTPRatioOut, _Digits);
            
            // Ajusta o Take Profit para múltiplo de 5
            takeProfit = Rounder(takeProfit);
            
            // Calcula o preço de Take Profit final e ajusta
            double tpPrice = entryPrice + takeProfit;
            tpPrice = Rounder(tpPrice); // Ajusta para múltiplo de 5
            
            // Valida os valores de SL e TP
            if (stopLoss >= entryPrice || tpPrice <= entryPrice)
            {
                Print("Valores de SL ou TP inválidos para compra.");
                return;
            }
            
            // Calcula e armazena o valor do Stop Loss em pontos (se necessário)
            stopLossArray[OUTSIDEBAR] = Rounder((entryPrice - stopLoss) / _Point);
            
            // Envia a ordem de compra pendente
            BuyStopPrice(magicNumberArray[OUTSIDEBAR], InpLotSize, entryPrice, stopLoss, tpPrice, InpOrderExpiration, "Tend UP+OutsiderBar Green");
         }
    }
    // Verifica a tendência (preço abaixo da MA longa e RSI < 50)
    else if (lastClose < longMA && rsi < 50)
    {
        // Verifica se o último candle é um outside bar em tendência de baixa
        if (isOutsideBar && isFullBody && lastClose < lastOpen)
        {
        
            //Print("lastClose: ", lastClose, " LongMA: ", longMA, " RSI: ", rsi, " body: ", body, " var: ", variation);
            // Preço de entrada: mínima do outside bar
            double entryPrice = lastLow;
     
            double stopLoss = lastHigh;
            double takeProfit = NormalizeDouble((stopLoss - entryPrice) * InpTPRatioOut, _Digits); // Calcula o Take Profit
            takeProfit = Rounder(takeProfit); // Ajuste para múltiplo de 5 pontos
            
            double tpPrice = entryPrice - takeProfit; // Calcula o preço de Take Profit
            tpPrice = Rounder(tpPrice); // Ajuste para múltiplo de 5 pontos
            tpPrice = NormalizeDouble(tpPrice, _Digits); // Normaliza casas decimais
            
            // Valida os valores de SL e TP
            if (stopLoss <= entryPrice || tpPrice >= entryPrice)
            {
                Print("Valores de SL ou TP inválidos para venda.");
                return;
            }
            
            // Calcula e armazena o valor do Stop Loss em pontos
            stopLossArray[OUTSIDEBAR] = Rounder((stopLoss - entryPrice) / _Point); // Converte para pontos
            
            // Envia a ordem de venda pendente
            SellStopPrice(magicNumberArray[OUTSIDEBAR], InpLotSize, entryPrice, stopLoss, tpPrice, InpOrderExpiration, "Tend DOWN+OutsiderBar Red");

        }
    }
}