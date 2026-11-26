//! One MCP client's view of the browser (chrome-devtools-mcp's McpContext,
//! src/McpContext.ts at chrome-devtools-mcp-v1.13.0): the pages it knows,
//! each with an id it hands out in order of discovery (McpContext's
//! `nextPageId`), the selected page, and what each page's collectors have
//! seen. It attaches as Puppeteer does on connecting - target discovery and
//! flat auto-attach on the browser session - and keeps its records from the
//! events that come (client.EventSink).

const std = @import("std");
const Allocator = std.mem.Allocator;
const client_mod = @import("client.zig");
const Client = client_mod.Client;
const LocalLink = @import("../server.zig").LocalLink;
const collectors = @import("collectors.zig");
const console = @import("console.zig");
const network = @import("network.zig");
const keyboard_mod = @import("keyboard.zig");
const snapshot_mod = @import("snapshot.zig");
const paths_mod = @import("paths.zig");
const logpoints_mod = @import("logpoints.zig");
const heap_snapshot_mod = @import("heap_snapshot.zig");

const log = std.log.scoped(.mcp);

/// How long a command may take before the tool reports a timeout.
pub const command_timeout_ms: u32 = 30_000;

/// A dialog open on a page (Page.javascriptDialogOpening).
/// McpPage.emulationSettings, the settings Crane applies. Strings OWNED.
pub const Emulation = struct {
    network_conditions: ?[]u8 = null,
    cpu_throttling_rate: f64 = 1,
    geolocation: ?Geolocation = null,
    viewport: ?Viewport = null,
    user_agent: ?[]u8 = null,
    color_scheme: ?[]u8 = null,
    forced_colors: ?[]u8 = null,
    prefers_contrast: ?[]u8 = null,
    prefers_reduced_motion: ?[]u8 = null,

    pub const Geolocation = struct {
        latitude: f64,
        longitude: f64,
    };

    /// McpPage's NAVIGATION_TIMEOUT (10 s) scaled by network conditions and CPU throttling.
    pub const base_navigation_timeout_ms: u32 = 10_000;

    /// chrome-devtools-mcp's getNetworkMultiplierFromString
    /// (src/utils/WaitForHelper.ts, chrome-devtools-mcp-v1.13.0, Apache-2.0).
    pub fn networkMultiplier(network_conditions: ?[]const u8) f64 {
        const name = network_conditions orelse return 1;
        if (std.mem.eql(u8, name, "Fast 4G")) return 1;
        if (std.mem.eql(u8, name, "Slow 4G")) return 2.5;
        if (std.mem.eql(u8, name, "Fast 3G")) return 5;
        if (std.mem.eql(u8, name, "Slow 3G")) return 10;
        return 1;
    }

    /// McpPage.updateTimeouts' defaultNavigationTimeout (ms):
    /// `NAVIGATION_TIMEOUT * networkMultiplier * cpuMultiplier`.
    pub fn defaultNavigationTimeoutMs(network_conditions: ?[]const u8, cpu_throttling_rate: f64) u32 {
        const cpu_mult = if (cpu_throttling_rate > 1) cpu_throttling_rate else 1;
        return @intFromFloat(@as(f64, @floatFromInt(base_navigation_timeout_ms)) * networkMultiplier(network_conditions) * cpu_mult);
    }

    /// viewportTransform's object spread over McpPage's defaults.
    pub const Viewport = struct {
        width: i64,
        height: i64,
        /// Null when the text named none: zod keeps the undefined key,
        /// which the spread over the default of 1 then carries.
        scale: ?f64 = null,
        mobile: bool = false,
        landscape: bool = false,
        touch: bool = false,
    };

    pub fn deinit(self: *Emulation, allocator: Allocator) void {
        inline for (.{ "network_conditions", "user_agent", "color_scheme", "forced_colors", "prefers_contrast", "prefers_reduced_motion" }) |field| {
            if (@field(self, field)) |s| allocator.free(s);
        }
        self.* = .{};
    }
};

pub const Dialog = struct {
    /// alert, confirm, prompt or beforeunload. OWNED.
    type: []u8,
    message: []u8,
    default_prompt: []u8,
};

/// What a tool's action led to, while WaitForHelper.waitForEventsAfterAction
/// watches (chrome-devtools-mcp src/utils/WaitForHelper.ts; wait.zig).
pub const Watch = struct {
    page: *Page,
    /// handleDialog: one action for every dialog, or one per type
    /// (alert, confirm, prompt, beforeunload); null: none, the wait ends.
    dialog_action: DialogAction = .{},
    /// frameStartedNavigating (not same-document) or
    /// frameRequestedNavigation for the main frame.
    navigation_started: bool = false,
    /// Page.frameNavigated for the main frame: a new document.
    loaded_new_document: bool = false,
    /// The new document's load (waitForNavigation's 'load').
    navigation_finished: bool = false,
    dialog_detected: bool = false,
    dialog_handled: bool = false,
    /// A dialog no action answers: the waits end ("Action interrupted by a
    /// dialog").
    aborted: bool = false,
    /// Pages the action opened (Puppeteer's 'popup').
    opened: std.ArrayList(*Page) = .empty,

    pub const DialogAction = struct {
        /// "accept", "dismiss" or a prompt's text, for every type.
        all: ?[]const u8 = null,
        beforeunload: ?[]const u8 = null,

        fn forType(self: DialogAction, kind: []const u8) ?[]const u8 {
            if (self.all) |a| return a;
            if (std.mem.eql(u8, kind, "beforeunload")) return self.beforeunload;
            return null;
        }
    };
};

/// Puppeteer's UTILITY_WORLD_NAME (puppeteer-core 25.17.0
/// lib/puppeteer/common/util.js): the isolated world its queries run in.
pub const utility_world_name = "__puppeteer_utility_world__25.17.0";

pub const World = enum { main, utility };

/// An execution context of one of a page's frames.
pub const FrameContext = struct {
    id: i64,
    /// OWNED.
    frame_id: []u8,
    world: World,
    /// The utility world's objects wait_for keeps (Puppeteer's
    /// puppeteerUtil, injected once per context, and its document): their
    /// remote object ids, OWNED; they go with the context.
    util_object: ?[]u8 = null,
    document_object: ?[]u8 = null,

    pub fn deinit(self: *FrameContext, allocator: Allocator) void {
        allocator.free(self.frame_id);
        if (self.util_object) |o| allocator.free(o);
        if (self.document_object) |o| allocator.free(o);
    }
};

/// McpPage.textSnapshot: what its uids name, kept until the next snapshot.
pub const TextSnapshot = struct {
    arena: std.heap.ArenaAllocator,
    /// idToNode, by uid (in `arena`).
    targets: std.StringArrayHashMapUnmanaged(snapshot_mod.Target) = .empty,
};

pub const Page = struct {
    /// The MCP page id (McpPage.id).
    id: u32,
    target_id: []u8,
    session_id: []u8,
    url: []u8,
    title: []u8,
    browser_context_id: []u8,
    /// The isolated context's name it was opened in (new_page isolatedContext).
    isolated_context: ?[]u8 = null,
    /// Page, Runtime, Network and Log enabled on its session (`initPage`).
    initialized: bool = false,
    closed: bool = false,
    dialog: ?Dialog = null,
    /// Page.loadEventFired seen since the last `expectLoad`.
    load_fired: bool = false,
    /// A main-frame Page.navigatedWithinDocument seen since it was last
    /// cleared: what ends Puppeteer's waitForNavigation for a same-document
    /// navigation (LifecycleWatcher's sameDocumentNavigation).
    same_document_navigated: bool = false,
    /// McpPage.init's focus emulation was asked for.
    focus_emulated: bool = false,
    /// The emulate tool's state Puppeteer keeps per page: a user agent
    /// override applied (NetworkManager #userAgentOverrideApplied), a
    /// viewport override active and its mobile and touch
    /// (EmulationManager's viewport state, #emulatingMobile, #hasTouch).
    user_agent_emulated: bool = false,
    viewport_emulated: bool = false,
    emulating_mobile: bool = false,
    emulating_touch: bool = false,
    /// McpPage.emulationSettings: what the last emulate call set, which
    /// McpResponse prints for a page tool's answer ("Emulating ...").
    emulation: Emulation = .{},
    /// McpPage's DevTools universe: the second session on the page
    /// (logpoints.initUniverse), its Debugger enabled. OWNED.
    debugger_session_id: ?[]u8 = null,
    /// set_logpoints' scripts and logpoints (logpoints.zig).
    logpoints: logpoints_mod.State = .{},
    /// The main frame's id (Page.frameNavigated without a parentId).
    main_frame_id: ?[]u8 = null,
    /// The frames' execution contexts Puppeteer keeps (FrameManager
    /// #onExecutionContextCreated): each frame's main world (Runtime's
    /// isDefault), where console calls are heard (registerWorldListeners
    /// for MAIN_WORLD) and evaluations run, and its utility world
    /// (PUPPETEER_WORLD, named `utility_world_name`).
    contexts: std.ArrayList(FrameContext) = .empty,
    /// The main frame's main-world context (Puppeteer's mainFrame() world
    /// that page.evaluate runs in).
    main_context_id: ?i64 = null,
    /// McpPage.textSnapshot: the last snapshot's uids and their nodes.
    text_snapshot: ?*TextSnapshot = null,
    /// McpPage.uniqueBackendNodeIdToMcpId.
    uids: snapshot_mod.UidMap = .{},
    /// ConsoleCollector: console messages and uncaught errors.
    console: collectors.Collector(console.Message) = .{ .max_per_navigation = console.max_per_navigation },
    /// NetworkCollector: the requests.
    network: network.Collector = .{},
    /// Puppeteer's page.keyboard: the keys held.
    keyboard: keyboard_mod.Keyboard = .{},
    /// CDP CSS.styleSheetAdded headers kept for `get_css_styles`.
    css_enabled: bool = false,
    css_sheets: std.StringArrayHashMapUnmanaged(CssSheetHeader) = .empty,

    pub const CssSheetHeader = struct {
        source_url: []u8,
        origin: []u8,
        start_line: i64 = 0,
        start_col: i64 = 0,
        is_inline: bool = false,
        is_constructed: bool = false,

        pub fn deinit(self: *CssSheetHeader, allocator: Allocator) void {
            allocator.free(self.source_url);
            allocator.free(self.origin);
        }
    };

    pub fn clearCssSheets(self: *Page, allocator: Allocator) void {
        for (self.css_sheets.keys()) |k| allocator.free(k);
        for (self.css_sheets.values()) |*v| v.deinit(allocator);
        self.css_sheets.clearRetainingCapacity();
    }

    pub fn putCssSheet(self: *Page, allocator: Allocator, id: []const u8, hdr: CssSheetHeader) !void {
        if (self.css_sheets.getPtr(id)) |existing| {
            existing.deinit(allocator);
            existing.* = hdr;
            return;
        }
        const owned_key = try allocator.dupe(u8, id);
        errdefer allocator.free(owned_key);
        try self.css_sheets.put(allocator, owned_key, hdr);
    }

    fn deinit(self: *Page, allocator: Allocator) void {
        allocator.free(self.target_id);
        allocator.free(self.session_id);
        allocator.free(self.url);
        allocator.free(self.title);
        allocator.free(self.browser_context_id);
        if (self.isolated_context) |n| allocator.free(n);
        if (self.main_frame_id) |id| allocator.free(id);
        self.clearDialog(allocator);
        self.console.deinit(allocator);
        self.network.deinit(allocator);
        self.keyboard.deinit(allocator);
        self.clearCssSheets(allocator);
        self.css_sheets.deinit(allocator);
        for (self.contexts.items) |*c| c.deinit(allocator);
        self.contexts.deinit(allocator);
        self.dropSnapshot(allocator);
        self.uids.deinit(allocator);
        self.emulation.deinit(allocator);
        if (self.debugger_session_id) |id| allocator.free(id);
        self.logpoints.deinit(allocator);
    }

    /// Replace the page's snapshot (null: none).
    pub fn setSnapshot(self: *Page, allocator: Allocator, next: ?*TextSnapshot) void {
        self.dropSnapshot(allocator);
        self.text_snapshot = next;
    }

    fn dropSnapshot(self: *Page, allocator: Allocator) void {
        if (self.text_snapshot) |s| {
            s.arena.deinit();
            allocator.destroy(s);
        }
        self.text_snapshot = null;
    }

    /// The execution context of `frame_id`'s `world`, if Puppeteer would
    /// have one.
    pub fn contextOf(self: *Page, frame_id: []const u8, world: World) ?*FrameContext {
        for (self.contexts.items) |*c| if (c.world == world and std.mem.eql(u8, c.frame_id, frame_id)) return c;
        return null;
    }

    fn isMainWorld(self: *const Page, id: i64) bool {
        for (self.contexts.items) |c| if (c.id == id and c.world == .main) return true;
        return false;
    }

    fn removeContext(self: *Page, allocator: Allocator, id: i64) void {
        for (self.contexts.items, 0..) |*c, at| if (c.id == id) {
            c.deinit(allocator);
            _ = self.contexts.orderedRemove(at);
            return;
        };
    }

    /// Puppeteer's mainFrame()._id: the main frame's id, which is the
    /// page target's id until a frameNavigated names it.
    pub fn mainFrameId(self: *const Page) []const u8 {
        return self.main_frame_id orelse self.target_id;
    }

    pub fn clearDialog(self: *Page, allocator: Allocator) void {
        if (self.dialog) |d| {
            allocator.free(d.type);
            allocator.free(d.message);
            allocator.free(d.default_prompt);
        }
        self.dialog = null;
    }
};

/// Active `take_heapsnapshot` chunk sink (tools/memory.zig): collects
/// `HeapProfiler.addHeapSnapshotChunk` events for `session_id` while
/// `HeapProfiler.takeHeapSnapshot` is in flight.
pub const HeapCapture = struct {
    session_id: []const u8,
    allocator: Allocator,
    chunks: std.ArrayList(u8) = .empty,
    failed: bool = false,
};

pub const Session = struct {
    allocator: Allocator,
    client: Client,
    pages: std.ArrayList(*Page) = .empty,
    selected: ?*Page = null,
    next_page_id: u32 = 1,
    /// The selection the last snapshot replaced (McpContext's
    /// `#selectedPageFallback`): reported once.
    selection_fallback: ?struct { was_closed: bool } = null,
    /// new_page's isolated contexts by name: the browserContextId.
    isolated_contexts: std.StringArrayHashMapUnmanaged([]u8) = .empty,
    next_isolated_context: u32 = 1,
    /// The wait a tool's action runs under (wait.zig), if any.
    watch: ?*Watch = null,
    /// Active heap snapshot capture (tools/memory.zig), if any.
    heap_capture: ?*HeapCapture = null,
    /// The tools' definitions (tools/list's array), parsed: the input
    /// schemas calls are checked against (validate.zig).
    schemas: ?std.json.Parsed(std.json.Value) = null,
    /// TextSnapshot.nextSnapshotId: one count for the server, every page's
    /// snapshots numbered from it.
    next_snapshot_id: u32 = 1,
    /// Where tools may read and write files (paths.zig: the configured
    /// roots, the client's, the OS temp directory).
    paths: paths_mod.Policy,
    /// Whether `--memoryDebugging` / `--memory-debugging` is enabled.
    memory_debugging: bool = false,
    /// Loaded and cached heap snapshots (HeapSnapshotManager).
    heap_snapshots: heap_snapshot_mod.Cache = .{},

    /// Attach to the browser behind `link` as Puppeteer's connect does.
    pub fn create(allocator: Allocator, link: *LocalLink) !*Session {
        const self = try allocator.create(Session);
        errdefer allocator.destroy(self);
        self.* = .{ .allocator = allocator, .client = .{ .allocator = allocator, .link = link }, .paths = .{ .allocator = allocator } };
        self.client.sink = .{ .context = self, .on_event = onEvent };
        var discover = try self.client.call("Target.setDiscoverTargets", "{\"discover\":true}", "", command_timeout_ms);
        discover.deinit();
        var attach = try self.client.call("Target.setAutoAttach", "{\"autoAttach\":true,\"waitForDebuggerOnStart\":false,\"flatten\":true}", "", command_timeout_ms);
        attach.deinit();
        _ = try self.client.pump(50 * std.time.ns_per_ms);
        try self.initPages();
        self.snapshot();
        return self;
    }

    pub fn destroy(self: *Session) void {
        for (self.pages.items) |p| {
            p.deinit(self.allocator);
            self.allocator.destroy(p);
        }
        self.pages.deinit(self.allocator);
        var it = self.isolated_contexts.iterator();
        while (it.next()) |e| {
            self.allocator.free(e.key_ptr.*);
            self.allocator.free(e.value_ptr.*);
        }
        self.isolated_contexts.deinit(self.allocator);
        if (self.schemas) |*parsed| parsed.deinit();
        self.heap_snapshots.deinit(self.allocator);
        self.paths.deinit();
        self.allocator.destroy(self);
    }

    // ------------------------------------------------------------------
    // Pages
    // ------------------------------------------------------------------

    /// McpContext.createPagesSnapshot: when the selected page is gone,
    /// select the first open one and remember the change. Closed pages stay
    /// listed (as closed) until the next call starts (`dropClosed`): this
    /// call's response may still point at them.
    pub fn snapshot(self: *Session) void {
        if (self.selected != null and !self.selected.?.closed) return;
        const live = self.firstLive();
        if (self.selected) |old| {
            if (live != null) self.selection_fallback = .{ .was_closed = old.closed };
        }
        self.selected = live;
    }

    /// McpContext.getTargetInfos: the pages' titles as Target.getTargets
    /// gives them now (formatPage reads a fresh TargetInfo's title).
    pub fn refreshTitles(self: *Session) void {
        var r = self.client.call("Target.getTargets", "{}", "", command_timeout_ms) catch return;
        defer r.deinit();
        const result = r.result() orelse return;
        const infos = result.object.get("targetInfos") orelse return;
        if (infos != .array) return;
        for (infos.array.items) |info| {
            if (info != .object or !std.mem.eql(u8, str(info.object.get("type")), "page")) continue;
            const page = self.pageByTarget(str(info.object.get("targetId"))) orelse continue;
            replace(self.allocator, &page.title, str(info.object.get("title"))) catch {};
        }
    }

    /// Free the closed pages (at a call's start).
    pub fn dropClosed(self: *Session) void {
        var i: usize = 0;
        while (i < self.pages.items.len) {
            const p = self.pages.items[i];
            if (p.closed and p != self.selected) {
                _ = self.pages.orderedRemove(i);
                p.deinit(self.allocator);
                self.allocator.destroy(p);
                continue;
            }
            i += 1;
        }
    }

    fn firstLive(self: *Session) ?*Page {
        for (self.pages.items) |p| if (!p.closed) return p;
        return null;
    }

    /// The open pages, in id order.
    pub fn livePages(self: *Session, arena: Allocator) ![]*Page {
        var out: std.ArrayList(*Page) = .empty;
        for (self.pages.items) |p| if (!p.closed) try out.append(arena, p);
        return out.items;
    }

    /// McpContext.getPageById: error.NoSuchPage when it is unknown or closed.
    pub fn pageById(self: *Session, id: i64) ?*Page {
        for (self.pages.items) |p| if (!p.closed and p.id == id) return p;
        return null;
    }

    pub fn select(self: *Session, page: *Page) void {
        self.selected = page;
        self.selection_fallback = null;
    }

    /// Enable on every new page's session what the collectors read (as
    /// Puppeteer's page initialisation does: Page, Runtime, Network, Log).
    pub fn initPages(self: *Session) !void {
        var index: usize = 0;
        while (index < self.pages.items.len) : (index += 1) {
            const p = self.pages.items[index];
            if (p.initialized or p.closed) continue;
            p.initialized = true;
            const session_id = p.session_id;
            // FrameManager.initialize's order: Page.enable, the frame tree
            // (the main frame's id), then Runtime (whose replayed contexts
            // name their frames), Network and Log.
            for ([_][]const u8{ "Page.enable", "Page.getFrameTree", "Runtime.enable", "Network.enable", "Log.enable" }) |method| {
                var r = self.client.call(method, "{}", session_id, command_timeout_ms) catch |err| {
                    log.warn("mcp: {s} on page {d}: {t}", .{ method, p.id, err });
                    continue;
                };
                defer r.deinit();
                if (std.mem.eql(u8, method, "Page.getFrameTree")) if (r.result()) |result| {
                    const tree = result.object.get("frameTree") orelse continue;
                    const frame = (tree.object.get("frame") orelse continue).object;
                    const id = try self.allocator.dupe(u8, str(frame.get("id")));
                    if (p.main_frame_id) |old| self.allocator.free(old);
                    p.main_frame_id = id;
                };
            }
        }
    }

    // ------------------------------------------------------------------
    // Events
    // ------------------------------------------------------------------

    fn onEvent(context: *anyopaque, method: []const u8, params: std.json.Value, session_id: []const u8) void {
        const self: *Session = @ptrCast(@alignCast(context));
        self.event(method, params, session_id) catch |err| log.warn("mcp: event {s}: {t}", .{ method, err });
    }

    fn event(self: *Session, method: []const u8, params: std.json.Value, session_id: []const u8) !void {
        if (params != .object) return;
        const p = params.object;
        if (std.mem.eql(u8, method, "Target.attachedToTarget")) {
            const info = (p.get("targetInfo") orelse return).object;
            if (!std.mem.eql(u8, str(info.get("type")), "page")) return;
            // A second session on a page's target is its DevTools universe
            // (logpoints.initUniverse), not a page.
            if (self.pageByTarget(str(info.get("targetId"))) != null) return;
            const page = try self.allocator.create(Page);
            errdefer self.allocator.destroy(page);
            page.* = .{
                .id = self.next_page_id,
                .target_id = try self.allocator.dupe(u8, str(info.get("targetId"))),
                .session_id = try self.allocator.dupe(u8, str(p.get("sessionId"))),
                .url = try self.allocator.dupe(u8, str(info.get("url"))),
                .title = try self.allocator.dupe(u8, str(info.get("title"))),
                .browser_context_id = try self.allocator.dupe(u8, str(info.get("browserContextId"))),
            };
            self.next_page_id += 1;
            try self.pages.append(self.allocator, page);
            if (self.watch) |w| if (std.mem.eql(u8, str(info.get("openerId")), w.page.target_id)) try w.opened.append(self.allocator, page);
            return;
        }
        if (std.mem.eql(u8, method, "Target.targetInfoChanged")) {
            const info = (p.get("targetInfo") orelse return).object;
            const page = self.pageByTarget(str(info.get("targetId"))) orelse return;
            try replace(self.allocator, &page.url, str(info.get("url")));
            try replace(self.allocator, &page.title, str(info.get("title")));
            return;
        }
        if (std.mem.eql(u8, method, "Target.detachedFromTarget") or std.mem.eql(u8, method, "Target.targetDestroyed")) {
            const target = str(p.get("targetId"));
            const by_session = str(p.get("sessionId"));
            // The universe's session going leaves the page.
            if (by_session.len != 0) for (self.pages.items) |page| {
                const universe = page.debugger_session_id orelse continue;
                if (!std.mem.eql(u8, universe, by_session)) continue;
                self.allocator.free(universe);
                page.debugger_session_id = null;
                return;
            };
            for (self.pages.items) |page| {
                if ((target.len != 0 and std.mem.eql(u8, page.target_id, target)) or (by_session.len != 0 and std.mem.eql(u8, page.session_id, by_session))) page.closed = true;
            }
            return;
        }
        // The universe's events: set_logpoints' scripts and resolutions.
        if (session_id.len != 0) for (self.pages.items) |universe_page| {
            const universe = universe_page.debugger_session_id orelse continue;
            if (!std.mem.eql(u8, universe, session_id)) continue;
            return universe_page.logpoints.debuggerEvent(self.allocator, method, p, universe_page.url, &self.paths);
        };
        // A page session's events.
        const page = self.pageBySession(session_id) orelse return;
        if (std.mem.eql(u8, method, "HeapProfiler.addHeapSnapshotChunk")) {
            if (self.heap_capture) |cap| {
                if (std.mem.eql(u8, cap.session_id, session_id) and !cap.failed) {
                    cap.chunks.appendSlice(cap.allocator, str(p.get("chunk"))) catch {
                        cap.failed = true;
                    };
                }
            }
            return;
        }
        if (std.mem.eql(u8, method, "Page.javascriptDialogOpening")) {
            if (self.watch) |w| if (w.page == page) {
                w.dialog_detected = true;
                if (w.dialog_action.forType(str(p.get("type")))) |action| {
                    // Dialog.accept/dismiss, not awaited; a handled dialog is
                    // no longer the page's open one (McpPage.getDialog).
                    w.dialog_handled = true;
                    const answer = if (std.mem.eql(u8, action, "dismiss"))
                        "{\"accept\":false}"
                    else if (std.mem.eql(u8, action, "accept"))
                        "{\"accept\":true}"
                    else
                        try std.fmt.allocPrint(self.allocator, "{{\"accept\":true,\"promptText\":{f}}}", .{std.json.fmt(action, .{})});
                    defer if (!std.mem.eql(u8, action, "dismiss") and !std.mem.eql(u8, action, "accept")) self.allocator.free(answer);
                    try self.client.post("Page.handleJavaScriptDialog", answer, page.session_id);
                    return;
                }
                w.aborted = true;
            };
            page.clearDialog(self.allocator);
            page.dialog = .{
                .type = try self.allocator.dupe(u8, str(p.get("type"))),
                .message = try self.allocator.dupe(u8, str(p.get("message"))),
                .default_prompt = try self.allocator.dupe(u8, str(p.get("defaultPrompt"))),
            };
            return;
        }
        if (std.mem.eql(u8, method, "Page.javascriptDialogClosed")) {
            page.clearDialog(self.allocator);
            return;
        }
        if (std.mem.eql(u8, method, "Page.loadEventFired")) {
            page.load_fired = true;
            if (self.watch) |w| if (w.page == page and w.loaded_new_document) {
                w.navigation_finished = true;
            };
            return;
        }
        if (std.mem.eql(u8, method, "Page.frameStartedNavigating") or std.mem.eql(u8, method, "Page.frameRequestedNavigation")) {
            const w = self.watch orelse return;
            if (w.page != page) return;
            if (!std.mem.eql(u8, str(p.get("frameId")), page.mainFrameId())) return;
            const kind = str(p.get("navigationType"));
            if (std.mem.eql(u8, method, "Page.frameStartedNavigating") and (std.mem.eql(u8, kind, "sameDocument") or std.mem.eql(u8, kind, "historySameDocument"))) return;
            w.navigation_started = true;
            return;
        }
        if (std.mem.eql(u8, method, "Page.navigatedWithinDocument")) {
            // The main frame's URL moves (Puppeteer's Frame
            // _navigatedWithinDocument, which page.url() reads).
            if (!std.mem.eql(u8, str(p.get("frameId")), page.mainFrameId())) return;
            try replace(self.allocator, &page.url, str(p.get("url")));
            page.same_document_navigated = true;
            return;
        }
        if (std.mem.eql(u8, method, "Page.frameNavigated")) {
            const frame = (p.get("frame") orelse return).object;
            if (frame.get("parentId") != null) return;
            // The main frame names the page's URL; its new document starts
            // the collectors' next navigation (PageCollector's
            // 'framenavigated' for the main frame - a same-document
            // navigation is Page.navigatedWithinDocument, which keeps it).
            try replace(self.allocator, &page.url, str(frame.get("url")));
            const frame_id = str(frame.get("id"));
            if (page.main_frame_id == null or !std.mem.eql(u8, page.main_frame_id.?, frame_id)) {
                const copy = try self.allocator.dupe(u8, frame_id);
                if (page.main_frame_id) |old| self.allocator.free(old);
                page.main_frame_id = copy;
            }
            try page.console.split(self.allocator, null);
            try page.network.split(self.allocator, page.mainFrameId());
            page.clearCssSheets(self.allocator);
            if (self.watch) |w| if (w.page == page) {
                w.loaded_new_document = true;
                w.navigation_started = true;
            };
            return;
        }
        if (std.mem.eql(u8, method, "Runtime.executionContextCreated")) {
            const context = (p.get("context") orelse return).object;
            const aux = context.get("auxData") orelse return;
            if (aux != .object) return;
            const id = context.get("id") orelse return;
            if (id != .integer) return;
            // FrameManager #onExecutionContextCreated: the main world by
            // isDefault, the utility world by its name; no other.
            const is_default = if (aux.object.get("isDefault")) |d| d == .bool and d.bool else false;
            const world: World = if (is_default) .main else if (std.mem.eql(u8, str(context.get("name")), utility_world_name)) .utility else return;
            try self.addContext(page, id.integer, str(aux.object.get("frameId")), world);
            return;
        }
        if (std.mem.eql(u8, method, "Runtime.executionContextDestroyed")) {
            const id = p.get("executionContextId") orelse return;
            if (id != .integer) return;
            page.removeContext(self.allocator, id.integer);
            if (page.main_context_id == id.integer) page.main_context_id = null;
            page.logpoints.contextDestroyed(self.allocator, id.integer);
            return;
        }
        if (std.mem.eql(u8, method, "Runtime.executionContextsCleared")) {
            for (page.contexts.items) |*c| c.deinit(self.allocator);
            page.contexts.clearRetainingCapacity();
            page.main_context_id = null;
            page.logpoints.contextsCleared(self.allocator);
            return;
        }
        if (std.mem.eql(u8, method, "Runtime.consoleAPICalled")) {
            const id = p.get("executionContextId") orelse return;
            if (id != .integer or !page.isMainWorld(id.integer)) return;
            if (try console.fromConsoleApi(self.allocator, p)) |message| try page.console.add(self.allocator, message);
            return;
        }
        if (std.mem.eql(u8, method, "CSS.styleSheetAdded")) {
            const header_val = p.get("header") orelse return;
            if (header_val != .object) return;
            const h = header_val.object;
            const sid = str(h.get("styleSheetId"));
            if (sid.len == 0) return;
            const url = try self.allocator.dupe(u8, str(h.get("sourceURL")));
            errdefer self.allocator.free(url);
            const origin = try self.allocator.dupe(u8, str(h.get("origin")));
            errdefer self.allocator.free(origin);
            const start_line: i64 = if (h.get("startLine")) |v| switch (v) {
                .integer => v.integer,
                .float => @intFromFloat(v.float),
                else => 0,
            } else 0;
            const start_col: i64 = if (h.get("startColumn")) |v| switch (v) {
                .integer => v.integer,
                .float => @intFromFloat(v.float),
                else => 0,
            } else 0;
            const is_inline = if (h.get("isInline")) |v| v == .bool and v.bool else false;
            const is_constructed = if (h.get("isConstructed")) |v| v == .bool and v.bool else false;
            try page.putCssSheet(self.allocator, sid, .{
                .source_url = url,
                .origin = origin,
                .start_line = start_line,
                .start_col = start_col,
                .is_inline = is_inline,
                .is_constructed = is_constructed,
            });
            return;
        }
        if (std.mem.eql(u8, method, "Log.entryAdded")) {
            if (try console.fromLogEntry(self.allocator, p)) |message| try page.console.add(self.allocator, message);
            return;
        }
        if (std.mem.startsWith(u8, method, "Network.")) {
            const name = method["Network.".len..];
            if (std.mem.eql(u8, name, "requestWillBeSent")) return page.network.requestWillBeSent(self.allocator, p);
            if (std.mem.eql(u8, name, "requestWillBeSentExtraInfo")) return page.network.requestWillBeSentExtraInfo(self.allocator, p);
            if (std.mem.eql(u8, name, "responseReceived")) return page.network.responseReceived(self.allocator, p);
            if (std.mem.eql(u8, name, "responseReceivedExtraInfo")) return page.network.responseReceivedExtraInfo(self.allocator, p);
            if (std.mem.eql(u8, name, "loadingFinished")) return page.network.loadingFinished(p);
            if (std.mem.eql(u8, name, "loadingFailed")) return page.network.loadingFailed(self.allocator, p);
            return;
        }
        if (std.mem.eql(u8, method, "Runtime.exceptionThrown")) {
            if (try console.fromException(self.allocator, p)) |message| try page.console.add(self.allocator, message);
            return;
        }
    }

    /// Record context `id` of `frame_id`'s `world` (once: the answer to
    /// Page.createIsolatedWorld and its executionContextCreated name the
    /// same one).
    pub fn addContext(self: *Session, page: *Page, id: i64, frame_id: []const u8, world: World) !void {
        for (page.contexts.items) |c| if (c.id == id) return;
        const frame = try self.allocator.dupe(u8, frame_id);
        errdefer self.allocator.free(frame);
        try page.contexts.append(self.allocator, .{ .id = id, .frame_id = frame, .world = world });
        if (world == .main and std.mem.eql(u8, frame_id, page.mainFrameId())) page.main_context_id = id;
    }

    pub fn pageByTarget(self: *Session, target_id: []const u8) ?*Page {
        for (self.pages.items) |page| if (!page.closed and std.mem.eql(u8, page.target_id, target_id)) return page;
        return null;
    }

    fn pageBySession(self: *Session, session_id: []const u8) ?*Page {
        if (session_id.len == 0) return null;
        for (self.pages.items) |page| if (std.mem.eql(u8, page.session_id, session_id)) return page;
        return null;
    }

    /// Wait (up to `timeout_ms`) until `done` holds, pumping events.
    pub fn waitUntil(self: *Session, timeout_ms: u32, context: anytype, comptime done: fn (@TypeOf(context)) bool) !bool {
        var waited: u32 = 0;
        while (!done(context)) {
            if (waited >= timeout_ms) return false;
            _ = try self.client.pump(10 * std.time.ns_per_ms);
            waited += 10;
        }
        return true;
    }
};

/// A JSON string's value, or "" for anything else.
pub fn str(value: ?std.json.Value) []const u8 {
    const v = value orelse return "";
    return if (v == .string) v.string else "";
}

fn replace(allocator: Allocator, field: *[]u8, value: []const u8) !void {
    if (std.mem.eql(u8, field.*, value)) return;
    const copy = try allocator.dupe(u8, value);
    allocator.free(field.*);
    field.* = copy;
}
