//! WindowProperties Exotic Object
//!
//! Per WebIDL §3.7.4, the WindowProperties object is a special "named properties object"
//! inserted into the prototype chain:
//!
//! Window instance → Window.prototype → WindowProperties → EventTarget.prototype → Object.prototype
//!
//! This object has special exotic behavior:
//! - [[SetPrototypeOf]]: Always returns false for any value except current prototype
//! - [[PreventExtensions]]: Always returns false
//! - [[DefineOwnProperty]]: Always returns false
//! - [[Set]]: Always returns false for own properties
//! - [[Delete]]: Always returns false
//! - [[GetOwnProperty]]: Returns named elements (elements with id/name attributes)
//! - [[Get]]: Returns named elements through [[GetOwnProperty]]
//! - [[HasProperty]]: Returns true if named element exists
//! - [[OwnPropertyKeys]]: Returns supported property names + Symbol.toStringTag
//!
//! The WindowProperties object also has @@toStringTag = "WindowProperties" so that
//! Object.prototype.toString.call(windowProperties) returns "[object WindowProperties]".
//!
//! ## Implementation Strategy
//!
//! We implement WindowProperties as a native V8 object with property interceptors.
//! This ensures spec compliance with HTML §7.3.3 and §7.3.4 and resolves Proxy-related
//! issues like cross-realm access failures.
//!
//! ## Named Property Lookup (HTML §7.4.3.3)
//!
//! Delegated to Window implementation which performs the actual DOM lookup.

const std = @import("std");
const v8 = @import("ffi.zig");
const helpers = @import("helpers.zig");
const runtime = @import("runtime");
const WindowImpl = @import("impls").Window;
const context_manager = @import("context_manager.zig");
const conv = @import("conversions.zig");
const template_registry = @import("template_registry.zig");

var template_cache: ?*v8.FunctionTemplate = null;
var template_cache_isolate: ?*v8.Isolate = null;
var template_cache_generation: u64 = 0;

/// Get or create the FunctionTemplate for WindowProperties
pub fn getTemplate(isolate: *v8.Isolate) *v8.FunctionTemplate {
    if (template_cache) |cached| {
        if (template_cache_isolate == isolate and
            template_cache_generation == template_registry.cache_generation)
        {
            return cached;
        }
        // Invalidate stale cache
        template_cache = null;
        template_cache_isolate = null;
    }

    const tpl = v8.v8_FunctionTemplate_New(isolate, null, null).?;
    const name = v8.v8_String_NewFromUtf8(isolate, "WindowProperties", 16);
    v8.v8_FunctionTemplate_SetClassName(tpl, name.?);

    // NOTE: We do NOT use v8_FunctionTemplate_Inherit here because that would
    // cause EventTarget's prototype methods to appear as own properties on
    // WindowProperties instances. Per WebIDL §3.7.4, WindowProperties should
    // only have named properties as own properties. The prototype chain is
    // set up manually in insertIntoPrototypeChain() to properly link to
    // EventTarget.prototype without inheriting its methods as own properties.

    const instance_tpl = v8.v8_FunctionTemplate_InstanceTemplate(tpl);

    // Reserve internal field to store the associated Window instance
    // This allows named property lookups to find the correct Window regardless of
    // which context is calling (important for cross-window access like iframe.wp.propName)
    v8.v8_ObjectTemplate_SetInternalFieldCount(instance_tpl, 1);

    // Register native property interceptors
    v8.v8_ObjectTemplate_SetNamedPropertyHandlerFull(
        instance_tpl,
        namedPropertyGetter,
        namedPropertySetter,
        namedPropertyQuery,
        namedPropertyDeleter,
        namedPropertyEnumerator,
        namedPropertyDescriptor,
        .kOnlyInterceptStrings,
    );

    // Mark WindowProperties instances as having immutable [[Prototype]]
    // Per WebIDL §3.7.4, the named properties object's prototype is immutable
    v8.v8_ObjectTemplate_SetImmutableProto(instance_tpl);

    const proto_tmpl = v8.v8_FunctionTemplate_PrototypeTemplate(tpl);
    // Mark WindowProperties.prototype as immutable per WebIDL §3.7.4
    v8.v8_ObjectTemplate_SetImmutableProto(proto_tmpl);

    template_cache = tpl;
    template_cache_isolate = isolate;
    template_cache_generation = template_registry.cache_generation;
    return tpl;
}

/// Create the WindowProperties exotic object
/// The window_instance parameter is stored in an internal field so property lookups
/// can find the correct Window even when accessed from a different context (e.g., parent accessing iframe's wp).
pub fn create(
    isolate: *v8.Isolate,
    context: *v8.Context,
    event_target_prototype: *v8.Object,
    window_instance: ?*runtime.Instance,
) ?*v8.Object {
    _ = event_target_prototype;

    const tpl = getTemplate(isolate);
    const instance_tpl = v8.v8_FunctionTemplate_InstanceTemplate(tpl);
    const instance = v8.v8_ObjectTemplate_NewInstance(instance_tpl, context) orelse return null;

    // Store the Window instance in internal field 0
    // This allows named property lookups to find the correct Window
    if (window_instance) |win| {
        v8.v8_Object_SetAlignedPointerInInternalField(instance, 0, @ptrCast(win));
    }

    // Set Symbol.toStringTag per WebIDL §3.7.4
    if (v8.v8_Symbol_GetToStringTag(isolate)) |tag_symbol| {
        const tag_val = v8.v8_String_NewFromUtf8(isolate, "WindowProperties", 16);
        _ = v8.v8_Object_DefineProperty(instance, context, @ptrCast(tag_symbol), @ptrCast(tag_val), false, false, true);
    }

    return instance;
}

/// Insert WindowProperties into the prototype chain for a global Window
///
/// Per WebIDL spec, for interfaces with [Global] extended attribute that support
/// named properties, the prototype chain must be:
///   global → Window.prototype → WindowProperties → EventTarget.prototype → Object.prototype
///
/// This function manually inserts a WindowProperties instance into the chain
/// since SetPrototypeProviderTemplate may not work as expected for all cases.
///
/// The window_instance parameter is the Window instance to associate with this WindowProperties.
/// If null, it will attempt to get the Window from the global's internal field 0.
pub fn insertIntoPrototypeChain(
    isolate: *v8.Isolate,
    context: *v8.Context,
    window_instance_opt: ?*runtime.Instance,
) bool {
    // Get Window.prototype from the chain
    const global = v8.v8_Context_Global(context) orelse return false;
    const window_key = v8.v8_String_NewFromUtf8(isolate, "Window", 6) orelse return false;
    const window_ctor_val = v8.v8_Object_Get(global, context, @ptrCast(window_key)) orelse return false;
    const window_ctor: *v8.Object = helpers.asObject(window_ctor_val) orelse return false;

    const proto_key = v8.v8_String_NewFromUtf8(isolate, "prototype", 9) orelse return false;
    const window_proto_val = v8.v8_Object_Get(window_ctor, context, @ptrCast(proto_key)) orelse return false;
    const window_proto = helpers.asObject(window_proto_val) orelse return false;

    // Get EventTarget.prototype (current prototype of Window.prototype)
    const current_proto_val = v8.v8_Object_GetPrototype(window_proto) orelse return false;
    const event_target_proto = helpers.asObject(current_proto_val) orelse return false;

    // Use provided window_instance, or try to get from global's internal field
    const window_instance: ?*runtime.Instance = window_instance_opt orelse blk: {
        const window_ptr = v8.v8_Object_GetAlignedPointerFromInternalField(global, 0);
        break :blk if (window_ptr) |ptr| @ptrCast(@alignCast(ptr)) else null;
    };

    // Create a new WindowProperties instance with the Window reference
    const wp = create(isolate, context, event_target_proto, window_instance) orelse return false;

    // Set WindowProperties's prototype to EventTarget.prototype
    _ = v8.v8_Object_SetPrototype(wp, context, @ptrCast(event_target_proto));

    // Insert WindowProperties between Window.prototype and EventTarget.prototype
    // Window.prototype.__proto__ = WindowProperties
    _ = v8.v8_Object_SetPrototype(window_proto, context, @ptrCast(wp));

    return true;
}

// ============================================================================
// Named Property Handler Callbacks
// ============================================================================

/// Get Window instance from the WindowProperties object's internal field
/// Each WindowProperties instance stores a reference to its associated Window,
/// allowing correct lookups even when accessed from a different context (e.g., parent accessing iframe's wp).
fn getWindowInstanceFromHolder(info: *const v8.PropertyCallbackInfo) ?*runtime.Instance {
    // Get the Window from the holder's internal field (set during WindowProperties creation)
    const holder = info.getHolder() orelse {
        // Fallback: try current context's global (for backwards compatibility)
        const isolate = info.getIsolate();
        const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return null;
        const global = v8.v8_Context_Global(context) orelse return null;
        const global_ptr = v8.v8_Object_GetAlignedPointerFromInternalField(global, 0) orelse return null;
        return @ptrCast(@alignCast(global_ptr));
    };
    const ptr = v8.v8_Object_GetAlignedPointerFromInternalField(holder, 0) orelse {
        // Fallback: try current context's global (for backwards compatibility)
        const isolate = info.getIsolate();
        const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return null;
        const global = v8.v8_Context_Global(context) orelse return null;
        const global_ptr = v8.v8_Object_GetAlignedPointerFromInternalField(global, 0) orelse return null;
        return @ptrCast(@alignCast(global_ptr));
    };
    return @ptrCast(@alignCast(ptr));
}

/// Get the current context for WindowProperties operations
fn getContextFromHolder(info: *const v8.PropertyCallbackInfo) ?*v8.Context {
    const isolate = info.getIsolate();
    return v8.v8_Isolate_GetCurrentContext(isolate);
}

/// Convert V8 Name to native string
fn nameToNative(_: *v8.Isolate, name: *v8.Name, buf: []u8) ?[]const u8 {
    if (!v8.v8_Name_IsString(name)) return null;
    const string = @as(*v8.String, @ptrCast(name));
    const len = v8.v8_String_WriteUtf8_Raw(string, buf.ptr, @intCast(buf.len));
    if (len < 0) return null;
    return buf[0..@intCast(len)];
}

/// Named property getter - [[Get]] for WindowProperties
fn namedPropertyGetter(
    property: *v8.Name,
    info: *const v8.PropertyCallbackInfo,
) callconv(.c) v8.Intercepted {
    const isolate = info.getIsolate();
    const window = getWindowInstanceFromHolder(info) orelse return .kNo;
    const context = getContextFromHolder(info) orelse return .kNo;

    var name_buf: [256]u8 = undefined;
    const name = nameToNative(isolate, property, &name_buf) orelse return .kNo;

    const result = WindowImpl.getNamedProperty(window, name) catch return .kNo;
    if (result) |js_val| {
        const value = conv.toV8Value(runtime.JSValue, isolate, context, js_val) catch return .kNo;
        info.setReturnValue(value);
        return .kYes;
    }

    return .kNo;
}

/// Named property setter - [[Set]] for WindowProperties
/// Per WebIDL §3.7.4: [[Set]] on WindowProperties always throws TypeError
fn namedPropertySetter(
    property: *v8.Name,
    _: *v8.Value,
    info: *const v8.PropertyCallbackInfo,
) callconv(.c) v8.Intercepted {
    const isolate = info.getIsolate();
    const window = getWindowInstanceFromHolder(info) orelse return .kNo;

    var name_buf: [256]u8 = undefined;
    const name = nameToNative(isolate, property, &name_buf) orelse return .kNo;

    // Only intercept if this is a named property
    if (WindowImpl.hasNamedProperty(window, name)) {
        // Throw TypeError per WebIDL §3.7.4
        conv.throwTypeError(isolate, "Cannot set property on WindowProperties");
        return .kYes;
    }

    return .kNo;
}

/// Named property query - [[HasProperty]] for WindowProperties
fn namedPropertyQuery(
    property: *v8.Name,
    info: *const v8.PropertyCallbackInfo,
) callconv(.c) v8.Intercepted {
    const isolate = info.getIsolate();
    const window = getWindowInstanceFromHolder(info) orelse return .kNo;

    var name_buf: [256]u8 = undefined;
    const name = nameToNative(isolate, property, &name_buf) orelse return .kNo;

    if (WindowImpl.hasNamedProperty(window, name)) {
        info.setReturnValue(@ptrCast(v8.v8_Integer_New(isolate, 2))); // DontEnum
        return .kYes;
    }
    return .kNo;
}

/// Named property deleter - [[Delete]] for WindowProperties
/// Per WebIDL §3.7.4: [[Delete]] on WindowProperties always throws TypeError
fn namedPropertyDeleter(
    property: *v8.Name,
    info: *const v8.PropertyCallbackInfo,
) callconv(.c) v8.Intercepted {
    const isolate = info.getIsolate();
    const window = getWindowInstanceFromHolder(info) orelse return .kNo;

    var name_buf: [256]u8 = undefined;
    const name = nameToNative(isolate, property, &name_buf) orelse return .kNo;

    // Only intercept if this is a named property
    if (WindowImpl.hasNamedProperty(window, name)) {
        // Throw TypeError per WebIDL §3.7.4
        conv.throwTypeError(isolate, "Cannot delete property on WindowProperties");
        return .kYes;
    }

    return .kNo;
}

/// Named property enumerator - [[OwnPropertyKeys]] for WindowProperties
fn namedPropertyEnumerator(
    info: *const v8.PropertyCallbackInfo,
) callconv(.c) void {
    const isolate = info.getIsolate();
    const window = getWindowInstanceFromHolder(info) orelse return;
    const context = getContextFromHolder(info) orelse return;

    const runtime_ctx = context_manager.get(context) orelse return;
    const allocator = runtime_ctx.getAllocator();

    const names = WindowImpl.getSupportedPropertyNames(window, allocator) catch return;
    defer {
        for (names) |*name| name.deinit(allocator);
        allocator.free(names);
    }

    const arr = v8.v8_Array_New(isolate, @intCast(names.len));
    for (names, 0..) |name, i| {
        const s = name.asSlice();
        const v8_str = v8.v8_String_NewFromUtf8(isolate, s.ptr, @intCast(s.len));
        _ = v8.v8_Array_Set(arr, context, @intCast(i), @ptrCast(v8_str));
    }

    info.setReturnValue(@ptrCast(arr));
}

/// Named property descriptor callback
fn namedPropertyDescriptor(
    property: *v8.Name,
    info: *const v8.PropertyCallbackInfo,
) callconv(.c) v8.Intercepted {
    const isolate = info.getIsolate();
    const window = getWindowInstanceFromHolder(info) orelse return .kNo;
    const context = getContextFromHolder(info) orelse return .kNo;

    var name_buf: [256]u8 = undefined;
    const name = nameToNative(isolate, property, &name_buf) orelse return .kNo;

    const result = WindowImpl.getNamedProperty(window, name) catch return .kNo;
    if (result) |js_val| {
        const val = conv.toV8Value(runtime.JSValue, isolate, context, js_val) catch return .kNo;
        const desc = v8.v8_Object_New(isolate) orelse return .kNo;
        _ = v8.v8_Object_Set(desc, context, @ptrCast(v8.v8_String_NewFromUtf8(isolate, "value", 5)), val);
        _ = v8.v8_Object_Set(desc, context, @ptrCast(v8.v8_String_NewFromUtf8(isolate, "writable", 8)), @ptrCast(v8.v8_Boolean_New(isolate, true)));
        _ = v8.v8_Object_Set(desc, context, @ptrCast(v8.v8_String_NewFromUtf8(isolate, "enumerable", 10)), @ptrCast(v8.v8_Boolean_New(isolate, false)));
        _ = v8.v8_Object_Set(desc, context, @ptrCast(v8.v8_String_NewFromUtf8(isolate, "configurable", 12)), @ptrCast(v8.v8_Boolean_New(isolate, true)));
        info.setReturnValue(@ptrCast(desc));
        return .kYes;
    }
    return .kNo;
}

const testing = std.testing;
test "WindowProperties module compiles" {
    testing.refAllDecls(@This());
}
