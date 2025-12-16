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
//! - [[OwnPropertyKeys]]: Returns only Symbol.toStringTag
//!
//! The WindowProperties object also has @@toStringTag = "WindowProperties" so that
//! Object.prototype.toString.call(windowProperties) returns "[object WindowProperties]".
//!
//! ## Implementation Strategy
//!
//! V8's ObjectTemplate doesn't support all the exotic behaviors required by WebIDL spec.
//! We use a JavaScript Proxy to implement the exotic internal methods correctly:
//! - preventExtensions trap returns false
//! - setPrototypeOf trap returns false for different prototypes
//! - set trap returns false
//! - deleteProperty trap returns false
//! - defineProperty trap returns false
//! - ownKeys returns only [Symbol.toStringTag]

const std = @import("std");
const v8 = @import("ffi.zig");

/// Create the WindowProperties exotic object using JavaScript Proxy
///
/// This uses a Proxy to implement the exotic internal methods correctly.
/// V8's ObjectTemplate can't express all the required exotic behaviors.
///
/// Arguments:
/// - isolate: V8 isolate
/// - context: V8 context
/// - event_target_prototype: The EventTarget.prototype to set as [[Prototype]] (unused, set via JS)
///
/// Returns: The WindowProperties Proxy object, or null on failure
pub fn create(
    isolate: *v8.Isolate,
    context: *v8.Context,
    event_target_prototype: *v8.Object,
) ?*v8.Object {
    _ = event_target_prototype; // Will be set via JS now

    // Create WindowProperties as a Proxy with exotic behavior handlers
    // This is the only way to implement the full spec-compliant behavior
    //
    // NOTE: V8 Proxy has a limitation where errors thrown automatically by V8
    // (when trap returns false) come from the caller's realm, not the proxy's realm.
    // This is a known issue: https://bugs.chromium.org/p/v8/issues/detail?id=5765
    //
    // The WPT tests expect cross-realm TypeError instances, but with Proxy this
    // isn't possible without explicitly throwing errors ourselves. The test
    // `assert_throws_js(w.TypeError, ...)` will fail because the TypeError
    // comes from the caller's realm, not the iframe's realm.
    //
    // For full spec compliance, we would need V8-level support for specifying
    // which realm to create errors in when Proxy traps return false.
    const js_code =
        \\(function() {
        \\  // Target object with Symbol.toStringTag
        \\  const target = Object.create(null);
        \\  Object.defineProperty(target, Symbol.toStringTag, {
        \\    value: "WindowProperties",
        \\    writable: false,
        \\    enumerable: false,
        \\    configurable: true
        \\  });
        \\  
        \\  // Store the prototype (will be set after creation)
        \\  let currentPrototype = null;
        \\  
        \\  const handler = {
        \\    // [[GetPrototypeOf]] - return current prototype
        \\    getPrototypeOf(target) {
        \\      return currentPrototype;
        \\    },
        \\    
        \\    // [[SetPrototypeOf]] - return false for different value, true for same
        \\    setPrototypeOf(target, proto) {
        \\      if (currentPrototype === null) {
        \\        // First time setting - allow it
        \\        currentPrototype = proto;
        \\        return true;
        \\      }
        \\      // Only allow setting to same value
        \\      return proto === currentPrototype;
        \\    },
        \\    
        \\    // [[PreventExtensions]] - always return false (cannot be made non-extensible)
        \\    preventExtensions(target) {
        \\      return false;
        \\    },
        \\    
        \\    // [[IsExtensible]] - always return true
        \\    isExtensible(target) {
        \\      return true;
        \\    },
        \\    
        \\    // [[GetOwnPropertyDescriptor]] - return descriptor for toStringTag only
        \\    getOwnPropertyDescriptor(target, prop) {
        \\      if (prop === Symbol.toStringTag) {
        \\        return {
        \\          value: "WindowProperties",
        \\          writable: false,
        \\          enumerable: false,
        \\          configurable: true
        \\        };
        \\      }
        \\      // TODO: Check for named properties in the document
        \\      return undefined;
        \\    },
        \\    
        \\    // [[DefineOwnProperty]] - always return false
        \\    defineProperty(target, prop, descriptor) {
        \\      return false;
        \\    },
        \\    
        \\    // [[HasProperty]] - check Symbol.toStringTag and named properties
        \\    has(target, prop) {
        \\      if (prop === Symbol.toStringTag) return true;
        \\      // TODO: Check for named properties in the document
        \\      // For now, continue to prototype chain
        \\      if (currentPrototype) {
        \\        return prop in currentPrototype;
        \\      }
        \\      return false;
        \\    },
        \\    
        \\    // [[Get]] - return toStringTag or look up prototype chain
        \\    get(target, prop, receiver) {
        \\      if (prop === Symbol.toStringTag) {
        \\        return "WindowProperties";
        \\      }
        \\      // TODO: Check for named properties in the document
        \\      // Continue to prototype chain
        \\      if (currentPrototype && prop in currentPrototype) {
        \\        return currentPrototype[prop];
        \\      }
        \\      return undefined;
        \\    },
        \\    
        \\    // [[Set]] - always return false
        \\    set(target, prop, value, receiver) {
        \\      return false;
        \\    },
        \\    
        \\    // [[Delete]] - always return false
        \\    deleteProperty(target, prop) {
        \\      return false;
        \\    },
        \\    
        \\    // [[OwnPropertyKeys]] - return only Symbol.toStringTag
        \\    ownKeys(target) {
        \\      return [Symbol.toStringTag];
        \\    }
        \\  };
        \\  
        \\  return new Proxy(target, handler);
        \\})()
    ;

    const source = v8.v8_String_NewFromUtf8(isolate, js_code.ptr, @intCast(js_code.len)) orelse return null;
    const script = v8.v8_Script_Compile(context, source) orelse return null;
    const result = v8.v8_Script_Run(context, script) orelse return null;

    return @ptrCast(result);
}

/// Insert WindowProperties into the prototype chain for a global Window
///
/// This modifies the prototype chain from:
///   Window.prototype → EventTarget.prototype
/// to:
///   Window.prototype → WindowProperties → EventTarget.prototype
///
/// Arguments:
/// - isolate: V8 isolate
/// - context: V8 context
///
/// Returns: true on success, false on failure
pub fn insertIntoPrototypeChain(
    isolate: *v8.Isolate,
    context: *v8.Context,
) bool {
    const global = v8.v8_Context_Global(context) orelse return false;

    // Get Window constructor
    const window_key = v8.v8_String_NewFromUtf8(isolate, "Window", 6) orelse return false;
    const window_ctor_val = v8.v8_Object_Get(global, context, @ptrCast(window_key)) orelse return false;
    const window_ctor: *v8.Object = @ptrCast(window_ctor_val);

    // Get Window.prototype
    const proto_key = v8.v8_String_NewFromUtf8(isolate, "prototype", 9) orelse return false;
    const window_proto_val = v8.v8_Object_Get(window_ctor, context, @ptrCast(proto_key)) orelse return false;
    _ = window_proto_val; // Unused in JS approach

    // Since Window doesn't use FunctionTemplate_Inherit anymore, Window.prototype.__proto__
    // starts as Object.prototype. We need to get EventTarget.prototype from the global scope.
    const et_key = v8.v8_String_NewFromUtf8(isolate, "EventTarget", 11) orelse return false;
    const et_ctor_val = v8.v8_Object_Get(global, context, @ptrCast(et_key)) orelse return false;
    const et_ctor: *v8.Object = @ptrCast(et_ctor_val);

    const et_proto_val = v8.v8_Object_Get(et_ctor, context, @ptrCast(proto_key)) orelse return false;
    const event_target_proto: *v8.Object = @ptrCast(et_proto_val);

    // Create WindowProperties with EventTarget.prototype as its [[Prototype]]
    const window_properties = create(isolate, context, event_target_proto) orelse return false;

    // Store WindowProperties on a temporary global property so JS can access it
    const temp_key = v8.v8_String_NewFromUtf8(isolate, "__windowProperties__", 20) orelse return false;
    if (!v8.v8_Object_Set(global, context, @ptrCast(temp_key), @ptrCast(window_properties))) {
        std.debug.print("insertIntoPrototypeChain: failed to store WindowProperties on global\n", .{});
        return false;
    }

    // Use JavaScript to set the prototype chain
    // This works because JS has full access to modify prototypes, even when
    // the V8 C++ API SetPrototypeV2 fails (possibly due to internal template state)
    //
    // IMPORTANT: We set WindowProperties.__proto__ = EventTarget.prototype FIRST
    // because WindowProperties was created with immutable proto set on its template.
    // This first setPrototypeOf on WindowProperties succeeds because V8's immutable proto
    // allows changing from the template's default (Object.prototype) exactly once.
    // After this, WindowProperties' prototype is locked to EventTarget.prototype.
    const js_code =
        \\(function() {
        \\  const wp = globalThis.__windowProperties__;
        \\  if (!wp) return false;
        \\  // Set WindowProperties' prototype to EventTarget.prototype
        \\  Object.setPrototypeOf(wp, EventTarget.prototype);
        \\  // Insert WindowProperties into Window's prototype chain
        \\  Object.setPrototypeOf(Window.prototype, wp);
        \\  delete globalThis.__windowProperties__;
        \\  return true;
        \\})()
    ;

    const source = v8.v8_String_NewFromUtf8(isolate, js_code.ptr, js_code.len) orelse {
        std.debug.print("insertIntoPrototypeChain: failed to create JS source string\n", .{});
        return false;
    };

    const script = v8.v8_Script_Compile(context, source) orelse {
        std.debug.print("insertIntoPrototypeChain: failed to compile JS\n", .{});
        return false;
    };

    const result_val = v8.v8_Script_Run(context, script) orelse {
        std.debug.print("insertIntoPrototypeChain: JS execution failed\n", .{});
        return false;
    };

    return v8.v8_Value_BooleanValue(result_val, isolate);
}

// ============================================================================
// Named Property Handler Callbacks
// ============================================================================

/// Named property getter - [[Get]] for WindowProperties
///
/// Per WebIDL spec, this should:
/// 1. Check named property visibility algorithm
/// 2. Return named elements (elements with id/name attributes) if visible
/// 3. Continue normal lookup if not a named property
///
/// For now, we don't intercept - V8 will continue to prototype chain.
/// A full implementation would query the document for elements with matching id/name.
fn namedPropertyGetter(
    _: *v8.Name,
    _: *const v8.PropertyCallbackInfo,
) callconv(.c) void {
    // Don't intercept - let V8 continue to prototype chain
    // This means WindowProperties doesn't add any own properties by default
    //
    // A full implementation would:
    // 1. Get the property name as a string
    // 2. Check if it's an "exposed" property (passes named property visibility)
    // 3. If so, query the document for elements with that id/name and return them
    //
    // For WPT compliance, the tests use iframes where the named properties
    // come from elements added to the iframe's document. Since we're not
    // fully implementing document element lookup here, those tests that rely
    // on actual named elements won't work, but the ones testing the exotic
    // behavior (set/delete/defineProperty failing) will work.
}

/// Named property setter - [[Set]] for WindowProperties
///
/// Per WebIDL §3.7.4, [[Set]] on named properties object always returns false.
/// This means:
/// - In strict mode: throws TypeError
/// - In sloppy mode: silently fails
/// - Reflect.set returns false
fn namedPropertySetter(
    _: *v8.Name,
    _: *v8.Value,
    info: *const v8.PropertyCallbackInfo,
) callconv(.c) void {
    // Always return false - [[Set]] always fails on WindowProperties
    const isolate = info.getIsolate();
    const false_val = v8.v8_Boolean_New(isolate, false);
    info.setReturnValue(@ptrCast(false_val));
}

/// Named property query - [[HasProperty]] for WindowProperties
///
/// Returns property attributes if the property exists as a named element,
/// or does nothing to indicate property doesn't exist.
fn namedPropertyQuery(
    _: *v8.Name,
    _: *const v8.PropertyCallbackInfo,
) callconv(.c) void {
    // Don't intercept - continue normal lookup
    // Named properties are not reported as own properties in the basic query
}

/// Named property deleter - [[Delete]] for WindowProperties
///
/// Per WebIDL §3.7.4, [[Delete]] on named properties object always returns false.
/// This means:
/// - In strict mode: throws TypeError
/// - delete operator returns false
/// - Reflect.deleteProperty returns false
fn namedPropertyDeleter(
    _: *v8.Name,
    info: *const v8.PropertyCallbackInfo,
) callconv(.c) void {
    // Always return false - [[Delete]] always fails on WindowProperties
    const isolate = info.getIsolate();
    const false_val = v8.v8_Boolean_New(isolate, false);
    info.setReturnValue(@ptrCast(false_val));
}

/// Named property enumerator - [[OwnPropertyKeys]] for WindowProperties
///
/// Per WebIDL §3.7.4, [[OwnPropertyKeys]] returns only Symbol.toStringTag.
/// Named properties are NOT enumerable (not in for...in, Object.keys, etc.)
fn namedPropertyEnumerator(
    info: *const v8.PropertyCallbackInfo,
) callconv(.c) void {
    // Return array with just Symbol.toStringTag
    const isolate = info.getIsolate();
    const arr = v8.v8_Array_New(isolate, 1);

    if (v8.v8_Symbol_GetToStringTag(isolate)) |tag_symbol| {
        const v8_context = v8.v8_Isolate_GetCurrentContext(isolate) orelse return;
        _ = v8.v8_Array_Set(arr, v8_context, 0, @ptrCast(tag_symbol));
    }

    info.setReturnValue(@ptrCast(arr));
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "WindowProperties module compiles" {
    testing.refAllDecls(@This());
}
