//! Core runtime types for WebIDL interface instances
//!
//! This module defines the fundamental types for the WebIDL-to-Zig runtime:
//! - Instance: Type-erased handle (24 bytes) pointing to VTable, state, and context
//! - VTable: Function pointer table for polymorphic dispatch
//! - Method: Enumeration of all possible WebIDL operations
//! - MethodMap: Type-safe mapping from Method to function pointers

const std = @import("std");
const Context = @import("context.zig").Context;

/// Type-erased instance handle (24 bytes)
///
/// Every WebIDL interface instance is represented by this uniform handle:
/// - vtable: Points to the interface's method dispatch table
/// - state: Points to the interface's type-specific state (FullState)
/// - ctx: Runtime context (pointer to JS execution environment)
///
/// This enables polymorphism - a NodeList can hold mixed Node/Element/Text
/// instances and dispatch methods correctly through their vtables.
pub const Instance = struct {
    vtable: *const VTable,
    state: *anyopaque, // KEEP: Polymorphic state - use getState(T) for type safety
    ctx: Context,

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
    /// const instance = try Instance.init(allocator, ElementState, &element_vtable, ctx, undefined);
    /// defer Instance.deinit(instance);
    /// ```
    pub fn init(
        allocator: std.mem.Allocator,
        comptime StateType: type,
        vtable: *const VTable,
        ctx: Context,
    ) !*Instance {
        _ = allocator; // Unused - SlabAllocator and ArenaAllocator are global singletons

        // Import SlabAllocator and ArenaAllocator at comptime
        const SlabAllocator = @import("slab_allocator.zig").SlabAllocator;
        const ArenaAllocator = @import("arena_allocator.zig").ArenaAllocator;

        // Step 1: Allocate Instance handle from slab allocator (24 bytes)
        const instance = try SlabAllocator.get().alloc(vtable);
        errdefer SlabAllocator.get().free(instance);

        // Step 1a: Clear any stale lifecycle flags from previous instance at this address
        // The slab allocator reuses memory addresses, so we must clear old flags
        // to prevent markCleanupStarted() from incorrectly returning false for new instances.
        const instance_lifecycle = @import("instance_lifecycle.zig");
        instance_lifecycle.reset(instance);

        // Step 2: Allocate state from arena allocator (variable size based on StateType)
        const state = try ArenaAllocator.get().create(StateType);

        // Step 2a: CRITICAL - Zero-initialize state memory to prevent uninitialized reads
        // This ensures all pointer fields are null, all numbers are 0, etc.
        // Without this, optional pointer fields contain garbage that crashes when unwrapped.
        // Rationale: Chrome/Blink uses C++ constructors that explicitly initialize all fields.
        // In Zig, struct default values (= null) are NOT applied by allocator.create(),
        // so we must explicitly zero the memory.
        @memset(std.mem.asBytes(state), 0);

        // Step 3: Link state and context to instance
        instance.state = state;
        instance.ctx = ctx;

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
    /// const instance = try Instance.init(allocator, ElementState, &element_vtable, undefined);
    /// defer Instance.deinit(instance);
    /// ```
    pub fn deinit(instance: *Instance) void {
        // Import SlabAllocator at comptime
        const SlabAllocator = @import("slab_allocator.zig").SlabAllocator;

        // Step 1: Call VTable's deinit function if present (for custom cleanup)
        if (instance.vtable.deinit) |deinit_fn| {
            deinit_fn(instance);
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
/// - deinit: Cleanup function called by GC (points to interface's deinit function)
/// - fns: Map from Method enum to function pointers
pub const VTable = struct {
    /// Cleanup function (called by GC finalizer)
    /// Points directly to the interface's deinit function
    /// Signature: fn(instance: *Instance) void
    deinit: ?*const fn (*Instance) void,

    /// Type-erased pointer to the delegates struct
    /// The actual type is known at compile time by each interface
    /// Access methods using getMethod() with the delegates type
    methods_ptr: *const anyopaque, // KEEP: Polymorphic method table - type known at interface level

    /// Get a method function pointer by name using compile-time reflection
    /// Usage: vtable.getMethod(DelegatesType, "methodName")
    pub inline fn getMethod(
        self: *const VTable,
        comptime DelegatesType: type,
        comptime method_name: []const u8,
    ) ?*const anyopaque {
        const delegates_ptr: *const DelegatesType = @ptrCast(@alignCast(self.methods_ptr));

        // Check if the method exists at compile time
        if (!@hasField(DelegatesType, method_name)) {
            return null;
        }

        const method_fn = @field(delegates_ptr.*, method_name);
        return @ptrCast(method_fn);
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
    call_when,

    // === Event getters (readonly attributes) ===
    get_type,
    get_target,
    get_srcElement,
    get_currentTarget,
    get_eventPhase,
    get_bubbles,
    get_cancelable,
    get_defaultPrevented,
    get_composed,
    get_isTrusted,
    get_timeStamp,

    // === Event getters/setters (read-write attributes) ===
    get_cancelBubble,
    set_cancelBubble,
    get_returnValue,
    set_returnValue,

    // === Event operations ===
    call_stopImmediatePropagation,
    call_initEvent,
    call_composedPath,
    call_stopPropagation,
    call_preventDefault,

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
    // Verify Instance is exactly 24 bytes (2 pointers on 64-bit)
    const instance_size = @sizeOf(Instance);
    if (instance_size != 24) {
        @compileError(std.fmt.comptimePrint(
            "Instance must be exactly 24 bytes, got {d} bytes",
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

test "Instance size is 24 bytes" {
    try testing.expectEqual(@as(usize, 24), @sizeOf(Instance));
}

test "Instance has correct field sizes" {
    try testing.expectEqual(@as(usize, 8), @sizeOf(*const VTable));
    try testing.expectEqual(@as(usize, 8), @sizeOf(*anyopaque));
}

test "VTable can store and retrieve methods" {
    // Dummy functions for testing
    const dummyFn = struct {
        fn appendChild() void {}
        fn getAttribute() void {}
    };

    // Create delegates struct with methods
    const delegates = .{
        .call_appendChild = &dummyFn.appendChild,
        .call_getAttribute = &dummyFn.getAttribute,
    };

    const vtable = VTable{
        .deinit = null,
        .methods_ptr = &delegates,
    };

    // Retrieve method using getMethod
    const fn_ptr = vtable.getMethod(@TypeOf(delegates), "call_appendChild");
    try testing.expect(fn_ptr != null);

    // Verify missing method returns null
    const missing = vtable.getMethod(@TypeOf(delegates), "call_removeChild");
    try testing.expectEqual(@as(?*const anyopaque, null), missing);
}

test "Instance.getState casts correctly" {
    // Create dummy state
    const State = struct {
        value: u32,
    };

    var state = State{ .value = 42 };
    const delegates = .{}; // Empty delegates struct
    const vtable = VTable{
        .deinit = null,
        .methods_ptr = &delegates,
    };

    // Create instance
    const instance = Instance{
        .vtable = &vtable,
        .state = @ptrCast(&state),
        .ctx = undefined,
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
    const delegates = .{}; // Empty delegates struct
    const vtable = VTable{
        .deinit = null,
        .methods_ptr = &delegates,
    };

    // Define state type
    const State = struct {
        value: u32,
        name: []const u8,
    };

    // Test Instance.init
    const instance = try Instance.init(testing.allocator, State, &vtable, undefined);
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

    const delegates = .{}; // Empty delegates struct
    const vtable = VTable{
        .deinit = null,
        .methods_ptr = &delegates,
    };

    const State = struct {
        value: u32,
    };

    // Should fail with OutOfMemory
    const result = Instance.init(testing.allocator, State, &vtable, undefined);
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
        fn call(instance: *Instance) void {
            const s: *State = @ptrCast(@alignCast(instance.state));
            s.deinit_flag.* = true;
        }
    }.call;

    const delegates = .{}; // Empty delegates struct
    const vtable = VTable{
        .deinit = deinitFn,
        .methods_ptr = &delegates,
    };

    const instance = try Instance.init(testing.allocator, State, &vtable, undefined);
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

    const delegates = .{}; // Empty delegates struct
    const vtable = VTable{
        .deinit = null, // No deinit function
        .methods_ptr = &delegates,
    };

    const instance = try Instance.init(testing.allocator, State, &vtable, undefined);

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

    const delegates = .{}; // Empty delegates struct
    const vtable = VTable{
        .deinit = null,
        .methods_ptr = &delegates,
    };

    // Allocate and free multiple instances
    var instances: [10]*Instance = undefined;
    for (&instances) |*inst| {
        inst.* = try Instance.init(testing.allocator, State, &vtable, undefined);
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

    const delegates = .{}; // Empty delegates struct
    const vtable = VTable{
        .deinit = null,
        .methods_ptr = &delegates,
    };

    // Small state
    const SmallState = struct {
        value: u8,
    };

    const inst1 = try Instance.init(testing.allocator, SmallState, &vtable, undefined);
    defer Instance.deinit(inst1);

    const state1 = inst1.getState(SmallState);
    state1.value = 42;
    try testing.expectEqual(@as(u8, 42), state1.value);

    // Large state
    const LargeState = struct {
        values: [1024]u64,
    };

    const inst2 = try Instance.init(testing.allocator, LargeState, &vtable, undefined);
    defer Instance.deinit(inst2);

    const state2 = inst2.getState(LargeState);
    state2.values[0] = 123;
    state2.values[1023] = 456;
    try testing.expectEqual(@as(u64, 123), state2.values[0]);
    try testing.expectEqual(@as(u64, 456), state2.values[1023]);
}
