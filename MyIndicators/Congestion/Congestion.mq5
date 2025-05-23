//+------------------------------------------------------------------+
//|                      PriceExtremeConsolidation.mq5               |
//|              Identificação de congestão com foco em preços extremos |
//+------------------------------------------------------------------+

#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   5

#property tester_indicator "Congestion.ex5"

//--- Inputs
input int      EMA1_Period = 7;
input int      EMA2_Period = 21;
input int      EMA3_Period = 50;
input double   TolerancePct = 0.05;
input double   TolerancePctLong = 0.05;
input int      Lookback = 100;
input color    SupportColor = clrLimeGreen;
input color    ResistanceColor = clrRed;
input double   ExtremeWeight = 3.0; // Peso para preços extremos

//--- Buffers
double EMA1Buffer[], EMA2Buffer[], EMA3Buffer[];
double SupportBuffer[], ResistanceBuffer[];
int ema1_handle, ema2_handle, ema3_handle;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Obter handles para as EMAs
   ema1_handle = iMA(NULL, 0, EMA1_Period, 0, MODE_EMA, PRICE_CLOSE);
   ema2_handle = iMA(NULL, 0, EMA2_Period, 0, MODE_EMA, PRICE_CLOSE);
   ema3_handle = iMA(NULL, 0, EMA3_Period, 0, MODE_EMA, PRICE_CLOSE);
   
   if(ema1_handle == INVALID_HANDLE || ema2_handle == INVALID_HANDLE)// || ema3_handle == INVALID_HANDLE)
   {
      Print("Erro ao criar handles para as EMAs");
      return(INIT_FAILED);
   }

   //--- Configurar buffers
   SetIndexBuffer(0, EMA1Buffer);
   SetIndexBuffer(1, EMA2Buffer);
   SetIndexBuffer(2, EMA3Buffer);
   SetIndexBuffer(3, SupportBuffer);
   SetIndexBuffer(4, ResistanceBuffer);
   
   //--- Configurar propriedades das linhas
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, clrBlue);
   PlotIndexSetString(0, PLOT_LABEL, "EMA "+string(EMA1_Period));
   
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, clrOrange);
   PlotIndexSetString(1, PLOT_LABEL, "EMA "+string(EMA2_Period));
   
   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, clrPurple);
   PlotIndexSetString(2, PLOT_LABEL, "EMA "+string(EMA3_Period));
   
   PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, SupportColor);
   PlotIndexSetInteger(3, PLOT_LINE_STYLE, STYLE_SOLID);
   PlotIndexSetInteger(3, PLOT_LINE_WIDTH, 2);
   PlotIndexSetString(3, PLOT_LABEL, "Suporte");
   
   PlotIndexSetInteger(4, PLOT_DRAW_TYPE, DRAW_LINE);
   PlotIndexSetInteger(4, PLOT_LINE_COLOR, ResistanceColor);
   PlotIndexSetInteger(4, PLOT_LINE_STYLE, STYLE_SOLID);
   PlotIndexSetInteger(4, PLOT_LINE_WIDTH, 2);
   PlotIndexSetString(4, PLOT_LABEL, "Resistência");
   
   //--- Limpar buffers quando não há consolidação
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, 0.0);
   
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
   //--- Verificar se há dados suficientes
   if(rates_total < MathMax(EMA1_Period, MathMax(EMA2_Period, EMA3_Period)) + Lookback)
      return(0);
      
   //--- Obter dados das EMAs
   if(CopyBuffer(ema1_handle, 0, 0, rates_total-prev_calculated+1, EMA1Buffer) <= 0) return(0);
   if(CopyBuffer(ema2_handle, 0, 0, rates_total-prev_calculated+1, EMA2Buffer) <= 0) return(0);
   if(CopyBuffer(ema3_handle, 0, 0, rates_total-prev_calculated+1, EMA3Buffer) <= 0) return(0);
   
   //--- Calcular posição inicial
   int start = (prev_calculated == 0) ? MathMax(EMA1_Period, MathMax(EMA2_Period, EMA3_Period)) : prev_calculated-1;
   
   for(int i=start; i<rates_total && !IsStopped(); i++)
   {
      //--- Verificar consolidação
      //double avg_ema = (EMA1Buffer[i] + EMA2Buffer[i] + EMA3Buffer[i]) / 3;
      double threshold = (EMA1Buffer[i] + EMA2Buffer[i]) / 2 * TolerancePct / 100;
      double thresholdLong = (EMA2Buffer[i] + EMA3Buffer[i]) / 2 * TolerancePctLong / 100;
      
      bool is_consolidation = MathAbs(EMA1Buffer[i] - EMA2Buffer[i]) < threshold && MathAbs(EMA2Buffer[i] - EMA3Buffer[i]) < thresholdLong;
      
      if(is_consolidation)
      {
         //--- Encontrar início da consolidação atual
         int start_idx = i;
         while(start_idx > 0 && 
               MathAbs(EMA1Buffer[start_idx-1] - EMA2Buffer[start_idx-1]) < threshold && 
               MathAbs(EMA2Buffer[start_idx-1] - EMA3Buffer[start_idx-1]) < thresholdLong)
         {
            start_idx--;
         }
         
         //--- Calcular S/R com peso nos extremos
         CalculateExtremeSR(start_idx, i, high, low);
      }
      else
      {
         SupportBuffer[i] = 0.0;
         ResistanceBuffer[i] = 0.0;
      }
   }
   
   return(rates_total);
}


//+------------------------------------------------------------------+
//| Cálculo de S/R com os 5 preços mais extremos                     |
//+------------------------------------------------------------------+
void CalculateExtremeSR(int start_idx, int end_idx, const double &high[], const double &low[])
{
   int consolidation_length = end_idx - start_idx + 1;
   
   // Só processar se tivermos pelo menos 5 candles
   if(consolidation_length < 5) return;
   
   // Arrays para armazenar os preços extremos
   double lowest_prices[5], highest_prices[5];
   ArrayInitialize(lowest_prices, EMPTY_VALUE);
   ArrayInitialize(highest_prices, EMPTY_VALUE);
   
   // Encontrar os 5 menores preços mínimos
   for(int i = start_idx; i <= end_idx; i++)
   {
      for(int j = 0; j < 5; j++)
      {
         if(lowest_prices[j] == EMPTY_VALUE || low[i] < lowest_prices[j])
         {
            // Deslocar valores para inserir o novo mínimo
            for(int k = 4; k > j; k--)
               lowest_prices[k] = lowest_prices[k-1];
            lowest_prices[j] = low[i];
            break;
         }
      }
   }
   
   // Encontrar os 5 maiores preços máximos
   for(int i = start_idx; i <= end_idx; i++)
   {
      for(int j = 0; j < 5; j++)
      {
         if(highest_prices[j] == EMPTY_VALUE || high[i] > highest_prices[j])
         {
            // Deslocar valores para inserir o novo máximo
            for(int k = 4; k > j; k--)
               highest_prices[k] = highest_prices[k-1];
            highest_prices[j] = high[i];
            break;
         }
      }
   }
   
   // Calcular médias dos 5 extremos
   double avg_support = 0, avg_resistance = 0;
   for(int i = 0; i < 5; i++)
   {
      avg_support += lowest_prices[i];
      avg_resistance += highest_prices[i];
   }
   avg_support /= 5;
   avg_resistance /= 5;
   
   // Aplicar a todos os candles da consolidação
   for(int i = start_idx; i <= end_idx; i++)
   {
      SupportBuffer[i] = avg_support;
      ResistanceBuffer[i] = avg_resistance;
   }
}