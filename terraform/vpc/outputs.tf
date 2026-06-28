output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "subnet_ids" {
  description = "IDs of the two public subnets"
  value       = aws_subnet.public[*].id
}

output "availability_zones" {
  description = "AZs the subnets are deployed in"
  value       = local.azs
}
