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
