//! Core runtime types for WebIDL interface instances
//!
//! This module defines the fundamental types for the WebIDL-to-Zig runtime:
//! - Instance: Type-erased handle (16 bytes) pointing to VTable and state
//! - VTable: Function pointer table for polymorphic dispatch
//! - Method: Enumeration of all possible WebIDL operations
//! - MethodMap: Type-safe mapping from Method to function pointers

const std = @import("std");

/// Type-erased instance handle (16 bytes)
///
/// Every WebIDL interface instance is represented by this uniform handle:
/// - vtable: Points to the interface's method dispatch table
/// - state: Points to the interface's type-specific state (FullState)
///
/// This enables polymorphism - a NodeList can hold mixed Node/Element/Text
/// instances and dispatch methods correctly through their vtables.
pub const Instance = struct {
    vtable: *const VTable,
    state: *anyopaque,

    /// Get the state as a typed pointer (unsafe - caller must ensure correct type)
    pub inline fn getState(self: *const Instance, comptime T: type) *T {
        return @ptrCast(@alignCast(self.state));
    }
};

/// VTable with function pointers for method dispatch
///
/// Each WebIDL interface has its own VTable populated at comptime.
/// The VTable contains:
/// - deinit_fn: Type-erased cleanup function called by GC
/// - fns: Map from Method enum to function pointers
pub const VTable = struct {
    /// Type-erased deinit function (called by GC finalizer)
    /// Signature: fn(state: *anyopaque) void
    deinit_fn: ?*const fn (*anyopaque) void,

    /// Method function pointer map
    /// Maps Method enum values to type-erased function pointers
    fns: MethodMap,

    /// Get a method function pointer (returns null if not implemented)
    pub inline fn get(self: *const VTable, method: Method) ?*const anyopaque {
        return self.fns.get(method);
    }
};

/// Method enumeration - all possible WebIDL operations
///
/// This enum covers all operations across all WebIDL interfaces.
/// Not every interface implements every method - the VTable's MethodMap
/// will contain null for unimplemented methods.
///
/// Naming convention:
/// - Getters: get_{attributeName}
/// - Setters: set_{attributeName}
/// - Methods: call_{methodName}
/// - Constructors: construct
pub const Method = enum {
    // === EventTarget operations ===
    call_addEventListener,
    call_removeEventListener,
    call_dispatchEvent,

    // === Node getters (readonly attributes) ===
    get_nodeType,
    get_nodeName,
    get_baseURI,
    get_isConnected,
    get_ownerDocument,
    get_parentNode,
    get_parentElement,
    get_childNodes,
    get_firstChild,
    get_lastChild,
    get_previousSibling,
    get_nextSibling,

    // === Node getters/setters (read-write attributes) ===
    get_nodeValue,
    set_nodeValue,
    get_textContent,
    set_textContent,

    // === Node methods ===
    call_getRootNode,
    call_hasChildNodes,
    call_normalize,
    call_cloneNode,
    call_isEqualNode,
    call_isSameNode,
    call_compareDocumentPosition,
    call_contains,
    call_lookupPrefix,
    call_lookupNamespaceURI,
    call_isDefaultNamespace,
    call_insertBefore,
    call_appendChild,
    call_replaceChild,
    call_removeChild,

    // === Element getters ===
    get_namespaceURI,
    get_prefix,
    get_localName,
    get_tagName,
    get_id,
    get_className,
    get_classList,
    get_slot,
    get_attributes,

    // === Element setters ===
    set_id,
    set_className,
    set_slot,

    // === Element methods ===
    call_hasAttributes,
    call_getAttributeNames,
    call_getAttribute,
    call_getAttributeNS,
    call_setAttribute,
    call_setAttributeNS,
    call_removeAttribute,
    call_removeAttributeNS,
    call_toggleAttribute,
    call_hasAttribute,
    call_hasAttributeNS,
    call_getAttributeNode,
    call_getAttributeNodeNS,
    call_setAttributeNode,
    call_setAttributeNodeNS,
    call_removeAttributeNode,
    call_attachShadow,
    call_closest,
    call_matches,
    call_webkitMatchesSelector,
    call_getElementsByTagName,
    call_getElementsByTagNameNS,
    call_getElementsByClassName,
    call_insertAdjacentElement,
    call_insertAdjacentText,

    // === HTMLElement getters/setters ===
    get_title,
    set_title,
    get_lang,
    set_lang,
    get_dir,
    set_dir,
    get_hidden,
    set_hidden,
    get_inert,
    set_inert,
    call_click,
    call_focus,
    call_blur,

    // === Document methods ===
    call_createElement,
    call_createElementNS,
    call_createTextNode,
    call_createComment,
    call_createDocumentFragment,
    call_getElementById,
    call_querySelector,
    call_querySelectorAll,

    // === Constructor ===
    construct,

    // Placeholder for future methods
    // Add more as WebIDL interfaces are generated
};

/// Method function pointer map
///
/// Maps Method enum values to type-erased function pointers.
/// Uses std.EnumArray for O(1) lookup by Method enum.
///
/// Example usage:
///   var map = MethodMap.initFill(null);
///   map.set(.call_appendChild, @ptrCast(&Node.call_appendChild));
///   const fn_ptr = map.get(.call_appendChild);
pub const MethodMap = std.EnumArray(Method, ?*const anyopaque);

// Compile-time verification
comptime {
    // Verify Instance is exactly 16 bytes (2 pointers on 64-bit)
    const instance_size = @sizeOf(Instance);
    if (instance_size != 16) {
        @compileError(std.fmt.comptimePrint(
            "Instance must be exactly 16 bytes, got {d} bytes",
            .{instance_size},
        ));
    }

    // Verify Instance fields are correctly sized
    const vtable_size = @sizeOf(*const VTable);
    const state_size = @sizeOf(*anyopaque);
    if (vtable_size != 8 or state_size != 8) {
        @compileError("Pointer sizes unexpected - expected 8 bytes each on 64-bit");
    }
}

/// Unit tests for instance types
const testing = std.testing;

test "Instance size is 16 bytes" {
    try testing.expectEqual(@as(usize, 16), @sizeOf(Instance));
}

test "Instance has correct field sizes" {
    try testing.expectEqual(@as(usize, 8), @sizeOf(*const VTable));
    try testing.expectEqual(@as(usize, 8), @sizeOf(*anyopaque));
}

test "VTable can store and retrieve methods" {
    // Dummy function for testing
    const dummyFn = struct {
        fn call() void {}
    }.call;

    // Create VTable with one method set
    var methods = MethodMap.initFill(null);
    methods.set(.call_appendChild, @ptrCast(&dummyFn));

    const vtable = VTable{
        .deinit_fn = null,
        .fns = methods,
    };

    // Retrieve method
    const fn_ptr = vtable.get(.call_appendChild);
    try testing.expect(fn_ptr != null);

    // Verify unset method returns null
    const missing = vtable.get(.call_removeChild);
    try testing.expectEqual(@as(?*const anyopaque, null), missing);
}

test "Instance.getState casts correctly" {
    // Create dummy state
    const State = struct {
        value: u32,
    };

    var state = State{ .value = 42 };
    const methods = MethodMap.initFill(null);
    const vtable = VTable{
        .deinit_fn = null,
        .fns = methods,
    };

    // Create instance
    const instance = Instance{
        .vtable = &vtable,
        .state = @ptrCast(&state),
    };

    // Get typed state
    const typed_state = instance.getState(State);
    try testing.expectEqual(@as(u32, 42), typed_state.value);
}

test "Method enum has expected operations" {
    // Verify some key methods exist
    _ = Method.call_addEventListener;
    _ = Method.call_appendChild;
    _ = Method.get_nodeType;
    _ = Method.set_textContent;
    _ = Method.construct;
}
