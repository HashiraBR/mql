//+------------------------------------------------------------------+
//|                     Candlestick Pattern Analyzer                 |
//+------------------------------------------------------------------+
#property script_show_inputs
#property strict

// Input parameters
input int       LookAheadPeriod = 20;    // Number of candles to analyze after pattern
input double    ATR_Period = 14;         // ATR period
input bool      IncludeSingleCandle = true;
input bool      IncludeDoubleCandle = true;
input bool      IncludeTripleCandle = true;

// Global variables
int atrHandle;
int ma25Handle, ma50Handle, ma100Handle;

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
 
   LoadHistoricalData(5);
   // Initialize indicators
   atrHandle = iATR(_Symbol, _Period, (int)ATR_Period);
   ma25Handle = iMA(_Symbol, _Period, 25, 0, MODE_EMA, PRICE_CLOSE);
   ma50Handle = iMA(_Symbol, _Period, 50, 0, MODE_EMA, PRICE_CLOSE);
   ma100Handle = iMA(_Symbol, _Period, 100, 0, MODE_EMA, PRICE_CLOSE);
   
   if(atrHandle == INVALID_HANDLE || ma25Handle == INVALID_HANDLE || 
      ma50Handle == INVALID_HANDLE || ma100Handle == INVALID_HANDLE)
   {
      Print("Error creating indicator handles");
      return;
   }
   
   // Create output file
   string filename = "PatternAnalysis_" + _Symbol + "_" + IntegerToString((int)_Period) + ".csv";
   int filehandle = FileOpen(filename, FILE_WRITE|FILE_CSV|FILE_ANSI);
   
   if(filehandle == INVALID_HANDLE)
   {
      Print("Error creating file: ", filename);
      return;
   }
   
   // Write CSV header
   FileWrite(filehandle, 
      "PatternName", "PatternType", "DateTime",
      "MA25", "MA50", "MA100", "ATR", "Trend",
      "Candle1_Open", "Candle1_High", "Candle1_Low", "Candle1_Close", "Candle1_Volume",
      "Candle2_Open", "Candle2_High", "Candle2_Low", "Candle2_Close", "Candle2_Volume",
      "Candle3_Open", "Candle3_High", "Candle3_Low", "Candle3_Close", "Candle3_Volume",
      "MaxPrice", "MinPrice", "BarsToMax", "BarsToMin", "FinalPrice"
   );
   
   // Main analysis loop
   int totalBars = Bars(_Symbol, _Period);
   int analyzedBars = 0;
   
   for(int i = 100; i < totalBars - LookAheadPeriod; i++)
   {
      // Get indicator values
      double ma25[1], ma50[1], ma100[1], atr[1];
      if(CopyBuffer(ma25Handle, 0, i, 1, ma25) != 1 || 
         CopyBuffer(ma50Handle, 0, i, 1, ma50) != 1 ||
         CopyBuffer(ma100Handle, 0, i, 1, ma100) != 1 ||
         CopyBuffer(atrHandle, 0, i, 1, atr) != 1)
      {
         continue;
      }
      
      // Determine trend (simple MA comparison)
      string trend = "Neutral";
      if(ma25[0] > ma50[0] && ma50[0] > ma100[0]) trend = "Up";
      else if(ma25[0] < ma50[0] && ma50[0] < ma100[0]) trend = "Down";
      
      // Get candle data
      MqlRates candles[];
      ArraySetAsSeries(candles, true);
      
      // Check single candle patterns
      if(IncludeSingleCandle && CopyRates(_Symbol, _Period, i, 1, candles) == 1)
      {
         string pattern = CheckSingleCandlePattern(candles[0]);
         if(pattern != "")
         {
            RecordPattern(filehandle, pattern, "Single", i, candles, ma25[0], ma50[0], ma100[0], atr[0], trend);
            analyzedBars++;
         }
      }
      
      // Check double candle patterns
      if(IncludeDoubleCandle && CopyRates(_Symbol, _Period, i, 2, candles) == 2)
      {
         string pattern = CheckDoubleCandlePattern(candles[1], candles[0]);
         if(pattern != "")
         {
            RecordPattern(filehandle, pattern, "Double", i, candles, ma25[0], ma50[0], ma100[0], atr[0], trend);
            analyzedBars++;
         }
      }
      
      // Check triple candle patterns
      if(IncludeTripleCandle && CopyRates(_Symbol, _Period, i, 3, candles) == 3)
      {
         string pattern = CheckTripleCandlePattern(candles[2], candles[1], candles[0]);
         if(pattern != "")
         {
            RecordPattern(filehandle, pattern, "Triple", i, candles, ma25[0], ma50[0], ma100[0], atr[0], trend);
            analyzedBars++;
         }
      }
   }
   
   FileClose(filehandle);
   Print("Analysis complete. Analyzed ", analyzedBars, " patterns. Results saved to ", filename);
}

//+------------------------------------------------------------------+
//| Check for single candle patterns                                 |
//+------------------------------------------------------------------+
string CheckSingleCandlePattern(const MqlRates &candle)
{
   double bodySize = MathAbs(candle.close - candle.open);
   double upperShadow = candle.high - MathMax(candle.open, candle.close);
   double lowerShadow = MathMin(candle.open, candle.close) - candle.low;
   double totalRange = candle.high - candle.low;
   
   // Hammer/Hanging Man
   if(lowerShadow >= 2 * bodySize && upperShadow <= bodySize * 0.5)
   {
      if(candle.close > candle.open) return "Hammer";
      else return "HangingMan";
   }
   
   // Inverted Hammer/Shooting Star
   if(upperShadow >= 2 * bodySize && lowerShadow <= bodySize * 0.5)
   {
      if(candle.close > candle.open) return "InvertedHammer";
      else return "ShootingStar";
   }
   
   // Doji
   if(bodySize <= totalRange * 0.05 && totalRange > 0)
   {
      return "Doji";
   }
   
   return "";
}

//+------------------------------------------------------------------+
//| Check for double candle patterns                                 |
//+------------------------------------------------------------------+
string CheckDoubleCandlePattern(const MqlRates &candle1, const MqlRates &candle2)
{
   // Engulfing patterns
   if(candle2.close > candle2.open && candle1.close < candle1.open && 
      candle1.open > candle2.close && candle1.close < candle2.open)
   {
      return "BullishEngulfing";
   }
   
   if(candle2.close < candle2.open && candle1.close > candle1.open && 
      candle1.open < candle2.close && candle1.close > candle2.open)
   {
      return "BearishEngulfing";
   }
   
   // Harami patterns
   if(candle2.close < candle2.open && candle1.close > candle1.open && 
      candle1.open < candle2.close && candle1.close > candle2.open &&
      candle1.high < candle2.high && candle1.low > candle2.low)
   {
      return "BullishHarami";
   }
   
   if(candle2.close > candle2.open && candle1.close < candle1.open && 
      candle1.open > candle2.close && candle1.close < candle2.open &&
      candle1.high < candle2.high && candle1.low > candle2.low)
   {
      return "BearishHarami";
   }
   
   return "";
}

//+------------------------------------------------------------------+
//| Check for triple candle patterns                                 |
//+------------------------------------------------------------------+
string CheckTripleCandlePattern(const MqlRates &candle1, const MqlRates &candle2, const MqlRates &candle3)
{
   // Morning Star
   if(candle3.close < candle3.open && 
      MathAbs(candle2.close - candle2.open) <= (candle2.high - candle2.low) * 0.1 &&
      candle1.close > candle1.open && 
      candle1.close > candle3.open * 1.01)
   {
      return "MorningStar";
   }
   
   // Evening Star
   if(candle3.close > candle3.open && 
      MathAbs(candle2.close - candle2.open) <= (candle2.high - candle2.low) * 0.1 &&
      candle1.close < candle1.open && 
      candle1.close < candle3.open * 0.99)
   {
      return "EveningStar";
   }
   
   return "";
}

//+------------------------------------------------------------------+
//| Record pattern data to file                                      |
//+------------------------------------------------------------------+
void RecordPattern(int filehandle, string patternName, string patternType, int barIndex, 
                  MqlRates &candles[], double ma25, double ma50, double ma100, 
                  double atr, string trend)
{
   // Get future price action
   double maxPrice = 0, minPrice = EMPTY_VALUE;
   int barsToMax = 0, barsToMin = 0;
   double finalPrice = 0;
   
   MqlRates futureCandles[];
   if(CopyRates(_Symbol, _Period, barIndex, LookAheadPeriod, futureCandles) == LookAheadPeriod)
   {
      finalPrice = futureCandles[LookAheadPeriod-1].close;
      
      for(int i = 0; i < LookAheadPeriod; i++)
      {
         if(futureCandles[i].high > maxPrice)
         {
            maxPrice = futureCandles[i].high;
            barsToMax = i;
         }
         
         if(futureCandles[i].low < minPrice)
         {
            minPrice = futureCandles[i].low;
            barsToMin = i;
         }
      }
   }
   
   // Write data to file
   FileWrite(filehandle,
      patternName, patternType, TimeToString(candles[0].time),
      DoubleToString(ma25, _Digits), DoubleToString(ma50, _Digits), DoubleToString(ma100, _Digits),
      DoubleToString(atr, _Digits), trend,
      
      // Candle 1 data (most recent)
      DoubleToString(candles[0].open, _Digits), DoubleToString(candles[0].high, _Digits),
      DoubleToString(candles[0].low, _Digits), DoubleToString(candles[0].close, _Digits),
      DoubleToString(candles[0].real_volume, 2),
      
      // Candle 2 data (if available)
      ArraySize(candles) > 1 ? DoubleToString(candles[1].open, _Digits) : "",
      ArraySize(candles) > 1 ? DoubleToString(candles[1].high, _Digits) : "",
      ArraySize(candles) > 1 ? DoubleToString(candles[1].low, _Digits) : "",
      ArraySize(candles) > 1 ? DoubleToString(candles[1].close, _Digits) : "",
      ArraySize(candles) > 1 ? DoubleToString(candles[1].real_volume, 2) : "",
      
      // Candle 3 data (if available)
      ArraySize(candles) > 2 ? DoubleToString(candles[2].open, _Digits) : "",
      ArraySize(candles) > 2 ? DoubleToString(candles[2].high, _Digits) : "",
      ArraySize(candles) > 2 ? DoubleToString(candles[2].low, _Digits) : "",
      ArraySize(candles) > 2 ? DoubleToString(candles[2].close, _Digits) : "",
      ArraySize(candles) > 2 ? DoubleToString(candles[2].real_volume, 2) : "",
      
      // Future performance
      DoubleToString(maxPrice, _Digits), DoubleToString(minPrice, _Digits),
      IntegerToString(barsToMax), IntegerToString(barsToMin),
      DoubleToString(finalPrice, _Digits)
   );
}

//+------------------------------------------------------------------+
//| Carrega dados históricos                                        |
//+------------------------------------------------------------------+
void LoadHistoricalData(int year)
{
   datetime endTime = TimeCurrent();
   datetime startTime = endTime - year*365*24*60*60; // 5 years back
   
   // First get the number of available bars
   int totalBars = Bars(_Symbol, _Period, startTime, endTime);
   
   // Then actually copy the rates
   MqlRates rates[];
   int copied = CopyRates(_Symbol, _Period, startTime, endTime, rates);
   
   Print("Dados carregados: ", copied, " candles");
   
   if(copied <= 0)
      Alert("Erro ao carregar dados históricos. Verifique o History Center (F2)");
}