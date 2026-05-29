# Instructivo de Instalación WireGuard — Analistas POSE
**Versión:** 2026-05-29  
**Dirigido a:** Personal de Sistemas  
**Objetivo:** Conectar laptops de analistas contables a la VPN del servidor Sauron para acceder al recurso compartido `\\10.10.0.1\analistas`.

---

## Asignación de IPs

| Analista  | Archivo de config      | IP VPN        |
|-----------|------------------------|---------------|
| Martina   | `wg0_martina.conf`     | 10.10.0.8     |
| Agustina  | `wg0_agustina.conf`    | 10.10.0.5     |
| Agostina  | `wg0_agostina.conf`    | 10.10.0.6     |
| Mauro     | `wg0_mauro.conf`       | 10.10.0.7     |

Servidor VPN: **178.104.226.136:51820**  
Red VPN: **10.10.0.0/24**

---

## Paso a paso — Windows (10/11)

### 1. Instalar WireGuard

1. Descargar el instalador oficial desde: https://www.wireguard.com/install/  
   → Elegir **"Windows"** → descargar `wireguard-installer.exe`
2. Ejecutar el instalador con permisos de administrador.
3. Al terminar, abrir la aplicación **WireGuard** desde el menú inicio.

### 2. Importar la configuración

1. En la app WireGuard, hacer clic en **"Importar túnel(es) desde archivo"** (ícono `+` → Import tunnel(s) from file).
2. Seleccionar el archivo `.conf` correspondiente al analista (ej: `wg0_agustina.conf`).
3. Aparecerá un túnel llamado **`wg0`** en la lista.

### 3. Activar la conexión

1. Seleccionar el túnel `wg0` y hacer clic en **"Activar"**.
2. El estado cambia a **"Activo"** → la IP VPN queda asignada.
3. Verificar conectividad:
   - Abrir `cmd` o PowerShell y ejecutar:
     ```
     ping 10.10.0.1
     ```
   - Debe responder en < 50ms.

### 4. Montar la carpeta compartida

1. Abrir el **Explorador de archivos**.
2. En la barra de direcciones escribir:
   ```
   \\10.10.0.1\analistas
   ```
3. Ingresar credenciales Samba cuando las solicite:
   - **Usuario:** nombre del analista (ej: `agustina`)
   - **Contraseña:** la que le proporcionó Sistemas / Richard
4. La carpeta `analistas` queda accesible. Dentro hay una subcarpeta por analista.

> **Tip:** Para mapear como unidad permanente → clic derecho en "Este equipo" → "Conectar a unidad de red" → ingresar `\\10.10.0.1\analistas\<nombre>` y tildar "Reconectar al iniciar sesión".

---

## Paso a paso — Android (opcional)

1. Instalar **WireGuard** desde Google Play Store.
2. En la app, tocar **`+`** → **"Importar desde archivo o archivo"** o **"Escanear QR"**.
3. Si se dispone de QR: generarlo desde Windows con `qrencode` (ver sección avanzada).
4. Si se importa por archivo: pasar el `.conf` al teléfono por cualquier medio y abrirlo con la app.
5. Activar el túnel → verificar con ping `10.10.0.1`.

---

## Solución de problemas

| Síntoma | Causa probable | Acción |
|---------|---------------|--------|
| El túnel se activa pero no hay ping | Firewall Windows bloqueando ICMP | Permitir ICMP entrante en el firewall |
| "No se puede encontrar la ruta de red" | WireGuard no está activo | Activar el túnel antes de acceder a `\\10.10.0.1` |
| Handshake nunca completa | Puerto 51820/UDP bloqueado en red corporativa | Probar desde otra red / hotspot |
| Error al importar el .conf | Formato inválido o archivo corrupto | Volver a copiar el archivo desde el servidor |

---

## Notas para Sistemas

- Los archivos `.conf` contienen **claves privadas** — tratarlos como contraseñas. No enviar por email en texto plano. Compartir por USB o carpeta segura.
- Cada archivo es **único por analista** — no intercambiar configs entre usuarios.
- Si una laptop se pierde o roba: avisar a Richard para revocar el peer en el servidor (operación remota, no requiere acción en la laptop).
- Para agregar un analista nuevo: contactar a Richard (genera nuevas claves, actualiza servidor y entrega nuevo `.conf`).

---

## Archivos entregados

```
wg0_martina.conf    ← para Martina   (IP: 10.10.0.8)
wg0_agustina.conf   ← para Agustina  (IP: 10.10.0.5)
wg0_agostina.conf   ← para Agostina  (IP: 10.10.0.6)
wg0_mauro.conf      ← para Mauro     (IP: 10.10.0.7)
```
