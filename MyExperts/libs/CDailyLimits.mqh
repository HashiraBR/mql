//+------------------------------------------------------------------+
//|                                                  CDailyLimits.mqh |
//|                                                    Danne Pereira |
//|                                             https://www.aipi.com |
//+------------------------------------------------------------------+
#property copyright "Danne Pereira"
#property link      "https://www.aipi.com"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
#include <Trade/DealInfo.mqh>
#include <Trade/PositionInfo.mqh>
#include "CPrintManager.mqh"

class CDailyLimits
{
private:
    int               m_magicNumber;
    double            m_dailyProfitLimit;
    double            m_dailyLossLimit;
    int               m_maxConsecutiveLosses;
    int               m_maxTrades;
    int               m_maxOpenPositions;
    double            m_maxTradeLoss;
    datetime          m_lastCheckDate;
    bool              m_profitLimitReached;
    bool              m_lossLimitReached;
    CDealInfo         m_dealInfo;
    CPositionInfo     m_positionInfo;
    CTrade            m_trade;
    string            m_symbol;
    string            m_expertName;
    
    CPrintManager    *print;
    
    // Métodos privados
    double CalculateDailyProfit();
    int    CountConsecutiveLosses();
    int    CountDailyTrades();
    int    CountOpenPositionsInSymbol();
    void   CancelPendingOrders(int maxAgeSeconds);
    
public:
    // Construtor
    CDailyLimits(int magicNumber, double dailyProfitLimit = 0, double dailyLossLimit = 0, 
                int maxConsecutiveLosses = 0, int maxTrades = 0, int maxOpenPositions = 0,
                double maxTradeLoss = 0, string symbol = NULL);
    ~CDailyLimits();
    
    // Métodos principais
    bool CheckDailyLimits();
    bool IsDailyProfitReached(double offset = 5);
    bool IsDailyLossReached(double offset = 5);
    bool DailyLimitReached();
    bool CheckMaxTradeLoss(ulong ticket);
    
    // Setters para configuração
    void SetDailyProfitLimit(double limit) { m_dailyProfitLimit = limit; }
    void SetDailyLossLimit(double limit) { m_dailyLossLimit = limit; }
    void SetMaxConsecutiveLosses(int limit) { m_maxConsecutiveLosses = limit; }
    void SetMaxTrades(int limit) { m_maxTrades = limit; }
    void SetMaxOpenPositions(int limit) { m_maxOpenPositions = limit; }
    void SetMaxTradeLoss(double limit) { m_maxTradeLoss = limit; }
    void SetSymbol(string symbol) {m_symbol = symbol; }
    
    // Getters para status
    double GetCurrentDailyProfit() { return CalculateDailyProfit(); }
    bool IsProfitLimitReached() const { return m_profitLimitReached; }
    bool IsLossLimitReached() const { return m_lossLimitReached; }
    int GetConsecutiveLosses() { return CountConsecutiveLosses(); }
    int GetDailyTradesCount() { return CountDailyTrades(); }
    int GetTotalOpenPositionsInSymbol() { return CountOpenPositionsInSymbol(); }
    int GetExpertOpenPositionsCount();
};

//+------------------------------------------------------------------+
//| Implementação dos métodos                                        |
//+------------------------------------------------------------------+

CDailyLimits::CDailyLimits(int magicNumber, double dailyProfitLimit, double dailyLossLimit,
                          int maxConsecutiveLosses, int maxTrades, int maxOpenPositions,
                          double maxTradeLoss, string symbol) :
    m_magicNumber(magicNumber),
    m_dailyProfitLimit(dailyProfitLimit),
    m_dailyLossLimit(dailyLossLimit),
    m_maxConsecutiveLosses(maxConsecutiveLosses),
    m_maxTrades(maxTrades),
    m_maxOpenPositions(maxOpenPositions),
    m_maxTradeLoss(maxTradeLoss),
    m_lastCheckDate(0),
    m_profitLimitReached(false),
    m_lossLimitReached(false),
    m_symbol(symbol)
{
    m_expertName = ChartGetString(0, CHART_EXPERT_NAME);
    print = new CPrintManager();
    // Verifica se é um novo dia
    datetime today = iTime(NULL, PERIOD_D1, 0);
    if(m_lastCheckDate != today)
    {
        m_lastCheckDate = today;
        m_profitLimitReached = false;
        m_lossLimitReached = false;
    }
    m_trade.SetExpertMagicNumber(m_magicNumber);
}

CDailyLimits::~CDailyLimits(){
   if(CheckPointer(print) == POINTER_DYNAMIC) delete print;   
}

double CDailyLimits::CalculateDailyProfit()
{
    double totalProfit = 0;
    datetime todayStart = iTime(NULL, PERIOD_D1, 0);
    
    // Verifica se é um novo dia
    if(m_lastCheckDate != todayStart)
    {
        m_lastCheckDate = todayStart;
        m_profitLimitReached = false;
        m_lossLimitReached = false;
        
        print.ResetAllFlags();
    }
    
    // Calcula lucro de negócios fechados hoje usando CDealInfo
    if(HistorySelect(todayStart, TimeCurrent()))
    {
        int totalDeals = HistoryDealsTotal();
        for(int i = 0; i < totalDeals; i++)
        {
            ulong ticket = HistoryDealGetTicket(i);
            if(m_dealInfo.SelectByIndex(i) && 
               m_dealInfo.Magic() == m_magicNumber &&
               m_dealInfo.Entry() == DEAL_ENTRY_OUT)
            {
                totalProfit += m_dealInfo.Profit();
            }
        }
    }
    
    // Adiciona lucro de posições abertas (não realizado)
    // Motivo: o EA fecha os trades quando alcançar algum limite de loss ou gain
    for(int i = PositionsTotal()-1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(m_positionInfo.SelectByIndex(i) && 
           m_positionInfo.Magic() == m_magicNumber)
        {
            totalProfit += m_positionInfo.Profit();
        }
    }
    
    return totalProfit;
}

int CDailyLimits::CountConsecutiveLosses()
{
    int consecutiveLosses = 0;
    datetime todayStart = iTime(NULL, PERIOD_D1, 0);
    
    if(HistorySelect(todayStart, TimeCurrent()))
    {
        int totalDeals = HistoryDealsTotal();
        for(int i = totalDeals-1; i >= 0; i--)
        {
            ulong ticket = HistoryDealGetTicket(i);
            if(m_dealInfo.SelectByIndex(i) && 
               m_dealInfo.Magic() == m_magicNumber)
            {
                if(m_dealInfo.Entry() == DEAL_ENTRY_OUT)
                {
                    if(m_dealInfo.Profit() < 0)
                        consecutiveLosses++;
                    else
                        break; // Sai do loop quando encontra um lucro
                }
            }
        }
    }
    
    return consecutiveLosses;
}

int CDailyLimits::CountDailyTrades()
{
    int tradesCount = 0;
    datetime todayStart = iTime(NULL, PERIOD_D1, 0);
    
    if(HistorySelect(todayStart, TimeCurrent()))
    {
        int totalDeals = HistoryDealsTotal();
        for(int i = 0; i < totalDeals; i++)
        {
            ulong ticket = HistoryDealGetTicket(i);
            if(m_dealInfo.SelectByIndex(i) && 
               m_dealInfo.Magic() == m_magicNumber &&
               m_dealInfo.Entry() == DEAL_ENTRY_IN)
            {
                tradesCount++;
            }
        }
    }
    
    return tradesCount;
}

int CDailyLimits::CountOpenPositionsInSymbol()
{
    int count = 0;
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (PositionSelectByTicket(ticket) && 
            PositionGetString(POSITION_SYMBOL) == m_symbol) // Apenas símbolo atual
        {
            count++;
        }
    }
    return count;
}

int CDailyLimits::GetExpertOpenPositionsCount()
{
    int count = 0;
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (m_positionInfo.SelectByIndex(i) && 
            m_positionInfo.Magic() == m_magicNumber && // Filtro por Magic
            m_positionInfo.Symbol() == m_symbol)        // + símbolo atual
        {
            count++;
        }
    }
    return count;
}

bool CDailyLimits::IsDailyProfitReached(double offset = 5)
{
    if(m_dailyProfitLimit <= 0) return false;
    
    double dailyProfit = CalculateDailyProfit();
    m_profitLimitReached = (dailyProfit >= m_dailyProfitLimit + offset);
    
    /*if(m_profitLimitReached && !m_printedProfitLimitReached){
        Print("Limite diário de lucro atingido: ", dailyProfit, " (Limite: ", m_dailyProfitLimit, ")");
        m_printedProfitLimitReached = true;
     }*/
     
     if(m_profitLimitReached)
         print.PrintOnce("PROFIT_LIMIT", "Limite diário de lucro atingido: " + StringFormat("%.2f", dailyProfit) + " (Limite: " + StringFormat("%.2f", m_dailyProfitLimit) + ")");
    
    return m_profitLimitReached;
}

bool CDailyLimits::IsDailyLossReached(double offset)
{
    if(m_dailyLossLimit <= 0) return false;
    
    double dailyProfit = CalculateDailyProfit();
    m_lossLimitReached = (dailyProfit + offset <= -m_dailyLossLimit);
    
    /*if(m_lossLimitReached && !m_printedLossLimitReached){
        Print("Limite diário de perda atingido: ", dailyProfit, " (Limite: ", -m_dailyLossLimit, ")");
        m_printedLossLimitReached = true;
    }*/
    if(m_lossLimitReached)
      print.PrintOnce("LOSS_LIMIT", "Limite diário de perda atingido: " +  StringFormat("%.2f", dailyProfit) + " (Limite: " +  StringFormat("%.2f", -m_dailyProfitLimit) + ")");
    
    return m_lossLimitReached;
}

bool CDailyLimits::DailyLimitReached()
{
    return IsDailyProfitReached() || IsDailyLossReached();
}

bool CDailyLimits::CheckMaxTradeLoss(ulong ticket)
{
    if(m_maxTradeLoss <= 0) return false;
    
    if(m_positionInfo.SelectByTicket(ticket) && 
       m_positionInfo.Magic() == m_magicNumber)
    {
        double currentProfit = m_positionInfo.Profit();
        if(currentProfit < -m_maxTradeLoss)
        {
            for(int attempt = 0; attempt < 3; attempt++)
            {
                if(m_trade.PositionClose(ticket))
                {
                    Print("Posição ", ticket, " fechada (Prejuízo: ", -currentProfit, " > Limite: ", m_maxTradeLoss, ")");
                    return true;
                }
                Sleep(1000);
            }
            Print("Falha ao fechar posição ", ticket, ". Erro: ", GetLastError());
        }
    }
    return false;
}

bool CDailyLimits::CheckDailyLimits()
{
    // Verifica limites diários de lucro/perda
    bool dailyLimitReached = DailyLimitReached();
    
    // Verifica perda máxima por trade
    for(int i = PositionsTotal()-1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(CheckMaxTradeLoss(ticket))
        {
            // Trade foi fechado por exceder o limite de perda
            return false;
        }
    }
    
    // Verifica perdas consecutivas
    int consecutiveLosses = CountConsecutiveLosses();
    if(m_maxConsecutiveLosses > 0 && consecutiveLosses >= m_maxConsecutiveLosses)
    {
        /*if(!m_printedMaxConsecutiveLosses)
        {
            Print("Limite máximo de perdas consecutivas atingido: ", consecutiveLosses);
            m_printedMaxConsecutiveLosses = true;
        }*/
        
        print.PrintOnce("MAX_CONSECUTIVE_LOSSES", "Limite máximo de perdas consecutivas atingido: " + IntegerToString(consecutiveLosses));
        dailyLimitReached = true;
    }
    
    // Verifica limite de trades por dia
    int tradesCount = CountDailyTrades();
    if(m_maxTrades > 0 && tradesCount >= m_maxTrades)
    {
        /*if(!m_printedMaxLimitTrades)
        {
            Print("Limite máximo de trades por dia atingido: ", tradesCount);
            m_printedMaxLimitTrades = true;
        }*/
        print.PrintOnce("MAX_TRADES", "Limite máximo de trades por dia: " + IntegerToString(tradesCount));
        dailyLimitReached = true;
    }
    
    // Se necessário, fecha todas as posições
    if(dailyLimitReached)
    {
        /*if(!m_printedDailyLimitReached){
            Print("Fechando todas as posições devido a limite atingido");
            m_printedDailyLimitReached = true;
        }*/
        print.PrintOnce("ANY_LIMIT_REACHED", "Fechando todas as posições devido a limite atingido");
        
        for(int i = PositionsTotal()-1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(m_positionInfo.SelectByTicket(ticket) && 
               m_positionInfo.Magic() == m_magicNumber)
            {
                if(!m_trade.PositionClose(ticket))
                {
                    Print("Falha ao fechar posição #", ticket, ". Erro: ", GetLastError());
                }
            }
        }
    }
    
    
    // Verifica limite de posições abertas
    int openPositions = CountOpenPositionsInSymbol();
    if(m_maxOpenPositions > 0 && openPositions >= m_maxOpenPositions)
    {
        CDailyLimits::CancelPendingOrders(0);
        /*if(!m_printedMaxOpenPositions){
           Print("Limite máximo de posições abertas atingido: ", openPositions, " Cancelando ordens pendentes.");
           m_printedMaxOpenPositions = true;
        }*/
        print.PrintOnce("MAX_OPEN_POSITION", "Limite máximo de posições abertas atingido: " + IntegerToString(openPositions) + ". Cancelando ordens pendentes.");
        dailyLimitReached = true;
    }
    
    
    return !dailyLimitReached; // Retorna true se trading permitido
}

void CDailyLimits::CancelPendingOrders(int maxAgeSeconds){
  datetime currentTime = TimeCurrent();
  
  for(int i = OrdersTotal() - 1; i >= 0; i--)
  {
      ulong ticket = OrderGetTicket(i);
      if(OrderGetInteger(ORDER_MAGIC) == m_magicNumber)
      {
         ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         
         // Filtra apenas ordens pendentes
         if(orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_SELL_LIMIT ||
           orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_SELL_STOP)
         {
            datetime orderTime = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
            
            // Verifica expiração
            if((currentTime - orderTime) >= maxAgeSeconds)
            {
                if(m_trade.OrderDelete(ticket))
                {
                    PrintFormat("%s Ordem pendente #%d cancelada (expirada após %d segundos)",
                              m_expertName, ticket, maxAgeSeconds);
                }
                else
                {
                    PrintFormat("%s ERRO ao cancelar ordem #%d (Código: %d)",
                              m_expertName, ticket, GetLastError());
                }
            }
         }
      }
  }
}
