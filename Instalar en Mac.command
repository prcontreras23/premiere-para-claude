#!/bin/bash
# Doble clic para instalar Premiere para Claude.
# Es una envoltura de install.sh que deja la ventana abierta al terminar.

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1
chmod +x install.sh desinstalar.sh 2>/dev/null

./install.sh "$@"
CODIGO=$?

echo
if [[ $CODIGO -ne 0 ]]; then
  printf '\033[31mLa instalación se detuvo. El log está en ~/premiere-para-claude/instalacion.log\033[0m\n'
fi
printf '\033[90mPresiona Enter para cerrar esta ventana.\033[0m\n'
read -r
exit $CODIGO
