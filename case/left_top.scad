// Entry point for the left half's top plate. Render with:
//   openscad -o build/kagu_left_top.stl case/left_top.scad
include <kagu_left_geom.scad>
include <kagu_tray.scad>
include <kagu_top.scad>

top_plate();
