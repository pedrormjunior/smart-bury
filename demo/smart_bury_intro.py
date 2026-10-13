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
from xml.sax.saxutils import escape

from manim import (
    DOWN,
    LEFT,
    PI,
    TAU,
    RIGHT,
    UP,
    GRAY_A,
    GRAY_B,
    GRAY_D,
    WHITE,
    ManimColor,
    AnimationGroup,
    Create,
    DashedVMobject,
    FadeIn,
    FadeOut,
    Indicate,
    Line,
    MarkupText,
    Rectangle,
    RoundedRectangle,
    Scene,
    Text,
    Transform,
    Triangle,
    VGroup,
    Wiggle,
    Write,
)

from smart_bury_demo import MONO
from smart_bury_sim import SMART_COMMANDS, SmartBury

Text.set_default(font="Sans", color="#ebdbb2")

BUFFERS = ["A", "B", "C", "D", "E"]
# Rainbow colors, so the list's order is easy to follow (the long demo
# keeps its own palette).
COLORS = {
    "A": "#e8475f",     # red
    "B": "#f5893b",     # orange
    "C": "#f2d45c",     # yellow
    "D": "#5cc96b",     # green
    "E": "#b07ce8",     # violet (not blue, to stay apart from CURRENT_COLOR)
}
CURRENT_COLOR = "#00bfff"
# The keys repeat-mode offers after a Smart Bury command, in the order of
# the package's description (bury, switch through, switch to the other).
REPEAT_KEYS = ["M--", "_", "M-_"]
INITIAL_COLOR = "#ff9fbf"   # "initial" marker and counter
OTHER_COLOR = GRAY_A
PROMPT_COLOR = CURRENT_COLOR
BACKGROUND = "#000000"
NAME_COLOR = "#00bfff"  # command and mode names
DIM_COLOR = "#ebdbb2"   # secondary (dimmed) text
HIGHLIGHT = NAME_COLOR
KEY_FILL = GRAY_D
KEY_STROKE = GRAY_B
TAGLINE = "Keep wanted buffers at the top of the “list of all buffers”"

# Geometry (Manim's frame is about 14.2 x 8 units, centered on ORIGIN).
MARGIN = 0.8            # left margin of the Emacs frame, and right margin
FRAME_WIDTH = 8.2
FRAME_X = -7.11 + MARGIN + FRAME_WIDTH / 2   # center of frame and list
# From top to bottom: the Emacs frame, the buffer list, the caption.
FRAME_TOP = 3.5
WINDOW_BOTTOM = 0.9
MODE_LINE_HEIGHT = 0.45
MINIBUFFER_HEIGHT = 0.45
SLOT_SPACING = 1.65
LIST_TITLE_Y = -0.45
LIST_Y = -1.3
MARKER_LABEL_Y = -2.1
INITIAL_Y = -2.44
KEYS_BOX_WIDTH = 3.4
SIDE_X = 7.11 - MARGIN - KEYS_BOX_WIDTH / 2
KEYS_Y = 0.2
CAPTION_Y = -3.3
KEYS_FONT_SIZE = 26
KEYS_GAP = 0.12
KEY_ROOM = 0.1   # extra room on each side of a key box in running text


def slot_position(index: int):
    """Center of the INDEXth slot (0 = most recent) of the buffer list."""
    offset = SLOT_SPACING * (index - (len(BUFFERS) - 1) / 2)
    return RIGHT * (FRAME_X + offset) + UP * LIST_Y


def frame_left() -> float:
    return FRAME_X - FRAME_WIDTH / 2


def minibuffer_y() -> float:
    return WINDOW_BOTTOM - MODE_LINE_HEIGHT - MINIBUFFER_HEIGHT / 2


# Rich text: key boxes, italics, and highlighted symbols

def parse_rich(text: str) -> tuple[str, str, list[tuple[int, int]]]:
    """Parse TEXT's markup into plain text, Pango markup, and key spans.

    `KEYS` is a key (or key sequence) drawn in a monospace key box,
    ~TEXT~ is italic, and {SYMBOL} is a monospace symbol in the
    highlight color.  The key spans are (start, end) offsets into the
    plain text.
    """
    plain, markup, keys = "", "", []
    italic = False
    i = 0
    while i < len(text):
        char = text[i]
        if char == "`":
            end = text.index("`", i + 1)
            key = text[i + 1:end]
            keys.append((len(plain), len(plain) + len(key)))
            plain += key
            markup += (f'<span font_family="{MONO}" foreground="{{color}}">'
                       f'{escape(key)}</span>')
            i = end + 1
        elif char == "{":
            end = text.index("}", i + 1)
            symbol = text[i + 1:end]
            plain += symbol
            markup += (f'<span font_family="{MONO}" foreground="{HIGHLIGHT}">'
                       f'{escape(symbol)}</span>')
            i = end + 1
        elif char == "~":
            markup += "</i>" if italic else "<i>"
            italic = not italic
            i += 1
        else:
            plain += char
            markup += escape(char)
            i += 1
    return plain, markup, keys


def glyph_count(text: str) -> int:
    """How many glyphs TEXT renders to: one per non-blank character."""
    return sum(1 for char in text if not char.isspace())


def rich_text(text: str, font_size: float = 26, color=None,
              font: str = "Sans") -> VGroup:
    """Render TEXT (see `parse_rich') as one line: VGroup(boxes, glyphs).

    The text is rendered after an "M" strut, which gives the line's
    baseline and cap height, so every key box spans the same height, with
    equal padding above the caps and below the baseline, and keys keep
    their baseline: a lone `_' isn't centered like a dash.  Underscores
    in keys are raised onto the baseline.  The strut is then dropped.  Ligatures
    are off, so each character maps to exactly one glyph.

    Glyphs are shifted to make KEY_ROOM on each side of every key, so
    neighboring text stays clear of its box.  (A space character can't
    do this: in a monospace font every space is a full cell wide.)
    """
    color = DIM_COLOR if color is None else color
    plain, markup, keys = parse_rich(text)
    # Keys take the text's color.
    markup = markup.replace("{color}", ManimColor(color).to_hex())
    strut = "M"
    rendered = MarkupText(
        f'<span font_features="liga=0">{strut}{markup}</span>',
        font=font, font_size=font_size, color=color)
    if len(rendered.submobjects) != len(strut) + glyph_count(plain):
        raise ValueError(f"glyphs don't map to characters in {text!r}")
    top = rendered[0].get_top()[1]          # cap height
    baseline = rendered[0].get_bottom()[1]
    pad = 0.3 * (top - baseline)
    spans = [(len(strut) + glyph_count(plain[:start]),
              len(strut) + glyph_count(plain[:end])) for start, end in keys]
    for first, last in spans:
        for glyph in rendered[first:]:
            glyph.shift(RIGHT * KEY_ROOM)
        for glyph in rendered[last:]:
            glyph.shift(RIGHT * KEY_ROOM)
    # Underscores in keys sit on the baseline, like the other letters,
    # rather than below it.
    chars = [char for char in plain if not char.isspace()]
    for first, last in spans:
        for index in range(first, last):
            if chars[index - len(strut)] == "_":
                glyph = rendered[index]
                glyph.shift(UP * (baseline - glyph.get_bottom()[1]))
    boxes = VGroup()
    for first, last in spans:
        glyphs = VGroup(*rendered[first:last])
        box = RoundedRectangle(corner_radius=0.06, width=glyphs.width + 0.16,
                               height=top - baseline + 2 * pad,
                               color=KEY_STROKE, stroke_width=1.5,
                               fill_color=KEY_FILL, fill_opacity=1)
        boxes.add(box.move_to(RIGHT * glyphs.get_center()[0]
                              + UP * (top + baseline) / 2))
    return VGroup(boxes, VGroup(*rendered[len(strut):]))


def key_box(keys: str, font_size: float = KEYS_FONT_SIZE) -> VGroup:
    """KEYS (e.g. "C-x M--") alone in a monospace key box."""
    return rich_text(f"`{keys}`", font_size=font_size, font=MONO)


def buffer_box(name: str) -> VGroup:
    """A buffer in the list: a rounded box in the buffer's color."""
    box = RoundedRectangle(corner_radius=0.15, width=1.3, height=0.9,
                           color=COLORS[name], stroke_width=4,
                           fill_color=COLORS[name], fill_opacity=0.25)
    label = Text(name, font=MONO, font_size=34, color=DIM_COLOR)
    return VGroup(box, label.move_to(box))


class SmartBuryIntro(Scene):
    def construct(self) -> None:
        self.camera.background_color = BACKGROUND
        self.sim = SmartBury(BUFFERS)
        self.key_boxes: list[VGroup] = []
        self.caption: VGroup | None = None
        self.state_visible = False

        self.next_section("Title")
        self.title_card()
        self.next_section("Three basic commands")
        self.basic_commands_card()
        self.next_section("Wrapped commands")
        self.wrapped_commands_card()
        self.next_section("Stage")
        self.stage()
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
        self.boxes = {name: buffer_box(name).move_to(slot_position(index))
                      for index, name in enumerate(self.sim.blist)}
        first, last = slot_position(0), slot_position(len(BUFFERS) - 1)
        title = Text("list of all buffers", font_size=22, color=DIM_COLOR)
        title.move_to(RIGHT * (first[0] - 0.65) + UP * LIST_TITLE_Y,
                      aligned_edge=LEFT)
        direction = Text("most recent  →  least recent", font_size=18,
                         color=DIM_COLOR)
        direction.move_to(RIGHT * (last[0] + 0.65) + UP * LIST_TITLE_Y,
                          aligned_edge=RIGHT)
        self.list_labels = VGroup(title, direction)

    def build_markers(self) -> None:
        """The fixed frames marking the current and the other buffer."""
        self.current_frame = RoundedRectangle(
            corner_radius=0.2, width=1.55, height=1.15, color=CURRENT_COLOR,
            stroke_width=5).move_to(slot_position(0))
        self.current_label = Text("current", font_size=18,
                                  color=CURRENT_COLOR)
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
                           color=COLORS[name], stroke_width=6,
                           stroke_opacity=0.55))
        return lines

    def mode_line_text(self, name: str) -> Text:
        text = Text(name, font=MONO, font_size=24, color=DIM_COLOR)
        text.move_to(self.mode_line, aligned_edge=LEFT)
        return text.shift(RIGHT * 0.3)

    def at_minibuffer(self, mobject):
        return mobject.move_to(RIGHT * (frame_left() + 0.3)
                               + UP * minibuffer_y(), aligned_edge=LEFT)

    def minibuffer_label(self, prompt: str = "", typed: str = "") -> VGroup:
        """The minibuffer's contents: PROMPT, then TYPED and a cursor.

        Prompt and input are one text, so the space between them is kept.
        Empty, it is an invisible placeholder glyph rather than nothing,
        so that transforming from it doesn't start from a stray point.
        """
        if not prompt:
            placeholder = Text("_", font=MONO, font_size=22).set_opacity(0)
            return self.at_minibuffer(VGroup(placeholder))
        # Without input, an invisible "M" holds the cursor's cell, one
        # space after the prompt's colon.
        line = MarkupText(f'<span foreground="{PROMPT_COLOR}">'
                          f'{escape(prompt)}</span>{escape(typed or "M")}',
                          font=MONO, font_size=22, color=DIM_COLOR)
        cursor = Rectangle(width=0.16, height=0.3, color=DIM_COLOR,
                           fill_opacity=0.9, stroke_width=0)
        if typed:
            cursor.next_to(line, RIGHT, buff=0.05)
        else:
            cell = line[-1]
            cell.set_opacity(0)
            cursor.move_to(cell.get_left() + RIGHT * cursor.width / 2
                           + UP * (line[0].get_center()[1]
                                   - cell.get_center()[1]))
            cursor.set_y(line[0].get_center()[1])
        return self.at_minibuffer(VGroup(line, cursor))

    def repeat_message(self) -> VGroup:
        """`repeat-mode's echo after a Smart Bury command.

        The keys are in the order of the package's description (bury,
        switch through, switch to the other buffer), in key boxes like
        Emacs' `help-key-binding' face.
        """
        keys = ", ".join(f"`{key}`" for key in REPEAT_KEYS)
        return self.at_minibuffer(
            rich_text(f"[Repeat with: {keys}]", font_size=22,
                      color=DIM_COLOR, font=MONO))

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
        keys_title = Text("keys", font_size=22, color=DIM_COLOR)
        self.keys_box = RoundedRectangle(corner_radius=0.15,
                                         width=KEYS_BOX_WIDTH, height=0.85,
                                         color=GRAY_B, stroke_width=3)
        self.keys_box.move_to(RIGHT * SIDE_X + UP * KEYS_Y)
        keys_title.next_to(self.keys_box, UP, buff=0.12)
        self.keys_panel = VGroup(keys_title, self.keys_box)
        state_title = Text("Smart Bury state", font_size=22, color=DIM_COLOR)
        state_title.move_to(RIGHT * SIDE_X + UP * (KEYS_Y - 1.25))
        self.counter_text = self.counter_label(self.sim.counter)
        self.state_panel = VGroup(state_title, self.counter_text)

    def counter_label(self, counter: int) -> Text:
        return Text(f"counter: {counter}", font=MONO, font_size=24,
                    color=INITIAL_COLOR).move_to(RIGHT * SIDE_X
                                                 + UP * (KEYS_Y - 1.75))

    def say(self, text: str, wait: float = 1.5) -> None:
        """Replace the caption at the bottom (see `parse_rich' for TEXT)."""
        new = rich_text(text, font_size=26, color=WHITE)  # captions: white
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

    # The keys panel: one key box per press, appended on the right

    def keys_push(self, keys: str) -> list:
        """Animations appending a key box for KEYS to the keys panel.

        The boxes already there slide left to make room, and those
        pushed past the panel's left edge fade out.
        """
        new = key_box(keys)
        boxes = self.key_boxes + [new]
        right = self.keys_box.get_right()[0] - 0.2
        left_limit = self.keys_box.get_left()[0] + 0.2
        y = self.keys_box.get_center()[1]
        targets, x = [], right
        for box in reversed(boxes):
            targets.append(x - box.width / 2)
            x -= box.width + KEYS_GAP
        targets.reverse()
        animations, kept = [], []
        for box, target in zip(boxes, targets):
            fits = target - box.width / 2 >= left_limit
            if box is new:
                box.move_to(RIGHT * target + UP * y)
                animations.append(FadeIn(box, shift=LEFT * 0.4))
                kept.append(box)
            elif fits:
                animations.append(box.animate.move_to(RIGHT * target
                                                      + UP * y))
                kept.append(box)
            else:
                animations.append(FadeOut(box, shift=LEFT * 0.4))
        self.key_boxes = kept
        return animations

    def keys_clear(self) -> list:
        """Animations removing every key box from the keys panel."""
        animations = [FadeOut(box) for box in self.key_boxes]
        self.key_boxes = []
        return animations

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
                     run_time: float, extra: list | None = None) -> None:
        """Animate the model's new state: list, window, state, minibuffer.

        EXTRA animations, if any, play along with it.
        """
        new = list(self.sim.blist)
        animations = self.box_moves(old, new) + list(extra or [])
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

    def glow(self, key: VGroup) -> VGroup:
        """Make KEY (a key box from `rich_text') glow in CURRENT_COLOR.

        Its box's outline turns CURRENT_COLOR, and a soft halo follows
        the box frame by frame, so it stays with the box while the box
        slides or wiggles.  Returns the halo, for `glow_off'.
        """
        box = key[0][0]
        box.set_stroke(CURRENT_COLOR, width=3)

        def follow(halo):
            halo.become(box.copy().set_fill(opacity=0).set_stroke(
                CURRENT_COLOR, width=12,
                opacity=0.35 * box.get_stroke_opacity()))

        halo = box.copy()
        follow(halo)
        halo.add_updater(follow)
        self.add(halo)
        return halo

    def glow_off(self, keys: list[VGroup], halos: list[VGroup]) -> None:
        """Fade the glow of KEYS out: halos vanish, outlines turn back."""
        for halo in halos:
            halo.clear_updaters()
        self.play(*(FadeOut(halo) for halo in halos),
                  *(key[0][0].animate.set_stroke(KEY_STROKE, width=1.5)
                    for key in keys),
                  run_time=0.3)
        self.remove(*halos)

    def press(self, keys: str, action, caption: str = "",
              expect: str | None = None, fast: bool = False) -> None:
        """Press KEYS, run the model's ACTION, and animate the result.

        KEYS are appended to the keys panel, unless they start with C-x
        or the previous command was not a Smart Bury one, in which case
        they start a new key sequence there.  EXPECT, if given, is the
        buffer order the storyboard expects.
        """
        if caption:
            self.say(caption, wait=0.25 if fast else 0.5)
        animations = []
        if (keys.startswith("C-x")
                or self.sim.last_command not in SMART_COMMANDS):
            animations += self.keys_clear()
        repeating = (keys in REPEAT_KEYS
                     and self.sim.last_command in SMART_COMMANDS)
        animations += self.keys_push(keys)
        glowing, halos, wiggles = [], [], []
        if repeating:
            # The minibuffer shows repeat-mode's message: the key pressed
            # there, and its new box in the keys panel, glow and wiggle
            # from the press through the step's animation.  In the
            # minibuffer, a copy laid exactly over the key does it, so
            # the message itself is untouched.
            target = self.repeat_message()[0][REPEAT_KEYS.index(keys)]
            overlay = key_box(keys, font_size=22)
            overlay.shift(target.get_center() - overlay[0][0].get_center())
            self.add(overlay)
            for key in (overlay, self.key_boxes[-1]):
                halos.append(self.glow(key))
                glowing.append(key)
                wiggles.append(Wiggle(key, scale_value=1.25,
                                      rotation_angle=0.03 * TAU,
                                      n_wiggles=4))
        self.play(*animations, run_time=0.25 if fast else 0.4)
        old = list(self.sim.blist)
        action()
        if expect is not None:
            self.expect(expect, keys)
        self.update_stage(old, self.repeat_message(),
                          run_time=0.55 if fast else 1.0, extra=wiggles)
        if repeating:
            self.glow_off(glowing, halos)
            self.remove(glowing[0])    # the minibuffer's overlay
        self.wait(0.35 if fast else max(1.0, 0.15 * len(caption.split())))

    def work(self, caption: str, expect: str | None = None) -> None:
        """Any other command (e.g. typing), which ends the sequence and
        clears `repeat-mode's message."""
        self.say(caption, wait=0)
        self.sim.work()
        if expect is not None:
            self.expect(expect, "work")
        typing = Text("typing…", font_size=24, color=DIM_COLOR, slant="ITALIC")
        typing.move_to(self.keys_box)
        animations = self.keys_clear() + [
            FadeIn(typing),
            Indicate(self.window_body, color=WHITE, scale_factor=1.03),
            Transform(self.minibuffer, self.minibuffer_label()),
        ]
        if self.state_visible:
            animations.append(self.initial_marker.animate.set_opacity(0))
        self.play(*animations, run_time=0.8)
        self.wait(0.7)
        self.play(FadeOut(typing), run_time=0.3)

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
        self.play(*self.keys_clear(), *self.keys_push("C-x b"),
                  Transform(self.minibuffer, self.minibuffer_label(prompt)),
                  run_time=0.3 if fast else 0.45)
        self.wait(0.2 if fast else 0.45)
        if name != default:
            self.play(*self.keys_push(name),
                      Transform(self.minibuffer,
                                self.minibuffer_label(prompt, name)),
                      run_time=0.25 if fast else 0.35)
            self.wait(0.2 if fast else 0.35)
        self.play(*self.keys_push("RET"), run_time=0.2 if fast else 0.3)
        old = list(self.sim.blist)
        self.sim.switch_to_buffer(name)
        if expect is not None:
            self.expect(expect, f"C-x b {name} RET")
        self.update_stage(old, self.minibuffer_label(),
                          run_time=0.55 if fast else 1.0)
        self.wait(0.35 if fast else 1.0)

    # Cards

    def clear_all(self) -> None:
        self.play(*(FadeOut(mobject) for mobject in self.mobjects))
        self.caption = None
        self.key_boxes = []

    def title_card(self) -> None:
        title = Text("Smart Bury", font_size=72, weight="BOLD")
        tagline = Text(TAGLINE, font_size=30, color=DIM_COLOR)
        VGroup(title, tagline).arrange(DOWN, buff=0.4)
        self.play(Write(title), FadeIn(tagline, shift=UP * 0.2))
        self.wait(2)
        self.clear_all()

    def card_heading(self, text: str) -> Text:
        return Text(text, font_size=40, weight="BOLD").move_to(UP * 2.9)

    def command_row(self, keys: str, description: str,
                    symbol: str) -> VGroup:
        """A key box, then a description over the command's name."""
        keys_group = key_box(keys, font_size=30)
        desc = rich_text(description, font_size=24)
        if desc.width > 10:
            desc.scale_to_fit_width(10)
        name = Text(symbol, font=MONO, font_size=20, color=NAME_COLOR)
        block = VGroup(desc, name).arrange(DOWN, aligned_edge=LEFT, buff=0.12)
        return VGroup(keys_group, block).arrange(RIGHT, buff=0.45)

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
                             "Bury the ~current buffer~, and move on smartly.",
                             "smart-bury-bury-buffer"),
            self.command_row("C-x _",
                             "Go to the ~other buffer~, then one deeper per "
                             "`_`, burying nothing.",
                             "smart-bury-switch-through-buffers"),
            self.command_row("C-x M-_",
                             "Go back to where the sequence started, or to "
                             "the ~other buffer~.",
                             "smart-bury-switch-to-other-buffer"),
        )
        # Align the key boxes in one column, and the descriptions in another.
        column = max(row[0].width for row in rows)
        for row in rows:
            row[1].next_to(row[0], RIGHT, buff=0.45 + column - row[0].width)
        rows.arrange(DOWN, aligned_edge=LEFT, buff=0.55).move_to(UP * 0.1)
        footer = VGroup(rich_text("With {repeat-mode}, continue with just "
                                  "`M--`, `_`, or `M-_`.", font_size=24,
                                  color=DIM_COLOR))
        footer.move_to(DOWN * 2.9)
        self.show_card(heading, rows, footer, hold=3.5)

    def wrapped_row(self, vanilla: str, wrapper: str, note: str) -> VGroup:
        arrow = Text("→", font_size=28, color=DIM_COLOR)
        line = VGroup(Text(vanilla, font=MONO, font_size=26, color=DIM_COLOR),
                      arrow,
                      Text(wrapper, font=MONO, font_size=26, color=NAME_COLOR)
                      ).arrange(RIGHT, buff=0.3)
        hint = rich_text(note, font_size=20, color=DIM_COLOR)
        return VGroup(line, hint).arrange(DOWN, aligned_edge=LEFT, buff=0.12)

    def wrapped_commands_card(self) -> None:
        heading = self.card_heading("Wrapped commands")
        rows = VGroup(
            self.wrapped_row("quit-window", "smart-bury-quit-window",
                             "e.g. `q` in read-only buffers such as "
                             "*Messages*"),
            self.wrapped_row("kill-current-buffer",
                             "smart-bury-kill-current-buffer",
                             "on whatever key it is bound to"),
        ).arrange(DOWN, aligned_edge=LEFT, buff=0.6)
        rows.move_to(UP * 0.5)
        footer = VGroup(
            rich_text("They do their usual job, then continue the same "
                      "~smart~ sequence.", font_size=26, color=DIM_COLOR),
            rich_text("The list is customizable: "
                      "{smart-bury-wrapped-commands}.", font_size=22,
                      color=DIM_COLOR),
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

        self.say("The first is the ~current buffer~; "
                 "the second is the ~other buffer~.", wait=0)
        self.play(Create(self.current_frame), FadeIn(self.current_label))
        self.play(Create(self.other_frame), FadeIn(self.other_label))
        self.wait(1.2)

        self.say("The window shows the ~current buffer~; "
                 "the minibuffer sits below it.", wait=0)
        minibuffer_hint = self.at_minibuffer(
            Text("minibuffer", font_size=20, color=DIM_COLOR))
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
                 "typing its name.", wait=2)
        self.switch_to_buffer("C", "`C-x b` offers the ~other buffer~, B, "
                              "by default; we type C instead.",
                              expect="CABDE")
        self.switch_to_buffer("A", "Coming back to A, now the ~other "
                              "buffer~, is just `C-x b` `RET`…",
                              expect="ACBDE")
        self.say("…leaves C ahead of B: the list got shuffled.", wait=0)
        self.play(Indicate(self.boxes["C"], color=WHITE),
                  Indicate(self.boxes["B"], color=WHITE), run_time=1.2)
        self.wait(0.6)
        self.switch_to_buffer("B", "Putting it back takes more typing.",
                              expect="BACDE", fast=True)
        self.switch_to_buffer("A", expect="ABCDE", fast=True)
        self.say("Smart Bury moves through buffers without typing names…",
                 wait=1.8)
        self.say("…and keeps the list in order.", wait=1.8)

    def burying(self) -> None:
        self.press("C-x M--", self.sim.bury,
                   "`C-x M--` buries A: it goes to the end of the list, "
                   "and B shows.", expect="BCDEA")
        self.press("M--", self.sim.bury,
                   "Each further `M--` buries the ~current buffer~ in turn…",
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
        self.play(FadeIn(self.state_panel),
                  self.initial_marker_target(visible=True),
                  *self.keys_clear())
        self.wait(1.3)
        self.press("C-x _", self.sim.switch_through,
                   "`C-x _` goes to the ~other buffer~, B.", expect="BACDE")
        self.press("_", self.sim.switch_through,
                   "Each `_` goes one buffer further, burying nothing…",
                   expect="CABDE")
        self.press("_", self.sim.switch_through, expect="DABCE", fast=True)
        self.press("_", self.sim.switch_through,
                   "…up to the last one, E. Behind it, A B C D stay in "
                   "order.", expect="EABCD")
        self.work("Work on E for a while: any other command ends the "
                  "sequence.", expect="EABCD")
        self.press("C-x M--", self.sim.bury,
                   "Then `C-x M--` buries E: A is back on top, and the list "
                   "is as it started.", expect="ABCDE")

    def switching_to_other(self) -> None:
        self.press("C-x M-_", self.sim.switch_to_other,
                   "`C-x M-_` switches to the ~other buffer~, B…",
                   expect="BACDE")
        self.press("M-_", self.sim.switch_to_other,
                   "…and `M-_` switches back, as many times as wanted.",
                   expect="ABCDE")
        self.press("M-_", self.sim.switch_to_other, expect="BACDE",
                   fast=True)
        self.press("M-_", self.sim.switch_to_other,
                   "The ~current~ and the ~other buffer~ just trade places.",
                   expect="ABCDE")

    def breaking_the_sequence(self) -> None:
        self.press("C-x _", self.sim.switch_through,
                   "Without stopping, `C-x _` `_` `_` `_` goes four buffers "
                   "deep, to E.", expect="BACDE", fast=True)
        self.press("_", self.sim.switch_through, expect="CABDE", fast=True)
        self.press("_", self.sim.switch_through, expect="DABCE", fast=True)
        self.press("_", self.sim.switch_through, expect="EABCD")
        self.press("M-_", self.sim.switch_to_other,
                   "`M-_` goes back to A, with the list restored.",
                   expect="ABCDE")
        self.press("C-x _", self.sim.switch_through,
                   "Now `C-x _` `_` goes to C…", expect="BACDE", fast=True)
        self.press("_", self.sim.switch_through, expect="CABDE")
        self.work("…and we work on C for a while, which ends the sequence.",
                  expect="CABDE")
        self.press("C-x _", self.sim.switch_through,
                   "So `C-x _` `_` starts a new sequence from C: two deep is "
                   "now B.", expect="ACBDE", fast=True)
        self.press("_", self.sim.switch_through, expect="BCADE")
        self.press("M-_", self.sim.switch_to_other,
                   "`M-_` returns to C, where the new sequence started.",
                   expect="CABDE")
        self.say("Any other command starts a new sequence, "
                 "from wherever we are.", wait=2.5)

    def outro(self) -> None:
        self.clear_all()
        title = Text("Smart Bury", font_size=64, weight="BOLD")
        tagline = Text(TAGLINE, font_size=28, color=DIM_COLOR)
        link = Text("github.com/pedrormjunior/smart-bury", font=MONO,
                    font_size=26, color=DIM_COLOR)
        VGroup(title, tagline, link).arrange(DOWN, buff=0.4)
        self.play(FadeIn(title, shift=UP * 0.2), FadeIn(tagline),
                  FadeIn(link))
        self.wait(3)
