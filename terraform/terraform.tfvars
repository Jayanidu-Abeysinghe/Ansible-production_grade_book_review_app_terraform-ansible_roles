aws_region           = "us-east-1"
aws_access_key = ""
aws_secret_key = ""
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
availability_zones   = ["us-east-1a", "us-east-1b"]

frontend_instance_type = "t2.micro"
backend_instance_type  = "t2.micro"

ami_id = "ami-0c02fb55956c7d316"

key_pair_name = "bookreview-keypair"

rds_instance_class    = "db.t3.micro"
rds_username          = "root"
rds_password          = "YourSecret123"
rds_db_name           = "bookreview"
rds_allocated_storage = 20
rds_engine_version    = "8.0"

frontend_port = 3000
backend_port  = 3001
ssh_port      = 22
http_port     = 80
mysql_port    = 3306

project_name = "bookreview"
environment  = "production"