// Kagu top plate -- the switch plate and the short skirt that carries it, one
// part that sits on the bottom tray's border and closes the case.
//
// This file expects the geometry file and kagu_tray.scad to be included first:
// the plate reuses the tray's stack heights and its 2D profiles, so the skirt
// lands exactly on the border, cable swell included. See case/left_top.scad
// and case/right_top.scad.
//
// The same five M3 screws that hold the PCB now clamp plate, PCB and tray
// together: each runs through a spacer under the plate, then the PCB, into the
// tray's heat-set insert. The PCB mounting holes are DIN 965 footprints, so the
// plate is countersunk for flat-head screws that finish flush. M3 x 8 is right
// for the stack below; anything longer bottoms out in the insert hole.

// ---------------------------------------------------------------------------
// Vertical stack, on top of the tray's (which ends at the PCB top face).
// ---------------------------------------------------------------------------
pcb_to_plate = 2.2;   // PCB top -> plate underside, set by the Choc switch body
plate_t      = 1.3;   // Choc clips want 1.2-1.3mm

// ---------------------------------------------------------------------------
// Openings
// ---------------------------------------------------------------------------
switch_cut   = 13.8;  // Kailh Choc v1/v2 plate cutout
window_clear = 0.4;   // margin around tall components and the XIAO
reset_hole_d = 4.0;   // access to the reset button

// ---------------------------------------------------------------------------
// Fasteners -- countersunk M3 (DIN 965 / ISO 7046), 90 degree head.
// ---------------------------------------------------------------------------
spacer_d      = 6.0;  // sits on the 6mm mounting-hole pad, clear of the parts
screw_clear_d = 3.4;
csk_d         = 6.2;  // head diameter plus a little, so it lands flush

// Same web cleanup as the old one-piece case: the battery-LED connector lands
// 0.35mm from the SW16 cutout, leaving a sliver too thin to print. Opening the
// profile by min_web deletes any web thinner than 2*min_web and leaves the
// rest alone. Set to 0 to disable.
min_web = 0.3;

// ---------------------------------------------------------------------------
// Derived
// ---------------------------------------------------------------------------
plate_z = tray_h + pcb_to_plate;   // plate underside
top_h   = pcb_to_plate + plate_t;  // overall height of this part

echo(str("top: skirt ", pcb_to_plate, " + plate ", plate_t, " = ", top_h,
         "mm,  case ", tray_h + top_h, "mm tall assembled,  screws M3 x 8 csk"));

// ---------------------------------------------------------------------------
// 2D
// ---------------------------------------------------------------------------
module rect(r, c = 0) {
    translate([r[0] - c, r[1] - c])
        square([r[2] - r[0] + 2 * c, r[3] - r[1] + 2 * c]);
}

module plate_profile() {
    difference() {
        shell_2d();

        for (s = switches)
            translate([s[0], s[1]])
                rotate(s[2])
                    square(switch_cut, center = true);

        // The JST connectors stand well clear of the plate gap. The switch and
        // battery-LED ones are also where the ledge will be wired from.
        for (t = tall_parts) rect(t, window_clear);

        // Open bay over the XIAO: clears the module however deep it seats, and
        // lets its RGB status LED show.
        rect(xiao, window_clear);

        translate(reset) circle(d = reset_hole_d);
    }
}

// ---------------------------------------------------------------------------
// Assembly -- modelled in place on top of the tray; printed upside down.
// ---------------------------------------------------------------------------
module top_plate_in_place() {
    difference() {
        union() {
            // skirt, the same skin as the tray border
            translate([0, 0, tray_h])
                linear_extrude(pcb_to_plate)
                    difference() { shell_2d(); cavity_2d(); }
            translate([0, 0, plate_z])
                linear_extrude(plate_t)
                    if (min_web > 0) offset(r = min_web) offset(r = -min_web) plate_profile();
                    else plate_profile();
            // spacers that let the screws clamp the plate down onto the PCB
            for (p = screws)
                translate([p[0], p[1], tray_h])
                    cylinder(d = spacer_d, h = top_h);
        }
        for (p = screws)
            translate([p[0], p[1], 0]) {
                translate([0, 0, tray_h - eps])
                    cylinder(d = screw_clear_d, h = top_h + 2 * eps);
                // 90 degree countersink, flush with the plate top
                translate([0, 0, plate_z + plate_t - csk_d / 2 + eps])
                    cylinder(d1 = 0, d2 = csk_d, h = csk_d / 2);
            }
        // USB-C: the tray's notch, carried through the skirt and the plate.
        translate([0, 0, tray_h - eps])
            linear_extrude(top_h + 2 * eps) usb_slot_2d();
    }
}

// Plate face down on the bed: the visible surface comes off the build plate
// smooth, and the skirt and spacers print upward without supports.
module top_plate() {
    translate([0, 0, tray_h + top_h])
        rotate([180, 0, 0])
            top_plate_in_place();
}
