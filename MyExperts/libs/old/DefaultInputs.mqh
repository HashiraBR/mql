//+------------------------------------------------------------------+
//| Inputs do Expert Advisor                                         |
//+------------------------------------------------------------------+
enum ENUM_SL_TYPE {
   FIXED_SL, //Fixo
   TRAILING, //Trailing
   PROGRESS, //Progressivo
   OPEN_PRICE_SL, //Preço de entrada quando Profit
};

enum ENUM_TP_TYPE {
   FIXED_TP, //Fixo
   RISK_REWARD, //Risco Retorno
};

input string space00_ = "==========================================================================="; // ############ Configurações Operacionais ############
// Identificação e Controle
input int      InpMagicNumber = 0;              // Número mágico (0=NM ignorado, considera NM das Estratégias)
input double   InpPipSize = 5;                  // Tamanho do PIP
input bool     InpSendEmail = true;             // Habilitar envio de e-mails
input bool     InpSendPushNotification = true;  // Habilitar envio de Push Notification
input int      InpOrderExpiration = 119;        // Tempo de expiração da ordem (em segundos)
// Configurações Técnicas
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M2; // Timeframe do gráfico
input bool     InpShowPanel = false;            // Mostrar painel do EA

input string space01_ = "==========================================================================="; // ############ Gestão de Capital ############
input double   InpDailyProfitLimit = 250.0;    // Limite diário de lucro (R$)
input double   InpDailyLossLimit = 150.0;      // Limite diário de perda (R$)
input double   InpManageCapitalLoss = 100.0;   // Limite máximo de perda por operação (R$)
input int      InpMaxConsecutiveLosses = 0;    // Número máximo de losses consecutivos permitidos (0=desativado)
input int      InpMaxTrades = 0;               // Número máximo de trades por dia permitidos (0=desativado)
input int      InpMaxOpenPositions = 0;        // Máximo de posições em aberto simultaneamente (0=desativado)
input int      InpMaxStopLossPoints = 250;     // SL máximo permitido (útil para SL dinâmicos)

input string space02_ = "==========================================================================="; // ############ Horários de operação ############
// Horário de Negociação
input int      InpStartHour = 9;               // Hora de início das negociações (formato 24h)
input int      InpStartMinute = 0;             // Minuto de início das negociações
input int      InpEndHour = 17;                // Hora de término das negociações (formato 24h)
input int      InpEndMinute = 0;               // Minuto de término das negociações
input int      InpCloseAfterMinutes = 20;      // Encerrar posições após parar de operar (minutos)

input string space03_ = "==========================================================================="; // ############ Configurações de Negociações ############
// Configurações de Negociação
input double   InpLotSize = 1.0;                      // Tamanho do lote
input ENUM_SL_TYPE InpSLType = FIXED_SL;              // Tipo de SL
input double   InpStopLoss = 100.0;                   // SL Base (em pontos)
input bool     InpStopLossFromSmootedATR = false;     // Habilitar SL a partir do ATR suavizado (True=desativa SL Base)
input int      InpAtrPeriod = 21;                     // Período para calcudo do ATR suavizado
input double   InpAtrMultiplier = 1.0;                // Multiplicador de ATR para SL
input int      InpTrailingSLStartPoint = 0;           // SL Trailing: Profit (pontos) para mover SL (0=cada tick)
input int      InpProgressSLProtectedPoints = 200;    // SL Progress: Passo dos pontos de proteção
input double   InpProgressSLPercentToProtect = 0.5;   // SL Progress: Porcentagem para proteger
input int      InpSLAtOpenProfit = 100;               // SL no preço de entrada se Profit > 0 (pontos, 0=SL Base)
input ENUM_TP_TYPE InpTPType = FIXED_TP;              // Tipo de TP
input double   InpTakeProfit = 200.0;                 // Take Profit (em pontos)
input double   InpTPRiskReward = 1.5;                 // TP com relação Risco-Retorno

input string space005 = "==========================================================================="; //===========================================================================
input string space04_ = "==========================================================================="; // ############ Configurações das Estratégias ############