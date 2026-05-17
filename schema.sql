-- Task A schema. PostgreSQL 14+ (Supabase). Idempotent.

CREATE TABLE IF NOT EXISTS leads_log (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    received_at                 TIMESTAMPTZ NOT NULL DEFAULT now(),

    email                       TEXT NOT NULL,
    company_domain              TEXT NOT NULL,

    role_account                BOOLEAN NOT NULL DEFAULT false,
    enrichment_inconsistent     BOOLEAN NOT NULL DEFAULT false,
    website_unresolved          BOOLEAN NOT NULL DEFAULT false,

    apollo_organization         JSONB,
    apollo_top_people           JSONB,
    email_matched_in_top_people BOOLEAN,
    matched_person              JSONB,
    apify_content               JSONB,
    combined_enrichment         JSONB,
    data_tier                   TEXT CHECK (data_tier IN ('MINIMAL','PARTIAL','RICH')),

    agent_iterations            INT,
    agent_tools_called          JSONB,
    agent_has_enough_info       BOOLEAN,
    agent_findings              JSONB,
    agent_research_reasoning    TEXT,

    criteria_scores             JSONB,
    disqualifiers_triggered     JSONB,
    subtotal                    INT,
    expected_score              INT,
    final_score                 INT CHECK (final_score BETWEEN 1 AND 10 OR final_score IS NULL),
    tier                        TEXT CHECK (tier IN ('hot','warm','cold')),
    summary_reasoning           TEXT,

    evidence_fabricated         JSONB,
    evidence_fabrication        BOOLEAN NOT NULL DEFAULT false,
    score_anomaly               BOOLEAN NOT NULL DEFAULT false,

    email_subject               TEXT,
    email_body                  TEXT,
    email_template_used         TEXT,

    action_taken                TEXT NOT NULL CHECK (action_taken IN (
        'email_drafted',
        'routed_to_review',
        'routed_role_account',
        'skipped_duplicate',
        'skipped_disqualifier',
        'skipped_invalid_email',
        'skipped_invalid_domain'
    )),
    review_reason               TEXT,

    total_cost_usd              NUMERIC(10,5),
    total_latency_ms            INT,
    llm_calls_count             INT,

    event_hash                  TEXT
);

CREATE INDEX IF NOT EXISTS idx_leads_log_received_at ON leads_log (received_at DESC);
CREATE INDEX IF NOT EXISTS idx_leads_log_tier        ON leads_log (tier);
CREATE INDEX IF NOT EXISTS idx_leads_log_action      ON leads_log (action_taken);
CREATE INDEX IF NOT EXISTS idx_leads_log_event_hash  ON leads_log (event_hash);

ALTER TABLE leads_log ENABLE ROW LEVEL SECURITY;
-- service_role bypasses RLS; no anon policies needed for the take-home.
