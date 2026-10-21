# SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0 (see LICENSE)
"""Python statement of the Risk Position Tool sizing maths (RTMCompute in RiskCore.mqh), for checking its rules.

It restates the rules; it does not read a terminal. Symbol data (tick size, tick value, lot step, minimum and maximum
lot) are passed in, so any symbol can be simulated."""
import math
from dataclasses import dataclass


@dataclass
class Symbol:
    tick_size: float      # SYMBOL_TRADE_TICK_SIZE
    tick_value: float     # money one tick moves one lot, in the account currency
    vol_step: float
    vol_min: float
    vol_max: float


def tick_price(sym: Symbol, p: float) -> float:
    """A price rounded to the symbol's tick; 0 stays 0 (RTMTickPrice)."""
    if p <= 0:
        return 0.0
    return round(p / sym.tick_size) * sym.tick_size if sym.tick_size > 0 else p


def loss_per_lot(sym: Symbol, entry: float, sl: float) -> float:
    """Money lost from entry to stop by one lot, from the tick value (the tick-value branch of RTMLossPerLot)."""
    return abs(entry - sl) / sym.tick_size * sym.tick_value if sym.tick_size > 0 else 0.0


def size(sym: Symbol, entry: float, sl: float, risk_money: float):
    """Lot for `risk_money` at the stop: rounded DOWN to the lot step, capped at the maximum; below the minimum lot the
    answer is 0 with a note, never a rounded-up lot. Returns (lots, real_risk, note)."""
    entry, sl = tick_price(sym, entry), tick_price(sym, sl)
    if entry <= 0 or sl <= 0 or entry == sl:
        return 0.0, 0.0, "place entry and stop"
    lpl = loss_per_lot(sym, entry, sl)
    if lpl <= 0:
        return 0.0, 0.0, "no tick value for symbol"
    raw = risk_money / lpl
    v = math.floor(raw / sym.vol_step + 1e-9) * sym.vol_step if sym.vol_step > 0 else raw
    v = round(min(v, sym.vol_max), 8)
    if v < sym.vol_min - 1e-12:
        return 0.0, sym.vol_min * lpl, "min lot"
    return v, v * lpl, ""
