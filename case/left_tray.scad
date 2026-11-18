// Entry point for the left half's bottom tray. Render with:
//   openscad -o build/kagu_left_tray.stl case/left_tray.scad
include <kagu_left_geom.scad>
include <kagu_tray.scad>
include <kagu_top.scad>
include <kagu_screen.scad>

screen_fold = true;   // the folding screen's base, behind the far wall
                      // (the ledge comes with kagu_screen.scad either way)

difference() {
    union() {
        bottom_tray();
        if (screen_fold) screen_base();
    }
    if (screen_fold) wire_path();   // through the far wall too
}
