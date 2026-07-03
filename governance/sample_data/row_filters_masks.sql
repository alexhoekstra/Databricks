-- ============================================================================
-- row_filters_masks.sql — fine-grained access control, applied LAST
--
-- Two independent controls:
--   HR column masks     on {{hr}}.silver.employees     — hide PII values.
--   Programs row filter on {{programs}}.silver.programs — hide ITAR rows.
--
-- The mask/filter functions are Unity Catalog objects living in the schema
-- whose table they protect. They check group membership with is_member() — the
-- group names ('pii_readers', 'export_cleared') must match team keys in
-- ../terraform.tfvars.
--
-- (!) RUN LAST. Filters and masks apply to EVERYONE not exempted by the
-- function logic — INCLUDING the table owner running this loader. The gold
-- CTAS statements in the sample_data_*.sql files read silver.employees (real
-- salaries) and silver.programs (all rows) to build their aggregates; those
-- must run BEFORE these bindings, or the loader's own reads get masked/filtered
-- and the aggregates come out wrong. load_sample_data.py puts this file last in
-- DEFAULT_FILES; keep it there.
--
-- Re-run safety: the sample_data_*.sql files use CREATE OR REPLACE TABLE, which
-- drops existing bindings, so each load starts from a clean table and re-binds
-- here — re-run the loader freely.
--
-- Splitter contract: NO ';' inside any function body (statements are split on
-- ';'), and every statement is fully qualified (no USE).
--
-- Free Edition note: databricks_group in ../identities.tf creates WORKSPACE-LOCAL
-- groups (Unity Catalog can't grant to them, which is why ../grants.tf grants to
-- user emails). Membership in a workspace-local group is resolved by is_member(),
-- NOT is_account_group_member() — the latter only sees account-level groups and
-- would return false for everyone here, masking/filtering data from even the
-- exempt groups. Verified on this workspace: is_member('pii_readers') tracks
-- membership; is_account_group_member('pii_readers') is always false.
-- ============================================================================

-- ---- HR column masks: pii_readers see raw values, everyone else masked ------

CREATE OR REPLACE FUNCTION {{hr}}.silver.mask_pii_string(v STRING)
RETURN CASE
  WHEN is_member('pii_readers') THEN v
  ELSE '***MASKED***'
END;

-- Typed mask: salary reads NULL (not a string) for non-pii_readers, so the
-- column stays DECIMAL and numeric tooling does not choke on a masked value.
CREATE OR REPLACE FUNCTION {{hr}}.silver.mask_salary(v DECIMAL(10, 2))
RETURN CASE
  WHEN is_member('pii_readers') THEN v
  ELSE NULL
END;

ALTER TABLE {{hr}}.silver.employees
  ALTER COLUMN email SET MASK {{hr}}.silver.mask_pii_string;

ALTER TABLE {{hr}}.silver.employees
  ALTER COLUMN ssn SET MASK {{hr}}.silver.mask_pii_string;

ALTER TABLE {{hr}}.silver.employees
  ALTER COLUMN clearance_level SET MASK {{hr}}.silver.mask_pii_string;

ALTER TABLE {{hr}}.silver.employees
  ALTER COLUMN salary SET MASK {{hr}}.silver.mask_salary;

-- ---- Programs ITAR row filter: export_cleared see every row; everyone else
-- sees only non-ITAR programs. Bound ON (itar_restricted). --------------------

CREATE OR REPLACE FUNCTION {{programs}}.silver.itar_filter(itar_restricted BOOLEAN)
RETURN is_member('export_cleared') OR NOT itar_restricted;

ALTER TABLE {{programs}}.silver.programs
  SET ROW FILTER {{programs}}.silver.itar_filter ON (itar_restricted);
