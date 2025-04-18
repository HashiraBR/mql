//+------------------------------------------------------------------+
//|                                              FechamentoAnterior |
//|                        Copyright 2023, Seu Nome ou Empresa      |
//|                                       https://www.seusite.com    |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_separate_window

//+------------------------------------------------------------------+
//| Função de inicialização do indicador                             |
//+------------------------------------------------------------------+
int OnInit()
{
    // Chamar a função para desenhar a linha
    DesenharLinhaFechamentoAnterior();
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Função de iteração do indicador                                 |
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
    // Atualizar a linha a cada novo candle
    if (time[0] != iTime(NULL, PERIOD_D1, 0)) // Verificar se é um novo dia
    {
        DesenharLinhaFechamentoAnterior();
    }
    return(rates_total);
}

//+------------------------------------------------------------------+
//| Função para desenhar a linha do fechamento do dia anterior       |
//+------------------------------------------------------------------+
void DesenharLinhaFechamentoAnterior()
{
    // Obter o preço de fechamento do dia anterior
    double fechamentoAnterior = iClose(NULL, PERIOD_D1, 1);

    // Nome único para o objeto (para evitar duplicação)
    string nomeLinha = "FechamentoAnteriorLine";

    // Verificar se o objeto já existe
    if (ObjectFind(0, nomeLinha) >= 0)
    {
        // Atualizar o preço da linha existente
        ObjectSetDouble(0, nomeLinha, OBJPROP_PRICE, fechamentoAnterior);
    }
    else
    {
        // Criar uma nova linha horizontal
        ObjectCreate(0, nomeLinha, OBJ_HLINE, 0, 0, fechamentoAnterior);
        
        // Configurar a aparência da linha
        ObjectSetInteger(0, nomeLinha, OBJPROP_COLOR, clrRed); // Cor da linha
        ObjectSetInteger(0, nomeLinha, OBJPROP_WIDTH, 2);      // Espessura da linha
        ObjectSetInteger(0, nomeLinha, OBJPROP_STYLE, STYLE_DASH); // Estilo da linha
        
        // Tornar a linha não selecionável
        ObjectSetInteger(0, nomeLinha, OBJPROP_SELECTABLE, false);
    }
}