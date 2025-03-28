//+------------------------------------------------------------------+
//|                                            TopBottomDetector.mq5 |
//|                                                    Danne Pereira |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Danne Pereira"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property indicator_chart_window
//+------------------------------------------------------------------+
//|                                                      ToposFundos |
//|                                      Copyright 2023, Seu Nome    |
//|                                      https://www.seusite.com      |
//+------------------------------------------------------------------+
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   2
#property indicator_color1  clrGreen
#property indicator_color2  clrRed
#property indicator_type1   DRAW_ARROW
#property indicator_type2   DRAW_ARROW
#property indicator_width1  2
#property indicator_width2  2

// Buffers para armazenar os topos e fundos
double ToposBuffer[];
double FundosBuffer[];

// Parâmetros do indicador
input int Periodo = 5;  // Número de velas para identificar topos e fundos
input double Offset = 15; //Offset em pontos

//+------------------------------------------------------------------+
//| Função de inicialização do indicador                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Definindo os buffers
   SetIndexBuffer(0, ToposBuffer);
   SetIndexBuffer(1, FundosBuffer);
   
   // Configurando os símbolos dos topos e fundos
   PlotIndexSetInteger(0, PLOT_ARROW, 234);  // Símbolo para topos
   PlotIndexSetInteger(1, PLOT_ARROW, 233);  // Símbolo para fundos
   
   // Nome do indicador
   IndicatorSetString(INDICATOR_SHORTNAME, "Topos e Fundos (" + string(Periodo) + ")");
   
   return(INIT_SUCCEEDED);
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
   // Loop para identificar topos e fundos
   for(int i = Periodo; i < rates_total - Periodo; i++)
     {
      // Identificando topos  
      
      if(IsTopo(i, high, Periodo))
        {
         ToposBuffer[i] = high[i] + Offset * _Point;
        }
      else
        {
         ToposBuffer[i] = EMPTY_VALUE;
        }
      
      // Identificando fundos
      if(IsFundo(i, low, Periodo))
        {
         FundosBuffer[i] = low[i] - Offset * _Point;
        }
      else
        {
         FundosBuffer[i] = EMPTY_VALUE;
        }
     }
   
   return(rates_total);
  }
//+------------------------------------------------------------------+
//| Função para identificar topos                                    |
//+------------------------------------------------------------------+
bool IsTopo(int index, const double &high[], int periodo)
  {
   for(int i = 1; i <= periodo; i++)
     {
      if(high[index] < high[index + i] || high[index] < high[index - i])
        {
         return false;
        }
     }
   return true;
  }
//+------------------------------------------------------------------+
//| Função para identificar fundos                                   |
//+------------------------------------------------------------------+
bool IsFundo(int index, const double &low[], int periodo)
  {
   for(int i = 1; i <= periodo; i++)
     {
      if(low[index] > low[index + i] || low[index] > low[index - i])
        {
         return false;
        }
     }
   return true;
  }
//+------------------------------------------------------------------+