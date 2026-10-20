# Smart Bury

*Keep wanted buffers at the top of the “list of all buffers”.*

Smart Bury makes switching buffers in a window a matter of a few
repeated key presses: bury, quit, or kill the current buffer, or go
through the most recently used buffers, without typing any buffer
name.  It is “smart” in the sense that if we go from `A` to `B` and
immediately bury `B`, it takes us straight to `C` instead of coming
back to `A` — `B` was simply on the way (see [Why is it
“smart”?](#why-is-it-smart)).

## Motivation

The interactive function `bury-buffer` comes with Emacs but is not
bound to any key by default.  Function `(bury-buffer &optional
BUFFER-OR-NAME)`, as its documentation says, will basically “Put
BUFFER-OR-NAME at the end of the list of all buffers.”  When called
interactively, it buries the *current buffer*.

The function `switch-to-buffer` is bound to `C-x b` by default:
interactively, it basically asks for the buffer we want to switch to,
offering as default the “most recently selected buffer other than” the
*current* buffer, i.e., the one returned by an `(other-buffer)` call.
(Quoted from the documentation of the non-interactive `other-buffer`.)

If we want to switch to a third, fourth, or further buffer, by default
we would type the name of the buffer, use `<TAB>` to autocomplete it,
and then press `<RET>` to give focus to the intended buffer…

## Overview

Without loss of generality, let’s assume we’re on a single *frame*, a
single *window*, and consequently a single *buffer*.  From that
window, we want to switch to another buffer.  That’s what this package
handles.  It provides *three basic functions* and it is preconfigured
to “smartly” handle *two others* when switching buffers in a window.
(This list of two is customizable and extensible; see [Wrapping other
commands](#wrapping-other-commands).)

The three basic (interactive) functions are:
- `smart-bury-switch-through-buffers` — equivalent to a
  `(switch-to-buffer (other-buffer))` call on *first call*, but goes
  on to the 3rd, 4th… buffer on successive immediate calls, *without
  actually burying buffers* so that after those calls we end up on the
  intended buffer; that buffer becomes the *current buffer*, the
  origin buffer becomes the *other buffer*, and the remaining buffers
  keep their relative positions.  That is, if the target buffer was
  the i-th, it becomes the 1st (*current*), the j-th buffer, for j <
  i, moves to the (j+1)-th position, and the j-th buffer, for j > i,
  keeps the same position it had in the “list of all buffers”.
- `smart-bury-switch-to-other-buffer` — also equivalent to a
  `(switch-to-buffer (other-buffer))` call on *first call*, as well as
  on *remaining calls*: it keeps switching back and forth between the
  current buffer and the *other buffer*.  As *switching through
  buffers* (previously described function) always keeps buffers in
  positions (more or less) relative to their initial positions and the
  origin buffer as the *other buffer*, a call to this function after
  successive and immediate calls to the previously described function
  will return the focus to the original buffer, keeping the “list of
  all buffers” as it was before starting *switching through buffers*.
- `smart-bury-bury-buffer` — like `bury-buffer`, but “smart” (see why
  below).

The two other functions, handled by default, are `quit-window` and
`kill-current-buffer`: `smart-bury-mode` remaps them to
`smart-bury-quit-window` and `smart-bury-kill-current-buffer`, which
take part in the same “smart” sequences.

## Setup

Smart Bury requires Emacs 27.1 or later.  With `smart-bury.el` in a
directory on `load-path`, enable the mode and, as recommended,
`repeat-mode`:

```elisp
(use-package smart-bury
  :load-path "/path/to/smart-bury"
  :config
  (smart-bury-mode 1)
  (repeat-mode 1))
```

`smart-bury-mode` binds the keys `C-x _`, `C-x M-_`, and `C-x M--` to
the three basic functions, respectively, and remaps the wrapped ones
(see [Keys](#keys) to change them).

**Note:** the mode’s default keys are **not** bound in vanilla Emacs.

With `repeat-mode` enabled, any call to any of the three functions
bound with the `C-x` prefix can simply be followed by `_`, `M-_`, or
`M--`, respectively.  The same holds after an interactive call to any
of the wrapped functions (e.g., `q` in a read-only buffer, if it is
bound to `quit-window`): it also enables the *repeat map*, so
*switching through buffers* can be done with fewer key presses.  So
does splitting the window with `C-x 2` or `C-x 3`: e.g., `C-x 3 _`
shows another buffer next to the current one (see [Repeatable
commands](#repeatable-commands)).

We recommend reading the examples below before trying it out, to get
a sense of how it is meant to be used.

## Usage by example

We’ll assume the default keybindings and *repeat mode* throughout this
section.  In each **case** below, let’s consider the initial “list of
all buffers” is `A B C … X Y Z`, which implies the *current buffer* is
`A` and the *other buffer* is `B`.

**Case 1:** We’re done with `A` and we no longer want to see it in any
window for a while, unless we explicitly search for it (e.g., with
`C-x b`).  `C-x M--` suffices: it gives focus to `B` and leaves the
“list of all buffers” as `B C D … Y Z A`.

**Case 2:** We want to go to `B` to write some lines (but we’ll come
back to `A` afterwards); either `C-x _` or `C-x M-_` does that.  After
typing anything else in `B` (important; see **case 6**), to come back
to `A`, either key sequence does the job as well.  Final “list of all
buffers”: `A B C … X Y Z`.

**Case 3:** We just want to read something in `B` and then come back
to work on `A`: `C-x _` (or `C-x M-_`) will present `B` and `M-_` (or
`C-x M-_`) will get us back to `A`.  Final “list of all buffers”: `A B
C … X Y Z`.

**Case 4:** Similar to **Case 3**, but we want to read something in
`C`: `C-x _ _`, read, and `M-_` to be back on `A`.  Final “list of all
buffers”: `A B C … X Y Z`.  A new `C-x _` (or simply `_` if no
non-*smart-bury* command was called in the meantime; or `C-x M-_` or
`M-_` as well) will get us to `B`.

**Case 5:** Similar to **Case 4**, but `B` is on the way and no longer
needed: `C-x _ M--`, read in `C`, and `M-_` to be back on `A`, so that
`C` becomes the *other buffer* and the “list of all buffers” becomes
`A C D … Y Z B`.  After working on `A`, to do the same again, `C-x _`,
read in `C`, and `M-_` suffice to be back on `A` and the “list of all
buffers” will be the same.

**Case 6:** Working on three buffers cyclically, i.e., from initial
`A`, `C-x _ _` gets us to `C`, work on `C` (important), `C-x _ _` gets
us to `B`, work on `B` (important), `C-x _ _` gets us back to `A`,
work on `A` (important), and so on to cycle.  After ending up on `A`,
the “list of all buffers” is as the original.  Here, “work” is marked
as “important” because `C-x _ _` followed by `C-x _ _` with no
intermediate non-*smart-bury* command is equivalent to `C-x _ _ _ _`,
which would get us to `E`.

**Case 7:** `A` is the `*Messages*` buffer.  To quit it and go to `C`,
`q _` suffices.  The final “list of all buffers” is then `C B D … Y Z
A`.

### Why is it “smart”?

It is smart in the sense that if we are on buffer `A`, go to `B`, and
immediately bury `B`, it takes us straight to `C` instead of coming
back to `A`.  We rarely want to go to `B` just to bury it and come
back to where we were: usually `B` is simply on the way to another
buffer.  But if we stop and work on `B` and later bury it, then we go
back to `A` as normal; and if `C` is intended instead, one extra `_`
suffices to get us there.

## Customization

The options below must be set with `setopt` (Emacs 29+),
`customize-set-variable`, or `M-x customize-variable` — **not** with a
plain `setq`, which skips the regeneration they trigger.

### Keys

The prefix `C-x` is configured in `smart-bury-prefix-key`, and the
three keys following it in `smart-bury-keys`.  Each of those keys must
be a single key, since it is also the key repeating its function under
*repeat mode*.  For example, to use `C-c` with `n`, `o`, and `b`:

```elisp
(setopt smart-bury-prefix-key "C-c")
(setopt smart-bury-keys
        '((smart-bury-switch-through-buffers . "n")
          (smart-bury-switch-to-other-buffer . "o")
          (smart-bury-bury-buffer            . "b")))
```

The prefix may also be the empty string, to bind the keys directly
(e.g., `<f5>`, `<f6>`, and `<f7>`).

### Wrapping other commands

`smart-bury-quit-window` and `smart-bury-kill-current-buffer` aren't
hand-written — they're generated from `smart-bury-wrapped-commands`
(default: `(quit-window kill-current-buffer)`), each entry FN getting
a `smart-bury-FN` command that calls FN via the same cycling machinery
as `smart-bury-bury-buffer`, reusing FN's own `interactive` spec.
(`smart-bury-bury-buffer` itself is defined separately, as one of the
three basic functions configured through `smart-bury-keys`.)

Setting this variable regenerates the wrapper commands immediately,
and keeps the mode’s remaps and each wrapper’s `repeat-map` property
in sync.  For example, to drop `kill-current-buffer` entirely and
instead wrap `View-quit`:

```elisp
(setopt smart-bury-wrapped-commands '(quit-window View-quit))
```

<!-- A command can be listed before the package defining it is loaded -->
<!-- (nor is it loaded by being listed): its wrapper only needs it when -->
<!-- called. -->

Here is a non-exhaustive list of functions that can be added to
`smart-bury-wrapped-commands`: `magit-mode-bury-buffer`,
`magit-blame-quit` ([Magit](https://magit.vc)), `ebib-quit`
([Ebib](https://joostkremers.github.io/ebib/)), `mu4e-quit`
([mu4e](https://www.djcbsoftware.nl/code/mu/)), `Custom-buffer-done`,
`kill-buffer` (built in)…

In general, commands that get rid of the current buffer (burying,
quitting, or killing it) belong here.  Those that don’t, but after
which we may want to switch buffers, belong in
`smart-bury-repeatable-commands` instead (see below).

### Repeatable commands

The commands in `smart-bury-repeatable-commands` (default:
`(split-window-below split-window-right)`) aren’t wrapped: they keep
their own behavior and don’t take part in “smart” sequences.  With
`smart-bury-mode` and `repeat-mode` enabled, they only enable the
*repeat map*, so that a new sequence can start with a single key.
For instance, `C-x 3 _` splits the window and shows another buffer in
the selected window, while the new one keeps showing the current
buffer; further `_` presses go on to the next buffers.

For example, to also enable the *repeat map* after `delete-window`
and `switch-to-buffer`:

```elisp
(setopt smart-bury-repeatable-commands
        '(split-window-below split-window-right
          delete-other-windows delete-window switch-to-buffer))
```

Other candidates are `tab-new` (`C-x t 2`), `make-frame-command` (`C-x
5 2`), and `clone-frame` (`C-x 5 c`).  Keep in mind that the first key
pressed after such a command goes to the *repeat map*: e.g., `_` right
after `C-x b` switches through buffers instead of inserting `_`, and
`M--` buries the buffer instead of acting as `negative-argument`.

A command with a *repeat map* of its own (e.g., `other-window`,
`undo`, or `next-buffer`) loses it while listed; it gets it back when
removed from the list or when `smart-bury-mode` is disabled.  As with
wrapped commands, a command may be listed before the package defining
it is loaded.

### Repeat map

`smart-bury-repeat-map` can be extended so that, when the *repeat map*
is enabled, we can easily call certain functions with a single key
press.  For instance, the following allows us to easily kill many
buffers we find on the way to the intended buffer:

```elisp
(define-key smart-bury-repeat-map (kbd "M-Q")
            #'smart-bury-kill-current-buffer)
```

This requires `kill-current-buffer` to be in
`smart-bury-wrapped-commands` (it is by default).  Bindings added to
`smart-bury-repeat-map` or `smart-bury-mode-map` this way are
preserved when any of the options above is customized later.

*Smart Bury* also sets `repeat-check-key` to `no` for its functions
(and for the repeatable commands above, while `smart-bury-mode` is
enabled), so the *repeat map* arms regardless of *which key actually
invoked the command* — not just its default binding.  This matters
most for `smart-bury-quit-window` and
`smart-bury-kill-current-buffer`: they only reach the user via a remap
of whatever key `quit-window`/`kill-current-buffer` are bound to
(e.g. `q` in many read-only modes), so there's no fixed key of their
own to require.  With the check relaxed, even invoking one of those
through such a mode-local `q` arms the map — meaning, for instance,
that after `q` is pressed in a certain read-only mode, we’re is ready
to navigate through the buffers in *repeat mode*.

If one prefers to disable this behavior for a function:

```elisp
(put 'smart-bury-<function> 'repeat-check-key t)
```

### Frames

By default, *smart bury* only considers buffers from the current
frame.  To consider recently-used buffers across all frames instead,
customize `smart-bury-same-frame`, e.g.:

```elisp
(setopt smart-bury-same-frame nil)
```

### Buffers shown in other windows

By default, *smart bury* skips buffers already shown in another window
of the frame, as `other-buffer` (and thus `C-x b`’s default) does —
except the buffer a sequence started from (e.g., right after `C-x 3`,
when both windows show it), which keeps its place in the sequence.  To
go through those buffers too, so that the selected window may end up
showing the same buffer as another window:

```elisp
(setopt smart-bury-include-displayed-buffers t)
```

### Display actions

*Smart Bury* always switches buffers in the selected window, ignoring
display actions even when `switch-to-buffer-obey-display-actions` is
non-nil.  Otherwise, a `display-buffer-alist` rule (e.g., one showing a
buffer in the full frame) would apply to every buffer a sequence merely
passes through, deleting other windows or moving the sequence to
another one.

### Messages

Each command reports where it landed in the echo area, labeled
“Smart Bury:” in face `smart-bury-message-prefix` (which inherits
`font-lock-type-face`, green in the default theme).
To turn these messages off:

```elisp
(setopt smart-bury-messages nil)
```

## Development

Run the test suite with `make test`.  To test interactively in a new
Emacs session just with *smart bury* loaded, run `make
test-interactively`; to compare against vanilla Emacs, run `make
test-emacs-defaults-interactively`.

## License

Smart Bury is free software, licensed under the GNU General Public
License, version 3 or (at your option) any later version.  See
[`LICENSE`](LICENSE) for the full text.
