// ROYUAN-based keyboards (Attack Shark K86, Epomaker TH80 Pro).
//
// Protocol from OpenRGB's RoyuanKeyboardController / EpomakerController
// (Alvaro Munoz, 2023), plus what the Attack Shark app does with the K86
// (learned from the app and checked on the keyboard, 2026-10-23).
//
// One color for the whole keyboard goes live: the keyboard is put in its
// direct mode once and then takes colors through a short command that does
// not restart the lighting (the Attack Shark app's own screen-following mode
// works the same way). Older models take colors only through the command
// that sets the lighting mode, which restarts the lighting and may be stored,
// so it is rate limited.
//
// The K86 (firmware id 1168) also has:
// - three key-by-key pictures kept in the keyboard. They cannot change live,
//   so when the app's effect stops changing, its colors are written to
//   picture 3 and shown key by key; animated effects go as one color;
// - a 240x135 screen that keeps an image or an animation (RGB565, sent
//   column by column);
// - a clock, set when the plugin starts.
//
// SPDX-License-Identifier: GPL-2.0-or-later

var SET_LED_PARAMS = 0x07;
var SET_USERPIC = 0x0C;
var SET_DIRECT_COLOR = 0x0E;
var SCREEN_DATA = 0x25;
var SET_CLOCK = 0x28;
var GET_DEVICE_ID = 0x8F;
var SCREEN_START = 0xA5;

var MODE_ALWAYS_ON = 0x01;
var MODE_USERPIC = 0x0D;
var MODE_DIRECT = 0x15; // live color mode
var DAZZLE_OFF = 0x07; // the color given
var DAZZLE_ON = 0x08;  // rainbow colors

var K86_ID = 1168;
var APP_PICTURE = 2;     // picture 3 holds the app's key colors
var STILL_MS = 1500;     // an effect this long without change shows per key
var CLOCK_EVERY = 6 * 3600 * 1000;

// Models tested with the live color command, and its checksum: 'B' is the
// Attack Shark app's.
var LIVE_MODELS = { 0x4015: 'B' };

// The K86's keys: [picture slot, column, row] on a grid of half-key
// columns, from the keyboard's key matrix and the Attack Shark app's
// drawing of it.
var K86_GRID = { width: 37, height: 6 };
var K86_LEDS = [
  0, 1, 0, 1, 1, 1, 2, 1, 2, 3, 2, 3, 4, 2, 4, 5, 1, 5, 6, 5, 0, 7, 3, 1,
  8, 4, 2, 9, 4, 3, 12, 7, 0, 13, 5, 1, 14, 6, 2, 15, 6, 3, 16, 5, 4, 17, 3, 5,
  18, 9, 0, 19, 7, 1, 20, 8, 2, 21, 8, 3, 22, 7, 4, 23, 6, 5, 24, 11, 0, 25, 9, 1,
  26, 10, 2, 27, 10, 3, 28, 9, 4, 30, 14, 0, 31, 11, 1, 32, 12, 2, 33, 12, 3, 34, 11, 4,
  36, 16, 0, 37, 13, 1, 38, 14, 2, 39, 14, 3, 40, 13, 4, 41, 14, 5, 42, 18, 0, 43, 15, 1,
  44, 16, 2, 45, 16, 3, 46, 15, 4, 48, 20, 0, 49, 17, 1, 50, 18, 2, 51, 18, 3, 52, 17, 4,
  54, 23, 0, 55, 19, 1, 56, 20, 2, 57, 20, 3, 58, 19, 4, 59, 22, 5, 60, 25, 0, 61, 21, 1,
  62, 22, 2, 63, 22, 3, 64, 21, 4, 66, 27, 0, 67, 23, 1, 68, 24, 2, 69, 24, 3, 70, 23, 4,
  71, 27, 5, 72, 29, 0, 73, 25, 1, 74, 26, 2, 76, 27, 4, 77, 29, 5, 79, 28, 1, 80, 29, 2,
  81, 28, 3, 83, 32, 5, 84, 32, 1, 85, 32, 2, 86, 32, 3, 87, 36, 1, 88, 34, 4, 89, 34, 5,
  90, 34, 1, 91, 34, 2, 92, 34, 3, 93, 36, 2, 94, 36, 3, 95, 36, 5
];

// Speed and brightness ranges of these models (OpenRGB's EpomakerLegacy
// profile); 0 brightness turns the lights off, which "Off" already does.
var SPEED = { min: 0, max: 5, default: 4 };
var BRIGHTNESS = { min: 1, max: 4, default: 4 };

function effect(id, name) {
  return { id: id, name: name, speed: SPEED, brightness: BRIGHTNESS, colors: 1, random: true };
}

var EFFECTS = [
  effect(0x02, 'Breathing'),
  effect(0x03, 'Rainbow'),
  effect(0x04, 'Drift'),
  effect(0x05, 'Waves'),
  effect(0x06, 'Stars'),
  effect(0x07, 'Flow'),
  effect(0x08, 'Reactive'),
  effect(0x0A, 'Sine wave'),
  effect(0x0C, 'Flowers'),
  effect(0x0E, 'Laser'),
  effect(0x10, 'Rain'),
  effect(0x11, 'Snow'),
  effect(0x12, 'Meteor')
];

// OpenRGB's checksum for these keyboards: the distance from the sum to the
// next power of two, minus one.
function checksum(bytes) {
  var sum = 0;
  for (var i = 0; i < bytes.length; i++) sum += bytes[i];
  var p = 1;
  while (p < sum) p <<= 1;
  return (p - sum - 1) & 0xFF;
}

// The Attack Shark app's: 255 minus the sum's low byte. The two agree when
// the sum is 128 or more; below that only this one matches the K86.
function vendorChecksum(bytes) {
  var sum = 0;
  for (var i = 0; i < bytes.length; i++) sum += bytes[i];
  return (0xFF - (sum & 0xFF)) & 0xFF;
}

// A 64-byte command with the checksum of its first [n] bytes at [n].
function command(dev, bytes, n) {
  n = n || 7;
  var p = bytes.slice(0, 64);
  while (p.length < 64) p.push(0);
  p[n] = vendorChecksum(p.slice(0, n));
  return dev.sendFeature([0x00].concat(p));
}

// The answer to the last command: [report ID, command, ...].
function answer(dev) {
  return dev.getFeature(0, 65);
}

function rgb565(r, g, b) {
  return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3);
}

plugin({
  name: 'ROYUAN keyboard',
  vendor: 'ROYUAN',
  type: 'keyboard',
  devices: [
    { vid: 0x3151, pid: 0x4015, name: 'Attack Shark K86' },
    { vid: 0x3151, pid: 0x4010, name: 'Epomaker TH80 Pro' },
    { vid: 0x3151, pid: 0x4011, name: 'Epomaker TH80 Pro' }
  ],
  // Lighting goes through feature reports on interface 2.
  endpoint: function (endpoints) {
    for (var i = 0; i < endpoints.length; i++) {
      if (endpoints[i].interface === 2 && endpoints[i].featureLength >= 64) return i;
    }
    return -1;
  },
  zones: function (dev) {
    if (!this.k86) return [{ name: 'Keyboard', leds: 1 }];
    var map = [];
    for (var i = 0; i < K86_GRID.width * K86_GRID.height; i++) map.push(-1);
    for (var k = 0; k < K86_LEDS.length; k += 3) {
      map[K86_LEDS[k + 2] * K86_GRID.width + K86_LEDS[k + 1]] = k / 3;
    }
    return [{ name: 'Keyboard', width: K86_GRID.width, height: K86_GRID.height, map: map }];
  },
  modes: function (dev) {
    var list = EFFECTS.slice();
    if (this.k86) {
      list.push({ id: 'picture1', name: 'Keyboard picture 1' });
      list.push({ id: 'picture2', name: 'Keyboard picture 2' });
      list.push({ id: 'picture3', name: 'Keyboard picture 3' });
    }
    list.push({ id: 0x00, name: 'Off' });
    return list;
  },
  screen: function (dev) {
    return this.k86 ? { width: 240, height: 135, maxFrames: 100 } : null;
  },
  settings: {
    live: {
      label: 'Color delivery',
      type: 'combobox',
      values: ['Auto', 'Live A', 'Live B', 'Compatible'],
      default: 'Auto',
      description: "Live changes the color without flicker; Compatible works on every model but flickers with animated effects. Auto uses Live on tested models. If the keyboard doesn't change color in Live, use Compatible."
    },
    perKey: {
      label: 'Per-key colors',
      type: 'combobox',
      values: ['When the effect stops', 'Never'],
      default: 'When the effect stops',
      description: "The K86 doesn't take live per-key colors: moving effects go out as a single color. When the effect holds still, each key's color is saved to keyboard picture 3 and shows key by key."
    },
    rate: {
      label: 'Updates per second (Compatible)',
      type: 'number',
      min: 1,
      max: 30,
      default: 8,
      description: 'Compatible mode only: fewer updates spare the keyboard; more make fast effects smoother.'
    }
  },
  fps: 30,
  pollMs: 500,

  start: function (dev) {
    this.sentKey = '';
    this.sentAt = 0;
    this.directOn = false;
    this.frame = null;      // the app's last colors
    this.frameKey = '';
    this.changedAt = 0;
    this.pictureKey = '';   // what picture 3 holds
    this.pictureOn = false; // the keyboard shows picture 3
    this.clockAt = 0;
    this.k86 = this.deviceId(dev) === K86_ID;
    if (this.k86) this.setClock(dev);
    return true;
  },

  // The firmware's model id (several keyboards share one USB id).
  deviceId: function (dev) {
    if (dev.info.pid !== 0x4015) return 0;
    for (var i = 0; i < 3; i++) {
      command(dev, [GET_DEVICE_ID]);
      var r = answer(dev);
      if (r.length > 5 && r[1] === GET_DEVICE_ID) {
        return (r[2] | (r[3] << 8) | (r[4] << 16) | (r[5] << 24)) >>> 0;
      }
    }
    return 0;
  },

  setClock: function (dev) {
    var t = dev.localTime();
    if (!t || t.length < 6) return;
    command(dev, [SET_CLOCK, 0, 0, 0, 0, 0, 0, 0, t[0] >> 8, t[0] & 0xFF, t[1], t[2],
      t[3], t[4], t[5]]);
    this.clockAt = Date.now();
  },

  // Live color: the keyboard is put in its direct mode once, then each
  // color goes in a short command that does not restart the lighting.
  sendDirect: function (dev, variant, r, g, b) {
    if (!this.directOn) {
      this.send(dev, MODE_DIRECT, DAZZLE_OFF, r, g, b);
      this.directOn = true;
    }
    var payload = [SET_DIRECT_COLOR, r, g, b, 0, 0, 0];
    var sum = variant === 'B' ? vendorChecksum(payload) : checksum(payload);
    dev.sendFeature([0x00].concat(payload, [sum]));
  },

  settingChanged: function (dev, name) {
    // Switching how colors are sent starts over with the next frame.
    this.sentKey = '';
    this.directOn = false;
    this.pictureOn = false;
  },

  send: function (dev, mode, dazzle, r, g, b, speed, brightness) {
    var payload = [
      SET_LED_PARAMS, mode,
      speed === undefined ? SPEED.default : speed,
      brightness === undefined ? BRIGHTNESS.default : brightness,
      dazzle, r, g, b
    ];
    var sum = dev.info.pid === 0x4015 ? vendorChecksum(payload) : checksum(payload);
    dev.sendFeature([0x00].concat(payload, [sum]));
  },

  // 'A' or 'B' for the live command, or null for the mode command. Accepts
  // the names older versions saved ("Automático", "Ao vivo A", "Direto A
  // (teste)", "Padrão").
  liveVariant: function (dev) {
    var live = dev.setting('live') || 'Auto';
    if (live === 'Auto' || live === 'Automático') return LIVE_MODELS[dev.info.pid] || null;
    if (live.indexOf('Live') === 0 || live.indexOf('Ao vivo') === 0 || live.indexOf('Direto') === 0) {
      return live.indexOf(' B') > 0 ? 'B' : 'A';
    }
    return null;
  },

  render: function (dev, colors) {
    var now = Date.now();
    var key = colors.join(',');
    if (key !== this.frameKey) {
      this.frame = colors;
      this.frameKey = key;
      this.changedAt = now;
    }
    // Showing picture 3 while the effect stays put.
    if (this.pictureOn) {
      if (this.frameKey === this.pictureKey) return;
      this.pictureOn = false;
      this.directOn = false;
      this.sentKey = '';
    }
    // The one color the keyboard takes live: the average of its middle
    // third, so an effect that moves across it (a rainbow) passes through
    // its colors instead of averaging to grey.
    var perKey = colors.length === K86_LEDS.length;
    var n = 0, r = 0, g = 0, b = 0;
    for (var i = 0; i < colors.length; i += 3) {
      if (perKey) {
        var col = K86_LEDS[i + 1];
        if (col < K86_GRID.width / 3 || col > K86_GRID.width * 2 / 3) continue;
      }
      r += colors[i]; g += colors[i + 1]; b += colors[i + 2];
      n++;
    }
    n = Math.max(1, n);
    r = Math.round(r / n); g = Math.round(g / n); b = Math.round(b / n);
    var one = r + ',' + g + ',' + b;
    if (one === this.sentKey) return;
    var variant = this.liveVariant(dev);
    // The mode command restarts the lighting and may be stored: limited.
    if (!variant && now - this.sentAt < 1000 / (dev.setting('rate') || 8)) return;
    this.sentKey = one;
    this.sentAt = now;
    if (variant) {
      this.sendDirect(dev, variant, r, g, b);
    } else {
      this.send(dev, MODE_ALWAYS_ON, DAZZLE_OFF, r, g, b);
    }
  },

  // A still frame with different colors per key goes to picture 3, written
  // only when it differs from what the picture holds.
  poll: function (dev) {
    if (!this.k86) return;
    var now = Date.now();
    if (now - this.clockAt > CLOCK_EVERY) this.setClock(dev);
    var c = this.frame;
    if (!c || this.pictureOn || c.length < 6) return;
    var perKeySetting = dev.setting('perKey');
    if (perKeySetting === 'Never' || perKeySetting === 'Nunca') return;
    if (now - this.changedAt < STILL_MS) return;
    var same = true;
    for (var i = 3; i < c.length && same; i++) same = c[i] === c[i % 3];
    if (same) return; // one color: the live command already shows it
    // The colors go first, so switching to the picture shows them at once
    // instead of the old picture.
    if (this.frameKey !== this.pictureKey) {
      var pic = [];
      for (var p = 0; p < 7 * 56; p++) pic.push(0);
      for (var k = 0; k < K86_LEDS.length; k += 3) {
        var slot = K86_LEDS[k], led = k / 3;
        pic[slot * 3] = c[led * 3];
        pic[slot * 3 + 1] = c[led * 3 + 1];
        pic[slot * 3 + 2] = c[led * 3 + 2];
      }
      for (var part = 0; part < 7; part++) {
        command(dev, [SET_USERPIC, 0, 0x80, 0x01, part, 0, 0, 0]
          .concat(pic.slice(part * 56, part * 56 + 56)));
      }
      this.pictureKey = this.frameKey;
    }
    this.send(dev, MODE_USERPIC, APP_PICTURE, 0xFF, 0xFF, 0xFF);
    this.pictureOn = true;
    this.directOn = false;
  },

  mode: function (dev, id, options) {
    this.sentKey = '';
    this.directOn = false;
    this.pictureOn = false;
    if (id === null) return; // the next frame sends the app's color
    if (typeof id === 'string' && id.indexOf('picture') === 0) {
      this.send(dev, MODE_USERPIC, parseInt(id.slice(7), 10) - 1, 0xFF, 0xFF, 0xFF);
      return;
    }
    var c = (options.colors && options.colors[0]) || [0xFF, 0xFF, 0xFF];
    var dazzle = options.random === false ? DAZZLE_OFF : DAZZLE_ON;
    this.send(dev, id, dazzle, c[0], c[1], c[2], options.speed, options.brightness);
  },

  // The screen keeps what it gets: an image (one frame) or an animation.
  showImage: function (dev, image) {
    if (!this.k86) return false;
    var w = image.width, h = image.height, n = image.frames;
    var length = w * h * 2;
    var start = [SCREEN_START, 0, n, Math.max(1, Math.min(255, image.delays[0] || 100)),
      length & 0xFF, (length >> 8) & 0xFF, 0, 0,
      0, 0, w & 0xFF, h & 0xFF, 0, 0, w >> 8, h >> 8,
      (length >> 16) & 0xFF, (length >> 24) & 0xFF, 0];
    var ready = false;
    for (var tries = 0; tries < 10 && !ready; tries++) {
      command(dev, start);
      dev.sleep(100);
      var r = answer(dev);
      ready = r.length > 2 && r[1] === SCREEN_START && r[2] === 1;
    }
    if (!ready) return false;
    var chunks = Math.ceil(length / 56);
    for (var f = 0; f < n; f++) {
      var px = dev.frame(f);
      var delay = Math.max(1, Math.min(255, image.delays[f] || 100));
      // Column by column, two bytes per pixel, high byte first.
      var data = [];
      for (var x = 0; x < w; x++) {
        for (var y = 0; y < h; y++) {
          var i = (y * w + x) * 3;
          var v = rgb565(px[i], px[i + 1], px[i + 2]);
          data.push(v >> 8, v & 0xFF);
        }
      }
      for (var c = 0; c < chunks; c++) {
        var part = data.slice(c * 56, c * 56 + 56);
        var cmd = [SCREEN_DATA, f, n, delay, c & 0xFF, c >> 8, part.length, 0];
        if (command(dev, cmd.concat(part)) < 0) return false;
        if (c % 64 === 0) dev.progress((f + c / chunks) / n);
      }
    }
    dev.progress(1);
    return true;
  },

  stop: function (dev) {
    this.send(dev, MODE_ALWAYS_ON, DAZZLE_OFF, 0, 0, 0);
  }
});
