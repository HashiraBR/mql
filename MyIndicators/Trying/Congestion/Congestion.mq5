//+------------------------------------------------------------------+
//| CongestionZoneIndicator.mq5                                      |
//| Identifica congestionamento e desenha suporte/resistência       |
//+------------------------------------------------------------------+
#property copyright "Seu Nome"
#property version   "1.00"
#property indicator_buffers 2
#property indicator_plots   2
#property indicator_color1  clrBlue
#property indicator_color2  clrRed
#property indicator_width1  2
#property indicator_width2  2

// Inputs do usuário
input int      BollingerPeriod = 20;       // Período das Bandas de Bollinger
input double   InpDesviation = 2.0;        // Desvio padrão para Bollinger
input int      StdDevPeriod = 50;          // Período para calcular o desvio padrão da largura
input double   StdDevFactor = 1.0;         // Fator do desvio padrão para identificar congestionamento
input color    SupportColor = clrGreen;    // Cor da linha de suporte
input color    ResistanceColor = clrRed;   // Cor da linha de resistência
input int      LineWidth = 2;              // Espessura das linhas

// Buffers para desenhar as linhas de suporte e resistência
double SupportBuffer[];
double ResistanceBuffer[];

// Handle para o indicador Bandas de Bollinger
int bollingerHandle;

double upperBand[];
double lowerBand[];

//+------------------------------------------------------------------+
//| Inicialização do indicador                                      |
//+------------------------------------------------------------------+
int OnInit()
{
    SetIndexBuffer(0, SupportBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, ResistanceBuffer, INDICATOR_DATA);
    
    PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, SupportColor);
    PlotIndexSetInteger(1, PLOT_LINE_COLOR, 0, ResistanceColor);
    PlotIndexSetInteger(0, PLOT_LINE_WIDTH, 0, LineWidth);
    PlotIndexSetInteger(1, PLOT_LINE_WIDTH, 0, LineWidth);
    
    PlotIndexSetString(0, PLOT_LABEL, "Suporte");
    PlotIndexSetString(1, PLOT_LABEL, "Resistência");
    
    bollingerHandle = iBands(_Symbol, 0, BollingerPeriod, 0, InpDesviation, PRICE_CLOSE);
    if (bollingerHandle == INVALID_HANDLE)
    {
        Print("Erro ao criar handle para Bandas de Bollinger");
        return INIT_FAILED;
    }
    
    ArraySetAsSeries(upperBand, true);
    ArraySetAsSeries(lowerBand, true);
    ArraySetAsSeries(SupportBuffer, true);
    ArraySetAsSeries(ResistanceBuffer, true);
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Cálculo do indicador                                           |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[],
                const double &high[], const double &low[],
                const double &close[], const long &tick_volume[],
                const long &volume[], const int &spread[])
{
    if (bollingerHandle == INVALID_HANDLE) return 0;
    
    if (CopyBuffer(bollingerHandle, 0, 0, rates_total, upperBand) <= 0 ||
        CopyBuffer(bollingerHandle, 2, 0, rates_total, lowerBand) <= 0)
    {
        Print("Erro ao copiar buffers das Bandas de Bollinger");
        return 0;
    }
    
    ArrayInitialize(SupportBuffer, 0);
    ArrayInitialize(ResistanceBuffer, 0);
    
    for (int i = prev_calculated; i < rates_total; i++)
    {
        double currentWidth = upperBand[i] - lowerBand[i];
        double maWidth = 0, stdDevWidth = 0;
        int count = 0;
        
        for (int j = 0; j < StdDevPeriod; j++)
        {
            int index = i - j;
            if (index < 0) break;
            
            double width = upperBand[index] - lowerBand[index];
            maWidth += width;
            stdDevWidth += width * width;
            count++;
        }
        
        if (count > 0)
        {
            maWidth /= count;
            stdDevWidth = MathSqrt((stdDevWidth / count) - (maWidth * maWidth));
        }
        
        if (currentWidth < maWidth - (StdDevFactor * stdDevWidth))
        {
            SupportBuffer[i] = lowerBand[i];
            ResistanceBuffer[i] = upperBand[i];
        }
        else
        {
            SupportBuffer[i] = (i > 0) ? SupportBuffer[i - 1] : 0;
            ResistanceBuffer[i] = (i > 0) ? ResistanceBuffer[i - 1] : 0;
        }
    }
    
    return rates_total;
}

//+------------------------------------------------------------------+
//| Finalização do indicador                                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if (bollingerHandle != INVALID_HANDLE)
    {
        IndicatorRelease(bollingerHandle);
    }
}
