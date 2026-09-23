#!/bin/bash

# Exit if any error
set -e

BRANCH=$(git rev-parse --abbrev-ref HEAD)

echo "📌 Current branch: $BRANCH"

# Step 1: Go to main
echo "➡️ Switching to main..."
git checkout main

# Step 2: Pull latest changes from fork
echo "⬇️ Pulling latest changes from origin/main..."
git pull origin main

# Step 3: Go back to original branch
echo "🔙 Switching back to $BRANCH..."
git checkout "$BRANCH"

# Step 4: Merge main into current branch
echo "🔀 Merging main into $BRANCH..."
git merge main

echo "✅ Branch updated successfully!"