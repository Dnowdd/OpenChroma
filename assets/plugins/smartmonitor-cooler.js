// Water coolers with a 2.8" 480x480 round screen driven by the SmartMonitor
// app (SmartMonitorX28, firmware S021H480480), behind a CH340/CH9340 serial
// bridge at 1 Mbaud.
//
// Learned from the SmartMonitor app (2026-11-18). The app turns a theme into
// a file and sends it whole; the cooler keeps it and plays it on its own:
// - the file starts with a 4096-byte table of 64-byte records: 0x96 (screen
//   direction in byte 1) and 0x81 (the background: size, where its frames
//   start, how many and the file length); widget records are left out here.
//   The frames follow, each a big-endian length and a JPEG;
// - it goes in 4096-byte blocks, each behind a 64-byte header: "theme",
//   block number, file length and the file's CRC-16/MODBUS, all big-endian.
//   After every 256 blocks the cooler answers 'C' (0x43) when it is ready,
//   or NAK (0x15). An "end" header closes the file and the cooler answers
//   'C' once it shows it. Themes over 4 MB break the cooler's screen (the
//   app refuses them), so frames get a lower quality or are dropped to fit;
// - live numbers are 0x92 records: id, value channel (1-5), box, RGB565
//   color and the glyphs "0"-"9", ".", "-" (one opacity byte per pixel)
//   stored after the frames, which start at an even offset. Each second the
//   PC sends either an 'f' packet (time and exactly five channel values) or
//   an 'n' packet (20 ids with non-zero values), taking turns like the app;
//   the numbers stay hidden when both come at once, without either, or
//   when the 'n' values are zero. Static images (0x93)
//   cannot be wider than 255 pixels, so texts are drawn into the frames.
// - the 'f' packet also carries the screen brightness (1-100) and, with the
//   weekday, an off timer (weekday + minutes * 8). A few packets with 1 and
//   then silence make the screen blink and go dark, and it stays dark while
//   nothing more is sent (more packets light it again); a few with 30 light
//   it, and 0 keeps it as it is.
//   Live numbers vanish when the whole theme passes about 2 MB (themes up
//   to 1.9 MB showed them, 2.2 MB did not), so such themes are kept smaller.
//
// SPDX-License-Identifier: GPL-2.0-or-later

var SIZE = 480;
var BLOCK = 4096;
var ACK = 0x43;
var NAK = 0x15;
var MAX_THEME = 4 * 1024 * 1024;
var MAX_LIVE_THEME = 1900000;
var MIN_QUALITY = 40;
var CHANNELS = 5;
var MAX_WIDGETS = 60;
var WAKE_PACKETS = 3;
var SLEEP_PACKETS = 1;

function be16(v) { return [(v >> 8) & 0xff, v & 0xff]; }
function be32(v) { return [(v >>> 24) & 0xff, (v >> 16) & 0xff, (v >> 8) & 0xff, v & 0xff]; }

function crc16(data) {
  var crc = 0xffff;
  for (var i = 0; i < data.length; i++) {
    crc ^= data[i];
    for (var b = 0; b < 8; b++) crc = crc & 1 ? (crc >>> 1) ^ 0xa001 : crc >>> 1;
  }
  return crc;
}

function put(buf, at, bytes) {
  for (var i = 0; i < bytes.length; i++) buf[at + i] = bytes[i];
}

function buildTheme(jpegs, direction, widgets, glyphs) {
  var start = BLOCK;
  for (var i = 0; i < jpegs.length; i++) start += 4 + jpegs[i].length;
  var data = start + (start % 2);
  var total = data;
  for (var g = 0; g < glyphs.length; g++) total += glyphs[g].length;
  var file = new Uint8Array(total);
  file[0] = 0x96;
  file[1] = direction;
  var bg = 0x40;
  file[bg] = 0x81;
  put(file, bg + 7, be16(SIZE));
  put(file, bg + 9, be16(SIZE));
  put(file, bg + 0x0e, be32(BLOCK));
  put(file, bg + 0x12, be16(jpegs.length));
  put(file, bg + 0x14, [0, 0, 1, 1]);
  put(file, bg + 0x18, be32(total));
  var at = BLOCK;
  for (var j = 0; j < jpegs.length; j++) {
    put(file, at, be32(jpegs[j].length));
    put(file, at + 4, jpegs[j]);
    at += 4 + jpegs[j].length;
  }
  at = data;
  for (var k = 0; k < widgets.length && k < MAX_WIDGETS; k++) {
    var w = widgets[k], r = 0x80 + k * 0x40;
    file[r] = 0x92;
    file[r + 1] = k + 1;
    file[r + 2] = w.channel;
    put(file, r + 3, be16(w.x));
    put(file, r + 5, be16(w.y));
    put(file, r + 7, be16(w.width));
    put(file, r + 9, be16(w.height));
    file[r + 11] = 1;
    put(file, r + 12, be16(w.color));
    file[r + 15] = 0xff;
    put(file, r + 16, be32(at));
    put(file, r + 20, be16(w.glyphHeight));
    for (var c = 0; c < 12; c++) put(file, r + 22 + c * 2, be16(w.glyphWidths[c]));
    put(file, at, glyphs[k]);
    at += glyphs[k].length;
  }
  return file;
}

function hex(bytes) {
  var out = [];
  for (var i = 0; i < bytes.length; i++) out.push((bytes[i] < 16 ? '0' : '') + bytes[i].toString(16));
  return out.join(' ');
}

function seal(packet) {
  var length = packet.length + 2;
  packet[1] = (length >> 8) & 0xff;
  packet[2] = length & 0xff;
  return packet.concat(be16(crc16(packet)));
}

function valuePackets(dev, values, offTimer, brightness) {
  var t = dev.localTime();
  var day = new Date(Date.UTC(t[0], t[1] - 1, t[2])).getUTCDay() || 7;
  var f = [0x66, 0, 0, 1, (t[0] + 0x30) & 0xff, t[1], t[2], t[3], t[4], t[5],
    day + offTimer * 8, brightness];
  for (var i = 0; i < CHANNELS; i++) {
    var v = values[i] == null ? 0 : Math.max(-32768, Math.min(32767, Math.round(values[i])));
    f.push(i + 1, (v >> 8) & 0xff, v & 0xff);
  }
  var n = [0x6e, 0, 0];
  for (var id = 0; id < 20; id++) n.push(id, 0, 100 + id);
  return [seal(f), seal(n)];
}

function header(name, index, length, crc) {
  var h = new Array(64).fill(0);
  for (var i = 0; i < name.length; i++) h[i] = name.charCodeAt(i);
  put(h, 6, be16(index));
  put(h, 8, be32(length));
  put(h, 12, be16(crc));
  return h;
}

function waitReady(dev, ms) {
  var until = Date.now() + ms;
  while (Date.now() < until) {
    var r = dev.read(64, 200);
    for (var i = 0; i < r.length; i++) {
      if (r[i] === ACK) return true;
      if (r[i] === NAK) return false;
    }
  }
  return false;
}

plugin({
  name: 'SmartMonitor Cooler',
  vendor: 'SmartMonitor',
  type: 'cooler',
  devices: [
    { vid: 0x1a86, pid: 0x8040, name: 'Water Cooler 2.8" (SmartMonitor)' },
    { vid: 0x1a86, pid: 0x5722, name: 'Water Cooler 2.8" (SmartMonitor)' }
  ],
  serial: { baud: 1000000 },
  zones: [],
  screen: { width: SIZE, height: SIZE, maxFrames: 100, round: true, liveValues: CHANNELS },
  settings: {
    screenOn: { label: 'Tela ligada', type: 'boolean', default: true },
    brightness: { label: 'Brilho da tela', type: 'number', default: 100, min: 1, max: 100 },
    quality: { label: 'Qualidade do JPEG', type: 'number', default: 80, min: 40, max: 100 },
    direction: {
      label: 'Rotação da tela',
      type: 'combobox',
      default: '0°',
      values: ['0°', '90°', '180°', '270°']
    }
  },
  pollMs: 1000,

  start: function (dev) {
    try {
      dev.clearInput();
    } catch (e) {
      dev.log('port busy, will retry when needed: ' + e.message);
    }
    return true;
  },

  showImage: function (dev, image) {
    var quality = dev.setting('quality') || 80;
    var dir = ['0°', '90°', '180°', '270°'].indexOf(dev.setting('direction'));
    var widgets = image.widgets || [];
    var glyphs = [], glyphBytes = 0;
    for (var g = 0; g < widgets.length; g++) {
      glyphs.push(dev.widgetGlyphs(g));
      glyphBytes += glyphs[g].length;
    }
    var budget = (widgets.length ? MAX_LIVE_THEME : MAX_THEME) - BLOCK - glyphBytes - 2;
    var probe = dev.jpeg(0, quality).length;
    if (!probe) return false;
    while (quality > MIN_QUALITY && (probe + 4) * image.frames > budget * 0.9) {
      quality = Math.max(MIN_QUALITY, quality - 10);
      probe = dev.jpeg(0, quality).length;
    }
    var keep = Math.min(image.frames, Math.max(1, Math.floor(budget * 0.9 / (probe + 4))));
    var jpegs = [], total = 0;
    for (var k = 0; k < keep; k++) {
      var jpeg = dev.jpeg(Math.floor(k * image.frames / keep), quality);
      if (!jpeg.length) {
        dev.log('frame ' + k + ' could not be encoded');
        return false;
      }
      if (total + 4 + jpeg.length > budget) break;
      total += 4 + jpeg.length;
      jpegs.push(jpeg);
      dev.progress(0.2 * (k + 1) / keep);
    }
    dev.log(jpegs.length + ' of ' + image.frames + ' frames at quality ' + quality + ', ' + Math.round((total + BLOCK) / 1024) + ' KB');
    var file = buildTheme(jpegs, dir < 0 ? 0 : dir, widgets, glyphs);
    dev.log('theme ' + file.length + ' bytes, ' + widgets.length + ' live widgets');
    for (var x = 0; x < widgets.length; x++) {
      dev.log('widget ' + x + ' ' + JSON.stringify(widgets[x]) + ' glyphs ' + glyphs[x].length +
        ' record ' + hex(file.subarray(0x80 + x * 0x40, 0x80 + x * 0x40 + 46)));
    }
    this.valueLogs = 4;
    var crc = crc16(file);
    var blocks = Math.ceil(file.length / BLOCK);
    dev.clearInput();
    var b = 0, retries = 0;
    while (b < blocks) {
      var packet = header('theme', b, file.length, crc);
      var chunk = Array.prototype.slice.call(file.subarray(b * BLOCK, (b + 1) * BLOCK));
      while (chunk.length < BLOCK) chunk.push(0);
      var waits = ((b + 1) & 0xff) === 0 && b + 1 < blocks;
      if (waits) dev.clearInput();
      var sent = dev.write(packet.concat(chunk));
      if (sent !== 64 + BLOCK) {
        dev.log('block ' + b + ': wrote ' + sent + ' of ' + (64 + BLOCK) + ' bytes');
        return false;
      }
      b++;
      dev.progress(0.2 + 0.8 * b / blocks);
      if (waits) {
        if (!waitReady(dev, 60000)) {
          if (++retries > 3) return false;
          b = Math.max(0, b - (((b - 1) & 0xff) + 1));
          dev.log('cooler asked to resend from block ' + b);
        }
      }
    }
    dev.clearInput();
    dev.write(header('end', 0, file.length, crc));
    return waitReady(dev, 60000);
  },

  values: function (dev, values) {
    this.liveValues = values;
  },

  settingChanged: function (dev, name, value) {
    if (name !== 'screenOn') return;
    this.wake = value ? WAKE_PACKETS : 0;
    this.sleep = value ? 0 : SLEEP_PACKETS;
  },

  poll: function (dev) {
    var on = dev.setting('screenOn') !== false;
    if (this.wake === undefined) {
      this.wake = on ? WAKE_PACKETS : 0;
      this.sleep = on ? 0 : SLEEP_PACKETS;
    }
    if (!on && this.sleep <= 0) return;
    this.valueTick = !this.valueTick;
    var offTimer = 0;
    if (on && this.wake > 0) offTimer = 30;
    if (!on) offTimer = 1;
    var sendF = this.valueTick || offTimer !== 0;
    if (sendF && this.wake > 0) this.wake--;
    if (!on) this.sleep--;
    var packets = valuePackets(dev, this.liveValues || [], offTimer,
      Math.max(1, Math.min(100, dev.setting('brightness') || 100)));
    var packet = packets[sendF ? 0 : 1];
    var sent;
    try {
      sent = dev.write(packet);
    } catch (e) {
      sent = e.message;
    }
    if (this.valueLogs > 0) {
      this.valueLogs--;
      dev.log('values ' + JSON.stringify(this.liveValues || []) + ' sent ' + sent + ': ' + hex(packet));
    }
  }
});
