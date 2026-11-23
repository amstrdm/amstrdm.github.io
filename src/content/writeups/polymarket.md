---
title: Is Polymarket efficient enough to trade?
subtitle: Can you actually beat Polymarket? I went looking for an edge in its order flow, in the traders who consistently win, and in outside data the market doesn't price.
accent: orange
date: "2025"
status: Research — ongoing
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

My plan was to work from the inside out. First figure out whether Polymarket is
efficient at all speaking from a general perspective, because if it is then trading it is just gambling and there's no
point going further. Then, if there's something there, try to find the traders who
consistently win and see whether you can actually follow them. And if reading the
market's own data doesn't work, bring in data from outside that the market
doesn't have. I'll say up front how it ends: almost everything I tried is
efficient (as expected) and gets eaten by the spread, and the one angle that even
looked like an edge didn't really hold up once I pushed on it. I don't take that to
mean the market is unbeatable, some people clearly do beat it, I just couldn't find
the thing they have with the data and tools I had. This is the shorter version; the
full thing with every number is in
[WRITEUP.md](https://github.com/amstrdm/polymarket-efficiency/blob/main/WRITEUP.md).

## Getting the data

A project like this lives or dies on the trade data, and that part was most of the
battle. I originally pulled every fill from Polymarket's Goldsky subgraph. But I unfortunately encountered a data corruption issue on my end and when
I went to regenerate everything a couple months later it was dead, deprecated after their V2 migration,
and their own `/trades` endpoint was gone too. So the data the project first ran on
isn't retrievable from Polymarket's free endpoints anymore. What saved it was Dune Analytics, which keeps decoded
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

So lets start with a naive test: can I predict the next 24-hour move from things I'd actually
know at the time? I built features that are all past-only so there's no cheating
with the future (cumulative volume, trade count, recent volatility, the spread, how
old the market is, how long until it resolves) and trained a simple ridge
regression, with a strict time-based split and a gap at the cutoff. Out of sample
the predictions correlate with the real move at about 0.107. That sounds tiny, and
there's a trap in it, because I'm predicting 24 hours ahead but doing it every
hour, so the observations overlap heavily and the 39k rows aren't anywhere near 39k
independent points. Clustering the errors by market gives a t-stat around 4.7, so
the signal is real. But real and tradeable are two very different things. When I run
the long/short backtest and actually pay the spread on the way in and the way out,
the edge breaks even at about half the spread and loses money at the realistic full
spread.

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

That crypto result was the only thing in the whole project that even pointed
somewhere, and what it pointed at was bringing in outside data, so I kept going in
that direction and tried three more markets. The first was sports, which has the
cleanest outside reference there is, the bookmakers. Polymarket is mostly
crypto-native retail, so my guess was that it lags the sharp books, and if its
sports prices had drifted off a sharp line then fading toward that line should pay.
It was also cheap to check, since tennis-data.co.uk publishes Pinnacle's closing
odds for free. So I lined up a few hundred Polymarket tennis matches against
Pinnacle's closing probability for the same match. There was nothing there, and it
was a clean nothing: the two track each other almost one-for-one (correlation 0.96),
the Brier scores are a dead heat, and the gap between them doesn't predict the
result. Which makes sense the moment you say it out loud, because a match with a
public sharp line is about the easiest thing on the platform to arbitrage, so
someone already has.

The sports result had a loophole I wanted to push on, though. Individual matches
have a clean public line, but tournament winners don't. "Will this player win the
whole tournament?" isn't a single number anyone posts, and to price it properly you
have to simulate the entire bracket, which is real work and exactly the kind of
thing retail doesn't do in its head. So I built it: Elo ratings off the same free
match history, reconstruct each tournament's draw, and Monte-Carlo the bracket a few
thousand times to get each player's chance of winning. And for a while it looked
great. My probabilities scored a better Brier than the market, Polymarket looked
like it was overpricing the big favorites by around six cents, and the gap predicted
the outcome with a t-stat around four. There was even a backtest that made money
fading the overpriced names, and I honestly thought I'd found something and started
writing it up that way.

I'm glad I didn't stop there, because it fell apart, and how it fell apart is the
useful part. There were two plain bugs first (men's and women's events share
tournament names, so "Wimbledon" was getting merged into one nonsensical draw, and
the word "quarterfinals" contains "final," so my round labels were mistaking
quarterfinals for the final), and fixing those already cut it down. But the one that
actually killed it was subtler. I'd been using the first trade in the data as the
pre-tournament price, the line before anyone had played. When I checked the
timestamps, about a third of those first trades had happened after the tournament
had already started. So for those markets I was comparing a pre-tournament model
against a price that already knew the first-round results: the market had watched a
top seed get upset and repriced, and my model, blind to that, looked clever for
"predicting" something that had already happened. It was look-ahead, and it was
basically the entire edge. Once I threw out the contaminated markets and kept only
the ones priced genuinely before the tournament, the model and the market scored an
identical Brier and the backtest made nothing. The mispricing I thought I'd found
was my own leaky entry price, and that one stung because I'd let myself believe it
for a bit.

The last thing I tried was weather, partly because I wanted a market with a lot of
independent events so one fluke couldn't masquerade as a signal. Polymarket runs
daily "what's the high in this city today" markets, split into one-degree buckets,
resolving every day across a couple dozen cities, which is hundreds of outcomes a
month. My thesis was that retail collapses a forecast into a single number and
overpays for the one most-likely bucket, while the real forecast has a degree or two
of spread that the neighbouring buckets deserve, so you'd sell the center and buy
the shoulders, pricing the true spread from a free weather ensemble. The first pass
looked incredible and was completely wrong: the bucket prices summed to about 1.6
instead of 1, which reads as free money, until I pulled the live order books and
they summed to almost exactly 1. The 1.6 was stale last-trade prices on buckets that
hadn't traded in a while. At least I caught that one before writing it up this time.
Priced off the real book, the market is well-calibrated: its most-likely bucket was
priced around 0.47 and won about 0.44, a three-cent gap that sits inside the spread.
And the humbling part is that my ensemble forecast scored worse than the market, not
better. Good temperature forecasting isn't a generic model pointed at a lat/long,
it's bias-corrected, station-specific forecasting that the people trading these
markets evidently already use. I showed up with a worse version of a tool the market
already had.

## So where does this leave me?

If I line all of this up, the mechanical angles all landed in the same place. A
microstructure signal, copying last period's winners, following the smart money,
fading a sharp sports line, re-deriving a tournament bracket, pointing a generic
weather model at free data, every one of them was either already in the price or
turned out to be a bug or a leak once I looked hard enough. Twice I got far enough to
half-believe a result before catching that it was a stale feed or a look-ahead in my
own data, and I think that's a more useful lesson than any single number: the real
failure mode in this kind of work isn't "there's no edge," it's "there's a fake edge
you've talked yourself into." So the careful way to put what I found is just that
with public data and off-the-shelf models I couldn't find a durable, tradeable edge,
and each time it failed I could point at a specific, checkable reason why.

What I don't want to do is turn that into the cocky version, "I couldn't find an
edge, so the market must be efficient." That doesn't follow, and I don't actually
believe it. The skilled tail from the smart-money test is proof enough that an edge
exists, since a small group beats this market over and over and keeps the money.
What my results really say is narrower than "it's efficient": the edge just isn't
lying around in the obvious places. It isn't a microstructure signal, it isn't
copy-trading the winners, it isn't a sharp line that's drifted, and it isn't a
generic model pointed at free data, because those are all either already priced in or
a trap. Whatever the winners actually have is harder to copy than any of that:
specific knowledge, or research on one particular market that nobody else bothered to
do, or just being early. And that's the part I haven't really tested, because I spent
this whole project hunting for a rule that works across markets, and what the data
keeps quietly pointing at is that the money, if it's anywhere, is in the specifics,
one market at a time, earned with actual work instead of a formula. So I'd rather
leave this with the door open than pretend I've shown the room is empty. I think I've
shown that the easy doors are locked. I haven't walked all the hard ones yet.
