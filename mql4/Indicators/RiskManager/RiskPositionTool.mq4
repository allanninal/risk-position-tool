//+------------------------------------------------------------------+
//|                                             RiskPositionTool.mq4 |
//|                                      Copyright 2026, Allan Niñal |
//|                                  https://www.allanninal.dev/mql5 |
//+------------------------------------------------------------------+
//| Free indicator (MetaTrader 4 edition): a position tool. Drag the entry, stop-loss and   |
//| take-profit lines; the panel shows the lot for your risk, the    |
//| money at the stop and at the target, the reward:risk ratio and   |
//| the margin. It never places or changes an order.                 |
//| Shared code: Include/RiskManager/RiskCore.mqh, Panel.mqh.        |
//+------------------------------------------------------------------+
// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0 (see LICENSE)
#property copyright "Copyright 2026, Allan Niñal <https://www.allanninal.dev/mql5>"
#property link      "https://www.allanninal.dev/mql5"
#property version   "1.00"
#property description "Position size calculator on the chart: drag entry, stop and target lines; lot for your risk %, money at risk, reward:risk."
#property description "Calculates only: it never places or changes an order."
#property strict
#property indicator_chart_window
#property indicator_buffers 0

#include <RiskManager/RiskView.mqh>

input ENUM_RTM_RISK InpRiskMode = RTM_RISK_PCT_BAL;  // Risk measured as
input double InpRisk        = 1.0;     // Risk per trade (% or money)
input double InpStopATR     = 1.5;     // Stop distance, x ATR(14)
input double InpRR          = 2.0;     // Target, x the stop distance
input color  InpColEntry    = C'132,164,206';  // Entry line
input color  InpColSL       = C'226,124,124';  // Stop-loss line
input color  InpColTP       = C'126,192,143';  // Take-profit line
input ENUM_RPT_CORNER InpCorner = RPT_RIGHT;   // Panel position
input int    InpOffsetX     = 10;      // Panel margin from the side, px
input int    InpOffsetY     = 26;      // Panel margin from the top, px
input int    InpFontSize    = 9;       // Panel font size
input bool   InpLight       = false;   // Light colours (for white charts)

int g_panel_h=200;

void Draw(void)
  {
   RTMCalc c;
   RTMCompute(c,InpRiskMode,InpRisk);
   g_cursor=0;
   Box("bg",0,0,UI_W,g_panel_h+UI_PAD,UiBack(),UiRule());
   Box("hd",0,0,UI_W,UI_HEAD-4,g_ui_light ? C'240,241,244' : C'32,35,40',UiRule());
   Text("title",UI_PAD,5,"Risk Position Tool",UiText(),g_ui_font+1,"Segoe UI Semibold");
   int y=RTMDrawSetup(c,UI_HEAD,InpRiskMode,InpRisk);
   Button("b_buy",UI_PAD+0,y+6,70,"BUY");
   Button("b_sell",UI_PAD+78,y+6,70,"SELL");
   Button("b_mkt",UI_PAD+156,y+6,70,g_entry_market ? "MARKET" : "PENDING");
   Button("b_del",UI_PAD+234,y+6,64,"CLEAR");
   y+=30;
   if(y!=g_panel_h)
     {
      g_panel_h=y;
      CacheClear();
      Draw();
      return;
     }
   if(g_panel_dirty)
     {
      ChartRedraw();
      g_panel_dirty=false;
     }
  }

int OnInit()
  {
   if(InpRisk<=0 || InpStopATR<=0 || InpRR<0)
     {
      Print("Risk Position Tool: risk and stop distance must be above 0");
      return(INIT_PARAMETERS_INCORRECT);
     }
   g_ui_corner=InpCorner;
   g_ui_x=InpOffsetX;
   g_ui_y=InpOffsetY;
   g_ui_font=MathMax(7,MathMin(14,InpFontSize));
   g_ui_light=InpLight;
   g_entry_market=(ObjectFind(0,L_ENTRY)<0);          // lines kept from an earlier run stay where they were dragged
   EventSetMillisecondTimer(300);
   Draw();
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   EventKillTimer();
   PanelDelete();
   if(reason==REASON_REMOVE)                          // keep the lines over a timeframe change, remove them with the tool
      RTMDeleteLines();
   ChartRedraw();
  }

void OnTimer()
  {
   RTMFollowMarket();
   Draw();
  }

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
  {
   if(id==CHARTEVENT_OBJECT_DRAG && sparam==L_ENTRY)
      g_entry_market=false;
   if(id==CHARTEVENT_OBJECT_CLICK)
     {
      if(sparam==RPT_PREFIX+"b_buy" || sparam==RPT_PREFIX+"b_sell")
         RTMResetLines(sparam==RPT_PREFIX+"b_buy",InpStopATR,InpRR,InpColEntry,InpColSL,InpColTP);
      else
         if(sparam==RPT_PREFIX+"b_mkt")
            g_entry_market=!g_entry_market;
         else
            if(sparam==RPT_PREFIX+"b_del")
               RTMDeleteLines();
     }
   if(id==CHARTEVENT_OBJECT_DRAG || id==CHARTEVENT_OBJECT_CLICK)
     {
      CacheClear();
      Draw();
     }
  }

int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],const double &open[],
                const double &high[],const double &low[],const double &close[],const long &tick_volume[],
                const long &volume[],const int &spread[])
  {
   return(rates_total);
  }
//+------------------------------------------------------------------+
