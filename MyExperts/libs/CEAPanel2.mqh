//+------------------------------------------------------------------+
//|                                                     CEAPanel.mqh |
//|                                                    Danne Pereira |
//|                                             https://www.aipi.com |
//+------------------------------------------------------------------+
#property copyright "Danne Pereira"
#property link      "https://www.aipi.com"
#property version   "1.02"

#include <Controls\WndClient.mqh>
#include <Controls\Label.mqh>
#include <Controls\Button.mqh>
#include "CTradeStatistics.mqh"

// Classe principal do painel
class CEAPanel : public CWndClient
{
private:
    // Controles visuais
    CLabel m_lblHeader;             // Cabeçalho
    CLabel m_lblSymbol, m_lblTimeframe, m_lblBalance, m_lblEquity; // Ativo, timeframe e saldo
    CLabel m_lblStatsDaily, m_lblStatsWeekly, m_lblStatsMonthly; // Estatísticas detalhadas
    CLabel m_lblStatsDailyWR, m_lblStatsWeeklyWR, m_lblStatsMonthlyWR; // Estatísticas detalhadas
    CLabel m_lblServerTime, m_lblNextCandle;          // Informações de tempo
    CLabel m_statsMonthly, m_payoffMonthly;
    CLabel m_lblTradeInfo, m_lblTradeDuration, m_lblTradeProfit; // Trade ativo
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
    CWndClient m_background;
    color GetColor(double value);
    
    void DestroyAllControls()
    {
        // Lista de todos os controles a serem removidos
        CLabel* labels[] = { 
            &m_lblHeader, &m_lblSymbol, &m_lblTimeframe, 
            &m_lblBalance, &m_lblEquity, &m_lblStatsDaily, 
            &m_lblStatsWeekly, &m_lblStatsMonthly, &m_lblServerTime, 
            &m_lblNextCandle, &m_lblTradeInfo, &m_lblTradeDuration, 
            &m_lblTradeProfit, &m_statsMonthly, &m_payoffMonthly 
        };
    
        // Remove todos os labels
        for(int i = 0; i < ArraySize(labels); i++) 
        {
            if(labels[i].Id() > 0) 
            {
                labels[i].Destroy();
            }
        }
    
        // Remove o botão (se existir)
        if(m_btnCloseTrade.Id() > 0) 
        {
            m_btnCloseTrade.Destroy();
        }
        
        if(m_background.Id() > 0) 
        {
            m_background.Destroy();
            Print("Background removido");
        }
        else
        {
            Print("Falha ao remover Background");
        }
    }

public:
    
    CTradeStatistics *stats;
    
    void CloseAllTrades(int magicNumber);
    void UpdateTradeInfo();
    void UpdateTimeInfo();
    void UpdateBalanceStats();
    void UpdateData();
    void SyncAndUpdate();
    
    CEAPanel(int magicNumber, string symbol, ENUM_TIMEFRAMES timeframe) :
        m_magicNumber(magicNumber), m_symbol(symbol), m_timeframe(timeframe),
        m_textColor(clrWhite), m_profitColor(clrGreenYellow), m_lossColor(clrTomato), m_bgColor(clrBlack), m_fontSize(9)
    {
        stats = new CTradeStatistics(magicNumber);
        SyncAndUpdate(); 
    }

    ~CEAPanel() 
    { 
        DestroyAllControls();
        delete stats; 
    }

    // Função auxiliar para configurar um label
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
        if(!CWndClient::Create(chart, name, subwin, x1, y1, x2, y2))
            return false;
            
        // Criar área de fundo colorida
        if(!m_background.Create(chart, name + "Bg", subwin, x1, y1, x2, y2))
            return false;
            
        m_background.ColorBackground(m_bgColor);
        m_background.ColorBorder(clrGoldenrod);

        int y = 10, x = 10;
        int lineHeight = (int)(m_fontSize * 1.9);
        int sectionGap = (int)(m_fontSize * 0.9);

        // ** Cabeçalho **
        if(!m_lblHeader.Create(chart, "lblHeader", subwin, x, y, x2 - 10, y + lineHeight))
            return false;
        ConfigureLabel(m_lblHeader, ChartGetString(0, CHART_EXPERT_NAME), m_fontSize + 4, clrBlue);
        m_lblHeader.Shift(x, y);
        y += lineHeight + sectionGap + 5;

        // ** Informações do ativo **
        if(!m_lblSymbol.Create(chart, "lblSymbol", subwin, x, y, x + 200, y + lineHeight))
            return false;
        ConfigureLabel(m_lblSymbol, "Símbolo: " + m_symbol, m_fontSize, m_textColor);
        m_lblSymbol.Shift(x, y);

        if(!m_lblTimeframe.Create(chart, "lblTimeframe", subwin, x + 200, y, x, y + lineHeight))
            return false;
        ConfigureLabel(m_lblTimeframe, "Timeframe: " + TimeframeToString(m_timeframe), m_fontSize, m_textColor);
        m_lblTimeframe.Shift(x + 200, y);
        y += lineHeight;
        
        
        if (!m_lblNextCandle.Create(m_chart_id, "lblNextCandle", m_subwin, x + 200, y, x, y + lineHeight))
            return false;
        ConfigureLabel(m_lblNextCandle, "Próx. Candle: 00:10", m_fontSize, m_textColor);
        Add(m_lblNextCandle);
        y += lineHeight + sectionGap;
        
        // ** Estatísticas detalhadas **
        if (!m_lblStatsDaily.Create(m_chart_id, "lblStatsDaily", m_subwin, x, y, x + 400, y + lineHeight))
            return false;
        ConfigureLabel(m_lblStatsDaily, "Diário: R$ 0.00", m_fontSize, m_textColor);
        Add(m_lblStatsDaily);
       
        if (!m_lblStatsDailyWR.Create(m_chart_id, "lblStatsDailyWR", m_subwin, x + 200, y, x, y + lineHeight))
            return false;
        ConfigureLabel(m_lblStatsDailyWR, "Acerto: 0/00 (0.00%)", m_fontSize, m_textColor);
        Add(m_lblStatsDailyWR);
        y += lineHeight;

        if (!m_lblStatsWeekly.Create(m_chart_id, "lblStatsWeekly", m_subwin, x, y, x + 400, y + lineHeight))
            return false;
        ConfigureLabel(m_lblStatsWeekly, "Semanal: R$ 0.00", m_fontSize, m_textColor);
        Add(m_lblStatsWeekly);
        
        if (!m_lblStatsWeeklyWR.Create(m_chart_id, "lblStatsWeeklyWR", m_subwin, x + 200, y, x, y + lineHeight))
            return false;
        ConfigureLabel(m_lblStatsWeeklyWR, "Acerto: 0/00 (0.00%)", m_fontSize, m_textColor);
        Add(m_lblStatsWeeklyWR);
        y += lineHeight;

        if (!m_lblStatsMonthly.Create(m_chart_id, "lblStatsMonthly", m_subwin, x, y, x + 400, y + lineHeight))
            return false;
        ConfigureLabel(m_lblStatsMonthly, "Mensal: R$ 0.00", m_fontSize, m_textColor);
        Add(m_lblStatsMonthly);
        
        if (!m_lblStatsMonthlyWR.Create(m_chart_id, "lblStatsMonthlyWR", m_subwin, x + 200, y, x, y + lineHeight))
            return false;
        ConfigureLabel(m_lblStatsMonthlyWR, "Acerto: 0/00 (0.00%)", m_fontSize, m_textColor);
        Add(m_lblStatsMonthlyWR);
        y += lineHeight;
        
        if (!m_statsMonthly.Create(m_chart_id, "m_statsMonthly", m_subwin, x, y, x + 400, y + lineHeight))
            return false;
        ConfigureLabel(m_statsMonthly, "F. Lucro/Mês: 0.00", m_fontSize, m_textColor);
        Add(m_statsMonthly);
        
        if (!m_payoffMonthly.Create(m_chart_id, "m_payoffMonthly", m_subwin, x + 200, y, x, y + lineHeight))
            return false;
        ConfigureLabel(m_payoffMonthly, "Payoff/Mês: R$ 00.00", m_fontSize, m_textColor);
        Add(m_payoffMonthly);
        
        y += lineHeight + sectionGap;

        // ** Informações de trade ativo **
        if (!m_lblBalance.Create(m_chart_id, "lblBalance", m_subwin, x, y, x2 - 10, y + lineHeight))
            return false;
        ConfigureLabel(m_lblBalance, "Saldo: R$ 0.00", m_fontSize, m_textColor);
        Add(m_lblBalance);
         
        if (!m_lblEquity.Create(m_chart_id, "lblEquity", m_subwin, x + 200, y, x2 - 10, y + lineHeight))
            return false;
        ConfigureLabel(m_lblEquity, " Margem: R$ 0.00", m_fontSize, m_textColor);
        Add(m_lblEquity);

        y += lineHeight;
        
        if (!m_lblTradeInfo.Create(m_chart_id, "lblTradeInfo", m_subwin, x, y, x + 400, y + lineHeight))
            return false;
        ConfigureLabel(m_lblTradeInfo, "Trade Ativo: Nenhum", m_fontSize, m_textColor);
        Add(m_lblTradeInfo);
        y += lineHeight;

        if (!m_lblTradeProfit.Create(m_chart_id, "lblTradeProfit", m_subwin, x, y, x + 400, y + lineHeight))
            return false;
        ConfigureLabel(m_lblTradeProfit, "Profit: R$ 0.00", m_fontSize, m_textColor);
        Add(m_lblTradeProfit);
        
        if (!m_lblTradeDuration.Create(m_chart_id, "lblTradeDuration", m_subwin, x + 200, y, x, y + lineHeight))
            return false;
        ConfigureLabel(m_lblTradeDuration, StringFormat("Duração: %02d:%02d", 0, 0), m_fontSize, m_textColor);
        Add(m_lblTradeDuration);
        
        y += lineHeight + sectionGap;

        // ** Botão para fechar posição **
        if(!m_btnCloseTrade.Create(chart, "btnCloseTrade", subwin, x, y, x + 380, y + lineHeight + 10))
            return false;
        m_btnCloseTrade.Text("Fechar Posição");
        m_btnCloseTrade.Shift(x, y);

        return true;
    }

    virtual bool OnEvent(const int id, const long& lparam, const double& dparam, const string& sparam)
    {
        if(id == CHARTEVENT_OBJECT_CLICK)
        {
            if(sparam == "btnCloseTrade")
            {
                Print("Fechando todas as posições.");
                CloseAllTrades(m_magicNumber);
                return true;
            }
        }
        else if(id == CHARTEVENT_CHART_CHANGE)
        {
            if(!ChartGetInteger(0, CHART_IS_MINIMIZED)) 
            {
                // Redimensionar controles se necessário
            }
        }
        
        return CWndClient::OnEvent(id, lparam, dparam, sparam);
    }

};


    void CEAPanel::CloseAllTrades(int magicNumber)
    {
       // Fecha todas as posições abertas com o magic number especificado
        for(int i = PositionsTotal()-1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket <= 0) continue;
            
            // Verifica o magic number da posição
            if(PositionGetInteger(POSITION_MAGIC) != magicNumber)
                continue;
                
            // Prepara a estrutura para fechamento
            MqlTradeRequest request;
            ZeroMemory(request);
            
            request.action = TRADE_ACTION_DEAL;
            request.position = ticket;
            request.symbol = PositionGetString(POSITION_SYMBOL);
            request.volume = PositionGetDouble(POSITION_VOLUME);
            request.deviation = 5;
            request.magic = magicNumber;
            
            // Determina a direção do fechamento
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
            
            // Envia a ordem de fechamento
            MqlTradeResult result;
            if(!OrderSend(request, result)) Print("Falha ao enviar uma ordem de fechamento de posição!");
            
            // Log do resultado
            if(result.retcode == TRADE_RETCODE_DONE)
            {
                Print("Posição fechada com sucesso. Ticket: ", ticket);
            }
            else
            {
                Print("Falha ao fechar posição. Ticket: ", ticket, 
                      " Código de erro: ", result.retcode);
            }
        }
        SyncAndUpdate();
    }

    void CEAPanel::SyncAndUpdate()
    {
        stats.SyncWithHistory();
        UpdateData();
    }

    void CEAPanel::UpdateTimeInfo()
    {
        datetime serverTime = TimeCurrent();
        string timeStr = TimeToString(serverTime, TIME_SECONDS);

        // Calcula tempo restante para o próximo candle
        int tfSeconds = PeriodSeconds(m_timeframe);
        datetime nextCandleTime = iTime(m_symbol, m_timeframe, 0) + tfSeconds;
        int remainingSec = int(nextCandleTime - serverTime);
        string nextCandleStr = TimeToString(nextCandleTime, TIME_SECONDS);

        m_lblServerTime.Text("Horário: " + timeStr);
        m_lblNextCandle.Text("Próx. Candle: " + IntegerToString(remainingSec) + "s");
    }

    void CEAPanel::UpdateBalanceStats()
    {
        double balance = AccountInfoDouble(ACCOUNT_BALANCE);
        double equity = AccountInfoDouble(ACCOUNT_EQUITY);

        string _balance = StringFormat("Saldo: R$ %.2f", balance);
        string _equity = StringFormat("Margem: R$ %.2f", equity);

        m_lblBalance.Text(_balance);
        m_lblEquity.Text(_equity);
        m_lblEquity.Color((equity == balance ? m_textColor : (equity < balance ? m_lossColor : m_profitColor)));
        
        stats.SyncWithHistory();

        // Atualiza estatísticas diárias com cores
        double dailyProfit = stats.GetDailyProfit();
        m_lblStatsDaily.Text(StringFormat("Diário: R$ %.2f ", dailyProfit));
        m_lblStatsDaily.Color(GetColor(dailyProfit));
        
        // Atualiza estatísticas semanais com cores
        double weeklyProfit = stats.GetWeeklyProfit();
        m_lblStatsWeekly.Text(StringFormat("Semanal: R$ %.2f ", weeklyProfit));
        m_lblStatsWeekly.Color(GetColor(weeklyProfit));
        
        // Atualiza estatísticas mensais com cores
        double monthlyProfit = stats.GetMonthlyProfit();
        m_lblStatsMonthly.Text(StringFormat("Mensal: R$ %.2f ", monthlyProfit));
        m_lblStatsMonthly.Color(GetColor(monthlyProfit));
        
        // Atualiza fator de lucro e payoff mensal
        double monthlyProfitFactor = stats.GetProfitFactor(PERIOD_MN1);
        m_statsMonthly.Text(StringFormat("F. Lucro/Mês: %.2f", monthlyProfitFactor));
        m_statsMonthly.Color(GetColor(monthlyProfitFactor));
        
        double monthlyPayoff = stats.GetPayoff(PERIOD_MN1);
        m_payoffMonthly.Text(StringFormat("Payoff/Mês: R$ %.2f", monthlyPayoff));
        m_payoffMonthly.Color(GetColor(monthlyPayoff));

        // Atualiza taxas de acerto (mantém cor padrão)
        m_lblStatsDailyWR.Text(StringFormat("Acerto: %d/%d (%.2f%%)", stats.GetDailyWins(), stats.GetDailyTrades(), stats.GetDailyWinRate()));
        m_lblStatsWeeklyWR.Text(StringFormat("Acerto: %d/%d (%.2f%%)", stats.GetWeeklyWins(), stats.GetWeeklyTrades(), stats.GetWeeklyWinRate()));
        m_lblStatsMonthlyWR.Text(StringFormat("Acerto: %d/%d (%.2f%%)", stats.GetMonthlyWins(), stats.GetMonthlyTrades(), stats.GetMonthlyWinRate()));
    }
    
    color CEAPanel::GetColor(double value){
      if(value == 0) return m_textColor;
      return (value < 0 ? m_lossColor : m_profitColor);
    }

    void CEAPanel::UpdateTradeInfo()
    {
        bool trade_found = false;
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ulong ticket = PositionGetTicket(i);
            if(PositionGetInteger(POSITION_MAGIC) == m_magicNumber)
            {
                string symbol = PositionGetString(POSITION_SYMBOL);
                double profit = PositionGetDouble(POSITION_PROFIT);
                datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);

                int duration = (int)(TimeCurrent() - open_time);
                int min = duration / 60;
                int sec = duration % 60;

                string info = "Trade Ativo: " + symbol;
                string duration_text = StringFormat("Duração: %02d:%02d", min, sec);
                string profit_text = StringFormat("Profit: R$ %.2f", profit);

                m_lblTradeInfo.Text(info);
                m_lblTradeDuration.Text(duration_text);
                m_lblTradeProfit.Text(profit_text);
                m_lblTradeProfit.Color(profit >= 0 ? m_profitColor : m_lossColor);
                
                trade_found = true;
                break;
            }
        }

        if (!trade_found)
        {
            m_lblTradeInfo.Text("Trade Ativo: Nenhum");
            m_lblTradeDuration.Text("");
            m_lblTradeProfit.Text("Profit: R$ 0.00");
        }
    }

    void CEAPanel::UpdateData()
    {
       UpdateBalanceStats();
       UpdateTimeInfo();
       UpdateTradeInfo();
    }

    //+------------------------------------------------------------------+
    //| Converte um timeframe para string em português                   |
    //+------------------------------------------------------------------+
    string CEAPanel::TimeframeToString(ENUM_TIMEFRAMES timeframe)
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
       return "Desconhecido";
    }