-- ============================================================================
-- sample_data_hr.sql — HR catalog: bronze -> silver -> gold
--
-- Placeholders {{hr}}/{{finance}}/{{programs}} are CATALOG names, substituted by
-- load_sample_data.py (defaults hr/finance/programs). Schema names are the
-- literal bronze/silver/gold. Every statement is fully qualified and self-
-- contained (no USE) because each runs in its own Statement Execution API call.
--
-- Idempotent: CREATE OR REPLACE TABLE resets each table (and drops any column
-- masks bound to it) so re-running load_sample_data.py is always safe.
--
-- Shared join keys across catalogs: program_id (P-001..P-006), employee_id.
-- ============================================================================

-- ---- bronze: raw personnel feed (what the HR system dumps; PII in the clear)
CREATE OR REPLACE TABLE {{hr}}.bronze.employees_raw (
  employee_id INT,
  full_name   STRING,
  email       STRING,
  ssn         STRING,
  salary      DECIMAL(10, 2),
  department  STRING,
  _ingest_ts  TIMESTAMP
);

INSERT INTO {{hr}}.bronze.employees_raw VALUES
  (1,  'Ana Torres',    'ana.torres@example.com',    '123-45-6789', 145000.00, 'Engineering',  TIMESTAMP '2026-06-01 04:00:00'),
  (2,  'Ben Okafor',    'ben.okafor@example.com',    '234-56-7890',  98000.00, 'Program Mgmt', TIMESTAMP '2026-06-01 04:00:00'),
  (3,  'Chloe Martin',  'chloe.martin@example.com',  '345-67-8901', 121000.00, 'Engineering',  TIMESTAMP '2026-06-01 04:00:00'),
  (4,  'Derya Kaya',    'derya.kaya@example.com',    '456-78-9012',  87500.00, 'Finance',      TIMESTAMP '2026-06-01 04:00:00'),
  (5,  'Elena Petrova', 'elena.petrova@example.com', '567-89-0123', 132000.00, 'Engineering',  TIMESTAMP '2026-06-01 04:00:00'),
  (6,  'Farid Rahman',  'farid.rahman@example.com',  '678-90-1234',  76000.00, 'Logistics',    TIMESTAMP '2026-06-01 04:00:00'),
  (7,  'Grace Liu',     'grace.liu@example.com',     '789-01-2345', 158000.00, 'Engineering',  TIMESTAMP '2026-06-01 04:00:00'),
  (8,  'Hugo Silva',    'hugo.silva@example.com',    '890-12-3456', 104000.00, 'Contracts',    TIMESTAMP '2026-06-01 04:00:00'),
  (9,  'Iris Chen',     'iris.chen@example.com',     '901-23-4567', 112000.00, 'Program Mgmt', TIMESTAMP '2026-06-01 04:00:00'),
  (10, 'Jamal Reed',    'jamal.reed@example.com',    '012-34-5678', 129000.00, 'Engineering',  TIMESTAMP '2026-06-01 04:00:00');

-- ---- silver: curated employees. Enriches bronze with clearance_level and the
-- program each person supports (the cross-catalog join key). email, ssn,
-- clearance_level, salary are masked in row_filters_masks.sql AFTER this loads.
CREATE OR REPLACE TABLE {{hr}}.silver.employees AS
SELECT
  employee_id,
  full_name,
  email,
  ssn,
  salary,
  department,
  CASE employee_id
    WHEN 1 THEN 'Secret'     WHEN 2 THEN 'Confidential' WHEN 3 THEN 'Secret'
    WHEN 4 THEN 'Secret'     WHEN 5 THEN 'Confidential' WHEN 6 THEN 'Secret'
    WHEN 7 THEN 'Top Secret' WHEN 8 THEN 'Top Secret'   WHEN 9 THEN 'Secret'
    ELSE 'Top Secret'
  END AS clearance_level,
  CASE employee_id
    WHEN 1 THEN 'P-001' WHEN 2 THEN 'P-001' WHEN 3 THEN 'P-002'
    WHEN 4 THEN 'P-003' WHEN 5 THEN 'P-002' WHEN 6 THEN 'P-004'
    WHEN 7 THEN 'P-003' WHEN 8 THEN 'P-005' WHEN 9 THEN 'P-006'
    ELSE 'P-005'
  END AS program_id
FROM {{hr}}.bronze.employees_raw;

-- ---- gold: headcount + average salary per program. Aggregates only, no
-- row-level PII, so this is the "aggregation boundary" safe to expose to
-- program_managers who cannot read individual HR rows. Built BEFORE the silver
-- salary mask binds, so AVG(salary) sums real values.
CREATE OR REPLACE TABLE {{hr}}.gold.headcount_by_program AS
SELECT
  program_id,
  COUNT(*)              AS headcount,
  ROUND(AVG(salary), 2) AS avg_salary
FROM {{hr}}.silver.employees
GROUP BY program_id;
