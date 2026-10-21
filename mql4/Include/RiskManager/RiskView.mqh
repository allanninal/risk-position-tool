//+------------------------------------------------------------------+
//|                                                     RiskView.mqh |
//|                                      Copyright 2026, Allan Niñal |
//|                                  https://www.allanninal.dev/mql5 |
//+------------------------------------------------------------------+
//| The setup and size rows both programs draw from RTMCompute.      |
//+------------------------------------------------------------------+
// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0 (see LICENSE)
#ifndef RTM_VIEW_MQH
#define RTM_VIEW_MQH

#include "Panel.mqh"
#include "RiskCore.mqh"

int RTMDrawSetup(const RTMCalc &c,int y,const ENUM_RTM_RISK mode,const double risk)
  {
   string cur=" "+AccountInfoString(ACCOUNT_CURRENCY);
   int d=_Digits;
   if(c.entry<=0)
      return(Row("msg",y,"Lines","press BUY or SELL",UiWarn()));
   string kind=(g_entry_market ? " at market" : ((c.buy ? c.entry<SymbolInfoDouble(_Symbol,SYMBOL_ASK) : c.entry>SymbolInfoDouble(_Symbol,SYMBOL_BID)) ? " limit" : " stop"));
   y=Row("dir",y,"Setup",(c.buy ? "BUY" : "SELL")+kind,c.buy ? UiPos() : UiNeg());
   y=Row("ent",y,"Entry",DoubleToString(c.entry,d),UiText());
   y=Row("sl",y,"Stop loss",DoubleToString(c.sl,d)+StringFormat("  %.0f pts",c.stop_pts),UiNeg());
   y=Row("tp",y,"Take profit",c.tp>0 ? DoubleToString(c.tp,d)+StringFormat("  %.0f pts",c.target_pts) : "-",UiPos());
   y=Section("s_size",y,"SIZE");
   y=Row("risk",y,"Risk asked",(mode==RTM_RISK_MONEY ? Money(risk)+cur : Pct(risk,2)+(mode==RTM_RISK_PCT_EQ ? " of equity" : " of balance")),UiText());
   y=Row("lot",y,"Lot",c.lots>0 ? DoubleToString(c.lots,RTMLotDigits()) : "-",c.lots>0 ? UiAccent() : UiWarn());
   y=Row("rr",y,"At the stop",(c.lots>0 ? "-"+Money(c.real_risk)+cur+"  "+Pct(c.real_risk_pct,2) : "-"),UiNeg());
   y=Row("rw",y,"At the target",(c.lots>0 && c.tp>0 ? "+"+Money(c.reward)+cur : "-"),UiPos());
   y=Row("ratio",y,"Reward:risk",c.rr>0 ? "1 : "+DoubleToString(c.rr,2) : "-",UiText());
   y=Row("mg",y,"Margin",c.lots>0 ? Money(c.margin)+cur : "-",UiText());
   if(c.why!="")
      y=Row("why",y,"Note",c.why,UiWarn());
   return(y);
  }

#endif
//+------------------------------------------------------------------+
