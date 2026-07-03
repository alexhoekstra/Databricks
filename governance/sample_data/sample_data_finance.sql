-- ============================================================================
-- sample_data_finance.sql — finance catalog: bronze -> silver -> gold
-- (see sample_data_hr.sql header for placeholder / no-USE / idempotency rules)
--
-- Shared join keys: program_id (P-001..P-006), vendor_id + CAGE code.
-- ============================================================================

-- ---- bronze: raw contract-line feed
CREATE OR REPLACE TABLE {{finance}}.bronze.contract_lines_raw (
  contract_line_id STRING,
  contract_id      STRING,
  vendor_id        STRING,
  cage_code        STRING,
  program_id       STRING,
  appropriation    STRING,
  fiscal_year      INT,
  amount           DECIMAL(15, 2),
  _ingest_ts       TIMESTAMP
);

INSERT INTO {{finance}}.bronze.contract_lines_raw VALUES
  ('CL-001', 'C-9001', 'V-100', '1A2B3', 'P-001', 'Procurement', 2025, 1200000.00, TIMESTAMP '2026-06-02 04:00:00'),
  ('CL-002', 'C-9001', 'V-100', '1A2B3', 'P-001', 'O&M',         2025,  300000.00, TIMESTAMP '2026-06-02 04:00:00'),
  ('CL-003', 'C-9002', 'V-101', '4C5D6', 'P-002', 'RDT&E',       2025,  800000.00, TIMESTAMP '2026-06-02 04:00:00'),
  ('CL-004', 'C-9003', 'V-102', '7E8F9', 'P-003', 'Procurement', 2025, 4500000.00, TIMESTAMP '2026-06-02 04:00:00'),
  ('CL-005', 'C-9003', 'V-102', '7E8F9', 'P-003', 'RDT&E',       2024,  900000.00, TIMESTAMP '2026-06-02 04:00:00'),
  ('CL-006', 'C-9004', 'V-103', '0G1H2', 'P-004', 'O&M',         2025,  450000.00, TIMESTAMP '2026-06-02 04:00:00'),
  ('CL-007', 'C-9005', 'V-100', '1A2B3', 'P-005', 'RDT&E',       2025, 1600000.00, TIMESTAMP '2026-06-02 04:00:00'),
  ('CL-008', 'C-9005', 'V-100', '1A2B3', 'P-005', 'Procurement', 2025, 1100000.00, TIMESTAMP '2026-06-02 04:00:00'),
  ('CL-009', 'C-9006', 'V-101', '4C5D6', 'P-006', 'RDT&E',       2025, 1300000.00, TIMESTAMP '2026-06-02 04:00:00'),
  ('CL-010', 'C-9006', 'V-101', '4C5D6', 'P-006', 'O&M',         2025,  500000.00, TIMESTAMP '2026-06-02 04:00:00'),
  ('CL-011', 'C-9002', 'V-101', '4C5D6', 'P-002', 'Procurement', 2026,  700000.00, TIMESTAMP '2026-06-02 04:00:00'),
  ('CL-012', 'C-9004', 'V-103', '0G1H2', 'P-004', 'RDT&E',       2026,  250000.00, TIMESTAMP '2026-06-02 04:00:00');

-- ---- silver: curated contracts. Resolves vendor_id -> vendor_name.
CREATE OR REPLACE TABLE {{finance}}.silver.contracts AS
SELECT
  contract_line_id,
  contract_id,
  vendor_id,
  CASE vendor_id
    WHEN 'V-100' THEN 'Astra Dynamics'
    WHEN 'V-101' THEN 'Ironbridge Systems'
    WHEN 'V-102' THEN 'Meridian Aerospace'
    WHEN 'V-103' THEN 'Cobalt Defense'
    ELSE 'Unknown'
  END AS vendor_name,
  cage_code,
  program_id,
  appropriation,
  fiscal_year,
  amount
FROM {{finance}}.bronze.contract_lines_raw;

-- ---- gold: obligated dollars per program. Per the aggregation-boundary policy
-- (README), spend rollups MAY include ITAR programs as DOLLAR TOTALS ONLY — no
-- program names, phases, or milestones live here, only money keyed by program_id.
CREATE OR REPLACE TABLE {{finance}}.gold.program_spend AS
SELECT
  program_id,
  SUM(amount) AS total_obligated,
  COUNT(*)    AS contract_line_count
FROM {{finance}}.silver.contracts
GROUP BY program_id;
