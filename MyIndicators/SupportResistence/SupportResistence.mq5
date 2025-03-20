//+------------------------------------------------------------------+
//|                     SRLevelsUnified.mq5                          |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 1
#property indicator_plots   0

input int MaxCandles = 500;         // Número máximo de candles analisados
input double SafeDistance = 50;     // Margem de tolerância (em pontos)
input bool UseMedian = false;        // Preferência: true para mediana, false para média

enum NUMBER_LEVEL {
   LOW,
   MEDIUM,
   HIGH
};

input NUMBER_LEVEL numberLevel = MEDIUM;

input color supportColor = clrRed;     // Cor para linhas de suporte
input color resistenceColor = clrGreen;   // Cor para linhas de resistência
input int lineLarge = 1;                // Espessura das linhas
input int qtLvls = 10;                  // Quantidade de nívels

// Buffer para armazenar os níveis de suporte/resistência
double ResSupBuffer[];
int MinDistance;

// Defina um tamanho máximo para o buffer
//int MAX_LEVELS = 10; // Número máximo de níveis de suporte/resistência

//+------------------------------------------------------------------+
//| Função de inicialização do indicador                              |
//+------------------------------------------------------------------+
int OnInit()
{

    IndicatorSetString(INDICATOR_SHORTNAME, "SupportResistence");

    SetIndexBuffer(0, ResSupBuffer, INDICATOR_DATA);
    
    ArrayResize(ResSupBuffer, qtLvls);
    ArrayInitialize(ResSupBuffer, 0.0); // Inicialize o buffer com 0.0
    
    double close = iClose(_Symbol, PERIOD_CURRENT, 0);
    
    if(numberLevel == LOW){
      MinDistance = close * 0.00079;
    }else if(numberLevel == MEDIUM){
      MinDistance = close * 0.001;
    }else if(numberLevel == HIGH){
      MinDistance = close * 0.0013;
    }
    
    //MinDistance = 1500;
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Função de desinicialização do indicador                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    ObjectsDeleteAll(0, "SRLevel_");
}


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
    // Verificar se há candles suficientes para análise
    if (rates_total < MaxCandles)
        return(0);

    // Declarar lastTime como static para manter seu valor entre as chamadas
    static datetime lastTime = 0;

    // Verificar se time[0] é válido
    if (ArraySize(time) == 0)
    {
        Print("Erro: Array time[] está vazio.");
        return(0);
    }

    // Verificar se um novo candle foi aberto
    /*if (lastTime == 0 || time[0] != lastTime) // Novo candle aberto
    {
        // Atualiza o tempo do último candle processado
        lastTime = time[0];*/

        // Limpar o buffer
        ArrayInitialize(ResSupBuffer, 0);

        // Identificar os níveis de suporte/resistência
        IdentifyResSupLevels(high, low, close, rates_total, UseMedian);

        // Verificar o conteúdo do buffer após o preenchimento
        /*for (int i = 0; i < qtLvls; i++)
        {
            Print("ResSupBuffer[", i, "] = ", ResSupBuffer[i]);
        }*/
    //}

    // Desenhar os níveis no gráfico (atualiza a coloração das linhas)
    DrawResSupLevels(close[rates_total - 1]);

    return(rates_total);
}


//+------------------------------------------------------------------+
//| Identificar níveis de suporte/resistência                        |
//+------------------------------------------------------------------+
void IdentifyResSupLevels(const double &high[], const double &low[], const double &close[], int rates_total, bool useMedian)
{
    double levels[];

    // Identificar topos e fundos
    for (int i = 1; i < rates_total - 1; i++)
    {
        if (high[i] > high[i - 1] && high[i] > high[i + 1])
        {
            if (!IsCloseLevel(high[i], levels, MinDistance))
            {
                ArrayResize(levels, ArraySize(levels) + 1);
                levels[ArraySize(levels) - 1] = high[i];
            }
        }

        if (low[i] < low[i - 1] && low[i] < low[i + 1])
        {
            if (!IsCloseLevel(low[i], levels, MinDistance))
            {
                ArrayResize(levels, ArraySize(levels) + 1);
                levels[ArraySize(levels) - 1] = low[i];
            }
        }
    }

// No OnCalculate, preencha o buffer com os níveis encontrados
int buffer_index = 0; // Contador para controlar o preenchimento do buffer

// 1. Encontre o preço atual
double currentPrice = close[rates_total - 1]; // Preço de fechamento do candle mais recente

// 2. Ordene os níveis de suporte e resistência
ArraySort(levels); // Ordena os níveis em ordem crescente

// 3. Encontre os 5 níveis mais próximos acima e abaixo do preço atual
int levelsAbove = 0; // Contador para níveis acima do preço atual
int levelsBelow = 0; // Contador para níveis abaixo do preço atual

// 3.1. Adicionar níveis ABAIXO do preço atual (em ordem DECRESCENTE)
for (int i = ArraySize(levels) - 1; i >= 0; i--) // Percorre o array de trás para frente
{
    if (levels[i] < currentPrice && levelsBelow < (int)qtLvls/2)
    {
        ResSupBuffer[buffer_index++] = levels[i]; // Armazena o nível abaixo
        levelsBelow++;
    }

    // Se já encontramos 5 níveis abaixo, interrompa o loop
    if (levelsBelow >= (int)qtLvls/2)
        break;
}

// 3.2. Adicionar níveis ACIMA do preço atual (em ordem CRESCENTE)
for (int i = 0; i < ArraySize(levels); i++)
{
    if (levels[i] > currentPrice && levelsAbove < (int)qtLvls/2)
    {
        ResSupBuffer[buffer_index++] = levels[i]; // Armazena o nível acima
        levelsAbove++;
    }

    // Se já encontramos 5 níveis acima, interrompa o loop
    if (levelsAbove >= (int)qtLvls/2)
        break;
}

}


//+------------------------------------------------------------------+
//| Calcular a média de um array                                     |
//+------------------------------------------------------------------+
double CalculateMean(const double &values[])
{
    if (ArraySize(values) == 0)
        return 0;

    double sum = 0;
    for (int i = 0; i < ArraySize(values); i++)
    {
        sum += values[i];
    }

    return sum / ArraySize(values);
}

//+------------------------------------------------------------------+
//| Calcular a mediana de um array                                   |
//+------------------------------------------------------------------+
double CalculateMedian(double &values[])
{
    if (ArraySize(values) == 0)
        return 0;

    ArraySort(values); // Ordena os valores
    int size = ArraySize(values);

    // Se o número de elementos for ímpar, retorna o do meio
    if (size % 2 != 0)
        return values[size / 2];
    else // Se for par, retorna a média dos dois valores centrais
        return (values[size / 2 - 1] + values[size / 2]) / 2.0;
}

//+------------------------------------------------------------------+
//| Verificar níveis próximos                                        |
//+------------------------------------------------------------------+
bool IsCloseLevel(double level, const double &levels[], double min_distance)
{
    for (int i = 0; i < ArraySize(levels); i++)
    {
        if (MathAbs(level - levels[i]) <= min_distance)
            return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Desenhar os níveis de suporte/resistência no gráfico             |
//+------------------------------------------------------------------+
void DrawResSupLevels(double currentPrice)
{
    for (int i = 0; i < ArraySize(ResSupBuffer); i++)
    {
        if (ResSupBuffer[i] != 0)
        {
            string lineName = "SRLevel_" + IntegerToString(i);

            // Determinar a cor com base na posição do preço atual
            color lineColor = (ResSupBuffer[i] < currentPrice) ? supportColor : resistenceColor;

            // Desenhar o nível
            if (ObjectFind(0, lineName) < 0)
            {
                ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, ResSupBuffer[i]);
            }
            ObjectSetInteger(0, lineName, OBJPROP_COLOR, lineColor);   // Definir cor
            ObjectSetInteger(0, lineName, OBJPROP_WIDTH, lineLarge);  // Definir espessura
        }
    }
}
