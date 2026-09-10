#!/bin/bash

OG_BRANCH=$(git branch --show-current)

echo "==========================================="
echo "rebasing with main branch"
echo "==========================================="
echo ""

echo "step 1: updating main branch..."
git checkout main
git pull
echo ""

echo "step 2: rebasing dev with main..."
git checkout dev
git pull
git rebase main
git push --force-with-lease
echo ""

echo "==========================================="
echo "rebased successfully!"
echo "==========================================="

git checkout "$OG_BRANCH"
