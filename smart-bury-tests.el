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
         (smart-bury--counter 1)
         (smart-bury--initial-buffer nil))
     (unwind-protect
         (save-window-excursion
           (save-current-buffer
             ,@body))
       ,@(mapcar (lambda (b) `(when (buffer-live-p ,(car b))
                                (kill-buffer ,(car b))))
                 bindings))))

(defmacro smart-bury-test-with-mode (&rest body)
  "Run BODY with `smart-bury-mode' enabled, always disabling it
afterward even if BODY signals an error."
  (declare (indent 0))
  `(unwind-protect
       (progn
         (smart-bury-mode 1)
         ,@body)
     (smart-bury-mode -1)))

(defmacro smart-bury-test-with-wrapped-commands (commands &rest body)
  "Run BODY with `smart-bury-wrapped-commands' temporarily set to
COMMANDS (regenerating the wrapper commands, `smart-bury--commands',
and `smart-bury-mode-map' to match), always restoring and
regenerating the original value afterward even if BODY signals an
error."
  (declare (indent 1))
  `(let ((smart-bury--orig-wrapped-commands smart-bury-wrapped-commands))
     (unwind-protect
         (progn
           (customize-set-variable 'smart-bury-wrapped-commands ,commands)
           ,@body)
       (customize-set-variable 'smart-bury-wrapped-commands
                               smart-bury--orig-wrapped-commands))))

(defmacro smart-bury-test-with-repeatable-commands (commands &rest body)
  "Run BODY with `smart-bury-repeatable-commands' temporarily set to
COMMANDS, always restoring the original value afterward even if BODY
signals an error."
  (declare (indent 1))
  `(let ((smart-bury--orig-repeatable-commands smart-bury-repeatable-commands))
     (unwind-protect
         (progn
           (customize-set-variable 'smart-bury-repeatable-commands ,commands)
           ,@body)
       (customize-set-variable 'smart-bury-repeatable-commands
                               smart-bury--orig-repeatable-commands))))

(defmacro smart-bury-test-with-keys (prefix keys &rest body)
  "Run BODY with `smart-bury-prefix-key' and `smart-bury-keys'
temporarily set to PREFIX and KEYS (rebuilding Smart Bury's keymaps
to match), always restoring the original values afterward even if
BODY signals an error."
  (declare (indent 2))
  `(let ((smart-bury--orig-prefix-key smart-bury-prefix-key)
         (smart-bury--orig-keys smart-bury-keys))
     (unwind-protect
         (progn
           (customize-set-variable 'smart-bury-prefix-key ,prefix)
           (customize-set-variable 'smart-bury-keys ,keys)
           ,@body)
       (customize-set-variable 'smart-bury-prefix-key smart-bury--orig-prefix-key)
       (customize-set-variable 'smart-bury-keys smart-bury--orig-keys))))

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

(ert-deftest smart-bury-test-go-through-buffers-skips-space-prefixed ()
  "Any buffer whose name starts with a space is internal and never
eligible, not only those starting with \" *\"."
  (smart-bury-test-with-buffers ((a "sb-a") (internal " sb-internal") (b "sb-b"))
    (should (eq (smart-bury--go-through-buffers (list internal a b)) a))))

(ert-deftest smart-bury-test-go-through-buffers-skips-dead-buffer ()
  "A killed buffer in a caller-supplied list is skipped instead of
crashing on its nil `buffer-name'."
  (smart-bury-test-with-buffers ((dead "sb-dead") (a "sb-a") (b "sb-b"))
    (kill-buffer dead)
    (should (eq (smart-bury--go-through-buffers (list dead a b)) a))))

(ert-deftest smart-bury-test-go-through-buffers-nth ()
  "With COUNTER = 2, the 2nd eligible buffer is returned, and the
1st is switched through along the way."
  (smart-bury-test-with-buffers ((a "sb-a") (b "sb-b") (c "sb-c"))
    (setq smart-bury--counter 2)
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
    (setq smart-bury--counter 3)
    (should (eq (smart-bury--go-through-buffers (list a b) 'allow-current) a))))

(ert-deftest smart-bury-test-go-through-buffers-no-eligible-signals-error ()
  "With zero eligible buffers (e.g. every candidate is already
displayed in a window and ALLOW-CURRENT is nil), signal a
`user-error' immediately instead of looping forever.  This is a
regression test: an unbounded `while' loop used to spin forever
chasing a target buffer count it could never reach."
  (smart-bury-test-with-buffers ((a "sb-a") (b "sb-b"))
    (switch-to-buffer a)
    (save-window-excursion
      (split-window)
      (other-window 1)
      (switch-to-buffer b)
      (other-window 1)
      (should-error (smart-bury--go-through-buffers (list a b) nil)
                    :type 'user-error))))


;;; `smart-bury--starts-now-p' / `smart-bury--maybe-start-sequence' /
;;; `smart-bury--is-initial-p'

(ert-deftest smart-bury-test-starts-now-p-is-pure ()
  "`smart-bury--starts-now-p' only reports whether LAST-COMMAND is
outside `smart-bury--commands'; it never touches the initial buffer."
  (smart-bury-test-with-buffers ((a "sb-a") (b "sb-b"))
    (setq smart-bury--initial-buffer a)
    (with-current-buffer b
      (let ((last-command 'some-other-command))
        (should (smart-bury--starts-now-p)))
      (let ((last-command 'smart-bury-bury-buffer))
        (should-not (smart-bury--starts-now-p)))
      (should (eq smart-bury--initial-buffer a)))))

(ert-deftest smart-bury-test-maybe-start-sequence-fresh-command ()
  "A LAST-COMMAND outside `smart-bury--commands' starts a new sequence
and records the current buffer as the initial one."
  (smart-bury-test-with-buffers ((a "sb-a"))
    (with-current-buffer a
      (let ((last-command 'some-other-command))
        (should (smart-bury--maybe-start-sequence))
        (should (eq smart-bury--initial-buffer a))))))

(ert-deftest smart-bury-test-maybe-start-sequence-continuing ()
  "A LAST-COMMAND that is a Smart Bury command means we're
continuing a sequence, and the initial buffer is left untouched."
  (smart-bury-test-with-buffers ((a "sb-a") (b "sb-b"))
    (setq smart-bury--initial-buffer a)
    (with-current-buffer b
      (let ((last-command 'smart-bury-bury-buffer))
        (should-not (smart-bury--maybe-start-sequence))
        (should (eq smart-bury--initial-buffer a))))))

(ert-deftest smart-bury-test-is-initial-p ()
  (smart-bury-test-with-buffers ((a "sb-a") (b "sb-b"))
    (setq smart-bury--initial-buffer a)
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
;; `smart-bury--initial-buffer' and `smart-bury--counter' are kept in
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
        (should (eq smart-bury--initial-buffer (current-buffer)))
        (should (= smart-bury--counter 1))))))

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
      (should (eq smart-bury--initial-buffer (current-buffer)))
      (should (= smart-bury--counter 1)))))

(ert-deftest smart-bury-test-switch-through-buffers-increments-counter ()
  (smart-bury-test-with-buffers ((a "sb-a") (b "sb-b") (c "sb-c"))
    (switch-to-buffer a)
    (smart-bury-test-with-buffer-list (list a b c)
      (let ((last-command 'some-other-command))
        (smart-bury-switch-through-buffers))
      (should (= smart-bury--counter 2))
      (let ((last-command 'smart-bury-switch-through-buffers))
        (smart-bury-switch-through-buffers))
      (should (= smart-bury--counter 3)))))

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

(ert-deftest smart-bury-test-sequence-with-initial-buffer-in-other-window ()
  "With the initial buffer also shown in another window (e.g. right
after splitting the window), switching through buffers visits them
in order, and switching to the other buffer returns to the initial
one.

Regression test: the initial buffer, being displayed in the other
window, was not eligible, so every call after the first skipped a
buffer, and `smart-bury-switch-to-other-buffer' landed on the skipped
buffer instead of the initial one.  Like the test above, this one
needs the real `buffer-list'."
  (smart-bury-test-with-buffers ((a "sb-a") (b "sb-b") (c "sb-c") (d "sb-d"))
    (delete-other-windows)
    (dolist (buffer (list d c b a))
      (switch-to-buffer buffer))
    (split-window-right)
    (let ((last-command 'some-other-command))
      (smart-bury-switch-through-buffers))
    (should (eq (current-buffer) b))
    (let ((last-command 'smart-bury-switch-through-buffers))
      (smart-bury-switch-through-buffers))
    (should (eq (current-buffer) c))
    (let ((last-command 'smart-bury-switch-through-buffers))
      (smart-bury-switch-to-other-buffer))
    (should (eq (current-buffer) a))))

(ert-deftest smart-bury-test-skips-buffer-in-other-window ()
  "By default, switching through buffers skips a buffer displayed in
another window, unless it is the initial buffer."
  (smart-bury-test-with-buffers ((a "sb-a") (b "sb-b") (c "sb-c") (d "sb-d"))
    (delete-other-windows)
    (dolist (buffer (list d c b a))
      (switch-to-buffer buffer))
    (set-window-buffer (split-window-right) b)
    (let ((smart-bury-include-displayed-buffers nil))
      (let ((last-command 'some-other-command))
        (smart-bury-switch-through-buffers))
      (should (eq (current-buffer) c))
      (let ((last-command 'smart-bury-switch-through-buffers))
        (smart-bury-switch-through-buffers))
      (should (eq (current-buffer) d))
      (let ((last-command 'smart-bury-switch-through-buffers))
        (smart-bury-switch-to-other-buffer))
      (should (eq (current-buffer) a)))))

(ert-deftest smart-bury-test-include-displayed-buffers ()
  "With `smart-bury-include-displayed-buffers' non-nil, switching
through buffers also goes through a buffer displayed in another
window, and the sequence still returns to the initial buffer."
  (smart-bury-test-with-buffers ((a "sb-a") (b "sb-b") (c "sb-c") (d "sb-d"))
    (delete-other-windows)
    (dolist (buffer (list d c b a))
      (switch-to-buffer buffer))
    (set-window-buffer (split-window-right) b)
    (let ((smart-bury-include-displayed-buffers t))
      (let ((last-command 'some-other-command))
        (smart-bury-switch-through-buffers))
      (should (eq (current-buffer) b))
      (let ((last-command 'smart-bury-switch-through-buffers))
        (smart-bury-switch-through-buffers))
      (should (eq (current-buffer) c))
      (let ((last-command 'smart-bury-switch-through-buffers))
        (smart-bury-switch-to-other-buffer))
      (should (eq (current-buffer) a)))))

(ert-deftest smart-bury-test-switching-ignores-display-actions ()
  "Switching through buffers ignores `display-buffer-alist', even with
`switch-to-buffer-obey-display-actions' non-nil.

Regression test: Smart Bury switches with `switch-to-buffer', which
then obeyed the display action of every buffer passed through, so one
shown in the full frame deleted the other window of a split, and the
sequence went on in whatever window the action chose."
  (smart-bury-test-with-buffers ((a "sb-a") (b "sb-b") (c "sb-c") (d "sb-d"))
    (delete-other-windows)
    (dolist (buffer (list d c b a))
      (switch-to-buffer buffer))
    (split-window-right)
    (let ((window (selected-window))
          (switch-to-buffer-obey-display-actions t)
          ;; C is to be shown in the full frame.
          (display-buffer-alist
           `((,(concat "\\`" (regexp-quote (buffer-name c)) "\\'")
              ,(lambda (buffer alist)
                 (delete-other-windows)
                 (display-buffer-same-window buffer alist))))))
      (let ((last-command 'some-other-command))
        (smart-bury-switch-through-buffers))
      (let ((last-command 'smart-bury-switch-through-buffers))
        (smart-bury-switch-through-buffers))
      ;; Landing on C...
      (should (eq (current-buffer) c))
      (should (= (length (window-list)) 2))
      (let ((last-command 'smart-bury-switch-through-buffers))
        (smart-bury-switch-through-buffers))
      ;; ...and passing through it again on the way to D.
      (should (eq (current-buffer) d))
      (should (= (length (window-list)) 2))
      (should (eq (selected-window) window))
      (let ((last-command 'smart-bury-switch-through-buffers))
        (smart-bury-switch-to-other-buffer))
      (should (eq (current-buffer) a)))))

(ert-deftest smart-bury-test-switch-to-other-buffer-alternates-back-and-forth ()
  "A fresh call to `smart-bury-switch-to-other-buffer' switches to the
\"other\" buffer; calling it again (continuing the sequence) switches
back to the buffer the sequence started from; calling it a third
time switches to that same \"other\" buffer again -- i.e. it keeps
alternating between exactly the same two buffers.

Like `smart-bury-test-switch-through-then-switch-to-other-returns-to-origin'
above, this does NOT stub `buffer-list': the alternation depends on
the real, dynamic most-recently-used buffer ordering."
  (smart-bury-test-with-buffers ((a "sb-a") (b "sb-b") (c "sb-c"))
    (switch-to-buffer a)
    (let ((last-command 'some-other-command))
      (smart-bury-switch-to-other-buffer))
    (should-not (eq (current-buffer) a))
    (let ((other (current-buffer)))
      (let ((last-command 'smart-bury-switch-to-other-buffer))
        (smart-bury-switch-to-other-buffer))
      (should (eq (current-buffer) a))
      (let ((last-command 'smart-bury-switch-to-other-buffer))
        (smart-bury-switch-to-other-buffer))
      (should (eq (current-buffer) other)))))

(ert-deftest smart-bury-test-switch-to-other-buffer-targets-second ()
  "Regardless of any counter left over from a previous sequence,
`smart-bury-switch-to-other-buffer' always targets the 2nd buffer."
  (smart-bury-test-with-buffers ((a "sb-a") (b "sb-b") (c "sb-c"))
    (switch-to-buffer a)
    (smart-bury-test-with-buffer-list (list a b c)
      (setq smart-bury--counter 5)
      (let ((last-command 'smart-bury-switch-through-buffers))
        (smart-bury-switch-to-other-buffer))
      (should (= smart-bury--counter 2)))))

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
live, sane buffer."
  (smart-bury-test-with-buffers ((a "sb-a") (b "sb-b") (c "sb-c"))
    (switch-to-buffer a)
    (smart-bury-test-with-buffer-list (list a b c)
      (let ((last-command 'some-other-command))
        (smart-bury-kill-current-buffer))
      (should (buffer-live-p (current-buffer)))
      (let ((last-command 'smart-bury-kill-current-buffer))
        (smart-bury-kill-current-buffer))
      (should (buffer-live-p (current-buffer))))))

;;; Messages

(defmacro smart-bury-test-capturing-messages (&rest body)
  "Run BODY as if its commands were called interactively.
Stub `called-interactively-p' (always nil in batch) and capture each
`message' instead of printing it.  Return the captured messages, in
order."
  (declare (indent 0))
  `(let (messages)
     (cl-letf (((symbol-function 'called-interactively-p) (lambda (&rest _) t))
               ((symbol-function 'message)
                (lambda (format-string &rest args)
                  (push (apply #'format format-string args) messages))))
       ,@body)
     (nreverse messages)))

(defun smart-bury-test-total ()
  "Return how many buffers a sequence goes through in the test session.
With a single window, that is every buffer but the internal ones,
whose names start with a space."
  (length (seq-remove (lambda (buffer)
                        (string-prefix-p " " (buffer-name buffer)))
                      (buffer-list))))

(defun smart-bury-test-positions (total &rest positions)
  "Return the messages expected for POSITIONS, each out of TOTAL."
  (mapcar (lambda (position)
            (format "Smart Bury: %d/%d" position total))
          positions))

(ert-deftest smart-bury-test-messages-labelled-in-face ()
  "A command reports its position in the sequence, with the
\"Smart Bury:\" label in face `smart-bury-message-prefix'."
  (smart-bury-test-with-buffers ((a "sb-a") (b "sb-b"))
    (switch-to-buffer b)
    (switch-to-buffer a)
    (let* ((smart-bury-messages t)
           (messages (smart-bury-test-capturing-messages
                       (let ((last-command 'self-insert-command))
                         (smart-bury-switch-to-other-buffer)))))
      (should (equal (mapcar #'substring-no-properties messages)
                     (smart-bury-test-positions (smart-bury-test-total) 2)))
      (should (eq (get-text-property 0 'face (car messages))
                  'smart-bury-message-prefix)))))

(ert-deftest smart-bury-test-messages-positions-switching ()
  "Switching through buffers reports positions 2, 3... wrapping around
to 1 back on the initial buffer; switching to the other buffer
reports 1 on the initial buffer and 2 on the other one."
  (smart-bury-test-with-buffers ((a "sb-a") (b "sb-b") (c "sb-c"))
    (dolist (buffer (list c b a))
      (switch-to-buffer buffer))
    (let* ((smart-bury-messages t)
           (total (smart-bury-test-total))
           (messages
            (smart-bury-test-capturing-messages
              (let ((last-command 'self-insert-command))
                (smart-bury-switch-through-buffers))
              ;; On through every buffer, back to A.
              (dotimes (_ (1- total))
                (let ((last-command 'smart-bury-switch-through-buffers))
                  (smart-bury-switch-through-buffers)))
              (let ((last-command 'smart-bury-switch-through-buffers))
                (smart-bury-switch-through-buffers)
                (smart-bury-switch-through-buffers)
                (smart-bury-switch-to-other-buffer)
                (smart-bury-switch-to-other-buffer)))))
      (should (eq (current-buffer) b))
      (should (equal (mapcar #'substring-no-properties messages)
                     (append (apply #'smart-bury-test-positions total
                                    (number-sequence 2 total))
                             (smart-bury-test-positions total 1 2 3 1 2)))))))

(ert-deftest smart-bury-test-messages-positions-burying-and-killing ()
  "Burying reports the position the sequence lands on: 1 when it starts
a sequence, the depth reached when it continues one.  Killing a buffer
lowers the total."
  (smart-bury-test-with-buffers ((a "sb-a") (b "sb-b") (c "sb-c"))
    (dolist (buffer (list c b a))
      (switch-to-buffer buffer))
    (let* ((smart-bury-messages t)
           (total (smart-bury-test-total))
           (messages
            (smart-bury-test-capturing-messages
              (let ((last-command 'self-insert-command))
                (smart-bury-bury-buffer))
              (let ((last-command 'smart-bury-bury-buffer))
                (smart-bury-bury-buffer))
              (let ((last-command 'self-insert-command))
                (smart-bury-switch-through-buffers))
              (let ((last-command 'smart-bury-switch-through-buffers))
                (smart-bury-switch-through-buffers)
                (smart-bury-kill-current-buffer)))))
      (should (equal (mapcar #'substring-no-properties messages)
                     (append (smart-bury-test-positions total 1 1 2 3)
                             (smart-bury-test-positions (1- total) 3)))))))

(ert-deftest smart-bury-test-messages-disabled ()
  "With `smart-bury-messages' nil, commands report nothing."
  (smart-bury-test-with-buffers ((a "sb-a") (b "sb-b"))
    (switch-to-buffer b)
    (switch-to-buffer a)
    (let ((smart-bury-messages nil))
      (should-not (smart-bury-test-capturing-messages
                    (let ((last-command 'self-insert-command))
                      (smart-bury-switch-to-other-buffer)))))))

;;; README Introduction cases

;; Each test below replays one **Case** from the Introduction of
;; README.md and checks both where we land and the resulting "list of
;; all buffers".  Like the MRU tests above, they do NOT stub
;; `buffer-list': the cases are statements about its real ordering.

(defun smart-bury-test--order (buffers)
  "Make BUFFERS the head of the real `buffer-list', in order, with the
first one current and displayed in the selected window."
  (dolist (buffer (reverse buffers))
    (switch-to-buffer buffer)))

(defun smart-bury-test--names (buffers)
  "Return the names of BUFFERS in their current `buffer-list' order."
  (mapcar #'buffer-name
          (seq-filter (lambda (buffer) (memq buffer buffers))
                      (buffer-list (selected-frame)))))

(defvar smart-bury-test--previous 'self-insert-command
  "The command `smart-bury-test--run' last ran, i.e. the
`last-command' its next call sees.")

(defun smart-bury-test--run (&rest commands)
  "Call COMMANDS interactively in order, as if typed one after another.
Each call sees the previous one as `last-command', including across
successive calls to this function within one
`smart-bury-test-with-case'.  The symbol `work' stands for any
non-Smart Bury command (e.g. typing in the buffer), which ends the
current Smart Bury sequence."
  (dolist (command commands)
    (if (eq command 'work)
        (setq smart-bury-test--previous 'self-insert-command)
      (let ((last-command smart-bury-test--previous))
        (call-interactively command))
      (setq smart-bury-test--previous command))))

(defmacro smart-bury-test-with-case (&rest body)
  "Run BODY with fresh buffers A, B, C, D, and E bound to `a'...`e',
ordered so that the \"list of all buffers\" starts `A B C D E', `A'
being current, and no Smart Bury sequence in progress.  BUFS is bound
to the list of all five."
  (declare (indent 0))
  `(smart-bury-test-with-buffers ((a "A") (b "B") (c "C") (d "D") (e "E"))
     (let ((bufs (list a b c d e))
           (smart-bury-test--previous 'self-insert-command))
       (ignore bufs)
       (smart-bury-test--order bufs)
       ,@body)))

(ert-deftest smart-bury-test-readme-case-1 ()
  "Case 1: `C-x M--' buries `A', focuses `B', and leaves `B C D E A'."
  (smart-bury-test-with-case
    (smart-bury-test--run #'smart-bury-bury-buffer)
    (should (eq (current-buffer) b))
    (should (equal (smart-bury-test--names bufs) '("B" "C" "D" "E" "A")))))

(ert-deftest smart-bury-test-readme-case-2 ()
  "Case 2: `C-x _' (or `C-x M-_') goes to `B'; after working there,
the same key sequence comes back to `A', leaving the list untouched."
  (dolist (command '(smart-bury-switch-through-buffers
                     smart-bury-switch-to-other-buffer))
    (smart-bury-test-with-case
      (smart-bury-test--run command)
      (should (eq (current-buffer) b))
      (smart-bury-test--run 'work command)
      (should (eq (current-buffer) a))
      (should (equal (smart-bury-test--names bufs) '("A" "B" "C" "D" "E"))))))

(ert-deftest smart-bury-test-readme-case-3 ()
  "Case 3: `C-x _' (or `C-x M-_') presents `B' and an immediate `M-_'
gets back to `A', leaving the list untouched."
  (dolist (command '(smart-bury-switch-through-buffers
                     smart-bury-switch-to-other-buffer))
    (smart-bury-test-with-case
      (smart-bury-test--run command)
      (should (eq (current-buffer) b))
      (smart-bury-test--run #'smart-bury-switch-to-other-buffer)
      (should (eq (current-buffer) a))
      (should (equal (smart-bury-test--names bufs) '("A" "B" "C" "D" "E"))))))

(ert-deftest smart-bury-test-readme-case-4 ()
  "Case 4: `C-x _ _' reaches `C', `M-_' gets back to `A' with the list
untouched; then a new `C-x _' (or a continuing `_', `C-x M-_', or
`M-_') gets to `B'."
  (dolist (next '((work smart-bury-switch-through-buffers)
                  (smart-bury-switch-through-buffers)
                  (work smart-bury-switch-to-other-buffer)
                  (smart-bury-switch-to-other-buffer)))
    (smart-bury-test-with-case
      (smart-bury-test--run #'smart-bury-switch-through-buffers
                            #'smart-bury-switch-through-buffers)
      (should (eq (current-buffer) c))
      (smart-bury-test--run #'smart-bury-switch-to-other-buffer)
      (should (eq (current-buffer) a))
      (should (equal (smart-bury-test--names bufs) '("A" "B" "C" "D" "E")))
      (apply #'smart-bury-test--run next)
      (should (eq (current-buffer) b)))))

(ert-deftest smart-bury-test-readme-case-5 ()
  "Case 5: `C-x _ M--' buries `B' on the way to `C', and `M-_' gets
back to `A', leaving `A C D E B'.  After working on `A', repeating
with `C-x _' then `M-_' keeps that same list."
  (smart-bury-test-with-case
    (smart-bury-test--run #'smart-bury-switch-through-buffers
                          #'smart-bury-bury-buffer)
    (should (eq (current-buffer) c))
    (smart-bury-test--run #'smart-bury-switch-to-other-buffer)
    (should (eq (current-buffer) a))
    (should (equal (smart-bury-test--names bufs) '("A" "C" "D" "E" "B")))
    (smart-bury-test--run 'work #'smart-bury-switch-through-buffers)
    (should (eq (current-buffer) c))
    (smart-bury-test--run #'smart-bury-switch-to-other-buffer)
    (should (eq (current-buffer) a))
    (should (equal (smart-bury-test--names bufs) '("A" "C" "D" "E" "B")))))

(ert-deftest smart-bury-test-readme-case-6 ()
  "Case 6: with work in between, `C-x _ _' three times cycles
`A' -> `C' -> `B' -> `A', restoring the original list; without work in
between, `C-x _ _' twice is `C-x _ _ _ _', reaching `E'."
  (smart-bury-test-with-case
    (dolist (expected (list c b a))
      (smart-bury-test--run 'work
                            #'smart-bury-switch-through-buffers
                            #'smart-bury-switch-through-buffers)
      (should (eq (current-buffer) expected)))
    (should (equal (smart-bury-test--names bufs) '("A" "B" "C" "D" "E"))))
  (smart-bury-test-with-case
    (smart-bury-test--run #'smart-bury-switch-through-buffers
                          #'smart-bury-switch-through-buffers
                          #'smart-bury-switch-through-buffers
                          #'smart-bury-switch-through-buffers)
    (should (eq (current-buffer) e))))

(ert-deftest smart-bury-test-readme-case-7 ()
  "Case 7: `q _' from `A' (where `q' is `quit-window', remapped)
quits `A' and reaches `C', leaving `C B D E A'."
  (smart-bury-test-with-case
    (smart-bury-test--run #'smart-bury-quit-window
                          #'smart-bury-switch-through-buffers)
    (should (eq (current-buffer) c))
    (should (equal (smart-bury-test--names bufs) '("C" "B" "D" "E" "A")))))

(ert-deftest smart-bury-test-readme-why-smart ()
  "\"Why is it smart?\": going to `B' and immediately burying it
reaches `C', not `A'; but after working on `B', burying it gets back
to `A', and an immediate `_' then reaches `C'."
  (smart-bury-test-with-case
    (smart-bury-test--run #'smart-bury-switch-through-buffers
                          #'smart-bury-bury-buffer)
    (should (eq (current-buffer) c)))
  (smart-bury-test-with-case
    (smart-bury-test--run #'smart-bury-switch-through-buffers
                          'work
                          #'smart-bury-bury-buffer)
    (should (eq (current-buffer) a))
    (smart-bury-test--run #'smart-bury-switch-through-buffers)
    (should (eq (current-buffer) c))))

;;; `smart-bury-mode'

(ert-deftest smart-bury-test-mode-binds-switch-commands ()
  "Enabling the mode binds its two keys to the Smart Bury
switching commands; disabling it removes them again."
  (smart-bury-test-with-mode
    (should (eq (key-binding (kbd "C-x _")) #'smart-bury-switch-through-buffers))
    (should (eq (key-binding (kbd "C-x M-_")) #'smart-bury-switch-to-other-buffer)))
  (should-not (eq (key-binding (kbd "C-x _")) #'smart-bury-switch-through-buffers))
  (should-not (eq (key-binding (kbd "C-x M-_")) #'smart-bury-switch-to-other-buffer)))

(ert-deftest smart-bury-test-mode-map-remaps-vanilla-commands ()
  "The mode's keymap remaps the three vanilla commands to their
Smart Bury equivalents, regardless of what key they are bound to."
  (should (eq (lookup-key smart-bury-mode-map [remap bury-buffer])
             #'smart-bury-bury-buffer))
  (should (eq (lookup-key smart-bury-mode-map [remap quit-window])
             #'smart-bury-quit-window))
  (should (eq (lookup-key smart-bury-mode-map [remap kill-current-buffer])
             #'smart-bury-kill-current-buffer)))

(ert-deftest smart-bury-test-mode-remap-active-when-enabled ()
  "`command-remapping' only resolves `bury-buffer' to
`smart-bury-bury-buffer' while the mode is enabled -- i.e. the remap
is actually live in the active keymaps, not just present in
`smart-bury-mode-map' in isolation."
  (should-not (command-remapping 'bury-buffer))
  (smart-bury-test-with-mode
    (should (eq (command-remapping 'bury-buffer) #'smart-bury-bury-buffer)))
  (should-not (command-remapping 'bury-buffer)))

;;; `smart-bury-prefix-key' and `smart-bury-keys'

(ert-deftest smart-bury-test-keys-custom-prefix-and-keys ()
  "A custom prefix and keys bind the commands under the new keys,
and the default `C-x _' no longer reaches the Smart Bury command."
  (smart-bury-test-with-keys "C-c" '((smart-bury-switch-through-buffers . "n")
                                    (smart-bury-switch-to-other-buffer . "o"))
    (should (eq (lookup-key smart-bury-mode-map (kbd "C-c n"))
                #'smart-bury-switch-through-buffers))
    (should (eq (lookup-key smart-bury-mode-map (kbd "C-c o"))
                #'smart-bury-switch-to-other-buffer))
    (should-not (eq (lookup-key smart-bury-mode-map (kbd "C-x _"))
                    #'smart-bury-switch-through-buffers))))

(ert-deftest smart-bury-test-keys-repeat-map-follows-keys ()
  "Each command's key is also its single-key repeat in
`smart-bury-repeat-map', and the old repeat key goes away."
  (smart-bury-test-with-keys "C-x" '((smart-bury-switch-through-buffers . "n"))
    (should (eq (lookup-key smart-bury-repeat-map (kbd "n"))
                #'smart-bury-switch-through-buffers))
    (should-not (lookup-key smart-bury-repeat-map (kbd "_")))))

(ert-deftest smart-bury-test-keys-empty-prefix-binds-bare-key ()
  "An empty prefix binds each key directly."
  (smart-bury-test-with-keys "" '((smart-bury-switch-through-buffers . "<f9>"))
    (should (eq (lookup-key smart-bury-mode-map (kbd "<f9>"))
                #'smart-bury-switch-through-buffers))))

(ert-deftest smart-bury-test-keys-skips-multi-key-entry-with-warning ()
  "A key that is not a single event is skipped with a warning; the
other entries still get bound."
  (let (warnings)
    (cl-letf (((symbol-function 'display-warning)
               (lambda (type message &rest _) (push (cons type message) warnings))))
      (smart-bury-test-with-keys "C-x" '((smart-bury-switch-through-buffers . "a b")
                                        (smart-bury-switch-to-other-buffer . "o"))
        (should warnings)
        (should-not (eq (lookup-key smart-bury-mode-map (kbd "C-x a b"))
                        #'smart-bury-switch-through-buffers))
        (should (eq (lookup-key smart-bury-mode-map (kbd "C-x o"))
                    #'smart-bury-switch-to-other-buffer))))))

(ert-deftest smart-bury-test-keys-user-mode-map-binding-survives ()
  "A user's own binding in `smart-bury-mode-map' survives later
customization of both `smart-bury-wrapped-commands' and
`smart-bury-keys'."
  (unwind-protect
      (progn
        (define-key smart-bury-mode-map (kbd "C-c z") #'ignore)
        (smart-bury-test-with-wrapped-commands '(kill-current-buffer)
          (should (eq (lookup-key smart-bury-mode-map (kbd "C-c z")) #'ignore)))
        (smart-bury-test-with-keys "C-c" '((smart-bury-switch-through-buffers . "n"))
          (should (eq (lookup-key smart-bury-mode-map (kbd "C-c z")) #'ignore))))
    (define-key smart-bury-mode-map (kbd "C-c z") nil)))

(ert-deftest smart-bury-test-keys-user-repeat-map-binding-survives ()
  "A user's own binding in `smart-bury-repeat-map' survives later
customization of `smart-bury-keys'."
  (unwind-protect
      (progn
        (define-key smart-bury-repeat-map (kbd "M-Q") #'smart-bury-kill-current-buffer)
        (smart-bury-test-with-keys "C-c" '((smart-bury-switch-through-buffers . "n"))
          (should (eq (lookup-key smart-bury-repeat-map (kbd "M-Q"))
                      #'smart-bury-kill-current-buffer))))
    (define-key smart-bury-repeat-map (kbd "M-Q") nil)))

;;; `smart-bury-wrapped-commands'

(ert-deftest smart-bury-test-wrapped-commands-default-defines-expected-wrappers ()
  "The default value generates `smart-bury-quit-window' and
`smart-bury-kill-current-buffer', and both are tracked in
`smart-bury--commands'."
  (should (fboundp 'smart-bury-quit-window))
  (should (fboundp 'smart-bury-kill-current-buffer))
  (should (memq 'smart-bury-quit-window smart-bury--commands))
  (should (memq 'smart-bury-kill-current-buffer smart-bury--commands)))

(ert-deftest smart-bury-test-wrapped-commands-excludes-removed-entry ()
  "Excluding `quit-window' from the list removes it from
`smart-bury--commands' and drops its remap from `smart-bury-mode-map',
while `kill-current-buffer' -- still in the list -- keeps its remap."
  (smart-bury-test-with-wrapped-commands '(kill-current-buffer)
    (should-not (memq 'smart-bury-quit-window smart-bury--commands))
    (should-not (lookup-key smart-bury-mode-map [remap quit-window]))
    (should (memq 'smart-bury-kill-current-buffer smart-bury--commands))
    (should (eq (lookup-key smart-bury-mode-map [remap kill-current-buffer])
               #'smart-bury-kill-current-buffer))))

(ert-deftest smart-bury-test-wrapped-commands-includes-new-entry ()
  "Adding an arbitrary interactive command to the list defines its
wrapper and tracks it in `smart-bury--commands'."
  (smart-bury-test-with-wrapped-commands '(quit-window kill-current-buffer other-window)
    (should (fboundp 'smart-bury-other-window))
    (should (memq 'smart-bury-other-window smart-bury--commands))
    (should (eq (lookup-key smart-bury-mode-map [remap other-window])
               #'smart-bury-other-window))
    (should (eq (get 'smart-bury-other-window 'repeat-map) 'smart-bury-repeat-map))))

(ert-deftest smart-bury-test-wrapped-commands-restored-after-macro ()
  "Sanity check that `smart-bury-test-with-wrapped-commands' actually
restores the previous configuration afterward."
  (let ((before smart-bury-wrapped-commands))
    (smart-bury-test-with-wrapped-commands '(kill-current-buffer))
    (should (equal smart-bury-wrapped-commands before))
    (should (memq 'smart-bury-quit-window smart-bury--commands))))

(defvar smart-bury-test--recorded-arg nil
  "Argument last received by `smart-bury-test--define-recording-command'.")

(defun smart-bury-test--define-recording-command (name)
  "Define NAME as a command recording its prefix-arg argument.
The argument goes to `smart-bury-test--recorded-arg'."
  (defalias name (lambda (&optional arg)
                   (interactive "P")
                   (setq smart-bury-test--recorded-arg arg))))

(ert-deftest smart-bury-test-wrapped-commands-wraps-undefined-command-without-warning ()
  "A command not defined yet (e.g. from a package loaded after Smart
Bury) is wrapped anyway, without any warning: its wrapper is defined,
tracked in `smart-bury--commands', remapped, and repeatable."
  (should-not (fboundp 'smart-bury-test--later-cmd)) ; sanity
  (let (warnings)
    (cl-letf (((symbol-function 'display-warning)
               (lambda (type message &rest _) (push (cons type message) warnings))))
      (smart-bury-test-with-wrapped-commands
          '(quit-window smart-bury-test--later-cmd kill-current-buffer)
        (should-not warnings)
        (should (commandp 'smart-bury-smart-bury-test--later-cmd))
        (should (memq 'smart-bury-smart-bury-test--later-cmd smart-bury--commands))
        (should (eq (lookup-key smart-bury-mode-map [remap smart-bury-test--later-cmd])
                    #'smart-bury-smart-bury-test--later-cmd))
        (should (eq (get 'smart-bury-smart-bury-test--later-cmd 'repeat-map)
                    'smart-bury-repeat-map))
        (should (memq 'smart-bury-quit-window smart-bury--commands))))))

(ert-deftest smart-bury-test-wrapped-commands-wrapper-uses-command-defined-later ()
  "A wrapper generated while its command was still undefined runs
that command once it is defined, with the arguments read by the
command's own `interactive' spec (here, the prefix argument)."
  (smart-bury-test-with-buffers ((a "sb-a"))
    (switch-to-buffer a)
    (smart-bury-test-with-wrapped-commands '(smart-bury-test--later-cmd)
      (unwind-protect
          (progn
            (smart-bury-test--define-recording-command 'smart-bury-test--later-cmd)
            (setq smart-bury-test--recorded-arg nil)
            (let ((current-prefix-arg '(4))
                  (last-command 'some-other-command))
              (call-interactively 'smart-bury-smart-bury-test--later-cmd))
            (should (equal smart-bury-test--recorded-arg '(4))))
        (fmakunbound 'smart-bury-test--later-cmd)))))

(ert-deftest smart-bury-test-wrapped-commands-wrapper-of-undefined-command-signals-user-error ()
  "Calling a wrapper whose command is still undefined signals a
`user-error', before touching the Smart Bury sequence state."
  (smart-bury-test-with-buffers ((a "sb-a") (b "sb-b"))
    (switch-to-buffer a)
    (smart-bury-test-with-wrapped-commands '(smart-bury-test--later-cmd)
      (setq smart-bury--initial-buffer b)
      (let ((last-command 'some-other-command))
        (should-error (call-interactively 'smart-bury-smart-bury-test--later-cmd)
                      :type 'user-error))
      (should (eq smart-bury--initial-buffer b)))))

(defvar smart-bury-test--lib-loaded nil
  "Set by the library of `smart-bury-test--autoloaded-cmd' when loaded.")

(ert-deftest smart-bury-test-wrapped-commands-does-not-load-autoloaded-command ()
  "Wrapping an autoloaded command does not load its library."
  (let ((file (make-temp-file
               "smart-bury-test-lib" nil ".el"
               (concat "(setq smart-bury-test--lib-loaded t)\n"
                       "(defun smart-bury-test--autoloaded-cmd () (interactive))\n"))))
    (setq smart-bury-test--lib-loaded nil)
    (unwind-protect
        (progn
          (autoload 'smart-bury-test--autoloaded-cmd file nil t)
          (smart-bury-test-with-wrapped-commands '(smart-bury-test--autoloaded-cmd)
            (should (commandp 'smart-bury-smart-bury-test--autoloaded-cmd))
            (should-not smart-bury-test--lib-loaded)))
      (fmakunbound 'smart-bury-test--autoloaded-cmd)
      (delete-file file))))

(ert-deftest smart-bury-test-wrapped-commands-type-accepts-undefined-command ()
  "The option's custom type accepts a command not defined yet, so
`setopt' and Customize do not complain about it."
  (require 'wid-edit)
  (should (widget-apply (widget-convert (get 'smart-bury-wrapped-commands 'custom-type))
                        :match '(quit-window smart-bury-test--later-cmd))))

(ert-deftest smart-bury-test-wrapped-commands-skips-non-interactive-function-with-warning ()
  "A defined-but-non-interactive function (no `interactive' spec), or
a nil entry, is skipped with a warning instead of an error, while the
other entries still get wrapped."
  (should-not (interactive-form #'+)) ; sanity: `+' is real but non-interactive
  (let (warnings)
    (cl-letf (((symbol-function 'display-warning)
               (lambda (type message &rest _) (push (cons type message) warnings))))
      (smart-bury-test-with-wrapped-commands '(quit-window + nil)
        (should (= (length warnings) 2))
        (should-not (fboundp 'smart-bury-+))
        (should-not (fboundp 'smart-bury-nil))
        (should (memq 'smart-bury-quit-window smart-bury--commands))))))

;;; `smart-bury-repeatable-commands'

(ert-deftest smart-bury-test-repeatable-commands-arm-repeat-map-when-mode-on ()
  "While `smart-bury-mode' is on, a listed command arms
`smart-bury-repeat-map' whichever key invoked it, even if the command
is not defined yet."
  (let ((cmd (make-symbol "sb-cmd")))
    (smart-bury-test-with-mode
      (smart-bury-test-with-repeatable-commands (list cmd)
        (should (eq (get cmd 'repeat-map) 'smart-bury-repeat-map))
        (should (eq (get cmd 'repeat-check-key) 'no))))))

(ert-deftest smart-bury-test-repeatable-commands-inactive-when-mode-off ()
  "A listed command is left alone while `smart-bury-mode' is off, and
gets its properties back once the mode is turned off."
  (let ((cmd (make-symbol "sb-cmd")))
    (smart-bury-test-with-repeatable-commands (list cmd)
      (should-not (get cmd 'repeat-map))
      (smart-bury-test-with-mode
        (should (eq (get cmd 'repeat-map) 'smart-bury-repeat-map)))
      (should-not (get cmd 'repeat-map))
      (should-not (get cmd 'repeat-check-key)))))

(ert-deftest smart-bury-test-repeatable-commands-restore-own-repeat-map ()
  "A command's own repeat map is replaced while the command is listed,
and restored, with its `repeat-check-key', when it is removed from the
list."
  (let ((cmd (make-symbol "sb-cmd")))
    (put cmd 'repeat-map 'sb-own-map)
    (put cmd 'repeat-check-key t)
    (smart-bury-test-with-mode
      (smart-bury-test-with-repeatable-commands (list cmd)
        (should (eq (get cmd 'repeat-map) 'smart-bury-repeat-map))
        (customize-set-variable 'smart-bury-repeatable-commands nil)
        (should (eq (get cmd 'repeat-map) 'sb-own-map))
        (should (eq (get cmd 'repeat-check-key) t))))))

(ert-deftest smart-bury-test-repeatable-commands-keep-property-set-meanwhile ()
  "A repeat map given to a listed command after Smart Bury replaced its
own (e.g. by its package, loaded later) is not undone when the mode is
turned off."
  (let ((cmd (make-symbol "sb-cmd")))
    (smart-bury-test-with-repeatable-commands (list cmd)
      (smart-bury-test-with-mode
        (put cmd 'repeat-map 'sb-later-map))
      (should (eq (get cmd 'repeat-map) 'sb-later-map)))))

(ert-deftest smart-bury-test-repeatable-commands-skip-non-command-with-warning ()
  "A nil entry or a defined but non-interactive function is skipped
with a warning, while the other entries are still made repeatable."
  (let ((cmd (make-symbol "sb-cmd"))
        warnings)
    (cl-letf (((symbol-function 'display-warning)
               (lambda (type message &rest _) (push (cons type message) warnings))))
      (smart-bury-test-with-mode
        (smart-bury-test-with-repeatable-commands (list nil '+ cmd)
          (should (= (length warnings) 2))
          (should-not (get '+ 'repeat-map))
          (should (eq (get cmd 'repeat-map) 'smart-bury-repeat-map)))))))

(provide 'smart-bury-tests)

;;; smart-bury-tests.el ends here
