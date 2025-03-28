#property tester_indicator "Market\Support and Resistance Levels Finder MT5"

string indicatorName;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
  
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Acessa os buffers do indicador
   double supportLevel = iCustom(_Symbol, _Period, "Market\Support and Resistance Levels Finder MT5", 0, 0);
   double resistanceLevel = iCustom(_Symbol, _Period, "Market\Support and Resistance Levels Finder MT5", 2, 0);
   double distanceToSupport = iCustom(_Symbol, _Period, "Market\Support and Resistance Levels Finder MT5", 1, 0);
   double distanceToResistance = iCustom(_Symbol, _Period, "Market\Support and Resistance Levels Finder MT5", 3, 0);

   // Verifica se os valores são válidos
   if (supportLevel == EMPTY_VALUE || resistanceLevel == EMPTY_VALUE)
      return;

   // Exibe os valores no log
   Print("Suporte: ", supportLevel);
   Print("Resistência: ", resistanceLevel);
   Print("Distância até o Suporte: ", distanceToSupport);
   Print("Distância até a Resistência: ", distanceToResistance);

   // Lógica de negociação
   if (distanceToSupport < 50.0) // Se o preço estiver a menos de 50 pontos do suporte
     {
      // Compre (exemplo)
      Print("Comprar: Preço próximo ao suporte.");
     }

   if (distanceToResistance < 50.0) // Se o preço estiver a menos de 50 pontos da resistência
     {
      // Venda (exemplo)
      Print("Vender: Preço próximo à resistência.");
     }
  }