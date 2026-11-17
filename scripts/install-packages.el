;;; install-packages.el --- Preinstalación batch de paquetes -*- lexical-binding: t; -*-
;;
;; Uso:
;;   emacs --batch -Q -l scripts/install-packages.el
;;
;; Instala en modo batch los paquetes que usa init.el, para que el primer
;; arranque de Emacs no tenga que descargarlos de forma interactiva.

;;; Code:

(require 'package)

(setq package-archives
      '(("gnu"    . "https://elpa.gnu.org/packages/")
        ("nongnu" . "https://elpa.nongnu.org/nongnu/")
        ("melpa"  . "https://melpa.org/packages/"))
      package-archive-priorities
      '(("gnu" . 10) ("nongnu" . 5) ("melpa" . 0)))

(package-initialize)

(unless package-archive-contents
  (package-refresh-contents))

(defconst my/base-packages
  '(vertico
    orderless
    corfu
    cape
    corfu-terminal
    markdown-mode
    web-mode
    typescript-mode
    go-mode
    rust-mode
    vterm)
  "Paquetes que deben estar instalados antes del primer arranque.")

(dolist (pkg my/base-packages)
  (condition-case err
      (unless (package-installed-p pkg)
        (message "Instalando %s..." pkg)
        (package-install pkg))
    (error
     (message "AVISO: no se pudo instalar %s: %s"
              pkg (error-message-string err)))))

(message "Preinstalación de paquetes finalizada.")

;;; install-packages.el ends here
