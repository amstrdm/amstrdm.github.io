---
title: Is Polymarket efficient enough to trade?
subtitle: A leakage-safe test of whether prediction-market prices predict returns — and whether any edge survives costs
accent: orange
date: "2025"
status: Research — complete
stack: ["Python", "DuckDB", "Dune / SQL", "scikit-learn"]
repo: "https://github.com/amstrdm/polymarket-efficiency"
fullSource:
  label: "the full writedown (WRITEUP.md)"
  url: "https://github.com/amstrdm/polymarket-efficiency/blob/main/WRITEUP.md"
order: 2
---

The question is simple and the honest answer is a bit anticlimactic, which is
exactly why it's worth writing down. If a prediction market is efficient, two
things should hold: its prices should behave like real probabilities, and you
shouldn't be able to predict its next move from its own trading history. I tested
both — and built the whole thing so that a *positive* result couldn't just be an
artifact of look-ahead or of pretending trading is free.

The rule I kept coming back to: an edge only counts if it's still there after you
pay to trade.

The full writedown — the whole story, every number, the methodology in detail —
lives in [WRITEUP.md](https://github.com/amstrdm/polymarket-efficiency/blob/main/WRITEUP.md)
in the repo. This page is the short version.

## The data

On-chain trade history, loaded into a DuckDB / Parquet lake. The original pipeline
pulled raw order-book fills from a Goldsky subgraph; that source has since died
(the subgraph is deprecated and Polymarket's trades endpoint now 410s), so the
published results come from a 208-market sample on Dune Analytics — one outcome
token per market, hourly bars from mid-2024 to early 2025, about 149k bars.

Two things I keep attached to those numbers. First, volume on Polymarket is
brutally concentrated: across ~100k markets, the top ~5% carry roughly 80% of the
volume and the long tail is basically untradeable, so the test only looks at a
liquid "active universe."

<figure>
  <img src="/figures/polymarket-volume.png" alt="Cumulative share of trading volume across markets — a small fraction carries most of the volume" loading="lazy" />
  <figcaption>Volume concentration across markets. The tradeable universe is a thin slice at the top; most markets never have enough liquidity to matter.</figcaption>
</figure>

Second, those 208 markets were picked *after the fact* by realized volume, which
is itself a look-ahead — in the universe selection, not the model — and it biases
the sample toward decisive, heavily-traded markets (the kept side resolved YES 88%
of the time). I'd rather say that plainly than let the headline number stand on
its own.

## Test 1 — are the prices good probabilities?

One snapshot per market, 24 hours before it resolves, so each market is a single
independent forecast. The per-market Brier score comes out at **0.056**. On its
own that means nothing, so the question is: better than what?

<figure>
  <img src="/figures/polymarket-calibration.png" alt="Calibration curve — observed outcome frequency vs market price, close to the diagonal" loading="lazy" />
  <figcaption>Reliability curve: market price on the x-axis, realized outcome frequency on the y. Close to the diagonal is good. Prices run a touch above the line (slightly under-confident) but track reality well.</figcaption>
</figure>

A coin-flip baseline scores 0.25, and beating that would be easy and meaningless —
of course most favorites win. The fair comparison is the base rate (just always
predicting the 88% YES rate), which scores 0.104. Against *that*, 0.056 is a skill
score of **0.46**: the prices cut the base-rate error roughly in half. They're
genuinely informative, not just "the favorite usually wins."

## Test 2 — is the signal real, and is it tradeable?

A ridge regression on past-only microstructure features — cumulative volume, trade
count, 24-hour volatility, spread, market age, time to resolution — predicting the
next 24-hour move in log-odds.

**Is it real?** Out-of-sample correlation is about 0.107. But I'm predicting a
24-hour-ahead target every hour, so neighbouring observations overlap massively
and the naive sample size (~39k) is a lie. Clustering the standard errors by
market gives **t ≈ 4.7** across 113 markets — the signal is distinguishable from
zero.

**Is it tradeable?** A long/short top-decile backtest, paying the estimated spread
on entry *and* exit, swept from paying nothing to paying 2× the spread:

| cost × spread | mean PnL / period | Sharpe / period | 95% CI |
|---|---|---|---|
| 0× (pre-cost) | **+0.028** | **+0.24** | [+0.012, +0.044] |
| 0.5× | −0.001 | −0.01 | [−0.018, +0.015] |
| 1× (realistic) | −0.031 | −0.25 | [−0.049, −0.014] |
| 2× | −0.088 | −0.66 | [−0.108, −0.071] |

<figure>
  <img src="/figures/polymarket-equity-curve.png" alt="Cumulative long/short PnL at 0.5x, 1x and 2x the estimated spread" loading="lazy" />
  <figcaption>Cumulative long/short PnL at different cost assumptions. Pre-cost it climbs; at a realistic full spread it bleeds. The edge is real and smaller than the bid/ask spread.</figcaption>
</figure>

Before costs the edge is small but real. It breaks even around *half* the
estimated spread and loses money at the full spread. So the edge exists on paper
and it's smaller than what it costs to cross — efficient in the way that actually
matters if you're the one paying the spread.

### Ruling out the boring explanation

A pre-cost Sharpe of +0.24 per hour is high enough to be suspicious, and the usual
culprit is bid-ask bounce: last-trade prices bounce between bid and ask, which
*looks* predictable but isn't, because you'd pay the exact spread the bounce comes
from. Two standard checks, both at zero cost — entering a bar late instead of on
the signal bar, and pricing off the midpoint instead of the last trade — and the
edge survives both (Sharpe 0.24 and 0.26). So it's a genuine directional signal,
not a microstructure artifact. It stays untradeable only because it's smaller than
the spread.

## Why it's built the way it is

Most of the effort went into not fooling myself:

- Features are **past-only** — cumulative-so-far and trailing windows, nothing
  that peeks forward.
- The train/test split is **by time**, with a horizon-sized gap at the cutoff so
  the test set can't see into training.
- Trades that would be **held across resolution are dropped.**
- The spread is a soft proxy (the high−low of each hourly bar), so instead of
  betting on one cost number I **swept the cost**. If an apparent edge only lives
  at half the spread and dies at the real one, it was never an edge.

## Where it lands

A real 24-hour signal that's unprofitable after realistic costs, over prices that
are already well-calibrated. That's a duller headline than "I found an edge," and
a much more trustworthy one.
