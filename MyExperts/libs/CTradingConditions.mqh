//+------------------------------------------------------------------+
//|                                           CTradingConditions.mqh |
//|                                                    Danne Pereira |
//|                                             https://www.aipi.com |
//+------------------------------------------------------------------+
#property copyright "Danne Pereira"
#property link      "https://www.aipi.com"
#property version   "1.00"
#include <Trade/Trade.mqh>

class CTradingConditions
{
private:
    string        m_expertName;
    int           m_magicNumber;
    bool          m_printedWarning;
    datetime      m_tradingStopTime;
    ENUM_TIMEFRAMES m_timeframe;
    string        m_symbol;
    
    // Configurações de horário
    int           m_startHour, m_startMinute, m_endHour, m_endMinute;
    int           m_closeAfterMinutes;
    CTrade       *m_trade;
    datetime      m_lastCandleTime;
    
public:
    CTradingConditions(CTrade &trade, int magicNumber, 
                      int startHour, int startMinute, int endHour, int endMinute,
                      int closeAfterMinutes, ENUM_TIMEFRAMES timeframe, string symbol) :
        m_trade(GetPointer(trade)),
        m_expertName(ChartGetString(0, CHART_EXPERT_NAME)),
        m_magicNumber(magicNumber),
        m_startHour(startHour),
        m_startMinute(startMinute),
        m_endHour(endHour),
        m_endMinute(endMinute),
        m_closeAfterMinutes(closeAfterMinutes),
        m_printedWarning(false),
        m_timeframe(timeframe),
        m_symbol(symbol),
        m_lastCandleTime(0)
    {}
    
    // --- Verifica horário e fecha posições se necessário ---
    bool IsTradingTimeAllowed()
    {
        MqlDateTime currentTime;
        TimeToStruct(TimeCurrent(), currentTime);
        
        bool isWeekday = (currentTime.day_of_week >= 1 && currentTime.day_of_week <= 5);
        bool isTradingTime = (currentTime.hour > m_startHour || 
                            (currentTime.hour == m_startHour && currentTime.min >= m_startMinute)) &&
                            (currentTime.hour < m_endHour || 
                            (currentTime.hour == m_endHour && currentTime.min < m_endMinute));
        
        // Dentro do horário permitido
        if (isWeekday && isTradingTime) 
        {
            m_printedWarning = false;
            return true;
        }
        // Fora do horário
        else 
        {
            HandleAfterHours();
            return false;
        }
    }
    
    // --- Verifica se é um novo candle ---
    bool IsNewCandle()
    {
        datetime currentCandleTime = iTime(m_symbol, m_timeframe, 0);
        if (m_lastCandleTime == currentCandleTime) 
            return false;
            
        m_lastCandleTime = currentCandleTime;
        return true;
    }
    
    // --- Verifica se o sinal é do mesmo dia ---
    bool IsSignalFromCurrentDay()
    {
        datetime previousCandleTime = iTime(m_symbol, m_timeframe, 1);
        datetime currentCandleTime = iTime(m_symbol, m_timeframe, 0);
        
        MqlDateTime prevTimeStruct, currTimeStruct;
        TimeToStruct(previousCandleTime, prevTimeStruct);
        TimeToStruct(currentCandleTime, currTimeStruct);
        
        return (prevTimeStruct.day == currTimeStruct.day &&
                prevTimeStruct.mon == currTimeStruct.mon &&
                prevTimeStruct.year == currTimeStruct.year);
    }
    
    // Adicione este método público na classe CTradingConditions
   bool CTradingConditions::IsTradingAllowed()
   {
       if(!IsNewCandle()) return false;
       if(!IsSignalFromCurrentDay()) return false;
       if(!IsTradingTimeAllowed()) return false;
       
       return true;
   }
    
private:
    // --- Lógica de fechamento fora do horário ---
    void HandleAfterHours()
    {
        if (!m_printedWarning) 
        {
            Print(m_expertName + ": Fora do horário de trading. Fechando em " + IntegerToString(m_closeAfterMinutes) + " minutos.");
            m_printedWarning = true;
            m_tradingStopTime = TimeCurrent() + (m_closeAfterMinutes * 60);
        }
        
        // Fecha todas as posições após o tempo limite
        if (TimeCurrent() >= m_tradingStopTime) 
        {
            CloseAllPositions();
        }
    }
    
    // --- Fecha todas as posições do Magic Number ---
    void CloseAllPositions()
    {
        m_trade.SetExpertMagicNumber(m_magicNumber);
        
        for (int i = PositionsTotal() - 1; i >= 0; i--) 
        {
            ulong ticket = PositionGetTicket(i);
            if (PositionGetInteger(POSITION_MAGIC) == m_magicNumber) 
            {
                m_trade.PositionClose(ticket);
            }
        }
    }
};