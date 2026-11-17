// Entry point for the folding screen head, printed on its floor. Render with:
//   openscad -o build/kagu_left_screen_head.stl case/left_screen_head.scad
include <kagu_left_geom.scad>
include <kagu_tray.scad>
include <kagu_top.scad>
include <kagu_screen.scad>

translate([0, 0, head_d]) screen_head_flat();
