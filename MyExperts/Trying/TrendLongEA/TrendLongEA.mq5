//+------------------------------------------------------------------+
//| Expert Advisor baseado em EMAs e padrões de reversão             |
//+------------------------------------------------------------------+

// Configuração das médias móveis
input int emaFastPeriod = 20;  // EMA Curta (20 períodos)
input int emaSlowPeriod = 200; // EMA Longa (200 períodos)
input int InpQtdCandlesToAvgVolume = 2; // Usar filtro de volume

#include "../DefaultInputs.mqh"
#include "../DefaultFunctions.mqh"

enum opType {
   OP_SELL,
   OP_BUY
};

int emaFastHandle, emaSlowHandle; // Handles para as EMAs
double emaFastBuffer[], emaSlowBuffer[]; // Buffers para armazenar os valores das EMAs
double emaFast, emaSlow, emaPreviousSlow, emaPreviousFast;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    // Inicializa as EMAs
    if (!InitializeEMAs()) {
        return INIT_FAILED;
    }
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Função para inicializar as EMAs                                  |
//+------------------------------------------------------------------+
bool InitializeEMAs() {
    // Obtém os handles para as EMAs
    emaFastHandle = iMA(_Symbol, InpTimeframe, emaFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
    emaSlowHandle = iMA(_Symbol, InpTimeframe, emaSlowPeriod, 0, MODE_EMA, PRICE_CLOSE);

    // Verifica se os handles foram criados corretamente
    if (emaFastHandle == INVALID_HANDLE || emaSlowHandle == INVALID_HANDLE) {
        Print(expertName+"Erro ao criar handles para as EMAs.");
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Função para calcular as médias móveis                           |
//+------------------------------------------------------------------+
void CalculateEMAs() {
    // Copia os valores das EMAs para os buffers
    if (CopyBuffer(emaFastHandle, 0, 0, 3, emaFastBuffer) <= 0) {
        Print("Erro ao copiar dados da EMA rápida.");
        return;
    }
    if (CopyBuffer(emaSlowHandle, 0, 0, 3, emaSlowBuffer) <= 0) {
        Print("Erro ao copiar dados da EMA lenta.");
        return;
    }

    // Atribui os valores aos buffers
    emaFast = emaFastBuffer[0];
    emaSlow = emaSlowBuffer[0];
    
    emaPreviousFast = emaFastBuffer[2];
    emaPreviousSlow = emaSlowBuffer[2]; 
}

//+------------------------------------------------------------------+
//| Função principal OnTick()                                       |
//+------------------------------------------------------------------+
void OnTick() {

    CheckStopsSkippedAndCloseTrade(InpMagicNumber);
   
    // Cancela ordens velhas
    CancelOldPendingOrders(InpMagicNumber, InpOrderExpiration);
    
    // Aplica Trailing Stop se estiver ativado
    if (InpTrailingStop) MonitorTrailingStop(InpMagicNumber, InpStopLoss);

    // Verifica a última negociação e envia e-mail se necessário
    CheckLastTradeAndSendEmail(InpMagicNumber);
    
    // Verifica se é um novo candle
    if (!isNewCandle()) return;
    
    CalculateEMAs();
   
    if(HasOpenPosition(InpMagicNumber))
    {
      CheckExit();
      return;
    }
        
    // Verifica horário de funcionamento e fecha possições
    if (!CheckTradingTime(InpMagicNumber)) 
        return;

    // Verifica as condições de entrada
    CheckEntries();
}

//+------------------------------------------------------------------+
//| Verifica padrões de reversão                                    |
//+------------------------------------------------------------------+
bool IsReversalCandle(opType type) {
    double open = iOpen(_Symbol, InpTimeframe, 1);
    double close = iClose(_Symbol, InpTimeframe, 1);
    double high = iHigh(_Symbol, InpTimeframe, 1);
    double low = iLow(_Symbol, InpTimeframe, 1);
    double bodySize = MathAbs(close - open);
    double totalRange = high - low;

    // Padrão de reversão de alta (martelo, engolfo de alta, pin bar)
    if (type == OP_BUY) {
        //bool hammer = (close > open) && (close - open) < (high - low) * 0.3 && (close > (high + low) / 2);
        bool hammer = ((close > open) && (totalRange > (2 * bodySize)) && ((high - close) <= 10 * _Point) );
        bool engulfing = (close > open) && (close > iOpen(_Symbol, InpTimeframe, 2)) && (open < iClose(_Symbol, InpTimeframe, 2));
        bool pinBar = (close > open) && (high - close) > (close - open) * 2;
        return hammer || engulfing || pinBar;
    }

    // Padrão de reversão de baixa (estrela cadente, engolfo de baixa, pin bar invertido)
    if (type == OP_SELL) {
        //bool shootingStar = (close < open) && (open - close) < (high - low) * 0.3 && (close < (high + low) / 2);
        bool shootingStar = ((close < open) && (totalRange > (2 * bodySize)) && ((close - low) <= 10 * _Point));
        bool engulfing = (close < open) && (close < iOpen(_Symbol, InpTimeframe, 2)) && (open > iClose(_Symbol, InpTimeframe, 2));
        bool pinBar = (close < open) && (close - low) > (open - close) * 2;
        return shootingStar || engulfing || pinBar;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Verifica condições de entrada                                    |
//+------------------------------------------------------------------+
void CheckEntries() {
    // Obtém os preços dos candles
    double lastHigh = iHigh(_Symbol, InpTimeframe, 1);
    double lastLow = iLow(_Symbol, InpTimeframe, 1);
    double lastClose = iClose(_Symbol, InpTimeframe, 1);
    //double closePrice = iClose(_Symbol, InpTimeframe, 0);

    bool isHighVolume = IsVolumeAboveAverage();
   
    // Verifica a inclinação das EMAs
    bool isUpFast = emaFast > emaPreviousFast * 1.01 / 100 * _Point;
    bool isUpSlow = emaSlow > emaPreviousSlow * 1.01 / 100 * _Point;
    bool isDownFast = emaFast < emaPreviousFast * 1.01 / 100 * _Point;
    bool isDownSlow = emaSlow < emaPreviousSlow * 1.01 / 100 * _Point;

    // --- COMPRA ---
    if (isHighVolume && emaFast > emaSlow && lastClose > emaFast && lastLow < emaFast && IsReversalCandle(OP_BUY)) {
        // Verifica se ambas as EMAs estão inclinadas para cima
        if (isUpFast && isUpSlow) {
            ExecuteBuyOrder(InpMagicNumber, InpLotSize, lastLow, InpTakeProfit, "Sinal de reversão para ALTA");
        }
    }

    // --- VENDA ---
    if (isHighVolume && emaFast < emaSlow && lastClose < emaFast && lastHigh > emaFast && IsReversalCandle(OP_SELL)) {
        // Verifica se ambas as EMAs estão inclinadas para baixo
        if (isDownFast && isDownSlow) {
            ExecuteSellOrder(InpMagicNumber, InpLotSize, lastHigh, InpTakeProfit, "Sinal de reversão para BAIXA");
        }
    }
}

bool IsVolumeAboveAverage() {
    // Verifica se x é válido
    if (InpQtdCandlesToAvgVolume <= 0) {
        Print("Erro: O valor de x deve ser maior que 0.");
        return false;
    }

    // Calcula a soma dos volumes dos últimos x candles antes do candle de análise (Candle[1])
    double sumVolumes = 0;
    for (int i = 1; i <= InpQtdCandlesToAvgVolume; i++) {
        sumVolumes += (double)iVolume(_Symbol, InpTimeframe, i + 1); // i + 1 porque Candle[1] é o candle de análise
    }

    // Calcula a média dos volumes
    double averageVolume = sumVolumes / InpQtdCandlesToAvgVolume;

    // Obtém o volume do candle de análise (Candle[1])
    double analysisVolume = (double)iVolume(_Symbol, InpTimeframe, 1);

    // Retorna true se o volume do candle de análise for maior que a média
    return analysisVolume > averageVolume;
}

//+------------------------------------------------------------------+
//| Verifica se as EMAs se cruzaram e fecha a posição se necessário   |
//+------------------------------------------------------------------+
void CheckExit() {
     // Obtém a direção da posição atual
     ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

     // Verifica o cruzamento das EMAs
     if (positionType == POSITION_TYPE_BUY && emaFast < emaSlow) {
         // Fecha a posição de compra
         ClosePositionWithMagicNumber(InpMagicNumber);
     }
     else if (positionType == POSITION_TYPE_SELL && emaFast > emaSlow) {
         // Fecha a posição de venda
         ClosePositionWithMagicNumber(InpMagicNumber);
     }
}