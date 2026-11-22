//! A Browser's performance violations, as a host subscribes to them (CDP's
//! Log.startViolationsReport): Blink's PerformanceMonitor
//! (third_party/blink/renderer/core/frame/performance_monitor.cc;
//! reproduced, not copied). Each subscriber names a violation and a
//! threshold; the monitor keeps, per violation, the smallest threshold, and a
//! report reaches each subscriber of its violation whose threshold is
//! STRICTLY below the report's time (InnerReportGenericViolation's
//! `it.value < time`), so a report with no time (document.write, a
//! non-passive listener) reaches only a negative threshold - DevTools asks
//! -1 for those.
//!
//! The violations Crane reports, where Blink does:
//! - handler / recurringHandler: an outermost user callback - an event
//!   listener (named by the event type), setTimeout/setInterval,
//!   requestAnimationFrame, requestIdleCallback (recurring) - that ran at
//!   least the threshold: "'<name>' handler took <ms>ms".
//! - blockedEvent: a non-passive listener of a cancelable touchstart,
//!   touchmove, wheel or mousewheel event dispatched more than the threshold
//!   after the event was made.
//! - blockedParser: document.write() inserting a parser-blocking external
//!   script (PerformanceMonitor::DocumentWriteFetchScript).
//! - discouragedAPIUse: document.write(), and a non-passive listener added
//!   for a scroll-blocking event without saying `passive`.
//! - longTask: subscribed, never reported - Blink's InspectorLogAgent
//!   implements no ReportLongTask (inspector_log_agent.cc), so Chrome's Log
//!   domain is silent for it.
//! - longLayout: never - there is no layout without a renderer
//!   (needs-renderer).
//!
//! Window realms only: a worker's PerformanceMonitor::Monitor is null in
//! Blink. The hot paths (listener invoke, timer fire) test one atomic
//! pointer on the Browser's scope (`active`) - null while nothing is
//! subscribed - before reading any clock, as PerformanceMonitor::enabled_.
//! On the Browser's window thread. Lane cdph.

const std = @import("std");
const runtime = @import("runtime");

pub const Violation = enum(u8) {
    long_task,
    long_layout,
    blocked_event,
    blocked_parser,
    discouraged_api_use,
    handler,
    recurring_handler,

    /// CDP's Log.ViolationSetting name.
    pub fn ofName(name: []const u8) ?Violation {
        const names = .{
            .{ "longTask", .long_task },
            .{ "longLayout", .long_layout },
            .{ "blockedEvent", .blocked_event },
            .{ "blockedParser", .blocked_parser },
            .{ "discouragedAPIUse", .discouraged_api_use },
            .{ "handler", .handler },
            .{ "recurringHandler", .recurring_handler },
        };
        inline for (names) |pair| if (std.mem.eql(u8, name, pair[0])) return pair[1];
        return null;
    }
};

const violation_count = @typeInfo(Violation).@"enum".fields.len;

/// Who hears a violation: a host (a CDP session's Log domain), for the
/// documents of one tab.
pub const Client = struct {
    context: *anyopaque,
    tab: u64,
    report: *const fn (context: *anyopaque, violation: Violation, text: []const u8, url: []const u8) void,
};

const Subscription = struct {
    client: Client,
    violation: Violation,
    threshold_ns: i64,
};

/// The Browser's monitor (a BrowserScope supplement: `init`, `deinit`).
pub const Monitor = struct {
    allocator: std.mem.Allocator,
    scope: ?*runtime.BrowserScope = null,
    subscriptions: std.ArrayListUnmanaged(Subscription) = .empty,
    /// thresholds_: per violation, the smallest subscribed threshold; null
    /// for none.
    thresholds: [violation_count]?i64 = @splat(null),
    /// user_callback_depth_, and the outermost callback's start when it is
    /// timed.
    callback_depth: u32 = 0,
    /// The listeners a blockedEvent was told for (by listener id), once each.
    blocked_warned: std.ArrayListUnmanaged(u64) = .empty,

    pub fn init(allocator: std.mem.Allocator) Monitor {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *Monitor) void {
        self.publish(false);
        self.subscriptions.deinit(self.allocator);
        self.blocked_warned.deinit(self.allocator);
    }

    /// The monitor of `scope`, made on first use.
    pub fn of(scope: *runtime.BrowserScope) !*Monitor {
        const monitor = try scope.of(Monitor);
        monitor.scope = scope;
        return monitor;
    }

    /// Subscribe `client` to `violation` at `threshold_ns`.
    pub fn subscribe(self: *Monitor, client: Client, violation: Violation, threshold_ns: i64) !void {
        try self.subscriptions.append(self.allocator, .{ .client = client, .violation = violation, .threshold_ns = threshold_ns });
        self.recompute();
    }

    /// Every subscription of the client whose context is `context` goes
    /// (UnsubscribeAll).
    pub fn unsubscribeAll(self: *Monitor, context: *anyopaque) void {
        var i: usize = 0;
        while (i < self.subscriptions.items.len) {
            if (self.subscriptions.items[i].client.context == context) {
                _ = self.subscriptions.orderedRemove(i);
            } else i += 1;
        }
        self.recompute();
    }

    fn recompute(self: *Monitor) void {
        self.thresholds = @splat(null);
        for (self.subscriptions.items) |s| {
            const slot = &self.thresholds[@backingInt(s.violation)];
            if (slot.* == null or s.threshold_ns < slot.*.?) slot.* = s.threshold_ns;
        }
        self.publish(self.subscriptions.items.len > 0);
    }

    /// The scope's pointer to this monitor, while anything is subscribed.
    fn publish(self: *Monitor, on: bool) void {
        const scope = self.scope orelse return;
        scope.performance_monitor.store(if (on) @ptrCast(self) else null, .release);
    }

    pub fn threshold(self: *const Monitor, violation: Violation) ?i64 {
        return self.thresholds[@backingInt(violation)];
    }

    /// InnerReportGenericViolation: `text` to each subscriber of
    /// `violation` on `realm`'s tab whose threshold is below `time_ns`.
    pub fn report(self: *Monitor, realm: runtime.Context, violation: Violation, text: []const u8, time_ns: i64) void {
        const tab = tabOf(realm) orelse return;
        const url = realm.documentUrl() orelse "";
        // A client may unsubscribe while it is told: walk a copy.
        var copy: [16]Subscription = undefined;
        var n: usize = 0;
        for (self.subscriptions.items) |s| {
            if (s.violation != violation or s.client.tab != tab or !(s.threshold_ns < time_ns) or n == copy.len) continue;
            copy[n] = s;
            n += 1;
        }
        for (copy[0..n]) |s| s.client.report(s.client.context, violation, text, url);
    }

    /// Will(UserCallback): the start of an outermost callback to time, or
    /// null (nested, or nothing subscribed to its kind).
    pub fn willCallback(self: *Monitor, recurring: bool) ?i64 {
        self.callback_depth += 1;
        if (self.callback_depth != 1) return null;
        if (self.threshold(if (recurring) .recurring_handler else .handler) == null) return null;
        return monotonicNs();
    }

    /// Did(UserCallback): the call's time when it took at least the
    /// threshold (PerformanceMonitor::Did(CallFunction)), for `reportHandler`.
    pub fn didCallback(self: *Monitor, recurring: bool, started: ?i64) ?i64 {
        self.callback_depth -|= 1;
        const start = started orelse return null;
        const limit = self.threshold(if (recurring) .recurring_handler else .handler) orelse return null;
        const duration = monotonicNs() - start;
        return if (duration < limit) null else duration;
    }

    /// "'<name>' handler took <ms>ms".
    pub fn reportHandler(self: *Monitor, realm: runtime.Context, name: []const u8, recurring: bool, duration: i64) void {
        var buffer: [160]u8 = undefined;
        const text = std.fmt.bufPrint(&buffer, "'{s}' handler took {d}ms", .{ name, @divTrunc(duration, std.time.ns_per_ms) }) catch return;
        self.report(realm, if (recurring) .recurring_handler else .handler, text, duration);
    }

    /// blockedEvent: the listener ran for a cancelable scroll-blocking
    /// event made `delay_ns` before it was dispatched; told once per
    /// listener (`id`), as SetBlockedEventWarningEmitted.
    pub fn reportBlockedEvent(self: *Monitor, realm: runtime.Context, event_type: []const u8, listener_id: u64, delay_ns: i64) void {
        for (self.blocked_warned.items) |id| if (id == listener_id) return;
        self.blocked_warned.append(self.allocator, listener_id) catch return;
        var buffer: [256]u8 = undefined;
        const text = std.fmt.bufPrint(&buffer, "Handling of '{s}' input event was delayed for {d} ms due to main thread being busy. Consider marking event handler as 'passive' to make the page more responsive.", .{ event_type, @divTrunc(delay_ns, std.time.ns_per_ms) }) catch return;
        self.report(realm, .blocked_event, text, delay_ns);
    }
};

/// The four scroll-blocking event types (Blink's IsScrollBlockingEvent).
pub fn isScrollBlocking(event_type: []const u8) bool {
    return std.mem.eql(u8, event_type, "touchstart") or std.mem.eql(u8, event_type, "touchmove") or
        std.mem.eql(u8, event_type, "wheel") or std.mem.eql(u8, event_type, "mousewheel");
}

/// The Browser's monitor while anything is subscribed, for a Window realm:
/// the hot paths' one test (one atomic load and a branch).
pub inline fn active(realm: runtime.Context) ?*Monitor {
    const scope = realm.browser_scope orelse return null;
    const pointer = scope.performance_monitor.load(.acquire) orelse return null;
    if (!realm.isWindow()) return null;
    return @ptrCast(@alignCast(pointer));
}

/// A report with no time (ReportGenericViolation's static form), when the
/// realm's Browser has a monitor.
pub fn reportUntimed(realm: runtime.Context, violation: Violation, text: []const u8) void {
    const monitor = active(realm) orelse return;
    monitor.report(realm, violation, text, 0);
}

pub fn monotonicNs() i64 {
    return @intCast(@import("platform").monotonicNow().ns);
}

/// The id of `realm`'s Window's top-level traversable (its tab).
fn tabOf(realm: runtime.Context) ?u64 {
    const record = realm.getRealm() orelse return null;
    const window: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return null));
    const bc = @import("browser_state.zig").browsingContextOf(window) orelse return null;
    return bc.getTop().id;
}

test "a report reaches only subscribers whose threshold is strictly below its time" {
    try std.testing.expectEqual(Violation.discouraged_api_use, Violation.ofName("discouragedAPIUse").?);
    try std.testing.expect(Violation.ofName("nope") == null);
    var monitor = Monitor.init(std.testing.allocator);
    defer monitor.deinit();
    var dummy: u8 = 0;
    const client: Client = .{ .context = &dummy, .tab = 1, .report = undefined };
    try monitor.subscribe(client, .handler, 150 * std.time.ns_per_ms);
    try monitor.subscribe(client, .handler, 50 * std.time.ns_per_ms);
    try monitor.subscribe(client, .discouraged_api_use, -1 * std.time.ns_per_ms);
    try std.testing.expectEqual(@as(?i64, 50 * std.time.ns_per_ms), monitor.threshold(.handler));
    try std.testing.expect(monitor.threshold(.long_task) == null);
    monitor.unsubscribeAll(&dummy);
    try std.testing.expect(monitor.threshold(.handler) == null);
}
