//+------------------------------------------------------------------+
//|                     SRLevelsUnified.mq5                          |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   0

input int MaxCandles = 500;         // Número máximo de candles analisados
input double SafeDistance = 50;     // Margem de tolerância (em pontos)
input bool UseMedian = false;        // Preferência: true para mediana, false para média

enum NUMBER_LEVEL {
   LOW,
   MEDIUM,
   HIGH
};

input NUMBER_LEVEL numberLevel = MEDIUM;

input color supportColor = clrRed;     // Cor para linhas de suporte
input color resistenceColor = clrGreen;   // Cor para linhas de resistência
input int lineLarge = 1;                // Espessura das linhas

// Buffer para armazenar os níveis de suporte/resistência
double ResSupBuffer[];
int MinDistance;

//+------------------------------------------------------------------+
//| Função de inicialização do indicador                              |
//+------------------------------------------------------------------+
int OnInit()
{

    IndicatorSetString(INDICATOR_SHORTNAME, "SupportResistence");

    SetIndexBuffer(0, ResSupBuffer, INDICATOR_DATA);
    
    double close = iClose(_Symbol, PERIOD_CURRENT, 0);
    
    if(numberLevel == LOW){
      MinDistance = close * 0.00079;
    }else if(numberLevel == MEDIUM){
      MinDistance = close * 0.001;
    }else if(numberLevel == HIGH){
      MinDistance = close * 0.0013;
    }
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Função de desinicialização do indicador                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    ObjectsDeleteAll(0, "SRLevel_");
}

//+------------------------------------------------------------------+
//| Função de iteração do indicador                                   |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    // Verificar se há candles suficientes para análise
    if (rates_total < MaxCandles)
        return(0);

    // Limpar o buffer
    ArrayInitialize(ResSupBuffer, 0);

    // Identificar os níveis de suporte/resistência
    IdentifyResSupLevels(high, low, rates_total, UseMedian);

    // Desenhar os níveis no gráfico
    DrawResSupLevels(close[rates_total - 1]);

    return(rates_total);
}

//+------------------------------------------------------------------+
//| Identificar níveis de suporte/resistência                        |
//+------------------------------------------------------------------+
void IdentifyResSupLevels(const double &high[], const double &low[], int rates_total, bool useMedian)
{
    double levels[];

    // Identificar topos e fundos
    for (int i = 1; i < rates_total - 1; i++)
    {
        if (high[i] > high[i - 1] && high[i] > high[i + 1])
        {
            if (!IsCloseLevel(high[i], levels, MinDistance))
            {
                ArrayResize(levels, ArraySize(levels) + 1);
                levels[ArraySize(levels) - 1] = high[i];
            }
        }

        if (low[i] < low[i - 1] && low[i] < low[i + 1])
        {
            if (!IsCloseLevel(low[i], levels, MinDistance))
            {
                ArrayResize(levels, ArraySize(levels) + 1);
                levels[ArraySize(levels) - 1] = low[i];
            }
        }
    }

    // Calcular os valores com base na preferência (média ou mediana)
    int buffer_index = 0;
    for (int i = 0; i < ArraySize(levels); i++)
    {
        double confirmations[];
        int count = 0;

        // Verificar confirmações para o nível atual
        for (int j = 0; j < rates_total; j++)
        {
            if (MathAbs(levels[i] - high[j]) <= SafeDistance * _Point ||
                MathAbs(levels[i] - low[j]) <= SafeDistance * _Point)
            {
                ArrayResize(confirmations, count + 1);
                confirmations[count++] = levels[i];
            }
        }

        //if (count >= MinConfirmations)
        //{
        double finalValue = 0;

        if (useMedian)
            finalValue = CalculateMedian(confirmations); // Usar mediana
        else
            finalValue = CalculateMean(confirmations);   // Usar média

        ResSupBuffer[buffer_index++] = finalValue;
        //}
    }
}

//+------------------------------------------------------------------+
//| Calcular a média de um array                                     |
//+------------------------------------------------------------------+
double CalculateMean(const double &values[])
{
    if (ArraySize(values) == 0)
        return 0;

    double sum = 0;
    for (int i = 0; i < ArraySize(values); i++)
    {
        sum += values[i];
    }

    return sum / ArraySize(values);
}

//+------------------------------------------------------------------+
//| Calcular a mediana de um array                                   |
//+------------------------------------------------------------------+
double CalculateMedian(double &values[])
{
    if (ArraySize(values) == 0)
        return 0;

    ArraySort(values); // Ordena os valores
    int size = ArraySize(values);

    // Se o número de elementos for ímpar, retorna o do meio
    if (size % 2 != 0)
        return values[size / 2];
    else // Se for par, retorna a média dos dois valores centrais
        return (values[size / 2 - 1] + values[size / 2]) / 2.0;
}

//+------------------------------------------------------------------+
//| Verificar níveis próximos                                        |
//+------------------------------------------------------------------+
bool IsCloseLevel(double level, const double &levels[], double min_distance)
{
    for (int i = 0; i < ArraySize(levels); i++)
    {
        if (MathAbs(level - levels[i]) <= min_distance * _Point)
            return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Desenhar os níveis de suporte/resistência no gráfico             |
//+------------------------------------------------------------------+
void DrawResSupLevels(double currentPrice)
{
    for (int i = 0; i < ArraySize(ResSupBuffer); i++)
    {
        if (ResSupBuffer[i] != 0)
        {
            string lineName = "SRLevel_" + IntegerToString(i);

            // Determinar a cor com base na posição do preço atual
            color lineColor = (ResSupBuffer[i] < currentPrice) ? supportColor : resistenceColor;

            // Desenhar o nível
            if (ObjectFind(0, lineName) < 0)
            {
                ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, ResSupBuffer[i]);
            }
            ObjectSetInteger(0, lineName, OBJPROP_COLOR, lineColor);   // Definir cor
            ObjectSetInteger(0, lineName, OBJPROP_WIDTH, lineLarge);  // Definir espessura
        }
    }
}
