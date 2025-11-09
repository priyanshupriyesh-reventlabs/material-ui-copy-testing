#!/bin/bash
# generate_closed_prs_only_final.sh
# macOS-safe: creates 10 closed PRs, 3 reusing existing open PRs

set -e

REPO="priyanshupriyesh-reventlabs/material-ui-copy-testing"
BASE_BRANCH="master"
CLOSED_COUNT=10
SHARED_OPEN_COUNT=3

echo "🏗️  Creating $CLOSED_COUNT closed PRs ($SHARED_OPEN_COUNT reusing existing open PRs)..."
echo "📦 Repo: $REPO"
echo "🌿 Base branch: $BASE_BRANCH"

# Step 1: Fetch open PR branches
echo "🔍 Fetching open PRs..."
OPEN_BRANCHES=$(gh pr list --state open --json headRefName -q '.[].headRefName')
if [ -z "$OPEN_BRANCHES" ]; then
    echo "❌ No open PRs found. Exiting."
    exit 1
fi

# Convert to array
OPEN_ARRAY=()
while read -r branch; do
    OPEN_ARRAY+=("$branch")
done <<< "$OPEN_BRANCHES"

# Step 2: Initialize used indices array
USED_INDICES=()

# Step 3: Create closed PRs
for i in $(seq 1 $CLOSED_COUNT); do
    if [ $i -le $SHARED_OPEN_COUNT ]; then
        # Reuse an existing open branch
        # pick next unused index
        INDEX=$((i-1))
        BRANCH="${OPEN_ARRAY[$INDEX]}"
        echo "♻️  Reusing open branch for closed PR: $BRANCH"
    else
        # Create a new closed branch
        BRANCH="closed-$(date +%s)-$i"
        git checkout -b "$BRANCH" "$BASE_BRANCH"
        FILE_NAME="closed_pr_$i.txt"
        echo "This is test closed PR $i" > "$FILE_NAME"
        git add "$FILE_NAME"
        git commit -m "Add closed PR $i file"
        git push origin "$BRANCH"
        echo "📦 Created closed branch: $BRANCH"
    fi

    # Create draft PR
    echo "📝 Creating draft PR for $BRANCH → $BASE_BRANCH"
    gh pr create --head "$BRANCH" --base "$BASE_BRANCH" --title "Closed PR $i" --body "This is closed PR $i" --draft || true
done

# Step 4: Return to base branch
git checkout "$BASE_BRANCH"
echo "✅ Done creating closed PRs."

