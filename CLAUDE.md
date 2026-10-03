# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

- Run the test suite: `make test`
  (equivalent to `emacs -batch -l ert -l smart-bury.el -l smart-bury-tests.el -f ert-run-tests-batch-and-exit`)
- Run a single test: `emacs -batch -l ert -l smart-bury.el -l smart-bury-tests.el -f ert-run-tests-batch-and-exit --eval "(ert-run-tests-batch-and-exit \"test-name-regexp\")"`,
  or interactively via `emacsclient` (see `emacs-skills:emacsclient` — always use `emacsclient`, not `emacs`, for interactive elisp work, byte compilation, or `check-parens`).
- Try the package interactively, isolated from the user's own init file: `make test-interactively` (loads `smart-bury.el` and `test-interactively.el` under `emacs -Q`; see that file for what it sets up — enabling `smart-bury-mode`/`repeat-mode`, a repeat binding for `smart-bury-kill-current-buffer`, and a few throwaway buffers).

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
- `smart-bury--go-through-buffers` first filters `(buffer-list)` (scoped to the selected frame when `smart-bury-same-frame` is non-nil) down to the eligible buffers (skipping the minibuffer, buffers already displayed in a window unless `allow-current`, and buffers whose name starts with `" *"`), signaling `user-error` immediately if none qualify. It then cycles through that eligible list in laps until it has collected `smart-bury-counter` buffers (wrapping around as needed — each lap is guaranteed to make progress since the eligible list is non-empty, so this always terminates), switches through all but the last, and returns the last. Preserving the lap-by-lap switching (rather than jumping straight to the final buffer) matters: those intermediate `switch-to-buffer` calls are what keep Emacs's real most-recently-used buffer order consistent with the counter, which `smart-bury-switch-to-other-buffer` relies on to land back on the original buffer after a run of `smart-bury-switch-through-buffers` calls.
- `smart-bury-mode` is a global minor mode (`smart-bury-mode-map`) that remaps `bury-buffer`/`quit-window`/`kill-current-buffer` to their Smart Bury equivalents via `[remap ...]` entries, binds `C-x M--` to plain `bury-buffer` (so it resolves through the remap), and binds `C-x _`/`C-x M-_` to the two Smart-Bury-only commands.
- `smart-bury-repeat-map` lets Emacs's built-in `repeat-mode` repeat a command with a single key once invoked. All five commands get `repeat-map` set to it and `repeat-check-key` set to `no`, so the map arms regardless of which key actually triggered the command — notably `quit-window`/`kill-current-buffer`, which only reach Smart Bury through a remap of whatever key the major mode already binds them to, and so have no fixed key of their own.

Known open issues are tracked in `IMPROVEMENTS.md` (no `buffer-live-p` guard on caller-supplied buffer lists in `smart-bury--go-through-buffers`, an unconfirmed suspected bug in `smart-bury-kill-current-buffer`, and a missing license header).

Tests in `smart-bury-tests.el` use several macros: `smart-bury-test-with-buffers` (creates fresh buffers, resets global state, always kills the buffers afterward), `smart-bury-test-with-buffer-list` (stubs `buffer-list` to a fixed set), and `smart-bury-test-with-mode` (enables `smart-bury-mode` for the duration, always disabling it afterward). Note that `bury-buffer`/`quit-window` pick their target via the *selected window's* own prev/next-buffer history, not via `buffer-list` — so tests for those commands check the counter/initial-buffer bookkeeping invariant rather than the exact destination buffer. The one test that exercises the real (unstubbed) `buffer-list` MRU reordering — `smart-bury-test-switch-through-then-switch-to-other-returns-to-origin` — exists because a prior refactor of `smart-bury--go-through-buffers` passed every other test while silently breaking that invariant; the stubbed-buffer-list tests can't catch that class of regression.

`test-interactively.el` (run via `make test-interactively`) is a separate, non-ERT file for manually trying the package out in an isolated `emacs -Q` session — not for automated testing.

## When committing modifications

Include your signature in the body of the commit message.
Commit message should start with lowercase, unless the first word is a noun.
