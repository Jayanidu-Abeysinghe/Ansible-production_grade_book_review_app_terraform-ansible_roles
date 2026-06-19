# Book Review App - Production Deployment

A production-grade full-stack book review application deployed on AWS using **Terraform** (infrastructure) + **Ansible** (configuration management).

## 🏗 Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        AWS VPC                                   │
│  ┌─────────────────────────┐    ┌─────────────────────────┐     │
│  │      Public Subnet      │    │      Private Subnet     │     │
│  │  ┌─────────────────┐    │    │  ┌─────────────────┐    │     │
│  │  │  Frontend EC2   │◄───┼────┼─►│  Backend EC2    │    │     │
│  │  │  (Web Server)   │    │    │  │  (App Server)   │    │     │
│  │  │  Nginx + Next.js│    │    │  │  Express + API  │    │     │
│  │  │  Port: 80/3000  │    │    │  │  Port: 3001     │    │     │
│  │  └─────────────────┘    │    │  └────────┬────────┘    │     │
│  └─────────────────────────┘    └───────────┼─────────────┘     │
│                                             │                    │
│  ┌─────────────────────────────────────────┼─────────────┐     │
│  │              Private Subnet             │             │     │
│  │  ┌──────────────────────────────────┐   │             │     │
│  │  │        RDS MySQL (Managed)       │◄──┘             │     │
│  │  │        Port: 3306                │                 │     │
│  │  └──────────────────────────────────┘                 │     │
│  └─────────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────┘
```

### Components
| Component | Technology | Purpose |
|-----------|------------|---------|
| **Infrastructure** | Terraform | AWS VPC, EC2, RDS, Security Groups |
| **Configuration** | Ansible | Node.js, Nginx, PM2, App Deployment |
| **Frontend** | Next.js 15 | React app served via Nginx + PM2 |
| **Backend** | Express + Sequelize | REST API with MySQL |
| **Database** | AWS RDS MySQL | Managed MySQL with SSL |
| **Process Manager** | PM2 | Auto-restart, logs, boot persistence |

---

## 📋 Prerequisites

### Required Tools
```bash
# Terraform >= 1.0
terraform version

# Ansible >= 2.12
ansible --version

# AWS CLI configured
aws configure
```

### AWS Requirements
- AWS Account with permissions for: EC2, VPC, RDS, IAM
- AWS credentials configured (`~/.aws/credentials` or env vars)
- Key pair for SSH access (Terraform generates one)

### Local Environment
```bash
# Generate a strong JWT secret (save this!)
openssl rand -base64 48

# Ensure SSH key permissions
chmod 400 terraform/bookreview-keypair.pem
```

---

## 🚀 Deployment Steps

### Step 1: Configure Terraform Variables

Edit `terraform/terraform.tfvars`:
```hcl
aws_region           = "us-east-1"
aws_access_key       = "YOUR_ACCESS_KEY"
aws_secret_key       = "YOUR_SECRET_KEY"
project_name         = "bookreview"
environment          = "production"
vpc_cidr             = "10.0.0.0/16"
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
availability_zones   = ["us-east-1a", "us-east-1b"]
ami_id               = "ami-0c02fb55956c7d316"  # Ubuntu 22.04 LTS
frontend_instance_type = "t3.micro"
backend_instance_type  = "t3.micro"
key_pair_name        = "bookreview-keypair"
rds_engine_version   = "8.0"
rds_instance_class   = "db.t3.micro"
rds_allocated_storage = 20
rds_username         = "root"
rds_password         = "CHANGE_ME_STRONG_PASSWORD"
rds_db_name          = "bookreview"
```

### Step 2: Deploy Infrastructure (Terraform)

```bash
cd terraform

# Initialize
terraform init

# Review plan
terraform plan

# Apply (takes ~5-10 minutes)
terraform apply

# Save outputs for Ansible
terraform output -json > ../ansible/terraform-outputs.json
```

**Key Terraform Outputs:**
```bash
terraform output frontend_public_ip      # Web server public IP
terraform output backend_private_ip      # App server private IP
terraform output rds_endpoint            # RDS MySQL endpoint (host:port)
terraform output private_key_path        # Path to SSH private key
```

### Step 3: Configure Ansible Variables

After Terraform completes, update these files in `ansible/`:

#### 1. `inventory.ini`
```ini
[web]
<FRONTEND_PUBLIC_IP>

[app]
<BACKEND_PRIVATE_IP>

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=<PATH_TO_PRIVATE_KEY>
ansible_python_interpreter=/usr/bin/python3

# App server is in private subnet - access via web server as jump host
[app:vars]
ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -i <PATH_TO_PRIVATE_KEY> ubuntu@<FRONTEND_PUBLIC_IP>"'
```

#### 2. `group_vars/web.yml`
```yaml
api_private_ip: "<BACKEND_PRIVATE_IP>:3001"
```

#### 3. `group_vars/app.yml`
```yaml
DB_HOST: "<RDS_ENDPOINT_WITHOUT_PORT>"     # e.g., bookreview-prod-mysql.ckzkuicoajpz.us-east-1.rds.amazonaws.com
DB_PORT: 3306
DB_USER: "root"
DB_PASS: "<RDS_PASSWORD_FROM_TERRAFORM>"
DB_NAME: "bookreview"
DB_DIALECT: "mysql"
DB_SSL: true
PORT: 3001
NODE_ENV: "production"
JWT_SECRET: "<GENERATE_STRONG_SECRET_64_CHARS>"
ALLOWED_ORIGINS: "http://<FRONTEND_PUBLIC_IP>:3000"
```

> **Security**: Never commit real secrets. Consider `ansible-vault encrypt group_vars/app.yml`

### Step 4: Deploy Application (Ansible)

```bash
cd ansible

# Verify connectivity
ansible all -i inventory.ini -m ping

# Syntax check
ansible-playbook site.yml --syntax-check

# Dry run
ansible-playbook site.yml -i inventory.ini --check

# Full deployment
ansible-playbook site.yml -i inventory.ini
```

**What Ansible Does:**

| Play | Host | Roles | Purpose |
|------|------|-------|---------|
| **Prepare frontend** | web | `common` → `nginx` → `web` | Node.js 20, Nginx reverse proxy, Next.js build + PM2 |
| **Prepare backend** | app | `common` → `app` | Node.js 20, Sequelize DB sync, Express API + PM2 |

---

## 🔧 Ansible Commands Reference

### Common Operations
```bash
# Test connectivity
ansible all -i inventory.ini -m ping

# Run specific play
ansible-playbook site.yml -i inventory.ini --limit web      # this will run withing only web server 
ansible-playbook site.yml -i inventory.ini --limit app      # this will run withing only app server

# Run specific play with start-at-task
ansible-playbook -i inventory.ini site.yml --start-at-task="task name" --limit app

# Run with specific tags
ansible-playbook site.yml -i inventory.ini --tags "nginx"
ansible-playbook site.yml -i inventory.ini --tags "deploy"

# Check syntax
ansible-playbook site.yml --syntax-check

# Verbose output
ansible-playbook site.yml -i inventory.ini -v
ansible-playbook site.yml -i inventory.ini -vvv
```

### Ad-hoc Commands
```bash
# Check PM2 status
ansible web -i inventory.ini -m shell -a "pm2 status" --become --become-user=ubuntu
ansible app -i inventory.ini -m shell -a "pm2 status" --become --become-user=ubuntu

# View logs
ansible web -i inventory.ini -m shell -a "pm2 logs frontend-book-review-app --lines 50" --become --become-user=ubuntu
ansible app -i inventory.ini -m shell -a "pm2 logs backend-book-review-app --lines 50" --become --become-user=ubuntu

# Restart apps
ansible web -i inventory.ini -m shell -a "pm2 restart frontend-book-review-app" --become --become-user=ubuntu
ansible app -i inventory.ini -m shell -a "pm2 restart backend-book-review-app" --become --become-user=ubuntu

# Check Nginx status
ansible web -i inventory.ini -m systemd -a "name=nginx state=started" --become
```

### Rolling Updates
```bash
# Re-deploy only frontend (code changes)
ansible-playbook site.yml -i inventory.ini --limit web

# Re-deploy only backend (API changes)
ansible-playbook site.yml -i inventory.ini --limit app

# Update dependencies only
ansible web -i inventory.ini -m shell -a "cd /opt/book-review-app/web/frontend && npm install && npm run build && pm2 restart frontend-book-review-app" --become --become-user=ubuntu
```

---

## 🔧 Terraform Commands Reference

### Lifecycle
```bash
cd terraform

# Initialize / upgrade providers
terraform init
terraform init -upgrade

# Format code
terraform fmt

# Validate
terraform validate

# Plan
terraform plan
terraform plan -out=tfplan

# Apply
terraform apply
terraform apply tfplan

# Destroy (careful!)
terraform plan -destroy
terraform destroy
```

### State Management
```bash
# List resources
terraform state list

# Show resource
terraform state show aws_instance.frontend

# Import existing resource
terraform import aws_instance.frontend i-1234567890abcdef0

# Refresh state
terraform refresh
```

### Outputs
```bash
# All outputs
terraform output

# Specific output
terraform output frontend_public_ip
terraform output rds_endpoint

# JSON format
terraform output -json
```

---

## 📁 Project Structure

```
Production_Grade_Book_Review_App_Terraform+Ansible_Roles/
├── terraform/                          # Infrastructure as Code
│   ├── main.tf                         # VPC, EC2, RDS, Security Groups
│   ├── variables.tf                    # Input variables
│   ├── output.tf                       # Outputs for Ansible
│   ├── terraform.tfvars                # YOUR VALUES (gitignored)
│   └── bookreview-keypair.pem          # SSH private key (gitignored)
│
├── ansible/                            # Configuration Management
│   ├── inventory.ini                   # Hosts + SSH config
│   ├── site.yml                        # Main playbook
│   ├── PLACEHOLDERS.md                 # Variable replacement guide
│   ├── group_vars/
│   │   ├── web.yml                     # Frontend-specific vars
│   │   └── app.yml                     # Backend-specific vars (SECRETS)
│   └── roles/
│       ├── common/                     # Node.js 20, baseline packages, SSH hardening
│       ├── nginx/                      # Nginx reverse proxy config
│       ├── web/                        # Frontend: Next.js build, PM2, .env
│       └── app/                        # Backend: DB sync, Express, PM2, .env
│
└── README.md                           # This file
```

---

## 🔑 Key Configuration Details

### Nginx Reverse Proxy (`roles/nginx/templates/bookreview.conf.j2`)
```nginx
# Frontend (Next.js) on port 3000
location / {
    proxy_pass http://127.0.0.1:3000;
}

# Backend API proxied through /api/
location /api/ {
    proxy_pass http://<BACKEND_PRIVATE_IP>:3001;
    # Headers for WebSocket, real IP, etc.
}
```

### Frontend Environment (`roles/web/templates/.env.j2`)
```env
NEXT_PUBLIC_API_URL=          # Empty! Frontend uses /api/... (proxied by Nginx)
NODE_ENV=production
```

### Backend Environment (`roles/app/templates/.env.j2`)
```env
DB_HOST={{DB_HOST}}
DB_PORT={{DB_PORT}}
DB_USER={{DB_USER}}
DB_PASS={{DB_PASS}}
DB_NAME={{DB_NAME}}
DB_DIALECT={{DB_DIALECT}}
DB_SSL={{DB_SSL}}
PORT={{PORT}}
NODE_ENV={{NODE_ENV}}
JWT_SECRET={{JWT_SECRET}}
ALLOWED_ORIGINS={{ALLOWED_ORIGINS}}
```

### PM2 Process Management
Both apps use PM2 with `pm2 startup systemd` for boot persistence:
```bash
# PM2 commands (run as ubuntu user)
pm2 status
pm2 logs <app-name>
pm2 restart <app-name>
pm2 stop <app-name>
pm2 delete <app-name>
pm2 save              # Persist current process list
```

---

## 🐛 Troubleshooting

### Frontend Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| 502 Bad Gateway | Next.js not running on 3000 | `pm2 restart frontend-book-review-app` |
| 404 on `/api/*` | Wrong `NEXT_PUBLIC_API_URL` | Ensure `.env` has `NEXT_PUBLIC_API_URL=` (empty) |
| Build fails | Node version mismatch | Verify Node 20: `node --version` |
| CSS not loading | Build not re-run | `cd /opt/book-review-app/web/frontend && npm run build && pm2 restart frontend-book-review-app` |

### Backend Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| DB connection failed | RDS SG / credentials | Check `group_vars/app.yml` + RDS security group |
| Sequelize sync failed | DB not accessible | Test: `mysql -h <RDS_ENDPOINT> -u root -p` |
| CORS errors | `ALLOWED_ORIGINS` mismatch | Set to `http://<FRONTEND_IP>:3000` |
| JWT errors | `JWT_SECRET` mismatch | Ensure same secret used across restarts |

### Network Issues

| Symptom | Cause | Fix |
|---------|-------|-----|
| Can't SSH to backend | Private subnet | Use jump host: `ssh -J ubuntu@<FRONTEND_IP> ubuntu@<BACKEND_IP>` |
| Ansible timeout on app | Jump host config | Verify `ansible_ssh_common_args` in inventory.ini |
| Nginx can't reach backend | SG rules | Backend SG must allow 3001 from Frontend SG |

### Useful Debug Commands
```bash
# On web server
curl http://127.0.0.1:3000          # Frontend direct
curl http://127.0.0.1/api/books     # API via nginx
nginx -t && systemctl status nginx  # Nginx config test

# On app server
curl http://127.0.0.1:3001/api/books # Backend direct
pm2 logs backend-book-review-app

# Database
mysql -h <RDS_ENDPOINT> -u root -p -e "USE bookreview; SHOW TABLES;"
```

---

## 🔒 Security Checklist

### Before Deployment
- [ ] `terraform.tfvars` not committed (gitignored)
- [ ] `group_vars/app.yml` encrypted with ansible-vault
- [ ] Strong `JWT_SECRET` generated (`openssl rand -base64 48`)
- [ ] Strong `rds_password` in terraform.tfvars
- [ ] SSH key permissions: `chmod 400 bookreview-keypair.pem`

### After Deployment
- [ ] Restrict SSH access to your IP only (update SG rules)
- [ ] Enable RDS automated backups
- [ ] Set up CloudWatch alarms for CPU/Memory
- [ ] Configure SSL/TLS (ACM + ALB or Certbot on Nginx)
- [ ] Rotate secrets periodically

### Ansible Vault Usage
```bash
# Encrypt secrets file
ansible-vault encrypt ansible/group_vars/app.yml

# Edit encrypted file
ansible-vault edit ansible/group_vars/app.yml

# Run playbook with vault
ansible-playbook site.yml -i inventory.ini --ask-vault-pass

# Or use password file
ansible-playbook site.yml -i inventory.ini --vault-password-file ~/.vault_pass
```

---

## 🔄 Maintenance Operations

### Application Updates
```bash
# 1. Pull latest code (if using Git tags/branches)
# Update book_review_app_repo_version in roles/web/defaults/main.yml and roles/app/defaults/main.yml

# 2. Re-deploy
ansible-playbook site.yml -i inventory.ini
```

### Scale Up/Down
```bash
# Terraform: Change instance types in terraform.tfvars
frontend_instance_type = "t3.small"
backend_instance_type  = "t3.small"

terraform apply
ansible-playbook site.yml -i inventory.ini
```

### Database Backup
```bash
# Manual backup
mysqldump -h <RDS_ENDPOINT> -u root -p bookreview > backup_$(date +%Y%m%d).sql

# Restore
mysql -h <RDS_ENDPOINT> -u root -p bookreview < backup_20240115.sql
```

### SSL/TLS Setup (Let's Encrypt)
```bash
# On web server
sudo apt install certbot python3-certbot-nginx
sudo certbot --nginx -d yourdomain.com
sudo certbot renew --dry-run
```

---

## 📝 Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2024-06 | Initial production deployment |
| | | Terraform: VPC, EC2, RDS, SG |
| | | Ansible: Node.js 20, Nginx, PM2, Next.js, Express |
| | | DB: Sequelize auto-migration |

---

## 🤝 Contributing

1. Make changes to Terraform/Ansible
2. Test in staging environment
3. Run `terraform fmt` and `ansible-playbook --syntax-check`
4. Submit PR with description of changes

---

## 📄 License

MIT License - Feel free to use for learning or production.

---

## 🔗 Quick Reference Card

```bash
# === FULL DEPLOYMENT ===
cd terraform && terraform init && terraform apply
cd ../ansible
# Update inventory.ini, group_vars/web.yml, group_vars/app.yml
ansible-playbook site.yml -i inventory.ini

# === DAILY OPS ===
ansible web -i inventory.ini -m shell -a "pm2 status" --become --become-user=ubuntu
ansible app -i inventory.ini -m shell -a "pm2 status" --become --become-user=ubuntu

# === LOGS ===
ansible web -i inventory.ini -m shell -a "pm2 logs frontend-book-review-app --lines 100" --become --become-user=ubuntu
ansible app -i inventory.ini -m shell -a "pm2 logs backend-book-review-app --lines 100" --become --become-user=ubuntu

# === REDEPLOY FRONTEND ONLY ===
ansible-playbook site.yml -i inventory.ini --limit web

# === REDEPLOY BACKEND ONLY ===
ansible-playbook site.yml -i inventory.ini --limit app
```