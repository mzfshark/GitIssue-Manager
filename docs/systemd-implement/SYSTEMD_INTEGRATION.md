# 🤖 SYSTEMD INTEGRATION - GitIssuer Automation

**Tipo**: INFRASTRUCTURE  
**Status**: 📋 Planning Phase  
**Data**: 22 Janeiro 2025  
**Prioridade**: 🟡 Medium  
**Estimativa**: 2-3 horas  

---

## 📊 Executive Summary

Integrar **GitIssuer com systemd** para automação contínua que:
- ✅ Monitora mudanças em cada repositório
- ✅ Executa GitIssuer automaticamente (daily/weekly/on-change)
- ✅ Cria e edita arquivos necessários (docs/plans/, logs, state)
- ✅ Funciona como daemon sem intervenção manual
- ✅ Registra todas as operações (journalctl)

---

## 🎯 Objetivo

Após GitIssuer estar pronto, criar serviços systemd que automatizam o workflow completo:

```
┌─ SYSTEMD SERVICE ───────────────────────────┐
│                                             │
│  gitissuer.service (main daemon)           │
│  ├── Monitora /repos (OSX, app, backend)   │
│  ├── Detecta mudanças em ISSUE_UPDATES.md │
│  ├── Executa: add → prepare → deploy      │
│  ├── Cria ./docs/plans/*_UPDATE.md        │
│  ├── Registra logs via journalctl         │
│  └── Email/Slack notifications (opcional) │
│                                             │
│  gitissuer.timer (scheduler)               │
│  ├── Executa daily às 9:00                │
│  ├── OU on-demand via: systemctl start    │
│  └── OU webhooks GitHub (opcional)        │
│                                             │
│  gitissuer-watch.service (file monitoring)│
│  └── Detecciona ISSUE_UPDATES.md criado   │
│                                             │
└─────────────────────────────────────────────┘
```

---

## 🔧 Componentes Systemd

### 1. **gitissuer.service**
Serviço principal que executa GitIssuer

```ini
[Unit]
Description=GitIssuer - GitHub Issue Manager Automation
Documentation=file:///opt/GitIssue-Manager/docs/SYSTEMD_GUIDE.md
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=gitissuer
Group=gitissuer
WorkingDirectory=/opt/GitIssue-Manager

# Executa o workflow completo
ExecStart=/opt/GitIssue-Manager/scripts/gitissuer.sh daemon --auto

# Logs estruturados
StandardOutput=journal
StandardError=journal
SyslogIdentifier=gitissuer

# Timeout
TimeoutStartSec=300
TimeoutStopSec=60

[Install]
WantedBy=multi-user.target
```

### 2. **gitissuer.timer**
Agenda execução (cron-like)

```ini
[Unit]
Description=GitIssuer Daily Automation Timer
Documentation=file:///opt/GitIssue-Manager/docs/SYSTEMD_GUIDE.md

[Timer]
# Executa todos os dias às 9:00 AM
OnCalendar=daily
OnCalendar=*-*-* 09:00:00

# Timezone
Timezone=America/Sao_Paulo

# Se perder execução, executa assim que possível
Persistent=true

# Nome do serviço a executar
Unit=gitissuer.service

[Install]
WantedBy=timers.target
```

### 3. **gitissuer-watch.service** (Opcional)
Monitora mudanças em tempo real

```ini
[Unit]
Description=GitIssuer File Watch - Real-time Monitoring
Documentation=file:///opt/GitIssue-Manager/docs/SYSTEMD_GUIDE.md
PartOf=gitissuer.service

[Service]
Type=simple
User=gitissuer
ExecStart=/opt/GitIssue-Manager/scripts/gitissuer-watch.sh

# Reinicia se falhar
Restart=always
RestartSec=10

StandardOutput=journal
StandardError=journal
SyslogIdentifier=gitissuer-watch

[Install]
WantedBy=multi-user.target
```

---

## 📁 Estrutura de Arquivos Systemd

```
/opt/GitIssue-Manager/
├── systemd/
│   ├── gitissuer.service          ← Serviço principal
│   ├── gitissuer.timer             ← Scheduler
│   ├── gitissuer-watch.service     ← File monitoring (opcional)
│   └── install.sh                  ← Script de instalação
│
├── scripts/
│   ├── gitissuer-daemon.sh         ← Modo daemon
│   ├── gitissuer-watch.sh          ← File watcher
│   └── gitissuer-auto.sh           ← Auto-execução
│
├── config/
│   ├── repos.config.json           ← Lista de repos a monitorar
│   ├── schedule.config.json        ← Agendamento customizado
│   └── notifications.config.json   ← Email/Slack/Webhooks
│
└── logs/
    └── gitissuer-daemon.log        ← Logs persistentes
```

---

## 🔄 Fluxo de Automação

### Cenário 1: **Agendado (Daily)**
```
09:00 AM ────→ systemd.timer dispara
                ↓
        gitissuer.service inicia
                ↓
        Itera sobre repos (OSX, app, backend)
                ↓
        Para cada repo com ISSUE_UPDATES.md:
          • gitissuer add --auto
          • gitissuer prepare --dry-run
          • gitissuer deploy --batch --confirm
          • gitissuer e2e:run
                ↓
        Gera relatório
                ↓
        Notifica via email/Slack (opcional)
                ↓
        Salva logs em journalctl
```

### Cenário 2: **On-Change (File Watch)**
```
User cria/modifica ISSUE_UPDATES.md
        ↓
gitissuer-watch.service detecta (inotify)
        ↓
systemctl start gitissuer.service
        ↓
[mesmo fluxo acima]
```

### Cenário 3: **Manual (Sob Demanda)**
```bash
systemctl start gitissuer.service
# OU
systemctl start gitissuer.service --wait
# OU
gitissuer daemon --auto
```

---

## 📋 Implementação em Etapas

### STAGE-001: Criar arquivos de configuração
- [ ] `repos.config.json` - Lista de repos (OSX, app, backend)
- [ ] `schedule.config.json` - Agendamento customizado
- [ ] `notifications.config.json` - Email/Slack/Webhooks

### STAGE-002: Implementar modo daemon
- [ ] `gitissuer-daemon.sh` - Script que itera repos
- [ ] `gitissuer-auto.sh` - Auto-execução com retry logic
- [ ] Tratamento de erros e logging

### STAGE-003: Implementar file watcher
- [ ] `gitissuer-watch.sh` - Monitora ISSUE_UPDATES.md com inotify
- [ ] Detecta mudanças por repo
- [ ] Dispara gitissuer.service automaticamente

### STAGE-004: Criar arquivos systemd
- [ ] `gitissuer.service` - Serviço principal
- [ ] `gitissuer.timer` - Timer agendado
- [ ] `gitissuer-watch.service` - File monitoring

### STAGE-005: Instalação & Setup
- [ ] `install.sh` - Script que instala tudo
- [ ] Criar usuário/grupo `gitissuer`
- [ ] Configurar permissões
- [ ] Registrar com systemctl

### STAGE-006: Logging & Monitoramento
- [ ] Estruturar logs via syslog
- [ ] Criar dashboard de status
- [ ] Setup de alertas

### STAGE-007: Documentação
- [ ] SYSTEMD_GUIDE.md
- [ ] TROUBLESHOOTING.md
- [ ] CONFIGURATION.md

---

## 💾 Configuração (JSON)

### repos.config.json
```json
{
  "repositories": [
    {
      "name": "AragonOSX",
      "path": "/home/user/AragonOSX",
      "owner": "Axodus",
      "repo": "AragonOSX",
      "enabled": true,
      "auto_deploy": true
    },
    {
      "name": "aragon-app",
      "path": "/home/user/aragon-app",
      "owner": "Axodus",
      "repo": "aragon-app",
      "enabled": true,
      "auto_deploy": true
    },
    {
      "name": "Aragon-app-backend",
      "path": "/home/user/Aragon-app-backend",
      "owner": "Axodus",
      "repo": "Aragon-app-backend",
      "enabled": true,
      "auto_deploy": true
    }
  ]
}
```

### schedule.config.json
```json
{
  "schedules": [
    {
      "name": "daily-morning",
      "time": "09:00",
      "day": "*",
      "enabled": true
    },
    {
      "name": "daily-evening",
      "time": "18:00",
      "day": "*",
      "enabled": false
    }
  ],
  "timezone": "America/Sao_Paulo"
}
```

### notifications.config.json
```json
{
  "email": {
    "enabled": false,
    "recipient": "team@aragon.io",
    "on_success": false,
    "on_failure": true
  },
  "slack": {
    "enabled": false,
    "webhook": "https://hooks.slack.com/...",
    "channel": "#gitissuer",
    "on_success": true,
    "on_failure": true
  }
}
```

---

## 🛠️ Scripts de Suporte

### gitissuer-daemon.sh
```bash
#!/bin/bash
# Modo daemon - itera sobre repos e executa

set -e

REPOS_CONFIG="/opt/GitIssue-Manager/config/repos.config.json"
LOG_FILE="/var/log/gitissuer-daemon.log"

echo "[$(date)] GitIssuer Daemon Starting" >> $LOG_FILE

# Lê repos do JSON
repos=$(jq -r '.repositories[] | select(.enabled==true) | .path' $REPOS_CONFIG)

for repo_path in $repos; do
  echo "[$(date)] Processing: $repo_path" >> $LOG_FILE
  
  cd "$repo_path"
  
  # Verifica se ISSUE_UPDATES.md existe
  if [ -f "ISSUE_UPDATES.md" ]; then
    echo "[$(date)] Found ISSUE_UPDATES.md" >> $LOG_FILE
    
    # Executa workflow
    /opt/GitIssue-Manager/scripts/gitissuer.sh add --file ISSUE_UPDATES.md
    /opt/GitIssue-Manager/scripts/gitissuer.sh prepare --dry-run
    /opt/GitIssue-Manager/scripts/gitissuer.sh deploy --batch --confirm
    /opt/GitIssue-Manager/scripts/gitissuer.sh e2e:run
    
    echo "[$(date)] Completed: $repo_path" >> $LOG_FILE
  fi
done

echo "[$(date)] GitIssuer Daemon Finished" >> $LOG_FILE
```

### gitissuer-watch.sh
```bash
#!/bin/bash
# File watcher - monitora ISSUE_UPDATES.md em cada repo

REPOS_CONFIG="/opt/GitIssue-Manager/config/repos.config.json"

repos=$(jq -r '.repositories[] | select(.enabled==true) | .path' $REPOS_CONFIG)

# Usa inotify-tools (apt install inotify-tools)
for repo_path in $repos; do
  echo "Watching: $repo_path/ISSUE_UPDATES.md"
  
  inotifywait -m -e modify,create "$repo_path/ISSUE_UPDATES.md" \
    --format '%w %e' |
  while read path event; do
    echo "Detected: $event on $path"
    systemctl start gitissuer.service
  done &
done

wait
```

---

## 📊 Criação de Arquivos Locais

GitIssuer criará automaticamente:

### Em cada repositório:

```
AragonOSX/
├── docs/plans/
│   └── AragonOSX_20250122_UPDATE.md      ← Criado por gitissuer add
├── .gitissuer/
│   ├── state.json                        ← Estado persistente
│   ├── last-run.json                     ← Timestamp última execução
│   ├── logs/
│   │   ├── 20250122_daemon.log          ← Logs por data
│   │   └── 20250122_deploy.log
│   └── backups/
│       └── AragonOSX_20250121_BACKUP.md ← Backup antes de deploy

aragon-app/
├── docs/plans/
│   └── aragon-app_20250122_UPDATE.md
├── .gitissuer/
│   └── ... (similar)

Aragon-app-backend/
├── docs/plans/
│   └── backend_20250122_UPDATE.md
├── .gitissuer/
│   └── ... (similar)
```

---

## 🔐 Permissões & Segurança

```bash
# Criar usuário gitissuer
sudo useradd -r -s /bin/bash gitissuer

# Permissões
sudo chmod 755 /opt/GitIssue-Manager/scripts/*.sh
sudo chmod 644 /opt/GitIssue-Manager/systemd/*.service
sudo chmod 644 /opt/GitIssue-Manager/systemd/*.timer

# Logs
sudo mkdir -p /var/log/gitissuer
sudo chown gitissuer:gitissuer /var/log/gitissuer
sudo chmod 750 /var/log/gitissuer

# GitHub auth para usuário gitissuer
sudo -u gitissuer gh auth login
```

---

## 📊 Monitoramento & Logs

### Ver logs em tempo real
```bash
journalctl -u gitissuer.service -f
journalctl -u gitissuer-watch.service -f
```

### Ver status
```bash
systemctl status gitissuer.service
systemctl status gitissuer.timer
systemctl list-timers gitissuer.timer
```

### Ver próxima execução agendada
```bash
systemctl list-timers gitissuer.timer
# OUTPUT:
# NEXT                        LEFT        LAST                        PASSED UNIT
# Thu 2025-01-23 09:00:00 BRST 14h left   Thu 2025-01-22 09:00:50 BRST 1h 30min ago gitissuer.timer
```

---

## 🚀 Instalação (Quick Start)

```bash
# 1. Clonar/copiar para /opt
sudo git clone https://github.com/mzfshark/GitIssue-Manager /opt/GitIssue-Manager
cd /opt/GitIssue-Manager

# 2. Executar installer
sudo ./systemd/install.sh

# 3. Editar configuração
sudo vi config/repos.config.json
sudo vi config/schedule.config.json

# 4. Registrar com systemd
sudo systemctl daemon-reload
sudo systemctl enable gitissuer.timer
sudo systemctl start gitissuer.timer

# 5. Verificar
systemctl status gitissuer.timer
journalctl -u gitissuer.service -n 20
```

---

## 🎯 Resultado Final Esperado

Após instalado:

```bash
# Logs de daemon automático
$ journalctl -u gitissuer.service -n 10
Jan 22 09:00:01 server gitissuer[1234]: [2025-01-22 09:00:01] Processing: /home/user/AragonOSX
Jan 22 09:00:05 server gitissuer[1234]: [2025-01-22 09:00:05] ✅ Updated: 2 PRs
Jan 22 09:00:08 server gitissuer[1234]: [2025-01-22 09:00:08] E2E Tests: PASSED
Jan 22 09:00:09 server gitissuer[1234]: [2025-01-22 09:00:09] Processing: /home/user/aragon-app
...

# Status de timer
$ systemctl list-timers gitissuer.timer
NEXT                        LEFT UNIT
Thu 2025-01-23 09:00:00 BRST 14h gitissuer.timer

# Status de serviço
$ systemctl status gitissuer.service
● gitissuer.service - GitIssuer - GitHub Issue Manager Automation
   Loaded: loaded (/etc/systemd/system/gitissuer.service; static)
   Active: inactive (dead)
   Last Trigger: Thu 2025-01-22 09:00:01 BRST; 1h 30min ago
```

---

## ✅ Checklist de Implementação

- [ ] STAGE-001: Configurações (repos, schedule, notifications)
- [ ] STAGE-002: Mode daemon + auto-execução
- [ ] STAGE-003: File watcher (inotify)
- [ ] STAGE-004: Arquivos systemd (.service, .timer)
- [ ] STAGE-005: Install script + permissões
- [ ] STAGE-006: Logging & alertas
- [ ] STAGE-007: Documentação completa
- [ ] Teste ponta-a-ponta (manual + agendado)
- [ ] Integração com GitHub (webhooks opcional)

---

## 📝 Próximos Passos

1. **Confirmar**: Quer implementar systemd integration?
2. **Configuração**: Quais repos + horários?
3. **Notificações**: Email/Slack/Webhooks?
4. **Logging**: Centralizado ou local?

---

**Ready to implement systemd automation?** 🚀
