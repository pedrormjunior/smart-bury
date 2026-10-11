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
