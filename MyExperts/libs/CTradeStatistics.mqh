//+------------------------------------------------------------------+
//|                                             CTradeStatistics.mqh |
//|                                                    Danne Pereira |
//|                                             https://www.aipi.com |
//+------------------------------------------------------------------+
#property copyright "Danne Pereira"
#property link      "https://www.aipi.com"
#property version   "1.00"
#include <Arrays\ArrayObj.mqh>

class CTradeRecord : public CObject
{
public:
    datetime time;
    double profit;
    bool isWin;
    
    CTradeRecord(datetime _time, double _profit, bool _isWin) : 
        time(_time), profit(_profit), isWin(_isWin) {}
        
    double GetProfit(){ return profit;}
};

class CTradeStatistics
{
private:
    CArrayObj m_history;
    int m_magicNumber;

    // Caches
    double m_dailyProfit;
    int m_dailyTrades;
    int m_dailyWins;
    
    double m_weeklyProfit;
    int m_weeklyTrades;
    int m_weeklyWins;
    
    double m_monthlyProfit;
    int m_monthlyTrades;
    int m_monthlyWins;
    
    datetime m_lastUpdate;
    
    double m_payoff;

    void CalculateDailyStats();
    void CalculateWeeklyStats();
    void CalculateMonthlyStats();
    datetime GetPeriodStart(int periodType);
    int GetDaysInMonth(int month, int year);

public:
    CTradeStatistics(int magic) : 
        m_magicNumber(magic),
        m_dailyProfit(0), m_dailyTrades(0), m_dailyWins(0),
        m_weeklyProfit(0), m_weeklyTrades(0), m_weeklyWins(0),
        m_monthlyProfit(0), m_monthlyTrades(0), m_monthlyWins(0),
        m_lastUpdate(0), m_payoff(0) {}

    ~CTradeStatistics() { m_history.Clear(); }

    void AddTrade(datetime time, double profit, double commission=0, double swap=0);
    void SyncWithHistory(); // <<< Adicional
    void UpdateStatistics();

    // Getters
    double GetDailyProfit() { return m_dailyProfit; }
    int GetDailyTrades() { return m_dailyTrades; }
    int GetDailyWins() { return m_dailyWins; }
    double GetDailyWinRate() { return (m_dailyTrades > 0) ? 100.0 * m_dailyWins / m_dailyTrades : 0; }

    double GetWeeklyProfit() { return m_weeklyProfit; }
    int GetWeeklyTrades() { return m_weeklyTrades; }
    int GetWeeklyWins() { return m_weeklyWins; }
    double GetWeeklyWinRate() { return (m_weeklyTrades > 0) ? 100.0 * m_weeklyWins / m_weeklyTrades : 0; }

    double GetMonthlyProfit() { return m_monthlyProfit; }
    int GetMonthlyTrades() { return m_monthlyTrades; }
    int GetMonthlyWins() { return m_monthlyWins; }
    double GetMonthlyWinRate() { return (m_monthlyTrades > 0) ? 100.0 * m_monthlyWins / m_monthlyTrades : 0; }

    double GetProfitFactor(int periodType);
    double GetPayoff(int periodType);
    double GetPayoffRatio(int periodType);
    
    void PrintDebugInfo()
    {
        Print("Total trades in history: ", m_history.Total());
        Print("Last update time: ", TimeToString(m_lastUpdate));
        Print("Daily - Profit: ", m_dailyProfit, " Trades: ", m_dailyTrades, " Wins: ", m_dailyWins);
        Print("Weekly - Profit: ", m_weeklyProfit, " Trades: ", m_weeklyTrades, " Wins: ", m_weeklyWins);
        Print("Monthly - Profit: ", m_monthlyProfit, " Trades: ", m_monthlyTrades, " Wins: ", m_monthlyWins);
        
        // Imprime os últimos 5 trades para verificação
        int total = m_history.Total();
        int start = (total > 5) ? total - 5 : 0;
        for(int i = start; i < total; i++)
        {
            CTradeRecord* record = m_history.At(i);
            Print(i, ": ", TimeToString(record.time), " - Profit: ", record.profit, " - Win: ", record.isWin, " - Magic: ", m_magicNumber);
        }
    }
};

double CTradeStatistics::GetPayoff(int periodType)
{
    datetime startDate = GetPeriodStart(periodType);
    double totalProfit = 0.0;
    int totalTrades = 0;
    
    for(int i = m_history.Total()-1; i >= 0; i--)
    {
        CTradeRecord* record = m_history.At(i);
        if(record == NULL) continue;
        if(record.time < startDate) break;
 
        totalProfit += record.profit;
        totalTrades++;
    }
    
    if(totalTrades == 0) return 0.0;
    return totalProfit / totalTrades;
}

// Implementação dos métodos
double CTradeStatistics::GetPayoffRatio(int periodType)
{
    //UpdateStatistics(); // Garante que os dados estão atualizados
    
    datetime startDate = GetPeriodStart(periodType);
    double totalProfit = 0.0;
    double totalLoss = 0.0;
    int winCount = 0;
    int lossCount = 0;
    
    for(int i = m_history.Total()-1; i >= 0; i--)
    {
        CTradeRecord* record = m_history.At(i);
        if(record == NULL) continue;
        if(record.time < startDate) break;
        
        if(record.isWin)
        {
            totalProfit += record.profit;
            winCount++;
        }
        else
        {
            totalLoss += MathAbs(record.profit);
            lossCount++;
        }
    }
    
    // Cálculo do Payoff Ratio
    if(lossCount == 0) return (winCount > 0) ? DBL_MAX : 0.0;
    if(winCount == 0) return 0.0;
    
    double avgWin = totalProfit / winCount;
    double avgLoss = totalLoss / lossCount;
    
    return avgWin / avgLoss;
}

void CTradeStatistics::AddTrade(datetime time, double profit, double commission=0, double swap=0)
{
    double netProfit = profit + commission + swap;
    bool isWin = netProfit >= 0;
    
    m_history.Add(new CTradeRecord(time, netProfit, isWin));
    m_lastUpdate = 0; // Invalida cache
}

void CTradeStatistics::UpdateStatistics()
{ 
    //Print("Entrei aqui 111111111111");
    if(m_lastUpdate == TimeCurrent()) return;
    //Print("Entrei aqui 222222222");
    CalculateDailyStats();
    CalculateWeeklyStats();
    CalculateMonthlyStats();
    
    m_lastUpdate = TimeCurrent();
}

double CTradeStatistics::GetProfitFactor(int periodType)
{
    UpdateStatistics();
    
    double grossProfit = 0;
    double grossLoss = 0;
    datetime startDate = GetPeriodStart(periodType);
    
    for(int i = m_history.Total()-1; i >= 0; i--)
    {
        CTradeRecord* record = m_history.At(i);
        if(record.time < startDate) break;
        
        if(record.isWin)
            grossProfit += record.profit;
        else
            grossLoss += MathAbs(record.profit);
    }
    
    return (grossLoss > 0) ? grossProfit / grossLoss : (grossProfit > 0) ? grossProfit : 0;
}

void CTradeStatistics::CalculateDailyStats()
{
    m_dailyProfit = 0;
    m_dailyTrades = 0;
    m_dailyWins = 0;
    
    datetime todayStart = GetPeriodStart(PERIOD_D1);
    for(int i = m_history.Total()-1; i >= 0; i--)
    {
        CTradeRecord* record = m_history.At(i);
        if(record.time < todayStart) break;
        m_dailyProfit += record.profit;
        m_dailyTrades++;
        if(record.isWin) m_dailyWins++;
    }
}

void CTradeStatistics::CalculateWeeklyStats()
{
    m_weeklyProfit = 0;
    m_weeklyTrades = 0;
    m_weeklyWins = 0;
    
    datetime weekStart = GetPeriodStart(PERIOD_W1);
    
    for(int i = m_history.Total()-1; i >= 0; i--)
    {
        CTradeRecord* record = m_history.At(i);
        if(record.time < weekStart) break;
        
        m_weeklyProfit += record.profit;
        m_weeklyTrades++;
        if(record.isWin) m_weeklyWins++;
    }
}

void CTradeStatistics::CalculateMonthlyStats()
{
    m_monthlyProfit = 0;
    m_monthlyTrades = 0;
    m_monthlyWins = 0;
    
    datetime monthStart = GetPeriodStart(PERIOD_MN1);
    
    for(int i = m_history.Total()-1; i >= 0; i--)
    {
        CTradeRecord* record = m_history.At(i);
        if(record.time < monthStart) break;
        
        m_monthlyProfit += record.profit;
        m_monthlyTrades++;
        if(record.isWin) m_monthlyWins++;
    }
}

datetime CTradeStatistics::GetPeriodStart(int periodType)
{
    MqlDateTime current;
    TimeToStruct(TimeCurrent(), current);
    
    switch(periodType)
    {
        case PERIOD_D1:
            current.hour = 0;
            current.min = 0;
            current.sec = 0;
            break;
            
        case PERIOD_W1:
            current.hour = 0;
            current.min = 0;
            current.sec = 0;
            // Ajusta para início da semana (segunda-feira)
            while(current.day_of_week != 1) // 1 = segunda-feira
            {
                current.day--;
                if(current.day < 1)
                {
                    current.mon--;
                    if(current.mon < 1)
                    {
                        current.year--;
                        current.mon = 12;
                    }
                    current.day = GetDaysInMonth(current.mon, current.year);
                }
                current.day_of_week = (current.day_of_week == 0) ? 6 : current.day_of_week - 1;
            }
            break;
            
        case PERIOD_MN1:
            current.day = 1;
            current.hour = 0;
            current.min = 0;
            current.sec = 0;
            break;
    }
    
    return StructToTime(current);
}

int CTradeStatistics::GetDaysInMonth(int month, int year)
{
    if(month == 2) return ((year % 4 == 0 && year % 100 != 0) || year % 400 == 0) ? 29 : 28;
    if(month == 4 || month == 6 || month == 9 || month == 11) return 30;
    return 31;
}
void CTradeStatistics::SyncWithHistory()
{
    m_history.Clear();
    
    // 1. Garanta que o histórico está carregado
    datetime from = D'1970.01.01'; // Data inicial máxima
    datetime to = TimeCurrent();
    
    if(!HistorySelect(from, to))
    {
        Print("Falha ao carregar histórico! Código de erro: ", GetLastError());
        return;
    }
    
    int total = HistoryDealsTotal();
    //Print("Total de negócios no histórico: ", total);
    
    // 2. Varredura detalhada do histórico
    for(int i = 0; i < total; i++)
    {
        ulong ticket = HistoryDealGetTicket(i);
        if(ticket <= 0) continue;
        
        // Debug: imprime todos os negócios
        long magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
        ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
        string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
        
        /*Print(i, " Ticket: ", ticket, 
              " Magic: ", magic, 
              " Entry: ", EnumToString(entry), 
              " Symbol: ", symbol);*/
        
        // Filtra apenas negócios de saída com o magic number correto
        if(entry != DEAL_ENTRY_OUT || magic != m_magicNumber)
            continue;
            
        // Obtém os dados completos
        datetime time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
        double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
        double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
        double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
        
        /*Print("Trade válido encontrado: ", TimeToString(time), 
              " Profit: ", profit, 
              " Commission: ", commission, 
              " Swap: ", swap);*/
        
        AddTrade(time, profit, commission, swap);        
    }
    
    //Print("Total de trades válidos carregados: ", m_history.Total());
    
    // 3. Força atualização imediata
    m_lastUpdate = 0;
    UpdateStatistics();
}