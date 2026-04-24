# MyTomato — Agent Instructions

MyTomato customizes a FreshTomato/TomatoUSB ARMv7 router environment (tested on Netgear R7000). Scripts run on the router under `ash`/`sh` at boot but are authored in `bash` on the development machine.

## Key references

- [README.md](README.md) — Install steps, USB preparation, feature list
- [Changelog.md](Changelog.md) — Version history and recent changes
- [root/SCRIPTs/inc/vars](root/SCRIPTs/inc/vars) — All global variables (paths, flags, binaries)
- [root/SCRIPTs/inc/funcs](root/SCRIPTs/inc/funcs) — All shared functions

## Repository layout

| Path                   | Purpose                                                                                               |
| ---------------------- | ----------------------------------------------------------------------------------------------------- |
| `root/SCRIPTs/`        | Main scripts: `Services_Start/Stop.sh`, `USB_AfterMounting.sh`, `Upgrade.sh`, `Environment_Config.sh` |
| `root/SCRIPTs/inc/`    | `vars` (global config), `funcs` (shared library), `ARM-Extras/` (kernel modules)                      |
| `root/TEMPLATEs/`      | `*.tmpl` files copied at runtime to `/opt/etc/init.d/` and config dirs                                |
| `root/ConfigOverload/` | User overrides (gitignored): `vars`, custom init scripts, DNS/P2P configs                             |
| `root/OpenVPN/`        | OpenVPN client/server config directories                                                              |
| `P2Partisan/`          | `p2partisan.sh` — IP blocklist manager (v6.x)                                                         |
| `ci/scripts/`          | CI pipeline: version check (`10-`), ShellCheck (`30-`), template validation (`40-`)                   |

## Naming conventions

**Variables** — always follow these prefixes:

| Prefix    | Type                                   | Example                     |
| --------- | -------------------------------------- | --------------------------- |
| `gs`      | Global string                          | `gsScriptName`, `gsDirLogs` |
| `gb`      | Global boolean (0/1)                   | `gbP2Partisan_Enable`       |
| `gn`      | Global number                          | `gnExitCode`                |
| `gd`      | Global datetime                        | `gdDateTime`                |
| `bin`     | Binary command alias                   | `binCurl`                   |
| `s` / `n` | Local string/number (inside functions) | `sValue`, `nCommit`         |

**Functions** — prefix `gfn` for all shared functions:
```bash
gfnMyFunction() {
    local sArg="${1}"
    ...
}
```

## Sourcing pattern

```bash
#!/usr/bin/env bash
# shellcheck disable=SC1091
# shellcheck source=root/SCRIPTs/inc/vars
. /opt/MyTomato/root/SCRIPTs/inc/vars
[[ -f ${gsDirOverLoad}/vars ]] && . "${gsDirOverLoad}/vars"
# shellcheck source=root/SCRIPTs/inc/funcs
. /opt/MyTomato/root/SCRIPTs/inc/funcs
```

Always source `inc/vars` before `inc/funcs`. Never hardcode paths — use the `gs*` directory variables.

## ShellCheck

- All scripts must pass ShellCheck. Run: `shellcheck -s bash <file>`
- Use `# shellcheck disable=SC<code>` inline, not globally, and only when necessary
- SC1091 (can't follow sourced files) is disabled at file level — that's expected
- Variable quoting: always quote `"${var}"` except in `[[ ]]` tests where word-splitting is not an issue — but quote when the value may contain spaces or special characters

## CI validation

```bash
# Syntax check (no execution)
bash -n ci/scripts/30-check_bash.sh

# Run full CI locally (requires shellcheck, dos2unix, xz, rsync)
bash ci/scripts/00-libs.sh
bash ci/scripts/10-check_versions.sh
bash ci/scripts/30-check_bash.sh
bash ci/scripts/40-check_project.sh
```

CI checks: ShellCheck on all `*.sh`/`*.tmpl`, syntax validation (`bash -n`), orphan function detection, unused/missing template detection.

## Template system

Templates in `root/TEMPLATEs/` are plain shell/config files with `.tmpl` extension. At runtime, `Environment_Config.sh` copies them with `cp` (no variable substitution engine — variables are evaluated at shell source time). User overrides go into `root/ConfigOverload/` (gitignored).

When adding a new service init script, add both:
1. `root/TEMPLATEs/init/S<nn><name>.tmpl`
2. A corresponding entry in `root/SCRIPTs/inc/funcs` (start/stop function)

## Logging

Use `logger` for runtime log messages (goes to syslog):
```bash
logger -p user.notice "| ${gsScriptName} | My message"
```

Do not use `echo` for logging in production scripts.

## .profile / login shell

`root/.profile` is mounted at `/tmp/home/root/.profile` on the router. It detects bash availability and launches bash. The router's default shell is `ash` (BusyBox), so scripts must use `#!/usr/bin/env bash` and not rely on bash being the login shell during early boot.

## What is gitignored

- `root/ConfigOverload/*` (except `.gitkeep`) — user-specific overrides
- `P2Partisan/*` except `p2partisan.sh` — runtime blocklists
- `root/BACKUPs/`, `root/SCRIPTs/inc/ARM-Extras/` — generated at runtime
