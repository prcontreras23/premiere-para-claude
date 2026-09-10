#!/bin/bash
# Instalador de Premiere para Claude — macOS
#
# Audita lo que ya tienes, instala solo lo que falta y deja el conector
# registrado en Claude. Se puede correr las veces que quieras: lo que ya está
# hecho se salta.
#
#   ./install.sh              audita e instala lo que falte
#   ./install.sh --auditar    solo revisa y reporta, no instala nada
#   ./install.sh --sin-app    no tocar la configuración de la app de Claude

set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="$HOME/premiere-para-claude/instalacion.log"
SOLO_AUDITAR=false
TOCAR_APP=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --auditar|--audit) SOLO_AUDITAR=true; shift ;;
    --sin-app) TOCAR_APP=false; shift ;;
    *) shift ;;
  esac
done

mkdir -p "$(dirname "$LOG")"
exec > >(tee "$LOG") 2>&1

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '\033[32m  ✓\033[0m %s\n' "$*"; }
info() { printf '\033[90m  · %s\033[0m\n' "$*"; }
falta(){ printf '\033[33m  ○ %s\033[0m\n' "$*"; }
warn() { printf '\033[33m  ! %s\033[0m\n' "$*"; }
err()  { printf '\033[31m  ✗ %s\033[0m\n' "$*" >&2; }
paso() { echo; bold "$*"; }
morir(){ echo; err "$*"; echo; exit 1; }

echo
bold "═══ Premiere para Claude ═══"
echo
info "Conecta Adobe Premiere Pro con Claude para que te organice los proyectos:"
info "crear carpetas, mover clips, audios e imágenes, renombrar, limpiar lo que no usas."
info "No edita el video — cortes, zooms y volumen no son lo suyo."
echo

[[ "$(uname -s)" == "Darwin" ]] || morir "Este instalador es para Mac."

# shellcheck source=lib-requisitos.sh
source "$REPO_DIR/lib-requisitos.sh" || morir "Falta el archivo lib-requisitos.sh"
ruta_extendida

# ═══════════════════════════════════════════════════════ 1. AUDITORÍA

paso "1. Auditoría — qué tienes y qué falta"

FALTANTES=()

# --- Premiere Pro (esto no lo puede instalar nadie más que Adobe)
if tiene_premiere; then
  ok "Adobe Premiere Pro $(version_premiere 2>/dev/null)"
  tiene_premiere_beta && info "también tienes la Beta; el conector se instala para la versión normal"
else
  falta "Adobe Premiere Pro — no está instalado"
  info "viene por Creative Cloud y es de pago; este instalador no lo puede bajar"
  FALTANTES+=("premiere")
fi

# --- Node.js
if node_sirve; then
  ok "Node.js v$(node_version)"
  node_avisa_ebadengine && info "npm va a avisar EBADENGINE (una dependencia pide 22.22+); funciona igual"
else
  falta "Node.js 20.19 o más nuevo"
  FALTANTES+=("node")
fi

# --- Claude
if tiene claude; then ok "Claude Code"; else falta "Claude Code"; FALTANTES+=("claude"); fi
tiene_claude_app && ok "App de Claude" || info "la app de escritorio de Claude no está (opcional si usas Claude Code)"

# --- Servidor MCP
if cli_mcp >/dev/null; then
  V_LOCAL="$(version_mcp)"; V_NPM="$(version_mcp_publicada)"
  if [[ -n "$V_NPM" && -n "$V_LOCAL" && "$V_LOCAL" != "$V_NPM" ]]; then
    ok "Servidor MCP v$V_LOCAL"
    info "hay una versión más nueva (v$V_NPM); se va a actualizar"
    FALTANTES+=("mcp")
  else
    ok "Servidor MCP v${V_LOCAL:-?}"
  fi
else
  falta "Servidor MCP ($PAQUETE)"
  FALTANTES+=("mcp")
fi

# --- Extensión CEP dentro de Premiere
if tiene_cep; then ok "Conector dentro de Premiere (extensión CEP)"; else falta "Conector dentro de Premiere"; FALTANTES+=("cep"); fi
if debug_cep_activo; then ok "Modo desarrollador de Adobe"; else falta "Modo desarrollador de Adobe (PlayerDebugMode)"; FALTANTES+=("debug"); fi

# --- Registro en Claude
# Claude Code es la vía confiable: `claude mcp add` se queda puesto.
# La app de escritorio es otra historia — ver la nota en el paso 4.
REG_CODE=false; REG_APP=false
tiene claude && claude mcp get premiere-pro >/dev/null 2>&1 && REG_CODE=true
CFG="$(config_claude_app)"
[[ -f "$CFG" ]] && grep -q '"premiere-pro"' "$CFG" 2>/dev/null && REG_APP=true
$REG_CODE && ok "Conector registrado en Claude Code" || { falta "Registro en Claude Code"; FALTANTES+=("reg"); }
if tiene_claude_app; then
  $REG_APP && ok "Conector en el archivo de la app de Claude" \
           || info "el conector no está en el archivo de la app de Claude (se intenta, pero la app puede reescribirlo)"
fi

echo
N=${#FALTANTES[@]}
if [[ $N -eq 0 ]]; then
  bold "Todo está en su lugar."
elif [[ $N -eq 1 ]]; then
  info "Falta 1 cosa. Se instala a continuación."
else
  info "Faltan $N cosas. Se instalan a continuación."
fi

if $SOLO_AUDITAR; then
  echo; info "Modo auditoría: no se instaló nada."; echo; exit 0
fi
[[ ${#FALTANTES[@]} -eq 0 ]] || true

# ═══════════════════════════════════════════════════════ 2. PREMIERE CERRADO

necesita_cep=false
for f in "${FALTANTES[@]:-}"; do [[ "$f" == "cep" ]] && necesita_cep=true; done

if $necesita_cep && premiere_abierto; then
  paso "2. Premiere tiene que estar cerrado"
  info "el conector se copia dentro de Premiere, y con la app abierta no lo toma"
  warn "Cierra Adobe Premiere Pro (⌘Q). Te espero."

  # Solo se espera cuando hay una terminal de verdad detrás. Sin ella (una
  # tubería, un cron) colgarse dos minutos en silencio es peor que seguir.
  if [[ -t 0 ]]; then
    intento=0
    while premiere_abierto && [[ $intento -lt 5 ]]; do
      printf '\033[90m  · dale Enter cuando lo hayas cerrado (o Ctrl-C para salir)\033[0m\n'
      read -r _ || break
      premiere_abierto && warn "todavía lo veo abierto"
      intento=$((intento+1))
    done
  fi

  if premiere_abierto; then
    warn "sigue abierto: se instala todo lo demás y se salta el conector de Premiere"
    info "cuando lo cierres, corre otra vez el instalador y solo hará ese paso"
    necesita_cep=false
  else
    ok "cerrado"
  fi
fi

# ═══════════════════════════════════════════════════════ 3. INSTALACIÓN

paso "3. Instalando lo que falta"

if ! node_sirve; then
  info "instalando Node.js (un par de minutos)..."
  instalar_node && ok "Node.js v$(node_version)" || morir "No pude instalar Node.js.
Instálalo desde https://nodejs.org (versión LTS) y vuelve a correr el instalador."
  persistir_ruta
fi

if ! tiene claude; then
  info "instalando Claude Code..."
  instalar_claude && ok "Claude Code" \
    || warn "no pude instalar Claude Code; hazlo después con: curl -fsSL https://claude.ai/install.sh | bash"
  persistir_ruta
fi

if ! cli_mcp >/dev/null || [[ -n "${V_NPM:-}" && "${V_LOCAL:-}" != "${V_NPM:-}" ]]; then
  info "instalando el servidor MCP..."
  instalar_mcp >/dev/null 2>&1
  cli_mcp >/dev/null && ok "Servidor MCP v$(version_mcp)" \
    || morir "No pude instalar $PAQUETE. Revisa el log: $LOG"
fi
CLI="$(cli_mcp)"

if $necesita_cep && ! tiene_cep; then
  info "instalando el conector dentro de Premiere..."
  "$CLI" --install-cep >/dev/null 2>&1
  tiene_cep && ok "Conector instalado en Premiere" \
    || warn "no quedó instalado; corre a mano: $CLI --install-cep"
fi

if ! debug_cep_activo; then
  activar_debug_cep && ok "Modo desarrollador de Adobe activado" \
    || warn "no pude activar PlayerDebugMode; Premiere no cargará la extensión"
fi

# ═══════════════════════════════════════════════════════ 4. REGISTRO EN CLAUDE

paso "4. Registrando el conector en Claude"

if tiene claude; then
  if claude mcp get premiere-pro >/dev/null 2>&1; then
    ok "Claude Code (ya estaba)"
  else
    claude mcp add premiere-pro --scope user -- "$CLI" >/dev/null 2>&1 \
      && ok "Claude Code" || warn "no pude registrarlo en Claude Code"
  fi
fi

if $TOCAR_APP && tiene_claude_app && ! $REG_APP; then
  mkdir -p "$(dirname "$CFG")"
  [[ -f "$CFG" ]] || echo '{}' > "$CFG"
  cp "$CFG" "$CFG.bak.$(date +%Y%m%d-%H%M%S)"
  if node -e '
      const fs=require("fs");
      const [p,cli]=process.argv.slice(1);
      let c={}; try { c=JSON.parse(fs.readFileSync(p,"utf8")||"{}"); } catch(e) { c={}; }
      c.mcpServers=c.mcpServers||{};
      c.mcpServers["premiere-pro"]={command:cli,args:[]};
      fs.writeFileSync(p, JSON.stringify(c,null,2));
    ' "$CFG" "$CLI" 2>/dev/null; then
    ok "App de Claude — escrito en su archivo (respaldo guardado al lado)"
    # Verificado el 2026-09-10: algunas versiones de la app son dueñas de este
    # archivo y al reiniciar borran el bloque mcpServers completo. No es un
    # error del instalador; en ese caso el conector se activa desde la app.
    info "si al reiniciar la app no aparece, actívalo desde Configuración → Conectores"
  else
    warn "no pude editar $CFG; revísalo a mano"
  fi
fi

# ═══════════════════════════════════════════════════════ 5. VERIFICACIÓN

paso "5. Verificación"
"$CLI" --doctor 2>&1 | sed 's/^/  /' || warn "el diagnóstico reportó pendientes"

echo
PENDIENTE=false
node_sirve || { err "Node.js"; PENDIENTE=true; }
cli_mcp >/dev/null || { err "servidor MCP"; PENDIENTE=true; }
tiene_cep || { warn "el conector de Premiere no está instalado"; PENDIENTE=true; }
debug_cep_activo || { warn "el modo desarrollador de Adobe no está activo"; PENDIENTE=true; }
tiene_premiere || { warn "Premiere Pro no está en esta Mac"; PENDIENTE=true; }

if $PENDIENTE; then
  bold "Quedaron cosas pendientes (arriba)."
else
  bold "Todo listo."
fi

cat <<'FIN'

────────────────────────────────────────────────
  Lo último, y esto va a mano
────────────────────────────────────────────────

  1. Cierra Claude por completo (⌘Q) y ábrelo otra vez.
  2. Abre Premiere Pro y abre un proyecto.
     Con Premiere vacío el panel sale desactivado.
  3. Ventana → Extensiones → «MCP for Adobe Premiere Pro».
     Déjalo abierto o minimizado mientras editas: si lo
     cierras, se cae la conexión.
  4. Pruébalo pidiéndole a Claude:
     «organiza los archivos del proyecto en carpetas:
      imágenes en img, audios en audio, videos en clips»

FIN
info "Log completo: $LOG"
echo
