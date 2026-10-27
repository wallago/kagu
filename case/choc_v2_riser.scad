// Choc v2 keycap riser -- a straight round post that plugs into a Kailh Choc
// v2 (PG1353) stem and carries a plain MX cross on top, so any MX or Choc v2
// keycap stands `height` higher, optionally leaned over by `tilt` degrees
// toward the compass direction `azimuth`.
//
// The post is the same diameter as the stem tube it lands on, so nothing
// overhangs: it prints socket down, straight up, with no supports, and never
// meets the switch housing at bottom-out. A tilted top only leans the stem,
// which prints fine up to the usual 45 degrees.
//
// As with the tilter, the cross only engages every 90 degrees: azimuth=0
// covers the four square leans, azimuth=45 the four diagonal ones.
//
// Select with -D height=1.5 -D tilt=15 -D azimuth=45.

height  = 5;          // rim seat to keycap seat, at the centre
tilt    = 0;          // degrees of lean; 0 leaves a straight riser
azimuth = 0;          // which way it leans, degrees CCW from +x

// ---------------------------------------------------------------------------
// Male stem -- the tilter's MX cross, thickened a touch for a snugger cap.
// ---------------------------------------------------------------------------
cap_cross_l = 4.10;   // arm length
cap_cross_w = 1.17;   // arm width
cap_fit     = 0.05;   // added to both: printed caps were a touch loose
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
boss_fit   = 0.10;    // boss diameter under the bore
socket_fit = 0.05;    // added to both cross dimensions of the hole -- the
                      // tilter's 0.15 let a printed riser lift off freely
cross_over = 0.10;    // hole past the shoulder, so the rim seats before the cross
web        = 0.40;    // roof over the cross hole: two 0.2 layers

$fn = 64;
eps = 0.01;
big = 100;

// ---------------------------------------------------------------------------
// Derived
// ---------------------------------------------------------------------------
boss_d   = stem_bore - boss_fit;
hole_l   = cross_l + socket_fit;
hole_w   = cross_w + socket_fit;
hole_top = boss_h + cross_over;
stem_l   = cap_cross_l + cap_fit;
stem_w   = cap_cross_w + cap_fit;

// The tilted top drops fastest at the post edge; keep `web` over the hole.
low_z = height - stem_od / 2 * tan(tilt);
assert(low_z >= cross_over + web, "post too short for this tilt");

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

// Tip +z over toward `azimuth`, by turning about the horizontal axis square to
// it. The socket below stays put -- it has to stay square to the switch.
module lean() {
    rotate(a = tilt, v = [-sin(azimuth), cos(azimuth), 0]) children();
}

// Boss that drops into the annular slot, then the post standing on the rim,
// cut off by the (possibly tilted) top.
module body() {
    cylinder(d1 = boss_d - 2 * lead_in, d2 = boss_d, h = lead_in);
    translate([0, 0, lead_in]) cylinder(d = boss_d, h = boss_h - lead_in + eps);
    intersection() {
        translate([0, 0, boss_h]) cylinder(d = stem_od, h = big);
        translate([0, 0, boss_h + height]) lean()
            translate([0, 0, -big / 2]) cube(big, center = true);
    }
}

module cross_hole() {
    translate([0, 0, -eps]) linear_extrude(hole_top + eps) cross_2d(hole_l, hole_w);
    bar_mouth(hole_l, hole_w);
    rotate([0, 0, 90]) bar_mouth(hole_l, hole_w);
}

// Sunk below the face by the drop under its arms, so a tilted stem has no
// gap at its low side.
module stem() {
    sink = stem_l / 2 * tan(tilt) + eps;
    bar_tip(stem_l, stem_w);
    rotate([0, 0, 90]) bar_tip(stem_l, stem_w);
    translate([0, 0, -sink]) linear_extrude(sink + eps) cross_2d(stem_l, stem_w);
}

// ---------------------------------------------------------------------------
// Assembly -- socket mouth down on the bed.
// ---------------------------------------------------------------------------
difference() {
    union() {
        body();
        translate([0, 0, boss_h + height]) lean() stem();
    }
    cross_hole();
}
