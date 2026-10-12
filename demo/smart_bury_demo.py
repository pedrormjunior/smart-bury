"""Explanatory animation of Smart Bury, rendered with Manim Community Edition.

Layout: the window showing the current buffer in the middle and top, the
"list of all buffers" as a row of boxes at the bottom, the keys pressed
and Smart Bury's hidden state on the right, and captions at the top.
Every buffer order shown comes from the model in smart_bury_sim.py.

Render with `make demo-preview' (fast) or `make demo' (final) from the
repository root.
"""

from __future__ import annotations

import random

from manim import (
    DOWN,
    LEFT,
    ORIGIN,
    PI,
    RIGHT,
    UP,
    BLUE_C,
    GOLD_C,
    GRAY_B,
    GRAY_D,
    GREEN_C,
    MAROON_C,
    PURPLE_C,
    TEAL_C,
    WHITE,
    YELLOW,
    AnimationGroup,
    Create,
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

from smart_bury_sim import WORK, SmartBury

BACKGROUND = "#1e1e2e"
MONO = "Monospace"
INITIAL_COLOR = "#f38ba8"

Text.set_default(font="Sans")

BUFFERS = ["A", "B", "C", "D", "E", "F"]
COLORS = {
    "A": BLUE_C,
    "B": GREEN_C,
    "C": GOLD_C,
    "D": PURPLE_C,
    "E": TEAL_C,
    "F": MAROON_C,
}

# Geometry (Manim's frame is about 14.2 x 8 units, centered on ORIGIN).
SLOT_WIDTH = 1.65
LIST_Y = -2.45
WINDOW_CENTER = LEFT * 1.6 + UP * 1.2
WINDOW_WIDTH = 9.4
WINDOW_HEIGHT = 3.4
SIDE_X = 5.35
CAPTION_Y = 3.45


# Short labels for buffer boxes whose full name doesn't fit; the window's
# mode line still shows the full name.
BOX_LABELS = {"*Messages*": "*Msg*"}


def color_of(name: str) -> str:
    """Color of buffer NAME; renamed buffers keep the A color."""
    return COLORS.get(name, BLUE_C)


def slot_position(index: int) -> object:
    """Center of the INDEXth slot (0 = most recent) of the buffer list."""
    first = -SLOT_WIDTH * (len(BUFFERS) - 1) / 2
    return RIGHT * (first + SLOT_WIDTH * index) + UP * LIST_Y


class BufferBox(VGroup):
    """A buffer in the list: a colored rounded box with its name."""

    def __init__(self, name: str) -> None:
        self.name = name
        box = RoundedRectangle(corner_radius=0.15, width=1.3, height=0.9,
                               color=color_of(name), stroke_width=4,
                               fill_color=color_of(name), fill_opacity=0.25)
        label = Text(BOX_LABELS.get(name, name), font=MONO, font_size=34,
                     color=WHITE)
        if label.width > 1.1:
            label.scale_to_fit_width(1.1)
        super().__init__(box, label)


class SmartBuryDemo(Scene):
    def construct(self) -> None:
        self.camera.background_color = BACKGROUND
        self.sim = SmartBury(BUFFERS)
        self.key_sequence: list[str] = []
        self.caption: Text | None = None

        self.next_section("Intro")
        self.intro()
        for label, title, scene in CASES:
            self.next_section(label)
            scene(self, label, title)
        self.next_section("Outro")
        self.outro()

    # Building blocks

    def body_lines(self, name: str) -> VGroup:
        """Fake text lines filling the window, in the buffer's color."""
        rng = random.Random(name)
        left = WINDOW_CENTER[0] - WINDOW_WIDTH / 2 + 0.45
        top = WINDOW_CENTER[1] + WINDOW_HEIGHT / 2 - 0.45
        lines = VGroup()
        for i in range(5):
            width = rng.uniform(2.5, WINDOW_WIDTH - 1.6)
            indent = rng.choice([0, 0, 0.5, 1.0])
            start = RIGHT * (left + indent) + UP * (top - 0.42 * i)
            lines.add(Line(start, start + RIGHT * width,
                           color=color_of(name), stroke_width=6,
                           stroke_opacity=0.55))
        return lines

    def mode_line_text(self, name: str) -> Text:
        text = Text(name, font=MONO, font_size=26, color=WHITE)
        text.move_to(self.mode_line, aligned_edge=LEFT)
        return text.shift(RIGHT * 0.3)

    def build_window(self) -> VGroup:
        self.window_frame = Rectangle(width=WINDOW_WIDTH, height=WINDOW_HEIGHT,
                                      color=GRAY_B, stroke_width=3)
        self.window_frame.move_to(WINDOW_CENTER)
        self.mode_line = Rectangle(width=WINDOW_WIDTH, height=0.5,
                                   color=GRAY_B, stroke_width=3,
                                   fill_color=GRAY_D, fill_opacity=1)
        self.mode_line.next_to(self.window_frame, DOWN, buff=0)
        self.mode_line_label = self.mode_line_text(self.sim.current)
        self.window_body = self.body_lines(self.sim.current)
        return VGroup(self.window_frame, self.mode_line,
                      self.mode_line_label, self.window_body)

    def build_buffer_list(self) -> VGroup:
        self.boxes = {name: BufferBox(name) for name in BUFFERS}
        for index, name in enumerate(self.sim.blist):
            self.boxes[name].move_to(slot_position(index))
        self.current_frame = RoundedRectangle(
            corner_radius=0.2, width=1.55, height=1.15, color=YELLOW,
            stroke_width=5).move_to(slot_position(0))
        self.current_label = Text("current", font_size=20, color=YELLOW)
        self.current_label.next_to(self.current_frame, DOWN, buff=0.1)
        title = Text("list of all buffers", font_size=24, color=GRAY_B)
        title.move_to(slot_position(0) + UP * 0.85, aligned_edge=LEFT)
        title.shift(LEFT * 0.65)
        direction = Text("most recent  →  least recent", font_size=20,
                         color=GRAY_B)
        direction.move_to(slot_position(len(BUFFERS) - 1) + UP * 0.85,
                          aligned_edge=RIGHT)
        direction.shift(RIGHT * 0.65)
        self.list_labels = VGroup(title, direction)
        return VGroup(*self.boxes.values(), self.current_frame,
                      self.current_label, self.list_labels)

    def build_keys(self) -> VGroup:
        title = Text("keys", font_size=22, color=GRAY_B)
        self.keys_box = RoundedRectangle(corner_radius=0.15, width=3.0,
                                         height=0.85, color=GRAY_B,
                                         stroke_width=3)
        self.keys_box.move_to(RIGHT * SIDE_X + UP * 2.0)
        title.next_to(self.keys_box, UP, buff=0.12)
        self.keys_text = self.keys_label("")
        return VGroup(title, self.keys_box, self.keys_text)

    def keys_label(self, keys: str) -> Text:
        # An empty label is an invisible placeholder glyph rather than
        # Text(" "): a space has no points, so transforming from it starts
        # from a stray point outside the box (a one-frame dot).
        label = Text(keys or "_", font=MONO, font_size=30, color=WHITE)
        if label.width > self.keys_box.width - 0.4:
            label.scale_to_fit_width(self.keys_box.width - 0.4)
        label.move_to(self.keys_box)
        return label if keys else label.set_opacity(0)

    def build_state(self) -> VGroup:
        title = Text("Smart Bury state", font_size=22, color=GRAY_B)
        title.move_to(RIGHT * SIDE_X + UP * 0.25)
        self.counter_text = self.counter_label(self.sim.counter)
        self.initial_marker = VGroup(
            Triangle(color=INITIAL_COLOR, fill_opacity=1).scale(0.12),
            Text("initial", font_size=18, color=INITIAL_COLOR),
        ).arrange(DOWN, buff=0.06)
        self.initial_marker.move_to(slot_position(0) + DOWN * 1.2)
        self.initial_marker.set_opacity(0)
        return VGroup(title, self.counter_text)

    def counter_label(self, counter: int) -> Text:
        return Text(f"counter: {counter}", font=MONO, font_size=24,
                    color=WHITE).move_to(RIGHT * SIDE_X + DOWN * 0.3)

    def say(self, text: str, wait: float = 1.5) -> None:
        """Replace the caption at the top of the frame."""
        new = Text(text, font_size=28, color=WHITE)
        if new.width > 13:
            new.scale_to_fit_width(13)
        new.move_to(UP * CAPTION_Y)
        if self.caption is None:
            self.play(FadeIn(new, shift=DOWN * 0.15))
        else:
            self.play(FadeOut(self.caption), FadeIn(new, shift=DOWN * 0.15))
        self.caption = new
        if wait > 0:
            self.wait(wait)

    # Animating the model

    def box_moves(self, old: list[str], new: list[str]) -> list:
        """Slide each box from its slot in OLD to its slot in NEW.

        A box jumping two or more slots moves along an arc below the row
        (when buried) or above it (when brought back), so it doesn't pass
        through the other boxes.
        """
        moves = []
        for name in new:
            delta = new.index(name) - old.index(name)
            if delta == 0:
                continue
            # Counterclockwise: below the row moving right, above it
            # moving left.
            arc = 0 if abs(delta) < 2 else PI / 2.5
            moves.append(self.boxes[name].animate(path_arc=arc)
                         .move_to(slot_position(new.index(name))))
        return moves

    def initial_marker_target(self, initial: str | None,
                              order: list[str], visible: bool):
        """Animation putting the "initial" marker under INITIAL's box."""
        if initial is None or initial not in order:
            return self.initial_marker.animate.set_opacity(0)
        target = slot_position(order.index(initial)) + DOWN * 1.2
        return (self.initial_marker.animate.move_to(target)
                .set_opacity(1 if visible else 0))

    def show_keys(self, keys: str) -> None:
        self.play(Transform(self.keys_text, self.keys_label(keys)),
                  run_time=0.4)

    def press(self, keys: str, action, caption: str = "") -> None:
        """Press KEYS, run ACTION on the model, and animate the result.

        KEYS continue the key sequence on display unless the previous
        command was not a Smart Bury one, in which case they start it.
        The caption shows first, with a pause to read it before the
        motion; the wait afterward grows with the caption's length.
        """
        if caption:
            self.say(caption, wait=0.8)
        old = list(self.sim.blist)
        if self.sim.last_command == WORK:
            self.key_sequence = []
        self.key_sequence.append(keys)
        self.show_keys(" ".join(self.key_sequence[-4:]))
        step = action()
        new = list(step.blist)
        animations = self.box_moves(old, new)
        if new[0] != old[0]:
            animations += [
                Transform(self.mode_line_label,
                          self.mode_line_text(new[0])),
                Transform(self.window_body, self.body_lines(new[0])),
            ]
        animations += [
            Transform(self.counter_text, self.counter_label(step.counter)),
            self.initial_marker_target(step.initial, new, visible=True),
        ]
        self.play(*animations, run_time=1.2)
        self.wait(max(1.2, 0.18 * len(caption.split())))

    def work(self, caption: str) -> None:
        """Any other command (e.g. typing), which ends the sequence."""
        self.say(caption, wait=0)
        self.sim.work()
        self.key_sequence = []
        self.play(Transform(self.keys_text,
                            self.keys_label("…typing…")),
                  Indicate(self.window_frame, color=WHITE, scale_factor=1.02),
                  self.initial_marker.animate.set_opacity(0))
        self.wait(1)
        self.show_keys("")

    def reset(self, label: str, title: str,
              buffers: list[str] | None = None) -> None:
        """Introduce a case with a LABEL and TITLE card, then start over.

        The whole stage fades out, the title shows alone in the center,
        the buffers reset to a fresh list while nothing is visible, and
        the stage fades back in.
        """
        buffers = buffers or BUFFERS
        if self.caption is not None:
            self.play(FadeOut(self.caption))
            self.caption = None
        stage = list(self.mobjects)
        self.play(*(FadeOut(mobject) for mobject in stage))

        card = VGroup(Text(label, font_size=26, color=GRAY_B),
                      Text(title, font_size=44, weight="BOLD"))
        card.arrange(DOWN, buff=0.3)
        self.play(FadeIn(card, shift=UP * 0.2))
        self.wait(2)
        self.play(FadeOut(card))

        self.sim = SmartBury(buffers)
        self.key_sequence = []
        # Rename boxes whose buffer isn't in the new list to the missing
        # names (e.g. A -> *Messages* for Case 7, and back afterward).
        unused = [name for name in self.boxes if name not in buffers]
        missing = [name for name in buffers if name not in self.boxes]
        for old_name, new_name in zip(unused, missing):
            self.boxes[old_name].become(BufferBox(new_name))
            self.boxes[new_name] = self.boxes.pop(old_name)
        for index, name in enumerate(buffers):
            self.boxes[name].move_to(slot_position(index))
        self.mode_line_label.become(self.mode_line_text(buffers[0]))
        self.window_body.become(self.body_lines(buffers[0]))
        self.keys_text.become(self.keys_label(""))
        self.counter_text.become(self.counter_label(1))
        self.initial_marker.set_opacity(0)
        self.play(*(FadeIn(mobject) for mobject in stage))
        self.wait(0.5)

    def restart(self, caption: str) -> None:
        """Start over from the default buffer list within the same case."""
        self.say(caption, wait=0)
        old = list(self.sim.blist)
        self.sim = SmartBury(BUFFERS)
        self.key_sequence = []
        self.play(*self.box_moves(old, BUFFERS),
                  Transform(self.mode_line_label,
                            self.mode_line_text(BUFFERS[0])),
                  Transform(self.window_body, self.body_lines(BUFFERS[0])),
                  Transform(self.keys_text, self.keys_label("")),
                  Transform(self.counter_text, self.counter_label(1)),
                  self.initial_marker.animate.set_opacity(0),
                  run_time=1.2)
        self.wait(1)

    # Scenes

    def intro(self) -> None:
        title = Text("Smart Bury", font_size=72, weight="BOLD")
        tagline = Text("Keep wanted buffers at the top of the "
                       "“list of all buffers”", font_size=30, color=GRAY_B)
        VGroup(title, tagline).arrange(DOWN, buff=0.4)
        self.play(Write(title), FadeIn(tagline, shift=UP * 0.2))
        self.wait(1.5)
        self.play(FadeOut(title), FadeOut(tagline))

        window = self.build_window()
        self.say("The window shows the current buffer.", wait=0)
        self.play(Create(self.window_frame), FadeIn(self.mode_line),
                  FadeIn(self.mode_line_label),
                  Create(self.window_body, lag_ratio=0.2))
        self.wait(1)

        buffer_list = self.build_buffer_list()
        self.say("Emacs keeps a “list of all buffers”, "
                 "most recently used first.", wait=0)
        self.play(AnimationGroup(*(FadeIn(self.boxes[name], shift=UP * 0.3)
                                   for name in self.sim.blist),
                                 lag_ratio=0.15),
                  FadeIn(self.list_labels))
        self.play(Create(self.current_frame), FadeIn(self.current_label))
        self.say("The current buffer is always the first one.")

        keys = self.build_keys()
        self.say("The keys pressed appear here.", wait=0)
        self.play(FadeIn(keys))
        self.wait(1)

        state = self.build_state()
        self.say("Smart Bury remembers where a sequence started, "
                 "and how deep it went.", wait=0)
        self.play(FadeIn(state), self.initial_marker.animate.set_opacity(1))
        self.wait(2)
        self.play(self.initial_marker.animate.set_opacity(0))
        self.wait(0.5)
        self.window = window
        self.buffer_list = buffer_list

    def case_1(self, label: str, title: str) -> None:
        self.reset(label, title)
        self.press("C-x M--", self.sim.bury,
                   "C-x M-- buries A: it goes to the end of the list, "
                   "and B shows.")
        self.say("A stays out of the way until explicitly asked for "
                 "(e.g. with C-x b).", wait=2.5)

    def case_2(self, label: str, title: str) -> None:
        self.reset(label, title)
        self.press("C-x _", self.sim.switch_through,
                   "C-x _ (or C-x M-_) switches to the other buffer, B.")
        self.work("Write some lines in B…")
        self.press("C-x _", self.sim.switch_through,
                   "The same keys come back to A.")
        self.say("The list is as it was. Working in B is what made "
                 "this a new sequence (see Case 6).", wait=2.5)

    def case_3(self, label: str, title: str) -> None:
        self.reset(label, title)
        self.press("C-x _", self.sim.switch_through,
                   "C-x _ (or C-x M-_) presents B.")
        self.say("Read B…", wait=1)
        self.press("M-_", self.sim.switch_to_other,
                   "M-_ gets back to A.")
        self.say("And the list is exactly as it was before.", wait=2)

    def case_4(self, label: str, title: str) -> None:
        self.reset(label, title)
        self.press("C-x _", self.sim.switch_through,
                   "C-x _ switches to the other buffer, B.")
        self.press("_", self.sim.switch_through,
                   "Another _ goes one buffer further, to C. "
                   "Nothing was buried on the way.")
        self.say("Read C…", wait=1)
        self.press("M-_", self.sim.switch_to_other,
                   "M-_ goes back to where the sequence started, A.")
        self.say("And the list is exactly as it was before.", wait=2)

    def case_5(self, label: str, title: str) -> None:
        self.reset(label, title)
        self.press("C-x _", self.sim.switch_through,
                   "C-x _ switches to B.")
        self.press("M--", self.sim.bury,
                   "M-- buries B and lands on C, not back on A.")
        self.say("Read C…", wait=1)
        self.press("M-_", self.sim.switch_to_other,
                   "M-_ goes back to A.")
        self.say("B is now at the end of the list, "
                 "and C is the other buffer.", wait=2)
        self.work("Work on A…")
        self.press("C-x _", self.sim.switch_through,
                   "To do the same again, C-x _ now goes straight to C.")
        self.press("M-_", self.sim.switch_to_other,
                   "M-_ goes back to A.")
        self.say("And the list stays the same.", wait=2)

    def case_6(self, label: str, title: str) -> None:
        self.reset(label, title)
        for target in ("C", "B", "A"):
            self.work(f"Work on {self.sim.current}…")
            self.press("C-x _", self.sim.switch_through,
                       "C-x _ _ goes two buffers deep…")
            self.press("_", self.sim.switch_through,
                       f"…to {target}.")
        self.say("A, C, B, A: after a full cycle, "
                 "the list is as it was.", wait=2.5)
        self.work("But without working in between…")
        for keys in ("C-x _", "_", "_", "_"):
            self.press(keys, self.sim.switch_through)
        self.say("…C-x _ _ followed by C-x _ _ is C-x _ _ _ _, "
                 "which reaches E.", wait=2.5)

    def case_7(self, label: str, title: str) -> None:
        self.reset(label, title, ["*Messages*"] + BUFFERS[1:])
        self.press("q", self.sim.quit,
                   "q quits *Messages*: Smart Bury buries it and shows B.")
        self.press("_", self.sim.switch_through,
                   "_ continues the sequence, straight to C.")
        self.say("*Messages* waits at the end of the list "
                 "until it is needed again.", wait=2.5)

    def why_smart(self, label: str, title: str) -> None:
        self.reset(label, title)
        self.press("C-x _", self.sim.switch_through, "Go to B…")
        self.press("M--", self.sim.bury,
                   "…and bury it right away: Smart Bury goes on to C, "
                   "not back to A.")
        self.say("B was simply on the way.", wait=2)
        self.restart("Again from A, but this time we stop and work on B.")
        self.press("C-x _", self.sim.switch_through, "Go to B…")
        self.work("…and work on it…")
        self.press("C-x M--", self.sim.bury,
                   "…then burying B goes back to A, as usual.")
        self.press("_", self.sim.switch_through,
                   "If C was intended instead, one extra _ gets us there.")
        self.say("Smart Bury follows what we were doing.", wait=2.5)

    def outro(self) -> None:
        self.play(*(FadeOut(mobject) for mobject in self.mobjects))
        title = Text("Smart Bury", font_size=64, weight="BOLD")
        link = Text("github.com/pedrormjunior/smart-bury", font=MONO,
                    font_size=28, color=GRAY_B)
        VGroup(title, link).arrange(DOWN, buff=0.4)
        self.play(FadeIn(title, shift=UP * 0.2), FadeIn(link))
        self.wait(2.5)


# The README's cases, in order: (section label, title, scene method).
CASES = [
    ("Case 1", "Done with A for a while", SmartBuryDemo.case_1),
    ("Case 2", "Write in B, then come back to A", SmartBuryDemo.case_2),
    ("Case 3", "Read something in B, then come back to A",
     SmartBuryDemo.case_3),
    ("Case 4", "Read something in C, then come back to A",
     SmartBuryDemo.case_4),
    ("Case 5", "B is on the way, and no longer needed",
     SmartBuryDemo.case_5),
    ("Case 6", "Working on three buffers in turn", SmartBuryDemo.case_6),
    ("Case 7", "Done reading *Messages*", SmartBuryDemo.case_7),
    ("Why is it “smart”?", "Buried on the way, or after working on it",
     SmartBuryDemo.why_smart),
]
