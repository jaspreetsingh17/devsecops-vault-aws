#!/bin/bash
# Vault Setup Script for GitHub OIDC + AWS Secrets Engine
#
# This script automates the Vault configuration for the DevSecOps pipeline.
# 
# Prerequisites:
#   - Vault CLI installed
#   - VAULT_ADDR environment variable set
#   - VAULT_TOKEN environment variable set (with admin access)
#   - jq installed for JSON parsing
#
# Usage:
#   ./scripts/vault-setup.sh <github_org> <github_repo> <aws_account_id> <aws_region>
#
# Example:
#   ./scripts/vault-setup.sh myorg myrepo 123456789012 us-east-1


set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    if ! command -v vault &> /dev/null; then
        echo -e "${RED}Error: vault CLI not found. Please install it first.${NC}"
        exit 1
    fi
    
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: jq not found. Please install it first.${NC}"
        exit 1
    fi
    
    if [ -z "${VAULT_ADDR:-}" ]; then
        echo -e "${RED}Error: VAULT_ADDR environment variable not set.${NC}"
        exit 1
    fi
    
    if [ -z "${VAULT_TOKEN:-}" ]; then
        echo -e "${RED}Error: VAULT_TOKEN environment variable not set.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}[OK] All prerequisites met${NC}"
}

# Parse arguments
parse_arguments() {
    if [ $# -ne 4 ]; then
        echo "Usage: $0 <github_org> <github_repo> <aws_account_id> <aws_region>"
        echo "Example: $0 myorg myrepo 123456789012 us-east-1"
        exit 1
    fi
    
    GITHUB_ORG=$1
    GITHUB_REPO=$2
    AWS_ACCOUNT_ID=$3
    AWS_REGION=$4
    
    echo -e "${YELLOW}Configuration:${NC}"
    echo "  GitHub Org/User:  $GITHUB_ORG"
    echo "  GitHub Repo:      $GITHUB_REPO"
    echo "  AWS Account ID:   $AWS_ACCOUNT_ID"
    echo "  AWS Region:       $AWS_REGION"
}

# Enable and configure JWT auth method
setup_jwt_auth() {
    echo -e "\n${YELLOW}Setting up JWT auth method for GitHub OIDC...${NC}"
    
    # Check if JWT auth is already enabled
    if vault auth list | grep -q 'jwt/'; then
        echo "JWT auth method already enabled"
    else
        vault auth enable jwt
        echo -e "${GREEN}[OK] JWT auth method enabled${NC}"
    fi
    
    # Configure JWT auth with GitHub OIDC
    vault write auth/jwt/config \
        oidc_discovery_url="https://token.actions.githubusercontent.com" \
        bound_issuer="https://token.actions.githubusercontent.com"
    
    echo -e "${GREEN}[OK] JWT auth configured for GitHub OIDC${NC}"
}

# Create JWT role for GitHub Actions
create_jwt_role() {
    echo -e "\n${YELLOW}Creating JWT role for GitHub Actions...${NC}"
    
    vault write auth/jwt/role/github-actions \
        role_type="jwt" \
        bound_audiences="vault" \
        user_claim="repository" \
        bound_claims_type="glob" \
        bound_claims="{\"repository\": \"${GITHUB_ORG}/${GITHUB_REPO}\", \"ref\": \"refs/heads/main\"}" \
        policies="github-s3-creator" \
        ttl="15m" \
        max_ttl="30m"
    
    echo -e "${GREEN}[OK] JWT role 'github-actions' created${NC}"
}

# Enable and configure AWS secrets engine
setup_aws_secrets() {
    echo -e "\n${YELLOW}Setting up AWS secrets engine...${NC}"
    
    # Check if AWS secrets engine is already enabled
    if vault secrets list | grep -q 'aws/'; then
        echo "AWS secrets engine already enabled"
    else
        vault secrets enable aws
        echo -e "${GREEN}[OK] AWS secrets engine enabled${NC}"
    fi
    
    echo -e "${YELLOW}Note: You need to configure AWS credentials manually.${NC}"
    echo "Run the following command with your AWS credentials:"
    echo ""
    echo "  vault write aws/config/root \\"
    echo "      access_key=\"YOUR_ACCESS_KEY\" \\"
    echo "      secret_key=\"YOUR_SECRET_KEY\" \\"
    echo "      region=\"${AWS_REGION}\""
    echo ""
    
    # Configure lease settings
    vault write aws/config/lease \
        lease="15m" \
        lease_max="1h"
    
    echo -e "${GREEN}[OK] AWS secrets engine lease configured (15 min TTL)${NC}"
}

# Create AWS role for S3 operations
create_aws_role() {
    echo -e "\n${YELLOW}Creating AWS role for S3 operations...${NC}"
    
    # Read the policy document
    POLICY_DOC=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:CreateBucket",
        "s3:DeleteBucket",
        "s3:GetBucketLocation",
        "s3:GetBucketVersioning",
        "s3:PutBucketVersioning",
        "s3:GetBucketAcl",
        "s3:PutBucketAcl",
        "s3:GetBucketPolicy",
        "s3:PutBucketPolicy",
        "s3:DeleteBucketPolicy",
        "s3:GetEncryptionConfiguration",
        "s3:PutEncryptionConfiguration",
        "s3:GetBucketPublicAccessBlock",
        "s3:PutBucketPublicAccessBlock",
        "s3:GetBucketOwnershipControls",
        "s3:PutBucketOwnershipControls",
        "s3:ListBucket",
        "s3:GetBucketTagging",
        "s3:PutBucketTagging"
      ],
      "Resource": "*"
    }
  ]
}
EOF
)
    
    vault write aws/roles/s3-creator \
        credential_type="iam_user" \
        policy_document="$POLICY_DOC"
    
    echo -e "${GREEN}[OK] AWS role 's3-creator' created with S3 permissions${NC}"
}

# Apply Vault policy
apply_vault_policy() {
    echo -e "\n${YELLOW}Applying Vault policy...${NC}"
    
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    POLICY_FILE="${SCRIPT_DIR}/../vault-config/policy.hcl"
    
    if [ -f "$POLICY_FILE" ]; then
        vault policy write github-s3-creator "$POLICY_FILE"
        echo -e "${GREEN}[OK] Vault policy 'github-s3-creator' applied${NC}"
    else
        echo -e "${RED}Warning: Policy file not found at $POLICY_FILE${NC}"
        echo "Please apply the policy manually."
    fi
}

# Main function
main() {
    echo "Vault Setup for DevSecOps Pipeline"
    echo ""
    
    check_prerequisites
    parse_arguments "$@"
    
    apply_vault_policy
    setup_jwt_auth
    create_jwt_role
    setup_aws_secrets
    create_aws_role
    
    echo -e "\n${GREEN}Setup Complete!${NC}"
    echo ""
    echo ""
    echo "Next steps:"
    echo "1. Configure AWS credentials in Vault (see instructions above)"
    echo "2. Add these secrets to your GitHub repository:"
    echo "   - VAULT_ADDR: ${VAULT_ADDR}"
    echo "   - VAULT_NAMESPACE: (optional, for HCP Vault)"
    echo "3. Add these variables to your GitHub repository:"
    echo "   - AWS_REGION: ${AWS_REGION}"
    echo "   - S3_BUCKET_NAME: your-bucket-name"
    echo "4. Push to the main branch to trigger the workflow"
}

main "$@"
