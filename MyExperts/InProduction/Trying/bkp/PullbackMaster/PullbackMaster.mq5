//+------------------------------------------------------------------+
//|                                          PullbackMaster.mq5       |
//|                        Copyright © 2023, Danne M. G. Pereira     |
//|                              Email: makleyston@gmail.com         |
//|                              Site: www.aipi.com.br               |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2025, Danne M. G. Pereira"
#property link      "www.aipi.com.br"
#property version   "1.0"
#property description "PullbackMaster - Expert Advisor focado em operar pullbacks na tendência."
#property description " "
#property description "Funcionalidades:"
#property description "- Opera sempre a favor da tendência principal."
#property description "- Detecta pullbacks em Resistências e Suportes baseados em preços."
#property description "- Integra indicadores como MACD, RSI, Bollinger Bands e pullback clássico."
#property description "- Gerenciamento de risco avançado com Stop Loss e Take Profit."
#property description "- Horário de negociação configurável."
#property description "- Timeframe recomendado: M2 (2 minutos)."
#property description " "
#property description "Recomendações:"
#property description "- Ajuste os parâmetros dos indicadores conforme o ativo negociado."
#property icon "\\Images\\PullbackMaster.ico" // Ícone personalizado (opcional)

enum ENUM_SR_METHOD {
   SR_MEDIUM, //Mediana
   SR_AVG,    //Média
};

enum ENUM_NUMBER_LEVEL {
   LOW,
   MEDIUM,
   HIGH
};

enum ENUM_TP_TYPE {
   FIXED_TP, //Fixo
   RISK_REWARD, //Risco Retorno
   DYNAMIC_SM, //Cruz. MA Curta-Média
   DYNAMIC_ML, //Cruz. MA Média-Longa
   DYNAMIC_SL, //Cruz. MA Curta-Longa
};

/*enum ENUM_SL_TYPE {
   FIXED_SL, //Fixo
   MAX_MIN_BEFORE //Máx ou Mín candle ant.
};*/

#include "../DefaultFunctions.mqh"
#include "../DefaultInputs.mqh"

input bool InpApllySLAtMaxMin = false; // SL baseado na Máx/Min anterior? True: desabilita SL Fixo.
//input ENUM_SL_TYPE InpSLType = FIXED_SL; // Tipo de SL
input double InpTPRiskReward = 1.5; // TP com relação Risco-Retorno
input ENUM_TP_TYPE InpTpType = FIXED_TP; // Tipo de TP
input int InpQtPeriodToAnalyze = 5; // Quantidade de períodos para análise

input string space1_ = "==========================================================================="; // #### Configurações de Tendência: Médias Móveis ####
input int InpMAShortPeriod = 25;      // Período da Média Móvel Curta
input int InpMAMediumPeriod = 50;     // Período da Média Móvel Média
input int InpMALongPeriod = 200;      // Período da Média Móvel Longa
input double InpDistanceBetweenMA = 0.01; // Distância mínima entre as MAs (em porcentagem)
input bool InpUseTwoMAs = true;       // Tend. com (T) 2 (Méd e Lon) ou (F) 3 MAs (Cur, Méd e Lon)
input ENUM_MA_METHOD InpMAMethod = MODE_SMA; // Método de cálculo das Médias Móveis (ex: MODE_SMA, MODE_EMA)

input string space2_ = "==========================================================================="; // #### Configurações de Suporte e Resistência ####
input int InpMarginSR = 20;     // Margem em pontos para identificar níveis de suporte/resistência
input int InpMaxCandles = 500;  // Número máximo de candles analisados para identificar S/R
input double InpSafeDistance = 50; // Margem de tolerância em pontos para evitar níveis muito próximos
input ENUM_SR_METHOD InptSRMethod = SR_AVG; // Método de cálculo dos níveis de S/R (ex: SR_AVG para média, SR_MEDIAN para mediana)
input int InpQtLevels = 16;     // Quantidade de níveis de suporte/resistência a serem identificados
input ENUM_NUMBER_LEVEL InpNumberLevel = MEDIUM; // Sensibilidade dos níveis (LOW, MEDIUM, HIGH)

input string space3_ = "==========================================================================="; // #### Configurações de Bollinger Bands ####
input bool InpUseBollinger = true; // Habilitar/desabilitar operações baseadas em Bollinger Bands
input int InpBollingerPeriod = 14;  // Período das Bollinger Bands
input double InpBollingerDeviation = 2.5; // Desvio padrão das Bollinger Bands
input int InpMarginBands = 20; // Margem em pontos para verificar proximidade das bandas
input bool InpVerifyNearBands = true; // Verificar se o preço fecha próximo às bandas
input bool InpVerifyBrokenOutBands = true; // Verificar se o preço rompeu as bandas

input string space4_ = "==========================================================================="; // #### Configurações do RSI ####
input bool InpUseRSI = true; // Habilitar/desabilitar operações baseadas no RSI
input int InpRSIPeriod = 14; // Período do RSI
input int InpRSIUpLevel = 80; // Nível superior do RSI (sobrecompra)
input int InpRSIDownLevel = 20; // Nível inferior do RSI (sobrevenda)

input string space6_ = "==========================================================================="; // #### Configurações do Estocástico (Stoch) ####
input bool InpUseStoch = true; // Habilitar/desabilitar operações baseadas no Estocástico
input int InpStochKPeriod = 5; // Período %K do Estocástico
input int InpStochDPeriod = 3; // Período %D do Estocástico
input int InpStochSlowing = 3; // Fator de desaceleração do Estocástico
input int InpStochOverbought = 80; // Nível de sobrecompra do Estocástico
input int InpStochOversold = 20; // Nível de sobrevenda do Estocástico

input string space7_ = "==========================================================================="; // #### Configurações do MACD ####
input bool InpUseMACD = true; // Habilitar/desabilitar operações baseadas no MACD
input int InpMACDFastPeriod = 12; // Período rápido do MACD
input int InpMACDSlowPeriod = 26; // Período lento do MACD
input int InpMACDSignalPeriod = 9; // Período do sinal do MACD

input string space8_ = "==========================================================================="; // #### Configurações Pullback entre níveis ####
input bool InpUseRSPullback = true; //Habilitar/desabilitar pullback entre S&R


int bbHandle, maShortHandle, maMediumHandle, maLongHandle, rsiHandle;
double bUpperBand[], bLowerBand[], bMAShort[], bMAMedium[], bMALong[];

int stochHandle, macdHandle;
double bStochK[], bStochD[], bMACD[], bMACDSignal[];

double bSrLevels[];                     // Array para armazenar os níveis de suporte/resistência
int bTouchLevels[];                     // Array para contar quantas vezes o preço tocou em cada nível
double gMinDistance;                    // Distância mínima entre os níveis
double gDistanceBetweenMAs = 0;         // Distância entre as MAs
double bRSI[];

double gStopLoss;
int gTPMaxCross = 5000;

int OnInit()
  {
  // Verifica se os parâmetros de entrada são válidos
   if(InpMarginBands <= 0 || InpMarginSR <= 0 || InpMAShortPeriod <= 0 || InpMALongPeriod <= 0 || InpBollingerPeriod <= 0 || InpBollingerDeviation <= 0)
   {
      Print("Parâmetros de entrada inválidos!");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   // Inicializo os indicadores com base no último candle.
   bbHandle = iBands(_Symbol, InpTimeframe, InpBollingerPeriod, 0, InpBollingerDeviation, PRICE_CLOSE);
   maShortHandle= iMA(_Symbol, InpTimeframe, InpMAShortPeriod, 0, InpMAMethod, PRICE_CLOSE);
   maMediumHandle= iMA(_Symbol, InpTimeframe, InpMAMediumPeriod, 0, InpMAMethod, PRICE_CLOSE);
   maLongHandle = iMA(_Symbol, InpTimeframe, InpMALongPeriod, 0, InpMAMethod, PRICE_CLOSE);
   rsiHandle = iRSI(_Symbol, InpTimeframe, InpRSIPeriod, PRICE_CLOSE);
   
   stochHandle = iStochastic(_Symbol, InpTimeframe, InpStochKPeriod, InpStochDPeriod, InpStochSlowing, MODE_SMA, STO_LOWHIGH);
   macdHandle = iMACD(_Symbol, InpTimeframe, InpMACDFastPeriod, InpMACDSlowPeriod, InpMACDSignalPeriod, PRICE_CLOSE);
   
   // Verificar se os handles são válidos
   if(stochHandle == INVALID_HANDLE || macdHandle == INVALID_HANDLE)
   {
       Print("Erro ao obter os handles dos indicadores Stoch ou MACD.");
       return(INIT_FAILED);
   }
   
   gTPMaxCross = 1500;
   
   // Verifica se os handles são válidos
   if(bbHandle == INVALID_HANDLE || maShortHandle == INVALID_HANDLE 
   || maMediumHandle == INVALID_HANDLE || maLongHandle == INVALID_HANDLE 
   || rsiHandle == INVALID_HANDLE)
   {
      Print("Erro ao obter os handles dos indicadores.");
      return(INIT_FAILED);
   }
   
    // Calcular a distância mínima entre os níveis
   double close = iClose(_Symbol, InpTimeframe, 0);
   if (InpNumberLevel == LOW) gMinDistance = close * 0.0008;
   else if (InpNumberLevel == MEDIUM) gMinDistance = close * 0.001;
   else if (InpNumberLevel == HIGH) gMinDistance = close * 0.0013;
   
   gDistanceBetweenMAs = InpDistanceBetweenMA / 100;   
   
   gStopLoss = InpStopLoss;
   
   ArrayResize(bSrLevels, InpQtLevels);
   ArrayResize(bTouchLevels, InpQtLevels);
   ArrayInitialize(bTouchLevels, 0);
   
   ArrayResize(bStochK, InpQtPeriodToAnalyze);
   ArrayResize(bStochD, InpQtPeriodToAnalyze);
   ArrayResize(bMACD, 2);
   ArrayResize(bMACDSignal, 2);
   
   ArrayResize(bUpperBand, 1);
   ArrayResize(bLowerBand, 1);
   ArrayResize(bRSI, 1);
   ArrayResize(bMAShort, InpQtPeriodToAnalyze);
   ArrayResize(bMAMedium, InpQtPeriodToAnalyze);
   ArrayResize(bMALong, InpQtPeriodToAnalyze);
   
   ArraySetAsSeries(bStochK, true);
   ArraySetAsSeries(bStochD, true);
   ArraySetAsSeries(bMAShort, true);
   ArraySetAsSeries(bMAMedium, true);
   ArraySetAsSeries(bMALong, true);
   ArraySetAsSeries(bMACD, true);
   ArraySetAsSeries(bMACDSignal, true);
   
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
      IndicatorRelease(bbHandle);
      IndicatorRelease(maShortHandle);
      IndicatorRelease(maLongHandle);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    ManageCapital(InpMagicNumber, InpManageCapitalLoss);
    
    if (!CheckAndManagePositions(InpMaxOpenPositions)) 
        return;
    
    if(InpMaxTrades > 0)
        if(!ManageTotalTrades(InpMagicNumber, InpMaxTrades))
            return;
    
    if(InpMaxConsecutiveLosses > 0) 
        if(!ManageConsecutiveLosses(InpMagicNumber, InpMaxConsecutiveLosses))
            return;
    
    if(!IsSignalFromCurrentDay(_Symbol, InpTimeframe))
      return;
    
    CheckStopsSkippedAndCloseTrade(InpMagicNumber);
   
    // Cancela ordens velhas
    CancelOldPendingOrders(InpMagicNumber, InpOrderExpiration);
    
    // Aplica Trailing Stop se estiver ativado
    if (InpSLType == TRAILING) MonitorTrailingStop(InpMagicNumber, gStopLoss); // Chamar a função somente no ganho
    else if (InpSLType == PROGRESS) ProtectProfitProgressivo(InpMagicNumber, InpProgressSLProtectedPoints, InpProgressSLPercentToProtect);

    // Verifica a última negociação e envia e-mail se necessário
    CheckLastTradeAndSendEmail(InpMagicNumber);
    
    // Verifica se é um novo candle
    if (!isNewCandle()) 
        return;
   
    UpdateIndicators();
   
    // Verifica horário de funcionamento e fecha possições
    if (!CheckTradingTime(InpMagicNumber)) 
        return;
    
    IdentifyResSupLevels();  
        
    //PrintLvls();
    
    if(HasOpenPosition(InpMagicNumber)) {
        if(InpTpType == DYNAMIC_ML || InpTpType == DYNAMIC_SM || InpTpType == DYNAMIC_SL)
            DynamicTP(InpMagicNumber);
        return;
     }
     
    CheckForTrade();
  }
//+------------------------------------------------------------------+

void UpdateIndicators()
{
    
   // Copia os valores das Bandas de Bollinger
   if(CopyBuffer(bbHandle, 1, 1, 1, bUpperBand) <= 0 ||
      CopyBuffer(bbHandle, 2, 1, 1, bLowerBand) <= 0 )
   {
      Print("Erro ao copiar os buffers das Bollinger Bands.");
      return;
   }

   // Copia os valores das Médias Móveis (candle atual e anterior)
   if(CopyBuffer(maLongHandle, 0, 1, InpQtPeriodToAnalyze, bMALong) <= 0 ||
      CopyBuffer(maMediumHandle, 0, 1, InpQtPeriodToAnalyze, bMAMedium) <= 0 ||
      CopyBuffer(maShortHandle, 0, 1, InpQtPeriodToAnalyze, bMAShort) <= 0 )
   {
      Print("Erro ao copiar os buffers das Médias Móveis.");
      return;
   }
   
   // Copia os valores do Stoch
    if(CopyBuffer(stochHandle, 0, 1, InpQtPeriodToAnalyze, bStochK) <= 0 ||
       CopyBuffer(stochHandle, 1, 1, InpQtPeriodToAnalyze, bStochD) <= 0)
    {
        Print("Erro ao copiar os buffers do Stoch.");
        return;
    }

    // Copia os valores do MACD
    if(CopyBuffer(macdHandle, 0, 1, 2, bMACD) <= 0 ||
       CopyBuffer(macdHandle, 1, 1, 2, bMACDSignal) <= 0)
    {
        Print("Erro ao copiar os buffers do MACD.");
        return;
    }
   
   // Copia os valores do RSI para o candle anterior
   if(CopyBuffer(rsiHandle, 0, 1, 1, bRSI) <= 0) // Diferentemente dos outros indicadores, o RSI não inicializa no OnInit com o candle anterior, então tenho quiei colocar 1 nesse momento.
   {
      Print("Erro ao copiar os buffers da RSI");
      return;
   }
}

// Função principal para verificar condições de entrada em trades
void CheckForTrade() 
{
    string comment = "Operação realizada"; // Comentário padrão para a operação
    bool tradeFlag = false; // Flag para indicar se uma operação foi sinalizada

    // Obtém os preços do último candle
    double lastHigh = iHigh(_Symbol, InpTimeframe, 1);
    double lastOpen = iOpen(_Symbol, InpTimeframe, 1);
    double lastLow = iLow(_Symbol, InpTimeframe, 1);
    double lastClose = iClose(_Symbol, InpTimeframe, 1);
    
    // Verifica se o preço fechou próximo de algum nível de suporte/resistência
    bool isNearSR = CheckNearSR(lastClose, InpMarginSR);
    
    // Verifica a tendência com base nas Médias Móveis
    bool isTrendUp = CheckTrendUp();   // Tendência de alta: MA curta > MA longa
    bool isTrendDown = CheckTrendDown(); // Tendência de baixa: MA curta < MA longa
    
    // Se o preço estiver próximo de um nível de suporte/resistência
    if (isNearSR) 
    {  
        comment = "NearSR"; // Atualiza o comentário para indicar proximidade a S/R
        
        // Se a tendência for de alta
        if (isTrendUp) 
        {
            comment += "+TrendUp"; // Adiciona tendência de alta ao comentário
            
            // Verifica a estratégia de Bollinger Bands
            if (!tradeFlag && InpUseBollinger) 
            {
                // Verifica se a abordagem de proximidade ou rompimento das bandas está habilitada
                if (InpVerifyNearBands || InpVerifyBrokenOutBands) 
                {   
                    // Verifica se o preço fechou próximo da banda inferior
                    bool isNearDownBand = (InpVerifyNearBands ? CheckNearDownBand(lastClose, InpMarginBands) : true);
                    // Verifica se o preço rompeu a banda inferior
                    bool isBrokenOutDown = (InpVerifyBrokenOutBands ? CheckBrokenOutDownBand(lastClose) : true);
                    
                    // Se ambas as condições forem atendidas, sinaliza uma operação
                    if (isNearDownBand && isBrokenOutDown) 
                    {
                        comment += "+Bollinger";
                        tradeFlag = true;
                    }
                } 
                else 
                {
                    Print("O uso de Bollinger está habilitado, mas nenhuma abordagem (proximidade ou rompimento) foi selecionada.");
                }
            }
            
            // Verifica a estratégia de RSI
            if (!tradeFlag && InpUseRSI) 
            { 
                bool isRSIOversold = CheckRSIOverSold();
                if (isRSIOversold) 
                {
                    comment += "+RSI_OS"; // RSI sobrevendido
                    tradeFlag = true;  
                }
            }
            
            // Verifica a estratégia de Stoch
            if (!tradeFlag && InpUseStoch) 
            {
                bool isStochSignal = CheckStochOverSold();
                if (isStochSignal) 
                {
                    comment += "+Stoch_OS"; // Stoch sobrevendido
                    tradeFlag = true; 
                }
            }
            
            // Verifica a estratégia de MACD
            if (!tradeFlag && InpUseMACD) 
            {
                bool isMACDSignal = CheckMACDBuySignal();
                if (isMACDSignal) 
                {
                    comment += "+MACD"; // Sinal de compra do MACD
                    tradeFlag = true; 
                }
            }
            
            // Verifica a estratégia de S&R anterior
            if(!tradeFlag && InpUseRSPullback)
            {
            
            
               bool isPullbackUpTrend = CheckSRPullbackUpTrend(lastClose);
               if(isPullbackUpTrend)
               {
                   comment += "+PB"; // Sinal de compra por ser pullback de tendência de alta
                   tradeFlag = true; 
               }
            }
            
            // Executa a ordem de compra se uma condição for atendida
            if (tradeFlag) {
                double sl = 0.0; // Stop Loss (preço absoluto)
                double tp = 0.0; // Take Profit (preço absoluto)
            
                // Cálculo do Stop Loss (SL)
                if (InpSLType == FIXED && !InpApllySLAtMaxMin) {
                    // SL fixo: InpStopLoss é o valor em pontos
                    sl = lastClose - InpStopLoss * _Point;
                } 
                
                if (InpApllySLAtMaxMin) {
                    // SL baseado no mínimo anterior: InpStopLoss é o valor em pontos
                    sl = lastLow - InpStopLoss * _Point;
                }
            
                gStopLoss = MathAbs(lastClose - sl);
                   
                // Cálculo do Take Profit (TP)
                if(InpTpType == FIXED_TP){
                    tp = lastClose + InpTakeProfit * _Point;
                } else if (InpTpType == RISK_REWARD) {
                    // TP baseado no risco/recompensa: InpTPRiskReward é o múltiplo do SL
                    tp = lastClose + MathAbs(lastClose - sl) * InpTPRiskReward;
                    // Ajusta o Take Profit (tp) para múltiplo de 5 pontos
                    tp = MathRound(tp / (5 * _Point)) * (5 * _Point);
                    // Normaliza para o número correto de casas decimais
                    tp = NormalizeDouble(tp, _Digits);

                } else { //TP Dinâmico
                    // TP dinâmico: valor fixo de 1000 pontos (ajuste conforme necessário)
                    tp = lastClose + gTPMaxCross * _Point;
                }
                  
                // Executa a ordem de compra com SL e TP definidos
                BuyMarketPrice(InpMagicNumber, InpLotSize, sl, tp, comment);
            }
        }
        // Se a tendência for de baixa
        else if (isTrendDown) 
        {
            comment += "+TrendDown"; // Adiciona tendência de baixa ao comentário
            
            // Verifica a estratégia de Bollinger Bands
            if (!tradeFlag && InpUseBollinger) 
            {
                // Verifica se a abordagem de proximidade ou rompimento das bandas está habilitada
                if (InpVerifyNearBands || InpVerifyBrokenOutBands) 
                {
                    // Verifica se o preço fechou próximo da banda superior
                    bool isNearUpBand = (InpVerifyNearBands ? CheckNearUpBand(lastClose, InpMarginBands) : true);               
                    // Verifica se o preço rompeu a banda superior
                    bool isBrokenOutUp = (InpVerifyBrokenOutBands ? CheckBrokenOutUpBand(lastClose) : true);
                    
                    // Se ambas as condições forem atendidas, sinaliza uma operação
                    if (isNearUpBand && isBrokenOutUp) 
                    {
                        comment += "+Bollinger";
                        tradeFlag = true;  
                    }
                } 
                else 
                {
                    Print("O uso de Bollinger está habilitado, mas nenhuma abordagem (proximidade ou rompimento) foi selecionada.");
                }
            }
            
            // Verifica a estratégia de RSI
            if (!tradeFlag && InpUseRSI) 
            { 
                bool isRSIOverbought = CheckRSIOverBought();
                if (isRSIOverbought) 
                {
                    comment += "+RSI_OB"; // RSI sobrecomprado
                    tradeFlag = true; 
                }
            }
            
            // Verifica a estratégia de Stoch
            if (!tradeFlag && InpUseStoch) 
            {
                bool isStochSignal = CheckStochOverBought();
                if (isStochSignal) 
                {
                    comment += "+Stoch_OB"; // Stoch sobrecomprado
                    tradeFlag = true; 
                }
            }
            
            // Verifica a estratégia de MACD
            if (!tradeFlag && InpUseMACD) 
            {
                bool isMACDSignal = CheckMACDSellSignal();
                if (isMACDSignal) 
                {
                    comment += "+MACD"; // Sinal de venda do MACD
                    tradeFlag = true; 
                }
            }
            
            // Verifica a estratégia de S&R anterior
            if(!tradeFlag && InpUseRSPullback)
            {
               bool isPullbackDownTrend = CheckSRPullbackDownTrend(lastClose);
               if(isPullbackDownTrend)
               {
                   comment += "+PB"; // Sinal de venda por ser pullback de tendência de baixa
                   tradeFlag = true; 
               }
            }
            
            // Executa a ordem de venda se uma condição for atendida
            if (tradeFlag) {
                double sl = 0.0; // Stop Loss (preço absoluto)
                double tp = 0.0; // Take Profit (preço absoluto)
            
                // Cálculo do Stop Loss (SL)
                if (InpSLType == FIXED && !InpApllySLAtMaxMin) {
                    // SL fixo: InpStopLoss é o valor em pontos
                    sl = lastClose + InpStopLoss * _Point;
                } 
                
                if (InpApllySLAtMaxMin) {
                    // SL baseado no máximo anterior: InpStopLoss é o valor em pontos
                    sl = lastHigh + InpStopLoss * _Point;
                }
                  
                gStopLoss = MathAbs(lastClose - sl);
            
                // Cálculo do Take Profit (TP)
                if(InpTpType == FIXED_TP){
                    tp = lastClose - InpTakeProfit;
                } else if (InpTpType == RISK_REWARD) {                   
                    // TP baseado no risco/recompensa: InpTPRiskReward é o múltiplo do SL
                    tp = lastClose - MathAbs(lastClose - sl) * InpTPRiskReward;
                    tp = MathRound(tp / (5 * _Point)) * (5 * _Point); // Ajusta para múltiplo de 5 pontos
                    tp = NormalizeDouble(tp, _Digits); // Normaliza casas decimais
                } else { //TP dinâmico
                    // TP dinâmico: valor fixo de 1000 pontos (ajuste conforme necessário)
                    tp = lastClose - gTPMaxCross * _Point;
                }
            
                // Executa a ordem de venda com SL e TP definidos
                SellMarketPrice(InpMagicNumber, InpLotSize, sl, tp, comment);
            }
        }
    }
}

//Se está em UpTrend, então o pullback começa na resistência e encerra no suporte. Comprar no suporte.
bool CheckSRPullbackUpTrend(double lastClose) {
    // Encontrar o nível de resistência mais recente
    double priceResistenceBefore = 0.0;
    for (int i = 0; i < InpQtPeriodToAnalyze; i++) {
        double lvl = GetPriceNearSR(iHigh(_Symbol, InpTimeframe, i), InpMarginSR);
        if (lvl > 0.0 && (priceResistenceBefore == 0.0 || lvl > priceResistenceBefore)) {
            priceResistenceBefore = lvl; // Encontrar o maior nível de resistência
        }
    }

    // Encontrar o nível de suporte atual
    double priceCurrentLevel = GetPriceNearSR(lastClose, InpMarginSR);

    // Verificar se o preço está caindo da resistência em direção ao suporte
    return (priceResistenceBefore != 0.0 && priceCurrentLevel != 0.0);// && priceCurrentLevel < priceResistenceBefore);
}

// Se está em DownTrend, então o pullback começa no suporte e encerra na resistência. Comprar na resistência.
bool CheckSRPullbackDownTrend(double lastClose) {
    // Encontrar o nível de suporte mais recente
    double priceSupportBefore = 0.0;
    for (int i = 0; i < InpQtPeriodToAnalyze; i++) {
        double lvl = GetPriceNearSR(iLow(_Symbol, InpTimeframe, i), InpMarginSR);
        if (lvl > 0.0 && (priceSupportBefore == 0.0 || lvl < priceSupportBefore)) {
            priceSupportBefore = lvl; // Encontrar o menor nível de suporte
        }
    }

    // Encontrar o nível de resistência atual
    double priceCurrentLevel = GetPriceNearSR(lastClose, InpMarginSR);

    // Verificar se o preço está subindo do suporte em direção à resistência
    return (priceSupportBefore != 0.0 && priceCurrentLevel != 0.0 && priceCurrentLevel > priceSupportBefore);
}

bool CheckStochOverSold() {
   bool zone = false, cross = false;
   for(int i=0;i<InpQtPeriodToAnalyze-1;i++)
   {
     zone = bStochK[i] <= InpStochOversold && bStochD[i] <= InpStochOversold;
     cross = bStochK[i+1] < bStochD[i+1] && bStochK[i] > bStochD[i];
     if (zone && cross)
      return true;
   }
   return false;
}

bool CheckStochOverBought() {
   bool zone = false, cross = false;
   for(int i=0;i<InpQtPeriodToAnalyze-1;i++)
   {
     zone = bStochK[i] >= InpStochOverbought && bStochD[i] >= InpStochOverbought;
     cross = bStochK[i+1] > bStochD[i+1] && bStochK[i] < bStochD[i];
     if(zone && cross)
        return true;
   }
    return false;
}

bool CheckMACDBuySignal() {
    // Verifica se a MACD Line está acima da Signal Line
    bool isMACDAboveSignal = bMACD[0] > bMACDSignal[0];
    
    // Verifica se o histograma está positivo (MACD > Signal)
    bool isHistogramPositive = (bMACD[0] - bMACDSignal[0]) > 0;
    
    // Verifica se o histograma está aumentando (força crescente)
    bool isHistogramIncreasing = (bMACD[0] - bMACDSignal[0]) > (bMACD[1] - bMACDSignal[1]);
    
    // Retorna true apenas se todas as condições forem atendidas
    return isMACDAboveSignal && isHistogramPositive && isHistogramIncreasing;
}

bool CheckMACDSellSignal() {
    // Verifica se a MACD Line está abaixo da Signal Line
    bool isMACDBelowSignal = bMACD[0] < bMACDSignal[0];
    
    // Verifica se o histograma está negativo (MACD < Signal)
    bool isHistogramNegative = (bMACD[0] - bMACDSignal[0]) < 0;
    
    // Verifica se o histograma está diminuindo (força decrescente)
    bool isHistogramDecreasing = (bMACD[0] - bMACDSignal[0]) < (bMACD[1] - bMACDSignal[1]);
    
    // Retorna true apenas se todas as condições forem atendidas
    return isMACDBelowSignal && isHistogramNegative && isHistogramDecreasing;
}

bool CheckTrendUp()
{
   double _minDis = 1 + gDistanceBetweenMAs;
   if(InpUseTwoMAs)
   {
      bool trend = bMAMedium[0] > bMALong[0] * _minDis;
      //bool alpha = bMAShort[3] < bMAShort[0] && bMAMedium[3] < bMAMedium[0];
      return trend;// && alpha;
   }
   else
   {
      bool trend = bMAShort[0] > bMAMedium[0] * _minDis &&  bMAMedium[0] > bMALong[0] * _minDis;
      //bool alpha = bMAShort[3] < bMAShort[0] && bMAMedium[3] < bMAMedium[0];
      return trend;//d && alpha;
   }
}

bool CheckTrendDown()
{
   double _minDis = 1 - gDistanceBetweenMAs;
   if(InpUseTwoMAs)
   {
      bool trend = bMAMedium[0] < bMALong[0] * _minDis;
      //bool alpha = bMAShort[3] > bMAShort[0] && bMAMedium[3] > bMAMedium[0];
      return trend;// && alpha;
   }
   else
   {
      bool trend = bMAShort[0] < bMAMedium[0] * _minDis &&  bMAMedium[0] < bMALong[0] * _minDis;
      //bool alpha = bMAShort[3] > bMAShort[0] && bMAMedium[3] > bMAMedium[0];
      return trend;// && alpha;
   }
}

// Função para verificar se o preço está próximo das bandas
bool CheckNearUpBand(double closePrice, double margin) {
    if (MathAbs(closePrice - bUpperBand[0]) <= margin)
      return true;
    return false;
}

bool CheckNearDownBand(double closePrice, double margin) {
    if (MathAbs(closePrice - bLowerBand[0]) <= margin)
      return true;
    return false;
}

// Função para verificar se o preço rompeu as bandas
bool CheckBrokenOutUpBand(double closePrice) {
    return closePrice >= bUpperBand[0];
}

bool CheckBrokenOutDownBand(double closePrice) {
    return closePrice <= bLowerBand[0];
}

// Verificar sobre comprados e sobrevendidos
bool CheckRSIOverSold(){
   return bRSI[0] <= InpRSIDownLevel;
}

bool CheckRSIOverBought(){
   return bRSI[0] >= InpRSIUpLevel;
}

void PrintLvls(){
    for (int i = 0; i < ArraySize(bSrLevels); i++) // Use ArraySize() instead of .Length
    {
        Print(bSrLevels[i]);
    }
}

// Função para verificar se o preço está próximo de algum nível de suporte/resistência
bool CheckNearSR(double closePrice, double margin)
{
    for (int i = 0; i < ArraySize(bSrLevels); i++) // Use ArraySize() instead of .Length
    {
        if (MathAbs(closePrice - bSrLevels[i]) <= margin)
        {
            return true;
        }
    }
    return false;
}

// Função para verificar se o preço está próximo de algum nível de suporte/resistência: RETORNA O PREÇO DO LVL
double GetPriceNearSR(double closePrice, double margin)
{
    for (int i = 0; i < ArraySize(bSrLevels); i++) // Use ArraySize() instead of .Length
    {
        if (MathAbs(closePrice - bSrLevels[i]) <= margin)
        {
            return bSrLevels[i];
        }
    }
    return 0.0;
}



void IdentifyResSupLevels()
{
    double levels[];

    // Obter dados dos candles
    double high[], low[], close[];
    if (CopyHigh(_Symbol, InpTimeframe, 1, InpMaxCandles, high) <= 0 ||
        CopyLow(_Symbol, InpTimeframe, 1, InpMaxCandles, low) <= 0 ||
        CopyClose(_Symbol, InpTimeframe, 1, InpMaxCandles, close) <= 0)
    {
        Print("Erro ao copiar dados dos candles");
        return;
    }

    // Identificar topos e fundos
    for (int i = 1; i < InpMaxCandles - 1; i++)
    {
        if (high[i] > high[i - 1] && high[i] > high[i + 1])
        {
            if (!IsCloseLevel(high[i], levels, gMinDistance))
            {
                ArrayResize(levels, ArraySize(levels) + 1);
                levels[ArraySize(levels) - 1] = high[i];
            }
        }

        if (low[i] < low[i - 1] && low[i] < low[i + 1])
        {
            if (!IsCloseLevel(low[i], levels, gMinDistance))
            {
                ArrayResize(levels, ArraySize(levels) + 1);
                levels[ArraySize(levels) - 1] = low[i];
            }
        }
    }

    ArraySort(levels);

    double currentPrice = iClose(_Symbol, _Period, 0);
    int levelsAbove = 0, levelsBelow = 0;
    for (int i = 0; i < ArraySize(levels); i++)
    {
        if (levels[i] < currentPrice && levelsBelow < InpQtLevels / 2)
        {
            bSrLevels[levelsBelow++] = levels[i];
        }
        else if (levels[i] > currentPrice && levelsAbove < InpQtLevels / 2)
        {
            bSrLevels[InpQtLevels / 2 + levelsAbove++] = levels[i];
        }
    }
}

bool IsCloseLevel(double level, const double &levels[], double min_distance)
{
    for (int i = 0; i < ArraySize(levels); i++)
    {
        if (MathAbs(level - levels[i]) <= min_distance)
            return true;
    }
    return false;
}

// Função para calcular o TP dinâmico
void DynamicTP(int magicNumber) {
    // Verifica se há posições abertas com o magicNumber especificado
    if (PositionsTotal() == 0) return; // Nenhuma posição aberta, não faz nada

    // Itera sobre todas as posições abertas
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i); // Obtém o ticket da posição
        if (ticket <= 0) continue; // Se o ticket for inválido, pula para a próxima posição

        // Verifica se a posição pertence ao magicNumber especificado
        if (PositionGetInteger(POSITION_MAGIC) == magicNumber) {
            // Obtém o tipo da posição (BUY ou SELL)
            ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

            // Verifica o cruzamento das Médias Móveis
            bool cross = false;

            if (positionType == POSITION_TYPE_BUY) {
                // Verifica o cruzamento para posições de compra
                if (InpTpType == DYNAMIC_SM) {
                    cross = bMAShort[0] < bMAMedium[0]; // Short cruza abaixo da Medium
                } else if (InpTpType == DYNAMIC_SL) {
                    cross = bMAShort[0] < bMALong[0]; // Short cruza abaixo da Long
                } else if (InpTpType == DYNAMIC_ML) {
                    cross = bMAMedium[0] < bMALong[0]; // Medium cruza abaixo da Long
                }
            } else if (positionType == POSITION_TYPE_SELL) {
                // Verifica o cruzamento para posições de venda
                if (InpTpType == DYNAMIC_SM) {
                    cross = bMAShort[0] > bMAMedium[0]; // Short cruza acima da Medium
                } else if (InpTpType == DYNAMIC_SL) {
                    cross = bMAShort[0] > bMALong[0]; // Short cruza acima da Long
                } else if (InpTpType == DYNAMIC_ML) {
                    cross = bMAMedium[0] > bMALong[0]; // Medium cruza acima da Long
                }
            }

            // Fecha a posição se o cruzamento for detectado
            if (cross) {
                ClosePositionWithMagicNumber(magicNumber);
                Print("Posição fechada devido ao cruzamento das MAs. Ticket: ", ticket);
            }
        }
    }
}


double CalculateLotSize(double marginPerLot, double percent) {
    // Obter o valor livre (free margin) da conta
    double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    
    // Calcular 50% do valor livre
    double availableMargin = freeMargin * percent;
    
    // Calcular o tamanho do lote
    double lotSize = availableMargin / marginPerLot;
    
    // Obter os limites de tamanho de lote permitidos pelo símbolo
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    // Garantir que o tamanho do lote esteja dentro dos limites permitidos
    lotSize = MathMin(MathMax(lotSize, minLot), maxLot); // Limitar entre minLot e maxLot
    lotSize = MathRound(lotSize / lotStep) * lotStep;    // Arredondar para o múltiplo mais próximo de lotStep
    
    return lotSize;
}