#!/usr/bin/env bash
# setup_workspace.sh — Espacio de trabajo unificado POSE en Hetzner
# Ejecutar como root en el servidor: bash setup_workspace.sh
#
# Estructura resultante:
#   /opt/pose/workspace/analistas/          ← share Samba compartido
#   /opt/pose/workspace/analistas/martina/
#   /opt/pose/workspace/analistas/agustina/
#   /opt/pose/workspace/analistas/agostina/
#   /opt/pose/workspace/analistas/mauro/
#   /opt/pose/workspace/sauron/reportes/    ← lectura para todos
#   /opt/pose/workspace/sauron/logs/        ← solo root/sauron
#
# Peers WireGuard generados: 10.10.0.4–10.10.0.7
# Configs cliente → /root/wg_analistas/wg0_<nombre>.conf
set -euo pipefail

# ── Configuración ─────────────────────────────────────────────────
WORKSPACE="/opt/pose/workspace"
ANALISTAS=(martina agustina agostina mauro)
WG_IPS=(10.10.0.4 10.10.0.5 10.10.0.6 10.10.0.7)
WG_SERVER_ENDPOINT="178.104.226.136:51820"
WG_CONFIG_DIR="/root/wg_analistas"
WG_IFACE="wg0"
GRUPO="analistas_pose"

# ── Validaciones previas ──────────────────────────────────────────
[[ $EUID -ne 0 ]] && {
    echo "ERROR: ejecutar como root." >&2
    exit 1
}

WG_SERVER_PUBKEY=$(
    wg show "$WG_IFACE" public-key 2>/dev/null || true
)
if [[ -z "$WG_SERVER_PUBKEY" ]]; then
    echo "ERROR: interfaz $WG_IFACE no activa." >&2
    echo "       Verificar: wg show" >&2
    exit 1
fi

echo ""
echo "════════════════════════════════════════════"
echo " POSE Workspace Setup"
echo " Servidor : $WG_SERVER_ENDPOINT"
echo " WG pubkey: $WG_SERVER_PUBKEY"
echo "════════════════════════════════════════════"
echo ""

# ── 1. Grupo Linux compartido ─────────────────────────────────────
echo "[1/5] Grupo del sistema: $GRUPO"
if ! getent group "$GRUPO" &>/dev/null; then
    groupadd "$GRUPO"
    echo "  + grupo $GRUPO creado"
else
    echo "  ~ grupo $GRUPO ya existe"
fi

# ── 2. Estructura de carpetas ─────────────────────────────────────
echo "[2/5] Carpetas..."
mkdir -p "$WORKSPACE/sauron/reportes"
mkdir -p "$WORKSPACE/sauron/logs"
chown -R root:root "$WORKSPACE/sauron"
chmod 755 "$WORKSPACE/sauron/reportes"
chmod 700 "$WORKSPACE/sauron/logs"

# Raíz analistas: grupo analistas_pose, setgid (herencia de grupo)
mkdir -p "$WORKSPACE/analistas"
chown root:"$GRUPO" "$WORKSPACE/analistas"
chmod 2775 "$WORKSPACE/analistas"

for user in "${ANALISTAS[@]}"; do
    mkdir -p "$WORKSPACE/analistas/$user"
done
echo "      OK"

# ── 3. Usuarios Linux ─────────────────────────────────────────────
echo "[3/5] Usuarios del sistema..."
for user in "${ANALISTAS[@]}"; do
    if ! id "$user" &>/dev/null; then
        useradd --no-create-home \
                --shell /usr/sbin/nologin \
                --gid "$GRUPO" \
                "$user"
        echo "  + $user creado (grupo primario: $GRUPO)"
    else
        echo "  ~ $user ya existe — añadiendo a $GRUPO"
        usermod -aG "$GRUPO" "$user"
    fi
    chown "$user":"$GRUPO" "$WORKSPACE/analistas/$user"
    # Dueño: rwx — grupo: rwx — otros: ---
    # Setgid: nuevos archivos heredan grupo analistas_pose
    chmod 2770 "$WORKSPACE/analistas/$user"
done

# ── 4. Samba ──────────────────────────────────────────────────────
echo "[4/5] Samba..."
apt-get install -y -q samba

SMB_CONF="/etc/samba/smb.conf"
BACKUP="${SMB_CONF}.bak.$(date +%Y%m%d%H%M%S)"
cp "$SMB_CONF" "$BACKUP" 2>/dev/null && \
    echo "  ~ backup: $BACKUP" || true

VALID_USERS=$(printf "%s " "${ANALISTAS[@]}" | sed 's/ $//')

{
cat << GLOBAL
[global]
   workgroup = POSE
   server string = POSE Workspace
   server role = standalone server
   log file = /var/log/samba/log.%m
   max log size = 500
   obey pam restrictions = yes
   map to guest = bad user
   # Solo accesible desde la red VPN WireGuard
   hosts allow = 10.10.0. 127.
   hosts deny = ALL
   # Protocolo mínimo SMB2 (seguridad — deshabilita SMB1)
   server min protocol = SMB2

GLOBAL

# Share colectivo — todos los analistas ven y acceden a todas
# las carpetas. force group garantiza herencia del grupo en
# archivos nuevos, permitiendo lectura cruzada.
cat << SHARE

[analistas]
   comment = Carpetas de trabajo — Equipo Analistas POSE
   path = $WORKSPACE/analistas
   valid users = $VALID_USERS
   read only = no
   browseable = yes
   create mask = 0664
   directory mask = 2775
   force group = $GRUPO

SHARE

# Share reportes Sauron — lectura para todo el equipo
cat << SHARE

[reportes_sauron]
   comment = Reportes generados por Sauron (solo lectura)
   path = $WORKSPACE/sauron/reportes
   valid users = $VALID_USERS
   read only = yes
   browseable = yes

SHARE
} > "$SMB_CONF"

systemctl enable smbd nmbd --quiet
systemctl restart smbd nmbd
echo "      Samba OK"
echo "      Pendiente — establecer contraseña por analista:"
for user in "${ANALISTAS[@]}"; do
    echo "        smbpasswd -a $user"
done
echo "      Acceso cliente: \\\\10.10.0.1\\analistas"

# ── 5. WireGuard — configs para analistas ────────────────────────
echo "[5/5] WireGuard configs..."
mkdir -p "$WG_CONFIG_DIR"
chmod 700 "$WG_CONFIG_DIR"

# Leer peers ya registrados para evitar duplicados
EXISTING_PEERS=$(wg show "$WG_IFACE" peers 2>/dev/null || true)

for i in "${!ANALISTAS[@]}"; do
    user="${ANALISTAS[$i]}"
    client_ip="${WG_IPS[$i]}"

    # Verificar si ya existe peer con esa IP asignada
    if grep -q "AllowedIPs = ${client_ip}/32" \
            /etc/wireguard/wg0.conf 2>/dev/null; then
        echo "  ~ $user ($client_ip) — peer ya registrado, omitiendo"
        continue
    fi

    privkey=$(wg genkey)
    pubkey=$(echo "$privkey" | wg pubkey)
    psk=$(wg genpsk)

    # ── Config para distribuir al analista ───────────────────────
    # AllowedIPs split-tunnel:
    #   10.10.0.0/24 → red VPN (Samba + PostgreSQL directo)
    # El tráfico a internet (gestionpose.com.ar) NO pasa por VPN.
    cat > "$WG_CONFIG_DIR/wg0_${user}.conf" << EOF
[Interface]
PrivateKey = $privkey
Address = $client_ip/32
DNS = 10.10.0.1

[Peer]
# Servidor Hetzner
PublicKey = $WG_SERVER_PUBKEY
PresharedKey = $psk
Endpoint = $WG_SERVER_ENDPOINT
# Split-tunnel: solo red interna POSE por VPN
AllowedIPs = 10.10.0.0/24
PersistentKeepalive = 25
EOF
    chmod 600 "$WG_CONFIG_DIR/wg0_${user}.conf"

    # ── Registrar peer en wg0.conf del servidor ───────────────────
    cat >> /etc/wireguard/wg0.conf << EOF

# $user — agregado $(date +%Y-%m-%d)
[Peer]
PublicKey = $pubkey
PresharedKey = $psk
AllowedIPs = $client_ip/32
EOF

    # Activar peer en caliente sin reiniciar la VPN
    # (no interrumpe sesiones activas de iMac/Asus)
    wg set "$WG_IFACE" peer "$pubkey" \
        preshared-key <(echo "$psk") \
        allowed-ips "$client_ip/32"

    echo "  + $user → $client_ip (activo en caliente)"
done

# Sincronizar estado en memoria con wg0.conf
# (reconcilia cualquier diferencia sin reiniciar)
wg syncconf "$WG_IFACE" /etc/wireguard/wg0.conf
echo "      wg syncconf OK — peers activos:"
wg show "$WG_IFACE" allowed-ips

# ── Resumen final ──────────────────────────────────────────────────
echo ""
echo "════════════════════════════════════════════"
echo " SETUP COMPLETO"
echo "════════════════════════════════════════════"
echo ""
echo " 1. Establecer contraseñas Samba:"
for user in "${ANALISTAS[@]}"; do
    echo "      smbpasswd -a $user"
done
echo ""
echo " 2. Distribuir configs WireGuard a cada analista:"
for user in "${ANALISTAS[@]}"; do
    echo "      $WG_CONFIG_DIR/wg0_${user}.conf"
done
echo ""
echo " 3. Instrucción para analistas (Windows):"
echo "      Instalar WireGuard → importar wg0_<nombre>.conf"
echo "      Conectar → mapear unidad de red:"
echo "      \\\10.10.0.1\analistas"
echo ""
echo " 4. Verificar peers activos en cualquier momento:"
echo "      wg show wg0"
echo ""
echo " 5. Estructura de carpetas en el servidor:"
echo "      $WORKSPACE/analistas/{martina,agustina,agostina,mauro}/"
echo "      $WORKSPACE/sauron/reportes/  (lectura VPN)"
echo "════════════════════════════════════════════"
