#!/usr/bin/env python3
"""Derive case geometry from the KiCad PCBs.

Reads pcb/kagu-{left,right}/kagu.kicad_pcb and writes case/kagu_{side}_geom.scad.
Everything the case needs is taken from the board, so the case stays in sync
with the PCB instead of repeating its dimensions by hand.

KiCad has +Y pointing down; OpenSCAD has +Y up. Points are emitted as
    x' = x - min_x
    y' = max_y - y
which flips Y and puts the board's bounding box at the origin. That flip also
mirrors footprint rotations, so emitted angles are negated.
"""

import math
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def sexp_blocks(src, pattern):
    """Yield (match, text) for each top-level s-expression matching pattern."""
    for m in re.finditer(pattern, src):
        i = m.start()
        depth = 0
        j = i
        while j < len(src):
            if src[j] == "(":
                depth += 1
            elif src[j] == ")":
                depth -= 1
                if depth == 0:
                    break
            j += 1
        yield m, src[i : j + 1]


def xf(px, py, rot_deg):
    """KiCad footprint-local -> board coordinates."""
    th = math.radians(rot_deg)
    c, s = math.cos(th), math.sin(th)
    return lambda lx, ly: (px + lx * c + ly * s, py - lx * s + ly * c)


def edge_segments(src):
    """All Edge.Cuts line segments, including those inside footprints."""
    segs = []
    for _, blk in sexp_blocks(src, r"\n\t\(gr_line\b"):
        if '(layer "Edge.Cuts")' in blk:
            a = re.search(r"\(start ([-\d.]+) ([-\d.]+)\)", blk)
            b = re.search(r"\(end ([-\d.]+) ([-\d.]+)\)", blk)
            segs.append(
                ((float(a.group(1)), float(a.group(2))), (float(b.group(1)), float(b.group(2))))
            )
    return segs


def chain(segs, tol=1e-3):
    """Order unordered segments into a closed ring of points."""
    remaining = list(segs)
    ring = list(remaining.pop(0))
    while remaining:
        cur = ring[-1]
        for i, (a, b) in enumerate(remaining):
            if math.dist(cur, a) < tol:
                ring.append(b)
                remaining.pop(i)
                break
            if math.dist(cur, b) < tol:
                ring.append(a)
                remaining.pop(i)
                break
        else:
            raise SystemExit(f"outline is not continuous at {cur}")
    if math.dist(ring[0], ring[-1]) < tol:
        ring.pop()
    return ring


def footprints(src):
    for m, blk in sexp_blocks(src, r"\n\t\(footprint "):
        ref = re.search(r'\(property "Reference" "([^"]+)"', blk)
        at = re.search(r"^\t\t\(at ([-\d.]+) ([-\d.]+)(?: ([-\d.]+))?\)", blk, re.M)
        if not ref or not at:
            continue
        yield {
            "ref": ref.group(1),
            "lib": re.search(r'\(footprint "([^"]+)"', blk).group(1),
            "x": float(at.group(1)),
            "y": float(at.group(2)),
            "rot": float(at.group(3) or 0),
            "blk": blk,
        }


def body_bbox(fp, layer="F.Fab"):
    """Global bounding box of a footprint's body outline.

    F.Fab is the real component body; F.CrtYd adds a keep-out margin that is
    far larger than the part and would collide with neighbouring switches.
    """
    t = xf(fp["x"], fp["y"], fp["rot"])
    pts = []
    for _, b in sexp_blocks(fp["blk"], r"\(fp_(?:line|rect|poly|circle|arc)\b"):
        if f'(layer "{layer}")' not in b:
            continue
        for a, c in re.findall(r"\((?:start|end|center|mid|xy) ([-\d.]+) ([-\d.]+)\)", b):
            pts.append(t(float(a), float(c)))
    if not pts:
        return None
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    return min(xs), min(ys), max(xs), max(ys)


def extract(side):
    src = (ROOT / "pcb" / f"kagu-{side}" / "kagu.kicad_pcb").read_text()
    ring = chain(edge_segments(src))

    min_x = min(p[0] for p in ring)
    max_y = max(p[1] for p in ring)

    def P(x, y):
        return (round(x - min_x, 4), round(max_y - y, 4))

    fps = list(footprints(src))
    holes, switches, tall, xiao, reset = [], [], [], None, None

    for fp in fps:
        ref, lib = fp["ref"], fp["lib"]
        if "MountingHole" in lib:
            holes.append(P(fp["x"], fp["y"]))
        elif re.match(r"^SW([1-9]|1[0-8])$", ref):
            switches.append((*P(fp["x"], fp["y"]), round(-fp["rot"], 3)))
        elif ref == "U1":
            bb = [b for _, b in sexp_blocks(fp["blk"], r"\(fp_(?:line|arc)\b")
                  if '(layer "Edge.Cuts")' in b]
            t = xf(fp["x"], fp["y"], fp["rot"])
            pts = []
            for b in bb:
                for a, c in re.findall(r"\((?:start|end) ([-\d.]+) ([-\d.]+)\)", b):
                    pts.append(t(float(a), float(c)))
            xs, ys = [p[0] for p in pts], [p[1] for p in pts]
            lo, hi = P(min(xs), max(ys)), P(max(xs), min(ys))
            xiao = (lo[0], lo[1], hi[0], hi[1])

        # The reset button is short enough to clear the plate; it only needs
        # a finger/tool access hole, not a window.
        if ref == "SW19":
            reset = P(fp["x"], fp["y"])

        # Connectors stand taller than the plate gap and need real windows.
        if ref in ("Bat_Con1", "Switch_Con1", "Bat_LED_Con1"):
            bb = body_bbox(fp) or body_bbox(fp, "F.CrtYd")
            if bb:
                lo, hi = P(bb[0], bb[3]), P(bb[2], bb[1])
                tall.append((ref, lo[0], lo[1], hi[0], hi[1]))

    # USB-C: the connector outline lives on User.1 in the XIAO footprint.
    usb = None
    for fp in fps:
        if fp["ref"] != "U1":
            continue
        t = xf(fp["x"], fp["y"], fp["rot"])
        pts = []
        for _, b in sexp_blocks(fp["blk"], r"\(fp_line\b"):
            if '(layer "User.1")' not in b:
                continue
            for a, c in re.findall(r"\((?:start|end) ([-\d.]+) ([-\d.]+)\)", b):
                pts.append(t(float(a), float(c)))
        if pts:
            xs, ys = [p[0] for p in pts], [p[1] for p in pts]
            lo, hi = P(min(xs), max(ys)), P(max(xs), min(ys))
            usb = (lo[0], lo[1], hi[0], hi[1])

    return dict(ring=[P(*p) for p in ring], holes=holes, switches=switches,
                tall=tall, xiao=xiao, usb=usb, reset=reset,
                w=round(max(p[0] for p in ring) - min_x, 4),
                h=round(max_y - min(p[1] for p in ring), 4))


def fmt_pts(pts):
    return "[ " + ", ".join(f"[{x:.4g}, {y:.4g}]" for x, y in pts) + " ]"


def write(side, g):
    out = ROOT / "case" / f"kagu_{side}_geom.scad"
    L = [
        "// GENERATED by case/extract_geometry.py -- do not edit.",
        f"// Source: pcb/kagu-{side}/kagu.kicad_pcb",
        "",
        f"board_w = {g['w']:.4g};",
        f"board_h = {g['h']:.4g};",
        "",
        "// Board outline, counter-clockwise, origin at bounding-box corner.",
        f"outline = {fmt_pts(g['ring'])};",
        "",
        "// M3 mounting holes.",
        f"screws = {fmt_pts(g['holes'])};",
        "",
        "// Switch centres as [x, y, rotation].",
        "switches = [ "
        + ", ".join(f"[{x:.4g}, {y:.4g}, {r:.4g}]" for x, y, r in g["switches"])
        + " ];",
        "",
        "// Components taller than the plate gap: [x0, y0, x1, y1].",
        "tall_parts = [",
    ]
    for ref, x0, y0, x1, y1 in g["tall"]:
        L.append(f"    [{x0:.4g}, {y0:.4g}, {x1:.4g}, {y1:.4g}],  // {ref}")
    L += [
        "];",
        "",
        "// XIAO board cutout [x0, y0, x1, y1].",
        f"xiao = [{g['xiao'][0]:.4g}, {g['xiao'][1]:.4g}, {g['xiao'][2]:.4g}, {g['xiao'][3]:.4g}];",
        "",
        "// USB-C connector envelope [x0, y0, x1, y1].",
        f"usb = [{g['usb'][0]:.4g}, {g['usb'][1]:.4g}, {g['usb'][2]:.4g}, {g['usb'][3]:.4g}];",
        "",
        "// Reset button centre.",
        f"reset = [{g['reset'][0]:.4g}, {g['reset'][1]:.4g}];",
        "",
    ]
    out.write_text("\n".join(L))
    return out


if __name__ == "__main__":
    for side in ("left", "right"):
        g = extract(side)
        p = write(side, g)
        print(f"{p.name}: {g['w']:.2f} x {g['h']:.2f} mm, {len(g['ring'])} outline pts, "
              f"{len(g['holes'])} screws, {len(g['switches'])} switches, "
              f"{len(g['tall'])} tall parts")
