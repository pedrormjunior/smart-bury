# Smart Bury

The idea behind Smart Bury is in its name: *bury*, not banish. Getting
a buffer out of the way need not mean losing track of it — it should
remain one keystroke away, simply no longer in front. That is a
different mindset from "close" or "discard": the buffer is not
finished with, only no longer in focus *right now*. Smart Bury has no
notion of which buffer is actually wanted next — that choice stays
with whoever is pressing the key — it only makes repeated presses of
the same key land somewhere deliberate, instead of wherever Emacs's
own internal bookkeeping happens to produce.

Smart Bury wraps `bury-buffer`, `quit-window`, and
`kill-current-buffer` — and adds two buffer-switching commands of its
own — so that a *sequence* of presses walks through recently-used
buffers, one per press, cycling back around once it runs out. Once
the sequence is interrupted by some other command, the next press
starts a fresh sequence from wherever focus happens to be.

Consider three buffers — A, B, and C — in active use, shown one at a
time in a single window with no split needed. Switching to whichever
of the other two was used most recently costs nothing: `C-x b RET`
already defaults to it. Reaching the third one does not: Emacs offers
only that one default target, so getting to the other one means
typing its name in full. Repeated plain `bury-buffer` presses do not
reliably help either, since each one's target is simply whatever that
window's own history happens to contain, not a deliberate choice.

Starting in A, switching to B costs nothing, as above. Done with B,
and really wanting C, burying it with plain `bury-buffer` returns to
A — not C, since A is only what that window showed right before B.
`smart-bury-bury-buffer` behaves the same way on this first press,
also landing on A; but burying again, continuing the same sequence,
reaches C directly — without a buffer name ever being typed.

`smart-bury-switch-through-buffers` has no equivalent among the
vanilla commands at all, and is useful well beyond that one case.
Starting in A and heading for C, with B expected to be useful again
shortly, two presses reach C directly. After working there, two more
presses lead back toward B — the first already passing through A,
which is never out of reach even while attention is elsewhere.

Pressing the same key repeatedly like this is, in fact, the whole
point, which is why
[Repeating with `repeat-mode`](#repeating-with-repeat-mode) below
matters: each pair of presses above — the two that reach C, and
later the two that head back toward B — reduces to one chord (`C-x
_`) followed by a single tap of the last key, with work on C in
between resetting the count, as it should. Everything here assumes
one window showing one buffer at a time for simplicity, but the same
mechanism applies unchanged with buffers split across several windows
instead.

## Commands

- `smart-bury-bury-buffer` — like `bury-buffer`, but smart.
- `smart-bury-quit-window` — like `quit-window`, but smart. Generated
  from `smart-bury-wrapped-commands` (see below), not hand-written.
- `smart-bury-kill-current-buffer` — like `kill-current-buffer`, but
  smart (also generated; see below).
- `smart-bury-switch-through-buffers` — cumulatively switch to the
  next recently-used buffer on every press (no underlying Emacs
  command — this one is specific to Smart Bury).
- `smart-bury-switch-to-other-buffer` — switches to the buffer the current
  sequence started from. If already back on that buffer, switches
  instead to the "other" (next most recently used) buffer, so
  pressing it repeatedly toggles back and forth between the two (also
  specific to Smart Bury).

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
