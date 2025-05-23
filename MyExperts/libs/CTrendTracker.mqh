
class CTrendTracker
{
private:
    enum ENUM_TREND_STATE {TREND_UP, TREND_DOWN, TREND_CONGESTION};
    ENUM_TREND_STATE m_lastTrend;
    ENUM_TREND_STATE m_lastNonCongestionTrend;
    datetime m_lastChangeTime;
    
public:
    CTrendTracker() : m_lastTrend(TREND_CONGESTION), m_lastNonCongestionTrend(TREND_CONGESTION), m_lastChangeTime(0) {}
    
    void UpdateTrend(bool isUpTrend, bool isDownTrend)
    {
        ENUM_TREND_STATE currentTrend = TREND_CONGESTION;
        
        if(isUpTrend && !isDownTrend)
            currentTrend = TREND_UP;
        else if(isDownTrend && !isUpTrend)
            currentTrend = TREND_DOWN;
        
        // Atualiza a última tendência não congestionada
        if(currentTrend != TREND_CONGESTION)
            m_lastNonCongestionTrend = currentTrend;
        
        // Registra mudança de tendência
        if(currentTrend != m_lastTrend)
        {
            m_lastTrend = currentTrend;
            m_lastChangeTime = TimeCurrent();
        }
    }
    
    ENUM_TREND_STATE GetLastNonCongestionTrend() const
    {
        return m_lastNonCongestionTrend;
    }
    
    string GetLastNonCongestionTrendString() const
    {
        switch(m_lastNonCongestionTrend)
        {
            case TREND_UP: return "UP";
            case TREND_DOWN: return "DOWN";
            default: return "CONGESTION";
        }
    }
    
    datetime GetLastChangeTime() const
    {
        return m_lastChangeTime;
    }
};