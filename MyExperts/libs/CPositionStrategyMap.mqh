/*class PositionStrategyMap
{
private:
    struct StrategyTicketPair
    {
        int strategyIndex;
        ulong ticket;
    };
    
    StrategyTicketPair m_pairs[];
    int m_count;
    
    int FindIndex(int strategyIndex) const
    {
        for(int i = 0; i < m_count; i++)
            if(m_pairs[i].strategyIndex == strategyIndex)
                return i;
        return -1;
    }

    int FindIndexByTicket(ulong ticket) const
    {
        for(int i = 0; i < m_count; i++)
            if(m_pairs[i].ticket == ticket)
                return i;
        return -1;
    }

public:
    PositionStrategyMap() : m_count(0)
    {
        ArrayResize(m_pairs, 16);
    }
    
    void Add(int strategyIndex, ulong ticket)
    {
        int index = FindIndex(strategyIndex);
        
        if(index >= 0)
        {
            m_pairs[index].ticket = ticket;
        }
        else
        {
            if(m_count >= ArraySize(m_pairs))
                ArrayResize(m_pairs, m_count + 16);
                
            m_pairs[m_count].strategyIndex = strategyIndex;
            m_pairs[m_count].ticket = ticket;
            m_count++;
        }
    }
    
    ulong Get(int strategyIndex) const
    {
        int index = FindIndex(strategyIndex);
        return (index >= 0) ? m_pairs[index].ticket : 0;
    }
    
    void Remove(int strategyIndex)
    {
        int index = FindIndex(strategyIndex);
        if(index < 0) return;
        
        for(int i = index; i < m_count - 1; i++)
            m_pairs[i] = m_pairs[i + 1];
            
        m_count--;
    }
    
    void RemoveByTicket(ulong ticket)
    {
        int index = FindIndexByTicket(ticket);
        if(index >= 0)
        {
            for(int i = index; i < m_count - 1; i++)
                m_pairs[i] = m_pairs[i + 1];
            m_count--;
        }
    }
    
    void Cleanup()
    {
        for(int i = m_count - 1; i >= 0; i--)
        {
            if(!PositionSelectByTicket(m_pairs[i].ticket))
                Remove(m_pairs[i].strategyIndex);
        }
    }
    
    int GetTotalEntries() const { return m_count; }
};
*/

//+------------------------------------------------------------------+
//| PositionStrategyMap - Mapeamento estratégia→ticket               |
//+------------------------------------------------------------------+
class PositionStrategyMap
{
private:
    struct StrategyTicketPair
    {
        int strategyIndex;
        ulong ticket;
    };
    
    StrategyTicketPair m_pairs[];
    int m_count;
    
    int FindIndex(int strategyIndex) const
    {
        for(int i = 0; i < m_count; i++)
            if(m_pairs[i].strategyIndex == strategyIndex)
                return i;
        return -1;
    }

public:
    PositionStrategyMap() : m_count(0)
    {
        ArrayResize(m_pairs, 16); // Tamanho inicial
    }
    
    void Add(int strategyIndex, ulong ticket)
    {
        int index = FindIndex(strategyIndex);
        
        if(index >= 0)
        {
            // Atualiza ticket existente
            m_pairs[index].ticket = ticket;
        }
        else
        {
            // Adiciona novo par
            if(m_count >= ArraySize(m_pairs))
                ArrayResize(m_pairs, m_count + 16);
                
            m_pairs[m_count].strategyIndex = strategyIndex;
            m_pairs[m_count].ticket = ticket;
            m_count++;
        }
    }
    
    ulong Get(int strategyIndex) const
    {
        int index = FindIndex(strategyIndex);
        return (index >= 0) ? m_pairs[index].ticket : 0;
    }
    
    void Remove(int strategyIndex)
    {
        int index = FindIndex(strategyIndex);
        if(index < 0) return;
        
        // Move todos os elementos após o índice para preencher o espaço
        for(int i = index; i < m_count - 1; i++)
            m_pairs[i] = m_pairs[i + 1];
            
        m_count--;
    }
    
    void Cleanup()
    {
        for(int i = m_count - 1; i >= 0; i--)
        {
            if(!PositionSelectByTicket(m_pairs[i].ticket))
                Remove(m_pairs[i].strategyIndex);
        }
    }
    
    int GetCount() const { return m_count; }
};