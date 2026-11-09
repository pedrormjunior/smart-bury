;;; smart-bury-project-tests.el --- Tests for smart-bury-project.el -*- lexical-binding: t; -*-

;;; Commentary:

;; Run with `make test', which loads smart-bury-tests.el first: these
;; tests use its macros and helpers.
;;
;; Every test but those of `smart-bury-project--buffers' itself stubs
;; that project lookup: the tests run inside a git checkout, whose
;; directory is a project, and on Emacs 27, which has no
;; `project-buffers'.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'smart-bury-project)
(require 'smart-bury-tests)

(defconst smart-bury-project-test--directory
  (file-name-directory (or load-file-name buffer-file-name))
  "The directory of this file, in the package's own repository.")

(defmacro smart-bury-project-test-with-case (project &rest body)
  "Run BODY as in `smart-bury-test-with-case-only', the project being PROJECT.
PROJECT is what the project lookup returns, either a list of buffers or
a string saying why there are none.  It is evaluated at each lookup,
with the case's buffers bound to `a'...`e', so it may depend on the
current buffer."
  (declare (indent 1))
  `(smart-bury-test-with-case-only
     (cl-letf (((symbol-function 'smart-bury-project--buffers)
                (lambda () ,project)))
       ,@body)))

(defun smart-bury-project-test--run ()
  "Run `smart-bury-project-bury-buffers' as `smart-bury-test--run' does.
Return the messages it showed, as if called interactively."
  (smart-bury-test-capturing-messages
    (smart-bury-test--run #'smart-bury-project-bury-buffers)))

;;; Burying

(ert-deftest smart-bury-project-test-buries-project ()
  "A fresh call buries the project's buffers at the end of the list, in
their order, goes to the first buffer left, and reports how many buffers
it buried."
  (smart-bury-project-test-with-case (list a c)
    (should (equal (smart-bury-project-test--run)
                   '("Smart Bury: 1/5 (buried 2)")))
    (should (eq (current-buffer) b))
    (should (equal (smart-bury-test--names bufs) '("B" "D" "E" "A" "C")))))

(ert-deftest smart-bury-project-test-mid-sequence ()
  "Mid-sequence, the project's buffers passed on the way are buried too,
and the sequence goes on after the current buffer."
  (smart-bury-project-test-with-case (list b d)
    (smart-bury-test--run #'smart-bury-switch-through-buffers
                          #'smart-bury-switch-through-buffers
                          #'smart-bury-switch-through-buffers)
    (should (equal (smart-bury-project-test--run)
                   '("Smart Bury: 3/5 (buried 2)")))
    (should (eq (current-buffer) e))
    (should (equal (smart-bury-test--names bufs) '("E" "A" "C" "B" "D")))
    (smart-bury-test--run #'smart-bury-switch-to-other-buffer)
    (should (eq (current-buffer) a))))

(ert-deftest smart-bury-project-test-no-buffer-outside-after ()
  "Mid-sequence, when no buffer outside the project follows the current
one, the sequence goes back to the first buffer outside it."
  (smart-bury-project-test-with-case (list b c d e)
    (smart-bury-test--run #'smart-bury-switch-through-buffers)
    (should (equal (smart-bury-project-test--run)
                   '("Smart Bury: 1/5 (buried 4)")))
    (should (eq (current-buffer) a))
    (should (equal (smart-bury-test--names bufs) '("A" "B" "C" "D" "E")))))

(ert-deftest smart-bury-project-test-project-after-project ()
  "Repeated, the command buries one project after another."
  (smart-bury-project-test-with-case (if (memq (current-buffer) (list a c))
                                         (list a c)
                                       (list b d))
    (smart-bury-project-test--run)
    (should (eq (current-buffer) b))
    (smart-bury-project-test--run)
    (should (eq (current-buffer) e))
    (should (equal (smart-bury-test--names bufs) '("E" "A" "C" "B" "D")))))

(ert-deftest smart-bury-project-test-every-buffer-in-project ()
  "When every buffer belongs to the project, the order does not change,
and a fresh call stays on the current buffer."
  (smart-bury-project-test-with-case bufs
    (should (equal (smart-bury-project-test--run)
                   '("Smart Bury: 1/5 (buried 5)")))
    (should (eq (current-buffer) a))
    (should (equal (smart-bury-test--names bufs) '("A" "B" "C" "D" "E")))))

(ert-deftest smart-bury-project-test-internal-buffers-not-counted ()
  "The project's internal buffers, whose names start with a space, are
buried along, but not counted in the report."
  (let ((internal (generate-new-buffer " sb-internal")))
    (unwind-protect
        (smart-bury-project-test-with-case (list a c internal)
          (setq bufs (append bufs (list internal)))
          (should (equal (smart-bury-project-test--run)
                         '("Smart Bury: 1/5 (buried 2)"))))
      (kill-buffer internal))))

(ert-deftest smart-bury-project-test-without-messages ()
  "With `smart-bury-messages' nil, burying reports nothing."
  (smart-bury-project-test-with-case (list a c)
    (let ((smart-bury-messages nil))
      (should-not (smart-bury-project-test--run))
      (should (eq (current-buffer) b)))))

;;; Doing nothing

(ert-deftest smart-bury-project-test-not-in-project-fresh ()
  "Outside a project, a fresh call changes nothing but starts a sequence
from the current buffer, at position 1, which it reports along with why
it did nothing."
  (smart-bury-project-test-with-case "not in a project"
    (setq smart-bury--counter 4
          smart-bury--initial-buffer e)
    (should (equal (smart-bury-project-test--run)
                   '("Smart Bury: 1/5 (not in a project)")))
    (should (eq (current-buffer) a))
    (should (equal (smart-bury-test--names bufs) '("A" "B" "C" "D" "E")))
    (should (eq smart-bury--initial-buffer a))
    (should (= smart-bury--counter 1))))

(ert-deftest smart-bury-project-test-not-in-project-mid-sequence ()
  "Outside a project, a call mid-sequence changes nothing, and the
sequence goes on."
  (smart-bury-project-test-with-case "not in a project"
    (smart-bury-test--run #'smart-bury-switch-through-buffers
                          #'smart-bury-switch-through-buffers)
    (should (equal (smart-bury-project-test--run)
                   '("Smart Bury: 3/5 (not in a project)")))
    (should (eq (current-buffer) c))
    (should (equal (smart-bury-test--names bufs) '("C" "A" "B" "D" "E")))
    (should (eq smart-bury--initial-buffer a))
    (should (= smart-bury--counter 3))
    (smart-bury-test--run #'smart-bury-switch-to-other-buffer)
    (should (eq (current-buffer) a))))

(ert-deftest smart-bury-project-test-not-in-project-without-messages ()
  "With `smart-bury-messages' nil, why nothing was done is still
reported, without the position."
  (smart-bury-project-test-with-case "not in a project"
    (let ((smart-bury-messages nil))
      (should (equal (smart-bury-project-test--run)
                     '("Smart Bury: not in a project"))))))

(ert-deftest smart-bury-project-test-dedicated-window ()
  "In a strongly dedicated window, nothing is done, without even looking
the project up."
  (smart-bury-project-test-with-case (error "Looked the project up")
    (unwind-protect
        (progn
          (set-window-dedicated-p nil t)
          (should (equal (smart-bury-project-test--run)
                         '("Smart Bury: 1/5 (dedicated window)")))
          (should (eq (current-buffer) a))
          (should (equal (smart-bury-test--names bufs)
                         '("A" "B" "C" "D" "E"))))
      (set-window-dedicated-p nil nil))))

;;; Raising

(defun smart-bury-project-test--raise ()
  "Run `smart-bury-project-raise-buffers' as `smart-bury-test--run' does.
Return the messages it showed, as if called interactively."
  (smart-bury-test-capturing-messages
    (smart-bury-test--run #'smart-bury-project-raise-buffers)))

(ert-deftest smart-bury-project-test-raises-project ()
  "A fresh call raises the project's buffers to the top of the list, in
their order, stays on the current buffer, and reports how many buffers
it raised."
  (smart-bury-project-test-with-case (list a c e)
    (should (equal (smart-bury-project-test--raise)
                   '("Smart Bury: 1/5 (raised 3)")))
    (should (eq (current-buffer) a))
    (should (equal (smart-bury-test--names bufs) '("A" "C" "E" "B" "D")))))

(ert-deftest smart-bury-project-test-raise-mid-sequence ()
  "Mid-sequence, the project's buffers passed on the way come before the
current one, and the sequence goes on from there."
  (smart-bury-project-test-with-case (list a c e)
    (smart-bury-test--run #'smart-bury-switch-through-buffers
                          #'smart-bury-switch-through-buffers)
    (should (equal (smart-bury-project-test--raise)
                   '("Smart Bury: 2/5 (raised 3)")))
    (should (eq (current-buffer) c))
    (should (equal (smart-bury-test--names bufs) '("C" "A" "E" "B" "D")))
    (smart-bury-test--run #'smart-bury-switch-to-other-buffer)
    (should (eq (current-buffer) a))))

(ert-deftest smart-bury-project-test-raise-not-in-project ()
  "Outside a project, raising does nothing but say why."
  (smart-bury-project-test-with-case "not in a project"
    (should (equal (smart-bury-project-test--raise)
                   '("Smart Bury: 1/5 (not in a project)")))
    (should (equal (smart-bury-test--names bufs) '("A" "B" "C" "D" "E")))))

(ert-deftest smart-bury-project-test-raise-dedicated-window ()
  "Raising switches no buffer, so it works in a strongly dedicated
window."
  (smart-bury-project-test-with-case (list a c e)
    (unwind-protect
        (progn
          (set-window-dedicated-p nil t)
          (should (equal (smart-bury-project-test--raise)
                         '("Smart Bury: 1/5 (raised 3)")))
          (should (equal (smart-bury-test--names bufs)
                         '("A" "C" "E" "B" "D"))))
      (set-window-dedicated-p nil nil))))

(ert-deftest smart-bury-project-test-raise-minibuffer-window ()
  "In a minibuffer window, raising does nothing, without even looking
the project up."
  (smart-bury-project-test-with-case (error "Looked the project up")
    (cl-letf (((symbol-function 'window-minibuffer-p) (lambda (&rest _) t)))
      (should (equal (smart-bury-project-test--raise)
                     '("Smart Bury: 1/5 (minibuffer window)"))))
    (should (equal (smart-bury-test--names bufs) '("A" "B" "C" "D" "E")))))

;;; Registration

(ert-deftest smart-bury-project-test-registered ()
  "The commands continue a sequence and arm the repeat map, even after
`smart-bury-wrapped-commands' changes."
  (dolist (command '(smart-bury-project-bury-buffers
                     smart-bury-project-raise-buffers))
    (smart-bury-test-with-wrapped-commands '(quit-window)
      (should (memq command smart-bury--commands)))
    (should (memq command smart-bury--commands))
    (should (eq (get command 'repeat-map) 'smart-bury-repeat-map))
    (should (eq (get command 'repeat-check-key) 'no))))

;;; `smart-bury-project--buffers'

(ert-deftest smart-bury-project-test-buffers-needs-emacs-28 ()
  "Without `project-buffers' (Emacs 27), the lookup says Emacs 28 is
needed."
  (skip-unless (not (fboundp 'project-buffers)))
  (should (equal (smart-bury-project--buffers) "needs Emacs 28")))

(ert-deftest smart-bury-project-test-buffers-outside-project ()
  "Outside a project, the lookup says so."
  (skip-unless (fboundp 'project-buffers))
  (let ((outside (make-temp-file "smart-bury-project-test" t)))
    (unwind-protect
        (with-temp-buffer
          (setq default-directory (file-name-as-directory outside))
          (skip-unless (not (project-current)))
          (should (equal (smart-bury-project--buffers) "not in a project")))
      (delete-directory outside))))

(ert-deftest smart-bury-project-test-buffers-in-project ()
  "In a project, here the package's own repository, the lookup returns
the project's buffers, the current one included."
  (skip-unless (fboundp 'project-buffers))
  (with-temp-buffer
    (setq default-directory smart-bury-project-test--directory)
    (skip-unless (project-current))
    (should (memq (current-buffer) (smart-bury-project--buffers)))))

(provide 'smart-bury-project-tests)

;;; smart-bury-project-tests.el ends here
