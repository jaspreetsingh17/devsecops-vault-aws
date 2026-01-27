# DevSecOps: GitHub Actions + HashiCorp Vault OIDC + AWS Terraform

A secure DevSecOps pipeline demonstrating zero-trust credential management using GitHub Actions, HashiCorp Vault OIDC integration, and Terraform for AWS S3 bucket creation.

## Security Features

| Feature | Description |
|---------|-------------|
| **No Static Credentials** | GitHub Actions uses OIDC tokens, no secrets stored in GitHub |
| **Short-lived AWS Credentials** | 15-minute TTL credentials from Vault |
| **Least Privilege** | Minimal IAM permissions for S3 operations only |
| **Audit Trail** | Full audit logging in Vault for all credential requests |
| **Token Revocation** | Vault tokens are revoked after workflow completion |

## Project Structure

- `.github/workflows/deploy-s3.yml` - GitHub Actions workflow
- `terraform/main.tf` - S3 bucket configuration
- `terraform/variables.tf` - Terraform variables  
- `terraform/outputs.tf` - Terraform outputs
- `terraform/providers.tf` - AWS provider configuration
- `vault-config/github-oidc-auth.hcl` - Vault OIDC auth config
- `vault-config/aws-secrets-engine.hcl` - AWS secrets engine config
- `vault-config/policy.hcl` - Vault policy for GitHub
- `aws-iam/vault-trust-policy.json` - IAM role trust policy
- `aws-iam/s3-permissions-policy.json` - IAM permissions for S3
- `scripts/vault-setup.sh` - Automated Vault setup script

## Quick Start

### Prerequisites

- [HashiCorp Vault](https://www.vaultproject.io/) instance (self-hosted or HCP Vault)
- AWS account with admin access
- GitHub repository with Actions enabled
- [Terraform](https://www.terraform.io/) CLI (for local testing)
- [Vault CLI](https://www.vaultproject.io/downloads)

### Step 1: Configure Vault

#### Option A: Automated Setup

```bash
# Set Vault environment variables
export VAULT_ADDR="https://your-vault-server:8200"
export VAULT_TOKEN="your-root-or-admin-token"

# Run the setup script
chmod +x scripts/vault-setup.sh
./scripts/vault-setup.sh <github_org> <github_repo> <aws_account_id> <aws_region>

# Example:
./scripts/vault-setup.sh mycompany my-devsecops-repo 123456789012 us-east-1
```

#### Option B: Manual Setup

1. **Enable JWT Auth Method:**
   ```bash
   vault auth enable jwt
   
   vault write auth/jwt/config \
       oidc_discovery_url="https://token.actions.githubusercontent.com" \
       bound_issuer="https://token.actions.githubusercontent.com"
   ```

2. **Create JWT Role for GitHub Actions:**
   ```bash
   vault write auth/jwt/role/github-actions \
       role_type="jwt" \
       bound_audiences="vault" \
       user_claim="repository" \
       bound_claims_type="glob" \
       bound_claims='{"repository": "YOUR_ORG/YOUR_REPO", "ref": "refs/heads/main"}' \
       policies="github-s3-creator" \
       ttl="15m" \
       max_ttl="30m"
   ```

3. **Enable AWS Secrets Engine:**
   ```bash
   vault secrets enable aws
   
   vault write aws/config/root \
       access_key="YOUR_VAULT_AWS_ACCESS_KEY" \
       secret_key="YOUR_VAULT_AWS_SECRET_KEY" \
       region="us-east-1"
   
   vault write aws/config/lease \
       lease="15m" \
       lease_max="1h"
   ```

4. **Create AWS Role:**
   ```bash
   vault write aws/roles/s3-creator \
       credential_type="iam_user" \
       policy_document=@aws-iam/s3-permissions-policy.json
   ```

5. **Apply Vault Policy:**
   ```bash
   vault policy write github-s3-creator vault-config/policy.hcl
   ```

### Step 2: Configure GitHub Repository

1. **Add Repository Secrets:**
   - Go to: `Settings` → `Secrets and variables` → `Actions`
   - Add secret: `VAULT_ADDR` = `https://your-vault-server:8200`
   - (Optional) Add secret: `VAULT_NAMESPACE` = `admin` (for HCP Vault)

2. **Add Repository Variables:**
   - Go to: `Settings` → `Secrets and variables` → `Actions` → `Variables`
   - Add variable: `AWS_REGION` = `us-east-1`
   - Add variable: `S3_BUCKET_NAME` = `my-devsecops-bucket`

### Step 3: Trigger the Pipeline

Push a change to the `main` branch:

```bash
git add .
git commit -m "Initial DevSecOps pipeline"
git push origin main
```

The workflow will:
1. Authenticate to Vault using GitHub OIDC
2. Request temporary AWS credentials (15-minute TTL)
3. Run Terraform to create the S3 bucket
4. Revoke Vault token after completion

## Configuration Options

### Terraform Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `bucket_name` | Base name for S3 bucket | `devsecops-demo-bucket` |
| `aws_region` | AWS region | `us-east-1` |
| `environment` | Environment tag | `development` |

### Customizing Vault JWT Claims

To restrict which branches/workflows can access credentials, modify the `bound_claims` in the JWT role:

```bash
vault write auth/jwt/role/github-actions \
    bound_claims='{
      "repository": "myorg/myrepo",
      "ref": "refs/heads/main",
      "workflow": "Deploy S3 Bucket with Vault OIDC"
    }' \
    # ... other settings
```

### Changing Credential TTL

To modify the 15-minute TTL, update the AWS secrets engine configuration:

```bash
vault write aws/config/lease \
    lease="30m" \
    lease_max="2h"
```

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| "Failed to authenticate to Vault" | Check that the JWT role `bound_claims` matches your repo/branch |
| "Failed to get AWS credentials" | Verify Vault has valid AWS credentials configured |
| "Terraform apply failed" | Check AWS permissions in `s3-permissions-policy.json` |
| "OIDC token not available" | Ensure `id-token: write` permission is set in workflow |

### Debugging

Enable verbose logging in the workflow by adding:

```yaml
env:
  ACTIONS_RUNNER_DEBUG: true
  ACTIONS_STEP_DEBUG: true
```

### Viewing Vault Audit Logs

```bash
vault audit list
vault read sys/audit
```

## References

- [GitHub Actions OIDC Documentation](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
- [Vault JWT Auth Method](https://developer.hashicorp.com/vault/docs/auth/jwt)
- [Vault AWS Secrets Engine](https://developer.hashicorp.com/vault/docs/secrets/aws)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## License

MIT License - See [LICENSE](LICENSE) for details.
