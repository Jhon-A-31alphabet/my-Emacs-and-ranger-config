;;; init.el --- Entorno Emacs: Eglot + Corfu + Ranger -*- lexical-binding: t; -*-
;;
;; Configuración pensada para Emacs 30.x en terminal, reproducible desde
;; https://github.com/<usuario>/emacs-dev-env (o el remoto que uses).
;;
;; Secciones:
;;   1. Repositorios y paquetes
;;   2. Entorno, rendimiento y PATH
;;   3. Interfaz básica
;;   4. Minibúfer y completado (Vertico, Orderless, Corfu, Cape)
;;   5. Eglot y servidores LSP
;;   6. Modos de lenguaje
;;   7. vterm + Ranger (M-r)
;;   8. Servidor de Emacs (emacsclient)

;;; Code:

;; ---------------------------------------------------------------------------
;; 1. Repositorios y paquetes
;; ---------------------------------------------------------------------------
(require 'package)

(setq package-archives
      '(("gnu"    . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")
        ("melpa"  . "https://melpa.org/packages/"))
      package-archive-priorities
      '(("gnu" . 10) ("nongnu" . 5) ("melpa" . 0))
      package-native-compile t)

(unless package-archive-contents
  (package-refresh-contents))

(package-initialize)

(require 'use-package)
(setq use-package-always-ensure nil
      use-package-expand-minimally nil
      use-package-enable-imenu-support t)

(require 'seq)

;; ---------------------------------------------------------------------------
;; 2. Entorno, rendimiento y PATH
;; ---------------------------------------------------------------------------
(setq read-process-output-max (* 1024 1024)
      inhibit-startup-screen t
      initial-scratch-message nil
      ring-bell-function 'ignore
      use-short-answers t
      sentence-end-double-space nil
      confirm-kill-processes nil
      create-lockfiles nil
      enable-recursive-minibuffers t
      completion-ignore-case t
      read-file-name-completion-ignore-case t
      scroll-conservatively 101
      scroll-margin 2
      tab-width 4
      indent-tabs-mode nil
      fill-column 100)

;; Respaldos y autosave dentro de ~/.emacs.d
(let ((backup-dir (expand-file-name "backups" user-emacs-directory))
      (auto-dir (expand-file-name "auto-save" user-emacs-directory)))
  (make-directory backup-dir t)
  (make-directory auto-dir t)
  (setq backup-directory-alist `(("." . ,backup-dir))
        auto-save-file-name-transforms `((".*" ,(concat auto-dir "/") t))))

;; PATH: binarios instalados por npm, pipx, cargo y nvm.
(dolist (dir (append
              (list (expand-file-name "~/.local/bin")
                    (expand-file-name "~/.cargo/bin"))
              (file-expand-wildcards
               (expand-file-name "~/.nvm/versions/node/*/bin"))))
  (when (and dir (file-directory-p dir))
    (add-to-list 'exec-path dir)
    (setenv "PATH" (concat dir ":" (getenv "PATH")))))

;; Codificación UTF-8
(set-charset-priority 'unicode)
(prefer-coding-system 'utf-8)
(set-language-environment "UTF-8")

;; ---------------------------------------------------------------------------
;; 3. Interfaz básica
;; ---------------------------------------------------------------------------
(menu-bar-mode -1)
(when (fboundp 'tool-bar-mode) (tool-bar-mode -1))
(when (fboundp 'scroll-bar-mode) (scroll-bar-mode -1))

(global-display-line-numbers-mode 1)
(column-number-mode 1)
(show-paren-mode 1)
(electric-pair-mode 1)
(delete-selection-mode 1)
(xterm-mouse-mode 1)
(global-auto-revert-mode 1)
(savehist-mode 1)
(save-place-mode 1)
(recentf-mode 1)
(winner-mode 1)

(setq-default cursor-type 'bar)
(global-set-key (kbd "C-x C-b") #'ibuffer)

(defun my/disable-line-numbers ()
  "Desactiva los números de línea en buffers de terminal."
  (display-line-numbers-mode -1))

(dolist (hook '(vterm-mode-hook term-mode-hook shell-mode-hook eshell-mode-hook))
  (add-hook hook #'my/disable-line-numbers))

(use-package which-key
  :ensure nil
  :config
  (which-key-mode 1))

;; ---------------------------------------------------------------------------
;; 4. Minibúfer y completado
;; ---------------------------------------------------------------------------
(use-package vertico
  :ensure t
  :init
  (vertico-mode 1))

(use-package orderless
  :ensure t
  :custom
  (completion-styles '(orderless basic))
  (completion-category-defaults nil)
  (completion-category-overrides '((file (styles basic partial-completion)))))

(use-package corfu
  :ensure t
  :custom
  (corfu-auto t)
  (corfu-auto-delay 0.15)
  (corfu-auto-prefix 2)
  (corfu-cycle t)
  (corfu-preselect 'prompt)
  (corfu-quit-at-boundary 'separator)
  (corfu-quit-no-match 'separator)
  (corfu-preview-current nil)
  :bind
  (:map corfu-map
        ("TAB" . corfu-insert)
        ("S-TAB" . corfu-prev-line))
  :config
  (global-corfu-mode 1)
  (when (require 'corfu-popupinfo nil t)
    (corfu-popupinfo-mode 1))
  ;; En terminal no existen child frames: corfu-terminal los emula.
  (unless (display-graphic-p)
    (require 'corfu-terminal)
    (corfu-terminal-mode 1)))

(use-package cape
  :ensure t
  :init
  ;; CAPF adicionales. Eglot añade el suyo al final; cape-file y cape-keyword
  ;; solo producen candidatos cuando el contexto lo justifica.
  (add-hook 'prog-mode-hook
            (lambda ()
              (add-hook 'completion-at-point-functions #'cape-file nil t)
              (add-hook 'completion-at-point-functions #'cape-keyword nil t)))
  (add-hook 'text-mode-hook
            (lambda ()
              (add-hook 'completion-at-point-functions #'cape-dabbrev nil t))))

;; ---------------------------------------------------------------------------
;; 5. Eglot y servidores LSP
;; ---------------------------------------------------------------------------
(require 'eglot)

(setq eglot-autoshutdown t
      eglot-sync-connect 1
      eglot-connect-timeout 30
      eglot-events-buffer-size 0
      eglot-send-changes-idle-time 0.3
      eldoc-echo-area-use-multiline-p nil)

;; --- Python: pyright si existe, si no pylsp -------------------------------
(defun my/python-server-program ()
  "Devuelve el programa LSP disponible para Python."
  (cond
   ((executable-find "pyright-langserver") '("pyright-langserver" "--stdio"))
   ((executable-find "pylsp") '("pylsp"))
   (t '("pyright-langserver" "--stdio"))))

(dolist (mode '(python-mode python-ts-mode))
  (add-to-list 'eglot-server-programs
               (cons mode (my/python-server-program))))

;; --- Markdown -------------------------------------------------------------
(dolist (mode '(markdown-mode gfm-mode))
  (add-to-list 'eglot-server-programs
               (cons mode '("marksman" "server"))))

;; --- HTML / CSS / JavaScript / TypeScript ---------------------------------
(dolist (mode '(web-mode html-mode sgml-mode))
  (add-to-list 'eglot-server-programs
               (cons mode '("vscode-html-language-server" "--stdio"))))

(dolist (mode '(css-mode css-ts-mode scss-mode))
  (add-to-list 'eglot-server-programs
               (cons mode '("vscode-css-language-server" "--stdio"))))

(dolist (mode '(js-mode js-ts-mode typescript-mode typescript-ts-mode tsx-ts-mode))
  (add-to-list 'eglot-server-programs
               (cons mode '("typescript-language-server" "--stdio"))))

;; --- C / C++ --------------------------------------------------------------
(dolist (mode '(c-mode c++-mode c-ts-mode c++-ts-mode))
  (add-to-list 'eglot-server-programs
               (cons mode '("clangd"))))

;; --- Rust -----------------------------------------------------------------
(dolist (mode '(rust-mode rust-ts-mode))
  (add-to-list 'eglot-server-programs
               (cons mode '("rust-analyzer"))))

;; --- Go -------------------------------------------------------------------
(dolist (mode '(go-mode go-ts-mode))
  (add-to-list 'eglot-server-programs
               (cons mode '("gopls"))))

;; --- Fortran --------------------------------------------------------------
(dolist (mode '(f90-mode fortran-mode))
  (add-to-list 'eglot-server-programs
               (cons mode '("fortls"))))

;; --- Activación automática de Eglot ---------------------------------------
(defun my/eglot-ensure-with (&rest servers)
  "Activa `eglot-ensure' si alguno de SERVERS está instalado."
  (when (seq-some #'executable-find servers)
    (eglot-ensure)))

(defun my/eglot-python ()  (my/eglot-ensure-with "pyright-langserver" "pylsp"))
(defun my/eglot-markdown () (my/eglot-ensure-with "marksman"))
(defun my/eglot-html ()    (my/eglot-ensure-with "vscode-html-language-server"))
(defun my/eglot-css ()     (my/eglot-ensure-with "vscode-css-language-server"))
(defun my/eglot-js ()      (my/eglot-ensure-with "typescript-language-server"))
(defun my/eglot-c ()       (my/eglot-ensure-with "clangd"))
(defun my/eglot-rust ()    (my/eglot-ensure-with "rust-analyzer"))
(defun my/eglot-go ()      (my/eglot-ensure-with "gopls"))
(defun my/eglot-fortran () (my/eglot-ensure-with "fortls"))

(dolist (hook '(python-mode-hook python-ts-mode-hook))
  (add-hook hook #'my/eglot-python))

(dolist (hook '(markdown-mode-hook gfm-mode-hook))
  (add-hook hook #'my/eglot-markdown))

(dolist (hook '(web-mode-hook html-mode-hook sgml-mode-hook))
  (add-hook hook #'my/eglot-html))

(dolist (hook '(css-mode-hook css-ts-mode-hook scss-mode-hook))
  (add-hook hook #'my/eglot-css))

(dolist (hook '(js-mode-hook js-ts-mode-hook typescript-mode-hook
                typescript-ts-mode-hook tsx-ts-mode-hook))
  (add-hook hook #'my/eglot-js))

(dolist (hook '(c-mode-hook c++-mode-hook c-ts-mode-hook c++-ts-mode-hook))
  (add-hook hook #'my/eglot-c))

(dolist (hook '(rust-mode-hook rust-ts-mode-hook))
  (add-hook hook #'my/eglot-rust))

(dolist (hook '(go-mode-hook go-ts-mode-hook))
  (add-hook hook #'my/eglot-go))

(dolist (hook '(f90-mode-hook fortran-mode-hook))
  (add-hook hook #'my/eglot-fortran))

(with-eval-after-load 'eglot
  (define-key eglot-mode-map (kbd "C-c r") #'eglot-rename)
  (define-key eglot-mode-map (kbd "C-c a") #'eglot-code-actions)
  (define-key eglot-mode-map (kbd "C-c f") #'eglot-format)
  (define-key eglot-mode-map (kbd "C-c d") #'flymake-show-buffer-diagnostics)
  (define-key eglot-mode-map (kbd "C-c h") #'eldoc))

;; ---------------------------------------------------------------------------
;; 6. Modos de lenguaje
;; ---------------------------------------------------------------------------
(use-package markdown-mode
  :ensure t
  :mode ("\\.md\\'" "\\.markdown\\'"))

(use-package web-mode
  :ensure t
  :mode ("\\.html?\\'" "\\.php\\'" "\\.vue\\'" "\\.svelte\\'")
  :config
  (setq web-mode-markup-indent-offset 2
        web-mode-css-indent-offset 2
        web-mode-code-indent-offset 2
        web-mode-enable-auto-pairing nil))

(use-package typescript-mode
  :ensure t
  :mode "\\.tsx?\\'")

(use-package go-mode
  :ensure t
  :mode "\\.go\\'")

(use-package rust-mode
  :ensure t
  :mode "\\.rs\\'"
  :config
  (setq rust-format-on-save nil))

;; Fortran: f90-mode es nativo; cubrir extensiones habituales.
(dolist (pattern '("\\.f90\\'" "\\.f95\\'" "\\.f03\\'" "\\.f08\\'" "\\.F90\\'"))
  (add-to-list 'auto-mode-alist (cons pattern 'f90-mode)))

;; ---------------------------------------------------------------------------
;; 7. vterm + Ranger (M-r)
;; ---------------------------------------------------------------------------
(use-package vterm
  :ensure t
  :commands (vterm vterm-other-window)
  :custom
  (vterm-shell "/bin/bash")
  (vterm-max-scrollback 10000)
  (vterm-timer-delay 0.02)
  (vterm-kill-buffer-on-exit t))

(defvar my/ranger-buffer-name "*ranger*"
  "Nombre del buffer donde se ejecuta Ranger.")

(defun my/ranger--root ()
  "Directorio raíz del proyecto actual, o `default-directory'.
No pregunta por un proyecto cuando no hay uno activo."
  (or (when-let ((project (project-current t)))
        (project-root project))
      default-directory))

(defun my/ranger--fallback ()
  "Abre Ranger con `ansi-term' si vterm no está disponible."
  (let ((default-directory (my/ranger--root)))
    (ansi-term "/bin/bash" "ranger")
    (comint-send-string (get-buffer-process (current-buffer)) "ranger\n")))

(defun my/ranger ()
  "Abre o alterna Ranger dentro de Emacs en el directorio del proyecto.
Se invoca con M-r. Al pulsar Enter sobre un archivo, Ranger usa
`emacsclient -n' para abrirlo en esta misma sesión."
  (interactive)
  (let ((buffer (get-buffer my/ranger-buffer-name)))
    (cond
     ((and buffer (get-buffer-window buffer))
      (select-window (get-buffer-window buffer)))
     ((buffer-live-p buffer)
      (pop-to-buffer buffer))
     (t
      (let ((default-directory (my/ranger--root)))
        (condition-case err
            (progn
              (vterm my/ranger-buffer-name)
              (with-current-buffer my/ranger-buffer-name
                (vterm-send-string "ranger\n")))
          (error
           (message "vterm no disponible: %s" (error-message-string err))
           (when (get-buffer my/ranger-buffer-name)
             (kill-buffer my/ranger-buffer-name))
           (my/ranger--fallback))))))))

(global-set-key (kbd "M-r") #'my/ranger)

(add-to-list 'display-buffer-alist
             '("\\*ranger\\*" (display-buffer-same-window)))

;; ---------------------------------------------------------------------------
;; 8. Servidor de Emacs (emacsclient)
;; ---------------------------------------------------------------------------
(require 'server)
(unless (server-running-p)
  (ignore-errors (server-start)))

;;; init.el ends here
