# Solución de problemas

Ejecuta siempre primero:

```bash
make doctor
```

---

## 1. Emacs no encuentra `libgccjit` durante `configure`

**Síntoma**

```
configure: error: libgccjit is required for native compilation
```

**Causa**: el paquete de desarrollo de libgccjit no está instalado.

**Solución (Debian/Ubuntu)**

```bash
sudo apt install libgccjit-15-dev   # ajusta al GCC disponible
```

El script `deps.sh` busca automáticamente `libgccjit-*-dev` con la versión más
alta disponible. Si aun así falla:

```bash
make emacs NATIVE_COMP=no
```

---

## 2. Error de tree-sitter al compilar Emacs 30.x

**Síntoma**

```
treesit.c: error: implicit declaration of function 'ts_language_version'
```

**Causa**: Emacs 30.x solo soporta `libtree-sitter` ≤ 0.25.x. Las versiones
0.26+ eliminaron `ts_language_version`.

**Solución**

- `build-emacs.sh` detecta la versión y desactiva tree-sitter automáticamente
  para Emacs 30.x. Si quieres forzarlo:

```bash
make emacs WITH_TREE_SITTER=no
```

- O compila Emacs 31.1, que soporta ambas ABI:

```bash
make emacs EMACS_VERSION=31.1
```

---

## 3. `vterm` no carga o falla al compilar el módulo

**Síntoma**

```
Error (use-package): vterm/:catch: vterm module is not available
```

**Causa**: falta `cmake`, `libtool` o un compilador de C++.

**Solución**

```bash
# Debian/Ubuntu
sudo apt install cmake libtool-bin g++ libvterm-dev
# Fedora
sudo dnf install cmake libtool gcc-c++ libvterm-devel
# Arch
sudo pacman -S cmake libtool libvterm

# Recompilar el módulo desde Emacs
emacs --batch -l ~/.emacs.d/init.el --eval '(vterm-module-compile)'
```

Mientras tanto, `M-r` usa `ansi-term` como respaldo automático.

---

## 4. `emacsclient` no conecta con Emacs

**Síntoma**

```
emacsclient: can't find socket; have you started the server?
```

**Causa**: el servidor de Emacs no está iniciado.

**Solución**

- `init.el` ejecuta `(server-start)` al arrancar. Abre Emacs primero.
- Verifica manualmente:

```bash
emacs --daemon          # arranca el servidor en segundo plano
emacsclient -e '(server-version)'
```

- Si usas otra instancia de Emacs (por ejemplo, otra versión), revisa
  `server-name` y el socket en `$XDG_RUNTIME_DIR/emacs/`.

---

## 5. Ranger abre un Emacs nuevo en vez de reutilizar la sesión

**Causa**: `rifle.conf` no tiene las reglas del proyecto o `emacsclient` no
encuentra el servidor.

**Solución**

```bash
make ranger
grep -n emacsclient ~/.config/ranger/rifle.conf
```

Comprueba que `emacsclient -n -- archivo.txt` abre el archivo en la sesión
actual. Si no, revisa el punto 4.

---

## 6. `pyright` o `typescript-language-server` no aparecen en Emacs

**Causa**: Node se instaló con `nvm` y `~/.nvm/versions/node/*/bin` no está en
el `PATH` con el que se lanzó Emacs.

**Solución**: `init.el` añade automáticamente `~/.local/bin`, `~/.cargo/bin` y
las rutas de nvm al `exec-path`. Si aun así falla:

```bash
npm install -g --prefix ~/.local pyright typescript-language-server vscode-langservers-extracted
which pyright-langserver
```

Asegúrate de lanzar Emacs desde una shell que tenga Node en el `PATH`, o añade
nvm a `~/.profile`.

---

## 7. `pip install` falla con "externally-managed-environment"

**Causa**: PEP 668 en Ubuntu/Debian recientes.

**Solución**: el script usa `pipx`, que es la vía recomendada:

```bash
sudo apt install pipx
pipx install fortls
```

No uses `pip install` global para herramientas.

---

## 8. `marksman` no se descarga

**Síntoma**: error 404 o fallo de red al consultar la API de GitHub.

**Solución**: descarga manual desde
<https://github.com/artempyanykh/marksman/releases> y coloca el binario en
`~/.local/bin/marksman` con permisos de ejecución:

```bash
mkdir -p ~/.local/bin
curl -fL -o ~/.local/bin/marksman \
  https://github.com/artempyanykh/marksman/releases/latest/download/marksman-linux-x64
chmod +x ~/.local/bin/marksman
```

---

## 9. `make install` falla por permisos

**Síntoma**: `Permission denied` al escribir en `/usr/local`.

**Solución**: usa `sudo` (el Makefile lo hace por ti) o instala en tu home:

```bash
make emacs PREFIX="$HOME/.local"
```

En ese caso añade `~/.local/bin` al `PATH`.

---

## 10. La primera apertura de Emacs tarda mucho

**Causa**: instalación de paquetes de MELPA y compilación nativa de los
mismos.

**Solución**: preinstala en batch antes de abrir la interfaz:

```bash
make packages
```

Si ya abriste Emacs, espera a que termine la compilación asíncrona
(`*Async-native-compile-log*`).

---

## 11. Los números de línea o Corfu se ven mal en terminal

- Corfu necesita `corfu-terminal` en TTY; `init.el` lo activa solo cuando
  `display-graphic-p` es nil.
- Los números de línea se desactivan en `vterm`, `term`, `shell` y `eshell`.
- Si usas `tmux`, asegúrate de que el `TERM` sea `xterm-256color` o similar:

```bash
echo $TERM
export TERM=xterm-256color
```

---

## 12. Emacs instalado pero `emacs` ejecuta otra versión

**Causa**: `/usr/bin/emacs` tiene prioridad o hay otra instalación.

**Solución**

```bash
which -a emacs
/usr/local/bin/emacs --version
```

Ordena el `PATH` para que `/usr/local/bin` vaya antes que `/usr/bin`:

```bash
export PATH=/usr/local/bin:$PATH
```

---

## 13. Deshacer la configuración

`make config` guarda respaldos con marca de tiempo:

```bash
ls -l ~/.emacs.d/*.bak.*
mv ~/.emacs.d/init.el.bak.YYYYMMDD-HHMMSS ~/.emacs.d/init.el
```

Para desinstalar ranger y Emacs compilado:

```bash
cd .build/emacs-30.2 && sudo make uninstall
```
