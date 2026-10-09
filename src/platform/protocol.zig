//! Crane's platform protocol: module `platform`.
//!
//! Everything platform-specific - the OS services Crane needs on every target
//! and the capabilities a browser offers pages - is reached through this one
//! module, bound at build time to one platform implementation, as the
//! JavaScript engine is (docs/engine-protocol.md). The signatures and doc
//! comments here ARE the contract; docs/platform-protocol.md summarises it and
//! never overrides it. Consumers write:
//!
//!     const platform = @import("platform");
//!     const start = platform.monotonicNow();
//!
//! Dispatch is static. build.zig binds `platform_impl` to the platform
//! `-Dplatform=` (or `-Dplatform-module=`) selects, whose root declares
//! `pub const protocol`; each operation below is an inline function whose body
//! calls that namespace's function of the same name, so a call site compiles
//! to a direct call: no table, no optional unwrap, no run-time host object.
//!
//! The contract is checked at compile time whenever this module is used (the
//! `comptime` block at the end). Every public inline function here is an
//! operation, and the implementation must declare a function of the same name
//! with exactly the same parameter and return types - every operation,
//! including those gated on a capability it lacks (kit/headless answers those;
//! the gate keeps them from being called). It must also declare `name`,
//! `capabilities`, `identity` and `PlatformBrowserOptions` (contract 1.3). A
//! missing or mis-typed declaration is a compile error in this file that names
//! it, whether or not anything calls it
//! (docs/lessons/architecture-a-forwarding-facade-checks-only-what-gets-called.md).
//!
//! Capabilities are tri-state and comptime-known: `.native`, `.emulated` (with
//! its deviations listed at the platform's constant) or `.unsupported` (Crane
//! takes the spec's unsupported path). `-Dplatform-without=<capability>,...`
//! forces a capability `.unsupported` whatever the platform declares. A gated
//! operation compiles only inside a check, and the `else` is the spec's
//! unsupported path:
//!
//!     if (platform.capabilities.geolocation != .unsupported) {
//!         platform.currentPosition(browser, &requester, &options, reply);
//!     } else {
//!         // Geolocation: POSITION_UNAVAILABLE to the error callback.
//!     }
//!
//! so an unsupported capability compiles out on both sides.
//!
//! `platform` is a LEAF: it imports only std, `platform_impl` and
//! `platform_options` (this graph's -Dplatform-* choices) - and, until the
//! TRANSITIONAL section near the end goes, the `clock` bridge. Its types are its
//! own; fetch, storage, webcrypto, html and the impls convert at their edge.
//! Everything that crosses is C-representable (contract 1.4): records are
//! `extern struct`s, enums have explicit integer tags, strings are `Str` and
//! byte runs `Bytes`, callbacks are `callconv(.c)` with a context pointer.
//! Error unions, optionals and slices appear only at the Zig surface.
//!
//! Status: platform protocol step 0 (docs/platform-protocol-recipes.md). Every
//! operation of the contract is declared and checked; the built-in platforms
//! implement today's behaviour or alias kit/headless. Nothing outside
//! src/platform/ calls it yet - step 1 moves the first callers.

const std = @import("std");
const impl = @import("platform_impl").protocol;
const platform_options = @import("platform_options");

/// The bound implementation itself, for surfaces only one platform has (the
/// testing platform's control surface, contract section 9). Code that uses it
/// compiles on that platform only, so only tests/ may use it; lint-platform
/// counts `platform.adapter` anywhere else.
pub const adapter = impl;

// ============================================================================
// 2. Types and ownership
// ============================================================================

/// A borrowed or owned UTF-8 string: pointer and length. BORROWED for the call
/// unless an operation says it returns one OWNED (then allocated with the
/// allocator passed in).
pub const Str = extern struct {
    ptr: [*]const u8 = "".ptr,
    len: usize = 0,

    pub const empty: Str = .{};

    pub fn from(text: []const u8) Str {
        return .{ .ptr = text.ptr, .len = text.len };
    }

    pub fn slice(self: Str) []const u8 {
        return self.ptr[0..self.len];
    }
};

/// A borrowed or owned run of bytes: pointer and length (the rules of `Str`).
pub const Bytes = extern struct {
    ptr: [*]const u8 = "".ptr,
    len: usize = 0,

    pub const empty: Bytes = .{};

    pub fn from(bytes: []const u8) Bytes {
        return .{ .ptr = bytes.ptr, .len = bytes.len };
    }

    pub fn slice(self: Bytes) []const u8 {
        return self.ptr[0..self.len];
    }
};

/// A list of strings, BORROWED like `Str`.
pub const StrList = extern struct {
    ptr: [*]const Str = &[_]Str{},
    len: usize = 0,

    pub fn from(items: []const Str) StrList {
        return .{ .ptr = items.ptr, .len = items.len };
    }

    pub fn slice(self: StrList) []const Str {
        return self.ptr[0..self.len];
    }
};

/// A time on the monotonic clock, arbitrary origin: HR-Time 2.1's monotonic
/// clock. Never decreases.
pub const Instant = extern struct {
    ns: u64,
};

/// A time on the wall clock, nanoseconds since the Unix epoch: HR-Time 2.1's
/// wall clock. It jumps.
pub const WallTime = extern struct {
    ns_since_epoch: i64,
};

/// What an OS operation fails with. `NotSupported` only from an operation
/// whose capability is `.unsupported`. Network failures are `HttpError`
/// (6.7), storage failures `StoreError` (6.6), crypto failures `CryptoError`
/// (6.8).
pub const Error = error{
    OutOfMemory,
    NotSupported,
    AccessDenied,
    NotFound,
    AlreadyExists,
    NoSpace,
    Io,
    Canceled,
    Busy,
};

/// A value with no content: the payload of a `Reply` that only says "done".
pub const Unit = extern struct {
    reserved: u8 = 0,
};

/// Opaque per-Browser platform state (section 3). OWNED by the Browser:
/// `createBrowserPlatform` / `destroyBrowserPlatform`. Every per-Browser
/// operation takes it first.
pub const BrowserPlatform = opaque {};

/// Names a pending request for `cancelRequest`; unique per Browser.
pub const RequestId = u64;
/// A top-level traversable (a tab) of a Browser.
pub const TabId = u64;
/// A navigable (a frame) of a Browser.
pub const FrameId = u64;

/// Who asks, BORROWED for the call: the inputs of the permission key
/// (Permissions 3.2) and the checks a capability's spec makes. No realm or
/// engine value crosses.
pub const Requester = extern struct {
    request_id: RequestId,
    tab: TabId,
    frame: FrameId,
    /// Serialized origin of the relevant settings object.
    origin: Str,
    /// Serialized origin of its top-level traversable's active document.
    top_level_origin: Str,
    secure_context: bool,
    transient_activation: bool,
};

/// One asynchronous answer (section 4). OWNED by the platform from the call
/// until it calls exactly one of `deliver` / `drop`, once, from any thread,
/// at any time after the call - before the operation returns included. Crane
/// never runs the request's steps inside either: both post a task to the
/// requesting agent's event loop.
pub fn Reply(comptime T: type) type {
    return extern struct {
        context: *anyopaque,
        /// The value is BORROWED for the call; Crane copies what it keeps.
        deliver: *const fn (context: *anyopaque, value: *const T) callconv(.c) void,
        /// No answer: canceled, or the platform cannot answer. Crane takes the
        /// spec's failure path.
        drop: *const fn (context: *anyopaque) callconv(.c) void,
    };
}

/// One event loop's OS side - its sockets, its wait, its wake (6.7). OWNED by
/// the event loop; used on its thread only, except `wakeEventLoopPort`.
pub const EventLoopPort = opaque {};
/// An HTTP transfer, OWNED by its port until its client's last callback or
/// `cancelTransfer`.
pub const Transfer = opaque {};
/// A WebSocket connection, OWNED by its port until `releaseWebSocket`.
pub const WebSocket = opaque {};
/// Storage engine handles (6.6), OWNED until closed / committed or aborted.
pub const Store = opaque {};
pub const StoreTransaction = opaque {};
pub const StoreCursor = opaque {};
/// Capability objects, OWNED by Crane from a successful open until its close.
pub const MediaDecoder = opaque {};
pub const Codec = opaque {};
pub const CaptureSource = opaque {};
pub const AudioOutput = opaque {};
pub const DeviceHandle = opaque {};
pub const SensorHandle = opaque {};

/// A file the user picked (6.10.3), OWNED until `releasePickedFile`.
pub const FileToken = extern struct {
    id: u64,
};

/// A thread, OWNED by the spawner until `joinThread`.
pub const Thread = extern struct {
    handle: usize,
};

// ============================================================================
// 3. Per-Browser state
// ============================================================================

/// An explicit proxy (docs/instances.md: explicit proxies only for 0.1).
pub const ProxyConfig = extern struct {
    /// e.g. "http://proxy.example:8080"; empty: no proxy for that scheme.
    http: Str = .{},
    https: Str = .{},
    /// Comma-separated hosts that bypass the proxy.
    no_proxy: Str = .{},
};

/// The platform's own per-Browser options (3.2), declared by each platform.
pub const PlatformBrowserOptions = impl.PlatformBrowserOptions;

/// What a Browser asks of its platform state (3.1).
pub const BrowserOptions = struct {
    /// Where the Browser's stores live. Null: in memory, nothing written to
    /// disk (decision 12).
    profile_dir: ?Str = null,
    /// Empty: the platform's default (from `identity`).
    user_agent: Str = .{},
    /// Null: the platform's (OS) preference list.
    preferred_languages: ?[]const Str = null,
    proxy: ?ProxyConfig = null,
    /// Added to the platform's trust store (the WPT runner's cacert.pem).
    extra_trust_anchors_pem: Bytes = .{},
    platform: PlatformBrowserOptions = .{},
};

/// Make a Browser's platform state. `events` is BORROWED by the platform
/// until `destroyBrowserPlatform` returns. The result is OWNED by the Browser.
pub inline fn createBrowserPlatform(allocator: std.mem.Allocator, options: *const BrowserOptions, events: EventSink) Error!*BrowserPlatform {
    return impl.createBrowserPlatform(allocator, options, events);
}

/// End a Browser's platform state. Pending Replies are still completed
/// (section 4): a platform completes or drops every Reply it was given.
pub inline fn destroyBrowserPlatform(browser: *BrowserPlatform) void {
    return impl.destroyBrowserPlatform(browser);
}

// ============================================================================
// 5. Capabilities
// ============================================================================

/// How a platform has a capability.
pub const Support = enum(u8) {
    /// The platform does it.
    native,
    /// Built on what the platform has, with deviations listed at its constant.
    emulated,
    /// Crane takes the spec's unsupported path.
    unsupported,
};

/// Every capability a platform may lack (contract section 5). Each field's
/// comment is the unsupported path.
pub const Capabilities = struct {
    /// Stores in memory; StorageManager.persisted() false (Storage 5).
    persistent_storage: Support,
    /// Fetch 4.3 scheme fetch "file": a network error.
    file_urls: Support,
    /// Only `extra_trust_anchors_pem` is trusted.
    system_trust_store: Support,
    /// HTTP-network fetch step 8.3: an HTTP/2-only request is a network error.
    http2: Support,
    /// HTTP/1.1 and HTTP/2 only.
    http3: Support,
    /// Threads run at the default priority.
    thread_qos: Support,
    /// Diagnostics report no resident memory.
    resident_memory: Support,
    /// CSSOM View with no layout box: zero boxes, no hit (6.9).
    layout: Support,
    /// A permission request in the prompt state is denied.
    os_permissions: Support,
    /// HTML 8.9.1 "cannot show simple dialogs".
    simple_dialogs: Support,
    /// The printing steps end without output.
    printing: Support,
    /// No files chosen (`cancel`; AbortError for File System Access).
    file_picker: Support,
    /// Every popup allowed; window rects ignored.
    windows: Support,
    /// canPlayType answers "".
    media_decoding: Support,
    /// NotSupportedError.
    webcodecs: Support,
    media_capabilities: Support,
    encrypted_media: Support,
    /// enumerateDevices() empty; getUserMedia NotFoundError.
    camera: Support,
    microphone: Support,
    /// getDisplayMedia NotAllowedError.
    screen_capture: Support,
    /// No output device: media plays silently.
    audio_output: Support,
    /// No voices; recognition "service-not-allowed".
    speech_synthesis: Support,
    speech_recognition: Support,
    /// Clipboard API read and write reject with NotAllowedError.
    clipboard: Support,
    /// Never shown; permission "denied".
    notifications: Support,
    /// The API's no-service rejection.
    push: Support,
    background_sync: Support,
    background_fetch: Support,
    /// POSITION_UNAVAILABLE.
    geolocation: Support,
    /// NotReadableError (every sensor type).
    sensors: Support,
    /// No events.
    device_orientation: Support,
    /// No device chosen (NotFoundError).
    usb: Support,
    hid: Support,
    serial: Support,
    bluetooth: Support,
    nfc: Support,
    midi: Support,
    /// No gamepads.
    gamepad: Support,
    /// The API's rejection (NotSupportedError / NotAllowedError / AbortError).
    payment: Support,
    webauthn: Support,
    identity_credentials: Support,
    share: Support,
    contacts: Support,
    /// The request fails as its spec says.
    fullscreen: Support,
    pointer_lock: Support,
    keyboard_lock: Support,
    wake_lock: Support,
    /// Each spec's default or rejection (6.10).
    idle_detection: Support,
    battery: Support,
    vibration: Support,
    badging: Support,
    eyedropper: Support,
    local_fonts: Support,
    keyboard_map: Support,
    screen_details: Support,
    presentation: Support,
    remote_playback: Support,
    picture_in_picture: Support,
    media_session: Support,
    network_information: Support,
    compute_pressure: Support,
    device_posture: Support,
    virtual_keyboard: Support,
    protocol_handlers: Support,
};

pub const Capability = std.meta.FieldEnum(Capabilities);

/// The platform's declaration with every capability `-Dplatform-without`
/// names forced to `.unsupported`. A name that is no capability is a compile
/// error, so a typo cannot silently keep a capability in.
pub fn withoutCapabilities(declared: Capabilities, comptime without: []const []const u8) Capabilities {
    var result = declared;
    inline for (without) |capability| {
        if (!@hasField(Capabilities, capability)) @compileError("-Dplatform-without names `" ++ capability ++
            "`, which is not a platform capability (src/platform/protocol.zig Capabilities)");
        @field(result, capability) = .unsupported;
    }
    return result;
}

/// The capabilities of the platform this build selected.
pub const capabilities: Capabilities = withoutCapabilities(impl.capabilities, platform_options.platform_without);

/// The platform this build selected, for messages ("darwin", "testing").
pub const name: []const u8 = impl.name;

/// A gated operation reached where the platform lacks its capability: a
/// compile error that says so, and how to write the call.
fn gate(comptime capability: Capability, comptime operation: []const u8) void {
    if (@field(capabilities, @tagName(capability)) == .unsupported) @compileError("platform." ++ operation ++
        " needs platform.capabilities." ++ @tagName(capability) ++ ", which the " ++ name ++
        " platform does not have in this build: call it inside `if (platform.capabilities." ++
        @tagName(capability) ++ " != .unsupported)`, which compiles the call out where it is unsupported");
}

/// As `gate`, for an operation any one of several capabilities serves
/// (enumerateMediaDevices: camera or microphone).
fn gateAny(comptime any: []const Capability, comptime operation: []const u8) void {
    for (any) |capability| {
        if (@field(capabilities, @tagName(capability)) != .unsupported) return;
    }
    var names: []const u8 = "";
    for (any, 0..) |capability, i| names = names ++ (if (i == 0) "" else " or ") ++ @tagName(capability);
    @compileError("platform." ++ operation ++ " needs platform.capabilities." ++ names ++
        ", which the " ++ name ++ " platform does not have in this build: check one of them first");
}

// ============================================================================
// 6.1 Process and identity
// ============================================================================

/// What the process asks of `initializePlatform`.
pub const PlatformOptions = extern struct {
    reserved: u8 = 0,
};

/// The storage engine a platform uses by default (6.6).
pub const StorageEngine = enum(u8) { memory, sqlite, leveldb, other };

/// Comptime identity constants (HTML 8.10.1.1 Client identification).
pub const Identity = extern struct {
    /// navigator.platform.
    navigator_platform: Str,
    /// The OS token of the default User-Agent ("Macintosh; Intel Mac OS X").
    ua_os_token: Str,
    /// navigator.oscpu.
    oscpu: Str,
    /// File API's native line ending ("\n" or "\r\n").
    native_line_ending: Str,
    path_separator: u8,
    storage_engine: StorageEngine,
};

/// The platform's comptime identity.
pub const identity: Identity = impl.identity;

/// Resident memory, for diagnostics (tools) only.
pub const MemoryReading = extern struct {
    resident_bytes: u64,
};

/// Once, before any Browser: what is truly per process (curl_global_init,
/// the process Io and its signal dispositions). crane.Process calls it.
pub inline fn initializePlatform(options: *const PlatformOptions) Error!void {
    return impl.initializePlatform(options);
}

/// At process end.
pub inline fn deinitializePlatform() void {
    return impl.deinitializePlatform();
}

/// The CLI's profile root, OWNED (macOS ~/Library/Application Support/Crane;
/// Linux $XDG_DATA_HOME/crane; null on iOS - the app passes its container).
/// Any thread.
pub inline fn defaultDataDirectory(allocator: std.mem.Allocator) Error!?[]u8 {
    return impl.defaultDataDirectory(allocator);
}

/// The OS's preferred languages (HTML 8.10.1.2), most preferred first. The
/// slice and every string in it are OWNED, allocated with `allocator`. Any
/// thread.
pub inline fn preferredLanguages(allocator: std.mem.Allocator) Error![]Str {
    return impl.preferredLanguages(allocator);
}

/// The IANA time zone id for the engine adapter's Date and Intl, OWNED.
pub inline fn defaultTimeZone(allocator: std.mem.Allocator) Error![]u8 {
    return impl.defaultTimeZone(allocator);
}

/// navigator.hardwareConcurrency's input. At least 1.
pub inline fn logicalProcessorCount() u32 {
    return impl.logicalProcessorCount();
}

/// navigator.deviceMemory before Device Memory's rounding.
pub inline fn deviceMemoryGiB() f64 {
    return impl.deviceMemoryGiB();
}

/// Resident memory now [resident_memory]; null if the OS will not say.
pub inline fn residentMemory() ?MemoryReading {
    comptime gate(.resident_memory, "residentMemory");
    return impl.residentMemory();
}

// ============================================================================
// 6.2 Clocks (HR-Time 2.1)
// ============================================================================

/// The monotonic clock's unsafe current time. Any thread; hot (performance.now
/// and every Event.timeStamp pay one call).
pub inline fn monotonicNow() Instant {
    return impl.monotonicNow();
}

/// The wall clock's unsafe current time. Any thread.
pub inline fn wallNow() WallTime {
    return impl.wallNow();
}

/// Block this thread for `nanoseconds`. TRANSITIONAL: deleted once the
/// network step replaces the remaining sleeps with port waits (recipes step 2).
pub inline fn sleepThread(nanoseconds: u64) void {
    return impl.sleepThread(nanoseconds);
}

/// The monotonic clock in whole milliseconds.
pub fn monotonicMillis() i64 {
    return @intCast(monotonicNow().ns / std.time.ns_per_ms);
}

/// The wall clock in whole milliseconds since the epoch.
pub fn wallMillis() i64 {
    return @divFloor(wallNow().ns_since_epoch, std.time.ns_per_ms);
}

/// The wall clock in whole seconds since the epoch.
pub fn wallSeconds() i64 {
    return @divFloor(wallNow().ns_since_epoch, std.time.ns_per_s);
}

/// Elapsed time on the monotonic clock.
pub const Stopwatch = struct {
    start_ns: u64,

    pub fn start() Stopwatch {
        return .{ .start_ns = monotonicNow().ns };
    }

    /// Nanoseconds since start (or the last lap or reset).
    pub fn read(self: *const Stopwatch) u64 {
        return monotonicNow().ns -| self.start_ns;
    }

    /// `read`, then restart from now.
    pub fn lap(self: *Stopwatch) u64 {
        const now = monotonicNow().ns;
        const elapsed = now -| self.start_ns;
        self.start_ns = now;
        return elapsed;
    }

    pub fn reset(self: *Stopwatch) void {
        self.start_ns = monotonicNow().ns;
    }
};

// ============================================================================
// 6.3 Randomness
// ============================================================================

/// Cryptographically strong bytes from the OS (WebCrypto 10.1.1
/// getRandomValues, 10.1.2 randomUUID, key generation, every PRNG seed).
/// Cannot fail: the platform aborts if the OS cannot supply entropy.
pub inline fn fillRandom(bytes: []u8) void {
    return impl.fillRandom(bytes);
}

// ============================================================================
// 6.4 Threads
// ============================================================================

/// A thread's quality of service [thread_qos]; ignored where unsupported.
pub const ThreadQos = enum(u8) { default, user_interactive, user_initiated, utility, background };

pub const ThreadOptions = extern struct {
    /// Shown by debuggers; empty: none.
    name: Str = .{},
    /// 0: the platform's default.
    stack_size: usize = 0,
    qos: ThreadQos = .default,
};

/// Start a thread running `entry(context)`. OWNED until `joinThread`. Worker
/// agents, IndexedDB's workers, a C embedder's Browser thread.
pub inline fn spawnThread(options: ThreadOptions, entry: *const fn (?*anyopaque) callconv(.c) void, context: ?*anyopaque) Error!Thread {
    return impl.spawnThread(options, entry, context);
}

/// Wait for `thread` to end and release it.
pub inline fn joinThread(thread: Thread) void {
    return impl.joinThread(thread);
}

// ============================================================================
// 6.5 Files and storage locations
// ============================================================================

pub const FileKind = enum(u8) { file, directory, sym_link, other };

pub const FileInfo = extern struct {
    size: u64,
    modified: WallTime,
    kind: FileKind,
};

/// A directory entry. `name` is OWNED by the allocator `listDirectory` took.
pub const DirEntry = extern struct {
    name: Str,
    kind: FileKind,
};

/// Storage 6 "Usage and quota"'s input.
pub const VolumeSpace = extern struct {
    total: u64,
    available: u64,
};

/// Make `path` and any missing parents. Paths are absolute UTF-8.
pub inline fn makeDirectoryPath(path: Str) Error!void {
    return impl.makeDirectoryPath(path);
}

/// The file's bytes, OWNED; `error.Io` past `limit` bytes. The V8 snapshot,
/// CLDR data, file: URLs [file_urls] (Fetch 4.3 scheme fetch "file").
pub inline fn readFile(allocator: std.mem.Allocator, path: Str, limit: usize) Error![]u8 {
    return impl.readFile(allocator, path, limit);
}

/// Write `bytes` to a temporary beside `path`, then rename it over `path`.
pub inline fn writeFileAtomic(path: Str, bytes: Bytes) Error!void {
    return impl.writeFileAtomic(path, bytes);
}

pub inline fn deleteFile(path: Str) Error!void {
    return impl.deleteFile(path);
}

/// Delete `path` and everything under it; nothing to delete is success.
pub inline fn deleteTree(path: Str) Error!void {
    return impl.deleteTree(path);
}

pub inline fn fileInfo(path: Str) Error!FileInfo {
    return impl.fileInfo(path);
}

/// The entries of a directory, OWNED (the slice and each name).
pub inline fn listDirectory(allocator: std.mem.Allocator, path: Str) Error![]DirEntry {
    return impl.listDirectory(allocator, path);
}

pub inline fn volumeSpace(path: Str) Error!VolumeSpace {
    return impl.volumeSpace(path);
}

// ============================================================================
// 6.6 The storage engine (decision 10)
// ============================================================================
//
// A transactional, ordered key-value store. Keys are byte strings compared
// lexicographically as unsigned bytes - the one order every implementation
// must give. Web-visible behaviour (IndexedDB's key encoding, scheduling,
// quota) is Crane's, above this layer.

pub const StoreError = error{ OutOfMemory, NotFound, Conflict, Corrupt, QuotaExceeded, Io, Closed };

pub const StoreOptions = extern struct {
    /// Create the store if it does not exist.
    create: bool = true,
    /// In memory even when the Browser has a profile directory.
    in_memory: bool = false,
};

pub const TransactionMode = enum(u8) { read, write };
pub const CursorDirection = enum(u8) { forward, reverse };

/// A key range; a bound is used only when its `has_` flag is set.
pub const KeyRange = extern struct {
    lower: Bytes = .{},
    upper: Bytes = .{},
    has_lower: bool = false,
    has_upper: bool = false,
    lower_open: bool = false,
    upper_open: bool = false,

    pub const all: KeyRange = .{};
};

/// A key and its value, both OWNED by the allocator `cursorNext` took.
pub const KeyValue = extern struct {
    key: Bytes,
    value: Bytes,
};

/// Open (or create) the Browser's store `name`: under its profile, or in
/// memory. OWNED until `closeStore`. Any thread.
pub inline fn openStore(browser: *BrowserPlatform, store_name: Str, options: StoreOptions) StoreError!*Store {
    return impl.openStore(browser, store_name, options);
}

pub inline fn closeStore(store: *Store) void {
    return impl.closeStore(store);
}

/// Delete the Browser's store `name` (Clear-Site-Data, IDBFactory.deleteDatabase).
pub inline fn deleteStore(browser: *BrowserPlatform, store_name: Str) StoreError!void {
    return impl.deleteStore(browser, store_name);
}

/// Snapshot isolation for reads; one writer at a time. One thread per
/// transaction.
pub inline fn beginTransaction(store: *Store, mode: TransactionMode) StoreError!*StoreTransaction {
    return impl.beginTransaction(store, mode);
}

/// Durable on return when the store is persistent. Ends the transaction.
pub inline fn commitTransaction(transaction: *StoreTransaction) StoreError!void {
    return impl.commitTransaction(transaction);
}

/// Discard the transaction's writes. Ends the transaction.
pub inline fn abortTransaction(transaction: *StoreTransaction) void {
    return impl.abortTransaction(transaction);
}

/// The value under `key`, OWNED; null if none.
pub inline fn storeGet(transaction: *StoreTransaction, allocator: std.mem.Allocator, key: Bytes) StoreError!?[]u8 {
    return impl.storeGet(transaction, allocator, key);
}

pub inline fn storePut(transaction: *StoreTransaction, key: Bytes, value: Bytes) StoreError!void {
    return impl.storePut(transaction, key, value);
}

pub inline fn storeDelete(transaction: *StoreTransaction, key: Bytes) StoreError!void {
    return impl.storeDelete(transaction, key);
}

pub inline fn storeDeleteRange(transaction: *StoreTransaction, range: KeyRange) StoreError!void {
    return impl.storeDeleteRange(transaction, range);
}

/// A cursor over `range` in the transaction's view. OWNED until `closeCursor`,
/// which must come before the transaction ends.
pub inline fn openCursor(transaction: *StoreTransaction, range: KeyRange, direction: CursorDirection) StoreError!*StoreCursor {
    return impl.openCursor(transaction, range, direction);
}

/// The next pair, OWNED; null at the end.
pub inline fn cursorNext(cursor: *StoreCursor, allocator: std.mem.Allocator) StoreError!?KeyValue {
    return impl.cursorNext(cursor, allocator);
}

pub inline fn closeCursor(cursor: *StoreCursor) void {
    return impl.closeCursor(cursor);
}

/// Bytes the store uses, for Storage 6. Any thread.
pub inline fn storeSize(store: *Store) StoreError!u64 {
    return impl.storeSize(store);
}

// ============================================================================
// 6.7 Network (Fetch 4.7 HTTP-network fetch's transport; WebSockets)
// ============================================================================
//
// The platform moves bytes. Every Fetch algorithm (redirects - the transport
// never follows them -, cookies, CORS, caching) and the WebSocket protocol's
// state stay Crane's.

/// What starting a transfer or a socket fails with, synchronously. Failures
/// after the start arrive in the client's `end` / `closed`.
pub const HttpError = error{ OutOfMemory, InvalidRequest, Canceled, NetworkError };

pub const Header = extern struct {
    name: Str,
    value: Str,
};

pub const HeaderList = extern struct {
    ptr: [*]const Header = &[_]Header{},
    len: usize = 0,

    pub fn from(headers: []const Header) HeaderList {
        return .{ .ptr = headers.ptr, .len = headers.len };
    }

    pub fn slice(self: HeaderList) []const Header {
        return self.ptr[0..self.len];
    }
};

pub const HttpVersion = enum(u8) { any, http1_1, http2, http3 };

pub const RequestBodyKind = enum(u8) { none, bytes, pull };

/// A request body: none, bytes copied with the request, or a pull callback
/// the platform calls inside `pollEventLoopPort` (it returns bytes written
/// into `buffer`, 0 at the end, or a negative value to fail the transfer).
pub const RequestBody = extern struct {
    kind: RequestBodyKind = .none,
    bytes: Bytes = .{},
    pull: ?*const fn (context: ?*anyopaque, buffer: [*]u8, capacity: usize) callconv(.c) isize = null,
    pull_context: ?*anyopaque = null,
    /// The length when known; -1 when not (chunked).
    length: i64 = -1,
};

/// An HTTP request as Crane built it. BORROWED; copied before
/// `startTransfer` returns.
pub const HttpRequest = extern struct {
    url: Str,
    method: Str,
    /// In order, as sent.
    headers: HeaderList = .{},
    body: RequestBody = .{},
    version: HttpVersion = .any,
    /// 0: none.
    connect_timeout_ms: u32 = 0,
    total_timeout_ms: u32 = 0,
    /// HTTP-network fetch step 8.3: refuse anything but HTTP/2.
    require_http2: bool = false,
};

/// Resource Timing marks on the monotonic clock; 0 = did not happen.
pub const TransferTiming = extern struct {
    dns_start: u64 = 0,
    dns_end: u64 = 0,
    connect_start: u64 = 0,
    connect_end: u64 = 0,
    tls_start: u64 = 0,
    request_start: u64 = 0,
    first_byte: u64 = 0,
};

/// A response head. One per block: 1xx informational blocks arrive apart,
/// with `informational` set. BORROWED for the callback.
pub const HttpResponseHead = extern struct {
    status: u16,
    status_message: Str = .{},
    version: HttpVersion = .any,
    headers: HeaderList = .{},
    header_bytes: u64 = 0,
    remote_address: Str = .{},
    connection_reused: bool = false,
    informational: bool = false,
    timing: TransferTiming = .{},
};

/// How a transfer ended. `native_code` keeps the transport's own cause an
/// allowlisted retry needs (docs/lessons/spec-compliance-a-network-error-may-need-a-native-cause.md).
pub const TransferOutcome = enum(u8) { ok, canceled, dns_failed, connect_failed, tls_failed, timed_out, protocol_error, http2_required, too_large, other };

pub const TransferResult = extern struct {
    outcome: TransferOutcome,
    native_code: i32 = 0,
};

/// A transfer's receiver. Every callback runs inside `pollEventLoopPort`,
/// never inside a library call; `end` comes last, exactly once.
pub const TransferClient = extern struct {
    context: ?*anyopaque,
    head: *const fn (context: ?*anyopaque, head: *const HttpResponseHead) callconv(.c) void,
    /// The bytes are BORROWED for the call.
    data: *const fn (context: ?*anyopaque, bytes: Bytes) callconv(.c) void,
    end: *const fn (context: ?*anyopaque, result: *const TransferResult) callconv(.c) void,
};

/// The WebSocket handshake request Crane built (URL, protocols, origin,
/// cookies). BORROWED; copied before `openWebSocket` returns.
pub const WebSocketRequest = extern struct {
    url: Str,
    protocols: StrList = .{},
    origin: Str = .{},
    headers: HeaderList = .{},
};

pub const WebSocketFrameKind = enum(u8) { text, binary, ping, pong };

/// A socket's receiver; every callback runs inside `pollEventLoopPort`.
pub const WebSocketClient = extern struct {
    context: ?*anyopaque,
    opened: *const fn (context: ?*anyopaque, head: *const HttpResponseHead) callconv(.c) void,
    /// The bytes are BORROWED for the call.
    frame: *const fn (context: ?*anyopaque, kind: WebSocketFrameKind, bytes: Bytes, fin: bool) callconv(.c) void,
    closed: *const fn (context: ?*anyopaque, code: u16, reason: Str, clean: bool) callconv(.c) void,
};

/// One per event loop (the Browser's, each worker's), OWNED by it, bound to
/// the Browser's network context. The agent's thread.
pub inline fn createEventLoopPort(allocator: std.mem.Allocator, browser: *BrowserPlatform) Error!*EventLoopPort {
    return impl.createEventLoopPort(allocator, browser);
}

/// Cancel what still runs, with no callbacks, and free the port.
pub inline fn destroyEventLoopPort(port: *EventLoopPort) void {
    return impl.destroyEventLoopPort(port);
}

/// One non-blocking step; every transfer and WebSocket callback runs inside
/// it. True if anything ran.
pub inline fn pollEventLoopPort(port: *EventLoopPort) bool {
    return impl.pollEventLoopPort(port);
}

/// Block until a socket is ready, `deadline` (the next timer) passes or
/// `wakeEventLoopPort` is called: the HTML 8.1.7.3 processing model's wait.
pub inline fn waitEventLoopPort(port: *EventLoopPort, deadline: ?Instant) void {
    return impl.waitEventLoopPort(port, deadline);
}

/// End a wait. ANY thread: runtime.TaskSink calls it on every post.
pub inline fn wakeEventLoopPort(port: *EventLoopPort) void {
    return impl.wakeEventLoopPort(port);
}

/// Start a transfer. The request is copied before return; the client hears
/// `head`, `data` and finally `end`, all inside `pollEventLoopPort`.
pub inline fn startTransfer(port: *EventLoopPort, allocator: std.mem.Allocator, request: *const HttpRequest, client: TransferClient) HttpError!*Transfer {
    return impl.startTransfer(port, allocator, request, client);
}

/// Nothing more is heard from the transfer.
pub inline fn cancelTransfer(port: *EventLoopPort, transfer: *Transfer) void {
    return impl.cancelTransfer(port, transfer);
}

/// Receive backpressure.
pub inline fn pauseTransfer(port: *EventLoopPort, transfer: *Transfer) void {
    return impl.pauseTransfer(port, transfer);
}

pub inline fn resumeTransfer(port: *EventLoopPort, transfer: *Transfer) void {
    return impl.resumeTransfer(port, transfer);
}

/// Open a WebSocket. The per-host CONNECTING queue (RFC 6455 4.1) is the
/// Browser's. OWNED until `releaseWebSocket`.
pub inline fn openWebSocket(port: *EventLoopPort, allocator: std.mem.Allocator, request: *const WebSocketRequest, client: WebSocketClient) HttpError!*WebSocket {
    return impl.openWebSocket(port, allocator, request, client);
}

/// Send a frame; the platform buffers partial writes.
pub inline fn sendWebSocketFrame(socket: *WebSocket, kind: WebSocketFrameKind, bytes: Bytes) HttpError!void {
    return impl.sendWebSocketFrame(socket, kind, bytes);
}

/// Start the closing handshake.
pub inline fn closeWebSocket(socket: *WebSocket, code: u16, reason: Str) void {
    return impl.closeWebSocket(socket, code, reason);
}

/// Free the socket; nothing more is heard.
pub inline fn releaseWebSocket(socket: *WebSocket) void {
    return impl.releaseWebSocket(socket);
}

// ============================================================================
// 6.8 Crypto primitives (decision 11)
// ============================================================================
//
// WebCrypto's spec steps stay above the protocol; these are primitives over
// raw key material, synchronous, any thread. Crane maps CryptoError to the
// spec's OperationError / DataError at its edge, identically everywhere.

pub const CryptoError = error{ OutOfMemory, InvalidKey, OperationFailed, NotSupported };

pub const HashAlgorithm = enum(u8) { sha1, sha256, sha384, sha512 };
pub const EcCurve = enum(u8) { p256, p384, p521 };
pub const OkpCurve = enum(u8) { ed25519, x25519 };
pub const AesModeKind = enum(u8) { cbc, ctr, gcm, kw };

/// An AES mode and its parameters; fields a mode does not use are ignored.
pub const AesMode = extern struct {
    kind: AesModeKind,
    /// CBC and GCM.
    iv: Bytes = .{},
    /// CTR: the counter block and how many of its rightmost bits count.
    counter: Bytes = .{},
    counter_length: u32 = 0,
    /// GCM.
    additional_data: Bytes = .{},
    tag_bits: u32 = 128,
};

pub const RsaPaddingKind = enum(u8) { pkcs1v15, pss };

pub const RsaPadding = extern struct {
    kind: RsaPaddingKind,
    /// PSS only.
    salt_length: u32 = 0,
};

/// SHA-1, SHA-256/384/512 of `message`, OWNED.
pub inline fn digest(allocator: std.mem.Allocator, hash: HashAlgorithm, message: Bytes) CryptoError![]u8 {
    return impl.digest(allocator, hash, message);
}

pub inline fn hmacSign(allocator: std.mem.Allocator, hash: HashAlgorithm, key: Bytes, message: Bytes) CryptoError![]u8 {
    return impl.hmacSign(allocator, hash, key, message);
}

/// Constant-time comparison of the recomputed MAC.
pub inline fn hmacVerify(hash: HashAlgorithm, key: Bytes, signature: Bytes, message: Bytes) bool {
    return impl.hmacVerify(hash, key, signature, message);
}

/// HKDF-Extract-and-Expand to `bits` bits, OWNED.
pub inline fn hkdf(allocator: std.mem.Allocator, hash: HashAlgorithm, key: Bytes, salt: Bytes, info: Bytes, bits: u32) CryptoError![]u8 {
    return impl.hkdf(allocator, hash, key, salt, info, bits);
}

pub inline fn pbkdf2(allocator: std.mem.Allocator, hash: HashAlgorithm, password: Bytes, salt: Bytes, iterations: u32, bits: u32) CryptoError![]u8 {
    return impl.pbkdf2(allocator, hash, password, salt, iterations, bits);
}

pub inline fn aesEncrypt(allocator: std.mem.Allocator, mode: *const AesMode, key: Bytes, input: Bytes) CryptoError![]u8 {
    return impl.aesEncrypt(allocator, mode, key, input);
}

pub inline fn aesDecrypt(allocator: std.mem.Allocator, mode: *const AesMode, key: Bytes, input: Bytes) CryptoError![]u8 {
    return impl.aesDecrypt(allocator, mode, key, input);
}

/// A new private scalar, OWNED; entropy from `fillRandom`.
pub inline fn ecGenerate(allocator: std.mem.Allocator, curve: EcCurve) CryptoError![]u8 {
    return impl.ecGenerate(allocator, curve);
}

/// The uncompressed public point of a private scalar, OWNED.
pub inline fn ecPublicKey(allocator: std.mem.Allocator, curve: EcCurve, private: Bytes) CryptoError![]u8 {
    return impl.ecPublicKey(allocator, curve, private);
}

/// A point checked on the curve, returned uncompressed, OWNED.
pub inline fn ecValidatePublic(allocator: std.mem.Allocator, curve: EcCurve, point: Bytes) CryptoError![]u8 {
    return impl.ecValidatePublic(allocator, curve, point);
}

/// An IEEE P1363 signature, OWNED.
pub inline fn ecdsaSign(allocator: std.mem.Allocator, curve: EcCurve, hash: HashAlgorithm, private: Bytes, message: Bytes) CryptoError![]u8 {
    return impl.ecdsaSign(allocator, curve, hash, private, message);
}

pub inline fn ecdsaVerify(curve: EcCurve, hash: HashAlgorithm, public: Bytes, signature: Bytes, message: Bytes) CryptoError!bool {
    return impl.ecdsaVerify(curve, hash, public, signature, message);
}

/// The shared secret, truncated to `bits` when given, OWNED.
pub inline fn ecdhDerive(allocator: std.mem.Allocator, curve: EcCurve, private: Bytes, peer_public: Bytes, bits: ?u32) CryptoError![]u8 {
    return impl.ecdhDerive(allocator, curve, private, peer_public, bits);
}

/// The 32-byte public key of a 32-byte private key, OWNED.
pub inline fn okpPublicKey(allocator: std.mem.Allocator, curve: OkpCurve, private: Bytes) CryptoError![]u8 {
    return impl.okpPublicKey(allocator, curve, private);
}

pub inline fn ed25519Sign(allocator: std.mem.Allocator, private: Bytes, message: Bytes) CryptoError![]u8 {
    return impl.ed25519Sign(allocator, private, message);
}

pub inline fn ed25519Verify(public: Bytes, signature: Bytes, message: Bytes) CryptoError!bool {
    return impl.ed25519Verify(public, signature, message);
}

pub inline fn x25519Derive(allocator: std.mem.Allocator, private: Bytes, peer_public: Bytes) CryptoError![]u8 {
    return impl.x25519Derive(allocator, private, peer_public);
}

/// A PKCS#1 private key DER of `bits` bits, OWNED.
pub inline fn rsaGenerate(allocator: std.mem.Allocator, bits: u32, exponent: Bytes) CryptoError![]u8 {
    return impl.rsaGenerate(allocator, bits, exponent);
}

/// The PKCS#1 public key DER of a private key DER, OWNED.
pub inline fn rsaPublicKey(allocator: std.mem.Allocator, private_der: Bytes) CryptoError![]u8 {
    return impl.rsaPublicKey(allocator, private_der);
}

pub inline fn rsaSign(allocator: std.mem.Allocator, padding: RsaPadding, hash: HashAlgorithm, private_der: Bytes, message: Bytes) CryptoError![]u8 {
    return impl.rsaSign(allocator, padding, hash, private_der, message);
}

pub inline fn rsaVerify(padding: RsaPadding, hash: HashAlgorithm, public_der: Bytes, signature: Bytes, message: Bytes) CryptoError!bool {
    return impl.rsaVerify(padding, hash, public_der, signature, message);
}

/// RSA-OAEP.
pub inline fn rsaEncrypt(allocator: std.mem.Allocator, hash: HashAlgorithm, label: Bytes, key_der: Bytes, input: Bytes) CryptoError![]u8 {
    return impl.rsaEncrypt(allocator, hash, label, key_der, input);
}

pub inline fn rsaDecrypt(allocator: std.mem.Allocator, hash: HashAlgorithm, label: Bytes, key_der: Bytes, input: Bytes) CryptoError![]u8 {
    return impl.rsaDecrypt(allocator, hash, label, key_der, input);
}

// ============================================================================
// 6.9 Layout (decision 14) [layout]
// ============================================================================
//
// Crane does not lay out. A rendering host plugs in here; the headless answer
// is today's: no layout box anywhere. How a layout implementation reads the
// DOM and computed style is designed with the first rendering host.

/// A stable per-Browser node id Crane assigns; no Instance pointer crosses.
pub const LayoutNode = extern struct {
    id: u64,
};

pub const Point = extern struct {
    x: f64 = 0,
    y: f64 = 0,
};

pub const Rect = extern struct {
    x: f64 = 0,
    y: f64 = 0,
    width: f64 = 0,
    height: f64 = 0,
};

/// A box's CSSOM View metrics (offset*, client*, scroll*).
pub const BoxMetrics = extern struct {
    offset: Rect,
    /// 0: offsetParent is null.
    offset_parent: LayoutNode,
    client: Rect,
    scroll_width: f64,
    scroll_height: f64,
};

pub const ScrollBehavior = enum(u8) { auto, instant, smooth };

/// The viewport: CSSOM View and media queries.
pub const Viewport = extern struct {
    width: f64,
    height: f64,
    device_pixel_ratio: f64,
    visual: Rect,
};

pub const InvalidationReason = enum(u8) { tree, style, attribute, text };

/// The node's box metrics; null: no layout box (offsetWidth 0, offsetParent
/// null, ...).
pub inline fn layoutBox(browser: *BrowserPlatform, document: LayoutNode, node: LayoutNode) ?BoxMetrics {
    comptime gate(.layout, "layoutBox");
    return impl.layoutBox(browser, document, node);
}

/// getClientRects, OWNED; empty with no box.
pub inline fn clientRects(browser: *BrowserPlatform, document: LayoutNode, node: LayoutNode, allocator: std.mem.Allocator) Error![]Rect {
    comptime gate(.layout, "clientRects");
    return impl.clientRects(browser, document, node, allocator);
}

/// scrollTop/Left; the viewport's when `node` is the document.
pub inline fn scrollPosition(browser: *BrowserPlatform, document: LayoutNode, node: LayoutNode) Point {
    comptime gate(.layout, "scrollPosition");
    return impl.scrollPosition(browser, document, node);
}

pub inline fn setScrollPosition(browser: *BrowserPlatform, document: LayoutNode, node: LayoutNode, point: Point, behavior: ScrollBehavior) void {
    comptime gate(.layout, "setScrollPosition");
    return impl.setScrollPosition(browser, document, node, point, behavior);
}

/// elementsFromPoint, topmost first, OWNED; empty with no layout.
pub inline fn hitTest(browser: *BrowserPlatform, document: LayoutNode, point: Point, allocator: std.mem.Allocator) Error![]LayoutNode {
    comptime gate(.layout, "hitTest");
    return impl.hitTest(browser, document, point, allocator);
}

/// HTML's "being rendered"; false with no layout.
pub inline fn isRendered(browser: *BrowserPlatform, document: LayoutNode, node: LayoutNode) bool {
    comptime gate(.layout, "isRendered");
    return impl.isRendered(browser, document, node);
}

/// innerText's rendered text, OWNED; null: Crane uses the not-rendered steps.
pub inline fn renderedText(browser: *BrowserPlatform, document: LayoutNode, node: LayoutNode, allocator: std.mem.Allocator) Error!?[]u8 {
    comptime gate(.layout, "renderedText");
    return impl.renderedText(browser, document, node, allocator);
}

pub inline fn viewport(browser: *BrowserPlatform, tab: TabId) Viewport {
    comptime gate(.layout, "viewport");
    return impl.viewport(browser, tab);
}

/// Crane reports a change; the implementation lays out lazily.
pub inline fn invalidateLayout(browser: *BrowserPlatform, document: LayoutNode, node: LayoutNode, reason: InvalidationReason) void {
    comptime gate(.layout, "invalidateLayout");
    return impl.invalidateLayout(browser, document, node, reason);
}

/// Before a layout-dependent query that must be current.
pub inline fn forceLayout(browser: *BrowserPlatform, document: LayoutNode) void {
    comptime gate(.layout, "forceLayout");
    return impl.forceLayout(browser, document);
}

// ============================================================================
// 6.10 Capabilities offered to pages
// ============================================================================
//
// Every operation below is per Browser, called on the requesting agent's
// thread (section 4), and gated on its capability. Crane draws no prompt,
// dialog or picker: a platform uses the OS's own permission requests and
// native system UI; with no window it drops the Reply and Crane takes the
// spec's unsupported path.

// ---- 6.10.1 Permissions [os_permissions] (section 8) ----

/// A powerful feature's name (Permissions, the registry).
pub const PermissionName = enum(u16) {
    accelerometer,
    ambient_light_sensor,
    background_fetch,
    background_sync,
    bluetooth,
    camera,
    clipboard_read,
    clipboard_write,
    compute_pressure,
    display_capture,
    geolocation,
    gyroscope,
    idle_detection,
    keyboard_lock,
    local_fonts,
    magnetometer,
    microphone,
    midi,
    nfc,
    notifications,
    persistent_storage,
    pointer_lock,
    push,
    screen_wake_lock,
    speaker_selection,
    storage_access,
    top_level_storage_access,
    window_management,
    other,
};

/// A permission descriptor; fields a name does not use are ignored.
pub const PermissionDescriptor = extern struct {
    name: PermissionName,
    /// `other`: the descriptor's name as given.
    other_name: Str = .{},
    /// push: userVisibleOnly.
    user_visible_only: bool = false,
    /// midi: sysex.
    sysex: bool = false,
    /// camera: panTiltZoom.
    pan_tilt_zoom: bool = false,
    /// clipboard-read/-write: allowWithoutSanitization.
    allow_without_sanitization: bool = false,
};

pub const PermissionState = enum(u8) { granted, denied, prompt };

/// Whether the OS governs a descriptor and, if so, its state.
pub const PlatformPermission = extern struct {
    governed: bool,
    state: PermissionState,
};

/// One decision per descriptor asked, in order. BORROWED for `deliver`.
pub const PermissionDecisions = extern struct {
    ptr: [*]const PermissionState,
    len: usize,
};

/// Synchronous. The OS's state for an OS-governed descriptor; the platform's
/// default state otherwise (Permissions 5.1 step 8).
pub inline fn platformPermissionState(browser: *BrowserPlatform, requester: *const Requester, descriptor: *const PermissionDescriptor) PlatformPermission {
    comptime gate(.os_permissions, "platformPermissionState");
    return impl.platformPermissionState(browser, requester, descriptor);
}

/// Permissions 5.2 step 3: the OS access request for a governed descriptor;
/// the platform's policy for an ungoverned one in the prompt state.
pub inline fn requestPermission(browser: *BrowserPlatform, requester: *const Requester, descriptors: []const PermissionDescriptor, reply: Reply(PermissionDecisions)) void {
    comptime gate(.os_permissions, "requestPermission");
    return impl.requestPermission(browser, requester, descriptors, reply);
}

/// A hint that a pending request's realm ended (take a prompt down, stop a
/// camera). The platform still completes the Reply. Any capability.
pub inline fn cancelRequest(browser: *BrowserPlatform, id: RequestId) void {
    return impl.cancelRequest(browser, id);
}

// ---- 6.10.2 Dialogs, printing, console and windows ----

pub const DialogKind = enum(u8) { alert, confirm, prompt, beforeunload };

pub const DialogRequest = extern struct {
    kind: DialogKind,
    message: Str = .{},
    /// prompt's default value.
    default_value: Str = .{},
};

/// The user's answer: `accepted` (OK / leave), and prompt's text.
pub const DialogResult = extern struct {
    accepted: bool,
    text: Str = .{},
};

/// HTML 8.9.1's simple dialogs, asked only when the WebDriver BiDi user
/// prompt handler is "none"; Crane pauses until the Reply (section 4).
pub inline fn runSimpleDialog(browser: *BrowserPlatform, requester: *const Requester, request: *const DialogRequest, reply: Reply(DialogResult)) void {
    comptime gate(.simple_dialogs, "runSimpleDialog");
    return impl.runSimpleDialog(browser, requester, request, reply);
}

/// HTML 8.9.2 printing steps.
pub inline fn printDocument(browser: *BrowserPlatform, requester: *const Requester, reply: Reply(Unit)) void {
    comptime gate(.printing, "printDocument");
    return impl.printDocument(browser, requester, reply);
}

/// window.open's request (HTML 7.2.2.1, "the rules for choosing a navigable").
pub const TraversableRequest = extern struct {
    url: Str,
    features: Str = .{},
    noopener: bool = false,
};

pub const TraversableDecision = enum(u8) { allow, block };

pub const TraversableChangeKind = enum(u8) { created, closed, activated };

pub const TraversableChange = extern struct {
    kind: TraversableChangeKind,
    /// `created`: the opener's tab, 0 if none.
    opener: TabId = 0,
};

/// Popup blocking.
pub inline fn createTopLevelTraversable(browser: *BrowserPlatform, requester: *const Requester, request: *const TraversableRequest) TraversableDecision {
    comptime gate(.windows, "createTopLevelTraversable");
    return impl.createTopLevelTraversable(browser, requester, request);
}

pub inline fn traversableChanged(browser: *BrowserPlatform, tab: TabId, change: *const TraversableChange) void {
    comptime gate(.windows, "traversableChanged");
    return impl.traversableChanged(browser, tab, change);
}

/// outerWidth, screenX (CSSOM View).
pub inline fn windowRect(browser: *BrowserPlatform, tab: TabId) Rect {
    comptime gate(.windows, "windowRect");
    return impl.windowRect(browser, tab);
}

/// moveTo / resizeTo.
pub inline fn requestWindowRect(browser: *BrowserPlatform, tab: TabId, rect: Rect) void {
    comptime gate(.windows, "requestWindowRect");
    return impl.requestWindowRect(browser, tab, rect);
}

pub const ConsoleSourceKind = enum(u8) { tab, worker };

pub const ConsoleSource = extern struct {
    kind: ConsoleSourceKind,
    /// The tab, or the worker's id.
    id: u64,
};

pub const ConsoleLevel = enum(u8) { log, debug, info, warn, @"error" };

/// Console Standard 2.3 Printer. Required (kit default: stderr).
pub inline fn printConsoleMessage(browser: *BrowserPlatform, source: *const ConsoleSource, level: ConsoleLevel, text: Str) void {
    return impl.printConsoleMessage(browser, source, level, text);
}

// ---- 6.10.3 File pickers [file_picker] ----

pub const FilePickerMode = enum(u8) { open, open_multiple, save, directory };

pub const FilePickerOptions = extern struct {
    mode: FilePickerMode,
    /// MIME types and extensions, as the accept attribute lists them.
    accept: StrList = .{},
    /// The capture attribute; empty: none.
    capture: Str = .{},
    suggested_name: Str = .{},
};

pub const PickedFile = extern struct {
    token: FileToken,
    name: Str,
    mime_type: Str = .{},
    size: u64,
    last_modified: WallTime,
};

/// The files chosen; none: canceled. BORROWED for `deliver`.
pub const PickedFiles = extern struct {
    ptr: [*]const PickedFile,
    len: usize,
};

/// HTML 4.10.5.1.17's File Upload picker, showPicker(), File System Access.
pub inline fn showFilePicker(browser: *BrowserPlatform, requester: *const Requester, options: *const FilePickerOptions, reply: Reply(PickedFiles)) void {
    comptime gate(.file_picker, "showFilePicker");
    return impl.showFilePicker(browser, requester, options, reply);
}

/// A picked file's bytes; files stay where the OS keeps them.
pub inline fn readPickedFile(browser: *BrowserPlatform, file: FileToken, offset: u64, length: u32, reply: Reply(Bytes)) void {
    comptime gate(.file_picker, "readPickedFile");
    return impl.readPickedFile(browser, file, offset, length, reply);
}

pub inline fn releasePickedFile(browser: *BrowserPlatform, file: FileToken) void {
    comptime gate(.file_picker, "releasePickedFile");
    return impl.releasePickedFile(browser, file);
}

// ---- 6.10.4 Screen and system state (required; defaults allowed) ----

pub const OrientationType = enum(u8) { portrait_primary, portrait_secondary, landscape_primary, landscape_secondary };

/// CSSOM View 2.3 and 4.3; Screen Orientation.
pub const ScreenInfo = extern struct {
    width: i32,
    height: i32,
    avail_width: i32,
    avail_height: i32,
    color_depth: u32,
    pixel_depth: u32,
    device_pixel_ratio: f64,
    orientation: OrientationType,
    orientation_angle: u16,
};

pub const ColorScheme = enum(u8) { light, dark };
pub const ReducedMotion = enum(u8) { no_preference, reduce };
pub const Contrast = enum(u8) { no_preference, more, less, custom };

/// Media Queries 5's user preferences.
pub const UserPreferences = extern struct {
    color_scheme: ColorScheme = .light,
    reduced_motion: ReducedMotion = .no_preference,
    contrast: Contrast = .no_preference,
    forced_colors: bool = false,
};

pub const Visibility = enum(u8) { visible, hidden };

/// The screens, BORROWED for `deliver` (Window Management).
pub const ScreenList = extern struct {
    ptr: [*]const ScreenInfo,
    len: usize,
};

/// The platform's current screen snapshot; changes arrive as events.
pub inline fn screenInfo(browser: *BrowserPlatform) ScreenInfo {
    return impl.screenInfo(browser);
}

/// HTML 8.10.1.3.
pub inline fn isOnline(browser: *BrowserPlatform) bool {
    return impl.isOnline(browser);
}

pub inline fn userPreferences(browser: *BrowserPlatform) UserPreferences {
    return impl.userPreferences(browser);
}

/// HTML's system visibility state.
pub inline fn systemVisibility(browser: *BrowserPlatform, tab: TabId) Visibility {
    return impl.systemVisibility(browser, tab);
}

pub inline fn screenDetails(browser: *BrowserPlatform, requester: *const Requester, reply: Reply(ScreenList)) void {
    comptime gate(.screen_details, "screenDetails");
    return impl.screenDetails(browser, requester, reply);
}

// ---- 6.10.5 Media ----

pub const MediaSupport = enum(u8) { unsupported, maybe, probably };

/// What a decoder has learned. Written by `pushMediaData`.
pub const MediaMetadata = extern struct {
    duration: f64 = 0,
    width: u32 = 0,
    height: u32 = 0,
};

pub const MediaResult = enum(u8) { need_more, unsupported, decode_error, metadata, current_data };

pub const VideoSize = extern struct {
    width: u32,
    height: u32,
};

/// HTML canPlayType.
pub inline fn mediaCanPlayType(browser: *BrowserPlatform, mime: Str) MediaSupport {
    comptime gate(.media_decoding, "mediaCanPlayType");
    return impl.mediaCanPlayType(browser, mime);
}

/// OWNED until `closeMediaDecoder`.
pub inline fn openMediaDecoder(browser: *BrowserPlatform, mime: Str) Error!*MediaDecoder {
    comptime gate(.media_decoding, "openMediaDecoder");
    return impl.openMediaDecoder(browser, mime);
}

/// Synchronous, as src/platform/media_backend.zig's push is today; on
/// `metadata` / `current_data` it has written `metadata`.
pub inline fn pushMediaData(decoder: *MediaDecoder, bytes: Bytes, end_of_stream: bool, metadata: *MediaMetadata) MediaResult {
    comptime gate(.media_decoding, "pushMediaData");
    return impl.pushMediaData(decoder, bytes, end_of_stream, metadata);
}

/// The video's intrinsic size at `seconds` (a resolution change mid-stream);
/// false if the decoder cannot say. media_backend.zig's video_size_at.
pub inline fn mediaVideoSize(decoder: *MediaDecoder, seconds: f64, size: *VideoSize) bool {
    comptime gate(.media_decoding, "mediaVideoSize");
    return impl.mediaVideoSize(decoder, seconds, size);
}

pub inline fn closeMediaDecoder(decoder: *MediaDecoder) void {
    comptime gate(.media_decoding, "closeMediaDecoder");
    return impl.closeMediaDecoder(decoder);
}

/// A Media Capabilities decoding configuration.
pub const MediaDecodingConfig = extern struct {
    content_type: Str,
    is_video: bool,
    width: u32 = 0,
    height: u32 = 0,
    bitrate: u64 = 0,
    framerate: f64 = 0,
    channels: Str = .{},
    samplerate: u32 = 0,
};

pub const DecodingInfo = extern struct {
    supported: bool = false,
    smooth: bool = false,
    power_efficient: bool = false,
};

pub inline fn mediaDecodingInfo(browser: *BrowserPlatform, config: *const MediaDecodingConfig) DecodingInfo {
    comptime gate(.media_capabilities, "mediaDecodingInfo");
    return impl.mediaDecodingInfo(browser, config);
}

pub const CodecKind = enum(u8) { video_decoder, video_encoder, audio_decoder, audio_encoder };

/// A WebCodecs configuration: the codec string and its description.
pub const CodecConfig = extern struct {
    kind: CodecKind,
    codec: Str,
    description: Bytes = .{},
    width: u32 = 0,
    height: u32 = 0,
    sample_rate: u32 = 0,
    channels: u32 = 0,
    bitrate: u64 = 0,
};

pub const EncodedChunk = extern struct {
    key: bool,
    timestamp_us: i64,
    duration_us: u64 = 0,
    data: Bytes,
};

/// A decoded frame or an encoded chunk, BORROWED for the call.
pub const CodecOutput = extern struct {
    timestamp_us: i64,
    duration_us: u64 = 0,
    key: bool = false,
    data: Bytes,
    width: u32 = 0,
    height: u32 = 0,
};

/// A codec's outputs and errors, from any thread.
pub const CodecSink = extern struct {
    context: ?*anyopaque,
    output: *const fn (context: ?*anyopaque, output: *const CodecOutput) callconv(.c) void,
    failed: *const fn (context: ?*anyopaque, message: Str) callconv(.c) void,
};

/// OWNED until `closeCodec`.
pub inline fn openCodec(browser: *BrowserPlatform, config: *const CodecConfig, output: CodecSink) Error!*Codec {
    comptime gate(.webcodecs, "openCodec");
    return impl.openCodec(browser, config, output);
}

pub inline fn codecInput(codec: *Codec, chunk: *const EncodedChunk, reply: Reply(Unit)) void {
    comptime gate(.webcodecs, "codecInput");
    return impl.codecInput(codec, chunk, reply);
}

pub inline fn codecFlush(codec: *Codec, reply: Reply(Unit)) void {
    comptime gate(.webcodecs, "codecFlush");
    return impl.codecFlush(codec, reply);
}

pub inline fn closeCodec(codec: *Codec) void {
    comptime gate(.webcodecs, "closeCodec");
    return impl.closeCodec(codec);
}

/// requestMediaKeySystemAccess's request.
pub const KeySystemRequest = extern struct {
    key_system: Str,
    init_data_types: StrList = .{},
    content_types: StrList = .{},
};

pub const KeySystemAccess = extern struct {
    key_system: Str,
};

pub const KeySessionType = enum(u8) { temporary, persistent_license };

pub const KeySessionId = extern struct {
    id: u64,
};

/// Encrypted Media Extensions; messages arrive as `key_session_message`.
pub inline fn requestKeySystemAccess(browser: *BrowserPlatform, requester: *const Requester, request: *const KeySystemRequest, reply: Reply(KeySystemAccess)) void {
    comptime gate(.encrypted_media, "requestKeySystemAccess");
    return impl.requestKeySystemAccess(browser, requester, request, reply);
}

pub inline fn createKeySession(browser: *BrowserPlatform, key_system: Str, session_type: KeySessionType, reply: Reply(KeySessionId)) void {
    comptime gate(.encrypted_media, "createKeySession");
    return impl.createKeySession(browser, key_system, session_type, reply);
}

pub inline fn keySessionGenerateRequest(browser: *BrowserPlatform, session: KeySessionId, init_data_type: Str, init_data: Bytes, reply: Reply(Unit)) void {
    comptime gate(.encrypted_media, "keySessionGenerateRequest");
    return impl.keySessionGenerateRequest(browser, session, init_data_type, init_data, reply);
}

pub inline fn keySessionUpdate(browser: *BrowserPlatform, session: KeySessionId, response: Bytes, reply: Reply(Unit)) void {
    comptime gate(.encrypted_media, "keySessionUpdate");
    return impl.keySessionUpdate(browser, session, response, reply);
}

pub inline fn closeKeySession(browser: *BrowserPlatform, session: KeySessionId, reply: Reply(Unit)) void {
    comptime gate(.encrypted_media, "closeKeySession");
    return impl.closeKeySession(browser, session, reply);
}

pub const MediaDeviceKind = enum(u8) { audioinput, audiooutput, videoinput };

/// A device as the platform names it: raw id and label. Crane salts and
/// hashes ids per origin and applies "device information exposure".
pub const MediaDeviceInfo = extern struct {
    kind: MediaDeviceKind,
    device_id: Str,
    group_id: Str = .{},
    label: Str = .{},
};

pub const MediaDeviceList = extern struct {
    ptr: [*]const MediaDeviceInfo,
    len: usize,
};

/// A chooser's answer: a device, or none.
pub const MediaDeviceChoice = extern struct {
    chosen: bool,
    device: MediaDeviceInfo,
};

pub const CaptureKind = enum(u8) { video, audio };

/// Constraints the platform applies (Media Capture and Streams); 0 = none.
pub const CaptureConstraints = extern struct {
    width: u32 = 0,
    height: u32 = 0,
    frame_rate: f64 = 0,
    sample_rate: u32 = 0,
    channel_count: u32 = 0,
    facing_mode: Str = .{},
};

pub const CaptureRequest = extern struct {
    kind: CaptureKind,
    /// Empty: the default device.
    device_id: Str = .{},
    constraints: CaptureConstraints = .{},
};

pub const CaptureOpened = extern struct {
    source: *CaptureSource,
    device: MediaDeviceInfo,
};

pub const TrackSettings = extern struct {
    width: u32 = 0,
    height: u32 = 0,
    frame_rate: f64 = 0,
    sample_rate: u32 = 0,
    channel_count: u32 = 0,
    device_id: Str = .{},
};

pub const TrackCapabilities = extern struct {
    max_width: u32 = 0,
    max_height: u32 = 0,
    max_frame_rate: f64 = 0,
    sample_rates: StrList = .{},
};

pub const ConstraintResult = extern struct {
    satisfied: bool,
    /// The constraint that could not be met, if any.
    failed_constraint: Str = .{},
};

/// A captured frame or audio buffer, BORROWED for the call.
pub const CapturedFrame = extern struct {
    kind: CaptureKind,
    timestamp_us: i64,
    data: Bytes,
    width: u32 = 0,
    height: u32 = 0,
};

/// Frames to Crane, from any thread.
pub const FrameSink = extern struct {
    context: ?*anyopaque,
    frame: *const fn (context: ?*anyopaque, frame: *const CapturedFrame) callconv(.c) void,
};

/// Raw ids and labels; enumerateDevices().
pub inline fn enumerateMediaDevices(browser: *BrowserPlatform, requester: *const Requester, reply: Reply(MediaDeviceList)) void {
    comptime gateAny(&.{ .camera, .microphone }, "enumerateMediaDevices");
    return impl.enumerateMediaDevices(browser, requester, reply);
}

/// getUserMedia's source. OWNED from delivery until `closeCaptureSource`.
pub inline fn openCaptureSource(browser: *BrowserPlatform, requester: *const Requester, request: *const CaptureRequest, reply: Reply(CaptureOpened)) void {
    comptime gateAny(&.{ .camera, .microphone }, "openCaptureSource");
    return impl.openCaptureSource(browser, requester, request, reply);
}

pub inline fn captureSettings(source: *CaptureSource) TrackSettings {
    comptime gateAny(&.{ .camera, .microphone }, "captureSettings");
    return impl.captureSettings(source);
}

pub inline fn captureCapabilities(source: *CaptureSource) TrackCapabilities {
    comptime gateAny(&.{ .camera, .microphone }, "captureCapabilities");
    return impl.captureCapabilities(source);
}

pub inline fn applyCaptureConstraints(source: *CaptureSource, constraints: *const CaptureConstraints, reply: Reply(ConstraintResult)) void {
    comptime gateAny(&.{ .camera, .microphone }, "applyCaptureConstraints");
    return impl.applyCaptureConstraints(source, constraints, reply);
}

pub inline fn setCaptureSink(source: *CaptureSource, sink: FrameSink) void {
    comptime gateAny(&.{ .camera, .microphone }, "setCaptureSink");
    return impl.setCaptureSink(source, sink);
}

pub inline fn closeCaptureSource(source: *CaptureSource) void {
    comptime gateAny(&.{ .camera, .microphone }, "closeCaptureSource");
    return impl.closeCaptureSource(source);
}

pub const DisplayMediaOptions = extern struct {
    video: bool = true,
    audio: bool = false,
};

/// getDisplayMedia.
pub inline fn chooseDisplaySurface(browser: *BrowserPlatform, requester: *const Requester, options: *const DisplayMediaOptions, reply: Reply(CaptureOpened)) void {
    comptime gate(.screen_capture, "chooseDisplaySurface");
    return impl.chooseDisplaySurface(browser, requester, options, reply);
}

pub const AudioSampleFormat = enum(u8) { f32, s16 };

pub const AudioFormat = extern struct {
    sample_rate: u32,
    channels: u32,
    sample_format: AudioSampleFormat = .f32,
};

/// An output stream; `device_id` null: the default. OWNED until
/// `closeAudioOutput`.
pub inline fn openAudioOutput(browser: *BrowserPlatform, requester: *const Requester, format: *const AudioFormat, device_id: ?Str) Error!*AudioOutput {
    comptime gate(.audio_output, "openAudioOutput");
    return impl.openAudioOutput(browser, requester, format, device_id);
}

/// Bytes of interleaved frames accepted.
pub inline fn writeAudio(output: *AudioOutput, frames: Bytes) usize {
    comptime gate(.audio_output, "writeAudio");
    return impl.writeAudio(output, frames);
}

/// Seconds.
pub inline fn audioOutputLatency(output: *AudioOutput) f64 {
    comptime gate(.audio_output, "audioOutputLatency");
    return impl.audioOutputLatency(output);
}

pub inline fn closeAudioOutput(output: *AudioOutput) void {
    comptime gate(.audio_output, "closeAudioOutput");
    return impl.closeAudioOutput(output);
}

/// Audio Output Devices' selectAudioOutput.
pub inline fn selectAudioOutput(browser: *BrowserPlatform, requester: *const Requester, reply: Reply(MediaDeviceChoice)) void {
    comptime gate(.audio_output, "selectAudioOutput");
    return impl.selectAudioOutput(browser, requester, reply);
}

/// A SpeechSynthesisVoice. Strings OWNED by the allocator `speechVoices` took.
pub const Voice = extern struct {
    voice_uri: Str,
    name: Str,
    lang: Str,
    local_service: bool,
    default: bool,
};

pub const Utterance = extern struct {
    text: Str,
    lang: Str = .{},
    voice_uri: Str = .{},
    volume: f32 = 1,
    rate: f32 = 1,
    pitch: f32 = 1,
};

pub const SpeechEndKind = enum(u8) { ended, canceled, interrupted, failed };

pub const SpeechEnd = extern struct {
    kind: SpeechEndKind,
    /// SpeechSynthesisErrorCode when `failed`.
    error_code: Str = .{},
};

pub inline fn speechVoices(browser: *BrowserPlatform, allocator: std.mem.Allocator) Error![]Voice {
    comptime gate(.speech_synthesis, "speechVoices");
    return impl.speechVoices(browser, allocator);
}

pub inline fn speak(browser: *BrowserPlatform, requester: *const Requester, utterance: *const Utterance, reply: Reply(SpeechEnd)) void {
    comptime gate(.speech_synthesis, "speak");
    return impl.speak(browser, requester, utterance, reply);
}

pub inline fn pauseSpeech(browser: *BrowserPlatform) void {
    comptime gate(.speech_synthesis, "pauseSpeech");
    return impl.pauseSpeech(browser);
}

pub inline fn resumeSpeech(browser: *BrowserPlatform) void {
    comptime gate(.speech_synthesis, "resumeSpeech");
    return impl.resumeSpeech(browser);
}

pub inline fn cancelSpeech(browser: *BrowserPlatform) void {
    comptime gate(.speech_synthesis, "cancelSpeech");
    return impl.cancelSpeech(browser);
}

pub const RecognitionOptions = extern struct {
    lang: Str = .{},
    continuous: bool = false,
    interim_results: bool = false,
    max_alternatives: u32 = 1,
};

pub const RecognitionId = extern struct {
    id: u64,
};

/// Results arrive as `speech_event`s.
pub inline fn startRecognition(browser: *BrowserPlatform, requester: *const Requester, options: *const RecognitionOptions) Error!RecognitionId {
    comptime gate(.speech_recognition, "startRecognition");
    return impl.startRecognition(browser, requester, options);
}

pub inline fn stopRecognition(browser: *BrowserPlatform, id: RecognitionId) void {
    comptime gate(.speech_recognition, "stopRecognition");
    return impl.stopRecognition(browser, id);
}

pub const MediaSessionPlaybackState = enum(u8) { none, paused, playing };

pub const MediaSessionState = extern struct {
    title: Str = .{},
    artist: Str = .{},
    album: Str = .{},
    playback_state: MediaSessionPlaybackState = .none,
    /// The actions with handlers ("play", "pause", ...).
    actions: StrList = .{},
};

pub inline fn setMediaSession(browser: *BrowserPlatform, tab: TabId, state: *const MediaSessionState) void {
    comptime gate(.media_session, "setMediaSession");
    return impl.setMediaSession(browser, tab, state);
}

pub const PictureInPictureWindow = extern struct {
    width: u32,
    height: u32,
};

pub inline fn enterPictureInPicture(browser: *BrowserPlatform, requester: *const Requester, reply: Reply(PictureInPictureWindow)) void {
    comptime gate(.picture_in_picture, "enterPictureInPicture");
    return impl.enterPictureInPicture(browser, requester, reply);
}

pub inline fn exitPictureInPicture(browser: *BrowserPlatform, tab: TabId, reply: Reply(Unit)) void {
    comptime gate(.picture_in_picture, "exitPictureInPicture");
    return impl.exitPictureInPicture(browser, tab, reply);
}

pub const PresentationConnection = extern struct {
    id: u64,
    url: Str,
};

pub const Availability = extern struct {
    available: bool,
};

pub inline fn startPresentation(browser: *BrowserPlatform, requester: *const Requester, urls: StrList, reply: Reply(PresentationConnection)) void {
    comptime gate(.presentation, "startPresentation");
    return impl.startPresentation(browser, requester, urls, reply);
}

pub inline fn watchRemotePlaybackAvailability(browser: *BrowserPlatform, requester: *const Requester, media_url: Str, reply: Reply(Availability)) void {
    comptime gate(.remote_playback, "watchRemotePlaybackAvailability");
    return impl.watchRemotePlaybackAvailability(browser, requester, media_url, reply);
}

// ---- 6.10.6 Clipboard [clipboard] (decision 8) ----

pub const ClipboardRepresentation = extern struct {
    mime_type: Str,
    data: Bytes,
};

pub const ClipboardEntry = extern struct {
    ptr: [*]const ClipboardRepresentation,
    len: usize,
};

/// BORROWED for the call (and for `deliver`).
pub const ClipboardItems = extern struct {
    ptr: [*]const ClipboardEntry,
    len: usize,
};

/// read()/readText() and a paste. The Async Clipboard API's permission rules
/// are Crane's, above.
pub inline fn readClipboard(browser: *BrowserPlatform, requester: *const Requester, types: []const Str, reply: Reply(ClipboardItems)) void {
    comptime gate(.clipboard, "readClipboard");
    return impl.readClipboard(browser, requester, types, reply);
}

/// write()/writeText() and execCommand copy/cut.
pub inline fn writeClipboard(browser: *BrowserPlatform, requester: *const Requester, items: *const ClipboardItems, reply: Reply(Unit)) void {
    comptime gate(.clipboard, "writeClipboard");
    return impl.writeClipboard(browser, requester, items, reply);
}

// ---- 6.10.7 Notifications, push and background work ----

pub const NotificationId = extern struct {
    id: u64,
};

pub const NotificationData = extern struct {
    id: NotificationId,
    title: Str,
    body: Str = .{},
    tag: Str = .{},
    icon_url: Str = .{},
    silent: bool = false,
    require_interaction: bool = false,
    actions: StrList = .{},
};

/// Notifications 2.6; clicks and closes arrive as `notification_event`s.
/// Delivers whether it was shown.
pub inline fn showNotification(browser: *BrowserPlatform, requester: *const Requester, notification: *const NotificationData, reply: Reply(bool)) void {
    comptime gate(.notifications, "showNotification");
    return impl.showNotification(browser, requester, notification, reply);
}

pub inline fn closeNotification(browser: *BrowserPlatform, id: NotificationId) void {
    comptime gate(.notifications, "closeNotification");
    return impl.closeNotification(browser, id);
}

pub inline fn maxNotificationActions(browser: *BrowserPlatform) u32 {
    comptime gate(.notifications, "maxNotificationActions");
    return impl.maxNotificationActions(browser);
}

pub const PushSubscriptionOptions = extern struct {
    user_visible_only: bool = true,
    application_server_key: Bytes = .{},
    /// The service worker registration's scope.
    scope: Str,
};

pub const PushSubscription = extern struct {
    endpoint: Str,
    p256dh: Bytes = .{},
    auth: Bytes = .{},
    expiration_ms: i64 = -1,
};

pub const PushSubscriptionState = extern struct {
    subscribed: bool,
    subscription: PushSubscription,
};

/// Push API; messages arrive as `push_message`s.
pub inline fn pushSubscribe(browser: *BrowserPlatform, requester: *const Requester, options: *const PushSubscriptionOptions, reply: Reply(PushSubscription)) void {
    comptime gate(.push, "pushSubscribe");
    return impl.pushSubscribe(browser, requester, options, reply);
}

pub inline fn pushUnsubscribe(browser: *BrowserPlatform, requester: *const Requester, scope: Str, reply: Reply(bool)) void {
    comptime gate(.push, "pushUnsubscribe");
    return impl.pushUnsubscribe(browser, requester, scope, reply);
}

pub inline fn pushSubscription(browser: *BrowserPlatform, requester: *const Requester, scope: Str, reply: Reply(PushSubscriptionState)) void {
    comptime gate(.push, "pushSubscription");
    return impl.pushSubscription(browser, requester, scope, reply);
}

pub inline fn registerBackgroundSync(browser: *BrowserPlatform, requester: *const Requester, tag: Str, reply: Reply(Unit)) void {
    comptime gate(.background_sync, "registerBackgroundSync");
    return impl.registerBackgroundSync(browser, requester, tag, reply);
}

pub const BackgroundFetchRequest = extern struct {
    id: Str,
    urls: StrList,
    title: Str = .{},
    download_total: u64 = 0,
};

pub inline fn startBackgroundFetch(browser: *BrowserPlatform, requester: *const Requester, request: *const BackgroundFetchRequest, reply: Reply(Unit)) void {
    comptime gate(.background_fetch, "startBackgroundFetch");
    return impl.startBackgroundFetch(browser, requester, request, reply);
}

/// Badging; null clears the badge, 0 shows a flag.
pub inline fn setAppBadge(browser: *BrowserPlatform, requester: *const Requester, value: ?u64) void {
    comptime gate(.badging, "setAppBadge");
    return impl.setAppBadge(browser, requester, value);
}

/// HTML 8.10.1.4.
pub inline fn registerProtocolHandler(browser: *BrowserPlatform, requester: *const Requester, scheme: Str, url: Str) void {
    comptime gate(.protocol_handlers, "registerProtocolHandler");
    return impl.registerProtocolHandler(browser, requester, scheme, url);
}

// ---- 6.10.8 Location, sensors and device state ----

pub const PositionOptions = extern struct {
    enable_high_accuracy: bool = false,
    timeout_ms: u32 = std.math.maxInt(u32),
    maximum_age_ms: u32 = 0,
};

pub const PositionErrorCode = enum(u8) { none, permission_denied, position_unavailable, timeout };

/// A position (GeolocationCoordinates) or its error.
pub const PositionResult = extern struct {
    error_code: PositionErrorCode = .none,
    latitude: f64 = 0,
    longitude: f64 = 0,
    accuracy: f64 = 0,
    /// NaN: not available.
    altitude: f64 = std.math.nan(f64),
    altitude_accuracy: f64 = std.math.nan(f64),
    heading: f64 = std.math.nan(f64),
    speed: f64 = std.math.nan(f64),
    timestamp: WallTime = .{ .ns_since_epoch = 0 },
};

pub const WatchId = extern struct {
    id: u64,
};

pub inline fn currentPosition(browser: *BrowserPlatform, requester: *const Requester, options: *const PositionOptions, reply: Reply(PositionResult)) void {
    comptime gate(.geolocation, "currentPosition");
    return impl.currentPosition(browser, requester, options, reply);
}

/// Positions arrive as `position` events.
pub inline fn watchPosition(browser: *BrowserPlatform, requester: *const Requester, options: *const PositionOptions) Error!WatchId {
    comptime gate(.geolocation, "watchPosition");
    return impl.watchPosition(browser, requester, options);
}

pub inline fn clearWatch(browser: *BrowserPlatform, id: WatchId) void {
    comptime gate(.geolocation, "clearWatch");
    return impl.clearWatch(browser, id);
}

pub const SensorType = enum(u8) { accelerometer, linear_acceleration, gravity, gyroscope, magnetometer, ambient_light, absolute_orientation, relative_orientation, proximity, geolocation };

/// Readings arrive as `sensor_reading` events. OWNED until `stopSensor`.
pub inline fn startSensor(browser: *BrowserPlatform, requester: *const Requester, sensor_type: SensorType, frequency: f64) Error!*SensorHandle {
    comptime gate(.sensors, "startSensor");
    return impl.startSensor(browser, requester, sensor_type, frequency);
}

pub inline fn stopSensor(sensor: *SensorHandle) void {
    comptime gate(.sensors, "stopSensor");
    return impl.stopSensor(sensor);
}

/// Readings arrive as `orientation` events.
pub inline fn startDeviceOrientation(browser: *BrowserPlatform, requester: *const Requester) Error!void {
    comptime gate(.device_orientation, "startDeviceOrientation");
    return impl.startDeviceOrientation(browser, requester);
}

pub inline fn stopDeviceOrientation(browser: *BrowserPlatform) void {
    comptime gate(.device_orientation, "stopDeviceOrientation");
    return impl.stopDeviceOrientation(browser);
}

pub const BatteryStatus = extern struct {
    charging: bool = true,
    /// Seconds; +inf: unknown.
    charging_time: f64 = 0,
    discharging_time: f64 = std.math.inf(f64),
    level: f64 = 1.0,
};

/// Changes arrive as `battery_changed`.
pub inline fn batteryStatus(browser: *BrowserPlatform) BatteryStatus {
    comptime gate(.battery, "batteryStatus");
    return impl.batteryStatus(browser);
}

/// Vibration's "perform vibration"; false: no vibration mechanism.
pub inline fn vibrate(browser: *BrowserPlatform, pattern: []const u32) bool {
    comptime gate(.vibration, "vibrate");
    return impl.vibrate(browser, pattern);
}

pub const ConnectionType = enum(u8) { unknown, bluetooth, cellular, ethernet, none, wifi, wimax, other };

pub const ConnectionInfo = extern struct {
    connection_type: ConnectionType = .unknown,
    effective_type: Str = .{},
    downlink_mbps: f64 = 0,
    rtt_ms: u32 = 0,
    save_data: bool = false,
};

pub inline fn connectionInfo(browser: *BrowserPlatform) ConnectionInfo {
    comptime gate(.network_information, "connectionInfo");
    return impl.connectionInfo(browser);
}

pub const PressureSource = enum(u8) { cpu };

pub const PressureObserverId = extern struct {
    id: u64,
};

/// Readings arrive as `pressure_changed`.
pub inline fn startPressureObserver(browser: *BrowserPlatform, requester: *const Requester, source: PressureSource, sample_interval_ms: u32) Error!PressureObserverId {
    comptime gate(.compute_pressure, "startPressureObserver");
    return impl.startPressureObserver(browser, requester, source, sample_interval_ms);
}

pub inline fn stopPressureObserver(browser: *BrowserPlatform, id: PressureObserverId) void {
    comptime gate(.compute_pressure, "stopPressureObserver");
    return impl.stopPressureObserver(browser, id);
}

pub const Posture = enum(u8) { continuous, folded };

pub inline fn devicePosture(browser: *BrowserPlatform) Posture {
    comptime gate(.device_posture, "devicePosture");
    return impl.devicePosture(browser);
}

pub const IdleDetectorId = extern struct {
    id: u64,
};

/// States arrive as `idle_changed`.
pub inline fn startIdleDetection(browser: *BrowserPlatform, requester: *const Requester, threshold_ms: u64) Error!IdleDetectorId {
    comptime gate(.idle_detection, "startIdleDetection");
    return impl.startIdleDetection(browser, requester, threshold_ms);
}

pub inline fn stopIdleDetection(browser: *BrowserPlatform, id: IdleDetectorId) void {
    comptime gate(.idle_detection, "stopIdleDetection");
    return impl.stopIdleDetection(browser, id);
}

// ---- 6.10.9 Devices [usb, hid, serial, bluetooth, nfc, midi, gamepad] ----

pub const DeviceKind = enum(u8) { usb, hid, serial, bluetooth, nfc, midi };

pub const DeviceId = extern struct {
    id: u64,
};

/// A requestDevice / requestPort filter set: each filter's fields, as
/// key=value strings in the order the page gave them.
pub const DeviceFilters = extern struct {
    filters: StrList = .{},
    exclusion_filters: StrList = .{},
};

pub const DeviceInfo = extern struct {
    id: DeviceId,
    kind: DeviceKind,
    name: Str = .{},
    vendor_id: u16 = 0,
    product_id: u16 = 0,
};

pub const DeviceChoice = extern struct {
    chosen: bool,
    device: DeviceInfo,
};

pub const DeviceList = extern struct {
    ptr: [*]const DeviceInfo,
    len: usize,
};

pub const OpenedDevice = extern struct {
    handle: *DeviceHandle,
};

/// One request shape for every device kind: `operation` names it (a USB
/// control/bulk/interrupt/isochronous transfer, a HID report, a serial
/// read/write/signal, a GATT read/write/notify, an NFC read/write, a MIDI
/// send), with its parameters and data.
pub const DeviceRequest = extern struct {
    operation: Str,
    parameters: StrList = .{},
    data: Bytes = .{},
    length: u32 = 0,
};

pub const DeviceResponse = extern struct {
    status: Str = .{},
    data: Bytes = .{},
};

pub const GamepadState = extern struct {
    index: u32,
    connected: bool,
    id: [64]u8 = [_]u8{0} ** 64,
    timestamp: Instant = .{ .ns = 0 },
    axes: [8]f64 = [_]f64{0} ** 8,
    axis_count: u32 = 0,
    buttons: [32]f64 = [_]f64{0} ** 32,
    button_count: u32 = 0,
};

/// The chooser: requestDevice / requestPort / Bluetooth requestDevice.
pub inline fn chooseDevice(browser: *BrowserPlatform, requester: *const Requester, kind: DeviceKind, filters: *const DeviceFilters, reply: Reply(DeviceChoice)) void {
    comptime gateAny(&.{ .usb, .hid, .serial, .bluetooth, .nfc, .midi }, "chooseDevice");
    return impl.chooseDevice(browser, requester, kind, filters, reply);
}

/// getDevices() / getPorts().
pub inline fn grantedDevices(browser: *BrowserPlatform, requester: *const Requester, kind: DeviceKind, reply: Reply(DeviceList)) void {
    comptime gateAny(&.{ .usb, .hid, .serial, .bluetooth, .nfc, .midi }, "grantedDevices");
    return impl.grantedDevices(browser, requester, kind, reply);
}

/// OWNED from delivery until `closeDevice`.
pub inline fn openDevice(browser: *BrowserPlatform, device: DeviceId, reply: Reply(OpenedDevice)) void {
    comptime gateAny(&.{ .usb, .hid, .serial, .bluetooth, .nfc, .midi }, "openDevice");
    return impl.openDevice(browser, device, reply);
}

pub inline fn closeDevice(handle: *DeviceHandle) void {
    comptime gateAny(&.{ .usb, .hid, .serial, .bluetooth, .nfc, .midi }, "closeDevice");
    return impl.closeDevice(handle);
}

/// Input (reports, notifications, readings, messages, disconnects) arrives as
/// `device_event`s.
pub inline fn deviceRequest(handle: *DeviceHandle, request: *const DeviceRequest, reply: Reply(DeviceResponse)) void {
    comptime gateAny(&.{ .usb, .hid, .serial, .bluetooth, .nfc, .midi }, "deviceRequest");
    return impl.deviceRequest(handle, request, reply);
}

/// Gamepad API snapshot into `out`; the count written.
pub inline fn gamepads(browser: *BrowserPlatform, out: []GamepadState) usize {
    comptime gate(.gamepad, "gamepads");
    return impl.gamepads(browser, out);
}

// ---- 6.10.10 Payments, credentials, sharing, input and UI ----

pub const PaymentId = extern struct {
    id: u64,
};

/// A PaymentRequest, its method data and details serialized as JSON.
pub const PaymentRequestData = extern struct {
    id: PaymentId,
    method_data_json: Str,
    details_json: Str,
    options_json: Str = .{},
};

pub const PaymentResponse = extern struct {
    method_name: Str,
    details_json: Str,
};

pub const PaymentComplete = enum(u8) { unknown, success, fail };

pub inline fn canMakePayment(browser: *BrowserPlatform, requester: *const Requester, request: *const PaymentRequestData, reply: Reply(bool)) void {
    comptime gate(.payment, "canMakePayment");
    return impl.canMakePayment(browser, requester, request, reply);
}

pub inline fn showPayment(browser: *BrowserPlatform, requester: *const Requester, request: *const PaymentRequestData, reply: Reply(PaymentResponse)) void {
    comptime gate(.payment, "showPayment");
    return impl.showPayment(browser, requester, request, reply);
}

pub inline fn completePayment(browser: *BrowserPlatform, id: PaymentId, result: PaymentComplete, reply: Reply(Unit)) void {
    comptime gate(.payment, "completePayment");
    return impl.completePayment(browser, id, result, reply);
}

pub inline fn abortPayment(browser: *BrowserPlatform, id: PaymentId, reply: Reply(bool)) void {
    comptime gate(.payment, "abortPayment");
    return impl.abortPayment(browser, id, reply);
}

/// WebAuthn options and results, as their JSON serializations
/// (PublicKeyCredential's toJSON / parse*OptionsFromJSON shapes).
pub const CredentialOptions = extern struct {
    options_json: Str,
};

pub const CredentialResult = extern struct {
    credential_json: Str,
};

pub inline fn createCredential(browser: *BrowserPlatform, requester: *const Requester, options: *const CredentialOptions, reply: Reply(CredentialResult)) void {
    comptime gate(.webauthn, "createCredential");
    return impl.createCredential(browser, requester, options, reply);
}

pub inline fn getCredential(browser: *BrowserPlatform, requester: *const Requester, options: *const CredentialOptions, reply: Reply(CredentialResult)) void {
    comptime gate(.webauthn, "getCredential");
    return impl.getCredential(browser, requester, options, reply);
}

pub inline fn platformAuthenticatorAvailable(browser: *BrowserPlatform, reply: Reply(bool)) void {
    comptime gate(.webauthn, "platformAuthenticatorAvailable");
    return impl.platformAuthenticatorAvailable(browser, reply);
}

/// FedCM / Digital Credentials request and token, as JSON.
pub const IdentityRequest = extern struct {
    request_json: Str,
};

pub const IdentityCredential = extern struct {
    token: Str,
};

pub inline fn requestIdentityCredential(browser: *BrowserPlatform, requester: *const Requester, request: *const IdentityRequest, reply: Reply(IdentityCredential)) void {
    comptime gate(.identity_credentials, "requestIdentityCredential");
    return impl.requestIdentityCredential(browser, requester, request, reply);
}

/// Web Share data; files as picked-file tokens.
pub const ShareData = extern struct {
    title: Str = .{},
    text: Str = .{},
    url: Str = .{},
    file_count: u32 = 0,
};

pub inline fn canShare(browser: *BrowserPlatform, data: *const ShareData) bool {
    comptime gate(.share, "canShare");
    return impl.canShare(browser, data);
}

pub inline fn share(browser: *BrowserPlatform, requester: *const Requester, data: *const ShareData, reply: Reply(bool)) void {
    comptime gate(.share, "share");
    return impl.share(browser, requester, data, reply);
}

pub const ContactPropertyList = extern struct {
    /// "address", "email", "icon", "name", "tel".
    properties: StrList,
};

pub const ContactsRequest = extern struct {
    properties: StrList,
    multiple: bool = false,
};

/// The selected contacts as JSON (ContactInfo dictionaries).
pub const ContactList = extern struct {
    contacts_json: Str,
};

pub inline fn contactProperties(browser: *BrowserPlatform, reply: Reply(ContactPropertyList)) void {
    comptime gate(.contacts, "contactProperties");
    return impl.contactProperties(browser, reply);
}

pub inline fn selectContacts(browser: *BrowserPlatform, requester: *const Requester, request: *const ContactsRequest, reply: Reply(ContactList)) void {
    comptime gate(.contacts, "selectContacts");
    return impl.selectContacts(browser, requester, request, reply);
}

/// Fullscreen API: whether the tab went fullscreen.
pub inline fn requestFullscreen(browser: *BrowserPlatform, requester: *const Requester, tab: TabId, reply: Reply(bool)) void {
    comptime gate(.fullscreen, "requestFullscreen");
    return impl.requestFullscreen(browser, requester, tab, reply);
}

pub inline fn exitFullscreen(browser: *BrowserPlatform, tab: TabId) void {
    comptime gate(.fullscreen, "exitFullscreen");
    return impl.exitFullscreen(browser, tab);
}

pub inline fn requestPointerLock(browser: *BrowserPlatform, requester: *const Requester, reply: Reply(bool)) void {
    comptime gate(.pointer_lock, "requestPointerLock");
    return impl.requestPointerLock(browser, requester, reply);
}

pub inline fn exitPointerLock(browser: *BrowserPlatform, tab: TabId) void {
    comptime gate(.pointer_lock, "exitPointerLock");
    return impl.exitPointerLock(browser, tab);
}

/// Keyboard Lock; `keys` empty: every key.
pub inline fn lockKeys(browser: *BrowserPlatform, requester: *const Requester, keys: StrList, reply: Reply(Unit)) void {
    comptime gate(.keyboard_lock, "lockKeys");
    return impl.lockKeys(browser, requester, keys, reply);
}

pub inline fn unlockKeys(browser: *BrowserPlatform, tab: TabId) void {
    comptime gate(.keyboard_lock, "unlockKeys");
    return impl.unlockKeys(browser, tab);
}

pub const KeyboardMapEntry = extern struct {
    code: Str,
    key: Str,
};

pub const KeyboardMap = extern struct {
    ptr: [*]const KeyboardMapEntry,
    len: usize,
};

pub inline fn keyboardLayoutMap(browser: *BrowserPlatform, reply: Reply(KeyboardMap)) void {
    comptime gate(.keyboard_map, "keyboardLayoutMap");
    return impl.keyboardLayoutMap(browser, reply);
}

pub const WakeLockType = enum(u8) { screen };

pub const WakeLockId = extern struct {
    id: u64,
};

/// Screen Wake Lock.
pub inline fn requestWakeLock(browser: *BrowserPlatform, requester: *const Requester, kind: WakeLockType, reply: Reply(WakeLockId)) void {
    comptime gate(.wake_lock, "requestWakeLock");
    return impl.requestWakeLock(browser, requester, kind, reply);
}

pub inline fn releaseWakeLock(browser: *BrowserPlatform, id: WakeLockId) void {
    comptime gate(.wake_lock, "releaseWakeLock");
    return impl.releaseWakeLock(browser, id);
}

pub const EyeDropperResult = extern struct {
    /// sRGBHex, "#rrggbb".
    srgb_hex: [8]u8,
};

pub inline fn openEyeDropper(browser: *BrowserPlatform, requester: *const Requester, reply: Reply(EyeDropperResult)) void {
    comptime gate(.eyedropper, "openEyeDropper");
    return impl.openEyeDropper(browser, requester, reply);
}

pub const FontData = extern struct {
    postscript_name: Str,
    full_name: Str,
    family: Str,
    style: Str,
};

pub const FontList = extern struct {
    ptr: [*]const FontData,
    len: usize,
};

/// Local Font Access.
pub inline fn queryLocalFonts(browser: *BrowserPlatform, requester: *const Requester, reply: Reply(FontList)) void {
    comptime gate(.local_fonts, "queryLocalFonts");
    return impl.queryLocalFonts(browser, requester, reply);
}

/// VirtualKeyboard; geometry arrives as `virtual_keyboard_geometry`.
pub inline fn showVirtualKeyboard(browser: *BrowserPlatform, tab: TabId) void {
    comptime gate(.virtual_keyboard, "showVirtualKeyboard");
    return impl.showVirtualKeyboard(browser, tab);
}

pub inline fn hideVirtualKeyboard(browser: *BrowserPlatform, tab: TabId) void {
    comptime gate(.virtual_keyboard, "hideVirtualKeyboard");
    return impl.hideVirtualKeyboard(browser, tab);
}

// ============================================================================
// 7. Platform events
// ============================================================================

pub const PlatformEventKind = enum(u16) {
    screen_changed,
    online_changed,
    languages_changed,
    preferences_changed,
    visibility_changed,
    memory_pressure,
    permission_changed,
    media_devices_changed,
    capture_ended,
    capture_muted,
    notification_event,
    push_message,
    position,
    sensor_reading,
    orientation,
    device_event,
    gamepad_connected,
    battery_changed,
    idle_changed,
    pressure_changed,
    connection_changed,
    key_session_message,
    speech_event,
    virtual_keyboard_geometry,
    window_rect_changed,
};

pub const MemoryPressureLevel = enum(u8) { normal, warning, critical };

pub const NotificationAction = enum(u8) { click, close };

/// What the platform reports unasked. `kind` says which fields are set; the
/// rest are zero. BORROWED for `EventSink.post`.
pub const PlatformEvent = extern struct {
    kind: PlatformEventKind,
    tab: TabId = 0,
    /// online_changed, capture_muted, gamepad_connected: the new value.
    flag: bool = false,
    screen: ScreenInfo = std.mem.zeroes(ScreenInfo),
    preferences: UserPreferences = .{},
    visibility: Visibility = .visible,
    memory_pressure: MemoryPressureLevel = .normal,
    /// permission_changed.
    permission: PermissionDescriptor = .{ .name = .other },
    origin: Str = .{},
    top_level_origin: Str = .{},
    permission_state: PermissionState = .prompt,
    /// capture_ended, capture_muted.
    capture_source: ?*CaptureSource = null,
    /// notification_event.
    notification: NotificationId = .{ .id = 0 },
    notification_action: NotificationAction = .click,
    /// position.
    watch: WatchId = .{ .id = 0 },
    position: PositionResult = .{},
    /// sensor_reading.
    sensor: ?*SensorHandle = null,
    /// device_event.
    device: ?*DeviceHandle = null,
    /// gamepad_connected.
    index: u32 = 0,
    /// window_rect_changed, virtual_keyboard_geometry.
    rect: Rect = .{},
    /// Readings, messages and payloads (sensor values, push data, key session
    /// messages, speech results, device input), BORROWED.
    data: Bytes = .{},
    /// A label for `data` (the event type of a device event, a speech event's
    /// name, a key session's message type).
    detail: Str = .{},
};

/// Crane's receiver for platform events, given to `createBrowserPlatform`.
pub const EventSink = extern struct {
    context: ?*anyopaque,
    /// Any thread. The event is BORROWED for the call; Crane copies it and
    /// queues the steps on the event loops that need it. Never runs script
    /// inside.
    post: *const fn (context: ?*anyopaque, event: *const PlatformEvent) callconv(.c) void,
};

// ============================================================================
// TRANSITIONAL: today's backends, re-exported so their callers keep importing
// `@import("platform")` while the protocol replaces them (the integrator's
// ruling for step 0, 2026-10-09). None of these is part of the contract: each
// goes with the recipes step named beside it. lint-platform counts every use
// as `platform.<name>` against its baseline, so today's callers are allowed
// and a new one fails. They are std-only except timer_backend, which reads the
// `clock` bridge - the facade's one import beyond its leaf set, until it goes.
// ============================================================================

/// Recipes step 7 (media decoding moves into the platform).
pub const media_backend = @import("media_backend.zig");
/// Recipes step 7.
pub const media_adapter = @import("media_adapter.zig");
/// Recipes step 2c (the event loop's wait), or step 6 as dead code.
pub const timer_backend = @import("timer_backend.zig");
/// Recipes step 11 (the clipboard).
pub const clipboard_backend = @import("clipboard_backend.zig");
pub const ClipboardBackend = clipboard_backend.ClipboardBackend;
pub const StubClipboardBackend = clipboard_backend.StubClipboardBackend;
pub const DeniedClipboardBackend = clipboard_backend.DeniedClipboardBackend;
pub const ClipboardFormat = clipboard_backend.ClipboardFormat;
pub const ClipboardItem = clipboard_backend.ClipboardItem;
pub const ClipboardResult = clipboard_backend.ClipboardResult;

/// Step 0's own dead-code deletion (decision 15).
pub const platform_backend = @import("platform_backend.zig");
pub const PlatformBackend = platform_backend.PlatformBackend;
pub const vtables = @import("vtables.zig");
pub const exports = @import("exports.zig");
pub const stub_platform_backend = @import("stub_platform_backend.zig");

// ============================================================================
// The contract, checked
// ============================================================================

comptime {
    @setEvalBranchQuota(200_000);
    checkPlatform(impl);
}

/// Every check the contract makes of a platform's `protocol` namespace: each
/// operation declared with exactly its type, and the declarations of contract
/// 1.3. A third-party platform (-Dplatform-module) is held to the same.
fn checkPlatform(comptime platform: type) void {
    const label = "platform `" ++ (if (@hasDecl(platform, "name")) platform.name else "?") ++ "` (platform_impl.protocol)";
    // 1.3: the declarations.
    for ([_][]const u8{ "name", "capabilities", "identity", "PlatformBrowserOptions" }) |required| {
        if (!@hasDecl(platform, required)) @compileError(label ++ " lacks `" ++ required ++ "` (docs/platform-protocol.md 1.3)");
    }
    if (@TypeOf(platform.name) != []const u8 and !isStringLiteral(@TypeOf(platform.name))) @compileError(label ++ ": `name` must be a []const u8");
    if (@TypeOf(platform.capabilities) != Capabilities) @compileError(label ++ ": `capabilities` must be a platform.Capabilities");
    if (@TypeOf(platform.identity) != Identity) @compileError(label ++ ": `identity` must be a platform.Identity");
    checkBrowserOptions(label, platform.PlatformBrowserOptions);
    // Every public inline function here is an operation.
    const protocol = @This();
    for (@typeInfo(protocol).@"struct".decls) |decl| {
        const expected = switch (@typeInfo(@TypeOf(@field(protocol, decl.name)))) {
            .@"fn" => |f| f,
            else => continue,
        };
        if (expected.calling_convention != .@"inline") continue;
        switch (conformance(platform, decl.name, expected)) {
            .matches => {},
            .missing => @compileError(label ++ " lacks protocol operation `" ++ decl.name ++ "`"),
            .not_a_function => @compileError(label ++ ": `" ++ decl.name ++ "` is not a function"),
            .mistyped => @compileError(label ++ ": `" ++ decl.name ++ "` is " ++
                @typeName(@TypeOf(@field(platform, decl.name))) ++ "; the protocol's signature is " ++ signatureText(expected)),
        }
        // In a test build, compile the implementation's function whole: a stub
        // nothing calls still has to type-check.
        if (@import("builtin").is_test) _ = &@field(platform, decl.name);
    }
}

fn isStringLiteral(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .pointer => |p| p.size == .one and @typeInfo(p.child) == .array and @typeInfo(p.child).array.child == u8,
        else => false,
    };
}

/// PlatformBrowserOptions: an extern struct whose every field has a default,
/// so `.{}` is valid.
fn checkBrowserOptions(comptime label: []const u8, comptime T: type) void {
    const info = switch (@typeInfo(T)) {
        .@"struct" => |s| s,
        else => @compileError(label ++ ": `PlatformBrowserOptions` must be an extern struct"),
    };
    if (info.layout != .@"extern") @compileError(label ++ ": `PlatformBrowserOptions` must be an extern struct (C-representable, contract 1.4)");
    for (info.fields) |field| {
        if (field.default_value_ptr == null) @compileError(label ++ ": `PlatformBrowserOptions." ++ field.name ++ "` needs a default, so `.{}` is valid");
    }
}

/// How a platform's declaration of one operation compares with the
/// protocol's. A function the comptime check and tests/platform share, so the
/// comparison itself is unit-tested (a compile error cannot be a test's
/// expected outcome).
pub const Conformance = enum { matches, missing, not_a_function, mistyped };

/// Compare `platform`'s declaration `operation` with the protocol's type
/// `expected`: exactly the same parameter and return types, not generic.
pub fn conformance(comptime platform: type, comptime operation: []const u8, comptime expected: std.builtin.Type.Fn) Conformance {
    if (!@hasDecl(platform, operation)) return .missing;
    const actual = switch (@typeInfo(@TypeOf(@field(platform, operation)))) {
        .@"fn" => |f| f,
        else => return .not_a_function,
    };
    if (actual.is_generic or actual.return_type != expected.return_type or actual.params.len != expected.params.len) return .mistyped;
    for (actual.params, expected.params) |a, e| {
        if (a.type != e.type) return .mistyped;
    }
    return .matches;
}

fn signatureText(comptime f: std.builtin.Type.Fn) []const u8 {
    var text: []const u8 = "fn (";
    for (f.params, 0..) |p, i| text = text ++ (if (i == 0) "" else ", ") ++ @typeName(p.type.?);
    return text ++ ") " ++ @typeName(f.return_type.?);
}
