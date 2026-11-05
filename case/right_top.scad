// Entry point for the right half's top plate. Render with:
//   openscad -o build/kagu_right_top.stl case/right_top.scad
include <kagu_right_geom.scad>
include <kagu_tray.scad>
include <kagu_top.scad>

top_plate();
