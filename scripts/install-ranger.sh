#!/usr/bin/env bash
# ============================================================================
#  install-ranger.sh — Instala ranger y despliega la regla de rifle.conf que
#  abre archivos en la sesión actual de Emacs mediante `emacsclient -n`.
# ============================================================================
set -euo pipefail

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[aviso]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
RIFLE_BLOCK="${PROJECT_DIR}/config/ranger/rifle.conf"
RIFLE_TARGET="${HOME}/.config/ranger/rifle.conf"

[[ -f "$RIFLE_BLOCK" ]] || die "No se encontró ${RIFLE_BLOCK}"

if [[ ${EUID} -eq 0 ]]; then
    SUDO=()
else
    SUDO=(sudo)
fi

# shellcheck disable=SC1091
[[ -r /etc/os-release ]] && . /etc/os-release
DISTRO_ID="${ID:-unknown}"
DISTRO_LIKE="${ID_LIKE:-}"

# ---------------------------------------------------------------------------
# 1. Instalar ranger si falta
# ---------------------------------------------------------------------------
if command -v ranger >/dev/null 2>&1; then
    log "ranger ya está instalado ($(ranger --version 2>/dev/null | head -n1))"
else
    log "Instalando ranger"
    case " ${DISTRO_ID} ${DISTRO_LIKE} " in
        *debian*|*ubuntu*|*linuxmint*|*pop*|*zorin*|*elementary*|*kali*)
            "${SUDO[@]}" env DEBIAN_FRONTEND=noninteractive apt-get install -y ranger ;;
        *fedora*|*rhel*|*centos*|*rocky*|*almalinux*|*oracle*)
            "${SUDO[@]}" dnf -y install ranger ;;
        *arch*|*manjaro*|*endeavouros*|*cachyos*)
            "${SUDO[@]}" pacman -S --needed --noconfirm ranger ;;
        *)
            die "Instala ranger manualmente para tu distribución" ;;
    esac
fi

# ---------------------------------------------------------------------------
# 2. Preparar ~/.config/ranger/rifle.conf
# ---------------------------------------------------------------------------
mkdir -p "$(dirname "$RIFLE_TARGET")"

if [[ ! -f "$RIFLE_TARGET" ]]; then
    log "Copiando la configuración por defecto de rifle"
    ranger --copy-config=rifle >/dev/null 2>&1 || true
    [[ -f "$RIFLE_TARGET" ]] || : > "$RIFLE_TARGET"
fi

BACKUP="${RIFLE_TARGET}.bak.$(date +%Y%m%d-%H%M%S)"
cp "$RIFLE_TARGET" "$BACKUP"
log "Respaldo de rifle.conf en ${BACKUP}"

# Elimina un bloque anterior (si existe) y coloca el bloque actual al inicio.
TMP_FILE="$(mktemp)"
trap 'rm -f "$TMP_FILE"' EXIT

awk '
    /^# >>> emacs-dev-env >>>$/ { skip = 1; next }
    /^# <<< emacs-dev-env <<<$/ { skip = 0; next }
    !skip { print }
' "$RIFLE_TARGET" > "$TMP_FILE"

{
    cat "$RIFLE_BLOCK"
    echo
    cat "$TMP_FILE"
} > "$RIFLE_TARGET"

log "rifle.conf actualizado: los archivos se abrirán con emacsclient -n"
log "Reglas aplicadas:"

grep -E 'emacsclient' "$RIFLE_TARGET" | sed 's/^/    /' || true

warn "Recuerda: el servidor de Emacs debe estar activo (server-start en init.el)."
