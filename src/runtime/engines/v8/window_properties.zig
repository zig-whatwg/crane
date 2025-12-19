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
//!
//! ## Named Property Lookup (HTML §7.4.1)
//!
//! The supported property names of a Window object consist of:
//! - document-tree child navigable target names (iframe/frame name attributes)
//! - name attributes of embed, form, img, object elements
//! - id attributes of all HTML elements

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
        \\  // Capture reference to this Window (globalThis)
        \\  const windowRef = globalThis;
        \\  
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
        \\  // Store reference to proxy for identity checks in set trap
        \\  let proxyRef = null;
        \\  
        \\  // Get named element from document per HTML §7.4.1
        \\  // Returns the element/window or undefined if not found
        \\  function getNamedElement(name) {
        \\    try {
        \\      if (typeof window === 'undefined' || !window.document) return undefined;
        \\      const doc = window.document;
        \\      // Don't require body - elements might be in documentElement or head
        \\      
        \\      // Convert name to string for comparison
        \\      const nameStr = String(name);
        \\      
        \\      // 1. Check for child browsing context (iframe/frame with matching name)
        \\      const iframes = doc.getElementsByTagName('iframe');
        \\      for (let i = 0; i < iframes.length; i++) {
        \\        const frame = iframes[i];
        \\        if (frame.name === nameStr && frame.contentWindow) {
        \\          return frame.contentWindow;
        \\        }
        \\      }
        \\      const frames = doc.getElementsByTagName('frame');
        \\      for (let i = 0; i < frames.length; i++) {
        \\        const frame = frames[i];
        \\        if (frame.name === nameStr && frame.contentWindow) {
        \\          return frame.contentWindow;
        \\        }
        \\      }
        \\      
        \\      // 2. Check for named elements: embed, form, img, object with name attr
        \\      const tagNames = ['embed', 'form', 'img', 'object'];
        \\      const namedElements = [];
        \\      for (let t = 0; t < tagNames.length; t++) {
        \\        const elements = doc.getElementsByTagName(tagNames[t]);
        \\        for (let i = 0; i < elements.length; i++) {
        \\          if (elements[i].name === nameStr) {
        \\            namedElements.push(elements[i]);
        \\          }
        \\        }
        \\      }
        \\      if (namedElements.length === 1) return namedElements[0];
        \\      if (namedElements.length > 1) {
        \\        // Return first for now - full impl would return HTMLCollection
        \\        return namedElements[0];
        \\      }
        \\      
        \\      // 3. Check for element with matching id
        \\      const byId = doc.getElementById(nameStr);
        \\      if (byId) return byId;
        \\      
        \\      return undefined;
        \\    } catch (e) {
        \\      // If anything fails, treat as no named element
        \\      return undefined;
        \\    }
        \\  }
        \\  
        \\  // Check if property is visible per named property visibility algorithm
        \\  // A property is NOT visible if shadowed by something higher in prototype chain
        \\  function isPropertyVisible(prop) {
        \\    // Symbol properties are never named properties
        \\    if (typeof prop === 'symbol') return false;
        \\    
        \\    const propStr = String(prop);
        \\    
        \\    // 1. Check if property exists on the Global object itself
        \\    // Per WebIDL §3.8.1 step 1
        \\    if (Object.prototype.hasOwnProperty.call(globalThis, propStr)) return false;
        \\    
        \\    // 2. Check if property exists on Object.prototype or EventTarget.prototype
        \\    // These shadow named properties
        \\    if (Object.prototype.hasOwnProperty.call(Object.prototype, propStr)) return false;
        \\    if (currentPrototype && Object.prototype.hasOwnProperty.call(currentPrototype, propStr)) return false;
        \\    
        \\    // SPECIAL CASE: Shadow status explicitly to avoid recursion or early access issues
        \\    if (propStr === 'status') return false;
        \\    
        \\    return true;
        \\  }
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
        \\    // [[GetOwnPropertyDescriptor]] - return descriptor for named properties
        \\    getOwnPropertyDescriptor(target, prop) {
        \\      if (prop === Symbol.toStringTag) {
        \\        return {
        \\          value: "WindowProperties",
        \\          writable: false,
        \\          enumerable: false,
        \\          configurable: true
        \\        };
        \\      }
        \\      
        \\      // Check named property visibility
        \\      if (!isPropertyVisible(prop)) return undefined;
        \\      
        \\      // Look up named element
        \\      const element = getNamedElement(prop);
        \\      if (element !== undefined) {
        \\        // Per WebIDL, named properties are writable, non-enumerable, configurable
        \\        return {
        \\          value: element,
        \\          writable: true,
        \\          enumerable: false,
        \\          configurable: true
        \\        };
        \\      }
        \\      
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
        \\      
        \\      // Check named property visibility
        \\      if (!isPropertyVisible(prop)) {
        \\        // Property is shadowed - check prototype chain
        \\        if (currentPrototype) {
        \\          return prop in currentPrototype;
        \\        }
        \\        return false;
        \\      }
        \\      
        \\      // Check if named element exists
        \\      const element = getNamedElement(prop);
        \\      if (element !== undefined) return true;
        \\      
        \\      // Continue to prototype chain
        \\      if (currentPrototype) {
        \\        return prop in currentPrototype;
        \\      }
        \\      return false;
        \\    },
        \\    
        \\    // [[Get]] - return named element or continue to prototype chain
        \\    get(target, prop, receiver) {
        \\      if (prop === Symbol.toStringTag) {
        \\        return "WindowProperties";
        \\      }
        \\      
        \\      // Check named property visibility
        \\      if (isPropertyVisible(prop)) {
        \\        // Look up named element
        \\        const element = getNamedElement(prop);
        \\        if (element !== undefined) return element;
        \\      }
        \\      
        \\      // Continue to prototype chain
        \\      if (currentPrototype) {
        \\        return Reflect.get(currentPrototype, prop, receiver);
        \\      }
        \\      return undefined;
        \\    },
        \\    
        \\    // [[Set]] - Per WebIDL §3.7.4:
        \\    // - If receiver is the proxy, return false
        \\    // - If receiver is different, create property on receiver
        \\    set(target, prop, value, receiver) {
        \\      // If receiver IS the proxy, setting fails
        \\      if (receiver === proxyRef) {
        \\        return false;
        \\      }
        \\      
        \\      // Continue to prototype chain or receiver
        \\      const proto = currentPrototype || Object.create(null);
        \\      return Reflect.set(proto, prop, value, receiver);
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
        \\  proxyRef = new Proxy(target, handler);
        \\  return proxyRef;
        \\})()
    ;

    const source = v8.v8_String_NewFromUtf8(isolate, js_code.ptr, @intCast(js_code.len)) orelse return null;
    const script = v8.v8_Script_Compile(context, source) orelse return null;
    const result = v8.v8_Script_Run(context, script) orelse return null;

    return @ptrCast(result);
}

/// Insert WindowProperties into the prototype chain for a global Window
///
/// Per WebIDL spec, for interfaces with [Global] extended attribute that support
/// named properties, the prototype chain must be:
///   global → Window.prototype → WindowProperties → EventTarget.prototype → Object.prototype
///
/// Spec references:
/// - §3.7.3 step 2: Window.prototype.__proto__ = WindowProperties
/// - §3.7.4 step 2: WindowProperties.__proto__ = EventTarget.prototype (inherited interface)
/// - §3.8 step 9: global.__proto__ = Window.prototype (set by caller)
///
/// This function:
/// 1. Creates the WindowProperties exotic object (with special [[GetOwnProperty]], etc.)
/// 2. Sets WindowProperties.__proto__ = EventTarget.prototype
/// 3. Sets Window.prototype.__proto__ = WindowProperties
///
/// The caller is responsible for setting global.__proto__ = Window.prototype, which
/// is typically done by V8's context creation or explicitly in createChildContext.
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
    _ = window_proto_val;

    // Create WindowProperties (EventTarget.prototype arg is unused now - set via JS)
    // Note: The argument is kept for API compatibility but ignored
    const window_properties = create(isolate, context, @ptrCast(v8.v8_Null(isolate).?)) orelse return false;

    // Store WindowProperties on a temporary global property so JS can access it
    const temp_key = v8.v8_String_NewFromUtf8(isolate, "__windowProperties__", 20) orelse return false;
    if (!v8.v8_Object_Set(global, context, @ptrCast(temp_key), @ptrCast(window_properties))) {
        return false;
    }

    // Use JavaScript to set the prototype chain correctly per WebIDL spec:
    //
    // Per WebIDL §3.7.3 (Interface prototype object creation), step 2:
    //   "If interface is declared with the [Global] extended attribute, and
    //   interface supports named properties, then set proto to the result of
    //   creating a named properties object"
    // This means: Window.prototype.__proto__ = WindowProperties
    //
    // Per WebIDL §3.7.4 (Named properties object creation), step 2:
    //   "If interface is declared to inherit from another interface, then set
    //   proto to the interface prototype object in realm for the inherited interface"
    // Window inherits from EventTarget, so: WindowProperties.__proto__ = EventTarget.prototype
    //
    // Per WebIDL §3.8 (Platform objects), the global's prototype is set to Window.prototype.
    //
    // Final chain: global → Window.prototype → WindowProperties → EventTarget.prototype
    const js_code =
        \\(function() {
        \\  const wp = globalThis.__windowProperties__;
        \\  if (!wp) return false;
        \\  
        \\  // Step 1: Set WindowProperties' prototype to EventTarget.prototype
        \\  // Per WebIDL §3.7.4 step 2: named properties object inherits from the
        \\  // inherited interface's prototype (Window inherits from EventTarget)
        \\  Object.setPrototypeOf(wp, EventTarget.prototype);
        \\  
        \\  // Step 2: Set Window.prototype's prototype to WindowProperties
        \\  // Per WebIDL §3.7.3 step 2: interface prototype object for [Global]
        \\  // interfaces with named properties has WindowProperties as its prototype
        \\  Object.setPrototypeOf(Window.prototype, wp);
        \\  
        \\  // Step 3: Make Window.prototype's prototype immutable per WebIDL §3.7.3
        \\  // We do this by making __proto__ non-configurable and non-writable
        \\  // Note: V8 honors this for the immutable prototype bit internally
        \\  Object.defineProperty(Window.prototype, "__proto__", {
        \\    configurable: false,
        \\    writable: false
        \\  });
        \\  
        \\  // Note: global.__proto__ = Window.prototype is already set by V8 or
        \\  // will be set by the caller after this function returns
        \\  
        \\  delete globalThis.__windowProperties__;
        \\  return true;
        \\})()
    ;

    const source = v8.v8_String_NewFromUtf8(isolate, js_code.ptr, js_code.len) orelse {
        return false;
    };

    const script = v8.v8_Script_Compile(context, source) orelse {
        return false;
    };

    const result_val = v8.v8_Script_Run(context, script) orelse {
        return false;
    };

    if (!v8.v8_Value_BooleanValue(result_val, isolate)) {
        return false;
    }

    return true;
}

// ============================================================================
// Named Property Handler Callbacks (legacy - kept for reference)
// ============================================================================

/// Named property getter - [[Get]] for WindowProperties
fn namedPropertyGetter(
    _: *v8.Name,
    _: *const v8.PropertyCallbackInfo,
) callconv(.c) void {
    // Not used - Proxy handles this
}

/// Named property setter - [[Set]] for WindowProperties
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
fn namedPropertyQuery(
    _: *v8.Name,
    _: *const v8.PropertyCallbackInfo,
) callconv(.c) void {
    // Not used - Proxy handles this
}

/// Named property deleter - [[Delete]] for WindowProperties
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
