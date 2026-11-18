// Kagu screen pod -- holds the 1.47" 172x320 ST7789 module on the left half,
// behind the index columns and beside the XIAO, its face tilted back toward
// the typist. Two printed parts:
//
//   cup    an open box whose rim is the tilted face. Four posts inside carry
//          M2 heat-set inserts. Printed on its floor; plain flat walls for
//          now, attached to the case by hand behind the far wall.
//   bezel  a flat frame with the window, screwed onto the rim. It clamps the
//          display board onto the posts, glass up through the window.
//
// Assembly: press the inserts into the posts, lay the board on the posts with
// its holes over them, put the bezel on, four M2 x 6 screws through bezel and
// board into the inserts. The leads leave through a notch under the bezel at
// the XIAO end of the rim and drop into the open bay over the XIAO.
//
// This file expects the geometry file, kagu_tray.scad and kagu_top.scad to be
// included first (case heights, where the far wall is). Left-half coordinates.

// ---------------------------------------------------------------------------
// Display module -- MEASURE YOURS. Board from the photo, hole spacing
// estimated from it, glass and active area from typical 1.47" drawings.
// ---------------------------------------------------------------------------
lcd_board   = [37.5, 30.0];   // landscape: long side across the keyboard
lcd_pcb_t   = 1.6;
lcd_holes   = [32.0, 25.0];   // M2 hole spacing, centred on the board (both
                              // checked against a print, -0.5mm each way)
lcd_glass   = [36.2, 19.8];   // glass outline
lcd_glass_t = 2.4;            // glass + backlight stack above the board
lcd_active  = [32.4, 17.4];   // visible pixels

// ---------------------------------------------------------------------------
// Pod
// ---------------------------------------------------------------------------
pod_x     = [51.5, 94.5];     // 10mm clear of the USB-C notch on the right, so
                              // a cable's overmoulded plug fits beside the pod
face_tilt = 30;               // face angle from the desk
face_len  = 40;               // rim, along the slope; leaves room at the back
                              // for the back inserts, which lean into it
corner_r  = 4;
pod_wall  = 2.0;              // leaves ~0.75mm each side of the board inside:
                              // room for the flex tail on the right
pod_floor = 2.0;

bezel_t     = 3.4;            // glass pocket + lip in front of the glass
bezel_lip   = 1.0;
glass_clear = 0.3;
glass_side_clear = 2.0;       // extra each side, left and right: the glass
                              // would not go in with glass_clear alone
window_margin = 0.4;
window_r    = 2.0;            // rounded window corners
window_len  = 32.7;           // long side of the window
window_shift = -1.75;         // the panel's pixels sit off-centre, away from the
                              // flex end (+x): a print showed pixels cut at -x
                              // and a 2mm dark strip at +x with the window at +0.25
header_relief = [23, 2.6];    // pocket for the pin header's solder joints on the
                              // board front: length x depth, on both long edges
                              // so the board can go in either way up

post_d      = 7.2;            // merges into the side walls
insert_d    = 3.2;            // M2 heat-set insert, ~3.5mm OD
insert_h    = 4.5;
m2_clear    = 2.6;
m2_head_d   = 4.4;            // shallow 90 degree countersink for the screw head

wire_notch  = [8, 3];         // in the rim at the XIAO end: w x depth

// ---------------------------------------------------------------------------
// Derived
// ---------------------------------------------------------------------------
pod_w    = pod_x[1] - pod_x[0];
pod_cx   = (pod_x[0] + pod_x[1]) / 2;
far_y    = 82.5 + pcb_clear + wall;              // far wall beside the XIAO
case_top = tray_h + pcb_to_plate + plate_t;      // top of the assembled case
lcd_v    = face_len / 2;                         // board centred on the bezel

echo(str("screen pod: ", pod_w, " wide, ",
         round(face_len * cos(face_tilt)), " deep, ",
         round(case_top + face_len * sin(face_tilt) + bezel_t), "mm tall, face ",
         face_tilt, " deg, screws M2 x 6"));

// Local frame on the rim: origin at the middle of its front edge, x across,
// y up the slope, z out of the face. The board's front face lies in z = 0,
// flush with the rim, and the bezel sits on top of both.
module on_face() {
    translate([pod_cx, far_y, case_top]) rotate([face_tilt, 0, 0]) children();
}

module rim_2d(inset = 0) {
    translate([-pod_w / 2 + inset, inset])
        offset(r = corner_r - inset) offset(delta = -(corner_r - inset))
            square([pod_w - 2 * inset, face_len - 2 * inset]);
}

// A rim outline in the face plane, run straight down to height z0: vertical
// walls, tilted top.
module down_to(z0, inset = 0) {
    hull() {
        on_face() linear_extrude(0.01) rim_2d(inset);
        translate([0, 0, z0]) linear_extrude(0.01)
            projection() on_face() linear_extrude(0.01) rim_2d(inset);
    }
}

module hole_pts() {
    for (sx = [-1, 1], sy = [-1, 1])
        translate([sx * lcd_holes[0] / 2, lcd_v + sy * lcd_holes[1] / 2]) children();
}

// ---------------------------------------------------------------------------
// Cup
// ---------------------------------------------------------------------------
module screen_cup(base = 0) {   // base: height of the cup's underside
    difference() {
        union() {
            difference() {
                down_to(base);
                // hollow, open through the rim
                down_to(base + pod_floor, pod_wall);
                on_face() translate([0, 0, -0.01]) linear_extrude(5) rim_2d(pod_wall);
            }
            // posts, square to the face, from the floor up to the board's back
            intersection() {
                on_face() hole_pts()
                    translate([0, 0, -lcd_pcb_t - 60]) cylinder(d = post_d, h = 60);
                down_to(base);
            }
        }
        on_face() {
            // insert holes
            hole_pts() translate([0, 0, -lcd_pcb_t - insert_h])
                cylinder(d = insert_d, h = insert_h + 1);
            // wire notch in the rim toward the XIAO, clear of the post, closed over by the bezel
            translate([lcd_holes[0] / 2 - post_d / 2 - 5 - wire_notch[0], -1, -wire_notch[1]])
                cube([wire_notch[0], pod_wall + 2, wire_notch[1] + 1]);
        }
    }
}

// ---------------------------------------------------------------------------
// Bezel
// ---------------------------------------------------------------------------
module screen_bezel_flat() {   // in the face frame, sitting on z = 0
    difference() {
        linear_extrude(bezel_t) rim_2d();
        // window
        translate([window_shift, lcd_v, -1]) linear_extrude(bezel_t + 2)
            offset(r = window_r) offset(delta = -window_r)
                square([window_len,
                        lcd_active[1] + 2 * window_margin],
                       center = true);
        // header solder joints, between the screw holes along each long edge,
        // running from the glass pocket out past the board edge
        for (sy = [-1, 1])
            translate([-header_relief[0] / 2, lcd_v + sy * (lcd_board[1] / 2 + 0.5) - (sy > 0 ? 6 : 0), -1])
                cube([header_relief[0], 6, header_relief[1] + 1]);
        // glass pocket underneath, the lip stays in front
        translate([-(lcd_glass[0] / 2 + glass_clear + glass_side_clear),
                   lcd_v - lcd_glass[1] / 2 - glass_clear, -1])
            cube([lcd_glass[0] + 2 * (glass_clear + glass_side_clear), lcd_glass[1] + 2 * glass_clear,
                  bezel_t - bezel_lip + 1]);
        // M2 screws, heads sunk into the top
        hole_pts() {
            translate([0, 0, -1]) cylinder(d = m2_clear, h = bezel_t + 2);
            translate([0, 0, bezel_t - (m2_head_d - m2_clear) / 2])
                cylinder(d1 = m2_clear, d2 = m2_head_d, h = (m2_head_d - m2_clear) / 2 + 0.01);
        }
    }
}

module screen_bezel() { on_face() screen_bezel_flat(); }

// The display itself, for previews.
module lcd_model() {
    on_face() translate([0, lcd_v, 0]) {
        color("royalblue") difference() {
            translate([0, 0, -lcd_pcb_t / 2]) cube([lcd_board[0], lcd_board[1], lcd_pcb_t], center = true);
            for (sx = [-1, 1], sy = [-1, 1])
                translate([sx * lcd_holes[0] / 2, sy * lcd_holes[1] / 2, -5]) cylinder(d = 2.2, h = 10);
        }
        color([0.05, 0.05, 0.05]) translate([0, 0, lcd_glass_t / 2])
            cube([lcd_glass[0], lcd_glass[1], lcd_glass_t], center = true);
        color([0.15, 0.85, 0.35]) translate([0, 0, lcd_glass_t])
            cube([lcd_active[0], lcd_active[1], 0.05], center = true);
    }
}

// ---------------------------------------------------------------------------
// Folding head -- for a keyboard on a tripod, where the fixed 30 degree cup
// can't be seen. The screen sits in a shallow "head" that turns on two side
// pivots on a small base behind the far wall. It folds backward: 0 is
// flat (face up, lying behind the case), 90 stands straight up facing the
// typist. Each pivot is one M3 bolt: head outside, through the head's ear and
// the base's cheek, into a nyloc nut trapped in the cheek. Tighten the bolts
// until the screen holds where you leave it. The bezel is the same part as
// above. The base is printed as part of the left tray (screen_fold in
// left_tray.scad), fused to the back of the far wall.
// ---------------------------------------------------------------------------
head_d      = 12;             // head depth under the face: floor + room for
                              // the wires soldered to the back of the board
knuckle_r   = 4.5;            // round end of the ears and cheeks
ear_t       = 3.0;            // head's ears, the outer plates
cheek_t     = 4.0;            // base's cheeks, the inner plates
pivot_gap   = 0.3;            // between ear and cheek
m3_clear    = 3.3;
nyloc_af    = 5.5 + 0.3;      // M3 nyloc across flats, plus fit
nyloc_depth = 2.5;            // pocket in the cheek's inner face
tab_y       = 91.5 + pcb_clear + wall;   // back of the case's tab just left of
                              // the pod: the left ear swings over it
tab_gap     = 0.5;
head_angle  = 60;             // for previews only

// Pivot axis, in the head's frame (face at z = 0, front edge at y = 0) and in
// the world (just behind the far wall, at the top of the case).
axis_head = [-(knuckle_r + 0.5), -head_d / 2];
axis_y    = tab_y + tab_gap + knuckle_r;
base_top  = case_top;                    // flush with the assembled case
axis_z    = base_top + 0.5 + head_d / 2; // the ears ride just over the base
// wire trench under the head's notch, across the pod (from its centre)
wire_x     = [lcd_holes[0] / 2 - post_d / 2 - 5 - wire_notch[0] - 1,
              lcd_holes[0] / 2 - post_d / 2 - 5 + 1];
wire_floor = floor_t + 3;

echo(str("folding screen: head ", pod_w, " x ", face_len, " x ", head_d,
         ", pivots 2x M3 x 10-12 + nyloc, base ", round(axis_y + knuckle_r - far_y),
         "mm deep"));

module on_head(a = head_angle) {
    translate([pod_cx, axis_y, axis_z]) rotate([a, 0, 0])
        translate([0, -axis_head[0], -axis_head[1]]) children();
}

module pivot_x(x0, t) {     // a rod along x through the axis, x0..x0+t
    translate([x0, 0, 0]) rotate([0, 90, 0]) cylinder(r = knuckle_r, h = t);
}

module screen_head_flat() {   // in the head frame, face up
    difference() {
        union() {
            difference() {
                translate([0, 0, -head_d]) linear_extrude(head_d) rim_2d();
                translate([0, 0, -head_d + pod_floor]) linear_extrude(head_d) rim_2d(pod_wall);
            }
            intersection() {
                hole_pts() translate([0, 0, -head_d]) cylinder(d = post_d, h = head_d - lcd_pcb_t);
                translate([0, 0, -head_d]) linear_extrude(head_d) rim_2d();
            }
            // ears: the side walls run forward around the pivot
            for (sx = [-1, 1]) hull() {
                translate([0, axis_head[0], axis_head[1]])
                    pivot_x(sx > 0 ? pod_w / 2 - ear_t : -pod_w / 2, ear_t);
                translate([sx > 0 ? pod_w / 2 - ear_t : -pod_w / 2, 0, -head_d])
                    cube([ear_t, corner_r, head_d]);
            }
        }
        hole_pts() translate([0, 0, -lcd_pcb_t - insert_h])
            cylinder(d = insert_d, h = insert_h + 1);
        // wire notch in the front rim, closed over by the bezel
        translate([lcd_holes[0] / 2 - post_d / 2 - 5 - wire_notch[0], -1, -wire_notch[1]])
            cube([wire_notch[0], pod_wall + 2, wire_notch[1] + 1]);
        // pivot bolts
        translate([-pod_w, axis_head[0], axis_head[1]]) rotate([0, 90, 0])
            cylinder(d = m3_clear, h = 2 * pod_w);
    }
}

module screen_head(a = head_angle) { on_head(a) screen_head_flat(); }

module base_2d(y0) {
    r  = wall + pcb_clear;                     // the case's outer corners
    x0 = pod_x[0] - wall - pcb_clear - 1;
    y1 = axis_y + knuckle_r;
    translate([x0, y0]) square([pod_x[1] - r - x0, y1 - y0]);
    translate([pod_x[1] - r - 0.01, y0]) square([r + 0.01, y1 - r - y0]);
    translate([pod_x[1] - r, y1 - r]) circle(r = r);
}

// The wire path: a trench under the head's wire notch, from the back of the
// base through the far wall into the tray, under the PCB. Cut from the base
// and the tray together (left_tray.scad).
module wire_path() {
    translate([pod_cx + wire_x[0], far_y - wall - 1, wire_floor])
        cube([wire_x[1] - wire_x[0], axis_y + knuckle_r - far_y + wall + 2, tray_h]);
}

module screen_base() {
    cheek_x = pod_w / 2 - ear_t - pivot_gap;   // outer face of a cheek, from the centre
    y0 = far_y - 1;                            // 1mm into the far wall
    cy = axis_y - knuckle_r;                   // cheeks stay behind the case
    difference() {
        union() {
            // Runs on into the ledge's wall on the left, filling its rounded
            // corner; the outer corner on the right is rounded like the case.
            // Above the tray border it goes on up to the top plate's height,
            // 0.2mm clear of the plate. Over the ledge's right wall it takes
            // the plate's place (plate_cut), so base and ledge meet square.
            difference() {
                union() {
                    linear_extrude(tray_h) base_2d(y0);
                    translate([0, 0, tray_h]) linear_extrude(base_top - tray_h)
                        difference() {
                            base_2d(y0);
                            offset(delta = 0.2) profile(wall + pcb_clear);
                            translate([-big, -big]) square([big + ledge[2] + 0.2, 2 * big]);
                        }
                }
                translate([0, 0, floor_t]) linear_extrude(base_top) cavity_2d();
            }
            for (sx = [-1, 1]) hull() {
                translate([pod_cx, axis_y, axis_z])
                    pivot_x(sx > 0 ? cheek_x - cheek_t : -cheek_x, cheek_t);
                translate([pod_cx + (sx > 0 ? cheek_x - cheek_t : -cheek_x), cy, 0])
                    cube([cheek_t, 2 * knuckle_r, 1]);
            }
        }
        translate([pod_x[0] - 1, axis_y, axis_z]) rotate([0, 90, 0])
            cylinder(d = m3_clear, h = pod_w + 2);
        wire_path();
        // nyloc pockets on the inner faces
        for (sx = [-1, 1])
            translate([pod_cx + sx * (cheek_x - cheek_t + nyloc_depth / 2), axis_y, axis_z])
                rotate([0, 90, 0]) rotate([0, 0, 30])
                    cylinder(d = nyloc_af / cos(30), h = nyloc_depth + 0.02, center = true, $fn = 6);
    }
}

// The ledge -- the case filled out behind the left keys, from the left edge to
// the base, so the back is one straight line with the base. Hollow, under the
// top plate, with two more M3 inserts holding the plate down there. Read by
// kagu_tray.scad and kagu_top.scad, which leave it empty on the right half.
ledge = [0, 70, pod_x[0] - wall - pcb_clear - 0.5,
         axis_y + knuckle_r - wall];   // its wall ends flush with the base's back
ledge_screws = [[9, 96], [44, 96]];
ledge_boss_top = tray_h + skirt_gap;   // meets the plate's spacers
plate_cut = [ledge[2], tab_y];         // the plate stops here; the base takes over

module lcd_on_head(a = head_angle) {
    on_head(a) translate([0, lcd_v, 0]) {
        color("royalblue") translate([0, 0, -lcd_pcb_t / 2])
            cube([lcd_board[0], lcd_board[1], lcd_pcb_t], center = true);
        color([0.05, 0.05, 0.05]) translate([0, 0, lcd_glass_t / 2])
            cube([lcd_glass[0], lcd_glass[1], lcd_glass_t], center = true);
        color([0.15, 0.85, 0.35]) translate([0, 0, lcd_glass_t])
            cube([lcd_active[0], lcd_active[1], 0.05], center = true);
    }
}
