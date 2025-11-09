#!/bin/bash
set -euo pipefail

echo "🏗️  Creating 10 closed PRs (3 reusing existing open PRs)..."

REPO=$(gh repo view --json nameWithOwner -q .nameWithOwner)
BASE_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD | cut -d'/' -f2 || echo "master")

echo "📦 Repo: $REPO"
echo "🌿 Base branch: $BASE_BRANCH"

# Get all open PR branches
OPEN_BRANCHES=()
while IFS= read -r branch; do
  OPEN_BRANCHES+=("$branch")
done < <(gh pr list --state open --json headRefName -q '.[].headRefName')

if [ ${#OPEN_BRANCHES[@]} -lt 3 ]; then
  echo "❌ Need at least 3 open PRs to reuse. Found ${#OPEN_BRANCHES[@]}."
  exit 1
fi

# Pick 3 random distinct indices
TOTAL_OPEN=${#OPEN_BRANCHES[@]}
USED_INDICES=()
REUSED_BRANCHES=()

while [ ${#REUSED_BRANCHES[@]} -lt 3 ]; do
  IDX=$((RANDOM % TOTAL_OPEN))
  if [[ ! " ${USED_INDICES[*]} " =~ " ${IDX} " ]]; then
    USED_INDICES+=("$IDX")
    REUSED_BRANCHES+=("${OPEN_BRANCHES[$IDX]}")
  fi
done

echo "♻️  Will reuse these open PR branches:"
for b in "${REUSED_BRANCHES[@]}"; do echo "   - $b"; done

# --- Create 7 new branches and close them ---
for i in $(seq 1 7); do
  BRANCH="closed-$(date +%s)-$i"
  echo "🚀 Creating closed PR branch: $BRANCH"
  git checkout "$BASE_BRANCH" >/dev/null 2>&1
  git pull origin "$BASE_BRANCH" >/dev/null 2>&1
  git checkout -b "$BRANCH"
  echo "Closed PR test file $i" > "closed_pr_$i.txt"
  git add "closed_pr_$i.txt"
  git commit -m "Add closed PR test file $i"
  git push -u origin "$BRANCH"
  gh pr create --title "Closed PR $i" --body "Auto-generated closed PR $i" --base "$BASE_BRANCH" --head "$BRANCH" --draft
  PR_NUM=$(gh pr list --state open --json number,headRefName -q ".[] | select(.headRefName==\"$BRANCH\") | .number")
  if [ -n "$PR_NUM" ]; then
    echo "❌ Closing PR #$PR_NUM..."
    gh pr close "$PR_NUM" --delete-branch || true
  fi
done

# --- Reuse 3 open branches for closed PRs ---
for BRANCH in "${REUSED_BRANCHES[@]}"; do
  echo "♻️  Creating closed PR reusing branch: $BRANCH"
  gh pr create --title "Closed (Reused) $BRANCH" --body "Closed PR reusing open branch $BRANCH" --base "$BASE_BRANCH" --head "$BRANCH" --draft || true
  PR_NUM=$(gh pr list --state open --json number,headRefName -q ".[] | select(.headRefName==\"$BRANCH\") | .number")
  if [ -n "$PR_NUM" ]; then
    echo "❌ Closing reused PR #$PR_NUM..."
    gh pr close "$PR_NUM" || true
  fi
done

echo "✅ Done! Created 10 closed PRs (7 new, 3 reused)."

