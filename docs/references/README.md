# Pi References

Reference material consumed by Pi sessions: links, posts, and source documents
collected from `#hermes_home` and other channels, converted into structured
TOML files for retrieval.

## Layout

```
references/
├── README.md            ← this file
├── CLASSIFICATION.md    ← topic classification of articles/tweets/non-X links
├── SOURCES.md          ← consolidated original repo docs (how-to, prompt, script, readme)
├── unclassified/        ← raw material not yet classified (only .keep)
└── classified_v1/
    └── miyake-ken-prompts/   ← converted snapshot of github.com/miyake-ken/prompts
        ├── manifest.toml     ← conversion metadata + full path index
        ├── articles/         ← 94 classified articles (89 tweets + 5 non-X posts)
        │   └── <category>/   ← 24 topic categories (see CLASSIFICATION.md)
        ├── video/            ← non-article: 1 YouTube video
        ├── repos/            ← non-article: 2 GitHub repos
        └── slack-messages/   ← 101 raw Slack posts (the source of truth)
```

## Data lineage

**`slack-messages/` is the base data.** Every tweet and non-X link derives from a
post in Slack channel `#hermes_home` (id `C0BBHF3REDS`). The conversion pipeline
is documented in [`SOURCES.md`](SOURCES.md) (consolidated from the original repo
docs) and implemented by `process_hermes_home_slack.py` (in `SOURCES.md`):

```
slack-messages/  (101 posts = 90 X-link + 8 non-X-link + 3 text-only)
  │
  ├── X links (89 unique status ids)          non-X links (8 unique urls)
  │     │  fetch tweet text (FxTwitter)             │  dedupe / classify
  │     ▼                                          ▼
  │  articles/<category>/*.toml (89)        articles/<category>/ (5)
  │   (kind="tweet")                        video/ (1) + repos/ (2)
  │                                          (kind="non-x-url")
  │
  └── text-only posts (3) → appear only in the message index export, not in
      articles/ or video/ or repos/
```

Verified invariants (checked 2026-08-09):

- All 89 tweet `status_id`s appear in `slack-messages/` (90 X-link posts, one
  duplicate: `2080447479947116624` posted twice).
- All 8 non-X urls appear in `slack-messages/` (query strings like `?si=...`
  normalized away).
- The 3 tweets with empty text (`articles/empty/`) correspond to X posts whose
  text fetch returned nothing; they still map back to Slack messages.
- The 3 text-only Slack posts have no URLs and exist only in the message index.

## Classification

`CLASSIFICATION.md` maps every article/tweet/non-X link to one of 24 topic
categories (e.g. `agent-config`, `loop-engineering`, `agent-memory`), with
per-item one-line summaries. The primary focus is **AI agent engineering**;
secondary topics (LLM fundamentals, dev tools, security, math, etc.) are
grouped separately. Non-article media (video, repos) is deliberately kept out of
the article categories.

## How to add material

1. Place raw content under `unclassified/` (or convert it the same way as
   `miyake-ken-prompts/`).
2. Classify article-type items into `articles/<category>/`; keep non-articles
   in `video/` / `repos/`-style folders.
3. Record the source Slack post as the parent in `slack-messages/` so the
   lineage stays verifiable.
4. Update `CLASSIFICATION.md` and the collection's `manifest.toml`.
