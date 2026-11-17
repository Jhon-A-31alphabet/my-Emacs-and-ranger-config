#!/usr/bin/env bash
# ============================================================================
#  configure-emacs.sh — Despliega early-init.el e init.el del repositorio en
#  el directorio de configuración de Emacs, con respaldo de la configuración
#  anterior. Usa enlaces simbólicos para que `git pull` actualice el entorno.
# ============================================================================
set -euo pipefail

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[aviso]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Elegir directorio de configuración respetando una configuración XDG previa.
if [[ -z "${EMACS_DIR:-}" ]]; then
    if [[ -f "${HOME}/.config/emacs/init.el" && ! -d "${HOME}/.emacs.d" ]]; then
        EMACS_DIR="${HOME}/.config/emacs"
    else
        EMACS_DIR="${HOME}/.emacs.d"
    fi
fi

for file in early-init.el init.el; do
    [[ -f "${PROJECT_DIR}/config/${file}" ]] \
        || die "Falta config/${file} en el repositorio"
done

log "Directorio de configuración: ${EMACS_DIR}"
mkdir -p "$EMACS_DIR" "${EMACS_DIR}/backups" "${EMACS_DIR}/auto-save" "${EMACS_DIR}/elpa"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

for file in early-init.el init.el; do
    source_file="${PROJECT_DIR}/config/${file}"
    target_file="${EMACS_DIR}/${file}"

    if [[ -L "$target_file" ]] \
       && [[ "$(readlink -f "$target_file")" == "$(readlink -f "$source_file")" ]]; then
        log "${file} ya está enlazado"
        continue
    fi

    if [[ -e "$target_file" || -L "$target_file" ]]; then
        mv "$target_file" "${target_file}.bak.${TIMESTAMP}"
        log "Respaldo: ${target_file}.bak.${TIMESTAMP}"
    fi

    ln -s "$source_file" "$target_file"
    log "Enlazado ${target_file} -> ${source_file}"
done

# Comprobaciones de la configuración desplegada
if ! grep -q "server-start" "${PROJECT_DIR}/config/init.el"; then
    warn "init.el no contiene server-start; emacsclient no podrá conectarse"
fi

if command -v emacs >/dev/null 2>&1; then
    EMACS_MAJOR="$(emacs --version | head -n1 | sed -E 's/.* ([0-9]+)\..*/\1/')"
    if [[ "$EMACS_MAJOR" =~ ^[0-9]+$ ]] && (( EMACS_MAJOR < 29 )); then
        warn "Emacs ${EMACS_MAJOR}.x es antiguo. La configuración apunta a Emacs 30.x."
    fi
else
    warn "emacs aún no está instalado; ejecuta 'make emacs' antes de abrir el editor."
fi

log "Configuración de Emacs desplegada."
log "Siguiente paso: ejecuta 'emacs' y espera a que se instalen los paquetes,"
log "o ejecuta 'make packages' para preinstalarlos en modo batch."
