# Premiere para Claude

Conecta **Adobe Premiere Pro** con **Claude** para que te organice los proyectos: crear carpetas, mover clips, audios e imágenes, renombrar, limpiar lo que no usas.

Un solo comando. Audita lo que ya tienes en la Mac, instala solo lo que falte y deja el conector registrado.

```bash
curl -fsSL https://raw.githubusercontent.com/prcontreras23/premiere-para-claude/main/instalar.sh | bash
```

---

## Qué hace y qué no

**Sí, y bien**: inventariar el proyecto, crear bins, mover clips/audios/imágenes a carpetas, renombrar, borrar archivos que no se usan. Lo tedioso.

**No**: editar el video. Cortes, zooms y ajustes de volumen los intenta, pero falla. No es para eso.

Ejemplo real de lo que se le pide:

> organiza los archivos del proyecto en carpetas: imágenes en `img`, audios en `audio`, videos en `clips`

Tarda un par de minutos y uno se dedica a otra cosa mientras.

---

## Qué necesitas

- Una Mac
- **Adobe Premiere Pro** instalado (viene por Creative Cloud; esto no lo puede instalar el script)
- Claude Code o la app de Claude — si no tienes ninguno, el instalador pone Claude Code
- Unos 5 minutos

No hace falta saber programar. Node.js y Claude Code los instala solo, **sin pedir contraseña de administrador**: usa Homebrew si lo tienes y si no baja los instaladores oficiales a tu carpeta de usuario.

---

## Qué instala exactamente

| Pieza | Dónde queda |
|---|---|
| Node.js (si falta) | Homebrew, o `~/.local/node` |
| Claude Code (si falta) | el instalador oficial de Anthropic |
| Servidor MCP [`premiere-pro-mcp`](https://github.com/leancoderkavy/premiere-pro-mcp) | paquete global de npm |
| Conector dentro de Premiere (extensión CEP) | `~/Library/Application Support/Adobe/CEP/extensions/MCPBridgeCEP` |
| Modo desarrollador de Adobe | `PlayerDebugMode = 1` en CSXS 8–14 |
| Registro del conector | Claude Code y `claude_desktop_config.json` (con respaldo) |

Correrlo dos veces no rompe nada: lo que ya está hecho se salta, y si hay una versión más nueva del servidor la actualiza.

---

## Solo auditar, sin instalar

Para ver qué tienes y qué falta sin tocar nada:

```bash
curl -fsSL https://raw.githubusercontent.com/prcontreras23/premiere-para-claude/main/instalar.sh | bash -s -- --auditar
```

---

## Después de instalar: tres pasos a mano

Esto no se puede automatizar desde fuera de Premiere.

1. **Cierra Claude por completo** (⌘Q) y ábrelo otra vez.
2. **Abre Premiere y abre un proyecto.** Con Premiere vacío el panel sale desactivado — es el error que más tiempo hace perder.
3. **Ventana → Extensiones → «MCP for Adobe Premiere Pro».** Déjalo abierto o minimizado mientras editas: si lo cierras, se cae la conexión.

Ya después le pides a Claude que te organice el proyecto.

---

## Si algo sale mal

El instalador deja un log completo:

```bash
cat ~/premiere-para-claude/instalacion.log
```

Y el diagnóstico del servidor se puede correr solo:

```bash
premiere-pro-mcp --doctor
```

**Premiere tiene que estar cerrado** cuando se instala el conector. Si estaba abierto, ciérralo y corre el instalador otra vez.

**Si npm avisa `EBADENGINE`**: tu Node sirve, pero una dependencia del servidor prefiere Node 22.22 o más nuevo. Funciona igual; si algún día el servidor falla raro, ese es el primer sospechoso.

---

## Desinstalar

```bash
~/premiere-para-claude-fuente/desinstalar.sh
```

Quita el conector de Premiere, el registro en Claude y el paquete de npm. Deja como estaban Node.js, Claude Code y el modo desarrollador de Adobe, porque otras extensiones de Creative Cloud pueden depender de él.

---

## Privacidad

- El servidor corre **en tu Mac**. No hay servidor de nadie en medio.
- Lo que sale hacia Claude es lo que tú le pidas en cada conversación: si le pides el inventario del proyecto, esa lista va a Claude para poder trabajarla.
- El servidor trae telemetría opcional (PostHog) que **viene apagada**: necesita una variable `POSTHOG_API_KEY` que este instalador no pone. Según su documentación no manda nombres de proyecto, rutas, prompts ni resultados.

---

## Créditos

El servidor MCP es [`premiere-pro-mcp`](https://github.com/leancoderkavy/premiere-pro-mcp), de **leancoderkavy** (MIT). Este repo solo instala y documenta en español; el mérito del conector es suyo.

Instaladores y documentación: **Francis Contreras**. Mismo patrón que [logos-para-claude](https://github.com/prcontreras23/logos-para-claude).
