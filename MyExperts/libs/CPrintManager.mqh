//+------------------------------------------------------------------+
//|                                            CPrintManager.mqh |
//|                                                    Danne Pereira |
//|                                             https://www.aipi.com |
//+------------------------------------------------------------------+
#property copyright "Danne Pereira"
#property link      "https://www.aipi.com"
#property version   "1.00"


//+------------------------------------------------------------------+
//| CPrintManager - Gerenciador automático de flags de impressão |
//+------------------------------------------------------------------+
class CPrintManager
{
private:
    struct FlagPair
    {
        string key;
        bool wasPrinted;
    };
    
    FlagPair m_flags[];
    bool m_debugMode;
    
    /**
     * Encontra o índice de uma flag
     * @param key Nome da flag
     * @return Índice ou -1 se não encontrado
     */
    int FindFlagIndex(const string key) const
    {
        for(int i = 0; i < ArraySize(m_flags); i++)
        {
            if(m_flags[i].key == key)
            {
                return i;
            }
        }
        return -1;
    }

public:
    //--- Construtor e destrutor ---//
    CPrintManager(bool debugMode = true) : m_debugMode(debugMode) {}
    ~CPrintManager() {}

    //--- Métodos principais ---//
    
    /**
     * Imprime a mensagem apenas uma vez (gerencia flags automaticamente)
     * @param key Nome único da mensagem/chave
     * @param message Mensagem a ser impressa
     * @return true se a mensagem foi impressa, false se já tinha sido impressa antes
     */
    bool PrintOnce(const string key, const string message)
    {
        int idx = FindFlagIndex(key);
        
        // Se não encontrou, cria nova flag
        if(idx == -1)
        {
            FlagPair newFlag;
            newFlag.key = key;
            newFlag.wasPrinted = false;
            
            ArrayResize(m_flags, ArraySize(m_flags) + 1);
            m_flags[ArraySize(m_flags) - 1] = newFlag;
            idx = ArraySize(m_flags) - 1;
        }
        
        // Verifica se pode imprimir
        if(!m_flags[idx].wasPrinted)
        {
            Print(message);
            m_flags[idx].wasPrinted = true;
            return true;
        }
        return false;
    }
    
    /**
     * Reseta todas as flags para permitir novos prints
     */
    void ResetAllFlags()
    {
        for(int i = 0; i < ArraySize(m_flags); i++)
        {
            m_flags[i].wasPrinted = false;
        }
    }
    
    /**
     * Reseta uma flag específica para permitir novo print
     * @param key Nome da flag a ser resetada
     */
    void ResetFlag(const string key)
    {
        int idx = FindFlagIndex(key);
        if(idx != -1)
        {
            m_flags[idx].wasPrinted = false;
        }
    }
    
    /**
     * Verifica se uma mensagem já foi impressa
     * @param key Nome da flag/mensagem
     * @return true se já foi impressa
     */
    bool WasPrinted(const string key) const
    {
        int idx = FindFlagIndex(key);
        return (idx != -1) ? m_flags[idx].wasPrinted : false;
    }
    
    void DebugPrint(string s)
    {    
         if(m_debugMode)
            Print(s);
    }
    
    void ErrorPrint(string s)
    {    
         if(m_debugMode)
            Print(s);
    }
};