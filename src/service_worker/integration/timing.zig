//! Service Worker Timing Integration
//!
//! Timing fields for Resource Timing API integration with Service Workers.
//!
//! Spec: https://w3c.github.io/ServiceWorker/#service-worker-timing-info

const std = @import("std");

/// Service worker timing information.
///
/// These fields are added to resource timing entries when a service worker
/// is involved in handling a fetch.
///
/// Spec: https://w3c.github.io/ServiceWorker/#service-worker-timing-info
pub const ServiceWorkerTiming = struct {
    /// When the service worker started processing the request.
    /// This is relative to the fetch start time.
    worker_start: f64 = 0,

    /// When router rule evaluation started.
    /// 0 if no router rules were evaluated.
    worker_router_evaluation_start: f64 = 0,

    /// When cache lookup started (if routed to cache).
    /// 0 if not routed to cache.
    worker_cache_lookup_start: f64 = 0,

    /// The matched router source (e.g., "cache", "network", "fetch-event").
    /// Empty string if no router match.
    worker_matched_router_source: []const u8 = "",

    /// The final router source used (may differ from matched if fallback occurred).
    worker_final_router_source: []const u8 = "",

    /// When response headers were received from the service worker.
    final_response_headers_received: f64 = 0,

    /// Mark worker start time.
    pub fn markWorkerStart(self: *ServiceWorkerTiming) void {
        self.worker_start = getCurrentTimeMs();
    }

    /// Mark router evaluation start.
    pub fn markRouterEvaluationStart(self: *ServiceWorkerTiming) void {
        self.worker_router_evaluation_start = getCurrentTimeMs();
    }

    /// Mark cache lookup start.
    pub fn markCacheLookupStart(self: *ServiceWorkerTiming) void {
        self.worker_cache_lookup_start = getCurrentTimeMs();
    }

    /// Mark final response headers received.
    pub fn markFinalResponseHeadersReceived(self: *ServiceWorkerTiming) void {
        self.final_response_headers_received = getCurrentTimeMs();
    }

    /// Set matched router source.
    pub fn setMatchedRouterSource(self: *ServiceWorkerTiming, source: []const u8) void {
        self.worker_matched_router_source = source;
    }

    /// Set final router source.
    pub fn setFinalRouterSource(self: *ServiceWorkerTiming, source: []const u8) void {
        self.worker_final_router_source = source;
    }

    /// Check if service worker was involved.
    pub fn wasServiceWorkerInvolved(self: *const ServiceWorkerTiming) bool {
        return self.worker_start > 0;
    }
};

/// Get current time in milliseconds (DOMHighResTimeStamp format).
fn getCurrentTimeMs() f64 {
    return @as(f64, @floatFromInt(std.time.timestamp())) * 1000.0;
}

// =============================================================================
// Tests
// =============================================================================

test "ServiceWorkerTiming defaults" {
    const timing = ServiceWorkerTiming{};
    try std.testing.expectEqual(@as(f64, 0), timing.worker_start);
    try std.testing.expect(!timing.wasServiceWorkerInvolved());
}

test "ServiceWorkerTiming.markWorkerStart" {
    var timing = ServiceWorkerTiming{};
    timing.markWorkerStart();
    try std.testing.expect(timing.worker_start > 0);
    try std.testing.expect(timing.wasServiceWorkerInvolved());
}

test "ServiceWorkerTiming.setRouterSource" {
    var timing = ServiceWorkerTiming{};
    timing.setMatchedRouterSource("cache");
    timing.setFinalRouterSource("network");

    try std.testing.expectEqualStrings("cache", timing.worker_matched_router_source);
    try std.testing.expectEqualStrings("network", timing.worker_final_router_source);
}
