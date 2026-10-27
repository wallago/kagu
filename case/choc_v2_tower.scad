// Choc v2 tower keycap -- a tall rounded block that sits straight on a Kailh
// Choc v2 (PG1353) stem, no MX adapter in between. The top face can be
// angled by `tilt` degrees, sloping down toward the compass direction
// `azimuth`, so a tower can face the finger that presses it.
//
// Printed top face down on the bed: the face comes out flat and smooth, the
// edge chamfer is a 45 degree slope, the sides lean at most `tilt` from
// vertical and the socket points straight up. Nothing needs supports.
//
// As with the tilter, the cross only engages every 90 degrees, so the slope
// direction is built into the part:
//
//   azimuth=0   turned 0/90/180/270 on the switch -> the four square slopes
//   azimuth=45  turned 0/90/180/270 on the switch -> the four diagonal slopes
//
// Select with -D height=11 -D tilt=15 -D azimuth=45.

height  = 10;         // top face height at the centre, above the rim seat
tilt    = 0;          // degrees the top face slopes; 0 leaves it flat
azimuth = 0;          // which way it slopes down, degrees CCW from +x
print   = true;       // true: top face down on the bed; false: as fitted

// ---------------------------------------------------------------------------
// Body -- Kagu's switches sit on an 18 x 17 grid, so 13 leaves a 4 mm gap to
// the next row, wide enough to feel each tower on its own.
// ---------------------------------------------------------------------------
size    = 13;         // square footprint
size_r  = 2.5;        // corner radius of the footprint
chamfer = 0.8;        // 45 degree chamfer round the top face

// ---------------------------------------------------------------------------
// Switch side -- same socket as choc_v2_tilter.scad; see the datasheet notes
// there. The boss drops into the annular slot of the v2 stem tube and the
// body underside lands on the tube rim.
// ---------------------------------------------------------------------------
stem_bore  = 5.50;    // bore the boss drops into
cross_l    = 4.00;    // cross arm span      (datasheet 2-4.00 +/-0.05)
cross_w    = 1.30;    // cross arm width     (datasheet 2-1.30 +/-0.03)

boss_h     = 2.50;    // how far the boss reaches into the slot (3.52 available)
boss_fit   = 0.20;    // boss diameter under the bore
socket_fit = 0.15;    // added to both cross dimensions of the hole
cross_over = 0.20;    // hole past the shoulder, so the rim seats before the cross
lead_in    = 0.10;    // chamfer on the socket mouth and on the boss tip

// The rim seat leaves 0.10 above the housing at bottom-out. The tilter's
// body never left the stem; this one covers most of the housing, so outside
// a ring round the stem the underside steps up by `relief` for margin.
seat_d     = 7.40;    // flat ring that lands on the ø6.50 rim
relief     = 0.50;    // underside step outside the seat

$fn = 64;
eps = 0.01;
big = 100;

// ---------------------------------------------------------------------------
// Derived
// ---------------------------------------------------------------------------
boss_d   = stem_bore - boss_fit;
hole_l   = cross_l + socket_fit;
hole_w   = cross_w + socket_fit;
hole_top = cross_over;              // cross hole roof, above the rim seat

// How far the footprint reaches along the slope direction; the face is
// lowest there.
reach = (size / 2 - size_r) * (abs(cos(azimuth)) + abs(sin(azimuth))) + size_r;
low_z = height - reach * tan(tilt);

echo(str("height=", height, " tilt=", tilt, " azimuth=", azimuth,
         " -> low side ", low_z, " mm, high side ", height + reach * tan(tilt), " mm"));
assert(low_z - chamfer > relief + 1, "tilt too steep for this height");

// ---------------------------------------------------------------------------
// Profiles
// ---------------------------------------------------------------------------
module cross_2d(l, w) {
    square([l, w], center = true);
    square([w, l], center = true);
}

module footprint_2d() { offset(r = size_r) square(size - 2 * size_r, center = true); }

// The footprint as the sloped face cuts it: stretched along the slope.
module face_2d() {
    rotate(azimuth) scale([1 / cos(tilt), 1]) rotate(-azimuth) footprint_2d();
}

// Tip +z over toward `azimuth`, by turning about the horizontal axis square to
// it. Applied to the top face only -- the sides stay square to the switch.
module lean() {
    rotate(a = tilt, v = [-sin(azimuth), cos(azimuth), 0]) children();
}

// Into the face frame: origin on the face centre, +z out of the face.
module on_face() { translate([0, 0, height]) lean() children(); }

// Everything below the face, with the edge chamfered at 45 degrees to it.
module under_face() {
    on_face() hull() {
        translate([0, 0, -eps]) linear_extrude(eps) offset(delta = -chamfer) face_2d();
        translate([0, 0, -big]) linear_extrude(eps) offset(delta = big - chamfer) face_2d();
    }
}

// ---------------------------------------------------------------------------
// Parts
// ---------------------------------------------------------------------------
module body() {
    intersection() {
        union() {
            translate([0, 0, relief]) linear_extrude(big) footprint_2d();
            linear_extrude(relief + eps) circle(d = seat_d);
        }
        under_face();
    }
}

// Boss that drops into the annular slot, built down from the rim seat.
module boss() {
    translate([0, 0, -boss_h]) {
        cylinder(d1 = boss_d - 2 * lead_in, d2 = boss_d, h = lead_in);
        translate([0, 0, lead_in]) cylinder(d = boss_d, h = boss_h - lead_in + eps);
    }
}

module bar_mouth(l, w) {
    hull() {
        translate([0, 0, -eps]) linear_extrude(eps)
            square([l + 2 * lead_in, w + 2 * lead_in], center = true);
        translate([0, 0, lead_in]) linear_extrude(eps) square([l, w], center = true);
    }
}

module cross_hole() {
    translate([0, 0, -boss_h]) {
        translate([0, 0, -eps]) linear_extrude(boss_h + hole_top + eps) cross_2d(hole_l, hole_w);
        bar_mouth(hole_l, hole_w);
        rotate([0, 0, 90]) bar_mouth(hole_l, hole_w);
    }
}

module tower() {
    difference() {
        union() {
            body();
            boss();
        }
        cross_hole();
    }
}

// ---------------------------------------------------------------------------
// Assembly
// ---------------------------------------------------------------------------
if (print)
    // Undo the lean, put the face on z=0 and turn it over.
    rotate([180, 0, 0]) rotate(a = -tilt, v = [-sin(azimuth), cos(azimuth), 0])
        translate([0, 0, -height]) tower();
else
    tower();
