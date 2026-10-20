// ROYUAN-based keyboards (Attack Shark K86, Epomaker TH80 Pro): one color
// for the whole keyboard plus the keyboard's own effects.
//
// Protocol from OpenRGB's RoyuanKeyboardController / EpomakerController
// (Alvaro Munoz, 2023). OpenChroma limits how often the color is sent:
// these keyboards take color changes through the same command that sets
// the lighting mode, which the firmware may store, so the app does not
// stream it at full frame rate.
//
// SPDX-License-Identifier: GPL-2.0-or-later

var SET_LED_PARAMS = 0x07;
var MODE_ALWAYS_ON = 0x01;
var DAZZLE_OFF = 0x07; // the color given
var DAZZLE_ON = 0x08;  // rainbow colors

// Checksum: distance to the next power of two of the payload sum, minus one.
function checksum(bytes) {
  var sum = 0;
  for (var i = 0; i < bytes.length; i++) sum += bytes[i];
  var p = 1;
  while (p < sum) p <<= 1;
  return (p - sum - 1) & 0xFF;
}

plugin({
  name: 'Teclado ROYUAN',
  vendor: 'ROYUAN',
  type: 'keyboard',
  devices: [
    { vid: 0x3151, pid: 0x4015, name: 'Attack Shark K86' },
    { vid: 0x3151, pid: 0x4010, name: 'Epomaker TH80 Pro' },
    { vid: 0x3151, pid: 0x4011, name: 'Epomaker TH80 Pro (sem fio)' }
  ],
  // Lighting goes through feature reports on interface 2.
  endpoint: function (endpoints) {
    for (var i = 0; i < endpoints.length; i++) {
      if (endpoints[i].interface === 2 && endpoints[i].featureLength >= 64) return i;
    }
    return -1;
  },
  zones: [{ name: 'Teclado', leds: 1 }],
  modes: [
    { id: 0x02, name: 'Respirar' },
    { id: 0x03, name: 'Arco-íris' },
    { id: 0x04, name: 'Deriva' },
    { id: 0x05, name: 'Ondas' },
    { id: 0x06, name: 'Estrelas' },
    { id: 0x07, name: 'Correnteza' },
    { id: 0x08, name: 'Ao digitar' },
    { id: 0x0A, name: 'Senoide' },
    { id: 0x0C, name: 'Flores' },
    { id: 0x0E, name: 'Laser' },
    { id: 0x10, name: 'Chuva' },
    { id: 0x11, name: 'Neve' },
    { id: 0x12, name: 'Meteoro' },
    { id: 0x00, name: 'Desligado' }
  ],
  settings: {
    rate: {
      label: 'Atualizações por segundo',
      type: 'number',
      min: 1,
      max: 15,
      default: 8,
      description: 'Menos atualizações poupam o teclado; mais deixam efeitos rápidos mais suaves.'
    }
  },
  fps: 30,

  start: function (dev) {
    this.color = [0, 0, 0];
    this.sentKey = '';
    this.sentAt = 0;
    return true;
  },

  send: function (dev, mode, dazzle, r, g, b) {
    var payload = [SET_LED_PARAMS, mode, 0x04, 0x04, dazzle, r, g, b];
    dev.sendFeature([0x00].concat(payload, [checksum(payload)]));
  },

  render: function (dev, colors) {
    var r = colors[0], g = colors[1], b = colors[2];
    var key = r + ',' + g + ',' + b;
    var now = Date.now();
    var rate = dev.setting('rate') || 8;
    if (key === this.sentKey || now - this.sentAt < 1000 / rate) return;
    this.sentKey = key;
    this.sentAt = now;
    this.send(dev, MODE_ALWAYS_ON, DAZZLE_OFF, r, g, b);
  },

  mode: function (dev, id) {
    this.sentKey = '';
    if (id === null) return; // the next frame sends the app's color
    this.send(dev, id, DAZZLE_ON, 0xFF, 0xFF, 0xFF);
  },

  stop: function (dev) {
    this.send(dev, MODE_ALWAYS_ON, DAZZLE_OFF, 0, 0, 0);
  }
});
