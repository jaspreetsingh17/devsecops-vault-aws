# Vault AWS Secrets Engine Configuration
#
# This configures Vault's AWS secrets engine to generate temporary credentials.
# The credentials will have a 15-minute TTL as requested.
#
# Prerequisites:
#   - Vault CLI installed and configured
#   - AWS IAM role created for Vault to assume (see aws-iam/vault-trust-policy.json)
#   - VAULT_ADDR and VAULT_TOKEN environment variables set

# CLI Commands to run (copy and paste into terminal):
#
# # Enable the AWS secrets engine
# vault secrets enable aws
#
# # Configure the AWS secrets engine with your credentials
# # Option 1: Using IAM User credentials (for Vault to manage IAM)
# vault write aws/config/root \
#     access_key="YOUR_VAULT_AWS_ACCESS_KEY" \
#     secret_key="YOUR_VAULT_AWS_SECRET_KEY" \
#     region="us-east-1"
#
# # Option 2: Using IAM Role (recommended - for EC2/ECS hosted Vault)
# # If Vault is running on AWS with an IAM role attached, no credentials needed
# vault write aws/config/root \
#     region="us-east-1"
#
# # Configure lease settings (15 minute default TTL)
# vault write aws/config/lease \
#     lease="15m" \
#     lease_max="1h"
#
# # Create a role that generates STS credentials for S3 operations
# vault write aws/roles/s3-creator \
#     credential_type="assumed_role" \
#     role_arns="arn:aws:iam::YOUR_AWS_ACCOUNT_ID:role/VaultS3CreatorRole" \
#     default_sts_ttl="15m" \
#     max_sts_ttl="1h"
#
# # Alternative: Create a role with inline policy (if not using assumed role)
# vault write aws/roles/s3-creator \
#     credential_type="iam_user" \
#     policy_document=-<<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Action": [
#         "s3:CreateBucket",
#         "s3:DeleteBucket",
#         "s3:GetBucketLocation",
#         "s3:GetBucketVersioning",
#         "s3:PutBucketVersioning",
#         "s3:GetBucketAcl",
#         "s3:PutBucketAcl",
#         "s3:GetBucketPolicy",
#         "s3:PutBucketPolicy",
#         "s3:DeleteBucketPolicy",
#         "s3:GetEncryptionConfiguration",
#         "s3:PutEncryptionConfiguration",
#         "s3:GetBucketPublicAccessBlock",
#         "s3:PutBucketPublicAccessBlock",
#         "s3:GetBucketOwnershipControls",
#         "s3:PutBucketOwnershipControls",
#         "s3:ListBucket",
#         "s3:GetBucketTagging",
#         "s3:PutBucketTagging"
#       ],
#       "Resource": "*"
#     }
#   ]
# }
# EOF
