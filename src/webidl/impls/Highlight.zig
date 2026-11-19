//! CSS Custom Highlight API 1 §2.2: a custom highlight - a set of ranges
//! (`setlike<AbstractRange>`), with a priority and a type.
//!
//! The set entries are dom.style.highlights.RangeSet, which traces each range
//! from the highlight; their setlike members (size, has, add, delete, clear,
//! forEach and the iterators) are the binding's (WebIDL 3.7.12), which
//! reaches them through the generated `setlikeEntries`.
//!
//! Spec: https://drafts.csswg.org/css-highlight-api-1/#creation

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const enums = @import("enums");
const webidl = @import("webidl");
const highlights = @import("dom").style.highlights;
const Highlight = interfaces.Highlight;

pub const State = Highlight.State;

pub const ImplError = error{InvalidStateError};

pub const InternalState = struct {
    ranges: highlights.RangeSet,
    /// "priority": initially 0 (constructor step 3).
    priority: i32 = 0,
    /// "type": initially "highlight" (constructor step 4).
    type: enums.HighlightType = ._highlight_,
};

fn internalOf(instance: *runtime.Instance) !*InternalState {
    const state = instance.stateAs(State) orelse return error.InvalidStateError;
    return state.own._internal orelse error.InvalidStateError;
}

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = args;
    const internal = try allocator.create(InternalState);
    internal.* = .{ .ranges = .init(instance, allocator) };
    instance.getState(StateType).own._internal = internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    const allocator = internal.ranges.allocator;
    internal.ranges.deinit();
    allocator.destroy(internal);
    state.own._internal = null;
}

/// new Highlight(...initialRanges): "1. Let highlight be the new Highlight
/// object. 2. For each range of initialRanges, let rangeArg be the result of
/// converting range to an ECMAScript value, then run the steps for a
/// built-in setlike add function, with highlight as the this value and
/// rangeArg as the argument. 3. Set highlight's priority to 0. 4. Set
/// highlight's type to highlight." The arguments are AbstractRanges already
/// (the binding converted them), so step 2's add is the set entries' append.
pub fn call_constructor(ctx: runtime.Context, initialRanges: []const *runtime.Instance) !*runtime.Instance {
    const instance = try Highlight.init(ctx.allocator, ctx);
    errdefer Highlight.deinit(instance);
    const internal = try internalOf(instance);
    for (initialRanges) |range| try internal.ranges.add(range);
    return instance;
}

pub fn get_priority(instance: *runtime.Instance) anyerror!i32 {
    return (try internalOf(instance)).priority;
}

pub fn set_priority(instance: *runtime.Instance, value: i32) anyerror!void {
    (try internalOf(instance)).priority = value;
}

pub fn get_type(instance: *runtime.Instance) anyerror!enums.HighlightType {
    return (try internalOf(instance)).type;
}

pub fn set_type(instance: *runtime.Instance, value: enums.HighlightType) anyerror!void {
    (try internalOf(instance)).type = value;
}

/// The set entries (WebIDL 2.5.12) for the binding's setlike members; null
/// once the instance's state is gone.
pub fn setlikeEntries(instance: *runtime.Instance) ?*webidl.setlike.PlatformObjects {
    const internal = internalOf(instance) catch return null;
    return internal.ranges.view();
}
