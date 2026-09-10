#!/bin/bash
# Arranque de una línea para Mac:
#
#   curl -fsSL https://raw.githubusercontent.com/prcontreras23/premiere-para-claude/main/instalar.sh | bash
#
# Baja el proyecto y arranca el instalador. Existe para esquivar Gatekeeper: un
# archivo bajado con el navegador queda marcado como "de internet" y macOS no lo
# ejecuta con doble clic si no está firmado. Lo que baja curl no lleva esa marca.

set -uo pipefail

REPO="prcontreras23/premiere-para-claude"
FUENTE="$HOME/premiere-para-claude-fuente"

rojo()  { printf '\033[31m%s\033[0m\n' "$*"; }
verde() { printf '\033[32m%s\033[0m\n' "$*"; }
gris()  { printf '\033[90m%s\033[0m\n' "$*"; }
morir() { echo; rojo "  ✗ $*"; echo; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || morir "Este instalador es para Mac."

echo
printf '\033[1m%s\033[0m\n' "Bajando Premiere para Claude..."
echo

rm -rf "$FUENTE"; mkdir -p "$FUENTE"
if ! curl -fsSL "https://github.com/$REPO/archive/refs/heads/main.tar.gz" | tar -xz -C "$FUENTE" --strip-components=1; then
  morir "No se pudo bajar. Revisa que tengas internet e inténtalo otra vez."
fi
chmod +x "$FUENTE/install.sh" "$FUENTE/desinstalar.sh" "$FUENTE/Instalar en Mac.command" 2>/dev/null
verde "  ✓ listo"
gris  "  archivos en $FUENTE"

# El instalador pregunta cosas (cerrar Premiere), así que se le devuelve la
# terminal como entrada: este script llega por una tubería y no tiene stdin.
#
# La prueba va dentro de un subshell para que, si /dev/tty existe pero no está
# conectada (dentro de otro proceso, en CI), el aviso de bash muera ahí y no le
# salga al usuario.
if ( exec < /dev/tty ) 2>/dev/null; then
  exec "$FUENTE/install.sh" "$@" < /dev/tty
else
  exec "$FUENTE/install.sh" "$@"
fi
