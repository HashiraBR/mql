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
    
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong orderTicket = OrderGetTicket(i); // Obtém o ticket da ordem

        if (OrderSelect(orderTicket)) // Seleciona a ordem ativa pelo ticket
        {
        
            // Verifica se a ordem pertence ao bot
            if (OrderGetInteger(ORDER_MAGIC) != magicNumber)
                continue;
                
            datetime orderTime = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
            ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            
            // Verifica se é uma ordem pendente (BUY_LIMIT, SELL_LIMIT, BUY_STOP, SELL_STOP)
            if (orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_SELL_LIMIT ||
                orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_SELL_STOP)
            {
                // Verifica se a ordem está no book há mais de 30 segundos
                if ((currentTime - orderTime) >= maxAgeSeconds)
                {
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
                        if (SendEmailBool)
                        {
                            SendTradeEmail(
                                expertName+"Encerramento de Operação", // Assunto
                                reason,                     // Razão
                                closePrice,                 // Preço de fechamento
                                balance,                    // Saldo da conta
                                closePrice,                 // Preço da posição
                                positionType,               // Tipo de posição
                                sl,                         // Stop Loss
                                tp,                         // Take Profit
                                entryTime                   // Horário de entrada
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

void SendTradeEmail(string subject, string reason, double price, double balance, double positionPrice, ENUM_POSITION_TYPE type, double sl, double tp, datetime entryTime)
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


void CalculateSLTP(int orderType, double stopLoss, double takeProfit, double &sl, double &tp)
{
    double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    //double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    if (stopLoss > 0)
        sl = (orderType == ORDER_TYPE_BUY) ? price - stopLoss * _Point : price + stopLoss * _Point;

    if (takeProfit > 0)
        tp = (orderType == ORDER_TYPE_BUY) ? price + takeProfit * _Point : price - takeProfit * _Point;
}

double Normalize(double price)
{
    return NormalizeDouble(price, _Digits);
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
    MqlDateTime time;
    TimeToStruct(TimeCurrent(), time);
    int currentHour = time.hour;
    int dayOfWeek = time.day_of_week; // 0 (Domingo) a 6 (Sábado)

    // Verifica se é um dia útil (Segunda a Sexta) e dentro do horário permitido
    if (dayOfWeek >= 1 && dayOfWeek <= 5 && currentHour >= StartHour && currentHour < EndHour) {
        printedTradingTimeWarning = false; // Reseta o aviso quando voltar ao horário permitido
        return true; // Dentro do horário de negociação
    } else {
        if (!printedTradingTimeWarning) {
            Print(expertName + " Fora do horário permitido para negociação.");
            printedTradingTimeWarning = true;
            tradingStopTime = TimeCurrent() + (X_Minutes_Close * 60); // Define o horário de fechamento
        }

        // Se já passou o tempo de espera, fechamos todas as posições
        if (TimeCurrent() >= tradingStopTime) {
            ClosePositionWithMagicNumber(magicNumber);
        }
        return false; // Fora do horário de negociação
    }
}


void ExecuteBuyOrder(int magicNumber, double loteSize, double sl, double tp, string comment)
{
    double return_sl; double return_tp;
    CalculateSLTP(ORDER_TYPE_BUY, Normalize(sl), Normalize(tp), return_sl, return_tp); // Calcula SL e TP
    trade.SetExpertMagicNumber(magicNumber); // Define o magic number
    if (!trade.Buy(loteSize, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), return_sl, return_tp, expertName+comment))
      Print(expertName+"Erro na execução de ordem de compra.");
}


void ExecuteSellOrder(int magicNumber, double loteSize, double sl, double tp, string comment)
{
    double return_sl; double return_tp;
    CalculateSLTP(ORDER_TYPE_SELL, Normalize(sl), Normalize(tp), return_sl, return_tp); // Calcula SL e TP
    trade.SetExpertMagicNumber(magicNumber); // Define o magic number
    if (!trade.Sell(loteSize, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID), return_sl, return_tp, expertName+comment))
        Print(expertName+"Erro na execução de ordem de venda.");
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