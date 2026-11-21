// Entry point for the left half's screen cup, printed on its floor. Render with:
//   openscad -o build/kagu_left_screen_pod.stl case/left_screen_pod.scad
include <kagu_left_geom.scad>
include <kagu_tray.scad>
include <kagu_top.scad>
include <kagu_screen.scad>

screen_cup();
