# Prompt evaluation notes

The PDF asks what I'd improve with more time. This file keeps those notes concise and organized by prompt, without duplicating the prompt text.

---

## Methodology

How I'd evaluate a prompt change before shipping it:

1. Build a labeled golden set (~30 leads per prompt). Diverse: hot/warm/cold, role accounts, competitors, agencies, sparse data, multi-language sites.
2. Run the candidate prompt against the golden set, compare against the labeled outcomes.
3. Track metrics: tier-classification accuracy (against label), evidence_quote substring-validity (does the quote exist verbatim in the enrichment), email cliché-density, latency, token cost.
4. Promotion gate: candidate must beat the production prompt on tier accuracy AND not regress on cliché-density.

Tooling: Promptfoo for the harness, simple Python validators for substring + cliché checks. Not wired in this take-home.

---

## Per-prompt improvements

### `icp-criteria.md`
What it does: defines the 7-axis ICP rubric (industry, size, seniority, geography, sales-hiring intent, growth/funding intent, outbound-stack intent), each scored 0/1/2.
Future improvement:
- Per-industry sub-rubric (B2B SaaS vs Agency vs Recruitment vs MarTech). The same axes weighted differently per vertical.
- Add a localized rubric variant for non-English-speaking markets (LATAM, DACH, JP).

### `icp-scoring.md`
What it does: scores a single lead against the 7 criteria with verbatim evidence quotes, emits a holistic 1-10, classifies as hot/warm/cold.
Future improvement:
- Add 4-5 more calibration examples covering the borderline cases (warm-bordering-hot, cold-bordering-warm).
- Enforce the disqualifier whitelist at the backend (validate model output, reject unknown labels) instead of relying on the prompt alone.
- Per-tier confidence thresholds (Hot needs confidence >= 0.7, Warm >= 0.5, etc.) before the email branch fires.

### `agent-research.md`
What it does: decides if enrichment is enough to score safely; if not, fires up to 3 web/Jina lookups to fill gaps.
Future improvement:
- Add LinkedIn-as-tool (currently agent reads LinkedIn through Google snippets, not the page itself).
- Tool-budget by data tier: 1 call on RICH, 3 on PARTIAL, 5 on MINIMAL, instead of a flat cap.
- Memoize tool calls across leads in the same batch (same `{company} careers SDR` query twice = once).

### `email-hot.md`
What it does: drafts a high-touch first email when the lead scores 8-10.
Future improvement:
- Split into Hot+RICH and Hot+PARTIAL variants. Currently one template; PARTIAL-data Hot leads either fabricate specifics or fall back to generic.
- A/B subject-line styles (signal-first vs question-first vs name-first).

### `email-warm.md`
What it does: drafts a lower-pressure nurture email when the lead scores 4-7.
Future improvement:
- A "wait-and-see" mode for warm leads with no current intent: queue for a 2-week follow-up instead of sending now.
- Allow the model to suggest a content asset (article, case study) instead of a meeting ask.

### `email-cold.md`
What it does: chooses drip OR skip on cold leads; default is skip.
Future improvement:
- Per-disqualifier skip wording (currently a flat `skip_reason` string).
- Allow drip on score=2 if the lead's industry is "promising-but-early" (eg, a 5-person startup).

---

## Cross-cutting methodology choices

- **Decomposed scoring over holistic 1-10**. Holistic 1-10 alone is noisy across runs; per-criterion 0/1/2 with evidence stabilizes it.
- **Anchored output schemas everywhere**. Every LLM emits validated JSON, never raw prose.
- **Anti-pattern lists in email prompts**. Saying what NOT to write (`<banned_phrases>`) works; positive-only "be specific" guidance does not.
- **Fixed disqualifier whitelist**. The scoring model cannot invent new disqualifier labels at runtime; that prevents the kind of category drift where "non-outbound SaaS" gets wrongly tagged as "competitor".

---

## Known open problems at the prompt level

- LLM occasionally writes an evidence_quote that paraphrases instead of quoting verbatim. A backend substring validator would catch this.
- The Cold drip-vs-skip decision currently lives inside the email prompt; might be cleaner as a deterministic rule outside the LLM.
- Temperature is left at the n8n default. Should be pinned to 0.0-0.2 across all scoring/email nodes.
