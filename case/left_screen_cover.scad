// Entry point for the left screen pod's back cover. Render with:
//   openscad -o build/kagu_left_screen_cover.stl case/left_screen_cover.scad
include <kagu_left_geom.scad>
include <kagu_tray.scad>
include <kagu_top.scad>
include <kagu_screen.scad>

// Flat on the bed, outside face down.
rotate([-90, 0, 0]) translate([0, -pod_back, 0]) screen_cover();
