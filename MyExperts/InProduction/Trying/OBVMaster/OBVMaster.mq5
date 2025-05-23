//+------------------------------------------------------------------+
//|                                                        Model.mq5 |
//|                                                    Danne Pereira |
//|                                             https://www.aipi.com |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+


#include "../../DefaultInputs.mqh"
#include "../../DefaultFunctions.mqh"

input int InpEMAPeriod = 20;                // Período da EMA
input double InpOverboughtLevel = 60.0;     // Nível de sobrecompra (60%)
input double InpOversoldLevel = 40.0;       // Nível de sobrevenda (40%)
input int InpLookback = 200;                   // Lookback para normalização

int handleOBV, handleEMA;                // Handles dos indicadores
double OBV[], EMA[];                     // Arrays para valores
datetime lastTradeTime = 0;              // Controle de tempo entre operações
int lastBars = 0;                        // Controle de barras entre operações

int OnInit()
  {
   handleOBV = iOBV(_Symbol, _Period, VOLUME_REAL);
   handleEMA = iMA(_Symbol, _Period, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   
   if(handleOBV == INVALID_HANDLE || handleEMA == INVALID_HANDLE)
   {
      Print("Erro ao criar handles dos indicadores");
      return(INIT_FAILED);
   }
   
   ArraySetAsSeries(OBV, true);
   ArraySetAsSeries(EMA, true);
   
   return(INIT_SUCCEEDED);
  }
  
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(handleOBV);
   IndicatorRelease(handleEMA);
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
    if(InpSLType == TRAILING) MonitorTrailingStop(InpMagicNumber, InpStopLoss);
    else if(InpSLType == PROGRESS) ProtectProfitProgressivo(InpMagicNumber, InpProgressSLProtectedPoints, InpProgressSLPercentToProtect);

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
        
    // Copia os últimos 3 valores para análise
    if(CopyBuffer(handleOBV, 0, 0, 3, OBV) != 3 || CopyBuffer(handleEMA, 0, 0, 3, EMA) != 3)
    {
       Print("Erro ao copiar buffers. Verifique se há barras suficientes.");
       return;
    }
       
   // Normaliza os valores
   double normOBV1 = NormalizeValue(OBV[1], handleOBV);
   double normEMA1 = NormalizeValue(EMA[1], handleEMA);
   double normOBV2 = NormalizeValue(OBV[2], handleOBV);
   double normEMA2 = NormalizeValue(EMA[2], handleEMA);

   // Compra: OBV cruza EMA para cima e sobe pelo menos 2 pontos percentuais
   if(normOBV2 < normEMA2 && normOBV1 > normEMA1 && normOBV1 < InpOversoldLevel && (normOBV1 - normEMA1) > 2.0){
   Print(normOBV1, " - ", InpOversoldLevel, " - ", normEMA1);
      BuyMarketPoint(InpMagicNumber, InpLotSize, InpStopLoss, InpTakeProfit, "Buy");
      }
   
   // Venda: OBV cruza EMA para baixo e desce pelo menos 2 pontos percentuais
   else if(normOBV2 > normEMA2 && normOBV1 < normEMA1 && normOBV1 > InpOverboughtLevel && (normEMA1 - normOBV1) > 2.0){
   Print(normOBV1, " - ", InpOverboughtLevel, " - ", normEMA1);
      SellMarketPoint(InpMagicNumber, InpLotSize, InpStopLoss, InpTakeProfit, "Sell");
      }

  }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Normaliza valores para escala 0-100 (versão corrigida)           |
//+------------------------------------------------------------------+
double NormalizeValue(double value, int handle)
{
   double tempValues[];
   if(CopyBuffer(handle, 0, 0, InpLookback, tempValues) <= 0)
   {
      Print("Erro ao copiar dados para normalização");
      return 50; // Valor neutro se falhar
   }
   
   // Encontra máximos e mínimos absolutos
   double maxValue = tempValues[ArrayMaximum(tempValues)];
   double minValue = tempValues[ArrayMinimum(tempValues)];
   
   // Caso especial: todos valores iguais
   if(maxValue == minValue)
      return 50;
   
   // Normalização considerando valores negativos
   double normalized = 100 * (value - minValue) / (maxValue - minValue);
   
   // Limita entre 0-100 por segurança
   return MathMin(100, MathMax(0, normalized));
}