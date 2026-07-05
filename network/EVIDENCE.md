# EVIDENCE — `network/` applied for real (us-east-2)

Applied **2026-07-03** · Terraform v1.15.6 (repo container) · AWS account `****6754` ·
repo at `57a5bd8` + this root. Everything below is trimmed real output; commands shown
before each block. Filter tag `project = network` comes from the provider `default_tags`.

**Timeline** — plan: 74 to add · apply #1 22:37:25Z: failed fast on pre-existing
`dms-vpc-role` (`EntityAlreadyExists` — the conflict called out in
`variables.tf`; flipped `create_dms_vpc_role = false`) · apply #2
22:38:52→22:41:20Z (**2m28s**): everything except 2 SG rules (AWS rejects `>` in
rule descriptions — fixed the tfvars text) · apply #3 22:41:59→22:42:18Z: the 2
rules. Steady state: **76 state entries**.

## 1. Outputs — the workspace_vending contract

`terraform output -json vpcs` — exactly `{vpc_id, private_subnet_ids[2], security_group_ids[1]}` per VPC:

```json
{"ingest":{"private_subnet_ids":["subnet-00235cc46cf1c3940","subnet-01284f365d9b3985d"],
           "security_group_ids":["sg-0292dad639edf9b46"],"vpc_id":"vpc-073f86f1beae49cf1"},
 "workspace":{"private_subnet_ids":["subnet-064136a47a1614983","subnet-0af86c4b02abbafa9"],
              "security_group_ids":["sg-06a88e8dd77c04fbd"],"vpc_id":"vpc-0a0f769cbfc65843a"}}
```

`terraform output -json peerings`:

```json
{"workspace_ingest":{"accept_status":"active","id":"pcx-0433d52cace522b80"}}
```

## 2. VPCs + DNS attributes

`aws ec2 describe-vpcs --filters Name=tag:project,Values=network` + `describe-vpc-attribute`:

```text
dbx-net-ingest     vpc-073f86f1beae49cf1  10.21.0.0/20  available
dbx-net-workspace  vpc-0a0f769cbfc65843a  10.20.0.0/20  available

vpc-073f86f1beae49cf1: dnsSupport=True dnsHostnames=True   <- Databricks hard requirement
vpc-0a0f769cbfc65843a: dnsSupport=True dnsHostnames=True
```

## 3. Subnets — 2 AZs per VPC, /24s from the +4-newbits math

`aws ec2 describe-subnets --filters Name=tag:project,Values=network`:

```text
dbx-net-ingest-private-us-east-2a     subnet-00235cc46cf1c3940  us-east-2a  10.21.0.0/24
dbx-net-ingest-private-us-east-2b     subnet-01284f365d9b3985d  us-east-2b  10.21.1.0/24
dbx-net-ingest-public-us-east-2a      subnet-0a87e6fee2369cbf2  us-east-2a  10.21.8.0/24
dbx-net-ingest-public-us-east-2b      subnet-03657ae3023f5ad3b  us-east-2b  10.21.9.0/24
dbx-net-workspace-private-us-east-2a  subnet-064136a47a1614983  us-east-2a  10.20.0.0/24
dbx-net-workspace-private-us-east-2b  subnet-0af86c4b02abbafa9  us-east-2b  10.20.1.0/24
dbx-net-workspace-public-us-east-2a   subnet-09833e813beba2df2  us-east-2a  10.20.8.0/24
dbx-net-workspace-public-us-east-2b   subnet-00e28e482f31d5a51  us-east-2b  10.20.9.0/24
```

## 4. NAT gateways

`aws ec2 describe-nat-gateways --filter Name=tag:project,Values=network` — one per VPC
(single-NAT default), both in public subnets:

```text
nat-015b91f40e57b67bb  available  subnet-09833e813beba2df2   (workspace)
nat-0dc850b7e9105f83c  available  subnet-0a87e6fee2369cbf2   (ingest)
```

## 5. Route tables — NAT default + S3 prefix-list + peering routes

`aws ec2 describe-route-tables --filters Name=tag:project,Values=network` (routes per table):

```text
dbx-net-workspace-private-us-east-2a/2b:
  10.20.0.0/20 -> local
  10.21.0.0/20 -> pcx-0433d52cace522b80      <- peering route to ingest
  0.0.0.0/0    -> nat-015b91f40e57b67bb      <- NAT egress
  pl-7ba54012  -> vpce-04580194dc0ac750b     <- S3 gateway endpoint (prefix list)

dbx-net-ingest-private-us-east-2a/2b:
  10.21.0.0/20 -> local
  10.20.0.0/20 -> pcx-0433d52cace522b80      <- peering route back to workspace
  0.0.0.0/0    -> nat-0dc850b7e9105f83c      (no S3 prefix-list route: endpoints disabled here)

dbx-net-{workspace,ingest}-public:
  0.0.0.0/0    -> igw-...
```

## 6. VPC endpoints — the Databricks trio (workspace VPC only)

`aws ec2 describe-vpc-endpoints --filters Name=tag:project,Values=network`
(`ServiceName / Type / State / PrivateDnsEnabled`):

```text
com.amazonaws.us-east-2.s3               Gateway    available  False
com.amazonaws.us-east-2.sts              Interface  available  True
com.amazonaws.us-east-2.kinesis-streams  Interface  available  True    <- kinesis-streams, not plain kinesis
```

## 7. Peering — active

`aws ec2 describe-vpc-peering-connections --filters Name=tag:project,Values=network`:

```text
pcx-0433d52cace522b80  active  10.20.0.0/20 <-> 10.21.0.0/20
```

## 8. DMS wiring (ingest VPC — no instance by design)

`aws dms describe-replication-subnet-groups` + `describe-security-group-rules`:

```text
dbx-net-ingest-dms  Complete  vpc-073f86f1beae49cf1  2 subnets

DMS SG (sg-0fcc54cda03e2e5e3):
  ingress  tcp 3306  10.20.0.0/20  "Databricks clusters to DMS/MySQL side of the ingest VPC"   <- across the peering
  egress   all       0.0.0.0/0     "DMS reaches sources/targets + AWS service APIs via NAT"
```

## 9. Workspace security group — the documented Databricks rules

`aws ec2 describe-security-group-rules --filters Name=group-id,Values=sg-06a88e8dd77c04fbd`:

```text
ingress  tcp 0-65535   self          Databricks inter-node (all TCP from this SG)
ingress  udp 0-65535   self          Databricks inter-node (all UDP from this SG)
ingress  tcp 443       10.21.0.0/20  Ingest VPC to Databricks SG on 443 (reverse-path demo)   <- peering allow rule
egress   tcp 0-65535   self          Databricks inter-node (all TCP to this SG)
egress   udp 0-65535   self          Databricks inter-node (all UDP to this SG)
egress   tcp 443       0.0.0.0/0     Databricks control plane + S3/STS/Kinesis + library repos
egress   tcp 3306      0.0.0.0/0     Legacy Hive metastore (MySQL)
egress   tcp 6666      0.0.0.0/0     Secure cluster connectivity relay
egress   tcp 8443-8451 0.0.0.0/0     Databricks internal services / future extendability
```

## 10. Destroy — nothing left behind

`terraform destroy -auto-approve`, 22:45:01→22:47:48Z (**2m47s**):

```text
Destroy complete! Resources: 71 destroyed.

$ terraform state list | wc -l
0
$ aws ec2 describe-vpcs --filters Name=tag:project,Values=network --query 'length(Vpcs)'
0
```

Total time infrastructure existed: ~9 minutes. Cost: ≈ $0.02 of NAT/endpoint
hours — the whole exercise cost less than the coffee it was verified over.
