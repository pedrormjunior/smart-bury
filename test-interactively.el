;;; test-interactively.el --- Manual testing setup for Smart Bury -*- lexical-binding: t; -*-

;;; Commentary:

;; Loaded by `make test-interactively' (see Makefile) to set up a
;; throwaway Emacs session for manually trying out Smart Bury:
;; enables `smart-bury-mode' and `repeat-mode', adds a repeat-mode
;; binding for `smart-bury-kill-current-buffer' (see README.md's
;; "Repeating with `repeat-mode'" section for why that one isn't
;; included by default), and creates a few throwaway buffers to
;; cycle/bury/kill through.

;;; Code:

(load-theme 'modus-vivendi t)

(smart-bury-mode 1)
(repeat-mode 1)

(define-key smart-bury-repeat-map (kbd "M-Q") #'smart-bury-kill-current-buffer)

(dotimes (i 5)
  (generate-new-buffer (format "test-buffer-%d" (1+ i))))

(provide 'test-interactively)

;;; test-interactively.el ends here
