/*
 * Kagu status screen for the 1.47" 320x172 ST7789 on the left half.
 *
 *   [batt  78%]        o o o o o        [BT *]
 *   ----------------------------------------
 *                      BASE
 *                      ----
 *          (  78%  )            (  64%  )
 *          (   L   )            (   R   )
 *   ----------------------------------------
 *    BT 1        |    USB     |    LAYER 0
 *
 * The gauges are rings of dots that fill with each half's battery level.
 */

#include <zephyr/kernel.h>
#include <zephyr/logging/log.h>
#include <lvgl.h>

#include <zmk/battery.h>
#include <zmk/ble.h>
#include <zmk/display.h>
#include <zmk/display/status_screen.h>
#include <zmk/endpoints.h>
#include <zmk/event_manager.h>
#include <zmk/events/battery_state_changed.h>
#include <zmk/events/ble_active_profile_changed.h>
#include <zmk/events/endpoint_changed.h>
#include <zmk/events/layer_state_changed.h>
#include <zmk/keymap.h>
#include <zmk/split/central.h>

LOG_MODULE_DECLARE(zmk, CONFIG_ZMK_LOG_LEVEL);

#define WHITE lv_color_hex(0xf2f2f2)
#define GREY lv_color_hex(0x8a8f98)
#define DARK lv_color_hex(0x3a3d44)
#define MINT lv_color_hex(0x4cf5a6)
#define CYAN lv_color_hex(0x5bd3f5)
#define BLUE lv_color_hex(0x3d6bff)
#define AMBER lv_color_hex(0xffb000)

#define W 320
#define H 172

#define GAUGE_DOTS 22
#define GAUGE_RADIUS 33
#define GAUGE_Y 100

static lv_obj_t *top_batt_icon;
static lv_obj_t *top_batt_label;
static lv_obj_t *profile_dot[ZMK_BLE_PROFILE_COUNT];
static lv_obj_t *link_dot;
static lv_obj_t *layer_name_label;
static lv_obj_t *gauge_dot[2][GAUGE_DOTS];
static lv_obj_t *gauge_label[2];
static lv_obj_t *bt_icon, *bt_label;
static lv_obj_t *usb_icon, *usb_label;
static lv_obj_t *layer_index_label;

/* Helpers */

static lv_obj_t *text(lv_obj_t *parent, const lv_font_t *font, lv_color_t color, const char *s) {
    lv_obj_t *label = lv_label_create(parent);
    lv_obj_set_style_text_font(label, font, LV_PART_MAIN);
    lv_obj_set_style_text_color(label, color, LV_PART_MAIN);
    lv_label_set_text(label, s);
    return label;
}

static lv_obj_t *dot(lv_obj_t *parent, int32_t size, lv_color_t color) {
    lv_obj_t *obj = lv_obj_create(parent);
    lv_obj_remove_style_all(obj);
    lv_obj_set_size(obj, size, size);
    lv_obj_set_style_radius(obj, LV_RADIUS_CIRCLE, LV_PART_MAIN);
    lv_obj_set_style_bg_opa(obj, LV_OPA_COVER, LV_PART_MAIN);
    lv_obj_set_style_bg_color(obj, color, LV_PART_MAIN);
    return obj;
}

static void rect(lv_obj_t *parent, int32_t x, int32_t y, int32_t w, int32_t h, lv_color_t color) {
    lv_obj_t *obj = lv_obj_create(parent);
    lv_obj_remove_style_all(obj);
    lv_obj_set_pos(obj, x, y);
    lv_obj_set_size(obj, w, h);
    lv_obj_set_style_radius(obj, h / 2, LV_PART_MAIN);
    lv_obj_set_style_bg_opa(obj, LV_OPA_COVER, LV_PART_MAIN);
    lv_obj_set_style_bg_color(obj, color, LV_PART_MAIN);
}

static const char *battery_symbol(uint8_t level) {
    if (level > 90) {
        return LV_SYMBOL_BATTERY_FULL;
    } else if (level > 60) {
        return LV_SYMBOL_BATTERY_3;
    } else if (level > 35) {
        return LV_SYMBOL_BATTERY_2;
    } else if (level > 10) {
        return LV_SYMBOL_BATTERY_1;
    }
    return LV_SYMBOL_BATTERY_EMPTY;
}

/* Layer */

struct layer_state {
    zmk_keymap_layer_index_t index;
    const char *name;
};

static struct layer_state layer_get_state(const zmk_event_t *eh) {
    zmk_keymap_layer_index_t index = zmk_keymap_highest_layer_active();
    return (struct layer_state){
        .index = index,
        .name = zmk_keymap_layer_name(zmk_keymap_layer_index_to_id(index)),
    };
}

static void layer_update_cb(struct layer_state state) {
    char name[16];
    if (state.name == NULL || state.name[0] == '\0') {
        snprintf(name, sizeof(name), "LAYER %d", state.index);
    } else {
        int i = 0;
        for (; state.name[i] != '\0' && i < sizeof(name) - 1; i++) {
            char c = state.name[i];
            name[i] = (c >= 'a' && c <= 'z') ? c - 'a' + 'A' : c;
        }
        name[i] = '\0';
    }
    lv_label_set_text(layer_name_label, name);
    lv_label_set_text_fmt(layer_index_label, "LAYER %d", state.index);
}

ZMK_DISPLAY_WIDGET_LISTENER(kagu_layer, struct layer_state, layer_update_cb, layer_get_state)
ZMK_SUBSCRIPTION(kagu_layer, zmk_layer_state_changed);

/* Output: active BLE profile, its link state, and USB vs BLE */

struct output_state {
    struct zmk_endpoint_instance selected;
    enum zmk_transport preferred;
    uint8_t profile;
    bool connected;
    bool bonded;
};

static struct output_state output_get_state(const zmk_event_t *eh) {
    return (struct output_state){
        .selected = zmk_endpoint_get_selected(),
        .preferred = zmk_endpoint_get_preferred_transport(),
        .profile = zmk_ble_active_profile_index(),
        .connected = zmk_ble_active_profile_is_connected(),
        .bonded = !zmk_ble_active_profile_is_open(),
    };
}

static void output_update_cb(struct output_state state) {
    for (int i = 0; i < ZMK_BLE_PROFILE_COUNT; i++) {
        lv_obj_set_style_bg_color(profile_dot[i], i == state.profile ? MINT : DARK, LV_PART_MAIN);
    }

    lv_color_t link = state.connected ? MINT : (state.bonded ? DARK : AMBER);
    lv_obj_set_style_bg_color(link_dot, link, LV_PART_MAIN);

    enum zmk_transport transport = state.selected.transport;
    if (transport == ZMK_TRANSPORT_NONE) {
        transport = state.preferred;
    }
    bool ble = transport == ZMK_TRANSPORT_BLE;

    lv_label_set_text_fmt(bt_label, "BT %d", state.profile + 1);
    lv_obj_set_style_text_color(bt_icon, ble ? BLUE : DARK, LV_PART_MAIN);
    lv_obj_set_style_text_color(bt_label, ble ? WHITE : GREY, LV_PART_MAIN);
    lv_obj_set_style_text_color(usb_icon, ble ? DARK : WHITE, LV_PART_MAIN);
    lv_obj_set_style_text_color(usb_label, ble ? GREY : WHITE, LV_PART_MAIN);
}

ZMK_DISPLAY_WIDGET_LISTENER(kagu_output, struct output_state, output_update_cb, output_get_state)
ZMK_SUBSCRIPTION(kagu_output, zmk_endpoint_changed);
ZMK_SUBSCRIPTION(kagu_output, zmk_ble_active_profile_changed);

/* Batteries: [0] is this (left) half, [1] the right half */

struct battery_state {
    uint8_t level[2];
};

static struct battery_state battery_cache;

static struct battery_state battery_get_state(const zmk_event_t *eh) {
    const struct zmk_battery_state_changed *own = as_zmk_battery_state_changed(eh);
    const struct zmk_peripheral_battery_state_changed *peer =
        as_zmk_peripheral_battery_state_changed(eh);

    if (own != NULL) {
        battery_cache.level[0] = own->state_of_charge;
    } else if (peer != NULL) {
        if (peer->source == 0) {
            battery_cache.level[1] = peer->state_of_charge;
        }
    } else {
        battery_cache.level[0] = zmk_battery_state_of_charge();
        zmk_split_central_get_peripheral_battery_level(0, &battery_cache.level[1]);
    }
    return battery_cache;
}

static void battery_update_cb(struct battery_state state) {
    static const lv_color_t fill[2] = {MINT, CYAN};

    for (int g = 0; g < 2; g++) {
        uint8_t level = state.level[g];
        int lit = (level * GAUGE_DOTS + 50) / 100;
        for (int i = 0; i < GAUGE_DOTS; i++) {
            lv_obj_set_style_bg_color(gauge_dot[g][i], i < lit ? fill[g] : DARK, LV_PART_MAIN);
        }
        if (level == 0) {
            lv_label_set_text(gauge_label[g], "--");
        } else {
            lv_label_set_text_fmt(gauge_label[g], "%d%%", level);
        }
    }

    lv_label_set_text(top_batt_icon, battery_symbol(state.level[0]));
    lv_label_set_text_fmt(top_batt_label, "%d%%", state.level[0]);
}

ZMK_DISPLAY_WIDGET_LISTENER(kagu_battery, struct battery_state, battery_update_cb,
                            battery_get_state)
ZMK_SUBSCRIPTION(kagu_battery, zmk_battery_state_changed);
ZMK_SUBSCRIPTION(kagu_battery, zmk_peripheral_battery_state_changed);

/* Layout */

static void top_bar(lv_obj_t *screen) {
    top_batt_icon = text(screen, &lv_font_montserrat_14, MINT, LV_SYMBOL_BATTERY_FULL);
    lv_obj_set_pos(top_batt_icon, 8, 3);
    top_batt_label = text(screen, &lv_font_montserrat_14, WHITE, "");
    lv_obj_set_pos(top_batt_label, 34, 3);

    const int32_t gap = 11;
    int32_t x0 = W / 2 - (ZMK_BLE_PROFILE_COUNT - 1) * gap / 2 - 3;
    for (int i = 0; i < ZMK_BLE_PROFILE_COUNT; i++) {
        profile_dot[i] = dot(screen, 6, DARK);
        lv_obj_set_pos(profile_dot[i], x0 + i * gap, 8);
    }

    lv_obj_t *bt = text(screen, &lv_font_montserrat_14, BLUE, LV_SYMBOL_BLUETOOTH);
    lv_obj_set_pos(bt, W - 32, 3);
    link_dot = dot(screen, 8, DARK);
    lv_obj_set_pos(link_dot, W - 16, 7);

    rect(screen, 6, 23, W - 12, 1, DARK);
}

static void gauge(lv_obj_t *screen, int g, int32_t cx, lv_color_t color, const char *side) {
    /* 270 degree ring, open at the bottom: from 135 deg clockwise to 405 deg. */
    for (int i = 0; i < GAUGE_DOTS; i++) {
        int32_t angle = 135 + i * 270 / (GAUGE_DOTS - 1);
        int32_t x = cx + GAUGE_RADIUS * lv_trigo_cos(angle) / LV_TRIGO_SIN_MAX;
        int32_t y = GAUGE_Y + GAUGE_RADIUS * lv_trigo_sin(angle) / LV_TRIGO_SIN_MAX;
        gauge_dot[g][i] = dot(screen, 5, DARK);
        lv_obj_set_pos(gauge_dot[g][i], x - 2, y - 2);
    }

    gauge_label[g] = text(screen, &lv_font_montserrat_20, WHITE, "--");
    lv_obj_align(gauge_label[g], LV_ALIGN_TOP_MID, cx - W / 2, GAUGE_Y - 16);

    lv_obj_t *tag = text(screen, &lv_font_montserrat_14, color, side);
    lv_obj_align(tag, LV_ALIGN_TOP_MID, cx - W / 2, GAUGE_Y + 20);
}

static void bottom_bar(lv_obj_t *screen) {
    const int32_t y = 150;
    rect(screen, 6, 143, W - 12, 1, DARK);
    rect(screen, W / 3, 148, 1, 20, DARK);
    rect(screen, 2 * W / 3, 148, 1, 20, DARK);

    bt_icon = text(screen, &lv_font_montserrat_14, BLUE, LV_SYMBOL_BLUETOOTH);
    lv_obj_set_pos(bt_icon, 22, y);
    bt_label = text(screen, &lv_font_montserrat_14, WHITE, "BT 1");
    lv_obj_set_pos(bt_label, 40, y);

    usb_icon = text(screen, &lv_font_montserrat_14, GREY, LV_SYMBOL_USB);
    lv_obj_set_pos(usb_icon, W / 3 + 24, y);
    usb_label = text(screen, &lv_font_montserrat_14, GREY, "USB");
    lv_obj_set_pos(usb_label, W / 3 + 46, y);

    lv_obj_t *layers = text(screen, &lv_font_montserrat_14, MINT, LV_SYMBOL_KEYBOARD);
    lv_obj_set_pos(layers, 2 * W / 3 + 12, y);
    layer_index_label = text(screen, &lv_font_montserrat_14, WHITE, "");
    lv_obj_set_pos(layer_index_label, 2 * W / 3 + 36, y);
}

lv_obj_t *zmk_display_status_screen() {
    lv_obj_t *screen = lv_obj_create(NULL);
    lv_obj_set_style_bg_color(screen, lv_color_hex(0x000000), LV_PART_MAIN);
    lv_obj_set_style_bg_opa(screen, LV_OPA_COVER, LV_PART_MAIN);
    lv_obj_set_style_pad_all(screen, 0, LV_PART_MAIN);
    lv_obj_remove_flag(screen, LV_OBJ_FLAG_SCROLLABLE);

    top_bar(screen);

    layer_name_label = text(screen, &lv_font_montserrat_28, WHITE, "");
    lv_obj_set_style_text_letter_space(layer_name_label, 6, LV_PART_MAIN);
    lv_obj_align(layer_name_label, LV_ALIGN_TOP_MID, 3, 27);
    rect(screen, W / 2 - 12, 60, 24, 3, MINT);

    gauge(screen, 0, 80, GREY, "L");
    gauge(screen, 1, W - 80, GREY, "R");

    bottom_bar(screen);

    kagu_layer_init();
    kagu_output_init();
    kagu_battery_init();

    return screen;
}
