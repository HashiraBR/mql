
//+------------------------------------------------------------------+
//| Função para identificar padrões de candle de COMPRA (alta)       |
//+------------------------------------------------------------------+
bool IsBullishSignal(ENUM_TIMEFRAMES timeframe)
{
   // Dados do candle atual (último completo)
   double open   = iOpen(_Symbol, timeframe, 1);
   double close  = iClose(_Symbol, timeframe, 1);
   double low    = iLow(_Symbol, timeframe, 1);
   double high   = iHigh(_Symbol, timeframe, 1);
   
   // Dados do candle anterior
   double prevOpen   = iOpen(_Symbol, timeframe, 2);
   double prevClose  = iClose(_Symbol, timeframe, 2);
   double prevLow    = iLow(_Symbol, timeframe, 2);
   double prevHigh   = iHigh(_Symbol, timeframe, 2);
   
   // Cálculos comuns
   double bodySize = MathAbs(close - open);
   double totalRange = high - low;
   if(totalRange == 0) return false;
   
   // 1. Martelo (Hammer) - Reversão de baixa para alta
   if(close > open)
   {
      double lowerShadow = open - low;
      double upperShadow = high - close;
      bool isHammer = (lowerShadow >= 2 * bodySize) && 
                     (upperShadow <= bodySize * 0.5) &&
                     (bodySize <= totalRange * 0.3);
      if(isHammer) return true;
   }
   
   // 2. Martelo Invertido (Inverted Hammer) - Reversão
   if(close > open)
   {
      double upperShadow = high - close;
      double lowerShadow = open - low;
      bool isInvertedHammer = (upperShadow >= 2 * bodySize) && 
                            (lowerShadow <= bodySize * 0.5) &&
                            (bodySize <= totalRange * 0.3);
      if(isInvertedHammer) return true;
   }
   
   // 3. Engulfing de Alta (Bullish Engulfing) - Reversão forte
   if(prevClose < prevOpen && close > open && open < prevClose && close > prevOpen)
      return true;
   
   // 4. Piercing Line - Reversão moderada
   if(prevClose < prevOpen && close > open && open < prevClose && 
      close > (prevOpen + prevClose)/2 && close < prevOpen)
      return true;
   
   // 5. Estrela da Manhã (Morning Star) - Precisa de 3 candles
   double prev2Close = iClose(_Symbol, timeframe, 3);
   double prev2Open  = iOpen(_Symbol, timeframe, 3);
   if(prev2Close < prev2Open &&               // Primeiro candle: baixa
      MathAbs(prevClose - prevOpen) < (prevHigh - prevLow) * 0.3 && // Segundo candle: pequeno
      close > open &&                         // Terceiro candle: alta
      close > (prev2Open + prev2Close)/2)     // Fechamento acima do meio do primeiro
      return true;
   
   // 6. Inside Bar de Alta (continuação)
   if(high < prevHigh && low > prevLow && close > open && close > prevClose)
      return true;
   
   // 7. Outside Bar de Alta
   if(low < prevLow && high > prevHigh && close > open && close > (prevOpen + prevClose)/2)
      return true;
   
   // 8. Three White Soldiers (precisa de 3 candles de alta consecutivos)
   if(close > open && prevClose > prevOpen && prev2Close > prev2Open &&
      close > prevClose && prevClose > prev2Close &&
      open > prevOpen && prevOpen > prev2Open)
      return true;
      
   if(IsStrongBullishCandle(timeframe)) return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Função para identificar padrões de candle de VENDA (baixa)       |
//+------------------------------------------------------------------+
bool IsBearishSignal(ENUM_TIMEFRAMES timeframe)
{
   // Dados do candle atual (último completo)
   double open   = iOpen(_Symbol, timeframe, 1);
   double close  = iClose(_Symbol, timeframe, 1);
   double low    = iLow(_Symbol, timeframe, 1);
   double high   = iHigh(_Symbol, timeframe, 1);
   
   // Dados do candle anterior
   double prevOpen   = iOpen(_Symbol, timeframe, 2);
   double prevClose  = iClose(_Symbol, timeframe, 2);
   double prevLow    = iLow(_Symbol, timeframe, 2);
   double prevHigh   = iHigh(_Symbol, timeframe, 2);
   
   // Cálculos comuns
   double bodySize = MathAbs(close - open);
   double totalRange = high - low;
   if(totalRange == 0) return false;
   
   // 1. Estrela Cadente (Shooting Star) - Reversão de alta para baixa
   if(close < open)
   {
      double upperShadow = high - open;
      double lowerShadow = close - low;
      bool isShootingStar = (upperShadow >= 2 * bodySize) && 
                          (lowerShadow <= bodySize * 0.5) &&
                          (bodySize <= totalRange * 0.3);
      if(isShootingStar) return true;
   }
   
   // 2. Homem Pendurado (Hanging Man) - Reversão
   if(close < open)
   {
      double lowerShadow = close - low;
      double upperShadow = high - open;
      bool isHangingMan = (lowerShadow >= 2 * bodySize) && 
                        (upperShadow <= bodySize * 0.5) &&
                        (bodySize <= totalRange * 0.3);
      if(isHangingMan) return true;
   }
   
   // 3. Engulfing de Baixa (Bearish Engulfing) - Reversão forte
   if(prevClose > prevOpen && close < open && open > prevClose && close < prevOpen)
      return true;
   
   // 4. Dark Cloud Cover - Reversão moderada
   if(prevClose > prevOpen && close < open && open > prevClose && 
      close < (prevOpen + prevClose)/2 && close > prevOpen)
      return true;
   
   // 5. Estrela da Tarde (Evening Star) - Precisa de 3 candles
   double prev2Close = iClose(_Symbol, timeframe, 3);
   double prev2Open  = iOpen(_Symbol, timeframe, 3);
   if(prev2Close > prev2Open &&               // Primeiro candle: alta
      MathAbs(prevClose - prevOpen) < (prevHigh - prevLow) * 0.3 && // Segundo candle: pequeno
      close < open &&                         // Terceiro candle: baixa
      close < (prev2Open + prev2Close)/2)     // Fechamento abaixo do meio do primeiro
      return true;
   
   // 6. Inside Bar de Baixa (continuação)
   if(high < prevHigh && low > prevLow && close < open && close < prevClose)
      return true;
   
   // 7. Outside Bar de Baixa
   if(low < prevLow && high > prevHigh && close < open && close < (prevOpen + prevClose)/2)
      return true;
   
   // 8. Three Black Crows (precisa de 3 candles de baixa consecutivos)
   if(close < open && prevClose < prevOpen && prev2Close < prev2Open &&
      close < prevClose && prevClose < prev2Close &&
      open < prevOpen && prevOpen < prev2Open)
      return true;
      
   if(IsStrongBearishCandle(timeframe)) return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Função para identificar candles de força (forte tendência)      |
//+------------------------------------------------------------------+
bool IsStrongBullishCandle(ENUM_TIMEFRAMES timeframe)
{
   double open  = iOpen(_Symbol, timeframe, 1);
   double close = iClose(_Symbol, timeframe, 1);
   double low   = iLow(_Symbol, timeframe, 1);
   double high  = iHigh(_Symbol, timeframe, 1);
   
   if(close <= open) return false;
   
   double bodySize = close - open;
   double totalRange = high - low;
   
   // Candle com corpo grande (>70% do range) e sombras pequenas
   return (bodySize >= totalRange * 0.7) && 
          ((high - close) <= totalRange * 0.1) && 
          ((open - low) <= totalRange * 0.1);
}

bool IsStrongBearishCandle(ENUM_TIMEFRAMES timeframe)
{
   double open  = iOpen(_Symbol, timeframe, 1);
   double close = iClose(_Symbol, timeframe, 1);
   double low   = iLow(_Symbol, timeframe, 1);
   double high  = iHigh(_Symbol, timeframe, 1);
   
   if(close >= open) return false;
   
   double bodySize = open - close;
   double totalRange = high - low;
   
   // Candle com corpo grande (>70% do range) e sombras pequenas
   return (bodySize >= totalRange * 0.7) && 
          ((high - open) <= totalRange * 0.1) && 
          ((close - low) <= totalRange * 0.1);
}