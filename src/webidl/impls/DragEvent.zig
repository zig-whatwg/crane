//! Implementation for DragEvent interface (HTML 6.11.4): a MouseEvent with
//! the DataTransfer it was initialized with.
//!
//! The event keeps its DataTransfer by a traced edge (slot
//! "drag-event:dataTransfer"), as Blink's DragEvent traces data_transfer_:
//! a listener that keeps the event keeps its DataTransfer. Not a node, so
//! no node hold.
//!
//! https://html.spec.whatwg.org/multipage/dnd.html#the-dragevent-interface

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const engine = @import("engine");
const DragEvent = interfaces.DragEvent;

pub const State = DragEvent.State;

pub const ImplError = error{
    NotImplemented,
};

/// The DataTransfer the event was initialized to, when it has one.
pub const InternalState = struct {
    data_transfer: *runtime.Instance,
    /// Whether the edge is drawn (an engine; engine-free tests draw none).
    traced: bool,
};

const data_transfer_slot: engine.TracedSlot = .{ .name = "drag-event:dataTransfer" };

pub const construction_args = .{"drag_init"};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// The generated chain initializes MouseEvent before DragEvent's own part:
/// "Initialize ... its dataTransfer attribute to" the dictionary's.
pub fn initOwn(
    instance: *runtime.Instance,
    allocator: std.mem.Allocator,
    comptime StateType: type,
    args: anytype,
) !void {
    _ = allocator;
    _ = StateType;
    if (!@hasField(@TypeOf(args), "drag_init")) return;
    const dictionary: dictionaries.DragEventInit = args.drag_init;
    const data_transfer = dictionary.dataTransfer orelse return;
    const internal = try runtime.arenaOf(instance).create(InternalState);
    internal.* = .{ .data_transfer = data_transfer, .traced = instance.ctx.hasEngine() };
    instance.getState(State).own._internal = internal;
    if (internal.traced) engine.traceChild(instance, data_transfer, data_transfer_slot);
}

/// Let the DataTransfer go with the event.
pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    state.own._internal = null;
    if (internal.traced) engine.forgetTracedChild(instance, data_transfer_slot);
    runtime.arenaOf(instance).destroy(InternalState, internal);
}

/// DOM event constructor steps 1–2, including all MouseEventInit members.
/// https://html.spec.whatwg.org/multipage/dnd.html#the-dragevent-interface
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.DragEventInit)) !*runtime.Instance {
    const dictionary: dictionaries.DragEventInit = if (eventInitDict.was_passed) eventInitDict.value else .{ .base = .{ .base = .{ .base = .{ .base = .{} } } } };
    return DragEvent.initWith(ctx.allocator, ctx, .{
        .mouse_type = @"type",
        .mouse_init = dictionary.base,
        .drag_init = dictionary,
    });
}

/// Getter for dataTransfer: "must return the value it was initialized to".
pub fn get_dataTransfer(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    return internal.data_transfer;
}
