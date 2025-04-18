//+------------------------------------------------------------------+
//|                                                  CUtils.mqh       |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.metaquotes.net/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.aipi.com/"
#property version   "1.00"
#property strict

#include <Object.mqh>

//+------------------------------------------------------------------+
//| Classe de utilitários para operações comuns                      |
//+------------------------------------------------------------------+
class CUtils : public CObject
{
public:
    //--- Construtor e destrutor ---//
                     CUtils() {}
                    ~CUtils() {}

    //--- Métodos estáticos de utilidade geral ---//

    /**
     * Arredonda um valor para o múltiplo mais próximo do tick size da corretora
     * @param value Valor a ser arredondado
     * @param symbol Símbolo para obter informações de tick (NULL para símbolo atual)
     * @return Valor arredondado ou 0 em caso de erro
     */
    static double Rounder(const double value, const string symbol = NULL)
    {
        string useSymbol = (symbol == NULL) ? _Symbol : symbol;
        double tickSize = SymbolInfoDouble(useSymbol, SYMBOL_TRADE_TICK_SIZE);
        
        if(tickSize <= 0)
        {
            PrintFormat("%s: Erro ao obter tick size para %s (Valor: %f)", __FUNCTION__, useSymbol, tickSize);
            return NormalizeDouble(value, (int)SymbolInfoInteger(useSymbol, SYMBOL_DIGITS));
        }
        
        return MathRound(value / tickSize) * tickSize;
    }

    /**
     * Verifica se dois preços são iguais considerando a precisão do símbolo
     * @param price1 Primeiro preço a comparar
     * @param price2 Segundo preço a comparar
     * @param symbol Símbolo para obter a precisão
     * @return true se os preços forem considerados iguais
     */
    static bool ComparePrices(const double price1, const double price2, const string symbol)
    {
        const double epsilon = SymbolInfoDouble(symbol, SYMBOL_POINT) * 10; // Margem maior para evitar falsos positivos
        return MathAbs(price1 - price2) < epsilon;
    }

    /**
     * Verifica se há posições abertas com um magic number
     * @param magicNumber Número mágico para filtrar
     * @param symbol Símbolo para filtrar (NULL para símbolo atual)
     * @return true se encontrar posição correspondente
     */
    static bool HasPosition(int magicNumber, string symbol = NULL)
    {
        string targetSymbol = (symbol == NULL) ? _Symbol : symbol;
        
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            if(PositionGetTicket(i) && 
               PositionGetInteger(POSITION_MAGIC) == magicNumber &&
               PositionGetString(POSITION_SYMBOL) == targetSymbol)
            {
                return true;
            }
        }
        return false;
    }

    /**
     * Verifica se o volume está acima da média
     * @param period Período para cálculo da média
     * @param symbol Símbolo para análise (NULL para símbolo atual)
     * @param timeframe Timeframe para análise (PERIOD_CURRENT para timeframe atual)
     * @return true se o volume atual estiver acima da média
     */
    static bool IsVolumeAboveAvg(int period, string symbol = NULL, ENUM_TIMEFRAMES timeframe = PERIOD_CURRENT)
    {
        if(period <= 0) 
        {
            PrintFormat("%s: Período inválido (%d)", __FUNCTION__, period);
            return false;
        }
        
        string targetSymbol = (symbol == NULL) ? _Symbol : symbol;
        ENUM_TIMEFRAMES targetTF = (timeframe == PERIOD_CURRENT) ? _Period : timeframe;
        
        double sumVolumes = 0;
        for(int i = 1; i <= period; i++)
        {
            sumVolumes += (double)iVolume(targetSymbol, targetTF, i);
        }
        
        double avgVolume = sumVolumes / period;
        double currentVolume = (double)iVolume(targetSymbol, targetTF, 0);
        
        return currentVolume > avgVolume;
    }
};