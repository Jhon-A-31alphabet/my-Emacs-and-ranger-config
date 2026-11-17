# emacs-dev-env

Entorno de desarrollo reproducible para terminal basado en **Emacs compilado
desde el código fuente**, con **Eglot + Corfu + Cape** como sistema de
autocompletado LSP, e integración nativa con **Ranger** mediante `vterm`.

El objetivo es que una máquina nueva quede exactamente igual con dos pasos:

```bash
git clone git@github.com:Jhon-A-31alphabet/my-Emacs-and-ranger-config.git emacs-dev-env
cd emacs-dev-env && make all
```

---

## Requisitos

- Linux (Debian/Ubuntu, Fedora/RHEL o Arch/Manjaro).
- `sudo` disponible (para paquetes del sistema y para instalar en `/usr/local`).
- Conexión a Internet (descarga de Emacs, paquetes ELPA/MELPA y servidores LSP).
- ~2 GB libres en disco y 30–40 minutos en la primera instalación.

La configuración está pensada para **Emacs 30.2** (por defecto) ejecutándose
en una terminal. Es compatible con Emacs 31.x; puedes cambiarlo con
`make emacs EMACS_VERSION=31.1`.

---

## Inicio rápido

```bash
# 1. Clonar (o crear el repositorio la primera vez)
git clone git@github.com:Jhon-A-31alphabet/my-Emacs-and-ranger-config.git emacs-dev-env
cd emacs-dev-env

# 2. Desplegar todo
make all

# 3. Abrir Emacs
emacs
```

`make all` ejecuta, en orden:

1. `deps` — dependencias del sistema.
2. `emacs` — descarga y compila Emacs desde la fuente.
3. `lsp` — servidores LSP de los lenguajes soportados.
4. `ranger` — ranger + `rifle.conf` integrado con `emacsclient`.
5. `config` — despliega `init.el` y `early-init.el`.
6. `packages` — preinstala paquetes ELPA/MELPA en modo batch.
7. `doctor` — diagnóstico final (no bloqueante).

---

## Targets del Makefile

| Target | Descripción |
|---|---|
| `make init-git` | Inicializa el repositorio Git y crea el commit base. |
| `make deps` | Instala dependencias de compilación y herramientas. |
| `make emacs` | Compila e instala Emacs (`EMACS_VERSION`, por defecto `30.2`). |
| `make emacs-latest` | Resuelve y compila la última versión estable de GNU. |
| `make lsp` | Instala pyright, clangd, rust-analyzer, gopls, fortls, marksman… |
| `make ranger` | Instala ranger y despliega `rifle.conf`. |
| `make config` | Enlaza `init.el` y `early-init.el` en `~/.emacs.d`. |
| `make packages` | Preinstala paquetes de Emacs sin abrir la interfaz. |
| `make doctor` | Comprueba binarios, configuración y servidor de Emacs. |
| `make all` | Flujo completo. |
| `make clean` | Borra `.build/` (fuentes, tarballs y registros). |

Variables útiles:

```bash
make emacs EMACS_VERSION=31.1      # otra versión
make emacs PREFIX="$HOME/.local"   # instalación sin sudo
make emacs JOBS=4                  # limitar paralelismo
make emacs FORCE=1                 # recompilar aunque ya exista
make emacs NATIVE_COMP=no          # sin native-compilation
make emacs WITH_TREE_SITTER=no     # sin tree-sitter
```

---

## Estructura del proyecto

```
emacs-dev-env/
├── Makefile
├── README.md
├── .gitignore
├── scripts/
│   ├── deps.sh              # dependencias por distribución
│   ├── build-emacs.sh       # descarga y compilación de Emacs
│   ├── install-lsp.sh       # servidores LSP
│   ├── install-ranger.sh    # ranger + rifle.conf
│   ├── configure-emacs.sh   # despliegue de init.el
│   ├── install-packages.el  # preinstalación batch de paquetes
│   └── doctor.sh            # diagnóstico
├── config/
│   ├── early-init.el
│   ├── init.el
│   └── ranger/
│       └── rifle.conf
└── docs/
    └── troubleshooting.md
```

---

## Servidores LSP configurados

| Lenguaje | Modo(s) | Servidor | Instalación |
|---|---|---|---|
| Markdown | `markdown-mode` | `marksman` | binario en `~/.local/bin` |
| Python | `python-mode` | `pyright-langserver` (respaldo `pylsp`) | npm / pipx |
| HTML | `web-mode`, `html-mode` | `vscode-html-language-server` | npm |
| CSS | `css-mode` | `vscode-css-language-server` | npm |
| JS / TS | `js-mode`, `typescript-mode` | `typescript-language-server` | npm |
| C / C++ | `cc-mode` | `clangd` | paquete del sistema |
| Rust | `rust-mode` | `rust-analyzer` | rustup / cargo |
| Fortran | `f90-mode` | `fortls` | pipx |
| Go | `go-mode` | `gopls` | `go install` |

Eglot arranca automáticamente al abrir un archivo de esos modos **solo si el
servidor correspondiente está instalado**. Si falta, el archivo se abre sin LSP
y `make doctor` indica qué falta.

---

## Atajos principales

| Atajo | Acción |
|---|---|
| `M-q` | Abrir/alternar **Ranger** dentro de Emacs (vterm). Sustituye a `fill-paragraph`. |
| `C-c r` | Renombrar símbolo (Eglot). |
| `C-c a` | Acciones de código (Eglot). |
| `C-c f` | Formatear buffer/región (Eglot). |
| `C-c d` | Diagnósticos de Flymake. |
| `C-c h` | Documentación en el minibúfer (Eldoc). |
| `TAB` | Aceptar candidato de Corfu. |
| `C-x C-b` | `ibuffer`. |
| `C-x <left/right>` | Deshacer/rehacer ventanas (`winner-mode`). |

Dentro de Ranger:

| Tecla | Acción |
|---|---|
| `Enter` | Abre el archivo en la **sesión actual** de Emacs (`emacsclient -n`). |
| `q` | Cerrar Ranger. |
| `S` | Abrir una shell en el directorio actual. |

---

## Cómo crear y publicar el repositorio

La primera vez, en la máquina de origen:

```bash
cd emacs-dev-env
# Identidad de Git (cámbiala por la tuya antes de publicar)
git config user.name "Tu Nombre"
git config user.email "tu@correo"

make init-git
# Opcional: publicar en tu remoto
git remote add origin git@github.com:Jhon-A-31alphabet/my-Emacs-and-ranger-config.git
git push -u origin main
```

> `make init-git` solo define una identidad local de respaldo
> (`$USER@localhost`) si no existe ninguna configurada. Revísala con
> `git config user.email` antes de publicar.

En una máquina nueva:

```bash
git clone git@github.com:Jhon-A-31alphabet/my-Emacs-and-ranger-config.git emacs-dev-env
cd emacs-dev-env
make all
```

Si actualizas el repositorio en otra máquina:

```bash
git pull
make config packages   # los enlaces simbólicos ya apuntan al repo
```

`make config` usa enlaces simbólicos: los cambios en `git pull` se reflejan
directamente en `~/.emacs.d/init.el`.

---

## Despliegue en una PC nueva (resumen)

```bash
sudo apt update && sudo apt install -y git make   # o dnf/pacman
git clone git@github.com:Jhon-A-31alphabet/my-Emacs-and-ranger-config.git emacs-dev-env
cd emacs-dev-env
make all
emacs
```

`make all` pedirá la contraseña de `sudo` para instalar paquetes y para
`make install` de Emacs en `/usr/local`.

---

## Notas sobre versiones y tree-sitter

- **Emacs 30.2** es el valor por defecto. Es la última versión 30.x estable.
- **Emacs 31.1** (agosto 2026) está disponible y es compatible con
  `libtree-sitter` 0.26+. Compílalo con `make emacs EMACS_VERSION=31.1`.
- Emacs 30.x **solo compila con tree-sitter ≤ 0.25.x**. El script detecta la
  versión instalada y, si es 0.26 o superior con Emacs 30.x, desactiva
  tree-sitter automáticamente para que la compilación no falle.
- La configuración no depende de tree-sitter: usa `cc-mode`, `f90-mode`,
  `rust-mode`, etc., y Eglot para el soporte semántico.

## Native compilation

Por defecto se compila con `--with-native-compilation=aot`, lo que produce un
Emacs más rápido a costa de una compilación más larga y de más consumo de
memoria (cada trabajo de `make -j` puede usar varios cientos de MB). Si
`libgccjit` no está disponible, el script lo detecta y compila sin
native-compilation.

En máquinas con poca RAM:

```bash
make emacs NATIVE_COMP=yes JOBS=4   # compilación nativa asíncrona
make emacs NATIVE_COMP=no           # sin compilación nativa
```

---

## Diagnóstico y solución de problemas

```bash
make doctor
```

Consulta [`docs/troubleshooting.md`](docs/troubleshooting.md) para problemas
concretos (libgccjit, vterm, emacsclient, PATH de npm/nvm, PEP 668, etc.).
