//! Implementation for PerformanceResourceTiming interface
//!
//! Spec: https://w3c.github.io/resource-timing/#sec-performanceresourcetiming
//!
//! An entry is made by Resource Timing's "mark resource timing", which fetch
//! runs (through its request's timing reporter) for a request with an
//! initiator type when its response is handed over: `dom.performance_timeline`
//! asks this impl, through the hook it installs, for a new entry set up with
//! a `ResourceTiming` - the fetch timing info's times already converted to
//! the entry's global's relative time, which the getters return.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const engine = @import("engine");
const performance_timeline = @import("dom").performance_timeline;
const PerformanceResourceTiming = interfaces.PerformanceResourceTiming;

pub const State = PerformanceResourceTiming.State;

pub const ImplError = error{
    NotImplemented,
};

/// What "setup the resource timing entry" set (its strings owned).
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    timing: performance_timeline.ResourceTiming,
};

/// The hooks this type owns (src/dom), installed once, at process start,
/// by crane.Process through the generated interface (docs/instances.md).
pub fn installHooks() void {
    performance_timeline.installResourceTimings(.{ .create = &createEntry, .setup = &setupEntry });
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    return runtime.Instance.init(allocator, StateType, vtable, ctx);
}

/// Deinitialize instance: what setup set, then PerformanceEntry's part.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.timing.deinit();
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    interfaces.PerformanceEntry.deinit(instance);
    // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// "mark resource timing" steps 1-2: a new PerformanceResourceTiming in
/// `realm`, with "setup the resource timing entry" given `timing`: step 3
/// initializes the PerformanceEntry (startTime, "resource", the requested
/// URL, end time), steps 4-11 are `timing` (copied).
fn createEntry(realm: runtime.Context, timing: *const performance_timeline.ResourceTiming) anyerror!*runtime.Instance {
    const allocator = realm.allocator;
    const instance = try init(allocator, State, &PerformanceResourceTiming.vtable, realm);
    errdefer runtime.Instance.deinit(instance);
    try performance_timeline.initializeEntry(instance, timing.start_time, .resource, timing.url, timing.end_time);
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);
    internal.* = .{ .allocator = allocator, .timing = try timing.clone(allocator) };
    instance.getState(State).own._internal = internal;
    return instance;
}

/// "setup the resource timing entry" steps 4-11 for `entry`, whose
/// PerformanceEntry its own type initialized (a PerformanceNavigationTiming):
/// `timing` copied into its PerformanceResourceTiming part.
fn setupEntry(entry: *runtime.Instance, timing: *const performance_timeline.ResourceTiming) anyerror!void {
    const state = entry.stateAs(State) orelse return error.InvalidStateError;
    const allocator = entry.ctx.allocator;
    const copy = try timing.clone(allocator);
    if (state.own._internal) |existing| {
        existing.timing.deinit();
        existing.timing = copy;
        return;
    }
    const internal = allocator.create(InternalState) catch |err| {
        var unused = copy;
        unused.deinit();
        return err;
    };
    internal.* = .{ .allocator = allocator, .timing = copy };
    state.own._internal = internal;
}

fn timingOf(instance: *runtime.Instance) !*const performance_timeline.ResourceTiming {
    const state = instance.stateAs(State) orelse return error.InvalidStateError;
    const internal = state.own._internal orelse return error.InvalidStateError;
    return &internal.timing;
}

/// Getter for initiatorType
pub fn get_initiatorType(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return runtime.DOMString.initInterned((try timingOf(instance)).initiator_type);
}

/// Getter for deliveryType
pub fn get_deliveryType(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return runtime.DOMString.initInterned((try timingOf(instance)).delivery_type);
}

/// Getter for nextHopProtocol: the final connection timing info's ALPN
/// negotiated protocol, isomorphic decoded. A ByteString result is the
/// binding's to free: a copy.
pub fn get_nextHopProtocol(instance: *runtime.Instance) anyerror!runtime.ByteString {
    const protocol = (try timingOf(instance)).next_hop_protocol;
    if (protocol.len == 0) return "";
    return instance.ctx.allocator.dupe(u8, protocol);
}

/// Getter for workerStart
pub fn get_workerStart(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    return (try timingOf(instance)).worker_start;
}

/// Getter for redirectStart
pub fn get_redirectStart(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    return (try timingOf(instance)).redirect_start;
}

/// Getter for redirectEnd
pub fn get_redirectEnd(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    return (try timingOf(instance)).redirect_end;
}

/// Getter for fetchStart: the post-redirect start time.
pub fn get_fetchStart(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    return (try timingOf(instance)).fetch_start;
}

/// Getter for domainLookupStart
pub fn get_domainLookupStart(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    return (try timingOf(instance)).domain_lookup_start;
}

/// Getter for domainLookupEnd
pub fn get_domainLookupEnd(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    return (try timingOf(instance)).domain_lookup_end;
}

/// Getter for connectStart
pub fn get_connectStart(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    return (try timingOf(instance)).connect_start;
}

/// Getter for connectEnd
pub fn get_connectEnd(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    return (try timingOf(instance)).connect_end;
}

/// Getter for secureConnectionStart
pub fn get_secureConnectionStart(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    return (try timingOf(instance)).secure_connection_start;
}

/// Getter for requestStart: the final network-request start time.
pub fn get_requestStart(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    return (try timingOf(instance)).request_start;
}

/// Getter for finalResponseHeadersStart: the final network-response start
/// time.
pub fn get_finalResponseHeadersStart(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    return (try timingOf(instance)).final_response_headers_start;
}

/// Getter for firstInterimResponseStart
pub fn get_firstInterimResponseStart(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    return (try timingOf(instance)).first_interim_response_start;
}

/// Getter for responseStart: firstInterimResponseStart if it is not 0,
/// otherwise finalResponseHeadersStart.
pub fn get_responseStart(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    const timing = try timingOf(instance);
    if (timing.first_interim_response_start != 0) return timing.first_interim_response_start;
    return timing.final_response_headers_start;
}

/// Getter for responseEnd: the end time.
pub fn get_responseEnd(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    return (try timingOf(instance)).response_end;
}

/// Getter for transferSize: 0 for a "local" cache mode, 300 for
/// "validated", else the encoded size plus 300 (standing in for the header
/// bytes, which could reveal cookies).
pub fn get_transferSize(instance: *runtime.Instance) anyerror!u64 {
    const timing = try timingOf(instance);
    return switch (timing.cache_mode) {
        .local => 0,
        .validated => 300,
        .none => timing.encoded_body_size + 300,
    };
}

/// Getter for encodedBodySize
pub fn get_encodedBodySize(instance: *runtime.Instance) anyerror!u64 {
    return (try timingOf(instance)).encoded_body_size;
}

/// Getter for decodedBodySize
pub fn get_decodedBodySize(instance: *runtime.Instance) anyerror!u64 {
    return (try timingOf(instance)).decoded_body_size;
}

/// Getter for responseStatus
pub fn get_responseStatus(instance: *runtime.Instance) anyerror!u16 {
    return (try timingOf(instance)).response_status;
}

/// Getter for renderBlockingStatus: "blocking" when the timing info says
/// render-blocking, else "non-blocking".
pub fn get_renderBlockingStatus(instance: *runtime.Instance) anyerror!enums.RenderBlockingStatusType {
    return if ((try timingOf(instance)).render_blocking) ._blocking_ else ._non_blocking_;
}

/// Getter for contentType
pub fn get_contentType(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return runtime.DOMString.initInterned((try timingOf(instance)).content_type);
}

/// Getter for contentEncoding
pub fn get_contentEncoding(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return runtime.DOMString.initInterned((try timingOf(instance)).content_encoding);
}

/// Getter for serverTiming (Server Timing): a sequence of
/// PerformanceServerTiming. Fetch does not parse `Server-Timing` yet, so
/// the list is empty - an Array of the current realm, never undefined.
pub fn get_serverTiming(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const realm = engine.currentRealm() orelse instance.ctx;
    const empty = try engine.createSequenceOfPlatformObjects(realm, &.{});
    return empty.take();
}

/// Getter for workerRouterEvaluationStart: no service worker router ran.
pub fn get_workerRouterEvaluationStart(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    _ = try timingOf(instance);
    return 0;
}

/// Getter for workerCacheLookupStart: no service worker cache lookup ran.
pub fn get_workerCacheLookupStart(instance: *runtime.Instance) anyerror!typedefs.DOMHighResTimeStamp {
    _ = try timingOf(instance);
    return 0;
}

/// Getter for workerMatchedRouterSource: none.
pub fn get_workerMatchedRouterSource(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = try timingOf(instance);
    return runtime.DOMString.initInterned("");
}

/// Getter for workerFinalRouterSource: none.
pub fn get_workerFinalRouterSource(instance: *runtime.Instance) anyerror!runtime.DOMString {
    _ = try timingOf(instance);
    return runtime.DOMString.initInterned("");
}

/// Operation: toJSON - WebIDL's default toJSON steps over PerformanceEntry's
/// and PerformanceResourceTiming's attributes. `serverTiming` is left
/// undefined (so JSON omits it): a JSValue in this struct would be a handle
/// nobody releases, and the list is always empty here.
pub fn call_toJSON(instance: *runtime.Instance) anyerror!interfaces.PerformanceResourceTiming.PerformanceResourceTimingToJSON {
    const timing = try timingOf(instance);
    const data = performance_timeline.dataOf(instance) orelse return error.InvalidStateError;
    return .{
        .id = data.id,
        .name = runtime.DOMString.initInterned(data.name),
        .entryType = runtime.DOMString.initInterned(data.entry_type.name()),
        .startTime = data.start_time,
        .duration = data.duration(),
        .navigationId = data.navigation_id,
        .initiatorType = runtime.DOMString.initInterned(timing.initiator_type),
        .deliveryType = runtime.DOMString.initInterned(timing.delivery_type),
        .nextHopProtocol = timing.next_hop_protocol,
        .workerStart = timing.worker_start,
        .redirectStart = timing.redirect_start,
        .redirectEnd = timing.redirect_end,
        .fetchStart = timing.fetch_start,
        .domainLookupStart = timing.domain_lookup_start,
        .domainLookupEnd = timing.domain_lookup_end,
        .connectStart = timing.connect_start,
        .connectEnd = timing.connect_end,
        .secureConnectionStart = timing.secure_connection_start,
        .requestStart = timing.request_start,
        .finalResponseHeadersStart = timing.final_response_headers_start,
        .firstInterimResponseStart = timing.first_interim_response_start,
        .responseStart = try get_responseStart(instance),
        .responseEnd = timing.response_end,
        .workerRouterEvaluationStart = 0,
        .workerCacheLookupStart = 0,
        .workerMatchedRouterSource = runtime.DOMString.initInterned(""),
        .workerFinalRouterSource = runtime.DOMString.initInterned(""),
        .transferSize = try get_transferSize(instance),
        .encodedBodySize = timing.encoded_body_size,
        .decodedBodySize = timing.decoded_body_size,
        .responseStatus = timing.response_status,
        .renderBlockingStatus = try get_renderBlockingStatus(instance),
        .contentType = runtime.DOMString.initInterned(timing.content_type),
        .contentEncoding = runtime.DOMString.initInterned(timing.content_encoding),
        .serverTiming = .undefined,
    };
}
