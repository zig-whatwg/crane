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
const media_backend_mod = @import("platform").media_backend;

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
    hooks.ensureCanCompileStrings = html.code_generation.hooks.ensureCanCompileStrings;
    hooks.getCodeForEval = html.code_generation.hooks.getCodeForEval;
    hooks.ensureCanCompileWasmBytes = html.code_generation.hooks.ensureCanCompileWasmBytes;
    if (engine.capabilities.html_constructor != .unsupported) hooks.htmlConstructor = html.custom_element_constructor.construct;
    hooks.agentClusterOf = html.agent_clusters.agentClusterOf;
    if (html.webassembly_streaming.supported) hooks.compilePotentialWebAssemblyResponse = html.webassembly_streaming.compilePotentialWebAssemblyResponse;
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
    /// The host's media decoding (src/platform/media_backend.zig). Crane
    /// builds in no decoder: fetch, CORS, CSP, events and HTML state stay in
    /// Crane, and the host supplies what it can decode. BORROWED for the
    /// Browser's whole lifetime - the host keeps the backend (its `ptr` and
    /// vtable) alive until `deinit` returns. Every realm of the Browser reaches
    /// it through the Browser's scope (html.media_runtime.forRealm). The
    /// default, no_decoder, makes canPlayType answer "" for every type.
    media_backend: media_backend_mod.MediaBackend = media_backend_mod.no_decoder,
    /// A certificate authority bundle this Browser trusts besides the
    /// system's (PEM; the WPT runner's tools/certs/cacert.pem). Copied.
    ca_bundle_path: ?[]const u8 = null,
    /// The Browser's user agent string: the `User-Agent` its requests send
    /// and navigator.userAgent in its windows and workers (Fetch's
    /// "environment default `User-Agent` value"). Null: Crane's default
    /// (fetch.internal.user_agent). Copied.
    user_agent: ?[]const u8 = null,
    /// Where its requests go - WebDriver's proxy configuration. Explicit
    /// proxies only (docs/instances.md): a PAC file and auto-detection make
    /// `init` fail with error.NotSupported. Copied.
    proxy: Proxy = .system,
    /// WebDriver's acceptInsecureCerts: TLS certificates are not verified.
    accept_insecure_certs: bool = false,
    /// How many pages the back/forward cache keeps (back_forward_cache.zig):
    /// 2 by default - WebKit's page cache on a small device (CacheModel);
    /// Blink keeps 6 - for an engine that runs many Browsers in one
    /// process. 0 keeps none.
    back_forward_cache_size: usize = @import("back_forward_cache.zig").default_size,
    /// How long a page stays in the back/forward cache, in seconds: 600, as
    /// Blink (BackForwardCacheImpl::GetTimeToLiveInBackForwardCache).
    back_forward_cache_ttl_seconds: u64 = @import("back_forward_cache.zig").default_ttl_seconds,
    /// The Browser's HTTP cache (in memory, shared by its tabs, frames and
    /// workers): its byte cap - default 50 MiB, Chromium's in-memory
    /// backend's - and per-response cap - default an eighth of that, as
    /// Chromium and Gecko both derive it. A max_bytes of 0: no HTTP cache.
    http_cache: HttpCacheConfig = .{},

    pub const HttpCacheConfig = @import("fetch").network.NetworkContext.HttpCacheConfig;

    pub const Proxy = union(enum) {
        /// The process's proxy settings (curl reads http_proxy, https_proxy
        /// and no_proxy from the environment). The default.
        system,
        /// No proxy.
        direct,
        /// A proxy per scheme and the hosts that bypass it.
        manual: @import("fetch").network.NetworkContext.Proxy.Manual,
        /// A proxy auto-config file's URL: not supported.
        pac: []const u8,
        /// Proxy auto-detection (WPAD): not supported.
        autodetect,
    };
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
    /// this Browser runs - a supplement of its scope, which ends with it.
    /// Fetch sends and stores through it, and document.cookie and
    /// cookieStore read and write it; a realm reaches it through its
    /// settings object (dom.global_settings.cookieJarOf). Its change hook is
    /// the Browser's CookieStore listeners (dom.cookie_change_listeners).
    ///
    /// Reached from the Browser's window thread and every worker's: whoever
    /// reads or writes it holds its lock (CookieJar, "One jar serves every
    /// thread of a Browser").
    cookie_jar: *cookiestore.CookieJar,
    /// The Browser's scope: its per-Browser state, as supplements every realm
    /// of it reaches (ContextData.browser_scope; docs/instances.md rule 2) -
    /// its live workers (html.WorkerRegistry) - and the slab and arena every
    /// platform object of it comes from. Ends after every realm and every
    /// worker thread.
    scope: *runtime.BrowserScope,

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
        // Explicit proxies only (docs/instances.md, the user's decision).
        switch (config.proxy) {
            .pac, .autodetect => return error.NotSupported,
            else => {},
        }
        Process.ensureStarted(.{ .snapshot_path = config.snapshot_path }) catch return error.V8InitFailed;

        // The platform objects of this Browser, and their side tables, come
        // from its own scope (made below, before its first realm), never from
        // another Browser's: nothing process-wide is started here.

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
            // A collected node's teardown is queued here, for the event loop
            // to run between tasks (runtime.gc.DeferredTeardown).
            .deferred_teardown = &agent_host.deferred_teardown,
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
        // The agent's deferred teardown queue, which the loop runs between
        // tasks, and its fetches, which the loop pumps.
        event_loop.deferred_teardown = &agent_host.deferred_teardown;
        event_loop.fetches = &agent_host.fetches;

        // The Browser's scope, which its realms carry.
        const scope = try allocator.create(runtime.BrowserScope);
        errdefer allocator.destroy(scope);
        scope.* = runtime.BrowserScope.init(allocator);
        errdefer scope.deinit();
        // The Browser's platform state (docs/platform-protocol.md section 3),
        // which its realms' per-Browser platform operations take.
        try @import("html").platform_state.create(scope);
        // The host's media backend, which every realm of this Browser reads
        // (html.media_runtime.MediaHost), set before any realm exists.
        (try scope.of(@import("html").media_runtime.MediaHost)).backend = config.media_backend;
        // The user agent's cookie jar, and the CookieStores that hear it:
        // the listeners are its change hook from before any realm can change
        // it. (The jar first: supplements end in reverse, so the listeners
        // go before the jar they hear.)
        const cookie_jar = try scope.of(cookiestore.CookieJar);
        (try scope.of(@import("dom").cookie_change_listeners.CookieChangeListeners)).hearJar(cookie_jar);
        // The Browser's network: its connections, its TLS options, its
        // WebSocket gate - every request of its realms carries it.
        try (try scope.of(@import("fetch").network.NetworkContext)).configure(.{
            .ca_bundle_path = config.ca_bundle_path,
            .user_agent = config.user_agent,
            .proxy = switch (config.proxy) {
                .system => .system,
                .direct => .direct,
                .manual => |manual| .{ .manual = manual },
                .pac, .autodetect => unreachable, // refused by init
            },
            .accept_insecure_certs = config.accept_insecure_certs,
            .http_cache = config.http_cache,
        });
        // What a response's Clear-Site-Data header clears: this Browser's
        // state, never another's (src/browser/clear_site_data.zig).
        (try scope.of(@import("fetch").network.NetworkContext)).site_data = @import("clear_site_data.zig").clearerFor(scope);

        // The back/forward cache, on the Browser's loop, as configured.
        (try scope.of(@import("back_forward_cache.zig").BackForwardCache)).configure(event_loop, config.back_forward_cache_size, config.back_forward_cache_ttl_seconds);

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
            .cookie_jar = cookie_jar,
            .scope = scope,
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
        // Every worker thread of this Browser ends first - terminated, then
        // joined - before the page's teardown and before the runtime's
        // allocators go: the slab and arena every platform object comes from
        // must outlive every thread (workers design 2.4). What the workers
        // posted to this loop since is dropped with it.
        if (self.scope.existing(@import("html").WorkerRegistry)) |registry| {
            registry.terminateAll();
            registry.joinAll();
        }
        // The pages the back/forward cache keeps leave first: their realms
        // are children of the page's (which would end them), and their
        // eviction needs the loop, which ends below.
        @import("back_forward_cache.zig").evictAllIn(self.scope);
        // Destroy current context if any
        if (self.current_context) |ctx| {
            ctx.deinit();
            self.allocator.destroy(ctx);
            self.current_context = null;
        }
        // The page's fetches still in flight release what they hold - a
        // promise, and through it the realm - while the isolate lives.
        _ = self.agent_host.fetches.sweep();

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
            // Release queued handles while the agent exists; AgentHost outlives it.
            self.agent_host.custom_elements.releasePending();
            // No node waits for its deferred teardown: each was queued by a
            // realm, and every realm's end (current_context's, above) drained
            // its own. The sweep below frees what is left of the DOM without
            // teardowns, so a node still queued would be torn down after it.
            std.debug.assert(self.agent_host.deferred_teardown.isEmpty());
            // IMPORTANT: Clean up orphaned DOM nodes BEFORE the agent ends!
            // DOM node internal states may use the agent's allocator, which
            // its end frees. Every type's side table of THIS Browser is swept
            // (dom.teardown_sweeps) - never another Browser's.
            @import("dom").teardown_sweeps.runAll(self.scope);

            // Release the rejection tracker's promise handles - this agent's,
            // on its host, and no other Browser's - while the agent that
            // owns them still exists.
            @import("html").rejected_promises.releaseAgent(agent);

            // The end of the agent (engine.destroyAgent): its hooks forgotten,
            // the engine's per-isolate and per-thread state torn down in
            // order, its garbage collected, its isolate disposed.
            engine.destroyAgent(agent);
            self.agent_host.deinit();
            self.allocator.destroy(self.agent_host);

            // Every Window is gone now, so the browsing contexts their
            // containers retired while a Window might still read them
            // (BrowsingContext.discard) can finally be freed - this
            // Browser's, never another's.
            if (@import("dom").browser_state.existingNavigablesIn(self.scope)) |navigables| navigables.freeRetired();
        }

        // The Browser's scope: every realm and every worker thread is gone,
        // and every agent's fetches with its host. Its supplements end - its
        // network context closes its connections (each HTTP/2 one with a
        // GOAWAY), its own and no other Browser's - then its side tables
        // (what their entries still hold of the engine is released without
        // it), then its slab and arena - every platform object of this
        // Browser, and none of another's. Its platform state ends first.
        @import("html").platform_state.destroy(self.scope);
        self.scope.deinit();
        self.allocator.destroy(self.scope);

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
            // The pages the back/forward cache keeps were opened from this
            // page: they leave while its realm - their realms' parent - and
            // the loop still live.
            @import("back_forward_cache.zig").evictAllIn(self.scope);
            old_ctx.deinit();
            self.allocator.destroy(old_ctx);
            self.current_context = null;
            // Fetch's "terminate a fetch group" for the page that ended, now
            // rather than at the next turn's pump.
            _ = self.agent_host.fetches.sweep();

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
            self.cookie_jar,
            serialized orelse url,
            self.event_loop,
            context_type,
            self.used_snapshot,
            self.scope,
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
