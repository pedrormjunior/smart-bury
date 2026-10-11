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

(defconst smart-bury--basic-commands
  '(smart-bury-switch-through-buffers
    smart-bury-switch-to-other-buffer
    smart-bury-bury-buffer)
  "The three basic Smart Bury commands, which always exist.
Unlike the wrappers generated from `smart-bury-wrapped-commands',
they are defined by hand.")

(defvar smart-bury-commands (copy-sequence smart-bury--basic-commands)
  "Commands allowed by Smart Bury without resetting configuration.
Extended with each wrapper generated from `smart-bury-wrapped-commands'
whenever that variable is set.")

(defvar smart-bury-counter 1
  "How many buffers deep the current Smart Bury sequence is.")

(defvar smart-bury-initial-buffer nil
  "The current buffer when the first Smart Bury command was called.")

(defgroup smart-bury nil
  "Smartly bury, quit, and kill buffers."
  :group 'convenience)

(defcustom smart-bury-same-frame t
  "Whether to consider only recent buffers in the same frame."
  :type 'boolean
  :group 'smart-bury)

(defun smart-bury--buffer-list nil
  "Return `buffer-list' according to configuration.
When `smart-bury-same-frame' is non-nil, the buffer list is in the scope
of the current frame."
  (buffer-list (when smart-bury-same-frame (selected-frame))))

(defun smart-bury--starts-now-p nil
  "Check if `last-command' was *not* one of the Smart Bury ones.
The Smart Bury commands are stored in `smart-bury-commands'."
  (not (memq last-command smart-bury-commands)))

(defun smart-bury--maybe-start-sequence nil
  "Start a new Smart Bury sequence if this call begins one.
When `smart-bury--starts-now-p', set `smart-bury-initial-buffer' to
the current buffer, i.e., the one from which the first call to a Smart
Bury command occurred.  Return non-nil if a new sequence started."
  (when (smart-bury--starts-now-p)
    (setq smart-bury-initial-buffer (current-buffer))
    t))

(defun smart-bury--is-initial-p nil
  "Check if current buffer is the initial one."
  (eq (current-buffer) smart-bury-initial-buffer))

(defun smart-bury--maybe-restart-sequence nil
  "Return non-nil if the Smart Bury sequence (re)starts with this call.
That is the case when `smart-bury--maybe-start-sequence' starts a new
sequence, or when the user is back on `smart-bury-initial-buffer'
while continuing one."
  (or (smart-bury--maybe-start-sequence)
      (smart-bury--is-initial-p)))

(defun smart-bury--eligible-p (buffer &optional allow-current)
  "Return non-nil if BUFFER may be switched to by Smart Bury.
BUFFER must be live, not a minibuffer, not internal (its name does
not start with a space), and not displayed in a window of the
selected frame -- unless ALLOW-CURRENT is non-nil and BUFFER is the
current buffer."
  (and (buffer-live-p buffer)
       (not (minibufferp buffer))
       (not (string-prefix-p " " (buffer-name buffer)))
       (or (not (get-buffer-window buffer))
           (and allow-current
                (eq buffer (current-buffer))))))

(defun smart-bury--select-buffers (buffers n &optional allow-current)
  "Return the first N eligible buffers of BUFFERS.
See `smart-bury--eligible-p' for ALLOW-CURRENT.  When N exceeds the
number of eligible buffers, wrap around and cycle through them again.
Signal a `user-error' when there are no eligible buffers at all."
  (cl-assert (>= n 1))
  (let ((eligible (seq-filter
                   (lambda (buffer)
                     (smart-bury--eligible-p buffer allow-current))
                   buffers)))
    (when (null eligible)
      (user-error "Smart Bury: no eligible buffer to switch to"))
    (let ((count (length eligible)))
      (cl-loop for i below n
               collect (nth (mod i count) eligible)))))

(defun smart-bury--walk-back (selection)
  "Switch to each buffer of SELECTION in reverse order.
The first buffer of SELECTION thus ends up current, and the
most-recently-used order of the others is rebuilt behind it, as
if the user had never left it.  This is what lets
`smart-bury-switch-to-other-buffer' return to the original buffer
after a run of `smart-bury-switch-through-buffers' calls, with the
\"list of all buffers\" as it was before -- so callers must never
skip these intermediate switches by jumping straight to a buffer."
  (mapc #'switch-to-buffer (reverse selection)))

(defun smart-bury--go-through-buffers (buffers &optional allow-current)
  "Go through `smart-bury-counter' buffers of BUFFERS.
Walk back through all of them except the last one (see
`smart-bury--walk-back'), and return the last one instead, for the
caller to switch to.  See `smart-bury--select-buffers' for
ALLOW-CURRENT, wrapping around, and the error when no buffer is
eligible."
  (let ((selection (smart-bury--select-buffers
                    buffers smart-bury-counter allow-current)))
    (smart-bury--walk-back (butlast selection))
    (car (last selection))))

(defun smart-bury--run-function (func &rest r)
  "Run FUNC passing arguments in R to it, then switch smartly.
Unless this call starts a fresh Smart Bury sequence, switch through
`smart-bury-counter' buffers afterward, keeping
`smart-bury-initial-buffer' in sync with where the sequence lands."
  ;; `let*': a new sequence makes the current buffer the initial one,
  ;; so WAS-INITIAL is always non-nil when STARTS-NOW is.
  (let* ((starts-now (smart-bury--maybe-start-sequence))
         (was-initial (smart-bury--is-initial-p)))
    (apply func r)
    (when was-initial
      (setq smart-bury-counter 1))
    (if starts-now
        (setq smart-bury-initial-buffer (current-buffer))
      (let ((last-buf (switch-to-buffer
                       (smart-bury--go-through-buffers
                        (smart-bury--buffer-list)
                        'allow-current))))
        (when was-initial
          (setq smart-bury-initial-buffer last-buf))))))

(defun smart-bury-switch-through-buffers nil
  "Smartly switch to the other buffer, then further on repeated calls.
The first call switches to the other buffer; each immediately
following call goes one buffer further (3rd, 4th...), without burying
the buffers on the way."
  (interactive)
  (when (smart-bury--maybe-restart-sequence)
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
        (if (smart-bury--maybe-restart-sequence)
            2
          (max 2 smart-bury-counter)))
  (smart-bury--walk-back
   (smart-bury--select-buffers (cdr (smart-bury--buffer-list))
                               (1- smart-bury-counter)))
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
  "Define `smart-bury-FN'.
Defined function is an interactive command that wraps the vanilla
command FN via `smart-bury--run-function'.  Defined function works
together with other Smart Bury functions.

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
  "Globally remap `bury-buffer' and wrapped commands to Smart Bury ones.
Wrapped commands are the entries of `smart-bury-wrapped-commands'.
Also bind the commands in `smart-bury-keys' under
`smart-bury-prefix-key'.

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
  "Keymap letting `repeat-mode' repeat Smart Bury's commands.

Each command in `smart-bury-keys' is repeatable with its own key
\(the one following `smart-bury-prefix-key'); those bindings live in
the parent keymap, `smart-bury--repeat-map-generated'.  Bindings
added to this keymap itself (e.g. via `define-key') belong to the
user and are preserved across any later customization.

Every Smart Bury command, including each one generated from
`smart-bury-wrapped-commands', sets option `repeat-check-key' to `no',
so this map arms regardless of which key actually invoked the command --
notably commands like `smart-bury-quit-window' and
`smart-bury-kill-current-buffer', which only reach the user via a remap
of whatever key `quit-window'/`kill-current-buffer' are bound
to (e.g. \"q\" in many read-only modes), and so have no fixed \"last
key\" of their own to require.  None of the wrapped commands get a
default binding in this map; add one yourself (and bind the matching
vanilla command, if needed) to make it repeatable with that key.

This has no effect unless the user has enabled `repeat-mode'
themselves; `smart-bury-mode' does not turn it on.")

(defun smart-bury--make-repeatable (command)
  "Make COMMAND arm `smart-bury-repeat-map' under `repeat-mode'.
Set its `repeat-check-key' to `no' too, so the map arms whichever key
invoked COMMAND (see `smart-bury-repeat-map')."
  (put command 'repeat-map 'smart-bury-repeat-map)
  (put command 'repeat-check-key 'no))

(mapc #'smart-bury--make-repeatable smart-bury--basic-commands)

(defvar smart-bury--valid-wrapped-commands nil
  "The valid entries of `smart-bury-wrapped-commands'.
That is, the entries that were actually wrapped, i.e., without the
invalid ones skipped with a warning.")

(defun smart-bury--rebuild-keymaps ()
  "Rebuild generated maps.
Rebuild `smart-bury--mode-map-generated' and
`smart-bury--repeat-map-generated' in place from
`smart-bury-prefix-key', `smart-bury-keys', and
`smart-bury--valid-wrapped-commands'.

Does nothing until all of Smart Bury's options are defined: each
option's `:set' calls this function, and `custom-initialize-reset' runs
that `:set' while `smart-bury.el' is still loading, before the options
defined after it exist.  The last one defined triggers the first full
build.

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
  "Set SYMBOL to VALUE and regenerate the wrapper commands.
Used as the `:set' function of `smart-bury-wrapped-commands'.  Also
update `smart-bury-commands' and Smart Bury's keymaps to match VALUE.

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
          (append smart-bury--basic-commands
                  (mapcar #'smart-bury--wrapper-name valid)))
    (dolist (fn valid)
      (smart-bury--define-wrapper fn)
      (smart-bury--make-repeatable (smart-bury--wrapper-name fn)))
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
