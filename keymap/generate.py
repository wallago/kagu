"""Render keymap.txt into the ZMK keymap.

Adapted from the keymap generator in denniskempin/dubu36 (MIT, (c) 2021
Dennis Kempin), trimmed to ZMK and to Kagu's 36-key matrix. The diagrams are
drawn from the generated keymap by keymap-drawer, see `just keymap`.

    python3 keymap/generate.py           write kagu.keymap
    python3 keymap/generate.py --check   fail if it is out of date
"""

from __future__ import annotations

import argparse
import re
import sys
from collections.abc import Iterable, Sequence
from pathlib import Path
from typing import NamedTuple

ROOT = Path(__file__).resolve().parent.parent
KEYMAP_TXT = ROOT / "keymap.txt"
TEMPLATE = ROOT / "keymap" / "template.keymap"
ZMK_OUT = ROOT / "config" / "boards" / "shields" / "kagu" / "kagu.keymap"

# Keys in each row of the grid: three rows of ten, then the thumbs.
ROW_SIZES = (10, 10, 10, 6)
HALF = 5  # columns 0-4 are the left half
BLANK = "_"
COMMENT = "//"

# ── Label vocabulary ─────────────────────────────────────────────────────────

# Labels that are a key press: the label maps to a ZMK key code for &kp.
# Single letters and digits are handled in `key_code`.
KEY_CODES: dict[str, str] = {
    "ESC": "ESC",
    "RET": "RET",
    "TAB": "TAB",
    "SPC": "SPACE",
    "BSPC": "BSPC",
    "DEL": "DEL",
    "INS": "INS",
    "CAPS": "CAPS",
    "APP": "K_APP",
    "PSCRN": "PSCRN",
    "SLCK": "SLCK",
    "PAUSE": "PAUSE_BREAK",
    "LEFT": "LEFT",
    "RIGHT": "RIGHT",
    "UP": "UP",
    "DOWN": "DOWN",
    "HOME": "HOME",
    "END": "END",
    "PGUP": "PG_UP",
    "PGDN": "PG_DN",
    "UNDO": "LC(Z)",
    "REDO": "LC(LS(Z))",
    "CUT": "LC(X)",
    "COPY": "LC(C)",
    "PASTE": "LC(V)",
    "STAB": "LS(TAB)",
    "WORD_L": "LC(LEFT)",
    "WORD_R": "LC(RIGHT)",
    "BACK": "LA(LEFT)",
    "FWD": "LA(RIGHT)",
    "TAB_L": "LC(PG_UP)",
    "TAB_R": "LC(PG_DN)",
    # Media
    "PREV": "C_PREV",
    "NEXT": "C_NEXT",
    "VOL-": "C_VOL_DN",
    "VOL+": "C_VOL_UP",
    "MUTE": "C_MUTE",
    "PLAY": "C_PP",
    "STOP": "C_STOP",
    # Symbols
    "`": "GRAVE",
    "~": "TILDE",
    "!": "EXCL",
    "@": "AT",
    "#": "HASH",
    "$": "DLLR",
    "%": "PRCNT",
    "^": "CARET",
    "&": "AMPS",
    "*": "STAR",
    "(": "LPAR",
    ")": "RPAR",
    "-": "MINUS",
    "_": "UNDER",
    "=": "EQUAL",
    "+": "PLUS",
    "[": "LBKT",
    "]": "RBKT",
    "{": "LBRC",
    "}": "RBRC",
    "\\": "BSLH",
    "PIPE": "PIPE",
    ";": "SEMI",
    ":": "COLON",
    "'": "SQT",
    '"': "DQT",
    ",": "COMMA",
    ".": "DOT",
    "<": "LT",
    ">": "GT",
    "/": "FSLH",
    "?": "QMARK",
    # Modifiers
    "LSHFT": "LSHFT",
    "LCTRL": "LCTRL",
    "LALT": "LALT",
    "LGUI": "LGUI",
    "RSHFT": "RSHFT",
    "RCTRL": "RCTRL",
    "RALT": "RALT",
    "RGUI": "RGUI",
}

MODIFIERS = frozenset(("LSHFT", "LCTRL", "LALT", "LGUI", "RSHFT", "RCTRL", "RALT", "RGUI"))

# Labels that are a ready-made binding rather than a key press.
SPECIAL: dict[str, str] = {
    "TRNS": "&trans",
    "BOOT": "&bootloader",
    "OUT_USB": "&out OUT_USB",
    "OUT_BLE": "&out OUT_BLE",
    "BT_PRV": "&bt BT_PRV",
    "BT_NXT": "&bt BT_NXT",
    "BT_CLR": "&bt BT_CLR",
    "BT_CLR_ALL": "&bt BT_CLR_ALL",
    **{f"BT_{n}": f"&bt BT_SEL {n}" for n in range(5)},
    "MS_L": "&mmv MOVE_LEFT",
    "MS_D": "&mmv MOVE_DOWN",
    "MS_U": "&mmv MOVE_UP",
    "MS_R": "&mmv MOVE_RIGHT",
    "WH_L": "&msc SCRL_LEFT",
    "WH_D": "&msc SCRL_DOWN",
    "WH_U": "&msc SCRL_UP",
    "WH_R": "&msc SCRL_RIGHT",
    "BTN1": "&mkp MB1",
    "BTN2": "&mkp MB2",
    "BTN3": "&mkp MB3",
}

FLAVORS = ("hm",)

# ── Parsing ──────────────────────────────────────────────────────────────────


class Key(NamedTuple):
    """What a key taps, what it holds (empty for nothing), and the hold flavor.

    `hold` is None while a layer cell still waits for an overlay to fill it.
    """

    tap: str
    hold: str | None
    flavor: str | None


class Layer(NamedTuple):
    """`modifier` is held for as long as the layer is held from a hold-tap."""

    name: str
    rows: list[list[Key]]
    modifier: str = ""


class Combo(NamedTuple):
    a: str
    b: str
    result: str
    layers: tuple[str, ...]
    idle_ms: int


class ParseError(Exception):
    def __init__(self, line_number: int, message: str) -> None:
        super().__init__(f"keymap.txt:{line_number}: {message}")


def split_unescaped(text: str, separator: str) -> list[str]:
    """Split on the first unescaped separator, leaving escapes intact."""
    i = 0
    while i < len(text):
        if text[i] == "\\" and i + 1 < len(text):
            i += 2
        elif text[i] == separator:
            return [text[:i], text[i + 1 :]]
        else:
            i += 1
    return [text]


def strip_comment(line: str) -> str:
    i = 0
    while i < len(line):
        if line[i] == "\\" and i + 1 < len(line):
            i += 2
        elif line.startswith(COMMENT, i):
            return line[:i]
        else:
            i += 1
    return line


def parse_label(field: str) -> str:
    """Normalize a label: unescape it, upper-case it, `_` becomes empty."""
    if field == BLANK:
        return ""
    return re.sub(r"\\(.)", r"\1", field).upper()


class Parser:
    def __init__(self) -> None:
        self.line_number = 0
        self.overlays: dict[str, list[list[Key]]] = {}
        self.layers: list[Layer] = []
        self.combos: list[Combo] = []
        self.block: tuple[str, str, list[str], str] | None = None
        self.combo_header: tuple[list[str], int, int] = ([], 0, 0)
        self.rows: list[list[Key]] = []

    def error(self, message: str) -> ParseError:
        return ParseError(self.line_number, message)

    def parse(self, lines: Iterable[str]) -> tuple[list[Layer], list[Combo]]:
        for self.line_number, raw in enumerate(lines, start=1):
            line = strip_comment(raw).strip()
            if not line:
                continue
            keyword, _, rest = line.partition(" ")
            keyword = keyword.rstrip(":")
            if keyword in ("overlay", "layer", "combos"):
                self.end_block()
                self.start_block(keyword, line[len(keyword) :].strip(" :"))
            elif self.block is None:
                raise self.error(f"expected an overlay, layer or combos block, got {line!r}")
            elif self.block[0] == "combos":
                self.combos.append(self.parse_combo(line.split()))
            else:
                self.rows.append(self.parse_row(line.split()))
        self.end_block()
        self.check()
        return self.layers, self.combos

    def start_block(self, keyword: str, rest: str) -> None:
        if keyword == "combos":
            names, idle = [], 0
            for item in rest.replace(",", " ").split():
                if item.startswith("idle="):
                    idle = int(item.removeprefix("idle="))
                else:
                    names.append(item)
            if not names:
                raise self.error("combos blocks name the layers they fire on")
            self.combo_header = (names, idle, self.line_number)
            self.block = (keyword, "", [], "")
            return
        rest, plus, modifier = rest.partition("+")
        modifier = parse_label(modifier.strip())
        if plus and keyword != "layer":
            raise self.error(f"{keyword} blocks cannot hold a modifier")
        if plus and modifier not in MODIFIERS:
            raise self.error(f"expected a modifier after '+', got {modifier!r}")
        name, _, tail = rest.partition(":")
        name = name.strip()
        if not name:
            raise self.error(f"{keyword} blocks need a name")
        overlays = [item.strip() for item in tail.split(",") if item.strip()]
        if overlays and keyword != "layer":
            raise self.error(f"{keyword} blocks cannot use overlays")
        for overlay in overlays:
            if overlay not in self.overlays:
                raise self.error(f"unknown overlay {overlay!r}")
        self.block = (keyword, name, overlays, modifier)
        self.rows = []

    def end_block(self) -> None:
        if self.block is None:
            return
        keyword, name, overlays, modifier = self.block
        if keyword != "combos":
            if len(self.rows) != len(ROW_SIZES):
                raise self.error(
                    f"{keyword} {name} has {len(self.rows)} rows, expected {len(ROW_SIZES)}"
                )
            if keyword == "overlay":
                self.overlays[name] = self.rows
            else:
                self.layers.append(Layer(name, self.apply_overlays(overlays), modifier))
        self.block = None
        self.rows = []

    def apply_overlays(self, overlays: Sequence[str]) -> list[list[Key]]:
        """Fill in the hold of every cell that does not define one itself."""
        keys: list[list[Key]] = []
        for y, row in enumerate(self.rows):
            keys.append([])
            for x, (tap, hold, flavor) in enumerate(row):
                if hold is None:
                    # The last overlay that covers the cell wins.
                    for overlay in overlays:
                        _, covered, covered_flavor = self.overlays[overlay][y][x]
                        if covered:
                            hold, flavor = covered, covered_flavor
                keys[-1].append(Key(tap, hold or "", flavor))
        return keys

    def parse_row(self, cells: Sequence[str]) -> list[Key]:
        assert self.block is not None
        keyword, name, *_ = self.block
        row = len(self.rows)
        if row >= len(ROW_SIZES):
            raise self.error(f"{keyword} {name} has more than {len(ROW_SIZES)} rows")
        if len(cells) != ROW_SIZES[row]:
            raise self.error(
                f"row {row} of {keyword} {name} has {len(cells)} keys, expected {ROW_SIZES[row]}"
            )
        if keyword == "overlay":
            # Overlay cells only define the hold of the keys they cover.
            return [Key("", *self.parse_hold(cell)) for cell in cells]
        return [self.parse_key(cell) for cell in cells]

    def parse_key(self, cell: str) -> Key:
        parts = split_unescaped(cell, "/")
        if len(parts) == 1:
            return Key(parse_label(parts[0]), None, None)
        key = Key(parse_label(parts[0]), *self.parse_hold(parts[1]))
        if key.flavor and key.tap == key.hold:
            raise self.error(f"{cell!r} is a one-shot key, which takes no flavor")
        return key

    def parse_hold(self, field: str) -> tuple[str, str | None]:
        parts = split_unescaped(field, ":")
        flavor = parts[1] if len(parts) > 1 else None
        if flavor is not None and flavor not in FLAVORS:
            raise self.error(f"unknown flavor {flavor!r}, expected one of {', '.join(FLAVORS)}")
        return parse_label(parts[0]), flavor

    def parse_combo(self, cells: Sequence[str]) -> Combo:
        if len(cells) != 4 or cells[2] != "->":
            raise self.error("expected a combo of the form `KEY KEY -> RESULT`")
        names, idle, _ = self.combo_header
        a, b, result = (parse_label(cell) for cell in (cells[0], cells[1], cells[3]))
        return Combo(a, b, result, tuple(names), idle)

    def check(self) -> None:
        if not self.layers:
            raise self.error("no layers")
        names = [layer.name for layer in self.layers]
        if len(set(names)) != len(names):
            raise self.error("layer names must be unique")
        for combo in self.combos:
            for name in combo.layers:
                if name not in names:
                    self.line_number = self.combo_header[2]
                    raise self.error(f"unknown combo layer {name!r}")


def parse_keymap(text: str) -> tuple[list[Layer], list[Combo]]:
    return Parser().parse(text.splitlines())


# ── ZMK ──────────────────────────────────────────────────────────────────────


def key_code(label: str) -> str | None:
    """The &kp code a label presses, or None if it is not a key press."""
    if len(label) == 1 and label.isalpha():
        return label
    if len(label) == 1 and label.isdigit():
        return f"N{label}"
    if re.fullmatch(r"F([1-9]|1[0-9]|2[0-4])", label):
        return label
    if label.startswith("HYP_"):
        # Hyper: Ctrl+Alt+Shift+Super, free for window manager bindings.
        code = key_code(label.removeprefix("HYP_"))
        return f"LC(LA(LS(LG({code}))))" if code else None
    return KEY_CODES.get(label)


class Zmk:
    def __init__(self, layers: list[Layer]) -> None:
        self.layer_names = {layer.name.upper() for layer in layers}
        self.layer_mods = {layer.name.upper(): layer.modifier for layer in layers}

    def binding(self, label: str) -> str:
        if not label:
            return "&none"
        code = key_code(label)
        if code:
            return f"&kp {code}"
        if label in SPECIAL:
            return SPECIAL[label]
        if label in self.layer_names:
            return f"&mo {label}"
        if label.startswith("TO_") and label[3:] in self.layer_names:
            return f"&to {label[3:]}"
        raise KeyError(f"cannot map label {label!r} to ZMK")

    def key(self, key: Key, column: int) -> str:
        if not key.hold:
            return self.binding(key.tap)
        if not key.tap:
            return self.binding(key.hold)
        if key.tap == key.hold:
            # One-shot on tap, momentary on hold.
            if key.hold in self.layer_names:
                return f"&osl {key.hold} {key.hold}"
            if key.hold in MODIFIERS:
                return f"&osm {key.hold} {key.hold}"
            raise KeyError(f"{key.hold!r} cannot be one-shot")
        tap = key_code(key.tap)
        if tap is None:
            raise KeyError(f"{key.tap!r} cannot be tapped from a hold-tap")
        if key.hold in self.layer_names:
            if key.flavor:
                raise KeyError(f"layer hold {key.hold!r} takes no flavor")
            if self.layer_mods[key.hold]:
                return f"&lt_{key.hold.lower()} {key.hold} {tap}"
            return f"&lt {key.hold} {tap}"
        if key.hold not in MODIFIERS:
            raise KeyError(f"cannot hold {key.hold!r}")
        if key.flavor == "hm":
            side = "hml" if column < HALF else "hmr"
            return f"&{side} {key.hold} {tap}"
        return f"&mt {key.hold} {tap}"

    def layer(self, layer: Layer) -> str:
        cells = [
            [self.key(key, x if y < 3 else x + 2) for x, key in enumerate(row)]
            for y, row in enumerate(layer.rows)
        ]
        # Align columns; the thumbs sit under columns 2-7.
        grid = [row[:] for row in cells[:3]] + [["", "", *cells[3], "", ""]]
        widths = [max(len(row[x]) for row in grid) for x in range(10)]
        lines = []
        for row in grid:
            parts = [cell.ljust(width) for cell, width in zip(row, widths, strict=True)]
            left = " ".join(parts[:HALF])
            right = " ".join(parts[HALF:])
            lines.append(("   " + left + "    " + right).rstrip())
        body = "\n".join(lines)
        return (
            f"\t\t{layer.name}_layer {{\n"
            f'\t\t\tdisplay-name = "{layer.name.capitalize()}";\n'
            f"\t\t\tbindings = <\n{body}\n\t\t\t>;\n"
            "\t\t};"
        )

    def combos(self, layers: list[Layer], combos: list[Combo]) -> str:
        by_name = {layer.name: layer for layer in layers}
        nodes = []
        for i, combo in enumerate(combos):
            first = by_name[combo.layers[0]]
            positions = " ".join(str(find_position(first, label)) for label in (combo.a, combo.b))
            props = [
                "timeout-ms = <50>;",
                f"key-positions = <{positions}>;",
                f"bindings = <{self.binding(combo.result)}>;",
                f"layers = <{' '.join(name.upper() for name in combo.layers)}>;",
            ]
            if combo.idle_ms:
                props.append(f"require-prior-idle-ms = <{combo.idle_ms}>;")
            inner = "".join(f"\t\t\t{prop}\n" for prop in props)
            nodes.append(f"\t\tcombo_{i} {{\n{inner}\t\t}};")
        if not nodes:
            return ""
        return '\tcombos {\n\t\tcompatible = "zmk,combos";\n\n' + "\n\n".join(nodes) + "\n\t};"


def layer_mod_behaviors(layers: list[Layer]) -> str:
    """A layer-tap per `layer name + MOD`, holding MOD along with the layer.

    A hold-tap passes its hold behavior one parameter, so the modifier is
    fixed in a macro and the parameter is the layer.
    """
    nodes = []
    for layer in layers:
        if not layer.modifier:
            continue
        name, mod = layer.name.lower(), KEY_CODES[layer.modifier]
        nodes.append(
            f"\t\tlt_{name}: layer_tap_{name} {{\n"
            '\t\t\tcompatible = "zmk,behavior-hold-tap";\n'
            "\t\t\t#binding-cells = <2>;\n"
            '\t\t\tflavor = "tap-preferred";\n'
            "\t\t\ttapping-term-ms = <200>;\n"
            "\t\t\tquick-tap-ms = <175>;\n"
            f"\t\t\tbindings = <&mo_{name}>, <&kp>;\n"
            "\t\t};\n\n"
            f"\t\tmo_{name}: momentary_{name} {{\n"
            '\t\t\tcompatible = "zmk,behavior-macro-one-param";\n'
            "\t\t\t#binding-cells = <1>;\n"
            "\t\t\twait-ms = <0>;\n"
            "\t\t\ttap-ms = <0>;\n"
            "\t\t\tbindings\n"
            "\t\t\t\t= <&macro_param_1to1>\n"
            "\t\t\t\t, <&macro_press &mo MACRO_PLACEHOLDER>\n"
            f"\t\t\t\t, <&macro_press &kp {mod}>\n"
            "\t\t\t\t, <&macro_pause_for_release>\n"
            f"\t\t\t\t, <&macro_release &kp {mod}>\n"
            "\t\t\t\t, <&macro_param_1to1>\n"
            "\t\t\t\t, <&macro_release &mo MACRO_PLACEHOLDER>\n"
            "\t\t\t\t;\n"
            "\t\t};"
        )
    return "\n\n".join(nodes)


def find_position(layer: Layer, label: str) -> int:
    """ZMK key position of the only key on `layer` that taps `label`."""
    found = [
        y * 10 + x
        for y, row in enumerate(layer.rows)
        for x, key in enumerate(row)
        if key.tap == label
    ]
    if len(found) != 1:
        raise KeyError(f"{len(found)} keys on layer {layer.name} tap {label!r}, expected 1")
    return found[0]


def indent_block(text: str) -> str:
    """`text` as a block after a blank line, or nothing when it is empty."""
    return f"\n{text}\n" if text else ""


def generate_zmk(layers: list[Layer], combos: list[Combo], template: str) -> str:
    zmk = Zmk(layers)
    defines = "\n".join(f"#define {layer.name.upper():<5} {i}" for i, layer in enumerate(layers))
    text = (
        template.replace("#LAYER_DEFINES#", defines)
        .replace("#LAYER_MOD_BEHAVIORS#\n", indent_block(layer_mod_behaviors(layers)))
        .replace("#COMBOS#", zmk.combos(layers, combos))
        .replace("#LAYERS#", "\n\n".join(zmk.layer(layer) for layer in layers))
    )
    # The template's own header comment gives way to the generated one.
    text = text.split("\n", 2)[2]
    return "// Generated from keymap.txt by keymap/generate.py. Do not edit.\n\n" + text


# ── Entry point ──────────────────────────────────────────────────────────────


def outputs() -> dict[Path, str]:
    layers, combos = parse_keymap(KEYMAP_TXT.read_text(encoding="utf-8"))
    return {
        ZMK_OUT: generate_zmk(layers, combos, TEMPLATE.read_text(encoding="utf-8")),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--check", action="store_true", help="fail if outputs are stale")
    args = parser.parse_args(argv)
    try:
        files = outputs()
    except (ParseError, KeyError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    stale = []
    for path, text in files.items():
        current = path.read_text(encoding="utf-8") if path.exists() else None
        if current == text:
            continue
        if args.check:
            stale.append(path.relative_to(ROOT))
        else:
            path.write_text(text, encoding="utf-8")
            print(f"wrote {path.relative_to(ROOT)}")
    if stale:
        names = ", ".join(str(path) for path in stale)
        print(f"error: {names} out of date, run `just keymap`", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
