//+------------------------------------------------------------------+
//|                                                        Model.mq5 |
//|                                                    Danne Pereira |
//|                                             https://www.aipi.com |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+


#include "../libs/DefaultInputs.mqh"
#include "../libs/DefaultFunctions.mqh"
#include "../libs/CandleSignal.mqh"
#include "DTOscillatorStrategy.mqh"
#include "ADXStrategy.mqh"

//input bool   InpFirstSignal = true;       // Operar apenas um sinal por vez?
input string space000_ = "==========================================================================="; // ############ Configuração de Tendência ############
input int    InpEMAShortTimeframe = 21;   // Período da EMA
input int    InpEMALongTimeframe = 50;    // Período da EMA
input double InpDisMA = 0.01;             // Distância entre EMAs

input string space0 = "==========================================================================="; // ############ Estratégia: DT Oscillator ############
input bool   InpEnableDTStrategy = true;  // Habilita/desabilita a estratégia DT Oscillator
input int    InpRsiPeriod     = 12;       // Rsi period
input int    InpStochPeriod   = 12;       // Stochastic period
input int    InpSlowingPeriod = 5;        // Slowing 
input int    InpSignalPeriod  = 3;        // Signal period
input bool   InpTapeVisible   = true;     // Tape visibility
input int    InpDisDT = 1;                // Distância entre Oscillator e Signal

input string space2 = "==========================================================================="; // ############ Estratégia: ADX ############
input bool     InpEnableADXStrategy = true;     // Habilita/desabilita a estratégia ADX
input int      InpAdxPeriod = 14;               // Período do ADX
input int      InpADXStep   = 4;                // Salto do ADX para entrada


// ADX Strategy
int adxHandle;
double adx[], plusDI[], minusDI[];

// DT Strategy
int emaShortHandle;
int emaLongHandle;
double emaValueDT[];
double emaLongValueDT[];

double emaShort, emaLong;


int OnInit()
  {
    
   InitDTOscillator(InpStochPeriod, InpSlowingPeriod, InpSignalPeriod);
   // Obter handle da EMA
   emaShortHandle = iMA(_Symbol, InpTimeframe, InpEMAShortTimeframe, 0, MODE_EMA, PRICE_CLOSE);
   emaLongHandle = iMA(_Symbol, InpTimeframe, InpEMALongTimeframe, 0, MODE_EMA, PRICE_CLOSE);
   if(emaShortHandle == INVALID_HANDLE || emaLongHandle == INVALID_HANDLE)
   {
     Print("Erro ao criar handle da EMA");
     return INIT_SUCCEEDED;
   }
   
   ArraySetAsSeries(emaValueDT, true);
   ArraySetAsSeries(emaLongValueDT, true);
   
   adxHandle = iADX(_Symbol, InpTimeframe, InpAdxPeriod);
   if(adxHandle == INVALID_HANDLE)
   {
     Print("Erro ao criar handle do ADX");
     return INIT_SUCCEEDED;
   }
   
   ArraySetAsSeries(adx, true);
   ArraySetAsSeries(plusDI, true);
   ArraySetAsSeries(minusDI, true);

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {   
   
       IndicatorRelease(emaShortHandle);
       IndicatorRelease(emaLongHandle);
       
       IndicatorRelease(adxHandle);
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   
   if(!BasicFunction(InpMagicNumber)) 
      return;
   
   UpdateData();
   
   emaShort = emaValueDT[1];
   emaLong  = emaLongValueDT[1];
   
   bool upTrend   = emaShort > emaLong * (1 + InpDisMA / 100);
   bool downTrend = emaShort < emaLong * (1 - InpDisMA / 100);
   
   if(!upTrend && !downTrend) return;
   
   if(InpEnableADXStrategy  && !HasOpenPosition(InpMagicNumber))
      CheckForTradeADX(upTrend, downTrend);
   
   if(InpEnableDTStrategy  && !HasOpenPosition(InpMagicNumber))
      CheckForTradeDT(upTrend, downTrend);
  
}
  
  
void UpdateData(){
    
    // Copia os dados do indicador
    if(CopyBuffer(emaShortHandle, 0, 0, 2, emaValueDT) != 2 ||
       CopyBuffer(emaLongHandle, 0, 0, 2, emaLongValueDT) != 2)
     {
        Print("Failed to copy indicator buffers!");
        return;
    }
}
  