// Kagu trackpad -- a bay for an Azoteq TPS43-201A-S on the right half.
//
// The module (40 x 43mm) does not fit on the board: below the XIAO there is
// only ~31mm between the board edge and the first key column, a thumb key
// cuts into the corner, and the M3 screw at [5, 35.5] would sit under the
// pad. So the case grows a wing on the inner edge (-x, toward the other half)
// and the pad lives entirely there, clear of the PCB.
//
// The top plate is the overlay. Over the pad it is thinned from below to
// tp_overlay, inside Azoteq's 0.2-1.2mm range for the stock firmware, and the
// module's own 3M 468MP adhesive sticks it to the underside of that skin. The
// plate prints face down, so the touch surface comes off the bed with the
// sheet's texture. A shallow groove on the face outlines the pad.
//
// Four posts rise from the tray floor to just under the module's corners so a
// hard press is carried by the floor rather than by the thin skin. CHECK the
// back of your module: if a part sits in a corner, set tp_posts = false.
//
// Included by kagu_tray.scad; only modules and defaults here. Entry files
// turn it on with `trackpad = true;` after the includes.

trackpad = false;

tp_size    = [40, 43];   // module outline (x, y), as measured
tp_centre  = [-23, 41];  // right-board coordinates: off the inner edge,
                         // level with the screw at [5, 35.5] and the XIAO
tp_fit     = 0.2;        // clearance per side round the module
tp_overlay = 0.8;        // plate skin over the module
tp_margin  = 1.5;        // cavity beyond the pocket, before the wall
tp_module_t = 1.0;       // module PCB thickness, under the adhesive -- MEASURE
tp_post_gap = 0.3;       // posts stop this far under the module
tp_post_d   = 3.0;
tp_post_in  = 2.5;       // post centre, in from each module corner
tp_posts    = true;

tp_groove_w = 0.6;       // outline on the face
tp_groove_h = 0.4;

// The wing is hulled to the strip of board beside it (left of the first key
// column, same height as the pad), so it meets the case in one smooth line
// and fills the angle under the diagonal edge.
tp_join_x = 12;

module tp_rect(grow = 0) {
    translate(tp_centre - tp_size / 2 - [grow, grow])
        square(tp_size + 2 * [grow, grow]);
}

// Added to the tray cavity; the wall, skirt and plate follow from it.
module trackpad_cavity_2d() {
    hull() {
        offset(r = tp_margin) tp_rect(tp_fit);
        intersection() {
            profile(pcb_clear);
            translate([-big, tp_centre[1] - tp_size[1] / 2 - tp_fit - tp_margin])
                square([big + tp_join_x, tp_size[1] + 2 * (tp_fit + tp_margin)]);
        }
    }
}

// Pocket under the plate: the module drops in from below and sticks to the skin.
module trackpad_pocket(plate_top) {
    translate([0, 0, plate_top - big - tp_overlay])
        linear_extrude(big) tp_rect(tp_fit);
    translate([0, 0, plate_top - tp_groove_h])
        linear_extrude(tp_groove_h + eps)
            difference() {
                tp_rect(tp_fit + 0.5 + tp_groove_w);
                tp_rect(tp_fit + 0.5);
            }
}

// Corner posts on the tray floor, top at the module underside minus a gap.
module trackpad_posts(plate_top) {
    h = plate_top - tp_overlay - tp_module_t - tp_post_gap - floor_t;
    if (tp_posts)
        for (sx = [-1, 1], sy = [-1, 1])
            translate([tp_centre[0] + sx * (tp_size[0] / 2 - tp_post_in),
                       tp_centre[1] + sy * (tp_size[1] / 2 - tp_post_in),
                       floor_t - eps])
                cylinder(d = tp_post_d, h = h + eps);
}
