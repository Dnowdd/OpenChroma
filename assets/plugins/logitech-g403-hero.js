// Logitech G403 HERO: DPI indicator and logo.
//
// HID++ lighting commands from OpenRGB's LogitechGLightsyncController
// (TheRogueZeta, 2021). The mouse is put in its no-save mode while the app
// drives it, so frame-by-frame colors are not written to its memory.
//
// SPDX-License-Identifier: GPL-2.0-or-later

var DEVICE = 0xFF;   // wired HID++ device index
var FEATURE = 0x0E;  // lighting feature index on this mouse
var SET_ZONE = 0x3A; // function: set zone effect

var STATIC = 0x01, CYCLE = 0x02, BREATHING = 0x03;
// Effect speed in tenths of a second per cycle (slowest to fastest, as in
// OpenRGB) and brightness in percent.
var SPEED = { min: 200, max: 10, default: 50 };
var BRIGHTNESS = { min: 1, max: 100, default: 100 };

var SHORT = { interface: 1, usagePage: 0xFF00, usage: 0x01 };
var LONG = { interface: 1, usagePage: 0xFF00, usage: 0x02 };

plugin({
  name: 'Logitech G403 HERO',
  vendor: 'Logitech',
  type: 'mouse',
  devices: [{ vid: 0x046D, pid: 0xC08F, name: 'Logitech G403 HERO' }],
  endpoint: LONG,
  zones: [
    { name: 'DPI', leds: 1 },
    { name: 'Logo', leds: 1 }
  ],
  modes: [
    { id: 'cycle', name: 'Rainbow', speed: SPEED, brightness: BRIGHTNESS },
    { id: 'breathing', name: 'Breathing', speed: SPEED, brightness: BRIGHTNESS, colors: 1 },
    { id: 'off', name: 'Off' }
  ],
  fps: 30,

  // HID++ "save to memory" switch: on = colors persist, off = live only.
  setLive: function (dev, live) {
    dev.useEndpoint(SHORT);
    dev.write([0x10, DEVICE, FEATURE, 0x8A, live ? 0x01 : 0x00, live ? 0x01 : 0x00, 0x00]);
    dev.useEndpoint(LONG);
    dev.read(20, 50);
  },

  zone: function (dev, zone, effect, r, g, b, speed, brightness) {
    var ms = (speed || SPEED.default) * 100;
    var level = brightness || BRIGHTNESS.default;
    var p = [0x11, DEVICE, FEATURE, SET_ZONE, zone, effect, r, g, b, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    if (effect === STATIC) p[0x09] = 0x02;
    if (effect === CYCLE) { p[0x0B] = ms >> 8; p[0x0C] = ms & 0xFF; p[0x0D] = level; }
    if (effect === BREATHING) { p[0x09] = ms >> 8; p[0x0A] = ms & 0xFF; p[0x0C] = level; }
    dev.write(p);
    dev.read(20, 20);
  },

  start: function (dev) {
    this.sent = ['', ''];
    this.color = [255, 255, 255];
    this.setLive(dev, true);
    return true;
  },

  render: function (dev, colors) {
    for (var z = 0; z < 2; z++) {
      var r = colors[z * 3], g = colors[z * 3 + 1], b = colors[z * 3 + 2];
      var key = r + ',' + g + ',' + b;
      if (key === this.sent[z]) continue;
      this.sent[z] = key;
      this.color = [r, g, b];
      this.zone(dev, z, STATIC, r, g, b);
    }
  },

  mode: function (dev, id, options) {
    this.sent = ['', ''];
    if (id === null) {
      this.setLive(dev, true);
      return;
    }
    // Hardware effects run on their own and may be saved.
    this.setLive(dev, false);
    var effect = id === 'cycle' ? CYCLE : id === 'breathing' ? BREATHING : 0x00;
    var c = (options.colors && options.colors[0]) || this.color;
    for (var z = 0; z < 2; z++) this.zone(dev, z, effect, c[0], c[1], c[2], options.speed, options.brightness);
  },

  // Back to the lighting saved in the mouse.
  stop: function (dev) {
    this.setLive(dev, false);
  }
});
