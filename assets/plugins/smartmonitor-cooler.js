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
//   app refuses them), so frames get a lower quality or are dropped to fit.
//
// SPDX-License-Identifier: GPL-2.0-or-later

var SIZE = 480;
var BLOCK = 4096;
var ACK = 0x43;
var NAK = 0x15;
var MAX_THEME = 4 * 1024 * 1024;
var MIN_QUALITY = 40;

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

function buildTheme(jpegs, direction) {
  var total = BLOCK;
  for (var i = 0; i < jpegs.length; i++) total += 4 + jpegs[i].length;
  var file = new Uint8Array(total);
  file[0] = 0x96;
  file[1] = direction;
  var bg = 0x40;
  file[bg] = 0x81;
  put(file, bg + 7, be16(SIZE));
  put(file, bg + 9, be16(SIZE));
  put(file, bg + 0x0c, [0xf7, 0x9e]);
  put(file, bg + 0x0e, be32(BLOCK));
  put(file, bg + 0x12, be16(jpegs.length));
  put(file, bg + 0x14, be32(1));
  put(file, bg + 0x18, be32(total));
  var at = BLOCK;
  for (var j = 0; j < jpegs.length; j++) {
    put(file, at, be32(jpegs[j].length));
    put(file, at + 4, jpegs[j]);
    at += 4 + jpegs[j].length;
  }
  return file;
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
  screen: { width: SIZE, height: SIZE, maxFrames: 100 },
  settings: {
    quality: { label: 'JPEG quality', type: 'number', default: 80, min: 40, max: 100 },
    direction: {
      label: 'Screen rotation',
      type: 'combobox',
      default: '0°',
      values: ['0°', '90°', '180°', '270°']
    }
  },
  pollMs: 5000,

  start: function (dev) {
    dev.clearInput();
    return true;
  },

  showImage: function (dev, image) {
    var quality = dev.setting('quality') || 80;
    var dir = ['0°', '90°', '180°', '270°'].indexOf(dev.setting('direction'));
    var budget = MAX_THEME - BLOCK;
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
    var file = buildTheme(jpegs, dir < 0 ? 0 : dir);
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
  }
});
