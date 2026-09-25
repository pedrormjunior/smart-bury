;;; smart-bury.el --- Smartly bury, quit, and kill buffers -*- lexical-binding: t; -*-

;; Author: Pedro Ribeiro Mendes Júnior <pedrormjunior@gmail.com>
;; Keywords: convenience

;;; Commentary:

;; This file was extracted verbatim from a personal Emacs
;; configuration.  No functional changes were made during the
;; extraction.

;;; Code:

(defconst smart-bury-commands
  '(smart-bury-switch-through-buffers
    smart-bury-switch-to-other-buffer
    smart-bury-bury-buffer
    smart-bury-quit-window
    smart-bury-kill-current-buffer)
  "Commands allowed by Smart Bury without resetting configuration.")

(defvar smart-bury-counter 1
  "Hold the counter of buffer to switch to after a command.")

(defvar smart-bury-initial-buffer nil
  "Store the current buffer when the first Smart Buffer was called.")

(defcustom smart-bury-same-frame t
  "Whether to consider only recent buffers in the same frame.")

(defun smart-bury--starts-now? nil
  "Check if `last-command' was *not* one of the Smart Bury ones.
The Smart Bury commands are stored in `smart-bury-commands'.  When
`last-command' was not a Smart Bury one, set `smart-bury-initial-buffer'
to the buffer from which the first call to a Smart Buffer command
occurred."
  (let ((smart-bury-command? (seq-contains-p
                              smart-bury-commands last-command 'eq)))
    (unless smart-bury-command?
      (setq smart-bury-initial-buffer (current-buffer)))
    (not smart-bury-command?)))

(defun smart-bury--is-initial? nil
  "Check if current buffer is the initial one."
  (eq (current-buffer) smart-bury-initial-buffer))

(defun smart-bury--go-through-buffers (buffers &optional allow-current)
  "Go to through `smart-bury-counter' previous BUFFERS.
Switch to them except the last one, which is returned, instead.  When
ALLOW-CURRENT, the current buffer is accept as valid buffer for
selection."
  (cl-assert (>= smart-bury-counter 1))
  (let ((counter 0)
        buffer-selection)
    ;; Cycle through all buffers again if necessary
    (while (< counter smart-bury-counter)
      (catch 'finish
        (seq-doseq (buffer buffers)
          (when (and (not (minibufferp buffer))
                     (or (not (get-buffer-window buffer))
                         (and allow-current
                              (eq buffer (current-buffer))))
                     (not (string-match-p "^ \\*"
                                          (buffer-name buffer))))
            (push buffer buffer-selection)
            (setq counter (1+ counter))
            (when (eq counter smart-bury-counter)
              (throw 'finish nil))))))
    (cl-assert (= counter (length buffer-selection) smart-bury-counter))
    (seq-doseq (buffer (cdr buffer-selection))
      (switch-to-buffer buffer))
    (car buffer-selection)))

(defun smart-bury--run-function (func &rest r)
  "Run FUNC passing arguments in R to it.
Also, take, into account the buffer configuration."
  (let ((starts-now (smart-bury--starts-now?))
        (was-initial (smart-bury--is-initial?)))
    (apply func r)
    (when was-initial
      (setq smart-bury-counter 1))
    (if starts-now
        (when was-initial (setq smart-bury-initial-buffer
                                (current-buffer)))
      (let ((last-buf (switch-to-buffer
                       (smart-bury--go-through-buffers
                        (buffer-list (when smart-bury-same-frame
                                       (selected-frame)))
                        'allow-current))))
        (when was-initial
          (setq smart-bury-initial-buffer last-buf))))))

(defun smart-bury-switch-through-buffers nil
  "Smartly/Cumulatively switch to other buffers."
  (interactive)
  (when (or (smart-bury--starts-now?)
            (smart-bury--is-initial?))
    (setq smart-bury-counter 1))
  (switch-to-buffer
   (smart-bury--go-through-buffers (cdr (buffer-list
                                         (when smart-bury-same-frame
                                           (selected-frame))))))
  (setq smart-bury-counter (1+ smart-bury-counter)))

(defun smart-bury-switch-to-other-buffer nil
  "Smartly switch to other buffer."
  (interactive)
  (setq smart-bury-counter
        (if (or (smart-bury--starts-now?)
                (smart-bury--is-initial?))
            2
          (max 2 smart-bury-counter)))
  (smart-bury--go-through-buffers (cdr (buffer-list
                                        (when smart-bury-same-frame
                                          (selected-frame)))))
  (setq smart-bury-counter 2))

(defun smart-bury-bury-buffer (&optional buffer-or-name)
  "Smartly put buffer at the end of the list of all buffers.
Call `bury-buffer' passing BUFFER-OR-NAME to it and switch smartly to
the next buffer.

For more documentation, see `bury-buffer'."
  (interactive "P")
  (smart-bury--run-function 'bury-buffer buffer-or-name))

(defun smart-bury-quit-window (&optional kill window)
  "Smartly quit window and bury its buffer.
Call `quit-window' passing KILL and WINDOW to it and smartly switch to
the next buffer.

For more documentation, see `quit-window'."
  (interactive "P")
  (smart-bury--run-function 'quit-window kill window))

(defun smart-bury-kill-current-buffer nil
  "Smartly kill the current buffer.
Call `kill-current-buffer' and switch smartly to the next buffer.

For more documentation, see `kill-current-buffer'."
  ;; There seems to be a problem with this function.
  (interactive)
  (smart-bury--run-function 'kill-current-buffer))

(provide 'smart-bury)

;;; smart-bury.el ends here
