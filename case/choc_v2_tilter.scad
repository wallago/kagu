// Choc v2 keycap tilter -- an MX-to-MX wedge that drops between a Kailh Choc
// v2 (PG1353) switch and its keycap and leans the cap over by `tilt` degrees,
// in the compass direction `azimuth`.
//
// Re-cut from a Choc v1 tilter kit for the v2 cruciform stem.
//
// An MX cross only engages every 90 degrees, so the lean direction has to be
// built into the part -- you cannot turn an azimuth=0 wedge 45 degrees on the
// switch and have the cross still seat. Two prints per angle cover everything:
//
//   azimuth=0   turned 0/90/180/270 on the switch -> the four square leans
//   azimuth=45  turned 0/90/180/270 on the switch -> the four diagonal leans
//
// Select both with -D tilt=25 -D azimuth=45.

tilt    = 25;         // degrees of lean; 0 leaves a plain riser
azimuth = 0;          // which way it leans, degrees CCW from +x

// ---------------------------------------------------------------------------
// Body -- footprint carried over from the v1 kit this replaces.
// ---------------------------------------------------------------------------
body   = 8.9;         // square footprint
body_r = 2.2;         // corner radius
web    = 1.0;         // solid left between the socket roof and the tilted face

// ---------------------------------------------------------------------------
// Male stem -- a plain MX cruciform, 4.1 x 1.17 Cherry nominal. Confirmed
// fitting real keycaps, so leave it alone.
// ---------------------------------------------------------------------------
cap_cross_l = 4.10;   // arm length  -- Cherry nominal, confirmed on real caps
cap_cross_w = 1.17;   // arm width
stem_h     = 3.60;    // male stem, standing off the tilted face
lead_in    = 0.10;    // chamfer on the socket mouth and on the stem tip

// ---------------------------------------------------------------------------
// Switch side, from the PG1353 datasheet (CPG135301D01 rev A, sheets 1-2).
//
// The v2 stem is not a bare cross. It is a tube: ø6.50 outside, ø5.50 bore,
// with the 4.00 x 1.30 cross standing inside it and a ~0.75 annular slot
// between the two. Cross and rim finish flush, so there is nothing to grip
// above the rim -- a counterbored cross socket gets zero engagement. What
// mates with this reaches DOWN into the slot, exactly as an MX cap does.
//
// It is also what buys the travel. The part lands on the rim 3.30 above the
// housing and the switch moves 3.20, leaving 0.10 at bottom-out -- and the
// travel tolerance is +/-0.25, so check a key presses fully before printing
// a set. A relief step under the body would buy margin at the cost of a
// visible collar; this version goes flat to the boss instead.
// ---------------------------------------------------------------------------
stem_bore  = 5.50;    // bore the boss drops into
stem_od    = 6.50;    // tube outside diameter -- the rim the part rests on
cross_l    = 4.00;    // cross arm span      (datasheet 2-4.00 +/-0.05)
cross_w    = 1.30;    // cross arm width     (datasheet 2-1.30 +/-0.03)

boss_h     = 2.50;    // how far the boss reaches into the slot (3.52 available)
boss_fit   = 0.20;    // boss diameter under the bore
socket_fit = 0.15;    // added to both cross dimensions of the hole
cross_over = 0.20;    // hole past the shoulder, so the rim seats before the cross

$fn = 64;
eps = 0.01;
big = 100;

// ---------------------------------------------------------------------------
// Derived
// ---------------------------------------------------------------------------
boss_d      = stem_bore - boss_fit;   // thin wall that enters the annular slot
hole_l      = cross_l + socket_fit;
hole_w      = cross_w + socket_fit;
hole_top    = boss_h + cross_over;    // cross hole roof
underside_z = boss_h;                 // body underside, straight onto the rim

// How far a centred l x w cross, and the body, reach along the lean direction.
// The tilted face drops fastest there, so these set every height below.
function cross_reach(l, w, a) = max(l / 2 * abs(cos(a)) + w / 2 * abs(sin(a)),
                                    w / 2 * abs(cos(a)) + l / 2 * abs(sin(a)));
function body_reach(a) = (body / 2 - body_r) * (abs(cos(a)) + abs(sin(a))) + body_r;

// Keep `web` of material over the cross hole, and over the body underside at
// its low corner. Whichever the lean brings closest sets the face height; the
// crowding corner moves as the azimuth turns.
plane_z = max(hole_top    + web + cross_reach(hole_l, hole_w, azimuth) * tan(tilt),
              underside_z + web + body_reach(azimuth) * tan(tilt));

// Tallest point, for the echo: the stem's trailing base corner, its trailing
// chamfered tip, or the body's high corner -- whichever the lean puts highest.
tip_z = max(cross_reach(cap_cross_l, cap_cross_w, azimuth) * sin(tilt)
                + (stem_h - lead_in) * cos(tilt),
            cross_reach(cap_cross_l - 2 * lead_in, cap_cross_w - 2 * lead_in, azimuth) * sin(tilt)
                + stem_h * cos(tilt));

echo(str("tilt=", tilt, " azimuth=", azimuth, "  overall height=",
         plane_z + max(tip_z, body_reach(azimuth) * tan(tilt)), "mm"));

// ---------------------------------------------------------------------------
// Profiles
// ---------------------------------------------------------------------------
module cross_2d(l, w) {
    square([l, w], center = true);
    square([w, l], center = true);
}

module body_2d() { offset(r = body_r) square(body - 2 * body_r, center = true); }

// Tip +z over toward `azimuth`, by turning about the horizontal axis square to
// it. The socket below stays put -- it has to stay square to the switch.
module lean() {
    rotate(a = tilt, v = [-sin(azimuth), cos(azimuth), 0]) children();
}

// Everything below the tilted face.
module under_face() {
    translate([0, 0, plane_z]) lean()
        translate([0, 0, -big / 2]) cube(big, center = true);
}

// ---------------------------------------------------------------------------
// Mounts -- built one bar at a time so the chamfers stay rectangular; the
// convex hull of a whole cross would round the arms off.
// ---------------------------------------------------------------------------
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

// Boss that drops into the annular slot. The body underside above it is what
// lands on the tube rim.
module mount() {
    cylinder(d1 = boss_d - 2 * lead_in, d2 = boss_d, h = lead_in);
    translate([0, 0, lead_in]) cylinder(d = boss_d, h = boss_h - lead_in + eps);
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
        mount();
        intersection() {
            translate([0, 0, underside_z]) linear_extrude(big) body_2d();
            under_face();
        }
        translate([0, 0, plane_z]) lean() stem();
    }
    cross_hole();
}
