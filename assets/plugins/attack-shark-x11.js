// Attack Shark X11: the mouse's light and its battery, on the cable
// (1D57:FA55) or through the 2.4 GHz receiver (1D57:FA60).
//
// Protocol learned from the vendor app's handling of this model and checked
// on the device (2026-10-23). Lighting is feature report 0x05 on the
// configuration collection; the same report carries the sleep timers and the
// button debounce, so those go along with every color. The mouse reports
// its battery about every 2 s as input report 0x03 on another collection:
// 55 40 <state> <percent>, but not while it is busy acknowledging writes
// (55 50 00 05), so while the app streams colors the plugin pauses them for
// a moment once a minute to hear the battery. On the cable the charge LED
// takes over the light.
//
// SPDX-License-Identifier: GPL-2.0-or-later

var CONFIG = { interface: 2, usagePage: 0x0B };
var EVENTS = { interface: 2, usagePage: 0x0A };
var WIRED_PID = 0xFA55;

var OFF = 0, STATIC = 1, BREATHING = 2, NEON = 3, COLOR_BREATHING = 4;
var SPEED = { min: 1, max: 8, default: 6 };
var BATTERY_EVERY = 60000; // ms between battery checks while streaming
var QUIET = 3000;          // ms without writes for a battery report
var BRIGHTNESS = { min: 1, max: 8, default: 8 };

plugin({
  name: 'Attack Shark X11',
  vendor: 'Attack Shark',
  type: 'mouse',
  devices: [
    { vid: 0x1D57, pid: 0xFA55, name: 'Attack Shark X11' },
    { vid: 0x1D57, pid: 0xFA60, name: 'Attack Shark X11' }
  ],
  endpoint: CONFIG,
  zones: [{ name: 'Mouse', leds: 1 }],
  modes: [
    { id: STATIC, name: 'Static', brightness: BRIGHTNESS, colors: 1 },
    { id: BREATHING, name: 'Breathing', speed: SPEED, colors: 1 },
    { id: NEON, name: 'Neon', speed: SPEED },
    { id: COLOR_BREATHING, name: 'Color breathing', speed: SPEED },
    { id: OFF, name: 'Off' }
  ],
  settings: {
    rate: {
      label: 'Updates per second',
      type: 'number',
      min: 1,
      max: 15,
      default: 4,
      description: 'Each color goes out as a settings command, which the mouse may store; fewer per second spare the mouse and its battery.'
    },
    lightOff: {
      label: 'Light-off delay',
      type: 'number',
      min: 1,
      max: 60,
      default: 1,
      description: 'On the same scale as the Attack Shark app (default 1).'
    },
    sleep: {
      label: 'Sleep delay',
      type: 'number',
      min: 1,
      max: 60,
      default: 10,
      description: 'On the same scale as the Attack Shark app (default 10).'
    },
    debounce: {
      label: 'Button debounce time (ms)',
      type: 'number',
      min: 2,
      max: 25,
      default: 4,
      description: 'Sent along with every color. Values that are too low can cause double clicks.'
    }
  },
  fps: 30,
  pollMs: 2000,

  start: function (dev) {
    this.sentKey = '';
    this.sentAt = 0;
    this.batteryAt = 0;
    this.quietUntil = 0;
    return true;
  },

  // The whole configuration report: mode, speed, brightness, color and the
  // power settings, with the 16-bit sum of bytes 3 to 10.
  send: function (dev, mode, speed, brightness, r, g, b) {
    var sleep = dev.setting('sleep') || 10;
    var level = mode === STATIC ? brightness : 8;
    var p = [
      0x05, 0x0F, 0x01,
      mode << 4,
      (sleep & 0xF0) | (9 - speed),
      ((sleep << 4) & 0xF0) | level,
      r, g, b,
      dev.setting('lightOff') || 1,
      dev.setting('debounce') || 4
    ];
    var sum = 0;
    for (var i = 3; i < p.length; i++) sum += p[i];
    p.push((sum >> 8) & 0xFF, sum & 0xFF, 0, 0);
    dev.sendFeature(p);
  },

  render: function (dev, colors) {
    var key = colors[0] + ',' + colors[1] + ',' + colors[2];
    var now = Date.now();
    var rate = dev.setting('rate') || 4;
    if (key === this.sentKey || now - this.sentAt < 1000 / rate) return;
    if (now < this.quietUntil) return; // listening for the battery
    this.sentKey = key;
    this.sentAt = now;
    this.send(dev, STATIC, SPEED.default, BRIGHTNESS.max, colors[0], colors[1], colors[2]);
  },

  mode: function (dev, id, options) {
    this.sentKey = '';
    if (id === null) return; // the next frame sends the app's color
    var c = (options.colors && options.colors[0]) || [0xFF, 0xFF, 0xFF];
    this.send(dev, id, options.speed || SPEED.default,
      options.brightness || BRIGHTNESS.max, c[0], c[1], c[2]);
  },

  settingChanged: function (dev) {
    this.sentKey = ''; // the power settings go with the next color
  },

  // Battery events queue up between polls; the newest one counts. On the
  // cable the mouse charges and the app shows no battery: none means wired.
  poll: function (dev) {
    if (dev.info.pid === WIRED_PID) return;
    dev.useEndpoint(EVENTS);
    var last = null;
    for (var i = 0; i < 32; i++) {
      var r = dev.read(8, 0);
      if (!r.length) break;
      var o = r[0] === 0x03 ? 1 : 0; // with or without the report ID
      if (r[o] === 0x55 && r[o + 1] === 0x40) last = [r[o + 2], r[o + 3]];
    }
    dev.useEndpoint(CONFIG);
    var now = Date.now();
    if (!last || last[1] > 100) {
      if (now - this.batteryAt > BATTERY_EVERY && now > this.quietUntil) {
        this.quietUntil = now + QUIET;
      }
      return;
    }
    this.batteryAt = now;
    this.quietUntil = 0;
    // Through the receiver state 3 means charging (on the dock).
    dev.setBattery(last[1], last[0] === 3);
  }
});
