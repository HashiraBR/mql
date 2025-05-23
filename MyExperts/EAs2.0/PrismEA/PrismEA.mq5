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
#include "../../libs/CEAPanel.mqh"
#include "CADXStrategy.mqh"
#include "CDTStrategy.mqh"


//+------------------------------------------------------------------+
//| Inputs do EA                                                    |
//+------------------------------------------------------------------+
// Configurações básicas
input string space00_ = "==========================================================================="; // ############ Configurações Operacionais ############
input int                  InpMagicNumber = 1000;         // Número mágico
input int                  InpMaxAgeSeconds = 119;        // Idade máxima ordens pendentes (segundos)
input double               InpMaxSLAllowed = 250;         // Máximo SL permitido (pontos)
input ENUM_TIMEFRAMES      InpTimeframe = PERIOD_M2;      // Período gráfico
input bool                 InpEnabledPanel = true;           // Mostrar painel

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
input double               InpTakeProfit = 300;           // Take profit 
//input double               InpRatioRiskReward = 2.0;    // Fator de risco retorno (RR)
input int                  InpMaxCandlesByTrade = 20;     // Quantidade máxima de candles por trade

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
input double               InpMaxTradeLoss = 100;         // Máx. perda por trade (BRL)
input int                  InpMaxConsecutiveLosses = 3;   // Máx. perdas consecutivas (0=desativado)
input int                  InpMaxTrades = 10;             // Máx. trades por dia (0=desativado)
input int                  InpMaxPositions = 3;           // Máx. posições abertas neste símbolo além desse EA (0=desativado)
input int                  InpMaxEATrades = 2;            // Máx. de trades simultâneos com este EA

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
input double               InpMADist = 2.0;              // Distância em % entre as Médias (evita falsos cruzamentos)

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
CPanelEA *panel;

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
   fixedTakeProfit = GetPoints(InpTakeProfit); 
   
   orderManager = new COrderManager(m_trade, InpMagicNumber, InpMaxSLAllowed, _Symbol);   
   riskManager = new CRiskProtection(m_trade, InpMagicNumber, _Symbol);
   notificationManager = new CNotificationService(InpMagicNumber, InpEmailEnabled, InpPushEnabled, InpLogToFile);
   tradingManager = new CTradingConditions(m_trade, InpMagicNumber, InpStartHour, InpStartMin, InpEndHour, InpEndMin, InpCloseAfterMin, _Period, _Symbol);
   limitsManager = new CDailyLimits(InpMagicNumber, InpDailyProfitLimit, InpDailyStopLossLimit, InpMaxConsecutiveLosses, InpMaxTrades, InpMaxPositions, InpMaxTradeLoss, _Symbol);
   
     if(InpEnabledPanel){
      panel = new CPanelEA(InpMagicNumber, _Symbol, InpTimeframe);
      int hPanel = 320 + (50 * InpMaxEATrades);
      if (!panel.Create(0, ChartGetString(0, CHART_EXPERT_NAME), 0, 10, 30, 415, hPanel))
           return INIT_FAILED;
      panel.Run(); // <-- ESSENCIAL para os elementos aparecerem!
   }
   
   
   EventSetTimer(1); // chama OnTimer a cada 1 segundo
   
   // Configurações adicionais
   m_trade.SetDeviationInPoints(10);
   m_trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   adxStrategy = new CADXStrategy(InpADXPeriod, InpADXStep, InpTimeframe, _Symbol);
   dtStrategy = new CDTStrategy(_Symbol, InpTimeframe, InpRSIPeriod, InpStochPeriod, InpSlowingPeriod, InpSignalPeriod, InpDistance, InpMAShortPeriod, InpMALongPeriod, InpMADist);
   
   // Verifica ambiente de trading
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      //Alert("Trading não permitido pelo terminal!");
      //return INIT_FAILED;
   }
   
   return INIT_SUCCEEDED;
}

  
void OnTimer()
{
    if (panel != NULL)
        panel.SyncAndUpdate();
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
   if(CheckPointer(panel) == POINTER_DYNAMIC) delete panel;
   
   EventKillTimer();
   
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
   fixedTakeProfit = GetPoints(InpTakeProfit); 
   
   // Gerenciamento de risco   
   if(orderManager.HasOpenPosition())
      orderManager.CheckAndCloseExpiredTrades(InpMagicNumber, InpMaxCandlesByTrade);
   
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
   if(orderManager.TotalOpenPosition() >= InpMaxEATrades)
     return;
   //if(orderManager.HasOpenPosition())
      //return;
   
   // Lógica principal de trading
   CheckForTrade();
}


void CheckForTrade(){
    
    if(!adxStrategy.UpdateData()) return;
    if(adxStrategy.IsBuySignal())
    {
        double tpPoints = orderManager.GetTakeProfitPoints(InpTakeProfitStrategy, InpTakeProfit, fixedStopLossPoints);
        orderManager.BuyMarketPoint(InpLotSize, fixedStopLossPoints, tpPoints, "ADX UP acelerado");
        return;
    }
    else if(adxStrategy.IsSellSignal())
    {
        double tpPoints = orderManager.GetTakeProfitPoints(InpTakeProfitStrategy, InpTakeProfit, fixedStopLossPoints);
        orderManager.SellMarketPoint(InpLotSize, fixedStopLossPoints, tpPoints, "ADX Down acelerado");
        return;
    }
    
    if(orderManager.TotalOpenPosition() >= InpMaxEATrades)
     return;
    
    if(!dtStrategy.UpdateData()) return;
    if(dtStrategy.IsBuySignal())
    {
        double tpPoints = orderManager.GetTakeProfitPoints(InpTakeProfitStrategy, InpTakeProfit, fixedStopLossPoints);
        orderManager.BuyMarketPoint(InpLotSize, fixedStopLossPoints, tpPoints, "DT+Candle Up");
        return;
    } else if(dtStrategy.IsSellSignal())
    {
        double tpPoints = orderManager.GetTakeProfitPoints(InpTakeProfitStrategy, InpTakeProfit, fixedStopLossPoints);
        orderManager.SellMarketPoint(InpLotSize, fixedStopLossPoints, tpPoints, "DT+Candle Down");
        return;
    } 
    
}

double GetPoints(double value){
   if(InpPointsBasedOnATR)
      return CUtils::Rounder(atr.GetValue() * value);
    return value;      
}


double OnTester()
  {
   CTester tester;
   double result = tester.CalculateOptimizationCriterion();
   return (result > 100 ? 0 : result);
  }

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
//Print(id, " - ", lparam, " - ", dparam, " - ", sparam);
   if(panel != NULL)
      panel.ChartEvent(id, lparam, dparam, sparam);
}
