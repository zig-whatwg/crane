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
- **Crane is built for one fixed CPU, `-Dcpu=apple_m1`** (the user, 2026-11-06), never its
  build host's: every Crane build a published round times - ReleaseSafe, ReleaseFast, a base -
  is compiled with `-Dcpu=apple_m1`, the CPU every Apple Silicon Mac runs, as the browsers ship
  one build for all of them. See "The CPU target" below.
- **Crane is timed with its default young generation, 8 MB semispaces** (the user, 2026-11-12):
  V8's young generation is a build option, `-Dv8-young-generation-mb=<n>` - megabytes of the
  WHOLE young generation of each isolate, three semispaces' worth (docs/engine-protocol.md, 7b,
  has the unit table). A published round's Crane builds pass nothing, which is the default, 24 =
  8 MB semispaces: less memory held between collections, slower on allocation-heavy pages than
  V8's own 32 MB semispaces (`-Dv8-young-generation-mb=0`, a desktop host's choice - and what
  Chrome runs on desktop, so the trade is visible in Crane's rows beside Chrome's). A console
  built with the option is a measurement of that option, never the `crane` row; its pin's
  `build=` line names the value.
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
| `workers.start-stop` | 8 dedicated workers one after another, each started, sent one message, answered and terminated: an engine instance's whole life, the worker doing nothing (from round 9) | |
| `workers.start-work-stop` | the same, each worker allocating 4,000 arrays of 1,024 numbers and keeping every second one until it answers: its heap grows and is given back at its end | |
| `workers.four-at-once` | four allocating workers alive together, then terminated, twice. The three rows exist from round 9 (rounds 0 to 8 have no value for them); an engine that has `Worker` but never runs one - no message, no error within 5 s of the page's first worker - reads `unsupported` (Lightpanda's nightly of 2026-11-05 as the suite launches it: its log says "resource skipped ... resource=worker") | |
| `load.news`, `load.docs`, `load.app` | a real-world-shaped page loaded 10 times in one tab: from the document's time origin to its load event, or to when its script says it is ready (the app's data rendered) | |
| `memory.idle-page` | one small page, left alone 3 s: the footprint | |
| `startup.idle-page` | from launching the engine to that page's load event: start-up, reported apart so no other row includes it | |
| `memory.page-growth` | 30 documents in one tab, each with 2,000 elements and listeners: the footprint the chain levels off at (each run's median over the second half of its steps), with that half's slope per page beside it - what each further page still keeps. Until lane perf2 batch 7 it was the slope over all 30 steps, which reads a footprint that levels off later as more growth (a tip below its base at every step read 1.175 of it); every round is read the new way from its journals' series | |
| `memory.instances` | 1 to 4 engines side by side on a small page: the footprint's slope per added instance | |
| `elements.*` | memory per element, a suite of its own (`tests/perf/elements.json`): see "Memory per element" | |

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

## Memory per element

What one kept node costs each engine (the user, 2026-11-07: "can we get our nodes even
smaller?", and "yes" to a fair comparison with the browsers). The browsers' published object
sizes - Blink's Element at 80 bytes, Lightpanda's at 74 - leave out the JS wrapper and the side
tables, so they are not a comparison; this measures the whole engine, the same way in each.

- **Its own suite**, `tests/perf/elements.json`: six pages of kind `retained`
  (`tests/perf/memory/elements-*.html`, the cases in `elements.js`), so `suite.json` stays the
  pages every round repeats. One case per page, and each page in a fresh launch: memory one case
  freed stays in its allocators, and a second case in the same process would reuse it and read
  smaller.
- **A case** (`perf.retain(name, { setup(n), create(n) })`, harness.js): `setup` makes everything
  but the nodes - a slot for each in an array, a host element, the markup to parse - and the
  harness holds it to the end, so both readings hold it; then the page asks for a full collection
  where the engine lets it (`TestUtils.gc()` twice in Crane's console; `gc()` twice in Chrome,
  launched with `--js-flags=--expose-gc`; Firefox, Safari and Lightpanda let a page ask for none),
  idles `settle_ms`, and posts `before`; makes and keeps `count` nodes; collects and idles again,
  and posts `after`. The runner reads the process set's footprint at each mark, as for every row.
- **The cases**, N = 100,000 in every engine: divs kept in a JS array; divs appended to the
  document; divs with two attributes (the same two values on each); text nodes; spans made by
  the fragment parser (innerHTML, the markup one flat string made in setup); and **the control**,
  the same steps with nothing made.
- **The figure** (`report.zig` `elementTable`): per run, (the case's footprint difference - the
  control's median difference) / N; the median over the runs, with the median absolute deviation
  shown where it is 5% or more. Where the engine tells a page its JS heap (Chrome's
  `performance.memory.usedJSHeapSize`, launched with `--enable-precise-memory-info`), the same
  figure for the heap beside it.
- **The journal**: one row of kind `retained` per case and run - `ops` = N, `footprint_start` /
  `footprint_end` the two readings, `wall_ms` the one sample of making them, counters `forced_gc`
  (1 when both readings followed a collection the page asked for), `settle_ms`, and
  `js_heap_before` / `js_heap_after` where reported. The report keeps these rows out of every
  other section: the headline, the round tables, the progress and the drift controls are the
  suite's alone.

```bash
zig-out/bin/perf_bench run --suite=tests/perf/elements.json --root=tests/perf --out=<dir> --round=<n> \
  --runs=5 --pin=crane.pin --pin=crane_fast.pin --pin=chrome.pin --pin=firefox.pin --pin=safari.pin \
  --pin=lightpanda.pin --stop-file=<STOP>
```

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
  (On Linux the same set is read from `/proc`: "perf_bench on Linux".)
- A timed row's CPU and instructions are the set's between its begin and end marks; its memory,
  the footprints at both, the most a 50 ms sampler saw between them, and its **steady** footprint:
  after the workload's teardown, with the page left alone `--settle-ms` (500 ms by default), at
  its `settled` mark - what the workload left behind. Each timed page also gets its own row,
  `page.<file>`: its footprint from its load mark to its done mark (after the settle time) and the
  launch's peak. The report compares the steady footprint, and shows the peak beside it.
  The footprints at the begin and end marks are single readings of whatever the page is in the
  middle of, and no figure is taken from them alone. On the worker rows the end mark is answered
  while the workers the sample just terminated are still ending on their own threads (measured
  2026-11-15: 1 to 4 of them alive at every end mark and gone 1 to 5 ms later, the footprint then
  the settled mark's), and the last step of a chain reads wherever the collector's sawtooth is. A
  pair's memory is judged on the steady footprint and the peak.
- **A page that goes idle gives the allocator's free memory back** (lane idle1, 2026-11-16;
  `src/browser/memory_release.zig`): once a window's event loop has had nothing to run for 200 ms
  it starts a release of the system allocator's free memory on a detached thread - once per idle
  stretch, and for the whole process not again until 20 times the release's duration has passed,
  at least 5 seconds, and 30 seconds after a release that returned under 1 MiB (WebKit's numbers).
  The settle time is 500 ms, so a `settled` mark reads after the release where the hold-off let
  one start. On Linux (glibc `malloc_trim(0)`) that lowers the rows that follow a large free:
  server1, the tip against main ca7726f6964, 7 launches a side - settled resident memory x0.943
  over 51 rows with no row above x0.995 (`streams.transform-chain` and `streams.blob-stream` 517
  -> 366 MB; the `dom.*` attribute rows 92.6 -> 81.9 MB; the page peaks x0.955 to x0.995), time
  x0.985 over 50 rows with no row outside the base's own spread. The first three streams rows stay
  near 510 MB: the process's first release, at the page's first idle stretch, returns under 1 MiB,
  and the next is held off for 30 seconds. On macOS nothing is returned: since macOS 26 the system
  allocator ignores `malloc_zone_pressure_relief`, the one public call (chat.local, 27.0.1: time
  x0.999, footprint x1.004 on the default pass and x0.992 with `MallocLargeCache=0`; three
  `events.*` rows read 1.5 MB higher on the default pass in every launch and the same, 31 MB,
  with the ring off - the reclaim ring's phase, not bytes held). A row timed while a release
  runs does not wait for it; an allocation from the arena glibc is trimming at that moment does.
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

## The CPU target

`build.zig` calls `b.standardTargetOptions(.{})`, which has no default: without `-Dcpu`, a build
is compiled for the CPU of the host that builds it. The pool's hosts differ (chat.local is an
M4 Pro, `apple_m4` to Zig; chat2 an M2, `apple_a15`), and two builds of one source for two CPUs
are two code layouts: on 2026-11-06 a console of lane perf2's tip built on chat2 was 12.6% slower
on `dom.getter-loop` than the same tip built on chat.local, with the same instructions retired
(docs/lessons/testing-a-frozen-console-is-one-builds-layout.md). Round 0's Crane was built that
way, natively on chat.local. So, since round 1:

- **Every Crane build a round times is built with `-Dcpu=apple_m1`**, in one build session on the
  timing host (the SDK and linker differ between hosts too).
- **The build records its target.** A release console's `zig-out/bin/repl.modes` is its build
  identity in the pin's own `key=value` lines (`tests/wpt_runner/build_mode.zig`,
  `writeModesFile`): `optimize=` its modes and `target_cpu=` the CPU its code is for, as `-Dcpu`
  spells it - the model, then `+feature` / `-feature` for each feature added to or removed from
  the model's own, and ` (native)` when no `-Dcpu` was given. It is the CPU Zig resolved, not the
  model asked for: `std.zig.system.resolveTargetQuery` drops `fuse_aes` from every Apple Silicon
  model (a workaround for ziglang/zig#37215), so `-Dcpu=apple_m1` records
  `target_cpu=apple_m1-fuse_aes`, and round 0's native build on chat.local was
  `apple_m4-fuse_aes (native)`. A window checks the model and that it is not native, never an
  exact string, and `perf_bench` holds the builds it compares to one target string.
- **The pin and every journal row carry it** (`target_cpu`): a `crane`, `crane_fast` or
  `crane_base` pin without one is refused (`PinMissingBuildIdentity`), and so is a set of pins
  whose Crane builds name different targets (`PinWrongTarget`). The drift control
  (`crane_control`, below) is exempt: it is an earlier round's binary, as that round built it.
- **The page names it**: the subtitle, the engines table and the method say which CPU Crane is
  built for.

## Running it

On the measuring host, from a checkout with the engines pinned:

```bash
zig build perf-bench -j2                     # zig-out/bin/perf_bench (std only; seconds)
zig build repl-exe -j2 -Dwpt-runner-release -Dcpu=apple_m1      # Crane's release build (+ zig-out/bin/repl.modes)
grep -qE '^target_cpu=apple_m1([+-][a-z0-9_]+)*$' zig-out/bin/repl.modes  # the model it is for, never native
# copy zig-out/bin/{repl,whatwg_snapshot.bin,repl.modes} to <safe>/ before the next build replaces them
zig build repl-exe -j2 -Dwpt-runner-release-fast -Dcpu=apple_m1 # the ReleaseFast column; copy the same three to <fast>/

# Crane's pins (the browsers' pins are written by their setup scripts on the host); `optimize`
# and `target_cpu` are the build's own repl.modes lines. For the ReleaseFast build:
# name=crane_fast, <fast>/. `v8` is the LINKED archive's version - the directory -Dv8 selects,
# jsengines/v8/15.7.112.43/include/v8-version.h (jsengines/v8/include is still 13.1.203's and is
# linked by nothing) - checked in the console's own bytes before the pin is written:
LC_ALL=C grep -a -q -F 15.7.112.43 <safe>/repl
cat > crane.pin <<PIN
name=crane
version=$(git rev-parse --short=11 HEAD)
commit=$(git rev-parse --short=11 HEAD)
build=release: -Dwpt-runner-release -Dcpu=apple_m1 (ReleaseSafe everywhere, C .trap, libc malloc)
$(cat <safe>/repl.modes)
v8=15.7.112.43 static
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
also `commit`, `optimize`, `target_cpu`, `v8`; Safari's `webdriver` (`/usr/bin/safaridriver`).
`check` and `run` refuse a binary whose SHA-256 is not its pin's, a Crane pin whose `optimize` is
not its engine's modes as `build_mode.zig` `describe` writes them (`crane`: root ReleaseSafe ...;
`crane_fast`: root ReleaseFast ...) - the correctness runner, or one build under the other's name,
is never timed - and Crane builds of different CPU targets ("The CPU target").

## The journal

`journal.jsonl`: one JSON line per (engine, version, workload, run). `tools/perf_bench/journal.zig`
IS the format (`Record`), read strictly (an unknown or missing field is an error) and pinned by
its tests byte for byte; `perf_bench validate` reads journals the same way. The fields:

| Field | |
|---|---|
| `format` | `crane-perf/1` |
| `round`, `time` | the perf round (0: the baseline), and the launch's UTC time |
| `host` | name, OS, arch, CPU, cores, memory |
| `engine` | name (`crane`, `crane_fast`, `crane_base`, `crane_control`, `chrome`, `firefox`, `safari`, `lightpanda`), version, build; Crane's commit, optimize modes, CPU target (`target_cpu`, absent from round 0's rows) and V8; the binary, its SHA-256, the launch flags |
| `page`, `workload`, `kind`, `run` | what ran: `timed`, `chain`, `idle`, `startup`, `instances`, `gc_bench`, `retained` |
| `status`, `message` | `ok`, `error`, `timeout`, `crash` or `unsupported`, and why |
| `ops`, `wall_ms` | operations per sample and each sample's time (a chain: each step's load) |
| `cpu_ms`, `instructions` | the process set's between the workload's marks |
| `memory` | footprint at start and end, peak, steady (`footprint_settled`), resident at end, processes |
| `series` | a chain's footprint per step; instances' total with 1..k running |
| `counters` | figures beyond the common ones: gc_bench rows' (Crane only), retained rows' collection, idle time and JS heap |
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

## Re-measuring Crane: Crane-only windows

**The user's rule (2026-11-06): re-measuring /performance/ runs ONLY Crane** (ReleaseSafe, and
ReleaseFast where the round has it). Chrome, Firefox, Safari and Lightpanda keep their last
rows. A browser runs again only when it updates, and then only that browser.

A Crane-only window alternates the new Crane (`crane`, the tip) with the frozen previous Crane as
its base (`crane_base`: round 0's is chat.local `~/crane-work/perf0-bins/crane-9b0f1b1f382/`).
The base is an engine of its own: the same release build's modes (a pin whose `optimize` is not
ReleaseSafe's is refused), its own column in the round's tables, and its own commit in every row.
It runs in the run order like any other engine. `run` and `check` refuse a set of pins with:
- two pins for one engine;
- a `crane_base` without a `crane`;
- a `crane_base` of the same commit as another Crane pin, which would compare nothing.

```bash
# crane_base.pin: crane.pin's keys for the frozen base, with name=crane_base
zig-out/bin/perf_bench run --suite=tests/perf/suite.json --root=tests/perf --out=<dir> \
  --round=<n> --runs=7 --pin=crane.pin --pin=crane_base.pin --stop-file=<STOP>
zig-out/bin/perf_bench report --journals=<dir> --out=<scratch>
```

`report` prints the comparison and the page gets a "Crane against its base" section. Per
workload both ran it gives the tip's figure over the base's for time, steady memory and peak
memory. Each ratio has a noise band: 10%, or three times the runs' spread where that is wider
(memory never under 10%). A workload with any ratio outside its band has moved, and every one
that moved is listed. Two geometric means, time and steady memory, are taken over the headline's
workloads. A row whose runs read in two memory levels - two tight groups of launches at least 3%
apart, each of two runs or more (on macOS the system allocator gives freed pages back in steps, so
`dom.event-ctor` and the rows after it read 143.5 MB in some launches and 162.5 MB in the others
with the same bytes allocated) - keeps the median of all runs as its figure, shows both levels
with their counts beside it on a Crane build's rows ("two levels: 143.5 MB x3 / 162.5 MB x7"; a
browser's row gets no such note), and is compared level
against level where one Crane build is checked against another - the tip against its base here,
and a drift control against the round it repeats: low with low and high with high, their
geometric mean judged against the band, and a side with one level set against the level of the
other it is within 3% of (at neither, the figures' ratio; the counts beside each figure show such
a row: read it with care, a side that truly moved by the whole gap looks the same). The two
levels `fetch.loopback-gzip` read until 2026-11-16 had another cause, an under-count: V8's
default in-sandbox allocator gives free 1 MiB chunks up with `MADV_FREE_REUSABLE` and hands them
out again without `MADV_FREE_REUSE`, and macOS leaves such pages out of the footprint though they
are written again (lane mem2: 100-103 MB in 14 launches of 20 and 139-141 MB in 6; lesson
testing-two-footprint-levels-with-equal-dirty-bytes-are-one-level-undercounted.md). Crane now has
its own in-sandbox allocator (lane ab1, `src/runtime/engines/v8/sandbox_allocator.zig`), which
recommits the pages a block uses before it hands them out, so the footprint is the process's
dirty pages less about 1 MB in every launch. **The rows read after many ArrayBuffers were freed
rose with that merge, and the rise is the reading, not memory** (chat.local, 20 launches a side,
the tip against main 4d4cedb50d9; MB, median, with libmalloc's deferred reclamation off in
brackets): `fetch.loopback-gzip` 105.1 -> 145.4 (78.7 -> 119.7), its peak the same;
`fetch.loopback-br` steady 130.5 -> 131.7 (101.6 -> 103.2) and peak 131.9 -> 157.0 (101.7 ->
131.0); `fetch.loopback-stream` steady 97.5 -> 99.1 (78.7 -> 80.3) and peak 101.7 -> 135.1 (84.2
-> 108.8). With every in-sandbox allocation logged, the two allocators hold the same for the
same live bytes: dirty pages less live in-sandbox bytes 79.9-82.8 MiB on the tip and 79.3-81.7
on main, four launches each. What these rows hold at their mark is garbage V8 has not freed yet,
and how much is left differs from launch to launch on either allocator - on the gzip row 36 to
39 of its 1 MiB bodies and none to 41 of the stream row's 176 KiB pieces, 36 to 46 MiB - so the
gzip row's launches spread over about 10 MB (113-122 with the reclamation off) and
`fetch.loopback-stream` reads about 80 MB in 15 launches of 20 and about 122 in the other 5:
two states of the collector, both counted, not one level under-read (lesson
testing-footprint-levels-of-uncollected-garbage-hold-different-live-sets.md). A round measured
before that merge is low on these rows by what was reused, up to about 42 MB. Every published ratio - Crane against a browser,
ReleaseFast against ReleaseSafe, a round against the first - stays the medians'. Before the tip's rows are set beside the browsers' last ones, the base must be within
noise of its own earlier rows: compare the window's `crane_base` rows with the earlier round's
Crane rows as the drift control above does, with both geometric means within 5% of 100%.

**The browsers' rows stand; the drift control decides whether Crane's may stand beside them.** A
Crane-only round has no browser rows of its own: each browser's rows are its latest earlier
round's (`report.zig` `Model.standing`; a Crane build's rows never stand for a later round), and
the page says so where it shows them. Before the new Crane rows are set beside them, the host must
be shown not to have moved since: the window also runs **the binary the earlier round measured as
`crane`, unchanged**, as engine `crane_control` (its pin is that round's, renamed). The report
finds that round by the control's SHA-256, compares the control's rows with that round's Crane
rows (`controlDrift`, `driftBetween`: page workloads only, never gc_bench's), and prints a "Drift
control" section. `perf_bench report` refuses to write a round whose browsers' rows are carried
when it has no such control, or when the control is not within noise (both geometric means within
5% of 100%). Where the window also has a base of the control's commit built for the fixed target
(round 1: round 0's source for `apple_m1`), the base over the control is what the CPU target alone
did (`targetAlone`): the drift control section shows it per workload, and the Progress section
says it in one footnote sentence (`targetChanges`) - a methodology control, never a point of
Crane's progress.

```bash
# round 1: the tip and ReleaseFast for apple_m1, round 0's source for apple_m1, round 0's binary
zig-out/bin/perf_bench run --suite=tests/perf/suite.json --root=tests/perf --out=<dir> --round=1 --runs=7 \
  --pin=crane.pin --pin=crane_fast.pin --pin=crane_base.pin --pin=crane_control.pin --stop-file=<STOP>
zig-out/bin/perf_bench report --journals=<round 0's journals + <dir>> --out=<scratch>
```

**A micro row is one build's layout.** A sub-microsecond row can swing by about 15% between two
builds of the same source, with instructions retired equal within 0.5%: code placement. Builds on
different pool hosts also differ in code, because each targets its host's CPU. On 2026-11-06,
dom.getter-loop was +12.6% for a tip console built on chat2 and -0.6% for the same tip built on
chat.local; main built on chat2 was +0.6%
(docs/lessons/testing-a-frozen-console-is-one-builds-layout.md). So:
- every console of a timed comparison is built on the host that times it, in one build session,
  with the one pinned `-Dcpu` the published rounds use ("The CPU target");
- a surprising micro-row change is first re-checked with a second build, both sides rebuilt on the
  timing host, and with instructions retired (page minus a 0-iteration control) - only a change
  that survives both is chased.

## A lane's cost pair

A lane that changes how an object is built, a hot path or what Crane holds measures its cost as a
**pair**: its tip (`crane`) against the main it is based on (`crane_base`), both consoles built in
the lane's own mirror on the timing host, alternating in one window. The bar is 3% (AGENTS.md,
"The 3% memory bar reads what Crane holds"). The pair is two passes of `perf_bench run`, and one
command reads them:

```bash
# the default pass: time, CPU, instructions; steady and peak memory
perf_bench run --suite=tests/perf/suite.json --root=tests/perf --out=<D> --round=<n> --runs=7 \
  --pin=crane.pin --pin=crane_base.pin
# the memory pass: memory only, the allocator's deferred-reclamation ring off on BOTH sides, and
# each timed workload's footprint read once more after a full collection
MallocLargeCache=0 perf_bench run --suite=... --root=tests/perf --out=<M> --round=<n> --runs=9 \
  --pin=crane.pin --pin=crane_base.pin --collected
perf_bench cost --default=<D> --memory=<M> [--bar=1.03]
```

**The rule `cost` applies** (AGENTS.md, "The 3% memory bar reads what Crane holds"; the user,
2026-11-15 and 2026-11-17):

- time and instructions, on the default pass: a row is over when the tip's median over the base's
  is above the bar and the two sides' launches do not overlap;
- memory, on the steady figure and the peak - the medians of all launches, in either pass. A
  figure above the bar is **cleared**, with every launch's value printed, when
  (a) both sides reached a common level and each such level's tip / base ratio is within the bar,
  or (b) the row's collected figure is within the bar. A figure neither clears is over;
- the collected figure never replaces steady and peak: it is read only to clear a row they put
  above the bar.

`cost` prints the geometric means, every row above the bar with each launch's value on both sides
and its verdict (`CLEARED (a)`, `CLEARED (b)` or `OVER THE BAR`, with why), and a table of all
rows (`!` above the bar and not cleared, `c` a memory figure the rule clears, `*` the sides'
launches apart, `L` two levels). Its last line is the pair's verdict, and it exits 1 when a row is
over the bar and not cleared.

**The two readings that clear a row, and why a median needs them** (lane tl2, 2026-11-17). The
rows of the streams, attributes, page-growth and fetch pages sit on two memory levels: a median of
3 or 9 launches flips between them, and two consoles can sit on different levels with disjoint
ranges in either direction (lane wb1: +3.3% on one pair of trees, -3.3% on the next, the same
lane diff). With the ring off, what is left of a level is garbage waiting for a collection at the
settle mark - whether V8 started a marking task in the idle half second, whether a full
collection landed inside the page - and a build can prefer one level while it holds the same
bytes on each.

- **The levels of both sides together.** The two sides run the same page on the same host in
  alternation, so a level belongs to the page. `cost` looks for two levels in the launches of both
  sides at once (two groups at least 3% apart, two launches or more in each, each closer together
  than half the gap between them), puts each launch on the low or the high one, and prints the tip
  over the base **per
  level both sides reached**, each side's count on each level, and the chance of shares that far
  apart from one coin (Fisher's exact test, two-sided). A side with 8 launches low and 1 high, a
  pass of 3 launches, and a side that sits on one level are all read this way; the report's own
  levels need two groups on one side and miss each of them. A figure above the bar whose every
  shared level reads within it is a median that changed level: clearing (a).
- **Sides that share no level.** Every launch of the tip on one level and every launch of the
  base on the other is the row the steady figure cannot settle: the tip holds more (or less), or
  each build prefers a level. `cost` says so, whichever side is the higher - a row reading 0.967
  today is the row that reads 1.033 on the next pair.
- **The collected figure** (`--collected`, `memory.footprint_collected`). After a workload's
  `settled` mark the page asks for a full collection (`TestUtils.gc()` twice, as the retained
  pages do), stays idle for the settle time again and posts a `collected` mark. The footprint
  there is what the workload keeps once its garbage is gone, so the collector's schedule cannot
  choose it. A collected pass's page runs at another pace (each row starts from a collected
  heap), so its steady and peak figures are a pair's, compared only within the pass, and its times
  are not read. No published round is run with `--collected`: without `collect=1` in its URL the
  harness does what it always did.

**What the figures are worth, measured** (chat.local, 2026-11-17, main 4aa01442561: ONE console
as both sides of the pair, so every row's true ratio is 1.000; the attributes and streams pages,
9 launches a side, the ring off):

- the steady figure of a plain memory pass read 1.000 to 1.016 over the 15 rows: the five rows
  after `streams.reader` read 265-267, 270-272 or 276-281 MB by launch, one side had more launches
  on the middle group, and its medians read 1.015 to 1.017 for no difference at all; three
  attributes rows read 55.6 or 61.5 MB (4 launches and 5 on each side) and their medians 1.010;
- the collected figure read 0.998 to 1.002 over the same 15 rows. On the attributes page it is one
  level (42.5-43.0 MB in all 18 launches). On the streams page it is 81.2-82.7 MB in 13 launches of
  18 and 92-97 MB in the other 5 (2 of one side, 3 of the other), the same launches on every row
  after `streams.reader`: a collection frees the garbage, not the pages the heap's largest size
  left in the allocator, which macOS does not take back. So the collected figure is not one level
  everywhere; its median holds while fewer than half the launches are in that tail;
- a real pair read by the command (lane impls8's cost window, 7 launches a side): the attributes
  rows 1.116 by the rule on the ring-off pass; levels of both sides together 55.5 and 62.8 MB, the
  tip 3 low and 4 high, the base 5 low and 2 high (the chance of those shares from one coin 0.59),
  level against level 1.004 and 0.995.

The user's ruling on these figures (2026-11-17) is the rule above: steady and peak stay the bar,
and either reading may clear a row.

## perf_bench on Linux

`perf_bench` runs on Linux (lane tl2, 2026-11-17: `tools/perf_bench/proc_linux.zig`), so a server1
pair uses the same tool, journal and `cost` table as a chat.local one. What differs is the
reading, so **a Linux row is compared only with a Linux row of the same host, and every published
figure stays macOS's**:

- memory: the footprint is `RssAnon + VmSwap` of `/proc/<pid>/status` - the process's own
  anonymous memory, resident or swapped out, the nearest Linux has to `phys_footprint`.
  `resident_end` is `VmRSS`, which also counts the executable's and the libraries' file pages
  (the tables lanes mem2, idle1 and ev2 wrote before this read `VmRSS`: they are higher by those
  pages);
- CPU: `utime + stime` of `/proc/<pid>/stat`, all threads, in clock ticks - 10 ms steps;
- instructions: not measured (the journal's field is absent). A counter on a process set from
  outside misses what each thread did before the counter was opened;
- the process set: the launched process and its descendants, from every thread's
  `/proc/<pid>/task/<tid>/children`;
- `perf_bench gc-bench` runs each row under GNU time (`/usr/bin/time -v`): wall time and the
  largest resident size, which stands for the row's memory; no instructions.

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

**Progress over time** (the user, 2026-11-06: the page shows the progress Crane makes over
time; 2026-11-07, on the first version's chart of one line per browser with a CPU-target point:
"this graph is confusing for tracking Crane's progress"), from the second round on, all of it from
the rounds' journals. A point is a **measurement round** of Crane's release build, never a
methodology control: a round's base and drift control (`crane_base`, `crane_control`) are not
points (`report.zig` `progress`).
- **Progress**, right after the headline, in two parts:
  - **Crane over time**, first: two small charts, time and memory, each ONE line - Crane's
    geometric mean as a share of its first round's (round 0 = 100%; `compareRounds` over the
    workloads both rounds ran), lower is better. The x labels name the round, its date and
    Crane's commit; each point is labelled with its value (`chart.zig` `trendChart`: a linear
    scale from 0, 100% the reference line). A round that changed the CPU target and rebuilt an
    earlier round's source for it gets one footnote sentence instead of a point (`targetChanges`:
    round 1's apple_m1 rebuild of round 0's source changed time by 0.991x and memory by 1.010x,
    within the 5% noise limit). Under the charts, each round's line: its date, commit, CPU target,
    its two figures and what it changed (`round_notes`).
  - **The gap to the browsers**: a table, one row per browser, of Crane's time and memory as
    "N.NNx the browser's" in each round - the headline's geometric means, each round against each
    browser's rows as they stood then (its last-measured rows, `Model.standing`). From the second
    round on a cell is green when lower than the round before (whose column sits beside it), red
    when higher, and uncoloured when the change is within the drift control's own 5% limit
    (`changeOf`). At phone width each row lists its cells with their labels.
- **Crane, round by round**: each workload's time and steady memory in every measurement round,
  its change since the first round, and a sparkline per measure - Crane's own rounds only, with
  no target step (what a target alone did per workload is the drift control's table).
- **The card and the description** name the progress: Crane's time and memory against its first
  round's (`sinceFirst`), beside the gap to each browser.
- The charts are inline SVG the tool draws (`tools/perf_bench/chart.zig`), on the WPT site's chart
  classes, with a native tooltip per point; every number is also in the HTML beside them, and no
  script is needed. The line's colour is the first categorical slot of the dataviz reference
  palette, with its own step for dark (`report.zig` `style`).
- **What each round changed** is one line in `report.zig` `round_notes`, written when the round is
  published (a test holds every round to one, BY NUMBER through the latest: publishing round N
  extends the test's range to N first, then writes the line - rounds 3-6 went out with none while
  the test only walked the lines that existed); every figure beside it is the journals'.

## The browsers on chat.local

Each browser is pinned under `~/crane-browsers/` with a setup script that checks for an update
and installs it, writing the browser's `.pin`: Chrome for Testing (stable, with chromedriver),
Firefox (the latest release, with geckodriver), Lightpanda (the newest nightly from its GitHub
releases), and Safari (the installed version; `softwareupdate --list` only - an update needs the
admin password and a restart, so it is reported to the user, never installed unattended). The
user's rule: check daily and before each round; an updated browser's benchmarks are re-run as a
new data point, and the report shows each browser's history by version.
