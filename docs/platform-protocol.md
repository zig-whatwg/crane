# The platform protocol

**Status: design, approved by the user's decisions of 2026-10-09; nothing is built yet.** When
`src/platform/protocol.zig` exists, its signatures and doc comments are the contract and this file
summarises it - it never overrides the code. How to move existing code onto the protocol is in
[platform-protocol-recipes.md](platform-protocol-recipes.md), in order. The survey it was designed
against (every OS and host touchpoint, file by file) is tmp/plans/platform-inventory.md, and the
reasoning and engine precedent behind it are tmp/plans/platform-protocol-design.md (both local
working documents). Why the seam is designed whole before anything migrates:
[the lesson](lessons/architecture-design-the-protocol-before-migrating.md).

Crane's platform is an adapter, as its JavaScript engine is (docs/engine-protocol.md). Everything
platform-specific - the OS services Crane needs on every target AND the capabilities a browser offers
pages (camera, clipboard, notifications, layout, ...) - is reached through one module, `platform`,
bound at build time to one platform implementation. Nothing else in src/ calls an OS API.

## 1. Shape

```
src/platform/protocol.zig            module "platform" - THE PROTOCOL
    const impl = @import("platform_impl").protocol;   bound by build.zig
    pub inline fn monotonicNow() Instant { return impl.monotonicNow(); }
    ... one forwarding function per operation; its signature is the contract
    comptime { conformance check }    every pub inline fn, exact types (engine_protocol.zig's check)

src/platform/adapters/darwin/        macOS and iOS (comptime os.tag branches inside)
src/platform/adapters/linux/         Linux
src/platform/adapters/testing/       the build machine's real OS services (darwin's or linux's)
                                     plus compiled-in test capabilities - what the WPT runner and
                                     the test tiers build with (section 9)
src/platform/kit/                    Crane's reusable implementations, one module per part, which
                                     any platform - built-in or third-party - may use:
    posix/      clocks, files, entropy, threads over libc
    curl/       the network: libcurl + mbedTLS (moved from src/fetch/network, src/websocket)
    sqlite/, leveldb/, memory_store/   storage engines
    crypto/     WebCrypto primitives: Zig std.crypto + mbedTLS
    headless/   every capability's "unsupported" answer, and the headless defaults
    memory_clipboard/   a per-Browser in-memory clipboard
```

The kit is also every platform's static fallback: where a platform links a system library for a
capability (section 10, the link plans), the kit's implementation is what it compiles instead when the
system library is missing, does not do what Crane needs, or is not trusted - and a platform may carry
both and choose at build time.

- Consumers write `const platform = @import("platform");` and call `platform.op(...)`. Dispatch is
  static: each operation is a `pub inline fn` whose body calls the bound implementation's function of
  the same name, so a call site compiles to a direct call. No table, no optional unwrap, no run-time
  host object.
- **Every `pub inline fn` in protocol.zig is an operation.** A comptime block checks that the bound
  implementation declares each one with exactly the protocol's parameter and return types (not
  generic) - a missing or mis-typed operation is a compile error naming it, whether or not anything
  calls it (docs/lessons/architecture-a-forwarding-facade-checks-only-what-gets-called.md). It also
  requires the declarations of section 1.3. Helpers built over operations (`monotonicMillis`,
  `Stopwatch`) are plain `pub fn`s. In a test build the implementation's functions are compiled whole,
  so a stub nothing calls still type-checks.
- **`platform` is a leaf.** The facade imports only std, `platform_impl` and `build_options`. Its
  types are its own (Instant, HttpRequest, PermissionDescriptor, ...): fetch, storage, webcrypto,
  html and the impls convert at their edge. That is what lets fetch, storage, cookiestore, infra,
  hr_time, dom, html, impls, runtime, websocket, webcrypto, browser and the engine adapter all import
  it without a cycle. An implementation imports std, the facade, the kit parts it uses, and its C
  libraries and OS frameworks.

### 1.1 Choosing the platform

| Option | Meaning |
|---|---|
| `-Dplatform=darwin` / `linux` / `testing` | a built-in platform. Default: from the target (`darwin` for macOS and iOS, `linux` for Linux) |
| `-Dplatform-module=<path>` | a THIRD-PARTY platform: the root file of an implementation that lives outside Crane (a Windows port, a console, an embedded board). build.zig makes it the `platform_impl` module, gives it the `platform` facade and the kit modules to import, and the same conformance check holds it to the contract. A package dependency can supply the path |
| `-Dplatform-without=<capability>,...` | compile capabilities OUT (section 5): each named capability reads `.unsupported` whatever the platform declares, so neither Crane's feature code nor the platform's implementation of it is in the binary, and the system library it would link is not linked |
| `-Dplatform-static=<item>,...` | compile the kit's static implementation for the named link-plan items instead of linking the system library (section 10); `all` for a fully static build |

The JavaScript engine is chosen the same way (`-Dengine=`), and the two are independent.

**Each artifact is built against its own platform.** build.zig builds its module graph through one
function per platform, so one invocation can build the library, the CLI and the iOS build against the
target's platform and the WPT runner and the test tiers against `testing`. Each artifact is already its
own compile, so this costs no extra analysis; within one compile every file belongs to one module, as
Zig requires (docs/lessons/architecture-a-module-bound-twice-cannot-share-a-compile.md).

### 1.2 Third-party platforms

The protocol is a public contract. An outside implementation is a Zig module whose root declares
`pub const protocol` - a namespace holding every operation and the declarations of 1.3 - and is
selected with `-Dplatform-module`. It
may reuse any kit part - a Windows platform would typically write its own clocks, files, threads and
system clipboard and take kit/curl for the network, kit/sqlite for storage, kit/crypto for WebCrypto
and kit/headless for every capability it does not implement yet. Kit parts are separate modules, each
linking only its own C library, so a platform that does not use kit/curl does not link libcurl.

Rules for any platform: types crossing the protocol are the facade's; a capability is declared
`.native`, `.emulated` (with its deviations listed at the constant) or `.unsupported`; every operation
of an `.unsupported` capability still exists with its exact type and gives the spec's unsupported
answer (kit/headless has them all, to alias); and web-visible behaviour must not depend on the
platform beyond what a capability declares (storage and crypto especially: sections 6.6, 6.8).

### 1.3 What every platform's `protocol` namespace declares

| Declaration | Type | Meaning |
|---|---|---|
| `protocol` | namespace | every operation of section 6, by name |
| `name` | `[]const u8` | for messages ("darwin", "testing") |
| `capabilities` | `platform.Capabilities` | section 5 |
| `identity` | `platform.Identity` | comptime identity constants (6.1) |
| `PlatformBrowserOptions` | `extern struct`, every field defaulted (so `.{}` is valid) | the platform's own per-Browser options (3.2): the testing platform's fake devices, prompt policy and console sink |

The facade also re-exports the bound implementation as `platform.adapter`, for surfaces only one
platform has (the testing platform's control surface, section 9). Code that uses it compiles on that
platform only, so only tests/ may use it; the lint counts `platform.adapter` anywhere else.

### 1.4 C compatibility

Decision 4 puts the C API last, so everything that crosses the protocol is C-representable from the
first step: records are `extern struct`s, enums have explicit integer tags, strings and byte runs are
`Str` / `Bytes` (pointer and length), callbacks are `callconv(.c)` function pointers with a context
pointer, and `Reply(T)` (section 4) is an extern struct. Zig error unions and slices appear only at
the Zig surface, each with a mechanical C form (a status code; pointer and length). The C API is then
a thin export (include/crane.h), not a second design.

## 2. Types and ownership

The types are the ownership rule, as in the engine protocol.

| Type | Meaning |
|---|---|
| `Instant` | `extern struct { ns: u64 }` on the monotonic clock, arbitrary origin. HR-Time 2.1's monotonic clock. |
| `WallTime` | `extern struct { ns_since_epoch: i64 }`, the wall clock; it jumps. HR-Time 2.1's wall clock. |
| `Str`, `Bytes` | Pointer and length. BORROWED for the call unless an operation says it returns one OWNED (then allocated with the allocator passed in). |
| `Error` | `error{ OutOfMemory, NotSupported, AccessDenied, NotFound, AlreadyExists, NoSpace, Io, Canceled, Busy }` for operations that can fail. `NotSupported` only from an operation whose capability is `.unsupported`. Network failures are `HttpError` (6.7), storage failures `StoreError` (6.6), crypto failures `CryptoError` (6.8). |
| `BrowserPlatform` | Opaque per-Browser platform state (section 3). OWNED by the Browser: `createBrowserPlatform` / `destroyBrowserPlatform`. Every per-Browser operation takes it first. |
| `Requester` | Who asks, BORROWED for the call: `request_id: RequestId`, `tab: TabId`, `frame: FrameId`, `origin` and `top_level_origin` (serialized - the permission key's inputs, Permissions 3.2), `secure_context`, `transient_activation`. No realm or engine value crosses. |
| `RequestId` | `u64`, unique per Browser; names a pending request for `cancelRequest`. |
| `Reply(T)` | One asynchronous answer (section 4). OWNED by the platform from the call until it calls exactly one of `deliver` / `drop`. |
| `EventSink` | Crane's receiver for what the platform reports unasked (section 7); given to `createBrowserPlatform`, BORROWED by the platform until `destroyBrowserPlatform` returns. |
| `EventLoopPort` | One event loop's OS side - its sockets, its wait, its wake (6.7). OWNED by the event loop; used on its thread only, except `wakeEventLoopPort`. |
| `Transfer`, `WebSocket` | OWNED by their port until their client's last callback or a cancel. |
| `Store`, `StoreTransaction`, `StoreCursor` | Storage engine handles (6.6), OWNED until closed / committed or aborted / closed. |
| `MediaDecoder`, `Codec`, `CaptureSource`, `AudioOutput`, `DeviceHandle`, `SensorHandle` | Capability objects, OWNED by Crane from a successful open until its close call. |
| `FileToken` | A file the user picked (6.10.3), OWNED until `releasePickedFile`. |
| `Thread` | OWNED by the spawner until `joinThread`. |
| Returned slices | Allocated with the allocator the caller passed; the caller's. |

## 3. Per-Browser state

Capabilities are compiled in (decision 3), so there is no run-time host object. What differs between
two Browsers in one process is DATA, held by the platform per Browser:

```zig
pub inline fn createBrowserPlatform(allocator: Allocator, options: *const BrowserOptions, events: EventSink) Error!*BrowserPlatform
pub inline fn destroyBrowserPlatform(browser: *BrowserPlatform) void
```

### 3.1 BrowserOptions (the protocol's)

| Field | Meaning |
|---|---|
| `profile_dir: ?Str` | Where the Browser's stores live. Null: in memory, nothing written to disk (decision 12; docs/instances.md). The CLI passes `defaultDataDirectory()`. |
| `user_agent: Str` | Empty: the platform's default (from `identity`). |
| `preferred_languages: ?[]const Str` | Null: the platform's (OS) preference list. |
| `proxy: ?ProxyConfig` | Explicit proxies only for 0.1 (docs/instances.md). |
| `extra_trust_anchors_pem: Bytes` | Added to the platform's trust store (the WPT runner's cacert.pem). |
| `platform: PlatformBrowserOptions` | The platform's own options (3.2). |

### 3.2 The platform's own options

Each platform declares `PlatformBrowserOptions` (section 1.3), which the facade re-exports under the same name.
Examples: the testing platform's fake capture devices, its prompt policy and its console sink
(section 9). darwin needs none for its UI - it uses the OS's own permission system and native system UI
over the app's key window (6.10, section 8) - and no app callbacks are required. A host built for one
platform sets that platform's fields; code meant for every platform leaves the field at `.{}`.

Per-Browser differences are options and state only. Implementations do not mix in one process, and
state the OS owns is the OS's: darwin's permission decisions are per app, shared by every Browser in
the process (section 8).

### 3.3 What the BrowserPlatform holds

The network context (DNS cache, connections, TLS sessions, proxy, trust - today process-global:
src/fetch/network/curl_backend.zig:46-55, connection_pool.zig:635, backend.zig:85), the profile's
stores, the in-memory clipboard where the platform has no system clipboard, the testing platform's
per-Browser fake state, and the platform's observers (screen, network reachability, memory pressure)
that report through the EventSink.

Crane holds the Browser's BrowserPlatform as part of the Browser (BrowserScope, docs/instances.md
rule 2); a realm reaches it through `realm.browser_scope`. A worker realm carries its creator's scope,
so a worker's requests use its Browser's BrowserPlatform.

## 4. Threads and asynchronous results

- **OS operations** may be called from any thread unless the operation says otherwise.
- **Per-Browser operations** are called on the thread of the agent that needs them: the Browser's
  thread for a window, frame or popup; a worker's own thread for a worker (decision 17). They return
  promptly. Where an OS API must run on a main queue (UIKit, AppKit, AVFoundation, UIPasteboard), the
  platform hops there itself and answers through the Reply.
- **An asynchronous operation takes a `Reply(T)`:**

```zig
pub fn Reply(comptime T: type) type {
    return extern struct {
        context: *anyopaque,
        /// The value is BORROWED for the call; Crane copies what it keeps.
        deliver: *const fn (context: *anyopaque, value: *const T) callconv(.c) void,
        /// No answer: canceled, or the platform cannot answer. Crane takes the spec's failure path.
        drop: *const fn (context: *anyopaque) callconv(.c) void,
    };
}
```

  The platform calls exactly one of `deliver` and `drop`, once, from any thread, at any time after
  the call - before the operation returns included. Crane never runs the request's steps inside
  either: both post a task to the requesting agent's event loop (its `runtime.TaskSink`, which wakes
  the loop's port). The task checks that the realm still has an engine and the request is still live
  before it runs the spec's steps (resolve, or the spec's rejection on drop), as Blink drops a result
  whose context is destroyed.
- **Cancellation.** When a realm ends with requests pending, Crane marks them dead and calls
  `cancelRequest(browser, id)` - a hint (take a prompt down, stop a camera). The platform still
  completes the Reply; a completion for a dead request only frees. The same at the Browser's end: a
  pending request's record outlives its Browser until the platform completes it, so a platform must
  complete or drop every Reply it was given.
- **Synchronous spec steps over asynchronous platforms.** HTML's simple dialogs "pause until the user
  responds" (HTML 8.9.1, confirm step 7). Crane pauses by waiting on the agent's EventLoopPort without
  running that agent's tasks until the Reply arrives; the platform answers from the OS main queue
  while the agent's thread waits.

This is the dropped-end rule (docs/lessons/architecture-a-callback-the-engine-may-never-make-needs-a-dropped-end.md)
and the liveness rule (docs/lessons/architecture-native-owner-liveness-differs-from-realm-callability.md).

## 5. Capabilities

`platform.capabilities` is a comptime struct of `Support`: `.native` (the platform does it),
`.emulated` (built on what the platform has, with deviations listed at its constant), `.unsupported`
(the spec's unsupported path). It is the platform's declaration, with every capability named in
`-Dplatform-without` forced to `.unsupported`.

A gated operation names its capability once, in its body; calling it outside a check is a compile
error that says how to write it:

```zig
if (platform.capabilities.camera != .unsupported) {
    platform.openCaptureSource(browser, &requester, &request, reply);
} else {
    // Media Capture and Streams: no device - getUserMedia rejects with NotFoundError.
}
```

So **an unsupported capability compiles out on both sides**: Crane's feature code for it is in a
branch the compiler drops, and the platform's implementation is never referenced. A capability
answers its spec's unsupported path in every build that lacks it - the binary is smaller, never
different in kind. kit/headless implements every gated operation's unsupported answer, so a platform
aliases those until it implements one (`pub const openCaptureSource = headless.openCaptureSource;`).

Required of every platform (no capability): clocks, randomness, threads, files, the storage engine
(kit/memory_store at least), the crypto primitives (kit/crypto at least), the network, screen and
system state (defaults allowed), console output.

| Capability | darwin | linux | testing | Unsupported path |
|---|---|---|---|---|
| `persistent_storage` | native | native | native | stores in memory; StorageManager.persisted() false (Storage 5) |
| `file_urls` | native on macOS, unsupported on iOS (sandbox) | native | native | Fetch 4.3 scheme fetch "file": network error |
| `system_trust_store` | native (SecTrust, decision 6) | emulated (distro CA bundle: no revocation, no enterprise roots) | as its host OS | only `extra_trust_anchors_pem` trusted |
| `http2` / `http3` | native when built with nghttp2 / unsupported | same | same | HTTP-network fetch step 8.3: an HTTP/2-only request is a network error / HTTP/1.1 and 2 only |
| `thread_qos` | native | unsupported | as its host OS | default priority |
| `resident_memory` | native | native | native | diagnostics report nothing |
| `layout` | unsupported (headless) | unsupported | unsupported | CSSOM View with no layout box: zero boxes, no hit (6.9) |
| `os_permissions` | native: the OS permission system, per app (section 8) | unsupported (no OS permission system: Crane's store and the platform's policy) | emulated (Crane's store; scripted policy, section 9) | a request in the prompt state is denied |
| `simple_dialogs` | native: system alerts over the key window (NSAlert; UIAlertController), the unsupported path with no window | unsupported | native (dismiss) | HTML 8.9.1 "cannot show simple dialogs" |
| `printing` | unsupported | unsupported | native (no output) | printing steps end without output |
| `file_picker` | native: NSOpenPanel / NSSavePanel; UIDocumentPickerViewController, PHPickerViewController - over the key window, the unsupported path with no window | unsupported | native (testdriver queue) | no files chosen (`cancel`) |
| `windows` | native | native | native | every popup allowed; rects ignored |
| `media_decoding` | unsupported until built (AVFoundation) | unsupported | native (WAV; WebM/Ogg) | canPlayType "" |
| `webcodecs`, `media_capabilities`, `encrypted_media` | unsupported | unsupported | unsupported | NotSupportedError |
| `camera`, `microphone` | unsupported until built (AVFoundation) | unsupported | native (fake devices) | enumerateDevices() empty; getUserMedia NotFoundError |
| `screen_capture` | unsupported | unsupported | unsupported | getDisplayMedia NotAllowedError |
| `audio_output` | unsupported until built | unsupported | native (silent sink) | no output device |
| `speech_synthesis`, `speech_recognition` | unsupported | unsupported | unsupported | no voices; recognition "service-not-allowed" |
| `clipboard` | native (NSPasteboard / UIPasteboard, decision 8) | native with a display (X11/Wayland), emulated (in-memory) without | emulated (in-memory per Browser) | Clipboard API read/write reject NotAllowedError |
| `notifications` | unsupported until built (UserNotifications) | unsupported | native (recorded) | never shown; permission "denied" |
| `push`, `background_sync`, `background_fetch` | unsupported | unsupported | unsupported | the API's no-service rejection |
| `geolocation` | unsupported until built (CoreLocation) | unsupported | native (scripted) | POSITION_UNAVAILABLE |
| `sensors` (per type), `device_orientation` | unsupported | unsupported | unsupported | NotReadableError / no events |
| `usb`, `hid`, `serial`, `bluetooth`, `nfc`, `midi` | unsupported | unsupported | unsupported | no device chosen (NotFoundError) |
| `gamepad` | unsupported | unsupported | unsupported | no gamepads |
| `payment`, `webauthn`, `identity_credentials`, `share`, `contacts` | unsupported | unsupported | unsupported | the API's rejection (NotSupportedError / NotAllowedError / AbortError) |
| `fullscreen`, `pointer_lock`, `keyboard_lock`, `wake_lock` | unsupported | unsupported | unsupported | the request fails as its spec says (TypeError, pointerlockerror, NotAllowedError) |
| `idle_detection`, `battery`, `vibration`, `badging`, `eyedropper`, `local_fonts`, `keyboard_map`, `screen_details`, `presentation`, `remote_playback`, `picture_in_picture`, `media_session`, `network_information`, `compute_pressure`, `device_posture`, `virtual_keyboard`, `protocol_handlers` | unsupported | unsupported | unsupported | each spec's default or rejection (6.10) |

"Unsupported until built" means the darwin platform declares `.unsupported` and aliases kit/headless
today; a lane that implements the capability flips the constant.

## 6. Operations

`src/platform/protocol.zig` groups them; each group names the spec it follows. "any" = any thread;
"agent" = the requesting agent's thread (section 4); [x] = gated on capability x.

### 6.1 Process and identity

| Operation | Signature | Thread | Notes |
|---|---|---|---|
| `initializePlatform` | `(options: *const PlatformOptions) Error!void` | once, before any Browser | crane.Process calls it. Holds what is truly per process: curl_global_init, the process Io and its SIGIO/SIGPIPE dispositions (src/platform/host.zig:32-39). |
| `deinitializePlatform` | `() void` | at process end | |
| `identity` | `pub const identity: Identity` | - | comptime: `navigator_platform`, `ua_os_token`, `oscpu`, `native_line_ending` (File API), `path_separator`, `storage_engine`. HTML 8.10.1.1 Client identification. |
| `defaultDataDirectory` | `(allocator) Error!?[]u8` | any | The CLI's profile root, OWNED (macOS ~/Library/Application Support/Crane; Linux $XDG_DATA_HOME/crane; null on iOS - the app passes its container). |
| `preferredLanguages` | `(allocator) Error![]Str` | any | The OS's preferred languages, OWNED. HTML 8.10.1.2. |
| `defaultTimeZone` | `(allocator) Error![]u8` | any | IANA id for the engine adapter's Date/Intl. |
| `logicalProcessorCount` | `() u32` | any | navigator.hardwareConcurrency. |
| `deviceMemoryGiB` | `() f64` | any | navigator.deviceMemory before Device Memory's rounding. |
| `residentMemory` | `() ?MemoryReading` [resident_memory] | any | Diagnostics (tools). |

### 6.2 Clocks (HR-Time 2.1)

| Operation | Signature | Thread | Notes |
|---|---|---|---|
| `monotonicNow` | `() Instant` | any, hot | The monotonic clock's unsafe current time. Darwin `mach_absolute_time`, Linux `clock_gettime(CLOCK_MONOTONIC)`. No dispatch: performance.now and every Event.timeStamp pay one libc call. |
| `wallNow` | `() WallTime` | any | The wall clock's unsafe current time. |
| `sleepThread` | `(nanoseconds: u64) void` | any | TRANSITIONAL: exists until the network step replaces the remaining sleeps with port waits (recipes step 2), then is deleted. |
| helpers (`pub fn`) | `monotonicMillis`, `wallMillis`, `wallSeconds`, `Stopwatch` | any | Over the two clocks. |

### 6.3 Randomness

| Operation | Signature | Thread | Notes |
|---|---|---|---|
| `fillRandom` | `(bytes: []u8) void` | any | Cryptographically strong bytes from the OS. Cannot fail: the platform aborts if the OS cannot supply entropy. WebCrypto 10.1.1 getRandomValues, 10.1.2 randomUUID, every key generation, and every PRNG seed in Crane. |

### 6.4 Threads

| Operation | Signature | Thread | Notes |
|---|---|---|---|
| `spawnThread` | `(options: ThreadOptions, entry: *const fn (?*anyopaque) callconv(.c) void, context: ?*anyopaque) Error!Thread` | any | `ThreadOptions{ name, stack_size, qos }` [thread_qos for qos]. Worker agents, IndexedDB's workers, a C embedder's Browser thread (decision 13). |
| `joinThread` | `(thread: Thread) void` | any | |

Mutexes, conditions, futexes, atomics, `std.Thread.yield` and thread ids stay std - synchronisation,
not platform policy.

### 6.5 Files and storage locations

| Operation | Signature | Thread | Notes |
|---|---|---|---|
| `makeDirectoryPath` | `(path: Str) Error!void` | any | |
| `readFile` | `(allocator, path: Str, limit: usize) Error![]u8` | any | OWNED. The V8 snapshot, CLDR data, file: URLs [file_urls] (Fetch 4.3 scheme fetch "file"). |
| `writeFileAtomic` | `(path: Str, bytes: Bytes) Error!void` | any | Write, then rename. |
| `deleteFile`, `deleteTree` | `(path: Str) Error!void` | any | |
| `fileInfo` | `(path: Str) Error!FileInfo` | any | `{ size, modified: WallTime, kind }` |
| `listDirectory` | `(allocator, path: Str) Error![]DirEntry` | any | OWNED. |
| `volumeSpace` | `(path: Str) Error!VolumeSpace` | any | `{ total, available }`: the input to Storage 6 "Usage and quota". |

Paths are absolute UTF-8. A Browser's storage locations are under its `profile_dir`; Crane's storage
model (Storage 4.2 storage keys, 4.6 storage bottles) stays above the protocol.

### 6.6 The storage engine (decision 10)

A transactional, ordered key-value store: the common shape of SQLite, LevelDB and an in-memory map,
and of what Crane's stores need (IndexedDB, localStorage persistence, Cache API, the permission
store). kit/sqlite, kit/leveldb and kit/memory_store implement it; darwin, linux and testing use them
(today's choice: SQLite on iOS, LevelDB on desktop, memory with no profile directory), and a platform
may supply its own.

**Web-visible behaviour is above the protocol.** Keys are byte strings compared lexicographically
(unsigned bytes) - the one order every implementation must give, so an IndexedDB key range or cursor
order is the same on every platform: Crane encodes IndexedDB keys, object stores and indexes into
order-preserving byte keys above this layer. Transaction scheduling, version changes, quota and
eviction are Crane's.

| Operation | Signature | Thread | Notes |
|---|---|---|---|
| `openStore` | `(browser, name: Str, options: StoreOptions) StoreError!*Store` | any | Under the Browser's profile, or in memory. OWNED until `closeStore`. |
| `closeStore` | `(store) void` | any | |
| `deleteStore` | `(browser, name: Str) StoreError!void` | any | Clear-site-data, IDBFactory.deleteDatabase. |
| `beginTransaction` | `(store, mode: .read / .write) StoreError!*StoreTransaction` | the caller's, one thread per transaction | Snapshot isolation for reads; one writer at a time. |
| `commitTransaction` | `(txn) StoreError!void` | same | Durable on return when the store is persistent. |
| `abortTransaction` | `(txn) void` | same | |
| `storeGet` | `(txn, allocator, key: Bytes) StoreError!?[]u8` | same | OWNED value. |
| `storePut`, `storeDelete` | `(txn, key: Bytes, value: Bytes) / (txn, key: Bytes) StoreError!void` | same | |
| `storeDeleteRange` | `(txn, range: KeyRange) StoreError!void` | same | |
| `openCursor` | `(txn, range: KeyRange, direction: .forward / .reverse) StoreError!*StoreCursor` | same | |
| `cursorNext` | `(cursor, allocator) StoreError!?KeyValue` | same | OWNED key and value. |
| `closeCursor` | `(cursor) void` | same | |
| `storeSize` | `(store) StoreError!u64` | any | Usage, for Storage 6. |

`StoreError = error{ OutOfMemory, NotFound, Conflict, Corrupt, QuotaExceeded, Io, Closed }`.

### 6.7 Network (Fetch 4.7 HTTP-network fetch's transport; WebSockets' connection)

The platform moves bytes; every Fetch algorithm (redirects - the transport never follows them -,
cookies, CORS, caching, request bodies from streams) and the WebSocket protocol's state stay Crane's.
kit/curl implements it (libcurl + mbedTLS; decision 5 keeps it on iOS for 0.1, URLSession later as an
`.emulated` alternative).

| Operation | Signature | Thread | Notes |
|---|---|---|---|
| `createEventLoopPort` | `(allocator, browser) Error!*EventLoopPort` | agent | One per event loop (the Browser's, each worker's), OWNED by it; bound to the Browser's network context. |
| `destroyEventLoopPort` | `(port) void` | agent | Cancels what still runs, with no callbacks. |
| `pollEventLoopPort` | `(port) bool` | agent | One non-blocking step; every transfer and WebSocket callback runs inside it, never inside a library call. True if anything ran. |
| `waitEventLoopPort` | `(port, deadline: ?Instant) void` | agent | Block until a socket is ready, the deadline (the next timer) passes or `wakeEventLoopPort` is called: the HTML 8.1.7.3 processing model's wait, with no busy loop (decision 16). |
| `wakeEventLoopPort` | `(port) void` | ANY | Ends a wait (kit/curl: `curl_multi_wakeup`, callable from any thread). `runtime.TaskSink` calls it on every post. |
| `startTransfer` | `(port, allocator, request: *const HttpRequest, client: TransferClient) HttpError!*Transfer` | agent | `client.head(*const HttpResponseHead)`, `client.data(Bytes)` (BORROWED), `client.end(HttpError!void)` last - all inside `pollEventLoopPort`. The request is copied before return. Retries without a connection and the HTTP/2-only refusal (`require_http2`, step 8.3) are the platform's. |
| `cancelTransfer` | `(port, transfer) void` | agent | Nothing more is heard. |
| `pauseTransfer`, `resumeTransfer` | `(port, transfer) void` | agent | Receive backpressure. |
| `openWebSocket` | `(port, allocator, request: *const WebSocketRequest, client: WebSocketClient) HttpError!*WebSocket` | agent | The handshake request Crane built (URL, protocols, origin, cookies); `opened(head)`, `frame(kind, Bytes, fin)`, `closed(code, reason, clean)` inside poll. The per-host CONNECTING queue (RFC 6455 4.1) is the Browser's. |
| `sendWebSocketFrame` | `(socket, kind, bytes: Bytes) HttpError!void` | agent | The platform buffers partial writes. |
| `closeWebSocket`, `releaseWebSocket` | `(socket, code, reason: Str) void`, `(socket) void` | agent | |

`HttpRequest`: URL, method, headers in order, body (bytes or a pull callback), HTTP version
preference, timeouts, `require_http2`. `HttpResponseHead`: status, status message, version, headers in
order (1xx blocks apart), header byte count, remote address, connection reused, and the Resource Timing
marks (DNS, connect, TLS, request start, first byte). `HttpError` keeps the native cause an allowlisted
retry needs (docs/lessons/spec-compliance-a-network-error-may-need-a-native-cause.md). TLS verification
is the platform's: the system trust store where `system_trust_store` is native (darwin: SecTrust over
the chain through mbedTLS's verify callback, Security.framework linked - decision 6), plus
`extra_trust_anchors_pem`.

### 6.8 Crypto primitives (decision 11)

WebCrypto's spec steps stay above the protocol - algorithm normalization, key objects, usages,
extractability, the key formats (SPKI, PKCS#8, JWK, raw: src/webcrypto/key_formats.zig, jwk.zig,
der.zig) and every error a page can observe. The platform supplies the primitives over raw key
material. kit/crypto (Zig std.crypto + mbedTLS, today's src/webcrypto/{hash,hmac,kdf,okp,aes,ec,rsa}.zig)
is the default and the static fallback; a platform links its system crypto where its link plan accepts
it (section 10: darwin uses CommonCrypto and Security.framework's SecKey where they cover an algorithm
and its parameters, and the kit for the rest, choosing per call; linux may link OpenSSL 3).

All are synchronous, any thread (WebCrypto runs them "in parallel": Crane calls them off the agent's
thread or in a task, src/webcrypto/tasks.zig), and return `CryptoError!` with
`CryptoError = error{ OutOfMemory, InvalidKey, OperationFailed, NotSupported }` - Crane maps these to
the spec's OperationError / DataError at its edge, identically on every platform.

| Operation | Signature | Notes |
|---|---|---|
| `digest` | `(allocator, hash, message: Bytes) CryptoError![]u8` | SHA-1, SHA-256/384/512 |
| `hmacSign`, `hmacVerify` | `(allocator, hash, key, message) ![]u8`, `(hash, key, signature, message) bool` | |
| `hkdf`, `pbkdf2` | `(allocator, hash, key, salt, info, bits) ![]u8`, `(allocator, hash, password, salt, iterations, bits) ![]u8` | |
| `aesEncrypt`, `aesDecrypt` | `(allocator, mode: AesMode{ cbc(iv), ctr(counter, length), gcm(iv, aad, tag_bits), kw }, key, input) CryptoError![]u8` | |
| `ecGenerate` | `(allocator, curve) ![]u8` | private scalar; entropy from `fillRandom` |
| `ecPublicKey`, `ecValidatePublic` | `(allocator, curve, private) ![]u8`, `(allocator, curve, point) ![]u8` | |
| `ecdsaSign`, `ecdsaVerify` | `(allocator, curve, hash, private, message) ![]u8`, `(curve, hash, public, signature, message) !bool` | IEEE P1363 signatures |
| `ecdhDerive` | `(allocator, curve, private, peer_public, bits: ?u32) ![]u8` | |
| `okpPublicKey`, `ed25519Sign`, `ed25519Verify`, `x25519Derive` | as above over 32-byte keys | |
| `rsaGenerate` | `(allocator, bits, exponent: Bytes) ![]u8` | PKCS#1 private key DER |
| `rsaPublicKey` | `(allocator, private_der) ![]u8` | |
| `rsaSign`, `rsaVerify` | `(allocator, padding: .pkcs1v15 / pss(salt), hash, private_der, message) ![]u8`, `(padding, hash, public_der, signature, message) !bool` | |
| `rsaEncrypt`, `rsaDecrypt` | `(allocator, hash, label, key_der, input) ![]u8` | RSA-OAEP |

**Identical behaviour is checked, not assumed:** a platform's crypto passes kit/crypto's known-answer
vectors (src/webcrypto/rsa_vectors.zig and its siblings move with the kit) and WebCryptoAPI/ (78
worklist files) on that platform before its constant can say `.native`.

### 6.9 Layout (decision 14) [layout]

Crane does not lay out (the deliberate exclusion stands). A rendering host plugs in here; the
headless answer is today's: no layout box anywhere. Nodes are named by `LayoutNode`, a stable
per-Browser node id Crane assigns (no Instance pointer crosses). The operations are defined now; how a
layout implementation reads the DOM and computed style is designed when the first real rendering host
plugs in (section 13).

| Operation | Signature | Thread | Notes |
|---|---|---|---|
| `layoutBox` | `(browser, document: LayoutNode, node: LayoutNode) ?BoxMetrics` | agent, sync | offset{Top,Left,Width,Height}, offsetParent, client{Top,Left,Width,Height}, scroll{Width,Height}; null: no layout box (CSSOM View: offsetWidth 0, offsetParent null, ...). |
| `clientRects` | `(browser, document, node, allocator) Error![]Rect` | agent | getClientRects / getBoundingClientRect (union); empty with no box. |
| `scrollPosition`, `setScrollPosition` | `(browser, document, node) Point`, `(browser, document, node, point, behavior) void` | agent | scrollTop/Left, scrollTo; the viewport when node is the document. |
| `hitTest` | `(browser, document, point, allocator) Error![]LayoutNode` | agent | elementFromPoint / elementsFromPoint (CSSOM View); empty with no layout. |
| `isRendered` | `(browser, document, node) bool` | agent | "being rendered" (HTML), innerText's rendered-text steps; false with no layout. |
| `renderedText` | `(browser, document, node, allocator) Error!?[]u8` | agent | innerText's rendered text; null: Crane uses the spec's not-rendered steps (textContent). |
| `viewport` | `(browser, tab) Viewport` | agent | width, height, devicePixelRatio, visual viewport - CSSOM View, media queries. Default: today's constants. |
| `invalidateLayout` | `(browser, document, node, reason: .tree / .style / .attribute / .text) void` | agent | Crane reports changes; the implementation lays out lazily. |
| `forceLayout` | `(browser, document) void` | agent | Before a layout-dependent query that must be current. |

### 6.10 Capabilities offered to pages

Every operation below is per Browser, called on the agent's thread (section 4), and gated on its
capability. "Unsupported path" is what Crane does with the capability `.unsupported`; kit/headless
answers the same if called.

**Native, never Crane's own UI.** Crane draws no prompt, dialog or picker. A platform uses the OS's own
permission requests and native system UI - darwin presents system alerts and the system pickers over
the app's key window - so a page in Crane looks like any other app's request. With no window (headless
or background use) the operation drops its Reply and Crane takes the spec's unsupported path.

#### 6.10.1 Permissions [os_permissions] (section 8)

| Operation | Signature | Notes |
|---|---|---|
| `platformPermissionState` | `(browser, requester, descriptor) PlatformPermission{ governed: bool, state: PermissionState }` | sync. Whether the OS governs the descriptor and, if so, its state - darwin: AVCaptureDevice authorization status for camera and microphone, CLLocationManager's for geolocation, UNUserNotificationCenter's for notifications (not determined = prompt, denied or restricted = denied, authorized = granted); a status the OS answers only asynchronously is cached and refreshed through `permission_changed`. Ungoverned: the platform's default state (Permissions 5.1 step 8; headless: prompt). |
| `requestPermission` | `(browser, requester, descriptors: []const PermissionDescriptor, reply: Reply(PermissionDecisions)) void` | Permissions 5.2 step 3. A governed descriptor: the OS access request (AVCaptureDevice requestAccess, CLLocationManager authorization, UNUserNotificationCenter requestAuthorization); the OS presents whatever it presents, remembers the answer and returns granted or denied - Crane asks nothing of its own. An ungoverned descriptor in the prompt state: the platform's policy (headless and linux: denied; testing: decision 9). Unsupported: every descriptor denied. |
| `cancelRequest` | `(browser, id: RequestId) void` | Any pending request (section 4). |

#### 6.10.2 Dialogs, printing and windows

| Operation | Capability | Signature | Unsupported path |
|---|---|---|---|
| `runSimpleDialog` | simple_dialogs | `(browser, requester, request: *const DialogRequest{ kind: alert/confirm/prompt/beforeunload, message, default }, reply: Reply(DialogResult))` - asked only when HTML 8.9.1's WebDriver BiDi user prompt handler is "none"; Crane pauses (section 4) | "cannot show simple dialogs": alert returns, confirm false, prompt null |
| `printDocument` | printing | `(browser, requester, reply: Reply(void))` - HTML 8.9.2 | the printing steps end without output |
| `createTopLevelTraversable` | windows | `(browser, requester, request: *const TraversableRequest{ url, features, noopener }) TraversableDecision{ allow, block }` - HTML 7.2.2.1 window open steps, "the rules for choosing a navigable" (popup blocking) | allow |
| `traversableChanged` | windows | `(browser, tab, change: created(opener) / closed / activated) void` | ignored |
| `windowRect`, `requestWindowRect` | windows | `(browser, tab) Rect`, `(browser, tab, rect) void` - outerWidth, screenX; moveTo/resizeTo (CSSOM View) | the viewport's rect; requests ignored |
| `printConsoleMessage` | (required) | `(browser, source: ConsoleSource{ tab or worker }, level, text: Str) void` - Console Standard 2.3 Printer | kit default: stderr |

#### 6.10.3 File pickers [file_picker]

| Operation | Signature | Notes |
|---|---|---|
| `showFilePicker` | `(browser, requester, options: *const FilePickerOptions{ mode: open/open_multiple/save/directory, accept, capture, suggested_name }, reply: Reply(PickedFiles))` | HTML 4.10.5.1.17 File Upload state and "show the picker, if applicable"; showPicker(); File System Access's pickers. Unsupported: none chosen - `cancel` (input), AbortError (File System Access). |
| `readPickedFile` | `(browser, file: FileToken, offset: u64, length: u32, reply: Reply(Bytes))` | Reading a picked File's bytes (FileReader, Blob.stream) - files stay where the OS keeps them (a document provider on iOS). |
| `releasePickedFile` | `(browser, file: FileToken) void` | |

#### 6.10.4 Screen and system state (required; defaults allowed)

| Operation | Signature | Notes |
|---|---|---|
| `screenInfo` | `(browser) ScreenInfo` | sync, the platform's current snapshot: width, height, availWidth/Height, colorDepth, pixelDepth, devicePixelRatio, orientation type and angle (CSSOM View 2.3 and 4.3; Screen Orientation). Darwin reads UIScreen/NSScreen on the main queue and caches; changes arrive as events (section 7). Default: 1920x1080 (src/webidl/impls/Screen.zig:42-46). |
| `isOnline` | `(browser) bool` | HTML 8.10.1.3. Default true. |
| `userPreferences` | `(browser) UserPreferences` | prefers-color-scheme, -reduced-motion, -contrast, forced-colors (Media Queries 5). Default: light, no-preference. |
| `systemVisibility` | `(browser, tab) Visibility` | HTML's system visibility state. Default visible (docs/instances.md). |
| `screenDetails` [screen_details] | `(browser, requester, reply: Reply(ScreenList))` | Window Management. Unsupported: a single screen from `screenInfo`. |

#### 6.10.5 Media

| Operation | Capability | Signature | Unsupported path |
|---|---|---|---|
| `mediaCanPlayType` | media_decoding | `(browser, mime: Str) MediaSupport{ unsupported, maybe, probably }` - HTML canPlayType | "" |
| `openMediaDecoder` | media_decoding | `(browser, mime: Str) Error!*MediaDecoder` | NotSupported |
| `pushMediaData` | media_decoding | `(decoder, bytes: Bytes, end_of_stream: bool, metadata: *MediaMetadata) MediaResult{ need_more, unsupported, decode_error, metadata, current_data }` - synchronous, as src/platform/media_backend.zig's push is today | - |
| `closeMediaDecoder` | media_decoding | `(decoder) void` | - |
| `mediaDecodingInfo` | media_capabilities | `(browser, config) DecodingInfo` | supported false |
| `openCodec`, `codecInput`, `codecFlush`, `closeCodec` | webcodecs | `(browser, config: *const CodecConfig, output: CodecSink) Error!*Codec`, `(codec, chunk, reply: Reply(void))`, `(codec, reply)`, `(codec)` | isConfigSupported false; configure NotSupportedError |
| `requestKeySystemAccess`, `createKeySession`, `keySessionGenerateRequest`, `keySessionUpdate`, `closeKeySession` | encrypted_media | each with a Reply; messages as events | requestMediaKeySystemAccess NotSupportedError |
| `enumerateMediaDevices` | camera or microphone | `(browser, requester, reply: Reply(MediaDeviceList))` - raw ids and labels; Crane salts and hashes ids per origin and applies "device information exposure" (Media Capture and Streams) | an empty list |
| `openCaptureSource` | camera / microphone | `(browser, requester, request: *const CaptureRequest{ kind, device_id, constraints }, reply: Reply(CaptureOpened))` | NotFoundError |
| `captureSettings`, `captureCapabilities`, `applyCaptureConstraints` | camera / microphone | `(source) TrackSettings`, `(source) TrackCapabilities`, `(source, constraints, reply: Reply(ConstraintResult))` | - |
| `setCaptureSink`, `closeCaptureSource` | camera / microphone | `(source, sink: FrameSink) void` (frames to Crane, any thread), `(source) void` | - |
| `chooseDisplaySurface` | screen_capture | `(browser, requester, options, reply: Reply(CaptureOpened))` - getDisplayMedia | NotAllowedError |
| `openAudioOutput`, `writeAudio`, `audioOutputLatency`, `closeAudioOutput` | audio_output | `(browser, requester, format, device_id: ?Str) Error!*AudioOutput`, `(output, frames: Bytes) usize`, `(output) f64`, `(output) void` | no output device: media plays silently, AudioContext renders to no sink |
| `selectAudioOutput` | audio_output | `(browser, requester, reply: Reply(?MediaDeviceInfo))` - Audio Output Devices | NotAllowedError |
| `speechVoices`, `speak`, `pauseSpeech`, `resumeSpeech`, `cancelSpeech` | speech_synthesis | `(browser, allocator) ![]Voice`, `(browser, utterance, reply: Reply(SpeechEnd))`, ... | no voices; `error` "synthesis-unavailable" |
| `startRecognition`, `stopRecognition` | speech_recognition | results as events | `error` "service-not-allowed" |
| `setMediaSession` | media_session | `(browser, tab, metadata, playback_state, actions) void` | ignored |
| `enterPictureInPicture`, `exitPictureInPicture` | picture_in_picture | Reply-based | NotSupportedError |
| `startPresentation`, `watchRemotePlaybackAvailability` | presentation / remote_playback | Reply-based | NotFoundError / NotSupportedError |

#### 6.10.6 Clipboard [clipboard] (decision 8)

| Operation | Signature | Notes |
|---|---|---|
| `readClipboard` | `(browser, requester, types: []const Str, reply: Reply(ClipboardItems))` | Clipboard API read()/readText() and a paste; darwin reads NSPasteboard / UIPasteboard on the main queue, where iOS shows its own paste prompt. The Async Clipboard API's permission rules (clipboard-read, user activation) are Crane's, above. |
| `writeClipboard` | `(browser, requester, items: *const ClipboardItems, reply: Reply(void))` | write()/writeText() and execCommand copy/cut (which do not wait for the reply). |

Unsupported: read and write reject with NotAllowedError. The testing platform, and a platform with no
system clipboard (a display-less server), use kit/memory_clipboard per Browser.

#### 6.10.7 Notifications, push and background work

| Operation | Capability | Signature | Unsupported path |
|---|---|---|---|
| `showNotification`, `closeNotification`, `maxNotificationActions` | notifications | `(browser, requester, notification, reply: Reply(bool))`, `(browser, id) void`, `(browser) u32` - Notifications 2.6; clicks and closes as events | not shown (permission denied through the model) |
| `pushSubscribe`, `pushUnsubscribe`, `pushSubscription` | push | Reply-based; messages as events | the Push API's no-push-service rejection |
| `registerBackgroundSync`, `startBackgroundFetch` | background_sync / background_fetch | Reply-based | the registration rejects |
| `setAppBadge` | badging | `(browser, requester, value: ?u64) void` | nothing shown |
| `registerProtocolHandler` | protocol_handlers | `(browser, requester, scheme, url) void` - HTML 8.10.1.4 | ignored, as the spec permits |

#### 6.10.8 Location, sensors and device state

| Operation | Capability | Signature | Unsupported path |
|---|---|---|---|
| `currentPosition`, `watchPosition`, `clearWatch` | geolocation | `(browser, requester, options, reply: Reply(PositionResult))`, `(browser, requester, options) Error!WatchId` (positions as events), `(browser, id) void` | POSITION_UNAVAILABLE |
| `startSensor`, `stopSensor` | sensors (per `SensorType`: accelerometer, gyroscope, magnetometer, ambient light, orientation, proximity, geolocation sensor) | `(browser, requester, type, frequency) Error!*SensorHandle` (readings as events), `(sensor) void` | `error` with NotReadableError |
| `startDeviceOrientation`, `stopDeviceOrientation` | device_orientation | readings as events | no events |
| `batteryStatus` | battery | `(browser) BatteryStatus` (changes as events) | the Battery Status default (charging, level 1.0) |
| `vibrate` | vibration | `(browser, pattern: []const u32) bool` | the "no vibration mechanism" path |
| `connectionInfo` | network_information | `(browser) ConnectionInfo` | type "unknown" |
| `startPressureObserver`, `stopPressureObserver` | compute_pressure | readings as events | NotSupportedError |
| `devicePosture` | device_posture | `(browser) Posture` | "continuous" |
| `startIdleDetection`, `stopIdleDetection` | idle_detection | states as events | NotAllowedError |

#### 6.10.9 Devices [usb, hid, serial, bluetooth, nfc, midi, gamepad]

One channel shape for every device kind, with a request union per kind:

| Operation | Signature | Notes |
|---|---|---|
| `chooseDevice` | `(browser, requester, kind, filters: *const DeviceFilters, reply: Reply(?DeviceInfo))` | the chooser: requestDevice / requestPort / Bluetooth requestDevice. Unsupported: none chosen (NotFoundError). |
| `grantedDevices` | `(browser, requester, kind, reply: Reply(DeviceList))` | getDevices() / getPorts(). Unsupported: empty. |
| `openDevice`, `closeDevice` | `(browser, device: DeviceId, reply: Reply(*DeviceHandle))`, `(handle) void` | |
| `deviceRequest` | `(handle, request: *const DeviceRequest, reply: Reply(DeviceResponse))` | `DeviceRequest` = USB control/bulk/interrupt/isochronous transfers and configuration; HID reports and feature reports; serial read/write/signals; Bluetooth GATT discovery, read, write, notifications; NFC read/write; MIDI send. Input (HID reports, GATT notifications, NFC readings, MIDI messages, disconnects) arrives as events. |
| `gamepads` | `(browser, out: []GamepadState) usize` | Gamepad API snapshot; connections as events. Unsupported: none. |

#### 6.10.10 Payments, credentials, sharing, input and UI

| Operation | Capability | Signature | Unsupported path |
|---|---|---|---|
| `canMakePayment`, `showPayment`, `completePayment`, `abortPayment` | payment | Reply-based (Payment Request) | show() NotSupportedError |
| `createCredential`, `getCredential`, `platformAuthenticatorAvailable` | webauthn | Reply-based (WebAuthn, Credential Management) | NotAllowedError; availability false |
| `requestIdentityCredential` | identity_credentials | Reply-based (FedCM, Digital Credentials) | NetworkError / NotAllowedError as each spec says |
| `canShare`, `share` | share | `(browser, data) bool`, `(browser, requester, data, reply: Reply(bool))` (Web Share) | canShare false; share rejects |
| `contactProperties`, `selectContacts` | contacts | Reply-based (Contact Picker) | empty properties; select rejects |
| `requestFullscreen`, `exitFullscreen` | fullscreen | `(browser, requester, tab, reply: Reply(bool))`, `(browser, tab) void` (specs/whatwg/fullscreen.md) | the fullscreen error path (rejects with TypeError) |
| `requestPointerLock`, `exitPointerLock` | pointer_lock | Reply-based | `pointerlockerror` |
| `lockKeys`, `unlockKeys` | keyboard_lock | Reply-based | rejects |
| `keyboardLayoutMap` | keyboard_map | `(browser, reply: Reply(KeyboardMap))` | an empty map |
| `requestWakeLock`, `releaseWakeLock` | wake_lock | Reply-based (Screen Wake Lock) | NotAllowedError |
| `openEyeDropper` | eyedropper | Reply-based | AbortError |
| `queryLocalFonts` | local_fonts | Reply-based (Local Font Access) | an empty list |
| `showVirtualKeyboard`, `hideVirtualKeyboard` | virtual_keyboard | geometry as events | no-op |

## 7. Platform events

What the platform reports unasked - a screen change, a revoked permission, a camera unplugged, a
gamepad press - goes through the `EventSink` Crane gave `createBrowserPlatform`:

```zig
pub const EventSink = extern struct {
    context: *anyopaque,
    /// Any thread. The event is BORROWED for the call; Crane copies it and queues the steps on the
    /// event loops that need it (the Browser's, each subscribed worker's). Never runs script inside.
    post: *const fn (context: *anyopaque, event: *const PlatformEvent) callconv(.c) void,
};
```

| Event | Crane's steps |
|---|---|
| `screen_changed(ScreenInfo)` | ScreenOrientation `change`, resize-dependent steps |
| `online_changed(bool)` | `online` / `offline` at every Window and WorkerGlobalScope (HTML 8.10.1.3) |
| `languages_changed` | `languagechange` (HTML 8.10.1.2) |
| `preferences_changed(UserPreferences)` | media query re-evaluation |
| `visibility_changed(tab, Visibility)` | the document visibility steps |
| `memory_pressure(level)` | `engine.notifyMemoryPressure` on every agent of the Browser |
| `permission_changed(descriptor, origin, top_level_origin, state)` | an OS-governed decision changed (the user changed it in Settings), or a store entry was set; PermissionStatus `change` (Permissions 5.4) |
| `media_devices_changed` | `devicechange` |
| `capture_ended(source)`, `capture_muted(source, bool)` | MediaStreamTrack `ended` / `mute` / `unmute` |
| `notification_event(id, click / close, action)` | Notification `click` / `close` |
| `push_message(subscription, data)` | the service worker's `push` |
| `position(watch, PositionResult)`, `sensor_reading(sensor, reading)`, `orientation(reading)` | the APIs' events |
| `device_event(handle, DeviceEvent)` | HID `inputreport`, GATT `characteristicvaluechanged`, NFC `reading`, MIDI `midimessage`, disconnects |
| `gamepad_connected(index, bool)`, `battery_changed`, `idle_changed`, `pressure_changed`, `connection_changed`, `key_session_message`, `speech_event`, `virtual_keyboard_geometry` | the APIs' events |
| `window_rect_changed(tab, Rect)` | resize steps |

## 8. The permission model

The Permissions spec gives the user agent a permission store (3.2) and the algorithms around it. On a
platform with its own permission system, that system is the store for what it governs: **Crane creates
no prompts of its own.**

**Where the OS governs a descriptor** (darwin: camera, microphone, geolocation, notifications - the
platform says which through `platformPermissionState`):

- The decision is the OS's, per app, shared by every Browser in the process, as in mobile Safari: the
  first access triggers the OS opt-in (with the app's usage descriptions), the OS remembers the answer,
  and the user changes it in Settings.
- "Get the current permission state" (5.1) runs the spec's own checks first - a non-secure context is
  denied, a policy-controlled feature the document may not use is denied - and then answers the OS's
  state. No store entry is written.
- "Request permission to use" (5.2) calls `requestPermission`, which accesses the resource through the
  OS API; whatever the OS presents is the OS's. There is no per-site layer: Safari's per-website prompt
  is Safari's UI, not iOS's. Once the app is allowed, pages in it have access subject to the spec's own
  rules (secure context, permissions policy, user activation where required).
- A denial reaches the page as the spec's failure (getUserMedia rejects with NotAllowedError,
  permissions.query answers "denied"), and the page handles its fallback.
- A change in Settings arrives as `permission_changed`, and PermissionStatus fires `change` (5.4).

**Where no OS governs a descriptor** (every descriptor on linux and the testing platform; the rest on
darwin - persistent-storage, clipboard-read, ...), Crane owns the state, per Browser
(docs/instances.md lists permissions on the Browser):

- the permission store, entries keyed by descriptor and permission key (3.2; the key from the settings
  object's top-level origin and origin, 5.1 step 5), persisted through the storage engine when the
  Browser has a profile;
- 5.1 as written: the spec's checks, the store entry, else the platform's default state;
- 5.2: a state other than prompt is the answer; in the prompt state the platform's policy decides
  without UI (headless and linux deny - the spec's "otherwise denied"; the testing platform follows
  decision 9), and the entry is set from a task (5.2 step 7);
- PermissionStatus and its `change` events (6.3), on the permissions task source (3.4);
- automation: WebDriver Set Permission (B.1.1) and BiDi `permissions.setPermission` (B.2.1.3.1) write
  the store, scoped to a user context = a Browser; the WPT runner's testdriver `set_permission` calls
  the same Browser function. (Automation for an OS-governed descriptor is section 13's open question.)

Feature specs plug in through the same path: Notification.requestPermission (Notifications 2.2),
getUserMedia (camera, microphone), Storage's persistent-storage (Storage 5), clipboard-read /
clipboard-write, geolocation, and the rest.

## 9. The built-in platforms

**darwin** (macOS and iOS), following its link plan (10.1): libSystem's clocks, entropy and threads
(`mach_absolute_time`, `arc4random_buf`, pthreads with QoS); kit/curl with mbedTLS for the transport
(decision 5) and SecTrust for trust (decision 6); the system SQLite for storage on both macOS and iOS
(today's macOS LevelDB comes from Homebrew, not the system, and cannot ship); the system zlib;
CommonCrypto and SecKey where they cover an algorithm, kit/crypto for the rest; the system clipboard;
the OS permission system (section 8); native system alerts and pickers over the key window; screen,
reachability, memory pressure and app lifecycle observed and reported as events. Capabilities not
built yet alias kit/headless.

**linux**, following its link plan (10.2): glibc's clocks, entropy and threads; kit/curl (static: the
distros' libcurl lacks or varies in WebSockets) with the system zlib and nghttp2; the system SQLite;
OpenSSL 3 for TLS and crypto where its link plan accepts it, mbedTLS and kit/crypto otherwise; the
distro CA bundle; the system clipboard through X11 or Wayland when a display is present (loaded at run
time), kit/memory_clipboard otherwise.

**testing** (decision 2, revised): the build machine's real OS services - darwin's or linux's, chosen by
`builtin.os.tag` - plus compiled-in test capabilities, with all their state per Browser:

| Capability | The testing platform |
|---|---|
| media_decoding | WAV linear PCM (today tests/wpt_runner/wav_backend.zig) and WebM/Ogg (lane/webm), moved into the platform |
| camera, microphone | one fake camera "fake_video_0" (640x480, 30 fps) and one fake microphone "fake_audio_0" (48 kHz mono); precedent Chrome's FakeVideoCaptureDeviceFactory, Gecko's MediaEngineFake, WebKit's MockRealtimeMediaSourceCenter |
| os_permissions | governs no descriptor: Crane's store answers, and a request in the prompt state grants camera and microphone (the fake devices) and denies everything else (decision 9); tests script anything else with `test_driver.set_permission`, which writes the store |
| simple_dialogs | dismissed at once (alert OK, confirm false, prompt null), logged to the test's output |
| file_picker | answers from a per-Browser queue testdriver fills (`test_driver.file_upload`); canceled when empty |
| clipboard | kit/memory_clipboard per Browser |
| notifications, geolocation | recorded; positions scripted per Browser |
| console | the per-Browser sink in its options (the runner's per-test log) |
| layout | headless |

Its per-Browser options (`platform.PlatformBrowserOptions` in a testing build) carry the fake devices,
the prompt policy and the console sink; its control surface for testdriver (queue a picked file,
script a position) is `platform.adapter.control`, present only in a testing build. Fresh state per
Browser is the point: WebKitTestRunner's process-global mocks need `resetStateToConsistentValues`.

## 10. Link plans

**The principle (the user, 2026-10-09): ship the smallest library.** For each capability - and, where it
matters, each algorithm or feature - a platform dynamically links the system library when the platform
ships one that does what Crane needs (complete and conformant for that use) and can be trusted.
Otherwise it statically compiles Crane's kit implementation. It may carry both and choose at build time
(`-Dplatform-static=<item>`), and where a system implementation covers only some parameters (an RSA-PSS
salt length, an AES-CTR counter that wraps) it chooses per call, so every platform gives the same
web-visible answer. A capability compiled out with `-Dplatform-without` links nothing. On darwin,
frameworks newer than the deployment target are weak-linked; on linux, libraries a headless server may
lack (display, audio, media) are loaded at run time (`std.DynLib`, inside the platform), never required
at load.

How this was checked: darwin against the macOS 27.0 and iOS 27.0 SDKs in Xcode (public headers and
`.tbd` stubs, 2026-10-09) and `/usr/bin/curl -V` on macOS 27.0; linux against packages.debian.org and
packages.ubuntu.com (2026-10-09). An SDK shows what the newest OS ships; whether an item is present on
the oldest OS Crane will support depends on deployment targets not yet chosen (section 13). Anything
not verified is marked UNVERIFIED.

### 10.1 darwin

"Both" = macOS and iOS. "Dynamic" = the default; the kit is the static fallback unless "none".

| Item | System library | Available | Acceptable? | Static fallback | Default |
|---|---|---|---|---|---|
| clocks, entropy, threads, files, memory pressure, QoS | libSystem (`mach_absolute_time`, `arc4random_buf`, pthreads, `pthread_set_qos_class_self_np`, libdispatch memory-pressure sources) | both | yes - the OS itself; Apple requires libSystem dynamically | none | dynamic |
| TLS trust | Security.framework SecTrust (`SecTrustCreateWithCertificates`, `SecTrustEvaluateWithError` - in both SDKs) | both | yes - the system roots and MDM-installed roots (decision 6) | kit/curl's anchor-file verification | dynamic |
| TLS protocol | libboringssl.tbd (both SDKs, no public headers); Network.framework (both) | both | no for 0.1 - boringssl is private; Network.framework/URLSession do not expose what Fetch needs (raw header order, 1xx, HTTP/2-only refusal, transport timing) - decision 5 | mbedTLS (kit/curl) | static |
| HTTP client | /usr/lib/libcurl.4.dylib, 8.7.1 (macOS SDK's curlver.h) | macOS only (no libcurl in the iOS SDK) | no - macOS's build has no WebSockets (`curl -V` lists no ws/wss), uses the deprecated SecureTransport/LibreSSL 3.3.6, and is pinned old | kit/curl | static |
| HTTP/2 framing | nghttp2 (inside macOS's libcurl only; no libnghttp2 in either SDK) | - | no public library | static nghttp2 (build.zig `enable_http2`) | static |
| zlib (Content-Encoding gzip/deflate, Compression Streams) | libz.tbd, zlib 1.2.12 (zlib.h in both SDKs) | both | yes - stable API; Apple's security backports to 1.2.12 UNVERIFIED | static zlib (today's) | dynamic |
| Brotli (Content-Encoding br; not built today) | Compression framework `COMPRESSION_BROTLI` (compression.h: macOS 12, iOS 15; Apple's encoder is level 2 only) | both | yes for decoding, when br is added | static brotli | dynamic |
| storage engine | libsqlite3.tbd, SQLite 3.54.0 (sqlite3.h in both SDKs) | both | yes - the ordered key-value contract (6.6) needs nothing version-specific | kit/sqlite (amalgamation); kit/leveldb (no system LevelDB on darwin - today's macOS link is Homebrew's) | dynamic |
| SHA-1/256/384/512 | CommonCrypto `CC_SHA*` (CommonDigest.h) | both | yes | kit/crypto | dynamic |
| HMAC | CommonCrypto `CCHmac` (SHA-1, -224, -256, -384, -512) | both | yes | kit/crypto | dynamic |
| PBKDF2 | CommonCrypto `CCKeyDerivationPBKDF` (SHA-1 to SHA-512 PRFs) | both | yes | kit/crypto | dynamic |
| HKDF | - (CommonKeyDerivation.h offers PBKDF2 only) | no | no public API | kit/crypto | static |
| AES-CBC | CommonCrypto `CCCrypt`, kCCModeCBC with PKCS#7 | both | yes | kit/crypto | dynamic |
| AES-CTR | CommonCrypto kCCModeCTR (`kCCModeOptionCTR_BE`, the whole 128-bit block counts) | both | partly - identical only while WebCrypto's `length`-bit counter does not wrap within the message; chosen per call | kit/crypto | per call |
| AES-GCM | - (CommonCryptor.h's modes: ECB, CBC, CFB, CTR, OFB, RC4, CFB8; no GCM) | no | no public API | kit/crypto | static |
| AES-KW | CommonCrypto `CCSymmetricKeyWrap` / `Unwrap`, kCCWRAPAES (RFC 3394, CommonSymmetricKeywrap.h) | both | yes - WebCrypto's AES-KW is RFC 3394 | kit/crypto | dynamic |
| RSASSA-PKCS1-v1_5 | SecKey `kSecKeyAlgorithmRSASignatureMessagePKCS1v15SHA1` ... `SHA512` | both | yes | kit/crypto | dynamic |
| RSA-PSS | SecKey `kSecKeyAlgorithmRSASignatureMessagePSSSHA1` ... `SHA512`; the salt length is fixed to the hash's output size (SecKey.h) | both | partly - only when `saltLength` equals the hash length; chosen per call | kit/crypto | per call |
| RSA-OAEP | SecKey `kSecKeyAlgorithmRSAEncryptionOAEPSHA1` ... `SHA512`; no label parameter (SecKey.h) | both | partly - only with an empty `label`; chosen per call | kit/crypto | per call |
| RSA key generation | SecKey `SecKeyCreateRandomKey`; no public-exponent attribute (SecKey.h, SecItem.h) | both | partly - only for the exponent SecKey uses (65537, UNVERIFIED); chosen per call | kit/crypto | per call |
| ECDSA P-256/384/521 | SecKey `kSecKeyAlgorithmECDSASignatureMessageX962SHA1` ... `SHA512` (DER signatures; Crane converts to IEEE P1363) | both | yes (P-521 in SecKey UNVERIFIED) | kit/crypto | dynamic |
| ECDH P-256/384/521 | SecKey `kSecKeyAlgorithmECDHKeyExchangeStandard` | both | yes (P-521 UNVERIFIED) | kit/crypto | dynamic |
| EC key generation | SecKey `SecKeyCreateRandomKey`, `kSecAttrKeyTypeECSECPrimeRandom` | both | yes | kit/crypto | dynamic |
| Ed25519, X25519 | - (no 25519 in SecKey.h; CryptoKit has them but is Swift-only, with no C or Objective-C API) | no | no callable API | kit/crypto | static |
| Intl, collation, IDNA | libicucore.tbd, ICU 78.1 - but only 23 public headers in both SDKs (uchar, uidna, uregex, ustring, utext, ...; no collation, date or number formatting) | both | no - incomplete for Intl, V8 needs its own pinned ICU, and Unicode-version-dependent answers (IDNA, case mapping) would differ by OS version, breaking identical behaviour | V8's ICU, src/intl's CLDR data, src/url's IDNA | static |
| media decoding | AVFoundation, AudioToolbox, VideoToolbox | both | yes for the formats Apple decodes (H.264, HEVC, AAC, MP3, ...); WebM/VP9/Opus support UNVERIFIED | none - Crane builds in no decoder ("host decoders only", the user, 2026-10-08) | dynamic |
| camera, microphone; audio output | AVFoundation; AVFAudio, AudioToolbox | both | yes | none | dynamic |
| clipboard | AppKit NSPasteboard; UIKit UIPasteboard | macOS; iOS | yes | kit/memory_clipboard | dynamic |
| dialogs, pickers | AppKit NSAlert, NSOpenPanel, NSSavePanel; UIKit UIAlertController, UIDocumentPickerViewController, PhotosUI PHPickerViewController | macOS; iOS | yes | none (the spec's unsupported path) | dynamic |
| notifications; geolocation; sensors | UserNotifications; CoreLocation; CoreMotion | both (CoreMotion's sensors on macOS UNVERIFIED) | yes | none | dynamic |
| gamepad; Bluetooth; MIDI | GameController; CoreBluetooth; CoreMIDI | both | yes | none | dynamic |
| NFC | CoreNFC | iOS only (not in the macOS SDK) | yes | none | dynamic (iOS) |
| USB, HID, serial | IOKit | macOS only (not in the iOS SDK) | yes | none - unsupported on iOS | dynamic (macOS) |
| speech | AVFAudio (synthesis), Speech (recognition) | both | yes | none | dynamic |
| WebAuthn; payment; contacts | AuthenticationServices; PassKit; Contacts (ContactsUI on iOS) | both | yes | none | dynamic |
| online state | Network.framework path monitor; SystemConfiguration (macOS, linked today) | both | yes | constant "online" | dynamic |
| C++ runtime | libc++.dylib | both | the engine adapter's question, not the platform's: V8's prebuilt monolith may use its own libc++ (UNVERIFIED) | - | - |

darwin crypto for 0.1 follows this table (decision OQ5): CommonCrypto and SecKey for the algorithms and
parameters they cover, kit/crypto (std.crypto + mbedTLS) for HKDF, AES-GCM, Ed25519, X25519 and the
parameter cases SecKey and CommonCrypto do not take. Both paths pass the same known-answer vectors and
WebCryptoAPI/ before darwin's crypto is declared native (6.8). AES-KW is covered by CommonCrypto (an
earlier assumption that Apple lacks it was wrong); AES-GCM and HKDF are the gaps.

### 10.2 linux

Versions are Debian bookworm / trixie and Ubuntu 22.04 / 24.04 (and newer where it matters); Fedora,
RHEL and Arch are UNVERIFIED.

| Item | System library | Available | Acceptable? | Static fallback | Default |
|---|---|---|---|---|---|
| clocks, entropy, threads, files | glibc (`clock_gettime`, `getrandom`, pthreads) | every glibc distro | yes | none (a musl build is fully static: `-Dplatform-static=all`) | dynamic |
| TLS protocol and trust | OpenSSL 3: libssl3 3.0.22 (bookworm), libssl3t64 3.5.7 (trixie); 3.0.2 (22.04), 3.0.13 (24.04) | Debian, Ubuntu | yes - complete and trusted; kit/curl's ALPN read and verify hook are mbedTLS-specific today (src/fetch/network/curl_backend.zig:1131-1143), so this waits for kit/curl's OpenSSL backend | mbedTLS (kit/curl) | static until kit/curl supports OpenSSL, then dynamic |
| CA certificates | the distro bundle file (/etc/ssl/certs/ca-certificates.crt on Debian and Ubuntu; Fedora and RHEL paths UNVERIFIED) | - | data, not a library | `extra_trust_anchors_pem` | - |
| HTTP client | libcurl4 7.88.1 (bookworm), libcurl4t64 8.14.1 (trixie); 7.81.0 (22.04), 8.5.0 (24.04), 8.18.0 (26.04) | all | no by default - WebSockets became official only in curl 8.11.0 (curl's 8.11.0 changelog), so bookworm, 22.04 and 24.04 lack it; whether trixie's and 26.04's builds enable WebSockets is UNVERIFIED. A build-time choice on distros that have it | kit/curl | static |
| HTTP/2 framing | libnghttp2-14 1.52.0 (bookworm), 1.64.0 (trixie) | Debian (Ubuntu UNVERIFIED) | yes | static nghttp2 | dynamic |
| zlib | zlib1g 1.2.13 (bookworm), 1.3.1 (trixie) | all | yes | static zlib | dynamic |
| storage engine | libsqlite3-0 3.40.1 (bookworm), 3.46.1 (trixie) | all | yes | kit/sqlite; kit/leveldb (libleveldb1d 1.23 exists in Debian but is not installed by default) | dynamic SQLite (replacing today's desktop LevelDB default) |
| WebCrypto primitives | OpenSSL 3 libcrypto (above) | Debian, Ubuntu | yes - covers every algorithm, OAEP labels, any PSS salt, any RSA exponent, HKDF, AES-KW; AES-CTR's counter-wrap rule is chosen per call as on darwin | kit/crypto | dynamic once the vectors pass |
| Intl | libicu (a versioned soname per release) | all | no - the soname changes per release, V8 needs its pinned ICU, and Unicode-dependent answers would vary by distro | V8's ICU, src/intl | static |
| clipboard | libxcb / libX11 (X11), libwayland-client (Wayland), loaded at run time | desktops only | yes when a display is present | kit/memory_clipboard | run-time load |
| media decoding, audio output | GStreamer or FFmpeg (libavcodec); PipeWire / PulseAudio / ALSA - loaded at run time | desktops (UNVERIFIED per distro) | to be decided when the capability is built | none | - |
| notifications, geolocation, wake lock, file pickers | D-Bus services (org.freedesktop.Notifications, GeoClue2, xdg-desktop-portal), loaded at run time | desktops (UNVERIFIED per distro) | to be decided when built | none | - |

## 11. The boundary

**Crane's platform is an adapter, and the protocol is the only way to reach it.** Outside
src/platform/: no OS API (`std.c`, `std.posix`, `std.os`, `std.process`, `std.Io.Dir/File/net/Clock`,
`std.Thread.spawn`, `std.net`, `std.http.Client/Server`, `extern fn`, `getenv`, `builtin.os.tag`), no
libcurl, mbedTLS, SQLite or LevelDB identifier, no OS framework call. Build-time tools, tests/, test
declarations and src/webdriver/ (while it is a separate executable, decision 18) are exempt.
Synchronisation primitives, allocators, `std.fs.path` and `std.time` constants are not OS access.

Held by `zig build lint-platform` (tools/lint_platform_boundary.zig, part of `zig build test`): per file
and per key against tools/platform_boundary_baseline.txt, a count that rises fails, a pair the baseline
lacks fails, and the baseline only goes down - built like lint-engine. The starting baseline is about
1,510 references in about 123 files (curl 687, SQLite/LevelDB 363, the clock bridge 228, mbedTLS 140,
files 50, randomness 20, threads 13, target branches 11, environment 1; tmp/plans/platform-inventory.md
has every one by file and line).

## 12. Adding an operation

A platform need that no operation meets becomes a new operation, requested from the integrator, who
owns protocol.zig. It lands in one change:

1. **The declaration**, in its area, named after the spec concept it is (or, where there is no spec,
   the OS concern). Its doc comment says who owns what it takes and returns, its thread, sync or
   async, and its unsupported path. C-representable types only (1.4). Gated on a capability unless
   every platform must provide it.
2. **kit/headless's unsupported answer**, so every platform has something to alias.
3. **Each built-in platform**: an implementation, or the alias with the capability `.unsupported`.
4. **Tests**: tests/platform for each built-in platform's implementation (bound with
   `platformProtocolBinding`), and a test of Crane's unsupported path with the capability forced off.
5. **This file**: the operation table, the capability table, the event table if it reports events,
   and each platform's link-plan row if the operation can be served by a system library.

## 13. Settled, and what is still open

**Settled** (the user, 2026-10-09; tmp/plans/platform-decisions.md, the OQ lines):

1. **Each artifact against its own platform.** build.zig builds one module graph per platform: the WPT
   runner and the test tiers against `testing`, the library, the CLI and the iOS build against the
   target's platform (section 1.1).
2. **The platform's native permission system, and no prompts of Crane's own.** darwin's permission
   capability is the OS permission system, per app: the adapter accesses the resource through the OS
   API and the OS presents whatever it presents. No per-site layer (section 8).
3. **Native system UI.** Dialogs and pickers are the platform's own, over the key window; with no window
   the spec's unsupported path applies. No app delegate or presenter is required (6.10).
4. **Per-Browser differences are options and state only**; implementations do not mix in one process,
   and OS-owned state (darwin's permissions) is shared by every Browser in the process (3.2).
5. **Layout input.** The layout operations are defined now (6.9); how a renderer reads the DOM and
   computed style is designed when the first real rendering host plugs in.
6. **Ship the smallest library** - the link-plan principle and the per-platform plans (section 10);
   darwin crypto for 0.1 is CommonCrypto and SecKey where they cover, the static kit for the rest.
7. **The storage engine contract** is the ordered, transactional key-value store with byte-ordered keys
   (6.6); IndexedDB's SQL-based persistence is rewritten over it (recipes step 4).

**Still open**

1. **Automation for an OS-governed permission.** WebDriver Set Permission (Permissions B.1.1), BiDi
   `permissions.setPermission` and testdriver's `set_permission` write the user agent's store, but on
   darwin the OS owns camera, microphone, geolocation and notifications, and Crane cannot write the
   OS's per-app decision. Options: (a) answer those descriptors with WebDriver's "unsupported
   operation" error on darwin - tests that script them run on the testing platform, where no OS
   governs anything; (b) an automation-only override in Crane's store that wins over the OS while a
   WebDriver session drives the Browser. Recommendation: (a) - (b) would make the OS's answer depend on
   who is driving.
2. **Deployment targets.** The link plans list what the current SDKs and distros ship; which system
   libraries a platform may rely on depends on the oldest macOS, iOS and distro releases Crane supports
   (Compression's Brotli needs macOS 12 / iOS 15; a WebSocket-capable distro libcurl needs curl 8.11),
   and those are not chosen. Recommendation: choose them before step 14 freezes a platform's defaults,
   and record each item's minimum version in its link-plan row.
3. **The engine's own libraries.** V8's ICU and its C++ runtime are linked by the engine adapter, not
   the platform; whether V8's prebuilt monolith could use the system libc++ on darwin
   (`use_custom_libcxx`) is UNVERIFIED and belongs to the engine protocol's work, noted here so the
   smallest-library principle reaches it.
