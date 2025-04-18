//+------------------------------------------------------------------+
//|                                                        Model.mq5 |
//|                                                    Danne Pereira |
//|                                             https://www.aipi.com |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

#include <Trade/Trade.mqh>
#include "../../libs/COrderManager.mqh"
#include "../../libs/CRiskProtection.mqh"
#include "../../libs/CNotificationService.mqh"
#include "../../libs/CTradingConditions.mqh"
#include "../../libs/CDailyLimits.mqh" 
#include "../../libs/CSmoothedATR.mqh" 
#include "../../libs/CUtils.mqh" 
#include "../../libs/CTester.mqh" 
#include "CADXStrategy.mqh"
#include "CDTStrategy.mqh"

//+------------------------------------------------------------------+
//| Inputs do EA                                                    |
//+------------------------------------------------------------------+
// Configurações básicas
input string space00_ = "==========================================================================="; // ############ Configurações Operacionais ############
input int                  InpMagicNumber = 12345;        // Número mágico
input int                  InpMaxAgeSeconds = 119;        // Idade máxima ordens pendentes (segundos)
input double               InpMaxSLAllowed = 250;         // Máximo SL permitido (pontos)
input ENUM_TIMEFRAMES      InpTimeframe = PERIOD_M2;      // Período gráfico

// Configurações de risco
input string space01_ = "==========================================================================="; // ############ Configurações das Negociações ############
input double               InpLotSize = 1.0;              // Tamanho do lote
input bool                 InpPointsBasedOnATR = false;   // Potos baseado em ATR (T:0~1, F:pontos)
input ENUM_SL_STRATEGY     InpStopLossStrategy = SL_FIXED;// Estratégia de stop loss
input double               InpFixedStopLoss = 150;        // Stop loss fixo
input double               InpTrailingStart = 150;        // Trailing Stop: profit para início do trailing stop
input double               InpBreakevenProfit = 150;      // Breakeven: profit para fazer breakeven
input double               InpProgressiveStep = 200;      // Progressivo: passo do Trailing Stop
input double               InpProgressivePercent = 0.2;   // Progressivo: procentagem para proteger (0~1)
input ENUM_TP_STRATEGY     InpTakeProfitStrategy = TP_FIXED; // Estratégia de take profit
input double               InpFixedTakeProfit = 300;              // Take profit fixo
input double               InpRatioRiskReward = 2.0;           // Fator de risco retorno (RR)

// Configurações de horário
input string space02_ = "==========================================================================="; // ############ Configurações de Horários ############
input int                  InpStartHour = 9;             // Hora início trading
input int                  InpStartMin = 0;              // Minuto início trading
input int                  InpEndHour = 17;              // Hora fim trading
input int                  InpEndMin = 0;                // Minuto fim trading
input int                  InpCloseAfterMin = 20;        // Fechar após minutos fora do horário

// Limites diários
input string space03_ = "==========================================================================="; // ############ Gestão de Capital ############
input double               InpDailyProfitLimit = 500;     // Limite lucro diário (BRL)
input double               InpDailyStopLossLimit = 300;   // Limite perda diária (BRL)
input int                  InpMaxConsecutiveLosses = 3;   // Máx. perdas consecutivas (0=desativado)
input int                  InpMaxTrades = 10;             // Máx. trades por dia (0=desativado)
input int                  InpMaxPositions = 3;           // Máx. posições abertas (0=desativado)
input double               InpMaxTradeLoss = 100;         // Máx. perda por trade (BRL)

// Notificações
input string space04_ = "==========================================================================="; // ############ Configurações de Notificações ############
input bool                 InpEmailEnabled = true;       // Habilitar e-mails
input bool                 InpPushEnabled = false;       // Habilitar notificações push
input bool                 InpLogToFile = true;          // Log em arquivo

// Estratégia
input string space05_ = "==========================================================================="; // ############ Configurações da Estratégia ADX ############
input int                  InpADXPeriod = 21;            // Período ADX
input double               InpADXStep = 2;               // Salto do ADX (aceleração do ADX)

input string space06_ = "==========================================================================="; // ############ Configurações da Estratégia DT Oscillator ############
input int                  InpRSIPeriod = 14;            // Período do RSI
input int                  InpStochPeriod = 14;          // Período do Estocástico
input int                  InpSlowingPeriod = 5;         // Período do DT Lento
input int                  InpSignalPeriod = 3;          // Período do Sinal DT
input double               InpDistance = 4;              // Distância entre DT e Sinal (evita falsos cruzamentos)
input int                  InpMAShortPeriod = 21;        // Período da EMA
input int                  InpMALongPeriod = 50;         // Período da EMA
input double               InpMADist = 2.0;              // Distância entre as Médias (evita falsos cruzamentos)

//+------------------------------------------------------------------+
//| Objetos globais                                                  |
//+------------------------------------------------------------------+
CTrade* m_trade;
COrderManager *orderManager;
CRiskProtection *riskManager;
CNotificationService *notificationManager;
CTradingConditions *tradingManager;
CDailyLimits *limitsManager;
CSmoothedATR *atr;
CADXStrategy *adxStrategy;
CDTStrategy *dtStrategy;

double fixedStopLossPoints;
double trailingStartPoints;
double breakevenProfitPoints;
double progressiveStepPoints;
double fixedTakeProfit;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Inicializa objetos
   m_trade = new CTrade();
   
   atr = new CSmoothedATR(_Symbol, InpTimeframe, 14, 7);
   if(!atr.Initialize()) return INIT_FAILED;
   
   fixedStopLossPoints = GetPoints(InpFixedStopLoss);
   trailingStartPoints = GetPoints(InpTrailingStart);
   breakevenProfitPoints = GetPoints(InpBreakevenProfit);
   progressiveStepPoints = GetPoints(InpProgressiveStep);
   fixedTakeProfit = GetPoints(InpFixedTakeProfit); 
   
   orderManager = new COrderManager(m_trade, InpMagicNumber, InpMaxSLAllowed, _Symbol);   
   riskManager = new CRiskProtection(m_trade, InpMagicNumber, _Symbol);
   notificationManager = new CNotificationService(InpMagicNumber, InpEmailEnabled, InpPushEnabled, InpLogToFile);
   tradingManager = new CTradingConditions(m_trade, InpMagicNumber, InpStartHour, InpStartMin, InpEndHour, InpEndMin, InpCloseAfterMin, _Period, _Symbol);
   limitsManager = new CDailyLimits(InpMagicNumber, InpDailyProfitLimit, InpDailyStopLossLimit, InpMaxConsecutiveLosses, InpMaxTrades, InpMaxPositions, InpMaxTradeLoss, _Symbol);
   
   // Configurações adicionais
   m_trade.SetDeviationInPoints(10);
   m_trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   adxStrategy = new CADXStrategy(InpADXPeriod, InpADXStep, InpTimeframe, _Symbol);
   dtStrategy = new CDTStrategy(_Symbol, InpTimeframe, InpRSIPeriod, InpStochPeriod, InpSlowingPeriod, InpSignalPeriod, InpDistance, InpMAShortPeriod, InpMALongPeriod, InpMADist);
   
   // Verifica ambiente de trading
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      Alert("Trading não permitido pelo terminal!");
      return INIT_FAILED;
   }
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Limpa todos os objetos alocados dinamicamente
   if(CheckPointer(m_trade) == POINTER_DYNAMIC) delete m_trade;
   if(CheckPointer(orderManager) == POINTER_DYNAMIC) delete orderManager;
   if(CheckPointer(riskManager) == POINTER_DYNAMIC) delete riskManager;
   if(CheckPointer(notificationManager) == POINTER_DYNAMIC) delete notificationManager;
   if(CheckPointer(tradingManager) == POINTER_DYNAMIC) delete tradingManager;
   if(CheckPointer(limitsManager) == POINTER_DYNAMIC) delete limitsManager;
   if(CheckPointer(atr) == POINTER_DYNAMIC) delete atr;
   if(CheckPointer(adxStrategy) == POINTER_DYNAMIC) delete adxStrategy;
   if(CheckPointer(dtStrategy) == POINTER_DYNAMIC) delete dtStrategy;
   
   // Log de desinicialização
   string reasonText;
   switch(reason)
   {
      case REASON_PROGRAM:        reasonText = "Expert removido do gráfico"; break;
      case REASON_REMOVE:         reasonText = "Programa auto-removido"; break;
      case REASON_RECOMPILE:      reasonText = "Expert recompilado"; break;
      case REASON_CHARTCHANGE:    reasonText = "Símbolo/período alterado"; break;
      case REASON_CHARTCLOSE:     reasonText = "Gráfico fechado"; break;
      case REASON_PARAMETERS:     reasonText = "Parâmetros alterados"; break;
      case REASON_ACCOUNT:        reasonText = "Conta alterada"; break;
      case REASON_TEMPLATE:       reasonText = "Template alterado"; break;
      default:                    reasonText = "Razão desconhecida";
   }
   
   Print("EA desinicializado. Motivo: ", reasonText);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Gerenciamento de risco
   fixedStopLossPoints = GetPoints(InpFixedStopLoss);
   trailingStartPoints = GetPoints(InpTrailingStart);
   breakevenProfitPoints = GetPoints(InpBreakevenProfit);
   progressiveStepPoints = GetPoints(InpProgressiveStep);
   fixedTakeProfit = GetPoints(InpFixedTakeProfit); 
   
   riskManager.MonitorStopLoss(InpStopLossStrategy, fixedStopLossPoints, trailingStartPoints, breakevenProfitPoints, progressiveStepPoints, InpProgressivePercent);
   
   // Cancela ordens velhas
   orderManager.CancelPendingOrders(InpMaxAgeSeconds);
   
   // Verifica limites
   if(!limitsManager.ManageTradingLimits())
      return;
   
   // Verifica condições de trading
   if(!tradingManager.IsTradingAllowed())
      return;
   
   // Verifica se já tem posição aberta
   if(orderManager.HasOpenPosition())
      return;
   
   // Lógica principal de trading
   CheckForTrade();
}


void CheckForTrade(){
    
    if(!adxStrategy.UpdateData()) return;
    if(adxStrategy.IsBuySignal())
    {
        double tpPoints = orderManager.GetTakeProfitPoints(InpTakeProfitStrategy, fixedTakeProfit, fixedStopLossPoints, InpRatioRiskReward);
        orderManager.BuyMarketPoint(InpLotSize, fixedStopLossPoints, tpPoints, "ADX UP acelerado");
        return;
    }
    else if(adxStrategy.IsSellSignal())
    {
        double tpPoints = orderManager.GetTakeProfitPoints(InpTakeProfitStrategy, fixedTakeProfit, fixedStopLossPoints, InpRatioRiskReward);
        orderManager.SellMarketPoint(InpLotSize, fixedStopLossPoints, tpPoints, "ADX Down acelerado");
        return;
    }
    
    if(!dtStrategy.UpdateData()) return;
    if(dtStrategy.IsBuySignal())
    {
        double tpPoints = orderManager.GetTakeProfitPoints(InpTakeProfitStrategy, fixedTakeProfit, fixedStopLossPoints, InpRatioRiskReward);
        orderManager.BuyMarketPoint(InpLotSize, fixedStopLossPoints, tpPoints, "DT+Candle Up");
        return;
    } else if(dtStrategy.IsSellSignal())
    {
        double tpPoints = orderManager.GetTakeProfitPoints(InpTakeProfitStrategy, fixedTakeProfit, fixedStopLossPoints, InpRatioRiskReward);
        orderManager.SellMarketPoint(InpLotSize, fixedStopLossPoints, tpPoints, "DT+Candle Down");
        return;
    } 
    
}

double GetPoints(double value){
   if(InpPointsBasedOnATR)
      return CUtils::Rounder(atr.GetValue() * value);
    return value;      
}


double OnTester(void)
  {
   CTester tester;
   
   //--- Obter estatísticas básicas
   double profit = TesterStatistics(STAT_PROFIT);
   int total_trades = (int)TesterStatistics(STAT_TRADES);
   double pf = TesterStatistics(STAT_PROFIT_FACTOR);
   double sharpe = TesterStatistics(STAT_SHARPE_RATIO);
   double dd_pct = TesterStatistics(STAT_BALANCEDD_PERCENT);
   double expected_payoff= TesterStatistics(STAT_EXPECTED_PAYOFF);
   
   //--- Filtros rigorosos
   if(total_trades < 30 || total_trades > 350)     return -1.0;  // Mínimo de trades
   if(dd_pct > 25.0)                               return -1.0;  // Drawdown máximo
   if(pf < 1.5)                                    return -1.0;  // Fator de lucro mínimo
   if(sharpe < 5)                                  return -1.0;  // Risco/retorno
   if (expected_payoff < 8.0)                      return -1.0;  // Retorno esperado
   
   return tester.CalculateOptimizationCriterion();
  }


/*
double OnTester()
  {
//--- valor do critério de otimização personalizado (quanto mais, melhor)
   double ret=0.0;
//--- obtemos os resultados dos trades na matriz
   double array[];
   double trades_volume;
   GetTradeResultsToArray(array,trades_volume);
   int trades=ArraySize(array);
//--- se há menos de 10 trades, o teste não gerou resultados positivos
   if(trades<10)
      return (0);
//--- resultado médio no trade
   double average_pl=0;
   for(int i=0;i<ArraySize(array);i++)
      average_pl+=array[i];
   average_pl/=trades;
//--- exibimos uma mensagem para o modo de teste único
   if(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_OPTIMIZATION))
      PrintFormat("%s: Trades=%d, Lucro médio=%.2f",__FUNCTION__,trades,average_pl);
//--- calculamos os coeficientes de regressão linear para o gráfico de lucro
   double a,b,std_error;
   double chart[];
   if(!CalculateLinearRegression(array,chart,a,b))
      return (0);
//--- calculamos o erro de desvio do gráfico em relação à linha de regressão
   if(!CalculateStdError(chart,a,b,std_error))
      return (0);
//--- calculamos o rácio do lucro de tendência em relação ao desvio padrão
   ret=(std_error == 0.0) ? a*trades : a*trades/std_error;
//--- retornamos o valor do critério de otimização personalizado
   return(ret);
  }
//+------------------------------------------------------------------+
//| Obtendo a matriz de lucros/perdas de transações                  |
//+------------------------------------------------------------------+
bool GetTradeResultsToArray(double &pl_results[],double &volume)
  {
//--- consultamos o histórico de negociação completo
   if(!HistorySelect(0,TimeCurrent()))
      return (false);
   uint total_deals=HistoryDealsTotal();
   volume=0;
//--- definimos o tamanho inicial da matriz pelo número de transações no histórico
   ArrayResize(pl_results,total_deals);
//--- contador de trades que fixam o resultado da negociação - lucro ou perda
   int counter=0;
   ulong ticket_history_deal=0;
//--- passar por todos os trades
   for(uint i=0;i<total_deals;i++)
     {
      //--- selecionamos o trade 
      if((ticket_history_deal=HistoryDealGetTicket(i))>0)
        {
         ENUM_DEAL_ENTRY deal_entry  =(ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket_history_deal,DEAL_ENTRY);
         long            deal_type   =HistoryDealGetInteger(ticket_history_deal,DEAL_TYPE);
         double          deal_profit =HistoryDealGetDouble(ticket_history_deal,DEAL_PROFIT);
         double          deal_volume =HistoryDealGetDouble(ticket_history_deal,DEAL_VOLUME);
         //--- estamos interessados apenas em operações de negociação        
         if((deal_type!=DEAL_TYPE_BUY) && (deal_type!=DEAL_TYPE_SELL))
            continue;
         //--- somente trades com fixação de lucro/perda
         if(deal_entry!=DEAL_ENTRY_IN)
           {
            //--- escrevemos o resultado da negociação na matriz e aumentamos o contador de trades
            pl_results[counter]=deal_profit;
            volume+=deal_volume;
            counter++;
           }
        }
     }
//--- definimos o tamanho final da matriz
   ArrayResize(pl_results,counter);
   return (true);
  }
//+------------------------------------------------------------------+
//| Calculando a regressão linear de tipo y=a*x+b                    |
//+------------------------------------------------------------------+
bool CalculateLinearRegression(double  &change[],double &chartline[],
                               double  &a_coef,double  &b_coef)
  {
//--- verificamos se há suficientes dados
   if(ArraySize(change)<3)
      return (false);
//--- criamos a matriz do gráfico com acumulação
   int N=ArraySize(change);
   ArrayResize(chartline,N);
   chartline[0]=change[0];
   for(int i=1;i<N;i++)
      chartline[i]=chartline[i-1]+change[i];
//--- agora calculamos os coeficientes de regressão
   double x=0,y=0,x2=0,xy=0;
   for(int i=0;i<N;i++)
     {
      x=x+i;
      y=y+chartline[i];
      xy=xy+i*chartline[i];
      x2=x2+i*i;
     }
   a_coef=(N*xy-x*y)/(N*x2-x*x);
   b_coef=(y-a_coef*x)/N;
//---
   return (true);
  }
//+------------------------------------------------------------------+
//|  Calcula o erro quadrático médio do desvio para os a e b definidos    
//+------------------------------------------------------------------+
bool  CalculateStdError(double  &data[],double  a_coef,double  b_coef,double &std_err)
  {
//--- soma dos quadrados dos erros
   double error=0;
   int N=ArraySize(data);
   if(N<=2)
      return (false);
   for(int i=0;i<N;i++)
      error+=MathPow(a_coef*i+b_coef-data[i],2);
   std_err=MathSqrt(error/(N-2));
//--- 
   return (true);
  }
  */