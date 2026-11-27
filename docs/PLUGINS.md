# Device plugins

A plugin is a `.js` file that teaches OpenChroma how to talk to a USB HID
device: which models it supports, how many LEDs they have and which bytes to
send to paint each one. Plugins take priority over the built-in drivers:
when a plugin declares a model, the built-in drivers don't even open that
device.

- Plugins that ship with the app: [`assets/plugins`](../assets/plugins).
  They are read straight from the app's own assets (never from a copy in
  `%APPDATA%`), so they cannot be changed from outside the install.
- Your plugins: `%APPDATA%\OpenChroma\plugins` (Settings › Device plugins ›
  Open folder). A user plugin only runs after you approve it (see
  [Security](#security)). A file with the same name as a bundled plugin, or
  one that declares the same devices, replaces the bundled one once
  approved, and the approval dialog says so. The app watches the folder:
  saving, creating or deleting a `.js` (or the reload button next to "Open
  folder") reloads the plugins, and only the devices of the plugins that
  changed restart. A model that a plugin starts supporting leaves the
  built-in drivers right away.

Each device runs its plugin in a separate QuickJS instance (JavaScript
ES2020), with no access to files, the network or other devices.

## Security

A plugin is code that runs inside OpenChroma, often with administrator
rights (SMBus access needs them), and it can send any report to the USB
devices it declares. So:

- **Approval on first use.** A user plugin is not even evaluated until you
  approve it. New or modified files show "N new plugins need your approval"
  on the Devices page; the dialog lists file name, path, size, date and the
  SHA-256 of each one. The approval is stored in `settings.json` as
  `{file name: SHA-256}` and is bound to that exact content: the plugin
  that runs is the text that was hashed, not a second read of the file.
  A refusal is remembered until the file changes.
- **Edits.** When OpenChroma runs as administrator, any change to an
  approved file makes it pending again. When it does not (the usual way to
  develop a plugin), a file you approved once keeps its approval as you
  edit it, so hot reload stays smooth; a new file name always asks.
  Limitation: `settings.json` is as writable as the plugins folder, so
  malware that can write both could pre-approve its own file. The approval
  stops code that only drops a `.js`.
- **Limits.** Each user plugin is read in its own isolate with a 3 second
  limit and a 512 KB JavaScript stack (64 MB heap when the QuickJS bridge
  exports `jsSetMemoryLimit`, which the current Windows build does not). QuickJS
  cannot be interrupted, so a plugin that loops forever is reported as an
  error and its thread is left at idle priority until the app exits; it is
  not tried again until the file changes. A running plugin that stops
  answering for 20 seconds is marked as failed the same way.
- **Devices.** A plugin only gets the HID/serial collections of the VID:PID
  pairs it declares (the worker enforces it again on its side), and never
  FIDO security keys (usage page `0xF1D0`).

## Example

```js
plugin({
  name: 'Example Mouse',
  vendor: 'Example',
  type: 'mouse',
  devices: [{ vid: 0x1234, pid: 0x5678, name: 'Example M1' }],
  endpoint: { interface: 1, usagePage: 0xFF00 },
  zones: [
    { name: 'Logo', leds: 1 },
    { name: 'Wheel', leds: 1 }
  ],

  start: function (dev) {
    dev.write([0x01, 0x10]); // software-controlled mode
  },

  render: function (dev, colors) {
    // colors: [r, g, b] of each LED, in zone order
    dev.write([0x02].concat(colors));
  },

  stop: function (dev) {
    dev.write([0x01, 0x00]); // give control back to the mouse
  }
});
```

## The description

| Field | Required | What it is |
|---|---|---|
| `name` | yes | Plugin name. |
| `vendor` | no | Manufacturer. |
| `type` | no | `keyboard`, `mouse`, `headset`, `mousepad`, `motherboard`, `gpu`, `ram`, `ledstrip`, `cooler`, `gamepad`, `speakers`, `microphone`, `case` or `other`. Sets the device artwork in the app. |
| `devices` | yes | List of supported `{ vid, pid, name }`. |
| `serial` | no | `{ baud }` when the devices are USB serial ports (COMx) rather than HID: the app finds the port by VID:PID, opens it as 8N1 without flow control, and `dev.write`/`dev.read` send and read raw bytes. `endpoint` doesn't apply. |
| `endpoint` | no | Which HID collection to open: an object with the fields that must match (`interface`, `usagePage`, `usage`, `collection`) or a function `(endpoints) => index` (-1 refuses). Without it, the first collection. |
| `zones` | yes | Groups of LEDs, in color order: `{ name, leds }` (a single row) or `{ name, width, height, map }` (a matrix; `map` has `width × height` positions holding the LED index within the zone, or `-1`). Can be a function `(dev) => zones`, called after `start`. |
| `modes` | no | The hardware's own effects: `[{ id, name, speed, brightness, colors, random }]`. The user picks one on the device screen. Only `id` and `name` are required; the other fields show controls for the effect (see [Hardware effects](#hardware-effects)). Can also be a function. |
| `screen` | no | The device's screen, if it has one: `{ width, height, maxFrames, round }` (`maxFrames` is how many frames it stores, default 100; `round: true` for round screens; `liveValues: n` if the screen draws up to `n` live values by itself, such as the CPU temperature). Shows the Screen tab on the device. Can also be a function. |
| `settings` | no | Options shown in the app: `{ name: { label, type, default, min, max, values, description } }`, with `type` `number`, `boolean`, `color` or `combobox`. On a device with `screen`, the `brightness` option is the screen brightness: it shows up in the app's brightness panel and reaches the plugin already multiplied by the global brightness, within `min` and `max`. |
| `fps` | no | Frames per second for `render` (default 30, max 60). |
| `pollMs` | no | `poll` interval in milliseconds (default 1000). |

## The functions

All of them get `dev` first; `this` is the plugin object itself, so you can
keep state on it (`this.lastColor = ...`).

| Function | When |
|---|---|
| `start(dev)` | When the device is opened. Returning `false` refuses the device. |
| `render(dev, colors)` | Every frame, with the colors of all LEDs (`[r, g, b, r, g, b, ...]`, 0 to 255, brightness already applied). The app only calls it when the colors change. |
| `mode(dev, id, options)` | The user picked a hardware effect (`id` from `modes`) or changed its options, or `null` to go back to the app's colors. |
| `poll(dev)` | Every `pollMs`: read the battery, state and so on. |
| `settingChanged(dev, name, value)` | The user changed an option. |
| `showImage(dev, image)` | The user sent an image or GIF to the screen: `{ width, height, frames, delays }`, with the number of frames and how long each one lasts (ms). Get each frame with `dev.frame(i)` and report progress with `dev.progress(x)`. Live values come in `widgets`: `{ x, y, width, height, color (RGB565), channel, glyphHeight, glyphWidths }`, with the glyphs for "0" to "9", "." and "-" in `dev.widgetGlyphs(i)`. Return `true` if the device accepted it. |
| `values(dev, values)` | Every second, when the screen image has live values: one number (or `null`) per channel, in the order of `image.widgets[i].channel`. |
| `stop(dev)` | The app is closing or the device was disabled. |

## Hardware effects

Each effect in `modes` can declare what the user adjusts:

| Field | What it is |
|---|---|
| `speed` | `{ min, max, default }`: `min` is the slowest and `max` the fastest, even if `min` is the larger number (as on devices that measure speed as time per cycle). |
| `brightness` | `{ min, max, default }`, from dimmest to brightest. |
| `colors` | How many colors the effect uses (`1`), or `{ min, max, default: ['#ff0000', ...] }` to let the user choose how many. Without `default`, the colors start white. |
| `random` | `true` if the device can also pick colors by itself (rainbow). Starts on. |

`mode(dev, id, options)` gets the chosen values (or the `default`s):
`{ speed, brightness, colors: [[r, g, b], ...], random }`, with only the
fields the effect declared. The function is called again on every change, so
send the effect's full command.

```js
modes: [
  { id: 0x02, name: 'Breathing', speed: { min: 0, max: 4, default: 2 }, colors: 1, random: true },
  { id: 0x00, name: 'Off' }
],

mode: function (dev, id, options) {
  if (id === null) return; // the next render sends the app's colors
  var color = options.random ? [0, 0, 0] : options.colors[0];
  dev.write([0x01, id, options.speed, options.random ? 1 : 0].concat(color));
}
```

When `zones`, `modes` or `screen` are functions, they run after `start`,
with `this` being the plugin: they can depend on what `start` found out
(such as the device model).

## The `dev` object

| Member | What it does |
|---|---|
| `dev.info` | `{ vid, pid, serial, product, manufacturer, name }`. |
| `dev.write(bytes)` | Output report; `bytes[0]` is the report ID (0 if the device doesn't use IDs). Padded with zeros up to the report size. Returns the bytes written or -1. |
| `dev.read(size, timeoutMs)` | Next input report (ID 0 removed), or `[]` if nothing arrives in time (default 100 ms). |
| `dev.sendFeature(bytes)` | Feature report; `bytes[0]` is the ID. |
| `dev.getFeature(id, size)` | Reads a feature report. |
| `dev.getInputReport(id, size)` | Reads an input report through the control channel. |
| `dev.clearInput()` | Discards queued input reports. |
| `dev.endpoints()` | All HID collections of the device. |
| `dev.useEndpoint(filter)` | Switches to another collection (e.g. a mouse with short commands on one and long ones on another). |
| `dev.sleep(ms)` | Waits. |
| `dev.log(...)` | Message in the device log. |
| `dev.setting(name)` | Current value of an option. |
| `dev.setBattery(percent, charging)` | Shows the battery in the app. |
| `dev.frame(i)` | Frame `i` of the image going to the screen: `[r, g, b, ...]` row by row, already at the `screen` size. |
| `dev.jpeg(i, quality)` | Frame `i` already encoded as JPEG (quality 10 to 100, default 85), for screens that take JPEG. |
| `dev.widgetGlyphs(i)` | The glyphs of live value `i`: one opacity byte per pixel, glyph after glyph, row by row. |
| `dev.progress(x)` | Progress of a long upload, from 0 to 1 (shown on the Screen tab). |
| `dev.localTime()` | The PC's local time: `[year, month, day, hour, minute, second]`. JavaScript's `Date` here only knows UTC. |

## Good practices

- **Don't write to the device's memory every frame.** Many devices save the
  color when they get the mode command; if that's the case, use the device's
  "don't save" mode (as in `logitech-g403-hero.js`) or limit the rate (as in
  `royuan-keyboard.js`).
- **Don't rewrite what you don't understand.** If the color command also
  carries other settings (sleep timeout, button debounce...), don't trust a
  read to copy them: some devices return a truncated read. Use known values
  or offer them as options (as in `attack-shark-x11.js`).
- **Respect the device's limits.** If a device has a maximum upload size,
  frame count or write rate, enforce it in the plugin; never bypass it to
  squeeze in more.
- If the device only sends the battery level when it isn't busy, stop
  writing once in a while to listen for it (as in `attack-shark-x11.js`).
- In `stop`, leave the device in a sensible state: off, or back to the
  effect saved in it.
- Plugins based on OpenRGB code stay GPL-2.0-or-later: keep the credit and
  the `SPDX-License-Identifier` line at the top, like the bundled ones.

## Testing

`test/plugins_test.dart` runs the bundled plugins against a fake device and
checks the bytes they send. For a new plugin, follow the same pattern:

```powershell
flutter build windows --release
$env:PATH = "$PWD\build\windows\x64\runner\Release;$env:PATH"
$env:OC_PLUGIN_TEST = "1"
flutter test test\plugins_test.dart
```
