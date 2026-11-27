<h1 align="center">Crane</h1>

<p align="center">
  A headless web platform engine written in Zig &mdash; the browser, minus the pixels.
  <br><br>
  <a href="#results">Results</a> &middot;
  <a href="#what-crane-01-ships">What 0.1 Ships</a> &middot;
  <a href="#quickstart-crane-cli">CLI</a> &middot;
  <a href="#mcp-for-ai-agents">MCP</a> &middot;
  <a href="#playwright-and-puppeteer">Playwright &amp; Puppeteer</a> &middot;
  <a href="#embedding-crane-lib">Embedding</a> &middot;
  <a href="#building-from-source">Building with V8</a> &middot;
  <a href="#architecture">Architecture</a> &middot;
  <a href="#contributing--reporting-bugs">Contributing</a>
</p>

Crane implements the web platform in Zig &mdash; DOM, HTML parser, CSS cascade and style invalidation, Fetch, HTTP/2, WebSockets, Service Workers, IndexedDB, Web Storage, WebCrypto, Streams, Accessibility, and a 15-source HTML Event Loop &mdash; paired with V8 15.7 (with ICU and Temporal), Chrome DevTools Protocol (CDP), and a built-in Model Context Protocol (MCP) server.

**No layout or pixel rendering in 0.1, by design.** Rendering and layout belong to the host behind a pluggable layout backend ([`src/platform/layout_backend.zig`](src/platform/layout_backend.zig)). Everything non-visual runs through the same web specifications and algorithms as Chrome, Firefox, and Safari.

---

## Results

Every claim below is measured continuously and published as static HTML on GitHub Pages:

| Report | Headline | Live Dashboard |
| :--- | :--- | :--- |
| **Web Platform Tests** | **`1,905,777 / 1,913,850`** subtests passing (**`99.58%`**) across **`14,346`** files in 67 suites &middot; **`0` blocking** (0.1 gate met) &middot; **`98.9%`** outside `encoding/` &middot; **`96.2%`** mean per-file &middot; **`602 / 602`** WPT crashtests clean | [zig-whatwg.github.io/crane/](https://zig-whatwg.github.io/crane/) |
| **JavaScript Frameworks** | **`19,672 / 19,692`** (**`99.9%`**) across 6 frameworks' own browser test suites + **`826 / 1,202`** across 43 TodoMVC apps (Chrome: `827 / 1,202`) | [zig-whatwg.github.io/crane/frameworks/](https://zig-whatwg.github.io/crane/frameworks/) |
| **Performance & Memory** | Round 12 (`ReleaseSafe`): **`11%`** of Chrome's steady memory, **`6%`** of Firefox, **`22%`** of Safari, **`60%`** of Lightpanda, **`19%`** of Ladybird Alpha (`14.0 MB` idle page, `148 B` per parsed `<span>`) | [zig-whatwg.github.io/crane/performance/](https://zig-whatwg.github.io/crane/performance/) |
| **MCP Parity** | **`34 / 39`** differential cases equal (+4 expected diffs) against `chrome-devtools-mcp` v1.13.0 across 38 matching tools | [zig-whatwg.github.io/crane/mcp/](https://zig-whatwg.github.io/crane/mcp/) |

### WPT Beside Chrome 157

On the `13,571` common test files run in the same window (WPT revision `f7d81dcadf`, 5 runners each):

| Engine | Subtests Passing | Blocking Files | Clean Files |
| :--- | ---: | ---: | ---: |
| **Crane** (Gen 241, `8e14eb4dc` / `bec71f98e`) | **`1,901,977 / 1,909,689`** | **`0`** | **`12,710`** |
| **Chrome 157.0.8103.78** (headless, `wpt run`) | `1,885,719 / 1,909,693` | `466` | `11,987` |

Both production and bug-finding builds pass **`602 / 602`** WPT crashtests ([`tests/wpt_0_1_crashtests.txt`](tests/wpt_0_1_crashtests.txt)) with zero crashes, leaks, poison reads, or unexpected allocator rungs.

### JavaScript Frameworks

Each framework's own browser test suite run in Crane beside Chrome (`054e1499f2`, [full report](https://zig-whatwg.github.io/crane/frameworks/)):

| Framework | Crane | Chrome | Notes |
| :--- | ---: | ---: | :--- |
| **Angular 22.2.6** | **`13,116 / 13,128`** (`99.9%`) | `13,165 / 13,165` (`100.0%`) | 15 need renderer, 6 follow ruling, 96 skipped upstream |
| **React 19.3.1** | **`3,538 / 3,540`** (`99.9%`) | `3,531 / 3,540` (`99.7%`) | Ahead of Chrome by +0.2 pts on the same tests |
| **htmx 4.0.1** | **`1,773 / 1,773`** (`100.0%`) | `1,773 / 1,773` (`100.0%`) | Even with Chrome |
| **jQuery 4.0.0** | **`1,066 / 1,072`** (`99.4%`) | `1,144 / 1,147` (`99.7%`) | 76 need renderer |
| **Svelte 5.57.3** | **`97 / 97`** (`100.0%`) | `97 / 97` (`100.0%`) | Even with Chrome |
| **Vue 3.5.45** | **`82 / 82`** (`100.0%`) | `82 / 82` (`100.0%`) | Even with Chrome |
| **Total (6 frameworks)** | **`19,672 / 19,692`** (`99.9%`) | `19,792 / 19,804` (`99.9%`) | |
| **TodoMVC (43 apps)** | **`826 / 1,202`** (`68.7%`) | `827 / 1,202` (`68.8%`) | Same tests through the same port |

### Performance & Memory (Round 12)

Geometric means across shared workloads in Round 12 (`369e0c50b` / `e38d1abcf`, Crane `ReleaseSafe`, Apple M4 Pro; lower is better for Crane, [full report](https://zig-whatwg.github.io/crane/performance/)):

| Browser | Version | Crane Steady Memory | Crane Time |
| :--- | :--- | ---: | ---: |
| **Chrome** | `157.0.8103.38` | **`11%`** | `304%` |
| **Firefox** | `159.0.1` | **`6%`** | `262%` |
| **Safari** | `27.2 (22625.2.8.11.9)` | **`22%`** | `300%` |
| **Lightpanda** | `1.1.0-nightly.11745+1b60dcc7a` | **`60%`** | `282%` |
| **Ladybird Alpha** | `2026.47.8` | **`19%`** | `188%` |

- **Footprint:** `14.0 MB` idle page; `148 B` per parsed `<span>` (`innerHTML`), `251 B` per `<div>` in document, `255 B` per kept `<div>`, `239 B` per text node.
- **Progress since Round 0:** `41.4%` of Round 0's time and `19.7%` of Round 0's steady memory, including a **`-36%`** steady memory drop in Round 12 from the 4-partition hardened allocator.

---

## What Crane 0.1 Ships

1. **`crane` CLI** (`zig build crane` / `zig build crane-release`)
   - Single self-contained headless browser binary compiled in **`ReleaseSafe`** with debug symbols preserved and an issue-reporting crash handler.
   - All external C/C++ libraries statically compiled in (V8 15.7 + ICU data, Chromium hardened `libc++`, Temporal Rust, libcurl, mbedTLS, nghttp2, zlib, brotli, libjpeg-turbo, expat, nanosvg, SQLite).
   - **CDP enabled** (`127.0.0.1:9222` by default) and **MCP enabled** (`127.0.0.1:9223` Streamable HTTP by default, or stdio with `--mcp`).
2. **`crane-lib` (Zig Module + C ABI)**
   - High-level Zig dependency (`dep.module("crane")`) via `build.zig.zon`.
   - Thread-safe C-ABI static library (`dep.artifact("crane-lib")` &rarr; `libcrane.a` + [`include/crane.h`](include/crane.h)) supporting isolated multi-threaded `Browser` instances, tabs, navigation readiness, script evaluation, event callbacks, dialog handling, and embedded MCP servers.

---

## Quickstart: `crane` CLI

### Default Daemon Mode

Running `crane` starts a headless browser daemon with CDP and Streamable HTTP MCP active, streaming live activity logs (navigations, `console.*` output, uncaught errors) to your terminal until `Ctrl-C`:

```bash
# Start with about:blank, serving CDP on 127.0.0.1:9222 and MCP on 127.0.0.1:9223
crane

# Start and load an initial URL
crane https://example.com
```

On startup, `crane` prints the CDP WebSocket endpoint, the MCP HTTP endpoint, and the generated 256-bit Bearer token (plus TLS certificate SHA-256 fingerprint when `--mcp-tls` or a non-loopback `--mcp-host` is used).

### MCP for AI Agents

Crane includes a native Model Context Protocol server matching `chrome-devtools-mcp` &mdash; no Node.js wrapper or separate Chrome binary required.

#### Stdio Mode (`crane --mcp`)

**Claude Code:**

```bash
claude mcp add crane -- crane --mcp
```

**Claude Desktop** (`claude_desktop_config.json`):

```json
{
  "mcpServers": {
    "crane": {
      "command": "crane",
      "args": ["--mcp"]
    }
  }
}
```

#### Streamable HTTP Mode

The default `crane` daemon serves Streamable HTTP MCP on `http://127.0.0.1:9223/mcp` protected by a mandatory 256-bit Bearer token (`Authorization: Bearer <token>`). Configure host, port, or TLS explicitly:

```bash
# Custom port with TLS on loopback (ephemeral self-signed ECDSA P-256 cert)
crane --mcp-port=9223 --mcp-tls

# Non-loopback bind (TLS is mandatory; supply PEM cert/key or use ephemeral cert)
crane --mcp-host=0.0.0.0 --mcp-port=9223 --mcp-cert=cert.pem --mcp-key=key.pem
```

Optional MCP flags: `--slim` (minimal tool surface), `--categoryNetworkMocks` (network interception/mocking tools), `--memoryDebugging` (V8 `.heapsnapshot` analysis tools), `--isolated`, `--viewport=<WxH>`, `--acceptInsecureCerts`.

### Playwright and Puppeteer

Crane speaks Chrome DevTools Protocol (CDP) over both TCP (`--remote-debugging-port`) and inherited pipes (`--remote-debugging-pipe`), accepting standard Chrome launcher switches.

**Connect to a running `crane` daemon:**

```js
// Playwright
import { chromium } from "playwright-core";

const browser = await chromium.connectOverCDP("http://127.0.0.1:9222");
const page = await browser.contexts()[0].newPage();
await page.goto("https://example.com");
console.log(await page.title());
await browser.close();
```

```js
// Puppeteer
import puppeteer from "puppeteer-core";

const browser = await puppeteer.connect({
  browserURL: "http://127.0.0.1:9222", // or browserWSEndpoint: "ws://127.0.0.1:9222/devtools/browser/..."
});
const page = await browser.newPage();
await page.goto("https://example.com");
console.log(await page.title());
await browser.disconnect();
```

**Or launch `crane` directly as the browser executable:**

```js
// Puppeteer
const browser = await puppeteer.launch({
  executablePath: "/path/to/crane",
});

// Playwright
const browser = await chromium.launch({
  executablePath: "/path/to/crane",
});
```

---

## Embedding (`crane-lib`)

A complete, runnable consumer project lives in [`examples/zig-consumer/`](examples/zig-consumer/).

### Zig Dependency (`build.zig.zon` + `build.zig`)

Fetch Crane into your project:

```bash
zig fetch --save git+https://github.com/zig-whatwg/crane#v0.1.0
```

That adds Crane to your `build.zig.zon`:

```zig
.{
    .name = .my_app,
    .version = "0.1.0",
    .dependencies = .{
        .crane = .{
            .url = "git+https://github.com/zig-whatwg/crane#v0.1.0",
            .hash = "<populated by zig fetch --save>",
        },
    },
    .paths = .{ "build.zig", "build.zig.zon", "src" },
}
```

Wire the high-level Zig module (or the C-ABI static library) in `build.zig`:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const crane_dep = b.dependency("crane", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "my-app",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                // High-level Zig module
                .{ .name = "crane", .module = crane_dep.module("crane") },
            },
        }),
    });

    // Or link the C-ABI static library (libcrane.a + include/crane.h):
    // exe.root_module.linkLibrary(crane_dep.artifact("crane-lib"));

    b.installArtifact(exe);
}
```

### Zig Example

```zig
const std = @import("std");
const crane = @import("crane");

pub fn main() !void {
    const allocator = std.heap.c_allocator;

    // Start the process once before creating any Browser.
    var proc = try crane.Process.init(.{});
    defer proc.deinit();

    // Start an isolated Browser on its own thread.
    const host = try crane.BrowserHost.start(allocator, .{});
    defer host.stop();

    const tab = try host.createTab(.{});
    const url = try host.navigate(allocator, tab, "https://example.com", .{
        .wait = .complete,
    });
    defer allocator.free(url);

    const result = try host.evaluate(allocator, tab, "document.title", .{}, 30_000);
    defer result.deinit(allocator);

    std.debug.print("URL: {s}\nTitle JSON: {s}\n", .{ url, result.json });
}
```

### C Example (`libcrane.a` + `include/crane.h`)

Every call in [`include/crane.h`](include/crane.h) is thread-safe and blocks until the Browser's thread responds. Options structs begin with `struct_size` for forward ABI compatibility:

```c
#include <stdio.h>
#include <string.h>
#include "crane.h"

int main(void) {
    crane_process_options_t proc_opts = { .struct_size = sizeof(proc_opts) };
    if (crane_process_init(&proc_opts) != CRANE_OK) return 1;

    crane_browser_options_t browser_opts = { .struct_size = sizeof(browser_opts) };
    crane_browser_t *browser = NULL;
    if (crane_browser_create(&browser_opts, &browser) != CRANE_OK) {
        crane_process_shutdown();
        return 1;
    }

    crane_tab_id tab = 0;
    crane_tab_create(browser, NULL, false, &tab);

    crane_navigate_result_t nav = {0};
    crane_tab_navigate(browser, tab, "https://example.com", CRANE_READY_COMPLETE, &nav);

    const char *script = "document.title";
    crane_evaluate_result_t eval = {0};
    crane_tab_evaluate(browser, tab, script, strlen(script), 0, &eval);

    printf("URL: %s\nResult: %s\n", nav.url ? nav.url : "", eval.json ? eval.json : "");

    crane_evaluate_result_free(&eval);
    crane_navigate_result_free(&nav);
    crane_browser_destroy(browser);
    crane_process_shutdown();
    return 0;
}
```

---

## Building from Source

Supported build hosts: **macOS (`aarch64` / Apple Silicon)** and **Linux (`x86_64`)**.

### Prerequisites

| Requirement | Version / Notes |
| :--- | :--- |
| **Pinned Zig** | **`0.17.1-dev+77c319a0f0`** (0.17.x branch at `77c319a0f00a`), available from Crane's GitHub toolchain release (or `0.17.1+` once released). **`zig 0.17.0` is intentionally refused** by `build.zig` ([`tools/zig_toolchain.zig`](tools/zig_toolchain.zig)) due to `ziglang/zig#37061` (mobile Apple targets) and `ziglang/zig#37142` (`checkAllAllocationFailures` resizes). |
| **V8 15.7.112.43 (with ICU)** | Chrome 157's V8 built against Chromium's hardened `libc++` (`std::__Cr`), with ICU data and Temporal enabled. Choose **Option A, B, or C** below. System/Homebrew V8 packages are not compatible. |
| **Python 3** | Required for running the WPT server (`tests/wpt`) and for compiling V8 from source (`lzma` module required). |

> [!WARNING]
> **Never run a bare `zig build`.** Always name a step and pass `-j2` (e.g. `zig build crane -j2`). A bare build compiles ~19 artifacts in parallel, each analyzing the full WebIDL graph (~6 GB RAM each).

### Getting V8 (`15.7.112.43` with ICU)

Crane links V8 `15.7.112.43` (commit `307108153d1e35e6e74528ee55f97b0cd59bf182`). Pick the path that fits your workflow &mdash; full technical details (Chromium `libc++`, ICU static data, Temporal Rust repacking, Linux ELF `SHT_CREL` handling, and troubleshooting) live in [`docs/building-v8.md`](docs/building-v8.md).

#### Option A &mdash; Prebuilt V8 Tarballs (Fastest)

Download the prebuilt V8 archive for your host (`macos-aarch64` or `linux-x86_64`) from the [`v8-prebuilt-15.7.112.43`](https://github.com/zig-whatwg/crane/releases/tag/v8-prebuilt-15.7.112.43) GitHub pre-release, unpack it, verify `SHA256SUMS`, and point Crane at it with `-Dv8-dir`:

```bash
# Example: unpack to /path/to/v8-15.7.112.43-icu (or jsengines/v8/15.7.112.43-icu)
tar -xf v8-15.7.112.43-icu-<platform>.tar.zst -C /path/to/
(cd /path/to/v8-15.7.112.43-icu && sha256sum -c SHA256SUMS)   # macOS: shasum -a 256 -c SHA256SUMS

# Build the release crane CLI
zig build crane-release -j2 -Dv8-dir=/path/to/v8-15.7.112.43-icu
```

If unpacked into the default path `jsengines/v8/15.7.112.43-icu/`, `-Dv8-dir` can be omitted.

#### Option B &mdash; Statically Compiling V8 from Source (Default for `crane`)

Produces a self-contained static monolith (`libv8_monolith.a`, `libv8_libplatform_fat.a`, `libv8_libbase_fat.a`, `libc++_chromium.a`, `librust_v8.a`) with ICU data linked into the archive so `crane` ships as one binary with no external `icudtl.dat` or shared libraries. Requires ~25 GB free disk while building (and Xcode on macOS).

```bash
# Run all steps: deps -> checkout -> build -> rust -> verify -> smoke -> install
scripts/build-v8-15.7.sh all

# Optional: delete ~10 GB of Ninja intermediates after install
scripts/build-v8-15.7.sh clean

# Build Crane linked statically against the installed V8
zig build crane-release -j2 -Dv8-link=static -Dv8-dir=jsengines/v8/15.7.112.43-icu
```

Underlying GN arguments written by `scripts/build-v8-15.7.sh`:

```gn
is_component_build = false
v8_monolithic = true
v8_use_external_startup_data = false
is_debug = false
symbol_level = 0
v8_enable_sandbox = true
v8_enable_pointer_compression = true
v8_enable_gdbjit = false
v8_enable_disassembler = false
v8_enable_object_print = false
v8_enable_verify_heap = false
v8_enable_trace_maps = false
v8_enable_test_features = false
v8_enable_v8_checks = false
v8_enable_i18n_support = true
icu_use_data_file = false
clang_use_chrome_plugins = false
treat_warnings_as_errors = false
use_custom_libcxx = true
use_siso = false
v8_enable_partition_alloc = false
v8_enable_temporal_support = true
v8_generate_external_defines_header = true
cppgc_enable_object_names = false
cppgc_enable_object_section_gcinfo = false
target_cpu = "arm64"   # "x64" on Linux x86_64
# Linux only:
use_sysroot = false
use_glib = false
```

#### Option C &mdash; Dynamically Compiling V8 from Source

Useful for faster iterative relinks during development when you want V8 built as shared component libraries instead of a static monolith:

```bash
# Build V8 as shared component libraries
scripts/build-v8-15.7.sh --dynamic all

# Build Crane linked dynamically against the shared V8 libraries
zig build crane -j2 -Dv8-link=dynamic -Dv8-dir=jsengines/v8/15.7.112.43-icu-dynamic
```

Underlying GN argument differences from static (all sandbox, `use_custom_libcxx`, ICU, Temporal, and external-defines flags remain identical):

```gn
is_component_build = true
v8_monolithic = false
```

**Runtime library search paths (dynamic builds):**

- **macOS:** Set `DYLD_LIBRARY_PATH` to the installed V8 shared library directory (e.g. `DYLD_LIBRARY_PATH=jsengines/v8/15.7.112.43-icu-dynamic/out/dynamic ./zig-out/bin/crane`) or embed an rpath (`-Wl,-rpath,...`) pointing to it.
- **Linux:** Set `LD_LIBRARY_PATH` to the installed V8 shared library directory (e.g. `LD_LIBRARY_PATH=jsengines/v8/15.7.112.43-icu-dynamic/out/dynamic ./zig-out/bin/crane`) or embed an rpath (`-Wl,-rpath,...`).

See [`docs/building-v8.md`](docs/building-v8.md) for why Chromium's hardened `libc++` is mandatory with V8's sandbox, how `v8-gn.h` and `librust_v8.a` are extracted, and why Linux builds strip `SHT_CREL` relocations for Zig's self-hosted ELF linker.

### Common Build & Test Commands

```bash
zig build crane -j2              # Build the crane CLI (development / fast iteration)
zig build crane-release -j2      # Build the release crane CLI (ReleaseSafe + debug symbols)
zig build test -j2               # Unit tests, codegen-check, crane-check, and all boundary lints
zig build test-browser -j2       # Browser initialization & host API tests
zig build wpt-runner -j2         # Production WPT runner (same build & allocator graph as crane-release)
zig build wpt-runner-bug-finding -j2  # Bug-finding WPT runner (debug allocator, poison-on-free, C sanitizers)
```

---

## Architecture

- **Spec-faithful Web Platform in Zig:** `5,877` Zig source files implementing WHATWG and W3C algorithms step by step with numbered spec comments &mdash; DOM, HTML + speculative parser, CSS cascade and selective style invalidation (including Forced Colors and Media Queries), Fetch + HTTP/1.1 + HTTP/2 + WebSockets over HTTP/2 (RFC 8441), Service Workers, IndexedDB, Web Storage, WebCrypto, Streams, WebVTT, Geolocation, Accessibility tree, Isolated Worlds, HTML5 Drag & Drop, and a 15-source HTML Event Loop.
- **Generated WebIDL Bindings:** `338` upstream IDL files from [w3c/webref](https://github.com/w3c/webref) plus `14` supplementary IDLs (`specs/supplementary/`) generate `1,249` interfaces in `src/webidl/interfaces/`, backed by `1,265` hand-written implementations in `src/webidl/impls/`. Generated files are committed and verified by `codegen-check`; each impl is compiled as its own module and reachable only through its generated interface (`check-impls-boundary`).
- **Hardened 4-Partition Per-Browser Allocator:** Each `Browser` isolates its allocations into four partitions &mdash; `.node` (DOM nodes), cage `.satellite` (rare data, listener lists, attributes, `ElementStyle`), `.objects` (platform objects with lock-free per-agent caches and a 512 KiB task-scoped quarantine), and `.bytes` (string and codec buffers) &mdash; with 200 ms idle bitmap decommit back to the OS.
- **Clean Engine & Platform Build Protocols:**
  - **Engine protocol** ([`docs/engine-protocol.md`](docs/engine-protocol.md)): All V8 types and FFI calls are confined to `src/runtime/engines/v8/`. Everything else calls the statically dispatched `engine` protocol (`-Dengine=v8|jsc|quickjs`; V8 runs today, with JSC and QuickJS adapters scaffolded behind the same contract).
  - **Platform protocol** ([`docs/platform-protocol.md`](docs/platform-protocol.md)): OS access (sockets, threads, clocks, storage, TLS, codecs) sits behind `src/platform/`. `build.zig` names no engine, OS, or platform library (`lint-build`), and `zig build test` enforces every boundary automatically (`lint-impls`, `lint-engine`, `lint-platform`, `lint-global-state`, `lint-refcount`, `lint-objects-bytes`, `lint-build`).

<details>
<summary>Subsystem map (<code>src/</code>)</summary>

| Group | Modules |
| :--- | :--- |
| **DOM, HTML & Style** | `dom`, `html` (parser, speculative preload, scripting, navigation, session history, Navigation API, frames, forms, DnD, dialogs), `css`, `selector`, `quirks`, `xml`, `trusted_types`, `csp`, `permissions` |
| **Networking** | `fetch` (libcurl 8.18.0 fork, HTTP/2 via nghttp2 1.70.0, TLS via mbedTLS 3.6.6), `xhr`, `websocket` (H1 + H2 RFC 8441), `eventsource`, `cookiestore`, `referrer_policy`, `mimesniff`, `url`, `urlpattern`, `compression` |
| **Script & Workers** | `webidl` (codegen, generated interfaces, isolated impls), `runtime` (engine protocol, V8 adapter, 4-partition heap), `service_worker`, `streams`, `console`, `hr_time`, `webcrypto` |
| **Storage & Files** | `storage` (IndexedDB, Web Storage, Cache API, SQLite / in-memory stores), `fs`, `file` |
| **Text & Intl** | `encoding`, `infra`, `intl` (ICU + CLDR) |
| **Browser & Automation** | `browser` (`Browser`, `BrowserHost`, 15-source event loop, isolated worlds, bfcache, C ABI), `devtools` (CDP + Streamable HTTP & stdio MCP), `webdriver`, `platform` (capabilities + pluggable `layout_backend`), `process` |

</details>

---

## Running the Web Platform Tests

WPT lives in `tests/wpt`, a submodule of [zig-whatwg/wpt](https://github.com/zig-whatwg/wpt). Upstream test files are never modified; Crane's own testharness tests live in `tests/wpt/crane/`.

```bash
git submodule update --init tests/wpt

# Build the production WPT runner and run a directory
zig build wpt -j2 -- dom/nodes/

# Run the full 0.1 worklist directly
./zig-out/bin/wpt_runner --from-file=tests/wpt_0_1_worklist.txt \
    --wpt-root=tests/wpt --parallel=4 --output=wpt-results/my-run

# Regenerate the local progress report
zig build wpt-progress -j2
```

WPT is judged in two builds of the same tree: the **production** runner (`wpt_runner`, matching `crane-release` exactly) for conformance counts and timings, and the **bug-finding** runner (`wpt_runner_bug_finding`, adding debug allocator, poison-on-free, Debug checks, and C sanitizers) to catch crashes, leaks, and memory safety bugs. See [`docs/wpt.md`](docs/wpt.md) for full details.

---

## Contributing & Reporting Bugs

- **Found a bug or crash?** Open an issue at **[github.com/zig-whatwg/crane/issues/new](https://github.com/zig-whatwg/crane/issues/new)**.
  - Release builds of `crane` compile in `ReleaseSafe` with debug symbols preserved and print a symbolicated stack trace alongside a built-in crash report checklist &mdash; paste that output directly into your issue along with the URL or minimal reproducer.
- **Contributing code:** Read [`AGENTS.md`](AGENTS.md) first (the engineering rulebook for humans and agents alike): implement spec algorithms step by step, write a failing test first, keep zero leaks, never hand-edit generated WebIDL files, and pass all `zig build test` boundary lints.
- **Further docs:** [`docs/building-v8.md`](docs/building-v8.md) &middot; [`docs/console.md`](docs/console.md) &middot; [`docs/instances.md`](docs/instances.md) &middot; [`docs/engine-protocol.md`](docs/engine-protocol.md) &middot; [`docs/platform-protocol.md`](docs/platform-protocol.md) &middot; [`docs/roadmap.toml`](docs/roadmap.toml) &middot; [`docs/lessons/README.md`](docs/lessons/README.md) &middot; [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

---

## License

MIT. Copyright (c) 2025 Brian Cardarella. See [`LICENSE`](LICENSE).
