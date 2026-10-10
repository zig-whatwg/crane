# Platform protocol recipes

How to move Crane onto the platform protocol, `@import("platform")` (src/platform/protocol.zig, once
built), in order. The protocol itself is [platform-protocol.md](platform-protocol.md); the survey of
every touchpoint, file by file and line by line, is tmp/plans/platform-inventory.md (a local working
document - regenerate its counts from the lint once the lint exists). One section per step, each with
its files, its recipes (the intent, the old pattern, the protocol call, who owns what), its tests and
its verification. The engine protocol's migration is the model (docs/engine-protocol-recipes.md;
docs/lessons/architecture-design-the-protocol-before-migrating.md).

**Status: design, approved 2026-10-09; nothing is built.** Line numbers below are from main e5fc3466cc.

A migrated file has **zero platform-boundary references**: no `@import("clock")`, `@import("host")`,
`@import("memory")`, `std.c`, `std.posix`, `std.os`, `std.process`, `std.Io.Dir/File/net/Clock`,
`std.Thread.spawn`, `getenv`, `extern fn`, `builtin.os.tag`, libcurl, mbedTLS, SQLite or LevelDB. Then
`zig build lint-platform -j2 --cache-dir ~/Library/Caches/crane-z16-cache -- --update` records the drop
(the baseline only goes down).

---

## 0. Rules every recipe assumes

### 0.1 Import and module wiring

```zig
const platform = @import("platform");
```

`platform` is a leaf module (it imports only std, `platform_impl` and `platform_options`), so any module
may import it. A module that does not have the import yet needs `<mod>.addImport("platform",
platform_mod)` in build.zig - ask the integrator, who owns build.zig and protocol.zig. Never import
`platform_impl` or a kit module outside src/platform/ (the WPT runner's use of the testing platform's
control surface goes through `platform.adapter`, contract section 9).

### 0.2 The name `platform` may be taken

Some files name a field or local `platform` (src/html/event_loop/event_loop.zig's `self.platform`,
the TimerBackend). A field is no conflict; a local or a parameter called `platform` shadows the import
and Zig rejects it. Rename the local first (`timer`, `backend`), in the same commit.

### 0.3 Ownership vocabulary

| Thing | Rule |
|---|---|
| `Str` / `Bytes` / slice parameters | BORROWED for the call |
| A returned slice | OWNED by the allocator you passed; free it |
| `*BrowserPlatform` | the Browser's; borrowed by every operation; never stored past the Browser |
| Handles (`*Store`, `*Transfer`, `*MediaDecoder`, `*CaptureSource`, `FileToken`, ...) | OWNED from a successful open/start until the matching close/end; exactly once |
| `Reply(T)` you pass | the platform's until it calls deliver or drop, exactly once, from any thread |
| `Requester` | BORROWED for the call; build it from the realm (0.5) |

### 0.4 Which thread

OS operations: any thread. Per-Browser operations: the requesting agent's thread (the Browser's, or
the worker's). A Reply is completed from any thread and only posts a task; the steps run on the
agent's thread, in that task, after a liveness check. Never resolve a promise inside `deliver`.

### 0.5 Which BrowserPlatform, which Requester

The Browser's `*BrowserPlatform` is a supplement of its BrowserScope (docs/instances.md rule 2):
`html.platform_state.of(realm)` (a new helper, step 2b) reads `realm.browser_scope`. A worker realm
carries its creator's scope. The `Requester` comes from the relevant settings object:
`html.platform_state.requester(realm, request_id)` fills origin, top-level origin, tab, frame, secure
context and transient activation.

### 0.6 Capability gates

A gated operation compiles only inside a check, and the `else` is the spec's unsupported path:

```zig
if (platform.capabilities.geolocation != .unsupported) {
    platform.currentPosition(browser, &requester, &options, reply);
} else {
    // Geolocation: the position is unavailable - POSITION_UNAVAILABLE to the error callback.
}
```

Write the `else` from the spec text, not from what the stub did. An unsupported capability compiles
out on both sides (platform-protocol.md section 5).

### 0.7 C-representable types

Records crossing the protocol are `extern struct`s, enums have explicit tags, strings are `Str`
(pointer, length), callbacks are `callconv(.c)` with a context pointer. Convert Crane types at the
edge (fetch's Headers to `HttpRequest.headers`, a DOMString to `Str`); never put a Crane type in a
protocol record.

### 0.8 Verification (AGENTS.md, and the verification-process memory)

Every step: failing test first; `zig fmt src/ tests/ tools/`; `zig build wpt-runner -j2 --cache-dir
~/Library/Caches/crane-z16-cache`; `zig build test -j2 --cache-dir ~/Library/Caches/crane-z16-cache`
(which runs lint-platform, lint-engine, lint-impls, lint-global-state); the targeted WPT A/B the step
names, plus a 1-in-4 sample unless the step is engine-wide; timers x3 for steps that touch the event
loop, timers or lifetimes. Report the lint-platform baseline total beside the other ratchets.

---

## 1. The steps, in order

| Step | What | Lint references removed (approx.) | Risk |
|---|---|---|---|
| 0 | Per-platform module graphs in build.zig, the seam, every operation declared, the link-plan mechanics, the lint (old code kept until each step replaces it) | 0 (the baseline is recorded) | medium (the build.zig refactor) |
| 1 | The clock | 228 | low, wide |
| 2 | The network, per-Browser network state, the event-loop wait | 687 + 3 | HIGH |
| 3 | Files and storage locations; in memory by default | 50 + 1 | low |
| 4 | The storage engine behind the platform | 363 | medium |
| 5 | Randomness and the crypto primitives | 20 + 137 | medium |
| 6 | Threads, identity, diagnostics | 13 + 11 | low |
| 7 | The testing platform, platform events, media decoding | - | medium |
| 8 | Permissions | - | medium |
| 9 | Dialogs, printing, console, windows, screen and system state | - | medium (the pause) |
| 10 | File pickers | - | low |
| 11 | The clipboard | - | low |
| 12 | Layout | - | low (headless) |
| 13 | Every other page capability behind its gate | - | low, many lanes |
| 14 | darwin's native capabilities, by demand | - | per capability |
| 15 | The C API | - | medium |

Steps 1 and 3-6 are independent of each other once step 0 is in; step 2 should land before 7 (the
testing platform needs per-Browser state and the port), and 8-13 need 7.

---

## Step 0. The seam

**Goal**: the protocol and its check exist, every operation of platform-protocol.md is declared, every
built-in platform conforms (implementing today's behaviour or aliasing kit/headless), the lint passes
on a recorded baseline, and the old platform code is kept, re-exported where callers use it, until the step that replaces it. No behaviour change.

**Files**

- src/platform/protocol.zig: types (section 2 of the contract), every operation as a `pub inline fn`,
  `Capabilities`, `Support`, the `gate` helper, the conformance block (copy engine_protocol.zig's
  `conforms`, :1903-1919, and its whole-compile rule for test builds, :1890-1897), plus the
  declaration checks of contract 1.3 (`name`, `capabilities`, `identity`, `PlatformBrowserOptions` - a struct
  whose fields all have defaults).
- src/platform/kit/: posix (today's src/platform/clock.zig and host.zig moved behind functions),
  headless (every gated operation's unsupported answer), and empty-but-conforming curl, sqlite,
  leveldb, memory_store, crypto and memory_clipboard modules that forward to today's code where the
  code is still elsewhere (src/fetch/network, src/storage/backends, src/webcrypto) - one module per
  part, each linking only its own C library.
- src/platform/adapters/{darwin,linux,testing}/protocol.zig: compositions of kit parts.
- build.zig: `-Dplatform` (default from the target), `-Dplatform-module`, `-Dplatform-without`,
  `-Dplatform-static`, the `platform` and `platform_impl` modules (the engine binding's shape,
  build.zig:1366-1385), `platformProtocolBinding` for tests/platform (the shape of
  `engineProtocolBinding`, :718-730). The `platform` module stops importing fetch (build.zig:2212).
  **Per-platform module graphs** (settled, contract 1.1): build.zig's module wiring moves into one
  function, `addCraneModules(b, target, platform)`, called once per platform the invocation needs - the
  WPT runner and the test tiers get `testing`, the library, the CLI and the iOS build the target's
  platform. This refactor is the largest piece of step 0; land it first, alone, with no platform change
  (every artifact still bound to today's modules), then bind.
- The link-plan mechanics (contract section 10, R0 below): each kit part that has a system alternative
  takes a build option choosing system or static; darwin frameworks newer than the deployment target
  are weak-linked; linux's optional libraries are loaded at run time.
- tools/lint_platform_boundary.zig + tools/platform_boundary_baseline.txt + `zig build lint-platform`
  in `test` (rules: contract section 11; key list: tmp/plans/platform-protocol-design.md 12.2-12.3,
  with SQLite, LevelDB and all of mbedTLS now confined to src/platform/).
- Keep; each step removes what it replaces (decision 15 as the user changed it, 2026-10-09: "keep
  the code for now and attempt to extract out or replace everything first. Then delete."). Step 0
  deletes nothing of the old platform code. The facade re-exports what today's callers import from
  the old `platform` module in a TRANSITIONAL section (media_backend, media_adapter, timer_backend,
  the clipboard backend's types, the PlatformBackend/vtables/exports surface), lint-platform keys
  each use as `platform.<name>`, and the old src/platform/root.zig stays unbound. Each later step
  names the old files it retires below ("Retires"): it deletes them once its replacement is in place
  and tested, counting callers first (the function-pointer-table lesson's method), and drops their
  TRANSITIONAL entries and lint names. The caller counts taken in step 0 are in
  tmp/plans/lane-platform0-handoff.md.

**Tests**: tests/platform/protocol_conformance_test.zig - each built-in platform binds and every
operation type-checks; the signature comparison the conformance block uses is a function returning
whether two fn types match, unit-tested on a matching, a mistyped and a missing operation (a compile
error cannot be a test's expected outcome); `-Dplatform-without=camera` makes
`platform.capabilities.camera == .unsupported`. The lint's std.testing blocks: each key family, each
exemption (tools/, tests/, test declarations, src/webdriver/), a swap, src/url's `@import("host")`
(the URL host module, not the bridge). Once: `zig build test -Dtest-isolation=file`.

**Done when**: `zig build test` passes with lint-platform on the recorded baseline (about 1,510
references in about 123 files), `zig build wpt-runner -Dplatform=testing` builds, an `aarch64-ios`
build of the library compiles, and a WPT sample shows no change.

### R0. A link-plan item: the system library, with the kit as its fallback

```zig
// In a platform (src/platform/adapters/darwin/protocol.zig): one choice per link-plan item, at build time
const use_system_sqlite = !hasItem(platform_options.platform_static, "sqlite"); // or "all"
pub const openStore = if (use_system_sqlite) system_sqlite.openStore else kit_sqlite.openStore;
// build.zig: darwin_impl.linkSystemLibrary("sqlite3", .{}) when system; the kit module's static
// amalgamation otherwise - never both linked for one item.
```

Where a system library covers only some parameters (SecKey's RSA-PSS salt, CommonCrypto's AES-CTR
counter), the platform's function chooses per call, and both paths pass the same tests. Pitfall: a
system library is only "acceptable" in its link-plan row when it is complete for Crane's use and
trusted; record the evidence (the header, the package version) in the row, and mark what you could not
check UNVERIFIED.

---

## Step 1. The clock

**Files**: the 82 files of the inventory's clock table (85 with src/webdriver/, which is exempt but
may migrate in the same commit), then delete module `clock` (build.zig:1138-1146 and its addImport
lines). src/hr_time/clock.zig's per-OS wall-clock branches (88-117) go: the platform's `wallNow` is the
source.

### R1. Read a clock

```zig
// Before
const clock = @import("clock");
const start = clock.monotonicMillis();
const expires = clock.wallMillis() + max_age_ms;
var timer = clock.Timer.start();

// After
const platform = @import("platform");
const start = platform.monotonicMillis();
const expires = platform.wallMillis() + max_age_ms;
var timer = platform.Stopwatch.start();
```

Same values, same units. `clock.monotonicNanos()` is `platform.monotonicNow().ns`; `clock.wallNanos()`
is `platform.wallNow().ns_since_epoch`. `clock.sleep(ns)` becomes `platform.sleepThread(ns)` -
transitional, deleted at the end of step 2. Pitfall: this recipe changes no semantics. The Event
timeStamp sites (src/webidl/impls/Event.zig:195, 437 and 18 subclasses) stamp `monotonicMillis()`,
which is not relative to the relevant global's time origin - a real spec bug (DOM "timeStamp",
HR-Time "current high resolution time"), fixed separately with its own test, not inside this recipe.

**Tests**: tests/platform/clock_test.zig against darwin, linux and testing (monotonic never decreases
over 10,000 reads; the wall clock is within a day of a reference read; Stopwatch lap). WPT: hr-time/
(13 worklist files) A/B and a 1-in-4 sample.

---

## Step 2. The network

The highest-risk step: per-Browser network state, and the event loop's wait. Four commits, in order.

### 2a. Move libcurl behind the protocol

**Retires**: src/platform/network_adapter.zig (the NetworkVTable bridge into fetch).

**Files**: src/fetch/network/{curl_ffi,curl_backend,connection_pool,scheduler,curl_error}.zig and
src/websocket/curl_backend.zig move to src/platform/kit/curl/; `NetworkRequest` / `NetworkResponse`
/ `NetworkError` (src/fetch/network/backend.zig:103-258) become the facade's `HttpRequest`,
`HttpResponseHead`, `HttpError`, which fetch re-exports. src/fetch/algorithms/async_fetch.zig:197's
`CURLINFO_HEADER_SIZE` read becomes `HttpResponseHead.header_bytes`.

### R2. Start an asynchronous transfer

```zig
// Before (12 sites: src/html/module_script.zig:1488, script_execution.zig:3179,
// hyperlink_auditing.zig:178, style_sheet_loading.zig:732, embedded_content.zig:738,
// media/runtime.zig:144, impls/EventSource.zig:120, HTMLImageElement.zig:701,
// HTMLIFrameElement.zig:1419, XMLHttpRequest.zig:1004, WindowOrWorkerGlobalScope.zig:587, 908)
AsyncFetch.start(allocator, request, .{}, fetch.network.scheduler.threadScheduler(), client)

// After: the realm's agent's port
AsyncFetch.start(allocator, request, .{}, html.platform_state.portOf(realm), client)
// inside fetch: platform.startTransfer(port, allocator, &http_request, transfer_client)
```

The transfer's callbacks run only inside `platform.pollEventLoopPort`; the request is copied before
`startTransfer` returns. Pitfall: in 2a the port is still the thread's scheduler wrapped (2c makes it
per loop) - change the type, not the lifetime, in this commit.

### 2b. Per-Browser network state

**Files**: Browser.init (src/browser/Browser.zig:157-203) calls `platform.createBrowserPlatform(allocator,
&options, events)` and keeps it in the BrowserScope (`html.platform_state`), replacing
`fetch.network.globalInit()` (Browser.zig:168); the network context in kit/curl is per
BrowserPlatform (one CURLSH, one connection pool, its trust and proxy), replacing `global_share`
(curl_backend.zig:46), `global_pool` (connection_pool.zig:635) and `default_cert_options`
(backend.zig:85, `setDefaultCertOptions`, which the WPT runner calls at tests/wpt_runner/wpt_browser.zig:170 -
it passes `extra_trust_anchors_pem` instead); curl_global_init moves to `platform.initializePlatform`
(crane.Process). darwin verifies with SecTrust through mbedTLS's verify callback (decision 6;
Security.framework linked into the darwin platform only) and links the system zlib (link plan 10.1);
linux links the system zlib and nghttp2 and keeps static mbedTLS until kit/curl has an OpenSSL backend
(link plan 10.2). The WebSocket per-host CONNECTING gate
(threadlocal `handshake_gate`, src/websocket/connection.zig:198) moves onto the Browser.

**Tests**: tests/platform/network_context_test.zig - two Browsers fetching one URL from a local server
open two connections (the server counts accepts) and one Browser fetching twice reuses one;
`extra_trust_anchors_pem` is honoured per Browser, not process-wide. WPT: the .https. files (157 in
the worklist) A/B, reporting runner time as well as status (per-Browser contexts change connection
reuse).

### 2c. One port per event loop, and a real wait (decision 16)

**Retires**: src/platform/timer_backend.zig and timer_adapter.zig, with the html/event_loop EventLoop they serve (step 0 counted it dead: `EventLoop.init` runs only in its own tests, `WorkerGlobalScope.setEventLoop` has no caller) and tests/wpt_runner/main.zig's `timer_backend.deinitDefault()`.

**Files**: src/browser/event_loop.zig and each worker's loop (src/html/worker_thread.zig) create their
`EventLoopPort` and destroy it at their end, replacing the threadlocal `thread_scheduler`
(src/fetch/network/scheduler.zig:378); src/runtime/native_timer.zig's 1 ms `clock.sleep` slice (295)
becomes `platform.waitEventLoopPort(port, next_timer_deadline)`; `runtime.TaskSink.post` calls
`platform.wakeEventLoopPort`.

### R3. Wait for the next task, timer or socket

```zig
// Before: sleep in 1 ms slices and look again (native_timer.zig:281-296)
if (wait_ms > 0) clock.sleep(wait_ms *| std.time.ns_per_ms);
return self.pollEach(after_each);

// After: one wait that a socket, the deadline or a post from any thread ends
platform.waitEventLoopPort(port, if (next_deadline) |d| platform.Instant{ .ns = d } else null);
_ = platform.pollEventLoopPort(port);
return self.pollEach(after_each);
```

Pitfall: everything that can make work for the loop from another thread must wake it - TaskSink posts
(workers, ports, BroadcastChannel, platform Replies and events), and an agent's end. A post that does
not wake waits for the next timer: look for timeouts that move by a timer interval.

**Tests**: a tests/runtime test - a post from another thread ends a 10 s wait within 5 ms; a deadline
ends it on time. Timers x3 (`./zig-out/bin/wpt_runner html/webappapis/timers/ --parallel=3`, crash
counts, and a same-list comparison for any sweep-only crash per AGENTS.md); a full worklist sweep A/B
against main (every file's timing moves).

### 2d. The blocking paths

**Files**: `fetch.algorithms.fetch` (src/fetch/algorithms/fetch.zig:40-62, `curl_easy_perform`) and its
three callers (src/html/script_execution.zig:3021, src/html/worker_host.zig:371,
src/html/navigation/fetch_integration.zig:282) move to transfers on their loop's port;
`WebSocketConnection.connect` (src/websocket/connection.zig:434-442) to the asynchronous handshake;
curl_backend's retry `clock.sleep` (343) to the port's retry timer. Then delete `platform.sleepThread`
(the WebDriver server's sleeps are exempt and use their own).

### R4. A blocking fetch

```zig
// Before
var fetched = fetch.algorithms.fetch(allocator, request, .{}) catch |err| ...;
// After: the async fetch, continued from its completion task
_ = try AsyncFetch.start(allocator, request, .{}, html.platform_state.portOf(realm), client);
```

If a caller cannot continue asynchronously yet, add a transitional `transferBlocking` operation in the
same commit and delete it with its last caller - never a hidden blocking path.

**Tests**: classic script, worker script and navigation WPT A/B (html/semantics/scripting-1/, workers/,
html/browsers/browsing-the-web/).

---

## Step 3. Files and storage locations

**Retires**: src/platform/filesystem_adapter.zig, and src/runtime/engines/v8/context_manager.zig:56's unused `host` import.

**Files**: the inventory's filesystem table - src/storage/indexeddb/blob_storage.zig,
src/intl/cldr/loader.zig, src/runtime/engines/v8/snapshot_loader.zig, src/browser/process.zig,
src/browser/storage/Storage.zig, the four file: URL readers (src/browser/navigation.zig:266,
src/html/navigation/fetch_integration.zig:668, src/html/window/iframe_integration.zig:1264-1296,
src/html/external_script_loader.zig:254); then delete module `host` (build.zig:1148-1155) - its process
Io becomes kit/posix's, set up by `initializePlatform`.

### R5. Read a file

```zig
// Before
const io = host.io();
const file = host.cwd().openFile(io, path, .{}) catch return null;
defer file.close(io);
// ... stat, alloc, readPositionalAll ...

// After
const bytes = platform.readFile(allocator, path, max_bytes) catch return null; // OWNED
defer allocator.free(bytes);
```

### R6. Profile directories (decision 12)

`BrowserConfig.storage_root` + `persist_storage = true` (Browser.zig:90-93, default ~/.whatwg/) become
`BrowserOptions.profile_dir: ?Str`, default null = in memory. The `~` expansion with
`std.c.getenv("HOME")` and its "/tmp" fallback (Storage.zig:349-357) go; the CLI passes
`platform.defaultDataDirectory()`. Directory creation is `platform.makeDirectoryPath`.

### R7. file: URLs

One scheme-fetch "file" reader in fetch (Fetch 4.3: implementation-defined), gated on `file_urls`, called
by the four readers above; the unsupported path is a network error.

```zig
if (platform.capabilities.file_urls != .unsupported) {
    const body = platform.readFile(allocator, path, limit) catch return network_error;
    ...
} else return network_error;
```

**Tests**: tests/platform/files_test.zig against each built-in platform in `std.testing.tmpDir`
(atomic write, makeDirectoryPath, listDirectory, deleteTree, volumeSpace > 0); a Browser with no
profile directory writes nothing (HOME pointed at an empty directory stays empty); the file:
navigation tests (tests/html/navigation/). WPT: IndexedDB/ A/B.

---

## Step 4. The storage engine (decision 10)

**Files**: src/storage/backends/{sqlite,leveldb,memory}.zig move to src/platform/kit/{sqlite,leveldb,memory_store}/
behind the store operations (contract 6.6); src/storage/backend.zig's engine choice by `builtin.os.tag`
(:652-700) becomes `platform.identity.storage_engine` inside each platform; build.zig's
`configureStorageBackends` (:20-114) goes, replaced by the link plans: darwin and linux link the system
SQLite by default (macOS's LevelDB link today is Homebrew's, not the system's, and cannot ship),
kit/sqlite's amalgamation is the static fallback, and kit/leveldb stays available as a static choice.
The IndexedDB layer
is re-expressed over the store operations - its SQL-shaped persistence
(src/storage/indexeddb/object_store_persistence.zig, index_persistence.zig, sqlite_transactions.zig)
becomes an order-preserving key encoding (database / object store / index / key prefixes) over the
ordered key-value store, because LevelDB has no SQL (settled, contract 13). localStorage
persistence, the Cache API and the permission store use the same operations.

### R8. A transaction over the store

```zig
// Before: a backend vtable (src/storage/backend.zig:350-533) or SQL text
const txn = try backend.vtable.begin_transaction(backend.ptr, .readwrite);
try backend.vtable.write(backend.ptr, txn, key, value);
try backend.vtable.commit(backend.ptr, txn);

// After
const txn = try platform.beginTransaction(store, .write);
errdefer platform.abortTransaction(txn);
try platform.storePut(txn, encoded_key, value);
try platform.commitTransaction(txn);
```

Pitfall: key order is byte order, and it is web-visible through IndexedDB. Every key Crane writes is
encoded so byte order equals the spec's key order (IndexedDB "compare two keys"): numbers, dates,
strings (code unit order), binary, arrays. Test the encoding against the spec's comparison directly.

**Tests**: tests/platform/store_test.zig run against kit/sqlite, kit/leveldb and kit/memory_store - the
same script of puts, deletes, ranges, reverse cursors and aborted transactions gives the same results
from all three; the key-encoding test (encoded byte order equals `compareKeys` for a generated corpus);
persistence across a Browser restart with a profile directory. WPT: IndexedDB/, webstorage/, the Cache
API files, service-workers/cache-storage/ A/B; storage/ when it joins the worklist.

---

## Step 5. Randomness and the crypto primitives (decision 11)

### R9. Random bytes

```zig
// Before (three sources)
try io.randomSecure(&bytes);                       // src/webcrypto/random.zig:9, ec.zig:44, 111, rsa.zig
random.fill(host.io(), bytes) catch ...;           // src/webidl/impls/Crypto.zig:79-99
if (getentropy(&buf, buf.len) != 0) { ... }        // blob_url_store.zig:31, joint_history.zig:38,
                                                   // web_locks/registry.zig:614, fetch_body.zig:976,
                                                   // performance_timeline.zig:53
var prng = std.Random.DefaultPrng.init(@intCast(clock.wallMillis())); // blob_url_store.zig:94

// After
platform.fillRandom(&bytes); // cannot fail
// a PRNG that only needs unpredictability seeds from it once:
var seed: u64 = undefined;
platform.fillRandom(std.mem.asBytes(&seed));
```

The `std.Io` parameters webcrypto threads for entropy (asymmetric_keys.zig:50, secret_keys.zig:40,
operations.zig:22, tasks.zig:15, SubtleCrypto.zig:337) go.

### R10. A crypto primitive

src/webcrypto/{hash,hmac,kdf,okp,aes,ec,rsa}.zig and mbed.zig move to src/platform/kit/crypto/ behind
the operations of contract 6.8; src/webcrypto keeps normalize, registry, key, key_formats, der, jwk,
inputs, operations and tasks - every step a page can observe.

```zig
// Before
const signature = try ec.sign(allocator, io, curve, hash, secret, message);
// After
const signature = platform.ecdsaSign(allocator, curve, hash, secret, message) catch |err| switch (err) {
    error.OutOfMemory => return error.OutOfMemory,
    else => return error.OperationError, // WebCrypto's error, chosen here, the same on every platform
};
```

Pitfall: the error a page sees is decided above the protocol, from `CryptoError`, never by the
platform's library. A platform's implementation is accepted only when it passes the known-answer
vectors (src/webcrypto/rsa_vectors.zig and siblings, which move with kit/crypto).

**darwin's crypto for 0.1 follows its link plan (contract 10.1):** CommonCrypto for SHA-1/256/384/512,
HMAC, PBKDF2, AES-CBC, AES-KW and AES-CTR while the counter cannot wrap; SecKey for RSASSA-PKCS1-v1_5,
RSA-PSS with a salt equal to the hash length, RSA-OAEP with an empty label, RSA generation with the
exponent SecKey uses, ECDSA, ECDH and EC generation; kit/crypto for HKDF, AES-GCM, Ed25519, X25519 and
every parameter case Apple's libraries do not take - chosen per call (R0). linux links OpenSSL 3's
libcrypto once its vectors pass, kit/crypto otherwise. Each path runs the same vectors.

**Tests**: the known-answer vectors run through the protocol against kit/crypto, against darwin's
CommonCrypto/SecKey paths (on macOS, and in an iOS build) and against linux's libcrypto, including the
per-call boundaries (a PSS salt one byte off the hash length, an OAEP label, a CTR counter that wraps,
which must take the kit path and give the kit's answer); a fill of 0 bytes and two 32-byte fills that
differ. WPT: WebCryptoAPI/ (78 worklist files) A/B on each platform.

---

## Step 6. Threads, identity, diagnostics

### R11. Spawn a thread

```zig
// Before (src/html/worker_thread.zig:99, src/storage/indexeddb/worker_threads.zig:483)
const thread = try std.Thread.spawn(.{ .stack_size = stack }, run, .{ctx});
// After
const thread = try platform.spawnThread(.{ .name = "crane-worker", .stack_size = stack, .qos = .user_initiated }, runEntry, ctx);
// join: platform.joinThread(thread)   (src/html/worker_link.zig:74, 209)
```

`runEntry` is a `callconv(.c)` function taking the context pointer. IndexedDB's condition variables on
`host.io()` (worker_threads.zig:260-300) become std synchronisation, not platform calls.

### R12. A target branch

```zig
// Before (src/html/navigator/navigator_id.zig:126-151; also fetch/internal/user_agent.zig:14,
// file/algorithms/line_endings.zig:24, fs/context.zig:211-220, webidl/impls/Navigator.zig:338, 387,
// html/workers/worker_navigator.zig:267)
const platform_str = switch (builtin.os.tag) { .macos => "MacIntel", .ios => "iPhone", ... };
// After
const platform_str = platform.identity.navigator_platform;
```

hardwareConcurrency (navigator_concurrent_hardware.zig:49, Navigator.zig:434, worker_navigator.zig:289)
is `platform.logicalProcessorCount()`; navigator.language(s) (Navigator.zig:399's "en-US",
NavigatorLanguage.zig:43-51) read the Browser's preferred languages (BrowserOptions, else
`platform.preferredLanguages()`); tools/gc_bench.zig's `@import("memory")` becomes
`platform.residentMemory()` behind `resident_memory`.

**Tests**: worker thread tests (tests/html/workers/worker_thread_test.zig) and the navigator unit tests.
WPT: workers/ and html/webappapis/system-state-and-capabilities/ A/B.

---

## Step 7. The testing platform, platform events, media decoding

**Retires**: src/platform/media_backend.zig and media_adapter.zig (their callers move to the media_decoding operations).

**Goal**: the WPT runner builds with `-Dplatform=testing` and stops passing backends through
BrowserConfig; platform events reach Crane; media decoding is a capability.

**Files**

- src/platform/adapters/testing/: the build machine's OS services, kit/memory_clipboard, the fake
  capture devices, tests/wpt_runner/wav_backend.zig moved in as the WAV decoder (and lane/webm's WebM/Ogg
  decoder when merged), the prompt policy (decision 9), the dialog log, the file-upload queue, the
  console sink, all per BrowserPlatform; its control surface `platform.adapter.control`.
- src/html/platform_state.zig: the BrowserScope supplement holding the `*BrowserPlatform`, `of(realm)`,
  `portOf(realm)`, `requester(realm, id)`, and the EventSink that turns `PlatformEvent`s into tasks.
- `BrowserConfig.media_backend` (Browser.zig:109, 230) and src/html/media/runtime.zig's `MediaHost`
  (15-41) go: HTMLMediaElement (src/webidl/impls/HTMLMediaElement.zig:14, 36, 232, 262, 933) calls
  `platform.mediaCanPlayType` / `openMediaDecoder` / `pushMediaData` / `closeMediaDecoder` behind
  `media_decoding`. src/platform/media_backend.zig and media_adapter.zig are deleted (their C vtable's
  shape is the protocol's media records).
- tests/wpt_runner/wpt_browser.zig:107-114 passes the testing platform's per-Browser options instead
  of `.media_backend`.

### R13. Ask the platform, answer later

```zig
// The pattern every asynchronous capability call uses (contract section 4).
const pending = try html.platform_state.PendingRequest(PositionResult).create(realm, promise_capability);
// pending holds: a TaskSink reference, the realm's Context and generation, the continuation,
// the RequestId, and two holds (the platform's and the realm's).
platform.currentPosition(browser, &html.platform_state.requester(realm, pending.id), &options, pending.reply());
// deliver/drop post a task; the task checks realm.hasEngine() and pending.live, then runs the
// spec's steps - or, on drop, the spec's failure path. The realm's end marks pending dead and calls
// platform.cancelRequest(browser, pending.id).
```

Pitfall: never resolve, reject or touch an Instance inside `deliver` or `drop` - they may run on any
thread. The record is freed when both holds are gone, which can be after the Browser ends.

### R14. A platform event

`PlatformEvent`s arrive on any thread through the EventSink; `html.platform_state` copies each and
queues its steps on the Browser's loop (and the workers subscribed to it), as contract section 7 lists.
Steps run in tasks, never in `post`.

**Tests**: tests/platform/reply_test.zig - a reply delivered from another thread after its realm ended
frees without running steps, a drop runs the spec's rejection, a deliver inside the call still queues
(std.testing.allocator, a two-thread stress of 1,000 requests); an event posted from another thread
queues its task; tests/html/media/host_backend_test.zig moved onto the testing platform. WPT: the media
files (mixed-content audio-tag/video-tag, CSP media-src; about 41) A/B, and a sample - the runner's
platform changed.

---

## Step 8. Permissions

The model is contract section 8: where the OS governs a descriptor (darwin: camera, microphone,
geolocation, notifications) the OS's per-app decision is the state and Crane creates no prompt; where no
OS governs it (everything on linux and the testing platform, the rest on darwin) Crane's store holds it
per Browser, and the platform's policy answers a request in the prompt state without UI.

**Files**: src/permissions/ becomes the Browser's permission store for ungoverned descriptors (a
BrowserScope supplement, persisted through the storage engine with a profile; `PermissionStatus.next_id`,
src/permissions/status.zig:35, moves onto it); impls Permissions.zig (query, :60),
PermissionStatus.zig, Navigator.zig:120, WorkerNavigator.zig:113; Permissions 5.1-5.2 around
`platform.platformPermissionState` and `platform.requestPermission` (R13); `Browser.setPermission` for
the store, and the `permission_changed` event's steps for both kinds; testdriver's `set_permission`
native in tests/wpt_runner/test_driver.zig (:68 lists today's natives) calling `Browser.setPermission`;
Storage's persist() through the model, replacing the process-global
`StorageManager.permission_callback` (src/storage/storage_manager.zig:55-60, 152). darwin's governed
descriptors map the OS authorization status (not determined = prompt, denied or restricted = denied,
authorized = granted), and `requestPermission` calls the OS request API on the main queue.

**Tests**: unit tests of 5.1 for both kinds (non-secure -> denied before anything else; a governed
descriptor answers the platform's state and writes no entry; an ungoverned one answers its store entry,
else the platform default) and 5.2 (a governed request calls the platform once and resolves from a
task; an ungoverned request in the prompt state follows the platform's policy and sets the entry from a
task; PermissionStatus `change` on `permission_changed`). On macOS, a tests/platform test of darwin's
status mapping with the OS state stubbed at the adapter boundary. WPT: permissions/ (14 worklist files;
7 call `test_driver.set_permission`) on the testing platform. Automation for OS-governed descriptors on
darwin waits on contract 13's open question 1.

---

## Step 9. Dialogs, printing, console, windows, screen and system state

**Retires**: src/platform/ui_adapter.zig.

**Files**

- Window.zig's alert/confirm/prompt/print (src/webidl/impls/Window.zig:1920-1946, 2509-2518,
  3492-3505) run HTML 8.9.1's steps - "cannot show simple dialogs", normalizing and truncation, the
  WebDriver BiDi user prompt handler - and only for a "none" handler ask `platform.runSimpleDialog` and
  pause (R15); `call_alert__1` (alert(message), NotImplemented today) is implemented; the stub UI
  backend (Window.zig:115-118, 271-273, 497) and src/html/window/ui_backend.zig go. darwin presents
  the system alert over the app's key window (NSAlert on macOS, UIAlertController on iOS, on the main
  queue); with no key window it drops the Reply and Crane takes "cannot show simple dialogs".
- console.zig's printer (src/webidl/impls/console.zig:45-64) calls `platform.printConsoleMessage`.
- window.open/close (Window.zig:3039, 2907) ask `createTopLevelTraversable` and report
  `traversableChanged`; moveTo/resizeTo (2441, 3487) call `requestWindowRect`; outer geometry reads
  `windowRect`.
- Screen.zig (42-46, 69, 109), navigator.onLine (Navigator.zig:418, WorkerNavigator.zig:294), media
  queries' user preferences and the tab's visibility read the platform (`screenInfo`, `isOnline`,
  `userPreferences`, `systemVisibility`) and update from events.

### R15. Pause for an answer

```zig
// HTML "pause": wait on the agent's port, running none of this agent's tasks, until the reply's task
const pending = try PendingRequest(DialogResult).create(realm, .pause);
platform.runSimpleDialog(browser, &requester, &request, pending.reply());
while (!pending.answered()) platform.waitEventLoopPort(port, null); // the reply's post wakes it
const result = pending.take(); // dropped: the spec's "cannot show" answer
```

Pitfall: the pause must not run other tasks of the same agent (HTML's pause runs none), but it must
keep the port's I/O and other agents' threads unaffected; and a realm torn down during the pause (a
frame removed by another thread's message) ends the wait with the dropped answer.

**Tests**: confirm() pauses until a reply delivered from another thread and returns it; a "none"
handler asks the platform and an "accept" handler does not. WPT: the 22 worklist files using prompts or
print, workers/WorkerNavigator_onLine.htm, the window-open files A/B.

---

## Step 10. File pickers

**Files**: HTMLInputElement.zig (the File Upload state's picker and showPicker, :1446-1671),
HTMLSelectElement.zig:515 (showPicker), File System Access's pickers (Window.zig:2359, 2448, 2469)
calling `platform.showFilePicker` (R13), File's bytes through `readPickedFile` / `releasePickedFile`;
the WPT runner's testdriver `file_upload` fills the testing platform's queue (un-exclude
tests/wpt_runner/config.zig:251's `testdriver/file_upload`). darwin presents the system pickers over
the key window (NSOpenPanel / NSSavePanel on macOS; UIDocumentPickerViewController, and
PHPickerViewController for image and video `accept`, on iOS); with no window, no file is chosen.

**Tests**: a picked file's name, type, size and bytes reach the File; a canceled picker fires `cancel`.
WPT: the 17 type=file and 17 showPicker worklist files A/B.

---

## Step 11. The clipboard (decision 8)

**Retires**: src/platform/clipboard_backend.zig and clipboard_adapter.zig (selection_ops.zig's ClipboardBackend moves to the protocol's clipboard).

**Files**: impls Clipboard.zig (:60, 67), Navigator.zig:96 (`navigator.clipboard`), ClipboardItem,
execCommand copy/cut/paste (src/html/editing/executor.zig:126, selection_ops.zig:302) through
`platform.readClipboard` / `writeClipboard`, with the Async Clipboard API's permission and activation
rules above; src/html/navigator/clipboard/root.zig's private ClipboardBackend and
src/html/navigator/navigator.zig:69's field go. darwin: NSPasteboard (macOS) / UIPasteboard (iOS) on
the main queue - iOS shows its own paste prompt; linux: the system clipboard when a display is present,
kit/memory_clipboard otherwise; testing: kit/memory_clipboard per Browser.

**Tests**: write then read round-trips through the testing platform; two Browsers' in-memory
clipboards are separate; a read without permission or activation rejects as the spec says. WPT:
clipboard-apis/ when it joins the worklist (58 files, 0 today), and the execCommand copy file.

---

## Step 12. Layout (decision 14)

**Retires**: src/platform/layout_backend.zig and layout_adapter.zig, and src/webidl/impls/HTMLElement.zig:32's unused `layout_backend` import.

**Files**: src/platform/layout_backend.zig's types become the protocol's layout records (BoxMetrics,
Rect); the CSSOM View members of Element/HTMLElement (offset*, client*, scroll*, getBoundingClientRect,
getClientRects, scrollTo, elementFromPoint/elementsFromPoint, innerText's rendered-text steps) ask the
layout operations behind `layout`, and take CSSOM View's no-layout-box answers in the `else` - the
headless answer, as today. Selection's line granularities (src/webidl/impls/Selection.zig:549-596)
likewise. Crane assigns `LayoutNode` ids per Browser. How a renderer reads the DOM and computed style
is designed when the first real rendering host plugs in (settled, contract 13).

**Tests**: with `layout` unsupported, every CSSOM View member answers what it answers today (pinned
first); a testing-only layout stub that reports one fixed box shows the members read it. WPT: no
change expected (css/cssom-view/ is outside the worklist).

---

## Step 13. Every other page capability behind its gate (decision 7)

**Retires**: src/platform/notification_backend.zig, notification_adapter.zig, push_backend.zig and push_adapter.zig.

Every operation of contract 6.10 exists from step 0, and every built-in platform answers its
unsupported path. This step makes each API's impl call its operation behind its gate, with the spec's
unsupported path in the `else`, replacing the NotImplemented stubs (inventory section 9.2: media
capture, screen capture, audio output, speech, notifications, push and background work, geolocation,
sensors, devices, gamepad, payment, credentials, share, contacts, fullscreen, pointer lock, keyboard
lock and map, wake lock, battery, vibration, badging, EyeDropper, local fonts, network information,
compute pressure, device posture, idle detection, virtual keyboard, picture-in-picture, media session,
presentation, remote playback, EME, WebCodecs, media capabilities, protocol handlers). One lane per
group; none has a 0.1 worklist file, so order by demand.

### R16. A capability API, unsupported first

```zig
// Before (src/webidl/impls/MediaDevices.zig:85-94)
pub fn call_enumerateDevices(instance: *runtime.Instance) anyerror!runtime.JSValue {
    _ = instance;
    return error.NotImplemented;
}

// After: the spec's algorithm, the platform behind the gate, the unsupported path in the else
pub fn call_enumerateDevices(instance: *runtime.Instance) anyerror!runtime.JSValue {
    // 1. A new promise (engine protocol R16).
    // 2. If camera or microphone is not .unsupported: ask platform.enumerateMediaDevices through
    //    R13; its task runs "device information exposure" and resolves with the MediaDeviceInfos.
    // 3. Else: resolve with an empty list - Media Capture and Streams' answer with no devices.
    // 4. Return the promise.
}
```

**Tests**: per API, a test with the capability forced off (`-Dplatform-without=<name>` in a test tier)
asserting the spec's unsupported answer, and one against the testing platform where it implements the
capability.

---

## Step 14. darwin's native capabilities, by demand

Each a lane that implements one capability in src/platform/adapters/darwin/ through the system
framework its link plan names (contract 10.1) and flips its constant: media decoding
(AVFoundation/VideoToolbox/AudioToolbox), camera and microphone (AVFoundation; the OS permission
system, contract section 8), notifications (UserNotifications), geolocation (CoreLocation), audio
output (AVFAudio/AudioToolbox), and the rest by demand (GameController, CoreBluetooth, CoreMIDI, CoreNFC
on iOS, IOKit on macOS, AuthenticationServices, PassKit, Speech). Dialogs and pickers are steps 9 and
10. Each with tests/platform tests on macOS, an `aarch64-ios` build, and its WPT directory A/B on macOS.
Before a platform's defaults are frozen, the deployment targets of contract 13's open question 2 are
chosen and each link-plan row records its minimum OS version.

---

## Step 15. The C API (decision 4)

**Retires**: the old C ABI - src/platform/exports.zig, platform_backend.zig, vtables.zig and stub_platform_backend.zig, build.zig's `lib` step (libwhatwg) with its packaging in .github/workflows/{swift,kotlin,release}.yml, src/lib_exports.zig's whatwg_platform_* re-exports and PlatformBackend reference, tests/platform/platform_backend_test.zig, include/whatwg_backend.h and docs/swift-integration.md's section - and the old src/platform/root.zig, once nothing it lists remains.

**Files**: include/crane.h - `crane_browser_create(const crane_browser_config_t *)` with the
BrowserOptions fields (profile directory, user agent, languages, proxy, trust anchors) - no app
callbacks are needed for permissions, dialogs or pickers (contract 13, settled); Crane owns the Browser's thread
(`crane_browser_create` starts it with `platform.spawnThread` at the app's requested priority, and every
`crane_*` call posts to it - decision 13); `crane_browser_destroy`, `crane_browser_navigate`,
`crane_browser_evaluate`, `crane_tab_*`. src/lib_exports.zig exports them; the header-less
`whatwg_browser_*` and `whatwg_runtime_*` functions (lib_exports.zig:136-247) and the platform half of include/whatwg.h,
include/whatwg_backend.h, include/whatwg_types.h go, with docs/swift-integration.md,
docs/kotlin-integration.md and docs/capability-implementation.md rewritten against crane.h (decision 15).

**Tests**: tests/linked_libraries/ - a C program creates a Browser on its own Crane-owned thread,
evaluates a script and reads the result; a C struct built against an older `struct_size` still works.
An `aarch64-ios` build links the library into a minimal app target.
