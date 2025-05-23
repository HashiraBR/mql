//+------------------------------------------------------------------+
//|                                                        Model.mq5 |
//|                                                    Danne Pereira |
//|                                             https://www.aipi.com |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+


#include "../../libs/DefaultInputs.mqh"
#include "../../libs/DefaultFunctions.mqh"

input int ADX_Period = 14;          // Período do ADX
input double ADX_Threshold = 25.0;  // Limiar mínimo de força de tendência

int stoch2mHandle, stoch3mHandle, stoch4mHandle, stoch5mHandle, stoch1mHandle;
double stoch2mMain[], stoch2mSignal[];
double stoch3mMain[], stoch3mSignal[];
double stoch4mMain[], stoch4mSignal[];
double stoch5mMain[], stoch5mSignal[];
double stoch1mMain[], stoch1mSignal[];

int adxHandle;
double adxValues[], diPlus[], diMinus[];

int OnInit()
  {
   InitializerATR();
   
   // Criar handles para os indicadores Stochastic
   stoch2mHandle = iStochastic(_Symbol, PERIOD_M2, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
   stoch3mHandle = iStochastic(_Symbol, PERIOD_M3, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
   stoch4mHandle = iStochastic(_Symbol, PERIOD_M4, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
   stoch5mHandle = iStochastic(_Symbol, PERIOD_M5, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
   stoch1mHandle = iStochastic(_Symbol, PERIOD_M1, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
   
   // Verificar se todos os handles foram criados com sucesso
   if(stoch2mHandle == INVALID_HANDLE || stoch3mHandle == INVALID_HANDLE ||
      stoch4mHandle == INVALID_HANDLE || stoch5mHandle == INVALID_HANDLE ||
      stoch1mHandle == INVALID_HANDLE)
   {
      Print("Erro ao criar handles dos indicadores Stochastic");
      return INIT_FAILED;
   }
   
   adxHandle = iADX(_Symbol, PERIOD_M5, ADX_Period);
   if(adxHandle == INVALID_HANDLE)
   {
      Print("Falha ao criar handle do ADX");
      return INIT_FAILED;
   }
   
   // Configurar arrays como series temporais
   ArraySetAsSeries(adxValues, true);
   ArraySetAsSeries(diPlus, true);
   ArraySetAsSeries(diMinus, true);
   
   // Configurar arrays como series temporais
   ArraySetAsSeries(stoch2mMain, true);
   ArraySetAsSeries(stoch2mSignal, true);
   ArraySetAsSeries(stoch3mMain, true);
   ArraySetAsSeries(stoch3mSignal, true);
   ArraySetAsSeries(stoch4mMain, true);
   ArraySetAsSeries(stoch4mSignal, true);
   ArraySetAsSeries(stoch5mMain, true);
   ArraySetAsSeries(stoch5mSignal, true);
   ArraySetAsSeries(stoch1mMain, true);
   ArraySetAsSeries(stoch1mSignal, true);
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   
   // Liberar todos os handles dos indicadores
   IndicatorRelease(stoch2mHandle);
   IndicatorRelease(stoch3mHandle);
   IndicatorRelease(stoch4mHandle);
   IndicatorRelease(stoch5mHandle);
   IndicatorRelease(stoch1mHandle);
   
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    
   if(!BasicFunction()) return;
   
   ENUM_TRADE_SIGNAL signal = CheckForTrade();
   
   
   // Determinar tendência com ADX
   bool isUptrend = (diPlus[0] > diMinus[0] && adxValues[0] > ADX_Threshold);
   bool isDowntrend = (diMinus[0] > diPlus[0] && adxValues[0] > ADX_Threshold);
   
   
   if(signal == TRADE_SIGNAL_BUY && isUptrend)
   {
      // Executar lógica de compra
      double sl = GetDefaultSmoothedATR() * InpAtrMultiplier;
      double tp = sl * InpTPRiskReward;
      
      sl = Rounder(sl) ;
      tp = Rounder(tp) ;
      BuyMarketPoint(InpMagicNumber, InpLotSize, sl, tp, "5-Stoch-Up");
   }
   else if(signal == TRADE_SIGNAL_SELL && isDowntrend)
   {
      // Executar lógica de venda
      // Executar lógica de compra
      double sl = GetDefaultSmoothedATR() * InpAtrMultiplier;
      double tp = sl * InpTPRiskReward;
      
      sl = Rounder(sl);
      tp = Rounder(tp);
      SellMarketPoint(InpMagicNumber, InpLotSize, sl, tp, "5-Stoch-Down");
   }
   
  }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| Enumeração para os sinais de trade                               |
//+------------------------------------------------------------------+
enum ENUM_TRADE_SIGNAL
{
   TRADE_SIGNAL_NONE,    // Nenhum sinal
   TRADE_SIGNAL_BUY,     // Sinal de compra
   TRADE_SIGNAL_SELL     // Sinal de venda
};

//+------------------------------------------------------------------+
//| Função principal para verificar condições de trade                |
//+------------------------------------------------------------------+
ENUM_TRADE_SIGNAL CheckForTrade()
{
   // Atualizar buffers para todos os timeframes
   if(!UpdateBuffers()) return TRADE_SIGNAL_NONE;
   
   // Verificar direção predominante nos timeframes maiores
   int buySignals = 0;
   int sellSignals = 0;
   
   CheckTimeframeCondition(stoch2mMain, stoch2mSignal, buySignals, sellSignals);
   CheckTimeframeCondition(stoch3mMain, stoch3mSignal, buySignals, sellSignals);
   CheckTimeframeCondition(stoch4mMain, stoch4mSignal, buySignals, sellSignals);
   CheckTimeframeCondition(stoch5mMain, stoch5mSignal, buySignals, sellSignals);
   
   // Determinar direção principal
   ENUM_TRADE_SIGNAL mainDirection = TRADE_SIGNAL_NONE;
   
   if(buySignals >= 3) mainDirection = TRADE_SIGNAL_BUY;  // Pelo menos 3/4 timeframes confirmando
   else if(sellSignals >= 3) mainDirection = TRADE_SIGNAL_SELL;
   
   if(mainDirection == TRADE_SIGNAL_NONE) return TRADE_SIGNAL_NONE;
   
   // Verificar cruzamento no 1min conforme direção principal
   bool is1mCrossedUp = (stoch1mMain[0] >= stoch1mSignal[0] && stoch1mMain[1] < stoch1mSignal[1]);
   bool is1mCrossedDown = (stoch1mMain[0] <= stoch1mSignal[0] && stoch1mMain[1] > stoch1mSignal[1]);
   
   if(mainDirection == TRADE_SIGNAL_BUY && !is1mCrossedUp) return TRADE_SIGNAL_NONE;
   if(mainDirection == TRADE_SIGNAL_SELL && !is1mCrossedDown) return TRADE_SIGNAL_NONE;
   
   return mainDirection;
}

//+------------------------------------------------------------------+
//| Atualiza todos os buffers                                        |
//+------------------------------------------------------------------+
bool UpdateBuffers()
{
   // Atualizar buffers para os timeframes maiores (2m, 3m, 4m, 5m)
   if(CopyBuffer(stoch2mHandle, 0, 0, 3, stoch2mMain) != 3 || CopyBuffer(stoch2mHandle, 1, 0, 3, stoch2mSignal) != 3 ||
      CopyBuffer(stoch3mHandle, 0, 0, 3, stoch3mMain) != 3 || CopyBuffer(stoch3mHandle, 1, 0, 3, stoch3mSignal) != 3 ||
      CopyBuffer(stoch4mHandle, 0, 0, 3, stoch4mMain) != 3 || CopyBuffer(stoch4mHandle, 1, 0, 3, stoch4mSignal) != 3 ||
      CopyBuffer(stoch5mHandle, 0, 0, 3, stoch5mMain) != 3 || CopyBuffer(stoch5mHandle, 1, 0, 3, stoch5mSignal) != 3 ||
      CopyBuffer(stoch1mHandle, 0, 0, 2, stoch1mMain) != 2 || CopyBuffer(stoch1mHandle, 1, 0, 2, stoch1mSignal) != 2)
   {
      Print("Falha ao copiar dados dos buffers");
      return false;
   }
   
   // Atualizar buffers do ADX
   if(CopyBuffer(adxHandle, 0, 0, 3, adxValues) != 3 ||
      CopyBuffer(adxHandle, 1, 0, 3, diPlus) != 3 ||
      CopyBuffer(adxHandle, 2, 0, 3, diMinus) != 3)
   {
      Print("Falha ao copiar dados do ADX");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Verifica condições para um timeframe específico                  |
//+------------------------------------------------------------------+
void CheckTimeframeCondition(const double &stochMain[], const double &stochSignal[], int &buySignals, int &sellSignals)
{
   // Verificar se está sobrevendido (zona de compra)
   bool isOversold = (stochMain[0] < 20 && stochSignal[0] < 20);
   
   // Verificar se está sobrecomprado (zona de venda)
   bool isOverbought = (stochMain[0] > 80 && stochSignal[0] > 80);
   
   // Verificar cruzamentos
   bool isCrossingUp = (stochMain[0] >= stochSignal[0] && stochMain[1] < stochSignal[1]);
   bool isCrossingDown = (stochMain[0] <= stochSignal[0] && stochMain[1] > stochSignal[1]);
   
   // Verificar direção das linhas (se não estiver em zona)
   bool isRising = (stochMain[0] > stochMain[1] && stochSignal[0] > stochSignal[1]);
   bool isFalling = (stochMain[0] < stochMain[1] && stochSignal[0] < stochSignal[1]);
   
   // Lógica para compra
   if((isOversold && (isCrossingUp || stochMain[0] > stochMain[1])) || 
      (!isOverbought && !isOversold && isRising && isCrossingUp))
   {
      buySignals++;
   }
   
   // Lógica para venda
   if((isOverbought && (isCrossingDown || stochMain[0] < stochMain[1])) || 
      (!isOverbought && !isOversold && isFalling && isCrossingDown))
   {
      sellSignals++;
   }
}