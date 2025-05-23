//+------------------------------------------------------------------+
//|                                          NotificationService.mqh |
//|                                                    Danne Pereira |
//|                                             https://www.aipi.com |
//+------------------------------------------------------------------+
#property copyright "Danne Pereira"
#property link      "https://www.aipi.com"
#property version   "1.00"

#include <Trade/Trade.mqh>
#include <Trade/DealInfo.mqh>

class CNotificationService
{
private:
    CDealInfo          m_deal;
    CTrade             m_trade;
    ulong              m_processedTickets[];
    int                m_magicNumber;
    string             m_expertName;
    bool               m_emailEnabled;
    bool               m_pushEnabled;
    bool               m_logToFile;
    
    // Métodos auxiliares privados
    bool               IsTicketProcessed(const ulong ticket);
    void               AddProcessedTicket(const ulong ticket);
    string             GetTradeDescription();
    string             FormatPrice(const double price, const int digits);
    
public:
    // Construtor
    CNotificationService(const int magicNumber, const bool emailEnabled = true, 
                        const bool pushEnabled = true, const bool logToFile = false);
    
    // Métodos principais
    void               CheckLastTradeForNotification();
    void               SendTradeEmail(const string subject, const string message);
    void               SendTradePushNotification(const string subject, const string message);
    void               LogTradeToFile(const string message);
    
    // Setters para configuração
    void               SetEmailEnabled(const bool enabled) { m_emailEnabled = enabled; }
    void               SetPushEnabled(const bool enabled) { m_pushEnabled = enabled; }
    void               SetLogToFileEnabled(const bool enabled) { m_logToFile = enabled; }
};

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
CNotificationService::CNotificationService(const int magicNumber, const bool emailEnabled, 
                                          const bool pushEnabled, const bool logToFile) :
    m_magicNumber(magicNumber),
    m_emailEnabled(emailEnabled),
    m_pushEnabled(pushEnabled),
    m_logToFile(logToFile)
{
    m_expertName = ChartGetString(0, CHART_EXPERT_NAME) + " - ";
    ArrayResize(m_processedTickets, 0, 100);
}

//+------------------------------------------------------------------+
//| Verifica o último trade e envia notificações                     |
//+------------------------------------------------------------------+
void CNotificationService::CheckLastTradeForNotification()
{
    // Get today's start time (00:00:00)
    MqlDateTime todayStartTime;
    TimeCurrent(todayStartTime);
    todayStartTime.hour = 0;
    todayStartTime.min = 0;
    todayStartTime.sec = 0;
    datetime startOfDay = StructToTime(todayStartTime);
    
    // Select history from today until now
    if(!HistorySelect(startOfDay, TimeCurrent()))
        return;
    
    int totalDeals = HistoryDealsTotal();
    for(int i = totalDeals-1; i >= 0; i--)
    {
        ulong ticket = HistoryDealGetTicket(i);
        if(ticket == 0) continue;
        
        if(m_deal.SelectByIndex(i) && m_deal.Magic() == m_magicNumber)
        {
            if(!IsTicketProcessed(ticket))
            {
                // Additional check to ensure the deal is from today
                datetime dealTime = (datetime)m_deal.Time();
                if(dealTime >= startOfDay)
                {
                    string description = GetTradeDescription();
                    
                    if(m_emailEnabled)
                        SendTradeEmail(" - Trade Executado", description);
                    
                    if(m_pushEnabled)
                        SendTradePushNotification(" - Trade Executado", description);
                    
                    if(m_logToFile)
                        LogTradeToFile(description);
                    
                    AddProcessedTicket(ticket);
                    break; // Processa apenas o último trade
                }
            }
        }
    }
}


//+------------------------------------------------------------------+
//| Verifica se o ticket já foi processado                           |
//+------------------------------------------------------------------+
bool CNotificationService::IsTicketProcessed(const ulong ticket)
{
    for(int i = 0; i < ArraySize(m_processedTickets); i++)
    {
        if(m_processedTickets[i] == ticket)
            return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Adiciona ticket à lista de processados                           |
//+------------------------------------------------------------------+
void CNotificationService::AddProcessedTicket(const ulong ticket)
{
    int size = ArraySize(m_processedTickets);
    ArrayResize(m_processedTickets, size + 1);
    m_processedTickets[size] = ticket;
}

//+------------------------------------------------------------------+
//| Cria descrição detalhada do trade                                |
//+------------------------------------------------------------------+
string CNotificationService::GetTradeDescription()
{
    //if(m_deal == nullptr)
    //    return "Erro: Não foi possível obter detalhes do trade";
    
    string symbol = m_deal.Symbol();
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    
    string direction = (m_deal.DealType() == DEAL_TYPE_BUY) ? "COMPRA" : "VENDA";
    string entryExit = (m_deal.Entry() == DEAL_ENTRY_IN) ? "Abertura" : "Fechamento";
    
    string message = StringFormat(
        "%s %s\n"
        "Ativo: %s\n"
        "Preço: %s\n"
        "Volume: %.2f\n"
        "Lucro: %.2f %s\n"
        "Ticket: %I64u\n"
        "Horário: %s",
        entryExit, direction,
        symbol,
        FormatPrice(m_deal.Price(), digits),
        m_deal.Volume(),
        m_deal.Profit(),
        AccountInfoString(ACCOUNT_CURRENCY),
        TimeToString(m_deal.Time(), TIME_DATE|TIME_SECONDS)
    );
    
    return message;
}

//+------------------------------------------------------------------+
//| Formata preço com os dígitos corretos                            |
//+------------------------------------------------------------------+
string CNotificationService::FormatPrice(const double price, const int digits)
{
    return DoubleToString(price, digits);
}

//+------------------------------------------------------------------+
//| Envia email específico para trades                               |
//+------------------------------------------------------------------+
void CNotificationService::SendTradeEmail(const string subject, const string message)
{
    if(!m_emailEnabled) return;
    
    string fullSubject = m_expertName + subject;
    SendMail(fullSubject, message);
}

//+------------------------------------------------------------------+
//| Envia notificação push específica para trades                    |
//+------------------------------------------------------------------+
void CNotificationService::SendTradePushNotification(const string subject, const string message)
{
    if(!m_pushEnabled) return;
    
    SendNotification(m_expertName + subject + ": " + message);
}

//+------------------------------------------------------------------+
//| Registra trade em arquivo de log                                 |
//+------------------------------------------------------------------+
void CNotificationService::LogTradeToFile(const string message)
{
    if(!m_logToFile) return;
    
    // Obtendo o número da conta
    string filename = "TradeLog_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + ".csv";
    int handle = FileOpen(filename, FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON);
    
    if(handle != INVALID_HANDLE)
    {
        FileSeek(handle, 0, SEEK_END);
        FileWrite(handle, TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), message);
        FileClose(handle);
    }
}
