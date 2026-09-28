//! Browser - Single V8 Isolate Browser Implementation
//!
//! This module implements a browser abstraction that maintains a single V8 isolate
//! for its entire lifetime, creating new V8 contexts per navigation. This is more
//! efficient than creating/destroying isolates per page.
//!
//! ## Architecture
//!
//! ```
//! Browser (single isolate)
//!     └── Context (per navigation)
//!             ├── Window globals
//!             ├── Document
//!             └── WebIDL bindings
//! ```
//!
//! ## Snapshot Support
//!
//! For fast startup, the browser can use V8 heap snapshots containing pre-registered
//! WebIDL interfaces. When a snapshot is available:
//! - Isolate is created from snapshot (~2ms vs ~40ms fresh)
//! - Contexts skip interface registration (already in snapshot)
//!
//! Generate a snapshot:
//! ```bash
//! zig build snapshot-generator -- whatwg_snapshot.bin
//! ```
//!
//! ## Usage
//!
//! ```zig
//! const browser = @import("browser");
//!
//! var b = try browser.Browser.init(allocator, .{});
//! defer b.deinit();
//!
//! // Navigate creates new context, preserves storage
//! try b.navigate("http://example.com/test.html");
//!
//! // Execute script in current context
//! const result = try b.evaluateScript("document.title");
//! ```
//!
//! ## Specification References
//!
//! - HTML Standard: Browsing contexts https://html.spec.whatwg.org/multipage/document-sequences.html
//! - HTML Standard: Navigation and session history https://html.spec.whatwg.org/multipage/nav-history-apis.html

const std = @import("std");
const log = std.log.scoped(.browser);
const engine = @import("engine");
const runtime = @import("runtime");
const impls = @import("impls");
const namespaces = @import("namespaces");

const context_mod = @import("Context.zig");
const Context = context_mod.Context;
const storage_mod = @import("storage/Storage.zig");
const cookiestore = @import("cookiestore");
const clock = @import("clock");
const host = @import("host");
const Storage = storage_mod.Storage;
/// The page agent's event loop - the host's (HTML 8.1.7).
const EventLoop = @import("event_loop.zig").EventLoop;

/// Where a snapshot is looked for, first to last. The build's own output
/// comes first: a `whatwg_snapshot.bin` in the current directory - one that
/// was tracked in git from January to September 2026 - won over it, and
/// every run from the repository root restored that stale snapshot against
/// the running build's callback table. A candidate the engine refuses (no
/// build stamp, not a valid blob, another build's external references) is
/// skipped, not taken because it exists.
const DEFAULT_SNAPSHOT_PATHS = [_][]const u8{
    "zig-out/bin/whatwg_snapshot.bin", // Zig build output (highest priority)
    "whatwg_snapshot.bin", // Current directory
    "../whatwg_snapshot.bin", // Parent directory (for tests run from subdirs)
};

/// The first of `candidates` that `usable` accepts, in order, or null.
fn firstUsableSnapshot(
    context: anytype,
    candidates: []const []const u8,
    comptime usable: fn (@TypeOf(context), []const u8) bool,
) ?[]const u8 {
    for (candidates) |path| {
        if (usable(context, path)) return path;
    }
    return null;
}

/// A similar-origin window agent's host hooks: HostPromiseRejectionTracker
/// and "notify about rejected promises" (html/rejected_promises.zig), and
/// HostLoadImportedModule and HostGetImportMetaProperties - import() in a
/// Window realm loads through the document's module map
/// (html/script_execution.zig).
const window_agent_hooks: engine.HostHooks = blk: {
    const html = @import("html");
    var hooks = html.rejected_promises.hooks;
    hooks.loadImportedModule = html.script_execution.module_hooks.loadImportedModule;
    hooks.importMetaUrl = html.script_execution.module_hooks.importMetaUrl;
    break :blk hooks;
};

/// The engine, started with the snapshot of the first candidate it takes
/// (engine.initializeEngine refuses a blob this build cannot restore).
const EngineStart = struct {
    allocator: std.mem.Allocator,
    /// The accepted snapshot's bytes, OWNED by `allocator` and lent to the
    /// engine until deinitializeEngine: V8 deserializes from them lazily.
    snapshot: ?[]u8 = null,

    /// Start the engine with the snapshot at `path`, if it reads and the
    /// engine takes it.
    fn offer(self: *EngineStart, path: []const u8) bool {
        const bytes = readSnapshot(self.allocator, path) orelse return false;
        engine.initializeEngine(.{ .snapshot = bytes }) catch {
            self.allocator.free(bytes);
            return false;
        };
        self.snapshot = bytes;
        return true;
    }
};

/// The file's bytes, or null when it cannot be read. OWNED by `allocator`.
fn readSnapshot(allocator: std.mem.Allocator, path: []const u8) ?[]u8 {
    const io = host.io();
    const file = host.cwd().openFile(io, path, .{}) catch return null;
    defer file.close(io);
    const stat = file.stat(io) catch return null;
    const bytes = allocator.alloc(u8, stat.size) catch return null;
    const read = file.readPositionalAll(io, bytes, 0) catch {
        allocator.free(bytes);
        return null;
    };
    if (read != stat.size) {
        allocator.free(bytes);
        return null;
    }
    return bytes;
}

/// Browser configuration options
pub const BrowserConfig = struct {
    /// Root directory for persistent storage (default: ~/.whatwg/)
    storage_root: ?[]const u8 = null,
    /// Whether to enable storage persistence (default: true)
    persist_storage: bool = true,
    /// Initial URL to navigate to (optional)
    initial_url: ?[]const u8 = null,
    /// Enable debug logging
    debug: bool = false,
    /// Path to V8 snapshot file (optional, auto-detected if null)
    /// Set to empty string "" to explicitly disable snapshot loading
    snapshot_path: ?[]const u8 = null,
    /// Whether to log performance information
    log_performance: bool = false,
};

/// Browser instance managing a single V8 isolate
pub const Browser = struct {
    allocator: std.mem.Allocator,
    /// The page's agent (engine.createAgent) - lives for the entire browser
    /// lifetime.
    agent: ?*engine.Agent,
    /// Current browsing context (V8 context + DOM)
    current_context: ?*Context,
    /// Persistent storage subsystem
    storage: *Storage,
    /// Browser configuration
    config: BrowserConfig,
    /// Whether the browser has been initialized
    initialized: bool,
    /// V8 event loop with timer support
    event_loop: ?*EventLoop,
    /// Whether isolate was created from a snapshot (affects context initialization)
    used_snapshot: bool,
    /// The snapshot the engine made the agent from (EngineStart.snapshot):
    /// freed after the agent is destroyed and the engine has forgotten it.
    snapshot_bytes: ?[]u8 = null,
    /// The user agent's cookie jar: one for every window, frame and worker
    /// this Browser runs. Fetch sends and stores through it, and
    /// document.cookie and cookieStore read and write it; a realm reaches it
    /// through its settings object (dom.global_settings.cookieJarOf).
    ///
    /// SINGLE-THREADED, and unlocked: every realm that reaches it runs on
    /// this Browser's thread - a worker's tasks run as timers on the page's
    /// loop (html/worker_host.zig), and fetch reads and writes the jar from
    /// its algorithms, never from the network layer's callbacks. Whoever
    /// moves a worker, or any fetch step, onto another thread must lock
    /// this jar first.
    cookie_jar: cookiestore.CookieJar,

    /// Initialize a new Browser instance
    ///
    /// Creates a V8 isolate that will be reused across all navigations.
    /// The isolate is only destroyed when the browser is deinitialized.
    ///
    /// If a V8 snapshot is available, uses it for fast isolate startup (~2ms vs ~40ms).
    /// Note: The snapshot contains V8 builtins only. WebIDL interfaces are registered
    /// at runtime on each context creation.
    pub fn init(allocator: std.mem.Allocator, config: BrowserConfig) !*Browser {
        // The network's process-wide state - curl, and the connection pool
        // every fetch shares - held for this Browser's life (`deinit`).
        try @import("fetch").network.globalInit();
        errdefer @import("fetch").network.globalCleanup();

        // Initialize WebIDL runtime (SlabAllocator, ArenaAllocator)
        runtime.initializeRuntime(allocator);
        errdefer runtime.deinitializeRuntime();

        // The engine and the snapshot its agents are made from: the first
        // candidate the engine takes, or none (engine.initializeEngine). On
        // V8 it sets the RUNTIME flags, not the snapshot generator's:
        // `--predictable` and `--hash-seed=0` are generation-time determinism
        // knobs, and applying them here turned off V8's own parallelism,
        // pinned Math.random() to a fixed sequence and removed hash-flooding
        // protection in every browser this code has ever started.
        var start: EngineStart = .{ .allocator = allocator };
        startEngine(&start, config.snapshot_path);
        errdefer if (start.snapshot) |bytes| allocator.free(bytes);
        if (start.snapshot == null) engine.initializeEngine(.{}) catch return error.V8InitFailed;
        errdefer engine.deinitializeEngine();
        const from_snapshot = start.snapshot != null;
        if (config.log_performance) {
            std.log.info("Browser starting {s} a snapshot", .{if (from_snapshot) "from" else "without"});
        }

        // HTML "obtain a similar-origin window agent": [[CanBlock]] false -
        // Atomics.wait() throws a TypeError rather than freezing the page's
        // one thread, as Blink's main thread does; a dedicated worker's agent
        // keeps it - and the host's hooks (window_agent_hooks).
        const agent = engine.createAgent(.{
            .can_block = false,
            .from_snapshot = from_snapshot,
            .hooks = &window_agent_hooks,
            .allocator = allocator,
        }) catch return error.V8InitFailed;

        return initBrowserWithAgent(allocator, agent, from_snapshot, config, start.snapshot);
    }

    /// Complete browser initialization with its agent.
    fn initBrowserWithAgent(
        allocator: std.mem.Allocator,
        agent: *engine.Agent,
        used_snapshot: bool,
        config: BrowserConfig,
        snapshot_bytes: ?[]u8,
    ) !*Browser {
        errdefer engine.destroyAgent(agent);

        // Create storage subsystem
        const storage = try Storage.init(allocator, config.storage_root, config.persist_storage);
        errdefer storage.deinit();

        // The agent's event loop, with its timers (the host's).
        const event_loop = try allocator.create(EventLoop);
        errdefer allocator.destroy(event_loop);
        event_loop.* = try EventLoop.init(agent, allocator);

        // Allocate browser struct
        const browser = try allocator.create(Browser);
        errdefer allocator.destroy(browser);

        browser.* = Browser{
            .allocator = allocator,
            .agent = agent,
            .current_context = null,
            .storage = storage,
            .config = config,
            .initialized = true,
            .event_loop = event_loop,
            .used_snapshot = used_snapshot,
            .snapshot_bytes = snapshot_bytes,
            .cookie_jar = cookiestore.CookieJar.init(allocator),
        };

        // Always create initial about:blank context - a real browser always has a window/document
        // Then navigate to initial URL if specified
        const initial_url = config.initial_url orelse "about:blank";
        try browser.navigate(initial_url, .window);

        return browser;
    }

    /// Start the engine with the configured snapshot, or the first of
    /// DEFAULT_SNAPSHOT_PATHS the engine takes; an empty configured path
    /// means none. `start.snapshot` is null when no snapshot was taken, and
    /// the engine is not started then.
    fn startEngine(start: *EngineStart, config_path: ?[]const u8) void {
        if (config_path) |path| {
            if (path.len > 0) _ = start.offer(path);
            return;
        }
        _ = firstUsableSnapshot(start, &DEFAULT_SNAPSHOT_PATHS, EngineStart.offer);
    }

    /// Deinitialize the browser and release all resources
    ///
    /// This destroys the V8 isolate and all associated contexts.
    /// All storage is flushed to disk before cleanup.
    pub fn deinit(self: *Browser) void {
        // Destroy current context if any
        if (self.current_context) |ctx| {
            ctx.deinit();
            self.allocator.destroy(ctx);
            self.current_context = null;
        }
        // The page's fetches still in flight release what they hold - a
        // promise, and through it the realm - while the isolate lives.
        _ = @import("fetch").algorithms.async_fetch.sweep();
        // Nothing that could reach the jar is left.
        self.cookie_jar.deinit();

        // Flush and cleanup storage
        self.storage.flush() catch {};
        self.storage.deinit();
        self.allocator.destroy(self.storage);

        // Cleanup event loop
        if (self.event_loop) |event_loop| {
            event_loop.deinit();
            self.allocator.destroy(event_loop);
        }

        if (self.agent) |agent| {
            // IMPORTANT: Clean up orphaned DOM nodes BEFORE the agent ends!
            // DOM node internal states may use the agent's allocator, which
            // its end frees. We must clean them up while allocators are valid.
            impls.cleanup.cleanupAllDomRegistries();

            // Release the rejection tracker's promise handles while the
            // agent that owns them still exists.
            @import("html").rejected_promises.releaseTracked();

            // The end of the agent (engine.destroyAgent): its hooks forgotten,
            // the engine's per-isolate and per-thread state torn down in
            // order, its garbage collected, its isolate disposed.
            engine.destroyAgent(agent);

            // Every Window is gone now, so the browsing contexts their
            // containers retired while a Window might still read them
            // (BrowsingContext.discard) can finally be freed.
            @import("html").window.browsing_context.BrowsingContext.freeRetired();

            // The snapshot outlives the isolate - V8 deserializes from it
            // lazily - and the engine forgets it before it is freed.
            engine.deinitializeEngine();
            if (self.snapshot_bytes) |bytes| self.allocator.free(bytes);
        }

        // Cleanup WebIDL runtime
        runtime.deinitializeRuntime();

        // The network ends with the last Browser, once nothing that could
        // hold a transfer is left: the thread's scheduler closes, and so does
        // the connection pool, where curl shuts each connection down - an
        // HTTP/2 one with a GOAWAY. A connection only closed by the process
        // exiting ends with a bare FIN, and WPT's h2 server (:9000) spins a
        // thread forever on each of those.
        @import("fetch").network.scheduler.endIdleThreadScheduler();
        @import("fetch").network.globalCleanup();

        self.initialized = false;
        self.allocator.destroy(self);
    }

    /// Navigation options
    pub const NavigateOptions = struct {
        /// If true, skip loading the page (caller will load manually)
        skip_load: bool = false,
        /// Optional script loader for external scripts during HTML parsing
        script_loader: ?Context.ScriptLoader = null,
    };

    /// Navigate to a URL
    ///
    /// This destroys the current V8 context (if any) and creates a new one.
    /// Storage persists across navigations.
    ///
    /// Navigation flow:
    /// 1. Destroy current V8 context (if any)
    /// 2. Create new V8 context
    /// 3. Register browser globals (skipped if using snapshot)
    /// 4. Fetch URL content via HTTP
    /// 5. Parse HTML and execute scripts
    /// 6. Fire DOMContentLoaded and load events
    pub fn navigate(self: *Browser, url: []const u8, context_type: context_mod.ContextType) !void {
        return self.navigateWithOptions(url, context_type, .{});
    }

    /// Navigate to a URL with options
    pub fn navigateWithOptions(
        self: *Browser,
        url: []const u8,
        context_type: context_mod.ContextType,
        options: NavigateOptions,
    ) !void {
        const agent = self.agent orelse return error.NotInitialized;

        // Destroy current context if any
        if (self.current_context) |old_ctx| {
            old_ctx.deinit();
            self.allocator.destroy(old_ctx);
            self.current_context = null;
            // Fetch's "terminate a fetch group" for the page that ended, now
            // rather than at the next turn's pump.
            _ = @import("fetch").algorithms.async_fetch.sweep();

            // Drain all pending timer close callbacks first
            // When timers are cancelled in Context.deinit(), libuv schedules close callbacks.
            // These MUST be processed before GC can clean up timer-related V8 objects.
            if (self.event_loop) |event_loop| {
                _ = event_loop.drainCloseCallbacks();
            }

            // The page was let go: what it held is garbage now, and the
            // engine collects it before the next page's realm is made
            // (engine.notifyMemoryPressure .critical - on V8, three full
            // collections with checkpoints between). This is critical for
            // sequential test execution to prevent heap growth.
            engine.notifyMemoryPressure(agent, .critical);
        }

        // The URL to navigate to is the parsed URL, serialized: a space in a
        // query - `?timeout set to expiring value` - is percent-encoded
        // there, where curl refuses it raw and the load failed with
        // NetworkError. A string that does not parse is used as given.
        const serialized = serializedUrl(self.allocator, url);
        defer if (serialized) |s| self.allocator.free(s);

        // Create new context
        // Pass used_snapshot flag so Context knows whether to skip initializeBindings
        const ctx = try Context.init(
            self.allocator,
            agent,
            self.storage,
            &self.cookie_jar,
            serialized orelse url,
            self.event_loop,
            context_type,
            self.used_snapshot,
        );
        errdefer {
            ctx.deinit();
            self.allocator.destroy(ctx);
        }

        self.current_context = ctx;

        // Navigation loading is handled by Context.loadPage()
        if (!options.skip_load) {
            try ctx.loadPageWithOptions(.{
                .script_loader = options.script_loader,
            });
        }
    }

    /// `url` parsed with the basic URL parser and serialized; null when it
    /// does not parse. Owned by `allocator`.
    fn serializedUrl(allocator: std.mem.Allocator, url: []const u8) ?[]u8 {
        var record = @import("basic_parser").parse(allocator, url, null) catch return null;
        defer record.deinit();
        return @constCast(@import("url_serializer").serialize(allocator, &record, false) catch return null);
    }

    /// Reload the current page
    ///
    /// Re-navigates to the current URL, destroying and recreating the context.
    pub fn reload(self: *Browser) !void {
        const ctx = self.current_context orelse return error.NoContext;
        const url = try self.allocator.dupe(u8, ctx.url);
        const context_type = ctx.context_type;
        defer self.allocator.free(url);
        try self.navigate(url, context_type);
    }

    /// Evaluate JavaScript in the current context: its completion value,
    /// OWNED - `release` it (Context.evaluateScript).
    pub fn evaluateScript(self: *Browser, script: []const u8) !engine.Owned {
        const ctx = self.current_context orelse return error.NoContext;
        return ctx.evaluateScript(script);
    }

    /// Run the event loop until timeout expires.
    ///
    /// This uses efficient blocking on libuv, waking only when:
    /// - A timer fires
    /// - I/O is ready
    /// - The timeout expires
    ///
    /// @param timeout_ms Maximum time to run the loop.
    /// @return true if work was performed, false if timeout with no work
    pub fn runEventLoop(self: *Browser, timeout_ms: u64) !void {
        _ = try self.runEventLoopBlocking(timeout_ms);
    }

    /// Run the event loop with proper blocking behavior.
    ///
    /// This replaces the old polling + sleep pattern with proper blocking.
    /// The loop blocks efficiently on libuv, waking only when:
    /// - A timer fires
    /// - I/O is ready
    /// - A task is posted from another thread
    /// - The timeout expires
    ///
    /// @param timeout_ms Maximum time to run the loop. Pass 0 for single non-blocking check.
    /// @return true if work was performed, false if timeout with no work
    pub fn runEventLoopBlocking(self: *Browser, timeout_ms: u64) !bool {
        const event_loop = self.event_loop orelse return error.NotInitialized;
        // DEBUG: Log event loop pointer and task count
        log.debug("[Browser.runEventLoopBlocking] event_loop={*}, tasks.len={d}", .{ event_loop, event_loop.tasks.items.len });
        const start_time = clock.monotonicMillis();
        const deadline = start_time + @as(i64, @intCast(timeout_ms));
        var did_work = false;

        while (true) {
            const now = clock.monotonicMillis();
            if (now >= deadline) {
                break;
            }

            const remaining: u64 = @intCast(deadline - now);

            // Run one iteration of the event loop with blocking
            // This will block up to `remaining` ms waiting for work
            if (event_loop.runOnceBlocking(remaining)) {
                did_work = true;
            }

            // If no more pending work, exit early
            if (!event_loop.hasPendingWork()) {
                break;
            }
        }

        return did_work;
    }

    /// Get the current URL
    pub fn getCurrentUrl(self: *Browser) ?[]const u8 {
        const ctx = self.current_context orelse return null;
        return ctx.url;
    }

    /// Check if browser is initialized
    pub fn isInitialized(self: *Browser) bool {
        return self.initialized and self.agent != null;
    }

    /// The page's agent (for advanced usage: engine operations that take one).
    pub fn getAgent(self: *Browser) ?*engine.Agent {
        return self.agent;
    }

    /// The current page's realm (for advanced usage)
    pub fn getRealm(self: *Browser) ?runtime.Context {
        const ctx = self.current_context orelse return null;
        return ctx.realm;
    }

    /// Get the storage subsystem
    pub fn getStorage(self: *Browser) *Storage {
        return self.storage;
    }

    /// Check if the browser was initialized from a V8 snapshot
    ///
    /// Returns true if the browser's isolate was created from a snapshot,
    /// which means interface bindings are pre-registered and context creation
    /// is faster.
    pub fn isUsingSnapshot(self: *Browser) bool {
        return self.used_snapshot;
    }
};

test "the build's own snapshot is looked for first, and a refused candidate is skipped" {
    try std.testing.expectEqualStrings("zig-out/bin/whatwg_snapshot.bin", DEFAULT_SNAPSHOT_PATHS[0]);
    const Only = struct {
        fn accepts(accepted: []const u8, path: []const u8) bool {
            return std.mem.eql(u8, accepted, path);
        }
    };
    // The build output is refused here, so the next candidate is taken.
    try std.testing.expectEqualStrings(
        "whatwg_snapshot.bin",
        firstUsableSnapshot(@as([]const u8, "whatwg_snapshot.bin"), &DEFAULT_SNAPSHOT_PATHS, Only.accepts).?,
    );
    try std.testing.expectEqualStrings(
        "zig-out/bin/whatwg_snapshot.bin",
        firstUsableSnapshot(@as([]const u8, "zig-out/bin/whatwg_snapshot.bin"), &DEFAULT_SNAPSHOT_PATHS, Only.accepts).?,
    );
    try std.testing.expect(firstUsableSnapshot(@as([]const u8, "nowhere.bin"), &DEFAULT_SNAPSHOT_PATHS, Only.accepts) == null);
}

test "Browser - basic lifecycle" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // Note: This test requires V8 to be initialized, which may not be available
    // in all test environments. Skip if V8 is not available.
    var browser = Browser.init(allocator, .{
        .persist_storage = false, // Use memory-only storage for tests
    }) catch |err| {
        // V8 not available in test environment
        if (err == error.V8InitFailed) return;
        return err;
    };
    defer browser.deinit();

    try testing.expect(browser.isInitialized());
    try testing.expect(browser.getAgent() != null);
}
