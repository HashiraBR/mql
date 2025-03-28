

#include "../DefaultInputs.mqh"
#include "../DefaultFunctions.mqh"

   // Definição dos períodos das MAs
input int shortMAPeriod = 10;  // MA curta
input ENUM_MA_METHOD shortMAMethod = MODE_SMA;  // Tipo da MA curta (SMA, EMA, etc.)

input int mediumMAPeriod = 20; // MA média
input ENUM_MA_METHOD mediumMAMethod = MODE_SMA; // Tipo da MA média (SMA, EMA, etc.)

input int longMAPeriod = 50;   // MA longa
input ENUM_MA_METHOD longMAMethod = MODE_SMA;   // Tipo da MA longa (SMA, EMA, etc.)

//+------------------------------------------------------------------+
//| Definições globais                                               |
//+------------------------------------------------------------------+
int shortMAHandle;  // Handle para a MA curta
int mediumMAHandle; // Handle para a MA média
int longMAHandle;   // Handle para a MA longa

// Arrays para armazenar os valores das MAs
   double shortMABuffer[], mediumMABuffer[], longMABuffer[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Criação dos handles para as MAs com base nos parâmetros de entrada
   shortMAHandle = iMA(NULL, 0, shortMAPeriod, 0, shortMAMethod, PRICE_CLOSE);
   mediumMAHandle = iMA(NULL, 0, mediumMAPeriod, 0, mediumMAMethod, PRICE_CLOSE);
   longMAHandle = iMA(NULL, 0, longMAPeriod, 0, longMAMethod, PRICE_CLOSE);

   // Verificação se os handles foram criados corretamente
   if(shortMAHandle == INVALID_HANDLE || mediumMAHandle == INVALID_HANDLE || longMAHandle == INVALID_HANDLE)
     {
      Print("Erro ao criar handles das MAs");
      return(INIT_FAILED);
     }

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // Liberação dos handles das MAs
   if(shortMAHandle != INVALID_HANDLE)
      IndicatorRelease(shortMAHandle);
   if(mediumMAHandle != INVALID_HANDLE)
      IndicatorRelease(mediumMAHandle);
   if(longMAHandle != INVALID_HANDLE)
      IndicatorRelease(longMAHandle);
  }
  
void CopyMAs(){

   // Copiando os valores das MAs para os arrays
   if(CopyBuffer(shortMAHandle, 0, 0, 2, shortMABuffer) <= 0 ||
      CopyBuffer(mediumMAHandle, 0, 0, 2, mediumMABuffer) <= 0 ||
      CopyBuffer(longMAHandle, 0, 0, 2, longMABuffer) <= 0)
     {
      Print("Erro ao copiar dados das MAs");
      return;
     }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   
    CheckStopsSkippedAndCloseTrade(InpMagicNumber);
   
    // Cancela ordens velhas
    CancelOldPendingOrders(InpMagicNumber, InpOrderExpiration);
    
    // Aplica Trailing Stop se estiver ativado
    if (InpTrailingStop) MonitorTrailingStop(InpMagicNumber, InpStopLoss);

    // Verifica a última negociação e envia e-mail se necessário
    CheckLastTradeAndSendEmail(InpMagicNumber);
    
    // Verifica se é um novo candle
    if (!isNewCandle()) return;
    
    CopyMAs();
    
    // Valores atuais das MAs
    double shortMA = shortMABuffer[0];    // Valor atual da MA curta
    double mediumMA = mediumMABuffer[0]; // Valor atual da MA média
    double longMA = longMABuffer[0];     // Valor atual da MA longa

    // Valores anteriores das MAs (para verificar cruzamentos)
    double previousShortMA = shortMABuffer[1];    // Valor anterior da MA curta
    double previousMediumMA = mediumMABuffer[1]; // Valor anterior da MA média
   
    bool crossDown = previousShortMA > mediumMA && shortMA <= mediumMA;
    bool crossUp = previousShortMA < mediumMA && shortMA >= mediumMA;
   
    if(HasOpenPosition(InpMagicNumber)) {
      if(crossDown || crossUp) ClosePositionWithMagicNumber(InpMagicNumber);
      return;
    }
   
    // Verifica horário de funcionamento e fecha possições
    if (!CheckTradingTime(InpMagicNumber)) 
        return;
   

   // Verificação da tendência
   bool isUptrend = shortMA > mediumMA && mediumMA > longMA;
   bool isDowntrend = shortMA < mediumMA && mediumMA < longMA;
   
   double lastClose = iClose(_Symbol, InpTimeframe, 1);
   double lastOpen = iOpen(_Symbol, InpTimeframe, 1);
   double lastHigh = iHigh(_Symbol, InpTimeframe, 1);
   double lastLow = iLow(_Symbol, InpTimeframe, 1);

   if(isUptrend && lastClose >= mediumMA && lastLow <= mediumMA && lastLow >= longMA){
      ExecuteBuyOrder(InpMagicNumber, InpLotSize, InpStopLoss, InpTakeProfit, "");
   }
   else if(isDowntrend && lastClose <= mediumMA && lastHigh >= mediumMA && lastHigh <= longMA){
      ExecuteSellOrder(InpMagicNumber, InpLotSize, InpStopLoss, InpTakeProfit, "");
   }
}
//+------------------------------------------------------------------+