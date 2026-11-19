---
title: Episteme
subtitle: Turning crowd-sourced stock theses into structured, peer-reviewed research
accent: blue
date: "2026"
status: Live in production
stack: ["Python", "FastAPI", "PostgreSQL", "React", "LLMs"]
repo: "https://github.com/amstrdm/episteme-terminal"
live: "https://episteme.cloud"
fullSource:
  label: "the full technical writedown (gist)"
  url: "https://gist.github.com/amstrdm/06f9a7eecde222300178bf04e2aed240"
aiNote: >-
  I wrote the research, the notes and the original text myself; I used AI to
  tighten the prose on this page so it reads more smoothly. The full writedown
  linked above is entirely my own writing, with no AI involved.
order: 1
---

Episteme was my final Abitur research project, graded 15/15 (the top mark). The
original question was whether an AI could usefully critique investment theses, and
it turned into a web app that's live and running in production. You give it a
ticker or a company name, it goes to the
places people actually argue about stocks (Reddit, Seeking Alpha), and it hands
back the bull case and the bear case for that stock, each point scored for
sentiment and checked against what the comments say back.

This is the short version. I wrote a very long, blow-by-blow writedown of how the
whole thing works while I was building it — it's linked at the top of the page if
you want the real depth.

## The backend

Python and FastAPI over PostgreSQL, deployed on a VPS with Gunicorn/Uvicorn
workers. There are five core tables — tickers, posts, points, criticisms,
comments — with cascade deletes and check constraints so a sentiment score can't
land outside its 1–100 range. Vector embeddings live right on the point rows so I
can ask "have I seen this argument before?" without recomputing anything.

Scraping is PRAW for Reddit and a rate-limited RapidAPI feed for Seeking Alpha
(500 requests a day, which keeps you honest about what you actually fetch). Ticker
search is a trigram index with weighted relevance so partial queries resolve as
you type.

## The part I spent the most time on: deduplication

The same thesis gets posted ten different ways, so if you don't dedup, you
double-count. I wanted a cheap embedding model to do a first pass and only call an
LLM on the borderline cases. So I benchmarked four embedding models on 40 hand-
labelled pairs of thesis points, looking at where each one separates duplicates
from non-duplicates and how sensitive that is to the similarity threshold:

| Model | Avg sim (dupes) | Avg sim (non-dupes) | Best threshold | F1 |
|---|---|---|---|---|
| text-embedding-ada-002 | 0.93 | 0.80 | 0.85 | 0.96 |
| text-embedding-3-small | 0.74 | 0.33 | 0.60 | 0.96 |
| **MiniLM** (all-MiniLM-L6-v2) | 0.66 | 0.22 | 0.40 | **1.00** |
| FinLang | 0.78 | 0.29 | 0.40–0.45 | 0.96 |

The headline number — MiniLM hitting a perfect F1 — hides the real story, which
only shows up when you plot F1 against the threshold:

<figure>
  <img src="/figures/episteme-embedding-f1.png" alt="F1 score vs similarity threshold for ada-002, text-embedding-3-small, MiniLM and FinLang" loading="lazy" />
  <figcaption>F1 vs threshold. ada-002 is nearly flat — its duplicates and non-duplicates sit almost on top of each other, so it can barely tell them apart. MiniLM is perfect at 0.40 but falls off a cliff the moment you move off it, which means it'd misclassify a lot once the data gets more varied.</figcaption>
</figure>

ada-002 is the obvious loser: it crushes everything into a narrow similarity band,
so you need a brutal 0.85 threshold just to start separating duplicates, and even
then a tiny wording change tips a non-duplicate over the line. MiniLM is the most
accurate in the controlled test but fragile. The 3-small and FinLang models are
less peaky and hold up over a wider range of thresholds, which is what you want in
production where the inputs aren't curated.

So the design is a hybrid: a cheap embedding pass flags anything above the
similarity cutoff as a *possible* duplicate, then GPT-3.5 confirms the flagged
pairs in batches. Fast and cheap for the easy 95%, a real language model only
where it's worth paying for.

## The rest of the pipeline

Each ticker runs through: summarize each post into discrete thesis points with
GPT-4o (0–100 sentiment on each) → dedup → pull company fundamentals from
Financial Modeling Prep and Yahoo → read the comments and extract where the crowd
actually pushes back on a point → average the surviving points into a ticker
sentiment.

LLM latency taxes everything, so the pipeline is async and analyzes posts
concurrently, and I shaved time off the small stuff too — sets instead of lists
for O(1) URL dedup, batched comment-ID requests instead of one at a time. None of
those is a big win on its own, but they stack up, and it matters most exactly when
you're already waiting on a model.

## What production actually taught me

The first deploy broke in a way local dev never could. Analysis progress was held
in memory, which is fine with one worker and wrong the instant you have several
Gunicorn workers — each one has its own memory, so a progress poll would hit a
worker that had never heard of the task. The fix was to move task state into Redis
with a short TTL so every worker reads from the same place. "Works on my machine"
and "works with concurrency" turned out to be two different claims.

## Frontend

React + Vite + Tailwind, hosted on Vercel. Three pages: a search home, the
per-ticker dashboard, and a local-storage favorites list. The dashboard cancels
in-flight requests when you navigate away, memoizes the bull/bear filtering, and
colour-codes the metrics so you can read the shape of a thesis before you read a
word of it.

<figure>
  <img src="/figures/episteme-design.png" alt="Episteme stock dashboard — company profile, metrics, and the bull/bear points list" loading="lazy" />
  <figcaption>The per-ticker dashboard: company profile and metrics up top, the scored bull and bear points below, each one expandable into the criticisms pulled from the comments.</figcaption>
</figure>
