//! The host API's C ABI (include/crane.h; the instances design, 5.2; lane
//! cdph): Browsers on threads of their own (BrowserHost) and their tabs,
//! for an embedder that is not Zig. Every call is thread-safe and blocks its
//! caller until the Browser's thread has answered; called from the Browser's
//! own thread - an event callback - a tab call returns
//! CRANE_ERR_WRONG_THREAD (no re-entrant commands). Strings out are UTF-8,
//! owned by the result, freed by its `_free`. Every options struct starts
//! with `struct_size`, so the ABI can grow.
//!
//! The library root (src/lib_exports.zig) references this file, which emits
//! the `crane_*` symbols; no other artifact does.

const std = @import("std");
const engine = @import("engine");
const browser_mod = @import("Browser.zig");
const Browser = browser_mod.Browser;
const BrowserConfig = browser_mod.BrowserConfig;
const BrowserHost = @import("BrowserHost.zig").BrowserHost;
const host_events = @import("host_events.zig");
const Process = @import("process.zig").Process;

/// Every allocation the ABI hands out or keeps: malloc's, thread-safe.
const allocator = std.heap.c_allocator;

pub const Status = enum(c_int) {
    ok = 0,
    invalid_argument = 1,
    no_such_tab = 2,
    unsupported = 3,
    profile_in_use = 4,
    out_of_memory = 5,
    navigation_failed = 6,
    wrong_thread = 7,
    process_not_started = 8,
    timeout = 9,
    internal = 10,
};

pub const Readiness = enum(c_int) { none = 0, interactive = 1, complete = 2 };

pub const ProcessOptions = extern struct {
    struct_size: u32,
    snapshot_path: ?[*:0]const u8 = null,
};

pub const ProxyKind = enum(u32) { system = 0, direct = 1, manual = 2, pac = 3, autodetect = 4 };

pub const Proxy = extern struct {
    kind: u32,
    http: ?[*:0]const u8 = null,
    ssl: ?[*:0]const u8 = null,
    /// Comma-separated hosts that bypass the proxy.
    no_proxy: ?[*:0]const u8 = null,
    pac_url: ?[*:0]const u8 = null,
};

pub const EventKind = enum(u32) { tab_created = 1, tab_destroyed = 2, frame_created = 3, frame_destroyed = 4 };

pub const Event = extern struct {
    struct_size: u32,
    kind: u32,
    /// The tab, or the frame's navigable.
    tab: u64,
    /// tab_created: the traversable whose page opened it, 0 for none;
    /// frame_created: the parent navigable.
    related: u64,
    /// tab_created: made by a page's script (a popup).
    created_by_web_content: bool,
    /// tab_created: where its first navigation goes. BORROWED for the call.
    url: ?[*:0]const u8,
};

pub const EventFn = *const fn (context: ?*anyopaque, event: *const Event) callconv(.c) void;

pub const BrowserOptions = extern struct {
    struct_size: u32,
    /// A profile directory: not supported yet (in memory only).
    profile_dir: ?[*:0]const u8 = null,
    user_agent: ?[*:0]const u8 = null,
    proxy: ?*const Proxy = null,
    accept_insecure_certs: bool = false,
    on_event: ?EventFn = null,
    event_context: ?*anyopaque = null,
};

pub const TabInfo = extern struct {
    id: u64,
    /// 0: none.
    opener: u64,
    created_by_web_content: bool,
    url: [*:0]u8,
    title: [*:0]u8,
};

pub const NavigateResult = extern struct {
    url: ?[*:0]u8 = null,
};

pub const EvaluateResult = extern struct {
    /// The script threw (or its awaited promise rejected): `json` is the
    /// exception's details; else a BiDi script.RemoteValue.
    exception: bool = false,
    json: ?[*:0]u8 = null,
};

pub const eval_await_promise: u32 = 1;
pub const eval_user_activation: u32 = 2;

/// The ABI's `crane_browser_t`.
pub const Handle = CBrowser;

/// What the ABI's browser handle is: a BrowserHost and the embedder's event
/// callback, which a listener on the Browser's thread calls.
const CBrowser = struct {
    host: *BrowserHost,
    on_event: ?EventFn,
    event_context: ?*anyopaque,
    /// Copies of what the options borrowed, kept for the Browser's life.
    strings: std.ArrayListUnmanaged([]u8) = .empty,

    fn listener(self: *CBrowser) host_events.Listener {
        return .{ .context = self, .on_event = deliver };
    }

    /// On the Browser's thread: the embedder's callback, given the event.
    fn deliver(context: *anyopaque, event: *const host_events.Event) void {
        const self: *CBrowser = @ptrCast(@alignCast(context));
        const callback = self.on_event orelse return;
        var url_buffer: [2048:0]u8 = undefined;
        var out: Event = .{ .struct_size = @sizeOf(Event), .kind = 0, .tab = 0, .related = 0, .created_by_web_content = false, .url = null };
        switch (event.*) {
            .tab_created => |created| {
                out.kind = @backingInt(EventKind.tab_created);
                out.tab = created.tab;
                out.related = created.opener orelse 0;
                out.created_by_web_content = created.made_by == .page;
                const len = @min(created.url.len, url_buffer.len);
                @memcpy(url_buffer[0..len], created.url[0..len]);
                url_buffer[len] = 0;
                out.url = url_buffer[0..len :0].ptr;
            },
            .tab_destroyed => |destroyed| {
                out.kind = @backingInt(EventKind.tab_destroyed);
                out.tab = destroyed.tab;
            },
            .frame_created => |frame| {
                out.kind = @backingInt(EventKind.frame_created);
                out.tab = frame.navigable;
                out.related = frame.parent;
            },
            .frame_destroyed => |frame| {
                out.kind = @backingInt(EventKind.frame_destroyed);
                out.tab = frame.navigable;
            },
            // Navigation milestones and document starts are not in the C
            // ABI's events yet.
            .navigation, .document_start, .dialog_opening, .dialog_closed => return,
        }
        callback(self.event_context, &out);
    }

    fn addListener(ctx: ?*anyopaque, b: *Browser) void {
        const self: *CBrowser = @ptrCast(@alignCast(ctx.?));
        b.addListener(self.listener()) catch {};
    }

    fn removeListener(ctx: ?*anyopaque, b: *Browser) void {
        const self: *CBrowser = @ptrCast(@alignCast(ctx.?));
        b.removeListener(self.listener());
    }

    fn keep(self: *CBrowser, text: ?[*:0]const u8) !?[]const u8 {
        const t = text orelse return null;
        const copy = try allocator.dupe(u8, std.mem.span(t));
        errdefer allocator.free(copy);
        try self.strings.append(allocator, copy);
        return copy;
    }
};

fn statusOf(err: anyerror) Status {
    return switch (err) {
        error.OutOfMemory => .out_of_memory,
        error.NoSuchTab, error.NoSuchTraversable => .no_such_tab,
        error.InvalidUrl => .invalid_argument,
        error.WrongThread => .wrong_thread,
        error.NotSupported => .unsupported,
        error.Timeout => .timeout,
        error.NetworkError, error.NavigationAborted, error.NavigationTimedOut => .navigation_failed,
        error.ProcessNotStarted => .process_not_started,
        else => .internal,
    };
}

fn dupeZ(text: []const u8) ![*:0]u8 {
    return (try allocator.dupeSentinel(u8, text, 0)).ptr;
}

// ============================================================================
// The process
// ============================================================================

/// Start the process - the engine, every hook - once, before any Browser.
/// Call it first in `main`, before the embedder makes a thread that will
/// run Crane (engine.initializeBeforeThreadCreation: V8's thread isolation
/// key on x86-64 Linux, which only threads made after it can read).
pub export fn crane_process_init(options: ?*const ProcessOptions) callconv(.c) Status {
    engine.initializeBeforeThreadCreation();
    const snapshot: ?[]const u8 = if (options) |o| (if (o.snapshot_path) |p| std.mem.span(p) else null) else null;
    Process.ensureStarted(.{ .snapshot_path = snapshot }) catch return .internal;
    return .ok;
}

/// End the process, after its last Browser. The engine keeps its platform
/// until the process exits (V8 cannot start twice), so this only says the
/// embedder is done: nothing may be made after it.
pub export fn crane_process_shutdown() callconv(.c) void {}

// ============================================================================
// Browsers
// ============================================================================

/// A Browser on a thread of its own (BiDi browser.createUserContext; CDP
/// Target.createBrowserContext). In memory: a `profile_dir` is
/// CRANE_ERR_UNSUPPORTED until profile directories exist.
pub export fn crane_browser_create(options: ?*const BrowserOptions, out: ?*?*CBrowser) callconv(.c) Status {
    const result = out orelse return .invalid_argument;
    result.* = null;
    const o: BrowserOptions = if (options) |given| given.* else .{ .struct_size = @sizeOf(BrowserOptions) };
    if (o.struct_size < @sizeOf(u32)) return .invalid_argument;
    if (o.profile_dir != null) return .unsupported;
    const self = allocator.create(CBrowser) catch return .out_of_memory;
    self.* = .{ .host = undefined, .on_event = o.on_event, .event_context = o.event_context };
    var config: BrowserConfig = .{ .accept_insecure_certs = o.accept_insecure_certs };
    const failed: ?Status = blk: {
        config.user_agent = self.keep(o.user_agent) catch break :blk .out_of_memory;
        if (o.proxy) |proxy| config.proxy = switch (std.enums.fromInt(ProxyKind, proxy.kind) orelse break :blk .invalid_argument) {
            .system => .system,
            .direct => .direct,
            .manual => .{ .manual = .{
                .http = self.keep(proxy.http) catch break :blk .out_of_memory,
                .https = self.keep(proxy.ssl) catch break :blk .out_of_memory,
                .no_proxy = self.keep(proxy.no_proxy) catch break :blk .out_of_memory,
            } },
            .pac, .autodetect => break :blk .unsupported,
        };
        break :blk null;
    };
    if (failed) |status| {
        freeBrowser(self);
        return status;
    }
    self.host = BrowserHost.start(allocator, config) catch |err| {
        freeBrowser(self);
        return statusOf(err);
    };
    if (self.on_event != null) self.host.call(self, CBrowser.addListener) catch {};
    result.* = self;
    return .ok;
}

fn freeBrowser(self: *CBrowser) void {
    for (self.strings.items) |text| allocator.free(text);
    self.strings.deinit(allocator);
    allocator.destroy(self);
}

/// End a Browser: every tab closed without prompting, its thread joined.
/// Not from the Browser's own thread (an event callback).
pub export fn crane_browser_destroy(browser: ?*CBrowser) callconv(.c) void {
    const self = browser orelse return;
    if (self.host.isBrowserThread()) return;
    if (self.on_event != null) self.host.call(self, CBrowser.removeListener) catch {};
    self.host.stop();
    freeBrowser(self);
}

// ============================================================================
// Tabs
// ============================================================================

/// Open a tab (BiDi browsingContext.create; CDP Target.createTarget) at
/// `url` (NULL: about:blank).
pub export fn crane_tab_create(browser: ?*CBrowser, url: ?[*:0]const u8, background: bool, out: ?*u64) callconv(.c) Status {
    const self = browser orelse return .invalid_argument;
    const result = out orelse return .invalid_argument;
    const id = self.host.createTab(.{ .url = if (url) |u| std.mem.span(u) else null, .background = background }) catch |err| return statusOf(err);
    result.* = id;
    return .ok;
}

/// Every open tab, the first page's first. Free with crane_tab_info_free.
pub export fn crane_tab_list(browser: ?*CBrowser, out: ?*?[*]TabInfo, count: ?*usize) callconv(.c) Status {
    const self = browser orelse return .invalid_argument;
    const result = out orelse return .invalid_argument;
    const length = count orelse return .invalid_argument;
    result.* = null;
    length.* = 0;
    const tabs = self.host.listTabs(allocator) catch |err| return statusOf(err);
    defer Browser.freeTabs(allocator, tabs);
    const infos = allocator.alloc(TabInfo, tabs.len) catch return .out_of_memory;
    var made: usize = 0;
    for (tabs, 0..) |tab, i| {
        const url = dupeZ(tab.url) catch break;
        const title = dupeZ(tab.title) catch {
            allocator.free(std.mem.span(url));
            break;
        };
        infos[i] = .{ .id = tab.id, .opener = tab.opener orelse 0, .created_by_web_content = tab.made_by == .page, .url = url, .title = title };
        made += 1;
    }
    if (made != tabs.len) {
        crane_tab_info_free(infos.ptr, made);
        return .out_of_memory;
    }
    result.* = infos.ptr;
    length.* = tabs.len;
    return .ok;
}

pub export fn crane_tab_info_free(infos: ?[*]TabInfo, count: usize) callconv(.c) void {
    const list = infos orelse return;
    for (list[0..count]) |info| {
        allocator.free(std.mem.span(info.url));
        allocator.free(std.mem.span(info.title));
    }
    allocator.free(list[0..count]);
}

pub export fn crane_tab_activate(browser: ?*CBrowser, tab: u64) callconv(.c) Status {
    const self = browser orelse return .invalid_argument;
    self.host.activateTab(tab) catch |err| return statusOf(err);
    return .ok;
}

/// CRANE_READY_* as the host's readiness; an unknown value is "none".
fn navigateOptions(wait: c_int) BrowserHost.NavigateOptions {
    return .{ .wait = switch (wait) {
        @backingInt(Readiness.interactive) => .interactive,
        @backingInt(Readiness.complete) => .complete,
        else => .none,
    } };
}

/// HTML "navigate" a tab as the browser's UI does (BiDi
/// browsingContext.navigate), returning at `wait`. Free with
/// crane_navigate_result_free.
pub export fn crane_tab_navigate(browser: ?*CBrowser, tab: u64, url: ?[*:0]const u8, wait: c_int, out: ?*NavigateResult) callconv(.c) Status {
    const self = browser orelse return .invalid_argument;
    const target = url orelse return .invalid_argument;
    const landed = self.host.navigate(allocator, tab, std.mem.span(target), navigateOptions(wait)) catch |err| return statusOf(err);
    defer allocator.free(landed);
    if (out) |result| result.url = dupeZ(landed) catch return .out_of_memory;
    return .ok;
}

/// HTML "reload" a tab as the browser's reload button does.
pub export fn crane_tab_reload(browser: ?*CBrowser, tab: u64, wait: c_int, out: ?*NavigateResult) callconv(.c) Status {
    const self = browser orelse return .invalid_argument;
    const landed = self.host.reload(allocator, tab, navigateOptions(wait)) catch |err| return statusOf(err);
    defer allocator.free(landed);
    if (out) |result| result.url = dupeZ(landed) catch return .out_of_memory;
    return .ok;
}

pub export fn crane_navigate_result_free(result: ?*NavigateResult) callconv(.c) void {
    const r = result orelse return;
    if (r.url) |url| allocator.free(std.mem.span(url));
    r.url = null;
}

/// HTML "traverse the history by a delta" (BiDi traverseHistory): back -1,
/// forward +1. CRANE_ERR_INVALID_ARGUMENT when there is no entry there.
pub export fn crane_tab_traverse_history(browser: ?*CBrowser, tab: u64, delta: i32) callconv(.c) Status {
    const self = browser orelse return .invalid_argument;
    const queued = self.host.traverseHistory(tab, delta) catch |err| return statusOf(err);
    return if (queued) .ok else .invalid_argument;
}

/// Evaluate `source` (`len` bytes, UTF-8) in a tab (BiDi script.evaluate):
/// flags CRANE_EVAL_AWAIT_PROMISE, CRANE_EVAL_USER_ACTIVATION. An awaited
/// promise is waited for at most 30 s (CRANE_ERR_TIMEOUT). Free with
/// crane_evaluate_result_free.
pub export fn crane_tab_evaluate(browser: ?*CBrowser, tab: u64, source: ?[*]const u8, len: usize, flags: u32, out: ?*EvaluateResult) callconv(.c) Status {
    const self = browser orelse return .invalid_argument;
    const text = source orelse return .invalid_argument;
    const result = out orelse return .invalid_argument;
    result.* = .{};
    const answer = self.host.evaluate(allocator, tab, text[0..len], .{
        .await_promise = flags & eval_await_promise != 0,
        .user_activation = flags & eval_user_activation != 0,
    }, 30_000) catch |err| return statusOf(err);
    defer answer.deinit(allocator);
    result.exception = answer.kind == .exception;
    result.json = dupeZ(answer.json) catch return .out_of_memory;
    return .ok;
}

pub export fn crane_evaluate_result_free(result: ?*EvaluateResult) callconv(.c) void {
    const r = result orelse return;
    if (r.json) |json| allocator.free(std.mem.span(json));
    r.json = null;
}

/// HTML "close a top-level traversable" (BiDi browsingContext.close):
/// beforeunload only with `prompt_unload`.
pub export fn crane_tab_close(browser: ?*CBrowser, tab: u64, prompt_unload: bool) callconv(.c) Status {
    const self = browser orelse return .invalid_argument;
    self.host.closeTab(tab, .{ .prompt_unload = prompt_unload }) catch |err| return statusOf(err);
    return .ok;
}
