//+------------------------------------------------------------------+
//| Inputs para controle de plotagem e operação                       |
//+------------------------------------------------------------------+


#include "../DefaultInputs.mqh"
#include "../DefaultFunctions.mqh"


input bool PlotVWAP = true;      // Ativar/desativar plotagem do VWAP
input bool PlotMA = true;        // Ativar/desativar plotagem da MA intraday
input int MAPeriod = 14;         // Período da MA intraday
input color VWAPColor = clrBlue; // Cor da linha do VWAP
input color MAColor = clrRed;    // Cor da linha da MA intraday
input ENUM_TIMEFRAMES InpTimeFrame = PERIOD_M1; // Tempo gráfico para MA e VWAP
input bool candleMode = false;   // Operar apenas na formação de Hammer ou Shooting Star?

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Inicialização do EA
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Remove todos os objetos gráficos ao finalizar o EA
    ObjectsDeleteAll(0, "VWAP_");
    ObjectsDeleteAll(0, "MA_");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    
    CheckStopsSkippedAndCloseTrade(InpMagicNumber);
   
    // Cancela ordens velhas
    CancelOldPendingOrders(InpMagicNumber, InpOrderExpiration);
    
    // Aplica Trailing Stop se estiver ativado
    if (InpTrailingStop) MonitorTrailingStop(InpMagicNumber, InpStopLoss);

    // Verifica a última negociação e envia e-mail se necessário
    CheckLastTradeAndSendEmail(InpMagicNumber);
    
    // Verifica se é um novo candle
    if (!isNewCandle()) return;
   
    // Verifica horário de funcionamento e fecha possições
    if (!CheckTradingTime(InpMagicNumber)) 
        return;
        
    if(HasOpenPosition(InpMagicNumber)) return;

    // Atualiza os valores do VWAP e da MA intraday
    double vwap = CalculateVWAP(InpTimeFrame); 
    double intradayMA = CalculateIntradayMA(MAPeriod, InpTimeFrame); 

    // Plota os valores no gráfico, se ativado
    if (PlotVWAP)
        PlotTrendLine("VWAP", vwap, VWAPColor);
    if (PlotMA)
        PlotTrendLine("MA", intradayMA, MAColor);

    // Verifica as condições de compra e venda
    CheckTradeConditions(vwap, intradayMA);
}

//+------------------------------------------------------------------+
//| Função para calcular o VWAP                                      |
//+------------------------------------------------------------------+
double CalculateVWAP(ENUM_TIMEFRAMES timeframe)
{
    double totalVolume = 0;
    double totalPriceVolume = 0;
    datetime endTime = iTime(NULL, timeframe, 0);
    datetime startTime = iTime(NULL, timeframe, iBars(NULL, timeframe) - 1);

    for(int i = 0; i < iBars(NULL, timeframe); i++)
    {
        if(iTime(NULL, timeframe, i) < startTime)
            break;

        double volume = (double)iVolume(NULL, timeframe, i);
        double typicalPrice = (iHigh(NULL, timeframe, i) + iLow(NULL, timeframe, i) + iClose(NULL, timeframe, i)) / 3;

        totalVolume += volume;
        totalPriceVolume += typicalPrice * volume;
    }

    if(totalVolume == 0)
        return 0;

    return totalPriceVolume / totalVolume;
}

//+------------------------------------------------------------------+
//| Função para calcular a MA intraday                                |
//+------------------------------------------------------------------+
double CalculateIntradayMA(int period, ENUM_TIMEFRAMES timeframe)
{
    double sum = 0;
    int count = 0;
    datetime endTime = iTime(NULL, timeframe, 0);
    datetime startTime = iTime(NULL, timeframe, iBars(NULL, timeframe) - 1);

    for(int i = 0; i < iBars(NULL, timeframe); i++)
    {
        if(iTime(NULL, timeframe, i) < startTime)
            break;

        sum += iClose(NULL, timeframe, i);
        count++;
    }

    if(count == 0)
        return 0;

    return sum / count;
}

//+------------------------------------------------------------------+
//| Função para plotar uma linha de tendência (OBJ_TREND)             |
//+------------------------------------------------------------------+
void PlotTrendLine(string prefix, double value, color clr)
{
    string objName = prefix + "_TrendLine";
    
    // Verifica se o objeto já existe
    if (ObjectFind(0, objName) < 0)
    {
        // Cria uma nova linha de tendência
        ObjectCreate(0, objName, OBJ_TREND, 0, 0, 0);
    }

    // Define as propriedades da linha de tendência
    ObjectSetDouble(0, objName, OBJPROP_PRICE, 0, value); // Preço inicial
    ObjectSetDouble(0, objName, OBJPROP_PRICE, 1, value); // Preço final
    ObjectSetInteger(0, objName, OBJPROP_TIME, 0, iTime(NULL, 0, 1)); // Tempo inicial (candle anterior)
    ObjectSetInteger(0, objName, OBJPROP_TIME, 1, iTime(NULL, 0, 0)); // Tempo final (candle atual)
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clr); // Cor da linha
    ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2); // Espessura da linha
    ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, true); // Estende a linha para a direita
}

//+------------------------------------------------------------------+
//| Função para verificar as condições de compra e venda              |
//+------------------------------------------------------------------+
void CheckTradeConditions(double vwap, double intradayMA)
{
    // Dados do candle anterior
    double prevLow = iLow(NULL, 0, 1);
    double prevHigh = iHigh(NULL, 0, 1);
    double prevClose = iClose(NULL, 0, 1);

    // Verifica se o preço veio de cima (MA)
    bool priceFromAbove = vwap < intradayMA;
    
    bool hammer = true, shootingStar = true;
    if(candleMode)
    {
      hammer = MathAbs(prevHigh - vwap) < MathAbs(vwap - prevLow);
      shootingStar = MathAbs(prevLow - vwap) < MathAbs(vwap - prevHigh);
    }

    // Condição de compra
    if (priceFromAbove && prevLow <= vwap && prevClose >= vwap && hammer)
    {
        if (IsTradeLogicValid(vwap, intradayMA))
        {
            ExecuteBuyOrder(InpMagicNumber, InpLotSize, InpStopLoss, InpTakeProfit, "Try fundo VWAP");
        }
    }
    // Condição de venda
    else if (!priceFromAbove && prevHigh >= vwap && prevClose <= vwap && shootingStar)
    {
        if (IsTradeLogicValid(vwap, intradayMA))
        {
            ExecuteSellOrder(InpMagicNumber, InpLotSize, InpStopLoss, InpTakeProfit, "Try topo VWAP");
        }
    }
}

//+------------------------------------------------------------------+
//| Função para verificar se a lógica de operação faz sentido         |
//+------------------------------------------------------------------+
bool IsTradeLogicValid(double vwap, double intradayMA)
{
    // Verifica se o VWAP e a MA estão bem definidos
    if (vwap == 0 || intradayMA == 0)
        return false;

    // Verifica se o preço está próximo o suficiente do VWAP
    double priceDistance = MathAbs(iClose(NULL, 0, 0) - vwap);
    if (priceDistance > 10 * _Point) // Ajuste o valor conforme necessário
        return false;

    return true;
}