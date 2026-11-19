//! CSS Custom Highlight API 1 §2.3: the highlight registry - the ordered
//! map of names to custom highlights (`maplike<DOMString, Highlight>`) that
//! CSS.highlights answers.
//!
//! The map entries are dom.style.highlights.HighlightMap, which traces each
//! highlight from the registry; their maplike members (size, get, has, set,
//! delete, clear, forEach and the iterators) are the binding's (WebIDL
//! 3.7.11), which reaches them through the generated `maplikeEntries`.
//!
//! Spec: https://drafts.csswg.org/css-highlight-api-1/#registration

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const dictionaries = @import("dictionaries");
const webidl = @import("webidl");
const highlights = @import("dom").style.highlights;
const HighlightRegistry = interfaces.HighlightRegistry;

pub const State = HighlightRegistry.State;

pub const ImplError = error{InvalidStateError};

pub const InternalState = struct {
    map: highlights.HighlightMap,
};

fn internalOf(instance: *runtime.Instance) !*InternalState {
    const state = instance.stateAs(State) orelse return error.InvalidStateError;
    return state.own._internal orelse error.InvalidStateError;
}

pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    _ = args;
    const internal = try allocator.create(InternalState);
    internal.* = .{ .map = .init(instance, allocator) };
    instance.getState(StateType).own._internal = internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    const allocator = internal.map.allocator;
    internal.map.deinit();
    allocator.destroy(internal);
    state.own._internal = null;
}

/// highlightsFromPoint(x, y, options) (§6.3): the highlights whose ranges'
/// boxes contain the point - a hit test against the renderer's layout. With
/// no renderer every range has no box (CSSOM View's no-box answer, as
/// elementsFromPoint gives none), so no highlight is hit: an empty sequence.
/// x and y are restricted floats, so the binding has thrown for the
/// non-finite ones (step 1's "If any of x or y is non-finite" never
/// reaches here).
pub fn call_highlightsFromPoint(instance: *runtime.Instance, x: f32, y: f32, options: webidl.Opt(dictionaries.HighlightsFromPointOptions)) anyerror!runtime.JSValue {
    _ = x;
    _ = y;
    _ = options;
    const realm = engine.currentRealm() orelse instance.ctx;
    const result = try engine.createSequenceOfValues(realm, &.{});
    return result.take();
}

/// The map entries (WebIDL 2.5.11) for the binding's maplike members; null
/// once the instance's state is gone.
pub fn maplikeEntries(instance: *runtime.Instance) ?*webidl.maplike.PlatformObjects {
    const internal = internalOf(instance) catch return null;
    return internal.map.view();
}
