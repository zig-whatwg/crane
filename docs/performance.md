# Performance: the benchmark suite, the journal and /performance/

Crane's performance is measured the way its users run it - pages in a headless browser - and
always beside the browsers: Chrome, Firefox, Safari and Lightpanda run the same pages, launched
the same way, on the same host. Every round of perf work (feature-queue, "deep performance
analysis") is measured with this suite before and after, and published at
<https://zig-whatwg.github.io/crane/performance/>. Memory is half of performance: every row
carries its memory beside its time.

| Part | Where |
|---|---|
| The workload pages and their harness | `tests/perf/` (`harness.js`, `suite.json`, `workloads/`, `load/`, `memory/`) |
| The runner, the journal reader, the report generator | `tools/perf_bench/` (`zig build perf-bench`) |
| The results | journals (`journal.jsonl`), kept out of git like `wpt-results/`; the page under gh-pages `performance/` |

## The rules

These are the user's (2026-11-02 and 2026-11-04) and the runner enforces what it can:

- **Comparisons run only on chat.local**, in a closed timed window, with pinned engine versions
  recorded in every row, the engines in alternating order, the same pages for every engine.
  Never on the Mac. A run anywhere else is a dry run: its numbers are not results.
- **Crane is timed in its release build**: the console (`repl <url>`, Crane's headless browser)
  built with `zig build repl-exe -Dwpt-runner-release` - every part
  ReleaseSafe (Crane's modules, the C libraries, the root), the C code at ReleaseSafe's `.trap`
  sanitizer, libc's malloc, V8 linked statically (`tests/wpt_runner/build_mode.zig`,
  `consoleModes`). Never the correctness runner, whose Crane modules are Debug. Every headline
  compares this build (journal engine `crane`).
- **Crane ReleaseFast is a column beside it, never the headline** (the user, 2026-11-05): the
  same release build with only the optimize mode changed, built with `-Dwpt-runner-release-fast`
  - Crane's modules, the C libraries and the root ReleaseFast, no C sanitizer
  (`releaseRunner(.fast)`), the same allocator, V8 and snapshot - timed in the same runs,
  alternating like any other engine (journal engine `crane_fast`). The two options name two
  builds, and the build refuses both at once.
- **Browsers launch headless, in the background, never taking focus.** Safari has no headless
  mode: it runs through `safaridriver` in chat.local's console session, one session at a time.
  Lightpanda runs through its CDP server.
- **Memory is half of perf**: each row has the engine's footprint when its workload ended and its
  peak during it; the memory rows measure one page, page after page, and instance after instance.

## What each workload measures

Each workload is a fixed number of operations (`ops`) timed in the page with
`performance.now()`, after `warmup` untimed runs, `iterations` times (default 3 and 10). The
journal keeps every sample; the report compares the median sample divided by `ops` (time per
operation). The operations are the same in every engine. Where a gc_bench row runs the same
statement, the workload says so: that is its browser equivalent.

| Workload | What it does | gc_bench row |
|---|---|---|
| `overhead.empty` | nothing: the harness's own cost per sample, the floor under every row | |
| `dom.create-element` | `document.createElement('div')`, discarded | create-element |
| `dom.getter-loop` | `el.id` (an attribute getter), over 16 elements in turn so no JIT hoists a getter it knows is pure | getter-loop |
| `dom.setter-loop` | `el.id = ...` (an attribute setter) | setter-loop |
| `dom.method-loop` | `el.hasAttribute('x')` (an operation), over 16 elements in turn | method-loop |
| `dom.event-ctor` | `new Event('x')` (a constructor) | ctor-loop |
| `dom.event-ctor-dict` | `new Event('x', {bubbles, cancelable})` (a dictionary argument) | dict-loop |
| `dom.set-get-attribute` | `setAttribute` then `getAttribute` | |
| `dom.class-list` | `classList.toggle` | |
| `dom.build-tree` | a 1,000-node tree built with createElement/appendChild/createTextNode, attached and removed | |
| `dom.insert-remove` | `removeChild` + `insertBefore` in a 100-item list | |
| `dom.text-content` | reading a subtree's `textContent` and replacing a child's | |
| `dom.clone-node` | `cloneNode(true)` of a 1,000-node tree | |
| `dom.query-selector` | `querySelector('#n-i .leaf')` in a 3,000-element document | |
| `dom.query-selector-all` | `querySelectorAll` of a four-step selector | |
| `dom.matches` | `Element.matches` of a descendant/child selector | |
| `dom.get-elements-by-class` | a live `getElementsByClassName` collection, read | |
| `dom.inner-html-set` | `innerHTML =` a 100-item list (the fragment parser) | |
| `dom.inner-html-get` | reading `innerHTML` of 1,000 items (the serializer), two elements in turn | |
| `dom.insert-adjacent-html` | `insertAdjacentHTML('beforeend', ...)` | |
| `events.dispatch` | `dispatchEvent` to a target 10 deep, a capture and a bubble listener per level | |
| `events.add-remove-listener` | `addEventListener` + `removeEventListener` | |
| `events.custom-event` | `new CustomEvent` with a detail, dispatched to one listener | |
| `parser.inner-html-large` | a 300 KB document body through `innerHTML` | |
| `parser.dom-parser` | the same document through `DOMParser` | |
| `parser.document-write` | the same document in 400 `document.write` calls into a document a script opened | |
| `json.parse`, `json.stringify` | a 1 MB document of 5,000 records | |
| `fetch.data-url-text` | `fetch('data:...')` and `text()` | fetch-text |
| `fetch.response-text` | `new Response('x').text()` | response-text |
| `fetch.loopback-small` | 1 KB from the benchmark server on loopback | |
| `fetch.loopback-json` | 2,000 records from loopback, `json()` | |
| `fetch.loopback-stream` | 4 MB from loopback, read through `body.getReader()` | |
| `streams.reader` | `new ReadableStream(...).getReader()` | stream-reader |
| `streams.enqueue-read` | 20,000 chunks pulled and read | |
| `streams.pipe-through-decoder` | `Response.body.pipeThrough(new TextDecoderStream())` read to the end | pipe-through |
| `streams.transform-chain` | 2,000 chunks through three TransformStreams into a WritableStream | |
| `streams.blob-stream` | `new Blob(...).stream()` read to the end | blob-stream |
| `timers.set-timeout-batch` | 1,000 `setTimeout(0)` scheduled together (no nesting clamp) | |
| `timers.promise-chain` | a chain of 100,000 `then` | |
| `timers.queue-microtask` | 100,000 `queueMicrotask` one after another | |
| `timers.message-channel` | 2,000 `MessageChannel` round trips | |
| `load.news`, `load.docs`, `load.app` | a real-world-shaped page loaded 10 times in one tab: from the document's time origin to its load event, or to when its script says it is ready (the app's data rendered) | |
| `memory.idle-page` | one small page, left alone 3 s: the footprint | |
| `startup.idle-page` | from launching the engine to that page's load event: start-up, reported apart so no other row includes it | |
| `memory.page-growth` | 30 documents in one tab, each with 2,000 elements and listeners: the footprint's slope per page | |
| `memory.instances` | 1 to 4 engines side by side on a small page: the footprint's slope per added instance | |

Rendering and layout are not Crane's (it draws nothing), so no workload times them; the
browsers' footprints include their rendering processes, as running them headless does.

### Crane-only rows

`perf_bench gc-bench` runs gc_bench's rows (`tools/perf_bench/gcbench.zig`, the bodies the lanes'
cost series use) into the journal as kind `gc_bench`: instructions retired, wall time and peak
footprint of one gc_bench process, and from gc_bench's own report the resident bytes per cycle,
the engine heap and the live global handles. The statements have browser equivalents (the table
above); the measurement has none: a full collection forced between batches (`--gc`: what is
retained, not how fast), instructions counted for one process, and the engine adapter's counters.
Those rows stay Crane-only, with their history.

## How it is measured

- `perf_bench run` serves `tests/perf/` on 127.0.0.1 with cross-origin isolation (COOP
  same-origin, COEP require-corp): `crossOriginIsolated` holds in every engine that has it, so
  `performance.now()` is at its finest resolution (HTML "coarsen time").
- Each launch is a fresh process with a fresh profile. For run r the engines go in the order
  given rotated by r, page by page: no engine always first, last, or after the same other.
- The page reports with `POST /__perf/mark` (loaded, begin, end, step, error, done). On each mark
  the runner reads the engine's **process set** - the launched process and its descendants, and
  for Safari the WebKit processes launchd starts, by name - through `proc_pid_rusage`: CPU (user
  + system), instructions retired, `phys_footprint` (Activity Monitor's Memory: each page counted
  once) and resident size. It answers only after reading, so the page is idle while it is read.
- A timed row's CPU and instructions are the set's between its begin and end marks; its memory,
  the footprints at both, the most a 50 ms sampler saw between them, and its **steady** footprint:
  after the workload's teardown, with the page left alone `--settle-ms` (500 ms by default), at
  its `settled` mark - what the workload left behind. Each timed page also gets its own row,
  `page.<file>`: its footprint from its load mark to its done mark (after the settle time) and the
  launch's peak. The report compares the steady footprint, and shows the peak beside it.
- Chrome: `--headless=new` with puppeteer's quiet-profile flags; Firefox: `--headless` with a
  profile whose `user.js` turns off first-run pages, telemetry and updates; Lightpanda: `serve`,
  then CDP (browser context, target, flat session, `Page.navigate`); Safari: `safaridriver`, a
  WebDriver session, Navigate To, and a Safari of the launch's own - the runner refuses a launch
  while a Safari runs and, when the launch ends, ends the automation Safari it started by exact
  pid (safaridriver leaves it running after Delete Session on Safari 27.2: in round 0's first
  window every launch reused one Safari, whose app, Networking and GPU processes were outside
  the set); Crane: `repl <url> --proxy=direct`, its stdin held open (the
  page stays live) and closed at the end (the console exits as on Ctrl+D), started in its build's
  own directory: the console restores the `whatwg_snapshot.bin` beside its executable, and only
  without one searches from its working directory, so even that fallback is the build's own
  (docs/lessons/testing-a-runner-finds-its-snapshot-from-its-working-directory.md). Every row
  records the flags exactly (`engines.zig`).
- The harness's own costs are their own rows: `overhead.empty` (per sample) and
  `startup.idle-page` (launch to first load). No other row includes a launcher's time.

Check benchmark noise before explaining a difference: the same binary against itself first
(docs/lessons/testing-check-benchmark-noise-with-identical-binaries.md). The report prints each
cell's spread (the runs' relative median absolute deviation) when it is 5% or more.

## Running it

On the measuring host, from a checkout with the engines pinned:

```bash
zig build perf-bench -j2                     # zig-out/bin/perf_bench (std only; seconds)
zig build repl-exe -j2 -Dwpt-runner-release      # Crane's release build (+ zig-out/bin/repl.modes)
# copy zig-out/bin/{repl,whatwg_snapshot.bin,repl.modes} to <safe>/ before the next build replaces them
zig build repl-exe -j2 -Dwpt-runner-release-fast # the ReleaseFast column; copy the same three to <fast>/

# Crane's pins (the browsers' pins are written by their setup scripts on the host); `optimize`
# is the build's own repl.modes. For the ReleaseFast build: name=crane_fast, <fast>/.
cat > crane.pin <<PIN
name=crane
version=$(git rev-parse --short=11 HEAD)
commit=$(git rev-parse --short=11 HEAD)
build=release: -Dwpt-runner-release (ReleaseSafe everywhere, C .trap, libc malloc)
optimize=$(cat <safe>/repl.modes)
v8=13.1.203 static
binary=<safe>/repl
sha256=$(shasum -a 256 <safe>/repl | cut -d' ' -f1)
PIN

zig-out/bin/perf_bench check --suite=tests/perf/suite.json --root=tests/perf --pin=crane.pin --pin=chrome.pin ...
zig-out/bin/perf_bench run --suite=tests/perf/suite.json --root=tests/perf --out=<dir> \
  --round=0 --runs=5 --pin=crane.pin --pin=crane_fast.pin --pin=chrome.pin --pin=firefox.pin \
  --pin=safari.pin --pin=lightpanda.pin --stop-file=<STOP>
zig-out/bin/perf_bench gc-bench --gc-bench=zig-out/bin/gc_bench --pin=crane.pin --out=<dir2> --round=0 --runs=5
zig-out/bin/perf_bench validate <dir>/journal.jsonl <dir2>/journal.jsonl
zig-out/bin/perf_bench report --journals=<journals> --out=<gh-pages>/performance
```

`--only=<text>` runs only the pages or workloads whose name contains it; `--iterations` and
`--warmup` change the samples (the journal records what ran). A STOP file ends the run between
launches. `perf_bench serve --root=tests/perf` serves the pages alone, to open one by hand.

The `.pin` files are `key=value` lines: `name`, `version`, `build`, `binary`, `sha256`; Crane's
also `commit`, `optimize`, `v8`; Safari's `webdriver` (`/usr/bin/safaridriver`). `check` and
`run` refuse a binary whose SHA-256 is not its pin's, and a Crane pin whose `optimize` is not its
engine's modes as `build_mode.zig` `describe` writes them (`crane`: root ReleaseSafe ...;
`crane_fast`: root ReleaseFast ...): the correctness runner, or one build under the other's name,
is never timed.

## The journal

`journal.jsonl`: one JSON line per (engine, version, workload, run). `tools/perf_bench/journal.zig`
IS the format (`Record`), read strictly (an unknown or missing field is an error) and pinned by
its tests byte for byte; `perf_bench validate` reads journals the same way. The fields:

| Field | |
|---|---|
| `format` | `crane-perf/1` |
| `round`, `time` | the perf round (0: the baseline), and the launch's UTC time |
| `host` | name, OS, arch, CPU, cores, memory |
| `engine` | name (`crane`, `crane_fast`, `chrome`, `firefox`, `safari`, `lightpanda`), version, build; Crane's commit, optimize modes and V8; the binary, its SHA-256, the launch flags |
| `page`, `workload`, `kind`, `run` | what ran: `timed`, `chain`, `idle`, `startup`, `instances`, `gc_bench` |
| `status`, `message` | `ok`, `error`, `timeout`, `crash` or `unsupported`, and why |
| `ops`, `wall_ms` | operations per sample and each sample's time (a chain: each step's load) |
| `cpu_ms`, `instructions` | the process set's between the workload's marks |
| `memory` | footprint at start and end, peak, steady (`footprint_settled`), resident at end, processes |
| `series` | a chain's footprint per step; instances' total with 1..k running |
| `counters` | Crane-only figures (gc_bench rows) |
| `launch_ms` | launch to the page's load mark |

Journals are kept by round, outside git (`wpt-results/perf/rounds/<round>/...`, two levels below
`wpt-results/` so the WPT progress report never reads them as WPT journals).

## Re-measuring an engine

When one engine's rows of a round turn out wrong (round 0: Safari's process set), that engine
runs again in a second window, alternating with Crane ReleaseSafe as a **drift control**. The
round is then window 1's rows without that engine's, plus window 2's rows of it; window 2's
Crane rows never join the round's, they are compared with them:

```bash
grep -v '"engine":{"name":"safari"' <w1>/pages.jsonl > <round>/pages.jsonl   # a line's engine object starts with its name
grep '"engine":{"name":"safari"' <w2>/journal.jsonl > <round>/safari.jsonl
grep '"engine":{"name":"crane"' <w2>/journal.jsonl > <control>/crane.jsonl
zig-out/bin/perf_bench report --journals=<round> --control=<control> --remeasured=safari --out=<gh-pages>/performance
```

`report` prints the drift and the page gets a "Re-measured" section: the control's time and
memory over the round's (geometric means, and each workload's ratio), **within noise** when both
means are within 5% of 100%, with the workloads outside their own band (10%, or three times the
runs' spread) counted. A control that is not within noise means the host moved between the
windows: the re-measured rows are not comparable with the round's, and are not published.

## /performance/

`perf_bench report` writes `index.html` and `card.png` from every journal below `--journals`:
the headline (Crane's time and memory as a percentage of each browser's: the geometric mean over
the workloads both ran; start-up and `overhead.empty` are rows of their own, never in it; always
Crane's ReleaseSafe build), where a round has it the Crane ReleaseFast section (the same means of
the ReleaseFast build against the ReleaseSafe one and each browser) and its own column in the
round's tables, the engines with versions, builds and flags, this round workload by
workload, each workload's history by round (a browser updated between rounds keeps a row per
version), the Crane-only rows, and Open Graph and Twitter `summary_large_image` metadata with the
headline and the 1200x630 card (`tools/perf_bench/card/README.md`). The content is all in the
HTML; the page uses the WPT site's stylesheet (`../site.css`) and lives at gh-pages
`performance/`, which the WPT site's generator leaves alone and links to.

## The browsers on chat.local

Each browser is pinned under `~/crane-browsers/` with a setup script that checks for an update
and installs it, writing the browser's `.pin`: Chrome for Testing (stable, with chromedriver),
Firefox (the latest release, with geckodriver), Lightpanda (the newest nightly from its GitHub
releases), and Safari (the installed version; `softwareupdate --list` only - an update needs the
admin password and a restart, so it is reported to the user, never installed unattended). The
user's rule: check daily and before each round; an updated browser's benchmarks are re-run as a
new data point, and the report shows each browser's history by version.
