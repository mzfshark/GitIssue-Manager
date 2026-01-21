#!/bin/bash

###############################################################################
# GitIssue-Manager: 6-Stage Execution Pipeline (v3 - GitHub Tasks Format)
# Purpose: Automate issue creation with GitHub task format (convertible to sub-issues)
###############################################################################

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPOS_ROOT="${PROJECT_ROOT}/../../"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
AUDIT_LOG="${PROJECT_ROOT}/audit-logs/execution-${TIMESTAMP}.log"
mkdir -p "${PROJECT_ROOT}/audit-logs"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "${AUDIT_LOG}"; }
success() { echo -e "${GREEN}✅ $1${NC}" | tee -a "${AUDIT_LOG}"; }
error() { echo -e "${RED}❌ $1${NC}" | tee -a "${AUDIT_LOG}"; exit 1; }
warning() { echo -e "${YELLOW}⚠️  $1${NC}" | tee -a "${AUDIT_LOG}"; }

# Check if issue exists
issue_exists() {
    local repo="$1"
    local title_pattern="$2"
    local existing=$(gh issue list -R "$repo" --state all --json number,title --jq ".[] | select(.title | test(\"${title_pattern}\")) | .number" 2>/dev/null | head -1)
    echo "$existing"
}

# Create or update issue
create_or_update_issue() {
    local repo="$1"
    local title="$2"
    local body="$3"
    local title_pattern="$4"
    
    local existing_num=$(issue_exists "$repo" "$title_pattern")
    
    if [ -n "$existing_num" ]; then
        warning "Issue #$existing_num já existe em $repo"
        if gh issue edit $existing_num -R "$repo" --body "$body" &>/dev/null; then
            success "Atualizada issue #$existing_num (sem criar duplicata)"
        fi
        echo "$existing_num"
    else
        log "Criando nova issue em $repo..."
        local issue_url=$(gh issue create -R "$repo" --title "$title" --body "$body" 2>&1)
        if [[ $issue_url =~ ([0-9]+)$ ]]; then
            success "Criada issue #${BASH_REMATCH[1]} em $repo"
            echo "${BASH_REMATCH[1]}"
        else
            error "Falha ao criar issue em $repo"
        fi
    fi
}

# Stage setup
stage_setup() {
    log "STAGE 1: SETUP"
    if ! gh auth status &>/dev/null; then
        error "GitHub CLI não autenticado"
    fi
    success "GitHub CLI autenticado"
    
    for repo in "Axodus/AragonOSX" "Axodus/aragon-app" "Axodus/Aragon-app-backend"; do
        if gh repo view "$repo" &>/dev/null; then
            success "Repositório acessível: $repo"
        else
            error "Repositório não acessível: $repo"
        fi
    done
}

# Stage create with tasks format
stage_create() {
    log "STAGE 3: CREATE (com formato GitHub Tasks)"
    declare -A ISSUE_NUMBERS

    # AragonOSX
    issue_num=$(create_or_update_issue "Axodus/AragonOSX" \
      "[AragonOSX | #PLAN-001]: HarmonyVoting E2E Production Rollout" \
      "# PLAN: AragonOSX — HarmonyVoting E2E Production Rollout

**Timeline:** 2026-01-21 to 2026-02-28 (6 weeks)
**Status:** 69% complete (11 of 16 sprint items done)

## Key Metrics
- Total Planned Work: 160 hours
- Completion: 69% (11 of 16 sprint items done)
- Active Features: 4 (Indexing, Uninstall, Metadata, Native-Token)

## Tasks

- [ ] **Indexing Resilience** (40h | high)
  - [ ] Implement robust event indexing for HarmonyVoting plugin events
  - [ ] Add automatic retry logic with exponential backoff
  - [ ] Implement circuit breaker pattern
  - [ ] Dead-letter queue handling for failed events
  - [ ] Ensure idempotency and proper error recovery

- [ ] **Plugin Uninstall (Safety & Cleanup)** (35h | high)
  - [ ] Implement safe plugin uninstallation flow
  - [ ] Full state cleanup and permission revocation
  - [ ] Ensure no orphaned state remains after uninstall
  - [ ] Event generation for indexers/UI reconciliation
  - [ ] Test uninstall with governance permissions

- [ ] **Metadata Redundancy (Resilient Proposal Metadata)** (50h | medium)
  - [ ] Implement redundant proposal metadata storage
  - [ ] IPFS fallback integration
  - [ ] Fallback resolution logic (on-chain → cache → placeholder)
  - [ ] Integrity checks (format validation, size limits)
  - [ ] E2E tests with IPFS unavailability

- [ ] **Native-Token Voting Support** (35h | medium)
  - [ ] Extend HarmonyVoting plugin for native token (ONE) voting
  - [ ] Add native token balance checking
  - [ ] Implement voting power calculation
  - [ ] Update vote casting logic
  - [ ] Test native-token voting scenarios

**Note:** Converta as tasks acima em sub-issues usando a UI do GitHub. Selecione uma task e escolha \"Convert to issue\" no menu." \
      "PLAN-001.*HarmonyVoting E2E")
    ISSUE_NUMBERS["AragonOSX"]="$issue_num"

    # aragon-app
    issue_num=$(create_or_update_issue "Axodus/aragon-app" \
      "[aragon-app | #PLAN-002]: HarmonyVoting Frontend UI & UX Production Release" \
      "# PLAN: aragon-app — HarmonyVoting Frontend UI & UX Production Release

**Timeline:** 2026-01-21 to 2026-02-28 (6 weeks)
**Status:** 45% complete (11 of 26 sprint items done)

## Key Metrics
- Total Planned Work: 120 hours
- Completion: 45% (11 of 26 sprint items done)
- Active Features: 4 (Setup Forms, Install Flows, UI Resilience, Uninstall UX)

## Tasks

- [ ] **Setup Forms (Validator Address Input)** (28h | high)
  - [ ] Create setup form for HarmonyVoting plugin
  - [ ] Validator address input field with validation
  - [ ] ENS resolution support
  - [ ] Address normalization (lowercase)
  - [ ] Error handling and user guidance

- [ ] **Install Flows** (32h | high)
  - [ ] Implement plugin installation flow
  - [ ] Step-by-step wizard interface
  - [ ] Transaction signing and confirmation
  - [ ] Error recovery and retry logic
  - [ ] Blockchain confirmation handling

- [ ] **UI Resilience** (35h | high)
  - [ ] Implement graceful degradation patterns
  - [ ] Handle backend API failures
  - [ ] Missing metadata fallback states
  - [ ] Network error recovery and retry
  - [ ] Fallback UI states when APIs fail

- [ ] **Uninstall UX** (25h | medium)
  - [ ] Create uninstall confirmation flow
  - [ ] Show what happens during uninstall
  - [ ] Verify uninstall completion
  - [ ] Update UI state post-uninstall
  - [ ] Test governance permission checks

**Note:** Converta as tasks acima em sub-issues usando a UI do GitHub. Selecione uma task e escolha \"Convert to issue\" no menu." \
      "PLAN-002.*Frontend UI")
    ISSUE_NUMBERS["aragon-app"]="$issue_num"

    # Aragon-app-backend
    issue_num=$(create_or_update_issue "Axodus/Aragon-app-backend" \
      "[Aragon-app-backend | #PLAN-003]: Backend Architecture & Indexing — Event Pipeline" \
      "# PLAN: Backend Architecture & Indexing — Event Pipeline

**Timeline:** 2026-01-21 to 2026-02-28 (6 weeks)
**Status:** 37% complete (2 DONE, 18 TODO)

## Key Metrics
- Total Planned Work: 165 hours
- Completion: 37% (2 DONE, 18 TODO)
- Critical Path: Event handlers → Indexing resilience → Observability

## Tasks

- [ ] **Event Handlers (VoteCast, Proposal, Execute)** (40h | critical)
  - [ ] Implement VoteCast event handler with vote weight calculation
  - [ ] Implement ProposalCreated event handler (create proposal records)
  - [ ] Implement ProposalExecuted event handler (mark proposals as executed)
  - [ ] Event validation and parsing logic (ensure data integrity)
  - [ ] MongoDB storage with proper indexing (votes, proposals collections)
  - [ ] Reorg detection and block rollback (handle chain reorgs)

- [ ] **Indexing Resilience (Retry logic, Circuit Breakers)** (35h | high)
  - [ ] Implement retry strategy with exponential backoff (1s → 30s max)
  - [ ] Circuit breaker pattern for RPC outages (fail-fast + auto-recover)
  - [ ] Error recovery and handler restart logic (graceful degradation)
  - [ ] Comprehensive reorg tests (1-10 block reorgs + 100-block reorg)
  - [ ] Database connection pooling and health checks (MongoDB)
  - [ ] Dead-letter queue for unprocessable events (manual review queue)

- [ ] **Observability (Prometheus, Logging, Dashboards)** (30h | high)
  - [ ] Add Prometheus metrics (indexing lag, event count, error rate)
  - [ ] Structured logging with Winston (all handler operations)
  - [ ] Grafana dashboards (indexing status, RPC health, DB performance)
  - [ ] Alert rules (lag >60s, error rate >0.1%, RPC unavailable)
  - [ ] Event tracing and performance monitoring (latency histograms)
  - [ ] Alert notification setup (Slack/PagerDuty integration)

- [ ] **Metadata Indexing (IPFS Fallback)** (25h | medium)
  - [ ] Metadata fetch with timeout (IPFS gateway, max 5s)
  - [ ] Fallback chain: on-chain → cache → placeholder
  - [ ] IPFS gateway rotation (multiple gateway URLs for redundancy)
  - [ ] Caching strategy (TTL: 24h valid, 1h failures)
  - [ ] Fetch validation (format check, size limits, safe parsing)
  - [ ] Revalidation on metadata updates

- [ ] **Native-Token Support** (20h | medium)
  - [ ] Add native token (ONE) balance indexing
  - [ ] Implement voting power calculation for native tokens
  - [ ] Support mixed native-token + standard voting scenarios
  - [ ] Test native-token balance updates and recalculations
  - [ ] Add metrics for native-token voting activity
  - [ ] Ensure backward compatibility with standard voting

- [ ] **E2E Testing & Deploy** (15h | high)
  - [ ] End-to-end test suite (event → indexing → API → app consumption)
  - [ ] Deploy to staging and validate against testnet
  - [ ] Performance benchmarking (event throughput, latency)
  - [ ] Smoke tests for all critical flows
  - [ ] Deployment runbook documentation
  - [ ] Monitoring and alerting validation post-deploy

**Note:** Converta as tasks acima em sub-issues usando a UI do GitHub. Selecione uma task e escolha \"Convert to issue\" no menu." \
      "PLAN-003.*Event Pipeline")
    ISSUE_NUMBERS["Aragon-app-backend"]="$issue_num"

    log "STAGE 3 COMPLETE"
    success "AragonOSX:           #${ISSUE_NUMBERS["AragonOSX"]}"
    success "aragon-app:          #${ISSUE_NUMBERS["aragon-app"]}"
    success "Aragon-app-backend:  #${ISSUE_NUMBERS["Aragon-app-backend"]}"
}

# Main
main() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  GitIssue-Manager: Pipeline v3 (GitHub Tasks Format)            ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    stage_setup
    echo ""
    stage_create
    echo ""
    success "PIPELINE COMPLETE"
}

main "$@"
