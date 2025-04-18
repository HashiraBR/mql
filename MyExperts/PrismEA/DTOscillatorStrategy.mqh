//+------------------------------------------------------------------+
//| Estrutura para armazenar dados do DT                             |
//+------------------------------------------------------------------+
struct DT_DATA
{
    double dtosc;
    double dtoss;
};

//+------------------------------------------------------------------+
//| Função CheckForTradeDT atualizada                                |
//+------------------------------------------------------------------+
void CheckForTradeDT(bool upTrend, bool downTrend)
{

    //int magicNumber = (InpMagicNumber == 0 ? InpMagicNumberDT : InpMagicNumber);
    static DT_DATA dt1, dt2; // dt1 = atual, dt2 = anterior
    
    // 1. Atualiza os valores do DT Oscillator
    dt2 = dt1; // Armazena o valor anterior
    
    // Obtém o preço atual
    double lastClose = iClose(_Symbol, InpTimeframe, 1);
    
    // Calcula os novos valores do DT Oscillator
    double rsiValue = CalculateRSI(lastClose, InpRsiPeriod); // RsiPeriod = 13
    double stochRsi = CalculateStochasticRSI(rsiValue, InpStochPeriod); // StochPeriod = 8
    CalculateDTOscillator(dt1.dtosc, dt1.dtoss, stochRsi, InpSlowingPeriod, InpSignalPeriod); // Slowing=5, Signal=3
    
    // 3. Verifica condições para compra
    bool crossUp = dt2.dtosc < dt2.dtoss && dt1.dtosc > dt1.dtoss && MathAbs(dt1.dtosc - dt1.dtoss) >= InpDisDT;
    bool below30 = dt1.dtosc < 30 && dt1.dtoss < 30;
    bool priceAboveEMA = lastClose > emaShort;

    // 4. Verifica condições para venda
    bool crossDown = dt2.dtosc > dt2.dtoss && dt1.dtosc < dt1.dtoss && MathAbs(dt1.dtosc - dt1.dtoss) >= InpDisDT;
    bool above70 = dt1.dtosc > 70 && dt1.dtoss > 70;
    bool priceBelowEMA = lastClose < emaShort;
    
    double sl = InpStopLoss;
    if(InpStopLossFromSmootedATR)
      sl = GetDefaultSmoothedATR() * InpAtrMultiplier;
    
    // 5. Calcula Take Profit
    double tp = InpTakeProfit;
    if(InpTPType == RISK_REWARD) {
        tp = sl * InpTPRiskReward;
        // Print("Take Profit calculado (Risk/Reward): ", tp, " (SL: ", InpStopLoss, " RR: ", InpTPRiskReward, ")");
    } 

    sl = Rounder(sl);
    tp = Rounder(tp);
    
    Print("dtosc: ", dt1.dtosc, " dtoss: ", dt1.dtoss);
    Print("crossDown: ", crossDown, " above70: ", above70, " priceBelowEMA: ", priceBelowEMA, " downTrend: ", downTrend);
    Print("crossUp: ", crossUp, " below30: ", below30, " priceAboveEMA: ", priceAboveEMA, " upTrend: ", upTrend);


    // 6. Executa as ordens conforme condições
    if(crossUp && below30 && priceAboveEMA && upTrend && IsBullishSignal())
    {
        // Print("*** ENTRADA DE COMPRA DETECTADA ***");
        BuyMarketPoint(InpMagicNumber, InpLotSize, sl, tp, "DT+Candles de Alta");
    }
    else if(crossDown && above70 && priceBelowEMA && downTrend && IsBearishSignal())
    {
        // Print("*** ENTRADA DE VENDA DETECTADA ***");
        SellMarketPoint(InpMagicNumber, InpLotSize, sl, tp, "DT+Candles de Baixa");
    }
}

//+------------------------------------------------------------------+
//| Funções do DT Oscillator para EA                                 |
//+------------------------------------------------------------------+

// Estrutura para armazenar dados do RSI
struct RSI_DATA
{
    double chgAvg;
    double totChg;
    double lastPrice;
};

// Variáveis globais para o cálculo
RSI_DATA rsiData;
double stochBuffer[];
double dtoscBuffer[];
double dtossBuffer[];

//+------------------------------------------------------------------+
//| Inicialização do DT Oscillator                                   |
//+------------------------------------------------------------------+
void InitDTOscillator(int stochPeriod, int slowingPeriod, int signalPeriod)
{
    ArrayResize(stochBuffer, stochPeriod);
    ArrayResize(dtoscBuffer, slowingPeriod);
    ArrayResize(dtossBuffer, signalPeriod);
    
    // Inicializa buffers
    ArrayInitialize(stochBuffer, 0);
    ArrayInitialize(dtoscBuffer, 0);
    ArrayInitialize(dtossBuffer, 0);
    
    // Inicializa dados do RSI
    rsiData.chgAvg = 0;
    rsiData.totChg = 0;
}

//+------------------------------------------------------------------+
//| Cálculo do RSI personalizado                                     |
//+------------------------------------------------------------------+
double CalculateRSI(double price, double period)
{
    if(rsiData.lastPrice == 0)
    {
        rsiData.lastPrice = price;
        return 50;
    }
    
    double sf = 1.0 / period;
    double change = price - rsiData.lastPrice;
    
    rsiData.chgAvg = rsiData.chgAvg + sf * (change - rsiData.chgAvg);
    rsiData.totChg = rsiData.totChg + sf * (MathAbs(change) - rsiData.totChg);
    
    rsiData.lastPrice = price;
    
    double changeRatio = (rsiData.totChg != 0) ? rsiData.chgAvg / rsiData.totChg : 0;
    return 50.0 * (changeRatio + 1.0);
}

//+------------------------------------------------------------------+
//| Cálculo do Stochastic do RSI                                     |
//+------------------------------------------------------------------+
double CalculateStochasticRSI(double rsiValue, int stochPeriod)
{
    // Desloca o buffer e adiciona novo valor
    for(int i = stochPeriod-1; i > 0; i--)
        stochBuffer[i] = stochBuffer[i-1];
    stochBuffer[0] = rsiValue;
    
    // Encontra mínimo e máximo
    double min = rsiValue;
    double max = rsiValue;
    for(int i = 0; i < stochPeriod; i++)
    {
        min = MathMin(stochBuffer[i], min);
        max = MathMax(stochBuffer[i], max);
    }
    
    return (max != min) ? 100 * (rsiValue - min) / (max - min) : 0;
}

//+------------------------------------------------------------------+
//| Cálculo do DT Oscillator                                         |
//+------------------------------------------------------------------+
void CalculateDTOscillator(double &dtosc, double &dtoss, double stochValue, int slowingPeriod, int signalPeriod)
{
    // Cálculo da linha principal (dtosc)
    for(int i = slowingPeriod-1; i > 0; i--)
        dtoscBuffer[i] = dtoscBuffer[i-1];
    dtoscBuffer[0] = stochValue;
    
    double sum = 0;
    for(int i = 0; i < slowingPeriod; i++)
        sum += dtoscBuffer[i];
    dtosc = sum / slowingPeriod;
    
    // Cálculo da linha de sinal (dtoss)
    for(int i = signalPeriod-1; i > 0; i--)
        dtossBuffer[i] = dtossBuffer[i-1];
    dtossBuffer[0] = dtosc;
    
    sum = 0;
    for(int i = 0; i < signalPeriod; i++)
        sum += dtossBuffer[i];
    dtoss = sum / signalPeriod;
}