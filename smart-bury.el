;;; smart-bury.el --- Smartly bury, quit, and kill buffers -*- lexical-binding: t; -*-

;; Author: Pedro Ribeiro Mendes Júnior <pedrormjunior@gmail.com>
;; Keywords: convenience
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1"))
;; URL: https://github.com/pedrormjunior/smart-bury

;;; Commentary:

;; This file was extracted verbatim from a personal Emacs
;; configuration.  No functional changes were made during the
;; extraction.

;;; Code:

(require 'cl-lib)
(require 'seq)

(defvar smart-bury-commands
  '(smart-bury-switch-through-buffers
    smart-bury-switch-to-other-buffer
    smart-bury-bury-buffer)
  "Commands allowed by Smart Bury without resetting configuration.
Extended with each wrapper generated from `smart-bury-wrapped-commands'
whenever that variable is set.")

(defvar smart-bury-counter 1
  "Hold the counter of buffer to switch to after a command.")

(defvar smart-bury-initial-buffer nil
  "Store the current buffer when the first Smart Buffer was called.")

(defgroup smart-bury nil
  "Smartly bury, quit, and kill buffers."
  :group 'convenience)

(defcustom smart-bury-same-frame t
  "Whether to consider only recent buffers in the same frame."
  :type 'boolean
  :group 'smart-bury)

(defun smart-bury--starts-now-p nil
  "Check if `last-command' was *not* one of the Smart Bury ones.
The Smart Bury commands are stored in `smart-bury-commands'.  When
`last-command' was not a Smart Bury one, set `smart-bury-initial-buffer'
to the buffer from which the first call to a Smart Buffer command
occurred."
  (let ((smart-bury-command-p (seq-contains-p
                              smart-bury-commands last-command 'eq)))
    (unless smart-bury-command-p
      (setq smart-bury-initial-buffer (current-buffer)))
    (not smart-bury-command-p)))

(defun smart-bury--is-initial-p nil
  "Check if current buffer is the initial one."
  (eq (current-buffer) smart-bury-initial-buffer))

(defun smart-bury--go-through-buffers (buffers &optional allow-current)
  "Go to through `smart-bury-counter' previous BUFFERS.
Switch to them except the last one, which is returned, instead.  When
ALLOW-CURRENT, the current buffer is accept as valid buffer for
selection.

When `smart-bury-counter' exceeds the number of eligible buffers,
wrap around and cycle through them again, switching through every
eligible buffer once per lap.  Signal a `user-error' when there are
no eligible buffers to cycle through at all, instead of looping
forever chasing a target that can never be reached."
  (cl-assert (>= smart-bury-counter 1))
  (let ((eligible (seq-filter
                   (lambda (buffer)
                     (and (not (minibufferp buffer))
                          (or (not (get-buffer-window buffer))
                              (and allow-current
                                   (eq buffer (current-buffer))))
                          (not (string-match-p "^ \\*"
                                               (buffer-name buffer)))))
                   buffers)))
    (when (null eligible)
      (user-error "Smart Bury: no eligible buffer to switch to"))
    (let ((counter 0)
          buffer-selection)
      ;; Cycle through all eligible buffers again if necessary.  Since
      ;; ELIGIBLE is non-empty, every lap makes progress, so this
      ;; always terminates within `smart-bury-counter' laps.
      (while (< counter smart-bury-counter)
        (catch 'finish
          (seq-doseq (buffer eligible)
            (push buffer buffer-selection)
            (setq counter (1+ counter))
            (when (eq counter smart-bury-counter)
              (throw 'finish nil)))))
      (cl-assert (= counter (length buffer-selection) smart-bury-counter))
      (seq-doseq (buffer (cdr buffer-selection))
        (switch-to-buffer buffer))
      (car buffer-selection))))

(defun smart-bury--run-function (func &rest r)
  "Run FUNC passing arguments in R to it.
Also, take, into account the buffer configuration."
  (let ((starts-now (smart-bury--starts-now-p))
        (was-initial (smart-bury--is-initial-p)))
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
  (when (or (smart-bury--starts-now-p)
            (smart-bury--is-initial-p))
    (setq smart-bury-counter 1))
  (switch-to-buffer
   (smart-bury--go-through-buffers (cdr (buffer-list
                                         (when smart-bury-same-frame
                                           (selected-frame))))))
  (when (called-interactively-p 'interactive)
    (message "Smart Bury: buffer %d — %s" smart-bury-counter (buffer-name)))
  (setq smart-bury-counter (1+ smart-bury-counter)))

(defun smart-bury-switch-to-other-buffer nil
  "Smartly switch to the other buffer.
Switches to the buffer the user was in when the current Smart Bury
sequence began (`smart-bury-initial-buffer').  If already back on
that buffer -- either because this starts a fresh sequence, or
because the user switched back to it already -- switches instead to
the \"other\" buffer, the next most recently used one.  Calling this
repeatedly therefore alternates back and forth between the two."
  (interactive)
  (setq smart-bury-counter
        (if (or (smart-bury--starts-now-p)
                (smart-bury--is-initial-p))
            2
          (max 2 smart-bury-counter)))
  (smart-bury--go-through-buffers (cdr (buffer-list
                                        (when smart-bury-same-frame
                                          (selected-frame)))))
  (when (called-interactively-p 'interactive)
    (message "Smart Bury: switched to %s" (buffer-name)))
  (setq smart-bury-counter 2))

(defun smart-bury-bury-buffer (&optional buffer-or-name)
  "Smartly put buffer at the end of the list of all buffers.
Call `bury-buffer' passing BUFFER-OR-NAME to it and switch smartly to
the next buffer.

For more documentation, see `bury-buffer'."
  (interactive "P")
  (smart-bury--run-function 'bury-buffer buffer-or-name)
  (when (called-interactively-p 'interactive)
    (message "Smart Bury: buried, now at %s" (buffer-name))))

(defun smart-bury--wrapper-name (fn)
  "Return the symbol `smart-bury-FN' for vanilla command FN."
  (intern (format "smart-bury-%s" fn)))

(defun smart-bury--define-wrapper (fn)
  "Define `smart-bury-FN', an interactive command that smartly wraps
the vanilla command FN via `smart-bury--run-function', cycling
through recently-used buffers afterward the same way
`smart-bury-bury-buffer' does.

FN's own `interactive' spec is reused verbatim, so the wrapper
accepts whatever arguments FN itself would (e.g. `quit-window's
prefix-arg-driven KILL/WINDOW)."
  (let* ((name (smart-bury--wrapper-name fn))
         (iform (or (interactive-form fn)
                    (error "`%s' is not an interactive command" fn))))
    (defalias name
      (eval
       `(lambda (&rest args)
          ,iform
          (apply #'smart-bury--run-function ',fn args)
          (when (called-interactively-p 'interactive)
            (message "Smart Bury: ran `%s', now at %s" ',fn (buffer-name))))
       t)
      (format "Smartly call `%s' and switch to the next buffer.\n\nFor more documentation, see `%s'." fn fn))))

(defvar smart-bury--mode-map-base
  (let ((map (make-sparse-keymap)))
    (define-key map [remap bury-buffer] #'smart-bury-bury-buffer)
    (define-key map (kbd "C-x M--") #'bury-buffer)
    (define-key map (kbd "C-x _") #'smart-bury-switch-through-buffers)
    (define-key map (kbd "C-x M-_") #'smart-bury-switch-to-other-buffer)
    map)
  "Fixed entries of `smart-bury-mode-map', unaffected by
`smart-bury-wrapped-commands'.")

(defvar smart-bury-mode-map (copy-keymap smart-bury--mode-map-base)
  "Keymap for `smart-bury-mode'.
Rebuilt in place (same object -- see `smart-bury--set-wrapped-commands')
from `smart-bury--mode-map-base' plus a remap entry per
`smart-bury-wrapped-commands' entry, every time that variable is set.
`define-minor-mode' captures this keymap by value, not by live symbol
lookup, so it must be mutated rather than reassigned to stay in
effect once `smart-bury-mode' is already enabled.")

;;;###autoload
(define-minor-mode smart-bury-mode
  "Globally remap `bury-buffer', `quit-window', and
`kill-current-buffer' to their Smart Bury equivalents, and bind
`smart-bury-switch-through-buffers' and
`smart-bury-switch-to-other-buffer'.

See `smart-bury-mode-map' for the bindings, and customize it (e.g.
via `define-key') before or after enabling the mode to change them."
  :global t
  :group 'smart-bury
  :keymap smart-bury-mode-map)

(defvar smart-bury-repeat-map
  (let ((map (make-sparse-keymap)))
    (define-key map "_" #'smart-bury-switch-through-buffers)
    (define-key map (kbd "M-_") #'smart-bury-switch-to-other-buffer)
    (define-key map (kbd "M--") #'smart-bury-bury-buffer)
    map)
  "Keymap letting `repeat-mode' repeat Smart Bury's commands with a
single key once invoked.

Every Smart Bury command, including each one generated from
`smart-bury-wrapped-commands', sets `repeat-check-key' to `no', so
this map arms regardless of which key actually invoked the
command -- notably commands like `smart-bury-quit-window' and
`smart-bury-kill-current-buffer', which only reach the user via a
remap of whatever key `quit-window'/`kill-current-buffer' are bound
to (e.g. \"q\" in many read-only modes), and so have no fixed \"last
key\" of their own to require.  None of the wrapped commands get a
default binding in this map; add one yourself (and bind the matching
vanilla command, if needed) to make it repeatable with that key.

This has no effect unless the user has enabled `repeat-mode'
themselves; `smart-bury-mode' does not turn it on.")

(dolist (command '(smart-bury-switch-through-buffers
                   smart-bury-switch-to-other-buffer
                   smart-bury-bury-buffer))
  (put command 'repeat-map 'smart-bury-repeat-map)
  (put command 'repeat-check-key 'no))

(defun smart-bury--set-wrapped-commands (symbol value)
  "Regenerate the wrapper commands, `smart-bury-commands', and
`smart-bury-mode-map' to match VALUE.

Any entry in VALUE that isn't a usable interactive command (e.g.
undefined -- as can happen with a stale saved Customize value
referring to a command from a since-updated or removed dependency,
evaluated only once `smart-bury.el' itself finally loads -- or a
plain non-interactive function) is skipped with a warning rather
than erroring: failing to wrap one stale entry is no reason to break
the rest of this variable, or abort whatever `require'd this file in
the first place."
  (set-default symbol value)
  (let ((valid (seq-filter (lambda (fn)
                             (or (interactive-form fn)
                                 (progn
                                   (display-warning
                                    'smart-bury
                                    (format "`%s' is not an interactive command; not wrapping it" fn)
                                    :warning)
                                   nil)))
                           value)))
    (setq smart-bury-commands
          (append '(smart-bury-switch-through-buffers
                     smart-bury-switch-to-other-buffer
                     smart-bury-bury-buffer)
                  (mapcar #'smart-bury--wrapper-name valid)))
    ;; `define-minor-mode' captured `smart-bury-mode-map' by value, not
    ;; by live symbol lookup, so if the mode is already enabled, only
    ;; mutating this same keymap OBJECT (not reassigning the variable
    ;; to a new one) keeps the change in effect.  Rebuilding fresh from
    ;; `smart-bury--mode-map-base' each time (rather than layering onto
    ;; whatever `smart-bury-mode-map' currently holds) ensures a
    ;; command removed from VALID loses its remap instead of it
    ;; lingering from a previous call.
    (let ((fresh (copy-keymap smart-bury--mode-map-base)))
      (dolist (fn valid)
        (define-key fresh (vector 'remap fn) (smart-bury--wrapper-name fn)))
      (setcdr smart-bury-mode-map (cdr fresh)))
    (dolist (fn valid)
      (smart-bury--define-wrapper fn)
      (put (smart-bury--wrapper-name fn) 'repeat-map 'smart-bury-repeat-map)
      (put (smart-bury--wrapper-name fn) 'repeat-check-key 'no))))

(defcustom smart-bury-wrapped-commands '(quit-window kill-current-buffer)
  "Vanilla commands to generate a `smart-bury-FN' wrapper for.
`smart-bury-bury-buffer' is defined separately (it has its own
default keybinding in `smart-bury-mode-map') and is not part of this
list.  Setting this variable (e.g. via `setopt' or Customize)
regenerates the wrapper commands and keeps `smart-bury-commands',
`smart-bury-mode-map', and `smart-bury-repeat-map' in sync."
  :type '(repeat function)
  :group 'smart-bury
  :set #'smart-bury--set-wrapped-commands)

(provide 'smart-bury)

;;; smart-bury.el ends here
