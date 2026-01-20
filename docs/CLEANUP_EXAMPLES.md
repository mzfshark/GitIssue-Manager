# GitHub Issue Cleanup Script - Exemplos Práticos

Guia rápido com 20+ exemplos prontos para copiar/colar. Para referência completa, veja [CLEANUP_SCRIPT_GUIDE.md](./CLEANUP_SCRIPT_GUIDE.md).

---

## Exemplo 1: Preview Inicial (Dry-Run Seguro)

```bash
# Visualizar 20 primeiras issues não em PLAN (sem fazer nada)
bash scripts/cleanup_unnecessary_issues.sh --limit 20
```

**Output esperado:**
```
[INFO] Starting cleanup script for mzfshark/AragonOSX
[INFO] Found 654 issues to close (not in PLAN documents)
[INFO] Preview of first 20 issues:
[INFO]   Issue #620: adapt SDK
[INFO]   Issue #619: add support for plugin registry
[INFO]   Issue #618: test the storage...
...
[WARN] DRY-RUN MODE: Not making any changes.
[INFO] To close these, run:
  bash cleanup_unnecessary_issues.sh --execute --limit 20
```

**Quando usar**: Primeira vez, antes de qualquer alteração.

---

## Exemplo 2: Fechar Batch de 50 Issues

```bash
# Executar: fechar primeiras 50 issues não em PLAN
bash scripts/cleanup_unnecessary_issues.sh \
  --execute \
  --limit 50
```

**Output esperado:**
```
[SUCCESS] ✓ Closed #620: adapt SDK
[SUCCESS] ✓ Closed #619: add support for plugin registry
[SUCCESS] ✓ Closed #618: test the storage...
...
[SUCCESS] CLEANUP SUMMARY
[SUCCESS] Closed: 50 / 50
[INFO] Log: logs/cleanup_20260120_180000.log
```

**Tempo estimado**: ~25 segundos (com 0.5s rate-limit)

**Quando usar**: Cleanup em lotes pequenos, monitorar progresso.

---

## Exemplo 3: Fechar Todas as 654 Issues

```bash
# ⚠️ CUIDADO: Fechará TODAS as 654 issues não em PLAN
bash scripts/cleanup_unnecessary_issues.sh --execute
```

**Output esperado:**
```
[INFO] Found 654 issues to close (not in PLAN documents)
[INFO] EXECUTE MODE: Closing 654 issues as 'not-implemented'...
[SUCCESS] ✓ Closed #620: adapt SDK
[SUCCESS] ✓ Closed #619: add support for plugin registry
...
[SUCCESS] CLEANUP SUMMARY
[SUCCESS] Closed: 654 / 654
[INFO] Log: logs/cleanup_20260120_180000.log
```

**Tempo estimado**: ~5 minutos (654 × 0.5s + processamento)

**Quando usar**: Limpeza definitiva da repo (apenas após validar com dry-run).

---

## Exemplo 4: Multi-Repo Cleanup

```bash
# Fechar issues não em PLAN em TODOS os 3 repos
bash scripts/cleanup_unnecessary_issues.sh \
  --repos "mzfshark/AragonOSX,Axodus/aragon-app,Axodus/Aragon-app-backend" \
  --execute
```

**Output esperado:**
```
[INFO] Processing repo 1/3: mzfshark/AragonOSX
[SUCCESS] ✓ Closed #620: adapt SDK
...
[SUCCESS] Closed: 654 / 654

[INFO] Processing repo 2/3: Axodus/aragon-app
[SUCCESS] ✓ Closed #162: some issue
...
[SUCCESS] Closed: 15 / 15

[INFO] Processing repo 3/3: Axodus/Aragon-app-backend
[SUCCESS] ✓ Closed #14: another issue
...
[SUCCESS] Closed: 8 / 8

[SUCCESS] TOTAL SUMMARY
[SUCCESS] AragonOSX:          654 closed
[SUCCESS] aragon-app:         15 closed
[SUCCESS] Aragon-app-backend: 8 closed
[SUCCESS] GRAND TOTAL:        677 issues closed
```

**Quando usar**: Cleanup corporativo em múltiplas repos com um comando.

---

## Exemplo 5: Cleanup Config Customizado

```bash
# Criar config para apenas um repo
cp docs/cleanup-config.example.json my-cleanup.json

# Editar: deixar apenas AragonOSX
# nano my-cleanup.json

# Executar com config customizado
bash scripts/cleanup_unnecessary_issues.sh \
  --config ./my-cleanup.json \
  --execute
```

**Quando usar**: Quando você quer diferentes configs para diferentes repos.

---

## Exemplo 6: Filtrar por Label Específico

```bash
# Fechar APENAS issues com label "sync-md" que NÃO estão em PLAN
bash scripts/cleanup_unnecessary_issues.sh \
  --repos "mzfshark/AragonOSX" \
  --include-labels "sync-md" \
  --limit 100 \
  --execute
```

**Lógica:**
- Issue TEM label "sync-md"
- Issue NÃO está em PLAN.md
- → Fechar

**Quando usar**: Limpeza seletiva de issues auto-geradas por sincronização.

---

## Exemplo 7: Excluir Labels Importantes

```bash
# Fechar issues NÃO em PLAN, MAS ignorar com labels "pinned" ou "important"
bash scripts/cleanup_unnecessary_issues.sh \
  --repos "mzfshark/AragonOSX" \
  --exclude-labels "pinned,important" \
  --execute
```

**Lógica:**
- Issue NÃO está em PLAN
- Issue NÃO tem labels "pinned" ou "important"
- → Fechar

**Quando usar**: Proteger issues críticas durante cleanup automático.

---

## Exemplo 8: Filtrar por Data (Issues Antigas)

```bash
# Fechar issues criadas ANTES de 2025-01-01 e não em PLAN
bash scripts/cleanup_unnecessary_issues.sh \
  --from-date "2025-01-01" \
  --limit 200 \
  --execute
```

**Lógica:**
- Issue criada ANTES de 2025-01-01
- Issue NÃO está em PLAN
- → Fechar

**Quando usar**: Limpeza de débito técnico antigo.

---

## Exemplo 9: Issues Criadas Após Data Específica

```bash
# Fechar issues criadas DEPOIS de 2025-06-01 e não em PLAN
bash scripts/cleanup_unnecessary_issues.sh \
  --to-date "2025-06-01" \
  --execute
```

**Quando usar**: Cleanup de issues recém-geradas em período específico.

---

## Exemplo 10: Range de Datas

```bash
# Fechar issues criadas entre 2025-01-01 e 2025-06-30, não em PLAN
bash scripts/cleanup_unnecessary_issues.sh \
  --from-date "2025-01-01" \
  --to-date "2025-06-30" \
  --execute
```

**Quando usar**: Limpeza de período específico (ex: após sprint antigo).

---

## Exemplo 11: Lógica Inversa (Debug)

```bash
# Preview: Issues que ESTÃO em PLAN (lógica inversa, para debug)
bash scripts/cleanup_unnecessary_issues.sh \
  --with-plan \
  --limit 10
```

**Output esperado:**
```
[INFO] Mode: with-plan (INVERSE logic)
[INFO] Issues to close: (those IN PLAN - unusual mode)
[INFO]   Issue #150: ...
[INFO]   Issue #156: ...
```

**Quando usar**: Debug de PLAN.md ou estratégias alternativas.

---

## Exemplo 12: Fechar Issues Fechadas

```bash
# Listar/fechar issues já fechadas (para limpeza de "duplicatas fechadas")
bash scripts/cleanup_unnecessary_issues.sh \
  --status "closed" \
  --limit 20
```

**Quando usar**: Limpeza de issues em estado "closed" que podem ser removidas.

---

## Exemplo 13: Listar Tudo (sem filtro de status)

```bash
# Listar issues abertas E fechadas não em PLAN
bash scripts/cleanup_unnecessary_issues.sh \
  --status "all" \
  --limit 50
```

**Quando usar**: Auditoria completa.

---

## Exemplo 14: Modo Debug (Verbose)

```bash
# Saída detalhada para troubleshooting
bash scripts/cleanup_unnecessary_issues.sh \
  --debug \
  --limit 5
```

**Output inclui:**
```
[DEBUG] Extracting issues from PLAN.md...
[DEBUG] Found lines:
  Issue #150 [line 45 PLAN.md]
  Issue #156 [line 62 PLAN.md]
[DEBUG] GitHub API query:
  gh issue list --repo mzfshark/AragonOSX --state open --limit 10000
[DEBUG] Response: 654 issues returned
[DEBUG] Comparison results:
  #620 NOT in PLAN → close
  #156 IN PLAN → keep
```

**Quando usar**: Debug de regex ou query construction.

---

## Exemplo 15: Testar em Fork Primeiro

```bash
# Clone um fork local para testar
gh repo fork Axodus/aragon-app --clone

# Executar cleanup em seu fork
bash scripts/cleanup_unnecessary_issues.sh \
  --repos "YOUR_USERNAME/aragon-app" \
  --execute --limit 10

# Se tudo OK, fazer em repo principal
bash scripts/cleanup_unnecessary_issues.sh \
  --repos "Axodus/aragon-app" \
  --execute
```

**Quando usar**: Testing seguro antes de cleanup em produção.

---

## Exemplo 16: Monitorar Cleanup em Tempo Real

```bash
# Terminal 1: Iniciar cleanup
bash scripts/cleanup_unnecessary_issues.sh --execute

# Terminal 2: Tail do log em tempo real
tail -f logs/cleanup_*.log

# Terminal 3: Monitorar issues abertas
watch -n 5 'gh issue list --repo mzfshark/AragonOSX --state open --json number | jq ". | length"'
```

**Quando usar**: Monitoring durante cleanup massivo.

---

## Exemplo 17: Reverter Issues Fechadas

```bash
# Se precisar reabrir algumas issues:

# 1. Extrair IDs do log
grep "Closed #" logs/cleanup_20260120_180000.log | \
  awk '{print $3}' | sed 's/:.*//' > reopened.txt

# 2. Reabrir algumas (ex: primeiras 5)
head -5 reopened.txt | xargs -I {} \
  gh issue reopen {} --repo mzfshark/AragonOSX

# 3. Verificar
cat reopened.txt | head -5 | xargs -I {} \
  gh issue view {} --repo mzfshark/AragonOSX --json number,state
```

**Output esperado:**
```
number  state
------  -----
620     OPEN
619     OPEN
618     OPEN
...
```

**Quando usar**: Reverter acidental closes.

---

## Exemplo 18: Extrair Estatísticas do Log

```bash
# Contar total fechado
grep -c "Closed #" logs/cleanup_*.log

# Listar todos os IDs fechados
grep "Closed #" logs/cleanup_*.log | awk '{print $3}' | sed 's/:.*$//'

# Gerar CSV
grep "Closed #" logs/cleanup_*.log | \
  awk '{print $3, $4, $5, $6, $7}' | \
  sed 's/:.*$//' > closed_issues.csv

# Contar falhas
grep -c "\[ERROR\]" logs/cleanup_*.log || echo "0"
```

**Quando usar**: Auditoria e relatórios.

---

## Exemplo 19: Cleanup Automático via Cron

```bash
# Adicionar ao crontab (executar toda segunda 2AM UTC)
(crontab -l 2>/dev/null; echo "0 2 * * 1 cd /path/to/GitIssue-Manager && bash scripts/cleanup_unnecessary_issues.sh --execute") | crontab -

# Verificar
crontab -l
```

**Output esperado:**
```
0 2 * * 1 cd /path/to/GitIssue-Manager && bash scripts/cleanup_unnecessary_issues.sh --execute
```

**Quando usar**: Cleanup automático semanal.

---

## Exemplo 20: GitHub Actions Workflow

```yaml
# Criar arquivo: .github/workflows/cleanup-issues.yml

name: Weekly Issue Cleanup

on:
  schedule:
    - cron: '0 2 * * 1'  # Toda segunda, 2AM UTC
  workflow_dispatch:     # Manual trigger

jobs:
  cleanup:
    runs-on: ubuntu-latest
    permissions:
      issues: write
      contents: read
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
      
      - name: Upload logs
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: cleanup-logs-${{ github.run_id }}
          path: logs/
          retention-days: 30
```

**Push para repo e habilitar workflows.**

**Quando usar**: Cleanup automático em CI/CD.

---

## Exemplo 21: Limpar Cache Local

```bash
# Se script fica lento, limpar caches
rm -rf ~/.cache/gh/  # Cache do GitHub CLI
gh auth status       # Re-authenticate se necessário
```

**Quando usar**: Troubleshooting de performance.

---

## Exemplo 22: Comparar Antes/Depois

```bash
# ANTES: Contar issues
BEFORE=$(gh issue list --repo mzfshark/AragonOSX --state open --json number | jq ". | length")

# EXECUTAR
bash scripts/cleanup_unnecessary_issues.sh --execute

# DEPOIS: Contar issues novamente
AFTER=$(gh issue list --repo mzfshark/AragonOSX --state open --json number | jq ". | length")

# RELATORIO
echo "Before: $BEFORE open issues"
echo "After:  $AFTER open issues"
echo "Closed: $((BEFORE - AFTER)) issues"
```

**Output esperado:**
```
Before: 700 open issues
After:  46 open issues
Closed: 654 issues
```

**Quando usar**: Validação e relatório de cleanup.

---

## Dicas & Boas Práticas

### ✅ Faça

- **Dry-run primeiro**: `bash scripts/cleanup_unnecessary_issues.sh --limit 20`
- **Revisar PLAN.md**: Certifique-se que contém todos os issues válidos antes de cleanup
- **Monitorar logs**: `tail -f logs/cleanup_*.log` durante execução
- **Backup de IDs**: `grep "Closed #" logs/*.log > closed_backup.txt`
- **Alertar time**: Notifique antes de cleanup massivo (654 issues)

### ❌ Não Faça

- **Cleanup sem dry-run**: Sempre testar antes de `--execute`
- **Confiar apenas em labels**: Use PLAN.md como source of truth
- **Ignorar logs**: Sempre revisar `logs/cleanup_*.log` após execução
- **Cleanup automaticamente sem aprovação**: Require manual approval para cleanup > 100 issues
- **Editar PLAN.md manualmente antes do cleanup**: Script usa versão no disk

---

## Próximas Execuções

Após cleanup inicial:

1. **Manter PLAN.md atualizado** — Add novos issues quando criados
2. **Executar cleanup mensal** — `cron 0 2 * * 1 ...`
3. **Monitorar novos orphans** — Issues criadas fora de PLAN
4. **Integrar em CI/CD** — GitHub Actions workflow automático

---

**Última atualização**: 20 de janeiro de 2026  
**Versão**: 1.0
