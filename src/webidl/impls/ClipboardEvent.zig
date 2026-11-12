//! Implementation for ClipboardEvent interface
//!
//! Spec: Clipboard API and events 5.1
//! https://w3c.github.io/clipboard-apis/#clipboard-event-interfaces
//!
//! ```idl
//! [Exposed=Window]
//! interface ClipboardEvent : Event {
//!   constructor(DOMString type, optional ClipboardEventInit eventInitDict = {});
//!   readonly attribute DataTransfer? clipboardData;
//! };
//! dictionary ClipboardEventInit : EventInit {
//!   DataTransfer? clipboardData = null;
//! };
//! ```
//!
//! The event traces its clipboardData, as SubmitEvent its submitter: a
//! cycle through the event is collected with it (Blink's ClipboardEvent::
//! Trace visits clipboard_data_). The link's generation and the saved realm
//! are only the teardown net. The clipboard actions (src/html/execcommand/
//! clipboard.zig) make their events through this constructor.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const dom = @import("dom");
const event_construction = dom.event_construction;
const same_object = dom.same_object;
const ClipboardEvent = interfaces.ClipboardEvent;

pub const State = ClipboardEvent.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    clipboard_data: ?same_object.Link = null,
    clipboard_data_realm: ?runtime.Context = null,
};

pub const construction_args = .{ "clipboard_event_type", "clipboard_event_init" };

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// The generated chain makes Event's part first; then the DOM event
/// constructor steps (inner event creation steps with the EventInit
/// members) and ClipboardEventInit's clipboardData.
pub fn initOwn(
    instance: *runtime.Instance,
    allocator: std.mem.Allocator,
    comptime StateType: type,
    args: anytype,
) !void {
    _ = StateType;
    if (@hasField(@TypeOf(args), "clipboard_event_type")) {
        const dictionary: dictionaries.ClipboardEventInit = if (@hasField(@TypeOf(args), "clipboard_event_init")) args.clipboard_event_init else .{ .base = .{} };
        try event_construction.innerEventCreationSteps(instance, args.clipboard_event_type, event_construction.eventInitFrom(dictionary.base));
        const internal = try allocator.create(InternalState);
        internal.* = .{ .allocator = allocator };
        if (dictionary.clipboardData) |data_transfer| {
            internal.clipboard_data = same_object.Link.to(data_transfer);
            internal.clipboard_data_realm = data_transfer.ctx;
            engine.traceChild(instance, data_transfer, .{ .name = "clipboardData" });
        }
        instance.getState(State).own._internal = internal;
        return;
    }
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(State).own._internal = internal;
}

/// ClipboardEvent's own teardown: the generated chain runs Event's after it.
pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    // A native event can die before its wrapper exists: end the edge
    // waiting for that wrapper, as SubmitEvent does for its submitter.
    if (internal.clipboard_data != null) engine.forgetTracedChild(instance, .{ .name = "clipboardData" });
    internal.allocator.destroy(internal);
    state.own._internal = null;
}

/// Constructor: the DOM event constructor steps, then clipboardData
/// ("initialized to" the dictionary's member, null by default).
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.ClipboardEventInit)) !*runtime.Instance {
    const dictionary: dictionaries.ClipboardEventInit = if (eventInitDict.was_passed) eventInitDict.value else .{ .base = .{} };
    return ClipboardEvent.initWith(ctx.allocator, ctx, .{
        .clipboard_event_type = @"type",
        .clipboard_event_init = dictionary,
    });
}

/// Getter for clipboardData: the DataTransfer the event was initialized
/// with, kept alive by the event's traced edge.
pub fn get_clipboardData(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    const link = internal.clipboard_data orelse return null;
    const realm = internal.clipboard_data_realm orelse return null;
    if (!realm.hasEngine()) return null;
    if (!link.isLive()) return null;
    return link.instance;
}
