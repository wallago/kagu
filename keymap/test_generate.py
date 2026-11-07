"""Tests for keymap/generate.py. Run with `python3 -m unittest discover keymap`."""

from __future__ import annotations

import unittest

import generate
from generate import Key, ParseError, Zmk, parse_keymap

BLANK_ROWS = "  " + " ".join("_" * 10) + "\n"
EMPTY_ROWS = (BLANK_ROWS * 3) + "  _ _ _ _ _ _\n"


def grid(rows: list[str]) -> str:
    return "".join(f"  {row}\n" for row in rows)


BASE = grid(
    [
        "Q W F P B J L U Y '",
        "A R S T G M N E I O",
        "Z X C D V K H , . \\/",
        "ESC/nav SPC LSHFT/LSHFT RET/app BSPC nav/nav",
    ]
)


class ParserTest(unittest.TestCase):
    def test_overlay_fills_holds_and_drops_them(self) -> None:
        layers, _ = parse_keymap(
            "overlay mods\n"
            + grid(["_ _ _ _ _ _ _ _ _ _", "LGUI:hm _ _ _ _ _ _ _ _ RGUI:hm"])
            + BLANK_ROWS
            + "  _ _ _ _ _ _\n"
            + "layer base: mods\n"
            + grid(["Q W F P B J L U Y '", "A R S T G M N E I O/_"])
            + BLANK_ROWS
            + "  _ _ _ _ _ _\n"
        )
        row = layers[0].rows[1]
        self.assertEqual(row[0], Key("A", "LGUI", "hm"))
        self.assertEqual(row[9], Key("O", "", None))

    def test_escapes(self) -> None:
        top = grid(["\\/ \\: \\_ \\\\ _ _ _ _ _ _"])
        layers, _ = parse_keymap("layer base\n" + top + EMPTY_ROWS[len(BLANK_ROWS) :])
        self.assertEqual([key.tap for key in layers[0].rows[0][:4]], ["/", ":", "_", "\\"])

    def test_wrong_row_length_names_the_line(self) -> None:
        with self.assertRaisesRegex(ParseError, r"keymap.txt:2: row 0 of layer base has 3"):
            parse_keymap("layer base\n  Q W F\n")

    def test_layer_modifier_must_be_a_modifier(self) -> None:
        with self.assertRaisesRegex(ParseError, "expected a modifier"):
            parse_keymap("layer app + Q\n" + EMPTY_ROWS)

    def test_unknown_combo_layer(self) -> None:
        with self.assertRaisesRegex(ParseError, "unknown combo layer 'nope'"):
            parse_keymap("layer base\n" + EMPTY_ROWS + "combos: nope\n  Q W -> ESC\n")


class ZmkTest(unittest.TestCase):
    def setUp(self) -> None:
        self.layers, self.combos = parse_keymap(
            "layer base\n"
            + BASE
            + "layer nav\n"
            + EMPTY_ROWS
            + "layer app + LCTRL\n"
            + EMPTY_ROWS
            + "combos: base, app idle=100\n  W F -> ESC\n"
        )
        self.zmk = Zmk(self.layers)

    def bindings(self) -> list[str]:
        return [self.zmk.key(key, x) for x, key in enumerate(self.layers[0].rows[3])]

    def test_thumb_bindings(self) -> None:
        self.assertEqual(
            self.bindings(),
            [
                "&lt NAV ESC",
                "&kp SPACE",
                "&osm LSHFT LSHFT",
                "&lt_app APP RET",
                "&kp BSPC",
                "&osl NAV NAV",
            ],
        )

    def test_home_row_flavor_picks_the_side(self) -> None:
        self.assertEqual(self.zmk.key(Key("A", "LGUI", "hm"), 0), "&hml LGUI A")
        self.assertEqual(self.zmk.key(Key("O", "RGUI", "hm"), 9), "&hmr RGUI O")
        self.assertEqual(self.zmk.key(Key("A", "LGUI", None), 0), "&mt LGUI A")
        self.assertEqual(self.zmk.key(Key("", "LGUI", "hm"), 0), "&kp LGUI")

    def test_blank_and_transparent(self) -> None:
        self.assertEqual(self.zmk.binding(""), "&none")
        self.assertEqual(self.zmk.binding("TRNS"), "&trans")
        self.assertEqual(self.zmk.binding("TO_NAV"), "&to NAV")

    def test_unknown_label(self) -> None:
        with self.assertRaises(KeyError):
            self.zmk.binding("NOPE")

    def test_combo(self) -> None:
        text = self.zmk.combos(self.layers, self.combos)
        self.assertIn("key-positions = <1 2>;", text)
        self.assertIn("layers = <BASE APP>;", text)
        self.assertIn("require-prior-idle-ms = <100>;", text)

    def test_layer_modifier_macro(self) -> None:
        text = generate.layer_mod_behaviors(self.layers)
        self.assertIn("lt_app: layer_tap_app", text)
        self.assertIn("<&macro_press &kp LCTRL>", text)


class CommittedOutputTest(unittest.TestCase):
    def test_generated_files_are_up_to_date(self) -> None:
        for path, text in generate.outputs().items():
            self.assertEqual(path.read_text(encoding="utf-8"), text, f"{path} is stale")


if __name__ == "__main__":
    unittest.main()
