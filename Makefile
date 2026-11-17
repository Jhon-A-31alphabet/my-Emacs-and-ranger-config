# ============================================================================
#  emacs-dev-env — Entorno Emacs reproducible (Eglot + Corfu + Ranger)
# ----------------------------------------------------------------------------
#  Uso rápido:
#    make help      Muestra la ayuda
#    make all       Despliega el entorno completo en una máquina nueva
# ============================================================================

SHELL            := /bin/bash
.SHELLFLAGS      := -eu -o pipefail -c
.DEFAULT_GOAL    := help

PROJECT_DIR      := $(CURDIR)
EMACS_VERSION    ?= 30.2
NATIVE_COMP      ?= aot
WITH_TREE_SITTER ?= auto
PREFIX           ?= /usr/local
JOBS             ?= $(shell nproc 2>/dev/null || echo 2)
BUILD_DIR        ?= $(PROJECT_DIR)/.build
LOCAL_BIN        ?= $(HOME)/.local/bin

SUDO := $(shell if [ "$$(id -u)" -eq 0 ]; then echo ""; else echo sudo; fi)

# Se resuelve en tiempo de uso: tras compilar Emacs, apunta a $(PREFIX)/bin/emacs.
EMACS_BIN = $(if $(wildcard $(PREFIX)/bin/emacs),$(PREFIX)/bin/emacs,$(shell command -v emacs 2>/dev/null || echo emacs))

export EMACS_VERSION NATIVE_COMP WITH_TREE_SITTER PREFIX JOBS BUILD_DIR LOCAL_BIN SUDO

.PHONY: help all init-git deps emacs emacs-latest lsp ranger config packages doctor clean

help:
	@echo "emacs-dev-env — targets disponibles"
	@echo ""
	@echo "  make init-git      Inicializa el repositorio Git y crea el commit base"
	@echo "  make deps          Instala dependencias del sistema (apt/dnf/pacman)"
	@echo "  make emacs         Compila e instala Emacs $(EMACS_VERSION) desde fuente"
	@echo "  make emacs-latest  Compila la última versión estable publicada en GNU"
	@echo "  make lsp           Instala servidores LSP (pyright, clangd, gopls, etc.)"
	@echo "  make ranger        Instala ranger y despliega rifle.conf con emacsclient"
	@echo "  make config        Despliega early-init.el e init.el en ~/.emacs.d"
	@echo "  make packages      Preinstala paquetes ELPA/MELPA en modo batch"
	@echo "  make doctor        Diagnóstico del entorno"
	@echo "  make all           deps + emacs + lsp + ranger + config + packages + doctor"
	@echo "  make clean         Elimina artefactos de compilación (.build/)"
	@echo ""
	@echo "Variables:"
	@echo "  EMACS_VERSION=$(EMACS_VERSION)  PREFIX=$(PREFIX)  JOBS=$(JOBS)"
	@echo "  NATIVE_COMP=$(NATIVE_COMP)  WITH_TREE_SITTER=$(WITH_TREE_SITTER)"
	@echo ""
	@echo "Ejemplo: make emacs EMACS_VERSION=31.1 NATIVE_COMP=aot"

all: deps emacs lsp ranger config packages
	@echo ""
	@echo "✔ Entorno desplegado. Abre una terminal nueva y ejecuta: emacs"
	@echo "  Atajo para Ranger dentro de Emacs: M-r"
	@echo ""
	@-$(MAKE) --no-print-directory doctor

init-git:
	@if [ ! -d "$(PROJECT_DIR)/.git" ]; then \
		git init -q "$(PROJECT_DIR)"; \
		echo "Repositorio Git inicializado en $(PROJECT_DIR)"; \
	else \
		echo "El repositorio Git ya existe"; \
	fi
	@cd "$(PROJECT_DIR)" && chmod +x scripts/*.sh
	@cd "$(PROJECT_DIR)" && git config user.name >/dev/null 2>&1 || git config user.name "$${USER:-user}"
	@cd "$(PROJECT_DIR)" && git config user.email >/dev/null 2>&1 || git config user.email "$${USER:-user}@localhost"
	@git -C "$(PROJECT_DIR)" add -A
	@if git -C "$(PROJECT_DIR)" diff --cached --quiet; then \
		echo "Sin cambios nuevos que registrar"; \
	else \
		git -C "$(PROJECT_DIR)" commit -q -m "chore: entorno Emacs + Ranger reproducible"; \
		echo "Commit base creado"; \
	fi

deps:
	@echo "==> Instalando dependencias del sistema"
	@bash scripts/deps.sh

emacs:
	@bash scripts/build-emacs.sh

emacs-latest:
	@bash scripts/build-emacs.sh --latest

lsp:
	@bash scripts/install-lsp.sh

ranger:
	@bash scripts/install-ranger.sh

config:
	@bash scripts/configure-emacs.sh

packages:
	@if [ ! -x "$(EMACS_BIN)" ] && ! command -v "$(EMACS_BIN)" >/dev/null 2>&1; then \
		echo "Emacs no está instalado. Ejecuta 'make emacs' primero."; \
		exit 1; \
	fi
	@echo "==> Preinstalando paquetes ELPA/MELPA"
	@"$(EMACS_BIN)" --batch -Q -l scripts/install-packages.el

doctor:
	@bash scripts/doctor.sh

clean:
	@rm -rf "$(BUILD_DIR)"
	@echo "Artefactos de compilación eliminados"
