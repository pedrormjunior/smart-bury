;;; test-interactively.el --- Manual testing setup for Smart Bury -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Pedro Ribeiro Mendes Júnior

;; This file is not part of GNU Emacs.

;; This file is maintained by AI.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or (at
;; your option) any later version.

;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see
;; <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Loaded by `make test-interactively' (see Makefile), after
;; smart-bury.el, to set up a throwaway Emacs session for manually
;; trying out Smart Bury:
;;
;; - enables `smart-bury-mode' and `repeat-mode';
;; - adds a repeat-mode binding for `smart-bury-kill-current-buffer'
;;   (see the "Repeat map" section of README.md for why that one isn't
;;   included by default);
;; - creates a few throwaway buffers to cycle/bury/kill through;
;; - when `smart-bury-test-demo-stale-entry' is non-nil (the default),
;;   customizes Smart Bury's options as a saved custom-file would,
;;   including a stale/undefined entry in both
;;   `smart-bury-wrapped-commands' and `smart-bury-repeatable-commands',
;;   to confirm it is accepted without a warning or breaking anything,
;;   its wrapper only signaling a `user-error' when called (see `M-x
;;   view-echo-area-messages' after startup).

;;; Code:

(defvar smart-bury-test-demo-stale-entry t
  "Non-nil means customize Smart Bury's options on startup.
The customization includes a stale/undefined entry in
`smart-bury-wrapped-commands' and `smart-bury-repeatable-commands'
\(see below).")

(load-theme 'modus-vivendi t)

(smart-bury-mode 1)
(repeat-mode 1)

(define-key smart-bury-repeat-map (kbd "M-Q") #'smart-bury-kill-current-buffer)

(dotimes (i 5)
  (generate-new-buffer (format "test-buffer-%d" (1+ i))))

(when smart-bury-test-demo-stale-entry
  ;; Both command lists name `a-command-that-does-not-exist', simulating
  ;; a stale saved Customize value referring to a since-renamed/removed
  ;; command, as would happen if a custom-file set them before an
  ;; upgrade dropped one of the commands they name.  This should neither
  ;; warn nor error, and still leave `quit-window'/`kill-current-buffer'
  ;; wrapped normally.  `M-x smart-bury-a-command-that-does-not-exist'
  ;; then signals a `user-error'.
  (custom-set-variables
   ;; The default, set here to be flipped: non-nil also goes through
   ;; buffers shown in other windows.
   '(smart-bury-include-displayed-buffers nil)
   ;; More commands arming the repeat map than the default two.
   '(smart-bury-repeatable-commands
     '( split-window-below split-window-right
        delete-other-windows delete-window switch-to-buffer
        a-command-that-does-not-exist))
   '(smart-bury-wrapped-commands
     '(quit-window kill-current-buffer a-command-that-does-not-exist)))

  (message (concat "Smart Bury: quit-window wrapped? %s"
                   " | kill-current-buffer wrapped? %s"
                   " | bogus entry wrapped (should be t)? %s")
           (fboundp 'smart-bury-quit-window)
           (fboundp 'smart-bury-kill-current-buffer)
           (fboundp 'smart-bury-a-command-that-does-not-exist)))

(provide 'test-interactively)

;;; test-interactively.el ends here
