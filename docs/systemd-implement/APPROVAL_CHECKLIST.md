# 🎯 GITISSUER GLOBAL - APPROVAL CHECKLIST

## 📋 O Que Será Implementado

```
┌──────────────────────────────────────────────────────────┐
│         GITISSUER - ARQUITETURA GLOBAL                   │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  Local: /opt/GitIssue-Manager/                          │
│  ├── scripts/gitissuer.js (refatorado)                  │
│  ├── scripts/gitissuer.sh (wrapper)                     │
│  ├── scripts/lib/ (módulos Node.js)                     │
│  │   ├── cli-parser.js (parse de comandos)             │
│  │   ├── file-manager.js (salvar local)                │
│  │   ├── github-client.js (integração gh)              │
│  │   └── workflow.js (orquestração)                    │
│  └── bin/gitissuer (executável global)                 │
│                                                          │
│  Alias Global: gitissuer (executável em qualquer lugar)│
│                                                          │
│  Dados Locais (em cada repo):                           │
│  ├── AragonOSX/docs/plans/*_UPDATE.md                  │
│  ├── aragon-app/docs/plans/*_UPDATE.md                 │
│  └── Aragon-app-backend/docs/plans/*_UPDATE.md         │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

---

## 🔄 Workflow de 4 Etapas

### 1️⃣ **ADD** - Carregar dados

```bash
gitissuer add --file ./ISSUE_UPDATES.md
```

✅ Salva em `./docs/plans/*_UPDATE.md` (local)

### 2️⃣ **PREPARE** - Preparar & Simular

```bash
gitissuer prepare --repo Axodus/Aragon-app-backend --dry-run
```

✅ Valida mudanças sem aplicar

### 3️⃣ **DEPLOY** - Aplicar mudanças

```bash
gitissuer deploy --batch --confirm
```

✅ Aplica títulos, bodies, labels, reviewers

### 4️⃣ **E2E:RUN** - Validar

```bash
gitissuer e2e:run --repo Axodus/Aragon-app-backend
```

✅ Verifica que tudo funcionou

---

## 📁 Estrutura de Arquivos a Criar

### /opt/GitIssue-Manager/

```
scripts/
  ├── gitissuer.js (402 linhas, refatorado)
  ├── gitissuer.sh (wrapper)
  └── lib/
      ├── cli-parser.js (~150 linhas)
      ├── file-manager.js (~180 linhas)
      ├── github-client.js (~200 linhas)
      └── workflow.js (~250 linhas)

docs/
  ├── GITISSUER_ARCHITECTURE.md
  ├── WORKFLOW_GUIDE.md
  └── CLI_COMMANDS.md

config/
  └── global.config.json
```

**Total novo código**: ~1000 linhas de JavaScript

---

## 🎯 Comportamento Esperado

### ✅ Funciona em Qualquer Diretório

```bash
cd /home/user/project
gitissuer add --file ISSUE_UPDATES.md
# ✅ Salva em ./docs/plans/ (projeto atual)

cd /another/project
gitissuer add --file UPDATES.md
# ✅ Salva em ./docs/plans/ (projeto atual)
```

### ✅ Salva Dados Localmente

```
AragonOSX/
  └── docs/plans/
      └── AragonOSX_20250122_UPDATE.md ← LOCAL

aragon-app/
  └── docs/plans/
      └── aragon-app_20250122_UPDATE.md ← LOCAL

Aragon-app-backend/
  └── docs/plans/
      └── backend_20250122_UPDATE.md ← LOCAL
```

### ✅ Executa Globalmente

```bash
# De qualquer lugar:
gitissuer help          # OK ✅
gitissuer add --file XX # OK ✅
gitissuer deploy        # OK ✅
gitissuer e2e:run       # OK ✅
```

---

## 🔧 Instalação Necessária

```bash
# 1. Criar estrutura /opt/GitIssue-Manager (se não existir)
sudo mkdir -p /opt/GitIssue-Manager/scripts/lib
sudo mkdir -p /opt/GitIssue-Manager/docs
sudo mkdir -p /opt/GitIssue-Manager/config

# 2. Copiar scripts
sudo cp gitissuer.js /opt/GitIssue-Manager/scripts/
sudo cp gitissuer.sh /opt/GitIssue-Manager/scripts/

# 3. Criar alias (adicionar ao ~/.bashrc, ~/.zshrc, $PROFILE)
alias gitissuer='sh /opt/GitIssue-Manager/scripts/gitissuer.sh'

# OU criar symlink (macOS/Linux)
sudo ln -s /opt/GitIssue-Manager/scripts/gitissuer.sh /usr/local/bin/gitissuer
```

---

## 📊 Arquivos a Modificar vs Criar

| Tipo      | Ação      | Arquivo                   | Status                      |
| --------- | --------- | ------------------------- | --------------------------- |
| Modificar | Refatorar | gitissuer.js              | 🔄 Será separado em módulos |
| Modificar | Atualizar | gitissuer.sh              | 🔄 Novo wrapper             |
| Criar     | Novo      | cli-parser.js             | ✨ ~150 linhas              |
| Criar     | Novo      | file-manager.js           | ✨ ~180 linhas              |
| Criar     | Novo      | github-client.js          | ✨ ~200 linhas              |
| Criar     | Novo      | workflow.js               | ✨ ~250 linhas              |
| Criar     | Novo      | GITISSUER_ARCHITECTURE.md | 📖 Documentação             |
| Criar     | Novo      | WORKFLOW_GUIDE.md         | 📖 Documentação             |
| Criar     | Novo      | CLI_COMMANDS.md           | 📖 Documentação             |

---

## ⚠️ Impacto & Riscos

### ✅ Positivo

- Ferramenta global reutilizável
- Múltiplos repositórios
- Workflow estruturado
- Idempotente e reversível

### ⚠️ Possíveis Riscos

- Requer `/opt/` acesso (sudo)
- Depende de GitHub CLI (deve estar instalado)
- Estado persistente em `.gitissuer/`

### 🛡️ Mitigações

- Documentação clara de setup
- Fallback para local se não houver `/opt/`
- Backup automático antes de mudanças
- Teste E2E completo

---

## ✅ Checklist de Aprovação

Antes de implementar, confirme:

- [ ] **Quer criar `/opt/GitIssue-Manager`?**  
      `Sim` / `Não` / `Usar outro caminho`

- [ ] **Quer refatorar gitissuer.js em módulos?**  
      `Sim` / `Não` / `Manter monolítico`

- [ ] **Quer implementar todas 4 etapas (add/prepare/deploy/e2e)?**  
      `Sim` / `Apenas add + deploy` / `Customizado`

- [ ] **Quer alias global ou symlink?**  
      `Alias bash/zsh` / `Symlink /usr/local/bin` / `Ambos`

- [ ] **Quer manter compatibilidade com versão anterior?**  
      `Sim` / `Não` / `Deprecate after 1 month`

- [ ] **Quer preservar `./docs/plans/` como padrão?**  
      `Sim` / `Outro caminho`

---

## 📅 Timeline Estimado

| Fase             | Horas    | Tarefas                           |
| ---------------- | -------- | --------------------------------- |
| **ARCH-001-003** | 1.5h     | Setup + CLI Parser + File Manager |
| **ARCH-004-005** | 1.5h     | GitHub Client + Workflow          |
| **ARCH-006**     | 0.5h     | Setup global                      |
| **ARCH-007**     | 1h       | E2E Testing                       |
| **ARCH-008**     | 1h       | Documentação                      |
| **Total**        | **5.5h** | Completo & Testado                |

---

## 🎯 Resultado Final Esperado

Depois de implementado, você poderá:

```bash
# De QUALQUER repositório Aragon:
cd ~/AragonOSX
gitissuer add --file ISSUE_UPDATES.md
gitissuer prepare --repo Axodus/AragonOSX --dry-run
gitissuer deploy --batch --confirm
gitissuer e2e:run

# E tudo funcionará perfeitamente ✅
```

---

## 🚀 Próximo Passo

**Pressione para confirmar a implementação:**

```
[1] ✅ CONFIRMAR - Implementar arquitetura global conforme planejado
[2] ⚠️  AJUSTAR - Quero mudar alguns detalhes (qual?)
[3] ❌ CANCELAR - Voltar à versão anterior
```

---

**Qual opção?** 👇
