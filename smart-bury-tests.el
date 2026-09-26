;;; smart-bury-tests.el --- Tests for smart-bury.el -*- lexical-binding: t; -*-

;;; Commentary:

;; Run with:
;;   emacs -batch -l ert -l smart-bury.el -l smart-bury-tests.el \
;;     -f ert-run-tests-batch-and-exit
;; or `make test'.

;;; Code:

(require 'ert)
(require 'cl-lib)
(require 'smart-bury)

(defmacro smart-bury-test-with-buffers (bindings &rest body)
  "Bind each (VAR NAME) pair in BINDINGS to a fresh buffer named NAME.
Reset Smart Bury's global state for the duration of BODY, and
always kill the buffers afterward, even if BODY signals an error."
  (declare (indent 1))
  `(let (,@(mapcar (lambda (b) `(,(car b) (generate-new-buffer ,(cadr b))))
                   bindings)
         (smart-bury-counter 1)
         (smart-bury-initial-buffer nil))
     (unwind-protect
         (save-window-excursion
           (save-current-buffer
             ,@body))
       ,@(mapcar (lambda (b) `(when (buffer-live-p ,(car b))
                                (kill-buffer ,(car b))))
                 bindings))))

(defmacro smart-bury-test-with-buffer-list (buffers &rest body)
  "Run BODY with `buffer-list' stubbed to always return the live
buffers among BUFFERS. This isolates tests of the public commands
from whatever real buffers happen to exist in the Emacs session
running the tests, while still mimicking real `buffer-list', which
never reports an already-killed buffer -- some of BUFFERS may get
killed by BODY itself across a sequence of calls."
  (declare (indent 1))
  `(cl-letf (((symbol-function 'buffer-list)
              (lambda (&optional _frame) (seq-filter #'buffer-live-p ,buffers))))
     ,@body))


;;; `smart-bury--go-through-buffers'

(ert-deftest smart-bury-test-go-through-buffers-skips-hidden ()
  "A hidden (\" *...*\") buffer is never eligible for selection."
  (smart-bury-test-with-buffers ((a "sb-a") (hidden " *sb-hidden*") (b "sb-b"))
    (should (eq (smart-bury--go-through-buffers (list hidden a b)) a))))

(ert-deftest smart-bury-test-go-through-buffers-nth ()
  "With COUNTER = 2, the 2nd eligible buffer is returned, and the
1st is switched through along the way."
  (smart-bury-test-with-buffers ((a "sb-a") (b "sb-b") (c "sb-c"))
    (setq smart-bury-counter 2)
    (should (eq (smart-bury--go-through-buffers (list a b c)) b))
    (should (eq (current-buffer) a))))

(ert-deftest smart-bury-test-go-through-buffers-allow-current ()
  "ALLOW-CURRENT lets the current buffer be selected even though it
already has a window; without it, a displayed buffer is skipped."
  (smart-bury-test-with-buffers ((cur "sb-cur") (other "sb-other"))
    (switch-to-buffer cur)
    (should (eq (smart-bury--go-through-buffers (list cur other)) other))
    (should (eq (smart-bury--go-through-buffers (list cur other) 'allow-current)
               cur))))

(ert-deftest smart-bury-test-go-through-buffers-wraps-around ()
  "When COUNTER exceeds the number of eligible buffers, cycle back
around instead of failing to make progress."
  (smart-bury-test-with-buffers ((a "sb-a") (b "sb-b"))
    (setq smart-bury-counter 3)
    (should (eq (smart-bury--go-through-buffers (list a b) 'allow-current) a))))

(ert-deftest smart-bury-test-go-through-buffers-no-eligible-signals-error ()
  "With zero eligible buffers (e.g. every candidate is already
displayed in a window and ALLOW-CURRENT is nil), signal a
`user-error' immediately instead of looping forever.  This is a
regression test for IMPROVEMENTS.md item 2: an unbounded `while' loop
used to spin forever chasing a target buffer count it could never
reach."
  (smart-bury-test-with-buffers ((a "sb-a") (b "sb-b"))
    (switch-to-buffer a)
    (save-window-excursion
      (split-window)
      (other-window 1)
      (switch-to-buffer b)
      (other-window 1)
      (should-error (smart-bury--go-through-buffers (list a b) nil)
                    :type 'user-error))))


;;; `smart-bury--starts-now-p' / `smart-bury--is-initial-p'

(ert-deftest smart-bury-test-starts-now-p-fresh-command ()
  "A LAST-COMMAND outside `smart-bury-commands' marks a fresh start
and records the current buffer as the initial one."
  (smart-bury-test-with-buffers ((a "sb-a"))
    (with-current-buffer a
      (let ((last-command 'some-other-command))
        (should (smart-bury--starts-now-p))
        (should (eq smart-bury-initial-buffer a))))))

(ert-deftest smart-bury-test-starts-now-p-continuing ()
  "A LAST-COMMAND that is a Smart Bury command means we're
continuing a sequence, and the initial buffer is left untouched."
  (smart-bury-test-with-buffers ((a "sb-a") (b "sb-b"))
    (setq smart-bury-initial-buffer a)
    (with-current-buffer b
      (let ((last-command 'smart-bury-bury-buffer))
        (should-not (smart-bury--starts-now-p))
        (should (eq smart-bury-initial-buffer a))))))

(ert-deftest smart-bury-test-is-initial-p ()
  (smart-bury-test-with-buffers ((a "sb-a") (b "sb-b"))
    (setq smart-bury-initial-buffer a)
    (with-current-buffer a
      (should (smart-bury--is-initial-p)))
    (with-current-buffer b
      (should-not (smart-bury--is-initial-p)))))


;;; Public commands

;; NOTE: unlike `smart-bury--go-through-buffers' (exercised directly
;; above), `bury-buffer' and `quit-window' pick their target via the
;; *selected window's own* prev/next-buffer history, not via the
;; `buffer-list' function -- so mocking `buffer-list' cannot pin down
;; which buffer they land on. These tests therefore check the
;; invariant Smart Bury is actually responsible for (that
;; `smart-bury-initial-buffer' and `smart-bury-counter' are kept in
;; sync with wherever we really end up), rather than guessing the
;; destination buffer.

(ert-deftest smart-bury-test-bury-buffer-single-call ()
  "A single, fresh call to `smart-bury-bury-buffer' delegates to
`bury-buffer' and records wherever we land as the initial buffer,
without cycling through anything else yet."
  (smart-bury-test-with-buffers ((a "sb-a") (b "sb-b"))
    (switch-to-buffer a)
    (smart-bury-test-with-buffer-list (list a b)
      (let ((last-command 'some-other-command))
        (smart-bury-bury-buffer)
        (should (eq smart-bury-initial-buffer (current-buffer)))
        (should (= smart-bury-counter 1))))))

(ert-deftest smart-bury-test-bury-buffer-repeated-calls-track-initial-buffer ()
  "A second, immediately-following call keeps the initial-buffer and
counter bookkeeping consistent with wherever `bury-buffer' actually
lands each time."
  (smart-bury-test-with-buffers ((a "sb-a") (b "sb-b") (c "sb-c"))
    (switch-to-buffer a)
    (smart-bury-test-with-buffer-list (list a b c)
      (let ((last-command 'some-other-command))
        (smart-bury-bury-buffer))
      ;; Simulate Emacs's command loop having just run
      ;; `smart-bury-bury-buffer'.
      (let ((last-command 'smart-bury-bury-buffer))
        (smart-bury-bury-buffer))
      (should (eq smart-bury-initial-buffer (current-buffer)))
      (should (= smart-bury-counter 1)))))

(ert-deftest smart-bury-test-switch-through-buffers-increments-counter ()
  (smart-bury-test-with-buffers ((a "sb-a") (b "sb-b") (c "sb-c"))
    (switch-to-buffer a)
    (smart-bury-test-with-buffer-list (list a b c)
      (let ((last-command 'some-other-command))
        (smart-bury-switch-through-buffers))
      (should (= smart-bury-counter 2))
      (let ((last-command 'smart-bury-switch-through-buffers))
        (smart-bury-switch-through-buffers))
      (should (= smart-bury-counter 3)))))

(ert-deftest smart-bury-test-switch-through-then-switch-to-other-returns-to-origin ()
  "Repetitive calls to `smart-bury-switch-through-buffers' followed
by a single call to `smart-bury-switch-to-other-buffer' must bring
back the original buffer.

Unlike the other public-command tests above, this one does NOT stub
`buffer-list': the invariant it checks depends on the real, dynamic
most-recently-used buffer ordering that `switch-to-buffer' maintains
as a side effect of the intermediate switches `smart-bury' performs
while cycling -- exactly the behavior a prior, more \"clever\"
rewrite of `smart-bury--go-through-buffers' silently dropped (it
computed the right final buffer but skipped the intermediate
switches, so this invariant broke even though every other test
still passed)."
  (smart-bury-test-with-buffers ((a "sb-a") (b "sb-b") (c "sb-c"))
    (switch-to-buffer a)
    (let ((last-command 'some-other-command))
      (smart-bury-switch-through-buffers))
    (dotimes (_ 2)
      (let ((last-command 'smart-bury-switch-through-buffers))
        (smart-bury-switch-through-buffers)))
    (should-not (eq (current-buffer) a))
    (let ((last-command 'smart-bury-switch-through-buffers))
      (smart-bury-switch-to-other-buffer))
    (should (eq (current-buffer) a))))

(ert-deftest smart-bury-test-switch-to-other-buffer-targets-second ()
  "Regardless of any counter left over from a previous sequence,
`smart-bury-switch-to-other-buffer' always targets the 2nd buffer."
  (smart-bury-test-with-buffers ((a "sb-a") (b "sb-b") (c "sb-c"))
    (switch-to-buffer a)
    (smart-bury-test-with-buffer-list (list a b c)
      (setq smart-bury-counter 5)
      (let ((last-command 'smart-bury-switch-through-buffers))
        (smart-bury-switch-to-other-buffer))
      (should (= smart-bury-counter 2)))))

(ert-deftest smart-bury-test-kill-current-buffer ()
  "Killing the current buffer should leave us on another live,
sane buffer."
  (smart-bury-test-with-buffers ((a "sb-a") (b "sb-b"))
    (switch-to-buffer a)
    (smart-bury-test-with-buffer-list (list a b)
      (let ((last-command 'some-other-command))
        (smart-bury-kill-current-buffer))
      (should (buffer-live-p (current-buffer)))
      (should-not (eq (current-buffer) a)))))

(ert-deftest smart-bury-test-kill-current-buffer-repeated ()
  "Two immediately-following kills should still each leave us on a
live, sane buffer. A single-kill repro of IMPROVEMENTS.md item 1
did not reproduce the original author's suspected bug (see the
test above); this widens the probe to a repeated-call sequence."
  (smart-bury-test-with-buffers ((a "sb-a") (b "sb-b") (c "sb-c"))
    (switch-to-buffer a)
    (smart-bury-test-with-buffer-list (list a b c)
      (let ((last-command 'some-other-command))
        (smart-bury-kill-current-buffer))
      (should (buffer-live-p (current-buffer)))
      (let ((last-command 'smart-bury-kill-current-buffer))
        (smart-bury-kill-current-buffer))
      (should (buffer-live-p (current-buffer))))))

(provide 'smart-bury-tests)

;;; smart-bury-tests.el ends here
