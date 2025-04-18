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
//input ENUM_ANCHOR_POSITION CommentPosition = LEFT_UPPER; // Posição do comentário
input color TextColorPositive = clrBlue; // Cor do texto
input color TextColorNegative = clrRed; // Cor do texto
input int num_contracts = 1;
double mini_ind = 0.20;
double mini_dol = 10;

//+------------------------------------------------------------------+
//| Variáveis globais                                               |
int x = -1;
int y = -1;
ENUM_VARIATION_MODE VariationMode = POINTS_MINI_INDEX;

//+------------------------------------------------------------------+
//| Inicialização                                                   |
int OnInit()
{
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, 1);
   CreateButtons();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Criação dos botões                                              |
void CreateButtons()
{
   string btnPrefix = "btn_";
   string btnInd = btnPrefix + "ind";
   string btnDol = btnPrefix + "dol";
   string btnPerc = btnPrefix + "perc";

   CreateButton(btnInd, 10, 90, "Índice", VariationMode == POINTS_MINI_INDEX);
   CreateButton(btnDol, 10, 120, "Dólar", VariationMode == POINTS_MINI_DOLLAR);
   CreateButton(btnPerc, 10, 150, "%", VariationMode == PERCENTAGE);
}

void CreateButton(string name, int x, int y, string text,  bool pressed)
{
   if (ObjectFind(0, name) != 0)
   {
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, 80);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, 20);
      ObjectSetInteger(0, name, OBJPROP_CORNER, 0);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
   }
   
   // Define o estado do botão (pressionado ou não)
   ObjectSetInteger(0, name, OBJPROP_STATE, pressed);
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
void Show(int x, int y, double variation)
{
   string name = "custom_comment";
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x + 20);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y + 20);

   string txt = "";

   if (VariationMode == POINTS_MINI_INDEX)
   {
      txt = DoubleToString(variation, 2) + " | R$ " + DoubleToString(num_contracts * variation * mini_ind, 2);
   }
   else if (VariationMode == POINTS_MINI_DOLLAR)
   {
      txt = DoubleToString(variation, 2) + " | R$ " + DoubleToString(num_contracts * variation * mini_dol, 2);
   }else{
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
   return MathRound(price * 2.0) / 2.0;
}

double CalculateVariation(double priceInit, double priceEnd)
{
   priceEnd = NormalizePrice(priceEnd);
   priceInit = NormalizePrice(priceInit);

   double variation = priceEnd - priceInit;

   switch (VariationMode)
   {
      case POINTS_MINI_INDEX:
         return MathRound(variation / 5.0) * 5.0;
      case POINTS_MINI_DOLLAR:
         return variation;
      case PERCENTAGE:
         return (priceEnd * 100 / priceInit) - 100;
      default:
         return variation;
   }
}


// Função para atualizar o estado dos botões com base no VariationMode
void UpdateButtons()
{
   // Remove todos os botões existentes
   ObjectsDeleteAll(0, "btn_");

   // Cria os botões novamente com o estado correto
   CreateButtons();
}

// Função chamada quando um botão é clicado
void OnButtonClick(string buttonName)
{
   // Atualiza o VariationMode com base no botão clicado
   if (buttonName == "btn_ind")
   {
      VariationMode = POINTS_MINI_INDEX;
   }
   else if (buttonName == "btn_dol")
   {
      VariationMode = POINTS_MINI_DOLLAR;
   }
   else if (buttonName == "btn_perc")
   {
      VariationMode = PERCENTAGE;
   }

   // Redesenha a interface
   UpdateButtons();
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

   if (id == CHARTEVENT_OBJECT_CLICK)
   {
      string name = sparam;
      if (name == "btn_ind")
      {
         VariationMode = POINTS_MINI_INDEX;
      }
      else if (name == "btn_dol")
      {
         VariationMode = POINTS_MINI_DOLLAR;
      }
      else if (name == "btn_perc")
      {
         VariationMode = PERCENTAGE;
      }
      
      OnButtonClick(sparam);
   }
}
