//! What the page-side domains read of a Browser's navigables: frames by
//! navigable id, their documents' loader ids, and a frame's description
//! (Page.Frame) - on the Browser's thread (lane cdph, P4; design 1.2, 3.3).
//!
//! Chrome's facts the runners lean on (design 1.2): a page target's id is
//! its main frame's id (ids.zig); a document's loaderId IS the id of the
//! navigation that made it, which is also its navigation request's
//! requestId - so every Page event and every Network event of a document
//! names it the same way. Crane's navigation observer gives each
//! cross-document navigation an id (html.navigation.observer: navigate step
//! 7's navigation ID); `loaderToken` makes CDP's 32-hex-digit loaderId from
//! it, and lane cdpt's Network domain names the navigation request by the
//! same function. A document no navigation made - an initial about:blank,
//! one committed before any session listened - is given an id of its own
//! the first time a session asks (Chrome reports a loaderId for a new tab's
//! about:blank too).
//!
//! The records are a supplement of the Browser's scope (docs/instances.md
//! rule 2): per Browser, freed with it.

const std = @import("std");
const Allocator = std.mem.Allocator;
const runtime = @import("runtime");
const html = @import("html");
const dom = @import("dom");
const interfaces = @import("interfaces");
const ids = @import("ids.zig");
const protocol = @import("protocol/root.zig");
const host_bridge = @import("host_bridge.zig");
const PageSession = @import("page_session.zig").PageSession;

pub const BrowsingContext = html.BrowsingContext;
pub const ViewportSize = html.window.browsing_context.ViewportSize;
pub const Milestone = host_bridge.Milestone;

/// A loader id's half that tells it from a frame id with the same Browser
/// token (ids.zig: a frame id's low half is a navigable id; a loader id's
/// has this bit set).
const loader_bit: u64 = 1 << 63;
/// The ids given to documents no navigation made: their own range.
const synthetic_bit: u64 = 1 << 62;

pub const Frames = struct {
    allocator: Allocator,
    /// By navigable id: the document last seen committed there, and its
    /// loader id.
    records: std.AutoHashMapUnmanaged(u64, Record) = .empty,
    next_synthetic: u64 = 1,

    const Record = struct {
        document: ?*anyopaque,
        generation: u64,
        loader: u64,
    };

    pub fn init(allocator: Allocator) Frames {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Frames) void {
        self.records.deinit(self.allocator);
    }

    /// A navigation committed `document` in `navigable` (the navigation
    /// observer's `committed`): its loader id is the navigation's. Asked by
    /// every session that hears the milestone: the same answer each time.
    pub fn noteCommitted(self: *Frames, navigable_id: u64, document: *anyopaque, generation: u64, navigation_id: u64) void {
        if (navigation_id == 0) {
            // An initial about:blank: an id of its own, given once.
            if (self.records.get(navigable_id)) |record| {
                if (record.document == document and record.generation == generation) return;
            }
            self.records.put(self.allocator, navigable_id, .{ .document = document, .generation = generation, .loader = self.synthetic() }) catch {};
            return;
        }
        self.records.put(self.allocator, navigable_id, .{ .document = document, .generation = generation, .loader = navigation_id }) catch {};
    }

    /// The navigable is gone.
    pub fn forget(self: *Frames, navigable_id: u64) void {
        _ = self.records.remove(navigable_id);
    }

    /// The loader id of `bc`'s active document.
    pub fn loaderOf(self: *Frames, bc: *BrowsingContext) u64 {
        const document = bc.getActiveDocument() orelse return 0;
        const generation = runtime.SlabAllocator.generationOf(@as(*runtime.Instance, @ptrCast(@alignCast(document))));
        if (self.records.get(bc.id)) |record| {
            if (record.document == document and record.generation == generation) return record.loader;
        }
        const loader = self.synthetic();
        self.records.put(self.allocator, bc.id, .{ .document = document, .generation = generation, .loader = loader }) catch {};
        return loader;
    }

    fn synthetic(self: *Frames) u64 {
        defer self.next_synthetic += 1;
        return synthetic_bit | self.next_synthetic;
    }
};

/// The Browser's records, made on first use.
pub fn of(browser: *host_bridge.Browser) ?*Frames {
    return browser.scope.of(Frames) catch null;
}

/// CDP's loaderId (Network.LoaderId) for loader id `loader` of the session's
/// Browser - the requestId of the navigation request that made the document
/// (lane cdpt's Network domain uses this function for it).
pub fn loaderToken(session: *const PageSession, loader: u64) ids.Token {
    return ids.Token.of(session.side.?.token, loader_bit | loader);
}

/// The navigable with id `id` in the session's Browser, while it lives.
pub fn navigable(session: *const PageSession, id: u64) ?*BrowsingContext {
    const browser = session.browser orelse return null;
    const navigables = dom.browser_state.existingNavigablesIn(browser.scope) orelse return null;
    const bc = navigables.byId(id) orelse return null;
    if (bc.is_closed or bc.active_window == null) return null;
    return bc;
}

/// Whether navigable `id` is the session's tab or one of its frames.
pub fn inTab(session: *const PageSession, id: u64) bool {
    if (id == session.tab) return true;
    const bc = navigable(session, id) orelse return false;
    return bc.getTop().id == session.tab;
}

/// The navigable a CDP frame id names in the session's tab, or the tab's
/// main frame for null.
pub fn frameNamed(session: *const PageSession, frame_id: ?[]const u8) ?*BrowsingContext {
    const id = if (frame_id) |text| session.navigableOf(text) orelse return null else session.tab;
    if (!inTab(session, id)) return null;
    return navigable(session, id);
}

/// `bc`'s active document and Window.
pub fn documentOf(bc: *BrowsingContext) ?*runtime.Instance {
    const document = bc.getActiveDocument() orelse return null;
    return @ptrCast(@alignCast(document));
}

pub fn windowOf(bc: *BrowsingContext) ?*runtime.Instance {
    const window = bc.getActiveWindow() orelse return null;
    return @ptrCast(@alignCast(window));
}

/// The realm of `bc`'s active Window (its main world).
pub fn mainRealmOf(bc: *BrowsingContext) ?runtime.Context {
    const window = windowOf(bc) orelse return null;
    return window.ctx;
}

/// `document`'s URL, in `arena`.
pub fn documentUrl(arena: Allocator, document: *runtime.Instance) ![]const u8 {
    const url = interfaces.Document.get_URL(document) catch return "about:blank";
    defer document.ctx.allocator.free(url);
    return arena.dupe(u8, if (url.len == 0) "about:blank" else url);
}

/// The Page.Frame of `bc` (Blink's InspectorPageAgent::BuildObjectForFrame),
/// its strings in `arena`.
pub fn describe(session: *const PageSession, arena: Allocator, bc: *BrowsingContext) !protocol.Page.Frame {
    const document = documentOf(bc);
    const url = if (document) |d| try documentUrl(arena, d) else "about:blank";
    // The URL without its fragment, and the fragment with its '#'.
    const hash = std.mem.indexOfScalar(u8, url, '#');
    const origin: []const u8 = blk: {
        const window = windowOf(bc) orelse break :blk "null";
        const text = interfaces.Window.get_origin(window) catch break :blk "null";
        defer window.ctx.allocator.free(text);
        break :blk try arena.dupe(u8, text);
    };
    const mime: []const u8 = blk: {
        const d = document orelse break :blk "text/html";
        var content_type = interfaces.Document.get_contentType(d) catch break :blk "text/html";
        defer content_type.deinit(d.ctx.allocator);
        break :blk try arena.dupe(u8, content_type.asSlice());
    };
    const frames = of(session.browser.?);
    const loader = if (frames) |f| f.loaderOf(bc) else 0;
    const loader_id = loaderToken(session, loader);
    const frame_id = session.frameId(bc.id);
    const secure = if (mainRealmOf(bc)) |realm| realm.secure_context else false;
    return .{
        .id = try arena.dupe(u8, frame_id.slice()),
        .parentId = if (bc.parent) |parent| try arena.dupe(u8, session.frameId(parent.id).slice()) else null,
        .loaderId = try arena.dupe(u8, loader_id.slice()),
        .name = if (bc.target_name.len > 0) try arena.dupe(u8, bc.target_name) else null,
        .url = if (hash) |i| url[0..i] else url,
        .urlFragment = if (hash) |i| url[i..] else null,
        // TODO(cdph): the registrable domain from the public suffix list
        // (Chrome's net::registry_controlled_domains); "" as Chrome gives for
        // an IP address or a host with no registrable domain.
        .domainAndRegistry = "",
        .securityOrigin = origin,
        .mimeType = mime,
        .secureContextType = if (!secure) .InsecureScheme else if (isLocalhostOrigin(origin)) .SecureLocalhost else .Secure,
        .crossOriginIsolatedContextType = if (bc.groupIsCrossOriginIsolated()) .Isolated else .NotIsolated,
        .gatedAPIFeatures = &.{},
    };
}

/// Chrome's SecureLocalhost: a potentially trustworthy origin only because
/// its host is localhost or a loopback address.
fn isLocalhostOrigin(origin: []const u8) bool {
    const rest = if (std.mem.indexOf(u8, origin, "://")) |i| origin[i + 3 ..] else return false;
    const host = if (std.mem.lastIndexOfScalar(u8, rest, ':')) |i| rest[0..i] else rest;
    return std.mem.eql(u8, host, "localhost") or std.mem.endsWith(u8, host, ".localhost") or
        std.mem.startsWith(u8, host, "127.") or std.mem.eql(u8, host, "[::1]");
}

/// The Page.FrameTree of `bc` and its open child navigables, in `arena`.
pub fn tree(session: *const PageSession, arena: Allocator, bc: *BrowsingContext) !protocol.Page.FrameTree {
    var children: std.ArrayListUnmanaged(protocol.Page.FrameTree) = .empty;
    for (bc.children.items) |child| {
        if (child.is_closed or child.active_window == null) continue;
        try children.append(arena, try tree(session, arena, child));
    }
    return .{
        .frame = try describe(session, arena, bc),
        .childFrames = if (children.items.len > 0) children.items else null,
    };
}

/// Seconds on the monotonic clock: CDP's MonotonicTime (Chrome's
/// base::TimeTicks in seconds), as lane cdpt's Network timestamps.
pub fn monotonicSeconds() f64 {
    const ns = @import("platform").monotonicNow().ns;
    return @as(f64, @floatFromInt(ns)) / std.time.ns_per_s;
}

test "a loader id never reads as a frame id of the same Browser" {
    const loader = ids.Token.of(7, loader_bit | 42);
    const ref = ids.parseFrameId(loader.slice()).?;
    try std.testing.expect(ref.navigable_id != 42);
}

test "localhost origins are SecureLocalhost" {
    try std.testing.expect(isLocalhostOrigin("http://localhost:9090"));
    try std.testing.expect(isLocalhostOrigin("http://127.0.0.1:8000"));
    try std.testing.expect(!isLocalhostOrigin("https://example.test"));
    try std.testing.expect(!isLocalhostOrigin("null"));
}
