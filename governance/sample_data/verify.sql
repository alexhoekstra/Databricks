-- ============================================================================
-- verify.sql — persona verification runbook.
--
-- Run these in the SQL editor while logged in as each persona in turn (Free
-- Edition: use Gmail +alias accounts you have added to the teams, then switch
-- users). Uses the default catalog names hr / finance / programs — adjust if
-- you loaded into different catalogs. Each numbered block says which persona it
-- is written for and what the correct result looks like.
-- ============================================================================

-- 0. Who am I, and which governance groups does the platform place me in?
--    (Run as anyone — this is the identity probe every other check hinges on.)
-- (These team groups are workspace-local, so is_member() is the right check —
--  is_account_group_member() only sees account groups and is always false here.)
SELECT
  current_user()                  AS who,
  is_member('platform_engineers') AS platform_engineer,
  is_member('hr_analysts')        AS hr_analyst,
  is_member('finance_analysts')   AS finance_analyst,
  is_member('program_managers')   AS program_manager,
  is_member('pii_readers')        AS pii_reader,
  is_member('export_cleared')     AS export_cleared;

-- 1. Audit the grants Terraform manages (run as any member with USE on each).
--    One schema per catalog; expect only the teams from the access matrix.
SHOW GRANTS ON SCHEMA hr.silver;
SHOW GRANTS ON SCHEMA finance.silver;
SHOW GRANTS ON SCHEMA programs.silver;

-- 2. HR column masks — the SAME query, different results per persona.
--    hr_analyst (not pii_reader): email/ssn/clearance read '***MASKED***',
--                                 salary reads NULL.
--    pii_reader:                  raw email/ssn/clearance and real salary.
SELECT employee_id, full_name, email, ssn, clearance_level, salary, program_id
FROM hr.silver.employees
ORDER BY employee_id;

-- 3. Aggregates cross the masking boundary on purpose. hr.gold holds headcount
--    and avg_salary per program with NO row-level PII — a program_manager who
--    cannot read hr.silver can still read this rollup.
--    (Run as program_manager: hr/gold is granted, hr/silver is not.)
SELECT program_id, headcount, avg_salary
FROM hr.gold.headcount_by_program
ORDER BY program_id;

-- 4. ITAR row filter on programs.silver.programs — again same query, different
--    rows per persona.
--    program_manager (not export_cleared): only the 3 non-ITAR programs
--                                           (SENTINEL, LONGBOW, VANGUARD).
--    export_cleared:                        all 6, including IRONCLAD/TALON/AEGIS.
SELECT program_id, program_name, itar_restricted, lifecycle_phase, current_status
FROM programs.silver.programs
ORDER BY program_id;

-- 5. The filter holds through aggregates too — a non-export_cleared user
--    counting programs by phase sees only the rows the filter lets through.
SELECT lifecycle_phase, count(*) AS programs
FROM programs.silver.programs
GROUP BY lifecycle_phase
ORDER BY lifecycle_phase;

-- 6. Cross-catalog join — run as finance_analyst (has finance/silver+gold and
--    programs/gold). Ties spend to program status across two catalogs. Only
--    non-ITAR programs appear because programs.gold.program_status already
--    excludes ITAR (aggregation-boundary policy); their dollars still total in
--    finance.gold.program_spend.
SELECT
  s.program_id,
  st.program_name,
  st.current_status,
  s.total_obligated
FROM finance.gold.program_spend AS s
LEFT JOIN programs.gold.program_status AS st ON st.program_id = s.program_id
ORDER BY s.total_obligated DESC;

-- 7. Negative test — run as hr_analyst. hr_analysts hold no grant on finance,
--    so this must fail with PERMISSION_DENIED (proves grants are scoped, not
--    workspace-wide). Uncomment to run.
-- SELECT * FROM finance.silver.contracts LIMIT 1;
