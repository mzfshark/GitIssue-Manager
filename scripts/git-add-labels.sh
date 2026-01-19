#!/bin/bash
set -e

echo "🏷️ Creating labels across all repositories..."

# AragonOSX (apenas faltantes)
echo "📦 AragonOSX..."
gh label create "indexing" --color "0E8A16" --description "Event indexing and blockchain synchronization" --repo Axodus/AragonOSX 2>/dev/null || echo "  ⚠️ 'indexing' already exists"
gh label create "subtask" --color "FBCA04" --description "Sub-task of epic" --repo Axodus/AragonOSX 2>/dev/null || echo "  ⚠️ 'subtask' already exists"
gh label create "enhancement" --color "a2eeef" --description "New feature or improvement" --repo Axodus/AragonOSX 2>/dev/null || echo "  ⚠️ 'enhancement' already exists"
gh label create "breaking-change" --color "D93F0B" --description "Breaking compatibility change" --repo Axodus/AragonOSX 2>/dev/null || echo "  ⚠️ 'breaking-change' already exists"
gh label create "security" --color "B60205" --description "Security" --repo Axodus/AragonOSX 2>/dev/null || echo "  ⚠️ 'security' already exists"
gh label create "testing" --color "1D76DB" --description "Tests" --repo Axodus/AragonOSX 2>/dev/null || echo "  ⚠️ 'testing' already exists"

# Backend
echo "📦 Aragon-app-backend..."
for label in "epic:7057ff:High-level issue grouping sub-tasks" \
             "harmony:58721b:Harmony Voting protocol related" \
             "backend:b25c45:Backend/indexer changes" \
             "indexing:0E8A16:Event indexing and blockchain sync" \
             "subtask:FBCA04:Sub-task of epic" \
             "enhancement:a2eeef:New feature or improvement" \
             "bug:d73a4a:Bug fix" \
             "documentation:0075ca:Documentation updates" \
             "breaking-change:D93F0B:Breaking compatibility change" \
             "security:B60205:Security" \
             "testing:1D76DB:Tests"; do
  IFS=':' read -r name color desc <<< "$label"
  gh label create "$name" --color "$color" --description "$desc" --repo Axodus/Aragon-app-backend 2>/dev/null || echo "  ⚠️ '$name' already exists"
done

# Frontend
echo "📦 aragon-app..."
for label in "epic:7057ff:High-level issue grouping sub-tasks" \
             "harmony:58721b:Harmony Voting protocol related" \
             "frontend:afdbf8:UI/app changes" \
             "ui:084683:User interface improvements" \
             "subtask:FBCA04:Sub-task of epic" \
             "enhancement:a2eeef:New feature or improvement" \
             "bug:d73a4a:Bug fix" \
             "documentation:0075ca:Documentation updates" \
             "breaking-change:D93F0B:Breaking compatibility change" \
             "security:B60205:Security" \
             "testing:1D76DB:Tests"; do
  IFS=':' read -r name color desc <<< "$label"
  gh label create "$name" --color "$color" --description "$desc" --repo Axodus/aragon-app 2>/dev/null || echo "  ⚠️ '$name' already exists"
done

# Contracts
echo "📦 osx-plugin-foundry..."
for label in "epic:7057ff:High-level issue grouping sub-tasks" \
             "harmony:58721b:Harmony Voting protocol related" \
             "contracts:9083c4:Smart contract changes" \
             "plugin:1d57f4:Plugin related" \
             "subtask:FBCA04:Sub-task of epic" \
             "enhancement:a2eeef:New feature or improvement" \
             "bug:d73a4a:Bug fix" \
             "documentation:0075ca:Documentation updates" \
             "breaking-change:D93F0B:Breaking compatibility change" \
             "security:B60205:Security" \
             "testing:1D76DB:Tests"; do
  IFS=':' read -r name color desc <<< "$label"
  gh label create "$name" --color "$color" --description "$desc" --repo mzfshark/osx-plugin-foundry 2>/dev/null || echo "  ⚠️ '$name' already exists"
done

echo "✅ All labels created!"
