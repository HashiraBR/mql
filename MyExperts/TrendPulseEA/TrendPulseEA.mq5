//+------------------------------------------------------------------+
//|                                                        Model.mq5 |
//|                                                    Danne Pereira |
//|                                             https://www.aipi.com |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

#include "../libs/DefaultFunctions.mqh"
#include "../libs/DefaultInputs.mqh"
#include "TrendAccelerationStrategy.mqh"
#include "PullbackMovingAverageStrategy.mqh"
#include "OutsideBarTrendStrategy.mqh"

input bool     InpFirstSignal = true;              // Operar um sinal por vez

input string space1_ = "==========================================================================="; // ############ Estratégia: Aceleração Forte ############
input bool InpStrategyTrendAcceleration = true;    // Habilitar/desabilitar sinais baseados em Forte Aceleração
input int InpMagicNumberTrendAcceleration = 2001;  // Número Mágico
input int InpShortMAPeriodTrendA = 9;              // Período da MA curta
input int InpLongMAPeriodTrendA = 21;              // Período da MA longa
input ENUM_MA_METHOD InpMAModeTrendA = MODE_EMA;   // Tipo de MA
input double InpMinDisMATrenA = 0.03;              // Distância mín. entre MAs (em %)
input int InpTrueRangePeriodTrendA = 21;           // Período do True Range
input double InpSLFactorTrendA = 1.0;              // Stop Loss em fator de True Range
input double InpTPRatioTrendA = 2.0;               // Razão do Take Profit em fator True Range

input string space2_ = "==========================================================================="; // ############ Estratégia: Pullbacks na MA ############
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

input string space3_ = "==========================================================================="; // ############ Estratégia: OutsideBar ############
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
    
    double pointsLoss = NormalizeDouble(Rounder(InpManageCapitalLoss / (SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) / _Point)), _Digits);
    stopLossArray[TREND] = pointsLoss; // 200 pontos de garantia para caso dê algum problema não perder muito
    stopLossArray[PULLBACK] = pointsLoss;
    stopLossArray[OUTSIDEBAR] = pointsLoss;

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
  
    if(!MinCandles(InpShortMAPeriodTrendA, InpTimeframe))
      return;
      
    UpdateIndicators();
      
    for (int i = 0; i < ArraySize(magicNumberArray); i++){
        int magicNumber = magicNumberArray[i];
        if(!BasicFunction(magicNumber))
           continue;   

        int positionsTotal = GetOpenPositionTotal(magicNumberArray);
        if (InpFirstSignal && positionsTotal > 0)
            return;
   
        CheckForTrade();
    }
    
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
