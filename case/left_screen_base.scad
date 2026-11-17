// Entry point for the folding screen's base, glued behind the left case's far
// wall. Printed standing on its bottom. Render with:
//   openscad -o build/kagu_left_screen_base.stl case/left_screen_base.scad
include <kagu_left_geom.scad>
include <kagu_tray.scad>
include <kagu_top.scad>
include <kagu_screen.scad>

screen_base();
