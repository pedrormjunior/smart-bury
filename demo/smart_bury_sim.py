"""A pure-Python model of Smart Bury's algorithm, driving the demo animation.

Each method mirrors its counterpart in ../smart-bury.el, so the animation
cannot show a "list of all buffers" order the package does not produce.
The model has a single window: buffers are plain names, and ``blist[0]``
is the current buffer, the only one displayed.

Modeling assumption: vanilla ``bury-buffer`` and ``quit-window`` move the
current buffer to the end of the list, and the window then shows the new
head of the list.  In Emacs the window's own buffer history decides
instead; for the single-window scenarios here the result is the same,
which ``check()`` confirms against the README cases.

Run this file directly to replay the README cases (and a few more) and
exit non-zero on any mismatch.
"""

from __future__ import annotations

import sys
from dataclasses import dataclass

SWITCH_THROUGH = "smart-bury-switch-through-buffers"
SWITCH_TO_OTHER = "smart-bury-switch-to-other-buffer"
BURY = "smart-bury-bury-buffer"
QUIT = "smart-bury-quit-window"
WORK = "self-insert-command"
SWITCH_TO_BUFFER = "switch-to-buffer"

# `smart-bury--commands' with the default `smart-bury-wrapped-commands'
# (only the wrappers the demo uses).
SMART_COMMANDS = {SWITCH_THROUGH, SWITCH_TO_OTHER, BURY, QUIT}


def other_buffer(blist) -> str | None:
    """`(other-buffer)' for a single window: the most recent buffer
    other than the current one, skipping internal buffers (names
    starting with a space).  It is also `C-x b's default."""
    return next((b for b in blist[1:] if not b.startswith(" ")), None)


@dataclass(frozen=True)
class Step:
    """The state after one key press, for the animation to draw."""

    keys: str
    command: str
    caption: str
    blist: tuple[str, ...]
    initial: str | None
    counter: int

    @property
    def current(self) -> str:
        return self.blist[0]

    @property
    def other(self) -> str | None:
        return other_buffer(self.blist)


class SmartBury:
    """Smart Bury's state and commands over a single window."""

    def __init__(self, buffers: list[str]) -> None:
        self.blist = list(buffers)
        self.counter = 1  # `smart-bury--counter'
        self.initial: str | None = None  # `smart-bury--initial-buffer'
        self.last_command = WORK  # `last-command'
        self.steps: list[Step] = []

    @property
    def current(self) -> str:
        return self.blist[0]

    @property
    def other(self) -> str | None:
        return other_buffer(self.blist)

    # Primitives

    def _switch(self, buffer: str) -> None:
        """`switch-to-buffer': make BUFFER current and most recent."""
        self.blist.remove(buffer)
        self.blist.insert(0, buffer)

    def _bury(self) -> None:
        """Vanilla `bury-buffer'/`quit-window' (see module docstring)."""
        self.blist.append(self.blist.pop(0))

    # Mirrors of smart-bury.el's internal functions

    def _starts_now_p(self) -> bool:
        return self.last_command not in SMART_COMMANDS

    def _maybe_start_sequence(self) -> bool:
        if self._starts_now_p():
            self.initial = self.current
            return True
        return False

    def _is_initial_p(self) -> bool:
        return self.current == self.initial

    def _maybe_restart_sequence(self) -> bool:
        return self._maybe_start_sequence() or self._is_initial_p()

    def _eligible_p(self, buffer: str, allow_current: bool) -> bool:
        # Only the current buffer is displayed in a window.
        displayed = buffer == self.current
        return not buffer.startswith(" ") and (not displayed or allow_current)

    def _select_buffers(
        self, buffers: list[str], n: int, allow_current: bool = False
    ) -> list[str]:
        assert n >= 1
        eligible = [b for b in buffers if self._eligible_p(b, allow_current)]
        if not eligible:
            raise RuntimeError("Smart Bury: no eligible buffer to switch to")
        return [eligible[i % len(eligible)] for i in range(n)]

    def _walk_back(self, selection: list[str]) -> None:
        for buffer in reversed(selection):
            self._switch(buffer)

    def _go_through_buffers(
        self, buffers: list[str], allow_current: bool = False
    ) -> str:
        selection = self._select_buffers(buffers, self.counter, allow_current)
        self._walk_back(selection[:-1])
        return selection[-1]

    def _run_function(self, func) -> None:
        starts_now = self._maybe_start_sequence()
        was_initial = self._is_initial_p()
        func()
        if was_initial:
            self.counter = 1
        if starts_now:
            self.initial = self.current
        else:
            last = self._go_through_buffers(list(self.blist), allow_current=True)
            self._switch(last)
            if was_initial:
                self.initial = last

    # Commands

    def _record(self, keys: str, command: str, caption: str) -> Step:
        self.last_command = command
        step = Step(keys, command, caption, tuple(self.blist),
                    self.initial, self.counter)
        self.steps.append(step)
        return step

    def switch_through(self, keys: str = "_", caption: str = "") -> Step:
        if self._maybe_restart_sequence():
            self.counter = 1
        self._switch(self._go_through_buffers(self.blist[1:]))
        self.counter += 1
        return self._record(keys, SWITCH_THROUGH, caption)

    def switch_to_other(self, keys: str = "M-_", caption: str = "") -> Step:
        self.counter = (2 if self._maybe_restart_sequence()
                        else max(2, self.counter))
        self._walk_back(self._select_buffers(self.blist[1:], self.counter - 1))
        self.counter = 2
        return self._record(keys, SWITCH_TO_OTHER, caption)

    def bury(self, keys: str = "M--", caption: str = "") -> Step:
        self._run_function(self._bury)
        return self._record(keys, BURY, caption)

    def quit(self, keys: str = "q", caption: str = "") -> Step:
        self._run_function(self._bury)
        return self._record(keys, QUIT, caption)

    def switch_to_buffer(self, name: str, keys: str = "C-x b",
                         caption: str = "") -> Step:
        """Vanilla `switch-to-buffer' (C-x b NAME RET).  Not a Smart Bury
        command, so the next Smart Bury command starts a new sequence."""
        self._switch(name)
        return self._record(keys, SWITCH_TO_BUFFER, caption)

    def work(self, caption: str = "") -> Step:
        """Any non-Smart Bury command, which ends the current sequence."""
        return self._record("", WORK, caption)


# Self-check against the README cases (same expectations as the
# `smart-bury-test-readme-*' tests in ../smart-bury-tests.el)

BUFFERS = ["A", "B", "C", "D", "E"]


def _expect(label: str, actual, expected, failures: list[str]) -> None:
    if actual != expected:
        failures.append(f"{label}: expected {expected!r}, got {actual!r}")


def check() -> list[str]:
    failures: list[str] = []
    order = lambda sb: "".join(sb.blist)  # noqa: E731

    # Case 1: C-x M-- buries A, focuses B, and leaves B C D E A.
    sb = SmartBury(BUFFERS)
    sb.bury()
    _expect("case 1 current", sb.current, "B", failures)
    _expect("case 1 list", order(sb), "BCDEA", failures)

    # Case 2: C-x _ (or C-x M-_) goes to B; after work, back to A.
    for cmd in ("switch_through", "switch_to_other"):
        sb = SmartBury(BUFFERS)
        getattr(sb, cmd)()
        _expect(f"case 2 ({cmd}) to B", sb.current, "B", failures)
        sb.work()
        getattr(sb, cmd)()
        _expect(f"case 2 ({cmd}) back", sb.current, "A", failures)
        _expect(f"case 2 ({cmd}) list", order(sb), "ABCDE", failures)

    # Case 3: C-x _ (or C-x M-_) then M-_ returns to A.
    for cmd in ("switch_through", "switch_to_other"):
        sb = SmartBury(BUFFERS)
        getattr(sb, cmd)()
        sb.switch_to_other()
        _expect(f"case 3 ({cmd}) back", sb.current, "A", failures)
        _expect(f"case 3 ({cmd}) list", order(sb), "ABCDE", failures)

    # Case 4: C-x _ _ reaches C, M-_ returns to A; then any of four
    # follow-ups reaches B.
    for follow in (("work", "switch_through"), ("switch_through",),
                   ("work", "switch_to_other"), ("switch_to_other",)):
        sb = SmartBury(BUFFERS)
        sb.switch_through()
        sb.switch_through()
        _expect("case 4 to C", sb.current, "C", failures)
        sb.switch_to_other()
        _expect("case 4 back", sb.current, "A", failures)
        _expect("case 4 list", order(sb), "ABCDE", failures)
        for cmd in follow:
            getattr(sb, cmd)()
        _expect(f"case 4 then {follow}", sb.current, "B", failures)

    # Case 5: C-x _ M-- reaches C, M-_ returns to A, leaving A C D E B;
    # repeating after work keeps that list.
    sb = SmartBury(BUFFERS)
    sb.switch_through()
    sb.bury()
    _expect("case 5 to C", sb.current, "C", failures)
    sb.switch_to_other()
    _expect("case 5 back", sb.current, "A", failures)
    _expect("case 5 list", order(sb), "ACDEB", failures)
    sb.work()
    sb.switch_through()
    _expect("case 5 again to C", sb.current, "C", failures)
    sb.switch_to_other()
    _expect("case 5 again back", sb.current, "A", failures)
    _expect("case 5 again list", order(sb), "ACDEB", failures)

    # Case 6: with work in between, C-x _ _ cycles A -> C -> B -> A;
    # without work, four presses reach E.
    sb = SmartBury(BUFFERS)
    for expected in ("C", "B", "A"):
        sb.work()
        sb.switch_through()
        sb.switch_through()
        _expect("case 6 cycle", sb.current, expected, failures)
    _expect("case 6 list", order(sb), "ABCDE", failures)
    sb = SmartBury(BUFFERS)
    for _ in range(4):
        sb.switch_through()
    _expect("case 6 no work", sb.current, "E", failures)

    # Case 7: q _ from A quits it and reaches C, leaving C B D E A.
    sb = SmartBury(BUFFERS)
    sb.quit()
    sb.switch_through()
    _expect("case 7 to C", sb.current, "C", failures)
    _expect("case 7 list", order(sb), "CBDEA", failures)

    # "Why is it smart?": bury right after arriving at B reaches C; after
    # working on B, burying returns to A, and an immediate _ reaches C.
    sb = SmartBury(BUFFERS)
    sb.switch_through()
    sb.bury()
    _expect("why-smart immediate bury", sb.current, "C", failures)
    sb = SmartBury(BUFFERS)
    sb.switch_through()
    sb.work()
    sb.bury()
    _expect("why-smart bury after work", sb.current, "A", failures)
    sb.switch_through()
    _expect("why-smart then _", sb.current, "C", failures)

    # Beyond the README (verified against smart-bury.el in batch Emacs):
    # burying every buffer in a row cycles back to the initial order.
    sb = SmartBury(BUFFERS)
    for _ in BUFFERS:
        sb.bury()
    _expect("bury all", order(sb), "ABCDE", failures)

    # Switching through to the last buffer, working on it, then burying
    # it returns to the initial order.
    sb = SmartBury(BUFFERS)
    for _ in BUFFERS[1:]:
        sb.switch_through()
    _expect("through to the last", order(sb), "EABCD", failures)
    sb.work()
    sb.bury()
    _expect("work, then bury the last", order(sb), "ABCDE", failures)

    # C-x b is not a Smart Bury command: it ends the sequence, so C-x _
    # afterward starts a new one from the buffer it switched to.
    sb = SmartBury(BUFFERS)
    sb.switch_through()
    sb.switch_to_buffer("D")
    _expect("C-x b D", order(sb), "DBACE", failures)
    sb.switch_through()
    _expect("C-x b then C-x _", (sb.current, sb.initial), ("B", "D"),
            failures)

    # The other buffer is the second in the list, skipping internal ones.
    _expect("other", SmartBury(BUFFERS).other, "B", failures)
    _expect("other skips internal", SmartBury(["A", " *x*", "C"]).other, "C",
            failures)

    return failures


if __name__ == "__main__":
    failures = check()
    for failure in failures:
        print(f"FAIL {failure}")
    if failures:
        sys.exit(1)
    print("smart_bury_sim: all checks match (README cases and more)")
