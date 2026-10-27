// Choc v2 keycap riser -- a straight round post that plugs into a Kailh Choc
// v2 (PG1353) stem and carries a plain MX cross on top, so any MX or Choc v2
// keycap stands `height` higher.
//
// The post is the same diameter as the stem tube it lands on, so nothing
// overhangs: it prints socket down, straight up, with no supports, and never
// meets the switch housing at bottom-out.
//
// Select with -D height=5.

height = 5;           // rim seat to keycap seat

// ---------------------------------------------------------------------------
// Male stem -- same MX cross as choc_v2_tilter.scad, confirmed on real caps.
// ---------------------------------------------------------------------------
cap_cross_l = 4.10;   // arm length
cap_cross_w = 1.17;   // arm width
stem_h      = 3.60;   // male stem, standing off the post top
lead_in     = 0.10;   // chamfer on the socket mouth and on the stem tip

// ---------------------------------------------------------------------------
// Switch side -- same socket as choc_v2_tilter.scad; see the datasheet notes
// there. The boss drops into the annular slot of the v2 stem tube and the
// post underside lands on the ø6.50 tube rim.
// ---------------------------------------------------------------------------
stem_bore  = 5.50;    // bore the boss drops into
stem_od    = 6.50;    // tube outside diameter -- also the post diameter
cross_l    = 4.00;    // cross arm span      (datasheet 2-4.00 +/-0.05)
cross_w    = 1.30;    // cross arm width     (datasheet 2-1.30 +/-0.03)

boss_h     = 2.50;    // how far the boss reaches into the slot (3.52 available)
boss_fit   = 0.20;    // boss diameter under the bore
socket_fit = 0.15;    // added to both cross dimensions of the hole
cross_over = 0.20;    // hole past the shoulder, so the rim seats before the cross

$fn = 64;
eps = 0.01;

// ---------------------------------------------------------------------------
// Derived
// ---------------------------------------------------------------------------
boss_d   = stem_bore - boss_fit;
hole_l   = cross_l + socket_fit;
hole_w   = cross_w + socket_fit;
hole_top = boss_h + cross_over;

assert(height >= cross_over + 1, "post too short to roof the cross hole");

// ---------------------------------------------------------------------------
// Parts
// ---------------------------------------------------------------------------
module cross_2d(l, w) {
    square([l, w], center = true);
    square([w, l], center = true);
}

module bar_mouth(l, w) {
    hull() {
        translate([0, 0, -eps]) linear_extrude(eps)
            square([l + 2 * lead_in, w + 2 * lead_in], center = true);
        translate([0, 0, lead_in]) linear_extrude(eps) square([l, w], center = true);
    }
}

module bar_tip(l, w) {
    hull() {
        linear_extrude(stem_h - lead_in) square([l, w], center = true);
        translate([0, 0, stem_h - eps]) linear_extrude(eps)
            square([l - 2 * lead_in, w - 2 * lead_in], center = true);
    }
}

// Boss that drops into the annular slot, then the post standing on the rim.
module body() {
    cylinder(d1 = boss_d - 2 * lead_in, d2 = boss_d, h = lead_in);
    translate([0, 0, lead_in]) cylinder(d = boss_d, h = boss_h - lead_in + eps);
    translate([0, 0, boss_h]) cylinder(d = stem_od, h = height);
}

module cross_hole() {
    translate([0, 0, -eps]) linear_extrude(hole_top + eps) cross_2d(hole_l, hole_w);
    bar_mouth(hole_l, hole_w);
    rotate([0, 0, 90]) bar_mouth(hole_l, hole_w);
}

module stem() {
    bar_tip(cap_cross_l, cap_cross_w);
    rotate([0, 0, 90]) bar_tip(cap_cross_l, cap_cross_w);
}

// ---------------------------------------------------------------------------
// Assembly -- socket mouth down on the bed.
// ---------------------------------------------------------------------------
difference() {
    union() {
        body();
        translate([0, 0, boss_h + height]) stem();
    }
    cross_hole();
}
