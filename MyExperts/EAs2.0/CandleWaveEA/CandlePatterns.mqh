//+------------------------------------------------------------------+
//|                                                 CandlePatterns.mqh |
//|                        Copyright © 2023, Danne M. G. Pereira     |
//|                              Site: www.aipi.com.br               |
//+------------------------------------------------------------------+
#include "../../libs/CUtils.mqh" 

enum CandlePattern {
    PATTERN_NONE,
    PATTERN_DOJI,
    PATTERN_MARUBOZU_GREEN,
    PATTERN_MARUBOZU_RED,
    PATTERN_SHOOTING_STAR_RED,
    PATTERN_SHOOTING_STAR_GREEN,
    PATTERN_SPINNING_TOP,
    PATTERN_HAMMER_GREEN,
    PATTERN_HAMMER_RED
};

string CandlePatternNames[] = {
    "NONE",
    "DOJI",
    "MARUBOZU_GREEN",
    "MARUBOZU_RED",
    "SHOOTING_STAR_RED",
    "SHOOTING_STAR_GREEN",
    "SPINNING_TOP",
    "HAMMER_GREEN",
    "HAMMER_RED"
};

struct PatternConfig {
    bool enabled;
    double minRange;
    double maxRange;
    double lotSize;
    double stopLoss;
    double takeProfit;
};

CandlePattern IdentifyPattern(double open, double high, double low, double close, double minRange, double maxRange = 0) 
{
    // Configurações específicas para WDO/DOL
    double multiplier = 1.0;
    bool isWDO = (StringFind(_Symbol, "WDO", 0) != -1) || (StringFind(_Symbol, "DOL", 0) != -1);
    
    if (isWDO) {
        multiplier = 2.0; // Aumenta tolerâncias para WDO
    }
    
    double bodySize = MathAbs(close - open);
    double totalRange = high - low;
    
    // Range válido (ajustado para min/max)
    bool isRangeValid = (totalRange >= minRange * _Point);
    if (maxRange > 0) 
        isRangeValid = isRangeValid && (totalRange <= maxRange * _Point);
    
    if (!isRangeValid) 
        return PATTERN_NONE;

    // --- Critérios Relaxados ---
    double shadowPercent = 0.15 * multiplier; // 15% para WDO (30% sombra)
    double smallBodyPercent = 0.05 * multiplier; // Corpo pequeno (Doji)
    double marubozuBodyPercent = 0.85; // 85% do range é corpo
    double marubozuShadowPercent = 0.1 * multiplier; // 10% sombra para Marubozu

    // 1. Doji (corpo ≤ 5% do range e ≤ 10 ticks)
    if (bodySize <= smallBodyPercent * totalRange && bodySize <= 10 * _Point) 
        return PATTERN_DOJI;
    
    // 2. Hammer (verde/vermelho)
    if (totalRange >= 3 * bodySize) {
        double upperShadow = (close > open) ? (high - close) : (high - open);
        if (upperShadow <= shadowPercent * totalRange) {
            return (close > open) ? PATTERN_HAMMER_GREEN : PATTERN_HAMMER_RED;
        }
    }

    // 3. Shooting Star (verde/vermelho)
    if (totalRange >= 3 * bodySize) {
        double lowerShadow = (close > open) ? (open - low) : (close - low);
        if (lowerShadow <= shadowPercent * totalRange) {
            return (close > open) ? PATTERN_SHOOTING_STAR_GREEN : PATTERN_SHOOTING_STAR_RED;
        }
    }

    // 4. Marubozu (verde/vermelho)
    if (bodySize >= marubozuBodyPercent * totalRange) {
        double upperShadow = high - MathMax(open, close);
        double lowerShadow = MathMin(open, close) - low;
        if (upperShadow <= marubozuShadowPercent * totalRange && 
            lowerShadow <= marubozuShadowPercent * totalRange) {
            return (close > open) ? PATTERN_MARUBOZU_GREEN : PATTERN_MARUBOZU_RED;
        }
    }

    // 5. Spinning Top (corpo pequeno e sombras grandes)
    if (bodySize <= 0.3 * totalRange) {
        double upperShadow = (close > open) ? (high - close) : (high - open);
        double lowerShadow = (close > open) ? (open - low) : (close - low);
        if (upperShadow > bodySize && lowerShadow > bodySize) {
            return PATTERN_SPINNING_TOP;
        }
    }

    return PATTERN_NONE;
}

/*CandlePattern IdentifyPattern(double open, double high, double low, double close, double minRange, double maxRange = 0) 
{
    double multiplier = 1;
    if (StringFind(symbol, "WDO", 0) != -1 || StringFind(symbol, "DOL", 0) != -1)
      multiplier = 2;
    
    double bodySize = MathAbs(close - open);
    double totalRange = high - low;
    double shadowPercent = 0.1 * multiplier;
    
    // Verifica se o range está dentro dos limites
    bool isRangeValid = (totalRange >= minRange * _Point);

    if(maxRange > 0) 
       isRangeValid = isRangeValid && (totalRange <= maxRange * _Point);
    
    if(!isRangeValid) 
        return PATTERN_NONE;

    // Doji
    if(bodySize <= 10 * _Point) 
        return PATTERN_DOJI;
    
    // Hammer Verde (Bullish Hammer)
    if((close > open) && (totalRange > (3 * bodySize)) && ((high - close) <= (totalRange * shadowPercent))) 
        return PATTERN_HAMMER_GREEN;

    // Hammer Vermelho (Bearish Hammer)
    if((close < open) && (totalRange > (4 * bodySize)) && ((high - open) <= (totalRange * shadowPercent))) 
        return PATTERN_HAMMER_RED;

    // Marubozu
    if((close > open) && (bodySize > (totalRange * 0.9)) && 
      ((high - close) <= (totalRange * 0.05)) && 
      ((open - low) <= (totalRange * 0.05))) 
      return PATTERN_MARUBOZU_GREEN;
      
    if((close < open) && (bodySize > (totalRange * 0.9)) &&
      ((high - close) <= (totalRange * 0.05)) && 
      ((open - low) <= (totalRange * 0.05)))     
        return PATTERN_MARUBOZU_RED;

    // Shooting Star Vermelho (Bearish Shooting Star)
    if((close < open) && (totalRange > (3 * bodySize)) && ((close - low) <= (totalRange * shadowPercent))) 
        return PATTERN_SHOOTING_STAR_RED;

    // Shooting Star Verde (Bullish Shooting Star)
    if((close > open) && (totalRange > (8 * bodySize)) && ((open - low) <= (totalRange * shadowPercent))) 
        return PATTERN_SHOOTING_STAR_GREEN;

    // Spinning Top
    if((close > open) && (bodySize * 2 < (open - low)) && (bodySize < (high - close))) 
        return PATTERN_SPINNING_TOP;
    if((close < open) && (bodySize * 2 < (close - low)) && (bodySize < (high - open))) 
        return PATTERN_SPINNING_TOP;

    return PATTERN_NONE;
}*/

bool IsBuyPatternSignal(CandlePattern pattern)
{
    if(pattern == PATTERN_MARUBOZU_GREEN || pattern == PATTERN_HAMMER_GREEN || pattern == PATTERN_HAMMER_RED)
       return true;
    return false;
}

bool IsSellPatternSignal(CandlePattern pattern)
{
    if(pattern == PATTERN_MARUBOZU_RED || pattern == PATTERN_SHOOTING_STAR_RED || pattern == PATTERN_SHOOTING_STAR_GREEN)
       return true;
    return false;
}

string GetCandlePatternName(CandlePattern pattern)
{
   int index = (int)pattern;
   if(index >= 0 && index < ArraySize(CandlePatternNames))
      return CandlePatternNames[index];
   return "PATTERN_UNKNOWN";
}