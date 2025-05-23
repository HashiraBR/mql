//+------------------------------------------------------------------+
//|                                                      SupRes.mq5  |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2
#property indicator_color1  clrGreen
#property indicator_color2  clrRed
#property indicator_width1  2
#property indicator_width2  2

input int lookbackPeriod = 50;  // Período de lookback para identificar máximos e mínimos
input double minDistance = 10.0; // Distância mínima entre os níveis (em pontos)

double SupportBuffer[];
double ResistanceBuffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, SupportBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ResistanceBuffer, INDICATOR_DATA);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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
   // Verifica se há candles suficientes para análise
   if (rates_total < lookbackPeriod)
      return 0; // Não há dados suficientes

   // Loop para calcular os níveis de suporte e resistência
   for(int i = prev_calculated; i < rates_total; i++)
     {
      // Verifica se o índice está dentro dos limites do array
      if (i < lookbackPeriod)
         continue; // Ignora os primeiros candles (não há dados suficientes para análise)

      // Identifica máximos e mínimos locais
      int maxIndex = i - lookbackPeriod + ArrayMaximum(high, i - lookbackPeriod, lookbackPeriod);
      int minIndex = i - lookbackPeriod + ArrayMinimum(low, i - lookbackPeriod, lookbackPeriod);

      double localMax = high[maxIndex];
      double localMin = low[minIndex];

      // Verifica se o nível já foi identificado anteriormente
      if (i > 0) // Garante que não estamos no primeiro candle
        {
         if (MathAbs(localMax - ResistanceBuffer[i-1]) > minDistance)
            ResistanceBuffer[i] = localMax;
         else
            ResistanceBuffer[i] = ResistanceBuffer[i-1];

         if (MathAbs(localMin - SupportBuffer[i-1]) > minDistance)
            SupportBuffer[i] = localMin;
         else
            SupportBuffer[i] = SupportBuffer[i-1];
        }
      else // Primeiro candle
        {
         ResistanceBuffer[i] = localMax;
         SupportBuffer[i] = localMin;
        }
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+