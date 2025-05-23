//+------------------------------------------------------------------+
//|                     CandlePatternIndicator.mq5                   |
//|                 Copyright 2023, MetaQuotes Software Corp.        |
//|                         https://www.mql5.com                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.01"
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   1

// Enumeração dos padrões de candles
enum CandlePattern
  {
   PATTERN_NONE,
   PATTERN_DOJI,
   PATTERN_HAMMER,
   PATTERN_MARUBOZU_GREEN,
   PATTERN_MARUBOZU_RED,
   PATTERN_SHOOTING_STAR,
   PATTERN_SPINNING_TOP
  };

// Inputs para configuração dos padrões
input int DojiVariation = 10;
input int HammerVariation = 15;
input int MarubozuGreenVariation = 20;
input int MarubozuRedVariation = 20;
input int ShootingStarVariation = 15;
input int SpinningTopVariation = 10;

// Cores dos padrões
input color DojiColor = clrPurple;
input color HammerColor = clrBlue;
input color MarubozuGreenColor = clrGreen;
input color MarubozuRedColor = clrRed;
input color ShootingStarColor = clrOrange;
input color SpinningTopColor = clrMagenta;

// Buffers para armazenar os valores e cores dos candles
double OpenBuffer[];
double HighBuffer[];
double LowBuffer[];
double CloseBuffer[];
double ColorBuffer[];

//+------------------------------------------------------------------+
//| Função de inicialização do indicador                            |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Configuração dos buffers
   SetIndexBuffer(0, OpenBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, HighBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, LowBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, CloseBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, ColorBuffer, INDICATOR_COLOR_INDEX);

   // Configuração do desenho dos candles coloridos
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_COLOR_CANDLES);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, DojiColor);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, HammerColor);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, MarubozuGreenColor);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 3, MarubozuRedColor);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 4, ShootingStarColor);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 5, SpinningTopColor);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Função principal de cálculo do indicador                        |
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
   for(int i = prev_calculated; i < rates_total; i++)
     {
      // Copiar os valores originais dos candles
      OpenBuffer[i] = open[i];
      HighBuffer[i] = high[i];
      LowBuffer[i] = low[i];
      CloseBuffer[i] = close[i];

      // Identificar o padrão do candle
      CandlePattern pattern = IdentifyPattern(open[i], high[i], low[i], close[i]);

      // Definir a cor do candle com base no padrão identificado
      ColorBuffer[i] = GetPatternColorIndex(pattern);
     }
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Identificação dos padrões de candles                            |
//+------------------------------------------------------------------+
CandlePattern IdentifyPattern(double open, double high, double low, double close)
  {
   double bodySize = MathAbs(close - open);
   double totalRange = high - low;
   
   if(bodySize <= 1 * _Point && totalRange >= DojiVariation * _Point) 
      return PATTERN_DOJI;
   if(close > open && totalRange > 2 * bodySize && (high - close) <= 10 * _Point && totalRange >= HammerVariation * _Point)
      return PATTERN_HAMMER;
   if(close > open && bodySize > (totalRange * 0.8) && totalRange >= MarubozuGreenVariation * _Point)
      return PATTERN_MARUBOZU_GREEN;
   if(close < open && bodySize > (totalRange * 0.8) && totalRange >= MarubozuRedVariation * _Point)
      return PATTERN_MARUBOZU_RED;
   if(close < open && totalRange > 2 * bodySize && (close - low) <= 10 * _Point && totalRange >= ShootingStarVariation * _Point)
      return PATTERN_SHOOTING_STAR;
   if(bodySize * 2 < (open - low) && bodySize < (high - close) && totalRange >= SpinningTopVariation * _Point)
      return PATTERN_SPINNING_TOP;
   if(bodySize * 2 < (close - low) && bodySize < (high - open) && totalRange >= SpinningTopVariation * _Point)
      return PATTERN_SPINNING_TOP;
   
   return PATTERN_NONE;
  }

//+------------------------------------------------------------------+
//| Retorna o índice da cor do padrão identificado                   |
//+------------------------------------------------------------------+
int GetPatternColorIndex(CandlePattern pattern)
  {
   switch(pattern)
     {
      case PATTERN_DOJI: return 0;
      case PATTERN_HAMMER: return 1;
      case PATTERN_MARUBOZU_GREEN: return 2;
      case PATTERN_MARUBOZU_RED: return 3;
      case PATTERN_SHOOTING_STAR: return 4;
      case PATTERN_SPINNING_TOP: return 5;
      default: return -1; // Nenhuma cor (candle normal)
     }
  }