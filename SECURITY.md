# Security policy

OpenChroma runs with high privileges on purpose: it can run as
administrator, installs a kernel driver (PawnIO) and talks directly to
hardware. Security reports are taken seriously.

## Supported versions

Only the **latest release** gets security fixes. Please check that the
problem still happens on the newest version from
[Releases](https://github.com/Dnowdd/OpenChroma/releases) (or on `main`)
before reporting.

| Version | Supported |
|---|---|
| Latest release | Yes |
| Older releases | No |

## Reporting a vulnerability

**Please don't open a public issue, discussion or pull request for security
problems.**

Report it privately through GitHub's Private Vulnerability Reporting:

1. Go to the repository's **Security** tab.
2. Click **Report a vulnerability**.
3. Describe the problem, the affected version, the steps to reproduce it and
   the impact. A proof of concept helps a lot.

Only the maintainer sees the report. We can discuss it, work on a fix and
credit you (if you want) in the same private advisory.

## Scope

In scope, for example:

- **Privilege escalation** through the "always run as administrator" /
  start with Windows scheduled task, the elevation flow, or any other path
  that lets a standard user or another program run code as administrator.
- **Plugin sandbox escapes:** a device plugin (JavaScript running in
  QuickJS) reading or writing files, reaching the network, touching devices
  it didn't claim, or running native code.
- **The installer** (`OpenChroma-x.y.z-setup.exe`): unsafe file permissions,
  DLL hijacking, or a tampered bundled PawnIO setup or WebView2 bootstrapper.
- **API key storage:** weaknesses in how the assistant's API keys are
  protected with DPAPI or how they're sent to providers.
- **The WebView2 effect host:** an imported HTML effect escaping the page,
  reaching the app or the system beyond what an effect needs.
- Imported `.ocfx` files or images that crash the app in an exploitable way
  or run code.

Out of scope:

- Problems in third-party components (OpenRGB, PawnIO, QuickJS, hidapi,
  libusb, WebView2) that don't come from how OpenChroma uses them; please
  report those upstream. If OpenChroma ships a vulnerable version, that is
  in scope.
- Attacks that already require administrator rights or physical access.
- Hardware damage caused by a device's normal, documented behavior (see the
  [disclaimer](README.md#disclaimer--use-at-your-own-risk)). A bug that lets
  untrusted input trigger harmful hardware writes is in scope.
- The SmartScreen warning caused by the missing code signature (known; see
  the [ROADMAP](ROADMAP.md)).

## What to expect

OpenChroma is a hobby project maintained by one person in spare time, so
responses are **best effort**:

- An acknowledgement, usually within a week.
- An assessment and, if the report is valid, a fix in a new release as soon
  as reasonably possible. Critical issues get priority.
- A published GitHub security advisory once a fixed version is available,
  crediting the reporter unless they prefer otherwise.

Please give us reasonable time to release a fix before disclosing the
problem publicly.
