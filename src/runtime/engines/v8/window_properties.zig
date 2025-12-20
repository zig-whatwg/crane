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

    // Set up inheritance: WindowProperties inherits from EventTarget
    // This ensures WindowProperties instance's [[Prototype]] chain includes EventTarget.prototype
    const interface_bindings = @import("interface_bindings.zig");
    const event_target_tpl = interface_bindings.EventTarget.createTemplate(isolate);
    v8.v8_FunctionTemplate_Inherit(tpl, event_target_tpl);

    const instance_tpl = v8.v8_FunctionTemplate_InstanceTemplate(tpl);

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
pub fn create(
    isolate: *v8.Isolate,
    context: *v8.Context,
    event_target_prototype: *v8.Object,
) ?*v8.Object {
    _ = event_target_prototype;

    const tpl = getTemplate(isolate);
    const instance_tpl = v8.v8_FunctionTemplate_InstanceTemplate(tpl);
    const instance = v8.v8_ObjectTemplate_NewInstance(instance_tpl, context) orelse return null;

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
pub fn insertIntoPrototypeChain(
    isolate: *v8.Isolate,
    context: *v8.Context,
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

    // Create a new WindowProperties instance
    const wp = create(isolate, context, event_target_proto) orelse return false;

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

/// Get Window instance from the current context
/// With SetPrototypeProviderTemplate, WindowProperties is shared across all Window instances.
/// We use the current context (not the holder's creation context) to get the correct Window.
fn getWindowInstanceFromHolder(info: *const v8.PropertyCallbackInfo) ?*runtime.Instance {
    // Use the current context, not the holder's creation context.
    // With SetPrototypeProviderTemplate, the holder is shared across all contexts,
    // so GetCreationContext would return the first context where the template was used.
    const isolate = info.getIsolate();
    const context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return null;

    // Get the Window from that context's global
    const global = v8.v8_Context_Global(context) orelse return null;
    const ptr = v8.v8_Object_GetAlignedPointerFromInternalField(global, 0) orelse return null;
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
fn namedPropertySetter(
    _: *v8.Name,
    _: *v8.Value,
    info: *const v8.PropertyCallbackInfo,
) callconv(.c) v8.Intercepted {
    // Always return false - [[Set]] always fails on WindowProperties per WebIDL §3.7.4
    const isolate = info.getIsolate();
    info.setReturnValue(@ptrCast(v8.v8_Boolean_New(isolate, false)));
    return .kYes;
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
fn namedPropertyDeleter(
    _: *v8.Name,
    info: *const v8.PropertyCallbackInfo,
) callconv(.c) v8.Intercepted {
    // Always return false - [[Delete]] always fails on WindowProperties
    const isolate = info.getIsolate();
    info.setReturnValue(@ptrCast(v8.v8_Boolean_New(isolate, false)));
    return .kYes;
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
