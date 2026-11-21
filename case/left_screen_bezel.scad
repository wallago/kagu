// Entry point for the left screen pod's bezel, printed face down. Render with:
//   openscad -o build/kagu_left_screen_bezel.stl case/left_screen_bezel.scad
include <kagu_left_geom.scad>
include <kagu_tray.scad>
include <kagu_top.scad>
include <kagu_screen.scad>

translate([0, 0, bezel_t]) rotate([180, 0, 0]) screen_bezel_flat();
