//+------------------------------------------------------------------+
//|                                            TrendWaveMaster.mq5   |
//|                        Copyright © 2023, Danne M. G. Pereira     |
//|                              Email: makleyston@gmail.com         |
//|                              Site: www.aipi.com.br               |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2023, Danne M. G. Pereira"
#property link      "www.aipi.com.br"
#property version   "1.0"
#property description "TrendWaveMaster - EA baseado em médias móveis exponenciais para identificar tendências e gerar sinais de compra/venda."
#property description " "
#property description "Funcionalidades:"
#property description "- Usa EMAs para máximas, mínimas e fechamentos dos candles."
#property description "- Abertura de ordens com base na distância do preço em relação às EMAs."
#property description "- Gerenciamento de risco com Stop Loss e Take Profit."
#property description " "
#property description "Recomendações:"
#property description "- Use, preferencialmente, no timeframe de M2."
#property icon "\\Images\\TrendWaveMaster.ico" // Ícone personalizado (opcional)
#property script_show_inputs

#include "../DefaultInputs.mqh"
#include "../DefaultFunctions.mqh"

//+------------------------------------------------------------------+
//| Inputs do Expert Advisor                                         |
//+------------------------------------------------------------------+

// Configurações de Médias Móveis Exponenciais (EMA)
input int      InpEMAHighPeriod = 7;           // Período da EMA para máximas
input int      InpEMALowPeriod = 5;            // Período da EMA para mínimas
input int      InpMALongPeriod = 200;            // Período da MA Longa
input int      InpMAShortPeriod = 50;            // Período da MA Curta

input bool     InpUseVirtualEMAForTP = false;   // Usar a média virtual como TP

input double InpNearCloseExtreme = 0.1; //Fechamento próximo à extremidade em %

// Configurações de Distância
input double   InpDistancePercent = 0.12;       // Porcentagem de distância do fechamento para as médias

int emaHighHandle;    // Handle para a EMA das máximas
int emaLowHandle;     // Handle para a EMA das mínimas
int maLongHandle;
int maShortHandle;
int emaTPVirtual;
string trendLineName = "tp_virtual";

// Função para inicializar os handles dos indicadores
int InitializeIndicators() {

    emaHighHandle = iMA(_Symbol, InpTimeframe, InpEMAHighPeriod, 0, MODE_EMA, PRICE_HIGH);
    emaLowHandle = iMA(_Symbol, InpTimeframe, InpEMALowPeriod, 0, MODE_EMA, PRICE_LOW);
    maLongHandle = iMA(_Symbol, InpTimeframe, InpMALongPeriod, 0, MODE_SMA, PRICE_CLOSE);
    maShortHandle = iMA(_Symbol, InpTimeframe, InpMAShortPeriod, 0, MODE_SMA, PRICE_CLOSE);

    if (emaHighHandle == INVALID_HANDLE || emaLowHandle == INVALID_HANDLE || maLongHandle == INVALID_HANDLE || maShortHandle == INVALID_HANDLE)
    {
        Print(expertName+"Erro ao criar o handle da Média Móvel");
        return(INIT_FAILED);
    }
    
    // Desenha a linha de tendência para TP virtual
    emaTPVirtual = MathMax(InpEMAHighPeriod, InpEMALowPeriod);
    DrawVirtualTrendLine(emaTPVirtual, trendLineName);
    
    return INIT_SUCCEEDED;
}

int OnInit()
  {
//---
   return InitializeIndicators();
//---
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
    IndicatorRelease(emaHighHandle);
    IndicatorRelease(emaLowHandle);
    //IndicatorRelease(emaCloseHandle);
     // Remove a linha de tendência quando a EA é removida
    ObjectDelete(0, trendLineName);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    
    if(!IsSignalFromCurrentDay(_Symbol, InpTimeframe))
      return;
    
    CheckStopsSkippedAndCloseTrade(InpMagicNumber);
   
    // Cancela ordens velhas
    CancelOldPendingOrders(InpMagicNumber, InpOrderExpiration);
    
    // Aplica Trailing Stop se estiver ativado
    if (InpTrailingStop) MonitorTrailingStop(InpMagicNumber, InpStopLoss);

    // Verifica a última negociação e envia e-mail se necessário
    CheckLastTradeAndSendEmail(InpMagicNumber);
    
    // Verifica se é um novo candle
    if (!isNewCandle()) return;
    
    DrawVirtualTrendLine(emaTPVirtual, trendLineName);
   
    // Ajusta o TP se a opção estiver ativada
    if (InpUseVirtualEMAForTP)
        AdjustTPBasedOnVirtualEMA(InpMagicNumber);
   
    // Verifica horário de funcionamento e fecha possições
    if (!CheckTradingTime(InpMagicNumber)) 
        return;
        
    if(HasOpenPosition(InpMagicNumber)) return;
              
     double emaHigh = GetMAValue(emaHighHandle, 1);  // EMA de X períodos das máximas
     double emaLow = GetMAValue(emaLowHandle, 1);    // EMA de Y períodos das mínimas
     double maLong = GetMAValue(maLongHandle, 1);
     double maShort = GetMAValue(maShortHandle, 1);
     
     double lastClose = iClose(_Symbol, InpTimeframe, 1);  // Último preço de fechamento
     double lastHigh = iHigh(_Symbol, InpTimeframe, 1);  // Último preço de fechamento
     double lastLow = iLow(_Symbol, InpTimeframe, 1);  // Último preço de fechamento
     double distance = InpDistancePercent / 100.0; // Distância percentual para entrada
     
     bool upTrend = maShort > maLong;
     
     double tp = (InpUseVirtualEMAForTP ? 1000 : InpTakeProfit) * _Point;
     
     if (!upTrend && lastClose > emaHigh * (1 + distance) && MathAbs(lastClose - lastHigh) <= MathAbs(lastLow - lastHigh) * InpNearCloseExtreme/100) {
            ExecuteSellOrder(InpMagicNumber, InpLotSize, InpStopLoss, tp, "Price>"+DoubleToString(((lastClose - emaHigh) / emaHigh) * 100, 2)+ "% EMA_High");
        }
     else if (upTrend && lastClose < emaLow * (1 - distance) && MathAbs(lastClose - lastLow) <= MathAbs(lastLow - lastHigh) * InpNearCloseExtreme/100) {
            ExecuteBuyOrder(InpMagicNumber, InpLotSize, InpStopLoss, tp, "Price<"+DoubleToString(((lastClose - emaHigh) / emaHigh) * 100, 2)+ "% EMA_High");
        }

  }
//+------------------------------------------------------------------+

double GetMAValue(int handle, int shift = 0) {
    double emaValue[1]; // Array para armazenar o valor da EMA
    if (CopyBuffer(handle, 0, shift, 1, emaValue) == 1) {
        return emaValue[0]; // Retorna o valor da EMA no índice especificado
    }
    return -1; // Retorna -1 em caso de erro
}


// Função para calcular a média virtual
double CalculateVirtualEMA(double emaHigh, double emaLow) {
    return (emaHigh + emaLow) / 2.0;
}

// Função para ajustar o TP com base na média virtual
void AdjustTPBasedOnVirtualEMA(int magicNumber) {
    double emaHigh = GetMAValue(emaHighHandle);
    double emaLow = GetMAValue(emaLowHandle);
    double virtualEMA = CalculateVirtualEMA(emaHigh, emaLow);

    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if (PositionGetInteger(POSITION_MAGIC) == magicNumber) {
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double newTP = virtualEMA;

            if (posType == POSITION_TYPE_BUY && newTP > PositionGetDouble(POSITION_PRICE_OPEN)) {
                trade.PositionModify(ticket, PositionGetDouble(POSITION_SL), newTP);
            } else if (posType == POSITION_TYPE_SELL && newTP < PositionGetDouble(POSITION_PRICE_OPEN)) {
                trade.PositionModify(ticket, PositionGetDouble(POSITION_SL), newTP);
            }
        }
    }
}

void DrawVirtualTrendLine(double value, string lineName)
{
    // Verifica se a linha já existe
    if (ObjectFind(0, lineName) != -1)
    {
        ObjectDelete(0, lineName); // Remove a linha se já existir
    }

    // Cria uma nova linha de tendência horizontal
    ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, value);
    ObjectSetInteger(0, lineName, OBJPROP_COLOR, clrBlue); // Cor da linha
    ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_SOLID); // Estilo da linha
    ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2); // Espessura da linha
    ObjectSetString(0, lineName, OBJPROP_TEXT, "Virtual Trend Line"); // Texto da linha
}