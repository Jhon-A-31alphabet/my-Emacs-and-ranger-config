#!/usr/bin/env bash
# ============================================================================
#  install-lsp.sh — Instala los servidores LSP usados por Eglot:
#    Markdown   -> marksman
#    Python     -> pyright (o pylsp como respaldo)
#    HTML/CSS   -> vscode-html-language-server / vscode-css-language-server
#    JS/TS      -> typescript-language-server
#    C/C++      -> clangd
#    Rust       -> rust-analyzer
#    Fortran    -> fortls
#    Go         -> gopls
# ============================================================================
set -uo pipefail

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  ✔\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[aviso]\033[0m %s\n' "$*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

LOCAL_BIN="${LOCAL_BIN:-${HOME}/.local/bin}"
export LOCAL_BIN
export PATH="${LOCAL_BIN}:${HOME}/.cargo/bin:${PATH}"

mkdir -p "$LOCAL_BIN"

if [[ ${EUID} -eq 0 ]]; then
    SUDO=()
else
    SUDO=(sudo)
fi
run_root() { "${SUDO[@]}" "$@"; }

# shellcheck disable=SC1091
[[ -r /etc/os-release ]] && . /etc/os-release
DISTRO_ID="${ID:-unknown}"
DISTRO_LIKE="${ID_LIKE:-}"

install_pkg() {
    # install_pkg <debian> <fedora> <arch>
    case " ${DISTRO_ID} ${DISTRO_LIKE} " in
        *debian*|*ubuntu*|*linuxmint*|*pop*|*zorin*|*elementary*|*kali*)
            run_root env DEBIAN_FRONTEND=noninteractive apt-get install -y "$1" ;;
        *fedora*|*rhel*|*centos*|*rocky*|*almalinux*|*oracle*)
            run_root dnf -y install "$2" ;;
        *arch*|*manjaro*|*endeavouros*|*cachyos*)
            run_root pacman -S --needed --noconfirm "$3" ;;
        *)
            return 1 ;;
    esac
}

# ---------------------------------------------------------------------------
# 1. Paquetes de npm (se instalan en ~/.local para no requerir sudo)
# ---------------------------------------------------------------------------
if command -v npm >/dev/null 2>&1; then
    log "Instalando servidores LSP de npm en ${LOCAL_BIN}"
    if npm install -g --prefix "$HOME/.local" --no-fund --no-audit \
        pyright typescript-language-server vscode-langservers-extracted; then
        ok "pyright, typescript-language-server y vscode-langservers-extracted"
    else
        warn "Falló la instalación de paquetes npm; revisa la conexión o los permisos"
    fi
else
    warn "npm no está disponible; no se instalarán pyright ni los servidores web"
fi

# ---------------------------------------------------------------------------
# 2. clangd
# ---------------------------------------------------------------------------
if command -v clangd >/dev/null 2>&1; then
    ok "clangd ya instalado"
else
    log "Instalando clangd"
    install_pkg clangd clang-tools-extra clang && ok "clangd" || warn "No se pudo instalar clangd"
fi

# ---------------------------------------------------------------------------
# 3. gopls
# ---------------------------------------------------------------------------
if command -v gopls >/dev/null 2>&1; then
    ok "gopls ya instalado"
else
    if ! command -v go >/dev/null 2>&1; then
        log "Instalando Go"
        install_pkg golang-go golang go || warn "No se pudo instalar Go"
    fi
    if command -v go >/dev/null 2>&1; then
        log "Instalando gopls en ${LOCAL_BIN}"
        GOBIN="$LOCAL_BIN" go install golang.org/x/tools/gopls@latest \
            && ok "gopls" || warn "No se pudo instalar gopls"
    else
        warn "gopls omitido: Go no está disponible"
    fi
fi

# ---------------------------------------------------------------------------
# 4. rust-analyzer
# ---------------------------------------------------------------------------
if command -v rust-analyzer >/dev/null 2>&1; then
    ok "rust-analyzer ya instalado ($(command -v rust-analyzer))"
elif command -v rustup >/dev/null 2>&1; then
    log "Instalando rust-analyzer con rustup"
    rustup component add rust-analyzer && ok "rust-analyzer" \
        || warn "No se pudo añadir el componente rust-analyzer"
else
    warn "rust-analyzer no encontrado. Instala Rust con rustup y ejecuta:"
    warn "    rustup component add rust-analyzer"
fi

# ---------------------------------------------------------------------------
# 5. fortls (Fortran)
# ---------------------------------------------------------------------------
if command -v fortls >/dev/null 2>&1; then
    ok "fortls ya instalado"
else
    if command -v pipx >/dev/null 2>&1; then
        log "Instalando fortls con pipx"
        pipx install fortls >/dev/null 2>&1 || pipx upgrade fortls >/dev/null 2>&1
        command -v fortls >/dev/null 2>&1 && ok "fortls" \
            || warn "pipx no pudo instalar fortls"
    else
        warn "pipx no disponible; intentando pip --user"
        python3 -m pip install --user --break-system-packages fortls \
            && ok "fortls" || warn "No se pudo instalar fortls"
    fi
fi

# ---------------------------------------------------------------------------
# 6. pylsp como respaldo de Python
# ---------------------------------------------------------------------------
if command -v pylsp >/dev/null 2>&1; then
    ok "pylsp ya instalado (respaldo de Python)"
elif ! command -v pyright-langserver >/dev/null 2>&1 && command -v pipx >/dev/null 2>&1; then
    log "pyright no está disponible; instalando pylsp como respaldo"
    pipx install "python-lsp-server[all]" >/dev/null 2>&1 \
        && ok "pylsp" || warn "No se pudo instalar pylsp"
fi

# ---------------------------------------------------------------------------
# 7. marksman (Markdown)
# ---------------------------------------------------------------------------
if command -v marksman >/dev/null 2>&1; then
    ok "marksman ya instalado"
else
    log "Descargando marksman"
    case "$(uname -m)" in
        x86_64|amd64)  MARKSMAN_ASSET="marksman-linux-x64" ;;
        aarch64|arm64) MARKSMAN_ASSET="marksman-linux-arm64" ;;
        *) MARKSMAN_ASSET="" ;;
    esac

    if [[ -n "$MARKSMAN_ASSET" ]]; then
        MARKSMAN_URL="$(curl -fsSL --retry 3 \
            https://api.github.com/repos/artempyanykh/marksman/releases/latest 2>/dev/null \
            | grep -oE "https://[^\"]*/${MARKSMAN_ASSET}" | head -n1 || true)"
        if [[ -n "$MARKSMAN_URL" ]] \
           && curl -fL --retry 3 -o "${LOCAL_BIN}/marksman" "$MARKSMAN_URL"; then
            chmod +x "${LOCAL_BIN}/marksman"
            ok "marksman instalado en ${LOCAL_BIN}/marksman"
        else
            warn "No se pudo descargar marksman; instálalo manualmente desde:"
            warn "    https://github.com/artempyanykh/marksman/releases"
        fi
    else
        warn "Arquitectura $(uname -m) no soportada por el binario de marksman"
    fi
fi

# ---------------------------------------------------------------------------
# Resumen
# ---------------------------------------------------------------------------
log "Resumen de servidores LSP"
MISSING=0
for cmd in pyright-langserver pylsp typescript-language-server \
           vscode-html-language-server vscode-css-language-server \
           clangd rust-analyzer gopls fortls marksman; do
    if command -v "$cmd" >/dev/null 2>&1; then
        ok "$cmd -> $(command -v "$cmd")"
    else
        printf '\033[1;33m  ✘\033[0m %s no encontrado\n' "$cmd"
        MISSING=$((MISSING + 1))
    fi
done

if [[ "$MISSING" -gt 0 ]]; then
    warn "${MISSING} servidor(es) no instalados. Revisa los avisos anteriores."
    warn "El entorno funciona igualmente; Eglot solo arrancará en los modos cubiertos."
fi

log "Instalación de LSP finalizada."
