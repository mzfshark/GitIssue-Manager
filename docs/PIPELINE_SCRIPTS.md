# Pipeline Scripts - Referência Rápida

## 🚀 Uso Básico

Todos os comandos abaixo utilizam `pnpm` (ou `npm`).

### Pipeline Completo
```bash
pnpm pipeline
```
Executa STAGE 1-6 em sequência.

---

## 📋 Scripts por Estágio

### STAGE 1: SETUP
```bash
pnpm pipeline:setup
```
✅ Verifica autenticação GitHub CLI  
✅ Verifica acesso aos 3 repositórios  
✅ Valida configuração

**Tempo:** ~5 segundos

---

### STAGE 2: PREPARE
```bash
pnpm pipeline:prepare
```
✅ Faz parsing dos arquivos PLAN.md  
✅ Gera configuração intermediária  
✅ Valida metadados

**Tempo:** ~5 segundos

---

### STAGE 3: CREATE
```bash
pnpm pipeline:create
```
✅ Cria issues pais (1 por repositório)  
✅ Cria issues filhas (4-6 por repositório)  
✅ Cada issue filha tem tasks (checklists)  
✅ Deduplicação automática (evita duplicatas)

**Tempo:** ~30-60 segundos (depende do GitHub API)

---

### STAGE 4: FETCH
```bash
pnpm pipeline:fetch
```
✅ Verifica que issues foram criadas  
✅ Confirma existência no GitHub  
✅ Valida dados

**Tempo:** ~10 segundos

---

### STAGE 5: METADATA
```bash
pnpm pipeline:metadata
```
✅ Prepara sincronização ProjectV2  
✅ Valida campos customizados  
✅ Gera configuração para sync

**Tempo:** ~5 segundos

---

### STAGE 6: REPORTS
```bash
pnpm pipeline:reports
```
✅ Gera audit logs  
✅ Cria relatório de execução  
✅ Documenta todas as ações

**Tempo:** ~5 segundos

---

## 🔧 Scripts de Utilidade

### Listar Informações
```bash
# Mostrar ajuda completa
pnpm pipeline:help

# Listar estágios disponíveis
pnpm pipeline:list-stages

# Listar repositórios
pnpm pipeline:list-repos
```

### Usar com Argumentos
```bash
# Executar com --stage <NUM>
bash scripts/execute-pipeline.sh --stage 3

# Executar com --repo <REPO>
bash scripts/execute-pipeline.sh --repo AragonOSX

# Combinar filtros
bash scripts/execute-pipeline.sh --stage 3 --repo aragon-app
```

---

## 💡 Exemplos Práticos

### Cenário 1: Criar issues apenas para AragonOSX
```bash
bash scripts/execute-pipeline.sh --stage 3 --repo AragonOSX
```

### Cenário 2: Testar conectividade antes de tudo
```bash
pnpm pipeline:setup
```

### Cenário 3: Reexecutar apenas relatórios
```bash
pnpm pipeline:reports
```

### Cenário 4: Debug completo de um repositório
```bash
pnpm pipeline:setup
pnpm pipeline:prepare
bash scripts/execute-pipeline.sh --stage 3 --repo AragonOSX
pnpm pipeline:fetch
```

### Cenário 5: Full pipeline com relatório
```bash
pnpm pipeline
```

---

## ⚡ Sequência Recomendada

### Primeira Execução
```bash
pnpm pipeline:setup     # Verificar
pnpm pipeline:prepare   # Preparar
pnpm pipeline:create    # Criar
pnpm pipeline:fetch     # Verificar
pnpm pipeline:reports   # Relatar
```

### Reexecução Após Ajustes
```bash
bash scripts/execute-pipeline.sh --stage 3 --repo AragonOSX  # Só um repo
pnpm pipeline:fetch                                           # Verificar
```

### Apenas Sincronizar Metadata
```bash
pnpm pipeline:metadata  # Preparar
# Depois rode: npm run apply-metadata
```

---

## 🎯 Flags & Opções

| Flag | Descrição | Exemplo |
|------|-----------|---------|
| `--stage <1-6>` | Executar estágio específico | `--stage 3` |
| `--repo <REPO>` | Executar para repo específico | `--repo AragonOSX` |
| `--help` | Mostrar ajuda | `--help` |
| `--list-stages` | Listar estágios | `--list-stages` |
| `--list-repos` | Listar repositórios | `--list-repos` |

---

## 📊 Output Esperado

Cada execução gera:

1. **Console Output**
   - Status de cada stage
   - ✅ Sucesso ou ❌ Erro
   - Timestamp detalhado

2. **Audit Logs**
   - Localização: `tmp/audit-log-YYYYMMDD-HHMMSS.log`
   - Contém: Todas as ações executadas
   - Útil para debugging

3. **Configurações**
   - Localização: `tmp/`, `sync-helper/configs/`
   - Reutilizáveis para próximas execuções

---

## 🐛 Troubleshooting

### Erro: "GitHub CLI not authenticated"
```bash
gh auth login
pnpm pipeline:setup  # Tentar novamente
```

### Erro: "Repository not found"
```bash
# Verificar acesso
gh repo list | grep AragonOSX
# Ou verificar permissions no GitHub
```

### Erro: "Invalid stage"
```bash
# Use stage 1-6 apenas
pnpm pipeline:setup    # ✅ Correto
pnpm pipeline --stage 7 # ❌ Erro
```

### Executar com debug
```bash
bash -x scripts/execute-pipeline.sh --stage 1
```

---

## ✅ Checklist de Execução

- [ ] Autenticação GitHub CLI (`gh auth status`)
- [ ] Todos 3 repositórios acessíveis (`pnpm pipeline:setup`)
- [ ] PLAN.md files presentes (3 repositórios)
- [ ] Executar stage 3 (`pnpm pipeline:create`)
- [ ] Verificar criação (`pnpm pipeline:fetch`)
- [ ] Gerar relatório (`pnpm pipeline:reports`)
- [ ] Revisar logs (`tail tmp/audit-log-*.log`)

---

**Status:** 🎉 Ready for Production (v3 + pnpm scripts)
