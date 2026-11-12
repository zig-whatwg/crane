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
const interfaces = @import("interfaces");
const html_mod = @import("html");

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
const platform = @import("platform");

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
    hooks.crossOriginIsolatedCapability = html.agent_clusters.crossOriginIsolatedCapability;
    if (html.webassembly_streaming.supported) hooks.compilePotentialWebAssemblyResponse = html.webassembly_streaming.compilePotentialWebAssemblyResponse;
    break :blk hooks;
};

/// Browser configuration options
pub const BrowserConfig = struct {
    /// Root directory of the legacy storage manager (storage/Storage.zig),
    /// with `persist_storage`; null: ~/.whatwg/.
    storage_root: ?[]const u8 = null,
    /// Whether the legacy storage manager makes its directories under
    /// `storage_root`. False by default: a Browser is in memory and writes
    /// nothing to disk (docs/instances.md: "In memory by default; an
    /// optional profile directory persists the Browser's stores"). It was
    /// true, and every Browser left at the defaults made empty directories
    /// in ~/.whatwg/ that nothing ever read: localStorage, cookies,
    /// IndexedDB, the Cache API and the HTTP cache are all in memory today,
    /// and persisting them under a profile directory is its own work
    /// (STORAGE PERSISTENCE, tmp/plans/lane-console-handoff.md).
    persist_storage: bool = false,
    /// Initial URL to navigate to (optional)
    initial_url: ?[]const u8 = null,
    /// Enable debug logging
    debug: bool = false,
    /// Path to V8 snapshot file (optional, auto-detected if null)
    /// Set to empty string "" to explicitly disable snapshot loading
    snapshot_path: ?[]const u8 = null,
    /// Whether to log performance information
    log_performance: bool = false,
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
    /// Whether a platform object's freed state - its State block, and a
    /// node's NodeBase released at its teardown - is overwritten with the
    /// poison byte (runtime.ArenaAllocator.poison_freed), so a read after the
    /// free faults instead of finding the old bytes. For the WPT correctness
    /// runner, which poisons its allocator's frees by default (the user,
    /// 2026-11-05); off by default - never in a product build.
    poison_freed_state: bool = false,
    /// The most memory the young generation of its window agent may take,
    /// in bytes (engine.AgentOptions.young_generation_limit):
    /// a larger one is faster for allocation-heavy pages and holds more
    /// memory between collections. A host that ships for desktop can permit
    /// the engine's own ceiling (null; V8 15.7: 96 MB, 32 MB semispaces); one
    /// that runs many Browsers in a server, or on a phone, gives less (24 MB
    /// is 8 MB semispaces). A hint where the engine has no such knob. The
    /// default is the protocol's one constant,
    /// engine.default_young_generation_limit.
    young_generation_limit: ?usize = engine.default_young_generation_limit,
    /// How many pages the back/forward cache keeps (back_forward_cache.zig):
    /// 8 by default - Firefox's desktop cap, for the whole Browser
    /// (back_forward_cache.zig `default_size` says why). 0 keeps none.
    back_forward_cache_size: usize = @import("back_forward_cache.zig").default_size,
    /// How long a page stays in the back/forward cache, in seconds: 600, as
    /// Blink (BackForwardCacheImpl::GetTimeToLiveInBackForwardCache).
    back_forward_cache_ttl_seconds: u64 = @import("back_forward_cache.zig").default_ttl_seconds,
    /// The Browser's HTTP cache (in memory, shared by its tabs, frames and
    /// workers): its byte cap - default 50 MiB, Chromium's in-memory
    /// backend's - and per-response cap - default an eighth of that, as
    /// Chromium and Gecko both derive it. A max_bytes of 0: no HTTP cache.
    http_cache: HttpCacheConfig = .{},
    /// The platform's own per-Browser options (docs/platform-protocol.md
    /// 3.2), given to the Browser's platform state: on the testing
    /// platform, the opt-in deterministic modes - a virtual clock
    /// (`virtual_clock`, `virtual_clock_wall_start_ms`) and a random seed
    /// (`random_seed`) - among others. Code meant for every platform leaves
    /// it `.{}`, which is real time and the engine's own entropy.
    platform: platform.PlatformBrowserOptions = .{},

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
    /// What a host attached to the Browser's developer console receives
    /// (`attachDeveloperConsole`).
    pub const developer_console = @import("dom").developer_console;

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
        // The Browser's scope, which its realms carry, and its platform
        // state (docs/platform-protocol.md section 3), before its agent and
        // its event loop: the agent takes the Browser's clock and the seed
        // of its random stream, the loop its clock (platform.browserClock,
        // platform.fillBrowserRandom) - the testing platform's opt-in
        // virtual clock and seed, or none: the engine's own clock and
        // entropy, exactly as before. Ended after the agent and the loop,
        // here as in `deinit`.
        const scope = try allocator.create(runtime.BrowserScope);
        errdefer allocator.destroy(scope);
        scope.* = runtime.BrowserScope.init(allocator);
        errdefer scope.deinit();
        scope.arena.poison_freed = config.poison_freed_state;
        const browser_platform = try @import("html").platform_state.createWith(scope, &.{ .platform = config.platform });
        const browser_clock = platform.browserClock(browser_platform);
        var random_seed: u64 = undefined;
        const seeded = platform.fillBrowserRandom(browser_platform, std.mem.asBytes(&random_seed));
        // The Browser's heap: one reservation of address space, named as
        // this scope's (runtime.BrowserScope.reserveHeap), its generations
        // seeded from the Browser's stream after the agent's seed is drawn,
        // so a seeded run replays both. A Browser that cannot reserve fails
        // here, cleanly; the scope's end releases it, last.
        try scope.reserveHeap(platform, browser_platform);

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
            // The Browser's DOM, which its engine is told about as it grows
            // and shrinks (runtime.gc.ExternalMemory).
            .external_memory = &scope.dom_memory,
            // Date reads the Browser's clock when it has one of its own.
            .clock = if (browser_clock.wall_now) |wall_now| .{ .context = browser_clock.context, .wall_now = wall_now } else null,
            // Math.random replays from the Browser's stream when it has one.
            .random_seed = if (seeded) random_seed else null,
            // The young generation's ceiling the host chose for this Browser.
            .young_generation_limit = config.young_generation_limit,
        }) catch return error.V8InitFailed;

        // What the agent really is: one asked for the snapshot is made without
        // it while the process's live isolates were made without it (V8 keeps
        // one read-only heap per process; the engine says so at warn), and
        // its realms are then made afresh rather than failing a restore each.
        const restored = engine.agentRestoredFromSnapshot(agent);
        return initBrowserWithAgent(allocator, agent, agent_host, restored, config, scope, browser_clock);
    }

    /// Complete browser initialization with its agent.
    fn initBrowserWithAgent(
        allocator: std.mem.Allocator,
        agent: *engine.Agent,
        agent_host: *@import("html").agent_host.AgentHost,
        used_snapshot: bool,
        config: BrowserConfig,
        scope: *runtime.BrowserScope,
        browser_clock: platform.BrowserClock,
    ) !*Browser {
        errdefer engine.destroyAgent(agent);

        // Create storage subsystem
        const storage = try Storage.init(allocator, config.storage_root, config.persist_storage);
        errdefer storage.deinit();

        // The agent's event loop, with its timers (the host's).
        const event_loop = try allocator.create(EventLoop);
        errdefer allocator.destroy(event_loop);
        event_loop.* = try EventLoop.initWithClock(agent, allocator, browser_clock);
        // The agent's deferred teardown queue, which the loop runs between
        // tasks, and its fetches, which the loop pumps.
        event_loop.deferred_teardown = &agent_host.deferred_teardown;
        event_loop.fetches = &agent_host.fetches;

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
            // The agent runs no more script: its node wrappers end now, each
            // one's reference let go, so the drain below frees the trees
            // only wrappers held and the sweep after it finds no node a
            // wrapper still points at (engine.releaseNodeWrappers; the
            // wrapper redesign's P2: a node's wrapper is its agent's, and its
            // realm's end no longer lets it go).
            engine.releaseNodeWrappers(agent);
            // No node waits for its deferred teardown: each realm's end
            // (current_context's, above) drained its own, and what the counts
            // queued after - a holder its realm's teardown released - goes
            // now (refcount step 7; a retired realm's trees are left to the
            // sweep below). The sweep frees what is left of the DOM without
            // teardowns, so a node still queued would be torn down after it.
            self.agent_host.deferred_teardown.drainAll();
            std.debug.assert(self.agent_host.deferred_teardown.isEmpty());
            // Every node the counts could free is freed: what is left is a
            // tree something still holds at the agent's end - a leak the
            // sweep below hides (refcount design step 7, decision D9).
            _ = @import("dom").refcount_teardown.agentEnded(self.scope, &self.agent_host.deferred_teardown);
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
        // Browser, and none of another's - and last its heap's reservation.
        // Its platform state ends first.
        @import("html").platform_state.destroy(self.scope);
        self.scope.deinit();
        self.allocator.destroy(self.scope);

        self.initialized = false;
        self.allocator.destroy(self);
    }

    /// Navigation options
    pub const NavigateOptions = struct {
        /// Leave the new traversable on its initial about:blank document:
        /// the caller loads it (Context.loadPage, Context.loadHTML).
        skip_load: bool = false,
    };

    /// Open `url` in a FRESH top-level traversable - a new tab, the page
    /// before it closed: the Browser's page ends (its realm, its traversable)
    /// and a new one is made, as HTML "create a fresh top-level traversable"
    /// does: "create a new top-level traversable" - a browsing context and
    /// its initial about:blank document of a new opaque origin, in a realm of
    /// its own (Context.init) - then HTML "navigate" of it to `url` with user
    /// involvement "browser UI" (Context.loadPage), waited for until the
    /// page's document has committed and its parser has run as far as it
    /// can (Context.loadByNavigating). Storage, cookies and the
    /// HTTP cache are the Browser's and persist. To navigate the page the
    /// Browser shows instead - its session history kept - `navigateInPlace`.
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
            // (engine.notifyMemoryPressure .critical - on V8,
            // Isolate::MemoryPressureNotification(kCritical): one full
            // collection, a second when the first left much to free). This is
            // critical for sequential test execution to prevent heap growth.
            // KNOWN, queued (lane v8up b5, tmp/plans/feature-queue.md): not a
            // browser's path - when a page goes Blink tells V8 only that a
            // context was disposed (V8GCForContextDispose::
            // NotifyContextDisposed, which the realm's end sends), and sends
            // critical pressure at a navigation only on low-end Android.
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
        // The new traversable is the Browser's page from here, whatever its
        // first navigation does: one that fails leaves it on that
        // navigation's error page, as a browser's tab does, and the error
        // says so (CDP's Page.navigate errorText).
        self.current_context = ctx;
        if (!options.skip_load) try ctx.loadPage();
    }

    /// HTML "navigate" the page this Browser shows to `url`, in place: the
    /// same top-level traversable - its session history, its WindowProxy -
    /// as an address bar navigates its tab (Context.navigate; the navigation
    /// runs as tasks, so run the event loop for it). With no page yet, the
    /// first one is opened (`navigate`). `navigate` itself opens a FRESH
    /// traversable each time - what the WPT runner wants for each file.
    ///
    /// A page with no traversable record (error.NoTraversable: a worker's
    /// page, or a record that could not be made) cannot be navigated, and
    /// says so: it is not replaced by a fresh traversable behind the
    /// caller's back, which no browser's address bar does (lane loadpath1).
    pub fn navigateInPlace(self: *Browser, url: []const u8) !void {
        const ctx = self.current_context orelse return self.navigate(url, .window);
        try ctx.navigate(url);
    }

    /// `url` parsed with the basic URL parser and serialized; null when it
    /// does not parse. Owned by `allocator`.
    fn serializedUrl(allocator: std.mem.Allocator, url: []const u8) ?[]u8 {
        var record = @import("basic_parser").parse(allocator, url, null) catch return null;
        defer record.deinit();
        return @constCast(@import("url_serializer").serialize(allocator, &record, false) catch return null);
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

    /// The condition `spinEventLoopUntil` waits for: `met(context)` is asked
    /// between turns of the event loop. It must not run script.
    pub const SpinGoal = context_mod.SpinGoal;

    /// How `spinEventLoopUntil` ended.
    pub const SpinOutcome = context_mod.SpinOutcome;

    /// HTML "spin the event loop" until `goal` is met (8.1.7.3), for a host
    /// that waits from outside any task - the browser console waiting for an
    /// evaluation, WebDriver for a script's promise: the event loop's turns
    /// run - tasks, timers, the network, posted work, microtask checkpoints
    /// - exactly as `runEventLoopBlocking` runs them, until `goal` is met or
    /// `timeout_ms` (real time) passes. The goal is asked before the first
    /// turn and after each, so a goal a checkpoint meets is seen at once; a
    /// turn waits at most a millisecond for a timer or I/O (native_timer's
    /// slice), so a goal is seen within about one of being met.
    ///
    /// The spec's steps, for a caller with no running task: 1-4 there is no
    /// task to stop and the JavaScript execution context stack is empty; 5
    /// "perform a microtask checkpoint" - each turn's first step; 6.1 "wait
    /// until the condition goal is met" - the turns below; 6.2 the steps
    /// after the spin are the caller's, which runs them once this returns.
    /// Unlike runEventLoopBlocking it does not stop when the loop has no
    /// pending work: what meets the goal may come from outside it (another
    /// thread's post wakes the loop), and only the deadline ends the wait.
    ///
    /// error.Reentrant from inside a turn of this Browser's loop (a task, a
    /// timer, a microtask): spinning there would run the loop inside itself,
    /// which runOnceBlocking refuses.
    pub fn spinEventLoopUntil(self: *Browser, goal: SpinGoal, timeout_ms: u64) !SpinOutcome {
        const event_loop = self.event_loop orelse return error.NotInitialized;
        return context_mod.spinEventLoopUntil(event_loop, goal, timeout_ms);
    }

    // ========================================================================
    // The host's view of its top-level traversables
    // ========================================================================
    //
    // A host shows its Browser's top-level traversables (HTML 7.3.1.2) - the
    // host page's, and every popup window.open() or a link's or form's target
    // made ("every popup is a tab", docs/instances.md) - and drives them as a
    // browser's UI does: navigate one, reload it, traverse its history, close
    // it. Each is named by the id of its top-level browsing context, which it
    // keeps for its life; an id whose traversable has closed names nothing
    // (null, or error.NoSuchTraversable). On the Browser's window thread, from
    // outside script (a task of the loop, or between its turns).
    //
    // Opening a tab - a host-made top-level traversable in a new browsing
    // context group - is not here: the host page's Window realm is entered for
    // its life (the engine's createWindowRealm), so a second one cannot end
    // before a later one (tmp/plans/lane-console-handoff.md, HOST-OPENED TABS).

    /// One top-level traversable, as `traversables` lists it.
    pub const TraversableInfo = struct {
        /// Its top-level browsing context's id.
        id: u64,
        /// Its active document's URL and title. OWNED (`freeTraversables`).
        url: []u8,
        title: []u8,
        /// Who made it: the host (the Browser's page), or a page's script
        /// (a popup).
        made_by: enum { host, page },
        /// The traversable whose page opened it, while it lives and the popup
        /// was not opened with noopener; null otherwise.
        opener: ?u64,
    };

    /// Every top-level traversable of this Browser that is not closed: the
    /// host page's first, then the popups in the order they were made.
    /// OWNED by `allocator`: `freeTraversables`.
    pub fn traversables(self: *Browser, allocator: std.mem.Allocator) ![]TraversableInfo {
        var list: std.ArrayListUnmanaged(TraversableInfo) = .empty;
        errdefer {
            for (list.items) |info| {
                allocator.free(info.url);
                allocator.free(info.title);
            }
            list.deinit(allocator);
        }
        const host_id = self.hostTraversableId();
        var contexts: std.ArrayListUnmanaged(*html_mod.BrowsingContext) = .empty;
        defer contexts.deinit(allocator);
        if (@import("dom").browser_state.existingNavigablesIn(self.scope)) |navigables| {
            for (navigables.contexts()) |bc| {
                if (!isOpenTopLevel(bc)) continue;
                try contexts.append(allocator, bc);
            }
        }
        std.mem.sort(*html_mod.BrowsingContext, contexts.items, host_id, struct {
            fn lessThan(host_tab: ?u64, a: *html_mod.BrowsingContext, b: *html_mod.BrowsingContext) bool {
                if (host_tab) |h| {
                    if (a.id == h) return b.id != h;
                    if (b.id == h) return false;
                }
                return a.id < b.id;
            }
        }.lessThan);
        for (contexts.items) |bc| {
            const document: ?*runtime.Instance = if (bc.getActiveDocument()) |d| @ptrCast(@alignCast(d)) else null;
            const url = try documentUrl(allocator, document);
            errdefer allocator.free(url);
            const title = try documentTitle(allocator, document);
            errdefer allocator.free(title);
            const opener: ?u64 = if (bc.opener) |o| (if (!bc.disowned and isOpenTopLevel(o)) o.id else null) else null;
            try list.append(allocator, .{
                .id = bc.id,
                .url = url,
                .title = title,
                .made_by = if (host_id != null and bc.id == host_id.?) .host else .page,
                .opener = opener,
            });
        }
        return list.toOwnedSlice(allocator);
    }

    /// The ids of the open top-level traversables, in `traversables`'
    /// order, written into `out` (as many as fit): how many there are.
    /// Allocates nothing - a host asks between turns of the loop.
    pub fn traversableIds(self: *Browser, out: []u64) usize {
        const navigables = @import("dom").browser_state.existingNavigablesIn(self.scope) orelse return 0;
        const host_id = self.hostTraversableId();
        var count: usize = 0;
        if (host_id) |h| if (self.openTraversable(h) != null) {
            if (count < out.len) out[count] = h;
            count += 1;
        };
        const first_popup = count;
        for (navigables.contexts()) |bc| {
            if (!isOpenTopLevel(bc)) continue;
            if (host_id) |h| if (bc.id == h) continue;
            if (count < out.len) out[count] = bc.id;
            count += 1;
        }
        const written = @min(count, out.len);
        if (written > first_popup) std.mem.sort(u64, out[first_popup..written], {}, std.sort.asc(u64));
        return count;
    }

    /// Free what `traversables` returned.
    pub fn freeTraversables(allocator: std.mem.Allocator, list: []TraversableInfo) void {
        for (list) |info| {
            allocator.free(info.url);
            allocator.free(info.title);
        }
        allocator.free(list);
    }

    /// The host page's top-level traversable: the Browser's first tab.
    pub fn hostTraversableId(self: *Browser) ?u64 {
        const ctx = self.current_context orelse return null;
        const bc = ctx.browsing_context orelse return null;
        return bc.id;
    }

    /// The realm of traversable `id`'s active window - where script typed
    /// into its console runs, and what follows its navigations - or null
    /// while it has none (a navigation between two Windows) or once it has
    /// closed.
    pub fn traversableRealm(self: *Browser, id: u64) ?runtime.Context {
        const window = self.traversableWindow(id) orelse return null;
        return window.ctx;
    }

    /// Traversable `id`'s active window (its Window), or null.
    pub fn traversableWindow(self: *Browser, id: u64) ?*runtime.Instance {
        const bc = self.openTraversable(id) orelse return null;
        const window = bc.getActiveWindow() orelse return null;
        return @ptrCast(@alignCast(window));
    }

    /// Where traversable `id` is, read without running script or
    /// allocating - a host asks between turns of the loop. Null once it has
    /// closed.
    pub const TraversableState = struct {
        /// Its active document, as an identity to tell one document from the
        /// next with `document_generation` (a freed document's address is
        /// reused): never dereferenced by the caller. Null between two
        /// documents.
        document: ?*anyopaque,
        document_generation: u64,
        /// The active document is its initial about:blank one.
        initial_about_blank: bool,
        /// A navigation of it is under way, or a traversal or reload queued
        /// on its session history traversal queue.
        navigating: bool,
        /// The active document's load event has run: HTML "the end" step 7
        /// makes its readiness "complete" and fires load in one task.
        loaded: bool,
        /// The URL the navigation under way navigates to, when it is a
        /// navigation (not a traversal or a reload queued): BORROWED, valid
        /// until the loop's next turn.
        navigating_to: ?[]const u8 = null,
    };

    pub fn traversableState(self: *Browser, id: u64) ?TraversableState {
        const bc = self.openTraversable(id) orelse return null;
        const document: ?*runtime.Instance = if (bc.getActiveDocument()) |d| @ptrCast(@alignCast(d)) else null;
        const integration = integrationOf(bc);
        const navigating = if (integration) |i| i.ongoing_navigation != .none else false;
        const queued = if (bc.traversal_queue) |queue| queue.items.items.len > 0 or queue.running != null else false;
        const loaded = if (document) |d| ((interfaces.Document.get_readyState(d) catch ._loading_) == ._complete_) else false;
        var navigating_to: ?[]const u8 = null;
        if (integration) |i| switch (i.ongoing_navigation) {
            .id => |navigation_id| if (bc.navigables) |navigables| {
                if (navigables.navigation(navigation_id)) |record| navigating_to = @import("dom").navigables.navigationUrl(record);
            },
            else => {},
        };
        return .{
            .navigating_to = navigating_to,
            .document = if (document) |d| @ptrCast(d) else null,
            .document_generation = if (document) |d| runtime.SlabAllocator.generationOf(d) else 0,
            .initial_about_blank = if (document) |d| @import("dom").document_lifecycle.isInitialAboutBlank(d) else false,
            .navigating = navigating or queued,
            .loaded = loaded,
        };
    }

    /// Traversable `id`'s active document's URL ("about:blank" while it has
    /// none). OWNED by `allocator`; error.NoSuchTraversable once it closed.
    pub fn traversableUrl(self: *Browser, allocator: std.mem.Allocator, id: u64) ![]u8 {
        const bc = self.openTraversable(id) orelse return error.NoSuchTraversable;
        const document: ?*runtime.Instance = if (bc.getActiveDocument()) |d| @ptrCast(@alignCast(d)) else null;
        return documentUrl(allocator, document);
    }

    /// The response status of the navigation that made traversable `id`'s
    /// active document - its navigation timing entry's responseStatus - or
    /// 0: a document no response made (about:blank, a srcdoc, an error
    /// document) has no entry, and one fetched from no network a status of 0.
    pub fn traversableStatus(self: *Browser, id: u64) u16 {
        const window = self.traversableWindow(id) orelse return 0;
        const entry = @import("dom").performance_timeline.navigationEntryOf(window.ctx) orelse return 0;
        return interfaces.PerformanceResourceTiming.get_responseStatus(entry) catch 0;
    }

    /// HTML "navigate" traversable `id` to `url` as the browser's UI does -
    /// its address bar: the host page's through its record
    /// (Context.navigate, user involvement "browser UI"), a popup's through
    /// its navigable's own navigate with no source document. The navigation
    /// runs as tasks of the loop: run it to see the new document.
    /// error.InvalidUrl for a `url` the basic URL parser does not take as an
    /// absolute URL: nothing is navigated.
    pub fn navigateTraversable(self: *Browser, id: u64, url: []const u8) !void {
        const bc = self.openTraversable(id) orelse return error.NoSuchTraversable;
        const serialized = serializedUrl(self.allocator, url) orelse return error.InvalidUrl;
        defer self.allocator.free(serialized);
        if (self.isHostTraversable(bc)) return self.navigateInPlace(serialized);
        const integration = integrationOf(bc) orelse return error.NoSuchTraversable;
        // A "browser UI" navigation: no sourceDocument, the user's own
        // (navigate step 5) - as the host page's address bar navigates.
        integration.navigate(serialized, .{ .browser_ui = true });
    }

    /// HTML "reload" traversable `id`'s navigable, as the browser's reload
    /// button does: with userInvolvement "browser UI", so "reload" step 1 -
    /// the navigation API's navigate event, which the page could cancel - is
    /// skipped (History's reload steps for its active window). The page's
    /// own location.reload() is "none" and fires it.
    pub fn reloadTraversable(self: *Browser, id: u64) !void {
        const window = self.traversableWindow(id) orelse return error.NoSuchTraversable;
        @import("dom").history_traversal.reloadWithUserInvolvement(window, .browser_ui);
    }

    /// HTML "traverse the history by a delta" for traversable `id`, as a
    /// browser's back (-1) and forward (+1) buttons do: no sourceDocument
    /// (step 3's allowed-to-navigate check is the document's, and the user
    /// is not a document), its steps appended to the traversable's session
    /// history traversal queue (step 4). False when there is no entry `delta`
    /// steps away (step 4.4 would return): nothing is queued. The traversal
    /// runs as tasks of the loop.
    pub fn traverseHistoryByDelta(self: *Browser, id: u64, delta: i32) !bool {
        const bc = self.openTraversable(id) orelse return error.NoSuchTraversable;
        const history = try bc.ensureHistoryEntries(&historyDocumentInfo);
        const apply_history_step = html_mod.navigation.apply_history_step;
        const predicted = history.predictedStepByDelta(delta) orelse return false;
        const cross_document = switch (predicted) {
            .listed => |target| apply_history_step.changesDocument(bc, history, target),
            .pushed => false,
        };
        apply_history_step.traverse(bc, self.allocator, .{ .delta = delta }, .{ .cross_document_delta = cross_document, .delta_navigable = bc.id });
        return true;
    }

    /// HTML "close a top-level traversable" for popup `id`: its documents
    /// are asked about unloading (beforeunload), unloaded and destroyed, and
    /// its browsing context closed (dom.auxiliary_navigables.definitelyClose).
    /// The host's own page closes only with the Browser:
    /// error.HostTraversable.
    pub fn closeTraversable(self: *Browser, id: u64) !void {
        const bc = self.openTraversable(id) orelse return error.NoSuchTraversable;
        if (self.isHostTraversable(bc)) return error.HostTraversable;
        const window: *runtime.Instance = @ptrCast(@alignCast(bc.getActiveWindow() orelse return error.NoSuchTraversable));
        if (!@import("dom").auxiliary_navigables.definitelyClose(window)) return error.NoSuchTraversable;
    }

    /// How many top-level traversables are open.
    pub fn traversableCount(self: *Browser) usize {
        const navigables = @import("dom").browser_state.existingNavigablesIn(self.scope) orelse return 0;
        var count: usize = 0;
        for (navigables.contexts()) |bc| {
            if (isOpenTopLevel(bc)) count += 1;
        }
        return count;
    }

    /// Where traversable `id` is in `traversables`' order, from 0 (the host
    /// page's); null once it has closed. Allocates nothing.
    pub fn traversableIndex(self: *Browser, id: u64) ?usize {
        const target = self.openTraversable(id) orelse return null;
        const host_id = self.hostTraversableId();
        if (host_id) |h| if (target.id == h) return 0;
        const navigables = @import("dom").browser_state.existingNavigablesIn(self.scope) orelse return null;
        var index: usize = if (host_id != null and self.openTraversable(host_id.?) != null) 1 else 0;
        for (navigables.contexts()) |bc| {
            if (!isOpenTopLevel(bc) or bc.id == target.id) continue;
            if (host_id) |h| if (bc.id == h) continue;
            if (bc.id < target.id) index += 1;
        }
        return index;
    }

    /// Where a Window realm of this Browser is shown: the top-level
    /// traversable it is in, and whether it is a frame's (a child
    /// navigable's) rather than the traversable's own. Null for a realm that
    /// is not a Window's, or one no browsing context shows any more. On the
    /// Browser's window thread.
    pub const RealmSource = struct { traversable: u64, frame: bool };

    pub fn realmSource(self: *Browser, realm: runtime.Context) ?RealmSource {
        _ = self;
        if (!realm.isWindow()) return null;
        const record = realm.getRealm() orelse return null;
        const global: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
        const bc = @import("dom").browser_state.browsingContextOf(global) orelse return null;
        return .{ .traversable = bc.getTop().id, .frame = bc.parent != null };
    }

    /// The open top-level browsing context with this id.
    fn openTraversable(self: *Browser, id: u64) ?*html_mod.BrowsingContext {
        const navigables = @import("dom").browser_state.existingNavigablesIn(self.scope) orelse return null;
        const bc = navigables.byId(id) orelse return null;
        return if (isOpenTopLevel(bc)) bc else null;
    }

    fn isHostTraversable(self: *Browser, bc: *const html_mod.BrowsingContext) bool {
        const host_id = self.hostTraversableId() orelse return false;
        return bc.id == host_id;
    }

    /// A top-level browsing context still shown: not a frame's, not closed,
    /// not orphaned (a group switch's leftover).
    fn isOpenTopLevel(bc: *const html_mod.BrowsingContext) bool {
        return bc.parent == null and !bc.is_closed and !bc.orphaned and bc.active_window != null;
    }

    /// The navigable integration that drives `bc` - a popup's, or the host
    /// page's record - if it lives.
    fn integrationOf(bc: *html_mod.BrowsingContext) ?*html_mod.IFrameIntegration {
        const navigables = bc.navigables orelse return null;
        for (navigables.integrations.items) |integration| {
            if (integration.browsing_context == bc) return integration;
        }
        return null;
    }

    /// What a traversable's session history records about a document (its
    /// URL and origin, serialized), read through the interfaces - the
    /// `info_of` of BrowsingContext.ensureHistoryEntries, as History's own.
    fn historyDocumentInfo(document_ptr: *anyopaque, allocator: std.mem.Allocator) anyerror!html_mod.navigation.joint_history.DocumentInfo {
        const document: *runtime.Instance = @ptrCast(@alignCast(document_ptr));
        const url = try documentUrl(allocator, document);
        errdefer allocator.free(url);
        const window = (interfaces.Document.get_defaultView(document) catch null) orelse return .{ .url = url, .origin = try allocator.dupe(u8, "null") };
        const origin = interfaces.Window.get_origin(window) catch return .{ .url = url, .origin = try allocator.dupe(u8, "null") };
        defer window.ctx.allocator.free(origin);
        return .{ .url = url, .origin = try allocator.dupe(u8, origin) };
    }

    /// `document`'s URL, "about:blank" for none. OWNED by `allocator`.
    fn documentUrl(allocator: std.mem.Allocator, document: ?*runtime.Instance) ![]u8 {
        const d = document orelse return allocator.dupe(u8, "about:blank");
        const url = interfaces.Document.get_URL(d) catch return allocator.dupe(u8, "about:blank");
        defer d.ctx.allocator.free(url);
        return allocator.dupe(u8, if (url.len == 0) "about:blank" else url);
    }

    /// `document`'s title, "" for none. OWNED by `allocator`.
    fn documentTitle(allocator: std.mem.Allocator, document: ?*runtime.Instance) ![]u8 {
        const d = document orelse return allocator.dupe(u8, "");
        var title = interfaces.Document.get_title(d) catch return allocator.dupe(u8, "");
        defer title.deinit(d.ctx.allocator);
        return allocator.dupe(u8, title.asSlice());
    }

    // ========================================================================
    // The developer console
    // ========================================================================

    /// The host shows this Browser's developer console from now on: the
    /// console output of every realm of it - its pages, their frames and
    /// popups, its workers - and their unhandled exceptions and rejections
    /// are reported to `host` (dom.developer_console: on the realm's thread,
    /// with the console's lock held; it runs no script), and no longer
    /// printed to stderr. Until `detachDeveloperConsole`, which a host calls
    /// before it ends.
    pub fn attachDeveloperConsole(self: *Browser, host_console: developer_console.Host) !void {
        try developer_console.attach(self.scope, host_console);
    }

    /// The host no longer shows the console: no report reaches it once this
    /// returns (one under way on a worker's thread has ended).
    pub fn detachDeveloperConsole(self: *Browser) void {
        developer_console.detach(self.scope);
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
