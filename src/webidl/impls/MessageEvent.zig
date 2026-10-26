//! Implementation for MessageEvent interface
//!
//! MessageEvent is dispatched when a message is received through various APIs:
//! - WebSocket: when a message is received from the server
//! - postMessage: when a message is posted to a window/worker
//! - Server-Sent Events: when an event is received
//! - BroadcastChannel: when a message is received on the channel
//!
//! Spec: https://html.spec.whatwg.org/multipage/comms.html#messageevent
//!
//! For WebSocket specifically:
//! - data contains the message payload (string or binary)
//! - origin is the URL of the WebSocket server
//! - lastEventId is empty string (not used for WebSocket)
//! - source is null (not used for WebSocket)
//! - ports is an empty array (not used for WebSocket)

const std = @import("std");
const log = std.log.scoped(.message_event);
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const engine = @import("engine");
const event_construction = @import("dom").event_construction;
const MessageEvent = interfaces.MessageEvent;

pub const State = MessageEvent.State;

pub const ImplError = error{
    NotImplemented,
};

/// Internal state for MessageEvent implementation
pub const InternalState = struct {
    /// The user agent's origin, when supplied as a record. This event owns
    /// one reference on its own thread; script's origin string supplies none.
    origin_record: ?*@import("dom").origin_record.OriginRecord = null,
    /// Whether we own the origin string (should free on deinit)
    owns_origin: bool = false,
    /// The event's own hold on `data` when it is a script value: `data` is a
    /// view of it. Released on deinit.
    data_hold: ?engine.Owned = null,
    /// The frozen array `get_ports` made for this event: `ports` is a view of
    /// it. Released on deinit.
    ports_hold: ?engine.Owned = null,
    /// The event's ports, as the MessagePort instances they are: the frozen
    /// array `ports` returns is made from them on first read. Owned slice
    /// (ctx.allocator); the ports themselves are not.
    ports: []*runtime.Instance = &.{},
    /// The event's hold on `source`'s wrapper, when the constructor was
    /// given one: the event may be all that refers to it. Released on deinit.
    /// Not for a WindowProxy of another realm (`source_window`).
    source_hold: ?engine.Owned = null,
    /// A source that is another realm's WindowProxy: the Window it named
    /// when set, held with its generation (runtime.window_holders.Link), and
    /// a traced edge from this event to the proxy itself (`source_slot`).
    /// The source getter answers the proxy - whatever document its browsing
    /// context shows now - and the Link only when there is no edge to read.
    source_window: ?runtime.window_holders.Link = null,
};

/// The member a MessageEvent keeps another realm's WindowProxy source in
/// (engine.traceValue).
const source_slot: engine.TracedSlot = .{ .name = "source" };

/// Hold `source` for the event (`internal`'s), as `source_hold` and
/// `source_window` say.
///
/// A WindowProxy holder keeps the PROXY, never the Window it showed then
/// (lane winslot1, kind 3; the integrator's ruling of 2026-10-25 on the
/// three-browser probe, tmp/analysis/integrator-probes-1025n): after the
/// source's frame navigates, `source` is the same proxy showing the new
/// document (Firefox 158, Safari 27; Chrome 155 answers null), and after
/// its iframe is removed, the same proxy, closed (Chrome, Firefox; Safari
/// null) - Firefox's behaviour, the majority mechanism by mechanism.
/// WebKit's MessageEvent keeps `Ref<WindowProxy>` (dom/MessageEvent.h). The
/// edge is traced, never a root: the removed frame's realm lives exactly as
/// long as the event. A source of the event's own realm needs none: the
/// event goes with that realm, and the realm keeps its Window while it
/// lives.
fn holdSource(instance: *runtime.Instance, internal: *InternalState, source: typedefs.MessageEventSource) void {
    switch (source) {
        .window_proxy => |window| {
            if (window.ctx == instance.ctx) return;
            internal.source_window = runtime.window_holders.Link.of(window);
            engine.traceValue(instance, .{ .instance = window }, source_slot);
        },
        inline else => |object| internal.source_hold = engine.retainValue(instance.ctx, .{ .instance = object }) catch null,
    }
}

/// Let go of what `holdSource` held.
fn releaseSource(instance: *runtime.Instance, internal: *InternalState) void {
    if (internal.source_hold) |held| {
        held.release();
        internal.source_hold = null;
    }
    if (internal.source_window != null) {
        engine.forgetTracedChild(instance, source_slot);
        internal.source_window = null;
    }
}

pub fn installHooks() void {
    @import("dom").extract_origin.install(.message_event, .{ .owns = &ownsOriginExtraction, .extract = &extractOrigin });
}

fn ownsOriginExtraction(instance: *runtime.Instance) bool {
    return instance.stateAs(State) != null;
}

/// MessageEvent extract-an-origin steps 1-2: only an origin record can be
/// extracted. A string, including "null", does not identify an origin.
fn extractOrigin(instance: *runtime.Instance) !?*@import("dom").origin_record.OriginRecord {
    const internal = instance.getState(State).own._internal orelse return null;
    const record = internal.origin_record orelse return null;
    return record.retain();
}

fn releaseOriginRecord(internal: *InternalState) void {
    if (internal.origin_record) |record| record.release();
    internal.origin_record = null;
}

/// Let go of the event's hold on `data`, if it has one: `data` is undefined
/// after.
fn releaseData(state: anytype, internal: *InternalState) void {
    if (internal.data_hold) |held| {
        held.release();
        internal.data_hold = null;
        state.own.data = runtime.JSValue.jsUndefined;
    }
}

/// Facts given at construction, all borrowed. Only user-agent construction
/// supplies an actual origin record; call_constructor supplies a string.
pub const construction_args = .{ "message_type", "message_init", "message_origin_record" };

/// The generated chain creates Event's part before this interface's own.
pub fn initOwn(
    instance: *runtime.Instance,
    allocator: std.mem.Allocator,
    comptime StateType: type,
    args: anytype,
) !void {
    _ = allocator;
    _ = StateType;

    const state = instance.getState(State);
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = .{};
    state.own._internal = internal;
    errdefer deinitOwn(instance);

    if (@hasField(@TypeOf(args), "message_type")) {
        const dictionary: dictionaries.MessageEventInit = if (@hasField(@TypeOf(args), "message_init")) args.message_init else .{ .base = .{} };
        try initialize(instance, args.message_type, dictionary);
    }
    if (@hasField(@TypeOf(args), "message_origin_record")) {
        const given: ?*@import("dom").origin_record.OriginRecord = args.message_origin_record;
        if (given) |record| internal.origin_record = record.retain();
    }
}

/// Release only this interface's own part; the generated chain ends Event's.
pub fn deinitOwn(instance: *runtime.Instance) void {
    var state = instance.getState(State);

    // The handles this event owns: a deserialized postMessage payload, and
    // the frozen ports array.
    if (state.own._internal) |internal| {
        releaseOriginRecord(internal);
        releaseData(state, internal);
        if (internal.ports_hold) |held| {
            held.release();
            internal.ports_hold = null;
            state.own.ports = runtime.JSValue.jsUndefined;
        }
        if (internal.ports.len > 0) instance.ctx.allocator.free(internal.ports);
        internal.ports = &.{};
        releaseSource(instance, internal);
        state.own.source = null;
    }

    // Clean up the cloned JSValue data (if it's an owned string)
    // This was cloned in call_constructor to take ownership using ctx.allocator
    state.own.data.deinit(instance.ctx.allocator);
    // The event's own copy of lastEventId (empty unless a constructor's
    // dictionary or initMessageEvent gave one).
    state.own.lastEventId.deinit(instance.ctx.allocator);

    if (state.own._internal) |internal| {
        // Free the constructor's copy of an origin string.
        if (internal.owns_origin and state.own.origin.len > 0) {
            instance.ctx.allocator.free(state.own.origin);
        }
    }

    // Release MessageEvent's OWN internal block. The parent releases the Event-level
    // one, which on a MessageEvent instance is a different allocation.
    if (state.own._internal) |internal| {
        runtime.arenaOf(instance).destroy(InternalState, internal);
        state.own._internal = null;
    }
}

/// Constructor implementation
/// Spec: https://html.spec.whatwg.org/multipage/comms.html#dom-messageevent-messageevent
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.MessageEventInit)) !*runtime.Instance {
    var dictionary = if (eventInitDict.was_passed) eventInitDict.value else dictionaries.MessageEventInit{ .base = .{} };
    // Web IDL dictionary conversion applies the default to an undefined
    // member. UA construction initializes attributes directly instead: a
    // posted undefined value must remain undefined (HTML step 8.7).
    if (dictionary.data) |data| {
        if (data == .undefined) dictionary.data = runtime.JSValue.jsNull;
    }
    return MessageEvent.initWith(ctx.allocator, ctx, .{
        .message_type = @"type",
        .message_init = dictionary,
    });
}

/// DOM event constructor steps 1-2, including the inherited Event steps and
/// the MessageEventInit attributes. The event keeps every supplied value.
fn initialize(instance: *runtime.Instance, event_type: runtime.DOMString, init_dict: dictionaries.MessageEventInit) !void {
    const ctx = instance.ctx;
    const state = instance.getState(State);
    try event_construction.innerEventCreationSteps(instance, event_type, event_construction.eventInitFrom(init_dict.base));

    // DOM inner event creation step 4: initialize the dictionary's members.
    // The binding and UA caller own their inputs; this event owns copies.
    state.own.data = if (init_dict.data) |data| try keepData(ctx, instance, data) else runtime.JSValue.jsNull;
    if (init_dict.origin) |origin| {
        if (origin.len > 0) {
            state.own.origin = try ctx.allocator.dupe(u8, origin);
            if (state.own._internal) |internal| internal.owns_origin = true;
        } else {
            state.own.origin = "";
        }
    } else {
        state.own.origin = "";
    }
    state.own.lastEventId = if (init_dict.lastEventId) |id| try id.clone(ctx.allocator) else runtime.DOMString.initEmpty();

    // A source wrapper may have no other holder, as when a new MessagePort
    // is passed directly to the constructor. Retain it for this event.
    state.own.source = init_dict.source;
    if (init_dict.source) |source| {
        // With no engine to wrap in (a unit test's realm) there is no
        // collector either, and nothing to hold.
        if (state.own._internal) |internal| holdSource(instance, internal, source);
    }

    // The frozen array is what keeps the ports before script first reads
    // them. A port's own pending activity starts only once its queue does.
    if (init_dict.ports) |ports| {
        if (ports.len > 0) {
            if (state.own._internal) |internal| {
                internal.ports = try ctx.allocator.dupe(*runtime.Instance, ports);
                // Where no array can be made now, the first read makes it.
                makePortsArray(instance) catch {};
            }
        }
    }
}

/// The event's own hold on `data` (borrowed from the dictionary): a string
/// is copied, and a script value is retained - OWNED by the event, released
/// in deinit - so it lives as long as the event, not as long as whoever
/// handed it over.
fn keepData(ctx: runtime.Context, instance: *runtime.Instance, data: runtime.JSValue) !runtime.JSValue {
    switch (data) {
        .handle, .instance => {
            const internal = instance.getState(State).own._internal orelse return data.clone(ctx.allocator);
            const held = try engine.retainValue(ctx, data);
            internal.data_hold = held;
            return held.value;
        },
        else => return data.clone(ctx.allocator),
    }
}

/// Getter for data
/// Spec: https://html.spec.whatwg.org/multipage/comms.html#dom-messageevent-data
///
/// For WebSocket:
/// - Returns a DOMString if binaryType is "blob" and message was text
/// - Returns a Blob if binaryType is "blob" and message was binary
/// - Returns an ArrayBuffer if binaryType is "arraybuffer" and message was binary
pub fn get_data(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const state = instance.getState(State);
    // The event keeps what it holds: a handle goes to the binding as a hold
    // of its own, and a string as a reference - the binding frees a string
    // result handed over owned, and this one is the event's (keepData's copy).
    return switch (state.own.data) {
        .handle => (try engine.retainValue(instance.ctx, state.own.data)).take(),
        .string => |text| runtime.JSValue.fromStringRef(text.data),
        else => state.own.data,
    };
}

/// Getter for origin
/// Spec: https://html.spec.whatwg.org/multipage/comms.html#dom-messageevent-origin
///
/// For WebSocket, this is the URL of the WebSocket server.
pub fn get_origin(instance: *runtime.Instance) anyerror!runtime.USVString {
    const state = instance.getState(State);
    // Getter step 1: serialize an origin. Steps 2-3 return the string below.
    if (state.own._internal) |internal| {
        if (internal.origin_record) |record| return instance.ctx.allocator.dupe(u8, record.serialized orelse "null");
    }
    log.debug("[MessageEvent.get_origin] value=\"{s}\"\n", .{state.own.origin});
    // The binding frees a returned USVString, so it gets a copy. Returning the
    // field itself freed it on the first read of `e.origin`; the second read
    // was a use-after-free and `deinit` then freed it again.
    if (state.own.origin.len == 0) return "";
    return instance.ctx.allocator.dupe(u8, state.own.origin);
}

/// Getter for lastEventId
/// Spec: https://html.spec.whatwg.org/multipage/comms.html#dom-messageevent-lasteventid
///
/// For WebSocket, this is always an empty string.
/// This is used by Server-Sent Events.
pub fn get_lastEventId(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const state = instance.getState(State);
    log.debug("[MessageEvent.get_lastEventId] called\n", .{});
    // Return as interned to avoid double-free (state owns the string)
    return runtime.DOMString.initInterned(state.own.lastEventId.asSlice());
}

/// Getter for source
/// Spec: https://html.spec.whatwg.org/multipage/comms.html#dom-messageevent-source
///
/// For WebSocket, this is always null.
/// This is used by postMessage to identify the sending window/worker.
pub fn get_source(instance: *runtime.Instance) anyerror!?typedefs.MessageEventSource {
    const state = instance.getState(State);
    const source = state.own.source orelse return null;
    // Another realm's WindowProxy: the proxy the event keeps, as the Window
    // it shows now (`holdSource`); with no edge to read, the Window it named,
    // while that is still the one.
    if (source == .window_proxy) if (state.own._internal) |internal| if (internal.source_window) |link| {
        if (engine.tracedValue(instance, source_slot)) |held| {
            defer held.release();
            if (engine.convertToPlatformObject(instance.ctx, held.value)) |window| return .{ .window_proxy = window };
        }
        return if (link.get()) |window| .{ .window_proxy = window } else null;
    };
    return source;
}

/// Getter for ports
/// Spec: https://html.spec.whatwg.org/multipage/comms.html#dom-messageevent-ports
///
/// "The ports attribute must return the value it was initialized to": a
/// FROZEN array of the ports transferred with the message (or given to the
/// constructor) - empty when there were none. It is one array for the life
/// of the event, so `e.ports === e.ports`; the event owns it and releases it
/// in deinit.
pub fn get_ports(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const state = instance.getState(State);
    if (state.own._internal == null) return runtime.JSValue.jsUndefined;
    try makePortsArray(instance);
    // The event keeps its array; the binding gets a hold of its own.
    return switch (state.own.ports) {
        .handle => (try engine.retainValue(instance.ctx, state.own.ports)).take(),
        else => state.own.ports,
    };
}

/// The event's frozen ports array, made once and kept (`ports_hold`). The
/// constructor makes it at once, since it is what keeps the ports: calling
/// get_ports there would take a hold nothing releases.
fn makePortsArray(instance: *runtime.Instance) !void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    if (internal.ports_hold != null) return;
    const allocator = instance.ctx.allocator;
    const values = try allocator.alloc(runtime.JSValue, internal.ports.len);
    defer allocator.free(values);
    for (internal.ports, values) |port, *value| value.* = .{ .instance = port };
    const ports = try engine.createFrozenArray(instance.ctx, values);
    internal.ports_hold = ports;
    state.own.ports = ports.value;
}

/// Operation: initMessageEvent (legacy)
/// Spec: https://html.spec.whatwg.org/multipage/comms.html#dom-messageevent-initmessageevent
///
/// "The initMessageEvent() method must initialize the event in a manner
/// analogous to the similarly-named initEvent() method": DOM's initEvent
/// steps - 1. if this's dispatch flag is set, return; 2. initialize this with
/// type, bubbles and cancelable - and then this interface's own attributes.
///
/// Every argument is the binding's, freed when this returns: the event keeps
/// copies of its strings (Event's initEvent copies the type) and a hold of
/// its own on data and source. Storing the `type` argument itself made every
/// read of `type` a read of freed memory and the event's teardown a double
/// free - four "Double free detected" per run of
/// html/webappapis/scripting/events/messageevent-constructor.https.html.
pub fn call_initMessageEvent(instance: *runtime.Instance, @"type": runtime.DOMString, bubbles: webidl.Opt(bool), cancelable: webidl.Opt(bool), data: webidl.Opt(runtime.JSValue), origin: webidl.Opt(runtime.USVString), lastEventId: webidl.Opt(runtime.DOMString), source: webidl.Opt(?typedefs.MessageEventSource), ports: webidl.Opt(runtime.JSValue)) anyerror!void {
    const allocator = instance.ctx.allocator;
    const state = instance.getState(State);

    // initEvent step 1: an event being dispatched is left as it is.
    if (event_construction.dispatchFlag(instance)) return;

    // The copies first - the fallible part - so nothing is half set.
    var next_last_event_id = if (lastEventId.was_passed) try lastEventId.value.clone(allocator) else runtime.DOMString.initEmpty();
    errdefer next_last_event_id.deinit(allocator);
    const next_origin: []const u8 = if (origin.was_passed and origin.value.len > 0) try allocator.dupe(u8, origin.value) else "";
    errdefer if (next_origin.len > 0) allocator.free(next_origin);

    // initEvent step 2: initialize this with type, bubbles and cancelable.
    try interfaces.Event.call_initEvent(instance, @"type", bubbles, cancelable);

    // This interface's attributes. What the event held before is let go.
    if (state.own._internal) |internal| {
        releaseOriginRecord(internal);
        releaseData(state, internal);
        if (internal.owns_origin and state.own.origin.len > 0) allocator.free(state.own.origin);
        internal.owns_origin = false;
        releaseSource(instance, internal);
    }
    state.own.data.deinit(allocator);
    // `optional any data = null`: absent or undefined is null.
    state.own.data = runtime.JSValue.jsNull;
    if (data.was_passed and data.value != .undefined) state.own.data = try keepData(instance.ctx, instance, data.value);

    state.own.origin = next_origin;
    if (next_origin.len > 0) {
        if (state.own._internal) |internal| internal.owns_origin = true;
    }

    state.own.lastEventId.deinit(allocator);
    state.own.lastEventId = next_last_event_id;

    // "source": the event holds its wrapper, as the constructor's does.
    state.own.source = if (source.was_passed) source.value else null;
    if (state.own.source) |source_value| {
        if (state.own._internal) |internal| holdSource(instance, internal, source_value);
    }

    // TODO(seam): "ports" - a sequence<MessagePort> the binding hands over as
    // an `any` (initMessageEvent's ports default `[]`); setting the frozen
    // array from it needs the array's elements as MessagePort instances.
    _ = ports;
}
