# Suggested improvements

## Remaining

1. **Fix the known bug**: `smart-bury-kill-current-buffer` carries a
   `;; There seems to be a problem with this function.` comment from
   the original author, with no further detail. Simple single- and
   repeated-kill sequences (now covered by
   `smart-bury-test-kill-current-buffer{,-repeated}`) both pass, so
   the bug — if still present — needs a more specific repro (e.g.
   interaction with a particular major mode, multiple windows, or
   `smart-bury-same-frame` set to nil) before it can be root-caused.
2. **Missing dead-buffer guard**: `smart-bury--go-through-buffers`
   calls `(buffer-name buffer)` on every buffer in the list it's
   given without checking `buffer-live-p` first; `buffer-name`
   returns nil for an already-killed buffer, which crashes the
   `string-match-p` call right after it (`wrong-type-argument
   stringp nil`). Harmless with the real `buffer-list` (which never
   reports dead buffers), but the function has no defense if it's
   ever called with a caller-supplied list containing one — as
   happened while testing.
3. **Docs**: there's no `README.md` and the `Commentary:` section is
   just an extraction note. A real README should explain *why*
   this package exists (repeated bury/quit/kill commands normally
   dump you on an arbitrary buffer; Smart Bury instead cycles you
   through recently-used ones) and show the intended keybinding
   setup (remapping `bury-buffer`, `quit-window`,
   `kill-current-buffer`), since none of that is obvious from the
   function names alone.
4. **License header**: the file currently has no license notice at
   all, which is a blocker for any public distribution (MELPA
   requires one). GPL-3.0-or-later is the conventional choice for
   packages that extend core Emacs behavior; needs the standard
   FSF-style boilerplate comment block at the top of the file.
