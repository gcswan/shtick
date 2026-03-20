# Shared exclude list for pack functions (no @name header — not a shtick function)
SHTICK_EXCLUDES=(
  .git node_modules .next dist build .cache
  __pycache__ .venv venv .terraform vendor
  coverage .turbo
  lazy-lock.json package-lock.json yarn.lock pnpm-lock.yaml
)
