//+------------------------------------------------------------------+
//|                                                      NovoBot.mq5 |
//|                        Copyright © 2023, Seu Nome                |
//|                              Site: www.seusite.com               |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2023, Seu Nome"
#property link      "www.seusite.com"
#property version   "1.0"
#property description "NovoBot - Expert Advisor baseado em Bandas de Bollinger e Média Móvel."
#property description " "
#property description "Funcionalidades:"
#property description "- Opera com base na distância do preço em relação à Média Móvel."
#property description "- TP na média das Bandas de Bollinger."
#property description "- Condições de entrada baseadas em distâncias percentuais (disLong e disShort)."
#property description "- Uso de Média Móvel Simples ou Exponencial."
#property script_show_inputs

#include "../DefaultInputs.mqh"
#include "../DefaultFunctions.mqh"

// Inputs do Expert Advisor
input int      InpBollingerPeriod = 8;          // Período das Bandas de Bollinger
input double   InpBollingerDeviation = 2.7;     // Desvio padrão das Bandas de Bollinger
input int      InpMAPeriod = 200;               // Período da Média Móvel
input int      InpMAShortPeriod = 5;            // Período da Média Móvel de Curto Prazo
input ENUM_MA_METHOD InpMAMethod = MODE_SMA;    // Tipo de Média Móvel (SMA, EMA, etc.)
input double   InpDisLong = 1.0;                // Distância longa da MA (%)
input double   InpDisShort = 0.5;               // Distância curta da MA (%)
input bool     UseBollingerTP = true;           // Usar TP na média das Bandas de Bollinger?

// Variáveis globais para armazenar os handles dos indicadores
int bbHandle, maHandle, maShortHandle;
double upperBand[], lowerBand[], bollingerMiddle[]; // Arrays dinâmicos
double ma[], maShort[]; // Arrays dinâmicos
double maCurrent[], maShortCurrent[]; // Arrays dinâmicos

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Verifica se os parâmetros de entrada são válidos
   if(InpBollingerPeriod <= 0 || InpMAPeriod <= 0 || InpMAShortPeriod <= 0 || InpDisLong <= 0 || InpDisShort <= 0)
   {
      Print("Parâmetros de entrada inválidos!");
      return(INIT_PARAMETERS_INCORRECT);
   }

   // Obtém os handles dos indicadores de Bollinger Bands e Médias Móveis
   bbHandle = iBands(_Symbol, PERIOD_CURRENT, InpBollingerPeriod, 0, InpBollingerDeviation, PRICE_CLOSE);
   maHandle = iMA(_Symbol, PERIOD_CURRENT, InpMAPeriod, 0, InpMAMethod, PRICE_CLOSE);
   maShortHandle = iMA(_Symbol, PERIOD_CURRENT, InpMAShortPeriod, 0, InpMAMethod, PRICE_CLOSE);
   
   // Verifica se os handles são válidos
   if(bbHandle == INVALID_HANDLE || maHandle == INVALID_HANDLE || maShortHandle == INVALID_HANDLE)
   {
      Print("Erro ao obter os handles dos indicadores.");
      return(INIT_FAILED);
   }

   // Define o tamanho dos arrays dinâmicos
   ArrayResize(upperBand, 1);
   ArrayResize(lowerBand, 1);
   ArrayResize(bollingerMiddle, 1);
   ArrayResize(ma, 2);
   ArrayResize(maShort, 2);
   ArrayResize(maCurrent, 2);
   ArrayResize(maShortCurrent, 2);

   // Configura os buffers como séries temporais
   ArraySetAsSeries(upperBand, true);
   ArraySetAsSeries(lowerBand, true);
   ArraySetAsSeries(bollingerMiddle, true);
   ArraySetAsSeries(ma, true);
   ArraySetAsSeries(maShort, true);
   ArraySetAsSeries(maCurrent, true);
   ArraySetAsSeries(maShortCurrent, true);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Verifica stops skipped e fecha trades
   CheckStopsSkippedAndCloseTrade(InpMagicNumber);
   
   // Cancela ordens velhas
   CancelOldPendingOrders(InpMagicNumber, InpOrderExpiration);
   
   // Verifica a última negociação e envia e-mail se necessário
   CheckLastTradeAndSendEmail(InpMagicNumber);
   
   // Aplica Trailing Stop se estiver ativado
   if (InpTrailingStop) MonitorTrailingStop(InpMagicNumber, InpStopLoss);

   // Verifica se é um novo candle
   if (!isNewCandle()) return;
   
   // Atualiza o TP das posições abertas para a média das Bandas de Bollinger
   if (UseBollingerTP) UpdateTPForOpenPositions(InpMagicNumber);
   
   // Verifica horário de funcionamento e fecha posições
   if (!CheckTradingTime(InpMagicNumber)) return;
   
   // Verifica se já há uma posição aberta
   if(HasOpenPosition(InpMagicNumber)) return;

   // Lógica do EA

   // Copia os valores das Bandas de Bollinger
   if(CopyBuffer(bbHandle, 1, 0, 1, upperBand) <= 0 ||
      CopyBuffer(bbHandle, 2, 0, 1, lowerBand) <= 0 ||
      CopyBuffer(bbHandle, 0, 0, 1, bollingerMiddle) <= 0)
   {
      Print("Erro ao copiar os buffers das Bollinger Bands.");
      return;
   }

   // Copia os valores das Médias Móveis (candle atual e anterior)
   if(CopyBuffer(maHandle, 0, 0, 2, maCurrent) <= 0 ||
      CopyBuffer(maShortHandle, 0, 0, 2, maShortCurrent) <= 0)
   {
      Print("Erro ao copiar os buffers das Médias Móveis.");
      return;
   }

   // Obtém os valores das Médias Móveis
   double maValueCurrent = maCurrent[0];       // Média atual
   double maValuePrevious = maCurrent[1];      // Média anterior
   double maShortValueCurrent = maShortCurrent[0]; // Média curta atual
   double maShortValuePrevious = maShortCurrent[1]; // Média curta anterior

   // Obtém o preço de fechamento do candle anterior
   double closePrice = iClose(_Symbol, _Period, 1);

   // Calcula as distâncias em pontos
   double disLongPoints = maValueCurrent * (InpDisLong / 100);
   double disShortPoints = maValueCurrent * (InpDisShort / 100);

   // Plota as linhas no gráfico
   PlotAllLines(maValueCurrent, disLongPoints, disShortPoints);

   // Verifica as condições de compra e venda

   // Condição de Compra 1: Preço abaixo de MA - disLong e abaixo da banda inferior
   if (closePrice < maValueCurrent - disLongPoints && closePrice < lowerBand[0])
   {
      OpenTrade(ORDER_TYPE_BUY);
   }
   // Condição de Venda 1: Preço acima de MA + disLong e acima da banda superior
   else if (closePrice > maValueCurrent + disLongPoints && closePrice > upperBand[0])
   {
      OpenTrade(ORDER_TYPE_SELL);
   }
   // Condição de Compra 2: Preço dentro da região MA - disShort e MA + disShort, e "vem de cima"
   else if (closePrice > maValueCurrent - disShortPoints && closePrice < maValueCurrent + disShortPoints)
   {
      // Verifica se o preço "vem de cima"
      if (maShortValuePrevious > maValueCurrent + disShortPoints && maShortValueCurrent <= maValueCurrent + disShortPoints && closePrice < lowerBand[0])
      {
         OpenTrade(ORDER_TYPE_BUY);
      }
      // Verifica se o preço "vem de baixo"
      else if (maShortValuePrevious < maValueCurrent - disShortPoints && maShortValueCurrent >= maValueCurrent - disShortPoints && closePrice > upperBand[0])
      {
         OpenTrade(ORDER_TYPE_SELL);
      }
   }
}

//+------------------------------------------------------------------+
//| Função para atualizar o TP das posições abertas                  |
//+------------------------------------------------------------------+
void UpdateTPForOpenPositions(int magicNumber)
{
   double newTP = bollingerMiddle[0]; // TP na média das Bandas de Bollinger

   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (PositionGetInteger(POSITION_MAGIC) == magicNumber)
      {
         trade.PositionModify(ticket, PositionGetDouble(POSITION_SL), newTP);
      }
   }
}

//+------------------------------------------------------------------+
//| Função para criar ou atualizar uma linha horizontal              |
//+------------------------------------------------------------------+
void PlotLine(string name, double price, color lineColor, int lineWidth = 1, int lineStyle = STYLE_SOLID)
{
   // Verifica se o objeto já existe
   if (ObjectFind(0, name) < 0)
   {
      // Cria a linha se não existir
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   }
   else
   {
      // Atualiza o preço da linha se ela já existir
      ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   }

   // Define as propriedades da linha
   ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, lineWidth);
   ObjectSetInteger(0, name, OBJPROP_STYLE, lineStyle);
}

//+------------------------------------------------------------------+
//| Função para remover uma linha                                    |
//+------------------------------------------------------------------+
void RemoveLine(string name)
{
   if (ObjectFind(0, name) >= 0)
   {
      ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
//| Função para plotar todas as linhas                               |
//+------------------------------------------------------------------+
void PlotAllLines(double maValue, double disLongPoints, double disShortPoints)
{
   // Plotar a média móvel principal
   PlotLine("MA", maValue, clrBlue, 2, STYLE_SOLID);

   // Plotar as linhas de distância longa
   PlotLine("MA+DisLong", maValue + disLongPoints, clrRed, 2, STYLE_SOLID);
   PlotLine("MA-DisLong", maValue - disLongPoints, clrRed, 2, STYLE_SOLID);

   // Plotar as linhas de distância curta
   PlotLine("MA+DisShort", maValue + disShortPoints, clrPurple, 2, STYLE_SOLID);
   PlotLine("MA-DisShort", maValue - disShortPoints, clrPurple, 2, STYLE_SOLID);
}

//+------------------------------------------------------------------+
//| Função para remover todas as linhas                              |
//+------------------------------------------------------------------+
void RemoveAllLines()
{
   RemoveLine("MA");
   RemoveLine("MA+DisLong");
   RemoveLine("MA-DisLong");
   RemoveLine("MA+DisShort");
   RemoveLine("MA-DisShort");
}

//+------------------------------------------------------------------+
//| Função para abrir uma operação                                   |
//+------------------------------------------------------------------+
void OpenTrade(int orderType)
{
   double sl = InpStopLoss * _Point; // Stop Loss fixo
   double tp = (UseBollingerTP ? bollingerMiddle[0] : (InpTakeProfit > 0 ? InpTakeProfit : 0));   // TP na média das Bandas de Bollinger

   double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Abre a operação
   if (orderType == ORDER_TYPE_BUY)
   {
      trade.Buy(InpLotSize, _Symbol, price, price - sl, tp, "Compra");
   }
   else
   {
      trade.Sell(InpLotSize, _Symbol, price, price + sl, tp, "Venda");
   }
}