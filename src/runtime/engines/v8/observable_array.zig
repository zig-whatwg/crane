//! ObservableArray Exotic Object - the V8 half
//!
//! Implements the observable array exotic object per WebIDL specification.
//! It is a Proxy with native traps, which is engine machinery, so it lives in
//! the adapter; host code reaches it through the engine protocol's
//! `createObservableArray`.
//! This creates a JavaScript Proxy that wraps an array-like backing store
//! with change observation callbacks.
//!
//! Spec: https://webidl.spec.whatwg.org/#es-observable-array
//!
//! Key behaviors:
//! - ownKeys returns: array indices (ascending) → "length" → string keys (insertion order)
//! - Proxy internals (target, handler) MUST NOT leak to JavaScript
//! - Supports indexed access, length property, and arbitrary string properties
//!
//! The "no leak" requirement means we must use an ECMAScript-side handler object
//! with native callbacks, rather than exposing the C++ Proxy::GetTarget/GetHandler.

const std = @import("std");
const runtime = @import("runtime");
const engine = @import("engine");
const v8 = @import("ffi.zig");
const conversions = @import("conversions.zig");
const Context = runtime.Context;
const JSValue = runtime.JSValue;
const EngineError = runtime.EngineError;
/// The agent records, where each agent's registry lives.
const protocol_agents = @import("protocol_agents.zig");

/// Internal state for an ObservableArray exotic object
/// This is stored in a registry keyed by the Proxy object
const ConvertedValue = union(enum) {
    any,
    instance: *runtime.Instance,
};

pub const ObservableArrayState = struct {
    /// Allocator for memory management
    allocator: std.mem.Allocator,

    /// The backing list (per WebIDL spec [[BackingList]])
    /// Contains the indexed values
    backing_list: std.ArrayList(JSValue),

    /// The V8 Proxy object this state is associated with
    /// Used to clear weak callback during cleanup
    proxy: ?*v8.Object = null,

    /// The agent's registry this state is in (null for an isolate
    /// createAgent did not make, whose states only the collector frees).
    registry: ?*Registry = null,

    /// Callback for when an indexed value is set
    on_set_indexed_value: ?*const fn (index: usize, value: JSValue) void = null,

    /// Callback for when an indexed value is deleted
    on_delete_indexed_value: ?*const fn (index: usize, old_value: JSValue) void = null,

    /// The array's T, and its owner's algorithms (engine.createObservableArray).
    element: engine.ObservableArrayElement = .any,
    hooks: ?*const engine.ObservableArrayHooks = null,
    /// A link to the owner, with its slab generation: no hook runs for an
    /// owner that has been freed.
    owner: ?*runtime.Instance = null,
    owner_generation: u64 = 0,

    /// The target array (string and symbol properties live there) is the
    /// Proxy's: each trap is given it.
    pub fn init(allocator: std.mem.Allocator) ObservableArrayState {
        return .{
            .allocator = allocator,
            .backing_list = .empty,
        };
    }

    /// The backing list's values are the list's own handles: released with
    /// it, and the Proxy's Global (whose disposal ends its weak arm) with
    /// them. V8 API calls: never from a first-pass weak callback.
    fn destroyWithHandles(self: *ObservableArrayState) void {
        for (self.backing_list.items) |value| switch (value) {
            .handle => |h| v8.v8_Value_Dispose(@ptrCast(h.ptr)),
            else => {},
        };
        self.backing_list.deinit(self.allocator); // Zig 0.15: pass allocator
        if (self.proxy) |proxy| v8.v8_Value_Dispose(@ptrCast(proxy));
        self.proxy = null;
        self.allocator.destroy(self);
    }

    fn liveOwner(self: *const ObservableArrayState) ?*runtime.Instance {
        const owner = self.owner orelse return null;
        if (runtime.SlabAllocator.generationOf(owner) != self.owner_generation) return null;
        return owner;
    }

    /// WebIDL "set the indexed value" step 1 for `value`: converted to T -
    /// for an ObservableArray<I>, the platform object; null (a TypeError
    /// pending) when it is not one.
    fn convert(self: *const ObservableArrayState, isolate: *v8.Isolate, value: *v8.Value) ?ConvertedValue {
        switch (self.element) {
            .any => return .any,
            .platform_object => |brand| {
                const instance = conversions.platformObjectOf(value) orelse {
                    conversions.throwTypeError(isolate, "The value is not of the observable array's type");
                    return null;
                };
                if (!brand(instance)) {
                    conversions.throwTypeError(isolate, "The value is not of the observable array's type");
                    return null;
                }
                return .{ .instance = instance };
            },
        }
    }

    /// WebIDL "set the indexed value" steps 2-4 for the converted `value`,
    /// a handle the list owns once stored: the replaced value's delete
    /// steps, the owner's set steps, then the value stored. False, with an
    /// exception pending and nothing stored, when a set step threw.
    fn storeIndexedValue(self: *ObservableArrayState, isolate: *v8.Isolate, index: usize, converted: ConvertedValue, value: *v8.Value) bool {
        if (index < self.backing_list.items.len) self.deleteIndexedValue(index);
        switch (converted) {
            .any => {},
            .instance => |instance| if (self.hooks) |hooks| if (hooks.set_indexed_value) |set| if (self.liveOwner()) |owner| {
                set(owner, index, instance) catch |err| {
                    conversions.throwDOMException(isolate, @errorName(err), "The value cannot be set");
                    return false;
                };
            },
        }
        const stored = JSValue{ .handle = .{ .ptr = @ptrCast(value) } };
        if (index < self.backing_list.items.len) {
            switch (self.backing_list.items[index]) {
                .handle => |h| v8.v8_Value_Dispose(@ptrCast(h.ptr)),
                else => {},
            }
            self.backing_list.items[index] = stored;
        } else {
            self.backing_list.append(self.allocator, stored) catch return false;
        }
        return true;
    }

    /// The owner's `changed` hook, with the list's values now.
    fn notifyChanged(self: *ObservableArrayState) void {
        const hooks = self.hooks orelse return;
        const changed = hooks.changed orelse return;
        const owner = self.liveOwner() orelse return;
        var values: std.ArrayList(*runtime.Instance) = .empty;
        defer values.deinit(self.allocator);
        for (self.backing_list.items) |value| switch (value) {
            .handle => |h| if (conversions.platformObjectOf(@ptrCast(h.ptr))) |instance| values.append(self.allocator, instance) catch return,
            else => {},
        };
        changed(owner, values.items);
    }

    /// WebIDL "delete an indexed value": the owner's delete steps for the
    /// value at `index`.
    fn deleteIndexedValue(self: *ObservableArrayState, index: usize) void {
        const hooks = self.hooks orelse return;
        const delete = hooks.delete_indexed_value orelse return;
        const owner = self.liveOwner() orelse return;
        const value = self.backing_list.items[index];
        const handle = switch (value) {
            .handle => |h| h.ptr,
            else => return,
        };
        const instance = conversions.platformObjectOf(@ptrCast(handle)) orelse return;
        delete(owner, index, instance);
    }

    /// Remove the last value: its delete steps, then its handle.
    fn removeLast(self: *ObservableArrayState) void {
        const last = self.backing_list.items.len - 1;
        self.deleteIndexedValue(last);
        const value = self.backing_list.pop().?;
        switch (value) {
            .handle => |h| v8.v8_Value_Dispose(@ptrCast(h.ptr)),
            else => {},
        }
    }
};

/// One agent's live ObservableArray states (instances B2): kept on its agent
/// record (protocol_agents.observableArraysOf), made by its first array, and
/// freed by its end (`destroy`) - whichever kind of agent it is - before its
/// isolate's last collections. Read and written on the agent's own thread
/// only, where V8 also runs the arrays' weak callbacks: no lock.
///
/// It was one map for the process, under a mutex every thread took - and
/// every collected array's weak callback scanned the whole map, every
/// agent's entries, to find its own; only a thread's host agent's end freed
/// what was left (context_manager.deinit), so a worker agent's arrays waited
/// for the collector.
pub const Registry = struct {
    allocator: std.mem.Allocator,
    states: std.AutoHashMapUnmanaged(*ObservableArrayState, void) = .empty,

    pub fn create(allocator: std.mem.Allocator) !*Registry {
        const self = try allocator.create(Registry);
        self.* = .{ .allocator = allocator };
        return self;
    }

    /// The agent's end: every state still alive is freed, its proxy's weak
    /// handle disarmed first so that no collection reaches a freed state.
    /// The agent's isolate is entered.
    pub fn destroy(self: *Registry) void {
        // Disposing each Proxy's Global ends its arm (no finalizer runs for
        // it later); the backing lists' handles go with their states.
        var states = self.states.keyIterator();
        while (states.next()) |state| state.*.destroyWithHandles();
        self.states.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    /// How many of the agent's arrays are alive.
    pub fn count(self: *const Registry) usize {
        return self.states.count();
    }
};

/// How many ObservableArrays of the agent whose isolate this is are alive;
/// 0 for an isolate createAgent did not make. On the agent's thread.
pub fn liveCount(isolate: *v8.Isolate) usize {
    const registry = protocol_agents.observableArraysOf(isolate) orelse return 0;
    return registry.count();
}

/// The Proxy was collected - V8's first pass, where no V8 API may run
/// (ffi.v8_Global_SetWeakFinalizer): only the registry's entry goes, so the
/// agent's end cannot reach the state as well.
fn unlinkCollected(data: ?*anyopaque, _: usize) callconv(.c) void {
    const state: *ObservableArrayState = @ptrCast(@alignCast(data orelse return));
    if (state.registry) |registry| _ = registry.states.remove(state);
    state.registry = null;
}

/// After that collection (V8's second pass, V8 API allowed): the backing
/// list's handles - strong roots of its values, which would otherwise keep
/// them alive for the isolate's life - the Proxy's Global, and the state go.
fn finalizeCollected(data: ?*anyopaque, _: usize) callconv(.c) void {
    const state: *ObservableArrayState = @ptrCast(@alignCast(data orelse return));
    state.destroyWithHandles();
}

/// Create a new ObservableArray exotic object
///
/// Returns a V8 Proxy object that behaves as an observable array.
/// The proxy has traps for get, set, deleteProperty, ownKeys, etc.
///
/// @param ctx - The runtime context
/// @return JSValue wrapping the Proxy, or error
pub fn create(ctx: Context, options: engine.ObservableArrayOptions) !JSValue {
    const allocator = ctx.allocator;

    // Get V8 context - the engine_ctx is the V8 context pointer
    const v8_ctx: *v8.Context = ctx.getEngineContextAs(v8.Context) orelse return error.NoContext;
    const isolate = v8.v8_Isolate_GetCurrent() orelse return error.NoIsolate;

    // Create target array (the actual storage object)
    // Per WebIDL spec: the target MUST be an Array for proper IsArray() checks
    // and to get the correct [[OwnPropertyKeys]] behavior
    // A Global the wrapper made, released once the Proxy holds the target.
    const target = v8.v8_Array_New(isolate, 0);
    var target_held = true;
    defer if (target_held) v8.v8_Array_Dispose(target);

    // Create the internal state
    const state = try allocator.create(ObservableArrayState);
    errdefer allocator.destroy(state);
    state.* = ObservableArrayState.init(allocator);
    state.element = options.element;
    state.hooks = options.hooks;
    if (options.owner) |owner| {
        state.owner = owner;
        state.owner_generation = runtime.SlabAllocator.generationOf(owner);
    }

    // Create handler object with our trap functions (a Global, released
    // once the Proxy holds it).
    const handler = try createHandler(ctx, state);
    defer v8.v8_Object_Dispose(handler);

    // Create the Proxy - cast Array to Object since Array is a subtype of
    // Object. The Proxy holds its target and handler.
    const proxy = v8.v8_Proxy_New(v8_ctx, @ptrCast(target), handler) orelse return error.OutOfMemory;
    v8.v8_Array_Dispose(target);
    target_held = false;

    // Store proxy pointer in state for cleanup
    state.proxy = @ptrCast(proxy);

    // The agent's: its end frees what the collector has not.
    if (protocol_agents.observableArraysOf(isolate)) |registry| {
        try registry.states.put(registry.allocator, state, {});
        state.registry = registry;
    }

    // Set up V8 weak callback for GC-driven cleanup
    // When the Proxy is garbage collected, the weak callback will clean up the state
    v8.v8_Global_SetWeakFinalizer(@ptrCast(proxy), @ptrCast(state), unlinkCollected, finalizeCollected);

    // The proxy's Global (v8_Proxy_New makes one), handed over.
    return JSValue{ .handle = .{ .ptr = @ptrCast(proxy) } };
}

/// The Engine table's `createObservableArray` (WebIDL "create an observable
/// array exotic object" in `realm`). The object is the engine's: the weak
/// callback frees its state when script can no longer reach it, and the
/// agent's end frees what is left (`Registry.destroy`).
pub fn createObservableArray(realm: Context, options: engine.ObservableArrayOptions) EngineError!JSValue {
    return create(realm, options) catch |err| switch (err) {
        error.OutOfMemory => EngineError.OutOfMemory,
        else => EngineError.OperationFailed,
    };
}

/// Create the handler object with trap functions
/// @param state - The ObservableArrayState to pass to trap callbacks
fn createHandler(ctx: Context, state: *ObservableArrayState) !*v8.Object {
    const v8_ctx: *v8.Context = ctx.getEngineContextAs(v8.Context) orelse return error.NoContext;
    const isolate = v8.v8_Isolate_GetCurrent() orelse return error.NoIsolate;

    const handler = v8.v8_Object_New(isolate) orelse return error.OutOfMemory;
    errdefer v8.v8_Object_Dispose(handler);

    // An External that wraps the state pointer, passed as 'data' to each
    // trap. Every handle made here is a Global the wrapper allocated, owned
    // here (AGENTS.md "The C++ seam"): released once the handler holds what
    // it needs - kept, each array leaked about twenty of them
    // (leaks --atExit, lane style2).
    const state_external = v8.v8_External_New(isolate, state) orelse return error.OutOfMemory;
    defer v8.v8_External_Dispose(state_external);

    const traps = .{
        .{ "get", getTrap },
        .{ "set", setTrap },
        .{ "ownKeys", ownKeysTrap },
        // Required for ownKeys to work.
        .{ "getOwnPropertyDescriptor", getOwnPropertyDescriptorTrap },
        .{ "deleteProperty", deletePropertyTrap },
        // Critical for the no-leak test: Array.prototype, not the target.
        .{ "getPrototypeOf", getPrototypeOfTrap },
    };
    inline for (traps) |trap| {
        try setHandlerTrap(isolate, v8_ctx, handler, trap[0], trap[1], @ptrCast(state_external));
    }
    return handler;
}

/// `handler[name] = <a function calling callback with data>`, releasing
/// every handle it makes.
fn setHandlerTrap(isolate: *v8.Isolate, context: *v8.Context, handler: *v8.Object, comptime name: []const u8, callback: v8.FunctionCallback, data: *v8.Value) !void {
    const key = v8.v8_String_NewFromUtf8(isolate, name.ptr, name.len) orelse return error.OutOfMemory;
    defer v8.v8_String_Dispose(key);
    const template = v8.v8_FunctionTemplate_New(isolate, callback, data) orelse return error.OutOfMemory;
    defer v8.v8_FunctionTemplate_Dispose(template);
    const function = v8.v8_FunctionTemplate_GetFunction(template, context) orelse return error.OutOfMemory;
    defer v8.v8_Function_Dispose(function);
    _ = v8.v8_Object_Set(handler, context, @ptrCast(key), @ptrCast(function));
}

// ============================================================================
// Proxy Trap Implementations
// ============================================================================
//
// These trap functions use V8's FunctionCallbackInfo method syntax:
// - info.length() for argument count
// - info.getIsolate() for isolate
// - info.get(index) for argument access
// - info.setReturnValue(value) for return values
// - info.getData() for the External wrapping our state pointer

/// Helper to extract ObservableArrayState from callback info. The [[data]]
/// handle is owned (`info.getData()` allocates a Global) and released here;
/// the state pointer it wraps is the registry's.
fn getStateFromInfo(info: *const v8.FunctionCallbackInfo) ?*ObservableArrayState {
    const data = info.getData();
    defer v8.v8_Value_Dispose(data);
    // The data is an External wrapping our state pointer
    const state_ptr = v8.v8_External_Value(@ptrCast(data)) orelse return null;
    return @ptrCast(@alignCast(state_ptr));
}

// Every handle a trap is given (`info.get(i)`) or makes is owned, and
// `setReturnValue` copies the result into the call's return slot, so each is
// released before the trap returns - kept, every `sheets.length` read left
// four Globals (lane callleak). A backing-list element set as the result is
// the list's, borrowed, and kept.

/// The trap's result is undefined; no handle is made for it.
fn returnUndefined(info: *const v8.FunctionCallbackInfo) void {
    v8.FunctionCallbackInfo.v8_FunctionCallbackInfo_SetReturnValueGlobal(info, null);
}

/// The trap's result is `value`, which the trap made: set, then released.
fn returnOwned(info: *const v8.FunctionCallbackInfo, value: *v8.Value) void {
    info.setReturnValue(value);
    v8.v8_Value_Dispose(value);
}

fn returnBoolean(info: *const v8.FunctionCallbackInfo, isolate: *v8.Isolate, value: bool) void {
    const result = v8.v8_Boolean_New(isolate, value) orelse return;
    returnOwned(info, result);
}

/// Whether the string key `prop` is "length".
fn isLengthKey(prop: *v8.Value) bool {
    if (v8.v8_String_Utf8Length(@ptrCast(prop)) != 6) return false;
    var buf: [6]u8 = undefined;
    _ = v8.v8_String_WriteUtf8(@ptrCast(prop), &buf, 6);
    return std.mem.eql(u8, &buf, "length");
}

/// The array index the string key `prop` names, if it names one.
fn arrayIndexKey(prop: *v8.Value) ?usize {
    // Note: v8_String_WriteUtf8 returns count INCLUDING null terminator
    // Use Utf8Length for actual character count
    const str_len = v8.v8_String_Utf8Length(@ptrCast(prop));
    if (str_len <= 0 or str_len > 32) return null;
    var key_buf: [32]u8 = undefined;
    _ = v8.v8_String_WriteUtf8(@ptrCast(prop), &key_buf, 32);
    return std.fmt.parseInt(usize, key_buf[0..@intCast(str_len)], 10) catch null;
}

/// Trap for property access: handler.get(target, property, receiver)
/// Per WebIDL spec section 3.10.3
fn getTrap(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const args_count = info.length();
    if (args_count < 3) return;

    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer v8.v8_Context_Dispose(context);
    const state = getStateFromInfo(info) orelse return returnUndefined(info);

    const target = info.get(0); // O - the target array
    defer v8.v8_Value_Dispose(target);
    const prop = info.get(1); // P - the property
    defer v8.v8_Value_Dispose(prop);
    // receiver = info.get(2) - not used for simple cases

    const length = state.backing_list.items.len;

    if (v8.v8_Value_IsString(prop)) {
        // Step 3: If P is "length", return length
        if (isLengthKey(prop)) {
            return returnOwned(info, @ptrCast(v8.v8_Number_New(isolate, @floatFromInt(length))));
        }

        // Check if it's an array index string like "0", "1", etc.
        if (arrayIndexKey(prop)) |index| {
            // Step 4: If P is an array index
            if (index >= length) return returnUndefined(info);
            // The list's own handle, borrowed: setReturnValue copies it.
            const element = state.backing_list.items[index];
            info.setReturnValue(@ptrCast(element.handle.ptr));
            return;
        }
        // Not a numeric index - fall through to target lookup
    }

    // Step 5: Return O.[[Get]](P, Receiver) - delegate to target
    const result = v8.v8_Object_Get(@ptrCast(target), context, prop) orelse return returnUndefined(info);
    returnOwned(info, result);
}

/// Trap for property assignment: handler.set(target, property, value, receiver)
/// Per WebIDL spec section 3.10.8
fn setTrap(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const args_count = info.length();
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer v8.v8_Context_Dispose(context);

    if (args_count < 4) return returnBoolean(info, isolate, false);

    const state = getStateFromInfo(info) orelse return returnBoolean(info, isolate, false);

    const target = info.get(0); // O - the target array
    defer v8.v8_Value_Dispose(target);
    const prop = info.get(1); // P - the property
    defer v8.v8_Value_Dispose(prop);
    // V - the value. The backing list keeps the very handle it stores (it
    // is the list's from then on); on every other path it is released.
    const value = info.get(2);
    var value_stored = false;
    defer if (!value_stored) v8.v8_Value_Dispose(value);
    // The receiver (args[3]) is not used by the simple Object_Set below.

    if (v8.v8_Value_IsString(prop)) {
        // Step 2: If P is "length", set the length
        if (isLengthKey(prop)) {
            // Step 2: "set the length": a new length past the end is
            // refused; otherwise each value from the end down to it is
            // deleted.
            if (!v8.v8_Value_IsNumber(value)) return returnBoolean(info, isolate, false);
            const number = v8.v8_Value_NumberValue(value, context);
            if (!(number >= 0) or number != @floor(number)) return returnBoolean(info, isolate, false);
            const new_len: usize = @intFromFloat(@min(number, 4294967295.0));
            if (new_len > state.backing_list.items.len) return returnBoolean(info, isolate, false);
            if (state.backing_list.items.len > new_len) {
                while (state.backing_list.items.len > new_len) state.removeLast();
                state.notifyChanged();
            }
            return returnBoolean(info, isolate, true);
        }

        if (arrayIndexKey(prop)) |index| {
            // Step 3: If P is an array index, set the indexed value
            const old_len = state.backing_list.items.len;

            // Per spec: index > oldLen returns false (can only append at end)
            if (index > old_len) return returnBoolean(info, isolate, false);

            // "Set the indexed value": convert, then store - a throw leaves
            // the list as it was.
            const converted = state.convert(isolate, value) orelse return;
            if (!state.storeIndexedValue(isolate, index, converted, value)) return;
            value_stored = true;
            state.notifyChanged();
            return returnBoolean(info, isolate, true);
        }
        // Not a numeric index - fall through to target set
    }

    // Step 4: Return O.[[Set]](P, V, Receiver) - delegate to target
    // For non-indexed properties, set on the target array directly
    const result = v8.v8_Object_Set(@ptrCast(target), context, prop, value);
    returnBoolean(info, isolate, result);
}

/// Append the string of `index` to `result` at `idx`, releasing what it made.
fn appendIndexKey(isolate: *v8.Isolate, context: *v8.Context, result: *v8.Array, idx: u32, index: usize) bool {
    const int_val = v8.v8_Integer_New(isolate, @intCast(index));
    defer v8.v8_Value_Dispose(@ptrCast(int_val));
    const str_val = v8.v8_Value_ToString(@ptrCast(int_val), context) orelse return false;
    defer v8.v8_Value_Dispose(@ptrCast(str_val));
    _ = v8.v8_Array_Set(result, context, idx, @ptrCast(str_val));
    return true;
}

/// Append "length" to `result` at `idx`, releasing the string.
fn appendLengthKey(isolate: *v8.Isolate, context: *v8.Context, result: *v8.Array, idx: u32) bool {
    const length_str = v8.v8_String_NewFromUtf8(isolate, "length", 6) orelse return false;
    defer v8.v8_String_Dispose(length_str);
    _ = v8.v8_Array_Set(result, context, idx, @ptrCast(length_str));
    return true;
}

/// Trap for Object.keys/Object.getOwnPropertyNames: handler.ownKeys(target)
/// Per WebIDL spec section 3.10.6
///
/// Returns keys in order: array indices (ascending) → keys from target's [[OwnPropertyKeys]]
fn ownKeysTrap(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const args_count = info.length();
    if (args_count < 1) return;

    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer v8.v8_Context_Dispose(context);

    const state = getStateFromInfo(info) orelse {
        return returnOwned(info, @ptrCast(v8.v8_Array_New(isolate, 0)));
    };

    const target = info.get(0); // O - the target array
    defer v8.v8_Value_Dispose(target);

    // Step 2: Let length be handler.[[BackingList]]'s size
    const length = state.backing_list.items.len;

    // Step 6: Extend keys with O.[[OwnPropertyKeys]]()
    // Note: v8_Object_GetOwnPropertyNames only returns ENUMERABLE properties
    // But we need ALL properties including non-enumerable like "length"
    // Get target's own property keys (enumerable ones - string props set via set trap)
    // Use GetOwnPropertyNamesAsStrings to ensure all keys are strings (required for Proxy ownKeys)
    const target_keys = v8.v8_Object_GetOwnPropertyNamesAsStrings(context, @ptrCast(target)) orelse {
        // If we can't get target keys, at least return indices + "length"
        const result = v8.v8_Array_New(isolate, @intCast(length + 1));
        var idx: u32 = 0;
        for (0..length) |i| {
            if (appendIndexKey(isolate, context, result, idx, i)) idx += 1;
        }
        _ = appendLengthKey(isolate, context, result, idx);
        return returnOwned(info, @ptrCast(result));
    };
    defer v8.v8_Value_Dispose(@ptrCast(target_keys));

    const target_keys_len = v8.v8_Array_Length(target_keys);

    // Create result array - start empty and grow dynamically
    // We can't pre-calculate size because we filter out duplicates from target_keys
    const result = v8.v8_Array_New(isolate, 0);
    defer returnOwned(info, @ptrCast(result));
    var idx: u32 = 0;

    // Steps 4-5: Add indices 0 to length-1 as strings
    // Use V8's own number-to-string conversion for proper string creation
    for (0..length) |i| {
        if (appendIndexKey(isolate, context, result, idx, i)) idx += 1;
    }

    // Add "length" - it's non-enumerable on Array but we MUST include it
    if (!appendLengthKey(isolate, context, result, idx)) return;
    idx += 1;

    // Step 6: Extend with target's keys, filtering out "length" and array indices
    // (we already added "length" and indices from backing_list)
    for (0..target_keys_len) |i| {
        const key = v8.v8_Array_Get(context, target_keys, @intCast(i)) orelse continue;
        defer v8.v8_Value_Dispose(key);

        // Skip if not a string
        if (!v8.v8_Value_IsString(key)) continue;

        // Skip "length" (we already added it)
        if (isLengthKey(key)) continue;

        // Skip array indices (keys that are valid non-negative integers)
        // Array indices are strings like "0", "1", "2", etc.
        const key_len = v8.v8_String_Utf8Length(@ptrCast(key));
        if (key_len > 0 and key_len <= 10) { // Max uint32 is 10 digits
            var buf: [16]u8 = undefined;
            _ = v8.v8_String_WriteUtf8(@ptrCast(key), &buf, 16);
            if (std.fmt.parseInt(u32, buf[0..@intCast(key_len)], 10)) |_| {
                continue; // Skip numeric indices
            } else |_| {
                // Not a numeric string, include it
            }
        }

        _ = v8.v8_Array_Set(result, context, idx, key);
        idx += 1;
    }

    // Step 6 also includes symbols from target
    // Per [[OwnPropertyKeys]], symbols come after strings
    const target_symbols = v8.v8_Object_GetOwnPropertySymbols(context, @ptrCast(target));
    if (target_symbols) |symbols| {
        defer v8.v8_Value_Dispose(@ptrCast(symbols));
        const symbols_len = v8.v8_Array_Length(symbols);
        for (0..symbols_len) |i| {
            const sym = v8.v8_Array_Get(context, symbols, @intCast(i)) orelse continue;
            defer v8.v8_Value_Dispose(sym);
            _ = v8.v8_Array_Set(result, context, idx, sym);
            idx += 1;
        }
    }
}

/// Set `key` (made here, released) to `value` (borrowed) on `desc`.
fn setDescriptorField(isolate: *v8.Isolate, context: *v8.Context, desc: *v8.Object, key: []const u8, value: *v8.Value) bool {
    const key_str = v8.v8_String_NewFromUtf8(isolate, key.ptr, @intCast(key.len)) orelse return false;
    defer v8.v8_String_Dispose(key_str);
    _ = v8.v8_Object_Set(desc, context, @ptrCast(key_str), value);
    return true;
}

/// Trap for Object.getOwnPropertyDescriptor
/// Required for ownKeys trap to work correctly
fn getOwnPropertyDescriptorTrap(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer v8.v8_Context_Dispose(context);

    // Return a descriptor: { value: <value>, writable: true, enumerable: true, configurable: true }
    const desc = v8.v8_Object_New(isolate) orelse return;
    defer returnOwned(info, @ptrCast(desc));

    const true_val = v8.v8_Boolean_New(isolate, true) orelse return;
    defer v8.v8_Value_Dispose(true_val);
    // Set configurable: true (required for ownKeys invariant)
    if (!setDescriptorField(isolate, context, desc, "configurable", true_val)) return;
    // Set enumerable: true
    if (!setDescriptorField(isolate, context, desc, "enumerable", true_val)) return;
    // Set writable: true
    if (!setDescriptorField(isolate, context, desc, "writable", true_val)) return;

    // The value: an index's from the backing list, "length"'s the list's
    // size; anything else reads undefined, as before.
    if (info.length() >= 2) if (getStateFromInfo(info)) |state| {
        const prop = info.get(1);
        defer v8.v8_Value_Dispose(prop);
        if (v8.v8_Value_IsString(prop)) {
            if (arrayIndexKey(prop)) |index| if (index < state.backing_list.items.len) {
                switch (state.backing_list.items[index]) {
                    .handle => |h| _ = setDescriptorField(isolate, context, desc, "value", @ptrCast(h.ptr)),
                    else => {},
                }
                return;
            };
            if (isLengthKey(prop)) {
                const length = v8.v8_Number_New(isolate, @floatFromInt(state.backing_list.items.len));
                defer v8.v8_Value_Dispose(@ptrCast(length));
                _ = setDescriptorField(isolate, context, desc, "value", @ptrCast(length));
                return;
            }
        }
    };
    const undefined_val = v8.v8_Undefined(isolate) orelse return;
    defer v8.v8_Value_Dispose(undefined_val);
    _ = setDescriptorField(isolate, context, desc, "value", undefined_val);
}

/// The state of the observable array whose Proxy `array` is.
fn stateOf(array: JSValue) ?*ObservableArrayState {
    const handle = switch (array) {
        .handle => |h| h.ptr,
        else => return null,
    };
    const isolate = v8.v8_Isolate_GetCurrent() orelse return null;
    const registry = protocol_agents.observableArraysOf(isolate) orelse return null;
    // A holder's handle is a Global of its own for the same Proxy: compared
    // by identity, not by address.
    var it = registry.states.keyIterator();
    while (it.next()) |state| {
        const proxy = state.*.proxy orelse continue;
        if (@intFromPtr(proxy) == @intFromPtr(handle) or v8.v8_Value_StrictEquals(@ptrCast(proxy), @ptrCast(handle))) return state.*;
    }
    return null;
}

/// engine.observableArrayItems: the backing list's platform objects.
pub fn observableArrayItems(array: JSValue, allocator: std.mem.Allocator, out: *std.ArrayList(*runtime.Instance)) EngineError!void {
    const state = stateOf(array) orelse return EngineError.OperationFailed;
    for (state.backing_list.items) |value| switch (value) {
        .handle => |h| if (conversions.platformObjectOf(@ptrCast(h.ptr))) |instance| {
            out.append(allocator, instance) catch return EngineError.OutOfMemory;
        },
        else => {},
    };
}

/// engine.replaceObservableArrayItems: the attribute setter's steps after
/// its sequence conversion.
pub fn replaceObservableArrayItems(array: JSValue, values: []const JSValue) EngineError!void {
    const state = stateOf(array) orelse return EngineError.OperationFailed;
    const isolate = v8.v8_Isolate_GetCurrent() orelse return EngineError.NoEngine;
    defer state.notifyChanged();
    while (state.backing_list.items.len > 0) state.removeLast();
    for (values, 0..) |value, index| {
        const handle = switch (value) {
            .handle => |h| h.ptr,
            else => return EngineError.TypeError,
        };
        const converted = state.convert(isolate, @ptrCast(handle)) orelse return EngineError.ExceptionPending;
        // The list keeps a handle of its own.
        const own = v8.v8_Global_Clone(@ptrCast(handle)) orelse return EngineError.OutOfMemory;
        if (!state.storeIndexedValue(isolate, index, converted, own)) {
            v8.v8_Value_Dispose(own);
            return EngineError.ExceptionPending;
        }
    }
}

/// WebIDL 3.10.5: an array index may be deleted only at the end (the
/// backing list has no holes) - its delete steps run, and the value goes;
/// "length" cannot be deleted; anything else is the target's.
fn deletePropertyTrap(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    if (info.length() < 2) return returnBoolean(info, isolate, false);
    const state = getStateFromInfo(info) orelse return returnBoolean(info, isolate, false);
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer v8.v8_Context_Dispose(context);
    const target = info.get(0);
    defer v8.v8_Value_Dispose(target);
    const prop = info.get(1);
    defer v8.v8_Value_Dispose(prop);
    if (v8.v8_Value_IsString(prop)) {
        if (isLengthKey(prop)) return returnBoolean(info, isolate, false);
        if (arrayIndexKey(prop)) |index| {
            const len = state.backing_list.items.len;
            if (len == 0 or index != len - 1) return returnBoolean(info, isolate, false);
            state.removeLast();
            state.notifyChanged();
            return returnBoolean(info, isolate, true);
        }
    }
    returnBoolean(info, isolate, v8.v8_Object_Delete(@ptrCast(target), context, prop));
}

/// Trap for Object.getPrototypeOf: handler.getPrototypeOf(target)
///
/// CRITICAL: This must return Array.prototype, NOT the Proxy target.
/// This is required to pass the "no leak of internals" test.
fn getPrototypeOfTrap(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;
    defer v8.v8_Context_Dispose(context);

    // Get Array.prototype. Every handle on the way is a Global this trap
    // owns (the old note that they were HandleScope Locals was wrong).
    const global = v8.v8_Context_Global(context) orelse return;
    defer v8.v8_Object_Dispose(global);
    const array_str = v8.v8_String_NewFromUtf8(isolate, "Array", 5) orelse return;
    defer v8.v8_String_Dispose(array_str);
    const array_ctor = v8.v8_Object_Get(global, context, @ptrCast(array_str)) orelse return;
    defer v8.v8_Value_Dispose(array_ctor);

    if (!v8.v8_Value_IsFunction(array_ctor)) return;

    const prototype_str = v8.v8_String_NewFromUtf8(isolate, "prototype", 9) orelse return;
    defer v8.v8_String_Dispose(prototype_str);
    const array_proto = v8.v8_Object_Get(@ptrCast(array_ctor), context, @ptrCast(prototype_str)) orelse return;

    returnOwned(info, array_proto);
}
