//+------------------------------------------------------------------+
//|                                 BollingerFalseBreakoutEA.mq5     |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.metaquotes.net/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.metaquotes.net/"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Input parameters                                                 |
//+------------------------------------------------------------------+
#include "../../DefaultFunctions.mqh"
#include "../../DefaultInputs.mqh"

enum ENUM_TP_TYPE {
   FIXED_TP, //Fixo
   RISK_REWARD //Risco Retorno
};

input ENUM_TP_TYPE InpTpType = FIXED_TP; // Tipo de TP
input double InpTPRiskReward = 1.5; // TP com relação Risco-Retorno

input int      InpATRPeriod = 14;             // ATR Period
input int      InpBBPeriod = 20;              // Bollinger Bands Period
input double   InpBBDeviation = 2.1;          // Bollinger Bands Deviation
input int      InpMATRPeriod = 9;             // EMA on ATR Period
input int      InpRSIPeriod = 9;              // RSI Period
input double   InpRSIOverbought = 70.0;       // RSI Overbought Level
input double   InpRSIOversold = 30.0;         // RSI Oversold Level

//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+
int bbHandle;       // Bollinger Bands indicator handle
int atrHandle;      // ATR indicator handle
int emaATRHandle;   // EMA on ATR indicator handle
int rsiHandle;      // RSI indicator handle

double upperBand[], middleBand[], lowerBand[];
double atrBuffer[];
double emaATRBuffer[];
double rsiBuffer[];

datetime lastCandleTime;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize indicator handles
   bbHandle = iBands(_Symbol, InpTimeframe, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
   atrHandle = iATR(_Symbol, InpTimeframe, InpATRPeriod);
   emaATRHandle = iMA(_Symbol, InpTimeframe, InpMATRPeriod, 0, MODE_EMA, atrHandle);
   rsiHandle = iRSI(_Symbol, InpTimeframe, InpRSIPeriod, PRICE_CLOSE);
   
   if(bbHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE || 
      emaATRHandle == INVALID_HANDLE || rsiHandle == INVALID_HANDLE)
   {
      Print("Error creating indicators");
      return INIT_FAILED;
   }
   
   // Set indicator buffers
   ArraySetAsSeries(upperBand, true);
   ArraySetAsSeries(middleBand, true);
   ArraySetAsSeries(lowerBand, true);
   ArraySetAsSeries(atrBuffer, true);
   ArraySetAsSeries(emaATRBuffer, true);
   ArraySetAsSeries(rsiBuffer, true);
   
   return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicators
   if(bbHandle != INVALID_HANDLE) IndicatorRelease(bbHandle);
   if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
   if(emaATRHandle != INVALID_HANDLE) IndicatorRelease(emaATRHandle);
   if(rsiHandle != INVALID_HANDLE) IndicatorRelease(rsiHandle);
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!IsSignalFromCurrentDay(_Symbol, InpTimeframe))
      return;
    
   CheckStopsSkippedAndCloseTrade(InpMagicNumber);
   
   // Cancel old pending orders
   CancelOldPendingOrders(InpMagicNumber, InpOrderExpiration);
    
   // Apply Trailing Stop if enabled
   if(InpSLType == TRAILING) MonitorTrailingStop(InpMagicNumber, InpStopLoss);
   else if(InpSLType == PROGRESS) ProtectProfitProgressivo(InpMagicNumber, InpProgressSLProtectedPoints, InpProgressSLPercentToProtect);

   // Check last trade and send email if needed
   CheckLastTradeAndSendEmail(InpMagicNumber);
    
   // Check if it's a new candle
   if(!isNewCandle()) 
      return;
   
   // Check trading time and close positions
   if(!CheckTradingTime(InpMagicNumber)) 
      return;
        
   if(HasOpenPosition(InpMagicNumber)) 
      return;
        
   // Update indicators
   UpdateIndicators();
   
   // Check for trading signals
   CheckForTrade();
}
//+------------------------------------------------------------------+
//| Update indicator buffers                                         |
//+------------------------------------------------------------------+
void UpdateIndicators()
{
   // Copy Bollinger Bands values
   if(CopyBuffer(bbHandle, 1, 1, 1, upperBand) <= 0 || 
      CopyBuffer(bbHandle, 0, 1, 1, middleBand) <= 0 || 
      CopyBuffer(bbHandle, 2, 1, 1, lowerBand) <= 0)
   {
      Print("Error copying Bollinger Bands buffers");
      return;
   }
   
   // Copy ATR values
   if(CopyBuffer(atrHandle, 0, 1, 1, atrBuffer) <= 0)
   {
      Print("Error copying ATR buffer");
      return;
   }
   
   // Calculate EMA on ATR
   if(CopyBuffer(emaATRHandle, 0, 0, 1, emaATRBuffer) <= 0)
   {
      Print("Error copying EMA on ATR buffer");
      return;
   }
   
   // Copy RSI values
   if(CopyBuffer(rsiHandle, 0, 1, 1, rsiBuffer) <= 0)
   {
      Print("Error copying RSI buffer");
      return;
   }
}
//+------------------------------------------------------------------+
//| Check for trading signals                                        |
//+------------------------------------------------------------------+
void CheckForTrade()
{
   // Get current close price (previous candle)
   double closePrice = iClose(_Symbol, InpTimeframe, 1);
   
   // Check buy condition: 
   // 1. Close below lower band 
   // 2. EMA(ATR) > ATR 
   // 3. RSI is oversold
   if(closePrice < lowerBand[0] && 
      emaATRBuffer[0] > atrBuffer[0] && 
      rsiBuffer[0] < InpRSIOversold)
   {
      BuyMarketPoint(InpMagicNumber, InpLotSize, InpStopLoss, InpTakeProfit, "Falso rompimento de queda com RSI oversold.");
   }
   // Check sell condition: 
   // 1. Close above upper band 
   // 2. EMA(ATR) > ATR 
   // 3. RSI is overbought
   else if(closePrice > upperBand[0] && 
           emaATRBuffer[0] > atrBuffer[0] && 
           rsiBuffer[0] > InpRSIOverbought)
   {
      SellMarketPoint(InpMagicNumber, InpLotSize, InpStopLoss, InpTakeProfit, "Falso rompimento de alta com RSI overbought.");
   }
}




















/*//+------------------------------------------------------------------+
//|                                                        Model.mq5 |
//|                                                    Danne Pereira |
//|                                             https://www.aipi.com |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+


#include "../../DefaultInputs.mqh"
#include "../../DefaultFunctions.mqh"

enum ENUM_TP_TYPE {
   FIXED_TP, //Fixo
   RISK_REWARD, //Risco Retorno
};
input ENUM_TP_TYPE InpTpType = FIXED_TP; // Tipo de TP
input double InpTPRiskReward = 1.5; // TP com relação Risco-Retorno

//--- Parâmetros de entrada
input int InpBBPeriod = 20;                  // Período das Bollinger Bands
input double InpBBDeviation = 2.0;           // Desvio padrão das Bollinger Bands
input int InpVolNormThreshold = 10;          // Diferença em p.p. entre Main e HighLimit

//--- Parâmetros de entrada
input int InpDiffPeriod = 14;          // Período para cálculo do desvio padrão inicial
input int InpNormalizationWindow = 21;   // Janela para normalização
input int InpStdBandPeriod = 11;           // Período para cálculo do STD das bandas
input int InpHighLvl = 60; // Limite máximo para Volatility operar

//--- Handles dos indicadores
int volNormHandle;
int bbHandle;

double main[], highLimit[], lowLimit[];
double upperBB[1], lowerBB[1];

string indicatorPath = "";
int OnInit()
  {
   // Tenta carregar o indicador de 3 formas diferentes
   string indicatorName = "VolatilityNormalizer";
   
   // Tentativa 1: Nome simples
   volNormHandle = iCustom(NULL, 0, indicatorName, InpDiffPeriod, InpNormalizationWindow, InpStdBandPeriod, 0, 0, MODE_EMA);
   
   if(volNormHandle == INVALID_HANDLE)
   {
      Print("Falha ao carregar o indicador VolatilityNormalizer");
      return INIT_FAILED;
   }
   
   bbHandle = iBands(NULL, 0, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
   if(bbHandle == INVALID_HANDLE)
   {
      Print("Falha ao carregar as Bollinger Bands");
      return INIT_FAILED;
   }
   
   ArraySetAsSeries(main, true);
   ArraySetAsSeries(highLimit, true);
   ArraySetAsSeries(lowLimit, true);
   
   return INIT_SUCCEEDED;
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Liberar handles dos indicadores
   if(volNormHandle != INVALID_HANDLE) IndicatorRelease(volNormHandle);
   if(bbHandle != INVALID_HANDLE) IndicatorRelease(bbHandle);   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    
    if(!IsSignalFromCurrentDay(_Symbol, InpTimeframe))
      return;
    
    CheckStopsSkippedAndCloseTrade(InpMagicNumber);
   
    // Cancela ordens velhas
    CancelOldPendingOrders(InpMagicNumber, InpOrderExpiration);
    
    // Aplica Trailing Stop se estiver ativado
    if (InpSLType == TRAILING) MonitorTrailingStop(InpMagicNumber, InpStopLoss);
    else if (InpSLType == PROGRESS) ProtectProfitProgressivo(InpMagicNumber, InpProgressSLProtectedPoints, InpProgressSLPercentToProtect);


    // Verifica a última negociação e envia e-mail se necessário
    CheckLastTradeAndSendEmail(InpMagicNumber);
    
    // Verifica se é um novo candle
    if (!isNewCandle()) 
        return;
   
    // Verifica horário de funcionamento e fecha possições
    if (!CheckTradingTime(InpMagicNumber)) 
        return;
        
    if(HasOpenPosition(InpMagicNumber)) 
        return;
        
  //--- Obter dados dos indicadores
   if(CopyBuffer(volNormHandle, 0, 1, 2, main) <= 0 || 
      CopyBuffer(volNormHandle, 1, 1, 2, highLimit) <= 0|| 
      CopyBuffer(volNormHandle, 2, 1, 2, lowLimit) <= 0)
   {
      Print("Falha ao copiar dados do VolatilityNormalizer");
      return;
   }
   
   if(CopyBuffer(bbHandle, 1, 1, 1, upperBB) <= 0 || 
      CopyBuffer(bbHandle, 2, 1, 1, lowerBB) <= 0)
   {
      Print("Falha ao copiar dados das Bollinger Bands");
      return;
   }
   
   //--- Obter preços atuais
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   bool falseBreakup = ((highLimit[0] - main[0]) >= InpVolNormThreshold) && 
                        main[0] <= InpHighLvl &&
                        (MathAbs(main[1] - highLimit[1]) < MathAbs(main[0] - highLimit[0]));
   //Print(falseBreakup);
   //--- Condições de entrada
   bool sellCondition = bid >= upperBB[0] && falseBreakup;
                        
   bool buyCondition  = ask <= lowerBB[0] && falseBreakup;
   
   //--- Executar ordens se as condições forem atendidas
   double tpPoint = InpTakeProfit;
   if(InpTpType == RISK_REWARD)
      tpPoint = Rounder(InpStopLoss * InpTPRiskReward);
      
   if(sellCondition)
   {
      SellMarketPoint(InpMagicNumber, InpLotSize, InpStopLoss, tpPoint, "Romp. UpBand falso");
   }
   else if(buyCondition)
   {
      BuyMarketPoint(InpMagicNumber, InpLotSize, InpStopLoss, tpPoint, "Romp. LowBand falso");
   }
}*/