//! Service Worker Timing Info
//!
//! Timing information for service worker operations, exposed via
//! Navigation Timing API and Resource Timing API.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#service-worker-timing-info

const std = @import("std");
const types = @import("types.zig");

/// Service worker timing info.
///
/// Marks certain points in time that are later exposed by the navigation
/// timing API and resource timing API.
///
/// Spec: https://w3c.github.io/ServiceWorker/#service-worker-timing-info
pub const TimingInfo = struct {
    /// When the service worker started for this fetch.
    /// Corresponds to PerformanceResourceTiming.workerStart.
    start_time: f64 = 0,

    /// When the fetch event was dispatched to the service worker.
    fetch_event_dispatch_time: f64 = 0,

    /// When router rule evaluation started.
    worker_router_evaluation_start: f64 = 0,

    /// When cache lookup started (if routed to cache).
    worker_cache_lookup_start: f64 = 0,

    /// The matched router source (e.g., "cache", "network", "fetch-event").
    /// Empty string if no router rules matched.
    worker_matched_router_source: []const u8 = "",

    /// The final router source used after evaluation.
    /// This may differ from matched source if fallback occurred.
    worker_final_router_source: []const u8 = "",

    const Self = @This();

    /// Create a new timing info with current time as start.
    pub fn now() Self {
        return .{
            .start_time = getCurrentTime(),
        };
    }

    /// Mark fetch event dispatch time.
    pub fn markFetchEventDispatch(self: *Self) void {
        self.fetch_event_dispatch_time = getCurrentTime();
    }

    /// Mark router evaluation start time.
    pub fn markRouterEvaluationStart(self: *Self) void {
        self.worker_router_evaluation_start = getCurrentTime();
    }

    /// Mark cache lookup start time.
    pub fn markCacheLookupStart(self: *Self) void {
        self.worker_cache_lookup_start = getCurrentTime();
    }

    /// Set matched router source.
    pub fn setMatchedRouterSource(self: *Self, source: []const u8) void {
        self.worker_matched_router_source = source;
    }

    /// Set final router source.
    pub fn setFinalRouterSource(self: *Self, source: []const u8) void {
        self.worker_final_router_source = source;
    }

    /// Get time elapsed since start (for debugging).
    pub fn elapsedSinceStart(self: *const Self) f64 {
        return getCurrentTime() - self.start_time;
    }

    /// Check if fetch event was dispatched.
    pub fn wasFetchEventDispatched(self: *const Self) bool {
        return self.fetch_event_dispatch_time > 0;
    }

    /// Check if router was evaluated.
    pub fn wasRouterEvaluated(self: *const Self) bool {
        return self.worker_router_evaluation_start > 0;
    }
};

/// Get current high-resolution time in milliseconds.
///
/// Returns time relative to an arbitrary epoch.
/// In real implementation, this would use performance.now() semantics.
fn getCurrentTime() f64 {
    const ns = std.time.nanoTimestamp();
    return @as(f64, @floatFromInt(ns)) / 1_000_000.0;
}

// =============================================================================
// Tests
// =============================================================================

test "TimingInfo defaults" {
    const timing = TimingInfo{};
    try std.testing.expectEqual(@as(f64, 0), timing.start_time);
    try std.testing.expectEqual(@as(f64, 0), timing.fetch_event_dispatch_time);
    try std.testing.expect(!timing.wasFetchEventDispatched());
    try std.testing.expect(!timing.wasRouterEvaluated());
}

test "TimingInfo.now sets start time" {
    const timing = TimingInfo.now();
    try std.testing.expect(timing.start_time > 0);
}

test "TimingInfo.markFetchEventDispatch" {
    var timing = TimingInfo.now();
    try std.testing.expect(!timing.wasFetchEventDispatched());

    timing.markFetchEventDispatch();
    try std.testing.expect(timing.wasFetchEventDispatched());
    try std.testing.expect(timing.fetch_event_dispatch_time >= timing.start_time);
}

test "TimingInfo.markRouterEvaluationStart" {
    var timing = TimingInfo.now();
    try std.testing.expect(!timing.wasRouterEvaluated());

    timing.markRouterEvaluationStart();
    try std.testing.expect(timing.wasRouterEvaluated());
}

test "TimingInfo.setRouterSources" {
    var timing = TimingInfo{};

    timing.setMatchedRouterSource("cache");
    try std.testing.expectEqualStrings("cache", timing.worker_matched_router_source);

    timing.setFinalRouterSource("network");
    try std.testing.expectEqualStrings("network", timing.worker_final_router_source);
}

test "TimingInfo.elapsedSinceStart" {
    const timing = TimingInfo.now();
    // Small delay
    std.time.sleep(1_000_000); // 1ms

    const elapsed = timing.elapsedSinceStart();
    try std.testing.expect(elapsed >= 0.5); // At least 0.5ms
}
