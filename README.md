<h1 align="center">Crane</h1>

<p align="center">
  A web platform engine written in Zig: the browser, minus the pixels.
  <br><br>
  <a href="#about">About</a> ·
  <a href="#status">Status</a> ·
  <a href="#building">Building</a> ·
  <a href="#running-the-web-platform-tests">Web Platform Tests</a> ·
  <a href="docs/engine-protocol.md">Engine protocol</a> ·
  <a href="AGENTS.md">Contributing</a>
</p>

> [!IMPORTANT]
> Crane is pre-release. 266 of the 4,323 WPT files in the 0.1 worklist still block, it builds on
> macOS (Apple Silicon) only, and its embedding APIs are not stable.

## About

Crane implements the web platform: the DOM, the HTML parser, scripting, navigation and session
history, fetch, streams, workers, WebSockets, storage, and the rest of what a browser runs. What it
leaves out is deliberate:

- **No pixels, by design.** Rendering and layout belong to the host, through a pluggable layout
  backend. Crane can sit behind a native UI, a test harness, or a headless automation tool.
- **Any JavaScript engine.** The engine is an adapter behind one statically dispatched protocol.
  V8 13.1 runs today; the protocol is designed for JavaScriptCore on iOS as well.
- **Measured by the Web Platform Tests.** Conformance is judged by
  [WPT](https://web-platform-tests.org/), the suite every major browser runs, not by Crane's own tests.
- **Zig all the way down.** About 990,000 lines of Zig in 6,400 files, with explicit allocators and
  a no-leaks rule, plus a 12,700-line C++ wrapper around V8.

## Status

Crane 0.1 means **zero blocking files** (no TIMEOUT, ERROR or CRASH) across the 4,323 WPT files in
[`tests/wpt_0_1_worklist.txt`](tests/wpt_0_1_worklist.txt). The latest full sweep, main `703639a56`
on 2026-09-29, as `zig build wpt-progress` reports it:

```
4,323 of 4,323 sources run  |  266 blocking  |  2,132 clean
subtests: 752,409 passing of 1,116,347 targeted  (67.40%)  |  files clean 49.32%
```

| Area | Files | Blocking | Subtests passing |
| :--- | ---: | ---: | ---: |
| `html/semantics` · elements, forms, scripting, links | 1,127 | 111 | 34.0% |
| `html/browsers` · windows, navigation, history, origins | 567 | 56 | 49.1% |
| `navigation-api` | 414 | 15 | 71.0% |
| `dom` | 374 | 21 | 76.1% |
| `xhr` | 319 | 1 | 89.3% |
| `html/webappapis` · timers, event loop, scripting | 277 | 16 | 87.8% |
| `websockets` | 200 | 0 | 90.2% |
| `html/dom` | 183 | 13 | 88.1% |
| `fetch` | 176 | 1 | 93.0% |
| `custom-elements` | 167 | 3 | 55.9% |
| `encoding` | 149 | 20 | 71.4% |
| `html/syntax` · the parser | 139 | 4 | 59.5% |
| `streams` | 87 | 2 | 94.3% |
| `cookiestore` | 53 | 0 | 82.2% |
| `webidl` | 44 | 0 | 91.2% |
| `url` | 32 | 2 | 77.6% |

Most of `encoding`'s failing subtests wait on one feature in progress: decoding documents in their
declared legacy encoding. `zig build wpt-progress` renders the live report, with per-area history
and the [roadmap](docs/roadmap.toml), to `wpt-results/progress.html`.

## Building

The build is set up for macOS on Apple Silicon. You need:

| Requirement | Notes |
| :--- | :--- |
| Zig 0.16.0 | Exactly this version. |
| V8 13.1, static monolith | In `jsengines/v8/`, which git does not track. [`scripts/build-v8-static.sh`](scripts/build-v8-static.sh) builds it: about 15 GB of disk and 30-60 minutes. |
| Homebrew `sqlite` and `leveldb` | `build.zig` links them from `/opt/homebrew`. |
| Python 3 | For the WPT server. |

```bash
zig build wpt-runner -j2    # the WPT runner
zig build test -j2          # ~4,900 unit tests and the boundary lints
```

> [!WARNING]
> Never run a bare `zig build`. It installs about 19 artifacts, each analysing the whole tree with
> roughly 6 GB of RAM. Name a step and pass `-j2`.

On a machine whose default SDK is macOS 27, `build.zig` builds against the newest 26.x SDK on its
own, because Zig 0.16's bundled libc++ does not compile against 27.

## Running the Web Platform Tests

WPT lives in `tests/wpt`, a submodule of the [zig-whatwg/wpt](https://github.com/zig-whatwg/wpt)
fork. Upstream files are never modified; Crane's own testharness tests live in `tests/wpt/crane/`.

```bash
git submodule update --init tests/wpt
zig build wpt -j2 -- dom/nodes/      # build the runner and run one directory

./zig-out/bin/wpt_runner --from-file=tests/wpt_0_1_worklist.txt \
    --wpt-root=tests/wpt --parallel=3 --output=wpt-results/my-run
zig build wpt-progress -j2           # regenerate wpt-results/progress.html
```

Each run writes a `journal.jsonl`, one record per file, and a wpt.fyi-format report. The progress
report reads journals from `wpt-results/*.jsonl` and `wpt-results/<label>/*.jsonl` only. More in
[`docs/wpt.md`](docs/wpt.md).

## Architecture

**The JavaScript engine is an adapter.** Everything outside `src/runtime/engines/v8/` reaches the
engine through `src/runtime/engine_protocol.zig`, and `-Dengine=v8|jsc|quickjs` picks the adapter
at build time. Only V8 works today; the JavaScriptCore and QuickJS adapters declare every operation
and answer most with `NotSupported`. `zig build test` fails on any V8 reference outside the adapter.
[`docs/engine-protocol.md`](docs/engine-protocol.md) has the whole contract.

**WebIDL is generated.** The code generator reads 341 IDL files (the official definitions from
[w3c/webref](https://github.com/w3c/webref) plus `specs/supplementary/`) and writes 1,262 interfaces
to `src/webidl/interfaces/`, which are committed and never edited by hand. Behind them sit 1,283
hand-written implementations in `src/webidl/impls/`, each reached only through its own generated
interface.

**The host supplies pixels and capabilities.** Layout is a backend the host provides
(`src/platform/layout_backend.zig`). Clipboard, storage, network and the other platform
capabilities are tables the host fills in, exported over a C ABI (`src/platform/exports.zig`). The
tree links for `aarch64-ios` as well as macOS.

<details>
<summary>What is in <code>src/</code></summary>

| Group | Subsystems |
| :--- | :--- |
| DOM and HTML | `dom`, `html` (parser, scripting, navigation and session history, the navigation API, frames, forms), `css`, `selector`, `quirks`, `trusted_types`, `csp`, `permissions` |
| Networking | `fetch` (libcurl, HTTP/2 through nghttp2), `xhr`, `websocket`, `cookiestore`, `referrer_policy`, `mimesniff`, `url`, `urlpattern` |
| Script | `webidl` (bindings and code generation), `runtime` (the engine protocol and adapters), workers, `service_worker`, `streams`, `console`, `hr_time` |
| Storage and files | `storage`, `fs`, `file` |
| Text | `encoding`, `infra`, `intl` (CLDR) |
| Embedding | `platform` (capabilities, layout backend), `browser`, `webdriver` (does not build on Zig 0.16 yet) |

</details>

## Embedding

- **Zig:** the `whatwg` module, rooted at `src/root.zig`.
- **C:** `whatwg_runtime_init` / `_shutdown`, `whatwg_browser_create` / `_navigate` / `_evaluate` /
  `_destroy`, `whatwg_version` and `whatwg_interface_count` (`src/lib_exports.zig`), plus the
  `whatwg_platform_*` capability API (`src/platform/exports.zig`).
- **Swift and Kotlin:** `bindings/` holds prototypes from December 2025.

> [!NOTE]
> Three things here are out of date: `include/whatwg.h` declares 14 functions nothing exports
> (among them the whole `whatwg_context_*` family); the Swift and Kotlin bindings predate the engine
> protocol, and their SwiftUI view draws a placeholder; and GitHub CI is red on a clean checkout,
> because nothing provisions V8 and `build.zig` expects Homebrew paths
> (`.github/workflows/test.yml` explains).

## Contributing

[`AGENTS.md`](AGENTS.md) is the rulebook, for people and agents alike: spec algorithms step by step
with numbered comments, a failing test first, WPT as the bar, no memory leaks, never a hand-edited
generated file, and the impls and engine boundaries that `zig build test` enforces. What past work
taught is indexed in [`docs/lessons/README.md`](docs/lessons/README.md). See also
[`CONTRIBUTING.md`](CONTRIBUTING.md).

## License

MIT. Copyright (c) 2025 Brian Cardarella. See [`LICENSE`](LICENSE).
