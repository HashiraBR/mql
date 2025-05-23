//+------------------------------------------------------------------+
//| Estrutura que encapsula um sinal de trading                      |
//+------------------------------------------------------------------+
enum ENUM_TREND_DIRECTION{
   TREND_NONE,    // Sem tendência clara
   TREND_UP,      // Tendência de alta
   TREND_DOWN     // Tendência de baixa
};

struct TradeSignal
{
    bool         isValid;          // Flag que indica se o sinal é válido
    ENUM_TREND_DIRECTION direction; // Direção do trade (TREND_UP/TREND_DOWN)
    double       lotSize;          // Tamanho do lote calculado
    double       stopLoss;         // Stop loss em pontos
    double       takeProfit;       // Take profit em pontos ou múltiplo do SL
    string       comment;          // Comentário para identificar a origem
    int          patternType;      // Tipo de padrão (opcional para candles)
    double       openPrice;        // Preço de entrada
    
    // Construtor padrão
    TradeSignal(): isValid(false), direction(TREND_NONE), lotSize(0.0),
                   stopLoss(0.0), takeProfit(0.0), comment(""), patternType(-1) {}
};

