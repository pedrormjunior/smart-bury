# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

- Run the test suite: `make test`
  (equivalent to `emacs -batch -l ert -l smart-bury.el -l smart-bury-tests.el -f ert-run-tests-batch-and-exit`)
- Run a single test: `emacs -batch -l ert -l smart-bury.el -l smart-bury-tests.el -f ert-run-tests-batch-and-exit --eval "(ert-run-tests-batch-and-exit \"test-name-regexp\")"`,
  or interactively via `emacsclient` (see `emacs-skills:emacsclient` — always use `emacsclient`, not `emacs`, for interactive elisp work, byte compilation, or `check-parens`).

Important: No need to run tests after every modification, mainly if
they are minor and simple.  Only run tests when a major modification
is performed and we're not sure about the correctness of the code.

## Architecture

Smart Bury is a single-file Emacs package (`smart-bury.el`) that wraps `bury-buffer`, `quit-window`, and `kill-current-buffer` so that repeated invocations cycle through recently-used buffers instead of landing on an arbitrary one.

Core mechanism:
- `smart-bury-commands` lists the package's own interactive commands. `smart-bury--starts-now-p` checks `last-command` against this list to detect whether the current invocation continues a sequence or starts a fresh one.
- `smart-bury-initial-buffer` (the buffer active when a sequence started) and `smart-bury-counter` (how many buffers deep into the cycle we are) are the two pieces of global state threaded through a sequence of calls.
- `smart-bury--run-function` is the shared wrapper used by `smart-bury-bury-buffer` and `smart-bury-quit-window`: it calls the underlying Emacs function, then — unless this is a fresh sequence — switches through `smart-bury-counter` eligible buffers via `smart-bury--go-through-buffers`, keeping `smart-bury-initial-buffer` in sync with wherever the sequence actually lands.
- `smart-bury-switch-through-buffers` and `smart-bury-switch-to-other-buffer` instead call `smart-bury--go-through-buffers` directly (no underlying Emacs function to delegate to), incrementing/pinning the counter themselves.
- `smart-bury--go-through-buffers` walks `(buffer-list)` (scoped to the selected frame when `smart-bury-same-frame` is non-nil), skipping the minibuffer, buffers already displayed in a window (unless `allow-current`), and buffers whose name starts with `" *"`, until it collects `smart-bury-counter` eligible buffers; it switches through all but the last and returns the last.

Known open issues are tracked in `IMPROVEMENTS.md` (unbounded loop risk in `smart-bury--go-through-buffers` when fewer than `smart-bury-counter` buffers are eligible, no `buffer-live-p` guard on caller-supplied buffer lists, missing README/license, and an unconfirmed suspected bug in `smart-bury-kill-current-buffer`).

Tests in `smart-bury-tests.el` use two macros: `smart-bury-test-with-buffers` (creates fresh buffers, resets global state, always kills the buffers afterward) and `smart-bury-test-with-buffer-list` (stubs `buffer-list` to a fixed set). Note that `bury-buffer`/`quit-window` pick their target via the *selected window's* own prev/next-buffer history, not via `buffer-list` — so tests for those commands check the counter/initial-buffer bookkeeping invariant rather than the exact destination buffer.

## When committing modifications

Include your signature in the body of the commit message.
Commit message should start with lowercase, unless the first word is a noun.
