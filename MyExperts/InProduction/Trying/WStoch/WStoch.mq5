//+------------------------------------------------------------------+
//|                                                     WStoch.mq5   |
//|                        Copyright © 2023, Danne M. G. Pereira     |
//|                              Email: makleyston@gmail.com         |
//|                              Site: www.aipi.com.br               |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2023, Danne M. G. Pereira"
#property link      "www.aipi.com.br"
#property version   "1.0"
#property description "WStoch - Expert Advisor baseado estocástico"
#property description " "
#property description "Funcionalidades:"
#property description "- Identifica sinais de entrada em operação com base em duplos toque na zona alta/baixa do indicador."
#property description "- Opera com a tendências definidas por meio de média móvel."
#property description "- As ordens são compradas à mercado."
#property description "- Gerenciamento de risco com Stop Loss e Take Profit."
#property description " "
#property description "Recomendações:"
#property description "- Use, preferencialmente, no timeframe de M2."
#property icon "\\Images\\WStoch.ico" // Ícone personalizado (opcional)
#property script_show_inputs


#include "../DefaultInputs.mqh"
#include "../DefaultFunctions.mqh"


//+------------------------------------------------------------------+
//| Inputs do Expert Advisor                                         |
//+------------------------------------------------------------------+

// Configurações do Indicador Estocástico
input int      InpStochasticKPeriod = 5;        // Período %K do Estocástico
input int      InpStochasticDPeriod = 3;        // Período %D do Estocástico
input int      InpStochasticSlowing = 3;        // Fator de desaceleração do Estocástico
input double   InpStochasticLowLevel = 20.0;    // Nível baixo do Estocástico (sobrevenda)
input double   InpStochasticHighLevel = 80.0;   // Nível alto do Estocástico (sobrecompra)

// Configurações de Entrada
input int      InpCandlesBetweenEntries = 3;    // Máximo de candles entre a primeira e segunda entrada

// Configurações de Stop Loss
input bool     InpUseTopBottomAsSL = false;     // Usar fundo/topo anterior como Stop Loss
input int      InpCandlesForTopBottom = 5;      // Candles para análise de topo/fundo

// Configurações de Take Profit
input bool     InpTPOnOverboughtOversold = false; // TP ao atingir sobrecompra/sobrevenda

enum ENUM_TRADE_MODE
{
    OPERAR_COMPRAS,      // Operar apenas compras
    OPERAR_VENDAS,       // Operar apenas vendas
    OPERAR_AMBAS         // Operar compras e vendas
};
input ENUM_TRADE_MODE InpTradeMode = OPERAR_AMBAS; // Modo de operação
input int InpMAPeriod = 200; // Período da Média Móvel

int handleMA;
int handleStoch;
bool flagZonaBaixa = false;             // Buffer para zona de nível baixo
bool stochZonaBaixa = false;            // Indica se o Stochástico entrou na zona baixa
bool flagZonaAlta = false;              // Reseta a flag após o sinal
bool stochZonaAlta = false;             // Reseta para próxima verificação
int candleCountAfterFirstEntry = 0;

//+------------------------------------------------------------------+
//| Função de inicialização do Expert Advisor                        |
//+------------------------------------------------------------------+

int OnInit()
{
    handleMA = iMA(_Symbol, InpTimeframe, InpMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
    if (handleMA == INVALID_HANDLE)
    {
        Print("Erro ao criar o handle da Média Móvel");
        return(INIT_FAILED);
    }
    
    handleStoch = iStochastic(_Symbol, InpTimeframe, InpStochasticKPeriod, InpStochasticDPeriod, InpStochasticSlowing, MODE_SMA, STO_LOWHIGH);
    if (handleStoch == INVALID_HANDLE)
    {
        Print(expertName+"Erro ao criar o handle do indicador Stochastic");
        return INIT_FAILED;
    }
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Função de execução do Expert Advisor                             |
//+------------------------------------------------------------------+

void OnDeinit(const int reason)
{
    IndicatorRelease(handleMA);
    IndicatorRelease(handleStoch);
}

void OnTick()
{
    
    CheckStopsSkippedAndCloseTrade(InpMagicNumber);
    
    // Cancela ordens velhas
    CancelOldPendingOrders(InpMagicNumber, InpOrderExpiration);

    // Aplica Trailing Stop se estiver ativado
    if (InpTrailingStop) MonitorTrailingStop(InpMagicNumber, InpStopLoss);
    
    // Verifica a última negociação e envia e-mail se necessário
    CheckLastTradeAndSendEmail(InpMagicNumber);
    
    // Verifica se é um novo candle
    if (!isNewCandle()) return;
    
    // Verifica horário de funcionamento e fecha possições
    if (!CheckTradingTime(InpMagicNumber)) 
        return;
    
    // Verifica se já existe uma posição aberta pelo bot
    if (HasOpenPosition(InpMagicNumber))
        return;

    // Criar arrays para armazenar os valores do Stochástico
    double stochMainArray[], stochSignalArray[];

    // Copiar os valores dos buffers do indicador
    if (CopyBuffer(handleStoch, 0, 1, 1, stochMainArray) <= 0 || CopyBuffer(handleStoch, 1, 1, 1, stochSignalArray) <= 0)
    {
        Print(expertName+"Erro ao copiar os buffers do Stochástico");
        return;
    }

    // Obter os valores do Stochástico
    double stochMain = stochMainArray[0];  // %K
    double stochSignal = stochSignalArray[0]; // %D
    
    // Verifica a tendência
    bool isUptrend = IsUptrend();
    bool isDowntrend = IsDowntrend();

    // Lógica de entrada (compra/venda)
    if ((InpTradeMode == OPERAR_COMPRAS || InpTradeMode == OPERAR_AMBAS) && isUptrend && CheckBuyCondition(stochMain, stochSignal))
    {
        ExecuteBuyOrder(InpMagicNumber, InpLotSize, InpStopLoss, InpTakeProfit, "Setup W");
    }
    if ((InpTradeMode == OPERAR_VENDAS || InpTradeMode == OPERAR_AMBAS) && isDowntrend && CheckSellCondition(stochMain, stochSignal))
    {
        ExecuteSellOrder(InpMagicNumber, InpLotSize, InpStopLoss, InpTakeProfit, "Setup M");
    }
}

//+------------------------------------------------------------------+
//| Funções de Verificação de Condições                              |
//+------------------------------------------------------------------+

bool CheckBuyCondition(double stochMain, double stochSignal)
{
    // Verifica se o Stochástico ultrapassou 50%
    if (stochMain >= 50.0)
    {
        flagZonaBaixa = false; // Limpa o buffer
        stochZonaBaixa = false; // Reseta para próxima verificação
        candleCountAfterFirstEntry = 0; // Reseta o contador de candles
    }

    // Verifica se o Stochástico está abaixo da zona baixa
    if (stochMain < InpStochasticLowLevel)
    {
        if (!stochZonaBaixa)
        {
            stochZonaBaixa = true; // Marca que entrou na zona baixa
        }
    }
    // Verifica se o Stochástico saiu da zona baixa
    else if (stochZonaBaixa && stochMain > InpStochasticLowLevel && !flagZonaBaixa)
    {
        flagZonaBaixa = true; // Ativa a flag
        stochZonaBaixa = false; // Reseta para próxima verificação
        candleCountAfterFirstEntry += 1; // Inicia o contador de candles
    }

    // Verifica se entrou novamente na zona baixa após a flag estar ativa
    if (stochZonaBaixa && flagZonaBaixa)
    {
        // Verifica o cruzamento para sinal de compra
        if (candleCountAfterFirstEntry <= InpCandlesBetweenEntries && stochMain > stochSignal)
        {
            Print(expertName+"Segunda entrada na zona de baixa; limite de candles <= " + IntegerToString(InpCandlesBetweenEntries) + "; stoch > média;");
            flagZonaBaixa = false; // Reseta a flag após o sinal
            stochZonaBaixa = false; // Reseta para próxima verificação
            candleCountAfterFirstEntry = 0;
            return true; // Sinal de compra
        }
    }
    return false; // Sem sinal de compra
}

bool CheckSellCondition(double stochMain, double stochSignal)
{
    // Verifica se o Stochástico caiu abaixo de 50%
    if (stochMain <= 50.0)
    {
        flagZonaAlta = false; // Limpa o buffer
        stochZonaAlta = false; // Reseta para próxima verificação
        candleCountAfterFirstEntry = 0;
    }

    // Verifica se o Stochástico está acima da zona alta
    if (stochMain > InpStochasticHighLevel)
    {
        if (!stochZonaAlta)
        {
            stochZonaAlta = true; // Marca que entrou na zona alta
        }
    }
    // Verifica se o Stochástico saiu da zona alta
    else if (stochZonaAlta && stochMain < InpStochasticHighLevel && !flagZonaAlta)
    {
        flagZonaAlta = true; // Ativa a flag
        stochZonaAlta = false; // Reseta para próxima verificação
        candleCountAfterFirstEntry += 1;
    }

    // Verifica se entrou novamente na zona alta após a flag estar ativa
    if (stochZonaAlta && flagZonaAlta)
    {
        // Verifica o cruzamento para sinal de venda
        if (candleCountAfterFirstEntry <= InpCandlesBetweenEntries && stochMain < stochSignal)
        {
            Print(expertName+"Segunda entrada na zona de alta; limite de candles <= " + IntegerToString(InpCandlesBetweenEntries) + "; stoch < média;");
            flagZonaAlta = false; // Reseta a flag após o sinal
            stochZonaAlta = false; // Reseta para próxima verificação
            candleCountAfterFirstEntry = 0;
            return true; // Sinal de venda
        }
    }
    return false; // Sem sinal de compra
}

double GetPreviousTopBottom(int orderType)
{
    double low[], high[];
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(high, true);

    // Copia os preços mais baixos e mais altos dos últimos candles
    if (CopyLow(_Symbol, _Period, 0, InpCandlesForTopBottom, low) <= 0 || CopyHigh(_Symbol, _Period, 0, InpCandlesForTopBottom, high) <= 0)
    {
        Print("Erro ao copiar os preços mais baixos/altos");
        return -1;
    }

    // Para ordens de compra, busca o fundo anterior
    if (orderType == ORDER_TYPE_BUY)
    {
        double fundo = low[ArrayMinimum(low)]; // Encontra o menor preço no intervalo
        return fundo;
    }
    // Para ordens de venda, busca o topo anterior
    else if (orderType == ORDER_TYPE_SELL)
    {
        double topo = high[ArrayMaximum(high)]; // Encontra o maior preço no intervalo
        return topo;
    }

    return -1; // Retorno padrão em caso de erro
}

bool IsUptrend()
{
    double maValue[];
    if (CopyBuffer(handleMA, 0, 0, 1, maValue) <= 0) return false;
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    return (currentPrice > maValue[0]); // Preço acima da MA = Tendência de alta
}

bool IsDowntrend()
{
    double maValue[];
    if (CopyBuffer(handleMA, 0, 0, 1, maValue) <= 0) return false;
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    return (currentPrice < maValue[0]); // Preço abaixo da MA = Tendência de baixa
}