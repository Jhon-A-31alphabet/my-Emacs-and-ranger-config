#!/usr/bin/env bash
# ============================================================================
#  build-emacs.sh — Descarga, compila e instala Emacs desde el código fuente.
#
#  Variables:
#    EMACS_VERSION      versión a compilar (por defecto 30.2)
#    PREFIX             prefijo de instalación (por defecto /usr/local)
#    JOBS               trabajos paralelos de make (por defecto nproc)
#    BUILD_DIR          directorio de trabajo (por defecto .build/)
#    NATIVE_COMP        aot | yes | no (por defecto aot)
#    WITH_TREE_SITTER   auto | yes | no (por defecto auto)
#    FORCE              1 para recompilar aunque ya esté instalada
#
#  Uso:
#    ./build-emacs.sh
#    ./build-emacs.sh --latest
#    ./build-emacs.sh --force
# ============================================================================
set -euo pipefail

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[aviso]\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

VERSION="${EMACS_VERSION:-30.2}"
PREFIX="${PREFIX:-/usr/local}"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 2)}"
BUILD_DIR="${BUILD_DIR:-${PROJECT_DIR}/.build}"
NATIVE_COMP="${NATIVE_COMP:-aot}"
WITH_TREE_SITTER="${WITH_TREE_SITTER:-auto}"
FORCE="${FORCE:-0}"
LATEST=0

usage() {
    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --latest) LATEST=1; shift ;;
        --force|-f) FORCE=1; shift ;;
        -h|--help) usage ;;
        *) die "Opción desconocida: $1" ;;
    esac
done

# --- permisos ---------------------------------------------------------------
if [[ ${EUID} -eq 0 ]]; then
    SUDO=()
elif [[ -d "$PREFIX" && -w "$PREFIX" ]]; then
    SUDO=()
else
    SUDO=(sudo)
fi

# Compara versiones: version_ge A B  ->  A >= B
version_ge() {
    printf '%s\n%s\n' "$2" "$1" | sort -V -C
}

resolve_latest() {
    curl -fsSL --retry 3 https://ftp.gnu.org/gnu/emacs/ \
        | grep -oE 'emacs-[0-9]+(\.[0-9]+)+\.tar\.xz' \
        | sed -E 's/^emacs-(.*)\.tar\.xz$/\1/' \
        | sort -Vu \
        | tail -n1
}

if [[ "$LATEST" -eq 1 ]]; then
    log "Consultando la última versión estable en ftp.gnu.org"
    VERSION="$(resolve_latest || true)"
    [[ -n "$VERSION" ]] || die "No se pudo determinar la última versión de Emacs"
    log "Última versión estable: $VERSION"
fi

mkdir -p "$BUILD_DIR"
LOG_FILE="${BUILD_DIR}/build-emacs-${VERSION}.log"

log "Emacs ${VERSION} -> ${PREFIX} (jobs=${JOBS}, native-comp=${NATIVE_COMP})"
log "Registro completo: ${LOG_FILE}"

# Duplicar toda la salida en el archivo de registro
exec > >(tee -a "$LOG_FILE") 2>&1

# --- ¿ya está instalado? ----------------------------------------------------
if [[ "$FORCE" != "1" && -x "${PREFIX}/bin/emacs" ]]; then
    CURRENT="$("${PREFIX}/bin/emacs" --version 2>/dev/null | head -n1 || true)"
    if [[ "$CURRENT" == *"${VERSION}"* ]]; then
        log "Ya existe ${CURRENT} en ${PREFIX}/bin/emacs. Nada que hacer (usa FORCE=1 para forzar)."
        exit 0
    fi
fi

# --- compatibilidad de tree-sitter -----------------------------------------
TS_VERSION="$(pkg-config --modversion tree-sitter 2>/dev/null || true)"
if [[ "$WITH_TREE_SITTER" == "auto" ]]; then
    if [[ -z "$TS_VERSION" ]]; then
        WITH_TREE_SITTER="no"
        warn "libtree-sitter no está instalada; se compilará sin soporte tree-sitter"
    elif [[ "${VERSION%%.*}" -lt 31 ]] && version_ge "$TS_VERSION" "0.26"; then
        WITH_TREE_SITTER="no"
        warn "Emacs ${VERSION} solo soporta tree-sitter <= 0.25.x (detectado ${TS_VERSION})."
        warn "Se omitirá --with-tree-sitter. Usa EMACS_VERSION=31.1 para soporte 0.26+."
    else
        WITH_TREE_SITTER="yes"
    fi
fi
log "tree-sitter: ${WITH_TREE_SITTER} (libtree-sitter: ${TS_VERSION:-no instalada})"

# --- comprobación de native-compilation ------------------------------------
if [[ "$NATIVE_COMP" != "no" ]] && ! ls /usr/lib/gcc/*/*/libgccjit.so >/dev/null 2>&1 \
   && ! pkg-config --exists libgccjit 2>/dev/null; then
    warn "libgccjit no encontrada; se desactiva native-compilation"
    NATIVE_COMP="no"
fi

# --- descarga ---------------------------------------------------------------
TARBALL="${BUILD_DIR}/emacs-${VERSION}.tar.xz"
URL="https://ftp.gnu.org/gnu/emacs/emacs-${VERSION}.tar.xz"

if [[ ! -f "$TARBALL" ]]; then
    log "Descargando ${URL}"
    curl -fL --retry 3 --retry-delay 3 -o "${TARBALL}.part" "$URL" \
        || die "Falló la descarga de Emacs ${VERSION}"
    mv "${TARBALL}.part" "$TARBALL"
else
    log "Usando tarball ya descargado: ${TARBALL}"
fi

# --- extracción -------------------------------------------------------------
SRC_DIR="${BUILD_DIR}/emacs-${VERSION}"
log "Extrayendo fuentes en ${SRC_DIR}"
rm -rf "$SRC_DIR"
tar -xf "$TARBALL" -C "$BUILD_DIR"
[[ -d "$SRC_DIR" ]] || die "No se encontró el directorio de fuentes ${SRC_DIR}"
cd "$SRC_DIR"

# --- configuración ----------------------------------------------------------
log "Ejecutando ./autogen.sh"
./autogen.sh

CONFIGURE_FLAGS=(
    --prefix="$PREFIX"
    --without-x
    --with-native-compilation="$NATIVE_COMP"
    --with-json
    --with-gnutls
    --with-sqlite3
    --with-xml2
    --with-modules
)
if [[ "$WITH_TREE_SITTER" == "yes" ]]; then
    CONFIGURE_FLAGS+=(--with-tree-sitter)
else
    CONFIGURE_FLAGS+=(--without-tree-sitter)
fi

log "Ejecutando ./configure ${CONFIGURE_FLAGS[*]}"
if ! ./configure "${CONFIGURE_FLAGS[@]}"; then
    if [[ "$NATIVE_COMP" != "no" ]]; then
        warn "configure falló con native-compilation; reintentando sin ella"
        NATIVE_COMP="no"
        FALLBACK_FLAGS=("${CONFIGURE_FLAGS[@]}")
        for i in "${!FALLBACK_FLAGS[@]}"; do
            [[ "${FALLBACK_FLAGS[$i]}" == --with-native-compilation=* ]] \
                && FALLBACK_FLAGS[$i]="--with-native-compilation=no"
        done
        ./configure "${FALLBACK_FLAGS[@]}"
    else
        die "configure falló. Revisa ${LOG_FILE}"
    fi
fi

# --- compilación e instalación ---------------------------------------------
log "Compilando con make -j${JOBS}"
make -j"$JOBS" || die "La compilación falló. Revisa ${LOG_FILE}"

log "Instalando en ${PREFIX}"
if [[ ${#SUDO[@]} -gt 0 ]]; then
    "${SUDO[@]}" make install
else
    make install
fi

# --- verificación -----------------------------------------------------------
if [[ -x "${PREFIX}/bin/emacs" ]]; then
    INSTALLED="$("${PREFIX}/bin/emacs" --version | head -n1)"
    log "Instalado: ${INSTALLED}"
else
    die "No se encontró ${PREFIX}/bin/emacs tras la instalación"
fi

if [[ "${PREFIX}" == "/usr/local" ]]; then
    log "Asegúrate de que /usr/local/bin esté antes que /usr/bin en tu PATH."
fi

log "Compilación completada. Registro: ${LOG_FILE}"
