//! The target registry: browser contexts, targets and sessions, as the
//! devtools thread keeps them (tmp/plans/cdp-part1-design.md 2.3, 3.2).
//!
//! Chrome's TargetHandler and DevToolsAgentHost registry
//! (content/browser/devtools/protocol/target_handler.cc,
//! devtools_agent_host_impl.cc; BSD-3) are the model:
//! - a **browser context** is a Browser (BrowserHost): the default one the
//!   embedder started, and one per Target.createBrowserContext;
//! - each tab has two targets: a **tab** target (Puppeteer attaches to these)
//!   whose one child is the tab's **page** target, whose id is its main
//!   frame's id. Frames are not targets: Crane runs a tab's frames in its
//!   agent, which is Chrome without site isolation;
//! - a **session** is a client's attachment: the connection's own browser
//!   session (no sessionId), browser sessions from attachToBrowserTarget,
//!   and tab and page sessions, flat (every message names its sessionId).
//! Everything here is the devtools thread's; nothing is locked.

const std = @import("std");
const Allocator = std.mem.Allocator;
const ids = @import("ids.zig");
const outbound = @import("outbound.zig");
const dispatch = @import("dispatch.zig");
const host_bridge = @import("host_bridge.zig");
const protocol = @import("protocol/root.zig");
const BrowserSide = @import("browser_side.zig").BrowserSide;
const PageSession = @import("page_session.zig").PageSession;

pub const TargetType = enum {
    browser,
    tab,
    page,

    pub fn name(self: TargetType) []const u8 {
        return @tagName(self);
    }
};

/// A browser context: one Browser.
pub const Context = struct {
    id: ids.Token,
    host: *host_bridge.BrowserHost,
    side: *BrowserSide,
    /// Made by Target.createBrowserContext: stopped when disposed. The
    /// default context is the embedder's.
    owned: bool,
    /// Target.createBrowserContext {disposeOnDetach}: disposed when this
    /// connection closes.
    dispose_with: ?u32 = null,
    /// Browser.setDownloadBehavior for this context.
    download_behavior: DownloadBehavior = .default,
    /// OWNED copy of the download path.
    download_path: ?[]u8 = null,
    disposed: bool = false,
};

pub const DownloadBehavior = @FieldType(protocol.Browser.setDownloadBehavior.Params, "behavior");

/// A window's bounds, as Browser.getWindowForTarget reports them: by
/// default the headless platform's window rect (kit/headless windowRect:
/// 1024x768 at the origin).
pub const WindowBounds = struct {
    left: i64 = 0,
    top: i64 = 0,
    width: i64 = 1024,
    height: i64 = 768,
    state: protocol.Browser.WindowState = .normal,
};

pub const Target = struct {
    id: ids.Token,
    type: TargetType,
    context: *Context,
    tab: host_bridge.TabId,
    /// OWNED.
    url: []u8,
    /// OWNED; empty until the page has a title (then targetInfo.title is
    /// the URL, as Chrome's when a page has none).
    title: []u8,
    opener: ?ids.Token = null,
    opened_by_page: bool = false,
    /// The tab target of a page target, the page target of a tab target.
    partner: ?*Target = null,
    /// The window it is shown in (one per tab).
    window_id: i64,
    window: WindowBounds = .{},
    /// Sessions told `waitingForDebugger: true` that have not yet sent
    /// Runtime.runIfWaitingForDebugger; at zero the tab's hold is released.
    waiting: std.ArrayList(ids.Token) = .empty,
    /// Created held (its first navigation waits for the debugger).
    held: bool = false,
    /// The simple dialog open in the tab, while its Browser thread waits in
    /// it (a page target's).
    dialog: ?host_bridge.DialogAnswer = null,
    attached_sessions: u32 = 0,
};

/// Target.setAutoAttach's settings, per session.
pub const AutoAttach = struct {
    enabled: bool = false,
    wait_for_debugger: bool = false,
    filter: Filter = .default,
};

/// A TargetFilter (Target domain): the first entry whose type matches (or
/// that names no type) decides; no match excludes. Absent, Chrome's default
/// excludes "browser" and "tab" targets and includes the rest.
pub const Filter = struct {
    entries: []const Entry = &.{},
    default_rule: bool = true,

    pub const Entry = struct {
        type: ?[]const u8 = null,
        exclude: bool = false,
    };

    pub const default: Filter = .{};

    /// A copy of the client's filter (OWNED; free with `deinit`), or the
    /// default when it gave none.
    pub fn fromParams(allocator: Allocator, filter: ?[]const protocol.Target.FilterEntry) Allocator.Error!Filter {
        const given = filter orelse return .default;
        const entries = try allocator.alloc(Entry, given.len);
        var made: usize = 0;
        errdefer {
            for (entries[0..made]) |e| if (e.type) |t| allocator.free(t);
            allocator.free(entries);
        }
        for (given, 0..) |g, i| {
            entries[i] = .{ .type = if (g.type) |t| try allocator.dupe(u8, t) else null, .exclude = g.exclude orelse false };
            made += 1;
        }
        return .{ .entries = entries, .default_rule = false };
    }

    pub fn deinit(self: *Filter, allocator: Allocator) void {
        if (self.default_rule) return;
        for (self.entries) |e| if (e.type) |t| allocator.free(t);
        allocator.free(self.entries);
        self.* = .default;
    }

    pub fn matches(self: *const Filter, target_type: TargetType) bool {
        if (self.default_rule) return target_type != .browser and target_type != .tab;
        for (self.entries) |e| {
            const t = e.type orelse return !e.exclude;
            if (std.mem.eql(u8, t, target_type.name())) return !e.exclude;
        }
        return false;
    }
};

pub const SessionKind = enum { browser, tab, page };

/// A client's attachment, on the devtools thread.
pub const Session = struct {
    /// Empty for a connection's own browser session.
    id: ids.Token,
    implicit: bool,
    kind: SessionKind,
    connection_id: u32,
    link: *outbound.SessionLink,
    failure: dispatch.Failure = .{},
    /// The current command's arena, set by the dispatcher: a handler's
    /// result may be allocated from it.
    arena: ?Allocator = null,
    /// The tab or page target (null for a browser session).
    target: ?*Target = null,
    /// A page session's Browser-thread half.
    page: ?*PageSession = null,
    /// The session whose Target.* events announced this one (its
    /// attachedToTarget and detachedFromTarget go there).
    parent: ?*Session = null,
    auto_attach: AutoAttach = .{},
    /// Target.setDiscoverTargets: null when off.
    discover: ?Filter = null,
    /// Whether this session was told waitingForDebugger: true.
    waiting: bool = false,
    /// The server this session belongs to (for handlers).
    server: *anyopaque,

    pub fn sessionId(self: *const Session) []const u8 {
        return if (self.implicit) "" else self.id.slice();
    }

    /// Fail the current command (dispatch.zig).
    pub fn fail(self: *Session, message: []const u8) error{Protocol} {
        return self.failure.set(.server_error, message);
    }

    pub fn failWithCode(self: *Session, code: dispatch.Code, message: []const u8) error{Protocol} {
        return self.failure.set(code, message);
    }

    /// Send event `E` on this session.
    pub fn emit(self: *Session, comptime E: type, params: E.Params) void {
        const json_rpc = @import("json_rpc.zig");
        const message = json_rpc.encodeEvent(self.link.allocator, E, params, self.link.sessionId()) catch return;
        self.link.send(message);
    }
};

/// The TargetInfo of `target` (Target domain). Its slices borrow from it.
pub fn targetInfo(target: *const Target) protocol.Target.TargetInfo {
    return .{
        .targetId = target.id.slice(),
        .type = target.type.name(),
        .title = if (target.title.len != 0) target.title else target.url,
        .url = target.url,
        .attached = target.attached_sessions != 0,
        .openerId = if (target.opener) |*o| o.slice() else null,
        .canAccessOpener = target.opener != null and target.opened_by_page,
        .browserContextId = target.context.id.slice(),
        .parentId = if (target.type == .page) (if (target.partner) |p| p.id.slice() else null) else null,
    };
}

test "Filter: the default excludes browser and tab; a given filter decides by its first match" {
    try std.testing.expect(Filter.default.matches(.page));
    try std.testing.expect(!Filter.default.matches(.tab));
    try std.testing.expect(!Filter.default.matches(.browser));
    // Puppeteer's browser-session filter: [{type: "page", exclude: true}, {}].
    const entries = [_]Filter.Entry{ .{ .type = "page", .exclude = true }, .{} };
    const puppeteer: Filter = .{ .entries = &entries, .default_rule = false };
    try std.testing.expect(puppeteer.matches(.tab));
    try std.testing.expect(!puppeteer.matches(.page));
    // An empty filter matches nothing.
    const empty: Filter = .{ .entries = &.{}, .default_rule = false };
    try std.testing.expect(!empty.matches(.page));
}
