/*
 * Kagu status screen for the 1.47" 320x172 ST7789 on the left half:
 * Pip-Boy green on black, with the active layer name in large type,
 * the output (USB or BT profile) and both halves' batteries.
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

#define GREEN lv_color_hex(0x1bff80)
#define GREEN_DIM lv_color_hex(0x0b5c30)
#define BLACK lv_color_hex(0x000000)

static lv_obj_t *layer_label;
static lv_obj_t *output_label;
static lv_obj_t *battery_bar[2];
static lv_obj_t *battery_label[2];

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
    char text[16];
    if (state.name == NULL || state.name[0] == '\0') {
        snprintf(text, sizeof(text), "LAYER %d", state.index);
    } else {
        int i = 0;
        for (; state.name[i] != '\0' && i < sizeof(text) - 1; i++) {
            char c = state.name[i];
            text[i] = (c >= 'a' && c <= 'z') ? c - 'a' + 'A' : c;
        }
        text[i] = '\0';
    }
    lv_label_set_text(layer_label, text);
}

ZMK_DISPLAY_WIDGET_LISTENER(kagu_layer, struct layer_state, layer_update_cb, layer_get_state)
ZMK_SUBSCRIPTION(kagu_layer, zmk_layer_state_changed);

/* Output: USB, or the BLE profile and whether it is connected */

struct output_state {
    struct zmk_endpoint_instance selected;
    enum zmk_transport preferred;
    bool connected;
    bool bonded;
};

static struct output_state output_get_state(const zmk_event_t *eh) {
    return (struct output_state){
        .selected = zmk_endpoint_get_selected(),
        .preferred = zmk_endpoint_get_preferred_transport(),
        .connected = zmk_ble_active_profile_is_connected(),
        .bonded = !zmk_ble_active_profile_is_open(),
    };
}

static void output_update_cb(struct output_state state) {
    char text[24];
    enum zmk_transport transport = state.selected.transport;
    if (transport == ZMK_TRANSPORT_NONE) {
        transport = state.preferred;
    }

    switch (transport) {
    case ZMK_TRANSPORT_USB:
        snprintf(text, sizeof(text), "USB");
        break;
    case ZMK_TRANSPORT_BLE:
        snprintf(text, sizeof(text), "BT %d %s", state.selected.ble.profile_index + 1,
                 !state.bonded ? "PAIR" : (state.connected ? "OK" : "--"));
        break;
    default:
        snprintf(text, sizeof(text), "NO LINK");
        break;
    }
    lv_label_set_text(output_label, text);
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
    for (int i = 0; i < 2; i++) {
        lv_bar_set_value(battery_bar[i], state.level[i], LV_ANIM_OFF);
        if (state.level[i] == 0) {
            lv_label_set_text(battery_label[i], "--");
        } else {
            lv_label_set_text_fmt(battery_label[i], "%d%%", state.level[i]);
        }
    }
}

ZMK_DISPLAY_WIDGET_LISTENER(kagu_battery, struct battery_state, battery_update_cb,
                            battery_get_state)
ZMK_SUBSCRIPTION(kagu_battery, zmk_battery_state_changed);
ZMK_SUBSCRIPTION(kagu_battery, zmk_peripheral_battery_state_changed);

/* Layout */

static lv_obj_t *small_label(lv_obj_t *parent, const char *text, lv_color_t color) {
    lv_obj_t *label = lv_label_create(parent);
    lv_obj_set_style_text_font(label, &lv_font_unscii_16, LV_PART_MAIN);
    lv_obj_set_style_text_color(label, color, LV_PART_MAIN);
    lv_label_set_text(label, text);
    return label;
}

static lv_obj_t *divider(lv_obj_t *parent, int32_t y) {
    lv_obj_t *line = lv_obj_create(parent);
    lv_obj_remove_style_all(line);
    lv_obj_set_size(line, LV_PCT(100), 2);
    lv_obj_set_style_bg_color(line, GREEN_DIM, LV_PART_MAIN);
    lv_obj_set_style_bg_opa(line, LV_OPA_COVER, LV_PART_MAIN);
    lv_obj_align(line, LV_ALIGN_TOP_MID, 0, y);
    return line;
}

static void battery_row(lv_obj_t *parent, int i, const char *name, int32_t x) {
    lv_obj_t *tag = small_label(parent, name, GREEN);
    lv_obj_align(tag, LV_ALIGN_BOTTOM_LEFT, x, -10);

    lv_obj_t *bar = lv_bar_create(parent);
    lv_obj_remove_style_all(bar);
    lv_obj_set_size(bar, 72, 14);
    lv_obj_set_style_border_color(bar, GREEN, LV_PART_MAIN);
    lv_obj_set_style_border_width(bar, 2, LV_PART_MAIN);
    lv_obj_set_style_pad_all(bar, 3, LV_PART_MAIN);
    lv_obj_set_style_bg_color(bar, GREEN, LV_PART_INDICATOR);
    lv_obj_set_style_bg_opa(bar, LV_OPA_COVER, LV_PART_INDICATOR);
    lv_bar_set_range(bar, 0, 100);
    lv_obj_align(bar, LV_ALIGN_BOTTOM_LEFT, x + 20, -11);
    battery_bar[i] = bar;

    battery_label[i] = small_label(parent, "--", GREEN);
    lv_obj_align(battery_label[i], LV_ALIGN_BOTTOM_LEFT, x + 98, -10);
}

lv_obj_t *zmk_display_status_screen() {
    lv_obj_t *screen = lv_obj_create(NULL);
    lv_obj_set_style_bg_color(screen, BLACK, LV_PART_MAIN);
    lv_obj_set_style_bg_opa(screen, LV_OPA_COVER, LV_PART_MAIN);
    lv_obj_set_style_pad_all(screen, 8, LV_PART_MAIN);

    lv_obj_t *title = small_label(screen, "KAGU", GREEN);
    lv_obj_align(title, LV_ALIGN_TOP_LEFT, 0, 0);

    output_label = small_label(screen, "", GREEN);
    lv_obj_align(output_label, LV_ALIGN_TOP_RIGHT, 0, 0);

    divider(screen, 22);

    lv_obj_t *caption = small_label(screen, "LAYER", GREEN_DIM);
    lv_obj_align(caption, LV_ALIGN_TOP_MID, 0, 34);

    layer_label = lv_label_create(screen);
    lv_obj_set_style_text_font(layer_label, &lv_font_montserrat_40, LV_PART_MAIN);
    lv_obj_set_style_text_color(layer_label, GREEN, LV_PART_MAIN);
    lv_obj_align(layer_label, LV_ALIGN_CENTER, 0, 6);

    divider(screen, 118);

    battery_row(screen, 0, "L", 0);
    battery_row(screen, 1, "R", 152);

    kagu_layer_init();
    kagu_output_init();
    kagu_battery_init();

    return screen;
}
