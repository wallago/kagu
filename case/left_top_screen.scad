// Entry point for the left half's top plate with the screen cup on its back
// edge, as one print. Printed plate up, standing on the screw spacers and
// the cup floor; enable supports for the ~2mm under the plate and the skirt. Render with:
//   openscad -o build/kagu_left_top_screen.stl case/left_top_screen.scad
include <kagu_left_geom.scad>
include <kagu_tray.scad>
include <kagu_top.scad>
include <kagu_screen.scad>

translate([0, 0, -tray_h]) {
    top_plate_in_place();
    screen_cup(base = tray_h);
}
