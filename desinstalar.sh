#!/bin/bash
# Desinstala Premiere para Claude.
#
# Deja en su lugar el modo desarrollador de Adobe (PlayerDebugMode) a propósito:
# otras extensiones de Creative Cloud pueden depender de él.

#   ./desinstalar.sh              desinstala
#   PPC_ENSAYO=1 ./desinstalar.sh  dice qué haría, sin tocar nada
#
# El ensayo existe por una razón concreta: los paquetes globales de npm viven
# en el prefijo de npm, que NO se aísla poniendo otro HOME. Probar esto con un
# HOME de mentira desinstala el paquete de verdad. Pasó el 2026-09-10.

set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENSAYO="${PPC_ENSAYO:-}"

# Corre el comando en silencio, o solo lo anuncia si es un ensayo.
correr() {
  if [[ -n "$ENSAYO" ]]; then
    printf '\033[90m  … haría: %s\033[0m\n' "$*"
    return 0
  fi
  "$@" >/dev/null 2>&1
}

# Confirma algo hecho. En ensayo se calla, porque no se hizo nada.
hecho() { [[ -n "$ENSAYO" ]] || ok "$*"; }

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '\033[32m  ✓\033[0m %s\n' "$*"; }
info() { printf '\033[90m  · %s\033[0m\n' "$*"; }
warn() { printf '\033[33m  ! %s\033[0m\n' "$*"; }

source "$REPO_DIR/lib-requisitos.sh" 2>/dev/null || {
  carpeta_cep() { echo "$HOME/Library/Application Support/Adobe/CEP/extensions/MCPBridgeCEP"; }
  config_claude_app() { echo "$HOME/Library/Application Support/Claude/claude_desktop_config.json"; }
  tiene() { command -v "$1" >/dev/null 2>&1; }
  cli_mcp() { command -v premiere-pro-mcp 2>/dev/null; }
  PAQUETE="premiere-pro-mcp"
}
ruta_extendida 2>/dev/null || true

echo; bold "═══ Desinstalando Premiere para Claude ═══"; echo
[[ -n "$ENSAYO" ]] && { info "modo ensayo: no se toca nada"; echo; }

if pgrep -qf "Adobe Premiere Pro"; then
  warn "Premiere está abierto; ciérralo antes para que suelte la extensión"
fi

# El conector dentro de Premiere
CLI="$(cli_mcp || true)"
if [[ -n "$CLI" && -x "$CLI" ]]; then
  correr "$CLI" --uninstall-cep && hecho "conector de Premiere desinstalado"
fi
if [[ -d "$(carpeta_cep)" ]]; then
  correr rm -rf "$(carpeta_cep)" && hecho "carpeta de la extensión borrada"
fi

# Registro en Claude Code
if tiene claude; then
  correr claude mcp remove premiere-pro --scope user && hecho "quitado de Claude Code" \
    || info "no estaba registrado en Claude Code"
fi

# Registro en la app de Claude
CFG="$(config_claude_app)"
if [[ -f "$CFG" ]] && grep -q '"premiere-pro"' "$CFG" 2>/dev/null; then
  cp "$CFG" "$CFG.bak.$(date +%Y%m%d-%H%M%S)"
  if node -e '
      const fs=require("fs"); const p=process.argv[1];
      const c=JSON.parse(fs.readFileSync(p,"utf8"));
      if (c.mcpServers) delete c.mcpServers["premiere-pro"];
      fs.writeFileSync(p, JSON.stringify(c,null,2));
    ' "$CFG" 2>/dev/null; then
    ok "quitado de la app de Claude"
  else
    warn "no pude editar $CFG; quita el bloque \"premiere-pro\" a mano"
  fi
fi

# El paquete. Ojo: esto es global de npm, no depende del HOME.
if [[ -n "$CLI" ]]; then
  if [[ -n "$ENSAYO" ]]; then
    info "haría: npm uninstall -g $PAQUETE  (quitaría $CLI)"
  else
    npm uninstall -g "$PAQUETE" >/dev/null 2>&1 || npm uninstall -g --prefix "$HOME/.local" "$PAQUETE" >/dev/null 2>&1
    command -v premiere-pro-mcp >/dev/null 2>&1 && warn "el comando sigue en el PATH; bórralo a mano" \
      || ok "paquete $PAQUETE desinstalado"
  fi
fi

correr rm -rf "$HOME/premiere-para-claude-fuente"
echo
info "Node.js, Claude Code y el modo desarrollador de Adobe se quedan como estaban."
info "El log de instalación sigue en ~/premiere-para-claude/instalacion.log"
echo
