//! Implementation for the TrustedScriptURL interface (Trusted Types 2.2.3).
//!
//! "TrustedScriptURL objects have an associated string data. The value is set
//! when the object is created, and will never change during its lifetime."
//! Only a policy makes one (3.2 "create a trusted type", through
//! dom.trusted_types); there is no constructor.
//!
//! Spec: https://w3c.github.io/trusted-types/dist/spec/#trustedscripturl

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const dom = @import("dom");
const TrustedScriptURL = interfaces.TrustedScriptURL;

pub const State = TrustedScriptURL.State;

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// The associated data, owned.
    data: []u8,
};

pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);
    errdefer runtime.Instance.deinit(instance);
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator, .data = &.{} };
    instance.getState(StateType).own._internal = internal;
    return instance;
}

pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.allocator.free(internal.data);
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    // NOTE: Do NOT call runtime.Instance.deinit() - GC layer handles slab freeing
}

pub fn installHooks() void {
    dom.trusted_types.installValue(.script_url, .{ .create = &create, .data_of = &dataOf });
}

/// A new TrustedScriptURL in `realm` whose data is a copy of `data`.
fn create(realm: runtime.Context, data: []const u8) anyerror!*runtime.Instance {
    const instance = try TrustedScriptURL.init(realm.allocator, realm);
    errdefer TrustedScriptURL.deinit(instance);
    const internal = instance.getState(State).own._internal.?;
    internal.data = try internal.allocator.dupe(u8, data);
    return instance;
}

/// `instance`'s data when it is a TrustedScriptURL.
fn dataOf(instance: *runtime.Instance) ?[]const u8 {
    if (instance.vtable != &TrustedScriptURL.vtable) return null;
    const internal = instance.getState(State).own._internal orelse return null;
    return internal.data;
}

/// "The toJSON() method steps ... are to return the associated data value."
pub fn call_toJSON(instance: *runtime.Instance) anyerror!runtime.USVString {
    const data = dataOf(instance) orelse return error.TypeError;
    return instance.ctx.allocator.dupe(u8, data);
}

/// The stringification behavior: the associated data, as a copy (the
/// binding frees the string toString() returns).
pub fn serialize(instance: *runtime.Instance) anyerror!runtime.USVString {
    const data = dataOf(instance) orelse return error.TypeError;
    return instance.ctx.allocator.dupe(u8, data);
}
