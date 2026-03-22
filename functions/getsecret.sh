# @name: getsecret
# @description: Retrieve a secret value from AWS Secrets Manager
# @usage: getsecret <secret-id>
# @platform: AWS CLI

getsecret() {
  local secret_id="${1:?Usage: getsecret <secret-id>}"

  if ! command -v aws &>/dev/null; then
    echo "getsecret: AWS CLI is not installed" >&2
    return 1
  fi

  if ! aws sts get-caller-identity &>/dev/null; then
    echo "getsecret: not authenticated with AWS (run 'aws configure' or check your credentials)" >&2
    return 1
  fi

  aws secretsmanager get-secret-value \
    --secret-id "$secret_id" \
    --query SecretString \
    --output text \
  | jq -r . || echo "Failed to retrieve secret: $secret_id"
}

alias gsec='getsecret'
