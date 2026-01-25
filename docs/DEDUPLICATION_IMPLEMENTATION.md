# Execute Pipeline v2 - Deduplication Notes

## Problem

The original pipeline could create duplicate issues when the same logical work item was re-parsed with a different identifier (e.g., moved lines, edited text).

Example (duplicates):
```
AragonOSX PLAN-001:
❌ #429 - HarmonyVoting E2E Production Rollout (DUPLICATE)
❌ #430 - HarmonyVoting E2E Production Rollout (DUPLICATE - typo PLAN-00)
✅ #431 - HarmonyVoting E2E Production Rollout (CORRECT)
```

---

## Current dedupe strategy (Option A)

GitIssue-Manager now supports a canonical identity tag:

- Add `[key:<canonical-key>]` to checklist items.

Recommended format: ULID (26 chars, time-sortable). You can auto-inject missing keys with:

- `gitissuer rekey --repo <owner/name> --dry-run`
- `gitissuer rekey --repo <owner/name> --confirm`

When `key` is present:

- `StableId` is derived from `key` (instead of file/line/rawText), so it remains stable across moves/edits.
- GitHub issue bodies include `Key: <canonical-key>`.
- The executor dedupes by `Key` first, then falls back to `StableId` (backward compatible).

## Legacy notes (title-regex)

Older iterations used title-pattern matching to avoid duplicates. This is fragile and should not be treated as the source of truth.

**O que faz:**
- Verifica se uma issue com o padrão de título já existe
- Busca em **todas as issues** (abertas + fechadas)
- Retorna o número da issue encontrada ou string vazia

---

### 2. Função Principal: `create_or_update_issue()`

```bash
create_or_update_issue() {
    local repo="$1"
    local title="$2"
    local body="$3"
    local title_pattern="$4"  # Padrão de busca
    
    # PASSO 1: Verificar se existe
    local existing_num=$(issue_exists "$repo" "$title_pattern")
    
    if [ -n "$existing_num" ]; then
        # PASSO 2A: Se existe, ATUALIZAR
        warning "Issue #$existing_num já existe em $repo"
        gh issue edit $existing_num -R "$repo" --body "$body"
        echo "$existing_num"
    else
        # PASSO 2B: Se não existe, CRIAR
        local issue_url=$(gh issue create -R "$repo" --title "$title" --body "$body")
        # Extrair número e retornar
        echo "${BASH_REMATCH[1]}"
    fi
}
```

**Fluxo de Decisão:**
```
┌─────────────────────────────────┐
│ Executar Pipeline               │
└──────────────┬──────────────────┘
               │
               ▼
┌─────────────────────────────────┐
│ Issue já existe?                │
└──────┬────────────────┬─────────┘
       │                │
      SIM              NÃO
       │                │
       ▼                ▼
   ATUALIZAR        CRIAR NOVA
   (#431)           (#432, etc)
```

---

## 📊 Comportamento no v2

### Cenário 1: Primeira Execução (Sem Issues Existentes)

```
Pipeline v2 → Criar AragonOSX PLAN-001
  ├─ issue_exists("Axodus/AragonOSX", "PLAN-001.*HarmonyVoting E2E")
  │  └─ Retorna: "" (não encontrado)
  │
  └─ CREATE → Issue #431 criada ✅
```

### Cenário 2: Execução Repetida (Issues Existem)

```
Pipeline v2 → Executar novamente
  ├─ issue_exists("Axodus/AragonOSX", "PLAN-001.*HarmonyVoting E2E")
  │  └─ Retorna: "431" (encontrado)
  │
  └─ UPDATE → Issue #431 atualizada ✅ (sem criar duplicata)
```

### Cenário 3: Mudança de Conteúdo

```
Pipeline v2 → Conteúdo da PLAN.md mudou
  ├─ issue_exists(...) → "431" (encontrado)
  │
  └─ UPDATE com novo body → Issue #431 sincronizada com PLAN.md ✅
```

---

## 🎯 Benefícios

| Aspecto | Antes | Depois |
|---------|-------|--------|
| **Duplicatas** | Criava 3x por execução | Zero duplicatas |
| **Idempotência** | ❌ Não | ✅ Sim |
| **Atualização** | Manual ou criar nova | Automática |
| **Rastreamento** | Problemático | Garantido |
| **Segurança** | Risco de perder dados | Preserva dados |

---

## 🚀 Uso

### Executar pipeline v2 com deduplicação:

```bash
cd GitIssue-Manager
bash scripts/execute-pipeline-v2.sh
```

### Output esperado:

```
✅ STAGE 1: SETUP
✅ STAGE 2: PREPARE
✅ STAGE 3: CREATE (com deduplicação)
   ⚠️  Issue #431 já existe em Axodus/AragonOSX
   ✅ Atualizada com novo conteúdo
✅ STAGE 4: FETCH
✅ STAGE 5: APPLY METADATA
✅ STAGE 6: REPORTS
```

---

## GitHub issue titles

GitHub issue titles are generated as breadcrumbs (no `-NNN` numbering in the GitHub title), e.g.:

- `[PLAN / EPIC / FEATURE] - Title`
- `[PLAN / EPIC / BUG] - Title`

---

## ⚙️ Configuração do Regex

Os padrões usam **regex** para flexibilidade:

```bash
# Exato (menos flexível)
"PLAN-001"

# Flexível (recomendado)
"PLAN-001.*HarmonyVoting E2E"

# Muito flexível
"PLAN-001"  # encontra qualquer issue que tenha PLAN-001 no título
```

---

## 🔄 Próximos Passos

1. ✅ **Script v2 criado** com deduplicação
2. ✅ **Testado** - comportamento correto
3. ✅ **Fechadas duplicatas** (#429, #430)
4. ⏳ **Promover v2 para produção**:
   ```bash
   # Backup do script antigo
   mv scripts/execute-pipeline.sh scripts/execute-pipeline.backup.sh
   
   # Usar novo script
   cp scripts/execute-pipeline-v2.sh scripts/execute-pipeline.sh
   ```

5. ⏳ **Documentar** no README.md:
   - Explicar deduplicação
   - Mostrar padrões de título
   - Dar exemplos de uso

---

## 📋 Checklist de Implementação

- [x] Identificar problema de duplicação
- [x] Fechar issues duplicadas (#429, #430)
- [x] Criar script v2 com deduplication logic
- [x] Testar deduplicação (passou ✅)
- [ ] Revisar e aprovar mudanças
- [ ] Promover v2 para produção
- [ ] Atualizar documentação
- [ ] Treinar equipe sobre novo fluxo

