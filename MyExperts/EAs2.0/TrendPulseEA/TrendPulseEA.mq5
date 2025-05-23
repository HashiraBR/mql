//+------------------------------------------------------------------+
//|                                                 TrendPulseEA.mqh |
//|                                                    Danne Pereira |
//|                                             https://www.aipi.com |
//+------------------------------------------------------------------+
#property copyright "Danne Pereira"
#property link      "https://www.aipi.com"
#property version   "2.00"
#include <Trade/Trade.mqh>
#include "../../libs/COrderManager.mqh"
#include "../../libs/CRiskProtection.mqh"
#include "../../libs/CNotificationService.mqh"
#include "../../libs/CTradingConditions.mqh"
#include "../../libs/CDailyLimits.mqh" 
#include "../../libs/CTester.mqh" 
#include "../../libs/CUtils.mqh" 
#include "../../libs/CEAPanel.mqh"
#include "COutsiderBarStrategy.mqh"
#include "CTrendAcceleratorStrategy.mqh"
#include "CPullbackMovingAverageStrategy.mqh"



//+------------------------------------------------------------------+
//| Inputs do EA                                                    |
//+------------------------------------------------------------------+
// Configurações básicas
input string space00_ = "==========================================================================="; // ############ Configurações Operacionais ############
input int                  InpMagicNumber = 2000;         // Número mágico
input int                  InpMaxAgeSeconds = 119;        // Idade máxima ordens pendentes (segundos)
input double               InpMaxSLAllowed = 250;         // Máximo SL permitido (pontos)
input ENUM_TIMEFRAMES      InpTimeframe = PERIOD_M2;      // Período gráfico
input bool                 InpEnabledPanel = true;        // Habilitar/desabilitar Painel

// Configurações de risco
input string space01_ = "==========================================================================="; // ############ Configurações das Negociações ############
input double               InpLotSize = 1.0;              // Tamanho do lote
//input bool                 InpPointsBasedOnATR = false;   // Potos baseado em ATR (T:0~1, F:pontos)
input ENUM_SL_STRATEGY     InpStopLossStrategy = SL_FIXED;// Estratégia de stop loss
//input double               InpFixedStopLoss = 150;        // Stop loss fixo
input double               InpTrailingStart = 150;        // Trailing Stop: profit para início do trailing stop
input double               InpBreakevenProfit = 150;      // Breakeven: profit para fazer breakeven
input double               InpProgressiveStep = 200;      // Progressivo: passo do Trailing Stop
input double               InpProgressivePercent = 0.2;   // Progressivo: procentagem para proteger (0~1)
input ENUM_TP_STRATEGY     InpTakeProfitStrategy = TP_FIXED; // Estratégia de take profit
input double               InpFixedTakeProfit = 300;      // Take profit fixo
input double               InpRatioRiskReward = 2.0;      // Fator de risco retorno (RR)

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

input string space05_ = "==========================================================================="; // ############ Estrstégia: Outsidebar ############
input bool                 InpEnabledOutsidebarStrategy = true; // Habilitar/desabilitar estratégia
input int                  InpMAPeriodOutsideBar = 21;      // Período da MM
input ENUM_MA_METHOD       InpMAModeOutsideBar = MODE_SMA;  // Método de MM
input int                  InpRSIPeriodOutsideBar = 21;     // Período do RSI

input string space06_ = "==========================================================================="; // ############ Estrstégia: Accelerator ############
input bool                 InpEnabledAccelerator = true; // Habilitar/desabilitar estratégia
input int                  InpATRPeriodAcc = 21;         // Período do ATR para stop loss
input int                  InpMAVariationPeriodAcc = 7;  // Período da MM suavizadora do ATR
input ENUM_MA_METHOD       InpMAVariationModeAcc = MODE_EMA; // Modo da MM suavizadora do ATR
input int                  InpMaShortPeriodAcc = 9;      // Período MM curta
input ENUM_MA_METHOD       InpMAShortModeAcc = MODE_EMA; // Modo da MM curta
input int                  InpMALongPeriodAcc = 21;      // Período MM longa
input ENUM_MA_METHOD       InpMALongModeAcc = MODE_EMA;  // Modo da MM longa
input double               InpMinDist = 0.05;            // Inclinação da MM curta (%)

input string space07_ = "==========================================================================="; // ############ Estrstégia: Pullback ############
input bool                 InpEnabledPullBack= true;     // Habilitar/desabilitar estratégia
input int                  InpMaShortPeriodPB = 10;      // Período da Média Móvel Curta
input ENUM_MA_METHOD       InpMaShortModePB = MODE_EMA;  // Método da MM Curta
input int                  InpMaMediumPeriodPB = 20;     // Período da Média Móvel Média
input ENUM_MA_METHOD       InpMaMediumModePB = MODE_EMA; // Método da MM Média
input int                  InpMaLongPeriodPB = 50;       // Período da Média Móvel Longa
input ENUM_MA_METHOD       InpMaLongModePB = MODE_EMA;   // Método da MM Longa
input int                  InpWindowPB = 5;              // Janela de análise do pullback (candles)
input double               InpMinDistSMPB = 0.5;         // Distância mínima % entre MM Curta e Média
input double               InpMinDistMLPB = 0.5;         // Distância mínima % entre MM Média e Longa
input double               InpMinDistSLPB = 1.0;         // Distância mínima % entre MM Curta e Longa

//+------------------------------------------------------------------+
//| Objetos globais                                                  |
//+------------------------------------------------------------------+
CTrade* m_trade;
COrderManager *orderManager;
CRiskProtection *riskManager;
CNotificationService *notificationManager;
CTradingConditions *tradingManager;
CDailyLimits *limitsManager;
CPanelEA *panel;

COutsiderBarStrategy *outsidebar;
CTrendAcceleratorStrategy *accelerator;
CPullbackMovingAverageStrategy *pullback;

double m_stopLoss;

int OnInit()
{
   // Inicializa objetos
   m_trade = new CTrade();
   
   orderManager = new COrderManager(m_trade, InpMagicNumber, InpMaxSLAllowed, _Symbol);   
   riskManager = new CRiskProtection(m_trade, InpMagicNumber, _Symbol);
   notificationManager = new CNotificationService(InpMagicNumber, InpEmailEnabled, InpPushEnabled, InpLogToFile);
   tradingManager = new CTradingConditions(m_trade, InpMagicNumber, InpStartHour, InpStartMin, InpEndHour, InpEndMin, InpCloseAfterMin, InpTimeframe, _Symbol);
   limitsManager = new CDailyLimits(InpMagicNumber, InpDailyProfitLimit, InpDailyStopLossLimit, InpMaxConsecutiveLosses, InpMaxTrades, InpMaxPositions, InpMaxTradeLoss, _Symbol);
   outsidebar = new COutsiderBarStrategy(_Symbol, InpTimeframe, InpMAPeriodOutsideBar, InpRSIPeriodOutsideBar, InpMAModeOutsideBar);
   accelerator = new CTrendAcceleratorStrategy(_Symbol, InpTimeframe, InpATRPeriodAcc, InpMAVariationPeriodAcc, InpMAVariationModeAcc, InpMaShortPeriodAcc, InpMAShortModeAcc, InpMALongPeriodAcc, InpMALongModeAcc, InpMinDist);
   pullback = new CPullbackMovingAverageStrategy(_Symbol, InpMagicNumber, InpTimeframe, InpMaShortPeriodPB, InpMaShortModePB, InpMaMediumPeriodPB, InpMaMediumModePB, InpMaLongPeriodPB, InpMaLongModePB, InpWindowPB, InpMinDistSMPB, InpMinDistMLPB, InpMinDistSLPB);
   
   if(InpEnabledPanel){
      panel = new CPanelEA(InpMagicNumber, _Symbol, InpTimeframe);
      if (!panel.Create(0, ChartGetString(0, CHART_EXPERT_NAME), 0, 10, 30, 415, 425))
           return INIT_FAILED;
      panel.Run(); // <-- ESSENCIAL para os elementos aparecerem!
   }
   
   // Configurações adicionais
   m_trade.SetDeviationInPoints(10);
   m_trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   m_stopLoss = -1;
   
   EventSetTimer(1); // chama OnTimer a cada 1 segundo
   
   // Verifica ambiente de trading
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      //Alert("Trading não permitido pelo terminal!");
      //return INIT_FAILED;
   }
   
   return INIT_SUCCEEDED;
}


void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   panel.ChartEvent(id, lparam, dparam, sparam);
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
   if(CheckPointer(outsidebar) == POINTER_DYNAMIC) delete outsidebar;
   if(CheckPointer(accelerator) == POINTER_DYNAMIC) delete accelerator;
   if(CheckPointer(pullback) == POINTER_DYNAMIC) delete pullback;
   
   if(panel != NULL)
      panel.Destroy(reason);
   
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

void OnTick(void)
{
    
   // Gerenciamento de risco   
   if(orderManager.HasOpenPosition())
      riskManager.MonitorStopLoss(InpStopLossStrategy, m_stopLoss, InpTrailingStart, InpBreakevenProfit, InpProgressiveStep, InpProgressivePercent);
   
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
   if(InpEnabledOutsidebarStrategy && outsidebar.UpdateData()){
      if(outsidebar.IsBuySignal() || outsidebar.IsSellSignal()){
         double entryPrice = outsidebar.GetEntryPrice();
         double stopLossPoints = outsidebar.GetStopLossPoints();
         ENUM_ORDER_TYPE orderType = outsidebar.GetOrderType();
         double takeProfit = orderManager.GetTakeProfitPoints(InpTakeProfitStrategy, InpFixedTakeProfit, stopLossPoints, InpRatioRiskReward);
         //Print(orderType, " - ", entryPrice, " - ", stopLossPoints, " - ", takeProfit, " - ", "OutsideBar" );
         (orderType == ORDER_TYPE_BUY_STOP ? 
            orderManager.BuyStopPoint(entryPrice, InpLotSize, stopLossPoints, takeProfit, InpMaxAgeSeconds, "Outside+Up") :
            orderManager.SellStopPoint(entryPrice, InpLotSize, stopLossPoints, takeProfit, InpMaxAgeSeconds, "Outside+Down"));
         m_stopLoss = stopLossPoints; // Para Traling Stop Loss
         return;
      }
   }
   
   if(InpEnabledAccelerator && accelerator.UpdateData()) {
      if(accelerator.IsBuySignal() || accelerator.IsSellSignal()){
         double entryPrice = accelerator.GetEntryPrice();
         double stopLossPoints = accelerator.GetStopLossPoints();
         ENUM_ORDER_TYPE orderType = accelerator.GetOrderType();
         double takeProfit = orderManager.GetTakeProfitPoints(InpTakeProfitStrategy, InpFixedTakeProfit, stopLossPoints, InpRatioRiskReward);
         //Print(orderType, " - ", entryPrice, " - ", stopLossPoints, " - ", takeProfit, " - ", "Strong" );
         (orderType == ORDER_TYPE_BUY_LIMIT ? 
            orderManager.BuyLimitPoint(entryPrice, InpLotSize, stopLossPoints, takeProfit, InpMaxAgeSeconds, "Strong+UP") : 
            orderManager.SellLimitPoint(entryPrice, InpLotSize, stopLossPoints, takeProfit, InpMaxAgeSeconds, "Strong+DOWN"));
         m_stopLoss = stopLossPoints;
         return;
      }
   }
   
   if(InpEnabledPullBack && pullback.UpdateData()) {
      if(pullback.IsBuySignal() || pullback.IsSellSignal()) {
         double entryPrice = pullback.GetEntryPrice();
         double stopLossPoints = pullback.GetStopLossPoints();
         ENUM_ORDER_TYPE orderType = pullback.GetOrderType();
         double takeProfit = orderManager.GetTakeProfitPoints(InpTakeProfitStrategy, InpFixedTakeProfit, stopLossPoints, InpRatioRiskReward);
         //Print(orderType, " - ", entryPrice, " - ", stopLossPoints, " - ", takeProfit, " - ", "Pullback" );
         (orderType == ORDER_TYPE_BUY_STOP ? 
            orderManager.BuyStopPoint(entryPrice, InpLotSize, stopLossPoints, takeProfit, InpMaxAgeSeconds, "Pullback+UP") :
            orderManager.SellStopPoint(entryPrice, InpLotSize, stopLossPoints, takeProfit, InpMaxAgeSeconds, "Pullback+Down"));
         m_stopLoss = stopLossPoints;
         return;
      }   
   }
}

double OnTester(void)
  {
   CTester tester;
   return tester.CalculateOptimizationCriterion();
  }
  
