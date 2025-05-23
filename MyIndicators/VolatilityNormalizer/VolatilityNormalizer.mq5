//+------------------------------------------------------------------+
//| Volatility Indicator with Smoothed Lines                        |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
#property version   "1.00"
#property description "Indicador de Volatilidade com Linhas Suavizadas"
#property description "Bandas deslocadas com opções de suavização configuráveis"

#property indicator_separate_window
#property indicator_minimum 0
#property indicator_maximum 120
#property indicator_buffers 8  // Aumentado para buffers de suavização
#property indicator_plots   3

//--- Plot 1: Volatilidade Normalizada (Main)
#property indicator_label1  "Main"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRoyalBlue
#property indicator_width1  2

//--- Plot 2: Banda Superior Deslocada
#property indicator_label2  "HighLimit"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_DOT
#property indicator_width2  2

//--- Plot 3: Banda Inferior Deslocada
#property indicator_label3  "LowLimit"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrOrange
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

#property tester_indicator "VolatilityNormalizer.ex5"

//--- Parâmetros de entrada
input int InpDiffPeriod = 14;          // Período para cálculo do desvio padrão inicial
input int NormalizationWindow = 21;   // Janela para normalização
input int StdBandPeriod = 11;           // Período para cálculo do STD das bandas

//--- Parâmetros de suavização
input int    MainSmoothingPeriod = 0;  // Suavização da linha principal (0 = desligado)
input int    BandSmoothingPeriod = 0;  // Suavização das bandas (0 = desligado)
input ENUM_MA_METHOD SmoothingMethod = MODE_EMA; // Método de suavização

//--- Buffers do indicador
double mainBuffer[];                  // Linha principal (volatilidade normalizada)
double upperBandBuffer[];             // Banda superior deslocada
double lowerBandBuffer[];             // Banda inferior deslocada
double diffStdBuffer[];               // Buffer para cálculos do STD inicial
double tempStdBuffer[];               // Buffer temporário para cálculo do STD das bandas
double mainBufferRaw[];               // Buffer não suavizado (cálculos)
double upperBandBufferRaw[];          // Banda superior não suavizada
double lowerBandBufferRaw[];          // Banda inferior não suavizada

//+------------------------------------------------------------------+
//| Função de inicialização do indicador                            |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Definir buffers
   SetIndexBuffer(0, mainBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, upperBandBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, lowerBandBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, diffStdBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, tempStdBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, mainBufferRaw, INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, upperBandBufferRaw, INDICATOR_CALCULATIONS);
   SetIndexBuffer(7, lowerBandBufferRaw, INDICATOR_CALCULATIONS);
   
   //--- Definir deslocamento das bandas (1 candle para trás)
   PlotIndexSetInteger(1, PLOT_SHIFT, 1);
   PlotIndexSetInteger(2, PLOT_SHIFT, 1);
   
   //--- Definir precisão de exibição
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   
   //--- Nome curto do indicador
   IndicatorSetString(INDICATOR_SHORTNAME, "VolLagBands_Smoothed("+string(InpDiffPeriod)+")");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Aplica suavização a um buffer                                   |
//+------------------------------------------------------------------+
void SmoothBuffer(const double &source[], double &dest[], int period, int rates_total, int type)
{
   if(period <= 1) // Sem suavização
   {
      ArrayCopy(dest, source);
      return;
   }
   
   for(int i = 0; i < rates_total; i++)
   {
      if(i == 0)
      {
         dest[i] = source[i];
         continue;
      }
      
      double sum = 0;
      int count = 0;
      
      for(int j = 0; j < period; j++)
      {
         if(i - j >= 0)
         {
            sum += source[i - j];
            count++;
         }
      }
      
      if(type == MODE_SMA)
      {
         dest[i] = sum / count;
      }
      else if(type == MODE_EMA)
      {
         if(i == 0)
            dest[i] = source[i];
         else
            dest[i] = source[i] * (2.0/(period+1)) + dest[i-1] * (1 - 2.0/(period+1));
      }
      else if(type == MODE_SMMA)
      {
         if(i == 0)
            dest[i] = source[i];
         else if(i < period)
            dest[i] = (sum + dest[i-1] * (period - count)) / period;
         else
            dest[i] = (dest[i-1] * (period - 1) + source[i]) / period;
      }
   }
}

//+------------------------------------------------------------------+
//| Função de cálculo do desvio padrão                              |
//+------------------------------------------------------------------+
double CalculateStdDev(const double &array[], int count, int shift)
{
   if(count <= 1) return 0.0;
   
   double sum = 0.0, sumSq = 0.0;
   for(int i = 0; i < count; i++)
   {
      if(shift + i >= ArraySize(array)) break;
      sum += array[shift + i];
      sumSq += array[shift + i] * array[shift + i];
   }
   
   double variance = (sumSq - sum * sum / count) / (count - 1);
   return MathSqrt(variance);
}

//+------------------------------------------------------------------+
//| Função de cálculo do indicador                                  |
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
   //--- Verificar se há barras suficientes
   if(rates_total < InpDiffPeriod + NormalizationWindow + StdBandPeriod) return 0;
   
   int start;
   if(prev_calculated == 0)
   {
      //--- Primeira execução - calcular todas as barras
      start = InpDiffPeriod;
      ArrayInitialize(mainBufferRaw, 0.0);
      ArrayInitialize(upperBandBufferRaw, 0.0);
      ArrayInitialize(lowerBandBufferRaw, 0.0);
   }
   else
   {
      //--- Execuções subsequentes - calcular apenas a última barra
      start = prev_calculated - 1;
   }

   //--- 1. Calcular STD inicial para todas as barras necessárias
   for(int i = start; i < rates_total; i++)
   {
      diffStdBuffer[i] = CalculateStdDev(close, InpDiffPeriod, i - InpDiffPeriod);
   }

   //--- 2. Normalizar com base nos últimos 200 períodos
   for(int i = start; i < rates_total; i++)
   {
      //--- Encontrar máximo na janela de normalização
      int windowStart = MathMax(i - NormalizationWindow + 1, InpDiffPeriod);
      double maxInWindow = 0.0;
      
      for(int j = windowStart; j <= i; j++)
      {
         if(diffStdBuffer[j] > maxInWindow)
            maxInWindow = diffStdBuffer[j];
      }
      
      //--- Normalizar para 0-100
      if(maxInWindow > 0)
         mainBufferRaw[i] = (diffStdBuffer[i] / maxInWindow) * 100;
      else
         mainBufferRaw[i] = 0;
   }

   //--- 3. Calcular STD da volatilidade normalizada (5 períodos)
   for(int i = start; i < rates_total; i++)
   {
      if(i >= InpDiffPeriod + StdBandPeriod)
      {
         // Calcular STD com dados até o candle anterior (i-1)
         double currentStd = CalculateStdDev(mainBufferRaw, StdBandPeriod, i - StdBandPeriod);
         
         //--- Calcular bandas (aplicadas ao candle atual, mas baseadas no candle anterior)
         upperBandBufferRaw[i] = mainBufferRaw[i-1] + currentStd;
         lowerBandBufferRaw[i] = mainBufferRaw[i-1] - currentStd;
         
         //--- Garantir que as bandas não ultrapassem os limites do gráfico
         upperBandBufferRaw[i] = MathMin(upperBandBufferRaw[i], 110);
         lowerBandBufferRaw[i] = MathMax(lowerBandBufferRaw[i], 0);
      }
   }
   
   //--- Aplicar suavização aos buffers
   SmoothBuffer(mainBufferRaw, mainBuffer, MainSmoothingPeriod, rates_total, SmoothingMethod);
   SmoothBuffer(upperBandBufferRaw, upperBandBuffer, BandSmoothingPeriod, rates_total, SmoothingMethod);
   SmoothBuffer(lowerBandBufferRaw, lowerBandBuffer, BandSmoothingPeriod, rates_total, SmoothingMethod);

   return rates_total;
}