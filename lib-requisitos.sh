#!/bin/bash
# Requisitos de Premiere para Claude en macOS: Node.js y Claude Code.
#
# Adaptado de logos-para-claude. No depende de Homebrew: lo usa si está y
# funciona, y si no cae a los instaladores oficiales, que se extraen dentro de
# la carpeta del usuario y no piden contraseña de administrador.
#
# Lo cargan install.sh e "Instalar en Mac.command".

# El servidor pide Node 20.19+, pero una de sus dependencias (posthog-node)
# exige ^20.20 || >=22.22. Con menos que eso funciona, pero npm avisa.
NODE_MIN_MAYOR=20
NODE_MIN_MENOR=19

ruta_extendida() {
  local extra=(
    "$HOME/.local/bin"
    "$HOME/.local/node/bin"
    "/opt/homebrew/bin"
    "/usr/local/bin"
  )
  local d
  for d in "${extra[@]}"; do
    [[ -d "$d" && ":$PATH:" != *":$d:"* ]] && PATH="$d:$PATH"
  done
  export PATH
}

tiene() { command -v "$1" >/dev/null 2>&1; }

cargar_brew() {
  # PPC_SIN_BREW=1 fuerza los instaladores oficiales aunque haya Homebrew.
  [[ -n "${PPC_SIN_BREW:-}" ]] && return 1
  tiene brew && return 0
  local b
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [[ -x "$b" ]]; then
      eval "$("$b" shellenv)" 2>/dev/null
      return 0
    fi
  done
  return 1
}

_probar_brew() {
  cargar_brew || return 1
  brew install "$1" >/dev/null 2>&1 || return 1
  ruta_extendida
  return 0
}

# ------------------------------------------------------------------ Node.js

node_version() { node -p 'process.versions.node' 2>/dev/null; }

node_sirve() {
  tiene node || return 1
  local v mayor menor
  v="$(node_version)"; [[ -n "$v" ]] || return 1
  mayor="${v%%.*}"; menor="${v#*.}"; menor="${menor%%.*}"
  [[ "$mayor" -gt "$NODE_MIN_MAYOR" ]] && return 0
  [[ "$mayor" -eq "$NODE_MIN_MAYOR" && "$menor" -ge "$NODE_MIN_MENOR" ]]
}

# Cierto cuando el Node instalado sirve pero es viejo para posthog-node, que es
# lo que hace que npm imprima EBADENGINE. No impide nada, solo se avisa.
node_avisa_ebadengine() {
  node_sirve || return 1
  local v mayor menor
  v="$(node_version)"
  mayor="${v%%.*}"; menor="${v#*.}"; menor="${menor%%.*}"
  if [[ "$mayor" -eq 20 ]]; then [[ "$menor" -lt 20 ]] && return 0; return 1; fi
  if [[ "$mayor" -eq 21 ]]; then return 0; fi
  if [[ "$mayor" -eq 22 ]]; then [[ "$menor" -lt 22 ]] && return 0; return 1; fi
  return 1
}

instalar_node() {
  ruta_extendida
  node_sirve && return 0

  _probar_brew node && { node_sirve && return 0; }

  # Tarball oficial de nodejs.org (última LTS), extraído en ~/.local/node.
  # index.tab es una tabla separada por tabuladores; la columna 10 es "lts"
  # ("-" cuando la versión no es LTS). Se evita python3 a propósito: en una
  # Mac sin Command Line Tools, /usr/bin/python3 dispara su instalador.
  local arch version url tmp
  arch="$(uname -m)"; [[ "$arch" == "arm64" ]] && arch="arm64" || arch="x64"
  version="$(curl -fsSL --max-time 30 https://nodejs.org/dist/index.tab 2>/dev/null | awk -F'\t' 'NR>1 && $10!="-" {print $1; exit}')"
  [[ -z "$version" ]] && return 1
  url="https://nodejs.org/dist/$version/node-$version-darwin-$arch.tar.gz"
  tmp="$(mktemp -d)"
  curl -fsSL --max-time 600 "$url" -o "$tmp/node.tgz" 2>/dev/null || { rm -rf "$tmp"; return 1; }
  rm -rf "$HOME/.local/node"; mkdir -p "$HOME/.local/node"
  tar -xzf "$tmp/node.tgz" -C "$HOME/.local/node" --strip-components=1 || { rm -rf "$tmp"; return 1; }
  rm -rf "$tmp"
  ruta_extendida
  node_sirve
}

# ------------------------------------------------------------------ Claude

instalar_claude() {
  ruta_extendida
  tiene claude && return 0
  curl -fsSL https://claude.ai/install.sh 2>/dev/null | bash >/dev/null 2>&1
  ruta_extendida
  tiene claude
}

tiene_claude_app() { [[ -d "/Applications/Claude.app" || -d "$HOME/Applications/Claude.app" ]]; }

config_claude_app() { echo "$HOME/Library/Application Support/Claude/claude_desktop_config.json"; }

# ------------------------------------------------------------------ Premiere Pro

# Premiere no se puede instalar desde aquí: viene por Creative Cloud y es de pago.

# Todas las instalaciones encontradas, una por línea. Puede haber varias a la
# vez (la versión del año y la Beta conviven en /Applications).
rutas_premiere() {
  local d encontradas=0
  for d in /Applications/Adobe\ Premiere\ Pro*/Adobe\ Premiere\ Pro*.app \
           /Applications/Adobe\ Premiere\ Pro*.app; do
    [[ -d "$d" ]] && { echo "$d"; encontradas=1; }
  done
  [[ "$encontradas" -eq 1 ]]
}

# La instalación "de verdad": la del año más alto. La Beta se ignora aquí porque
# usa su propia carpeta de extensiones y no es la que la gente edita a diario.
ruta_premiere() {
  local elegida="" anio mejor=0 d
  while IFS= read -r d; do
    [[ -n "$d" ]] || continue
    case "$d" in *Beta*) continue ;; esac
    anio="$(printf '%s' "$d" | grep -oE '[0-9]{4}' | head -1)"
    anio="${anio:-1}"
    if [[ "$anio" -ge "$mejor" ]]; then mejor="$anio"; elegida="$d"; fi
  done < <(rutas_premiere)
  # Si solo hay Beta, se usa esa antes que decir que no hay nada.
  [[ -z "$elegida" ]] && elegida="$(rutas_premiere | head -1)"
  [[ -n "$elegida" ]] || return 1
  echo "$elegida"
}

tiene_premiere() { ruta_premiere >/dev/null 2>&1; }

# Devuelve algo legible siempre: "2026", "(Beta)" o el nombre de la carpeta.
version_premiere() {
  local app anio; app="$(ruta_premiere)" || return 1
  anio="$(printf '%s' "$app" | grep -oE '[0-9]{4}' | head -1)"
  if [[ -n "$anio" ]]; then echo "$anio"; return 0; fi
  case "$app" in *Beta*) echo "(Beta)"; return 0 ;; esac
  basename "$app" .app
}

tiene_premiere_beta() { rutas_premiere | grep -q Beta; }

premiere_abierto() { pgrep -qf "Adobe Premiere Pro"; }

carpeta_cep() { echo "$HOME/Library/Application Support/Adobe/CEP/extensions/MCPBridgeCEP"; }

tiene_cep() { [[ -f "$(carpeta_cep)/CSXS/manifest.xml" ]]; }

# El modo desarrollador de Adobe: sin esto Premiere no carga una extensión sin firmar.
debug_cep_activo() {
  local v
  for v in 11 12 13 14; do
    [[ "$(defaults read "com.adobe.CSXS.$v" PlayerDebugMode 2>/dev/null)" == "1" ]] && return 0
  done
  return 1
}

activar_debug_cep() {
  local v
  for v in 8 9 10 11 12 13 14; do
    defaults write "com.adobe.CSXS.$v" PlayerDebugMode 1 2>/dev/null
  done
  debug_cep_activo
}

# ------------------------------------------------------------------ El servidor MCP

PAQUETE="premiere-pro-mcp"

cli_mcp() {
  local c
  for c in "$(command -v premiere-pro-mcp 2>/dev/null)" \
           "$HOME/.local/bin/premiere-pro-mcp" \
           "$HOME/.local/node/bin/premiere-pro-mcp" \
           /opt/homebrew/bin/premiere-pro-mcp \
           /usr/local/bin/premiere-pro-mcp; do
    [[ -n "$c" && -x "$c" ]] && { echo "$c"; return 0; }
  done
  return 1
}

version_mcp() { local c; c="$(cli_mcp)" || return 1; "$c" --version 2>/dev/null | tr -d '\r'; }

version_mcp_publicada() {
  curl -fsSL --max-time 20 "https://registry.npmjs.org/$PAQUETE/latest" 2>/dev/null \
    | sed -n 's/.*"version":"\([^"]*\)".*/\1/p' | head -1
}

# Instala el paquete global. Si el prefijo de npm no es escribible (típico en un
# Node de sistema), reintenta contra ~/.local para no pedir contraseña.
instalar_mcp() {
  ruta_extendida
  npm install -g "$PAQUETE" 2>&1 && { cli_mcp >/dev/null && return 0; }
  npm install -g --prefix "$HOME/.local" "$PAQUETE" 2>&1 || return 1
  ruta_extendida
  cli_mcp >/dev/null
}

# ------------------------------------------------------------------ PATH persistente

persistir_ruta() {
  local rc="$HOME/.zshrc"
  [[ "${SHELL:-}" == *bash* ]] && rc="$HOME/.bash_profile"
  local linea='export PATH="$HOME/.local/bin:$HOME/.local/node/bin:$PATH"'
  grep -qsF '.local/node/bin' "$rc" || echo "$linea" >> "$rc"
}
