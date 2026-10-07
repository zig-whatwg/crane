//! Implementation for Lock interface
//!
//! Web Locks API section 3.3: "A Lock object has an associated lock", whose
//! name and mode its getters return. A Lock is made only by LockManager, when
//! a request is granted ("process the lock request queue" step 14.2) -
//! through the hook this impl installs (html.web_locks.lock_objects): the
//! lock's name and mode are copied into the Lock, which needs nothing else of
//! it.
//!
//! Spec: https://w3c.github.io/web-locks/#lock

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const web_locks = @import("html").web_locks;
const Lock = interfaces.Lock;

pub const State = Lock.State;

pub const ImplError = error{
    NotImplemented,
    InvalidStateError,
};

/// The associated lock's name and mode.
pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// The lock's resource name. Owned.
    name: []u8 = &.{},
    mode: enums.LockMode = ._exclusive_,
};

fn getInternal(instance: *runtime.Instance) ?*InternalState {
    const state = instance.stateAs(State) orelse return null;
    return state.own._internal;
}

/// The hook LockManager makes a Lock through, installed once at process
/// start.
pub fn installHooks() void {
    web_locks.lock_objects.install(.{ .create = create });
}

/// "A new Lock object associated with lock", in `realm`.
fn create(realm: runtime.Context, name: []const u8, mode: web_locks.Mode) anyerror!*runtime.Instance {
    const instance = try Lock.init(realm.allocator, realm);
    // Never wrapped yet: its slot and state are this function's to free.
    errdefer runtime.Instance.deinit(instance);
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    internal.name = try internal.allocator.dupe(u8, name);
    internal.mode = switch (mode) {
        .shared => ._shared_,
        .exclusive => ._exclusive_,
    };
    return instance;
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
    if (state.own._internal) |internal| {
        internal.allocator.free(internal.name);
        internal.allocator.destroy(internal);
        state.own._internal = null;
    }
    // GC layer handles slab freeing - do NOT call runtime.Instance.deinit()
}

/// "The name getter's steps are to return the associated lock's name."
pub fn get_name(instance: *runtime.Instance) anyerror!runtime.DOMString {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return runtime.DOMString.initDupe(instance.ctx.allocator, internal.name);
}

/// "The mode getter's steps are to return the associated lock's mode."
pub fn get_mode(instance: *runtime.Instance) anyerror!enums.LockMode {
    const internal = getInternal(instance) orelse return error.InvalidStateError;
    return internal.mode;
}
