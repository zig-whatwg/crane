//! Implementation for NotRestoredReasons interface
//!
//! HTML 7.2.8: why a document was not restored from the back/forward cache,
//! with a NotRestoredReasons per document-tree child navigable. Its backing
//! struct is a "not restored reasons" (html_core.navigation
//! .not_restored_reasons), copied at construction ("create a
//! NotRestoredReasons object" step 2); its reasons and children arrays are
//! frozen arrays made once, from it, in its realm (steps 3-6), and traced by
//! it, so every read returns the same array.
//!
//! Spec: https://html.spec.whatwg.org/multipage/nav-history-apis.html#notrestoredreasons

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const interfaces = @import("interfaces");
const NotRestoredReasons = interfaces.NotRestoredReasons;
const Backing = @import("html_core").navigation.not_restored_reasons.NotRestoredReasons;

pub const State = NotRestoredReasons.State;

pub const ImplError = error{
    NotImplemented,
};

/// The backing struct (`*const Backing`), copied at construction.
pub const construction_args = .{"backing"};

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// The backing struct: a copy, OWNED.
    backing: Backing,
    /// The reasons and children arrays were made (and are traced).
    has_reasons_array: bool = false,
    has_children_array: bool = false,
};

const reasons_slot: engine.TracedSlot = .{ .name = "reasons" };
const children_slot: engine.TracedSlot = .{ .name = "children" };

/// "Create a NotRestoredReasons object" steps 1-2: a copy of the backing
/// struct it is made with (none: an empty one, every member null).
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);
    const backing: Backing = if (@hasField(@TypeOf(args), "backing")) try args.backing.clone(allocator) else .{};
    internal.* = .{ .allocator = allocator, .backing = backing };
    instance.getState(StateType).own._internal = internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        if (internal.has_reasons_array) engine.forgetTracedChild(instance, reasons_slot);
        if (internal.has_children_array) engine.forgetTracedChild(instance, children_slot);
        internal.backing.deinit(internal.allocator);
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
}

fn internalOf(instance: *runtime.Instance) !*InternalState {
    const state = instance.stateAs(State) orelse return error.InvalidStateError;
    return state.own._internal orelse error.InvalidStateError;
}

/// A copy for the binding, which frees what a getter returns ("" is not
/// allocated).
fn usvCopy(instance: *runtime.Instance, value: ?[]const u8) !?runtime.USVString {
    const text = value orelse return null;
    if (text.len == 0) return "";
    return try instance.ctx.allocator.dupe(u8, text);
}

/// Getter for src: "this's backing struct's src".
pub fn get_src(instance: *runtime.Instance) anyerror!?runtime.USVString {
    return usvCopy(instance, (try internalOf(instance)).backing.src);
}

/// Getter for id: "this's backing struct's id".
pub fn get_id(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    const id = (try internalOf(instance)).backing.id orelse return null;
    return runtime.DOMString.initInterned(id);
}

/// Getter for name: "this's backing struct's name".
pub fn get_name(instance: *runtime.Instance) anyerror!?runtime.DOMString {
    const name = (try internalOf(instance)).backing.name orelse return null;
    return runtime.DOMString.initInterned(name);
}

/// Getter for url: null when the backing struct's URL is null, else it,
/// serialized (kept serialized).
pub fn get_url(instance: *runtime.Instance) anyerror!?runtime.USVString {
    return usvCopy(instance, (try internalOf(instance)).backing.url);
}

/// Getter for reasons: "this's reasons array" - null when the backing
/// struct's reasons are null, else a frozen array of a
/// NotRestoredReasonDetails per reason ("create a NotRestoredReasons
/// object" steps 3-4), made in this object's realm the first time it is
/// read and the same array after.
pub fn get_reasons(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    const internal = try internalOf(instance);
    const reasons = internal.backing.reasons orelse return null;
    if (!instance.ctx.hasEngine()) return error.InvalidStateError;
    if (internal.has_reasons_array) {
        if (engine.tracedValue(instance, reasons_slot)) |array| return array.take();
    }
    const allocator = internal.allocator;
    const values = try allocator.alloc(runtime.JSValue, reasons.len);
    defer allocator.free(values);
    const generations = try allocator.alloc(u64, reasons.len);
    defer allocator.free(generations);
    var initialized: usize = 0;
    defer for (values[0..initialized], generations[0..initialized]) |value, generation| {
        value.instance.releaseIfUnwrapped(generation);
    };
    for (reasons, values, generations) |reason, *value, *generation| {
        const object = try interfaces.NotRestoredReasonDetails.initWith(allocator, instance.ctx, .{ .reason = reason });
        value.* = .{ .instance = object };
        generation.* = runtime.SlabAllocator.generationOf(object);
        initialized += 1;
    }
    const array = try engine.createFrozenArray(instance.ctx, values);
    engine.traceValue(instance, array.value, reasons_slot);
    internal.has_reasons_array = true;
    return array.take();
}

/// Getter for children: "this's children array" - null when the backing
/// struct's children are null, else a frozen array of a NotRestoredReasons
/// per child ("create a NotRestoredReasons object" steps 5-6), made in this
/// object's realm the first time it is read and the same array after.
pub fn get_children(instance: *runtime.Instance) anyerror!?runtime.JSValue {
    const internal = try internalOf(instance);
    const children = internal.backing.children orelse return null;
    if (!instance.ctx.hasEngine()) return error.InvalidStateError;
    if (internal.has_children_array) {
        if (engine.tracedValue(instance, children_slot)) |array| return array.take();
    }
    const allocator = internal.allocator;
    const values = try allocator.alloc(runtime.JSValue, children.len);
    defer allocator.free(values);
    const generations = try allocator.alloc(u64, children.len);
    defer allocator.free(generations);
    var initialized: usize = 0;
    defer for (values[0..initialized], generations[0..initialized]) |value, generation| {
        value.instance.releaseIfUnwrapped(generation);
    };
    for (children, values, generations) |*child, *value, *generation| {
        const object = try interfaces.NotRestoredReasons.initWith(allocator, instance.ctx, .{ .backing = @as(*const Backing, child) });
        value.* = .{ .instance = object };
        generation.* = runtime.SlabAllocator.generationOf(object);
        initialized += 1;
    }
    const array = try engine.createFrozenArray(instance.ctx, values);
    engine.traceValue(instance, array.value, children_slot);
    internal.has_children_array = true;
    return array.take();
}

/// Operation: toJSON ([Default]): every attribute, the arrays included.
/// The binding copies the strings of a returned record without freeing
/// them, so they are the backing struct's, borrowed; the arrays are holds
/// handed over, which it releases (releaseReturnedDictionaryHandles).
pub fn call_toJSON(instance: *runtime.Instance) anyerror!interfaces.NotRestoredReasons.NotRestoredReasonsToJSON {
    const backing = &(try internalOf(instance)).backing;
    const reasons = try get_reasons(instance);
    errdefer if (reasons) |held| engine.releaseValue(.{ .value = held });
    const children = try get_children(instance);
    return .{
        .src = backing.src,
        .id = if (backing.id) |id| runtime.DOMString.initInterned(id) else null,
        .name = if (backing.name) |name| runtime.DOMString.initInterned(name) else null,
        .url = backing.url,
        .reasons = reasons,
        .children = children,
    };
}
