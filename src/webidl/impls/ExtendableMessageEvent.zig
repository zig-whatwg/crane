//! Implementation for ExtendableMessageEvent interface
//!
//! Spec: Service Workers 4.7 ExtendableMessageEvent
//! https://w3c.github.io/ServiceWorker/#extendablemessageevent-interface
//!
//! The `message` and `messageerror` events a service worker's global gets
//! from ServiceWorker.postMessage(): an ExtendableEvent (its extended
//! lifetime is ExtendableEvent's construction argument) with the message's
//! data, origin, source and ports. The service worker's thread
//! (src/service_worker/run.zig) makes it with `message` - an origin, which
//! the event's extract-an-origin steps return; script constructs one with a
//! dictionary, whose origin is a string and no origin.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const engine = @import("engine");
const dom = @import("dom");
const service_worker = @import("service_worker");
const ExtendableMessageEvent = interfaces.ExtendableMessageEvent;
const OriginRecord = dom.origin_record.OriginRecord;

pub const State = ExtendableMessageEvent.State;

pub const ImplError = error{
    NotImplemented,
    TypeError,
};

/// What the user agent's event is made with
/// (service_worker.objects.ExtendableMessageInit), BORROWED.
pub const construction_args = .{"message"};

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// data: an inline value, or a view of `data_hold`.
    data: runtime.JSValue = runtime.JSValue.jsNull,
    data_hold: ?engine.Owned = null,
    /// A string data's own copy (`data` borrows it).
    data_string: ?[]u8 = null,
    /// The event's origin when it is an origin (a user agent's event): its
    /// extract-an-origin steps return it. One reference, on this thread.
    origin_record: ?*OriginRecord = null,
    /// The event's origin when it is a string (a constructor's). OWNED.
    origin_string: []u8 = &.{},
    /// OWNED.
    last_event_id: []u8 = &.{},
    /// source, held: the event may be all that refers to it.
    source: ?*runtime.Instance = null,
    source_hold: ?engine.Owned = null,
    /// The ports array, made at construction: it is what holds the ports.
    ports_hold: ?engine.Owned = null,
};

pub fn installHooks() void {
    dom.extract_origin.install(.extendable_message_event, .{ .owns = &ownsOriginExtraction, .extract = &extractOrigin });
}

fn ownsOriginExtraction(instance: *runtime.Instance) bool {
    return instance.stateAs(State) != null;
}

/// 4.7.3: "Objects implementing the ExtendableMessageEvent interface's
/// extract an origin steps are to return this's origin if it is an origin;
/// otherwise null."
fn extractOrigin(instance: *runtime.Instance) !?*OriginRecord {
    const internal = instance.getState(State).own._internal orelse return null;
    const record = internal.origin_record orelse return null;
    return record.retain();
}

/// ExtendableMessageEvent's own construction steps: the generated chain runs
/// ExtendableEvent's (and Event's) first.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = StateType;
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(State).own._internal = internal;
    if (!@hasField(@TypeOf(args), "message")) return;
    errdefer releaseAll(internal);
    const init: service_worker.objects.ExtendableMessageInit = args.message;
    const ctx = instance.ctx;
    try keepData(ctx, internal, init.data);
    // Its origin is an origin - made on this thread from its serialization
    // (an opaque origin's identity does not cross threads).
    internal.origin_record = try OriginRecord.create(allocator, init.origin);
    try keepSource(ctx, internal, init.source);
    try keepPorts(ctx, internal, init.ports);
}

/// ExtendableMessageEvent's own teardown: the generated chain runs
/// ExtendableEvent's after it.
pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    releaseAll(internal);
    internal.allocator.destroy(internal);
    state.own._internal = null;
}

fn releaseAll(internal: *InternalState) void {
    const allocator = internal.allocator;
    if (internal.data_hold) |hold| hold.release();
    internal.data_hold = null;
    if (internal.data_string) |text| allocator.free(text);
    internal.data_string = null;
    internal.data = runtime.JSValue.jsNull;
    if (internal.origin_record) |record| record.release();
    internal.origin_record = null;
    allocator.free(internal.origin_string);
    internal.origin_string = &.{};
    allocator.free(internal.last_event_id);
    internal.last_event_id = &.{};
    if (internal.source_hold) |hold| hold.release();
    internal.source_hold = null;
    internal.source = null;
    if (internal.ports_hold) |hold| hold.release();
    internal.ports_hold = null;
}

/// The event's own hold on `data` (borrowed): a script value is retained,
/// a string copied, anything else kept as it is.
fn keepData(ctx: runtime.Context, internal: *InternalState, data: runtime.JSValue) !void {
    switch (data) {
        .handle, .instance => {
            const hold = try engine.retainValue(ctx, data);
            internal.data_hold = hold;
            internal.data = hold.value;
        },
        .string => |text| {
            const copy = try internal.allocator.dupe(u8, text.data);
            internal.data_string = copy;
            internal.data = runtime.JSValue.fromStringRef(copy);
        },
        // `any data = null`: absent or undefined is null.
        .undefined => internal.data = runtime.JSValue.jsNull,
        else => internal.data = data,
    }
}

fn keepSource(ctx: runtime.Context, internal: *InternalState, source: ?*runtime.Instance) !void {
    const instance = source orelse return;
    internal.source_hold = try engine.retainValue(ctx, runtime.JSValue.fromInstance(instance));
    internal.source = instance;
}

/// The frozen ports array, made now: it is what keeps the ports.
fn keepPorts(ctx: runtime.Context, internal: *InternalState, ports: []const *runtime.Instance) !void {
    const values = try internal.allocator.alloc(runtime.JSValue, ports.len);
    defer internal.allocator.free(values);
    for (ports, values) |port, *value| value.* = runtime.JSValue.fromInstance(port);
    internal.ports_hold = try engine.createFrozenArray(ctx, values);
}

/// new ExtendableMessageEvent(type, eventInitDict): DOM's inner event
/// creation steps, then the dictionary's members.
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.ExtendableMessageEventInit)) !*runtime.Instance {
    const instance = try ExtendableMessageEvent.init(ctx.allocator, ctx);
    errdefer ExtendableMessageEvent.deinit(instance);
    const given: dictionaries.ExtendableMessageEventInit = if (eventInitDict.was_passed) eventInitDict.value else .{ .base = .{ .base = .{} } };
    try dom.event_construction.innerEventCreationSteps(instance, @"type", dom.event_construction.eventInitFrom(given.base.base));
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    try keepData(ctx, internal, given.data orelse runtime.JSValue.jsNull);
    if (given.origin) |origin| internal.origin_string = try internal.allocator.dupe(u8, origin);
    if (given.lastEventId) |id| internal.last_event_id = try internal.allocator.dupe(u8, id.asSlice());
    // source: (Client or ServiceWorker or MessagePort)?.
    if (given.source) |value| switch (value) {
        .null, .undefined => {},
        else => {
            const instance_source = engine.convertToPlatformObject(ctx, value) orelse return error.TypeError;
            const accepted = instance_source.stateAs(interfaces.Client.State) != null or
                instance_source.stateAs(interfaces.ServiceWorker.State) != null or
                instance_source.stateAs(interfaces.MessagePort.State) != null;
            if (!accepted) return error.TypeError;
            try keepSource(ctx, internal, instance_source);
        },
    };
    try keepPorts(ctx, internal, given.ports orelse &.{});
    return instance;
}

fn internalOf(instance: *runtime.Instance) !*InternalState {
    return instance.getState(State).own._internal orelse error.InvalidStateError;
}

/// Getter for data (4.7.1): the value it was initialized to.
pub fn get_data(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = try internalOf(instance);
    return switch (internal.data) {
        // The event keeps its own; the binding gets a hold of its own.
        .handle => (try engine.retainValue(instance.ctx, internal.data)).take(),
        else => internal.data,
    };
}

/// Getter for origin (4.7.2): an origin serialized, a string as it is, or
/// the empty string.
pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
    const internal = try internalOf(instance);
    // 1. An origin: its serialization.
    if (internal.origin_record) |record| return instance.ctx.allocator.dupe(u8, record.serialized orelse "null");
    // 2-3. Null: the empty string; a string: itself.
    return instance.ctx.allocator.dupe(u8, internal.origin_string);
}

/// Getter for lastEventId (4.7.3).
pub fn get_lastEventId(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = try internalOf(instance);
    return runtime.DOMString.initInterned(internal.last_event_id);
}

/// Getter for source (4.7.4): the value it was initialized to.
pub fn get_source(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    const internal = try internalOf(instance);
    const source = internal.source orelse return null;
    return runtime.JSValue.fromInstance(source);
}

/// Getter for ports (4.7.5): the frozen array it was initialized to.
pub fn get_ports(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = try internalOf(instance);
    if (internal.ports_hold == null) try keepPorts(instance.ctx, internal, &.{});
    return (try engine.retainValue(instance.ctx, internal.ports_hold.?.value)).take();
}
