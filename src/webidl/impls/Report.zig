//! Implementation for Report interface
//!
//! The browsers' Report interface (the user's ruling of 2026-11-05;
//! specs/supplementary/reporting-interfaces.idl): a report's type, URL and
//! body, read from the native report record it holds (Reporting §2.1,
//! dom.reporting.Record). Its body is made from the record the first time
//! script reads it and kept as the same object from then on, as Chromium's
//! Report::body() returns its member and WebKit's Report::body() its Ref.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const engine = @import("engine");
const reporting = @import("dom").reporting;
const Report = interfaces.Report;

pub const State = Report.State;

pub const construction_args = .{"record"};

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    record: *reporting.Record,
    /// The body made by the first read of `body` (its wrapper kept by an
    /// edge from this report's: `body_slot`), with its slab generation so
    /// that a body its wrapper's collection freed is never read.
    body: ?*runtime.Instance = null,
    body_generation: u64 = 0,
};

const body_slot: engine.TracedSlot = .{ .name = "body" };

/// The record is retained for the report's life.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    const record: *reporting.Record = args.record;
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator, .record = record };
    record.retain();
    instance.getState(StateType).own._internal = internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    internal.record.release();
    internal.allocator.destroy(internal);
}

fn internalOf(instance: *runtime.Instance) !*InternalState {
    const state = instance.stateAs(State) orelse return error.InvalidStateError;
    return state.own._internal orelse error.InvalidStateError;
}

/// Getter for type
pub fn get_type(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return runtime.DOMString.initInterned((try internalOf(instance)).record.type);
}

/// Getter for url
pub fn get_url(instance: *runtime.Instance) anyerror!runtime.DOMString {
    return runtime.DOMString.initInterned((try internalOf(instance)).record.url);
}

/// Getter for body: the same body object on every read, made from the
/// record on the first (dom.reporting.makeBody); null for a report type
/// with no body interface.
pub fn get_body(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = try internalOf(instance);
    if (internal.body) |body| {
        if (runtime.SlabAllocator.generationOf(body) == internal.body_generation) return body;
        internal.body = null;
    }
    const body = (try reporting.makeBody(instance.ctx, internal.record)) orelse return null;
    // The body's wrapper lives as long as this report's (Chromium traces
    // Report::body_, WebKit's Report holds a Ref to its body).
    engine.traceChild(instance, body, body_slot);
    internal.body = body;
    internal.body_generation = runtime.SlabAllocator.generationOf(body);
    return body;
}

/// Operation: toJSON - Chromium's Report::toJSON (report.cc): type, url,
/// and the body's JSON as a plain object (body()->BuildJSONValue), which
/// structured clone takes; the record keeps the body's members as that JSON.
pub fn call_toJSON(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = try internalOf(instance);
    const record = internal.record;
    const realm = engine.currentRealm() orelse instance.ctx;
    const body = try engine.parseJsonToValue(realm, record.body_json);
    defer body.release();
    const object = try engine.createDictionaryObject(realm, &.{
        .{ .name = "type", .value = .{ .string = .{ .data = record.type, .owned = false } } },
        .{ .name = "url", .value = .{ .string = .{ .data = record.url, .owned = false } } },
        .{ .name = "body", .value = body.value },
    });
    return object.take();
}
