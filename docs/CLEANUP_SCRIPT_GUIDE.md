# GitHub Issue Cleanup Script Guide

## 1. Visão Geral

O **cleanup script** identifica e fecha automaticamente issues que não estão referenciadas em arquivos `PLAN.md`, marcando-as como "not-implemented". 

**Problema**: Após sincronizações automáticas de markdown, acumulam-se centenas de issues órfãs que não fazem parte da estratégia atual de desenvolvimento.

**Solução**: Script compara issues abertas contra PLAN.md como fonte de verdade, permitindo cleanup massivo com segurança (dry-run padrão).

---

## 2. Instalação e Setup

### Pré-requisitos

- **GitHub CLI** (gh): https://cli.github.com/
  ```bash
  # Verify installation
  gh --version
  
  # Authenticate
  gh auth login
  ```

- **jq**: JSON processor
  ```bash
  # macOS
  brew install jq
  
  # Ubuntu/Debian
  sudo apt-get install jq
  
  # Windows (git bash ou WSL)
  choco install jq  # ou via winget
  ```

- **Bash 4+**
  ```bash
  bash --version
  ```

### Localização

```
GitIssue-Manager/
├── scripts/
│   └── cleanup_unnecessary_issues.sh    # Script principal
├── cleanup-config.json                   # Config default (criar)
└── docs/
    ├── CLEANUP_SCRIPT_GUIDE.md           # Este arquivo
    ├── cleanup-config.example.json       # Template
    └── CLEANUP_EXAMPLES.md               # Exemplos práticos
```

### Primeira Execução

```bash
cd GitIssue-Manager

# 1. Copiar arquivo de config
cp docs/cleanup-config.example.json cleanup-config.json

# 2. Editar conforme necessário
nano cleanup-config.json

# 3. Testar permissões
gh auth status

# 4. Dry-run inicial (sem fazer alterações)
bash scripts/cleanup_unnecessary_issues.sh --limit 10
```

---

## 3. Arquivo de Configuração

### Estrutura: `cleanup-config.json`

```json
{
  "repos": [
    "mzfshark/AragonOSX",
    "Axodus/aragon-app",
    "Axodus/Aragon-app-backend"
  ],
  "plan_files": {
    "mzfshark/AragonOSX": [
      "PLAN.md",
      "PLAN_admin_grant_closeout.md"
    ],
    "Axodus/aragon-app": ["PLAN.md"],
    "Axodus/Aragon-app-backend": ["PLAN.md"]
  },
  "defaults": {
    "status": "open",
    "limit": null,
    "skip_labels": ["pinned", "important"],
    "mode": "without-plan"
  }
}
```

### Parâmetros

| Campo | Tipo | Descrição |
|-------|------|-----------|
| `repos` | array | Lista de repos no formato `owner/name` |
| `plan_files` | object | Mapa de repo → lista de PLAN files |
| `defaults.status` | string | `open`, `closed`, ou `all` |
| `defaults.limit` | number/null | Limite padrão de issues (null = sem limite) |
| `defaults.skip_labels` | array | Labels a ignorar na busca |
| `defaults.mode` | string | `without-plan` (fechar não-ref) ou `with-plan` (fechar ref) |

### Hierarquia de Prioridade

Flags CLI **sobrescrevem** config.json:

```
CLI Flags > config.json > Script Defaults
```

---

## 4. Interface de Flags

### Flags Disponíveis

#### Seleção de Repos
```bash
--repos REPO1,REPO2,REPO3
```
Override repos do `cleanup-config.json`. Formato: `owner/name,owner/name,...`

#### Seleção de Issues

```bash
--include-labels LABEL1,LABEL2
```
Incluir APENAS issues com um desses labels (alternativa: buscar qualquer label).

```bash
--exclude-labels LABEL1,LABEL2
```
Excluir issues com esses labels da busca.

```bash
--status open|closed|all
```
Filtrar por status. Default: `open`.

```bash
--from-date YYYY-MM-DD
```
Incluir APENAS issues criadas antes dessa data.

```bash
--to-date YYYY-MM-DD
```
Incluir APENAS issues criadas depois dessa data.

#### Modo de Lógica

```bash
--without-plan
```
Fechar issues NÃO referenciadas em PLAN.md (default).

```bash
--with-plan
```
Fechar issues referenciadas em PLAN.md (lógica inversa).

#### Controle de Execução

```bash
--limit N
```
Processar no máximo N issues. Útil para testes.

```bash
--execute
```
Aplicar mudanças (default: dry-run, apenas preview).

```bash
--config FILE
```
Usar arquivo de config customizado (default: `cleanup-config.json`).

#### Informação

```bash
--help
```
Exibir ajuda.

```bash
--debug
```
Modo verbose (output detalhado).

---

## 5. Exemplos Práticos

### Scenario A: Limpeza Inicial (Dry-Run)

```bash
# Preview: 20 primeiras issues não em PLAN (AragonOSX default)
bash scripts/cleanup_unnecessary_issues.sh --limit 20

# Output esperado:
# [INFO] Found 654 issues to close (not in PLAN documents)
# [INFO] Preview of first 20 issues:
#   Issue #620: adapt SDK
#   Issue #619: add support for plugin registry
#   ...
# [INFO] To close these, run:
#   bash cleanup_unnecessary_issues.sh --execute --limit 20
```

### Scenario B: Executar Cleanup em Subset

```bash
# Fechar primeiras 50 issues não em PLAN
bash scripts/cleanup_unnecessary_issues.sh \
  --execute \
  --limit 50

# Output esperado:
# [SUCCESS] ✓ Closed #620: adapt SDK
# [SUCCESS] ✓ Closed #619: add support for plugin registry
# ...
# [SUCCESS] CLEANUP SUMMARY
# [SUCCESS] Closed: 50 / 50
# [INFO] Log: logs/cleanup_20260120_180000.log
```

### Scenario C: Multi-Repo Cleanup

```bash
# Fechar issues não em PLAN em todos os 3 repos
bash scripts/cleanup_unnecessary_issues.sh \
  --repos "mzfshark/AragonOSX,Axodus/aragon-app,Axodus/Aragon-app-backend" \
  --execute

# Output esperado:
# [INFO] Processing mzfshark/AragonOSX...
#   Found 654 issues to close
#   Closed: 654 / 654
# [INFO] Processing Axodus/aragon-app...
#   Found 15 issues to close
#   Closed: 15 / 15
# [INFO] Processing Axodus/Aragon-app-backend...
#   Found 8 issues to close
#   Closed: 8 / 8
# [SUCCESS] TOTAL: 677 issues closed across 3 repos
```

### Scenario D: Filtrar por Label

```bash
# Fechar apenas issues com label "sync-md" não em PLAN
bash scripts/cleanup_unnecessary_issues.sh \
  --repos "mzfshark/AragonOSX" \
  --include-labels "sync-md" \
  --limit 100 \
  --execute

# Issues COM label sync-md + NÃO em PLAN → fechadas
```

### Scenario E: Filtrar por Data de Criação

```bash
# Fechar issues criadas ANTES de 2025-01-01 não em PLAN
bash scripts/cleanup_unnecessary_issues.sh \
  --from-date "2025-01-01" \
  --limit 200 \
  --execute

# Fecha issues antigas que acumularam antes dessa data
```

### Scenario F: Config Customizado

```bash
# Criar config customizado para um repo específico
cp docs/cleanup-config.example.json custom-cleanup.json
# Editar: deixar apenas um repo, ajustar PLAN files, etc.

bash scripts/cleanup_unnecessary_issues.sh \
  --config ./custom-cleanup.json \
  --execute
```

### Scenario G: Lógica Inversa (Debug)

```bash
# Fechar issues que ESTÃO em PLAN (inverter lógica)
# Útil para debug ou estratégias alternativas
bash scripts/cleanup_unnecessary_issues.sh \
  --with-plan \
  --limit 10

# Issues QUE ESTÃO em PLAN → seriam fechadas (apenas preview)
```

### Scenario H: Modo Debug

```bash
# Output verboso para troubleshooting
bash scripts/cleanup_unnecessary_issues.sh \
  --debug \
  --limit 5

# Mostra:
# - Linhas de PLAN.md encontradas
# - Regex matches
# - Query construída para gh CLI
# - Response raw da API
```

---

## 6. Lógica de Seleção de Issues

### Fluxo Padrão (`--without-plan`)

```
1. Buscar todos os open issues da repo (--state open)
2. Extrair números de PLAN.md (pattern: #123, #456, ...)
3. Para cada issue aberta:
   IF issue_number NOT IN plan_numbers THEN
       → Adicionar à lista de fechamento
4. Fechar com comentário "not-implemented"
```

### Exemplo Visual

```
PLAN.md contém:    #150, #156, #160, #162
Issues abertas:    #620, #619, #618, #156, #150, #100, #95, ...

Lógica de seleção:
  #620 → NOT in PLAN → FECHAR
  #619 → NOT in PLAN → FECHAR
  #618 → NOT in PLAN → FECHAR
  #156 → IN PLAN → MANTER
  #150 → IN PLAN → MANTER
  #100 → NOT in PLAN → FECHAR
  #95  → NOT in PLAN → FECHAR
```

### Fluxo com Flags Adicionais

```
gh issue list \
  --repo mzfshark/AragonOSX \
  --state open \
  [--label sync-md]              # Se --include-labels
  --limit 10000                  # Paginação
  --json number,title,createdAt
```

Comparação posterior contra PLAN.md + filtros de data.

---

## 7. Troubleshooting

### Erro: "gh command not found"

```bash
# Solução: Instalar GitHub CLI
# macOS
brew install gh

# Ubuntu/Debian
sudo apt-get install gh

# Windows
choco install gh
# ou: https://cli.github.com/
```

### Erro: "jq command not found"

```bash
# Solução: Instalar jq
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# Windows
choco install jq
```

### Erro: "Cannot access repository"

```bash
# Causa: Autenticação falhou ou repo não existe

# Solução 1: Verificar auth
gh auth status

# Solução 2: Re-autenticar
gh auth logout
gh auth login

# Solução 3: Verificar permissões
gh repo view OWNER/REPO
```

### Erro: "Found 0 issue numbers in PLAN documents"

```bash
# Causa 1: PLAN.md não existe ou não está no PATH
# Solução: Verificar arquivo
ls -la PLAN.md PLAN_admin_grant_closeout.md

# Causa 2: Padrão regex não encontra números
# Solução: Debug com --debug flag
bash scripts/cleanup_unnecessary_issues.sh --debug --limit 1

# Cause 3: Formato diferente de referência em PLAN.md
# Exemplo: "Issue 123" em vez de "#123"
# Solução: Editar script ou PLAN.md para padronizar
```

### Erro: "Rate limit exceeded"

```bash
# Causa: Muitas requisições à GitHub API (60 por hora padrão)

# Solução 1: Aguardar 1 hora
# Solução 2: Aumentar sleep entre requests
#   Editar: sleep 0.5 → sleep 2.0
# Solução 3: Usar GitHub token com maior limite
gh auth status --show-token
```

### Issues não fecham no --execute

```bash
# Causa: Permissões insuficientes (repo admin required)

# Verificar permissão
gh repo view OWNER/REPO

# Se não for admin, solicitar:
gh repo list --jq '.[] | select(.name=="REPO_NAME")'

# Alternativa: Pedir para admin executar o script
```

### Log file não encontrado

```bash
# Logs salvos em: ./logs/cleanup_TIMESTAMP.log

# Verificar diretório
ls -la ./logs/

# Se não existir, criar:
mkdir -p ./logs
```

---

## 8. Safety & Rate-Limiting

### Dry-Run (Padrão)

```bash
# NÃO faz alterações, apenas preview
bash scripts/cleanup_unnecessary_issues.sh

# Output:
# [WARN] DRY-RUN MODE: Not making any changes.
# [INFO] Preview of first 20 issues:
#   Issue #620: adapt SDK
#   ...
```

### Rate-Limiting

- **Sleep padrão**: 0.5s entre requisições
- **Limite GitHub API**: ~60 req/hour (públicas) ou 5000 req/hour (autenticadas)
- **Com 0.5s sleep**: ~7200 req/hour (safe)
- **Tempo estimado**: 654 issues = ~5 minutos

### Comentário de Closure

Cada issue recebe comentário explicativo:

```
This issue is marked as 'not-implemented' because it does not appear 
in the current PLAN.md documentation. It may be:
- Auto-generated from an older framework sync
- Duplicate or superseded by other work
- Out of scope for the current sprint

If needed, reopen and link to PLAN.md.
```

### Reversão

Se precisar reabrir issues:

```bash
# Reverter issue específica
gh issue reopen ISSUE_NUMBER --repo OWNER/REPO

# Reverter múltiplas (de um log)
cat cleanup_20260120_180000.log | grep "Closed #" | \
  awk '{print $3}' | sed 's/:.*$//' | \
  xargs -I {} gh issue reopen {} --repo mzfshark/AragonOSX
```

### Backup de IDs Fechados

Log file contém lista completa:

```bash
# Extrair todos os IDs fechados
grep "Closed #" cleanup_*.log | awk '{print $3}' > closed_issues.txt

# Usar para reverter depois, se necessário
```

---

## 9. Logs e Reporting

### Arquivo de Log

Salvo em: `./logs/cleanup_TIMESTAMP.log`

Formato:

```
[INFO] Starting cleanup script for mzfshark/AragonOSX
[INFO] Authenticated as: github.com
[INFO] Found 654 issues to close (not in PLAN documents)
[SUCCESS] ✓ Closed #620: adapt SDK
[SUCCESS] ✓ Closed #619: add support for plugin registry
...
[SUCCESS] CLEANUP SUMMARY
[SUCCESS] Closed: 654 / 654
```

### Extraction de Dados do Log

```bash
# Contar issues fechadas
grep "Closed #" cleanup_*.log | wc -l

# Listar IDs
grep -oE "Closed #[0-9]{1,4}" cleanup_*.log | cut -d'#' -f2

# Encontrar falhas
grep "\[ERROR\]" cleanup_*.log
```

---

## 10. Integração com CI/CD (Futuro)

### GitHub Actions Workflow

```yaml
name: Weekly Issue Cleanup

on:
  schedule:
    - cron: '0 2 * * 0'  # Toda semana segunda, 2AM UTC

jobs:
  cleanup:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install dependencies
        run: |
          sudo apt-get install -y jq
      - name: Run cleanup
        run: |
          bash scripts/cleanup_unnecessary_issues.sh --execute
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      - name: Upload log
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: cleanup-logs
          path: ./logs/
```

---

## 11. FAQ

**P: Posso reabrair issues fechadas?**
R: Sim. Use `gh issue reopen ISSUE_NUMBER`. Veja seção "Reversão" acima.

**P: O que diferencia issues "without-plan" de "with-plan"?**
R: 
- `--without-plan`: Fecha issues NÃO em PLAN (cleanup default)
- `--with-plan`: Fecha issues EM PLAN (lógica inversa, para estratégias especiais)

**P: Como faço clean em múltiplos repos com configs diferentes?**
R: Criar múltiplos `cleanup-config-X.json` e rodar:
```bash
bash scripts/cleanup_unnecessary_issues.sh --config ./cleanup-config-repo1.json --execute
bash scripts/cleanup_unnecessary_issues.sh --config ./cleanup-config-repo2.json --execute
```

**P: Posso programar limpeza automática (cron)?**
R: Sim. Adicionar ao crontab:
```bash
0 2 * * 0 cd /path/to/GitIssue-Manager && bash scripts/cleanup_unnecessary_issues.sh --execute
```

**P: Como monitorar progresso durante --execute?**
R: Tail do log file:
```bash
tail -f logs/cleanup_*.log
```

---

## Referências

- [GitHub CLI Docs](https://cli.github.com/manual/)
- [gh issue list](https://cli.github.com/manual/gh_issue_list)
- [jq Manual](https://stedolan.github.io/jq/manual/)

---

**Versão**: 1.0  
**Última atualização**: 20 de janeiro de 2026  
**Autor**: Aragon DevOps  
**Status**: Production Ready
