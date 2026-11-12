//! Implementation for InputEvent interface
//!
//! Spec: https://w3c.github.io/uievents/#interface-inputevent and
//! https://w3c.github.io/input-events/#interface-InputEvent
//!
//! ```idl
//! [Exposed=Window]
//! interface InputEvent : UIEvent {
//!   constructor(DOMString type, optional InputEventInit eventInitDict = {});
//!   readonly attribute USVString? data;
//!   readonly attribute boolean isComposing;
//!   readonly attribute DOMString inputType;
//!   readonly attribute DataTransfer? dataTransfer;
//!   sequence<StaticRange> getTargetRanges();
//! };
//! dictionary InputEventInit : UIEventInit {
//!   DOMString? data = null; boolean isComposing = false; DOMString inputType = "";
//!   DataTransfer? dataTransfer = null; sequence<StaticRange> targetRanges = [];
//! };
//! ```
//!
//! dataTransfer is kept as SubmitEvent keeps its submitter: a traced edge
//! (Blink's InputEvent::Trace visits data_transfer_), a link and its realm as
//! the teardown net. The paste action gives its beforeinput and input in an
//! editing host one (Input Events 2, insertFromPaste: "dataTransfer" holds
//! what is inserted; src/html/execcommand/clipboard.zig).
//! Stated: targetRanges are not kept - nothing fires beforeinput with ranges
//! yet - so getTargetRanges() is an empty sequence.

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
const InputEvent = interfaces.InputEvent;

pub const State = InputEvent.State;

pub const ImplError = error{
    NotImplemented,
};

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// Owned; null is the null data.
    data: ?[]u8 = null,
    /// Owned.
    input_type: []u8 = &.{},
    is_composing: bool = false,
    data_transfer: ?dom.same_object.Link = null,
    data_transfer_realm: ?runtime.Context = null,

    fn clear(self: *InternalState) void {
        if (self.data) |d| self.allocator.free(d);
        self.data = null;
        self.allocator.free(self.input_type);
        self.input_type = &.{};
    }
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// Initialize instance: the UIEvent part, then InputEvent's own state.
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try interfaces.UIEvent.initWithState(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(StateType).own._internal = internal;
    return instance;
}

/// Deinitialize instance: its own state, then the UIEvent part.
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        // A native event can die before its wrapper exists: end the edge
        // waiting for that wrapper (SubmitEvent's submitter likewise).
        if (internal.data_transfer != null) engine.forgetTracedChild(instance, .{ .name = "dataTransfer" });
        internal.clear();
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    interfaces.UIEvent.deinit(instance);
}

/// Constructor: inner event creation steps, UIEventInit's members, then
/// data, isComposing and inputType.
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.InputEventInit)) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &InputEvent.vtable, ctx);
    errdefer deinit(instance);
    const dict: dictionaries.InputEventInit = if (eventInitDict.was_passed) eventInitDict.value else .{ .base = .{ .base = .{} } };
    try event_construction.innerEventCreationSteps(instance, @"type", event_construction.eventInitFrom(dict.base.base));
    event_construction.initializeUIEvent(instance, event_construction.uiEventInitFrom(dict.base));

    const internal = getInternal(instance) orelse return error.InvalidStateError;
    const allocator = internal.allocator;
    const data: ?[]u8 = if (dict.data) |d| try allocator.dupe(u8, d.asSlice()) else null;
    errdefer if (data) |d| allocator.free(d);
    const input_type = try allocator.dupe(u8, if (dict.inputType) |t| t.asSlice() else "");
    internal.clear();
    internal.data = data;
    internal.input_type = input_type;
    internal.is_composing = dict.isComposing orelse false;
    if (dict.dataTransfer) |data_transfer| {
        internal.data_transfer = dom.same_object.Link.to(data_transfer);
        internal.data_transfer_realm = data_transfer.ctx;
        engine.traceChild(instance, data_transfer, .{ .name = "dataTransfer" });
    }
    return instance;
}

/// Getter for data. A copy: the binding frees what a USVString getter
/// returns.
pub fn get_data(instance: *runtime.Instance) anyerror!?runtime.USVString {
    const internal = getInternal(instance) orelse return null;
    const data = internal.data orelse return null;
    if (data.len == 0) return "";
    return try instance.ctx.allocator.dupe(u8, data);
}

/// Getter for isComposing
pub fn get_isComposing(instance: *runtime.Instance) anyerror!bool {
    const internal = getInternal(instance) orelse return false;
    return internal.is_composing;
}

/// Getter for inputType. A copy, as data's.
pub fn get_inputType(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return runtime.DOMString.initEmpty();
    return runtime.DOMString.initDupe(instance.ctx.allocator, internal.input_type);
}

/// Getter for dataTransfer: the DataTransfer the event was initialized
/// with, kept alive by the event's traced edge.
pub fn get_dataTransfer(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = getInternal(instance) orelse return null;
    const link = internal.data_transfer orelse return null;
    const realm = internal.data_transfer_realm orelse return null;
    if (!realm.hasEngine()) return null;
    if (!link.isLive()) return null;
    return link.instance;
}

/// Operation: getTargetRanges - an empty sequence (stated above).
pub fn call_getTargetRanges(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const realm = engine.currentRealm() orelse instance.ctx;
    return (try engine.createSequenceOfPlatformObjects(realm, &.{})).take();
}
