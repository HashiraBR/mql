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
#include "ADXStrategy.mqh"

input string space005 = "==========================================================================="; //===========================================================================
input string space2 = "==========================================================================="; // ############ Estratégia: ADX ############
input bool     InpEnableADXStrategy = true;     // Habilita/desabilita a estratégia ADX
input int      InpMagicNumberADX = 3003;        // Número mágico
input int      InpAdxPeriod = 14;               // Período do ADX
input int      InpADXStep   = 4;                // Salto do ADX para entrada

// ADX Strategy
int adxHandle;
double adx[], plusDI[], minusDI[];
// Fim ADX Strategy


int OnInit()
  {   
    if(InpEnableADXStrategy){
      adxHandle = iADX(_Symbol, InpTimeframe, InpAdxPeriod);
      
      ArraySetAsSeries(adx, true);
      ArraySetAsSeries(plusDI, true);
      ArraySetAsSeries(minusDI, true);
    }
    
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {   
    
    if(InpEnableADXStrategy){
      IndicatorRelease(adxHandle); 
    }
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    if(!BasicFunction()) return;
       
    if(InpEnableADXStrategy)
      CheckForTradeADX();
    
  }
  
  
  
  
  
  