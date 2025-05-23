
//+------------------------------------------------------------------+
//| Função para verificar condições de negociação                    |
//+------------------------------------------------------------------+
bool tradeSellFlag = false;
bool tradeBuyFlag = false;

void CheckForTradeADX()
{
    int maginNumber = (InpMagicNumber == 0? InpMagicNumberADX : InpMagicNumber);
   
    CopyBuffer(adxHandle, 0, 0, 3, adx);
    CopyBuffer(adxHandle, 1, 0, 3, plusDI);
    CopyBuffer(adxHandle, 2, 0, 3, minusDI);
    
    // Verificar se temos dados suficientes
    if(ArraySize(adx) < 3 || ArraySize(plusDI) < 3 || ArraySize(minusDI) < 3)
        return;
        
    if(!tradeBuyFlag && plusDI[2] < minusDI[2] && plusDI[1] > minusDI[1]) tradeBuyFlag = true;
    if(!tradeSellFlag && plusDI[2] > minusDI[2] && plusDI[1] < minusDI[1]) tradeSellFlag = true;
        
    double tp = InpTakeProfit;
    if(InpTPType == RISK_REWARD)
       tp = Rounder(InpStopLoss * InpTPRiskReward);
       
    //Print("Dados: (+)", plusDI[1], " | 1: ", adx[1], " | 2: ", adx[2], " | (-)", minusDI[1], "Diff: ", (adx[1] + InpADXStep));
    
    // Verificar condições para COMPRA
    if(plusDI[1] > adx[1] && 
       adx[2] < MathAbs(adx[1] - InpADXStep) && 
       plusDI[1] > minusDI[1] &&
       tradeBuyFlag)
    {
        tradeBuyFlag = false;
        //Print("Alta: (+)", plusDI[1], " | 1: ", adx[1], " | 2: ", adx[2], " | (-)", minusDI[1]);
        BuyMarketPoint(maginNumber, InpLotSize, InpStopLoss, tp, "ADX acelerado de alta");
    }
    
    // Verificar condições para VENDA
    else if(minusDI[1] > adx[1] && 
            adx[2] < MathAbs(adx[1] - InpADXStep) && 
            minusDI[1] > plusDI[1] &&
            tradeSellFlag)
    {
        tradeSellFlag = false;
        //Print("Baixa: (+)", plusDI[1], " | 1: ", adx[1], " | 2: ", adx[2], " | (-)", minusDI[1]);
        SellMarketPoint(maginNumber, InpLotSize, InpStopLoss, tp, "ADX acelerado de baixa");
    }
}
