//+------------------------------------------------------------------+
//| Inputs do Expert Advisor                                         |
//+------------------------------------------------------------------+
enum ENUM_SL_TYPE {
   FIXED, //Fixo
   TRAILING, //Trailing
   PROGRESS //Progressivo
};

input string space0_ = "==========================================================================="; // #### Configurações Operacionais ####
// Identificação e Controle
input int      InpMagicNumber;                  // Número mágico para identificar as ordens do bot
input bool     InpSendEmail = true;             // Habilitar envio de e-mails
input bool     InpSendPushNotification = true;  // Habilitar envio de Push Notification
input int      InpOrderExpiration = 119;         // Tempo de expiração da ordem (em segundos)

// Horário de Negociação
input int      InpStartHour = 9;               // Hora de início das negociações (formato 24h)
input int      InpStartMinute = 0;             // Minuto de início das negociações
input int      InpEndHour = 17;                // Hora de término das negociações (formato 24h)
input int      InpEndMinute = 0;               // Minuto de término das negociações
input int      InpCloseAfterMinutes = 20;      // Encerrar posições após parar de operar (minutos)

// Configurações Técnicas
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M2; // Timeframe do gráfico

// Configurações de Negociação
input double   InpLotSize = 1.0;               // Tamanho do lote
input ENUM_SL_TYPE InpSLType = FIXED;          // Tipo de SL
input double   InpStopLoss = 100.0;            // SL Fixo (em pontos)
input int      InpTrailingSLStartPoint = 0;    // SL Trailing: Profit (pontos) para mover SL (0=cada tick)
input int      InpProgressSLProtectedPoints = 200; // SL Progress: Passo dos pontos de proteção
input double   InpProgressSLPercentToProtect = 0.5; // SL Progress: Porcentagem para proteger


input double   InpTakeProfit = 200.0;          // Take Profit (em pontos)
//input bool     InpTrailingStop = true;         // Trailing Stop Loss (true = móvel, false = fixo)

input double   InpManageCapitalLoss = 100.0;   // Prejuízo máximo (R$) por operação (Gerenciamento de Capital)
input int InpMaxConsecutiveLosses = 0; // Número máximo de losses consecutivos permitidos (0 desativado)
input int InpMaxTrades = 0; // Número máximo de trades por dia permitidos (0 desativado)
input int InpMaxOpenPositions = 2; // Máximo de posições em aberto simultaneamente