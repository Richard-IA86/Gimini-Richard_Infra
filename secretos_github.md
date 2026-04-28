# Documentación de Secretos CI/CD

Para que los despliegues automáticos (GitHub Actions) funcionen hacia nuestro servidor en Hetzner, es necesario configurar los siguientes "Repository Secrets" en los repositorios de GitHub (`Pose_API` y `Pose_Frontend`).

## Secretos Requeridos en GitHub

Ve a `Settings` > `Secrets and variables` > `Actions` > `New repository secret` en cada repositorio y agrega:

1. **`HETZNER_IP`**
   - **Descripción:** La dirección IP pública de nuestro servidor VPS en Hetzner.
   - **Ejemplo:** `198.51.100.23`

2. **`HETZNER_USER`**
   - **Descripción:** El usuario SSH para conectarse al servidor.
   - **Ejemplo:** `root` (o el usuario con permisos de docker que hayamos configurado).

3. **`HETZNER_SSH_KEY`**
   - **Descripción:** La llave privada SSH (`id_rsa` o `id_ed25519`) que tiene permisos para entrar al servidor sin contraseña.

## Permisos del GITHUB_TOKEN
Para que las Actions puedan subir las imágenes Docker a GitHub Container Registry (ghcr.io), asegúrate de que en los repositorios:
- En `Settings` > `Actions` > `General` > `Workflow permissions`
- Esté seleccionada la opción: **"Read and write permissions"**.
