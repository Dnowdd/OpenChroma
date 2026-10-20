// Sony DualShock 4: light bar and battery.
//
// Light bar reports from OpenRGB's SonyDS4Controller (Pol Rius, 2020);
// battery layout as in the Linux hid-sony driver. OpenChroma adds the
// battery and charging state.
//
// SPDX-License-Identifier: GPL-2.0-or-later

var CRC_TABLE = (function () {
  var t = [];
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) c = c & 1 ? 0xEDB88320 ^ (c >>> 1) : c >>> 1;
    t.push(c >>> 0);
  }
  return t;
})();

function crc32(bytes) {
  var c = 0xFFFFFFFF;
  for (var i = 0; i < bytes.length; i++) c = CRC_TABLE[(c ^ bytes[i]) & 0xFF] ^ (c >>> 8);
  return (c ^ 0xFFFFFFFF) >>> 0;
}

plugin({
  name: 'Sony DualShock 4',
  vendor: 'Sony',
  type: 'gamepad',
  devices: [
    { vid: 0x054C, pid: 0x05C4, name: 'DualShock 4' },
    { vid: 0x054C, pid: 0x09CC, name: 'DualShock 4' },
    { vid: 0x054C, pid: 0x0BA0, name: 'DualShock 4 (adaptador sem fio)' }
  ],
  // The gamepad collection takes the light bar report.
  endpoint: function (endpoints) {
    for (var i = 0; i < endpoints.length; i++) {
      if (endpoints[i].usagePage === 0x01 && endpoints[i].usage === 0x05) return i;
    }
    return endpoints.length ? 0 : -1;
  },
  zones: [{ name: 'Barra de luz', leds: 1 }],
  fps: 30,
  pollMs: 2000,

  start: function (dev) {
    this.last = '';
    // Over Bluetooth the controller sends report 0x11 instead of 0x01.
    this.bluetooth = false;
    dev.clearInput();
    for (var i = 0; i < 5; i++) {
      var r = dev.read(78, 50);
      if (r[0] === 0x11) { this.bluetooth = true; break; }
      if (r[0] === 0x01) break;
    }
    return true;
  },

  send: function (dev, r, g, b) {
    if (!this.bluetooth) {
      dev.write([0x05, 0x07, 0x00, 0x00, 0x00, 0x00, r, g, b, 0x00, 0x00]);
      return;
    }
    // Bluetooth output report 0x11, signed with CRC-32 over 0xA2 + report.
    var report = [0x11, 0xC0, 0x00, 0x07, 0x00, 0x00, 0x00, 0x00, r, g, b];
    while (report.length < 74) report.push(0);
    var crc = crc32([0xA2].concat(report));
    report.push(crc & 0xFF, (crc >>> 8) & 0xFF, (crc >>> 16) & 0xFF, (crc >>> 24) & 0xFF);
    dev.write(report);
  },

  render: function (dev, colors) {
    var key = colors[0] + ',' + colors[1] + ',' + colors[2];
    if (key === this.last) return;
    this.last = key;
    this.send(dev, colors[0], colors[1], colors[2]);
  },

  poll: function (dev) {
    dev.clearInput();
    var r = dev.read(78, 100);
    // Battery nibble: level 0-10 (11 = full), bit 4 = cable plugged in.
    var at = this.bluetooth ? (r[0] === 0x11 ? 32 : -1) : (r[0] === 0x01 ? 30 : -1);
    if (at < 0 || r.length <= at) return;
    var level = r[at] & 0x0F, cable = (r[at] >> 4) & 0x01;
    dev.setBattery(Math.min(level, 10) * 10, cable === 1 && level <= 10);
  },

  stop: function (dev) {
    this.send(dev, 0, 0, 0);
  }
});
