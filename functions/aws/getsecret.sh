# @name: getsecret
# @description: Retrieve a secret value from AWS Secrets Manager
# @usage: getsecret <secret-id> [key]
# @platform: AWS CLI

getsecret() {
  local secret_id="${1:?Usage: getsecret <secret-id> [key]}"
  local key="$2"

  if ! command -v aws &>/dev/null; then
    echo "getsecret: AWS CLI is not installed" >&2
    return 1
  fi

  if ! aws sts get-caller-identity &>/dev/null; then
    echo "getsecret: not authenticated with AWS (run 'aws configure' or check your credentials)" >&2
    return 1
  fi

  local secret
  secret=$(aws secretsmanager get-secret-value \
    --secret-id "$secret_id" \
    --query SecretString \
    --output text) || { echo "Failed to retrieve secret: $secret_id" >&2; return 1; }

  if [[ -n "$key" ]]; then
    jq -r --arg k "$key" '.[$k] // empty' <<< "$secret"
  else
    jq -r . <<< "$secret"
  fi
}
