---
title: Is Polymarket efficient enough to trade?
subtitle: A leakage-safe hunt for an edge — through efficiency, smart money, and following the crowd. Every version is real before costs and gone after the spread.
accent: orange
date: "2025"
status: Research — complete
stack: ["Python", "DuckDB", "Dune / SQL", "scikit-learn"]
repo: "https://github.com/amstrdm/polymarket-efficiency"
fullSource:
  label: "the full writedown (WRITEUP.md)"
  url: "https://github.com/amstrdm/polymarket-efficiency/blob/main/WRITEUP.md"
aiNote: >-
  I did the research and wrote the original notes and text myself; I used AI to
  tighten the prose on this page so it reads more smoothly. The analysis,
  decisions and conclusions are mine.
order: 2
---

People clearly make consistent money on Polymarket. So is the market actually
inefficient in a way you can exploit, or are the winners just the survivors of a
big coin-flipping contest? I wanted to answer that with data instead of vibes.

The plan was two-sided. First, is Polymarket efficient at all — because if it is,
trading it is just gambling and there's no point going further. Second, if there's
something there, find the "smart money" and see whether you can follow it. The
short version is that I tried four different ways to find an edge, every one has a
real signal *before* costs, and every one dies once you pay the spread. The rule I
kept coming back to: an edge only counts if it survives the toll of actually
trading.

This is the walkthrough. The whole story, every number, and the methodology in
detail live in [WRITEUP.md](https://github.com/amstrdm/polymarket-efficiency/blob/main/WRITEUP.md)
in the repo.

## The data (this was most of the battle)

I need every fill on every market: who traded, how much, at what price, and how the
market resolved. The original pipeline pulled raw fills from Polymarket's Goldsky
subgraph — which is now dead (deprecated after their V2 migration), as is the Data
API `/trades` endpoint (410 Gone). The data the project originally ran on simply
isn't retrievable from Polymarket's free endpoints anymore, which is its own small
finding. What saved it was Dune Analytics: decoded on-chain `OrderFilled` events
plus a market-resolution table, aggregated to hourly bars server-side. The
efficiency study runs on the top ~208 markets by volume over the 2024 election
period, about 150k hourly bars.

<figure>
  <img src="/figures/polymarket-volume.png" alt="Cumulative share of trading volume across markets — a small fraction carries most of it" loading="lazy" />
  <figcaption>Volume is brutally concentrated — a thin slice of markets carries most of it, and the long tail is untradeable. That's why the test restricts to a liquid universe. Picking that universe by realized volume is itself a look-ahead, which is why the kept side resolves YES 88% of the time; I flag it rather than hide it.</figcaption>
</figure>

## Part 1 — is it efficient?

**Are the prices good probabilities?** One snapshot per market, 24 hours before it
resolves, so each market is one independent forecast. The Brier score is 0.056. On
its own that's meaningless, so: a coin flip scores 0.25 (beating that is easy and
pointless), but the honest baseline is the base rate — just always predicting the
average outcome — which scores 0.104. Against that, 0.056 is a skill score of
**0.46**: the prices cut the base-rate error roughly in half. They're genuinely
informative, which also means beating them will be hard.

<figure>
  <img src="/figures/polymarket-calibration.png" alt="Calibration curve — observed outcome frequency vs market price, close to the diagonal" loading="lazy" />
  <figcaption>Things priced at 70% happen about 70% of the time. Close to the diagonal is good; the prices track reality well.</figcaption>
</figure>

**Can I predict the next move?** A ridge regression on past-only microstructure
features (cumulative volume, trade count, volatility, spread, age, time to
resolution) predicting the next 24-hour move. Out-of-sample correlation is ~0.107,
but I predict a 24h-ahead target every hour, so the observations overlap and the
naive sample size lies. Clustering the standard errors by market gives **t ≈ 4.7** —
the signal is real. But real and tradeable are different things. A long/short
backtest that pays the spread on entry and exit, swept across cost assumptions:

| cost × spread | Sharpe (per rebalance) |
|---|---|
| 0× (pre-cost) | **+0.24** |
| 0.5× | ≈ 0 |
| 1× (realistic) | −0.25 |
| 2× | −0.66 |

<figure>
  <img src="/figures/polymarket-equity-curve.png" alt="Cumulative long/short PnL at 0.5x, 1x and 2x the estimated spread" loading="lazy" />
  <figcaption>Pre-cost the edge climbs; at a realistic full spread it bleeds. It breaks even around half the spread. The signal is real and smaller than the bid/ask.</figcaption>
</figure>

**Isn't that just bid-ask bounce?** A pre-cost Sharpe of +0.24/hour is suspicious —
last-trade prices ping-pong between bid and ask, which looks predictable but isn't
capturable. So I re-ran it entering one bar late, and again pricing off the
midpoint instead of the last trade. Both wash out bounce by construction, and the
edge survived both (Sharpe 0.24 and 0.26). So it's a genuine directional signal,
untradeable only because it's smaller than the spread — not a microstructure
artifact. I'm glad I ran that check; "I suspected it and ruled it out" beats
asserting a conclusion.

So to a **price-taker**, Polymarket is efficient. Clean negative result — and with
this little machinery, a negative result is more believable than an edge would be.
But "efficient to a naive price-taker" isn't "nobody makes money." People do. So
who are they?

## Part 2 — smart money: skill or luck?

With thousands of traders and binary outcomes, plenty look like geniuses by luck.
The only honest test is out of sample: rank wallets by profit in an earlier period
(A), see if it predicts a later period (B). I took the 41,500 wallets active in
both.

As a group they're net profitable (+$17M in A, +$14M in B) — they take money off
the casuals. But individually, persistence is almost nothing: the rank correlation
between a wallet's period-A and period-B return is ~0.02. If you were profitable in
A, you're profitable in B 48% of the time — versus a 44% base rate. So you can't
just copy whoever was green last month; most of them were lucky.

<figure>
  <img src="/figures/polymarket-persistence.png" alt="Median period-B ROI by period-A performance decile — noise around zero" loading="lazy" />
  <figcaption>Out-of-sample return by how profitable you were before. If past profit predicted future profit this would slope up; instead it's noise around zero. Even the top decile is slightly negative.</figcaption>
</figure>

The *extreme* tail is different, though. The top 100 wallets by period-A profit are
66% profitable in B (vs 44% base); strictly-defined persistent winners are about 5%
of the cohort and put up a +3.7% median return. So a skilled elite genuinely
exists — it's just the tail, not "anyone who won recently."

What do they do? My guess was market-makers earning the spread that kills the
price-taker. I checked directly: `OrderFilled` tells you who was the maker (resting
liquidity) and who was the taker (crossing the spread). The winners' maker-rate is
**0.17** — they're the *taker* 83% of the time. The opposite of market-makers. So
their edge is **directional and informational**: they pay the spread to express a
view and are right often enough to overcome it. That reconciles with Part 1 instead
of breaking it — the market's efficient against a dumb signal, and a skilled
minority beats it on actual information.

## Part 3 — follow the group, then?

Individuals don't persist, but the group reliably makes money — so why not mirror
the smart group's consensus instead of picking a member? I defined the smart group
on period-A data only, then in period B looked at their net position 48 hours
before each market resolved, and asked: does it predict the outcome *beyond the
price*, and can you trade it after costs?

Clean no. Following their net flow made +0.38% per trade before costs (basically
zero, and negative once you pay even a one-cent half-spread). And in a logistic
regression of the outcome on price and smart-flow direction, the price is hugely
significant and the smart-flow term is **not** (p = 0.36). Once you know the price,
which way the smart money leaned tells you nothing extra — the price already ate
their information. They're aggressive takers who move the price *as* they trade, so
by the time their position is visible on-chain, you're a latecomer paying the
spread.

## Part 4 — the one place it almost worked

There's a hole in that argument: it assumes the informed traders *move* the price.
What about someone consistently right who trades *small*? Their order doesn't move
anything, so their information wouldn't be impounded yet — and it could leak in
slowly. (Whales also split into many wallets to hide, so some "small" accounts are
whales trading quietly.) I split the smart traders into **big winners** (the
price-movers) and a **small-but-skilled** cohort (tiny size, high return-on-capital),
and checked whether each predicts the outcome beyond the price, 7 days out and 1
day out.

Big-winner flow added nothing at either point. But small-skilled flow *did* add
signal — but only 7 days out (p ≈ 0.02), gone by 1 day out. The price slowly
absorbs it over the final week. Following that 7-day lean to resolution made +4.2%
per trade gross, and **+3.2% after a one-cent half-spread** — an edge that clears a
realistic cost. The only thing in the whole project that looked tradeable.

Which is exactly when you should distrust yourself: one period pair, one of four
combinations landing significant, a one-sided edge. So I built a proper
**walk-forward backtest** — six windows from Nov 2024 to Oct 2025, each defining the
cohort on the prior four months and trading the next two after costs.

<figure>
  <img src="/figures/polymarket-walkforward.png" alt="Walk-forward equity curve — small-skilled flat near zero, big-winners control bleeding to -300" loading="lazy" />
  <figcaption>Following small-skilled flow (green) vs the big-winner control (gray), after a one-cent spread. Nearly all the small-cohort profit comes from the first window — the one I found the effect on — then it goes flat. Across all six it's break-even. But the control bleeds to −300: small, non-price-moving flow really does carry more information than whale flow.</figcaption>
</figure>

So the exciting number was mostly the discovery window flattering me — which is the
whole reason you walk a result forward. But one piece is robust and I think it's the
real takeaway: the small cohort beats the whale control enormously. The mechanism is
real — quiet, non-price-moving flow carries information that whale flow doesn't,
because the whales' is already in the price. It just isn't enough to clear the
spread. Same lesson as everywhere else: the gross signal is real, the spread eats
it.

## The bottom line

Polymarket is efficient in the way that matters to a normal trader. You can't beat
it with a simple signal, you can't copy last month's winners, and you can't follow
the whales — by the time their move is visible, the price has already absorbed it.
It's not efficient in the strong sense: a small, aggressive, informed minority
genuinely extracts money from the crowd, and they're a huge share of volume. Their
edge is information, not a trick and not liquidity provision (I checked).

Every "follow something" idea fails for the same satisfying reason: for information
that has already moved the price, the price is a sufficient statistic, and the
spread is the toll for arriving after. The one crack — quiet informed flow a week
early — has a real gross edge but washes out to break-even after costs. The people
who make money are the ones putting information *into* the price. There doesn't seem
to be a free lunch for the rest of us reading it back out — which is, honestly, the
answer I should have expected.
