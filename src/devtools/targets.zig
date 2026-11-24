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
    /// `display_url`, as Chrome's when a page has none).
    title: []u8,
    /// OWNED: `url` as Chrome shows it for a page with no title
    /// (`displayUrl`), kept with `url` by `setUrl`.
    display_url: []u8 = &.{},
    /// Whether the tab has committed a document the remote end heard of
    /// (`navigated`): before it, Chrome reports the title "" - and a new
    /// tab's tab target the URL "" (vue-e2e protocol log l.2-18, l.103).
    committed: bool = false,
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
/// Chrome 157's (vue-e2e protocol log l.2-18, lane cdpr's G15): the title
/// is "" until the tab commits, then the document's title or, with none,
/// the URL as Chrome displays it (WebContents::GetTitle's fallback,
/// `displayUrl`); a page target names no parentId (Chrome sets it for a
/// frame or worker target under a page, not for a tab's page).
pub fn targetInfo(target: *const Target) protocol.Target.TargetInfo {
    return .{
        .targetId = target.id.slice(),
        .type = target.type.name(),
        .title = shownTitle(target),
        .url = target.url,
        .attached = target.attached_sessions != 0,
        .openerId = if (target.opener) |*o| o.slice() else null,
        .canAccessOpener = target.opener != null and target.opened_by_page,
        .browserContextId = target.context.id.slice(),
    };
}

/// The title a target shows: its document's, else - once it has
/// committed - its URL as Chrome displays it, else "".
pub fn shownTitle(target: *const Target) []const u8 {
    if (target.title.len != 0) return target.title;
    return if (target.committed) target.display_url else "";
}

/// Replace `target`'s URL (OWNED by `allocator`) and its display form.
pub fn setUrl(allocator: Allocator, target: *Target, url: []const u8) Allocator.Error!void {
    const copy = try allocator.dupe(u8, url);
    errdefer allocator.free(copy);
    const shown = try displayUrl(allocator, url);
    allocator.free(target.url);
    allocator.free(target.display_url);
    target.url = copy;
    target.display_url = shown;
}

/// Chrome's kMaxTitleChars (content/public/common/content_constants.h).
const max_title_chars = 4 * 1024;

/// What Chrome shows as the title of a page that has none: Chromium's
/// NavigationEntryImpl::GetTitleForDisplay
/// (content/browser/renderer_host/navigation_entry_impl.cc) over
/// url_formatter::FormatUrl(url) with its defaults
/// (components/url_formatter/url_formatter.cc, FormatUrlWithAdjustments:
/// kFormatUrlOmitDefaults - no username and password, no "http://" unless
/// the host starts with "ftp.", no "/" after a bare hostname - and
/// UnescapeRule::SPACES, "%20" shown as a space in the path, query and
/// fragment); a file: URL shows its file name; then gfx::ElideString to
/// kMaxTitleChars. Chromium, tag 157.0.8103.78, BSD-3-Clause: the
/// algorithm, reproduced, not its code. Measured against Chrome for Testing
/// 157 by tests/devtools/mcp1_target_title_test.zig ("127.0.0.1:<port>/
/// frame.html", "data:text/html,<p>x</p>", "about:blank").
/// TODO(mcp1): FormatUrl's IDNToUnicodeWithAdjustments - a punycode host
/// Chrome deems safe is shown in Unicode; Crane shows it as serialized.
pub fn displayUrl(allocator: Allocator, url: []const u8) Allocator.Error![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);
    const colon = std.mem.indexOfScalar(u8, url, ':') orelse {
        try out.appendSlice(allocator, url);
        return elide(allocator, &out);
    };
    const scheme = url[0..colon];
    var rest = url[colon + 1 ..];
    var standard = false;
    if (std.mem.startsWith(u8, rest, "//")) {
        standard = true;
        const authority_end = std.mem.indexOfAny(u8, rest[2..], "/?#") orelse rest.len - 2;
        var authority = rest[2 .. 2 + authority_end];
        const after = rest[2 + authority_end ..];
        // kFormatUrlOmitUsernamePassword.
        if (std.mem.lastIndexOfScalar(u8, authority, '@')) |at| authority = authority[at + 1 ..];
        // kFormatUrlOmitHTTP: not for a host that would read as ftp.
        const omit_scheme = std.mem.eql(u8, scheme, "http") and !std.ascii.startsWithIgnoreCase(authority, "ftp.");
        if (!omit_scheme) {
            try out.appendSlice(allocator, scheme);
            try out.appendSlice(allocator, "://");
        }
        try out.appendSlice(allocator, authority);
        rest = after;
        // kFormatUrlOmitTrailingSlashOnBareHostname (CanStripTrailingSlash):
        // a standard, non-file URL whose path is "/" with no query or ref.
        if (std.mem.eql(u8, rest, "/") and !std.mem.eql(u8, scheme, "file") and !std.mem.eql(u8, scheme, "filesystem")) rest = "";
    } else {
        try out.appendSlice(allocator, scheme);
        try out.append(allocator, ':');
    }
    // UnescapeRule::SPACES over the rest.
    var i: usize = 0;
    while (i < rest.len) {
        if (i + 2 < rest.len and rest[i] == '%' and rest[i + 1] == '2' and rest[i + 2] == '0') {
            try out.append(allocator, ' ');
            i += 3;
            continue;
        }
        try out.append(allocator, rest[i]);
        i += 1;
    }
    // A file: URL's file name: after the last "/" before its query or ref.
    if (standard and std.mem.eql(u8, scheme, "file")) {
        const text = out.items;
        const last = std.mem.indexOfAny(u8, text, "?#") orelse text.len;
        if (std.mem.lastIndexOfScalar(u8, text[0..last], '/')) |slash| {
            const name = try allocator.dupe(u8, text[slash + 1 ..]);
            out.deinit(allocator);
            out = .fromOwnedSlice(name);
        }
    }
    return elide(allocator, &out);
}

/// gfx::ElideString(text, kMaxTitleChars): a longer text keeps its first
/// and last characters around "..." (the URL text is ASCII).
fn elide(allocator: Allocator, out: *std.ArrayList(u8)) Allocator.Error![]u8 {
    if (out.items.len <= max_title_chars) return out.toOwnedSlice(allocator);
    const right = (max_title_chars - 3) / 2;
    const left = right + (max_title_chars - 3) % 2;
    const text = out.items;
    const elided = try std.mem.concat(allocator, u8, &.{ text[0..left], "...", text[text.len - right ..] });
    out.deinit(allocator);
    return elided;
}

test "displayUrl: a titleless page's URL as Chrome shows it" {
    const cases = [_][2][]const u8{
        .{ "http://127.0.0.1:64983/frame.html", "127.0.0.1:64983/frame.html" },
        .{ "http://example.com/", "example.com" },
        .{ "http://example.com/?q", "example.com/?q" },
        .{ "https://example.com/", "https://example.com" },
        .{ "http://user:pass@example.com/a", "example.com/a" },
        .{ "http://ftp.example.com/", "http://ftp.example.com" },
        .{ "http://example.com/a%20b?c%20d#e%20f", "example.com/a b?c d#e f" },
        .{ "data:text/html,<p>x</p>", "data:text/html,<p>x</p>" },
        .{ "data:text/html,a%20b", "data:text/html,a b" },
        .{ "about:blank", "about:blank" },
        .{ "file:///Users/me/page.html?x=/y#z", "page.html?x=/y#z" },
        .{ "file:///", "" },
    };
    for (cases) |c| {
        const shown = try displayUrl(std.testing.allocator, c[0]);
        defer std.testing.allocator.free(shown);
        try std.testing.expectEqualStrings(c[1], shown);
    }
    const run: [5000]u8 = @splat('x');
    const long = "http://a.test/" ++ run;
    const shown = try displayUrl(std.testing.allocator, long);
    defer std.testing.allocator.free(shown);
    try std.testing.expectEqual(@as(usize, max_title_chars), shown.len);
    try std.testing.expect(std.mem.startsWith(u8, shown, "a.test/xx"));
    try std.testing.expectEqualStrings("...", shown[2047..2050]);
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
