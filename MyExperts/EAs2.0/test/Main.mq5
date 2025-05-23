//+------------------------------------------------------------------+
//|                                              CandlesTrendMaster.mq5 |
//|                        Copyright © 2023, Danne M. G. Pereira     |
//|                              www.aipi.com.br                     |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2023, Danne M. G. Pereira"
#property link      "www.aipi.com.br"
#property version   "2.0"
#property description "Expert Advisor baseado em padrões de candles e médias móveis"
#property description "Opera com base em padrões de candles como Marubozu, Doji, Estrela Cadente e Martelo"
#property description "Usar preferencialmente no timeframe M2"
#property icon "\\Images\\CandlesMaster.ico"
#property strict

#include <Trade/Trade.mqh>
#include "CCandleStrategy.mqh"

//+------------------------------------------------------------------+
//| Input Parameters                                                |
//+------------------------------------------------------------------+
input string group1 = "=== Configurações Gerais ===";
input int      InpMagicNumber = 2000;          // Número Mágico
input double   InpMaxLotSize = 10.0;           // Tamanho máximo do lote
input double   InpMinLotSize = 0.1;            // Tamanho mínimo do lote

input string group2 = "=== Configurações de Médias Móveis ===";
input ENUM_MA_METHOD InpMAMethod = MODE_SMA;   // Tipo de Média Móvel
input int      InpMAShortPeriod = 9;           // Período da MM Curta
input int      InpMAMediumPeriod = 17;         // Período da MM Média
input int      InpMALongPeriod = 100;          // Período da MM Longa

input string group3 = "=== Estratégia de Candles ===";
input bool     InpUseCandleStrategy = true;    // Usar estratégia de candles
input int      InpPeriodCandle = 2;            // Período para cálculo de volume

// Configurações dos padrões de candles (simplificado para exemplo)
input bool     PATTERN_MARUBOZU_GREEN_Enabled = true;
input bool     PATTERN_MARUBOZU_RED_Enabled = true;
input bool     PATTERN_HAMMER_GREEN_Enabled = true;
input bool     PATTERN_HAMMER_RED_Enabled = true;
input bool     PATTERN_SHOOTING_STAR_RED_Enabled = true;
input bool     PATTERN_SHOOTING_STAR_GREEN_Enabled = true;

//+------------------------------------------------------------------+
//| Variáveis globais                                               |
//+------------------------------------------------------------------+
CTrade trade;
CCandleStrategy *candleStrategy;

int shortMAHandle, mediumMAHandle, longMAHandle;
double shortMABuffer[], mediumMABuffer[], longMABuffer[];

//+------------------------------------------------------------------+
//| Função de inicialização do expert                               |
//+------------------------------------------------------------------+
int OnInit()
{
   // Configurar os padrões
   PatternConfig patterns[9];
   
   // Marubozu Verde
   patterns[PATTERN_MARUBOZU_GREEN].enabled = PATTERN_MARUBOZU_GREEN_Enabled;
   patterns[PATTERN_MARUBOZU_GREEN].variationHigh = 150;
   patterns[PATTERN_MARUBOZU_GREEN].lotSize = 1.0;
   patterns[PATTERN_MARUBOZU_GREEN].stopLoss = 50;
   patterns[PATTERN_MARUBOZU_GREEN].takeProfit = 100;
   
   // Marubozu Vermelho
   patterns[PATTERN_MARUBOZU_RED].enabled = PATTERN_MARUBOZU_RED_Enabled;
   patterns[PATTERN_MARUBOZU_RED].variationHigh = 150;
   patterns[PATTERN_MARUBOZU_RED].lotSize = 1.0;
   patterns[PATTERN_MARUBOZU_RED].stopLoss = 50;
   patterns[PATTERN_MARUBOZU_RED].takeProfit = 100;
   
   // Hammer Verde
   patterns[PATTERN_HAMMER_GREEN].enabled = PATTERN_HAMMER_GREEN_Enabled;
   patterns[PATTERN_HAMMER_GREEN].variationHigh = 150;
   patterns[PATTERN_HAMMER_GREEN].lotSize = 1.0;
   patterns[PATTERN_HAMMER_GREEN].stopLoss = 50;
   patterns[PATTERN_HAMMER_GREEN].takeProfit = 100;
   
   // Hammer Vermelho
   patterns[PATTERN_HAMMER_RED].enabled = PATTERN_HAMMER_RED_Enabled;
   patterns[PATTERN_HAMMER_RED].variationHigh = 150;
   patterns[PATTERN_HAMMER_RED].lotSize = 1.0;
   patterns[PATTERN_HAMMER_RED].stopLoss = 50;
   patterns[PATTERN_HAMMER_RED].takeProfit = 100;
   
   // Shooting Star Vermelho
   patterns[PATTERN_SHOOTING_STAR_RED].enabled = PATTERN_SHOOTING_STAR_RED_Enabled;
   patterns[PATTERN_SHOOTING_STAR_RED].variationHigh = 150;
   patterns[PATTERN_SHOOTING_STAR_RED].lotSize = 1.0;
   patterns[PATTERN_SHOOTING_STAR_RED].stopLoss = 50;
   patterns[PATTERN_SHOOTING_STAR_RED].takeProfit = 100;
   
   // Shooting Star Verde
   patterns[PATTERN_SHOOTING_STAR_GREEN].enabled = PATTERN_SHOOTING_STAR_GREEN_Enabled;
   patterns[PATTERN_SHOOTING_STAR_GREEN].variationHigh = 150;
   patterns[PATTERN_SHOOTING_STAR_GREEN].lotSize = 1.0;
   patterns[PATTERN_SHOOTING_STAR_GREEN].stopLoss = 50;
   patterns[PATTERN_SHOOTING_STAR_GREEN].takeProfit = 100;

   // Criar a estratégia de candles
   candleStrategy = new CCandleStrategy(_Symbol, _Period, InpMagicNumber, InpPeriodCandle, patterns);
   
   // Configurar o trade
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   // Criar handles para as médias móveis
   shortMAHandle = iMA(_Symbol, _Period, InpMAShortPeriod, 0, InpMAMethod, PRICE_CLOSE);
   mediumMAHandle = iMA(_Symbol, _Period, InpMAMediumPeriod, 0, InpMAMethod, PRICE_CLOSE);
   longMAHandle = iMA(_Symbol, _Period, InpMALongPeriod, 0, InpMAMethod, PRICE_CLOSE);
   
   if(shortMAHandle == INVALID_HANDLE || mediumMAHandle == INVALID_HANDLE || longMAHandle == INVALID_HANDLE) {
      Print("Erro ao criar indicadores de média móvel");
      return INIT_FAILED;
   }
   
   // Configurar buffers
   ArraySetAsSeries(shortMABuffer, true);
   ArraySetAsSeries(mediumMABuffer, true);
   ArraySetAsSeries(longMABuffer, true);
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Função de desinicialização do expert                            |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(CheckPointer(candleStrategy) == POINTER_DYNAMIC) {
      delete candleStrategy;
   }
   
   IndicatorRelease(shortMAHandle);
   IndicatorRelease(mediumMAHandle);
   IndicatorRelease(longMAHandle);
}

//+------------------------------------------------------------------+
//| Função de tick do expert                                        |
//+------------------------------------------------------------------+
void OnTick()
{
   // Verificar se é um novo candle
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(lastBarTime == currentBarTime) return;
   lastBarTime = currentBarTime;
   
   // Verificar se há posição aberta
   if(PositionSelect(_Symbol)) return;
   
   // Obter valores das médias móveis
   if(CopyBuffer(shortMAHandle, 0, 0, 1, shortMABuffer) <= 0 ||
      CopyBuffer(mediumMAHandle, 0, 0, 1, mediumMABuffer) <= 0 ||
      CopyBuffer(longMAHandle, 0, 0, 1, longMABuffer) <= 0) {
      Print("Erro ao copiar buffers das MAs");
      return;
   }
   
   double shortMA = shortMABuffer[0];
   double mediumMA = mediumMABuffer[0];
   double longMA = longMABuffer[0];
   
   // Determinar tendência
   bool isUptrend = (shortMA > mediumMA && mediumMA > longMA);
   bool isDowntrend = (shortMA < mediumMA && mediumMA < longMA);
   
   // Executar estratégia de candles se habilitada
   if(InpUseCandleStrategy)
   {
      if(isUptrend && candleStrategy.IsBuySignal(longMA)) {
         double lotSize = NormalizeDouble(candleStrategy.GetLotSize(), 2);
         lotSize = fmax(InpMinLotSize, fmin(lotSize, InpMaxLotSize));
         
         trade.Buy(
            lotSize,
            _Symbol,
            0, // price
            0, // stoploss
            candleStrategy.GetTakeProfit(),
            candleStrategy.GetComment()
         );
      }
      else if(isDowntrend && candleStrategy.IsSellSignal(longMA)) {
         double lotSize = NormalizeDouble(candleStrategy.GetLotSize(), 2);
         lotSize = fmax(InpMinLotSize, fmin(lotSize, InpMaxLotSize));
         
         trade.Sell(
            lotSize,
            _Symbol,
            0, // price
            0, // stoploss
            candleStrategy.GetTakeProfit(),
            candleStrategy.GetComment()
         );
      }
   }
}

//+------------------------------------------------------------------+
//| Função para calcular o lucro/perda em pontos                    |
//+------------------------------------------------------------------+
double CalculateProfitInPoints()
{
   if(!PositionSelect(_Symbol)) return 0;
   
   double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                        SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                        SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   return (currentPrice - entryPrice) / _Point * (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 1 : -1);
}