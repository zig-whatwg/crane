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
    defer v8.v8_ObjectTemplate_Dispose(instance_tpl);

    // Reserve internal field to store the associated Window instance
    // This allows named property lookups to find the correct Window regardless of
    // which context is calling (important for cross-window access like iframe.wp.propName)
    v8.v8_ObjectTemplate_SetInternalFieldCount(instance_tpl, 1);

    // Register native property interceptors with definer callback
    // Using SetNamedPropertyHandlerWithDefiner to intercept Object.defineProperty
    // IMPORTANT: Use kNonMasking so named properties don't shadow built-in Window properties
    // This matches Chromium's WindowProperties configuration
    v8.v8_ObjectTemplate_SetNamedPropertyHandlerWithDefiner(
        instance_tpl,
        namedPropertyGetter,
        namedPropertySetter,
        namedPropertyQuery,
        namedPropertyDeleter,
        namedPropertyEnumerator,
        namedPropertyDefiner,
        namedPropertyDescriptor,
        .kNonMaskingAndOnlyInterceptStrings,
    );

    // Mark WindowProperties instances as having immutable [[Prototype]]
    // Per WebIDL §3.7.4, the named properties object's prototype is immutable
    v8.v8_ObjectTemplate_SetImmutableProto(instance_tpl);

    // The template's prototype object is NOT made immutable. It is not the
    // named properties object - the instance above is, and it is immutable -
    // but it is the only link after that instance whose [[Prototype]] can
    // still be set, and insertIntoPrototypeChain points it at
    // EventTarget.prototype. With both immutable, that step was refused
    // silently and `window instanceof EventTarget` was never true.

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
    defer v8.v8_ObjectTemplate_Dispose(instance_tpl);
    const instance = v8.v8_ObjectTemplate_NewInstance(instance_tpl, context) orelse return null;

    // Store the Window instance in internal field 0
    // This allows named property lookups to find the correct Window
    if (window_instance) |win| {
        v8.v8_Object_SetAlignedPointerInInternalField(instance, 0, @ptrCast(win));
    }

    // Set Symbol.toStringTag per WebIDL §3.7.4
    if (v8.v8_Symbol_GetToStringTag(isolate)) |tag_symbol| {
        defer v8.v8_Value_Dispose(@ptrCast(tag_symbol));
        const tag_val = v8.v8_String_NewFromUtf8(isolate, "WindowProperties", 16);
        defer if (tag_val) |t| v8.v8_String_Dispose(t);
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
    // Get Window.prototype from the chain. Every handle below is owned and
    // released on the way out: each points into `context`, and one leaked per
    // context kept every page and frame alive.
    const global = v8.v8_Context_Global(context) orelse return false;
    defer v8.v8_Object_Dispose(global);
    const window_key = v8.v8_String_NewFromUtf8(isolate, "Window", 6) orelse return false;
    defer v8.v8_String_Dispose(window_key);
    const window_ctor_val = v8.v8_Object_Get(global, context, @ptrCast(window_key)) orelse return false;
    defer v8.v8_Value_Dispose(window_ctor_val);
    const window_ctor: *v8.Object = helpers.asObject(window_ctor_val) orelse return false;

    const proto_key = v8.v8_String_NewFromUtf8(isolate, "prototype", 9) orelse return false;
    defer v8.v8_String_Dispose(proto_key);
    const window_proto_val = v8.v8_Object_Get(window_ctor, context, @ptrCast(proto_key)) orelse return false;
    defer v8.v8_Value_Dispose(window_proto_val);
    const window_proto = helpers.asObject(window_proto_val) orelse return false;

    // WindowProperties' [[Prototype]] is EventTarget.prototype (HTML 7.3.3) - the
    // one the global exposes, which is what `instanceof EventTarget` checks.
    // After a snapshot restore, Window.prototype's own [[Prototype]] is a
    // placeholder object rather than it, so it is only the fallback.
    const et_key = v8.v8_String_NewFromUtf8(isolate, "EventTarget", 11) orelse return false;
    defer v8.v8_String_Dispose(et_key);
    // The prototype handle is taken inside the block and used after it, so its
    // release is recorded here rather than deferred in there.
    var event_target_proto_owned: ?*v8.Value = null;
    defer if (event_target_proto_owned) |v| v8.v8_Value_Dispose(v);
    const event_target_proto: *v8.Object = blk: {
        if (v8.v8_Object_Get(global, context, @ptrCast(et_key))) |et_ctor_val| {
            defer v8.v8_Value_Dispose(et_ctor_val);
            if (helpers.asObject(et_ctor_val)) |et_ctor| {
                if (v8.v8_Object_Get(et_ctor, context, @ptrCast(proto_key))) |et_proto_val| {
                    event_target_proto_owned = et_proto_val;
                    if (helpers.asObject(et_proto_val)) |et_proto| break :blk et_proto;
                }
            }
        }
        if (event_target_proto_owned) |v| v8.v8_Value_Dispose(v);
        event_target_proto_owned = null;
        const current_proto_val = v8.v8_Object_GetPrototype(window_proto) orelse return false;
        event_target_proto_owned = current_proto_val;
        break :blk helpers.asObject(current_proto_val) orelse return false;
    };

    // Use provided window_instance, or try to get from global's internal field
    const window_instance: ?*runtime.Instance = window_instance_opt orelse blk: {
        const window_ptr = v8.v8_Object_GetAlignedPointerFromInternalField(global, 0);
        break :blk if (window_ptr) |ptr| @ptrCast(@alignCast(ptr)) else null;
    };

    // Create a new WindowProperties instance with the Window reference
    const wp = create(isolate, context, event_target_proto, window_instance) orelse return false;
    defer v8.v8_Object_Dispose(wp);

    // WindowProperties -> EventTarget.prototype. The instance's own
    // [[Prototype]] is immutable (WebIDL), so the link goes on the template's
    // prototype object behind it: wp -> wp_proto -> EventTarget.prototype.
    if (v8.v8_Object_GetPrototypeV2(wp)) |wp_proto_val| {
        defer v8.v8_Value_Dispose(wp_proto_val);
        if (helpers.asObject(wp_proto_val)) |wp_proto| {
            _ = v8.v8_Object_SetPrototypeV2(wp_proto, context, @ptrCast(event_target_proto));
        }
    }

    // Insert WindowProperties between Window.prototype and EventTarget.prototype
    // Window.prototype.__proto__ = WindowProperties
    _ = v8.v8_Object_SetPrototype(window_proto, context, @ptrCast(wp));

    linkGlobalToWindowProperties(context, global, window_proto, wp);

    return true;
}

/// Make the global's prototype chain reach WindowProperties, so named access on
/// the Window object (HTML 7.3.3) works: `window.<id>`, a bare `<id>`
/// identifier, `'<id>' in window`, `window.<iframe name>`.
///
/// A [Global] object has an immutable prototype (WebIDL: an immutable
/// prototype exotic object), so its [[Prototype]] is fixed when the context is
/// created. Every context here is restored from a snapshot whose context was
/// made by a plain `Context::New(isolate)` (v8_SnapshotCreator_CreateAndAddContext),
/// so that prototype is V8's placeholder for a template without a constructor:
/// an object holding only `constructor`, directly on Object.prototype. Setting
/// the global's prototype afterwards is refused without an exception
/// (SetPrototypeImpl uses kDontThrow), which is how the SetPrototypeV2 calls in
/// Context.zig and context_manager.createChildContext came to do nothing: the
/// WindowProperties object inserted above was never on the global's chain, in
/// top-level pages or iframes.
///
/// The placeholder is an ordinary object, so it is what gets linked:
///   window -> placeholder -> WindowProperties -> EventTarget.prototype
/// Window.prototype is deliberately NOT spliced in. After a snapshot restore
/// its accessors are mis-wired: setting `self` on the global walked to
/// Window.prototype's `self` accessor, whose setter dispatched to
/// `MethodCallback("call_pauseTransformFeedback")` and threw
/// NotEnoughArguments - every page errored before its first script. The global
/// already carries Window's members as own properties
/// (registerPropertiesAsOwnOnObject / registerMethodsAsOwnOnObject), so nothing
/// is lost by skipping it. Left over: `Object.getPrototypeOf(window) !==
/// Window.prototype`; creating the snapshot's global from Window's
/// InstanceTemplate, once its accessors are sound, is the fix for both.
///
/// Only SetPrototypeV2 and GetPrototypeV2 on the global: the V1 calls are V8's
/// from_javascript=false path, which on a global proxy reaches the hidden
/// JSGlobalObject rather than the [[Prototype]] script sees - and SetPrototypeV2
/// on a JSGlobalObject is a CHECK failure.
fn linkGlobalToWindowProperties(context: *v8.Context, global: *v8.Object, window_proto: *v8.Object, wp: *v8.Object) void {
    // A global created mutable takes Window.prototype directly.
    if (v8.v8_Object_SetPrototypeV2(global, context, @ptrCast(window_proto))) return;
    const placeholder_val = v8.v8_Object_GetPrototypeV2(global) orelse return;
    defer v8.v8_Value_Dispose(placeholder_val);
    if (v8.v8_Value_StrictEquals(placeholder_val, @ptrCast(window_proto))) return;
    const placeholder = helpers.asObject(placeholder_val) orelse return;
    _ = v8.v8_Object_SetPrototypeV2(placeholder, context, @ptrCast(wp));
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
        defer v8.v8_Context_Dispose(context);
        const global = v8.v8_Context_Global(context) orelse return null;
        defer v8.v8_Object_Dispose(global);
        const global_ptr = v8.v8_Object_GetAlignedPointerFromInternalField(global, 0) orelse return null;
        return @ptrCast(@alignCast(global_ptr));
    };
    // Owned, like every handle the FFI returns - and a handle to this object
    // keeps its page alive, so one leaked per named-property lookup kept every
    // page that ever did one.
    defer v8.v8_Object_Dispose(holder);
    // An empty field means the Window was discarded (detachWindow): answer
    // nothing. Falling back to the CURRENT context's window here would answer
    // `iframe.contentWindow.x` from the parent's document.
    const ptr = v8.v8_Object_GetAlignedPointerFromInternalField(holder, 0) orelse return null;
    return @ptrCast(@alignCast(ptr));
}

/// Sever `window_instance` from its context's global and WindowProperties
/// object before the instance is freed.
///
/// Script can outlive a browsing context: `const w = iframe.contentWindow;
/// iframe.remove(); w.length` is ordinary. Both the global and its
/// WindowProperties object hold the Window instance in internal field 0, so
/// once destroyChildContext freed the instance, every later access read freed
/// state - `w.length` panicked in an @intCast of a poisoned child count, and
/// `w.x` walked a freed document. With the fields cleared, a getter finds no
/// instance and throws "Illegal invocation", and named access is undefined.
/// (A discarded window should answer `length` 0 and `closed` true; that needs
/// its state retired rather than freed.)
pub fn detachWindow(context: *v8.Context, window_instance: *runtime.Instance) void {
    const global = v8.v8_Context_Global(context) orelse return;
    defer v8.v8_Object_Dispose(global);
    clearIfWindow(global, window_instance);
    // global -> placeholder -> WindowProperties: a couple of links up. Every
    // handle stays alive until the walk is over - each link is read through
    // the previous one.
    var links: [3]?*v8.Value = .{ null, null, null };
    defer for (links) |link| {
        if (link) |value| v8.v8_Value_Dispose(value);
    };
    var current: *v8.Object = global;
    for (&links) |*slot| {
        const proto_val = v8.v8_Object_GetPrototypeV2(current) orelse return;
        slot.* = proto_val;
        const proto = helpers.asObject(proto_val) orelse return;
        clearIfWindow(proto, window_instance);
        current = proto;
    }
}

fn clearIfWindow(obj: *v8.Object, window_instance: *runtime.Instance) void {
    if (v8.v8_Object_InternalFieldCount(obj) < 1) return;
    const ptr = v8.v8_Object_GetAlignedPointerFromInternalField(obj, 0) orelse return;
    if (@intFromPtr(ptr) != @intFromPtr(window_instance)) return;
    v8.v8_Object_SetAlignedPointerInInternalField(obj, 0, null);
}

/// Get the current context for WindowProperties operations
/// The current context, as an owned `Global<Context>`: the caller disposes
/// it. A leaked one keeps its page's whole native context alive.
fn getContextFromHolder(info: *const v8.PropertyCallbackInfo) ?*v8.Context {
    const isolate = info.getIsolate();
    return v8.v8_Isolate_GetCurrentContext(isolate);
}

/// Convert V8 Name to native string
fn nameToNative(_: *v8.Isolate, name: *v8.Name, buf: []u8) ?[]const u8 {
    return helpers.nameToUtf8(name, buf);
}

/// Named property getter - [[Get]] for WindowProperties
fn namedPropertyGetter(
    property: *v8.Name,
    info: *const v8.PropertyCallbackInfo,
) callconv(.c) v8.Intercepted {
    const isolate = info.getIsolate();
    const window = getWindowInstanceFromHolder(info) orelse return .kNo;

    var name_buf: [256]u8 = undefined;
    const name = nameToNative(isolate, property, &name_buf) orelse return .kNo;

    const result = WindowImpl.getNamedProperty(window, name) catch return .kNo;
    if (result) |js_val| {
        // Acquired only on this path: every early return above would leak it.
        const context = getContextFromHolder(info) orelse return .kNo;
        defer v8.v8_Context_Dispose(context);
        // NOT released: for an element `toV8Value` hands back the wrapper
        // cache's own handle, not a copy - ownership is the conversion's, not
        // the type's - and releasing it freed the cache's entry under it.
        const value = conv.toV8Value(runtime.JSValue, isolate, context, js_val) catch return .kNo;
        info.setReturnValue(value);
        return .kYes;
    }

    return .kNo;
}

/// Named property setter - [[Set]] for WindowProperties
/// Per WebIDL §3.7.4: [[Set]] on WindowProperties ALWAYS throws TypeError
/// This applies to ALL properties, not just named properties
fn namedPropertySetter(
    _: *v8.Name,
    _: *v8.Value,
    info: *const v8.PropertyCallbackInfo,
) callconv(.c) v8.Intercepted {
    const isolate = info.getIsolate();

    // WindowProperties is immutable - [[Set]] always throws TypeError
    conv.throwTypeError(isolate, "Cannot set property on WindowProperties object");
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
        const attributes = v8.v8_Integer_New(isolate, 2); // DontEnum
        defer v8.v8_Value_Dispose(@ptrCast(attributes));
        info.setReturnValue(@ptrCast(attributes));
        return .kYes;
    }
    return .kNo;
}

/// Named property deleter - [[Delete]] for WindowProperties
/// Per WebIDL §3.7.4: [[Delete]] on WindowProperties ALWAYS throws TypeError
/// This applies to ALL properties, not just named properties
fn namedPropertyDeleter(
    _: *v8.Name,
    info: *const v8.PropertyCallbackInfo,
) callconv(.c) v8.Intercepted {
    const isolate = info.getIsolate();

    // WindowProperties is immutable - [[Delete]] always throws TypeError
    conv.throwTypeError(isolate, "Cannot delete property on WindowProperties object");
    return .kYes;
}

/// Named property definer - [[DefineOwnProperty]] for WindowProperties
/// Per WebIDL §3.7.4: [[DefineOwnProperty]] on WindowProperties ALWAYS throws TypeError
fn namedPropertyDefiner(
    _: *v8.Name,
    _: *const v8.PropertyDescriptor,
    info: *const v8.PropertyCallbackInfoVoid,
) callconv(.c) v8.Intercepted {
    const isolate = info.getIsolate();

    // WindowProperties doesn't support [[DefineOwnProperty]] - always throws TypeError
    conv.throwTypeError(isolate, "Cannot define property on WindowProperties object");
    return .kYes;
}

/// Named property enumerator - [[OwnPropertyKeys]] for WindowProperties
///
/// Per WebIDL §3.7.4, the named properties object (WindowProperties) has special
/// [[OwnPropertyKeys]] behavior that differs from regular legacy platform objects:
///
/// "The [[OwnPropertyKeys]] internal method of a named properties object O takes
/// no arguments and returns a normal completion containing a List of property keys.
/// It performs the following steps when called:
///   1. Return « @@toStringTag »."
///
/// This means WindowProperties should return ONLY Symbol.toStringTag as an own key.
/// Named properties are accessible via [[Get]] but are NOT enumerated as own properties.
/// This is why Object.getOwnPropertyNames(wp) returns [] and Reflect.ownKeys(wp)
/// returns only [Symbol.toStringTag].
fn namedPropertyEnumerator(
    info: *const v8.PropertyCallbackInfo,
) callconv(.c) void {
    const isolate = info.getIsolate();

    // Per WebIDL §3.7.4: [[OwnPropertyKeys]] returns only « @@toStringTag »
    // We return an EMPTY array for string property names.
    // V8 will add Symbol.toStringTag separately since it was defined on the object.
    // The named properties are NOT own properties - they're accessed via interceptors
    // but don't appear in [[OwnPropertyKeys]].
    const arr = v8.v8_Array_New(isolate, 0);
    // Created in the current context: a leaked handle to it would keep the
    // whole page alive.
    defer v8.v8_Array_Dispose(arr);
    info.setReturnValue(@ptrCast(arr));
}

/// Named property descriptor callback
fn namedPropertyDescriptor(
    property: *v8.Name,
    info: *const v8.PropertyCallbackInfo,
) callconv(.c) v8.Intercepted {
    const isolate = info.getIsolate();
    const window = getWindowInstanceFromHolder(info) orelse return .kNo;

    var name_buf: [256]u8 = undefined;
    const name = nameToNative(isolate, property, &name_buf) orelse return .kNo;

    const result = WindowImpl.getNamedProperty(window, name) catch return .kNo;
    if (result) |js_val| {
        const context = getContextFromHolder(info) orelse return .kNo;
        defer v8.v8_Context_Dispose(context);
        // Not released - see namedPropertyGetter.
        const val = conv.toV8Value(runtime.JSValue, isolate, context, js_val) catch return .kNo;
        const desc = v8.v8_Object_New(isolate) orelse return .kNo;
        defer v8.v8_Object_Dispose(desc);
        setDescriptorField(isolate, context, desc, "value", val);
        const yes: *v8.Value = @ptrCast(v8.v8_Boolean_New(isolate, true) orelse return .kNo);
        defer v8.v8_Value_Dispose(yes);
        const no: *v8.Value = @ptrCast(v8.v8_Boolean_New(isolate, false) orelse return .kNo);
        defer v8.v8_Value_Dispose(no);
        setDescriptorField(isolate, context, desc, "writable", yes);
        setDescriptorField(isolate, context, desc, "enumerable", no);
        setDescriptorField(isolate, context, desc, "configurable", yes);
        info.setReturnValue(@ptrCast(desc));
        return .kYes;
    }
    return .kNo;
}

/// `desc[key] = value`, releasing the key handle it makes.
fn setDescriptorField(isolate: *v8.Isolate, context: *v8.Context, desc: *v8.Object, comptime key: []const u8, value: *v8.Value) void {
    const key_str = v8.v8_String_NewFromUtf8(isolate, key.ptr, key.len) orelse return;
    defer v8.v8_String_Dispose(key_str);
    _ = v8.v8_Object_Set(desc, context, @ptrCast(key_str), value);
}

/// Register WindowProperties callbacks as external references for V8 snapshots
///
/// This MUST be called before creating or loading a V8 snapshot.
/// Named property callbacks must be registered so V8 can resolve them at load time.
pub fn registerExternalReferences() void {
    const ext_refs = @import("external_references.zig");

    // Register named property handler callbacks
    ext_refs.registerPointer(@intFromPtr(&namedPropertyGetter));
    ext_refs.registerPointer(@intFromPtr(&namedPropertySetter));
    ext_refs.registerPointer(@intFromPtr(&namedPropertyQuery));
    ext_refs.registerPointer(@intFromPtr(&namedPropertyDeleter));
    ext_refs.registerPointer(@intFromPtr(&namedPropertyEnumerator));
    ext_refs.registerPointer(@intFromPtr(&namedPropertyDefiner));
    ext_refs.registerPointer(@intFromPtr(&namedPropertyDescriptor));
}

const testing = std.testing;
test "WindowProperties module compiles" {
    testing.refAllDecls(@This());
}
