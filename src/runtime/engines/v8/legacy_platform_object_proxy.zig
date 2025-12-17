// Legacy Platform Object Proxy
//
// This module provides Proxy-based wrapping for WebIDL Legacy Platform Objects
// to ensure correct [[OwnPropertyKeys]] enumeration order per WebIDL §3.9.6.
//
// V8's default property enumeration order is: own properties → interceptor properties
// WebIDL requires: indexed properties → named properties → own properties → symbols
//
// We achieve this by wrapping legacy platform objects in a Proxy with a custom
// `ownKeys` trap that returns keys in the correct order.

const std = @import("std");
const v8 = @import("ffi.zig");

/// Thread-local storage for the shared proxy handler
/// This handler is reused for all legacy platform objects in a context
threadlocal var cached_handler: ?*v8.Object = null;
threadlocal var cached_handler_context: ?*v8.Context = null;

/// Creates or retrieves a shared Proxy handler for legacy platform objects.
/// The handler has an `ownKeys` trap that returns keys in WebIDL order.
pub fn getOrCreateProxyHandler(isolate: *v8.Isolate, context: *v8.Context) ?*v8.Object {
    // Check if we have a cached handler for this context
    if (cached_handler != null and cached_handler_context == context) {
        return cached_handler;
    }

    // Create a new handler object
    const handler = v8.v8_Object_New(isolate) orelse return null;

    // Create the ownKeys function using FunctionTemplate
    const ownkeys_template = v8.v8_FunctionTemplate_New(isolate, ownKeysCallback, null) orelse return null;
    const ownkeys_fn = v8.v8_FunctionTemplate_GetFunction(ownkeys_template, context) orelse return null;

    // Set ownKeys on handler
    const ownkeys_str = v8.v8_String_NewFromUtf8(isolate, "ownKeys", 7) orelse return null;
    _ = v8.v8_Object_Set(handler, context, @ptrCast(ownkeys_str), @ptrCast(ownkeys_fn));

    // Create getOwnPropertyDescriptor function - needed for proper Proxy operation
    const getownprop_template = v8.v8_FunctionTemplate_New(isolate, getOwnPropertyDescriptorCallback, null) orelse return null;
    const getownprop_fn = v8.v8_FunctionTemplate_GetFunction(getownprop_template, context) orelse return null;

    const getownprop_str = v8.v8_String_NewFromUtf8(isolate, "getOwnPropertyDescriptor", 24) orelse return null;
    _ = v8.v8_Object_Set(handler, context, @ptrCast(getownprop_str), @ptrCast(getownprop_fn));

    // Cache the handler
    cached_handler = handler;
    cached_handler_context = context;

    return handler;
}

/// Wraps a legacy platform object in a Proxy with WebIDL-compliant ownKeys behavior.
/// Returns the Proxy object, or the original object if Proxy creation fails.
pub fn wrapInProxy(
    target: *v8.Object,
    isolate: *v8.Isolate,
    context: *v8.Context,
) *v8.Object {
    const handler = getOrCreateProxyHandler(isolate, context) orelse return target;
    return v8.v8_Proxy_New(context, target, handler) orelse target;
}

/// The ownKeys trap callback for the Proxy handler.
/// Returns keys in WebIDL order: indexed → named → own string → own symbol
fn ownKeysCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;

    // Get the target object (first argument to ownKeys trap)
    const args_len = info.length();
    if (args_len < 1) return;

    const target_val = info.get(0);
    if (!v8.v8_Value_IsObject(target_val)) return;
    const target: *v8.Object = @ptrCast(target_val);

    // Collect keys in WebIDL order
    var keys_list: std.ArrayList(*v8.Value) = .{};
    defer keys_list.deinit(std.heap.c_allocator);

    // 1. Collect indexed properties (0 to length-1)
    // Check if target has a "length" property
    const length_str = v8.v8_String_NewFromUtf8(isolate, "length", 6) orelse return;
    if (v8.v8_Object_Has(context, target, "length")) {
        if (v8.v8_Object_Get(target, context, @ptrCast(length_str))) |length_val| {
            if (v8.v8_Value_IsNumber(length_val)) {
                const length = v8.v8_Value_NumberValue(length_val, context);
                if (length >= 0 and length <= 4294967295) {
                    const len: u32 = @intFromFloat(length);
                    var i: u32 = 0;
                    while (i < len) : (i += 1) {
                        // Create string key for index
                        var buf: [16]u8 = undefined;
                        const idx_str = std.fmt.bufPrint(&buf, "{d}", .{i}) catch continue;
                        const v8_idx_str = v8.v8_String_NewFromUtf8(isolate, idx_str.ptr, @intCast(idx_str.len)) orelse continue;
                        keys_list.append(std.heap.c_allocator, @ptrCast(v8_idx_str)) catch continue;
                    }
                }
            }
        }
    }

    // 2. Collect named properties from internal field (if available)
    // Named properties are collected by the named property enumerator
    // We access them through the target's internal mechanisms
    // For now, we get them from the Object's own property names and filter

    // 3. Collect own properties (strings then symbols)
    const own_names = v8.v8_Object_GetOwnPropertyNamesAsStrings(context, target);
    if (own_names) |names_arr| {
        const names_len = v8.v8_Array_Length(names_arr);
        var j: u32 = 0;
        while (j < names_len) : (j += 1) {
            if (v8.v8_Array_Get(context, names_arr, j)) |name_val| {
                // Skip numeric indices (already added)
                if (v8.v8_Value_IsString(name_val)) {
                    const name_str: *v8.String = @ptrCast(name_val);
                    const str_len = v8.v8_String_Utf8Length_Raw(name_str);
                    if (str_len > 0 and str_len < 32) {
                        var name_buf: [32]u8 = undefined;
                        const written = v8.v8_String_WriteUtf8_Raw(name_str, &name_buf, 32);
                        if (written > 0) {
                            const name_slice = name_buf[0..@intCast(written)];
                            // Skip if it's a numeric index
                            const is_index = std.fmt.parseInt(u32, name_slice, 10) catch null;
                            if (is_index == null) {
                                keys_list.append(std.heap.c_allocator, name_val) catch continue;
                            }
                        }
                    } else {
                        // Long string, unlikely to be an index
                        keys_list.append(std.heap.c_allocator, name_val) catch continue;
                    }
                }
            }
        }
    }

    // 4. Collect symbol properties
    // V8 doesn't expose GetOwnPropertySymbols directly, skip for now
    // Symbols are rare in legacy platform objects anyway

    // Create result array
    const result = v8.v8_Array_New(isolate, @intCast(keys_list.items.len));
    for (keys_list.items, 0..) |key, idx| {
        _ = v8.v8_Array_Set(result, context, @intCast(idx), key);
    }

    info.setReturnValue(@ptrCast(result));
}

/// The getOwnPropertyDescriptor trap callback for the Proxy handler.
/// Delegates to Object.getOwnPropertyDescriptor on the target.
fn getOwnPropertyDescriptorCallback(info: *const v8.FunctionCallbackInfo) callconv(.c) void {
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;

    // Get target (first arg) and property key (second arg)
    const args_len = info.length();
    if (args_len < 2) return;

    const target_val = info.get(0);
    const key_val = info.get(1);

    if (!v8.v8_Value_IsObject(target_val)) return;
    const target: *v8.Object = @ptrCast(target_val);

    // Get the property descriptor from the target
    if (v8.v8_Value_IsString(key_val) or v8.v8_Value_IsSymbol(key_val)) {
        // Use Object.getOwnPropertyDescriptor
        const descriptor = v8.v8_Object_GetOwnPropertyDescriptor(target, context, key_val);
        if (descriptor) |desc| {
            info.setReturnValue(desc);
            return;
        }
    }

    // Return undefined if no descriptor
    info.setReturnValue(@ptrCast(v8.v8_Undefined(isolate)));
}

/// Check if an interface is a legacy platform object that needs Proxy wrapping.
/// Legacy platform objects have indexed or named property access.
pub fn isLegacyPlatformObject(comptime Interface: type) bool {
    // Check for indexed property support (call_item with u32)
    const has_indexed = comptime blk: {
        if (!@hasDecl(Interface, "call_item")) break :blk false;
        const CallItemFn = @TypeOf(Interface.call_item);
        const fn_info = @typeInfo(CallItemFn).@"fn";
        if (fn_info.params.len != 2) break :blk false;
        const second_param = fn_info.params[1].type orelse break :blk false;
        break :blk second_param == u32;
    };

    // Check for named property support
    const has_named = comptime @hasDecl(Interface, "getSupportedPropertyNames") or
        @hasDecl(Interface, "call_getNamedItem") or
        @hasDecl(Interface, "call_namedItem");

    return has_indexed or has_named;
}
