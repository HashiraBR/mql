//+------------------------------------------------------------------+
//|                                                  PivotMaster.mq5 |
//|                                                    Danne Pereira |
//|                                             https://www.aipi.com |
//+------------------------------------------------------------------+


#include "../DefaultInputs.mqh"
#include "../DefaultFunctions.mqh"



// Inputs
input string space1 = "#### Operacional ####"; //#### Operacional ####
input int InpMAPeriodShort = 10;       // Período da primeira média móvel
input int InpMAPeriodMedium = 20;       // Período da segunda média móvel
input int InpMAPeriodLong = 50;       // Período da terceira média móvel
input double InpMinDistanceShortLong = 0.01; // Distância mínima entre MA curta e longa (%)
input double InpMinDistanceMediumLong = 0.01; // Distância mínima entre MA média e longa (%)
input double InpMinDistanceShortMedium = 0.01; // Distância mínima entre MA curta e média (%)
input int CandlesLookback = 5;  // Quantidade de velas para verificar o topo/fundo anterior

// Buffers para suporte/resistência
double gSrLevels[];                     // Array para armazenar os níveis de suporte/resistência
int gTouchLevels[];                     // Array para contar quantas vezes o preço tocou em cada nível
double gMinDistance;                    // Distância mínima entre os níveis
int gShortMAHandle, gMediumMAHandle, gLongMAHandle; // Handles das MAs
double minDistanceShortLong, minDistanceMediumLong, minDistanceShortMedium; // Distâncias mínimas entre as MAs

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {

   
    // Inicializar os arrays
    ArrayResize(gSrLevels, InpQtLevels);
    ArrayResize(gTouchLevels, InpQtLevels);
    ArrayInitialize(gTouchLevels, 0);
    

    // Calcular a distância mínima entre os níveis
    double close = iClose(_Symbol, InpTimeframe, 0);
    if (InpNumberLevel == LOW) gMinDistance = close * 0.0008;
    else if (InpNumberLevel == MEDIUM) gMinDistance = close * 0.001;
    else if (InpNumberLevel == HIGH) gMinDistance = close * 0.0013;
    
    gShortMAHandle = iMA(_Symbol, InpTimeframe, InpMAPeriodShort, 0, MODE_SMA, PRICE_CLOSE);
    gMediumMAHandle = iMA(_Symbol, InpTimeframe, InpMAPeriodMedium, 0, MODE_SMA, PRICE_CLOSE);
    gLongMAHandle = iMA(_Symbol, InpTimeframe, InpMAPeriodLong, 0, MODE_SMA, PRICE_CLOSE); 

   if (gShortMAHandle == INVALID_HANDLE || gMediumMAHandle == INVALID_HANDLE || gLongMAHandle == INVALID_HANDLE)
   {
       Print("Erro ao criar os handles das MAs");
       return(INIT_FAILED);
   }     

   // Pré-calcula as distâncias mínimas
   minDistanceShortLong = InpMinDistanceShortLong / 100.0;
   minDistanceMediumLong = InpMinDistanceMediumLong / 100.0;
   minDistanceShortMedium = InpMinDistanceShortMedium / 100.0;
    
    
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
    // Verifica e fecha trades com stops ignorados
    CheckStopsSkippedAndCloseTrade(InpMagicNumber);

    // Cancela ordens pendentes antigas
    CancelOldPendingOrders(InpMagicNumber, InpOrderExpiration);

    // Aplica trailing stop se estiver ativado
    if (InpTrailingStop) MonitorTrailingStop(InpMagicNumber, gStopLoss);

    // Verifica a última negociação e envia e-mail se necessário
    CheckLastTradeAndSendEmail(InpMagicNumber);

    // Verifica se é um novo candle
    if (!isNewCandle()) return;

    // Verificar se há candles suficientes
    if (Bars(NULL, 0) < InpMaxCandles)
        return;

    // Identificar os níveis de suporte/resistência
    if (InpUseSupportResistance)
    {
        IdentifyResSupLevels();
        DrawSupportResistanceLevels();
    }

    // Verifica o horário de funcionamento e fecha posições se necessário
    if (!CheckTradingTime(InpMagicNumber)) return;

    // Verifica se já existe uma posição aberta pelo bot
    if (HasOpenPosition(InpMagicNumber)) return;

    // Verificar padrões de candlestick e níveis de suporte/resistência
    CheckForTrades();
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Função para verificar tendência das médias móveis                |
//+------------------------------------------------------------------+
bool CheckTrend()
{
    double ma1 = iMA(NULL, 0, MAPeriod1, 0, MODE_SMA, PRICE_CLOSE, 0);
    double ma2 = iMA(NULL, 0, MAPeriod2, 0, MODE_SMA, PRICE_CLOSE, 0);
    double ma3 = iMA(NULL, 0, MAPeriod3, 0, MODE_SMA, PRICE_CLOSE, 0);

    // Verifica se as médias estão em tendência de alta (MA1 > MA2 > MA3)
    if (ma1 > ma2 && ma2 > ma3)
        return true; // Tendência de alta

    // Verifica se as médias estão em tendência de baixa (MA1 < MA2 < MA3)
    if (ma1 < ma2 && ma2 < ma3)
        return false; // Tendência de baixa

    return false; // Sem tendência clara
}

//+------------------------------------------------------------------+
//| Função para verificar se há um pullback e gerar sinal de compra  |
//+------------------------------------------------------------------+
bool CheckForBuySignal()
{
    // Verifica se o preço tocou um nível de suporte
    for (int i = 0; i < ArraySize(srLevels) - 1; i++)
    {
        if (Bid <= srLevels[i] + 10 * Point && Bid >= srLevels[i] - 10 * Point) // Margem de 10 pips
        {
            // Verifica se o topo anterior tocou o próximo nível de resistência
            double previousHigh = iHigh(NULL, 0, iHighest(NULL, 0, MODE_HIGH, CandlesLookback, 1));
            if (previousHigh <= srLevels[i + 1] + 10 * Point && previousHigh >= srLevels[i + 1] - 10 * Point)
            {
                return true; // Sinal de compra
            }
        }
    }
    return false; // Sem sinal de compra
}

//+------------------------------------------------------------------+
//| Função para verificar se há um pullback e gerar sinal de venda   |
//+------------------------------------------------------------------+
bool CheckForSellSignal()
{
    // Verifica se o preço tocou um nível de resistência
    for (int i = 0; i < ArraySize(srLevels) - 1; i++)
    {
        if (Ask <= srLevels[i] + 10 * Point && Ask >= srLevels[i] - 10 * Point) // Margem de 10 pips
        {
            // Verifica se o fundo anterior tocou o próximo nível de suporte
            double previousLow = iLow(NULL, 0, iLowest(NULL, 0, MODE_LOW, CandlesLookback, 1));
            if (previousLow <= srLevels[i + 1] + 10 * Point && previousLow >= srLevels[i + 1] - 10 * Point)
            {
                return true; // Sinal de venda
            }
        }
    }
    return false; // Sem sinal de venda
}

//+------------------------------------------------------------------+
//| Função principal para verificar condições de trade               |
//+------------------------------------------------------------------+
void CheckForTrade()
{
    // Verifica a tendência
    bool isUptrend = CheckTrend();

    if (isUptrend)
    {
        // Verifica sinal de compra
        if (CheckForBuySignal())
        {
            // Executa a ordem de compra
            int ticket = OrderSend(Symbol(), OP_BUY, LotSize, Ask, 3, 0, 0, "Compra por tendência", 0, 0, Blue);
            if (ticket < 0)
                Print("Erro ao abrir ordem de compra: ", GetLastError());
        }
    }
    else
    {
        // Verifica sinal de venda
        if (CheckForSellSignal())
        {
            // Executa a ordem de venda
            int ticket = OrderSend(Symbol(), OP_SELL, LotSize, Bid, 3, 0, 0, "Venda por tendência", 0, 0, Red);
            if (ticket < 0)
                Print("Erro ao abrir ordem de venda: ", GetLastError());
        }
    }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Inicialização do indicador ou buffers
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Limpeza (se necessário)
}
