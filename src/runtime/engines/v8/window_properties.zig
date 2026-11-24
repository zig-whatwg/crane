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
//! Window's named getter and supported property names are IDL (`getter
//! object (DOMString name)`): the interceptors ask Window's generated
//! interface, `interfaces.Window.call_getter` and `isSupportedPropertyName`,
//! as any caller reaches a type (src/webidl/AGENTS.md, the impls boundary).

const std = @import("std");
const v8 = @import("ffi.zig");
const helpers = @import("helpers.zig");
const runtime = @import("runtime");
const Window = @import("interfaces").Window;
const context_manager = @import("context_manager.zig");
const conv = @import("conversions.zig");

const protocol_agents = @import("protocol_agents.zig");

/// The WindowProperties template for `isolate`, and whether the caller owns
/// the handle.
const Template = struct {
    template: *v8.FunctionTemplate,
    /// Not cached: an isolate createAgent did not make (a test's own, the
    /// snapshot generator's) has no agent record, so its caller disposes it.
    owned: bool,
};

/// `isolate`'s WindowProperties template: its agent's (AgentRecord, Blink's
/// V8PerIsolateData shape), made by the isolate's first window realm. It was
/// one process-wide cache keyed by the last isolate that made one, read and
/// written unlocked: two Browsers making window realms on two threads at
/// once could hand one isolate the other's template.
fn templateFor(isolate: *v8.Isolate) Template {
    // Only window realm creation reaches this, which calls V8: the record
    // with no lock on the agent's thread (protocol_agents.callbackRecordOf).
    const record = protocol_agents.callbackRecordOf(isolate);
    if (record) |r| {
        if (r.window_properties_template) |cached| return .{ .template = cached, .owned = false };
    }
    const made = makeTemplate(isolate);
    const r = record orelse return .{ .template = made, .owned = true };
    r.window_properties_template = made;
    return .{ .template = made, .owned = false };
}

/// A new FunctionTemplate for WindowProperties.
fn makeTemplate(isolate: *v8.Isolate) *v8.FunctionTemplate {
    const tpl = v8.v8_FunctionTemplate_New(isolate, null, null).?;
    // The template keeps its class name; the handle is ours. (Made once per
    // process before, its leak went unseen; made per realm for an isolate
    // with no agent record, it was a handle a realm.)
    const name = v8.v8_String_NewFromUtf8(isolate, "WindowProperties", 16).?;
    defer v8.v8_String_Dispose(name);
    v8.v8_FunctionTemplate_SetClassName(tpl, name);

    // WebIDL 3.7.4 "create a named properties object", step 2: "Let proto be
    // ... the interface prototype object for the inherited interface" -
    // EventTarget.prototype - and the object is made with proto as its
    // [[Prototype]], which is immutable from then on. V8's prototype provider
    // gives that at creation (FunctionTemplate::SetPrototypeProviderTemplate:
    // an instance's [[Prototype]] is the provider's prototype object in the
    // instance's context, here the realm's EventTarget.prototype, which
    // materializeInterfaceObject builds from this same registered template).
    // Without it the instance's [[Prototype]] was this template's own
    // prototype object, one more object on every global's chain:
    // window -> Window.prototype -> WindowProperties -> (that object) ->
    // EventTarget.prototype (window-prototype-chain.html, cross-global-npo.html
    // and window-named-properties-object.html's [[SetPrototypeOf]] read it;
    // Chrome, Firefox and Safari have none). No Inherit(): that would make
    // this template's prototype object inherit EventTarget's, still one
    // object too many. A template made where no EventTarget template is
    // registered keeps the old link, made in insertIntoPrototypeChain.
    if (@import("template_registry.zig").getTemplateForIsolate("EventTarget", isolate)) |event_target| {
        v8.v8_FunctionTemplate_SetPrototypeProviderTemplate(tpl, event_target);
    }

    const instance_tpl = v8.v8_FunctionTemplate_InstanceTemplate(tpl);
    defer v8.v8_ObjectTemplate_Dispose(instance_tpl);

    // No internal field: the object is wrapped with its realm's GlobalAnchor
    // (insertIntoPrototypeChain), which names its Window - Blink's
    // SetupWindowPrototypeChain gives WindowProperties the window's native
    // info the same way (local_window_proxy.cc 434-437). Every API object
    // carries the CppHeap pointer Object::Wrap sets (V8 js-objects.tq,
    // JSAPIObjectWithEmbedderSlots / JSSpecialObject `cpp_heap_wrappable`), so
    // the named lookups find the right Window whichever realm asks
    // (`iframe.contentWindow.someName`), and the realm's end severs it with
    // the anchor's one clear().

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

    // Array-index property names reach the same named steps (the indexed
    // callbacks below). No setter, enumerator or definer: [[OwnPropertyKeys]]
    // lists no named property, and a write or a definition with an index
    // key behaves as it did.
    v8.v8_ObjectTemplate_SetIndexedPropertyHandlerFull(
        instance_tpl,
        indexedPropertyGetter,
        null,
        indexedPropertyQuery,
        null,
        indexedPropertyDescriptor,
    );

    // Mark WindowProperties instances as having immutable [[Prototype]]
    // Per WebIDL §3.7.4, the named properties object's prototype is immutable
    v8.v8_ObjectTemplate_SetImmutableProto(instance_tpl);

    // With no prototype provider (no EventTarget template registered), the
    // template's own prototype object stands behind the instance; it is NOT
    // made immutable, so insertIntoPrototypeChain can still point it at
    // EventTarget.prototype - with both immutable, that step was refused
    // silently and `window instanceof EventTarget` was never true.

    return tpl;
}

/// Create the WindowProperties exotic object, wrapped with `context`'s realm's
/// GlobalAnchor (realm_global.attach made it), which names the realm's Window.
pub fn create(
    isolate: *v8.Isolate,
    context: *v8.Context,
    event_target_prototype: *v8.Object,
) ?*v8.Object {
    _ = event_target_prototype;

    const made = templateFor(isolate);
    defer if (made.owned) v8.v8_FunctionTemplate_Dispose(made.template);
    const instance_tpl = v8.v8_FunctionTemplate_InstanceTemplate(made.template);
    defer v8.v8_ObjectTemplate_Dispose(instance_tpl);
    const instance = v8.v8_ObjectTemplate_NewInstance(instance_tpl, context) orelse return null;

    // Its Window: the realm's anchor (Blink: SetNativeInfo on WindowProperties).
    if (@import("context_manager.zig").globalAnchorOf(context)) |anchor| {
        v8.v8_GlobalAnchor_WrapObject(anchor, instance);
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
/// Its Window is the realm's: the object is wrapped with the realm's
/// GlobalAnchor, so the realm's global must be attached first
/// (realm_global.attach).
pub fn insertIntoPrototypeChain(
    isolate: *v8.Isolate,
    context: *v8.Context,
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

    // A new WindowProperties instance, wrapped with the realm's anchor.
    const wp = create(isolate, context, event_target_proto) orelse return false;
    defer v8.v8_Object_Dispose(wp);

    // WindowProperties -> EventTarget.prototype: the instance's own
    // [[Prototype]], immutable (WebIDL), given at creation by the template's
    // prototype provider (makeTemplate). Only a template made with no
    // EventTarget template registered has its own prototype object there
    // instead; the link then goes on that object: wp -> wp_proto ->
    // EventTarget.prototype.
    if (v8.v8_Object_GetPrototypeV2(wp)) |wp_proto_val| {
        defer v8.v8_Value_Dispose(wp_proto_val);
        if (!v8.v8_Value_StrictEquals(wp_proto_val, @ptrCast(event_target_proto))) {
            if (helpers.asObject(wp_proto_val)) |wp_proto| {
                _ = v8.v8_Object_SetPrototypeV2(wp_proto, context, @ptrCast(event_target_proto));
            }
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

/// The Window whose named properties these are: the instance of the
/// GlobalAnchor the holder - this WindowProperties object, an interceptor's
/// holder is the object it is installed on - is wrapped with (`create`).
/// Null once the realm's end cleared the anchor: answer nothing. Never the
/// CURRENT context's Window, which would answer `iframe.contentWindow.x`
/// from the parent's document - nor, for a realm whose WindowProxy went on,
/// the NEW Window: an old realm's named access reaches its own
/// WindowProperties, whose anchor is the old realm's.
fn getWindowInstanceFromHolder(info: *const v8.PropertyCallbackInfo) ?*runtime.Instance {
    const ptr = v8.v8_PropertyCallbackInfo_HolderGlobalAnchorInstance(info) orelse return null;
    return @ptrCast(@alignCast(ptr));
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
    var name_buf: [256]u8 = undefined;
    const name = nameToNative(info.getIsolate(), property, &name_buf) orelse return .kNo;
    return getNamed(info, name);
}

/// [[Get]] for the property name `name` (a string key, or an array index
/// written as its decimal string).
fn getNamed(info: *const v8.PropertyCallbackInfo, name: []const u8) v8.Intercepted {
    const isolate = info.getIsolate();
    const window = getWindowInstanceFromHolder(info) orelse return .kNo;

    // Undefined: no supported property name (Window.call_getter).
    const js_val = Window.call_getter(window, runtime.DOMString.initInterned(name)) catch return .kNo;
    if (js_val != .undefined) {
        // HTML 7.1.3.3's access report check for a name the named getter
        // answers (Chromium reports "named"; access-reporting/
        // property-named-getter: an iframe's name and an element's id, never
        // a global or a missing name).
        @import("protocol_realms.zig").reportWindowAccess(window, "named");
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
    var name_buf: [256]u8 = undefined;
    const name = nameToNative(info.getIsolate(), property, &name_buf) orelse return .kNo;
    return queryNamed(info, name);
}

/// [[HasProperty]] for the property name `name` (see getNamed).
fn queryNamed(info: *const v8.PropertyCallbackInfo, name: []const u8) v8.Intercepted {
    const isolate = info.getIsolate();
    const window = getWindowInstanceFromHolder(info) orelse return .kNo;

    if (Window.isSupportedPropertyName(window, runtime.DOMString.initInterned(name)) catch false) {
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
    info: *const v8.PropertyCallbackInfoBoolean,
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
    var name_buf: [256]u8 = undefined;
    const name = nameToNative(info.getIsolate(), property, &name_buf) orelse return .kNo;
    return describeNamed(info, name);
}

/// [[GetOwnProperty]] for the property name `name` (see getNamed).
fn describeNamed(info: *const v8.PropertyCallbackInfo, name: []const u8) v8.Intercepted {
    const isolate = info.getIsolate();
    const window = getWindowInstanceFromHolder(info) orelse return .kNo;

    const js_val = Window.call_getter(window, runtime.DOMString.initInterned(name)) catch return .kNo;
    if (js_val != .undefined) {
        const context = getContextFromHolder(info) orelse return .kNo;
        defer v8.v8_Context_Dispose(context);
        // Not released - see namedPropertyGetter.
        const borrowed_val = conv.toV8Value(runtime.JSValue, isolate, context, js_val) catch return .kNo;
        // An element's wrapper is the wrapper cache's, held WEAKLY: hold it
        // before the descriptor and its keys allocate, which can collect it
        // (docs/lessons/architecture-a-weakly-held-wrapper-dies-at-the-next-allocation.md).
        const val = v8.v8_Global_Clone(borrowed_val) orelse return .kNo;
        defer v8.v8_Global_Dispose(val);
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

// ============================================================================
// Indexed Property Handler Callbacks
// ============================================================================
//
// WebIDL 3.7.4's named properties object answers every PROPERTY NAME - a
// string - and an array index is one ("0".."4294967294"): `<div id=0>` and
// `<iframe name=3>` are named properties too. V8 sends integer keys to
// indexed interceptors only, so the named handler above never saw them, and
// `Object.getPrototypeOf(Window.prototype)[0]` read undefined while Chrome,
// Firefox and Safari answer the element (html/browsers/the-window-object/
// window-indexed-access-vs-named-access.html, 10/10 in all three). These
// run the same named steps with the index written as its decimal string.
// The global's own indexed interceptor (context_manager, the WindowProxy's
// child navigables) answers first: an index it has no child for reaches the
// prototype chain, and here.

/// `index` as its decimal string, in `buf`.
fn indexName(index: u32, buf: []u8) []const u8 {
    return std.fmt.bufPrint(buf, "{d}", .{index}) catch unreachable;
}

/// WebIDL's named property visibility algorithm (3.9.7) steps 2 and 4-5 for
/// the array-index name `name`: hidden when the named properties object has
/// a real own property of that name, or an object on its [[Prototype]] chain
/// does (`w.Object.prototype[0] = 20` makes wp[0] read 20:
/// window-named-properties-object.html's visibility subtests). The named
/// handler gets this from V8's non-masking flag, which indexed handlers do
/// not take.
fn indexHidden(info: *const v8.PropertyCallbackInfo, name: []const u8) bool {
    var units: [10]u16 = undefined;
    for (name, 0..) |c, i| units[i] = c;
    return v8.v8_LegacyPlatformObject_NamedPropertyState(@ptrCast(info), &units, @intCast(name.len)) != 0;
}

/// WebIDL's named property visibility algorithm (3.9.7) for the array-index
/// name `name`, in its order: step 1, "if P is not a supported property name
/// of O, then return false", first - the common case, every `window[i]` past
/// the child navigables, answered by Window's lookup alone - and the walk of
/// steps 2 and 4-5 (`indexHidden`) only for a name that exists (lane blk3's
/// focused cost window, 2026-11-18: walking it first cost each such miss
/// about 90 ns).
fn indexVisible(info: *const v8.PropertyCallbackInfo, name: []const u8) bool {
    const window = getWindowInstanceFromHolder(info) orelse return false;
    if (!(Window.isSupportedPropertyName(window, runtime.DOMString.initInterned(name)) catch false)) return false;
    return !indexHidden(info, name);
}

fn indexedPropertyGetter(index: u32, info: *const v8.PropertyCallbackInfo) callconv(.c) v8.Intercepted {
    var buf: [10]u8 = undefined;
    const name = indexName(index, &buf);
    if (!indexVisible(info, name)) return .kNo;
    return getNamed(info, name);
}

fn indexedPropertyQuery(index: u32, info: *const v8.PropertyCallbackInfo) callconv(.c) v8.Intercepted {
    var buf: [10]u8 = undefined;
    const name = indexName(index, &buf);
    if (!indexVisible(info, name)) return .kNo;
    return queryNamed(info, name);
}

fn indexedPropertyDescriptor(index: u32, info: *const v8.PropertyCallbackInfo) callconv(.c) v8.Intercepted {
    var buf: [10]u8 = undefined;
    const name = indexName(index, &buf);
    if (!indexVisible(info, name)) return .kNo;
    return describeNamed(info, name);
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
    // And the indexed ones (array-index property names).
    ext_refs.registerPointer(@intFromPtr(&indexedPropertyGetter));
    ext_refs.registerPointer(@intFromPtr(&indexedPropertyQuery));
    ext_refs.registerPointer(@intFromPtr(&indexedPropertyDescriptor));
}
