//+------------------------------------------------------------------+
//|                                               CTradeAnalyzer.mqh |
//|                                                    Danne Pereira |
//|                                             https://www.aipi.com |
//+------------------------------------------------------------------+
#property copyright "Danne Pereira"
#property link      "https://www.aipi.com"
#property version   "1.00"
#include <Generic\HashMap.mqh>
#include <Arrays\ArrayDouble.mqh>
#include <Math\Stat\Math.mqh>

class CTradeAnalyzer
{
private:
    struct TradeStatistics
    {
        // Estatísticas básicas
        int total_trades;
        int profitable_trades;
        int losing_trades;
        double win_rate;
        double profit_factor;
        double gross_profit;
        double gross_loss;
        double net_profit;
        double average_profit_per_trade;
        double largest_winning_trade;
        double largest_losing_trade;
        double average_winning_trade;
        double average_losing_trade;
        double max_drawdown;
        double max_drawdown_percent;
        double recovery_factor;
        double payoff_ratio;
        
        // Estatísticas de sequências
        int max_consecutive_wins;
        int max_consecutive_losses;
        double max_consecutive_profit;
        double max_consecutive_loss;
        
        // Estatísticas de tempo
        datetime first_trade_time;
        datetime last_trade_time;
        double average_trade_duration;
        double shortest_trade_duration;
        double longest_trade_duration;
        double median_trade_duration;
        
        // Duração por tipo de resultado
        double avg_duration_winning_trades;
        double avg_duration_losing_trades;
        double median_duration_winning_trades;
        double median_duration_losing_trades;
        double top10pct_longest_duration_win_rate;
        double top10pct_longest_duration_avg_profit;
        double bottom10pct_shortest_duration_win_rate;
        double bottom10pct_shortest_duration_avg_profit;
        double duration_profit_correlation;
        
        // Estatísticas por dia da semana
        double weekday_profit[5];
        int weekday_trades[5];
        
        // Estatísticas por hora do dia
        double hourly_profit[24];
        int hourly_trades[24];
        
        // Estatísticas por tipo de trade
        double buy_profit;
        double sell_profit;
        int buy_trades;
        int sell_trades;
        
        // Estatísticas por duração
        double short_term_profit;
        double medium_term_profit;
        double long_term_profit;
        int short_term_trades;
        int medium_term_trades;
        int long_term_trades;
        
        // Estatísticas de retorno
        double sharpe_ratio;
        double sortino_ratio;
        double standard_deviation;
        double average_return;
        double risk_reward_ratio;
        
        // Outras métricas
        double k_ratio;
        double z_score;
        double expected_payoff;
        double custom_score;
    };

    TradeStatistics m_stats;
    bool m_initialized;
    datetime m_last_update_time;

    // Métodos auxiliares
    void CalculateAllStatistics();
    double CalculateCorrelation(const CArrayDouble &x, const CArrayDouble &y);
    double CalculateKRatio(const CHashMap<ulong, double> &equity_changes);
    double CalculateZScore(int total_trades, int wins, double win_rate);
    void UpdateDurationAnalysis(CArrayDouble &winning_durations, CArrayDouble &losing_durations, 
                              CArrayDouble &all_durations_sorted, const TradeStatistics &temp_stats);
    void UpdateTimeAnalysis(const datetime close_time, double profit, TradeStatistics &temp_stats);

public:
    CTradeAnalyzer() : m_initialized(false), m_last_update_time(0) {}
    
    // Método principal para atualizar estatísticas
    void UpdateStatistics(bool force_update = false);
    
    // Métodos para gerenciamento de trades baseado em estatísticas
    bool ShouldExitTrade(double current_duration, double current_profit) const;
    bool IsOptimalEntryTime() const;
    void AdjustTradeLevels(double &sl, double &tp, double position_duration) const;
    void CheckForAlerts() const;
    
    // Métodos de acesso aos dados
    const TradeStatistics& GetStats() const { return m_stats; }
    void PrintFullReport() const;
};

// Implementação dos métodos
void CTradeAnalyzer::UpdateStatistics(bool force_update)
{
    // Atualizar apenas uma vez por dia ou se forçado
    if(!force_update && m_initialized && TimeCurrent() - m_last_update_time < 86400)
        return;
    
    CalculateAllStatistics();
    m_initialized = true;
    m_last_update_time = TimeCurrent();
}

void CTradeAnalyzer::CalculateAllStatistics()
{
    TradeStatistics temp_stats = {};
    CArrayDouble winning_durations, losing_durations, all_durations, trade_returns, trade_durations;
    CHashMap<ulong, double> equity_changes;
    CHashMap<int, double> hour_profits, hour_trades;
    CHashMap<int, double> weekday_profits, weekday_trades;
    
    double max_equity_peak = 0;
    double max_equity_drawdown = 0;
    double current_equity = 0;
    
    int current_consecutive_wins = 0;
    int current_consecutive_losses = 0;
    double current_consecutive_profit = 0;
    double current_consecutive_loss = 0;
    
    HistorySelect(0, TimeCurrent());
    int total = HistoryDealsTotal();
    
    for(int i = 0; i < total; i++)
    {
        ulong ticket = HistoryDealGetTicket(i);
        if(ticket == 0) continue;
        
        double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
        double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
        double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
        double volume = HistoryDealGetDouble(ticket, DEAL_VOLUME);
        datetime close_time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
        datetime open_time = close_time;
        ENUM_DEAL_TYPE deal_type = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
        ENUM_DEAL_ENTRY deal_entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
        
        // Encontrar trade de entrada correspondente
        if(deal_entry == DEAL_ENTRY_OUT || deal_entry == DEAL_ENTRY_OUT_BY)
        {
            for(int j = i-1; j >= 0; j--)
            {
                ulong prev_ticket = HistoryDealGetTicket(j);
                if(HistoryDealGetInteger(prev_ticket, DEAL_POSITION_ID) == 
                   HistoryDealGetInteger(ticket, DEAL_POSITION_ID) &&
                   (HistoryDealGetInteger(prev_ticket, DEAL_ENTRY) == DEAL_ENTRY_IN ||
                    HistoryDealGetInteger(prev_ticket, DEAL_ENTRY) == DEAL_ENTRY_IN_BY))
                {
                    open_time = (datetime)HistoryDealGetInteger(prev_ticket, DEAL_TIME);
                    break;
                }
            }
        }
        
        double trade_duration = (close_time - open_time) / 60.0; // em minutos
        double trade_return = profit / (volume * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE));
        
        // Atualizar todas as estatísticas
        // ... (implementação completa conforme discutido anteriormente)
        
        UpdateTimeAnalysis(close_time, profit, temp_stats);
    }
    
    // Calcular estatísticas derivadas
    // ... (cálculos completos como discutido anteriormente)
    
    UpdateDurationAnalysis(winning_durations, losing_durations, all_durations, temp_stats);
    
    // Atualizar estatísticas de tempo
    for(int i = 0; i < 24; i++)
    {
        if(hour_trades.ContainsKey(i) && hour_trades[i] > 0)
        {
            temp_stats.hourly_profit[i] = hour_profits[i];
            temp_stats.hourly_trades[i] = (int)hour_trades[i];
        }
    }
    
    for(int i = 0; i < 5; i++)
    {
        if(weekday_trades.ContainsKey(i) && weekday_trades[i] > 0)
        {
            temp_stats.weekday_profit[i] = weekday_profits[i];
            temp_stats.weekday_trades[i] = (int)weekday_trades[i];
        }
    }
    
    m_stats = temp_stats;
}

bool CTradeAnalyzer::ShouldExitTrade(double current_duration, double current_profit) const
{
    // 1. Saída positiva precoce
    if(current_profit > 0 && current_duration >= m_stats.avg_duration_winning_trades * 0.8)
        return true;
    
    // 2. Corte de perdas baseado em duração
    if(current_profit < 0 && current_duration >= m_stats.median_duration_losing_trades * 1.2)
        return true;
    
    // 3. Trades anormalmente longos
    if(current_duration > m_stats.longest_trade_duration * 0.9)
        return true;
    
    // 4. Se estiver no top 10% de duração e a win rate for baixa
    if(current_duration >= m_stats.longest_trade_duration * 0.9 && 
       m_stats.top10pct_longest_duration_win_rate < 40)
        return true;
    
    return false;
}

bool CTradeAnalyzer::IsOptimalEntryTime() const
{
    MqlDateTime time_struct;
    TimeCurrent(time_struct);
    
    // Verificar se está no melhor horário
    if(m_stats.hourly_trades[m_stats.best_performing_hour] > 5 && 
       time_struct.hour == m_stats.best_performing_hour)
        return true;
    
    // Verificar se há tempo suficiente até o fechamento
    datetime market_close = StringToTime("23:59");
    double minutes_remaining = (market_close - TimeCurrent()) / 60.0;
    
    return (minutes_remaining > m_stats.avg_duration_winning_trades * 1.5);
}

void CTradeAnalyzer::AdjustTradeLevels(double &sl, double &tp, double position_duration) const
{
    // Ajustar TP/SL baseado na duração do trade
    if(position_duration > m_stats.median_duration_winning_trades)
    {
        tp *= 1.1; // Aumentar take-profit para trades de maior duração
    }
    
    if(position_duration > m_stats.avg_duration_losing_trades)
    {
        sl *= 0.9; // Reduzir stop-loss para trades que estão demorando muito
    }
}

void CTradeAnalyzer::PrintFullReport() const
{
    Print("=== Relatório Completo de Estatísticas de Trading ===");
    // ... (implementação completa do método de impressão)
}

// Exemplo de uso no EA:
CTradeAnalyzer tradeAnalyzer;

void OnTick()
{
    // Atualizar estatísticas uma vez por dia
    tradeAnalyzer.UpdateStatistics();
    
    // Gerenciar trades abertos
    if(PositionSelect(_Symbol))
    {
        datetime positionOpenTime = (datetime)PositionGetInteger(POSITION_TIME);
        double duration = (TimeCurrent() - positionOpenTime) / 60.0; // em minutos
        double profit = PositionGetDouble(POSITION_PROFIT);
        
        if(tradeAnalyzer.ShouldExitTrade(duration, profit))
        {
            trade.PositionClose(_Symbol);
        }
    }
    
    // Verificar entrada
    if(IsNewBar() && tradeAnalyzer.IsOptimalEntryTime())
    {
        // Lógica de entrada
    }
}

double OnTester()
{
    tradeAnalyzer.UpdateStatistics(true);
    tradeAnalyzer.PrintFullReport();
    return tradeAnalyzer.GetStats().custom_score;
}