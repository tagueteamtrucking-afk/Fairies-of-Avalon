#!/bin/bash
set -e

# Clean up repository by removing obsolete and duplicate files.
# Run this script from the root of the Fairies-of-Avalon repository.

echo "Starting cleanup..."

# Delete all memory-history snapshots except the latest
if [ -d "memory-history" ]; then
  find memory-history -type f -name "Codys-Memory-*.yaml" ! -name "Codys-Memory-20251021T064919Z.yaml" -exec rm -f {} \;
fi

# Remove deprecated micro-app directories
for dir in pages/apps/clarice pages/apps/themis pages/apps/odessa pages/apps/sorcha; do
  if [ -d "$dir" ]; then
    rm -rf "$dir"
  fi
done

# Remove obsolete subdirectories named 'old' or 'compliance' within pages/apps
if [ -d "pages/apps" ]; then
  find pages/apps -type d -name "old" -exec rm -rf {} +
  find pages/apps -type d -name "compliance" -exec rm -rf {} +
fi

# Remove duplicate or unused assets flagged by cleanup-proposals.json (manual review recommended)
# This script does not automatically remove assets to avoid accidental loss.

# Delete temporary/system files
find . -name "__MACOSX" -type d -exec rm -rf {} +
find . -name "Thumbs.db" -delete
find . -name ".DS_Store" -delete
find . -name "*.tmp" -delete

# Remove placeholder docs
rm -f docs/BUILD-PATH.md docs/RULES.md

echo "Cleanup complete. Please review changes and commit if correct."
