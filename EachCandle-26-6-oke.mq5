//+------------------------------------------------------------------+
//|                                                        3MACD.mq5 |
//|                                          Copyright 2023, Geraked |
//|                                       https://github.com/geraked |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, anhdz"
#property link "https://github.com/anhdxd"
#property version "1.0"
#property description "A strategy using each candle for trade"
#property description "XAU - H4"

#include <EAUtils.mqh>
#include <Trade/Trade.mqh>
#include <Trade/OrderInfo.mqh>

CTrade ExtTrade;
CPositionInfo PositionInfo;
input group "Indicator Parameters" input int MA1 = 9; // MACD1 Fast
input int MA2 = 21;                                   // MACD2 Fast

input group "General" input int SLDev = 60; // SL Deviation (Points)
input int BuffSize = 32;                    // Buffer Size

input group "Risk Management" input double Risk = 0.5; // Risk
input ENUM_RISK RiskMode = RISK_DEFAULT;               // Risk Mode
input bool IgnoreSL = false;                           // Ignore SL
input bool IgnoreTP = false;                           // Ignore TP
input bool Trail = true;                               // Trailing Stop
input double TrailingStopLevel = 50;                   // Trailing Stop Level (%) (0: Disable)
input double EquityDrawdownLimit = 0;                  // Equity Drawdown Limit (%) (0: Disable)

input group "Open Position Limit" input bool OpenNewPos = true; // Allow Opening New Position
input bool MultipleOpenPos = false;                             // Allow Having Multiple Open Positions
input double MarginLimit = 300;                                 // Margin Limit (%) (0: Disable)
input int SpreadLimit = -1;                                     // Spread Limit (Points) (-1: Disable)

input group "Auxiliary" input int Slippage = 30; // Slippage (Points)
input int TimerInterval = 30;                    // Timer Interval (Seconds)
input ulong MagicNumber = 5000;                  // Magic Number
input ENUM_FILLING Filling = FILLING_DEFAULT;    // Order Filling

GerEA ea;
datetime lastCandle;
datetime tc;

int MA1_handle, MA2_handle;
double M1[], M2[];

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool BuySignal()
{
    double in = Ask();
    double oneOpen = Open(1, Symbol(), 0);
    double oneClose = Close(1, Symbol(), 0);
    double oneHigh = High(1, Symbol(), 0);
    double oneLow = Low(1, Symbol(), 0);

    bool isCandleBuy = (oneOpen - oneClose > 0) ? false : true;

    // if not a buy candle, return false
    if (!isCandleBuy)
    {
        Print("Not a buy candle");
        return false;
    }

    // open buy position
    double avg = (oneHigh + oneLow) / 2 + MathAbs(oneHigh - oneClose)/10; // for entry
    if (Bid() <= avg)
    {
        // 10 - 20 for h1
        // H4 => 10-40, 10-60
        // 15-30 for m30 => 1000 -> 2000
        double sl = Bid() - 10; // for SL
        double tp = Bid() + 60; // for TP
        // bool res = ExtTrade.PositionOpen(_Symbol, ORDER_TYPE_BUY, 3.0,
        //                                  SymbolInfoDouble(_Symbol, ORDER_TYPE_BUY == ORDER_TYPE_SELL ? SYMBOL_BID : SYMBOL_ASK),
        //                                  sl, tp);

        ea.BuyOpen(sl, tp, false, false, "", NULL, 0.1);
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SellSignal()
{
    double oneOpen = Open(1, Symbol(), 0);
    double oneClose = Close(1, Symbol(), 0);
    double oneHigh = High(1, Symbol(), 0);
    double oneLow = Low(1, Symbol(), 0);

    bool isCandleBuy = (oneOpen - oneClose > 0) ? false : true;

    // if not a buy candle, return false
    if (isCandleBuy)
    {
        Print("Not a sell candle");
        return false;
    }

    // open buy position
    double avg = (oneHigh + oneLow) / 2; // for entry
    if (Ask() <= avg)
    {
        double sl = avg + 25; // for SL
        double tp = avg - 50; // for TP
        bool res = ExtTrade.PositionOpen(_Symbol, ORDER_TYPE_SELL, 0.5,
                                         SymbolInfoDouble(_Symbol, ORDER_TYPE_BUY == ORDER_TYPE_SELL ? SYMBOL_BID : SYMBOL_ASK),
                                         sl, tp);
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    ea.Init();
    ea.SetMagic(MagicNumber);
    //ea.risk = Risk * 0.01;
    // ea.reverse = Reverse;
    //ea.trailingStopLevel = TrailingStopLevel * 0.01;
    // ea.grid = Grid;
    // ea.gridVolMult = GridVolMult;
    //ea.gridTrailingStopLevel = GridTrailingStopLevel * 0.01;
    // ea.gridMaxLvl = GridMaxLvl;
    // ea.equityDrawdownLimit = EquityDrawdownLimit * 0.01;
    // ea.slippage = Slippage;
    // ea.news = News;
    // ea.newsImportance = NewsImportance;
    // ea.newsMinsBefore = NewsMinsBefore;
    // ea.newsMinsAfter = NewsMinsAfter;
    // ea.filling = Filling;
    //ea.riskMode = RiskMode;

    // if (RiskMode == RISK_FIXED_VOL || RiskMode == RISK_MIN_AMOUNT) ea.risk = Risk;
    // if (News) fetchCalendarFromYear(NewsStartYear);

    // MA1_handle = iMACD(NULL, 0, MA1, M1Slow, 1, PRICE_CLOSE);

    // if (M1_handle == INVALID_HANDLE || M2_handle == INVALID_HANDLE || M3_handle == INVALID_HANDLE) {
    //     Print("Runtime error = ", GetLastError());
    //     return INIT_FAILED;
    // }

    EventSetTimer(TimerInterval);
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    EventKillTimer();
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
    datetime oldTc = tc;
    tc = TimeCurrent();
    if (tc == oldTc)
        return;
    // TrallingStop();
    // if (Trail) ea.CheckForTrail();
    // if (EquityDrawdownLimit) ea.CheckForEquity();
    //  if (Grid) ea.CheckForGrid();
}

bool TrallingStop()
{
    if (PositionsTotal() > 0)
    {
        for (int index = 0; index < PositionsTotal(); index++)
        {
            /* code */

            // int index = PositionsTotal() - 1; // Lấy số thứ tự của lệnh đầu tiên trong danh sách lệnh đang mở

            if (!PositionInfo.SelectByIndex(index))
            {
                Print("Error selecting position:", GetLastError());
                return false;
            }
            double openPrice = PositionInfo.PriceOpen();
            int positionType = PositionInfo.Type();
            double oldStoploss = PositionInfo.StopLoss();
            // Lấy giá hiện tại của cặp tiền
            double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_LAST);
            if (openPrice > PositionInfo.StopLoss())
            {
                if (MathAbs(currentPrice - openPrice) >= 1.0 * MathAbs(openPrice - PositionInfo.StopLoss()))
                {
                    if (PositionInfo.Profit() > 0)
                    {
                        double newSl = openPrice;
                        double currentTP = PositionInfo.TakeProfit(); // Lấy giá trị hiện tại của Take Profit
                        ulong ticket = PositionGetTicket(index);
                        bool result = ExtTrade.PositionModify(ticket, newSl, currentTP); // Thực hiện chỉnh sửa Stop Loss

                        if (result == false)
                        {
                            // Xử lý lỗi nếu có
                            Print("Lỗi khi chỉnh sửa Stop Loss: ", GetLastError());
                            return false;
                        }
                    }
                }
            }
        }
    }
    return false;
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    if (lastCandle != Time(0))
    {
        lastCandle = Time(0);

        // if (CopyBuffer(M1_handle, 0, 0, BuffSize, M1) <= 0) return;
        // if (CopyBuffer(M2_handle, 0, 0, BuffSize, M2) <= 0) return;

        // ArraySetAsSeries(M1, true);
        // ArraySetAsSeries(M2, true);

        //if (!OpenNewPos) return;
        // if (SpreadLimit != -1 && Spread() > SpreadLimit) return;
        // if (MarginLimit && PositionsTotal() > 0 && AccountInfoDouble(ACCOUNT_MARGIN_LEVEL) < MarginLimit) return;
    if (PositionsTotal() > 0)
    {
        Print("Tralling Stop");
        TrallingStop();
        return;
    }
        if (BuySignal())
            return;
        // SellSignal();
    }
}

//+------------------------------------------------------------------+
