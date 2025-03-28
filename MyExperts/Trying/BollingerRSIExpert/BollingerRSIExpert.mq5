//+------------------------------------------------------------------+
//|                                         BollingerRSIExpert.mq5   |
//|                        Copyright © 2023, Danne M. G. Pereira     |
//|                              Email: makleyston@gmail.com         |
//|                              Site: www.aipi.com.br               |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2023, Danne M. G. Pereira"
#property link      "www.aipi.com.br"
#property version   "1.0"
#property description "BollingerRSIExpert - Expert Advisor baseado Bandas de Bollinger e RSI."
#property description " "
#property description "Funcionalidades:"
#property description "- Identifica sinais de 'esticamento' do preço e variações maiores que o desvio padrão das bandas de bollinger como entrada da operação."
#property description "- Opera com a tendência devicia definida, buscando pullbacks."
#property description "- As ordens são postas pendentes na máxima do candle anterior com time de expiração."
#property description "- Gerenciamento de risco com Stop Loss e Take Profit."
#property description " "
#property description "Recomendações:"
#property description "- Use, preferencialmente, no timeframe de M2."
#property icon "\\Images\\BollingerRSIExpert.ico" // Ícone personalizado (opcional)
#property script_show_inputs

#include "../DefaultInputs.mqh"
#include "../DefaultFunctions.mqh"

// Inputs do Expert Advisor
input int      InpBollingerPeriod = 8;          // Período das Bandas de Bollinger
input double   InpBollingerDeviation = 2.7;     // Desvio padrão das Bandas de Bollinger
input int      InpRSIPeriod = 14;               // Período do RSI
input double   InpRSIOverbought = 80.0;         // Nível de sobrecompra do RSI
input double   InpRSIOversold = 20.0;           // Nível de sobrevenda do RSI
input int      InpMAPeriod = 200;               // Período da Média Móvel

// Variáveis globais para armazenar os handles dos indicadores
int bbHandle, rsiHandle, maHandle;
double upperBand[1], lowerBand[1], rsi[1], ma[1];

bool previousCandleAboveUpperBand = false; // Indica se o candle anterior fechou acima da banda superior
bool previousCandleBelowLowerBand = false; // Indica se o candle anterior fechou abaixo da banda inferior

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Verifica se os parâmetros de entrada são válidos
   if(InpBollingerPeriod <= 0 || InpRSIPeriod <= 0 || InpLotSize <= 0 || InpMAPeriod <= 0)
   {
      Print("Parâmetros de entrada inválidos!");
      return(INIT_PARAMETERS_INCORRECT);
   }

   // Obtém os handles dos indicadores de Bollinger Bands, RSI e Média Móvel
   bbHandle = iBands(_Symbol, PERIOD_CURRENT, InpBollingerPeriod, 0, InpBollingerDeviation, PRICE_CLOSE);
   rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, InpRSIPeriod, PRICE_CLOSE);
   maHandle = iMA(_Symbol, PERIOD_CURRENT, InpMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
   
   // Verifica se os handles são válidos
   if(bbHandle == INVALID_HANDLE || rsiHandle == INVALID_HANDLE || maHandle == INVALID_HANDLE)
   {
      Print("Erro ao obter os handles dos indicadores.");
      return(INIT_FAILED);
   }

   // Configura os buffers como séries temporais
   ArraySetAsSeries(upperBand, true);
   ArraySetAsSeries(lowerBand, true);
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(ma, true);

   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // Limpeza, se necessário
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
   
   // Verifica horário de funcionamento e fecha posições
   if (!CheckTradingTime(InpMagicNumber)) return;
   if(HasOpenPosition(InpMagicNumber)) return;
   
   // Copia os valores das Bandas de Bollinger
   if(CopyBuffer(bbHandle, 1, 0, 1, upperBand) <= 0 ||
      CopyBuffer(bbHandle, 2, 0, 1, lowerBand) <= 0)
   {
      Print("Erro ao copiar os buffers das Bollinger Bands.");
      return;
   }

   // Copia os valores do RSI
   if(CopyBuffer(rsiHandle, 0, 0, 1, rsi) <= 0)
   {
      Print("Erro ao copiar o buffer do RSI.");
      return;
   }

   // Copia os valores da Média Móvel
   if(CopyBuffer(maHandle, 0, 0, 1, ma) <= 0)
   {
      Print("Erro ao copiar o buffer da Média Móvel.");
      return;
   }

   // Obtém o preço de fechamento do candle anterior
   double closePrice = iClose(_Symbol, _Period, 1);
   double highPrice = iHigh(_Symbol, _Period, 1);
   double lowPrice = iLow(_Symbol, _Period, 1);

   // Verifica a tendência
   bool isUptrend = (closePrice > ma[0]); // Tendência de alta: preço acima da média móvel
   bool isDowntrend = (closePrice < ma[0]); // Tendência de baixa: preço abaixo da média móvel

   // Lógica de negociação
   if (isUptrend && closePrice > upperBand[0] && rsi[0] >= InpRSIOverbought)
   {
      //Print("máxima: " + highPrice);
      // Condição de venda: tendência de alta, preço acima da banda superior e RSI acima do nível de sobrecompra
      PendingSellOrder(InpMagicNumber, highPrice, InpLotSize, InpStopLoss, InpTakeProfit, InpOrderExpiration, "Tend. alta, Preço > Banda Sup. e RSI alto");
   }
   else if (isDowntrend && closePrice < lowerBand[0] && rsi[0] <= InpRSIOversold)
   {
      //Print("mínima: " + lowPrice);
      // Condição de compra: tendência de baixa, preço abaixo da banda inferior e RSI abaixo do nível de sobrevenda
      PendingBuyOrder(InpMagicNumber, lowPrice, InpLotSize, InpStopLoss, InpTakeProfit, InpOrderExpiration, "Tend. baixa, Preço < Banda Inf. e RSI baixo");
   }
}