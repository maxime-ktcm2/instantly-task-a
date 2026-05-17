# Instantly.ai ICP (Ideal Customer Profile)

This document defines the scoring rubric used in `icp-scoring.md`. It is the canonical source-of-truth for the 7-criteria decomposed decomposition, the negative-signal caps, and the score-to-tier mapping.

The scoring prompt (`icp-scoring.md`) embeds this rubric in its system message verbatim. In production, this file would live in a config DB or feature flag system for per-tenant customization; in this take-home it is a markdown file loaded at build time into the workflow.

---

## The 7 sub-criteria

Each criterion is scored 0, 1, or 2 (None / Partial / Strong). Every score must be anchored by a verbatim `evidence_quote` extracted from the enrichment payload.

### 1. industry_fit

| Score | Meaning | Examples |
|---|---|---|
| 0 | Off-ICP | Retail, hospitality, consumer goods, healthcare patient-facing, education K-12 |
| 1 | Adjacent | E-commerce platforms, fintech consumer apps, real estate brokerages |
| 2 | Strong | B2B SaaS, marketing agencies, sales agencies, consulting firms, recruitment firms, MarTech, SalesTech, RevOps |

### 2. size_fit

| Score | Meaning |
|---|---|
| 0 | <10 employees (too small to support a SaaS purchase decision) OR >2000 (too enterprise for self-serve) |
| 1 | 500-2000 (still reachable but longer sales cycle) OR unknown |
| 2 | 10-500 (sweet spot for self-serve cold-outreach platform) |

### 3. seniority_fit

| Score | Meaning |
|---|---|
| 0 | Junior IC: Analyst, Specialist, Coordinator, Assistant, intern |
| 1 | Manager, Lead, Sr. Manager, Sr. IC |
| 2 | Director, VP, Head, C-level (CEO/COO/CMO/CRO/CSO), Founder, Owner |

### 4. geography_fit

| Score | Meaning |
|---|---|
| 0 | Off-market: countries where cold outreach is restricted or low Instantly demand (typically: China, Russia, Iran, North Korea) |
| 1 | Adjacent: LatAm, South East Asia, Eastern Europe, India, Africa |
| 2 | Primary: United States, United Kingdom, Canada, Australia, Western Europe (DE, FR, NL, ES, IT, IE, Nordics) |

### 5. intent_hiring_sales

| Score | Meaning | Detect via |
|---|---|---|
| 0 | No signal | n/a |
| 1 | Vague mention of sales team or growth team exists | website mentions sales team |
| 2 | Active SDR/AE/BDR job posting OR explicit "scaling sales" in recent comms | agent serper_search for "SDR" OR LinkedIn jobs |

### 6. intent_growth_funding

| Score | Meaning | Detect via |
|---|---|---|
| 0 | No signal of growth or funding | n/a |
| 1 | Older funding (>18 months) OR organic growth mentions | Apollo `latest_funding_round_date` or news |
| 2 | Recent funding (<12 months) OR explicit "scaling" / "Series A/B/C just closed" | Apollo or Apify Google Search / Jina-sourced article |

### 7. intent_outbound_stack

| Score | Meaning | Detect via |
|---|---|---|
| 0 | No signal of outbound activity or tooling | n/a |
| 1 | Generic CRM mention (Salesforce, HubSpot, Pipedrive only) | Apollo `technologies[]` |
| 2 | Mentions cold outbound, sequencing, AI SDR, Apollo, Outreach, Salesloft, Lemlist, Smartlead, Reply.io | Apollo technologies or web content |

---

## Strong negative signals (cap subtotal)

These do NOT auto-reject the lead but bound the subtotal so the holistic score reflects the issue.

| Signal | Detection | Subtotal cap |
|---|---|---|
| Personal email (`@gmail.com`, `@yahoo.com`, `@outlook.com`, `@hotmail.com`) AND no resolvable corporate website | backend check | 2 |
| MLM / spam-farm industry detected | Apollo industry contains "Multi-Level Marketing" / website content matches MLM patterns | 1 |
| Domain doesn't resolve / 5xx | HTTP probe during Apify crawl | 1 |
| Junk page detected | Apify homepage returns "domain for sale" / "coming soon" / "parked" / `<title>` len < 5 / content < 200 tokens | 2 |

## Coherence-failure routing (separate from scoring)

If `email_domain != company_domain` AND `email_domain not in apollo_organization.domains[]` AND not in known organizational aliases, set `enrichment_inconsistent=true` and CAP `final_score` at 3 (forcing tier=cold). Scoring DOES still run (we want a low score with reasoning, not silent rejection) but the cap ensures we don't waste high-touch outreach on a likely-wrong person. Note: personal-email providers (`gmail.com`, `yahoo.com`, `outlook.com`, `hotmail.com`) are exempt from this check (since freelancers commonly use gmail + own domain  |  that's a legitimate pattern, not a coherence failure).

## email_status cap (Apollo signal)

If `email_matched_in_top_people` is false OR `matched_person.seniority` is null, **cap `seniority_fit` at 1 regardless of LLM output**. The email reaches the company but we don't have evidence the person is among the senior decision-makers.

---

## Score mapping (subtotal → reference 1-10 → PDF tier)

The LLM emits a **holistic** `final_score` 1-10 of its own judgment. The table below is a **reference** used by the backend anomaly detector  |  NOT a deterministic formula.

| Subtotal (sum of 7 sub-scores) | Reference final_score | PDF tier |
|---|---|---|
| 0-2 | 1-2 | Cold |
| 3-4 | 3 | Cold |
| 5 | 4 | Warm |
| 6-7 | 5 | Warm |
| 8-9 | 6 | Warm |
| 10 | 7 | Warm |
| 11 | 8 | Hot |
| 12-13 | 9 | Hot |
| 14 | 10 | Hot |

**Anomaly detection** : if `|LLM_final_score - reference_from_table| > 2`, flag `score_anomaly=true` and route to review queue for spot-check. This catches LLM drift while still respecting holistic judgment.

> Note: this lookup table is the canonical computation of `expected_score`. A previously-considered linear formula `ceil(subtotal * 10 / 14)` is rejected because it disagrees with the table on subtotal=10 (formula yields 8, table yields 7).

---

## Why these 7 criteria specifically (for Instantly)

Instantly.ai is a cold-email and outbound automation platform. Its ideal customer is a B2B company doing (or about to do) sales-led outbound. The 7 criteria balance three lenses:

- **3 firmographic** (industry, size, geography) | **who they are**
- **1 person** (seniority) | **who in the org**  
- **3 intent** (hiring sales, growth/funding, outbound stack) | **are they at the moment of need**

This mirrors the typical "moment of need" pattern for B2B SaaS sales tooling: post-funding companies that just hired sales leadership and are evaluating tooling. Hot tier = all three intents present. Warm = 1-2 intents. Cold = 0 intents (still might convert later but lower priority right now).

In production this rubric would be tenant-customizable. For the take-home demo it is fixed.
