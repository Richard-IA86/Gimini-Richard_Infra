# prueba_sauron_ser — Conexión M2/Windows → M3/Hetzner vía VS Code Remote-SSH

**Fecha:** 2026-05-21
**Ejecuta:** Richard desde M2 (Asus/Windows)
**Objetivo:** Verificar que VS Code en M2 puede conectarse al servidor M3 (Hetzner)
vía Remote-SSH y operar el workspace `/opt/pose/` como entorno de trabajo principal.

---

## Prerrequisitos — checklist antes de empezar

- [ ] VS Code instalado en M2
- [ ] Extensión **Remote - SSH** instalada en VS Code
  (`ms-vscode-remote.remote-ssh`)
- [ ] Llave SSH disponible en `%USERPROFILE%\.ssh\id_ed25519_hetzner`
- [ ] WireGuard instalado y activo en M2

---

## Paso 1 — Verificar WireGuard activo en M2

```powershell
ping 10.10.0.1 -n 2
```

**Resultado esperado:** 2 paquetes respondidos desde `10.10.0.1`.

Si no responde → activar WireGuard desde la UI antes de continuar.

---

## Paso 2 — Verificar llave SSH en M2

```powershell
Test-Path "$env:USERPROFILE\.ssh\id_ed25519_hetzner"
```

**Resultado esperado:** `True`

Si devuelve `False` → la llave no fue transferida. Solicitar a M1.

---

## Paso 3 — Configurar SSH config en M2

Abrir (o crear) `%USERPROFILE%\.ssh\config` y agregar:

```
Host pose-m3
    HostName 10.10.0.1
    User root
    IdentityFile ~/.ssh/id_ed25519_hetzner
    ServerAliveInterval 60
    ServerAliveCountMax 3

Host pose-m3-pub
    HostName 178.104.226.136
    User root
    IdentityFile ~/.ssh/id_ed25519_hetzner
    ServerAliveInterval 60
```

> `pose-m3` usa WireGuard (preferido, más rápido).
> `pose-m3-pub` es fallback por IP pública si WireGuard no responde.

---

## Paso 4 — Test SSH desde PowerShell

```powershell
ssh pose-m3 "hostname && echo OK"
```

**Resultado esperado:**
```
<nombre-servidor>
OK
```

Si aparece prompt de contraseña → llave no autorizada en el servidor. Reportar a M1.

---

## Paso 5 — Conectar desde VS Code

1. Abrir VS Code en M2.
2. Presionar `F1` → **Remote-SSH: Connect to Host...**
3. Seleccionar `pose-m3`.
4. VS Code Server se instala automáticamente en M3 (primera vez: ~1 min).
5. Esperar barra inferior:

```
>< SSH: pose-m3
```

---

## Paso 6 — Abrir workspace en M3

Una vez conectado:

1. `File` → `Open Folder...`
2. Escribir `/opt/pose/`
3. Confirmar.

Verificar que el explorador muestra:

```
/opt/pose/
├── auditoria_ecosauron/
├── crew_ecosauron/
├── docker-compose.yml
├── Gimini-Richard_Infra/
├── Pose_API/
├── Pose_Frontend/
├── POSE_ETL/
└── workspace/
```

---

## Paso 7 — Verificar entorno crew_ecosauron

Abrir terminal integrada (`` Ctrl+` ``):

```bash
cd /opt/pose/crew_ecosauron
source venv/bin/activate
python -c "import src.crew_ecosauron.main; print('import OK')"
```

**Resultado esperado:** `import OK`

---

## Paso 8 — Verificar cron activo

```bash
crontab -l | grep crew
```

**Resultado esperado:**

```
50 9 * * 1-5 /opt/pose/crew_ecosauron/cron_briefing_servidor.sh >> ...
```

---

## Semáforo de resultado

| Check | Verde | Rojo |
|-------|-------|------|
| WireGuard ping 10.10.0.1 | responde | timeout |
| Llave SSH en M2 | `True` | `False` |
| SSH `pose-m3` sin password | `OK` en output | pide contraseña |
| VS Code barra inferior | `SSH: pose-m3` | error |
| `/opt/pose/` visible | 8 carpetas/archivos | vacío |
| import crew_ecosauron | `import OK` | ImportError |
| cron activo | línea `50 9 ...` | crontab vacío |

---

## Reportar resultado a M1

Documentar en `POSE_ETL/config/estado_proyecto.json`
→ sección `m2_pendiente.ultimo_resultado`:

```json
{
  "tarea": "prueba_SauronSer",
  "fecha": "2026-05-21",
  "ssh_ok": true,
  "vscode_remote_ok": true,
  "workspace_abierto": "/opt/pose/",
  "crew_import_ok": true,
  "cron_activo": true,
  "observaciones": ""
}
```

Luego push:

```powershell
cd C:\path\to\POSE_ETL
git add config/estado_proyecto.json
git commit -m "chore(m2): prueba_SauronSer completada 2026-05-21"
git push
```
