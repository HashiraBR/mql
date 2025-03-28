//+------------------------------------------------------------------+
//|                                                        Model.mq5 |
//|                                                    Danne Pereira |
//|                                             https://www.aipi.com |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

#include "../DefaultFunctions.mqh"
#include "TrendAccelerationStrategy.mqh"
#include "PullbackMovingAverageStrategy.mqh"
#include "OutsideBarTrendStrategy.mqh"

enum ENUM_SL_TYPE {
   FIXED, //Fixo
   TRAILING, //Trailing
   PROGRESS //Progressivo
};

input string space0_ = "==========================================================================="; // #### Configurações Operacionais ####
// Identificação e Controle
input bool     InpSendEmail = true;             // Habilitar envio de e-mails
input bool     InpSendPushNotification = true;  // Habilitar envio de Push Notification
input int      InpOrderExpiration = 119;         // Tempo de expiração da ordem (em segundos)

// Horário de Negociação
input int      InpStartHour = 9;               // Hora de início das negociações (formato 24h)
input int      InpStartMinute = 0;             // Minuto de início das negociações
input int      InpEndHour = 17;                // Hora de término das negociações (formato 24h)
input int      InpEndMinute = 0;               // Minuto de término das negociações
input int      InpCloseAfterMinutes = 20;      // Encerrar posições após parar de operar (minutos)

// Configurações Técnicas
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M2; // Timeframe do gráfico

input string space00_ = "==========================================================================="; // #### Configurações de Negociações ####
input bool     InpFirstSignal = true;              // Operar um sinal por vez
input double   InpLotSize = 1.0;                   // Tamanho do lote
//input bool     InpTrailingStop = true;           // Trailing Stop Loss (true = móvel, false = fixo)
//input int      InpTrailingSLStartPoint = 0;      // Profit (pontos) para inicializar Trailing SL (0=cada tick)

input ENUM_SL_TYPE InpSLType = FIXED;              // Tipo de SL
input double   InpStopLoss = 100.0;                // SL Fixo (em pontos)
input int      InpTrailingSLStartPoint = 0;        // SL Trailing: Profit (pontos) para mover SL (0=cada tick)
input int      InpProgressSLProtectedPoints = 200; // SL Progress: Passo dos pontos de proteção
input double   InpProgressSLPercentToProtect = 50; // SL Progress: Porcentagem para proteger

input double   InpManageCapitalLoss = 100.0;       // Prejuízo máximo (R$) por operação (Gerenciamento de Capital)
input int InpMaxOpenPositions = 2; // Máximo de posições em aberto simultaneamente

input string space01_ = "==========================================================================="; // #### Estratégia: Aceleração Forte ####
input bool InpStrategyTrendAcceleration = true;    // Habilitar/desabilitar sinais baseados em Forte Aceleração
input int InpMagicNumberTrendAcceleration = 2001;  // Número Mágico
input int InpShortMAPeriodTrendA = 9;              // Período da MA curta
input int InpLongMAPeriodTrendA = 21;              // Período da MA longa
input ENUM_MA_METHOD InpMAModeTrendA = MODE_EMA;   // Tipo de MA
input double InpMinDisMATrenA = 0.03;              // Distância mín. entre MAs (em %)
input int InpTrueRangePeriodTrendA = 21;           // Período do True Range
input double InpSLFactorTrendA = 1.0;              // Stop Loss em fator de True Range
input double InpTPRatioTrendA = 2.0;               // Razão do Take Profit em fator True Range

input string space02_ = "==========================================================================="; // #### Estratégia: Pullbacks na MA ####
input bool InpStrategyPullbackMA = true;           // Habilitar/desabilitar sinais baseados em Pullbacks na MA
input int InpMagicNumberPullbackMA = 2002;         // Número Mágico
input int InpShortPeriodPB = 25;                   // Período da MA curta
input int InpMediumPeriodPB = 50;                  // Período da MA média
input int InpLongPeriodPB = 100;                   // Período da MA curta
input double InpMinDistSM = 0.01;                  // Distâcia mínima em % entre MA curta e média
input double InpMinDistML = 0.01;                  // Distâcia mínima em % entre MA média e longa
input double InpMinDistSL = 0.01;                  // Distâcia mínima em % entre MA curta e longa
input ENUM_MA_METHOD InpMAModePB = MODE_EMA;       // Tipo de MA
input int InpTimeWindowPB = 5;                     // Janela de tempo para identificação do sinal
input double InpTPRatioPB = 2.0;                   // Razão do TP em fator de SL (SL=máx/min do candle sinal)

input string space03_ = "==========================================================================="; // #### Estratégia: OutsideBar ####
input bool InpStrategyOutsideBar = true;           // Habilita/desabilita sinais baseados em Outsiders
input int InpMagicNumberOutsideBar = 2003;         // Número Mágico
input int InpRSIPeriodOut = 14;                    // Período do RSI
input int InpLongPeriodOut = 200;                  // Período da MA longa
input ENUM_MA_METHOD InpMAModeOut = MODE_SMA;      // Tipo de MA
input double InpBodySizeBarOut = 0.6;              // Tamanho mínimo (%) do corpo da barra em rel. sua variação.
input double InpTPRatioOut = 2.0;                  // Razão do TP em fator de SL (SL=máx/min do candle sinal)

// Variáveis Globais
//Estratégia Forte Aceleração
double bMAShortTrendA[], bMALongTrendA[], bTrueRange[1], bSmoothedTrueRange[1];
int maShortTrendAHandle, maLongTrendAHandle, trueRangeHandle, smoothedTrueRangeHandle;

//Estratégia Pullback na MA
double bMAShortPB[], bMAMediumPB[], bMALongPB[];
int maShortPBHandle, maMediumPBHandle, maLongPBHandle;

double bMALongOut[1], bRSIOut[1];
int maLongOutHandle, rsiOut;

double stopLossArray[3];
int magicNumberArray[3];
enum STRATEGY{
   TREND,
   PULLBACK,
   OUTSIDEBAR
};



int OnInit()
  {
   if(InpStrategyTrendAcceleration){
       // Obtém os valores das MAs
       maShortTrendAHandle = iMA(_Symbol, InpTimeframe, InpShortMAPeriodTrendA, 0, InpMAModeTrendA, PRICE_CLOSE);
       maLongTrendAHandle = iMA(_Symbol, InpTimeframe, InpLongMAPeriodTrendA, 0, InpMAModeTrendA, PRICE_CLOSE);
       
       ArraySetAsSeries(bMAShortTrendA, true);
       ArraySetAsSeries(bMALongTrendA, true);
   
       // Obtém o True Range suavizado
       trueRangeHandle = iATR(_Symbol, InpTimeframe, InpTrueRangePeriodTrendA);
       smoothedTrueRangeHandle = iMA(_Symbol, InpTimeframe, InpTrueRangePeriodTrendA, 0, MODE_SMMA, trueRangeHandle);
    }
    
    if(InpStrategyPullbackMA){
       maShortPBHandle = iMA(_Symbol, InpTimeframe, InpShortPeriodPB, 0, InpMAModePB, PRICE_CLOSE);
       maMediumPBHandle = iMA(_Symbol, InpTimeframe, InpMediumPeriodPB, 0, InpMAModePB, PRICE_CLOSE);
       maLongPBHandle = iMA(_Symbol, InpTimeframe, InpLongPeriodPB, 0, InpMAModePB, PRICE_CLOSE);
       
       ArraySetAsSeries(bMAShortPB, true);
       ArraySetAsSeries(bMAMediumPB, true);
       ArraySetAsSeries(bMALongPB, true);
    }
    
    if(InpStrategyOutsideBar){
      maLongOutHandle = iMA(_Symbol, InpTimeframe, InpLongPeriodPB, 0, InpMAModeOut, PRICE_CLOSE);
      rsiOut = iRSI(_Symbol, InpTimeframe, InpRSIPeriodOut, PRICE_CLOSE);
    }
    
    magicNumberArray[TREND] = InpMagicNumberTrendAcceleration;
    magicNumberArray[PULLBACK] = InpMagicNumberPullbackMA;
    magicNumberArray[OUTSIDEBAR] = InpMagicNumberOutsideBar;
    
    stopLossArray[TREND] = 200; // 200 pontos de garantia para caso dê algum problema não perder muito
    stopLossArray[PULLBACK] = 200;
    stopLossArray[OUTSIDEBAR] = 200;

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   
    if(!IsSignalFromCurrentDay(_Symbol, InpTimeframe))
      return;
      
    if(!MinCandles(InpShortMAPeriodTrendA, InpTimeframe))
      return;
      
    if (!CheckAndManagePositions(InpMaxOpenPositions)) 
        return;
    
    for (int i = 0; i < ArraySize(magicNumberArray); i++)
    {
        int magicNumber = magicNumberArray[i];
        
        ManageCapital(magicNumber, InpManageCapitalLoss);
   
        CheckStopsSkippedAndCloseTrade(magicNumber);
   
        CancelOldPendingOrders(magicNumber, InpOrderExpiration);
    
        if (InpSLType == TRAILING) MonitorTrailingStop(magicNumber, stopLossArray[i]);
        else if (InpSLType == PROGRESS) ProtectProfitProgressivo(magicNumber, InpProgressSLProtectedPoints, InpProgressSLPercentToProtect);

        CheckLastTradeAndSendEmail(magicNumber);
    }
    
    if (!isNewCandle()) 
        return;
    
    UpdateIndicators();
   
    bool hasAnyPosition = false;
    bool tradingTimeFlag = false;
    for (int i = 0; i < ArraySize(magicNumberArray); i++)
    {
        
       int magicNumber = magicNumberArray[i];
       
       // Verifica horário de funcionamento e fecha possições
       if (!CheckTradingTime(magicNumber)) {
           tradingTimeFlag = true;
       }
       
       bool hasPosition = HasOpenPosition(magicNumber); 
       if(InpFirstSignal && hasPosition) {
           hasAnyPosition = true;
       }
     }  
     
    if(tradingTimeFlag) return;
    
    if (InpFirstSignal && hasAnyPosition) {
        return;
    }

    CheckForTrade();
  }
//+------------------------------------------------------------------+

void CheckForTrade()
{
    // Verifica se a estratégia TrendAccelerationStrategy está ativa
    if (InpStrategyTrendAcceleration && !HasOpenPosition(magicNumberArray[TREND]))
    {
        TrendAccelerationStrategy();
    }

    // Verifica se a estratégia PullbackMovingAveragSTRATEGY está ativa
    if (InpStrategyPullbackMA && !HasOpenPosition(magicNumberArray[PULLBACK]))
    {
        PullbackMovingAverageStrategy();
    }

    // Verifica se a estratégia OutsideBarTrendStrategy está ativa
    if (InpStrategyOutsideBar && !HasOpenPosition(magicNumberArray[OUTSIDEBAR]))
    {
        OutsideBarTrendStrategy();
    }
}


// Códigos Gerais
void UpdateIndicators()
{
    // Copia os valores das MAs e do True Range
    if (InpStrategyTrendAcceleration)
    {
        if (CopyBuffer(maShortTrendAHandle, 0, 1, 2, bMAShortTrendA) <= 0 || // Copia 2 valores (índices 1 e 2)
            CopyBuffer(maLongTrendAHandle, 0, 1, 1, bMALongTrendA) <= 0 ||   // Copia 1 valor (índice 1)
            CopyBuffer(trueRangeHandle, 0, 1, 1, bTrueRange) <= 0 ||         // Copia 1 valor (índice 1)
            CopyBuffer(smoothedTrueRangeHandle, 0, 1, 1, bSmoothedTrueRange) <= 0) // Copia 1 valor (índice 1)
        {
            Print("Erro ao copiar os buffers dos indicadores da Estratégia Forte Aceleração.");
            return;
        }
    }

    if (InpStrategyPullbackMA)
    {
        if (CopyBuffer(maShortPBHandle, 0, 1, InpTimeWindowPB+1, bMAShortPB) <= 0 ||
            CopyBuffer(maMediumPBHandle, 0, 1, InpTimeWindowPB+1, bMAMediumPB) <= 0 ||
            CopyBuffer(maLongPBHandle, 0, 1, InpTimeWindowPB+1, bMALongPB) <= 0)
        {
            Print("Erro ao copiar os buffers dos indicadores da Estratégia Pullback na MA.");
            return;
        }
    }

    if (InpStrategyOutsideBar)
    {
        if (CopyBuffer(maLongOutHandle, 0, 1, 1, bMALongOut) <= 0 ||
            CopyBuffer(rsiOut, 0, 1, 1, bRSIOut) <= 0)
        {
            Print("Erro ao copiar os buffers dos indicadores da Estratégia OutsiderBar.");
            return;
        }
    }
}

bool MinCandles(int qtdCandles, ENUM_TIMEFRAMES tFrames){
   // Obter o tempo do primeiro candle do dia atual
   datetime startOfDay = TimeCurrent() - (TimeCurrent() % 86400); // Início do dia (00:00)
   int index = qtdCandles - 1;
   if (iTime(_Symbol, tFrames, index) >= startOfDay) // Índice 8 representa o 9º candle (índice começa em 0)
       return true;
   else
      return false;
}
