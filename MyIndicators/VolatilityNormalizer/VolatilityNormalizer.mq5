//+------------------------------------------------------------------+
//| Volatility Normalizer Indicator                                 |
//| Versão otimizada para MQL5                                      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Seu Nome"
#property link      "https://seusite.com"
#property version   "1.00"
#property description "Indicador de Volatilidade Normalizada (0-100%)"

#property indicator_separate_window
#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_buffers 5
#property indicator_plots   3

//--- Plot 1: Volatilidade Normalizada
#property indicator_label1  "Volatilidade"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Média da Volatilidade
#property indicator_label2  "MA Volatilidade"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- Plot 3: Linha de Referência
#property indicator_label3  "Limiar"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrRed
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

//--- Parâmetros de entrada
input int      InpMAPeriod = 20;        // Período da média móvel
input int      InpDiffPeriod = 20;      // Período para cálculo do STD
input double   ThresholdFactor = 1.5;   // Fator do limiar
input ENUM_MA_METHOD MA_Method = MODE_SMA; // Método da MA

//--- Buffers do indicador
double         diffNormalizedBuffer[];  // Volatilidade normalizada (0-100%)
double         diffStdBuffer[];         // STD do diff
double         diffThresholdBuffer[];   // Limiar dinâmico
double         maBuffer[];              // Buffer para MA
double         tempBuffer[];            // Buffer temporário

//--- Handles
int            maHandle;                // Handle para a MA
int            stdHandle;               // Handle para o STD

//+------------------------------------------------------------------+
//| Função de inicialização do indicador                              |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Verificar parâmetros de entrada
   if(InpMAPeriod <= 0 || InpDiffPeriod <= 0)
   {
      Alert("Períodos devem ser maiores que zero");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   //--- Definir buffers
   SetIndexBuffer(0, diffNormalizedBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, diffStdBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(2, diffThresholdBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, maBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, tempBuffer, INDICATOR_CALCULATIONS);
   
   //--- Definir propriedades dos plots
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpMAPeriod + InpDiffPeriod);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, InpMAPeriod + InpDiffPeriod);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, InpMAPeriod + InpDiffPeriod);
   
   //--- Criar handles para indicadores técnicos
   maHandle = iMA(_Symbol, _Period, InpMAPeriod, 0, MA_Method, PRICE_CLOSE);
   stdHandle = iStdDev(_Symbol, _Period, InpMAPeriod, 0, MA_Method, PRICE_CLOSE);
   
   if(maHandle == INVALID_HANDLE || stdHandle == INVALID_HANDLE)
   {
      Print("Falha ao criar handles para indicadores técnicos");
      return INIT_FAILED;
   }
   
   //--- Definir nome curto para exibição
   IndicatorSetString(INDICATOR_SHORTNAME, "VolNorm(" + string(InpMAPeriod) + ")");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Função de desinicialização do indicador                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Liberar handles
   if(maHandle != INVALID_HANDLE) IndicatorRelease(maHandle);
   if(stdHandle != INVALID_HANDLE) IndicatorRelease(stdHandle);
}

//+------------------------------------------------------------------+
//| Função para calcular desvio padrão em um array                   |
//+------------------------------------------------------------------+
double CalculateStdDev(const double &array[], int count, int shift)
{
   if(count <= 1) return 0.0;
   
   double sum = 0.0;
   double sumSq = 0.0;
   
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
//| Função de iteração do indicador                                  |
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
   if(rates_total < MathMax(InpMAPeriod, InpDiffPeriod))
      return 0;
      
   //--- Obter dados da MA
   if(CopyBuffer(maHandle, 0, 0, rates_total - prev_calculated + 1, maBuffer) <= 0)
      return 0;
   
   //--- Obter dados do STD
   if(CopyBuffer(stdHandle, 0, 0, rates_total - prev_calculated + 1, tempBuffer) <= 0)
      return 0;
   
   //--- Calcular limites e diferença
   int start;
   if(prev_calculated == 0)
   {
      start = InpMAPeriod;
      ArrayInitialize(diffNormalizedBuffer, 0.0);
      ArrayInitialize(diffThresholdBuffer, 0.0);
   }
   else
   {
      start = prev_calculated - 1;
   }
   
   //--- Calcular buffers
   for(int i = start; i < rates_total; i++)
   {
      //--- Calcular bandas superior e inferior
      double upperBand = maBuffer[i] + tempBuffer[i];
      double lowerBand = maBuffer[i] - tempBuffer[i];
      double bandDiff = upperBand - lowerBand;
      
      //--- Armazenar diferença no buffer temporário
      tempBuffer[i] = bandDiff;
      
      //--- Calcular STD da diferença
      if(i >= MathMax(InpMAPeriod, InpDiffPeriod) - 1)
      {
         diffStdBuffer[i] = CalculateStdDev(tempBuffer, InpDiffPeriod, i - InpDiffPeriod + 1);
         
         //--- Normalizar para 0-100%
         static double maxDiffSTD = 0.0;
         if(diffStdBuffer[i] > maxDiffSTD) maxDiffSTD = diffStdBuffer[i];
         
         diffNormalizedBuffer[i] = (maxDiffSTD > 0) ? (diffStdBuffer[i] / maxDiffSTD) * 100 : 0;
         diffThresholdBuffer[i] = diffNormalizedBuffer[i] * ThresholdFactor;
      }
   }
   
   return rates_total;
}