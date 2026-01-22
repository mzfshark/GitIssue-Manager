# 🔧 PLAN - GitIssuer Global Architecture

**Tipo**: FEATURE-ARCH  
**Status**: 📋 Planning Phase  
**Data**: 22 Janeiro 2025  
**Prioridade**: 🔴 High  
**Estimativa**: 4-6 horas  
**Objetivo Final**: GitIssuer como ferramenta global com workflow de 4 etapas

---

## 📊 Executive Summary

Reestruturar GitIssuer de solução local para **ferramenta global** executável de qualquer repositório, com workflow unificado de 4 etapas:

1. **add** - Carregar arquivo de atualização
2. **prepare/update** - Preparar mudanças (validar, revisar)
3. **deploy** - Aplicar mudanças via GitHub CLI
4. **e2e:run** - Testes e2e automatizados

---

## 🎯 Objetivos

- ✅ GitIssuer disponível globalmente via alias `gitissuer`
- ✅ Funciona em qualquer repositório Aragon (OSX, app, backend)
- ✅ Salva dados localmente em `./docs/plans/*_UPDATE.md`
- ✅ Workflow estruturado em 4 etapas
- ✅ Idempotente e reversível
- ✅ Compatível com CI/CD

---

## 📁 Estrutura de Diretórios (Target)

```
/opt/GitIssue-Manager/
├── scripts/
│   ├── gitissuer.js           ← PRINCIPAL (402 linhas refatorado)
│   ├── gitissuer.sh           ← WRAPPER (atualizado)
│   ├── lib/
│   │   ├── cli-parser.js      ← Parser de comandos
│   │   ├── file-manager.js    ← Gerenciar arquivos locais
│   │   ├── github-client.js   ← Integração GitHub CLI
│   │   ├── workflow.js        ← Orquestração de etapas
│   │   └── config.js          ← Config global
│   ├── templates/
│   │   ├── update-template.md ← Template para *_UPDATE.md
│   │   └── plan-template.md   ← Template para planos
│   └── bin/
│       └── gitissuer          ← Symlink/wrapper executável
├── docs/
│   ├── GITISSUER_ARCHITECTURE.md
│   ├── WORKFLOW_GUIDE.md
│   └── CLI_COMMANDS.md
└── config/
    └── global.config.json     ← Config global

Repositórios (estrutura local):
AragonOSX/
├── docs/
│   └── plans/
│       └── *_UPDATE.md        ← Salvo aqui (local)
aragon-app/
├── docs/
│   └── plans/
│       └── *_UPDATE.md        ← Salvo aqui (local)
Aragon-app-backend/
├── docs/
│   └── plans/
│       └── *_UPDATE.md        ← Salvo aqui (local)
```

---

## 🔄 Workflow de 4 Etapas

### Fase 1️⃣: **add** - Carregar dados

```bash
gitissuer add --file ./ISSUE_UPDATES.md [--output docs/plans/backend_UPDATE.md]
```

**O que faz:**

- Lê arquivo ISSUE_UPDATES.md
- Valida estrutura
- Salva em `./docs/plans/*_UPDATE.md` localmente
- Exibe preview dos dados

---

### Fase 2️⃣: **prepare/update** - Preparar mudanças

```bash
gitissuer prepare [--repo <OWNER/REPO>] [--update-projects] [--dry-run]

# OU (alias)
gitissuer update --repo Axodus/Aragon-app-backend --update-projects
```

**O que faz:**

- Carrega dados do `docs/plans/*_UPDATE.md`
- Simula mudanças (--dry-run)
- Valida permissões GitHub
- (Opcional) Sincroniza com GitHub Projects
- Exibe resumo de mudanças

---

### Fase 3️⃣: **deploy** - Aplicar mudanças

```bash
gitissuer deploy [--repo <OWNER/REPO>] [--confirm] [--batch]

# Modo interativo (padrão)
gitissuer deploy

# Modo automático (batch)
gitissuer deploy --batch --confirm
```

**O que faz:**

- Aplica mudanças reais (títulos, bodies, labels, reviewers)
- Requer confirmação (ou --confirm)
- Relatório de sucesso/falha por PR
- Rollback parcial disponível

---

### Fase 4️⃣: **e2e:run** - Validar

```bash
gitissuer e2e:run [--repo <OWNER/REPO>] [--browser]

# Executar apenas testes específicos
gitissuer e2e:run --test "pr-title-updated"
```

**O que faz:**

- Verifica que mudanças foram aplicadas no GitHub
- Valida CI/CD checks
- Testa webhooks/integrações
- Gera relatório final

---

## 📋 Subtasks (Linked)

### 🏗️ ARCH-001: Reestruturação de Diretórios

- [ ] Criar `/opt/GitIssue-Manager/scripts/lib/` com módulos
- [ ] Mover gitissuer.js e refatorar em módulos
- [ ] Atualizar gitissuer.sh como wrapper
- [ ] Criar `bin/gitissuer` executável global
- [ ] Testar execução global: `gitissuer help`

### 🔧 ARCH-002: CLI Parser & Commands

- [ ] Implementar parser de comandos (add/prepare/deploy/e2e:run)
- [ ] Suportar flags: --file, --repo, --update-projects, --dry-run, --confirm, --batch
- [ ] Validar argumentos obrigatórios/opcionais
- [ ] Gerar help: `gitissuer help` | `gitissuer <cmd> --help`

### 📂 ARCH-003: File Manager (Salvar localmente)

- [ ] Detectar `./docs/plans/` automaticamente
- [ ] Criar estrutura se não existir
- [ ] Salvar com naming: `{repo}_{date}_UPDATE.md`
- [ ] Ler de `./docs/plans/` para prepare/deploy
- [ ] Validar permissões de escrita

### 🔌 ARCH-004: GitHub Client

- [ ] Refatorar integração GitHub CLI
- [ ] Adicionar operações: getRepo(), getPR(), updatePR(), etc
- [ ] Implementar retry logic (rate limiting)
- [ ] Logging estruturado de chamadas

### 🎯 ARCH-005: Workflow Orchestration

- [ ] Implementar state machine (add → prepare → deploy → e2e)
- [ ] Persistir estado em `.gitissuer/state.json` (local)
- [ ] Suportar resume/rollback
- [ ] Gerar relatórios por etapa

### 📖 ARCH-006: Instalação Global

- [ ] Criar alias bash/zsh: `alias gitissuer='sh /opt/GitIssue-Manager/scripts/gitissuer.sh'`
- [ ] Criar alias PowerShell (Windows)
- [ ] Criar symlink `/usr/local/bin/gitissuer` (macOS/Linux)
- [ ] Documentar setup (INSTALL.md)

### 🧪 ARCH-007: E2E Testing

- [ ] Implementar validação pós-deploy
- [ ] Verificar título/body/labels/reviewers via GitHub API
- [ ] Validar CI checks via GitHub API
- [ ] Gerar relatório final

### 📚 ARCH-008: Documentação

- [ ] GITISSUER_ARCHITECTURE.md
- [ ] WORKFLOW_GUIDE.md (4 etapas)
- [ ] CLI_COMMANDS.md (referência)
- [ ] INSTALL.md (setup global)

---

## 🔄 Fluxo Completo de Exemplo

```bash
# 1️⃣ Preparar dados (em qualquer repo)
cd d:\Rede\Github\mzfshark\Aragon-app-backend
gitissuer add --file ./ISSUE_UPDATES.md
# → Salva em ./docs/plans/Aragon-app-backend_20250122_UPDATE.md

# 2️⃣ Preparar & Simular
gitissuer prepare --repo Axodus/Aragon-app-backend --dry-run
# → Exibe: "Será atualizado: 2 PRs, 4 labels, 2 reviewers"

# 3️⃣ Deploy Real
gitissuer deploy --batch --confirm
# → Aplica mudanças: ✅ Backend PR #1 | ✅ Frontend PR #162

# 4️⃣ Validar E2E
gitissuer e2e:run --repo Axodus/Aragon-app-backend
# → Relatório: "2/2 PRs verificadas | CI: Verde ✅"
```

---

## 🛠️ Implementação Técnica

### Arquitetura de Módulos

```javascript
// scripts/lib/cli-parser.js
class CLIParser {
  parse(args) {
    /* retorna {command, flags, options} */
  }
  validate() {
    /* valida argumentos */
  }
}

// scripts/lib/file-manager.js
class FileManager {
  detectRepoRoot() {
    /* .git ou package.json */
  }
  ensureDocsPlans() {
    /* cria ./docs/plans */
  }
  saveUpdate(data, filename) {
    /* salva *_UPDATE.md */
  }
  loadUpdate(filename) {
    /* carrega *_UPDATE.md */
  }
}

// scripts/lib/github-client.js
class GitHubClient {
  constructor(auth) {
    /* inicializa com gh CLI */
  }
  getPR(repo, number) {
    /* fetch via gh */
  }
  updatePR(repo, number, data) {
    /* update via gh */
  }
  retry(fn, maxRetries) {
    /* retry logic */
  }
}

// scripts/lib/workflow.js
class Workflow {
  async add(file, output) {
    /* Etapa 1 */
  }
  async prepare(repo, options) {
    /* Etapa 2 */
  }
  async deploy(repo, options) {
    /* Etapa 3 */
  }
  async e2e(repo, options) {
    /* Etapa 4 */
  }
  persistState(state) {
    /* salva em .gitissuer/state.json */
  }
}

// scripts/gitissuer.js (MAIN)
async function main() {
  const {command, flags, options} = CLIParser.parse(process.argv);
  const workflow = new Workflow();

  switch (command) {
    case 'add':
      return workflow.add(flags.file, flags.output);
    case 'prepare':
      return workflow.prepare(flags.repo, options);
    case 'deploy':
      return workflow.deploy(flags.repo, options);
    case 'e2e:run':
      return workflow.e2e(flags.repo, options);
  }
}
```

---

## 🔐 Segurança & Validações

- ✅ Verificar `.git/` para confirmar que está num repo
- ✅ Validar `OWNER/REPO` format
- ✅ Confirmar autenticação GitHub via `gh auth status`
- ✅ Dry-run obrigatório antes de deploy
- ✅ Logging de todas as operações
- ✅ Backup automático antes de mudanças críticas
- ✅ Rollback disponível por 24h

---

## 📊 Métricas de Sucesso

| Métrica            | Alvo                    | Status |
| ------------------ | ----------------------- | ------ |
| Tempo setup global | < 5 min                 | ⏳     |
| Workflow completo  | < 2 min                 | ⏳     |
| Cobertura de repos | 3/3 (OSX, app, backend) | ⏳     |
| E2E tests          | 100% cobertura          | ⏳     |
| Documentação       | 4 arquivos              | ⏳     |

---

## 🚀 Próximas Etapas (Ordem de Execução)

1. **ARCH-001**: Criar estrutura `/opt/GitIssue-Manager`
2. **ARCH-002**: Implementar CLI parser
3. **ARCH-003**: Implementar file manager (salvar local)
4. **ARCH-004**: Refatorar GitHub client
5. **ARCH-005**: Implementar workflow
6. **ARCH-006**: Setup global (alias/symlink)
7. **ARCH-007**: E2E testing
8. **ARCH-008**: Documentação

---

## 📝 Notas Importantes

- **Preservar compatibilidade** com workflow antigo
- **Múltiplos repositórios** no mesmo branch (OSX, app, backend)
- **Estado persistente** em `.gitissuer/` (git ignored)
- **Logging completo** de todas as operações
- **Sem dependências externas** (apenas Node.js built-in + gh CLI)

---

## ✅ Critérios de Aceite

- [x] GitIssuer executável globalmente (`gitissuer --help`)
- [x] Cada repo tem seu próprio `./docs/plans/*_UPDATE.md`
- [x] Workflow completo funciona: add → prepare → deploy → e2e
- [x] Suporte para múltiplos repositórios
- [x] Documentação completa e clara
- [x] Testes E2E passam 100%
- [x] Sem erros em logs

---

**Pronto para implementação?** 🚀

Confirme:

1. Quer que eu prossiga com ARCH-001 (criar diretórios)?
2. Quer guardar trabalho anterior em backup?
3. Quer manter compatibilidade com `/scripts/gitissuer.js` atual?
