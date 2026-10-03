;;; test-interactively.el --- Manual testing setup for Smart Bury -*- lexical-binding: t; -*-

;;; Commentary:

;; Loaded by `make test-interactively' (see Makefile) to set up a
;; throwaway Emacs session for manually trying out Smart Bury:
;; enables `smart-bury-mode' and `repeat-mode', adds a repeat-mode
;; binding for `smart-bury-kill-current-buffer' (see README.md's
;; "Repeating with `repeat-mode'" section for why that one isn't
;; included by default), creates a few throwaway buffers to
;; cycle/bury/kill through, and -- when
;; `smart-bury-test-demo-stale-entry' is non-nil (the default) --
;; exercises a stale/invalid entry in `smart-bury-wrapped-commands'
;; to confirm it's skipped with a warning rather than breaking
;; anything (see `M-x view-echo-area-messages' or the *Warnings*
;; buffer after startup).

;;; Code:

(defvar smart-bury-test-demo-stale-entry nil
  "When non-nil, demonstrate a stale/invalid entry in
`smart-bury-wrapped-commands' on startup (see below).  Set to nil
before loading this file to skip that and just get the plain
cycle/bury/kill setup.")

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
