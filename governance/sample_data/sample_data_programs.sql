-- ============================================================================
-- sample_data_programs.sql — programs catalog: bronze -> silver -> gold
-- (see sample_data_hr.sql header for placeholder / no-USE / idempotency rules)
--
-- Shared join key: program_id (P-001..P-006). This file loads THIRD, so its
-- gold CTAS may join the already-built {{hr}}.gold and {{finance}}.gold.
--
-- (!) ORDERING TRAP: {{programs}}.silver.programs gets an ITAR row filter in
-- row_filters_masks.sql, which runs LAST. The gold CTAS below reads
-- programs.silver.programs while it is still UNFILTERED, then applies its own
-- WHERE NOT itar_restricted. If the filter bound first, the loader's own read
-- would already hide ITAR rows and the aggregate would silently change. Keep
-- row_filters_masks.sql last in DEFAULT_FILES.
-- ============================================================================

-- ---- bronze: raw milestones feed
CREATE OR REPLACE TABLE {{programs}}.bronze.milestones_raw (
  milestone_id   STRING,
  program_id     STRING,
  milestone_name STRING,
  planned_date   DATE,
  actual_date    DATE,
  status         STRING,
  _ingest_ts     TIMESTAMP
);

INSERT INTO {{programs}}.bronze.milestones_raw VALUES
  ('M-001', 'P-001', 'PDR',                  DATE '2025-02-15', DATE '2025-02-20', 'Complete', TIMESTAMP '2026-06-03 04:00:00'),
  ('M-002', 'P-001', 'CDR',                  DATE '2025-09-01', NULL,              'On Track', TIMESTAMP '2026-06-03 04:00:00'),
  ('M-003', 'P-002', 'PDR',                  DATE '2025-03-10', DATE '2025-03-15', 'Complete', TIMESTAMP '2026-06-03 04:00:00'),
  ('M-004', 'P-002', 'CDR',                  DATE '2025-10-01', NULL,              'At Risk',  TIMESTAMP '2026-06-03 04:00:00'),
  ('M-005', 'P-003', 'CDR',                  DATE '2024-11-01', DATE '2024-11-10', 'Complete', TIMESTAMP '2026-06-03 04:00:00'),
  ('M-006', 'P-003', 'Production Readiness', DATE '2025-08-01', NULL,              'On Track', TIMESTAMP '2026-06-03 04:00:00'),
  ('M-007', 'P-004', 'Sustainment Review',   DATE '2025-05-01', DATE '2025-05-05', 'On Track', TIMESTAMP '2026-06-03 04:00:00'),
  ('M-008', 'P-005', 'PDR',                  DATE '2025-04-01', DATE '2025-04-12', 'Complete', TIMESTAMP '2026-06-03 04:00:00'),
  ('M-009', 'P-005', 'CDR',                  DATE '2025-11-15', NULL,              'Late',     TIMESTAMP '2026-06-03 04:00:00'),
  ('M-010', 'P-006', 'SRR',                  DATE '2025-06-01', DATE '2025-06-03', 'Complete', TIMESTAMP '2026-06-03 04:00:00'),
  ('M-011', 'P-006', 'PDR',                  DATE '2025-12-01', NULL,              'On Track', TIMESTAMP '2026-06-03 04:00:00');

-- ---- silver: program master. itar_restricted drives the row filter bound in
-- row_filters_masks.sql. Explicit INSERT (not CTAS) — the program roster is
-- reference data, not a straight derivation of the milestones feed.
CREATE OR REPLACE TABLE {{programs}}.silver.programs (
  program_id      STRING,
  program_name    STRING,
  itar_restricted BOOLEAN,
  lifecycle_phase STRING,
  current_status  STRING,
  budget_usd      DECIMAL(15, 2)
);

INSERT INTO {{programs}}.silver.programs VALUES
  ('P-001', 'SENTINEL', false, 'Production',  'On Track', 4200000.00),
  ('P-002', 'LONGBOW',  false, 'EMD',         'At Risk',  1800000.00),
  ('P-003', 'IRONCLAD', true,  'Production',  'On Track', 6500000.00),
  ('P-004', 'VANGUARD', false, 'Sustainment', 'On Track',  950000.00),
  ('P-005', 'TALON',    true,  'EMD',         'Late',     3100000.00),
  ('P-006', 'AEGIS',    true,  'Design',      'On Track', 2200000.00);

-- ---- gold: non-ITAR program status, enriched cross-catalog with headcount
-- (hr.gold) and obligated spend (finance.gold). STATED POLICY: this rollup
-- EXCLUDES ITAR programs (WHERE NOT itar_restricted) — their dollar totals
-- still exist in finance.gold.program_spend, but names + schedule + headcount
-- are withheld here. See README section "Aggregation-boundary policy".
CREATE OR REPLACE TABLE {{programs}}.gold.program_status AS
SELECT
  p.program_id,
  p.program_name,
  p.lifecycle_phase,
  p.current_status,
  p.budget_usd,
  s.total_obligated,
  h.headcount
FROM {{programs}}.silver.programs AS p
LEFT JOIN {{finance}}.gold.program_spend       AS s ON s.program_id = p.program_id
LEFT JOIN {{hr}}.gold.headcount_by_program     AS h ON h.program_id = p.program_id
WHERE NOT p.itar_restricted;
