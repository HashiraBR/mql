//+------------------------------------------------------------------+
//|                                         CandlesTrendMaster.mq5   |
//|                        Copyright © 2025, Danne M. G. Pereira     |
//|                              Email: comercial@autotradex.com.br  |
//|                              Site: www.autotradex.com.br         |
//+------------------------------------------------------------------+
#define URL "http://localhost:8080/license.json"
#define ID "Xv9#lQ2@m8"
#define PASS "tZ7!pK8@x4"

#property copyright "Copyright © 2025, AutoTradeX"
#property link      "www.autotradex.com.br"
#property version   "2.0"
#property description "CandlesWave - Expert Advisor baseado em padrões de candles, médias móveis e tendências e congestão."
#property description " "
#property description "Funcionalidades:"
#property description "- Identifica padrões de candles como Marubozu, Doji, Estrela Cadente e Martelo."
#property description "- Opera com base em médias móveis e tendências definidas."
#property description "- Seguidora de tendências."
#property description "- Gerenciamento de risco completo."
#property description "- Horário de negociação, envio de notificações, habilitação de estratégias totalmente configuráveis."
#property description "- Envio de e-mails para notificações."
#property description " "
#property description "Recomendações:"
#property description "- Timeframe: M2 e Símbolo WIN."
#property icon "\\Images\\CandlesWave.ico" // Ícone personalizado (opcional)
#property script_show_inputs
#property strict

#include <Trade/Trade.mqh>
#include "../../libs/COrderManager.mqh"
#include "../../libs/CRiskProtection.mqh"
#include "../../libs/CNotificationService.mqh"
#include "../../libs/CTradingConditions.mqh"
#include "../../libs/CDailyLimits.mqh" 
#include "../../libs/CTester.mqh" 
#include "../../libs/CUtils.mqh" 
#include "../../libs/CEAPanel.mqh"
#include "../../libs/CPositionManager.mqh"
#include "../../libs/CAuth.mqh"
#include "CCandleStrategy.mqh"
#include "CTrendStrategy.mqh"
#include "CCongestionStrategy.mqh"
#include "../../libs/structs/TradeSignal.mqh"
#include "../../libs/structs/PositionParams.mqh"


//+------------------------------------------------------------------+
//| Inputs do EA                                                    |
//+------------------------------------------------------------------+
// Configurações básicas
input string space00_ = "==========================================================================="; // ############ Configurações Operacionais ############
input string               InpLicense = "";               // Licença de uso
input int                  InpMagicNumber = 150;          // Número mágico
input int                  InpMaxAgeSeconds = 119;        // Idade máxima ordens pendentes (segundos)
input double               InpMaxSLAllowed = -1;          // Máximo SL permitido (pontos)
input ENUM_TIMEFRAMES      InpTimeframe = PERIOD_M2;      // Período gráfico
input bool                 InpEnabledPanel = true;        // Habilitar/desabilitar Painel

// Configurações de risco
input string space01_ = "==========================================================================="; // ############ Configurações das Negociações ############
input bool                 InpPointsBasedOnATR = false;      // Potos baseado em ATR (T:0~1, F:pontos)
input int                  InpAtrPeriod = -1;                // Período do ATR para cálculo de 
input int                  InpMAAtrPeriod = -1;              // Período de MM para suavizar ATR
input ENUM_SL_STRATEGY     InpStopLossStrategy = SL_FIXED;   // Estratégia de stop loss
input double               InpTrailingStart = -1;            // Trailing Stop: profit para início do trailing stop
input double               InpBreakevenProfit = -1;          // Breakeven: profit para fazer breakeven
input double               InpProgressiveStep = -1;          // Progressivo: passo do Trailing Stop
input double               InpProgressivePercent = -1;       // Progressivo: procentagem para proteger (0~1)
input ENUM_TP_STRATEGY     InpTakeProfitStrategy = TP_FIXED; // Estratégia de take profit
input int                  InpMaxCandlesByTrade = -1;        // Quantidade máxima de candles por trade

// Configurações de horário
input string space02_ = "==========================================================================="; // ############ Configurações de Horários ############
input int                  InpStartHour = -1;             // Hora início trading
input int                  InpStartMin = -1;              // Minuto início trading
input int                  InpEndHour = -1;               // Hora fim trading
input int                  InpEndMin = -1;                // Minuto fim trading
input int                  InpCloseAfterMin = -1;         // Fechar após minutos fora do horário

// Limites diários
input string space03_ = "==========================================================================="; // ############ Gestão de Capital ############
input double               InpDailyProfitLimit = -1;      // Limite lucro diário (BRL)
input double               InpDailyStopLossLimit = -1;    // Limite perda diária (BRL)
input int                  InpMaxConsecutiveLosses = -1;  // Máx. perdas consecutivas (0=desativado)
input int                  InpMaxTrades = -1;             // Máx. trades por dia (0=desativado)
input int                  InpMaxPositions = -1;          // Máx. posições abertas simultâneas neste símbolo (0=desativado)
input int                  InpEAMaxPositions = 1;         // Máx. posições abertas simultâneas com este EA (0=desativado)
input double               InpMaxTradeLoss = -1;          // Máx. perda por trade (BRL)
//input bool                 InpMultiSignalPerCandle = true;// Multiplos sinais por candle

// Notificações
input string space04_ = "==========================================================================="; // ############ Configurações de Notificações ############
input bool                 InpEmailEnabled = true;       // Habilitar e-mails
input bool                 InpPushEnabled = false;       // Habilitar notificações push
input bool                 InpLogToFile = true;          // Log em arquivo

input string space05_ = "==========================================================================="; // ############ Configurações de tendências ############
input int                  InpMAShortPeriod = -1;        // Média Móvel Curta
input int                  InpMAMediumPeriod = -1;       // Média Móvel Média
input int                  InpMALongPeriod = -1;         // Média Móvel Longa
input ENUM_MA_METHOD       InpMAShortMode = MODE_EMA;    // Modo da MM Curta
input ENUM_MA_METHOD       InpMAMediumMode = MODE_EMA;   // Modo da MM Média
input ENUM_MA_METHOD       InpMALongMode = MODE_EMA;     // Modo da MM Longa
input double               InpDistSM = -1;               // Distância entre MM Curta e Média
input double               InpDistML = -1;               // Distância entre MM Média e Longa
input double               InpDistSL = -1;               // Distância entre MM Curta e Longa

input string space06 = "==========================================================================="; // ############ Estratégia de Padrões de Candle ############
input bool                 InpEnabledCandleStrategy = true;      // Usar estratégia de padrões de candles
input int                  InpCandleStrategyVolumePeriod = 5;    // Quantidade de candles para cálculo da média do volume

input string space07 = "==========================================================================="; // ############ Marubozu GREEN ############
// Configurações do padrão Marubozu Verde
input bool                 PATTERN_MARUBOZU_GREEN_Enabled = true;       // Habilita/desabilita o padrão Marubozu Verde
input double               PATTERN_MARUBOZU_GREEN_MinRange = -1;        // Variação mínima do candle  
input double               PATTERN_MARUBOZU_GREEN_MaxRange = -1;        // Variação máxima do candle  
input double               PATTERN_MARUBOZU_GREEN_LotSize =  -1;        // Tamanho do lote para operações 
input double               PATTERN_MARUBOZU_GREEN_StopLoss = -1;        // Stop Loss 
input double               PATTERN_MARUBOZU_GREEN_TakeProfit = -1;      // Take Profit 

input string space08 = "==========================================================================="; // ############ Marubozu RED ############
// Configurações do padrão Marubozu Vermelho
input bool                 PATTERN_MARUBOZU_RED_Enabled = true;      // Habilita/desabilita o padrão Marubozu Vermelho
input double               PATTERN_MARUBOZU_RED_MinRange = -1;       // Variação mínima do candle  
input double               PATTERN_MARUBOZU_RED_MaxRange = -1;       // Variação máxima do candle  
input double               PATTERN_MARUBOZU_RED_LotSize = -1;        // Tamanho do lote para operações
input double               PATTERN_MARUBOZU_RED_StopLoss = -1;       // Stop Loss para operações
input double               PATTERN_MARUBOZU_RED_TakeProfit = -1;     // Take Profit 

input string space09 = "==========================================================================="; // ############ Estrela Cadente RED ############
// Configurações do padrão Estrela Cadente RED (Shooting Star RED)
input bool                 PATTERN_SHOOTING_STAR_RED_Enabled = true;       // Habilita/desabilita o padrão Estrela Cadente Red
input double               PATTERN_SHOOTING_STAR_RED_MinRange = -1;       // Variação mínima do candle 
input double               PATTERN_SHOOTING_STAR_RED_LotSize = -1;        // Tamanho do lote para operações 
input double               PATTERN_SHOOTING_STAR_RED_StopLoss = -1;        // Stop Loss 
input double               PATTERN_SHOOTING_STAR_RED_TakeProfit = -1;     // Take Profit 

input string space10 = "==========================================================================="; // ############ Estrela Cadente GREEN ############
// Configurações do padrão Estrela Cadente GREEN (Shooting Star GREEN)
input bool                 PATTERN_SHOOTING_STAR_GREEN_Enabled = true;        // Habilita/desabilita o padrão Estrela Cadente Green
input double               PATTERN_SHOOTING_STAR_GREEN_MinRange = -1;        // Variação mínima do candle 
input double               PATTERN_SHOOTING_STAR_GREEN_LotSize = -1;         // Tamanho do lote para operações 
input double               PATTERN_SHOOTING_STAR_GREEN_StopLoss = -1;         // Stop Loss 
input double               PATTERN_SHOOTING_STAR_GREEN_TakeProfit = -1;      // Take Profit 

input string space11 = "==========================================================================="; // ############ Martelo GREEN ############
// Configurações do padrão Martelo (Hammer)
input bool                 PATTERN_HAMMER_GREEN_Enabled = true;         // Habilita/desabilita o padrão Martelo Green
input double               PATTERN_HAMMER_GREEN_MinRange = -1;         // Variação mínima do candle  
input double               PATTERN_HAMMER_GREEN_LotSize = -1;          // Tamanho do lote para operações 
input double               PATTERN_HAMMER_GREEN_StopLoss = -1;          // Stop Loss 
input double               PATTERN_HAMMER_GREEN_TakeProfit = -1;       // Take Profit 

input string space12 = "==========================================================================="; // ############ Martelo RED ############
input bool                 PATTERN_HAMMER_RED_Enabled = true;        // Habilita/desabilita o padrão Martelo Red
input double               PATTERN_HAMMER_RED_MinRange = -1;        // Variação mínima do candle  
input double               PATTERN_HAMMER_RED_LotSize = -1;         // Tamanho do lote para operações 
input double               PATTERN_HAMMER_RED_StopLoss = -1;         // Stop Loss 
input double               PATTERN_HAMMER_RED_TakeProfit = -1;      // Take Profit 

input string space13 = "==========================================================================="; // ############ Estratégia de Continuação de Tendência ############
input bool                 InpEnabledTrendStrategy = true;          // Habilita/desabilida estratégia.
input double               InpTrendLotSize = -1;                    // Tamanho do lote
input int                  InpTrendStrategyVolumePeriod = -1;       // Quantidade de candles para cálculo da média do volume
input double               InpTrendCandleLongPercent = -1;          // % mín. que o candle deve ser maior que o anterior
input double               InpTrendMaxCandleRange = -1;             // Tamanho máximo para o candle signal
input double               InpTrendStopLoss = -1;                   // Stop loss
input double               InpTrendTakeProfit = -1;                 // Take profit

input string space14 = "==========================================================================="; // ############ Estratégia de Congestão ############
input bool                 InpEnabledCongestionStrategy = true;       // Habilitar/desabilitar estratégia   
input int                  InpCongestionShortPeriod = -1;             // Período da MM Curta da congestão
input int                  InpCongestionMediumPeriod = -1;            // Período da MM Médiada congestão
input int                  InpCongestionLongPeriod = -1;              // Período da MM Longda congestão
input double               InpDistMaxSM = -1;                         // Distância máxima das MMs Curta e Média
input double               InpDistMaxML = -1;                         // Distância máxima das MMs Média e Longa
input double               InpDistMinLvls = -1;                       // Distância mínima entre níveis S&R
input int                  InpLookback = -1;                          // Total de candles para análise
input double               InpCongestionLotSize = -1;                 // Tamanho do lote
input double               InpWeightFactor = -1;                      // Peso para preços extremos dos candles
input int                  InpCongestionVolumePeriod = -1;            // Periodo para análise do volume
input double               InpCongestionTakeProfit = -1;              // Takeprofit


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
CPositionManager *positionManager;
CAuth *auth;

CCandleStrategy *candle;
CTrendStrategy *trendStrategy;
CCongestionStrategy *congestion;

//+------------------------------------------------------------------+
//| Variáveis Globais                                                                  |
//+------------------------------------------------------------------+
int m_atrHandle, m_maAtrHandle;
double m_atrValue[], m_maAtrValue[];
int m_maShortHandle, m_maMediumHandle, m_maLongHandle;
double m_maShortBuffer[], m_maMediumBuffer[], m_maLongBuffer[];

PatternConfig patternConfigs[9];

const int trendStrategyIndex           = 1;
const int candleStrategyIndex          = 2;
const int congestionStrategyIndex      = 3;
const string trendStrategyTitle        = "[TREND] ";
const string candleStrategyTitle       = "[CAND.] ";
const string congestionStrategyTitle   = "[CONG.] ";

int OnInit()
{
   
   //auth = new CAuth(URL,InpLicense, );
   // Verifica a assinatura
   /* if(!webService.CheckSubscription())
    {
        Alert("Assinatura inválida ou expirada. Por favor, renove sua assinatura.");
        return INIT_FAILED;
    }*/
    
    // Verifica expiração próxima (novo)
   // webService.CheckExpirationWarning();

   // Inicializa objetos
   m_trade = new CTrade();
   m_trade.SetDeviationInPoints(10);
   m_trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   m_atrHandle = iATR(_Symbol, InpTimeframe, InpAtrPeriod);
   m_maAtrHandle = iMA(_Symbol, InpTimeframe, InpMAAtrPeriod, 0, MODE_SMMA, m_atrHandle);
   if(m_atrHandle == INVALID_HANDLE || m_maAtrHandle == INVALID_HANDLE){
      Print("Erro ao cirar o ATR");
      return INIT_FAILED;
   }
   
   orderManager = new COrderManager(m_trade, InpMagicNumber, InpMaxSLAllowed, _Symbol);   
   riskManager = new CRiskProtection(m_trade, InpMagicNumber, _Symbol);
   notificationManager = new CNotificationService(InpMagicNumber, InpEmailEnabled, InpPushEnabled, InpLogToFile);
   tradingManager = new CTradingConditions(m_trade, InpMagicNumber, InpStartHour, InpStartMin, InpEndHour, InpEndMin, InpCloseAfterMin, InpTimeframe, _Symbol);
   limitsManager = new CDailyLimits(InpMagicNumber, InpDailyProfitLimit, InpDailyStopLossLimit, InpMaxConsecutiveLosses, InpMaxTrades, InpMaxPositions, InpMaxTradeLoss, _Symbol);  
   positionManager = new CPositionManager(InpEAMaxPositions); 
   
   // Inicializa as configurações dos padrões
    patternConfigs[PATTERN_MARUBOZU_GREEN].enabled = PATTERN_MARUBOZU_GREEN_Enabled;
    patternConfigs[PATTERN_MARUBOZU_GREEN].minRange = PATTERN_MARUBOZU_GREEN_MinRange;
    patternConfigs[PATTERN_MARUBOZU_GREEN].maxRange = PATTERN_MARUBOZU_GREEN_MaxRange;
    patternConfigs[PATTERN_MARUBOZU_GREEN].lotSize = PATTERN_MARUBOZU_GREEN_LotSize;
    patternConfigs[PATTERN_MARUBOZU_GREEN].stopLoss = PATTERN_MARUBOZU_GREEN_StopLoss;
    patternConfigs[PATTERN_MARUBOZU_GREEN].takeProfit = PATTERN_MARUBOZU_GREEN_TakeProfit;

    patternConfigs[PATTERN_MARUBOZU_RED].enabled = PATTERN_MARUBOZU_RED_Enabled;
    patternConfigs[PATTERN_MARUBOZU_RED].minRange = PATTERN_MARUBOZU_RED_MinRange;
    patternConfigs[PATTERN_MARUBOZU_RED].maxRange = PATTERN_MARUBOZU_RED_MaxRange;
    patternConfigs[PATTERN_MARUBOZU_RED].lotSize = PATTERN_MARUBOZU_RED_LotSize;
    patternConfigs[PATTERN_MARUBOZU_RED].stopLoss = PATTERN_MARUBOZU_RED_StopLoss;
    patternConfigs[PATTERN_MARUBOZU_RED].takeProfit = PATTERN_MARUBOZU_RED_TakeProfit;

    patternConfigs[PATTERN_SHOOTING_STAR_RED].enabled = PATTERN_SHOOTING_STAR_RED_Enabled;
    patternConfigs[PATTERN_SHOOTING_STAR_RED].minRange = PATTERN_SHOOTING_STAR_RED_MinRange;
    patternConfigs[PATTERN_SHOOTING_STAR_RED].maxRange = 0;
    patternConfigs[PATTERN_SHOOTING_STAR_RED].lotSize = PATTERN_SHOOTING_STAR_RED_LotSize;
    patternConfigs[PATTERN_SHOOTING_STAR_RED].stopLoss = PATTERN_SHOOTING_STAR_RED_StopLoss;
    patternConfigs[PATTERN_SHOOTING_STAR_RED].takeProfit = PATTERN_SHOOTING_STAR_RED_TakeProfit;
    
    patternConfigs[PATTERN_SHOOTING_STAR_GREEN].enabled = PATTERN_SHOOTING_STAR_GREEN_Enabled;
    patternConfigs[PATTERN_SHOOTING_STAR_GREEN].minRange = PATTERN_SHOOTING_STAR_GREEN_MinRange;
    patternConfigs[PATTERN_SHOOTING_STAR_GREEN].maxRange = 0;
    patternConfigs[PATTERN_SHOOTING_STAR_GREEN].lotSize = PATTERN_SHOOTING_STAR_GREEN_LotSize;
    patternConfigs[PATTERN_SHOOTING_STAR_GREEN].stopLoss = PATTERN_SHOOTING_STAR_GREEN_StopLoss;
    patternConfigs[PATTERN_SHOOTING_STAR_GREEN].takeProfit = PATTERN_SHOOTING_STAR_GREEN_TakeProfit;

    patternConfigs[PATTERN_HAMMER_GREEN].enabled = PATTERN_HAMMER_GREEN_Enabled;
    patternConfigs[PATTERN_HAMMER_GREEN].minRange = PATTERN_HAMMER_GREEN_MinRange;
    patternConfigs[PATTERN_HAMMER_GREEN].maxRange = 0;
    patternConfigs[PATTERN_HAMMER_GREEN].lotSize = PATTERN_HAMMER_GREEN_LotSize;
    patternConfigs[PATTERN_HAMMER_GREEN].stopLoss = PATTERN_HAMMER_GREEN_StopLoss;
    patternConfigs[PATTERN_HAMMER_GREEN].takeProfit = PATTERN_HAMMER_GREEN_TakeProfit;
    
    patternConfigs[PATTERN_HAMMER_RED].enabled = PATTERN_HAMMER_RED_Enabled;
    patternConfigs[PATTERN_HAMMER_RED].minRange = PATTERN_HAMMER_RED_MinRange;
    patternConfigs[PATTERN_HAMMER_RED].maxRange = 0;
    patternConfigs[PATTERN_HAMMER_RED].lotSize = PATTERN_HAMMER_RED_LotSize;
    patternConfigs[PATTERN_HAMMER_RED].stopLoss = PATTERN_HAMMER_RED_StopLoss;
    patternConfigs[PATTERN_HAMMER_RED].takeProfit = PATTERN_HAMMER_RED_TakeProfit;
   
   candle = new CCandleStrategy(_Symbol, InpTimeframe, InpCandleStrategyVolumePeriod, patternConfigs);
   trendStrategy = new CTrendStrategy(_Symbol, InpTimeframe, InpTrendStrategyVolumePeriod, InpTrendCandleLongPercent, InpTrendStopLoss, InpTrendTakeProfit, InpTrendLotSize);
   congestion = new CCongestionStrategy(_Symbol, InpTimeframe, InpLookback, InpWeightFactor, InpCongestionShortPeriod, InpCongestionMediumPeriod, 
   InpCongestionLongPeriod, InpDistMaxSM, InpDistMaxML, InpCongestionLotSize, InpCongestionTakeProfit, InpDistMinLvls, InpCongestionVolumePeriod, "CCS", clrRed, clrGreen);
   
   if(!congestion.Init())
   {
      Alert("Falha ao inicializar a estratégia de Congestão!");
      return INIT_FAILED;
   }
   
   ArrayResize(m_maShortBuffer, InpLookback);
   ArrayResize(m_maMediumBuffer, InpLookback);
   ArrayResize(m_maLongBuffer, InpLookback);
   
   ArraySetAsSeries(m_maShortBuffer, true);
   ArraySetAsSeries(m_maMediumBuffer, true);
   ArraySetAsSeries(m_maLongBuffer, true);
   
   if(InpEnabledPanel){
      panel = new CPanelEA(InpMagicNumber, _Symbol, InpTimeframe);
      int hPanel = 320 + (50 * InpEAMaxPositions);
      if (!panel.Create(0, ChartGetString(0, CHART_EXPERT_NAME), 0, 10, 30, 415, hPanel))
           return INIT_FAILED;
      panel.Run(); // <-- ESSENCIAL para os elementos aparecerem!
   }
   
   EventSetTimer(1); // chama OnTimer a cada 1 segundo
   
   // Verifica ambiente de trading
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      //Alert("Trading não permitido pelo terminal!");
      //return INIT_FAILED;
   }
   
   m_maShortHandle = iMA(_Symbol, InpTimeframe, InpMAShortPeriod, 0, InpMAShortMode, PRICE_CLOSE);
   m_maMediumHandle = iMA(_Symbol, InpTimeframe, InpMAMediumPeriod, 0, InpMAMediumMode, PRICE_CLOSE);
   m_maLongHandle = iMA(_Symbol, InpTimeframe, InpMALongPeriod, 0, InpMALongMode, PRICE_CLOSE);
   
   if (m_maShortHandle == INVALID_HANDLE || m_maMediumHandle == INVALID_HANDLE || m_maLongHandle == INVALID_HANDLE) {
        Print("Erro: Falha ao criar os indicadores de média móvel.");
        return INIT_FAILED;
   }
   
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   // Qualquer alteração já projete o EA de operar.
   if(CheckPointer(m_trade) == POINTER_DYNAMIC) delete m_trade;

   // Motivos relacionados a mudanças no gráfico
   if(reason == REASON_CHARTCHANGE || reason == REASON_PARAMETERS)
{
   Alert("═══════════════════════════════════════════════════");
   Alert("  ATENÇÃO: Alteração detectada no gráfico");
   Alert("═══════════════════════════════════════════════════");
   Alert("Por questões de segurança e estabilidade do sistema,");
   Alert("o Expert Advisor será encerrado automaticamente.\n");
   Alert("Por favor:");
   Alert("1. Feche este gráfico");
   Alert("2. Abra um novo gráfico com o par ativo e timeframe desejado");
   Alert("3. Reinicie o Expert Advisor com os novos parâmetros");
   Alert("Isso garante a inicialização correta de todos os recursos");
   Alert("e previne possíveis inconsistências no funcionamento.");
   Alert("═══════════════════════════════════════════════════");
   Alert("O gráfico está sendo fechado automaticamente! Até logo.");
   
   Comment("ATENÇÃO: Alteração detectada no gráfico\nVerifique os alertas acima.");
   Sleep(5000);
}

   // Limpa todos os objetos alocados dinamicamente
   if(CheckPointer(orderManager) == POINTER_DYNAMIC) delete orderManager;
   if(CheckPointer(riskManager) == POINTER_DYNAMIC) delete riskManager;
   if(CheckPointer(notificationManager) == POINTER_DYNAMIC) delete notificationManager;
   if(CheckPointer(tradingManager) == POINTER_DYNAMIC) delete tradingManager;
   if(CheckPointer(limitsManager) == POINTER_DYNAMIC) delete limitsManager;
   if(CheckPointer(trendStrategy) == POINTER_DYNAMIC) delete trendStrategy;
   if(CheckPointer(candle) == POINTER_DYNAMIC) delete candle;
   if(CheckPointer(positionManager) == POINTER_DYNAMIC) delete positionManager;
   if(CheckPointer(panel) == POINTER_DYNAMIC) delete panel;
   
   congestion.RemoveVisuals();
   if(CheckPointer(congestion) == POINTER_DYNAMIC) delete congestion;
   
   EventKillTimer();
   
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

void OnTimer(void)
{
   if (panel != NULL)
     panel.SyncAndUpdate();
}

void OnTick(void)
{
    // 1. Gerenciamento de posições existentes
    ManageOpenPositions();
   
    // 2. Verificações iniciais rápidas
    if(!IsTradingAllowed()) return;
    
    // 3. Verificar novas oportunidades de trade
    if(positionManager.Total() < InpEAMaxPositions) {
        CheckForTrade();
    }
}

void ManageOpenPositions()
{
    // Notificação do trade
    notificationManager.CheckLastTradeForNotification();

    // Limpeza e monitoramento consolidado
    positionManager.CleanUp();
    positionManager.CleanInvalidTickets(); // Remove tickets inválidos
    positionManager.CleanupStrategyMap();  // Limpa mapeamento de estratégias
    
    // Se alcançar o tempo limite do trade, essa função fecha a operação
    if(orderManager.HasOpenPosition())
      orderManager.CheckAndCloseExpiredTrades(InpMagicNumber, InpMaxCandlesByTrade);
    
    // Gerenciamento de risco para posições abertas
    PositionParams params;
    for(int i = positionManager.Total()-1; i >= 0; i--)
    {
        ulong ticket = positionManager.GetTicket(i);
        if(positionManager.GetParams(ticket, params)) 
        {
            riskManager.MonitorStopLossByTicket(
                ticket,
                InpStopLossStrategy,
                params.stopLoss,
                params.trailingStart,
                params.breakevenProfit,
                params.progressiveStep,
                InpProgressivePercent
            );
        }else{// Há ticket para o ativo e EA, mas, certamente, o EA foi reiniciado e não´há params em memória 
            riskManager.MonitorStopLossByTicket(
               ticket,
                InpStopLossStrategy,
                InpTrendStopLoss, //Usa o TREND STRATEGY como padrão
                InpTrendStopLoss,
                InpTrendStopLoss,
                InpTrendStopLoss,
                InpProgressivePercent
            );
        }
    }
    
    orderManager.CancelOldPendingOrders(InpMaxAgeSeconds);
}

bool IsTradingAllowed()
{
    // Todas as verificações de ambiente em um só lugar
    if(!limitsManager.CheckDailyLimits()) return false;
    if(!tradingManager.IsTradingAllowed()) return false;
    
    return true;
}

void CheckForTrade()
{
    // 1. Verificação de congestão (sempre independente de tendência)
    if(InpEnabledCongestionStrategy && 
       positionManager.Total() < InpEAMaxPositions && 
       positionManager.GetStrategyPosition(congestionStrategyIndex) == 0) // ≤── Bloqueia múltiplos trades
    {
        CheckCongestionStrategy();
    }

    // 2. Verificação de tendência (resto do código permanece igual)
    ENUM_TREND_DIRECTION trend = DetermineMarketTrend();
    if(trend == TREND_NONE) return;

    // 3. Estratégias condicionais (com MultiSignalPerCandle aplicável)
    if(InpEnabledCandleStrategy && 
       positionManager.Total() < InpEAMaxPositions &&
       (positionManager.GetStrategyPosition(candleStrategyIndex) == 0))
    {
        CheckCandlePatternStrategy(trend);
    }

    if(InpEnabledTrendStrategy && 
       positionManager.Total() < InpEAMaxPositions &&
       (positionManager.GetStrategyPosition(trendStrategyIndex) == 0))
    {
        CheckTrendStrategy(trend);
    }
}

ENUM_TREND_DIRECTION DetermineMarketTrend()
{
    // Leitura simplificada das MAs
    double maShort = GetMAValue(m_maShortHandle);
    double maMedium = GetMAValue(m_maMediumHandle);
    double maLong = GetMAValue(m_maLongHandle);
    
    if(maShort > maMedium * (1 + InpDistSM/100) && 
       maMedium > maLong * (1 + InpDistML/100)) {
        return TREND_UP;
    }
    else if(maShort < maMedium * (1 - InpDistSM/100) && 
            maMedium < maLong * (1 - InpDistML/100)) {
        return TREND_DOWN;
    }
    return TREND_NONE;
}


void CheckCandlePatternStrategy(ENUM_TREND_DIRECTION trend)
{
    if(!InpEnabledCandleStrategy) return;
    
    TradeSignal signal = candle.CheckForSignal(trend, GetMAValue(m_maLongHandle), GetAtrPoints());
    if(signal.isValid) {
        ExecuteTrade(signal, candleStrategyIndex);
    }
}

void CheckTrendStrategy(ENUM_TREND_DIRECTION trend)
{
    if(!InpEnabledTrendStrategy) return;
    
    TradeSignal signal = trendStrategy.CheckForSignal(GetMAValue(m_maShortHandle), trend, GetPoints(InpTrendMaxCandleRange));
    if(signal.isValid && signal.direction == trend) {
        ExecuteTrade(signal, trendStrategyIndex);
    }
}

void CheckCongestionStrategy()
{
    if(!InpEnabledCongestionStrategy) return;
    TradeSignal signal = congestion.CheckForSignal(GetAtrPoints());
    if(signal.isValid) {
        ExecuteTrade(signal, congestionStrategyIndex);
    }
}

void ExecuteTrade(const TradeSignal &signal, int strategyIndex)
{
    if(positionManager.GetStrategyPosition(strategyIndex) > 0) {
        return;
    }
    
    PositionParams params;
    SetTradeParams(params, signal);
    
    DebugPosition(params);
    
    bool success = (signal.direction == TREND_UP) ? 
                  orderManager.BuyMarketPoint(params.lotSize, params.stopLoss, params.takeProfit, params.comment) :
                  orderManager.SellMarketPoint(params.lotSize, params.stopLoss, params.takeProfit, params.comment);
    
    if(success) {
        RegisterNewPosition(params, strategyIndex);
    }
}

void DebugPosition(PositionParams &params)
{
    Print("===== DEBUG DE POSIÇÃO =====");
    Print("Tipo de Posição: ", EnumToString(params.positionType));
    Print("Símbolo: ", _Symbol); // Assumindo que é para o símbolo atual
    Print("Preço de Abertura: ", params.openPrice > 0 ? DoubleToString(params.openPrice, _Digits) : "à mercado");
    Print("Horário de Abertura: ", TimeToString(params.openTime, TIME_DATE|TIME_SECONDS));
    Print("Tamanho do Lote: ", DoubleToString(params.lotSize, 2));
    Print("Stop Loss: ", params.stopLoss > 0 ? DoubleToString(params.stopLoss, _Digits) : "Nenhum");
    Print("Take Profit: ", params.takeProfit > 0 ? DoubleToString(params.takeProfit, _Digits) : "Nenhum");
    Print("Trailing Start: ", params.trailingStart > 0 ? DoubleToString(params.trailingStart, _Digits) : "Desativado");
    Print("Breakeven Profit: ", params.breakevenProfit > 0 ? DoubleToString(params.breakevenProfit, _Digits) : "Desativado");
    Print("Progressive Step: ", params.progressiveStep > 0 ? DoubleToString(params.progressiveStep, _Digits) : "Desativado");
    Print("Comentário: ", params.comment != "" ? params.comment : "Nenhum");
    Print("============================");
}

void SetTradeParams(PositionParams &params, const TradeSignal &signal)
{
    params.stopLoss = GetPoints(signal.stopLoss);
    params.takeProfit = CalculateTakeProfit(signal.stopLoss, signal.takeProfit);
    params.trailingStart = GetPoints(InpTrailingStart);
    params.breakevenProfit = GetPoints(InpBreakevenProfit);
    params.progressiveStep = GetPoints(InpProgressiveStep);
    params.comment = signal.comment;
    params.positionType = (signal.direction == TREND_UP) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
    params.lotSize = signal.lotSize;
    params.openPrice = signal.openPrice;
}

double CalculateTakeProfit(double slPoints, double tpPoints)
{
    return (InpTakeProfitStrategy == TP_RISK_REWARD) ? 
           GetPoints(tpPoints * slPoints) : 
           GetPoints(tpPoints);
}

void RegisterNewPosition(const PositionParams &params, int strategyIndex)
{
    ulong ticket = orderManager.GetLastTicket();
    if(ticket > 0 && PositionSelectByTicket(ticket))
    {
        PositionParams finalParams = params;
        finalParams.openTime = TimeCurrent();
        finalParams.openPrice = PositionGetDouble(POSITION_PRICE_OPEN); // ← MQL5
        
        positionManager.AddPosition(ticket, finalParams);
        positionManager.AddStrategyPosition(strategyIndex, ticket);
    }
    else
    {
        Print("Falha ao selecionar posição para ticket: ", ticket);
    }
}

double GetMAValue(int maHandle)
{
    // 1. Verificar se o handle é válido
    if(maHandle == INVALID_HANDLE)
    {
        Print("Erro: Handle de MA inválido");
        return 0.0;
    }

    // 2. Buffer para o valor da MA
    double maValue[1];
    
    // 3. Copiar o valor mais recente
    if(CopyBuffer(maHandle, 0, 0, 1, maValue) <= 0)
    {
        Print("Falha ao copiar buffer da MA. Código de erro: ", GetLastError());
        return 0.0;
    }

    // 4. Verificar se o valor é válido
    if(!NormalizeDouble(maValue[0], _Digits))
    {
        Print("Valor inválido da MA: ", maValue[0]);
        return 0.0;
    }

    return maValue[0];
}

double GetAtrPoints()
{
    if(!InpPointsBasedOnATR)
        return 1.0;

    if(CopyBuffer(m_maAtrHandle, 0, 0, 1, m_maAtrValue) <= 0) {
        Print("Erro ao copiar dados do ATR: ", GetLastError());
        return -1.0;
    }

    return CUtils::Rounder(CUtils::GetSymbolPoints(m_maAtrValue[0]));
}

double GetPoints(double value){
   return value * GetAtrPoints();
}

double OnTester()
{
   CTester tester;
   return tester.CalculateOptimizationCriterion();
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
//Print(id, " - ", lparam, " - ", dparam, " - ", sparam);
   if(panel != NULL)
      panel.ChartEvent(id, lparam, dparam, sparam);
}