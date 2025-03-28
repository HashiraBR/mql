input int MagicNumber;                          // Número mágico para identificar as ordens do bot
input int InpOrderExpiration = 60;              // Tempo de expiração da ordem (em segundos)
input bool SendEmailBool = true;                // Habilitar envio de e-mails
input double InpLotSize = 1.0;                  // Tamanho do lote
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M2; // Timeframe
input int StartHour = 9;                        // Hora de início das negociações (formato 24h)
input int EndHour = 17;                         // Hora de término das negociações (formato 24h)
input int X_Minutes_Close = 20;                 // Encerrar posições após parar de operar (min)
input double SL = 10;                           // Stop Loss
input double TP = 20;                           // Take Profit
input bool SL_Mobile = true;                    // Tipo de SL (true = móvel, false = fixo)