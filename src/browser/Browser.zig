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
const Process = @import("process.zig").Process;

/// A similar-origin window agent's host hooks: HostPromiseRejectionTracker
/// and "notify about rejected promises" (html/rejected_promises.zig), and
/// HostLoadImportedModule and HostGetImportMetaProperties - import() in a
/// Window realm loads through the document's module map
/// (html/script_execution.zig).
const window_agent_hooks: engine.HostHooks = blk: {
    const html = @import("html");
    var hooks = html.rejected_promises.hooks;
    hooks.afterMicrotaskCheckpoint = html.microtask_checkpoint.afterMicrotaskCheckpoint;
    hooks.loadImportedModule = html.script_execution.module_hooks.loadImportedModule;
    hooks.importMetaUrl = html.script_execution.module_hooks.importMetaUrl;
    hooks.importMetaResolve = html.script_execution.module_hooks.importMetaResolve;
    break :blk hooks;
};

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
    agent_host: *@import("html").agent_host.AgentHost,
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
        // What every Browser shares - the engine, the snapshot, every hook -
        // is the process's, started once before any Browser (process.zig). A
        // host that has not started it gets it started here, for the
        // process's life.
        Process.ensureStarted(.{ .snapshot_path = config.snapshot_path }) catch return error.V8InitFailed;

        // The network's process-wide state - curl, and the connection pool
        // every fetch shares - held for this Browser's life (`deinit`). It
        // stays here until curl's global init is split from the pool, which
        // must close with the last Browser (process.zig).
        try @import("fetch").network.globalInit();
        errdefer @import("fetch").network.globalCleanup();

        // Initialize WebIDL runtime (SlabAllocator, ArenaAllocator)
        runtime.initializeRuntime(allocator);
        errdefer runtime.deinitializeRuntime();

        // Agents are made from the process's snapshot, unless this Browser
        // asked for none (an empty snapshot_path).
        const no_snapshot = if (config.snapshot_path) |path| path.len == 0 else false;
        const from_snapshot = Process.hasSnapshot() and !no_snapshot;
        if (config.log_performance) {
            std.log.info("Browser starting {s} a snapshot", .{if (from_snapshot) "from" else "without"});
        }

        // HTML "obtain a similar-origin window agent": [[CanBlock]] false -
        // Atomics.wait() throws a TypeError rather than freezing the page's
        // one thread, as Blink's main thread does; a dedicated worker's agent
        // keeps it - and the host's hooks (window_agent_hooks).
        const agent_host = try allocator.create(@import("html").agent_host.AgentHost);
        agent_host.* = @import("html").agent_host.AgentHost.init(allocator);
        errdefer {
            agent_host.deinit();
            allocator.destroy(agent_host);
        }
        const agent = engine.createAgent(.{
            .can_block = false,
            .from_snapshot = from_snapshot,
            .hooks = &window_agent_hooks,
            .host = agent_host,
            .allocator = allocator,
        }) catch return error.V8InitFailed;

        return initBrowserWithAgent(allocator, agent, agent_host, from_snapshot, config);
    }

    /// Complete browser initialization with its agent.
    fn initBrowserWithAgent(
        allocator: std.mem.Allocator,
        agent: *engine.Agent,
        agent_host: *@import("html").agent_host.AgentHost,
        used_snapshot: bool,
        config: BrowserConfig,
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
            .agent_host = agent_host,
            .current_context = null,
            .storage = storage,
            .config = config,
            .initialized = true,
            .event_loop = event_loop,
            .used_snapshot = used_snapshot,
            .cookie_jar = cookiestore.CookieJar.init(allocator),
        };

        // Always create initial about:blank context - a real browser always has a window/document
        // Then navigate to initial URL if specified
        const initial_url = config.initial_url orelse "about:blank";
        try browser.navigate(initial_url, .window);

        return browser;
    }

    /// Deinitialize the browser and release all resources
    ///
    /// This destroys the V8 isolate and all associated contexts.
    /// All storage is flushed to disk before cleanup.
    pub fn deinit(self: *Browser) void {
        // The workers on this loop end first. A worker's end is a timer on
        // this loop, armed when its Worker object lets go; the page's
        // teardown below would arm it, and event_loop.deinit would drop it
        // unfired, leaving the worker's realm, isolate and host to the
        // process. Here, BEFORE the page's teardown and not inside it, the
        // page realm still has the page isolate entered - as it does when
        // those timers fire - so each worker's agent ends as a worker's.
        if (self.event_loop) |event_loop| {
            if (event_loop.timerInterface()) |timers| @import("html").worker_host.endWorkersOn(timers);
        }
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
            self.agent_host.deinit();
            self.allocator.destroy(self.agent_host);

            // Every Window is gone now, so the browsing contexts their
            // containers retired while a Window might still read them
            // (BrowsingContext.discard) can finally be freed.
            @import("html").window.browsing_context.BrowsingContext.freeRetired();
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
