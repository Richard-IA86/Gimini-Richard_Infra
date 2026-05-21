#!/usr/bin/env bash
# install_servidor.sh — Instala crew_ecosauron (Sauron) en Hetzner
# Ejecutar como root en el servidor:
#   bash install_servidor.sh
#
# Qué hace:
#   1. Instala dependencias del sistema (git, python3.11, venv)
#   2. Verifica que Ollama esté corriendo (no lo instala — requiere
#      intervención manual por recursos de hardware)
#   3. Clona crew_ecosauron y auditoria_ecosauron en /opt/pose/
#   4. Crea venv + pip install
#   5. Genera .env.local con valores del servidor
#   6. Genera deploy key SSH para git push a GitHub
#   7. Instala el cron (09:50 UTC = 06:50 ART)
#   8. Health check final
set -euo pipefail

# ── Configuración ─────────────────────────────────────────────────
BASE="/opt/pose"
CREW_DIR="$BASE/crew_ecosauron"
ECOSAURON_DIR="$BASE/auditoria_ecosauron"
VENV="$CREW_DIR/venv"
DEPLOY_KEY="/root/.ssh/sauron_github_deploy"
GITHUB_CREW="https://github.com/Richard-IA86/crew_ecosauron.git"
GITHUB_AUDITORIA="https://github.com/Richard-IA86/Auditoria_EcoSauron.git"

# ── Validaciones ──────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && {
    echo "ERROR: ejecutar como root." >&2
    exit 1
}

echo ""
echo "════════════════════════════════════════════"
echo " Sauron — Instalación en Servidor Hetzner"
echo "════════════════════════════════════════════"
echo ""

# ── 1. Dependencias del sistema ───────────────────────────────────
echo "[1/7] Dependencias del sistema..."
apt-get update -q
apt-get install -y -q \
    git \
    python3.11 \
    python3.11-venv \
    python3-pip \
    curl

# Verificar versión de Python
PY=$(python3.11 --version 2>&1)
echo "      $PY OK"

# ── 2. Verificar Ollama ───────────────────────────────────────────
echo "[2/7] Verificando Ollama..."
if ! curl -sf http://127.0.0.1:11434/api/tags > /dev/null; then
    echo ""
    echo "  ⚠  Ollama no está corriendo en este servidor."
    echo "     El briefing usa LLM local (qwen2.5:7b)."
    echo "     Opciones:"
    echo "       A) Instalar Ollama (requiere ≥8 GB RAM):"
    echo "          curl -fsSL https://ollama.ai/install.sh | sh"
    echo "          ollama pull qwen2.5:7b"
    echo "          systemctl enable ollama"
    echo "       B) Usar una API externa en .env.local"
    echo ""
    read -r -p "     ¿Continuar sin Ollama? (s/N): " RESP
    [[ "$RESP" =~ ^[sS]$ ]] || {
        echo "     Instalación cancelada."; exit 0
    }
else
    echo "      Ollama OK → $(curl -sf \
        http://127.0.0.1:11434/api/tags | \
        python3 -c \
        'import sys,json; \
         m=[x["name"] for x in json.load(sys.stdin).get("models",[])]; \
         print(", ".join(m) or "(sin modelos)")')"
fi

# ── 3. Clonar repos ───────────────────────────────────────────────
echo "[3/7] Repositorios..."
mkdir -p "$BASE"

if [[ -d "$CREW_DIR/.git" ]]; then
    echo "  ~ crew_ecosauron ya existe — git pull"
    git -C "$CREW_DIR" pull --quiet
else
    git clone "$GITHUB_CREW" "$CREW_DIR"
    echo "  + crew_ecosauron clonado"
fi

if [[ -d "$ECOSAURON_DIR/.git" ]]; then
    echo "  ~ auditoria_ecosauron ya existe — git pull"
    git -C "$ECOSAURON_DIR" pull --quiet
else
    git clone "$GITHUB_AUDITORIA" "$ECOSAURON_DIR"
    echo "  + auditoria_ecosauron clonado"
fi

mkdir -p "$CREW_DIR/logs" "$ECOSAURON_DIR/logs"

# ── 4. Entorno virtual ────────────────────────────────────────────
echo "[4/7] Entorno virtual..."
if [[ ! -d "$VENV" ]]; then
    python3.11 -m venv "$VENV"
    echo "  + venv creado"
fi

source "$VENV/bin/activate"
pip install --quiet --upgrade pip
pip install --quiet -e "$CREW_DIR"
echo "      pip install OK"

# ── 5. .env.local ─────────────────────────────────────────────────
echo "[5/7] Configuración .env.local..."
ENV_FILE="$CREW_DIR/.env.local"

if [[ -f "$ENV_FILE" ]]; then
    echo "  ~ .env.local ya existe — no se sobreescribe"
    echo "    Editar manualmente: $ENV_FILE"
else
    cat > "$ENV_FILE" << 'EOF'
# crew_ecosauron — servidor Hetzner
# COMPLETAR: PG_PASSWORD antes de ejecutar

# ── Ollama (local al servidor) ────────────────────────────
OLLAMA_BASE_URL=http://127.0.0.1:11434
OLLAMA_MODEL=qwen2.5:7b

# ── SSH (no aplica: el servidor es el destino) ────────────
HETZNER_HOST=127.0.0.1
HETZNER_USER=root
HETZNER_SSH_KEY=/root/.ssh/id_ed25519

# ── PostgreSQL (nativo en este servidor) ─────────────────
PG_HOST=127.0.0.1
PG_PORT=5432
PG_DB=dw_grupopose_b52_prod
PG_USER=pose_app
PG_PASSWORD=COMPLETAR_AQUI

# ── Endpoint de producción ────────────────────────────────
API_URL=http://127.0.0.1:8000
EOF
    chmod 600 "$ENV_FILE"
    echo "  + .env.local creado"
    echo "  ⚠  PENDIENTE: completar PG_PASSWORD en $ENV_FILE"
fi

# ── 6. Deploy key para git push a GitHub ─────────────────────────
echo "[6/7] Deploy key SSH para GitHub..."
if [[ ! -f "$DEPLOY_KEY" ]]; then
    ssh-keygen -t ed25519 \
        -C "sauron-servidor-hetzner" \
        -f "$DEPLOY_KEY" \
        -N ""
    chmod 600 "$DEPLOY_KEY"
    chmod 644 "${DEPLOY_KEY}.pub"
    echo "  + deploy key generada: $DEPLOY_KEY"
else
    echo "  ~ deploy key ya existe"
fi

# Configurar git para usar la deploy key en los repos clonados
GIT_SSH_CMD="ssh -i $DEPLOY_KEY -o StrictHostKeyChecking=no"
git -C "$CREW_DIR" config core.sshCommand "$GIT_SSH_CMD"
git -C "$ECOSAURON_DIR" config core.sshCommand "$GIT_SSH_CMD"

# Reconfigurar remote a SSH si está en HTTPS
for DIR in "$CREW_DIR" "$ECOSAURON_DIR"; do
    REMOTE=$(git -C "$DIR" remote get-url origin)
    if [[ "$REMOTE" == https://github.com/Richard-IA86/crew* ]]; then
        git -C "$DIR" remote set-url origin \
            git@github.com:Richard-IA86/crew_ecosauron.git
    elif [[ "$REMOTE" == https://github.com/Richard-IA86/Auditoria* ]]; then
        git -C "$DIR" remote set-url origin \
            git@github.com:Richard-IA86/Auditoria_EcoSauron.git
    fi
done

echo ""
echo "  ════════════════════════════════════════"
echo "  ACCIÓN REQUERIDA — Agregar a GitHub:"
echo "  ════════════════════════════════════════"
echo "  1. Ir a:"
echo "     github.com/Richard-IA86/crew_ecosauron"
echo "     → Settings → Deploy keys → Add deploy key"
echo "  2. Nombre: sauron-servidor-hetzner"
echo "  3. Clave pública:"
echo ""
cat "${DEPLOY_KEY}.pub"
echo ""
echo "  4. Marcar 'Allow write access'"
echo "  5. Repetir para Auditoria_EcoSauron"
echo "  ════════════════════════════════════════"
echo ""
read -r -p "  ¿Ya agregaste las deploy keys en GitHub? (s/N): " KEYS_OK
[[ "$KEYS_OK" =~ ^[sS]$ ]] || \
    echo "  WARN: sin deploy keys el git push del briefing fallará."

# ── 7. Cron ──────────────────────────────────────────────────────
echo "[7/7] Cron..."
CRON_SCRIPT="$CREW_DIR/cron_briefing_servidor.sh"
chmod +x "$CRON_SCRIPT"

# 09:50 UTC = 06:50 ART (UTC-3), lun-vie
CRON_LINE="50 9 * * 1-5 $CRON_SCRIPT >> $CREW_DIR/logs/cron.log 2>&1"

# Idempotente: solo agregar si no existe
if crontab -l 2>/dev/null | grep -qF "cron_briefing_servidor.sh"; then
    echo "  ~ cron ya registrado"
else
    (crontab -l 2>/dev/null || true; echo "$CRON_LINE") | crontab -
    echo "  + cron registrado: $CRON_LINE"
fi

# ── Health check ─────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════"
echo " Health check..."
echo "════════════════════════════════════════════"

source "$VENV/bin/activate"
cd "$CREW_DIR"

if python -m src.crew_ecosauron.main --dry-run 2>&1 | \
        grep -q "DRY RUN"; then
    echo "  crew_ecosauron --dry-run   OK"
else
    echo "  WARN: dry-run con advertencias — revisar .env.local"
fi

echo ""
echo "════════════════════════════════════════════"
echo " INSTALACIÓN COMPLETA"
echo "════════════════════════════════════════════"
echo ""
echo " Repos   : $CREW_DIR"
echo "           $ECOSAURON_DIR"
echo " Venv    : $VENV"
echo " Config  : $ENV_FILE"
echo " Cron    : 09:50 UTC (06:50 ART) lun-vie"
echo " Logs    : $CREW_DIR/logs/cron.log"
echo ""
if grep -q "COMPLETAR_AQUI" "$ENV_FILE" 2>/dev/null; then
    echo " ⚠  PENDIENTE:"
    echo "    PG_PASSWORD en $ENV_FILE"
    echo ""
fi
echo " Ejecutar manualmente para probar:"
echo "   $CRON_SCRIPT"
echo "════════════════════════════════════════════"
