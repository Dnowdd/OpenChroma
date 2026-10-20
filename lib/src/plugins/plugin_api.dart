/// The JavaScript side of OpenChroma's plugin API (see docs/PLUGINS.md),
/// evaluated before a plugin file. A plugin calls `plugin({...})` once with
/// its description and callbacks; the host then drives it through `__oc`.
///
/// Hardware calls go to Dart through the synchronous
/// `sendMessage('h', ...)` bridge of flutter_js.
const pluginApiJs = r'''
var __oc = (function () {
  function h() { return sendMessage('h', JSON.stringify(Array.prototype.slice.call(arguments))); }
  function bytes(a) { return a == null ? [] : Array.prototype.slice.call(a).map(function (v) { return v & 0xff; }); }

  var def = null;
  var settings = {};

  globalThis.plugin = function (d) {
    if (def) throw new Error('plugin() was called twice');
    def = d;
  };

  var dev = {
    /** Set by the host: vid, pid, serial, product, manufacturer. */
    info: {},
    /** Output report; data[0] is the report ID. Returns bytes written. */
    write: function (data) { return h('write', bytes(data)); },
    /** Next input report (report ID 0 stripped), or [] after timeoutMs. */
    read: function (length, timeoutMs) { return h('read', length | 0, timeoutMs === undefined ? 100 : timeoutMs | 0) || []; },
    /** Feature report; data[0] is the report ID. Returns bytes sent or -1. */
    sendFeature: function (data) { return h('sendFeature', bytes(data)); },
    /** Reads feature report [reportId]; returns [] on failure. */
    getFeature: function (reportId, length) { return h('getFeature', reportId | 0, length | 0) || []; },
    /** Reads input report [reportId] over the control pipe. */
    getInputReport: function (reportId, length) { return h('getInputReport', reportId | 0, length | 0) || []; },
    /** Drops queued input reports. */
    clearInput: function () { h('clearInput'); },
    /** The device's HID collections. */
    endpoints: function () { return h('endpoints'); },
    /** Switches I/O to the first collection matching {interface, usagePage, usage}. */
    useEndpoint: function (match) { return h('useEndpoint', match || {}) === true; },
    sleep: function (ms) { h('sleep', ms | 0); },
    log: function () {
      h('log', Array.prototype.map.call(arguments, function (a) {
        return typeof a === 'string' ? a : JSON.stringify(a);
      }).join(' '));
    },
    /** Current value of one of the plugin's settings. */
    setting: function (name) { return settings[name]; },
    /** Reports a wireless device's charge (0-100, or null when unknown). */
    setBattery: function (percent, charging) {
      h('battery', percent == null ? null : Math.max(0, Math.min(100, Math.round(percent))), !!charging);
    }
  };

  function call(name, args) {
    var fn = def && def[name];
    return typeof fn === 'function' ? fn.apply(def, [dev].concat(args || [])) : undefined;
  }
  function resolve(v) { return typeof v === 'function' ? v(dev) : v; }

  return {
    defined: function () { return def != null; },
    /** Everything that is not a function, for the plugin list. */
    describe: function () { return JSON.stringify(def); },
    setInfo: function (info) { dev.info = info; },
    setSettings: function (s) { settings = s || {}; },
    setSetting: function (name, value) {
      settings[name] = value;
      call('settingChanged', [name, value]);
    },
    /** Picks the collection to open from the device's endpoints. */
    pickEndpoint: function (endpoints) {
      var e = def.endpoint;
      if (typeof e === 'function') return e(endpoints);
      for (var i = 0; i < endpoints.length; i++) {
        var p = endpoints[i], ok = true;
        for (var k in (e || {})) if (e[k] !== p[k]) ok = false;
        if (ok) return i;
      }
      return -1;
    },
    start: function () { return call('start') !== false; },
    /** Zones and hardware modes, after start (they may depend on the device). */
    layout: function () {
      return JSON.stringify({ zones: resolve(def.zones) || [], modes: resolve(def.modes) || [] });
    },
    render: function (colors) { call('render', [colors]); },
    mode: function (id) { call('mode', [id]); },
    poll: function () { call('poll'); },
    stop: function () { call('stop'); },
    fps: function () { return def.fps || 30; },
    pollMs: function () { return def.pollMs || 1000; }
  };
})();
''';
