struct EAData
{
   // Cabeçalho
   string EA_Name;
   string EA_Version;
   datetime ServerTime;
   string Symbol;
   ENUM_TIMEFRAMES Timeframe;
   int SecondsToNextCandle;
   bool IsDemoMode;

   // Performance
   double TotalProfit;
   double DailyProfit;
   double WeeklyProfit;
   double MonthlyProfit;
   int TotalTrades;
   int DailyTrades;
   int WeeklyTrades;
   int MonthlyTrades;
   int ProfitableTrades;
   int LosingTrades;

   // Estatísticas
   double WinRate;
   double ProfitFactor;
   double MaxDrawdownPercent;
   double MaxDrawdownCurrency;

   // Últimos Trades
   struct TradeHistory
   {
      datetime EntryTime;
      string Direction;
      double Profit;
      string Comment;
   };
   TradeHistory LastTrades[5]; // Array com os 5 últimos trades

   // Configurações/Limites
   double DailyLossLimit;
   double DailyLossUsed; // % ou valor
   int MaxTradesPerDay;
   int TradesExecutedToday;
   bool IsGlobalSLActive;
   bool IsGlobalTPActive;
   double GlobalSL;
   double GlobalTP;
   string TradingHours;

   // Tempo e Frequência
   double CurrentTradeDuration; // Em segundos
   datetime LastTradeTime;
   double AvgTradesPerHour;

   // Status Adicionais
   double Balance;
   double Equity;
   int Leverage;
   double CurrentSpread;
};

void CreateEAPanel(const EAData &data)
{
   //--- Configurações de design
   int panel_width = 300;
   int x = 10;          // Posição X inicial
   int y = 20;          // Posição Y inicial
   int line_height = 20; // Espaçamento entre linhas
   int section_spacing = 5; // Espaço entre seções
   
   // Cores
   color background_color = C'30,30,30';  // Cinza escuro
   color border_color = C'60,60,60';      // Cinza médio
   color text_color = clrWhite;
   color profit_color = C'0,180,0';       // Verde mais suave
   color loss_color = C'180,0,0';         // Vermelho mais suave
   color section_color = C'70,130,180';   // Azul aço
   color highlight_color = C'100,100,100';// Cinza para destaques

   //--- Limpar objetos antigos
   ObjectsDeleteAll(0, "Panel_");

   //--- Criar fundo do painel
   CreatePanelBackground("Panel_Background", x-5, y-5, panel_width, 400, background_color, border_color);
   
   //--- 1. Cabeçalho
   CreateSectionLabel("Panel_Header", x, y, panel_width-20, StringFormat("%s v%s", data.EA_Name, data.EA_Version), section_color, true);
   y += line_height;
   
   CreateLabel("Panel_SymbolInfo", x, y, StringFormat("■ %s | %s | %s", 
      data.Symbol), EnumToString(data.Timeframe), text_color);
   y += line_height;
   
   CreateLabel("Panel_ServerTime", x, y, StringFormat("■ Server: %s", 
      TimeToString(data.ServerTime, TIME_MINUTES|TIME_SECONDS)), text_color);
   y += line_height;
   
   CreateLabel("Panel_Candle", x, y, StringFormat("■ Next candle: %d sec", 
      data.SecondsToNextCandle), text_color);
   y += line_height + section_spacing;

   //--- 2. Performance (Lucro/Perda)
   CreateSectionLabel("Panel_PerfHeader", x, y, panel_width-20, "PERFORMANCE", section_color);
   y += line_height;
   
   CreateLabel("Panel_TotalProfit", x, y, StringFormat("Total: %s$%.2f (%d trades)", 
      data.TotalProfit >= 0 ? "▲ " : "▼ ", 
      MathAbs(data.TotalProfit), 
      data.TotalTrades), 
      data.TotalProfit >= 0 ? profit_color : loss_color);
   y += line_height;
   
   CreateTwoColumnLabel("Panel_Daily", x, y, "Today:", StringFormat("%s$%.2f (%d)", 
      data.DailyProfit >= 0 ? "+" : "-", MathAbs(data.DailyProfit), data.DailyTrades), 
      data.DailyProfit >= 0 ? profit_color : loss_color);
   y += line_height;
   
   CreateTwoColumnLabel("Panel_Weekly", x, y, "Weekly:", StringFormat("%s$%.2f (%d)", 
      data.WeeklyProfit >= 0 ? "+" : "-", MathAbs(data.WeeklyProfit), data.WeeklyTrades), 
      data.WeeklyProfit >= 0 ? profit_color : loss_color);
   y += line_height;
   
   CreateTwoColumnLabel("Panel_Monthly", x, y, "Monthly:", StringFormat("%s$%.2f (%d)", 
      data.MonthlyProfit >= 0 ? "+" : "-", MathAbs(data.MonthlyProfit), data.MonthlyTrades), 
      data.MonthlyProfit >= 0 ? profit_color : loss_color);
   y += line_height + section_spacing;

   //--- 3. Estatísticas
   CreateSectionLabel("Panel_StatsHeader", x, y, panel_width-20, "STATISTICS", section_color);
   y += line_height;
   
   CreateTwoColumnLabel("Panel_WinRate", x, y, "Win Rate:", StringFormat("%.1f%%", data.WinRate), 
      data.WinRate >= 50 ? profit_color : loss_color);
   y += line_height;
   
   CreateTwoColumnLabel("Panel_ProfitFactor", x, y, "Profit Factor:", StringFormat("%.2f", data.ProfitFactor), 
      data.ProfitFactor >= 1 ? profit_color : loss_color);
   y += line_height;
   
   CreateTwoColumnLabel("Panel_Drawdown", x, y, "Max DD:", StringFormat("$%.2f (%.1f%%)", 
      data.MaxDrawdownCurrency, data.MaxDrawdownPercent), text_color);
   y += line_height + section_spacing;

   //--- 4. Últimos Trades
   CreateSectionLabel("Panel_TradesHeader", x, y, panel_width-20, "LAST TRADES", section_color);
   y += line_height;
   
   for(int i = 0; i < ArraySize(data.LastTrades); i++)
   {
      string dir_arrow = data.LastTrades[i].Direction == "COMPRA" ? "▲" : "▼";
      color trade_color = data.LastTrades[i].Profit >= 0 ? profit_color : loss_color;
      
      CreateLabel(StringFormat("Panel_TradeTime%d", i), x, y, 
         TimeToString(data.LastTrades[i].EntryTime, TIME_MINUTES), highlight_color);
      
      CreateLabel(StringFormat("Panel_TradeDir%d", i), x + 50, y, dir_arrow, trade_color);
      
      CreateLabel(StringFormat("Panel_TradeProfit%d", i), x + 70, y, 
         StringFormat("$%.2f", data.LastTrades[i].Profit), trade_color);
      
      CreateLabel(StringFormat("Panel_TradeComment%d", i), x + 150, y, 
         data.LastTrades[i].Comment, text_color);
      y += line_height;
   }
   y += section_spacing;

   //--- 5. Configurações/Limites
   CreateSectionLabel("Panel_ConfigHeader", x, y, panel_width-20, "CONFIGURATION", section_color);
   y += line_height;
   
   CreateTwoColumnLabel("Panel_DailyLimit", x, y, "Daily Limit:", 
      StringFormat("%.1f%% (%.1f%%)", data.DailyLossLimit, data.DailyLossUsed), 
      data.DailyLossUsed < data.DailyLossLimit ? profit_color : loss_color);
   y += line_height;
   
   CreateTwoColumnLabel("Panel_TradesLimit", x, y, "Trades Limit:", 
      StringFormat("%d/%d", data.TradesExecutedToday, data.MaxTradesPerDay), 
      data.TradesExecutedToday < data.MaxTradesPerDay ? profit_color : loss_color);
   y += line_height;
   
   CreateTwoColumnLabel("Panel_Session", x, y, "Session:", data.TradingHours, text_color);
   y += line_height + section_spacing;

   //--- 6. Botões de Ação
   CreateButton("Panel_BtnCloseAll", x, y, panel_width-20, 25, "CLOSE ALL TRADES", clrWhite, loss_color);
   y += 30;
   CreateButton("Panel_BtnSettings", x, y, panel_width-20, 25, "EA SETTINGS", clrWhite, highlight_color);
}

//--- Funções auxiliares melhoradas
void CreatePanelBackground(const string name, int x, int y, int width, int height, color bg_color, color border_color)
{
   // Fundo
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg_color);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, border_color);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
}

void CreateSectionLabel(const string name, int x, int y, int width, const string text, color clr, bool large=false)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, large ? 10 : 8);
   ObjectSetString(0, name, OBJPROP_FONT, large ? "Arial Bold" : "Arial");
}

void CreateLabel(const string name, int x, int y, const string text, color clr, int font_size=8)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
}

void CreateTwoColumnLabel(const string prefix, int x, int y, const string leftText, const string rightText, color rightColor, int font_size=8)
{
   CreateLabel(prefix+"_Left", x, y, leftText, clrSilver, font_size);
   CreateLabel(prefix+"_Right", x + 120, y, rightText, rightColor, font_size);
}

void CreateButton(const string name, int x, int y, int width, int height, const string text, color text_color, color bg_color)
{
   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, text_color);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg_color);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrGray);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
}


static EAData eaData;
void Panel()
{    
    // 1. Informações básicas do EA e do ambiente
    eaData.EA_Name = ChartGetString(0, CHART_EXPERT_NAME);
    eaData.EA_Version = "1.0";
    eaData.ServerTime = TimeCurrent();
    eaData.Symbol = _Symbol;
    eaData.Timeframe = InpTimeframe;
    eaData.SecondsToNextCandle = PeriodSeconds(InpTimeframe) - (TimeCurrent() % PeriodSeconds(InpTimeframe));
    eaData.IsDemoMode = AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_DEMO;
    
    // 2. Processar posições e histórico de trades
    PositionTotalToPanel(eaData);
    
    // 3. Configurações do EA
    eaData.DailyLossLimit = InpDailyLossLimit;
    eaData.IsGlobalSLActive = InpMaxStopLossPoints > 0;
    eaData.IsGlobalTPActive = false;
    eaData.GlobalSL = InpMaxStopLossPoints * _Point;
    eaData.GlobalTP = 0.0;
    eaData.TradingHours = StringFormat("%02d:%02d - %02d:%02d (Fechar após %d min)", 
        InpStartHour, InpStartMinute, InpEndHour, InpEndMinute, InpCloseAfterMinutes);
    
    // 4. Informações da conta
    eaData.Balance = AccountInfoDouble(ACCOUNT_BALANCE);
    eaData.Equity = AccountInfoDouble(ACCOUNT_EQUITY);
    eaData.Leverage = AccountInfoInteger(ACCOUNT_LEVERAGE);
    eaData.CurrentSpread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
    
    CreateEAPanel(eaData);
}

void PositionTotalToPanel(EAData &data)
{
    // Zerar os contadores
    data.TotalProfit = 0;
    data.DailyProfit = 0;
    data.WeeklyProfit = 0;
    data.MonthlyProfit = 0;
    data.TotalTrades = 0;
    data.DailyTrades = 0;
    data.WeeklyTrades = 0;
    data.MonthlyTrades = 0;
    data.ProfitableTrades = 0;
    data.LosingTrades = 0;
    data.TradesExecutedToday = 0;
    
    double totalProfit = 0;
    double totalLoss = 0;
    double maxDrawdown = 0;
    double peakEquity = 0;
    datetime lastTradeTime = 0;
    
    // Processar histórico de trades
    HistorySelect(0, TimeCurrent());
    int totalDeals = HistoryDealsTotal();
    
    // Array para armazenar os últimos 5 trades
    int lastTradeCount = 0;
    
    for(int i = totalDeals-1; i >= 0 && lastTradeCount < 5; i--)
    {
        ulong ticket = HistoryDealGetTicket(i);
        if(ticket > 0)
        {
            datetime dealTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            string comment = HistoryDealGetString(ticket, DEAL_COMMENT);
            string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
            
            if(symbol == _Symbol) // Considerar apenas trades do símbolo atual
            {
                // Preencher os últimos 5 trades
                if(lastTradeCount < 5)
                {
                    data.LastTrades[lastTradeCount].EntryTime = dealTime;
                    data.LastTrades[lastTradeCount].Direction = HistoryDealGetInteger(ticket, DEAL_TYPE) == DEAL_TYPE_BUY ? "COMPRA" : "VENDA";
                    data.LastTrades[lastTradeCount].Profit = profit;
                    data.LastTrades[lastTradeCount].Comment = comment;
                    lastTradeCount++;
                }
                
                // Atualizar último trade
                if(dealTime > lastTradeTime)
                {
                    lastTradeTime = dealTime;
                    data.LastTradeTime = lastTradeTime;
                }
                
                // Cálculos de performance
                data.TotalProfit += profit;
                data.TotalTrades++;
                
                if(profit > 0)
                {
                    data.ProfitableTrades++;
                    totalProfit += profit;
                }
                else
                {
                    data.LosingTrades++;
                    totalLoss += MathAbs(profit);
                }
                
                // Períodos específicos
                if(TimeCurrent() - dealTime < 86400) // Diário
                {
                    data.DailyProfit += profit;
                    data.DailyTrades++;
                    data.TradesExecutedToday++;
                }
                
                if(TimeCurrent() - dealTime < 604800) // Semanal
                {
                    data.WeeklyProfit += profit;
                    data.WeeklyTrades++;
                }
                
                MqlDateTime currentTime, dealTimeStruct;
               TimeToStruct(TimeCurrent(), currentTime);
               TimeToStruct(dealTime, dealTimeStruct);
               
               if(currentTime.year == dealTimeStruct.year && 
                  currentTime.mon == dealTimeStruct.mon) // Mensal
               {
                   data.MonthlyProfit += profit;
                   data.MonthlyTrades++;
               }
            }
        }
    }
    
    // Calcular estatísticas
    if(data.TotalTrades > 0)
    {
        data.WinRate = (double)data.ProfitableTrades / data.TotalTrades * 100;
        data.ProfitFactor = totalLoss > 0 ? totalProfit / totalLoss : 0;
    }
    
    // Calcular drawdown
    if(data.Equity > peakEquity)
    {
        peakEquity = data.Equity;
    }
    else
    {
        double drawdown = peakEquity - data.Equity;
        if(drawdown > maxDrawdown)
        {
            maxDrawdown = drawdown;
            data.MaxDrawdownCurrency = maxDrawdown;
            data.MaxDrawdownPercent = peakEquity > 0 ? (maxDrawdown / peakEquity) * 100 : 0;
        }
    }
    
    // Calcular tempo de operação aberto
    if(PositionsTotal() > 0)
    {
        PositionSelect(_Symbol);
        data.CurrentTradeDuration = TimeCurrent() - PositionGetInteger(POSITION_TIME);
    }
    
    // Calcular DailyLossUsed
    if(data.DailyLossLimit > 0)
    {
        data.DailyLossUsed = (data.Balance - data.Equity) / data.Balance * 100;
    }
    
    // Calcular média de trades por hora
    if(data.TotalTrades > 0)
    {
        double hoursRunning = (TimeCurrent() - data.LastTradeTime) / 3600.0;
        data.AvgTradesPerHour = hoursRunning > 0 ? data.TotalTrades / hoursRunning : 0;
    }
}