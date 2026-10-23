// ROYUAN-based keyboards (Attack Shark K86, Epomaker TH80 Pro): one color
// for the whole keyboard plus the keyboard's own effects.
//
// Protocol from OpenRGB's RoyuanKeyboardController / EpomakerController
// (Alvaro Munoz, 2023). OpenChroma limits how often the color is sent:
// these keyboards take color changes through the same command that sets
// the lighting mode, which the firmware may store and which restarts the
// lighting (animated effects blink), so the app does not stream it at full
// frame rate. Models where the live color command of sibling models is known
// to work (the Attack Shark K86, tested 2026-10-23) use that instead: the
// keyboard goes to its direct mode once and then takes colors at frame rate,
// without blinking.
//
// SPDX-License-Identifier: GPL-2.0-or-later

var SET_LED_PARAMS = 0x07;
var SET_DIRECT_COLOR = 0x0E;
var MODE_ALWAYS_ON = 0x01;
var MODE_DIRECT = 0x15; // live color mode on sibling models (GK68HE Pro)
var DAZZLE_OFF = 0x07; // the color given
var DAZZLE_ON = 0x08;  // rainbow colors

// Models tested with the live color command and its checksum variant.
var LIVE_MODELS = { 0x4015: 'A' };

// Checksum of this keyboard family: distance to the next power of two of
// the payload sum, minus one. Some models use a ones' complement instead.
function onesComplement(bytes) {
  var sum = 0;
  for (var i = 0; i < bytes.length; i++) sum += bytes[i];
  return (0xFF - (sum & 0xFF)) & 0xFF;
}

// Speed and brightness ranges of these models (OpenRGB's EpomakerLegacy
// profile); 0 brightness turns the lights off, which "Desligado" already does.
var SPEED = { min: 0, max: 5, default: 4 };
var BRIGHTNESS = { min: 1, max: 4, default: 4 };

function effect(id, name) {
  return { id: id, name: name, speed: SPEED, brightness: BRIGHTNESS, colors: 1, random: true };
}

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
    { vid: 0x3151, pid: 0x4011, name: 'Epomaker TH80 Pro' }
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
    effect(0x02, 'Respirar'),
    effect(0x03, 'Arco-íris'),
    effect(0x04, 'Deriva'),
    effect(0x05, 'Ondas'),
    effect(0x06, 'Estrelas'),
    effect(0x07, 'Correnteza'),
    effect(0x08, 'Ao digitar'),
    effect(0x0A, 'Senoide'),
    effect(0x0C, 'Flores'),
    effect(0x0E, 'Laser'),
    effect(0x10, 'Chuva'),
    effect(0x11, 'Neve'),
    effect(0x12, 'Meteoro'),
    { id: 0x00, name: 'Desligado' }
  ],
  settings: {
    live: {
      label: 'Como enviar a cor',
      type: 'combobox',
      values: ['Automático', 'Ao vivo A', 'Ao vivo B', 'Compatível'],
      default: 'Automático',
      description: 'Ao vivo muda a cor sem piscar; Compatível funciona em todos os modelos, mas pisca com efeitos animados. Automático usa Ao vivo nos modelos testados. Se o teclado não mudar de cor em Ao vivo, use Compatível.'
    },
    rate: {
      label: 'Atualizações por segundo (Compatível)',
      type: 'number',
      min: 1,
      max: 30,
      default: 8,
      description: 'Só no modo Compatível: menos atualizações poupam o teclado; mais deixam efeitos rápidos mais suaves.'
    }
  },
  fps: 30,

  start: function (dev) {
    this.color = [0, 0, 0];
    this.sentKey = '';
    this.sentAt = 0;
    this.directOn = false;
    return true;
  },

  // Live color: the keyboard is put in its direct mode once, then each
  // color goes in a short command that does not restart the lighting.
  sendDirect: function (dev, variant, r, g, b) {
    if (!this.directOn) {
      this.send(dev, MODE_DIRECT, DAZZLE_OFF, r, g, b);
      this.directOn = true;
    }
    var payload = [SET_DIRECT_COLOR, r, g, b, 0, 0, 0];
    var sum = variant === 'B' ? onesComplement(payload) : checksum(payload);
    dev.sendFeature([0x00].concat(payload, [sum]));
  },

  settingChanged: function (dev, name) {
    // Switching how colors are sent starts over with the next frame.
    this.sentKey = '';
    this.directOn = false;
  },

  send: function (dev, mode, dazzle, r, g, b, speed, brightness) {
    var payload = [
      SET_LED_PARAMS, mode,
      speed === undefined ? SPEED.default : speed,
      brightness === undefined ? BRIGHTNESS.default : brightness,
      dazzle, r, g, b
    ];
    dev.sendFeature([0x00].concat(payload, [checksum(payload)]));
  },

  // 'A' or 'B' (checksum variant) for the live command, or null for the
  // mode command. Accepts the names older versions saved ("Direto A (teste)",
  // "Padrão").
  liveVariant: function (dev) {
    var live = dev.setting('live') || 'Automático';
    if (live === 'Automático') return LIVE_MODELS[dev.info.pid] || null;
    if (live.indexOf('Ao vivo') === 0 || live.indexOf('Direto') === 0) {
      return live.indexOf(' B') > 0 ? 'B' : 'A';
    }
    return null;
  },

  render: function (dev, colors) {
    var r = colors[0], g = colors[1], b = colors[2];
    var key = r + ',' + g + ',' + b;
    if (key === this.sentKey) return;
    var variant = this.liveVariant(dev);
    var now = Date.now();
    // The mode command restarts the lighting and may be stored: limited.
    if (!variant && now - this.sentAt < 1000 / (dev.setting('rate') || 8)) return;
    this.sentKey = key;
    this.sentAt = now;
    if (variant) {
      this.sendDirect(dev, variant, r, g, b);
    } else {
      this.send(dev, MODE_ALWAYS_ON, DAZZLE_OFF, r, g, b);
    }
  },

  mode: function (dev, id, options) {
    this.sentKey = '';
    this.directOn = false;
    if (id === null) return; // the next frame sends the app's color
    var c = (options.colors && options.colors[0]) || [0xFF, 0xFF, 0xFF];
    var dazzle = options.random === false ? DAZZLE_OFF : DAZZLE_ON;
    this.send(dev, id, dazzle, c[0], c[1], c[2], options.speed, options.brightness);
  },

  stop: function (dev) {
    this.send(dev, MODE_ALWAYS_ON, DAZZLE_OFF, 0, 0, 0);
  }
});
