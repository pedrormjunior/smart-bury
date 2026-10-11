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

;; Loaded by `make test-interactively' (see Makefile) to set up a
;; throwaway Emacs session for manually trying out Smart Bury: enables
;; `smart-bury-mode' and `repeat-mode', adds a repeat-mode binding for
;; `smart-bury-kill-current-buffer' (see the "Repeat map" section of
;; README.md for why that one isn't included by default), creates a few
;; throwaway buffers to cycle/bury/kill through, and -- when
;; `smart-bury-test-demo-stale-entry' is non-nil -- exercises a
;; stale/invalid entry in `smart-bury-wrapped-commands' to confirm it's
;; skipped with a warning rather than breaking anything (see `M-x
;; view-echo-area-messages' or the *Warnings* buffer after startup).

;;; Code:

(defvar smart-bury-test-demo-stale-entry nil
  "When non-nil, demonstrate a stale/invalid entry in
`smart-bury-wrapped-commands' on startup (see below).  Off by default,
giving just the plain cycle/bury/kill setup; set to non-nil before
loading this file to see the demonstration.")

(load-theme 'modus-vivendi t)

(smart-bury-mode 1)
(repeat-mode 1)

(define-key smart-bury-repeat-map (kbd "M-Q") #'smart-bury-kill-current-buffer)

(dotimes (i 5)
  (generate-new-buffer (format "test-buffer-%d" (1+ i))))

(when smart-bury-test-demo-stale-entry
  ;; Simulate a stale saved Customize value referring to a
  ;; since-renamed/removed command, as would happen if a custom-file
  ;; set `smart-bury-wrapped-commands' before an upgrade dropped one
  ;; of the commands it names.  This should warn (not error) and
  ;; still leave `quit-window'/`kill-current-buffer' wrapped normally.
  (customize-set-variable
   'smart-bury-wrapped-commands
   '(quit-window a-command-that-does-not-exist kill-current-buffer))

  (message "Smart Bury: quit-window wrapped? %s | kill-current-buffer wrapped? %s | bogus entry wrapped (should be nil)? %s"
           (fboundp 'smart-bury-quit-window)
           (fboundp 'smart-bury-kill-current-buffer)
           (fboundp 'smart-bury-a-command-that-does-not-exist)))

(provide 'test-interactively)

;;; test-interactively.el ends here
