// Kagu screen pod -- a separate wedge printed on its own and welded onto the
// back of the left case, above the index columns and beside the XIAO, holding
// the 1.47" 172x320 ST7789 module in landscape, its face tilted back toward the
// typist.
//
// This file expects the geometry file, kagu_tray.scad and kagu_top.scad to be
// included first: the pod's front hugs the assembled case's far side (tray
// border plus top plate skirt) with a small gap, so it can be pressed against
// it and melted on with a soldering iron. Neither tray nor plate changes.
//
// Left-half coordinates (chip on the +x edge). The module mounts from behind
// on four M2 screws, glass first into a pocket behind the bezel; a back cover
// on two M2 screws closes the pod. The leads leave through a notch at the foot
// of the face and drop into the open bay over the XIAO.

// ---------------------------------------------------------------------------
// Display module -- MEASURE YOURS. Board and hole spacing taken from the photo
// of the module, glass and active area from typical 1.47" panel drawings.
// ---------------------------------------------------------------------------
lcd_board  = [37.5, 30.0];   // landscape: long side across the keyboard
lcd_pcb_t  = 1.6;
lcd_holes  = [32.5, 25.5];   // M2 hole spacing, centred on the board
lcd_glass  = [36.2, 19.8];   // glass outline
lcd_glass_t = 2.4;           // glass + backlight stack above the board
lcd_active = [32.4, 17.4];   // visible pixels

// ---------------------------------------------------------------------------
// Pod
// ---------------------------------------------------------------------------
pod_x     = [62.5, 104.5];   // stops short of the USB-C notch on the right
face_tilt = 30;              // face angle from the desk
face_len  = 40;              // along the slope
face_t    = 2.4;             // bezel thickness at the window
pod_wall  = 2.0;
pod_cap   = 4.0;             // flat top behind the face
glass_clear = 0.3;
bezel_lip = 1.0;             // plastic left in front of the glass
window_margin = 0.4;         // window a hair bigger than the active area
pod_floor = 2.0;
case_fit  = 0.2;             // gap to the case, filled when it is welded on
wire_notch = [8, 4];         // at the foot of the face, next to the XIAO: w x h

m2_pilot = 1.7;
m2_clear = 2.3;

// ---------------------------------------------------------------------------
// Derived
// ---------------------------------------------------------------------------
pod_w  = pod_x[1] - pod_x[0];
pod_cx = (pod_x[0] + pod_x[1]) / 2;
far_y  = 82.5 + pcb_clear + wall;                 // far wall beside the XIAO
case_top = tray_h + pcb_to_plate + plate_t;       // top of the assembled case
face_z = case_top;                                // face starts at plate-top height
face_y = far_y;
face_top = [face_y + face_len * cos(face_tilt), face_z + face_len * sin(face_tilt)];
pod_back = face_top[0] + pod_cap;
pod_h    = face_top[1];
// Where the board sits on the slope: 3mm above centre, so the keycaps of the
// top row do not hide the bottom of the window.
lcd_v    = face_len / 2 + 3;

echo(str("screen pod: ", pod_w, " wide, ", round(pod_back - far_y), " deep, ",
         round(pod_h), "mm tall, face ", face_tilt, " deg"));

// Local frame on the face: origin on the outer surface at the bottom edge,
// x across, y up the slope, z out toward the typist.
module on_face() {
    translate([pod_cx, face_y, face_z]) rotate([face_tilt, 0, 0]) children();
}

module pod_profile() {   // in (y, z)
    polygon([
        [far_y, 0], [face_y, face_z],
        face_top, [pod_back, pod_h], [pod_back, 0],
    ]);
}

module pod_inside() {
    // Hollow: the profile pulled in by the wall, open at the back for the cover.
    intersection() {
        translate([pod_x[0] + pod_wall, 0, 0])
            rotate([90, 0, 90]) linear_extrude(pod_w - 2 * pod_wall)
                offset(delta = -pod_wall) pod_profile();
        translate([0, 0, pod_floor]) cube([big, big, big]);
    }
    // back opening
    translate([pod_x[0] + pod_wall, pod_back - pod_wall - eps, pod_floor])
        cube([pod_w - 2 * pod_wall, pod_wall + 2 * eps, pod_h - pod_floor - pod_wall]);
}

// The board's front face lands at depth bezel_lip + lcd_glass_t behind the
// outer surface; bosses run from the inside of the face down to it.
module lcd_standoffs() {
    on_face()
        for (sx = [-1, 1], sy = [-1, 1])
            translate([sx * lcd_holes[0] / 2, lcd_v + sy * lcd_holes[1] / 2,
                       -(bezel_lip + lcd_glass_t)])
                cylinder(d = 4.5, h = bezel_lip + lcd_glass_t - eps);
}

module lcd_cuts() {
    on_face() {
        // window
        translate([0, lcd_v, 0])
            cube([lcd_active[0] + 2 * window_margin, lcd_active[1] + 2 * window_margin, 20],
                 center = true);
        // glass pocket, from the inside up to the bezel lip
        translate([-(lcd_glass[0] / 2 + glass_clear), lcd_v - lcd_glass[1] / 2 - glass_clear,
                   -(bezel_lip + lcd_glass_t + 5)])
            cube([lcd_glass[0] + 2 * glass_clear, lcd_glass[1] + 2 * glass_clear,
                  lcd_glass_t + 5]);
        // M2 pilot holes
        for (sx = [-1, 1], sy = [-1, 1])
            translate([sx * lcd_holes[0] / 2, lcd_v + sy * lcd_holes[1] / 2,
                       -(bezel_lip + lcd_glass_t) - 5])
                cylinder(d = m2_pilot, h = 5 + lcd_glass_t);
    }
}

// Two bosses inside the back opening for the cover screws.
cover_pts = [[pod_x[0] + pod_wall + 3, pod_floor + 4], [pod_x[1] - pod_wall - 3, pod_floor + 4]];
module screen_pod() {
    difference() {
        union() {
            difference() {
                translate([pod_x[0], 0, 0])
                    rotate([90, 0, 90]) linear_extrude(pod_w) pod_profile();
                difference() { pod_inside(); pod_case_relief(); }
            }
            intersection() {
                lcd_standoffs();
                translate([pod_x[0], 0, 0])
                    rotate([90, 0, 90]) linear_extrude(pod_w) pod_profile();
            }
            for (p = cover_pts)
                translate([p[0] - 3, pod_back - pod_wall - 6, pod_floor])
                    cube([6, 6, p[1] + 3 - pod_floor]);
        }
        lcd_cuts();
        // cover screw holes, coming in from the back
        for (p = cover_pts)
            translate([p[0], pod_back + eps, p[1]]) rotate([90, 0, 0])
                cylinder(d = m2_pilot, h = 10);
        // follow the case's far side, where the middle column juts out
        translate([0, 0, -eps])
            linear_extrude(case_top + case_fit) offset(r = case_fit) shell_2d();
        // wire notch at the foot of the face, on the XIAO side
        translate([pod_x[1] - pod_wall - wire_notch[0], far_y - 1, case_top - eps])
            cube([wire_notch[0], pod_wall + 4, wire_notch[1]]);
    }
}

// Where the case juts into the pod, the hollow steps back so the wall stays
// pod_wall thick all round.
module pod_case_relief() {
    translate([0, 0, -eps])
        linear_extrude(case_top + case_fit + pod_wall)
            offset(r = case_fit + pod_wall) shell_2d();
}

// Printed standing on its open back: the face comes out at 60 degrees, the
// floor and cap as walls, and only the short front wall bridges.
module screen_pod_print() {
    rotate([-90, 0, 0]) translate([0, -pod_back, 0]) screen_pod();
}

module screen_cover() {
    difference() {
        translate([pod_x[0] + pod_wall + 0.2, pod_back - pod_wall, pod_floor + 0.2])
            cube([pod_w - 2 * pod_wall - 0.4, pod_wall, pod_h - pod_floor - pod_wall - 0.4]);
        for (p = cover_pts)
            translate([p[0], pod_back + eps, p[1]]) rotate([90, 0, 0])
                cylinder(d = m2_clear, h = 10);
    }
}

// The module itself, for previews.
module lcd_model() {
    on_face() translate([0, lcd_v, -(bezel_lip + lcd_glass_t)]) {
        color("royalblue") difference() {
            translate([0, 0, -lcd_pcb_t / 2]) cube([lcd_board[0], lcd_board[1], lcd_pcb_t], center = true);
            for (sx = [-1, 1], sy = [-1, 1])
                translate([sx * lcd_holes[0] / 2, sy * lcd_holes[1] / 2, -5]) cylinder(d = 2.2, h = 10);
        }
        color([0.05, 0.05, 0.05]) translate([0, 0, lcd_glass_t / 2])
            cube([lcd_glass[0], lcd_glass[1], lcd_glass_t], center = true);
        color([0.15, 0.85, 0.35]) translate([0, 0, lcd_glass_t])
            cube([lcd_active[0], lcd_active[1], 0.05], center = true);
        // 8-pin header along the bottom edge, pins out the back
        color("silver") for (i = [0 : 7])
            translate([(i - 3.5) * 2.54, -lcd_board[1] / 2 + 1.6, -lcd_pcb_t - 4])
                cube([0.64, 0.64, 6], center = true);
    }
}
