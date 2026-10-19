// Kagu case -- bottom tray + switch plate.
//
// This file expects a generated geometry file to be included first, which
// defines: outline, screws, switches, tall_parts, xiao, usb, reset,
// board_w, board_h.  See case/left.scad and case/right.scad.
//
// Select what to render with -D part="bottom" | "plate" | "preview".

part = "preview";

// ---------------------------------------------------------------------------
// Vertical stack, all measured from the outside face of the case floor.
// ---------------------------------------------------------------------------
floor_t      = 2.5;   // case floor thickness
standoff     = 4.0;   // floor top -> PCB underside; Choc hotswap sockets need 1.9
pcb_t        = 1.6;   // from the KiCad board stackup
pcb_to_plate = 2.2;   // PCB top -> plate underside, set by the Choc switch body
plate_t      = 1.3;   // printed PETG plate

// ---------------------------------------------------------------------------
// Shell
// ---------------------------------------------------------------------------
wall        = 3.0;    // outer wall thickness
pcb_clear   = 0.3;    // gap between PCB edge and cavity wall
rebate_w    = 1.2;    // width of the ledge the plate drops onto
plate_clear = 0.25;   // gap between plate edge and rebate wall

// ---------------------------------------------------------------------------
// Fasteners -- M3 brass heat-set inserts, screws down from the top.
// Insert dimensions vary a lot between suppliers: MEASURE YOURS and print a
// test coupon before committing a whole case.
// ---------------------------------------------------------------------------
boss_d        = 8.0;  // >= insert OD + 4mm so the boss has ~2mm of wall
insert_hole_d = 4.0;  // pilot hole for the insert
insert_depth  = 5.0;  // how deep the insert sits
screw_clear_d = 3.4;  // M3 clearance through the plate

// ---------------------------------------------------------------------------
// Openings
// ---------------------------------------------------------------------------
switch_cut   = 13.8;  // Kailh Choc v1/v2 plate cutout
window_clear = 0.4;   // margin around tall components
reset_hole_d = 4.0;   // access to the reset button
usb_clear    = 1.5;   // margin around the USB-C connector
usb_z0       = 4.5;   // bottom of the USB slot, from the case outside

// Some board features sit close enough to leave webs of plate too thin to
// print -- the battery-LED connector lands 0.35mm from the SW16 cutout. This
// opens the plate profile by min_web, which deletes any web thinner than
// 2*min_web (merging those openings) and leaves everything wider untouched.
// Side effect: internal corners pick up a min_web radius, which Choc switches
// tolerate happily. Set to 0 to disable.
min_web = 0.3;

// ---------------------------------------------------------------------------
// Battery bay -- retaining ribs on the cavity floor, under the PCB.
// Default is sized to the free area right of the last switch column; change
// it to match the cell you actually use.
// ---------------------------------------------------------------------------
battery      = true;
battery_pos  = [96, 26];
battery_size = [21, 30];
battery_rib  = 1.6;

$fn = 64;
eps = 0.01;

// ---------------------------------------------------------------------------
// Derived heights
// ---------------------------------------------------------------------------
pcb_z   = floor_t + standoff;      // PCB underside
pcb_top = pcb_z + pcb_t;
plate_z = pcb_top + pcb_to_plate;  // plate underside
case_h  = plate_z + plate_t;       // overall, plate flush with the wall top

// ---------------------------------------------------------------------------
// 2D profiles, all derived from the board outline
// ---------------------------------------------------------------------------
module profile(r) { offset(r = r) polygon(outline); }

module shell_2d()  { profile(pcb_clear + wall); }
module cavity_2d() { profile(pcb_clear); }
module rebate_2d() { profile(pcb_clear + rebate_w); }
module plate_2d()  { profile(pcb_clear + rebate_w - plate_clear); }

// ---------------------------------------------------------------------------
// Shared cutouts
// ---------------------------------------------------------------------------
module rect(r, c = 0) {
    translate([r[0] - c, r[1] - c])
        square([r[2] - r[0] + 2 * c, r[3] - r[1] + 2 * c]);
}

// USB-C exits through the far wall. The slot is deliberately generous: how
// high the connector sits depends on how deep the XIAO seats in its board
// cutout, which the PCB files do not pin down.
module usb_slot_2d() {
    translate([usb[0] - usb_clear, usb[1] - 2])
        square([usb[2] - usb[0] + 2 * usb_clear,
                board_h + wall + 4 - (usb[1] - 2)]);
}

// ---------------------------------------------------------------------------
// Bottom case
// ---------------------------------------------------------------------------
module bosses() {
    for (p = screws)
        translate([p[0], p[1], floor_t])
            cylinder(d = boss_d, h = standoff);
}

module insert_holes() {
    for (p = screws)
        translate([p[0], p[1], pcb_z - insert_depth])
            cylinder(d = insert_hole_d, h = insert_depth + eps);
}

module battery_ribs() {
    if (battery)
        linear_extrude(standoff - 0.2)
            difference() {
                offset(r = battery_rib)
                    translate(battery_pos) square(battery_size);
                translate(battery_pos) square(battery_size);
            }
}

module bottom_case() {
    difference() {
        union() {
            difference() {
                linear_extrude(case_h) shell_2d();
                // main cavity
                translate([0, 0, floor_t])
                    linear_extrude(case_h) cavity_2d();
                // pocket the plate drops into
                translate([0, 0, plate_z])
                    linear_extrude(case_h) rebate_2d();
            }
            bosses();
            battery_ribs();
        }
        insert_holes();
        // USB slot, from usb_z0 up to the plate underside
        translate([0, 0, usb_z0])
            linear_extrude(plate_z - usb_z0)
                usb_slot_2d();
    }
}

// ---------------------------------------------------------------------------
// Switch plate
// ---------------------------------------------------------------------------
module plate_profile() {
        difference() {
            plate_2d();

            for (s = switches)
                translate([s[0], s[1]])
                    rotate(s[2])
                        square(switch_cut, center = true);

            for (p = screws)
                translate([p[0], p[1]]) circle(d = screw_clear_d);

            // The JST connectors stand well clear of the 2.2mm plate gap.
            for (t = tall_parts) rect(t, window_clear);

            // Open bay over the XIAO: guarantees clearance regardless of how
            // deep the module seats, and lets its RGB status LED show.
            rect(xiao, window_clear);

            // Notch so the plate cannot foul the USB-C connector.
            usb_slot_2d();

            translate(reset) circle(d = reset_hole_d);
        }
}

module plate() {
    linear_extrude(plate_t)
        if (min_web > 0) offset(r = min_web) offset(r = -min_web) plate_profile();
        else plate_profile();
}

// ---------------------------------------------------------------------------
// Render
// ---------------------------------------------------------------------------
module pcb_stub() {
    color("#2d6a4f", 0.55)
        translate([0, 0, pcb_z])
            linear_extrude(pcb_t)
                difference() { polygon(outline); rect(xiao); }
}

if (part == "bottom") {
    bottom_case();
} else if (part == "plate") {
    plate();
} else {
    bottom_case();
    pcb_stub();
    color("#9aa5b1", 0.9) translate([0, 0, plate_z]) plate();
}
