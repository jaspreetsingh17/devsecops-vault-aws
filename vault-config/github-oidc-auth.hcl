# Vault JWT Auth Method Configuration for GitHub OIDC
# 
# This configures Vault to trust GitHub's OIDC provider.
# Run these commands on your Vault server to set up GitHub OIDC authentication.
#
# Prerequisites:
#   - Vault CLI installed and configured
#   - VAULT_ADDR and VAULT_TOKEN environment variables set
#   - Admin access to Vault

# Step 1: Enable the JWT auth method
# vault auth enable jwt

# Step 2: Configure the JWT auth method with GitHub's OIDC settings
path "auth/jwt/config" {
  # GitHub's OIDC discovery URL
  oidc_discovery_url = "https://token.actions.githubusercontent.com"
  
  # Bound issuer (must match GitHub's issuer)
  bound_issuer = "https://token.actions.githubusercontent.com"
}

# CLI Commands to run (copy and paste into terminal):
#
# # Enable JWT auth method
# vault auth enable jwt
#
# # Configure JWT auth method for GitHub OIDC
# vault write auth/jwt/config \
#     oidc_discovery_url="https://token.actions.githubusercontent.com" \
#     bound_issuer="https://token.actions.githubusercontent.com"
#
# # Create a role for GitHub Actions (update GITHUB_ORG and GITHUB_REPO)
# vault write auth/jwt/role/github-actions \
#     role_type="jwt" \
#     bound_audiences="vault" \
#     user_claim="repository" \
#     bound_claims_type="glob" \
#     bound_claims='{"repository": "GITHUB_ORG/GITHUB_REPO", "ref": "refs/heads/main"}' \
#     policies="github-s3-creator" \
#     ttl="15m" \
#     max_ttl="30m"
