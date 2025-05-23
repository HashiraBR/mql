//+------------------------------------------------------------------+
//|                                                     CPanelEA.mqh |
//|                                                    Danne Pereira |
//|                                             https://www.aipi.com |
//+------------------------------------------------------------------+
#property copyright "Danne Pereira"
#property link      "https://www.aipi.com"
#property version   "1.02"

#include <Controls\Dialog.mqh>
#include <Controls\Label.mqh>
#include <Controls\Button.mqh>
#include "CTradeStatistics.mqh"

// Classe principal do painel
class CPanelEA : public CAppDialog
{
private:
    // Controles visuais
    CLabel m_lblHeader;             // Cabeçalho
    CLabel m_lblSymbol, m_lblTimeframe, m_lblBalance, m_lblEquity; // Ativo, timeframe e saldo
    CLabel m_lblStatsDaily, m_lblStatsWeekly, m_lblStatsMonthly; // Estatísticas detalhadas
    CLabel m_lblStatsDailyWR, m_lblStatsWeeklyWR, m_lblStatsMonthlyWR; // Estatísticas detalhadas
    CLabel m_lblServerTime, m_lblNextCandle;          // Informações de tempo
    CLabel m_statsMonthly, m_payoffMonthly;
    CLabel m_lblTradeInfo, m_lblTradeProfit; // Trade ativo
    CLabel m_lblTradeDuration; // Adicionado para compatibilidade
    
    // Arrays para controles dinâmicos
    CLabel* m_tradeLabels[];    // Para os subtítulos dos trades
    CLabel* m_profitLabels[];   // Para os profits individuais
    CLabel* m_durationLabels[]; // Para as durações
    
    CButton m_btnCloseTrade;        // Botão para fechar posições
    int m_fontSize;
    string TimeframeToString(ENUM_TIMEFRAMES timeframe);

    // Dados
    int m_magicNumber;
    string m_symbol;
    ENUM_TIMEFRAMES m_timeframe;

    // Cores
    color m_textColor;
    color m_profitColor;
    color m_lossColor;
    color m_bgColor;
    string m_line;
    CLabel m_lblLine1, m_lblLine2, m_lblLine3;
    
    bool m_confirmClose;
    
    color GetColor(double value)
    {
        if(value == 0) return m_textColor;
        return (value < 0 ? m_lossColor : m_profitColor);
    }
    
    void DestroyAllControls()
    {
        // Lista de todos os controles a serem removidos
        CLabel* labels[] = { 
            &m_lblHeader, &m_lblSymbol, &m_lblTimeframe, 
            &m_lblBalance, &m_lblEquity, &m_lblStatsDaily, 
            &m_lblStatsWeekly, &m_lblStatsMonthly, &m_lblServerTime, 
            &m_lblNextCandle, &m_lblTradeInfo, &m_lblTradeDuration, 
            &m_lblTradeProfit, &m_statsMonthly, &m_payoffMonthly, 
            &m_lblLine1, &m_lblLine2, &m_lblLine3
        };
        
        // Remove controles dinâmicos
        ClearTradeLabels();
        
        // Remove todos os labels fixos
        for(int i = 0; i < ArraySize(labels); i++) 
        {
            if(labels[i].Id() > 0) 
            {
                labels[i].Destroy();
            }
        }
   
        // Remove o botão
        if(m_btnCloseTrade.Id() > 0) 
        {
            m_btnCloseTrade.Destroy();
        }
    }
    
    void ClearTradeLabels()
    {
        for(int i = 0; i < ArraySize(m_tradeLabels); i++)
        {
            if(CheckPointer(m_tradeLabels[i]) == POINTER_DYNAMIC)
            {
                m_tradeLabels[i].Destroy();
                delete m_tradeLabels[i];
            }
            if(CheckPointer(m_profitLabels[i]) == POINTER_DYNAMIC)
            {
                m_profitLabels[i].Destroy();
                delete m_profitLabels[i];
            }
            if(CheckPointer(m_durationLabels[i]) == POINTER_DYNAMIC)
            {
                m_durationLabels[i].Destroy();
                delete m_durationLabels[i];
            }
        }
        ArrayResize(m_tradeLabels, 0);
        ArrayResize(m_profitLabels, 0);
        ArrayResize(m_durationLabels, 0);
    }

public:
    CTradeStatistics *stats;
    
    void CloseAllTrades(int magicNumber);
    void UpdateTradeInfo();
    void UpdateTimeInfo();
    void UpdateBalanceStats();
    void UpdateData();
    void SyncAndUpdate();
    
    CPanelEA(int magicNumber, string symbol, ENUM_TIMEFRAMES timeframe) :
        m_magicNumber(magicNumber), m_symbol(symbol), m_timeframe(timeframe),
        m_textColor(clrMidnightBlue), m_profitColor(clrGreen), m_lossColor(clrTomato), 
        m_bgColor(clrBlack), m_fontSize(9), m_confirmClose(false)
    {
        m_line = "----------------------------------------------------------------";
        stats = new CTradeStatistics(magicNumber);
        SyncAndUpdate(); 
    }

    ~CPanelEA() 
    { 
        ClearTradeLabels();
        DestroyAllControls();
        delete stats; 
    }

    void ConfigureLabel(CLabel &label, const string text, const int fontSize, const color textColor, 
                       const color bgColor=clrNONE, const color borderColor=clrNONE)
    {
        label.Text(text);
        label.FontSize(fontSize);
        label.Color(textColor);
        label.ColorBackground(bgColor);
        label.ColorBorder(borderColor);
    }

    virtual bool Create(const long chart, const string name, const int subwin, const int x1, const int y1, const int x2, const int y2)
    {
        if(!CAppDialog::Create(chart, name, subwin, x1, y1, x2, y2))
            return false;

        int y = 10, x = 10;
        int lineHeight = (int)(m_fontSize * 1.9);
        int sectionGap = (int)(m_fontSize * 0.9);

        // ** Cabeçalho **
        if(!m_lblHeader.Create(m_chart_id, "lblHeader", m_subwin, x, y, x2-10, y+lineHeight))
            return false;
        ConfigureLabel(m_lblHeader, ChartGetString(0, CHART_EXPERT_NAME), m_fontSize+4, clrBlue);
        Add(m_lblHeader);
        y += lineHeight + sectionGap + 5;

        // ** Informações do ativo **
        if(!m_lblSymbol.Create(m_chart_id, "lblSymbol", m_subwin, x, y, x+200, y+lineHeight))
            return false;
        ConfigureLabel(m_lblSymbol, "Símbolo: "+m_symbol, m_fontSize, m_textColor);
        Add(m_lblSymbol);

        if(!m_lblTimeframe.Create(m_chart_id, "lblTimeframe", m_subwin, x+200, y, x, y+lineHeight))
            return false;
        ConfigureLabel(m_lblTimeframe, "Timeframe: "+TimeframeToString(m_timeframe), m_fontSize, m_textColor);
        Add(m_lblTimeframe);
        y += lineHeight;
        
        // ** Tempo do servidor e próximo candle **
        if(!m_lblServerTime.Create(m_chart_id, "lblServerTime", m_subwin, x, y, x+200, y+lineHeight))
            return false;
        ConfigureLabel(m_lblServerTime, "Horário: 00:00", m_fontSize, m_textColor);
        Add(m_lblServerTime);

        if(!m_lblNextCandle.Create(m_chart_id, "lblNextCandle", m_subwin, x+200, y, x, y+lineHeight))
            return false;
        ConfigureLabel(m_lblNextCandle, "Próx. Candle: 00:10", m_fontSize, m_textColor);
        Add(m_lblNextCandle);
        y += lineHeight + sectionGap;
        
        // Linha divisória
        if(!m_lblLine1.Create(m_chart_id, "lblLine1", m_subwin, x, y, x, y+lineHeight))
            return false;
        ConfigureLabel(m_lblLine1, m_line, m_fontSize, m_textColor);
        Add(m_lblLine1);
        y += lineHeight;
        
        // ** Estatísticas detalhadas **
        if(!m_lblStatsDaily.Create(m_chart_id, "lblStatsDaily", m_subwin, x, y, x+400, y+lineHeight))
            return false;
        ConfigureLabel(m_lblStatsDaily, "Diário: R$ 0.00", m_fontSize, m_textColor);
        Add(m_lblStatsDaily);
       
        if(!m_lblStatsDailyWR.Create(m_chart_id, "lblStatsDailyWR", m_subwin, x+200, y, x, y+lineHeight))
            return false;
        ConfigureLabel(m_lblStatsDailyWR, "Acerto: 0/00 (0.00%)", m_fontSize, m_textColor);
        Add(m_lblStatsDailyWR);
        y += lineHeight;

        if(!m_lblStatsWeekly.Create(m_chart_id, "lblStatsWeekly", m_subwin, x, y, x+400, y+lineHeight))
            return false;
        ConfigureLabel(m_lblStatsWeekly, "Semanal: R$ 0.00", m_fontSize, m_textColor);
        Add(m_lblStatsWeekly);
        
        if(!m_lblStatsWeeklyWR.Create(m_chart_id, "lblStatsWeeklyWR", m_subwin, x+200, y, x, y+lineHeight))
            return false;
        ConfigureLabel(m_lblStatsWeeklyWR, "Acerto: 0/00 (0.00%)", m_fontSize, m_textColor);
        Add(m_lblStatsWeeklyWR);
        y += lineHeight;

        if(!m_lblStatsMonthly.Create(m_chart_id, "lblStatsMonthly", m_subwin, x, y, x+400, y+lineHeight))
            return false;
        ConfigureLabel(m_lblStatsMonthly, "Mensal: R$ 0.00", m_fontSize, m_textColor);
        Add(m_lblStatsMonthly);
        
        if(!m_lblStatsMonthlyWR.Create(m_chart_id, "lblStatsMonthlyWR", m_subwin, x+200, y, x, y+lineHeight))
            return false;
        ConfigureLabel(m_lblStatsMonthlyWR, "Acerto: 0/00 (0.00%)", m_fontSize, m_textColor);
        Add(m_lblStatsMonthlyWR);
        y += lineHeight;
        
        if(!m_statsMonthly.Create(m_chart_id, "m_statsMonthly", m_subwin, x, y, x+400, y+lineHeight))
            return false;
        ConfigureLabel(m_statsMonthly, "F. Lucro/Mês: 0.00", m_fontSize, m_textColor);
        Add(m_statsMonthly);
        
        if(!m_payoffMonthly.Create(m_chart_id, "m_payoffMonthly", m_subwin, x+200, y, x, y+lineHeight))
            return false;
        ConfigureLabel(m_payoffMonthly, "Payoff/Mês: R$ 00.00", m_fontSize, m_textColor);
        Add(m_payoffMonthly);
        
        y += lineHeight + sectionGap;
        
        // Linha divisória
        if(!m_lblLine2.Create(m_chart_id, "lblLine2", m_subwin, x, y, x, y+lineHeight))
            return false;
        ConfigureLabel(m_lblLine2, m_line, m_fontSize, m_textColor);
        Add(m_lblLine2);
        y += lineHeight;

        // ** Informações de trade ativo **
        if(!m_lblBalance.Create(m_chart_id, "lblBalance", m_subwin, x, y, x2-10, y+lineHeight))
            return false;
        ConfigureLabel(m_lblBalance, "Saldo: R$ 0.00", m_fontSize, m_textColor);
        Add(m_lblBalance);
         
        if(!m_lblEquity.Create(m_chart_id, "lblEquity", m_subwin, x+200, y, x2-10, y+lineHeight))
            return false;
        ConfigureLabel(m_lblEquity, "Margem: R$ 0.00", m_fontSize, m_textColor);
        Add(m_lblEquity);
        y += lineHeight;
        
        if(!m_lblTradeInfo.Create(m_chart_id, "lblTradeInfo", m_subwin, x, y, x+400, y+lineHeight))
            return false;
        ConfigureLabel(m_lblTradeInfo, "Trades Ativos: 0", m_fontSize, m_textColor);
        Add(m_lblTradeInfo);

        if(!m_lblTradeProfit.Create(m_chart_id, "lblTradeProfit", m_subwin, x+200, y, x+400, y+lineHeight))
            return false;
        ConfigureLabel(m_lblTradeProfit, "Profit Total: R$ 0.00", m_fontSize, m_textColor);
        Add(m_lblTradeProfit);
        y += lineHeight;
        
        // Linha divisória
        if(!m_lblLine3.Create(m_chart_id, "lblLine3", m_subwin, x, y, x, y+lineHeight))
            return false;
        ConfigureLabel(m_lblLine3, m_line, m_fontSize, m_textColor);
        Add(m_lblLine3);
        y += lineHeight;

        // ** Botão para fechar posição **
        if(!m_btnCloseTrade.Create(m_chart_id, "btnCloseTrade", m_subwin, x, y, x+380, y+lineHeight+10))
            return false;
        m_btnCloseTrade.Text("Fechar Posições");
        Add(m_btnCloseTrade);
        
        return Show();
    }
    
   /* virtual void Destroy()
    {
        if(!ConfirmClose())
            return;
            
        CAppDialog::Destroy();
    }*/

    virtual bool OnEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
    {
    
        if(id == (int)CHARTEVENT_OBJECT_CLICK || id == 1000)
        {
            if(sparam == "btnCloseTrade")
            {
                Print("Fechando todas as posições.");
                CloseAllTrades(m_magicNumber);
                return true;
            }
        }
        /*if(id == 4){
        Print(CHARTEVENT_)
          //if(!ConfirmClose())
                return true; // Bloqueia o fechamento
        }*/
        
        return CAppDialog::OnEvent(id, lparam, dparam, sparam);
    }
      
   virtual void  OnClickButtonClose(){
         if(ConfirmClose()){
            ClearTradeLabels();
            DestroyAllControls();
            CAppDialog::OnClickButtonClose();
         }
   }

    
    bool ConfirmClose()
    {
        string msg = "Deseja realmente remover o EA?\n\n" +
                    "Operações abertas permanecerão ativas\n" +
                    "até que uma ação manual ocorra.";
        
        int answer = MessageBox(msg, "Confirmação", 
                              MB_YESNO|MB_ICONQUESTION|MB_TOPMOST);
        
        return (answer == IDYES);
    }

};

    void CPanelEA::CloseAllTrades(int magicNumber)
    {
        for(int i = PositionsTotal()-1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket <= 0) continue;
            
            if(PositionGetInteger(POSITION_MAGIC) != magicNumber)
                continue;
                
            MqlTradeRequest request;
            ZeroMemory(request);
            
            request.action = TRADE_ACTION_DEAL;
            request.position = ticket;
            request.symbol = PositionGetString(POSITION_SYMBOL);
            request.volume = PositionGetDouble(POSITION_VOLUME);
            request.deviation = 5;
            request.magic = magicNumber;
            
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
                request.type = ORDER_TYPE_SELL;
                request.price = SymbolInfoDouble(request.symbol, SYMBOL_BID);
            }
            else
            {
                request.type = ORDER_TYPE_BUY;
                request.price = SymbolInfoDouble(request.symbol, SYMBOL_ASK);
            }
            
            MqlTradeResult result;
            if(!OrderSend(request, result)) 
                Print("Falha ao enviar ordem de fechamento!");
            
            if(result.retcode == TRADE_RETCODE_DONE)
            {
                Print("Posição fechada. Ticket: ", ticket);
            }
            else
            {
                Print("Falha ao fechar posição. Ticket: ", ticket, " Erro: ", result.retcode);
            }
        }
        SyncAndUpdate();
    }

    void CPanelEA::SyncAndUpdate()
    {
        stats.SyncWithHistory();
        UpdateData();
    }

    void CPanelEA::UpdateTimeInfo()
    {
        datetime serverTime = TimeCurrent();
        string timeStr = TimeToString(serverTime, TIME_SECONDS);

        int tfSeconds = PeriodSeconds(m_timeframe);
        datetime nextCandleTime = iTime(m_symbol, m_timeframe, 0) + tfSeconds;
        int remainingSec = int(nextCandleTime - serverTime);

        m_lblServerTime.Text("Horário: " + timeStr);
        m_lblNextCandle.Text("Próx. Candle: " + IntegerToString(remainingSec) + "s");
    }

    void CPanelEA::UpdateBalanceStats()
    {
        double balance = AccountInfoDouble(ACCOUNT_BALANCE);
        double equity = AccountInfoDouble(ACCOUNT_EQUITY);

        m_lblBalance.Text(StringFormat("Saldo: R$ %.2f", balance));
        m_lblEquity.Text(StringFormat("Margem: R$ %.2f", equity));
        m_lblEquity.Color((equity == balance ? m_textColor : (equity < balance ? m_lossColor : m_profitColor)));
        
        stats.SyncWithHistory();

        // Atualiza estatísticas
        double dailyProfit = stats.GetDailyProfit();
        m_lblStatsDaily.Text(StringFormat("Diário: R$ %.2f", dailyProfit));
        m_lblStatsDaily.Color(GetColor(dailyProfit));
        
        double weeklyProfit = stats.GetWeeklyProfit();
        m_lblStatsWeekly.Text(StringFormat("Semanal: R$ %.2f", weeklyProfit));
        m_lblStatsWeekly.Color(GetColor(weeklyProfit));
        
        double monthlyProfit = stats.GetMonthlyProfit();
        m_lblStatsMonthly.Text(StringFormat("Mensal: R$ %.2f", monthlyProfit));
        m_lblStatsMonthly.Color(GetColor(monthlyProfit));
        
        double monthlyProfitFactor = stats.GetProfitFactor(PERIOD_MN1);
        m_statsMonthly.Text(StringFormat("F. Lucro/Mês: %.2f", monthlyProfitFactor));
        m_statsMonthly.Color((monthlyProfitFactor == 1 || monthlyProfitFactor == 0 ) ? m_textColor : (monthlyProfitFactor < 1 ? m_lossColor : m_profitColor));
        
        double monthlyPayoff = stats.GetPayoff(PERIOD_MN1);
        m_payoffMonthly.Text(StringFormat("Payoff/Mês: R$ %.2f", monthlyPayoff));
        m_payoffMonthly.Color(GetColor(monthlyPayoff));

        // Taxas de acerto
        m_lblStatsDailyWR.Text(StringFormat("Acerto: %d/%d (%.2f%%)", 
            stats.GetDailyWins(), stats.GetDailyTrades(), stats.GetDailyWinRate()));
        m_lblStatsWeeklyWR.Text(StringFormat("Acerto: %d/%d (%.2f%%)", 
            stats.GetWeeklyWins(), stats.GetWeeklyTrades(), stats.GetWeeklyWinRate()));
        m_lblStatsMonthlyWR.Text(StringFormat("Acerto: %d/%d (%.2f%%)", 
            stats.GetMonthlyWins(), stats.GetMonthlyTrades(), stats.GetMonthlyWinRate()));
    }

    void CPanelEA::UpdateTradeInfo()
    {
        int startY = 280; // Posição Y inicial para os trades
        int lineHeight = (int)(m_fontSize * 1.9);
        int sectionGap = (int)(m_fontSize * 0.9);
        int x = 10;
        
        ClearTradeLabels();

        int tradeCount = 0;
        int totalPositions = PositionsTotal();
        double totalProfit = 0;
        
        for(int i = 0; i < totalPositions; i++)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket <= 0 || PositionGetInteger(POSITION_MAGIC) != m_magicNumber)
                continue;

            // Redimensiona arrays se necessário
            if(tradeCount >= ArraySize(m_tradeLabels))
            {
                ArrayResize(m_tradeLabels, tradeCount + 1);
                ArrayResize(m_profitLabels, tradeCount + 1);
                ArrayResize(m_durationLabels, tradeCount + 1);
            }

            // Cria novos controles se necessário
            if(CheckPointer(m_tradeLabels[tradeCount]) != POINTER_DYNAMIC)
            {
                m_tradeLabels[tradeCount] = new CLabel();
                m_profitLabels[tradeCount] = new CLabel();
                m_durationLabels[tradeCount] = new CLabel();
            }

            // Obtém dados da posição
            string symbol = PositionGetString(POSITION_SYMBOL);
            string comment = PositionGetString(POSITION_COMMENT);
            double profit = PositionGetDouble(POSITION_PROFIT);
            string positionType = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? "C" : "V");
            
            totalProfit += profit;
            datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
            
            // Calcula duração
            int duration = (int)(TimeCurrent() - openTime);
            int min = duration / 60;
            int sec = duration % 60;

            // Cria/atualiza os controles
            if(!m_tradeLabels[tradeCount].Create(m_chart_id, "tradeLbl"+IntegerToString(tradeCount), m_subwin, 
               x, startY, x+300, startY+lineHeight))
                continue;
            ConfigureLabel(m_tradeLabels[tradeCount], StringFormat("#%d: [%s] %s", tradeCount+1, positionType, (comment == "" ? "Operação" : comment)), 
                          m_fontSize, m_textColor);
            Add(m_tradeLabels[tradeCount]);

            if(!m_profitLabels[tradeCount].Create(m_chart_id, "profitLbl"+IntegerToString(tradeCount), m_subwin, 
               x+28, startY+lineHeight, x+150, startY+2*lineHeight))
                continue;
            ConfigureLabel(m_profitLabels[tradeCount], StringFormat("Profit: R$ %.2f", profit), 
                          m_fontSize, GetColor(profit));
            Add(m_profitLabels[tradeCount]);

            if(!m_durationLabels[tradeCount].Create(m_chart_id, "durLbl"+IntegerToString(tradeCount), m_subwin, 
               x+200, startY+lineHeight, x+350, startY+2*lineHeight))
                continue;
            ConfigureLabel(m_durationLabels[tradeCount], StringFormat("Duração: %02d:%02d", min, sec), 
                          m_fontSize, m_textColor);
            Add(m_durationLabels[tradeCount]);

            startY += 2 * lineHeight + sectionGap;
            tradeCount++;
        }

        // Atualiza totais
        m_lblTradeInfo.Text(StringFormat("Trades Ativos: %d", tradeCount));
        m_lblTradeProfit.Text(StringFormat("Profit Total: R$ %.2f", totalProfit));
        m_lblTradeProfit.Color(GetColor(totalProfit));

        // Redimensiona arrays para o tamanho real
        ArrayResize(m_tradeLabels, tradeCount);
        ArrayResize(m_profitLabels, tradeCount);
        ArrayResize(m_durationLabels, tradeCount);
        
       // m_btnCloseTrade.Move(x+23, 305 + (totalPositions * (2 * lineHeight + sectionGap) ) );        
    }

    void CPanelEA::UpdateData()
    {
        UpdateBalanceStats();
        UpdateTimeInfo();
        UpdateTradeInfo();
    }

    string CPanelEA::TimeframeToString(ENUM_TIMEFRAMES timeframe)
    {
        switch(timeframe)
        {
            case PERIOD_M1:    return "1 Minuto";
            case PERIOD_M2:    return "2 Minutos";
            case PERIOD_M3:    return "3 Minutos";
            case PERIOD_M4:    return "4 Minutos";
            case PERIOD_M5:    return "5 Minutos";
            case PERIOD_M6:    return "6 Minutos";
            case PERIOD_M10:   return "10 Minutos";
            case PERIOD_M12:   return "12 Minutos";
            case PERIOD_M15:   return "15 Minutos";
            case PERIOD_M20:   return "20 Minutos";
            case PERIOD_M30:   return "30 Minutos";
            case PERIOD_H1:    return "1 Hora";
            case PERIOD_H2:    return "2 Horas";
            case PERIOD_H3:    return "3 Horas";
            case PERIOD_H4:    return "4 Horas";
            case PERIOD_H6:    return "6 Horas";
            case PERIOD_H8:    return "8 Horas";
            case PERIOD_H12:   return "12 Horas";
            case PERIOD_D1:    return "Diário";
            case PERIOD_W1:    return "Semanal";
            case PERIOD_MN1:   return "Mensal";
            default:          return "Desconhecido";
        }
    }