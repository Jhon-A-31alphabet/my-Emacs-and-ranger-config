#!/usr/bin/env bash
# ============================================================================
#  doctor.sh — Diagnóstico del entorno Emacs + Ranger.
# ============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Preferir el Emacs instalado por este proyecto cuando se ejecuta vía make.
if [[ -n "${PREFIX:-}" && -x "${PREFIX}/bin/emacs" ]]; then
    export PATH="${PREFIX}/bin:${PATH}"
fi

export PATH="${HOME}/.local/bin:${HOME}/.cargo/bin:${PATH}"

if [[ -z "${EMACS_DIR:-}" ]]; then
    if [[ -f "${HOME}/.config/emacs/init.el" && ! -d "${HOME}/.emacs.d" ]]; then
        EMACS_DIR="${HOME}/.config/emacs"
    else
        EMACS_DIR="${HOME}/.emacs.d"
    fi
fi

BOLD=$'\033[1m'; RED=$'\033[1;31m'; GREEN=$'\033[1;32m'
YELLOW=$'\033[1;33m'; BLUE=$'\033[1;34m'; RESET=$'\033[0m'

MISSING_REQUIRED=0
MISSING_OPTIONAL=0

section() { printf '\n%s== %s ==%s\n' "$BLUE" "$*" "$RESET"; }

check_cmd() {
    local name="$1" cmd="$2" required="${3:-no}"
    if command -v "$cmd" >/dev/null 2>&1; then
        printf '%s  ✔%s %-30s %s\n' "$GREEN" "$RESET" "$name" "$(command -v "$cmd")"
    else
        if [[ "$required" == "yes" ]]; then
            printf '%s  ✘%s %-30s FALTA (obligatorio)\n' "$RED" "$RESET" "$name"
            MISSING_REQUIRED=$((MISSING_REQUIRED + 1))
        else
            printf '%s  ✘%s %-30s no encontrado (opcional)\n' "$YELLOW" "$RESET" "$name"
            MISSING_OPTIONAL=$((MISSING_OPTIONAL + 1))
        fi
    fi
}

printf '%semacs-dev-env — diagnóstico%s\n' "$BOLD" "$RESET"

# ---------------------------------------------------------------------------
section "Base"
check_cmd "Emacs"        emacs        yes
check_cmd "emacsclient"  emacsclient  yes
check_cmd "ranger"       ranger       yes
check_cmd "git"          git          yes
check_cmd "make"         make         yes
check_cmd "gcc"          gcc          yes
check_cmd "cmake"        cmake        no
check_cmd "pkg-config"   pkg-config   no

if command -v emacs >/dev/null 2>&1; then
    printf '     versión: %s\n' "$(emacs --version | head -n1)"
fi

# ---------------------------------------------------------------------------
section "Herramientas"
check_cmd "ripgrep (rg)" rg no
if command -v fd >/dev/null 2>&1; then
    printf '%s  ✔%s %-30s %s\n' "$GREEN" "$RESET" "fd" "$(command -v fd)"
elif command -v fdfind >/dev/null 2>&1; then
    printf '%s  ✔%s %-30s %s\n' "$GREEN" "$RESET" "fd (fdfind)" "$(command -v fdfind)"
else
    printf '%s  ✘%s %-30s no encontrado (opcional)\n' "$YELLOW" "$RESET" "fd"
    MISSING_OPTIONAL=$((MISSING_OPTIONAL + 1))
fi
check_cmd "Node.js" node no
check_cmd "npm"     npm  no
check_cmd "python3" python3 no
check_cmd "pipx"    pipx no

# ---------------------------------------------------------------------------
section "Servidores LSP"
check_cmd "pyright (Python)"          pyright-langserver no
check_cmd "pylsp (Python, respaldo)"  pylsp no
check_cmd "typescript-language-server" typescript-language-server no
check_cmd "vscode-html-language-server" vscode-html-language-server no
check_cmd "vscode-css-language-server"  vscode-css-language-server no
check_cmd "clangd (C/C++)"            clangd no
check_cmd "rust-analyzer (Rust)"      rust-analyzer no
check_cmd "gopls (Go)"                gopls no
check_cmd "fortls (Fortran)"          fortls no
check_cmd "marksman (Markdown)"       marksman no

# ---------------------------------------------------------------------------
section "tree-sitter"
if pkg-config --exists tree-sitter 2>/dev/null; then
    TS_VERSION="$(pkg-config --modversion tree-sitter)"
    printf '     libtree-sitter: %s\n' "$TS_VERSION"
    if command -v emacs >/dev/null 2>&1; then
        EMACS_MAJOR="$(emacs --version | head -n1 | sed -E 's/.* ([0-9]+)\..*/\1/')"
        if [[ "$EMACS_MAJOR" =~ ^[0-9]+$ ]] && (( EMACS_MAJOR < 31 )); then
            if printf '%s\n%s\n' "0.26" "$TS_VERSION" | sort -V -C; then
                printf '%s  !%s Emacs %s.x no soporta tree-sitter >= 0.26\n' \
                    "$YELLOW" "$RESET" "$EMACS_MAJOR"
            fi
        fi
    fi
else
    printf '     libtree-sitter no instalada (opcional)\n'
fi

# ---------------------------------------------------------------------------
section "Configuración"
for file in early-init.el init.el; do
    target="${EMACS_DIR}/${file}"
    if [[ -L "$target" ]]; then
        printf '%s  ✔%s %-30s -> %s\n' "$GREEN" "$RESET" "$file" "$(readlink -f "$target")"
    elif [[ -f "$target" ]]; then
        printf '%s  ✔%s %-30s %s (archivo regular)\n' "$GREEN" "$RESET" "$file" "$target"
    else
        printf '%s  ✘%s %-30s FALTA\n' "$RED" "$RESET" "$file"
        MISSING_REQUIRED=$((MISSING_REQUIRED + 1))
    fi
done

if command -v emacsclient >/dev/null 2>&1; then
    if emacsclient -e '(emacs-pid)' >/dev/null 2>&1; then
        printf '%s  ✔%s servidor de Emacs activo (emacsclient operativo)\n' "$GREEN" "$RESET"
    else
        printf '%s  ·%s servidor de Emacs inactivo (se inicia al abrir Emacs)\n' "$YELLOW" "$RESET"
    fi
fi

VTERM_MODULE="$(find "${EMACS_DIR}/elpa" -maxdepth 2 -name 'vterm-module.so' 2>/dev/null | head -n1 || true)"
if [[ -n "$VTERM_MODULE" ]]; then
    printf '%s  ✔%s %-30s %s\n' "$GREEN" "$RESET" "vterm-module" "$VTERM_MODULE"
else
    printf '%s  ·%s %-30s no compilado aún (M-r usará ansi-term como respaldo)\n' \
        "$YELLOW" "$RESET" "vterm-module"
fi

case ":${PATH}:" in
    *":${HOME}/.local/bin:"*)
        printf '%s  ✔%s ~/.local/bin en PATH\n' "$GREEN" "$RESET" ;;
    *)
        printf '%s  !%s ~/.local/bin NO está en PATH; añádelo a ~/.bashrc\n' "$YELLOW" "$RESET" ;;
esac

# ---------------------------------------------------------------------------
section "Resumen"
if (( MISSING_REQUIRED > 0 )); then
    printf '%s  %d componente(s) obligatorio(s) faltante(s).%s\n' \
        "$RED" "$MISSING_REQUIRED" "$RESET"
    printf '     Ejecuta: make deps emacs lsp ranger config\n'
    exit 1
fi

printf '%s  Base obligatoria completa.%s\n' "$GREEN" "$RESET"
if (( MISSING_OPTIONAL > 0 )); then
    printf '%s  %d componente(s) opcional(es) no instalado(s).%s\n' \
        "$YELLOW" "$MISSING_OPTIONAL" "$RESET"
    printf '     Ejecuta: make lsp\n'
fi
printf '\n'
