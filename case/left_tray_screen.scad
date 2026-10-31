// Entry point for the left half's tray with the screen pod. Render with:
//   openscad -o build/kagu_left_tray_screen.stl case/left_tray_screen.scad
include <kagu_left_geom.scad>
include <kagu_tray.scad>
include <kagu_top.scad>
include <kagu_screen.scad>

difference() {
    union() {
        bottom_tray();
        screen_pod();
    }
    screen_wire_slot();
}
