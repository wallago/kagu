// Entry point for the left half's bottom tray. Render with:
//   openscad -o build/kagu_left_tray.stl case/left_tray.scad
include <kagu_left_geom.scad>
include <kagu_tray.scad>
include <kagu_top.scad>
include <kagu_screen.scad>

screen_fold = true;   // the folding screen's base, behind the far wall

bottom_tray();
if (screen_fold) screen_base();
