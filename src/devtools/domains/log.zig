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
const perf = @import("dom").performance_monitor;

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
    if (session.side) |side| side.log_storage.forgetTab(side.allocator, session.tab);
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

/// Each tab's Log entries, kept for a Log.enable that comes later - Blink's
/// ConsoleMessageStorage, one per Page (third_party/blink/renderer/core/
/// inspector/console_message_storage.cc, BSD): AddConsoleMessage keeps at
/// most kMaxConsoleMessageCount (1000), dropping the oldest and counting it
/// (expired_count_); Clear empties both. Page::DidCommitLoad clears it when
/// the main frame commits a new document (third_party/blink/renderer/core/
/// page/page.cc - read, not copied: LGPL), InspectorLogAgent::clear when
/// asked. Kept by the BrowserSide (`log_storage`), on the Browser's thread;
/// the tabs are few, so a list, searched (no hash map to tombstone).
pub const Storage = struct {
    tabs: std.ArrayList(TabEntries) = .empty,

    /// Blink's kMaxConsoleMessageCount.
    pub const max_entries = 1000;

    const TabEntries = struct {
        tab: u64,
        /// The entries, their strings OWNED: in order while fewer than
        /// `max_entries`; once full, a ring whose oldest is at `head`.
        ring: std.ArrayList(L.LogEntry) = .empty,
        head: usize = 0,
        /// How many the bound dropped since the last clear.
        expired: u64 = 0,

        fn deinit(self: *TabEntries, allocator: Allocator) void {
            for (self.ring.items) |*entry| freeEntry(allocator, entry);
            self.ring.deinit(allocator);
        }
    };

    pub fn deinit(self: *Storage, allocator: Allocator) void {
        for (self.tabs.items) |*kept| kept.deinit(allocator);
        self.tabs.deinit(allocator);
        self.* = .{};
    }

    fn find(self: *Storage, tab: u64) ?*TabEntries {
        for (self.tabs.items) |*kept| if (kept.tab == tab) return kept;
        return null;
    }

    /// Keep a copy of `entry` for `tab`; when the tab has `max_entries`
    /// already, its oldest goes and is counted.
    pub fn add(self: *Storage, allocator: Allocator, tab: u64, entry: L.LogEntry) Allocator.Error!void {
        var copy = try copyEntry(allocator, entry);
        errdefer freeEntry(allocator, &copy);
        const kept = self.find(tab) orelse blk: {
            try self.tabs.append(allocator, .{ .tab = tab });
            break :blk &self.tabs.items[self.tabs.items.len - 1];
        };
        if (kept.ring.items.len < max_entries) {
            try kept.ring.append(allocator, copy);
            return;
        }
        freeEntry(allocator, &kept.ring.items[kept.head]);
        kept.ring.items[kept.head] = copy;
        kept.head = (kept.head + 1) % max_entries;
        kept.expired += 1;
    }

    /// `tab`'s entries and count go: the main frame committed a new
    /// document, Log.clear, or the tab is gone.
    pub fn forgetTab(self: *Storage, allocator: Allocator, tab: u64) void {
        for (self.tabs.items, 0..) |*kept, i| {
            if (kept.tab != tab) continue;
            kept.deinit(allocator);
            _ = self.tabs.swapRemove(i);
            return;
        }
    }

    /// `tab`'s kept entries, oldest first, each to `visit`, after the
    /// count of those dropped.
    pub fn each(self: *Storage, tab: u64, context: anytype, comptime visit: fn (@TypeOf(context), expired: u64, entry: ?*const L.LogEntry) void) void {
        const kept = self.find(tab) orelse return;
        if (kept.expired > 0) visit(context, kept.expired, null);
        const n = kept.ring.items.len;
        for (0..n) |i| visit(context, 0, &kept.ring.items[(kept.head + i) % n]);
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
/// listens (BrowserSide.fanOutNavigation): a top-level traversable's
/// commit - its navigable id is its tab's - clears the tab's kept entries,
/// as Page::DidCommitLoad does for the main frame. A child's commit keeps
/// them. A main document's own error response (errorResponse, at its
/// response) is cleared with the rest, as in Chrome, where DocumentLoader::
/// CommitNavigation reports it (RecordConsoleMessagesForCommit) before
/// DidCommitNavigation reaches Page::DidCommitLoad: a session listening
/// then hears it, a later Log.enable does not. (Chrome clears for a regular
/// commit only - DocumentLoader::
/// DidCommitNavigation returns first for a javascript: URL's or XSLT's
/// document, and a back/forward cache restore commits no new document but
/// shows that Page's own storage; the milestone tells none of these apart,
/// so every commit clears: the entries are a document's no longer shown.)
pub fn onMilestone(side: *BrowserSide, milestone: *const host_bridge.Milestone) void {
    switch (milestone.event) {
        .committed => side.log_storage.forgetTab(side.allocator, milestone.navigable_id),
        else => {},
    }
}

/// The tab is gone: its kept entries go with it.
pub fn tabGone(side: *BrowserSide, tab: u64) void {
    side.log_storage.forgetTab(side.allocator, tab);
}

fn testEntry(text: []const u8) L.LogEntry {
    return .{ .source = .network, .level = .@"error", .text = text, .timestamp = 1, .url = "https://a.test/x", .networkRequestId = "7" };
}

test "a tab keeps at most 1000 entries, the oldest dropped and counted; forgetting a tab empties it" {
    const allocator = std.testing.allocator;
    var storage: Storage = .{};
    defer storage.deinit(allocator);
    var buffer: [16]u8 = undefined;
    for (0..Storage.max_entries + 2) |i| {
        try storage.add(allocator, 1, testEntry(try std.fmt.bufPrint(&buffer, "e{d}", .{i})));
    }
    try storage.add(allocator, 2, testEntry("other tab"));

    const Seen = struct {
        expired: u64 = 0,
        first: [16]u8 = undefined,
        first_len: usize = 0,
        last: [16]u8 = undefined,
        last_len: usize = 0,
        count: usize = 0,
        fn visit(self: *@This(), expired: u64, entry: ?*const L.LogEntry) void {
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
    };
    var seen: Seen = .{};
    storage.each(1, &seen, Seen.visit);
    try std.testing.expectEqual(@as(u64, 2), seen.expired);
    try std.testing.expectEqual(@as(usize, Storage.max_entries), seen.count);
    try std.testing.expectEqualStrings("e2", seen.first[0..seen.first_len]);
    try std.testing.expectEqualStrings("e1001", seen.last[0..seen.last_len]);

    storage.forgetTab(allocator, 1);
    var none: Seen = .{};
    storage.each(1, &none, Seen.visit);
    try std.testing.expectEqual(@as(usize, 0), none.count);
    try std.testing.expectEqual(@as(u64, 0), none.expired);
    var other: Seen = .{};
    storage.each(2, &other, Seen.visit);
    try std.testing.expectEqual(@as(usize, 1), other.count);
}
