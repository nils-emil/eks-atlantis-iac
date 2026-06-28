output "subnet_ids" {
  description = "IDs of the two public subnets"
  value       = aws_subnet.public[*].id
}
