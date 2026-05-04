# Contexto Inicial: DevOps Sprint 17

Este archivo ha sido generado para transferir el contexto de las decisiones tomadas en el entorno del "Ojo de Sauron" hacia este nuevo entorno independiente de Infraestructura.

## 1. División de Funciones
- **Copilot:** Desarrollador. Escribe código, tests y hace Pull Requests.
- **Gemini (Yo):** Ingeniero DevOps. Me encargo de Docker, CI/CD (GitHub Actions), servidor Hetzner, Nginx, VPN y despliegues. **Nunca toco la lógica de negocio.**
- **Regla de Oro:** Ningún despliegue automático ocurre sin un *merge* humano previo en GitHub.

## 2. Nueva Estructura del Ecosistema
Se decidió sacar las aplicaciones productivas del Ojo de Sauron (`auditoria_ecosauron`) por sanidad arquitectónica. El nuevo ecosistema en la máquina local (`/home/richard/Dev/`) se ve así:

- 📂 `auditoria_ecosauron/` (Solo QA y auditoría)
- 📂 `Pose_API/` (FastAPI backend)
- 📂 `Pose_Frontend/` (Next.js dashboard)
- 📂 `Gimini-Richard_Infra/` (Este repositorio - El Búnker DevOps)

## 3. Estado Actual de la Infraestructura
- **API:** Hemos inicializado la estructura base de FastAPI y creado su `Dockerfile` para producción.
- **Frontend:** Hemos inicializado la configuración base de Next.js (`package.json`, `next.config.mjs`) y su `Dockerfile` multi-stage.
- **CI/CD:** Hemos creado los workflows base en `.github/workflows/deploy.yml` para ambos repos. Estos corren linters, construyen la imagen Docker y hacen SSH a Hetzner para el pull y reinicio.
- **Auditoría Local:** El script `run_audit.sh` del Ojo de Sauron ha sido actualizado para poder evaluar TypeScript y Node.js, y ya sabe apuntar a estas nuevas carpetas externas.

## 4. Plan de Trabajo en este Búnker (Siguientes Pasos)
1. **Consolidar Git:** Inicializar este repositorio `Gimini-Richard_Infra` y los de la API/Frontend en GitHub.
2. **Orquestación Maestra:** Mantener aquí el `docker-compose.yml` maestro que levantará todas las piezas (API, Frontend, BD) en Hetzner.
3. **Secretos:** Documentar aquí qué secretos deben configurarse en GitHub para los Actions (`HETZNER_SSH_PRIVATE_KEY`, `GITHUB_TOKEN`, etc).
4. **Scripts de Servidor:** Mantener aquí los scripts de backup diarios (`pg_dump`) y configuración de Nginx / Firewall.

---

## Incidente 521 — 2026-05-04 (RESUELTO)

### Síntoma
`www.gestionpose.com.ar` devolvía **Cloudflare Error 521** (servidor no responde).

### Causa raíz
Docker Engine se actualizó automáticamente el **2026-04-20** a **v29.4.1**
(API mínima: 1.40). El Go SDK embebido en Traefik v2.10 negocia con API 1.24
→ el daemon rechaza la conexión → Traefik no descubre contenedores → sin routing.

### Fix aplicado

**1. Traefik v2.10 → v3.3 + File Provider**
- Docker Provider eliminado (incompatible con Docker 29.x).
- Rutas hardcodeadas en `traefik/config/dynamic.yaml`.
- ACME cambiado de TLS-ALPN-01 a HTTP-01 (TLS-ALPN-01 es interceptado
  por Cloudflare proxy).

**2. Registro DNS faltante**
- `api.gestionpose.com.ar` no tenía registro A en Cloudflare.
- Agregado: tipo A → `178.104.226.136` (Proxied).

**3. PostgreSQL inaccesible desde contenedores Docker**
- `DB_HOST=10.10.0.1` (WireGuard) no es ruteable desde la red bridge Docker.
- Fix: `DB_HOST=172.18.0.1` (gateway del bridge `pose_network`).
- UFW: `ufw allow from 172.18.0.0/16 to any port 5432`
- `pg_hba.conf`: agregada línea
  `host all all 172.18.0.0/16 scram-sha-256`

### Estado post-fix
- `gestionpose.com.ar` → ✅ HTTPS 200 (Next.js)
- `api.gestionpose.com.ar` → ✅ HTTPS 200 (FastAPI + PostgreSQL)
- Certificados Let's Encrypt → ✅ emitidos vía HTTP-01

### Archivos modificados en servidor Hetzner
- `/opt/traefik/docker-compose.yml` — Traefik v3.3 + File Provider
- `/opt/traefik/config/dynamic.yaml` — rutas creadas
- `/opt/pose/docker-compose.yml` — DB_HOST corregido
- `/etc/postgresql/16/main/pg_hba.conf` — red Docker permitida

---
*Mensaje para la nueva sesión de Gemini:* "Lee este documento y ponte a disposición del usuario para ejecutar el Punto 4 del Plan de Trabajo."
