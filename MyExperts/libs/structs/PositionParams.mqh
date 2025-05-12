struct PositionParams {
    double lotSize;
    double stopLoss;
    double trailingStart;
    double breakevenProfit;
    double progressiveStep;
    double takeProfit;
    datetime openTime;
    string comment;
    double openPrice;
    ENUM_POSITION_TYPE positionType;
};