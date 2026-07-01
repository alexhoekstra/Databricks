# Terraform — Infrastructure & platform provisioning

Exploratory Terraform scripts for provisioning Databricks workspace assets,
governing Unity Catalog, and running configuration-driven ingestion. Everything
here was built on the **Databricks Free Tier**, so some experiments are shaped by
its limitations (e.g. account-level federation).

> :heart: **The flagship `lakeflow_connect` CDC pipeline has been promoted to the repo root — see [`/lakeflow_connect`](../../lakeflow_connect/) for the most complete example** (per-domain CDC ingestion into Unity Catalog bronze, split across Terraform + a Databricks Asset Bundle).

## Contents

### [`scalable_ingestion/`](scalable_ingestion/)

A configuration-driven, scalable ingestion framework that extracts data from
external sources into Unity Catalog bronze tables. Adding a new data domain is
just a new entry in `terraform.tfvars` — no additional resources to write. Each
domain gets a UC schema, a managed landing volume, and a scheduled extract →
autoload job built on the [`domain_batch_ingest`](../notebooks/modules/domain_batch_ingest/)
wheel. See [`wc_bundle`](../bundles/wc_bundle/) for a DAB triggered off a bronze
table it produces.

### [`modules/`](modules/)

Reusable Terraform modules:

- [`domain_batch_ingest/`](modules/domain_batch_ingest/) — provisions a per-domain
  ingestion job (UC schema + managed volume + scheduled extract/autoload job),
  driven by a configurable source and target catalog.
- [`unity_catalog_module/`](modules/unity_catalog_module/) — reusable Unity Catalog
  schema/object provisioning.
- [`vault_secrets/`](modules/vault_secrets/) — pulls credentials from HashiCorp
  Vault (KV v2) at plan/apply time, keeping secrets out of code and `.tfvars`.

### [`dev/`](dev/)

Databricks provisioning experiments — Unity Catalog creation, secrets, jobs,
notebooks, and schemas. Its [`provisioning/`](dev/provisioning/) subfolder explores
account- and workspace-level governance: users, groups, service principals,
notification/alert destinations, and GitHub Actions OIDC federation.
