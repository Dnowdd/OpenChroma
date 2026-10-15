/// JavaScript shim that recreates the host API SignalRGB exposes to device
/// plugins (`device`, `bus`, `mouse`, `keyboard` and the `@SignalRGB/*`
/// modules). Hardware calls go to Dart through the synchronous
/// `sendMessage('h', ...)` bridge; LED colors are pushed in by the host before
/// every `Render()` via `__oc.setFrame(...)`, so `device.color()` never crosses
/// the bridge.
const pluginPrelude = r'''
var __oc = (function () {
  function h() { return sendMessage('h', JSON.stringify(Array.prototype.slice.call(arguments))); }

  var state = {
    name: '', size: [1, 1], ledNames: [], ledPositions: [], image: '',
    subdevices: {}, channels: {}, channelOrder: [], properties: [], features: [],
    ledLimit: 0, frameRate: 0, messages: []
  };
  var dirty = true;
  var frame = { m: [], s: {}, c: {} };
  var userProps = {};

  function touch() { dirty = true; }
  function toArray(data) {
    if (data == null) return [];
    if (Array.isArray(data)) return data;
    return Array.prototype.slice.call(data);
  }
  function hexToRgb(hex) {
    if (Array.isArray(hex)) return hex.slice(0, 3);
    var r = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})/i.exec(String(hex));
    return r ? [parseInt(r[1], 16), parseInt(r[2], 16), parseInt(r[3], 16)] : [0, 0, 0];
  }
  function reorder(c, order) {
    if (!order || order === 'RGB') return c;
    var o = String(order).toUpperCase();
    return [c['RGB'.indexOf(o[0])], c['RGB'.indexOf(o[1])], c['RGB'.indexOf(o[2])]];
  }
  function pack(colors, format, order) {
    var sep = format === 'Separate' || format === 'Seperate';
    if (sep) {
      var a = [[], [], []];
      for (var i = 0; i < colors.length; i++) {
        var c = reorder(colors[i], order);
        a[0].push(c[0]); a[1].push(c[1]); a[2].push(c[2]);
      }
      return a;
    }
    var out = [];
    for (var j = 0; j < colors.length; j++) {
      var d = reorder(colors[j], order);
      out.push(d[0], d[1], d[2]);
    }
    return out;
  }
  function gridColor(flat, w, x, y) {
    x = Math.floor(x); y = Math.floor(y);
    var i = (y * w + x) * 3;
    if (x < 0 || y < 0 || x >= w || i + 2 >= flat.length) return [0, 0, 0];
    return [flat[i], flat[i + 1], flat[i + 2]];
  }
  function channelColors(name) {
    var flat = frame.c[name] || [];
    var ch = state.channels[name];
    var n = ch ? ch.count : 0;
    var res = [];
    for (var i = 0; i < n; i++) res.push(i * 3 + 2 < flat.length ? [flat[i * 3], flat[i * 3 + 1], flat[i * 3 + 2]] : [0, 0, 0]);
    return res;
  }

  function makeChannel(name) {
    var ch = state.channels[name];
    if (!ch) return undefined;
    return {
      name: name,
      get ledCount() { return ch.count; },
      LedCount: function () { return ch.count; },
      LedLimit: function () { return ch.limit; },
      SetLedLimit: function (l) { ch.limit = l; touch(); },
      getColors: function (format, order) { return pack(channelColors(name), format, order); },
      getPulse: function (count, format, order) {
        var c = hexToRgb(device.getChannelPulseColor(name));
        var arr = []; for (var i = 0; i < count; i++) arr.push(c);
        return pack(arr, format, order);
      },
      shouldPulseColors: function () { return false; },
      getComponentNames: function () { return []; },
      getComponentData: function () { return []; }
    };
  }

  var device = {
    log: function () {
      var parts = [];
      for (var i = 0; i < arguments.length; i++) {
        var a = arguments[i];
        parts.push(typeof a === 'object' ? JSON.stringify(a) : String(a));
      }
      h('log', parts.join(' '));
    },
    notify: function (title, message) { h('log', '[notify] ' + title + ' - ' + (message || '')); },
    pause: function (ms) { h('pause', ms | 0); },

    // HID I/O
    write: function (data, len) { return h('write', toArray(data), len | 0); },
    send_report: function (data, len) { return h('send_report', toArray(data), len | 0); },
    get_report: function (data, len) { return h('get_report', toArray(data), len | 0) || []; },
    input_report: function (data, len) { return h('input_report', toArray(data), len | 0) || []; },
    read: function (data, len, timeout) { return h('read', toArray(data), len | 0, timeout === undefined ? 1000 : timeout | 0) || []; },
    getLastReadSize: function () { return h('last_read_size'); },
    clearReadBuffer: function () { h('clear_read'); },
    flush: function () { h('clear_read'); },
    set_endpoint: function (iface, usage, usagePage, collection) {
      return h('set_endpoint', iface, usage === undefined ? -1 : usage, usagePage === undefined ? -1 : usagePage, collection === undefined ? -1 : collection);
    },
    getHidEndpoints: function () { return h('endpoints'); },
    getHidInfo: function () { return h('hid_info'); },
    productId: function () { return h('pid'); },
    vendorId: function () { return h('vid'); },
    getDeviceInfo: function () { return h('device_info'); },
    bulk_transfer: function () { return -1; },
    control_transfer: function () { return -1; },
    setProtocol: function () {},

    // Device description
    setName: function (n) { state.name = String(n); touch(); },
    setSize: function (w, hh) { state.size = Array.isArray(w) ? w.slice(0, 2) : [w, hh]; touch(); },
    setControllableLeds: function (names, positions) { state.ledNames = toArray(names); state.ledPositions = toArray(positions); touch(); },
    setImageFromUrl: function (url) { state.image = String(url); touch(); },
    setImageFromBase64: function () {},
    getImageBuffer: function () { return []; },
    setFrameRateTarget: function (fps) { state.frameRate = fps; touch(); },
    addFeature: function (f) { if (state.features.indexOf(f) < 0) state.features.push(f); touch(); },
    getBrightness: function () { return h('brightness'); },

    // Properties
    addProperty: function (p) {
      device.removeProperty(p.property, true);
      state.properties.push(p);
      if (!(p.property in globalThis)) {
        var v = p.property in userProps ? userProps[p.property] : __oc.coerce(p, p['default']);
        globalThis[p.property] = v;
      }
      touch();
    },
    removeProperty: function (name, keepValue) {
      state.properties = state.properties.filter(function (p) { return p.property !== name; });
      if (!keepValue) { try { delete globalThis[name]; } catch (e) {} }
      touch();
    },
    getProperty: function (name) {
      for (var i = 0; i < state.properties.length; i++) if (state.properties[i].property === name) return state.properties[i];
      return undefined;
    },
    setUserProperty: function (name, value) { globalThis[name] = value; userProps[name] = value; h('user_prop', name, value); },

    // Colors
    color: function (x, y) { return gridColor(frame.m, state.size[0], x, y); },
    subdeviceColor: function (id, x, y) {
      var s = state.subdevices[id];
      return s ? gridColor(frame.s[id] || [], s.size[0], x, y) : [0, 0, 0];
    },
    createColorArray: function (color, count, format, order) {
      var c = hexToRgb(color), arr = [];
      for (var i = 0; i < count; i++) arr.push(c);
      return pack(arr, format, order);
    },

    // Subdevices
    createSubdevice: function (id) {
      if (!state.subdevices[id]) state.subdevices[id] = { name: id, size: [1, 1], ledNames: [], ledPositions: [], image: '' };
      touch();
    },
    removeSubdevice: function (id) { delete state.subdevices[id]; touch(); },
    setSubdeviceName: function (id, n) { if (state.subdevices[id]) { state.subdevices[id].name = n; touch(); } },
    setSubdeviceSize: function (id, w, hh) { if (state.subdevices[id]) { state.subdevices[id].size = [w, hh]; touch(); } },
    setSubdeviceLeds: function (id, names, positions) {
      if (state.subdevices[id]) { state.subdevices[id].ledNames = toArray(names); state.subdevices[id].ledPositions = toArray(positions); touch(); }
    },
    setSubdeviceImageUrl: function (id, url) { if (state.subdevices[id]) { state.subdevices[id].image = url; touch(); } },
    setSubdeviceImage: function () {},
    getCurrentSubdevices: function () { return Object.keys(state.subdevices); },
    SetIsSubdeviceController: function () {},

    // ARGB channels
    SetLedLimit: function (l) { state.ledLimit = l; touch(); },
    addChannel: function (name, limit) {
      if (!state.channels[name]) { state.channels[name] = { limit: limit || 0, count: 0 }; state.channelOrder.push(name); }
      touch();
    },
    removeChannel: function (name) {
      delete state.channels[name];
      state.channelOrder = state.channelOrder.filter(function (n) { return n !== name; });
      touch();
    },
    channel: function (name) { return makeChannel(name); },
    getChannelNames: function () { return state.channelOrder.slice(); },
    getLedCount: function () {
      var t = 0; for (var k in state.channels) t += state.channels[k].count; return t;
    },
    getChannelPulseColor: function () { return '#ffffff'; },

    // Fans / sensors are not supported in this version.
    fanControlDisabled: function () { return true; },
    createFanControl: function () {}, removeFanControl: function () {},
    setRPM: function () {}, getNormalizedFanlevel: function () { return 0; }, getFanlevel: function () { return 0; },
    createTemperatureSensor: function () {}, removeTemperatureSensor: function () {}, SetTemperature: function () {}
  };

  var noop = function () {};
  var bus = new Proxy({ log: function () { device.log.apply(null, arguments); } }, {
    get: function (t, k) { return k in t ? t[k] : function () { return -1; }; }
  });
  var inputStub = { sendEvent: noop, sendHid: noop, sendKey: noop };

  var Assert = {
    isOk: function (v, msg) { if (!v) throw new Error('Assert.isOk: ' + (msg || '')); return true; },
    isEqual: function (a, b, msg) { if (a !== b) throw new Error('Assert.isEqual: ' + (msg || '')); return true; },
    fail: function (msg) { throw new Error('Assert.fail: ' + (msg || '')); },
    unreachable: function (msg) { throw new Error('Assert.unreachable: ' + (msg || '')); },
    softIsDefined: function (v, msg) { if (v === undefined) { device.log('Assert.softIsDefined: ' + (msg || '')); return false; } return true; }
  };
  function ContextError(message) { this.message = message; }
  ContextError.prototype = Object.create(Error.prototype);
  var ctxStore = {};
  var globalContext = { set: function (k, v) { ctxStore[k] = v; }, get: function (k) { return ctxStore[k]; } };

  var systeminfo = {
    GetMotherboardInfo: function () { return h('sysinfo', 'motherboard'); },
    GetBiosInfo: function () { return h('sysinfo', 'bios'); },
    GetRamInfo: function () { return []; }
  };
  var errors = { Assert: Assert, ContextError: ContextError, globalContext: globalContext };
  var modules = {
    '@signalrgb/errors': errors,
    '@signalrgb/systeminfo': systeminfo,
    '@signalrgb/devicediscovery': { foundVirtualDevice: noop, lostVirtualDevice: noop },
    '@signalrgb/permissions': new Proxy({}, { get: function () { return function () { return true; }; } }),
    '@signalrgb/serial': new Proxy({}, { get: function () { return noop; } }),
    '@signalrgb/lcd': new Proxy({}, { get: function () { return noop; } })
  };

  globalThis.device = device;
  globalThis.bus = bus;
  globalThis.mouse = inputStub;
  globalThis.keyboard = inputStub;
  globalThis.require = function () { return {}; };

  return {
    module: function (name) {
      var key = String(name).toLowerCase().replace(/\.js$/, '');
      return modules[key] || {};
    },
    coerce: function (p, v) {
      if (p.type === 'boolean') return v === true || v === 'true' || v === 1 || v === '1';
      if (p.type === 'number' || p.type === 'int' || p.type === 'float') { var n = Number(v); return isNaN(n) ? 0 : n; }
      if (p.type === 'combobox' && v === undefined && p.values) return p.values[0];
      return v === undefined ? '' : v;
    },
    setUserProps: function (obj) { userProps = obj || {}; },
    fps: function () { return state.frameRate || 30; },
    setFrame: function (f) { frame = f; },
    setChannelCounts: function (counts) {
      for (var k in counts) if (state.channels[k]) state.channels[k].count = counts[k] | 0;
      touch();
    },
    takeState: function () {
      if (!dirty) return null;
      dirty = false;
      var props = state.properties.map(function (p) {
        var o = {}; for (var k in p) o[k] = p[k];
        o.value = globalThis[p.property];
        return o;
      });
      return JSON.stringify({
        name: state.name, size: state.size, ledNames: state.ledNames, ledPositions: state.ledPositions,
        image: state.image, subdevices: state.subdevices, channels: state.channels,
        channelOrder: state.channelOrder, properties: props, features: state.features,
        frameRate: state.frameRate
      });
    },
    touch: touch
  };
})();
''';
