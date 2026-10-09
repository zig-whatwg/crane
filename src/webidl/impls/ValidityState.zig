//! Implementation for ValidityState interface

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const ce = @import("dom").custom_elements;
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const ValidityState = interfaces.ValidityState;

pub const State = ValidityState.State;

pub const ImplError = error{
    NotImplemented,
};

/// HTML 4.10.21.3: a live view of its owner's constraints. As in Blink's
/// ValidityState::Trace, the edge keeps the control alive when only this
/// object remains reachable. Its generation is a teardown safety net.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    owner: ?union(enum) {
        internals: *runtime.Instance,
        control: *runtime.Instance,
    } = null,
    generation: u64 = 0,
    traced: bool = false,
};

pub fn installHooks() void {
    ce.installValidity(.{ .set_internals = &setInternals, .set_control = &setControl });
}

fn setInternals(instance: *runtime.Instance, internals: *runtime.Instance) !void {
    const state = instance.getState(State).own._internal orelse return error.InvalidStateError;
    state.owner = .{ .internals = internals };
    state.generation = runtime.SlabAllocator.generationOf(internals);
    if (instance.ctx.hasEngine()) {
        engine.traceChild(instance, internals, .{ .name = "elementInternals" });
        state.traced = true;
    }
}

fn setControl(instance: *runtime.Instance, control: *runtime.Instance) !void {
    const state = instance.getState(State).own._internal orelse return error.InvalidStateError;
    state.owner = .{ .control = control };
    state.generation = runtime.SlabAllocator.generationOf(control);
    if (instance.ctx.hasEngine()) {
        engine.traceChild(instance, control, .{ .name = "control" });
        state.traced = true;
    }
}

fn flagsOf(instance: *runtime.Instance) !ce.ValidityFlags {
    const state = instance.getState(State).own._internal orelse return error.InvalidStateError;
    const owner = state.owner orelse return error.InvalidStateError;
    const element = switch (owner) {
        inline else => |value| value,
    };
    if (runtime.SlabAllocator.generationOf(element) != state.generation or runtime.instance_lifecycle.isCleanedUp(element)) return error.InvalidStateError;
    return switch (owner) {
        .internals => ce.validityFlags(element),
        .control => @import("dom").form_controls.validityFlags(element),
    };
}

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    instance.getState(StateType).own._internal = internal;
    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    if (internal.traced) if (internal.owner) |owner| {
        engine.forgetTracedChild(instance, .{ .name = switch (owner) {
            .internals => "elementInternals",
            .control => "control",
        } });
    };
    internal.allocator.destroy(internal);
    state.own._internal = null;
}

/// Getter for valueMissing
pub fn get_valueMissing(instance: *runtime.Instance) anyerror!bool {
    return (try flagsOf(instance)).valueMissing orelse false;
}

/// Getter for typeMismatch
pub fn get_typeMismatch(instance: *runtime.Instance) anyerror!bool {
    return (try flagsOf(instance)).typeMismatch orelse false;
}

/// Getter for patternMismatch
pub fn get_patternMismatch(instance: *runtime.Instance) anyerror!bool {
    return (try flagsOf(instance)).patternMismatch orelse false;
}

/// Getter for tooLong
pub fn get_tooLong(instance: *runtime.Instance) anyerror!bool {
    return (try flagsOf(instance)).tooLong orelse false;
}

/// Getter for tooShort
pub fn get_tooShort(instance: *runtime.Instance) anyerror!bool {
    return (try flagsOf(instance)).tooShort orelse false;
}

/// Getter for rangeUnderflow
pub fn get_rangeUnderflow(instance: *runtime.Instance) anyerror!bool {
    return (try flagsOf(instance)).rangeUnderflow orelse false;
}

/// Getter for rangeOverflow
pub fn get_rangeOverflow(instance: *runtime.Instance) anyerror!bool {
    return (try flagsOf(instance)).rangeOverflow orelse false;
}

/// Getter for stepMismatch
pub fn get_stepMismatch(instance: *runtime.Instance) anyerror!bool {
    return (try flagsOf(instance)).stepMismatch orelse false;
}

/// Getter for badInput
pub fn get_badInput(instance: *runtime.Instance) anyerror!bool {
    return (try flagsOf(instance)).badInput orelse false;
}

/// Getter for customError
pub fn get_customError(instance: *runtime.Instance) anyerror!bool {
    return (try flagsOf(instance)).customError orelse false;
}

/// Getter for valid
pub fn get_valid(instance: *runtime.Instance) anyerror!bool {
    const flags = try flagsOf(instance);
    inline for (std.meta.fields(ce.ValidityFlags)) |field| {
        if (@field(flags, field.name) orelse false) return false;
    }
    return true;
}
