# CDC Pipeline — AWS layer (Terraform)

The AWS infrastructure layer of the CDC pipeline. It provisions the source
database, replication, storage, and IAM

> This was meant to be an example of an **existing** domain that Databricks could plug into and grab the Data from.  It configures a databricks_trust policy however,
> So if you are trying to plug into an existing system, there would need to be **some** coordination with the domain owner to create the IAM trust policies and S3 buckets that the data goes into.
>
> In this example I set it up so the bucket gets created here, but you could ostensibly configure it so replication goes into a bucket hosted by your org.

## Architecture (AWS portion)

```
RDS MySQL (source)
    └── AWS DMS (full load + CDC via binlog)
          └── S3 (Parquet files, partitioned by date)

IAM: Databricks cross-account S3 role + 3 DMS service roles
```

## What gets provisioned

| Layer | Resource | Purpose |
|-------|----------|---------|
| **Source** | RDS MySQL 8.0 (`db.t4g.micro`) | Source database with binlog enabled for CDC |
| **Replication** | DMS replication instance + task | Streams row changes (insert/update/delete) to S3 as Parquet |
| **Storage** | S3 bucket | Stores DMS CDC output (Parquet). Auto Loader checkpoints default to a UC managed volume, not this bucket |
| **IAM** | 4 IAM roles | DMS S3 write access, DMS VPC/CloudWatch roles, Databricks cross-account S3 access |
