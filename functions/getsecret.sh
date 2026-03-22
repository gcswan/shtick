# @name: getsecret
# @description: Retrieve a secret value from AWS Secrets Manager
# @usage: getsecret <secret-id>
# @platform: AWS CLI

getsecret() {
  local secret_id="${1:?Usage: getsecret <secret-id>}"
  aws secretsmanager get-secret-value \
    --secret-id "$secret_id" \
    --query SecretString \
    --output text \
  | jq -r . || echo "Failed to retrieve secret: $secret_id"
}

alias gsec='getsecret'
