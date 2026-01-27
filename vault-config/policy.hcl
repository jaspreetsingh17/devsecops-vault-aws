# Vault Policy for GitHub Actions S3 Creator
#
# This policy allows GitHub Actions to:
#   1. Read AWS credentials from the AWS secrets engine
#   2. Manage its own token
#
# Apply this policy:
#   vault policy write github-s3-creator vault-config/policy.hcl

# Allow reading AWS credentials for the s3-creator role
path "aws/creds/s3-creator" {
  capabilities = ["read"]
}

# Allow looking up the credentials lease
path "sys/leases/lookup" {
  capabilities = ["update"]
}

# Allow renewing the credentials lease
path "sys/leases/renew" {
  capabilities = ["update"]
}

# Allow revoking the credentials lease
path "sys/leases/revoke" {
  capabilities = ["update"]
}

# Allow the token to look up its own properties
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

# Allow the token to renew itself
path "auth/token/renew-self" {
  capabilities = ["update"]
}

# Allow the token to revoke itself
path "auth/token/revoke-self" {
  capabilities = ["update"]
}
