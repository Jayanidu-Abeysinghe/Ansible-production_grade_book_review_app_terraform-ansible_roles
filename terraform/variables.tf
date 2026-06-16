variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
}

variable "aws_access_key" {
	description = "AWS access key"
	type        = string
}

variable "aws_secret_key" {
	description = "AWS secret key"
	type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (for EC2 and RDS)"
  type        = list(string)
}

variable "availability_zones" {
  description = "Availability zones for subnets"
  type        = list(string)
}

variable "frontend_instance_type" {
  description = "Instance type for frontend EC2"
  type        = string
}

variable "backend_instance_type" {
  description = "Instance type for backend EC2"
  type        = string
}

variable "ami_id" {
  description = "Ubuntu AMI ID"
  type        = string
}

variable "key_pair_name" {
  description = "Name for the key pair"
  type        = string
}

variable "key_pair_public_key" {
  description = "Public key for the key pair"
  type        = string
}

variable "rds_instance_class" {
  description = "RDS instance class"
  type        = string
}

variable "rds_username" {
  description = "RDS master username"
  type        = string
}

variable "rds_password" {
  description = "RDS master password"
  type        = string
  sensitive   = true
}

variable "rds_db_name" {
  description = "RDS database name"
  type        = string
}

variable "rds_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
}

variable "rds_engine_version" {
  description = "RDS MySQL engine version"
  type        = string
}

variable "frontend_port" {
  description = "Frontend application port"
  type        = number
}

variable "backend_port" {
  description = "Backend application port"
  type        = number
}

variable "ssh_port" {
  description = "SSH port"
  type        = number
}

variable "http_port" {
  description = "HTTP port"
  type        = number
}

variable "mysql_port" {
  description = "MySQL port"
  type        = number
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}