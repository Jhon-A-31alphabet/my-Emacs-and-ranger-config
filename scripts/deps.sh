#!/usr/bin/env bash
# ============================================================================
#  deps.sh — Instala las dependencias del sistema para compilar Emacs y
#            ejecutar el entorno (Eglot, Corfu, vterm, Ranger).
#  Soporta: Debian/Ubuntu, Fedora/RHEL, Arch/Manjaro.
# ============================================================================
set -euo pipefail

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[aviso]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

if [[ ${EUID} -eq 0 ]]; then
    SUDO=()
else
    SUDO=(sudo)
fi

run_root() { "${SUDO[@]}" "$@"; }

[[ -r /etc/os-release ]] || die "No se pudo leer /etc/os-release"
# shellcheck disable=SC1091
. /etc/os-release

DISTRO_ID="${ID:-unknown}"
DISTRO_LIKE="${ID_LIKE:-}"

log "Distribución detectada: ${PRETTY_NAME:-$DISTRO_ID}"

install_debian() {
    log "Actualizando índices de APT"
    run_root env DEBIAN_FRONTEND=noninteractive apt-get update -y

    local pkgs=(
        build-essential autoconf automake texinfo pkg-config
        git curl wget ca-certificates
        libgnutls28-dev libncurses-dev libjansson-dev libtree-sitter-dev
        libxml2-dev libsqlite3-dev libgmp-dev zlib1g-dev libacl1-dev
        libvterm-dev cmake libtool-bin
        ripgrep fd-find python3-pip pipx ranger
    )

    local gccjit
    gccjit="$(apt-cache search --names-only '^libgccjit-[0-9]+-dev$' \
        | awk '{print $1}' | sort -V | tail -n1)"
    if [[ -n "$gccjit" ]]; then
        pkgs+=("$gccjit")
        log "Usando $gccjit para native-compilation"
    else
        warn "No se encontró libgccjit-*-dev; Emacs se compilará sin native-compilation"
    fi

    log "Instalando ${#pkgs[@]} paquetes con APT"
    run_root env DEBIAN_FRONTEND=noninteractive \
        apt-get install -y --no-install-recommends "${pkgs[@]}"

    if ! command -v npm >/dev/null 2>&1; then
        warn "npm no encontrado; instalando nodejs/npm del sistema"
        run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs npm
    fi
}

install_fedora() {
    local pkgs=(
        gcc gcc-c++ make autoconf automake texinfo pkgconf-pkg-config
        git curl wget ca-certificates
        gnutls-devel ncurses-devel jansson-devel tree-sitter-devel
        libxml2-devel sqlite-devel gmp-devel zlib-devel libacl-devel
        libgccjit-devel cmake libtool libvterm-devel
        ripgrep fd-find python3-pip pipx ranger
    )

    log "Instalando ${#pkgs[@]} paquetes con DNF"
    run_root dnf -y install "${pkgs[@]}"

    if ! command -v npm >/dev/null 2>&1; then
        warn "npm no encontrado; instalando nodejs/npm del sistema"
        run_root dnf -y install nodejs npm
    fi
}

install_arch() {
    local pkgs=(
        base-devel autoconf automake texinfo pkgconf
        git curl wget ca-certificates
        gnutls ncurses jansson tree-sitter libxml2 sqlite gmp zlib acl
        gccjit cmake libtool libvterm
        ripgrep fd python-pipx ranger
    )

    log "Sincronizando e instalando ${#pkgs[@]} paquetes con pacman"
    run_root pacman -Sy --needed --noconfirm "${pkgs[@]}"

    if ! command -v npm >/dev/null 2>&1; then
        warn "npm no encontrado; instalando nodejs/npm del sistema"
        run_root pacman -S --needed --noconfirm nodejs npm
    fi
}

case " ${DISTRO_ID} ${DISTRO_LIKE} " in
    *debian*|*ubuntu*|*linuxmint*|*pop*|*zorin*|*elementary*|*kali*)
        install_debian ;;
    *fedora*|*rhel*|*centos*|*rocky*|*almalinux*|*oracle*)
        install_fedora ;;
    *arch*|*manjaro*|*endeavouros*|*cachyos*)
        install_arch ;;
    *)
        die "Distribución no soportada: ${PRETTY_NAME:-$DISTRO_ID}.
Instala manualmente las dependencias de compilación de Emacs (build-essential,
autoconf, texinfo, libgnutls, libncurses, libjansson, libtree-sitter,
libxml2, libsqlite3, libgccjit, cmake, libtool, libvterm) y vuelve a ejecutar." ;;
esac

# Asegurar el directorio de binarios locales usado por npm/pipx/cargo
mkdir -p "${HOME}/.local/bin"

case ":${PATH}:" in
    *":${HOME}/.local/bin:"*) ;;
    *)
        warn "${HOME}/.local/bin no está en el PATH actual."
        warn "Añade esta línea a ~/.bashrc y ~/.profile:"
        warn '    export PATH="$HOME/.local/bin:$PATH"'
        ;;
esac

log "Dependencias del sistema listas."
