//! WindowProperties Exotic Object
//!
//! Per WebIDL §3.8.1, the WindowProperties object is a special "named properties object"
//! inserted into the prototype chain for [Global] interfaces:
//!
//! global → WindowProperties → Window.prototype → EventTarget.prototype → Object.prototype
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
        \\      if (!windowRef || !windowRef.document) return undefined;
        \\      const doc = windowRef.document;
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
        \\    // Check if property exists on Object.prototype or EventTarget.prototype
        \\    // These shadow named properties
        \\    if (Object.prototype.hasOwnProperty.call(Object.prototype, propStr)) return false;
        \\    if (currentPrototype && Object.prototype.hasOwnProperty.call(currentPrototype, propStr)) return false;
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
        \\      if (currentPrototype && prop in currentPrototype) {
        \\        return currentPrototype[prop];
        \\      }
        \\      return undefined;
        \\    },
        \\    
        \\    // [[Set]] - Per WebIDL §3.7.4:
        \\    // - If receiver is the proxy, return false (cannot set on WindowProperties)
        \\    // - If receiver is different, create property on receiver
        \\    set(target, prop, value, receiver) {
        \\      // If receiver IS the proxy, setting fails
        \\      if (receiver === proxyRef) {
        \\        return false;
        \\      }
        \\      
        \\      // Check if there's a setter in the prototype chain
        \\      let proto = currentPrototype;
        \\      while (proto) {
        \\        const desc = Object.getOwnPropertyDescriptor(proto, prop);
        \\        if (desc) {
        \\          if (desc.set) {
        \\            // Call the setter with receiver as this
        \\            desc.set.call(receiver, value);
        \\            return true;
        \\          }
        \\          if ('value' in desc && !desc.writable) {
        \\            // Non-writable data property - fail
        \\            return false;
        \\          }
        \\          break;
        \\        }
        \\        proto = Object.getPrototypeOf(proto);
        \\      }
        \\      
        \\      // Create own property on receiver
        \\      Object.defineProperty(receiver, prop, {
        \\        value: value,
        \\        writable: true,
        \\        enumerable: true,
        \\        configurable: true
        \\      });
        \\      return true;
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
/// Per WebIDL §3.8.1, for interfaces with [Global] extended attribute, the
/// prototype chain must be:
///   global → WindowProperties → Window.prototype → EventTarget.prototype → Object.prototype
///
/// This function modifies the prototype chain by:
/// 1. Creating the WindowProperties exotic object
/// 2. Setting WindowProperties.__proto__ = Window.prototype
/// 3. This is called BEFORE the global's prototype is set to Window.prototype
///    (the caller must then set global.__proto__ = WindowProperties)
///
/// NOTE: This function is designed to be called from initializeBindings() which
/// sets up Window.prototype → EventTarget.prototype. The caller (createChildContext
/// or browser_context) must then set the global's prototype to WindowProperties
/// (not Window.prototype directly) to complete the chain.
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

    // Use JavaScript to set the prototype chain correctly:
    // WindowProperties.__proto__ = Window.prototype
    // global.__proto__ = WindowProperties
    //
    // Per WebIDL §3.8.1, the named properties object's [[Prototype]] must be
    // the interface prototype object (Window.prototype). Then the global's
    // [[Prototype]] must be the named properties object (WindowProperties).
    //
    // This creates: global → WindowProperties → Window.prototype → EventTarget.prototype
    const js_code =
        \\(function() {
        \\  const wp = globalThis.__windowProperties__;
        \\  if (!wp) return false;
        \\  // Step 1: Set WindowProperties' prototype to Window.prototype
        \\  // Per WebIDL §3.8.1: "The [[Prototype]] internal property of a named
        \\  // properties object for an interface must be the interface prototype object"
        \\  Object.setPrototypeOf(wp, Window.prototype);
        \\  // Step 2: Set global's prototype to WindowProperties
        \\  // Per WebIDL §3.8.1: For [Global] interfaces, the global's prototype
        \\  // must be the named properties object
        \\  Object.setPrototypeOf(globalThis, wp);
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
