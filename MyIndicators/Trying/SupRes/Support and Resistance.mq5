//+------------------------------------------------------------------+
//|                                       Support and Resistance.mq5 |
//|                                      https://t.me/ForexEaPremium |
//+------------------------------------------------------------------+
#property copyright "https://t.me/ForexEaPremium"
#property version   "2.02"

#property description "Blue and red support and resistance levels displayed directly on the chart."
#property description "Alerts for close above resistance and close below support."

#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2
#property indicator_color1  clrRed
#property indicator_type1   DRAW_ARROW
#property indicator_width1  2
#property indicator_label1  "Resistance"
#property indicator_color2  clrBlue
#property indicator_type2   DRAW_ARROW
#property indicator_width2  2
#property indicator_label2  "Support"

enum enum_candle_to_check
{
    Current,
    Previous
};

// Inputs configuráveis
input bool EnableNativeAlerts = false;
input bool EnableEmailAlerts  = false;
input bool EnablePushAlerts   = false;
input enum_candle_to_check TriggerCandle = Previous;
input int CandlesToConsider = 5; // Número de candles para considerar

double Resistance[];
double Support[];

int myFractal;

datetime LastAlertTime = D'01.01.1970';

void OnInit()
{
    PlotIndexSetInteger(0, PLOT_ARROW, 119);
    PlotIndexSetInteger(1, PLOT_ARROW, 119);

    SetIndexBuffer(0, Resistance);
    SetIndexBuffer(1, Support);

    ArraySetAsSeries(Resistance, true);
    ArraySetAsSeries(Support, true);

    PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, CandlesToConsider); // Ajustar início com base no input
    PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, CandlesToConsider);
    
    myFractal = iFractals(NULL, 0);
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &Time[],
                const double &open[],
                const double &High[],
                const double &Low[],
                const double &Close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    ArraySetAsSeries(High, true);
    ArraySetAsSeries(Low, true);
    ArraySetAsSeries(Close, true);
    ArraySetAsSeries(Time, true);

    // Obter os valores do indicador de fractais antes de entrar no ciclo
    double FractalUpperBuffer[];
    double FractalLowerBuffer[];
    
    CopyBuffer(myFractal, 0, 0, rates_total, FractalUpperBuffer);
    CopyBuffer(myFractal, 1, 0, rates_total, FractalLowerBuffer);
    
    ArraySetAsSeries(FractalUpperBuffer, true);
    ArraySetAsSeries(FractalLowerBuffer, true);

    for (int i = rates_total - 2; i >= CandlesToConsider; i--) // Respeitar o número de candles
    {
        double maxResistance = -DBL_MAX;
        double minSupport = DBL_MAX;

        // Considerar os X candles configurados no input
        for (int j = 0; j < CandlesToConsider; j++)
        {
            maxResistance = MathMax(maxResistance, High[i - j]);
            minSupport = MathMin(minSupport, Low[i - j]);
        }

        if (FractalUpperBuffer[i] != EMPTY_VALUE) Resistance[i] = maxResistance;
        else Resistance[i] = Resistance[i + 1];

        if (FractalLowerBuffer[i] != EMPTY_VALUE) Support[i] = minSupport;
        else Support[i] = Support[i + 1];
    }
    
    // Alerts
    if (((TriggerCandle > 0) && (Time[0] > LastAlertTime)) || (TriggerCandle == 0))
    {
        string Text, TextNative;
        // Resistance.
        if ((Close[TriggerCandle] > Resistance[TriggerCandle]) && (Close[TriggerCandle + 1] <= Resistance[TriggerCandle]))
        {
            Text = "S&R: " + Symbol() + " - " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)Period()), 7) + " - Closed above Resistance: " + DoubleToString(Resistance[TriggerCandle], _Digits) + ".";
            TextNative = "S&R: Closed above Resistance: " + DoubleToString(Resistance[TriggerCandle], _Digits) + ".";
            if (EnableNativeAlerts) Alert(TextNative);
            if (EnableEmailAlerts) SendMail("S&R Alert", Text);
            if (EnablePushAlerts) SendNotification(Text);
            LastAlertTime = Time[0];
        }
        // Support.
        if ((Close[TriggerCandle] < Support[TriggerCandle]) && (Close[TriggerCandle + 1] >= Support[TriggerCandle]))
        {
            Text = "S&R: " + Symbol() + " - " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)Period()), 7) + " - Closed below Support: " + DoubleToString(Support[TriggerCandle], _Digits) + ".";
            TextNative = "S&R: Closed below Support: " + DoubleToString(Support[TriggerCandle], _Digits) + ".";
            if (EnableNativeAlerts) Alert(TextNative);
            if (EnableEmailAlerts) SendMail("S&R Alert", Text);
            if (EnablePushAlerts) SendNotification(Text);
            LastAlertTime = Time[0];
        }
    }

    return rates_total;
}
//+------------------------------------------------------------------+
