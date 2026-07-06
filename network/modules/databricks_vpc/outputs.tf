# ==============================================================================
# outputs.tf
# ==============================================================================

output "vpc_id" {
  description = "VPC id."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "VPC CIDR block."
  value       = aws_vpc.this.cidr_block
}

output "private_subnet_ids" {
  description = "Private subnet ids (one per AZ)."
  value       = aws_subnet.private[*].id
}

output "public_subnet_ids" {
  description = "Public subnet ids (NAT hosts only)."
  value       = aws_subnet.public[*].id
}

output "security_group_ids" {
  description = "Security groups for databricks_mws_networks."
  value       = [aws_security_group.workspace.id]
}

output "security_group_id" {
  description = "The workspace security group id."
  value       = aws_security_group.workspace.id
}

output "dms_security_group_id" {
  description = "DMS security group id (null when create_dms_subnet_group = false)."
  value       = try(aws_security_group.dms[0].id, null)
}

output "private_route_table_ids" {
  description = "Private route table ids (one per AZ) — peering routes attach here."
  value       = aws_route_table.private[*].id
}

output "nat_gateway_ids" {
  description = "NAT gateway ids."
  value       = aws_nat_gateway.this[*].id
}

output "endpoint_ids" {
  description = "VPC endpoint ids by service ({} when endpoints are disabled)."
  value = var.enable_databricks_endpoints ? {
    s3      = aws_vpc_endpoint.s3[0].id
    sts     = aws_vpc_endpoint.sts[0].id
    kinesis = aws_vpc_endpoint.kinesis[0].id
  } : {}
}

output "dms_replication_subnet_group_id" {
  description = "DMS replication subnet group id (null when not created)."
  value       = try(aws_dms_replication_subnet_group.this[0].replication_subnet_group_id, null)
}
