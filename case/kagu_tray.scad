// Kagu bottom tray -- floor, border, and the M3 bosses the PCB screws down to.
//
// This file expects a generated geometry file to be included first, which
// defines: outline, screws, xiao, usb, board_w, board_h.  See case/left_tray.scad
// and case/right_tray.scad.
//
// Not the case in kagu_case.scad: no plate rebate, no reset hole, nothing for
// a top part yet. The border stops flush with the top face of the PCB.
//
// Why one design covers both halves:
//
// The right PCB carries its XIAO on B.Cu (U1 really is on the back layer), so
// on that half the module and its USB-C connector hang ~4.5mm BELOW the board
// while on the left half they stand above it. Two things follow. `standoff` is
// set far taller than the board underside strictly needs, so the flipped
// module has somewhere to go; and the USB notch is cut through the WHOLE
// height of the border, so the connector passes whether it sits above the
// board or below it. That is what leaves the two halves exact mirrors of each
// other -- the outlines and screw positions already are.

// ---------------------------------------------------------------------------
// Vertical stack, measured from the outside face of the floor.
// ---------------------------------------------------------------------------
floor_t  = 3.0;   // floor thickness
standoff = 8.0;   // floor top -> PCB underside. Has to clear the flipped
                  // XIAO + USB-C on the right half (~4.5mm) as well as the
                  // Choc hotswap sockets on the board underside (1.9mm).
pcb_t    = 1.6;   // from the KiCad board stackup

// ---------------------------------------------------------------------------
// Border -- runs all the way round, flush with the top face of the PCB.
// ---------------------------------------------------------------------------
wall      = 3.0;  // border thickness
pcb_clear = 0.3;  // gap between PCB edge and the border, everywhere but...

// ...the chip side, where the border bows outward so the battery leads can run
// down past the board edge to the cell below. Full depth of the cavity, so
// 0.5mm leads drop straight in. Which side it is on comes from where the XIAO
// sits, so it follows the board rather than being named per half.
cable_gap = 2.0;  // deepest point of the bow, measured from the board edge

// ---------------------------------------------------------------------------
// USB-C -- deliberately generous. How high the connector ends up depends on
// how deep the XIAO seats in its board cutout, which the PCB files do not pin
// down, and on which face the module was soldered to.
// ---------------------------------------------------------------------------
usb_clear = 1.5;  // margin either side of the connector

// ---------------------------------------------------------------------------
// Fasteners -- M3 brass heat-set inserts, screws down through the PCB.
// Insert dimensions vary a lot between suppliers: MEASURE YOURS and print a
// test coupon before committing a whole tray.
// ---------------------------------------------------------------------------
boss_d        = 8.0;  // >= insert OD + 4mm so the boss has ~2mm of wall
insert_od     = 4.5;  // knurl outside diameter
insert_hole_d = 4.0;  // pilot hole for the insert
insert_depth  = 5.0;  // insert length
insert_melt   = 1.0;  // extra hole depth below the insert for the melt it pushes down

// Pressing the insert in raises a lip of plastic round the hole. A shallow
// counterbore at the top of the boss gives that lip somewhere to go below the
// PCB seat, so the board still lands on the boss face. Press the insert in
// until it is flush with the counterbore floor, not with the boss top.
insert_relief_d = insert_od + 1.0;
insert_relief_h = 0.6;

$fn = 64;
eps = 0.01;
big = 500;

// ---------------------------------------------------------------------------
// Derived
// ---------------------------------------------------------------------------
pcb_z      = floor_t + standoff;  // PCB underside
tray_h     = pcb_z + pcb_t;       // border top, flush with the PCB top face
chip_right = (xiao[0] + xiao[2]) / 2 > board_w / 2;

// The chip-side board edge: the run of outline the cable bow is struck across.
inner_x  = chip_right ? board_w : 0;
inner_ys = [for (p = outline) if (abs(p[0] - inner_x) < eps) p[1]];
inner_y0 = min(inner_ys);
inner_y1 = max(inner_ys);
inner_dir = chip_right ? 1 : -1;   // which way is outboard

// The bow: a circular arc on the chord between the two ends of that edge,
// standing cable_bow proud of the cavity wall at its deepest.
cable_bow = cable_gap - pcb_clear;
bow_span  = inner_y1 - inner_y0;
bow_r     = (bow_span * bow_span / 4 + cable_bow * cable_bow) / (2 * cable_bow);

echo(str("tray: chip on the ", chip_right ? "+x" : "-x", " board edge,  floor ",
         floor_t, " + standoff ", standoff, " + pcb ", pcb_t, " = ", tray_h,
         "mm tall,  cable bow ", cable_gap, " x ", standoff, "mm over y ",
         inner_y0, "..", inner_y1, " (r=", round(bow_r), ")"));

// ---------------------------------------------------------------------------
// 2D profiles, all derived from the board outline
// ---------------------------------------------------------------------------
module profile(r) { offset(r = r) polygon(outline); }

// The bow that carries the battery leads, as a circular segment on the chord
// between the two ends of the chip-side edge. A straight taper, or worse a
// square pad, meets the cavity wall at an angle, and that corner survives into
// the outer silhouette as a visible joint -- the border reads as something
// glued on. An arc struck corner to corner has no joint along the edge at all,
// and the only break left, 8 degrees where it meets each board corner, is
// swallowed by the fillet the border offset puts on that corner anyway.
module cable_relief_2d() {
    centre = inner_x + inner_dir * (cable_gap - bow_r);
    intersection() {
        translate([centre, (inner_y0 + inner_y1) / 2])
            circle(r = bow_r, $fn = 720);
        // Just the segment standing proud of the cavity wall.
        translate([inner_x + inner_dir * pcb_clear - (chip_right ? 0 : big), -big])
            square([big, 3 * big]);
    }
}

module cavity_2d() {
    profile(pcb_clear);
    cable_relief_2d();
}

// Grown from the cavity rather than from the outline a second time, so the
// border is one uniform skin: its thickness is wall everywhere by construction,
// including across the cable swell, and it follows the swell as a single
// continuous line.
module shell_2d() { offset(r = wall) cavity_2d(); }

// USB-C exits through the far wall. Cut over the full border height: on the
// left half the connector sits above the PCB, on the right half below it.
module usb_slot_2d() {
    translate([usb[0] - usb_clear, usb[1] - 2])
        square([usb[2] - usb[0] + 2 * usb_clear,
                board_h + wall + 4 - (usb[1] - 2)]);
}

// ---------------------------------------------------------------------------
// Bosses
// ---------------------------------------------------------------------------
module bosses() {
    for (p = screws)
        translate([p[0], p[1], floor_t])
            cylinder(d = boss_d, h = standoff);
}

module insert_holes() {
    hole_h = insert_relief_h + insert_depth + insert_melt;
    for (p = screws) {
        translate([p[0], p[1], pcb_z - hole_h])
            cylinder(d = insert_hole_d, h = hole_h + eps);
        translate([p[0], p[1], pcb_z - insert_relief_h])
            cylinder(d = insert_relief_d, h = insert_relief_h + eps);
    }
}

// ---------------------------------------------------------------------------
// Assembly -- floor flat on the bed, border up.
// ---------------------------------------------------------------------------
module bottom_tray() {
    difference() {
        union() {
            difference() {
                linear_extrude(tray_h) shell_2d();
                translate([0, 0, floor_t])
                    linear_extrude(tray_h) cavity_2d();
            }
            bosses();
        }
        insert_holes();
        // Border only -- the floor stays continuous under the connector.
        translate([0, 0, floor_t])
            linear_extrude(tray_h - floor_t + eps) usb_slot_2d();
    }
}

bottom_tray();
