//! The Log domain on page sessions (lane cdph, P4; design 3.11): accepted
//! per session, as every runner enables it. Log.entryAdded carries the
//! browser's own messages about the page - network errors, CSP and
//! permissions-policy violations, interventions (Blink's InspectorLogAgent)
//! - from their report points; the page's console output is Runtime's
//! (consoleAPICalled), not Log's.
//!
//! A tab's entries are kept for a Log.enable that comes later (`Storage`:
//! Blink's ConsoleMessageStorage, which Log.enable replays), whether or not
//! a session listens, while the remote end is on the Browser (the storage
//! is the BrowserSide's, so a Browser with no devtools pays nothing).

const std = @import("std");
const Allocator = std.mem.Allocator;
const PageSession = @import("../page_session.zig").PageSession;
const BrowserSide = @import("../browser_side.zig").BrowserSide;
const host_bridge = @import("../host_bridge.zig");
const protocol = @import("../protocol/root.zig");
const L = protocol.Log;
const html = @import("html");
const dom = @import("dom");
const perf = dom.performance_monitor;

/// Per-session state of the domain.
pub const State = struct {
    enabled: bool = false,
    /// Log.startViolationsReport's thresholds were asked for.
    violations: bool = false,
};

/// InspectorLogAgent::enable (third_party/blink/renderer/core/inspector/
/// inspector_log_agent.cc, BSD): already enabled, nothing more; otherwise
/// InnerEnable - the tab's kept entries go out, before the answer.
pub fn enable(session: *PageSession, params: L.enable.Params) !L.enable.Result {
    _ = params;
    if (session.states.Log.enabled) return .{};
    session.states.Log.enabled = true;
    if (session.side) |side| replay(session, &side.log_storage);
    return .{};
}

pub fn disable(session: *PageSession, params: L.disable.Params) !L.disable.Result {
    _ = params;
    unsubscribe(session);
    session.states.Log = .{};
    return .{};
}

pub fn sessionEnded(session: *PageSession) void {
    unsubscribe(session);
}

fn unsubscribe(session: *PageSession) void {
    if (!session.states.Log.violations) return;
    session.states.Log.violations = false;
    const browser = session.browser orelse return;
    const monitor = perf.Monitor.of(browser.scope) catch return;
    monitor.unsubscribeAll(session);
}

/// The tab's kept entries go (InspectorLogAgent::clear -> storage_->Clear()):
/// a later Log.enable, in any session on the tab, replays none of them.
pub fn clear(session: *PageSession, params: L.clear.Params) !L.clear.Result {
    _ = params;
    if (session.side) |side| side.log_storage.clearTab(side.allocator, session.tab);
    return .{};
}

/// The session hears the violations named, each at its threshold
/// (InspectorLogAgent::startViolationsReport: the earlier settings go,
/// unknown names are skipped) through the Browser's performance monitor
/// (dom.performance_monitor: Blink's PerformanceMonitor).
pub fn startViolationsReport(session: *PageSession, params: L.startViolationsReport.Params) !L.startViolationsReport.Result {
    if (!session.states.Log.enabled) return session.fail("Log is not enabled");
    const browser = session.browser orelse return session.fail("Violations are not supported for this target");
    const monitor = perf.Monitor.of(browser.scope) catch return session.fail("Violations are not supported for this target");
    monitor.unsubscribeAll(session);
    session.states.Log.violations = true;
    for (params.config) |setting| {
        const violation = perf.Violation.ofName(@tagName(setting.name)) orelse continue;
        const threshold_ns: i64 = @intFromFloat(setting.threshold * std.time.ns_per_ms);
        try monitor.subscribe(.{ .context = session, .tab = session.tab, .report = onViolation }, violation, threshold_ns);
    }
    return .{};
}

pub fn stopViolationsReport(session: *PageSession, params: L.stopViolationsReport.Params) !L.stopViolationsReport.Result {
    _ = params;
    unsubscribe(session);
    return .{};
}

/// A violation the session subscribed to: InspectorLogAgent::
/// ReportGenericViolation - source violation, level verbose. Sent to the
/// session only, never kept: Blink's agent makes the message and calls its
/// own ConsoleMessageAdded, past the page's ConsoleMessageStorage.
fn onViolation(context: *anyopaque, violation: perf.Violation, text: []const u8, url: []const u8) void {
    _ = violation;
    const session: *PageSession = @ptrCast(@alignCast(context));
    if (!session.states.Log.enabled) return;
    session.emit(L.entryAdded, .{ .entry = .{
        .source = .violation,
        .level = .verbose,
        .text = text,
        .timestamp = wallMs(),
        .url = if (url.len > 0) url else null,
    } });
}

// ============================================================================
// Entries (Blink's InspectorLogAgent::ConsoleMessageAdded)
// ============================================================================

/// Runtime.Timestamp: milliseconds since the epoch.
fn wallMs() f64 {
    return @as(f64, @floatFromInt(@import("platform").wallNow().ns_since_epoch)) / std.time.ns_per_ms;
}

/// `entry` is kept for the tab (ConsoleMessageStorage::AddConsoleMessage
/// tells the agents - probe::ConsoleMessageAdded - and stores it), and
/// Log.entryAdded goes to every session on `tab` with the domain enabled.
fn emitToTab(side: *BrowserSide, tab: u64, entry: L.LogEntry) void {
    side.log_storage.add(side.allocator, tab, entry) catch {};
    for (side.sessions.items) |s| {
        if (s.tab != tab or !s.states.Log.enabled) continue;
        s.emit(L.entryAdded, .{ .entry = entry });
    }
}

/// A fetch of the tab's failed (the fetch observer's loadingFailed, not for
/// a cancellation): Blink's FrameConsole::DidFailLoading - "Failed to load
/// resource" and the error's description, source network, level error, the
/// failing URL and the request's id.
pub fn loadingFailed(side: *BrowserSide, tab: u64, url: []const u8, request_id: []const u8, error_text: []const u8) void {
    var buffer: [256]u8 = undefined;
    const text = if (error_text.len > 0)
        std.fmt.bufPrint(&buffer, "Failed to load resource: {s}", .{error_text}) catch "Failed to load resource"
    else
        "Failed to load resource";
    emitToTab(side, tab, .{
        .source = .network,
        .level = .@"error",
        .text = text,
        .timestamp = wallMs(),
        .url = if (url.len > 0) url else null,
        .networkRequestId = if (request_id.len > 0) request_id else null,
    });
}

/// A response of 400 or more for a fetch of the tab: Blink's
/// ResourceLoadObserverForFrame::DidReceiveResponse - "Failed to load
/// resource: the server responded with a status of <status> (<text>)".
pub fn errorResponse(side: *BrowserSide, tab: u64, url: []const u8, request_id: []const u8, status: u16, status_text: []const u8) void {
    var buffer: [256]u8 = undefined;
    const text = std.fmt.bufPrint(&buffer, "Failed to load resource: the server responded with a status of {d} ({s})", .{ status, status_text }) catch "Failed to load resource";
    emitToTab(side, tab, .{
        .source = .network,
        .level = .@"error",
        .text = text,
        .timestamp = wallMs(),
        .url = if (url.len > 0) url else null,
        .networkRequestId = if (request_id.len > 0) request_id else null,
    });
}

// ============================================================================
// The kept entries (Blink's ConsoleMessageStorage)
// ============================================================================

/// A document, by identity and slab generation (the navigation observer's).
const DocumentRef = html.navigation.observer.DocumentRef;

/// Each tab's Log entries, kept for a Log.enable that comes later - Blink's
/// ConsoleMessageStorage, one per Page (third_party/blink/renderer/core/
/// inspector/console_message_storage.cc, BSD): AddConsoleMessage keeps at
/// most kMaxConsoleMessageCount (1000), dropping the oldest and counting it
/// (expired_count_); Clear empties both. A page's storage is emptied when
/// its main frame commits a new document for a regular reason
/// (DocumentLoader::DidCommitNavigation -> Page::DidCommitLoad,
/// third_party/blink/renderer/core/page/page.cc - read, not copied: LGPL),
/// and by InspectorLogAgent::clear. A javascript: URL's or XSLT's
/// replacement document, and the initial empty document, do not reach
/// Page::DidCommitLoad: the page's entries stay. A page the back/forward
/// cache keeps is a Page of its own in Chrome, with its own storage, which
/// shows again when the page is restored: here the entries of the page a
/// regular commit left are parked by its document, and a restore of that
/// document takes them back.
///
/// Kept by the BrowserSide (`log_storage`), on the Browser's thread. The
/// tabs are few, so lists, searched (no hash map to tombstone).
pub const Storage = struct {
    /// The page each tab shows now.
    pages: std.ArrayList(Page) = .empty,
    /// Pages a commit left, for a restore of their document (oldest first;
    /// as many as the Browser's back/forward cache keeps).
    parked: std.ArrayList(Page) = .empty,

    /// Blink's kMaxConsoleMessageCount.
    pub const max_entries = 1000;

    pub const Page = struct {
        tab: u64,
        /// The document the page shows, from its top-level commits; null
        /// when none was seen (the remote end came after it).
        document: ?DocumentRef = null,
        /// The entries, their strings OWNED: in order while fewer than
        /// `max_entries`; once full, a ring whose oldest is at `head`.
        ring: std.ArrayList(L.LogEntry) = .empty,
        head: usize = 0,
        /// How many the bound dropped since the last clear.
        expired: u64 = 0,

        fn clearEntries(self: *Page, allocator: Allocator) void {
            for (self.ring.items) |*entry| freeEntry(allocator, entry);
            self.ring.deinit(allocator);
            self.ring = .empty;
            self.head = 0;
            self.expired = 0;
        }

        fn deinit(self: *Page, allocator: Allocator) void {
            self.clearEntries(allocator);
        }

        fn shows(self: *const Page, document: DocumentRef) bool {
            const mine = self.document orelse return false;
            return mine.document == document.document and mine.generation == document.generation;
        }
    };

    pub fn deinit(self: *Storage, allocator: Allocator) void {
        for (self.pages.items) |*page| page.deinit(allocator);
        self.pages.deinit(allocator);
        for (self.parked.items) |*page| page.deinit(allocator);
        self.parked.deinit(allocator);
        self.* = .{};
    }

    fn indexOf(self: *const Storage, tab: u64) ?usize {
        for (self.pages.items, 0..) |page, i| if (page.tab == tab) return i;
        return null;
    }

    fn current(self: *Storage, tab: u64) ?*Page {
        const i = self.indexOf(tab) orelse return null;
        return &self.pages.items[i];
    }

    /// Keep a copy of `entry` for `tab`'s page; when it has `max_entries`
    /// already, its oldest goes and is counted.
    pub fn add(self: *Storage, allocator: Allocator, tab: u64, entry: L.LogEntry) Allocator.Error!void {
        var copy = try copyEntry(allocator, entry);
        errdefer freeEntry(allocator, &copy);
        const page = self.current(tab) orelse blk: {
            try self.pages.append(allocator, .{ .tab = tab });
            break :blk &self.pages.items[self.pages.items.len - 1];
        };
        if (page.ring.items.len < max_entries) {
            try page.ring.append(allocator, copy);
            return;
        }
        freeEntry(allocator, &page.ring.items[page.head]);
        page.ring.items[page.head] = copy;
        page.head = (page.head + 1) % max_entries;
        page.expired += 1;
    }

    /// Log.clear (InspectorLogAgent::clear -> ConsoleMessageStorage::Clear):
    /// the entries of `tab`'s page and their count go; the page stays.
    pub fn clearTab(self: *Storage, allocator: Allocator, tab: u64) void {
        if (self.current(tab)) |page| page.clearEntries(allocator);
    }

    /// The tab is gone: its page and its parked pages go.
    pub fn forgetTab(self: *Storage, allocator: Allocator, tab: u64) void {
        if (self.indexOf(tab)) |i| {
            var page = self.pages.swapRemove(i);
            page.deinit(allocator);
        }
        var i: usize = 0;
        while (i < self.parked.items.len) {
            if (self.parked.items[i].tab != tab) {
                i += 1;
                continue;
            }
            var page = self.parked.orderedRemove(i);
            page.deinit(allocator);
        }
    }

    /// Top-level traversable `tab` committed `document` for `kind`, or
    /// showed it again from the back/forward cache (`restored`); the
    /// Browser's cache keeps at most `parked_cap` pages.
    pub fn committed(self: *Storage, allocator: Allocator, tab: u64, document: DocumentRef, kind: html.navigation.observer.CommitKind, restored: bool, parked_cap: usize) void {
        if (restored) {
            // Not a commit in Blink: the restored Page, with the storage it
            // had, is shown again; the page left keeps its own.
            self.park(allocator, tab, parked_cap);
            const page = self.takeParked(tab, document) orelse Page{ .tab = tab, .document = document };
            self.pages.append(allocator, page) catch {
                var lost = page;
                lost.deinit(allocator);
            };
            return;
        }
        switch (kind) {
            // Page::DidCommitLoad: a new page's storage, empty.
            .regular => {
                self.park(allocator, tab, parked_cap);
                self.pages.append(allocator, .{ .tab = tab, .document = document }) catch {};
            },
            // The same page goes on with a replacement document.
            .javascript_url, .xslt => if (self.current(tab)) |page| {
                page.document = document;
            },
            // The first document of a traversable: nothing kept yet.
            .initialization => {},
        }
    }

    /// `tab`'s page leaves: parked by its document when it has entries and
    /// a document to be found by - the oldest parked one going when there
    /// are more than `cap`, as the cache's oldest page leaves first
    /// (src/browser/back_forward_cache.zig) - else freed.
    fn park(self: *Storage, allocator: Allocator, tab: u64, cap: usize) void {
        const i = self.indexOf(tab) orelse return;
        var page = self.pages.swapRemove(i);
        if (cap == 0 or page.document == null or (page.ring.items.len == 0 and page.expired == 0)) {
            page.deinit(allocator);
            return;
        }
        self.parked.append(allocator, page) catch {
            page.deinit(allocator);
            return;
        };
        while (self.parked.items.len > cap) {
            var oldest = self.parked.orderedRemove(0);
            oldest.deinit(allocator);
        }
    }

    fn takeParked(self: *Storage, tab: u64, document: DocumentRef) ?Page {
        for (self.parked.items, 0..) |*page, i| {
            if (page.tab == tab and page.shows(document)) return self.parked.orderedRemove(i);
        }
        return null;
    }

    /// `tab`'s kept entries, oldest first, each to `visit`, after the
    /// count of those dropped.
    pub fn each(self: *Storage, tab: u64, context: anytype, comptime visit: fn (@TypeOf(context), expired: u64, entry: ?*const L.LogEntry) void) void {
        const page = self.current(tab) orelse return;
        if (page.expired > 0) visit(context, page.expired, null);
        const n = page.ring.items.len;
        for (0..n) |i| visit(context, 0, &page.ring.items[(page.head + i) % n]);
    }
};

/// A copy of `entry` whose strings are `allocator`'s. A network entry
/// carries no stack trace, worker or arguments; none is kept.
fn copyEntry(allocator: Allocator, entry: L.LogEntry) Allocator.Error!L.LogEntry {
    var copy = entry;
    copy.stackTrace = null;
    copy.workerId = null;
    copy.args = null;
    copy.text = try allocator.dupe(u8, entry.text);
    errdefer allocator.free(copy.text);
    copy.url = if (entry.url) |url| try allocator.dupe(u8, url) else null;
    errdefer if (copy.url) |url| allocator.free(url);
    copy.networkRequestId = if (entry.networkRequestId) |id| try allocator.dupe(u8, id) else null;
    return copy;
}

fn freeEntry(allocator: Allocator, entry: *L.LogEntry) void {
    allocator.free(entry.text);
    if (entry.url) |url| allocator.free(url);
    if (entry.networkRequestId) |id| allocator.free(id);
    entry.* = undefined;
}

/// InspectorLogAgent::InnerEnable's replay to `session`: when entries were
/// dropped, a warning saying how many ("<n> log entries are not shown.",
/// source other, timestamp 0), then each kept entry as it was made.
fn replay(session: *PageSession, storage: *Storage) void {
    const Visit = struct {
        fn send(s: *PageSession, expired: u64, entry: ?*const L.LogEntry) void {
            if (entry) |e| return s.emit(L.entryAdded, .{ .entry = e.* });
            var buffer: [64]u8 = undefined;
            const text = std.fmt.bufPrint(&buffer, "{d} log entries are not shown.", .{expired}) catch return;
            s.emit(L.entryAdded, .{ .entry = .{ .source = .other, .level = .warning, .text = text, .timestamp = 0 } });
        }
    };
    storage.each(session.tab, session, Visit.send);
}

/// A milestone of the Browser's navigables, whether or not a session
/// listens (BrowserSide.fanOutNavigation): a top-level traversable's commit
/// - its navigable id is its tab's - goes to the storage with its kind
/// (Storage.committed); a child navigable's commit is not its page's.
/// A main document's own error response (errorResponse, at its response)
/// is cleared with the rest at its regular commit, as in Chrome, where
/// DocumentLoader::CommitNavigation reports it
/// (RecordConsoleMessagesForCommit) before DidCommitNavigation reaches
/// Page::DidCommitLoad: a session listening then hears it, a later
/// Log.enable does not.
pub fn onMilestone(side: *BrowserSide, milestone: *const host_bridge.Milestone) void {
    const commit = switch (milestone.event) {
        .committed => |c| c,
        else => return,
    };
    const browser = side.browser orelse return;
    const navigables = dom.browser_state.existingNavigablesIn(browser.scope) orelse return;
    const bc = navigables.byId(milestone.navigable_id) orelse return;
    if (bc.parent != null) return;
    side.log_storage.committed(side.allocator, milestone.navigable_id, commit.document, commit.kind, commit.restored, browser.config.back_forward_cache_size);
}

/// The tab is gone: its kept entries go with it.
pub fn tabGone(side: *BrowserSide, tab: u64) void {
    side.log_storage.forgetTab(side.allocator, tab);
}

fn testEntry(text: []const u8) L.LogEntry {
    return .{ .source = .network, .level = .@"error", .text = text, .timestamp = 1, .url = "https://a.test/x", .networkRequestId = "7" };
}

/// What `Storage.each` visited, for the tests.
const Seen = struct {
    expired: u64 = 0,
    first: [16]u8 = undefined,
    first_len: usize = 0,
    last: [16]u8 = undefined,
    last_len: usize = 0,
    count: usize = 0,

    fn visit(self: *Seen, expired: u64, entry: ?*const L.LogEntry) void {
        const e = entry orelse {
            self.expired = expired;
            return;
        };
        if (self.count == 0) {
            @memcpy(self.first[0..e.text.len], e.text);
            self.first_len = e.text.len;
        }
        @memcpy(self.last[0..e.text.len], e.text);
        self.last_len = e.text.len;
        self.count += 1;
    }

    fn of(storage: *Storage, tab: u64) Seen {
        var seen: Seen = .{};
        storage.each(tab, &seen, visit);
        return seen;
    }
};

test "a tab keeps at most 1000 entries, the oldest dropped and counted; Log.clear and the tab's end empty it" {
    const allocator = std.testing.allocator;
    var storage: Storage = .{};
    defer storage.deinit(allocator);
    var buffer: [16]u8 = undefined;
    for (0..Storage.max_entries + 2) |i| {
        try storage.add(allocator, 1, testEntry(try std.fmt.bufPrint(&buffer, "e{d}", .{i})));
    }
    try storage.add(allocator, 2, testEntry("other tab"));

    const seen = Seen.of(&storage, 1);
    try std.testing.expectEqual(@as(u64, 2), seen.expired);
    try std.testing.expectEqual(@as(usize, Storage.max_entries), seen.count);
    try std.testing.expectEqualStrings("e2", seen.first[0..seen.first_len]);
    try std.testing.expectEqualStrings("e1001", seen.last[0..seen.last_len]);

    storage.clearTab(allocator, 1);
    const cleared = Seen.of(&storage, 1);
    try std.testing.expectEqual(@as(usize, 0), cleared.count);
    try std.testing.expectEqual(@as(u64, 0), cleared.expired);
    try std.testing.expectEqual(@as(usize, 1), Seen.of(&storage, 2).count);
    storage.forgetTab(allocator, 2);
    try std.testing.expectEqual(@as(usize, 0), Seen.of(&storage, 2).count);
}

test "only a regular commit starts a new page's entries; a restore shows its own page's again (Blink's CommitReason, Page::DidCommitLoad)" {
    const allocator = std.testing.allocator;
    var storage: Storage = .{};
    defer storage.deinit(allocator);
    var a_doc: u8 = 0;
    var b_doc: u8 = 0;
    var c_doc: u8 = 0;
    const a: DocumentRef = .{ .document = &a_doc, .generation = 1 };
    const b: DocumentRef = .{ .document = &b_doc, .generation = 1 };
    const js: DocumentRef = .{ .document = &c_doc, .generation = 1 };

    // The initial about:blank, then page A (regular) with an entry.
    storage.committed(allocator, 1, .{ .document = &a_doc, .generation = 0 }, .initialization, false, 8);
    storage.committed(allocator, 1, a, .regular, false, 8);
    try storage.add(allocator, 1, testEntry("on a"));
    // A javascript: URL's document replaces A's: the same page, kept.
    storage.committed(allocator, 1, js, .javascript_url, false, 8);
    try std.testing.expectEqual(@as(usize, 1), Seen.of(&storage, 1).count);
    // Page B (regular): a new page, empty; A's (now the javascript: URL
    // document's) parked.
    storage.committed(allocator, 1, b, .regular, false, 8);
    try std.testing.expectEqual(@as(usize, 0), Seen.of(&storage, 1).count);
    try storage.add(allocator, 1, testEntry("on b"));
    // Back to the javascript: URL's document from the cache: its page's
    // entry again, and B's parked.
    storage.committed(allocator, 1, js, .regular, true, 8);
    const back = Seen.of(&storage, 1);
    try std.testing.expectEqual(@as(usize, 1), back.count);
    try std.testing.expectEqualStrings("on a", back.first[0..back.first_len]);
    // Forward to B from the cache.
    storage.committed(allocator, 1, b, .regular, true, 8);
    const forward = Seen.of(&storage, 1);
    try std.testing.expectEqualStrings("on b", forward.first[0..forward.first_len]);
    // A restore of a document whose page was not parked shows nothing.
    var d_doc: u8 = 0;
    storage.committed(allocator, 1, .{ .document = &d_doc, .generation = 1 }, .regular, true, 8);
    try std.testing.expectEqual(@as(usize, 0), Seen.of(&storage, 1).count);
}

test "parked pages are as many as the back/forward cache keeps, the oldest leaving first" {
    const allocator = std.testing.allocator;
    var storage: Storage = .{};
    defer storage.deinit(allocator);
    var docs: [3]u8 = .{ 0, 0, 0 };
    const x: DocumentRef = .{ .document = &docs[0], .generation = 1 };
    const y: DocumentRef = .{ .document = &docs[1], .generation = 1 };
    const z: DocumentRef = .{ .document = &docs[2], .generation = 1 };
    storage.committed(allocator, 1, x, .regular, false, 1);
    try storage.add(allocator, 1, testEntry("x"));
    storage.committed(allocator, 1, y, .regular, false, 1);
    try storage.add(allocator, 1, testEntry("y"));
    // A third page: y's is parked, x's (the oldest) leaves.
    storage.committed(allocator, 1, z, .regular, false, 1);
    storage.committed(allocator, 1, x, .regular, true, 1);
    try std.testing.expectEqual(@as(usize, 0), Seen.of(&storage, 1).count);
    storage.committed(allocator, 1, y, .regular, true, 1);
    const kept = Seen.of(&storage, 1);
    try std.testing.expectEqualStrings("y", kept.first[0..kept.first_len]);
    // A slab generation that moved on is another document.
    storage.committed(allocator, 1, .{ .document = &docs[1], .generation = 2 }, .regular, false, 1);
    storage.committed(allocator, 1, .{ .document = &docs[1], .generation = 3 }, .regular, true, 1);
    try std.testing.expectEqual(@as(usize, 0), Seen.of(&storage, 1).count);
}
