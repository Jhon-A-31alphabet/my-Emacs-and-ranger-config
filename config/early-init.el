;;; early-init.el --- Ajustes previos al arranque -*- lexical-binding: t; -*-
;;
;; Se carga antes que init.el y antes de la inicialización de paquetes.
;; Aquí solo van ajustes de rendimiento y de arranque.

;;; Code:

;; Reducir el trabajo del recolector de basura durante el arranque.
(setq gc-cons-threshold most-positive-fixnum
      gc-cons-percentage 0.6)

;; Evitar que el manejo de nombres de archivo penalice el arranque.
(defvar my/file-name-handler-alist file-name-handler-alist)
(setq file-name-handler-alist nil)

;; Native compilation: no bloquear el arranque por advertencias.
(setq native-comp-async-report-warnings-errors 'silent
      native-comp-jit-compilation t)

;; No cargar default.el ni paquetes de sistema que puedan alterar el entorno.
(setq inhibit-default-init t
      package-quickstart nil)

(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 64 1024 1024)
                  gc-cons-percentage 0.1
                  file-name-handler-alist my/file-name-handler-alist)))

;;; early-init.el ends here
