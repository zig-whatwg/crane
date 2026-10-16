//! Permissions 6.3: a query result, constructed through EventTarget's chain.
//! Spec: https://w3c.github.io/permissions/#permissionstatus-interface
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const enums = @import("enums");
const permissions = @import("permissions");

pub const State = interfaces.PermissionStatus.State;
pub const ImplError = error{InvalidStateError};
pub const construction_args = .{ "permission_descriptor", "permission_state" };

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// [[query]] is owned by value: a permission name and its native fields,
    /// with no reference to the script dictionary or its getters.
    query: ?permissions.PermissionDescriptor = null,
    state: permissions.PermissionState = .prompt,
};

/// 6.3.1 steps 3.1-3.2. The generated chain has initialized EventTarget.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    const internal = try allocator.create(InternalState);
    internal.* = .{ .allocator = allocator };
    if (comptime @hasField(@TypeOf(args), "permission_descriptor")) internal.query = args.permission_descriptor;
    if (comptime @hasField(@TypeOf(args), "permission_state")) internal.state = args.permission_state;
    instance.getState(StateType).own._internal = internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    internal.allocator.destroy(internal);
    state.own._internal = null;
}

/// 6.3.3: return this's state.
pub fn get_state(instance: *runtime.Instance) anyerror!enums.PermissionState {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    return switch (internal.state) {
        .granted => ._granted_,
        .denied => ._denied_,
        .prompt => ._prompt_,
    };
}

/// 6.3.2: return the name initialized at construction.
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = instance.getState(State).own._internal orelse return error.InvalidStateError;
    const query = internal.query orelse return runtime.DOMString.initEmpty();
    return runtime.DOMString.initInterned(query.name.toString());
}

// 6.3.4 onchange is the generated interface's shared event handler. No native
// status registry: Browser permission changes await platform recipes step 8.
