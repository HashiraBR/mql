//+------------------------------------------------------------------+
//|                                               Variation_Ruler.mq5 |
//|                                      Danne Makleyston G. Pereira |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Danne Makleyston G. Pereira"
#property description "Visualizador de porcentagem \nTem interesse em algum serviço? \nContate-me: \n\ndannemakleyston@yahoo.com.br"
#property link      "https://www.mql5.com"
#property version   "1.10"
#property indicator_chart_window

//+------------------------------------------------------------------+
//| Definição dos enums                                             |
enum ENUM_VARIATION_MODE
{
   POINTS_MINI_INDEX,  // Mini índice (5 em 5 pontos)
   POINTS_MINI_DOLLAR,  // Mini dólar (0,5 pontos por vez)
   PERCENTAGE
};

//+------------------------------------------------------------------+
//| Parâmetros personalizáveis                                      |
//+------------------------------------------------------------------+
input color TextColorPositive = clrBlue; // Cor do texto
input color TextColorNegative = clrRed; // Cor do texto
input int num_contracts = 1;
double mini_ind = 0.20;
double mini_dol = 10;

//+------------------------------------------------------------------+
//| Variáveis globais                                               |
int x = -1;
int y = -1;
ENUM_VARIATION_MODE VariationMode = PERCENTAGE; // Padrão para porcentagem

//+------------------------------------------------------------------+
//| Inicialização                                                   |
int OnInit()
{
   // Verifica o símbolo atual para definir o modo de cálculo automático
   string symbol = Symbol();
   if (StringFind(symbol, "WIN", 0) != -1 || StringFind(symbol, "IND", 0) != -1)
   {
      VariationMode = POINTS_MINI_INDEX;
   }
   else if (StringFind(symbol, "WDO", 0) != -1 || StringFind(symbol, "DOL", 0) != -1)
   {
      VariationMode = POINTS_MINI_DOLLAR;
   }
   else
   {
      VariationMode = PERCENTAGE; // Padrão para porcentagem se não for WIN/IND ou WDO/DOL
   }
   
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, 1);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Captura de eventos do mouse                                     |
void MouseState(uint state, int lparam, int dparam)
{
   if ((state & 1) == 1)  // Clique pressionado
   {
      if ((x == -1) || (y == -1))
      {
         x = lparam;
         y = dparam;
      }

      datetime dt = 0;
      double priceInit = 0;
      double priceEnd = 0;
      double price = 0;
      int window = 0;

      if ((ChartXYToTimePrice(0, x, y, window, dt, priceInit)) && (ChartXYToTimePrice(0, lparam, dparam, window, dt, priceEnd)))
      {
         price = priceEnd - priceInit;
         double percent = (priceEnd * 100 / priceInit) - 100;
         double variation = CalculateVariation(priceInit, priceEnd);

         string commentText = StringFormat("Preço Inicial: %.2f\nPreço Final: %.2f\nVariação: %.2f\nPorcentagem: %.2f%%",
                                           priceInit, priceEnd, variation, percent);

         Comment(commentText);
         Show(lparam, dparam, variation);
      }
   }
   else
   {
      Comment("");
      ObjectDelete(0, "custom_comment");
      x = -1;
      y = -1;
   }
}

//+------------------------------------------------------------------+
//| Exibe o resultado                                               |
void Show(int _x, int _y, double variation)
{
   string name = "custom_comment";
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   
   // Verifica se o preço está próximo à borda direita (ajuste o limite conforme necessário)
   int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int marginThreshold = 180; // Margem de segurança (pixels)
   
   if (_x > chartWidth - marginThreshold)
   {
      // Posiciona à esquerda do ponteiro
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, _x - 180); // Ajuste o valor (120) conforme necessário
   }
   else
   {
      // Posiciona à direita do ponteiro (comportamento padrão)
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, _x + 20);
   }
   
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, _y + 20);

   string txt = "";

   if (VariationMode == POINTS_MINI_INDEX)
   {
      txt = DoubleToString(variation, 2) + " pts | R$ " + DoubleToString(num_contracts * variation * mini_ind, 2);
   }
   else if (VariationMode == POINTS_MINI_DOLLAR)
   {
      txt = DoubleToString(variation, 2) + " pts | R$ " + DoubleToString(num_contracts * variation * mini_dol, 2);
   }
   else
   {
      txt = DoubleToString(variation, 2) + "% ";
   }

   if (variation >= 0)
   {
      ObjectSetInteger(0, name, OBJPROP_COLOR, TextColorPositive);
   }
   else
   {
      ObjectSetInteger(0, name, OBJPROP_COLOR, TextColorNegative);
   }

   ObjectSetString(0, name, OBJPROP_TEXT, txt);
}

//+------------------------------------------------------------------+
//| Calcula a variação conforme o modo selecionado                  |
double NormalizePrice(double price)
{
   // Aplica normalização diferente para dólar e índice
   if (VariationMode == POINTS_MINI_DOLLAR)
   {
      // Para dólar, normaliza para múltiplos de 0.5
      return MathRound(price * 2.0) / 2.0;
   }
   else if (VariationMode == POINTS_MINI_INDEX)
   {
      // Para índice, normaliza para inteiros
      return MathRound(price);
   }
   return price; // Para porcentagem, não normaliza
}

double CalculateVariation(double priceInit, double priceEnd)
{
   priceEnd = NormalizePrice(priceEnd);
   priceInit = NormalizePrice(priceInit);

   double variation = priceEnd - priceInit;

   switch (VariationMode)
   {
      case POINTS_MINI_INDEX:
         return MathRound(variation / 5.0) * 5.0; // Arredonda para múltiplos de 5 pontos
      case POINTS_MINI_DOLLAR:
         return variation; // Variação exata em pontos de 0.5
      case PERCENTAGE:
         return (priceEnd * 100 / priceInit) - 100;
      default:
         return variation;
   }
}

//+------------------------------------------------------------------+
//| Iteração do indicador                                           |
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const int begin,
                const double &price[])
{
   return (rates_total);
}

//+------------------------------------------------------------------+
//| Captura eventos do gráfico                                      |
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if (id == CHARTEVENT_MOUSE_MOVE)
   {
      MouseState((uint)sparam, (int)lparam, (int)dparam);
   }
}