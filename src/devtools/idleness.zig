//! A frame's network idleness, as Page.lifecycleEvent reports it:
//! "networkAlmostIdle" once no more than two of its document's fetches have
//! been in flight for 500 ms, "networkIdle" once none have. Blink's
//! IdlenessDetector (third_party/blink/renderer/core/loader/
//! idleness_detector.cc; reproduced, not copied), which Puppeteer's
//! waitUntil "networkidle2" / "networkidle0" wait for:
//!
//! - It starts when the document's DOMContentLoaded has fired
//!   (IdlenessDetector::DomContentLoadedEventFired -> Start), with both
//!   quiet periods open and no quiet time yet, and counts what is in flight
//!   then (Start ends with OnDidLoadResource).
//! - A request about to be sent (OnWillSendRequest) clears the 2-quiet time
//!   when it makes more than two in flight, and the 0-quiet time when it
//!   makes any.
//! - A request that ends (OnDidLoadResource): reaching exactly two sets the
//!   2-quiet time anew; fewer than two set it only when it is not set; zero
//!   sets the 0-quiet time.
//! - On the first task after a quiet time is more than kNetworkQuietWindow
//!   (500 ms) old (WillProcessTask, kept running by a 2 s watchdog timer),
//!   the event fires with the quiet period's start as its timestamp, and that
//!   period closes for the document's life.
//!
//! Crane has no task observer: a timer for the earliest open quiet time plus
//! the window stands for WillProcessTask's check (the page's sessions arm
//! it, src/devtools/domains/page.zig). The counts are the fetch observer's
//! (fetch_observer.inFlight: Blink's ResourceFetcher::ActiveRequestCount).
//! Lane cdph.

const std = @import("std");

/// kNetworkQuietWindow.
pub const quiet_window_ns: i64 = 500 * std.time.ns_per_ms;

pub const Detector = struct {
    /// in_network_2_quiet_period_ / in_network_0_quiet_period_: the event
    /// has not fired yet.
    in_2: bool = true,
    in_0: bool = true,
    /// network_2_quiet_ / network_0_quiet_: when the current quiet stretch
    /// began, or null while there is none.
    quiet_2: ?i64 = null,
    quiet_0: ?i64 = null,
    /// What is in flight now.
    count: u32 = 0,
    /// network_2_quiet_start_time_ / network_0_quiet_start_time_: when the
    /// latest quiet stretch began - set as it begins, kept after it fires
    /// and when a request ends it, cleared only by a new document
    /// (WillCommitLoad). GetNetworkAlmostIdleTime / GetNetworkIdleTime
    /// answer them, and a replay (InspectorPageAgent::
    /// setLifecycleEventsEnabled) reports each one set - whether or not its
    /// event has fired yet.
    quiet_2_start: ?i64 = null,
    quiet_0_start: ?i64 = null,

    /// Start: the document's DOMContentLoaded fired at `now` with `count` in
    /// flight.
    pub fn start(count: u32, now: i64) Detector {
        var self: Detector = .{ .count = count };
        self.didLoad(now);
        return self;
    }

    /// The count is `count` at `now`: a request was sent (it rose) or ended
    /// (it fell).
    pub fn moved(self: *Detector, count: u32, now: i64) void {
        const before = self.count;
        self.count = count;
        if (count > before) {
            // OnWillSendRequest.
            if (self.in_2 and count > 2) self.quiet_2 = null;
            if (self.in_0 and count > 0) self.quiet_0 = null;
        } else if (count < before) {
            self.didLoad(now);
        }
    }

    /// OnDidLoadResource, with `count` in flight.
    fn didLoad(self: *Detector, now: i64) void {
        if (!self.in_2 and !self.in_0) return;
        const count = self.count;
        if (count > 2) return;
        if (count == 2 and self.in_2) {
            self.quiet_2 = now;
            self.quiet_2_start = now;
        } else if (count < 2 and self.in_2 and self.quiet_2 == null) {
            self.quiet_2 = now;
            self.quiet_2_start = now;
        }
        if (count == 0 and self.in_0) {
            self.quiet_0 = now;
            self.quiet_0_start = now;
        }
    }

    pub const Due = struct { almost_idle: ?i64 = null, idle: ?i64 = null };

    /// WillProcessTask at `now`: the events due, each with its timestamp
    /// (the quiet stretch's start: NetworkBecameAlmostIdle(
    /// network_2_quiet_start_time_)), and their periods closed.
    pub fn check(self: *Detector, now: i64) Due {
        var due: Due = .{};
        if (self.in_2) if (self.quiet_2) |since| if (now - since > quiet_window_ns) {
            due.almost_idle = self.quiet_2_start orelse since;
            self.quiet_2 = null;
            self.in_2 = false;
        };
        if (self.in_0) if (self.quiet_0) |since| if (now - since > quiet_window_ns) {
            due.idle = self.quiet_0_start orelse since;
            self.quiet_0 = null;
            self.in_0 = false;
        };
        return due;
    }

    /// When the next check can find something due, or null when none can
    /// until the count moves.
    pub fn nextCheck(self: *const Detector) ?i64 {
        var next: ?i64 = null;
        if (self.in_2) if (self.quiet_2) |since| {
            next = since + quiet_window_ns + 1;
        };
        if (self.in_0) if (self.quiet_0) |since| {
            const at = since + quiet_window_ns + 1;
            if (next == null or at < next.?) next = at;
        };
        return next;
    }
};

const ms = std.time.ns_per_ms;

test "a page at rest at DOMContentLoaded is almost idle and idle 500 ms later, stamped with the quiet start" {
    var d = Detector.start(0, 1000 * ms);
    try std.testing.expectEqual(@as(?i64, 1500 * ms + 1), d.nextCheck());
    var due = d.check(1400 * ms);
    try std.testing.expect(due.almost_idle == null and due.idle == null);
    due = d.check(1501 * ms);
    try std.testing.expectEqual(@as(?i64, 1000 * ms), due.almost_idle);
    try std.testing.expectEqual(@as(?i64, 1000 * ms), due.idle);
    // Each fires once for the document's life.
    d.moved(5, 1600 * ms);
    d.moved(0, 1700 * ms);
    try std.testing.expectEqual(@as(?i64, null), d.nextCheck());
}

test "networkAlmostIdle waits for two in flight, networkIdle for none; a new request restarts the quiet" {
    var d = Detector.start(4, 0);
    try std.testing.expectEqual(@as(?i64, null), d.nextCheck());
    d.moved(3, 100 * ms);
    d.moved(2, 200 * ms); // exactly two: the 2-quiet starts
    try std.testing.expectEqual(@as(?i64, 700 * ms + 1), d.nextCheck());
    d.moved(1, 300 * ms); // fewer than two keeps the stamp it has
    d.moved(3, 400 * ms); // a request makes three: the 2-quiet clears
    try std.testing.expectEqual(@as(?i64, null), d.nextCheck());
    d.moved(2, 500 * ms);
    d.moved(0, 600 * ms);
    var due = d.check(1001 * ms);
    try std.testing.expectEqual(@as(?i64, 500 * ms), due.almost_idle);
    try std.testing.expect(due.idle == null);
    due = d.check(1101 * ms);
    try std.testing.expectEqual(@as(?i64, 600 * ms), due.idle);
    try std.testing.expectEqual(@as(?i64, 500 * ms), d.quiet_2_start);
}

test "the quiet start is known as the quiet begins, before its event fires: what a replay reports (GetNetworkIdleTime)" {
    var d = Detector.start(0, 1000 * ms);
    // At once, 500 ms before either event is due.
    try std.testing.expectEqual(@as(?i64, 1000 * ms), d.quiet_2_start);
    try std.testing.expectEqual(@as(?i64, 1000 * ms), d.quiet_0_start);
    // A request ending the quiet keeps the start it had; a new quiet moves it.
    d.moved(1, 1100 * ms);
    try std.testing.expectEqual(@as(?i64, 1000 * ms), d.quiet_0_start);
    d.moved(0, 1200 * ms);
    try std.testing.expectEqual(@as(?i64, 1200 * ms), d.quiet_0_start);
}

test "a request sent while two are in flight does not move the 2-quiet start; one that makes any clears the 0-quiet" {
    var d = Detector.start(0, 0);
    d.moved(1, 100 * ms);
    d.moved(2, 150 * ms);
    try std.testing.expectEqual(@as(?i64, 0), d.quiet_2);
    try std.testing.expectEqual(@as(?i64, null), d.quiet_0);
}
