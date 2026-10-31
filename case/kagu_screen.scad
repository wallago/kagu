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
lcd_holes   = [32.5, 25.5];   // M2 hole spacing, centred on the board
lcd_glass   = [36.2, 19.8];   // glass outline
lcd_glass_t = 2.4;            // glass + backlight stack above the board
lcd_active  = [32.4, 17.4];   // visible pixels

// ---------------------------------------------------------------------------
// Pod
// ---------------------------------------------------------------------------
pod_x     = [62.0, 104.5];    // stops short of the USB-C notch on the right
face_tilt = 30;               // face angle from the desk
face_len  = 40;               // rim, along the slope; leaves room at the back
                              // for the back inserts, which lean into it
corner_r  = 4;
pod_wall  = 2.0;              // leaves ~0.5mm round the board inside
pod_floor = 2.0;

bezel_t     = 3.4;            // glass pocket + lip in front of the glass
bezel_lip   = 1.0;
glass_clear = 0.3;
window_margin = 0.4;

post_d      = 6.4;            // merges into the side walls
insert_d    = 3.2;            // M2 heat-set insert, ~3.5mm OD
insert_h    = 4.5;
m2_clear    = 2.4;
m2_head_d   = 4.2;            // counterbore for the screw head
m2_head_h   = 1.4;

wire_notch  = [8, 3];         // in the rim at the XIAO end: w x depth

// ---------------------------------------------------------------------------
// Derived
// ---------------------------------------------------------------------------
pod_w    = pod_x[1] - pod_x[0];
pod_cx   = (pod_x[0] + pod_x[1]) / 2;
far_y    = 82.5 + pcb_clear + wall;              // far wall beside the XIAO
case_top = tray_h + pcb_to_plate + plate_t;      // top of the assembled case
lcd_v    = lcd_board[1] / 2 + pod_wall + 0.5;    // board centre, up the slope:
                                                 // as low as the front wall allows

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
module screen_cup() {
    difference() {
        union() {
            difference() {
                down_to(0);
                // hollow, open through the rim
                down_to(pod_floor, pod_wall);
                on_face() translate([0, 0, -0.01]) linear_extrude(5) rim_2d(pod_wall);
            }
            // posts, square to the face, from the floor up to the board's back
            intersection() {
                on_face() hole_pts()
                    translate([0, 0, -lcd_pcb_t - 60]) cylinder(d = post_d, h = 60);
                down_to(0);
            }
        }
        on_face() {
            // insert holes
            hole_pts() translate([0, 0, -lcd_pcb_t - insert_h])
                cylinder(d = insert_d, h = insert_h + 1);
            // wire notch in the rim at the XIAO end, closed over by the bezel
            translate([pod_w / 2 - pod_wall - wire_notch[0] - 2, -1, -wire_notch[1]])
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
        translate([0, lcd_v, 0])
            cube([lcd_active[0] + 2 * window_margin, lcd_active[1] + 2 * window_margin,
                  3 * bezel_t], center = true);
        // glass pocket underneath, the lip stays in front
        translate([-(lcd_glass[0] / 2 + glass_clear), lcd_v - lcd_glass[1] / 2 - glass_clear, -1])
            cube([lcd_glass[0] + 2 * glass_clear, lcd_glass[1] + 2 * glass_clear,
                  bezel_t - bezel_lip + 1]);
        // M2 screws, heads sunk into the top
        hole_pts() {
            translate([0, 0, -1]) cylinder(d = m2_clear, h = bezel_t + 2);
            translate([0, 0, bezel_t - m2_head_h]) cylinder(d = m2_head_d, h = m2_head_h + 1);
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
