//+------------------------------------------------------------------+
//|                                                      CTester.mqh |
//|                                                    Danne Pereira |
//|                                             https://www.aipi.com |
//+------------------------------------------------------------------+
#property copyright "Danne Pereira"
#property link      "https://www.aipi.com"
#property version   "1.00"
class CTester
{
private:
    // Métodos auxiliares privados
    bool GetTradeResultsToArray(double &pl_results[], double &volume);
    bool CalculateLinearRegression(double &change[], double &chartline[], double &a_coef, double &b_coef);
    bool CalculateStdError(double &data[], double a_coef, double b_coef, double &std_err);

public:
    // Método principal para cálculo do critério de otimização
    double CalculateOptimizationCriterion();
    
    // Método para execução em modo de teste único (opcional)
    void RunSingleTest();
};

//+------------------------------------------------------------------+
//| Calcula o critério de otimização personalizado                   |
//+------------------------------------------------------------------+
double CTester::CalculateOptimizationCriterion()
{
    //--- valor do critério de otimização personalizado (quanto mais, melhor)
    double ret = 0.0;
    
    //--- obtemos os resultados dos trades na matriz
    double array[];
    double trades_volume;
    if(!GetTradeResultsToArray(array, trades_volume))
        return 0.0;
        
    int trades = ArraySize(array);
    
    //--- se há menos de 10 trades, o teste não gerou resultados positivos
    if(trades < 10)
        return 0.0;
    
    //--- resultado médio no trade
    double average_pl = 0;
    for(int i = 0; i < trades; i++)
        average_pl += array[i];
    average_pl /= trades;
    
    //--- exibimos uma mensagem para o modo de teste único
    if(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_OPTIMIZATION))
        PrintFormat("%s: Trades=%d, Lucro médio=%.2f", __FUNCTION__, trades, average_pl);
    
    //--- calculamos os coeficientes de regressão linear para o gráfico de lucro
    double a, b, std_error;
    double chart[];
    if(!CalculateLinearRegression(array, chart, a, b))
        return 0.0;
    
    //--- calculamos o erro de desvio do gráfico em relação à linha de regressão
    if(!CalculateStdError(chart, a, b, std_error))
        return 0.0;
    
    //--- calculamos o rácio do lucro de tendência em relação ao desvio padrão
    ret = (std_error == 0.0) ? a * trades : a * trades / std_error;
    
    //--- retornamos o valor do critério de otimização personalizado
    return ret;
}

//+------------------------------------------------------------------+
//| Obtendo a matriz de lucros/perdas de transações                  |
//+------------------------------------------------------------------+
bool CTester::GetTradeResultsToArray(double &pl_results[], double &volume)
{
    //--- consultamos o histórico de negociação completo
    if(!HistorySelect(0, TimeCurrent()))
        return false;
        
    uint total_deals = HistoryDealsTotal();
    volume = 0;
    
    //--- definimos o tamanho inicial da matriz pelo número de transações no histórico
    ArrayResize(pl_results, total_deals);
    
    //--- contador de trades que fixam o resultado da negociação - lucro ou perda
    int counter = 0;
    ulong ticket_history_deal = 0;
    
    //--- passar por todos os trades
    for(uint i = 0; i < total_deals; i++)
    {
        //--- selecionamos o trade 
        if((ticket_history_deal = HistoryDealGetTicket(i)) > 0)
        {
            ENUM_DEAL_ENTRY deal_entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket_history_deal, DEAL_ENTRY);
            long deal_type = HistoryDealGetInteger(ticket_history_deal, DEAL_TYPE);
            double deal_profit = HistoryDealGetDouble(ticket_history_deal, DEAL_PROFIT);
            double deal_volume = HistoryDealGetDouble(ticket_history_deal, DEAL_VOLUME);
            
            //--- estamos interessados apenas em operações de negociação        
            if((deal_type != DEAL_TYPE_BUY) && (deal_type != DEAL_TYPE_SELL))
                continue;
                
            //--- somente trades com fixação de lucro/perda
            if(deal_entry != DEAL_ENTRY_IN)
            {
                //--- escrevemos o resultado da negociação na matriz e aumentamos o contador de trades
                pl_results[counter] = deal_profit;
                volume += deal_volume;
                counter++;
            }
        }
    }
    
    //--- definimos o tamanho final da matriz
    ArrayResize(pl_results, counter);
    return (counter > 0);
}

//+------------------------------------------------------------------+
//| Calculando a regressão linear de tipo y=a*x+b                    |
//+------------------------------------------------------------------+
bool CTester::CalculateLinearRegression(double &change[], double &chartline[],
                                      double &a_coef, double &b_coef)
{
    //--- verificamos se há suficientes dados
    if(ArraySize(change) < 3)
        return false;
        
    //--- criamos a matriz do gráfico com acumulação
    int N = ArraySize(change);
    ArrayResize(chartline, N);
    chartline[0] = change[0];
    
    for(int i = 1; i < N; i++)
        chartline[i] = chartline[i-1] + change[i];
    
    //--- agora calculamos os coeficientes de regressão
    double x = 0, y = 0, x2 = 0, xy = 0;
    
    for(int i = 0; i < N; i++)
    {
        x += i;
        y += chartline[i];
        xy += i * chartline[i];
        x2 += i * i;
    }
    
    a_coef = (N * xy - x * y) / (N * x2 - x * x);
    b_coef = (y - a_coef * x) / N;
    
    return true;
}

//+------------------------------------------------------------------+
//| Calcula o erro quadrático médio do desvio para os a e b definidos|
//+------------------------------------------------------------------+
bool CTester::CalculateStdError(double &data[], double a_coef, double b_coef, double &std_err)
{
    //--- soma dos quadrados dos erros
    double error = 0;
    int N = ArraySize(data);
    
    if(N <= 2)
        return false;
        
    for(int i = 0; i < N; i++)
        error += MathPow(a_coef * i + b_coef - data[i], 2);
        
    std_err = MathSqrt(error / (N - 2));
    
    return true;
}

//+------------------------------------------------------------------+
//| Método para execução em modo de teste único (opcional)           |
//+------------------------------------------------------------------+
void CTester::RunSingleTest()
{
    if(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_OPTIMIZATION))
    {
        double criterion = CalculateOptimizationCriterion();
        Print("Critério de otimização calculado: ", criterion);
    }
}