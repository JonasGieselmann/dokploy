#!/bin/bash
# Update from Dokploy upstream while preserving Cloud Run config
# Usage: ./scripts/update-from-upstream.sh

set -e

echo "=== Dokploy Cloud Run Update Script ==="
echo ""

# Check if upstream remote exists
if ! git remote | grep -q upstream; then
    echo "Adding upstream remote..."
    git remote add upstream https://github.com/Dokploy/dokploy.git
fi

# Fetch upstream
echo "Fetching upstream..."
git fetch upstream main

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
    echo "Error: Please switch to main branch first"
    exit 1
fi

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo "Error: You have uncommitted changes. Please commit or stash them first."
    exit 1
fi

# Backup our config files
echo "Backing up Cloud Run config..."
cp cloudbuild.yaml /tmp/cloudbuild.yaml.bak
cp Dockerfile.cloud /tmp/Dockerfile.cloud.bak
cp -r patches /tmp/patches.bak 2>/dev/null || true

# Merge upstream
echo "Merging upstream/main..."
if git merge upstream/main -m "chore: merge upstream Dokploy updates"; then
    echo "Merge successful!"
else
    echo ""
    echo "=== MERGE CONFLICT ==="
    echo "Resolve conflicts, then run:"
    echo "  git add ."
    echo "  git commit"
    echo "  git push"
    echo ""
    echo "Your Cloud Run configs are backed up in /tmp/"
    exit 1
fi

# Restore our config files (in case they were modified)
echo "Restoring Cloud Run config..."
cp /tmp/cloudbuild.yaml.bak cloudbuild.yaml
cp /tmp/Dockerfile.cloud.bak Dockerfile.cloud
cp -r /tmp/patches.bak patches 2>/dev/null || true

# Test if patches still apply
echo "Testing patches..."
PATCH_OK=true
for patch in patches/*.patch; do
    if [ -f "$patch" ]; then
        if ! patch -p1 --dry-run < "$patch" > /dev/null 2>&1; then
            echo "WARNING: Patch $patch may need updating!"
            PATCH_OK=false
        fi
    fi
done

if [ "$PATCH_OK" = true ]; then
    echo "All patches apply cleanly!"
else
    echo ""
    echo "=== PATCH UPDATE NEEDED ==="
    echo "Some patches may not apply cleanly after the update."
    echo "Please check and regenerate patches if needed:"
    echo "  1. Make the code change manually"
    echo "  2. git diff <file> > patches/<name>.patch"
    echo "  3. git checkout <file>"
    echo ""
fi

# Commit restored configs
git add cloudbuild.yaml Dockerfile.cloud patches/
if ! git diff-index --quiet HEAD --; then
    git commit -m "chore: restore Cloud Run config after upstream merge"
fi

echo ""
echo "=== Update Complete ==="
echo "Push to deploy: git push"
