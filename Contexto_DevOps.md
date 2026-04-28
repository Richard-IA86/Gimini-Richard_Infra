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
*Mensaje para la nueva sesión de Gemini:* "Lee este documento y ponte a disposición del usuario para ejecutar el Punto 4 del Plan de Trabajo."
