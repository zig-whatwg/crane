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

    /// Initialize a new instance with consolidated lifecycle management
    ///
    /// This function consolidates all instance allocation logic:
    /// - Allocates Instance handle from SlabAllocator (16 bytes, fast)
    /// - Allocates state from ArenaAllocator (variable size)
    /// - Sets up vtable and state pointers
    ///
    /// ## Parameters
    /// - `allocator`: Unused (kept for API compatibility, will be removed in future)
    /// - `StateType`: Comptime type of the state struct
    /// - `vtable`: Pointer to the interface's VTable
    ///
    /// ## Returns
    /// Initialized Instance pointer ready for use
    ///
    /// ## Errors
    /// - `error.OutOfMemory`: If slab or arena allocation fails
    ///
    /// ## Example
    /// ```zig
    /// const instance = try Instance.init(allocator, ElementState, &element_vtable);
    /// defer Instance.deinit(instance);
    /// ```
    pub fn init(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable: *const VTable,
    ) !*Instance {
        _ = allocator; // Unused - SlabAllocator and ArenaAllocator are global singletons

        // Import SlabAllocator and ArenaAllocator at comptime
        const SlabAllocator = @import("slab_allocator.zig").SlabAllocator;
        const ArenaAllocator = @import("arena_allocator.zig").ArenaAllocator;

        // Step 1: Allocate Instance handle from slab allocator (16 bytes)
        const instance = try SlabAllocator.get().alloc(vtable);
        errdefer SlabAllocator.get().free(instance);

        // Step 2: Allocate state from arena allocator (variable size based on StateType)
        const state = try ArenaAllocator.get().create(StateType);

        // Step 3: Link state to instance
        instance.state = state;

        return instance;
    }

    /// Clean up instance resources with consolidated lifecycle management
    ///
    /// This function consolidates all instance cleanup logic:
    /// - Calls VTable's deinit_fn if present (for custom cleanup)
    /// - Returns Instance handle to SlabAllocator
    /// - State memory is batch-freed during GC sweep (ArenaAllocator.reset())
    ///
    /// ## Parameters
    /// - `instance`: The instance to deinitialize
    ///
    /// ## Example
    /// ```zig
    /// const instance = try Instance.init(allocator, ElementState, &element_vtable);
    /// defer Instance.deinit(instance);
    /// ```
    pub fn deinit(instance: *Instance) void {
        // Import SlabAllocator at comptime
        const SlabAllocator = @import("slab_allocator.zig").SlabAllocator;

        // Step 1: Call VTable's deinit function if present (for custom cleanup)
        if (instance.vtable.deinit_fn) |deinit_fn| {
            deinit_fn(instance.state);
        }

        // Step 2: Return Instance handle to slab allocator
        SlabAllocator.get().free(instance);

        // Note: State memory is NOT freed here - it's batch-freed during GC sweep
        // via ArenaAllocator.reset() in gc_integration.zig::onGCSweep()
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

test "Instance.init allocates instance and state successfully" {
    const SlabAllocator = @import("slab_allocator.zig").SlabAllocator;
    const ArenaAllocator = @import("arena_allocator.zig").ArenaAllocator;

    // Initialize allocators
    SlabAllocator.init(testing.allocator);
    defer SlabAllocator.deinit();

    ArenaAllocator.init(testing.allocator);
    defer ArenaAllocator.deinit();

    // Create VTable
    const methods = MethodMap.initFill(null);
    const vtable = VTable{
        .deinit_fn = null,
        .fns = methods,
    };

    // Define state type
    const State = struct {
        value: u32,
        name: []const u8,
    };

    // Test Instance.init
    const instance = try Instance.init(testing.allocator, State, &vtable);
    defer Instance.deinit(instance);

    // Verify instance is properly initialized
    try testing.expect(instance.vtable == &vtable);

    // Verify state can be accessed
    const state = instance.getState(State);
    state.value = 42;
    state.name = "test";
    try testing.expectEqual(@as(u32, 42), state.value);
    try testing.expectEqualStrings("test", state.name);
}

test "Instance.init handles allocation failure gracefully" {
    const SlabAllocator = @import("slab_allocator.zig").SlabAllocator;
    const ArenaAllocator = @import("arena_allocator.zig").ArenaAllocator;

    // Use FailingAllocator to simulate OutOfMemory
    var failing = std.testing.FailingAllocator.init(testing.allocator, .{ .fail_index = 0 });

    SlabAllocator.init(failing.allocator());
    defer SlabAllocator.deinit();

    ArenaAllocator.init(failing.allocator());
    defer ArenaAllocator.deinit();

    const methods = MethodMap.initFill(null);
    const vtable = VTable{
        .deinit_fn = null,
        .fns = methods,
    };

    const State = struct {
        value: u32,
    };

    // Should fail with OutOfMemory
    const result = Instance.init(testing.allocator, State, &vtable);
    try testing.expectError(error.OutOfMemory, result);
}

test "Instance.deinit calls VTable deinit_fn if present" {
    const SlabAllocator = @import("slab_allocator.zig").SlabAllocator;
    const ArenaAllocator = @import("arena_allocator.zig").ArenaAllocator;

    SlabAllocator.init(testing.allocator);
    defer SlabAllocator.deinit();

    ArenaAllocator.init(testing.allocator);
    defer ArenaAllocator.deinit();

    // Track whether deinit_fn was called
    var deinit_called = false;

    const State = struct {
        deinit_flag: *bool,
    };

    const deinitFn = struct {
        fn call(state: *anyopaque) void {
            const s: *State = @ptrCast(@alignCast(state));
            s.deinit_flag.* = true;
        }
    }.call;

    const methods = MethodMap.initFill(null);
    const vtable = VTable{
        .deinit_fn = deinitFn,
        .fns = methods,
    };

    const instance = try Instance.init(testing.allocator, State, &vtable);
    const state = instance.getState(State);
    state.deinit_flag = &deinit_called;

    // Deinit should call our deinit_fn
    Instance.deinit(instance);

    try testing.expect(deinit_called);
}

test "Instance.deinit does not crash without deinit_fn" {
    const SlabAllocator = @import("slab_allocator.zig").SlabAllocator;
    const ArenaAllocator = @import("arena_allocator.zig").ArenaAllocator;

    SlabAllocator.init(testing.allocator);
    defer SlabAllocator.deinit();

    ArenaAllocator.init(testing.allocator);
    defer ArenaAllocator.deinit();

    const State = struct {
        value: u32,
    };

    const methods = MethodMap.initFill(null);
    const vtable = VTable{
        .deinit_fn = null, // No deinit function
        .fns = methods,
    };

    const instance = try Instance.init(testing.allocator, State, &vtable);

    // Should not crash even without deinit_fn
    Instance.deinit(instance);
}

test "Instance.init and deinit no memory leaks" {
    const SlabAllocator = @import("slab_allocator.zig").SlabAllocator;
    const ArenaAllocator = @import("arena_allocator.zig").ArenaAllocator;

    // Use testing.allocator which detects leaks
    SlabAllocator.init(testing.allocator);
    defer SlabAllocator.deinit();

    ArenaAllocator.init(testing.allocator);
    defer ArenaAllocator.deinit();

    const State = struct {
        value: u32,
        data: [100]u8,
    };

    const methods = MethodMap.initFill(null);
    const vtable = VTable{
        .deinit_fn = null,
        .fns = methods,
    };

    // Allocate and free multiple instances
    var instances: [10]*Instance = undefined;
    for (&instances) |*inst| {
        inst.* = try Instance.init(testing.allocator, State, &vtable);
    }

    for (instances) |inst| {
        Instance.deinit(inst);
    }

    // Note: State memory is batch-freed during arena reset, not individual deinit
    // This test verifies Instance handles are properly freed
}

test "Instance.init supports different state types" {
    const SlabAllocator = @import("slab_allocator.zig").SlabAllocator;
    const ArenaAllocator = @import("arena_allocator.zig").ArenaAllocator;

    SlabAllocator.init(testing.allocator);
    defer SlabAllocator.deinit();

    ArenaAllocator.init(testing.allocator);
    defer ArenaAllocator.deinit();

    const methods = MethodMap.initFill(null);
    const vtable = VTable{
        .deinit_fn = null,
        .fns = methods,
    };

    // Small state
    const SmallState = struct {
        value: u8,
    };

    const inst1 = try Instance.init(testing.allocator, SmallState, &vtable);
    defer Instance.deinit(inst1);

    const state1 = inst1.getState(SmallState);
    state1.value = 42;
    try testing.expectEqual(@as(u8, 42), state1.value);

    // Large state
    const LargeState = struct {
        values: [1024]u64,
    };

    const inst2 = try Instance.init(testing.allocator, LargeState, &vtable);
    defer Instance.deinit(inst2);

    const state2 = inst2.getState(LargeState);
    state2.values[0] = 123;
    state2.values[1023] = 456;
    try testing.expectEqual(@as(u64, 123), state2.values[0]);
    try testing.expectEqual(@as(u64, 456), state2.values[1023]);
}
