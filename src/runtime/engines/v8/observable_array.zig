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
const v8 = @import("ffi.zig");
const Context = runtime.Context;
const JSValue = runtime.JSValue;
const EngineError = runtime.EngineError;
/// The agent records, where each agent's registry lives.
const protocol_agents = @import("protocol_agents.zig");

/// Internal state for an ObservableArray exotic object
/// This is stored in a registry keyed by the Proxy object
pub const ObservableArrayState = struct {
    /// Allocator for memory management
    allocator: std.mem.Allocator,

    /// The backing list (per WebIDL spec [[BackingList]])
    /// Contains the indexed values
    backing_list: std.ArrayList(JSValue),

    /// The V8 target array - string/symbol properties are stored here
    /// Per spec, non-indexed operations delegate to the target
    target: *v8.Array,

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

    pub fn init(allocator: std.mem.Allocator, target: *v8.Array) ObservableArrayState {
        return .{
            .allocator = allocator,
            .backing_list = .empty,
            .target = target,
        };
    }

    pub fn deinit(self: *ObservableArrayState) void {
        self.backing_list.deinit(self.allocator); // Zig 0.15: pass allocator
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
        var states = self.states.keyIterator();
        while (states.next()) |state| {
            if (state.*.proxy) |proxy| v8.v8_Global_ClearWeak(@ptrCast(proxy));
        }
        states = self.states.keyIterator();
        while (states.next()) |state| {
            state.*.deinit();
            state.*.allocator.destroy(state.*);
        }
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

/// V8 weak callback for GC-driven cleanup of ObservableArrayState
/// Called when the V8 Proxy object is garbage collected
fn weakCallback(data: ?*anyopaque, _: usize) callconv(.c) void {
    const state: *ObservableArrayState = @ptrCast(@alignCast(data orelse return));
    if (state.registry) |registry| _ = registry.states.remove(state);
    state.deinit();
    state.allocator.destroy(state);
}

/// Create a new ObservableArray exotic object
///
/// Returns a V8 Proxy object that behaves as an observable array.
/// The proxy has traps for get, set, deleteProperty, ownKeys, etc.
///
/// @param ctx - The runtime context
/// @return JSValue wrapping the Proxy, or error
pub fn create(ctx: Context) !JSValue {
    const allocator = ctx.allocator;

    // Get V8 context - the engine_ctx is the V8 context pointer
    const v8_ctx: *v8.Context = ctx.getEngineContextAs(v8.Context) orelse return error.NoContext;
    const isolate = v8.v8_Isolate_GetCurrent() orelse return error.NoIsolate;

    // Create target array (the actual storage object)
    // Per WebIDL spec: the target MUST be an Array for proper IsArray() checks
    // and to get the correct [[OwnPropertyKeys]] behavior
    const target = v8.v8_Array_New(isolate, 0);
    // Note: Local handles are managed by V8's HandleScope, no explicit release needed

    // Create the internal state
    const state = try allocator.create(ObservableArrayState);
    errdefer allocator.destroy(state);
    state.* = ObservableArrayState.init(allocator, target);

    // Create handler object with our trap functions
    const handler = try createHandler(ctx, state);
    // Note: Local handles are managed by V8's HandleScope, no explicit release needed

    // Create the Proxy - cast Array to Object since Array is a subtype of Object
    const proxy = v8.v8_Proxy_New(v8_ctx, @ptrCast(target), handler) orelse return error.OutOfMemory;

    // Store proxy pointer in state for cleanup
    state.proxy = @ptrCast(proxy);

    // The agent's: its end frees what the collector has not.
    if (protocol_agents.observableArraysOf(isolate)) |registry| {
        try registry.states.put(registry.allocator, state, {});
        state.registry = registry;
    }

    // Set up V8 weak callback for GC-driven cleanup
    // When the Proxy is garbage collected, the weak callback will clean up the state
    v8.v8_Global_SetWeak(
        @ptrCast(proxy),
        @ptrCast(state),
        weakCallback,
    );

    // The proxy's Global (v8_Proxy_New makes one), handed over.
    return JSValue{ .handle = .{ .ptr = @ptrCast(proxy) } };
}

/// The Engine table's `createObservableArray` (WebIDL "create an observable
/// array exotic object" in `realm`). The object is the engine's: the weak
/// callback frees its state when script can no longer reach it, and the
/// agent's end frees what is left (`Registry.destroy`).
pub fn createObservableArray(realm: Context) EngineError!JSValue {
    return create(realm) catch |err| switch (err) {
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

    // Create an External that wraps the state pointer
    // This will be passed as 'data' to each FunctionTemplate
    const state_external = v8.v8_External_New(isolate, state) orelse return error.OutOfMemory;

    // Set up trap functions on the handler
    // Note: Local handles are managed by V8's HandleScope, no explicit release needed.

    // The "get" trap
    const get_name = v8.v8_String_NewFromUtf8(isolate, "get", 3) orelse return error.OutOfMemory;
    const get_fn = v8.v8_FunctionTemplate_GetFunction(
        v8.v8_FunctionTemplate_New(isolate, getTrap, @ptrCast(state_external)) orelse return error.OutOfMemory,
        v8_ctx,
    ) orelse return error.OutOfMemory;
    _ = v8.v8_Object_Set(handler, v8_ctx, @ptrCast(get_name), @ptrCast(get_fn));

    // The "set" trap
    const set_name = v8.v8_String_NewFromUtf8(isolate, "set", 3) orelse return error.OutOfMemory;
    const set_fn = v8.v8_FunctionTemplate_GetFunction(
        v8.v8_FunctionTemplate_New(isolate, setTrap, @ptrCast(state_external)) orelse return error.OutOfMemory,
        v8_ctx,
    ) orelse return error.OutOfMemory;
    _ = v8.v8_Object_Set(handler, v8_ctx, @ptrCast(set_name), @ptrCast(set_fn));

    // The "ownKeys" trap
    const ownKeys_name = v8.v8_String_NewFromUtf8(isolate, "ownKeys", 7) orelse return error.OutOfMemory;
    const ownKeys_fn = v8.v8_FunctionTemplate_GetFunction(
        v8.v8_FunctionTemplate_New(isolate, ownKeysTrap, @ptrCast(state_external)) orelse return error.OutOfMemory,
        v8_ctx,
    ) orelse return error.OutOfMemory;
    _ = v8.v8_Object_Set(handler, v8_ctx, @ptrCast(ownKeys_name), @ptrCast(ownKeys_fn));

    // The "getOwnPropertyDescriptor" trap (required for ownKeys to work)
    const gopd_name = v8.v8_String_NewFromUtf8(isolate, "getOwnPropertyDescriptor", 24) orelse return error.OutOfMemory;
    const gopd_fn = v8.v8_FunctionTemplate_GetFunction(
        v8.v8_FunctionTemplate_New(isolate, getOwnPropertyDescriptorTrap, @ptrCast(state_external)) orelse return error.OutOfMemory,
        v8_ctx,
    ) orelse return error.OutOfMemory;
    _ = v8.v8_Object_Set(handler, v8_ctx, @ptrCast(gopd_name), @ptrCast(gopd_fn));

    // The "deleteProperty" trap
    const delete_name = v8.v8_String_NewFromUtf8(isolate, "deleteProperty", 14) orelse return error.OutOfMemory;
    const delete_fn = v8.v8_FunctionTemplate_GetFunction(
        v8.v8_FunctionTemplate_New(isolate, deletePropertyTrap, @ptrCast(state_external)) orelse return error.OutOfMemory,
        v8_ctx,
    ) orelse return error.OutOfMemory;
    _ = v8.v8_Object_Set(handler, v8_ctx, @ptrCast(delete_name), @ptrCast(delete_fn));

    // The "getPrototypeOf" trap - critical for no-leak test
    // Must return Array.prototype, NOT the internal target
    const gpo_name = v8.v8_String_NewFromUtf8(isolate, "getPrototypeOf", 14) orelse return error.OutOfMemory;
    const gpo_fn = v8.v8_FunctionTemplate_GetFunction(
        v8.v8_FunctionTemplate_New(isolate, getPrototypeOfTrap, @ptrCast(state_external)) orelse return error.OutOfMemory,
        v8_ctx,
    ) orelse return error.OutOfMemory;
    _ = v8.v8_Object_Set(handler, v8_ctx, @ptrCast(gpo_name), @ptrCast(gpo_fn));

    return handler;
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

    const js_value = JSValue{ .handle = .{ .ptr = @ptrCast(value) } };

    if (v8.v8_Value_IsString(prop)) {
        // Step 2: If P is "length", set the length
        if (isLengthKey(prop)) {
            // TODO: Implement set length algorithm
            return returnBoolean(info, isolate, true);
        }

        if (arrayIndexKey(prop)) |index| {
            // Step 3: If P is an array index, set the indexed value
            const old_len = state.backing_list.items.len;

            // Per spec: index > oldLen returns false (can only append at end)
            if (index > old_len) return returnBoolean(info, isolate, false);

            // If replacing existing value
            if (index < old_len) {
                // TODO: Call delete algorithm for old value
                state.backing_list.items[index] = js_value;
            } else {
                // Appending at end (index == old_len)
                state.backing_list.append(state.allocator, js_value) catch return returnBoolean(info, isolate, false);
            }
            value_stored = true;
            // TODO: Call set algorithm
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

    // Set value to undefined (default)
    const undefined_val = v8.v8_Undefined(isolate) orelse return;
    defer v8.v8_Value_Dispose(undefined_val);
    _ = setDescriptorField(isolate, context, desc, "value", undefined_val);
}

/// Trap for delete operator: handler.deleteProperty(target, property)
fn deletePropertyTrap(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    // Return true to indicate successful deletion
    returnBoolean(info, info.getIsolate(), true);
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
