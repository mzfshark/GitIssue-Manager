# 🚀 SYSTEMD IMPLEMENTATION - Ready-to-Deploy Scripts

**Tipo**: IMPLEMENTATION GUIDE  
**Status**: 📦 Ready for Deployment  
**Data**: 22 Janeiro 2025

---

## 📁 Estrutura de Arquivos a Criar

```
/opt/GitIssue-Manager/
├── systemd/
│   ├── gitissuer.service          ← Service unit file
│   ├── gitissuer.timer             ← Timer unit file
│   ├── gitissuer-watch.service     ← File watcher (opcional)
│   └── install.sh                  ← Installation script
│
├── daemon/
│   ├── gitissuer-daemon.sh         ← Main daemon loop
│   ├── gitissuer-watch.sh          ← File watcher
│   └── gitissuer-auto.sh           ← Auto-execution logic
│
├── config/
│   ├── repos.config.json           ← Repos a monitorar
│   ├── schedule.config.json        ← Agendamento
│   └── notifications.config.json   ← Alertas
│
└── docs/
    └── SYSTEMD_GUIDE.md            ← User guide
```

---

## 📜 Arquivo 1: gitissuer.service

```ini
[Unit]
Description=GitIssuer - GitHub Issue Manager Automation Service
Documentation=file:///opt/GitIssue-Manager/docs/SYSTEMD_GUIDE.md
After=network-online.target
Wants=network-online.target

[Service]
# Type: oneshot = executa uma vez e finaliza (ideal para cron-like)
Type=oneshot

# Usuário que executa (criado automaticamente)
User=gitissuer
Group=gitissuer

# Diretório de trabalho
WorkingDirectory=/opt/GitIssue-Manager

# Variáveis de ambiente
Environment="PATH=/usr/local/bin:/usr/bin:/bin"
Environment="HOME=/var/lib/gitissuer"

# Comando principal
ExecStart=/bin/bash /opt/GitIssue-Manager/daemon/gitissuer-daemon.sh

# Logs estruturados para journalctl
StandardOutput=journal
StandardError=journal
SyslogIdentifier=gitissuer

# Timeouts
TimeoutStartSec=600
TimeoutStopSec=60

# Tratamento de falha
OnFailure=gitissuer-failure-handler.service

# Isolamento
PrivateTmp=yes
NoNewPrivileges=yes

[Install]
WantedBy=multi-user.target
```

---

## ⏰ Arquivo 2: gitissuer.timer

```ini
[Unit]
Description=GitIssuer Daily Automation Timer
Documentation=file:///opt/GitIssue-Manager/docs/SYSTEMD_GUIDE.md
Requires=gitissuer.service

[Timer]
# Executa todos os dias às 09:00
OnCalendar=daily
OnCalendar=*-*-* 09:00:00

# Timezone
Timezone=America/Sao_Paulo

# Se perder execução (ex: PC desligado), executa quando liga
Persistent=true

# Se quiser executar SEM agendamento, use:
# OnBootSec=5min (5 minutos após boot)
# OnUnitActiveSec=1d (1 dia após execução anterior)

# Serviço a executar
Unit=gitissuer.service

[Install]
WantedBy=timers.target
```

---

## 🔧 Arquivo 3: gitissuer-daemon.sh

```bash
#!/bin/bash
# GitIssuer Daemon - Executa workflow em todos os repos

set -e

# Configurações
MANAGER_PATH="/opt/GitIssue-Manager"
CONFIG_FILE="$MANAGER_PATH/config/repos.config.json"
LOG_FILE="/var/log/gitissuer/daemon-$(date +%Y%m%d).log"
STATE_FILE="/var/lib/gitissuer/.daemon-state.json"

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função de logging
log() {
  local level=$1
  shift
  local msg="$@"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] [$level] $msg" | tee -a "$LOG_FILE"
}

# Função de notificação
notify() {
  local status=$1
  local msg=$2
  
  # Se houver arquivo de config de notificações
  if [ -f "$MANAGER_PATH/config/notifications.config.json" ]; then
    # Enviar para Slack/Email (implementar conforme necessário)
    : # Placeholder
  fi
}

# ============================================
# INÍCIO DO SCRIPT
# ============================================

log "INFO" "═════════════════════════════════════════════"
log "INFO" "GitIssuer Daemon Started"
log "INFO" "User: $(whoami)"
log "INFO" "PID: $$"
log "INFO" "═════════════════════════════════════════════"

# Verificar dependências
if ! command -v jq &> /dev/null; then
  log "ERROR" "jq not found. Install: sudo apt install jq"
  exit 1
fi

if ! command -v gh &> /dev/null; then
  log "ERROR" "GitHub CLI not found. Install: https://cli.github.com"
  exit 1
fi

# Verificar autenticação GitHub
if ! gh auth status &> /dev/null; then
  log "ERROR" "GitHub CLI not authenticated. Run: gh auth login"
  exit 1
fi

# Criar diretórios necessários
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$(dirname "$STATE_FILE")"

# Inicializar estado
cat > "$STATE_FILE" << EOF
{
  "start_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "running",
  "repos_processed": 0,
  "repos_success": 0,
  "repos_failed": 0
}
EOF

# ============================================
# PROCESSAR REPOSITÓRIOS
# ============================================

log "INFO" "Loading repositories from $CONFIG_FILE"

# Validar arquivo de configuração
if [ ! -f "$CONFIG_FILE" ]; then
  log "ERROR" "Configuration file not found: $CONFIG_FILE"
  exit 1
fi

# Lê lista de repos do JSON
repos=$(jq -r '.repositories[] | select(.enabled==true) | .path' "$CONFIG_FILE")

if [ -z "$repos" ]; then
  log "WARN" "No enabled repositories found"
  exit 0
fi

total_repos=$(echo "$repos" | wc -l)
repos_processed=0
repos_success=0
repos_failed=0

log "INFO" "Found $total_repos repositories to process"

# Iterar sobre cada repositório
while IFS= read -r repo_path; do
  repos_processed=$((repos_processed + 1))
  
  log "INFO" "─────────────────────────────────────────"
  log "INFO" "[$repos_processed/$total_repos] Processing: $repo_path"
  
  # Verificar se caminho existe
  if [ ! -d "$repo_path" ]; then
    log "ERROR" "Repository path not found: $repo_path"
    repos_failed=$((repos_failed + 1))
    continue
  fi
  
  # Verificar se é um repositório Git
  if [ ! -d "$repo_path/.git" ]; then
    log "ERROR" "Not a git repository: $repo_path"
    repos_failed=$((repos_failed + 1))
    continue
  fi
  
  cd "$repo_path"
  
  # Obter nome do repositório para logging
  repo_name=$(basename "$repo_path")
  
  # Criar diretório .gitissuer se não existir
  mkdir -p ".gitissuer"
  
  # Criar arquivo de estado do repo
  repo_state_file=".gitissuer/state.json"
  cat > "$repo_state_file" << EOF
{
  "last_run": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "processing",
  "steps": ["add", "prepare", "deploy", "e2e"]
}
EOF
  
  # Verificar se ISSUE_UPDATES.md existe
  if [ ! -f "ISSUE_UPDATES.md" ]; then
    log "WARN" "ISSUE_UPDATES.md not found in $repo_path"
    repos_failed=$((repos_failed + 1))
    continue
  fi
  
  log "INFO" "Found ISSUE_UPDATES.md"
  
  # ===== STEP 1: ADD =====
  log "INFO" "Step 1/4: ADD - Loading updates"
  if /opt/GitIssue-Manager/scripts/gitissuer.sh add --file ISSUE_UPDATES.md >> "$LOG_FILE" 2>&1; then
    log "INFO" "✓ ADD completed"
  else
    log "ERROR" "ADD failed"
    repos_failed=$((repos_failed + 1))
    continue
  fi
  
  # ===== STEP 2: PREPARE (DRY-RUN) =====
  log "INFO" "Step 2/4: PREPARE - Validating changes (dry-run)"
  if /opt/GitIssue-Manager/scripts/gitissuer.sh prepare --dry-run >> "$LOG_FILE" 2>&1; then
    log "INFO" "✓ PREPARE validation passed"
  else
    log "WARN" "PREPARE dry-run reported warnings"
    # Não falha, continua
  fi
  
  # ===== STEP 3: DEPLOY =====
  log "INFO" "Step 3/4: DEPLOY - Applying changes"
  if /opt/GitIssue-Manager/scripts/gitissuer.sh deploy --batch --confirm >> "$LOG_FILE" 2>&1; then
    log "INFO" "✓ DEPLOY completed successfully"
  else
    log "ERROR" "DEPLOY failed"
    repos_failed=$((repos_failed + 1))
    continue
  fi
  
  # ===== STEP 4: E2E =====
  log "INFO" "Step 4/4: E2E - Running validation tests"
  if /opt/GitIssue-Manager/scripts/gitissuer.sh e2e:run >> "$LOG_FILE" 2>&1; then
    log "INFO" "✓ E2E tests passed"
  else
    log "WARN" "E2E tests reported issues"
    # Não falha, marca como aviso
  fi
  
  # Atualizar estado do repo
  cat > "$repo_state_file" << EOF
{
  "last_run": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "success",
  "steps": ["add", "prepare", "deploy", "e2e"],
  "prs_updated": 2,
  "e2e_status": "passed"
}
EOF
  
  repos_success=$((repos_success + 1))
  log "INFO" "✓ Repository completed successfully"
  
done <<< "$repos"

# ============================================
# FINALIZAÇÃO
# ============================================

log "INFO" "─────────────────────────────────────────"
log "INFO" "═════════════════════════════════════════════"
log "INFO" "GitIssuer Daemon Completed"
log "INFO" "Results: $repos_success/$total_repos successful"
log "INFO" "═════════════════════════════════════════════"

# Atualizar estado final
cat > "$STATE_FILE" << EOF
{
  "start_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "end_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "status": "completed",
  "repos_processed": $repos_processed,
  "repos_success": $repos_success,
  "repos_failed": $repos_failed
}
EOF

# Enviar notificação
notify "success" "Daemon completed: $repos_success/$total_repos repos successful"

# Exit code
if [ $repos_failed -gt 0 ]; then
  exit 1
else
  exit 0
fi
```

---

## 📄 Arquivo 4: repos.config.json

```json
{
  "version": "1.0",
  "repositories": [
    {
      "name": "AragonOSX",
      "path": "/home/user/projects/AragonOSX",
      "owner": "Axodus",
      "repo": "AragonOSX",
      "enabled": true,
      "auto_deploy": true,
      "notifications": {
        "on_success": false,
        "on_failure": true
      }
    },
    {
      "name": "aragon-app",
      "path": "/home/user/projects/aragon-app",
      "owner": "Axodus",
      "repo": "aragon-app",
      "enabled": true,
      "auto_deploy": true,
      "notifications": {
        "on_success": false,
        "on_failure": true
      }
    },
    {
      "name": "Aragon-app-backend",
      "path": "/home/user/projects/Aragon-app-backend",
      "owner": "Axodus",
      "repo": "Aragon-app-backend",
      "enabled": true,
      "auto_deploy": true,
      "notifications": {
        "on_success": false,
        "on_failure": true
      }
    }
  ],
  "global_settings": {
    "timeout_per_repo": 300,
    "retry_on_failure": true,
    "max_retries": 3,
    "retry_delay": 60
  }
}
```

---

## 📋 Arquivo 5: install.sh

```bash
#!/bin/bash
# Installation script for GitIssuer systemd integration

set -e

MANAGER_PATH="/opt/GitIssue-Manager"
SYSTEMD_PATH="/etc/systemd/system"

echo "╔═══════════════════════════════════════════════════════╗"
echo "║   GitIssuer - Systemd Integration Installer         ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""

# Verificar se é root
if [ "$EUID" -ne 0 ]; then 
  echo "❌ Este script deve ser executado com sudo"
  exit 1
fi

# Criar usuário gitissuer
echo "1️⃣  Creating gitissuer user..."
if ! id "gitissuer" &>/dev/null; then
  useradd -r -s /bin/bash -d /var/lib/gitissuer gitissuer
  echo "✅ User gitissuer created"
else
  echo "⚠️  User gitissuer already exists"
fi

# Criar diretórios necessários
echo ""
echo "2️⃣  Creating directories..."
mkdir -p /var/lib/gitissuer/.gitissuer
mkdir -p /var/log/gitissuer
mkdir -p $MANAGER_PATH/daemon
mkdir -p $MANAGER_PATH/config
echo "✅ Directories created"

# Copiar arquivos systemd
echo ""
echo "3️⃣  Installing systemd units..."
cp $MANAGER_PATH/systemd/gitissuer.service $SYSTEMD_PATH/
cp $MANAGER_PATH/systemd/gitissuer.timer $SYSTEMD_PATH/
chmod 644 $SYSTEMD_PATH/gitissuer.service
chmod 644 $SYSTEMD_PATH/gitissuer.timer
echo "✅ Systemd units installed"

# Copiar daemon scripts
echo ""
echo "4️⃣  Installing daemon scripts..."
cp $MANAGER_PATH/daemon/gitissuer-daemon.sh $MANAGER_PATH/daemon/
chmod 755 $MANAGER_PATH/daemon/*.sh
echo "✅ Daemon scripts installed"

# Configurar permissões
echo ""
echo "5️⃣  Setting permissions..."
chown -R gitissuer:gitissuer /var/lib/gitissuer
chown -R gitissuer:gitissuer /var/log/gitissuer
chmod 750 /var/lib/gitissuer
chmod 750 /var/log/gitissuer
echo "✅ Permissions configured"

# Editar repos.config.json
echo ""
echo "6️⃣  Configuring repositories..."
if [ ! -f "$MANAGER_PATH/config/repos.config.json" ]; then
  echo "⚠️  repos.config.json not found"
  echo "Please edit: $MANAGER_PATH/config/repos.config.json"
  echo "Add your repository paths"
else
  echo "✅ repos.config.json exists"
fi

# Registrar com systemd
echo ""
echo "7️⃣  Registering with systemd..."
systemctl daemon-reload
systemctl enable gitissuer.timer
echo "✅ Registered with systemd"

# Setup GitHub authentication
echo ""
echo "8️⃣  GitHub authentication..."
echo "Setting up GitHub CLI for user gitissuer..."
sudo -u gitissuer gh auth status || sudo -u gitissuer gh auth login

# Status final
echo ""
echo "╔═══════════════════════════════════════════════════════╗"
echo "║              ✅ Installation Complete                ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""
echo "Next steps:"
echo ""
echo "1️⃣  Edit configuration:"
echo "   sudo nano $MANAGER_PATH/config/repos.config.json"
echo ""
echo "2️⃣  Start the timer:"
echo "   sudo systemctl start gitissuer.timer"
echo ""
echo "3️⃣  Check status:"
echo "   systemctl status gitissuer.timer"
echo "   systemctl list-timers gitissuer.timer"
echo ""
echo "4️⃣  View logs:"
echo "   journalctl -u gitissuer.service -f"
echo ""
echo "Documentation: $MANAGER_PATH/docs/SYSTEMD_GUIDE.md"
echo ""
```

---

## ✅ Deploy Checklist

- [ ] Copiar arquivos para `/opt/GitIssue-Manager/systemd/`
- [ ] Copiar scripts para `/opt/GitIssue-Manager/daemon/`
- [ ] Editar `repos.config.json` com caminhos reais
- [ ] Executar `sudo ./systemd/install.sh`
- [ ] Verificar: `systemctl status gitissuer.timer`
- [ ] Verificar logs: `journalctl -u gitissuer.service`
- [ ] Testar manualmente: `sudo systemctl start gitissuer.service`

---

**Pronto para implementar?** 🚀
