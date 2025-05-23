//+------------------------------------------------------------------+
//|                                                COrderManager.mqh |
//|                                                    Danne Pereira |
//|                                             https://www.aipi.com |
//+------------------------------------------------------------------+
#property copyright "Danne Pereira"
#property link      "https://www.aipi.com"
#property version   "1.00"

#include <Trade/Trade.mqh>
#include <Trade/OrderInfo.mqh>
#include "CUtils.mqh"


enum ENUM_TP_STRATEGY {
   TP_FIXED,          // Take Profit fixo
   TP_RISK_REWARD,    // Baseado em risco/recompensa
   TP_DYNAMIC         // Take Profit dinâmico
};

// Enumeração de erros
enum ENUM_ORDER_ERROR {
   ORDER_ERROR_OK = 0,                  // Operação bem sucedida
   ORDER_ERROR_GENERIC_FAILURE,         // Falha genérica na operação
   ORDER_ERROR_INVALID_LOTS,            // Volume/tamanho do lote inválido
   ORDER_ERROR_ORDER_SEND_FAILED,       // Falha no envio da ordem
   ORDER_ERROR_SL_EXCEEDED,             // Stop Loss excede limite permitido
   ORDER_ERROR_TP_EXCEEDED,             // Take Profit excede limite permitido
   ORDER_ERROR_PRICE_INVALID,           // Preço inválido para a operação
   ORDER_ERROR_SL_INVALID,              // Stop Loss inválido (valor ou cálculo)
   ORDER_ERROR_TP_INVALID,              // Take Profit inválido (valor ou cálculo)
   ORDER_ERROR_MARKET_CLOSED,           // Mercado fechado para operação
   ORDER_ERROR_NOT_ENOUGH_MONEY,        // Saldo insuficiente
   ORDER_ERROR_ORDER_EXPIRED,           // Ordem expirada
   ORDER_ERROR_POSITION_NOT_FOUND,      // Posição não encontrada
   ORDER_ERROR_ORDER_NOT_FOUND,         // Ordem não encontrada
   ORDER_ERROR_TRADE_DISABLED,          // Trading desabilitado
   ORDER_ERROR_INVALID_EXPIRATION,      // Tempo de expiração inválido
   ORDER_ERROR_INVALID_MAGIC,           // Magic number inválido
   ORDER_ERROR_INVALID_COMMENT,         // Comentário muito longo
   ORDER_ERROR_HEDGING_PROHIBITED,      // Hedge não permitido
   ORDER_ERROR_TOO_MANY_REQUESTS,       // Muitas requisições
   ORDER_ERROR_ACCOUNT_RESTRICTION,     // Restrição na conta
   ORDER_ERROR_BROKER_INTERVENTION      // Intervenção do broker
};

class COrderManager
  {
  
private:
   CTrade           *m_trade;               // Objeto CTrade para execução
   int               m_magicNumber;         // Magic number do EA
   double            m_maxAllowedSLPoints;  // SL máximo em pontos
   string            m_symbol;              // Símbolo negociado
   string            m_expertName;          // Nome do Expert Advisor
   string            m_expertName_;         // Nome do Expert Advisor com ": "
   ENUM_ORDER_ERROR  m_lastError;           // Último erro ocorrido
   string            m_errorDescription;    // Descrição do erro
   
   void              CalculateSLTP(int orderType, double price, double stopLoss, double takeProfit, double &sl, double &tp);
   bool              ValidateOrder(double price, double sl, double tp, double lotSize);
   void              CancelPendingOrder(ulong orderTicket, int maxAgeSeconds, datetime currentTime);
   void              SetError(ENUM_ORDER_ERROR error, string description = "");

public:
    // Construtor e Destrutor
                     COrderManager(CTrade &trade, int magicNumber, double maxAllowedSLPoints, string symbol);
                    ~COrderManager();

    //--- Métodos principais de execução ---//
    bool              BuyMarketPoint(double lotSize, double slPoints, double tpPoints, string comment = "");
    bool              SellMarketPoint(double lotSize, double slPoints, double tpPoints, string comment = "");
    bool              BuyMarketPrice(double lotSize, double slPrice, double tpPrice, string comment = "");
    bool              SellMarketPrice(double lotSize, double slPrice, double tpPrice, string comment = "");
    bool              BuyLimitPoint(double entryPrice, double lotSize, double slPoints, double tpPoints, int expirationSeconds, string comment = "");
    bool              SellLimitPoint(double entryPrice, double lotSize, double slPoints, double tpPoints, int expirationSeconds, string comment = "");
    bool              BuyStopPoint(double entryPrice, double lotSize, double slPoints, double tpPoints, int expirationSeconds, string comment = "");
    bool              SellStopPoint(double entryPrice, double lotSize, double slPoints, double tpPoints, int expirationSeconds, string comment = "");
    bool              BuyStopPrice(double entryPrice, double lotSize, double slPrice, double tpPrice, int expirationSeconds, string comment = "");
    bool              SellStopPrice(double entryPrice, double lotSize, double slPrice, double tpPrice, int expirationSeconds, string comment = "");
    void              CancelOldPendingOrders(int maxAgeSeconds);
    bool              HasOpenPosition();
    int               TotalOpenPosition();
    double            GetTakeProfitPoints(ENUM_TP_STRATEGY tpStrategy, double takeProfit, double stopLoss);
    ulong             GetLastTicket();
    void              CheckAndCloseExpiredTrades(int magicNumber, int maxCandles);

    //--- Métodos de gerenciamento ---//
    bool              ClosePosition(ulong ticket, double lotSize = 0);

    //--- Métodos de informação ---//
    ENUM_ORDER_ERROR  GetLastError() const { return m_lastError; }
    string            GetLastErrorText() const { return m_errorDescription; }
    string            GetExpertName() const { return m_expertName; }
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// Construtor
COrderManager::COrderManager(CTrade &trade, int magicNumber, double maxAllowedSLPoints, string symbol) :
    m_magicNumber(magicNumber),
    m_maxAllowedSLPoints(maxAllowedSLPoints),
    m_symbol(symbol)
{
    m_trade = GetPointer(trade);
    m_expertName = ChartGetString(0, CHART_EXPERT_NAME);
    m_expertName_ = m_expertName + ": ";
    m_trade.SetExpertMagicNumber(m_magicNumber);
    m_lastError = ORDER_ERROR_OK;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
COrderManager::~COrderManager()
  {
  }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Métodos Privados                                                 |
//+------------------------------------------------------------------+
void COrderManager::CalculateSLTP(int orderType, double price, double stopLoss, double takeProfit, double &sl, double &tp)
{
    if(stopLoss > 0) {
        sl = (orderType == ORDER_TYPE_BUY) ? 
             price - stopLoss * _Point :
             price + stopLoss * _Point ;
        sl = NormalizeDouble(CUtils::Rounder(sl), _Digits);
    }
 
    if(takeProfit > 0) {
        tp = (orderType == ORDER_TYPE_BUY) ? 
             price + takeProfit * _Point :
             price - takeProfit * _Point ;
        tp = NormalizeDouble(CUtils::Rounder(tp), _Digits);
    }
}

// Método privado: Validação de ordem
bool COrderManager::ValidateOrder(double price, double sl, double tp, double lotSize)
{
    if(sl <= 0){
      SetError(ORDER_ERROR_SL_INVALID);
      return false;
    }
    
    if(tp <= 0){
      SetError(ORDER_ERROR_TP_INVALID);
      return false;
    }

    if(lotSize < SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN)) {
      SetError(ORDER_ERROR_INVALID_LOTS);
      return false;
    }
    
    if(sl != 0 && MathAbs(price - sl) > m_maxAllowedSLPoints * _Point) {
      SetError(ORDER_ERROR_SL_EXCEEDED);
      return false;
    }
    
    return true;
}


//+------------------------------------------------------------------+
//| Funções de Trading                                               |
//+------------------------------------------------------------------+

bool COrderManager::BuyMarketPoint(double lotSize, double slPoints, double tpPoints, string comment)
{
    double price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
    price = NormalizeDouble(CUtils::Rounder(price), _Digits);
    double slPrice, tpPrice;
    
    CalculateSLTP(ORDER_TYPE_BUY, price, slPoints, tpPoints, slPrice, tpPrice);
    
    // Round and normalize prices
    slPrice = NormalizeDouble(CUtils::Rounder(slPrice), _Digits);
    tpPrice = NormalizeDouble(CUtils::Rounder(tpPrice), _Digits);
    
    Print(" ============== ");
    Print("Preço: ", price);
    Print("SL pontos: ", slPoints);
    Print("TP pontos: ", tpPoints);
    Print("SL preço: ", slPrice);
    Print("TP preço: ", tpPrice);
    
    if(!ValidateOrder(price, slPrice, tpPrice, lotSize))
        return false;
        
    if(!m_trade.Buy(lotSize, m_symbol, price, slPrice, tpPrice, m_expertName_ + comment)) {
        SetError(ORDER_ERROR_ORDER_SEND_FAILED , "Falha na execução de BuyMarketPoint");
        return false;
    }
    
    return true;
}

bool COrderManager::SellMarketPoint(double lotSize, double slPoints, double tpPoints, string comment = ""){
    double price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    price = NormalizeDouble(CUtils::Rounder(price), _Digits);
    double slPrice; double tpPrice;
    
    CalculateSLTP(ORDER_TYPE_SELL, price, slPoints, tpPoints, slPrice, tpPrice);
    
    // Round and normalize prices
    slPrice = NormalizeDouble(CUtils::Rounder(slPrice), _Digits);
    tpPrice = NormalizeDouble(CUtils::Rounder(tpPrice), _Digits);
    
    if(!ValidateOrder(price, slPrice, tpPrice, lotSize))
        return false;
    
    if (!m_trade.Sell(lotSize, m_symbol, price, slPrice, tpPrice, m_expertName_ + comment)){
     SetError(ORDER_ERROR_ORDER_SEND_FAILED , "Falha na execução de SellMarketPoint");
      return false;
    }
    
    return true;
}

bool COrderManager::BuyMarketPrice(double lotSize, double slPrice, double tpPrice, string comment)
{
    double price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
    
    // Round and normalize prices
    slPrice = NormalizeDouble(CUtils::Rounder(slPrice), _Digits);
    tpPrice = NormalizeDouble(CUtils::Rounder(tpPrice), _Digits);
    
    if(!ValidateOrder(price, slPrice, tpPrice, lotSize)) {
        return false;
    }
    
    if(!m_trade.Buy(lotSize, m_symbol, price, slPrice, tpPrice, m_expertName_ + comment)) {
        SetError(ORDER_ERROR_ORDER_SEND_FAILED , "Falha na execução de BuyMarketPrice");
        return false;
    }
    
    return true;
}

bool COrderManager::SellMarketPrice(double lotSize, double slPrice, double tpPrice, string comment)
{
    double price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
    
    // Round and normalize prices
    slPrice = NormalizeDouble(CUtils::Rounder(slPrice), _Digits);
    tpPrice = NormalizeDouble(CUtils::Rounder(tpPrice), _Digits);
    
    if(!ValidateOrder(price, slPrice, tpPrice, lotSize)) {
        return false;
    }
    
    if(!m_trade.Sell(lotSize, m_symbol, price, slPrice, tpPrice, m_expertName_ + comment)) {
        SetError(ORDER_ERROR_ORDER_SEND_FAILED , "Falha na execução de SellMarketPrice");
        return false;
    }
    
    return true;
}

bool COrderManager::BuyLimitPoint(double entryPrice, double lotSize, double slPoints, double tpPoints, int expirationSeconds, string comment = ""){

    double slPrice, tpPrice;
    CalculateSLTP(ORDER_TYPE_BUY, entryPrice, slPoints, tpPoints, slPrice, tpPrice); 
    
    slPrice = NormalizeDouble(CUtils::Rounder(slPrice), _Digits);
    tpPrice = NormalizeDouble(CUtils::Rounder(tpPrice), _Digits);
    
    if(!ValidateOrder(entryPrice, slPrice, tpPrice, lotSize)) {
        return false;
    }
    
    datetime expirationTime = TimeCurrent() + expirationSeconds;
    
    if(!m_trade.BuyLimit(lotSize, entryPrice, m_symbol, slPrice, tpPrice, ORDER_TIME_SPECIFIED, expirationTime, m_expertName_ + comment)) {
      SetError(ORDER_ERROR_ORDER_SEND_FAILED , "Falha na execução de BuyLimitPoint");
      return false;
    }
   
    return true;
}

bool COrderManager::SellLimitPoint(double entryPrice, double lotSize, double slPoints, double tpPoints, int expirationSeconds, string comment = ""){

    double slPrice, tpPrice;
    CalculateSLTP(ORDER_TYPE_SELL, entryPrice, slPoints, tpPoints, slPrice, tpPrice);

    slPrice = NormalizeDouble(CUtils::Rounder(slPrice), _Digits);
    tpPrice = NormalizeDouble(CUtils::Rounder(tpPrice), _Digits);

    if(!ValidateOrder(entryPrice, slPrice, tpPrice, lotSize)) {
        return false;
    }

    datetime expirationTime = TimeCurrent() + expirationSeconds;

    if(!m_trade.SellLimit(lotSize, entryPrice, m_symbol, slPrice, tpPrice, ORDER_TIME_SPECIFIED, expirationTime, m_expertName_ + comment)) {
        SetError(ORDER_ERROR_ORDER_SEND_FAILED , "Falha na execução de SellLimitPoint");
        return false;
    }

    return true;
}

bool COrderManager::BuyStopPoint(double entryPrice, double lotSize, double slPoints, double tpPoints, int expirationSeconds, string comment = ""){
    
    double slPrice, tpPrice;

    // Calcula SL e TP
    CalculateSLTP(ORDER_TYPE_BUY, entryPrice, slPoints, tpPoints, slPrice, tpPrice);

    // Normalizar e arredondar os valores de SL e TP
    slPrice = NormalizeDouble(CUtils::Rounder(slPrice), _Digits);
    tpPrice = NormalizeDouble(CUtils::Rounder(tpPrice), _Digits);

    // Valida os parâmetros antes de enviar a ordem
    if(!ValidateOrder(entryPrice, slPrice, tpPrice, lotSize)) {
        return false;
    }

    // Calcula o tempo de expiração
    datetime expirationTime = TimeCurrent() + expirationSeconds;

    // Executa a ordem Buy Stop
    if(!m_trade.BuyStop(lotSize, entryPrice, m_symbol, slPrice, tpPrice, ORDER_TIME_SPECIFIED, expirationTime, m_expertName_ + comment)) {
        SetError(ORDER_ERROR_ORDER_SEND_FAILED , "Falha na execução de BuyStopPoint.");
        return false;
    }

    return true; // Ordem executada com sucesso
}


bool COrderManager::SellStopPoint(double entryPrice, double lotSize, double slPoints, double tpPoints, int expirationSeconds, string comment = ""){

    double slPrice, tpPrice;

    // Calcula SL e TP
    CalculateSLTP(ORDER_TYPE_SELL, entryPrice, slPoints, tpPoints, slPrice, tpPrice);

    // Normalizar e arredondar os valores de SL e TP
    slPrice = NormalizeDouble(CUtils::Rounder(slPrice), _Digits);
    tpPrice = NormalizeDouble(CUtils::Rounder(tpPrice), _Digits);

    // Valida os parâmetros antes de enviar a ordem
    if(!ValidateOrder(entryPrice, slPrice, tpPrice, lotSize)) {
        return false;
    }

    // Calcula o tempo de expiração
    datetime expirationTime = TimeCurrent() + expirationSeconds;

    // Executa a ordem Sell Stop
    if(!m_trade.SellStop(lotSize, entryPrice, m_symbol, slPrice, tpPrice, ORDER_TIME_SPECIFIED, expirationTime, m_expertName_ + comment)) {
        SetError(ORDER_ERROR_ORDER_SEND_FAILED , "Falha na execução de SellStopPoint.");
        return false;
    }

    return true; // Ordem executada com sucesso
}

bool COrderManager::BuyStopPrice(double entryPrice, double lotSize, double slPrice, double tpPrice, int expirationSeconds, string comment = ""){
   
   // Round and normalize prices
   slPrice = NormalizeDouble(CUtils::Rounder(slPrice), _Digits);
   tpPrice = NormalizeDouble(CUtils::Rounder(tpPrice), _Digits);

   if(!ValidateOrder(entryPrice, slPrice, tpPrice, lotSize)) {
        return false;
   }
     
   datetime expirationTime = TimeCurrent() + expirationSeconds;
   
   if(!m_trade.BuyStop(lotSize, entryPrice, m_symbol, slPrice, tpPrice, ORDER_TIME_SPECIFIED, expirationTime, m_expertName_ + comment))
   {
      SetError(ORDER_ERROR_ORDER_SEND_FAILED , "Falha na execução de BuyStopPrice");
      return false;
   }
   
   return true;
}

bool COrderManager::SellStopPrice(double entryPrice, double lotSize, double slPrice, double tpPrice, int expirationSeconds, string comment = ""){
   
    // Round and normalize prices
    slPrice = NormalizeDouble(CUtils::Rounder(slPrice), _Digits);
    tpPrice = NormalizeDouble(CUtils::Rounder(tpPrice), _Digits);

    // Validate the order details
    if(!ValidateOrder(entryPrice, slPrice, tpPrice, lotSize)) {
        return false;
    }
    
    // Calculate expiration time
    datetime expirationTime = TimeCurrent() + expirationSeconds;
    
    // Execute the Sell Stop order
    if(!m_trade.SellStop(lotSize, entryPrice, m_symbol, slPrice, tpPrice, ORDER_TIME_SPECIFIED, expirationTime, m_expertName_ + comment)) {
        SetError(ORDER_ERROR_ORDER_SEND_FAILED , "Falha na execução de SellStopPrice");
        return false;
    }
    
    return true;
}

void COrderManager::CancelOldPendingOrders(int maxAgeSeconds){
  datetime currentTime = TimeCurrent();
  
  for(int i = OrdersTotal() - 1; i >= 0; i--)
  {
      ulong ticket = OrderGetTicket(i);
      if(OrderGetInteger(ORDER_MAGIC) == m_magicNumber)
      {
          CancelPendingOrder(ticket, maxAgeSeconds, currentTime);
      }
  }
}

void COrderManager::CancelPendingOrder(ulong orderTicket, int maxAgeSeconds, datetime currentTime){
  ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
  
  // Filtra apenas ordens pendentes
  if(orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_SELL_LIMIT ||
     orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_SELL_STOP)
  {
      datetime orderTime = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      
      // Verifica expiração
      if((currentTime - orderTime) >= maxAgeSeconds)
      {
          if(m_trade.OrderDelete(orderTicket))
          {
              PrintFormat("%s Ordem pendente #%d cancelada (expirada após %d segundos)",
                        m_expertName, orderTicket, maxAgeSeconds);
          }
          else
          {
              PrintFormat("%s ERRO ao cancelar ordem #%d (Código: %d)",
                        m_expertName, orderTicket, GetLastError());
          }
      }
  }
}


//+------------------------------------------------------------------+
//| TP com Risco Retorno                                                                  |
//+------------------------------------------------------------------+
double COrderManager::GetTakeProfitPoints(ENUM_TP_STRATEGY tpStrategy, double takeProfit, double stopLoss){
   switch(tpStrategy)
   {
      case TP_RISK_REWARD:
         if(stopLoss <= 0 || takeProfit <= 0) return -1.0; //takeProfit, neste caso, é o ratio
         return CUtils::Rounder(stopLoss * takeProfit);
      case TP_DYNAMIC:
         //TODO
         if(takeProfit <= 0 ) return -1.0;
         return CUtils::Rounder(takeProfit); // Usar esse modo por enquando.
      case TP_FIXED: //TP Fixo
         if(takeProfit <= 0 ) return -1.0;
         return CUtils::Rounder(takeProfit);
   }
   return CUtils::Rounder(stopLoss);
}


bool COrderManager::HasOpenPosition()
{
    for(int i = PositionsTotal()-1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket) && 
           PositionGetInteger(POSITION_MAGIC) == m_magicNumber &&
           PositionGetString(POSITION_SYMBOL) == m_symbol)
        {
            return true;
        }
    }
    return false;
}

int COrderManager::TotalOpenPosition()
{
   int count = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket) && 
           PositionGetInteger(POSITION_MAGIC) == m_magicNumber &&
           PositionGetString(POSITION_SYMBOL) == m_symbol)
        {
            count++;
        }
    }
    return count;
}

ulong COrderManager::GetLastTicket()
{
    const int maxAttempts = 5;
    const int delayMs = 100;
    
    for(int attempt = 0; attempt < maxAttempts; attempt++)
    {
        datetime newestTime = 0;
        ulong newestTicket = 0;
        
        int total = PositionsTotal();
        for(int i = total-1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(PositionSelectByTicket(ticket))
            {
                if(PositionGetString(POSITION_SYMBOL) == m_symbol && 
                   PositionGetInteger(POSITION_MAGIC) == m_magicNumber)
                {
                    datetime time = (datetime)PositionGetInteger(POSITION_TIME);
                    if(time > newestTime)
                    {
                        newestTime = time;
                        newestTicket = ticket;
                    }
                }
            }
        }
        
        if(newestTicket != 0)
        {
            Print("Ticket encontrado: ", newestTicket);
            return newestTicket;
        }
        
        Sleep(delayMs);
    }
    
    Print("Nenhuma posição válida encontrada após ", maxAttempts, " tentativas");
    return 0; // Retorna 0 em caso de falha
}

void COrderManager::SetError(ENUM_ORDER_ERROR error, string description = "") 
{
    m_lastError = error;
    
    if(description == "") 
    {
        switch(error)
        {
            case ORDER_ERROR_OK:
                m_errorDescription = "Operação bem sucedida";
                break;
            case ORDER_ERROR_GENERIC_FAILURE:
                m_errorDescription = "Falha genérica na operação";
                break;
            case ORDER_ERROR_INVALID_LOTS:
                m_errorDescription = StringFormat("Volume inválido (min: %.2f, max: %.2f, step: %.2f)", 
                    SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN),
                    SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX),
                    SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP));
                break;
            case ORDER_ERROR_ORDER_SEND_FAILED : 
                m_errorDescription = "Falha no envio da ordem";
                break;
            case ORDER_ERROR_SL_EXCEEDED:
                m_errorDescription = "SL excede o limite de "+ DoubleToString(m_maxAllowedSLPoints * _Point) +" pontos";
                break;
            case ORDER_ERROR_TP_EXCEEDED:
                m_errorDescription = "Take Profit excede limite permitido";
                break;
            case ORDER_ERROR_PRICE_INVALID:
                m_errorDescription = "Preço inválido para a operação";
                break;
            case ORDER_ERROR_SL_INVALID:
                m_errorDescription = "Stop Loss inválido (valor ou cálculo)";
                break;
            case ORDER_ERROR_TP_INVALID:
                m_errorDescription = "Take Profit inválido (valor ou cálculo)";
                break;
            case ORDER_ERROR_MARKET_CLOSED:
                m_errorDescription = "Mercado fechado para operação";
                break;
            case ORDER_ERROR_NOT_ENOUGH_MONEY:
                m_errorDescription = "Saldo insuficiente para executar a operação";
                break;
            case ORDER_ERROR_ORDER_EXPIRED:
                m_errorDescription = "Ordem expirada";
                break;
            case ORDER_ERROR_POSITION_NOT_FOUND:
                m_errorDescription = "Posição não encontrada";
                break;
            case ORDER_ERROR_ORDER_NOT_FOUND:
                m_errorDescription = "Ordem não encontrada";
                break;
            case ORDER_ERROR_TRADE_DISABLED:
                m_errorDescription = "Trading desabilitado";
                break;
            case ORDER_ERROR_INVALID_EXPIRATION:
                m_errorDescription = "Tempo de expiração inválido";
                break;
            case ORDER_ERROR_INVALID_MAGIC:
                m_errorDescription = "Magic number inválido";
                break;
            case ORDER_ERROR_INVALID_COMMENT:
                m_errorDescription = "Comentário muito longo (máx. 25 caracteres)";
                break;
            case ORDER_ERROR_HEDGING_PROHIBITED:
                m_errorDescription = "Hedge não permitido nesta conta";
                break;
            case ORDER_ERROR_TOO_MANY_REQUESTS:
                m_errorDescription = "Muitas requisições em curto período";
                break;
            case ORDER_ERROR_ACCOUNT_RESTRICTION:
                m_errorDescription = "Restrição na conta impede a operação";
                break;
            case ORDER_ERROR_BROKER_INTERVENTION:
                m_errorDescription = "Intervenção do broker bloqueou a operação";
                break;
            default:
                m_errorDescription = StringFormat("Erro desconhecido (código %d)", error);
        }
    }
    else
    {
        m_errorDescription = m_expertName + ": " + description;
    }
    
    // Log do erro se não for OK
    if(error != ORDER_ERROR_OK)
    {
        Print(m_errorDescription);
    }
}


//+------------------------------------------------------------------+
//| Fecha operações após X candles                                    |
//+------------------------------------------------------------------+
void COrderManager::CheckAndCloseExpiredTrades(int magicNumber, int maxCandles)
{
    // 1. Obter o tempo atual e o candle de abertura da posição
    datetime currentTime = TimeCurrent();
    
    // 2. Verificar todas as posições abertas
    for(int i = PositionsTotal()-1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            // 3. Verificar se é uma posição deste EA
            if(PositionGetInteger(POSITION_MAGIC) == magicNumber)
            {
                datetime positionOpenTime = (datetime)PositionGetInteger(POSITION_TIME);
                string symbol = PositionGetString(POSITION_SYMBOL);
                ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                
                // 4. Calcular quantos candles se passaram desde a abertura
                int candlesPassed = iBarShift(symbol, PERIOD_CURRENT, positionOpenTime);
                
                // 5. Fechar se exceder o limite
                if(candlesPassed >= maxCandles)
                {
                    m_trade.PositionClose(ticket);
                    string closeReason = "Fechamento após " + IntegerToString(candlesPassed) + " candles";
                    Print(closeReason);
                }
            }
        }
    }
}