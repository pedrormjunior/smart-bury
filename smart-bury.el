;;; smart-bury.el --- Smartly bury, quit, and kill buffers -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Pedro Ribeiro Mendes Júnior

;; Author: Pedro Ribeiro Mendes Júnior <pedrormjunior@gmail.com>
;; Keywords: convenience
;; Version: 0.1.0
;; Package-Requires: ((emacs "27.1"))
;; URL: https://github.com/pedrormjunior/smart-bury

;; This file is not part of GNU Emacs.

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

;; Smart Bury makes switching buffers in a window a matter of a few
;; repeated key presses: bury, quit, or kill the current buffer, or go
;; through the most recently used buffers, without typing any buffer
;; name.  It is "smart" in the sense that if we go from buffer A to B
;; and immediately bury B, it takes us straight to C instead of coming
;; back to A -- B was simply on the way.
;;
;; It provides three basic commands:
;;
;; - `smart-bury-bury-buffer': like `bury-buffer', but "smart".
;; - `smart-bury-switch-through-buffers': switch to the other buffer,
;;   then to the 3rd, 4th... on successive calls, keeping the relative
;;   order of the remaining buffers.
;; - `smart-bury-switch-to-other-buffer': switch back and forth between
;;   the current and the other buffer; after switching through buffers,
;;   it returns to the original one.
;;
;; It also generates a `smart-bury-FN' wrapper for each command FN in
;; `smart-bury-wrapped-commands' (by default `quit-window' and
;; `kill-current-buffer'), which takes part in the same sequences.
;;
;; To use it, enable `smart-bury-mode', and preferably `repeat-mode':
;;
;;   (smart-bury-mode 1)
;;   (repeat-mode 1)
;;
;; The mode binds `C-x M--', `C-x _', and `C-x M-_' to the three basic
;; commands and remaps the wrapped ones.  With `repeat-mode', each
;; command can then be repeated with just `M--', `_', or `M-_'.  See
;; `smart-bury-prefix-key' and `smart-bury-keys' to change the keys, and
;; README.md for full description and examples.

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

(defun smart-bury--buffer-list nil
  "Return `buffer-list', scoped to the selected frame when
`smart-bury-same-frame' is non-nil."
  (buffer-list (when smart-bury-same-frame (selected-frame))))

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
                        (smart-bury--buffer-list)
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
   (smart-bury--go-through-buffers (cdr (smart-bury--buffer-list))))
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
  (smart-bury--go-through-buffers (cdr (smart-bury--buffer-list)))
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

(defvar smart-bury--mode-map-generated (make-sparse-keymap)
  "Package-owned parent of `smart-bury-mode-map'.
Rebuilt in place (same object -- see `smart-bury--rebuild-keymaps')
from `smart-bury-prefix-key', `smart-bury-keys', and
`smart-bury-wrapped-commands' every time one of them is set.")

(defvar smart-bury-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map smart-bury--mode-map-generated)
    map)
  "Keymap for `smart-bury-mode'.
Its own bindings belong to the user: Smart Bury never touches them.
The package's bindings live in its parent,
`smart-bury--mode-map-generated', which is rebuilt in place whenever
`smart-bury-prefix-key', `smart-bury-keys', or
`smart-bury-wrapped-commands' is set.  (`define-minor-mode' captures
this keymap by value, not by live symbol lookup, which is why the
parent is mutated rather than any keymap being reassigned.)")

;;;###autoload
(define-minor-mode smart-bury-mode
  "Globally remap `bury-buffer' and every entry of
`smart-bury-wrapped-commands' (by default `quit-window' and
`kill-current-buffer') to their Smart Bury equivalents, and bind the
commands in `smart-bury-keys' under `smart-bury-prefix-key'.

Customize those two options to change the keys.  Bindings added to
`smart-bury-mode-map' itself (e.g. via `define-key') are preserved
across any later customization."
  :global t
  :group 'smart-bury
  :keymap smart-bury-mode-map)

(defvar smart-bury--repeat-map-generated (make-sparse-keymap)
  "Package-owned parent of `smart-bury-repeat-map'.
Rebuilt in place from `smart-bury-keys' (see
`smart-bury--rebuild-keymaps').")

(defvar smart-bury-repeat-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map smart-bury--repeat-map-generated)
    map)
  "Keymap letting `repeat-mode' repeat Smart Bury's commands with a
single key once invoked.

Each command in `smart-bury-keys' is repeatable with its own key
(the one following `smart-bury-prefix-key'); those bindings live in
the parent keymap, `smart-bury--repeat-map-generated'.  Bindings
added to this keymap itself (e.g. via `define-key') belong to the
user and are preserved across any later customization.

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

(defvar smart-bury--valid-wrapped-commands nil
  "The entries of `smart-bury-wrapped-commands' that were actually
wrapped, i.e. without the invalid ones skipped with a warning.")

(defun smart-bury--rebuild-keymaps ()
  "Rebuild `smart-bury--mode-map-generated' and
`smart-bury--repeat-map-generated' in place from
`smart-bury-prefix-key', `smart-bury-keys', and
`smart-bury--valid-wrapped-commands'.

Does nothing until all of Smart Bury's options are defined: each
option's `:set' calls this function, and `custom-initialize-reset'
runs that `:set' while `smart-bury.el' is still loading, before the
options defined after it exist.  The last one defined triggers the
first full build.

An entry of `smart-bury-keys' whose key is not a single event is
skipped with a warning rather than erroring, since that key also
serves as the command's single-key repeat in
`smart-bury-repeat-map'."
  (when (and (boundp 'smart-bury-prefix-key)
             (boundp 'smart-bury-keys)
             (boundp 'smart-bury-wrapped-commands))
    (let ((mode-map (make-sparse-keymap))
          (repeat-map (make-sparse-keymap))
          (prefix (kbd smart-bury-prefix-key)))
      (define-key mode-map [remap bury-buffer] #'smart-bury-bury-buffer)
      (dolist (entry smart-bury-keys)
        (let* ((command (car entry))
               (key (cdr entry))
               (event (and (stringp key) (ignore-errors (kbd key)))))
          (if (= (length event) 1)
              (progn
                (define-key mode-map (vconcat prefix event) command)
                (define-key repeat-map event command))
            (display-warning
             'smart-bury
             (format "Key %S for `%s' is not a single key; not binding it"
                     key command)
             :warning))))
      (dolist (fn smart-bury--valid-wrapped-commands)
        (define-key mode-map (vector 'remap fn) (smart-bury--wrapper-name fn)))
      ;; Mutate the parents in place: `smart-bury-mode-map' and
      ;; `smart-bury-repeat-map' keep pointing at these same objects,
      ;; and the user's own bindings in those two maps stay untouched.
      (setcdr smart-bury--mode-map-generated (cdr mode-map))
      (setcdr smart-bury--repeat-map-generated (cdr repeat-map)))))

(defun smart-bury--set-and-rebuild (symbol value)
  "Set SYMBOL to VALUE and rebuild Smart Bury's keymaps.
Used as the `:set' function of `smart-bury-prefix-key' and
`smart-bury-keys'."
  (set-default symbol value)
  (smart-bury--rebuild-keymaps))

(defcustom smart-bury-prefix-key "C-x"
  "Prefix key for the commands in `smart-bury-keys', in `kbd' format.
May be the empty string, to bind those keys directly.  Setting this
variable (e.g. via `setopt' or Customize) updates
`smart-bury-mode-map' immediately."
  :type 'string
  :group 'smart-bury
  :set #'smart-bury--set-and-rebuild)

(defcustom smart-bury-keys
  '((smart-bury-bury-buffer            . "M--")
    (smart-bury-switch-through-buffers . "_")
    (smart-bury-switch-to-other-buffer . "M-_"))
  "Alist of (COMMAND . KEY) bound by `smart-bury-mode'.
Each KEY, in `kbd' format, must be a single key: `smart-bury-mode'
binds it after `smart-bury-prefix-key', and `smart-bury-repeat-map'
binds it alone, so that COMMAND can be repeated with just that key
under `repeat-mode'.  Setting this variable (e.g. via `setopt' or
Customize) updates both keymaps immediately."
  :type '(alist :key-type function :value-type string)
  :group 'smart-bury
  :set #'smart-bury--set-and-rebuild)

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
    (setq smart-bury--valid-wrapped-commands valid)
    (setq smart-bury-commands
          (append '(smart-bury-switch-through-buffers
                     smart-bury-switch-to-other-buffer
                     smart-bury-bury-buffer)
                  (mapcar #'smart-bury--wrapper-name valid)))
    (dolist (fn valid)
      (smart-bury--define-wrapper fn)
      (put (smart-bury--wrapper-name fn) 'repeat-map 'smart-bury-repeat-map)
      (put (smart-bury--wrapper-name fn) 'repeat-check-key 'no))
    (smart-bury--rebuild-keymaps)))

(defcustom smart-bury-wrapped-commands '(quit-window kill-current-buffer)
  "Vanilla commands to generate a `smart-bury-FN' wrapper for.
`smart-bury-bury-buffer' is defined separately (it has its own entry
in `smart-bury-keys') and is not part of this list.  Setting this
variable (e.g. via `setopt' or Customize) regenerates the wrapper
commands and keeps `smart-bury-commands', `smart-bury-mode-map', and
`smart-bury-repeat-map' in sync."
  :type '(repeat function)
  :group 'smart-bury
  :set #'smart-bury--set-wrapped-commands)

(provide 'smart-bury)

;;; smart-bury.el ends here
