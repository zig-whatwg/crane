//! ObservableArray Exotic Object
//!
//! Implements the observable array exotic object per WebIDL specification.
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
const v8_mod = @import("v8");
const v8 = v8_mod.ffi;
const Context = @import("context.zig").Context;
const JSValue = @import("js_value.zig").JSValue;

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

    /// Callback for when an indexed value is set
    on_set_indexed_value: ?*const fn (index: usize, value: JSValue) void = null,

    /// Callback for when an indexed value is deleted
    on_delete_indexed_value: ?*const fn (index: usize, old_value: JSValue) void = null,

    pub fn init(allocator: std.mem.Allocator, target: *v8.Array) ObservableArrayState {
        return .{
            .allocator = allocator,
            .backing_list = .{}, // Zig 0.15: ArrayList default empty init
            .target = target,
        };
    }

    pub fn deinit(self: *ObservableArrayState) void {
        self.backing_list.deinit(self.allocator); // Zig 0.15: pass allocator
    }
};

/// Registry mapping Proxy objects to their internal state
/// Uses the V8 Object pointer as the key
var state_registry: ?std.AutoHashMap(usize, *ObservableArrayState) = null;

fn getRegistry(allocator: std.mem.Allocator) *std.AutoHashMap(usize, *ObservableArrayState) {
    if (state_registry == null) {
        state_registry = std.AutoHashMap(usize, *ObservableArrayState).init(allocator);
    }
    return &state_registry.?;
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

    // Register the state with the proxy's address
    const registry = getRegistry(allocator);
    try registry.put(@intFromPtr(proxy), state);

    return JSValue{
        .handle = .{
            .ptr = @ptrCast(proxy),
            .needs_disposal = true,
            .handle_scope = .global, // V8 Proxy from v8_Proxy_New is a Global handle
        },
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

/// Helper to extract ObservableArrayState from callback info
fn getStateFromInfo(info: *const v8.FunctionCallbackInfo) ?*ObservableArrayState {
    const data = info.getData();
    // The data is an External wrapping our state pointer
    const state_ptr = v8.v8_External_Value(@ptrCast(data)) orelse return null;
    return @ptrCast(@alignCast(state_ptr));
}

/// Trap for property access: handler.get(target, property, receiver)
/// Per WebIDL spec section 3.10.3
fn getTrap(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const args_count = info.length();
    if (args_count < 3) return;

    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;
    const state = getStateFromInfo(info) orelse {
        const undef = v8.v8_Undefined(isolate) orelse return;
        info.setReturnValue(undef);
        return;
    };

    const target = info.get(0); // O - the target array
    const prop = info.get(1); // P - the property
    // receiver = info.get(2) - not used for simple cases

    const length = state.backing_list.items.len;

    // Step 3: If P is "length", return length
    if (v8.v8_Value_IsString(prop)) {
        const str_len = v8.v8_String_Utf8Length(@ptrCast(prop));
        if (str_len == 6) {
            var buf: [6]u8 = undefined;
            _ = v8.v8_String_WriteUtf8(@ptrCast(prop), &buf, 6);
            if (std.mem.eql(u8, &buf, "length")) {
                const length_value = v8.v8_Number_New(isolate, @floatFromInt(length));
                info.setReturnValue(@ptrCast(length_value));
                return;
            }
        }

        // Check if it's an array index string like "0", "1", etc.
        // Note: v8_String_WriteUtf8 returns count INCLUDING null terminator
        // Use Utf8Length for actual character count (str_len from above)
        var key_buf: [32]u8 = undefined;
        _ = v8.v8_String_WriteUtf8(@ptrCast(prop), &key_buf, 32);
        const key = key_buf[0..@intCast(str_len)];
        if (std.fmt.parseInt(usize, key, 10)) |index| {
            // Step 4: If P is an array index
            if (index >= length) {
                const undef = v8.v8_Undefined(isolate) orelse return;
                info.setReturnValue(undef);
                return;
            }
            const element = state.backing_list.items[index];
            info.setReturnValue(@ptrCast(element.handle.ptr));
            return;
        } else |_| {
            // Not a numeric index - fall through to target lookup
        }
    }

    // Step 5: Return O.[[Get]](P, Receiver) - delegate to target
    const result = v8.v8_Object_Get(@ptrCast(target), context, prop) orelse {
        const undef = v8.v8_Undefined(isolate) orelse return;
        info.setReturnValue(undef);
        return;
    };
    info.setReturnValue(result);
}

/// Trap for property assignment: handler.set(target, property, value, receiver)
/// Per WebIDL spec section 3.10.8
fn setTrap(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const args_count = info.length();
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;

    if (args_count < 4) {
        const false_val = v8.v8_Boolean_New(isolate, false);
        info.setReturnValue(@ptrCast(false_val));
        return;
    }

    const state = getStateFromInfo(info) orelse {
        const false_val = v8.v8_Boolean_New(isolate, false);
        info.setReturnValue(@ptrCast(false_val));
        return;
    };

    const target = info.get(0); // O - the target array
    const prop = info.get(1); // P - the property
    const value = info.get(2); // V - the value
    const receiver = info.get(3); // Receiver

    // Create JSValue wrapper for the value
    const js_value = JSValue{
        .handle = .{
            .ptr = @ptrCast(value),
            .needs_disposal = false, // V8 manages the handle
            .handle_scope = .local,
        },
    };

    if (v8.v8_Value_IsString(prop)) {
        const str_len = v8.v8_String_Utf8Length(@ptrCast(prop));

        // Step 2: If P is "length", set the length
        if (str_len == 6) {
            var buf: [6]u8 = undefined;
            _ = v8.v8_String_WriteUtf8(@ptrCast(prop), &buf, 6);
            if (std.mem.eql(u8, &buf, "length")) {
                // TODO: Implement set length algorithm
                const true_val = v8.v8_Boolean_New(isolate, true);
                info.setReturnValue(@ptrCast(true_val));
                return;
            }
        }

        // Check if it's an array index string like "0", "1", etc.
        // Note: v8_String_WriteUtf8 returns count INCLUDING null terminator
        // Use Utf8Length for actual character count
        var key_buf: [32]u8 = undefined;
        _ = v8.v8_String_WriteUtf8(@ptrCast(prop), &key_buf, 32);
        const key = key_buf[0..@intCast(str_len)];

        if (std.fmt.parseInt(usize, key, 10)) |index| {
            // Step 3: If P is an array index, set the indexed value
            const old_len = state.backing_list.items.len;

            // Per spec: index > oldLen returns false (can only append at end)
            if (index > old_len) {
                const false_val = v8.v8_Boolean_New(isolate, false);
                info.setReturnValue(@ptrCast(false_val));
                return;
            }

            // If replacing existing value
            if (index < old_len) {
                // TODO: Call delete algorithm for old value
                state.backing_list.items[index] = js_value;
            } else {
                // Appending at end (index == old_len)
                state.backing_list.append(state.allocator, js_value) catch {
                    const false_val = v8.v8_Boolean_New(isolate, false);
                    info.setReturnValue(@ptrCast(false_val));
                    return;
                };
            }
            // TODO: Call set algorithm

            const true_val = v8.v8_Boolean_New(isolate, true);
            info.setReturnValue(@ptrCast(true_val));
            return;
        } else |_| {
            // Not a numeric index - fall through to target set
        }
    }

    // Step 4: Return O.[[Set]](P, V, Receiver) - delegate to target
    // For non-indexed properties, set on the target array directly
    _ = receiver; // Receiver not used in simple Object_Set
    const result = v8.v8_Object_Set(@ptrCast(target), context, prop, value);
    const result_val = v8.v8_Boolean_New(isolate, result);
    info.setReturnValue(@ptrCast(result_val));
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

    const state = getStateFromInfo(info) orelse {
        const array = v8.v8_Array_New(isolate, 0);
        info.setReturnValue(@ptrCast(array));
        return;
    };

    const target = info.get(0); // O - the target array

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
            const int_val = v8.v8_Integer_New(isolate, @intCast(i));
            const str_val = v8.v8_Value_ToString(@ptrCast(int_val), context) orelse continue;
            _ = v8.v8_Array_Set(result, context, idx, @ptrCast(str_val));
            idx += 1;
        }
        const length_str = v8.v8_String_NewFromUtf8(isolate, "length", 6) orelse return;
        _ = v8.v8_Array_Set(result, context, idx, @ptrCast(length_str));
        info.setReturnValue(@ptrCast(result));
        return;
    };

    const target_keys_len = v8.v8_Array_Length(target_keys);

    // Create result array - start empty and grow dynamically
    // We can't pre-calculate size because we filter out duplicates from target_keys
    const result = v8.v8_Array_New(isolate, 0);
    var idx: u32 = 0;

    // Steps 4-5: Add indices 0 to length-1 as strings
    // Use V8's own number-to-string conversion for proper string creation
    for (0..length) |i| {
        const int_val = v8.v8_Integer_New(isolate, @intCast(i));
        const str_val = v8.v8_Value_ToString(@ptrCast(int_val), context) orelse continue;
        _ = v8.v8_Array_Set(result, context, idx, @ptrCast(str_val));
        idx += 1;
    }

    // Add "length" - it's non-enumerable on Array but we MUST include it
    const length_str = v8.v8_String_NewFromUtf8(isolate, "length", 6) orelse return;
    _ = v8.v8_Array_Set(result, context, idx, @ptrCast(length_str));
    idx += 1;

    // Step 6: Extend with target's keys, filtering out "length" and array indices
    // (we already added "length" and indices from backing_list)
    for (0..target_keys_len) |i| {
        const key = v8.v8_Array_Get(context, target_keys, @intCast(i)) orelse continue;

        // Skip if not a string
        if (!v8.v8_Value_IsString(key)) continue;

        // Get the string value to check
        const key_str: *v8.String = @ptrCast(key);
        const key_len = v8.v8_String_Utf8Length(key_str);

        // Skip "length" (we already added it)
        if (key_len == 6) {
            var buf: [6]u8 = undefined;
            _ = v8.v8_String_WriteUtf8(key_str, &buf, 6);
            if (std.mem.eql(u8, &buf, "length")) continue;
        }

        // Skip array indices (keys that are valid non-negative integers)
        // Array indices are strings like "0", "1", "2", etc.
        if (key_len <= 10) { // Max uint32 is 10 digits
            var buf: [16]u8 = undefined;
            const written = v8.v8_String_WriteUtf8(key_str, &buf, 16);
            // WriteUtf8 returns count INCLUDING null terminator if written
            // Use Utf8Length for actual character count
            const actual_len: usize = @intCast(key_len);
            const key_slice = buf[0..actual_len];
            // Check if it's a numeric string
            if (std.fmt.parseInt(u32, key_slice, 10)) |_| {
                _ = written; // Suppress unused warning
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
        const symbols_len = v8.v8_Array_Length(symbols);
        for (0..symbols_len) |i| {
            const sym = v8.v8_Array_Get(context, symbols, @intCast(i)) orelse continue;
            _ = v8.v8_Array_Set(result, context, idx, sym);
            idx += 1;
        }
    }

    info.setReturnValue(@ptrCast(result));
}

/// Trap for Object.getOwnPropertyDescriptor
/// Required for ownKeys trap to work correctly
fn getOwnPropertyDescriptorTrap(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;

    // Return a descriptor: { value: <value>, writable: true, enumerable: true, configurable: true }
    const desc = v8.v8_Object_New(isolate) orelse return;

    // Set configurable: true (required for ownKeys invariant)
    const configurable_key = v8.v8_String_NewFromUtf8(isolate, "configurable", 12) orelse return;
    const true_val = v8.v8_Boolean_New(isolate, true);
    _ = v8.v8_Object_Set(desc, context, @ptrCast(configurable_key), @ptrCast(true_val));

    // Set enumerable: true
    const enumerable_key = v8.v8_String_NewFromUtf8(isolate, "enumerable", 10) orelse return;
    _ = v8.v8_Object_Set(desc, context, @ptrCast(enumerable_key), @ptrCast(true_val));

    // Set writable: true
    const writable_key = v8.v8_String_NewFromUtf8(isolate, "writable", 8) orelse return;
    _ = v8.v8_Object_Set(desc, context, @ptrCast(writable_key), @ptrCast(true_val));

    // Set value to undefined (default)
    const value_key = v8.v8_String_NewFromUtf8(isolate, "value", 5) orelse return;
    const undefined_val = v8.v8_Undefined(isolate);
    _ = v8.v8_Object_Set(desc, context, @ptrCast(value_key), @ptrCast(undefined_val));

    info.setReturnValue(@ptrCast(desc));
}

/// Trap for delete operator: handler.deleteProperty(target, property)
fn deletePropertyTrap(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    // Return true to indicate successful deletion
    const isolate = info.getIsolate();
    const true_val = v8.v8_Boolean_New(isolate, true);
    info.setReturnValue(@ptrCast(true_val));
}

/// Trap for Object.getPrototypeOf: handler.getPrototypeOf(target)
///
/// CRITICAL: This must return Array.prototype, NOT the Proxy target.
/// This is required to pass the "no leak of internals" test.
fn getPrototypeOfTrap(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;

    // Get Array.prototype
    // Note: Local handles are managed by V8's HandleScope, no explicit release needed.
    const global = v8.v8_Context_Global(context) orelse return;
    const array_str = v8.v8_String_NewFromUtf8(isolate, "Array", 5) orelse return;
    const array_ctor = v8.v8_Object_Get(global, context, @ptrCast(array_str)) orelse return;

    if (!v8.v8_Value_IsFunction(array_ctor)) return;

    const prototype_str = v8.v8_String_NewFromUtf8(isolate, "prototype", 9) orelse return;
    const array_proto = v8.v8_Object_Get(@ptrCast(array_ctor), context, @ptrCast(prototype_str)) orelse return;

    info.setReturnValue(array_proto);
}

/// Get the internal state for an ObservableArray proxy
pub fn getState(proxy: JSValue) ?*ObservableArrayState {
    const handle_ptr = switch (proxy) {
        .handle => |h| h.ptr,
        else => return null,
    };
    const ptr = @intFromPtr(handle_ptr);
    if (state_registry) |*reg| {
        return reg.get(ptr);
    }
    return null;
}

/// Clean up an ObservableArray and its state
pub fn destroy(proxy: JSValue, allocator: std.mem.Allocator) void {
    const handle_ptr = switch (proxy) {
        .handle => |h| h.ptr,
        else => return,
    };
    const ptr = @intFromPtr(handle_ptr);
    if (state_registry) |*reg| {
        if (reg.fetchRemove(ptr)) |entry| {
            entry.value.deinit();
            allocator.destroy(entry.value);
        }
    }
}
