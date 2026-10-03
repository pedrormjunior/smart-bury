# Smart Bury

`bury-buffer`, `quit-window`, and `kill-current-buffer` all drop you
on *some* buffer afterward, but not necessarily a useful one — Emacs
picks it from its own internal buffer list, which doesn't line up
with what you, the user, were recently looking at. Press the same
key a few times in a row to get rid of several buffers, and you can
easily end up stranded somewhere unrelated to anything you were
working on.

Smart Bury wraps those three commands (plus two buffer-switching
commands of its own) so that a *sequence* of presses walks you
through your own recently-used buffers instead, one per press,
cycling back around once it runs out. Stop pressing, do something
else, and the next press starts a fresh sequence from wherever you
are.

## Commands

- `smart-bury-bury-buffer` — like `bury-buffer`, but smart.
- `smart-bury-quit-window` — like `quit-window`, but smart.
- `smart-bury-kill-current-buffer` — like `kill-current-buffer`, but
  smart.
- `smart-bury-switch-through-buffers` — cumulatively switch to the
  next recently-used buffer on every press (no underlying Emacs
  command — this one is specific to Smart Bury).
- `smart-bury-switch-to-other-buffer` — jump straight to the
  previous buffer, like a quick "toggle back" (also specific to
  Smart Bury).

## Configuration

Smart Bury doesn't bind any keys itself. The intended setup is to
remap the vanilla commands to their Smart Bury equivalents, so your
existing muscle memory (and any third-party keybindings) keeps
working, just smarter:

```elisp
(use-package smart-bury
  :bind (([remap bury-buffer]          . smart-bury-bury-buffer)
         ([remap quit-window]          . smart-bury-quit-window)
         ([remap kill-current-buffer]  . smart-bury-kill-current-buffer)
         ("C-c b" . smart-bury-switch-through-buffers)
         ("C-c o" . smart-bury-switch-to-other-buffer)))
```

(`smart-bury-switch-through-buffers` and
`smart-bury-switch-to-other-buffer` have no vanilla command to remap
from, so pick whatever keys suit you.)

By default, Smart Bury only considers buffers from the current
frame. To consider recently-used buffers across all frames instead,
customize `smart-bury-same-frame`:

```elisp
(setq smart-bury-same-frame nil)
```

## Development

See `IMPROVEMENTS.md` for known open issues, and run the test suite
with `make test`.
