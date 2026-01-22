# E2E Issue Hierarchy Pipeline — Plano Arquitetural Completo

**Data:** 2026-01-21  
**Status:** 🟡 PLANEJAMENTO  
**Owner:** mzfshark  
**Target Completion:** 2026-02-04

---

## Visão Geral

O E2E Flow é um **pipeline interativo completo** que:

1. ✅ **Valida setup** (auth, repositórios, configuração)
2. ✅ **Oferece seleção** (qual repo, qual PLAN.md, metadatas)
3. ✅ **Cria Issue PAI** com metadados completos
4. ✅ **Cria todas as sub-issues** em batch
5. ✅ **Linka hierarquia** (parent → child → sub-child)
6. ✅ **Sincroniza ProjectV2** (status, priority, estimate, dates)

**Resultado:** Uma única Issue PAI com estrutura hierárquica completa, sem "front running" de etapas.

---

## 1. FLUXO COMPLETO (Ordem Correta)

### Fase 1: SETUP & CONFIGURATION
```
┌─ Verificar autenticação GitHub (gh auth status)
├─ Carregar config base (.env / config.json)
├─ Validar repositórios acessíveis (gh repo list)
└─ Apresentar menu interativo principal
```

**Responsabilidades:**
- Validar `gh` CLI disponível
- Verificar auth token válido
- Carregar/criar `config/e2e-config.json`
- Confirmar acesso aos 3 repositórios

**Output:**
- `tmp/e2e-runs/run-{TIMESTAMP}/config.json` (config de execução)

---

### Fase 2: SELEÇÃO DE CONTEXTO
```
┌─ Menu: Escolher repositório
│  └─ [1] Axodus/AragonOSX
│  └─ [2] Axodus/aragon-app
│  └─ [3] Axodus/Aragon-app-backend
│  └─ [4] TODOS
│
├─ Menu: Escolher PLAN.md
│  └─ [1] PLAN.md
│  └─ [2] SPRINT.md
│  └─ [3] FEATURE.md
│  └─ [4] TODOS
│
├─ Menu: Issue Type (para PAI)
│  └─ [1] feature
│  └─ [2] task
│  └─ [3] epic
│
└─ Input: Assignee (padrão: mzfshark)
└─ Input: Labels (padrão: ["plan", "harmony"])
```

**Responsabilidades:**
- Apresentar menus interativos
- Validar seleções
- Gerar permutações (repo × planFile)
- Salvar config de execução

**Output:**
- Config JSON com todas as seleções

---

### Fase 3: CRIAR ISSUE PAI

**Por cada repo × planFile selecionado:**

```
┌─ Ler arquivo: {repo}/docs/plans/{planFile}.md
├─ Extrair metadados:
│  ├─ Título: do header `# PLAN: ...`
│  ├─ Descrição: primeiros 200-500 chars
│  ├─ Assignee: do prompt ou config
│  ├─ Type: do menu (feature/task/epic)
│  ├─ Labels: ["plan", "harmony", ...] 
│  ├─ ProjectId: do config
│  └─ Metadata básico (status, priority, etc)
│
├─ Criar issue via: gh issue create --repo {REPO} \
│                     --title "..." \
│                     --body "..." \
│                     --assignee "..." \
│                     --label "plan,harmony"
│
├─ Gravar resultado:
│  ├─ PAI_NUMBER (ex: 373)
│  ├─ PAI_NODE_ID (GraphQL ID)
│  ├─ PAI_URL
│  └─ Created timestamp
│
├─ ✨ ADICIONAR AO PROJECT NESTE PONTO ✨
│  └─ gh project item-add {PROJECT_ID} --issue {PAI_NUMBER}
│
└─ Gravar tudo em: hierarchy-map.json
```

**Responsabilidades:**
- Parse de PLAN.md para extrair título/descrição
- Validação de metadados
- Criar issue
- Adicionar ao project
- Gravação de metadata

**Output:**
```json
{
  "pai": {
    "number": 373,
    "nodeId": "I_kwDO...",
    "title": "PLAN: AragonOSX — HarmonyVoting E2E Production Rollout",
    "repo": "Axodus/AragonOSX",
    "planFile": "PLAN.md",
    "type": "feature",
    "assignee": "mzfshark",
    "labels": ["plan", "harmony"],
    "projectId": 23,
    "createdAt": "2026-01-21T18:00:00Z"
  }
}
```

---

### Fase 4: CRIAR SUB-ISSUES

**Por cada PAI criado:**

```
┌─ Parsear PLAN.md + SPRINT.md
├─ Extrair todos os items do checklist:
│  ├─ Regex: /^(\s*)-\s*\[([x ])\]\s+(.+)$/
│  ├─ Determinar nível: nivel = (indent / 2)
│  ├─ Extrair título: do match group 3
│  └─ Status: [x] = DONE, [ ] = TODO
│
├─ Para cada item:
│  ├─ Título: "- [ ] {text}"
│  ├─ Descrição: contexto local (5 linhas antes/depois)
│  ├─ Type: "task" (padrão)
│  ├─ Labels: derivadas de indentação + keywords
│  ├─ Assignee: padrão (mesmo da PAI)
│  └─ Criar via: gh issue create \
│                  --title "..." \
│                  --body "..." \
│                  --label "..." \
│                  --assignee "..."
│
├─ Gravar em JSON:
│  └─ { parent: 373, child: 374, level: "Lv1", title: "...", status: "TODO" }
│
└─ Gerar: HIERARCHY_MAP.json (estrutura completa)
```

**Responsabilidades:**
- Parse hierárquico de .md
- Detecção de níveis
- Batch creation de issues
- Gravação de metadata

**Output:**
```json
{
  "pai": 373,
  "children": [
    {
      "number": 374,
      "level": "Lv1",
      "title": "Indexing: All lifecycle states appear in UI/API within SLA",
      "status": "DONE",
      "nodeId": "I_kwDO..."
    },
    {
      "number": 375,
      "level": "Lv1",
      "title": "Indexing: Reindex/backfill produces identical final state",
      "status": "DONE",
      "nodeId": "I_kwDO..."
    },
    ...
  ],
  "totalCreated": 140
}
```

---

### Fase 5: APLICAR HIERARQUIA

**Por cada PAI + seus filhos:**

```
┌─ Ler HIERARCHY_MAP.json
├─ Para cada filho:
│  ├─ Determinar parent (baseado em level)
│  ├─ Executar: gh issue link {CHILD} {PARENT}
│  ├─ Validar sucesso (HTTP 200)
│  └─ Gravar em log
│
└─ Gerar relatório:
   ├─ Links criados: 140/140
   ├─ Links falhados: 0
   └─ Tempo total: 12.5s
```

**Responsabilidades:**
- Parse de HIERARCHY_MAP
- Linking via gh CLI
- Validação de links
- Logging detalhado

**Output:**
```json
{
  "linksCreated": 140,
  "linksFailed": 0,
  "duration": "12.5s",
  "details": [
    { "child": 374, "parent": 373, "status": "success" },
    { "child": 375, "parent": 373, "status": "success" },
    ...
  ]
}
```

---

### Fase 6: APLICAR METADATAS NO PROJECT

**Por cada issue (PAI + filhos):**

```
┌─ Query ProjectV2 para obter fieldIds:
│  ├─ statusFieldId
│  ├─ priorityFieldId
│  ├─ estimateHoursFieldId
│  ├─ startDateFieldId
│  └─ dueDateFieldId
│
├─ Para PAI:
│  ├─ Buscar item no project via nodeId
│  ├─ Atualizar fields:
│  │  ├─ Status: "TODO" (do config)
│  │  ├─ Priority: "HIGH" (do config)
│  │  ├─ Estimate: 160 hours (do PLAN.md)
│  │  ├─ Start Date: "2026-01-21" (do PLAN.md)
│  │  └─ Due Date: "2026-02-28" (do PLAN.md)
│  └─ GraphQL mutation: updateProjectV2ItemFieldValue
│
└─ Para cada filho:
   ├─ Atualizar fields básicos (status, priority)
   ├─ Inheritados do PAI quando necessário
   └─ GraphQL mutation
```

**Responsabilidades:**
- Query ProjectV2 schema
- Mapping de values (strings → enum IDs)
- Batch mutations GraphQL
- Error handling e retry

**Output:**
```json
{
  "metadata": {
    "pai": {
      "number": 373,
      "fields": {
        "status": "TODO",
        "priority": "HIGH",
        "estimateHours": 160,
        "startDate": "2026-01-21",
        "dueDate": "2026-02-28"
      },
      "status": "success"
    },
    "children": [
      {
        "number": 374,
        "fields": { "status": "DONE", "priority": "HIGH" },
        "status": "success"
      },
      ...
    ],
    "totalUpdated": 141
  }
}
```

---

## 2. ESTRUTURA DE ARQUIVOS

```
GitIssue-Manager/
├─ scripts/
│  ├─ e2e-flow.sh              [NOVO] Menu + orquestrador principal
│  ├─ e2e-phase-1.sh           [NOVO] Setup & validation
│  ├─ e2e-phase-2.sh           [NOVO] Selection & config
│  ├─ e2e-phase-3.sh           [NOVO] Create PAI + add to project
│  ├─ e2e-phase-4.sh           [NOVO] Create sub-issues batch
│  ├─ e2e-phase-5.sh           [NOVO] Link hierarchy (gh issue link)
│  ├─ e2e-phase-6.sh           [NOVO] Apply ProjectV2 metadata (GraphQL)
│  └─ e2e-utils.sh             [NOVO] Funções compartilhadas
│
├─ src/
│  ├─ e2e-flow.js              [NOVO] Orquestrador Node.js (opcional)
│  ├─ e2e-parser.js            [NOVO] Parser de PLAN.md (reúsa process-hierarchy.js)
│  ├─ e2e-github.js            [NOVO] Wrapper de gh CLI + GraphQL
│  └─ e2e-project.js           [NOVO] ProjectV2 field management
│
├─ config/
│  ├─ e2e-config.json          [NOVO] Config padrão
│  └─ e2e-config.sample.json   [NOVO] Exemplo
│
├─ E2E_FLOW_ARCHITECTURE.md    [NOVO] Este arquivo
│
└─ tmp/
   └─ e2e-runs/
      └─ run-2026-01-21-180000/
         ├─ config.json
         ├─ pai-map.json
         ├─ hierarchy-map.json
         ├─ metadata-map.json
         ├─ phase-results.json
         ├─ execution-log.txt
         └─ FINAL_REPORT.md
```

---

## 3. CONFIGURAÇÃO E2E

**Arquivo: `config/e2e-config.sample.json`**

```json
{
  "version": "1.0",
  "executionMode": "interactive",
  "repositories": [
    {
      "id": "aragon-osx",
      "name": "Axodus/AragonOSX",
      "defaultBranch": "develop",
      "docsPlansPath": "docs/plans"
    },
    {
      "id": "aragon-app",
      "name": "Axodus/aragon-app",
      "defaultBranch": "main",
      "docsPlansPath": "docs/plans"
    },
    {
      "id": "aragon-backend",
      "name": "Axodus/Aragon-app-backend",
      "defaultBranch": "development",
      "docsPlansPath": "docs/plans"
    }
  ],
  "projectDefaults": {
    "projectId": 23,
    "projectName": "Aragon Sprint 1",
    "organizationName": "Axodus"
  },
  "issueDefaults": {
    "assignee": "mzfshark",
    "type": "feature",
    "labels": ["plan", "harmony"],
    "metadata": {
      "status": "TODO",
      "priority": "HIGH",
      "estimateHours": 160,
      "startDate": "2026-01-21",
      "dueDate": "2026-02-28"
    }
  },
  "github": {
    "organization": "Axodus",
    "graphqlEndpoint": "https://api.github.com/graphql"
  }
}
```

---

## 4. CHECKLIST DE IMPLEMENTAÇÃO

### Fase 1: Setup & Validation
- [ ] `e2e-phase-1.sh` - Validar auth + repos
- [ ] `e2e-utils.sh` - Funções compartilhadas
- [ ] Testes unitários (auth, repo access)

### Fase 2: Selection & Config
- [ ] `e2e-phase-2.sh` - Menu interativo
- [ ] Geração de config.json
- [ ] Validação de seleções

### Fase 3: Create PAI
- [ ] `e2e-phase-3.sh` - Create issue + add project
- [ ] `src/e2e-parser.js` - Extract metadata from PLAN.md
- [ ] Validação de issue criada
- [ ] Test com AragonOSX

### Fase 4: Create Sub-Issues
- [ ] `e2e-phase-4.sh` - Batch creation
- [ ] Reúso de `process-hierarchy.js`
- [ ] Progress bar CLI
- [ ] Test com 140 items

### Fase 5: Link Hierarchy
- [ ] `e2e-phase-5.sh` - gh issue link
- [ ] Validação de links
- [ ] Error handling + retry
- [ ] Test linking

### Fase 6: Apply ProjectV2 Metadata
- [ ] `e2e-phase-6.sh` - GraphQL mutations
- [ ] `src/e2e-project.js` - Field management
- [ ] Schema query + caching
- [ ] Batch updates
- [ ] Test com ProjectV2

### Integration & Testing
- [ ] `e2e-flow.sh` - Orquestrador principal
- [ ] E2E test completo com AragonOSX
- [ ] Documentation (README)
- [ ] pnpm scripts (pnpm e2e-flow)

---

## 5. FLUXO INTERATIVO ESPERADO

```
╔══════════════════════════════════════════════════════════════╗
║  E2E Issue Hierarchy Pipeline v1.0                           ║
║  © 2026 mzfshark                                             ║
╚══════════════════════════════════════════════════════════════╝

[PHASE 1] Setup & Validation
  ✓ GitHub auth verified (user: mzfshark)
  ✓ Repositories accessible (3/3)
  ✓ Config loaded: config/e2e-config.json

[PHASE 2] Repository & Plan Selection
  ? Select repository:
    1) Axodus/AragonOSX
    2) Axodus/aragon-app
    3) Axodus/Aragon-app-backend
    4) ALL
  > 1

  ? Select plan file(s):
    1) PLAN.md (56 items)
    2) SPRINT.md (84 items)
    3) FEATURE.md (12 items)
    4) ALL
  > 1

  ? Issue PAI Type:
    1) feature
    2) task
    3) epic
  > 1

  ? Assignee (default: mzfshark): 
  > mzfshark

  ? Labels (comma-separated, default: plan,harmony):
  > plan,harmony

  Configuration saved to: tmp/e2e-runs/run-2026-01-21-180345/config.json

[PHASE 3] Creating Parent Issue (PAI)
  📝 Title: PLAN: AragonOSX — HarmonyVoting E2E Production Rollout
  📄 Description: Complete HarmonyVoting E2E flow across contracts, indexing...
  🏷️  Labels: plan, harmony
  👤 Assignee: mzfshark
  🎯 Type: feature
  📊 Estimate: 160h | Start: 2026-01-21 | Due: 2026-02-28

  Creating issue...
  ✓ Issue created: #373
  ✓ Added to project: Aragon Sprint 1 (status: TODO, priority: HIGH)
  ✓ Metadata saved

[PHASE 4] Creating Sub-Issues (56 items)
  Parsing PLAN.md...
  ✓ Extracted 56 items
  
  Creating issues: [████████████████████] 100% (56/56)
  ✓ All sub-issues created
  ✓ Hierarchy map saved: hierarchy-map.json

[PHASE 5] Applying Hierarchy Links
  Linking issues... [████████████████████] 100% (56/56)
  ✓ All links created successfully
  ✓ Validating relationships...
  ✓ All relationships verified

[PHASE 6] Applying ProjectV2 Metadata
  Querying ProjectV2 schema...
  ✓ Found 8 fields
  
  Updating metadata... [████████████████████] 100% (57/57)
  ✓ PAI #373 metadata:
    - Status: TODO
    - Priority: HIGH
    - Estimate: 160h
    - Start: 2026-01-21
    - Due: 2026-02-28
  
  ✓ All metadata applied successfully

╔══════════════════════════════════════════════════════════════╗
║ ✅ PIPELINE COMPLETE                                         ║
║                                                              ║
║ Results:                                                     ║
║  • PAI Issue: #373                                           ║
║  • Sub-issues created: 56                                    ║
║  • Links created: 56                                         ║
║  • Metadata fields updated: 57                               ║
║  • Total time: 4m 23s                                        ║
║                                                              ║
║ 📊 View at: https://github.com/Axodus/AragonOSX/issues/373  ║
║ 📁 Logs: tmp/e2e-runs/run-2026-01-21-180345/                 ║
╚══════════════════════════════════════════════════════════════╝
```

---

## 6. TECNOLOGIAS & FERRAMENTAS

| Componente | Tecnologia | Propósito |
|-----------|-----------|----------|
| **Orquestração** | Bash (`e2e-flow.sh`) | Menu interativo + fase coordination |
| **Menu CLI** | `bash` + `read` | Seleção interativa de opções |
| **Parsing .md** | Node.js (`e2e-parser.js`) | Extração de metadados e hierarquia |
| **GitHub API** | `gh` CLI | Issue CRUD, linking |
| **ProjectV2 API** | GraphQL | Field queries + mutations |
| **Logging** | Bash + JSON | Estruturado para auditoria |

---

## 7. DEPENDÊNCIAS

```bash
# Verificar disponibilidade
which gh                    # GitHub CLI
which node                  # Node.js
which jq                    # JSON processor
gh auth status             # GitHub authentication
```

---

## 8. PRÓXIMOS PASSOS

### Imediatos
1. ✅ Criar plano arquitetural (este documento)
2. ⏳ Criar `e2e-flow.sh` (menu principal)
3. ⏳ Criar `e2e-utils.sh` (funções compartilhadas)
4. ⏳ Implementar Fase 1 (setup validation)

### Curto Prazo
5. ⏳ Implementar Fases 2-6
6. ⏳ Criar testes unitários
7. ⏳ E2E test com AragonOSX
8. ⏳ Documentação (README)

### Futuro
9. ⏳ Suporte a múltiplos repositórios simultâneos
10. ⏳ Webhook para sync bidirecional
11. ⏳ Dashboard de progresso em tempo real
12. ⏳ Export para Jira/Linear

---

## 9. REFERÊNCIAS

- Exemplo de Issue Completa: https://github.com/Axodus/AragonOSX/issues/431
- GitHub Issue API: https://docs.github.com/en/rest/issues
- ProjectV2 API: https://docs.github.com/en/graphql/reference/mutations#updateprojectv2itemfieldvalue
- gh CLI Docs: https://cli.github.com/manual/

---

**Próximo:** Iniciar implementação de `e2e-flow.sh` e `e2e-utils.sh`
