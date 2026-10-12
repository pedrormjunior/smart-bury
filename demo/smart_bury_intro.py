"""Short introduction to Smart Bury, rendered with Manim Community Edition.

After title cards for the three basic commands and the wrapped ones, a
single session with five buffers shows the mechanism: the "list of all
buffers" at the top (with the current and the other buffer marked), an
Emacs frame (window, mode line, minibuffer) in the middle, the keys
pressed and Smart Bury's state on the right, and captions at the bottom.

Every buffer order shown comes from the model in smart_bury_sim.py, and
each storyboard step asserts the order it expects (see `expect'), so
`make intro-check' validates the storyboard without rendering.

Render with `make intro-preview' (fast) or `make intro' (final) from the
repository root.  The longer, case-by-case animation is
smart_bury_demo.py; this file reuses a few of its pieces unchanged.
"""

from __future__ import annotations

import random

from manim import (
    DOWN,
    LEFT,
    PI,
    RIGHT,
    UP,
    GRAY_A,
    GRAY_B,
    GRAY_D,
    WHITE,
    YELLOW,
    AnimationGroup,
    Create,
    DashedVMobject,
    FadeIn,
    FadeOut,
    Indicate,
    Line,
    Rectangle,
    RoundedRectangle,
    Scene,
    Text,
    Transform,
    Triangle,
    VGroup,
    Write,
)

from smart_bury_demo import BACKGROUND, INITIAL_COLOR, MONO, BufferBox, color_of
from smart_bury_sim import SMART_COMMANDS, SmartBury

Text.set_default(font="Sans")

BUFFERS = ["A", "B", "C", "D", "E"]
OTHER_COLOR = GRAY_A
PROMPT_COLOR = "#89b4fa"
# The keys `repeat-mode' offers after any Smart Bury command, in the
# order of the package's description (bury, switch through, switch to
# the other buffer).
REPEAT_KEYS = ["M--", "_", "M-_"]
TAGLINE = "Keep wanted buffers at the top of the “list of all buffers”"

# Geometry (Manim's frame is about 14.2 x 8 units, centered on ORIGIN).
FRAME_X = -1.5          # center of the Emacs frame and of the buffer list
FRAME_WIDTH = 9.6
FRAME_TOP = 1.5
WINDOW_BOTTOM = -1.55
MODE_LINE_HEIGHT = 0.45
MINIBUFFER_HEIGHT = 0.45
SLOT_SPACING = 1.9
LIST_TITLE_Y = 3.75
LIST_Y = 2.9
MARKER_LABEL_Y = 2.12
INITIAL_Y = 1.78
SIDE_X = 5.25
CAPTION_Y = -3.25


def slot_position(index: int):
    """Center of the INDEXth slot (0 = most recent) of the buffer list."""
    offset = SLOT_SPACING * (index - (len(BUFFERS) - 1) / 2)
    return RIGHT * (FRAME_X + offset) + UP * LIST_Y


def frame_left() -> float:
    return FRAME_X - FRAME_WIDTH / 2


def minibuffer_y() -> float:
    return WINDOW_BOTTOM - MODE_LINE_HEIGHT - MINIBUFFER_HEIGHT / 2


class SmartBuryIntro(Scene):
    def construct(self) -> None:
        self.camera.background_color = BACKGROUND
        self.sim = SmartBury(BUFFERS)
        self.key_sequence: list[str] = []
        self.caption: Text | None = None

        self.next_section("Title")
        self.title_card()
        self.next_section("Three basic commands")
        self.basic_commands_card()
        self.next_section("Wrapped commands")
        self.wrapped_commands_card()
        self.next_section("Stage")
        self.stage()
        self.state_visible = False
        self.next_section("The vanilla way")
        self.vanilla_way()
        self.next_section("Burying")
        self.burying()
        self.next_section("Switching through")
        self.switching_through()
        self.next_section("Switching to the other buffer")
        self.switching_to_other()
        self.next_section("Breaking the sequence")
        self.breaking_the_sequence()
        self.next_section("Outro")
        self.outro()

    # Building blocks

    def build_list(self) -> None:
        self.boxes = {name: BufferBox(name).move_to(slot_position(index))
                      for index, name in enumerate(self.sim.blist)}
        first, last = slot_position(0), slot_position(len(BUFFERS) - 1)
        title = Text("list of all buffers", font_size=22, color=GRAY_B)
        title.move_to(RIGHT * (first[0] - 0.65) + UP * LIST_TITLE_Y,
                      aligned_edge=LEFT)
        direction = Text("most recent  →  least recent", font_size=18,
                         color=GRAY_B)
        direction.move_to(RIGHT * (last[0] + 0.65) + UP * LIST_TITLE_Y,
                          aligned_edge=RIGHT)
        self.list_labels = VGroup(title, direction)

    def build_markers(self) -> None:
        """The fixed frames marking the current and the other buffer."""
        self.current_frame = RoundedRectangle(
            corner_radius=0.2, width=1.55, height=1.15, color=YELLOW,
            stroke_width=5).move_to(slot_position(0))
        self.current_label = Text("current", font_size=18, color=YELLOW)
        self.current_label.move_to(RIGHT * slot_position(0)[0]
                                   + UP * MARKER_LABEL_Y)
        self.other_frame = DashedVMobject(
            RoundedRectangle(corner_radius=0.2, width=1.55, height=1.15,
                             color=OTHER_COLOR, stroke_width=4),
            num_dashes=30).move_to(slot_position(1))
        self.other_label = Text("other", font_size=18, color=OTHER_COLOR)
        self.other_label.move_to(RIGHT * slot_position(1)[0]
                                 + UP * MARKER_LABEL_Y)
        self.initial_marker = VGroup(
            Triangle(color=INITIAL_COLOR, fill_opacity=1).scale(0.08),
            Text("initial", font_size=16, color=INITIAL_COLOR),
        ).arrange(RIGHT, buff=0.08)
        self.initial_marker.move_to(RIGHT * slot_position(0)[0]
                                    + UP * INITIAL_Y)
        self.initial_marker.set_opacity(0)

    def body_lines(self, name: str) -> VGroup:
        """Fake text lines filling the window, in the buffer's color."""
        rng = random.Random(name)
        left = frame_left() + 0.45
        top = FRAME_TOP - 0.4
        lines = VGroup()
        for i in range(5):
            width = rng.uniform(2.5, FRAME_WIDTH - 1.6)
            indent = rng.choice([0, 0, 0.5, 1.0])
            start = RIGHT * (left + indent) + UP * (top - 0.48 * i)
            lines.add(Line(start, start + RIGHT * width,
                           color=color_of(name), stroke_width=6,
                           stroke_opacity=0.55))
        return lines

    def mode_line_text(self, name: str) -> Text:
        text = Text(name, font=MONO, font_size=24, color=WHITE)
        text.move_to(self.mode_line, aligned_edge=LEFT)
        return text.shift(RIGHT * 0.3)

    def minibuffer_label(self, prompt: str = "", typed: str = "") -> VGroup:
        """The minibuffer's contents: PROMPT, then TYPED and a cursor.

        Empty, it is an invisible placeholder glyph rather than nothing,
        so that transforming from it doesn't start from a stray point.
        """
        if not prompt:
            placeholder = Text("_", font=MONO, font_size=22).set_opacity(0)
            return VGroup(placeholder).move_to(
                RIGHT * (frame_left() + 0.3) + UP * minibuffer_y(),
                aligned_edge=LEFT)
        parts = VGroup(Text(prompt, font=MONO, font_size=22,
                            color=PROMPT_COLOR))
        if typed:
            parts.add(Text(typed, font=MONO, font_size=22, color=WHITE))
        parts.arrange(RIGHT, buff=0.15)
        cursor = Rectangle(width=0.16, height=0.3, color=WHITE,
                           fill_opacity=0.9, stroke_width=0)
        cursor.next_to(parts, RIGHT, buff=0.05)
        return VGroup(*parts, cursor).move_to(
            RIGHT * (frame_left() + 0.3) + UP * minibuffer_y(),
            aligned_edge=LEFT)

    def repeat_message(self) -> VGroup:
        """`repeat-mode's echo: [Repeat with: M--, _, M-_].

        The keys are drawn like Emacs' `help-key-binding' face, a small
        box around each key.
        """
        parts = VGroup(Text("[Repeat with:", font=MONO, font_size=22,
                            color=GRAY_A))
        for index, key in enumerate(REPEAT_KEYS):
            label = Text(key, font=MONO, font_size=22, color=WHITE)
            chip = RoundedRectangle(corner_radius=0.06,
                                    width=label.width + 0.18,
                                    height=0.34, color=GRAY_B,
                                    stroke_width=1.5, fill_color=GRAY_D,
                                    fill_opacity=1)
            parts.add(VGroup(chip, label.move_to(chip)))
            if index < len(REPEAT_KEYS) - 1:
                parts.add(Text(",", font=MONO, font_size=22, color=GRAY_A))
        parts.add(Text("]", font=MONO, font_size=22, color=GRAY_A))
        parts.arrange(RIGHT, buff=0.12)
        return parts.move_to(RIGHT * (frame_left() + 0.3) + UP * minibuffer_y(),
                             aligned_edge=LEFT)

    def build_frame(self) -> None:
        """The Emacs frame: the window, its mode line, and the minibuffer."""
        bottom = WINDOW_BOTTOM - MODE_LINE_HEIGHT - MINIBUFFER_HEIGHT
        self.frame_outline = Rectangle(width=FRAME_WIDTH,
                                       height=FRAME_TOP - bottom,
                                       color=GRAY_B, stroke_width=3)
        self.frame_outline.move_to(RIGHT * FRAME_X
                                   + UP * (FRAME_TOP + bottom) / 2)
        self.mode_line = Rectangle(width=FRAME_WIDTH, height=MODE_LINE_HEIGHT,
                                   color=GRAY_B, stroke_width=3,
                                   fill_color=GRAY_D, fill_opacity=1)
        self.mode_line.move_to(RIGHT * FRAME_X
                               + UP * (WINDOW_BOTTOM - MODE_LINE_HEIGHT / 2))
        self.mode_line_label = self.mode_line_text(self.sim.current)
        self.window_body = self.body_lines(self.sim.current)
        self.minibuffer = self.minibuffer_label()

    def build_side(self) -> None:
        keys_title = Text("keys", font_size=22, color=GRAY_B)
        self.keys_box = RoundedRectangle(corner_radius=0.15, width=3.4,
                                         height=0.85, color=GRAY_B,
                                         stroke_width=3)
        self.keys_box.move_to(RIGHT * SIDE_X + UP * 0.7)
        keys_title.next_to(self.keys_box, UP, buff=0.12)
        self.keys_text = self.keys_label("")
        self.keys_panel = VGroup(keys_title, self.keys_box, self.keys_text)
        state_title = Text("Smart Bury state", font_size=22, color=GRAY_B)
        state_title.move_to(RIGHT * SIDE_X + DOWN * 0.55)
        self.counter_text = self.counter_label(self.sim.counter)
        self.state_panel = VGroup(state_title, self.counter_text)

    def keys_label(self, keys: str) -> Text:
        # An empty label is an invisible placeholder glyph (see
        # `minibuffer_label').
        label = Text(keys or "_", font=MONO, font_size=30, color=WHITE)
        if label.width > self.keys_box.width - 0.4:
            label.scale_to_fit_width(self.keys_box.width - 0.4)
        label.move_to(self.keys_box)
        return label if keys else label.set_opacity(0)

    def counter_label(self, counter: int) -> Text:
        return Text(f"counter: {counter}", font=MONO, font_size=24,
                    color=WHITE).move_to(RIGHT * SIDE_X + DOWN * 1.05)

    def say(self, text: str, wait: float = 1.5) -> None:
        """Replace the caption at the bottom of the frame."""
        new = Text(text, font_size=26, color=WHITE)
        if new.width > 13:
            new.scale_to_fit_width(13)
        new.move_to(UP * CAPTION_Y)
        if self.caption is None:
            self.play(FadeIn(new, shift=UP * 0.15), run_time=0.5)
        else:
            self.play(FadeOut(self.caption), FadeIn(new, shift=UP * 0.15),
                      run_time=0.5)
        self.caption = new
        if wait > 0:
            self.wait(wait)

    def expect(self, order: str, what: str) -> None:
        """Assert that the model's buffer order is ORDER after WHAT."""
        actual = "".join(self.sim.blist)
        if actual != order:
            raise AssertionError(
                f"storyboard step {what!r}: expected {order}, "
                f"the model gives {actual}")

    # Animating the model

    def box_moves(self, old: list[str], new: list[str]) -> list:
        """Slide each box from its slot in OLD to its slot in NEW.

        A box jumping two or more slots arcs below the row (clockwise or
        counterclockwise depending on the direction), so it doesn't pass
        through the other boxes or leave the frame at the top.
        """
        moves = []
        for name in new:
            delta = new.index(name) - old.index(name)
            if delta == 0:
                continue
            arc = 0 if abs(delta) < 2 else (PI / 4 if delta > 0 else -PI / 4)
            moves.append(self.boxes[name].animate(path_arc=arc)
                         .move_to(slot_position(new.index(name))))
        return moves

    def show_keys(self, run_time: float = 0.4) -> None:
        keys = " ".join(self.key_sequence[-6:])
        self.play(Transform(self.keys_text, self.keys_label(keys)),
                  run_time=run_time)

    def initial_marker_target(self, visible: bool):
        """Put the "initial" marker under the initial buffer's box."""
        initial = self.sim.initial
        if not visible or initial is None:
            return self.initial_marker.animate.set_opacity(0)
        x = slot_position(self.sim.blist.index(initial))[0]
        return (self.initial_marker.animate.move_to(RIGHT * x
                                                    + UP * INITIAL_Y)
                .set_opacity(1))

    def update_stage(self, old: list[str], minibuffer: VGroup,
                     run_time: float) -> None:
        """Animate the model's new state: list, window, state, minibuffer."""
        new = list(self.sim.blist)
        animations = self.box_moves(old, new)
        if new[0] != old[0]:
            animations += [
                Transform(self.mode_line_label, self.mode_line_text(new[0])),
                Transform(self.window_body, self.body_lines(new[0])),
            ]
        if self.state_visible:
            animations += [
                Transform(self.counter_text,
                          self.counter_label(self.sim.counter)),
                self.initial_marker_target(
                    visible=self.sim.last_command in SMART_COMMANDS),
            ]
        animations.append(Transform(self.minibuffer, minibuffer))
        self.play(*animations, run_time=run_time)

    def press(self, keys: str, action, caption: str = "",
              expect: str | None = None, fast: bool = False) -> None:
        """Press KEYS, run the model's ACTION, and animate the result.

        KEYS continue the key sequence on display unless the previous
        command was not a Smart Bury one, in which case they start it.
        EXPECT, if given, is the buffer order the storyboard expects.
        """
        if caption:
            self.say(caption, wait=0.25 if fast else 0.5)
        if (keys.startswith("C-x")
                or self.sim.last_command not in SMART_COMMANDS):
            self.key_sequence = []
        self.key_sequence.append(keys)
        self.show_keys(run_time=0.2 if fast else 0.35)
        old = list(self.sim.blist)
        action()
        if expect is not None:
            self.expect(expect, keys)
        self.update_stage(old, self.repeat_message(),
                          run_time=0.55 if fast else 1.0)
        self.wait(0.35 if fast else max(1.0, 0.15 * len(caption.split())))

    def work(self, caption: str, expect: str | None = None) -> None:
        """Any other command (e.g. typing), which ends the sequence and
        clears `repeat-mode's message."""
        self.say(caption, wait=0)
        self.sim.work()
        if expect is not None:
            self.expect(expect, "work")
        self.key_sequence = []
        animations = [Transform(self.keys_text,
                                self.keys_label("…typing…")),
                      Indicate(self.window_body, color=WHITE,
                               scale_factor=1.03),
                      Transform(self.minibuffer, self.minibuffer_label())]
        if self.state_visible:
            animations.append(self.initial_marker.animate.set_opacity(0))
        self.play(*animations, run_time=0.8)
        self.wait(0.7)
        self.show_keys(run_time=0.3)

    def switch_to_buffer(self, name: str, caption: str = "",
                         expect: str | None = None,
                         fast: bool = False) -> None:
        """Vanilla C-x b NAME RET, typed in the minibuffer.

        When NAME is the other buffer, the prompt's default, nothing is
        typed: C-x b RET.
        """
        if caption:
            self.say(caption, wait=0.25 if fast else 0.5)
        default = self.sim.other
        prompt = f"Switch to buffer (default {default}): "
        self.key_sequence = ["C-x b"]
        self.play(Transform(self.keys_text, self.keys_label("C-x b")),
                  Transform(self.minibuffer, self.minibuffer_label(prompt)),
                  run_time=0.3 if fast else 0.45)
        self.wait(0.2 if fast else 0.45)
        if name != default:
            self.key_sequence.append(name)
            self.play(Transform(self.keys_text,
                                self.keys_label(f"C-x b {name}")),
                      Transform(self.minibuffer,
                                self.minibuffer_label(prompt, name)),
                      run_time=0.25 if fast else 0.35)
            self.wait(0.2 if fast else 0.35)
        self.key_sequence.append("RET")
        self.show_keys(run_time=0.2 if fast else 0.3)
        old = list(self.sim.blist)
        self.sim.switch_to_buffer(name)
        if expect is not None:
            self.expect(expect, f"C-x b {name} RET")
        self.update_stage(old, self.minibuffer_label(),
                          run_time=0.55 if fast else 1.0)
        self.wait(0.35 if fast else 1.0)

    # Cards
    # Cards

    def clear_all(self) -> None:
        self.play(*(FadeOut(mobject) for mobject in self.mobjects))
        self.caption = None

    def title_card(self) -> None:
        title = Text("Smart Bury", font_size=72, weight="BOLD")
        tagline = Text(TAGLINE, font_size=30, color=GRAY_B)
        VGroup(title, tagline).arrange(DOWN, buff=0.4)
        self.play(Write(title), FadeIn(tagline, shift=UP * 0.2))
        self.wait(2)
        self.clear_all()

    def card_heading(self, text: str) -> Text:
        return Text(text, font_size=40, weight="BOLD").move_to(UP * 2.9)

    def command_row(self, keys: str, description: str,
                    symbol: str) -> VGroup:
        """A key chip, then a description over the command's name."""
        key_text = Text(keys, font=MONO, font_size=30, color=WHITE)
        chip = RoundedRectangle(corner_radius=0.15, width=2.4, height=0.8,
                                color=YELLOW, stroke_width=3)
        key_text.move_to(chip)
        desc = Text(description, font_size=24, color=WHITE)
        if desc.width > 10:
            desc.scale_to_fit_width(10)
        name = Text(symbol, font=MONO, font_size=20, color=GRAY_B)
        block = VGroup(desc, name).arrange(DOWN, aligned_edge=LEFT, buff=0.12)
        return VGroup(VGroup(chip, key_text), block).arrange(RIGHT, buff=0.45)

    def show_card(self, heading: Text, rows: VGroup, footer: VGroup,
                  hold: float) -> None:
        self.play(FadeIn(heading, shift=DOWN * 0.15))
        self.play(AnimationGroup(*(FadeIn(row, shift=RIGHT * 0.3)
                                   for row in rows), lag_ratio=0.6),
                  run_time=2.4)
        self.play(FadeIn(footer))
        self.wait(hold)
        self.clear_all()

    def basic_commands_card(self) -> None:
        heading = self.card_heading("Three basic commands")
        rows = VGroup(
            self.command_row("C-x M--",
                             "Bury the current buffer, and move on smartly.",
                             "smart-bury-bury-buffer"),
            self.command_row("C-x _",
                             "Go to the other buffer, then one deeper per _,"
                             " burying nothing.",
                             "smart-bury-switch-through-buffers"),
            self.command_row("C-x M-_",
                             "Go back to where the sequence started,"
                             " or to the other buffer.",
                             "smart-bury-switch-to-other-buffer"),
        ).arrange(DOWN, aligned_edge=LEFT, buff=0.55)
        rows.move_to(UP * 0.1)
        footer = VGroup(Text("With repeat-mode, continue with just "
                             "M--, _, or M-_.", font_size=24, color=GRAY_B))
        footer.move_to(DOWN * 2.9)
        self.show_card(heading, rows, footer, hold=3.5)

    def wrapped_row(self, vanilla: str, wrapper: str, note: str) -> VGroup:
        arrow = Text("→", font_size=28, color=GRAY_B)
        line = VGroup(Text(vanilla, font=MONO, font_size=26, color=WHITE),
                      arrow,
                      Text(wrapper, font=MONO, font_size=26, color=YELLOW)
                      ).arrange(RIGHT, buff=0.3)
        hint = Text(note, font_size=20, color=GRAY_B)
        return VGroup(line, hint).arrange(DOWN, aligned_edge=LEFT, buff=0.12)

    def wrapped_commands_card(self) -> None:
        heading = self.card_heading("Wrapped commands")
        rows = VGroup(
            self.wrapped_row("quit-window", "smart-bury-quit-window",
                             "e.g. q in read-only buffers such as *Messages*"),
            self.wrapped_row("kill-current-buffer",
                             "smart-bury-kill-current-buffer",
                             "on whatever key it is bound to"),
        ).arrange(DOWN, aligned_edge=LEFT, buff=0.6)
        rows.move_to(UP * 0.5)
        footer = VGroup(
            Text("They do their usual job, then continue the same smart "
                 "sequence.", font_size=26, color=WHITE),
            Text("The list is customizable: smart-bury-wrapped-commands.",
                 font_size=22, color=GRAY_B),
        ).arrange(DOWN, buff=0.25).move_to(DOWN * 2.3)
        self.show_card(heading, rows, footer, hold=3)

    # The session

    def stage(self) -> None:
        """Build the session's layout piece by piece."""
        self.build_list()
        self.build_markers()
        self.build_frame()
        self.build_side()

        self.say("Emacs keeps a “list of all buffers”, "
                 "most recently used first.", wait=0)
        self.play(AnimationGroup(*(FadeIn(self.boxes[name], shift=DOWN * 0.3)
                                   for name in self.sim.blist),
                                 lag_ratio=0.15),
                  FadeIn(self.list_labels))
        self.wait(0.8)

        self.say("The first is the current buffer; "
                 "the second is the other buffer.", wait=0)
        self.play(Create(self.current_frame), FadeIn(self.current_label))
        self.play(Create(self.other_frame), FadeIn(self.other_label))
        self.wait(1.2)

        self.say("The window shows the current buffer; "
                 "the minibuffer sits below it.", wait=0)
        minibuffer_hint = Text("minibuffer", font_size=20, color=GRAY_B)
        minibuffer_hint.move_to(RIGHT * (frame_left() + 0.3)
                                + UP * minibuffer_y(), aligned_edge=LEFT)
        self.play(Create(self.frame_outline), FadeIn(self.mode_line),
                  FadeIn(self.mode_line_label),
                  Create(self.window_body, lag_ratio=0.2),
                  FadeIn(minibuffer_hint))
        self.add(self.minibuffer)
        self.wait(1.2)
        self.play(FadeOut(minibuffer_hint))

        self.say("Keys pressed appear on the right.", wait=0)
        self.play(FadeIn(self.keys_panel))
        self.wait(1)

    def vanilla_way(self) -> None:
        self.say("Without Smart Bury, going to a third buffer means "
                 "typing its name.", wait=0.8)
        self.switch_to_buffer("C", "C-x b offers the other buffer, B, "
                              "by default; we type C instead.",
                              expect="CABDE")
        self.switch_to_buffer("A", "Coming back to A, now the other "
                              "buffer, is just C-x b RET…",
                              expect="ACBDE")
        self.say("…leaves C ahead of B: the list got shuffled.", wait=0)
        self.play(Indicate(self.boxes["C"], color=WHITE),
                  Indicate(self.boxes["B"], color=WHITE), run_time=1.2)
        self.wait(0.6)
        self.switch_to_buffer("B", "Putting it back takes more typing.",
                              expect="BACDE", fast=True)
        self.switch_to_buffer("A", expect="ABCDE", fast=True)
        self.say("Smart Bury moves through buffers without typing names, "
                 "and keeps the list in order.", wait=2)

    def burying(self) -> None:
        self.press("C-x M--", self.sim.bury,
                   "C-x M-- buries A: it goes to the end of the list, "
                   "and B shows.", expect="BCDEA")
        self.say("repeat-mode now lists, in the minibuffer, "
                 "the keys that repeat without C-x.", wait=1.8)
        self.press("M--", self.sim.bury,
                   "Each further M-- buries the current buffer in turn…",
                   expect="CDEAB", fast=True)
        self.press("M--", self.sim.bury, expect="DEABC", fast=True)
        self.press("M--", self.sim.bury, expect="EABCD", fast=True)
        self.press("M--", self.sim.bury,
                   "…until A is back, and the list is as it started.",
                   expect="ABCDE")

    def switching_through(self) -> None:
        self.counter_text.become(self.counter_label(self.sim.counter))
        self.say("Smart Bury remembers where a sequence started, "
                 "and how deep it is.", wait=0)
        self.state_visible = True
        self.key_sequence = []
        self.play(FadeIn(self.state_panel),
                  self.initial_marker_target(visible=True),
                  Transform(self.keys_text, self.keys_label("")))
        self.wait(1.3)
        self.press("C-x _", self.sim.switch_through,
                   "C-x _ goes to the other buffer, B.", expect="BACDE")
        self.press("_", self.sim.switch_through,
                   "Each _ goes one buffer further, burying nothing…",
                   expect="CABDE")
        self.press("_", self.sim.switch_through, expect="DABCE", fast=True)
        self.press("_", self.sim.switch_through,
                   "…up to the last one, E. Behind it, A B C D stay in "
                   "order.", expect="EABCD")
        self.work("Work on E for a while: any other command ends the "
                  "sequence.", expect="EABCD")
        self.press("C-x M--", self.sim.bury,
                   "Then C-x M-- buries E: A is back on top, and the list "
                   "is as it started.", expect="ABCDE")

    def switching_to_other(self) -> None:
        self.press("C-x M-_", self.sim.switch_to_other,
                   "C-x M-_ switches to the other buffer, B…",
                   expect="BACDE")
        self.press("M-_", self.sim.switch_to_other,
                   "…and M-_ switches back, as many times as wanted.",
                   expect="ABCDE")
        self.press("M-_", self.sim.switch_to_other, expect="BACDE",
                   fast=True)
        self.press("M-_", self.sim.switch_to_other,
                   "The current and the other buffer just trade places.",
                   expect="ABCDE")

    def breaking_the_sequence(self) -> None:
        self.press("C-x _", self.sim.switch_through,
                   "Without stopping, C-x _ _ _ _ goes four buffers deep, "
                   "to E.", expect="BACDE", fast=True)
        self.press("_", self.sim.switch_through, expect="CABDE", fast=True)
        self.press("_", self.sim.switch_through, expect="DABCE", fast=True)
        self.press("_", self.sim.switch_through, expect="EABCD")
        self.press("M-_", self.sim.switch_to_other,
                   "M-_ goes back to A, with the list restored.",
                   expect="ABCDE")
        self.press("C-x _", self.sim.switch_through, "Now C-x _ _ goes to C…",
                   expect="BACDE", fast=True)
        self.press("_", self.sim.switch_through, expect="CABDE")
        self.work("…and we work on C for a while, which ends the sequence.",
                  expect="CABDE")
        self.press("C-x _", self.sim.switch_through,
                   "So C-x _ _ starts a new sequence from C: two deep is "
                   "now B.", expect="ACBDE", fast=True)
        self.press("_", self.sim.switch_through, expect="BCADE")
        self.press("M-_", self.sim.switch_to_other,
                   "M-_ returns to C, where the new sequence started.",
                   expect="CABDE")
        self.say("Any other command starts a new sequence, "
                 "from wherever we are.", wait=2.5)

    def outro(self) -> None:
        self.clear_all()
        title = Text("Smart Bury", font_size=64, weight="BOLD")
        tagline = Text(TAGLINE, font_size=28, color=GRAY_B)
        link = Text("github.com/pedrormjunior/smart-bury", font=MONO,
                    font_size=26, color=GRAY_B)
        VGroup(title, tagline, link).arrange(DOWN, buff=0.4)
        self.play(FadeIn(title, shift=UP * 0.2), FadeIn(tagline),
                  FadeIn(link))
        self.wait(3)
