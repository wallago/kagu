// Kagu bottom tray -- floor, border, and the M3 bosses the PCB screws down to.
//
// This file expects a generated geometry file to be included first, which
// defines: outline, screws, xiao, usb, board_w, board_h.  See case/left_tray.scad
// and case/right_tray.scad.
//
// No plate rebate, no reset hole. The border stops flush with the top face
// of the PCB, and kagu_top.scad sits on it.
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

// ---------------------------------------------------------------------------
// Mount -- a 1/4"-20 hex nut trapped in a boss on the floor, for a magic arm
// or tripod screw coming up from underneath. The nut drops in from above
// before the PCB goes on; tightening the screw pulls it down onto the plastic
// under it, so nothing but the floor takes the load.
//
// Placed at the balance point: the mass centroid of tray, plate, PCB, 18
// switches + caps, battery and XIAO lands near [66, 50] and the key centroid
// near [56, 51]; the mount sits between the two so the half neither tips under
// its own weight nor under a hand resting on the keys. Left-half coordinates,
// mirrored for the right half. Clear of the battery, the XIAO and the bosses;
// the boss top stays ~1.3mm under the hotswap sockets. A screw that
// stands more than 9mm proud of the arm can reach the sockets.
// ---------------------------------------------------------------------------
mount_pos    = [60, 51];
mount_hole_d = 6.6;          // 1/4" = 6.35mm
nut_af       = 11.11 + 0.3;  // 7/16" across flats, plus fit
nut_h        = 5.56 + 0.2;   // 7/32"
nut_floor    = 2.0;          // plastic under the nut
mount_wall   = 2.4;

$fn = 64;
eps = 0.01;
big = 500;

// ---------------------------------------------------------------------------
// Derived
// ---------------------------------------------------------------------------
pcb_z      = floor_t + standoff;  // PCB underside
tray_h     = pcb_z + pcb_t;       // border top, flush with the PCB top face
chip_right = (xiao[0] + xiao[2]) / 2 > board_w / 2;
mount_xy   = chip_right ? mount_pos : [board_w - mount_pos[0], mount_pos[1]];
nut_d      = nut_af / cos(30);           // across corners
mount_top  = nut_floor + nut_h;          // boss top, from the outside face

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
// Mount
// ---------------------------------------------------------------------------
module mount_boss() {
    translate(mount_xy)
        cylinder(d = nut_d + 2 * mount_wall, h = mount_top);
}

module mount_cut() {
    translate(mount_xy) {
        translate([0, 0, -eps])
            cylinder(d = mount_hole_d, h = mount_top + 2 * eps);
        translate([0, 0, nut_floor])
            cylinder(d = nut_d, h = nut_h + eps, $fn = 6);
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
            mount_boss();
        }
        insert_holes();
        mount_cut();
        // Border only -- the floor stays continuous under the connector.
        translate([0, 0, floor_t])
            linear_extrude(tray_h - floor_t + eps) usb_slot_2d();
    }
}
