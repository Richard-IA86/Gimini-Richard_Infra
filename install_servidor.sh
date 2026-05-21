#!/usr/bin/env bash
# install_servidor.sh — Instala crew_ecosauron (Sauron) en Hetzner
# Ejecutar como root en el servidor:
#   bash install_servidor.sh
#
# Pasos:
#   1. Dependencias del sistema
#   2. Verificar Ollama
#   3. Deploy keys SSH (2 keys — una por repo privado)
#   4. Clonar repos vía SSH
#   5. Venv + pip install + .env.local
#   6. SSH self-auth (health check local)
#   7. Cron
set -euo pipefail

BASE="/opt/pose"
CREW_DIR="$BASE/crew_ecosauron"
ECOSAURON_DIR="$BASE/auditoria_ecosauron"
VENV="$CREW_DIR/venv"
KEY_CREW="/root/.ssh/sauron_github_deploy"
KEY_AUDITORIA="/root/.ssh/sauron_auditoria_deploy"
SSH_CONF="/root/.ssh/config"

[[ $EUID -ne 0 ]] && { echo "ERROR: ejecutar como root." >&2; exit 1; }

echo ""
echo "════════════════════════════════════════════"
echo " Sauron — Instalación en Servidor Hetzner"
echo "════════════════════════════════════════════"
echo ""

echo "[1/7] Dependencias del sistema..."
apt-get update -q
# Ubuntu Noble 24.04: Python 3.12 con venv builtin.
# NO instalar python3.11-venv (no existe en Noble).
apt-get install -y -q git python3 python3-pip curl
echo "      $(python3 --version) OK"

echo "[2/7] Verificando Ollama..."
if ! curl -sf http://127.0.0.1:11434/api/tags > /dev/null; then
    echo "  Ollama no corre. Instalar con:"
    echo "    curl -fsSL https://ollama.com/install.sh | sh"
    echo "    ollama pull qwen2.5:7b && systemctl enable ollama"
    read -r -p "  Continuar sin Ollama? (s/N): " RESP
    [[ "$RESP" =~ ^[sS]$ ]] || { echo "Cancelado."; exit 0; }
else
    echo "      Ollama OK"
fi

echo "[3/7] Deploy keys SSH..."
mkdir -p /root/.ssh && chmod 700 /root/.ssh

[[ ! -f "$KEY_CREW" ]] && {
    ssh-keygen -t ed25519 -C "sauron-crew-hetzner" -f "$KEY_CREW" -N ""
    chmod 600 "$KEY_CREW"
    echo "  + key crew generada"
} || echo "  ~ key crew ya existe"

[[ ! -f "$KEY_AUDITORIA" ]] && {
    ssh-keygen -t ed25519 -C "sauron-auditoria-hetzner" \
        -f "$KEY_AUDITORIA" -N ""
    chmod 600 "$KEY_AUDITORIA"
    echo "  + key auditoria generada"
} || echo "  ~ key auditoria ya existe"

if ! grep -q "github-crew" "$SSH_CONF" 2>/dev/null; then
    {
        echo ""
        echo "Host github-crew"
        echo "    HostName github.com"
        echo "    User git"
        echo "    IdentityFile $KEY_CREW"
        echo "    StrictHostKeyChecking no"
        echo ""
        echo "Host github-auditoria"
        echo "    HostName github.com"
        echo "    User git"
        echo "    IdentityFile $KEY_AUDITORIA"
        echo "    StrictHostKeyChecking no"
    } >> "$SSH_CONF"
    chmod 600 "$SSH_CONF"
    echo "  + SSH config actualizado"
fi

echo ""
echo "  ACCIÓN REQUERIDA — Agregar deploy keys en GitHub:"
echo "  1. crew: https://github.com/Richard-IA86/crew_ecosauron/settings/keys"
echo "     $(cat ${KEY_CREW}.pub)"
echo ""
echo "  2. auditoria: https://github.com/Richard-IA86/Auditoria_EcoSauron/settings/keys"
echo "     $(cat ${KEY_AUDITORIA}.pub)"
echo ""
read -r -p "  Agregaste ambas deploy keys? (s/N): " KEYS_OK
[[ "$KEYS_OK" =~ ^[sS]$ ]] && {
    ssh -T git@github-crew 2>&1 | grep -q "authenticated" \
        && echo "  crew OK" || echo "  WARN: crew — verificar key"
    ssh -T git@github-auditoria 2>&1 | grep -q "authenticated" \
        && echo "  auditoria OK" || echo "  WARN: auditoria — verificar key"
}

echo "[4/7] Repositorios..."
mkdir -p "$BASE"
for DIR in "$CREW_DIR" "$ECOSAURON_DIR"; do
    [[ -d "$DIR" && ! -d "$DIR/.git" ]] && rm -rf "$DIR"
done

[[ -d "$CREW_DIR/.git" ]] && {
    git -C "$CREW_DIR" pull --quiet
    echo "  ~ crew_ecosauron actualizado"
} || {
    git clone "git@github-crew:Richard-IA86/crew_ecosauron.git" "$CREW_DIR"
    echo "  + crew_ecosauron clonado"
}

[[ -d "$ECOSAURON_DIR/.git" ]] && {
    git -C "$ECOSAURON_DIR" pull --quiet
    echo "  ~ auditoria_ecosauron actualizado"
} || {
    git clone "git@github-auditoria:Richard-IA86/Auditoria_EcoSauron.git" \
        "$ECOSAURON_DIR"
    echo "  + auditoria_ecosauron clonado"
}

mkdir -p "$CREW_DIR/logs" "$ECOSAURON_DIR/logs"

echo "[5/7] Entorno virtual..."
[[ ! -d "$VENV" ]] && python3 -m venv "$VENV" && echo "  + venv creado"
source "$VENV/bin/activate"
pip install --quiet --upgrade pip setuptools wheel
# pip install -e . falla en Ubuntu Noble por conflicto de setuptools
# en build isolation — instalar deps directamente + .pth file.
pip install --quiet \
    'crewai==1.14.3' \
    'python-dotenv>=1.0.1' \
    'requests>=2.31.0' \
    'paramiko>=3.4.0' \
    'psycopg2-binary>=2.9.9'
PY_VER=$(python3 -c \
    "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
printf '%s\n%s\n' "$CREW_DIR" "$CREW_DIR/src" \
    > "$VENV/lib/python${PY_VER}/site-packages/crew_ecosauron.pth"
echo "      pip install OK"

ENV_FILE="$CREW_DIR/.env.local"
if [[ -f "$ENV_FILE" ]]; then
    echo "  ~ .env.local ya existe"
else
    python3 -c "
lines = [
    '# crew_ecosauron — servidor Hetzner',
    '# NO commitear (en .gitignore)',
    '',
    'OTEL_SDK_DISABLED=true',
    'CREWAI_DISABLE_TELEMETRY=true',
    '',
    'OLLAMA_BASE_URL=http://127.0.0.1:11434',
    'OLLAMA_MODEL=qwen2.5:7b',
    '',
    '# SSH self-check (servidor chequea su propio SSH)',
    'HETZNER_HOST=127.0.0.1',
    'HETZNER_USER=root',
    'HETZNER_SSH_KEY=/root/.ssh/id_ed25519',
    '',
    'PG_HOST=127.0.0.1',
    'PG_PORT=5432',
    'PG_DB_DEV=dw_grupopose_b52_dev',
    'PG_DB_PROD=dw_grupopose_b52_prod',
    'PG_USER=pose_admin',
    'PG_PASSWORD=COMPLETAR',
    '',
    'API_ENDPOINT=https://api.gestionpose.com.ar/api/v1/b53/dashboard-data',
    '',
    'REPOS_BASE=/opt/pose/auditoria_ecosauron/workspaces',
    'REPO_ECOSAURON=/opt/pose/auditoria_ecosauron',
    'REPO_GESTION_COMP=/opt/pose/auditoria_ecosauron/workspaces/gestion_comp',
    'REPO_PLANIF=/opt/pose/auditoria_ecosauron/workspaces/planif_pose',
    'REPO_BD=/opt/pose/auditoria_ecosauron/workspaces/bd_pose_b52',
    'REPO_RICHARD=/opt/pose/auditoria_ecosauron/workspaces/richard_ia86_dev',
    'REPO_ANALYTICS=/opt/pose/auditoria_ecosauron/workspaces/data_analytics',
    'INFRA_REPO=/opt/pose/Gimini-Richard_Infra',
    'LOGS_DIR=/opt/pose/auditoria_ecosauron/logs',
]
with open('$ENV_FILE', 'w') as f:
    f.write('\n'.join(lines) + '\n')
import os; os.chmod('$ENV_FILE', 0o600)
"
    echo "  + .env.local creado — completar PG_PASSWORD"
fi

echo "[6/7] SSH self-auth..."
[[ ! -f /root/.ssh/id_ed25519 ]] && {
    ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N "" -q
    echo "  + id_ed25519 generada"
}
PUBKEY=$(cat /root/.ssh/id_ed25519.pub)
grep -qF "$PUBKEY" /root/.ssh/authorized_keys 2>/dev/null || {
    echo "$PUBKEY" >> /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    echo "  + key en authorized_keys"
}
ssh-keyscan -H 127.0.0.1 >> /root/.ssh/known_hosts 2>/dev/null
echo "  + known_hosts actualizado"

echo "[7/7] Cron..."
CRON_SCRIPT="$CREW_DIR/cron_briefing_servidor.sh"
chmod +x "$CRON_SCRIPT"
CRON_LINE="50 9 * * 1-5 $CRON_SCRIPT >> $CREW_DIR/logs/cron.log 2>&1"
crontab -l 2>/dev/null | grep -qF "cron_briefing_servidor.sh" && {
    echo "  ~ cron ya registrado"
} || {
    (crontab -l 2>/dev/null || true; echo "$CRON_LINE") | crontab -
    echo "  + cron: 09:50 UTC (06:50 ART) lun-vie"
}

echo ""
echo "════════════════════════════════════════════"
echo " INSTALACIÓN COMPLETA"
echo "════════════════════════════════════════════"
echo " Repos : $CREW_DIR"
echo "         $ECOSAURON_DIR"
echo " Venv  : $VENV"
echo " Cron  : 09:50 UTC lun-vie"
grep -q "COMPLETAR" "$ENV_FILE" 2>/dev/null && \
    echo " ⚠  PENDIENTE: PG_PASSWORD en $ENV_FILE"
echo ""
echo " Health check:"
echo "   cd $CREW_DIR && source venv/bin/activate"
echo "   PYTHONPATH=src python -m crew_ecosauron.main"
echo ""
