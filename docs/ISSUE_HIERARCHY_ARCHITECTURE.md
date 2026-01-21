# GitHub Issue Hierarchy Architecture

## 🎯 Objetivo

Criar uma **hierarquia integrada de issues** onde:
1. **Uma única issue PAI** (por repositório) serve como ponto de entrada
2. **Progress tracking automático** sincronizado com sub-issues
3. **Bidirecional**: Fechar sub-issue atualiza checkbox da PAI
4. **Estrutura definida pelos .md files** (PLAN.md → SPRINT.md → FEATURE/TASK/BUG/HOTFIX)

---

## 📋 Hierarquia de Documentos → Issues

### Nível 1: PLAN (EPIC)
```
PLAN.md → Issue PAI (#431 no AragonOSX)
├─ Title: [AragonOSX | #PLAN-001]: HarmonyVoting E2E Production Rollout
├─ Body: PLAN.md completo + Progress Tracking section
└─ Status: Master issue para todo repositório
```

### Nível 2: SPRINT / FEATURE / TASK / BUG / HOTFIX
```
SPRINT.md, FEATURE-*.md, TASK-*.md, BUG-*.md, HOTFIX-*.md
    ↓
Sub-issues linkadas da issue PAI
├─ FEATURE-001: Indexing Resilience (#456)
├─ FEATURE-002: Plugin Uninstall (#457)
├─ FEATURE-003: Metadata Redundancy (#458)
├─ FEATURE-004: Native-Token Voting (#459)
└─ BUG-001, TASK-001, HOTFIX-001...
```

### Nível 3+: TASK / BUG / HOTFIX (sub-level)
```
Sub-tasks dentro de cada FEATURE/SPRINT
    ↓
Sub-issues linkadas às issues do nível 2
├─ TASK-A-001: Add reorg-safe handling (#452)
├─ TASK-A-002: Implement catch-up strategy (#453)
├─ TASK-A-003: Fresh sync validation (#454)
└─ ...
```

---

## 🔄 Fluxo de Sincronização

### Bidirecional: GitHub Native Linking

**Padrão de checkbox na Issue PAI (#431):**

```markdown
## Progress Tracking

### FEATURE-001: Indexing Resilience
- [ ] [#456 - Indexing Resilience](https://github.com/Axodus/AragonOSX/issues/456)
  - [ ] [#452 - Add reorg-safe handling](https://github.com/Axodus/AragonOSX/issues/452)
  - [ ] [#453 - Implement catch-up](https://github.com/Axodus/AragonOSX/issues/453)

### FEATURE-002: Plugin Uninstall
- [ ] [#457 - Plugin Uninstall](https://github.com/Axodus/AragonOSX/issues/457)
  - [ ] [#442 - Full state cleanup](https://github.com/Axodus/AragonOSX/issues/442)
  - [ ] [#443 - Ensure no orphaned state](https://github.com/Axodus/AragonOSX/issues/443)
```

**Sincronização:**
- ✅ Quando #452 é fechada → checkbox marca automaticamente
- ✅ Quando checkbox marca → GitHub não auto-fecha, mas serve como visual tracking
- ✅ Status reflete: OPEN = [ ] | CLOSED = [x]

---

## 📁 Estrutura de Arquivos & Mapping

### AragonOSX

```
AragonOSX/
├─ PLAN.md                      → Issue PAI (#431)
├─ SPRINT.md                    → Sub-issues Lv2 (FEATURE-001-004)
├─ COUNTRY_INTEGRATION.md       → (se existir) Sub-issues separadas
├─ DEPLOYMENT_CHECKLIST.md      → (se existir) Sub-issues separadas
├─ UPDATE_CHECKLIST.md          → (se existir) Sub-issues separadas
└─ packages/contracts/
   ├─ CHANGELOG.md              → Referência (não cria issues)
   └─ ...
```

**Mapping:**

| Arquivo | Tipo | Cria Issue Nível |
|---------|------|------------------|
| PLAN.md | EPIC | 1 (PAI) |
| SPRINT.md | SPRINT | 2 |
| FEATURE-*.md | FEATURE | 2 |
| TASK-*.md | TASK | 2-3 |
| BUG-*.md | BUG | 2-3 |
| HOTFIX-*.md | HOTFIX | 2-3 |

---

## 🎬 Algoritmo de Criação/Atualização

### 1. Detecção de Hierarquia (a partir dos .md files)

```bash
# Para cada repositório:
1. Ler PLAN.md
   ├─ Extrair checklist items (- [ ] ou - [x])
   ├─ Criar/atualizar Issue PAI
   └─ Gerar lista: level1_tasks = [...]

2. Ler SPRINT.md (ou outro FEATURE-*.md)
   ├─ Extrair checklist items
   ├─ Cada item = sub-issue Lv2
   └─ Gerar lista: level2_tasks = [...]

3. Para cada item em level2_tasks:
   ├─ Se tem sub-items (indentados)
   ├─ Cada sub-item = sub-issue Lv3
   └─ Linkar à issue Lv2
```

### 2. Criação/Atualização de Issues

```bash
# Padrão 1: Issue não existe
→ Criar nova com:
  - Title: [REPO | #TAG-nnn] Título
  - Body: Descrição do .md
  - Labels: (extrair de tags no .md)
  - Status/Priority/Estimate: (extrair de metadados)

# Padrão 2: Issue já existe
→ Atualizar:
  - Status do checkbox se foi completa
  - Sincronizar metadados
  - Não sobrescrever descrição (append)

# Padrão 3: Item foi deletado do .md
→ Deprecar/Arquivar issue (marcar como obsoleta)
```

### 3. Geração de Progress Tracking (Issue PAI)

```markdown
# PLAN: AragonOSX — HarmonyVoting E2E Production Rollout

[... PLAN.md completo ...]

---

## Progress Tracking (Auto-Generated)

**Completion:** 11/16 items (69%)

### FEATURE-001: Indexing Resilience
- [x] [#456 - Indexing Resilience](https://github.com/Axodus/AragonOSX/issues/456)
  - [x] [#452 - Add reorg-safe handling](https://github.com/Axodus/AragonOSX/issues/452) [CLOSED]
  - [x] [#453 - Implement catch-up](https://github.com/Axodus/AragonOSX/issues/453) [CLOSED]
  - [ ] [#454 - Mid-history backfill](https://github.com/Axodus/AragonOSX/issues/454) [OPEN]

### FEATURE-002: Plugin Uninstall
- [ ] [#457 - Plugin Uninstall](https://github.com/Axodus/AragonOSX/issues/457)
  - [x] [#442 - Full state cleanup](https://github.com/Axodus/AragonOSX/issues/442) [CLOSED]
  - [x] [#443 - Ensure no orphaned](https://github.com/Axodus/AragonOSX/issues/443) [CLOSED]
  - [ ] [#445 - Test with governance](https://github.com/Axodus/AragonOSX/issues/445) [OPEN]
```

---

## 🔗 Linking Strategy (Parent ↔ Child)

### GitHub Native Issue Links

**Option 1: Task Lists (GitHub 2024+)**
```markdown
- [ ] [#456 - Feature Name](link)
```
✅ Visual + Clickable  
❌ Não é oficial "parent/child"

**Option 2: Issue Relations (GitHub Discussions API)**
```bash
gh issue edit 431 --add-label "epic"
gh issue link 431 456  # Link 456 as related to 431
```
✅ Oficial  
✅ Bidirecional  
❌ Menos visual na descrição

**Option 3: Hybrid (Recomendado)**
- Usar Task Lists na descrição para visualização
- Usar issue linking via API para relação oficial
- Progress tracking automático baseia-se em estado das sub-issues

---

## 📊 Exemplo Completo: AragonOSX

### Issue PAI: #431

**Title:** `[AragonOSX | #PLAN-001]: HarmonyVoting E2E Production Rollout`

**Body:**
```markdown
# PLAN: AragonOSX — HarmonyVoting E2E Production Rollout

[... PLAN.md completo ...

---

## Progress Tracking

**Overall:** 11/16 items (69%)

### FEATURE-001: Indexing Resilience [75% | 10h remaining]
- [x] [#456 Indexing Resilience](https://github.com/Axodus/AragonOSX/issues/456)
  - [x] [#452 Add reorg-safe handling](https://github.com/Axodus/AragonOSX/issues/452) [6h | CLOSED]
  - [x] [#453 Implement catch-up](https://github.com/Axodus/AragonOSX/issues/453) [10h | CLOSED]
  - [ ] [#454 Mid-history backfill](https://github.com/Axodus/AragonOSX/issues/454) [10h | OPEN]

### FEATURE-002: Plugin Uninstall [83% | 12h remaining]
- [ ] [#457 Plugin Uninstall](https://github.com/Axodus/AragonOSX/issues/457)
  - [x] [#442 Full state cleanup](https://github.com/Axodus/AragonOSX/issues/442) [8h | CLOSED]
  - [ ] [#445 Test with governance](https://github.com/Axodus/AragonOSX/issues/445) [6h | OPEN]
```

### Sub-Issues: #452-#459

**#456 - Indexing Resilience**
```markdown
# FEATURE-001: Indexing Resilience & Catch-Up

Parent: #431 (HarmonyVoting E2E Production Rollout)

## Tasks
- [x] Add reorg-safe handling (#452) [6h] [CLOSED]
- [x] Implement catch-up (#453) [10h] [CLOSED]
- [ ] Mid-history backfill (#454) [10h]

## Progress: 2/3 tasks (67%)
```

---

## 🚀 Implementação no execute-pipeline.sh

### Novo Stage: STAGE 7 (OPTIONAL: Hierarchy & Linking)

```bash
stage_hierarchy() {
    info "Building issue hierarchy from .md files..."
    
    # 1. Parse .md structure
    parse_md_hierarchy "PLAN.md" "SPRINT.md" "FEATURE-*.md"
    
    # 2. Create/Update Issues
    create_hierarchy_issues
    
    # 3. Link parent ↔ child
    link_parent_child_issues
    
    # 4. Generate Progress Tracking
    generate_progress_tracking
    
    # 5. Update Issue PAI with tracking
    update_parent_issue_body
}
```

---

## ⚙️ Fluxo de Uso

### Para o usuário:

1. ✅ **Adiciona apenas Issue PAI (#431) ao ProjectV2**
2. ✅ **GitHub tracks sub-issues automaticamente**
3. ✅ **Progress %** reflete no dashboard
4. ✅ **Ao fechar sub-issue** → checkbox marca na PAI
5. ✅ **Report automático** mostra hierarquia completa

### Scripts pnpm:

```bash
# Criar/atualizar hierarquia
pnpm pipeline:hierarchy

# Só isso! Resto é automático.
```

---

## 📝 Status da Implementação

- [ ] Parse .md files e extrair checklist structure
- [ ] Detectar nível de indentação (Lv1, Lv2, Lv3...)
- [ ] Criar issues com Title: `[REPO | #TAG-nnn] Title`
- [ ] Linkar parent ↔ child via GitHub API
- [ ] Gerar Progress Tracking section
- [ ] Atualizar Issue PAI body
- [ ] Sincronização bidirecional (checkbox ↔ issue state)
- [ ] Teste completo em AragonOSX

---

**Próximo Passo:** Confirmar se essa arquitetura atende ao seu desejo!
