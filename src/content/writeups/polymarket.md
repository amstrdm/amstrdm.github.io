---
title: Is Polymarket efficient enough to trade?
subtitle: Can you actually beat Polymarket? I went looking for an edge in its order flow, in the traders who consistently win, and in outside data the market doesn't price.
accent: orange
date: "2025"
status: Research — ongoing (forward paper-trade running)
stack: ["Python", "DuckDB", "Dune / SQL", "scikit-learn"]
repo: "https://github.com/amstrdm/polymarket-efficiency"
fullSource:
  label: "the full writedown (WRITEUP.md)"
  url: "https://github.com/amstrdm/polymarket-efficiency/blob/main/WRITEUP.md"
aiNote: >-
  I did the research and wrote the original notes and text myself; I used AI to
  tighten the prose on this page so it reads more smoothly. The analysis,
  decisions and conclusions are mine.
order: 1
---

This started with a question I couldn't let go of: people clearly make consistent
money on Polymarket, so is the market actually inefficient in a way you can
exploit, or are the winners just the ones who happened to survive a big
coin-flipping contest? I wanted to answer that with data instead of a gut feeling.

The plan was to work from the inside out. First figure out whether Polymarket is
efficient at all, because if it is then trading it is just gambling and there's no
point going further. Then, if there's something there, try to find the traders who
consistently win and see whether you can actually follow them. And if reading the
market's own data doesn't work, bring in data from outside that the market
doesn't have. I'll say up front how it ends: almost everything I tried is
efficient and gets eaten by the spread, and the only two places I found a real
edge are spots where you have to compute something the crowd can't do in its head.
Neither of those is proven profitable yet, so I've got a paper-trader running on
them. This is the shorter version; the full thing with every number is in
[WRITEUP.md](https://github.com/amstrdm/polymarket-efficiency/blob/main/WRITEUP.md).

## Getting the data

A project like this lives or dies on the trade data, and that part was most of the
battle. I originally pulled every fill from Polymarket's Goldsky subgraph, but when
I went to regenerate everything it was dead, deprecated after their V2 migration,
and their own `/trades` endpoint was gone too. So the data the project first ran on
isn't retrievable from Polymarket's free endpoints anymore, which is already a
small finding on its own. What saved it was Dune Analytics, which keeps decoded
on-chain tables of exactly what I needed. I aggregate the fills into hourly bars on
Dune's side and only pull back the small result. For the efficiency study that's
the top 208 markets by volume over the 2024 election period, about 150k hourly bars.

<figure>
  <img src="/figures/polymarket-volume.png" alt="Cumulative share of trading volume across markets — most of it sits in a thin slice" loading="lazy" />
  <figcaption>Volume is extremely concentrated. A small slice of markets carries almost all of it and the long tail is untradeable, which is why I restrict the tests to a liquid universe. Picking that universe by realized volume is itself a look-ahead, and it's why the kept side resolves YES 88% of the time. I'd rather point that out than hide it.</figcaption>
</figure>

## Is it even efficient?

The first check is the simplest one: if a market says 70%, do things priced at 70%
actually happen about 70% of the time? I measured that with the Brier score on one
snapshot per market taken 24 hours before it resolved, so each market counts once.
It came out to 0.056. On its own that number means nothing, so the question is
better than what. Comparing it to a coin flip (0.25) flatters it, because most of
these markets aren't close to 50/50 by the time you're a day out. The honest
baseline is just always predicting the average outcome, which scores 0.104. Against
that, 0.056 is a skill score of 0.46, so the prices roughly halve the error you'd
get from knowing nothing but the base rate. They're genuinely informative, which
also tells me beating them is going to be hard.

<figure>
  <img src="/figures/polymarket-calibration.png" alt="Calibration curve — observed outcome frequency against market price, close to the diagonal" loading="lazy" />
  <figcaption>Things priced at 70% happen about 70% of the time. The closer to the diagonal the better, and the prices track it well.</figcaption>
</figure>

Then the real test: can I predict the next 24-hour move from things I'd actually
know at the time? I built features that are all past-only so there's no cheating
with the future (cumulative volume, trade count, recent volatility, the spread, how
old the market is, how long until it resolves) and trained a simple ridge
regression, with a strict time-based split and a gap at the cutoff. Out of sample
the predictions correlate with the real move at about 0.107. That sounds tiny, and
there's a trap in it, because I'm predicting 24 hours ahead but doing it every
hour, so the observations overlap heavily and the 39k rows aren't anywhere near 39k
independent points. Clustering the errors by market gives a t-stat around 4.7, so
the signal is real. But real and tradeable aren't the same thing, which is the
whole point. When I run the long/short backtest and actually pay the spread on the
way in and the way out, the edge breaks even at about half the spread and loses
money at the realistic full spread.

<figure>
  <img src="/figures/polymarket-equity-curve.png" alt="Cumulative long/short PnL at 0.5x, 1x and 2x the estimated spread" loading="lazy" />
  <figcaption>Before costs the signal makes money, but once you pay a realistic spread it bleeds. It's a genuine signal, it's just smaller than the bid/ask.</figcaption>
</figure>

A pre-cost Sharpe that high made me suspect bid-ask bounce, where last-trade prices
bounce between the bid and the ask and look predictable even though you can't
capture it. So I re-ran the whole thing entering a bar later, and again pricing off
the midpoint instead of the last trade, both of which kill bounce by construction.
The edge survived both, so it's a real directional signal and not a microstructure
artifact. It just isn't big enough to pay the toll of trading. So to anyone who has
to cross the spread, Polymarket is efficient. That's a clean negative result, and
honestly with this little machinery a negative result is more believable than
finding an edge would have been.

## Who actually wins, and can you copy them?

"Efficient to a price-taker" still isn't "nobody makes money," because people
obviously do. So who are they? The problem is that with thousands of traders and
binary outcomes, plenty of them will look like geniuses by pure luck, and the only
honest way to tell skill from luck is out of sample. I ranked wallets by how they
did in one period and checked whether it predicted a later period, using the 41,500
wallets active in both.

As a group they're clearly profitable, taking money off the casual traders. But at
the individual level the persistence is almost nothing. Whether you were profitable
in the first period barely moves your odds of being profitable in the second (about
48%, against a 44% base rate). So you can't just copy whoever was green last month,
because most of them got there by luck.

<figure>
  <img src="/figures/polymarket-persistence.png" alt="Median later-period return by earlier-period performance decile — noise around zero" loading="lazy" />
  <figcaption>Out-of-sample return grouped by how profitable a wallet was before. If past profit predicted future profit this would slope upward; instead it's just noise around zero.</figcaption>
</figure>

The extreme tail is different, though. The top 100 wallets by past profit are
profitable 66% of the time in the next period, so a genuinely skilled group does
exist, it's just the tail and not "anyone who won recently." When I looked at what
they actually do, my guess was market-makers earning the spread, which would have
fit the efficiency result nicely. But I checked it directly, and they're the
opposite: they're the taker in 83% of their trades, so they're paying the spread,
not earning it. That means their edge has to be information. They're right often
enough to overcome the spread they pay, and the roughly 300 of them make up about
40% of all the volume.

So can you follow the group's consensus instead of picking a member? No, and for a
clean reason. By the time their move is visible on-chain, they've already moved the
price with it, so following them means buying after the information is in and paying
the spread on top. When I regress the outcome on the price and the direction the
smart group leaned, the price is hugely significant and the smart-money direction
adds nothing (p = 0.36). There was one hole in that logic worth chasing: a trader
who's right but trades small doesn't move the price, so their information wouldn't
be baked in yet. And that cohort did predict the outcome a week out, and following
it made about +3.2% a trade after costs, which was the first thing in the whole
project that looked tradeable. But when I walked it forward across six time windows,
almost all of the profit came from the one window I'd found the effect on, and
across all of them it's break-even.

<figure>
  <img src="/figures/polymarket-walkforward.png" alt="Walk-forward equity — small-skilled flow flat near zero, big-winner control bleeding down" loading="lazy" />
  <figcaption>Following the small, quiet traders (green) against following the big price-movers as a control (grey), after costs. The green line is flat, so there's no money in it. But the mechanism is real: the small cohort massively beats the whales, because the whales' information is already in the price and the small traders' isn't yet.</figcaption>
</figure>

The lesson from this whole half is the same every time: for information that's
already in the price, the price is the answer, and the spread is the toll for
showing up late. You can't out-read the market using its own data.

## Bringing in data the market doesn't have

If reading information out of the price never works, the obvious move is to stop
doing that and bring information the price doesn't contain. When I looked at what
Polymarket actually is now, it's mostly crypto, and a huge share of those markets
are things like "Will Bitcoin be above $112,000 on September 23 at 8AM?" which, if
you stare at it, is just a binary option. The people trading them are retail
eyeballing a number, but the real BTC price and its volatility are sitting on
Binance for free. So I priced a couple thousand of these the way an options desk
would, using the real price and recent volatility an hour before resolution, and
compared it to what Polymarket was charging. Near the money, where the answer
actually depends on volatility, my model prices them better, and the gap between my
model and the market predicts the outcome with a t-stat around 5. For the first
time in the project it also traded: on the held-out later period it made roughly
+8% a trade after a realistic cost, and stayed positive even at double the spread.

Then I tried to break it, and mostly did. When I ran the exact same rule across
every month, almost all of the trades landed in September 2025. An hour before
these markets resolve they're usually already decided, so the near-the-money
chances I need are rare, and they happened to bunch up in one choppy month. So I ran
the test that would settle it and entered earlier, 1 to 24 hours out, where far more
markets are still genuinely undecided. That fixed the breadth problem but the edge
decayed as I pulled the entry earlier, from about +12% a trade at one hour down to
statistically zero by twelve to twenty-four hours.

<figure>
  <img src="/figures/polymarket-crypto.png" alt="Cumulative PnL of the crypto options strategy — ramps through September then goes flat" loading="lazy" />
  <figcaption>The crypto-options strategy at a one-hour entry. It ramps hard through September, keeps climbing past the dev/holdout line, and then goes flat, not because it starts losing but because it stops finding trades once the market gets busy again.</figcaption>
</figure>

Digging into why September worked made it more interesting than a plain fluke. It
was the calmest, most range-bound month of the year for crypto, and when crypto is
quiet a lot of these markets are still sitting right on their strike in the final
hour instead of having blown through it. So the opportunities pile up in low-vol
regimes and basically vanish in volatile ones. That turns it from "a lucky month"
into "a real last-hour edge you can only harvest when the market is calm," which is
a condition you can actually detect, so it's worth forward-testing. But I have
exactly one such month with real sample size, so for now it stays a maybe.

While I was at it I checked two other ideas. One was that Polymarket, being
crypto-native retail, might lag the sharp bookmakers in sports, so I tested tennis
against Pinnacle's closing odds. It doesn't lag at all: Polymarket tracks the sharp
line at 0.96 correlation with the same Brier score and no systematic bias, and the
gap between them doesn't predict anything. It's as sharp as the sharpest book,
because a liquid moneyline has an obvious reference that arbitrageurs keep aligned.
The other idea was the opposite kind of market, tournament outrights, "Will this
player win the whole tournament?", which is priced by retail with a clear
favorite bias and has no single sharp line to copy, and whose fair value you can
only get by simulating the bracket. I built an Elo model from free tennis history
and Monte-Carlo'd the actual draw, and this one is a genuine mispricing: my model
beats Polymarket's prices (Brier 0.125 vs 0.134), Polymarket overprices the
contenders by about six cents, and the gap predicts the outcome with a t-stat
around 4. Fading the overpriced favorites made +6.6% a trade after a two-cent
spread. The catch is that it's only 35 tournaments and the outcomes are
high-variance longshots, so the realized-profit t-stat is just 1.31, which isn't
convincing yet. It's the same shape as the crypto result: a real signal with
positive expected value that I can't yet prove is bankable.

## So where does it land?

Every piece of this rhymes, which I didn't plan but find satisfying. Polymarket is
efficient wherever there's an obvious reference that arbitrageurs can copy, whether
that's its own order flow, the crypto spot price, or the sharp sports line. The only
places I found a real edge were the non-obvious, computational mispricings, where
you have to price option volatility or simulate a tournament bracket, something
retail can't do in its head and no simple arb corrects. And even those two, the
crypto options and the tournament outrights, are real signals with positive
expected value that aren't proven profitable yet: one only shows up in calm months,
the other needs many more tournaments. So I've built a forward paper-trader that
takes both every time a fresh market appears, because the only honest way to know if
an edge is real is to watch it work on data you haven't seen.

The bigger takeaway is the one the project kept handing me no matter which door I
tried: you can't out-read a prediction market using its own data, because by
construction it has already digested it. If you want an edge you have to know or
compute something it doesn't. The people who make money on Polymarket know things,
they don't read them off the screen, and for the most part neither could I.
