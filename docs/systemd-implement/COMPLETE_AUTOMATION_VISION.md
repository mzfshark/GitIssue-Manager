# 🎯 GITISSUER - COMPLETE AUTOMATION VISION

**Status**: 📋 Architecture + Implementation Ready  
**Data**: 22 Janeiro 2025  
**Escopo**: Global GitIssuer Tool + Systemd Automation

---

## 🏗️ Arquitetura Completa (3 Camadas)

```
┌─────────────────────────────────────────────────────────────┐
│  CAMADA 1: SYSTEMD AUTOMATION (Sistema)                    │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  gitissuer.timer (09:00 AM diariamente)                   │
│  ↓                                                          │
│  gitissuer.service                                         │
│  ├── Itera sobre repos (OSX, app, backend)               │
│  ├── Detecta ISSUE_UPDATES.md                           │
│  ├── Cria ./docs/plans/*_UPDATE.md (local)              │
│  └── Executa workflow 4 etapas                          │
│                                                             │
│  gitissuer-watch.service (opcional)                       │
│  └── Monitora mudanças em tempo real (inotify)           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
           ↓
┌─────────────────────────────────────────────────────────────┐
│  CAMADA 2: GITISSUER TOOL (Aplicação)                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  /opt/GitIssue-Manager/scripts/                            │
│  ├── gitissuer.js (refatorado em módulos)                │
│  │   ├── cli-parser.js (parse commands)                 │
│  │   ├── file-manager.js (salvar local)                 │
│  │   ├── github-client.js (GitHub CLI)                  │
│  │   └── workflow.js (orquestração)                    │
│  └── gitissuer.sh (wrapper executável)                  │
│                                                             │
│  Alias Global: gitissuer (executável em qualquer lugar)  │
│                                                             │
│  Workflow de 4 Etapas:                                    │
│  1️⃣ add      → Carrega ISSUE_UPDATES.md                  │
│  2️⃣ prepare  → Simula mudanças (--dry-run)              │
│  3️⃣ deploy   → Aplica mudanças reais                    │
│  4️⃣ e2e:run  → Valida que funcionou                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
           ↓
┌─────────────────────────────────────────────────────────────┐
│  CAMADA 3: REPOSITÓRIOS (Dados Locais)                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  AragonOSX/                                                │
│  ├── ISSUE_UPDATES.md (entrada: dados PRs)              │
│  ├── docs/plans/                                         │
│  │   └── AragonOSX_20250122_UPDATE.md (salvo aqui)      │
│  └── .gitissuer/                                        │
│      ├── state.json (estado atual)                      │
│      ├── last-run.json (timestamp)                      │
│      └── logs/ (histórico)                             │
│                                                             │
│  aragon-app/  (similar)                                  │
│  Aragon-app-backend/  (similar)                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔄 Fluxo de Execução (Automático)

### Cenário 1: Agendado (Daily)

```
09:00 AM (systemd.timer)
   ↓
gitissuer.service inicia
   ↓
Para cada repo (OSX, app, backend):
   ├─ Detecta ISSUE_UPDATES.md
   ├─ gitissuer add --file ISSUE_UPDATES.md
   │  └─ Salva em ./docs/plans/*_UPDATE.md
   ├─ gitissuer prepare --dry-run
   │  └─ Valida mudanças (sem aplicar)
   ├─ gitissuer deploy --batch --confirm
   │  └─ Aplica títulos, bodies, labels, reviewers
   ├─ gitissuer e2e:run
   │  └─ Verifica que funcionou no GitHub
   └─ Registra resultado em .gitissuer/state.json
   
Logs em: journalctl -u gitissuer.service
```

### Cenário 2: On-Change (Real-time)

```
User cria/modifica ISSUE_UPDATES.md
   ↓
gitissuer-watch.service detecta (inotify)
   ↓
systemctl start gitissuer.service
   ↓
[mesmo fluxo acima]
```

### Cenário 3: Manual (On-Demand)

```bash
# De qualquer lugar:
gitissuer add --file ISSUE_UPDATES.md

# Ou modo completo:
gitissuer daemon --auto

# Ou serviço:
systemctl start gitissuer.service
```

---

## 📋 O Que Será Criado Automaticamente

### Estrutura em `/opt/GitIssue-Manager/`

```
/opt/GitIssue-Manager/
├── scripts/
│   ├── gitissuer.js           ← 402 linhas (refatorado)
│   ├── gitissuer.sh            ← wrapper
│   └── lib/                    ← módulos
│       ├── cli-parser.js       ← ~150 linhas
│       ├── file-manager.js     ← ~180 linhas
│       ├── github-client.js    ← ~200 linhas
│       └── workflow.js         ← ~250 linhas
│
├── systemd/
│   ├── gitissuer.service      ← Serviço
│   ├── gitissuer.timer         ← Scheduler (09:00 daily)
│   ├── gitissuer-watch.service ← File monitor
│   └── install.sh              ← Installer
│
├── daemon/
│   ├── gitissuer-daemon.sh    ← Main loop
│   ├── gitissuer-watch.sh     ← File watcher
│   └── gitissuer-auto.sh      ← Auto logic
│
├── config/
│   ├── repos.config.json      ← Repos a monitorar
│   ├── schedule.config.json   ← Agendamento
│   └── notifications.config.json ← Alertas
│
└── docs/
    ├── SYSTEMD_GUIDE.md
    ├── CONFIGURATION.md
    └── TROUBLESHOOTING.md
```

### Estrutura em cada repositório (criada automaticamente)

```
AragonOSX/
├── ISSUE_UPDATES.md (já existe - input)
├── docs/plans/
│   └── AragonOSX_20250122_UPDATE.md (criado por: gitissuer add)
└── .gitissuer/
    ├── state.json (estado atual)
    ├── last-run.json (timestamp última execução)
    ├── logs/
    │   ├── 20250122_daemon.log
    │   ├── 20250122_deploy.log
    │   └── 20250122_e2e.log
    └── backups/
        └── AragonOSX_20250121.backup.md (antes de deploy)

aragon-app/ (similar)
Aragon-app-backend/ (similar)
```

---

## 🎯 Workflow Passo-a-Passo

### Antes (Manual)

```bash
# Repetir para CADA repo:
cd ~/AragonOSX
node scripts/gitissuer.js add --file ISSUE_UPDATES.md
node scripts/gitissuer.js deploy --batch --confirm
# ... esperar resposta
# ... fazer manualmente para 3 repos
# ⏱️ Tempo total: 30-45 minutos
```

### Depois (Automático)

```bash
# Setup (uma vez):
sudo /opt/GitIssue-Manager/systemd/install.sh
sudo nano /opt/GitIssue-Manager/config/repos.config.json
sudo systemctl enable gitissuer.timer

# Tudo depois automático:
# 09:00 AM todos os dias → GitIssuer executa em todos os repos
# Logs disponíveis: journalctl -u gitissuer.service -f

# Você pode acompanhar:
systemctl status gitissuer.timer
systemctl list-timers gitissuer.timer
journalctl -u gitissuer.service -n 20
```

**Ganho**: ⏱️ De 30-45 min → 0 min (automático!) + 5 min review

---

## 📊 Cronograma de Implementação

### Fase 1: GitIssuer Global (APPROVAL_CHECKLIST.md)
- [ ] Refatorar gitissuer.js em módulos (cli, file, github, workflow)
- [ ] Criar alias global: `gitissuer`
- [ ] Implementar 4 etapas: add/prepare/deploy/e2e
- [ ] **Tempo**: ~4-6 horas

### Fase 2: Systemd Automation (SYSTEMD_INTEGRATION.md + SYSTEMD_IMPLEMENTATION.md)
- [ ] Criar gitissuer.service + gitissuer.timer
- [ ] Criar daemon scripts (gitissuer-daemon.sh)
- [ ] Configurar repos.config.json
- [ ] Criar install.sh
- [ ] **Tempo**: ~2-3 horas

### Fase 3: Testing & Documentation
- [ ] Teste manual de cada etapa
- [ ] Teste agendado (timer)
- [ ] Teste file watcher (opcional)
- [ ] Documentação SYSTEMD_GUIDE.md
- [ ] **Tempo**: ~1-2 horas

**Total Estimado**: 7-11 horas (distribuído em 2-3 dias)

---

## ✅ Checklist de Aprovação

Antes de começar a implementação:

### Fase 1: GitIssuer Global
- [ ] Confirma refatoração em módulos?
- [ ] Quer as 4 etapas completas (add/prepare/deploy/e2e)?
- [ ] Quer alias global `gitissuer`?
- [ ] Quer suporte para múltiplos repos?

### Fase 2: Systemd Automation
- [ ] Confirma agendamento diário (09:00)?
- [ ] Quer file watcher em tempo real (opcional)?
- [ ] Quer notificações via email/Slack?
- [ ] Quer logging centralizado (journalctl)?

### Fase 3: Configuração
- [ ] Caminhos corretos dos repos?
- [ ] Usuário `gitissuer` em /var/lib/gitissuer?
- [ ] Permissões corretas?
- [ ] GitHub auth configurado?

---

## 🔐 Segurança & Permissões

```bash
# Usuário dedicado
sudo useradd -r -s /bin/bash gitissuer

# Permissões
sudo chmod 755 /opt/GitIssue-Manager/daemon/*.sh
sudo chmod 644 /etc/systemd/system/gitissuer.*
sudo chown gitissuer:gitissuer /var/log/gitissuer
sudo chown gitissuer:gitissuer /var/lib/gitissuer

# GitHub auth (no contexto do usuário)
sudo -u gitissuer gh auth login
```

---

## 📊 Monitoramento

### Ver agendamento
```bash
systemctl list-timers gitissuer.timer
# NEXT                        LEFT UNIT
# Thu 2025-01-23 09:00:00 BRST 14h gitissuer.timer
```

### Ver status
```bash
systemctl status gitissuer.service
systemctl status gitissuer.timer
```

### Ver logs em tempo real
```bash
journalctl -u gitissuer.service -f
journalctl -u gitissuer.service -n 100
journalctl -u gitissuer.service --since "2 hours ago"
```

### Executar manualmente
```bash
sudo systemctl start gitissuer.service
sudo systemctl start gitissuer.service --wait  # espera conclusão
```

---

## 🎯 Resultado Final

Após implementado:

```
✅ GitIssuer disponível globalmente: gitissuer help
✅ Executa workflow completo em 4 etapas
✅ Salva dados localmente em ./docs/plans/
✅ Automático todos os dias às 09:00
✅ Monitora mudanças em tempo real (opcional)
✅ Logs estruturados via journalctl
✅ Sem intervenção manual
✅ Escalável para novos repos
```

---

## 🚀 Próximos Passos

1. **Confirmar**: Quer implementar a arquitetura completa (Fase 1+2)?
2. **Customizar**: Qual horário agendado? (padrão: 09:00)
3. **Notificações**: Quer email/Slack? (padrão: apenas logs)
4. **Começar**: Fase 1 (GitIssuer Global) ou Fase 2 (Systemd)?

---

**Documentos de referência criados:**
- ✅ `APPROVAL_CHECKLIST.md` - Checklist de aprovação
- ✅ `SYSTEMD_INTEGRATION.md` - Plano de integração systemd
- ✅ `SYSTEMD_IMPLEMENTATION.md` - Implementação pronta para deploy
- ✅ `COMPLETE_AUTOMATION_VISION.md` - Este documento (overview)

**Qual é a sua decisão?** ✅ SIM / 📝 AJUSTES / ❌ NÃO
