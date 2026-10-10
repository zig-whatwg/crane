//! HTML 6.5.2: CommandEvent's EventInit, command, and retargeted source.
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const dom = @import("dom");
const engine = @import("engine");
const CommandEvent = interfaces.CommandEvent;

pub const State = CommandEvent.State;
pub const ImplError = error{NotImplemented};
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    command: []u8 = &.{},
    // The event traces its source, including while waiting for its wrapper.
    // Generation and saved realm are the teardown net, as in ToggleEvent.
    source: ?dom.custom_elements.KeptInstance = null,
};
const source_slot: engine.TracedSlot = .{ .name = "source" };

pub fn init(allocator: std.mem.Allocator, comptime StateType: type, vtable: *const runtime.VTable, ctx: runtime.Context) !*runtime.Instance {
    const instance = try interfaces.Event.initWithState(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(State).own._internal = internal;
    return instance;
}

pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        if (internal.source != null) engine.forgetTracedChild(instance, source_slot);
        internal.allocator.free(internal.command);
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    interfaces.Event.deinit(instance);
}

pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.CommandEventInit)) !*runtime.Instance {
    const instance = try init(ctx.allocator, State, &CommandEvent.vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    const dict: dictionaries.CommandEventInit = eventInitDict.getOrDefault(.{ .base = .{} });
    // Interface dictionary conversion currently accepts any wrapped instance.
    if (dict.source) |source| if (source.stateAs(interfaces.Element.State) == null) return error.TypeError;
    // DOM inner event creation, then HTML's event-specific initialized values.
    try dom.event_construction.innerEventCreationSteps(instance, @"type", dom.event_construction.eventInitFrom(dict.base));
    const internal = instance.getState(State).own._internal.?;
    internal.command = try ctx.allocator.dupe(u8, if (dict.command) |command| command.asSlice() else "");
    if (dict.source) |source| {
        internal.source = dom.custom_elements.KeptInstance.of(source);
        engine.traceChild(instance, source, source_slot);
    }
    return instance;
}

pub fn get_source(instance: *runtime.Instance) anyerror!?*runtime.Instance {
    const internal = instance.getState(State).own._internal orelse return null;
    const kept = internal.source orelse return null;
    const source = kept.get() orelse return null;
    return dom.retarget.retarget(source, try interfaces.Event.get_currentTarget(instance));
}

pub fn get_command(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = instance.getState(State).own._internal orelse return runtime.DOMString.initEmpty();
    return runtime.DOMString.initDupe(instance.ctx.allocator, internal.command);
}
