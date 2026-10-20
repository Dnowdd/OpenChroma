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
var SPEED = 50 * 100; // ms per cycle, OpenRGB's "normal"

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
    { id: 'cycle', name: 'Arco-íris' },
    { id: 'breathing', name: 'Respirar' },
    { id: 'off', name: 'Desligado' }
  ],
  fps: 30,

  // HID++ "save to memory" switch: on = colors persist, off = live only.
  setLive: function (dev, live) {
    dev.useEndpoint(SHORT);
    dev.write([0x10, DEVICE, FEATURE, 0x8A, live ? 0x01 : 0x00, live ? 0x01 : 0x00, 0x00]);
    dev.useEndpoint(LONG);
    dev.read(20, 50);
  },

  zone: function (dev, zone, effect, r, g, b) {
    var p = [0x11, DEVICE, FEATURE, SET_ZONE, zone, effect, r, g, b, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    if (effect === STATIC) p[0x09] = 0x02;
    if (effect === CYCLE) { p[0x0B] = SPEED >> 8; p[0x0C] = SPEED & 0xFF; p[0x0D] = 100; }
    if (effect === BREATHING) { p[0x09] = SPEED >> 8; p[0x0A] = SPEED & 0xFF; p[0x0C] = 100; }
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

  mode: function (dev, id) {
    this.sent = ['', ''];
    if (id === null) {
      this.setLive(dev, true);
      return;
    }
    // Hardware effects run on their own and may be saved.
    this.setLive(dev, false);
    var effect = id === 'cycle' ? CYCLE : id === 'breathing' ? BREATHING : 0x00;
    for (var z = 0; z < 2; z++) this.zone(dev, z, effect, this.color[0], this.color[1], this.color[2]);
  },

  // Back to the lighting saved in the mouse.
  stop: function (dev) {
    this.setLive(dev, false);
  }
});
