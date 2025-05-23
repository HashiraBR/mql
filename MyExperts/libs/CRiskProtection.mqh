//+------------------------------------------------------------------+
//|                                                  CRiskProtection.mqh |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.metaquotes.net/ |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include "CUtils.mqh"

enum ENUM_SL_STRATEGY {
   SL_FIXED,          // Stop Loss fixo
   SL_TRAILING,       // Trailing Stop
   SL_PROGRESSIVE,    // Stop progressivo
   SL_BREAKEVEN,      // Move para o preço de abertura
   SL_HYBRID          // Combinação de estratégias
};

enum ENUM_RISK_ERROR {
   RISK_ERROR_OK = 0,               // Operação bem sucedida
   RISK_ERROR_INVALID_PARAM,        // Parâmetro inválido
   RISK_ERROR_POSITION_NOT_FOUND,   // Posição não encontrada
   RISK_ERROR_MODIFY_FAILED,        // Falha ao modificar posição
   RISK_ERROR_SL_BELOW_ZERO,        // SL abaixo de zero
   RISK_ERROR_INVALID_SL_STRATEGY,  // Estratégia de SL inválida
   RISK_ERROR_INVALID_TP_STRATEGY,  // Estratégia de TP inválida
   RISK_ERROR_WRONG_POSITION        // Posição não existente
};

class CRiskProtection
{
private:
    CTrade           *m_trade;               // Ponteiro para objeto CTrade
    CPositionInfo     m_position;            // Para obter informações de posição
    int               m_magicNumber;         // Magic number do EA
    string            m_symbol;              // Símbolo negociado
    string            m_expertName;          // Nome do EA
    // Método privado para modificar SL
    bool              ModifySL(ulong ticket, double newSl, double currentTp);
    ENUM_RISK_ERROR   m_lastError;           // Último erro ocorrido
    string            m_errorDescription;    // Descrição do erro
    double            m_stopLossPrice;       // Stop Loss em preço
    double            m_stopLossPoint;       // Stop Loss em Pontos
    
public:
    // Construtor/Destrutor
                     CRiskProtection(CTrade &trade, int magicNumber, string symbol);
                    ~CRiskProtection() {};
    
    //--- Métodos de Proteção ---//
    void              StopLossAtBreakeven(double minProfitPoints, double slOffset);
    void              MonitorTrailingStop(double trailingStart, double stopLoss);
    void              ProgressiveProfitProtection(double stepPoints, double protectPercent);
    ENUM_RISK_ERROR   MonitorStopLoss(ENUM_SL_STRATEGY slStrategy, double stopLoss = 0, double trailingStart = 0, double breakevenProfit = 0, double progressiveStep = 0, double progressivePercent = 0);    
    
    void              StopLossAtBreakevenByTicket(ulong ticket, double minProfitPoints, double slOffset = 0);
    void              MonitorTrailingStopByTicket(ulong ticket, double trailingStart, double stopLoss);
    void              ProgressiveProfitProtectionByTicket(ulong ticket, double stepPoints, double protectPercent);
    ENUM_RISK_ERROR   MonitorStopLossByTicket(ulong ticket, ENUM_SL_STRATEGY slStrategy, 
                                            double stopLoss = 0, double trailingStart = 0, 
                                            double breakevenProfit = 0, double progressiveStep = 0, 
                                            double progressivePercent = 0);
    
    static void VerifyPositionSafety(CTrade &trade, ulong ticket, double sl, double tp); //Altere o nome dessa função para algo mais apropriado
    
    //--- Métodos de informação ---//
    ENUM_RISK_ERROR  GetLastError() const { return m_lastError; }
    string           GetLastErrorText() const { return m_errorDescription; }
    string           GetExpertName() const { return m_expertName; }
    double           CRiskProtection::GetStopLossPoint(){ return m_stopLossPoint; }
    double           CRiskProtection::GetStopLossPrice(){ return m_stopLossPrice; }
};

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
CRiskProtection::CRiskProtection(CTrade &trade, int magicNumber, string symbol) :
    m_magicNumber(magicNumber),
    m_symbol(symbol)
{
    m_stopLossPoint = -1.0;
    m_stopLossPrice = -1.0;
    m_trade = GetPointer(trade);
    m_expertName = ChartGetString(0, CHART_EXPERT_NAME);
    m_trade.SetExpertMagicNumber(m_magicNumber);
    m_lastError = RISK_ERROR_OK;
}

//+------------------------------------------------------------------+
//| Define SL no preço de abertura quando atingir lucro mínimo       |
//+------------------------------------------------------------------+
void CRiskProtection::StopLossAtBreakeven(double minProfitPoints, double slOffset = 0)
{
    for(int i = PositionsTotal()-1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(m_position.SelectByTicket(ticket) && 
           m_position.Magic() == m_magicNumber &&
           m_position.Symbol() == m_symbol)
        {
            double openPrice = m_position.PriceOpen();
            double currentPrice = m_position.PriceCurrent();
            double currentSl = m_position.StopLoss();
            double profitPoints = 0;
            
            if(m_position.PositionType() == POSITION_TYPE_BUY)
                profitPoints = (currentPrice - openPrice) / _Point;
            else
                profitPoints = (openPrice - currentPrice) / _Point;
            
            if(profitPoints >= minProfitPoints)
            {
                double newSl = (m_position.PositionType() == POSITION_TYPE_BUY) 
                             ? openPrice + slOffset * _Point 
                             : openPrice - slOffset * _Point;
                             
                if((m_position.PositionType() == POSITION_TYPE_BUY && newSl > currentSl) ||
                   (m_position.PositionType() == POSITION_TYPE_SELL && newSl < currentSl))
                {
                    ModifySL(ticket, newSl, m_position.TakeProfit());
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Trailing Stop dinâmico                                           |
//+------------------------------------------------------------------+
void CRiskProtection::MonitorTrailingStop(double trailingStart, double stopLoss)
{
    for(int i = PositionsTotal()-1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(m_position.SelectByTicket(ticket) && 
           m_position.Magic() == m_magicNumber &&
           m_position.Symbol() == m_symbol)
        {
            double currentSl = m_position.StopLoss();
            double currentPrice = m_position.PriceCurrent();
            double openPrice = m_position.PriceOpen();
            double pointsProfit = 0;
            
            if(m_position.PositionType() == POSITION_TYPE_BUY)
            {
                pointsProfit = (currentPrice - openPrice) / _Point;
                if(pointsProfit >= trailingStart)
                {
                    double newSl = currentPrice - stopLoss * _Point;
                    if(newSl > currentSl)
                        ModifySL(ticket, newSl, m_position.TakeProfit());
                }
            }
            else // POSITION_TYPE_SELL
            {
                pointsProfit = (openPrice - currentPrice) / _Point;
                if(pointsProfit >= trailingStart)
                {
                    double newSl = currentPrice + stopLoss * _Point;
                    if(newSl < currentSl)
                        ModifySL(ticket, newSl, m_position.TakeProfit());
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Proteção progressiva de lucro                                    |
//+------------------------------------------------------------------+
void CRiskProtection::ProgressiveProfitProtection(double stepPoints, double protectPercent)
{
    protectPercent = MathMin(MathMax(protectPercent, 0.1), 0.9); // Limita entre 10% e 90%
    
    for(int i = PositionsTotal()-1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(m_position.SelectByTicket(ticket) && 
           m_position.Magic() == m_magicNumber &&
           m_position.Symbol() == m_symbol)
        {
            double openPrice = m_position.PriceOpen();
            double currentPrice = m_position.PriceCurrent();
            double currentSl = m_position.StopLoss();
            double profitPoints = 0;
            
            if(m_position.PositionType() == POSITION_TYPE_BUY)
                profitPoints = (currentPrice - openPrice) / _Point;
            else
                profitPoints = (openPrice - currentPrice) / _Point;
            
            if(profitPoints >= stepPoints)
            {
                int steps = int(profitPoints / stepPoints);
                double newSl = 0;
                
                if(m_position.PositionType() == POSITION_TYPE_BUY)
                {
                    newSl = openPrice + (stepPoints * steps * protectPercent * _Point);
                    if(newSl > currentSl)
                        ModifySL(ticket, newSl, m_position.TakeProfit());
                }
                else
                {
                    newSl = openPrice - (stepPoints * steps * protectPercent * _Point);
                    if(newSl < currentSl)
                        ModifySL(ticket, newSl, m_position.TakeProfit());
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Método privado para modificar SL                                 |
//+------------------------------------------------------------------+
bool CRiskProtection::ModifySL(ulong ticket, double newSl, double currentTp)
{

    newSl = CUtils::Rounder(newSl);
    newSl = NormalizeDouble(newSl, _Digits);
    
    m_stopLossPrice = newSl; // Armazena o SL globalmente para 
    
    if(!m_trade.PositionModify(ticket, newSl, currentTp))
    {
        Print("Falha ao modificar SL: ", GetLastError());
        return false;
    }
    return true;
}


ENUM_RISK_ERROR CRiskProtection::MonitorStopLoss(ENUM_SL_STRATEGY slStrategy, 
                                               double stopLoss = 0,
                                               double trailingStart = 0,
                                               double breakevenProfit = 0,
                                               double progressiveStep = 0,
                                               double progressivePercent = 0)
{    
    if(stopLoss <= 0) return RISK_ERROR_INVALID_PARAM;
    m_stopLossPoint = stopLoss;
    
    // Aplica a estratégia selecionada
    switch(slStrategy)
    {
        case SL_TRAILING:
            if(stopLoss <= 0 || trailingStart <= 0) return RISK_ERROR_INVALID_PARAM; 
            MonitorTrailingStop(trailingStart, stopLoss);
            break;
            
        case SL_PROGRESSIVE:
            if(progressiveStep <= 0 || progressivePercent <= 0 || progressivePercent > 1) return RISK_ERROR_INVALID_PARAM;
            ProgressiveProfitProtection(progressiveStep, progressivePercent);
            break;
            
        case SL_BREAKEVEN:
            if(breakevenProfit <= 0) return RISK_ERROR_INVALID_PARAM;
            StopLossAtBreakeven(breakevenProfit, 0);
            break;
            
        case SL_HYBRID:
            {
               // Estratégia híbrida: primeiro trailing, depois breakeven
               if(trailingStart <= 0 || stopLoss <= 0 || breakevenProfit <= 0)
                   return RISK_ERROR_INVALID_PARAM;
                   
               // Verifica se já atingiu o nível de breakeven
               bool breakevenReached = false;
               for(int i = PositionsTotal()-1; i >= 0; i--)
               {
                   ulong ticket = PositionGetTicket(i);
                   if(m_position.SelectByTicket(ticket) 
                      && m_position.Magic() == m_magicNumber
                      && m_position.Symbol() == m_symbol)
                   {
                       double profit = m_position.Profit();
                       if(profit >= breakevenProfit * _Point)
                       {
                           breakevenReached = true;
                           break;
                       }
                   }
               }
               
               if(breakevenReached)
                   StopLossAtBreakeven(breakevenProfit, 0); // Move SL para o preço de abertura
               else
                   MonitorTrailingStop(trailingStart, stopLoss);
               break;
            }
        default:
            return RISK_ERROR_INVALID_SL_STRATEGY;
    }
    
    return RISK_ERROR_OK;
}


//+------------------------------------------------------------------+
//|  Método estático para fechar posições se SL ou TP for pulado                                                                 |
//+------------------------------------------------------------------+
static void CRiskProtection::VerifyPositionSafety(CTrade &trade, ulong ticket, double sl, double tp) {
     if (!PositionSelectByTicket(ticket)) return;

     double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
     ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

     // Verifica se o preço passou do SL/TP sem fechar
     bool slIgnored = (type == POSITION_TYPE_BUY && currentPrice <= sl) || 
                      (type == POSITION_TYPE_SELL && currentPrice >= sl);
     bool tpIgnored = (type == POSITION_TYPE_BUY && currentPrice >= tp) || 
                      (type == POSITION_TYPE_SELL && currentPrice <= tp);

     if (slIgnored || tpIgnored) {
         trade.PositionClose(ticket);
         Print("[RISK] Posição ", ticket, " fechada manualmente (SL/TP ignorado)");
     }
 }
 
 
//+------------------------------------------------------------------+
//| Stop Loss no preço de abertura para posição específica           |
//+------------------------------------------------------------------+
void CRiskProtection::StopLossAtBreakevenByTicket(ulong ticket, double minProfitPoints, double slOffset = 0)
{
    if(!PositionSelectByTicket(ticket)) return;
    if(PositionGetInteger(POSITION_MAGIC) != m_magicNumber || PositionGetString(POSITION_SYMBOL) != m_symbol) return;

    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    double currentSl = PositionGetDouble(POSITION_SL);
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double profitPoints = 0;
    
    if(posType == POSITION_TYPE_BUY)
        profitPoints = (currentPrice - openPrice) / _Point;
    else
        profitPoints = (openPrice - currentPrice) / _Point;
    
    if(profitPoints >= minProfitPoints)
    {
        double newSl = (posType == POSITION_TYPE_BUY) 
                     ? openPrice + slOffset * _Point 
                     : openPrice - slOffset * _Point;
                     
        if((posType == POSITION_TYPE_BUY && newSl > currentSl) ||
           (posType == POSITION_TYPE_SELL && newSl < currentSl))
        {
            ModifySL(ticket, newSl, PositionGetDouble(POSITION_TP));
        }
    }
}

//+------------------------------------------------------------------+
//| Trailing Stop dinâmico para posição específica                   |
//+------------------------------------------------------------------+
void CRiskProtection::MonitorTrailingStopByTicket(ulong ticket, double trailingStart, double stopLoss)
{
    if(!PositionSelectByTicket(ticket)) return;
    if(PositionGetInteger(POSITION_MAGIC) != m_magicNumber || PositionGetString(POSITION_SYMBOL) != m_symbol) return;

    double currentSl = PositionGetDouble(POSITION_SL);
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double pointsProfit = 0;
    
    if(posType == POSITION_TYPE_BUY)
    {
        pointsProfit = (currentPrice - openPrice) / _Point;
        if(pointsProfit >= trailingStart)
        {
            double newSl = currentPrice - stopLoss * _Point;
            if(newSl > currentSl)
                ModifySL(ticket, newSl, PositionGetDouble(POSITION_TP));
        }
    }
    else // POSITION_TYPE_SELL
    {
        pointsProfit = (openPrice - currentPrice) / _Point;
        if(pointsProfit >= trailingStart)
        {
            double newSl = currentPrice + stopLoss * _Point;
            if(newSl < currentSl)
                ModifySL(ticket, newSl, PositionGetDouble(POSITION_TP));
        }
    }
}

//+------------------------------------------------------------------+
//| Proteção progressiva de lucro para posição específica           |
//+------------------------------------------------------------------+
void CRiskProtection::ProgressiveProfitProtectionByTicket(ulong ticket, double stepPoints, double protectPercent)
{
    if(!PositionSelectByTicket(ticket)) return;
    if(PositionGetInteger(POSITION_MAGIC) != m_magicNumber || PositionGetString(POSITION_SYMBOL) != m_symbol) return;

    protectPercent = MathMin(MathMax(protectPercent, 0.1), 0.9); // Limita entre 10% e 90%
    
    double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
    double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
    double currentSl = PositionGetDouble(POSITION_SL);
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double profitPoints = 0;
    
    if(posType == POSITION_TYPE_BUY)
        profitPoints = (currentPrice - openPrice) / _Point;
    else
        profitPoints = (openPrice - currentPrice) / _Point;
    
    if(profitPoints >= stepPoints)
    {
        int steps = int(profitPoints / stepPoints);
        double newSl = 0;
        
        if(posType == POSITION_TYPE_BUY)
        {
            newSl = openPrice + (stepPoints * steps * protectPercent * _Point);
            if(newSl > currentSl)
                ModifySL(ticket, newSl, PositionGetDouble(POSITION_TP));
        }
        else
        {
            newSl = openPrice - (stepPoints * steps * protectPercent * _Point);
            if(newSl < currentSl)
                ModifySL(ticket, newSl, PositionGetDouble(POSITION_TP));
        }
    }
}

//+------------------------------------------------------------------+
//| Monitora SL por ticket com estratégia híbrida                    |
//+------------------------------------------------------------------+
ENUM_RISK_ERROR CRiskProtection::MonitorStopLossByTicket(ulong ticket, ENUM_SL_STRATEGY slStrategy, 
                                               double stopLoss = 0,
                                               double trailingStart = 0,
                                               double breakevenProfit = 0,
                                               double progressiveStep = 0,
                                               double progressivePercent = 0)
{    
    if(stopLoss <= 0) return RISK_ERROR_INVALID_PARAM;
    m_stopLossPoint = stopLoss;
    
    if(!PositionSelectByTicket(ticket)) {
        return RISK_ERROR_POSITION_NOT_FOUND;
    }
    
    if(PositionGetInteger(POSITION_MAGIC) != m_magicNumber || 
       PositionGetString(POSITION_SYMBOL) != m_symbol) {
        return RISK_ERROR_WRONG_POSITION;
    }
    
    // Aplica a estratégia selecionada
    switch(slStrategy)
    {
        case SL_TRAILING:
            if(stopLoss <= 0 || trailingStart <= 0) return RISK_ERROR_INVALID_PARAM; 
            MonitorTrailingStopByTicket(ticket, trailingStart, stopLoss);
            break;
            
        case SL_PROGRESSIVE:
            if(progressiveStep <= 0 || progressivePercent <= 0 || progressivePercent > 1) 
                return RISK_ERROR_INVALID_PARAM;
            ProgressiveProfitProtectionByTicket(ticket, progressiveStep, progressivePercent);
            break;
            
        case SL_BREAKEVEN:
            if(breakevenProfit <= 0) return RISK_ERROR_INVALID_PARAM;
            StopLossAtBreakevenByTicket(ticket, breakevenProfit, 0);
            break;
            
        case SL_HYBRID:
            if(trailingStart <= 0 || stopLoss <= 0 || breakevenProfit <= 0)
                return RISK_ERROR_INVALID_PARAM;
                
            if(PositionGetDouble(POSITION_PROFIT) >= breakevenProfit * _Point) {
                StopLossAtBreakevenByTicket(ticket, breakevenProfit, 0);
            } else {
                MonitorTrailingStopByTicket(ticket, trailingStart, stopLoss);
            }
            break;
            
        default:
            return RISK_ERROR_INVALID_SL_STRATEGY;
    }
    
    return RISK_ERROR_OK;
}
