# Crane

Crane is a web platform engine written in Zig: the DOM, the HTML parser,
scripting, navigation and session history, fetch, streams, workers, WebSockets,
storage and the rest of what a browser runs. Rendering and layout are the one
deliberate exclusion. The host supplies pixels through a pluggable layout
backend, so Crane can sit behind a native UI, a test harness or a headless
automation tool.

JavaScript runs in V8, reached only through an engine protocol that is designed
to be implemented by JavaScriptCore on iOS as well.

Conformance is judged by the [Web Platform Tests](https://web-platform-tests.org/)
(WPT), the suite every major browser runs, not by Crane's own tests.

## Status

**Pre-release.** Crane 0.1 is defined as zero blocking files, meaning no
TIMEOUT, ERROR or CRASH, across the 0.1 worklist in
[`tests/wpt_0_1_worklist.txt`](tests/wpt_0_1_worklist.txt): 4,323 WPT files.

Latest full sweep (main `703639a56`, 2026-09-29):

| | |
|---|---|
| Blocking files | 266 of 4,323 |
| Files passing every subtest | 49.3% |
| Subtests passing | 752,409 of 1,116,347 (67.4%) |
| Crashes | 0 |

By area, from the same sweep:

| Area | Files | Blocking | Subtests passing |
|---|---:|---:|---:|
| `html/semantics` (elements, forms, scripting, links) | 1,127 | 111 | 34.0% |
| `html/browsers` (windows, navigation, history, origins) | 567 | 56 | 49.1% |
| `navigation-api` | 414 | 15 | 71.0% |
| `dom` | 374 | 21 | 76.1% |
| `xhr` | 319 | 1 | 89.3% |
| `html/webappapis` (timers, event loop, scripting) | 277 | 16 | 87.8% |
| `websockets` | 200 | 0 | 90.2% |
| `html/dom` | 183 | 13 | 88.1% |
| `fetch` | 176 | 1 | 93.0% |
| `custom-elements` | 167 | 3 | 55.9% |
| `encoding` | 149 | 20 | 71.4% |
| `html/syntax` (the parser) | 139 | 4 | 59.5% |
| `streams` | 87 | 2 | 94.3% |
| `cookiestore` | 53 | 0 | 82.2% |
| `webidl` | 44 | 0 | 91.2% |
| `url` | 32 | 2 | 77.6% |

Most of `encoding`'s failing subtests wait on one feature in progress:
decoding documents in their declared legacy encoding.

These numbers are a snapshot. `zig build wpt-progress` renders the live report,
with per-area history and the engine roadmap
([`docs/roadmap.toml`](docs/roadmap.toml)), to `wpt-results/progress.html`.

## What is in it

About 990,000 lines of Zig in 6,400 files under `src/`, plus a 12,700-line C++
wrapper around V8.

| Group | Subsystems (`src/`) |
|---|---|
| DOM and HTML | `dom`, `html` (parser, scripting, navigation and session history, the navigation API, frames, forms), `css`, `selector`, `quirks`, `trusted_types`, `csp`, `permissions` |
| Networking | `fetch` (libcurl, with HTTP/2 through nghttp2), `xhr`, `websocket`, `cookiestore`, `referrer_policy`, `mimesniff`, `url`, `urlpattern` |
| Script | `webidl` (bindings and code generation), `runtime` (the engine protocol and its adapters), workers, `service_worker`, `streams`, `console`, `hr_time` |
| Storage and files | `storage`, `fs`, `file` |
| Text | `encoding`, `infra`, `intl` (CLDR) |
| Embedding | `platform` (capabilities, layout backend), `browser`, `webdriver` (does not build on Zig 0.16 yet) |

## Architecture

**The JavaScript engine is an adapter.** Everything outside
`src/runtime/engines/v8/` reaches the engine through one statically dispatched
protocol, `src/runtime/engine_protocol.zig`, and `-Dengine=v8|jsc|quickjs` picks
the adapter at build time. V8 13.1, statically linked, is the only working
adapter today. The JavaScriptCore and QuickJS adapters declare every operation,
and most answer `NotSupported`. `zig build test` enforces the boundary: no V8
reference exists outside the adapter. See
[`docs/engine-protocol.md`](docs/engine-protocol.md).

**WebIDL is generated.** The code generator reads 341 IDL files (the official
definitions from [w3c/webref](https://github.com/w3c/webref) in `specs/idl/`,
plus `specs/supplementary/`) and writes 1,262 interfaces into
`src/webidl/interfaces/`. Those files are generated and committed; never edit
them by hand. Behind them sit 1,283 hand-written implementations in
`src/webidl/impls/`. An implementation is reached only through its own
generated interface, and `zig build lint-impls` checks that.

**The host supplies pixels and capabilities.** Layout is a backend the host
provides (`src/platform/layout_backend.zig`). Clipboard, storage, network and
the other platform capabilities are tables the host fills in, exported over a
C ABI (`src/platform/exports.zig`). The tree links for `aarch64-ios` as well as
macOS.

## Building

The build is set up for macOS on Apple Silicon today.

You need:

- **Zig 0.16.0**, exactly.
- **V8 13.1 as a static monolith library** in `jsengines/v8/`, which git does
  not track. [`scripts/build-v8-static.sh`](scripts/build-v8-static.sh) builds
  it (Xcode command line tools, Python 3, about 15 GB of disk, 30-60 minutes).
- **Homebrew `sqlite` and `leveldb`**: `build.zig` links them from
  `/opt/homebrew`.
- **Python 3**, for the WPT server.

```bash
zig build wpt-runner -j2    # the WPT runner, the one artifact WPT needs
zig build test -j2          # ~4,900 unit tests, plus the boundary lints
```

**Do not run a bare `zig build`.** It installs about 19 artifacts, and each one
analyses the whole tree with roughly 6 GB of RAM. Always pass `-j2`. On a
machine whose default SDK is macOS 27, `build.zig` builds against the newest
26.x SDK automatically: Zig 0.16's bundled libc++ does not compile against 27.

## Running the Web Platform Tests

WPT lives in `tests/wpt`, a submodule pointing at the
[zig-whatwg/wpt](https://github.com/zig-whatwg/wpt) fork. Crane's own
testharness tests are in `tests/wpt/crane/`. Upstream files are never modified.

```bash
git submodule update --init tests/wpt
zig build wpt -j2 -- dom/nodes/                     # build the runner and run one directory

./zig-out/bin/wpt_runner --from-file=tests/wpt_0_1_worklist.txt \
    --wpt-root=tests/wpt --parallel=3 --output=wpt-results/my-run
zig build wpt-progress -j2                          # regenerate wpt-results/progress.html
```

Each run writes a `journal.jsonl` (one record per file) and a wpt.fyi-format
report. The progress page reads journals only from `wpt-results/*.jsonl` and
`wpt-results/<label>/*.jsonl`. See [`docs/wpt.md`](docs/wpt.md).

## Embedding

- **Zig:** the `whatwg` module, rooted at `src/root.zig`.
- **C:** `src/lib_exports.zig` exports `whatwg_runtime_init` and
  `whatwg_runtime_shutdown`, `whatwg_browser_create`, `_navigate`, `_evaluate`
  and `_destroy`, `whatwg_version` and `whatwg_interface_count`.
  `src/platform/exports.zig` exports the `whatwg_platform_*` capability API.
  **`include/whatwg.h` is out of date:** it declares 14 functions that nothing
  exports, among them the whole `whatwg_context_*` family.
- **Swift and Kotlin:** `bindings/` holds prototypes from December 2025. They
  predate the engine protocol, their SwiftUI view draws a placeholder, and
  nothing in the current build or tests exercises them. Their guides
  (`docs/swift-integration.md`, `docs/kotlin-integration.md`,
  `docs/capability-implementation.md`) date from the same time.

## Repository layout

```
src/          the engine, one directory per subsystem
tests/        unit tests by subsystem; tests/wpt (submodule); tests/wpt_runner (the runner)
tools/        code generator, boundary lints, REPL, gc_bench, progress report
specs/        WHATWG specs as markdown, webref IDL (symlink), supplementary IDL
docs/         engine protocol, roadmap, lessons, WPT guide
data/         CLDR, encoding indexes, IDNA, public suffix list, Unicode tables
bindings/     Swift and Kotlin prototypes
include/      C headers (out of date; see Embedding)
scripts/      V8 build script
jsengines/    V8 (untracked; see Building)
```

## Contributing

[`AGENTS.md`](AGENTS.md) is the rulebook, for people and agents alike:

- Implement spec algorithms step by step, with numbered comments.
- Write the failing test first; WPT is the bar.
- No memory leaks, in Zig or C++.
- Never hand-edit a generated file.
- Keep the impls and engine boundaries. `zig build test` enforces both.

What past work taught is indexed in
[`docs/lessons/README.md`](docs/lessons/README.md). See also
[`CONTRIBUTING.md`](CONTRIBUTING.md).

GitHub CI is red on a clean checkout. `.github/workflows/test.yml` explains
why: nothing provisions V8, and `build.zig` expects Homebrew paths.

## License

MIT. Copyright (c) 2025 Brian Cardarella. See [`LICENSE`](LICENSE).
