;;; smart-bury-project.el --- Smart Bury commands for project buffers -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Pedro Ribeiro Mendes Júnior

;; Author: Pedro Ribeiro Mendes Júnior <pedrormjunior@gmail.com>
;; Assisted-by: Claude:claude-opus-5-5
;; Keywords: convenience
;; URL: https://github.com/pedrormjunior/smart-bury

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.

;; This program is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see
;; <https://www.gnu.org/licenses/>.

;;; Commentary:

;; Smart Bury commands for the buffers of the current buffer's project,
;; as `project.el' finds them (Emacs 28 or later):
;;
;; - `smart-bury-project-bury-buffers': bury all the buffers of the
;;   current project, keeping their order, and switch to the next
;;   buffer outside it, taking part in Smart Bury's sequences;
;;
;; - `smart-bury-project-raise-buffers': raise them all to the top of
;;   the list of all buffers, keeping their order, and stay on the
;;   current buffer, taking part in the sequences too.
;;
;; No key is bound by default.  For instance, to bind them to
;; `C-x p M--' and `C-x p -':
;;
;;   (define-key project-prefix-map (kbd "M--")
;;     #'smart-bury-project-bury-buffers)
;;   (define-key project-prefix-map "-" #'smart-bury-project-raise-buffers)

;;; Code:

(require 'smart-bury)
(require 'project)

(defun smart-bury-project--buffers ()
  "Return the buffers of the current buffer's project.
Return a string instead, saying why there are none: the current buffer
is not in a project, or Emacs is older than 28, which `project-buffers'
needs."
  (if (not (fboundp 'project-buffers))
      "needs Emacs 28"
    (let ((project (project-current)))
      (or (and project (project-buffers project))
          "not in a project"))))

(defun smart-bury-project--count (buffers)
  "Return how many of BUFFERS a report counts.
Internal buffers, whose names start with a space, are not counted."
  (seq-count (lambda (buffer)
               (not (string-prefix-p " " (buffer-name buffer))))
             buffers))

;;;###autoload
(defun smart-bury-project-bury-buffers ()
  "Smartly bury all the buffers of the current buffer's project.
Put them at the end of the list of all buffers, keeping their order, and
switch to the next buffer outside the project, as
`smart-bury-bury-buffer' does for the current buffer alone: in a
sequence, the buffers passed on the way that belong to the project are
buried too, and the sequence goes on after the current buffer, or back
to its first buffer outside the project when none is left after it.
When every buffer belongs to the project, the order does not change, and
the sequence goes back to its initial buffer, the project's most recent
one.
Report how many buffers were buried, e.g. \"Smart Bury: 3/80 (buried
5)\".

The project's buffers are those `project-buffers' returns, i.e. those
whose `default-directory' is in the project.  Do nothing but report why
when the current buffer is not in a project, when Emacs is older than
28, or in a minibuffer or strongly dedicated window (see
`smart-bury--do-nothing')."
  (interactive)
  (let ((buffers (or (smart-bury--switch-blocked-reason)
                     (smart-bury-project--buffers))))
    (if (stringp buffers)
        (smart-bury--do-nothing buffers)
      (let ((buried (smart-bury--bury-buffers buffers)))
        (smart-bury--report
         "%s (buried %d)"
         (smart-bury--position smart-bury--counter)
         (smart-bury-project--count buried))))))

;;;###autoload
(defun smart-bury-project-raise-buffers ()
  "Smartly raise all the buffers of the current buffer's project.
Put them at the top of the list of all buffers, keeping their order, by
burying every other buffer, most recent first, and stay on the current
buffer, so that the next buffer is the project's next one.  In a
sequence, their order is the sequence's: the project's buffers passed
on the way come before the current one, which goes on one buffer deeper
than them.  Report how many buffers were raised, e.g. \"Smart Bury:
2/80 (raised 5)\".

The project's buffers are those `project-buffers' returns, as for
`smart-bury-project-bury-buffers'.  Do nothing but report why when the
current buffer is not in a project, when Emacs is older than 28, or in
a minibuffer window (see `smart-bury--do-nothing')."
  (interactive)
  (let ((buffers (if (window-minibuffer-p)
                     "minibuffer window"
                   (smart-bury-project--buffers))))
    (if (stringp buffers)
        (smart-bury--do-nothing buffers)
      (let ((raised (smart-bury--raise-buffers buffers)))
        (smart-bury--report
         "%s (raised %d)"
         (smart-bury--position smart-bury--counter)
         (smart-bury-project--count raised))))))

(smart-bury--register-command 'smart-bury-project-bury-buffers)
(smart-bury--register-command 'smart-bury-project-raise-buffers)

(provide 'smart-bury-project)

;;; smart-bury-project.el ends here
