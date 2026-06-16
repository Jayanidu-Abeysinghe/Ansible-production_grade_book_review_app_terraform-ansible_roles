output "frontend_public_ip" {
  description = "Public IP address of the frontend EC2 instance"
  value       = aws_instance.frontend.public_ip
}

output "backend_public_ip" {
  description = "Public IP address of the backend EC2 instance"
  value       = aws_instance.backend.public_ip
}

output "rds_endpoint" {
  description = "RDS MySQL endpoint (DNS name)"
  value       = aws_db_instance.mysql.endpoint
}

output "rds_port" {
  description = "RDS MySQL port"
  value       = aws_db_instance.mysql.port
}

output "rds_address" {
  description = "RDS MySQL address (host:port)"
  value       = "${aws_db_instance.mysql.address}"
}

output "key_pair_name" {
  description = "Name of the created key pair"
  value       = aws_key_pair.ssh_key.key_name
}

output "private_key_path" {
  description = "Local path to the private key file"
  value       = local_file.private_key.filename
  sensitive   = true
}
