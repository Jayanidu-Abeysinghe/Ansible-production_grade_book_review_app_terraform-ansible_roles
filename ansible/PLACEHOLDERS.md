# Post-Terraform Placeholder Replacement Guide

After running Terraform, replace the following placeholders in Ansible configuration files:

## Inventory File: `inventory.ini`

| Placeholder | Description | Source |
|-------------|-------------|--------|
| `<frontend_ip>` | Public IP of the web server (frontend + nginx) | Terraform output: `web_server_public_ip` |
| `<backend_ip>` | Private IP of the app server (backend) | Terraform output: `app_server_private_ip` |
| `ansible_ssh_private_key_file=''` | Path to SSH private key for Ubuntu user | Local path to your `.pem` key file |

## Group Variables: `group_vars/web.yml`

| Placeholder | Description | Source |
|-------------|-------------|--------|
| `<private_ip>` | **Private IP of the app server** (backend) | Terraform output: `app_server_private_ip` |

## Group Variables: `group_vars/app.yml`

| Placeholder | Description | Source |
|-------------|-------------|--------|
| `<RDS_OR_MYSQL_HOST>` | RDS MySQL endpoint | Terraform output: `rds_endpoint` (without port) |
| `YourSecret123` | Database password | Terraform output: `rds_password` or your secret manager |
| `mysecretkey` | JWT secret for authentication | Generate strong random string (64+ chars) |
| `http://<FRONTEND_DOMAIN>:3000` | Frontend URL for CORS | Your actual frontend domain (e.g., `https://books.example.com`) |

## Nginx Configuration (Auto-populated via `group_vars/web.yml`)

The `api_private_ip` in `web.yml` is used in nginx template to proxy `/api/` to backend.
- **Must be**: `<app_server_private_ip>:3001` (no `http://` prefix, no trailing slash)

## Example After Replacement

### `inventory.ini`
```ini
[web]
54.123.45.67

[app]
10.0.1.50

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/my-key.pem
ansible_python_interpreter=/usr/bin/python3
```

### `group_vars/web.yml`
```yaml
api_private_ip: "10.0.1.50:3001"
```

### `group_vars/app.yml`
```yaml
DB_HOST: "my-rds-instance.xyz.us-east-1.rds.amazonaws.com"
DB_PORT: 3306
DB_USER: "root"
DB_PASS: "SuperSecretPasswordFromTerraform"
DB_NAME: "bookreview"
DB_DIALECT: "mysql"
DB_SSL: true
PORT: 3001
NODE_ENV: "production"
JWT_SECRET: "a-very-long-random-string-generated-securely"
ALLOWED_ORIGINS: "https://books.example.com"
```

## Verification Checklist

After replacement, verify:
- [ ] `ansible-inventory -i inventory.ini --list` shows correct hosts
- [ ] `ansible all -i inventory.ini -m ping` succeeds
- [ ] `ansible-playbook site.yml --syntax-check` passes
- [ ] Dry-run: `ansible-playbook site.yml -i inventory.ini --check`

## Security Notes

- **Never commit real secrets to git**
- Consider using Ansible Vault for `group_vars/app.yml`
- RDS password should come from AWS Secrets Manager or Terraform sensitive output
- JWT_SECRET must be cryptographically random (use `openssl rand -base64 48`)
