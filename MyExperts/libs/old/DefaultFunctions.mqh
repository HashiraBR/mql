#include <Trade/Trade.mqh>
CTrade trade;

bool printedTradingTimeWarning = false;
ulong processedTickets[]; // Array para armazenar tickets processados
datetime tradingStopTime = 0;           // Horário de fechamento de posições

string expertName = ChartGetString(0, CHART_EXPERT_NAME) + " - ";

bool BasicFunction(int magicNumber = 0){
    
    // Apply Trailing Stop if enabled
    if(InpSLType == TRAILING) MonitorTrailingStop(magicNumber, InpStopLoss);
    else if(InpSLType == PROGRESS) ProtectProfitProgressivo(magicNumber, InpProgressSLProtectedPoints, InpProgressSLPercentToProtect);
    else if(InpSLType == OPEN_PRICE_SL) SetStopLossAtOpenPrice(magicNumber, SymbolInfoDouble(_Symbol, SYMBOL_POINT));

    ManagePositionsAndOrders(magicNumber, InpOrderExpiration);

    // Verifica se é um novo candle
    if (!isNewCandle()) 
        return false;
   
    // Verifica horário de funcionamento e fecha possições
    if (!CheckTradingTime(magicNumber)) 
        return false;
        
    if(!IsSignalFromCurrentDay())
      return false;
      
    // Gerenciamento de risco e perdas
    if(!ManageTradingLimits(magicNumber, InpMaxConsecutiveLosses, InpMaxTrades, InpMaxOpenPositions))
       return false;
       
    if(DailyLimitReached())
        return false;
        
    if(HasOpenPosition(magicNumber)) 
        return false;
        
    return true;
        
}

void ManagePositionsAndOrders(int magicNumber, int maxAgeSeconds = 119) {
    datetime currentTime = TimeCurrent();
    
    // Primeiro processamos as posições abertas
    int totalPositions = PositionsTotal();
    for(int i = totalPositions-1; i >= 0; i--) {
        if(PositionGetTicket(i)) {
            if(PositionGetInteger(POSITION_MAGIC) == magicNumber) {
                ProcessPosition(magicNumber);
            }
        }
    }
    
    // Depois processamos as ordens pendentes
    int totalOrders = OrdersTotal();
    for(int i = totalOrders-1; i >= 0; i--) {
        ulong orderTicket = OrderGetTicket(i);
        if(OrderSelect(orderTicket)) {
            if(OrderGetInteger(ORDER_MAGIC) == magicNumber) {
                ProcessOrder(orderTicket, magicNumber, maxAgeSeconds, currentTime);
            }
        }
    }
    
    // Verifica último trade (se habilitado)
    if((InpSendEmail || InpSendPushNotification)) {
        CheckLastTrade(magicNumber, currentTime);
    }
}

// Função auxiliar para processar uma posição com gerenciamento de capital
void ProcessPosition(int magicNumber) {
    if(!PositionSelectByTicket(PositionGetInteger(POSITION_TICKET))) {
        Print("Falha ao selecionar a posição!");
        return;
    }

    ulong ticket = PositionGetInteger(POSITION_TICKET);
    double currentProfit = PositionGetDouble(POSITION_PROFIT);
    double stopLoss = PositionGetDouble(POSITION_SL);
    double takeProfit = PositionGetDouble(POSITION_TP);
    string symbol = PositionGetString(POSITION_SYMBOL);
    ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    
    double currentPrice = (positionType == POSITION_TYPE_BUY) 
                        ? SymbolInfoDouble(symbol, SYMBOL_BID) 
                        : SymbolInfoDouble(symbol, SYMBOL_ASK);

    // 1. Verificação de perda máxima
    if(currentProfit < -InpManageCapitalLoss) { // Note o sinal negativo
        for(int attempt = 0; attempt < 3; attempt++) {
            if(trade.PositionClose(ticket)) {
                PrintFormat("%s Posição %d fechada (Prejuízo: %.2f > Limite: %.2f) Magic: %d",
                          expertName, ticket, -currentProfit, InpManageCapitalLoss, magicNumber);
                return;
            }
            Sleep(1000);
        }
        PrintFormat("%s Falha ao fechar posição %d. Erro: %d",
                  expertName, ticket, GetLastError());
        return;
    }

    // 2. Verificação de Stop Loss e Take Profit
    bool closeBySL = (stopLoss != 0) && 
                    ((positionType == POSITION_TYPE_BUY && currentPrice < stopLoss) ||
                     (positionType == POSITION_TYPE_SELL && currentPrice > stopLoss));
    
    bool closeByTP = (takeProfit != 0) && 
                    ((positionType == POSITION_TYPE_BUY && currentPrice >= takeProfit) ||
                     (positionType == POSITION_TYPE_SELL && currentPrice <= takeProfit));

    if(closeBySL || closeByTP) {
        for(int attempt = 0; attempt < 3; attempt++) {
            if(trade.PositionClose(ticket)) {
                PrintFormat("%s Posição %d fechada por %s (Preço: %.5f %s: %.5f) Magic: %d",
                           expertName, ticket, 
                           closeBySL ? "Stop Loss" : "Take Profit",
                           currentPrice,
                           closeBySL ? "SL" : "TP",
                           closeBySL ? stopLoss : takeProfit,
                           magicNumber);
                return;
            }
            Sleep(1000);
        }
        PrintFormat("%s Falha ao fechar posição %d por %s. Erro: %d",
                  expertName, ticket, 
                  closeBySL ? "Stop Loss" : "Take Profit",
                  GetLastError());
    }
}


// Função auxiliar para processar uma ordem pendente
void ProcessOrder(ulong orderTicket, int magicNumber, int maxAgeSeconds, datetime currentTime) {
    ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
    
    if(orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_SELL_LIMIT ||
       orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_SELL_STOP) {
        datetime orderTime = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
        
        if((currentTime - orderTime) >= maxAgeSeconds) {
            if(trade.OrderDelete(orderTicket)) {
                PrintFormat("%sOrdem pendente %d cancelada após %d segundos.", expertName, orderTicket, maxAgeSeconds);
            } else {
                PrintFormat("%sFalha ao cancelar ordem %d. Erro: %d", expertName, orderTicket, GetLastError());
            }
        }
    }
}

void ClosePositionWithMagicNumber(int magicNumber) {
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if (PositionGetInteger(POSITION_MAGIC) == magicNumber) {
            if(!trade.PositionClose(ticket)) {
                Print(expertName + "Erro ao fechar posição aberta com MagicNumber: ", magicNumber);
            }
        }
    }
}


// Função para verificar se há uma posição aberta com o Número Mágico
bool HasOpenPosition(int magicNumber)
{
    for (int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if (PositionSelectByTicket(ticket))
        {
            if (PositionGetInteger(POSITION_MAGIC) == magicNumber)
                return true;
        }
    }
    return false;
}

int GetOpenPositionTotal(int &mnArray[]){
   int counter = 0;
   for (int i = 0; i < ArraySize(mnArray); i++)
      if(HasOpenPosition(mnArray[i])) counter++;
   return counter;
}


bool printedMaxConsecutiveLosses = false;
bool printedMaxLimitTrades = false;

bool ManageTradingLimits(int magicNumber, int maxConsecutiveLosses, int maxTrades, int maxPositions)
{
    int consecutiveLosses = 0;
    int tradesCount = 0;
    int totalPositions = 0;

    datetime currentTime = TimeCurrent();
    datetime currentDay = currentTime / 86400 * 86400; // Início do dia (00:00)

    // Seleciona o histórico de negociações do dia atual
    HistorySelect(currentDay, currentTime);
    int totalDeals = HistoryDealsTotal();

    // Loop para contar trades iniciadas e perdas consecutivas
    for (int i = 0; i < totalDeals; i++)
    {
        ulong dealTicket = HistoryDealGetTicket(i);
        if (dealTicket == 0) continue;

        ulong dealMagicNumber = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
        if (dealMagicNumber != magicNumber) continue;

        int entryType = (int)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);

        // Contabiliza apenas trades iniciadas no dia
        if (entryType == DEAL_ENTRY_IN)
        {
            tradesCount++;
        }

        // Contabiliza perdas consecutivas (com base apenas nas saídas)
        if (entryType == DEAL_ENTRY_OUT)
        {
            double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
            if (dealProfit < 0)
                consecutiveLosses++;
            else
                consecutiveLosses = 0;
        }
    }

    // Verifica limite de perdas consecutivas
    if (maxConsecutiveLosses != 0 && consecutiveLosses >= maxConsecutiveLosses)
    {
        if (!printedMaxConsecutiveLosses)
        {
            Print("Limite máximo de perdas consecutivas atingido: ", maxConsecutiveLosses);
            printedMaxConsecutiveLosses = true;
        }
        return false;
    }

    printedMaxConsecutiveLosses = false;

    // Verifica limite de trades iniciadas no dia
    if (maxTrades != 0 && tradesCount >= maxTrades)
    {
        if (!printedMaxLimitTrades)
        {
            Print("Limite máximo de trades por dia atingido: ", tradesCount);
            printedMaxLimitTrades = true;
        }
        return false;
    }

    printedMaxLimitTrades = false;

    // Verifica posições abertas no símbolo atual
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong positionTicket = PositionGetTicket(i);
        if (positionTicket > 0)
        {
            string positionSymbol = PositionGetString(POSITION_SYMBOL);
            if (positionSymbol == _Symbol)
            {
                totalPositions++;

                if (maxPositions != 0 && totalPositions >= maxPositions)
                {
                    ProcessOrder(positionTicket, magicNumber, 0, TimeCurrent());
                    return false;
                }
            }
        }
    }

    return true; // Permite novas operações
}



// Implementando o ATR para calcular SL
int defaultATRHandler;
int defaultSmoothedATRHandler;
void InitializerATR(){
   defaultATRHandler = iATR(_Symbol, InpTimeframe, InpAtrPeriod);
   defaultSmoothedATRHandler = iMA(_Symbol, InpTimeframe, InpAtrPeriod, 0, MODE_SMMA, defaultATRHandler);
   if(defaultATRHandler == INVALID_HANDLE || defaultSmoothedATRHandler == INVALID_HANDLE){
      Print(expertName + "Falha ao carregar Handler dos ATR e Smooted para definição de SL");
   }
}

double GetDefaultSmoothedATR(){
   double defaultSmootedATR[1];
   if(CopyBuffer(defaultSmoothedATRHandler, 0, 0, 1, defaultSmootedATR) != 1){
      Print(expertName + "Falha ao copiar Smoothed ATR para SL.");
      return -1.0;
   }
   
   return defaultSmootedATR[0];
}








bool IsVolumeAboveAverage(int period) {

    if (period <= 0) {
        Print("Erro: A quantidade de períodos deve ser maior que 0.");
        return false;
    }

    // Calcula a soma dos volumes dos últimos x candles antes do candle de análise (Candle[1])
    double sumVolumes = 0;
    for (int i = 1; i <= period; i++) {
        sumVolumes += (double)iVolume(_Symbol, InpTimeframe, i + 1); // i + 1 porque Candle[1] é o candle de análise
    }

    // Calcula a média dos volumes
    double averageVolume = sumVolumes / period;

    // Obtém o volume do candle de análise (Candle[1])
    double analysisVolume = (double)iVolume(_Symbol, InpTimeframe, 1);

    // Retorna true se o volume do candle de análise for maior que a média
    return analysisVolume > averageVolume;
}




bool CheckTradingTime(int magicNumber) {
    MqlDateTime currentTime;
    TimeToStruct(TimeCurrent(), currentTime);
    int currentHour = currentTime.hour;
    int currentMinute = currentTime.min;
    int dayOfWeek = currentTime.day_of_week;

    bool isWeekday = (dayOfWeek >= 1 && dayOfWeek <= 5);
    bool isTradingTime = (currentHour > InpStartHour || (currentHour == InpStartHour && currentMinute >= InpStartMinute)) &&
                         (currentHour < InpEndHour || (currentHour == InpEndHour && currentMinute < InpEndMinute));

    if (isWeekday && isTradingTime) {
        printedTradingTimeWarning = false;
        return true;
    } else {
        if (!printedTradingTimeWarning) {
            Print(expertName + " Fora do horário permitido para negociação.");
            printedTradingTimeWarning = true;
            tradingStopTime = TimeCurrent() + (InpCloseAfterMinutes * 60);
            Print("Tempo para fechamento definido para: ", TimeToString(tradingStopTime));
        }

        // Verifica se já passou o tempo de fechamento (remova a condição currentHour > 17)
        if (TimeCurrent() >= tradingStopTime) {
            /*Print("Fechando posições - Horário atual: ", TimeToString(TimeCurrent()), 
                  " - Horário de fechamento: ", TimeToString(tradingStopTime), 
                  " Magic: ", magicNumber);*/
            ClosePositionWithMagicNumber(magicNumber);
        }
        return false;
    }
}



bool isNewCandle()
{
    static datetime lastCandleTime = 0;
    datetime currentCandleTime = iTime(_Symbol, InpTimeframe, 0);
    if (lastCandleTime == currentCandleTime) return false; // Aguarda novo candle
    lastCandleTime = currentCandleTime;
    return true;
}

// Função para verificar se o sinal é do mesmo dia
bool IsSignalFromCurrentDay()
{
    // Obter a data do candle anterior (candle [1])
    datetime previousCandleTime = iTime(_Symbol, InpTimeframe, 1);

    // Obter a data do candle atual (candle [0])
    datetime currentCandleTime = iTime(_Symbol, InpTimeframe, 0);

    // Converter os timestamps para estrutura MqlDateTime
    MqlDateTime prevTimeStruct, currTimeStruct;
    TimeToStruct(previousCandleTime, prevTimeStruct);
    TimeToStruct(currentCandleTime, currTimeStruct);

    // Verificar se os candles são do mesmo dia
    return (prevTimeStruct.day == currTimeStruct.day &&
            prevTimeStruct.mon == currTimeStruct.mon &&
            prevTimeStruct.year == currTimeStruct.year);
}






























//+------------------------------------------------------------------+
//| Ordens                                                                 |
//+------------------------------------------------------------------+


double Rounder(double value) 
{
    if(InpPipSize <= 0) return value; // Proteção contra divisão por zero
    
    double pipValue = InpPipSize * _Point;
    return MathRound(value / pipValue) * pipValue;
}

/*double Rounder(double number){
   return MathRound(number / (InpPipSize * _Point) * (InpPipSize * _Point));
}*/

/* OPERAÇÕES */

/* Ordens a mercado */
void BuyMarketPoint(int magicNumber, double lotSize, double sl, double tp, string comment)
{
    double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    double maxDistance = InpMaxStopLossPoints * _Point;
    
    double return_sl; double return_tp;
    CalculateSLTP(ORDER_TYPE_BUY, price, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), return_sl, return_tp); // Calcula SL e TP
    
    // Garantir que os valores finais sejam múltiplos de 5 pontos
    return_sl = Rounder(return_sl);
    return_tp = Rounder(return_tp);
    
    if(return_sl != 0 && MathAbs(price - return_sl) > maxDistance) {
        PrintFormat("%s Ordem de BuyLimit cancelada: SL (%.5f) excede o limite de %d pontos a partir do preço (%.5f).", 
                    expertName, return_sl, InpMaxStopLossPoints, price);
        return;
    }
    
    trade.SetExpertMagicNumber(magicNumber); // Define o magic number
    if (!trade.Buy(lotSize, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), return_sl, return_tp, expertName+comment))
      Print(expertName+"Erro na execução de ordem de compra.");
}

void SellMarketPoint(int magicNumber, double lotSize, double sl, double tp, string comment)
{
    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    double maxDistance = InpMaxStopLossPoints * _Point;
    
    double return_sl; double return_tp;
    CalculateSLTP(ORDER_TYPE_SELL, price, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), return_sl, return_tp); // Calcula SL e TP
    
    // Garantir que os valores finais sejam múltiplos de 5 pontos
    return_sl = Rounder(return_sl);
    return_tp = Rounder(return_tp);
    
    if(return_sl != 0 && MathAbs(price - return_sl) > maxDistance) {
        PrintFormat("%s Ordem de BuyLimit cancelada: SL (%.5f) excede o limite de %d pontos a partir do preço (%.5f).", 
                    expertName, return_sl, InpMaxStopLossPoints, price);
        return;
    }
    
    trade.SetExpertMagicNumber(magicNumber); // Define o magic number
    if (!trade.Sell(lotSize, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID), return_sl, return_tp, expertName+comment))
        Print(expertName+"Erro na execução de ordem de venda.");
}

/*void BuyMarketPrice(int magicNumber, double lotSize, double sl, double tp, string comment)
{
    trade.SetExpertMagicNumber(magicNumber); // Define o magic number
    if (!trade.Buy(lotSize, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK),NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), expertName+comment))
      Print(expertName+"Erro na execução de ordem de compra.");
}

void SellMarketPrice(int magicNumber, double lotSize, double sl, double tp, string comment)
{
    trade.SetExpertMagicNumber(magicNumber); // Define o magic number
    if (!trade.Sell(lotSize, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID), NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), expertName+comment))
      Print(expertName+"Erro na execução de ordem de compra.");
}*/

void BuyMarketPrice(int magicNumber, double lotSize, double sl, double tp, string comment)
{
    double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

    // Verifica SL permitido
    if (sl != 0 && MathAbs(price - sl) > InpMaxStopLossPoints * _Point) {
        PrintFormat("%s Ordem de BuyMarketPrice cancelada: SL (%.5f) excede o limite de %d pontos a partir do preço (%.5f).",
                    expertName, sl, InpMaxStopLossPoints, price);
        return;
    }

    trade.SetExpertMagicNumber(magicNumber);
    if (!trade.Buy(lotSize, _Symbol, price, NormalizeDouble(Rounder(sl), _Digits), NormalizeDouble(Rounder(tp), _Digits), expertName + comment))
        Print(expertName + "Erro na execução de ordem de compra.");
}

void SellMarketPrice(int magicNumber, double lotSize, double sl, double tp, string comment)
{
    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    // Verifica SL permitido
    if (sl != 0 && MathAbs(price - sl) > InpMaxStopLossPoints * _Point) {
        PrintFormat("%s Ordem de SellMarketPrice cancelada: SL (%.5f) excede o limite de %d pontos a partir do preço (%.5f).",
                    expertName, sl, InpMaxStopLossPoints, price);
        return;
    }

    trade.SetExpertMagicNumber(magicNumber);
    if (!trade.Sell(lotSize, _Symbol, price, NormalizeDouble(Rounder(sl), _Digits), NormalizeDouble(Rounder(tp), _Digits), expertName + comment))
        Print(expertName + "Erro na execução de ordem de venda.");
}



/* Ordens STOP */
/*void BuyStopPrice(int magicNumber, double lotSize, double price, double sl, double tp, int expirationSeconds, string comment)
{
    datetime expirationTime = TimeCurrent() + expirationSeconds;
    trade.SetExpertMagicNumber(magicNumber); // Define o magic number
    if(!trade.BuyStop(lotSize, price, _Symbol, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), ORDER_TIME_SPECIFIED, expirationTime, expertName+comment))
      Print(expertName+"Erro na execução de ordem STOP de compra.");
}

void SellStopPrice(int magicNumber, double lotSize, double price, double sl, double tp, int expirationSeconds, string comment)
{
    datetime expirationTime = TimeCurrent() + expirationSeconds;
    trade.SetExpertMagicNumber(magicNumber); // Define o magic number
    if(!trade.SellStop(lotSize, price, _Symbol, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), ORDER_TIME_SPECIFIED, expirationTime, expertName+comment))
      Print(expertName+"Erro na execução de ordem STOP de venda.");
}*/
void BuyStopPrice(int magicNumber, double lotSize, double price, double sl, double tp, int expirationSeconds, string comment)
{
    if(sl == 0 || tp == 0) return;
    // Verifica SL permitido
    if(sl != 0 && MathAbs(price - sl) > InpMaxStopLossPoints * _Point) {
        PrintFormat("%s Ordem de BuyStop cancelada: SL (%.5f) excede o limite de %d pontos a partir do preço (%.5f).", 
                    expertName, sl, InpMaxStopLossPoints, price);
        return;
    }

    datetime expirationTime = TimeCurrent() + expirationSeconds;
    trade.SetExpertMagicNumber(magicNumber);
    if(!trade.BuyStop(lotSize, price, _Symbol, NormalizeDouble(Rounder(sl), _Digits), NormalizeDouble(Rounder(tp), _Digits),
                      ORDER_TIME_SPECIFIED, expirationTime, expertName + comment))
    {
        Print(expertName + "Erro na execução de ordem STOP de compra.");
    }
}

void SellStopPrice(int magicNumber, double lotSize, double price, double sl, double tp, int expirationSeconds, string comment)
{
    if(sl == 0 || tp == 0) return;
    // Verifica SL permitido
    if(sl != 0 && MathAbs(price - sl) > InpMaxStopLossPoints * _Point) {
        PrintFormat("%s Ordem de SellStop cancelada: SL (%.5f) excede o limite de %d pontos a partir do preço (%.5f).", 
                    expertName, sl, InpMaxStopLossPoints, price);
        return;
    }

    datetime expirationTime = TimeCurrent() + expirationSeconds;
    trade.SetExpertMagicNumber(magicNumber);
    if(!trade.SellStop(lotSize, price, _Symbol, NormalizeDouble(Rounder(sl), _Digits), NormalizeDouble(Rounder(tp), _Digits),
                       ORDER_TIME_SPECIFIED, expirationTime, expertName + comment))
    {
        Print(expertName + "Erro na execução de ordem STOP de venda.");
    }
}


/* Ordens LIMIT */
/*void BuyLimitPoint(int magicNumber, double price, double lotSize, double sl, double tp, int expiration, string comment)
{
    double return_sl; double return_tp;
    CalculateSLTP(ORDER_TYPE_BUY, price, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), return_sl, return_tp); // Calcula SL e TP
    
    // Garantir que os valores finais sejam múltiplos de 5 pontos
    return_sl = MathRound(return_sl / (5 * _Point)) * (5 * _Point);
    return_tp = MathRound(return_tp / (5 * _Point)) * (5 * _Point);
    
    datetime expirationTime = TimeCurrent() + expiration;
    trade.SetExpertMagicNumber(magicNumber); // Define o magic number
    if (!trade.BuyLimit(lotSize, price, _Symbol, return_sl, return_tp, ORDER_TIME_SPECIFIED, expirationTime, expertName + comment))
      Print(expertName+"Erro na execução de ordem de compra.");
}

void SellLimitPoint(int magicNumber, double price, double lotSize, double sl, double tp, int expiration, string comment)
{
    double return_sl; double return_tp;
    CalculateSLTP(ORDER_TYPE_SELL, price, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), return_sl, return_tp); // Calcula SL e TP
    
    // Garantir que os valores finais sejam múltiplos de 5 pontos
    return_sl = MathRound(return_sl / (5 * _Point)) * (5 * _Point);
    return_tp = MathRound(return_tp / (5 * _Point)) * (5 * _Point);
    
    datetime expirationTime = TimeCurrent() + expiration;
    trade.SetExpertMagicNumber(magicNumber); // Define o magic number
    if (!trade.SellLimit(lotSize, price, _Symbol, return_sl, return_tp, ORDER_TIME_SPECIFIED, expirationTime, expertName + comment))
        Print(expertName+"Erro na execução de ordem de venda.");
}*/
void BuyLimitPoint(int magicNumber, double price, double lotSize, double sl, double tp, int expiration, string comment)
{
    if(sl == 0 || tp == 0) return;
    
    double maxDistance = InpMaxStopLossPoints * _Point;
    
    double return_sl; double return_tp;
    CalculateSLTP(ORDER_TYPE_BUY, price, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), return_sl, return_tp); // Calcula SL e TP
    
    // Garantir que os valores finais sejam múltiplos de 5 pontos
    return_sl = Rounder(return_sl);
    return_tp = Rounder(return_tp);
    
    if(return_sl != 0 && MathAbs(price - return_sl) > maxDistance) {
        PrintFormat("%s Ordem de BuyLimit cancelada: SL (%.5f) excede o limite de %d pontos a partir do preço (%.5f).", 
                    expertName, return_sl, InpMaxStopLossPoints, price);
        return;
    }
    
    datetime expirationTime = TimeCurrent() + expiration;
    trade.SetExpertMagicNumber(magicNumber); // Define o magic number
    if (!trade.BuyLimit(lotSize, price, _Symbol, return_sl, return_tp, ORDER_TIME_SPECIFIED, expirationTime, expertName + comment))
      Print(expertName+"Erro na execução de ordem de compra.");
}

void SellLimitPoint(int magicNumber, double price, double lotSize, double sl, double tp, int expiration, string comment)
{
    if(sl == 0 || tp == 0) return;
    
    double maxDistance = InpMaxStopLossPoints * _Point;
    
    double return_sl; double return_tp;
    CalculateSLTP(ORDER_TYPE_SELL, price, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), return_sl, return_tp); // Calcula SL e TP
    
    // Garantir que os valores finais sejam múltiplos de 5 pontos
    return_sl = Rounder(return_sl);
    return_tp = Rounder(return_tp);
    
    if(return_sl != 0 && MathAbs(price - return_sl) > maxDistance) {
        PrintFormat("%s Ordem de BuyLimit cancelada: SL (%.5f) excede o limite de %d pontos a partir do preço (%.5f).", 
                    expertName, return_sl, InpMaxStopLossPoints, price);
        return;
    }
    
    datetime expirationTime = TimeCurrent() + expiration;
    trade.SetExpertMagicNumber(magicNumber); // Define o magic number
    if (!trade.SellLimit(lotSize, price, _Symbol, return_sl, return_tp, ORDER_TIME_SPECIFIED, expirationTime, expertName + comment))
        Print(expertName+"Erro na execução de ordem de venda.");
}

/*void BuyLimitPrice(int magicNumber, double price, double lotSize, double sl, double tp, int expiration, string comment)
{
    datetime expirationTime = TimeCurrent() + expiration;
    trade.SetExpertMagicNumber(magicNumber); // Define o magic number
    if (!trade.BuyLimit(lotSize, price, _Symbol, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), ORDER_TIME_SPECIFIED, expirationTime, expertName + comment))
      Print(expertName+"Erro na execução de ordem de compra.");
}

void SellLimitPrice(int magicNumber, double price, double lotSize, double sl, double tp, int expiration, string comment)
{
    datetime expirationTime = TimeCurrent() + expiration;
    trade.SetExpertMagicNumber(magicNumber); // Define o magic number
    Print("Tempo atual: ", TimeCurrent(), " - Tempo de expiração: ", expirationTime);
    if (!trade.SellLimit(lotSize, price, _Symbol, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), ORDER_TIME_SPECIFIED, expirationTime, expertName + comment))
        Print(expertName+"Erro na execução de ordem de venda.");
}*/

void BuyLimitPrice(int magicNumber, double price, double lotSize, double sl, double tp, int expiration, string comment)
{
    double maxDistance = InpMaxStopLossPoints * _Point;
    
    if(sl == 0 || tp ==0) return; // Não permite operação sem SL
    
    if(sl != 0 && MathAbs(price - sl) > maxDistance) {
        PrintFormat("%s Ordem de BuyLimit cancelada: SL (%.5f) excede o limite de %d pontos a partir do preço (%.5f).", 
                    expertName, sl, InpMaxStopLossPoints, price);
        return;
    }

    datetime expirationTime = TimeCurrent() + expiration;
    trade.SetExpertMagicNumber(magicNumber);

    if (!trade.BuyLimit(lotSize, price, _Symbol, NormalizeDouble(Rounder(sl), _Digits), NormalizeDouble(Rounder(tp), _Digits), 
                        ORDER_TIME_SPECIFIED, expirationTime, expertName + comment))
    {
        Print(expertName + " Erro na execução de ordem de compra.");
    }
}

void SellLimitPrice(int magicNumber, double price, double lotSize, double sl, double tp, int expiration, string comment)
{
    double maxDistance = InpMaxStopLossPoints * _Point;
    
    if(sl == 0 || tp ==0) return; // Não permite operação sem SL
    
    if(sl != 0 && MathAbs(price - sl) > maxDistance) {
        PrintFormat("%s Ordem de SellLimit cancelada: SL (%.5f) excede o limite de %d pontos a partir do preço (%.5f).", 
                    expertName, sl, InpMaxStopLossPoints, price);
        return;
    }

    datetime expirationTime = TimeCurrent() + expiration;
    trade.SetExpertMagicNumber(magicNumber);

    if (!trade.SellLimit(lotSize, price, _Symbol, NormalizeDouble(Rounder(sl), _Digits), NormalizeDouble(Rounder(tp), _Digits), 
                         ORDER_TIME_SPECIFIED, expirationTime, expertName + comment))
    {
        Print(expertName + " Erro na execução de ordem de venda.");
    }
}


/* Calcular SL e TP */
void CalculateSLTP(int orderType, double price, double stopLoss, double takeProfit, double &sl, double &tp)
{
    if (stopLoss > 0)
    {
        sl = (orderType == ORDER_TYPE_BUY) ? price - stopLoss * _Point : price + stopLoss * _Point;
        sl = Rounder(sl); // Ajusta para múltiplo de 5 pontos
    }

    if (takeProfit > 0)
    {
        tp = (orderType == ORDER_TYPE_BUY) ? price + takeProfit * _Point : price - takeProfit * _Point;
        tp = Rounder(tp); // Ajusta para múltiplo de 5 pontos
    }
}


























//+------------------------------------------------------------------+
//| Mensagens                                                                 |
//+------------------------------------------------------------------+

// Função auxiliar para verificar último trade
void CheckLastTrade(int magicNumber, datetime currentTime) {
    if(HistorySelect(0, currentTime)) {
        int totalDeals = HistoryDealsTotal();
        
        for(int i = totalDeals-1; i >= 0; i--) {
            ulong ticket = HistoryDealGetTicket(i);
            
            //if(ticket <= lastProcessedTicket) break;
             // Verifica se o ticket já foi processado
            if (IsTicketProcessed(ticket))
                break; // Sai do loop se o ticket já foi processado
            
            if(HistoryDealSelect(ticket)) {
                long dealMagic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
                if(dealMagic == magicNumber) {
                    ProcessTradeNotification(ticket, currentTime);
                    // Adiciona o ticket ao array de processados
                    AddProcessedTicket(ticket);
                    break;
                }
            }
        }
    }
}

// Função auxiliar para processar notificação de trade
void ProcessTradeNotification(ulong ticket, datetime currentTime) {
    double closePrice = HistoryDealGetDouble(ticket, DEAL_PRICE);
    double volume = HistoryDealGetDouble(ticket, DEAL_VOLUME);
    datetime entryTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
    ENUM_POSITION_TYPE positionType = (dealType == DEAL_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
    string comment = HistoryDealGetString(ticket, DEAL_COMMENT);
    double sl = HistoryDealGetDouble(ticket, DEAL_SL);
    double tp = HistoryDealGetDouble(ticket, DEAL_TP);
    double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
    string profitS = (profit != 0.0) ? DoubleToString(profit, 2) : "N/A";
    
    string reason = GetCloseReason(closePrice, sl, tp, comment);
    
    if(TimeToString(entryTime, TIME_DATE) == TimeToString(currentTime, TIME_DATE)) {
        if(InpSendEmail) {
            SendTradeNotification(
                expertName+"Operação", reason, closePrice, balance, 
                closePrice, positionType, sl, tp, entryTime, profitS, false
            );
        }
        
        if(InpSendPushNotification) {
            SendTradeNotification(
                expertName+"Operação", reason, closePrice, balance, 
                closePrice, positionType, sl, tp, entryTime, profitS, true
            );
        }
    }
}

// Função auxiliar para determinar razão do fechamento
string GetCloseReason(double closePrice, double sl, double tp, string comment) {
    double tolerance = 1 * _Point;
    
    if(sl > 0 && MathAbs(closePrice - sl) <= tolerance) {
        return "Stop Loss";
    }
    if(tp > 0 && MathAbs(closePrice - tp) <= tolerance) {
        return "Take Profit";
    }
    return (comment != "" ? comment : "Operação Manual");
}

// Função unificada para envio de notificações
void SendTradeNotification(string subject, string reason, double closePrice, double balance,
                         double positionPrice, ENUM_POSITION_TYPE positionType, double sl,
                         double tp, datetime entryTime, string profit, bool isPush) {
    if(isPush) {
        SendTradePushNotification(subject, reason, closePrice, balance, positionPrice,
                                positionType, sl, tp, entryTime, profit);
        Print(expertName + "Push notification enviada.");
    } else {
        SendTradeEmail(subject, reason, closePrice, balance, positionPrice,
                      positionType, sl, tp, entryTime, profit);
        Print(expertName + "E-mail enviado.");
    }
}



void SendTradeEmail(string subject, string reason, double price, double balance, double positionPrice, ENUM_POSITION_TYPE type, double sl, double tp, datetime entryTime, string profit)
{
    // Formata o corpo do e-mail
    string emailBody = "Detalhes da Operação:\n\n";
    emailBody += "Razão: " + reason + "\n";
    emailBody += "Tipo: " + (type == POSITION_TYPE_BUY ? "Compra" : "Venda") + "\n";
    emailBody += "Preço: " + DoubleToString(price, _Digits) + "\n";
    emailBody += "Saldo da Conta: " + DoubleToString(balance, 2) + "\n";
    emailBody += "Preço da Posição: " + DoubleToString(positionPrice, _Digits) + "\n";
    emailBody += "Stop Loss: " + DoubleToString(sl, _Digits) + "\n";
    emailBody += "Take Profit: " + DoubleToString(tp, _Digits) + "\n";
    emailBody += "Horário: " + TimeToString(entryTime, TIME_DATE|TIME_MINUTES) + "\n";
    emailBody += "Profit: " + profit + "\n";

    // Envia o e-mail
    if (!SendMail(subject, emailBody))
    {
        Print(expertName+"Erro ao enviar e-mail: ", GetLastError());
    }
    else
    {
        Print(expertName+"E-mail enviado com sucesso!");
    }
}

void SendTradePushNotification(string subject, string reason, double price, double balance, double positionPrice, ENUM_POSITION_TYPE type, double sl, double tp, datetime entryTime, string profit)
{
    // Formata a mensagem para a notificação push
    string notificationMessage = subject + "\n";
    notificationMessage += "Razão: " + reason + "\n";
    notificationMessage += "Tipo: " + (type == POSITION_TYPE_BUY ? "Compra" : "Venda") + "\n";
    notificationMessage += "Preço: " + DoubleToString(price, _Digits) + "\n";
    notificationMessage += "Saldo da Conta: " + DoubleToString(balance, 2) + "\n";
    notificationMessage += "Preço da Posição: " + DoubleToString(positionPrice, _Digits) + "\n";
    notificationMessage += "Stop Loss: " + DoubleToString(sl, _Digits) + "\n";
    notificationMessage += "Take Profit: " + DoubleToString(tp, _Digits) + "\n";
    notificationMessage += "Horário: " + TimeToString(entryTime, TIME_DATE | TIME_MINUTES) + "\n";
    notificationMessage += "Profit: " + profit + "\n";

    // Envia a notificação push
    if (!SendNotification(notificationMessage))
    {
        Print("Erro ao enviar notificação push: ", GetLastError());
    }
    else
    {
        Print("Notificação push enviada com sucesso!");
    }
}

bool IsTicketProcessed(ulong ticket)
{
    for (int i = 0; i < ArraySize(processedTickets); i++)
    {
        if (processedTickets[i] == ticket)
        {
            return true; // Ticket já foi processado
        }
    }
    return false; // Ticket não foi processado
}

void AddProcessedTicket(ulong ticket)
{
    int size = ArraySize(processedTickets);
    ArrayResize(processedTickets, size + 1);
    processedTickets[size] = ticket;
}






//+------------------------------------------------------------------+
//| Proteção a Riscos                                                                  |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Função para proteger progressivamente o lucro                    |
//+------------------------------------------------------------------+
void ProtectProfitProgressivo(int magicNumber, int pontosPorPasso, double percentualProtecao)
{
    // Loop através de todas as posições abertas
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        // Obter o ticket da posição
        ulong ticket = PositionGetTicket(i);
        if (ticket <= 0) continue;
   
        // Selecionar a posição usando o ticket
        if (!PositionSelectByTicket(ticket)) continue;

        // Verificar se a posição pertence ao magicNumber especificado
        if (PositionGetInteger(POSITION_MAGIC) != magicNumber) continue;

        // Obter os detalhes da posição
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        double stopLoss = PositionGetDouble(POSITION_SL);
        double takeProfit = PositionGetDouble(POSITION_TP);
        string symbol = PositionGetString(POSITION_SYMBOL);
        ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

        // Calcular o lucro em pontos
        double pontosLucro = (positionType == POSITION_TYPE_BUY) ?
            (currentPrice - openPrice) / _Point :
            (openPrice - currentPrice) / _Point;
            
        // Verificar se o lucro atingiu o mínimo para proteção
        if (pontosLucro < pontosPorPasso) continue;

        // Calcular quantos passos de lucro foram atingidos
        int passos = int(pontosLucro / pontosPorPasso);

        // Calcular o novo Stop Loss para proteger percentualProtecao% do lucro em cada passo
        double novoStopLoss = (positionType == POSITION_TYPE_BUY) ?
            openPrice + (pontosPorPasso * passos * percentualProtecao * _Point) :
            openPrice - (pontosPorPasso * passos * percentualProtecao * _Point);

        // Normalizar o valor do Stop Loss
        novoStopLoss = NormalizeDouble(Rounder(novoStopLoss), _Digits);

        // Verificar se o novo Stop Loss é melhor que o atual
        if ((positionType == POSITION_TYPE_BUY && novoStopLoss > stopLoss) ||
            (positionType == POSITION_TYPE_SELL && novoStopLoss < stopLoss))
        {
            ModifySL(ticket, novoStopLoss);
        }
    }
}



void SetStopLossAtOpenPrice(int magicNumber, double slOffset)
{
    // Verifica todas as posições abertas
    for(int i = PositionsTotal()-1; i >= 0; i--) // Iterar de trás para frente é mais seguro para possíveis remoções
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0)
        {
            Print("Erro ao obter ticket da posição: ", GetLastError());
            continue;
        }

        // Filtra pelo MagicNumber e pelo símbolo correto
        if(PositionGetInteger(POSITION_MAGIC) != magicNumber || PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;

        // Obtém os dados necessários da posição
        double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        double currentPrice = (posType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        
        // Calcula o lucro em pontos
        double profitPoints = (posType == POSITION_TYPE_BUY) 
                           ? (currentPrice - entryPrice) / _Point
                           : (entryPrice - currentPrice) / _Point;

        // Verifica se atingiu o lucro mínimo para mover o SL
        if(profitPoints >= InpSLAtOpenProfit)
        {
            double newSL = (posType == POSITION_TYPE_BUY) 
                        ? entryPrice + slOffset * _Point
                        : entryPrice - slOffset * _Point;
            
            newSL = NormalizeDouble(Rounder(newSL), _Digits);
            double currentTP = PositionGetDouble(POSITION_TP);
            double currentSL = PositionGetDouble(POSITION_SL);

            // Verifica se o SL já está no lugar certo (evita modificações desnecessárias)
            if(MathAbs(newSL - currentSL) < _Point/2.0)
                continue;

            ModifySL(ticket, Rounder(newSL));
        }
    }
}


void MonitorTrailingStop(int magicNumber, double stopLoss)
{
    for (int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if (PositionSelectByTicket(ticket))
        {
            // Verifica se a posição foi aberta por este bot
            if (PositionGetInteger(POSITION_MAGIC) == magicNumber)
            {
                double sl = PositionGetDouble(POSITION_SL);
                double price = PositionGetDouble(POSITION_PRICE_OPEN);
                ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                double new_sl;
                
                // Calcula o ganho atual da posição
                double currentProfitPoints = 0;
                if (type == POSITION_TYPE_BUY)
                {
                    currentProfitPoints = (bid - price) / _Point; // Ganho em pontos para compra
                }
                else if (type == POSITION_TYPE_SELL)
                {
                    currentProfitPoints = (price - ask) / _Point; // Ganho em pontos para venda
                }

                // Verifica se o ganho atual é maior ou igual ao ponto de início do trailing stop
                if (currentProfitPoints >= InpTrailingSLStartPoint)
                {
                   if (type == POSITION_TYPE_BUY)
                   {
                       new_sl = bid - stopLoss * _Point;
                       if (new_sl > sl)
                       {
                           ModifySL(ticket, new_sl);
                       }
                   }
                   else if (type == POSITION_TYPE_SELL)
                   {
                       new_sl = ask + stopLoss * _Point;
                       if (new_sl < sl)
                       {
                           ModifySL(ticket, new_sl);
                       }
                   }
                }
            }
        }
    }
}

void ModifySL(ulong ticket, double new_sl)
{
    MqlTradeRequest request;
    MqlTradeResult result;

    ZeroMemory(request);
    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.symbol = _Symbol;
    request.sl = Rounder(new_sl);
    double current_tp = PositionGetDouble(POSITION_TP);
    request.tp = (current_tp > 0) ? current_tp : 0;  // Mantém TP se existir, senão envia 0

    if (!OrderSend(request, result))
    {
        Print(expertName + "Erro ao modificar SL: ", result.comment);
    }
}





//+------------------------------------------------------------------+
//| Gestão de limites diários                                                                  |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Verifica se o lucro diário foi atingido                          |
//+------------------------------------------------------------------+
bool IsDailyProfitReached(double dailyProfitLimit) 
{
    if(dailyProfitLimit <= 0) return false; // Se limite não estiver definido
    
    double dailyProfit = CalculateDailyProfit();
    return(dailyProfit >= dailyProfitLimit);
}

//+------------------------------------------------------------------+
//| Verifica se o prejuízo diário foi atingido                       |
//+------------------------------------------------------------------+
bool IsDailyLossReached(double dailyLossLimit) 
{
    if(dailyLossLimit <= 0) return false; // Se limite não estiver definido
    
    double dailyProfit = CalculateDailyProfit();
    return(dailyProfit <= -dailyLossLimit); // Note o sinal negativo
}

//+------------------------------------------------------------------+
//| Calcula o resultado financeiro diário                            |
//+------------------------------------------------------------------+
double CalculateDailyProfit() 
{
    double totalProfit = 0;
    datetime todayStart = iTime(NULL, PERIOD_D1, 0); // Início do dia atual
    
    if(lastChackLimit != todayStart){
      profitFlag = true;
      lossFlag = true;
      lastChackLimit = todayStart;
    }
    
    // Verificar histórico de ordens fechadas hoje
    if(HistorySelect(todayStart, TimeCurrent()))
    {
        for(int i = HistoryDealsTotal()-1; i >= 0; i--)
        {
            ulong ticket = HistoryDealGetTicket(i);
            if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
            {
                totalProfit += HistoryDealGetDouble(ticket, DEAL_PROFIT);
            }
        }
    }
    
    // Adicionar posições abertas (resultado não realizado)
    for(int i = PositionsTotal()-1; i >= 0; i--)
    {
        if(PositionGetTicket(i))
        {
            totalProfit += PositionGetDouble(POSITION_PROFIT);
        }
    }
    
    return totalProfit;
}

//+------------------------------------------------------------------+
//| Função de verificação antes de operar                            |
//+------------------------------------------------------------------+
// Return FALSE = pode operar, pois não atingiu nenhum dos limites
// Return TRUE = para de operar, pois atingiu algum dos limites
bool profitFlag = false, lossFlag = false;
datetime lastChackLimit = false;
bool DailyLimitReached() 
{
    if(IsDailyProfitReached(InpDailyProfitLimit))
    {
        if(!profitFlag){
            Print("Limite diário de lucro atingido! Trading suspenso.");
            profitFlag = true;
        }
        return true;
    }
    
    if(IsDailyLossReached(InpDailyLossLimit))
    {
        if(!lossFlag){
            Print("Limite diário de perda atingido! Trading suspenso.");
            lossFlag = true;
        }
        return true;
    }
    
    return false;
}
