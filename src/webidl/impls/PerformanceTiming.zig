//! Implementation for PerformanceTiming interface
//!
//! Spec: https://w3c.github.io/navigation-timing/#the-performancetiming-interface
//!
//! Navigation Timing 1's `performance.timing`, obsolete: each attribute is
//! milliseconds since the Unix epoch - the time origin's timestamp plus the
//! document's navigation timing entry's (or load timing info's) relative
//! time, floored, and 0 where that time is 0 (not happened, or not exposed).

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const performance_timeline = @import("dom").performance_timeline;
const PerformanceTiming = interfaces.PerformanceTiming;

pub const State = PerformanceTiming.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return runtime.Instance.init(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    _ = instance; // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// The time origin's timestamp (ms since the Unix epoch) of this's global.
fn origin(instance: *runtime.Instance) f64 {
    return performance_timeline.timeOriginTimestamp(instance.ctx) orelse 0;
}

/// A relative time as PerformanceTiming reports it: 0 stays 0, anything
/// else is its epoch time in whole milliseconds.
fn epoch(instance: *runtime.Instance, relative: f64) u64 {
    if (relative == 0) return 0;
    const absolute = @floor(origin(instance) + relative);
    if (absolute <= 0) return 0;
    return @intFromFloat(absolute);
}

/// One of the navigation timing entry's resource timing attributes (0 for
/// a document no navigation made), where 0 means "did not happen" - a
/// redirect's times.
fn fromEntry(instance: *runtime.Instance, comptime getter: fn (*runtime.Instance) anyerror!f64) !u64 {
    const entry = performance_timeline.navigationEntryOf(instance.ctx) orelse return 0;
    return epoch(instance, try getter(entry));
}

/// One of the navigation's fetch times that always happened (fetchStart,
/// the connection's, requestStart, responseStart, responseEnd): a relative
/// time of 0 is the time origin itself - the navigation started its fetch
/// at once - not "unset", so it is the origin's epoch time.
fn alwaysFromEntry(instance: *runtime.Instance, comptime getter: fn (*runtime.Instance) anyerror!f64) !u64 {
    const entry = performance_timeline.navigationEntryOf(instance.ctx) orelse return 0;
    const absolute = @floor(origin(instance) + try getter(entry));
    if (absolute <= 0) return 0;
    return @intFromFloat(absolute);
}

/// One of the document's load timing info's times.
fn fromLoadTiming(instance: *runtime.Instance, comptime field: []const u8) u64 {
    const info = performance_timeline.loadTimingOf(instance.ctx) orelse return 0;
    return epoch(instance, @field(info.*, field));
}

/// Getter for navigationStart: the time origin (the navigation's start; the
/// time the current document was made where there was none).
pub fn get_navigationStart(instance: *runtime.Instance) anyerror!u64 {
    const timestamp = @floor(origin(instance));
    if (timestamp <= 0) return 0;
    return @intFromFloat(timestamp);
}

/// Getter for redirectStart: with same-origin redirects, "the starting time
/// of the fetch that initiates the redirect", else 0 (Navigation Timing,
/// PerformanceTiming redirectStart).
pub fn get_redirectStart(instance: *runtime.Instance) anyerror!u64 {
    return redirectTime(instance, interfaces.PerformanceResourceTiming.get_redirectStart);
}

/// Getter for redirectEnd: with same-origin redirects, the time the last
/// one's response arrived, else 0.
pub fn get_redirectEnd(instance: *runtime.Instance) anyerror!u64 {
    return redirectTime(instance, interfaces.PerformanceResourceTiming.get_redirectEnd);
}

/// A redirect time of the navigation entry. Its redirectCount says whether
/// there were redirects (it counts only same-origin chains, Navigation Timing
/// 3.2, as the entry's redirect times do): then a relative 0 is the moment
/// the first fetch began, at the time origin - a time, not "none" - and the
/// legacy attribute is its epoch time, as Blink's PerformanceTiming
/// redirectStart reads its redirect_start whenever it is set. Before, a
/// redirect that began in the time origin's coarsening tick read 0, and
/// navigation-timing/test-timing-server-redirect.html's "redirectStart > 0"
/// failed whenever the navigation's start and its fetch's shared a tick
/// (lane flaky6).
fn redirectTime(instance: *runtime.Instance, comptime getter: fn (*runtime.Instance) anyerror!f64) !u64 {
    const entry = performance_timeline.navigationEntryOf(instance.ctx) orelse return 0;
    if (try interfaces.PerformanceNavigationTiming.get_redirectCount(entry) == 0) return 0;
    return alwaysFromEntry(instance, getter);
}

/// Getter for fetchStart
pub fn get_fetchStart(instance: *runtime.Instance) anyerror!u64 {
    return alwaysFromEntry(instance, interfaces.PerformanceResourceTiming.get_fetchStart);
}

/// Getter for domainLookupStart
pub fn get_domainLookupStart(instance: *runtime.Instance) anyerror!u64 {
    return alwaysFromEntry(instance, interfaces.PerformanceResourceTiming.get_domainLookupStart);
}

/// Getter for domainLookupEnd
pub fn get_domainLookupEnd(instance: *runtime.Instance) anyerror!u64 {
    return alwaysFromEntry(instance, interfaces.PerformanceResourceTiming.get_domainLookupEnd);
}

/// Getter for connectStart
pub fn get_connectStart(instance: *runtime.Instance) anyerror!u64 {
    return alwaysFromEntry(instance, interfaces.PerformanceResourceTiming.get_connectStart);
}

/// Getter for connectEnd
pub fn get_connectEnd(instance: *runtime.Instance) anyerror!u64 {
    return alwaysFromEntry(instance, interfaces.PerformanceResourceTiming.get_connectEnd);
}

/// Getter for secureConnectionStart. Navigation Timing 1: "if the scheme of
/// the current page is "https", this attribute must return the time
/// immediately before the user agent starts the handshake process to secure
/// the current connection. If ... HTTPS is not used, this attribute must
/// return zero." So on an https page the entry's time always happened, and
/// a relative 0 is the time origin itself - the handshake began within the
/// fetch start's coarsening tick, as connectStart's 0 does - while any other
/// page reads 0. Gecko keys it on the page's scheme the same way
/// (PerformanceTimingData::SecureConnectionStartHighRes returns 0 only
/// without mSecureConnection, its channel URI being https); Blink returns a
/// time whenever the load had an SSL start (PerformanceTiming::
/// secureConnectionStart). Reading the 0 as "did not happen" made it 0 on an
/// https page in 34 of 50 runs of navigation-timing/
/// test-performance-attributes.sub.html (lane flaky4).
pub fn get_secureConnectionStart(instance: *runtime.Instance) anyerror!u64 {
    const entry = performance_timeline.navigationEntryOf(instance.ctx) orelse return 0;
    const data = performance_timeline.dataOf(entry) orelse return 0;
    if (!std.ascii.startsWithIgnoreCase(data.name, "https:")) return 0;
    return alwaysFromEntry(instance, interfaces.PerformanceResourceTiming.get_secureConnectionStart);
}

/// Getter for requestStart
pub fn get_requestStart(instance: *runtime.Instance) anyerror!u64 {
    return alwaysFromEntry(instance, interfaces.PerformanceResourceTiming.get_requestStart);
}

/// Getter for responseStart
pub fn get_responseStart(instance: *runtime.Instance) anyerror!u64 {
    return alwaysFromEntry(instance, interfaces.PerformanceResourceTiming.get_responseStart);
}

/// Getter for responseEnd
pub fn get_responseEnd(instance: *runtime.Instance) anyerror!u64 {
    return alwaysFromEntry(instance, interfaces.PerformanceResourceTiming.get_responseEnd);
}

/// Getter for unloadEventStart
pub fn get_unloadEventStart(instance: *runtime.Instance) anyerror!u64 {
    return fromLoadTiming(instance, "unload_event_start");
}

/// Getter for unloadEventEnd
pub fn get_unloadEventEnd(instance: *runtime.Instance) anyerror!u64 {
    return fromLoadTiming(instance, "unload_event_end");
}

/// Getter for domLoading
pub fn get_domLoading(instance: *runtime.Instance) anyerror!u64 {
    return fromLoadTiming(instance, "dom_loading");
}

/// Getter for domInteractive
pub fn get_domInteractive(instance: *runtime.Instance) anyerror!u64 {
    return fromLoadTiming(instance, "dom_interactive");
}

/// Getter for domContentLoadedEventStart
pub fn get_domContentLoadedEventStart(instance: *runtime.Instance) anyerror!u64 {
    return fromLoadTiming(instance, "dom_content_loaded_event_start");
}

/// Getter for domContentLoadedEventEnd
pub fn get_domContentLoadedEventEnd(instance: *runtime.Instance) anyerror!u64 {
    return fromLoadTiming(instance, "dom_content_loaded_event_end");
}

/// Getter for domComplete
pub fn get_domComplete(instance: *runtime.Instance) anyerror!u64 {
    return fromLoadTiming(instance, "dom_complete");
}

/// Getter for loadEventStart
pub fn get_loadEventStart(instance: *runtime.Instance) anyerror!u64 {
    return fromLoadTiming(instance, "load_event_start");
}

/// Getter for loadEventEnd
pub fn get_loadEventEnd(instance: *runtime.Instance) anyerror!u64 {
    return fromLoadTiming(instance, "load_event_end");
}

/// Operation: toJSON (WebIDL default toJSON steps)
pub fn call_toJSON(instance: *runtime.Instance) anyerror!interfaces.PerformanceTiming.PerformanceTimingToJSON {
    return .{
        .navigationStart = try get_navigationStart(instance),
        .unloadEventStart = try get_unloadEventStart(instance),
        .unloadEventEnd = try get_unloadEventEnd(instance),
        .redirectStart = try get_redirectStart(instance),
        .redirectEnd = try get_redirectEnd(instance),
        .fetchStart = try get_fetchStart(instance),
        .domainLookupStart = try get_domainLookupStart(instance),
        .domainLookupEnd = try get_domainLookupEnd(instance),
        .connectStart = try get_connectStart(instance),
        .connectEnd = try get_connectEnd(instance),
        .secureConnectionStart = try get_secureConnectionStart(instance),
        .requestStart = try get_requestStart(instance),
        .responseStart = try get_responseStart(instance),
        .responseEnd = try get_responseEnd(instance),
        .domLoading = try get_domLoading(instance),
        .domInteractive = try get_domInteractive(instance),
        .domContentLoadedEventStart = try get_domContentLoadedEventStart(instance),
        .domContentLoadedEventEnd = try get_domContentLoadedEventEnd(instance),
        .domComplete = try get_domComplete(instance),
        .loadEventStart = try get_loadEventStart(instance),
        .loadEventEnd = try get_loadEventEnd(instance),
    };
}
