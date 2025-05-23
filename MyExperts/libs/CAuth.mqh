//+------------------------------------------------------------------+
//| Struct para armazenar os dados da assinatura                     |
//+------------------------------------------------------------------+
struct SubscriptionData
{
    bool       isActive;          // Se o EA está habilitado para operar
    string     allowedSymbol;     // Símbolo permitido para operar
    string     productId;         // Identificador do EA adquirido
    datetime   expirationDate;    // Data de expiração da assinatura
    double     maxLotSize;        // Tamanho máximo do lote permitido
    bool       allowRealAccount;  // Se permite operar em conta real
    bool       allowDemoAccount;  // Se permite operar em conta demo
    int        maxOpenPositions;  // Máximo de posições abertas permitidas (sugestão adicional)
    int        version;           // Versão do EA permitida (sugestão adicional)
    string     customerName;      // Nome do cliente (sugestão adicional)
};

//+------------------------------------------------------------------+
//| Classe CAuth para verificação de assinatura                |
//+------------------------------------------------------------------+
class CAuth
{
private:
    string           m_baseUrl;          // URL base do webservice
    string           m_licenseKey;       // Chave de licença do usuário
    SubscriptionData m_subscription;    // Dados da assinatura
    bool             m_expirationWarningShown;
    
    // Função para fazer a requisição HTTP
    bool MakeHttpRequest(string &response);
    
    // Função para parsear a resposta JSON
    bool ParseResponse(const string jsonResponse);

public:
    // Construtor
    CAuth(string baseUrl, string licenseKey);

    void CheckExpirationWarning();
    
    // Verifica a assinatura no servidor
    bool CheckSubscription();
    
    // Obtém os dados da assinatura
    SubscriptionData GetSubscriptionData() const { return m_subscription; }
    
    // Verifica se o EA pode operar com os parâmetros atuais
    bool ValidateEnvironment(string currentSymbol, double currentLotSize, bool isDemoAccount);
};

//+------------------------------------------------------------------+
//| Construtor                                                       |
//+------------------------------------------------------------------+
CAuth::CAuth(string baseUrl, string licenseKey) : 
    m_baseUrl(baseUrl),
    m_licenseKey(licenseKey),
    m_expirationWarningShown(false)
{
    // Inicializa a struct com valores padrão
    m_subscription.isActive = false;
    m_subscription.allowedSymbol = "";
    m_subscription.productId = "";
    m_subscription.expirationDate = 0;
    m_subscription.maxLotSize = 0.0;
    m_subscription.allowRealAccount = false;
    m_subscription.allowDemoAccount = true;
    m_subscription.maxOpenPositions = 0;
    m_subscription.version = 0;
    m_subscription.customerName = "";
}

//+------------------------------------------------------------------+
//| Faz a requisição HTTP para o webservice                          |
//+------------------------------------------------------------------+
bool CAuth::MakeHttpRequest(string &response)
{
    string headers = "Content-Type: application/json\r\n";
    char post[], result[];
    string postData = "{\"license_key\":\"" + m_licenseKey + "\"}";
    
    StringToCharArray(postData, post, 0, StringLen(postData));
    int res = WebRequest("POST", m_baseUrl, headers, 5000, post, result, headers);
    
    if(res == -1)
    {
        Print("Error in WebRequest. Error code: ", GetLastError());
        return false;
    }
    
    response = CharArrayToString(result, 0, ArraySize(result));
    return true;
}

//+------------------------------------------------------------------+
//| Verifica a assinatura no servidor                                |
//+------------------------------------------------------------------+
bool CAuth::CheckSubscription()
{
    string response;
    
    if(!MakeHttpRequest(response))
    {
        Print("Failed to connect to the web service");
        return false;
    }
    
    if(!ParseResponse(response))
    {
        Print("Failed to parse subscription data");
        return false;
    }
    
    // Verifica se a assinatura está expirada
    if(m_subscription.expirationDate > 0 && TimeCurrent() > m_subscription.expirationDate)
    {
        m_subscription.isActive = false;
        Print("Subscription expired on ", TimeToString(m_subscription.expirationDate));
    }
    
    return m_subscription.isActive;
}

//+------------------------------------------------------------------+
//| Valida o ambiente de operação                                    |
//+------------------------------------------------------------------+
bool CAuth::ValidateEnvironment(string currentSymbol, double currentLotSize, bool isDemoAccount)
{
    // Verifica se a assinatura está ativa
    if(!m_subscription.isActive)
    {
        Print("EA is not active in subscription");
        return false;
    }
    
    // Verifica o símbolo
    if(m_subscription.allowedSymbol != "" && m_subscription.allowedSymbol != currentSymbol)
    {
        Print("Symbol not allowed. Allowed: ", m_subscription.allowedSymbol, ", Current: ", currentSymbol);
        return false;
    }
    
    // Verifica o tamanho do lote
    if(m_subscription.maxLotSize > 0 && currentLotSize > m_subscription.maxLotSize)
    {
        Print("Lot size exceeds maximum allowed. Max: ", m_subscription.maxLotSize, ", Current: ", currentLotSize);
        return false;
    }
    
    // Verifica o tipo de conta
    if(isDemoAccount && !m_subscription.allowDemoAccount)
    {
        Print("Demo account not allowed by subscription");
        return false;
    }
    
    if(!isDemoAccount && !m_subscription.allowRealAccount)
    {
        Print("Real account not allowed by subscription");
        return false;
    }
    
    // Verifica a data de expiração
    if(m_subscription.expirationDate > 0 && TimeCurrent() > m_subscription.expirationDate)
    {
        Print("Subscription expired on ", TimeToString(m_subscription.expirationDate));
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Implementação do método ParseResponse corrigido                  |
//+------------------------------------------------------------------+
bool CAuth::ParseResponse(const string jsonResponse)
{
    // Usando a abordagem de manipulação de string para parsing simples de JSON
    string response = jsonResponse;
    
    // Remove espaços e quebras de linha
    StringReplace(response, " ", "");
    StringReplace(response, "\n", "");
    StringReplace(response, "\r", "");
    StringReplace(response, "\t", "");
    
    // Extrai os valores do JSON manualmente
    m_subscription.isActive = (bool)StringToInteger(GetJsonValue(response, "active"));
    m_subscription.allowedSymbol = GetJsonValue(response, "symbol");
    m_subscription.productId = GetJsonValue(response, "id");
    m_subscription.expirationDate = (datetime)StringToInteger(GetJsonValue(response, "expiration_date"));
    m_subscription.maxLotSize = StringToDouble(GetJsonValue(response, "max_lot_size"));
    m_subscription.allowRealAccount = (bool)StringToInteger(GetJsonValue(response, "allow_real_account"));
    m_subscription.allowDemoAccount = (bool)StringToInteger(GetJsonValue(response, "allow_demo_account"));
    
    // Campos opcionais
    string temp = GetJsonValue(response, "max_open_positions");
    if(temp != "") m_subscription.maxOpenPositions = (int)StringToInteger(temp);
    
    temp = GetJsonValue(response, "version");
    if(temp != "") m_subscription.version = (int)StringToInteger(temp);
    
    temp = GetJsonValue(response, "customer_name");
    if(temp != "") m_subscription.customerName = temp;
    
    return true;
}

//+------------------------------------------------------------------+
//| Função auxiliar para extrair valores de um JSON simples          |
//+------------------------------------------------------------------+
string GetJsonValue(const string json, const string key)
{
    string pattern = "\"" + key + "\":";
    int startPos = StringFind(json, pattern);
    
    if(startPos == -1) return "";
    
    startPos += StringLen(pattern);
    int endPos = StringFind(json, ",", startPos);
    if(endPos == -1) endPos = StringFind(json, "}", startPos);
    if(endPos == -1) return "";
    
    string value = StringSubstr(json, startPos, endPos - startPos);
    
    // Remove aspas se for string
    if(StringGetCharacter(value, 0) == '"')
    {
        value = StringSubstr(value, 1, StringLen(value) - 2);
    }
    
    // Remove caracteres inválidos
    StringReplace(value, "\"", "");
    StringReplace(value, "'", "");
    StringReplace(value, "}", "");
    
    return value;
}

//+------------------------------------------------------------------+
//| Verifica e alerta sobre expiração próxima                        |
//+------------------------------------------------------------------+
void CAuth::CheckExpirationWarning()
{
    // Se já mostrou o alerta ou não há data de expiração definida
    if(m_expirationWarningShown || m_subscription.expirationDate == 0)
        return;
    
    // Calcula quantos dias faltam para expirar
    int secondsRemaining = (int)(m_subscription.expirationDate - TimeCurrent());
    int daysRemaining = secondsRemaining / (24 * 60 * 60);
    
    // Se faltam 3 dias ou menos
    if(daysRemaining <= 3 && daysRemaining >= 0)
    {
        string message = StringFormat(
            "Atenção: Sua assinatura expira em %d dia(s)! (Data: %s)\n" +
            "Por favor, renove sua assinatura para continuar usando o EA.",
            daysRemaining,
            TimeToString(m_subscription.expirationDate, TIME_DATE)
        );
        
        // Mostra alerta
        Alert(message);
        Print(message);
        
        // Marca que já mostrou o alerta para não repetir
        m_expirationWarningShown = true;
    }
}