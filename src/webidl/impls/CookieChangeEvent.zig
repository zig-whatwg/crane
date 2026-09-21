//! Implementation for CookieChangeEvent interface
//!
//! WHATWG Cookie Store Standard: https://cookiestore.spec.whatwg.org/
//!
//! The CookieChangeEvent interface represents an event for cookie changes
//! in Window contexts. It contains lists of changed and deleted cookies.

const std = @import("std");
const runtime = @import("runtime");
const interfaces = @import("interfaces");
const typedefs = @import("typedefs");
const enums = @import("enums");
const dictionaries = @import("dictionaries");
const callbacks = @import("callbacks");
const webidl = @import("webidl");
const cookiestore = @import("cookiestore");
const CookieChangeEvent = interfaces.CookieChangeEvent;
const CookieListItem = cookiestore.CookieListItem;

// The FrozenArray<CookieListItem> attributes have to be marshalled into real V8
// arrays, so this impl reaches for the engine directly.
const v8_engine = @import("v8");
const v8 = v8_engine.ffi;

pub const State = CookieChangeEvent.State;

pub const ImplError = error{
    NotImplemented,
    TypeError,
    OutOfMemory,
};

/// Internal state for CookieChangeEvent implementation
pub const InternalState = struct {
    /// Changed cookies (FrozenArray<CookieListItem>)
    changed: std.ArrayListUnmanaged(CookieListItem),

    /// Deleted cookies (FrozenArray<CookieListItem>)
    deleted: std.ArrayListUnmanaged(CookieListItem),

    /// Allocator for internal allocations
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !*InternalState {
        const internal = try allocator.create(InternalState);
        internal.* = InternalState{
            .changed = .empty,
            .deleted = .empty,
            .allocator = allocator,
        };
        return internal;
    }

    pub fn deinit(self: *InternalState) void {
        for (self.changed.items) |*item| {
            item.deinit();
        }
        self.changed.deinit(self.allocator);

        for (self.deleted.items) |*item| {
            item.deinit();
        }
        self.deleted.deinit(self.allocator);

        self.allocator.destroy(self);
    }

    /// Add a changed cookie
    pub fn addChanged(self: *InternalState, item: CookieListItem) !void {
        try self.changed.append(self.allocator, item);
    }

    /// Add a deleted cookie
    pub fn addDeleted(self: *InternalState, item: CookieListItem) !void {
        try self.deleted.append(self.allocator, item);
    }
};

/// Initialize instance (creates the instance)
pub fn init(
    allocator: std.mem.Allocator,
    comptime StateType: type,
    vtable: *const runtime.VTable,
    ctx: runtime.Context,
) !*runtime.Instance {
    const instance = try runtime.Instance.init(allocator, StateType, vtable, ctx);

    // Initialize internal state
    const internal = try InternalState.init(allocator);

    const state = instance.getState(StateType);
    state.own._internal = internal;

    return instance;
}

/// Deinitialize instance
pub fn deinit(instance: *runtime.Instance) void {
    const state = instance.getState(State);
    if (state.own._internal) |internal| {
        internal.deinit();
    }
}

/// Helper to get internal state
fn getInternalState(instance: *runtime.Instance) ?*InternalState {
    const state = instance.getState(State);
    return state.own._internal;
}

/// Constructor implementation
/// https://cookiestore.spec.whatwg.org/#dom-cookiechangeevent-cookiechangeevent
///
/// The CookieChangeEvent(type, eventInitDict) constructor steps are:
/// 1. Set this's changed attribute to eventInitDict["changed"]
/// 2. Set this's deleted attribute to eventInitDict["deleted"]
pub fn call_constructor(ctx: runtime.Context, @"type": runtime.DOMString, eventInitDict: webidl.Opt(dictionaries.CookieChangeEventInit)) !*runtime.Instance {
    _ = @"type"; // Event type is handled by Event base class

    // Create instance through init()
    const instance = try init(ctx.allocator, State, &CookieChangeEvent.vtable, ctx);
    errdefer deinit(instance);

    const internal = getInternalState(instance) orelse return error.NotImplemented;

    // Process eventInitDict if provided
    if (eventInitDict.was_passed) {
        const init_dict = eventInitDict.value;

        // Process changed cookies
        // init_dict.changed is ?[]const dictionaries.CookieListItem (CookieList typedef)
        if (init_dict.changed) |changed_list| {
            for (changed_list) |dict_item| {
                // Convert dictionary CookieListItem to our internal CookieListItem
                const item = CookieListItem{
                    .name = try ctx.allocator.dupe(u8, dict_item.name orelse ""),
                    .value = try ctx.allocator.dupe(u8, dict_item.value orelse ""),
                    .allocator = ctx.allocator,
                };
                try internal.addChanged(item);
            }
        }

        // Process deleted cookies
        if (init_dict.deleted) |deleted_list| {
            for (deleted_list) |dict_item| {
                const item = CookieListItem{
                    .name = try ctx.allocator.dupe(u8, dict_item.name orelse ""),
                    .value = try ctx.allocator.dupe(u8, dict_item.value orelse ""),
                    .allocator = ctx.allocator,
                };
                try internal.addDeleted(item);
            }
        }
    }

    return instance;
}

// ============================================================================
// FrozenArray<CookieListItem> marshalling
//
// `changed` and `deleted` used to return
// `runtime.JSValue.fromAnyopaque(@ptrCast(&internal.changed))` - the address of
// a Zig `ArrayListUnmanaged`. `fromAnyopaque` produces a `.handle` with
// `handle_scope = .global`, and the getter path in
// src/runtime/engines/v8/interface.zig hands that pointer straight to
// `v8_FunctionCallbackInfo_SetReturnValueGlobal`, which `reinterpret_cast`s it
// to `Global<Value>*` and dereferences it. A heap-allocated Zig struct is
// aligned and inside the heap range, so every guard in that function passes and
// the read goes through - taking the process down, not the subtest.
// src/runtime/js_value.zig:199-207 names this exact mistake.
//
// The fix is to build a real V8 array of `{name, value}` objects. Ownership
// follows the house rule (AGENTS.md): every `v8_*` call returning a pointer
// allocates a `Global<T>` the caller owns, so everything acquired here is
// disposed except the array handed back, which the return path consumes.
//
// The duplication with CookieStore.zig's `Realm` is deliberate: impls are
// private to each other (AGENTS.md, "The impls boundary"), and a shared helper
// would have to live outside `impls/`.
// ============================================================================

/// The current isolate and context, for the duration of one getter.
const Realm = struct {
    isolate: *v8.Isolate,
    context: *v8.Context,

    fn enter() error{NoRealm}!Realm {
        const isolate = v8.v8_Isolate_GetCurrent() orelse return error.NoRealm;
        const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return error.NoRealm;
        return .{ .isolate = isolate, .context = context };
    }

    /// `v8_Isolate_GetCurrentContext` allocated the Global we are holding.
    fn exit(self: Realm) void {
        v8.v8_Context_Dispose(self.context);
    }

    fn setString(self: Realm, object: *v8.Object, key: []const u8, value: []const u8) error{OutOfMemory}!void {
        const key_str = v8.v8_String_NewFromUtf8(self.isolate, key.ptr, @intCast(key.len)) orelse
            return error.OutOfMemory;
        defer v8.v8_String_Dispose(key_str);

        // An empty Zig slice has no usable `.ptr`. A deleted cookie always has
        // an empty value, and an unnamed cookie an empty name, so this arm is
        // the common case here rather than an edge.
        const value_str = if (value.len > 0)
            v8.v8_String_NewFromUtf8(self.isolate, value.ptr, @intCast(value.len)) orelse
                return error.OutOfMemory
        else
            v8.v8_String_Empty(self.isolate) orelse return error.OutOfMemory;
        defer v8.v8_String_Dispose(value_str);

        _ = v8.v8_Object_Set(object, self.context, @ptrCast(key_str), @ptrCast(value_str));
    }

    /// A `CookieListItem` as script sees it: `{ name, value }`.
    /// https://cookiestore.spec.whatwg.org/#create-a-cookielistitem
    fn cookieListItem(self: Realm, item: CookieListItem) error{OutOfMemory}!*v8.Object {
        const object = v8.v8_Object_NewInContext(self.context) orelse return error.OutOfMemory;
        errdefer v8.v8_Object_Dispose(object);

        try self.setString(object, "name", item.name);
        try self.setString(object, "value", item.value);
        return object;
    }

    /// A JS Array of CookieListItem objects.
    ///
    /// Deviation, stated per AGENTS.md: the IDL says `[SameObject]
    /// FrozenArray`, and this builds a fresh, unfrozen array per read. Freezing
    /// and caching need a `Global<Array>` held in instance state and disposed
    /// in `deinit`, which is teardown-order work this change does not take on.
    /// Script sees a correct array with correct contents; it sees a different
    /// array identity on each read.
    fn cookieList(self: Realm, items: []const CookieListItem) error{OutOfMemory}!*v8.Array {
        const array = v8.v8_Array_NewInContext(self.context, @intCast(items.len)) orelse
            return error.OutOfMemory;
        errdefer v8.v8_Array_Dispose(array);

        for (items, 0..) |item, index| {
            const object = try self.cookieListItem(item);
            defer v8.v8_Object_Dispose(object);
            _ = v8.v8_Array_Set(array, self.context, @intCast(index), @ptrCast(object));
        }
        return array;
    }
};

/// Getter for changed
/// https://cookiestore.spec.whatwg.org/#dom-cookiechangeevent-changed
pub fn get_changed(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternalState(instance) orelse return error.NotImplemented;

    const realm = try Realm.enter();
    defer realm.exit();

    const array = try realm.cookieList(internal.changed.items);
    return runtime.JSValue.fromHandleNonOwning(@ptrCast(array));
}

/// Getter for deleted
/// https://cookiestore.spec.whatwg.org/#dom-cookiechangeevent-deleted
pub fn get_deleted(instance: *runtime.Instance) anyerror!runtime.JSValue {
    const internal = getInternalState(instance) orelse return error.NotImplemented;

    const realm = try Realm.enter();
    defer realm.exit();

    const array = try realm.cookieList(internal.deleted.items);
    return runtime.JSValue.fromHandleNonOwning(@ptrCast(array));
}

// ============================================================================
// Public API for event creation
// ============================================================================

/// Create a CookieChangeEvent from cookie changes
/// This is used by the "fire a change event" algorithm
pub fn createFromChanges(
    allocator: std.mem.Allocator,
    ctx: runtime.Context,
    changed: []const cookiestore.CookieChange,
) !*runtime.Instance {
    const instance = try init(allocator, State, &CookieChangeEvent.vtable, ctx);
    errdefer deinit(instance);

    const internal = getInternalState(instance) orelse return error.NotImplemented;

    // Separate changed and deleted
    for (changed) |change| {
        const item = try CookieListItem.fromCookie(allocator, change.cookie);

        if (change.change_type == .changed) {
            try internal.addChanged(item);
        } else {
            // For deleted, value should be empty per spec
            allocator.free(item.value);
            var deleted_item = item;
            deleted_item.value = try allocator.dupe(u8, "");
            try internal.addDeleted(deleted_item);
        }
    }

    return instance;
}
