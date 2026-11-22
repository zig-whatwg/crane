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
const cookiestore = @import("cookiestore");
const clock = @import("clock");
const host = @import("host");
/// The page agent's event loop - the host's (HTML 8.1.7).
const EventLoop = @import("event_loop.zig").EventLoop;
const Process = @import("process.zig").Process;
const platform = @import("platform");
/// What the Browser tells its host as it happens: tabs and frames.
pub const host_events = @import("host_events.zig");
/// A script value as the host API hands it out (BiDi's RemoteValue, JSON).
pub const remote_value = @import("remote_value.zig");

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
    if (engine.capabilities.html_constructor != .unsupported) hooks.htmlConstructor = html.custom_element_constructor.hooks;
    hooks.agentClusterOf = html.agent_clusters.agentClusterOf;
    hooks.crossOriginIsolatedCapability = html.agent_clusters.crossOriginIsolatedCapability;
    if (html.webassembly_streaming.supported) hooks.compilePotentialWebAssemblyResponse = html.webassembly_streaming.compilePotentialWebAssemblyResponse;
    break :blk hooks;
};

/// Browser configuration options
pub const BrowserConfig = struct {
    /// The Browser's profile directory (docs/instances.md): its stores
    /// persist under it, and it is the Browser's alone while it lives - a
    /// second live Browser given the same directory fails to start with
    /// error.ProfileInUse, as Chrome's profile lock refuses one. Null (the
    /// default): in memory, nothing written to disk. The console's
    /// --user-data-dir / --profile set it. BORROWED for `init`.
    profile_dir: ?[]const u8 = null,
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
    /// free faults instead of finding the old bytes - and kept out of reuse
    /// for a while, so the poison is still there when a stale read comes
    /// (runtime.ArenaAllocator.quarantine_freed, lane uaf1). For the WPT
    /// bug-finding runner, which poisons its allocator's frees by default
    /// (the user, 2026-11-05); off by default - never in a product build. A
    /// Debug build poisons either way, without the quarantine.
    poison_freed_state: bool = false,
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
        /// Chrome's proxy rules - `--proxy-server` / `--proxy-bypass-list`,
        /// CDP Target.createBrowserContext {proxyServer, proxyBypassList}
        /// (fetch/network/proxy_rules.zig). BORROWED until Browser.init
        /// returns: the network context keeps a copy.
        rules: *const @import("fetch").network.NetworkContext.ProxyRules,
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
    /// The tabs the host opened beside its first page (`createTab`), in the
    /// order they were made: each a page of its own (a Context) in a new
    /// browsing context group, whose realms are entered per call
    /// (engine.WindowRealmOptions.entered_for_life false) so that tabs end in
    /// any order. The first page stays `current_context`.
    tabs: std.ArrayListUnmanaged(*Context) = .empty,
    /// The tab the host last activated (`activateTab`), or the first page's.
    /// Headless, every tab is focused and visible (the tab-focus ruling,
    /// 2026-11-19): activation decides only what `activeTab` answers.
    active_tab: ?TabId = null,
    /// The host's listeners: what the Browser tells its host as it happens
    /// (host_events).
    listeners: host_events.Listeners = .{},
    /// Tabs whose navigations wait before their fetch until the host
    /// releases them (`createTab`'s hold_first_navigation, CDP's
    /// waitForDebuggerOnStart): the navigation observer's hold point
    /// (html.navigation.observer, N3), released by `releaseTab`.
    paused_tabs: std.ArrayListUnmanaged(TabId) = .empty,
    /// The open tabs the host has been told of (`tab_created`), so that
    /// each is told gone (`tab_destroyed`) exactly once.
    known_tabs: std.ArrayListUnmanaged(TabId) = .empty,
    /// Every tab a page opens from now on starts paused
    /// (`holdTabsOpenedByPages`; CDP Target.setAutoAttach
    /// {waitForDebuggerOnStart}).
    hold_page_tabs: bool = false,
    /// The agent's inspector client (installed at init when the engine has
    /// inspector_protocol), BORROWED by the engine for the agent's life.
    inspector_client: engine.InspectorClient = .{},
    /// The debugger asked its paused message loop to end
    /// (quitMessageLoopOnPause).
    debugger_quit: bool = false,
    /// Host evaluations awaiting a promise (`evaluateInTab` with
    /// await_promise): each is told its result when the promise settles, or
    /// that the Browser ended first.
    pending_evaluations: std.ArrayListUnmanaged(*PendingEvaluation) = .empty,

    /// A tab: its top-level traversable's browsing context id.
    pub const TabId = host_events.TabId;

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
        // The config turns the poison on, never off: a Debug build's scope
        // poisons already (runtime.BrowserScope.poisonsFreedStateByDefault).
        // And with it the arena's quarantine, which no default turns on: a
        // freed state block stays out of reuse, all poison, for a while
        // (runtime.ArenaAllocator.quarantine_freed).
        if (config.poison_freed_state) {
            scope.arena.poison_freed = true;
            scope.arena.quarantine_freed = true;
        }
        // The Browser's receiver for platform events first: the platform's
        // observers (memory pressure) report through it from threads of
        // their own, from the moment the platform state exists until it
        // ends, so it is the scope's earlier supplement and ends after it.
        // It has no loop to post to until `attach`, below.
        const platform_events = try @import("platform_events.zig").make(scope);
        const browser_platform = @import("html").platform_state.createWith(scope, &.{
            .platform = config.platform,
            .profile_dir = if (config.profile_dir) |dir| platform.Str.from(dir) else null,
        }, platform_events.eventSink()) catch |err| return switch (err) {
            // Another live Browser holds the profile directory.
            error.Busy => error.ProfileInUse,
            else => err,
        };
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

        // The agent's event loop, with its timers (the host's).
        const event_loop = try allocator.create(EventLoop);
        errdefer allocator.destroy(event_loop);
        event_loop.* = try EventLoop.initWithClock(agent, allocator, browser_clock);
        // The agent's deferred teardown queue, which the loop runs between
        // tasks, and its fetches, which the loop pumps.
        event_loop.deferred_teardown = &agent_host.deferred_teardown;
        event_loop.fetches = &agent_host.fetches;
        // Platform events become this loop's tasks from now on
        // (platform_events.zig); a Browser that fails to start lets go.
        if (@import("platform_events.zig").of(scope)) |platform_events| platform_events.attach(event_loop);
        errdefer if (@import("platform_events.zig").of(scope)) |platform_events| platform_events.detach();

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
                .rules => |rules| .{ .rules = rules },
                .pac, .autodetect => unreachable, // refused by init
            },
            .accept_insecure_certs = config.accept_insecure_certs,
            .http_cache = config.http_cache,
        });
        // What a response's Clear-Site-Data header clears: this Browser's
        // state, never another's (src/browser/clear_site_data.zig).
        (try scope.of(@import("fetch").network.NetworkContext)).site_data = @import("clear_site_data.zig").clearerFor(scope);

        // The profile's stores (D6, the user's ruling 2026-11-21): a Browser
        // given a profile directory persists its web state there, its
        // platform state's stores (profile_stores.zig); one with none keeps
        // it in memory, as before.
        if (scope.existing(@import("html").platform_state.PlatformState)) |state| {
            if (state.browser) |browser_platform| {
                // IndexedDB keeps its databases in the platform's stores in
                // both modes (approved 8:44 PM ET).
                try @import("profile_stores.zig").attachPlatform(scope, browser_platform);
                if (config.profile_dir) |profile_dir| try @import("profile_stores.zig").attach(scope, browser_platform, event_loop, profile_dir);
            }
        }

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
            .config = config,
            .initialized = true,
            .event_loop = event_loop,
            .used_snapshot = used_snapshot,
            .cookie_jar = cookie_jar,
            .scope = scope,
        };

        // The Browser's navigation observer (html.navigation.observer): its
        // one slot, set once to the Browser's own dispatcher, which fans each
        // milestone out to the host's listeners (host_events) and answers
        // the hold point for paused tabs.
        const navigables = try scope.table(.navigables, html_mod.Navigables);
        navigables.observer = .{ .context = browser, .notify = notifyMilestone, .hold_first_navigation = holdsNavigation };
        // And its document-start hook (html.navigation.document_start): the
        // host's scripts for each new document, fanned out the same way.
        navigables.document_start = .{ .context = browser, .run = runDocumentStart };
        // And its user prompt hook (html.navigation.user_prompts): each
        // simple dialog's opening and closing.
        navigables.user_prompts = .{ .context = browser, .opening = dialogOpening, .closed = dialogClosed };
        // And its new-window hook (html.navigation.window_open).
        navigables.window_open = .{ .context = browser, .opened = windowOpened };
        // And its first-touch hook for frames on their initial about:blank.
        navigables.frame_touched = .{ .context = browser, .touched = frameTouched };
        // The agent's inspector client (the engine protocol's
        // inspector_protocol): Runtime.runIfWaitingForDebugger releases the
        // tab's start hold, a debugger pause runs the Browser's nested
        // message loop (runtime.BrowserPause, policy .debugger), and the DOM's
        // objects get Blink's RemoteObject subtypes and descriptions
        // (inspector_values.zig: a node is subtype "node").
        if (comptime engine.capabilities.inspector_protocol != .unsupported) {
            browser.inspector_client = .{
                .host = browser,
                .runIfWaitingForDebugger = inspectorRunIfWaiting,
                .runMessageLoopOnPause = inspectorRunMessageLoopOnPause,
                .quitMessageLoopOnPause = inspectorQuitMessageLoopOnPause,
                .valueSubtype = @import("inspector_values.zig").valueSubtype,
                .descriptionForValueSubtype = @import("inspector_values.zig").description,
            };
            engine.installInspectorClient(agent, &browser.inspector_client);
        }

        // Always create initial about:blank context - a real browser always has a window/document
        // Then navigate to initial URL if specified
        const initial_url = config.initial_url orelse "about:blank";
        try browser.navigate(initial_url, .window);

        return browser;
    }

    /// Deinitialize the browser and release all resources
    ///
    /// This destroys the V8 isolate and all associated contexts.
    /// What the profile's stores have pending is written first
    /// (profile_stores.flush).
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
        // Then its popups: "destroy a top-level traversable" for each - its
        // documents destroyed, its realm ended - before the page. A popup is
        // the Browser's, no realm's child, so the page's end would leave its
        // realm alive for the agent's end (dom.auxiliary_navigables.Popups).
        @import("dom").auxiliary_navigables.closeAll(self.scope);
        // The host evaluations still awaiting a promise are told the Browser
        // ended first, while the agent lives (their reactions are dropped
        // with it).
        self.failPendingEvaluations();
        // The tabs the host opened, the last made first: "destroy a
        // top-level traversable" for each, as for the first page below - no
        // unload, as at every Browser's end (BiDi's removeUserContext closes
        // without prompting). Each realm is entered per call, so they end in
        // any order before the first page's, which is entered for its life.
        while (self.tabs.pop()) |ctx| {
            if (ctx.browsing_context) |bc| @import("dom").navigables.destroyDocumentsAtBrowserEnd(bc);
            ctx.deinit();
            self.allocator.destroy(ctx);
        }
        self.tabs.deinit(self.allocator);
        self.paused_tabs.deinit(self.allocator);
        // What the pages' end tells the host from here on reaches nobody.
        self.listeners.deinit(self.allocator);
        self.listeners = .{};
        // Destroy current context if any
        if (self.current_context) |ctx| {
            // HTML "destroy a top-level traversable" step 2: "destroy a
            // document and its descendants" - every frame's document is
            // destroyed and its fetches aborted before the realms end
            // (dom.navigables.destroyDocumentsAtBrowserEnd).
            if (ctx.browsing_context) |bc| @import("dom").navigables.destroyDocumentsAtBrowserEnd(bc);
            ctx.deinit();
            self.allocator.destroy(ctx);
            self.current_context = null;
        }
        // The page's fetches still in flight release what they hold - a
        // promise, and through it the realm - while the isolate lives.
        _ = self.agent_host.fetches.sweep();

        // What the profile's stores still have pending is written now
        // (profile_stores.zig; Chromium LocalStorageImpl::ShutDown), while
        // the event loop and the platform state live; nothing without a
        // profile directory.
        @import("profile_stores.zig").flush(self.scope);

        // Cleanup event loop. Platform events stop becoming its tasks first:
        // the platform's observers post until the platform state ends,
        // below, and a post from now on finds no loop.
        if (@import("platform_events.zig").of(self.scope)) |platform_events| platform_events.detach();
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

            // The agent's inspector client points at this Browser: gone
            // before the agent ends.
            if (comptime engine.capabilities.inspector_protocol != .unsupported) engine.installInspectorClient(agent, null);
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

        self.known_tabs.deinit(self.allocator);
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
        var replaced_tab: ?TabId = null;
        if (self.current_context) |old_ctx| {
            // The pages the back/forward cache keeps were opened from this
            // page: they leave while its realm - their realms' parent - and
            // the loop still live.
            @import("back_forward_cache.zig").evictAllIn(self.scope);
            // HTML "close a top-level traversable" for the page the fresh one
            // replaces - its tab closes - before it is destroyed: beforeunload
            // (checking if unloading is canceled), then pagehide and unload,
            // children first ("definitely close" step 3; life1's audit N7).
            // It was destroyed without them, which no browser does to a tab
            // it closes. A shown prompt the user answered "stay" leaves the
            // page as it is.
            if (unloadHostPage(old_ctx, .prompt) == .canceled) return error.CloseCanceled;
            replaced_tab = if (old_ctx.browsing_context) |bc| bc.id else null;
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
        // The host heard the fresh tab come from the navigation observer
        // (navigable_created) as it was made; the old one is told gone now
        // if its destruction did not say so.
        if (replaced_tab) |id| self.tabGone(id);
        if (ctx.browsing_context) |bc| {
            if (self.active_tab == null or self.active_tab == replaced_tab) self.active_tab = bc.id;
        }
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
    // The host opens tabs of its own beside its first page (`createTab`):
    // each a host-made top-level traversable in a new browsing context
    // group, whose realms are entered per call - only the first page's is
    // entered for its life - so that tabs close in any order (lane console's
    // HOST-OPENED TABS design; lane cdph).

    /// One top-level traversable, as `traversables` lists it.
    pub const TraversableInfo = struct {
        /// Its top-level browsing context's id.
        id: u64,
        /// Its active document's URL and title. OWNED (`freeTraversables`).
        url: []u8,
        title: []u8,
        /// Who made it: the host (the Browser's first page, or a tab it
        /// opened), or a page's script (a popup).
        made_by: host_events.MadeBy,
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
                .made_by = if (self.isHostTraversable(bc)) .host else .page,
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
        if (self.hostContextOf(bc)) |ctx| return ctx.navigate(serialized);
        const integration = integrationOf(bc) orelse return error.NoSuchTraversable;
        // A "browser UI" navigation: no sourceDocument, the user's own
        // (navigate step 5) - as the host page's address bar navigates.
        integration.navigate(serialized, .{ .browser_ui = true });
    }

    /// What `navigateNavigable` carries besides its URL (N5: CDP
    /// Page.navigate's `referrer` and `referrerPolicy`).
    pub const NavigateNavigableOptions = struct {
        /// The request's referrer, a URL. BORROWED for the call.
        referrer: ?[]const u8 = null,
        referrer_policy: @import("fetch").internal.ReferrerPolicy = .empty,
    };

    /// HTML "navigate" navigable `id` - a tab, or a frame in one - to `url`
    /// as the browser's UI does (user involvement "browser UI", no
    /// sourceDocument), with `options`' referrer: CDP Page.navigate,
    /// whatever frame it names (Chrome: NavigationController::LoadURL on
    /// that frame's FrameTreeNode). The navigation runs as tasks; returns
    /// the id of the cross-document navigation it started (the navigation
    /// observer's navigation_id, CDP's loaderId), or 0 when none started (a
    /// fragment navigation, one refused). error.NoSuchTab for an id that
    /// names no live navigable of this Browser; error.InvalidUrl.
    pub fn navigateNavigable(self: *Browser, id: u64, url: []const u8, options: NavigateNavigableOptions) !u64 {
        const navigables = @import("dom").browser_state.existingNavigablesIn(self.scope) orelse return error.NoSuchTab;
        const bc = navigables.byId(id) orelse return error.NoSuchTab;
        if (bc.is_closed or bc.active_window == null) return error.NoSuchTab;
        const serialized = serializedUrl(self.allocator, url) orelse return error.InvalidUrl;
        defer self.allocator.free(serialized);
        if (bc.parent == null) if (self.hostContextOf(bc)) |ctx| {
            return ctx.navigateWithOptions(serialized, .{ .referrer = options.referrer, .referrer_policy = options.referrer_policy });
        };
        const integration = integrationOf(bc) orelse return error.NoSuchTab;
        var started: u64 = 0;
        integration.navigate(serialized, .{
            .browser_ui = true,
            .referrer_url = options.referrer,
            .referrer_policy = options.referrer_policy,
            .started_navigation_id = &started,
        });
        return started;
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

    /// HTML "close a top-level traversable" for `id` as a page's
    /// window.close() would - prompting to unload: its documents are asked
    /// about unloading (beforeunload), unloaded and destroyed, and its
    /// browsing context closed - a popup, or a tab the host opened
    /// (`closeTab`). The Browser's first page closes only with the Browser
    /// (or `closeTab`): error.HostTraversable.
    pub fn closeTraversable(self: *Browser, id: u64) !void {
        const bc = self.openTraversable(id) orelse return error.NoSuchTraversable;
        if (self.isFirstPage(bc)) return error.HostTraversable;
        self.closeTab(id, .{ .prompt_unload = true }) catch |err| switch (err) {
            error.NoSuchTab => return error.NoSuchTraversable,
            else => return err,
        };
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

    /// Whether `bc` is a traversable the host made: its first page, or a tab
    /// it opened.
    fn isHostTraversable(self: *Browser, bc: *const html_mod.BrowsingContext) bool {
        return self.hostContextOf(bc) != null;
    }

    /// Whether `bc` is the Browser's first page's (`current_context`).
    fn isFirstPage(self: *Browser, bc: *const html_mod.BrowsingContext) bool {
        const host_id = self.hostTraversableId() orelse return false;
        return bc.id == host_id;
    }

    /// The page (Context) the host made for `bc`: its first page, or a tab
    /// it opened. Null for a popup.
    fn hostContextOf(self: *Browser, bc: *const html_mod.BrowsingContext) ?*Context {
        if (self.current_context) |ctx| if (ctx.browsing_context) |own| if (own == bc) return ctx;
        for (self.tabs.items) |ctx| {
            if (ctx.browsing_context) |own| if (own == bc) return ctx;
        }
        return null;
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
    // Tabs: the host API (instances design 5.1, roadmap `instances` item
    // "Host API"; lane cdph). On the Browser's thread, from outside script;
    // BrowserHost runs them there for a host on another thread.
    // ========================================================================

    /// One tab, as `listTabs` lists it.
    pub const TabInfo = TraversableInfo;

    pub const CreateTabOptions = struct {
        /// Where its first navigation goes; null or "about:blank": it stays
        /// on its initial about:blank document, as a new tab opened at
        /// about:blank does. Parsed with the basic URL parser
        /// (error.InvalidUrl when it is no absolute URL).
        url: ?[]const u8 = null,
        /// Not made the active tab (WebDriver BiDi browsingContext.create
        /// `background`, CDP Target.createTarget `background`).
        background: bool = false,
        /// Its first navigation waits until the host releases it
        /// (`releaseTab`): CDP's Target.setAutoAttach waitForDebuggerOnStart,
        /// Chrome's TargetHandler throttle - the runner attaches before the
        /// page runs anything.
        hold_first_navigation: bool = false,
    };

    /// Open a tab: HTML "create a fresh top-level traversable" - "create a
    /// new top-level traversable" with a null opener, so a browsing context
    /// and its initial about:blank document of a new opaque origin in a new
    /// browsing context group (a top-level browsing context's own: the tab
    /// shares no group with the Browser's other tabs), in a realm of its own
    /// entered per call - then HTML "navigate" it to `options.url` with user
    /// involvement "browser UI" (the navigation runs as tasks of the loop).
    /// The host hears `tab_created` before the navigation starts. Its id is
    /// its top-level browsing context's, for its life.
    pub fn createTab(self: *Browser, options: CreateTabOptions) !TabId {
        const agent = self.agent orelse return error.NotInitialized;
        const requested = options.url orelse "about:blank";
        const serialized = serializedUrl(self.allocator, requested) orelse return error.InvalidUrl;
        defer self.allocator.free(serialized);
        try self.tabs.ensureUnusedCapacity(self.allocator, 1);
        const ctx = try Context.initWithOptions(
            self.allocator,
            agent,
            self.cookie_jar,
            "about:blank",
            self.event_loop,
            .window,
            self.used_snapshot,
            self.scope,
            .{ .entered_for_life = false },
        );
        const bc = ctx.browsing_context orelse {
            ctx.deinit();
            self.allocator.destroy(ctx);
            return error.ContextCreateFailed;
        };
        const id = bc.id;
        self.tabs.appendAssumeCapacity(ctx);
        if (!options.background or self.active_tab == null) self.active_tab = id;
        // The host heard `tab_created` as the traversable was made (the
        // navigation observer's navigable_created). A held tab's navigation
        // parks at the observer's hold point, after beforeunload and before
        // its fetch (N3), until `releaseTab`.
        if (options.hold_first_navigation) try self.paused_tabs.append(self.allocator, id);
        if (std.mem.eql(u8, serialized, "about:blank")) return id;
        try ctx.navigate(serialized);
        return id;
    }

    pub const CloseTabOptions = struct {
        /// Prompt to unload first: the beforeunload event at each of its
        /// documents (HTML "definitely close" step 2) - BiDi
        /// browsingContext.close {promptUnload: true}, CDP Page.close. False
        /// (CDP Target.closeTarget, BiDi's default): unload runs, beforeunload
        /// does not, as Chrome's WebContentsImpl::ClosePage.
        prompt_unload: bool = false,
    };

    /// HTML "close a top-level traversable" for tab `tab` - one the host
    /// opened, its first page, or a popup a page made - then it is
    /// destroyed: its documents unloaded (pagehide, unload) and destroyed,
    /// its browsing context closed, and a host-made tab's realm ended. The
    /// host hears `tab_destroyed` after. error.NoSuchTab when no open tab
    /// has that id; error.CloseCanceled when a shown beforeunload prompt was
    /// answered "stay" (nothing changed).
    pub fn closeTab(self: *Browser, tab: TabId, options: CloseTabOptions) !void {
        const bc = self.openTraversable(tab) orelse return error.NoSuchTab;
        const prompt: @import("dom").auxiliary_navigables.Prompt = if (options.prompt_unload) .prompt else .skip;
        if (self.hostContextOf(bc)) |ctx| {
            if (unloadHostPage(ctx, prompt) == .canceled) return error.CloseCanceled;
            self.endHostPage(ctx);
        } else {
            const window: *runtime.Instance = @ptrCast(@alignCast(bc.getActiveWindow() orelse return error.NoSuchTab));
            switch (@import("dom").auxiliary_navigables.definitelyClose(window, prompt)) {
                .not_top_level => return error.NoSuchTab,
                .canceled => return error.CloseCanceled,
                .closed => {},
            }
        }
        self.tabGone(tab);
    }

    /// Release tab `tab`'s navigations held before their fetch (CDP
    /// Runtime.runIfWaitingForDebugger): it is no longer paused, and a
    /// navigation parked at the hold point goes on from a task
    /// (html.navigation.observer.release). Nothing for a tab not paused.
    pub fn releaseTab(self: *Browser, tab: TabId) void {
        const index = self.pausedIndex(tab) orelse return;
        _ = self.paused_tabs.orderedRemove(index);
        const navigables = @import("dom").browser_state.existingNavigablesIn(self.scope) orelse return;
        html_mod.navigation.observer.release(navigables, tab);
    }

    /// Whether tab `tab` is paused (its navigations wait for `releaseTab`).
    pub fn isTabHeld(self: *Browser, tab: TabId) bool {
        return self.pausedIndex(tab) != null;
    }

    /// Every tab a page opens from now on (window.open, a link's or form's
    /// target) starts paused until `releaseTab` - CDP's
    /// Target.setAutoAttach {waitForDebuggerOnStart: true} - or, with
    /// false, starts as usual.
    pub fn holdTabsOpenedByPages(self: *Browser, hold: bool) void {
        self.hold_page_tabs = hold;
    }

    /// Make tab `tab` the active one (BiDi browsingContext.activate, CDP
    /// Target.activateTarget). Headless, every tab is focused and visible
    /// already (the tab-focus ruling, 2026-11-19): this changes what
    /// `activeTab` answers, and nothing a page can observe.
    pub fn activateTab(self: *Browser, tab: TabId) !void {
        _ = self.openTraversable(tab) orelse return error.NoSuchTab;
        self.active_tab = tab;
    }

    /// The tab the host last activated, while it is open; else the first
    /// open one; null with none.
    pub fn activeTab(self: *Browser) ?TabId {
        if (self.active_tab) |id| if (self.openTraversable(id) != null) return id;
        var first: [1]u64 = undefined;
        return if (self.traversableIds(&first) > 0) first[0] else null;
    }

    /// Every open tab: the first page's, then the others in the order they
    /// were made. OWNED: `freeTabs`.
    pub fn listTabs(self: *Browser, allocator: std.mem.Allocator) ![]TabInfo {
        return self.traversables(allocator);
    }

    pub fn freeTabs(allocator: std.mem.Allocator, tabs: []TabInfo) void {
        freeTraversables(allocator, tabs);
    }

    /// The realm of tab `tab`'s active Window, or null.
    pub fn tabRealm(self: *Browser, tab: TabId) ?runtime.Context {
        return self.traversableRealm(tab);
    }

    /// `listener` hears the Browser's events from now on (host_events), on
    /// this thread, until `removeListener`.
    pub fn addListener(self: *Browser, listener: host_events.Listener) !void {
        try self.listeners.add(self.allocator, listener);
    }

    pub fn removeListener(self: *Browser, listener: host_events.Listener) void {
        self.listeners.remove(listener);
    }

    /// One navigable and its descendants, as `navigableTree` gives them
    /// (WebDriver BiDi browsingContext.Info).
    pub const NavigableInfo = struct {
        id: u64,
        /// Its parent navigable; null for a tab.
        parent: ?u64,
        /// The traversable whose page opened it (a tab only).
        opener: ?u64,
        /// Its active document's URL. OWNED.
        url: []u8,
        /// Its child navigables, to the depth asked for. OWNED.
        children: []NavigableInfo,
    };

    /// BiDi browsingContext.getTree: every open tab with its frames, or the
    /// navigable `root` (a tab or a frame) and its descendants, each to
    /// `max_depth` levels below it (null: all). OWNED: `freeNavigableTree`.
    /// error.NoSuchTab for a `root` that names no open navigable.
    pub fn navigableTree(self: *Browser, allocator: std.mem.Allocator, root: ?u64, max_depth: ?u32) ![]NavigableInfo {
        var list: std.ArrayListUnmanaged(NavigableInfo) = .empty;
        errdefer {
            for (list.items) |*info| freeNavigableInfo(allocator, info);
            list.deinit(allocator);
        }
        if (root) |id| {
            const navigables = @import("dom").browser_state.existingNavigablesIn(self.scope) orelse return error.NoSuchTab;
            const bc = navigables.byId(id) orelse return error.NoSuchTab;
            if (bc.is_closed or bc.active_window == null) return error.NoSuchTab;
            try list.append(allocator, try navigableInfoOf(allocator, bc, max_depth));
        } else {
            var ids: [256]u64 = undefined;
            const count = @min(self.traversableIds(&ids), ids.len);
            for (ids[0..count]) |id| {
                const bc = self.openTraversable(id) orelse continue;
                try list.append(allocator, try navigableInfoOf(allocator, bc, max_depth));
            }
        }
        return list.toOwnedSlice(allocator);
    }

    pub fn freeNavigableTree(allocator: std.mem.Allocator, tree: []NavigableInfo) void {
        for (tree) |*info| freeNavigableInfo(allocator, info);
        allocator.free(tree);
    }

    fn freeNavigableInfo(allocator: std.mem.Allocator, info: *NavigableInfo) void {
        for (info.children) |*child| freeNavigableInfo(allocator, child);
        allocator.free(info.children);
        allocator.free(info.url);
    }

    fn navigableInfoOf(allocator: std.mem.Allocator, bc: *html_mod.BrowsingContext, depth_left: ?u32) !NavigableInfo {
        const document: ?*runtime.Instance = if (bc.getActiveDocument()) |d| @ptrCast(@alignCast(d)) else null;
        const url = try documentUrl(allocator, document);
        errdefer allocator.free(url);
        var children: std.ArrayListUnmanaged(NavigableInfo) = .empty;
        errdefer {
            for (children.items) |*child| freeNavigableInfo(allocator, child);
            children.deinit(allocator);
        }
        const descend = if (depth_left) |left| left > 0 else true;
        if (descend) {
            for (bc.children.items) |child| {
                if (child.is_closed or child.active_window == null) continue;
                try children.append(allocator, try navigableInfoOf(allocator, child, if (depth_left) |left| left - 1 else null));
            }
        }
        const opener: ?u64 = if (bc.parent == null) (if (bc.opener) |o| (if (!bc.disowned and isOpenTopLevel(o)) o.id else null) else null) else null;
        return .{
            .id = bc.id,
            .parent = if (bc.parent) |p| p.id else null,
            .opener = opener,
            .url = url,
            .children = try children.toOwnedSlice(allocator),
        };
    }

    /// What `evaluateInTab` evaluates with.
    pub const EvaluateOptions = struct {
        /// When the completion value is a promise, wait for it to settle and
        /// answer its value or its reason (BiDi script.evaluate awaitPromise).
        await_promise: bool = false,
        /// The tab's document gets an activation notification first, as a
        /// user's input would give it (BiDi script.evaluate userActivation;
        /// HTML 6.4.3 "activation notification").
        user_activation: bool = false,
        /// How deep arrays and objects are serialized (remote_value).
        max_depth: u32 = 1,
    };

    /// An evaluation's answer: a BiDi script.RemoteValue (`success`), or an
    /// exception's details (`exception`: {"text", "url", "lineNumber",
    /// "columnNumber", "exception": RemoteValue}). `json` is BORROWED for
    /// the callback.
    pub const EvaluateResult = struct {
        kind: enum { success, exception },
        json: []const u8,
    };

    /// Who hears an evaluation's answer, on the Browser's thread - at once,
    /// or when its promise settles. error.NoSuchTab, error.BrowserEnded (the
    /// Browser ended first), error.RealmEnded (the tab's document went
    /// first), or an engine error.
    pub const EvaluateCallback = struct {
        context: *anyopaque,
        done: *const fn (context: *anyopaque, result: anyerror!EvaluateResult) void,
    };

    /// Evaluate `source` as a classic script in tab `tab`'s active document's
    /// realm (BiDi script.evaluate, the host API's `evaluate`): its
    /// completion value, or what it threw - the host's script, never
    /// reported to the page's Window. `callback` hears the answer exactly
    /// once.
    pub fn evaluateInTab(self: *Browser, tab: TabId, source: []const u8, options: EvaluateOptions, callback: EvaluateCallback) void {
        const realm = self.tabRealm(tab) orelse return callback.done(callback.context, error.NoSuchTab);
        if (options.user_activation) {
            if (self.traversableWindow(tab)) |window| {
                if (interfaces.Window.get_document(window)) |document| html_mod.user_activation.notifyActivation(document) else |_| {}
            }
        }
        var capture: ExceptionCapture = .{ .allocator = self.allocator, .realm = realm, .max_depth = options.max_depth };
        defer capture.deinit();
        const completion = engine.evaluateClassicScript(realm, .{ .utf8 = source }, "", null, .{ .report = ExceptionCapture.report, .host = &capture }) catch |err| {
            if (capture.json) |details| return callback.done(callback.context, .{ .kind = .exception, .json = details });
            return callback.done(callback.context, err);
        };
        defer completion.release();
        if (options.await_promise) {
            // BiDi script.evaluate: "If awaitPromise is true and
            // evaluationStatus.[[Value]] is a Promise" - PromiseResolve
            // answers the same object for a promise of %Promise%, so the
            // two are the same value exactly then.
            if (engine.promiseResolve(realm, completion.borrow())) |resolved| switch (resolved) {
                .normal => |promise| {
                    defer promise.release();
                    if (engine.sameValue(realm, promise.borrow(), completion.borrow())) {
                        return self.awaitEvaluation(realm, promise.borrow(), options, callback);
                    }
                },
                .throw => |thrown| thrown.release(),
            } else |_| {}
        }
        const json = remote_value.serialize(self.allocator, realm, completion.borrow(), .{ .max_depth = options.max_depth }) catch |err| return callback.done(callback.context, err);
        defer self.allocator.free(json);
        callback.done(callback.context, .{ .kind = .success, .json = json });
    }

    fn awaitEvaluation(self: *Browser, realm: runtime.Context, promise: runtime.JSValue, options: EvaluateOptions, callback: EvaluateCallback) void {
        const pending = self.allocator.create(PendingEvaluation) catch return callback.done(callback.context, error.OutOfMemory);
        pending.* = .{ .browser = self, .allocator = self.allocator, .realm = realm, .callback = callback, .max_depth = options.max_depth };
        self.pending_evaluations.append(self.allocator, pending) catch {
            self.allocator.destroy(pending);
            return callback.done(callback.context, error.OutOfMemory);
        };
        engine.reactToPromise(realm, promise, &PendingEvaluation.steps, pending) catch |err| {
            _ = self.pending_evaluations.pop();
            self.allocator.destroy(pending);
            return callback.done(callback.context, err);
        };
    }

    /// Every host evaluation still awaiting a promise hears that the Browser
    /// ended; its reaction, which the engine drops with the agent, then only
    /// frees it.
    fn failPendingEvaluations(self: *Browser) void {
        while (self.pending_evaluations.pop()) |pending| {
            pending.browser = null;
            const callback = pending.callback;
            pending.answered = true;
            callback.done(callback.context, error.BrowserEnded);
        }
        self.pending_evaluations.deinit(self.allocator);
    }

    /// One host evaluation awaiting its promise.
    const PendingEvaluation = struct {
        /// Null once the Browser ended (it answered the callback then).
        browser: ?*Browser,
        allocator: std.mem.Allocator,
        realm: runtime.Context,
        callback: EvaluateCallback,
        max_depth: u32,
        answered: bool = false,

        const steps: engine.PromiseReactionSteps = .{ .fulfilled = fulfilled, .rejected = rejected, .dropped = dropped };

        fn fulfilled(data: ?*anyopaque, value: runtime.JSValue) void {
            const self: *PendingEvaluation = @ptrCast(@alignCast(data.?));
            self.answer(.success, value);
        }

        fn rejected(data: ?*anyopaque, reason: runtime.JSValue) void {
            const self: *PendingEvaluation = @ptrCast(@alignCast(data.?));
            self.answer(.exception, reason);
        }

        /// The reaction ended unrun: the tab's realm ended, or the agent.
        fn dropped(data: ?*anyopaque) void {
            const self: *PendingEvaluation = @ptrCast(@alignCast(data.?));
            if (!self.answered) {
                self.answered = true;
                self.forget();
                self.callback.done(self.callback.context, error.RealmEnded);
            }
            self.allocator.destroy(self);
        }

        fn answer(self: *PendingEvaluation, kind: @FieldType(EvaluateResult, "kind"), value: runtime.JSValue) void {
            defer self.allocator.destroy(self);
            if (self.answered) return;
            self.answered = true;
            self.forget();
            const json = switch (kind) {
                .success => remote_value.serialize(self.allocator, self.realm, value, .{ .max_depth = self.max_depth }),
                .exception => exceptionDetailsJson(self.allocator, self.realm, "Uncaught (in promise)", "", 0, 0, value, self.max_depth),
            } catch |err| return self.callback.done(self.callback.context, err);
            defer self.allocator.free(json);
            self.callback.done(self.callback.context, .{ .kind = kind, .json = json });
        }

        fn forget(self: *PendingEvaluation) void {
            const browser = self.browser orelse return;
            for (browser.pending_evaluations.items, 0..) |item, i| {
                if (item != self) continue;
                _ = browser.pending_evaluations.swapRemove(i);
                return;
            }
        }
    };

    /// What a host evaluation threw, as exception details JSON.
    const ExceptionCapture = struct {
        allocator: std.mem.Allocator,
        realm: runtime.Context,
        max_depth: u32,
        json: ?[]u8 = null,

        fn report(capture: ?*anyopaque, info: *const engine.ErrorInfo) void {
            const self: *ExceptionCapture = @ptrCast(@alignCast(capture.?));
            if (self.json != null) return;
            self.json = exceptionDetailsJson(self.allocator, info.realm orelse self.realm, info.message, info.filename, info.lineno, info.colno, info.error_value, self.max_depth) catch null;
        }

        fn deinit(self: *ExceptionCapture) void {
            if (self.json) |json| self.allocator.free(json);
        }
    };

    fn exceptionDetailsJson(allocator: std.mem.Allocator, realm: runtime.Context, text: []const u8, url: []const u8, line: u32, column: u32, exception: runtime.JSValue, max_depth: u32) ![]u8 {
        const value = try remote_value.serialize(allocator, realm, exception, .{ .max_depth = max_depth });
        defer allocator.free(value);
        var out: std.Io.Writer.Allocating = .init(allocator);
        errdefer out.deinit();
        try out.writer.writeAll("{\"text\":");
        try std.json.Stringify.encodeJsonString(text, .{}, &out.writer);
        try out.writer.writeAll(",\"url\":");
        try std.json.Stringify.encodeJsonString(url, .{}, &out.writer);
        try out.writer.print(",\"lineNumber\":{d},\"columnNumber\":{d},\"exception\":{s}}}", .{ line, column, value });
        return out.toOwnedSlice();
    }

    /// HTML "close a top-level traversable" for a page the host made, up to
    /// its destruction, which is the host's (`endHostPage`): beforeunload
    /// when `prompt` asks for it, then pagehide and unload, children first,
    /// and its documents destroyed (dom.auxiliary_navigables.definitelyClose,
    /// whose host-page branch leaves the page to its host).
    fn unloadHostPage(ctx: *Context, prompt: @import("dom").auxiliary_navigables.Prompt) @import("dom").auxiliary_navigables.CloseOutcome {
        const bc = ctx.browsing_context orelse return .closed;
        const window: *runtime.Instance = @ptrCast(@alignCast(bc.getActiveWindow() orelse return .closed));
        return @import("dom").auxiliary_navigables.definitelyClose(window, prompt);
    }

    /// "Destroy a top-level traversable" for a page the host made, once it
    /// is unloaded: its realm ended (Context.deinit), its fetches let go.
    fn endHostPage(self: *Browser, ctx: *Context) void {
        // The pages the back/forward cache keeps leave first, while their
        // realms' parents and the loop live - the Browser's, all of them, as
        // Browser.navigate does (a cached page's realm may be a child of the
        // page that ends).
        @import("back_forward_cache.zig").evictAllIn(self.scope);
        if (self.current_context == ctx) {
            self.current_context = null;
        } else for (self.tabs.items, 0..) |tab, i| {
            if (tab != ctx) continue;
            _ = self.tabs.orderedRemove(i);
            break;
        }
        ctx.deinit();
        self.allocator.destroy(ctx);
        // Fetch's "terminate a fetch group" for the page that ended, now.
        _ = self.agent_host.fetches.sweep();
        if (self.event_loop) |event_loop| _ = event_loop.drainCloseCallbacks();
    }

    /// Tab `tab` is gone: no longer paused, another tab active if it was,
    /// and the host told (`tab_destroyed`, after the close steps) unless the
    /// navigation observer told it already.
    fn tabGone(self: *Browser, tab: TabId) void {
        if (self.pausedIndex(tab)) |index| _ = self.paused_tabs.orderedRemove(index);
        if (self.active_tab == tab) self.active_tab = null;
        if (self.forgetKnownTab(tab)) self.listeners.emit(.{ .tab_destroyed = .{ .tab = tab } });
    }

    fn pausedIndex(self: *Browser, tab: TabId) ?usize {
        return std.mem.indexOfScalar(TabId, self.paused_tabs.items, tab);
    }

    /// Whether `tab` was known (and now is not).
    fn forgetKnownTab(self: *Browser, tab: TabId) bool {
        const index = std.mem.indexOfScalar(TabId, self.known_tabs.items, tab) orelse return false;
        _ = self.known_tabs.swapRemove(index);
        return true;
    }

    // ------------------------------------------------------------------------
    // The navigation observer's dispatcher
    // ------------------------------------------------------------------------

    /// html.navigation.observer: one milestone of one of the Browser's
    /// navigables, at its spec step. A navigable made or destroyed is told
    /// to the host as a tab or a frame first; then every milestone is passed
    /// on as it is. Records and fans out only: no script runs here.
    fn notifyMilestone(context: *anyopaque, milestone: *const html_mod.navigation.observer.Milestone) void {
        const self: *Browser = @ptrCast(@alignCast(context));
        const id = milestone.navigable_id;
        switch (milestone.event) {
            .navigable_created => |created| if (created.parent_id) |parent| {
                self.listeners.emit(.{ .frame_created = .{ .navigable = id, .parent = parent } });
            } else {
                self.known_tabs.append(self.allocator, id) catch {};
                // CDP's waitForDebuggerOnStart: a popup starts paused.
                if (created.created_by == .page and self.hold_page_tabs and self.pausedIndex(id) == null) {
                    self.paused_tabs.append(self.allocator, id) catch {};
                }
                self.listeners.emit(.{ .tab_created = .{
                    .tab = id,
                    .opener = created.opener_id,
                    .made_by = switch (created.created_by) {
                        .host => .host,
                        .page => .page,
                    },
                } });
            },
            .navigable_destroyed => if (self.forgetKnownTab(id)) {
                if (self.pausedIndex(id)) |index| _ = self.paused_tabs.orderedRemove(index);
                self.listeners.emit(.{ .tab_destroyed = .{ .tab = id } });
            } else {
                self.listeners.emit(.{ .frame_destroyed = .{ .navigable = id } });
            },
            else => {},
        }
        self.listeners.emit(.{ .navigation = milestone });
    }

    /// html.navigation.document_start: a new document of one of the
    /// Browser's navigables is ready for host scripts, before its own run -
    /// passed to the listeners, which may run script for it.
    fn runDocumentStart(context: *anyopaque, start: *const html_mod.navigation.document_start.Start) void {
        const self: *Browser = @ptrCast(@alignCast(context));
        self.listeners.emit(.{ .document_start = start });
    }

    /// html.navigation.user_prompts: a simple dialog opens - told to the
    /// listeners (host_events' dialog_opening), before this thread pauses.
    fn dialogOpening(context: *anyopaque, opening: *const html_mod.navigation.user_prompts.Opening) void {
        const self: *Browser = @ptrCast(@alignCast(context));
        self.listeners.emit(.{ .dialog_opening = opening });
    }

    /// html.navigation.user_prompts: the dialog closed.
    fn dialogClosed(context: *anyopaque, closed: *const html_mod.navigation.user_prompts.Closed) void {
        const self: *Browser = @ptrCast(@alignCast(context));
        self.listeners.emit(.{ .dialog_closed = closed });
    }

    /// html_core BrowsingContext.touchedByScript: script reached a frame's
    /// initial about:blank Window for the first time.
    fn frameTouched(context: *anyopaque, navigable: u64) void {
        const self: *Browser = @ptrCast(@alignCast(context));
        self.listeners.emit(.{ .frame_touched = .{ .navigable = navigable } });
    }

    /// html.navigation.window_open: a page asks for a new window, before it
    /// is made.
    fn windowOpened(context: *anyopaque, opened: *const html_mod.navigation.window_open.Opened) void {
        const self: *Browser = @ptrCast(@alignCast(context));
        self.listeners.emit(.{ .window_open = opened });
    }

    /// The inspector client's runIfWaitingForDebugger: group `group` is a
    /// tab (devtools contexts.groupOf), whose start hold goes.
    fn inspectorRunIfWaiting(client_host: ?*anyopaque, group: engine.InspectorGroup) void {
        const self: *Browser = @ptrCast(@alignCast(client_host orelse return));
        self.releaseTab(group);
    }

    /// The inspector client's runMessageLoopOnPause: the debugger paused
    /// script of tab `group`. This thread blocks in a nested loop that runs
    /// only the session messages posted to it (BrowserHost.postSessionMessage
    /// - the inspector's, which resume or step) until quitMessageLoopOnPause:
    /// no task, timer or rendering runs meanwhile. Blink's
    /// MainThreadDebugger::runMessageLoopOnPause -> ClientMessageLoop::Run
    /// (third_party/blink/renderer/core/inspector/main_thread_debugger.cc;
    /// BSD-3, reproduced, not copied).
    fn inspectorRunMessageLoopOnPause(client_host: ?*anyopaque, group: engine.InspectorGroup) void {
        _ = group;
        const self: *Browser = @ptrCast(@alignCast(client_host orelse return));
        const pause = self.scope.of(runtime.BrowserPause) catch return;
        self.debugger_quit = false;
        const Quit = struct {
            fn met(context: *anyopaque) bool {
                const browser: *Browser = @ptrCast(@alignCast(context));
                return browser.debugger_quit;
            }
        };
        pause.pauseUntil(.{ .context = self, .met = Quit.met }, .debugger);
    }

    /// The inspector client's quitMessageLoopOnPause (Debugger.resume, a
    /// step): the nested loop ends after the message that asked.
    fn inspectorQuitMessageLoopOnPause(client_host: ?*anyopaque) void {
        const self: *Browser = @ptrCast(@alignCast(client_host orelse return));
        self.debugger_quit = true;
        if (self.scope.existing(runtime.BrowserPause)) |pause| pause.notify();
    }

    /// html.navigation.observer: whether navigable `navigable_id`'s
    /// navigation waits before its fetch - while its tab is paused.
    fn holdsNavigation(context: *anyopaque, navigable_id: u64) bool {
        const self: *Browser = @ptrCast(@alignCast(context));
        return self.pausedIndex(navigable_id) != null;
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
    var browser = Browser.init(allocator, .{}) catch |err| {
        // V8 not available in test environment
        if (err == error.V8InitFailed) return;
        return err;
    };
    defer browser.deinit();

    try testing.expect(browser.isInitialized());
    try testing.expect(browser.getAgent() != null);
}
