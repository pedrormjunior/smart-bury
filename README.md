# Smart Bury

`bury-buffer`, `quit-window`, and `kill-current-buffer` all drop you
on *some* buffer afterward, but not necessarily a useful one — Emacs
picks it from its own internal buffer list, which might not line up
with what you, the user, want to focus. Press the same key a few times
in a row to get rid of several buffers, and you can easily end up
stranded somewhere unrelated to anything you were working on.

Smart Bury wraps those three commands (plus two buffer-switching
commands of its own) so that a *sequence* of presses walks you
through your own recently-used buffers instead, one per press,
cycling back around once it runs out. Stop pressing, do something
else, and the next press starts a fresh sequence from wherever you
are.

## Commands

- `smart-bury-bury-buffer` — like `bury-buffer`, but smart.
- `smart-bury-quit-window` — like `quit-window`, but smart. Generated
  from `smart-bury-wrapped-commands` (see below), not hand-written.
- `smart-bury-kill-current-buffer` — like `kill-current-buffer`, but
  smart (also generated; see below).
- `smart-bury-switch-through-buffers` — cumulatively switch to the
  next recently-used buffer on every press (no underlying Emacs
  command — this one is specific to Smart Bury).
- `smart-bury-switch-to-other-buffer` — jump straight to the
  previous buffer, like a quick "toggle back" (also specific to
  Smart Bury).

## Configuration

Smart Bury doesn't bind any keys itself by default, but it ships a
global minor mode, `smart-bury-mode`, that does: enable it and the
vanilla commands (`bury-buffer`, `quit-window`,
`kill-current-buffer`) are remapped to their Smart Bury equivalents
everywhere, plus `C-x _` and `C-x M-_` are bound to
`smart-bury-switch-through-buffers` and
`smart-bury-switch-to-other-buffer`:

```elisp
(use-package smart-bury
  :config (smart-bury-mode 1))
```

See `smart-bury-mode-map` for the exact bindings; `define-key` into
it (before or after enabling the mode) to change any of them.

If you'd rather not use the mode — e.g. to pick your own keys
instead of its defaults — remap the vanilla commands to their Smart
Bury equivalents yourself, so your existing muscle memory (and any
third-party keybindings) keeps working, just smarter:

```elisp
(use-package smart-bury
  :bind (([remap bury-buffer]          . smart-bury-bury-buffer)
         ([remap quit-window]          . smart-bury-quit-window)
         ([remap kill-current-buffer]  . smart-bury-kill-current-buffer)
         ("C-x M--" . bury-buffer)
         ("C-x _" . smart-bury-switch-through-buffers)
         ("C-x M-_" . smart-bury-switch-to-other-buffer)))
```

(`smart-bury-switch-through-buffers` and
`smart-bury-switch-to-other-buffer` have no vanilla command to remap
from, so pick whatever keys suit you.  Aligned to the recommendation
inhere, we suggest binding `bury-buffer` to `C-x -`.)

### Wrapping other commands

`smart-bury-quit-window` and `smart-bury-kill-current-buffer` aren't
hand-written — they're generated from `smart-bury-wrapped-commands`
(default: `(quit-window kill-current-buffer)`), each entry FN getting
a `smart-bury-FN` command that calls FN via the same cycling
machinery as `smart-bury-bury-buffer`, reusing FN's own `interactive`
spec. (`smart-bury-bury-buffer` itself is defined separately, since
it alone has a fixed default keybinding, `C-x M--`, in
`smart-bury-mode-map`.)

Setting this variable — via `setopt` or `M-x customize-variable` —
regenerates the wrapper commands immediately, and keeps
`smart-bury-commands`, `smart-bury-mode-map`'s remaps, and
`smart-bury-repeat-map`'s properties in sync. For example, to drop
`kill-current-buffer` entirely and instead wrap `View-quit`:

```elisp
(setopt smart-bury-wrapped-commands '(quit-window View-quit))
```

### Repeating with `repeat-mode`

All five Smart Bury commands declare a `repeat-map`, so if you already
have Emacs's built-in `repeat-mode` turned on, invoking one of them
lets you repeat it with just a single key afterward instead of
retyping the whole chord — e.g. after `C-x _`, pressing `_` again
keeps cycling. `smart-bury-mode` does not enable `repeat-mode` itself
(it's an independent, global setting unrelated to Smart Bury's own
purpose); turn it on yourself if you want this (recommended):

```elisp
(repeat-mode 1)
```

Smart Bury also sets `repeat-check-key` to `no`, so the repeat-map
arms regardless of *which key actually invoked the command* — not just
its default binding. This matters most for `smart-bury-quit-window`
and `smart-bury-kill-current-buffer`: they only reach the user via a
remap of whatever key `quit-window`/`kill-current-buffer` are bound to
(e.g. `q` in many read-only modes), so there's no fixed key of their
own to require. With the check relaxed, even invoking one of those
through such a mode-local `q` arms the map — meaning, for instance,
that after `q` is pressed in a certain read-only mode, the user is
ready to navigate through the buffers in repeat-mode.

If one prefers to disable this behavior, it is enough to `(put
'smart-bury-<function> 'repeat-check-key t)`.

Neither `smart-bury-quit-window` nor `smart-bury-kill-current-buffer`
has a default key of its own in `smart-bury-repeat-map` (unlike the
other three) — add one yourself, using whichever key you actually
invoke it with, e.g. for a `kill-current-buffer` bound to `M-Q`:

```elisp
(define-key smart-bury-repeat-map (kbd "M-Q") #'smart-bury-kill-current-buffer)
```

By default, Smart Bury only considers buffers from the current
frame. To consider recently-used buffers across all frames instead,
customize `smart-bury-same-frame`:

```elisp
(setq smart-bury-same-frame nil)
```

## Development

See `IMPROVEMENTS.md` for known open issues, and run the test suite
with `make test`.
