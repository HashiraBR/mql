//+------------------------------------------------------------------+
//|                                                      EMA_Distance.mq5 |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrBlue
#property indicator_width1  2
#property indicator_label1  "Buy Signal"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_width2  2
#property indicator_label2  "Sell Signal"

// Input parameters
input int    EMA_Period_Max = 7;        // EMA period for highs
input int    EMA_Period_Min = 7;        // EMA period for lows
input double Distance_Percent = 0.12;  // Distance percentage (z%)

// Indicator buffers
double BuySignalBuffer[];
double SellSignalBuffer[];

// Global variables
int EMA_Max_Handle;
int EMA_Min_Handle;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    // Set up indicator buffers
    SetIndexBuffer(0, BuySignalBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, SellSignalBuffer, INDICATOR_DATA);
    
    // Set up arrow codes for plotting
    PlotIndexSetInteger(0, PLOT_ARROW, 233);  // Up arrow
    PlotIndexSetInteger(1, PLOT_ARROW, 234);  // Down arrow
    
    // Get handles for EMA indicators
    EMA_Max_Handle = iMA(NULL, 0, EMA_Period_Max, 0, MODE_EMA, PRICE_HIGH);
    EMA_Min_Handle = iMA(NULL, 0, EMA_Period_Min, 0, MODE_EMA, PRICE_LOW);
    
    // Check if handles are valid
    if (EMA_Max_Handle == INVALID_HANDLE || EMA_Min_Handle == INVALID_HANDLE)
    {
        Print("Erro ao criar handles das EMAs.");
        return(INIT_FAILED);
    }
    
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
    // Temporary arrays to store EMA values
    double EMA_Max[], EMA_Min[];

    // Copy EMA values for the entire range
    if (CopyBuffer(EMA_Max_Handle, 0, 0, rates_total, EMA_Max) <= 0 ||
        CopyBuffer(EMA_Min_Handle, 0, 0, rates_total, EMA_Min) <= 0)
    {
        Print("Erro ao copiar dados das EMAs.");
        return 0;
    }
    
    // Loop through all candles
    for (int i = prev_calculated; i < rates_total; i++)
    {
        // Calculate the distance in percentage
        double Distance_Max = EMA_Max[i] * (Distance_Percent / 100.0);
        double Distance_Min = EMA_Min[i] * (Distance_Percent / 100.0);
        
        // Check if price is above or below the EMAs
        if (close[i] > EMA_Max[i] + Distance_Max)
        {
            SellSignalBuffer[i] = high[i] + 20 * _Point;  // Plot sell signal above the candle
            BuySignalBuffer[i] = 0;  // No buy signal
        }
        else if (close[i] < EMA_Min[i] - Distance_Min)
        {
            BuySignalBuffer[i] = low[i] - 20 * _Point;  // Plot buy signal below the candle
            SellSignalBuffer[i] = 0;  // No sell signal
        }
        else
        {
            BuySignalBuffer[i] = 0;  // No signal
            SellSignalBuffer[i] = 0;  // No signal
        }
    }
    
    return rates_total;
}
