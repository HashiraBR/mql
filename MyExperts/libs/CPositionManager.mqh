/*//+------------------------------------------------------------------+
//|                                                  PositionManager.mqh |
//|                        Copyright © 2023, Danne M. G. Pereira     |
//|                              www.aipi.com.br                     |
//+------------------------------------------------------------------+
#include <Arrays\ArrayLong.mqh>
#include "CPositionStrategyMap.mqh"
#include "structs/PositionParams.mqh"

// Implementação de seção crítica leve
class CSectionLock
{
private:
    bool m_locked;
public:
    CSectionLock() : m_locked(false) {}
    void Lock() { while(m_locked) Sleep(1); m_locked = true; }
    void Unlock() { m_locked = false; }
};


class CPositionManager {
private:
    CArrayLong           m_tickets;
    PositionParams       m_params[];
    int                  m_maxPositions;
    PositionStrategyMap  m_strategyMap;
    CSectionLock         m_lock;
    
    void RemoveArrayElement(int index) {
        if(index < 0 || index >= ArraySize(m_params)) return;
        
        if(index < ArraySize(m_params)-1) {
            // Copia manualmente os elementos string
            for(int j = index; j < ArraySize(m_params)-1; j++) {
                m_params[j] = m_params[j+1];
            }
        }
        ArrayResize(m_params, ArraySize(m_params)-1);
    }
    
public:
    CPositionManager(int maxPositions) : m_maxPositions(maxPositions) {
        ArrayResize(m_params, 0);
    }
    
    ulong GetTicket(int index) {
        m_lock.Lock();
        ulong result = 0;
        if(index >= 0 && index < m_tickets.Total()) {
            result = m_tickets.At(index);
        }
        m_lock.Unlock();
        return result;
    }
    
    bool AddPosition(ulong ticket, const PositionParams &params) {
        m_lock.Lock();
        bool result = false;
        
        if(ticket == 0) {
            Print("Ticket inválido (zero)");
        }
        else if(!PositionSelectByTicket(ticket)) {
            Print("Ticket não existe: ", ticket);
        }
        else if(m_tickets.SearchLinear(ticket) >= 0) {
            Print("Ticket duplicado: ", ticket);
        }
        else if(m_tickets.Total() >= m_maxPositions) {
            Print("Limite máximo de posições atingido: ", m_maxPositions);
        }
        else {
            int newIndex = m_tickets.Add(ticket);
            if(newIndex >= 0) {
                if(ArrayResize(m_params, newIndex + 1) == newIndex + 1) {
                    m_params[newIndex] = params;
                    result = true;
                }
                else {
                    m_tickets.Delete(newIndex);
                    Print("Falha ao redimensionar array de parâmetros");
                }
            }
        }
        
        m_lock.Unlock();
        return result;
    }
    
    bool RemovePosition(ulong ticket) {
        m_lock.Lock();
        bool result = false;
        
        for(int i = m_tickets.Total()-1; i >= 0; i--) {
            if(m_tickets.At(i) == ticket) {
                if(m_tickets.Delete(i)) {
                    RemoveArrayElement(i);
                    m_strategyMap.RemoveByTicket(ticket);
                    result = true;
                }
                break;
            }
        }
        
        m_lock.Unlock();
        return result;
    }
    
    bool GetPositionParams(ulong ticket, PositionParams &params) {
        m_lock.Lock();
        bool found = false;
        
        for(int i = 0; i < m_tickets.Total(); i++) {
            if(m_tickets.At(i) == ticket) {
                params = m_params[i];
                found = true;
                break;
            }
        }
        
        m_lock.Unlock();
        return found;
    }
    
    void CleanUp() {
        m_lock.Lock();
        int removed = 0;
        
        for(int i = m_tickets.Total()-1; i >= 0; i--) {
            ulong ticket = m_tickets.At(i);
            if(!PositionSelectByTicket(ticket)) {
                if(m_tickets.Delete(i)) {
                    RemoveArrayElement(i);
                    m_strategyMap.RemoveByTicket(ticket);
                    removed++;
                }
            }
        }
        
        if(removed > 0) {
            Print("Posições removidas: ", removed);
        }
        m_lock.Unlock();
    }
    
    int GetTotalPositions() const {
        return m_tickets.Total();
    }
    
    bool CanAddNewPosition() const {
        return m_tickets.Total() < m_maxPositions;
    }
    
    void AddStrategyPosition(int strategyIndex, ulong ticket) {
        m_lock.Lock();
        if(ticket != 0 && PositionSelectByTicket(ticket)) {
            m_strategyMap.Add(strategyIndex, ticket);
        }
        m_lock.Unlock();
    }
    
    ulong GetStrategyPosition(int strategyIndex) {
        m_lock.Lock();
        ulong result = m_strategyMap.Get(strategyIndex);
        m_lock.Unlock();
        return result;
    }
    
    void RemoveStrategyPosition(int strategyIndex) {
        m_lock.Lock();
        m_strategyMap.Remove(strategyIndex);
        m_lock.Unlock();
    }
    
    void Debug() {
        m_lock.Lock();
        Print("=== DEBUG PositionManager ===");
        Print("Total: ", m_tickets.Total(), "/", m_maxPositions);
        
        for(int i = 0; i < m_tickets.Total(); i++) {
            PositionParams p = m_params[i];
            Print(i, ": Ticket=", m_tickets.At(i),
                  " Type=", EnumToString(p.positionType),
                  " Lots=", p.lotSize,
                  " SL=", p.stopLoss,
                  " TP=", p.takeProfit,
                  " Open=", p.openPrice,
                  " Time=", TimeToString(p.openTime));
        }
        m_lock.Unlock();
    }
};

*/





//+------------------------------------------------------------------+
//|                                                  PositionManager.mqh |
//|                        Copyright © 2023, Danne M. G. Pereira     |
//|                              www.aipi.com.br                     |
//+------------------------------------------------------------------+
#include <Arrays\ArrayLong.mqh>  // Alterado para ArrayULong
#include "CPositionStrategyMap.mqh"
#include "structs/PositionParams.mqh"


class CPositionManager {
private:
    CArrayLong m_tickets;  // Alterado para CArrayULong
    PositionParams m_params[];
    int m_maxPositions;
    PositionStrategyMap m_strategyMap;
    
    void RemoveArrayElement(PositionParams &array[], int index) {
        int size = ArraySize(array);
        if(index >= 0 && index < size) {
            for(int i = index; i < size - 1; i++) {
                array[i] = array[i + 1];
            }
            ArrayResize(array, size - 1);
        }
    }
    
public:
    CPositionManager(int maxPositions) : m_maxPositions(maxPositions) {
        ArrayResize(m_params, m_maxPositions);
    }
    
    ulong GetTicket(const int index) const {
        if(index >= 0 && index < m_tickets.Total()) {
            return m_tickets.At(index);  // Retorna ulong diretamente
        }
        Print("Erro: Índice ", index, " fora dos limites");
        return 0;  // Retorna 0 em caso de erro
    }
    
    bool AddPosition(ulong ticket, const PositionParams &params) {
        // Validação rigorosa do ticket
        if(ticket == 0 || ticket == ULONG_MAX) {
            Print("Erro: Ticket inválido (", ticket, ")");
            return false;
        }
        
        // Verifica se a posição existe
        if(!PositionSelectByTicket(ticket)) {
            Print("Erro: Ticket ", ticket, " não corresponde a uma posição existente");
            return false;
        }
        
        // Verificação de duplicidade
        for(int i = 0; i < m_tickets.Total(); i++) {
            if(m_tickets.At(i) == ticket) {  // Comparação direta sem cast
                Print("Erro: Ticket ", ticket, " já existe na posição ", i);
                return false;
            }
        }
        
        // Verifica limite máximo de posições
        if(m_tickets.Total() >= m_maxPositions) {
            Print("Erro: Limite máximo de posições (", m_maxPositions, ") atingido");
            return false;
        }
        
        // Adição segura
        int index = m_tickets.Add(ticket);  // Sem cast necessário
        if(index < 0) {
            Print("Falha ao adicionar ticket à coleção");
            return false;
        }
        
        if(ArrayResize(m_params, index + 1) != index + 1) {
            m_tickets.Delete(index);
            Print("Falha ao redimensionar array de parâmetros");
            return false;
        }
        
        m_params[index] = params;
        Print("Ticket ", ticket, " adicionado com sucesso no índice ", index);
        return true;
    }
    
    bool RemovePosition(ulong ticket) {
        for(int i = 0; i < m_tickets.Total(); i++) {
            if(m_tickets.At(i) == ticket) {  // Comparação direta sem cast
                m_tickets.Delete(i);
                RemoveArrayElement(m_params, i);
                Print("Ticket ", ticket, " removido com sucesso");
                return true;
            }
        }
        Print("Erro: Ticket ", ticket, " não encontrado para remoção");
        return false;
    }
    
    bool GetParams(ulong ticket, PositionParams &params) const {
        for(int i = 0; i < m_tickets.Total(); i++) {
            if(m_tickets.At(i) == ticket) {  // Comparação direta sem cast
                params = m_params[i];
                return true;
            }
        }
        Print("Erro: Parâmetros não encontrados para o ticket ", ticket);
        return false;
    }
    
    void CleanUp() {
        int removed = 0;
        for(int i = m_tickets.Total()-1; i >= 0; i--) {
            ulong ticket = m_tickets.At(i);
            if(!PositionSelectByTicket(ticket)) {
                m_tickets.Delete(i);
                RemoveArrayElement(m_params, i);
                removed++;
            }
        }
        if(removed > 0) {
            Print("Limpeza realizada: ", removed, " posições inválidas removidas");
        }
    }
    
    void CleanInvalidTickets() {
        int removed = 0;
        for(int i = m_tickets.Total()-1; i >= 0; i--) {
            ulong ticket = m_tickets.At(i);
            if(ticket == 0 || ticket == ULONG_MAX || !PositionSelectByTicket(ticket)) {
                Print("Removendo ticket inválido: ", ticket);
                m_tickets.Delete(i);
                RemoveArrayElement(m_params, i);
                removed++;
            }
        }
        if(removed > 0) {
            Print("Removidos ", removed, " tickets inválidos");
        }
    }
    
    int Total() const { return m_tickets.Total(); }
    bool CanAddNewPosition() const { return Total() < m_maxPositions; }
    
    void AddStrategyPosition(int strategyIndex, ulong ticket) {
        if(ticket == 0 || ticket == ULONG_MAX) {
            Print("Erro: Não é possível adicionar ticket inválido à estratégia");
            return;
        }
        m_strategyMap.Add(strategyIndex, ticket);
    }
    
    ulong GetStrategyPosition(int strategyIndex) const {
        return m_strategyMap.Get(strategyIndex);
    }
    
    void RemoveStrategyPosition(int strategyIndex) {
        m_strategyMap.Remove(strategyIndex);
    }
    
    void CleanupStrategyMap() {
        m_strategyMap.Cleanup();
    }
    
    // Método de debug adicional
    void Debug() const {
        Print("=== DEBUG PositionManager ===");
        Print("Total positions: ", Total());
        Print("Max positions: ", m_maxPositions);
        
        for(int i = 0; i < Total(); i++) {
            ulong ticket = m_tickets.At(i);
            Print(i, ": Ticket=", ticket);
        }
    }
    
};