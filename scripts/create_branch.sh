#!/usr/bin/env bash
set -euo pipefail

# --- Optional: load a local .env if present ---
if [[ -f .env ]]; then set -a; source .env; set +a; fi

# Accept either GH_TOKEN or GITHUB_TOKEN
: "${GITHUB_TOKEN:=${GH_TOKEN:-}}"

# Required settings for this step
REQUIRED_VARS=(GITHUB_TOKEN GH_OWNER GH_REPO BASE_BRANCH NEW_BRANCH)

missing=()
for v in "${REQUIRED_VARS[@]}"; do
  [[ -n "${!v:-}" ]] || missing+=("$v")
done

if ((${#missing[@]})); then
  echo "❌ Missing required environment variables: ${missing[*]}"
  cat <<'USAGE'

Required vars for "Create Branch" step:
  - GITHUB_TOKEN (or GH_TOKEN): GitHub token with "repo" scope
  - GH_OWNER: GitHub org/user, e.g. "acme-inc"
  - GH_REPO: Existing repo name, e.g. "platform-monorepo"
  - BASE_BRANCH: Base branch to branch from, e.g. "main"
  - NEW_BRANCH: New branch name, e.g. "idp/new-app-2025-09-09"

Quick start (copy/paste and edit):
  export GH_TOKEN=ghp_xxx
  export GH_OWNER=acme-inc
  export GH_REPO=platform-monorepo
  export BASE_BRANCH=main
  export NEW_BRANCH="idp/app-template-$(date +%Y%m%d%H%M)"

Tip: You can also put these in a local .env file next to the script.

USAGE
  exit 2
fi

# --- Tooling check & strategy (gh preferred, fallback to curl+jq) ---
have() { command -v "$1" >/dev/null 2>&1; }
USE_GH=false
if have gh; then
  # If gh is logged in, we don't strictly need GITHUB_TOKEN for the API calls,
  # but we've already required it above for consistency with pipelines.
  USE_GH=true
elif ! have jq || ! have curl; then
  echo "❌ Need either GitHub CLI ('gh') or both 'curl' and 'jq' installed." >&2
  exit 3
fi

repo="${GH_OWNER}/${GH_REPO}"

echo "➡️  Creating branch '${NEW_BRANCH}' from '${BASE_BRANCH}' in ${repo}..."

set +e
if $USE_GH; then
  base_sha=$(gh api "repos/${repo}/git/ref/heads/${BASE_BRANCH}" --jq '.object.sha') || {
    echo "❌ Could not read base branch '${BASE_BRANCH}'. Does it exist?" >&2; exit 4; }
  # Try to create the ref
  gh api -X POST "repos/${repo}/git/refs" \
    -f ref="refs/heads/${NEW_BRANCH}" -f sha="${base_sha}" >/dev/null 2>&1
  status=$?
else
  API="https://api.github.com"
  AUTH=(-H "Authorization: Bearer ${GITHUB_TOKEN}" -H "Accept: application/vnd.github+json")
  base_sha=$(curl -fsSL "${AUTH[@]}" "${API}/repos/${repo}/git/ref/heads/${BASE_BRANCH}" | jq -r '.object.sha') || {
    echo "❌ Could not read base branch '${BASE_BRANCH}'. Does it exist?" >&2; exit 4; }
  resp=$(mktemp)
  code=$(jq -n --arg ref "refs/heads/${NEW_BRANCH}" --arg sha "$base_sha" '{ref:$ref,sha:$sha}' |
         curl -sS -w "%{http_code}" -o "$resp" -X POST "${AUTH[@]}" \
         -d @- "${API}/repos/${repo}/git/refs")
  if [[ "$code" == "201" ]]; then
    status=0
  else
    # 422 likely means branch exists already
    if grep -qi 'reference already exists' "$resp"; then status=99; else status=1; fi
  fi
  rm -f "$resp"
fi
set -e

case $status in
  0)  echo "✅ Created branch '${NEW_BRANCH}' (from ${BASE_BRANCH} @ ${base_sha:0:8})." ;;
  99) echo "ℹ️  Branch '${NEW_BRANCH}' already exists. Nothing to do." ;;
  *)  echo "❌ Failed to create branch. Check token scopes and permissions." >&2; exit 5 ;;
esac
