# 🏗️ POSE - Búnker de Infraestructura y DevOps

Bienvenido al repositorio central de Infraestructura del ecosistema **POSE**. Este repositorio sirve como el panel de control (Búnker) para toda la arquitectura, orquestación y despliegue continuo del proyecto.

---

## 🗺️ Arquitectura del Ecosistema
El proyecto está dividido en tres repositorios independientes para mantener la sanidad del código y responsabilidades claras:

1. **[Gimini-Richard_Infra](https://github.com/Richard-IA86/Gimini-Richard_Infra):** (Este repositorio). Contiene el `docker-compose.yml` maestro, configuraciones de Nginx, scripts de backup y documentación de secretos. **Solo lo toca el Ingeniero DevOps (Gemini).**
2. **[Pose_API](https://github.com/Richard-IA86/Pose_API):** Backend construido en FastAPI (Python). Maneja la lógica de negocio, base de datos y JWT.
3. **[Pose_Frontend](https://github.com/Richard-IA86/Pose_Frontend):** Dashboard construido en Next.js (TypeScript). 

---

## ⚙️ Orquestación Maestra (Local y Producción)
Toda la infraestructura está dockerizada. El archivo `docker-compose.yml` de este repositorio levanta los siguientes servicios:
- **`pose_db`**: Base de Datos PostgreSQL.
- **`pose_api`**: Contenedor del backend.
- **`pose_frontend`**: Contenedor del frontend.

### ¿Cómo correr todo localmente en tu computadora?
Dado que este `docker-compose.yml` apunta a las imágenes de producción en GitHub, si deseas levantar el entorno de desarrollo local mientras programas, debes ejecutar los entornos en sus respectivas carpetas.
Sin embargo, para simular producción, puedes ejecutar aquí:
```bash
docker-compose up -d
```

---

## 🚀 Despliegue Continuo (CI/CD)
El ecosistema cuenta con integración y despliegue continuo automatizado usando **GitHub Actions**.

1. **Desarrollo:** Copilot o tú hacen `git push` a la rama `master` en `Pose_API` o `Pose_Frontend`.
2. **Construcción:** GitHub Actions empaqueta automáticamente el nuevo código en una imagen Docker y la sube a **GitHub Container Registry (ghcr.io)**.
3. **Despliegue:** La Action se conecta por SSH a nuestro servidor **Hetzner**, descarga la nueva imagen y reinicia los contenedores automáticamente.

*Nota: Para ver los secretos necesarios para que esto funcione, revisa el archivo `secretos_github.md`.*

---

## 🛡️ Scripts y Mantenimiento
- **`nginx.conf`**: Configuración del Reverse Proxy para enrutar el tráfico de los usuarios hacia el Frontend o la API según corresponda.
- **`backup_db.sh`**: Script para generar respaldos diarios de la base de datos PostgreSQL. Mantiene un histórico de los últimos 7 días.

---
*Este repositorio fue diseñado y configurado por Gemini (Arquitecto/DevOps) en colaboración con Richard.*
