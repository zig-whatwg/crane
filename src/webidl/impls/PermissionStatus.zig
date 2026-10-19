//! Permissions 6.3: a query result, constructed through EventTarget's chain.
//! Spec: https://w3c.github.io/permissions/#permissionstatus-interface
const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const enums = @import("enums");
const permissions = @import("permissions");
const engine = @import("engine");
const dom = @import("dom");

pub const State = interfaces.PermissionStatus.State;
pub const ImplError = error{InvalidStateError};
pub const construction_args = .{ "permission_descriptor", "permission_state", "permission_key", "permission_key_owner" };

pub const InternalState = struct {
    allocator: std.mem.Allocator,
    /// [[query]] is owned by value: a permission name and its native fields,
    /// with no reference to the script dictionary or its getters.
    query: ?permissions.PermissionDescriptor = null,
    state: permissions.PermissionState = .prompt,
    store: ?*permissions.BrowserStore = null,
};

/// 6.3.1 steps 3.1-3.2. The generated chain has initialized EventTarget.
pub fn initOwn(instance: *runtime.Instance, allocator: std.mem.Allocator, comptime StateType: type, args: anytype) !void {
    const internal = try allocator.create(InternalState);
    errdefer allocator.destroy(internal);
    internal.* = .{ .allocator = allocator };
    if (comptime @hasField(@TypeOf(args), "permission_descriptor")) internal.query = args.permission_descriptor;
    if (comptime @hasField(@TypeOf(args), "permission_state")) internal.state = args.permission_state;
    if (comptime @hasField(@TypeOf(args), "permission_key_owner")) {
        // The caller allocated this key with the construction allocator.
        // Parent/own/store failure leaves its slot untouched. After listen
        // succeeds no fallible work remains, and no slot pointer is retained.
        if (args.permission_key_owner.*) |key| if (internal.query) |descriptor| if (instance.ctx.browser_scope) |scope| {
            const store = try scope.of(permissions.BrowserStore);
            internal.state = try store.listenOwned(instance, key, allocator, descriptor, internal.state, deliverChange);
            args.permission_key_owner.* = null;
            internal.store = store;
        };
    } else if (comptime @hasField(@TypeOf(args), "permission_key")) {
        if (args.permission_key) |key| if (internal.query) |descriptor| if (instance.ctx.browser_scope) |scope| {
            const store = try scope.of(permissions.BrowserStore);
            internal.state = try store.listen(instance, key, descriptor, internal.state, deliverChange);
            internal.store = store;
        };
    }
    instance.getState(StateType).own._internal = internal;
}

pub fn deinitOwn(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    const internal = state.own._internal orelse return;
    if (internal.store) |store| store.unlisten(instance);
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

/// On the status's own task sink and thread, after its registration was
/// checked. No pending-activity hold is added here: retaining a status only
/// while change listeners exist is the separate EventTarget lifetime task.
fn deliverChange(instance: *runtime.Instance, next: permissions.PermissionState) void {
    if (!instance.ctx.hasEngine()) return;
    var delivery = Change{ .instance = instance, .next = next };
    engine.runTaskInRealm(instance.ctx, Change.run, &delivery) catch {};
}

const Change = struct {
    instance: *runtime.Instance,
    next: permissions.PermissionState,

    fn run(data: ?*anyopaque) void {
        const self: *Change = @ptrCast(@alignCast(data.?));
        const instance = self.instance;
        const realm = instance.ctx;
        // PermissionStatus update steps 1.1-1.2: an inactive Window's
        // document receives neither the state update nor its change event.
        if (realm.isWindow()) {
            const record = realm.getRealm() orelse return;
            const window: *runtime.Instance = @ptrCast(@alignCast(record.global_object orelse return));
            if (!dom.document_activity.fullyActive(window, runtime.SlabAllocator.generationOf(window))) return;
        }
        const internal = instance.getState(State).own._internal orelse return;
        if (internal.state == self.next) return;
        // Steps 2-3. The queued value is the result of the descriptor's
        // query algorithm, including Storage Access's denied -> prompt rule.
        internal.state = self.next;
        // Step 4, on the queued permissions task: a trusted, non-bubbling,
        // non-cancelable Event. The generated onchange accessor shares the
        // EventTarget listener path with addEventListener.
        const event = interfaces.Event.call_constructor(realm, runtime.DOMString.initInterned("change"), .notPassed()) catch return;
        const generation = runtime.SlabAllocator.generationOf(event);
        _ = dom.fire_event.dispatchTrusted(instance, event) catch {};
        event.releaseIfUnwrapped(generation);
    }
};
