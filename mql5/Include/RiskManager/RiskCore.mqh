//+------------------------------------------------------------------+
//|                                                     RiskCore.mqh |
//|                                      Copyright 2026, Allan Niñal |
//|                                  https://www.allanninal.dev/mql5 |
//+------------------------------------------------------------------+
//| Risk Position Tool: three draggable lines (entry, stop loss,     |
//| take profit) and the position size they imply.                   |
//|   Direction: a stop below the entry is a buy, above it a sell.   |
//|   Lot = risk money / loss of one lot from entry to stop, rounded |
//|   DOWN to the lot step; below the broker minimum it says so      |
//|   instead of rounding up. Loss per lot: the larger of the tick-  |
//|   value maths and the terminal's own OrderCalcProfit.            |
//|   Entry "at market" follows the ask (buy) or bid (sell) until    |
//|   the entry line is dragged; then it is a pending price.         |
//+------------------------------------------------------------------+
// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0 (see LICENSE)
#ifndef RTM_CORE_MQH
#define RTM_CORE_MQH

#define L_ENTRY "RTM_L_ENTRY"
#define L_SL    "RTM_L_SL"
#define L_TP    "RTM_L_TP"

enum ENUM_RTM_RISK
  {
   RTM_RISK_PCT_BAL=0,  // % of balance
   RTM_RISK_PCT_EQ=1,   // % of equity
   RTM_RISK_MONEY=2     // Fixed money
  };

struct RTMCalc
  {
   bool   buy;
   double entry,sl,tp;
   double stop_pts,target_pts;            // distances in points
   double risk_money;                     // what the input asks for
   double loss_per_lot;
   double lots;                           // rounded down to the step, capped at the maximum; 0 = below the minimum
   double lots_raw;
   double real_risk;                      // money lost at the stop with `lots`
   double real_risk_pct;                  // of the balance
   double reward;                         // money won at the target with `lots`
   double rr;                             // reward : risk
   double margin;                         // margin `lots` needs
   string why;                            // "" or why no lot can be given
  };

bool   g_entry_market=true;               // the entry line follows the market until it is dragged
//--- the line prices, kept in memory too: the non-visual Strategy Tester has no chart objects
double g_px_entry=0,g_px_sl=0,g_px_tp=0;

double RTMShadow(const string name)
  {
   return(name==L_ENTRY ? g_px_entry : (name==L_SL ? g_px_sl : (name==L_TP ? g_px_tp : 0)));
  }
void RTMSetShadow(const string name,const double p)
  {
   if(name==L_ENTRY) g_px_entry=p;
   else if(name==L_SL) g_px_sl=p;
   else if(name==L_TP) g_px_tp=p;
  }
//--- set a line's price on the chart (when it exists) and in memory
void RTMSetPrice(const string name,const double p)
  {
   if(ObjectFind(0,name)>=0)
      ObjectSetDouble(0,name,OBJPROP_PRICE,0,p);
   RTMSetShadow(name,p);
  }

//--- a price rounded to the symbol's tick (0 stays 0)
double RTMTickPrice(const double p)
  {
   double t=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(p<=0)
      return(0);
   return(t>0 ? NormalizeDouble(MathRound(p/t)*t,_Digits) : NormalizeDouble(p,_Digits));
  }

//--- money lost from `price` to `sl` by one lot (for any symbol)
double RTMLossPerLot(const string sym,const double price,const double sl)
  {
   double tick=SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_SIZE);
   double tv=SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tv<=0)
      tv=SymbolInfoDouble(sym,SYMBOL_TRADE_TICK_VALUE);
   double by_tick=(tick>0 ? MathAbs(price-sl)/tick : 0)*tv;
   double p=0;
   if(price!=sl && OrderCalcProfit(sl<price ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,sym,1.0,price,sl,p))
      return(MathMax(by_tick,MathAbs(p)));
   return(by_tick);
  }

//--- a line's price: the chart object when there is one (it may have been dragged), else the price in memory
double RTMLinePrice(const string name)
  {
   if(ObjectFind(0,name)>=0)
     {
      double p=ObjectGetDouble(0,name,OBJPROP_PRICE,0);
      RTMSetShadow(name,p);
      return(p);
     }
   return(RTMShadow(name));
  }

void RTMDeleteLines(void)
  {
   ObjectDelete(0,L_ENTRY); ObjectDelete(0,L_SL); ObjectDelete(0,L_TP);
   g_px_entry=0; g_px_sl=0; g_px_tp=0;
  }

void RTMLine(const string name,const double price,const color clr,const ENUM_LINE_STYLE style,const string tip)
  {
   RTMSetShadow(name,price);
   if(ObjectFind(0,name)<0)
     {
      ObjectCreate(0,name,OBJ_HLINE,0,0,price);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,true);
      ObjectSetInteger(0,name,OBJPROP_SELECTED,true);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
      ObjectSetInteger(0,name,OBJPROP_BACK,false);
     }
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_STYLE,style);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,tip);
  }

//--- place the three lines: stop `stop_atr` x ATR(14) away, target `rr` x the stop distance, direction `buy`
void RTMResetLines(const bool buy,const double stop_atr,const double rr,const color c_entry,const color c_sl,const color c_tp)
  {
   double atr=0;
   MqlRates r[];
   ArraySetAsSeries(r,true);
   int n=CopyRates(_Symbol,_Period,1,15,r);
   for(int i=0; i<n-1; i++)
      atr+=MathMax(r[i].high,r[i+1].close)-MathMin(r[i].low,r[i+1].close);
   atr=(n>1 ? atr/(n-1) : 100*_Point);
   double entry=buy ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(entry<=0)
      entry=(n>0 ? r[0].close : 0);
   double d=MathMax(stop_atr*atr,10*_Point);
   double sl=entry+(buy ? -d : d),tp=entry+(buy ? rr*d : -rr*d);
   RTMDeleteLines();
   RTMLine(L_ENTRY,entry,c_entry,STYLE_SOLID,"Entry (drag it for a pending order price)");
   RTMLine(L_SL,sl,c_sl,STYLE_DASH,"Stop loss (drag it)");
   RTMLine(L_TP,tp,c_tp,STYLE_DASH,"Take profit (drag it)");
   g_entry_market=true;
  }

//--- keep the entry line on the market price while it has not been dragged
void RTMFollowMarket(void)
  {
   if(!g_entry_market || RTMLinePrice(L_ENTRY)<=0)
      return;
   bool buy=RTMLinePrice(L_SL)<RTMLinePrice(L_ENTRY);
   double p=buy ? SymbolInfoDouble(_Symbol,SYMBOL_ASK) : SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(p>0 && MathAbs(p-RTMLinePrice(L_ENTRY))>_Point/2)
     {
      //--- the stop and target keep their distance from the entry
      double e=RTMLinePrice(L_ENTRY),s=RTMLinePrice(L_SL),t=RTMLinePrice(L_TP);
      RTMSetPrice(L_ENTRY,p);
      RTMSetPrice(L_SL,s+(p-e));
      if(t>0)
         RTMSetPrice(L_TP,t+(p-e));
     }
  }

//--- decimals of the lot step (0.01 -> 2, 0.001 -> 3, 1 -> 0)
int RTMLotDigits(void)
  {
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   int d=0;
   while(d<8 && step>0 && MathAbs(step*MathPow(10,d)-MathRound(step*MathPow(10,d)))>1e-9)
      d++;
   return(d);
  }

//--- the size the lines imply for `risk` (percent or money, per mode)
bool RTMCompute(RTMCalc &c,const ENUM_RTM_RISK mode,const double risk)
  {
   ZeroMemory(c);
   c.why="";                                          // ZeroMemory leaves a NULL string, which is not equal to ""
   //--- the prices an order is sent with (rounded to the tick), so the size is measured on the stop the broker gets
   c.entry=RTMTickPrice(RTMLinePrice(L_ENTRY));
   c.sl=RTMTickPrice(RTMLinePrice(L_SL));
   c.tp=RTMTickPrice(RTMLinePrice(L_TP));
   if(c.entry<=0 || c.sl<=0 || c.entry==c.sl)
     {
      c.why="place entry and stop";
      return(false);
     }
   c.buy=c.sl<c.entry;
   double pt=_Point>0 ? _Point : 1;
   c.stop_pts=MathAbs(c.entry-c.sl)/pt;
   c.target_pts=(c.tp>0 ? MathAbs(c.tp-c.entry)/pt : 0);
   double bal=AccountInfoDouble(ACCOUNT_BALANCE);
   c.risk_money=(mode==RTM_RISK_MONEY ? risk : (mode==RTM_RISK_PCT_EQ ? AccountInfoDouble(ACCOUNT_EQUITY) : bal)*risk/100.0);
   c.loss_per_lot=RTMLossPerLot(_Symbol,c.entry,c.sl);
   if(c.loss_per_lot<=0)
     {
      c.why="no tick value for symbol";
      return(false);
     }
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP),vmin=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double vmax=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   c.lots_raw=c.risk_money/c.loss_per_lot;
   double v=(step>0 ? MathFloor(c.lots_raw/step+1e-9)*step : c.lots_raw);
   v=NormalizeDouble(MathMin(v,vmax),8);
   if(v<vmin-1e-12)
     {
      c.lots=0;
      c.why="min lot "+DoubleToString(vmin,RTMLotDigits())+" risks "+DoubleToString(vmin*c.loss_per_lot,2);
     }
   else
      c.lots=v;
   double use=(c.lots>0 ? c.lots : vmin);
   c.real_risk=use*c.loss_per_lot;
   c.real_risk_pct=(bal>0 ? 100.0*c.real_risk/bal : 0);
   double p=0;
   if(c.tp>0 && OrderCalcProfit(c.buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,_Symbol,use,c.entry,c.tp,p))
      c.reward=p;
   c.rr=(c.stop_pts>0 && c.target_pts>0 ? c.target_pts/c.stop_pts : 0);
   double m=0;
   if(OrderCalcMargin(c.buy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL,_Symbol,use,c.entry,m))
      c.margin=m;
   if(c.lots>0 && c.margin>AccountInfoDouble(ACCOUNT_MARGIN_FREE))
      c.why="not enough free margin";
   return(c.lots>0 && c.why=="");
  }

#endif
//+------------------------------------------------------------------+
