#include <Trade/Trade.mqh>
CTrade trade;

bool printedTradingTimeWarning = false;
ulong processedTickets[]; // Array para armazenar tickets processados
datetime tradingStopTime = 0;           // Horário de fechamento de posições

string expertName = ChartGetString(0, CHART_EXPERT_NAME) + " - ";

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
    request.sl = new_sl;
    double current_tp = PositionGetDouble(POSITION_TP);
    request.tp = (current_tp > 0) ? current_tp : 0;  // Mantém TP se existir, senão envia 0

    if (!OrderSend(request, result))
    {
        Print(expertName + "Erro ao modificar SL: ", result.comment);
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

void CancelOldPendingOrders(int magicNumber, int maxAgeSeconds = 60)
{
    datetime currentTime = TimeCurrent();
//    Print("MN" + magicNumber, "Max Seg: " + maxAgeSeconds);
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong orderTicket = OrderGetTicket(i); // Obtém o ticket da ordem

        if (OrderSelect(orderTicket)) // Seleciona a ordem ativa pelo ticket
        {
        
            // Verifica se a ordem pertence ao bot
            if (OrderGetInteger(ORDER_MAGIC) != magicNumber)
                continue;
                
        //        Print("Encontrei uma ordem " + magicNumber);
            datetime orderTime = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
            ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         //   Print("Current: "+currentTime, " ORder time: "+orderTime, " diferença: "+(currentTime - orderTime));
            // Verifica se é uma ordem pendente (BUY_LIMIT, SELL_LIMIT, BUY_STOP, SELL_STOP)
            if (orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_SELL_LIMIT ||
                orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_SELL_STOP)
            {
                // Verifica se a ordem está no book há mais de 30 segundos
                if ((currentTime - orderTime) >= maxAgeSeconds)
                {
              //  Print("A ordem venceu!");
                    if (trade.OrderDelete(orderTicket))
                    {
                        PrintFormat(expertName + "Ordem pendente %d cancelada após %d segundos.", orderTicket, maxAgeSeconds);
                    }
                    else
                    {
                        PrintFormat(expertName + "Falha ao cancelar ordem pendente %d. Erro: %d", orderTicket, GetLastError());
                    }
                }
            }
        }
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

void CheckLastTradeAndSendEmail(int magicNumber)
{
    // Seleciona o histórico de negociações
    if (HistorySelect(0, TimeCurrent()))
    {
        int totalDeals = HistoryDealsTotal();
        if (totalDeals > 0)
        {
            // Itera do último deal para o primeiro
            for (int i = totalDeals - 1; i >= 0; i--)
            {
                ulong ticket = HistoryDealGetTicket(i);

                if (HistoryDealSelect(ticket))
                {
                    // Verifica se o deal pertence a este bot (pelo magic number)
                    long dealMagic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
                    if (dealMagic == magicNumber)
                    {
                        // Verifica se o ticket já foi processado
                        if (IsTicketProcessed(ticket))
                        {
                            break; // Sai do loop se o ticket já foi processado
                        }

                        // Adiciona o ticket ao array de processados
                        AddProcessedTicket(ticket);

                        double closePrice = HistoryDealGetDouble(ticket, DEAL_PRICE);
                        double volume = HistoryDealGetDouble(ticket, DEAL_VOLUME);
                        datetime entryTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
                        double balance = AccountInfoDouble(ACCOUNT_BALANCE);
                        ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
                        ENUM_POSITION_TYPE positionType = (dealType == DEAL_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
                        string comment = HistoryDealGetString(ticket, DEAL_COMMENT);

                        // Obtém o SL e TP da negociação
                        double sl = HistoryDealGetDouble(ticket, DEAL_SL);
                        double tp = HistoryDealGetDouble(ticket, DEAL_TP);
                        
                        // Obtém o lucro/prejuízo da negociação
                        double profit = 0.0;
                        string profitS = "N/A";
                        profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                        if(profit != 0.0)
                           profitS = DoubleToString(profit,2);
                           

                        // Determina o motivo do fechamento com tolerância
                        string reason;
                        double tolerance = 1 * _Point; // Margem de tolerância de 1 ponto
                        if (sl > 0 && MathAbs(closePrice - sl) <= tolerance) {
                            reason = "Stop Loss";
                        } else if (tp > 0 && MathAbs(closePrice - tp) <= tolerance) {
                            reason = "Take Profit";
                        } else {
                            reason = (comment != "" ? comment : "Operação Manual");
                        }

                        // Envia o e-mail se o SendEmailBool estiver ativado
                        if (InpSendEmail && TimeToString(entryTime, TIME_DATE) == TimeToString(TimeCurrent(), TIME_DATE)) 
                        {
                            SendTradeEmail(
                                expertName+"Operação", // Assunto
                                reason,                     // Razão
                                closePrice,                 // Preço de fechamento
                                balance,                    // Saldo da conta
                                closePrice,                 // Preço da posição
                                positionType,               // Tipo de posição
                                sl,                         // Stop Loss
                                tp,                         // Take Profit
                                entryTime,                   // Horário de entrada
                                profitS
                            );
                            Print(expertName + "E-mail enviado com informações da última negociação.");
                        }
                        
                        // Envia o Push Notification se o SendPushNotification estiver ativado
                        if (InpSendPushNotification && TimeToString(entryTime, TIME_DATE) == TimeToString(TimeCurrent(), TIME_DATE)) 
                        {
                            SendTradePushNotification(
                                expertName+"Operação", // Assunto
                                reason,                     // Razão
                                closePrice,                 // Preço de fechamento
                                balance,                    // Saldo da conta
                                closePrice,                 // Preço da posição
                                positionType,               // Tipo de posição
                                sl,                         // Stop Loss
                                tp,                         // Take Profit
                                entryTime,                   // Horário de entrada
                                profitS
                            );
                            Print(expertName + "E-mail enviado com informações da última negociação.");
                        }

                        break; // Sai do loop após encontrar a última negociação deste bot
                    }
                }
            }
        }
    }
    else
    {
        Print(expertName+"Erro ao selecionar o histórico de negociações.");
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


bool isNewCandle()
{
    static datetime lastCandleTime = 0;
    datetime currentCandleTime = iTime(_Symbol, InpTimeframe, 0);
    if (lastCandleTime == currentCandleTime) return false; // Aguarda novo candle
    lastCandleTime = currentCandleTime;
    return true;
}

bool CheckTradingTime(int magicNumber) {
    // Obtém a hora e minuto atuais
    MqlDateTime currentTime;
    TimeToStruct(TimeCurrent(), currentTime);
    int currentHour = currentTime.hour;
    int currentMinute = currentTime.min;
    int dayOfWeek = currentTime.day_of_week; // 0 (Domingo) a 6 (Sábado)

    // Verifica se é um dia útil (Segunda a Sexta)
    bool isWeekday = (dayOfWeek >= 1 && dayOfWeek <= 5);

    // Verifica se está dentro do horário de negociação (considerando horas e minutos)
    bool isTradingTime = (currentHour > InpStartHour || (currentHour == InpStartHour && currentMinute >= InpStartMinute)) &&
                         (currentHour < InpEndHour || (currentHour == InpEndHour && currentMinute < InpEndMinute));

    // Se for dia útil e estiver dentro do horário de negociação
    if (isWeekday && isTradingTime) {
        printedTradingTimeWarning = false; // Reseta o aviso quando voltar ao horário permitido
        return true; // Dentro do horário de negociação
    } else {
        // Se estiver fora do horário de negociação e o aviso ainda não foi impresso
        if (!printedTradingTimeWarning) {
            Print(expertName + " Fora do horário permitido para negociação.");
            printedTradingTimeWarning = true;
            tradingStopTime = TimeCurrent() + (InpCloseAfterMinutes * 60); // Define o horário de fechamento
        }

        // Se já passou o tempo de espera, fechamos todas as posições
        if (TimeCurrent() >= tradingStopTime) {
            ClosePositionWithMagicNumber(magicNumber);
        }
        return false; // Fora do horário de negociação
    }
}


void CheckStopsSkippedAndCloseTrade(int magicNumber) {
    // Obtém o número total de ordens abertas
    int totalOrders = PositionsTotal();

    // Loop através de todas as ordens abertas
    for (int i = 0; i < totalOrders; i++) {
        // Seleciona a ordem pelo índice
        if (PositionGetTicket(i)) {
            // Verifica se o Magic Number corresponde
            if (PositionGetInteger(POSITION_MAGIC) == magicNumber) {
                // Obtém os detalhes da ordem
                ulong ticket = PositionGetInteger(POSITION_TICKET);
                double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                double stopLoss = PositionGetDouble(POSITION_SL);
                double takeProfit = PositionGetDouble(POSITION_TP);
                string symbol = PositionGetString(POSITION_SYMBOL);
                ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

                // Obtém o preço atual
                double currentPrice = (positionType == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);

                // Verifica se o Stop Loss foi pulado
                if (stopLoss != 0) {
                   if ((positionType == POSITION_TYPE_BUY && currentPrice < stopLoss) ||
                          (positionType == POSITION_TYPE_SELL && currentPrice > stopLoss)) {
                          Print(expertName + "Stop Loss pulado para a ordem ", ticket, " com Magic Number ", magicNumber);
                          
                          // Fecha a operação
                          trade.PositionClose(ticket);
                      }
                  }
                  
                  // Verifica se o Take Profit foi pulado
                  if (takeProfit != 0) {
                      if ((positionType == POSITION_TYPE_BUY && currentPrice > takeProfit) ||
                          (positionType == POSITION_TYPE_SELL && currentPrice < takeProfit)) {
                          Print(expertName + "Take Profit pulado para a ordem ", ticket, " com Magic Number ", magicNumber);
                          
                          // Fecha a operação
                          trade.PositionClose(ticket);
                      }
                  }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Função para gerenciar o capital e fechar operações com prejuízo  |
//+------------------------------------------------------------------+
void ManageCapital(int magicNumber, double maxLoss)
{
    // Obtém o número total de ordens abertas
    int totalOrders = PositionsTotal();
    
    // Itera sobre todas as ordens abertas
    for(int i = totalOrders - 1; i >= 0; i--)
    {
        // Seleciona a ordem pelo índice
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0)
        {
            // Verifica se a ordem pertence ao magicNumber especificado
            if(PositionGetInteger(POSITION_MAGIC) == magicNumber)
            {
                // Calcula o prejuízo atual da ordem
                double currentProfit = PositionGetDouble(POSITION_PROFIT) + 
                                      PositionGetDouble(POSITION_SWAP) + 
                                      PositionGetDouble(POSITION_COMMISSION);
                
                // Se o prejuízo for maior que o valor máximo permitido, fecha a ordem
                if(currentProfit < -maxLoss)
                {
                    // Fecha a ordem
                    trade.PositionClose(ticket);
                    
                    // Verifica se houve erro ao fechar a ordem
                    if(trade.ResultRetcode() != TRADE_RETCODE_DONE)
                    {
                        Print("Erro ao fechar a ordem: ", trade.ResultRetcode());
                    }
                }
            }
        }
    }
}

// Função para verificar se o sinal é do mesmo dia
bool IsSignalFromCurrentDay(string symbol, ENUM_TIMEFRAMES timeframe)
{
    // Obter a data do candle anterior (candle [1])
    datetime previousCandleTime = iTime(symbol, timeframe, 1);

    // Obter a data do candle atual (candle [0])
    datetime currentCandleTime = iTime(symbol, timeframe, 0);

    // Converter os timestamps para estrutura MqlDateTime
    MqlDateTime prevTimeStruct, currTimeStruct;
    TimeToStruct(previousCandleTime, prevTimeStruct);
    TimeToStruct(currentCandleTime, currTimeStruct);

    // Verificar se os candles são do mesmo dia
    return (prevTimeStruct.day == currTimeStruct.day &&
            prevTimeStruct.mon == currTimeStruct.mon &&
            prevTimeStruct.year == currTimeStruct.year);
}

bool IsVolumeAboveAverage(int period) {

    if (period <= 0) {
        Print("Erro: A quantidade de períodos deve ser maior que 0.");
        return false;
    }

    // Calcula a soma dos volumes dos últimos x candles antes do candle de análise (Candle[1])
    double sumVolumes = 0;
    for (int i = 1; i <= period; i++) {
        sumVolumes += (double)iVolume(_Symbol, _Period, i + 1); // i + 1 porque Candle[1] é o candle de análise
    }

    // Calcula a média dos volumes
    double averageVolume = sumVolumes / period;

    // Obtém o volume do candle de análise (Candle[1])
    double analysisVolume = (double)iVolume(_Symbol, _Period, 1);

    // Retorna true se o volume do candle de análise for maior que a média
    return analysisVolume > averageVolume;
}

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
        novoStopLoss = NormalizeDouble(novoStopLoss, _Digits);

        // Verificar se o novo Stop Loss é melhor que o atual
        if ((positionType == POSITION_TYPE_BUY && novoStopLoss > stopLoss) ||
            (positionType == POSITION_TYPE_SELL && novoStopLoss < stopLoss))
        {
            // Preparar a solicitação de modificação da posição
            MqlTradeRequest request;
            MqlTradeResult result;
            ZeroMemory(request);
            ZeroMemory(result);

            request.action = TRADE_ACTION_SLTP;
            request.position = PositionGetInteger(POSITION_TICKET);
            request.symbol = symbol;
            request.sl = novoStopLoss;
            request.tp = takeProfit;
            request.magic = magicNumber;

            // Enviar a solicitação de modificação
            if (OrderSend(request, result))
            {
                Print("Stop Loss movido para proteger ", percentualProtecao * 100, "% do lucro. Novo SL: ", novoStopLoss);
            }
            else
            {
                Print("Erro ao modificar Stop Loss. Código de retorno: ", result.retcode);
            }
        }
    }
}

// Função para gerenciar losses consecutivos
bool printedMaxConsecutiveLosses = false;
bool ManageConsecutiveLosses(int magicNumber, int maxConsecutiveLosses)
{
    int consecutiveLosses = 0;
    datetime currentTime = TimeCurrent(); // Obtém o tempo atual
    datetime currentDay = TimeCurrent() / 86400 * 86400; // Obtém o início do dia atual

    // Contabiliza as operações fechadas hoje com o magicNumber especificado
    HistorySelect(currentDay, currentTime); // Seleciona o histórico do dia atual
    int totalDeals = HistoryDealsTotal();   // Obtém o número total de negócios no dia

    for (int i = 0; i < totalDeals; i++)
    {
        ulong dealTicket = HistoryDealGetTicket(i); // Obtém o ticket do negócio
        ulong dealMagicNumber = HistoryDealGetInteger(dealTicket, DEAL_MAGIC); // Obtém o magicNumber do negócio

        // Verifica se o negócio pertence ao EA (magicNumber correspondente)
        if (dealMagicNumber == magicNumber && HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
        {
            double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT); // Obtém o lucro/prejuízo do negócio

            if (dealProfit < 0) // Se for um prejuízo
            {
                consecutiveLosses++; // Incrementa o contador de losses consecutivos
            }
            else
            {
                consecutiveLosses = 0; // Reseta o contador se houver um lucro
            }
        }
    }

    // Exibe os resultados no log
    //Print("Losses consecutivos: ", consecutiveLosses);

    // Verifica o limite de losses consecutivos
    if (consecutiveLosses >= maxConsecutiveLosses)
    {
        if(!printedMaxConsecutiveLosses){
           Print("Limite máximo de losses consecutivos atingido: ", maxConsecutiveLosses);
           printedMaxConsecutiveLosses = true;
        }
        return false; // Retorna false para parar o OnTick
    }

    printedMaxConsecutiveLosses = false; // Reseta a flag para print
    return true; // Retorna true para continuar o OnTick
}

bool printedMaxLimitTrades = false;
// Função para gerenciar losses consecutivos
bool ManageTotalTrades(int magicNumber, int maxTrades)
{
    int tradesCount = 0;
    datetime currentTime = TimeCurrent(); // Obtém o tempo atual
    datetime currentDay = TimeCurrent() / 86400 * 86400; // Obtém o início do dia atual

    // Contabiliza as operações fechadas hoje com o magicNumber especificado
    HistorySelect(currentDay, currentTime); // Seleciona o histórico do dia atual
    int totalDeals = HistoryDealsTotal();   // Obtém o número total de negócios no dia

    for (int i = 0; i < totalDeals; i++)
    {
        ulong dealTicket = HistoryDealGetTicket(i); // Obtém o ticket do negócio
        ulong dealMagicNumber = HistoryDealGetInteger(dealTicket, DEAL_MAGIC); // Obtém o magicNumber do negócio

        // Verifica se o negócio pertence ao EA (magicNumber correspondente)
        if (dealMagicNumber == magicNumber && HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
            tradesCount = tradesCount + 1;
    }

    if (tradesCount >= maxTrades)
    {
        if(!printedMaxLimitTrades){
            Print("Limite máximo de trades por dia atingido: ", tradesCount);
            printedMaxLimitTrades = true;
        }
        return false; // Retorna false para parar o OnTick
    }
    printedMaxLimitTrades = false; // Reseta a flag de print
    return true; // Retorna true para continuar o OnTick
}

//+------------------------------------------------------------------+
//| Verifica se há X ou mais posições abertas                        |
//| - Se SIM: Cancela ordens pendentes com MagicNumber != 0          |
//| - Retorna false (para bloquear novas ordens no OnTick)           |
//| - Se NÃO: Retorna true (permite novas ordens)                    |
//+------------------------------------------------------------------+
bool CheckAndManagePositions(int maxPositions)
{
    int totalPositions = 0;
    
    //--- Conta posições abertas no símbolo atual
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong positionTicket = PositionGetTicket(i);
        if(positionTicket > 0)
        {
            string positionSymbol = PositionGetString(POSITION_SYMBOL);
            if(positionSymbol == _Symbol)
            {
                totalPositions++;
                
                if(totalPositions >= maxPositions)
                {
                    CancelPendingOrders();
                    return false;
                }
            }
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Cancela todas as ordens pendentes com MagicNumber != 0           |
//+------------------------------------------------------------------+
void CancelPendingOrders()
{
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong orderTicket = OrderGetTicket(i);
        if(orderTicket > 0)
        {
            //--- Verifica se é uma ordem pendente
            ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            long magicNumber = OrderGetInteger(ORDER_MAGIC);
            
            if(magicNumber != 0 && 
               (orderType == ORDER_TYPE_BUY_LIMIT || 
                orderType == ORDER_TYPE_SELL_LIMIT ||
                orderType == ORDER_TYPE_BUY_STOP || 
                orderType == ORDER_TYPE_SELL_STOP))
            {
                //--- Tenta cancelar a ordem
                MqlTradeRequest request = {};
                MqlTradeResult result = {};
                request.action = TRADE_ACTION_REMOVE;
                request.order = orderTicket;
                
                if(!OrderSend(request, result))
                {
                    Print("Erro ao cancelar ordem #", orderTicket, " - Erro: ", GetLastError());
                }
                else
                {
                    Print("Ordem pendente #", orderTicket, " cancelada.");
                }
            }
        }
    }
}






/* OPERAÇÕES */

/* Ordens a mercado */
void BuyMarketPoint(int magicNumber, double lotSize, double sl, double tp, string comment)
{
    double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double return_sl; double return_tp;
    CalculateSLTP(ORDER_TYPE_BUY, price, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), return_sl, return_tp); // Calcula SL e TP
    
    // Garantir que os valores finais sejam múltiplos de 5 pontos
    return_sl = MathRound(return_sl / (5 * _Point)) * (5 * _Point);
    return_tp = MathRound(return_tp / (5 * _Point)) * (5 * _Point);
    
    trade.SetExpertMagicNumber(magicNumber); // Define o magic number
    if (!trade.Buy(lotSize, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), return_sl, return_tp, expertName+comment))
      Print(expertName+"Erro na execução de ordem de compra.");
}

void SellMarketPoint(int magicNumber, double lotSize, double sl, double tp, string comment)
{
    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double return_sl; double return_tp;
    CalculateSLTP(ORDER_TYPE_SELL, price, NormalizeDouble(sl, _Digits), NormalizeDouble(tp, _Digits), return_sl, return_tp); // Calcula SL e TP
    
    // Garantir que os valores finais sejam múltiplos de 5 pontos
    return_sl = MathRound(return_sl / (5 * _Point)) * (5 * _Point);
    return_tp = MathRound(return_tp / (5 * _Point)) * (5 * _Point);
    
    trade.SetExpertMagicNumber(magicNumber); // Define o magic number
    if (!trade.Sell(lotSize, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID), return_sl, return_tp, expertName+comment))
        Print(expertName+"Erro na execução de ordem de venda.");
}

void BuyMarketPrice(int magicNumber, double lotSize, double sl, double tp, string comment)
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
}


/* Ordens STOP */
void BuyStopPrice(int magicNumber, double lotSize, double price, double sl, double tp, int expirationSeconds, string comment)
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
}

/* Ordens LIMIT */
void BuyLimitPoint(int magicNumber, double price, double lotSize, double sl, double tp, int expiration, string comment)
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
}

void BuyLimitPrice(int magicNumber, double price, double lotSize, double sl, double tp, int expiration, string comment)
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
}

/* Calcular SL e TP */
void CalculateSLTP(int orderType, double price, double stopLoss, double takeProfit, double &sl, double &tp)
{
    if (stopLoss > 0)
    {
        sl = (orderType == ORDER_TYPE_BUY) ? price - stopLoss * _Point : price + stopLoss * _Point;
        sl = MathRound(sl / (5 * _Point)) * (5 * _Point); // Ajusta para múltiplo de 5 pontos
    }

    if (takeProfit > 0)
    {
        tp = (orderType == ORDER_TYPE_BUY) ? price + takeProfit * _Point : price - takeProfit * _Point;
        tp = MathRound(tp / (5 * _Point)) * (5 * _Point); // Ajusta para múltiplo de 5 pontos
    }
}